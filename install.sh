#!/usr/bin/env bash
# Stellar XHTTP Installer · verified GitHub launcher
# SPDX-License-Identifier: MIT
set -Eeuo pipefail

# shellcheck source=/dev/null
source /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 24.04 ]] || {
    printf 'Поддерживается только Ubuntu 24.04 LTS; изменения не начаты.\n' >&2
    exit 2
}

as_root=()
if (( EUID != 0 )); then
    as_root=(sudo)
fi
"${as_root[@]}" apt-get update
"${as_root[@]}" apt-get install -y curl ca-certificates python3

umask 077
launch_dir=$(mktemp -d /tmp/stellar-xhttp-launch.XXXXXXXX)
cleanup() {
    rm -f -- "$launch_dir/stellar-xhttp-install.sh" "$launch_dir/SHA256SUMS"
    rmdir -- "$launch_dir"
}
trap cleanup EXIT

revision=$(curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 15 --max-time 60 --retry 3 --retry-max-time 180 \
    https://api.github.com/repos/recobalt/XHTTP-Installer/commits/main \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["sha"])')
[[ $revision =~ ^[0-9a-f]{40}$ ]] || {
    printf 'Не удалось определить коммит установщика.\n' >&2
    exit 1
}
source_url=https://raw.githubusercontent.com/recobalt/XHTTP-Installer/$revision
curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 15 --max-time 300 --retry 3 --retry-max-time 900 \
    "$source_url/stellar-xhttp-install.sh" -o "$launch_dir/stellar-xhttp-install.sh"
curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 15 --max-time 300 --retry 3 --retry-max-time 900 \
    "$source_url/SHA256SUMS" -o "$launch_dir/SHA256SUMS"
(cd "$launch_dir" && sha256sum -c SHA256SUMS)

if (( $# == 0 )); then
    set -- --install --no-traffic-control --no-two-way-ping --no-tuning --no-updates
fi
"${as_root[@]}" bash "$launch_dir/stellar-xhttp-install.sh" "$@"
