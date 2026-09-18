import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: card

    width: 480
    height: contentColumn.implicitHeight + 88
    radius: 30
    border.color: "#40ffd88a"
    border.width: 1.2

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#592f2145" }
        GradientStop { position: 1.0; color: "#592a1a3d" }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#66000000"
        shadowBlur: 0.6
        shadowVerticalOffset: 10
        shadowHorizontalOffset: 0
    }

    property string errorMessage: ""

    Connections {
        target: sddm
        function onLoginFailed() {
            card.errorMessage = qsTr("Login failed")
            passwordField.selectAll()
            passwordField.forceActiveFocus()
        }
        function onLoginSucceeded() {
            card.errorMessage = ""
        }
    }

    Component.onCompleted: passwordField.forceActiveFocus()

    ColumnLayout {
        id: contentColumn
        anchors.centerIn: parent
        width: parent.width - 80
        spacing: 16

        Text {
            text: "✦ " + qsTr("Welcome back")
            color: "#fdf6ec"
            font.pixelSize: 31
            font.bold: true
            Layout.fillWidth: true
        }

        Text {
            text: qsTr("Sign in to continue")
            color: "#c9b8e0"
            font.pixelSize: 16
            Layout.fillWidth: true
            Layout.bottomMargin: 4
        }

        Rectangle {
            Layout.preferredWidth: 62
            Layout.preferredHeight: 5
            Layout.bottomMargin: 8
            radius: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#ff6fae" }
                GradientStop { position: 1.0; color: "#f5c150" }
            }
        }

        StyledComboBox {
            id: userBox
            Layout.fillWidth: true
            model: sddm.userModel
            textRole: "name"
            currentIndex: sddm.userModel.lastIndex
        }

        TextField {
            id: passwordField
            Layout.fillWidth: true
            implicitHeight: 58
            placeholderText: qsTr("Password")
            placeholderTextColor: "#8f7fa8"
            echoMode: TextInput.Password
            color: "#fdf6ec"
            selectionColor: "#ff6fae"
            font.pixelSize: 18
            leftPadding: 18
            rightPadding: 18
            onAccepted: loginButton.clicked()

            background: Rectangle {
                radius: 14
                color: passwordField.activeFocus ? "#26ffffff" : "#14ffffff"
                border.color: passwordField.activeFocus ? "#ffd88a" : "#40ffffff"
                border.width: 1.5
            }
        }

        StyledComboBox {
            id: sessionBox
            Layout.fillWidth: true
            model: sddm.sessionModel
            textRole: "name"
            currentIndex: sddm.sessionModel.lastIndex
        }

        Text {
            text: card.errorMessage
            color: "#ff8fae"
            visible: card.errorMessage.length > 0
            font.pixelSize: 15
            Layout.fillWidth: true
        }

        Button {
            id: loginButton
            Layout.fillWidth: true
            Layout.topMargin: 6
            implicitHeight: 58
            text: qsTr("Log In")

            background: Rectangle {
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: loginButton.pressed ? "#e0568f" : "#ff6fae" }
                    GradientStop { position: 1.0; color: loginButton.pressed ? "#d19a2e" : "#f5c150" }
                }
            }

            contentItem: Text {
                text: loginButton.text
                color: "#2a1a3d"
                font.pixelSize: 19
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: sddm.login(userBox.currentText, passwordField.text, sessionBox.currentIndex)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 14
            spacing: 14

            PowerButton {
                iconText: "⏻"
                visible: sddm.canPowerOff
                onClicked: sddm.powerOff()
            }
            PowerButton {
                iconText: "⟳"
                visible: sddm.canReboot
                onClicked: sddm.reboot()
            }
            PowerButton {
                iconText: "⏾"
                visible: sddm.canSuspend
                onClicked: sddm.suspend()
            }
        }
    }
}
