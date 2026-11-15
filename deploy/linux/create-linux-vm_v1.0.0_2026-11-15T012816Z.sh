#!/usr/bin/env bash
# ISO-8601 timestamp (file created): 2026-11-15T01:28:16Z
# ==============================================================================
# create-linux-vm.sh — create an Ubuntu Server 24.04 LTS VM for wa2dc-unified
# Version: 1.0.0
#
# Version history:
#   1.0.0  2026-11-15T01:28:16Z  Initial release (Multipass and KVM/libvirt
#                                back ends, cloud-init first-boot provisioning).
#
# Usage (on the machine that will HOST the VM):
#   bash deploy/linux/create-linux-vm_v1.0.0_*.sh --backend multipass
#   bash deploy/linux/create-linux-vm_v1.0.0_*.sh --backend kvm --ssh-key ~/.ssh/id_ed25519.pub
# Options:
#   --backend multipass|kvm   hypervisor front end (default: multipass)
#   --name NAME               VM name (default: wa2dc)
#   --cpus N --memory-mb N --disk-gb N   VM size (default: 2 CPUs, 2048 MB, 20 GB)
#   --ssh-key FILE            public key allowed to log in as "ubuntu" (required for kvm)
#   --repo-url URL            git URL of your wa2dc-unified repository to clone on first boot
#   --dry-run                 print commands and the cloud-init file, change nothing
# ==============================================================================
set -Eeuo pipefail                       # stop on errors, unset variables and failed pipes

BACKEND="multipass"; NAME="wa2dc"        # hypervisor front end and VM name
CPUS=2; MEMORY_MB=2048; DISK_GB=20       # sizing: the main bridge idles at ~300 MB RAM; 2 GB leaves headroom
SSH_KEY=""; REPO_URL=""; DRY_RUN=0       # optional inputs
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" # Ubuntu 24.04 cloud image

while [[ $# -gt 0 ]]; do                 # --- argument parsing ---
	case "$1" in
		--backend) BACKEND="$2"; shift 2 ;;
		--name) NAME="$2"; shift 2 ;;
		--cpus) CPUS="$2"; shift 2 ;;
		--memory-mb) MEMORY_MB="$2"; shift 2 ;;
		--disk-gb) DISK_GB="$2"; shift 2 ;;
		--ssh-key) SSH_KEY="$2"; shift 2 ;;
		--repo-url) REPO_URL="$2"; shift 2 ;;
		--dry-run) DRY_RUN=1; shift ;;
		-h | --help) sed -n '2,22p' "$0"; exit 0 ;;
		*) echo "Unknown option: $1" >&2; exit 2 ;;
	esac
done

log() { printf '[create-linux-vm] %s\n' "$*"; }
die() { printf '[create-linux-vm] ERROR: %s\n' "$*" >&2; exit 1; }
run() { if [[ $DRY_RUN -eq 1 ]]; then printf '+ %s\n' "$*"; else "$@"; fi; }
need() { [[ $DRY_RUN -eq 1 ]] || command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed. $2"; }

# --- cloud-init: runs once inside the VM on first boot --------------------------
WORK="$(mktemp -d)"                      # scratch directory for generated files
trap 'rm -rf "$WORK"' EXIT               # always clean it up
USER_DATA="$WORK/user-data.yaml"
{
	echo "#cloud-config"
	echo "hostname: $NAME"
	echo "package_update: true"            # apt-get update on first boot
	echo "package_upgrade: true"           # apply pending security updates
	echo "packages: [git, ca-certificates, curl, unattended-upgrades]"
	if [[ -n "$SSH_KEY" ]]; then           # authorise the caller's public key for the default user
		[[ -r "$SSH_KEY" ]] || die "Cannot read SSH public key: $SSH_KEY"
		echo "ssh_authorized_keys:"
		echo "  - $(cat "$SSH_KEY")"
	fi
	echo "runcmd:"
	if [[ -n "$REPO_URL" ]]; then          # optional: fetch the repository into /opt on first boot
		echo "  - [git, clone, --depth, '1', '$REPO_URL', /opt/wa2dc-unified]"
	else
		echo "  - [mkdir, -p, /opt/wa2dc-unified]"
	fi
} > "$USER_DATA"
if [[ $DRY_RUN -eq 1 ]]; then log "cloud-init user-data:"; cat "$USER_DATA"; fi

# --- create the VM ------------------------------------------------------------
case "$BACKEND" in
	multipass)
		need multipass "Install it with: sudo snap install multipass"
		# One command: downloads Ubuntu 24.04, creates the VM and applies cloud-init.
		run multipass launch 24.04 --name "$NAME" --cpus "$CPUS" --memory "${MEMORY_MB}M" \
			--disk "${DISK_GB}G" --cloud-init "$USER_DATA"
		run multipass info "$NAME"           # shows the IP address
		log "Open a shell with: multipass shell $NAME"
		;;
	kvm)
		[[ -n "$SSH_KEY" ]] || die "--ssh-key is required for the kvm backend (cloud images have no password)."
		need virt-install "Install with: sudo apt-get install -y qemu-kvm libvirt-daemon-system virtinst"
		need qemu-img "Install with: sudo apt-get install -y qemu-utils"
		POOL="/var/lib/libvirt/images"        # default libvirt storage pool
		BASE="$POOL/noble-server-cloudimg-amd64.img"
		[[ -f "$BASE" || $DRY_RUN -eq 1 ]] || run sudo curl -fL "$IMAGE_URL" -o "$BASE" # download the image once
		# Thin copy-on-write disk on top of the pristine cloud image, grown to the requested size.
		run sudo qemu-img create -f qcow2 -F qcow2 -b "$BASE" "$POOL/$NAME.qcow2" "${DISK_GB}G"
		# Import the disk, attach cloud-init, use the default NAT network and a serial console.
		run sudo virt-install --name "$NAME" --vcpus "$CPUS" --memory "$MEMORY_MB" \
			--disk "path=$POOL/$NAME.qcow2,format=qcow2,bus=virtio" --import \
			--cloud-init "user-data=$USER_DATA" --os-variant ubuntu24.04 \
			--network network=default,model=virtio --graphics none --noautoconsole
		log "Find the IP with: sudo virsh domifaddr $NAME   then: ssh ubuntu@<ip>"
		;;
	*) die "Unknown backend '$BACKEND' (use multipass or kvm)." ;;
esac

log "Inside the VM run: cd /opt/wa2dc-unified && sudo bash deploy/linux/install-linux_v1.0.0_*.sh --bridge main"
# ISO-8601 timestamp (end of file): 2026-11-15T01:28:16Z
