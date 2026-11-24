# harbour-claudechat

Basic native Sailfish OS chat client for Claude (Silica/QML + C++, Qt 5.6 safe).

- Anthropic Messages API (`POST https://api.anthropic.com/v1/messages`, no streaming).
- Pull-down menu: settings (API key, model, system prompt) and new chat.
- Conversation kept in memory; cover shows the last answer.
- Settings: `~/.config/org.roterfux/harbour-claudechat/settings.conf` (mode 600, key unencrypted).

## Build (sfdk)

```bash
sfdk -c target=SailfishOS-<version>-aarch64 build
sfdk -c target=SailfishOS-<version>-aarch64 -c device="<device>" deploy --sdk
```
