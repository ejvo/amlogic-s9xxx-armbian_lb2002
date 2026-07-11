#!/bin/sh
set -eu

GREEN_LED="${GREEN_LED:-remote_led}"
RED_LED="${RED_LED:-power_led}"
HMI_SERVICE="${HMI_SERVICE:-}"
CHECK_INTERVAL_SEC="${CHECK_INTERVAL_SEC:-5}"
ROOTFS_WARN_PCT="${ROOTFS_WARN_PCT:-85}"
ROOTFS_CRIT_PCT="${ROOTFS_CRIT_PCT:-95}"
TEMP_WARN_MILLIC="${TEMP_WARN_MILLIC:-70000}"
TEMP_CRIT_MILLIC="${TEMP_CRIT_MILLIC:-80000}"
LOAD_WARN_PER_CPU="${LOAD_WARN_PER_CPU:-2}"
LOAD_CRIT_PER_CPU="${LOAD_CRIT_PER_CPU:-4}"

LED_BASE=/sys/class/leds
GREEN_PATH="${LED_BASE}/${GREEN_LED}"
RED_PATH="${LED_BASE}/${RED_LED}"

log() {
    printf '%s cm311-status-leds: %s\n' "$(date -Is 2>/dev/null || date)" "$*" >&2
}

have_led() {
    [ -d "$1" ] && [ -w "$1/trigger" ] && [ -w "$1/brightness" ]
}

set_led_off() {
    led="$1"
    have_led "$led" || return 0
    printf 'none' > "$led/trigger" 2>/dev/null || true
    printf '0' > "$led/brightness" 2>/dev/null || true
}

set_led_on() {
    led="$1"
    have_led "$led" || return 0
    printf 'none' > "$led/trigger" 2>/dev/null || true
    printf '1' > "$led/brightness" 2>/dev/null || true
}

set_led_timer() {
    led="$1"
    on_ms="$2"
    off_ms="$3"
    have_led "$led" || return 0
    printf 'timer' > "$led/trigger" 2>/dev/null || return 0
    printf '%s' "$on_ms" > "$led/delay_on" 2>/dev/null || true
    printf '%s' "$off_ms" > "$led/delay_off" 2>/dev/null || true
}

set_state() {
    state="$1"
    case "$state" in
        ok)
            set_led_on "$GREEN_PATH"
            set_led_off "$RED_PATH"
            ;;
        warning)
            set_led_timer "$GREEN_PATH" 1000 1000
            set_led_timer "$RED_PATH" 250 1750
            ;;
        critical)
            set_led_off "$GREEN_PATH"
            set_led_timer "$RED_PATH" 250 250
            ;;
        *)
            set_led_timer "$GREEN_PATH" 250 250
            set_led_timer "$RED_PATH" 250 250
            ;;
    esac
}

rootfs_used_pct() {
    df -P / | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }'
}

max_temp_millic() {
    max=0
    for f in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$f" ] || continue
        t="$(cat "$f" 2>/dev/null || echo 0)"
        case "$t" in
            ''|*[!0-9-]*) t=0 ;;
        esac
        [ "$t" -gt "$max" ] && max="$t"
    done
    printf '%s\n' "$max"
}

cpu_count() {
    n="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
    case "$n" in
        ''|*[!0-9]*) n=1 ;;
    esac
    [ "$n" -gt 0 ] || n=1
    printf '%s\n' "$n"
}

load_scaled_100() {
    awk '{ split($1, a, "."); frac=a[2]; while (length(frac) < 2) frac=frac "0"; print (a[1] * 100) + substr(frac, 1, 2) }' /proc/loadavg
}

network_ok() {
    ip route show default 2>/dev/null | grep -q '^default '
}

rtc_ok() {
    for f in /sys/class/rtc/rtc*/name; do
        [ -r "$f" ] || continue
        grep -q 'rtc-ds1307' "$f" && return 0
        grep -q 'ds3231' "$f" && return 0
    done
    return 1
}

hmi_ok() {
    [ -n "$HMI_SERVICE" ] || return 0
    systemctl is-active --quiet "$HMI_SERVICE"
}

if ! have_led "$GREEN_PATH"; then
    log "missing green LED path: ${GREEN_PATH}"
fi
if ! have_led "$RED_PATH"; then
    log "missing red LED path: ${RED_PATH}"
fi

trap 'set_led_off "$GREEN_PATH"; set_led_off "$RED_PATH"; exit 0' INT TERM

set_state warning
last_state=
last_reasons=

while :; do
    state=ok
    reasons=

    root_pct="$(rootfs_used_pct 2>/dev/null || echo 0)"
    temp="$(max_temp_millic 2>/dev/null || echo 0)"
    cpus="$(cpu_count)"
    load100="$(load_scaled_100 2>/dev/null || echo 0)"
    warn_load100=$((cpus * LOAD_WARN_PER_CPU * 100))
    crit_load100=$((cpus * LOAD_CRIT_PER_CPU * 100))

    if [ "$root_pct" -ge "$ROOTFS_CRIT_PCT" ]; then
        state=critical
        reasons="${reasons} rootfs=${root_pct}%"
    elif [ "$root_pct" -ge "$ROOTFS_WARN_PCT" ] && [ "$state" = ok ]; then
        state=warning
        reasons="${reasons} rootfs=${root_pct}%"
    fi

    if [ "$temp" -ge "$TEMP_CRIT_MILLIC" ]; then
        state=critical
        reasons="${reasons} temp=${temp}"
    elif [ "$temp" -ge "$TEMP_WARN_MILLIC" ] && [ "$state" = ok ]; then
        state=warning
        reasons="${reasons} temp=${temp}"
    fi

    if [ "$load100" -ge "$crit_load100" ]; then
        state=critical
        reasons="${reasons} load100=${load100}"
    elif [ "$load100" -ge "$warn_load100" ] && [ "$state" = ok ]; then
        state=warning
        reasons="${reasons} load100=${load100}"
    fi

    if ! network_ok; then
        [ "$state" = ok ] && state=warning
        reasons="${reasons} no_default_route"
    fi

    if ! rtc_ok; then
        [ "$state" = ok ] && state=warning
        reasons="${reasons} no_ds3231_rtc"
    fi

    if ! hmi_ok; then
        state=critical
        reasons="${reasons} hmi_service=${HMI_SERVICE}"
    fi

    set_state "$state"
    if [ "$state" != "$last_state" ] || [ "$reasons" != "$last_reasons" ]; then
        log "state=${state}${reasons}"
        last_state="$state"
        last_reasons="$reasons"
    fi
    sleep "$CHECK_INTERVAL_SEC"
done
