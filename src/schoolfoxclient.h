#ifndef SCHOOLFOXCLIENT_H
#define SCHOOLFOXCLIENT_H

#include <QObject>
#include <QHash>
#include <QSet>
#include <QSettings>
#include <QVariantList>
#include <functional>

#include <QNetworkReply>

class QNetworkAccessManager;

/*
 * Talks to the private SchoolFox web API (https://api.schoolfox.com, the same
 * contract the my.schoolfox.app web client uses) and keeps the message list.
 *
 * Flow: POST api/Users/login -> (optional POST api/2fa/login) -> token
 *       GET api/Common/Inventory -> pupils (itemType "Pupil")
 *       GET tables/Messages?$filter=... per pupil -> {results, count}
 *       401 -> GET api/Users/login/token (renew), else log in again.
 *
 * Log in with user name "demo" to use built-in fake data.
 */
class SchoolFoxClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loggedIn READ loggedIn NOTIFY loggedInChanged)
    Q_PROPERTY(bool twoFactorRequired READ twoFactorRequired NOTIFY twoFactorRequiredChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString username READ username NOTIFY loggedInChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY messagesChanged)
    Q_PROPERTY(int pollMinutes READ pollMinutes WRITE setPollMinutes NOTIFY pollMinutesChanged)
    Q_PROPERTY(bool notificationsEnabled READ notificationsEnabled WRITE setNotificationsEnabled NOTIFY notificationsEnabledChanged)
    Q_PROPERTY(bool notificationContent READ notificationContent WRITE setNotificationContent NOTIFY notificationContentChanged)

public:
    explicit SchoolFoxClient(QObject *parent = nullptr);

    bool loggedIn() const { return !m_token.isEmpty(); }
    bool twoFactorRequired() const { return !m_pendingToken.isEmpty(); }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString username() const { return m_username; }
    QVariantList messages() const { return m_messages; }
    int unreadCount() const;
    int pollMinutes() const { return m_pollMinutes; }
    void setPollMinutes(int minutes);
    bool notificationsEnabled() const { return m_notificationsEnabled; }
    void setNotificationsEnabled(bool on);
    bool notificationContent() const { return m_notificationContent; }
    void setNotificationContent(bool on);

    Q_INVOKABLE void login(const QString &username, const QString &password);
    Q_INVOKABLE void submitTwoFactorCode(const QString &code);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void markRead(const QString &id);
    // Loads full content of one message (tables/Messages/{id}); emits messageUpdated.
    Q_INVOKABLE void loadContent(const QString &id);

signals:
    void loggedInChanged();
    void twoFactorRequiredChanged();
    void busyChanged();
    void errorChanged();
    void messagesChanged();
    void pollMinutesChanged();
    void notificationsEnabledChanged();
    void notificationContentChanged();
    void messageUpdated(const QVariantMap &message);
    // Messages not seen before. Each item: {id, title, body, html, sender, pupil, date, read}
    void newMessages(const QVariantList &messages);
    // Emitted after every refresh attempt, success or not (for BackgroundJob.finished()).
    void refreshFinished();

private:
    typedef std::function<void(int status, const QByteArray &data, QNetworkReply::NetworkError err,
                               const QString &errString)> Handler;

    QNetworkReply *send(const QByteArray &method, const QString &path,
                        const QByteArray &body, const QString &token);
    void call(const QByteArray &method, const QString &path, const QByteArray &body,
              const QString &token, Handler handler);
    void apiGet(const QString &path, Handler handler, bool allowRenew = true);

    bool acceptLogin(const QByteArray &data, bool afterTwoFactor);
    void fetchInventory();
    void fetchPupilMessages(int index);
    void finishRefresh(bool ok);
    void fillContent(int index, int budget);
    void applyContent(QVariantMap &m) const;
    void storeContent(const QString &id, const QVariantMap &detail);
    QVariantMap parseMessage(const QVariantMap &row, const QString &pupilName) const;

    void demoFetchMessages();

    void handleMessages(const QVariantList &fresh);
    void setBusy(bool busy);
    void setError(const QString &error);
    void setToken(const QString &token);
    void setPendingToken(const QString &token);

    QNetworkAccessManager *m_nam;
    QSettings m_settings;
    QString m_token;
    QString m_pendingToken;   // temporary token while waiting for 2FA code
    QString m_username;
    QString m_error;
    bool m_busy = false;
    int m_pollMinutes = 15;
    bool m_notificationsEnabled = true;
    bool m_notificationContent = true;
    QHash<QString, QVariantMap> m_content;   // id -> {title, body, html} from detail calls
    QVariantList m_messages;
    QSet<QString> m_seenIds;
    QSet<QString> m_readIds;
    int m_demoCounter = 0;

    // refresh state
    QVariantList m_pupils;        // {pupilId, classId, name}
    QVariantList m_collected;
};

#endif // SCHOOLFOXCLIENT_H
