# Five WhatsApp–Discord bridges, one repository: how wa2dc-unified was built

Published: 2026-11-15T01:28:16Z

If you search for a way to connect WhatsApp to Discord you find the same project several times over: an original, the fork that took it over, forks of that fork, and a few independent rewrites. Each has something the others lack. This post describes how they were surveyed, which ones were merged into **wa2dc-unified**, what broke along the way, and how to run the result on a Linux or Windows VM.

## 1. The survey

The search covered GitHub (repository search API, six queries), GitLab (project search API), SourceForge and Codeberg. Two honest caveats: SourceForge answered automated requests with HTTP 403 and Codeberg was blocked by the build environment's network policy, so neither could actually be searched.

What turned up, after discarding AI-agent chat gateways and unrelated bots:

| Project | Language | Licence | Last push | Verdict |
| --- | --- | --- | --- | --- |
| FKLC/WhatsAppToDiscord | JavaScript | MIT | 2025-07 (retired) | merged |
| arespawn/WhatsAppToDiscord | JavaScript | MIT | 2026-10 | merged (base) |
| sabaris-sps/wa2dc | JavaScript | MIT | 2026-04 | merged |
| Karvy-Singh/OSdc-wa | JavaScript | MIT | 2026-10 | merged |
| GoUAE/Hummus | Go | MIT | 2024-06 | merged |
| MAymanKH/Bridger | Python | GPL-3.0 | 2026-03 | excluded |
| HyeonbinJung/RelayX | JavaScript | none | 2026-10 | excluded |
| 42wim/matterbridge | Go | Apache-2.0 | 2024-12 | referenced only |

## 2. Name and licence

The original calls itself "WhatsAppToDiscord", its package and binaries are `wa2dc`, one fork is literally named `wa2dc`, and OSdc-wa keeps the `wa` too. **wa2dc-unified** says what it is and where it comes from.

The licence followed from the sources: all five merged projects are MIT, so the combination is MIT. That is also why two projects stayed out. Bridger is GPL-3.0 — copying it in would have relicensed everything. RelayX has no licence at all, which legally means "all rights reserved", however public the repository is. matterbridge (Apache-2.0) would have been compatible, but it is a 20-protocol bridge several times the size of everything else combined.

## 3. The merge

Three of the five projects turned out to share one git history, which decided the strategy:

```text
FKLC (125 commits) ──► arespawn (892 commits) ──► sabaris-sps (5 commits of its own)
OSdc-wa (45 commits)      unrelated history
Hummus  (11 commits)      unrelated history
```

**Step 1 — start from the most advanced line.** The repository began as a clone of arespawn's `main` (v2.6.0).

**Step 2 — merge the original.** FKLC's last seven commits were version bumps, a retired workflow and the retirement notice. `git merge` joined the history; every conflict was resolved in favour of the maintained code.

**Step 3 — merge the wa2dc fork.** A plain merge produced an 11,000-line conflict because the fork had reformatted every file. Merging with `-Xignore-all-space` reduced that to the real difference: about 240 lines. Reading those lines showed that only part of them should be kept:

- `/reorderchannels` moved a chat's channel to the top on every message, awaited inside the message handler. Discord allows two channel updates per ten minutes per channel, so a busy chat would have stalled its own delivery. It is now a separate module with a per-channel cooldown, runs in the background, skips threads, and saves its setting.
- `/historysyncdays` compared the wrong thing: the callback receives a history *notification*, not a message, so the comparison was always false and no history was ever synced. The rewritten filter uses the notification's oldest-message timestamp.
- The fork's image fix was already upstream in a better form, and its "check for updates in the background" change was left out because it races the updater's restart logic.

A mistake worth admitting: after the merge, the formatter was run with auto-fix on a file that still had a syntax error, and it "fixed" the file into nonsense. The test suite caught it immediately (57 failures); the port was redone cleanly on the maintained file.

**Step 4 — import the independent bridges.** `git subtree add` placed OSdc-wa and Hummus under `bridges/` with their complete histories, so `git blame` still names the original authors.

**Step 5 — repair.** Hummus compiled against its 2024 dependency pin but not against the current whatsmeow, whose API now takes a `context.Context` almost everywhere. Six call sites were updated. OSdc-wa declared ISC in `package.json` and MIT in `LICENSE`; the file wins, the field was corrected.

Result: more than 960 commits of history from five projects, 393 tests in the main bridge (392 pass, 1 skipped by upstream), 62 of 62 in OSdc-wa, and Hummus building with `go vet` clean.

## 4. Around the code

- **CI:** upstream's pipeline still covers the main bridge on Linux, macOS and Windows. A second workflow tests OSdc-wa, builds Hummus on Linux and Windows and lints the deployment scripts.
- **Releases:** pushing a `unified-v*` tag runs every test suite and publishes source archives, Hummus binaries and SHA-256 checksums. Upstream's own release pipeline needs upstream's signing keys, so it is kept but switched off unless explicitly enabled.
- **Staying current:** `scripts/sync-upstreams_*.sh` lists new commits in all four live upstreams and merges them on request.

## 5. How to run it

**Create a VM.** On a Linux host with Multipass:

```bash
bash deploy/linux/create-linux-vm_v1.0.0_2026-11-15T012816Z.sh --backend multipass --repo-url https://github.com/wanderingcloudclaudeai/wa2dc-unified.git
```

On a Windows host with Hyper-V (elevated PowerShell):

```powershell
.\deploy\windows\create-windows-vm_v1.0.0_2026-11-15T012816Z.ps1 -IsoPath C:\ISO\Win11_x64.iso
```

KVM, VirtualBox, Azure and AWS variants are in the [VM host guide](../VM-HOSTS_2026-11-15T012816Z.md).

**Install the bridge inside the VM.** Linux:

```bash
cd /opt/wa2dc-unified && sudo bash deploy/linux/install-linux_v1.0.0_2026-11-15T012816Z.sh --bridge main
```

Windows:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force; .\deploy\windows\install-windows_v1.0.0_2026-11-15T012816Z.ps1 -Bridge main
```

**Create the Discord bot.** In the Discord Developer Portal create an application, copy the bot token, and enable the *Message Content Intent*. Put the token in `.env` as `WA2DC_TOKEN=...`.

**Link WhatsApp.** Start the bridge once by hand:

```bash
npm start
```

Open the invite URL it prints, add the bot to your server, and scan the QR code that appears in the new `#control-room` channel from WhatsApp → Linked devices. Stop with Ctrl+C and start the service:

```bash
sudo systemctl start wa2dc-unified-main.service
```

From then on, `/start`, `/link` and the other [slash commands](../../commands.md) manage which chats are bridged. The complete walk-through, including checksum verification and upgrades, is the [releases guide](../RELEASES_2026-11-15T012816Z.md).

## 6. Five recommendations

1. Port fork features onto maintained code rather than merging stale files.
2. Keep the Go bridge on a current WhatsApp library.
3. Run one CI and one release pipeline for all bridges.
4. Install with one command and run as a service.
5. Record provenance and keep pulling from upstream.

All five were carried out in this repository; the [recommendations document](../RECOMMENDATIONS_2026-11-15T012816Z.md) says how, and what was deliberately not done.

## 7. Limits you should know about

- Every bridge here uses an unofficial WhatsApp Web client. WhatsApp can change its protocol or restrict an account at any time.
- The merged code was verified by automated tests and builds. Nothing in this project was tested against live WhatsApp or Discord accounts during the merge, and the Windows scripts were not executed (no Windows machine was available) — run them with `-WhatIf` first.
- The Linux installer was exercised in dry-run mode only.
- `storage/` (and `hummus.db`) hold the WhatsApp session. Whoever has that directory has the account.

Credit for the software belongs to the people who wrote it: Fatih Kilic, arespawn and the WhatsAppToDiscord contributors, sabaris-sps, Karvy Singh and the GoUAE community.
