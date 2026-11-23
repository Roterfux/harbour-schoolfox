import QtQuick 2.2
import Sailfish.Silica 1.0

CoverBackground {
    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingSmall

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: SchoolFox.loggedIn ? SchoolFox.unreadCount : "–"
            font.pixelSize: Theme.fontSizeHuge
            color: Theme.primaryColor
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: SchoolFox.loggedIn ? qsTr("unread") : qsTr("not logged in")
            color: Theme.secondaryColor
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "SchoolFox"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.highlightColor
        }
    }

    CoverActionList {
        enabled: SchoolFox.loggedIn
        CoverAction {
            iconSource: "image://theme/icon-cover-refresh"
            onTriggered: SchoolFox.refresh()
        }
    }
}
