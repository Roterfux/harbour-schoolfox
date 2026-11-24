import QtQuick 2.2
import Sailfish.Silica 1.0

// Icon with a small label underneath; used in action rows.
BackgroundItem {
    id: root
    property alias icon: img.source
    property alias text: label.text
    property bool active: false

    width: Theme.itemSizeExtraLarge
    height: col.height + 2 * Theme.paddingSmall

    Column {
        id: col
        anchors.centerIn: parent
        spacing: Theme.paddingSmall / 2
        Image {
            id: img
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.enabled ? 1 : 0.4
        }
        Label {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width
            horizontalAlignment: Text.AlignHCenter
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeTiny
            color: root.active || root.highlighted ? Theme.highlightColor : Theme.secondaryColor
        }
    }
}
