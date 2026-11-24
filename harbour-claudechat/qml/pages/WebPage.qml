import QtQuick 2.2
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0
import Sailfish.WebView.Popups 1.0

// claude.ai in a WebView. Plain Item (not a Page): it is created inside
// StartPage. WebView is no Flickable, so no PullDownMenu: a small menu
// button opens MenuPage instead.
Item {
    id: root
    property string status: qsTr("Starting WebView")

    function load(url) { web.url = url }
    function reload() { web.reload() }
    function currentUrl() { return web.url.toString() }

    function applyCookie(value) {
        var js = "document.cookie = 'sessionKey=' + " + JSON.stringify(value)
               + " + '; domain=.claude.ai; path=/; secure; max-age=2592000; samesite=lax'; true"
        web.runJavaScript(js, function() { web.url = "https://claude.ai/new" })
    }

    WebView {
        id: web
        anchors.fill: parent
        popupProvider: PopupProvider {}

        // Set after creation: the engine may not be ready earlier.
        Component.onCompleted: web.url = "https://claude.ai"

        onTitleChanged: app.pageTitle = title
        onLoadingChanged: root.status = (loading ? qsTr("Loading") : qsTr("Loaded")) + " " + loadProgress + "%"
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: web.loading
    }

    // Status while nothing is shown yet (dark text: page background is white).
    Label {
        visible: web.loading || web.title === ""
        anchors { bottom: parent.bottom; left: parent.left; right: menuButton.left; margins: Theme.horizontalPageMargin }
        wrapMode: Text.Wrap
        color: "#444444"
        font.pixelSize: Theme.fontSizeExtraSmall
        text: root.status + "\n" + web.url
    }

    // Menu button (bottom right, small, semi-transparent)
    Rectangle {
        id: menuButton
        anchors { right: parent.right; bottom: parent.bottom; margins: Theme.paddingLarge }
        width: Theme.itemSizeSmall
        height: width
        radius: width / 2
        color: "#cc333333"
        IconButton {
            anchors.centerIn: parent
            icon.source: "image://theme/icon-m-menu"
            icon.color: "white"
            onClicked: pageStack.animatorPush(Qt.resolvedUrl("MenuPage.qml"), { web: root })
        }
    }
}
