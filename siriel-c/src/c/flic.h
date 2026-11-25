/* =====================================================================
 * flic.h  -  a small step-able decoder for Autodesk FLI/FLC animation
 *            blocks (the format Animator / Animator Pro wrote to the
 *            Siriel DATADISK).  Used by the C-C engine to play a level
 *            intro (LOAD235.PAS play_ani -> aaplay), e.g. CAULDRON.DAT
 *            level 1's [FLISTART]=>AI1,ZAI1.
 *
 * This is a from-scratch C port of the headless FLIK.PAS stub (whose
 * TFliPlayer.Play / DrawFrame were no-ops) plus the well-known FLIC
 * chunk grammar (CompuPhase "The FLIC file format", Jim Kent's
 * Dr.Dobb's article).  It understands exactly the chunk types the
 * DATADISK uses:
 *
 *     FRAME_TYPE   0xF1FA  frame container (16-byte header)
 *     COLOR_256    0x04    8-bit RGB palette packets
 *     COLOR_64     0x0B    6-bit RGB palette packets (read verbatim)
 *     BYTE_RUN     0x0F    full-frame byte-oriented RLE (frame 0)
 *     DELTA_FLI    0x0C    frame-delta byte-oriented RLE (frames 1..)
 *     BLACK        0x0D    full-black frame
 *     FLI_COPY     0x10    uncompressed full frame
 *
 * The decoder is deliberately self-contained: flic.c owns the decoded
 * frame buffer and palette.  The caller (engine.c) blits the decoded
 * 8-bit image + palette into the 640x480 framebuffer on each step.
 * ===================================================================== */
#ifndef FLIC_H
#define FLIC_H

#include "datx.h"

typedef struct {
    const unsigned char *data;   /* FLI block bytes (owned by caller)   */
    int                size;      /* FLI block size in bytes             */
    int                width;     /* frame width  (from header)          */
    int                height;    /* frame height (from header)          */
    int                depth;     /* bits per pixel (from header)        */
    int                speed;     /* header speed field                  */
    int                frame_count;/* frames (from header)               */

    int                period;    /* engine steps per displayed frame    */
    int                steps;     /* steps since last frame decode       */
    int                cur;       /* index of the NEXT frame to decode   */
    int                done;      /* 1 once every frame has been shown   */

    unsigned char     *buf;       /* decoded 8-bit frame, w*h bytes      */
    unsigned char     *prev;      /* previous frame (DELTA_FLI base)     */
    int                have_buf;  /* buf holds a valid frame             */
    t_palette         pal[256];   /* current palette                     */
} flic_player_t;

/* Initialise p from a decoded FLI block.  Decodes frame 0 immediately.
 * Returns 0 on success, -1 if the block is too small / malformed. */
int  flic_init(flic_player_t *p, const unsigned char *data, int size);

/* Free the internal frame buffer. */
void flic_done(flic_player_t *p);

/* Advance one engine step.  When enough steps have elapsed it decodes the
 * next frame into p->buf / p->pal.  Returns 1 when the whole animation has
 * been shown (playback finished), 0 otherwise. */
int  flic_step(flic_player_t *p);

/* Accessors for the caller's blitter. */
const unsigned char *flic_frame(const flic_player_t *p);  /* w*h, may be NULL */
const t_palette     *flic_pal  (const flic_player_t *p);
int                  flic_w    (const flic_player_t *p);
int                  flic_h    (const flic_player_t *p);

#endif /* FLIC_H */
