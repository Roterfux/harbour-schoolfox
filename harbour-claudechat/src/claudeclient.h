#ifndef CLAUDECLIENT_H
#define CLAUDECLIENT_H

#include <QObject>
#include <QSettings>
#include <QVariantList>

class QNetworkAccessManager;

/*
 * Minimal client for the Anthropic Messages API (POST /v1/messages, no
 * streaming). Keeps the conversation in memory; API key, model and system
 * prompt live in ~/.config/org.roterfux/harbour-claudechat/ (mode 600).
 */
class ClaudeClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY settingsChanged)
    Q_PROPERTY(QString model READ model WRITE setModel NOTIFY settingsChanged)
    Q_PROPERTY(QString systemPrompt READ systemPrompt WRITE setSystemPrompt NOTIFY settingsChanged)

public:
    explicit ClaudeClient(QObject *parent = nullptr);

    QVariantList messages() const { return m_messages; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString apiKey() const { return m_settings.value(QStringLiteral("apiKey")).toString(); }
    QString model() const;
    QString systemPrompt() const { return m_settings.value(QStringLiteral("systemPrompt")).toString(); }
    void setApiKey(const QString &key);
    void setModel(const QString &model);
    void setSystemPrompt(const QString &prompt);

    Q_INVOKABLE void send(const QString &text);
    Q_INVOKABLE void clear();

signals:
    void messagesChanged();
    void busyChanged();
    void errorChanged();
    void settingsChanged();

private:
    void setBusy(bool busy);
    void setError(const QString &error);

    QNetworkAccessManager *m_nam;
    QSettings m_settings;
    QVariantList m_messages;   // {role: "user"|"assistant", text}
    bool m_busy = false;
    QString m_error;
};

#endif // CLAUDECLIENT_H
