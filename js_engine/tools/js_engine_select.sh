#!/usr/bin/env bash
# js_engine_select — run a js_engine build BY RECENCY, as a drop-in for the engine.
#
# The Makefile archives each previous binary as bin/js_engine.<YYYYmmdd-HHMMSS>
# (the mtime of that build) before overwriting bin/js_engine. This wrapper lets
# you invoke any of those historical builds by how recent they are, without
# remembering timestamps — handy for A/B-ing a fix against the build before it.
#
# Usage:
#   js_engine_select -N [engine args...]
#
#     -1   latest archived build   (js_engine.<newest date>)
#     -2   second latest archive
#     -N   Nth latest archive
#     -0   the current live bin/js_engine (the freshest build, not yet archived)
#
#   Everything after -N is forwarded verbatim to the selected binary, so:
#       js_engine_select -1 --gc script.mjs
#       js_engine_select -2 node_modules/vite/bin/vite.js build
#
#   With no args (or an out-of-range/invalid selector) it lists what's available.
#
# LD_LIBRARY_PATH for the engine's bundled shared libs is set automatically, so
# this behaves as if you ran the engine directly.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"      # .../bin
root="$(cd "$here/.." && pwd)"                            # js_engine root

# Archives, newest first. Names are zero-padded YYYYmmdd-HHMMSS, so a reverse
# lexical sort is chronological. Match only the dated archives (not .symmap etc).
mapfile -t archives < <(ls -1 "$here"/js_engine.[0-9]*-[0-9]* 2>/dev/null | sort -r)

list_available() {
    echo "Available js_engine builds (newest first):" >&2
    if [[ -e "$here/js_engine" ]]; then
        printf "  -0  %s  (current live build)\n" "$(date -r "$here/js_engine" '+%Y-%m-%d %H:%M:%S')" >&2
    fi
    if [[ ${#archives[@]} -eq 0 ]]; then
        echo "  (no archived builds yet)" >&2
    else
        local i=1
        for a in "${archives[@]}"; do
            printf "  -%d  %s\n" "$i" "$(basename "$a")" >&2
            i=$((i + 1))
        done
    fi
}

sel="${1:-}"
if [[ -z "$sel" || ! "$sel" =~ ^-[0-9]+$ ]]; then
    echo "usage: js_engine_select -N [engine args...]   (-1 = latest archive, -0 = current)" >&2
    echo >&2
    list_available
    exit 2
fi
shift
n="${sel#-}"

if [[ "$n" -eq 0 ]]; then
    selected="$here/js_engine"
    if [[ ! -x "$selected" ]]; then
        echo "js_engine_select: no current bin/js_engine build present" >&2
        exit 3
    fi
else
    if [[ "$n" -gt "${#archives[@]}" ]]; then
        echo "js_engine_select: requested -$n but only ${#archives[@]} archived build(s) exist" >&2
        echo >&2
        list_available
        exit 3
    fi
    selected="${archives[$((n - 1))]}"
fi

# Bundled shared libs (libpcre2, llhttp, napi/tz/icu/wasmtime shims) — same env
# the test harness and manual invocations use.
export LD_LIBRARY_PATH="$root/lib:$root/lib/llhttp/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Announce the choice on stderr (not stdout, so program output stays clean).
echo "js_engine_select: using $(basename "$selected")" >&2
exec "$selected" "$@"
