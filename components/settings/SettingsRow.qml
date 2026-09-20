import QtQuick
import QtQuick.Layouts
import ".."

// Label + optional description on the left, control(s) on the right. The
// horizontal unit inside a SettingsCard.
//
// The text column takes `Layout.preferredWidth: 1` with `fillWidth` so it
// absorbs all slack and the control keeps its natural size - without the
// preferred width a long description would push the control off the card
// instead of wrapping.
RowLayout {
    id: row

    default property alias control: controlRow.data

    property string title: ""
    property string subtitle: ""
    // Optional leading Material Symbols glyph. Used by the denser lists
    // (System Info's field toggles, Hyprland's input options) where an icon
    // per row makes a long column of similar text scannable.
    property string icon: ""

    // Dims and disables this row when the setting it depends on is off. A
    // local flag rather than a read of `enabled`, so a row nested inside an
    // already-dimmed SettingsCard body doesn't get dimmed twice.
    property bool active: true

    Layout.fillWidth: true
    spacing: 12
    enabled: row.active
    opacity: row.active ? 1.0 : SettingsStyle.disabledOpacity

    Behavior on opacity { NumberAnimation { duration: SettingsStyle.animFast } }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: row.icon
        color: Config.accent
        font.family: "Material Symbols Outlined"
        font.pixelSize: 17
        visible: row.icon !== ""
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: 0
        spacing: 2
        visible: row.title !== "" || row.subtitle !== ""

        Text {
            Layout.fillWidth: true
            text: row.title
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontBody)
            wrapMode: Text.WordWrap
            visible: row.title !== ""
        }

        Text {
            Layout.fillWidth: true
            text: row.subtitle
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            wrapMode: Text.WordWrap
            visible: row.subtitle !== ""
        }
    }

    // See SettingsCard's accessory row: a nested layout fills by default.
    RowLayout {
        id: controlRow
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: false
        spacing: SettingsStyle.tightGap
    }
}
