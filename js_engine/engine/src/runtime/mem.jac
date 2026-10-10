"""Low-level memory read/write helpers for Jac native.

All functions operate on raw `Ptr` (= int) pointers (GC-allocated or C-heap).
Reads and writes lower to the compiler's raw-memory intrinsics
(`__mem_load_iN` / `__mem_store_iN`): unchecked little-endian loads/stores.
The loads are signed, so unsigned reads mask after widening, and narrow
stores truncate through `iN.wrap`. The intrinsics carry the type's natural
alignment: unaligned offsets work on x86-64, but LLVM does not guarantee them.

NOTE: the old implementation cast the pointer to `str` and indexed it
(`ord(s[i])`). That idiom relied on string subscripts compiling to raw
unchecked loads; since jaclang #8207 string subscripts are length-checked
(len = strlen), so any buffer containing a 0x00 byte made reads past it raise
"string index out of range" (or corrupt state deeper in the engine). The
intrinsics restore true raw access without weakening str semantics.

On x86-64 Linux all integers are stored little-endian.

Public API
----------
  io_alloc(size)                   -> Ptr

  read_byte(ptr, offset)           -> int        0..255
  write_byte(ptr, offset, value)   -> None

  read_u16(ptr, offset)            -> int        0..65535
  read_u32(ptr, offset)            -> int        0..4294967295     (unsigned)
  read_i32(ptr, offset)            -> int        -2147483648..2147483647 (signed)
  read_u64(ptr, offset)            -> int        signed i64 bit pattern
  read_ptr(ptr, offset)            -> Ptr        pointer value     (= read_u64)

  write_i32(ptr, offset, value)    -> None       little-endian 4 bytes
  write_i64(ptr, offset, value)    -> None       little-endian 8 bytes

  str_from_raw(ptr)                -> str        owned copy of the NUL-terminated bytes
  byte_chr(b)                      -> str        one raw byte (chr(b) UTF-8-encodes b >= 128)

errno / process helpers live in ffi/libc.na.jac (get_errno).

Bun reference: bun/src/sys.zig  (Syscall.Error, errno helpers)
"""

import from engine.src.ffi.libc { calloc, free, write, abort, getenv }

# ── Type aliases ─────────────────────────────────────────────────────────────

"""Pointer-sized integer (i64 on x86-64). Use instead of bare `int` wherever
a value represents a raw memory address.""" type Ptr = int;

# ── String-safe allocation ───────────────────────────────────────────────────

"""Allocate a zeroed I/O buffer that is safe to cast to Jac `str`."""
glob _IOA_BYTES: int = 0;
glob _IOA_CALLS: int = 0,
     _IOA_NEXT_DUMP: int = 536870912,
     _IOA_BIG: int = 0,
     _IOA_BIGBYTES: int = 0,
     _IOA_DBG: int = -1;

# first dump at 512MB cumulative
# count of single allocs >= 1MB
# bytes in those big allocs
# -1 unknown, 0 off, 1 on (latched)
"""Bytes of zeroed header in front of every io_alloc buffer: the compiler's
full refcount header. Casting the buffer to `str` (`s: str = ptr`, as the .jsbc
decoder and UVBuf.base do) makes the refcount code read and write the header
from ptr-32 (alloc id + magic, HDR_ALLOC_ID_OFF) to ptr-16 (count, HDR_RC_OFF).
A shorter header puts ptr-32 in the previous heap block: with 16 bytes, the
flag bits written there cleared bits in the last character of the string
before it (`exports` decoded as `exportp`), and on an mmap'd (>=128KB) buffer
it would land in an unmapped page. Zeroed, the magic never matches, so the
buffer is treated as unmanaged. fs.jac's _io_alloc uses the same size."""
glob:pub IO_ALLOC_HDR: int = 32;

def:pub io_alloc(size: int) -> Ptr {
    raw: Ptr = calloc(1, size + IO_ALLOC_HDR);
    if raw == 0 {
        msg: str = "FATAL: io_alloc OOM (size=" + str(size) + ")\n";
        write(2, msg, len(msg));
        abort();
    }
    if _IOA_DBG != 0 {
        if _IOA_DBG < 0 {
            if getenv("JAC_DBG_IOALLOC") != None {
                _IOA_DBG = 1;
            } else {
                _IOA_DBG = 0;
            }
        }
        if _IOA_DBG == 1 {
            _IOA_BYTES = _IOA_BYTES + size;
            _IOA_CALLS = _IOA_CALLS + 1;
            if size >= 1048576 {
                _IOA_BIG = _IOA_BIG + 1;
                _IOA_BIGBYTES = _IOA_BIGBYTES + size;
            }
            if _IOA_BYTES >= _IOA_NEXT_DUMP {
                _IOA_NEXT_DUMP = _IOA_BYTES + 536870912;
                dmsg: str = "[IOALLOC] cum="
                    + str(_IOA_BYTES // 1048576)
                    + "MB calls="
                    + str(_IOA_CALLS)
                    + " big(>=1MB)="
                    + str(_IOA_BIG)
                    + " bigMB="
                    + str(_IOA_BIGBYTES // 1048576)
                    + " lastsize="
                    + str(size)
                    + "\n";
                write(2, dmsg, len(dmsg));
            }
        }
    }
    return raw + IO_ALLOC_HDR;
}

"""Release a buffer obtained from io_alloc.  Mirrors __buf.free() so native
code can drop a buffer it decided not to hand to JS after all."""
def:pub io_free(ptr: Ptr) {
    if ptr != 0 {
        free(ptr - IO_ALLOC_HDR);
    }
}

# ── Read helpers ─────────────────────────────────────────────────────────────

"""Read one unsigned byte from (ptr + offset). O(1), unchecked."""
def:pub read_byte(ptr: Ptr, offset: int) -> int {
    return int(__mem_load_i8(ptr + offset)) & 255;
}

"""Read a 2-byte unsigned little-endian integer from (ptr + offset)."""
def:pub read_u16(ptr: Ptr, offset: int) -> int {
    return int(__mem_load_i16(ptr + offset)) & 65535;
}

"""Read a 4-byte unsigned little-endian integer from (ptr + offset)."""
def:pub read_u32(ptr: Ptr, offset: int) -> int {
    return int(__mem_load_i32(ptr + offset)) & 4294967295;
}

"""Read a 4-byte signed little-endian integer from (ptr + offset).
Values whose most-significant bit is set are sign-extended to negative."""
def:pub read_i32(ptr: Ptr, offset: int) -> int {
    return int(__mem_load_i32(ptr + offset));
}

"""Read an 8-byte little-endian integer from (ptr + offset).
Returns a signed i64 (two's complement): an i64 load of the same 8 bytes,
identical bit pattern to the old sign-extended reconstruction."""
def:pub read_u64(ptr: Ptr, offset: int) -> int {
    return __mem_load_i64(ptr + offset);
}

"""Read a pointer-sized value from (ptr + offset). Alias for read_u64."""
def:pub read_ptr(ptr: Ptr, offset: int) -> Ptr {
    return __mem_load_i64(ptr + offset);
}

# ── Write helpers ─────────────────────────────────────────────────────────────

"""Write one byte (0..255) to (ptr + offset). O(1), unchecked."""
def:pub write_byte(ptr: Ptr, offset: int, value: int) {
    __mem_store_i8(ptr + offset, i8.wrap(value));
}

"""Write a 4-byte signed/unsigned integer at (ptr + offset), little-endian."""
def:pub write_i32(ptr: Ptr, offset: int, value: int) {
    __mem_store_i32(ptr + offset, i32.wrap(value));
}

"""Write an 8-byte integer at (ptr + offset), little-endian."""
def:pub write_i64(ptr: Ptr, offset: int, value: int) {
    __mem_store_i64(ptr + offset, value);
}

# ── Strings from raw bytes ────────────────────────────────────────────────────

glob _EMPTY: str = "";

"""Owned, byte-exact copy of the NUL-terminated bytes at `p`, an io_alloc buffer.

Use this instead of `tmp: str = p; out = "" + tmp` in the caller. A cast makes
the str's refcount root the buffer itself, and the str is released when it goes
out of scope: in the caller that is after any `io_free` of the buffer later in
the same function, a use-after-free that segfaults once the buffer is large
enough to be mmap'd. Here the cast's scope ends when this returns, so the
caller can free the buffer straight after. The cast's refcount checks read
the 32 bytes before `p`, which io_alloc zeroes (IO_ALLOC_HDR); do not pass a
pointer into memory someone else allocated. (A libc function declared `-> str`
is no substitute: that import re-encodes bytes >= 128 as Latin-1 code points.)
Stops at the first 0x00 byte, like the cast."""
def:pub str_from_raw(p: Ptr) -> str {
    tmp: str = p;  # jac:ignore[E1001] pointer reinterpret
    return _EMPTY + tmp;
}

"""Owned str copy of the NUL-terminated C string at `p` in memory someone
else allocated (libuv, Wasmtime, libc). Casting such a pointer (`s: str = p`)
makes the str's refcount checks read the 32 bytes before `p`, which only
io_alloc guarantees zeroed (see str_from_raw): with another allocator's chunk
header there, a check that happens to pass makes the cast's release free or
corrupt foreign memory. So the bytes are copied into an io_alloc buffer first."""
def:pub str_from_foreign_cstr(p: Ptr) -> str {
    if p == 0 {
        return "";
    }
    fc_n: int = 0;
    while read_byte(p, fc_n) != 0 {
        fc_n = fc_n + 1;
    }
    fc_buf: Ptr = io_alloc(fc_n + 1);
    fc_i: int = 0;
    while fc_i < fc_n {
        write_byte(fc_buf, fc_i, read_byte(p, fc_i));
        fc_i = fc_i + 1;
    }
    write_byte(fc_buf, fc_n, 0);
    fc_out: str = str_from_raw(fc_buf);
    io_free(fc_buf);
    return fc_out;
}

glob _BYTE_STRS: list[str] = [];

"""A one-byte str holding the raw byte `b` (0..255).

`chr(b)` is a character, not a byte: for b >= 128 it is the 2-byte UTF-8
encoding of code point b, so building bytes with it double-encodes them
(`chr(195) + chr(169)` is not "é"). Use byte_chr wherever a byte is meant:
UTF-8/WTF-8 encoders, strings assembled from buffer bytes, and comparisons
against single bytes of a str."""
def:pub byte_chr(b: int) -> str {
    if b < 128 {
        return chr(b);
    }
    if len(_BYTE_STRS) == 0 {
        buf: Ptr = io_alloc(2);
        i: int = 128;
        while i < 256 {
            write_byte(buf, 0, i);
            _BYTE_STRS.append(str_from_raw(buf));
            i = i + 1;
        }
        io_free(buf);
    }
    return _BYTE_STRS[b - 128];
}
