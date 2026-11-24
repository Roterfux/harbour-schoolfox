import QtQuick 2.2
import Sailfish.Silica 1.0

// Paste the claude.ai "sessionKey" cookie copied from a desktop browser
// (DevTools > Application/Storage > Cookies > https://claude.ai > sessionKey).
Dialog {
    id: dialog
    property string value: field.text.trim()
    canAccept: value.length > 20

    Column {
        width: parent.width
        DialogHeader { title: qsTr("Session cookie") }
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryHighlightColor
            text: qsTr("Log in to claude.ai on a computer, copy the value of the cookie \"sessionKey\" and paste it here. Treat it like a password.")
        }
        TextArea {
            id: field
            width: parent.width
            label: qsTr("sessionKey value")
            placeholderText: label
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
        }
    }
}
