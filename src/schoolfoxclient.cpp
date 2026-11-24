#include "schoolfoxclient.h"

#include <algorithm>

#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QRegExp>
#include <QStandardPaths>
#include <QTextDocumentFragment>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

namespace {
const char *DemoToken = "demo";
const QString BaseUrl = QStringLiteral("https://api.schoolfox.com/");
const QByteArray ApiVersion = QByteArrayLiteral("2.0.0");
const int MessagesPerPupil = 30;
const QString FileHost = QStringLiteral("getfile.foxeducation.com");

// Sailfish OS ships Qt 5.6: no QSet range constructor.
QStringList toList(const QSet<QString> &set) { return set.toList(); }
QSet<QString> toSet(const QStringList &list) { return list.toSet(); }

bool validId(const QString &id)
{
    static const QRegExp re(QStringLiteral("^[A-Za-z0-9_-]{1,128}$"));
    return re.exactMatch(id);
}

bool validPath(const QString &path)
{
    static const QRegExp re(QStringLiteral("^(api|tables)/[A-Za-z0-9_/-]+(\\?.*)?$"));
    return re.exactMatch(path) && !path.contains(QStringLiteral(".."));
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
    if (!dt.isValid())
        return QDateTime();
    dt.setTimeSpec(Qt::UTC);
    return dt.toLocalTime();
}

QString toPlain(const QString &content)
{
    if (!content.contains(QLatin1Char('<')) && !content.contains(QLatin1Char('&')))
        return content.trimmed();
    return QTextDocumentFragment::fromHtml(content).toPlainText().trimmed();
}

QString safeFileName(const QString &name)
{
    QString n = QFileInfo(name).fileName();
    n.replace(QRegExp(QStringLiteral("[\\\\/:*?\"<>|\\x0000-\\x001f]")), QStringLiteral("_"));
    n = n.trimmed();
    if (n.isEmpty() || n == QLatin1String(".") || n == QLatin1String(".."))
        n = QStringLiteral("attachment");
    return n.left(200);
}

QString uniquePath(const QString &dir, const QString &name)
{
    QString path = dir + QLatin1Char('/') + name;
    const QFileInfo fi(name);
    for (int i = 2; QFile::exists(path) && i < 1000; ++i) {
        const QString suffix = fi.suffix().isEmpty() ? QString() : QLatin1Char('.') + fi.suffix();
        path = QStringLiteral("%1/%2 (%3)%4").arg(dir, fi.completeBaseName()).arg(i).arg(suffix);
    }
    return path;
}

QString writeFile(const QString &name, const QByteArray &data)
{
    const QString dir = SchoolFoxClient::downloadDir();
    QDir().mkpath(dir);
    const QString path = uniquePath(dir, safeFileName(name));
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly) || f.write(data) != data.size()) {
        qWarning() << "schoolfox: cannot write" << path << f.errorString();
        return QString();
    }
    return path;
}

void invoke(QJSValue callback, const QJSValueList &args)
{
    if (!callback.isCallable())
        return;
    const QJSValue r = callback.call(args);
    if (r.isError())
        qWarning() << "schoolfox: QML callback error:" << r.toString();
}
}

// ---------------------------------------------------------------------------
// Setup / settings
// ---------------------------------------------------------------------------

QString SchoolFoxClient::settingsPath()
{
    // ~/.config/org.roterfux/harbour-schoolfox/ is writable inside Sailjail and
    // the same path for the unsandboxed background service.
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/settings.conf");
}

QString SchoolFoxClient::downloadDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)
         + QStringLiteral("/SchoolFox");
}

SchoolFoxClient::SchoolFoxClient(Mode mode, QObject *parent)
    : QObject(parent)
    , m_mode(mode)
    , m_nam(new QNetworkAccessManager(this))
    , m_settings(settingsPath(), QSettings::IniFormat)
{
    reloadSettings();
    QFile::setPermissions(settingsPath(), QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

void SchoolFoxClient::reloadSettings()
{
    m_settings.sync();
    const QString token = m_settings.value(QStringLiteral("auth/token")).toString();
    if (token != m_token) {
        m_token = token;
        emit loggedInChanged();
    }
    m_username = m_settings.value(QStringLiteral("auth/username")).toString();
    m_password = QString::fromUtf8(QByteArray::fromBase64(
                     m_settings.value(QStringLiteral("auth/password")).toByteArray()));
    const QString uid = m_settings.value(QStringLiteral("auth/userId")).toString();
    const QString fn = m_settings.value(QStringLiteral("auth/fullName")).toString();
    if (uid != m_userId || fn != m_fullName) {
        m_userId = uid;
        m_fullName = fn;
        emit identityChanged();
    }
    m_pollMinutes = m_settings.value(QStringLiteral("poll/minutes"), 15).toInt();
    m_notificationsEnabled = m_settings.value(QStringLiteral("notify/enabled"), true).toBool();
    m_notificationContent = m_settings.value(QStringLiteral("notify/content"), true).toBool();
    m_rememberPassword = m_settings.value(QStringLiteral("auth/remember"), true).toBool();
    m_markReadOnServer = m_settings.value(QStringLiteral("read/server"), false).toBool();
    m_unreadOnly = m_settings.value(QStringLiteral("view/unreadOnly"), false).toBool();
    m_readIds = toSet(m_settings.value(QStringLiteral("state/read")).toStringList());
    emit settingsChanged();
}

void SchoolFoxClient::setSetting(const QString &key, const QVariant &value)
{
    m_settings.setValue(key, value);
    m_settings.sync();
    emit settingsChanged();
}

bool SchoolFoxClient::demo() const { return m_token == QLatin1String(DemoToken); }

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
    setSetting(QStringLiteral("poll/minutes"), minutes);
}

void SchoolFoxClient::setNotificationsEnabled(bool on)
{
    if (on == m_notificationsEnabled)
        return;
    m_notificationsEnabled = on;
    setSetting(QStringLiteral("notify/enabled"), on);
}

void SchoolFoxClient::setNotificationContent(bool on)
{
    if (on == m_notificationContent)
        return;
    m_notificationContent = on;
    setSetting(QStringLiteral("notify/content"), on);
}

void SchoolFoxClient::setRememberPassword(bool on)
{
    if (on == m_rememberPassword)
        return;
    m_rememberPassword = on;
    if (!on) {
        m_password.clear();
        m_settings.remove(QStringLiteral("auth/password"));
    }
    setSetting(QStringLiteral("auth/remember"), on);
}

void SchoolFoxClient::setMarkReadOnServer(bool on)
{
    if (on == m_markReadOnServer)
        return;
    m_markReadOnServer = on;
    setSetting(QStringLiteral("read/server"), on);
}

void SchoolFoxClient::setUnreadOnly(bool on)
{
    if (on == m_unreadOnly)
        return;
    m_unreadOnly = on;
    setSetting(QStringLiteral("view/unreadOnly"), on);
}

QDateTime SchoolFoxClient::lastBackgroundCheck() const
{
    return m_settings.value(QStringLiteral("daemon/lastCheck")).toDateTime();
}

void SchoolFoxClient::recordBackgroundCheck()
{
    setSetting(QStringLiteral("daemon/lastCheck"), QDateTime::currentDateTime());
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
    if (method == "GET")
        return m_nam->get(req);
    if (method == "POST")
        return m_nam->post(req, body);
    if (method == "DELETE")
        return m_nam->deleteResource(req);
    QBuffer *buffer = new QBuffer;
    buffer->setData(body);
    buffer->open(QIODevice::ReadOnly);
    QNetworkReply *reply = m_nam->sendCustomRequest(req, method, buffer);
    buffer->setParent(reply);
    return reply;
}

void SchoolFoxClient::call(const QByteArray &method, const QString &path, const QByteArray &body,
                           const QString &token, Handler handler)
{
    QNetworkReply *reply = send(method, path, body, token);
    connect(reply, &QNetworkReply::finished, this, [reply, handler]() {
        reply->deleteLater();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        handler(status, reply->readAll(), reply->error(), reply->errorString());
    });
}

// Authenticated call. On 401 renews the session (token renewal, then stored
// password) and retries once. 401 means the request was rejected before
// processing, so retrying a write does not duplicate it.
void SchoolFoxClient::authCall(const QByteArray &method, const QString &path, const QByteArray &body,
                               Handler handler, bool allowRecover)
{
    const QString sentToken = m_token;
    call(method, path, body, sentToken,
         [=](int status, const QByteArray &data, QNetworkReply::NetworkError err,
             const QString &errString) {
        if (status != 401 || !allowRecover || sentToken == QLatin1String(DemoToken)) {
            handler(status, data, err, errString);
            return;
        }
        recover(sentToken, [=](bool ok) {
            if (ok) {
                authCall(method, path, body, handler, false);
            } else {
                setToken(QString());
                setError(tr("Session expired, please log in again"));
                handler(status, data, err, errString);
            }
        });
    });
}

void SchoolFoxClient::recover(const QString &failedToken, std::function<void(bool)> done)
{
    m_settings.sync();
    const QString stored = m_settings.value(QStringLiteral("auth/token")).toString();
    if (!stored.isEmpty() && stored != failedToken) {   // the other process renewed already
        m_token = stored;
        done(true);
        return;
    }
    qDebug() << "schoolfox: session rejected, renewing";
    call("GET", QStringLiteral("api/Users/login/token"), QByteArray(), failedToken,
         [=](int status, const QByteArray &data, QNetworkReply::NetworkError, const QString &) {
        if (status == 200 && acceptLogin(data, true)) {
            done(true);
            return;
        }
        if (m_username.isEmpty() || m_password.isEmpty()) {
            done(false);
            return;
        }
        qDebug() << "schoolfox: renewal failed, logging in with stored password";
        QJsonObject body {
            { QStringLiteral("username"), m_username },
            { QStringLiteral("password"), m_password },
            { QStringLiteral("applicationType"), QStringLiteral("SchoolFox") },
        };
        call("POST", QStringLiteral("api/Users/login"),
             QJsonDocument(body).toJson(QJsonDocument::Compact), QString(),
             [=](int ls, const QByteArray &ldata, QNetworkReply::NetworkError, const QString &) {
            done(ls == 200 && acceptLogin(ldata, false) && loggedIn());
        });
    });
}

void SchoolFoxClient::api(const QString &method, const QString &path, const QVariant &body,
                          const QJSValue &callback)
{
    const QByteArray verb = method.toUpper().toLatin1();
    if (!(verb == "GET" || verb == "POST" || verb == "PATCH" || verb == "DELETE") || !validPath(path)) {
        qWarning() << "schoolfox: rejected api call" << method << path;
        invoke(callback, QJSValueList() << 0 << QString());
        return;
    }
    if (demo()) {
        invoke(callback, QJSValueList() << 0 << QString());
        return;
    }
    QByteArray payload;
    if (body.type() == QVariant::Map || body.type() == QVariant::List)
        payload = QJsonDocument::fromVariant(body).toJson(QJsonDocument::Compact);
    authCall(verb, path, payload,
             [this, callback, verb, path](int status, const QByteArray &data,
                                          QNetworkReply::NetworkError, const QString &errString) {
        if (status < 200 || status >= 300)
            qWarning() << "schoolfox:" << verb << path.section(QLatin1Char('?'), 0, 0)
                       << "->" << status << errString;
        invoke(callback, QJSValueList() << status << QString::fromUtf8(data));
    });
}

// ---------------------------------------------------------------------------
// Files
// ---------------------------------------------------------------------------

void SchoolFoxClient::downloadAttachment(const QString &messageId, const QString &fileName,
                                         const QJSValue &callback)
{
    if (!validId(messageId) || fileName.isEmpty()) {
        invoke(callback, QJSValueList() << false << tr("Invalid file"));
        return;
    }
    const QString path = QStringLiteral("api/Files/Messages/") + messageId + QStringLiteral("?fileName=")
                       + QString::fromLatin1(QUrl::toPercentEncoding(fileName));
    QNetworkReply *reply = send("GET", path, QByteArray(), m_token);
    connect(reply, &QNetworkReply::finished, this, [this, reply, fileName, callback]() {
        reply->deleteLater();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 200) {
            const QString saved = writeFile(fileName, reply->readAll());
            invoke(callback, QJSValueList() << !saved.isEmpty()
                                            << (saved.isEmpty() ? tr("Cannot save file") : saved));
            return;
        }
        if (status >= 300 && status < 400) {
            const QUrl target = reply->url().resolved(
                reply->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl());
            // Signed link to the file host: fetch WITHOUT our token.
            if (target.scheme() == QLatin1String("https") && target.host() == FileHost) {
                fetchRedirect(target, fileName, callback);
                return;
            }
            qWarning() << "schoolfox: refused redirect to" << target.host();
        }
        qWarning() << "schoolfox: attachment failed" << status << reply->errorString();
        invoke(callback, QJSValueList() << false << tr("Download failed (%1)").arg(status));
    });
}

void SchoolFoxClient::fetchRedirect(const QUrl &url, const QString &target, const QJSValue &callback)
{
    QNetworkReply *reply = m_nam->get(QNetworkRequest(url));
    connect(reply, &QNetworkReply::finished, this, [reply, target, callback]() {
        reply->deleteLater();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            qWarning() << "schoolfox: file host" << status << reply->errorString();
            invoke(callback, QJSValueList() << false << QObject::tr("Download failed (%1)").arg(status));
            return;
        }
        const QString saved = writeFile(target, reply->readAll());
        invoke(callback, QJSValueList() << !saved.isEmpty()
                                        << (saved.isEmpty() ? QObject::tr("Cannot save file") : saved));
    });
}

QString SchoolFoxClient::saveTextFile(const QString &fileName, const QString &content)
{
    return writeFile(fileName, content.toUtf8());
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

    if (m_rememberPassword) {
        m_password = password;
        m_settings.setValue(QStringLiteral("auth/password"), password.toUtf8().toBase64());
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
            m_password.clear();
            m_settings.remove(QStringLiteral("auth/password"));
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

// Response: {token, user:{id, firstName, lastName, twoFactorAuthActive, twoFactorAuthStatus}}
bool SchoolFoxClient::acceptLogin(const QByteArray &data, bool afterTwoFactor)
{
    const QJsonObject obj = QJsonDocument::fromJson(data).object();
    const QString token = obj.value(QStringLiteral("token")).toString();
    const QVariantMap user = obj.value(QStringLiteral("user")).toObject().toVariantMap();
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
    const QString uid = user.value(QStringLiteral("id")).toString();
    if (!uid.isEmpty()) {
        QString name = (firstString(user, QStringList() << QStringLiteral("firstName")) + QLatin1Char(' ')
                      + firstString(user, QStringList() << QStringLiteral("lastName"))).trimmed();
        if (name.isEmpty())
            name = firstString(user, QStringList() << QStringLiteral("fullUsername"));
        m_userId = uid;
        m_fullName = name;
        m_settings.setValue(QStringLiteral("auth/userId"), uid);
        m_settings.setValue(QStringLiteral("auth/fullName"), name);
        emit identityChanged();
    }
    setPendingToken(QString());
    setToken(token);
    return true;
}

void SchoolFoxClient::logout()
{
    setPendingToken(QString());
    setToken(QString());
    m_password.clear();
    m_userId.clear();
    m_fullName.clear();
    m_messages.clear();
    m_pupils.clear();
    m_readIds.clear();
    m_content.clear();
    m_settings.remove(QStringLiteral("auth/password"));
    m_settings.remove(QStringLiteral("auth/userId"));
    m_settings.remove(QStringLiteral("auth/fullName"));
    m_settings.remove(QStringLiteral("state"));
    m_settings.remove(QStringLiteral("daemon/notified"));
    m_settings.remove(QStringLiteral("daemon/synced"));
    m_settings.sync();
    emit identityChanged();
    emit messagesChanged();
}

// ---------------------------------------------------------------------------
// Refresh: (identity) -> inventory -> messages per pupil -> missing content
// ---------------------------------------------------------------------------

void SchoolFoxClient::refresh()
{
    if (m_busy) {
        emit refreshFinished();
        return;
    }
    reloadSettings();
    if (!loggedIn()) {
        emit refreshFinished();
        return;
    }
    setError(QString());
    if (demo()) {
        demoFetchMessages();
        return;
    }
    setBusy(true);
    if (m_userId.isEmpty()) {
        // Sessions from older versions: fetch identity (needed for confirm/reply).
        call("GET", QStringLiteral("api/Users/login/token"), QByteArray(), m_token,
             [this](int status, const QByteArray &data, QNetworkReply::NetworkError, const QString &) {
            if (status == 200)
                acceptLogin(data, true);
            fetchInventory();
        });
        return;
    }
    fetchInventory();
}

void SchoolFoxClient::fetchInventory()
{
    apiGet(QStringLiteral("api/Common/Inventory"),
           [this](int status, const QByteArray &data, QNetworkReply::NetworkError err,
                  const QString &errString) {
        if (status == 401) {
            finishRefresh();
            return;
        }
        if (err != QNetworkReply::NoError) {
            qWarning() << "schoolfox: inventory failed" << status << errString;
            setError(tr("Refresh failed: %1").arg(errString));
            finishRefresh();
            return;
        }
        const QJsonArray arr = QJsonDocument::fromJson(data).array();
        QHash<QString, QString> plans;   // schoolId -> purchasedFeature
        for (const QJsonValue &v : arr) {
            const QJsonObject o = v.toObject();
            if (o.value(QStringLiteral("itemType")).toString() == QLatin1String("School"))
                plans.insert(o.value(QStringLiteral("id")).toString(),
                             o.value(QStringLiteral("purchasedFeature")).toString());
        }
        m_pupils.clear();
        for (const QJsonValue &v : arr) {
            const QVariantMap row = v.toObject().toVariantMap();
            if (row.value(QStringLiteral("itemType")).toString() != QLatin1String("Pupil"))
                continue;
            if (row.contains(QStringLiteral("isActive")) && !row.value(QStringLiteral("isActive")).toBool())
                continue;
            const QString pupilId = row.value(QStringLiteral("id")).toString();
            const QString classId = row.value(QStringLiteral("schoolClassId")).toString();
            if (!validId(pupilId) || !validId(classId))
                continue;
            const QString schoolId = row.value(QStringLiteral("schoolId")).toString();
            QVariantMap p;
            p.insert(QStringLiteral("pupilId"), pupilId);
            p.insert(QStringLiteral("classId"), classId);
            p.insert(QStringLiteral("schoolId"), schoolId);
            p.insert(QStringLiteral("name"), row.value(QStringLiteral("name")).toString());
            p.insert(QStringLiteral("className"), row.value(QStringLiteral("schoolClassName")).toString());
            p.insert(QStringLiteral("plan"), plans.value(schoolId));
            m_pupils.append(p);
        }
        qDebug() << "schoolfox: inventory items" << arr.size() << "pupils" << m_pupils.size();
        if (m_pupils.isEmpty()) {
            setError(tr("No child found in this SchoolFox account"));
            handleMessages(QVariantList());
            finishRefresh();
            return;
        }
        m_collected.clear();
        fetchPupilMessages(0);
    });
}

void SchoolFoxClient::fetchPupilMessages(int index)
{
    if (index >= m_pupils.size()) {
        std::sort(m_collected.begin(), m_collected.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value(QStringLiteral("date")).toDateTime()
                 > b.toMap().value(QStringLiteral("date")).toDateTime();
        });
        fillContent(0, 15);
        return;
    }
    const QVariantMap p = m_pupils.at(index).toMap();
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("$filter"),
                   QStringLiteral("Deleted eq false and SchoolClassId eq '%1' and PupilId eq '%2'")
                       .arg(p.value(QStringLiteral("classId")).toString(),
                            p.value(QStringLiteral("pupilId")).toString()));
    q.addQueryItem(QStringLiteral("$orderby"), QStringLiteral("UpdatedAt desc"));
    q.addQueryItem(QStringLiteral("$top"), QString::number(MessagesPerPupil));
    q.addQueryItem(QStringLiteral("$skip"), QStringLiteral("0"));
    q.addQueryItem(QStringLiteral("$inlinecount"), QStringLiteral("allpages"));
    const QString path = QStringLiteral("tables/Messages?") + q.toString(QUrl::FullyEncoded);

    apiGet(path, [this, index, p](int status, const QByteArray &data,
                                  QNetworkReply::NetworkError err, const QString &errString) {
        if (status == 401) {
            finishRefresh();
            return;
        }
        if (err != QNetworkReply::NoError) {
            qWarning() << "schoolfox: messages failed" << status << errString;
            setError(tr("Refresh failed: %1").arg(errString));
            finishRefresh();
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(data);
        const QJsonArray arr = doc.isArray() ? doc.array()
                                             : doc.object().value(QStringLiteral("results")).toArray();
        if (!arr.isEmpty())
            qDebug() << "schoolfox: message fields" << arr.first().toObject().keys();
        for (const QJsonValue &v : arr) {
            const QVariantMap m = parseMessage(v.toObject().toVariantMap(), p);
            if (!m.isEmpty())
                m_collected.append(m);
        }
        fetchPupilMessages(index + 1);
    });
}

QVariantMap SchoolFoxClient::parseMessage(const QVariantMap &row, const QVariantMap &pupil) const
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
    // Real list field is "senderName" (seen on device); others are fallbacks.
    m.insert(QStringLiteral("sender"), firstString(row, QStringList()
                                                   << QStringLiteral("senderName")
                                                   << QStringLiteral("creatorFullName")
                                                   << QStringLiteral("CreatorFullName")
                                                   << QStringLiteral("creatorName")));
    m.insert(QStringLiteral("pupil"), pupil.contains(QStringLiteral("name"))
                                          ? pupil.value(QStringLiteral("name"))
                                          : row.value(QStringLiteral("pupilNameForParent")));
    m.insert(QStringLiteral("pupilId"), row.contains(QStringLiteral("pupilId"))
                                            ? row.value(QStringLiteral("pupilId"))
                                            : pupil.value(QStringLiteral("pupilId")));
    m.insert(QStringLiteral("classId"), pupil.value(QStringLiteral("classId")));
    m.insert(QStringLiteral("schoolId"), pupil.value(QStringLiteral("schoolId")));
    m.insert(QStringLiteral("type"), row.value(QStringLiteral("messageType")).toString());
    m.insert(QStringLiteral("eventDate"), parseDate(row.value(QStringLiteral("eventDate")).toString()));
    m.insert(QStringLiteral("endDate"), parseDate(row.value(QStringLiteral("endDate")).toString()));
    m.insert(QStringLiteral("dueDate"), parseDate(row.value(QStringLiteral("dueDate")).toString()));
    m.insert(QStringLiteral("date"), date);
    m.insert(QStringLiteral("serverRead"), row.value(QStringLiteral("isRead")).toBool());
    // Read confirmation (field names seen on device in the list reply).
    const bool signedNow = row.value(QStringLiteral("isSigned")).toBool()
                        || !row.value(QStringLiteral("signingDate")).toString().isEmpty();
    m.insert(QStringLiteral("needsConfirm"), row.value(QStringLiteral("hasSignature")).toBool()
                                             || row.value(QStringLiteral("signatureRequired")).toBool());
    m.insert(QStringLiteral("signed"), signedNow);
    m.insert(QStringLiteral("signedBy"), row.value(QStringLiteral("signedByUserName")).toString());
    m.insert(QStringLiteral("signingDate"), parseDate(row.value(QStringLiteral("signingDate")).toString()));
    // The list reply has no attachment field (checked on device), so the
    // paperclip is unknown (-1) here; the message page loads the real list.
    // NOTE: never range-for over "QStringList() << ..." - the temporary is
    // destroyed before the loop runs (this crashed 0.4.2 / 0.5.0).
    const int files = -1;
    m.insert(QStringLiteral("attachments"), files);
    return m;
}

// Messages without text in the list: fetch tables/Messages/{id}, newest first,
// at most `budget` calls per refresh. Results are cached for the session.
void SchoolFoxClient::fillContent(int index, int budget)
{
    while (index < m_collected.size()) {
        QVariantMap m = m_collected.at(index).toMap();
        applyContent(m);
        m_collected[index] = m;
        if (m.value(QStringLiteral("body")).toString().isEmpty() && budget > 0)
            break;
        ++index;
    }
    if (index >= m_collected.size()) {
        handleMessages(m_collected);
        finishRefresh();
        return;
    }
    const QString id = m_collected.at(index).toMap().value(QStringLiteral("id")).toString();
    if (!validId(id)) {
        fillContent(index + 1, budget);
        return;
    }
    apiGet(QStringLiteral("tables/Messages/") + id,
           [this, index, budget, id](int status, const QByteArray &data,
                                     QNetworkReply::NetworkError err, const QString &) {
        if (status == 200 && err == QNetworkReply::NoError) {
            const QJsonObject o = QJsonDocument::fromJson(data).object();
            static bool logged = false;
            if (!logged) { logged = true; qDebug() << "schoolfox: detail fields" << o.keys(); }
            storeContent(id, parseMessage(o.toVariantMap(), QVariantMap()));
        } else {
            qWarning() << "schoolfox: detail failed" << status;
            QVariantMap failed;
            failed.insert(QStringLiteral("failed"), true);
            m_content.insert(id, failed);   // don't retry this session
        }
        if (index < m_collected.size()) {
            QVariantMap m = m_collected.at(index).toMap();
            applyContent(m);
            m_collected[index] = m;
        }
        fillContent(index + 1, budget - 1);
    });
}

void SchoolFoxClient::storeContent(const QString &id, const QVariantMap &detail)
{
    QVariantMap c;
    c.insert(QStringLiteral("title"), detail.value(QStringLiteral("title")));
    c.insert(QStringLiteral("body"), detail.value(QStringLiteral("body")));
    c.insert(QStringLiteral("html"), detail.value(QStringLiteral("html")));
    if (!detail.value(QStringLiteral("sender")).toString().isEmpty())
        c.insert(QStringLiteral("sender"), detail.value(QStringLiteral("sender")));
    m_content.insert(id, c);
}

void SchoolFoxClient::applyContent(QVariantMap &m) const
{
    const QString id = m.value(QStringLiteral("id")).toString();
    if (!m.value(QStringLiteral("body")).toString().isEmpty() || !m_content.contains(id))
        return;
    const QVariantMap c = m_content.value(id);
    if (c.value(QStringLiteral("failed")).toBool()) {
        m.insert(QStringLiteral("body"), QStringLiteral(" "));   // stop retrying
        return;
    }
    const QStringList always = QStringList() << QStringLiteral("body") << QStringLiteral("html");
    const QStringList ifEmpty = QStringList() << QStringLiteral("sender") << QStringLiteral("title");
    for (const QString &k : always)
        if (!c.value(k).toString().isEmpty())
            m.insert(k, c.value(k));
    for (const QString &k : ifEmpty)
        if (m.value(k).toString().isEmpty() && !c.value(k).toString().isEmpty())
            m.insert(k, c.value(k));
}

void SchoolFoxClient::loadContent(const QString &id)
{
    if (!validId(id) || demo())
        return;
    apiGet(QStringLiteral("tables/Messages/") + id,
           [this, id](int status, const QByteArray &data, QNetworkReply::NetworkError err,
                      const QString &errString) {
        if (status != 200 || err != QNetworkReply::NoError) {
            qWarning() << "schoolfox: detail failed" << status << errString;
            return;
        }
        storeContent(id, parseMessage(QJsonDocument::fromJson(data).object().toVariantMap(), QVariantMap()));
        for (QVariant &v : m_messages) {
            QVariantMap m = v.toMap();
            if (m.value(QStringLiteral("id")).toString() != id)
                continue;
            m.remove(QStringLiteral("body"));
            applyContent(m);
            v = m;
            emit messageUpdated(m);
        }
        emit messagesChanged();
    });
}

QVariantMap SchoolFoxClient::findMessage(const QString &id) const
{
    for (const QVariant &v : m_messages)
        if (v.toMap().value(QStringLiteral("id")).toString() == id)
            return v.toMap();
    return QVariantMap();
}

void SchoolFoxClient::finishRefresh()
{
    setBusy(false);
    emit refreshFinished();
}

void SchoolFoxClient::markRead(const QString &id)
{
    m_readIds.insert(id);
    m_settings.setValue(QStringLiteral("state/read"), toList(m_readIds));
    m_settings.sync();
    for (QVariant &v : m_messages) {
        QVariantMap m = v.toMap();
        if (m.value(QStringLiteral("id")).toString() == id) {
            const bool wasRead = m.value(QStringLiteral("serverRead")).toBool();
            m.insert(QStringLiteral("read"), true);
            v = m;
            if (m_markReadOnServer && !wasRead && !demo())
                tryMarkReadOnServer(id);
        }
    }
    emit messagesChanged();
}

// EXPERIMENTAL: no confirmed "mark read" endpoint is known. The message detail
// carries per-recipient records (tables/MessageRelatedPupils, also used for
// confirmations). If our record has a read flag/date, PATCH it. Logs the outcome.
void SchoolFoxClient::tryMarkReadOnServer(const QString &id)
{
    apiGet(QStringLiteral("tables/Messages/") + id,
           [this, id](int status, const QByteArray &data, QNetworkReply::NetworkError, const QString &) {
        if (status != 200)
            return;
        const QJsonObject msg = QJsonDocument::fromJson(data).object();
        const QJsonArray info = msg.value(QStringLiteral("info")).toArray();
        for (const QJsonValue &v : info) {
            QJsonObject rec = v.toObject();
            if (rec.value(QStringLiteral("userId")).toString() != m_userId)
                continue;
            const QString rid = rec.value(QStringLiteral("id")).toString();
            qDebug() << "schoolfox: read-on-server record fields" << rec.keys();
            bool changed = false;
            for (const QString &k : rec.keys()) {
                const QString lk = k.toLower();
                if ((lk == QLatin1String("isread") || lk == QLatin1String("read")) && !rec.value(k).toBool()) {
                    rec.insert(k, true);
                    changed = true;
                } else if ((lk == QLatin1String("readdate") || lk == QLatin1String("readat")
                            || lk == QLatin1String("readingdate")) && rec.value(k).isNull()) {
                    rec.insert(k, QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
                    changed = true;
                }
            }
            if (!changed || !validId(rid)) {
                qDebug() << "schoolfox: read-on-server: no read field found";
                return;
            }
            authCall("PATCH", QStringLiteral("tables/MessageRelatedPupils/") + rid,
                     QJsonDocument(rec).toJson(QJsonDocument::Compact),
                     [id](int s, const QByteArray &, QNetworkReply::NetworkError, const QString &e) {
                qDebug() << "schoolfox: read-on-server PATCH" << id << "->" << s << e;
            });
            return;
        }
        qDebug() << "schoolfox: read-on-server: no recipient record for this user";
    });
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
    m_pupils.clear();
    QVariantMap p;
    p.insert(QStringLiteral("pupilId"), QStringLiteral("demo-pupil"));
    p.insert(QStringLiteral("classId"), QStringLiteral("demo-class"));
    p.insert(QStringLiteral("schoolId"), QStringLiteral("demo-school"));
    p.insert(QStringLiteral("name"), QStringLiteral("Demo child"));
    m_pupils.append(p);
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
        m.insert(QStringLiteral("pupilId"), QStringLiteral("demo-pupil"));
        m.insert(QStringLiteral("date"), now.addSecs(-3600 * (count - i)));
        m.insert(QStringLiteral("attachments"), i == 1 ? 1 : 0);
        list.append(m);
    }
    handleMessages(list);
    emit refreshFinished();
}

// ---------------------------------------------------------------------------

void SchoolFoxClient::handleMessages(const QVariantList &fresh)
{
    m_messages.clear();
    for (const QVariant &v : fresh) {
        QVariantMap m = v.toMap();
        const QString id = m.value(QStringLiteral("id")).toString();
        m.insert(QStringLiteral("read"), m.value(QStringLiteral("serverRead")).toBool()
                                         || m_readIds.contains(id));
        m_messages.append(m);
    }
    emit messagesChanged();

    if (m_mode != Daemon)
        return;

    // Only the background service tracks what was notified.
    m_settings.sync();
    QSet<QString> notified = toSet(m_settings.value(QStringLiteral("daemon/notified")).toStringList());
    const bool firstSync = !m_settings.value(QStringLiteral("daemon/synced")).toBool();
    QVariantList newOnes;
    QSet<QString> current;
    for (const QVariant &v : m_messages) {
        const QVariantMap m = v.toMap();
        const QString id = m.value(QStringLiteral("id")).toString();
        current.insert(id);
        if (notified.contains(id))
            continue;
        notified.insert(id);
        if (!m.value(QStringLiteral("read")).toBool())
            newOnes.append(m);
    }
    // keep the list bounded: forget ids no longer returned by the server
    notified.intersect(current);
    m_settings.setValue(QStringLiteral("daemon/notified"), toList(notified));
    m_settings.setValue(QStringLiteral("daemon/synced"), true);
    m_settings.sync();
    // Don't spam notifications for the whole backlog on first run.
    if (!firstSync && !newOnes.isEmpty() && m_notificationsEnabled)
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
    m_settings.sync();
    emit loggedInChanged();
}

void SchoolFoxClient::setPendingToken(const QString &token)
{
    if (token == m_pendingToken)
        return;
    m_pendingToken = token;
    emit twoFactorRequiredChanged();
}
