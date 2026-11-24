import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader { title: qsTr("Settings") }

            PasswordField {
                id: keyField
                width: parent.width
                label: qsTr("Anthropic API key")
                placeholderText: label
                text: Claude.apiKey
                onTextChanged: if (activeFocus) Claude.apiKey = text
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: modelField.focus = true
            }
            TextField {
                id: modelField
                width: parent.width
                label: qsTr("Model")
                placeholderText: label
                text: Claude.model
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                onTextChanged: if (activeFocus) Claude.model = text
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: promptField.focus = true
            }
            TextArea {
                id: promptField
                width: parent.width
                label: qsTr("System prompt")
                placeholderText: label
                text: Claude.systemPrompt
                onTextChanged: if (activeFocus) Claude.systemPrompt = text
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("The key is stored unencrypted in ~/.config/org.roterfux/harbour-claudechat/settings.conf.")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
            }
        }
        VerticalScrollDecorator {}
    }
}
