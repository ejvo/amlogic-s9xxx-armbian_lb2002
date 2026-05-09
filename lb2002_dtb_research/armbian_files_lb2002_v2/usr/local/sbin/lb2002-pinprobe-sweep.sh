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

# Candidate map corrected by the current "-1" measurement hypothesis:
# GPIOX_0..5 match the standard G12A SDIO mux once the sweep shift is applied.
# Auxiliary candidates are kept separate for WCN control and IRQ validation.
run_one "SDIO_D0_GPIOX_0" 64
run_one "SDIO_D1_GPIOX_1" 65
run_one "SDIO_D2_GPIOX_2" 66
run_one "SDIO_D3_GPIOX_3" 67
run_one "SDIO_CLK_GPIOX_4" 68
run_one "SDIO_CMD_GPIOX_5" 69
run_one "WCN_CHIP_EN_GPIOX_6" 70
run_one "WCN_RST_N_GPIOX_17" 81
run_one "WCN_INT_GPIOX_18" 82
