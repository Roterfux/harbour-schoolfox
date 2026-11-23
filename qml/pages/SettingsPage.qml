import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    allowedOrientations: Orientation.All

    readonly property var intervals: [5, 10, 15, 30, 60]

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader { title: qsTr("Settings") }

            SectionHeader { text: qsTr("Notifications") }

            TextSwitch {
                text: qsTr("Sailfish notifications")
                description: qsTr("Show new SchoolFox messages in the Events view, also when the app is closed")
                checked: SchoolFox.notificationsEnabled
                onClicked: SchoolFox.notificationsEnabled = checked
            }

            TextSwitch {
                text: qsTr("Show message text")
                description: qsTr("Off: only the title appears in the notification")
                enabled: SchoolFox.notificationsEnabled
                checked: SchoolFox.notificationContent
                onClicked: SchoolFox.notificationContent = checked
            }

            ComboBox {
                label: qsTr("Check every")
                currentIndex: Math.max(0, intervals.indexOf(SchoolFox.pollMinutes))
                menu: ContextMenu {
                    Repeater {
                        model: intervals
                        MenuItem { text: qsTr("%n min", "", modelData) }
                    }
                }
                onCurrentIndexChanged: SchoolFox.pollMinutes = intervals[currentIndex]
            }

            DetailItem {
                label: qsTr("Last background check")
                value: isNaN(SchoolFox.lastBackgroundCheck.getTime()) ? qsTr("never")
                       : Format.formatDate(SchoolFox.lastBackgroundCheck, Formatter.TimepointRelative)
            }

            SectionHeader { text: qsTr("Account") }

            DetailItem {
                label: qsTr("Logged in as")
                value: SchoolFox.fullName !== "" ? SchoolFox.fullName : SchoolFox.username
            }

            TextSwitch {
                text: qsTr("Stay logged in")
                description: qsTr("Stores your password on this phone (not encrypted) so the app can log in again by itself when the session expires.")
                checked: SchoolFox.rememberPassword
                onClicked: SchoolFox.rememberPassword = checked
            }

            TextSwitch {
                text: qsTr("Mark read in SchoolFox (experimental)")
                description: qsTr("Tries to tell SchoolFox when you open a message. The method is a guess and may do nothing.")
                checked: SchoolFox.markReadOnServer
                onClicked: SchoolFox.markReadOnServer = checked
            }

            Item { width: 1; height: Theme.paddingLarge }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Log out")
                enabled: SchoolFox.loggedIn
                onClicked: remorse.execute(qsTr("Logging out"), function() {
                    SchoolFox.logout()
                    pageStack.pop()
                })
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Unofficial app, not made by SchoolFox. Attachments are saved in Downloads/SchoolFox.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }
        }
        VerticalScrollDecorator {}
    }

    RemorsePopup { id: remorse }
}
