import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All
    backNavigation: false

    Connections {
        target: SchoolFox
        onLoggedInChanged: if (SchoolFox.loggedIn) pageStack.pop()
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
                label: qsTr("Email or username")
                placeholderText: label
                text: SchoolFox.username
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: passwordField.focus = true
            }

            PasswordField {
                id: passwordField
                width: parent.width
                EnterKey.enabled: userField.text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: SchoolFox.login(userField.text, text)
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Log in")
                enabled: userField.text.length > 0 && !SchoolFox.busy
                onClicked: SchoolFox.login(userField.text, passwordField.text)
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
                text: qsTr("Unofficial app. Tip: user name \"demo\" shows fake data.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }
        }
    }
}
