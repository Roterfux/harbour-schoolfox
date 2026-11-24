import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    Connections {
        target: Claude
        onMessagesChanged: list.positionViewAtEnd()
    }

    SilicaListView {
        id: list
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: composer.top }
        clip: true
        model: Claude.messages
        header: PageHeader { title: qsTr("Claude"); description: Claude.model }

        PullDownMenu {
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("New chat")
                enabled: Claude.messages.length > 0
                onClicked: Claude.clear()
            }
        }

        delegate: Item {
            width: list.width
            height: col.height + 2 * Theme.paddingSmall
            readonly property bool mine: modelData.role === "user"
            Column {
                id: col
                x: mine ? Theme.horizontalPageMargin * 3 : Theme.horizontalPageMargin
                width: parent.width - 4 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    horizontalAlignment: mine ? Text.AlignRight : Text.AlignLeft
                    text: mine ? qsTr("You") : qsTr("Claude")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryHighlightColor
                }
                Label {
                    width: parent.width
                    horizontalAlignment: mine ? Text.AlignRight : Text.AlignLeft
                    text: modelData.text
                    wrapMode: Text.Wrap
                    color: mine ? Theme.primaryColor : Theme.highlightColor
                }
            }
        }

        ViewPlaceholder {
            enabled: Claude.messages.length === 0
            text: qsTr("No messages")
            hintText: Claude.apiKey === "" ? qsTr("Pull down and set your API key") : qsTr("Write a message below")
        }
        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: Claude.busy
        }
        VerticalScrollDecorator {}
    }

    Column {
        id: composer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            visible: Claude.error !== ""
            text: Claude.error
            color: Theme.errorColor
            font.pixelSize: Theme.fontSizeExtraSmall
            wrapMode: Text.Wrap
        }
        TextArea {
            id: input
            width: parent.width
            placeholderText: qsTr("Write a message")
            label: qsTr("Message")
            enabled: !Claude.busy
            EnterKey.enabled: text.trim().length > 0
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: {
                Claude.send(text)
                text = ""
            }
        }
    }
}
