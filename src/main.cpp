#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QScopedPointer>
#include <sailfishapp.h>

#include "schoolfoxclient.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    app->setOrganizationName(QStringLiteral("org.roterfux"));
    app->setApplicationName(QStringLiteral("harbour-schoolfox"));

    SchoolFoxClient client;

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty(QStringLiteral("SchoolFox"), &client);
    view->setSource(SailfishApp::pathToMainQml());
    view->show();

    return app->exec();
}
