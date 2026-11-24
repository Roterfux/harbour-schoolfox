import QtQuick 2.2
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0
import Sailfish.WebView.Controls 1.0
import Sailfish.WebView.Popups 1.0
import Sailfish.WebView.Pickers 1.0

// claude.ai in a WebView. Web login (email code) works as usual; if it does
// not (e.g. Google login blocked), paste the sessionKey cookie via the menu.
Page {
    id: page
    allowedOrientations: Orientation.All

    function applyCookie(value) {
        var js = "document.cookie = 'sessionKey=' + " + JSON.stringify(value)
               + " + '; domain=.claude.ai; path=/; secure; max-age=2592000; samesite=lax'; true"
        web.runJavaScript(js, function() { web.url = "https://claude.ai/new" })
    }

    SilicaWebView {
        id: web
        anchors.fill: parent
        url: "https://claude.ai"

        onTitleChanged: app.pageTitle = title

        popupProvider: PopupProvider {}
        pickerProvider: PickerProvider {}

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
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: web.loading
    }
}
