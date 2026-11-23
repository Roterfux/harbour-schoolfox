import QtQuick 2.2
import Sailfish.Silica 1.0
import "../util.js" as Util

// Report a pupil absence (all-day). Same steps as the SchoolFox parent web form:
// HasAbsence check -> POST tables/Messages (Absence) -> POST .../TeacherRecipients.
Page {
    id: page
    allowedOrientations: Orientation.All

    readonly property var reasons: [
        { code: "ABSENCE_ILLNESS", label: qsTr("Illness") },
        { code: "ABSENCE_DOCTOR", label: qsTr("Doctor's appointment") },
        { code: "ABSENCE_PRIVATE_APPOINTMENT", label: qsTr("Private appointment") },
        { code: "ABSENCE_FAMILY_REASONS", label: qsTr("Family reasons") },
        { code: "ABSENCE_OTHER", label: qsTr("Other") }
    ]
    readonly property var pupil: SchoolFox.pupils.length > 0 ? SchoolFox.pupils[pupilBox.currentIndex] : null
    property date startDay: new Date()
    property date endDay: new Date()
    property var teachers: []
    property var selected: ({})
    property bool working: false
    property string status: ""
    property bool done: false

    function loadTeachers() {
        page.teachers = []
        page.selected = {}
        if (!page.pupil) return
        SchoolFox.api("GET", "api/SchoolClasses/" + page.pupil.classId + "/Teachers", null, function(code, body) {
            var rows = code === 200 ? Util.parse(body) : null
            var seen = {}, list = [], sel = {}
            ;(Array.isArray(rows) ? rows : []).forEach(function(r) {
                if (!r.teacherId || r.deleted === true || r.isActive === false || seen[r.teacherId]) return
                seen[r.teacherId] = true
                list.push({ id: r.teacherId, name: [r.firstName, r.lastName].filter(function(x) { return x }).join(" ") || r.teacherId })
                sel[r.teacherId] = true
            })
            page.teachers = list
            page.selected = sel
        })
    }

    onPupilChanged: loadTeachers()
    Component.onCompleted: loadTeachers()

    function fail(text) {
        page.working = false
        page.status = text
    }

    function submit() {
        var p = page.pupil
        var s = new Date(startDay.getFullYear(), startDay.getMonth(), startDay.getDate(), 0, 0, 0)
        var e = new Date(endDay.getFullYear(), endDay.getMonth(), endDay.getDate(), 23, 59, 59)
        if (e < s) { fail(qsTr("The end date is before the start date")); return }
        var ids = page.teachers.filter(function(t) { return page.selected[t.id] }).map(function(t) { return t.id })
        page.working = true
        page.status = qsTr("Checking…")
        var startIso = s.toISOString(), endIso = e.toISOString()
        SchoolFox.api("GET", "api/Messages/HasAbsence?pupilId=" + encodeURIComponent(p.pupilId)
                      + "&startDate=" + encodeURIComponent(startIso) + "&endDate=" + encodeURIComponent(endIso),
                      null, function(code, body) {
            if (code !== 200) { fail(qsTr("Check failed (%1)").arg(code)); return }
            if (Util.parse(body) === true) { fail(qsTr("An absence already exists for these days")); return }
            page.status = qsTr("Sending…")
            SchoolFox.api("POST", "tables/Messages", {
                startDate: startIso,
                endDate: endIso,
                content: page.reasons[reasonBox.currentIndex].code,
                allDayEvent: true,
                messageType: "Absence",
                topic: "Absence",
                instantMessagesAllowed: true,
                schoolId: p.schoolId,
                schoolClassId: p.classId,
                applicationVersion: "10.10.0",
                recipientsType: (page.teachers.length === 1 || ids.length === page.teachers.length) ? "All" : "NotAll"
            }, function(code2, body2) {
                var saved = Util.parse(body2)
                if (code2 < 200 || code2 >= 300 || !saved || !saved.id) {
                    fail(qsTr("Saving failed (%1). Please check in the SchoolFox app before trying again.").arg(code2))
                    return
                }
                SchoolFox.api("POST", "api/Messages/" + saved.id + "/Pupils/" + p.pupilId
                              + "/TeacherRecipients?sendAbsenceNotifications=true", ids, function(code3) {
                    page.working = false
                    if (code3 >= 200 && code3 < 300) {
                        page.done = true
                        page.status = qsTr("Absence reported")
                        SchoolFox.refresh()
                    } else {
                        page.status = qsTr("Saved, but sending to teachers failed (%1). Please check in the SchoolFox app.").arg(code3)
                    }
                })
            })
        })
    }

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader { title: qsTr("Report absence") }

            ComboBox {
                id: pupilBox
                label: qsTr("Child")
                enabled: !page.working && !page.done
                menu: ContextMenu {
                    Repeater {
                        model: SchoolFox.pupils
                        MenuItem { text: Util.join([modelData.name, modelData.className]) }
                    }
                }
            }

            ComboBox {
                id: reasonBox
                label: qsTr("Reason")
                enabled: !page.working && !page.done
                menu: ContextMenu {
                    Repeater {
                        model: page.reasons
                        MenuItem { text: modelData.label }
                    }
                }
            }

            ValueButton {
                label: qsTr("From")
                value: Format.formatDate(page.startDay, Formatter.DateFull)
                enabled: !page.working && !page.done
                onClicked: {
                    var d = pageStack.push("Sailfish.Silica.DatePickerDialog", { date: page.startDay })
                    d.accepted.connect(function() {
                        page.startDay = d.date
                        if (page.endDay < page.startDay) page.endDay = d.date
                    })
                }
            }

            ValueButton {
                label: qsTr("Until")
                value: Format.formatDate(page.endDay, Formatter.DateFull)
                enabled: !page.working && !page.done
                onClicked: {
                    var d = pageStack.push("Sailfish.Silica.DatePickerDialog", { date: page.endDay })
                    d.accepted.connect(function() { page.endDay = d.date })
                }
            }

            SectionHeader { text: qsTr("Inform teachers") }

            Repeater {
                model: page.teachers
                TextSwitch {
                    text: modelData.name
                    checked: page.selected[modelData.id] === true
                    enabled: !page.working && !page.done
                    onClicked: {
                        var s = page.selected
                        s[modelData.id] = checked
                        page.selected = s
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.pupil !== null && ["PlusDemo", "Plus", "Max"].indexOf(page.pupil.plan) < 0
                text: qsTr("Your school's SchoolFox plan may not include absence reports.")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
            }

            Item { width: 1; height: Theme.paddingLarge }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Send absence report")
                enabled: page.pupil !== null && !page.working && !page.done
                onClicked: remorse.execute(qsTr("Sending absence report"), page.submit)
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.status !== ""
                text: page.status
                wrapMode: Text.Wrap
                color: page.done ? Theme.highlightColor : Theme.secondaryHighlightColor
            }
        }
        VerticalScrollDecorator {}
    }
}
