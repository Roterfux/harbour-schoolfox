#include <QCoreApplication>
#include <QGuiApplication>
#include <QLocale>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>
#include <QTranslator>
#include <sailfishapp.h>

#include "appservice.h"
#include "daemon.h"
#include "schoolfoxclient.h"

static void setNames(QCoreApplication *app)
{
    app->setOrganizationName(QStringLiteral("org.roterfux"));
    app->setApplicationName(QStringLiteral("harbour-schoolfox"));
}

int main(int argc, char *argv[])
{
    for (int i = 1; i < argc; ++i) {
        if (qstrcmp(argv[i], "--daemon") == 0) {
            // No window, but QtGui text classes are used (HTML -> plain text).
            qputenv("QT_QPA_PLATFORM", "minimal");
            QGuiApplication app(argc, argv);
            setNames(&app);
            QTranslator tr;
            if (tr.load(QLocale(), QStringLiteral("harbour-schoolfox"), QStringLiteral("-"),
                        QStringLiteral("/usr/share/harbour-schoolfox/translations")))
                app.installTranslator(&tr);
            Daemon daemon;
            return app.exec();
        }
    }

    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    setNames(app.data());

    SchoolFoxClient client(SchoolFoxClient::App);
    AppService service;
    service.registerOnBus();

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty(QStringLiteral("SchoolFox"), &client);
    view->rootContext()->setContextProperty(QStringLiteral("AppService"), &service);
    view->setSource(SailfishApp::pathToMainQml());
    view->show();

    return app->exec();
}
