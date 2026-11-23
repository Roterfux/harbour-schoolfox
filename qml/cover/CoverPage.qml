import QtQuick 2.2
import Sailfish.Silica 1.0

CoverBackground {
    readonly property var newest: SchoolFox.messages.length > 0 ? SchoolFox.messages[0] : null

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingSmall

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "/usr/share/icons/hicolor/86x86/apps/harbour-schoolfox.png"
            width: Theme.iconSizeMedium
            height: width
            opacity: 0.6
        }

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
            width: parent.width
            visible: newest !== null
            text: newest ? newest.title : ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeExtraSmall
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
