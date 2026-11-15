# wa2dc-unified 2.7.0

First unified release. Based on WhatsAppToDiscord 2.6.0 (arespawn) with FKLC/WhatsAppToDiscord, sabaris-sps/wa2dc, Karvy-Singh/OSdc-wa and GoUAE/Hummus merged in.

## Added
- `/reorderchannels`: optionally move active chats to the top of their category (throttled, threads excluded).
- `/historysyncdays`: optionally accept recent WhatsApp history chunks (0–365 days, default 0 = off).
- `bridges/osdc-wa`: lightweight `.env`-configured two-way bridge.
- `bridges/hummus`: Go read-only WhatsApp → Discord mirror, ported to current whatsmeow.
- Linux and Windows installers, VM creation scripts, upstream sync script.
- `WA2DC_UPDATE_REPO` to choose the release feed used for update notices.

## Fixed
- One malformed WhatsApp message no longer drops the rest of its batch.
- The history-sync filter from the wa2dc fork rejected all history; it now filters per chunk.
- OSdc-wa `package.json` licence field corrected to MIT.

## Install
See the releases guide in `docs/unified/` of the source archive. Verify downloads against `SHA256SUMS.txt`.
