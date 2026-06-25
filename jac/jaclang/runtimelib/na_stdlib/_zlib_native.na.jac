"""FFI floor for the bundled native `zlib` — Mechanism F over the system libz.

Part of the native standard library shipped under
`jaclang/runtimelib/na_stdlib` (issue #6940 Phase 2). This module is the thin
FFI binding the issue calls the "security/perf-critical floor": it never
reimplements DEFLATE, it forwards to the platform's `libz` (resolved by logical
name `z` → `libz.so` / `libz.dylib` / `z.dll`), exactly as CPython's `zlib` is
a wrapper over the same library. The Python-congruent surface that programs
call (`compress` / `decompress` / `crc32` / `adler32`) is the pure-Jac
`zlib.na.jac` module layered on top of these primitives.

A `bytes` argument on a foreign signature lowers to its raw data pointer (the C
buffer-protocol convention); the element count travels through the explicit
length parameter. The `*Len` in/out parameters (libz's `uLongf *destLen`) are
passed as 8-byte little-endian `bytes` scratch buffers the C side writes back
into, then re-read with `int.from_bytes`.

PORTABILITY: native-host-only (A/F tier). libz exists on Linux/macOS/Windows
native targets but not on bare wasm, so a wasm target gets a clean link error
rather than silent breakage — matching the issue's per-module portability
labelling.

A clib extern is declared into the shared native symbol table under its C
symbol name, so importing libz's `crc32` / `adler32` by those names would
collide with — and (being declared first) shadow — the public surface's
identically named `crc32` / `adler32` functions. The `_z` variants
(`crc32_z` / `adler32_z`, zlib ≥ 1.2.9) are byte-for-byte equivalent, take a
`size_t` length (so no 4 GiB cap), and sidestep the collision; the public
module re-exports them through the `z_`-prefixed wrappers below.
"""

import from z {
    def compress2(
        dest: bytes, destLen: bytes, source: bytes, sourceLen: u64, level: i32
    ) -> i32;  def uncompress(
        dest: bytes, destLen: bytes, source: bytes, sourceLen: u64
    ) -> i32;  def compressBound(sourceLen: u64) -> u64;  def crc32_z(
        crc: u64, buf: bytes, len: u64
    ) -> u64;  def adler32_z(adler: u64, buf: bytes, len: u64) -> u64;
}


"""Upper bound on the compressed size of `source_len` bytes (zlib compressBound)."""
def:pub z_compress_bound(source_len: int) -> int {
    return compressBound(source_len);
}


"""One-shot zlib-format DEFLATE of `source[:source_len]` into `dest`. `dest_len`
is an 8-byte LE scratch buffer: capacity in, compressed length out. Returns the
libz status code (0 == Z_OK)."""
def:pub z_compress2(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int, level: int
) -> int {
    return compress2(dest, dest_len, source, source_len, level);
}


"""One-shot zlib-format INFLATE of `source[:source_len]` into `dest`. `dest_len`
is an 8-byte LE scratch buffer: capacity in, decompressed length out. Returns
the libz status code (0 == Z_OK, -5 == Z_BUF_ERROR when `dest` is too small)."""
def:pub z_uncompress(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int
) -> int {
    return uncompress(dest, dest_len, source, source_len);
}


"""CRC-32 of `buf[:n]` continued from running value `crc` (libz crc32_z)."""
def:pub z_crc32(crc: int, buf: bytes, n: int) -> int {
    return crc32_z(crc, buf, n);
}


"""Adler-32 of `buf[:n]` continued from running value `adler` (libz adler32_z)."""
def:pub z_adler32(adler: int, buf: bytes, n: int) -> int {
    return adler32_z(adler, buf, n);
}
