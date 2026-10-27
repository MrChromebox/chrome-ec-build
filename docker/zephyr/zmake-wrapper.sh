#!/bin/bash
# Run zmake from the mounted EC checkout, defaulting to the Zephyr SDK
# toolchain (zmake would otherwise pick coreboot-sdk, which isn't installed).
set -e

args=()
have_toolchain=0
for arg in "$@"; do
	case "$arg" in
	-t | --toolchain | --toolchain=*) have_toolchain=1 ;;
	esac
done

inserted=0
for arg in "$@"; do
	args+=("$arg")
	if [[ $inserted -eq 0 && $have_toolchain -eq 0 &&
		("$arg" == build || "$arg" == configure) ]]; then
		args+=(-t zephyr)
		inserted=1
	fi
done

export PYTHONPATH="/work/src/platform/ec/zephyr/zmake${PYTHONPATH:+:$PYTHONPATH}"
exec python3 -m zmake "${args[@]}"
