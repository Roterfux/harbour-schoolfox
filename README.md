# harbour-schoolfox

Unofficial native Sailfish OS app (Silica/QML + C++) that checks SchoolFox for
new messages and shows them as Sailfish notifications. No Android layer.

## Status

- UI, polling, notifications, cover: done.
- **SchoolFox API: placeholder.** SchoolFox has no public API. Fill in the
  `API` section of `src/schoolfoxclient.cpp` (URLs, login body, auth header,
  JSON field names) from requests captured in the SchoolFox web app
  (browser DevTools → Network).
- Log in with user name `demo` to test with fake data. A new fake message
  appears every second refresh.

## Build (sfdk)

```bash
sfdk -c target=SailfishOS-<version>-aarch64 build
sfdk -c target=SailfishOS-<version>-aarch64 -c device="<device>" deploy --sdk
```

## Limits

- Polling runs via `Nemo.KeepAlive` `BackgroundJob` only while the app is
  running (open or on cover). Closed app = no notifications.
- Token is stored in plain QSettings; the password is never stored.
