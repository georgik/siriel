/* crash_handler.c - C-level backtrace on SIGSEGV/SIGBUS/SIGABRT/SIGILL.
 * Also prints the ORIGINAL faulting PC (si_addr) so we can disassemble it.
 *
 * Platform notes:
 *   - POSIX (Linux, macOS): uses backtrace()/backtrace_symbols_fd() from
 *     execinfo.h and dlsym() to report which BGI runtime loaded.
 *   - Windows (mingw-w64): execinfo.h and RTLD_DEFAULT are unavailable, so we
 *     fall back to a minimal handler that prints the signal number and the
 *     faulting address and re-raises. No lib backtrace is available without
 *     extra tooling, and printing the fault PC is enough to locate the insn.
 */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !defined(_WIN32)
#  include <execinfo.h>
#  include <unistd.h>
#  include <dlfcn.h>
#endif

#if !defined(_WIN32)
/* Report which BGI runtime defines detectgraph, so a fault inside the stub
 * can be attributed to the right object. Unix-only (RTLD_DEFAULT). */
static void print_resolved(void) __attribute__((constructor));
static void print_resolved(void) {
    void *fn = dlsym(RTLD_DEFAULT, "detectgraph");
    fprintf(stderr, "=== crash_handler: dlsym(detectgraph, BGI runtime) = %p ===\n", fn);
    fflush(stderr);
}
#endif

#if !defined(_WIN32)
static void on_signal(int, siginfo_t *, void *);
#endif

#if defined(_WIN32)
/* Windows has no sigaction()/siginfo_t, so we install a plain signal()
 * handler. We still print the faulting signal number and re-raise, which is
 * enough to surface the crash in the console. */
static void on_signal_win(int sig)
{
    fprintf(stderr, "\n=== [CH] MY HANDLER: Signal %d ===\n", sig);
    fflush(stderr);
    signal(sig, SIG_DFL);
    raise(sig);
}

static void install_handler(int sig)
{
    signal(sig, on_signal_win);
}
#else

static void install_handler(int sig) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = on_signal;
    sa.sa_flags = SA_RESTART | SA_NODEFER | SA_SIGINFO;
    sigaction(sig, &sa, NULL);
}
#endif


#if !defined(_WIN32)
static void on_signal(int sig, siginfo_t *si, void *uarg) {
    (void)uarg;
    fprintf(stderr, "\n=== [CH] MY HANDLER: Signal %d ===\n", sig);
    /* si_addr is the faulting instruction/data address. Print it so we can
     * disassemble the faulting insn (or, on Windows, locate it by hand). */
    fprintf(stderr, "[CH] si_addr (fault insn/data) = %p\n", si ? (void *)si->si_addr : NULL);
    fflush(stderr);

    {
        void *array[50];
        int size = backtrace(array, 50);
        backtrace_symbols_fd(array, size, STDERR_FILENO);
        fprintf(stderr, "=====================================\n");
    }

    signal(sig, SIG_DFL);
    raise(sig);
}
#endif

void install_crash_handler(void) {
    fprintf(stderr, "[CH] install_crash_handler CALLED\n");
    fflush(stderr);
    install_handler(SIGSEGV);
#ifdef SIGBUS
    install_handler(SIGBUS);
#endif
    install_handler(SIGABRT);
#ifdef SIGILL
    install_handler(SIGILL);
#endif
}

/* Interpose abort() so SIGABRT is diagnosable.  The libc abort() (called by
 * __stack_chk_fail on a corrupted stack canary, by assert(), or by malloc's
 * corruption guard) normally resets ALL signal handlers to SIG_DFL before
 * raising SIGABRT -- which would hide our SIGABRT handler and give no
 * backtrace.  By intercepting abort() we print the call site FIRST, then
 * delegate to the real abort() (looked up via RTLD_NEXT so we do not
 * recurse).  This mirrors the SIGSEGV/SIGBUS/SIGILL backtrace above and
 * makes an 'abort' termination show exactly which engine routine tripped it. */
#if !defined(_WIN32)
void abort(void) __attribute__((noreturn));
void abort(void) {
    fprintf(stderr, "\n=== [CH] abort() intercepted ===\n");
    void *array[50];
    int size = backtrace(array, 50);
    backtrace_symbols_fd(array, size, STDERR_FILENO);
    fprintf(stderr, "=====================================\n");
    fflush(stderr);
    void (*real_abort)(void) = (void (*)(void)) dlsym(RTLD_NEXT, "abort");
    if (real_abort) {
        real_abort();
    } else {
        raise(SIGABRT);
    }
    _exit(134);
}
#endif
