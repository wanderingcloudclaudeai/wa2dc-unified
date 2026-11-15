> Part of [wa2dc-unified](../../README.md). Imported from [GoUAE/Hummus](https://github.com/GoUAE/Hummus) and ported to the current whatsmeow API; see [UPSTREAMS.md](../../UPSTREAMS.md).

# Hummus

[![Go Report](https://goreportcard.com/badge/github.com/gouae/hummus)](https://goreportcard.com/report/gouae/hummus) [![Coders(HQ) Discord](https://img.shields.io/badge/Discord-%23golang-blue.svg)](https://golang.ae/discord) 

Hummus is a GoUAE Community project that bridges the Coders(HQ) [WhatsApp](https://golang.ae/whatsapp) communication channels with [Discord](https://golang.ae/discord).

Do note that for now, we aim to just be read-only, sending messages one way (WhatsApp -> Discord). Given the constraints of WhatsApp.

## Quickstart
> [!NOTE]
> Make sure you have [go](https://go.dev) [installed](https://go.dev/dl/).

1. Clone the repository
```sh
git clone https://github.com/GoUAE/Hummus
cd Hummus
```

2. Copy the `.env.example` file to `.env`
```sh
cp .env.example .env
```

3. Fill in the necessary environment variables in the .env file. You'll need to provide values for the following variables:
```env
DISCORD_BOT_TOKEN=
DISCORD_CHANNEL_ID=
DISCORD_WEBHOOK_ID=
DISCORD_WEBHOOK_TOKEN=
DISCORD_FALLBACK_AVATAR_URL=
# Only one WhatsApp chat is supported. WA_CHAT_JID is its JID, e.g. 1203630xxxxxxxx@g.us
# (WA_GOUAE_JID is still accepted for existing installs).
WA_CHAT_JID=
```

4. Install the dependencies
```sh
go mod download
```

5. Run the project (cgo and a C compiler are required for SQLite)
```sh
CGO_ENABLED=1 go run .
```

6. Scan the QR code to log in to the WhatsApp client. 

## Maintainers
- [Gaurav-Gosain](https://github.com/gaurav-gosain)

## LICENSE
This project is licensed under the [MIT License](LICENSE).