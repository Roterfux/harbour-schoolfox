import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    // Show login on top when not logged in.
    function checkLogin() {
        if (!SchoolFox.loggedIn && status === PageStatus.Active)
            pageStack.animatorPush(Qt.resolvedUrl("LoginPage.qml"))
    }
    onStatusChanged: checkLogin()
    Connections {
        target: SchoolFox
        onLoggedInChanged: page.checkLogin()
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: SchoolFox.messages

        header: PageHeader {
            title: "SchoolFox"
            description: SchoolFox.unreadCount > 0
                         ? qsTr("%n unread", "", SchoolFox.unreadCount) : ""
        }

        PullDownMenu {
            busy: SchoolFox.busy
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Refresh")
                enabled: SchoolFox.loggedIn && !SchoolFox.busy
                onClicked: SchoolFox.refresh()
            }
        }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeLarge
            property var msg: modelData

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    text: msg.title
                    truncationMode: TruncationMode.Fade
                    font.bold: !msg.read
                    color: item.highlighted || !msg.read ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    text: msg.sender + " · " + Format.formatDate(msg.date, Formatter.TimepointRelative)
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                }
            }

            onClicked: {
                SchoolFox.markRead(msg.id)
                pageStack.animatorPush(Qt.resolvedUrl("MessagePage.qml"), { message: msg })
            }
        }

        ViewPlaceholder {
            enabled: listView.count === 0 && !SchoolFox.busy
            text: SchoolFox.error !== "" ? SchoolFox.error : qsTr("No messages")
            hintText: qsTr("Pull down to refresh")
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: SchoolFox.busy && listView.count === 0
        }

        VerticalScrollDecorator {}
    }
}
