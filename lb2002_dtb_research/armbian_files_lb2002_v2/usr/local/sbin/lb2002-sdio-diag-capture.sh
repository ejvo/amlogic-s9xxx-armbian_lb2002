#!/bin/sh
set -eu

OUTDIR="${1:-/tmp/lb2002-sdio-diag-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "${OUTDIR}"

capture() {
  name="$1"
  shift
  "$@" > "${OUTDIR}/${name}.txt" 2>&1 || true
}

capture uname uname -a
capture cmdline cat /proc/cmdline
capture lsmod lsmod
capture gpioinfo gpioinfo
capture dmesg dmesg
capture dmesg_filtered sh -c "dmesg | grep -Ei 'mmc|sdio|sprd|unisoc|wcn|uwe|wifi|bt'"
capture sysfs_sdio sh -c "find /sys/bus/sdio -maxdepth 4 -type f | sort | xargs -r sed -n '1,40p'"
capture debug_gpio cat /sys/kernel/debug/gpio
capture debug_mmc_tree sh -c "find /sys/kernel/debug -maxdepth 2 \\( -name 'mmc*' -o -name 'sdio*' \\) -print"
capture mmc_ios sh -c "find /sys/kernel/debug -path '*/mmc*/ios' -type f -print -exec cat {} \\;"

echo "${OUTDIR}"
