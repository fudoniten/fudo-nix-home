import Quickshell
import Quickshell.Hyprland
import QtQuick

// Hyprland workspace pills, filtered to the monitor this bar is on.
Row {
    id: root

    // Wayland output name (e.g. "DP-1"), from ShellScreen.name.
    property string screenName: ""

    spacing: 4

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            id: pill

            required property var modelData

            // A workspace with no monitor yet (freshly created) is shown
            // everywhere rather than nowhere -- better a duplicate for a
            // frame than a pill that never appears.
            visible: root.screenName === "" || !modelData.monitor
                || modelData.monitor.name === root.screenName

            implicitWidth: Math.max(26, label.implicitWidth + 14)
            implicitHeight: 22
            radius: Theme.radius

            color: modelData.focused ? Theme.accent : modelData.active ? Theme.surface : "transparent"

            Text {
                id: label

                anchors.centerIn: parent
                text: modelData.name
                color: pill.modelData.focused ? Theme.bg : Theme.fg
                font.family: Theme.fontSans
                font.pixelSize: 12
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + pill.modelData.id)
            }
        }
    }
}
