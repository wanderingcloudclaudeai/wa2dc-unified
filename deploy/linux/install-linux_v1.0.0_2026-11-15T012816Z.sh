#!/usr/bin/env bash
# ISO-8601 timestamp (file created): 2026-11-15T01:28:16Z
# ==============================================================================
# install-linux.sh — install and run a wa2dc-unified bridge on a Linux host/VM
# Version: 1.0.0
#
# Version history:
#   1.0.0  2026-11-15T01:28:16Z  Initial release (Debian/Ubuntu + RHEL family,
#                                three bridges, optional systemd service, dry-run).
#
# Run from the root of an extracted release archive or git checkout:
#   sudo bash deploy/linux/install-linux_v1.0.0_*.sh --bridge main
# Options:
#   --bridge main|osdc-wa|hummus   which bridge to install (default: main)
#   --no-service                   build only; do not create a systemd unit
#   --dry-run                      print every command instead of running it
# ==============================================================================
set -Eeuo pipefail                      # stop on errors, unset variables and failed pipes

BRIDGE="main"                           # bridge selected with --bridge
SERVICE=1                               # 1 = create and enable a systemd service
DRY_RUN=0                               # 1 = only print commands
NODE_MAJOR=24                           # main bridge needs Node ^24.22.1 (see package.json "engines")
RUN_USER="wa2dc"                        # unprivileged account that owns and runs the bridge

# --- argument parsing ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
	case "$1" in
		--bridge) BRIDGE="${2:?--bridge needs a value}"; shift 2 ;;
		--no-service) SERVICE=0; shift ;;
		--dry-run) DRY_RUN=1; shift ;;
		-h | --help) sed -n '2,18p' "$0"; exit 0 ;;
		*) echo "Unknown option: $1" >&2; exit 2 ;;
	esac
done

log() { printf '[wa2dc-unified] %s\n' "$*"; }                 # uniform log prefix
die() { printf '[wa2dc-unified] ERROR: %s\n' "$*" >&2; exit 1; }
run() {                                                        # run (or, in dry-run, print) a command
	if [[ $DRY_RUN -eq 1 ]]; then printf '+ %s\n' "$*"; else "$@"; fi
}

# --- locate the repository and the selected bridge ----------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" # deploy/linux -> repository root
[[ -f "$REPO_ROOT/package.json" && -d "$REPO_ROOT/bridges" ]] || die "Run this from a wa2dc-unified checkout."
case "$BRIDGE" in
	main)    WORK_DIR="$REPO_ROOT";                 START_CMD="/usr/bin/env node src/runner.js" ;;
	osdc-wa) WORK_DIR="$REPO_ROOT/bridges/osdc-wa"; START_CMD="/usr/bin/env node src/index.js" ;;
	hummus)  WORK_DIR="$REPO_ROOT/bridges/hummus";  START_CMD="$REPO_ROOT/bridges/hummus/hummus" ;;
	*) die "Unknown bridge '$BRIDGE' (use main, osdc-wa or hummus)." ;;
esac
[[ $DRY_RUN -eq 1 || $EUID -eq 0 ]] || die "Run as root (sudo) so packages and the service can be installed."

# --- operating-system packages ------------------------------------------------
if command -v apt-get >/dev/null 2>&1; then
	PKG_FAMILY="debian"                  # Debian, Ubuntu and derivatives
elif command -v dnf >/dev/null 2>&1; then
	PKG_FAMILY="rhel"                    # RHEL, Rocky, Alma, Fedora
else
	die "Unsupported distribution: need apt-get or dnf."
fi
log "Installing OS packages for bridge '$BRIDGE' ($PKG_FAMILY family)"
if [[ $PKG_FAMILY == debian ]]; then
	export DEBIAN_FRONTEND=noninteractive # never stop for prompts
	run apt-get update
	# Base tools plus the native libraries node-canvas/sharp compile against, and ffmpeg for media.
	run apt-get install -y --no-install-recommends ca-certificates curl git ffmpeg build-essential \
		pkg-config python3 libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev
else
	run dnf install -y ca-certificates curl git gcc gcc-c++ make pkgconf-pkg-config python3 \
		cairo-devel pango-devel libjpeg-turbo-devel giflib-devel librsvg2-devel
fi

# --- language runtime ---------------------------------------------------------
if [[ $BRIDGE == hummus ]]; then
	# Hummus is Go + cgo (sqlite). Any Go >= 1.21 fetches the toolchain pinned in go.mod (GOTOOLCHAIN=auto).
	if [[ $PKG_FAMILY == debian ]]; then run apt-get install -y golang-go; else run dnf install -y golang; fi
else
	# Install Node.js only when the installed major version is too old or missing.
	CURRENT_NODE="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
	if [[ "$CURRENT_NODE" -lt "$NODE_MAJOR" ]]; then
		log "Installing Node.js $NODE_MAJOR.x from NodeSource"
		NODESOURCE_SETUP="$(mktemp)"       # download first, then execute: no curl | bash
		if [[ $PKG_FAMILY == debian ]]; then
			run curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" -o "$NODESOURCE_SETUP"
			run bash "$NODESOURCE_SETUP"
			run apt-get install -y nodejs
		else
			run curl -fsSL "https://rpm.nodesource.com/setup_${NODE_MAJOR}.x" -o "$NODESOURCE_SETUP"
			run bash "$NODESOURCE_SETUP"
			run dnf install -y nodejs
		fi
		rm -f "$NODESOURCE_SETUP"
	fi
fi

# --- service account and ownership ---------------------------------------------
if ! id "$RUN_USER" >/dev/null 2>&1; then
	run useradd --system --create-home --shell /usr/sbin/nologin "$RUN_USER" # no login shell, no password
fi
run chown -R "$RUN_USER:$RUN_USER" "$REPO_ROOT"                # the bridge writes storage/ and .env here

# --- build the selected bridge (as the unprivileged user) ----------------------
as_user() { run runuser -u "$RUN_USER" -- "$@"; }              # drop privileges for builds
cd "$WORK_DIR"
if [[ $BRIDGE == hummus ]]; then
	as_user env CGO_ENABLED=1 GOTOOLCHAIN=auto GOFLAGS=-buildvcs=false go build -trimpath -o hummus .
else
	as_user npm ci --omit=dev                                    # exact, reproducible dependency install
fi
# Create the configuration file from the template without overwriting an existing one.
if [[ ! -f "$WORK_DIR/.env" && -f "$WORK_DIR/.env.example" ]]; then
	as_user cp "$WORK_DIR/.env.example" "$WORK_DIR/.env"
	run chmod 600 "$WORK_DIR/.env"                               # the file will hold the Discord token
fi

# --- systemd service ----------------------------------------------------------
UNIT="wa2dc-unified-${BRIDGE}.service"
if [[ $SERVICE -eq 1 ]]; then
	log "Writing /etc/systemd/system/$UNIT"
	UNIT_BODY="[Unit]
Description=wa2dc-unified ($BRIDGE) WhatsApp <-> Discord bridge
After=network-online.target
Wants=network-online.target

[Service]
User=$RUN_USER
WorkingDirectory=$WORK_DIR
EnvironmentFile=-$WORK_DIR/.env
ExecStart=$START_CMD
Restart=on-failure
RestartSec=10
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=read-only
ReadWritePaths=$WORK_DIR

[Install]
WantedBy=multi-user.target"
	if [[ $DRY_RUN -eq 1 ]]; then
		printf '%s\n' "$UNIT_BODY"
	else
		printf '%s\n' "$UNIT_BODY" > "/etc/systemd/system/$UNIT"
	fi
	run systemctl daemon-reload
	run systemctl enable "$UNIT"                                 # start on boot; started manually after config
fi

# --- next steps ---------------------------------------------------------------
log "Done. Next steps:"
log "  1. Edit $WORK_DIR/.env and set the Discord token (and chat mapping for osdc-wa/hummus)."
log "  2. First start is interactive for WhatsApp linking: sudo -u $RUN_USER -H bash -c 'cd $WORK_DIR && $START_CMD'"
log "     (main: the QR code is posted in the Discord #control-room; osdc-wa/hummus: QR in the terminal)"
log "  3. Stop it with Ctrl+C once linked, then: sudo systemctl start $UNIT && journalctl -fu $UNIT"
# ISO-8601 timestamp (end of file): 2026-11-15T01:28:16Z
