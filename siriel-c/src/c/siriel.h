/* =====================================================================
 * siriel.h  -  shared C state for the pure C-C Siriel 3.5 engine core.
 *
 * This header owns the Pascal-record-matching data structures and the
 * small amount of global state the load path (load235.c) and the menu
 * renderer (menu.c) need.  It is included by engine.c, load235.c and
 * menu.c so they all see ONE definition of each symbol -- exactly the
 * way the Pascal units share globals through their var sections.
 *
 * The struct layouts mirror the Turbo-Pascal records with
 * {$packrecords 1}:
 *   level     = record meno:string[30]; subor:string[12]; end;
 *   levels    = record pocet:word; lev:array[1..19] of level; end;
 *   diskx     = record meno:string[25]; subor:string[12]; verzia:word; end;
 *   all_disks = array[1..19] of diskx;
 *   polozka_typ= record|string[64]; x,y:word; k:word; end;
 *   menum_typ = record dat:array[1..5] of polozka_typ; pocet:byte; end;
 *
 * Short strings are stored as { unsigned char len; char buf[]; } so the
 * length byte matches Pascal's s[0] and the data is 1-based (z[k]==buf[k-1]).
 * ===================================================================== */
#ifndef SIRIEL_H
#define SIRIEL_H

#include <stdint.h>
#include "vec_ext.h"        /* predmet -- the vec^[] object record  */

/* ---- short string: { u8 len; char buf[] } (TP7 packed short string) ---- */
typedef struct { unsigned char len; char buf[256]; } tstr;

/* ---- Pascal records ---- */
typedef struct { char  meno[30];  char  subor[12]; } t_level;      /* level     */
typedef struct { unsigned short pocet; t_level lev[19]; } t_levels; /* levels    */

/* stage = record (AKTIV35.PAS:64).  mie is array[0..mie_x,0..mie_y] of byte
   with mie_x=38, mie_y=26 (AKTIV35.PAS:23-24) -> 39 map columns x 27 rows.
   The level-map loader (load_level_map) fills mie with the MAPA block geometry.
   The first dimension is sized MIE_X+2 (=40) -- one wider than the 39 real
   columns -- so save_map()/load_map() can copy the full 40-byte row that the
   Pascal `s:array[0..39]` + CopyCMemToXMem(...,40) move (the extra column is
   the padded 40th byte; MAPA only writes cols 0..MIE_X, leaving col 39 == 0). */
#define MIE_X 38
#define MIE_Y 26
/* Level-block buffer size: mirrors LOAD235.PAS load_predmet2's
   `maxbuf=32767` (arm = array[0..maxbuf] of byte => 32768 bytes).  The
   Siriel golden-ball levels exceed the old 4097-byte buffer (M1=6341,
   M2=11315, M4=24035), so dat_load_array() returned 0 and the level never
   loaded.  Shared by load235.c (load_level_map) and engine.c (acc_init). */
#define MAXLEN_LEVEL 32767
typedef struct {
    char            meno[20];                 /* st.meno  (level name)  */
    char            obr[12];                  /* st.obr   (intro image) */
    unsigned char   mie[MIE_X + 2][MIE_Y + 1];/* st.mie   (map grid)    */
    unsigned char   stav;                     /* st.stav  (level type)  */
} t_stage;

/* t_diskx mirrors data_disks^[f] (SI35.PAS: diskx).  NOTE: this struct is
 * C-only runtime state -- it is never serialized to/from the DAT, so its
 * exact byte layout need not match the Pascal {$packrecords 1} record.
 * The Pascal `subor:string[12]` holds a full 8.3 filename (e.g.
 * 'SIRIEL35.DAT' = 12 chars) with no room for a NUL terminator, so a naive
 * C `char subor[12]` truncates it to 11 chars and the later file lookups
 * (load_level_list(zvukovy_subor), the 'DISK:' banner) would fail.  We keep
 * the same logical field but size it to hold the full name + NUL. */
typedef struct { char  meno[25];  char  subor[128]; unsigned short verzia; } t_diskx;
typedef t_diskx t_all_disks[19];                     /* all_disks[1..19] */

/* polozk_typ = record|string[255]; x,y:word; k:word; end;
   menum_typ  = record dat:array[1..5] of polozk_typ; pocet:byte; end;
   (AKTIV35.PAS).  The array is 1-based [1..5], so the C buffer must have
   room for index 5 -- a plain C `dat[5]` only spans indices 0..4 and would
   write the 5th item out of bounds (clobbering `pocet`, which sits right
   after the array).  We keep the 1-based indexing and size the buffer to 6.
   NOTE: `me` (menum_typ) is C-only runtime state, never serialized. */
typedef struct { char  meno[64]; unsigned short x, y; unsigned short k; } t_polozka;
typedef struct { t_polozka  dat[6];      unsigned char pocet; } t_menum_typ; /* menum_typ */

/* hrac = record|string[12]; score:longint; end;  (AKTIV35.PAS) -- a single
   hi-score entry.  banda = array[1..10] of hrac.  The short-string meno is
   kept as a Pascal-style { u8 len; char buf[12] } so a later SCORE.DAT
   Blockread port would line up; the display code reads it via g_hraci_name(). */
typedef struct { unsigned char len; char buf[12]; int score; } t_hraci;

/* ---- shared global state (defined in load235.c) ---- */
extern t_levels  *g_levely;        /* ^levels                          */
extern t_all_disks g_data_disks;   /* ^all_disks, indexed 1..num_disks */
extern unsigned short g_num_disks; /* num_disks                          */
extern unsigned char  g_ja;        /* ja: language index (1..num_lang)  */

/* language[1..num_lang] (LANG.INC: ('ENG','SLO')) */
extern const char *g_language[4];   /* g_language[1]='ENG', [2]='SLO' */

/* ---- translation tables (LANG.INC) ----
 * tx : array[1..2,1..27] of string[20]  -> [2][27][21]
 * tx2: array[1..2,1..4]  of string[25]  -> [2][4][26]
 * tx3: array[1..2,1..12] of string[80]  -> [2][12][81]
 * Access via TX(ja,n) / TX2(ja,n) / TX3(ja,n) below (1-based ja,n).        */
extern const char g_tx[2][27][21];
extern const char g_tx2[2][4][26];
extern const char g_tx3[2][12][81];

#define TX(ja,n)    g_tx[(ja)-1][(n)-1]
#define TX2(ja,n)   g_tx2[(ja)-1][(n)-1]
#define TX3(ja,n)   g_tx3[(ja)-1][(n)-1]

/* intro-page globals (GAME.INC show_intro_page) */
extern char   g_version[64];   /* VERSION constant                       */
extern char   g_meno_disku[32];/* meno_disku: selected disk display name */
extern char   g_input_file[16];/* 'MAIN.DAT'                             */

/* ---- config record: the fields setup() (LOAD235.PAS) assigns ---- */
typedef struct {
    int          zvuk;             /* opt 5  */
    char         snd_credit[12];   /* opt 6  */
    char         snd_zober[12];    /* opt 7  */
    char         zvukovy_subor[16];/* opt 9  */
    char         anim_file[16];    /* opt 10 */
    char         snd_port[12];     /* opt 11 */
    char         start_miestnost[24];/* opt 12 */
    char         textura[16];      /* opt 15 */
    char         veci[16];         /* opt 17 */
    char         anim_def[16];     /* opt 18 */
    char         snd_objav[12];    /* opt 19 */
    char         snd_start[12];    /* opt 20 */
    char         snd_strata[12];   /* opt 21 */
    char         snd_koniec[12];   /* opt 22 */
    char         snd_succes[12];   /* opt 23 */
    char         snd_acces[12];    /* opt 24 */
    char         snd_zmizni[12];   /* opt 25 */
    char         snd_intro[12];    /* opt 26 */
    char         intro_obr[16];    /* opt 27 */
    char         snd_appear[12];   /* opt 28 */
    char         snd_theend[12];   /* opt 29 */
    char         outro_obr[16];    /* opt 30 */
    char         snd_score[12];    /* opt 31 */
    char         snd_zivot[12];    /* opt 32 */
    char         snd_maze[12];     /* opt 33 */
    char         flik_start[32];   /* opt 34 */
    char         flik_end[32];     /* opt 35 */
    char         msg[6][81];       /* opt 36-40 msg[1..5] */
    unsigned short timer;          /* opt 41 */
    int          fli_abile;        /* opt 42 */
    int          ja_set;           /* opt 43: ja was set by config */
    char         scroll_sub[16];   /* opt 44 */
    char         vec_opt[16];      /* opt 45 */
    char         text_opt[16];     /* opt 46 */
    char         floor_opt[16];    /* opt 47 */
    int          test;             /* opt 48 */
    char         mapx[16];         /* opt 49 */
    char         firstmap[16];     /* opt 50 */
    int          crc_checking;     /* opt 51 */
    unsigned short inicializacna_pauza; /* opt 52 */
    char         snd_fireball[12]; /* opt 53 */
    char         snd_fir[12];      /* opt 54 */
    int          use_joystick;     /* opt 55 */
    char         font[16];         /* opt 56 */
    char         snd_change[12];   /* opt 57 */
    unsigned char scan_x1,scan_x2,scan_y1,scan_y2; /* opt 58-59 */
    int          smart_jump;       /* opt 60 */
    char         zvuky[17][16];    /* opt 62 SNDX zvuky[m] */
    unsigned char start_stage;     /* opt 63 */
    unsigned char freez_time;      /* opt 64 */
    unsigned char unfreez_sound;   /* opt 64 */
    unsigned char god_time;        /* opt 65 */
    unsigned char ungod_sound;     /* opt 65 */
    unsigned char start_action;    /* START_ACTION (last) */
} t_config;

extern t_config g_cfg;

/* ---- run-loop progress + game flags (SI35.PAS / GAME.INC) ----
 * These mirror the Pascal globals that the menu-driven states (level
 * selector, password, briefing, info, hi-scores, quit-confirm) read and
 * write.  They live here so engine.c (the state machine) and game_menu.c
 * (the menu routines) share ONE copy, exactly as the Pascal units do. */
extern t_hraci  g_hraci[11];          /* banda^[1..10]  hi-score table    */
extern unsigned char g_menu_pointer;  /* menu_pointer : last chosen level */
extern unsigned char g_old_level;     /* old_level    : current level 1..N*/
extern unsigned char g_vybrane;       /* vybrane      : selected level    */
extern int       g_the_koniec;        /* the_koniec   : level finished    */
extern int       g_sace;              /* sace         : level succeeded   */
extern int       g_restart;           /* restart      : game restart flag */
extern int       completer;           /* completion requirement (LOAD235.PAS:606);
                                          set from a funk=9 door's inf1, default
                                          def_completer=1 (AKTIV35.PAS:178) */

/* DAT file that holds the level blocks (M1..M12, [MENO]/[MSG1]/[MAPA] ...).
 * Set from g_data_disks^[1].subor by load_basic_config(); the level-block
 * readers in game_menu.c use it to read a level's block. */
extern const char *g_level_dat;

/* st : stage (AKTIV35.PAS:64) -- the current level's room record.  Defined
   in load235.c alongside the other run-loop globals; the map loader fills
   st.mie / st.meno / st.stav / st.obr. */
extern t_stage st;

/* miestnost : the current room (LOAD235.PAS:1048).  cc_print_predmet2() only
   blits vec^[] objects whose mie==miestnost; set at the end of load_level_map. */
extern unsigned short g_miestnost;

/* Texture / tile-table render state (LOAD235.PAS load_texture / print_texture).
   g_te[] is the ^te tile table (NUM_TILES 16x16 tiles, carved by cc_load_texture
   in engine.c); g_invisible / g_inusable are the st.mie thresholds.  g_invisible
   defaults to def_invisible = 255 (AKTIV35.PAS:173) and is overridden by a
   level's [INVISIBLE] option.  Defined in engine.c, reset per level in
   load_level_map(). */
#define NUM_TILES 190
extern unsigned char g_invisible;
extern unsigned char g_inusable;

/* msg[1..5] (AKTIV35.PAS: msg: array[1..5] of string[80]) -- the level
 * objective text.  For the menu states we read the selected level's MSG1
 * straight from its block (see level_field()); g_cfg.msg holds the top-level
 * CONFIG MSG1-5 as a fallback. */
#define MSG1  g_cfg.msg[1]
#define MSG2  g_cfg.msg[2]
#define MSG3  g_cfg.msg[3]
#define MSG4  g_cfg.msg[4]
#define MSG5  g_cfg.msg[5]

/* ---- load235.c (Phase C) ---- */
/* string helpers (plain C, null-terminated) */
void  get_name_normal(const char *src, char *dst, int dstsz);
void  get_funk_normal(const char *src, char *dst, int dstsz);
void  get_name(const char *src, char *dst, int dstsz);
void  get_funk(const char *src, char *dst, int dstsz);
int   check_lan(char *dst, const char *src, int dstsz);
int   check_lan2(char *dst, const char *src, int dstsz);
char *out_string(char *s, int sz);
void  upcased(char *s);
int   val(const char *s, long *out);
void  mov_string(const char *src, char *dst, int dstsz, unsigned short *poradie);
void  mov_num(const char *src, long *out, unsigned short *poradie);
void  mov_num2(const char *src, unsigned char *out, unsigned short *poradie);

/* vec^[] object storage + line token pointer (LOAD235.PAS load_predmet2).
   g_vec[1..200] is the object array (g_vec[0] a guard slot); g_nahrane_veci
   is the count of loaded objects; count is the mov_num token index. */
extern predmet g_vec[201];
extern unsigned short g_nahrane_veci;
extern unsigned short count;
/* State-23 inventory / [TEXT]-dialog globals (defined in engine.c, shared
   with game_menu.c exactly like the Pascal units share their var section). */
extern unsigned short g_mov;            /* object the avatar points at       */
/* inventory overlay (menu_init/menu_step) */
extern unsigned char inv_init;          /* menu_init() has painted the overlay   */
extern unsigned char inv_done;          /* a selection was committed             */
extern unsigned char inv_direct_done;   /* a direct-use object was applied       */
extern unsigned char inv_result;        /* committed menu index (1..3) or 0       */
extern unsigned short inv_f;            /* current menu highlight               */
extern unsigned short menu_x;           /* menu_x := 4                          */
extern unsigned char inv_status;        /* Pascal overlay status flag           */
extern unsigned char inv_zobral;        /* picked this entry up on this entry   */
/* item-activation [TEXT] dialog (pouzi_predmet_init/pouzi_predmet_step) */
extern unsigned char pp_started;        /* pouzi_predmet_init() has run         */
extern unsigned char pp_done;           /* command loop finished                */
extern unsigned char pp_pending;        /* a dialog is queued                   */
extern unsigned short pp_num;           /* item/num index passed to init        */
extern unsigned short pp_z;             /* originating item index               */
extern unsigned char pp_return;         /* return value for the caller          */
extern unsigned char pp_wait_mode;      /* 0=running 1=waiting key 2=pulses     */
extern unsigned short pp_wait_left;     /* remaining pulses (mode 2)            */
extern unsigned char pp_wait_cmd;       /* blocking command that triggered wait */
extern unsigned char pp_jump;           /* conditional jump requested           */
extern unsigned char pp_breaker;        /* END command seen                     */
extern unsigned char pp_close;          /* text finished; waiting to close      */
extern unsigned char pp_xx;             /* current text-buffer index            */
extern unsigned short pp_count;         /* position within the current line     */
extern char pp_s[128];                  /* current text-buffer line             */
/* load the CONFIG block of <sub> into levely^ (LOAD235.PAS load_level_list) */
void load_level_list(const char *sub);
/* disk scan + level load (LOAD235.PAS load_basic_config) */
void load_basic_config(void);
/* read the external SIRIEL3.CFG setup file and feed each line to setup()
   (SI35.PAS / PREMEN35.INC load_config).  Sets fli_abile from [ANIMS]=YES,
   language from [LANGUAGE], sound from [ZVUK], etc. -- the DAT block carries
   none of those keywords, so this is the only place they are honoured. */
void load_config(void);
/* Load a level's resource block (<sub>, e.g. "M1") from <dat> into buf and
 * apply the dekoduj(+2) transform exactly like LOAD235.PAS load_level_list
 * does for its CONFIG block.  Returns the number of bytes loaded (>0).
 * <sub> may carry the leading '>' (">M1") -- it is stripped before the read. */
int load_level_block(const char *dat, const char *sub,
                     unsigned char *buf, int bufsz);
/* Extract the value of a "[FIELD]=value" line from a dekoduj'd level block
 * (buf, as produced by load_level_block).  Mirrors load_level_list's
 * get_name_normal/get_funk_normal parse.  Returns 1 if found (out filled),
 * 0 otherwise. */
int level_field(const unsigned char *buf, const char *field,
                char *out, int outsz);
/* load_level_map(dat, sub) -- faithful port of the MAPA (option 4)
 * extraction from LOAD235.PAS load_predmet2, plus the Z/X/Y/V object branches
 * (prirad / pridaj2 -> vec^[]).  Loads the <sub> block from DAT <dat>, applies
 * the dekoduj(+2) transform, scans the [KEYWORD]= lines, and on [MAPA=] reads
 * the 39x27 (MIE_X/MIE_Y) map grid into st.mie using the exact Pascal loop
 * (cell = byte - 15, dec(znak) on CR/LF).  Also captures st.meno / st.stav /
 * st.obr from their option lines, and populates g_vec[] from the object
 * keywords (Z<name>, X/Y -> prirad, W -> pridaj2, V<name>). */
void load_level_map(const char *dat, const char *sub);

/* save_map(num) / load_map(num) -- faithful ports of LOAD235.PAS save_map /
   load_map.  They move the 40x27 st.mie tile-index grid to/from map_buf, which
   stands in for the Pascal handles[5] (map_size = 40*27*num_maps) XMS handle. */
void save_map(unsigned char num);
void load_map(unsigned char num);
/* [TEXT] table (handles[3] text portion).  uloz_text_c(s,n) stores the
   script of a [TEXT]=n,<script>; line at index n; vrat_text(n,dst,sz)
   returns it for the step-able pouzi_predmet() dialog. */
void uloz_text_c(const char *s, unsigned short n);
void vrat_text(unsigned short n, char *dst, int sz);
/* [VEC] name table (handles[3] name portion).  21-stride entries like the
   Pascal handles[3] name region (20-byte slot + stride).  uloz_nazov_c(s,f)
   stores the pickable item name at index f (populated by the [VEC] handler in
   load_level_map); vatr_nazov_c(f) returns it for the inventory display. */
void uloz_nazov_c(const char *s, unsigned short f);
const char *vatr_nazov_c(unsigned short f);
/* TEST HOOK: inject a key word for the pp_probe harness (see engine.c). */
void cc_pp_set_key(unsigned short k);
/* TEST HOOK: pp_probe injects Enter at this 0-based step (see game_menu.c). */
extern int g_pp_key_step;

/* ---- engine.c (Phase C-2): state-21 gameplay movement / simulation ----
 * Faithful C port of the missing Pascal gameplay source (GAME.INC
 * maze_step/arcade_step, GEO.PAS sipka_* + get_keyboard/zmack, POCHECK3.INC
 * po/po3, LOAD235.PAS zisti_vec/use_vec/go_to_new_stage, SI35.PAS panak).
 * engine.c owns all of it; load235.c only sets the avatar start position via
 * cc_set_start_pos() and the run-loop state machine drives the step loop via
 * cc_hra_step() / cc_hra_final() and reads the game flags below. */
/* LOAD235.PAS START option 3: place the panak avatar at si.x/si.y. */
void cc_set_start_pos(unsigned short x, unsigned short y);
/* hra_init(): reset all gameplay flags, re-apply the START position, install
   sipka_limit bounds + per-stav movx/movy/mova.  Called on level entry. */
void cc_game_reset(void);
/* GAME.INC hra_step: run exactly one game frame (arcade_step / maze_step). */
void cc_hra_step(void);
/* GAME.INC hra_final: free gameplay scratch, mark the loop done. */
void cc_hra_final(void);
/* GAME.INC arc_done / maze_done gate flags. */
int  cc_arc_done(void);
int  cc_maze_done(void);
/* SI35.PAS / LOAD235.PAS game-over / level-finished / level-won flags. */
int  cc_the_koniec(void);
int  cc_restart(void);
int  cc_acc_init_flag(void);
/* SI35.PAS state-21 special flags (ESC / help / inventory). */
int  cc_quit_pending(void);
int  cc_help_pending(void);
int  cc_inv_pending(void);
/* State-23 inventory overlay accessors (MENU35.INC + this header's externs).
   cc_last_mov = the object the avatar points at (Pascal global `mov`);
   cc_own/cc_set_own read/write the own[1..3] inventory slots; cc_get_si /
   cc_get_pxpy expose the avatar position + the AKTIV35.PAS px/py feet offset;
   cc_get_poloha/cc_set_poloha expose the panak pose frame. */
unsigned short cc_last_mov(void);
unsigned char  cc_own(int f);
void           cc_set_own(int f, unsigned char v);
void           cc_get_si(unsigned short *x, unsigned short *y);
/* MENU35.INC SIRXY (35) / GOMAP (37) text-command helpers.  cc_set_si()
   repositions the avatar (si.x:=a*8+8, si.y:=b*8+8); cc_gomap() switches the
   current room (save_map/load_map + g_miestnost) without moving the avatar. */
void           cc_set_si(unsigned short x, unsigned short y);
void           cc_gomap(unsigned char a);
void           cc_get_pxpy(int *pout_px, int *pout_py);
void           cc_set_poloha(unsigned char p);
unsigned char  cc_get_poloha(void);
/* Render helpers the inventory overlay calls into engine.c. */
void cc_zhasni_vec(predmet *v);          /* switch an object off        */
void cc_reprint_predmet(void);           /* redraw the whole scene       */
void cc_draw_inventar(void);             /* bottom-HUD inventory bar     */
void cc_put_obj_sprite(unsigned x, unsigned y, unsigned short obr, unsigned char col);
void cc_put_char_cell(unsigned x, unsigned y, unsigned char cell, unsigned char col);
/* cc_zisti_vec -- recompute the pointed-at object (g_mov) only (no
   use_vec/accomplish side effects).  Called by menu_step after a picked-up
   item is dropped back into the room. */
void cc_zisti_vec(void);
/* cc_use_vec -- run the real "use object" effect (LOAD235.PAS use_vec) for the
   pointed-at object.  menu_init calls it in its DIRECT-USE path (an object
   whose name first letter is not 'W' and not 'V'): a teleport, a texture/
   object reveal-hide, the level-complete door, or an add-life object. */
void cc_use_vec(unsigned short mov);

/* Phase 9 inventory / pause overlay (MENU35.INC) -- driven by engine.c
   es_state=23.  menu_init paints the overlay once; menu_step advances the
   cursor and commits on Enter/Space/ESC.  pouzi_predmet_init/pouzi_predmet_step
   are the step-able item-activation [TEXT] dialog. */
void menu_init(void);
void menu_step(void);
unsigned char pouzi_predmet_init(unsigned short num, unsigned char typ);
void pouzi_predmet_step(void);
/* ---- engine.c menu-box (old_frame / TFrame) loader ------------------
 * GLIST (MAIN.DAT) is decoded into g_frame (8 border tiles) at engine
 * init; cc_draw_menu_frame(x,y,dx,dy) blits the border + interior fill for
 * a menu box (mirrors SI35.PAS old_frame.draw(x,y,dx,dy)). The level
 * selector calls cc_draw_menu_frame(200,40,12,18); the "Quit" dialog calls
 * cc_draw_menu_frame(270,180,3,3). */
void cc_draw_menu_frame(int x, int y, int dx, int dy);

/* ---- engine.c sprite primitives (SI35.PAS / ANIMING.PAS) --------------
 * These drive the panak avatar that the intro menu (choice_init/choice_step)
 * renders next to the menu items.  ar^ is the character-sprite table. */
unsigned char *cc_ar(void);                       /* ^long_panak            */
void init_charakter(unsigned int chsizex, unsigned int chsizey,
                    unsigned int chx, unsigned int chy,
                    unsigned int chpoloha, unsigned int chbuf,
                    unsigned char *am);            /* place the avatar       */
void karakter(unsigned int chx, unsigned int chy,
              unsigned int choldx, unsigned int choldy,
              unsigned int chpoloha, unsigned int chbuf,
              unsigned char *am);                  /* move/animate the avatar*/
void vypni_charakter(unsigned int choldx, unsigned int choldy,
                    unsigned int chbuf, unsigned char *am);  /* erase the avatar    */

/* ---- menu.c (Phase D) ---- */
void show_intro_page(void);
void choice_init(void);
void choice_step(void);
unsigned char choice_result(void);
/* selected item's DOS key word (engine.c routes on it) */
unsigned short menu_item_key(int f);
/* intro-menu committed flag (engine.c auto-runs after it) */
unsigned char menu_ch_done(void);

/* ---- game_menu.c (Phase D-2): the menu-driven run-loop states ----
 * Faithful structural ports of GAME.INC select_level / password / briefing /
 * info / show_hi_score / quit_confirm, rendered with the tiny 5x7 font in
 * fb_draw.h (the real JxGRID raster is NOT ported yet).  engine.c drives each
 * as init()/step()/done()/result() mirroring SI35.PAS engine_step. */
/* State 12: level selector */
void select_level_init(void);
void select_level_step(void);
unsigned char select_level_done(void);
unsigned char select_level_result(void);
/* State 24: password prompt.  level_needs_password() pre-fills pw_password;
 * password_init/step paint the field and validate against it. */
int  level_needs_password(unsigned char level, char *pw_out, int pw_sz);
void password_init(void);
void password_step(void);
unsigned char password_done(void);
unsigned char password_ok(void);
/* State 30: level-start objective dialog */
void briefing_init(void);
void briefing_step(void);
unsigned char briefing_finished(void);   /* briefing_done() name is taken by the global */
/* State 40: Info / Help (credits + scrolling help) */
void info_init(void);
void info_step(void);
unsigned char info_finished(void);       /* info_done() name is taken by the global */
int  info_ret_get(void);
/* caller sets the return state before Info (10=main menu, 21=gameplay) */
void info_ret_set(int v);
/* State 41: hi-scores table */
void show_hi_score_init(void);
void show_hi_score_step(void);
unsigned char show_hi_score_done(void);
/* State 13: quit-level Yes/No confirmation */
void quit_confirm_init(void);
void quit_confirm_step(void);
unsigned char quit_confirm_done(void);
unsigned char quit_confirm_result(void);
/* init-once guards + reset (engine.c re-paints a menu fresh on re-entry) */
unsigned char select_level_init_done(void);
unsigned char password_init_done(void);
unsigned char briefing_init_done(void);
unsigned char info_init_done(void);
unsigned char hi_score_init_done(void);
unsigned char quit_confirm_init_done(void);
void select_level_reset(void);
void password_reset(void);
void briefing_reset(void);
void info_reset(void);
void hi_score_reset(void);
void quit_confirm_reset(void);

#endif /* SIRIEL_H */
