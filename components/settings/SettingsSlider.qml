import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import ".."

// Labelled slider with a live value badge. Consolidates the
// `component ThickHorizontalSlider : Slider { ... }` block that Appearance,
// Cava, Display and Hyprland each declared privately, plus the value-readout
// Rectangle that was rebuilt beside every one of them.
//
// Drives `moved` rather than `valueChanged`: valueChanged also fires when the
// binding to Config pushes a new value in, which turned every external config
// reload into a spurious write.
//
// QtQuick.Controls.Basic is imported here (not plain QtQuick.Controls) because
// this file overrides `background` and `handle` - a style-specific import is
// required for control customisation, and scoping it to this one file keeps
// the rest of the module run-time style-selectable.
ColumnLayout {
    id: root

    property string label: ""
    property string hint: ""
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string suffix: ""
    property int decimals: 0
    property bool showValue: true

    // See SettingsRow.active - dims and disables this slider when the setting
    // it depends on is off.
    property bool active: true

    signal moved(real value)

    readonly property string displayValue: root.value.toFixed(root.decimals) + root.suffix

    Layout.fillWidth: true
    spacing: SettingsStyle.tightGap
    enabled: root.active
    opacity: root.active ? 1.0 : SettingsStyle.disabledOpacity

    Behavior on opacity { NumberAnimation { duration: SettingsStyle.animFast } }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: root.label !== "" || root.showValue

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.label
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                font.letterSpacing: 0.4
                wrapMode: Text.WordWrap
                visible: root.label !== ""
            }

            Text {
                Layout.fillWidth: true
                text: root.hint
                color: Config.textMuted
                opacity: 0.75
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                wrapMode: Text.WordWrap
                visible: root.hint !== ""
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: valueText.implicitWidth + 16
            implicitHeight: 22
            radius: SettingsStyle.controlRadius * 0.7
            color: SettingsStyle.controlBg
            border.width: 1
            border.color: SettingsStyle.accentLine
            visible: root.showValue

            Text {
                id: valueText
                anchors.centerIn: parent
                text: root.displayValue
                color: Config.accent
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
            }
        }
    }

    Slider {
        id: slider

        Layout.fillWidth: true
        implicitHeight: 24
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value

        onMoved: root.moved(slider.value)

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            implicitHeight: 6
            height: implicitHeight
            radius: 3
            color: SettingsStyle.trackBg

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 3
                color: Config.accent
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 8
            scale: slider.pressed ? 1.15 : 1.0
            color: slider.pressed ? Config.accent : Config.textMain
            border.width: 2
            border.color: Config.bgBase

            Behavior on scale { NumberAnimation { duration: SettingsStyle.animFast; easing.type: Easing.OutBack } }
        }
    }
}
