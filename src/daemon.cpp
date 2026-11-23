#include "daemon.h"
#include "schoolfoxclient.h"

#include <QDateTime>
#include <QDebug>
#include <keepalive/backgroundactivity.h>
#include <nemonotifications-qt5/notification.h>

Daemon::Daemon(QObject *parent)
    : QObject(parent)
    , m_client(new SchoolFoxClient(SchoolFoxClient::Daemon, this))
    , m_activity(new BackgroundActivity(this))
{
    connect(m_activity, &BackgroundActivity::running, this, &Daemon::poll);
    connect(m_client, &SchoolFoxClient::refreshFinished, this, &Daemon::pollDone);
    connect(m_client, &SchoolFoxClient::newMessages, this, &Daemon::notify);
    qDebug() << "schoolfox-daemon: started";
    m_activity->run();   // first check right away
}

void Daemon::poll()
{
    m_client->reloadSettings();
    if (!m_client->loggedIn()) {
        qDebug() << "schoolfox-daemon: not logged in, sleeping";
        scheduleNext();
        return;
    }
    qDebug() << "schoolfox-daemon: checking";
    m_client->refresh();
}

void Daemon::pollDone()
{
    m_client->recordBackgroundCheck();
    scheduleNext();
}

void Daemon::scheduleNext()
{
    const int m = m_client->pollMinutes();
    BackgroundActivity::Frequency f = BackgroundActivity::OneHour;
    if (m <= 5) f = BackgroundActivity::FiveMinutes;
    else if (m <= 10) f = BackgroundActivity::TenMinutes;
    else if (m <= 15) f = BackgroundActivity::FifteenMinutes;
    else if (m <= 30) f = BackgroundActivity::ThirtyMinutes;
    m_activity->wait(f);   // releases the keepalive until the next wakeup
}

void Daemon::notify(const QVariantList &messages)
{
    const bool withText = m_client->notificationContent();
    for (const QVariant &v : messages) {
        const QVariantMap m = v.toMap();
        QString text;
        if (withText) {
            text = m.value(QStringLiteral("body")).toString().simplified();
            if (text.length() > 300)
                text = text.left(300) + QChar(0x2026);
        }
        const QString who = QStringList(QStringList() << m.value(QStringLiteral("sender")).toString()
                                                      << m.value(QStringLiteral("pupil")).toString())
                                .filter(QRegExp(QStringLiteral("\\S"))).join(QStringLiteral(" · "));
        const QString title = m.value(QStringLiteral("title")).toString();

        Notification n;
        n.setAppName(QStringLiteral("SchoolFox"));
        n.setAppIcon(QStringLiteral("harbour-schoolfox"));
        n.setCategory(QStringLiteral("x-nemo.messaging.im"));
        n.setSummary(title);
        n.setBody(text.isEmpty() ? who : text);
        n.setPreviewSummary(title);
        n.setPreviewBody(text.isEmpty() ? who : text);
        n.setTimestamp(m.value(QStringLiteral("date")).toDateTime());
        n.setRemoteActions(QVariantList() << Notification::remoteAction(
            QStringLiteral("default"), QString(),
            QStringLiteral("org.roterfux.harbour-schoolfox"),
            QStringLiteral("/org/roterfux/schoolfox"),
            QStringLiteral("org.roterfux.schoolfox"),
            QStringLiteral("openMessage"),
            QVariantList() << m.value(QStringLiteral("id"))));
        n.publish();
        qDebug() << "schoolfox-daemon: notified" << m.value(QStringLiteral("id")).toString();
    }
}
