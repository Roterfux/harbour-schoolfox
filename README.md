# harbour-schoolfox

Unofficial native Sailfish OS app (Silica/QML + C++) that checks SchoolFox for
new messages and shows them as Sailfish notifications. No Android layer.

## Status

- Real SchoolFox login (email + password, optional 2FA code), all children
  in the account, message title + content, notifications with title + content.
- Uses the private API of the SchoolFox web client (`https://api.schoolfox.com`,
  `ZUMO-API-VERSION: 2.0.0`, `X-ZUMO-AUTH` token). Routes and field names come
  from the public reverse-engineered projects
  [zagushka/schoolfox-mcp](https://github.com/zagushka/schoolfox-mcp) and
  [emanuelplopu/SchoolFoxAPI](https://github.com/emanuelplopu/SchoolFoxAPI).
  SchoolFox can change this API at any time.
- User name `demo` shows fake data.

| Step | Request |
| --- | --- |
| Login | `POST api/Users/login` `{username, password, applicationType: "SchoolFox"}` |
| 2FA | `POST api/2fa/login` `{password: code}` with temporary token |
| Children | `GET api/Common/Inventory`, items with `itemType: "Pupil"` |
| Messages | `GET tables/Messages?$filter=Deleted eq false and SchoolClassId eq '…' and PupilId eq '…'` |
| Renew | `GET api/Users/login/token` on HTTP 401 |

Messages are not marked read on the server; "read" is local only.

## Build (sfdk)

```bash
sfdk -c target=SailfishOS-<version>-aarch64 build
sfdk -c target=SailfishOS-<version>-aarch64 -c device="<device>" deploy --sdk
```

## Limits

- Polling runs via `Nemo.KeepAlive` `BackgroundJob` only while the app is
  running (open or on cover). Closed app = no notifications.
- Token is stored in plain QSettings; the password is never stored.
