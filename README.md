# wa2dc-unified

<p align="center">
  <img src="docs/_media/logo.png" alt="WA2DC logo" width="160" />
</p>

**One repository for the open-source WhatsApp ⇄ Discord bridges.** wa2dc-unified merges WhatsAppToDiscord (FKLC's original and arespawn's maintained successor), the sabaris-sps `wa2dc` fork, OSdc-wa and Hummus, with their full git histories, under the MIT licence they all share.

| Bridge | Path | Stack | Direction | Pick it when |
| --- | --- | --- | --- | --- |
| **WA2DC** (main) | repository root | Node.js 24, Baileys, discord.js | two-way | You want everything: every chat mirrored to its own channel or thread, slash commands, media, polls, newsletters, encryption at rest. |
| **OSdc-wa** | `bridges/osdc-wa` | Node.js 22+, Baileys, discord.js | two-way | You want a small bridge that maps a few named groups to channels from a `.env` file. |
| **Hummus** | `bridges/hummus` | Go, whatsmeow, discordgo | WhatsApp → Discord | You want a single read-only mirror of one chat as one static binary. |

These bridges use unofficial WhatsApp Web clients. They are not affiliated with WhatsApp or Discord, can break when WhatsApp changes its protocol, and can put the linked account at risk of restriction. Do not use them for spam, bulk messaging or monitoring people without consent.

## Quick start (main bridge)

Linux (Debian/Ubuntu/RHEL family), from a checkout or an extracted release archive:

```bash
sudo bash deploy/linux/install-linux_v1.0.0_2026-11-15T012816Z.sh --bridge main
```

Windows 10/11 or Server 2022+, from an elevated PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\deploy\windows\install-windows_v1.0.0_2026-11-15T012816Z.ps1 -Bridge main
```

Docker:

```bash
cp .env.example .env   # then set WA2DC_TOKEN
docker compose up -d --build
```

Then create the Discord bot, invite it and scan the WhatsApp QR code as described in [docs/setup.md](docs/setup.md).

## Documentation

| Topic | Document |
| --- | --- |
| Download, compile, run, publish a release | [Releases guide](docs/unified/RELEASES_2026-11-15T012816Z.md) |
| Create Linux and Windows host VMs | [VM host guide](docs/unified/VM-HOSTS_2026-11-15T012816Z.md) |
| What was merged, from where, and why | [UPSTREAMS.md](UPSTREAMS.md) |
| How this repository was built (blog post) | [Blog post](docs/unified/blog/BLOG_merging-the-whatsapp-discord-bridges_2026-11-15T012816Z.md) |
| The five recommendations and what was done | [Recommendations](docs/unified/RECOMMENDATIONS_2026-11-15T012816Z.md) |
| Main bridge setup, configuration, commands, FAQ | [docs/](docs/README.md) |
| OSdc-wa and Hummus configuration | [bridges/osdc-wa/README.md](bridges/osdc-wa/README.md), [bridges/hummus/README.md](bridges/hummus/README.md) |

## What is new compared with the upstreams

- `/reorderchannels` and `/historysyncdays` from the sabaris-sps fork, fixed and covered by tests ([details](UPSTREAMS.md#changes-made-to-merged-code)).
- Hummus builds against the current whatsmeow again (the 2024 upstream no longer compiles against it).
- One CI pipeline for all three bridges, one tag-driven release workflow, one installer per operating system.
- A script that reports and merges new upstream commits: `scripts/sync-upstreams_v1.0.0_2026-11-15T012816Z.sh`.

## Development

```bash
npm ci
npm run check
npm test
npm --prefix bridges/osdc-wa ci
npm run test:bridges
```

The main bridge needs Node.js 24.22.1–24.x or 26.12.1+. `npm run test:bridges` also needs Go (any 1.21+; the toolchain pinned in `bridges/hummus/go.mod` is fetched automatically) and a C compiler.

## Licence and credits

MIT — see [LICENSE.txt](LICENSE.txt). Credit for the code belongs to its authors: Fatih Kilic (FKLC), arespawn and the WhatsAppToDiscord contributors, sabaris-sps, Karvy Singh, and the GoUAE community. See [UPSTREAMS.md](UPSTREAMS.md).
