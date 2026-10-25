import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    property bool acceptsKeyboardFocus: false

    widgetWidth: 260
    widgetHeight: 280
    minWidth: 160
    minHeight: 160

    property real bgOpacity: 0.85
    property color cardBg: Theme.withAlpha(Theme.surfaceContainer, bgOpacity)
    property color borderCol: Theme.withAlpha(Theme.outlineVariant, 0.45)
    property real cardRadius: 28

    // Load authentic Google Sans Bold font
    FontLoader {
        id: fontBold
        source: "./fonts/GoogleSans-Bold.ttf"
    }

    readonly property string sansBold: fontBold.name.length > 0 ? fontBold.name : "Google Sans"

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    // Dynamic digit sizing based on widget bounds
    readonly property real digitSize: Math.min(card.width * 0.48, card.height * 0.44)
    readonly property real overlapOffset: digitSize * 0.72

    // Outer Pixel Container Card
    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.cardRadius
        color: root.cardBg
        border.color: root.borderCol
        border.width: 1
        clip: true

        // Pixel Lockscreen "Number Overlap" Clock
        Item {
            id: clockContainer
            anchors.centerIn: parent
            width: Math.max(hoursText.implicitWidth, minutesText.implicitWidth)
            height: digitSize + root.overlapOffset

            // Hours (Top layer / line 1)
            Text {
                id: hoursText
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                text: {
                    var d = systemClock.date ?? new Date();
                    var h = d.getHours();
                    if (!SettingsData.use24HourClock) {
                        h = h % 12 || 12;
                    }
                    return String(h).padStart(2, '0');
                }
                font.family: root.sansBold
                font.pixelSize: root.digitSize
                font.weight: Font.Bold
                font.letterSpacing: -root.digitSize * 0.04
                color: Theme.primary
                horizontalAlignment: Text.AlignHCenter
                z: 1
            }

            // Minutes (Bottom layer / line 2 - overlaps the lower portion of hours)
            Text {
                id: minutesText
                anchors.horizontalCenter: parent.horizontalCenter
                y: hoursText.y + root.overlapOffset
                text: {
                    var d = systemClock.date ?? new Date();
                    return String(d.getMinutes()).padStart(2, '0');
                }
                font.family: root.sansBold
                font.pixelSize: root.digitSize
                font.weight: Font.Bold
                font.letterSpacing: -root.digitSize * 0.04
                color: Theme.primary
                style: Text.Outline
                styleColor: root.cardBg
                horizontalAlignment: Text.AlignHCenter
                z: 2
            }
        }
    }
}
