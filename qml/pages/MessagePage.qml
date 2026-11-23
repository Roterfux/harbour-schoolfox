import QtQuick 2.2
import Sailfish.Silica 1.0
import "../util.js" as Util

Page {
    id: page
    property var message
    allowedOrientations: Orientation.All

    readonly property bool hasContent: (page.message.body || "").trim() !== ""
    property var detail: null
    property var attachments: []
    property var myRecord: null          // recipient record for confirmation
    property bool confirmBusy: false
    property string status: ""
    readonly property string icsText: Util.ics(page.message)

    Component.onCompleted: {
        if (!hasContent)
            SchoolFox.loadContent(page.message.id)
        if (SchoolFox.demo)
            return
        SchoolFox.api("GET", "tables/Messages/" + page.message.id, null, function(code, body) {
            if (code !== 200) return
            var d = Util.parse(body)
            if (!d) return
            console.log("schoolfox: detail keys", Object.keys(d).join(","))
            page.detail = d
            var info = d.info || []
            for (var i = 0; i < info.length; ++i) {
                if (info[i].userId === SchoolFox.userId
                        && (!page.message.pupilId || info[i].pupilId === page.message.pupilId)) {
                    page.myRecord = info[i]
                    break
                }
            }
        })
        SchoolFox.api("GET", "api/Files/Messages/" + page.message.id, null, function(code, body) {
            var list = code === 200 ? Util.parse(body) : null
            page.attachments = Array.isArray(list) ? list : []
        })
    }

    Connections {
        target: SchoolFox
        // signal argument is also called "message"
        onMessageUpdated: if (message.id === page.message.id) page.message = message
    }

    function confirm() {
        var r = page.myRecord
        var body = {}
        for (var k in r) body[k] = r[k]
        body.signedByUserId = SchoolFox.userId
        body.signingDate = new Date().toISOString()
        page.confirmBusy = true
        SchoolFox.api("PATCH", "tables/MessageRelatedPupils/" + r.id, body, function(code, resp) {
            page.confirmBusy = false
            if (code >= 200 && code < 300) {
                page.myRecord = body
                page.status = qsTr("Confirmed")
            } else {
                page.status = qsTr("Confirmation failed (%1)").arg(code)
            }
        })
    }

    function download(name) {
        page.status = qsTr("Downloading %1…").arg(name)
        SchoolFox.downloadAttachment(page.message.id, name, function(ok, result) {
            if (ok) {
                page.status = qsTr("Saved to %1").arg(result)
                Qt.openUrlExternally("file://" + result)
            } else {
                page.status = result
            }
        })
    }

    function addToCalendar() {
        var path = SchoolFox.saveTextFile("schoolfox-" + page.message.id + ".ics", page.icsText)
        if (path === "") {
            page.status = qsTr("Cannot save calendar file")
            return
        }
        Qt.openUrlExternally("file://" + path)
    }

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            visible: replyItem.visible || calendarItem.visible
            MenuItem {
                id: calendarItem
                text: qsTr("Add to calendar")
                visible: page.icsText !== ""
                onClicked: page.addToCalendar()
            }
            MenuItem {
                id: replyItem
                text: qsTr("Replies")
                visible: page.detail !== null && page.detail.instantMessagesAllowed === true
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("RepliesPage.qml"),
                                                  { message: page.message, detail: page.detail })
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: page.message.title
                description: Util.join([page.message.sender, page.message.pupil])
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: page.message.date ? Format.formatDate(page.message.date, Formatter.DateFull) + " "
                                          + Format.formatDate(page.message.date, Formatter.TimeValue) : ""
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.message.eventDate || page.message.dueDate ? true : false
                text: page.message.eventDate
                      ? qsTr("Event: %1").arg(Format.formatDate(page.message.eventDate, Formatter.DateFull)
                                              + " " + Format.formatDate(page.message.eventDate, Formatter.TimeValue))
                      : page.message.dueDate
                        ? qsTr("Due: %1").arg(Format.formatDate(page.message.dueDate, Formatter.DateFull)) : ""
                wrapMode: Text.Wrap
                color: Theme.highlightColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                readonly property bool html: Util.isHtml(page.message.html)
                text: html ? page.message.html : page.message.body
                textFormat: html ? Text.StyledText : Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                linkColor: Theme.primaryColor
                onLinkActivated: Qt.openUrlExternally(link)
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: !page.hasContent
                visible: running
                size: BusyIndicatorSize.Medium
            }

            // --- confirmation ---
            SectionHeader {
                text: qsTr("Confirmation")
                visible: page.myRecord !== null
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.myRecord !== null
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: !page.myRecord ? ""
                      : (page.myRecord.signedByUserId || page.myRecord.signingDate)
                        ? qsTr("Confirmed")
                        : page.detail && page.detail.signatureRequired === true
                          ? qsTr("This message needs a signature. Please sign it in the SchoolFox app.")
                          : qsTr("The teacher asks you to confirm that you have read this message.")
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: page.myRecord !== null && !page.myRecord.signedByUserId && !page.myRecord.signingDate
                         && page.detail && page.detail.signatureRequired === false
                enabled: !page.confirmBusy
                text: qsTr("Confirm")
                onClicked: remorse.execute(qsTr("Confirming"), page.confirm)
            }

            // --- attachments ---
            SectionHeader {
                text: qsTr("Attachments")
                visible: page.attachments.length > 0
            }
            Repeater {
                model: page.attachments
                BackgroundItem {
                    width: column.width
                    height: Theme.itemSizeSmall
                    onClicked: page.download(modelData.name)
                    Image {
                        id: fileIcon
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-attach"
                    }
                    Label {
                        anchors {
                            left: fileIcon.right; leftMargin: Theme.paddingMedium
                            right: parent.right; rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        text: modelData.name + (modelData.size ? "  (" + Format.formatFileSize(modelData.size) + ")" : "")
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.status !== ""
                text: page.status
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
            }
        }

        VerticalScrollDecorator {}
    }
}
