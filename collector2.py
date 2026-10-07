#!/usr/bin/env python3
"""Archive closed local MariaDB CRC32 binlogs to S3. Python 3.6.15+, no pip deps."""
import argparse
import base64
import fcntl
import gzip
import hashlib
import http.client
import json
import logging
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
from urllib.parse import quote, urlencode
import xml.etree.ElementTree as ET
import zlib

CHUNK = 1024 * 1024
MAX_RAW_BYTES = 4 * 1024**3  # Leaves gzip overhead below S3's single-PUT limit.
NAME = re.compile(r"([A-Za-z0-9_-]+(?:[.][A-Za-z0-9_-]+)*)[.]([0-9]{6,})\Z")


class CollectorError(Exception):
    pass


def check_name(name):
    match = NAME.fullmatch(name)
    if not match:
        raise CollectorError("Invalid binlog filename: " + name)
    return match


def successor(name):
    match = check_name(name)
    return "%s.%0*d" % (match[1], len(match[2]), int(match[2]) + 1)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(CHUNK), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sync_dir(path):
    fd = os.open(str(path), os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def save_json(path, value):
    temporary = path.with_suffix(".tmp")
    with temporary.open("w") as stream:
        json.dump(value, stream, sort_keys=True, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(str(temporary), str(path))
    sync_dir(path.parent)


def pack_binlog(source, archive, expected_size):
    """Validate event boundaries/CRC32 while compressing, without decoding rows."""
    if not 4 < expected_size <= MAX_RAW_BYTES:
        raise CollectorError("Unsupported binlog size (maximum 4 GiB)")
    if shutil.disk_usage(archive.parent).free < expected_size * 1.01 + 64 * CHUNK:
        raise CollectorError("Insufficient spool disk space")
    temporary = archive.with_suffix(".partial")
    digest = hashlib.sha256()
    events, position = 0, 4
    try:
        with source.open("rb") as incoming, temporary.open("wb") as output:
            before = os.fstat(incoming.fileno())
            if before.st_size != expected_size or incoming.read(4) != b"\xfebin":
                raise CollectorError("Binlog size or magic mismatch")
            with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0, compresslevel=6) as compressed:
                compressed.write(b"\xfebin")
                digest.update(b"\xfebin")
                while position < expected_size:
                    header = incoming.read(19)
                    if len(header) != 19:
                        raise CollectorError("Truncated event header")
                    _, kind, _, size, next_position, flags = struct.unpack("<IBIIIH", header)
                    if size < 23 or position + size > expected_size or next_position != position + size:
                        raise CollectorError("Invalid event boundary at %d" % position)
                    if events == 0 and (kind != 15 or flags & 1 or size > 4096):
                        raise CollectorError("Missing format description or binlog is still in use")
                    checksum = zlib.crc32(header)
                    digest.update(header)
                    compressed.write(header)
                    remaining = size - 23
                    while remaining:
                        chunk = incoming.read(min(CHUNK, remaining))
                        if not chunk:
                            raise CollectorError("Truncated event body")
                        if events == 0 and (chunk[-1] != 1 or chunk[:2] != b"\4\0" or chunk[56:57] != b"\x13"):
                            raise CollectorError("Expected v4 binlog with CRC32 checksums")
                        checksum = zlib.crc32(chunk, checksum)
                        digest.update(chunk)
                        compressed.write(chunk)
                        remaining -= len(chunk)
                    tail = incoming.read(4)
                    if len(tail) != 4 or struct.unpack("<I", tail)[0] != checksum:
                        raise CollectorError("Binlog checksum mismatch at %d" % position)
                    digest.update(tail)
                    compressed.write(tail)
                    events += 1
                    position += size
            after = os.fstat(incoming.fileno())
            if incoming.read(1) or (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
                raise CollectorError("Binlog changed while being archived")
            output.flush()
            os.fsync(output.fileno())
        os.replace(str(temporary), str(archive))
        sync_dir(archive.parent)
    finally:
        if temporary.exists():
            temporary.unlink()
    return {"raw_bytes": expected_size, "raw_sha256": digest.hexdigest(), "events": events,
            "gzip_bytes": archive.stat().st_size, "gzip_sha256": sha256(archive)}


class MySQLSource:
    def __init__(self, config):
        self.config = config

    def inventory(self):
        config = self.config
        command = [config.get("mysql_binary", "mysql")]
        defaults = config.get("mysql_defaults_file")
        command += ["--defaults-file=" + defaults] if defaults else ["--no-defaults", "--user=root"]
        command += ["--protocol=SOCKET", "--socket=" + config.get("mysql_socket", "/run/mysql/mysql.sock"),
                    "--batch", "--raw", "--skip-column-names", "--connect-timeout=10", "--execute",
                    "SELECT @@hostname, @@server_id, @@log_bin_basename; SHOW BINARY LOGS;"]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                universal_newlines=True, timeout=30)
        if result.returncode:
            raise CollectorError("MySQL inventory failed: " + result.stderr.strip())
        lines = result.stdout.splitlines()
        if len(lines) < 2 or len(lines[0].split("\t")) != 3:
            raise CollectorError("MySQL returned no binlog inventory")
        hostname, server_id, basename = lines[0].split("\t")
        logs = [(line.split("\t")[0], int(line.split("\t")[1])) for line in lines[1:]]
        return {"hostname": hostname, "server_id": server_id, "basename": basename}, logs


class S3Store:
    def __init__(self, config):
        bucket, region = config["bucket"], config["region"]
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,61}[a-z0-9]", bucket):
            raise CollectorError("Expected an S3 bucket name without dots")
        if not re.fullmatch(r"[a-z]{2}-[a-z]+-[0-9]+", region):
            raise CollectorError("Invalid AWS region")
        self.host = bucket + ".s3." + region + ".amazonaws.com"

    def request(self, method, key, headers, body=None, query=None):
        # Direct TLS, normal certificate verification, no credentials or redirects.
        connection = http.client.HTTPSConnection(self.host, timeout=1800)
        try:
            target = "/" + quote(key, safe="/")
            if query:
                target += "?" + urlencode(query)
            connection.request(method, target, body=body, headers=headers)
            response = connection.getresponse()
            payload = response.read(65537)
            if len(payload) > 65536:
                raise CollectorError("Unexpectedly large S3 metadata response")
            return response.status, {name.lower(): value for name, value in response.getheaders()}, payload
        except (OSError, http.client.HTTPException) as error:
            raise CollectorError("S3 HTTPS request failed: " + str(error)) from error
        finally:
            connection.close()

    def publish(self, path, key):
        checksum = base64.b64encode(bytes.fromhex(sha256(path))).decode("ascii")
        expected_size = path.stat().st_size
        head_headers = {"x-amz-checksum-mode": "ENABLED"}
        # Missing-object HEAD can return 403. Require a successful scoped listing
        # to establish absence; never interpret an access denial as a missing key.
        status, _, payload = self.request("GET", "", {}, query={"list-type": "2", "prefix": key, "max-keys": "1"})
        if status != 200:
            raise CollectorError("S3 listing failed (HTTP %d); check source IP and bucket policy" % status)
        try:
            root = ET.fromstring(payload)
        except ET.ParseError as error:
            raise CollectorError("Invalid S3 listing response") from error
        namespace = "{http://s3.amazonaws.com/doc/2006-03-01/}"
        if root.tag != namespace + "ListBucketResult":
            raise CollectorError("Unexpected S3 listing response")
        exists = any(node.text == key for node in root.findall(namespace + "Contents/" + namespace + "Key"))
        if not exists:
            # Anonymous S3 PUT cannot use If-None-Match (requires SigV4). The
            # collector lock and one writer per source prefix are required.
            headers = {"Content-Length": str(expected_size),
                       "x-amz-checksum-sha256": checksum, "x-amz-server-side-encryption": "AES256",
                       "Content-Type": "application/json" if key.endswith(".json") else "application/gzip"}
            with path.open("rb") as stream:
                status, _, _ = self.request("PUT", key, headers, body=stream)
            if status != 200:
                raise CollectorError("S3 PUT failed (HTTP %d); check source IP and bucket policy" % status)
        status, existing, _ = self.request("HEAD", key, head_headers)
        if status != 200:
            raise CollectorError("S3 HEAD failed (HTTP %d) for %s" % (status, key))
        if existing.get("content-length") != str(expected_size) or existing.get("x-amz-checksum-sha256") != checksum:
            raise CollectorError("S3 checksum mismatch or key collision: " + key)


class Collector:
    def __init__(self, config, source, store):
        self.config, self.source, self.store = config, source, store
        self.spool = Path(config["spool_dir"])
        self.state_path = self.spool / "state.json"
        self.pending_path = self.spool / "pending.json"
        self.archive = self.spool / "pending.gz"
        self.binding = {key: config[key] for key in ("bucket", "region", "prefix", "source_id")}
        if not re.fullmatch(r"[A-Za-z0-9_-]+", config["source_id"]):
            raise CollectorError("source_id must contain only letters, digits, underscores or hyphens")
        if not re.fullmatch(r"[A-Za-z0-9_/-]+", config["prefix"]) or config["prefix"].startswith("/"):
            raise CollectorError("Invalid S3 prefix")

    def clear_pending(self):
        # Remove the journal first: a leftover archive is safe to overwrite.
        self.pending_path.unlink()
        sync_dir(self.spool)
        self.archive.unlink()

    def finish_pending(self, state):
        pending = json.loads(self.pending_path.read_text())
        if pending["source"] != state["source"] or pending["destination"] != self.binding:
            raise CollectorError("pending source/destination mismatch")
        if state["next_file"] == pending["next_file"]:
            self.clear_pending()
            return 0
        if state["next_file"] != pending["file"]:
            raise CollectorError("pending checkpoint mismatch")
        if not self.archive.exists() or self.archive.stat().st_size != pending["gzip_bytes"] or sha256(self.archive) != pending["gzip_sha256"]:
            raise CollectorError("Local pending archive is missing or corrupt")
        key = self.config["prefix"].rstrip("/") + "/" + self.config["source_id"] + "/" + pending["file"]
        self.store.publish(self.archive, key + ".gz")
        self.store.publish(self.pending_path, key + ".json")
        state["next_file"] = pending["next_file"]
        save_json(self.state_path, state)
        self.clear_pending()
        logging.info("Archived %s (%d bytes compressed)", pending["file"], pending["gzip_bytes"])
        return 1

    def run(self, start_file=None, max_files=10):
        os.umask(0o077)
        self.spool.mkdir(mode=0o700, parents=True, exist_ok=True)
        if self.spool.stat().st_mode & 0o077:
            raise CollectorError("spool_dir must be private (chmod 700)")
        with (self.spool / "collector.lock").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                logging.info("Another collector is running")
                return 0
            return self.run_locked(start_file, max_files)

    def run_locked(self, start_file, max_files):
        if max_files < 1:
            raise CollectorError("max_files must be positive")
        uploaded = 0
        state = json.loads(self.state_path.read_text()) if self.state_path.exists() else None
        if state:
            if state.get("version") != 1 or state["destination"] != self.binding:
                raise CollectorError("Checkpoint version or destination changed; use a new spool/source_id")
            if self.pending_path.exists():
                uploaded += self.finish_pending(state)
        elif self.pending_path.exists():
            raise CollectorError("pending journal exists without checkpoint; restore state.json")
        elif not start_file:
            raise CollectorError("First run requires --start-file (no implicit historical backfill)")
        identity, logs = self.source.inventory()
        if not logs:
            raise CollectorError("Empty binlog inventory")
        for name, _ in logs:
            check_name(name)
        names = [name for name, _ in logs]
        if state:
            if state["source"] != identity:
                raise CollectorError("Database source identity changed; use a new spool/source_id")
        else:
            check_name(start_file)
            if start_file not in names:
                raise CollectorError("Starting binlog is missing (purged or mistyped?): " + start_file)
            state = {"version": 1, "source": identity, "destination": self.binding, "next_file": start_file}
            save_json(self.state_path, state)
        if state["next_file"] not in names:
            raise CollectorError("Expected binlog is missing (purged/reset?): " + state["next_file"])
        first = names.index(state["next_file"])
        # SHOW BINARY LOGS lists the active file last. Always leave it alone.
        for index in range(first, len(logs) - 1):
            if uploaded >= max_files:
                break
            name, size = logs[index]
            next_file = names[index + 1]
            if successor(name) != next_file:
                raise CollectorError("Binlog sequence gap after " + name)
            path = Path(identity["basename"]).parent / name
            details = pack_binlog(path, self.archive, size)
            pending = dict(details, version=1, source=identity, destination=self.binding,
                           file=name, next_file=next_file, start_position=4, end_position=size,
                           compression="gzip")
            save_json(self.pending_path, pending)
            uploaded += self.finish_pending(state)
        return uploaded


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--start-file", help="Required only before the first checkpoint; ignored on later runs")
    parser.add_argument("--max-files", type=int, default=10, help="Maximum closed files uploaded per invocation")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    try:
        config = json.loads(args.config.read_text())
        count = Collector(config, MySQLSource(config), S3Store(config)).run(args.start_file, args.max_files)
        logging.info("Done: %d files uploaded", count)
        return 0
    except (CollectorError, OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        logging.error("%s", error)
        return 1


if __name__ == "__main__":
    sys.exit(main())
