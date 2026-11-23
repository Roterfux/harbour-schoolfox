import QtQuick 2.2
import Sailfish.Silica 1.0
import Nemo.Notifications 1.0
import Nemo.KeepAlive 1.2
import "pages"

ApplicationWindow {
    id: app

    initialPage: Component {
        MessagesPage {}
    }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    function showMessages() {
        while (pageStack.depth > 1)
            pageStack.pop(null, PageStackAction.Immediate)
        app.activate()
    }

    // Wakes the device periodically while the app runs (also when on cover).
    BackgroundJob {
        id: pollJob
        enabled: SchoolFox.loggedIn
        frequency: {
            var m = SchoolFox.pollMinutes
            if (m <= 5) return BackgroundJob.FiveMinutes
            if (m <= 10) return BackgroundJob.TenMinutes
            if (m <= 15) return BackgroundJob.FifteenMinutes
            if (m <= 30) return BackgroundJob.ThirtyMinutes
            return BackgroundJob.OneHour
        }
        onTriggered: {
            console.log("schoolfox: background poll")
            SchoolFox.refresh()
        }
    }

    Connections {
        target: SchoolFox
        onRefreshFinished: if (pollJob.running) pollJob.finished()
        onNewMessages: {
            for (var i = 0; i < messages.length; ++i) {
                var m = messages[i]
                var text = SchoolFox.notificationContent ? (m.body || "").trim().replace(/\s+/g, " ") : ""
                if (text.length > 300) text = text.substring(0, 300) + "…"
                var who = [m.sender, m.pupil].filter(function(x) { return x }).join(" · ")
                var n = notificationComponent.createObject(app, {
                    summary: m.title,
                    body: text,
                    previewSummary: m.title,
                    previewBody: text,
                    subText: who,
                    timestamp: m.date
                })
                n.publish()
            }
        }
    }

    Component {
        id: notificationComponent
        Notification {
            appName: "SchoolFox"
            appIcon: "harbour-schoolfox"
            category: "x-nemo.messaging.im"
            onClicked: app.showMessages()
        }
    }
}
