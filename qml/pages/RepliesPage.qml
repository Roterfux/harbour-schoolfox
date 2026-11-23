import QtQuick 2.2
import Sailfish.Silica 1.0
import "../util.js" as Util

// Reply thread of one class message (tables/InstantMessageGroups / InstantMessages).
Page {
    id: page
    property var message
    property var detail
    property var group: null
    property bool loading: true
    property bool sending: false
    property string status: ""
    allowedOrientations: Orientation.All

    ListModel { id: replies }

    function load() {
        page.loading = true
        var f = "MessageId eq " + Util.q(page.message.id) + " and PupilId eq " + Util.q(page.message.pupilId)
        SchoolFox.api("GET", Util.odata("tables/InstantMessageGroups", f, "UpdatedAt desc", 50, 0), null,
                      function(code, body) {
            var groups = Util.results(Util.parse(body))
            page.group = groups.length > 0 ? groups[0] : null
            if (!page.group) {
                page.loading = false
                return
            }
            console.log("schoolfox: reply group keys", Object.keys(page.group).join(","))
            var rf = "InstantMessageGroupId eq " + Util.q(page.group.id)
                   + " and PupilId eq " + Util.q(page.message.pupilId)
            SchoolFox.api("GET", Util.odata("tables/InstantMessages", rf, "CreatedAt desc", 100, 0), null,
                          function(code2, body2) {
                page.loading = false
                var rows = Util.results(Util.parse(body2))
                if (rows.length > 0)
                    console.log("schoolfox: reply keys", Object.keys(rows[0]).join(","))
                replies.clear()
                for (var i = rows.length - 1; i >= 0; --i) {   // oldest first
                    var r = rows[i]
                    replies.append({
                        text: Util.plain(Util.first(r, ["content", "Content"])),
                        who: Util.first(r, ["creatorFullName", "CreatorFullName"]),
                        when: Util.date(r.createdAt) ? Util.date(r.createdAt).toISOString() : ""
                    })
                }
                list.positionViewAtEnd()
            })
        })
    }

    function send(text) {
        var g = page.group
        if (!g || g.isActive !== true || !g.schoolClassId || !g.pupilFullName) {
            page.status = qsTr("Replies are not possible for this message")
            return
        }
        page.sending = true
        SchoolFox.api("POST", "tables/InstantMessages", {
            MessageId: page.message.id,
            PupilId: page.message.pupilId,
            SchoolClassId: g.schoolClassId,
            IsActive: true,
            Content: text,
            InstantMessageGroupId: g.id,
            PupilFullName: g.pupilFullName,
            CreatorFullName: SchoolFox.fullName
        }, function(code, body) {
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
        model: replies
        header: PageHeader { title: qsTr("Replies"); description: page.message.title }

        delegate: ListItem {
            contentHeight: col.height + 2 * Theme.paddingSmall
            Column {
                id: col
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    text: Util.join([model.who, model.when ? Format.formatDate(new Date(model.when), Formatter.TimepointRelative) : ""])
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryHighlightColor
                }
                Label {
                    width: parent.width
                    text: model.text
                    wrapMode: Text.Wrap
                    color: Theme.highlightColor
                }
            }
        }

        ViewPlaceholder {
            enabled: !page.loading && replies.count === 0
            text: page.group ? qsTr("No replies yet") : qsTr("No reply thread for this message")
            hintText: page.group ? "" : qsTr("Reply threads are started in the SchoolFox app")
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
        visible: page.group !== null && page.group.isActive === true
        Label {
            x: Theme.horizontalPageMargin
            visible: page.status !== ""
            text: page.status
            color: Theme.errorColor
            font.pixelSize: Theme.fontSizeExtraSmall
        }
        TextArea {
            id: input
            width: parent.width
            placeholderText: qsTr("Write a reply")
            label: qsTr("Reply")
            enabled: !page.sending
            EnterKey.enabled: text.trim().length > 0
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: page.send(text.trim())
        }
    }
}
