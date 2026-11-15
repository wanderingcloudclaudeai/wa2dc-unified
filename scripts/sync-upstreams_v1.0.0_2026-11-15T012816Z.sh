#!/usr/bin/env bash
# ISO-8601 timestamp (file created): 2026-11-15T01:28:16Z
# ==============================================================================
# sync-upstreams.sh — pull new upstream work into wa2dc-unified
# Version: 1.0.0
#
# Version history:
#   1.0.0  2026-11-15T01:28:16Z  Initial release (reports new upstream commits;
#                                merges the main line and subtree bridges on request).
#
# Usage (from the repository root, clean working tree):
#   bash scripts/sync-upstreams_v1.0.0_*.sh            # report only: what is new upstream?
#   bash scripts/sync-upstreams_v1.0.0_*.sh --merge    # merge everything that is new
# Excluded on purpose (see UPSTREAMS.md): MAymanKH/Bridger (GPL-3.0) and
# HyeonbinJung/RelayX (no licence) are never fetched or merged.
# ==============================================================================
set -Eeuo pipefail                       # stop on errors, unset variables and failed pipes

MERGE=0                                  # 0 = report only, 1 = merge
[[ "${1:-}" == "--merge" ]] && MERGE=1

# name | git URL | branch | subtree prefix ("" = same history as the repository root)
UPSTREAMS=(
	"arespawn|https://github.com/arespawn/WhatsAppToDiscord.git|main|"
	"sabaris-sps|https://github.com/sabaris-sps/wa2dc.git|main|"
	"osdc-wa|https://github.com/Karvy-Singh/OSdc-wa.git|main|bridges/osdc-wa"
	"hummus|https://github.com/GoUAE/Hummus.git|main|bridges/hummus"
)

cd "$(git rev-parse --show-toplevel)"    # always operate from the repository root
if [[ $MERGE -eq 1 && -n "$(git status --porcelain)" ]]; then
	echo "Working tree is not clean; commit or stash first." >&2
	exit 1
fi

for entry in "${UPSTREAMS[@]}"; do
	IFS='|' read -r name url branch prefix <<< "$entry"   # split the table row
	echo "== $name ($url, $branch)"
	git fetch --quiet --no-tags "$url" "$branch"          # result lands in FETCH_HEAD
	tip="$(git rev-parse FETCH_HEAD)"
	if [[ -z "$prefix" ]]; then
		# Shared history: anything reachable from upstream but not from HEAD is new.
		new="$(git rev-list --count "HEAD..$tip")"
		echo "   $new new commit(s)"
		git --no-pager log --oneline --no-decorate -n 10 "HEAD..$tip" | sed 's/^/   /'
		if [[ $MERGE -eq 1 && "$new" -gt 0 ]]; then
			# Stops on conflicts so they can be resolved by hand; nothing is forced.
			git merge --no-ff -m "Merge upstream $name ($branch)" "$tip"
		fi
	else
		# Subtree: git-subtree records the last merged upstream commit in the merge message.
		last="$(git log --grep="^git-subtree-dir: $prefix\$" -n 1 --format=%B |
			sed -n 's/^git-subtree-split: //p')"
		if [[ "$last" == "$tip" ]]; then
			echo "   up to date"
		else
			echo "   upstream moved: ${last:0:12} -> ${tip:0:12}"
			if [[ $MERGE -eq 1 ]]; then
				git subtree pull --prefix="$prefix" "$url" "$branch" \
					-m "Merge upstream $name into $prefix"
			fi
		fi
	fi
done

if [[ $MERGE -eq 1 ]]; then
	echo "Merged. Now run: npm ci && npm run check && npm test && npm run test:bridges"
fi
# ISO-8601 timestamp (end of file): 2026-11-15T01:28:16Z
