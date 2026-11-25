/* =====================================================================
 * fb_draw.h  -  the tiny 8-bit back-buffer drawing primitives shared by
 *               engine.c (per-state rendering) and menu.c (the intro /
 *               choice menu).  Both files write the SAME video_buffer and
 *               call the SAME expand_frame(), so the window sees one
 *               consistent framebuffer.
 *
 * The real raster engine (JxGRAF / anim_ext printc / print_zoom_shadow)
 * is NOT ported yet -- the migration strategy explicitly allows the
 * skeleton to be "not 100% correct" in the low-level drawing while the
 * C-C loop is proven.  These primitives render the DAT-loaded 8x16
 * bitmap font (FMOD, from MAIN.DAT, via the faithful JxGRAF print core
 * in engine.c::font_draw_str) and the state/menu backgrounds that the
 * skeleton needs.
 * ===================================================================== */
#ifndef FB_DRAW_H
#define FB_DRAW_H

#include <stdint.h>

/* fill the whole 640x480 8-bit back buffer with one colour index */
void fb_vfill(unsigned char c);

/* write one pixel (clipped) */
void fb_vput(int x, int y, unsigned char c);

/* filled rectangle x0..x1, y0..y1 (arguments in any order) */
void fb_vrect(int x0, int y0, int x1, int y1, unsigned char c);

/* draw one DAT-font glyph at (x,y): fg colour on bg colour (8x16 FMOD) */
void fb_vchar(int x, int y, unsigned char ch, unsigned char fg, unsigned char bg);

/* draw a NUL-terminated string at (x,y) */
void fb_vstr(int x, int y, const char *s, unsigned char fg, unsigned char bg);

/* draw a NUL-terminated string WITHOUT the per-glyph background fill
 * (glyph-only, mirrors Pascal print_normal/Printr) */
void fb_vstr_nobg(int x, int y, const char *s, unsigned char col);

/* ---- JxGRAf raster layer (engine.c) used by the intro menu (menu.c) ---- */

/* print a scaled (zoomx/zoomy) glyph string with a shadow: the menu font.
 * textcolor is the main glyph colour, col the shadow; (px,py) is the shadow
 * offset.  Mirrors GAME.INC print_zoom_shadow / norm_it. */
void print_zoom_shadow(int x, int y, const char *s,
                       unsigned char textcolor,
                       int zoomx, int zoomy, int px, int py,
                       unsigned char col);

/* draw one menu item with the shadow scaling (GAME.INC norm_it). */
void norm_it(const char *meno, int mx, int my);

/* tprint_draw -- JxEFEKT.PAS TPrint.print.  Centers the text when center=1
 * (x := getmaxx/2 - real_length(s)/2, getmaxx=639), optionally draws a shadow
 * copy at (x+px,y+py) in shadow_color when shadow=1, then the main glyph at
 * (x,y) in text_color, using print_normal semantics (fb_vstr_nobg).  Used by
 * the password prompt/field/result and the level-complete window. */
void tprint_draw(const char *s, int x, int y,
                 unsigned char text_color,
                 int px, int py, unsigned char shadow_color,
                 int center, int shadow);

/* intro-menu glue: clear the back buffer; set the recycled 'death' index.
 * The DAT resource-block decoder itself is internal to engine.c and is
 * reached only through draw_it() / cc_draw_gif_block_pub() below. */
void cc_clear_bitmap(void);
void cc_set_death_color(int num);

/* draw_gif_block(screen, input_file, kluc, fromx, fromy, palx) port: decode
 * the DAT resource block <kluc> from MAIN.DAT at (fromx, fromy).  Mirrors
 * GAME.INC draw_gif_block(screen, input_file, 'GLOGO', 460, 100, palx). */
void cc_draw_gif_block_pub(const char *kluc, int fromx, int fromy);

/* draw_it: if name[1]=='>' decode and draw the DAT resource block named
 * name+1 at (x,y) (the JxGRAF/BLOCKX GIF/LZW decoder lives in engine.c),
 * otherwise the file-based branch draws nothing.  Mirrors JXEFEKT.draw_it. */
void draw_it(const char *name, int x, int y);

/* expand the 8-bit back buffer into the 24-bit frame_rgb the host reads */
void fb_expand(void);

#endif /* FB_DRAW_H */
