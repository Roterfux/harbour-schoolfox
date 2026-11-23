#include "appservice.h"

#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>

bool AppService::registerOnBus()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerObject(QStringLiteral("/org/roterfux/schoolfox"), this,
                            QDBusConnection::ExportScriptableSlots)) {
        qWarning() << "schoolfox: cannot register D-Bus object" << bus.lastError().message();
        return false;
    }
    if (!bus.registerService(QStringLiteral("org.roterfux.harbour-schoolfox"))) {
        qWarning() << "schoolfox: cannot own D-Bus name" << bus.lastError().message();
        return false;
    }
    return true;
}
