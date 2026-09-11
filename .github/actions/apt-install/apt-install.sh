#!/usr/bin/env bash
# The Blacksmith runner image's apt mirrorlist names Canonical hosts only, so a
# Canonical archive degradation leaves apt with no reachable mirror. apt then
# retries with no deadline of its own and the job hangs for its whole wall clock
# instead of failing (2026-09-11: 46 minutes in one step, on three branches).
# Every fetch is bounded, and each rung swaps in a different set of mirrors:
# :443 on the same hosts, then a mirror off Canonical's network entirely.
# azure.archive.ubuntu.com answers on :80 only, so it is never rewritten.
set -euo pipefail

read -r -a packages <<<"${APT_PACKAGES:-}"
if [ "${#packages[@]}" -eq 0 ]; then
    echo "::error::apt-install: no packages given"
    exit 2
fi

install_flags=(-y)
if [ "${APT_NO_RECOMMENDS:-true}" = "true" ]; then
    install_flags+=(--no-install-recommends)
fi

# Per-connection deadlines; the outer `timeout` is what turns a mirror that
# accepts the connection and then stalls into a failed step.
apt_flags=(
    -o Acquire::Retries=3
    -o Acquire::http::Timeout=20
    -o Acquire::https::Timeout=20
)

UPDATE_TIMEOUT=180
INSTALL_TIMEOUT=600
DEADLINE=1500

FALLBACK_MIRRORS=(
    http://azure.archive.ubuntu.com/ubuntu/
    https://mirrors.edge.kernel.org/ubuntu/
    https://archive.ubuntu.com/ubuntu/
)

codename=$(. /etc/os-release && echo "$VERSION_CODENAME")

source_files() {
    local f
    for f in /etc/apt/sources.list /etc/apt/blacksmith-ubuntu-mirrors.txt; do
        [ -f "$f" ] && printf '%s\n' "$f"
    done
    if [ -d /etc/apt/sources.list.d ]; then
        find /etc/apt/sources.list.d -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) 2>/dev/null
    fi
    return 0
}

try_install() {
    timeout "$UPDATE_TIMEOUT" sudo apt-get "${apt_flags[@]}" update \
        && timeout "$INSTALL_TIMEOUT" sudo apt-get "${apt_flags[@]}" install "${install_flags[@]}" "${packages[@]}"
}

use_https() {
    local f
    while IFS= read -r f; do
        sudo sed -i -E \
            -e 's#http://(([a-z0-9-]+\.)*)(archive|security)\.ubuntu\.com#https://\1\3.ubuntu.com#g' \
            -e 's#https://azure\.archive\.ubuntu\.com#http://azure.archive.ubuntu.com#g' \
            "$f"
    done < <(source_files)
}

use_fallback_mirror() {
    local candidate mirror=""
    for candidate in "${FALLBACK_MIRRORS[@]}"; do
        if curl -fsS --max-time 20 -o /dev/null "${candidate}dists/${codename}/InRelease"; then
            mirror="$candidate"
            break
        fi
    done
    if [ -z "$mirror" ]; then
        return 1
    fi
    echo "apt-install: falling back to $mirror"
    local f
    while IFS= read -r f; do
        sudo mv "$f" "$f.ci-disabled"
    done < <(source_files)
    sudo tee /etc/apt/sources.list.d/ci-fallback.sources >/dev/null <<EOF
Types: deb
URIs: $mirror
Suites: $codename $codename-updates $codename-backports $codename-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
}

for attempt in image-mirrors canonical-https fallback-mirror; do
    if [ "$SECONDS" -ge "$DEADLINE" ]; then
        echo "::warning::apt-install: out of time before $attempt"
        break
    fi
    case "$attempt" in
        canonical-https) use_https ;;
        fallback-mirror) use_fallback_mirror || break ;;
    esac
    if try_install; then
        echo "apt-install: installed ${packages[*]} via $attempt"
        exit 0
    fi
    echo "::warning::apt-install: $attempt could not serve ${packages[*]}"
done

echo "::error::apt-install: every mirror failed for ${packages[*]}; check https://status.canonical.com"
exit 1
