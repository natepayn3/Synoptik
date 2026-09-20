import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

// A titled group of related settings. This is the unit every page is built
// from: page header, then a vertical stack of these.
//
// `bodyEnabled` covers the pattern that most pages hand-rolled - a master
// toggle in the card header, with the dependent controls below it dimmed and
// click-through-disabled when it's off. Pages used to wrap those controls in
// an extra ColumnLayout with `enabled:` and an `opacity:` of 0.35, 0.4 or 0.5
// depending on the page.
//
// The hover response lives here rather than on each page: the root is a
// plain Item that never moves and owns the HoverHandler, and the card people
// actually see is `surface`, a child that scales. Keeping the handler on the
// unscaled root means the pointer's position over the card is read in fixed
// coordinates, so growing the card cannot shift its own input.
//
// This used to be a Matrix4x4 perspective tilt. A projective transform made
// the card dip and swell near its edges, and it also took the whole subtree
// off Qt Quick's 2D paths - clip regions, antialiased rounded rects and
// Canvas content all assume an affine matrix. A scale is affine, so none of
// that applies and no layer flattening is needed to work around it.
Item {
    id: card

    default property alias cardContent: body.data

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property alias accessory: accessoryRow.data
    property bool bodyEnabled: true

    // Drifting background glyph, for the one or two "hero" cards per page that
    // earn it (live weather, the shell's About panel). A Material Symbols
    // name; empty means no watermark.
    property string watermark: ""
    property real watermarkSize: 150
    property int watermarkSeed: 0

    // A card can be pure content (a preview canvas, a device list) with no
    // header of its own; the header collapses rather than leaving dead space.
    readonly property bool hasHeader: title !== "" || icon !== "" || accessoryRow.children.length > 0

    // Escape hatch for a card the effect doesn't suit - one hosting a Popup,
    // say, which positions itself against un-scaled scene coordinates.
    property bool hoverEffect: true

    readonly property bool lifting: card.hoverEffect && cardHover.hovered

    // The pointer's position across the card, 0..1. Drives where the sheen
    // sits. Read from the unscaled root, so the lift can't feed back into it.
    readonly property real nx: width > 0
        ? Math.max(0, Math.min(1, cardHover.point.position.x / width))
        : 0.5

    Layout.fillWidth: true
    implicitHeight: surface.implicitHeight

    // A lifted card overhangs its layout slot; without this the next card
    // down draws over the raised edge.
    z: card.lifting ? 1 : 0

    HoverHandler { id: cardHover }

    Rectangle {
        id: surface

        anchors.fill: parent
        implicitHeight: inner.implicitHeight + SettingsStyle.cardPadding * 2
        radius: SettingsStyle.cardRadius
        color: SettingsStyle.cardBg
        border.width: 1
        border.color: cardHover.hovered ? SettingsStyle.cardBorderHover : SettingsStyle.cardBorder

        Behavior on border.color { ColorAnimation { duration: SettingsStyle.animFast } }

        // Scales about its own centre, which is the default transformOrigin.
        // ScaleAnimator rather than NumberAnimation: it runs on the render
        // thread, so the lift stays smooth even when the QML thread is busy
        // rebuilding a page.
        scale: card.lifting ? SettingsStyle.hoverScale : 1.0

        Behavior on scale { ScaleAnimator { duration: SettingsStyle.animMed; easing.type: Easing.OutCubic } }

        // ClippingRectangle rather than the card's own clip: a plain
        // Rectangle only clips to its square bounding box, so the glyph
        // would bleed past the rounded corners.
        ClippingRectangle {
            anchors.fill: parent
            radius: surface.radius
            color: "transparent"
            visible: card.watermark !== ""

            Watermark {
                icon: card.watermark
                iconSize: card.watermarkSize
                seed: card.watermarkSeed
                baseRotation: 12
                baseOpacity: 0.05
            }
        }

        // Glass edge: a single bright hairline along the top inside the border.
        // Cheap (one Rectangle, no layer) and it's what stops a flat translucent
        // panel from reading as a plain grey box.
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: surface.radius * 0.6
            anchors.rightMargin: surface.radius * 0.6
            height: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.11) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: SettingsStyle.cardPadding
            spacing: SettingsStyle.rowGap

            // ================= CARD HEADER =================
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: card.hasHeader

                // Top-aligned rather than centred: a card whose subtitle wraps to
                // two lines would otherwise float its icon down beside the
                // description instead of sitting level with the title.
                Text {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 1
                    text: card.icon
                    color: Config.accent
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 18
                    visible: card.icon !== ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: card.title
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                        wrapMode: Text.WordWrap
                        visible: card.title !== ""
                    }

                    Text {
                        Layout.fillWidth: true
                        text: card.subtitle
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        wrapMode: Text.WordWrap
                        visible: card.subtitle !== ""
                    }
                }

                // A nested layout defaults Layout.fillWidth to true, which would
                // split the header evenly with the text column instead of hugging
                // its own contents - and leave the title wrapping at half width.
                RowLayout {
                    id: accessoryRow
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: false
                    spacing: SettingsStyle.tightGap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: SettingsStyle.divider
                visible: card.hasHeader && body.children.length > 0
            }

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: SettingsStyle.rowGap
                enabled: card.bodyEnabled
                opacity: card.bodyEnabled ? 1.0 : SettingsStyle.disabledOpacity

                Behavior on opacity { NumberAnimation { duration: SettingsStyle.animFast } }
            }
        }

        // Specular band tracking the pointer. A gradient on a Rectangle
        // rather than a shader or a rotated strip: no clip pass, and the
        // card's own radius masks it for free. Last child so it sits over the
        // content, and it carries no input handlers, so clicks fall straight
        // through to the controls underneath.
        Rectangle {
            anchors.fill: parent
            radius: surface.radius
            visible: card.hoverEffect
            opacity: card.lifting ? 1 : 0

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: Math.max(0.0, card.nx - SettingsStyle.sheenSpread); color: "transparent" }
                GradientStop { position: card.nx; color: Qt.rgba(1, 1, 1, SettingsStyle.sheenAlpha) }
                GradientStop { position: Math.min(1.0, card.nx + SettingsStyle.sheenSpread); color: "transparent" }
            }

            Behavior on opacity { NumberAnimation { duration: SettingsStyle.animMed } }
        }
    }

}
