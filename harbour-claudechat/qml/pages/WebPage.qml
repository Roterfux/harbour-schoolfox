import QtQuick 2.2
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0
import Sailfish.WebView.Popups 1.0

// claude.ai in a WebView. Web login (email code) works as usual; if it does
// not (e.g. Google login blocked), paste the sessionKey cookie via the menu.
Page {
    id: page
    allowedOrientations: Orientation.All

    property string status: qsTr("Starting WebView")

    function applyCookie(value) {
        var js = "document.cookie = 'sessionKey=' + " + JSON.stringify(value)
               + " + '; domain=.claude.ai; path=/; secure; max-age=2592000; samesite=lax'; true"
        web.runJavaScript(js, function() { web.url = "https://claude.ai/new" })
    }

    WebView {
        id: web
        anchors.fill: parent
        // Set after the page exists: the engine may not be ready at creation.
        Component.onCompleted: web.url = "https://claude.ai"

        onTitleChanged: app.pageTitle = title
        onLoadingChanged: page.status = (loading ? qsTr("Loading") : qsTr("Loaded")) + " " + loadProgress + "%"
        onViewInitialized: page.status = qsTr("Engine ready")

        popupProvider: PopupProvider {}

        PullDownMenu {
            MenuItem {
                text: qsTr("Set session cookie")
                onClicked: {
                    var d = pageStack.animatorPush(Qt.resolvedUrl("CookieDialog.qml"))
                    d.pageCompleted.connect(function() {
                        d.page.accepted.connect(function() { page.applyCookie(d.page.value) })
                    })
                }
            }
            MenuItem { text: qsTr("New chat"); onClicked: web.url = "https://claude.ai/new" }
            MenuItem { text: qsTr("Reload"); onClicked: web.reload() }
            MenuItem { text: qsTr("Open in browser"); onClicked: Qt.openUrlExternally(web.url) }
        }
    }

    // Visible until the page shows something; helps when the view stays white.
    Column {
        visible: web.loading || web.title === ""
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: Theme.horizontalPageMargin }
        spacing: Theme.paddingMedium
        Label {
            width: parent.width
            wrapMode: Text.Wrap
            color: "#444444"
            font.pixelSize: Theme.fontSizeExtraSmall
            text: page.status + "\n" + web.url
        }
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Open in browser")
            onClicked: Qt.openUrlExternally("https://claude.ai")
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: web.loading
    }
}
