# harbour-schoolfox

Unofficial native Sailfish OS app (Silica/QML + C++) that checks SchoolFox for
new messages and shows them as Sailfish notifications. No Android layer.

## Features

- Real SchoolFox login (email + password, optional 2FA code), all children.
- Message list with title, sender, child and text preview; full content.
- **Background service** (`harbour-schoolfox --daemon`, systemd user unit
  `harbour-schoolfox-daemon.service`): checks every 5–60 min with
  libkeepalive and publishes Sailfish notifications, also when the app is closed.
- Tapping a notification opens that message (D-Bus `org.roterfux.harbour-schoolfox`).
- Stay logged in: optional stored password (not encrypted) for automatic re-login.
- Attachments: list, download to `~/Downloads/SchoolFox`, open.
- Confirm messages that ask for a read confirmation.
- Events and due dates page; add to the Sailfish calendar (.ics).
- Report an absence (all-day) to selected teachers.
- Reply threads of class messages; standalone chats (read and send text).
- German translation.
- Experimental: mark read in SchoolFox (guessed method, logs the result).
- User name `demo` shows fake data.

Uses the private API of the SchoolFox web client (`https://api.schoolfox.com`,
`ZUMO-API-VERSION: 2.0.0`, `X-ZUMO-AUTH` token). Routes and field names come
from the public reverse-engineered projects
[zagushka/schoolfox-mcp](https://github.com/zagushka/schoolfox-mcp) and
[emanuelplopu/SchoolFoxAPI](https://github.com/emanuelplopu/SchoolFoxAPI).
SchoolFox can change this API at any time. Write features (confirm, absence,
replies, chat send) follow that project's contract but were not verified
against a live account there either.

| Feature | Request |
| --- | --- |
| Login / 2FA / renew | `POST api/Users/login`, `POST api/2fa/login`, `GET api/Users/login/token` |
| Children | `GET api/Common/Inventory` (`itemType: "Pupil"`) |
| Messages | `GET tables/Messages?$filter=…`, `GET tables/Messages/{id}` |
| Attachments | `GET api/Files/Messages/{id}[?fileName=…]` (302 to getfile.foxeducation.com) |
| Confirm | `PATCH tables/MessageRelatedPupils/{recipientId}` |
| Replies | `GET tables/InstantMessageGroups`, `GET/POST tables/InstantMessages` |
| Absence | `GET api/SchoolClasses/{id}/Teachers`, `GET api/Messages/HasAbsence`, `POST tables/Messages`, `POST api/Messages/{id}/Pupils/{pupil}/TeacherRecipients` |
| Chats | `GET api/OrganizationsForConversations`, `GET tables/Conversations`, `GET/POST tables/ConversationMessages` |

Not for Harbour: the background service and D-Bus activation are not allowed
there. Distribute via GitHub releases, OpenRepos or Chum.

## Build (sfdk)

```bash
sfdk -c target=SailfishOS-<version>-aarch64 build
sfdk -c target=SailfishOS-<version>-aarch64 -c device="<device>" deploy --sdk
```

## Files on the phone

- Settings, token and (if "stay logged in") the password:
  `~/.config/org.roterfux/harbour-schoolfox/settings.conf` (mode 600).
- Service log: `journalctl --user -u harbour-schoolfox-daemon`.
