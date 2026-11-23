TARGET = harbour-schoolfox

CONFIG += sailfishapp
QT += network

HEADERS += \
    src/schoolfoxclient.h

SOURCES += \
    src/main.cpp \
    src/schoolfoxclient.cpp

desktop.files = harbour-schoolfox.desktop
desktop.path = /usr/share/applications
INSTALLS += desktop

DISTFILES += \
    harbour-schoolfox.desktop \
    qml/harbour-schoolfox.qml \
    qml/cover/CoverPage.qml \
    qml/pages/LoginPage.qml \
    qml/pages/MessagesPage.qml \
    qml/pages/MessagePage.qml \
    qml/pages/SettingsPage.qml \
    rpm/harbour-schoolfox.spec

icons86.files = icons/86x86/harbour-schoolfox.png
icons86.path = /usr/share/icons/hicolor/86x86/apps
icons108.files = icons/108x108/harbour-schoolfox.png
icons108.path = /usr/share/icons/hicolor/108x108/apps
icons128.files = icons/128x128/harbour-schoolfox.png
icons128.path = /usr/share/icons/hicolor/128x128/apps
icons172.files = icons/172x172/harbour-schoolfox.png
icons172.path = /usr/share/icons/hicolor/172x172/apps
INSTALLS += icons86 icons108 icons128 icons172
