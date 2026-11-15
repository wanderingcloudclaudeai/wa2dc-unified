# Upstream projects, provenance and licensing

Generated: 2026-11-15T01:28:16Z

wa2dc-unified is a merge of the open-source WhatsApp ⇄ Discord bridges found in a survey of GitHub, GitLab, SourceForge and Codeberg on 2026-11-15. This file records exactly what was merged, at which commit, under which licence, and what was deliberately left out.

## Merged

| Upstream | Commit merged | Licence | How it was merged | Where it lives |
| --- | --- | --- | --- | --- |
| [FKLC/WhatsAppToDiscord](https://github.com/FKLC/WhatsAppToDiscord) (original, retired 2025-07-31) | `bf725e4` | MIT | `git merge` (shared history) | repository root |
| [arespawn/WhatsAppToDiscord](https://github.com/arespawn/WhatsAppToDiscord) (maintained successor, v2.6.0) | `45e91fd` | MIT | base of this repository, full history kept | repository root |
| [sabaris-sps/wa2dc](https://github.com/sabaris-sps/wa2dc) (fork of arespawn) | `7bc8707` | MIT | `git merge` (shared history); features re-implemented on the current code | `src/channelReorder.js`, `src/contracts.js`, `src/discordHandler.js`, `src/whatsappHandler.js` |
| [Karvy-Singh/OSdc-wa](https://github.com/Karvy-Singh/OSdc-wa) | `c10fed8` | MIT | `git subtree add` (full history) | `bridges/osdc-wa/` |
| [GoUAE/Hummus](https://github.com/GoUAE/Hummus) | `0adc22c` | MIT | `git subtree add` (full history) | `bridges/hummus/` |

All five histories are reachable from `main`; `git log --follow` and `git blame` attribute every line to its original author.

## Surveyed but not merged

| Project | Reason |
| --- | --- |
| [MAymanKH/Bridger](https://github.com/MAymanKH/Bridger) (Python, Telegram/Discord/WhatsApp) | **GPL-3.0.** Combining it with this code would force the whole repository to GPL-3.0, which the MIT upstreams did not choose. Not copied. |
| [HyeonbinJung/RelayX](https://github.com/HyeonbinJung/RelayX) | **No licence file**, so no permission to copy or redistribute. Not copied. |
| [42wim/matterbridge](https://github.com/42wim/matterbridge) (Apache-2.0) | A general 20-protocol bridge of which WhatsApp ⇄ Discord is a small part; last pushed 2024-12. Importing it would triple the codebase for one overlapping use case. Recommended as an alternative, not merged. |
| mautrix-whatsapp + mautrix-discord (AGPL-3.0) | Bridge through a Matrix homeserver rather than directly; AGPL. Out of scope. |
| GitLab `wcyat/whatsapp-to-discord`, `Ishannaik/WhatsAppToDiscord` | Moved / plain mirrors of FKLC with no additional commits. |
| SourceForge | The project directory returned HTTP 403 to automated requests from the build environment, so it could not be searched. No WhatsApp–Discord bridge is known to be hosted only there, but this was **not verified**. |
| Codeberg | Blocked by the build environment's network policy; **not searched**. |
| Multi-platform AI-agent chat gateways (nanoclaw, opencode-chat-bridge, …) | They connect an AI agent to chat apps; they do not bridge WhatsApp to Discord. |

## Licence of this repository

MIT — every merged upstream is MIT, so the combined work stays MIT. The root [LICENSE.txt](LICENSE.txt) carries the original copyright notice; `bridges/osdc-wa/LICENSE` and `bridges/hummus/LICENSE` are preserved unchanged as their notices require. Third-party dependencies keep their own licences (Baileys MIT, discord.js Apache-2.0, whatsmeow MPL-2.0, discordgo BSD-3-Clause); they are downloaded at install time and are not vendored here.

## Changes made to merged code

| Area | Change |
| --- | --- |
| sabaris-sps `/reorderchannels` | Extracted to `src/channelReorder.js`; no longer awaited on the message path; 10-minute per-channel cooldown; threads skipped; setting now persisted. |
| sabaris-sps `/historysyncdays` | The fork's filter compared a notification object with a timestamp and rejected every history chunk. Re-implemented per chunk via `oldestMsgInChunkTimestampSec`; `0` (default) keeps upstream behaviour. |
| sabaris-sps per-message `try/catch` in `messages.upsert` | Kept, with structured logging. |
| sabaris-sps image normalisation, background update check | Not taken: the first is already upstream in a better (sharp-based) form; the second races the updater's restart logic. |
| FKLC final commits | Version bumps, retired workflow and the retirement notice; superseded, history kept. |
| Hummus | Ported to current whatsmeow (context-aware API), discordgo 0.29, go-sqlite3 1.14.x; added `WA_CHAT_JID` alias; fixed `.env` example. |
| OSdc-wa | `package.json` said ISC while `LICENSE` is MIT — corrected to MIT; its deploy workflow (specific to the author's server) removed. |
| Updater | Release feed is configurable with `WA2DC_UPDATE_REPO` (defaults to upstream). |
| Upstream release pipeline | `release.yml` needs upstream's GitHub App and signing keys; it now runs only if the repository variable `WA2DC_UPSTREAM_RELEASE_PIPELINE` is `true`. `unified-release.yml` builds this repository's releases. |

## Keeping in sync

```bash
bash scripts/sync-upstreams_v1.0.0_2026-11-15T012816Z.sh
```

```bash
bash scripts/sync-upstreams_v1.0.0_2026-11-15T012816Z.sh --merge
```
