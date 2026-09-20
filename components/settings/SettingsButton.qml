import QtQuick
import QtQuick.Layouts
import ".."

// Action button. `variant` picks the weight:
//   "quiet"  - default, neutral surface (Cancel, Browse, Reset)
//   "accent" - the primary action of a card (Apply, Connect, Save)
//   "danger" - destructive (Forget Network, Remove, Delete)
Rectangle {
    id: control

    property string label: ""
    property string icon: ""
    property string variant: "quiet"
    property bool busy: false

    signal clicked()

    readonly property bool isAccent: variant === "accent"
    readonly property bool isDanger: variant === "danger"

    // An icon with no label is a square, not a pill - a chevron or an arrow in
    // a 42x32 box reads as off-centre even though the glyph is centred in it.
    readonly property bool isIconOnly: label === "" && icon !== ""

    implicitWidth: control.isIconOnly ? control.implicitHeight : contentRow.implicitWidth + 26
    implicitHeight: 32
    radius: SettingsStyle.controlRadius
    opacity: control.enabled ? 1.0 : 0.4

    color: control.isDanger
        ? (hover.hovered ? Qt.rgba(0.937, 0.267, 0.267, 0.34) : SettingsStyle.dangerSoft)
        : control.isAccent
            ? (hover.hovered ? Qt.lighter(Config.accent, 1.12) : Config.accent)
            : (hover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)

    border.width: 1
    border.color: control.isDanger
        ? SettingsStyle.danger
        : (control.isAccent ? Config.accent : SettingsStyle.controlBorder)

    scale: tap.pressed ? 0.96 : 1.0

    Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }

    // A quiet button picks up the accent on hover, which is how the buttons
    // this replaced signalled themselves - the neutral surface alone is a very
    // faint hover cue on a translucent panel.
    readonly property color foreground: control.isDanger
        ? SettingsStyle.danger
        : (control.isAccent
            ? Config.bgBase
            : (hover.hovered ? Config.accent : Config.textMain))

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: control.icon
            color: control.foreground
            font.family: "Material Symbols Outlined"
            font.pixelSize: 16
            visible: control.icon !== "" && !control.busy

            Layout.alignment: Qt.AlignVCenter
        }

        // Spinner shown in place of the icon while a long-running action
        // (git pull, nmcli scan, theme apply) is in flight.
        Text {
            text: "progress_activity"
            color: control.foreground
            font.family: "Material Symbols Outlined"
            font.pixelSize: 16
            visible: control.busy

            Layout.alignment: Qt.AlignVCenter

            RotationAnimator on rotation {
                running: control.busy && control.visible
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
            }
        }

        // An empty label is still a layout item, so without this the row keeps
        // its 6px spacing for a zero-width Text and an icon-only button's
        // glyph sits 3px left of centre.
        Text {
            text: control.label
            color: control.foreground
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
            visible: control.label !== ""

            Layout.alignment: Qt.AlignVCenter
        }
    }

    TapHandler {
        id: tap
        enabled: control.enabled
        onTapped: control.clicked()
    }
    HoverHandler { id: hover; enabled: control.enabled; cursorShape: Qt.PointingHandCursor }
}
