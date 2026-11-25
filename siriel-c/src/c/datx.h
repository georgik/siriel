/* =====================================================================
 * datx.h  -  faithful C port of the Siriel 3.5 DAT resource reader
 *            (src/pascal/BLOCKX.PAS, unit BLOCKX).
 *
 * The DAT files are block/resource files.  The layout (TP7 binary, see
 * {$packrecords 1} in BLOCKX.PAS) is:
 *
 *   offset 0      : NumSounds  -- 16-bit WORD  (record count)
 *   offset 2      : Resource[0]  (16 bytes each)
 *       Key       : array[1..8] of char   (8 bytes, #0 padded)
 *       Start     : LongInt               (4 bytes, little-endian)
 *       Size      : LongInt               (4 bytes, little-endian)
 *   ...           : the resource data lives at file offset 'Start'.
 *
 * The C-C engine resolves these directly from C (no FPC 'external' loading),
 * so this file is the DAT half of the two-process build, next to fb_shm.c
 * (the framebuffer half).  host_engine.c / the window are UNCHANGED.
 * ===================================================================== */
#ifndef SIRIEL_DATX_H
#define SIRIEL_DATX_H

#include <stdint.h>

#define DAT_MAX_RECORDS 19   /* num_disks guard in load_basic_config: num_disks>19 stops */
#define DAT_CHUNK       256  /* loadchunksize in BLOCKX.PAS */

/* t_palette mirrors JxGRAF t_palette = record r,v,b : byte; end; (packed, 3 B) */
typedef struct {
    unsigned char r, v, b;
} t_palette;

/* diskx mirrors data_disks^[f] in SI35.PAS (meno/subor/verzia). */
typedef struct {
    char           meno[64];    /* display name ('' until the selection commits) */
    char           subor[128];  /* DAT filename                                  */
    unsigned short verzia;       /* ver*100+ver*10+ver (3-digit, from SIRIEL35 blk) */
} diskx;

/* ---- resource-file state (mirrors BLOCKX.ResourceFile/SoundFile) ------- */
/* Open <sub>, read the 16-bit record count.  Returns 1 on success, 0 else. */
int  dat_open(const char *sub);

/* checkblock_header: the 2nd byte of the file is NUL  (BLOCKX.checkblock_header) */
int dat_checkblock_header(const char *filename);

/* checkblock_info(sub,key): header valid AND <key> present among records. */
int dat_checkblock_info(const char *sub, const char *key);

/* dat_block_size(sub,key): byte size of block <key> in DAT <sub>, or 0 if
 * absent.  Mirrors BLOCKX.GetBlockFile's Start/Size fields. */
int dat_block_size(const char *sub, const char *key);

/* Find a block by (already upper-cased) key; returns 1 and sets *start, *size. */
int dat_find_block(const char *key, long *start, long *size);

/* loadblock_array(sub,kluc,buf): copy the block's Size bytes into buf
 * (0-based, chunked DAT_CHUNK), like BLOCKX.Loadblock_array.  Returns the
 * number of bytes loaded (>0), or 0 on failure. */
int dat_load_array(const char *sub, const char *kluc,
                   unsigned char *buf, int bufsz);

/* getblock_out(sub,kluc,vystup): dump the block as text to <vystup>. */
int dat_getblock_out(const char *sub, const char *kluc, const char *vystup);

/* load_palette_block(sub,kluc,palx): if kluc[1]=='>' strip it (out_string),
 * load the block, unpack 768 bytes into 256 t_palette triplets (BLOCKX loads
 * the 8-bit RGB triplets verbatim -- no shr-2 darkening). */
void load_palette_block(const char *sub, const char *kluc,
                        t_palette palx[256]);

/* subor_exist(s): pattern match over the current directory (DOS findfirst). */
int subor_exist(const char *s);
/* subor_crc(name): 0 if it exists, 2 otherwise (GEO2.PAS). */
int subor_crc(const char *name);

/* scan_disks(pat,disks,max): append every file matching <pat> that passes the
 * SIRIEL35 block-header check into disks[] (sorted by name, reversed), and
 * return the count.  Mirrors load_basic_config's scan_disks (called once for
 * '*.dat' and once for '*.DAT'). */
int scan_disks(const char *pat, diskx *disks, int max);

#endif /* SIRIEL_DATX_H */
