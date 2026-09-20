import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

// Root of every settings page. Owns the four things that used to be
// re-implemented (differently) on each one: scrolling, the centred reading
// column, the page header, and the gap rhythm between cards.
//
// Previously the 24 pages rooted themselves five different ways - Flickable,
// Item + ScrollView, Item with no scrolling at all, and a bare ColumnLayout
// anchored to a parent it didn't own - so a page that outgrew the window
// either scrolled, clipped, or silently cut its last control off depending on
// which pattern it happened to have been written with. Settings.qml's
// `findFlickable` scroll indicator also only worked on the Flickable ones.
//
// Usage: declare cards as direct children; they land in the content column.
//
//   SettingsPage {
//       title: "Clock"
//       description: "Desktop clock overlay and formatting"
//       icon: "schedule"
//
//       SettingsCard { title: "Clock Widget"; SettingsToggleRow { ... } }
//   }
Flickable {
    id: page

    default property alias pageContent: contentColumn.data

    property string title: ""
    property string description: ""
    property string icon: ""
    property real maxContentWidth: SettingsStyle.contentMaxWidth

    // Lets a page hang a persistent control off the header - "Reset to
    // defaults", a scan button, a live status pill - without inventing its own
    // header row and breaking alignment with every other page.
    property alias headerAccessory: headerAccessoryRow.data

    // Slot for items that must live in the page but take no layout space -
    // a focus-grabbing key listener, a hidden measuring Text. Anything put
    // here sits outside the content column, so it can't perturb the spacing.
    property alias detached: detachedHost.data

    contentWidth: width
    contentHeight: layoutColumn.implicitHeight + SettingsStyle.pageGap * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar {
        id: pageScrollBar
        policy: ScrollBar.AsNeeded
        active: page.moving || page.flicking
    }

    Item { id: detachedHost }

    ColumnLayout {
        id: layoutColumn

        y: SettingsStyle.pageGap
        width: Math.min(page.width - SettingsStyle.pageGap * 2, page.maxContentWidth)
        x: Math.max(SettingsStyle.pageGap, (page.width - width) / 2)
        spacing: SettingsStyle.pageGap

        // ================= PAGE HEADER =================
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: -SettingsStyle.tightGap / 2
            spacing: 12
            visible: page.title !== ""

            // Accent badge. Echoes the "SETTINGS" badge in the shell header so
            // the page reads as a continuation of it rather than a new surface.
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 38
                implicitHeight: 38
                radius: SettingsStyle.controlRadius
                visible: page.icon !== ""

                gradient: Gradient {
                    GradientStop { position: 0.0; color: SettingsStyle.accentMed }
                    GradientStop { position: 1.0; color: SettingsStyle.accentSoft }
                }
                border.width: 1
                border.color: SettingsStyle.accentLine

                Text {
                    anchors.centerIn: parent
                    text: page.icon
                    color: Config.accent
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 21
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: page.title
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead)
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: page.description
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    wrapMode: Text.WordWrap
                    visible: page.description !== ""
                }
            }

            RowLayout {
                id: headerAccessoryRow
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: false
                spacing: SettingsStyle.tightGap
            }
        }

        // Hairline under the header, fading out to the right so it reads as a
        // rule under the title rather than a box edge.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            visible: page.title !== ""

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: SettingsStyle.accentLine }
                GradientStop { position: 0.55; color: SettingsStyle.divider }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            spacing: SettingsStyle.pageGap
        }
    }
}
