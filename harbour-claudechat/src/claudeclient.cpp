#include "claudeclient.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStandardPaths>

static const char DefaultModel[] = "claude-sonnet-5-5";

static QString settingsPath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
        + QStringLiteral("/org.roterfux/harbour-claudechat");
    QDir().mkpath(dir);
    return dir + QStringLiteral("/settings.conf");
}

ClaudeClient::ClaudeClient(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
    , m_settings(settingsPath(), QSettings::IniFormat)
{
    QFile::setPermissions(settingsPath(), QFile::ReadOwner | QFile::WriteOwner);
}

QString ClaudeClient::model() const
{
    return m_settings.value(QStringLiteral("model"), QLatin1String(DefaultModel)).toString();
}

void ClaudeClient::setApiKey(const QString &key)
{
    m_settings.setValue(QStringLiteral("apiKey"), key.trimmed());
    m_settings.sync();
    QFile::setPermissions(settingsPath(), QFile::ReadOwner | QFile::WriteOwner);
    emit settingsChanged();
}

void ClaudeClient::setModel(const QString &model)
{
    m_settings.setValue(QStringLiteral("model"), model.trimmed());
    emit settingsChanged();
}

void ClaudeClient::setSystemPrompt(const QString &prompt)
{
    m_settings.setValue(QStringLiteral("systemPrompt"), prompt);
    emit settingsChanged();
}

void ClaudeClient::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void ClaudeClient::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    emit errorChanged();
}

void ClaudeClient::clear()
{
    m_messages.clear();
    setError(QString());
    emit messagesChanged();
}

void ClaudeClient::send(const QString &text)
{
    const QString trimmed = text.trimmed();
    if (m_busy || trimmed.isEmpty())
        return;
    if (apiKey().isEmpty()) {
        setError(tr("Set your API key in the settings first."));
        return;
    }

    QVariantMap user;
    user[QStringLiteral("role")] = QStringLiteral("user");
    user[QStringLiteral("text")] = trimmed;
    m_messages.append(user);
    emit messagesChanged();
    setError(QString());
    setBusy(true);

    QJsonArray history;
    foreach (const QVariant &v, m_messages) {
        const QVariantMap m = v.toMap();
        QJsonObject o;
        o[QStringLiteral("role")] = m[QStringLiteral("role")].toString();
        o[QStringLiteral("content")] = m[QStringLiteral("text")].toString();
        history.append(o);
    }
    QJsonObject body;
    body[QStringLiteral("model")] = model();
    body[QStringLiteral("max_tokens")] = 4096;
    body[QStringLiteral("messages")] = history;
    if (!systemPrompt().trimmed().isEmpty())
        body[QStringLiteral("system")] = systemPrompt();

    QNetworkRequest req(QUrl(QStringLiteral("https://api.anthropic.com/v1/messages")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("x-api-key", apiKey().toUtf8());
    req.setRawHeader("anthropic-version", "2023-06-01");

    QNetworkReply *reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        setBusy(false);
        const QByteArray data = reply->readAll();
        const QJsonObject obj = QJsonDocument::fromJson(data).object();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        if (status != 200) {
            QString msg = obj.value(QStringLiteral("error")).toObject()
                              .value(QStringLiteral("message")).toString();
            if (msg.isEmpty())
                msg = reply->errorString();
            setError(tr("Error %1: %2").arg(status).arg(msg));
            // drop the unanswered user message so the user can edit and resend
            if (!m_messages.isEmpty()) {
                m_messages.removeLast();
                emit messagesChanged();
            }
            return;
        }

        QString answer;
        foreach (const QJsonValue &block, obj.value(QStringLiteral("content")).toArray()) {
            if (block.toObject().value(QStringLiteral("type")).toString() == QLatin1String("text"))
                answer += block.toObject().value(QStringLiteral("text")).toString();
        }
        QVariantMap assistant;
        assistant[QStringLiteral("role")] = QStringLiteral("assistant");
        assistant[QStringLiteral("text")] = answer;
        m_messages.append(assistant);
        emit messagesChanged();
    });
}
