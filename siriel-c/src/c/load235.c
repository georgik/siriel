/* =====================================================================
 * load235.c  -  faithful C port of the Siriel 3.5 DATA-DISK LOADER.
 *
 * This is Phase C of the C-C engine: it makes the pure-C engine actually
 * LOAD the game data disk (SIRIEL35.DAT) exactly like the original
 * Pascal, instead of the skeleton that only drew coloured state boxes.
 *
 * It ports, line by line from src/pascal/LOAD235.PAS:
 *   * the GEO.PAS string-extraction helpers used by the CONFIG parser
 *     (get_name_normal / get_funk_normal / get_name / get_funk /
 *      check_lan / out_string / upcased / val / mov_string / mov_num /
 *      mov_num2) -- here as plain null-terminated C strings, since the
 *      decoded CONFIG block is printable ASCII.
 *   * option[1..66]      -- the 66 CONFIG keywords (LOAD235:141)
 *   * setup(fun)         -- the CONFIG keyword parser (LOAD235:2168)
 *   * load_level_list    -- loads the CONFIG block, dekoduj's it, and
 *                           turns the [MENO]/[ ...]=>Mn records into the
 *                           levely^ table (LOAD235:2151)
 *   * load_basic_config  -- scans *.dat / *.DAT, checks the SIRIEL35
 *                           block header, parses each disk version, and
 *                           loads its level list (LOAD235 via SI35.PAS)
 *
 * datx.c supplies the DAT reader (loadblock_array via dat_load_array and
 * the *.dat scan with the SIRIEL35 header check via scan_disks), so this
 * file only has to port the Pascal *logic* on top of it.
 *
 * Global state (ja, language[], levely^, data_disks^, the config record)
 * lives here in siriel.h so engine.c / menu.c see the same memory.
 * ===================================================================== */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "siriel.h"
#include "datx.h"

/* ------------------------------------------------------------------ */
/* Global state                                                        */
/* ------------------------------------------------------------------ */
t_levels  *g_levely = NULL;
t_all_disks g_data_disks;
unsigned short g_num_disks = 0;
unsigned char  g_ja = 1;            /* default language = English       */

const char *g_language[4] = {
    "",             /* row 0 unused (Pascal indices are 1-based) */
    "ENG",          /* language[1] */
    "SLO",          /* language[2] */
    "",
};

const char g_tx[2][27][21] = {
    /* English (ja=1) */
    {"Time: "," High score !"," Password:"," WOW !"," Ooou !",
     "   Quit","Pause...","Lifes: ","Loading...","Game","Info + Help",
     "Hi-scores","Quit","No message"," HELP:","password",
     "Enter ","Correct ","Incorrect "," PASSWORD: ","Score:",
     "Back","Yes","No","Pocket","Empty","Inventory:"},
    /* Slovak (ja=2) */
    {"Cas: "," Najvyssie skore !"," Heslo:"," VAV !"," Uff !",
     "   Koniec","Pauza...","Zivoty: ","Nahravam...","Hra","Info + Pomoc",
     "Najlepsi hraci","Koniec","Ziadna sprava"," POMOC:","heslo","Vloz ",
     "Spravne "," Nespravne "," HESLO: ","Skore:","Spat","No","Nie",
     "Vrecko","Prazdne","Inventar:"},
};

const char g_tx2[2][4][26] = {
    {"You`ve done it !","Select DATADISK","Unknown parameter !-<",
     "MAIN.DAT is CORRUPTED !"},
    {"Zmolkol si to !","Vyber DATADISK","Neznomy parameter !-<",
     "MAIN.DAT je pokodene !"},
};

const char g_tx3[2][12][81] = {
    {"For this datadisk you need new Siriel 3.5 engine !",
     "Fatal error: MAIN.dat doesn`t exist !-<",
     "Arrows or NUM-pad => Move",
     "Space or Enter => Use",
     "Esc => Abort game, F1, H => HELP",
     "F4,P => Pause, F5, B => Briefing",
     "Controls: Arrows - move; Enter, Space - use",
     "No DATADISKS. You need to copy DATADISK into the SIRIEL.3_5 directory",
     "Siriel3.cfg was not found ! Run SETUP.EXE !",
     "CRC data deosn`t exist, file may be CORRUPTED !",
     "Incorect CRC ! File is  CORRUPTED !",
     "Do you still want to play it ? (contact me for correct version)"},
    {"Pre tento datadisk potrebujete nov Siriel 3.5 engine !",
     "Osudova chyba: MAIN.dat neexistuje !-<",
     "Tipky alebo NUM-pad => Pohyb",
     "Medzera alebo Enter => Pouzi",
     "ESC => Ukonci hru, F1, H => Pomoc",
     "F4, P => Pauza, F5, B => Briefing",
     "Ovladanie: sipky - pohyb; Enter, Medzera - pouzi",
     "Ziadne DATADISKy. Nakopirujte DATADISK do adresaru SIRIEL.3_5",
     "Siriel3.cfg nebol najdeny ! Spustite SETUP.EXE !",
     "CRC udaje neexistuju, subor moze byt pokodene !",
     "Nespravne CRC ! Subor je pokodene !",
     "Chcete aj naalej hrat ? (kontaktujte ma pre spravnu verziu)"},
};

char   g_version[64]   = "SIRIEL 3.5        v.:1.08";
char   g_meno_disku[32] = "";
char   g_input_file[16] = "MAIN.DAT";

t_config g_cfg;

/* DAT file holding the level blocks (M1..M12). Set by load_basic_config()
 * from g_data_disks^[1].subor ('SIRIEL35.DAT'); the menu-driven states use it
 * to read a level's [MENO]/[MSG1]/[MAPA] block. */
const char *g_level_dat = NULL;

/* st : stage -- the current level's room record (AKTIV35.PAS:64).  Defined
   next to the other load235.c globals so engine.c / menu.c see one copy. */
t_stage st;

/* miestnost : the current room (AKTIV35.PAS:108).  load_predmet2 sets it from
   the STARTMAP/aktual value at the end of the level load:
       if aktual>1 then miestnost:=aktual+126 else miestnost:=1 ;   (LOAD235.PAS:1048)
   cc_print_predmet2() only blits vec^[] objects whose mie==miestnost. */
unsigned short g_miestnost = 1;

/* ---- run-loop progress + game flags (SI35.PAS / GAME.INC) ----
 * These mirror the Pascal globals the menu-driven states (game_menu.c) read
 * and write.  Defined here (next to the other load235.c globals) so engine.c,
 * menu.c and game_menu.c all see ONE copy -- exactly as the Pascal units do. */
t_hraci  g_hraci[11];             /* banda^[1..10]  hi-score table (SCORE.DAT) */
unsigned char g_menu_pointer;     /* menu_pointer : last chosen level        */
unsigned char g_old_level;        /* old_level    : current level 1..N        */
unsigned char g_vybrane;          /* vybrane      : selected level            */
int       g_the_koniec;           /* the_koniec   : level finished            */
int       g_sace;                 /* sace         : level succeeded           */
int       g_restart;              /* restart      : game restart flag         */

/* maxlen from AKTIV35.PAS -- big enough for the CONFIG block (a few hundred
   bytes).  Kept for load_level_list() only.  The per-level block buffer is
   MAXLEN_LEVEL (see siriel.h), matching LOAD235.PAS load_predmet2's maxbuf. */
#define MAXLEN 4096
/* basic_snd from AKTIV35.PAS:166 -- offset of extra (replacement) sounds */
#define basic_snd 8

/* ===================================================================== */
/* val() : TP7 Val() -- parse an integer, return the error code (0=ok).  */
/* Ported from the validated spike/migrate/geo_ext/load_helpers.c.       */
/* ===================================================================== */
static unsigned short val_word(const char *s, unsigned short *code)
{
    unsigned short len = (unsigned short)strlen(s);
    unsigned short val = 0, i = 1;   /* 1-based Pascal index (== InitVal's Code) */
    int neg = 0;
    int base = 10;
    while (i <= len && (s[i-1]==' ' || s[i-1]=='\t')) i++;
    if (i <= len) {
        if (s[i-1]=='-') { neg=1; i++; }
        else if (s[i-1]=='+') i++;
    }
    if (i <= len) {
        switch (s[i-1]) {
            case '$': case 'X': case 'x': base=16; i++; break;
            case '%': base=2;  i++; break;
            case '&': base=8;  i++; break;
            case '0':
                if (i < len && (s[i]=='x' || s[i]=='X')) { i+=2; base=16; }
                break;
        }
    }
    if (i <= len) while (i <= len && s[i-1]=='0') i++;
    if (neg || i > len) { *code = i; return 0; }
    {
        unsigned char c = (unsigned char)s[i-1];
        if (c == '\0') { if (i > 1 && s[i-2]=='0') *code = 0; else *code = i; return 0; }
    }
    for (; i <= len; i++) {
        unsigned char cc = (unsigned char)s[i-1];
        unsigned short u, prev;
        if      (cc >= '0' && cc <= '9') u = cc - '0';
        else if (cc >= 'A' && cc <= 'F') u = cc - 'A' + 10;
        else if (cc >= 'a' && cc <= 'f') u = cc - 'a' + 10;
        else if (cc == '\0') break;
        else u = 16;
        prev = val;
        if (u >= (unsigned short)base || ((0xFFFFu - u) / (unsigned short)base) < prev) {
            val = 0; *code = i; return 0;
        }
        val = (unsigned short)((unsigned short)val * (unsigned short)base + u);
    }
    *code = 0;
    return val;
}

int val(const char *s, long *out)
{
    unsigned short code;
    long v = (long)val_word(s, &code);
    if (out) *out = v;
    return code;              /* 0 on success, else the failing index */
}

/* ===================================================================== */
/* mov_string / mov_num / mov_num2  (GEO.PAS token extractors)           */
/* ===================================================================== */
void mov_string(const char *src, char *dst, int dstsz, unsigned short *poradie)
{
    unsigned short len = (unsigned short)strlen(src);
    unsigned short p = *poradie;
    int n = 0;
    if (len >= p) {
        for (;;) {
            if (n < dstsz-1) dst[n] = src[p-1];
            n++; p++;
            if (p > len) break;
            if (src[p-1] == '~') break;
            if (src[p-1] == ',') break;
        }
        p++;                      /* inc(poradie) past the delimiter */
    }
    dst[n < dstsz ? n : dstsz-1] = '\0';
    *poradie = p;
}

void mov_num(const char *src, long *out, unsigned short *poradie)
{
    char row[256]; unsigned short code;
    mov_string(src, row, sizeof(row), poradie);
    if (row[0] == '\0') { if (out) *out = 0; }
    else                { if (out) *out = (long)val_word(row, &code); }
}

void mov_num2(const char *src, unsigned char *out, unsigned short *poradie)
{
    char row[256]; unsigned short code;
    mov_string(src, row, sizeof(row), poradie);
    if (row[0] == '\0') { if (out) *out = 0; }
    else                { if (out) *out = (unsigned char)(val_word(row, &code) & 0xff); }
}

/* M16(src, field) : mov_num into a predmet unsigned-short member.  mov_num
 * parses into a 4-byte long, so it must go through a long temp -- passing the
 * address of a 2-byte packed-struct member would write 2 overflow bytes into
 * the next field.  (v)->field is then narrowed to u16. */
#define M16(src, field) do { long _lm = 0; mov_num((src), &_lm, &count); (v)->field = (unsigned short)_lm; } while (0)

/* ===================================================================== */
/* out_string / upcased                                                   */
/* ===================================================================== */
/* Drops the first character in place (BLOCKX / check_lan helper). */
char *out_string(char *s, int sz)
{
    int len = (int)strlen(s), raw, d;
    if (len <= 0) return s;
    for (raw = 1, d = 0; raw < len; raw++, d++)   /* z[raw+1] := z[raw], raw=1..len-1 */
        s[d] = s[raw];
    s[d] = '\0';
    return s;
}

/* upcase a..z in place (GEO.PAS upcased). */
void upcased(char *s)
{
    for (; *s; s++)
        if (*s >= 'a' && *s <= 'z') *s = (char)(*s - 'a' + 'A');
}

/* ===================================================================== */
/* get_name_normal / get_funk_normal / get_name / get_funk               */
/*   (GEO.PAS -- identical to the validated spike ports, but on C chars) */
/* ===================================================================== */
void get_name_normal(const char *src, char *dst, int dstsz)
{
    unsigned short len = (unsigned short)strlen(src);
    unsigned short fr = 0;
    char chars[256];
    int n = 0;
    if (src[0] != ';') {
        while (1) { fr++;
            if (src[fr-1] == '[') break;
            if (fr > len) break;
        }
        fr++;
        while (1) { chars[n++] = src[fr-1]; fr++;
            if (src[fr-1] == ']') break;
            if (fr > len) break;
        }
    }
    if (n > dstsz-1) n = dstsz-1;
    memcpy(dst, chars, n);
    dst[n] = '\0';
}

void get_funk_normal(const char *src, char *dst, int dstsz)
{
    unsigned short len = (unsigned short)strlen(src);
    unsigned short fr = 0, fl;
    char chars[256];
    int n = 0;
    if (src[0] != ';') {
        while (1) { fr++;
            if (src[fr-1] == '=') break;
            if (fr > len) break;
        }
        fr++;
        for (fl = fr; fl <= len; fl++) chars[n++] = src[fl-1];
    }
    if (n > dstsz-1) n = dstsz-1;
    memcpy(dst, chars, n);
    dst[n] = '\0';
}

void get_name(const char *src, char *dst, int dstsz)
{
    get_name_normal(src, dst, dstsz);
    upcased(dst);
}

void get_funk(const char *src, char *dst, int dstsz)
{
    get_funk_normal(src, dst, dstsz);
    upcased(dst);
}

/* check_lan : var ciel; zdroj (LOAD235.PAS:695).                        */
/*   Returns 0 (plain copy), 1 (tilde prefix, lang no match), 2 (tilde    */
/*   prefix, lang matched -> strips the ~LLL~ marker).  On tilde-no-match  */
/*   PASCAL leaves <ciel> UNCHANGED -- this is the load_level_list path:   */
/*   the plain name line '[1. Magic stars]' sets lev.meno, then the        */
/*   tilde line '[~SLO~1. Magick. hviezdy]' must NOT wipe it.  Split from  */
/*   check_lan2() below, which DOES clear ciel on tilde-no-match (the      */
/*   [TEXT] handler path).  The C port used to merge both into one         */
/*   check_lan that cleared dst, so every tilde line wiped the level name */
/*   the plain line had just set -- the Level-Selector empty-text bug.    */
int check_lan(char *dst, const char *src, int dstsz)
{
    int f, res = 0;
    char s[8];
    if (src[0] == '~') {
        s[0] = '\0';
        for (f = 2; f <= 4; f++) { if (src[f-1]) { int sl = (int)strlen(s); if (sl<7){ s[sl]=src[f-1]; s[sl+1]='\0'; } } }
        res = 1;
        if ((unsigned)g_ja <= 2 && strcmp(g_language[g_ja], s) == 0) {
            res = 2;
            strncpy(dst, src, dstsz-1); dst[dstsz-1] = '\0';
            for (f = 0; f < 5; f++) out_string(dst, dstsz);   /* strip ~LLL~ */
        }
        /* else: PASCAL check_lan leaves <ciel> UNCHANGED -> do not touch dst */
    } else {
        strncpy(dst, src, dstsz-1); dst[dstsz-1] = '\0';
        res = 0;
    }
    return res;
}

/* check_lan2 : var ciel; zdroj (LOAD235.PAS:719).                        */
/*   Like check_lan but on tilde-no-match it CLEARS ciel to '' (this is    */
/*   the [TEXT] handler path: LOAD235.PAS option 46 calls check_lan2(sc,s) */
/*   so an untranslated script line yields an empty string, not a stale   */
/*   one.  The C port used to route this through check_lan, which is why   */
/*   the two had to be split.                                             */
int check_lan2(char *dst, const char *src, int dstsz)
{
    int f, res = 0;
    char s[8];
    if (src[0] == '~') {
        s[0] = '\0';
        for (f = 2; f <= 4; f++) { if (src[f-1]) { int sl = (int)strlen(s); if (sl<7){ s[sl]=src[f-1]; s[sl+1]='\0'; } } }
        res = 1;
        if ((unsigned)g_ja <= 2 && strcmp(g_language[g_ja], s) == 0) {
            res = 2;
            strncpy(dst, src, dstsz-1); dst[dstsz-1] = '\0';
            for (f = 0; f < 5; f++) out_string(dst, dstsz);   /* strip ~LLL~ */
        } else {
            dst[0] = '\0';        /* check_lan2: else ciel:='' (no match -> empty) */
        }
    } else {
        strncpy(dst, src, dstsz-1); dst[dstsz-1] = '\0';
        res = 0;
    }
    return res;
}

/* ===================================================================== */
/* option[1..66]  (LOAD235.PAS:141)                                      */
/* ===================================================================== */
static const char *option[67] = {   /* 1-based; [0] unused */
    "",
    "MENO","OBR","START","MAPA","ZVUK","SNDCREDIT",
    "SNDZOBER","GRAVITY","SND","ANIM","SNDPORT",
    "STARTMIE","NEXTMIE","TYP","TEXTURA","INVISIBLE",
    "VECI","ANIMDEF","SNDOBJAV","SNDSTART","SNDSTRATA",
    "SNDKONIEC","SNDSUCCES","SNDACCES","SNDZMIZNI",
    "SNDINTRO","INTROOBR","SNDAPPEAR","SNDEND","OUTROOBR",
    "SNDSCORE","SNDZIVOT","SNDMAZE","FLISTART","FLIEND",
    "MSG1","MSG2","MSG3","MSG4","MSG5","TIMER","ANIMS",
    "LANGUAGE","SCROLL","VEC","TEXT","FLOOR","TEST",
    "MAPX","FIRSTMAP","CRCCHECK","INITTIME","SNDFIREBALL",
    "SNDFIR","JOYSTICK","FONT","SNDCHANGE","SCAN","PRE",
    "SMARTJUMP","LIFT","SNDX","STARTSTAGE","SETFREEZ","SETGOD",
    "START_ACTION",
};

/* ===================================================================== */
/* setup(fun) : CONFIG keyword parser (LOAD235.PAS:2168).                */
/* Returns TRUE if <fun> was a known option (so load_level_list does    */
/* NOT treat it as a level), FALSE otherwise.                            */
/* ===================================================================== */
int setup(const char *fun)
{
    char funx[256];
    int f, found = 0;

    get_name(fun, funx, sizeof(funx));   /* get_name(fun,funx) */

    for (f = 1; f <= 66; f++) {
        if (strcmp(funx, option[f]) != 0) continue;
        found = 1;
        get_funk(fun, funx, sizeof(funx));   /* get_funk(fun,funx) */
        switch (f) {
            case 5:  g_cfg.zvuk = (strcmp(funx,"YES")==0); break;
            case 6:  strncpy(g_cfg.snd_credit, funx, sizeof(g_cfg.snd_credit)-1); break;
            case 7:  strncpy(g_cfg.snd_zober, funx, sizeof(g_cfg.snd_zober)-1); break;
            case 9:  strncpy(g_cfg.zvukovy_subor, funx, sizeof(g_cfg.zvukovy_subor)-1); break;
            case 10: strncpy(g_cfg.anim_file, funx, sizeof(g_cfg.anim_file)-1); break;
            case 11: strncpy(g_cfg.snd_port, funx, sizeof(g_cfg.snd_port)-1); break;
            case 12: strncpy(g_cfg.start_miestnost, funx, sizeof(g_cfg.start_miestnost)-1); break;
            case 15: strncpy(g_cfg.textura, funx, sizeof(g_cfg.textura)-1); break;
            case 17: strncpy(g_cfg.veci, funx, sizeof(g_cfg.veci)-1); break;
            case 18: strncpy(g_cfg.anim_def, funx, sizeof(g_cfg.anim_def)-1); break;
            case 19: strncpy(g_cfg.snd_objav, funx, sizeof(g_cfg.snd_objav)-1); break;
            case 20: strncpy(g_cfg.snd_start, funx, sizeof(g_cfg.snd_start)-1); break;
            case 21: strncpy(g_cfg.snd_strata, funx, sizeof(g_cfg.snd_strata)-1); break;
            case 22: strncpy(g_cfg.snd_koniec, funx, sizeof(g_cfg.snd_koniec)-1); break;
            case 23: strncpy(g_cfg.snd_succes, funx, sizeof(g_cfg.snd_succes)-1); break;
            case 24: strncpy(g_cfg.snd_acces, funx, sizeof(g_cfg.snd_acces)-1); break;
            case 25: strncpy(g_cfg.snd_zmizni, funx, sizeof(g_cfg.snd_zmizni)-1); break;
            case 26: strncpy(g_cfg.snd_intro, funx, sizeof(g_cfg.snd_intro)-1); break;
            case 27: strncpy(g_cfg.intro_obr, funx, sizeof(g_cfg.intro_obr)-1); break;
            case 28: strncpy(g_cfg.snd_appear, funx, sizeof(g_cfg.snd_appear)-1); break;
            case 29: strncpy(g_cfg.snd_theend, funx, sizeof(g_cfg.snd_theend)-1); break;
            case 30: strncpy(g_cfg.outro_obr, funx, sizeof(g_cfg.outro_obr)-1); break;
            case 31: strncpy(g_cfg.snd_score, funx, sizeof(g_cfg.snd_score)-1); break;
            case 32: strncpy(g_cfg.snd_zivot, funx, sizeof(g_cfg.snd_zivot)-1); break;
            case 33: strncpy(g_cfg.snd_maze, funx, sizeof(g_cfg.snd_maze)-1); break;
            case 34: strncpy(g_cfg.flik_start, funx, sizeof(g_cfg.flik_start)-1); break;
            case 35: strncpy(g_cfg.flik_end, funx, sizeof(g_cfg.flik_end)-1); break;
            case 36: strncpy(g_cfg.msg[1], funx, sizeof(g_cfg.msg[1])-1); break;
            case 37: strncpy(g_cfg.msg[2], funx, sizeof(g_cfg.msg[2])-1); break;
            case 38: strncpy(g_cfg.msg[3], funx, sizeof(g_cfg.msg[3])-1); break;
            case 39: strncpy(g_cfg.msg[4], funx, sizeof(g_cfg.msg[4])-1); break;
            case 40: strncpy(g_cfg.msg[5], funx, sizeof(g_cfg.msg[5])-1); break;
            case 41: { long v; val(funx,&v); g_cfg.timer = (unsigned short)v; break; }
            case 42: g_cfg.fli_abile = (strcmp(funx,"YES")==0); break;
            case 43: {
                int ja;
                for (ja = 1; ja <= 2; ja++)
                    if (strncmp(funx, g_language[ja], 3) == 0) { g_ja = (unsigned char)ja; g_cfg.ja_set = 1; break; }
                break;
            }
            case 44: strncpy(g_cfg.scroll_sub, funx, sizeof(g_cfg.scroll_sub)-1); break;
            case 45: strncpy(g_cfg.vec_opt, funx, sizeof(g_cfg.vec_opt)-1); break;
            case 46: strncpy(g_cfg.text_opt, funx, sizeof(g_cfg.text_opt)-1); break;
            case 47: strncpy(g_cfg.floor_opt, funx, sizeof(g_cfg.floor_opt)-1); break;
            case 48: g_cfg.test = (strcmp(funx,"YES")==0); break;
            case 49: strncpy(g_cfg.mapx, funx, sizeof(g_cfg.mapx)-1); break;
            case 50: strncpy(g_cfg.firstmap, funx, sizeof(g_cfg.firstmap)-1); break;
            case 51: g_cfg.crc_checking = (strcmp(funx,"YES")==0); break;
            case 52: { long v; val(funx,&v); g_cfg.inicializacna_pauza = (unsigned short)v; break; }
            case 53: strncpy(g_cfg.snd_fireball, funx, sizeof(g_cfg.snd_fireball)-1); break;
            case 54: strncpy(g_cfg.snd_fir, funx, sizeof(g_cfg.snd_fir)-1); break;
            case 55: g_cfg.use_joystick = (strcmp(funx,"YES")==0); break;
            case 56: strncpy(g_cfg.font, funx, sizeof(g_cfg.font)-1); break;
            case 57: strncpy(g_cfg.snd_change, funx, sizeof(g_cfg.snd_change)-1); break;
            case 58: {   /* SCAN: scan_x1,scan_x2,scan_y1,scan_y2 share ONE poradie */
                unsigned short c = 1;
                mov_num2(funx, &g_cfg.scan_x1, &c);
                mov_num2(funx, &g_cfg.scan_x2, &c);
                mov_num2(funx, &g_cfg.scan_y1, &c);
                mov_num2(funx, &g_cfg.scan_y2, &c);
                break;
            }
            case 60: g_cfg.smart_jump = (strcmp(funx,"YES")==0); break;
            case 62: {   /* SNDX: zvuky[m+basic_snd] := sc */
                long m; unsigned short c = 1;
                mov_num(funx, &m, &c);
                if (m >= 0 && m < 16)
                    mov_string(funx, g_cfg.zvuky[m + basic_snd],
                               (int)sizeof(g_cfg.zvuky[m + basic_snd]), &c);
                break;
            }
            case 63: { long v; val(funx,&v); g_cfg.start_stage = (unsigned char)v; break; }
            case 64: { unsigned short c = 1; mov_num2(funx,&g_cfg.freez_time,&c); mov_num2(funx,&g_cfg.unfreez_sound,&c); break; }
            case 65: { unsigned short c = 1; mov_num2(funx,&g_cfg.god_time,&c); mov_num2(funx,&g_cfg.ungod_sound,&c); break; }
            default: break;
        }
        break;
    }
    return found;
}

/* ===================================================================== */
/* load_config  (SI35.PAS / PREMEN35.INC load_config)                    */
/*                                                                       */
/*   Reads the external SIRIEL3.CFG setup file line by line and feeds    */
/*   each line to setup(), exactly like the Pascal routine.  This is the */
/*   ONLY place the game honours [ANIMS]=YES / [LANGUAGE] / [ZVUK] /      */
/*   [JOYSTICK] / [CRCCHECK] -- the DAT CONFIG block carries none of     */
/*   those keywords.  In particular it sets g_cfg.fli_abile from         */
/*   [ANIMS]=YES, which play_ani() (engine.c) guards on before it can    */
/*   load and show a level's [FLISTART] intro (e.g. AI1 in level 1).     */
/*   Without this the intro never plays, because no DAT block sets       */
/*   [ANIMS]=YES.                                                        */
/* ===================================================================== */
void load_config(void)
{
    static const char cfg_name[] = "SIRIEL3.CFG";   /* PREMEN35.INC chx */
    FILE *f;
    char line[512];

    /* subor_exist(chx) -- mirror the Pascal guard (PREMEN35.INC). */
    if (!subor_exist(cfg_name)) return;

    f = fopen(cfg_name, "rt");
    if (!f) return;
    while (fgets(line, sizeof(line), f)) {
        int len = (int)strlen(line);
        /* strip trailing CR/LF (readln in Pascal drops the EOL) */
        while (len > 0 && (line[len-1]=='\n' || line[len-1]=='\r'))
            line[--len] = '\0';
        if (len == 0) continue;        /* skip blank lines (Pascal eof guard) */
        setup(line);                   /* setup(fun) -- PREMEN35.INC */
    }
    fclose(f);
}

/* ===================================================================== */
/* load_level_list(meno, pole)  (LOAD235.PAS:2151)                       */
/*   Loads the CONFIG block of <sub>, dekoduj's it, and turns the        */
/*   [MENO]=.. / [ ...]=>Mn records into the levely^ table.              */
/* ===================================================================== */
void load_level_list(const char *sub)
{
    unsigned char buf[MAXLEN+1];
    char s[512], sx[512], sd[512];
    int countx, f;

    if (!g_levely) return;

    /* pole := 0; loadblock_array(sub, def_config='CONFIG', pole) */
    for (f = 0; f <= MAXLEN; f++) buf[f] = 0;
    if (dat_load_array(sub, "CONFIG", buf, sizeof(buf)) <= 0) return;

    /* for f:=0 to maxlen do begin if pole[f]<>0 then dekoduj(1,pole[f]); end;
     * dekoduj(1,..) = +2 (mod 256). */
    for (f = 0; f <= MAXLEN; f++)
        if (buf[f] != 0) buf[f] = (unsigned char)(buf[f] + 2);

    countx = 0;
    g_levely->pocet = 0;
    s[0] = '\0';

    for (;;) {
        int b = (countx < MAXLEN+1) ? buf[countx] : 0;
        if (b > 15) {
            int sl = (int)strlen(s);
            if (sl < (int)sizeof(s)-1) { s[sl] = (char)b; s[sl+1] = '\0'; }
        } else if (b == 13) {
            get_name_normal(s, sx, sizeof(sx));
            if (strcmp(sx, "MENO") == 0) {
                get_funk_normal(s, sx, sizeof(sx));
                if (g_num_disks >= 1)
                    check_lan(g_data_disks[g_num_disks].meno, sx, sizeof(g_data_disks[g_num_disks].meno));
            } else if ((int)strlen(s) > 0 && s[0] == '[') {
                if (!setup(s)) {
                    sd[0] = '\0';
                    if (check_lan(sd, sx, sizeof(sd)) == 0)
                        g_levely->pocet++;
                    if (g_levely->pocet >= 1 && g_levely->pocet <= 19)
                        check_lan(g_levely->lev[g_levely->pocet].meno, sx, sizeof(g_levely->lev[g_levely->pocet].meno));
                    get_funk_normal(s, sx, sizeof(sx));
                    if (g_levely->pocet >= 1 && g_levely->pocet <= 19)
                        check_lan(g_levely->lev[g_levely->pocet].subor, sx, sizeof(g_levely->lev[g_levely->pocet].subor));
                }
            }
            s[0] = '\0';
        }
        countx++;
        int nb = (countx < MAXLEN+1) ? buf[countx] : 0;
        if (countx > MAXLEN || nb == 0) break;
    }
}

/* ===================================================================== */
/* load_basic_config  (SI35.PAS)                                         */
/*   Scan *.dat / *.DAT, keep files with a SIRIEL35 block, parse each    */
/*   disk version, and load its level list.  Uses datx scan_disks +     */
/*   dat_load_array, so only the Pascal orchestration lives here.       */
/* ===================================================================== */
void load_basic_config(void)
{
    diskx disks[DAT_MAX_RECORDS];
    int n, f;

    g_num_disks = 0;

    /* scan_disks('*.dat') then scan_disks('*.DAT') -- datx appends only
     * files that pass the SIRIEL35 header check, sorted by name reversed. */
    n = scan_disks("*.dat", disks, DAT_MAX_RECORDS);
    if (n < 0) n = 0;
    if (n < DAT_MAX_RECORDS)
        n += scan_disks("*.DAT", disks + n, DAT_MAX_RECORDS - n);

    /* SCAN reveal-window defaults (GAME.INC out_sounds_to_def, GAME.INC:1211).
       The Pascal boot sets scan_x1=1, scan_x2=2, scan_y1=1, scan_y2=1 BEFORE
       any DAT CONFIG is parsed, so a level with no [SCAN] option still reveals
       a 4x3 window around the avatar.  Without this the C-C default stays
       0,0,0,0 (a 1x1 window = only the player's own floor cell, whose tile
       index 0 is fully transparent) and the "hidden in dark" maze stays
       totally black.  The DAT [SCAN] option (setup case 58) overrides below. */
    g_cfg.scan_x1 = 1;
    g_cfg.scan_x2 = 2;
    g_cfg.scan_y1 = 1;
    g_cfg.scan_y2 = 1;

    for (f = 0; f < n && f < 19; f++) {
        g_num_disks++;
        g_data_disks[g_num_disks].verzia = disks[f].verzia;
        strncpy(g_data_disks[g_num_disks].subor, disks[f].subor,
                sizeof(g_data_disks[g_num_disks].subor)-1);
        g_data_disks[g_num_disks].meno[0] = '\0';   /* filled by load_level_list */
        /* load this disk's level list (MENO sets data_disks^[num_disks].meno) */
        load_level_list(disks[f].subor);
    }

    if (g_num_disks == 0) return;     /* errormes(3) in the Pascal build */

    /* placeholder: first disk, so boot-time sound loading has a source.
     * The real selection (state 0) reloads the chosen disk afterwards. */
    strncpy(g_meno_disku, g_data_disks[1].subor, sizeof(g_meno_disku)-1);
    /* the level blocks (M1..M12) live in this DAT -- remember it so the
       menu-driven states can read a level's [MENO]/[MSG1]/[MAPA] block. */
    g_level_dat = g_data_disks[1].subor;
}

/* ===================================================================== */
/* load_level_block / level_field  (level-block readers)                 */
/*                                                                       */
/* load_predmet2 (LOAD235.PAS:753) -- the full level loader -- is NOT     */
/* ported yet (it needs vec^[], st, priechody, maps, ...).  The menu-     */
/* driven states only need two leaves of it:                            */
/*   * level_needs_password() reads the level's [MENO] to detect the     */
/*     '>' password marker and the password value.                      */
/*   * briefing_init() reads the level's [MSG1] objective text.          */
/*                                                                       */
/* These two helpers load ONE level block and pull a single [FIELD]=value*/
/* line out of it, mirroring load_predmet2's `loadblock_array + dekoduj`  */
/* and load_level_list's get_name_normal/get_funk_normal line parse.      */
/* ===================================================================== */
int load_level_block(const char *dat, const char *sub,
                     unsigned char *buf, int bufsz)
{
    char sub2[64];
    int n, f;

    /* sub carries the leading '>' (">M1") when it marks a DAT-block level
       (that is how levely^.lev[f].subor is stored after load_level_list).
       load_predmet2 strips it (sub:=out_string(sub)) before the
       loadblock_array, so we do the same here to look up the bare name. */
    strncpy(sub2, sub, sizeof(sub2)-1);
    sub2[sizeof(sub2)-1] = '\0';
    if (sub2[0] == '>') out_string(sub2, sizeof(sub2));

    n = dat_load_array(dat, sub2, buf, bufsz);
    if (getenv("ENGINE_DEBUG"))
        fprintf(stderr, "[L235] load_level_block dat='%s' sub='%s' -> n=%d bufsz=%d\n",
                (dat ? dat : "(null)"), sub2, n, bufsz);
    if (n <= 0) return 0;

    /* dekoduj(+2) -- identical transform load_level_list applies to its
       CONFIG block (LOAD235.PAS: `if pole[f]<>0 then dekoduj(1,pole[f])`).
       NOTE: `bufsz` is the buffer SIZE, so valid indices are 0..bufsz-1;
       the original Pascal loop `for f:=0 to maxlen` is inclusive because
       its `pole` is array[0..maxlen] (maxlen+1 bytes == our bufsz).  Using
       `f <= bufsz` here read/wrote buf[bufsz] -- one byte PAST the array,
       which corrupted the stack canary (macOS clang enables -fstack-protector
       by default) and aborted.  Bound is now `f < bufsz`. */
    for (f = 0; f < bufsz; f++)
        if (buf[f] != 0) buf[f] = (unsigned char)(buf[f] + 2);
    buf[n < bufsz ? n : bufsz-1] = 0;     /* NUL-terminate the scan */
    return n;
}

int level_field(const unsigned char *buf, const char *field,
                char *out, int outsz)
{
    char s[512], sx[512];
    int f, b;

    s[0] = '\0';
    if (out) out[0] = '\0';

    /* Mirror load_level_list's line scan: bytes >15 form the line text, a
       13 (CR) ends a line and triggers the get_name_normal/get_funk_normal
       extract, and the NUL terminator ends the block. */
    for (f = 0; buf[f] != 0; f++) {
        b = buf[f];
        if (b > 15) {
            int sl = (int)strlen(s);
            if (sl < (int)sizeof(s)-1) { s[sl] = (char)b; s[sl+1] = '\0'; }
        } else if (b == 13) {
            get_name_normal(s, sx, sizeof(sx));
            if (strcmp(sx, field) == 0) {
                get_funk_normal(s, sx, sizeof(sx));
                if (out) { strncpy(out, sx, outsz-1); out[outsz-1] = '\0'; }
                return 1;
            }
            s[0] = '\0';
        }
    }
    return 0;
}

/* ===================================================================== */
/* vec^[] object storage + object-branch loaders                         */
/*   (LOAD235.PAS load_predmet2: Z/X/Y/V branches, prirad, pridaj2)     */
/*                                                                       */
/* predmet is the Siriel on-screen object record (see vec-migration.md, */
/* ABI-verified, packed, 316 bytes).  Pascal vec is 1-based (vec^[1..200]);*/
/* g_vec[0] is a guard slot.  These live in load235.c so the pure-C-C     */
/* engine owns them (no FPC wire is linked here).                        */
/* ===================================================================== */
#include "vec_ext.h"

predmet g_vec[201];                        /* vec^[1..200] + guard slot [0] */unsigned short g_nahrane_veci = 0;         /* nahrane_veci : #objects loaded  */

/* count : the token pointer used by mov_num/mov_string/mov_num2.  Pascal
   resets it to 1 at the top of every line of load_predmet2's loop; the
   object branches (prirad/pridaj2) read from it too, so it is a unit-global. */
unsigned short count = 1;

#define NUM_OPT 66

/* defined(s) : LOAD235.PAS:742 -- TRUE if s matches a CONFIG option keyword.
   option[] is uppercase and the DAT keywords are uppercase too, so we
   compare the upcased keyword (matches the Pascal intent). */
static int defined(const char *s)
{
    int f;
    for (f = 1; f <= NUM_OPT; f++)
        if (strcmp(option[f], s) == 0) return 1;
    return 0;
}

/* set_meno(v, s) : vec^[l].meno := s   (Pascal string[5]: len@0, chars@1..5) */
static void set_meno(predmet *v, const char *s)
{
    unsigned char n = (unsigned char)strlen(s);
    if (n > 5) n = 5;
    v->len = n;
    memcpy(v->c, s, n);      /* c[0..4]  ==  meno[1..5] */
}

/* prirad(sx, l) : LOAD235.PAS:539 -- attach an X/Y object.  (num param is
   unused in the Pascal body.) */
static void prirad(const char *sx, unsigned short *l)
{
    char ciel[256];
    predmet *v = &g_vec[(*l) + 1];   /* vec^[ inc(l) ] */
    (*l)++;
    get_name_normal(sx, ciel, sizeof(ciel));  /* get_name_normal(sx,ciel) */
    set_meno(v, ciel);                        /* vec^.meno := ciel */
    v->smer = 0; v->z1 = 0; v->z2 = 0;
    get_funk(sx, ciel, sizeof(ciel));         /* get_funk(sx,ciel) */
    M16(ciel, obr);
    M16(ciel, x);
    v->x = (unsigned short)(v->x * 8 + 8);
    M16(ciel, y);
    v->y = (unsigned short)(v->y * 8 + 8);
    M16(ciel, funk);
    v->mie = (unsigned short)(unsigned char)v->c[3];   /* ord(meno[4]) */
    if ((unsigned char)v->c[3] < 'B') v->mie = 1;   /* if vec^.meno[4]<'B' */
    v->take = 4;
    switch (v->funk) {
        case 0:  v->useanim = 1; break;
        case 1:  M16(ciel, inf1);
                 M16(ciel, inf2);
                 v->useanim = 1; break;
        case 2:
        case 3:  M16(ciel, inf1);
                 M16(ciel, inf2);
                 M16(ciel, inf3);
                 M16(ciel, inf7);
                 v->inf4 = 0;
                 v->inf1 = (unsigned short)(v->inf1 * 8 + 8);
                 v->inf2 = (unsigned short)(v->inf2 * 8 + 8);
                 v->useanim = 0; break;
        case 4:  M16(ciel, inf1);
                 M16(ciel, inf7);
                 v->smer = (v->inf7 == 0) ? 1 : 0;
                 v->inf5 = v->x;
                 v->inf6 = v->y;
                 v->useanim = 0; break;
        case 5:  M16(ciel, inf1);
                 M16(ciel, inf7);
                 v->inf5 = v->x;
                 v->inf6 = v->y;
                 v->useanim = 0; break;
        case 6:  M16(ciel, inf1);
                 M16(ciel, inf2);
                 M16(ciel, inf3);
                 M16(ciel, inf4);
                 M16(ciel, inf5);
                 v->useanim = 1; break;
        case 7:
        case 8:
        case 10: M16(ciel, inf1);
                 v->useanim = 1; break;
        case 9:  M16(ciel, inf1);
                 v->useanim = 1;
                 /* LOAD235.PAS:606 case 9: completer:=vec^[l].inf1 -- the
                    funk=9 exit door's inf1 selects the completion test
                    (here 1: done once every visible-layer Z collectible is
                    picked up). */
                 completer = v->inf1; break;
        case 11: M16(ciel, inf1);
                 v->useanim = 0;
                 switch (v->inf1) {
                     case 2:
                     case 3: M16(ciel, inf2);
                               M16(ciel, inf3);
                               M16(ciel, inf4);
                               M16(ciel, inf5);
                               break;
                 }
                 break;
        case 12: M16(ciel, inf1);
                 M16(ciel, inf2);
                 v->useanim = 0; break;
        case 13: M16(ciel, inf1);
                 M16(ciel, inf2);
                 v->inf3 = v->mie;
                 v->useanim = 0; break;
        case 14: M16(ciel, inf1);
                 M16(ciel, inf2);
                 M16(ciel, inf3);
                 v->useanim = 1; break;
        case 15: M16(ciel, inf1);
                 M16(ciel, inf2);
                 v->inf2 = (unsigned short)(v->inf2 * 8 + 8);
                 M16(ciel, inf3);
                 M16(ciel, inf4);
                 v->useanim = 1; break;
        case 16:
        case 17: M16(ciel, inf1);
                 M16(ciel, inf2);
                 M16(ciel, inf3);
                 M16(ciel, inf4);
                 v->useanim = 0;
                 if (v->funk == 17) v->useanim = 1;
                 if (v->inf2 == 0) v->inf5 = 1;
                 break;
        case 18: M16(ciel, inf1);
                 M16(ciel, inf2);
                 v->inf2 = (unsigned short)(v->inf2 * 8 + 8);
                 M16(ciel, inf3);
                 M16(ciel, inf4);
                 v->useanim = 1;
                 mov_num2(ciel, &v->z1, &count);
                 mov_num2(ciel, &v->z2, &count);
                 break;
        case 19: M16(ciel, inf1);
                 M16(ciel, inf2);
                 mov_num2(ciel, &v->z1, &count);
                 mov_num2(ciel, &v->z2, &count);
                 v->useanim = 1; break;
        default: break;
    }
    v->ox = v->x; v->oy = v->y;
    v->oox = v->x; v->ooy = v->y;
    g_nahrane_veci = *l;             /* load_predmet2: nahrane_veci:=l after prirad */
}

/* pridaj2(s, l, update) : LOAD235.PAS:448 -- attach a pick-up 'W' object. */
static void pridaj2(const char *s, unsigned short *l, int update)
{
    char ciel[256];
    predmet *v = &g_vec[(*l) + 1];
    count = 1;                          /* pridaj2 resets count itself */
    (*l)++;
    get_name_normal(s, ciel, sizeof(ciel));  /* get_name_normal(s,ciel) */
    set_meno(v, ciel);                       /* vec^.meno := ciel */
    get_funk_normal(s, ciel, sizeof(ciel)); /* get_funk_normal(s,ciel) */
    M16(ciel, cislo);
    M16(ciel, obr);
    M16(ciel, x);
    M16(ciel, y);
    M16(ciel, funk);
    M16(ciel, x1);
    M16(ciel, y1);
    M16(ciel, x2);
    M16(ciel, y2);
    switch (v->funk) {
        case 1: M16(ciel, inf1); break;
        case 2: M16(ciel, inf1);
                M16(ciel, inf2);
                M16(ciel, inf3);
                M16(ciel, inf4);
                M16(ciel, inf5);
                break;
        case 4: M16(ciel, inf1);
                M16(ciel, inf2);
                M16(ciel, inf3);
                break;
        default: break;
    }
    M16(ciel, inf7);
    M16(ciel, st);
    if (v->st > 1) v->st = (unsigned short)(v->st + 126);
    if (update) {
        v->x = (unsigned short)(v->x * 8 + 8);
        v->y = (unsigned short)(v->y * 8 + 8);
        v->x1 = (unsigned short)(v->x1 * 8 + 8);
        v->y1 = (unsigned short)(v->y1 * 8 + 8);
        v->x2 = (unsigned short)(v->x2 * 8 + 8);
        v->y2 = (unsigned short)(v->y2 * 8 + 8);
        if ((unsigned char)v->c[3] < 'B') v->mie = 1;
        else v->mie = (unsigned short)(unsigned char)v->c[3];
        v->take = 4;
    }
    v->ox = v->x; v->oy = v->y;
    g_nahrane_veci = *l;             /* load_predmet2: nahrane_veci:=l after pridaj2 */
}

/* ===================================================================== */
/* [TEXT] table -- the text portion of handles[3] (AKTIV35.PAS).         */
/*                                                                       */
/* Pascal: pocet_textov=255 (MAX_TEXT_LINES), dlzka_textu=100 (TEXT_LEN). */
/*   uloz_text(s,n) stores the script of a [TEXT]=n,<script>; line at    */
/*   index n;  vrat_text(n) returns it.  The C-C engine has no XMS       */
/*   handle, so the 255x100 table below stands in for handles[3]'s text  */
/*   region (offset posuv_textu = pocet_veci*21).  It is cleared at the  */
/*   top of every load_level_map() so a level sees only its own text.    */
/* ===================================================================== */
#define MAX_TEXT_LINES 255     /* pocet_textov  (AKTIV35.PAS:14) */
#define TEXT_LEN 100           /* dlzka_textu   (AKTIV35.PAS:15) */
static char g_text[MAX_TEXT_LINES + 1][TEXT_LEN];   /* index 1..255 (0 unused) */

/* uloz_text(s,n) -- LOAD235.PAS uloz_text.  Store the script of a          */
/* [TEXT]=n,<script>; line at index n (capped to TEXT_LEN-1, like the       */
/* fixed 100-byte Pascal entry). */
void uloz_text_c(const char *s, unsigned short n)
{
    unsigned int i = 0;
    if (n >= 1 && n <= MAX_TEXT_LINES) {
        for (; s[i] && i < TEXT_LEN - 1; i++)
            g_text[n][i] = s[i];
        g_text[n][i] = '\0';
    }
}

/* vrat_text(n,dst,sz) -- LOAD235.PAS vrat_text.  Return the script stored  */
/* at index n (empty when n is out of range or unset).  Called by          */
/* pouzi_predmet_init() to feed the step-able [TEXT] dialog (pp_s).         */
void vrat_text(unsigned short n, char *dst, int sz)
{
    if (n >= 1 && n <= MAX_TEXT_LINES && sz > 0) {
        strncpy(dst, g_text[n], sz - 1);
        dst[sz - 1] = '\0';
    } else if (sz > 0) {
        dst[0] = '\0';
    }
}

/* ===================================================================== */
/* [VEC] name table  (LOAD235.PAS uloz_nazov / vatr_nazov)               */
/*                                                                       */
/* Pascal stores each pickable item's name in handles[3] at a 21-stride  */
/* slot (20-byte entry): uloz_nazov(s,f) -> CopyCMemToXMem(handles[3].h,  */
/* 21*(f-1), @s, 20).  The C-C engine has no XMS handle, so g_nazov[]    */
/* stands in for that region.  It is cleared at the top of every         */
/* load_level_map() so a level sees only its own [VEC] names.          */
/* ===================================================================== */
#define MAX_NAZOV 255     /* pocet_veci-ish bound (byte index 1..255)   */
static char g_nazov[MAX_NAZOV + 1][21];   /* index 1..255 (0 unused), 21-stride */

/* uloz_nazov_c(s,f) -- LOAD235.PAS uloz_nazov.  Store the pickable item
   name at index f (capped to the 20-byte slot, null-padded like the fixed
   Pascal entry). */
void uloz_nazov_c(const char *s, unsigned short f)
{
    unsigned int i = 0;
    if (f >= 1 && f <= MAX_NAZOV) {
        for (; s[i] && i < 20; i++)
            g_nazov[f][i] = s[i];
        for (; i < 20; i++)
            g_nazov[f][i] = '\0';
    }
}

/* vatr_nazov_c(f) -- LOAD235.PAS vatr_nazov.  Return the name stored at
   index f (empty when f is out of range or unset).  Called by
   cc_print_predmet2()'s inventory display. */
const char *vatr_nazov_c(unsigned short f)
{
    return (f >= 1 && f <= MAX_NAZOV) ? g_nazov[f] : "";
}

/* ===================================================================== */
/* load_level_map(dat, sub)  (LOAD235.PAS: load_predmet2)                */
/*                                                                       */
/* Faithful port of load_predmet2's line loop: loads the <sub> block from */
/* DAT <dat>, applies the dekoduj(+2) transform, scans the [KEYWORD]=    */
/* lines with the exact Pascal line-reader, and dispatches each line to  */
/* the object branches (Z/X/Y/V -> vec^[]) or the option table (MAPA,    */
/* MENO, OBR, TYP, ...).  The MAPA option reads the 39x27 grid into      */
/* st.mie using the verbatim Pascal loop: cell = ord(ch) - 15 ;          */
/* dec(znak) on CR/LF (this skips the trailing CR of each stored row).   */
/* ===================================================================== */
void load_level_map(const char *dat, const char *sub)
{
    unsigned char buf[MAXLEN_LEVEL + 1];
    char line[MAXLEN_LEVEL + 1];
    unsigned short cxa, f;
    unsigned short l = 0;         /* l : vec^[] index (load_predmet2) */
    unsigned short aktual = 1;    /* load_predmet2: aktual:=1  (STARTMAP)   */
    char sx[512];
    int reloaded = 0;             /* load_predmet2: reloaded -- a MAPX room was read */

    /* stage := empty; st.stav := 1  (load_predmet2: aktual:=1; st.stav default) */
    memset(&st, 0, sizeof(st));
    st.stav = 1;
    /* reset the render thresholds to defaults (set_def: invisible:=def_invisible=255).
       A level's [INVISIBLE] option below may override g_invisible. */
    g_invisible = 255;
    g_inusable = 0;
    /* set_def default (LOAD235.PAS:2100 completer:=def_completer=1) runs
       BEFORE load_predmet2, so the level's funk=9 door (prirad) can override it.
       Placed here, before the object loop, so the loader value wins over this
       default -- exactly the Pascal set_def -> load_predmet2 ordering. */
    completer = 1;

    /* sub carries a leading '>' when it is levely^.lev[f].subor (">M1").
       load_predmet2 strips it (sub:=out_string(sub)) before loadblock_array. */
    if (sub[0] == '>') sub++;

    /* loadblock_array(zvukovy_subor, sub, arr^) */
    if (dat_load_array(dat, sub, buf, sizeof(buf)) <= 0) return;

    /* for f:=0 to maxlen do begin if arr^[f]<>0 then inc(arr^[f],2); end; */
    for (f = 0; f <= MAXLEN_LEVEL; f++)
        if (buf[f] != 0) buf[f] = (unsigned char)(buf[f] + 2);

    /* [TEXT] table fresh for this level -- mirrors a fresh handles[3]: only
       this level's own [TEXT]=n,<script>; lines are visible to the dialog. */
    memset(g_text, 0, sizeof(g_text));
    /* [VEC] name table fresh for this level -- mirrors a fresh handles[3]:
       only this level's own [VEC]=m,<name>; lines are visible to the pocket. */
    memset(g_nazov, 0, sizeof(g_nazov));

    cxa = 0;

    /* repeat ... until (arr^[cxa]=0)   -- the Pascal repeat-until line loop */
    while (cxa <= MAXLEN_LEVEL && buf[cxa] != 0) {
        int sl;
        char name[64];

        count = 1;              /* count:=1  (top of the Pascal repeat) */

        /* line reader: s:=s+chr(arr^[cxa]); inc(cxa);
             until arr^[cxa] in {13,10,0}; if arr^[cxa]=10 then inc(cxa). */
        sl = 0;
        while (1) {
            if (cxa > MAXLEN_LEVEL) break;
            line[sl++] = buf[cxa];
            cxa++;
            if (cxa > MAXLEN_LEVEL || buf[cxa] == 13 || buf[cxa] == 10 || buf[cxa] == 0)
                break;
        }
        if (cxa <= MAXLEN_LEVEL && buf[cxa] == 10) cxa++;   /* skip lone LF */
        line[sl] = '\0';

        /* get_name_normal(s, sx) -> the [KEYWORD] */
        get_name_normal(line, name, sizeof(name));
        if (name[0] == '\0') continue;
        upcased(name);                 /* sc := upcased(name) */

        /* load_predmet2 object/option dispatch (LOAD235.PAS:787).  The
           line-reader above already consumed the whole line, so the object
           branches parse the in-memory <line> exactly like Pascal. */
        if (name[0] == 'Z' && !defined(name)) {
            /* Z<name> object (LOAD235.PAS:794) */
            long lm = 0;
            char fv[512];
            predmet *v = &g_vec[++l];
            g_nahrane_veci = l;
            val(name, &lm);            /* val(sx,vec^.inf1,err) -- sx=keyword */
            v->inf1 = (unsigned short)lm;
            set_meno(v, name);         /* vec^.meno := sx */
            get_funk(line, fv, sizeof(fv));  /* get_funk(s,sx) */
            M16(fv, obr);
            M16(fv, x);
            M16(fv, y);
            v->x = (unsigned short)(v->x * 8 + 8);
            v->y = (unsigned short)(v->y * 8 + 8);
            M16(fv, mie);
            if ((unsigned char)v->c[3] < 'A') v->mie = 1;   /* if vec^.meno[4]<'A' */
            M16(fv, take);
            M16(fv, inf1);
            v->funk = 0;
            v->useanim = 1;
            v->ox = v->x; v->oy = v->y;
        } else if ((name[0] == 'X' || name[0] == 'Y') && !defined(name)) {
            /* X/Y object -> prirad (LOAD235.PAS:810) */
            prirad(line, &l);
        } else if (name[0] == 'W' && !defined(name)) {
            /* W object -> pridaj2 (LOAD235.PAS:813) */
            pridaj2(line, &l, 1);
        } else if (name[0] == 'V' && !defined(name)) {
            /* V object (LOAD235.PAS:816) */
            char fv[512];
            predmet *v = &g_vec[++l];
            g_nahrane_veci = l;
            set_meno(v, name);
            get_funk(line, fv, sizeof(fv));
            M16(fv, obr);
            M16(fv, x);
            M16(fv, y);
            M16(fv, inf7);
            v->x = (unsigned short)(v->x * 8 + 8);
            v->y = (unsigned short)(v->y * 8 + 8);
            v->funk = 0;
            v->useanim = 1;
            v->ox = v->x; v->oy = v->y;
            v->mie = (unsigned short)(unsigned char)v->c[3];  /* ord(meno[4]) */
            if ((unsigned char)v->c[3] < 'B') v->mie = 1;
            v->take = 4;
        } else if (strcmp(name, "MAPA") == 0) {
            /* option 4: read the 39x27 map.  Faithful to the Pascal
               `for znak:=0 to mie_x do begin ch:=arr^[cxa]; inc(cxa);
               st.mie[znak,linex]:=ord(ch)-15; if ch in {10,13} dec(znak) end;`
               -- the write happens BEFORE dec(znak), and the for-loop's
               post-increment turns dec(znak) (->-1) back into 0, which is
               exactly what skips the trailing CR of each stored row. */
            unsigned short linex, znak, ch;
            for (linex = 0; linex <= MIE_Y; linex++) {
                znak = 0;
                while (znak <= MIE_X) {
                    if (cxa > MAXLEN_LEVEL) break;
                    ch = buf[cxa++];
                    st.mie[znak][linex] = (unsigned char)(ch - 15);
                    if (ch == 10 || ch == 13) znak--;   /* dec(znak) */
                    znak++;                              /* for post-inc */
                }
            }
            save_map(1);              /* load_predmet2: `save_map(1)` after MAPA */
            continue;
        } else if (strcmp(name, "VEC") == 0) {
            /* option 45 (LOAD235.PAS:965): [VEC]=m,<name>;  store the
               pickable item's name at index m in the handles[3] name table.
               Faithful to the Pascal:
                 count:=1; mov_num(sx,m,count)  -> the item index m
                 s:=kill_strings(sx,',')        -> the name after the first comma
                 check_lan2(sc,s)               -> ~LANG~ translation
                 if sc<>'' then uloz_nazov(sc,m)
               (kill_strings only reads <sx>; the C port slices it with strchr,
               into the separate <s> buffer below, exactly like the [TEXT] path.) */
            unsigned short m = 0;
            char s[TEXT_LEN];
            char sc[TEXT_LEN];
            long lm = 0;
            get_funk_normal(line, sx, sizeof(sx));  /* sx := value after [VEC]= */
            count = 1;                               /* mov_num token starts at 1 */
            mov_num(sx, &lm, &count);               /* m := the item index */
            m = (unsigned short)lm;
            /* s := kill_strings(sx,',') -- everything after the first comma */
            {
                const char *comma = strchr(sx, ',');
                unsigned int k = comma ? (unsigned int)(comma - sx) + 1 : 0;
                unsigned int i = 0;
                for (; k <= (unsigned int)strlen(sx) && i < (sizeof(s) - 1); k++, i++)
                    s[i] = sx[k];
                s[i] = '\0';
            }
            check_lan2(sc, s, sizeof(sc));        /* check_lan2(sc,s) -- option 45 */
            if (sc[0])
                uloz_nazov_c(sc, (unsigned short)m);
            continue;
        } else if (strcmp(name, "MAPX") == 0) {
            /* option 49 (LOAD235.PAS:988): [MAPX]=m  -- a second/third/...
               room.  Reads the 39x27 grid into st.mie (same loop as MAPA),
               saves it at slot m, and sets reloaded so the starting room is
               restored at end-of-load.  Without this the extra rooms are
               never written to map_buf, so entering room 2/3 draws blanks. */
            unsigned short linex, znak, ch, m = 0;
            long lm = 0;
            get_funk_normal(line, sx, sizeof(sx));  /* sx := value after [MAPX]= */
            val(sx, &lm);                           /* m := the room number */
            m = (unsigned short)lm;
            for (linex = 0; linex <= MIE_Y; linex++) {
                znak = 0;
                while (znak <= MIE_X) {
                    if (cxa > MAXLEN_LEVEL) break;
                    ch = buf[cxa++];
                    st.mie[znak][linex] = (unsigned char)(ch - 15);
                    if (ch == 10 || ch == 13) znak--;   /* dec(znak) */
                    znak++;                              /* for post-inc */
                }
            }
            save_map(m);              /* load_predmet2: `save_map(m)` after MAPX */
            reloaded = 1;             /* load_predmet2: reloaded:=true */
            continue;
        } else if (strcmp(name, "MENO") == 0) {
            get_funk_normal(line, sx, sizeof(sx));
            strncpy(st.meno, sx, sizeof(st.meno) - 1);
            st.meno[sizeof(st.meno) - 1] = '\0';
        } else if (strcmp(name, "OBR") == 0) {
            get_funk_normal(line, sx, sizeof(sx));
            strncpy(st.obr, sx, sizeof(st.obr) - 1);
            st.obr[sizeof(st.obr) - 1] = '\0';
        } else if (strcmp(name, "TYP") == 0) {
            long lm = 0;
            get_funk_normal(line, sx, sizeof(sx));   /* sx := funk value */
            val(sx, &lm);
            st.stav = (unsigned char)lm;
        } else if (strcmp(name, "INVISIBLE") == 0) {
            /* option 16: invisible tile threshold (LOAD235.PAS:924).
               val(sx,m); if m=0 then m:=def_invisible(255); invisible:=m. */
            long lm = 0;
            get_funk_normal(line, sx, sizeof(sx));
            val(sx, &lm);
            if (lm == 0) lm = 255;
            g_invisible = (unsigned char)lm;
        } else if (strcmp(name, "TIMER") == 0) {
            /* option 41: the level time limit (seconds).  load_predmet2:
               val(sx,timer,err).  Drives the bottom-bar countdown (time_out). */
            long lm = 0;
            get_funk_normal(line, sx, sizeof(sx));
            val(sx, &lm);
            g_cfg.timer = (unsigned short)lm;
        } else if (strcmp(name, "FLISTART") == 0) {
            /* option 34: the level-start intro animation block name.
               load_predmet2: check_lan(flik_start, sx).  The value is a
               mov_string pair "<FLIBLOCK>,<SND>" (e.g. AI1,ZAI1); the FLI
               block name is the first token, parsed by play_ani(). */
            get_funk_normal(line, sx, sizeof(sx));
            strncpy(g_cfg.flik_start, sx, sizeof(g_cfg.flik_start) - 1);
            g_cfg.flik_start[sizeof(g_cfg.flik_start) - 1] = '\0';
        } else if (strcmp(name, "FLIEND") == 0) {
            /* option 35: the level-end intro animation block name. */
            get_funk_normal(line, sx, sizeof(sx));
            strncpy(g_cfg.flik_end, sx, sizeof(g_cfg.flik_end) - 1);
            g_cfg.flik_end[sizeof(g_cfg.flik_end) - 1] = '\0';
        } else if (strcmp(name, "ANIMS") == 0) {
            /* option 42: enables FLI playback for this level.  load_predmet2:
               if sx=yes then fli_abile:=true.  Without it the intro never
               plays (play_ani guards on fli_abile). */
            get_funk_normal(line, sx, sizeof(sx));
            g_cfg.fli_abile = (strcmp(sx, "YES") == 0) ? 1 : 0;
        } else if (strcmp(name, "FLOOR") == 0) {
            /* option 47: floor/inusable threshold (LOAD235.PAS:977). */
            long lm = 0;
            get_funk_normal(line, sx, sizeof(sx));
            val(sx, &lm);
            g_inusable = (unsigned char)lm;
        } else if (strcmp(name, "FIRSTMAP") == 0) {
            /* option 50 (LOAD235.PAS:994): sets the STARTMAP / aktual value
               that decides the starting room.  val(sx,m); aktual:=m. */
            long lm = 0;
            get_funk_normal(line, sx, sizeof(sx));
            val(sx, &lm);
            if (lm > 0) aktual = (unsigned short)lm;
        } else if (strcmp(name, "START") == 0) {
            /* option 3 (LOAD235.PAS STARTOVACIE POZICIE): the panak avatar
               start position.  mov_num(sx,m,count); si.x:=m; mov_num(sx,m,
               count); si.y:=m; then si.oldx:=si.x; si.oldy:=si.y;
               startx:=si.x; starty:=si.y.  This sets the engine avatar
               position (cc_set_start_pos) so draw_state() places the figure
               at the level-defined tile instead of a fixed placeholder. */
            long mx = 0, my = 0;
            get_funk_normal(line, sx, sizeof(sx));
            count = 1;                 /* mov_num token starts at 1 (Pascal) */
            mov_num(sx, &mx, &count);  /* si.x  */
            mov_num(sx, &my, &count);  /* si.y  */
            cc_set_start_pos((unsigned short)mx, (unsigned short)my);
        } else if (strcmp(name, "TEXT") == 0) {
            /* option 46 (LOAD235.PAS:971): [TEXT]=n,<script>;  store the
               script at index n so pouzi_predmet() can show it via
               vrat_text(n).  Faithful to the Pascal:
                 mov_num(sx,m,count)  -> the text index n
                 kill_strings(sx,',') -> the script after the first comma
                 check_lan2(sc,s)     -> ~LANG~ translation (check_lan)
                 if sc<>'' then uloz_text(sc,m) */
            long n = 0;
            char tv[512];
            char script[TEXT_LEN * 4];
            char sc[TEXT_LEN];
            get_funk_normal(line, tv, sizeof(tv));   /* tv := value after [TEXT]= */
            count = 1;                               /* mov_num token starts at 1 */
            mov_num(tv, &n, &count);                 /* n := the text index */
            /* script := kill_strings(tv,',') -- everything after the first comma */
            {
                const char *comma = strchr(tv, ',');
                unsigned int k = comma ? (unsigned int)(comma - tv) + 1 : 0;
                unsigned int i = 0;
                for (; k <= (unsigned int)strlen(tv) && i < (sizeof(script) - 1); k++, i++)
                    script[i] = tv[k];
                script[i] = '\0';
            }
            check_lan2(sc, script, sizeof(sc));     /* check_lan2(sc,s) -- LOAD235.PAS option 46 */
            if (sc[0] && n >= 1 && n <= MAX_TEXT_LINES)
                uloz_text_c(sc, (unsigned short)n);
        }
        /* other options (SNDSTART, MSG1, ...) are read by the line-reader
           already; their values are not needed here. */
    }

    /* load_predmet2 end-of-load.  A MAPX room overwrote st.mie with the last
       room's grid, so restore the starting room first (LOAD235.PAS:1047):
           if reloaded then load_map(aktual);
       then set the current room (LOAD235.PAS:1048):
           if aktual>1 then miestnost:=aktual+126 else miestnost:=1 ;
       This is the current room that cc_print_predmet2() filters vec^[]
       objects by (vec.mie==miestnost). */
    if (reloaded) load_map(aktual);
    g_miestnost = (aktual > 1) ? (unsigned short)(aktual + 126) : 1;
}

/* ===================================================================== */
/* save_map / load_map  (LOAD235.PAS: save_map / load_map)                */
/*                                                                       */
/* Faithful ports.  In Pascal these move the 40x27 tile-index grid to and */
/* from handles[5] (a `map_size = 40*27*num_maps` XMS handle) via         */
/* CopyCMemToXMem / CopyXMemToCMem.  The C-C engine has no XMS layer, so  */
/* map_buf stands in for handles[5] with the SAME layout: num_maps        */
/* contiguous 40-col x 27-row grids (each row padded to 40 bytes).       */
/* ===================================================================== */
#define MAX_MAPS 64
static unsigned char map_buf[MAX_MAPS * 40 * 27];

/* save_map(num): st.mie[0..39][0..26] -> handles[5] at
   40*27*(num-1) + 40*f  (Pascal: dec(num); offset = 40*27*num + 40*f). */
void save_map(unsigned char num)
{
    unsigned short f, ff;
    unsigned char s[40];
    if (num > 0) {
        num--;                                  /* dec(num) */
        for (f = 0; f <= 26; f++) {
            for (ff = 0; ff <= 39; ff++)
                s[ff] = st.mie[ff][f];        /* s[ff]:=st.mie[ff,f] */
            memcpy(&map_buf[(40 * 27 * num) + (40 * f)], s, 40);
            /* CopyCMemToXMem(handles[5].h, 40*27*num+40*f, @s, 40); */
        }
        /* maps[num+1] := true;  -- maps[] is not tracked in the C-C engine */
    }
}

/* load_map(num): handles[5] -> st.mie[0..39][0..26] (Pascal counterpart,
   used when switching maps). */
void load_map(unsigned char num)
{
    unsigned short f, ff;
    unsigned char s[40];
    if (num > 0) {
        num--;                                  /* dec(num) */
        for (f = 0; f <= 26; f++) {
            memcpy(s, &map_buf[(40 * 27 * num) + (40 * f)], 40);
            /* CopyXMemToCMem(@s, handles[5].h, 40*27*num+40*f, 40); */
            for (ff = 0; ff <= 39; ff++)
                st.mie[ff][f] = s[ff];
        }
    }
}
