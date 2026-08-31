#!/bin/bash
#
# Build Chrome EC firmware in a pinned Docker image (host toolchain irrelevant).
#
# Scope: Chrome EC boards from Link (2013) through Brask (see generations below).
# Checks out the matching local firmware branch before building.
#
# Layout: this script lives in chrome-ec-build/; the firmware tree is expected at
#   chrome-ec-build/chrome-ec/   (gitignored clone — not part of this repo)
# Override with EC_ROOT=/path/to/chrome-ec if needed.
#
# Usage:
#   ./build-docker.sh [--no-sync] [--copy] [--full] <board|...>
#
# Builds RW firmware (ec.RW.flat) by default — what coreboot consumes.
# Use --full for ec.bin (RO + RW combined image).
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EC_ROOT="${EC_ROOT:-$SCRIPT_DIR/chrome-ec}"

IMAGE_XENIAL="${EC_IMAGE_XENIAL:-chrome-ec-xenial:u16}"
IMAGE_FOCAL="${EC_IMAGE_FOCAL:-chrome-ec-focal:u20}"
IMAGE_COREBOOT_SDK="${EC_IMAGE_COREBOOT_SDK:-coreboot/coreboot-sdk:2024-12-21_306660c2de}"

declare -A BOARD_BRANCH BOARD_BLOB_PREFIX BOARD_IMAGE BOARD_TOOLCHAIN BOARD_LEGACY BOARD_MAKE_EXTRA IMAGE_DOCKERFILE

# Pre-gcc5 trees use CFLAGS_WARN (not COMMON_WARN) and hard-code -Werror.
BRASWELL_CFLAGS_WARN='CFLAGS_WARN=-Wall -Wundef -Wno-error -Wno-maybe-uninitialized -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow'

IMAGE_DOCKERFILE[$IMAGE_XENIAL]="$SCRIPT_DIR/docker/xenial/Dockerfile"
IMAGE_DOCKERFILE[$IMAGE_FOCAL]="$SCRIPT_DIR/docker/focal/Dockerfile"

register_board() {
	local board="$1" branch="$2" blob_prefix="$3" image="${4:-$IMAGE_XENIAL}"
	local toolchain="${5:-arm}"
	local flags="${6:-}"
	BOARD_BRANCH[$board]="$branch"
	BOARD_BLOB_PREFIX[$board]="$blob_prefix"
	BOARD_IMAGE[$board]="$image"
	BOARD_TOOLCHAIN[$board]="$toolchain"
	case "$flags" in
	legacy)
		BOARD_LEGACY[$board]=1
		;;
	braswell)
		BOARD_LEGACY[$board]=1
		BOARD_MAKE_EXTRA[$board]="$BRASWELL_CFLAGS_WARN"
		;;
	esac
}

register_legacy_board() {
	register_board "$1" "$2" "$3" "${4:-$IMAGE_XENIAL}" arm legacy
}

register_braswell_board() {
	register_board "$1" "$2" cyan "$IMAGE_XENIAL" arm braswell
}

image_for_board() {
	echo "${BOARD_IMAGE[$1]:-$IMAGE_XENIAL}"
}

toolchain_for_board() {
	echo "${BOARD_TOOLCHAIN[$1]:-arm}"
}

COREBOOT_ROOT="${COREBOOT_ROOT:-$HOME/dev/coreboot}"
COREBOOT_BLOBS_GOOGLE="$COREBOOT_ROOT/3rdparty/blobs/mainboard/google"

# --- Link (LM4, 2013) --------------------------------------------------------
# Do not build Link with this Docker script. Ubuntu/host gcc-arm-none-eabi and
# other non-CrOS toolchains produce RW images that boot-loop (brick) on Link.
# Build only in a Chrome OS chroot with cross-arm-none-eabi gcc-4.9.2-r170
# (cros_sdk, then: make BOARD=link → build/link/ec.RW.flat).
LINK_BRANCH="firmware-link-2695.B"
BOARD_BRANCH[link]="$LINK_BRANCH"
BOARD_BLOB_PREFIX[link]=link

# --- Haswell (LM4, 2014) -----------------------------------------------------
FALCO_PEPPY_BRANCH="firmware-falco_peppy-4389.B"
register_legacy_board falco "$FALCO_PEPPY_BRANCH" slippy
register_legacy_board peppy "$FALCO_PEPPY_BRANCH" slippy
register_legacy_board wolf "firmware-wolf-4389.24.B" slippy
register_legacy_board leon "firmware-leon-4389.61.B" slippy

# --- Baytrail (LM4, 2014–2015), per-board branches ---------------------------
register_legacy_board banjo "firmware-banjo-5216.334.B" rambi
register_legacy_board candy "firmware-candy-5216.310.B" rambi
register_legacy_board clapper "firmware-clapper-5216.199.B" rambi
register_legacy_board enguarde "firmware-enguarde-5216.201.B" rambi
register_legacy_board expresso "firmware-expresso-5216.223.B" rambi
register_legacy_board glimmer "firmware-glimmer-5216.198.B" rambi
register_legacy_board gnawty "firmware-gnawty-5216.239.B" rambi
register_legacy_board heli "firmware-heli-5216.392.B" rambi
register_legacy_board kip "firmware-kip-5216.227.B" rambi
register_legacy_board ninja "firmware-ninja-5216.383.B" rambi
register_legacy_board orco "firmware-orco-5216.362.B" rambi
register_legacy_board quawks "firmware-quawks-5216.204.B" rambi
register_legacy_board squawks "firmware-squawks-5216.152.B" rambi
register_legacy_board sumo "firmware-sumo-5216.382.B" rambi
register_legacy_board swanky "firmware-swanky-5216.238.B" rambi
register_legacy_board winky "firmware-winky-5216.265.B" rambi

# --- Broadwell (LM4, 2015) ---------------------------------------------------
register_legacy_board buddy "firmware-buddy-6301.202.B" auron
register_legacy_board gandof "firmware-gandof-6301.155.B" auron
register_legacy_board lulu "firmware-lulu-6301.136.B" auron
register_legacy_board paine "firmware-paine-6301.58.B" auron
register_legacy_board samus "firmware-samus-6300.B" auron
register_legacy_board yuna "firmware-yuna-6301.59.B" auron

# --- Braswell (MEC1322, 2016), per-board branches ----------------------------
STRAGO_BRANCH="firmware-strago-7287.B"
register_braswell_board celes "firmware-celes-7287.92.B"
register_braswell_board cyan "firmware-cyan-7287.57.B"
register_braswell_board edgar "firmware-edgar-7287.167.B"
register_braswell_board reks "firmware-reks-7287.133.B"
register_braswell_board terra "firmware-terra-7287.154.B"
register_braswell_board ultima "firmware-ultima-7287.131.B"
# No local per-board firmware branches; build from consolidated strago tree.
for b in banon kefka relm setzer wizpig; do
	register_braswell_board "$b" "$STRAGO_BRANCH"
done

# --- Skylake (MEC1322, 2016–2017) → firmware-glados-7820.B -------------------
GLADOS_BRANCH="firmware-glados-7820.B"
for b in asuka caroline cave chell lars sentry; do
	register_board "$b" "$GLADOS_BRANCH" glados
done

# --- Apollolake (NPCX, 2017) -------------------------------------------------
register_board coral "firmware-coral-10068.B" coral
for b in reef pyro sand snappy nasher; do
	register_board "$b" "firmware-reef-9042.B" reef
done

# --- Kabylake (NPCX, 2017–2018) ----------------------------------------------
register_board eve "firmware-eve-9584.B" eve
register_board nami "firmware-nami-10775.B" poppy
register_board nocturne "firmware-nocturne-10984.B" poppy
register_board atlas "firmware-atlas-11827.B" poppy
register_board fizz "firmware-fizz-10139.B" fizz
register_board karma "firmware-kalista-11343.B" fizz
register_board endeavour "firmware-endeavour-13259.B-master" fizz
register_board rammus "firmware-rammus-11275.B" poppy
for b in nautilus soraka; do
	register_board "$b" "firmware-poppy-10431.B" poppy
done

# --- Grunt (AMD Stoney, 2018) → firmware-grunt-11031.B -----------------------
GRUNT_BRANCH="firmware-grunt-11031.B"
for b in aleena careena grunt liara treeya; do
	register_board "$b" "$GRUNT_BRANCH" kahlee
done

# --- Octopus (Gemini Lake, 2018–2019) → firmware-octopus-11297.B -------------
OCTOPUS_BRANCH="firmware-octopus-11297.B"
register_board ampton "$OCTOPUS_BRANCH" octopus "$IMAGE_COREBOOT_SDK" nds32
for b in bloog bobba casta dood fleex foob garg lick meep phaser yorp; do
	register_board "$b" "$OCTOPUS_BRANCH" octopus "$IMAGE_FOCAL"
done

# --- Hatch (Comet Lake, 2019–2020) → firmware-hatch-12672.B ------------------
HATCH_BRANCH="firmware-hatch-12672.B"
for b in akemi dratini helios jinlon kindred kohaku nightfury; do
	register_board "$b" "$HATCH_BRANCH" hatch "$IMAGE_FOCAL"
done

# --- Puff (Comet Lake, 2020) → firmware-puff-13324.B-master ------------------
PUFF_BRANCH="firmware-puff-13324.B-master"
for b in ambassador dooly genesis moonbuggy puff scout; do
	register_board "$b" "$PUFF_BRANCH" puff "$IMAGE_FOCAL"
done

# --- Zork (AMD Picasso, 2020) → firmware-zork-13434.B-master -----------------
ZORK_BRANCH="firmware-zork-13434.B-master"
for b in berknip dirinboz ezkinil gumboz morphius shuboz vilboz woomax; do
	register_board "$b" "$ZORK_BRANCH" zork "$IMAGE_FOCAL"
done

# --- Dedede (Jasper Lake, 2020–2021) → firmware-dedede-13606.B-master ---------
# Boards present on the firmware branch and in coreboot google/dedede blobs.
DEDEDE_BRANCH="firmware-dedede-13606.B-master"
for b in bugzzy cret madoo magolor metaknight sasuke waddledoo; do
	register_board "$b" "$DEDEDE_BRANCH" dedede "$IMAGE_FOCAL"
done
for b in awasuki beadrix beetley blipper boten boxy dexi dibbi dita drawcia galtic kracko lantis pirika sasukette storo taranza waddledee; do
	register_board "$b" "$DEDEDE_BRANCH" dedede "$IMAGE_COREBOOT_SDK" nds32
done

# --- Volteer (Tiger Lake, 2020–2021) → firmware-volteer-13672.B-main ----------
VOLTEER_BRANCH="firmware-volteer-13672.B-main"
for b in chronicler collis copano delbin drobit eldrid elemi lindar voema volet voxel; do
	register_board "$b" "$VOLTEER_BRANCH" volteer "$IMAGE_FOCAL"
done

# --- Brya (Alder Lake, 2022) → firmware-ec-R136-16238.2.B-main ----------------
BRYA_BRANCH="firmware-ec-R136-16238.2.B-main"
for b in anahera banshee brya crota dochi felwinter gimble kano marasov mithrax omnigul osiris primus redrix taeko taniks vell volmar xol; do
	register_board "$b" "$BRYA_BRANCH" brya/brya "$IMAGE_COREBOOT_SDK" sdk-arm
done

# --- Brask (Alder Lake-N, 2022–2023) → firmware-android-brya-14505.885.B-main --
BRASK_BRANCH="firmware-android-brya-14505.885.B-main"
for b in aurash brask bujia constitution gaelin gladios kinox kuldax lisbon moli moxie nova; do
	register_board "$b" "$BRASK_BRANCH" brya/brask "$IMAGE_COREBOOT_SDK" sdk-arm
done

LINK_BOARDS=(link)
HASWELL_BOARDS=(falco leon peppy wolf)
BAYTRAIL_BOARDS=(banjo candy clapper enguarde expresso glimmer gnawty heli kip ninja orco quawks squawks sumo swanky winky)
BROADWELL_BOARDS=(buddy gandof lulu paine samus yuna)
BRASWELL_BOARDS=(banon celes cyan edgar kefka reks relm setzer terra ultima wizpig)
SKYLAKE_BOARDS=(asuka caroline cave chell lars sentry)
APOLLOLAKE_BOARDS=(coral pyro reef sand snappy)
KABYLAKE_BOARDS=(atlas endeavour fizz karma nautilus nami nocturne rammus soraka)
GRUNT_BOARDS=(aleena careena grunt liara treeya)
OCTOPUS_BOARDS=(ampton bloog bobba casta dood fleex foob garg lick meep phaser yorp)
HATCH_BOARDS=(akemi dratini helios jinlon kindred kohaku nightfury)
PUFF_BOARDS=(ambassador dooly genesis moonbuggy puff scout)
ZORK_BOARDS=(berknip dirinboz ezkinil gumboz morphius shuboz vilboz woomax)
DEDEDE_BOARDS=(awasuki beadrix beetley blipper boten boxy bugzzy cret dexi dibbi dita drawcia galtic kracko lantis madoo magolor metaknight pirika sasuke sasukette storo taranza waddledee waddledoo)
VOLTEER_BOARDS=(chronicler collis copano delbin drobit eldrid elemi lindar voema volet voxel)
BRYA_BOARDS=(anahera banshee brya crota dochi felwinter gimble kano marasov mithrax omnigul osiris primus redrix taeko taniks vell volmar xol)
BRASK_BOARDS=(aurash brask bujia constitution gaelin gladios kinox kuldax lisbon moli moxie nova)

usage() {
	cat <<EOF
Usage: $0 [--no-sync] [--copy] [--full] <board|link|haswell|baytrail|broadwell|braswell|skylake|apollolake|kabylake|grunt|octopus|hatch|puff|zork|dedede|volteer|brya|brask>

  --no-sync   Build at current HEAD (do not checkout firmware branch)
  --copy      Install build/<board>/RW/ec.RW.flat into coreboot blobs
  --full      Build ec.bin (RO + RW) instead of RW-only ec.RW.flat

Docker images:
  xenial ($IMAGE_XENIAL)       haswell, baytrail, broadwell, braswell, skylake, apollolake, kabylake, grunt
  focal  ($IMAGE_FOCAL)        octopus (NPCX/ARM), hatch, puff, zork, dedede (NPCX), volteer
  sdk    ($IMAGE_COREBOOT_SDK) octopus/ampton + dedede IT83xx (NDS32), brya, brask
Git ref: local firmware branch

  link is NOT built here — Chrome OS chroot only (standard toolchains brick Link)

Generations (oldest first):
  link         ${LINK_BOARDS[*]}  (chroot only; this script refuses)
  haswell      ${HASWELL_BOARDS[*]}
  baytrail     ${BAYTRAIL_BOARDS[*]}
  broadwell    ${BROADWELL_BOARDS[*]}
  braswell     ${BRASWELL_BOARDS[*]}
  skylake      ${SKYLAKE_BOARDS[*]}
  apollolake   ${APOLLOLAKE_BOARDS[*]}
  kabylake     ${KABYLAKE_BOARDS[*]}
  grunt        ${GRUNT_BOARDS[*]}
  octopus      ${OCTOPUS_BOARDS[*]}
  hatch        ${HATCH_BOARDS[*]}
  puff         ${PUFF_BOARDS[*]}
  zork         ${ZORK_BOARDS[*]}
  dedede       ${DEDEDE_BOARDS[*]}
  volteer      ${VOLTEER_BOARDS[*]}
  brya         ${BRYA_BOARDS[*]}
  brask        ${BRASK_BOARDS[*]}
EOF
}

make_target_for_board() {
	local board="$1"
	if [[ "$BUILD_FULL" -eq 1 ]]; then
		echo "build/$board/ec.bin"
	elif [[ -n "${BOARD_LEGACY[$board]:-}${BOARD_MAKE_EXTRA[$board]:-}" ]]; then
		echo "build/$board/RW/ec.RW.elf"
	else
		echo "build/$board/RW/ec.RW.elf build/$board/RW/ec.RW.smap"
	fi
}

flat_output_for_board() {
	local board="$1"
	echo "build/$board/RW/ec.RW.flat"
}

ensure_image() {
	local image="$1"
	local dockerfile="${IMAGE_DOCKERFILE[$image]:-}"

	if docker image inspect "$image" >/dev/null 2>&1; then
		return 0
	fi
	if ! command -v docker >/dev/null 2>&1; then
		echo "$0: docker required" >&2
		exit 1
	fi
	if [[ -z "$dockerfile" || ! -f "$dockerfile" ]]; then
		if ! command -v docker >/dev/null 2>&1; then
			echo "$0: docker required" >&2
			exit 1
		fi
		echo "$0: pulling $image"
		docker pull "$image"
		return 0
	fi
	echo "$0: building $image from $dockerfile"
	docker build -t "$image" -f "$dockerfile" "$(dirname "$dockerfile")"
}

checkout_branch() {
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

board_known() {
	[[ -n "${BOARD_BRANCH[$1]:-}" ]]
}

resolve_boards() {
	local target="$1"
	case "$target" in
	link)         printf '%s\n' "${LINK_BOARDS[@]}" ;;
	haswell)      printf '%s\n' "${HASWELL_BOARDS[@]}" ;;
	baytrail)     printf '%s\n' "${BAYTRAIL_BOARDS[@]}" ;;
	broadwell)    printf '%s\n' "${BROADWELL_BOARDS[@]}" ;;
	braswell)     printf '%s\n' "${BRASWELL_BOARDS[@]}" ;;
	skylake)      printf '%s\n' "${SKYLAKE_BOARDS[@]}" ;;
	apollolake)   printf '%s\n' "${APOLLOLAKE_BOARDS[@]}" ;;
	kabylake)     printf '%s\n' "${KABYLAKE_BOARDS[@]}" ;;
	grunt)        printf '%s\n' "${GRUNT_BOARDS[@]}" ;;
	octopus)      printf '%s\n' "${OCTOPUS_BOARDS[@]}" ;;
	hatch)        printf '%s\n' "${HATCH_BOARDS[@]}" ;;
	puff)         printf '%s\n' "${PUFF_BOARDS[@]}" ;;
	zork)         printf '%s\n' "${ZORK_BOARDS[@]}" ;;
	dedede)       printf '%s\n' "${DEDEDE_BOARDS[@]}" ;;
	volteer)      printf '%s\n' "${VOLTEER_BOARDS[@]}" ;;
	brya)         printf '%s\n' "${BRYA_BOARDS[@]}" ;;
	brask)        printf '%s\n' "${BRASK_BOARDS[@]}" ;;
	*)
		if board_known "$target"; then
			echo "$target"
		else
			echo "$0: unknown board or generation '$target'" >&2
			usage >&2
			exit 1
		fi
		;;
	esac
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

	prefix="${BOARD_BLOB_PREFIX[$board]}"
	if [[ "$prefix" == "$board" ]]; then
		echo "$COREBOOT_BLOBS_GOOGLE/$board/ec.RW.flat"
	else
		echo "$COREBOOT_BLOBS_GOOGLE/$prefix/$board/ec.RW.flat"
	fi
}

copy_ec_rw_flat() {
	local board="$1"
	local src="$EC_ROOT/build/$board/RW/ec.RW.flat"
	local dest

	[[ -f "$src" ]] || { echo "$0: --copy: missing $src" >&2; return 1; }
	dest="$(blobs_ec_rw_dest "$board")" || return 1
	mkdir -p "$(dirname "$dest")"
	cp -f "$src" "$dest"
	echo "$0: copied $src -> $dest"
}

docker_build_board() {
	local board="$1"
	local branch="${BOARD_BRANCH[$board]}"
	local image target flat toolchain legacy board_extra
	local make_cross make_host make_warn objcopy docker_path
	local make_warn_arg='' board_extra_arg='' legacy=0

	image="$(image_for_board "$board")"
	toolchain="$(toolchain_for_board "$board")"
	target="$(make_target_for_board "$board")"
	flat="$(flat_output_for_board "$board")"
	legacy="${BOARD_LEGACY[$board]:-0}"
	board_extra="${BOARD_MAKE_EXTRA[$board]:-}"

	case "$toolchain" in
	nds32)
		docker_path='export PATH=/opt/xgcc/bin:$PATH; export CCACHE_DISABLE=1'
		make_cross='COREBOOT_SDK_ROOT_nds32=/opt/xgcc CROSS_COMPILE_nds32=/opt/xgcc/bin/nds32le-elf- CROSS_COMPILE=/opt/xgcc/bin/nds32le-elf-'
		make_host='BUILDCC=gcc BUILDCC_PREFIX='
		make_warn='COMMON_WARN=-Wall -Wundef -Wno-error -Werror-implicit-function-declaration -Wno-trigraphs -Wno-format-security -Wno-address-of-packed-member -fno-common -fno-strict-aliasing -fno-strict-overflow'
		objcopy='/opt/xgcc/bin/nds32le-elf-objcopy'
		;;
	sdk-arm)
		docker_path='export PATH=/opt/xgcc/bin:$PATH; export CCACHE_DISABLE=1'
		make_cross='COREBOOT_SDK_ROOT_arm=/opt/xgcc CROSS_COMPILE=/opt/xgcc/bin/arm-eabi-'
		make_host='BUILDCC=gcc BUILDCC_PREFIX='
		make_warn='COMMON_WARN=-Wall -Wundef -Wno-error -Werror-implicit-function-declaration -Wno-trigraphs -Wno-format-security -Wno-address-of-packed-member -fno-common -fno-strict-aliasing -fno-strict-overflow'
		objcopy='/opt/xgcc/bin/arm-eabi-objcopy'
		;;
	*)
		docker_path=''
		make_cross='CROSS_COMPILE=arm-none-eabi-'
		make_host=''
		make_warn=''
		objcopy='arm-none-eabi-objcopy'
		;;
	esac
	[[ -n "$make_warn" ]] && make_warn_arg="'$make_warn'"
	[[ -n "$board_extra" ]] && board_extra_arg="'$board_extra'"

	ensure_image "$image"

	if [[ "$BUILD_FULL" -eq 1 ]]; then
		echo "$0: BOARD=$board BRANCH=$branch TARGET=$target IMAGE=$image TOOLCHAIN=$toolchain"
	else
		echo "$0: BOARD=$board BRANCH=$branch TARGET=$flat IMAGE=$image TOOLCHAIN=$toolchain"
	fi

	docker run --rm \
		-u "$(id -u):$(id -g)" \
		-v "$EC_ROOT:/src:rw" \
		-w /src \
		"$image" \
		bash -lc "
			set -euo pipefail
			$docker_path
			flat_from_elf() {
				$objcopy --set-section-flags .roshared=share \
					-O binary \"\$1\" \"\$2\"
			}
			if [[ $legacy -eq 1 ]]; then
				rm -rf build/$board
				mkdir -p build/$board/RW build/$board/RO
			else
				make BOARD=$board $make_cross clean
			fi
			if [[ $BUILD_FULL -eq 1 ]]; then
				make -j\"\$(nproc)\" BOARD=$board $make_host $make_cross PEM= $board_extra_arg $make_warn_arg \
					build/$board/RO/ec.RO.elf build/$board/RO/ec.RO.smap \
					build/$board/RW/ec.RW.elf build/$board/RW/ec.RW.smap
				flat_from_elf build/$board/RO/ec.RO.elf build/$board/RO/ec.RO.flat
				flat_from_elf build/$board/RW/ec.RW.elf build/$board/RW/ec.RW.flat
				make -j\"\$(nproc)\" BOARD=$board $make_host $make_cross PEM= $board_extra_arg $make_warn_arg \
					$target
			else
				make -j\"\$(nproc)\" BOARD=$board $make_host $make_cross PEM= $board_extra_arg $make_warn_arg \
					$target
				flat_from_elf build/$board/RW/ec.RW.elf $flat
			fi
		"
}

build_board() {
	local board="$1"
	local branch="${BOARD_BRANCH[$board]}"

	if [[ "$board" == "link" ]]; then
		cat >&2 <<EOF
$0: refusing to build link in Docker.

Link EC must be built in a Chrome OS chroot with the CrOS
cross-arm-none-eabi gcc-4.9.2-r170 toolchain. Images from
Ubuntu/host gcc-arm-none-eabi (and similar) boot-loop and can
brick the device.

  cros_sdk
  cd /path/to/chrome-ec && git checkout $LINK_BRANCH
  make BOARD=link
  # install: build/link/ec.RW.flat
EOF
		exit 1
	fi

	if [[ "$DO_SYNC" -eq 1 ]]; then
		checkout_branch "$branch"
	fi

	docker_build_board "$board"

	if [[ "$COPY_BLOBS" -eq 1 ]]; then
		copy_ec_rw_flat "$board"
	fi
}

# --- main --------------------------------------------------------------------

COPY_BLOBS=0
BUILD_FULL=0
DO_SYNC=1
TARGET=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--copy)     COPY_BLOBS=1; shift ;;
	--full)     BUILD_FULL=1; shift ;;
	--no-sync)  DO_SYNC=0; shift ;;
	-h|--help) usage; exit 0 ;;
	-*)
		echo "$0: unknown option: $1" >&2
		usage >&2
		exit 1
		;;
	*)
		[[ -z "$TARGET" ]] || { usage >&2; exit 1; }
		TARGET="$1"
		shift
		;;
	esac
done

[[ -n "$TARGET" ]] || { usage >&2; exit 1; }

if ! command -v docker >/dev/null 2>&1; then
	echo "$0: docker required" >&2
	exit 1
fi

if [[ ! -d "$EC_ROOT/.git" ]]; then
	echo "$0: Chrome EC tree not found at $EC_ROOT" >&2
	echo "$0: move or clone chrome-ec there, or set EC_ROOT" >&2
	exit 1
fi

mapfile -t BOARDS < <(resolve_boards "$TARGET")

for board in "${BOARDS[@]}"; do
	build_board "$board"
done
