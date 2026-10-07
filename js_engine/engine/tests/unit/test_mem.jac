"""
Raw memory helpers (runtime/mem.jac).

io_alloc / read_* / write_* back every binary path in the engine: .jsbc decode,
Buffer/TypedArray storage, fs and socket I/O. They lower to the native
backend's raw load/store intrinsics, so this pins the exact contract the rest
of the engine assumes:

  - reads are little-endian; read_byte/u16/u32 zero-extend, read_i32
    sign-extends, read_u64 returns the raw i64 bit pattern;
  - writes truncate to their width;
  - any byte offset is valid (unaligned access);
  - io_alloc memory is zeroed and preceded by a zeroed 32-byte header (casting
    the buffer to str runs the compiler's refcount code on ptr-32..ptr-1; it
    must find zeros and stay inside the buffer's own allocation);
  - str_from_raw copies a buffer byte for byte, so the buffer can be freed
    straight after, even a large mmap-backed one;
  - byte_chr(b) is the single byte b for all 1..255 (chr(b) is not, above 127).
"""

import from engine.src.runtime.mem {
    io_alloc,
    io_free,
    read_byte,
    read_u16,
    read_u32,
    read_i32,
    read_u64,
    read_ptr,
    write_byte,
    write_i32,
    write_i64,
    str_from_raw,
    byte_chr
}
import from engine.src.ffi.libc { fflush, _exit }

glob _ok: int = 0,
     _fail: int = 0;

def _chki(label: str, got: int, want: int) {
    if got == want {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + label + " — got " + str(got) + " want " + str(want));
    }
}

with entry {
    p: int = io_alloc(64);
    _chki("io_alloc returns non-null", 1 if p != 0 else 0, 1);

    # ── Zeroed body and header ───────────────────────────────────────────────
    nz: int = 0;
    i: int = 0;
    while i < 64 {
        if read_byte(p, i) != 0 {
            nz = nz + 1;
        }
        i = i + 1;
    }
    _chki("io_alloc body zeroed", nz, 0);
    _chki("io_alloc header[0..8] zero", read_u64(p, -32), 0);
    _chki("io_alloc header[8..16] zero", read_u64(p, -24), 0);
    _chki("io_alloc header[16..24] zero", read_u64(p, -16), 0);
    _chki("io_alloc header[24..32] zero", read_u64(p, -8), 0);

    # ── Byte: zero-extension and truncation ──────────────────────────────────
    write_byte(p, 0, 255);
    _chki("read_byte 0xFF zero-extends", read_byte(p, 0), 255);
    write_byte(p, 1, 0x1AB);
    _chki("write_byte truncates to 8 bits", read_byte(p, 1), 0xAB);
    write_byte(p, 2, -1);
    _chki("write_byte -1 stores 0xFF", read_byte(p, 2), 255);

    # ── 32-bit: little-endian layout, zero- vs sign-extension ────────────────
    write_i32(p, 8, 0x04030201);
    _chki("LE byte 0", read_byte(p, 8), 1);
    _chki("LE byte 1", read_byte(p, 9), 2);
    _chki("LE byte 2", read_byte(p, 10), 3);
    _chki("LE byte 3", read_byte(p, 11), 4);
    _chki("read_u16 LE", read_u16(p, 8), 0x0201);
    _chki("read_u32 LE", read_u32(p, 8), 0x04030201);

    write_i32(p, 12, -1);
    _chki("read_u32 0xFFFFFFFF zero-extends", read_u32(p, 12), 4294967295);
    _chki("read_i32 0xFFFFFFFF sign-extends", read_i32(p, 12), -1);
    _chki("read_u16 0xFFFF zero-extends", read_u16(p, 12), 65535);
    write_i32(p, 12, 0x80000000);
    _chki("read_i32 0x80000000 = INT32_MIN", read_i32(p, 12), -2147483648);
    _chki("read_u32 0x80000000", read_u32(p, 12), 2147483648);
    write_i32(p, 16, 0x1_2345_6789);
    _chki("write_i32 truncates to 32 bits", read_u32(p, 16), 0x2345_6789);
    _chki("write_i32 leaves the next byte alone", read_byte(p, 20), 0);

    # ── 64-bit: raw bit pattern ──────────────────────────────────────────────
    write_i64(p, 24, -1);
    _chki("read_u64 all-ones is -1", read_u64(p, 24), -1);
    write_i64(p, 24, -9223372036854775807 - 1);
    _chki("read_u64 INT64_MIN", read_u64(p, 24), -9223372036854775807 - 1);
    _chki("INT64_MIN low byte", read_byte(p, 24), 0);
    _chki("INT64_MIN high byte", read_byte(p, 31), 0x80);
    write_i64(p, 24, 0x0102_0304_0506_0708);
    _chki("read_u64 LE value", read_u64(p, 24), 0x0102_0304_0506_0708);
    _chki("read_u64 LE low byte", read_byte(p, 24), 8);
    _chki("read_ptr aliases read_u64", read_ptr(p, 24), 0x0102_0304_0506_0708);

    # ── Unaligned access at every offset within a word ──────────────────────
    bad_unaligned: int = 0;
    off: int = 33;
    while off < 41 {
        write_i64(p, off, 0x1122_3344_5566_7788 + off);
        if read_u64(p, off) != 0x1122_3344_5566_7788 + off {
            bad_unaligned = bad_unaligned + 1;
        }
        write_i32(p, off, -2 - off);
        if read_i32(p, off) != -2 - off {
            bad_unaligned = bad_unaligned + 1;
        }
        off = off + 1;
    }
    _chki("unaligned i64/i32 round-trip at offsets 33..40", bad_unaligned, 0);

    # ── Large allocation (mmap-backed in glibc) is zeroed and writable ──────
    big: int = io_alloc(1 << 20);
    _chki("1MB io_alloc non-null", 1 if big != 0 else 0, 1);
    _chki("1MB header zero", read_u64(big, -16), 0);
    write_byte(big, (1 << 20) - 1, 7);
    _chki("1MB last byte writable", read_byte(big, (1 << 20) - 1), 7);
    _chki("1MB middle zeroed", read_u64(big, 1 << 19), 0);
    io_free(big);
    io_free(p);
    io_free(0);  # free of NULL is a no-op

    # ── byte_chr: one raw byte, not the UTF-8 encoding of a code point ──────
    bad_bytes: int = 0;
    b: int = 1;
    while b < 256 {
        bs: str = byte_chr(b);
        if len(bs) != 1 or ord(bs) != b {
            bad_bytes = bad_bytes + 1;
        }
        b = b + 1;
    }
    _chki("byte_chr(b) is 1 byte of value b, b in 1..255", bad_bytes, 0);
    _chki(
        "byte_chr builds UTF-8 bytes",
        1 if byte_chr(195) + byte_chr(169) == "é" else 0,
        1
    );

    # ── str_from_raw: an owned copy, safe to use after the buffer is freed ──
    q: int = io_alloc(8);
    write_byte(q, 0, 104);
    write_byte(q, 1, 105);
    write_byte(q, 2, 233);
    copied: str = str_from_raw(q);
    write_byte(q, 0, 120);
    io_free(q);
    _chki("str_from_raw length", len(copied), 3);
    _chki(
        "str_from_raw copies (buffer overwritten then freed)",
        1 if copied[0:2] == "hi" else 0,
        1
    );
    _chki(
        "str_from_raw keeps byte 233 raw", 1 if copied[2:3] == byte_chr(233) else 0, 1
    );
}

glob n_big: int = 300000;
with entry {
    q = io_alloc(n_big + 1);
    k: int = 0;
    while k < n_big {
        write_byte(q, k, 97 + (k % 26));
        k = k + 1;
    }
    copied_big: str = str_from_raw(q);
    io_free(q);
    _chki(
        "str_from_raw of a 300KB (mmap-backed) buffer, then free",
        len(copied_big),
        n_big
    );

    print("mem: passed=" + str(_ok) + " failed=" + str(_fail));
    if _fail > 0 {
        fflush(0);
        _exit(1);
    }
}
