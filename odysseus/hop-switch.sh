#!/usr/bin/env bash
#
# ipv6-gw-failover.sh
#
# Route an IPv6 prefix through one of two link-local next-hops, switching
# automatically depending on which gateway answers ping. This is for a
# *subnet* route (the /62), NOT the default/internet route.
#
# Uses `ip -6 route del` / `ip -6 route add` as requested.
#
set -euo pipefail

############################
# Configuration
############################
DEST="2a01:4f8:242:ea48::/62"           # prefix to route
IFACE="enp3s0"                           # egress interface
GW_PRIMARY="fe80::d2ea:11ff:fe3f:a817"   # preferred next-hop
GW_SECONDARY="fe80::d2ea:11ff:fe3f:a816" # backup next-hop

PING_COUNT=2          # packets per probe
PING_TIMEOUT=2        # seconds to wait for replies
CHECK_INTERVAL=5      # seconds between probe rounds
FAIL_THRESHOLD=3      # consecutive failures of active GW before failover
RECOVER_THRESHOLD=3   # consecutive primary successes before failing back
METRIC=100            # route metric

LOG_TAG="gw-failover"

############################
# Helpers
############################
log() {
    local msg="$*"
    echo "$(date '+%F %T') $msg" >&2
    command -v logger >/dev/null 2>&1 && logger -t "$LOG_TAG" -- "$msg" || true
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Must run as root (needs CAP_NET_ADMIN)." >&2
        exit 1
    fi
}

ping_gw() {
    # 0 if the link-local gateway answers on the interface.
    # -I gives the link-local destination its scope; -n no DNS; -q quiet.
    local gw="$1"
    ping -6 -n -q -c "$PING_COUNT" -W "$PING_TIMEOUT" -I "$IFACE" "$gw" \
        >/dev/null 2>&1
}

current_via() {
    # Print the next-hop currently installed for DEST (empty if none).
    ip -6 route show "$DEST" 2>/dev/null \
        | awk '{for (i=1;i<=NF;i++) if ($i=="via") {print $(i+1); exit}}'
}

set_route() {
    # Repoint DEST at the given next-hop using del + add.
    local gw="$1"

    # Remove every route currently present for DEST (config may install both).
    while ip -6 route show "$DEST" 2>/dev/null | grep -q .; do
        ip -6 route del "$DEST" 2>/dev/null || break
    done

    # `dev` is mandatory because the next-hop is link-local (fe80::/10).
    ip -6 route add "$DEST" via "$gw" dev "$IFACE" metric "$METRIC"
    log "route set: $DEST via $gw dev $IFACE"
}

############################
# Main
############################
require_root

active="$(current_via)"
if [[ -n "$active" ]]; then
    log "starting; current next-hop is $active"
else
    log "starting; no route for $DEST yet"
fi

fail_count=0
recover_count=0

cleanup() { log "stopping"; exit 0; }
trap cleanup INT TERM

while true; do
    primary_ok=false;   ping_gw "$GW_PRIMARY"   && primary_ok=true
    secondary_ok=false; ping_gw "$GW_SECONDARY" && secondary_ok=true

    case "$active" in
        "$GW_PRIMARY")
            if $primary_ok; then
                fail_count=0
            else
                fail_count=$((fail_count + 1))
                log "primary unreachable ($fail_count/$FAIL_THRESHOLD)"
                if (( fail_count >= FAIL_THRESHOLD )) && $secondary_ok; then
                    set_route "$GW_SECONDARY"; active="$GW_SECONDARY"
                    fail_count=0; recover_count=0
                fi
            fi
            ;;

        "$GW_SECONDARY")
            if ! $secondary_ok; then
                # Active path is dead: get off it immediately if primary is up.
                if $primary_ok; then
                    set_route "$GW_PRIMARY"; active="$GW_PRIMARY"
                    fail_count=0; recover_count=0
                else
                    fail_count=$((fail_count + 1))
                    log "both gateways unreachable ($fail_count)"
                fi
            elif $primary_ok; then
                # Secondary fine, primary recovered: fail back after hysteresis.
                recover_count=$((recover_count + 1))
                log "primary recovered ($recover_count/$RECOVER_THRESHOLD)"
                if (( recover_count >= RECOVER_THRESHOLD )); then
                    set_route "$GW_PRIMARY"; active="$GW_PRIMARY"
                    fail_count=0; recover_count=0
                fi
            else
                # Primary still down: stay on healthy secondary.
                recover_count=0
            fi
            ;;

        *)
            # Unknown / no route installed: pick the best available.
            if $primary_ok; then
                set_route "$GW_PRIMARY"; active="$GW_PRIMARY"
            elif $secondary_ok; then
                set_route "$GW_SECONDARY"; active="$GW_SECONDARY"
            else
                log "no gateway reachable; leaving route untouched"
            fi
            fail_count=0; recover_count=0
            ;;
    esac

    sleep "$CHECK_INTERVAL"
done
