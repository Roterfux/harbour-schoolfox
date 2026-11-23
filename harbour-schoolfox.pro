TARGET = harbour-schoolfox

CONFIG += sailfishapp sailfishapp_i18n link_pkgconfig
QT += network dbus
PKGCONFIG += keepalive nemonotifications-qt5

HEADERS += \
    src/appservice.h \
    src/daemon.h \
    src/schoolfoxclient.h

SOURCES += \
    src/appservice.cpp \
    src/daemon.cpp \
    src/main.cpp \
    src/schoolfoxclient.cpp

# Background service (systemd user unit, enabled for every user session)
systemd.files = harbour-schoolfox-daemon.service
systemd.path = /usr/lib/systemd/user
INSTALLS += systemd

# D-Bus activation: notification taps start the app
dbus.files = org.roterfux.harbour-schoolfox.service
dbus.path = /usr/share/dbus-1/services
INSTALLS += dbus

TRANSLATIONS += translations/harbour-schoolfox-de.ts

DISTFILES += \
    harbour-schoolfox.desktop \
    harbour-schoolfox-daemon.service \
    org.roterfux.harbour-schoolfox.service \
    qml/harbour-schoolfox.qml \
    qml/cover/*.qml \
    qml/pages/*.qml \
    rpm/harbour-schoolfox.spec \
    translations/*.ts

icons86.files = icons/86x86/harbour-schoolfox.png
icons86.path = /usr/share/icons/hicolor/86x86/apps
icons108.files = icons/108x108/harbour-schoolfox.png
icons108.path = /usr/share/icons/hicolor/108x108/apps
icons128.files = icons/128x128/harbour-schoolfox.png
icons128.path = /usr/share/icons/hicolor/128x128/apps
icons172.files = icons/172x172/harbour-schoolfox.png
icons172.path = /usr/share/icons/hicolor/172x172/apps
INSTALLS += icons86 icons108 icons128 icons172
