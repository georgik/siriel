/* =====================================================================
 * port.h  -  tiny POSIX/Windows compatibility shim for the C front-end.
 *
 * The two-process Siriel build compiles the C front-end on Linux, macOS and
 * Windows (mingw-w64). A few POSIX calls have no Windows counterpart, so we
 * funnel them through the helpers below and keep the platform guards in one
 * place instead of sprinkling #ifdef _WIN32 through every source file.
 *
 * This header is header-only (static inline) so it can be included from any
 * translation unit without adding a .c to the link.
 * ===================================================================== */
#ifndef SIRIEL_PORT_H
#define SIRIEL_PORT_H

/* --------------------------------------------------------------------- */
/* Sleep.                                                                */
/*                                                                       */
/* POSIX provides usleep(microseconds). Windows has no usleep(); it has   */
/* Sleep(milliseconds). We accept microseconds on every platform and      */
/* round up so a requested 20000 us still yields a full 20 ms.           */
/* --------------------------------------------------------------------- */
#if defined(_WIN32)
/* Only <Sleep> is needed here. Including the full <windows.h> would also pull
 * in the GDI/user API names (Rectangle, CloseWindow, ShowCursor, LoadImage,
 * ...) that raylib.h declares with the same identifiers, causing a redeclare
 * conflict in host_window.c. <windef.h> + <winbase.h> give us DWORD + Sleep
 * without those clashes. <winbase.h> needs <windef.h> first for its types. */
#  include <windef.h>
#  include <winbase.h>
static inline void port_sleep_us(unsigned long long us)
{
    Sleep((DWORD)((us + 999ULL) / 1000ULL));
}
#else
#  include <unistd.h>
static inline void port_sleep_us(unsigned long long us)
{
    usleep((useconds_t)us);
}
#endif

#endif /* SIRIEL_PORT_H */
