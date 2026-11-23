#ifndef APPSERVICE_H
#define APPSERVICE_H

#include <QObject>

/*
 * D-Bus entry point of the app: org.roterfux.harbour-schoolfox,
 * /org/roterfux/schoolfox, interface org.roterfux.schoolfox.
 * Called by notification taps (also starts the app via D-Bus activation).
 */
class AppService : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.roterfux.schoolfox")
public:
    explicit AppService(QObject *parent = nullptr) : QObject(parent) {}
    bool registerOnBus();

public slots:
    Q_SCRIPTABLE void openMessage(const QString &id) { emit openMessageRequested(id); }
    Q_SCRIPTABLE void activate() { emit activateRequested(); }

signals:
    void openMessageRequested(const QString &id);
    void activateRequested();
};

#endif // APPSERVICE_H
