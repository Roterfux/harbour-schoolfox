import QtQuick 2.2
import Sailfish.Silica 1.0

CoverBackground {
    readonly property var last: Claude.messages.length > 0 ? Claude.messages[Claude.messages.length - 1] : null

    Label {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.paddingLarge }
        text: Claude.busy ? qsTr("Thinking…") : (last ? last.text : qsTr("Claude Chat"))
        wrapMode: Text.Wrap
        maximumLineCount: 8
        truncationMode: TruncationMode.Fade
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.primaryColor
    }

    CoverActionList {
        CoverAction {
            iconSource: "image://theme/icon-cover-cancel"
            onTriggered: Claude.clear()
        }
    }
}
