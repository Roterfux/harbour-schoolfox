TARGET = harbour-claudechat

CONFIG += sailfishapp

SOURCES += src/main.cpp

DISTFILES += \
    harbour-claudechat.desktop \
    qml/harbour-claudechat.qml \
    qml/cover/*.qml \
    qml/pages/*.qml \
    rpm/harbour-claudechat.spec

icons86.files = icons/86x86/harbour-claudechat.png
icons86.path = /usr/share/icons/hicolor/86x86/apps
icons108.files = icons/108x108/harbour-claudechat.png
icons108.path = /usr/share/icons/hicolor/108x108/apps
icons128.files = icons/128x128/harbour-claudechat.png
icons128.path = /usr/share/icons/hicolor/128x128/apps
icons172.files = icons/172x172/harbour-claudechat.png
icons172.path = /usr/share/icons/hicolor/172x172/apps
INSTALLS += icons86 icons108 icons128 icons172
