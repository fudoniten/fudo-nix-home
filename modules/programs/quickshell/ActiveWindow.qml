import Quickshell
import Quickshell.Hyprland
import QtQuick

// Title of the focused window. Deliberately defensive: if the running
// Quickshell exposes no activeToplevel, this renders empty rather than
// throwing and taking the whole bar down with it.
Text {
    readonly property var toplevel: Hyprland.activeToplevel ?? null

    text: toplevel ? (toplevel.title ?? "") : ""
    color: Theme.muted
    elide: Text.ElideRight
    font.family: Theme.fontSans
    font.pixelSize: 12
    verticalAlignment: Text.AlignVCenter
}
