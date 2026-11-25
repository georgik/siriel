/* =====================================================================
 * fb_shm.c  -  shared-memory bridge for the two-process Siriel build.
 *
 * Two implementations, selected at compile time:
 *
 *   POSIX (Linux, macOS): shm_open()/mmap()/munmap()
 *                         (backed by /dev/shm or /dev/sysshm on macOS).
 *   Windows:              CreateFileMapping()/MapViewOfFile()/...
 *                         (named, memory-mapped file).
 *
 * In both cases the writer creates the object; the reader only attaches.
 * The header, the key ring and the lock-free seq protocol live in
 * fb_shm.h and are identical on every platform.
 * ===================================================================== */
#include "fb_shm.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#if defined(_WIN32)
#  include <windows.h>
#else
#  include <unistd.h>
#  include <fcntl.h>
#  include <sys/mman.h>
#  include <sys/stat.h>
#endif

/* ------------------------------------------------------------------ */
/* Name handling.                                                       */
/*                                                                    */
/* POSIX shm names must start with '/' and contain no other '/'.      */
/* Windows named mappings may NOT contain '/' at all, and a leading   */
/* '/' is meaningless there. We therefore normalise: drop a leading   */
/* '/' and translate any remaining '/' to '_'. The stored name is the */
/* same logical object on every OS ("siriel_fb").                     */
/* ------------------------------------------------------------------ */
static void fb_shm_normalize(const char *in, char *out, size_t outsz)
{
    size_t i = 0;
    const char *p = in;
    if (*p == '/') p++;                 /* drop leading '/' */
    for (; *p && i + 1 < outsz; p++, i++) {
        out[i] = (*p == '/') ? '_' : *p;
    }
    out[i] = '\0';
}

static const char *fb_shm_name(void)
{
    static char name[128];
    const char *env = getenv("SIRIEL_FB_NAME");
    const char *raw = (env && *env) ? env : FB_SHM_DEFAULT_NAME;
    fb_shm_normalize(raw, name, sizeof(name));
    return name;
}

/* Initialise the header on first creation. Shared by both backends. */
static void fb_shm_init_header(void *seg)
{
    fb_shm_hdr *h = (fb_shm_hdr *)seg;
    h->seq         = 0;
    h->cmd_wr      = 0;             /* key ring starts empty */
    h->w           = FBW;
    h->h           = FBH;
    h->bpp         = 24;
    h->reserved    = 0;
    h->quit        = 0;   /* no quit requested */
    h->engine_quit = 0;  /* engine has not quit */
}

/* ================================================================ */
/* POSIX backend                                                    */
/* ================================================================ */
#if !defined(_WIN32)

void *fb_shm_open_writer(void)
{
    /* Recreate a fresh object on every engine init so a stale segment left
     * by a previous run (which still carries engine_quit=1 and the final
     * seq) can never be read by a feeder/window that attaches before the
     * engine has reset the header. A preceding shm_unlink() simply fails
     * with ENOENT when nothing exists yet; that is expected and ignored. */
    shm_unlink(fb_shm_name());
    int fd = shm_open(fb_shm_name(), O_CREAT | O_RDWR, 0666);
    if (fd < 0) {
        fprintf(stderr, "[fb_shm] shm_open(write) failed: %s\n", strerror(errno));
        return NULL;
    }
    /* Size the object up to FB_SHM_SIZE if it is smaller. macOS DISALLOWS
     * shrinking a shm object (ftruncate to a smaller size -> EINVAL), so we
     * must never call ftruncate with a length below the current size. A
     * stale object left by a previous run is simply reused as-is. */
    {
        struct stat st;
        if (fstat(fd, &st) == 0 && (size_t)st.st_size < FB_SHM_SIZE) {
            if (ftruncate(fd, FB_SHM_SIZE) != 0) {
                fprintf(stderr, "[fb_shm] ftruncate failed: %s\n", strerror(errno));
                close(fd);
                return NULL;
            }
        }
    }
    void *seg = mmap(NULL, FB_SHM_SIZE, PROT_READ | PROT_WRITE,
                     MAP_SHARED, fd, 0);
    close(fd);
    if (seg == MAP_FAILED) {
        fprintf(stderr, "[fb_shm] mmap failed: %s\n", strerror(errno));
        return NULL;
    }
    fb_shm_init_header(seg);
    return seg;
}

void *fb_shm_open_reader(void)
{
    int fd = shm_open(fb_shm_name(), O_RDWR, 0);
    if (fd < 0) {
        /* ENOENT simply means the engine has not started / has exited. */
        if (errno == ENOENT)
            return NULL;
        fprintf(stderr, "[fb_shm] shm_open(read) failed: %s\n", strerror(errno));
        return NULL;
    }
    void *seg = mmap(NULL, FB_SHM_SIZE, PROT_READ | PROT_WRITE,
                     MAP_SHARED, fd, 0);
    close(fd);
    if (seg == MAP_FAILED) {
        fprintf(stderr, "[fb_shm] mmap failed: %s\n", strerror(errno));
        return NULL;
    }
    return seg;
}

void fb_shm_close(void *seg)
{
    if (seg && seg != MAP_FAILED)
        munmap(seg, FB_SHM_SIZE);
}

/* ================================================================ */
/* Windows backend                                                  */
/* ================================================================ */
#else /* _WIN32 */

/* Single-segment model: the whole app uses exactly one shm segment, so we
 * keep the OS handles in file-statics to let fb_shm_close() tear them down.
 * (The void* API only hands back the mapped pointer, not the handles.) */
static HANDLE g_hFile = NULL;
static HANDLE g_hMap  = NULL;

void *fb_shm_open_writer(void)
{
    const char *nm = fb_shm_name();

    /* Attach to an existing segment, or create a new one. Mirrors the POSIX
     * "open or create" behaviour of shm_open(O_CREAT). */
    HANDLE hMap = OpenFileMappingA(FILE_MAP_READ | FILE_MAP_WRITE, FALSE, nm);
    if (!hMap) {
        if (GetLastError() != ERROR_FILE_NOT_FOUND) {
            fprintf(stderr, "[fb_shm] OpenFileMapping failed: %u\n",
                    (unsigned)GetLastError());
            return NULL;
        }
        /* Backed by the paging file, sized up front. */
        hMap = CreateFileMappingA(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE,
                                  0, FB_SHM_SIZE, nm);
        if (!hMap) {
            fprintf(stderr, "[fb_shm] CreateFileMapping failed: %u\n",
                    (unsigned)GetLastError());
            return NULL;
        }
    }

    void *seg = MapViewOfFile(hMap, FILE_MAP_READ | FILE_MAP_WRITE,
                              0, 0, FB_SHM_SIZE);
    if (!seg) {
        fprintf(stderr, "[fb_shm] MapViewOfFile failed: %u\n",
                (unsigned)GetLastError());
        CloseHandle(hMap);
        return NULL;
    }

    g_hFile = NULL;
    g_hMap  = hMap;
    fb_shm_init_header(seg);
    return seg;
}

void *fb_shm_open_reader(void)
{
    const char *nm = fb_shm_name();
    HANDLE hMap = OpenFileMappingA(FILE_MAP_READ | FILE_MAP_WRITE, FALSE, nm);
    if (!hMap) {
        /* ERROR_FILE_NOT_FOUND simply means the engine has not started /
         * has exited. */
        if (GetLastError() == ERROR_FILE_NOT_FOUND)
            return NULL;
        fprintf(stderr, "[fb_shm] OpenFileMapping failed: %u\n",
                (unsigned)GetLastError());
        return NULL;
    }

    void *seg = MapViewOfFile(hMap, FILE_MAP_READ | FILE_MAP_WRITE,
                              0, 0, FB_SHM_SIZE);
    if (!seg) {
        fprintf(stderr, "[fb_shm] MapViewOfFile failed: %u\n",
                (unsigned)GetLastError());
        CloseHandle(hMap);
        return NULL;
    }

    g_hFile = NULL;
    g_hMap  = hMap;
    return seg;
}

void fb_shm_close(void *seg)
{
    if (seg && UnmapViewOfFile(seg)) {
        /* best-effort: forget the mapping */
    }
    if (g_hMap) {
        CloseHandle(g_hMap);
        g_hMap = NULL;
    }
    g_hFile = NULL;
}

#endif /* _WIN32 */

/* ================================================================ */
/* Platform-independent sync primitives (GCC/Clang atomics, which    */
/* mingw-w64 gcc supports natively).                                 */
/* ================================================================ */
void fb_shm_publish(void *seg)
{
    fb_shm_hdr *h = (fb_shm_hdr *)seg;
    /* Release store: the pixel copy above is visible before seq is read. */
    __atomic_store_n(&h->seq, h->seq + 1, __ATOMIC_RELEASE);
}

uint64_t fb_shm_seq(void *seg)
{
    const fb_shm_hdr *h = (const fb_shm_hdr *)seg;
    /* Acquire load: guarantees the pixel bytes are valid once seq>0. */
    return __atomic_load_n(&h->seq, __ATOMIC_ACQUIRE);
}
