import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

// StatusNotifierItem tray. Left click activates, right click asks the app for
// its secondary action -- a full DBusMenu popup is deliberately left out of
// this first pass; see docs/quickshell.md.
Row {
    spacing: 8

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: item

            required property var modelData

            implicitWidth: 18
            implicitHeight: 18
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    item.modelData.activate();
                else
                    item.modelData.secondaryActivate();
            }

            IconImage {
                anchors.fill: parent
                source: item.modelData.icon
            }
        }
    }
}
