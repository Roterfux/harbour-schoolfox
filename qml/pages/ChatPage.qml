import QtQuick 2.2
import Sailfish.Silica 1.0
import "../util.js" as Util

// One conversation: history (tables/ConversationMessages) and sending text.
Page {
    id: page
    property var chat
    property var conversation: null
    property var lines: []
    property bool loading: true
    property bool sending: false
    property string status: ""
    allowedOrientations: Orientation.All

    readonly property bool canWrite: conversation !== null && conversation.isClosed === false
        && (conversation.conversationUserRole === "Admin"
            || (conversation.conversationUserRole === "Member" && conversation.isReadOnlyForMembers === false))

    function load() {
        page.loading = true
        SchoolFox.api("GET", "tables/Conversations/" + page.chat.id, null, function(code, body) {
            var c = code === 200 ? Util.parse(body) : null
            page.conversation = c && c.organizationId === page.chat.schoolId ? c : null
        })
        var f = "ConversationId eq " + Util.q(page.chat.id)
        SchoolFox.api("GET", Util.odata("tables/ConversationMessages", f, null, 100, 0), null, function(code, body) {
            page.loading = false
            var rows = Util.results(Util.parse(body))
            if (rows.length > 0)
                console.log("schoolfox: chat message keys", Object.keys(rows[0]).join(","))
            var out = rows.map(function(r) {
                return { text: Util.plain(Util.first(r, ["content", "Content", "text"])),
                         who: Util.first(r, ["creatorFullName", "senderFullName", "userFullName",
                                             "createdByFullName", "authorFullName"]),
                         mine: (r.userId || r.createdBy || r.creatorId || r.senderId) === SchoolFox.userId,
                         when: Util.date(r.createdAt) }
            })
            out.sort(function(a, b) { return (a.when || 0) - (b.when || 0) })
            page.lines = out
            list.positionViewAtEnd()
        })
    }

    function send(text) {
        page.sending = true
        SchoolFox.api("POST", "tables/ConversationMessages",
                      { organizationId: page.chat.schoolId, conversationId: page.chat.id,
                        content: text, inReplyToId: null }, function(code) {
            page.sending = false
            if (code >= 200 && code < 300) {
                input.text = ""
                page.status = ""
                page.load()
            } else {
                page.status = qsTr("Sending failed (%1)").arg(code)
            }
        })
    }

    Component.onCompleted: load()

    SilicaListView {
        id: list
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: composer.top }
        clip: true
        model: page.lines
        header: PageHeader { title: page.chat.topic; description: page.chat.school }

        PullDownMenu {
            MenuItem { text: qsTr("Refresh"); onClicked: page.load() }
        }

        delegate: ListItem {
            contentHeight: col.height + 2 * Theme.paddingSmall
            Column {
                id: col
                x: modelData.mine ? Theme.horizontalPageMargin * 3 : Theme.horizontalPageMargin
                width: parent.width - 4 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    horizontalAlignment: modelData.mine ? Text.AlignRight : Text.AlignLeft
                    text: Util.join([modelData.mine ? qsTr("You") : modelData.who,
                                     modelData.when ? Format.formatDate(modelData.when, Formatter.TimepointRelative) : ""])
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryHighlightColor
                }
                Label {
                    width: parent.width
                    horizontalAlignment: modelData.mine ? Text.AlignRight : Text.AlignLeft
                    text: modelData.text
                    wrapMode: Text.Wrap
                    color: modelData.mine ? Theme.primaryColor : Theme.highlightColor
                }
            }
        }

        ViewPlaceholder {
            enabled: !page.loading && page.lines.length === 0
            text: qsTr("No messages")
        }
        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: page.loading
        }
        VerticalScrollDecorator {}
    }

    Column {
        id: composer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            visible: page.status !== "" || (!page.canWrite && page.conversation !== null)
            text: page.status !== "" ? page.status : qsTr("This chat is read-only")
            color: Theme.secondaryHighlightColor
            font.pixelSize: Theme.fontSizeExtraSmall
            wrapMode: Text.Wrap
        }
        TextArea {
            id: input
            width: parent.width
            visible: page.canWrite
            placeholderText: qsTr("Write a message")
            label: qsTr("Message")
            enabled: !page.sending
            EnterKey.enabled: text.trim().length > 0
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: page.send(text.trim())
        }
    }
}
