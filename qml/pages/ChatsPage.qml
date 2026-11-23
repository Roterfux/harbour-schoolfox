import QtQuick 2.2
import Sailfish.Silica 1.0
import "../util.js" as Util

// Standalone chats (tables/Conversations) of all schools.
Page {
    id: page
    allowedOrientations: Orientation.All
    property var chats: []
    property int pending: 0

    function load() {
        page.chats = []
        page.pending = 1
        SchoolFox.api("GET", "api/OrganizationsForConversations?applicationType=SchoolFox", null, function(code, body) {
            var orgs = code === 200 ? Util.parse(body) : null
            orgs = Array.isArray(orgs) ? orgs : []
            var all = []
            page.pending = orgs.length
            orgs.forEach(function(o) {
                var f = "Deleted eq false and OrganizationId eq " + Util.q(o.id)
                SchoolFox.api("GET", Util.odata("tables/Conversations", f, null, 50, 0), null, function(c2, b2) {
                    var rows = Util.results(Util.parse(b2))
                    if (rows.length > 0)
                        console.log("schoolfox: conversation keys", Object.keys(rows[0]).join(","))
                    rows.forEach(function(r) {
                        all.push({ id: r.id, schoolId: o.id, school: Util.first(o, ["name", "organizationName"]),
                                   topic: Util.first(r, ["topic", "name", "title"]) || qsTr("Chat"),
                                   unread: r.hasUnreadMessages === true,
                                   updated: Util.date(r.updatedAt) || Util.date(r.createdAt) })
                    })
                    page.pending -= 1
                    if (page.pending === 0) {
                        all.sort(function(a, b) { return (b.updated || 0) - (a.updated || 0) })
                        page.chats = all
                    }
                })
            })
        })
    }

    Component.onCompleted: load()

    SilicaListView {
        anchors.fill: parent
        model: page.chats
        header: PageHeader { title: qsTr("Chats") }

        PullDownMenu {
            MenuItem { text: qsTr("Refresh"); onClicked: page.load() }
        }

        delegate: ListItem {
            contentHeight: Theme.itemSizeMedium
            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    text: modelData.topic
                    font.bold: modelData.unread
                    truncationMode: TruncationMode.Fade
                    color: modelData.unread ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    text: Util.join([modelData.school, modelData.updated ? Format.formatDate(modelData.updated, Formatter.TimepointRelative) : ""])
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }
            }
            onClicked: pageStack.animatorPush(Qt.resolvedUrl("ChatPage.qml"), { chat: modelData })
        }

        ViewPlaceholder {
            enabled: page.pending === 0 && page.chats.length === 0
            text: qsTr("No chats")
            hintText: qsTr("New chats are started in the SchoolFox app")
        }
        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: page.pending > 0
        }
        VerticalScrollDecorator {}
    }
}
