import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    id: page
    property var web
    allowedOrientations: Orientation.All

    function go(fn) { pageStack.pop(); fn() }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height
        Column {
            id: col
            width: parent.width
            PageHeader { title: qsTr("Claude Chat") }
            BackgroundItem {
                Label { x: Theme.horizontalPageMargin; anchors.verticalCenter: parent.verticalCenter; text: qsTr("New chat") }
                onClicked: page.go(function() { page.web.load("https://claude.ai/new") })
            }
            BackgroundItem {
                Label { x: Theme.horizontalPageMargin; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Reload") }
                onClicked: page.go(function() { page.web.reload() })
            }
            BackgroundItem {
                Label { x: Theme.horizontalPageMargin; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Set session cookie") }
                onClicked: {
                    var d = pageStack.replace(Qt.resolvedUrl("CookieDialog.qml"))
                    var w = page.web
                    d.accepted.connect(function() { w.applyCookie(d.value) })
                }
            }
            BackgroundItem {
                Label { x: Theme.horizontalPageMargin; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Open in browser") }
                onClicked: Qt.openUrlExternally(page.web.currentUrl())
            }
        }
        VerticalScrollDecorator {}
    }
}
