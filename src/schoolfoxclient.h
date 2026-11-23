#ifndef SCHOOLFOXCLIENT_H
#define SCHOOLFOXCLIENT_H

#include <QDateTime>
#include <QHash>
#include <QJSValue>
#include <QNetworkReply>
#include <QObject>
#include <QSet>
#include <QSettings>
#include <QVariantList>
#include <functional>

class QNetworkAccessManager;

/*
 * Talks to the private SchoolFox web API (https://api.schoolfox.com, the same
 * contract the my.schoolfox.app web client uses) and keeps the message list.
 *
 * Flow: POST api/Users/login -> (optional POST api/2fa/login) -> token
 *       GET api/Common/Inventory -> pupils (itemType "Pupil")
 *       GET tables/Messages?$filter=... per pupil -> {results, count}
 *       401 -> GET api/Users/login/token (renew) -> stored password login.
 *
 * Used by the app (Mode::App) and by the background service (Mode::Daemon).
 * Both share one settings file; only the daemon publishes notifications.
 *
 * Log in with user name "demo" to use built-in fake data.
 */
class SchoolFoxClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loggedIn READ loggedIn NOTIFY loggedInChanged)
    Q_PROPERTY(bool demo READ demo NOTIFY loggedInChanged)
    Q_PROPERTY(bool twoFactorRequired READ twoFactorRequired NOTIFY twoFactorRequiredChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString username READ username NOTIFY loggedInChanged)
    Q_PROPERTY(QString userId READ userId NOTIFY identityChanged)
    Q_PROPERTY(QString fullName READ fullName NOTIFY identityChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(QVariantList pupils READ pupils NOTIFY messagesChanged)
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY messagesChanged)
    Q_PROPERTY(int pollMinutes READ pollMinutes WRITE setPollMinutes NOTIFY settingsChanged)
    Q_PROPERTY(bool notificationsEnabled READ notificationsEnabled WRITE setNotificationsEnabled NOTIFY settingsChanged)
    Q_PROPERTY(bool notificationContent READ notificationContent WRITE setNotificationContent NOTIFY settingsChanged)
    Q_PROPERTY(bool rememberPassword READ rememberPassword WRITE setRememberPassword NOTIFY settingsChanged)
    Q_PROPERTY(bool markReadOnServer READ markReadOnServer WRITE setMarkReadOnServer NOTIFY settingsChanged)
    Q_PROPERTY(bool unreadOnly READ unreadOnly WRITE setUnreadOnly NOTIFY settingsChanged)
    Q_PROPERTY(QDateTime lastBackgroundCheck READ lastBackgroundCheck NOTIFY settingsChanged)

public:
    enum Mode { App, Daemon };

    explicit SchoolFoxClient(Mode mode, QObject *parent = nullptr);

    static QString settingsPath();
    static QString downloadDir();

    bool loggedIn() const { return !m_token.isEmpty(); }
    bool demo() const;
    bool twoFactorRequired() const { return !m_pendingToken.isEmpty(); }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString username() const { return m_username; }
    QString userId() const { return m_userId; }
    QString fullName() const { return m_fullName; }
    QVariantList messages() const { return m_messages; }
    QVariantList pupils() const { return m_pupils; }
    int unreadCount() const;
    int pollMinutes() const { return m_pollMinutes; }
    void setPollMinutes(int minutes);
    bool notificationsEnabled() const { return m_notificationsEnabled; }
    void setNotificationsEnabled(bool on);
    bool notificationContent() const { return m_notificationContent; }
    void setNotificationContent(bool on);
    bool rememberPassword() const { return m_rememberPassword; }
    void setRememberPassword(bool on);
    bool markReadOnServer() const { return m_markReadOnServer; }
    void setMarkReadOnServer(bool on);
    QDateTime lastBackgroundCheck() const;
    bool unreadOnly() const { return m_unreadOnly; }
    void setUnreadOnly(bool on);

    Q_INVOKABLE void login(const QString &username, const QString &password);
    Q_INVOKABLE void submitTwoFactorCode(const QString &code);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void markRead(const QString &id);
    Q_INVOKABLE QVariantMap findMessage(const QString &id) const;
    // Loads full content of one message (tables/Messages/{id}); emits messageUpdated.
    Q_INVOKABLE void loadContent(const QString &id);

    // Generic authenticated call for QML pages.
    // callback(status:int, body:string). Only GET retries after renewing the session.
    Q_INVOKABLE void api(const QString &method, const QString &path, const QVariant &body,
                         const QJSValue &callback);
    // Downloads a message attachment to ~/Downloads/SchoolFox. callback(ok, pathOrError)
    Q_INVOKABLE void downloadAttachment(const QString &messageId, const QString &fileName,
                                        const QJSValue &callback);
    // Writes a text file (e.g. .ics) to ~/Downloads/SchoolFox, returns path or "".
    Q_INVOKABLE QString saveTextFile(const QString &fileName, const QString &content);

    void reloadSettings();
    void recordBackgroundCheck();

signals:
    void loggedInChanged();
    void identityChanged();
    void twoFactorRequiredChanged();
    void busyChanged();
    void errorChanged();
    void messagesChanged();
    void settingsChanged();
    void messageUpdated(const QVariantMap &message);
    // Daemon mode: unread messages not notified before.
    void newMessages(const QVariantList &messages);
    // Emitted after every refresh attempt, success or not.
    void refreshFinished();

private:
    typedef std::function<void(int status, const QByteArray &data, QNetworkReply::NetworkError err,
                               const QString &errString)> Handler;

    QNetworkReply *send(const QByteArray &method, const QString &path,
                        const QByteArray &body, const QString &token);
    void call(const QByteArray &method, const QString &path, const QByteArray &body,
              const QString &token, Handler handler);
    void authCall(const QByteArray &method, const QString &path, const QByteArray &body,
                  Handler handler, bool allowRecover = true);
    void recover(const QString &failedToken, std::function<void(bool)> done);
    void apiGet(const QString &path, Handler handler) { authCall("GET", path, QByteArray(), handler); }

    bool acceptLogin(const QByteArray &data, bool afterTwoFactor);
    void fetchInventory();
    void fetchPupilMessages(int index);
    void fillContent(int index, int budget);
    void applyContent(QVariantMap &m) const;
    void storeContent(const QString &id, const QVariantMap &detail);
    void finishRefresh();
    QVariantMap parseMessage(const QVariantMap &row, const QVariantMap &pupil) const;
    void tryMarkReadOnServer(const QString &id);
    void fetchRedirect(const QUrl &url, const QString &target, const QJSValue &callback);

    void demoFetchMessages();

    void handleMessages(const QVariantList &fresh);
    void setBusy(bool busy);
    void setError(const QString &error);
    void setToken(const QString &token);
    void setPendingToken(const QString &token);
    void setSetting(const QString &key, const QVariant &value);

    Mode m_mode;
    QNetworkAccessManager *m_nam;
    QSettings m_settings;
    QString m_token;
    QString m_pendingToken;   // temporary token while waiting for 2FA code
    QString m_username;
    QString m_password;       // only kept when rememberPassword is on
    QString m_userId;
    QString m_fullName;
    QString m_error;
    bool m_busy = false;
    int m_pollMinutes = 15;
    bool m_notificationsEnabled = true;
    bool m_notificationContent = true;
    bool m_rememberPassword = true;
    bool m_markReadOnServer = false;
    bool m_unreadOnly = false;
    QVariantList m_messages;
    QSet<QString> m_readIds;
    QHash<QString, QVariantMap> m_content;   // id -> {title, body, html} from detail calls
    int m_demoCounter = 0;

    // refresh state
    QVariantList m_pupils;        // {pupilId, classId, schoolId, name, plan}
    QVariantList m_collected;
};

#endif // SCHOOLFOXCLIENT_H
