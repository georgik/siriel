/* crash_handler.c - C-level backtrace on SIGSEGV/SIGBUS/SIGABRT/SIGILL.
 * Also prints the ORIGINAL faulting PC (si_addr) so we can disassemble it. */
#include <signal.h>
#include <execinfo.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

static void print_resolved(void) __attribute__((constructor));
static void print_resolved(void) {
    void *fn = dlsym(RTLD_DEFAULT, "SDL_Init");
    fprintf(stderr, "=== crash_handler: dlsym(SDL_Init) = %p ===\n", fn);
    fflush(stderr);
}

static void on_signal(int, siginfo_t *, void *);

static void install_handler(int sig) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = on_signal;
    sa.sa_flags = SA_RESTART | SA_NODEFER | SA_SIGINFO;
    sigaction(sig, &sa, NULL);
}

static void on_signal(int sig, siginfo_t *si, void *uarg) {
    (void)uarg;
    void *array[50];
    int size = backtrace(array, 50);
    fprintf(stderr, "\n=== [CH] MY HANDLER: Signal %d ===\n", sig);
    /* For SIGILL/SIGSEGV, si_addr is the faulting instruction address (SIGILL)
       or fault data address. Print it so we can disassemble the faulting insn. */
    fprintf(stderr, "[CH] si_addr (fault insn/data) = %p\n", si ? (void *)si->si_addr : NULL);
    fflush(stderr);
    backtrace_symbols_fd(array, size, STDERR_FILENO);
    fprintf(stderr, "=====================================\n");
    signal(sig, SIG_DFL);
    raise(sig);
}

void install_crash_handler(void) {
    fprintf(stderr, "[CH] install_crash_handler CALLED\n");
    fflush(stderr);
    install_handler(SIGSEGV);
    install_handler(SIGBUS);
    install_handler(SIGABRT);
    install_handler(SIGILL);
}
