import QtQuick 2.2
import Sailfish.Silica 1.0

// Loads the WebView page; if its QML fails (missing module etc.) show why,
// because a failed load is otherwise just a white screen.
Page {
    id: page
    allowedOrientations: Orientation.All
    property string errorText: ""

    Component.onCompleted: {
        var c = Qt.createComponent(Qt.resolvedUrl("WebPage.qml"))
        if (c.status === Component.Ready) {
            var o = c.createObject(page, { "anchors.fill": page })
            if (!o) page.errorText = "createObject failed"
        } else {
            page.errorText = c.errorString()
        }
    }

    Rectangle { anchors.fill: parent; color: "white"; visible: page.errorText !== "" }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height
        visible: page.errorText !== ""
        Column {
            id: col
            width: parent.width
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: implicitHeight + 2 * Theme.paddingLarge
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Claude Chat failed to start")
                font.pixelSize: Theme.fontSizeLarge
                color: "#111111"
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: "#111111"
                text: page.errorText
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Open in browser")
                onClicked: Qt.openUrlExternally("https://claude.ai")
            }
        }
        VerticalScrollDecorator {}
    }
}
