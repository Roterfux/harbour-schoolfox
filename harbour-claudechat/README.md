# harbour-claudechat

Sailfish OS wrapper around the claude.ai web chat (Silica WebView). No API,
no API key: log in on the website inside the app.

- QML only, `Sailfish.WebView` (needs `sailfish-components-webview-qt5` on the phone).
- Not for Harbour (WebView with a third-party site); distribute via GitHub releases, OpenRepos or Chum.

## Build (sfdk)

```bash
sfdk -c target=SailfishOS-<version>-aarch64 build
sfdk -c target=SailfishOS-<version>-aarch64 -c device="<device>" deploy --sdk
```
