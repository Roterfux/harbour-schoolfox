.pragma library

// OData path for the SchoolFox tables API.
function odata(table, filter, orderby, top, skip) {
    var q = "$filter=" + encodeURIComponent(filter)
          + "&$top=" + (top || 50) + "&$skip=" + (skip || 0) + "&$inlinecount=allpages"
    if (orderby)
        q += "&$orderby=" + encodeURIComponent(orderby)
    return table + "?" + q
}

// Quoted OData id; drops anything that is not an id character.
function q(id) {
    return "'" + String(id).replace(/[^A-Za-z0-9_-]/g, "") + "'"
}

function parse(body) {
    try { return JSON.parse(body) } catch (e) { return null }
}

function results(obj) {
    if (!obj) return []
    if (Array.isArray(obj)) return obj
    return obj.results || []
}

function first(row, keys) {
    for (var i = 0; i < keys.length; ++i) {
        var v = row[keys[i]]
        if (v !== undefined && v !== null && String(v).trim() !== "")
            return String(v).trim()
    }
    return ""
}

function date(s) {
    if (!s) return null
    var d = new Date(s)
    return isNaN(d.getTime()) ? null : d
}

function plain(html) {
    if (!html) return ""
    return String(html).replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>/gi, "\n")
        .replace(/<[^>]+>/g, "").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").trim()
}

function isHtml(s) {
    return /<[a-zA-Z][^>]*>/.test(s || "")
}

// Message object as used by MessagePage, from a raw tables/Messages row.
function message(row, pupil) {
    var html = first(row, ["content", "Content", "text"])
    var body = plain(html)
    return {
        id: row.id,
        title: first(row, ["topic", "Topic", "title"]) || body.split("\n")[0].substring(0, 80),
        body: body,
        html: html,
        sender: first(row, ["creatorFullName", "CreatorFullName", "creatorName", "teacherFullName"]),
        pupil: pupil ? pupil.name : "",
        pupilId: row.pupilId || (pupil ? pupil.pupilId : ""),
        classId: pupil ? pupil.classId : row.schoolClassId,
        schoolId: pupil ? pupil.schoolId : row.schoolId,
        type: row.messageType || "",
        date: date(row.createdAt) || date(row.updatedAt),
        eventDate: date(row.eventDate),
        endDate: date(row.endDate),
        dueDate: date(row.dueDate),
        read: !!row.isRead
    }
}

function pad(n) { return (n < 10 ? "0" : "") + n }

function icsUtc(d) {
    return d.getUTCFullYear() + pad(d.getUTCMonth() + 1) + pad(d.getUTCDate()) + "T"
         + pad(d.getUTCHours()) + pad(d.getUTCMinutes()) + pad(d.getUTCSeconds()) + "Z"
}

function icsDay(d) {
    return d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate())
}

function icsText(s) {
    return String(s || "").replace(/\\/g, "\\\\").replace(/;/g, "\;").replace(/,/g, "\\,")
        .replace(/\r?\n/g, "\\n")
}

// iCalendar text for a message with eventDate/endDate or dueDate. "" if no date.
function ics(m) {
    var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//harbour-schoolfox//EN", "BEGIN:VEVENT",
                 "UID:" + m.id + "@harbour-schoolfox", "DTSTAMP:" + icsUtc(new Date())]
    if (m.eventDate) {
        var end = m.endDate && m.endDate > m.eventDate ? m.endDate
                                                       : new Date(m.eventDate.getTime() + 3600000)
        lines.push("DTSTART:" + icsUtc(m.eventDate), "DTEND:" + icsUtc(end))
    } else if (m.dueDate) {
        var next = new Date(m.dueDate.getFullYear(), m.dueDate.getMonth(), m.dueDate.getDate() + 1)
        lines.push("DTSTART;VALUE=DATE:" + icsDay(m.dueDate), "DTEND;VALUE=DATE:" + icsDay(next))
    } else {
        return ""
    }
    lines.push("SUMMARY:" + icsText(m.title), "DESCRIPTION:" + icsText(m.body),
               "END:VEVENT", "END:VCALENDAR")
    return lines.join("\r\n") + "\r\n"
}

function join(parts) {
    return parts.filter(function(x) { return x }).join(" · ")
}

// Attachment list from any of the shapes seen/guessed for SchoolFox:
// [ {name,size} ], {results:[…]}, {files:[…]}, {attachments:[…]}.
function attachments(obj) {
    if (!obj) return []
    var list = Array.isArray(obj) ? obj : (obj.results || obj.files || obj.attachments || obj.Files || [])
    if (!Array.isArray(list)) return []
    var out = []
    list.forEach(function(a) {
        if (typeof a === "string") { out.push({ name: a, size: 0 }); return }
        var name = first(a, ["name", "fileName", "originalFileName", "FileName", "Name", "title"])
        if (name) out.push({ name: name, size: Number(a.size || a.fileSize || a.length || 0) })
    })
    return out
}

function isImage(name) {
    return /\.(jpe?g|png|gif|webp|bmp)$/i.test(name || "")
}

function fileIcon(name) {
    if (isImage(name)) return "image://theme/icon-m-file-image"
    if (/\.pdf$/i.test(name || "")) return "image://theme/icon-m-file-pdf"
    return "image://theme/icon-m-attach"
}
