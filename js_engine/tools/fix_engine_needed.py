#!/usr/bin/env python3
"""Rewrite cwd-relative DT_NEEDED entries in bin/js_engine to bare sonames.

Jac embeds import paths like ``lib/libnapi_shim.so`` as DT_NEEDED.  The dynamic
linker resolves NEEDED entries that contain a slash against *cwd*, so any
child_process spawn with a different working directory fails to start.

We shorten those strings in-place (null-pad the tail) so NEEDED becomes a bare
soname searchable via LD_LIBRARY_PATH / RPATH:

    lib/libnapi_shim.so          → libnapi_shim.so
    lib/libtz_shim.so            → libtz_shim.so
    lib/llhttp/lib/libllhttp.so  → libllhttp.so
    lib/libwasmtime.so           → libwasmtime.so

Safe because every replacement is strictly shorter than the original.
"""
from __future__ import annotations

import sys
from pathlib import Path

REPLACEMENTS = (
    (b"lib/llhttp/lib/libllhttp.so", b"libllhttp.so"),
    (b"lib/libnapi_shim.so", b"libnapi_shim.so"),
    (b"lib/libtz_shim.so", b"libtz_shim.so"),
    (b"lib/libicu_shim.so", b"libicu_shim.so"),
    (b"lib/libwasmtime.so", b"libwasmtime.so"),
)


def patch(path: Path) -> int:
    data = bytearray(path.read_bytes())
    changed = 0
    for old, new in REPLACEMENTS:
        if len(new) > len(old):
            raise SystemExit(f"replacement longer than original: {new!r}")
        padded = new + b"\0" * (len(old) - len(new))
        start = 0
        while True:
            idx = data.find(old, start)
            if idx < 0:
                break
            # Only replace if it looks like a C string (null or already end)
            data[idx : idx + len(old)] = padded
            changed += 1
            start = idx + len(old)
    if changed:
        path.write_bytes(data)
    return changed


def main() -> None:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <binary>", file=sys.stderr)
        sys.exit(2)
    path = Path(sys.argv[1])
    n = patch(path)
    print(f"fix_engine_needed: {n} replacement(s) in {path}")


if __name__ == "__main__":
    main()
