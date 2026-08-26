import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Screen-wide right-click catcher for the "Desktop Widgets" menu. The four
// desktop widgets (Clock/SysInfo/Cava/Mascot) each already open the same
// menu when right-clicked directly, but their own input masks only cover
// their own small footprint by design (so clicks elsewhere pass through to
// normal windows). This surface sits on the same Bottom layer, mapped before
// those widgets so they stack above it and keep first claim on their own
// area, and catches right-clicks anywhere else on the empty desktop.
//
// Trade-off: this claims the *entire* screen's input region to be able to
// see a right-click anywhere on it. Left-clicks landing on empty desktop
// (nothing else on top) are swallowed here too - used only to dismiss any
// open widget menu, but Wayland gives us no way to hand an unused click back
// to Hyprland - so if you rely on click-on-empty-desktop-to-defocus
// behavior, this will get in the way there. Removing this file/its Variants
// entry in shell.qml fully reverts that.
PanelWindow {
    id: contextWindow

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-desktop-context-menu"
    WlrLayershell.keyboardFocus: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: -1

    mask: Region { item: catchArea }

    Item {
        id: catchArea
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            // Left is accepted too, purely so a click on empty desktop
            // dismisses whichever widget's menu (this one or another
            // widget's) is currently open - it never opens anything itself.
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton && !widgetMenu.visible) {
                    widgetMenu.openAt(mouse.x, mouse.y, catchArea, contextWindow.width, contextWindow.height)
                } else {
                    Config.closeWidgetMenus()
                }
            }
        }

        WidgetContextMenu { id: widgetMenu }
    }
}
