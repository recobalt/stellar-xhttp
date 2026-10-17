#!/usr/bin/env bash
# Stellar · release 1.0.0
set -Eeuo pipefail
export LC_ALL=C.UTF-8

readonly TABLE=stellar_privacy

start() {
    if ! nft list table inet "$TABLE" >/dev/null 2>&1; then
        nft add table inet "$TABLE"
    fi
    nft -f - <<'NFT'
flush table inet stellar_privacy

add chain inet stellar_privacy privacy_input { type filter hook input priority -20; policy accept; }

add rule inet stellar_privacy privacy_input ip protocol icmp icmp type echo-request counter drop comment "Stellar: block ICMP echo"
add rule inet stellar_privacy privacy_input ip protocol icmp icmp type timestamp-request counter drop comment "Stellar: block ICMP timestamp"
add rule inet stellar_privacy privacy_input meta l4proto ipv6-icmp icmpv6 type echo-request counter drop comment "Stellar: block ICMPv6 echo"
NFT
}

stop() {
    if nft list table inet "$TABLE" >/dev/null 2>&1; then
        nft delete table inet "$TABLE"
    fi
}

status() {
    nft list table inet "$TABLE"
}

case "${1:-start}" in
    start) start;;
    stop) stop;;
    restart) stop; start;;
    status) status;;
    *) printf 'Использование: %s {start|stop|restart|status}\n' "$0" >&2; exit 2;;
esac
