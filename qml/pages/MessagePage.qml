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
    property string attachState: "loading"   // loading | done | error
    property var previews: ({})               // file name -> local path (images)
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
            // fallback: some replies may list files inside the message itself
            if (page.attachments.length === 0) {
                var inner = Util.attachments(d.files || d.attachments || d.Files || null)
                if (inner.length > 0) page.attachments = inner
            }
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
            if (code === 200) {
                var parsed = Util.parse(body)
                var list = Util.attachments(parsed)
                if (parsed && !Array.isArray(parsed))
                    console.log("schoolfox: attachment reply keys", Object.keys(parsed).join(","))
                if (list.length > 0 || page.attachments.length === 0)
                    page.attachments = list
                page.attachState = "done"
            } else {
                page.attachState = code === 404 ? "done" : "error"
                if (code !== 404) console.log("schoolfox: attachment list failed", code)
            }
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
        if (page.previews[name]) {   // already here
            Qt.openUrlExternally("file://" + page.previews[name])
            return
        }
        page.status = qsTr("Downloading %1…").arg(name)
        SchoolFox.downloadAttachment(page.message.id, name, function(ok, result) {
            if (!ok) {
                page.status = result
                return
            }
            page.status = qsTr("Saved to %1").arg(result)
            var p = page.previews
            p[name] = result
            page.previews = p
            page.previewsChanged()
            if (!Util.isImage(name))   // images are shown inline; tap again to open
                Qt.openUrlExternally("file://" + result)
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
                title: page.message.pupil || qsTr("Message")
            }

            // title
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: page.message.title
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamilyHeading
                color: Theme.highlightColor
            }

            // sender + date
            Row {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingMedium
                Rectangle {
                    id: avatar
                    width: Theme.iconSizeMedium
                    height: width
                    radius: width / 2
                    color: Util.childColor(page.message.sender || "?")
                    Label {
                        anchors.centerIn: parent
                        text: Util.initials(page.message.sender || "?")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        font.bold: true
                        color: "white"
                    }
                }
                Column {
                    width: parent.width - avatar.width - parent.spacing
                    anchors.verticalCenter: avatar.verticalCenter
                    Label {
                        width: parent.width
                        text: page.message.sender || qsTr("SchoolFox")
                        truncationMode: TruncationMode.Fade
                        color: Theme.primaryColor
                    }
                    Label {
                        width: parent.width
                        text: page.message.date ? Format.formatDate(page.message.date, Formatter.DateFull) + " · "
                                                  + Format.formatDate(page.message.date, Formatter.TimeValue) : ""
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }
                }
            }

            // event / due date chip
            BackgroundItem {
                width: parent.width
                height: eventRow.height + 2 * Theme.paddingSmall
                visible: page.message.eventDate || page.message.dueDate ? true : false
                enabled: page.icsText !== ""
                onClicked: page.addToCalendar()
                Row {
                    id: eventRow
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.paddingMedium
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-date?" + Theme.highlightColor
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            text: page.message.eventDate
                                  ? qsTr("Event: %1").arg(Format.formatDate(page.message.eventDate, Formatter.DateFull)
                                                          + " " + Format.formatDate(page.message.eventDate, Formatter.TimeValue))
                                  : page.message.dueDate
                                    ? qsTr("Due: %1").arg(Format.formatDate(page.message.dueDate, Formatter.DateFull)) : ""
                            color: Theme.highlightColor
                        }
                        Label {
                            text: qsTr("Tap to add to calendar")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryHighlightColor
                        }
                    }
                }
            }

            Separator {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                color: Theme.secondaryHighlightColor
                horizontalAlignment: Qt.AlignHCenter
            }

            // content
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                readonly property bool html: Util.isHtml(page.message.html)
                text: html ? page.message.html : page.message.body
                textFormat: html ? Text.StyledText : Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.primaryColor
                linkColor: Theme.highlightColor
                lineHeight: 1.15
                horizontalAlignment: Text.AlignJustify
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
                visible: page.attachments.length > 0 || page.attachState !== "done"
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.attachState !== "done" && !SchoolFox.demo
                text: page.attachState === "loading" ? qsTr("Loading attachments…")
                                                     : qsTr("Attachments could not be loaded")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
            }
            Repeater {
                model: page.attachments
                Column {
                    width: column.width
                    readonly property string localPath: page.previews[modelData.name] || ""

                    BackgroundItem {
                        width: parent.width
                        height: Theme.itemSizeSmall
                        onClicked: page.download(modelData.name)
                        Rectangle {   // card
                            anchors { fill: parent; leftMargin: Theme.horizontalPageMargin / 2
                                      rightMargin: Theme.horizontalPageMargin / 2; topMargin: Theme.paddingSmall / 2
                                      bottomMargin: Theme.paddingSmall / 2 }
                            radius: Theme.paddingSmall
                            color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                        }
                        Image {
                            id: fileIcon
                            x: Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            source: Util.fileIcon(modelData.name)
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

                    // inline preview of downloaded pictures; tap to open in Gallery
                    Image {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        visible: localPath !== "" && Util.isImage(modelData.name)
                        source: visible ? "file://" + localPath : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize.width: width
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Qt.openUrlExternally("file://" + localPath)
                        }
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
