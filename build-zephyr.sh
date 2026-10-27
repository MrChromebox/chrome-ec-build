#!/bin/bash
#
# Build Zephyr Chrome EC firmware (zmake) in Docker.
#
# Non-Zephyr boards stay on ./build-docker.sh. This script is for zmake
# projects such as screebo. The image matches the Framework Zephyr EC
# container: Debian bookworm, Zephyr SDK 0.16.9, u-boot binman.
#
# Zephyr and CMSIS are cloned from the ChromiumOS manifest branch that
# corresponds to the EC firmware branch (the "-main" suffix is EC-only).
# Checkouts live under deps/<deps-branch>/ and are not part of this repo.
#
# Usage:
#   ./build-zephyr.sh [--no-sync] [--copy] [--log] <board|rex> [...]
#   ./build-zephyr.sh --branch <ec-branch> <zmake-project>
#
# Output (inside the EC tree):
#   build/zephyr/<board>/output/ec.bin       packed RO+RW image
#   build/zephyr/<board>/output/ec.RW.flat   RW image coreboot consumes
#
# --copy installs ec.RW.flat into coreboot blobs (google/rex/<board>/...).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EC_ROOT="${EC_ROOT:-$SCRIPT_DIR/chrome-ec}"
DEPS_ROOT="${DEPS_ROOT:-$SCRIPT_DIR/deps}"
IMAGE="${EC_IMAGE_ZEPHYR:-chrome-ec-zephyr:bookworm}"
DOCKERFILE="$SCRIPT_DIR/docker/zephyr/Dockerfile"

ZEPHYR_URL="${ZEPHYR_URL:-https://chromium.googlesource.com/chromiumos/third_party/zephyr}"
CMSIS_URL="${CMSIS_URL:-https://chromium.googlesource.com/chromiumos/third_party/zephyr/cmsis}"

COREBOOT_ROOT="${COREBOOT_ROOT:-$HOME/dev/coreboot}"
COREBOOT_BLOBS_GOOGLE="$COREBOOT_ROOT/3rdparty/blobs/mainboard/google"

declare -A BOARD_BRANCH BOARD_DEPS BOARD_BLOB_PREFIX

# EC branch includes the "-main" suffix used by platform/ec. The deps
# branch is the manifest revision for third_party/zephyr and cmsis.
register_board() {
	local board="$1" ec_branch="$2" deps_branch="$3" blob_prefix="$4"
	BOARD_BRANCH[$board]="$ec_branch"
	BOARD_DEPS[$board]="$deps_branch"
	BOARD_BLOB_PREFIX[$board]="$blob_prefix"
}

# Rex (Meteor Lake) boards we ship. The rex reference project is not one
# of them. firmware-ec-R136-16238.2.B-main contains upstream
# stabilize-15964.9.B and adds kanix.
REX_BRANCH="firmware-ec-R136-16238.2.B-main"
REX_DEPS="firmware-ec-R136-16238.2.B"
for b in screebo karis kanix; do
	register_board "$b" "$REX_BRANCH" "$REX_DEPS" rex
done
REX_BOARDS=(screebo karis kanix)

usage() {
	cat <<EOF
Usage: $0 [--no-sync] [--copy] [--log] [--branch EC_BRANCH] <board|rex> [...]

  --no-sync          Build at current HEAD (do not checkout the EC branch);
                     Zephyr/CMSIS deps follow the current branch tip
  --copy             Install ec.RW.flat into coreboot blobs
  --log              Tee output to logs/zephyr-YYYYMMDD-HHMMSS.log (or \$LOG_FILE)
  --branch BRANCH    EC branch for an unregistered zmake project. Zephyr and
                     CMSIS use the same name with a trailing -main removed.

Registered boards:
  rex    ${REX_BOARDS[*]}   ($REX_BRANCH)

Image: $IMAGE
Deps:  $DEPS_ROOT/<zephyr-branch>/{zephyr,cmsis}

Output: \$EC_ROOT/build/zephyr/<board>/output/{ec.bin,ec.RW.flat}
EOF
}

board_known() {
	[[ -n "${BOARD_BRANCH[$1]:-}" ]]
}

# Zephyr/CMSIS track the ChromiumOS manifest branch (ends in .B). EC trees
# append -main, and local test branches may add another suffix
# (e.g. stabilize-15964.9.B-timeout → stabilize-15964.9.B).
deps_branch_for_ec_branch() {
	local ec_branch="$1"
	if [[ "$ec_branch" =~ ^(.*\.B)(-|$) ]]; then
		printf '%s\n' "${BASH_REMATCH[1]}"
	elif [[ "$ec_branch" == *-main ]]; then
		echo "${ec_branch%-main}"
	else
		echo "$ec_branch"
	fi
}

ensure_image() {
	if docker image inspect "$IMAGE" >/dev/null 2>&1; then
		return 0
	fi
	echo "$0: building $IMAGE"
	docker build -t "$IMAGE" -f "$DOCKERFILE" "$(dirname "$DOCKERFILE")"
}

checkout_ec_branch() {
	local branch="$1"
	if ! git -C "$EC_ROOT" rev-parse --verify "$branch" >/dev/null 2>&1; then
		echo "$0: missing local branch $branch in $EC_ROOT" >&2
		exit 1
	fi
	local sha
	sha="$(git -C "$EC_ROOT" rev-parse --short "$branch")"
	echo "$0: checkout $branch ($sha) in $EC_ROOT"
	git -C "$EC_ROOT" checkout "$branch"
}

# Cache a single ChromiumOS repo at a branch tip. The directory is keyed by
# the branch name, so two firmware branches do not share a worktree.
ensure_git_dep() {
	local url="$1" ref="$2" dest="$3"
	mkdir -p "$(dirname "$dest")"
	if [[ ! -d "$dest/.git" ]]; then
		echo "$0: cloning $url ($ref)" >&2
		git clone --filter=blob:none --single-branch --branch "$ref" "$url" "$dest"
		return 0
	fi
	echo "$0: updating $dest to $ref" >&2
	git -C "$dest" fetch --filter=blob:none origin "$ref"
	git -C "$dest" -c advice.detachedHead=false checkout -f FETCH_HEAD
}

ensure_deps() {
	local deps_branch="$1"
	local root="$DEPS_ROOT/$deps_branch"
	ensure_git_dep "$ZEPHYR_URL" "$deps_branch" "$root/zephyr"
	ensure_git_dep "$CMSIS_URL" "$deps_branch" "$root/cmsis"
	printf '%s\n' "$root"
}

blobs_ec_rw_dest() {
	local board="$1"
	local existing prefix

	if [[ ! -d "$COREBOOT_BLOBS_GOOGLE" ]]; then
		echo "$0: COREBOOT_BLOBS_GOOGLE missing: $COREBOOT_BLOBS_GOOGLE" >&2
		return 1
	fi

	existing="$(find "$COREBOOT_BLOBS_GOOGLE" -type f -path "*/${board}/ec.RW.flat" 2>/dev/null | head -n 1)"
	if [[ -n "$existing" ]]; then
		echo "$existing"
		return 0
	fi

	prefix="${BOARD_BLOB_PREFIX[$board]:-}"
	if [[ -z "$prefix" ]]; then
		echo "$0: no blob path for unregistered board '$board' (pass a board that already has ec.RW.flat, or copy it yourself)" >&2
		return 1
	fi
	if [[ "$prefix" == "$board" ]]; then
		echo "$COREBOOT_BLOBS_GOOGLE/$board/ec.RW.flat"
	else
		echo "$COREBOOT_BLOBS_GOOGLE/$prefix/$board/ec.RW.flat"
	fi
}

copy_ec_rw_flat() {
	local board="$1"
	local src="$EC_ROOT/build/zephyr/$board/output/ec.RW.flat"
	local dest

	[[ -f "$src" ]] || { echo "$0: --copy: missing $src" >&2; return 1; }
	dest="$(blobs_ec_rw_dest "$board")" || return 1
	mkdir -p "$(dirname "$dest")"
	cp -f "$src" "$dest"
	echo "$0: copied $src -> $dest"
}

build_board() {
	local board="$1"
	local ec_branch="$2"
	local deps_branch="$3"
	local deps_root rw_src out_dir zver fullver

	if [[ "$DO_SYNC" -eq 1 ]]; then
		checkout_ec_branch "$ec_branch"
	fi

	deps_root="$(ensure_deps "$deps_branch")"
	out_dir="$EC_ROOT/build/zephyr/$board/output"
	rw_src="$EC_ROOT/build/zephyr/$board/build-rw/zephyr/zephyr.bin"

	# Describe already carries the commit and dirty marker. --static
	# keeps zmake from appending a second -<hash>+.
	zver="$(git -C "$EC_ROOT" describe --tag --dirty)"
	fullver="${board}-${zver}"
	if ((${#fullver} > 31)); then
		echo "$0: version '$fullver' is ${#fullver} characters; the RW field keeps '${fullver:0:31}'" >&2
	fi
	echo "$0: BOARD=$board EC=$ec_branch DEPS=$deps_branch VERSION=$fullver IMAGE=$IMAGE"

	docker run --rm \
		-u "$(id -u):$(id -g)" \
		-e HOME=/home/builder \
		-e USER="$(id -un)" \
		--hostname "$(hostname)" \
		-v "$EC_ROOT:/work/src/platform/ec" \
		-v "$deps_root/zephyr:/work/src/third_party/zephyr/main:ro" \
		-v "$deps_root/cmsis:/work/src/third_party/zephyr/cmsis:ro" \
		-w /work/src/platform/ec \
		"$IMAGE" \
		zmake -j"$(nproc)" build --static -v "$zver" "$board"

	if [[ ! -f "$rw_src" ]]; then
		echo "$0: missing RW image $rw_src" >&2
		return 1
	fi
	mkdir -p "$out_dir"
	cp -f "$rw_src" "$out_dir/ec.RW.flat"
	echo "$0: $out_dir/ec.bin"
	echo "$0: $out_dir/ec.RW.flat"

	if [[ "$COPY_BLOBS" -eq 1 ]]; then
		copy_ec_rw_flat "$board"
	fi
}

# --- main --------------------------------------------------------------------

COPY_BLOBS=0
DO_SYNC=1
DO_LOG=0
EC_BRANCH_OVERRIDE=""
TARGETS=()

while [[ $# -gt 0 ]]; do
	case "$1" in
	--copy) COPY_BLOBS=1; shift ;;
	--no-sync) DO_SYNC=0; shift ;;
	--log) DO_LOG=1; shift ;;
	--branch)
		[[ $# -ge 2 ]] || { echo "$0: --branch needs a branch name" >&2; exit 1; }
		EC_BRANCH_OVERRIDE="$2"
		shift 2
		;;
	-h|--help) usage; exit 0 ;;
	-*)
		echo "$0: unknown option: $1" >&2
		usage >&2
		exit 1
		;;
	*)
		TARGETS+=("$1")
		shift
		;;
	esac
done

[[ ${#TARGETS[@]} -gt 0 ]] || { usage >&2; exit 1; }

if ! command -v docker >/dev/null 2>&1; then
	echo "$0: docker required" >&2
	exit 1
fi

if [[ ! -d "$EC_ROOT/.git" ]]; then
	echo "$0: Chrome EC tree not found at $EC_ROOT" >&2
	echo "$0: move or clone chrome-ec there, or set EC_ROOT" >&2
	exit 1
fi

if [[ "$DO_LOG" -eq 1 ]]; then
	mkdir -p "$SCRIPT_DIR/logs"
	LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/logs/zephyr-$(date +%Y%m%d-%H%M%S).log}"
	echo "$0: logging to $LOG_FILE"
	exec > >(tee -a "$LOG_FILE") 2>&1
fi

ensure_image

BOARDS=()
for target in "${TARGETS[@]}"; do
	case "$target" in
	rex) BOARDS+=("${REX_BOARDS[@]}") ;;
	*)   BOARDS+=("$target") ;;
	esac
done

for board in "${BOARDS[@]}"; do
	ec_branch=""
	deps_branch=""
	if [[ "$DO_SYNC" -eq 0 ]]; then
		# Keep the working tree as-is; pair Zephyr with this tip.
		ec_branch="$(git -C "$EC_ROOT" rev-parse --abbrev-ref HEAD)"
		if [[ "$ec_branch" == HEAD ]]; then
			ec_branch="$(git -C "$EC_ROOT" describe --tags --always)"
		fi
		deps_branch="$(deps_branch_for_ec_branch "$ec_branch")"
	elif [[ -n "$EC_BRANCH_OVERRIDE" ]]; then
		ec_branch="$EC_BRANCH_OVERRIDE"
		deps_branch="$(deps_branch_for_ec_branch "$ec_branch")"
	elif board_known "$board"; then
		ec_branch="${BOARD_BRANCH[$board]}"
		deps_branch="${BOARD_DEPS[$board]}"
	else
		echo "$0: unknown board '$board' (register it, or pass --branch)" >&2
		usage >&2
		exit 1
	fi
	build_board "$board" "$ec_branch" "$deps_branch"
done
