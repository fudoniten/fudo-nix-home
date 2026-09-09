import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Default sink volume. Click to toggle mute.
Text {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink && !!sink.audio

    // PipeWire objects are not bound (and their properties stay stale) until
    // something tracks them. Without this the volume simply never updates.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    text: !root.ready ? "vol --" : root.sink.audio.muted ? "muted" : "vol " + Math.round(root.sink.audio.volume * 100) + "%"

    color: root.ready && root.sink.audio.muted ? Theme.muted : Theme.fg
    font.family: Theme.fontMono
    font.pixelSize: 12

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.ready)
                root.sink.audio.muted = !root.sink.audio.muted;
        }
    }
}
