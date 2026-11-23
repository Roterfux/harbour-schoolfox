import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    allowedOrientations: Orientation.All

    readonly property var intervals: [5, 10, 15, 30, 60]

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader { title: qsTr("Settings") }

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

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Checks run while the app is open or on the cover. Close the app = no notifications.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                wrapMode: Text.Wrap
            }

            SectionHeader { text: qsTr("Account") }

            DetailItem {
                label: qsTr("Logged in as")
                value: SchoolFox.username
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Log out")
                enabled: SchoolFox.loggedIn
                onClicked: remorse.execute(qsTr("Logging out"), function() {
                    SchoolFox.logout()
                    pageStack.pop()
                })
            }
        }
    }

    RemorsePopup { id: remorse }
}
