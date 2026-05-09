#!/bin/sh
set -eu

PATTERN="${1:-mmc|sdio|sprd|unisoc|wcn|uwe|wifi|bt}"

echo "live kernel log filter: ${PATTERN}"
echo "ctrl-c to stop"
exec dmesg -w | grep -Ei "${PATTERN}"
