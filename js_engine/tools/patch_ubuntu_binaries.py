#!/usr/bin/env python3
"""Rewrite absolute Ubuntu multiarch DT_NEEDED paths to bare sonames.

Binaries built on Ubuntu (CI) embed absolute library paths like
``/usr/lib/x86_64-linux-gnu/libuv.so.1`` as DT_NEEDED entries. Those paths
only exist on Debian/Ubuntu, so the binary fails at startup on Arch
(/usr/lib) or Fedora (/usr/lib64):

    error while loading shared libraries: /usr/lib/x86_64-linux-gnu/libuv.so.1:
    cannot open shared object file: No such file or directory

patchelf refuses these binaries (no section headers), so we patch the
dynstr strings in place: shorten each absolute path to its bare soname
(null-pad the tail). NUL-padded entries are strictly shorter, so offsets
never move. Only strings preceded by a NUL byte are replaced, so a path
like ``/lib/...`` is never clobbered inside ``/usr/lib/...``.

Bare sonames resolve via the normal ldconfig cache on any distro.

Usage:
    python3 tools/patch_ubuntu_binaries.py <binary> [<binary> ...]
"""
from __future__ import annotations

import sys
from pathlib import Path

REPLACEMENTS = (
    ("/usr/lib/x86_64-linux-gnu/libuv.so.1", "libuv.so.1"),
    ("/usr/lib/x86_64-linux-gnu/libc.so.6", "libc.so.6"),
    ("/lib/x86_64-linux-gnu/libc.so.6", "libc.so.6"),
    ("/usr/lib/x86_64-linux-gnu/libm.so.6", "libm.so.6"),
    ("/usr/lib/x86_64-linux-gnu/libdl.so.2", "libdl.so.2"),
    ("/usr/lib/x86_64-linux-gnu/libpcre2-8.so.0", "libpcre2-8.so.0"),
    ("/usr/lib/x86_64-linux-gnu/libcrypto.so.3", "libcrypto.so.3"),
    ("/usr/lib/x86_64-linux-gnu/libssl.so.3", "libssl.so.3"),
    ("/usr/lib/x86_64-linux-gnu/libnghttp2.so", "libnghttp2.so"),
    ("/lib/x86_64-linux-gnu/libz.so.1", "libz.so.1"),
    ("/lib/x86_64-linux-gnu/libzstd.so.1", "libzstd.so.1"),
    ("/lib/x86_64-linux-gnu/libbrotlienc.so.1", "libbrotlienc.so.1"),
    ("/lib/x86_64-linux-gnu/libbrotlidec.so.1", "libbrotlidec.so.1"),
)


def patch_file(path: Path) -> int:
    data = bytearray(path.read_bytes())
    count = 0
    for old, new in REPLACEMENTS:
        old_b = old.encode()
        new_b = new.encode()
        assert len(new_b) <= len(old_b), f"{new!r} longer than {old!r}"
        padded = new_b + b"\x00" * (len(old_b) - len(new_b))
        idx = 0
        while (i := data.find(old_b, idx)) >= 0:
            # Only replace at a string start (preceded by NUL) so we never
            # match the tail of a longer absolute path.
            if i == 0 or data[i - 1] == 0:
                data[i : i + len(old_b)] = padded
                count += 1
            idx = i + 1
    if count:
        path.write_bytes(data)
        path.chmod(path.stat().st_mode | 0o111)
    return count


def main() -> None:
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} <binary> [<binary> ...]", file=sys.stderr)
        sys.exit(2)
    for arg in sys.argv[1:]:
        path = Path(arg)
        n = patch_file(path)
        print(f"{path}: {n} DT_NEEDED path(s) rewritten to bare sonames")


if __name__ == "__main__":
    main()
