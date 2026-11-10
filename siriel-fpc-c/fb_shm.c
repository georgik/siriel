/* =====================================================================
 * fb_shm.c  -  POSIX shared-memory implementation (see fb_shm.h).
 *
 * Uses shm_open()/mmap() (backed by /dev/shm or /dev/sysshm on macOS).
 * The writer creates the object; the reader only attaches.
 * ===================================================================== */
#include "fb_shm.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/stat.h>

/* Resolve the shm name (env override or default). */
static const char *fb_shm_name(void)
{
    static char name[128];
    const char *env = getenv("SIRIEL_FB_NAME");
    if (env && *env) {
        /* shm_open needs a leading '/' and a valid POSIX name. */
        if (env[0] == '/')
            snprintf(name, sizeof(name), "%s", env);
        else
            snprintf(name, sizeof(name), "/%s", env);
    } else {
        snprintf(name, sizeof(name), "/%s", FB_SHM_DEFAULT_NAME);
    }
    return name;
}

void *fb_shm_open_writer(void)
{
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
    /* Initialise the header on first creation. */
    fb_shm_hdr *h = (fb_shm_hdr *)seg;
    h->seq    = 0;
    h->cmd_wr = 0;              /* key ring starts empty */
    h->w      = FBW;
    h->h      = FBH;
    h->bpp    = 24;
    h->reserved = 0;
    h->quit     = 0;   /* no quit requested */
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

void fb_shm_publish(void *seg)
{
    fb_shm_hdr *h = (fb_shm_hdr *)seg;
    /* Release store: the pixel copy above is visible before seq is read. */
    __atomic_store_n(&h->seq, h->seq + 1, __ATOMIC_RELEASE);
}

uint64_t fb_shm_seq(void *seg)
{
    const fb_shm_hdr *h = (const fb_shm_hdr *)seg;
    /* Acquire store: guarantees the pixel bytes are valid once seq>0. */
    return __atomic_load_n(&h->seq, __ATOMIC_ACQUIRE);
}
