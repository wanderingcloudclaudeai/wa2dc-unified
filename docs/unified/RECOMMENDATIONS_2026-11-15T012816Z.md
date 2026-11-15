# Five recommendations — and what was done about each

Document timestamp: 2026-11-15T01:28:16Z

| # | Recommendation | Why | Carried out |
| --- | --- | --- | --- |
| 1 | **Port fork features onto the maintained code instead of taking the fork's files.** | The sabaris-sps fork was 218 commits behind and fully reformatted; a textual merge would have reverted months of fixes. | Features re-implemented on current code, two bugs fixed on the way (history filter rejected everything; channel moves blocked message delivery and ignored Discord's rate limit). 7 new tests in `tests/unifiedPorts.test.js`. |
| 2 | **Bring Hummus back to a buildable, current state.** | It was pinned to a May 2024 whatsmeow, and the code did not compile against the current library. | Ported to the context-aware whatsmeow API, dependencies updated, `go vet` clean, neutral `WA_CHAT_JID` setting added. |
| 3 | **One CI and one release pipeline for everything.** | Three projects with three (or zero) pipelines drift apart; upstream's release pipeline needs secrets this repository does not have. | `unified-ci.yml` (OSdc-wa tests, Hummus build on Linux and Windows, script linting) next to upstream's `ci.yml`; `unified-release.yml` publishes tagged releases with checksums; upstream's signing pipeline is kept but opt-in. |
| 4 | **Make installation a single command and run the bridge as a service.** | A bridge that stops when a terminal window closes is not dependable, and the main bridge needs native libraries that are easy to miss by hand. | `deploy/linux/install-linux_*.sh` (systemd unit, unprivileged user, sandboxing) and `deploy/windows/install-windows_*.ps1` (winget, scheduled task), plus VM creation scripts for Multipass, KVM and Hyper-V. Docker Compose now builds from the checkout. |
| 5 | **Record provenance and keep following upstream.** | A merged repository is only trustworthy if every line can be traced and it does not silently fork. | `UPSTREAMS.md` (commits, licences, exclusions and reasons), full histories preserved, `scripts/sync-upstreams_*.sh` reports and merges new upstream work, `WA2DC_UPDATE_REPO` lets update notices follow this repository. |

## Not done, and why

- **No code from Bridger (GPL-3.0) or RelayX (no licence)** — see `UPSTREAMS.md`.
- **No single "super-bridge" binary.** The three bridges use different languages and WhatsApp libraries; forcing them into one process would add risk without adding a feature. They share a repository, CI, installers and documentation instead.
- **No signed single-file binaries of the main bridge.** Upstream's updater only trusts upstream's signing key; publishing look-alike binaries under another key would mislead users. Source installs and Docker are supported.
