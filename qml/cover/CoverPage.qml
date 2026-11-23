import QtQuick 2.2
import Sailfish.Silica 1.0

CoverBackground {
    id: cover
    readonly property var unread: SchoolFox.messages.filter(function(m) { return !m.read })
    readonly property var latest: (unread.length > 0 ? unread : SchoolFox.messages).slice(0, 3)

    Image {   // faint icon watermark
        anchors { right: parent.right; bottom: parent.bottom; margins: -Theme.paddingLarge }
        source: "/usr/share/icons/hicolor/172x172/apps/harbour-schoolfox.png"
        width: parent.width * 0.6
        height: width
        opacity: 0.12
    }

    Column {
        x: Theme.paddingLarge
        y: Theme.paddingLarge
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingSmall

        Row {
            spacing: Theme.paddingMedium
            Label {
                id: countLabel
                text: SchoolFox.loggedIn ? SchoolFox.unreadCount : "–"
                font.pixelSize: Theme.fontSizeHuge
                color: SchoolFox.unreadCount > 0 ? Theme.highlightColor : Theme.primaryColor
            }
            Label {
                anchors.baseline: countLabel.baseline
                text: SchoolFox.loggedIn ? qsTr("unread") : qsTr("not logged in")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                width: cover.width - countLabel.width - 3 * Theme.paddingLarge
                wrapMode: Text.Wrap
            }
        }

        Repeater {
            model: cover.latest
            Label {
                width: parent.width
                text: modelData.title
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeExtraSmall
                font.bold: !modelData.read
                color: modelData.read ? Theme.secondaryColor : Theme.primaryColor
            }
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
