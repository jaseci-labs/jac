"""Enforced user code must stay able to import and call bundled na_stdlib
modules: the jaclang-package carve-out exempts their internals while
module-name matching keeps the call boundary open. A regression in either
direction turns this compile into a wall of E140x diagnostics. Owned values
cross the boundary through `from`-imports (bare-name calls take the
callee-module check); `mod.fn` attribute calls only take arg-free shapes
here because an owned arg there reads as sealing into managed storage."""

import os;
import socket;
import time;
import from zlib { compress, decompress }

with entry {
    packed: bytes = compress(b"nogc bundled stdlib");
    assert decompress(packed) == b"nogc bundled stdlib";
    sock = socket.socket();
    sock.close();
    assert time.monotonic_ns() > 0;
    print(len(os.getcwd()) > 0);
}
