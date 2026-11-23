import QtQuick 2.2
import Sailfish.Silica 1.0
import "pages"

ApplicationWindow {
    id: app

    initialPage: Component {
        MessagesPage {}
    }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    property string pendingMessageId: ""

    function openMessage(id) {
        var m = SchoolFox.findMessage(id)
        if (!m || !m.id) {
            // not loaded yet: refresh and try again when the list arrives
            pendingMessageId = id
            SchoolFox.refresh()
            return
        }
        pendingMessageId = ""
        while (pageStack.depth > 1)
            pageStack.pop(null, PageStackAction.Immediate)
        SchoolFox.markRead(m.id)
        pageStack.push(Qt.resolvedUrl("pages/MessagePage.qml"), { message: m }, PageStackAction.Immediate)
    }

    // Notification taps (via D-Bus, see src/appservice.h)
    Connections {
        target: AppService
        onOpenMessageRequested: { app.activate(); app.openMessage(id) }
        onActivateRequested: app.activate()
    }

    Connections {
        target: SchoolFox
        onMessagesChanged: if (app.pendingMessageId !== "") app.openMessage(app.pendingMessageId)
    }

    // The background service sends notifications. The app only refreshes its
    // list while it is visible (or on the cover).
    Timer {
        interval: Math.max(5, SchoolFox.pollMinutes) * 60 * 1000
        repeat: true
        running: SchoolFox.loggedIn && Qt.application.active
        onTriggered: SchoolFox.refresh()
    }

    Connections {
        target: Qt.application
        onActiveChanged: if (Qt.application.active && SchoolFox.loggedIn) SchoolFox.refresh()
    }

    Component.onCompleted: if (SchoolFox.loggedIn) SchoolFox.refresh()
}
