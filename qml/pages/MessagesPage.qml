import QtQuick 2.2
import Sailfish.Silica 1.0
import "../util.js" as Util

Page {
    id: page
    allowedOrientations: Orientation.All

    // Unread filter (remembered). A message opened from the filtered list
    // stays visible until the next refresh, so the list does not jump.
    property var keepVisible: ({})
    readonly property var shown: SchoolFox.unreadOnly
        ? SchoolFox.messages.filter(function(m) { return !m.read || page.keepVisible[m.id] })
        : SchoolFox.messages
    readonly property bool manyChildren: SchoolFox.pupils.length > 1

    function dayLabel(d) {
        if (!d) return ""
        var n = Util.daysAgo(d)
        if (n === 0) return qsTr("Today")
        if (n === 1) return qsTr("Yesterday")
        if (n < 7) return Format.formatDate(d, Formatter.WeekdayNameStandalone)
        return Format.formatDate(d, Formatter.DateLong)
    }

    // Show login on top when not logged in.
    function checkLogin() {
        if (!SchoolFox.loggedIn && status === PageStatus.Active)
            pageStack.animatorPush(Qt.resolvedUrl("LoginPage.qml"))
    }
    onStatusChanged: checkLogin()
    Connections {
        target: SchoolFox
        onLoggedInChanged: page.checkLogin()
        onRefreshFinished: page.keepVisible = {}
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: page.shown

        header: PageHeader {
            title: SchoolFox.unreadOnly ? qsTr("Unread") : qsTr("Messages")
            description: SchoolFox.unreadCount > 0 ? qsTr("%n unread", "", SchoolFox.unreadCount)
                                                   : SchoolFox.loggedIn ? qsTr("All read") : ""
        }

        PullDownMenu {
            busy: SchoolFox.busy
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Report absence")
                visible: SchoolFox.loggedIn && !SchoolFox.demo
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("AbsencePage.qml"))
            }
            MenuItem {
                text: qsTr("Chats")
                visible: SchoolFox.loggedIn && !SchoolFox.demo
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("ChatsPage.qml"))
            }
            MenuItem {
                text: qsTr("Events and due dates")
                visible: SchoolFox.loggedIn && !SchoolFox.demo
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("EventsPage.qml"))
            }
            MenuItem {
                text: SchoolFox.unreadOnly ? qsTr("Show all") : qsTr("Show only unread")
                onClicked: { page.keepVisible = {}; SchoolFox.unreadOnly = !SchoolFox.unreadOnly }
            }
            MenuItem {
                text: qsTr("Refresh")
                enabled: SchoolFox.loggedIn && !SchoolFox.busy
                onClicked: SchoolFox.refresh()
            }
        }

        delegate: Column {
            id: entry
            width: listView.width
            readonly property var msg: modelData
            readonly property bool newDay: index === 0
                || Util.dayKey(page.shown[index - 1].date) !== Util.dayKey(msg.date)

            SectionHeader {
                visible: entry.newDay && text !== ""
                text: page.dayLabel(msg.date)
            }

            ListItem {
                id: item
                contentHeight: Math.max(col.height, badge.height) + 2 * Theme.paddingMedium

                // unread marker
                Rectangle {
                    visible: !msg.read
                    width: Theme.paddingSmall
                    height: col.height
                    radius: width / 2
                    x: Theme.horizontalPageMargin / 2 - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.highlightColor
                }

                // child badge (only with several children)
                Rectangle {
                    id: badge
                    visible: page.manyChildren && (msg.pupil || "") !== ""
                    width: visible ? Theme.iconSizeMedium : 0
                    height: Theme.iconSizeMedium
                    radius: width / 2
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    color: Util.childColor(msg.pupil)
                    opacity: msg.read ? 0.6 : 1
                    Label {
                        anchors.centerIn: parent
                        text: Util.initials(msg.pupil)
                        font.pixelSize: Theme.fontSizeExtraSmall
                        font.bold: true
                        color: "white"
                    }
                }

                Column {
                    id: col
                    anchors {
                        left: badge.visible ? badge.right : parent.left
                        leftMargin: badge.visible ? Theme.paddingMedium : Theme.horizontalPageMargin
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.paddingSmall / 2

                    Item {
                        width: parent.width
                        height: titleLabel.height
                        Label {
                            id: titleLabel
                            width: parent.width - timeLabel.width - (clipIcon.visible ? clipIcon.width : 0) - Theme.paddingMedium
                            text: msg.title
                            truncationMode: TruncationMode.Fade
                            font.bold: !msg.read
                            color: item.highlighted || !msg.read ? Theme.highlightColor : Theme.primaryColor
                        }
                        Image {
                            id: clipIcon
                            anchors { right: timeLabel.left; rightMargin: Theme.paddingSmall
                                      verticalCenter: titleLabel.verticalCenter }
                            visible: msg.attachments > 0
                            source: "image://theme/icon-s-attach?" + (item.highlighted ? Theme.highlightColor
                                                                                        : Theme.secondaryColor)
                        }
                        Label {
                            id: timeLabel
                            anchors { right: parent.right; baseline: titleLabel.baseline }
                            text: msg.date ? (Util.daysAgo(msg.date) < 1
                                              ? Format.formatDate(msg.date, Formatter.TimeValue)
                                              : Format.formatDate(msg.date, Formatter.DateMediumWithoutYear))
                                           : ""
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        }
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: Util.join([msg.sender, page.manyChildren ? "" : msg.pupil])
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: (msg.body || "").trim().replace(/\s+/g, " ")
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignJustify
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall
                        color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    }
                }

                onClicked: {
                    var k = page.keepVisible
                    k[msg.id] = true
                    page.keepVisible = k
                    SchoolFox.markRead(msg.id)
                    pageStack.animatorPush(Qt.resolvedUrl("MessagePage.qml"), { message: msg })
                }
            }
        }

        ViewPlaceholder {
            enabled: listView.count === 0 && !SchoolFox.busy
            text: SchoolFox.error !== "" ? SchoolFox.error
                  : SchoolFox.unreadOnly && SchoolFox.messages.length > 0 ? qsTr("No unread messages")
                  : qsTr("No messages")
            hintText: SchoolFox.unreadOnly && SchoolFox.messages.length > 0
                      ? qsTr("Pull down to show all") : qsTr("Pull down to refresh")
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: SchoolFox.busy && listView.count === 0
        }

        VerticalScrollDecorator {}
    }
}
