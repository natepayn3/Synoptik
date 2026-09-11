import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Polkit
import ".."

// Native polkit authentication agent.
//
// Until now Config.syncHyprlandBorders() autostarted `hyprpolkitagent`, so
// every privilege prompt in the session - mounting a disk, installing a
// package, writing a charge threshold - arrived in a window styled by
// something else entirely. It was the one visual seam left in a shell whose
// whole premise is a single unified surface.
//
// The hard part of this was already solved: Lockscreen.qml does PAM
// authentication, and this reuses the same password-bar language so the two
// read as the same shell asking.
//
// Quickshell registers this as the session's authentication agent for as long
// as the shell is running. The hyprpolkitagent autostart that used to be
// written into hypr_style.lua is gone; if another agent is running anyway,
// whichever registered last wins and the other sits idle.
Scope {
    id: polkitScope

    readonly property var flow: polkitAgent.flow
    readonly property bool prompting: polkitAgent.isActive && !!polkitAgent.flow

    // polkit hands over a list of identities that could authorise the action -
    // usually just the current user, sometimes root as well. The Identity type
    // is not exported with a schema, so read its label defensively rather than
    // assuming a property name.
    function identityLabel(ident) {
        if (!ident) return ""
        if (ident.displayName) return ident.displayName
        if (ident.name) return ident.name
        if (ident.userName) return ident.userName
        if (ident.uid !== undefined) return "uid " + ident.uid
        return "" + ident
    }

    readonly property var identityList: (flow && flow.identities) ? flow.identities : []

    PolkitAgent {
        id: polkitAgent

        onAuthenticationRequestStarted: {
            passField.text = ""
            // A privilege prompt appearing under an open drawer would be
            // invisible; close whatever panel is up so this is what you see.
            Config.closeAllPanels()
        }
    }

    function submit() {
        if (!polkitScope.flow) return
        if (!polkitScope.flow.isResponseRequired) return
        polkitScope.flow.submit(passField.text)
        passField.text = ""
    }

    function cancel() {
        if (polkitScope.flow) polkitScope.flow.cancelAuthenticationRequest()
        passField.text = ""
    }

    PanelWindow {
        id: polkitWindow
        visible: polkitScope.prompting

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "synoptik-shell-polkit"
        // An auth prompt that can't take a password is useless, so this is one
        // of the few surfaces in the shell that takes an exclusive grab.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusiveZone: 0

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // Dim the session behind the prompt, the same way the lockscreen does,
        // so it reads as modal rather than as another floating widget.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)

            MouseArea {
                anchors.fill: parent
                // Swallow clicks so a stray click outside can't reach the
                // desktop, but don't cancel on it - losing a half-typed
                // password to a misclick is worse than having to hit Escape.
                onClicked: {}
            }
        }

        ClippingRectangle {
            id: dialog

            // Keys.* attaches to an Item, and a PanelWindow is not one - put
            // the Escape handler on the dialog itself, which is also what
            // holds focus.
            Keys.onEscapePressed: event => {
                polkitScope.cancel()
                event.accepted = true
            }
            anchors.centerIn: parent
            width: Math.min(440, polkitWindow.width - 48)
            implicitHeight: dialogColumn.implicitHeight + 36
            height: implicitHeight
            radius: Config.cornerRadius
            color: Config.bgBase
            border.width: Config.borderThickness > 0 ? Config.borderThickness : 1
            border.color: polkitScope.flow && polkitScope.flow.supplementaryIsError
                ? "#ef4444"
                : Config.accent

            Behavior on border.color { ColorAnimation { duration: 180 } }

            focus: true
            Component.onCompleted: passField.forceActiveFocus()

            ColumnLayout {
                id: dialogColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 12

                // --- HEADER ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                        border.width: 1
                        border.color: Config.accent

                        Text {
                            anchors.centerIn: parent
                            text: "admin_panel_settings"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            color: Config.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "AUTHENTICATION REQUIRED"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            font.letterSpacing: 0.8
                        }

                        Text {
                            // polkit's message is written for humans and names
                            // the actual operation ("Authentication is required
                            // to install software"), which is the one thing the
                            // user needs in order to decide.
                            text: (polkitScope.flow && polkitScope.flow.message)
                                ? polkitScope.flow.message
                                : "An application is requesting elevated privileges."
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // --- ACTION ID ---
                // The polkit action behind the prompt, e.g.
                // org.freedesktop.policykit.exec. Small and muted: useful when
                // a prompt appears unexpectedly and you want to know what asked.
                Text {
                    visible: polkitScope.flow && polkitScope.flow.actionId !== ""
                    text: polkitScope.flow ? polkitScope.flow.actionId : ""
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }

                // --- IDENTITY PICKER ---
                // Only when polkit offers a real choice; a single candidate
                // needs no UI.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    visible: polkitScope.identityList.length > 1

                    Text {
                        text: "AUTHENTICATE AS"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: polkitScope.identityList

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isActive:
                                    polkitScope.flow && polkitScope.flow.selectedIdentity === modelData

                                implicitWidth: identLabel.implicitWidth + 20
                                implicitHeight: 26
                                radius: 6
                                color: isActive
                                    ? Config.accent
                                    : (identHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05))
                                border.width: 1
                                border.color: isActive ? Config.accent : Qt.rgba(255, 255, 255, 0.12)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    id: identLabel
                                    anchors.centerIn: parent
                                    text: polkitScope.identityLabel(modelData)
                                    color: isActive ? Config.bgBase : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                }

                                TapHandler {
                                    onTapped: {
                                        if (polkitScope.flow) polkitScope.flow.selectedIdentity = modelData
                                        passField.forceActiveFocus()
                                    }
                                }
                                HoverHandler { id: identHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                // --- PASSWORD FIELD ---
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.width: 1
                    border.color: passField.activeFocus ? Config.accent : Qt.rgba(255, 255, 255, 0.12)
                    visible: polkitScope.flow ? polkitScope.flow.isResponseRequired : false

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "key"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: Config.textMuted
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextInput {
                            id: passField
                            Layout.fillWidth: true
                            clip: true
                            // polkit can ask for something that isn't secret
                            // (a one-time code, a fingerprint confirmation),
                            // and says so via responseVisible.
                            echoMode: (polkitScope.flow && polkitScope.flow.responseVisible)
                                ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            onAccepted: polkitScope.submit()

                            Text {
                                anchors.fill: parent
                                visible: passField.text === "" && !passField.activeFocus
                                text: (polkitScope.flow && polkitScope.flow.inputPrompt)
                                    ? polkitScope.flow.inputPrompt
                                    : "Password"
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // --- SUPPLEMENTARY MESSAGE ---
                // PAM's own feedback: "Authentication failure", "Password
                // expired", or an informational line. Colour follows
                // supplementaryIsError rather than assuming every message is
                // a failure.
                Text {
                    visible: polkitScope.flow
                        && polkitScope.flow.supplementaryMessage !== ""
                    text: polkitScope.flow ? polkitScope.flow.supplementaryMessage : ""
                    color: (polkitScope.flow && polkitScope.flow.supplementaryIsError)
                        ? "#ef4444" : Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                // --- BUTTONS ---
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: cancelLabel.implicitWidth + 28
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2
                        color: cancelHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.12)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: cancelLabel
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }

                        TapHandler { onTapped: polkitScope.cancel() }
                        HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                    }

                    Rectangle {
                        implicitWidth: authLabel.implicitWidth + 28
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2
                        color: authHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent
                        border.width: 1
                        border.color: Config.accent
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: authLabel
                            anchors.centerIn: parent
                            text: "Authenticate"
                            color: Config.bgBase
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }

                        TapHandler { onTapped: polkitScope.submit() }
                        HoverHandler { id: authHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
}
