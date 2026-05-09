#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root" >&2
  exit 1
fi

DURATION="${1:-8}"
PERIOD_MS="${2:-250}"

run_one() {
  name="$1"
  line="$2"
  echo
  echo "==== ${name} line=${line} duration=${DURATION}s period=${PERIOD_MS}ms ===="
  timeout "${DURATION}"s /usr/local/sbin/lb2002-pinprobe-wave.sh "${line}" "${PERIOD_MS}" || true
  sleep 1
}

# Candidate map derived from Android DT/runtime and mainline pinctrl:
# GPIOX_0..5 are inferred SDIO D0..D3/CLK/CMD.
# GPIOX_8/9/19 are confirmed auxiliary lines from Android:
#   0x48 -> 72 power_on
#   0x49 -> 73 irq
#   0x53 -> 83 reset
run_one "SDIO_D0_GPIOX_0" 64
run_one "SDIO_D1_GPIOX_1" 65
run_one "SDIO_D2_GPIOX_2" 66
run_one "SDIO_D3_GPIOX_3" 67
run_one "SDIO_CLK_GPIOX_4" 68
run_one "SDIO_CMD_GPIOX_5" 69
run_one "WIFI_POWER_ON_GPIOX_8" 72
run_one "WIFI_IRQ_GPIOX_9" 73
run_one "WCN_RESET_GPIOX_19" 83
