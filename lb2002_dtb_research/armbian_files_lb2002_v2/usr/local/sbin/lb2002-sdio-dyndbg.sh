#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root" >&2
  exit 1
fi

CTRL="/sys/kernel/debug/dynamic_debug/control"
if [ ! -e "${CTRL}" ]; then
  echo "dynamic debug control not available: ${CTRL}" >&2
  exit 1
fi

apply_rule() {
  rule="$1"
  printf '%s\n' "${rule}" >> "${CTRL}" || true
}

apply_rule 'file drivers/mmc/core/* +p'
apply_rule 'file drivers/mmc/host/* +p'
apply_rule 'module mmc_core +p'
apply_rule 'module meson_mx_sdio +p'
apply_rule 'module meson_gx_mmc +p'
apply_rule 'module sprdwl_ng +p'
apply_rule 'module sprdbt_tty +p'

echo "dynamic debug rules applied"
