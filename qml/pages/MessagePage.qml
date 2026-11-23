import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    property var message
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: message.title
                description: message.sender
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: Format.formatDate(message.date, Formatter.DateFull) + " "
                      + Format.formatDate(message.date, Formatter.TimeValue)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: message.body
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                color: Theme.highlightColor
            }
        }

        VerticalScrollDecorator {}
    }
}
