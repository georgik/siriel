/* =====================================================================
 * host_launch.c  -  ONE-COMMAND LAUNCHER for the two-process Siriel build.
 *
 * The engine (cdrv_engine) and the window (cdrv_window) are SEPARATE
 * processes. Running them by hand is awkward for a user, so this tiny
 * launcher spawns both, waits for the first one to exit, and then kills the
 * other. Pure C: NO FPC, NO Raylib, NO fb_shm -- it only needs fork/exec/
 * waitpid, so it cannot touch the FPC core or the display code.
 *
 * Lifecycle:
 *   - resolve its own directory (parsed from argv0; falls back to
 *     /dev/self/exe) and look for cdrv_engine / cdrv_window next to itself
 *     (argv overrides allowed).
 *   - fork the engine, then fork the window.
 *   - waitpid() for whichever child exits first; SIGTERM the other and wait
 *     for it, so the two never outlive each other:
 *        * Quit from the engine menu -> engine exits -> launcher kills the
 *          window. (The window ALSO stops itself via the shm engine_quit
 *          flag, see fb_shm.h -- belt and suspenders.)
 *        * Window closed (title-bar / Cmd+Q) -> window exits -> launcher
 *          kills the engine (the engine has no window to close, so it would
 *          otherwise run until state==9 or CTRL+C).
 *   - CTRL+C in the terminal: the signal hits the whole foreground process
 *     group; this handler also forwards it so both children clean up.
 * ===================================================================== */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/wait.h>
#include <signal.h>

static pid_t g_engine = 0, g_window = 0;

/* Forward a signal to a child if it is alive. */
static void forward_signal(pid_t p, int sig)
{
    if (p > 0) {
        /* kill() with p>0 sends to that single process. */
        if (kill(p, sig) != 0) {
            /* ESRCH just means it already left; ignore. */
        }
    }
}

/* CTRL+C / TERM on the launcher: tell both children to stop, then exit. */
static void on_launcher_signal(int sig)
{
    (void)sig;
    forward_signal(g_engine, sig);
    forward_signal(g_window, sig);
    _exit(128 + sig);
}

/* Build "<dir>/<base>" into out (max len), where <dir> is the directory
 * containing THIS launcher. Resolution order:
 *   1) argv0 (the path used to invoke us) — always available and works even
 *      when /dev/self/exe is unavailable (some sandboxes/containers lack
 *      /dev/self). This is what makes "../out/cdrv_run" work from any CWD.
 *   2) /dev/self/exe symlink (normal Macs; also covers PATH-invoked argv0).
 *   3) "./base" relative to CWD as a last resort.
 * Returns 1 on success, 0 if nothing could be resolved. */
static int resolve_next_to_self(char *out, size_t outlen, const char *base,
                                const char *argv0)
{
    char dir[4096];

    /* 1) Derive the directory from argv0, if it contains one. */
    if (argv0 && strchr(argv0, '/')) {
        snprintf(dir, sizeof(dir), "%s", argv0);
        char *slash = strrchr(dir, '/');
        if (slash) {
            *slash = '\0';
            if (dir[0])
                return snprintf(out, outlen, "%s/%s", dir, base) < (ssize_t)outlen;
        }
        /* argv0 was like "/foo/" -> dir empty -> fall through to next methods. */
    }

    /* 2) /dev/self/exe symlink (normal Macs; also covers PATH-invoked argv0). */
    {
        char exe[4096];
        ssize_t n = readlink("/dev/self/exe", exe, sizeof(exe) - 1);
        if (n > 0) {
            exe[n] = '\0';
            char *slash = strrchr(exe, '/');
            if (slash) { *slash = '\0'; return snprintf(out, outlen, "%s/%s", exe, base) < (ssize_t)outlen; }
        }
    }

    /* 4) Last resort: next to CWD. */
    return snprintf(out, outlen, "./%s", base) < (ssize_t)outlen;
}

int main(int argc, char **argv)
{
    char eng_path[4096], win_path[4096];
    const char *eng = (argc > 1) ? argv[1] : NULL;
    const char *win = (argc > 2) ? argv[2] : NULL;

    if (!eng)  eng  = resolve_next_to_self(eng_path,  sizeof(eng_path),  "cdrv_engine", argc > 0 ? argv[0] : NULL) ? eng_path  : "./cdrv_engine";
    if (!win)  win  = resolve_next_to_self(win_path,  sizeof(win_path),  "cdrv_window", argc > 0 ? argv[0] : NULL) ? win_path  : "./cdrv_window";

    signal(SIGINT,  on_launcher_signal);
    signal(SIGTERM, on_launcher_signal);
    /* Ignore SIGHUP so closing the terminal session does not orphan children. */
    signal(SIGHUP,  SIG_IGN);

    fprintf(stderr, "[launch] engine  = %s\n", eng);
    fprintf(stderr, "[launch] window  = %s\n", win);

    /* --- spawn the engine first so the shm segment exists before the window
     * attaches (the window also retries, so this is just good hygiene). --- */
    g_engine = fork();
    if (g_engine < 0) { perror("fork engine"); return 1; }
    if (g_engine == 0) {
        execl(eng, eng, (char *)NULL);
        perror("execl engine");
        _exit(127);
    }

    g_window = fork();
    if (g_window < 0) { perror("fork window"); return 1; }
    if (g_window == 0) {
        execl(win, win, (char *)NULL);
        perror("execl window");
        _exit(127);
    }

    fprintf(stderr, "[launch] engine pid=%d  window pid=%d  (Ctrl+C to quit both)\n",
            (int)g_engine, (int)g_window);

    int status;
    pid_t exited;
    while ((exited = waitpid(-1, &status, 0)) > 0) {
        if (exited == g_engine) {
            fprintf(stderr, "[launch] engine exited (code %d); stopping window\n",
                    WIFEXITED(status) ? WEXITSTATUS(status) : -1);
            forward_signal(g_window, SIGTERM);
            waitpid(g_window, &status, 0);
            return WIFEXITED(status) ? WEXITSTATUS(status) : 0;
        } else if (exited == g_window) {
            fprintf(stderr, "[launch] window closed; stopping engine\n");
            forward_signal(g_engine, SIGTERM);
            waitpid(g_engine, &status, 0);
            return 0;
        }
        /* Any other reaped pid (should not happen) -> keep waiting. */
    }
    return 0;
}
