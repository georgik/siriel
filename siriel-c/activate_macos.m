/* =====================================================================
 * activate_macos.m  -  macOS helpers to make the Raylib/GLFW window
 *                      VISIBLE, KEY (focused) and FOCUSED.
 *
 * PROBLEM
 * -------
 * A GUI app launched from the Terminal is registered by macOS as a
 * BACKGROUND application: its NSWindow is created but not shown / focused
 * until the app is activated. That is why a bare InitWindow() can leave a
 * window that never appears (and never receives keystrokes).
 *
 * Worse: activateIgnoringOtherApps:YES only makes the *application*
 * frontmost.  macOS still hands keyboard events to whatever window is the
 * KEY window (often the Terminal that launched us).  GLFW key callbacks
 * only fire for the key window, so without promoting our window we can see
 * it but never receive a keystroke.
 *
 * FIX
 * ---
 *   1. setActivationPolicy(.Regular)  -> tell the OS this is a normal
 *      foreground-capable app (required before activation actually works).
 *   2. activateIgnoringOtherApps:YES  -> bring this app (and its window)
 *      to the foreground.
 *   3. makeKeyAndVisible()            -> promote our NSWindow to the KEY
 *      window so macOS delivers keystrokes to it.
 *   4. becomeFirstResponder()         -> let the window accept key events.
 *
 * Neither touches the GLFW event pump, so neither can trigger the FPC-as-
 * library SIGILL (this process has no FPC anyway).
 * ===================================================================== */
#import <Cocoa/Cocoa.h>

#ifndef NSActivationPolicyRegular
/* Fallback for SDKs that do not declare the name (value is 0). */
#define NSActivationPolicyRegular 0
#endif

void siel_activate_app(void *nsWindow)
{
    NSApplication *app = [NSApplication sharedApplication];
    NSWindow *win = (NSWindow *)nsWindow;

    /* Must be a regular (foreground-capable) policy before activation. */
    [app setActivationPolicy:NSActivationPolicyRegular];

    /* Show + focus this app's window, ignoring other apps. */
    [app activateIgnoringOtherApps:YES];

    /* Promote OUR window to the key window so GLFW actually receives
     * keystrokes (the Terminal otherwise keeps the key slot). In this SDK
     * makeKeyAndVisible is gone; the window is already visible, so we only
     * need to promote it to the KEY window. Cast to NSWindow* so the AppKit
     * methods resolve. */
    if (win) {
        NSWindow *nw = (NSWindow *)win;
        [nw makeKeyWindow];
        [nw becomeFirstResponder];
    }
}
