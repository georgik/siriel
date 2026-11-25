/* =====================================================================
 * engine.c  -  C re-implementation of the Siriel 3.5 ENGINE CORE
 *              (the engine_* procedures that used to live in
 *              src/pascal/SI35.PAS, unit SIRIEL3).
 *
 * THIS IS THE "C-C" ENGINE: it removes the FPC/Pascal dependency from the
 * engine half of the two-process build. The C host (host_engine.c) drives
 * it EXACTLY as before -- it calls the same Pascal-mangled entry points
 * and reads the same framebuffer symbol -- so the window (Raylib) and the
 * shared-memory bridge are UNCHANGED.
 *
 * How the ABI stays identical:
 *   * Every exported symbol is forced to the exact FPC-mangled name with
 *     an __asm__ label, e.g.  void engine_init(void) __asm__("P$SIRIEL3_$$_ENGINE_INIT");
 *     host_engine.c already declares `extern void P$SIRIEL3_$$_ENGINE_INIT(void);`
 *     so it compiles with NO edits.
 *   * The framebuffer is the SAME symbol the host reads:
 *     `unsigned char frame_rgb[FB_RGB] __asm__("U_$VIDBASE_$$_FRAMERGB");`
 *
 * What is intentionally SIMPLIFIED (per the migration strategy: "it is OK
 * to be not 100% correct/matching -- that mattered only in low-level
 * functions; get C-C running, then finetune"):
 *   * SOUND  -> C stubs (pust / reload_sound / Initsbx ... are no-ops).
 *   * GRAPHICS-> a small self-contained C framebuffer renderer
 *     (8-bit VideoBuffer + palx palette + expand_frame) that draws a
 *     distinct frame per run-loop state. The real raster engine
 *     (JxGRAF / vid_dispatch.inc) is NOT ported yet -- it is "not reachable"
 *     from this skeleton and is marked TODO. The framebuffer path that the
 *     window displays (FrameRGB) IS wired, so the C-C loop is proven.
 *   * KEYBOARD-> already C-owned: engine_press_key() stores the pending key;
 *     the state machine treats a pending key as a menu choice.
 *
 * The run-loop state machine mirrors SI35.PAS (es_state):
 *   0 boot -> 10 intro menu -> 11 menu tick -> 12 level selector ->
 *   30 objective -> 21 gameplay -> 22 level-complete -> (loop) -> 9 done.
 *   States 13/23/40/41/24 are implemented as draw-and-advance stubs so the
 *   case is complete even though the default play-through does not visit
 *   them.
 * ===================================================================== */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>   /* getenv / atoi : SIRIEL_AUTO_RUN standalone flag */
#include <stdint.h>
#include "fb_shm.h"
#include "port.h"
#include "datx.h"     /* Phase A: faithful DAT reader (BLOCKX.PAS port) */
#include "siriel.h"   /* Phase C/D: levely^, load_basic_config, intro menu */
#include "fb_draw.h"  /* shared 8-bit back-buffer drawing primitives */
#include "flic.h"     /* FLI/FLC intro-animation decoder (LOAD235.PAS play_ani) */

/*
 * Platform symbol prefix. macOS/arm64 (any __APPLE__) prepends a leading '_'
 * to every C identifier, so the FPC-mangled entry points below must be
 * emitted with a leading '_' to match the references that clang generates in
 * host_engine.c (those `extern` declarations are mangled by the compiler
 * automatically). Linux/ELF uses no leading underscore, so the prefix is
 * empty there. One source file, correct on both.
 */
#if defined(__APPLE__)
#  define FPC_SYM_PREFIX "_"
#else
#  define FPC_SYM_PREFIX ""
#endif

/* --------------------------------------------------------------------- */
/* Framebuffer: the SAME symbol the C host reads.                        */
/* 640x480x24 expanded RGB (vid_dispatch.inc expand_frame output).       */
/* --------------------------------------------------------------------- */
#define FBW 640
#define FBH 480
#define VBUFSZ (FBW * FBH)          /* 8-bit 8-bit-per-pixel back buffer   */

/* The expanded 24-bit framebuffer. Forced to the Pascal-mangled name so
 * host_engine.c's `extern unsigned char U_$VIDBASE_$$_FRAMERGB[FB_RGB];`
 * resolves to THIS memory.
 *
 * Explicit alignment keeps macOS's linker quiet: a 921600-byte common
 * object would otherwise default to 0x8000 alignment, which exceeds the
 * __DATA segment maximum (0x4000) and triggers an "reducing alignment"
 * warning. 4096 is plenty for a byte buffer and is safe on every platform.
 */
unsigned char frame_rgb[FB_RGB] __asm__(FPC_SYM_PREFIX "U_$VIDBASE_$$_FRAMERGB") __attribute__((aligned(4096)));

/* 8-bit back buffer + palette (mirror vidbase.pas: VideoBuffer, palx).
 * palx is the real 256-entry t_palette (record{r,v,b}) loaded from the DAT
 * PALETA block (Phase A) -- NOT a synthetic palette. */
static unsigned char video_buffer[VBUFSZ];
static t_palette palx[256];

/* --------------------------------------------------------------------- */
/* SPRITE SHEETS (ANIMING.PAS / SI35.PAS).                               */
/*                                                                       */
/* load_pohyby() decodes the GZAL character sheet (MAIN.DAT) and         */
/* load_anim() decodes the GANIM animation sheet (the game DAT) into the */
/* framebuffer; getseg() then carves the 16x16 tiles out of it into the  */
/* two persistent sprite tables below.  These mirror the Pascal          */
/* `ar: ^long_panak` (sir_nums*256 bytes) and `anim: ^animacia`          */
/* (anim_nums*256 bytes) -- 16x16 = 256 bytes per cell, 1-based in       */
/* Pascal, so the C table index N holds sprite N (getseg writes          */
/* aw[num*256 .. num*256+255]).                                          */
/* --------------------------------------------------------------------- */
#define SIR_NUMS   52      /* AKTIV35.PAS: sir_nums                    */
#define ANIM_NUMS  80      /* AKTIV35.PAS: anim_nums                   */
static unsigned char ar[SIR_NUMS * 256];      /* ^long_panak: character tiles  */
static unsigned char anim[ANIM_NUMS * 256];   /* ^animacia : animation frames  */

/* SI35.PAS panak animation counters.  anic selects one of an object's four
   anim frames (anic + anx[obr]); bloing is the freezing-effect counter.
   anx[fm]:=fm*4 (load_anim_def).  Declared here (next to anim^) so the
   loaders below -- cc_load_anim / cc_load_veci / cc_print_predmet2 -- can
   see them. */
static int            anic, bloing;
static unsigned short anx[256];

/* g_frame / g_frame_fill : the C-C stand-in for the Pascal old_frame
 * (TFrame) box used by the level selector.  Mirrors SI35.PAS:930
 * old_frame.init(no_handle, input_file, frame_gif='>GLIST', false):
 * the GLIST block in MAIN.DAT is a Jx1 sheet 129x16 = 1 metadata column
 * (x=0) + 8 border tiles of 16x16 (x=1..128).  TFrame.init reads the
 * metadata from pixels (0,0..3) and carves the 8 tiles into the handle
 * via getsegxms(ha_frame,1+f*size_x,0,size_x,size_y,f).  g_frame holds
 * those 8 cells (256 bytes each); g_frame_fill holds fill_color.        */
#define FRAME_NUMS   8      /* GLIST border tiles (TFrame.f=0..7)      */
static unsigned char g_frame[FRAME_NUMS * 256];   /* ^ha_frame : GLIST border cells */
static unsigned char g_frame_fill;        /* TFrame.fill_color (GLIST (0,3))  */
static unsigned int  g_frame_sx;          /* TFrame.size_x  (GLIST (0,1))     */
static unsigned int  g_frame_sy;          /* TFrame.size_y  (GLIST (0,2))     */

/* g_handle4 : the C-C stand-in for the Pascal XMS handle[4] object-image
   handle (LOAD235.PAS load_predmet / print_predmet2 / zobraz_vec).  handle[4]
   holds the GVECI sprite sheet (CONFIG [VECI] => 'GVECI'), carved 16x16 into
   it by cc_load_veci().  The C-C engine has no XMS layer, so this plain table
   plays the SAME role: cc_print_predmet2() reads sprite `obr` out of it via
   putseg2_ar() -- a faithful port of putseg2xms(handles[4],...) reading the
   sprite from the handle and blitting non-(colour 13) pixels to the screen.
   load_predmet carves cells f+ff*20 (ff=0..11,f=0..19) and f+400 (f=0..14),
   so indices reach 414 -> size generously. */
#define HANDLE4_CELLS 512
static unsigned char g_handle4[HANDLE4_CELLS * 256];

/* resx/resy mirror the SI35.PAS globals set at SI35.PAS:842 (both 16).
 * load_pohyby / cc_load_anim carve 16x16 cells with these. */
static unsigned int resx = 16;
static unsigned int resy = 16;

/* HUD_VYPISY = vypisy (AKTIV35.PAS) -- the top line of the bottom HUD bar.
   HUD_VYPISX = vypisx (AKTIV35.PAS) -- the score column's left edge. */
#define HUD_VYPISY  460
#define HUD_VYPISX  250

/* --------------------------------------------------------------------- */
/* DAT-loaded bitmap font.  FAITHFUL port of the original engine font    */
/* pipeline (JxGRAF.PAS + BLOCKX.PAS + LOAD235.PAS).                     */
/*                                                                       */
/*   SI35.PAS engine_init() calls set_font(def_font)   (SI35.PAS:936).   */
/*   def_font = 'FMOD'  (8x16),  def_font2 = 'FMAIN' (8x8)               */
/*                                                     (AKTIV35.PAS:158)  */
/*   set_font(s)  (LOAD235.PAS:2025):                                     */
/*      if s=def_font or def_font2 -> font_load_block(input_file,s)      */
/*      else                        -> font_load_block(zvukovy_subor,s)  */
/*   font_load_block() (BLOCKX.PAS:365):                                 */
/*      loadblock_array(sub,kluc,flx^) -> the resource block;            */
/*      read the leading NUL-terminated header run into st1;             */
/*      get_parax() + val() parse 'fdlzka fx fy ftransf';                */
/*      fontik[f]:=flx^[f+num]  (f=1..fdlzka);                           */
/*      setstartchar(-ftransf); SetFont(@fontik,fx,fy).                  */
/*   The DAT FMOD block header is exactly "4096 8 16 0" (fdlzka=4096,    */
/*   fx=8, fy=16, ftransf=0), so the 4096 bitmap bytes (256 glyphs x     */
/*   16 rows, 1 byte/row, MSB-first) start at block offset 11 and are     */
/*   copied into fontik[1..4096] via fontik[f]:=flx^[f+12].              */
/*                                                                       */
/*   Rendering core (JxGRAF.PAS Printr/Printx, ~:2133): lit pixels        */
/*   (b>=128) are drawn; the index math uses CharDX/CharDY/posuv/         */
/*   FontScaleX/Y exactly as the original.  It writes into the 8-bit     */
/*   video_buffer through fb_vput(), which fb_expand() later recolors.   */
/* --------------------------------------------------------------------- */

/* fontik[1..4096]: the current font bitmap, 1-based like Pascal           */
/* array[1..4096] of byte.  fontik[g*CharDY + row] is row 'row' of         */
/* glyph 'g' (one byte per row, MSB-first).  Index 0 is unused (Pascal     */
/* declares fontik:array[0..4096]; the core never reads index 0).         */
static unsigned char fontik[4097];

/* TEMP debug: copy fontik[] to a caller buffer (for verification). */
void __dbg_font(unsigned char *out, int n)
{
    int i;
    for (i = 0; i < n && i < 4097; i++) out[i] = fontik[i];
}

/* font rendering globals (mirror JxGRAF.PAS var section) */
static int  CharDX      = 0;   /* character width  */
static int  CharDY      = 0;   /* character height */
static int  FontScaleX  = 1;   /* multiplication factors                     */
static int  FontScaleY  = 1;
static int  posuv       = 0;   /* startchar: the glyph index of ASCII '0'    */

/* SetFontScale(ScaleX,ScaleY) -- JxGRAF.PAS:2491 */
static void SetFontScale(int sx, int sy)
{
    if (sx <= 0 || sy <= 0) return;
    FontScaleX = sx;
    FontScaleY = sy;
}

/* SetStartChar(posx) -- JxGRAF.PAS:2502 */
static void SetStartChar(int posx)
{
    posuv = posx;
}

/* SetFont(FontPtr,w,h) -- JxGRAF.PAS:2507.  The Font pointer is recorded in
 * the Pascal global 'Font'; the C render core reads the fontik[] array
 * directly, so only the metrics matter here. */
static void SetFont(const unsigned char *FontPtr, int w, int h)
{
    (void)FontPtr;
    if (w == 0 || h == 0) return;
    CharDX = w;
    CharDY = h;
    SetFontScale(1, 1);
}

/* get_parax(s,vystup,num) -- BLOCKX.PAS:353 (inline, non-EXT path).  It
 * walks s from index 'num' (1-based), accumulating the non-space, non-NUL
 * characters intoystup, and advances num until it passes length(s) or hits
 * a space / NUL -- exactly the Pascal repeat-until loop. */
static void get_parax(const unsigned char *s, int s_len,
                      char *vystup, int *num)
{
    int n = 0;
    vystup[0] = '\0';
    while (1) {
        unsigned char ch = (*num >= 1 && *num <= s_len) ? s[*num] : 0;
        if (ch != ' ' && ch != 0) {
            if (n < 63) vystup[n++] = (char)ch;
        }
        (*num)++;
        if ((*num) > s_len) break;          /* num > length(s) */
        if (s[*num] == ' ' || s[*num] == 0) break;
    }
    vystup[n] = '\0';
}

/* font_load_block(sub,kluc) -- BLOCKX.PAS Font_Load_block.  Loads the block
 * into a 1-based view of the raw bytes, parses its header, copies the bitmap
 * into fontik[1..fdlzka], and installs it with SetFont.  Reuses the faithful
 * DAT reader dat_load_array() (the BLOCKX.Loadblock_array port). */
static void font_load_block(const char *sub, const char *kluc)
{
    /* +SLACK so the Pascal's 1-byte past-the-end read (flx^[fdlzka+num]) is
     * well-defined; it reads 0, matching a heap block allocated to size. */
    unsigned char blk[4107 + 16];
    unsigned char st1[256];
    char          st2[64];
    long          v;
    int           blksz, num, f, s_len;
    unsigned long fdlzka, fx, fy, ftransf;

    memset(blk, 0, sizeof(blk));
    blksz = dat_load_array(sub, kluc, blk, sizeof(blk));
    if (blksz <= 0) return;                 /* block missing -> leave font as-is */

    /* st1 := the leading NUL-terminated run of the block (the header).
     * flx^[k] (1-based) == blk[k-1] (0-based). */
    num = 1; s_len = 0;
    while (1) {
        unsigned char ch = blk[num - 1];    /* flx^[num] */
        if (ch != 0) { if (s_len < 255) st1[s_len + 1] = ch; s_len++; }
        num++;
        if (blk[num - 1] == 0) break;       /* until flx^[num]=0 */
    }

    /* get_parax + val parse the four header tokens: fdlzka fx fy ftransf.
     * num is reset to 1 before the first token (mirrors the Pascal). */
    num = 1;
    get_parax(st1, s_len, st2, &num); val(st2, &v); fdlzka   = (unsigned long)v;
    get_parax(st1, s_len, st2, &num); val(st2, &v); fx       = (unsigned long)v;
    get_parax(st1, s_len, st2, &num); val(st2, &v); fy       = (unsigned long)v;
    get_parax(st1, s_len, st2, &num); val(st2, &v); ftransf  = (unsigned long)v;

    /* fontik[f] := flx^[f+num]  (f=1..fdlzka).
     * flx^[k] (1-based) == blk[k-1] (0-based), so fontik[f] = blk[f+num-1]
     * = blk[idx] with idx = f+num-1.  (Reading blk[idx-1] was an off-by-one
     * that shifted every glyph by one row.) */
    for (f = 1; f <= (int)fdlzka; f++) {
        int idx = f + num - 1;
        fontik[f] = (idx >= 1 && idx <= blksz) ? blk[idx] : 0;
    }

    SetStartChar(-(int)ftransf);
    SetFont(fontik, (int)fx, (int)fy);
}

/* set_font(s) -- LOAD235.PAS:2025.  def_font='FMOD' / def_font2='FMAIN'
 * (AKTIV35.PAS) load from the main data DAT (input_file = 'MAIN.DAT'); any
 * other font name loads from the sound DAT (zvukovy_subor). */
static void set_font(const char *s)
{
    if (strcmp(s, "FMOD") == 0 || strcmp(s, "FMAIN") == 0)
        font_load_block("MAIN.DAT", s);
    else
        font_load_block(g_cfg.zvukovy_subor, s);
}

/* font_draw_str: faithful JxGRAF.PAS Printr / Printx rendering core.  Draws
 * the NUL-terminated string with the current DAT font; each lit pixel
 * (row byte b>=128) writes `col` into the 8-bit video_buffer.  The index
 * arithmetic, MSB-first bit walk, ByteRange and FontScaleX/Y all mirror the
 * Pascal verbatim. */
static void font_draw_str(const char *s, int x, int y,
                          unsigned char col, int roll)
{
    int c, n, h;
    unsigned int  Index;
    unsigned char b;
    int  CDX = CharDX, CDY = CharDY;
    int  ByteRange, Size;

    if (CDX == 0) return;                 /* Font==NIL guard */
    Size      = FontScaleX * CDX;
    ByteRange = 1 + ((CDX - 1) >> 3);
    for (c = 0; s[c]; c++) {
        Index = ((unsigned char)s[c] + posuv) *
                (unsigned int)ByteRange * (unsigned int)CDY - 1u;
        int i = y;
        for (n = 0; n < CDY; n++) {
            int DataIndex = 0;
            for (h = 0; h < CDX; h++) {
                if ((h & 7) == 0) {
                    Index++;
                    b = (Index <= 4096) ? fontik[Index] : 0;
                }
                if (b >= 128)
                    fb_vput(x + h + c * CDX, y + n, col);
                DataIndex += FontScaleX;
                b = (unsigned char)(b << 1);
            }
            i += FontScaleY;
        }
    }
}


/* Palette: load the REAL 256 RGB triplets from the DAT PALETA block.    */
/*                                                                     */
/* Mirrors SI35.PAS engine_init():                                         */
/*     load_palette_block(input_file, '>PALETA', palx);                  */
/*                                                                     */
/* load_palette_block() strips the leading '>' (BLOCKX.out_string),     */
/* reads the 768-byte PALETA block straight from MAIN.DAT via the       */
/* Phase A DAT reader, and unpacks it into 256 t_palette triplets       */
/* verbatim (8-bit r,v,b -- no shr-2 darkening).  palx[0] is colour 0   */
/* (black, the engine's background index).                             */
/* --------------------------------------------------------------------- */
static void load_real_palette(void)
{
    /* input_file in the Pascal = the main data DAT (MAIN.DAT). The engine
     * is always launched from the data directory (see run_engine_test.sh),
     * so the relative name resolves. */
    load_palette_block("MAIN.DAT", ">PALETA", palx);
}

/* --------------------------------------------------------------------- */
/* Draw helpers: 8-bit back buffer writes.                               */
/* --------------------------------------------------------------------- */
inline void fb_vput(int x, int y, unsigned char c)
{
    if (x >= 0 && x < FBW && y >= 0 && y < FBH)
        video_buffer[y * FBW + x] = c;
}

void fb_vfill(unsigned char c)
{
    memset(video_buffer, c, VBUFSZ);
}

void fb_vrect(int x0, int y0, int x1, int y1, unsigned char c)
{
    int x, y;
    if (x0 > x1) { int t = x0; x0 = x1; x1 = t; }
    if (y0 > y1) { int t = y0; y0 = y1; y1 = t; }
    for (y = y0; y < y1; y++)
        for (x = x0; x < x1; x++) fb_vput(x, y, c);
}

/* Draw one glyph cell: fill the CharDX x CharDY cell with 'bg', then paint
 * the lit pixels with 'fg' using the DAT-loaded font (faithful JxGRAF core). */
void fb_vchar(int x, int y, unsigned char ch, unsigned char fg, unsigned char bg)
{
    int h, n;
    unsigned char tmp[2];
    tmp[0] = ch; tmp[1] = 0;
    for (n = 0; n < CharDY; n++)
        for (h = 0; h < CharDX; h++)
            fb_vput(x + h, y + n, bg);
    font_draw_str((const char *)tmp, x, y, fg, 0);
}

void fb_vstr(int x, int y, const char *s, unsigned char fg, unsigned char bg)
{
    while (*s) {
        fb_vchar(x, y, (unsigned char)*s, fg, bg);
        x += CharDX;
        s++;
    }
}

/* Draw a string WITHOUT the per-glyph background fill.  Mirrors the Pascal
 * print_normal / Printr, which paints ONLY the lit glyph pixels (no bg) --
 * used by the menu items so the GLIST frame interior (or menu box) shows
 * through the letters instead of a solid cell background. */
void fb_vstr_nobg(int x, int y, const char *s, unsigned char col)
{
    while (*s) {
        unsigned char tmp[2];
        tmp[0] = (unsigned char)*s;
        tmp[1] = 0;
        font_draw_str((const char *)tmp, x, y, col, 0);
        x += CharDX;
        s++;
    }
}

/* --------------------------------------------------------------------- */
/* JxEFEKT.PAS TPrint port: real_length + print.                         */
/*                                                                       */
/* TPrint (the "napis" / "napis2" objects) draws text with:              */
/*   1. centering  : if center, x := (getmaxx div 2) - real_length(s)/2 */
/*   2. shadow     : if shadow, a copy at (x+px, y+py) in shadow_color   */
/*   3. main       : the glyph at (x, y) in text_color                 */
/* using print_normal semantics (lit pixels only, fixed chardx advance). */
/* Both napis.init(2,2,15,0,0,true,true) and napis2.init(2,2,15,0,0,    */
/* true,false) use px=py=2, text_color=15, shadow_color=0, center=true.  */
/* getmaxx = FBW-1 = 639, so getmaxx div 2 = 319.                       */
/* --------------------------------------------------------------------- */

/* real_length(s) -- JxEFEKT.PAS.  The proportional on-screen width (px) of
 * s: each non-space char advances lsign+2 where lsign is the widest lit
 * column of that glyph; a space advances chardx.  This is the width TPrint
 * uses to centre text (NOT length(s)*chardx). */
static int real_length(const char *s)
{
    int c, n, h;
    unsigned int Index;
    unsigned char b;
    int CDX = CharDX, CDY = CharDY;
    int ByteRange, lsign, x = 0;

    if (CDX == 0) return 0;                 /* Font==NIL guard */
    ByteRange = 1 + ((CDX - 1) >> 3);
    for (c = 0; s[c]; c++) {
        Index = ((unsigned char)s[c] + posuv) *
                (unsigned int)ByteRange * (unsigned int)CDY - 1u;
        lsign = 0;
        for (n = 0; n < CDY; n++) {
            for (h = 0; h < CDX; h++) {
                if ((h & 7) == 0) {
                    Index++;
                    b = (Index <= 4096) ? fontik[Index] : 0;
                }
                if ((b >= 128) && (h > lsign)) lsign = h;
                b = (unsigned char)(b << 1);
            }
        }
        if (s[c] != ' ') x += lsign + 2;    /* Pascal: inc(x, lsign+2) */
        else             x += CDX;          /* space: inc(x, chardx) */
    }
    return x;
}

/* tprint_draw -- JxEFEKT.PAS TPrint.print.  Centers when center=true,
 * draws a shadow copy at (x+px,y+py) in shadow_color when shadow=true, then
 * the main glyph at (x,y) in text_color.  Both use print_normal semantics
 * (fb_vstr_nobg: lit pixels only, fixed chardx advance).  Exposed via
 * fb_draw.h so game_menu.c can centre the password prompt / field / result. */
void tprint_draw(const char *s, int x, int y,
                 unsigned char text_color,
                 int px, int py, unsigned char shadow_color,
                 int center, int shadow)
{
    if (center)
        x = (FBW - 1) / 2 - real_length(s) / 2;   /* getmaxx div 2 = 319 */
    if (shadow)
        fb_vstr_nobg(x + px, y + py, s, shadow_color);
    fb_vstr_nobg(x, y, s, text_color);
}

/* --------------------------------------------------------------------- */
/* LZW constants (BLOCKX.PAS UnpackImage). */
static const unsigned short wordmasktable[16] =
    {0x0000,0x0001,0x0003,0x0007,0x000F,0x001F,0x003F,0x007F,
     0x00FF,0x01FF,0x03FF,0x07FF,0x0FFF,0x1FFF,0x3FFF,0x7FFF};
static const int inctable[5] = {8, 8, 4, 2, 0};
static const int starttable[5] = {0, 4, 2, 1, 0};

/* ===================================================================== */
/* JxGRAf raster layer + GIF/LZW resource decoder.                       */
/*                                                                       */
/* Faithful ports of the routines GAME.INC / JxGRAF.PAS / BLOCKX.PAS     */
/* use to paint the intro menu:                                          */
/*   * rectangle2 / putpixel / getpixel / write_linepos  -- the 8-bit    */
/*     framebuffer primitives the raster layer is built on.              */
/*   * printzoom2 / print_zoom_shadow                    -- the SCALED   */
/*     font used by the menu (norm_it -> print_zoom_shadow).  This is    */
/*     the piece the native fb_vstr port was missing: the reference      */
/*     menu text is drawn glyph-by-glyph as small rectangles (zoomx/     */
/*     zoomy), so adjacent lit pixels overlap and the palette produces   */
/*     the characteristic anti-aliasing grays.  fb_vstr drew at native   */
/*     size instead -- that was the "font not scaled" bug.              */
/*   * draw_gif_block (BLOCKX.PAS:416) -- Siriel's custom Jx1/LZW GIF    */
/*     decoder that paints the GLOGO / intro resource blocks.  The       */
/*     block-file abstraction (openblockfile/GetBlockFile/get/put) is    */
/*     replaced by loading the DAT block straight into memory via        */
/*     dat_load_array(); get() reads sequentially from that buffer.      */
/*   * draw_it / set_death_color / clear_bitmap -- the intro-menu glue.  */
/* ===================================================================== */

/* death_color: the index the GIF decoder recycles from the underlying
 * screen (JxGRAF.death_color, BLOCKX put()).  set_death_color(13) before
 * drawing GLOGO means "wherever index 13 appears, copy the pixel already
 * on screen here".  256 (a word, never a valid 8-bit index) disables the
 * recycle. */
static unsigned int death_color = 256;

void cc_set_death_color(int num) { death_color = (unsigned int)num; }

/* clear_bitmap(screen) -- zero the back buffer. */
void cc_clear_bitmap(void) { fb_vfill(0); }

/* save_scr / draw_scr: the C-C engine owns a SINGLE framebuffer (no
 * double-buffer handle like the Pascal handles[1]), so both are no-ops. */
static void cc_save_scr(int x0, int y0, int x1, int y1)
{ (void)x0; (void)y0; (void)x1; (void)y1; }
static void cc_draw_scr(int x0, int y0, int x1, int y1)
{ (void)x0; (void)y0; (void)x1; (void)y1; }

/* putpixel(bitmap,x,y,col) -- JxGRAPH.putpixel */
static inline void cc_putpixel(int x, int y, unsigned char col) { fb_vput(x, y, col); }

/* getpixel(bitmap,x,y) -- JxGRAF.getpixel */
static inline unsigned char cc_getpixel(int x, int y)
{
    if (x < 0 || x >= FBW || y < 0 || y >= FBH) return 0;
    return video_buffer[y * FBW + x];
}

/* Public 8-bit framebuffer read accessor (unit tests / debugging). */
unsigned char cc_fb_getpixel(int x, int y)
{
    return cc_getpixel(x, y);
}

/* write_linepos(bitmap,line,abscisse,ordonnee,number) -- copy `number`
 * bytes from line[] into the back buffer starting at (abscisse,ordonnee). */
static void cc_write_linepos(const unsigned char *line, int x, int y, int number)
{
    int i;
    for (i = 0; i < number; i++) fb_vput(x + i, y, line[i]);
}

/* --------------------------------------------------------------------- */
/* SPRITE BLIT PRIMITIVES (ANIMING.PAS port).                            */
/*                                                                       */
/* Faithful C port of the VideoBuffer graphics primitives from           */
/* src/pascal/ANIMING.PAS, operating on the SAME 8-bit video_buffer the  */
/* LZW decoder cc_draw_gif_block_dat writes into.  spike/migrate/anim    */
/* /anim.c is the reference (external) port; the bodies here are the      */
/* Pascal {$ELSE} implementations, transcribed verbatim but reading       */
/* video_buffer directly (no set_fb bridge).                             */
/*                                                                       */
/*   read_linepos(screen, buffer, gx, gy, gd)  reads `gd` bytes at        */
/*     (gx,gy) into `buffer` using the 640-row stride.                    */
/*   write_linepos(...) writes them back.                                 */
/*   getseg/putseg/getseg2/putseg2/putseg3/putseg2_mix/putseg2_rev/      */
/*     putseg2_rev_mix  sector copy / blend / mirror blitters.            */
/*   getcol/dec_down/charakter/init_charakter/vypni_charakter/           */
/*     zapni_charakter  the player-character blitters.                    */
/*                                                                       */
/* Arithmetic MIRROR the Pascal `word` (16-bit) types exactly: cxx/cxx2  */
/* /cxx3 are word (wrap at 65536), the row offset is (gf+gy) as word      */
/* then *FBW.  lajna/lajno mirror Pascal's persistent tline scratch       */
/* buffers (only the low 8 bits are ever used -> uint8_t bit-equivalent). */
/* --------------------------------------------------------------------- */
static unsigned char lajna[1024];   /* persistent scratch (Pascal lajna:tline)   */
static unsigned char lajno[1024];   /* persistent scratch (Pascal lajno:tline)   */
static unsigned int  sizex;         /* set by init_charakter                     */
static unsigned int  sizey;

/* si : postava (AKTIV35.PAS:50) -- the panak avatar position + copy buffer.
 * Driven by GAME.INC padak/hra_init exactly like menu.c drives the menu cursor.
 * px/py are the character cell offset (AKTIV35.PAS:169-170); the sprite is
 * blitted at (si.x+px, si.y+py).  poloha selects the 16x16 pose cell in ar[]. */
static unsigned short px = 4;         /* AKTIV35.PAS:169  px = 4 */
static unsigned short py = 2;         /* AKTIV35.PAS:170  py = 2 */
/* PANAK_TILE_X/PANAK_TILE_Y: the floor tile the panak stands on.  The
 * sprite is drawn at screen (si.x+px, si.y+py); tile (f,fy) maps to screen
 * (f*16+8, fy*16), so si is set to (f*16+4, fy*16-2) in draw_state().  The
 * real game reads the entrance from the level's PRE data (not parsed here),
 * so with maze_step unported the avatar simply stands on this tile. */
#define PANAK_TILE_X   6
#define PANAK_TILE_Y   17
static unsigned short si_x, si_y, si_oldx, si_oldy;  /* postava x,y,oldx,oldy */
static unsigned short si_buf;         /* sir_buf = sir_nums-1 = 51 (copy buffer) */
static unsigned char  poloha;         /* panak pose frame 0..43 */
static int            panak_initialized = 0;  /* set once per level start */

/* read_linepos(screen, buffer, gx, gy, gd) -- read `gd` bytes at (gx,gy). */
static void read_linepos(unsigned int gx, unsigned int gy, unsigned int gd,
                         unsigned char *buf)
{
    unsigned int base = (unsigned int)gy * FBW + gx;
    unsigned int gff;
    for (gff = 0; gff < gd; gff++)
        buf[gff] = video_buffer[base + gff];
}

/* write_linepos(screen, buffer, gx, gy, gd) -- write `gd` bytes at (gx,gy).*/
static void write_linepos(unsigned int gx, unsigned int gy, unsigned int gd,
                          const unsigned char *buf)
{
    unsigned int base = (unsigned int)gy * FBW + gx;
    unsigned int gff;
    for (gff = 0; gff < gd; gff++)
        video_buffer[base + gff] = buf[gff];
}

/* getseg(gx,gy,gd,gs,num:word; var aw) -- zoberie sektor (load sector). */
static void getseg(unsigned int gx, unsigned int gy, unsigned int gd,
                   unsigned int gs, unsigned int num, unsigned char *aw)
{
    unsigned int cxx = (unsigned int)num * gd * gs;   /* word wrap */
    unsigned int gf, gff;
    for (gf = 0; gf < gs; gf++) {
        read_linepos(gx, gf + gy, gd, lajna);
        for (gff = 0; gff < gd; gff++)
            aw[(unsigned int)(cxx + gf * gs) + gff] = lajna[gff];
    }
}

/* putseg(gx,gy,gd,gs,num:word; var aw) -- polozi sektor (store sector). */
static void putseg(unsigned int gx, unsigned int gy, unsigned int gd,
                   unsigned int gs, unsigned int num, unsigned char *aw)
{
    unsigned int cxx = (unsigned int)num * gd * gs;   /* word wrap */
    unsigned int gf, gff;
    for (gf = 0; gf < gd; gf++) {
        for (gff = 0; gff < gs; gff++)
            lajna[gff] = aw[(unsigned int)(cxx + gf * gs) + gff];
        write_linepos(gx, gf + gy, gd, lajna);
    }
}

/* getseg2(gx,gy,gd,gs,num,col:word; var aw) -- load sector, skip col. */
static void getseg2(unsigned int gx, unsigned int gy, unsigned int gd,
                    unsigned int gs, unsigned int num, unsigned int col,
                    unsigned char *aw)
{
    unsigned int cxx = (unsigned int)num * gd * gs;   /* word wrap */
    unsigned int gf, gff;
    for (gf = 0; gf < gs; gf++) {
        read_linepos(gx, gf + gy, gd, lajna);
        for (gff = 0; gff < gd; gff++)
            if (lajna[gff] != col)
                aw[(unsigned int)(cxx + gf * gs) + gff] = lajna[gff];
    }
}

/* putseg2(gx,gy,gd,gs,num,col:word; var aw) -- store sector, skip col. */
static void putseg2(unsigned int gx, unsigned int gy, unsigned int gd,
                    unsigned int gs, unsigned int num, unsigned int col,
                    unsigned char *aw)
{
    unsigned int cxx = (unsigned int)num * gd * gs;   /* word wrap */
    unsigned int gf, gff;
    for (gf = 0; gf < gd; gf++) {
        read_linepos(gx, gf + gy, gd, lajna);
        for (gff = 0; gff < gs; gff++)
            if (aw[(unsigned int)(cxx + gf * gs) + gff] != col)
                lajna[gff] = aw[(unsigned int)(cxx + gf * gs) + gff];
        write_linepos(gx, gf + gy, gd, lajna);
    }
}

/* putseg3(gx,gy,gd,gs,num,col,col2:word; var aw) */
static void putseg3(unsigned int gx, unsigned int gy, unsigned int gd,
                    unsigned int gs, unsigned int num, unsigned int col,
                    unsigned int col2, unsigned char *aw)
{
    unsigned int cxx = (unsigned int)num * gd * gs;   /* word wrap */
    unsigned int gf, gff;
    for (gf = 0; gf < gd; gf++) {
        read_linepos(gx, gf + gy, gd, lajna);
        for (gff = 0; gff < gs; gff++)
            if (aw[(unsigned int)(cxx + gf * gs) + gff] != col)
                lajna[gff] = col2;
        write_linepos(gx, gf + gy, gd, lajna);
    }
}

/* putseg2_mix(gx,gy,gd,gs,num,col:word; var aw; num2:word; var av) */
static void putseg2_mix(unsigned int gx, unsigned int gy, unsigned int gd,
                        unsigned int gs, unsigned int num, unsigned int col,
                        unsigned char *aw, unsigned int num2,
                        unsigned char *av)
{
    unsigned int cxx = (unsigned int)num * gd * gs;   /* word wrap */
    unsigned int gf, gff;
    for (gf = 0; gf < gd; gf++) {
        unsigned int cxx2 = (unsigned int)(cxx + gf * gs);
        unsigned int cxx3 = (unsigned int)num2 * gd * gs + gf * gs;
        for (gff = 0; gff < gs; gff++) {
            unsigned int a = (unsigned int)(cxx2 + gff);
            if (aw[a] == col)
                lajna[gff] = av[(unsigned int)(cxx3 + gff)];
            else
                lajna[gff] = aw[a];
        }
        write_linepos(gx, gf + gy, gd, lajna);
    }
}

/* putseg2_rev(gx,gy,gd,gs,num,col:word; var aw) -- mirrored sector, skip col.*/
static void putseg2_rev(unsigned int gx, unsigned int gy, unsigned int gd,
                        unsigned int gs, unsigned int num, unsigned int col,
                        unsigned char *aw)
{
    unsigned int cxx = (unsigned int)num * gd * gs;   /* word wrap */
    unsigned int gf, gff;
    for (gf = 0; gf < gd; gf++) {
        read_linepos(gx, gf + gy, gd, lajna);
        unsigned int cxx2 = (unsigned int)(cxx + gf * gs + gd - 1);
        for (gff = 0; gff < gs; gff++) {
            unsigned int a = (unsigned int)(cxx2 - gff);   /* wraps like word */
            if (aw[a] != col)
                lajna[gff] = aw[a];
        }
        write_linepos(gx, gf + gy, gd, lajna);
    }
}

/* putseg2_rev_mix(gx,gy,gd,gs,num,col:word; var aw; num2:word; var av) */
static void putseg2_rev_mix(unsigned int gx, unsigned int gy, unsigned int gd,
                            unsigned int gs, unsigned int num, unsigned int col,
                            unsigned char *aw, unsigned int num2,
                            unsigned char *av)
{
    unsigned int cxx = (unsigned int)num * gd * gs;   /* word wrap */
    unsigned int gf, gff;
    for (gf = 0; gf < gd; gf++) {
        unsigned int cxx2 = (unsigned int)(cxx + gf * gs + gd - 1);
        unsigned int cxx3 = (unsigned int)num2 * gd * gs + gf * gs;
        for (gff = 0; gff < gs; gff++) {
            unsigned int a = (unsigned int)(cxx2 - gff);   /* wraps like word */
            if (aw[a] == col)
                lajna[gff] = av[(unsigned int)(cxx3 + gff)];
            else
                lajna[gff] = aw[a];
        }
        write_linepos(gx, gf + gy, gd, lajna);
    }
}

/* putseg2_ar(gx,gy,gd,gs,num,col:word; var aw) -- C-C stand-in for the Pascal
   putseg2xms(handles[4],gx,gy,gd,gs,num,col) (ANIMING.PAS:426).  putseg2xms
   reads the sprite out of XMS handle[4] and blits it to the screen, skipping
   transparent colour `col`; the C-C engine has no XMS, so this reads the
   sprite from the plain g_handle4 stand-in table <aw> instead.  Layout and
   the skip-`col` semantics are byte-identical to the Pascal XMS version. */
static void putseg2_ar(unsigned int gx, unsigned int gy, unsigned int gd,
                       unsigned int gs, unsigned int num, unsigned int col,
                       unsigned char *aw)
{
    unsigned int cxx = (unsigned int)num * gd * gs;   /* word wrap */
    unsigned int gf, gff;
    for (gf = 0; gf < gs; gf++) {
        read_linepos(gx, gf + gy, gd, lajna);
        for (gff = 0; gff < gd; gff++) {
            unsigned int src = aw[(unsigned int)(cxx + gf * gs) + gff];
            if (src != col) lajna[gff] = src;          /* skip transparent col */
        }
        write_linepos(gx, gf + gy, gd, lajna);
    }
}

/* getcol(gx,gy,num:word; var am):word -- zoberie farbu z pola. */
static unsigned int getcol(unsigned int gx, unsigned int gy, unsigned int num,
                           unsigned char *am)
{
    if (num == 0)
        return 13;
    gx = (unsigned int)(gx % 16);          /* dec_down */
    gy = (unsigned int)(gy % 16);          /* dec_down */
    return am[(unsigned int)((unsigned long)256 * num + (unsigned long)gy * 16 + gx)];
}

/* dec_down(var num:word) -- num := num mod 16 */
static void dec_down(unsigned int *num)
{
    *num = (unsigned int)(*num % 16);
}


/* cc_ar() -- return the character-sprite table (^long_panak) that the
 * characteristic* blitters read.  Exposed so menu.c can pass ar^ to
 * init_charakter / karakter exactly as GAME.INC does. */
unsigned char *cc_ar(void) { return ar; }
/* characteristic(chx,chy,choldx,choldy,chpoloha,chbuf:word; var am) -- move the panak avatar: erase at the old cell, load the new one, repaint. Exposed (non-static) so menu.c drives the intro-menu avatar exactly as GAME.INC choice_step does. */
void karakter(unsigned int chx, unsigned int chy, unsigned int choldx,
                      unsigned int choldy, unsigned int chpoloha,
                      unsigned int chbuf, unsigned char *am)
{
    if (chx != choldx || chy != choldy) {
        putseg(choldx, choldy, sizex, sizey, chbuf, am);
        getseg(chx, chy, sizex, sizey, chbuf, am);
        putseg2(chx, chy, sizex, sizey, chpoloha, 13, am);
    } else {
        putseg2_mix(chx, chy, sizex, sizey, chpoloha, 13, am, chbuf, am);
    }
}

/* characteristic init: set the cell size and draw the initial pose. Exposed so menu.c can place the panak avatar in the intro menu. */
void init_charakter(unsigned int chsizex, unsigned int chsizey,
                           unsigned int chx, unsigned int chy,
                           unsigned int chpoloha, unsigned int chbuf,
                           unsigned char *am)
{
    sizex = chsizex;
    sizey = chsizey;
    getseg(chx, chy, sizex, sizey, chbuf, am);
    putseg2(chx, chy, sizex, sizey, chpoloha, 13, am);
}

/* vypni_charakter: restore the screen behind the panak (erase it). Exposed for menu.c. */
void vypni_charakter(unsigned int choldx, unsigned int choldy,
                            unsigned int chbuf, unsigned char *am)
{
    putseg(choldx, choldy, sizex, sizey, chbuf, am);
}

/* zapni_charakter(chx,chy,num,chbuf:word; var am) -- repaint the character.*/
static void zapni_charakter(unsigned int chx, unsigned int chy, unsigned int num,
                            unsigned int chbuf, unsigned char *am)
{
    getseg(chx, chy, sizex, sizey, chbuf, am);
    putseg2(chx, chy, sizex, sizey, num, 13, am);
}

/* rectangle2(bitmap,x1,y1,x2,y2,col): fill the rectangle [x1,x1+x2) x
 * [y1,y1+y2) with col.  printzoom2 draws each lit glyph pixel as one of
 * these, giving the scaled (zoomx+1 wide, zoomy tall) glyph cells. */
static void cc_rectangle2(int x1, int y1, int x2, int y2, unsigned char col)
{
    int xx, yy;
    for (yy = y1; yy < y1 + y2; yy++)
        for (xx = x1; xx < x1 + x2; xx++)
            fb_vput(xx, yy, col);
}

/* printzoom2(bitmap,var x,y,s,textcolor,zoomx,zoomy) -- JxGRAF.PAS.
 * Renders ONE glyph (s is a single char when called from print_zoom_shadow)
 * as scaled rectangles.  The index/ByteRange/MSB-first bit walk mirror the
 * native intr core; the only difference is the lit-pixel draw: instead of
 * a single fb_vput it emits rectangle2(x+(h+(c-1)*chardx)*zoomx,
 * y+n*zoomy, zoomx+1, zoomy, textcolor).
 *
 * NOTE: `x` is passed BY REFERENCE exactly like the Pascal `var x`.  On the
 * trailing line printzoom2 advances x by (lsign+3)*zoomx-chardx, and this
 * change MUST propagate back to the caller (print_zoom_shadow).  The C port
 * therefore takes `int *px`; this is the whole point of the var parameter --
 * dropping it (taking x by value, as an early port did) silently killed this
 * advance and made print_zoom_shadow space glyphs by only CharDX, so scaled
 * glyphs (each ~CharDX*(zoomx+1) wide) overlapped and every letter looked
 * "repeated".  print_zoom_shadow then mirrors Pascal's inc(x,chardx). */
static void printzoom2(const char *s, int *px, int y,
                       unsigned char textcolor, int zoomx, int zoomy)
{
    int c, n, h;
    unsigned int Index;
    unsigned char b;
    int CDX = CharDX, CDY = CharDY;
    int ByteRange, lsign;
    int len = (int)strlen(s);

    if (CDX == 0) return;                 /* Font==NIL guard */
    ByteRange = 1 + ((CDX - 1) >> 3);
    lsign = 0;                            /* set once, before the char loop */
    for (c = 1; c <= len; c++) {
        Index = ((unsigned char)s[c - 1] + posuv) *
                (unsigned int)ByteRange * (unsigned int)CDY - 1u;
        int yy = y;
        for (n = 0; n < CDY; n++) {
            for (h = 0; h < CDX; h++) {
                if ((h & 7) == 0) {
                    Index++;
                    b = (Index <= 4096) ? fontik[Index] : 0;
                }
                if (b >= 128) {
                    cc_rectangle2(*px + (h + (c - 1) * CDX) * zoomx,
                                    yy + n * zoomy, zoomx + 1, zoomy, textcolor);
                    if (h > lsign) lsign = h;
                }
                b = (unsigned char)(b << 1);
            }
        }
    }
    if (strcmp(s, " ") != 0)               /* Pascal: if s<>' ' then x:=... */
        *px = *px + (lsign + 3) * zoomx - CDX;
}

/* print_zoom_shadow(bitmap,x,y,s,textcolor,zoomx,zoomy,px,py,col) --
 * JxGRAF.PAS.  Draws each glyph twice: a shadow at (x+px,y+py) in `col` and
 * the main glyph at (x,y) in `textcolor`, both scaled by zoomx/zoomy.  Both
 * x and xx are passed BY REFERENCE to printzoom2 (Pascal var), so the trailing
 * printzoom2 advance persists; then inc(x,chardx)/inc(xx,chardx) run, giving a
 * net per-glyph advance of (lsign+3)*zoomx -- exactly the Pascal behaviour.
 *
 * CRITICAL: Pascal calls printzoom2(screen,xx,yy,s[f],...) with s[f] a SINGLE
 * CHARACTER (length 1).  An early C port passed s+f -- a SUBSTRING of length
 * len-f.  printzoom2's inner loop positions glyph c at
 * x + (h + (c-1)*chardx)*zoomx, so a multi-char s made it draw ALL remaining
 * glyphs at once; combined with the outer loop advancing x by chardx each
 * iteration and re-drawing, every glyph got painted once per preceding f at a
 * slightly different x -- the "copied by one pixel, growing to the right"
 * artifact.  Passing one char at a time (len==1, so (c-1)*chardx==0) makes
 * each glyph paint exactly once, exactly like the Pascal original. */
void print_zoom_shadow(int x, int y, const char *s,
                              unsigned char textcolor,
                              int zoomx, int zoomy, int px, int py,
                              unsigned char col)
{
    int xx = x + px, yy = y + py;
    int f, len = (int)strlen(s);
    char one[2];
    one[1] = '\0';
    for (f = 0; f < len; f++) {
        one[0] = s[f];
        printzoom2(one, &xx, yy, col, zoomx, zoomy);
        printzoom2(one, &x, y, textcolor, zoomx, zoomy);
        x += CharDX;
        xx += CharDX;
    }
    (void)yy; (void)col; (void)px; (void)py;
}

/* norm_it(mex) -- GAME.INC: print a menu item with the shadow scaling
 * (textcolor=9, zoomx=2, zoomy=2, shadow offset (3,3), shadow col=0). */
void norm_it(const char *meno, int mx, int my)
{
    print_zoom_shadow(mx, my, meno, 9, 2, 2, 3, 3, 0);
}

/* Internal GIF/LZW resource decoder (BLOCKX.PAS:416 port).  Forward
 * declaration so draw_it() below can call it before its definition.  The
 * <dat> argument selects the resource file, exactly as the Pascal
 * draw_gif_block(screen, file_name, kluc, ...) passes its file_name:
 *   * "MAIN.DAT"  -- system resources (draw_it('>...'), cc_draw_gif_block_pub)
 *   * g_level_dat -- the game DAT (SIRIEL35.DAT) for draw_it('GTREEP') etc. */
static void cc_draw_gif_block_dat(const char *dat, const char *kluc,
                                  int fromx, int fromy);
static void cc_draw_gif_block(const char *kluc, int fromx, int fromy);

/* draw_it(name,x,y,palx) -- LOAD235.PAS draw_it (the one GAME.INC uses).    */
/*                                                                       */
/* BOTH branches read the resource block from the game DAT (the Pascal   */
/* zvukovy_subor = g_level_dat).  The '>' prefix is stripped via         */
/* out_string() (a left-shift, dropping the leading '>') -- it is NOT    */
/* a "load from MAIN.DAT" marker like the JXEFEKT.PAS draw_it.  So       */
/* draw_it('>GTREEP') and draw_it('GANIM') both decode from g_level_dat. */
/* (The C-C engine has no .gif files on disk -- every graphic asset is a */
/* Jx1 block in a DAT -- so both branches call cc_draw_gif_block_dat().) */
void draw_it(const char *name, int x, int y)
{
    if (name && name[0] != '\0') {
        const char *kluc = name;
        if (name[0] == '>')
            kluc = name + 1;              /* out_string: strip leading '>' */
        cc_draw_gif_block_dat(g_level_dat, kluc, x, y);
    }
    (void)x; (void)y;
}

/* --------------------------------------------------------------------- */
/* SPRITE-SHEET LOADERs (SI35.PAS load_pohyby / do_fatal_restart block). */
/*                                                                       */
/* These mirror the Pascal exactly: decode the Jx1 sprite sheet into the */
/* framebuffer via cc_draw_gif_block_dat(), then carve the 16x16 cells   */
/* with getseg() into the persistent ar^ / anim^ tables.                */
/* --------------------------------------------------------------------- */

/* cc_load_pohyby -- port of SI35.PAS load_pohyby.                     */
/*                                                                       */
/*   draw_gif_block(screen, input_file, pohyby, 0, 0, palx);  input_file */
/*     = 'MAIN.DAT', pohyby = def_pohyby = 'GZAL' (a 224x64 sheet =     */
/*     14x4 grid of 16x16 cells).  Then getseg() carves the sir_nums     */
/*     cells into ar^ at the exact (row, index) positions the Pascal     */
/*     uses (rows 0/16/32/48, the +128/+160 column offsets).            */
static void cc_load_pohyby(void)
{
    int f;
    cc_draw_gif_block_dat(g_input_file, "GZAL", 0, 0);
    for (f = 0; f <= 11; f++)
        getseg(f * resx, 0, resx, resy, f, ar);
    for (f = 0; f <= 7; f++) {
        getseg(f * resx, 16, resx, resy, f + 12, ar);
        getseg(f * resx, 32, resx, resy, f + 20, ar);
        getseg(f * resx, 48, resx, resy, f + 28, ar);
    }
    for (f = 0; f <= 2; f++)
        getseg(f * resx + 128, 16, resx, resy, f + 36, ar);
    for (f = 0; f <= 3; f++)
        getseg(f * resx + 128, 32, resx, resy, f + 40, ar);
    for (f = 0; f <= 1; f++)
        getseg(f * resx + 128, 48, resx, resy, f + 44, ar);
    for (f = 0; f <= 3; f++)
        getseg(f * resx + 160, 48, resx, resy, f + 47, ar);
}

/* --------------------------------------------------------------------- */
/* MENU-BOX LOADER (JXEFEKT.PAS TFrame.init / draw).                     */
/*                                                                       */
/* These mirror the old_frame used by the level selector.  old_frame.init */
/* (SI35.PAS:930) decodes the GLIST block (frame_gif='>GLIST',           */
/* input_file='MAIN.DAT') into the framebuffer, reads the metadata from  */
/* pixels (0,0..3), then carves the 8 border tiles via getsegxms.  old  */
/*_frame.draw(200,40,12,18) + draw_PO then fills the box interior and   */
/* blits the 8 tiles (corners 0/2/5/7, edges 1/6 top/bottom, 3/4        */
/* left/right) around the menu.  Both are exposed so game_menu.c can    */
/* reproduce the level-selector decoration from the CORRECT source      */
/* (GLIST) instead of the GZAL animation sheet.                        */
/* --------------------------------------------------------------------- */

/* cc_load_frame -- port of SI35.PAS old_frame.init.   */
static void cc_load_frame(void)
{
    int f;
    cc_clear_bitmap();
    cc_draw_gif_block_dat(g_input_file, "GLIST", 0, 0);
    g_frame_sx = cc_getpixel(0, 1);          /* TFrame.size_x  */
    g_frame_sy = cc_getpixel(0, 2);          /* TFrame.size_y  */
    g_frame_fill = cc_getpixel(0, 3);        /* TFrame.fill_color */
    for (f = 0; f < FRAME_NUMS; f++)
        getseg(1 + f * g_frame_sx, 0, g_frame_sx, g_frame_sy, f, g_frame);
}

/* cc_draw_menu_frame(x,y,dx,dy) -- port of SI35.PAS old_frame.draw(x,y,dx,dy).
 * Draws the GLIST frame border + interior fill at (x,y) with the 5x5-ish
 * tile grid implied by (dx,dy): AP2 = (dx+2, dy+2), mirroring draw_PO.
 * Mirrors draw_PO: rectangle2 fill first, then the 8 border tiles.
 *
 *   (200,40,12,18) -- the level-selector box (select_level_init).
 *   (270,180,3,3)  -- the "Quit? Yes/No" box (quit_confirm_init).
 * Both are the SAME old_frame.draw mechanism; only the coordinates differ. */
void cc_draw_menu_frame(int x, int y, int dx, int dy)
{
    unsigned int P1x = (unsigned int)x, P1y = (unsigned int)y;  /* old_frame.draw(x,y,...) */
    unsigned int P2x, P2y;                    /* dx+2, dy+2                */
    unsigned int f;
    P2x = (unsigned int)dx + 2;               /* AP2.x = dx + 2            */
    P2y = (unsigned int)dy + 2;               /* AP2.y = dy + 2            */
    /* rectangle2(screen,P1.x+size_x,P1.y+size_y,
     *          (P2.x-2)*size_x,(P2.y-2)*size_y,fill_color) */
    cc_rectangle2(P1x + g_frame_sx, P1y + g_frame_sy,
                  (P2x - 2) * g_frame_sx, (P2y - 2) * g_frame_sy,
                  g_frame_fill);
    /* corners */
    putseg2(P1x,                    P1y,                    g_frame_sx, g_frame_sy, 0, 13, g_frame); /* TL */
    putseg2(P1x + (P2x - 1) * g_frame_sx, P1y,              g_frame_sx, g_frame_sy, 2, 13, g_frame); /* TR */
    putseg2(P1x,                    P1y + (P2y - 1) * g_frame_sy, g_frame_sx, g_frame_sy, 5, 13, g_frame); /* BL */
    putseg2(P1x + (P2x - 1) * g_frame_sx, P1y + (P2y - 1) * g_frame_sy,
            g_frame_sx, g_frame_sy, 7, 13, g_frame);                                              /* BR */
    /* top/bottom edges */
    for (f = 1; f <= P2x - 2; f++) {
        putseg2(P1x + f * g_frame_sx, P1y,                         g_frame_sx, g_frame_sy, 1, 13, g_frame);
        putseg2(P1x + f * g_frame_sx, P1y + (P2y - 1) * g_frame_sy, g_frame_sx, g_frame_sy, 6, 13, g_frame);
    }
    /* left/right edges */
    for (f = 1; f <= P2y - 2; f++) {
        putseg2(P1x,                    P1y + f * g_frame_sy, g_frame_sx, g_frame_sy, 3, 13, g_frame);
        putseg2(P1x + (P2x - 1) * g_frame_sx, P1y + f * g_frame_sy, g_frame_sx, g_frame_sy, 4, 13, g_frame);
    }
}

/* obrazky" block.                                                      */
/*                                                                       */
/*   draw_it(anim_file, 0, 0);  anim_file = 'GANIM' (from config         */
/*     [ANIM]=>GANIM), decoded from g_level_dat via the LOAD235 draw_it. */
/*   Then getseg() carves the 80 animation frames (ff=0..3 rows,        */
/*   f=0..19 columns) into anim^ at index f + ff*20.                    */
static void cc_load_anim(void)
{
    int f, ff;
    draw_it(g_cfg.anim_file, 0, 0);
    for (ff = 0; ff <= 3; ff++)
        for (f = 0; f <= 19; f++)
            getseg(16 * f, ff * 16, 16, 16, f + ff * 20, anim);
}

/* --------------------------------------------------------------------- */
/* load_anim_def -- port of LOAD235.PAS load_anim_def.                 */
/*                                                                       */
/*   for fm:=0 to anim_nums do begin anx[fm]:=fm*4; end;                */
/*                                                                       */
/* Sets the per-object animation-cell base so PROCESS.PAS process_all can
   address an object's 4 animation frames as  anic + anx[obr]  (four
   consecutive 16x16 cells in the anim sheet, see cc_load_anim's
   f+ff*20 carve).  The C-C engine has no FPC array, so anx is a plain
   256-word stand-in.  Called once at boot (mirrors SI35.PAS
   do_fatal_restart's "nahra animovane obrazky" setup). */
static void load_anim_def(void)
{
    int fm;
    for (fm = 0; fm <= 255; fm++)
        anx[fm] = (unsigned short)(fm * 4);
}

/* --------------------------------------------------------------------- */
/* TEXTURE / TILE TABLE (LOAD235.PAS load_texture / print_texture).      */
/*                                                                       */
/* load_texture() decodes the level's TEXTURA block (CONFIG [TEXTURA]    */
/* => 'GTEXT') into the framebuffer via draw_it(), then getseg() carves  */
/* the 19x10 grid of 16x16 tiles into g_te[] (the te^ table).  The tile  */
/* index N lives at g_te + N*256.  print_texture() blits the st.mie grid */
/*: each cell whose index < g_invisible is drawn at (f*16+8, ff*16) from */
/* g_te via putseg2 with transparent colour 13.                        */
/* --------------------------------------------------------------------- */
#define NUM_TILES 190     /* 19 x 10 tiles (LOAD235.PAS: load_texture)   */
static unsigned char g_te[NUM_TILES * 256];   /* ^te : the tile table */

/* --------------------------------------------------------------------- */
/* "HIDDEN IN DARK" MAZE DISCOVERY (LOAD235.PAS bludisko / GAME.INC maze  */
/* init+step).  Mirrors the Pascal ^bludisko global `bl` (AKTIV35.PAS:147)*/
/*   bludisko = array[0..mie_x,0..mie_y] of boolean;                      */
/*   bl       : ^bludisko;                                                */
/* bl^[f,ff]=true  => tile (f,ff) has been discovered/revealed (drawn).   */
/* bl^[f,ff]=false => tile is still hidden in the dark.                   */
/*                                                                       */
/* `bl<>nil` in Pascal selects the dark-maze rendering branch in          */
/* print_texture() and guards export_texture()/aktivuj_texturu();  here it */
/* is the `maze_bl_active` flag (set by the maze_init() block in         */
/* cc_game_reset() for stav 2/3/4/5).  The array is sized MIE_X+2 x      */
/* MIE_Y+1 to line up with the st.mie grid layout (siriel.h).            */
/* --------------------------------------------------------------------- */
static unsigned char g_bl[MIE_X + 2][MIE_Y + 1];   /* ^bl : the discovery map  */
static int maze_bl_active;                          /* bl <> nil                */

/* invisible / inusable -- the st.mie thresholds (LOAD235.PAS).  */
/* invisible defaults to def_invisible = 255 (AKTIV35.PAS:173).  A cell   */
/* st.mie[f,ff] >= invisible is NOT drawn (shows the background).         */
unsigned char g_invisible = 255;
unsigned char g_inusable  = 0;

/* objective text (LOAD235.PAS print_texture tail + GAME.INC hra_init).  The
   real definition lives with the HUD globals further down; declared here so
   print_texture() can paint the objective line. */
static char     sprava[32];

/* cc_load_texture -- port of LOAD235.PAS load_texture. */
static void cc_load_texture(void)
{
    int f, ff;
    /* draw_it(textura,0,0) -- TEXTURA='GTEXT' (CONFIG [TEXTURA]=>GTEXT).
       draw_it() strips a leading '>' and decodes from g_level_dat. */
    draw_it(g_cfg.textura, 0, 0);
    /* for ff:=0 to 9 do for f:=0 to 18 do getseg(f*resx,ff*resy,...,f+ff*19) */
    for (ff = 0; ff <= 9; ff++)
        for (f = 0; f <= 18; f++)
            getseg(resx * f, resy * ff, resx, resy, f + ff * 19, g_te);
}

/* print_texture -- port of LOAD235.PAS print_texture.  The st.stav 1,3,5   */
/* branch (the gameplay case) draws every cell whose index < invisible and   */
/* records the layout in the discovery map g_bl (revealing everything, then  */
/* dropping stav 3 -> 2).  The maze stav 2/4 branch draws ONLY discovered    */
/* tiles (g_bl[f][ff]), i.e. the "hidden in dark" mechanic.                 */
static void print_texture(void)
{
    int f, ff;
    static long dbg_drawn = 0;
    if (getenv("ENGINE_DEBUG")) dbg_drawn = 0;
    if (st.stav == 2 || st.stav == 4) {
        /* LOAD235.PAS maze branch: draw only discovered tiles.  When
           bl=nil (maze_bl_active==0) fall back to drawing every cell. */
        if (!maze_bl_active) {
            for (f = 0; f <= MIE_X; f++)
                for (ff = 0; ff <= MIE_Y; ff++)
                    if (st.mie[f][ff] < g_invisible) {
                        putseg2(f * 16 + 8, ff * 16, resx, resy, st.mie[f][ff], 13, g_te);
                        if (getenv("ENGINE_DEBUG") && dbg_drawn<=3)
                            fprintf(stderr, "[DBG] pt f=%d ff=%d mie=%u -> seg %u\n", f, ff, st.mie[f][ff], st.mie[f][ff]);
                    }
        } else {
            for (f = 0; f <= MIE_X; f++)
                for (ff = 0; ff <= MIE_Y; ff++)
                    if (g_bl[f][ff] && st.mie[f][ff] < g_invisible) {
                        putseg2(f * 16 + 8, ff * 16, resx, resy, st.mie[f][ff], 13, g_te);
                        if (getenv("ENGINE_DEBUG") && dbg_drawn<=3)
                            fprintf(stderr, "[DBG] pt f=%d ff=%d mie=%u (discovered) -> seg %u\n", f, ff, st.mie[f][ff], st.mie[f][ff]);
                    }
        }
    } else {
        /* LOAD235.PAS stav 1,3,5: draw every cell and record the layout in
           g_bl (revealing everything); on stav 3 drop to stav 2. */
        for (f = 0; f <= MIE_X; f++)
            for (ff = 0; ff <= MIE_Y; ff++) {
                if (st.mie[f][ff] < g_invisible) {
                    putseg2(f * 16 + 8, ff * 16, resx, resy, st.mie[f][ff], 13, g_te);
                    if (getenv("ENGINE_DEBUG") && dbg_drawn<=3)
                        fprintf(stderr, "[DBG] pt f=%d ff=%d mie=%u -> seg %u\n", f, ff, st.mie[f][ff], st.mie[f][ff]);
                }
                if (maze_bl_active) g_bl[f][ff] = 1;
            }
        if (maze_bl_active && st.stav == 3) st.stav = 2;
    }
    if (getenv("ENGINE_DEBUG")) {
        static FILE *df = NULL; if (!df) df = fopen("/tmp/engine_dbg.txt","a");
        fprintf(df, "print_texture: drawn=%ld g_invisible=%d stav=%u bl_active=%d\n", dbg_drawn, g_invisible, (unsigned)st.stav, maze_bl_active);
    }
    /* LOAD235.PAS print_texture tail: the level name (tx[ja,20]+st.meno) and
       the objective (sprava) are centred here via printc().  draw_lifes() is
       painted by draw_hud() in the C-C engine, so it is not repeated here.
       Guarded on st.meno so the boot frame (level not yet loaded) draws no
       title line. */
    if (st.meno[0] != '\0') {
        char s[64];
        int  len, x;
        const char *name = st.meno;
        if (*name == '>') name++;                 /* out_string: strip leading '>' */
        /* printc(screen, vypisy-9, s, 15, 0) -- level name, colour 15 */
        len = snprintf(s, sizeof(s), "%s%s", TX(g_ja, 20), name);
        x = 319 - (len * CharDX) / 2;             /* printc: getmaxx div 2 = 319 */
        fb_vstr_nobg(x, HUD_VYPISY - 9, s, 15);
        /* printc(screen, vypisy-27, sprava, 60, 1) -- objective, colour 60 */
        len = snprintf(s, sizeof(s), "%s", sprava);
        x = 319 - (len * CharDX) / 2;
        fb_vstr_nobg(x, HUD_VYPISY - 27, sprava, 60);
    }
}

/* cc_load_veci -- port of LOAD235.PAS load_predmet.  load_predmet decodes the
   level's object sprite sheet (CONFIG [VECI] => 'GVECI') into the framebuffer
   via draw_it(), then carves the 16x16 cells into the handle[4] stand-in
   g_handle4[] -- exactly the carve pattern putseg2xms(handles[4],...) reads.
       for ff:=0 to 11 do for f:=0 to 19 do getsegxms(handles[4],f*resx,ff*resy,
         resx,resy,f+ff*20);
       for f:=0 to 14 do getsegxms(handles[4],f*resx,ff*resy,resx,resy,f+400);
   (the second loop reuses ff==12 from the finished first loop). */
static void cc_load_veci(void)
{
    int f, ff;
    draw_it(g_cfg.veci, 0, 0);
    for (ff = 0; ff <= 11; ff++)
        for (f = 0; f <= 19; f++)
            getseg(resx * f, resy * ff, resx, resy, f + ff * 20, g_handle4);
    for (f = 0; f <= 14; f++)
        getseg(resx * f, resy * 12, resx, resy, f + 400, g_handle4);
}

/* cc_print_predmet2 -- port of LOAD235.PAS print_predmet2.  Blits every active
   object in the current room (vec.mie==miestnost && visible) to the screen
   from the handle[4] (GVECI) sprite table, skipping transparent colour 13:
       for wq:=1 to nahrane_veci do begin
         if (vec^[wq].mie=miestnost) and (vec^[wq].visible) then begin
           putseg2xms(handles[4],vec^[wq].x,vec^[wq].y,resx,resy,vec^[wq].obr,13);
         end;
       end;
   putseg2xms(handles[4],...) is replaced by putseg2_ar(...) reading g_handle4.
   NOTE: the Pascal `visible` flag is set by check_visible() (needs the bl^ map)
   during the real gameplay loop; the C-C draw_state stand-in has no bl^, so the
   level-load path marks in-room objects visible before this runs. */
static void cc_print_predmet2(void)
{
    int wq;
    static int cc_calls = 0;
    if (getenv("DBG_DUMP_VEC")) {
        fprintf(stderr, "[host] cc_print_predmet2 call=%d nahrane_veci=%d mies=%d\n",
                cc_calls, (int)g_nahrane_veci, (int)g_miestnost);
        for (int q = 1; q <= (int)g_nahrane_veci && q <= 400; q++) {
            predmet *vv = &g_vec[q];
            fprintf(stderr, "[host]   vec[%d] mie=%d vis=%d c3=0x%02x c4=0x%02x\n",
                    q, (int)vv->mie, (int)vv->visible, vv->c[3], vv->c[4]);
        }
    }
    cc_calls++;
    if (getenv("DBG_VEC_DRAW")) {
        fprintf(stderr, "[VEC-DRAW] call=%d g_miestnost=%d nahrane_veci=%d\n",
                cc_calls, (int)g_miestnost, (int)g_nahrane_veci);
        for (int q = 1; q <= (int)g_nahrane_veci && q <= 60; q++) {
            predmet *vv = &g_vec[q];
            int draw = (vv->mie == g_miestnost && vv->visible);
            fprintf(stderr, "[VEC-DRAW]   vec[%d] mie=%d x=%d y=%d vis=%d -> %s\n",
                    q, (int)vv->mie, (int)vv->x, (int)vv->y, (int)vv->visible, draw ? "DRAW" : "skip");
        }
    }
    for (wq = 1; wq <= g_nahrane_veci; wq++) {
        predmet *v = &g_vec[wq];
        if (v->mie != g_miestnost || !v->visible)
            continue;
        /* PROCESS.PAS process_all animated branch.  An object whose name has
           'A' in the 2nd char (vec.meno[2]='A' -> c[1]=='A') carries the
           animated indicator and is drawn from the anim sheet EVERY frame.
           The Pascal code (PROCESS.PAS:36-65) always animates such objects,
           choosing the frame counter by useanim/smer:
               useanim  -> cell = anic  + anx[obr]   (putseg2)
               !useanim & smer -> cell = bloing + anx[obr] (putseg2_rev)
               !useanim & !smer-> cell = bloing + anx[obr] (putseg2)
           so the cell is anic+anx[obr] when useanim, else bloing+anx[obr].
           Monsters (funk 2/3/4/5) have c[1]=='A' but useanim=false, so they
           animate via bloing -- the previous C port drew them STATIC because
           it only animated when (c[1]=='A') && useanim.
           draw_state() redraws the whole scene (fb_vfill + print_texture)
           before this runs, so the background behind every object is fresh
           each frame; the three Pascal sub-branches therefore collapse to a
           single putseg2() over the fresh scene (equivalent to the original
           putseg2[_rev]_mix over the object's zas copy), and ox/oy follow
           x/y on move. */
        if (v->c[1] == 'A') {
            unsigned int base = v->useanim ? anic : bloing;
            unsigned int cell = (unsigned int)(base + anx[v->obr]);
            if (v->change) {
                /* process_all: on move, ox/oy follow x/y (the old cell is
                   gone with the fresh redraw). */
                v->ox = v->x;
                v->oy = v->y;
            }
            /* TEST/verification log (gated by DBG_ANIM_LOG=1; cheap: one line
               per animated object per frame).  The log order is frame order,
               so the per-object cell sequence shows whether the sprite frame
               advances.  Uses a local frame counter (gen is declared later in
               this TU and is out of scope here). */
            static unsigned cc_frame_no = 0;
            /* horizontal mirror decision (PROCESS.PAS:47-65): mirror only when
               animating from the bloing sheet (!useanim) AND heading right
               (smer).  Logged so movement/mirror behaviour can be verified. */
            int mirror = (!v->useanim && v->smer) ? 1 : 0;
            if (getenv("DBG_ANIM_LOG"))
                fprintf(stderr,
                        "[host] frame=%u f=%2d [%c%c%c%c] funk=%d obr=%d useanim=%d base=%d cell=%d x=%d y=%d smer=%d mirror=%s\n",
                        (unsigned)(cc_frame_no + 1), wq, v->c[0], v->c[1], v->c[2], v->c[3],
                        (int)v->funk, (int)v->obr, (int)v->useanim,
                        (int)base, (int)cell,
                        (int)v->x, (int)v->y, (int)v->smer, mirror ? "yes" : "no");
            cc_frame_no++;
            /* Restore the Pascal horizontal-mirror that the earlier "collapse to
               a single putseg2()" dropped.  PROCESS.PAS process_all splits the
               animated branch on `smer` (PROCESS.PAS:47-65):
                   useanim  -> putseg2(anic +  anx[obr])   (never mirrored)
                   !useanim & smer -> putseg2_rev(bloing+anx[obr])  <-- MIRROR
                   !useanim & !smer -> putseg2(bloing+anx[obr])    (no mirror)
               so an object animating from the bloing sheet (!useanim) is drawn
               mirrored (putseg2_rev) exactly when it is heading right (smer).
               This is the sprite-saving trick: the monster faces the direction
               it moves, so it mirrors instead of carrying a second sprite.  The
               fresh-scene redraw from draw_state() still lets the three
               sub-branches collapse to one blit, so only the mirror is restored. */
            if (!v->useanim && v->smer)
                putseg2_rev(v->x, v->y, resx, resy, cell, 13, anim);
            else
                putseg2(v->x, v->y, resx, resy, cell, 13, anim);
        } else {
            putseg2_ar(v->x, v->y, resx, resy, v->obr, 13, g_handle4);
        }
    }
}

/* --------------------------------------------------------------------- */
/* BOTTOM HUD BAR globals (LOAD235.PAS redraw).  Declared here (before    */
/* use by the bar functions below) though GAME.INC / SI35.PAS capture    */
/* them in the big capture block near the bottom of this file.           */
/* --------------------------------------------------------------------- */
static int      score;                       /* current score              */
static int      basic_score;                 /* animated score (vypis_skore) */
static int      zivoty;                      /* lives                      */
static char     sprava[32];                  /* objective text (hra_init)  */
static unsigned char own[4];                 /* inventory slots own[1..3]  */
/* g_mov -- the object the avatar is currently pointing at, set by zisti_vec.
   Faithful to the Pascal GAME.INC global `mov` that menu_init() reads when the
   inventory overlay opens (es_state=23).  0 = nothing pointed at. */
unsigned short g_mov = 0;

/* --------------------------------------------------------------------- */
/* BOTTOM HUD BAR (LOAD235.PAS redraw -- score / lives / inventory / timer)*/
/*                                                                       */
/* The original engine paints a bar along the bottom of the screen.  It  */
/* is drawn by redraw() (LOAD235.PAS) AFTER the grid + vec^[]:           */
/*   redraw_score    "Score: <basic_score>"   at (450,  vypisy-26)       */
/*   vypis_skore     animate basic_score->score, redraw at (498,..)      */
/*   draw_lifes      "Lifes: <zivoty>" + life icons at (450, vypisy-9)   */
/*   draw_inventar   "Inventory:" + up to 3 item cells at (vypisy-9)     */
/*   time_out        "Time: <timer>"          at (40,  vypisy-26)        */
/*   print_texture   level name + objective + draw_lifes                 */
/* --------------------------------------------------------------------- */

/* redraw_score -- LOAD235.PAS.  "Score: <basic_score>" at (450, vypisy-26). */
static void redraw_score(void)
{
    char buf[48];
    snprintf(buf, sizeof(buf), "%s%d", TX(g_ja, 21), basic_score);
    fb_vstr_nobg(450, HUD_VYPISY - 26, buf, 62);
}

/* vypis_skore -- LOAD235.PAS.  Animate basic_score toward score, then redraw
   the score cell so the bar counts up to the new total.  soundplaying(0) is
   stubbed to false, so the `not soundplaying(0)` guard is always true. */
static void vypis_skore(void)
{
    int rozdiel;
    char sco[16];
    if (basic_score == score) return;
    rozdiel = (score - basic_score) / 5;   /* div 5 -- the count-up speed */
    if (rozdiel == 0) rozdiel = 1;
    basic_score += rozdiel;
    sprintf(sco, "%d", basic_score);
    cc_rectangle2(498, HUD_VYPISY - 26, 64, 16, 0);  /* okno(...) clear */
    /* pust(0);  sound stub */
    fb_vstr_nobg(498, HUD_VYPISY - 26, sco, 69);
}

/* draw_lifes -- LOAD235.PAS.  "Lifes: <zivoty>" + one life icon each. */
static void draw_lifes(void)
{
    char buf[32];
    int f, zn;
    snprintf(buf, sizeof(buf), "%s%d", TX(g_ja, 8), zivoty);
    cc_rectangle2(450, HUD_VYPISY - 9, 120, 16, 0);   /* clear the row */
    fb_vstr_nobg(450, HUD_VYPISY - 9, buf, 63);
    if (zivoty < 5) zn = zivoty; else zn = 5;
    for (f = 1; f <= zn; f++)
        putseg2(508 + f * 16, HUD_VYPISY - 9, resx, resy, f - 1, 13, cc_ar());
}

/* draw_inventar -- LOAD235.PAS.  "Inventory:" + up to 3 held items.  An empty
   slot shows cell 45 of the character sheet; an occupied slot shows the
   vec^[own[f]].obr sprite from the GVECI table (g_handle4). */
static void draw_inventar(void)
{
    int f, slot;
    cc_rectangle2(115, HUD_VYPISY - 9, 3 * 35, resy, 0);   /* clear the cells */
    fb_vstr_nobg(40, HUD_VYPISY - 9, TX(g_ja, 27), 15);    /* "Inventory:"  */
    for (f = 1; f <= 3; f++) {
        slot = own[f];
        if (slot <= 0 || slot > g_nahrane_veci)
            putseg2(80 + f * 35, HUD_VYPISY - 9, resx, resy, 45, 13, cc_ar());
        else
            putseg2_ar(80 + f * 35, HUD_VYPISY - 9, resx, resy,
                       g_vec[slot].obr, 13, g_handle4);
    }
}

/* draw_timer -- LOAD235.PAS time_out countdown label.  "Time: <timer>" at
   (40, vypisy-26); colour 12 when low (<30s) else 15.  The C-C engine drains
   g_cfg.timer via time_out(); here we only paint the current value (the whole
   frame is fb_vfilled each pass, so the cell is already clear). */
static long g_draw_timer_calls;   /* forward decl; defined near the other test globals */
static void draw_timer(void)
{
    char buf[32];
    int c;
    g_draw_timer_calls++;
    if (g_cfg.timer == 0) return;          /* no time limit set for this level */
    c = (g_cfg.timer < 30) ? 12 : 15;
    snprintf(buf, sizeof(buf), "%s%d", TX(g_ja, 1), g_cfg.timer);
    cc_rectangle2(70, HUD_VYPISY - 26, 50, 16, 0);   /* time_out: clear cell */
    fb_vstr_nobg(40, HUD_VYPISY - 26, buf, c);
}

/* line(bitmap,x1,y1,x2,y2,coul) -- JxGRAPH.line (Bresenham).  The C-C engine
   has no BGI line; this strokes the pixels cc_stvorec2 needs for the frame.
   Defined first because cc_stvorec2() calls it. */
static void cc_line(int x1, int y1, int x2, int y2, unsigned char col)
{
    int dx = (x2 > x1) ? (x2 - x1) : (x1 - x2);
    int dy = (y2 > y1) ? (y2 - y1) : (y1 - y2);
    int sx = (x1 < x2) ? 1 : -1;
    int sy = (y1 < y2) ? 1 : -1;
    int err = dx - dy, e2;
    for (;;) {
        cc_putpixel(x1, y1, col);
        if (x1 == x2 && y1 == y2) break;
        e2 = err;
        if (e2 > -dy) { err -= dy; x1 += sx; }
        if (e2 <  dx) { err += dx; y1 += sy; }
    }
}

/* help_line1 / help_line2 -- LOAD235.PAS.  The "ciara pre mrazak" scratch
   lines drawn by redraw() right after the frame.  lajna is the C-C engine's
   byte-per-pixel scratch row (tline stand-in); fill it, then blit 3 rows of
   250 pixels via write_linepos.  help_line1 sits left (x=40), help_line2 the
   right block (x=350), both at y = vypisy-31..vypisy-29. */
static void help_line1(void)
{
    int f;
    for (f = 0; f <= 250; f++) lajna[f] = 1;
    for (f = 1; f <= 3; f++) write_linepos(40, 428 + f, 250, lajna);
}

static void help_line2(void)
{
    int f;
    for (f = 0; f <= 250; f++) lajna[f] = 197;
    for (f = 1; f <= 3; f++) write_linepos(350, 428 + f, 250, lajna);
}

/* stvorec2(x,y,x1,y1,col1,col2,num) -- JXMENU.stvorec2.  Stroke a `num`-pixel
   thick border rectangle (border colour col1+f, a 20..29 gradient) with
   cc_line(), then fill its interior with col2.  Used by LOAD235.PAS redraw()
   to draw the decorative frame around the bottom HUD bar:
       stvorec2(0,416,639,62,20,0,10);   ->  y = 416..478, full width. */
static void cc_stvorec2(int x, int y, int x1, int y1,
                        int col1, int col2, int num)
{
    int f;
    for (f = 0; f < num; f++) {
        cc_line(x + f,    y + f,    x1 + x - f, y + f,    (unsigned char)(col1 + f));
        cc_line(x + f,    y + f,    x + f,      y + y1 - f, (unsigned char)(col1 + f));
        cc_line(x1 + x - f, y + f,  x1 + x - f, y + y1 - f, (unsigned char)(col1 + f));
        cc_line(x + f,    y1 + y - f, x1 + x - f, y1 + y - f, (unsigned char)(col1 + f));
    }
    /* interior fill (after the border) -- colour 0 (black) here. */
    cc_rectangle2(x + f, y + f, x1 - f * 2, y1 - f * 2, (unsigned char)col2);
}

/* draw_hud -- paint the whole bottom bar once per gameplay frame.  Mirrors
   the tail of LOAD235.PAS redraw(): redraw_score + vypis_skore (score),
   draw_lifes (lives) and draw_inventar (inventory).  The timer is painted by
   draw_timer() (LOAD235.PAS time_out label) and the level name / objective by
   print_texture(). */
static void draw_hud(void)
{
    draw_timer();
    redraw_score();
    vypis_skore();
    draw_lifes();
    draw_inventar();
}

/* check_visible -- LOAD235.PAS:1595.  Gates each object's visibility on the   */
/* discovery map g_bl (the "hidden in dark" mechanic): an object in the room   */
/* is visible only when its tile has been discovered, i.e. g_bl[(x-8) div 16,  */
/* y div 16], or when it is the level-complete door (funk=9, inf1=1,           */
/* mie=miestnost) which is revealed regardless of the fog.  The Pascal body    */
/* saves/restores the object sprite to vec^.zas via getseg() when             */
/* get_back is set; the C-C engine always has the sprite in g_handle4          */
/* (carved by cc_load_veci), so that save/restore is unnecessary and dropped.  */
/* Called once per frame from panak() (mirrors SI35.PAS panak ->               */
/* check_visible(true)) and once at level load.                               */
static void check_visible(unsigned char get_back)
{
    int f, cx, cy;
    (void)get_back;                          /* sprite always in g_handle4   */
    if (st.stav != 2 && st.stav != 4) return;
    if (!maze_bl_active) return;
    for (f = 1; f <= g_nahrane_veci; f++) {
        /* bl^[(vec.x-8) div 16, vec.y div 16]  (guard x<8 underflow) */
        cx = (g_vec[f].x >= 8) ? (int)((g_vec[f].x - 8) / 16) : 0;
        cy  = (int)(g_vec[f].y / 16);
        if (cx < 0) cx = 0;  if (cx > MIE_X) cx = MIE_X;
        if (cy < 0) cy = 0;  if (cy > MIE_Y) cy = MIE_Y;
        int revealed = g_bl[cx][cy]
                    || (g_vec[f].funk == 9
                        && g_vec[f].inf1 == 1
                        && g_vec[f].mie == g_miestnost);
        if (revealed) {
            if (!g_vec[f].visible) g_vec[f].change = 1;
            g_vec[f].visible = 1;
        } else {
            if (g_vec[f].visible) g_vec[f].change = 1;
            g_vec[f].visible = 0;
        }
    }
}

/* cc_draw_gif_block_pub(kluc, fromx, fromy) -- PUBLIC wrapper so menu.c can
 * call draw_gif_block(screen, input_file, 'GLOGO', 460, 100, palx) exactly
 * as GAME.INC does.  Loads the DAT block <kluc> from MAIN.DAT and decodes it
 * at (fromx, fromy).  The internal cc_draw_gif_block() is the BLOCKX.PAS:416
 * Jx1/LZW decoder; draw_it() above reaches it via the '>' key path. */
void cc_draw_gif_block_pub(const char *kluc, int fromx, int fromy)
{
    cc_draw_gif_block_dat("MAIN.DAT", kluc, fromx, fromy);
}

/* cc_draw_gif_block(kluc,x,y) -- convenience wrapper loading the block from
 * MAIN.DAT (the Pascal block_file).  Kept so the '>' path in draw_it() and
 * any other caller keeps working unchanged. */
static void cc_draw_gif_block(const char *kluc, int fromx, int fromy)
{
    cc_draw_gif_block_dat("MAIN.DAT", kluc, fromx, fromy);
}

/* --------------------------------------------------------------------- */
/* draw_gif_block (BLOCKX.PAS:416) -- Siriel custom Jx1/LZW GIF decoder.  */
/*                                                                       */
/* The block-file abstraction is replaced by dat_load_array(): the whole */
/* DAT block is read into memory and get() reads sequentially from it.   */
/* The LocPal / gifimage fields are populated exactly as the Pascal but  */
/* never read back (the decoded indices are written to the bitmap), so   */
/* they are loaded and discarded, matching the original control flow.    */
/* --------------------------------------------------------------------- */
static void cc_draw_gif_block_dat(const char *dat, const char *kluc,
                                  int fromx, int fromy)
{
    /* ---- the DAT block + sequential read position (the "SoundFile") --- */
    /* Get the block size from the DAT record (BLOCKX.GetBlockFile), then
       load exactly that many bytes.  (A naive dat_load_array(dat,kluc,NULL,0)
       size probe is wrong: its bufsz=0 trips the "bufsz < size" guard and
       always reports 0.) */
    int blksz = dat_block_size(dat, kluc);
    unsigned char *block;
    int pos = 0;                 /* current read offset in block        */
    int ok;

    if (blksz <= 0) return;
    block = malloc((size_t)blksz);
    if (!block) return;
    if (dat_load_array(dat, kluc, block, blksz) < blksz) { free(block); return; }

    /* ---- LZW workspaces (BLOCKX thashbyte / thashword) ---- */
    unsigned char *WorkSpace1 = calloc(4096, 1);
    unsigned char *WorkSpace2 = calloc(4096, 1);
    int           *WorkSpace3 = calloc(4096, sizeof(int));
    unsigned char  GifBlock[256];
    unsigned char  line_gif[1024];

    int GifError = 0;
    int Interlaced = 0;
    int ImageWidth = 0, ImageHeight = 0;
    int line_nb = 0, currentx = 0, byt = 0;
    int pixcount = 0;
    unsigned char ch;

    /* GifHeader (packed 13 bytes) */
    unsigned char GifHeader[13];

    /* LocPal: the (optional) local palette after the header.  Max size is
       256 colour entries * 3 bytes = 768 (BLOCKX declares it as a fixed
       buffer).  Only read when GifHeader.Flags & 128 (a global palette is
       present); otherwise it is left untouched, matching the Pascal. */
    unsigned char LocPal[768];

    /* GIF_GET(dst,nb): read nb bytes from block+pos into dst (BLOCKX.get).
       Returns 0 on a short read, mirroring ioresult<>0. */
    #define GIF_GET(dst, nb, _ok) do { \
        if (pos + (nb) > blksz) { _ok = 0; } \
        else { memcpy((dst), block + pos, (nb)); pos += (nb); _ok = 1; } \
    } while (0)

    /* ---- header ---- */
    GIF_GET(GifHeader, 13, ok); if (!ok) goto done;

    /* signature must be 'GIF' or 'Jx1' */
    if (!((GifHeader[0] == 'G' && GifHeader[1] == 'I' && GifHeader[2] == 'F') ||
          (GifHeader[0] == 'J' && GifHeader[1] == 'x' && GifHeader[2] == '1')))
        goto done;

    {
        int flg = GifHeader[10];
        int ColorBits = (flg & 7) + 1;
        if (flg & 128) { GIF_GET(LocPal, 3 * (1 << ColorBits), ok); if (!ok) goto done; }
    }

    /* Block loop (BLOCKX: `While (ch=',') or (ch='!') or (ch=#0)`).  Walks
       the image-data-separators ',' (each followed by a 9-byte packed
       ImageBlock -- {$packrecords 1} => SizeOf(ImageBlock)=9, NOT 10) and
       any '!' extensions, until the image block is found.  The compression
       code size 'c' following the ImageBlock is the UnpackImage 'bits'. */
    ch = 0;
    for (;;) {
        unsigned char iblock[9];
        unsigned int ibflags;

        GIF_GET(&ch, 1, ok); if (!ok) goto done;        /* Get(ch,1) */

        if (ch == '!') {                                /* SkipExtension */
            unsigned char ext, sk;
            GIF_GET(&ext, 1, ok); if (!ok) goto done;   /* Get(c,1) */
            switch (ext) {
            case 0x01: {                                /* graphic extension */
                unsigned char gbuf[13];
                GIF_GET(gbuf, 13, ok); if (!ok) goto done;
                GIF_GET(&sk, 1, ok);   if (!ok) goto done;
                while (sk > 0) {
                    unsigned char eb[256]; unsigned int nn = sk;
                    if (nn > sizeof(eb)) nn = sizeof(eb);
                    GIF_GET(eb, nn, ok); if (!ok) goto done;
                    GIF_GET(&sk, 1, ok);   if (!ok) goto done;
                }
                break;
            }
            case 0xf9: {
                unsigned char gbuf[6];
                GIF_GET(gbuf, 6, ok); if (!ok) goto done;
                break;
            }
            case 0xfe: {
                unsigned char sk2; unsigned char eb[256]; unsigned int nn;
                GIF_GET(&sk2, 1, ok); if (!ok) goto done;
                while (sk2 > 0) {
                    nn = sk2; if (nn > sizeof(eb)) nn = sizeof(eb);
                    GIF_GET(eb, nn, ok); if (!ok) goto done;
                    GIF_GET(&sk2, 1, ok);   if (!ok) goto done;
                }
                break;
            }
            case 0xff: {
                unsigned char gbuf[12];
                GIF_GET(gbuf, 12, ok); if (!ok) goto done;
                GIF_GET(&sk, 1, ok);   if (!ok) goto done;
                while (sk > 0) {
                    unsigned char eb[256]; unsigned int nn = sk;
                    if (nn > sizeof(eb)) nn = sizeof(eb);
                    GIF_GET(eb, nn, ok); if (!ok) goto done;
                    GIF_GET(&sk, 1, ok);   if (!ok) goto done;
                }
                break;
            }
            default: {
                unsigned char sk3; unsigned char eb[256]; unsigned int nn;
                GIF_GET(&sk3, 1, ok); if (!ok) goto done;
                nn = sk3; if (nn > sizeof(eb)) nn = sizeof(eb);
                if (nn) { GIF_GET(eb, nn, ok); if (!ok) goto done; }
                break;
            }
            }
            continue;
        }

        if (ch != ',') continue;          /* ch==#0 (or other): no-op, loop */

        /* ',' : Get(ImageBlock,9) -- {$packrecords 1} => 9 bytes. */
        GIF_GET(iblock, 9, ok); if (!ok) goto done;
        /* ImageBlock = {Left,Top,Width,Height:Word; flags:Byte}. */
        ImageWidth  = (unsigned char)iblock[4] | ((unsigned char)iblock[5] << 8);
        ImageHeight = (unsigned char)iblock[6] | ((unsigned char)iblock[7] << 8);
        ibflags = (unsigned char)iblock[8];
        if ((ibflags & 128) == 128) {             /* local colour table */
            int cb2 = (ibflags & 7) + 1;
            GIF_GET(LocPal, 3 * (1 << cb2), ok); if (!ok) goto done;
        }
        Interlaced = (ibflags & 64) == 64;
        /* c:=0; Get(c,1); UnpackImage(bitmap,c) -- the compression bits feed
           the LZW decoder below. */
        GIF_GET(&ch, 1, ok); if (!ok) goto done;
        break;                                    /* single-frame image */
    }

    /* UnpackImage(bitmap, bits) -- flattened LZW decode.  All state is local
       exactly as the nested GetBlock/UnpackImage procedures share it. */
    {
        int bits, bits2, codesize, codesize2, nextcode, oldcode, oldtoken;
        int p = 0, q = 0, blocksize, bitsleft = 8, thiscode, currentcode;
        int pass = 0;
        int u;

        memset(GifBlock, 0, sizeof(GifBlock));

        bits  = (int)ch;                 /* compression bits from ImageBlock */
        bits2 = 1 << bits;
        nextcode = bits2 + 2;
        codesize = bits + 1;
        codesize2 = 1 << codesize;
        oldcode = -1;
        oldtoken = -1;

        for (;;) {
            if (bitsleft == 8) {
                p++;
                if (p >= q) {
                    blocksize = 0;
                    GIF_GET(&blocksize, 1, ok); if (!ok) { GifError = 1; break; }
                    if (blocksize <= 0) { GifError = 1; break; }
                    p = 0;
                    GIF_GET(GifBlock, blocksize, ok); if (!ok) { GifError = 1; break; }
                    q = blocksize;
                }
                bitsleft = 0;
            }
            thiscode = GifBlock[p];
            currentcode = codesize + bitsleft;
            if (currentcode <= 8) {
                GifBlock[p] = (unsigned char)(GifBlock[p] >> codesize);
                bitsleft = currentcode;
            } else {
                p++;
                if (p >= q) {
                    blocksize = 0;
                    GIF_GET(&blocksize, 1, ok); if (!ok) { GifError = 1; break; }
                    if (blocksize <= 0) { GifError = 1; break; }
                    p = 0;
                    GIF_GET(GifBlock, blocksize, ok); if (!ok) { GifError = 1; break; }
                    q = blocksize;
                }
                thiscode = thiscode | (GifBlock[p] << (8 - bitsleft));
                if (currentcode <= 16) {
                    bitsleft = currentcode - 8;
                } else {
                    p++;
                    if (p >= q) {
                        blocksize = 0;
                        GIF_GET(&blocksize, 1, ok); if (!ok) { GifError = 1; break; }
                        if (blocksize <= 0) { GifError = 1; break; }
                        p = 0;
                        GIF_GET(GifBlock, blocksize, ok); if (!ok) { GifError = 1; break; }
                        q = blocksize;
                    }
                    thiscode = thiscode | (GifBlock[p] << (16 - bitsleft));
                    bitsleft = currentcode - 16;
                }
                GifBlock[p] = (unsigned char)(GifBlock[p] >> bitsleft);
            }
            thiscode = thiscode & wordmasktable[codesize];
            currentcode = thiscode;
            if (thiscode == bits2 + 1) break;          /* clear code */
            if (thiscode > nextcode) { GifError = 1; break; }
            if (thiscode == bits2) {                   /* reset code */
                nextcode = bits2 + 2;
                codesize = bits + 1;
                codesize2 = 1 << codesize;
                oldtoken = -1;
                oldcode = -1;
                continue;
            }
            u = 0;
            if (thiscode == nextcode) {
                if (oldcode == -1) { GifError = 1; break; }
                WorkSpace1[u] = (unsigned char)oldtoken;
                u++;
                thiscode = oldcode;
            }
            while (thiscode >= bits2) {
                WorkSpace1[u] = WorkSpace2[thiscode];
                u++;
                thiscode = WorkSpace3[thiscode];
            }
            oldtoken = thiscode;

            for (;;) {
                /* put(thiscode,1) with death_color recycle */
                {
                    int val = thiscode;
                    if (val == (int)death_color)
                        val = cc_getpixel(fromx + currentx, fromy + line_nb);
                    line_gif[currentx] = (unsigned char)val;
                    pixcount++;
                    currentx++;
                    if (currentx >= ImageWidth) {
                        cc_write_linepos(line_gif, fromx, fromy + line_nb, ImageWidth);
                        currentx = 0;
                    }
                }
                byt++;
                if (byt >= ImageWidth) {
                    byt = 0;
                    if (Interlaced) {
                        line_nb += inctable[pass];
                        if (line_nb >= ImageHeight) { pass++; line_nb = starttable[pass]; }
                    } else {
                        line_nb++;
                    }
                }
                if (u <= 0) break;
                u--;
                thiscode = WorkSpace1[u];
            }
            if ((nextcode < 4096) && (oldcode != -1)) {
                WorkSpace3[nextcode] = oldcode;
                WorkSpace2[nextcode] = oldtoken;
                nextcode++;
                if ((nextcode >= codesize2) && (codesize < 12)) {
                    codesize++;
                    codesize2 = 1 << codesize;
                }
            }
            oldcode = currentcode;
        }
    }
    if (getenv("DBG_GIF_COUNT")) fprintf(stderr, "[DBG] pixcount=%d ImageWidth=%d ImageHeight=%d GifError=%d\n", pixcount, ImageWidth, ImageHeight, GifError);
done:
    free(block);
    free(WorkSpace1);
    free(WorkSpace2);
    free(WorkSpace3);
    #undef GIF_GET
}

/* DEBUG helper: decode the Jx1 block <kluc> from DAT <dat> into the 8-bit
 * framebuffer at (0,0) and write the palx-expanded 24-bit image to <ppm>.
 * Used to prove GTREEP (the intro background, in the game DAT) decodes to
 * the same blue palette as the reference Pascal build. */
void cc_dump_gif_block_dat(const char *dat, const char *kluc, const char *ppm)
{
    int i, x, y;
    FILE *f;
    cc_clear_bitmap();
    cc_draw_gif_block_dat(dat, kluc, 0, 0);
    fb_expand();
    f = fopen(ppm, "wb");
    if (!f) return;
    fprintf(f, "P6\n640 480\n255\n");
    for (y = 0; y < 480; y++)
        for (x = 0; x < 640; x++) {
            int p = (y * 640 + x) * 3;
            unsigned char rgb[3] = { frame_rgb[p], frame_rgb[p+1], frame_rgb[p+2] };
            fwrite(rgb, 1, 3, f);
        }
    fclose(f);
}

/* --------------------------------------------------------------------- */
/* DEBUG accessors for the carved sprite tables (load_pohyby / cc_load  */
/* anim populate ar^ / anim^).  Used by build/verify_sprites.c to prove  */
/* the sprite loader carved real (non-blank) tile data.  Returns the     */
/* number of non-zero bytes in a 16x16 cell (0..256; -1 out of range).   */
/* --------------------------------------------------------------------- */
int cc_ar_cell_nonbg(int cell)
{
    int i, n = 0;
    if (cell < 0 || cell >= SIR_NUMS) return -1;
    for (i = 0; i < 256; i++)
        if (ar[cell * 256 + i] != 0) n++;
    return n;
}
int cc_ar_nonbg_total(void)
{
    int i, n = 0;
    for (i = 0; i < SIR_NUMS * 256; i++)
        if (ar[i] != 0) n++;
    return n;
}

/* DEBUG: return pointer to the 16x16 bytes of ar[] cell (NULL if bad). */
unsigned char *cc_ar_cell_ptr(int cell)
{
    if (cell < 0 || cell >= SIR_NUMS) return NULL;
    return &ar[cell * 256];
}

int cc_anim_cell_nonbg(int cell)
{
    int i, n = 0;
    if (cell < 0 || cell >= ANIM_NUMS) return -1;
    for (i = 0; i < 256; i++)
        if (anim[cell * 256 + i] != 0) n++;
    return n;
}
int cc_anim_nonbg_total(void)
{
    int i, n = 0;
    for (i = 0; i < ANIM_NUMS * 256; i++)
        if (anim[i] != 0) n++;
    return n;
}

/* --------------------------------------------------------------------- */
/* expand_frame: mirror vid_dispatch.inc exactly -- 8-bit VideoBuffer +   */
/* palx (record{r,v,b}) -> 24-bit FrameRGB.                                */
/*                                                                         */
/*   for i := 0 to FBW*FBH-1 do begin                                     */
/*     idx  := VideoBuffer[i];                                            */
/*     p    := i*3;                                                       */
/*     FrameRGB[p+0] := palx[idx].r;                                      */
/*     FrameRGB[p+1] := palx[idx].v;                                      */
/*     FrameRGB[p+2] := palx[idx].b;                                      */
/*   end;                                                                  */
/*                                                                         */
/* Linear index i = y*640 + x runs 0..307199 over the stride-1 VideoBuffer*/
/* (identical to the nested y/x loop). palx is 3 bytes/entry, so          */
/* palx[idx].r/.v/.b == pal[idx*3+0..2].                                   */
/* --------------------------------------------------------------------- */
void fb_expand(void)
{
    int i;
    for (i = 0; i < VBUFSZ; i++) {
        t_palette p = palx[video_buffer[i]];
        long pp = (long)i * 3;
        frame_rgb[pp + 0] = p.r;
        frame_rgb[pp + 1] = p.v;
        frame_rgb[pp + 2] = p.b;
    }
}

/* ===================================================================== */
/* STATE-21 GAMEPLAY MOVEMENT (GAME.INC + GEO.PAS + POCHECK3.INC +       */
/* LOAD235.PAS + SI35.PAS).                                              */
/*                                                                       */
/* Faithful C port of the missing Pascal gameplay source.  The C-C engine*/
/* owns the keyboard: engine_press_key() feeds g_auto_key_pending, which  */
/* get_keyboard() turns into the physical-key table klx[] read by        */
/* zmack(); the step loop steers si.x/si.y via sipka_fake and redraws via*/
/* panak()/draw_panak().  This block lives in engine.c because it touches */
/* the framebuffer, ar^/te^/vec^/st exactly like the Pascal units.       */
/* ===================================================================== */

/* ---- game-state globals (Pascal var sections) ---- */
static unsigned short movx, movy, mova;      /* per-stav movement params    */
static unsigned short startx, starty;        /* START position (strata_zivota) */
static unsigned short aktual = 1;            /* current map number          */
static unsigned short px16, py16;            /* px+12, py+12 (zisti_vec)    */
static unsigned short sipkaminx, sipkaminy, sipkamaxx, sipkamaxy, sipkastep;
static int      joystick_able;
static unsigned char tolerancia;
static int      hore, dole, lavo, pravo;
static int      klx[129];                    /* GEO.PAS physical-key table  */
static unsigned short last;                  /* last sipka direction        */
static int      anim_count;                  /* SI35.PAS animation counter  */
/* g_shut_down_siriel -- SI35.PAS `shut_down_siriel`: set when an object is   */
/* within the panak interaction radius (object_movement).  The caller skips  */
/* the player pose advance while it is set, exactly as PROCESS.PAS `process_ */
/* all` resets the character instead of animating.                          */
static int      g_shut_down_siriel = 0;
static int      rollup;                      /* arcade up-count            */
static int      rolldown;                    /* arcade fall flag           */
static int      same;                        /* smart_jump helper          */
static int      oldkey;                      /* arcade last-dir index      */
static unsigned short gravity, rolling;      /* arcade gravity/jump        */
static int      smart_jump;                  /* SMARTJUMP config           */
static int      lifting, use_lift;           /* LIFT flags                 */
static int      pom;                         /* idle-animation timer       */
int         completer = 1;              /* completion requirement (def_completer=1);
                                           set from a funk=9 door's inf1 in load235.c
                                           prirad, mirroring LOAD235.PAS:606 */
static int      ok;                          /* level already completed    */
static unsigned short g_auto_key_pending;    /* gameplay pending key word  */
static long     game_time;                   /* virtual clock (stubbed)    */
static long     g_time_out_calls = 0;        /* TEST: time_out() entries     */
static long     g_time_out_drained = 0;      /* TEST: time_out() drains      */
static long     g_draw_timer_calls = 0;      /* TEST: draw_timer() invocations */
static unsigned short wait_point;            /* arcade wait window         */
static unsigned short k;                     /* GAME.INC scratch key word  */
static unsigned short oldpol;                /* last pose (parity)         */
static unsigned short pad_pol;               /* padak_check counter        */
static int      padak_pose;                  /* pose cell padak_check drew  */
static int      win_now_flag;                /* test hook: force level win */
static int      hra_playing;                 /* GAME.INC: simulation armed */
static long     step_count = 0;              /* debug: step counter */

/* loop / coordinator gate flags (GAME.INC / LOAD235.PAS / SI35.PAS) */
static int arc_done_flag, maze_done_flag;
static int acc_init_flag, acc_done_flag, acc_last;
static int acc_painted;               /* state 22: congratulations window drawn once */
static char acc_pass[64];             /* state 22: next-level password (st.meno, '>' stripped) */
static int g_game_over_painted;       /* state 20: R.I.P. splash drawn once */
static int g_game_over_done;          /* state 20: Enter/Space/ESC accepted */
static int quit_pending_flag, help_pending_flag, inv_pending_flag;

/* forward declarations: the captured-key word and the sound stub are defined
   further down in engine.c, but the movement port below already uses them. */
static unsigned short g_step_key;   /* captured DOS key word for this step */
static void pust(int snd);          /* sound stub (defined further down) */

/* ---- prototypes (functions below are mutually recursive) ---- */
static void sipka_limit(unsigned short, unsigned short, unsigned short,
                        unsigned short, unsigned short, int, unsigned char,
                        int, int, int, int);
static void non_key(void);
static void key_swap(unsigned short, int);
static int  zmack(unsigned short);
static void sipka_fake(unsigned short, unsigned short *, unsigned short *);
static void sipka_spat(unsigned short *, unsigned short *);
static void sipka_joystick(void);
static void sipka_joystick2(void);
static void clear_key_buffer(void);
static int  keypressed(void);
static unsigned short ckey(void);
static void get_keyboard(void);
static void pl(unsigned short);
static int  po(unsigned int, unsigned int);
static int  po3(unsigned int, unsigned int);
static void time_out(void);
static void panak(void);
static void vypis_skore(void);
static void rewait(void);
static void aktivuj_texturu(void);
static void padak_check(void);
static void help_in_game(void);
static void briefing_in_game(void);
static void zisti_vec(void);
static void use_vec(unsigned short);
static void accomplish(void);
static void strata_zivota(void);
static void accomplished(void);
static void acc_init(void);
static void zhasni_vec_local(predmet *v);
static void redraw_local(int force);
static void go_to_new_stage(unsigned short, unsigned short, unsigned short);
static void go_to_new_stage2(unsigned short, unsigned short, unsigned short);
static void transfer_to_new_stage(unsigned short, unsigned short, unsigned short, int);

/* ---- sound / palette / display stubs (visual-only, redirected to no-ops) */
static void pust2(int snd)          { (void)snd; }
static void pust_extra(int n)       { (void)n; }
static void play_ball(void)         {}

/* ===================================================================== */
/* FLI / FLC intro animation (LOAD235.PAS play_ani -> aaplay).           */
/*                                                                       */
/* play_ani(vstup) is called from cc_game_reset() (hra_init) when a level */
/* starts.  It is guarded by the level's [ANIMS]=YES (g_cfg.fli_abile),  */
/* exactly like the Pascal `if length(vstup)>0 and fli_abile`.  vstup    */
/* is a mov_string pair "<FLIBLOCK>,<SND>" (e.g. "AI1,ZAI1"); the first   */
/* token is the FLI block to decode, the second the sound block (the     */
/* Z-prefix marks audio -- stubbed here).  The block is read from the    */
/* game DAT via dat_load_array and handed to the step-able flic player.  */
/* ===================================================================== */

/* Persistent storage for the loaded FLI block: play_ani() is called from
   cc_game_reset(), which also runs on the level-CHANGE path (state 22 ->
   next level), so the block bytes must outlive the call.  A level intro is
   a few hundred KB at most; 640 KB is plenty. */
static unsigned char g_flic_block[640 * 1024];
/* g_flic: the step-able decoder state. */
static flic_player_t g_flic;
/* g_flic_playing: 1 while the intro is shown (set by play_ani, cleared when
   the last frame has been shown or the player skips it).  g_flic_done: the
   decoder has finished its last frame (so a re-entrant cc_game_reset does
   not replay an already-shown intro). */
static int g_flic_playing;
static int g_flic_done;

/* render_flic_frame -- blit the decoded 8-bit FLI frame into the 640x480
   framebuffer, 2x upscaled (the FLI is 320x200; the C-C engine renders at
   640x480, so each source pixel becomes a 2x2 block).  The palette is copied
   into palx so the result matches the DAT palette.  Centered vertically so
   the 640x400 image sits in the 640x480 frame. */
static void render_flic_frame(void)
{
    const unsigned char *img = flic_frame(&g_flic);
    const t_palette *pal = flic_pal(&g_flic);
    int w = flic_w(&g_flic), h = flic_h(&g_flic);
    int x, y, cy, ox;
    int oy0;

    if (!img || w <= 0 || h <= 0 || !pal) return;

    /* Use the FLI frame's OWN palette (pal) directly.  We deliberately do
       NOT memcpy it into the global palx: the Pascal aaplay writes each FLI
       frame's palette to the hardware DAC and, on exit, write_palette(blackx)
       resets it.  In the 24-bit C-C engine there is no DAC -- frame_rgb is
       already 8:8:8 -- so the game's real palette (palx, loaded once at boot
       by load_real_palette()) must be left untouched; otherwise the intro
       would corrupt the palette for the rest of the level (the "palette
       remains incorrect after returning to the engine" bug). */

    /* clear the whole framebuffer to black (the FLI covers 640x400 only) */
    memset(frame_rgb, 0, sizeof(frame_rgb));

    oy0 = (FBH - h * 2) / 2;                 /* vertical centring */
    for (y = 0; y < h; y++) {
        cy = oy0 + y * 2;
        for (x = 0; x < w; x++) {
            t_palette c = pal[img[(long)y * w + x]];
            ox = x * 2;
            frame_rgb[(cy * FBW + ox) * 3 + 0] = c.r;
            frame_rgb[(cy * FBW + ox) * 3 + 1] = c.v;
            frame_rgb[(cy * FBW + ox) * 3 + 2] = c.b;
            frame_rgb[(cy * FBW + ox + 1) * 3 + 0] = c.r;
            frame_rgb[(cy * FBW + ox + 1) * 3 + 1] = c.v;
            frame_rgb[(cy * FBW + ox + 1) * 3 + 2] = c.b;
            frame_rgb[((cy + 1) * FBW + ox) * 3 + 0] = c.r;
            frame_rgb[((cy + 1) * FBW + ox) * 3 + 1] = c.v;
            frame_rgb[((cy + 1) * FBW + ox) * 3 + 2] = c.b;
            frame_rgb[((cy + 1) * FBW + ox + 1) * 3 + 0] = c.r;
            frame_rgb[((cy + 1) * FBW + ox + 1) * 3 + 1] = c.v;
            frame_rgb[((cy + 1) * FBW + ox + 1) * 3 + 2] = c.b;
        }
    }
}

/* play_ani -- see the header comment above.  Returns without touching the
   framebuffer when playback is disabled or there is no block. */
static void play_ani(const char *s)
{
    char fli_name[32];
    char sound[32];
    unsigned short poradie = 1;
    int n;

    /* guard: like the Pascal `length(vstup)>0 and fli_abile`. */
    if (!g_cfg.fli_abile || !s || !*s) {
        g_flic_playing = 0;
        if (getenv("DBG_FLIC")) fprintf(stderr, "[FLIC] play_ani: disabled (fli_abile=%d s='%s')\n",
                                        g_cfg.fli_abile, s ? s : "(null)");
        return;
    }

    /* mov_string splits "<FLIBLOCK>,<SND>" -> fli_name / sound. */
    mov_string(s, fli_name, sizeof(fli_name), &poradie);
    mov_string(s, sound, sizeof(sound), &poradie);
    if (fli_name[0] == '\0') {
        g_flic_playing = 0;
        return;
    }
    /* Siriel prefixes password-protected / locked block names with '>'.  The
       DAT block itself is keyed 'AI1' (not '>AI1'), so strip the marker before
       the lookup -- the same convention load_palette_block() uses (datx.c). */
    if (fli_name[0] == '>') memmove(&fli_name[0], &fli_name[1], strlen(fli_name));
    if (getenv("DBG_FLIC")) fprintf(stderr, "[FLIC] play_ani: block='%s' sound='%s' fli_abile=%d\n",
                                    fli_name, sound, g_cfg.fli_abile);

    /* Load the FLI block from the game DAT (e.g. "AI1" from CAULDRON.DAT). */
    n = dat_load_array(g_level_dat, fli_name, g_flic_block, sizeof(g_flic_block));
    if (n <= 0) {
        g_flic_playing = 0;
        if (getenv("DBG_FLIC")) fprintf(stderr, "[FLIC] play_ani: dat_load_array FAILED for '%s'\n", fli_name);
        return;
    }
    if (getenv("DBG_FLIC")) fprintf(stderr, "[FLIC] play_ani: loaded %d bytes\n", n);

    /* (Re)initialise the decoder.  The sound block (Z-prefix) is a no-op
       stub here, so it is ignored -- the animation still plays. */
    (void)sound;
    flic_done(&g_flic);
    if (flic_init(&g_flic, g_flic_block, n) == 0) {
        g_flic_playing = 1;
        g_flic_done = 0;
        if (getenv("DBG_FLIC")) fprintf(stderr, "[FLIC] play_ani: decoder OK w=%d h=%d frames=%d\n",
                                        flic_w(&g_flic), flic_h(&g_flic), g_flic.frame_count);
    } else {
        g_flic_playing = 0;
        if (getenv("DBG_FLIC")) fprintf(stderr, "[FLIC] play_ani: flic_init FAILED\n");
    }
}

/* Palette fade is visual-only; the scene is redrawn every frame, so these
   are no-ops.  (The real Pascal uses palx/blackx tables -- not needed here.) */
static void clear_key_buffer(void)  {}
static void rewait(void)            { (void)game_time; (void)wait_point; }
static unsigned long getclock(void) { return (unsigned long)game_time; }

/* sipka_limit(sminx,sminy,smaxx,smaxy,sstep;abile,tol,h,d,l,p) -- GEO.PAS. */
static void sipka_limit(unsigned short sminx, unsigned short sminy,
                        unsigned short smaxx, unsigned short smaxy,
                        unsigned short sstep, int abile, unsigned char tol,
                        int h, int d, int l, int p)
{
    sipkaminx = sminx; sipkaminy = sminy; sipkamaxx = smaxx;
    sipkamaxy = smaxy; sipkastep = sstep;
    joystick_able = abile; tolerancia = tol;
    hore = h; dole = d; lavo = l; pravo = p;
}

/* non_key / key_swap -- GEO.PAS physical-key table helpers. */
static void non_key(void)
{
    int i;
    for (i = 0; i <= 128; i++) klx[i] = 0;
}
static void key_swap(unsigned short cisl, int stav)
{
    klx[cisl] = stav;
}

/* zmack(cisl) -- GEO.PAS: is physical key cisl down? */
static int zmack(unsigned short cisl)
{
    return klx[cisl];
}

/* sipka_fake(pseudo,var sipx,sipy) -- GEO.PAS: step in pseudo, clamp to bounds.*/
static void sipka_fake(unsigned short pseudo, unsigned short *sipx, unsigned short *sipy)
{
    last = pseudo;
    switch (pseudo) {
    case 0x4800: (*sipy) = (unsigned short)((int)(*sipy) - sipkastep); break;
    case 0x5000: (*sipy) = (unsigned short)((int)(*sipy) + sipkastep); break;
    case 0x4b00: (*sipx) = (unsigned short)((int)(*sipx) - sipkastep); break;
    case 0x4d00: (*sipx) = (unsigned short)((int)(*sipx) + sipkastep); break;
    }
    if (*sipx < sipkaminx) *sipx = sipkaminx;
    if (*sipy < sipkaminy) *sipy = sipkaminy;
    if (*sipx > sipkamaxx) *sipx = sipkamaxx;
    if (*sipy > sipkamaxy) *sipy = sipkamaxy;
}

/* sipka_spat(var sipx,sipy) -- GEO.PAS: reverse the last sipka_fake. */
static void sipka_spat(unsigned short *sipx, unsigned short *sipy)
{
    switch (last) {
    case 0x4800: (*sipy) = (unsigned short)((int)(*sipy) + sipkastep); break;
    case 0x5000: (*sipy) = (unsigned short)((int)(*sipy) - sipkastep); break;
    case 0x4b00: (*sipx) = (unsigned short)((int)(*sipx) + sipkastep); break;
    case 0x4d00: (*sipx) = (unsigned short)((int)(*sipx) - sipkastep); break;
    }
}

/* sipka_joystick / sipka_joystick2 -- no real joystick in the C-C engine. */
static void sipka_joystick(void)  {}
static void sipka_joystick2(void) {}

/* keypressed -- geo's Jxgraf.Keypressed: a pending key word is queued. */
static int keypressed(void) { return (g_auto_key_pending != 0) ? 1 : 0; }

/* ckey -- txt.key(): return the pending DOS key word and clear it. */
static unsigned short ckey(void)
{
    unsigned short v = g_auto_key_pending;
    g_auto_key_pending = 0;
    return v;
}

/* get_keyboard -- GEO.PAS: feed the pending DOS key word into klx[].  A
 * release/break (scan byte >= 128) clears the key; 0x4d00 press -> scan 77,
 * 0xcd00 release -> scan 205.  Does NOT clear g_auto_key_pending (txt.key does).*/
static void get_keyboard(void)
{
    unsigned short klu;
    clear_key_buffer();
    if (g_auto_key_pending != 0) {
        klu = (unsigned short)(g_auto_key_pending >> 8);   /* scan code  */
        if (klu >= 128) klx[klu - 128] = 0;                /* release    */
        else            klx[klu]   = 1;                    /* press      */
        if (klu == 203 || klu == 205) non_key();
    }
}

/* pl(stav) -- LOAD135.PAS: advance the pose-frame index into its range. */
static void pl(unsigned short stav)
{
    poloha = (unsigned char)((int)poloha + 1);
    switch (stav) {
    case 1: if (poloha > 3)   poloha = 0;   break;
    case 2: if (poloha < 3 || poloha > 7)  poloha = 4;   break;
    case 3: if (poloha < 7 || poloha > 11) poloha = 8;   break;
    case 4: if (poloha < 11 || poloha > 19) poloha = 12; break;
    case 5: if (poloha < 19 || poloha > 27) poloha = 20; break;
    case 6: if (poloha < 27 || poloha > 35) poloha = 28; break;
    case 7: if (poloha < 40 || poloha > 43) poloha = 40; break;
    }
}

/* po(a1,a2) -- POCHECK3.INC: FALSE if the cell blocks (wall + opaque pixel). */
static int po(unsigned int a1, unsigned int a2)
{
    unsigned int b1, b2;
    a1 = (unsigned int)(a1 + 3);
    b1 = (unsigned int)(a1 / 16);
    b2 = (unsigned int)((a2 + 16) / 16);
    if (b1 > (unsigned int)MIE_X || b2 > (unsigned int)MIE_Y) return 0;
    if (st.mie[b1][b2] <= g_inusable) return 1;
    if (getcol(a1, a2, st.mie[b1][b2], g_te) == 13) return 1;
    return 0;
}

/* po3(a1,a2) -- POCHECK3.INC: same as po() but the +3 offset is applied to
 * both the tile index and the getcol local x.  word-wrap on the args (Pascal
 * `word` subtraction) then bounds-guard the tile access. */
static int po3(unsigned int a1, unsigned int a2)
{
    unsigned int ua1 = (unsigned int)(unsigned short)a1;  /* word wrap */
    unsigned int ua2 = (unsigned int)(unsigned short)a2;
    unsigned int b1, b2, gx;
    b1 = (ua1 + 3) / 16;
    b2 = (ua2 + 16) / 16;
    if (b1 > (unsigned int)MIE_X || b2 > (unsigned int)MIE_Y) return 0;
    if (st.mie[b1][b2] <= g_inusable) return 1;
    gx = (ua1 + 3) % 16;
    if (getcol(gx, ua2 % 16, st.mie[b1][b2], g_te) == 13) return 1;
    return 0;
}

/* time_out -- SI35.PAS level countdown.  Simplified: the C-C engine paces
 * ticks, so we only drain the timer on a coarse cadence (never mid-movement). */
static void time_out(void)
{
    static long ticks = 0;
    g_time_out_calls++;
    if (g_cfg.timer == 0) return;
    if (++ticks % 30 != 0) return;
    g_cfg.timer--;
    g_time_out_drained++;
    if (g_cfg.timer == 0) {
        zivoty = 0;
        strata_zivota();
    }
}

/* ===================================================================== */
/* OBJECT MOVEMENT -- SI35.PAS `panak` movement loop (Phase 2).          */
/*                                                                       */
/* The C-C engine previously ran only the animation-counter parity in    */
/* panak(); the per-object movement loop that walks vec^[] by its        */
/* `funk` type was missing, so every moving object (funk 2/3 oscillators */
/* in X/Y, funk 12 random walker, funk 15/18 projectiles, funk 4/5      */
/* gravity-walkers, funk 16 chaser) sat frozen.  These are faithful      */
/* ports of the GEO.PAS / SI35.PAS movement routines panak() calls, and  */
/* `object_movement()` reproduces the loop body SI35.PAS `panak` runs on */
/* the (anim_count==2 or anim_count==4) frames.                          */
/* ===================================================================== */

/* g_freez_time / g_god_time -- LOAD235.PAS `freez_time`/`god_time` runtime
 * timers.  def_freez_time / def_god_time are the defaults captured at
 * load_defaults (GAME.INC:1240).  The freeze/god effects are not yet wired
 * into the C-C engine, so both stay 0 and every in-room object moves.  Kept
 * as globals so the `freez_time=0 or (freez_time>0 and meno[3]<>'S')` gate
 * AND the danger check (`meno[3]='S' and god_time=0`) mirror Pascal exactly.
 * Because god_time is always 0, all 'S' (and 'D') objects are dangerous. */
static unsigned char def_freez_time = 0;
static unsigned char def_god_time   = 0;
static unsigned char g_freez_time = 0;
static unsigned char g_god_time   = 0;

/* Pascal `inc(x)` / `dec(x)` (word, mod-65536 wrap) and the 2-arg
 * `inc(x,n)` / `dec(x,n)`.  Inlined so the movement loop reads like the
 * Pascal source. */
#define CC_INC1(p)  ((p) = (unsigned short)((int)(p) + 1))
#define CC_DEC1(p)  ((p) = (unsigned short)((int)(p) - 1))
static inline unsigned short cc_addw(unsigned short v, unsigned short n) {
    return (unsigned short)((int)v + (int)n);
}
static inline unsigned short cc_subw(unsigned short v, unsigned short n) {
    return (unsigned short)((int)v - (int)n);
}

/* cc_random -- faithful port of Pascal `random(n)`.  Pascal seeds the 24-   */
/* bit seed once (seed=1) and advances it with the Borland LCG
 * seed := seed * 22695477 mod 16777216.  random() returns seed/16777216 as a
 * real in [0,1); random(n) = trunc(random()*n) = (seed*n) div 16777216 -- it
 * reads the HIGH bits.  (Using `seed % n` was a bug: 22695477 = 1 (mod 4),
 * so seed%4 was invariant and the `repeat random(4) until random<>k`
 * walker loop froze forever.)                                       */
static unsigned int cc_rand_seed = 1;
static unsigned short cc_random(unsigned short n)
{
    if (n == 0) return 0;
    cc_rand_seed = (unsigned int)((unsigned long long)cc_rand_seed * 22695477u) & 0xFFFFFFu;
    return (unsigned short)((cc_rand_seed * n) / 16777216u);
}

/* sipka_fake2(pseudo,var pr,krok) -- GEO.PAS: step `pr` by `krok` in `pseudo`
 * direction, clamp to bounds.  Returns 1 if the step fit, 0 if a bound was hit
 * (the caller then rejects the move).  Unlike sipka_fake, `krok` is an arbitrary
 * step, not the fixed sipkastep.  Reads x/y into locals then writes them back
 * (never takes the address of a packed member). */
static int sipka_fake2(unsigned short pseudo, predmet *pr, unsigned short krok)
{
    unsigned short x = pr->x, y = pr->y;
    switch (pseudo) {
    case 0x4800: y = (unsigned short)((int)y - (int)krok); break;
    case 0x5000: y = (unsigned short)((int)y + (int)krok); break;
    case 0x4b00: x = (unsigned short)((int)x - (int)krok); break;
    case 0x4d00: x = (unsigned short)((int)x + (int)krok); break;
    }
    pr->x = x;
    pr->y = y;
    if ((x < sipkaminx) || (y < sipkaminy) || (x > sipkamaxx) ||
        (y > sipkamaxy))
        return 0;
    return 1;
}

/* sipka_fakex(pseudo,step,var pr): boolean -- GEO.PAS: step `pr` by `step`,
 * clamp to bounds, return 1 if a bound was hit (clamped), 0 if it moved free.
 * Reads x/y into locals then writes them back (never takes the address of a
 * packed member). */
static int sipka_fakex(unsigned short pseudo, unsigned short step, predmet *pr)
{
    unsigned short x = pr->x, y = pr->y;
    int hit = 0;
    switch (pseudo) {
    case 0x4800: y = (unsigned short)((int)y - (int)step); break;
    case 0x5000: y = (unsigned short)((int)y + (int)step); break;
    case 0x4b00: x = (unsigned short)((int)x - (int)step); break;
    case 0x4d00: x = (unsigned short)((int)x + (int)step); break;
    }
    if (x < sipkaminx)  { x = sipkaminx;  hit = 1; }
    if (y < sipkaminy)  { y = sipkaminy;  hit = 1; }
    if (x > sipkamaxx)  { x = sipkamaxx;  hit = 1; }
    if (y > sipkamaxy)  { y = sipkamaxy;  hit = 1; }
    pr->x = x;
    pr->y = y;
    return hit;
}

/* incsx(plus,var pr,speed) -- SI35.PAS: move object `pr` one step in the    */
/* direction `plus` (0=left $4B00, 1=right $4D00, 2=up $4800, 3=down        */
/* $5000) by `speed`.                                                        */
static void incsx(unsigned short plus, predmet *pr, unsigned short speed)
{
    switch (plus) {
    case 0: sipka_fake2(0x4b00, pr, speed); break;
    case 1: sipka_fake2(0x4d00, pr, speed); break;
    case 2: sipka_fake2(0x4800, pr, speed); break;
    case 3: sipka_fake2(0x5000, pr, speed); break;
    }
}

/* gravitacia(var pr): boolean -- SI35.PAS: if the two feet tiles below the  */
/* object are solid, step it down one `inf1`; return 1 if it moved.         */
static int gravitacia(predmet *pr)
{
    if (po3(pr->x + 4, pr->y) && po3(pr->x - 12, pr->y)) {
        incsx(3, pr, pr->inf1);
        return 1;
    }
    return 0;
}

/* smeruj(num,step,var x,y,test_texture): boolean -- SI35.PAS: attempt a     */
/* `step` move in `num`; if test_texture, a texture hit counts as blocked.   */
/* Returns 1 = cannot pass.  On a rejected move x,y are left unchanged.      */
static int smeruj(unsigned short num, unsigned short step, predmet *v, int test_texture)
{
    int b;
    predmet t;                        /* temp copy so sipka_fakex clamps it,
                                         not the real object */
    memcpy(&t, v, sizeof(t));
    t.change = 0; t.visible = 0; t.useanim = 0;   /* irrelevant fields */
    b = sipka_fakex(num, step, &t);
    if (!b && test_texture) {
        unsigned short x2 = (unsigned short)((int)(v->x) - 6) / 16;
        unsigned short y2 = (unsigned short)((int)(v->y) + 6) / 16;
        unsigned short x3 = (unsigned short)((int)(v->x) + 6) / 16;
        unsigned short y3 = (unsigned short)((int)(v->y) / 16) + 1;
        if (st.mie[x2][y2] > g_inusable || st.mie[x2][y3] > g_inusable ||
            st.mie[x3][y2] > g_inusable || st.mie[x3][y3] > g_inusable)
            b = 1;   /* texture blocks the path */
    }
    if (!b) { v->x = t.x; v->y = t.y; }
    return b;
}

/* zmen_obrazok(f) -- SI35.PAS: swap an object's current sprite `obr` with   */
/* its target `inf4` (the "change image" pointer), clearing the direction    */
/* pointer inf7.                                                             */
static void zmen_obrazok(unsigned f)
{
    unsigned short t = g_vec[f].obr;
    g_vec[f].obr  = g_vec[f].inf4;
    g_vec[f].inf4 = t;
    g_vec[f].inf7 = 0;
}

/* movement(var x, from:word) -- SI35.PAS fireball / ballistic projectile.   */
/* `x` is the object's moving coordinate (x for inf1=1/2, y for inf1=3/4);  */
/* `from` its launch coordinate (oox / ooy).  While on screen the projectile */
/* advances one `inf3` per call; when it reaches its target it "fires":      */
/* erases its cell, hides it and flings it off-screen (x=640 / y off); on    */
/* the next tick (inf5>=inf4) it becomes visible again and resets to the    */
/* launch point.  The Pascal body also getseg/putseg the 16x16 `zas` copy   */
/* buffer; the C-C engine redraws the whole scene each frame via            */
/* cc_print_predmet2(), so only the x/y + visible + inf5 bookkeeping is     */
/* preserved here.                                                           */
static void movement(unsigned f, predmet *v, int which)
{
    if (v->visible) {
        v->visible = 0;
        v->change = 1;
        if (which == 0)  v->x = (unsigned short)((int)v->x + 1);
        else             v->y = (unsigned short)((int)v->y + 1);
        if (which == 0)  v->x = 640;                       /* fling off the right edge */
        else             v->y = 640;
    }
    v->inf5 = (unsigned short)((int)v->inf5 + 1);
    if (v->inf5 >= v->inf4) {
        /* Pascal resets the fireball timer here (SI35.PAS movement: inf5:=0)
           so the next shot fires only after inf4 more steps.  Without this the
           timer kept climbing and the ball respawned every step after the
           first -- and the unbounded counter was the other half of Issue #2. */
        v->inf5 = 0;
        v->visible = 1;
        v->x = v->oox;
        v->y = v->ooy;
        v->ox = v->x;
        v->oy = v->y;
    }
}

/* object_movement -- SI35.PAS `panak` per-object movement + change-detect.  */
/* Runs on the (anim_count==2 or anim_count==4) frames.  Mirrors the loop:   */
/*   move every in-room, animatable object by its `funk`; then set each     */
/* object's `change` flag from (ox<>x or oy<>y) and flag shut_down_siriel   */
/* when an object is close enough to the panak to interact with.            */
static void object_movement(void)
{
    unsigned short f;
    unsigned short sipx;                    /* SI35.PAS global used by funk 4/5 */

    for (f = 1; f <= g_nahrane_veci; f++) {
        /* in-room object, not frozen (freez_time=0 here) */
        if (g_vec[f].mie != g_miestnost) continue;
        if ((g_freez_time != 0) && (g_vec[f].c[2] == 'S')) continue;
        /* animatable: an 'A'-animated object, OR a non-W/V object with a
           positive funk (the scripted movers). */
        if (!((g_vec[f].c[1] == 'A') ||
              ((g_vec[f].c[0] != 'W') && (g_vec[f].c[0] != 'V') &&
               (g_vec[f].funk > 0))))
            continue;

        switch (g_vec[f].funk) {
        case 12:  {   /* nahodne pohyblivy -- random walker */
            unsigned char dir = (unsigned char)g_vec[f].inf3;
            /* pick the step direction from the current inf3, set smer */
            switch (dir) {
            case 0: sipka_fakex(0x4b00, g_vec[f].inf2, &g_vec[f]); g_vec[f].smer = 1; break;
            case 1: sipka_fakex(0x4d00, g_vec[f].inf2, &g_vec[f]); g_vec[f].smer = 0; break;
            case 2: sipka_fakex(0x5000, g_vec[f].inf2, &g_vec[f]); break;
            default: sipka_fakex(0x4800, g_vec[f].inf2, &g_vec[f]); break;
            }
            g_vec[f].inf4 = cc_subw(g_vec[f].inf4, g_vec[f].inf2);   /* inf4 -= inf2 */
            if (g_vec[f].inf1 == 0) {
                if (g_vec[f].x > 598 || g_vec[f].x < 10 ||
                    g_vec[f].y < 10 || g_vec[f].y > 392 || g_vec[f].inf4 < 4) {
                    if (g_vec[f].x > 598) g_vec[f].x = 598;
                    if (g_vec[f].x < 10)  g_vec[f].x = 10;
                    if (g_vec[f].y > 392) g_vec[f].y = 392;
                    if (g_vec[f].y < 10)  g_vec[f].y = 10;
                    g_vec[f].inf3 = cc_random(4);
                    g_vec[f].inf4 = (unsigned short)(cc_random(200) + 20);
                }
            } else {  /* inf1==1: also react to textures */
                if (g_vec[f].x > 598 || g_vec[f].x < 10 ||
                    g_vec[f].y < 10 || g_vec[f].y > 392 || g_vec[f].inf4 < 4 ||
                    st.mie[((g_vec[f].x - 6) / 16)][((g_vec[f].y) / 16)] > g_inusable ||
                    st.mie[((g_vec[f].x + 6) / 16)][((g_vec[f].y + 13) / 16)] > g_inusable) {
                    switch (g_vec[f].inf3) {
                    case 0: CC_INC1(g_vec[f].x); sipka_fakex(0x4d00, g_vec[f].inf2, &g_vec[f]); break;
                    case 1: CC_DEC1(g_vec[f].x); sipka_fakex(0x4b00, g_vec[f].inf2, &g_vec[f]); break;
                    case 2: CC_DEC1(g_vec[f].y); sipka_fakex(0x4800, g_vec[f].inf2, &g_vec[f]); break;
                    default: CC_INC1(g_vec[f].y); sipka_fakex(0x5000, g_vec[f].inf2, &g_vec[f]); break;
                    }
                    g_vec[f].inf5 = g_vec[f].inf3;
                    do { g_vec[f].inf3 = cc_random(4); }
                    while (g_vec[f].inf3 == g_vec[f].inf5);
                    g_vec[f].inf4 = cc_random(200);
                }
            }
            break;
        }
        case 2: {   /* horizontal oscillator between inf1..inf2 */
            if (g_vec[f].inf1 > g_vec[f].x) g_vec[f].smer = 0;
            if (g_vec[f].inf2 < g_vec[f].x) g_vec[f].smer = 1;
            if (g_vec[f].smer) incsx(0, &g_vec[f], g_vec[f].inf3);
            else               incsx(1, &g_vec[f], g_vec[f].inf3);
            break;
        }
        case 3: {   /* vertical oscillator between inf1..inf2 */
            if (g_vec[f].inf1 > g_vec[f].y) g_vec[f].inf7 = 1;
            if (g_vec[f].inf2 < g_vec[f].y) g_vec[f].inf7 = 0;
            incsx((unsigned short)(g_vec[f].inf7 + 2), &g_vec[f], g_vec[f].inf3);
            break;
        }
        case 4: {   /* gravity walker (horizontal choice at edges) */
            if (!gravitacia(&g_vec[f])) {
                if (po3(g_vec[f].x + 4, g_vec[f].y - 12) &&
                    po3(g_vec[f].x - 12, g_vec[f].y - 12)) {
                    sipx = g_vec[f].smer ? 0x4b00 : 0x4d00;
                    if (!sipka_fake2(sipx, &g_vec[f], g_vec[f].inf1)) {
                        if (getenv("DBG_RESPAWN"))
                            fprintf(stderr,
                                    "[host] RESPAWN funk4 f=%d [%c%c%c%c] -> (%d,%d)\n",
                                    f, g_vec[f].c[0], g_vec[f].c[1], g_vec[f].c[2], g_vec[f].c[3],
                                    g_vec[f].inf5, g_vec[f].inf6);
                        g_vec[f].x = g_vec[f].inf5;
                        g_vec[f].y = g_vec[f].inf6;
                    } else gravitacia(&g_vec[f]);
                } else {
                    if (getenv("DBG_RESPAWN"))
                        fprintf(stderr,
                                "[host] RESPAWN funk4(floorless) f=%d [%c%c%c%c] -> (%d,%d)\n",
                        f, g_vec[f].c[0], g_vec[f].c[1], g_vec[f].c[2], g_vec[f].c[3],
                        g_vec[f].inf5, g_vec[f].inf6);
                    g_vec[f].x = g_vec[f].inf5;
                    g_vec[f].y = g_vec[f].inf6;
                }
            }
            break;
        }
        case 5: {   /* gravity walker variant */
            if (!gravitacia(&g_vec[f])) {
                if (!po3(g_vec[f].x - 11, g_vec[f].y - 3)) g_vec[f].smer = 0;
                else if (!po3(g_vec[f].x + 3, g_vec[f].y - 3)) g_vec[f].smer = 1;
                sipx = g_vec[f].smer ? 0x4b00 : 0x4d00;
                if (!sipka_fake2(sipx, &g_vec[f], g_vec[f].inf1)) {
                    if (getenv("DBG_RESPAWN"))
                        fprintf(stderr,
                                "[host] RESPAWN funk5 f=%d [%c%c%c%c] -> (%d,%d)\n",
                                f, g_vec[f].c[0], g_vec[f].c[1], g_vec[f].c[2], g_vec[f].c[3],
                                g_vec[f].inf5, g_vec[f].inf6);
                    g_vec[f].x = g_vec[f].inf5;
                    g_vec[f].y = g_vec[f].inf6;
                } else gravitacia(&g_vec[f]);
            }
            break;
        }
        case 15:
        case 18: {  /* fireball / ballistic projectile */
            switch (g_vec[f].inf1) {
            case 1: if (g_vec[f].x < g_vec[f].inf2) g_vec[f].x = cc_addw(g_vec[f].x, g_vec[f].inf3);
                    else movement(f, &g_vec[f], 0); break;
            case 2: if (g_vec[f].x > g_vec[f].inf2) g_vec[f].x = cc_subw(g_vec[f].x, g_vec[f].inf3);
                    else movement(f, &g_vec[f], 0); break;
            case 3: if (g_vec[f].y < g_vec[f].inf2) g_vec[f].y = cc_addw(g_vec[f].y, g_vec[f].inf3);
                    else movement(f, &g_vec[f], 1); break;
            case 4: if (g_vec[f].y > g_vec[f].inf2) g_vec[f].y = cc_subw(g_vec[f].y, g_vec[f].inf3);
                    else movement(f, &g_vec[f], 1); break;
            }
            break;
        }
        default:
            break;
        }
    }

    /* change detection + panak proximity (SI35.PAS `panak` tail). */
    {
        int shut = 0;
        for (f = 1; f <= g_nahrane_veci; f++) {
            if ((g_vec[f].ox != g_vec[f].x) || (g_vec[f].oy != g_vec[f].y))
                g_vec[f].change = 1;
            else
                g_vec[f].change = 0;
            /* an object that moved onto / is adjacent to the panak pauses it */
            if (g_vec[f].mie == g_miestnost && g_vec[f].x > si_x - 24 &&
                g_vec[f].x < si_x + 36 && g_vec[f].y > si_y - 24 &&
                g_vec[f].y < si_y + 36 &&
                (g_vec[f].change || g_vec[f].c[1] == 'A')) {
                /* within interaction range -- the caller pauses the player */
                shut = 1;
            }
        }
        g_shut_down_siriel = shut;
    }
}

/* panak -- SI35.PAS panak core.  The characteristic redraw is done by
 * draw_panak() inside draw_state() (the scene is redrawn each frame); we keep
 * the time_out + anim_count parity here.
 *
 * SI35.PAS panak also drives object movement (Phase 2) and the process_all /
 * process_all2 rendering pass (Phase 1c).  The animation-counter parity:
 *     inc(anim_count);
 *     if (anim_count=4) or (anim_count=2) then begin
 *         inc(bloing); if bloing>=4 then bloing:=0;   {freezing counter, every 2 frames}
 *         if (anim_count=4) then begin anim_count:=0;
 *             inc(anic); if anic>=4 then anic:=0;     {animation frame, every 4 frames}
 *         end;
 *         ... object_movement() (movement + change detect) ...
 *     end;
 */
static void panak(void)
{
    time_out();
    anim_count++;
    if ((anim_count == 4) || (anim_count == 2)) {
        bloing++;
        if (bloing >= 4) bloing = 0;
        if (anim_count == 4) {
            anim_count = 0;
            anic++;
            if (anic >= 4) anic = 0;
        }
        object_movement();
    }
    /* LOAD235.PAS panak -> check_visible(true): recompute each object's
       visibility from the discovery map g_bl every frame, so objects in
       tiles the player has just uncovered appear (and objects in tiles that
       the MAP object re-hidden disappear).  A no-op outside maze modes. */
    check_visible(1);
}

/* --------------------------------------------------------------------- */
/* "HIDDEN IN DARK" MAZE DISCOVERY (LOAD235.PAS export_texture +        */
/* aktivuj_texturu).                                                   */
/*                                                                       */
/* export_texture(nx,ny) -- LOAD235.PAS:2035.  Reveal a single tile: if   */
/* it is not yet discovered and its index is a real tile (< invisible),  */
/* mark it discovered.  The Pascal body also blits the tile (putseg2)    */
/* and temporarily erases/redraws the avatar (vypni/init_charakter);     */
/* both are redundant here because draw_state() redraws the ENTIRE grid  */
/* via print_texture() every frame (gating on g_bl) and redraws the      */
/* avatar via draw_panak(), so writing g_bl is sufficient.             */
/* --------------------------------------------------------------------- */
static void export_texture(int nx, int ny)
{
    if (nx < 0 || nx > MIE_X || ny < 0 || ny > MIE_Y) return;
    if (!g_bl[nx][ny] && st.mie[nx][ny] < g_invisible)
        g_bl[nx][ny] = 1;
}

/* aktivuj_texturu -- LOAD235.PAS:2046.  Maze stav 2/4 only: reveal the    */
/* scan window of not-yet-discovered tiles around the avatar.  With the    */
/* default SCAN window (all zero, e.g. level 1) the window collapses to the */
/* avatar's own 16x16 cell, so exactly one tile is uncovered per step.    */
static void aktivuj_texturu(void)
{
    int a, b, c, d, e, f;
    unsigned char sx1 = g_cfg.scan_x1, sx2 = g_cfg.scan_x2;
    unsigned char sy1 = g_cfg.scan_y1, sy2 = g_cfg.scan_y2;
    if (st.stav != 2 && st.stav != 4) return;
    if (!maze_bl_active) return;                 /* bl = nil  (not a maze) */
    /* a:=(si.x-8) div 16;  b:=(si.y+8) div 16  (guard si.x<8 underflow) */
    a = (si_x >= 8) ? (int)((si_x - 8) / 16) : 0;
    b = (int)((si_y + 8) / 16);
    if ((a - sx1) < 0) a = sx1;
    if ((b - sy1) < 0) b = sy1;
    e = a + sx2;
    f = b + sy2;
    if (e > MIE_X) e = MIE_X;
    if (f > MIE_Y) f = MIE_Y;
    for (c = a - (int)sx1; c <= e; c++) {
        clear_key_buffer();
        for (d = b - (int)sy1; d <= f; d++)
            if (!g_bl[c][d])
                export_texture(c, d);
    }
}

/* padak_init -- GAME.INC: open the parachute sprite above the character
 * (pose cells 36..39 of ar^).  Mirrors padak_init exactly. */
static void padak_init(void)
{
    padak_pose = 36;
    init_charakter(resx, resy, si_x + 2, si_y - 14, 36, 39, ar);
}

/* padak(num) -- GAME.INC: draw the parachute pose cell 36+num above the
 * falling character.  Mirrors padak() exactly. */
static void padak(unsigned short num)
{
    padak_pose = (int)(36 + num);
    karakter((unsigned short)(si_x + 2), (unsigned short)(si_y - 14),
             (unsigned short)(si_oldx + 2), (unsigned short)(si_oldy - 14),
             (unsigned short)(36 + num), 39, ar);
}

/* padak_done -- GAME.INC: erase the parachute + the character, then redraw
 * the character at its resting pose.  Mirrors padak_done exactly. */
static void padak_done(void)
{
    padak_pose = 0;
    vypni_charakter(si_x + px, si_y + py, si_buf, ar);
    vypni_charakter(si_oldx + 2, si_oldy - 14, 39, ar);
    init_charakter(resx, resy, si_x + px, si_y + py, poloha, si_buf, ar);
}

/* padak_check -- GAME.INC: track the fall and open/close the parachute.
 *   * while falling (si.y > si.oldy) count pad_pol; at 19 open the sprite
 *     (padak_init), at 20 draw pose 37 (padak(1)), afterwards pose 38
 *     (padak(2));
 *   * on landing (si.y <= si.oldy) if the parachute had opened (pad_pol>18)
 *     close it (padak_done) and reset the counter.
 * Faithful port of GAME.INC:padak_check. */
static void padak_check(void)
{
    if (si_y > si_oldy) {                 /* falling (y grows downward)   */
        if (pad_pol < 20) {
            int oldpol_pad = pad_pol;
            pad_pol++;
            switch (pad_pol) {
            case 19: padak_init();  break;
            case 20: padak(1);      break;
            }
            if (getenv("ENGINE_DEBUG") && oldpol_pad < 19)
                fprintf(stderr, "[DBG] padak open frame=%d pad_pol=%d\n",
                        (int)step_count, (int)pad_pol);
        } else {
            padak(2);
        }
    } else {                              /* landed / not falling         */
        if (pad_pol > 0) {
            if (pad_pol > 18) {
                if (getenv("ENGINE_DEBUG"))
                    fprintf(stderr, "[DBG] padak close pad_pol=%d\n", (int)pad_pol);
                padak_done();
            }
            pad_pol = 0;
        }
    }
}

/* help_in_game / briefing_in_game -- GAME.INC special-key handlers. */
static void help_in_game(void)
{
    info_ret_set(21);
    help_pending_flag = 1;
}
static void briefing_in_game(void) { /* objective overlay: not wired */ }

/* maze_step -- GAME.INC maze loop (stav 2-5).  Faithful port. */
static void maze_step(void)
{
    unsigned short kdir;
    int keyset;
    if (maze_done_flag) return;
    if (rollup == 0) oldkey = 0;
    k = 0;
    vypis_skore();
    sipka_joystick();
    get_keyboard();
    keyset = keypressed();
    if (keyset) {
        k = ckey();
        clear_key_buffer();
        switch (k) {
        case 0x3b00: case 0x2368: help_in_game(); break;   /* F1   */
        case 0x3e00: case 0x1970: break;                   /* F4   */
        case 0x011b: quit_pending_flag = 1; break;         /* ESC  */
        case 0x1c0d: case 0x3920: inv_pending_flag = 1; break;  /* Enter/Space */
        case 0x3f00: case 0x0762: briefing_in_game(); break;    /* F3   */
        }
    }
    kdir = 0;
    if (zmack(75)) kdir = 0x4b00;   /* LEFT */
    if (zmack(77)) kdir = 0x4d00;   /* RIGHT */
    if (zmack(72)) kdir = 0x4800;   /* UP   */
    if (zmack(80)) kdir = 0x5000;   /* DOWN */
    if (kdir > 0) {
        switch (kdir) {
        case 0x4b00: pl(2); sipka_fake(kdir, &si_x, &si_y); break;
        case 0x4d00: pl(3); sipka_fake(kdir, &si_x, &si_y); break;
        case 0x4800: pl(7); sipka_fake(kdir, &si_x, &si_y); break;
        case 0x5000: pl(1); sipka_fake(kdir, &si_x, &si_y); break;
        }
        if ((!quit_pending_flag) &&
            ((!po3(si_x - movx, si_y - movy)) ||
             (!po3(si_x + mova, si_y - movy)) ||
             (!po3(si_x - movx, si_y))     ||
             (!po3(si_x + mova, si_y))))
            sipka_spat(&si_x, &si_y);   /* blocked -> undo the step */
        aktivuj_texturu();
    }
    panak();
    si_oldx = si_x;
    si_oldy = si_y;
    if (getenv("ENGINE_DEBUG"))
        fprintf(stderr, "[DBG-MS] kdir=%04x si_x=%d si_y=%d -> %d\n", kdir, si_x, si_y, g_the_koniec);
    oldpol  = poloha;
    zisti_vec();
    if (g_the_koniec || g_restart) maze_done_flag = 1;
    if (((int)step_count++ % 25) == 0 && getenv("ENGINE_DEBUG"))
        fprintf(stderr, "[DBG] maze_step stav=%d kdir=%04x si_x=%d si_y=%d poloha=%d movx=%d movy=%d mova=%d klx75=%d klx77=%d klx72=%d klx80=%d\n",
            (int)st.stav, kdir, (int)si_x, (int)si_y, (int)poloha,
            (int)movx, (int)movy, (int)mova, klx[75], klx[77], klx[72], klx[80]);
}

/* arcade_step -- GAME.INC arcade loop (stav 1).  Faithful port, incl. the
 * gravity / jump / edge logic. */
static void arcade_step(void)
{
    unsigned short k2, b, c;
    int old5, old7, truth, keyset;
    if (arc_done_flag) return;
    if (win_now_flag) { accomplished(); win_now_flag = 0; }
    if (rollup == 0) oldkey = 0;
    k = 0;
    vypis_skore();
    sipka_joystick2();
    keyset = keypressed();
    if (keyset) {
        get_keyboard();
        k = ckey();
        k2 = 0;
        switch (k) {
        case 0x3920: case 0x1c0d:
            if (!truth || !rolldown) inv_pending_flag = 1;
            break;
        case 0x3b00: case 0x2368: case 0x2348: help_in_game(); break;
        case 0x3e00: case 0x1970: case 0x1950: break;         /* pauza */
        case 0x011b: quit_pending_flag = 1; break;
        case 0x3f00: case 0x0762: briefing_in_game(); break;
        case 0x4800: case 0x4b00: case 0x4d00: case 0x5000:
        case 0x4700: case 0x4900: case 0x5100: case 0x4f00: k2 = k; break;
        }
        k = 0;
        if (joystick_able) {
            if (k2 > 0) k = k2;
            switch (k) {
            case 0x5000: non_key(); break;
            case 0x4900: if (rollup == 0 && !rolldown) rollup = rolling; k = 0x4d00; break;
            case 0x4700: if (rollup == 0 && !rolldown) rollup = rolling; k = 0x4b00; break;
            case 0x4f00: k = 0x4b00; break;
            case 0x5100: k = 0x4d00; break;
            case 0x4800: if (rollup == 0 && !rolldown) rollup = rolling; k = 0; break;
            }
            k2 = 0;
        }
    }
    old5 = zmack(75);
    old7 = zmack(77);
    get_keyboard();
    if (zmack(75)) { k = 0x4b00; if (old7) key_swap(77, 0); }
    if (zmack(77)) { k = 0x4d00; if (old5) key_swap(75, 0); }
    if (zmack(80) || zmack(28) || zmack(57)) { k = 0x5000; non_key(); }
    if (zmack(60)) k = 0x3c00;
    if (zmack(61)) k = 0x3d00;
    if (k > 0) sipka_fake(k, &si_x, &si_y);
    if (zmack(72) && rollup == 0 && !rolldown) rollup = rolling;
    switch (k) {
    case 0x4b00: if (rollup == 0) pl(2); else oldkey = 5; break;
    case 0x4d00: if (rollup == 0) pl(3); else oldkey = 6; break;
    }
    if (rollup > 0) {
        rollup--;
        if (rollup > gravity) sipka_fake((unsigned short)0x4800, &si_x, &si_y);
        if (smart_jump && (rollup < gravity) && (si_y <= si_oldy)) {
            same++;
            if (same == 1) { rollup = 0; same = 0; }
        }
        if (oldkey < 5) pl(4); else pl(oldkey);
        b = (si_x < 3) ? 1 : (unsigned short)(si_x - 2);
        c = (si_y < 15) ? 3 : (unsigned short)(si_y - 14);
        if ((!po3(b, c)) || (!po3(si_x + 3, c))) rollup = 0;
    } else same = 0;
    truth = po(si_x, si_y);
    if (truth && (rollup < (int)gravity - 5) && !lifting)
        sipka_fake((unsigned short)0x5000, &si_x, &si_y);
    rolldown = po(si_x, si_y);
    if (!rolldown) sipka_fake((unsigned short)0x4800, &si_x, &si_y);
    /* RELEASE THE GLIDE: the instant a side key (LEFT=75 / RIGHT=77) is let go
       the horizontal drift stops (matches the shipped game).  We gate the
       glide on the key *actually being held* rather than on the latched
       `oldkey`, so `oldkey` survives the release.  That keeps the avatar on
       its left/right movement pose `pl(oldkey)` (pl(5)/pl(6)) instead of
       snapping back to the jump up/down pose `pl(4)` -- exactly what the
       Pascal source does, since it never resets `oldkey` on release (only on
       landing, rollup=0, GAME.INC:130/298).  Placed just before the glide so
       the held-key test takes effect this frame. */
    if (rollup > 0 && k == 0 && (zmack(75) || zmack(77))) {
        if (oldkey == 5) sipka_fake((unsigned short)0x4b00, &si_x, &si_y);
        if (oldkey == 6) sipka_fake((unsigned short)0x4d00, &si_x, &si_y);
    }
    if (!po3(si_x - 5, si_y - 12)) sipka_fake((unsigned short)0x4d00, &si_x, &si_y);
    if (!po3(si_x + 6, si_y - 12)) sipka_fake((unsigned short)0x4b00, &si_x, &si_y);
    if (rollup == 0 && (!truth || !rolldown) &&
        (k == 0x4800 || k == 0x4b34 || k == 0x4d36)) rollup = rolling;
    if (rollup == 0) {
        if (k == 0) pom++; else pom = 0;
        if (pom > 3) { pom = 0; pl(1); }
    }
    if (rollup == 1) { pom = 4; key_swap(72, 0); }
    panak();
    padak_check();
    si_oldx = si_x;
    si_oldy = si_y;
    oldpol  = poloha;
    zisti_vec();
    if (g_the_koniec || g_restart) arc_done_flag = 1;
}

/* hra_step -- GAME.INC: dispatch to arcade/maze by st.stav. */
static void hra_step_local(void)
{
    if (((int)step_count++ % 25) == 0 && getenv("ENGINE_DEBUG"))
        fprintf(stderr, "[DBG] hra_step_local step=%d stav=%d si_x=%d si_y=%d oldx=%d oldy=%d poloha=%d movx=%d movy=%d mova=%d arc_done=%d maze_done=%d k=%d klx75=%d klx77=%d klx72=%d klx80=%d\n",
            (int)step_count, (int)st.stav, (int)si_x, (int)si_y,
            (int)si_oldx, (int)si_oldy, (int)poloha,
            (int)movx, (int)movy, (int)mova,
            arc_done_flag, maze_done_flag, k, klx[75], klx[77], klx[72], klx[80]);
    switch (st.stav) {
    case 1: arcade_step(); break;
    case 2: case 3: case 4: case 5: maze_step(); break;
    default: break;
    }
}

/* ===================================================================== */
/* zisti_vec / use_vec / accomplish / go_to_new_stage / strata_zivota     */
/* ===================================================================== */

/* use_vec(mov) -- LOAD235.PAS.  A Y-object (c[0]=='Y') reaches here from
 * zisti_vec.  The danger check runs FIRST, exactly as LOAD235.PAS:1482 does at
 * the end of its (case-free for monsters) use_vec: a dangerous object must NOT
 * be removed, so we strata_zivota() and return before the switch.  In Pascal
 * the `case funk of` has no default, so a monster (funk 2/3/4/5) falls through
 * the untouched case straight to the danger check; porting the check first
 * reproduces that and keeps the monster in the room.  Non-dangerous objects
 * skip the check and run their effect below. */
static void use_vec(unsigned short mov)
{
    unsigned short f;
    if (mov == 0 || mov > g_nahrane_veci) return;

    /* Danger check -- LOAD235.PAS:1482.  A Y-object whose name letter 3
       (c[2]) is 'D', or 'S' while not under a god effect (god_time=0), costs a
       life via strata_zivota.  In shipped levels every dangerous object uses
       'S' (dump_danger.c: 39 'S', 0 'D'); god_time is always 0 here, so all
       'S' objects are dangerous.  We return after strata_zivota so the object
       is NOT marked as picked up -- it stays in the room, exactly as the
       Pascal case-fall-through leaves it. */
    if (((g_vec[mov].c[2] == 'D') ||
         ((g_vec[mov].c[2] == 'S') && (g_god_time == 0))) &&
        !g_the_koniec) {
        fprintf(stderr, "[DBG-USE] mov=%d meno='%s' funk=%d DANGER->strata\n", mov, g_vec[mov].c, g_vec[mov].funk);
        strata_zivota();
        return;
    }
    fprintf(stderr, "[DBG-USE] mov=%d meno='%s' funk=%d ->switch\n", mov, g_vec[mov].c, g_vec[mov].funk);

    switch (g_vec[mov].funk) {
    case 1:  /* TELEPORT */
        si_x  = (unsigned short)(g_vec[mov].inf1 * 8 + 8);
        si_y  = (unsigned short)(g_vec[mov].inf2 * 8 + 8);
        si_oldx = si_x; si_oldy = si_y;
        rewait();
        break;
    case 6:  /* objavenie/zmiznutie textury -- LOAD235.PAS:1350 */
        zhasni_vec_local(&g_vec[mov]);
        g_vec[mov].mie = 2;
        /* set st.mie[f, ff+1] = inf5 for f in [inf1/2, inf3/2],
           ff in [inf2/2, inf4/2].  inf5 is the new texture index (0 =
           empty/background, i.e. a wall/disappearance reveals a passage). */
        {
            int fmin = g_vec[mov].inf1 / 2, fmax = g_vec[mov].inf3 / 2;
            int ffn = g_vec[mov].inf2 / 2, ffmax = g_vec[mov].inf4 / 2;
            unsigned char nv = (unsigned char)g_vec[mov].inf5;
            if (fmin > fmax) { int t=fmin; fmin=fmax; fmax=t; }
            for (int f = fmin; f <= fmax; f++)
                for (int g = ffn; g <= ffmax; g++)
                    if (f >= 0 && f < MIE_X+2 && g+1 >= 0 && g+1 < MIE_Y+1)
                        st.mie[f][g+1] = nv;
        }
        redraw_local(1);
        break;
    case 7:  /* objavenie predmetov -- reveal objects with c[3]==inf1 : LOAD235.PAS:1368 */
        zhasni_vec_local(&g_vec[mov]);
        g_vec[mov].mie = 2;
        {
            char target = (char)g_vec[mov].inf1;
            for (int f = 1; f <= g_nahrane_veci; f++)
                if (g_vec[f].c[3] == target) {
                    g_vec[f].mie = g_miestnost;
                    g_vec[f].visible = 1;
                }
        }
        redraw_local(1);
        break;
    case 8:  /* zmiznu veci -- hide objects with c[3]==inf1 : LOAD235.PAS:1379 */
        zhasni_vec_local(&g_vec[mov]);
        g_vec[mov].mie = 2;
        {
            char target = (char)g_vec[mov].inf1;
            for (int f = 1; f <= g_nahrane_veci; f++)
                if (g_vec[f].c[3] == target)
                    g_vec[f].mie = 2;
        }
        redraw_local(1);
        break;
    case 9:  /* finished */
        accomplished();
        break;
    case 10: /* prida zivot -- add life : LOAD235.PAS:1391 */
        zhasni_vec_local(&g_vec[mov]);
        g_vec[mov].mie = 2;
        zivoty += g_vec[mov].inf1;
        draw_lifes();
        redraw_local(1);
        break;
    case 11:  /* zobrazuje casti bludiska -- MAP reveal/hide of the fog
                  (LOAD235.PAS:1407).  A Y-MAP object (e.g. level 1 f=6
                  [YNNA] funk=11, inf1=3) re-paints which tiles are
                  discovered. */
        if (maze_bl_active) {
            int f;
            zhasni_vec_local(&g_vec[mov]);
            g_vec[mov].mie = 2;
            switch (g_vec[mov].inf1) {
            case 0: /* reveal all -> the maze goes dark again */
                for (f = 0; f <= MIE_X; f++)
                    for (int ff = 0; ff <= MIE_Y; ff++)
                        g_bl[f][ff] = 0;
                break;
            case 1: /* reveal the whole maze */
                for (f = 0; f <= MIE_X; f++)
                    for (int ff = 0; ff <= MIE_Y; ff++)
                        g_bl[f][ff] = 1;
                break;
            case 2: /* hide a rectangular range [inf2..inf4]x[inf3..inf5] */
                for (f = g_vec[mov].inf2; f <= g_vec[mov].inf4; f++)
                    for (int ff = g_vec[mov].inf3; ff <= g_vec[mov].inf5; ff++)
                        if (f >= 0 && f <= MIE_X && ff >= 0 && ff <= MIE_Y)
                            g_bl[f][ff] = 0;
                break;
            case 3: /* reveal a rectangular range [inf2..inf4]x[inf3..inf5] */
                for (f = g_vec[mov].inf2; f <= g_vec[mov].inf4; f++)
                    for (int ff = g_vec[mov].inf3; ff <= g_vec[mov].inf5; ff++)
                        if (f >= 0 && f <= MIE_X && ff >= 0 && ff <= MIE_Y)
                            g_bl[f][ff] = 1;
                break;
            }
            /* Visual-only effects (decrease/increase_palette,
               reload_sound/snd_maze, rewait) are no-ops in the paced
               C-C engine.  Hide every object for this frame; the next
               check_visible() (called from panak) re-reveals the objects
               in the tiles g_bl now exposes, and print_texture() redraws
               the newly discovered tiles. */
            for (f = 1; f <= g_nahrane_veci; f++)
                g_vec[f].visible = 0;
        }
        break;
    case 13:  /* zhasne jednu uroven, rozsvieti druhu -- LOAD235.PAS:1433
                Darken every object whose 5th name char (c[3]) equals inf1
                (hide it), then reveal every object whose c[3] equals inf2
                (drop it into the current room).  Faithful to Pascal:
                vec^[f].meno[4] is the 5th Pascal char == c[3] here. */
        {
            char dh = (char)g_vec[mov].inf1;   /* char(vec^[mov].inf1) */
            char rh = (char)g_vec[mov].inf2;
            for (f = 1; f <= g_nahrane_veci; f++)
                if (g_vec[f].c[3] == dh) g_vec[f].mie = 2;
            for (f = 1; f <= g_nahrane_veci; f++)
                if (g_vec[f].c[3] == rh) g_vec[f].mie = g_miestnost;
        }
        zhasni_vec_local(&g_vec[mov]);
        g_vec[mov].mie = 2;
        redraw_local(1);
        cc_reprint_predmet();
        break;
    case 14:  /* prechod do druhej miestnosti -- LOAD235.PAS:1453
                A funk-14 door transfers the avatar to another room.
                Pascal reads vec^[f].inf1/2/3 (f is the zisti_vec scan
                index == the pointed-at object here == mov); replicate. */
        transfer_to_new_stage(g_vec[mov].inf1, g_vec[mov].inf2,
                              g_vec[mov].inf3, 0);
        break;
    case 19:  /* MRAZAK 1 ; GOD 2 ; MIX 3 -- LOAD235.PAS:1458
                Activate a freezer / god / mix extra effect keyed on inf2,
                mirroring set_freez / set_god (timer += inf1, cap 254). */
        zhasni_vec_local(&g_vec[mov]);
        pust_extra((int)g_vec[mov].z1);
        {
            int fx = g_vec[mov].inf2;
            if (fx == 1) {
                if (g_freez_time + g_vec[mov].inf1 < 255)
                    g_freez_time = (unsigned char)(g_freez_time + g_vec[mov].inf1);
                else g_freez_time = 254;
            } else if (fx == 2) {
                if (g_god_time + g_vec[mov].inf1 < 255)
                    g_god_time = (unsigned char)(g_god_time + g_vec[mov].inf1);
                else g_god_time = 254;
            } else if (fx == 3) {
                if (g_freez_time + g_vec[mov].inf1 < 255)
                    g_freez_time = (unsigned char)(g_freez_time + g_vec[mov].inf1);
                else g_freez_time = 254;
                if (g_god_time + g_vec[mov].inf1 < 255)
                    g_god_time = (unsigned char)(g_god_time + g_vec[mov].inf1);
                else g_god_time = 254;
            }
        }
        g_vec[mov].mie = 2;
        break;
    default:
        zhasni_vec_local(&g_vec[mov]);
        g_vec[mov].mie = 2;
        redraw_local(1);
        break;
    }
}

/* accomplish -- LOAD235.PAS: reveal the '~' exit door and show it.
 *
 * Pascal:
 *   for f:=1 to nahrane_veci do
 *     if vec^[f].meno[4]='~' then begin vec^[f].mie:=1; zobraz_vec(vec^[f]); end;
 *
 * The exit door is loaded in a *different layer* (mie = ord('~') == 126), so it
 * is neither drawn nor detected until the level is won.  accomplish() drops it
 * into the current room (mie:=1).  In the C-C engine the scene is redrawn every
 * frame by cc_print_predmet2(), which filters by (mie==miestnost && visible);
 * mark_vec_visible() only ran at load time (when the door was still in layer 126)
 * and so never set its visible flag.  We must set visible=1 here, exactly as the
 * Pascal zobraz_vec() blit did, so the revealed door is shown AND becomes the
 * pickable/collidable trigger (funk=9 -> accomplished()) the player walks into. */
static void accomplish(void)
{
    int f;
    for (f = 1; f <= g_nahrane_veci; f++)
        if (g_vec[f].c[3] == '~') {
            g_vec[f].mie = 1;
            g_vec[f].visible = 1;
        }
    rewait();
}

/* accomplished -- SI35.PAS / LOAD235.PAS: the level-complete coordinator. */
static void accomplished(void)
{
    acc_init();
}

/* acc_init -- LOAD235.PAS: start the level-complete dialog.  Runs ONCE when a
 * level is won (accomplished()).  It records the completion (the_koniec), arms
 * acc_init_flag so the run-loop switches to state 22, and decides acc_last
 * (this was the last level -- the terminal ending).  The decorated window
 * itself is painted by acc_paint() on entry to state 22: the Pascal original
 * paints inside acc_init, but the C-C engine redraws the scene every frame, so
 * a paint here (during state 21 gameplay) would be overwritten before state 22
 * is entered.  acc_last uses g_old_level, which hra_init() pinned to the
 * Pascal `vybrane` (vybrane := old_level). */
static void acc_init(void)
{
    g_the_koniec = 1;
    acc_init_flag = 1;
    acc_done_flag = 0;
    acc_painted = 0;
    acc_last = (g_levely && g_old_level >= g_levely->pocet) ? 1 : 0;
    acc_pass[0] = '\0';
    if (!acc_last && g_levely && g_level_dat) {
        /* next level: load the next level's block and read st.meno, exactly
           like LOAD235.PAS acc_init (load_predmet2(lev[vybrane+1].subor);
           s:=st.meno; if s[1]='>' then s:=out_string(s); pass:=s).  This is
           the PASSWORD shown in the "Password:" dialog, NOT the level title.
           g_old_level is the Pascal `vybrane` (hra_init pins vybrane:=old_level). */
        const char *sub = g_levely->lev[g_old_level + 1].subor;
        unsigned char buf[MAXLEN_LEVEL + 1];
        char meno[80];
        if (sub && (g_old_level + 1) <= g_levely->pocet &&
            load_level_block(g_level_dat, sub, buf, sizeof(buf)) > 0 &&
            level_field(buf, "MENO", meno, sizeof(meno)) && meno[0] == '>') {
            strncpy(acc_pass, meno, sizeof(acc_pass) - 1);
            acc_pass[sizeof(acc_pass) - 1] = '\0';
            out_string(acc_pass, sizeof(acc_pass));   /* strip the '>' */
        }
    }
}

/* acc_paint -- LOAD235.PAS acc_init painting: the level-complete
 * congratulations / password window.  Called ONCE when state 22 is entered.
 *   last level : old_frame.draw(250,190,7,2) + napis.print(0,200,'WOW !')
 *                                   + napis2.print(0,218,'You`ve done it !')
 *   next level : old_frame.draw(265,190,5,2) + napis.print(0,200,'Password:')
 *                                   + napis2.print(0,218, next level name)
 * Both napis (center+shadow) and napis2 (center, no shadow) centre via
 * real_length; the box is cc_draw_menu_frame (port of old_frame.draw).  The
 * sound / GIF / palette effects in the Pascal original are visual-only and
 * are stubbed to no-ops here. */
static void acc_paint(void)
{
    if (acc_last) {
        /* last level: terminal ending */
        cc_draw_menu_frame(250, 190, 7, 2);
        tprint_draw(TX(g_ja, 4), 0, 200, 15, 2, 2, 0, 1, 1); /* napis: WOW ! */
        tprint_draw(g_tx2[g_ja - 1][0], 0, 218, 15, 2, 2, 0, 1, 0); /* napis2 */
    } else {
        /* next level: show the next level's PASSWORD (st.meno with '>'
           stripped), loaded in acc_init -- mirrors LOAD235.PAS acc_init,
           NOT the level title from the levely^ table. */
        cc_draw_menu_frame(265, 190, 5, 2);
        tprint_draw(TX(g_ja, 3), 0, 200, 15, 2, 2, 0, 1, 1); /* napis: Password: */
        tprint_draw(acc_pass[0] ? acc_pass : "?", 0, 218, 15, 2, 2, 0, 1, 0); /* napis2: password */
    }
}

/* game_over_paint -- LOAD235.PAS strata_zivota: zivoty==0 -> R.I.P. splash.
 *   old_frame.draw(250,190,7,2) + napis.print(0,200,tx[ja,5])
 *                              + napis2.print(0,218,'R. I. P.')
 * Painted ONCE when state 20 is entered, over the frozen gameplay scene
 * (exactly like acc_paint for state 22).  The C-C engine redraws the scene
 * every step, so the splash is NOT painted from strata_zivota() itself (it
 * would be wiped by the next draw_state) -- it is re-drawn here so it
 * persists while the game-over dialog waits for the player. */
static void game_over_paint(void)
{
    cc_draw_menu_frame(250, 190, 7, 2);                       /* old_frame.draw */
    tprint_draw(TX(g_ja, 5), 0, 200, 15, 2, 2, 0, 1, 1);      /* napis: tx[ja,5] */
    tprint_draw("R. I. P.", 0, 218, 15, 2, 2, 0, 1, 0);       /* napis2: R. I. P. */
}

/* game_over_step -- non-blocking Enter/Space/ESC wait for state 20, mirroring
 * acc_step().  Any other key (e.g. an arrow held down when the level was lost)
 * is consumed and discarded. */
static void game_over_step(void)
{
    unsigned short k;
    if (g_game_over_done) return;
    k = g_step_key;
    if (k != 0) {
        g_step_key = 0;                    /* consume this step's key */
        if ((k == 0x1c0d) || (k == 0x3920) || (k == 0x011b))
            g_game_over_done = 1;
    }
}

/* cc_end_state -- decide the run-loop state after a level ends.  A level win
 * (acc_init_flag) goes to the congratulations dialog (state 22); a game over
 * (all lives lost, via strata_zivota OR time_out) shows the R.I.P. splash
 * dialog (state 20) instead of jumping straight to the intro menu. */
static int cc_end_state(void)
{
    return cc_acc_init_flag() ? 22 : 20;
}

/* acc_step -- LOAD235.PAS: non-blocking Enter/Space/ESC wait for state 22.
 * Reads the captured key word (g_step_key -- the C host's one-choice-per-step
 * key, like the menu states via engine_last_key()).  Only Enter / Space / ESC
 * advance the dialog; any other key (e.g. an arrow still held down when the
 * level was finished) is consumed and discarded. */
static void acc_step(void)
{
    unsigned short k;
    if (acc_done_flag) return;
    k = g_step_key;
    if (k != 0) {
        g_step_key = 0;                    /* consume this step's key */
        if ((k == 0x1c0d) || (k == 0x3920) || (k == 0x011b))
            acc_done_flag = 1;
    }
}

/* go_to_new_stage2 / go_to_new_stage / transfer -- LOAD235.PAS.  Set the new
 * position + room.  Map switching (save_map/load_map) is best-effort. */
static void go_to_new_stage2(unsigned short mix, unsigned short x, unsigned short y)
{
    if (x > 8) si_x = x;
    if (y > 8) si_y = y;
    si_oldx = si_x; si_oldy = si_y;
    startx = si_x; starty = si_y;
    save_map(aktual);
    load_map(mix);
    aktual = mix;
    g_miestnost = (mix > 1) ? (unsigned short)(126 + mix) : 1;
}
static void go_to_new_stage(unsigned short mix, unsigned short x, unsigned short y)
{
    fprintf(stderr, "[DBG-GNS] go_to_new_stage mix=%d x=%d y=%d -> miestnost=%d\n", mix, x, y, (mix>1)?126+mix:1);
    save_map(aktual);
    load_map(mix);
    si_x = (unsigned short)(x * 8);
    si_y = (unsigned short)(y * 8 + 4);
    si_oldx = si_x; si_oldy = si_y;
    startx = si_x; starty = si_y;
    aktual = mix;
    g_miestnost = (mix > 1) ? (unsigned short)(126 + mix) : 1;
}
static void transfer_to_new_stage(unsigned short mix, unsigned short x, unsigned short y, int tr)
{
    if (tr) go_to_new_stage2(mix, x, y); else go_to_new_stage(mix, x, y);
}

/* strata_zivota -- LOAD235.PAS:1859.  Lose a life.  Faithful to the Pascal:
 *   1. non_key
 *   2. reset the god / freeze effect timers to their defaults
 *   3. set_old_pos -- snap every in-room 'S' object back to its home cell
 *      (oox/ooy) so the level restarts clean
 *   4a. zivoty == 0 : game over (the_koniec + restart).  The R.I.P. splash
 *       (old_frame.draw + tx[ja,5] + "R. I. P.") is painted by the run-loop
 *       state-20 dialog (cc_end_state -> state 20), so here we only arm the
 *       flags and let the frozen scene persist until the player acks it.
 *   4b. else        : dec(zivoty), respawn the avatar at START, reset rollup,
 *       redraw, restart the pose (play_ball + init_charakter).
 * The palette fade, sounds (unfreeze/ungod/strata) and rewait are visual/audio
 * only and the scene is redrawn every frame, so they are no-ops here. */
static void strata_zivota(void)
{
    unsigned short f;
    fprintf(stderr, "[DBG-SZ] strata_zivota: zivoty=%d si_x=%d si_y=%d\n", zivoty, si_x, si_y);

    non_key();
    /* freez_time := def_freez_time;  god_time := def_god_time; */
    g_freez_time = def_freez_time;
    g_god_time   = def_god_time;
    /* unfreez_sound := 0;  ungod_sound := 0;  (sound is stubbed) */

    /* set_old_pos -- LOAD235.PAS:1547.  Reset every in-room 'S' object to its
       original home cell so monsters return to their start on life loss. */
    for (f = 1; f <= g_nahrane_veci; f++)
        if (g_vec[f].mie == g_miestnost && g_vec[f].c[2] == 'S') {
            g_vec[f].x  = g_vec[f].oox;
            g_vec[f].y  = g_vec[f].ooy;
            g_vec[f].ox = g_vec[f].oox;
            g_vec[f].oy = g_vec[f].ooy;
        }

    if (zivoty == 0) {
        g_the_koniec = 1;
        g_restart = 1;
    } else {
        zivoty--;
        si_x = startx; si_y = starty;
        si_oldx = si_x; si_oldy = si_y;
        rollup = 0;
        /* decrease_palette / increase_palette -- visual-only, redrawn each frame */
        redraw_local(1);
        /* play_ball + init_charakter -- restart the pose (drawn next step) */
        init_charakter(resx, resy, si_x + px, si_y + py, poloha, si_buf, ar);
        /* rewait -- timer-based no-op in the paced C-C engine */
    }
}

/* zisti_vec -- LOAD235.PAS: proximity + Y-pickup + take=3 win + transitions.
 * The pixel-level pickup animation is dropped (draw_state redraws the scene). */
static void zisti_vec(void)
{
    unsigned short f, mov, xx, yy, sco;
    int vecicka, clr, najdene, use_lift;
    px16 = (unsigned short)(px + 12);
    py16 = (unsigned short)(py + 12);
    najdene = 1;
    vecicka = 0;
    clr = 0;
    if (si_y + py > 14) yy = (unsigned short)(si_y + py - 14); else yy = 0;
    if (si_x + px > 14) xx = (unsigned short)(si_x + px - 14); else xx = 0;
    mov = 0;
    for (f = 1; f <= g_nahrane_veci; f++) {
        if (g_vec[f].mie == g_miestnost &&
            (si_x + px16) >= g_vec[f].x &&
            xx <= g_vec[f].x &&
            yy <= g_vec[f].y &&
            (si_y + py16) >= g_vec[f].y) {
            vecicka = 1;
            clr = 1;
            mov = f;
            break;
        } else mov = 0;
    }
    if ((!vecicka) && clr) { clr = 0; mov = 0; }
    /* Expose the pointed-at object to the inventory overlay (SI35.PAS: the
       global `mov` that menu_init() reads when Enter opens the overlay). */
    g_mov = mov;
    /* Y-object -> use_vec  (LOAD235.PAS: only Y-objects reach use_vec) */
    if (mov != 0 && g_vec[mov].c[0] == 'Y') {
        fprintf(stderr, "[DBG-ZV] Y-object found: mov=%d men='%s' funk=%d x=%d y=%d mie=%d\n", mov, g_vec[mov].c, g_vec[mov].funk, g_vec[mov].x, g_vec[mov].y, g_vec[mov].mie);
        use_vec(mov);
    }
    /* take=3 -> score + remove + possibly accomplish */
    if (mov != 0 && g_vec[mov].take == 3 && !g_the_koniec) {
        sco = g_vec[mov].inf1;
        score += (int)sco;
        zhasni_vec_local(&g_vec[mov]);
        g_vec[mov].mie = 2;
        g_vec[mov].visible = 0;
        mov = 0;
        najdene = 1;
        if (!ok) {
            switch (completer) {
            /* LOAD235.PAS: case 0:najdene:=false -- a level with no
               completion requirement is never "all collected". */
            case 0: najdene = 0; break;
            case 1:
                for (f = 1; f <= g_nahrane_veci; f++)
                    if (g_vec[f].c[0] == 'Z' &&
                        g_vec[f].mie != 0 && g_vec[f].mie != 2)
                        najdene = 0;
                break;
            case 2:
                for (f = 1; f <= g_nahrane_veci; f++)
                    if (g_vec[f].c[0] == 'Z' &&
                        g_vec[f].mie != 0 && g_vec[f].mie != 2 &&
                        g_vec[f].c[3] >= 'A' && g_vec[f].c[3] <= 'Z')
                        najdene = 0;
                break;
            }
        }
        if (najdene && !ok) { accomplish(); ok = 1; }
        else pust(1);
    }
    /* priechody (transitions) -- LOAD235.PAS */
    (void)use_lift;
    /* (priechody[] is not tracked in the C-C engine; transitions are a
       follow-up.  The win/pickup path above is the primary level flow.) */
}

/* ===================================================================== */
/* Local helpers shared by the movement port.                            */
/* ===================================================================== */

/* zhasni_vec_local -- LOAD235.PAS: switch a picked-up object off.  The
 * pixel pickup animation is dropped (draw_state redraws the scene every
 * frame), so we only clear the object's visible flag. */
static void zhasni_vec_local(predmet *v) { v->visible = 0; }

/* redraw_local -- visual-only: the whole scene (grid + vec^[]) is redrawn by
 * draw_state() on the next frame, so there is nothing to force here. */
static void redraw_local(int force) { (void)force; }

/* ===================================================================== */
/* Public entry points used by the run-loop state machine (engine.c).    */
/* ===================================================================== */

/* cc_set_start_pos -- LOAD235.PAS START option 3: place the avatar. */
void cc_set_start_pos(unsigned short x, unsigned short y)
{
    si_x = x; si_y = y;
    si_oldx = x; si_oldy = y;
    startx = x; starty = y;
}

/* cc_game_reset -- hra_init(): reset gameplay flags, re-apply START, install
 * sipka_limit bounds + per-stav movx/movy/mova. */
void cc_game_reset(void)
{
    g_the_koniec = 0; g_restart = 0; g_sace = 0;
    arc_done_flag = 0; maze_done_flag = 0;
    acc_init_flag = 0; acc_done_flag = 0; acc_last = 0;
    acc_painted = 0;                        /* state 22: repaint the window next time */
    quit_pending_flag = 0; help_pending_flag = 0; inv_pending_flag = 0;
    anim_count = 0; bloing = 0; anic = 0;   /* anx[] is constant (load_anim_def) */
    rollup = 0; rolldown = 0; same = 0; oldkey = 0; oldpol = 0;
    lifting = 0; use_lift = 0; zivoty = 3; pom = 0; score = 0;
    basic_score = score;                 /* GAME.INC: basic_score:=score */
    /* GAME.INC: sprava:=levely^.lev[old_level].meno -- the objective line is
       the current level name; st.meno (set by load_level_map above) carries
       it, so copy it (stripping a password-protection leading '>'). */
    {
        const char *p = st.meno;
        if (*p == '>') p++;
        strncpy(sprava, p, sizeof(sprava) - 1);
        sprava[sizeof(sprava) - 1] = '\0';
    }
    /* NOTE: `completer` is intentionally NOT reset here.  load_level_map()
       sets it fresh each level (default def_completer=1, then a funk=9 door's
       inf1 via prirad) and runs BEFORE cc_game_reset(); resetting it here would
       clobber the loader's value and make the exit door fire after the first
       collectible instead of after all of them (LOAD235.PAS:606 / :1200). */
    ok = 0; win_now_flag = 0;
    k = 0; g_auto_key_pending = 0;
    poloha = 0;
    pad_pol = 0;                 /* GAME.INC:444 hra_init resets padak_check counter */
    padak_pose = 0;              /* parachute closed */
    /* re-apply the START position */
    si_x = startx; si_y = starty;
    si_oldx = startx; si_oldy = starty;
    /* SI35.PAS:780 sipka_limit(8,9,612,398,4,use_joystick,5,...) */
    sipka_limit(8, 9, 612, 398, 4,
                g_cfg.use_joystick ? 1 : 0, 5, 0, 0, 1, 1);
    gravity = 20; rolling = 30; smart_jump = 0;
    wait_point = 0;
    /* hra_init per-stav movement params (2,3 / 4,5); stav 1 keeps 0 */
    movx = 0; movy = 0; mova = 0;
    switch (st.stav) {
    case 2: case 3: movx = 6; movy = 12; mova = 8; break;
    case 4: case 5: movx = 6; movy = 6;  mova = 0; break;
    }
    /* GAME.INC maze_init (stav 2,3,4,5): allocate + clear the discovery map
       g_bl (the ^bludisko `bl`) and reveal the avatar's starting-cell window.
       maze_bl_active mirrors `bl <> nil` (the branch selector in
       print_texture()/check_visible()/export_texture()).  arc_done/maze_done
       are already reset above.  Non-maze levels (stav 1) leave maze_bl_active
       = 0, so print_texture draws every cell as before. */
    maze_bl_active = (st.stav == 2 || st.stav == 3 || st.stav == 4 ||
                      st.stav == 5) ? 1 : 0;
    for (int f = 0; f <= MIE_X; f++)
        for (int ff = 0; ff <= MIE_Y; ff++)
            g_bl[f][ff] = 0;
    /* GAME.INC hra_init: object-visibility seed.  Arcade / top-view modes
       (stav 1,3,5) show every object unconditionally; maze / dark modes
       (stav 2,4) hide them all here and let check_visible() re-enable each
       object as the fog-of-war reveals the tile it stands on.  This is the
       branch the C-C port was missing, so arcade objects never became
       visible.  Mirrors the Pascal acc_init/hra_init case exactly. */
    for (int f = 1; f <= g_nahrane_veci; f++)
        g_vec[f].visible = (st.stav == 2 || st.stav == 4) ? 0 : 1;
    if (maze_bl_active) aktivuj_texturu();   /* reveal the START cell window */
    /* GAME.INC hra_init:474  play_ani(flik_start);
       Load + queue the level's intro FLI/FLC animation (e.g. AI1 for level 1,
       declared by [FLISTART]=>AI1,ZAI1).  play_ani() sets g_flic_playing=1
       when the block decodes; state 21 shows it (2x upscaled) before gameplay
       and clears it when done or on any key.  Guarded internally by
       g_cfg.fli_abile, which load_config() sets from [ANIMS]=YES. */
    play_ani(g_cfg.flik_start);
}
void cc_hra_step(void)
{
    g_auto_key_pending = g_step_key;   /* feed this step's pending key */
    hra_step_local();
    g_step_key = 0;                    /* the key was consumed */
}

/* cc_hra_final -- GAME.INC hra_final: mark the loop done. */
void cc_hra_final(void)
{
    (void)g_sace;
    hra_playing = 0;
}

/* query helpers for the state machine */
int  cc_arc_done(void)       { return arc_done_flag; }
int  cc_maze_done(void)      { return maze_done_flag; }
int  cc_the_koniec(void)     { return g_the_koniec; }
int  cc_restart(void)        { return g_restart; }
int  cc_acc_init_flag(void)  { return acc_init_flag; }
/* cc_win_now -- TEST HOOK: arm the level-win coordinator (mirrors the
   win_now_flag test path in arcade_step).  A test harness calls this after
   reaching gameplay to force the level-complete dialog (state 22). */
void cc_win_now(void)        { win_now_flag = 1; }
/* TEST HOOK: the password shown in the level-complete "Password:" dialog
   (state 22, next-level branch).  acc_init() computes it in acc_init --
   load the next level's block, read st.meno, strip the leading '>' -- so it
   is the PASSWORD (e.g. 'LIGHT'), not the next level's TITLE. */
const char *cc_acc_pass(void) { return acc_pass; }
int  cc_quit_pending(void)   { return quit_pending_flag; }
int  cc_help_pending(void)   { return help_pending_flag; }
int  cc_inv_pending(void)    { return inv_pending_flag; }

/* --------------------------------------------------------------------- */
/* Inventory-overlay accessors (SI35.PAS es_state=23 / MENU35.INC).       */
/*                                                                       */
/* The inventory menu (game_menu.c: menu_init/menu_step + pouzi_predmet) */
/* drives es_state=23.  It needs read/write access to the engine's own[] */
/* inventory slots, the avatar position + pose, the pointed-at object    */
/* (g_mov), and a few render helpers (zhasni_vec / draw_inventar /      */
/* reprint_predmet) that live in engine.c.  These match the names        */
/* declared in siriel.h so engine.c links with no edits.                */
/* --------------------------------------------------------------------- */
unsigned short cc_last_mov(void)  { return g_mov; }
unsigned char cc_own(int f)       { return (f >= 1 && f <= 3) ? own[f] : 0; }
void cc_set_own(int f, unsigned char v) { if (f >= 1 && f <= 3) own[f] = v; }

/* si.x / si.y -- the avatar tile position (LOAD235.PAS si). */
void cc_get_si(unsigned short *x, unsigned short *y)
{ if (x) *x = si_x; if (y) *y = si_y; }
/* cc_set_si -- LOAD235.PAS SIRXY command (MENU35.INC:35): reposition the
   avatar without moving through intervening cells.  Faithful port:
       val(sc,a,a); mov_part_num(sx,b,por);
       si.x:=a*8+8; si.y:=b*8+8; si.oldx:=si.x; si.oldy:=si.y;
   Note the Pascal SIRXY does NOT touch startx/starty (unlike the START /
   go_to_new_stage paths), so this setter leaves them alone. */
void cc_set_si(unsigned short x, unsigned short y)
{ si_x = x; si_y = y; si_oldx = x; si_oldy = y; }
/* cc_gomap -- LOAD235.PAS GOMAP command (MENU35.INC:37): switch the current
   room WITHOUT moving the avatar.  Faithful port:
       val(sc,a,a); save_map(aktual); load_map(a);
       if a>1 then miestnost:=a+126 else a:=1;
   We also record the new map in `aktual` (mirroring go_to_new_stage) so the
   next save_map() writes the correct slot, and set g_miestnost so
   cc_print_predmet2() blits the NEW room's objects (filtered by mie==miestnost)
   instead of the previous room's.  Without the g_miestnost update the map grid
   reloads but the objects stay from the old room. */
void cc_gomap(unsigned char a)
{
    save_map(aktual);
    load_map(a);
    aktual = a;
    g_miestnost = (a > 1) ? (unsigned short)(a + 126) : 1;
}
/* AKTIV35.PAS px=4 / py=2 -- the avatar's feet offset (used to place a       */
/* picked-up object next to the avatar: vec.x := si.x + px, vec.y := si.y+py).*/
void cc_get_pxpy(int *pout_px, int *pout_py)
{ if (pout_px) *pout_px = (int)px; if (pout_py) *pout_py = (int)py; }
void cc_set_poloha(unsigned char p) { poloha = p; }
unsigned char cc_get_poloha(void)   { return poloha; }

/* zhasni_vec -- switch an object off (hide it from print_predmet2).  The    */
/* scene is redrawn every frame, so this only clears the visible flag; the   */
/* redraw below re-prints the scene.                                         */
void cc_zhasni_vec(predmet *v) { zhasni_vec_local(v); }

/* reprint_predmet -- reprint a single object after its state changed.  In   */
/* the C-C engine the whole scene is redrawn each frame, so this forces a     */
/* fresh print_predmet2 so the change is visible immediately.                */
void cc_reprint_predmet(void) { cc_print_predmet2(); }

/* draw_inventar -- the bottom-HUD inventory bar ("Inventory:" + 3 cells).    */
void cc_draw_inventar(void) { draw_inventar(); }

/* cc_put_obj_sprite(x,y,obr,col) -- blit an object's sprite (putseg2xms
   handles[4],...) from the g_handle4 object table.  Used by the inventory
   overlay to draw a picked-up item at (x,y). */
void cc_put_obj_sprite(unsigned x, unsigned y, unsigned short obr, unsigned char col)
{
    putseg2_ar(x, y, resx, resy, obr, col, g_handle4);
}

/* cc_put_char_cell(x,y,cell,col) -- blit one cell of the character sheet
   (putseg2(...,ar^)).  Cell 45 is the inventory "empty" glyph; cell 44 the
   "Return" glyph the overlay draws under the Return menu item. */
void cc_put_char_cell(unsigned x, unsigned y, unsigned char cell, unsigned char col)
{
    putseg2(x, y, resx, resy, cell, col, cc_ar());
}

/* cc_zisti_vec -- recompute the pointed-at object (g_mov) WITHOUT the
   use_vec / accomplish side effects.  menu_step (MENU35.INC) calls zisti_vec
   after dropping a picked-up item back into the room so the *new* pointed-at
   object is known before deciding whether to zhasni_vec it.  The full
   zisti_vec() has gameplay side effects (Y-pickup, score, take=3 win), so the
   menu only needs the mov-detection half exposed here. */
void cc_zisti_vec(void)
{
    unsigned short f, mov, xx, yy, vecicka, clr;
    px16 = (unsigned short)(px + 12);
    py16 = (unsigned short)(py + 12);
    vecicka = 0;   /* najdene is local to the full hra_step_local(); the menu only
                       needs the mov-detection half below, so it is not tracked. */
    clr = 0;
    if (si_y + py > 14) yy = (unsigned short)(si_y + py - 14); else yy = 0;
    if (si_x + px > 14) xx = (unsigned short)(si_x + px - 14); else xx = 0;
    mov = 0;
    for (f = 1; f <= g_nahrane_veci; f++) {
        if (g_vec[f].mie == g_miestnost &&
            (si_x + px16) >= g_vec[f].x &&
            xx <= g_vec[f].x &&
            yy <= g_vec[f].y &&
            (si_y + py16) >= g_vec[f].y) {
            vecicka = 1;
            clr = 1;
            mov = f;
            break;
        } else mov = 0;
    }
    if ((!vecicka) && clr) { clr = 0; mov = 0; }
    g_mov = mov;
}

/* cc_use_vec -- run the real "use object" effect (LOAD235.PAS use_vec) for the
   pointed-at object.  menu_init (MENU35.INC) calls this in its DIRECT-USE path:
   when the object the avatar points at has a name whose first letter is not
   'W' (not an inventory/carryable item) and not 'V' (a [TEXT]-dialog item),
   the Pascal menu_init() runs use_vec(mov) IMMEDIATELY — no overlay — to apply
   the object's effect (a teleport funk=1 moves the avatar, funk 6/7/8 reveal /
   hide textures/objects, funk 9 finishes the level, funk 10 adds a life, …).
   The internal use_vec() carries the danger check + the case-funk switch.
   Exposed here (like cc_zisti_vec) because it lives in engine.c but is called
   from game_menu.c's menu_init(). */
void cc_use_vec(unsigned short mov)
{
    use_vec(mov);
}

/* draw_panak -- redraw the panak avatar over the current scene.
 * Called at the end of draw_state(21) after fb_vfill/print_texture/
 * cc_print_predmet2 have redrawn the level scene.  Mirrors GAME.INC panak ->
 * charakter(si.x+px,si.y+py,poloha,si.buf,ar^): the pose cell ar[poloha] is
 * the figure with a transparent background (colour 13), so putseg2() overlays
 * it on the freshly rendered scene -- transparent pixels let the scene show
 * through.  Because the scene is redrawn every frame, the avatar follows
 * si.x/si.y exactly as the movement loop updates them (no stale background). */
static void draw_panak(void)
{
    if (((int)step_count % 25) == 0 && getenv("ENGINE_DEBUG"))
        fprintf(stderr, "[DBG] draw_panak si_x=%d si_y=%d -> blit(%d,%d) poloha=%d\n",
            (int)si_x, (int)si_y, (int)(si_x + px), (int)(si_y + py), (int)poloha);
    putseg2(si_x + px, si_y + py, resx, resy, poloha, 13, cc_ar());
}

/* draw_padak -- redraw the parachute in draw_state(21), AFTER draw_panak.
 *
 * Why this is needed: the C-C draw_state does `fb_vfill(0)` every frame, which
 * wipes the parachute blit that padak_check() made during movement (the C-C
 * draw_state stand-in redraws the whole scene each frame, unlike the Pascal
 * vid_present which just copies the framebuffer).  draw_panak() only redraws
 * the character, so without this the parachute would never be visible while
 * falling.
 *
 * padak_check() records the exact pose cell it blitted into padak_pose
 * (36 = padak_init, 37 = padak(1), 38 = padak(2), 0 = closed), so we reproduce
 * it here faithfully.  Using the recorded pose -- rather than re-deriving it
 * from pad_pol -- matters because pad_pol caps at 20: in Pascal the frame where
 * pad_pol increments to 20 draws pose 37, but every subsequent frame (pad_pol
 * still 20, the else branch) draws pose 38.  A plain pad_pol test cannot tell
 * those apart, so pose 38 (the sustained 'open' pose) would be wrong.  The
 * parachute sits just above the character at (si.x+2, si.y-14) with transparent
 * colour 13, drawn last so it stays on top. */
static void draw_padak(void)
{
    if (padak_pose >= 36) {
        putseg2((unsigned short)(si_x + 2), (unsigned short)(si_y - 14),
                resx, resy, (unsigned short)padak_pose, 13, ar);
    }
}

/* --------------------------------------------------------------------- */
/* draw_state -- render the current level scene for every engine state.  */
/*                                                                     */
/* The old port had a placeholder stand-in for the unported JxGRAF      */
/* per-state rendering: a full-screen bg fill (the green "area"), a     */
/* border, a state-label banner, a sliding "GEN" cursor rectangle and   */
/* numeric readouts. That chrome is removed -- the real game shows the  */
/* level scene for gameplay (state 21, via hra_step + vid_present),     */
/* for the level-complete screen (state 22, the unported acc_step      */
/* stand-in) and behind the inventory overlay (state 23); the boot      */
/* frame (state 0) falls through to the same level scene. print_texture */
/* (LOAD235.PAS print_texture) blits the st.mie grid and cc_print_      */
/* predmet2 (LOAD235.PAS print_predmet2) blits the room objects.       */
/* --------------------------------------------------------------------- */
static void draw_state(int st, unsigned gen)
{
    (void)gen;

    fb_vfill(0);
    /* LOAD235.PAS redraw() paints the bottom-HUD decorative frame
       (stvorec2) + the two scratch "lajna" help lines FIRST, before the
       playfield + bar content.  The frame is the 10px-thick border around
       the bottom bar (y = 416..478, full width). */
    /* The inventory overlay (es_state=23) is painted ON TOP of the frozen
       gameplay scene, so state 23 draws the SAME full frame state 21 does
       (HUD frame + help lines) -- the overlay then layers above it. */
    if (st == 21 || st == 23) {
        cc_stvorec2(0, 416, 639, 62, 20, 0, 10);
        {
            int f;
            for (f = 0; f <= 250; f++) lajna[f] = 1;
            help_line1();
            for (f = 0; f <= 250; f++) lajna[f] = 197;
            help_line2();
        }
    }
    print_texture();
    cc_print_predmet2();
    /* The panak avatar is blitted on top of the freshly rendered scene
     * (state 21 gameplay only).  fb_vfill/print_texture/cc_print_predmet2
     * redraw the whole scene, so the avatar is drawn last.  si.x/si.y were
     * placed at the level's START tile by cc_game_reset(); the movement loop
     * (cc_hra_step) updates them each frame and draw_panak() overlays the
     * current pose over the current scene. */
    if (st == 21 || st == 23) {
        draw_panak();
        /* Parachute overlay: redraws the padak sprite that padak_check()
         * blitted during cc_hra_step().  fb_vfill() (see above) wipes the
         * whole framebuffer every frame, so the parachute blit made during
         * movement is lost unless we redraw it here — mirroring the Pascal
         * panak->padak_check render order.  Drawn after draw_panak so it
         * stays on top. */
        draw_padak();
        /* The bottom HUD bar (score / lives / inventory) is painted last,
           exactly as LOAD235.PAS redraw() does, so it sits on top of the
           freshly rendered scene + avatar. */
        draw_hud();
    }
    fb_expand();
}

/* --------------------------------------------------------------------- */
/* SOUND STUBS -- per migration strategy, sound is redirected to no-ops. */
/* The real SMIX.PAS mixer is NOT ported here; these satisfy the calls   */
/* the run loop would otherwise make.                                    */
/* --------------------------------------------------------------------- */
static void pust(int snd)   { (void)snd; }      /* play a sfx          */
static void reload_sound(int f, const char *p, int s)
{ (void)f; (void)p; (void)s; }                 /* reload sfx from DAT */
static void Initsbx(void)  {}                   /* sound init          */
static void LoadSounds(void) {}
static void stop_all_sounds(void) {}

/* --------------------------------------------------------------------- */
/* Run-loop state (mirrors SI35.PAS `es_state` / `es_selector`).         */
/* --------------------------------------------------------------------- */
static int  es_state    = 0;
static int  es_selector = 0;
static unsigned gen     = 0;      /* double-buffer generation index        */
static unsigned short pending_key = 0;
static int  clock_val   = 0;

/* play-through progress (skeleton, not the real game) */
static int step_in_state = 0;
static int done_levels   = 0;

/* --------------------------------------------------------------------- */
/* Inventory / pause overlay state (MENU35.INC + SI35.PAS es_state=23).   */
/*                                                                       */
/* These are the SAME globals the menu routines in game_menu.c drive     */
/* (menu_init/menu_step + pouzi_predmet_init/pouzi_predmet_step), so the */
/* engine.c state-23 driver and game_menu.c share them exactly like the  */
/* Pascal units share their var section.  Declared non-static here and   */
/* `extern` in siriel.h.                                                 */
/* --------------------------------------------------------------------- */
/* inventory overlay (menu_init/menu_step) */
unsigned char inv_init   = 0;   /* menu_init() has painted the overlay     */
unsigned char inv_done   = 0;   /* a selection was committed (Enter/ESC)   */
unsigned char inv_direct_done = 0;  /* a direct-use object was applied */
unsigned char inv_result = 0;   /* committed menu index (1..3) or 0 (ESC)  */
unsigned short inv_f     = 1;   /* current menu highlight                  */
unsigned short menu_x    = 4;   /* menu_x := 4 (Pascal)                    */
unsigned char inv_status = 0;   /* status (Pascal overlay flag)            */
unsigned char inv_zobral = 0;   /* zobral (picked this entry up)           */

/* item-activation [TEXT] dialog (pouzi_predmet_init/pouzi_predmet_step) */
unsigned char pp_started   = 0;   /* pouzi_predmet_init() has run        */
unsigned char pp_done      = 0;   /* command loop finished               */
unsigned char pp_pending   = 0;   /* a dialog is queued                  */
unsigned short pp_num      = 0;   /* item/num index passed to init       */
unsigned short pp_z        = 0;   /* originating item index              */
unsigned char pp_return    = 1;   /* return value for the caller         */
unsigned char pp_wait_mode = 0;   /* 0=running, 1=waiting key, 2=pulses  */
unsigned short pp_wait_left = 0;  /* remaining pulses (mode 2)           */
unsigned char pp_wait_cmd  = 0;   /* blocking command that triggered wait*/
unsigned char pp_jump      = 0;   /* conditional jump requested          */
unsigned char pp_breaker   = 0;   /* END command seen                  */
unsigned char pp_close     = 0;   /* text finished; waiting to close   */
unsigned char pp_xx        = 0;   /* current text-buffer index         */
unsigned short pp_count    = 0;   /* position within the current line  */
char pp_s[128];                   /* current text-buffer line          */
static int menu_visits   = 0;

/* boot_done: has load_basic_config() (the disk scan + level load) run once?
 * Mirrors SI35.PAS `sd_boot`: the Pascal runs do_fatal_restart / load_basic_config
 * exactly ONCE on first entry to state 0, then drives the datadisk selector. */
static int  boot_done   = 0;

/* level_loaded_for: the g_old_level index last handed to load_level_map().
 * Mirrors hra_init() -> load_predmet2, which runs once per level start.  The
 * C-C engine loads on entry to state 21 (the Pascal level runs it on entry to
 * state 30); reload only when the selected level changes. */
static unsigned char level_loaded_for = 0;

/* cc_dbg_reload_level -- TEST HOOK: force state-21 to reload g_old_level's
   data on the next step (resets the level_loaded_for guard).  The test sets
   g_old_level (extern) then calls this. */
void cc_dbg_reload_level(void) { level_loaded_for = 0; }
/* cc_dbg_set_state -- TEST HOOK: force the run-loop es_state so a test
   harness can jump straight to a given phase (e.g. 21 = gameplay). */
void cc_dbg_set_state(int s) { es_state = (unsigned char)s; }
/* cc_dbg_shut -- TEST HOOK: return the panak interaction flag. */
int cc_dbg_shut(void) { return g_shut_down_siriel; }
/* cc_dbg_anic -- TEST HOOK: return the panak animation frame counter.  It
   advances every 4 engine frames and is added to anx[obr] so animated
   objects address their four cells (cc_print_predmet2). */
int cc_dbg_anic(void) { return anic; }

/* --- TEST HOOKS: arcade_step movement state (roll / rolling-stop debug) --- */
int  cc_dbg_rollup(void)      { return rollup; }
int  cc_dbg_oldkey(void)      { return oldkey; }
int  cc_dbg_poloha(void)      { return (int)poloha; }
int  cc_dbg_k(void)           { return (int)k; }
int  cc_dbg_rolldown(void)    { return rolldown; }

/* cc_dbg_pad_pol -- TEST HOOK: the padak_check fall counter.  >18 means the
   parachute has opened (pose 37/38 is drawn); <=18 means it is closed. */
int  cc_dbg_pad_pol(void)       { return (int)pad_pol; }

/* cc_dbg_fb_get -- TEST HOOK: read one 8-bit back-buffer pixel (0..255). */
unsigned char cc_dbg_fb_get(int x, int y)
{
    if (x < 0 || y < 0 || x >= FBW || y >= FBH) return 255;
    return video_buffer[y * FBW + x];
}

/* --- TEST HOOKS: read the static game-state vars strata_zivota / zisti_vec --- */
int  cc_dbg_zivoty(void)        { return zivoty; }
void cc_dbg_set_zivoty(int v)   { zivoty = v; }
int  cc_dbg_score(void)         { return score; }

/* --- TEST HOOKS: level countdown timer (SI35.PAS time_out) --- */
unsigned short cc_dbg_timer(void)         { return g_cfg.timer; }
/* TEST HOOK: force the level countdown timer (lets a test drive the timer
   game-over path without waiting for the DAT value to drain). */
void cc_dbg_set_timer(int v)              { g_cfg.timer = (unsigned short)v; }
/* number of times time_out() was entered (== panak() calls while playing) */
int cc_dbg_time_out_calls(void)           { return g_time_out_calls; }
/* how many times time_out() actually drained the timer by one */
int  cc_dbg_time_out_drained(void)        { return g_time_out_drained; }
/* how many times draw_timer() (HUD label) was invoked */
int  cc_dbg_draw_timer_calls(void)        { return (int)g_draw_timer_calls; }
/* TEST HOOK: font metrics + fontik[] checksum (0 = font NOT loaded) */
void cc_dbg_font_info(int *w, int *h, long *crc)
{
    int i; long c = 0;
    if (w) *w = CharDX;
    if (h) *h = CharDY;
    for (i = 1; i < 4097; i++) c += (long)i * (long)fontik[i];
    *crc = c;
}
unsigned short cc_dbg_si_x(void)      { return si_x; }
unsigned short cc_dbg_si_y(void)      { return si_y; }
unsigned short cc_dbg_startx(void)    { return startx; }
unsigned short cc_dbg_starty(void)    { return starty; }
unsigned char cc_dbg_god_time(void)   { return g_god_time; }
unsigned char cc_dbg_freez_time(void) { return g_freez_time; }
int  cc_dbg_the_koniec(void)    { return g_the_koniec; }

/* --- TEST HOOKS: "hidden in dark" discovery map g_bl (AKTIV35.PAS ^bludisko) */
int      cc_dbg_bl_active(void)   { return maze_bl_active; }
/* number of tiles currently discovered/revealed (0 = fully dark) */
int      cc_dbg_bl_count(void)
{
    int c = 0;
    for (int f = 0; f <= MIE_X; f++)
        for (int ff = 0; ff <= MIE_Y; ff++)
            if (g_bl[f][ff]) c++;
    return c;
}
unsigned char cc_dbg_bl_get(int f, int ff) {
    if (f < 0 || f > MIE_X || ff < 0 || ff > MIE_Y) return 0;
    return g_bl[f][ff];
}

/* cc_dbg_place_player -- TEST HOOK: place the avatar at (x,y) WITHOUT moving
   the recorded START, so a following step can test adjacency (danger / pickup)
   at an arbitrary cell.  (cc_set_start_pos would also reset startx/starty.) */
void cc_dbg_place_player(unsigned short x, unsigned short y)
{
    si_x = x; si_y = y;
}

/* Standalone-run flag. The REAL Pascal engine's menu states are input-driven
 * (choice_step / select_level_step / briefing_step block until a real key is
 * committed), so after reaching the intro menu the engine WAITS for the window
 * to connect and drive it. The C-C skeleton, by contrast, was auto-advancing
 * every state on a step timer, so with no keys it burned straight to
 * state=9 (done) and never sat in the menu.
 *
 * To make the C-C engine behave like the real one, the menu states below wait
 * for a real key by default. Set SIRIEL_AUTO_RUN=1 to re-enable the timer-based
 * auto-advance so the whole 0->...->9 run can be exercised headless (no window,
 * no keys) -- this is the standalone-verification mode only. */
static int g_auto_run = 0;

/* --------------------------------------------------------------------- */
/* Engine interface -- exported under the EXACT FPC-mangled names so      */
/* host_engine.c links with NO changes.                                 */
/* --------------------------------------------------------------------- */
void engine_init(void) __asm__(FPC_SYM_PREFIX "P$SIRIEL3_$$_ENGINE_INIT");
void engine_step(void) __asm__(FPC_SYM_PREFIX "P$SIRIEL3_$$_ENGINE_STEP");
void engine_shutdown(void) __asm__(FPC_SYM_PREFIX "P$SIRIEL3_$$_ENGINE_SHUTDOWN");
void engine_press_key(unsigned short k) __asm__(FPC_SYM_PREFIX "P$SIRIEL3_$$_ENGINE_PRESS_KEY$WORD");
void engine_set_clock(int c) __asm__(FPC_SYM_PREFIX "P$SIRIEL3_$$_ENGINE_SET_CLOCK$LONGINT");
unsigned char *engine_buffer(void) __asm__(FPC_SYM_PREFIX "P$SIRIEL3_$$_ENGINE_BUFFER$$POINTER");
int engine_generation(void) __asm__(FPC_SYM_PREFIX "P$SIRIEL3_$$_ENGINE_GENERATION$$LONGINT");
int engine_state(void) __asm__(FPC_SYM_PREFIX "P$SIRIEL3_$$_ENGINE_STATE$$LONGINT");

void engine_init(void)
{
    /* Mirror the Pascal init's observable effect for the C host: set up the
       framebuffer, palette, and put the run loop at boot (state 0). Sound
       init is stubbed. The palette is the REAL one from MAIN.DAT (Phase A). */
    /* new(levely) -- allocate the levely^ table BEFORE load_basic_config
       (do_fatal_restart / state 0 writes into it). Mirrors SI35.PAS
       engine_init's `new(levely)`. */
    if (!g_levely) g_levely = calloc(1, sizeof(t_levels));
    load_real_palette();
    /* Read the external SIRIEL3.CFG setup file and feed each line to setup()
       (SI35.PAS / PREMEN35.INC load_config).  This is the ONLY place the
       game honours [ANIMS]=YES / [LANGUAGE] / [ZVUK] / [JOYSTICK] /
       [CRCCHECK] -- the DAT CONFIG block carries none of those keywords.
       In particular it sets g_cfg.fli_abile from [ANIMS]=YES, which play_ani()
       (engine.c) guards on before it can show a level's [FLISTART] intro
       (e.g. AI1 in level 1).  The DAT CONFIG / per-level blocks are read
       afterwards, in engine_step() state 0 (load_basic_config). */
    load_config();
    /* SI35.PAS:936  set_font(def_font);  def_font='FMOD' (8x16) */
    set_font("FMOD");
    /* Load the character sprite sheet (GZAL from MAIN.DAT) into ar^ --
       mirrors SI35.PAS load_pohyby, called early in do_fatal_restart.  Does
       not depend on g_level_dat, so it is safe here (before state 0). */
    cc_load_pohyby();
    /* Load the menu-box frame (GLIST from MAIN.DAT) into g_frame --
       mirrors SI35.PAS:930 old_frame.init(no_handle, input_file,
       frame_gif, false).  Carves the 8 border tiles; drawn later by
       select_level_init via cc_draw_menu_frame(). */
    cc_load_frame();
    fb_vfill(0);
    fb_expand();
    es_state     = 0;
    es_selector  = 0;
    gen          = 0;
    step_in_state= 0;
    done_levels  = 0;
    menu_visits  = 0;
    pending_key  = 0;
    /* Standalone-run mode? See g_auto_run above. Default is to WAIT for the
     * window (input-driven menu, like the real engine); SIRIEL_AUTO_RUN=1
     * re-enables timer auto-advance for headless end-to-end verification. */
    {
        const char *ar = getenv("SIRIEL_AUTO_RUN");
        g_auto_run = (ar && atoi(ar) > 0) ? 1 : 0;
    }
    /* LoadSounds / Initsbx stubbed -> sound redirected to C no-ops. */
    LoadSounds();
    Initsbx();
}

void engine_press_key(unsigned short k)
{
    pending_key = k;      /* C owns the keyboard; store the pending DOS key word */
}

/* g_step_key: the DOS key word captured at the TOP of the current engine_step.
 * The host feeds at most one key per step (press_key) and then stops, so we must
 * clear pending_key each step to avoid a stale key persisting. The menu routines
 * read the captured key via engine_last_key() (mirrors GAME.INC's kkey2 read
 * inside choice_step / select_level_step / quit_confirm_step / ...), which is
 * why the captured value lives in g_step_key rather than being discarded. */
static unsigned short g_step_key = 0;

/* Return the DOS key word captured for the current engine_step (non-consuming).
 * A menu routine reads it exactly once per tick, just like GAME.INC's kkey2. */
unsigned short engine_last_key(void)
{
    return g_step_key;
}

/* TEST HOOK: inject a key word into g_step_key so the step-able
   pouzi_predmet [TEXT] dialog (driven directly by the pp_probe harness,
   which calls pouzi_predmet_step() rather than engine_step()) sees a key
   arrive -- needed to advance past a KEY/REINIT/NEWSCR/PULZX wait. */
void cc_pp_set_key(unsigned short k) { g_step_key = k; }


void engine_set_clock(int c)
{
    clock_val = c;        /* C owns the virtual clock */
}

unsigned char *engine_buffer(void)
{
    return frame_rgb;     /* @FrameRGB[0] */
}

int engine_generation(void)
{
    return (int)gen;
}

int engine_state(void)
{
    return es_state;
}

void engine_shutdown(void)
{
    fb_vfill(0);
    fb_expand();
}

/* --------------------------------------------------------------------- */
/* engine_step: the run-loop state machine. Mirrors SI35.PAS structure.   */
/* A pending key is treated as a committed menu choice (non-blocking),    */
/* matching the one-choice-per-step design.                             */
/* --------------------------------------------------------------------- */
void engine_step(void)
{
    /* Capture this step's key from the host, then clear pending_key so a key
     * does not persist to the next step when the host stops feeding. The menu
     * routines read the captured value via engine_last_key() (mirrors GAME.INC's
     * kkey2 read) -- clearing pending_key here but keeping the value in
     * g_step_key is what lets the menu actually see the key. */
    unsigned short step_key = pending_key;
    pending_key = 0;
    g_step_key = step_key;
    int have_key = (step_key != 0);

    switch (es_state) {
    case 0:  /* boot: run heavy setup once (load_basic_config scans the DAT
               disks and populates levely^), then go to the intro menu.
               Mirrors SI35.PAS state 0: do_fatal_restart runs ONCE (sd_boot). */
        if (!boot_done) {
            load_basic_config();           /* sets g_level_dat (SIRIEL35.DAT) */
            /* Load the animation sprite sheet (GANIM from g_level_dat) into
               anim^ -- mirrors SI35.PAS do_fatal_restart's "nahra animovane
               obrazky" block.  Runs ONCE, right after load_basic_config so
               g_level_dat is valid. */
            cc_load_anim();
            /* load_anim_def: populate the per-object anim-cell base
               (anx[fm]:=fm*4, LOAD235.PAS) so animated objects can address
               their 4 frames as anic + anx[obr].  Mirrors SI35.PAS
               do_fatal_restart, which calls load_anim_def right after
               loading the anim sheet. */
            load_anim_def();
            boot_done = 1;
        }
        draw_state(0, gen);
        gen++;
        es_state = 10;
        step_in_state = 0;
        break;

    case 10: /* intro-menu entry: paint the REAL menu (show_intro_page) and
               start navigation (choice_init). Faithful port of GAME.INC. */
        show_intro_page();
        choice_init();
        gen++;
        es_state = 11;
        step_in_state = 0;
        break;

    case 11: /* intro-menu tick: one choice step per step. Faithful port of
               GAME.INC choice_step, with SI35.PAS routing on the chosen item. */
        /* auto-run: after the menu idles, commit the current item. On the
           first visit commit Enter (plays a level pair); once a full cycle
           has been played (done_levels >= 2) commit the Quit hotkey (Q) so
           the demo burns through to done (state 9). */
        if (g_auto_run && !menu_ch_done() && step_in_state >= 3)
            g_step_key = (done_levels >= 2) ? 0x1071 : 0x1c0d;
        choice_step();
        gen++;
        if (menu_ch_done()) {
            int sel = choice_result();
            unsigned short sel_key = menu_item_key(sel);
            if (sel == 0 || sel_key == 0x1071) {
                es_selector = 0; es_state = 9;          /* ESC / Quit */
            } else if (sel_key == 0x2064 && g_num_disks > 1) {
                es_state = 0;                          /* DATADISK -> boot */
            } else {
                switch (sel_key) {
                    case 0x2267: es_selector = 1; es_state = 12; break;  /* Game */
                    case 0x1769: es_selector = 2; info_ret_set(10); es_state = 40; break;  /* Info -> menu */
                    case 0x2368: es_selector = 3; es_state = 41; break;  /* Hi-scores */
                    default:       es_selector = (unsigned char)sel; es_state = 12; break;
                }
            }
            /* choice_step() no-ops while ch_done is set, so the committed
               flag self-clears on the next tick once state 10 re-runs
               choice_init().  pending_key is cleared so the committed Enter
               is consumed exactly once. */
            pending_key = 0;
            step_in_state = 0;
        }
        break;

    case 12: /* level selector -- faithful port of SI35.PAS state 12.
               select_level_init() paints the level list once;
               select_level_step() advances the cursor one key per step.
               On commit: a password-protected level -> state 24, else
               briefing -> state 30; Back/ESC -> intro menu state 10. */
        /* Fresh level selection: the FLI intro (play_ani, run by cc_game_reset()
           in the state-21 load block) must replay on EVERY fresh start, exactly
           as Pascal's hra_init() does when a level is chosen here.  The load
           guard below only reloads when g_old_level CHANGES, so re-selecting the
           SAME level (e.g. level 1 after dying and returning to the selector)
           would otherwise skip cc_game_reset() and the intro never replays.
           Clearing the guard here forces the state-21 load block to reload the
           level and replay its intro on the next fresh selection.  The "continue"
           path (state 13 No -> 21) and the overlay paths (40/41/23 -> 21) never
           pass through state 12, so level_loaded_for is left intact there. */
        level_loaded_for = 0;
        /* TEMP TEST: auto-select level 2 (DOWN on fresh selector, ENTER to
           commit).  Use the init-once flag rather than a static counter:
           select_level_init() resets the cursor to level 1 every time a fresh
           selector starts (sl_init is cleared by select_level_reset()), so a
           static `down_done` would commit ENTER at level 1 on the SECOND
           visit.  Reading the flag BEFORE init() runs gives us: fresh ->
           DOWN (cursor 1->2), then committed visit -> ENTER. */
        if (g_auto_run && !select_level_done()) {
            if (!select_level_init_done()) g_step_key = 0x5000;  /* DOWN -> level 2 */
            else            g_step_key = 0x1c0d;   /* commit */
        }
        if (!select_level_init_done()) select_level_init();
        select_level_step();
        if (select_level_done()) {
            int r = select_level_result();
            if (r > 0) {
                char pw[64];
                /* Phase 10: detect a password-protected level before starting.
                   level_needs_password() reads the level's [MENO] and, if the
                   '>' marker is present, fills pw with the password. */
                if (level_needs_password((unsigned char)r, pw, sizeof(pw))) {
                    password_reset();          /* pw_init := false */
                    es_state = 24;
                } else {
                    briefing_reset();          /* briefing_started := false */
                    es_state = 30;
                }
            } else {
                es_state = 10;                 /* Back / ESC -> intro menu */
            }
            select_level_reset();
        }
        step_in_state = 0;
        break;

    case 24: /* password prompt -- faithful port of SI35.PAS state 24.
               password_init() paints the prompt/field once;
               password_step() reads one key per step. Correct -> briefing
               (state 30); wrong/ESC -> fresh level selector (state 12). */
        if (g_auto_run && !password_done() && step_in_state >= 1)
            g_step_key = 0x1c0d;         /* auto-submit (wrong) -> back to selector */
        if (!password_init_done()) password_init();
        password_step();
        if (password_done()) {
            /* Capture pw_ok BEFORE password_reset(): Pascal resets only
               pw_init := false before the pw_ok check (SI35.PAS state 24),
               so pw_ok stays valid across the branch.  password_reset()
               zeroes pw_ok too, so capturing first is what makes the
               correct-password path reach state 30 (gameplay). */
            unsigned char pw_ok_now = password_ok();
            password_reset();
            if (pw_ok_now) {
                briefing_reset();          /* briefing_started := false */
                es_state = 30;
            } else {
                select_level_reset();      /* sl_init := false -> fresh selector */
                es_state = 12;
            }
        }
        step_in_state = 0;
        break;

    case 30: /* objective dialog -- faithful port of SI35.PAS state 30.
               briefing_init() paints the objective text once;
               briefing_step() waits for Enter/Space/ESC.  Dismissed ->
               gameplay (state 21).  Levels with no objective text skip. */
        if (g_auto_run && !briefing_finished() && step_in_state >= 1)
            g_step_key = 0x1c0d;         /* auto-dismiss the objective */
        if (!briefing_init_done()) briefing_init();
        briefing_step();
        if (briefing_finished()) {
            briefing_reset();
            es_state = 21;                 /* -> gameplay */
        }
        step_in_state = 0;
        break;

    case 40: /* info / help -- faithful port of SI35.PAS state 40.
               info_init() draws the credits + scrolling help;
               info_step() advances one frame per step.  On dismiss return to
               info_ret (10 = main menu, 21 = gameplay). */
        if (g_auto_run && !info_finished() && step_in_state >= 2)
            g_step_key = 0x1c0d;         /* auto-dismiss */
        if (!info_init_done()) info_init();
        info_step();
        if (info_finished()) {
            info_reset();
            es_state = info_ret_get();
        }
        step_in_state = 0;
        break;

    case 41: /* hi-scores -- faithful port of SI35.PAS state 41.
               show_hi_score_init() paints the table once;
               show_hi_score_step() waits for Enter/Space/ESC, then returns to
               the intro menu (state 10). */
        if (g_auto_run && !show_hi_score_done() && step_in_state >= 2)
            g_step_key = 0x1c0d;         /* auto-dismiss */
        if (!hi_score_init_done()) show_hi_score_init();
        show_hi_score_step();
        if (show_hi_score_done()) {
            hi_score_reset();
            es_state = 10;
        }
        step_in_state = 0;
        break;

    case 13: /* quit confirmation -- faithful port of SI35.PAS state 13.
               quit_confirm_init() paints the Yes/No box once;
               quit_confirm_step() advances the cursor.  Yes(quit) -> level
               selector (state 12); No/ESC -> continue gameplay (state 21). */
        if (!quit_confirm_init_done()) quit_confirm_init();
        quit_confirm_step();
        if (quit_confirm_done()) {
            unsigned char r = quit_confirm_result();
            quit_confirm_reset();
            /* The ESC that opened this box set quit_pending_flag during state
             * 21. It is now consumed by the quit dialog -- clear it, or the
             * very next state-21 step would see cc_quit_pending() still true
             * and immediately re-open the box (the No/ESC path got stuck in
             * state 13 forever, because cc_game_reset() only clears the flag
             * when a NEW level is loaded). */
            quit_pending_flag = 0;
            if (r == 1) {
                select_level_reset();      /* sl_init := false */
                es_state = 12;
            } else {
                es_state = 21;             /* No/ESC -> continue game */
            }
        }
        step_in_state = 0;
        break;

    case 21: /* gameplay -- faithful port of SI35.PAS state 21.
               Exactly one frame per engine_step. On a normal keypress the
               engine runs hra_step (the arcade/maze simulation) then
               vid_present and STAYS in state 21; it only leaves on level
               win/over or a special flag (ESC -> quit-confirm state 13,
               help -> info state 40, inventory -> overlay state 23).
               Load g_old_level's block into vec^[] / st (st.mie grid,
               st.meno, st.stav) via load_level_map(dat, subor) once, then
               cc_load_texture() carves the te^ tile table from the level's
               TEXTURA block. draw_state(21) renders the st.mie grid via
               print_texture() (LOAD235.PAS print_texture) as the level
               background, with the vec^[] sprite blit (print_predmet2) on
               top. */
        if (g_old_level != level_loaded_for) {
            const char *sub = g_levely ? g_levely->lev[g_old_level].subor : NULL;
            if (sub && g_level_dat) {
                load_level_map(g_level_dat, sub);
                cc_load_texture();          /* carve te^ for this level's TEXTURA */
                cc_load_veci();             /* carve GVECI handle[4] object sprites */
                /* GAME.INC hra_init: reset the coordinator flags, re-apply the
                   START position (cc_set_start_pos, set during load_level_map),
                   install the sipka_limit bounds + per-stav movx/movy/mova, and
                   run maze_init (clear g_bl + reveal the START cell window for
                   maze modes).  maze_init MUST run before check_visible() below
                   so object visibility is gated on the freshly initialised fog. */
                cc_game_reset();
                check_visible(1);           /* gate object visibility on g_bl */
                level_loaded_for = g_old_level;
            }
        }
        /* FLI intro animation (LOAD235.PAS play_ani).  cc_game_reset() above
           (and the state-22 level-change path) called play_ani(), which set
           g_flic_playing=1 and loaded the level's intro block (e.g. AI1).
           Show it (2x upscaled) BEFORE gameplay; a key skips it.  When the
           decoder finishes or the player skips, g_flic_playing=0 and the
           gameplay below runs.  This mirrors GAME.INC hra_init -> play_ani
           running the intro before the playfield is shown.

           SKIP-ONLY-ON-PRESS: a key-RELEASE word (bit 15 set, e.g. 0x9c00 for
           ENTER) must NOT skip the intro.  In real play the user presses ENTER
           at the briefing (state 30) to dismiss it and then lets go; the window
           forwards both the press word (0x1c0d, bit15 clear) and the release
           word (0x9c00, bit15 set).  The press is consumed at state 30, but the
           release lands a step or two into the intro, and treating it as a skip
           made the intro show only the first frame and jump to gameplay.  A
           deliberate skip is a fresh PRESS during the intro, so we only skip
           when the captured word is non-zero AND is a press (bit 15 clear).  The
           release word is still delivered to the rest of the engine (it clears
           the Klx[scan] stuck-key latch in gameplay), we only ignore it here. */
        if (g_flic_playing) {
            if (g_step_key != 0 && (g_step_key & 0x8000) == 0) g_flic_done = 1;
            if (!g_flic_done) {
                if (flic_step(&g_flic)) g_flic_done = 1;
            }
            if (getenv("DBG_FLIC") && g_flic_done == 0) {
                static int fl_first = 1;
                static int fl_cnt = 0;
                if (fl_first) { fl_first = 0;
                    fprintf(stderr, "[FLIC] state21: intro PLAYING w=%d h=%d period=%d frames=%d (will 2x-upscale to %dx%d)\n",
                            flic_w(&g_flic), flic_h(&g_flic), g_flic.period, g_flic.frame_count, FBW, FBH); }
                if ((fl_cnt++ % 10) == 0)
                    fprintf(stderr, "[FLIC] state21: frame idx=%d/%d steps=%d\n",
                            g_flic.cur, g_flic.frame_count, g_flic.steps);
            }
            if (g_flic_done) {
                flic_done(&g_flic);
                g_flic_playing = 0;
                g_flic_done = 0;
            } else {
                render_flic_frame();
            }
            gen++;
            step_in_state++;
            break;
        }
        if (getenv("ENGINE_DEBUG") && !getenv("DBG_DUMPED")) {
            setenv("DBG_DUMPED","1",1);
            int ff2, f2;
            FILE *gf = fopen("/tmp/grid.txt","w");
            if (gf) {
                fprintf(gf, "st.mie grid (rows=ff 0..26, cols=f 0..38):\n");
                fprintf(gf, "     ");
                for (f2=0; f2<=MIE_X; f2++) fprintf(gf, "%d", f2%10);
                fprintf(gf, "\n");
                for (ff2=0; ff2<=MIE_Y; ff2++) {
                    fprintf(gf, "%02d: ", ff2);
                    for (f2=0; f2<=MIE_X; f2++) {
                        unsigned char v = st.mie[f2][ff2];
                        fprintf(gf, "%c", (v==0)?'.':(v<10)?('0'+v):('A'+(v-10)));
                    }
                    fprintf(gf, "\n");
                }
                fclose(gf);
            }
            fprintf(stderr, "[DBG] START=(%d,%d) si=(%d,%d) po(88,88)=%d po(88,92)=%d po(92,96)=%d po(92,110)=%d g_inusable=%d\n",
                startx, starty, (int)si_x, (int)si_y,
                (int)po(88,88), (int)po(88,92), (int)po(92,96), (int)po(92,110), (int)g_inusable);
        }
        /* SI35.PAS state 21: the arcade/maze loop is gated by arc_done/maze_done.
           When a previous cc_hra_step set the level-win (the_koniec -> acc_init
           flag) or game-over (restart) coordinator, finalise and leave state 21
           (won -> congratulations state 22, over -> intro menu state 10).
           Otherwise run ONE game frame: cc_hra_step consumes this step's key and
           recomputes si.x/si.y + pose (pl/sipka_fake), checks po3 collision,
           redraws via zisti_vec. Hand off to the step-able dialogs on
           quit_pending/help_pending/inv_pending; otherwise STAY in state 21. */
        if (cc_arc_done() || cc_maze_done()) {
            cc_hra_final();
            if (cc_acc_init_flag()) {
                es_state = 22;   /* level won -> dialog */
                g_step_key = 0;  /* drop the key that won the level so the
                                    congratulations window is shown in full
                                    before the user advances (acc_step). */
            }
            else                    es_state = cc_end_state();  /* game over -> R.I.P. dialog */
        } else {
            cc_hra_step();
            if (cc_quit_pending())      es_state = 13;
            else if (cc_help_pending()) es_state = 40;
            else if (cc_inv_pending())  {
                /* SI35.PAS state 21: before opening the inventory / pause
                   overlay clear the pending flag (so the menu does not
                   re-open the instant it closes -- the quit box debounces
                   the same way via quit_pending_flag), clear inv_init so
                   menu_init() re-paints the box fresh, and clear any queued
                   item-activation dialog so menu_init/menu_step/pouzi_predmet
                   start clean. */
                inv_pending_flag  = 0;
                inv_init      = 0;
                inv_done      = 0;
                inv_direct_done = 0;
                pp_pending    = 0;
                pp_started    = 0;
                es_state = 23;
            }
        }
        draw_state(21, gen);
        gen++;
        break;

    case 20: {
        /* game-over dialog -- port of LOAD235.PAS strata_zivota zivoty==0
           branch: the R.I.P. splash (old_frame.draw + "Ooou !" / "R. I. P.")
           is painted ONCE over the frozen gameplay scene, then the game waits
           non-blocking for Enter / Space / ESC before returning to the intro
           menu (state 10).  This is the SAME game-over path used whether the
           player lost the last life (strata_zivota) or the level timer ran
           out (time_out -> zivoty := 0 -> strata_zivota). */
        if (!g_game_over_painted) {
            game_over_paint();
            g_game_over_painted = 1;
        }
        if (g_auto_run && !g_game_over_done && step_in_state >= 1)
            g_step_key = 0x1c0d;         /* auto-dismiss the game-over screen */
        game_over_step();
        if (g_game_over_done) {
            g_game_over_painted = 0;
            g_game_over_done = 0;
            es_state = 10;               /* game over -> intro menu */
        }
        fb_expand();
        gen++;
        break;
    }

    case 22: {
        /* level-complete dialog -- port of SI35.PAS state 22 + LOAD235.PAS
           acc_init / acc_step.  acc_paint() draws the congratulations/
           password window (once, over the frozen scene); acc_step() waits
           non-blocking for Enter / Space / ESC; then advance to the next
           level (inc(old_level) -> briefing state 30) or the ending menu
           (state 10) when this was the last level (acc_last). */
        if (!acc_painted) {
            acc_paint();
            acc_painted = 1;
        }
        acc_step();
        if (acc_done_flag) {
            if (acc_last) {
                es_state = 10;                    /* last level -> ending menu */
            } else {
                g_old_level++;                    /* inc(old_level) */
                /* Load the next level BEFORE the briefing, mirroring
                   hra_init() -> load_predmet2, so state 30 / 21 see the new
                   level's data.  (state 21 would reload on its own since
                   level_loaded_for != g_old_level, but loading here matches
                   the Pascal order: hra_init, then state 30.) */
                if (g_levely && g_old_level >= 1 && g_old_level <= 19) {
                    const char *sub = g_levely->lev[g_old_level].subor;
                    if (sub[0] && g_level_dat) {
                        load_level_map(g_level_dat, sub);
                        cc_load_texture();
                        cc_load_veci();
                        cc_game_reset();
                        check_visible(1);
                        level_loaded_for = g_old_level;
                    }
                }
                briefing_reset();                 /* briefing_started := false */
                es_state = 30;
            }
            acc_painted = 0;
        }
        fb_expand();
        gen++;
        break;
    }

    case 23: {
        /* Phase 9: inventory / pause overlay -- faithful port of SI35.PAS
           state 23.  Two sub-phases selected by a flag:
             * pp_pending : an item-activation [TEXT] dialog was queued by
               menu_init/menu_step (a direct-use 'V' object, or a committed
               inventory item used from its activation zone).  pouzi_predmet
               init() already painted the first line; pouzi_predmet_step()
               advances one command/text token per engine_step.  When pp_done,
               finalise like state 21 if the dialog won the level, else resume.
             * otherwise  : the inventory / pause overlay.  menu_init() paints
               it (or applies a direct-use object) once; menu_step() advances
               the cursor on each key press via engine_last_key() (like state
               12 / 13).  On commit, if the used item completed the level
               (the_koniec) finalise like state 21 does.
           The pp_pending dialog takes precedence so the item-activation
           screens step-able like briefing (es_state=30).

           NOTE: unlike state 21, state 23 does NOT call draw_state() here.
           draw_state() runs fb_vfill(0) (wipe the whole framebuffer) and
           redraws the playfield every step -- that is correct for gameplay
           (movement each frame) but it would erase the overlay on the very
           next step, because menu_init() paints the box only ONCE.  This
           mirrors SI35.PAS / MENU35.INC, where menu_init() paints the
           overlay once (old_frame.draw + draw_jxmenu3 + items) and
           menu_step() only moves the cursor -- the scene behind is frozen
           (saved via save_scr in the Pascal build) and the box persists.
           The same "freeze the scene, paint the overlay once" pattern is
           used by every other dialog state (22 acc_paint, 30 briefing,
           40 info, 41 hi-scores, 13 quit-confirm).  The scene is already
           on the framebuffer from the state-21 step that opened the menu. */
        if (pp_pending) {
            pouzi_predmet_step();
            fb_expand();                       /* vid_present */
            if (pp_done) {
                /* DONTUSE (command 47): the item was not consumed, so put it
                   back into the level (pp_z>0 only for a committed inventory
                   item; a direct-use 'V' dialog has pp_z=0 and nothing to
                   return). */
                if ((pp_z > 0) && (!pp_return)) g_vec[pp_z].mie = g_miestnost;
                pp_pending = 0;
                pp_started = 0;
                if (cc_the_koniec()) {
                    cc_hra_final();
                    es_state = cc_end_state();   /* won / over */
                } else {
                    es_state = 21;              /* dialog done -> gameplay */
                    step_in_state = 0;
                }
            }
        } else {
            if (!inv_init) menu_init();
            menu_step();
            fb_expand();                       /* vid_present */
            if (cc_the_koniec()) {
                cc_hra_final();
                es_state = cc_end_state();   /* won / over */
            } else if (pp_pending) {
                /* menu_step queued an item-activation dialog: keep state 23
                   so the next step runs pouzi_predmet_step() above. */
            } else if ((inv_direct_done) || (inv_done)) {
                es_state = 21;                  /* menu finished -> gameplay */
                step_in_state = 0;
            }
        }
        gen++;
        break;
    }

    case 9:  /* done: terminal, no-op */
        break;

    default:
        es_state = 9;
        break;
    }

    step_in_state++;
}

/* --------------------------------------------------------------------- */
/* Program entry point.                                                  */
/*                                                                     */
/* In the FPC build this role belongs to the SI35.PAS program body,     */
/* which calls the C host_main(). Here -- the pure C-C engine --        */
/* engine.c IS the program, so it provides main() and drives the same   */
/* C host. host_engine.c owns the run loop; main() just hands control   */
/* to it.                                                               */
/* --------------------------------------------------------------------- */
int host_main(void);   /* declared external in host_engine.c */

int main(void)
{
    return host_main();
}

