/* =====================================================================
 * datx.c  -  faithful C port of src/pascal/BLOCKX.PAS (unit BLOCKX).
 *
 * The DAT resource reader the Siriel 3.5 engine core uses to load its data
 * files (MAIN.DAT palette/fonts/graphics/sounds, SIRIEL35.DAT the game disk
 * with the SIRIEL35 version block + CONFIG block, SCORE.DAT, ...).
 *
 * The C-C engine resolves these directly from C (no FPC 'external' loading),
 * so this is the DAT half of the two-process build, next to fb_shm.c.
 * host_engine.c / the window / shm are UNCHANGED.
 *
 * The port mirrors BLOCKX.PAS line by line:
 *   checkblock_header  -> read 2 bytes, test the 2nd is NUL
 *   MatchingKeys       -> 8-byte compare of #0-padded keys
 *   Loadblock_array    -> open, find block, read Size bytes chunked (256)
 *   getblock_out       -> dump block as text
 *   load_palette_block -> strip leading '>', load 768 B, unpack to 256 triplets
 *   subor_exist        -> DOS findfirst pattern match (cwd)
 *   scan_disks         -> wildcard dat scans + SIRIEL35 header check + version
 *
 * Binary layout (TP7, {$packrecords 1}): 16-bit NumSounds at offset 0, then
 * 16-byte records { Key[8] | Start:LongInt LE | Size:LongInt LE }.
 * ===================================================================== */
#include "datx.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <fnmatch.h>
#include <dirent.h>

/* ------------------------------------------------------------------ */
/* Helpers                                                            */
/* ------------------------------------------------------------------ */

/* Uppercase a..z in place (BLOCKX upcased on the ASCII keys here). */
static void dat_upcase(char *s)
{
    for (; *s; s++)
        if (*s >= 'a' && *s <= 'z') *s = (char)(*s - 'a' + 'A');
}

/* TKey compare: 8 bytes, key padded with #0 beyond its length. */
static int matching_keys(const void *a, const void *b)
{
    int i;
    for (i = 0; i < 8; i++)
        if (((unsigned char *)a)[i] != ((unsigned char *)b)[i])
            return 0;
    return 1;
}

/* Read the 16-bit record count at offset 0. */
static int dat_read_count(int fd)
{
    unsigned char b[2];
    if (lseek(fd, 0, SEEK_SET) < 0) return 0;
    if (read(fd, b, 2) != 2) return 0;
    return (int)(b[0] | (b[1] << 8));   /* little-endian WORD */
}

/* Read a 32-bit signed value at a record offset (LE). */
static void dat_read_int32(int fd, long off, long *out)
{
    unsigned char b[4];
    if (lseek(fd, off, SEEK_SET) < 0 || read(fd, b, 4) != 4) { *out = 0; return; }
    *out = (long)(b[0] | (b[1] << 8) | (b[2] << 16) | ((long)b[3] << 24));
}

/* ------------------------------------------------------------------ */
/* dat_open(sub): validate the DAT (16-bit record count at offset 0).  */
/* ------------------------------------------------------------------ */
int dat_open(const char *sub)
{
    int fd = open(sub, O_RDONLY);
    int ok = 0;
    if (fd < 0) return 0;
    ok = (dat_read_count(fd) > 0);
    close(fd);
    return ok;
}

/* ------------------------------------------------------------------ */
/* checkblock_header: 2nd byte of the file is NUL                      */
/* ------------------------------------------------------------------ */
int dat_checkblock_header(const char *filename)
{
    int fd = open(filename, O_RDONLY);
    unsigned char b[2];
    int ok = 0;
    if (fd < 0) return 0;
    if (read(fd, b, 2) == 2)
        ok = (b[1] == 0);          /* ord(ch)=0 after two reads -> true */
    close(fd);
    return ok;
}

/* ------------------------------------------------------------------ */
/* find_block(sub,key,&start,&size): mirrors GetBlockFile (key upper).  */
/* ------------------------------------------------------------------ */
static int find_block(const char *sub, const char *key, long *start, long *size)
{
    int fd = open(sub, O_RDONLY);
    int nrec, i;
    unsigned char rec[16];
    long rec_off;

    if (fd < 0) return 0;
    nrec = dat_read_count(fd);
    if (nrec <= 0) { close(fd); return 0; }

    rec_off = 2;   /* records begin right after the 2-byte NumSounds */
    {
        char k8[8];
        int klen = (int)strlen(key);
        int p;
        for (p = 0; p < 8; p++)          /* build the #0-padded TKey block */
            k8[p] = (p < klen) ? key[p] : '\0';
        for (i = 0; i < nrec; i++, rec_off += 16) {
            if (lseek(fd, rec_off, SEEK_SET) < 0) break;
            if (read(fd, rec, 16) != 16) break;
            if (matching_keys(k8, rec)) {   /* Key[8] */
                long s, z;
                dat_read_int32(fd, rec_off + 8, &s);   /* Start */
                dat_read_int32(fd, rec_off + 12, &z);  /* Size */
                close(fd);
                if (start) *start = s;
                if (size)  *size  = z;
                return 1;
            }
        }
    }
    close(fd);
    return 0;
}

/* ------------------------------------------------------------------ */
/* dat_block_size(sub,key): return the byte size of block <key> in DAT */
/* <sub>, or 0 if the block is absent.  Mirrors BLOCKX.GetBlockFile,   */
/* which reads the record's Start/Size fields to size the load.       */
/* ------------------------------------------------------------------ */
int dat_block_size(const char *sub, const char *key)
{
    long start, size;
    if (!find_block(sub, key, &start, &size)) return 0;
    return (int)size;
}

/* ------------------------------------------------------------------ */
/* checkblock_info(sub,key): header valid AND key present              */
/* ------------------------------------------------------------------ */
int dat_checkblock_info(const char *sub, const char *key)
{
    long s, z;
    if (!dat_checkblock_header(sub)) return 0;
    return find_block(sub, key, &s, &z);
}

/* ------------------------------------------------------------------ */
/* loadblock_array(sub,kluc,buf): copy the block's bytes (chunked 256)  */
/* ------------------------------------------------------------------ */
int dat_load_array(const char *sub, const char *kluc,
                   unsigned char *buf, int bufsz)
{
    long start, size;
    int fd, ffl = 0;
    unsigned char chunk[DAT_CHUNK];
    long remaining;

    /* loadblock_array port: the Pascal destination is a fixed-size
       array[0..maxlen] of byte, i.e. zero-filled.  Mirror that so bytes
       past the block read as 0 (otherwise the line-reader / MAPA loops
       would scan uninitialized stack and the result is non-deterministic). */
    memset(buf, 0, (size_t)bufsz);

    if (!subor_exist(sub)) return 0;
    if (!find_block(sub, kluc, &start, &size)) return 0;
    if (size <= 0 || (long)bufsz < size) return 0;

    fd = open(sub, O_RDONLY);
    if (fd < 0) return 0;
    lseek(fd, start, SEEK_SET);

    remaining = size;
    while (remaining > 0) {
        int par = (remaining < DAT_CHUNK) ? (int)remaining : DAT_CHUNK;
        int got = read(fd, chunk, (size_t)par);
        int j;
        if (got <= 0) break;
        for (j = 0; j < got; j++) buf[ffl++] = chunk[j];
        remaining -= got;
    }
    close(fd);
    return ffl;
}

/* getblock_out(sub,kluc,vystup): dump the block as text. */
int dat_getblock_out(const char *sub, const char *kluc, const char *vystup)
{
    long start, size;
    int fd;
    FILE *out;
    unsigned char buf[4096];
    long remaining;

    if (!find_block(sub, kluc, &start, &size)) return 0;
    if (size <= 0) return 0;
    out = fopen(vystup, "wb");
    if (!out) return 0;
    fd = open(sub, O_RDONLY);
    if (fd < 0) { fclose(out); return 0; }
    lseek(fd, start, SEEK_SET);
    remaining = size;
    while (remaining > 0) {
        int par = (remaining < (long)sizeof(buf)) ? (int)remaining : (int)sizeof(buf);
        int got = read(fd, buf, (size_t)par);
        int j;
        if (got <= 0) break;
        for (j = 0; j < got; j++) fputc(buf[j], out);
        remaining -= got;
    }
    close(fd);
    fclose(out);
    return 1;
}

/* ------------------------------------------------------------------ */
/* load_palette_block(sub,kluc,palx)                                   */
/* ------------------------------------------------------------------ */
void load_palette_block(const char *sub, const char *kluc,
                        t_palette palx[256])
{
    unsigned char buf[768];
    const char *p = kluc;
    int f;

    /* if kluc[0]=='>' strip it (BLOCKX.out_string) */
    if (kluc[0] == '>') p = kluc + 1;

    memset(palx, 0, sizeof(t_palette) * 256);
    if (dat_load_array(sub, p, buf, sizeof(buf)) < 768)
        return;                        /* not found / short -> leave black */

    /* 768 bytes -> 256 triplets, read in order r,v,b (verbatim 8-bit). */
    for (f = 0; f < 768; f++) {
        int idx = f / 3;
        if (f % 3 == 0)      palx[idx].r = buf[f];
        else if (f % 3 == 1) palx[idx].v = buf[f];
        else                 palx[idx].b = buf[f];
    }
}

/* ------------------------------------------------------------------ */
/* subor_exist / subor_crc (DOS findfirst over the current directory)  */
/* ------------------------------------------------------------------ */
int subor_exist(const char *s)
{
    DIR *d; struct dirent *e;
    d = opendir(".");
    if (d) {
        while ((e = readdir(d))) {
            if (e->d_name[0] == '.') continue;
            if (fnmatch(s, e->d_name, 0) == 0) { closedir(d); return 1; }
        }
        closedir(d);
    }
    return 0;
}

int subor_crc(const char *name)
{
    return subor_exist(name) ? 0 : 2;   /* GEO2.PAS */
}

/* ------------------------------------------------------------------ */
/* scan_disks(pat,disks,max): append matching DATs that pass the         */
/* SIRIEL35 header check, returning the count (BLOCKX.load_basic_config) */
/* ------------------------------------------------------------------ */
int scan_disks(const char *pat, diskx *disks, int max)
{
    DIR *d; struct dirent *e;
    int n = 0, g, h;

    d = opendir(".");
    if (d) {
        while ((e = readdir(d))) {
            char name[256];
            long s, z;
            unsigned char blk[8];

            if (e->d_name[0] == '.') continue;
            if (fnmatch(pat, e->d_name, 0) != 0) continue;
            if (strlen(e->d_name) >= sizeof(name)) continue;
            strcpy(name, e->d_name);
            /* dup guard: same subor already recorded */
            for (g = 0; g < n; g++)
                if (strcmp(disks[g].subor, name) == 0) break;
            if (g < n) continue;
            /* SIRIEL35 block must be present (checkblock_info) */
            if (!dat_checkblock_info(name, "SIRIEL35")) continue;
            if (n >= max) break;
            /* version from the SIRIEL35 block (3 ASCII digits) */
            disks[n].verzia = 0;
            if (find_block(name, "SIRIEL35", &s, &z) && z >= 3) {
                int fd = open(name, O_RDONLY);
                if (fd >= 0) {
                    if (lseek(fd, s, SEEK_SET) >= 0 && read(fd, blk, 3) == 3) {
                        for (h = 0; h < 3; h++)
                            blk[h] = (unsigned char)(blk[h] - 48);
                        disks[n].verzia =
                            (unsigned short)(blk[0] * 100 + blk[1] * 10 + blk[2]);
                    }
                    close(fd);
                }
            }
            disks[n].subor[0] = '\0';
            strncpy(disks[n].subor, name, sizeof(disks[n].subor) - 1);
            disks[n].meno[0] = '\0';
            n++;
        }
        closedir(d);
    }
    return n;
}
