# harbour-claudechat

Sailfish OS wrapper around the claude.ai web chat (Silica WebView). No API,
no API key: log in on the website inside the app.
If web login fails (Google login is often blocked in embedded browsers), pull down >
"Set session cookie" and paste the `sessionKey` cookie value copied from a desktop
browser (DevTools > Cookies > claude.ai). Cookie expires; paste a new one then.

- QML only, `Sailfish.WebView` (needs `sailfish-components-webview-qt5` on the phone).
- Not for Harbour (WebView with a third-party site); distribute via GitHub releases, OpenRepos or Chum.

## Build (sfdk)

```bash
sfdk -c target=SailfishOS-<version>-aarch64 build
sfdk -c target=SailfishOS-<version>-aarch64 -c device="<device>" deploy --sdk
```
