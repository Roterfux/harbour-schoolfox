#include "schoolfoxclient.h"

#include <algorithm>

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QRegExp>
#include <QTextDocumentFragment>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

namespace {
const char *DemoToken = "demo";
const QString BaseUrl = QStringLiteral("https://api.schoolfox.com/");
const QByteArray ApiVersion = QByteArrayLiteral("2.0.0");
const int MessagesPerPupil = 30;

// Sailfish OS ships Qt 5.6: no QSet range constructor.
QStringList toList(const QSet<QString> &set) { return set.toList(); }
QSet<QString> toSet(const QStringList &list) { return list.toSet(); }

bool validId(const QString &id)
{
    static const QRegExp re(QStringLiteral("^[A-Za-z0-9_-]{1,128}$"));
    return re.exactMatch(id);
}

QString firstString(const QVariantMap &row, const QStringList &keys)
{
    for (const QString &k : keys) {
        const QString v = row.value(k).toString().trimmed();
        if (!v.isEmpty())
            return v;
    }
    return QString();
}

QDateTime parseDate(const QString &s)
{
    if (s.isEmpty())
        return QDateTime();
    // "2026-10-13T08:15:30.123Z" -> drop fraction/zone, treat as UTC.
    QDateTime dt = QDateTime::fromString(s.left(19), QStringLiteral("yyyy-MM-ddTHH:mm:ss"));
    dt.setTimeSpec(Qt::UTC);
    return dt.toLocalTime();
}

QString toPlain(const QString &content)
{
    if (!content.contains(QLatin1Char('<')) && !content.contains(QLatin1Char('&')))
        return content.trimmed();
    return QTextDocumentFragment::fromHtml(content).toPlainText().trimmed();
}
}

SchoolFoxClient::SchoolFoxClient(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    // NOTE: token is stored in plain QSettings (~/.config/org.roterfux/harbour-schoolfox).
    // The password is never stored.
    m_token = m_settings.value(QStringLiteral("auth/token")).toString();
    m_username = m_settings.value(QStringLiteral("auth/username")).toString();
    m_pollMinutes = m_settings.value(QStringLiteral("poll/minutes"), 15).toInt();
    m_seenIds = toSet(m_settings.value(QStringLiteral("state/seen")).toStringList());
    m_readIds = toSet(m_settings.value(QStringLiteral("state/read")).toStringList());
}

int SchoolFoxClient::unreadCount() const
{
    int n = 0;
    for (const QVariant &v : m_messages)
        if (!v.toMap().value(QStringLiteral("read")).toBool())
            ++n;
    return n;
}

void SchoolFoxClient::setPollMinutes(int minutes)
{
    if (minutes == m_pollMinutes)
        return;
    m_pollMinutes = minutes;
    m_settings.setValue(QStringLiteral("poll/minutes"), minutes);
    emit pollMinutesChanged();
}

// ---------------------------------------------------------------------------
// HTTP
// ---------------------------------------------------------------------------

QNetworkReply *SchoolFoxClient::send(const QByteArray &method, const QString &path,
                                     const QByteArray &body, const QString &token)
{
    QNetworkRequest req(QUrl(BaseUrl + path));
    req.setRawHeader("ZUMO-API-VERSION", ApiVersion);
    req.setRawHeader("Accept", "application/json");
    if (!token.isEmpty())
        req.setRawHeader("X-ZUMO-AUTH", token.toUtf8());
    if (!body.isEmpty())
        req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    // Qt 5.6: no sendCustomRequest(QByteArray) overload.
    if (method == "POST")
        return m_nam->post(req, body);
    return m_nam->get(req);
}

void SchoolFoxClient::call(const QByteArray &method, const QString &path, const QByteArray &body,
                           const QString &token, Handler handler)
{
    QNetworkReply *reply = send(method, path, body, token);
    connect(reply, &QNetworkReply::finished, this, [reply, handler]() {
        reply->deleteLater();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray data = reply->readAll();
        handler(status, data, reply->error(), reply->errorString());
    });
}

// Authenticated GET. On 401 tries one token renewal, then retries once.
void SchoolFoxClient::apiGet(const QString &path, Handler handler, bool allowRenew)
{
    const QString sentToken = m_token;
    call("GET", path, QByteArray(), sentToken,
         [this, path, handler, allowRenew, sentToken](int status, const QByteArray &data,
                                                      QNetworkReply::NetworkError err,
                                                      const QString &errString) {
        if (status != 401 || !allowRenew) {
            handler(status, data, err, errString);
            return;
        }
        qDebug() << "schoolfox: 401, renewing token";
        call("GET", QStringLiteral("api/Users/login/token"), QByteArray(), sentToken,
             [this, path, handler, status, data, err, errString](int rs, const QByteArray &rdata,
                                                                 QNetworkReply::NetworkError,
                                                                 const QString &) {
            if (rs == 200 && acceptLogin(rdata, true))
                apiGet(path, handler, false);
            else
                handler(status, data, err, errString);
        });
    });
}

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

void SchoolFoxClient::login(const QString &username, const QString &password)
{
    setError(QString());
    setPendingToken(QString());
    m_username = username.trimmed();
    m_settings.setValue(QStringLiteral("auth/username"), m_username);

    if (m_username == QLatin1String("demo")) {
        setToken(QString::fromLatin1(DemoToken));
        refresh();
        return;
    }

    setBusy(true);
    QJsonObject body {
        { QStringLiteral("username"), m_username },
        { QStringLiteral("password"), password },
        { QStringLiteral("applicationType"), QStringLiteral("SchoolFox") },
    };
    call("POST", QStringLiteral("api/Users/login"),
         QJsonDocument(body).toJson(QJsonDocument::Compact), QString(),
         [this](int status, const QByteArray &data, QNetworkReply::NetworkError err,
                const QString &errString) {
        setBusy(false);
        if (status == 400 || status == 401 || status == 403) {
            setError(tr("Wrong email or password"));
            return;
        }
        if (err != QNetworkReply::NoError) {
            qWarning() << "schoolfox: login failed" << status << errString;
            setError(tr("Login failed: %1").arg(errString));
            return;
        }
        if (acceptLogin(data, false))
            refresh();
    });
}

void SchoolFoxClient::submitTwoFactorCode(const QString &code)
{
    if (m_pendingToken.isEmpty())
        return;
    setError(QString());
    setBusy(true);
    QJsonObject body { { QStringLiteral("password"), code.trimmed() } };
    call("POST", QStringLiteral("api/2fa/login"),
         QJsonDocument(body).toJson(QJsonDocument::Compact), m_pendingToken,
         [this](int status, const QByteArray &data, QNetworkReply::NetworkError err,
                const QString &errString) {
        setBusy(false);
        if (status == 400 || status == 401) {
            setError(tr("Wrong code"));
            return;
        }
        if (err != QNetworkReply::NoError) {
            setError(tr("Login failed: %1").arg(errString));
            return;
        }
        if (acceptLogin(data, true))
            refresh();
    });
}

// Response: {token, user:{id, twoFactorAuthActive, twoFactorAuthStatus, ...}}
bool SchoolFoxClient::acceptLogin(const QByteArray &data, bool afterTwoFactor)
{
    const QJsonObject obj = QJsonDocument::fromJson(data).object();
    const QString token = obj.value(QStringLiteral("token")).toString();
    const QJsonObject user = obj.value(QStringLiteral("user")).toObject();
    if (token.isEmpty()) {
        qWarning() << "schoolfox: login reply without token, keys:" << obj.keys();
        setError(tr("Login failed: unexpected server reply"));
        return false;
    }
    if (!afterTwoFactor) {
        if (user.value(QStringLiteral("twoFactorAuthActive")).toBool()) {
            setPendingToken(token);
            return false;
        }
        if (user.value(QStringLiteral("twoFactorAuthStatus")).toString() == QLatin1String("Required")) {
            setError(tr("Your school requires two-factor login. Set it up in the SchoolFox web app first."));
            return false;
        }
    }
    setPendingToken(QString());
    setToken(token);
    return true;
}

void SchoolFoxClient::logout()
{
    setPendingToken(QString());
    setToken(QString());
    m_messages.clear();
    m_seenIds.clear();
    m_readIds.clear();
    m_settings.remove(QStringLiteral("state"));
    emit messagesChanged();
}

// ---------------------------------------------------------------------------
// Refresh: inventory -> messages per pupil
// ---------------------------------------------------------------------------

void SchoolFoxClient::refresh()
{
    if (!loggedIn() || m_busy) {
        emit refreshFinished();
        return;
    }
    setError(QString());
    if (m_token == QLatin1String(DemoToken)) {
        demoFetchMessages();
        return;
    }
    setBusy(true);
    fetchInventory();
}

void SchoolFoxClient::fetchInventory()
{
    apiGet(QStringLiteral("api/Common/Inventory"),
           [this](int status, const QByteArray &data, QNetworkReply::NetworkError err,
                  const QString &errString) {
        if (status == 401) {
            setToken(QString());
            setError(tr("Session expired, please log in again"));
            finishRefresh(false);
            return;
        }
        if (err != QNetworkReply::NoError) {
            qWarning() << "schoolfox: inventory failed" << status << errString;
            setError(tr("Refresh failed: %1").arg(errString));
            finishRefresh(false);
            return;
        }
        m_pupils.clear();
        const QJsonArray arr = QJsonDocument::fromJson(data).array();
        for (const QJsonValue &v : arr) {
            const QVariantMap row = v.toObject().toVariantMap();
            if (row.value(QStringLiteral("itemType")).toString() != QLatin1String("Pupil"))
                continue;
            const QString pupilId = row.value(QStringLiteral("id")).toString();
            const QString classId = row.value(QStringLiteral("schoolClassId")).toString();
            if (!validId(pupilId) || !validId(classId))
                continue;
            QVariantMap p;
            p.insert(QStringLiteral("pupilId"), pupilId);
            p.insert(QStringLiteral("classId"), classId);
            p.insert(QStringLiteral("name"), row.value(QStringLiteral("name")).toString());
            m_pupils.append(p);
        }
        qDebug() << "schoolfox: inventory items" << arr.size() << "pupils" << m_pupils.size();
        if (m_pupils.isEmpty()) {
            setError(tr("No child found in this SchoolFox account"));
            handleMessages(QVariantList());
            finishRefresh(true);
            return;
        }
        m_collected.clear();
        fetchPupilMessages(0);
    });
}

void SchoolFoxClient::fetchPupilMessages(int index)
{
    if (index >= m_pupils.size()) {
        // newest first
        std::sort(m_collected.begin(), m_collected.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value(QStringLiteral("date")).toDateTime()
                 > b.toMap().value(QStringLiteral("date")).toDateTime();
        });
        handleMessages(m_collected);
        finishRefresh(true);
        return;
    }
    const QVariantMap p = m_pupils.at(index).toMap();
    const QString pupilName = p.value(QStringLiteral("name")).toString();
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("$filter"),
                   QStringLiteral("Deleted eq false and SchoolClassId eq '%1' and PupilId eq '%2'")
                       .arg(p.value(QStringLiteral("classId")).toString(),
                            p.value(QStringLiteral("pupilId")).toString()));
    q.addQueryItem(QStringLiteral("$orderby"), QStringLiteral("UpdatedAt desc"));
    q.addQueryItem(QStringLiteral("$top"), QString::number(MessagesPerPupil));
    q.addQueryItem(QStringLiteral("$skip"), QStringLiteral("0"));
    q.addQueryItem(QStringLiteral("$inlinecount"), QStringLiteral("allpages"));
    const QString path = QStringLiteral("tables/Messages?")
                       + q.toString(QUrl::FullyEncoded);

    apiGet(path, [this, index, pupilName](int status, const QByteArray &data,
                                          QNetworkReply::NetworkError err,
                                          const QString &errString) {
        if (status == 401) {
            setToken(QString());
            setError(tr("Session expired, please log in again"));
            finishRefresh(false);
            return;
        }
        if (err != QNetworkReply::NoError) {
            qWarning() << "schoolfox: messages failed" << status << errString;
            setError(tr("Refresh failed: %1").arg(errString));
            finishRefresh(false);
            return;
        }
        // {results:[...], count:n}  (plain array accepted too)
        const QJsonDocument doc = QJsonDocument::fromJson(data);
        const QJsonArray arr = doc.isArray() ? doc.array()
                                             : doc.object().value(QStringLiteral("results")).toArray();
        for (const QJsonValue &v : arr) {
            const QVariantMap m = parseMessage(v.toObject().toVariantMap(), pupilName);
            if (!m.isEmpty())
                m_collected.append(m);
        }
        fetchPupilMessages(index + 1);
    });
}

QVariantMap SchoolFoxClient::parseMessage(const QVariantMap &row, const QString &pupilName) const
{
    const QString id = row.value(QStringLiteral("id")).toString();
    if (id.isEmpty())
        return QVariantMap();
    const QString html = firstString(row, QStringList() << QStringLiteral("content")
                                                        << QStringLiteral("Content")
                                                        << QStringLiteral("text"));
    QString title = firstString(row, QStringList() << QStringLiteral("topic")
                                                   << QStringLiteral("Topic")
                                                   << QStringLiteral("title"));
    const QString body = toPlain(html);
    if (title.isEmpty())
        title = body.section(QLatin1Char('\n'), 0, 0).left(80);
    QDateTime date = parseDate(row.value(QStringLiteral("createdAt")).toString());
    if (!date.isValid())
        date = parseDate(row.value(QStringLiteral("updatedAt")).toString());

    QVariantMap m;
    m.insert(QStringLiteral("id"), id);
    m.insert(QStringLiteral("title"), title);
    m.insert(QStringLiteral("body"), body);
    m.insert(QStringLiteral("html"), html);
    m.insert(QStringLiteral("sender"), firstString(row, QStringList()
                                                   << QStringLiteral("creatorFullName")
                                                   << QStringLiteral("CreatorFullName")
                                                   << QStringLiteral("creatorName")
                                                   << QStringLiteral("teacherFullName")));
    m.insert(QStringLiteral("pupil"), pupilName);
    m.insert(QStringLiteral("type"), row.value(QStringLiteral("messageType")).toString());
    m.insert(QStringLiteral("date"), date);
    m.insert(QStringLiteral("serverRead"), row.value(QStringLiteral("isRead")).toBool());
    return m;
}

void SchoolFoxClient::finishRefresh(bool ok)
{
    Q_UNUSED(ok)
    setBusy(false);
    emit refreshFinished();
}

void SchoolFoxClient::markRead(const QString &id)
{
    // Local only: the web client does not mark read on GET either.
    m_readIds.insert(id);
    m_settings.setValue(QStringLiteral("state/read"), toList(m_readIds));
    for (QVariant &v : m_messages) {
        QVariantMap m = v.toMap();
        if (m.value(QStringLiteral("id")).toString() == id) {
            m.insert(QStringLiteral("read"), true);
            v = m;
        }
    }
    emit messagesChanged();
}

// ---------------------------------------------------------------------------
// Demo mode: fake data, a new message every second refresh
// ---------------------------------------------------------------------------

void SchoolFoxClient::demoFetchMessages()
{
    ++m_demoCounter;
    const int count = 2 + m_demoCounter / 2;
    QVariantList list;
    const QDateTime now = QDateTime::currentDateTime();
    for (int i = count; i >= 1; --i) {
        QVariantMap m;
        const QString body = QStringLiteral("Dear parents,\n\nthis is fake message number %1.").arg(i);
        m.insert(QStringLiteral("id"), QStringLiteral("demo-%1").arg(i));
        m.insert(QStringLiteral("title"), QStringLiteral("Demo message %1").arg(i));
        m.insert(QStringLiteral("body"), body);
        m.insert(QStringLiteral("html"), body);
        m.insert(QStringLiteral("sender"), i % 2 ? QStringLiteral("Class teacher")
                                                 : QStringLiteral("School office"));
        m.insert(QStringLiteral("pupil"), QStringLiteral("Demo child"));
        m.insert(QStringLiteral("date"), now.addSecs(-3600 * (count - i)));
        list.append(m);
    }
    handleMessages(list);
    emit refreshFinished();
}

// ---------------------------------------------------------------------------

void SchoolFoxClient::handleMessages(const QVariantList &fresh)
{
    const bool firstSync = !m_settings.value(QStringLiteral("state/synced")).toBool();
    QVariantList newOnes;
    m_messages.clear();
    for (const QVariant &v : fresh) {
        QVariantMap m = v.toMap();
        const QString id = m.value(QStringLiteral("id")).toString();
        m.insert(QStringLiteral("read"), m.value(QStringLiteral("serverRead")).toBool()
                                         || m_readIds.contains(id));
        if (!m_seenIds.contains(id)) {
            m_seenIds.insert(id);
            if (!m.value(QStringLiteral("read")).toBool())
                newOnes.append(m);
        }
        m_messages.append(m);
    }
    m_settings.setValue(QStringLiteral("state/seen"), toList(m_seenIds));
    m_settings.setValue(QStringLiteral("state/synced"), true);
    emit messagesChanged();
    // Don't spam notifications for the whole backlog on first login.
    if (!firstSync && !newOnes.isEmpty())
        emit newMessages(newOnes);
}

void SchoolFoxClient::setBusy(bool busy)
{
    if (busy == m_busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void SchoolFoxClient::setError(const QString &error)
{
    if (error == m_error)
        return;
    m_error = error;
    emit errorChanged();
}

void SchoolFoxClient::setToken(const QString &token)
{
    if (token == m_token)
        return;
    m_token = token;
    if (token.isEmpty())
        m_settings.remove(QStringLiteral("auth/token"));
    else
        m_settings.setValue(QStringLiteral("auth/token"), token);
    emit loggedInChanged();
}

void SchoolFoxClient::setPendingToken(const QString &token)
{
    if (token == m_pendingToken)
        return;
    m_pendingToken = token;
    emit twoFactorRequiredChanged();
}
