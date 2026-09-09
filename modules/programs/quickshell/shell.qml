//@ pragma UseQApplication
// UseQApplication is required by the system tray: DBusMenu popups are
// QtWidgets-based, and they silently do nothing under a plain QGuiApplication.

import Quickshell

ShellRoot {
    // One bar per connected monitor. `Variants` rebuilds the delegate set as
    // monitors come and go, so hotplugging a display Just Works -- there is
    // no reload to trigger by hand.
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
