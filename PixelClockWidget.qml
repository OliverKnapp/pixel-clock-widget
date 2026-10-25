import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    property bool acceptsKeyboardFocus: false

    widgetWidth: 320
    widgetHeight: 200
    minWidth: 240
    minHeight: 140

    property real bgOpacity: 0.85
    property color cardBg: Theme.withAlpha(Theme.surfaceContainer, bgOpacity)
    property color borderCol: Theme.withAlpha(Theme.outlineVariant, 0.45)
    property real cardRadius: 28

    // Active clock style: "at_a_glance" (default) or "stacked"
    property string clockStyle: getData("clockStyle", "at_a_glance")

    // Event data from dcal
    property string nextEventSummary: ""
    property string nextEventTimeStr: ""
    property bool hasNextEvent: nextEventSummary.length > 0

    // Load authentic Google Sans fonts
    FontLoader {
        id: fontBold
        source: "./fonts/GoogleSans-Bold.ttf"
    }

    FontLoader {
        id: fontMedium
        source: "./fonts/GoogleSans-Medium.ttf"
    }

    FontLoader {
        id: fontRegular
        source: "./fonts/GoogleSans-Regular.ttf"
    }

    readonly property string sansBold: fontBold.name.length > 0 ? fontBold.name : "Google Sans"
    readonly property string sansMedium: fontMedium.name.length > 0 ? fontMedium.name : "Google Sans Medium"
    readonly property string sansRegular: fontRegular.name.length > 0 ? fontRegular.name : "Google Sans"

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    Component.onCompleted: {
        refreshEvents();
    }

    // Refresh upcoming calendar events from dcal
    function refreshEvents() {
        if (!getEventsProc.running) {
            getEventsProc.running = true;
        }
    }

    Process {
        id: getEventsProc
        command: ["sh", "-c", "dcal ipc events.list from=\"$(date -u +\"%Y-%m-%dT00:00:00Z\")\" to=\"$(date -u -d \"+7 days\" +\"%Y-%m-%dT23:59:59Z\")\" limit=10"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    if (data && data.events && data.events.length > 0) {
                        var now = new Date();
                        var todayStr = Qt.formatDate(now, "yyyy-MM-dd");
                        var tomorrow = new Date(now.getTime() + 86400000);
                        var tomorrowStr = Qt.formatDate(tomorrow, "yyyy-MM-dd");

                        var bestEvent = null;

                        for (var i = 0; i < data.events.length; i++) {
                            var ev = data.events[i];
                            var evStart = new Date(ev.start);
                            var evDateStr = Qt.formatDate(evStart, "yyyy-MM-dd");

                            // Pick the closest upcoming event
                            if (evStart >= now || evDateStr === todayStr) {
                                bestEvent = ev;
                                break;
                            }
                        }

                        if (!bestEvent && data.events.length > 0) {
                            bestEvent = data.events[0];
                        }

                        if (bestEvent) {
                            var evDate = new Date(bestEvent.start);
                            var dateKey = Qt.formatDate(evDate, "yyyy-MM-dd");
                            var timeBadge = "";

                            if (dateKey === todayStr) {
                                if (bestEvent.allDay) {
                                    timeBadge = "Today";
                                } else {
                                    timeBadge = "Today " + Qt.formatTime(evDate, "hh:mm");
                                }
                            } else if (dateKey === tomorrowStr) {
                                if (bestEvent.allDay) {
                                    timeBadge = "Tomorrow";
                                } else {
                                    timeBadge = "Tomorrow " + Qt.formatTime(evDate, "hh:mm");
                                }
                            } else {
                                if (bestEvent.allDay) {
                                    timeBadge = Qt.formatDate(evDate, "ddd, MMM d");
                                } else {
                                    timeBadge = Qt.formatDate(evDate, "ddd") + " " + Qt.formatTime(evDate, "hh:mm");
                                }
                            }

                            root.nextEventSummary = bestEvent.summary || "Event";
                            root.nextEventTimeStr = timeBadge;
                            return;
                        }
                    }
                    root.nextEventSummary = "";
                    root.nextEventTimeStr = "";
                } catch (e) {
                    // Ignore parse errors
                }
            }
        }
    }

    Timer {
        id: eventSyncTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.refreshEvents()
    }

    function toggleStyle() {
        var next = (root.clockStyle === "at_a_glance") ? "stacked" : "at_a_glance";
        root.clockStyle = next;
        setData("clockStyle", next);
    }

    // Outer Pixel Container Card
    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.cardRadius
        color: root.cardBg
        border.color: root.borderCol
        border.width: 1
        clip: true

        // Style Switcher / Action Button in Top Right (visible on hover)
        Rectangle {
            id: styleBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            width: 28
            height: 28
            radius: 14
            z: 10
            color: styleMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"
            opacity: styleMouse.containsMouse ? 1.0 : 0.45

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            DankIcon {
                anchors.centerIn: parent
                name: root.clockStyle === "at_a_glance" ? "splitscreen" : "horizontal_distribute"
                size: 16
                color: Theme.onSurfaceVariant
            }

            MouseArea {
                id: styleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleStyle()
            }
        }

        // ==========================================
        // STYLE 1: PIXEL AT A GLANCE (HOMESCREEN)
        // ==========================================
        Item {
            id: atAGlanceView
            visible: root.clockStyle === "at_a_glance"
            anchors.fill: parent
            anchors.margins: 16

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                // Top: Large Pixel Digital Clock
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: {
                            var d = systemClock.date ?? new Date();
                            var h = d.getHours();
                            var m = d.getMinutes();
                            if (!SettingsData.use24HourClock) {
                                h = h % 12 || 12;
                            }
                            return String(h).padStart(2, '0') + ":" + String(m).padStart(2, '0');
                        }
                        font.family: root.sansBold
                        font.pixelSize: 48
                        font.weight: Font.Bold
                        color: Theme.primary
                    }

                    Text {
                        visible: !SettingsData.use24HourClock
                        text: (systemClock.date?.getHours() ?? 0) >= 12 ? "PM" : "AM"
                        font.family: root.sansMedium
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: Theme.withAlpha(Theme.primary, 0.7)
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 10
                    }

                    Item { Layout.fillWidth: true }
                }

                // Middle: Pixel "At a Glance" Date & Weather Pill Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Date Pill
                    Rectangle {
                        height: 28
                        radius: 14
                        color: Theme.secondaryContainer
                        implicitWidth: dateLabel.implicitWidth + 20

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 6

                            DankIcon {
                                name: "calendar_today"
                                size: 14
                                color: Theme.onSecondaryContainer
                            }

                            Text {
                                id: dateLabel
                                text: systemClock.date?.toLocaleDateString(I18n.locale(), "ddd, MMM d") ?? ""
                                font.family: root.sansMedium
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.onSecondaryContainer
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["dcal", "ipc", "ui.toggle"])
                        }
                    }

                    // Weather Pill
                    Rectangle {
                        visible: WeatherService.weather.available
                        height: 28
                        radius: 14
                        color: Theme.surfaceContainerHighest
                        implicitWidth: weatherRow.implicitWidth + 20

                        RowLayout {
                            id: weatherRow
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 6

                            DankIcon {
                                name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                                size: 14
                                color: Theme.primary
                            }

                            Text {
                                text: WeatherService.currentTempText()
                                font.family: root.sansMedium
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.onSurface
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["dms", "ipc", "call", "dashboard", "open", "weather"])
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Bottom: Upcoming Event from dcal
                Rectangle {
                    visible: root.hasNextEvent
                    Layout.fillWidth: true
                    height: 34
                    radius: 17
                    color: Theme.withAlpha(Theme.tertiaryContainer ?? Theme.secondaryContainer, 0.6)
                    border.color: Theme.withAlpha(Theme.outlineVariant, 0.3)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.primary
                        }

                        Text {
                            text: root.nextEventTimeStr + ":"
                            font.family: root.sansBold
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Theme.onSurface
                        }

                        Text {
                            text: root.nextEventSummary
                            font.family: root.sansRegular
                            font.pixelSize: 12
                            color: Theme.onSurface
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        DankIcon {
                            name: "open_in_new"
                            size: 13
                            color: Theme.onSurfaceVariant
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["dcal", "ipc", "ui.toggle"])
                    }
                }
            }
        }

        // ==========================================
        // STYLE 2: PIXEL STACKED LOCKSCREEN CLOCK
        // ==========================================
        Item {
            id: stackedView
            visible: root.clockStyle === "stacked"
            anchors.fill: parent
            anchors.margins: 14

            ColumnLayout {
                anchors.fill: parent
                spacing: 4

                // Two-line Huge Pixel Numerals
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: -14

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            var d = systemClock.date ?? new Date();
                            var h = d.getHours();
                            if (!SettingsData.use24HourClock) {
                                h = h % 12 || 12;
                            }
                            return String(h).padStart(2, '0');
                        }
                        font.family: root.sansBold
                        font.pixelSize: 58
                        font.weight: Font.Bold
                        color: Theme.primary
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            var d = systemClock.date ?? new Date();
                            return String(d.getMinutes()).padStart(2, '0');
                        }
                        font.family: root.sansBold
                        font.pixelSize: 58
                        font.weight: Font.Bold
                        color: Theme.primary
                    }
                }

                // Sub-pill with Date & Weather & Next Event
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Rectangle {
                        height: 24
                        radius: 12
                        color: Theme.secondaryContainer
                        implicitWidth: stackedDateText.implicitWidth + 18

                        Text {
                            id: stackedDateText
                            anchors.centerIn: parent
                            text: systemClock.date?.toLocaleDateString(I18n.locale(), "ddd, MMM d") ?? ""
                            font.family: root.sansMedium
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.onSecondaryContainer
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["dcal", "ipc", "ui.toggle"])
                        }
                    }

                    Rectangle {
                        visible: WeatherService.weather.available
                        height: 24
                        radius: 12
                        color: Theme.surfaceContainerHighest
                        implicitWidth: stackedWeatherRow.implicitWidth + 16

                        RowLayout {
                            id: stackedWeatherRow
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                                size: 12
                                color: Theme.primary
                            }

                            Text {
                                text: WeatherService.currentTempText()
                                font.family: root.sansMedium
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.onSurface
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["dms", "ipc", "call", "dashboard", "open", "weather"])
                        }
                    }
                }

                // Mini Next Event line
                Text {
                    visible: root.hasNextEvent
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width - 20
                    text: "📅 " + root.nextEventTimeStr + ": " + root.nextEventSummary
                    font.family: root.sansRegular
                    font.pixelSize: 11
                    color: Theme.onSurfaceVariant
                    elide: Text.ElideRight

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["dcal", "ipc", "ui.toggle"])
                    }
                }
            }
        }
    }
}
