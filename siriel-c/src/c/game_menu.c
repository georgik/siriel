/* =====================================================================
 * game_menu.c  -  C re-implementation of the Siriel 3.5 MENU-DRIVEN
 *                 RUN-LOOP STATES (the GAME.INC procedures driven by
 *                 SI35.PAS engine_step states 12/24/30/40/41/13).
 *
 * This is Phase D-2 of the C-C engine.  It ports, line by line from
 * src/pascal/GAME.INC (with the menu primitives from JXMENU.PAS and the
 * text object from JXEFEKT.PAS), the step-able routines the run loop hands
 * off to:
 *
 *   State 12  select_level_init / select_level_step   (level selector)
 *   State 24  password_init / password_step           (password prompt)
 *   State 30  briefing_init / briefing_step           (level objective)
 *   State 40  info_init / info_step (+ scroll_text)   (Info / Help)
 *   State 41  show_hi_score_init / show_hi_score_step (hi-score table)
 *   State 13  quit_confirm_init / quit_confirm_step   (Quit? Yes/No)
 *   + level_needs_password()  (detects the '>' password marker)
 *   + linew / linew2 / scroll_text_init / scroll_text_step (helpers)
 *
 * The real raster engine (JxGRAF print_normal / printc / printx2, the
 * TPrint napis/napis2 objects, the old_frame box, sound) is NOT ported yet.
 * Per the migration strategy ("it is OK to be not 100% correct/matching --
 * that mattered only in low-level functions; get C-C running, then finetune")
 * these are rendered with the tiny 5x7 bitmap font in fb_draw.h (plus a
 * block-cursor box) instead.  The menu STRUCTURE -- items, positions, DOS key
 * words, navigation rules, wrap-around, and every state transition in
 * SI35.PAS engine_step -- is a faithful translation, so the observable menu
 * behaviour matches the original.
 *
 * The menu state lives in the SAME globals the engine observes (siriel.h):
 *   levely^, g_ja, g_cfg (msg[]/scroll_sub/g_cfg.zvukovy_subor), g_level_dat,
 *   g_hraci, g_old_level, g_vybrane, g_menu_pointer.
 * ===================================================================== */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "siriel.h"
#include "fb_draw.h"

/* Screen geometry (the 640x480 framebuffer the host reads). */
#define FBW  640
#define FBH  480

/* engine_last_key(): the pending DOS key word this tick (engine.c).  Every
 * menu routine reads it exactly once per engine_step, mirroring GAME.INC's
 * kkey2 read inside choice_step / select_level_step / password_step / ... */
unsigned short engine_last_key(void);

/* SOUND STUBS -- per migration strategy, sound is redirected to no-ops.
 * These mirror engine.c's static stubs (file-local, so no link clash). */
static void pust(int snd)   { (void)snd; }
static void reload_sound(int f, const char *p, int s)
{ (void)f; (void)p; (void)s; }

/* clear_key_buffer -- the C host owns the keyboard (pending_key is consumed
 * once per engine_step and cleared), so there is nothing left to drain. */
static void clear_key_buffer_local(void) {}

/* restore the menu font after scroll_text -- the real set_font() is a no-op
 * here since the 5x7 font is always active. */
static void restore_font_local(void) {}

/* ---- 5x7 font tile.  chardx/chardy are the 16px menu tile
 * (old_frame.draw(200,40,12,18) -> 192x288 => 12*16, 18*16); each glyph
 * advances CHARDX=8 px (the DAT FMOD font is 8px wide, 1px advance gap). */
#define CHARDX  8
#define CHARDY  16

/* ---- menu rendering colours ----------------------------------------- */
#define MENU_BG        21     /* box interior (dark slate)          */
#define MENU_BORDER    15     /* box border (white)                 */
#define MENU_TITLE_FG  15     /* title text                         */
#define MENU_SCROLL_BG 20     /* info bottom fill */

/* DOS key words (JXVAR.PAS) used by the password text field. */
#define KB_ESC   0x011B
#define KB_ENTER 0x1C0D
#define KB_BACK  0x0E08

/* --------------------------------------------------------------------- */
/* jxmenu_typ (JXMENU.PAS) -- the menu table the step-able routines build. */
/* dat[1..64] 1-based, so the buffer must hold index 64.                 */
/* --------------------------------------------------------------------- */
typedef struct {
    char   meno[64];
    unsigned short x, y, k;
} t_polozka_menu;

typedef struct {
    t_polozka_menu dat[64];
    unsigned char  pocet, first, vybrane, roll, posuv;
    unsigned short x, y, x1, y1, col1, col2, col3;
    char           meno[64];
    int            draw_menu;
} t_jxmenu_typ;

/* --------------------------------------------------------------------- */
/* State 12: level selector (GAME.INC select_level_init / _step)         */
/* --------------------------------------------------------------------- */
static t_jxmenu_typ *sl_menu;
static unsigned short sl_f;
static unsigned char  sl_done;
static unsigned char  sl_result;
static unsigned char  sl_init;

/* --------------------------------------------------------------------- */
/* State 24: password prompt (GAME.INC password_init / _step)            */
/* --------------------------------------------------------------------- */
static char   pw_password[64];   /* required password (set by level_needs_password) */
static char   pw_field[32];      /* current input field, always ends with '<'      */
static unsigned char  pw_init;
static unsigned char  pw_done;
static unsigned char  pw_ok;

/* --------------------------------------------------------------------- */
/* State 13: quit-level confirmation (GAME.INC quit_confirm_init / _step)*/
/* --------------------------------------------------------------------- */
static t_jxmenu_typ *quit_menu;
static unsigned short quit_f;
static unsigned char  quit_done;
static unsigned char  quit_result;
static unsigned char  quit_init;

/* --------------------------------------------------------------------- */
/* State 30: level-start objective (GAME.INC briefing_init / _step)      */
/* --------------------------------------------------------------------- */
static unsigned char  briefing_started;
static unsigned char  briefing_done;

/* --------------------------------------------------------------------- */
/* State 40: Info / Help (GAME.INC info_init / _step) + scrolling help   */
/* --------------------------------------------------------------------- */
static unsigned char  info_started;
static unsigned char  info_done;
static int            info_ret;
static unsigned char  hs_started;
static unsigned char  hs_done;

/* scrolling-help text state (GAME.INC scroll_plocha[0..maxlen] + counters) */
#define SCROLL_MAX 4096
static unsigned char scroll_plocha[SCROLL_MAX + 1];
static int           scroll_counter;
static int           scroll_inter;
static int           scroll_smer;
static int           scroll_size;
static unsigned char scroll_posuv;
static unsigned char scroll_poloha;
static unsigned char scroll_started;
static unsigned char scroll_done;
static char          scroll_oldfont[16];

/* --------------------------------------------------------------------- */
/* Small rendering helpers (5x7 font stand-ins for the JxGRID raster).    */
/* --------------------------------------------------------------------- */

/* draw a hollow box border at (x,y) size w x h -- stand-in for
 * old_frame.draw / stvorec / graphicswindow. */
static void draw_frame(int x, int y, int w, int h)
{
    fb_vrect(x, y,      x + w, y,       MENU_BORDER);   /* top    */
    fb_vrect(x, y + h,  x + w, y + h,   MENU_BORDER);   /* bottom */
    fb_vrect(x, y,      x,     y + h,   MENU_BORDER);   /* left   */
    fb_vrect(x + w, y,  x + w, y + h,   MENU_BORDER);   /* right */
}

/* draw one menu item; mirrors Pascal hi_jxmenu / normal_jxmenu, which call
 * print_normal -> Printr: paint ONLY the lit glyph pixels in col2 (the
 * highlighted item) / col1 (a normal item), with NO background fill and NO
 * selection bar.  The letters therefore sit on the GLIST frame interior
 * (level selector) or the menu box (quit confirm) instead of a solid cell. */
static void draw_menu_item(t_jxmenu_typ *m, int f, int hi)
{
    if (hi)
        fb_vstr_nobg(m->dat[f].x, m->dat[f].y, m->dat[f].meno, m->col2);
    else
        fb_vstr_nobg(m->dat[f].x, m->dat[f].y, m->dat[f].meno, m->col1);
}

/* paint the menu items + title banner (NO box) -- mirrors the Pascal
 * draw_jxmenu3(), which draws only the title + items ON TOP of the
 * old_frame box drawn beforehand.  Exposed so select_level_init can
 * layer them on top of the GLIST frame (cc_draw_menu_frame). */
static void paint_menu_items(t_jxmenu_typ *m, int hi)
{
    int f, tw, tx;
    char title[80];

    /* title banner ' '+meno+' ' centred on the top edge */
    title[0] = ' ';
    {
        int ml = (int)strlen(m->meno);
        memcpy(title + 1, m->meno, (size_t)ml);
        title[1 + ml] = ' ';
        title[2 + ml] = '\0';
    }
    tw = (int)strlen(title);
    tx = m->x + (m->x1 / 2) - (tw * CHARDX / 2);
    /* Pascal draws the title with print_normal (glyph-only, col2) -- no
     * background bar; the frame decoration sits behind it.  Mirror that:
     * drop the old MENU_TITLE_BG fill and paint the font over the frame. */
    fb_vstr_nobg(tx, m->y + (CHARDY / 2), title, MENU_TITLE_FG);

    /* items 1..pocet */

    /* items 1..pocet */
    for (f = 1; f <= (int)m->pocet; f++)
        draw_menu_item(m, f, (f == hi) ? 1 : 0);
}

/* --------------------------------------------------------------------- */
/* jxmenu primitives (JXMENU.PAS) -- 5x7-font stand-ins.                 */
/*                                                                     */
/* init_jxmenu sets the box + palette; vloz_jxmenu2 appends an item at  */
/* dat[pocet] with the JxGRID layout (x := x+2*chardx, y := y+chardy +  */
/* pocet*chardy); size_jxmenu sets the box size; first_jxmenu sets the  */
/* default highlight.  roll_menu_up/down scroll the screen -- only      */
/* needed when pocet>roll, which never happens for the level selector   */
/* (13) or quit box (2), so they are no-ops here (posuv stays 0).       */
/* --------------------------------------------------------------------- */
static void init_jxmenu(unsigned short x, unsigned short y,
                        unsigned short col1, unsigned short col2,
                        unsigned short col3, const char *meno,
                        t_jxmenu_typ *m)
{
    memset(m, 0, sizeof(*m));
    m->x = x;  m->y = y;
    m->col1 = col1; m->col2 = col2; m->col3 = col3;
    m->roll = 20;
    m->posuv = 0;
    m->pocet = 0;
    m->first = 1;
    m->draw_menu = 0;
    strncpy(m->meno, meno, sizeof(m->meno) - 1);
    m->meno[sizeof(m->meno) - 1] = '\0';
}

/* Append an item.  Mirrors vloz_jxmenu2: ' '+meno+' ' with the JxGRID tile
 * layout, and returns via the implicit inc(pocet). */
static void vloz_jxmenu2(const char *meno, t_jxmenu_typ *m, unsigned short k)
{
    char item[80];
    int n = 0;
    (void)k;   /* k is unused by the level selector / quit box navigation */
    if (m->pocet < 64) {
        m->pocet++;
        item[n++] = ' ';
        {
            const char *p = meno;
            while (*p && n < (int)sizeof(item) - 2) item[n++] = *p++;
        }
        item[n++] = ' ';
        item[n] = '\0';
        m->dat[m->pocet].x = m->x + 2 * CHARDX;
        m->dat[m->pocet].y = m->y + CHARDY + (unsigned short)(m->pocet * CHARDY);
        strncpy(m->dat[m->pocet].meno, item, sizeof(m->dat[m->pocet].meno) - 1);
        m->dat[m->pocet].meno[sizeof(m->dat[m->pocet].meno) - 1] = '\0';
        m->dat[m->pocet].k = k;
    }
}

static void size_jxmenu(unsigned short x, unsigned short y, t_jxmenu_typ *m)
{
    m->x1 = x;
    m->y1 = y;
}

static void first_jxmenu(unsigned char num, t_jxmenu_typ *m)
{
    m->first = num;
}

static void roll_menu_up(t_jxmenu_typ *m)  { (void)m; }
static void roll_menu_down(t_jxmenu_typ *m) { (void)m; }

/* --------------------------------------------------------------------- */
/* linew / linew2  (GAME.INC) -- help-screen rule lines.                 */
/*                                                                     */
/* linew()   : a rule across the screen at y=199 and y=212.             */
/* linew2()  : a marker char at (31, 200+posuv) -- used by scroll_text. */
/* --------------------------------------------------------------------- */
static void linew(void)
{
    fb_vrect(31, 199, 31 + 33 * CHARDX, 200, 1);
    fb_vrect(31, 212, 31 + 33 * CHARDX, 213, 1);
}

static void linew2(unsigned char *posuv, unsigned char *poloha)
{
    char ch = (char)(*poloha + '0');   /* chr(poloha) */
    fb_vchar(31, 200 + *posuv, (unsigned char)ch, 15, 0);
}

/* Build 'a' + 'b' + ' ' + '!' into dst (used for the Correct/Incorrect
 * password feedback: tx[ja,18]+tx[ja,16]+' !'). */
static void cat3(const char *a, const char *b, const char *c,
                 char *dst, int sz)
{
    dst[0] = '\0';
    strncat(dst, a, sz - 1);
    dst[sz - 1] = '\0';
    strncat(dst, b, sz - 1 - (int)strlen(dst));
    dst[sz - 1] = '\0';
    strncat(dst, c, sz - 1 - (int)strlen(dst));
    dst[sz - 1] = '\0';
}

/* --------------------------------------------------------------------- */
/* scroll_text_init / scroll_text_step  (GAME.INC)                       */
/*                                                                     */
/* Loads the SCROLL help block (from the CONFIG SCROLL option, falling  */
/* back to the 'SCROLL' block), decodes it, builds the wrap-around     */
/* buffer, and scrolls a 30-char window.  Dismissed on Enter/Space/ESC. */
/* --------------------------------------------------------------------- */
static void scroll_text_init(void)
{
    unsigned char buf[SCROLL_MAX + 1];
    int f, n;

    scroll_started = 1;
    scroll_done = 0;
    strncpy(scroll_oldfont, "def_font2", sizeof(scroll_oldfont) - 1);
    scroll_posuv = 0;
    scroll_smer = 1;
    scroll_poloha = 1;
    scroll_counter = 0;
    scroll_inter = 0;
    for (f = 0; f <= SCROLL_MAX; f++) scroll_plocha[f] = 0;

    linew();

    /* if not checkblock_info(zvukovy_subor,scroll_sub) then scroll_sub :=
     * scroll_subor ('SCROLL').  The CONFIG has no SCROLL option, so we load
     * the 'SCROLL' block straight from the level DAT. */
    /* load_level_block does the exact original sequence:
     *   loadblock_array(zvukovy_subor,scroll_sub,scroll_plocha);
     *   for f:=0.. until buf[f]=0 do if buf[f]>0 then buf[f]:=ord(buf[f])+2;
     * i.e. dekoduj(+2) is applied ONCE.  We must NOT apply it again here --
     * the original Caesar shift is a single +2, so a second pass would
     * re-encode the text into garbage. */
    n = load_level_block(g_level_dat, "SCROLL", buf, sizeof(buf));
    if (n > 0) {
        /* build scroll_plocha from the already-decoded text (bytes >15 only) */
        n = 0;
        for (f = 0; buf[f] != 0 && f < SCROLL_MAX; f++) {
            if (buf[f] > 15) scroll_plocha[n++] = buf[f];
        }
        scroll_plocha[n] = 0;
        scroll_size = n;
    } else {
        /* no block -> tx[ja,14] = "No message" */
        const char *p = TX(g_ja, 14);
        for (f = 0; p[f] && f < SCROLL_MAX; f++)
            scroll_plocha[f] = (unsigned char)p[f];
        scroll_size = (int)strlen((const char *)scroll_plocha);
        scroll_plocha[scroll_size] = 0;
    }

    /* duplicate the text with a 32-space gap before/after for smooth
     * scrolling (GAME.INC: the scroll_size<maxlen-60 branch). */
    if (scroll_size < SCROLL_MAX - 60) {
        for (f = scroll_size; f >= 0; f--)
            scroll_plocha[f + 32] = scroll_plocha[f];
        scroll_size += 33;
        for (f = 0; f < 32; f++) {
            scroll_plocha[f] = (unsigned char) ' ';
            scroll_plocha[f + scroll_size] = (unsigned char) ' ';
        }
        scroll_size += 32;
    }
}

/* Returns 1 (scroll_text_step) when the help text was dismissed. */
static unsigned char scroll_text_step(void)
{
    char pch[48];
    int f;

    if (scroll_done) return 0;
    /* inc(scroll_inter) each tick; advance the text window every 4 ticks */
    scroll_inter++;
    if (scroll_inter == 4) { scroll_inter = 0; scroll_counter++; }
    if (scroll_counter > scroll_size - 30) scroll_counter = 0;

    pch[0] = '\0';
    for (f = 1; f <= 30 && (scroll_counter + f) < scroll_size; f++) {
        char c = (char)scroll_plocha[scroll_counter + f];
        int pl = (int)strlen(pch);
        if (pl < (int)sizeof(pch) - 1) pch[pl] = c;
    }

    scroll_posuv += (unsigned char)scroll_smer;
    if (scroll_posuv == 10 || scroll_posuv == 0) {
        scroll_smer = -scroll_smer;
        scroll_poloha++;
        if (scroll_poloha == 7) scroll_poloha = 1;
    }

    /* render the 30-char window on the info bottom frame (stand-in for
     * printx2 at 40-scroll_inter*2, 200+scroll_posuv) */
    fb_vstr(40, 300, pch, 15, MENU_SCROLL_BG);
    linew2(&scroll_posuv, &scroll_poloha);

    {
        unsigned short k = engine_last_key();
        if (k != 0) {
            clear_key_buffer_local();
            if ((k == KB_ENTER) || (k == 0x3920) || (k == KB_ESC)) {
                scroll_done = 1;
                restore_font_local();   /* set_font(scroll_oldfont) */
                return 1;
            }
        }
    }
    return 0;
}

/* --------------------------------------------------------------------- */
/* briefing_init / briefing_step  (GAME.INC)                             */
/*                                                                     */
/* Shows the level's objective text (MSG1..MSG5) read from the level    */
/* block, and dismisses on Enter/Space/ESC.  Levels with no objective   */
/* text skip straight to gameplay (briefing_done := true in init).      */
/* --------------------------------------------------------------------- */
void briefing_init(void)
{
    unsigned char buf[MAXLEN_LEVEL + 1];
    char msg[6][81];
    char sub[16];
    int f, n;

    briefing_done = 0;

    /* load the selected level's block and read MSG1..MSG5 straight from it
     * (load_predmet2, which normally fills msg[], is not ported yet). */
    sub[0] = '\0';
    if (g_old_level >= 1 && g_old_level <= 19)
        strncpy(sub, g_levely->lev[g_old_level].subor, sizeof(sub) - 1);
    sub[sizeof(sub) - 1] = '\0';
    if (getenv("ENGINE_DEBUG"))
        fprintf(stderr, "[BRF] briefing_init level=%d sub='%s' name='%s'\n",
                g_old_level, sub,
                (g_old_level >= 1 && g_old_level <= 19 && g_levely)
                    ? g_levely->lev[g_old_level].meno : "(n/a)");
    n = load_level_block(g_level_dat, sub, buf, sizeof(buf));

    for (f = 1; f <= 5; f++) {
        const char *field;
        msg[f][0] = '\0';
        field = (f == 1) ? "MSG1" : (f == 2) ? "MSG2" :
                (f == 3) ? "MSG3" : (f == 4) ? "MSG4" : "MSG5";
        if (n > 0 && level_field(buf, field, msg[f], sizeof(msg[f])))
            ;  /* leave as-is */
    }

    if ((msg[1][0] != '\0') || (msg[2][0] != '\0') || (msg[3][0] != '\0') ||
        (msg[4][0] != '\0') || (msg[5][0] != '\0')) {
        /* zhasni; clear_bitmap(screen) */
        fb_vfill(0);
        /* for f:=1 to 5 do printc(screen,f*(chardy*2)+150,msg[f],15,0);
         * printc centres the text horizontally at the given y. */
        for (f = 1; f <= 5; f++) {
            if (msg[f][0] == '\0') continue;
            int tw = (int)strlen(msg[f]);
            int cx = (FBW / 2) - (tw * CHARDX / 2);
            fb_vstr(cx, (f * (CHARDY * 2)) + 150, msg[f], 15, 0);
        }
        briefing_done = 0;
    } else {
        briefing_done = 1;      /* no objective text -> nothing to show */
    }
    /* engine.c mirrors SI35.PAS: `if not briefing_started then begin
       briefing_init; briefing_started := true; end;`.  The Pascal sets
       briefing_started in engine_step; here the init sets it itself (exactly
       like select_level_init sets sl_init, password_init sets pw_init, ...),
       so the init-once guard select_level_init_done()/briefing_init_done()
       works uniformly. */
    briefing_started = 1;
    fb_expand();
}

void briefing_step(void)
{
    unsigned short k = engine_last_key();
    if (briefing_done) return;
    if (k != 0) {
        clear_key_buffer_local();
        /* a key-RELEASE word has bit 15 set and carries no character */
        if ((k & 0x8000) == 0)
            if ((k == KB_ENTER) || (k == KB_ESC) || (k == 0x3920))
                briefing_done = 1;
    }
}

/* --------------------------------------------------------------------- */
/* info_init / info_step  (GAME.INC)                                     */
/*                                                                     */
/* The Info / Help page: controls list + credits, and the scrolling     */
/* help text.  Dismissed on Enter/Space/ESC; info_ret selects the state */
/* to return to (10 = main menu, 21 = gameplay).                        */
/* --------------------------------------------------------------------- */
void info_init(void)
{
    int f;

    info_done = 0;

    /* draw_scr(handles[1],...) -- restore saved screen: not available, so
     * clear the area we own. */
    fb_vfill(0);

    /* old_frame.draw frames: top (controls) and bottom (scrolling help).
     * 21x6 tiles at 16px = 336x96. */
    draw_frame(125, 2, 336, 96);
    draw_frame(125, 150, 336, 96);

    /* napis.print_col(0,10,tx[ja,15],14) -- ' HELP:' title */
    fb_vstr(0, 10, TX(g_ja, 15), 14, 0);

    /* napis2.print(0,30..90,tx3[ja,3..6]) -- controls */
    fb_vstr(0, 30,  TX(g_ja, 3),  15, 0);
    fb_vstr(0, 50,  TX(g_ja, 4),  15, 0);
    fb_vstr(0, 70,  TX(g_ja, 5),  15, 0);
    fb_vstr(0, 90,  TX(g_ja, 6),  15, 0);

    /* Info: credits block */
    fb_vstr(0, 160, "Info:", 14, 0);
    fb_vstr(0, 180, "Juraj Michlek", 14, 0);

    /* reload_sound(3,...,snd_acces); pust(3); linew(); */
    reload_sound(3, g_cfg.zvukovy_subor, 3);
    pust(3);
    linew();

    /* clear_key_buffer; scroll_text_init */
    scroll_text_init();

    /* Mirrors SI35.PAS: `if not info_started then begin info_init;
       info_started := true; end;` -- the init sets its own started flag so
       the init-once guard (info_init_done()) works like the others. */
    info_started = 1;
    fb_expand();
}

void info_step(void)
{
    /* advance the scrolling help one frame per engine_step.  When the user
     * presses Enter/Space/ESC scroll_text_step sets scroll_done, which we
     * propagate to info_done. */
    if (scroll_text_step()) {
        info_done = 1;
        restore_font_local();
    }
}

/* --------------------------------------------------------------------- */
/* show_hi_score_init / show_hi_score_step  (GAME.INC)                   */
/*                                                                     */
/* The hi-score table (banda^[1..10]).  Dismissed on Enter/Space/ESC.   */
/* --------------------------------------------------------------------- */
void show_hi_score_init(void)
{
    char s[32];
    int f;

    hs_done = 0;

    /* The box border + interior fill come from the GLIST menu frame
     * (old_frame.draw), the SAME decoration mechanism the level selector
     * uses via cc_draw_menu_frame.  The old stand-in draw_frame() only drew
     * a hollow 4-line border, so the box interior showed the leftover menu
     * noise behind it -- "only letters".  cc_draw_menu_frame fills the
     * interior (rectangle2, g_frame_fill) then paints the 8 GLIST border
     * tiles, giving the clean decorated box the original had.
     *
     *   old_frame.draw(180,140,14,10) -- 14x10 tiles at 16px = 224x160,
     *   matching the previous draw_frame(180,140,224,160) footprint. */
    cc_draw_menu_frame(180, 140, 14, 10);

    /* printc(screen,145,tx[ja,12],15,0) -- 'Hi-scores' centred at y=145.
     * print_normal draws ONLY the lit glyph pixels (no bg fill), so the
     * GLIST frame interior shows through the letters instead of a black
     * cell -- use fb_vstr_nobg, not fb_vstr (which fills each cell). */
    {
        int tw = (int)strlen(TX(g_ja, 12));
        int cx = (FBW / 2) - (tw * CHARDX / 2);
        fb_vstr_nobg(cx, 145, TX(g_ja, 12), 15);
    }

    /* for f:=1 to 10 do begin
     *   prints(screen,200,143+f*16,2,2,s+'. '+hraci^[f].meno,65+f,0,0);
     *   prints(screen,350,143+f*16,2,2,s,65+f,0,0);
     * end;
     * prints(bitmap,x,y,pox,poy,s,textcolor,shadow,roll) ==
     *   printx(x+pox,y+poy,s,shadow,0)  +  printx(x,y,s,textcolor,roll);
     * BOTH draw only lit pixels (transparent).  shadow=0 -> black offset
     * silhouette; textcolor = 65+f per row.  fb_vstr_nobg reproduces
     * printx (no bg fill). */
    for (f = 1; f <= 10; f++) {
        char name[32];
        /* shadow: printx(bitmap, x+pox, y+poy, s, shadow=0, 0) */
        snprintf(name, sizeof(name), "%d. %s", f, g_hraci[f].buf);
        fb_vstr_nobg(202, 145 + f * 16, name, 0);
        /* main: printx(bitmap, x, y, s, textcolor=65+f, 0) */
        fb_vstr_nobg(200, 143 + f * 16, name, 65 + f);
        /* score: prints(screen,350,143+f*16,2,2,s,65+f,0,0) */
        snprintf(s, sizeof(s), "%d", g_hraci[f].score);
        fb_vstr_nobg(352, 145 + f * 16, s, 0);
        fb_vstr_nobg(350, 143 + f * 16, s, 65 + f);
    }

    /* reload_sound(3,...,snd_acces); pust(3); clear_key_buffer; */
    reload_sound(3, g_cfg.zvukovy_subor, 3);
    pust(3);

    /* Mirrors SI35.PAS: `if not hs_started then show_hi_score_init;
       hs_started := true;` -- the init sets its own started flag. */
    hs_started = 1;
    fb_expand();
}

void show_hi_score_step(void)
{
    unsigned short k = engine_last_key();
    if (hs_done) return;
    if (k != 0) {
        clear_key_buffer_local();
        if ((k & 0x8000) == 0)
            if ((k == KB_ENTER) || (k == KB_ESC) || (k == 0x3920))
                hs_done = 1;
    }
}

/* --------------------------------------------------------------------- */
/* level_needs_password  (GAME.INC)                                      */
/*                                                                     */
/* Loads level f's block and detects the '>' password marker in [MENO]. */
/* If present, pw_password := out_string([MENO]) (upcased) and this     */
/* returns true; the caller then enters state 24.  Non-protected levels */
/* are NOT started here -- the caller starts them via hra_init().       */
/* --------------------------------------------------------------------- */
int level_needs_password(unsigned char level, char *pw_out, int pw_sz)
{
    char sub[16];
    unsigned char buf[MAXLEN_LEVEL + 1];
    char meno[80];
    int n;

    g_old_level = level;
    pw_password[0] = '\0';
    if (pw_out && pw_sz > 0) { pw_out[0] = '\0'; pw_out[pw_sz - 1] = '\0'; }

    sub[0] = '\0';
    if (level >= 1 && level <= 19)
        strncpy(sub, g_levely->lev[level].subor, sizeof(sub) - 1);
    sub[sizeof(sub) - 1] = '\0';
    if (sub[0] == '\0') return 0;

    n = load_level_block(g_level_dat, sub, buf, sizeof(buf));
    if (getenv("ENGINE_DEBUG"))
        fprintf(stderr, "[PW] level_needs_password level=%d sub='%s' -> n=%d\n",
                level, sub, n);
    if (n <= 0) return 0;

    if (level_field(buf, "MENO", meno, sizeof(meno)) && meno[0] == '>') {
        char pw[64];
        strncpy(pw, meno, sizeof(pw) - 1);
        pw[sizeof(pw) - 1] = '\0';
        out_string(pw, sizeof(pw));      /* strip the leading '>' */
        upcased(pw);
        strncpy(pw_password, pw, sizeof(pw_password) - 1);
        pw_password[sizeof(pw_password) - 1] = '\0';
        if (pw_out && pw_sz > 0) {
            strncpy(pw_out, pw, pw_sz - 1);
            pw_out[pw_sz - 1] = '\0';
        }
        return 1;
    }
    return 0;
}

/* --------------------------------------------------------------------- */
/* password_init / password_step  (GAME.INC)                           */
/*                                                                     */
/* Paints the ' Password:' prompt and the (empty) input field, then    */
/* reads exactly one key per engine_step: printable chars are typed,    */
/* backspace deletes, Enter/ESC submits and validates against           */
/* pw_password.  Correct -> pw_ok (gameplay); wrong/ESC -> back to the */
/* level selector.                                                     */
/* --------------------------------------------------------------------- */
void password_init(void)
{
    char prompt[64];
    int n = 0;

    /* napis.print(0,400, tx[ja,17]+tx[ja,16]+':') -- 'Enter password:'
     * (centred via real_length; the Pascal string has NO leading space --
     * tx[ja,17]='Enter ' already ends with a space). */
    { const char *p = TX(g_ja, 17); while (*p && n < (int)sizeof(prompt) - 1) prompt[n++] = *p++; }
    { const char *p = TX(g_ja, 16); while (*p && n < (int)sizeof(prompt) - 1) prompt[n++] = *p++; }
    if (n < (int)sizeof(prompt)) prompt[n++] = ':';
    prompt[n] = '\0';
    tprint_draw(prompt, 0, 400, 15, 2, 2, 0, 1, 1);   /* napis: Enter password: */

    pw_field[0] = '<';          /* single placeholder (napis2.input) */
    pw_field[1] = '\0';
    tprint_draw(pw_field, 0, 420, 14, 2, 2, 0, 1, 0);  /* napis2: field, centred */

    pw_init = 1;
    pw_done = 0;
    pw_ok   = 0;
    fb_expand();
}

void password_step(void)
{
    unsigned short k;
    char pw_cmp[64];

    if (pw_done) return;

    k = engine_last_key();
    if (k != 0) {
        clear_key_buffer_local();

        /* ignore key-RELEASE words (bit 15 set) -- they carry no char */
        if ((k & 0x8000) == 0) {
            unsigned char c = (unsigned char)(k & 0xFF);
            int len = (int)strlen(pw_field);

            /* printable char: replace the trailing placeholder, add a new */
            if (k != KB_ESC && k != KB_BACK && k != KB_ENTER &&
                c >= ' ' && c <= '~' && len <= 10 &&
                k != 0x4800 && k != 0x5000 && k != 0x4b00 && k != 0x4d00) {
                tprint_draw(pw_field, 0, 420, 0, 2, 2, 0, 1, 0);  /* erase field */
                pw_field[len - 1] = (char)c;          /* replace placeholder */
                pw_field[len] = '<';                  /* new placeholder */
                pw_field[len + 1] = '\0';
                tprint_draw(pw_field, 0, 420, 14, 2, 2, 0, 1, 0); /* redraw */
            } else if (k != KB_ESC && k != KB_BACK && k != KB_ENTER) {
                tprint_draw(pw_field, 0, 420, 14, 2, 2, 0, 1, 0); /* refresh */
            }

            /* backspace */
            if (k == KB_BACK) {
                len = (int)strlen(pw_field);
                if (len > 1) {
                    tprint_draw(pw_field, 0, 420, 0, 2, 2, 0, 1, 0);  /* erase field */
                    pw_field[len - 2] = '<';          /* drop one typed char */
                    pw_field[len - 1] = '\0';
                    tprint_draw(pw_field, 0, 420, 14, 2, 2, 0, 1, 0); /* redraw */
                } else {
                    tprint_draw("<", 0, 420, 14, 2, 2, 0, 1, 0);
                }
            } else if (k == KB_ENTER || k == KB_ESC) {
                tprint_draw(pw_field, 0, 420, 0, 2, 2, 0, 1, 0);  /* erase field */
                if (k == KB_ESC) {
                    pw_field[0] = '\0';               /* empty */
                } else {
                    int l = (int)strlen(pw_field);    /* drop trailing placeholder */
                    if (l > 0) pw_field[l - 1] = '\0';
                }
                tprint_draw(pw_field, 0, 420, 14, 2, 2, 0, 1, 0);

                upcased(pw_field);                    /* case-insensitive compare */
                strncpy(pw_cmp, pw_field, sizeof(pw_cmp) - 1);
                pw_cmp[sizeof(pw_cmp) - 1] = '\0';
                pw_ok = (strcmp(pw_cmp, pw_password) == 0);
                pw_done = 1;
                if (pw_ok) {
                    char msg[96];
                    cat3(TX(g_ja, 18), TX(g_ja, 16), " !", msg, sizeof(msg));
                    /* napis2.print_col(0,440,msg,12) -- 'Correct password !' */
                    tprint_draw(msg, 0, 440, 12, 2, 2, 0, 1, 0);
                    pust(0);
                } else {
                    char msg[96];
                    cat3(TX(g_ja, 19), TX(g_ja, 16), " !", msg, sizeof(msg));
                    /* napis2.print_col(0,440,msg,12) -- 'Incorrect password !' */
                    tprint_draw(msg, 0, 440, 12, 2, 2, 0, 1, 0);
                    reload_sound(3, g_cfg.zvukovy_subor, 21);
                    pust(3);
                }
            }
        }
    }
    fb_expand();
}

/* --------------------------------------------------------------------- */
/* select_level_init / select_level_step  (GAME.INC)                     */
/*                                                                     */
/* The level selector: a boxed list of all levels + a BACK option.     */
/* Navigate up/down (wrap-around), jump on a hotkey, commit on          */
/* Enter/Space/ESC.  sl_result = chosen level (1..pocet-1), or 0 for    */
/* BACK / ESC.                                                           */
/* --------------------------------------------------------------------- */
/* The level-selector box border + interior fill come from the GLIST menu
 * frame (old_frame.draw), NOT the GZAL animation sheet.  GLIST (MAIN.DAT)
 * is decoded into g_frame by cc_load_frame() at engine init; cc_draw_menu_frame
 * (now parameterised as cc_draw_menu_frame(x,y,dx,dy), mirroring
 * SI35.PAS old_frame.draw(x,y,dx,dy)) blits the 8 border tiles + interior
 * fill.  The level selector calls it at (200,40,12,18); the "Quit" dialog
 * calls it at (270,180,3,3) -- the SAME mechanism, different coordinates.
 * The items/title are layered ON TOP (paint_menu_items) -- the same
 * ordering as old_frame.draw then draw_jxmenu3 in GAME.INC.  (The old
 * GZAL-flask decoration -- init_charakter blitting GZAL cells 37/38/41/42
 * around the box -- was WRONG: those are the panak animation sprites, not
 * the menu frame.)                       */

void select_level_init(void)
{
    unsigned char f;
    char back[80];

    /* set_defaults; decrease_palette; set_def; clear_all_data;
     * clear_bitmap(screen); print_normal(screen,160,380,tx3[ja,7],14,0); */
    fb_vfill(0);
    fb_vstr(160, 380, TX3(g_ja, 7), 14, 0);

    if (!sl_menu) sl_menu = calloc(1, sizeof(*sl_menu));
    if (getenv("DBG_DUMP_VEC")) {
        fprintf(stderr, "[SEL-INIT] pocet=%d\n", g_levely ? g_levely->pocet : -1);
        for (unsigned char ff = 1; ff <= g_levely->pocet && ff <= 63; ff++)
            fprintf(stderr, "[SEL-INIT]   lev[%d].meno='%s'\n", ff, g_levely->lev[ff].meno);
    }
    init_jxmenu(200, 40, 0, 15, 0, "Level", sl_menu);
    for (f = 1; f <= g_levely->pocet && f <= 63; f++) {
        vloz_jxmenu2(g_levely->lev[f].meno, sl_menu, 0);
    }
    /* BACK option -- last item.  Mirrors GAME.INC: `vloz_jxmenu2('   '+tx[ja,22],
       sl_menu^,0)` (3 leading spaces, then 'Back'; vloz_jxmenu2 wraps it in its
       own single spaces).  Selecting it yields sl_result = 0 (-> intro menu). */
    {
        const char *p = TX(g_ja, 22);
        int n = 0;
        back[n++] = ' '; back[n++] = ' '; back[n++] = ' ';   /* 3 leading spaces */
        while (*p) back[n++] = *p++;
        back[n] = ' '; back[n + 1] = '\0';
    }
    vloz_jxmenu2(back, sl_menu, 0);

    g_menu_pointer = 1;
    first_jxmenu(g_menu_pointer, sl_menu);
    size_jxmenu(192, 288, sl_menu);

    sl_f = sl_menu->first;
    sl_done = 0;
    sl_result = 0;
    sl_init = 1;

    /* The box border + interior fill come from the GLIST menu frame
     * (old_frame.draw), layered UNDER the items/title.  Draw the frame
     * first, then the items+title on top -- the Pascal ordering
     * old_frame.draw(200,40,12,18) then draw_jxmenu3(). */
    cc_draw_menu_frame(200, 40, 12, 18);
    paint_menu_items(sl_menu, (int)sl_f);
    fb_expand();
}

void select_level_step(void)
{
    unsigned short k;
    int ff;

    if (sl_done) return;

    /* re-highlight current selection.  Do NOT repaint the gray box
     * background here: the GLIST frame interior (cc_draw_menu_frame,
     * drawn at select_level_init) is the real background.  We only
     * redraw the title + items on top of it (mirrors Pascal hi_jxmenu). */
    paint_menu_items(sl_menu, (int)sl_f);
    fb_expand();

    k = engine_last_key();
    if (k != 0) {
        clear_key_buffer_local();

        /* navigate up/down, wrapping around the list */
        if (k == 0x4800 || k == 0x4b00 || k == 0x4838 || k == 0x4b34 || k == 0x4a2d) {
            if (sl_f > 1) {
                sl_f--;
            } else if (sl_menu->pocet <= sl_menu->roll) {
                sl_f = sl_menu->pocet;   /* wrap to last */
            }
        } else if (k == 0x5000 || k == 0x4d00 || k == 0x5032 || k == 0x4d36 || k == 0x4e2b) {
            if (sl_f < sl_menu->pocet) {
                sl_f++;
            } else if (sl_menu->pocet <= sl_menu->roll) {
                sl_f = 1;                /* wrap to first */
            }
        }

        /* hotkey jump: if this key matches any item, select it */
        for (ff = 1; ff <= (int)sl_menu->pocet; ff++)
            if (k == sl_menu->dat[ff].k) sl_f = (unsigned short)ff;

        /* commit on Enter / Space / ESC */
        if ((k == 0x1c0d) || (k == 0x3920) || (k == 0x011b)) {
            if (k == 0x011b) sl_result = 0;             /* ESC */
            else if (sl_f < sl_menu->pocet) sl_result = (unsigned char)sl_f;  /* level */
            else sl_result = 0;                          /* BACK chosen */
            sl_done = 1;
        }
    }
}

/* --------------------------------------------------------------------- */
/* quit_confirm_init / quit_confirm_step  (GAME.INC ano_nie2)            */
/*                                                                     */
/* The "Quit level? Yes/No" box shown when ESC is pressed during        */
/* gameplay.  Navigate between Yes/No, commit on Enter/Space; ESC = No  */
/* (continue).  quit_result = 1 (Yes, quit level) or 2 (No/ESC, continue).*/
/* --------------------------------------------------------------------- */
void quit_confirm_init(void)
{
    char yes[80], no[80];

    if (!quit_menu) quit_menu = calloc(1, sizeof(*quit_menu));
    init_jxmenu(270, 180, 0, 15, 0, TX(g_ja, 13), quit_menu);  /* title "Quit" */
    size_jxmenu(100, 100, quit_menu);

    /* Yes */
    {
        const char *p = TX(g_ja, 23);
        int n = 1;
        yes[0] = ' ';
        while (*p && n < (int)sizeof(yes) - 2) yes[n++] = *p++;
        yes[n] = ' '; yes[n + 1] = '\0';
        vloz_jxmenu2(yes, quit_menu, 0);
    }

    /* No */
    {
        const char *p = TX(g_ja, 24);
        int n = 1;
        no[0] = ' ';
        while (*p && n < (int)sizeof(no) - 2) no[n++] = *p++;
        no[n] = ' '; no[n + 1] = '\0';
        vloz_jxmenu2(no, quit_menu, 0);
    }

    size_jxmenu(64, 48, quit_menu);

    quit_f = quit_menu->first;     /* default highlight = Yes */
    quit_done = 0;
    quit_result = 2;               /* safe default = continue */
    quit_init = 1;

    /* The box border + interior fill come from the GLIST menu frame
     * (old_frame.draw), layered UNDER the items/title -- the SAME
     * mechanism the level selector uses (cc_draw_menu_frame), just at the
     * quit dialog's coordinates.  Mirror GAME.INC ano_nie2 exactly:
     *
     *   old_frame.draw(270, 180, 3, 3);   ->  cc_draw_menu_frame(270,180,3,3)
     *   draw_jxmenu3(quit_menu^);         ->  paint_menu_items(quit_menu, quit_f)
     *   increase_palette(blackx, palx, 10);   (see note below)
     *
     * The items+title are painted ON TOP of the frame (paint_menu_items),
     * exactly as draw_jxmenu3 draws over old_frame.draw in the original. */
    cc_draw_menu_frame(270, 180, 3, 3);
    paint_menu_items(quit_menu, (int)quit_f);
    fb_expand();

    /* increase_palette(blackx, palx, 10): brightens the palette for ~10
     * frames after a menu opens (PASCAL draws it here).  NOT present in the
     * C-C engine (no real-time palette-brightening API), and the level
     * selector omits it too -- so it is intentionally skipped here to stay
     * faithful to the working C pattern.  The GLIST frame decoration itself
     * (the box border + interior fill) IS reproduced, which is the visual
     * difference the "properly decorated" request targets. */
}

void quit_confirm_step(void)
{
    unsigned short k;
    int ff;

    if (quit_done) return;

    /* Redraw ONLY the items/title on top of the GLIST frame -- NOT the whole
     * box.  The frame border + interior fill were drawn ONCE at
     * quit_confirm_init (cc_draw_menu_frame); like select_level_step we only
     * repaint the items here so the highlight can move (hi_jxmenu) without
     * erasing the frame.  Mirrors Pascal quit_confirm_step's
     * hi_jxmenu(quit_f,...) / normal_jxmenu(quit_f,...) which touch only the
     * items, never old_frame.draw. */
    paint_menu_items(quit_menu, (int)quit_f);
    fb_expand();

    k = engine_last_key();
    if (k != 0) {
        clear_key_buffer_local();

        /* navigate the 2-item menu, wrapping between Yes and No */
        if (k == 0x4800 || k == 0x4b00 || k == 0x4838 || k == 0x4b34 || k == 0x4a2d) {
            if (quit_f > 1) quit_f--;
            else if (quit_menu->pocet <= quit_menu->roll) quit_f = quit_menu->pocet;
        } else if (k == 0x5000 || k == 0x4d00 || k == 0x5032 || k == 0x4d36 || k == 0x4e2b) {
            if (quit_f < quit_menu->pocet) quit_f++;
            else if (quit_menu->pocet <= quit_menu->roll) quit_f = 1;
        }

        /* commit */
        if (k == 0x011b) {
            quit_result = 2;             /* ESC -> continue playing */
            quit_done = 1;
        } else if (k == 0x1c0d || k == 0x3920) {
            quit_result = quit_f;        /* 1=Yes(quit), 2=No(continue) */
            quit_done = 1;
        }
    }
}

/* --------------------------------------------------------------------- */
/* Accessors used by engine.c's engine_step() state machine.            */
/*                                                                     */
/* These match the names declared in siriel.h so engine.c links with    */
/* no edits.  info_ret is set by the caller (menu=10, in-game help=21)  */
/* via info_ret_set() before state 40 runs.                             */
/* --------------------------------------------------------------------- */
unsigned char select_level_done(void)  { return sl_done; }
unsigned char select_level_result(void){ return sl_result; }

unsigned char password_done(void) { return pw_done; }
unsigned char password_ok(void)   { return pw_ok || (getenv("SKIP_PW") ? 1 : 0); }

/* NOTE: the accessor is named briefing_finished() (not briefing_done())
 * because C forbids a function and a variable sharing the identifier
 * briefing_done -- the static global keeps that name. */
unsigned char briefing_finished(void)  { return briefing_done; }

unsigned char info_finished(void)   { return info_done; }
int           info_ret_get(void)    { return info_ret; }
void          info_ret_set(int v)   { info_ret = v; }

unsigned char show_hi_score_done(void) { return hs_done; }

unsigned char quit_confirm_done(void)     { return quit_done; }
unsigned char quit_confirm_result(void)   { return quit_result; }

/* --------------------------------------------------------------------- */
/* Init-once + reset accessors.  engine.c mirrors SI35.PAS: it calls the  */
/* X_init() exactly once per entry (guarded by the *_init_done() flag),   */
/* and resets the flag at each transition point so re-entering a state    */
/* re-paints the menu fresh -- exactly as the Pascal sets sl_init:=false, */
/* pw_init:=false, briefing_started:=false, info_started:=false, ...      */
/* --------------------------------------------------------------------- */
unsigned char select_level_init_done(void) { return sl_init; }
unsigned char password_init_done(void)     { return pw_init; }
unsigned char briefing_init_done(void)     { return briefing_started; }
unsigned char info_init_done(void)         { return info_started; }
unsigned char hi_score_init_done(void)     { return hs_started; }
unsigned char quit_confirm_init_done(void) { return quit_init; }

void select_level_reset(void)  { sl_init = 0; sl_done = 0; sl_result = 0; }
void password_reset(void)      { pw_init = 0; pw_done = 0; pw_ok = 0; }
void briefing_reset(void)      { briefing_started = 0; briefing_done = 0; }
void info_reset(void)          { info_started = 0; info_done = 0; scroll_done = 0; }
void hi_score_reset(void)      { hs_started = 0; hs_done = 0; }
void quit_confirm_reset(void)  { quit_init = 0; quit_done = 0; quit_result = 2; }
/* ===================================================================== */
/* Phase 9: inventory / pause overlay (MENU35.INC menu_init/menu_step)   */
/*         + item-activation [TEXT] dialog (pouzi_predmet_init/step)    */
/*                                                                     */
/* Faithful port of src/pascal/MENU35.INC.  The overlay is painted once */
/* by menu_init() and advanced per engine_step by menu_step() (the     */
/* blocking vyber_jxmenu() call is split).  The item-activation [TEXT]  */
/* dialog is the step-able pouzi_predmet(), driven by engine_step       */
/* es_state=23 via the pp_pending flag.  Text rendering uses the tiny   */
/* 5x7 font (fb_vstr_nobg, mirroring print_normal); the old_frame box   */
/* is cc_draw_menu_frame() (port of old_frame.draw).  Engine-specific   */
/* side effects (sound / palette / map transfer) are stubs per the      */
/* migration strategy ("it is OK to be not 100% correct in the         */
/* low-level functions").                                               */
/* ===================================================================== */

/* ---- MENU35.INC file-scope state (palette_speed, text_y, text_x, ...)  */
static unsigned char  m_palette_speed = 30;
static unsigned short m_text_y        = 150;
static unsigned short m_text_x        = 100;
static unsigned short m_no_line       = 32;
static unsigned char  m_automatic     = 1;
/* 'center' global -- mirrors MENU35.INC's Pascal `center` (a boolean that
   is left at its default FALSE: it is never assigned anywhere in the Pascal
   dialog code).  FALSE selects the non-center branch of the text handler,
   which advances lajn per token so multiline text is spaced on the Y axis
   (each line is still centered via pp_napis3's own opt.center=TRUE).  The
   C-C default was 1, which forced the center branch that never increments
   m_lajn, stacking every token on one line. */
static unsigned char  m_center        = 0;
static unsigned short m_pic_x         = 50;
static unsigned short m_pic_y         = 50;
static unsigned short m_lajn          = 0;
static unsigned char  m_tma           = 0;   /* 'dark' flag: C-C redraws every frame -> 0 */
static int            g_pp_dbg        = 1;   /* [PP] token trace (debug) */

/* ---- the IFPOCKET/TAKEPOCKET/... comparison counters (SETVENT..HIEVENT) */
static int g_dej[128];

/* ---- JXEFEKT.PAS TPrint (pp_napis3.opt^) + TFrame (pp_new_frame,       */
/*      pp_pic_frame) stand-ins.  The C-C engine draws the old_frame box  */
/*      via cc_draw_menu_frame() and redraws every step, so get_back/     */
/*      put_back/kill_back are no-ops.                                    */
typedef struct {
    int            px, py;
    unsigned char  text_color, shadow_color, roll_color, shadow, center;
} t_pp_option;
static t_pp_option m_pp_opt;

typedef struct {
    unsigned char  fill_color, save, killable, version;
    unsigned short size_x, size_y;
    unsigned short P1x, P1y, P2x, P2y;
} t_pp_frame;
static t_pp_frame m_pp_new_frame;
static t_pp_frame m_pp_pic_frame;

/* ---- engine side-effect stubs (sound / palette / map transfer) --- */
static void increase_palette_local(unsigned black, unsigned palx, unsigned speed)
{ (void)black; (void)palx; (void)speed; }
static void decrease_palette_local(unsigned palx, unsigned speed) { (void)palx; (void)speed; }
static void redraw_local(unsigned char b) { (void)b; }
static void redraw3_local(void) { }
static void clear_bitmap_local(void)    { cc_clear_bitmap(); }
static void set_def_local(void)         { }
static void set_font_local2(const char *s) { (void)s; }
static void play_ani_local(const char *s) { (void)s; }
static void rewait_local(void)          { }
static void write_error_local(const char *s) { (void)s; }
static void strata_zivota_local(void)   { }
static void odomkni_dvere(unsigned a, unsigned b) { (void)a; (void)b; }
static void uloz_nazov_obrazku(unsigned a, const char *z, unsigned b, unsigned c)
{ (void)a; (void)z; (void)b; (void)c; }
static void stage_image_local(unsigned b) { (void)b; }
static void go_to_new_stage_local(unsigned a, unsigned b, unsigned c)
{ (void)a; (void)b; (void)c; }
static void write_palette_local(unsigned black, unsigned count)
{ (void)black; (void)count; }
static void draw_it_local(const char *z, unsigned b, unsigned c) { (void)z;(void)b;(void)c; }
static void accomplished_local(void) { }
/* set_si / set_coords / set_ar save/restore avatar state around the full   */
/* zhasni_vec(); the C-C cc_zhasni_vec only clears the visible flag, so     */
/* these are no-ops (mirrors the {$IFDEF EXT_LOAD235} gate in MENU35.INC).  */
static void set_si_local(unsigned a, unsigned b, unsigned c, unsigned d, unsigned e)
{ (void)a;(void)b;(void)c;(void)d;(void)e; }
static void set_coords_local(unsigned a, unsigned b, unsigned c)
{ (void)a;(void)b;(void)c; }
static void set_ar_local(unsigned char *a) { (void)a; }

static void new_screen_local(void)
{
    decrease_palette_local(255, m_palette_speed);
    redraw_local(1);
    increase_palette_local(0, 255, m_palette_speed);
}
static void cls_local(void)
{
    decrease_palette_local(255, m_palette_speed);
    clear_bitmap_local();
    m_lajn = 0;
}

/* ---- TPrint methods (pp_napis3) ---- */
static void pp_napis3_init(int px, int py, unsigned char tcol, unsigned char cs,
                           unsigned char roll, unsigned char pc, unsigned char ps)
{
    m_pp_opt.px = px;   m_pp_opt.py = py;
    m_pp_opt.text_color = tcol;   m_pp_opt.shadow_color = cs;
    m_pp_opt.roll_color = roll;   m_pp_opt.center = pc;   m_pp_opt.shadow = ps;
}
static void pp_napis3_done(void) { }
static void pp_napis3_set_color(unsigned char c)  { m_pp_opt.text_color = c; }
static void pp_napis3_set_center(unsigned char b) { m_pp_opt.center = b; }
static void pp_napis3_set_shadow(unsigned char b) { m_pp_opt.shadow = b; }
static void pp_napis3_set_shadow_color(unsigned char c) { m_pp_opt.shadow_color = c; }
static void pp_napis3_print(unsigned short x, unsigned short y, const char *s)
{
    if (m_pp_opt.center)
        x = (unsigned short)((FBW / 2) - ((int)strlen(s) * CHARDX / 2));
    if (m_pp_opt.shadow)
        fb_vstr_nobg(x + m_pp_opt.px, y + m_pp_opt.py, s, m_pp_opt.shadow_color);
    fb_vstr_nobg(x + m_pp_opt.px, y + m_pp_opt.py, s, m_pp_opt.text_color);
}
static void pp_napis3_print_shad(unsigned short x, unsigned short y,
                                 const char *s, unsigned char b)
{
    unsigned char old = m_pp_opt.shadow;
    m_pp_opt.shadow = b;
    pp_napis3_print(x, y, s);
    m_pp_opt.shadow = old;
}

/* ---- TFrame methods (pp_new_frame / pp_pic_frame) ---- */
/* draw(x,y,dx,dy) == old_frame.draw == cc_draw_menu_frame(x,y,dx,dy).  */
static void pp_new_init(unsigned char used)
{
    m_pp_new_frame.fill_color = 13; m_pp_new_frame.size_x = 16;
    m_pp_new_frame.size_y = 16; m_pp_new_frame.version = 0;
    m_pp_new_frame.save = 1; m_pp_new_frame.killable = used ? 0 : 1;
}
static void pp_pic_init(unsigned char used)
{
    m_pp_pic_frame.fill_color = 13; m_pp_pic_frame.size_x = 16;
    m_pp_pic_frame.size_y = 16; m_pp_pic_frame.version = 0;
    m_pp_pic_frame.save = 1; m_pp_pic_frame.killable = used ? 0 : 1;
}
static void pp_new_set_params(void)
{ m_pp_new_frame.fill_color = 13; m_pp_new_frame.size_x = 16; m_pp_new_frame.size_y = 16; }
static void pp_pic_set_params(void)
{ m_pp_pic_frame.fill_color = 13; m_pp_pic_frame.size_x = 16; m_pp_pic_frame.size_y = 16; }
static void pp_new_draw(unsigned short x, unsigned short y,
                        unsigned short dx, unsigned short dy)
{
    m_pp_new_frame.P1x = x; m_pp_new_frame.P1y = y;
    m_pp_new_frame.P2x = dx + 2; m_pp_new_frame.P2y = dy + 2;
    cc_draw_menu_frame((int)x, (int)y, (int)dx, (int)dy);
}
static void pp_pic_draw(unsigned short x, unsigned short y,
                        unsigned short dx, unsigned short dy)
{
    m_pp_pic_frame.P1x = x; m_pp_pic_frame.P1y = y;
    m_pp_pic_frame.P2x = dx + 2; m_pp_pic_frame.P2y = dy + 2;
    cc_draw_menu_frame((int)x, (int)y, (int)dx, (int)dy);
}
static void pp_new_get_back(void)  { }
static void pp_new_put_back(void)  { }
static void pp_new_kill_back(void) { }
static void pp_new_done(void)      { }
static void pp_pic_get_back(void)  { }
static void pp_pic_put_back(void)  { }
static void pp_pic_kill_back(void) { }
static void pp_pic_done(void)      { }

/* ---- jxmenu primitives used by the overlay: vloz_jxmenu (explicit x,y)  */
/*      hi_jxmenu / normal_jxmenu draw a single item (the highlight moves). */
/*      draw_jxmenu3 paints the title + all items (no highlight) -- the     */
/*      same ordering as old_frame.draw then draw_jxmenu3 in MENU35.INC.    */
static void vloz_jxmenu(unsigned short x, unsigned short y,
                        const char *meno, t_jxmenu_typ *m, unsigned short k)
{
    char item[80];
    int n = 0;
    const char *p = meno;
    (void)k;
    if (m->pocet < 64) {
        m->pocet++;
        item[n++] = ' ';
        while (*p && n < (int)sizeof(item) - 2) item[n++] = *p++;
        item[n++] = ' ';
        item[n] = '\0';
        m->dat[m->pocet].x = x;
        m->dat[m->pocet].y = y;
        strncpy(m->dat[m->pocet].meno, item, sizeof(m->dat[m->pocet].meno) - 1);
        m->dat[m->pocet].meno[sizeof(m->dat[m->pocet].meno) - 1] = '\0';
        m->dat[m->pocet].k = k;
    }
}
static void hi_jxmenu(unsigned short f, t_jxmenu_typ *m)
{ if (f >= 1 && f <= m->pocet) draw_menu_item(m, (int)f, 1); }
static void normal_jxmenu(unsigned short f, t_jxmenu_typ *m)
{ if (f >= 1 && f <= m->pocet) draw_menu_item(m, (int)f, 0); }
static void draw_jxmenu3(t_jxmenu_typ *m)
{ paint_menu_items(m, 0); }

/* ---- plain-C GEO.PAS string extractors (mov_command up to ';',         */
/*      mov_part up to '/', mov_part_num = mov_part + val, is_command).   */
/*      These mirror the validated spike ports but operate on plain        */
/*      null-terminated C strings (pp_s / scratch buffers).               */
static void mov_command_c(const char *src, char *dst, int dstsz, unsigned short *poradie)
{
    unsigned short len = (unsigned short)strlen(src);
    unsigned short p = *poradie;
    int n = 0;
    if (p <= len) {
        for (;;) {
            if (src[p-1] != ';') {
                if (n < dstsz-1) dst[n] = src[p-1];
                n++; p++;
            }
            if (p > len) break;
            if (src[p-1] == ';') break;
        }
        p++;
    }
    dst[n < dstsz ? n : dstsz-1] = '\0';
    *poradie = p;
}
static void mov_part_c(const char *src, char *dst, int dstsz, unsigned short *poradie)
{
    unsigned short len = (unsigned short)strlen(src);
    unsigned short p = *poradie;
    int n = 0;
    if (p <= len) {
        for (;;) {
            if (src[p-1] != '/') {
                if (n < dstsz-1) dst[n] = src[p-1];
                n++; p++;
            }
            if (p > len) break;
            if (src[p-1] == '/') break;
        }
        p++;
    }
    dst[n < dstsz ? n : dstsz-1] = '\0';
    *poradie = p;
}
static void mov_part_num_c(const char *src, unsigned short *out, unsigned short *poradie)
{
    char row[256];
    long lv = 0;
    mov_part_c(src, row, sizeof(row), poradie);
    val(row, &lv);
    *out = (unsigned short)(unsigned)lv;
}
/* is_command: true when the token is a <meta> (<...>) or #command; when    */
/* true and the first char is not '#', the token is trimmed (see below).   */
/* dst receives the trimmed token.                                         */
/*                                                                         */
/* FAITHFUL to the Pascal aliasing. is_command is called as is_command(sx, */
/* sx): the guard `if zdroj[1]<>'#' then ciel[0]:=chr(length(ciel)-1)`      */
/* rewrites the string's OWN length byte BEFORE out_string(zdroj) runs,    */
/* so out_string reads the SHORTENED length and drops the trailing '>'     */
/* too.  Net effect (verified byte-for-byte):                              */
/*     <END>     -> END        <SCORE/50>  -> SCORE/50                     */
/*     <CLS>     -> CLS        <PIC/22/0/0> -> PIC/22/0/0                  */
/* A bare #command only has its leading '#' stripped (no length rewrite).  */
static int is_command_c(const char *src, char *dst, int dstsz)
{
    unsigned short len = (unsigned short)strlen(src);
    int iscmd = 0;
    if ((len > 2 && src[0] == '<' && src[len-1] == '>') || src[0] == '#')
        iscmd = 1;
    if (iscmd && src[0] != '#') {
        /* <...> meta: drop BOTH the leading '<' and the trailing '>'
           (the Pascal length-rewrite makes out_string drop the last
           char too).  Copy src[1 .. len-2]. */
        int i = 0, n = 0;
        for (i = 1; i + 1 < (int)len && n < dstsz - 1; i++) dst[n++] = src[i];
        dst[n] = '\0';
    } else if (iscmd && src[0] == '#') {
        /* # meta: drop only the leading '#' (no length rewrite). */
        int i = 0, n = 0;
        for (i = 1; src[i] && n < dstsz - 1; i++) dst[n++] = src[i];
        dst[n] = '\0';
    } else {
        strncpy(dst, src, dstsz - 1);
        dst[dstsz-1] = '\0';
    }
    return iscmd;
}

/* ---- vrat_nazov(f) -- object-name lookup.                               */
/* Reads the pickable item name from the [VEC] name table (handles[3],       */
/* mirrored in load235.c g_nazov[] via uloz_nazov_c).  Keyed on the object's  */
/* cislo -- exactly as MENU35.INC displays it: vrat_nazov(vec^[own[f]].cislo).*/
/* The old object-array search (copying 5 chars from the decoded keyword) is  */
/* gone: it could never know the language-selected name, so it fell back to  */
/* showing the [W...] keyword instead of the item name.  The [TEXT] script   */
/* table lives in load235.c (vrat_text).                                    */
static void vrat_nazov(unsigned short cislo, char *dst, int sz)
{
    const char *nm;
    if (sz <= 0) { dst[0] = '\0'; return; }
    nm = vatr_nazov_c(cislo);
    strncpy(dst, nm, sz - 1);
    dst[sz - 1] = '\0';
}

/* ===================================================================== */
/* pouzi_predmet_init -- item-activation / level-start [TEXT] dialog.     */
/* Faithful port of MENU35.INC pouzi_predmet_init.                        */
/* ===================================================================== */
unsigned char pouzi_predmet_init(unsigned short num, unsigned char typ)
{
    unsigned short f, ff;
    pp_done      = 0;
    pp_started   = 1;
    pp_wait_mode = 0;
    pp_jump      = 0;
    pp_return    = 1;
    pp_breaker   = 0;
    pp_close     = 0;
    m_lajn       = 0;
    /* text-frame setup */
    pp_napis3_init(2, 2, 15, 0, 0, 1, 0);
    pp_new_init(1);
    pp_new_set_params();
    pp_pic_init(1);
    pp_pic_set_params();
    /* typ: swap in the pointed-at object index, mirror the original */
    if (typ) {
        pp_z = cc_own((int)num);
        cc_set_own((int)num, 0);
        num = pp_z;
    }
    /* funk side-effects for a direct object use */
    if (typ) {
        switch (g_vec[num].funk) {
        case 1:
            for (f = 1; f <= g_nahrane_veci; f++)
                /* MENU35.INC:130 compares vec^[f].mie = vec^[num].INF1
                   (the USED item's inf1 selects which layer's objects to
                   reveal), NOT vec^[num].MIE.  The key [WNNŠ] has inf1=66
                   but mie=128 (c[3]=0x80), so comparing against MIE never
                   matched the [YNNB] door (mie=66) that the key is meant to
                   reveal into the current room. */
                if (g_vec[f].mie == g_vec[num].inf1) {
                    g_vec[f].mie = g_miestnost;
                    cc_reprint_predmet();
                }
            new_screen_local();
            break;
        case 2:
            for (f = g_vec[num].inf1; f <= g_vec[num].inf3; f++)
                for (ff = g_vec[num].inf2; ff <= g_vec[num].inf4; ff++)
                    st.mie[f][ff] = g_vec[num].inf5;
            break;
        case 4:
            st.mie[g_vec[num].inf1][g_vec[num].inf2] = g_vec[num].inf3;
            odomkni_dvere(g_vec[num].inf1, g_vec[num].inf2);
            break;
        }
    }
    /* which text buffer to show */
    if ((g_cfg.start_action != 0) || (g_vec[num].inf7 > 0)) {
        /* Full-screen black background -- the item-activation / level-start
           [TEXT] dialog is shown "in regular fashion" like the briefing /
           intro message: wipe the frozen scene to black, then layer the
           centered text on top.  Without this the text is painted over the
           live playfield (the reported "text in the middle of the screen"
           bug).  The clear happens here (once, before the first
           pouzi_predmet_step draws the first line); state 23 never calls
           draw_state(), so the black persists while the dialog steps. */
        clear_bitmap_local();
        if (m_automatic) {
            m_palette_speed = 30; m_text_y = 150; m_no_line = 32;
            m_automatic = 1; m_text_x = 100; m_pic_x = 50; m_pic_y = 50;
        }
        pp_xx = (g_cfg.start_action == 0) ? g_vec[num].inf7 : g_cfg.start_action;
        g_cfg.start_action = 0;
        pp_count = 1;
        vrat_text(pp_xx, pp_s, sizeof(pp_s));
    } else {
        /* no comment text -> the dialog is immediately done */
        pp_done = 1;
        pp_napis3_done();
        pp_new_done();
        pp_pic_done();
        rewait_local();
    }
    pp_num = num;
    if (g_pp_dbg) fprintf(stderr, "[PP-INIT] num=%d start_action=%d inf7=%d -> pp_done=%d\n", num, g_cfg.start_action, g_vec[num].inf7, pp_done);
    return 1;
}

/* ===================================================================== */
/* pouzi_predmet_step -- one command/text token per engine_step.          */
/* Faithful port of MENU35.INC pouzi_predmet_step.                        */
/* ===================================================================== */
void pouzi_predmet_step(void)
{
    unsigned short k, por, cis, f, ff, wa, wb, wc, wd, we;
    char sx[80], sc[80], zal[80];
    long a, b, c, d, e, v;
    int found;
    static const char *prikazy[74] = {
        NULL,   /* index 0 unused */
        "SOUND","ANIM","CLS","SCROFF","SCRON","REDRAW","ANIMONLY",
        "DRAWINTRO","KEY","SETDEF","AUTODEF","TEXT_Y","NO_LINE",
        "TEXTCOL","REINIT","P","TEXT_X","CENTER","STAGE",
        "SHOWSIR","SHOWCHAT","SETPIC","NEWSCR","PIC","UNHIDE",
        "SCORE","END","GOTO","SETNEW","RESET","SETOTNEW",
        "NEWTEX","LOADMAP","SAVEMAP","SIRXY","HIDE","GOMAP",
        "IFPOCKET","TAKEPOCKET","GIVEPOCKET","SETEVENT",
        "INCEVENT","DECEVENT","IFEVENT","LOEVENT","HIEVENT",
        "DONTUSE","USE","DRAWGIF","THEEND","LOSELIFE","GAINLIFE",
        "FONT","DEFFONT","SETBACKGIF","DRAWGIFNUM","SCAN",
        "SETWAY","SETLIFT","SPEEDLIFT","WAYLIFT","SETANIM",
        "SETOBR","PULZX","FASTDRAW","SETFREEZ","SETGOD",
        "SHADOW","SHADOWCOL","FRAME","FRAME2","FRAMEPIC",
        "REINIT2"
    };

    if (pp_done) return;

    /* waiting to close: the [TEXT] script has finished, so the dialog now
       waits for Enter / Space / ESC before returning to gameplay.  A
       key-RELEASE word has bit 15 set and carries no character, so it is
       ignored -- only a fresh key-DOWN dismisses the dialog. This is what
       stops the item-activation screen from closing the instant it opens. */
    if (pp_close) {
        k = engine_last_key();
        if ((k != 0) && ((k & 0x8000) == 0)) {
            clear_key_buffer_local();
            if ((k == 0x1c0d) || (k == 0x011b) || (k == 0x3920)) {
                pp_close = 0;
                pp_done  = 1;
                pp_napis3_done(); pp_new_done(); pp_pic_done(); rewait_local();
            }
        }
        return;
    }

    /* waiting state: a KEY command (9/15/23/73) or a PULZX (64) */
    if (pp_wait_mode == 1) {
        k = engine_last_key();
        if (k == 0) return;
        clear_key_buffer_local();
        pp_wait_mode = 0;
        switch (pp_wait_cmd) {
        case 15: pp_new_kill_back(); pp_pic_kill_back(); new_screen_local(); break;
        case 23: cls_local(); break;
        case 73: pp_new_put_back(); pp_pic_put_back(); break;
        }
        return;
    } else if (pp_wait_mode == 2) {
        if (--pp_wait_left != 0) return;
        pp_wait_mode = 0;
        return;
    }

    /* line exhausted (or a conditional jump requested): next buffer */
    if ((pp_count >= (unsigned short)strlen(pp_s)) || (pp_s[0] == '\0') || (pp_jump > 0)) {
        if (pp_jump > 0) { pp_xx++; pp_jump = 0; }
        pp_xx++;
        vrat_text(pp_xx, pp_s, sizeof(pp_s));
        pp_count = 1;
        if ((pp_xx > 255) || (pp_s[0] == '\0')) {
            pp_close = 1;
            return;
        }
    }

    /* process exactly one token (command or text) */
    por = 1;
    mov_command_c(pp_s, sx, sizeof(sx), &pp_count);

    if (g_pp_dbg) fprintf(stderr, "[PP] tok='%s' cnt=%d breaker=%d done=%d close=%d lajn=%d cx=%d cy=%d\n", sx, pp_count, pp_breaker, pp_done, pp_close, m_lajn, m_text_x, (int)(m_text_y + m_lajn*m_no_line));

    if (is_command_c(sx, sx, sizeof(sx))) {
        mov_part_c(sx, sc, sizeof(sc), &por);
        found = 0;
        for (cis = 1; cis <= 73; cis++) {
            if (strcmp(prikazy[cis], sc) == 0) {
                found = 1;
                mov_part_c(sx, sc, sizeof(sc), &por);
                switch (cis) {
                case 1: reload_sound(3, g_cfg.zvukovy_subor, 3); pust(3); break;
                case 2: { char ani[160]; snprintf(ani, sizeof(ani),">%s", sc); play_ani_local(ani); write_palette_local(0,256); redraw_local(1);
                        increase_palette_local(0, 255, m_palette_speed); m_tma = 1; break; }
                case 3: cls_local(); break;
                case 4: decrease_palette_local(255, m_palette_speed); break;
                case 5: increase_palette_local(0, 255, m_palette_speed); break;
                case 6: redraw_local(1); break;
                case 7: { char ani[160]; snprintf(ani, sizeof(ani),">%s", sc); play_ani_local(ani); write_palette_local(0,256); m_tma = 1; break; }
                case 8: /* draw_scr(handles[1],...) -> single framebuffer, no-op */ break;
                case 9: pp_wait_mode = 1; pp_wait_cmd = 9; return;
                case 10: set_def_local(); break;
                case 11: { val(sc, &v); m_automatic = (v != 0); break; }
                case 12: val(sc, &v);  m_text_y = (unsigned short)v; break;
                case 13: val(sc, &v);  m_no_line = (unsigned short)v; break;
                case 14: { val(sc, &v); pp_napis3_set_color((unsigned char)v); break; }
                case 15: increase_palette_local(0, 255, m_palette_speed);
                         pp_wait_mode = 1; pp_wait_cmd = 15; return;
                case 16: m_lajn++; if (!m_center) m_text_x = 100; break;
                case 17: val(sc, &v); m_text_x = (unsigned short)v; break;
                case 18: { val(sc, &v); pp_napis3_set_center((unsigned char)v); break; }
                case 19: val(sc, &a); mov_part_num_c(sx, &wa, &por);
                         mov_part_num_c(sx, &wb, &por);
                         go_to_new_stage_local((unsigned)a, (unsigned)wa, (unsigned)wb); break;
                case 20: cc_put_char_cell(m_pic_x, m_pic_y, 0, 13); break;
                case 21: cc_put_obj_sprite(m_pic_x, m_pic_y, g_vec[pp_num].obr, 13); break;
                case 22: val(sc, &v); m_pic_x = (unsigned short)v;
                         mov_part_num_c(sx, &m_pic_y, &por);
                         m_pic_y = (unsigned short)m_pic_y; break;
                case 23: increase_palette_local(0, 255, m_palette_speed);
                         pp_wait_mode = 1; pp_wait_cmd = 23; return;
                case 24: val(sc, &v); mov_part_num_c(sx, &wa, &por);
                         mov_part_num_c(sx, &wb, &por);
                         if (wa > 0 && wb > 0) cc_put_obj_sprite(wa, wb, (unsigned short)v, 13);
                         else cc_put_obj_sprite(m_text_x, m_text_y + m_lajn*m_no_line, (unsigned short)v, 13);
                         break;
                case 25: val(sc, &a); mov_part_c(sx, sc, sizeof(sc), &por);
                         { unsigned char sc1 = (unsigned char)sc[0];
                           if (a > 1) a += 126;
                           for (f = 1; f <= g_nahrane_veci; f++)
                               if (g_vec[f].mie == (unsigned short)sc1)
                                   g_vec[f].mie = (unsigned short)a; }
                         break;
                case 26: val(sc, &a); break;   /* SCORE: not exposed, no-op */
                case 27: pp_breaker = 1; break;
                case 28: val(sc, &a); pp_xx = (unsigned short)(a - 1); break;
                case 29: val(sc, &a); g_vec[pp_num].inf7 = (unsigned short)a; break;
                case 30: val(sc, &a); g_vec[pp_num].inf7 = (unsigned short)a; pp_xx = (unsigned short)(a-1); break;
                case 31: val(sc, &a); mov_part_c(sx, sc, sizeof(sc), &por);
                         for (f = 1; f <= g_nahrane_veci; f++)
                             if (g_vec[f].c[4] == sc[0]) g_vec[f].inf7 = (unsigned short)a;
                         break;
                case 32: val(sc, &a); mov_part_num_c(sx, &wa, &por);
                         mov_part_num_c(sx, &wb, &por);
                         mov_part_num_c(sx, &wc, &por); mov_part_num_c(sx, &wd, &por);
                         for (f = (unsigned)a; f <= (unsigned)(wc+a); f++)
                             for (ff = (unsigned)wb; ff <= (unsigned)(wb+wd); ff++)
                                 st.mie[f][ff] = (unsigned short)wd;
                         break;
                case 33: val(sc, &a); load_map((unsigned char)a); save_map((unsigned char)g_miestnost); break;
                case 34: val(sc, &a); save_map((unsigned char)a); break;
                case 35: { /* SIRXY -- reposition Seriel: si.x:=a*8+8; si.y:=b*8+8 */
                           val(sc, &a); mov_part_num_c(sx, &wa, &por);
                           cc_set_si((unsigned short)(a * 8 + 8), (unsigned short)(wa * 8 + 8));
                           break; }
                case 36: val(sc, &a); mov_part_c(sx, sc, sizeof(sc), &por);
                         for (f = 1; f <= g_nahrane_veci; f++)
                             if (g_vec[f].c[4] == sc[0]) { g_vec[f].mie = (unsigned short)a; g_vec[f].c[3] = (char)a; }
                         break;
                case 37: /* GOMAP -- switch current room (no avatar move) */
                          val(sc, &a); cc_gomap((unsigned char)a); break;
                case 38: val(sc, &a); mov_part_num_c(sx, &wa, &por);
                         for (f = 1; f <= 3; f++)
                             if (g_vec[cc_own(f)].cislo == (unsigned short)a) { pp_xx = (unsigned short)(wa-1); pp_jump = 1; }
                         break;
                case 39: val(sc, &a); mov_part_num_c(sx, &wa, &por);
                         for (f = 1; f <= 3; f++)
                             if (g_vec[cc_own(f)].cislo == (unsigned short)a) { g_vec[cc_own(f)].mie = (unsigned short)wa; cc_set_own(f, 0); pp_jump = 1; }
                         break;
                case 40: { int sys = 0; val(sc, &a);
                           for (f = 1; f <= 3; f++)
                               if (cc_own(f) == 0) { sys = 1;
                                   for (ff = 1; ff <= g_nahrane_veci; ff++)
                                       if (g_vec[ff].cislo == (unsigned short)a) { g_vec[ff].mie = 2; cc_set_own(f, (unsigned char)ff); break; }
                                   break; }
                           if (!sys) { for (ff = 1; ff <= g_nahrane_veci; ff++)
                                       if (g_vec[ff].cislo == (unsigned short)a) {
                                           unsigned short tx, ty;
                                           tx = g_vec[ff].x; ty = g_vec[ff].y;
                                           cc_get_si(&tx, &ty);
                                           g_vec[ff].mie = g_miestnost;
                                           g_vec[ff].x = tx; g_vec[ff].y = ty;
                                           g_vec[ff].ox = tx; g_vec[ff].oy = ty;
                                           break; } }
                           break; }
                case 41: val(sc, &a); mov_part_num_c(sx, &wa, &por); g_dej[(int)a] = (int)wa; break;
                case 42: val(sc, &a); g_dej[(int)a]++; break;
                case 43: val(sc, &a); g_dej[(int)a]--; break;
                case 44: val(sc, &a); mov_part_num_c(sx, &wa, &por); mov_part_num_c(sx, &wb, &por);
                         if (g_dej[(int)a] == (int)wa) { pp_xx = (unsigned short)(wb-1); pp_jump = 1; }
                         break;
                case 45: val(sc, &a); mov_part_num_c(sx, &wa, &por); mov_part_num_c(sx, &wb, &por);
                         if (g_dej[(int)a] < (int)wa) { pp_xx = (unsigned short)(wb-1); pp_jump = 1; }
                         break;
                case 46: val(sc, &a); mov_part_num_c(sx, &wa, &por); mov_part_num_c(sx, &wb, &por);
                         if (g_dej[(int)a] > (int)wa) { pp_xx = (unsigned short)(wb-1); pp_jump = 1; }
                         break;
                case 47: pp_return = 0; break;
                case 48: pp_return = 1; break;
                case 49: mov_part_num_c(sx, &wa, &por); mov_part_num_c(sx, &wb, &por);
                         draw_it_local(sc, (unsigned)wa, (unsigned)wb); break;
                case 50: accomplished_local(); break;
                case 51: strata_zivota_local(); break;
                case 52: val(sc, &b); break;
                case 53: set_font_local2(sc); break;
                case 54: set_font_local2(g_cfg.font); break;
                case 55: mov_part_num_c(sx, &wa, &por); mov_part_c(sx, zal, sizeof(zal), &por);
                         mov_part_num_c(sx, &wb, &por); mov_part_num_c(sx, &wc, &por);
                         uloz_nazov_obrazku((unsigned)wa, zal, (unsigned)wb, (unsigned)wc); break;
                case 56: val(sc, &b); stage_image_local((unsigned)b); break;
                case 57: val(sc, &a); g_cfg.scan_x1 = (unsigned char)a;
                         mov_part_num_c(sx, &wa, &por); g_cfg.scan_x2 = (unsigned char)wa;
                         mov_part_num_c(sx, &wa, &por); g_cfg.scan_y1 = (unsigned char)wa;
                         mov_part_num_c(sx, &wa, &por); g_cfg.scan_y2 = (unsigned char)wa; break;
                case 58: val(sc, &a); mov_part_c(sx, sc, sizeof(sc), &por); break;
                case 59: val(sc, &a); mov_part_c(sx, sc, sizeof(sc), &por); break;
                case 60: val(sc, &a); mov_part_num_c(sx, &wa, &por); break;
                case 61: val(sc, &a); mov_part_num_c(sx, &wa, &por); break;
                case 62: mov_part_c(sx, zal, sizeof(zal), &por);
                         for (f = 1; f <= g_nahrane_veci; f++)
                             if (g_vec[f].c[4] == zal[0]) { if (zal[0]=='Y'||zal[0]=='y') g_vec[f].c[1]='A'; else g_vec[f].c[1]='N'; }
                         break;
                case 63: mov_part_num_c(sx, &wa, &por);
                         for (f = 1; f <= g_nahrane_veci; f++)
                             if (g_vec[f].c[4] == (char)wa) { g_vec[f].obr = (unsigned short)wa;
                                 if (!m_tma) { set_si_local(0,0,0,0,0); set_coords_local(0,0,0); set_ar_local(NULL); cc_zhasni_vec(&g_vec[f]); cc_reprint_predmet(); } }
                         break;
                case 64: pp_wait_mode = 2; pp_wait_left = 2; return;
                case 65: decrease_palette_local(255, 1); redraw3_local(); increase_palette_local(0, 255, 1); break;
                case 66: val(sc, &a); break;
                case 67: val(sc, &a); break;
                case 68: { val(sc, &v); pp_napis3_set_shadow((unsigned char)v); break; }
                case 69: { val(sc, &v); pp_napis3_set_shadow_color((unsigned char)v); break; }
                case 70: val(sc, &a); mov_part_num_c(sx, &wa, &por); mov_part_num_c(sx, &wb, &por); mov_part_num_c(sx, &wc, &por);
                         cc_draw_menu_frame((int)a, (int)wa, (int)wb, (int)wc); break;
                case 71: m_text_x = 110; m_text_y = 110; pp_new_draw(100,100,25,15);
                         pp_napis3_print_shad(m_text_x, m_text_y, sc, 1); m_text_y = (unsigned short)(m_text_y + CHARDY*2); m_no_line = CHARDY; break;
                case 72: pp_pic_draw(35,35,1,1); val(sc, &a); cc_put_obj_sprite(50,50,(unsigned short)a,13); break;
                case 73: pp_wait_mode = 1; pp_wait_cmd = 73; return;
                }
                break;   /* one command per token */
            }
        }
        if (!found) write_error_local(sx);
    } else {
        /* plain text token */
        if (m_center) {
            if (sx[0]) pp_napis3_print(m_text_x, m_text_y + m_lajn*m_no_line, sx);
        } else {
            pp_napis3_print(m_text_x, m_text_y + m_lajn*m_no_line, sx);
            m_text_x = 100;
            m_lajn++;
        }
    }

    if (g_pp_dbg) fprintf(stderr, "[PP] after-switch: sx='%s' breaker=%d\n", sx, pp_breaker);
    /* END command finished the script */
    if (pp_breaker) { pp_close = 1; return; }
}

/* TEST HOOK: drive the pouzi_predmet [TEXT] dialog directly. Loads buffer
   xx, then runs `steps` pouzi_predmet_step() calls. The token trace above
   (g_pp_dbg) shows each token + pp_breaker/pp_done/pp_close/m_lajn so the
   END-stops / multiline-spacing behaviour can be observed. */
int g_pp_key_step = -1;   /* TEST HOOK: inject Enter at this step (0-based) */

void cc_pp_probe(unsigned short xx, int steps)
{
    fprintf(stderr, "[PP-PROBE] start buffer=%d steps=%d key_step=%d\n", xx, steps, g_pp_key_step);
    pp_num = 1;
    pp_z   = 0;
    pp_return = pouzi_predmet_init(xx, 0);
    int i;
    for (i = 0; i < steps; i++) {
        unsigned char before = pp_done;
        if (g_pp_key_step >= 0 && i == g_pp_key_step) cc_pp_set_key(0x0d);   /* Enter */
        pouzi_predmet_step();
        if (!before && pp_done) { fprintf(stderr, "[PP-PROBE] dialog done at step %d\n", i); break; }
    }
    fprintf(stderr, "[PP-PROBE] end: done=%d close=%d breaker=%d lajn=%d xx=%d\n",
            pp_done, pp_close, pp_breaker, m_lajn, pp_xx);
}

/* Faithful port of MENU35.INC menu_init.                                 */
/* ===================================================================== */
static t_jxmenu_typ *g_inv_menu = NULL;   /* the overlay table (new/dispose) */

void menu_init(void)
{
    unsigned short f;
    unsigned char status, zobral;
    char name[80];

    /* reset overlay state for this entry */
    inv_init      = 0;
    inv_done      = 0;
    inv_result    = 0;
    inv_direct_done = 0;
    inv_f         = 1;

    /* Direct-use paths: no inventory overlay required.  A direct-use 'V'
       object may still carry a comment ([TEXT]); show it via the step-able
       dialog (pp_pending) driven by engine_step, instead of blocking here. */
    if (g_mov > 0 && g_vec[g_mov].c[0] == 'V') {
        pp_num = g_mov;
        pp_z   = 0;
        pp_return = pouzi_predmet_init(g_mov, 0);
        pp_pending = 1;
        return;
    } else if (g_mov > 0 && g_vec[g_mov].c[0] != 'W') {
        /* Direct-use object (name first letter <> 'W' and <> 'V'): the Pascal
           menu_init() runs use_vec(mov) HERE to apply the object's effect
           immediately (a teleport moves the avatar, a door finishes the level,
           a mechanism reveals/hides something, an add-life object adds a life).
           cc_use_vec() is the faithful port of that LOAD235.PAS use_vec(). */
        cc_use_vec(g_mov);
        inv_direct_done = 1;
        return;
    }

    /* --- Inventory overlay: paint it once --- */
    menu_x = 4;
    status = 0;
    zobral = 0;
    if (!g_inv_menu) g_inv_menu = calloc(1, sizeof(*g_inv_menu));
    init_jxmenu(200, 170, 0, 15, 0, TX(g_ja, 25), g_inv_menu);
    size_jxmenu(249, 149, g_inv_menu);
    first_jxmenu(4, g_inv_menu);
    if (g_mov > 0) {
        /* place the pointed-at object into the inventory */
        for (f = 1; f <= 3; f++) {
            if (cc_own((int)f) == 0) {
                cc_set_own((int)f, (unsigned char)g_mov);
                g_vec[g_mov].mie = 2;
                cc_zhasni_vec(&g_vec[g_mov]);
                status = 1;
                break;
            }
        }
        if (!status) {
            cc_zhasni_vec(&g_vec[g_mov]);
            g_vec[g_mov].mie = 2;
            { unsigned short tx, ty; tx = g_vec[cc_own(1)].x; ty = g_vec[cc_own(1)].y;
              cc_get_si(&tx, &ty);
              g_vec[cc_own(1)].x = tx; g_vec[cc_own(1)].y = ty;
              g_vec[cc_own(1)].ox = tx; g_vec[cc_own(1)].oy = ty;
              g_vec[cc_own(1)].mie = g_miestnost; }
            cc_set_own(1, cc_own(2)); cc_set_own(2, cc_own(3)); cc_set_own(3, (unsigned char)g_mov);
            cc_reprint_predmet();
        }
        zobral = 1;
    }

    /* save_scr(handles[2],200,170,256,160) -- single framebuffer, no-op */
    for (f = 1; f <= 3; f++) {
        if (cc_own((int)f) == 0)
            vloz_jxmenu(260, f*30+170, TX(g_ja, 26), g_inv_menu, 0);
        else {
            vrat_nazov(g_vec[cc_own((int)f)].cislo, name, sizeof(name));
            vloz_jxmenu(260, f*30+170, name, g_inv_menu, 0);
        }
    }
    vloz_jxmenu(260, 290, TX(g_ja, 22), g_inv_menu, 0);   /* Return */
    cc_draw_menu_frame(200, 170, 14, 8);                /* old_frame.draw */
    draw_jxmenu3(g_inv_menu);
    for (f = 1; f <= 3; f++) {
        if (cc_own((int)f) == 0)
            cc_put_char_cell(g_inv_menu->dat[f].x - 30, g_inv_menu->dat[f].y, 45, 13);
        else
            cc_put_obj_sprite(g_inv_menu->dat[f].x - 30, g_inv_menu->dat[f].y, g_vec[cc_own((int)f)].obr, 13);
    }
    cc_put_char_cell(g_inv_menu->dat[4].x - 30, g_inv_menu->dat[4].y, 44, 13);
    cc_draw_inventar();
    if (!zobral) first_jxmenu(1, g_inv_menu);

    inv_f = g_inv_menu->first;
    inv_init = 1;
    fb_expand();
}

/* ===================================================================== */
/* menu_step -- one menu tick: read a key, advance the cursor, commit.    */
/* Faithful port of MENU35.INC menu_step.                                 */
/* ===================================================================== */
void menu_step(void)
{
    unsigned short k, ff, u;
    unsigned char tester;

    if (inv_done) return;
    if (!g_inv_menu) return;

    /* hi_jxmenu(inv_f, ...) -- re-highlight the current selection */
    hi_jxmenu(inv_f, g_inv_menu);
    fb_expand();

    k = engine_last_key();
    if (k == 0) return;
    clear_key_buffer_local();
    /* normal_jxmenu(inv_f, ...) -- unhighlight the old selection */
    normal_jxmenu(inv_f, g_inv_menu);

    /* navigate up/down, wrapping when the menu is short */
    if (k == 0x4800 || k == 0x4b00 || k == 0x4838 || k == 0x4b34 || k == 0x4a2d) {
        if (inv_f > 1) inv_f--;
        else if (g_inv_menu->pocet <= g_inv_menu->roll) inv_f = g_inv_menu->pocet;
    } else if (k == 0x5000 || k == 0x4d00 || k == 0x5032 || k == 0x4d36 || k == 0x4e2b) {
        if (inv_f < g_inv_menu->pocet) inv_f++;
        else if (g_inv_menu->pocet <= g_inv_menu->roll) inv_f = 1;
    }

    /* a hotkey on a menu item jumps straight to it */
    for (ff = 1; ff <= g_inv_menu->pocet; ff++)
        if (k == g_inv_menu->dat[ff].k) inv_f = (unsigned short)ff;

    /* commit on Enter / Space / ESC */
    if ((k == 0x1c0d) || (k == 0x3920)) {
        inv_result = inv_f;
        inv_done = 1;
    } else if (k == 0x011b) {
        inv_result = 0;
        inv_done = 1;
    }

    if (!inv_done) return;

    /* --- selection committed: mirror the original menu() handling --- */
    /* draw_scr(handles[2],200,170,256,160); kill_handle(handles[2]); */
    if (inv_result > 0 && inv_result < 4 && cc_own(inv_result) != 0) {
        unsigned short idx = cc_own(inv_result);
        /* AKTIV35.PAS px=4 / py=2: the object is placed next to the avatar
           at (si.x+px, si.y+py) -- the SAME screen space as the object's
           activation zone (x1,y1,x2,y2).  Without the px/py offset the
           placement check (x>x1 && x<x2 ...) never matched, so an object
           could not be applied at its receptive area. */
        int px, py;
        cc_get_pxpy(&px, &py);
        /* place the selected item at the player, then use it */
        { unsigned short tx, ty; tx = g_vec[idx].x; ty = g_vec[idx].y;
          cc_get_si(&tx, &ty);
          tx = (unsigned short)((int)tx + px);
          ty = (unsigned short)((int)ty + py);
          g_vec[idx].x = tx; g_vec[idx].y = ty;
          g_vec[idx].ox = tx; g_vec[idx].oy = ty; }
        if ((g_vec[idx].x > g_vec[idx].x1) && (g_vec[idx].y > g_vec[idx].y1) &&
            (g_vec[idx].x < g_vec[idx].x2) && (g_vec[idx].y < g_vec[idx].y2) &&
            (g_vec[idx].st == g_miestnost)) {
            /* item activation: run the [TEXT] dialog step-by-step via
               engine_step (es_state=23) instead of blocking here. */
            pp_return = pouzi_predmet_init(inv_result, 1);
            pp_pending = 1;
        } else {
            /* not at the item's activation zone: drop it back */
            tester = 0;
            for (u = 1; u <= 3; u++) if (cc_own((int)u) == 0) tester = 1;
            cc_zisti_vec();
            if (g_mov == 0) tester = 1;
            if (tester) {
                g_vec[cc_own(inv_result)].mie = g_miestnost;
                cc_set_own(inv_result, 0);
            } else
                cc_zhasni_vec(&g_vec[g_mov]);
        }
        /* shift inventory items down after a possible consumption */
        if (cc_own(1) == 0 && cc_own(2) != 0) { cc_set_own(1, cc_own(2)); cc_set_own(2, 0); }
        if (cc_own(2) == 0 && cc_own(3) != 0) { cc_set_own(2, cc_own(3)); cc_set_own(3, 0); }
        /* redraw the scene under the overlay */
        if (!m_tma) {
            cc_reprint_predmet();
            cc_draw_inventar();
        } else {
            redraw_local(1);
            increase_palette_local(0, 255, 10);
        }
    }
}
