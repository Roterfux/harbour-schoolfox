import QtQuick 2.2
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0
import Sailfish.WebView.Popups 1.0
import Sailfish.WebView.Pickers 1.0

// claude.ai in a WebView. Login and chats are handled by the website.
Page {
    id: page
    allowedOrientations: Orientation.All

    WebView {
        id: web
        anchors.fill: parent
        url: "https://claude.ai"

        onTitleChanged: app.pageTitle = title

        popupProvider: PopupProvider {}
        pickerProvider: PickerProvider {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: web.loading
    }
}
