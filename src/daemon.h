#ifndef DAEMON_H
#define DAEMON_H

#include <QObject>
#include <QVariantList>

class BackgroundActivity;
class SchoolFoxClient;

/*
 * Background service (harbour-schoolfox --daemon), started by the systemd
 * user unit harbour-schoolfox-daemon.service. Wakes the device with
 * libkeepalive every N minutes, refreshes and publishes Sailfish
 * notifications for new messages. Tapping a notification calls
 * org.roterfux.schoolfox.openMessage(id) on the app's D-Bus name.
 */
class Daemon : public QObject
{
    Q_OBJECT
public:
    explicit Daemon(QObject *parent = nullptr);

private slots:
    void poll();
    void pollDone();
    void notify(const QVariantList &messages);

private:
    void scheduleNext();

    SchoolFoxClient *m_client;
    BackgroundActivity *m_activity;
};

#endif // DAEMON_H
