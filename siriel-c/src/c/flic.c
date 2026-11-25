/* =====================================================================
 * flic.c  -  step-able FLI/FLC decoder (see flic.h).
 *
 * A FLIC file is a 128-byte header followed by a chain of FRAME_TYPE
 * chunks.  For a plain FLI (type 0xAF11) the first frame begins right
 * after the header (offset 128); the offset to the next frame is simply
 * the end of the current frame chunk, so we walk the file sequentially.
 *
 * Each FRAME_TYPE chunk (16-byte header) holds a list of subchunks; each
 * subchunk is a 6-byte header (size: DWORD LE, type: WORD LE) followed by
 * type-specific data.  Chunk sizes are padded up to an even number of
 * bytes.  We decode the frame into an 8-bit w*h buffer, applying the
 * palette (COLOR_256/COLOR_64), then one of BYTE_RUN / DELTA_FLI / BLACK
 * / FLI_COPY for the pixel image.
 *
 * DELTA_FLI stores the difference from the PREVIOUS frame, so the decoder
 * keeps the last decoded image in p->prev and decodes on top of it.  Its
 * RLE count byte has the OPPOSITE polarity to BYTE_RUN (the format's
 * famous "pit #1"): in BYTE_RUN a NEGATIVE count is a LITERAL run and a
 * POSITIVE one replicates the following byte, whereas in DELTA_FLI it is
 * reversed -- a POSITIVE count is a LITERAL run and a NEGATIVE one
 * replicates.  Both interpretations are tried (into a scratch buffer and
 * into p->buf); the correct one is the variant whose read position reaches
 * the subchunk end.  Prefer an exact fit, else the variant that does not
 * overrun the subchunk (overrunning reads past the boundary into the next
 * chunk / padding and yields garbage), else the one closest to the end.
 * ===================================================================== */
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "flic.h"

/* ---- little-endian readers ---------------------------------------- */
static inline unsigned int rd16(const unsigned char *d, int o)
{
    return (unsigned int)(unsigned char)d[o] |
           ((unsigned int)(unsigned char)d[o + 1] << 8);
}
static inline unsigned int rd32(const unsigned char *d, int o)
{
    return (unsigned int)(unsigned char)d[o] |
           ((unsigned int)(unsigned char)d[o + 1] << 8) |
           ((unsigned int)(unsigned char)d[o + 2] << 16) |
           ((unsigned int)(unsigned char)d[o + 3] << 24);
}

/* ---- palette (COLOR_256 = 4, COLOR_64 = 11) ------------------------ */
/* Palettes are a sequence of packets: (skip:WORD, copy:WORD) followed by
 * copy RGB triplets.  copy==0 means "fill the remaining 256 entries".
 *
 * Two encodings exist:
 *   COLOR_256 (type 4)  -- 8-bit RGB entries, written verbatim.
 *   COLOR_64  (type 11) -- 6-bit RGB entries (0..63); each channel is expanded
 *                          to 8-bit.  The Siriel DAT uses COLOR_64 for the AI1
 *                          intro frame 0, so the values MUST be scaled --
 *                          reading them verbatim leaves the whole palette
 *                          ~6x too dark.
 *
 *  Packet layout (matches the FLI spec and the libflic reference decoder):
 *     WORD  number of colour-change packets in the chunk
 *     per packet:
 *        BYTE  number of palette entries to skip before this run
 *        BYTE  number of entries to change (0 means "fill the remaining 256")
 *        3*copy bytes of RGB (R, G, B in that order)
 *
 *  BUG FIX (2026-11-23): skip and copy are single BYTES, not WORDS.  The old
 *  code read them with rd16() (4 bytes per packet header).  That over-consumed
 *  two extra bytes per packet and shifted the RGB payload two bytes later, so
 *  palette index 0 picked up bytes from the skip/copy fields instead of the
 *  real first colour.  For AI1 frame 0 that decoded index 0 to (0,56,42),
 *  which -- scaled -- looked like a green/teal wash over the whole black
 *  background ("black looked green").  Reading them as BYTES puts the payload
 *  back at the correct offset, so index 0 is (0,0,0) = black. */
static void decode_palette(const unsigned char *d, int sdata, int end,
                           t_palette *pal, int is_64bit)
{
    unsigned int cnt;
    int i, pos = sdata;

    if (pos + 2 > end) return;
    cnt = rd16(d, pos); pos += 2;   /* packet count */

    for (i = 0; i < (int)cnt && pos + 2 <= end; i++) {
        unsigned int skip, copy, j;
        skip = d[pos];      pos += 1;   /* skip is a BYTE (was rd16 -> WORD) */
        copy = d[pos];      pos += 1;   /* copy  is a BYTE (was rd16 -> WORD) */
        if (copy == 0) {
            for (j = skip; j < 256 && pos + 3 <= end; j++) {
                unsigned char r = d[pos], v = d[pos + 1], b = d[pos + 2];
                pos += 3;
                if (is_64bit) {
                    r = (unsigned char)(r << 2);
                    v = (unsigned char)(v << 2);
                    b = (unsigned char)(b << 2);
                }
                pal[j].r = r; pal[j].v = v; pal[j].b = b;
            }
            break;
        }
        for (j = 0; j < copy && pos + 3 <= end && (skip + j) < 256; j++) {
            unsigned char r = d[pos], v = d[pos + 1], b = d[pos + 2];
            pos += 3;
            if (is_64bit) {
                r = (unsigned char)(r << 2);
                v = (unsigned char)(v << 2);
                b = (unsigned char)(b << 2);
            }
            pal[skip + j].r = r; pal[skip + j].v = v; pal[skip + j].b = b;
        }
    }
}

/* ---- full-frame byte RLE (BYTE_RUN = 15) -------------------------- */
/* Each scan line: a throw-away packet-count byte, then packets.  A
 * NEGATIVE count is a LITERAL run (|count| data bytes copied in order);
 * a POSITIVE count replicates the single following byte count times.
 * Decoding continues until the line's width pixels are filled. */
static void decode_brun(const unsigned char *d, int sdata, int end,
                        int w, int h, unsigned char *img)
{
    int p = sdata, idx = 0, row;

    for (row = 0; row < h && p < end; row++) {
        p++;  /* ignore the per-line packet count (FLI legacy byte) */
        while (p < end && idx < w * (row + 1)) {
            int cnt = (signed char)d[p++];
            if (cnt < 0) {
                int n = -cnt, k;
                for (k = 0; k < n && p < end && idx < w * (row + 1); k++)
                    img[idx++] = d[p++];
            } else {
                int k;
                unsigned char v = d[p++];
                for (k = 0; k < cnt && idx < w * (row + 1); k++)
                    img[idx++] = v;
            }
        }
    }
}

/* ---- one DELTA_FLI scan line -------------------------------------- */
/* Returns the new read position. */
static int decode_delta_line(const unsigned char *d, int p, int end,
                             int w, int line, int wrow,
                             unsigned char *img, int neg_is_literal)
{
    int npkt = (int)(unsigned char)d[p++];
    int col = 0, i;

    for (i = 0; i < npkt && p + 2 <= end; i++) {
        int skip = (int)(unsigned char)d[p++];
        int count = (signed char)d[p++];
        int c = count;
        if (c > 127) c -= 256;          /* sign-expand the count byte */
        col += skip;
        if (neg_is_literal) {
            /* negative => literal, positive => replicate */
            if (c < 0) {
                int n = -c, k;
                for (k = 0; k < n && p + k < end && col < w; k++)
                    img[(long)line * wrow + col + k] = d[p + k];
                p += n;
                col += n;
            } else {
                unsigned char v = d[p++];
                int k;
                for (k = 0; k < c && col < w; k++)
                    img[(long)line * wrow + col++] = v;
            }
        } else {
            /* positive => literal, negative => replicate (BRUN polarity) */
            if (c < 0) {
                unsigned char v = d[p++];
                int k;
                for (k = 0; k < -c && col < w; k++)
                    img[(long)line * wrow + col++] = v;
            } else {
                int n = c, k;
                for (k = 0; k < n && p + k < end && col < w; k++)
                    img[(long)line * wrow + col + k] = d[p + k];
                p += n;
                col += n;
            }
        }
        if (col > w) break;
    }
    return p;
}

/* Decode one DELTA_FLI frame: leading WORDs are first-differing line and
 * line count.  base, when non-NULL, is copied into dst first.  Returns the
 * read position after the last consumed byte. */
static int decode_delta(const unsigned char *d, int sdata, int end,
                        int w, int h, const unsigned char *base,
                        unsigned char *dst, int neg_is_literal)
{
    int startline = (int)rd16(d, sdata);
    int nlines    = (int)rd16(d, sdata + 2);
    int p         = sdata + 4, ln;

    if (base) memcpy(dst, base, (size_t)w * h);
    for (ln = 0; ln < nlines; ln++) {
        int line = startline + ln;
        if (line < 0 || line >= h) continue;
        p = decode_delta_line(d, p, end, w, line, w, dst, neg_is_literal);
    }
    return p;
}

/* ---- frame walk ---------------------------------------------------- */
/* Decode the FRAME_TYPE chunk at offset `off` into p->buf, decoding deltas
 * on top of `base` (the previous frame, or NULL for the first frame). */
static void flic_decode_frame(flic_player_t *p, const unsigned char *d,
                              int size, int off, const unsigned char *base)
{
    int csize, end, sub, w = p->width, h = p->height;

    if (off + 16 > size) return;
    csize = (int)rd32(d, off);
    if (csize < 16) return;
    end = off + csize;
    if (end > size) end = size;

    if (!base) memset(p->buf, 0, (size_t)w * h);

    sub = off + 16;   /* skip the 16-byte FRAME_TYPE header */
    while (sub + 6 <= end) {
        int ssz = (int)rd32(d, sub);
        int stype = (int)rd16(d, sub + 4);
        int sdata = sub + 6;

        if (ssz < 6) break;
        if (sdata > end) { sub += ssz; continue; }

        if (stype == 4 || stype == 11) {
            /* COLOR_64 (type 11) is 6-bit and must be scaled; COLOR_256 (4) is 8-bit. */
            decode_palette(d, sdata, end, p->pal, stype == 11);
        } else if (stype == 15) {
            decode_brun(d, sdata, end, w, h, p->buf);
        } else if (stype == 12) {
            /* DELTA_FLI: try both polarities; keep the one that consumes
               the subchunk exactly to its end.  Variant A is decoded into
               a scratch buffer, variant B directly into p->buf. */
            {
                unsigned char *scratch =
                    (unsigned char *)malloc((size_t)w * h);
                int pA, pB, useA;
                if (!scratch) {
                    /* no scratch: decode the better-guess variant A in place */
                    decode_delta(d, sdata, end, w, h, base, p->buf, 1);
                } else {
                    pA = decode_delta(d, sdata, end, w, h, base, scratch, 1);
                    pB = decode_delta(d, sdata, end, w, h, base, p->buf, 0);
                    /*
                     * The correct DELTA_FLI polarity consumes the subchunk
                     * exactly to its end (up to the even-rounding padding
                     * byte).  Prefer an exact fit; if neither is exact,
                     * prefer the variant that does NOT overrun the subchunk
                     * (the under-consumer), because overrunning means it read
                     * past the boundary into the next chunk / padding and the
                     * pixels are garbage.  When both under-consume, keep the
                     * one whose read position is closer to `end`.
                     *
                     * NOTE: the old `else if (pA > pB) use A` rule was wrong:
                     * it picked variant A whenever A consumed more bytes.  In
                     * CAULDRON.DAT pA < pB so B was kept by accident (correct,
                     * since B is the true DELTA_FLI polarity: positive=literal,
                     * negative=replicate); in GBALL.DAT pA > pB, so A was
                     * wrongly kept and the frame "fell apart".  Both DATs
                     * actually want variant B.
                     */
                    if (pA == end) {
                        useA = 1;
                    } else if (pB == end) {
                        useA = 0;
                    } else if (pA > end && pB > end) {
                        useA = ((pA - end) < (pB - end));  /* smaller overrun */
                    } else if (pA > end) {
                        useA = 0;                          /* A overruns, B safe */
                    } else if (pB > end) {
                        useA = 1;                          /* B overruns, A safe */
                    } else {
                        useA = (pA > pB);                  /* both under: closer */
                    }
                    if (useA) memcpy(p->buf, scratch, (size_t)w * h);
                    /* else p->buf already holds the (exact-fit / under-consuming) variant B */
                    free(scratch);
                }
            }
        } else if (stype == 13) {
            /* BLACK: p->buf is already zeroed when there is no base */
        } else if (stype == 16) {
            int n = (end - sdata < (int)(w * h)) ? (end - sdata) : (w * h);
            memcpy(p->buf, d + sdata, n);
        }
        /* all other subchunks (LABEL, CEL_DATA, PSTAMP, ...) are ignored */

        sub += ssz;
        if (ssz & 1) sub++;   /* even-rounding padding */
    }
    p->have_buf = 1;
}

/* Count the real number of frames in the block by walking the FRAME_TYPE
   chunks from offset 128 to the end.  The Siriel DAT convention is that the
   header's `Frames` field is ONE LESS than the real count (verified for all
   five FLI blocks in CAULDRON.DAT: Frames=36 -> 37 real frames, etc.), so the
   original aaplay player walks every frame until the block end rather than
   trusting the header field.  Trusting the header field alone would stop one
   frame early and drop the final frame -- the intro would then "draw the
   picture for a short period" and stop before the whole animation plays. */
static int flic_count_frames(const unsigned char *data, int size)
{
    int pos = 128, cnt = 0;
    while (pos + 16 <= size) {
        int csize = (int)rd32(data, pos);
        if (csize < 16 || pos + csize > size) break;   /* no more real frames */
        cnt++;
        pos += csize;
    }
    return cnt;
}

int flic_init(flic_player_t *p, const unsigned char *data, int size)
{
    int pos;

    memset(p, 0, sizeof(*p));
    if (!data || size < 128 + 16) return -1;

    p->data = data;
    p->size = size;
    p->width   = rd16(data, 8);
    p->height = rd16(data, 10);
    p->depth  = rd16(data, 12);
    if (!p->depth) p->depth = 8;
    p->speed  = rd32(data, 16);
    /* Walk the chunks: the DAT header's Frames field is one short of the
       real count, so count the actual frames (see flic_count_frames). */
    {
        int cf = flic_count_frames(data, size);
        p->frame_count = (cf > 0) ? cf : 1;
    }

    /* one frame every ~speed/70 s, at the C-C engine's ~30 steps/s. */
    p->period = (p->speed * 30) / 70;
    if (p->period < 1) p->period = 1;

    p->buf = (unsigned char *)malloc((size_t)p->width * p->height);
    p->prev = (unsigned char *)malloc((size_t)p->width * p->height);
    if (!p->buf || !p->prev) { free(p->buf); free(p->prev); return -1; }
    memset(p->buf, 0, (size_t)p->width * p->height);
    memset(p->prev, 0, (size_t)p->width * p->height);
    memset(p->pal, 0, sizeof(p->pal));

    pos = 128;  /* first frame starts right after the header (FLI) */
    flic_decode_frame(p, data, size, pos, NULL);  /* frame 0: palette+image */
    memcpy(p->prev, p->buf, (size_t)p->width * p->height);
    p->cur = 1;   /* frame 0 shown; next to decode is frame 1 */
    p->steps = 0;
    p->have_buf = 1;
    return 0;
}

int flic_step(flic_player_t *p)
{
    int size, pos, i;

    if (!p || p->done) return 1;

    p->steps++;
    if (p->steps < p->period) return 0;
    p->steps = 0;

    if (p->cur >= p->frame_count) { p->done = 1; return 1; }

    size = p->size;
    pos = 128;
    for (i = 0; i < p->cur && pos + 16 <= size; i++) {
        int csize = (int)rd32(p->data, pos);
        pos += (csize < 16) ? (16 - pos) : csize;
    }

    if (pos + 16 <= size)
        /* decode on top of the previous frame; a void frame (csize==16)
           has no subchunks so this leaves p->buf unchanged. */
        flic_decode_frame(p, p->data, size, pos, p->prev);

    memcpy(p->prev, p->buf, (size_t)p->width * p->height);
    p->cur++;
    if (p->cur >= p->frame_count) p->done = 1;
    return 0;
}

const unsigned char *flic_frame(const flic_player_t *p) { return p->buf; }
const t_palette     *flic_pal  (const flic_player_t *p) { return p->pal; }
int                  flic_w    (const flic_player_t *p) { return p->width;  }
int                  flic_h    (const flic_player_t *p) { return p->height; }

void flic_done(flic_player_t *p)
{
    if (!p) return;
    free(p->buf);
    free(p->prev);
    p->buf = NULL;
    p->prev = NULL;
    p->have_buf = 0;
}
