#ifndef SCHOOLFOXCLIENT_H
#define SCHOOLFOXCLIENT_H

#include <QObject>
#include <QSet>
#include <QSettings>
#include <QVariantList>

class QNetworkAccessManager;
class QNetworkReply;

/*
 * Talks to SchoolFox and keeps the message list.
 *
 * SchoolFox has no public API. Everything server-specific lives in the
 * "API" section of schoolfoxclient.cpp (URLs, request bodies, JSON parsing).
 * Until real requests are captured, log in with username "demo" to use
 * built-in fake data.
 */
class SchoolFoxClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loggedIn READ loggedIn NOTIFY loggedInChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString username READ username NOTIFY loggedInChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY messagesChanged)
    Q_PROPERTY(int pollMinutes READ pollMinutes WRITE setPollMinutes NOTIFY pollMinutesChanged)

public:
    explicit SchoolFoxClient(QObject *parent = nullptr);

    bool loggedIn() const { return !m_token.isEmpty(); }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString username() const { return m_username; }
    QVariantList messages() const { return m_messages; }
    int unreadCount() const;
    int pollMinutes() const { return m_pollMinutes; }
    void setPollMinutes(int minutes);

    Q_INVOKABLE void login(const QString &username, const QString &password);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void markRead(const QString &id);

signals:
    void loggedInChanged();
    void busyChanged();
    void errorChanged();
    void messagesChanged();
    void pollMinutesChanged();
    // Messages not seen before. Each item: {id, title, body, sender, date, read}
    void newMessages(const QVariantList &messages);
    // Emitted after every refresh attempt, success or not (for BackgroundJob.finished()).
    void refreshFinished();

private:
    // --- API (replace with real SchoolFox calls) ---
    void apiLogin(const QString &username, const QString &password);
    void apiFetchMessages();
    QVariantList parseMessages(const QByteArray &json) const;

    // --- demo mode ---
    void demoFetchMessages();

    void handleMessages(const QVariantList &fresh);
    void setBusy(bool busy);
    void setError(const QString &error);
    void setToken(const QString &token);

    QNetworkAccessManager *m_nam;
    QSettings m_settings;
    QString m_token;
    QString m_username;
    QString m_error;
    bool m_busy = false;
    int m_pollMinutes = 15;
    QVariantList m_messages;
    QSet<QString> m_seenIds;
    QSet<QString> m_readIds;
    int m_demoCounter = 0;
};

#endif // SCHOOLFOXCLIENT_H
