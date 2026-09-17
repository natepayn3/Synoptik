import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// One row of a tray item's D-Bus menu, and - when that row has a submenu - the
// submenu itself, expanded inline underneath it.
//
// Inline rather than cascading on purpose. Every other surface in this shell is
// one plane that changes shape (see UnifiedSurface's popouts); a stack of
// floating menu windows sprouting sideways off the bar would be the one place
// that stops being true. Expanding in place also means a submenu can never open
// off the edge of the screen, which cascading menus on a bar constantly do.
Item {
    id: entryRoot

    // A QsMenuEntry. Its `triggered()` signal is the activation call - emitting
    // it is what tells the owning app the row was clicked.
    property var entry: null
    property int depth: 0
    property real rowWidth: 240

    // Guard against a malformed or self-referential menu tree walking forever.
    // Real tray menus are two levels deep at most; four is slack, not a target.
    readonly property int maxDepth: 4

    signal activated()

    readonly property bool isSeparator: entry ? entry.isSeparator === true : false
    readonly property bool hasChildren: entry ? entry.hasChildren === true : false
    readonly property bool isEnabled: entry ? entry.enabled !== false : false
    readonly property int buttonType: entry ? entry.buttonType : 0
    readonly property bool isChecked: entry ? entry.checkState === Qt.Checked : false

    property bool expanded: false

    // Collapse when the whole menu goes away, so reopening an item doesn't
    // restore a submenu the user expanded three sessions ago.
    onEntryChanged: expanded = false

    implicitWidth: rowWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: entryRoot.rowWidth
        spacing: 2

        // --- SEPARATOR ---
        Rectangle {
            visible: entryRoot.isSeparator
            Layout.fillWidth: true
            Layout.topMargin: 3
            Layout.bottomMargin: 3
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            implicitHeight: 1
            color: Qt.rgba(255, 255, 255, 0.1)
        }

        // --- ROW ---
        Rectangle {
            id: row
            visible: !entryRoot.isSeparator
            Layout.fillWidth: true
            implicitHeight: 30
            radius: Config.cornerRadius / 2
            color: (rowHover.hovered && entryRoot.isEnabled)
                ? Qt.rgba(255, 255, 255, 0.12)
                : "transparent"
            opacity: entryRoot.isEnabled ? 1.0 : 0.4

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8 + (entryRoot.depth * 12)
                anchors.rightMargin: 8
                spacing: 8

                // Checkbox / radio state. Drawn rather than glyph-swapped so a
                // checked item reads at a glance in the accent colour, the same
                // way toggles do everywhere else in the shell.
                Rectangle {
                    visible: entryRoot.buttonType !== 0
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    radius: entryRoot.buttonType === 2 ? 7 : 3
                    color: entryRoot.isChecked ? Config.accent : "transparent"
                    border.width: 1
                    border.color: entryRoot.isChecked ? Config.accent : Qt.rgba(255, 255, 255, 0.3)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        visible: entryRoot.isChecked && entryRoot.buttonType === 1
                        text: "check"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 11
                        color: Config.bgBase
                    }
                }

                // Routed through the tray's icon guard rather than bound
                // straight to entry.icon: a menu row's icon is the same
                // image://icon/<name> URL a tray item's is, and Quickshell will
                // build one for a name the theme doesn't have, which renders as
                // a magenta checkerboard instead of failing to load.
                IconImage {
                    visible: source !== ""
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    asynchronous: true
                    source: entryRoot.entry ? Config.tray.menuIconFor(entryRoot.entry.icon) : ""
                }

                Text {
                    text: (entryRoot.entry && entryRoot.entry.text) ? entryRoot.entry.text : ""
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Submenu affordance: rotates to point down once expanded, the
                // accordion convention, instead of the sideways caret a
                // cascading menu would use.
                Text {
                    visible: entryRoot.hasChildren
                    text: "chevron_right"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 14
                    color: entryRoot.expanded ? Config.accent : Config.textMuted
                    rotation: entryRoot.expanded ? 90 : 0

                    Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            TapHandler {
                enabled: entryRoot.isEnabled
                onTapped: {
                    if (entryRoot.hasChildren) {
                        entryRoot.expanded = !entryRoot.expanded
                        return
                    }
                    if (entryRoot.entry) entryRoot.entry.triggered()
                    entryRoot.activated()
                }
            }

            HoverHandler {
                id: rowHover
                cursorShape: entryRoot.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

        // --- SUBMENU ---
        // Loaded only once expanded: a QsMenuOpener asks the application to
        // populate that submenu over D-Bus, so instantiating one per row up
        // front would have every tray app build every submenu it owns the
        // moment the menu opens.
        Loader {
            id: subLoader
            Layout.fillWidth: true
            active: entryRoot.expanded && entryRoot.hasChildren && entryRoot.depth < entryRoot.maxDepth
            visible: active

            sourceComponent: Column {
                width: entryRoot.rowWidth
                spacing: 2

                QsMenuOpener {
                    id: subOpener
                    menu: entryRoot.entry
                }

                Repeater {
                    model: subOpener.children

                    // Loaded by URL rather than as a TrayMenuEntry {} block.
                    // A file-based QML type cannot reference itself anywhere in
                    // its own tree - the engine rejects it at compile time with
                    // "TrayMenuEntry is instantiated recursively" - and being
                    // inside a Repeater delegate does not exempt it, because
                    // that check runs before anything is ever instantiated.
                    // A URL is resolved at load time instead, which is how a
                    // recursive tree is built in QML.
                    delegate: Loader {
                        id: childLoader
                        required property var modelData

                        width: entryRoot.rowWidth
                        source: "TrayMenuEntry.qml"

                        onLoaded: {
                            item.entry = childLoader.modelData
                            item.depth = entryRoot.depth + 1
                            item.rowWidth = entryRoot.rowWidth
                            // Chains the child's activation up to this row,
                            // so triggering anything at any depth collapses
                            // the whole menu exactly once.
                            item.activated.connect(entryRoot.activated)
                        }

                        // onLoaded assigns rather than binds, so the one
                        // property that can change afterwards needs a real
                        // binding to follow it.
                        Binding {
                            target: childLoader.item
                            property: "rowWidth"
                            value: entryRoot.rowWidth
                            when: childLoader.item !== null
                        }
                    }
                }
            }
        }
    }
}
