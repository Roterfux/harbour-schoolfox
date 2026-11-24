import QtQuick 2.2
import Sailfish.Silica 1.0

CoverBackground {
    Image {
        anchors.centerIn: parent
        source: "/usr/share/icons/hicolor/172x172/apps/harbour-claudechat.png"
        width: parent.width * 0.6
        height: width
        opacity: 0.4
    }
    Label {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: Theme.paddingLarge }
        text: app.pageTitle !== "" ? app.pageTitle : qsTr("Claude Chat")
        horizontalAlignment: Text.AlignHCenter
        truncationMode: TruncationMode.Fade
        font.pixelSize: Theme.fontSizeSmall
    }
}
