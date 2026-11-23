import QtQuick 2.2
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    // Unread filter (remembered). A message opened from the filtered list
    // stays visible until the next refresh, so the list does not jump.
    property var keepVisible: ({})
    readonly property var shown: SchoolFox.unreadOnly
        ? SchoolFox.messages.filter(function(m) { return !m.read || page.keepVisible[m.id] })
        : SchoolFox.messages

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
            title: "SchoolFox"
            description: (SchoolFox.unreadOnly ? qsTr("Unread only") + " · " : "")
                         + (SchoolFox.unreadCount > 0 ? qsTr("%n unread", "", SchoolFox.unreadCount) : "")
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

        delegate: ListItem {
            id: item
            contentHeight: col.height + 2 * Theme.paddingMedium
            property var msg: modelData

            Column {
                id: col
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width - (clip.visible ? clip.width + Theme.paddingSmall : 0)
                    text: msg.title
                    truncationMode: TruncationMode.Fade

                    Image {
                        id: clip
                        anchors { left: parent.right; leftMargin: Theme.paddingSmall
                                  verticalCenter: parent.verticalCenter }
                        visible: msg.attachments > 0
                        source: "image://theme/icon-s-attach?" + (item.highlighted ? Theme.highlightColor : Theme.primaryColor)
                    }
                    font.bold: !msg.read
                    color: item.highlighted || !msg.read ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    text: [msg.sender, msg.pupil, Format.formatDate(msg.date, Formatter.TimepointRelative)]
                          .filter(function(x) { return x }).join(" · ")
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

        ViewPlaceholder {
            enabled: listView.count === 0 && !SchoolFox.busy
            text: SchoolFox.error !== "" ? SchoolFox.error
                  : SchoolFox.unreadOnly && SchoolFox.messages.length > 0 ? qsTr("No unread messages")
                  : qsTr("No messages")
            hintText: qsTr("Pull down to refresh")
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: SchoolFox.busy && listView.count === 0
        }

        VerticalScrollDecorator {}
    }
}
