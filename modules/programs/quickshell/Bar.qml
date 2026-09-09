import Quickshell
import QtQuick

// The bar itself: a layer-shell panel anchored to the top of one monitor.
// Everything visual is pulled from Theme, which Home Manager generates from
// your Stylix scheme -- so don't hardcode colours or fonts here.
PanelWindow {
    id: bar

    // Set by Variants in shell.qml; one Bar is built per ShellScreen.
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    color: Theme.bg

    Row {
        id: leftSection

        anchors.left: parent.left
        anchors.leftMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Workspaces {
            screenName: bar.modelData.name
        }
    }

    // Squeezed between the workspaces and the clock, and elides rather than
    // pushing the clock off-centre when a window has a very long title.
    ActiveWindow {
        anchors.left: leftSection.right
        anchors.right: centreSection.left
        anchors.leftMargin: Theme.gap
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
    }

    Row {
        id: centreSection

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Clock {}
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Tray {}
        Volume {}
        Battery {}
    }
}
