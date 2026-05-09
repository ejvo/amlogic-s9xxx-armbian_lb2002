#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "usage: $0 <gpio-line> [period_ms]" >&2
  exit 1
fi

LINE="$1"
PERIOD_MS="${2:-250}"
CHIP="${GPIOCHIP:-gpiochip0}"
HALF_SEC="$(awk "BEGIN { printf \"%.3f\", ${PERIOD_MS} / 2000 }")"

cleanup() {
  gpioset "${CHIP}" "${LINE}=0" >/dev/null 2>&1 || true
}

trap cleanup INT TERM EXIT

echo "pinprobe: chip=${CHIP} line=${LINE} period_ms=${PERIOD_MS}"
echo "ctrl-c to stop"

while true; do
  gpioset "${CHIP}" "${LINE}=1"
  sleep "${HALF_SEC}"
  gpioset "${CHIP}" "${LINE}=0"
  sleep "${HALF_SEC}"
done
