/* vec_ext.h - C-owned storage for the Siriel 3.5 `vec` object array.
 *
 * `vec` is the central on-screen object/entity array:
 *       ve    = array[1..pocet_veci(200)] of predmet;
 *       vec   : ^ve;
 *
 * This is Phase 0 of the Pascal->C migration (see wiki/modules/vec-migration.md).
 * It does NOT move any function logic yet -- it only relocates the STORAGE so
 * that C owns the array.  Both unported Pascal functions and (future) ported C
 * functions then see the SAME memory, exactly like the Layer-3 "C owns the
 * globals" pattern for ja/language[].
 *
 * Storage layout (calloc, so everything is zeroed / deterministic):
 *       g_vec[0]      = guard slot.  Pascal occasionally READS vec^[0]
 *                       (e.g. zisti_vec probe:  vec^[mov].meno[1]='Y' with mov=0).
 *                       In Pascal vec^[0] is 316 B BEFORE the array (OOB heap);
 *                       the probe only matters when meno[1]=='Y', so a zeroed
 *                       guard (meno[1]==0 != 'Y') gives the intended "empty"
 *                       result.  This mirrors the vec^[0] guard in the master plan.
 *       g_vec[1..200] = the real vec.  Only these slots are ever read at runtime.
 *
 * Indexing (the one subtle bit):
 *       Pascal vec is 1-based:  vec^[i] sits at  vec_base + (i-1)*316.
 *       siriel_vec_ptr() returns  &g_vec[1]  so that
 *                 Pascal  vec^[i]  ==  C   g_vec[i]      (i = 1..200)
 *                 Pascal  vec^[0]  ==  C   g_vec[0]      (guard)
 *       siriel_vec()   returns  g_vec  (the true base) for C callers, so a C
 *       function accesses  vec^[i]  as  siriel_vec()[i].
 *
 * predmet ABI (VERIFIED against FPC under {$packrecords 1}: sizeof == 316).
 * See spike/migrate/vec_ext/abi_verify/ for the harness that proved every
 * field offset.  string[5] -> len byte at offset 0 + chars at 1..5; Pascal
 * 1-based indexing:  meno[k] == c[k-1]  (k = 1..5).  boolean == 1 byte.
 */
#ifndef SIRIEL_VEC_EXT_H
#define SIRIEL_VEC_EXT_H

#include <stddef.h>

typedef struct __attribute__((packed)) {
    /* offset 0: string[5] -> len byte at 0, chars at 1..5 */
    unsigned char len;        /* meno[0]  (length)    */
    char        c[5];         /* meno[1..5]           */
    /* Pascal 1-based:  meno[k]  ==  c[k-1]   (k = 1..5) */

    unsigned short x, y, x2, y2, x1, y1, mie, st, take, obr,
                 inf1, inf2, inf3, inf4, inf5, inf6, funk, anim, inf7;
    unsigned short ox, oy, oox, ooy, cislo;
    unsigned char  z1, z2;
    unsigned char  useanim, change, visible, smer;   /* Pascal boolean = 1 byte */
    unsigned char  zas[256];                           /* offset 60 */
} predmet;                     /* sizeof == 316 (verified) */

#ifdef __cplusplus
extern "C" {
#endif

/* Pascal-facing:  vec := siriel_vec_ptr().  Returns &g_vec[1] (see above). */
predmet *siriel_vec_ptr(void);

/* C-facing:  returns g_vec;  vec^[i]  ==  siriel_vec()[i]. */
predmet *siriel_vec(void);

/* Free the storage (only called from C unload; Pascal's dispose(vec) is
 * guarded out under {$IFDEF EXT_VEC} -- see spike/wire_ext.py). */
void      siriel_vec_free(void);

#ifdef __cplusplus
}
#endif

#endif /* SIRIEL_VEC_EXT_H */
