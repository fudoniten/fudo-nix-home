import Quickshell
import QtQuick

Text {
    id: root

    // Minute precision: no point waking the process once a second to redraw
    // a clock that only shows minutes.
    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "ddd MMM d   HH:mm")
    color: Theme.fg
    font.family: Theme.fontSans
    font.pixelSize: 13
}
