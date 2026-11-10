/* =====================================================================
 * host_window.c  -  pure C + Raylib WINDOW host for the two-process build.
 *
 * This is the WINDOW half. It links NO FPC object, calls NO Pascal symbol,
 * and owns NO engine. It:
 *   - reads the 640x480x24 framebuffer the engine publishes into POSIX
 *     shared memory (fb_shm.c) and displays it with Raylib, and
 *   - forwards real keyboard input back to the engine through the key ring
 *     in the same segment, so the user can navigate Siriel's menus.
 *
 * Structure mirrors the working Raylib reference
 * (examples/core/core_basic_window.c): attach the framebuffer, InitWindow,
 * then a plain draw loop that blits the latest published frame.
 *
 * =====================================================================
 * KEYBOARD (IMPORTANT)
 * ---------------------------------------------------------------------
 * Raylib ALREADY registers its own GLFW key callback (glfwSetKeyCallback)
 * on the real GLFW window during InitWindow(), and updates its internal
 * key state from it. Raylib then exposes that state through its POLLING
 * API:  GetKeyPressed()  (one-shot key press)  and  GetCharPressed().
 *
 * The raylib examples (core_input_keys.c, core_keyboard_testbed.c) all use
 * this polling API and NEVER call glfwSetKeyCallback themselves.
 *
 * On macOS, raylib.h's GetWindowHandle() returns the Cocoa NSWindow*
 * (glfwGetCocoaWindow), NOT the GLFWwindow*. Registering a GLFW key
 * callback on that NSWindow* (cast to GLFWwindow*) is a bogus handle:
 * GLFW silently ignores it, so the callback never fires. That was the
 * bug that made no key get logged/forwarded (only Raylib's built-in
 * ESC->close worked, because that is Raylib's own callback).
 *
 * FIX: do NOT register our own GLFW callback. Poll Raylib's API instead.
 * ===================================================================== */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include "raylib.h"

#include "fb_shm.h"

/* macOS window-visibility/focus helpers (activate_macos.m). Passing the
 * NSWindow* lets us promote the window to the KEY window so GLFW receives
 * keystrokes (the Terminal otherwise keeps the key slot). */
void siel_activate_app(void *nsWindow);

/* --------------------------------------------------------------------- */
/* Keyboard -> engine. Siriel's JXGRAF menu matcher (GAME.INC.choice_step)
 * compares the injected DOS key word:
 *       word = (scan_code << 8) | ascii
 * The LOW byte is the ASCII character, NOT the PS/2 make code. Arrows have
 * no ASCII (0), so UP=0x4800, DOWN=0x5000, LEFT=0x4b00, RIGHT=0x4d00;
 * ENTER=0x1c0d  ESC=0x011b  SPACE=0x3920.  (release = scan<<8 | 0x00)      */

/* Build the 16-bit DOS key word for one Raylib KEY_* press. Only the
 * navigation / action keys Siriel's menus need return a word; letters,
 * digits and unknown keys return 0 (they are forwarded via GetCharPressed
 * instead, so each printable character is sent exactly once). */
static uint16_t dos_key_word(int key)
{
    switch (key) {
        case KEY_UP:       return 0x4800;   /* scan 0x48, ascii 0   */
        case KEY_DOWN:     return 0x5000;   /* scan 0x50            */
        case KEY_LEFT:     return 0x4b00;   /* scan 0x4b            */
        case KEY_RIGHT:    return 0x4d00;   /* scan 0x4d            */
        case KEY_HOME:     return 0x4700;   /* scan 0x47            */
        case KEY_END:      return 0x4f00;   /* scan 0x4f            */
        case KEY_ENTER:
        case KEY_KP_ENTER: return 0x1c0d;   /* scan 0x1c, ascii 0x0d */
        case KEY_ESCAPE:   return 0x011b;   /* scan 0x01, ascii 0x1b */
        case KEY_SPACE:    return 0x3920;   /* scan 0x39, ascii 0x20 */
        default:           return 0;        /* letters/digits/other */
    }
}

/* Map a pressed Raylib KEY_* to a release/break DOS key word. A release has bit
   7 set in the scan byte, so e.g. RIGHT (scan 0x4d) -> 0xcd00; the engine's
   get_keyboard sees klu=0xcd=205 (>=128) and clears Klx[77]. */
static uint16_t dos_release_word(int key)
{
    unsigned char scan;
    switch (key) {
        case KEY_UP:       scan = 0x48; break;
        case KEY_DOWN:     scan = 0x50; break;
        case KEY_LEFT:     scan = 0x4b; break;
        case KEY_RIGHT:    scan = 0x4d; break;
        case KEY_HOME:     scan = 0x47; break;
        case KEY_END:      scan = 0x4f; break;
        case KEY_ENTER:
        case KEY_KP_ENTER: scan = 0x1c; break;
        case KEY_ESCAPE:   scan = 0x01; break;
        case KEY_SPACE:    scan = 0x39; break;
        default:           return 0;
    }
    return (uint16_t)(((scan | 0x80) << 8) | 0x00);
}

/* Map a printable ASCII codepoint (from GetCharPressed) to a DOS key word
 * for text-entry sub-menus. Only letters + digits are supported. */
static uint16_t dos_word_for_char(int codepoint)
{
    if (codepoint < 32 || codepoint > 126) return 0;
    unsigned char c = (unsigned char)codepoint;
    unsigned char sc;

    if (c >= 'a' && c <= 'z')
        sc = (c == 'a') ? 0x1e : (unsigned char)(0x30 + (c - 'b'));
    else if (c >= 'A' && c <= 'Z') {
        unsigned char lc = (unsigned char)(c + 32);
        sc = (lc == 'a') ? 0x1e : (unsigned char)(0x30 + (lc - 'b'));
    }
    else if (c >= '1' && c <= '9')
        sc = (unsigned char)(0x02 + (c - '1'));
    else if (c == '0')
        sc = 0x0b;
    else
        return 0;   /* punctuation/space handled elsewhere; keep it simple */

    return (uint16_t)((uint16_t)sc << 8 | c);
}

/* Shared segment. */
static void *g_shm = NULL;

/* Track which physical keys are currently held down (indexed by Raylib KEY_*).
   Lets us emit a key-RELEASE (break) word the moment a held key is let go, so
   the engine clears Klx[scan] instead of treating the key as stuck pressed. */
#define MAX_KEYS 512
static unsigned char g_down[MAX_KEYS];

/* Append one DOS key word to the window->engine key ring. */
static void sirel_send_key(unsigned char scan, unsigned char ch)
{
    if (!g_shm) return;
    static uint64_t wi = 0;
    uint16_t word = (uint16_t)((uint16_t)scan << 8 | (uint16_t)ch);
    *FB_SHM_CMD_AT(g_shm, wi) = word;
    __atomic_store_n(&FB_SHM_CMD_WR(g_shm), wi + 1, __ATOMIC_RELEASE);
    wi++;
}

/* Forward one decoded key word to the engine, logging what we send so the
 * user can confirm keystrokes are actually being read from the window. */
static void sirel_forward(uint16_t word, const char *what)
{
    fprintf(stderr, "[win] KEY  %-8s word=0x%04x  (scan=0x%02x ascii=0x%02x)\n",
            what, (unsigned)word, (unsigned)(word >> 8), (unsigned)(word & 0xff));
    fflush(stderr);
    sirel_send_key((unsigned char)(word >> 8), (unsigned char)(word & 0xff));
}

/* --------------------------------------------------------------------- */
/* Framebuffer upload: the engine publishes a contiguous 640x480 framebuffer
 * into shared memory. We upload it VERBATIM as 24-bit R8G8B8 -- the engine
 * is responsible for writing contiguous pixels; the window does no
 * re-pitching or scaling. (See wiki/modules/two-process-arch.md.)
 * --------------------------------------------------------------------- */

int main(void)
{
    /* Attach the engine's framebuffer segment. If it is not there yet the
     * engine simply has not started; we wait for it. */
    for (int tries = 0; tries < 300; tries++) {
        g_shm = fb_shm_open_reader();
        if (g_shm) break;
        usleep(20000);              /* 20 ms */
    }
    if (!g_shm) {
        fprintf(stderr, "[win] FATAL: framebuffer shm never appeared "
                        "(start ./cdrv_engine first?)\n");
        return 2;
    }
    fprintf(stderr, "[win] framebuffer shm attached @ %p  (%d bytes)\n",
            (void *)FB_SHM_FB(g_shm), FB_RGB);

    /* --- Raylib window (normal, FPC-free flow) --- */
    InitWindow(FBW, FBH, "Siriel 3.5  (Raylib window)");
    SetWindowMinSize(FBW, FBH);
    SetTargetFPS(60);

    /* Do NOT let ESC close the window. Raylib's default exitKey is KEY_ESCAPE,
     * and we read WindowShouldClose() at the TOP of the loop (before polling),
     * so an ESC that closes the window would be dropped and never forwarded to
     * the engine. Disabling it keeps KEY_ESCAPE in the GetKeyPressed() queue so
     * we can forward 0x011b to Siriel's main menu. Window is still closed by
     * hand (title-bar button / Cmd+Q). */
    SetExitKey(KEY_NULL);

    /* Promote the window to visible + KEY window so GLFW delivers keystrokes.
     * We do NOT register our own GLFW key callback (see header note): Raylib
     * already owns keyboard input and exposes it via GetKeyPressed(). */
    void *wh = GetWindowHandle();          /* Cocoa NSWindow* on macOS */
    if (wh) siel_activate_app(wh);

    Image img;
    img.data = calloc(1, FB_RGB);   /* placeholder; real frame comes from shm */
    img.width  = FBW;
    img.height = FBH;
    img.format = PIXELFORMAT_UNCOMPRESSED_R8G8B8;
    img.mipmaps = 1;
    Texture tex = LoadTextureFromImage(img);
    free(img.data);
    fprintf(stderr, "[win] window+texture ready (win=%p tex=%d)\n",
            wh, tex.id);

    fb_shm_hdr *hdr = (fb_shm_hdr *)g_shm;   /* window sets hdr->quit */
    uint64_t last_seq = 0;
    long long frames = 0;
    int fresh = 0;
    static int gone = 0;
    /* Re-apply key-window promotion for the first few hundred frames so the
     * window reliably grabs keyboard focus while the user is getting ready. */
    int focus_frames = 300;

    while (1) {
        /* Window close (title-bar button / Cmd+Q): tell the engine to stop so
         * it does not keep running past the 600-step demo cap. */
        if (WindowShouldClose()) {
            hdr->quit = 1;
            fprintf(stderr, "[win] closing; signalling engine to quit\n");
            break;
        }
        /* Give the window a chance to (re)grab KEY-window focus early on. */
        /* Give the window a chance to (re)grab KEY-window focus early on. */
        if (focus_frames > 0) {
            if (wh) siel_activate_app(wh);
            focus_frames--;
        }

        /* ---- Keyboard: poll Raylib's API and forward to the engine ----
         * GetKeyPressed() returns the next queued key press (0 when empty),
         * i.e. one-shot, so held keys do not spam the menu. */
        int k;
        while ((k = GetKeyPressed()) > 0) {
            if ((unsigned)k < MAX_KEYS) g_down[(unsigned)k] = 1;
            uint16_t w = dos_key_word(k);
            if (w != 0) sirel_forward(w, GetKeyName(k));
        }
        /* Key RELEASES: the engine only ever sees a key as held once we send
         * its press word, so without this a quick press+release leaves
         * Klx[scan] stuck true and the character keeps moving. Poll each held
         * key for the release transition and forward a break word. */
        {
            int i;
            for (i = 0; i < MAX_KEYS; i++) {
                if (g_down[(unsigned)i] && IsKeyReleased(i)) {
                    g_down[(unsigned)i] = 0;
                    uint16_t w = dos_release_word(i);
                    if (w != 0) sirel_forward(w, GetKeyName(i));
                }
            }
        }
        /* Printable characters (letters/digits) for text-entry sub-menus. */
        int ch;
        while ((ch = GetCharPressed()) > 0) {
            uint16_t w = dos_word_for_char(ch);
            if (w != 0) {
                char buf[8];
                buf[0] = (char)ch; buf[1] = '\0';
                sirel_forward(w, buf);
            }
        }
        /* ---------------------------------------------------------------- */

        /* Is a newer frame available? */
        uint64_t seq = fb_shm_seq(g_shm);
        if (seq != last_seq) {
            UpdateTexture(tex, FB_SHM_FB(g_shm));   /* 24-bit R8G8B8 upload (verbatim) */
            last_seq = seq;
            fresh = 1;
        }

        BeginDrawing();
            ClearBackground((Color){ 18, 18, 22, 255 });
            /* ALWAYS draw the texture. It holds the last good frame (updated
             * above only when seq changed), so a window frame with no new shm
             * frame still shows the game instead of a cleared background.
             *
             * THIS WAS THE FLICKER: the window renders at 60 fps while the
             * engine publishes ~30 fps, so `fresh` was true only ~half the
             * frames. Every stale frame cleared the background and skipped
             * DrawTexture -> the game went dark for one 16.6 ms frame, then
             * returned -> a regular ~30 fps flicker. */
            DrawTexture(tex, 0, 0, WHITE);
            DrawFPS(8, 8);
        EndDrawing();

        /* If the engine has gone away, keep showing the last frame for a
         * bit, then exit. */
        if (seq == 0) {
            gone++;
            if (gone > 200) {   /* ~4s of no engine */
                fprintf(stderr, "[win] engine gone; exiting\n");
                break;
            }
        } else {
            gone = 0;
        }

        frames++;
        if ((frames & 63) == 0)
            fprintf(stderr, "[win] step=%lld seq=%llu close=%d\n",
                    frames, (unsigned long long)seq, WindowShouldClose());
    }

    UnloadTexture(tex);
    CloseWindow();
    fb_shm_close(g_shm);
    fprintf(stderr, "[win] host exit 0 (%lld frames)\n", frames);
    return 0;
}
