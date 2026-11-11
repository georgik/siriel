/* =====================================================================
 * host_engine.c  -  C host that DRIVES the Siriel 3.5 FPC engine and
 *                  PUBLISHES its framebuffer to POSIX shared memory.
 *
 * This is the ENGINE half of the two-process windowed build. It has NO
 * window, NO Raylib, NO AppKit -- it is a pure C + FPC-engine process.
 * That is what makes it safe: the FPC runtime is present here, but it is
 * never asked to touch macOS display/event code (the SIGILL source).
 *
 * The engine is a static library; C owns main(). Pattern is identical to
 * host_cdrv.c (the proven headless PPM dumper) minus the frame dump:
 *   - fpc_initializeunits runs once (FPC prologue).
 *   - engine_init()
 *   - loop: C owns the clock (+=77/tick), engine_step(), one ENTER key
 *           at step 2 selects 'Game', read generation/state.
 *   - each step: copy FrameRGB (U_$VIDBASE_$$_FRAMERGB, 921600 B) into the
 *              shared segment and publish (bump seq).
 *   - break at state==9 (done); engine_shutdown().
 *
 * Pascal NEVER calls back into display code. The ONLY shared state is the
 * shm segment (fb_shm.c).
 *
 * Symbols are FPC-mangled:  P$<UNIT>_$$_<PROC>$<TYPES>.
 * ===================================================================== */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <signal.h>
#include "fb_shm.h"

/* C-level SIGSEGV backtrace handler (crash_handler.c). Install FIRST. */
void install_crash_handler(void);

/* CTRL+C / SIGINT: flag the run loop to stop and shut down cleanly. */
static volatile sig_atomic_t g_quit = 0;
static void on_sigint(int sig) { (void)sig; g_quit = 1; }

static void install_sigint_handler(void)
{
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = on_sigint;
    sigaction(SIGINT, &sa, NULL);
}

/* --- Pascal engine entry points (unit 'SIRIEL3', SI35.PAS) --- */
extern void     P$SIRIEL3_$$_ENGINE_INIT(void);
extern void     P$SIRIEL3_$$_ENGINE_STEP(void);
extern void     P$SIRIEL3_$$_ENGINE_SHUTDOWN(void);
extern void     P$SIRIEL3_$$_ENGINE_PRESS_KEY$WORD(unsigned short k);
extern void     P$SIRIEL3_$$_ENGINE_SET_CLOCK$LONGINT(int c);
extern unsigned char * P$SIRIEL3_$$_ENGINE_BUFFER$$POINTER(void);
extern int      P$SIRIEL3_$$_ENGINE_GENERATION$$LONGINT(void);
extern int      P$SIRIEL3_$$_ENGINE_STATE$$LONGINT(void);

/* The 24-bit expanded framebuffer (640x480x24 = 921600 B), populated every
 * vid_present() by expand_frame() in vid_dispatch.inc. This is exactly what
 * the window must display. */
extern unsigned char U_$VIDBASE_$$_FRAMERGB[FB_RGB];

/* crude frame-change notice */
static uint32_t fb_hash(const unsigned char *fb)
{
    uint32_t h = 2166136261u;
    size_t i;
    for (i = 0; i < FB_RGB; i += 17) h ^= fb[i];
    return h;
}

/* Optional frame dump to /tmp/siriel_shm/frame_%02d.ppm when VID_SHM_DUMP is
 * set. Purely for debugging on the desktop; the window reads shm directly. */
static long long g_frames_dumped = 0;
static void maybe_dump_ppm(int step)
{
    if (getenv("VID_SHM_DUMP") == NULL) return;
    char path[128];
    snprintf(path, sizeof(path), "/tmp/siriel_shm/frame_%02d.ppm", step);
    FILE *f = fopen(path, "wb");
    if (!f) return;
    fprintf(f, "P6\n%d %d\n255\n", FBW, FBH);
    fwrite(U_$VIDBASE_$$_FRAMERGB, 1, FB_RGB, f);
    fclose(f);
    g_frames_dumped++;
}

/* The FPC program body calls this. C owns everything except the engine. */
int host_main(void)
{
    int step;
    fb_shm_hdr *h;                 /* shm header (window sets h->quit) */
    uint64_t g_cmd_rd = 0;         /* key-ring read index (engine side) */
    uint32_t gen, last_seen_gen = 0xFFFFFFFF;
    int state, last_state = -1;
    uint32_t last_hash = 0, cur_hash = 0;
    uint64_t last_seq = 0;
    long long g_clock = 0;

    install_crash_handler();
    /* NOTE: do NOT install the SIGINT handler before ENGINE_INIT() -- it
     * resets signal dispositions. Install it AFTER init, right before the run
     * loop, so CTRL+C survives. */

    /* Attach the shared segment for WRITING (creates it if absent). */
    void *shm = fb_shm_open_writer();
    if (!shm) {
        fprintf(stderr, "[host] FATAL: cannot open framebuffer shm\n");
        return 2;
    }
    fprintf(stderr, "[host] framebuffer shm @ %p  (%d bytes)  name=%s\n",
            (void *)FB_SHM_FB(shm), FB_RGB, getenv("SIRIEL_FB_NAME")
                ? getenv("SIRIEL_FB_NAME") : FB_SHM_DEFAULT_NAME);
    h = (fb_shm_hdr *)shm;

    /* Wall-clock throttle for the LIVE demo: the game clock is C-owned
     * (g_clock += 77/step, independent of wall time), so slowing the step
     * rate only stretches the demo out in real time -- it does NOT change
     * game behaviour. Default ~30 steps/s; override with SIRIEL_STEP_MS.
     * Without this the engine burns all 600 steps in <1s and the window
     * shows only the final frame. */
    long step_ms = 33;
    const char *env_ms = getenv("SIRIEL_STEP_MS");
    if (env_ms && atoi(env_ms) > 0) step_ms = atoi(env_ms);

    P$SIRIEL3_$$_ENGINE_INIT();
    fprintf(stderr, "[host] engine_init() returned OK\n");
    install_sigint_handler();   /* CTRL+C -> clean stop (after init) */

    /* Run indefinitely. The loop exits only on: (1) CTRL+C (g_quit),
     * (2) the window asking us to quit (h->quit), or (3) the engine reaching
     * done (state==9, e.g. Quit selected from the main menu). */
    for (step = 0; ; step++) {
        if (g_quit || h->quit) break;
        /* C owns the virtual clock: +77 per step (emulates the 4608 Hz DOS
         * tick at ~60 steps/s). Pascal sees forward game-time. */
        /* C owns the keyboard: consume ONE pending key from the window key
         * ring and hand it to the engine BEFORE this tick. choice_step()
         * reads it via keypressed()/key() during engine_step(), so feeding
         * it just ahead of the tick is what lets real window keys navigate
         * the menu. At most one key per step (auto_key_pending holds a
         * single word), matching the engine's one-choice-per-step design. */
        {
            uint64_t cmd_wr = FB_SHM_CMD_WR(shm);
            if (g_cmd_rd < cmd_wr) {
                uint16_t k = *FB_SHM_CMD_AT(shm, g_cmd_rd);
                P$SIRIEL3_$$_ENGINE_PRESS_KEY$WORD(k);
                g_cmd_rd++;
            }
        }

        g_clock += 77;
        P$SIRIEL3_$$_ENGINE_SET_CLOCK$LONGINT((int)g_clock);

        /* One engine tick. */
        P$SIRIEL3_$$_ENGINE_STEP();

        /* NOTE: the old build auto-injected a single ENTER at step 2 to jump
         * straight to gameplay. Removed on purpose: we want the initial
         * intro menu to show and be driven by real window keys. */

        /* --- publish the engine's framebuffer to shared memory ---
         * Copy the full 921600-byte FrameRGB, THEN bump the sequence. The
         * window loads seq (acquire) and only reads the bytes after seeing a
         * newer value, so it never sees a half-written frame. */
        memcpy(FB_SHM_FB(shm), U_$VIDBASE_$$_FRAMERGB, FB_RGB);
        fb_shm_publish(shm);

        gen  = (uint32_t)P$SIRIEL3_$$_ENGINE_GENERATION$$LONGINT();
        state = P$SIRIEL3_$$_ENGINE_STATE$$LONGINT();
        cur_hash = fb_hash(U_$VIDBASE_$$_FRAMERGB);

        if (state != last_state) {
            fprintf(stderr, "[host] step=%d state=%d gen=%u hash=%08x%s\n",
                    step, state, gen, cur_hash,
                    (cur_hash != last_hash) ? "  [picture changed]" : "");
            last_state  = state;
            last_hash   = cur_hash;
        }
        /* Heartbeat: if the menu (state 11) is non-blocking, the step count
         * keeps climbing while state stays 11 (waiting for a key). If it
         * freezes, choice_step() is blocking for input.
         * Gated behind HOST_HB=1 (off by default) -- it fired every 10 steps. */
        if ((step % 10) == 0 && getenv("HOST_HB") != NULL)
            fprintf(stderr, "[host] hb step=%d state=%d cmd_rd=%llu\n",
                    step, state, (unsigned long long)g_cmd_rd);

        maybe_dump_ppm(step);

        if (state == 9) {
            fprintf(stderr, "[host] engine reached done (state=9) at step=%d\n",
                    step);
            break;
        }

        /* Throttle the step rate so the live window plays out over time. */
        usleep((unsigned)(step_ms * 1000));
    }

    fprintf(stderr, "[host] published frames; shutting engine down\n");
    /* Tell the window to exit too. The engine owns no display; when it stops
     * (Quit from the menu -> state==9, CTRL+C, or the window asking us to stop)
     * the window must not keep showing a frozen last frame. The shm object
     * outlives this munmap, so the window observes engine_quit from its own
     * mapping. Symmetric with the window's own hdr->quit signal. */
    h->engine_quit = 1;
    P$SIRIEL3_$$_ENGINE_SHUTDOWN();
    fb_shm_close(shm);
    fprintf(stderr, "[host] engine_shutdown() returned; host exit 0\n");
    return 0;
}
