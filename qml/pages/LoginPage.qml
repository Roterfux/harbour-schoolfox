import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All
    backNavigation: false

    Connections {
        target: SchoolFox
        onLoggedInChanged: if (SchoolFox.loggedIn) pageStack.pop()
        onTwoFactorRequiredChanged: if (SchoolFox.twoFactorRequired) codeField.forceActiveFocus()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("SchoolFox login") }

            TextField {
                id: userField
                width: parent.width
                visible: !SchoolFox.twoFactorRequired
                label: qsTr("Email")
                placeholderText: label
                text: SchoolFox.username
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: passwordField.focus = true
            }

            PasswordField {
                id: passwordField
                width: parent.width
                visible: !SchoolFox.twoFactorRequired
                EnterKey.enabled: userField.text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: SchoolFox.login(userField.text, text)
            }

            TextSwitch {
                visible: !SchoolFox.twoFactorRequired
                text: qsTr("Stay logged in")
                description: qsTr("Stores the password on this phone so notifications keep working when the session expires")
                checked: SchoolFox.rememberPassword
                onClicked: SchoolFox.rememberPassword = checked
            }

            TextField {
                id: codeField
                width: parent.width
                visible: SchoolFox.twoFactorRequired
                label: qsTr("Two-factor code")
                placeholderText: label
                inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: SchoolFox.submitTwoFactorCode(text)
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: SchoolFox.twoFactorRequired ? qsTr("Confirm") : qsTr("Log in")
                enabled: !SchoolFox.busy && (SchoolFox.twoFactorRequired ? codeField.text.length > 0
                                                                         : userField.text.length > 0)
                onClicked: {
                    if (SchoolFox.twoFactorRequired)
                        SchoolFox.submitTwoFactorCode(codeField.text)
                    else
                        SchoolFox.login(userField.text, passwordField.text)
                }
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: SchoolFox.busy
                visible: running
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: SchoolFox.error !== ""
                text: SchoolFox.error
                color: Theme.errorColor
                wrapMode: Text.Wrap
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Unofficial app, not made by SchoolFox. User name \"demo\" shows fake data.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }
        }
    }
}
