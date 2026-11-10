/* =====================================================================
 * fb_shm.h  -  POSIX shared-memory bridge for the two-process Siriel
 *              windowed build.
 *
 * The Siriel 3.5 FPC engine (cdrv_engine) and the Raylib window
 * (cdrv_window) are SEPARATE processes. The engine owns no window (FPC
 * as a runtime cannot safely drive macOS AppKit -> SIGILL, see
 * wiki/modules/two-process-arch.md). The window owns no engine.
 *
 * They are joined ONLY by a POSIX shared-memory segment that carries:
 *   1. the latest 640x480x24 framebuffer (FrameRGB, 921600 bytes) plus a
 *      monotonically increasing frame sequence counter, and
 *   2. a small KEY RING (window -> engine) so real keyboard input from the
 *      visible window reaches the engine and navigates its menus.
 *
 *   cdrv_engine (FPC) : writes FrameRGB into the segment, bumps seq;
 *                       reads the key ring and feeds keys to the engine.
 *   cdrv_window (C)   : loads seq; if newer, copies the frame and displays
 *                       it; on key press, appends a DOS key word to the ring.
 *
 * Single-slot producer/consumer for each direction: a single 64-bit
 * sequence word with release/acquire semantics provides the happens-before
 * that makes the bytes visible. No locks required.
 * ===================================================================== */
#ifndef FB_SHM_H
#define FB_SHM_H

#include <stdint.h>
#include <stddef.h>

#define FBW   640
#define FBH   480
#define FB_RGB (FBW * FBH * 3)   /* 921600 bytes, 24-bit expanded */

/* Size of the key ring (DOS key words). Large enough that slow menu
 * navigation never wraps and drops a key before the engine consumes it. */
#define CMD_N 16

/* Header layout (engine->framebuffer follows it):
 *   seq       frame publish sequence (engine bumps AFTER copying FrameRGB)
 *   cmd_wr    key-ring WRITE index (window bumps AFTER appending a key)
 *   cmd[]     key ring: CMD_N DOS key words  (scan<<8 | ascii)
 *   w,h,bpp   framebuffer geometry
 *
 * DOS key word format (matches Siriel's JXGRAF menu matcher):
 *   LOW byte = ASCII char (0 for arrows/nav), HIGH byte = scan code.
 *   press : scan<<8 | ascii      e.g. UP=0x4800  ENTER=0x1c0d  ESC=0x011b
 *   release: scan<<8 | 0x00       e.g. UP=0x4800  (scan byte only)
 */
typedef struct {
    uint64_t seq;      /* bumped by the writer AFTER the frame is copied.
                          0 = no frame published yet. */
    uint64_t cmd_wr;   /* key-ring write index (window side). 0 = empty. */
    uint16_t cmd[CMD_N];
    uint32_t w;        /* framebuffer width  (640)   */
    uint32_t h;        /* framebuffer height (480)   */
    uint32_t bpp;      /* bits per pixel (24)        */
    uint32_t reserved; /* alignment / future use     */
    uint64_t quit;     /* window->engine: 1 when the window is closing */
} fb_shm_hdr;

#define FB_SHM_HDR_SZ  sizeof(fb_shm_hdr)
#define FB_SHM_SIZE    (FB_SHM_HDR_SZ + FB_RGB)   /* total segment size */

/* The framebuffer bytes live right after the header+ring. */
#define FB_SHM_FB(seg)  ((unsigned char *)(seg) + FB_SHM_HDR_SZ)

/* --- key-ring accessors --- */
/* Current write index (window bumps this after appending a key). */
#define FB_SHM_CMD_WR(seg)  (((fb_shm_hdr *)(seg))->cmd_wr)
/* Address of ring slot i (indices wrap inside the ring). */
#define FB_SHM_CMD_AT(seg, i)  (&(((fb_shm_hdr *)(seg))->cmd[(i) % CMD_N]))

/* Name of the shm object. Overridable via the SIRIEL_FB_NAME env var;
 * defaults to "siriel_fb". shm_open() is called with a leading '/'. */
#define FB_SHM_DEFAULT_NAME  "siriel_fb"

/* Attach the segment for WRITING. Creates it if it does not exist.
 * Returns a pointer to the segment (use it as the base), or NULL. */
void *fb_shm_open_writer(void);

/* Attach the segment for READING. Fails if it does not exist.
 * Returns a pointer to the segment, or NULL. */
void *fb_shm_open_reader(void);

/* Detach. Safe to call on NULL. */
void fb_shm_close(void *seg);

/* Publish a frame the writer just copied into FB_SHM_FB(seg).
 * Bumps seq with a release store so the reader observes the fresh bytes. */
void fb_shm_publish(void *seg);

/* Load the current sequence (acquire). Non-zero means a fresh frame is
 * available (and FB_SHM_FB(seg) holds it). */
uint64_t fb_shm_seq(void *seg);

#endif /* FB_SHM_H */
