import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    id: page
    property var message
    allowedOrientations: Orientation.All

    readonly property bool hasContent: (page.message.body || "").trim() !== ""
    Component.onCompleted: if (!hasContent) SchoolFox.loadContent(page.message.id)

    Connections {
        target: SchoolFox
        // signal argument is also called "message"
        onMessageUpdated: if (message.id === page.message.id) page.message = message
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: message.title
                description: [message.sender, message.pupil].filter(function(x) { return x }).join(" · ")
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
                readonly property bool isHtml: /<[a-zA-Z][^>]*>/.test(message.html || "")
                text: isHtml ? message.html : message.body
                textFormat: isHtml ? Text.StyledText : Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                linkColor: Theme.primaryColor
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }

        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            y: column.height + Theme.paddingLarge
            running: !page.hasContent
            visible: running
            size: BusyIndicatorSize.Medium
        }

        VerticalScrollDecorator {}
    }
}
