#include "schoolfoxclient.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QDebug>

namespace {
const char *DemoToken = "demo";

// ---------------------------------------------------------------------------
// API placeholders. Fill these in from the requests captured in the
// SchoolFox web app (browser DevTools -> Network). Everything below is a GUESS.
// ---------------------------------------------------------------------------
const QString BaseUrl = QStringLiteral("https://api.schoolfox.app");          // TODO
const QString LoginPath = QStringLiteral("/api/v1/auth/login");                // TODO
const QString MessagesPath = QStringLiteral("/api/v1/messages");               // TODO
const QByteArray UserAgent = QByteArrayLiteral("harbour-schoolfox/0.1 (Sailfish OS)");

// Sailfish OS ships Qt 5.6: no QSet range constructor.
QStringList toList(const QSet<QString> &set) { return set.toList(); }
QSet<QString> toSet(const QStringList &list) { return list.toSet(); }
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

void SchoolFoxClient::login(const QString &username, const QString &password)
{
    setError(QString());
    m_username = username.trimmed();
    m_settings.setValue(QStringLiteral("auth/username"), m_username);

    if (m_username == QLatin1String("demo")) {
        setToken(QString::fromLatin1(DemoToken));
        refresh();
        return;
    }
    apiLogin(m_username, password);
}

void SchoolFoxClient::logout()
{
    setToken(QString());
    m_messages.clear();
    m_seenIds.clear();
    m_readIds.clear();
    m_settings.remove(QStringLiteral("state"));
    emit messagesChanged();
}

void SchoolFoxClient::refresh()
{
    if (!loggedIn() || m_busy) {
        emit refreshFinished();
        return;
    }
    setError(QString());
    if (m_token == QLatin1String(DemoToken))
        demoFetchMessages();
    else
        apiFetchMessages();
}

void SchoolFoxClient::markRead(const QString &id)
{
    // Local only. TODO: tell server if SchoolFox has a "mark read" endpoint.
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
// API
// ---------------------------------------------------------------------------

void SchoolFoxClient::apiLogin(const QString &username, const QString &password)
{
    setBusy(true);
    QNetworkRequest req(QUrl(BaseUrl + LoginPath));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("User-Agent", UserAgent);

    // TODO: real body shape
    QJsonObject body {
        { QStringLiteral("username"), username },
        { QStringLiteral("password"), password },
    };
    QNetworkReply *reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        setBusy(false);
        const QByteArray data = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "login failed" << reply->error() << data.left(500);
            setError(tr("Login failed: %1").arg(reply->errorString()));
            return;
        }
        // TODO: real token field / maybe cookie instead of token
        const QJsonObject obj = QJsonDocument::fromJson(data).object();
        const QString token = obj.value(QStringLiteral("token")).toString();
        if (token.isEmpty()) {
            qWarning() << "login: no token in reply" << data.left(500);
            setError(tr("Login failed: unexpected server reply"));
            return;
        }
        setToken(token);
        refresh();
    });
}

void SchoolFoxClient::apiFetchMessages()
{
    setBusy(true);
    QNetworkRequest req(QUrl(BaseUrl + MessagesPath));
    req.setRawHeader("User-Agent", UserAgent);
    req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());   // TODO: real auth header

    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        setBusy(false);
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray data = reply->readAll();
        if (status == 401 || status == 403) {
            setToken(QString());
            setError(tr("Session expired, please log in again"));
        } else if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "fetch failed" << reply->error() << data.left(500);
            setError(tr("Refresh failed: %1").arg(reply->errorString()));
        } else {
            handleMessages(parseMessages(data));
        }
        emit refreshFinished();
    });
}

QVariantList SchoolFoxClient::parseMessages(const QByteArray &json) const
{
    // TODO: map real SchoolFox JSON. Guess: array of {id, title, text, sender:{name}, createdAt}
    QVariantList out;
    const QJsonDocument doc = QJsonDocument::fromJson(json);
    const QJsonArray arr = doc.isArray() ? doc.array()
                                         : doc.object().value(QStringLiteral("items")).toArray();
    for (const QJsonValue &v : arr) {
        const QJsonObject o = v.toObject();
        QVariantMap m;
        m.insert(QStringLiteral("id"), o.value(QStringLiteral("id")).toVariant().toString());
        m.insert(QStringLiteral("title"), o.value(QStringLiteral("title")).toString());
        m.insert(QStringLiteral("body"), o.value(QStringLiteral("text")).toString());
        m.insert(QStringLiteral("sender"), o.value(QStringLiteral("sender")).toObject()
                                               .value(QStringLiteral("name")).toString());
        m.insert(QStringLiteral("date"), QDateTime::fromString(
                     o.value(QStringLiteral("createdAt")).toString(), Qt::ISODate));
        out.append(m);
    }
    return out;
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
        m.insert(QStringLiteral("id"), QStringLiteral("demo-%1").arg(i));
        m.insert(QStringLiteral("title"), QStringLiteral("Demo message %1").arg(i));
        m.insert(QStringLiteral("body"),
                 QStringLiteral("Dear parents,\n\nthis is fake message number %1. "
                                "Real data needs the SchoolFox API.").arg(i));
        m.insert(QStringLiteral("sender"), i % 2 ? QStringLiteral("Class teacher")
                                                 : QStringLiteral("School office"));
        m.insert(QStringLiteral("date"), now.addSecs(-3600 * (count - i)));
        list.append(m);
    }
    handleMessages(list);
    emit refreshFinished();
}

// ---------------------------------------------------------------------------

void SchoolFoxClient::handleMessages(const QVariantList &fresh)
{
    const bool firstSync = m_seenIds.isEmpty();
    QVariantList newOnes;
    m_messages.clear();
    for (QVariant v : fresh) {
        QVariantMap m = v.toMap();
        const QString id = m.value(QStringLiteral("id")).toString();
        m.insert(QStringLiteral("read"), m_readIds.contains(id));
        if (!m_seenIds.contains(id)) {
            m_seenIds.insert(id);
            newOnes.append(m);
        }
        m_messages.append(m);
    }
    m_settings.setValue(QStringLiteral("state/seen"), toList(m_seenIds));
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
