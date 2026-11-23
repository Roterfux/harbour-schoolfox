import QtQuick 2.2
import Sailfish.Silica 1.0
import "../util.js" as Util

// Upcoming events and due dates of all children (tables/Messages filtered).
Page {
    id: page
    allowedOrientations: Orientation.All
    property int pending: 0

    property var events: []

    function load() {
        page.events = []
        var pupils = SchoolFox.pupils
        var now = new Date()
        var day = now.getUTCFullYear() + "-" + Util.pad(now.getUTCMonth() + 1) + "-" + Util.pad(now.getUTCDate())
                + "T00:00:00Z"
        var all = []
        page.pending = pupils.length
        pupils.forEach(function(p) {
            var f = "Deleted eq false and SchoolClassId eq " + Util.q(p.classId)
                  + " and PupilId eq " + Util.q(p.pupilId)
                  + " and ((MessageType eq 'Event' and EndDate ge datetime'" + day + "')"
                  + " or DueDate ge datetime'" + day + "')"
            SchoolFox.api("GET", Util.odata("tables/Messages", f, "EventDate asc", 50, 0), null,
                          function(code, body) {
                Util.results(Util.parse(body)).forEach(function(row) {
                    var m = Util.message(row, p)
                    m.when = m.eventDate || m.dueDate || m.date
                    all.push(m)
                })
                page.pending -= 1
                if (page.pending === 0) {
                    all.sort(function(a, b) { return (a.when || 0) - (b.when || 0) })
                    page.events = all
                }
            })
        })
    }

    Component.onCompleted: load()

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.events
        header: PageHeader { title: qsTr("Events and due dates") }

        PullDownMenu {
            MenuItem { text: qsTr("Refresh"); onClicked: page.load() }
        }

        delegate: ListItem {
            contentHeight: col.height + 2 * Theme.paddingMedium
            Column {
                id: col
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    text: modelData.title
                    truncationMode: TruncationMode.Fade
                    color: Theme.highlightColor
                }
                Label {
                    width: parent.width
                    text: Util.join([modelData.when ? Format.formatDate(modelData.when, Formatter.DateFull) : "",
                                     modelData.eventDate ? "" : qsTr("due"), modelData.pupil])
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }
            }
            onClicked: pageStack.animatorPush(Qt.resolvedUrl("MessagePage.qml"), { message: modelData })
        }

        ViewPlaceholder {
            enabled: page.pending === 0 && page.events.length === 0
            text: qsTr("No upcoming events")
        }
        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: page.pending > 0
        }
        VerticalScrollDecorator {}
    }
}
