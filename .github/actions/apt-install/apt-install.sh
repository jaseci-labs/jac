#!/usr/bin/env bash
# The runner images point apt at a mirrorlist naming Canonical hosts only, so a
# Canonical archive degradation leaves it nothing to fall back to: apt retries
# with no deadline of its own and the job stalls for its whole wall clock
# instead of failing (2026-09-11: 46 minutes in one step, on three branches).
# apt already fails over between mirrorlist entries, so all it needs is entries
# off Canonical's network, plus deadlines so a stalled fetch cannot sit forever.
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

apt_etc=${APT_ETC_DIR:-/etc/apt}

printf 'Acquire::Retries "3";\nAcquire::http::Timeout "20";\nAcquire::https::Timeout "20";\n' \
    | sudo tee "$apt_etc/apt.conf.d/99-ci-fetch-deadlines" >/dev/null

# Blacksmith images keep this at blacksmith-ubuntu-mirrors.txt, GitHub-hosted
# ones at apt-mirrors.txt. azure answers on :80 only, kernel.org on :443 only.
shopt -s nullglob
mirror_lists=("$apt_etc"/*mirrors*.txt)
shopt -u nullglob
if [ "${#mirror_lists[@]}" -eq 0 ]; then
    echo "::warning::apt-install: no apt mirrorlist on this image, using its sources as-is"
else
    printf 'http://azure.archive.ubuntu.com/ubuntu\nhttps://mirrors.edge.kernel.org/ubuntu\n' \
        | sudo tee -a "${mirror_lists[@]}" >/dev/null
fi

timeout 300 sudo apt-get update
timeout 900 sudo apt-get install "${install_flags[@]}" "${packages[@]}"
