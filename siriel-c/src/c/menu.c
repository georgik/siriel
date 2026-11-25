/* =====================================================================
 * menu.c  -  faithful C port of the Siriel 3.5 INTRO MENU (GAME.INC).
 *
 * This is Phase D of the C-C engine.  It ports, line by line, the two
 * procedures that draw and drive the boot intro menu:
 *
 *   show_intro_page   -- builds me^.dat[1..pocet] from GAME.INC and paints
 *                        the version line, the "DISK: <meno_disku>" line
 *                        and every menu item (norm_it).
 *   choice_init       -- one-shot navigation setup (ch_sel=1, cursor pos).
 *   choice_step       -- one menu tick: blink the cursor, navigate up/down
 *                        on arrow keys, jump to an item on its hotkey,
 *                        commit on ESC/Enter/Space.
 *   choice_result     -- 0 = ESC, else the 1-based selected index.
 *
 * The real raster engine (JxGRAF printc / print_zoom_shadow) is NOT ported
 * yet -- the migration strategy allows the skeleton to render the menu with
 * the tiny 5x7 font in fb_draw.h (plus a block cursor box) instead.  The
 * menu STRUCTURE (items, positions, DOS key words, navigation rules) is a
 * faithful translation of GAME.INC, so the observable menu behaviour
 * matches the original.
 *
 * The menu lives in the SAME global state the engine observes (siriel.h):
 *   me          -- the 5-item intro menu (dat[1..pocet], pocet)
 *   g_ja        -- active language (tx[] index)
 *   g_num_disks -- >1 enables the DATADISK item
 *   g_meno_disku-- shown on the "DISK:" line
 * ===================================================================== */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "siriel.h"
#include "fb_draw.h"

/* engine_last_key(): the pending DOS key word this tick (engine.c).  Canned
 * by choice_step() exactly as GAME.INC's choice_step reads kkey2. */
unsigned short engine_last_key(void);

/* ---- the intro menu (me^ in Pascal) -- dat[1..5], 1-based use ---------- */
static t_menum_typ me;

/* ---- choice() navigation state (GAME.INC globals) --------------------- */
static unsigned char  ch_sel;      /* current selection, 1..pocet       */
static unsigned char  ch_done;     /* a choice was committed            */
static unsigned char  poloha;      /* panak pose frame 0..35            */
static unsigned short ch_lastkey;  /* last key seen by choice_step      */

/* si : postava (AKTIV35.PAS) -- the panak avatar position + copy buffer.
 * Mirrors GAME.INC choice_init/choice_step which drive it directly. */
static unsigned short si_x, si_y, si_oldx, si_oldy;  /* x,y,oldx,oldy  */
static unsigned short si_buf;        /* sir_buf = sir_nums-1 = 51 (copy buffer) */

/* --------------------------------------------------------------------- */
/* show_intro_page  (GAME.INC show_intro_page)                           */
/* --------------------------------------------------------------------- */
void show_intro_page(void)
{
    int f;

    /* reset the menu */
    memset(&me, 0, sizeof(me));
    me.pocet = 1;

    /* dat[1]: tx[ja,10] = "Game" */
    strncpy(me.dat[1].meno, TX(g_ja, 10), sizeof(me.dat[1].meno) - 1);
    me.dat[1].x = 270; me.dat[1].y = 150; me.dat[1].k = 0x2267;
    me.pocet++;

    /* dat[2]: tx[ja,11] = "Info + Help" */
    strncpy(me.dat[2].meno, TX(g_ja, 11), sizeof(me.dat[2].meno) - 1);
    me.dat[2].x = 270; me.dat[2].y = 185; me.dat[2].k = 0x1769;
    me.pocet++;

    /* dat[3]: tx[ja,12] = "Hi-scores" */
    strncpy(me.dat[3].meno, TX(g_ja, 12), sizeof(me.dat[3].meno) - 1);
    me.dat[3].x = 270; me.dat[3].y = 220; me.dat[3].k = 0x2368;
    me.pocet++;

    /* dat[4]: 'DATADISK' -- only when more than one disk is installed */
    if (g_num_disks > 1) {
        strncpy(me.dat[4].meno, "DATADISK", sizeof(me.dat[4].meno) - 1);
        me.dat[4].x = 270; me.dat[4].y = 255; me.dat[4].k = 0x2064;
        me.pocet++;
    }

    /* dat[pocet]: tx[ja,13] = "Quit"  (last item, no further inc) */
    strncpy(me.dat[me.pocet].meno, TX(g_ja, 13), sizeof(me.dat[me.pocet].meno) - 1);
    me.dat[me.pocet].x = 280; me.dat[me.pocet].y = 300; me.dat[me.pocet].k = 0x1071;

    /* ---- GAME.INC show_intro_page paint order -------------------------
     *   clear_bitmap(screen);
     *   draw_it(intro_obr, 0, 0);
     *   set_death_color(13);
     *   draw_gif_block(screen, input_file, 'GLOGO', 460, 100, palx);
     *   set_death_color(256);
     *   save_scr(...)                     -- no double buffer: no-op
     *   print_zoom_shadow(version, ...)
     *   print_zoom_shadow('DISK: '+meno_disku, ...)
     *   norm_it(me^.dat[f]) for each item
     *
     * C-C has no double-buffered handles[1], so the `if not handles[1].used`
     * branch (clear + draw) is always taken.  The graphics (draw_it + GLOGO)
     * are painted BEFORE the text, exactly as the original. */

    /* clear_bitmap(screen) */
    cc_clear_bitmap();

    /* draw_it(intro_obr, 0, 0) -- intro_obr='GTREEP' (no '>' prefix) is the
     * file-based branch; no .gif on disk, draws nothing. */
    draw_it(g_cfg.intro_obr, 0, 0);

    /* set_death_color(13); draw_gif_block(screen, input_file, 'GLOGO', 460,
     * 100, palx); set_death_color(256) */
    cc_set_death_color(13);
    cc_draw_gif_block_pub("GLOGO", 460, 100);
    cc_set_death_color(256);

    /* save_scr(handles[1],0,0,640,480) -- no double buffer: no-op */

    /* print_zoom_shadow(screen, 250, 20, version, 14, 2, 2, 3, 3, 0) */
    print_zoom_shadow(250, 20, g_version, 14, 2, 2, 3, 3, 0);

    /* print_zoom_shadow(screen, 230, 60, 'DISK: '+meno_disku, 11, 1, 2, 3, 3,
     * 0) */
    {
        char line[80];
        int n = 0;
        const char *dk = g_meno_disku;
        memcpy(line, "DISK: ", 6); n = 6;
        for (; *dk && n < (int)sizeof(line) - 1; dk++, n++) line[n] = *dk;
        line[n] = '\0';
        print_zoom_shadow(230, 60, line, 11, 1, 2, 3, 3, 0);
    }

    /* norm_it(me^.dat[f]) for every item -- normal (non-highlighted) */
    for (f = 1; f <= (int)me.pocet; f++)
        norm_it(me.dat[f].meno, me.dat[f].x, me.dat[f].y);

    /* Present the 8-bit back buffer to frame_rgb -- the host reads frame_rgb,
     * so without this the window would never see the menu (it would keep the
     * previous state's frame). Mirrors draw_state()'s final fb_expand(). */
    fb_expand();
}

/* --------------------------------------------------------------------- */
/* hi_it / si_pust  (GAME.INC)                                            */
/* --------------------------------------------------------------------- */
/* hi_it(mex) -- GAME.INC: print a menu item highlighted (color 12). */
static void hi_it(int x, int y, const char *meno)
{
    print_zoom_shadow(x, y, meno, 12, 2, 2, 3, 3, 0);
}

/* si_pust() -- sound effect stub (the C-C engine has no sound). */
static void si_pust(void) {}

/* --------------------------------------------------------------------- */
/* choice_init  (GAME.INC choice_init)                                   */
/* --------------------------------------------------------------------- */
void choice_init(void)
{
    /* GAME.INC choice_init:
       k:=0;
       si.buf:=sir_buf;          // sir_buf = sir_nums-1 = 51
       poloha:=0;
       ch_sel:=1;
       si.x:=me^.dat[ch_sel].x-25;
       si.y:=me^.dat[ch_sel].y+8;
       si.oldx:=si.x;  si.oldy:=si.y;
       init_charakter(resx,resy,si.x,si.y,0,si.buf,ar^);   // draw panak
     */
    ch_lastkey = 0;
    poloha = 0;
    ch_sel = 1;
    ch_done = 0;
    si_buf = 51;                 /* sir_buf = sir_nums-1 */
    si_x  = me.dat[ch_sel].x - 25;
    si_y  = me.dat[ch_sel].y + 8;
    si_oldx = si_x;
    si_oldy = si_y;
    /* init_charakter(resx=16,resy=16, si.x, si.y, chpoloha=0, si.buf, ar^) */
    init_charakter(16, 16, si_x, si_y, 0, si_buf, cc_ar());

    /* Present the back buffer (panak drawn next to the menu) to frame_rgb. */
    fb_expand();
}

/* --------------------------------------------------------------------- */
/* choice_step  (GAME.INC choice_step)                                   */
/* --------------------------------------------------------------------- */
void choice_step(void)
{
    unsigned short k;
    int f;
    /* `first` is a LOCAL in the Pascal and is reset to false on every call,
     * so the `if not first` block runs on EVERY step (it locks the current
     * position and highlights the current item). */

    if (ch_done) return;

    /* si.oldx:=si.x;  si.oldy:=si.y; */
    si_oldx = si_x;
    si_oldy = si_y;
    /* si.x:=me^.dat[ch_sel].x-25;  si.y:=me^.dat[ch_sel].y+8; */
    si_x  = me.dat[ch_sel].x - 25;
    si_y  = me.dat[ch_sel].y + 8;
    /* clear_key_buffer;  time:=getclock+600;  -> no-ops in C (C paces ticks) */

    /* inc(poloha);  if poloha>35 then poloha:=0; */
    poloha++;
    if (poloha > 35) poloha = 0;
    /* characteristic(si.x,si.y,si.oldx,si.oldy,poloha,si.buf,ar^) --
     * move / animate the panak avatar to the current selection. */
    karakter(si_x, si_y, si_oldx, si_oldy, poloha, si_buf, cc_ar());

    /* if not first then begin  (always taken: `first` starts false) */
    {
        /* si.oldx:=si.x;  si.oldy:=si.y;  (lock position for next step) */
        si_oldx = si_x;
        si_oldy = si_y;
        /* hi_it(me^.dat[ch_sel]); -- highlight the current item (color 12) */
        hi_it(me.dat[ch_sel].x, me.dat[ch_sel].y, me.dat[ch_sel].meno);
    }

    /* k:=kkey2; -- read the pending key (choice_step consumes one per tick) */
    k = engine_last_key();
    if (k != 0) {
        /* first:=false;  clear_key_buffer; */
        /* norm_it(me^.dat[ch_sel]); -- redraw the item as normal (color 9)
         * BEFORE navigating, exactly as the Pascal does. */
        norm_it(me.dat[ch_sel].meno, me.dat[ch_sel].x, me.dat[ch_sel].y);
        /* case k of $4800,$4b00: dec(ch_sel);  $4d00,$5000: inc(ch_sel); */
        if ((k == 0x4800 || k == 0x4b00) && ch_sel > 1) { si_pust(); ch_sel--; }
        else if ((k == 0x4d00 || k == 0x5000) && ch_sel < me.pocet) { si_pust(); ch_sel++; }
        /* hotkey jump: if this key matches any item, jump to it (k:=Enter) */
        for (f = 1; f <= (int)me.pocet; f++) {
            if (k == me.dat[f].k) { ch_sel = (unsigned char)f; k = 0x1c0d; break; }
        }
    }
    ch_lastkey = k;

    /* commit on ESC / Enter / Space */
    if (k == 0x011b || k == 0x1c0d || k == 0x3920) ch_done = 1;

    /* Present the updated back buffer (panak moved / item re-drawn) to
     * frame_rgb so the window sees the new menu position each tick. */
    fb_expand();
}

/* exposed so engine.c can route by the selected item's DOS key word
 * (matching SI35.PAS engine_step's `sel_key := me^.dat[es_selector].k`). */
unsigned short menu_item_key(int f)
{
    return me.dat[f].k;
}

/* --------------------------------------------------------------------- */
/* choice_result  (GAME.INC choice_result)                               */
/* --------------------------------------------------------------------- */
unsigned char choice_result(void)
{
    if (ch_lastkey == 0x011b) return 0;     /* ESC -> 0 */
    return ch_sel;                           /* else 1-based index */
}

/* exposed so engine.c can auto-commit after the menu idles */
unsigned char menu_ch_done(void)
{
    return ch_done;
}
