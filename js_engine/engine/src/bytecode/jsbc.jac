"""
js_engine/engine/src/bytecode/jsbc.na.jac — Precompiled builtin bytecode (.jsbc)
serializer / deserializer.

See docs/jsbc_bytecode_cache_plan.md for the full design. This module round-trips
a compiled module (top_fn + all_fns) to/from a flat, pointer-free PACKED BINARY
form so builtin JS can ship as precompiled bytecode and skip parse+compile at
engine startup.

BINARY FORMAT (v4). Little-endian throughout. Every integer field and every count
is a fixed 8-byte i64 (no varints — simplicity/safety over compactness). Encoding
builds into a growable raw byte buffer (mem.na.jac helpers) and returns a
JSBCBlob(ptr,size); decoding reads from a raw byte buffer via mem.na.jac. Because
the blob is NEVER transported through a Jac `str` (which is strlen-based and would
truncate at the first embedded NUL), the format is binary-safe — arbitrary bytes,
including NUL, round-trip in every length-prefixed field.

Primitives:
  u8    : write_byte / read_byte
  i64   : write_i64 / read_u64 (read_u64 returns a signed i64 — two's complement
          round-trips every int we store)
  bstr  : i64 byte-count, then exactly that many raw bytes. On decode the Jac str
          is rebuilt by CHAR-APPEND of chr(read_byte(...)) per byte — yielding a
          properly length-stamped, NUL-safe Jac str (preserves embedded NUL).
  str_list : i64 count, then that many bstr
  int_list : i64 count, then that many i64

Grammar:
  Header:
    magic       : 4 raw bytes 'J','S','B','C'
    format_ver  : i64
    opcode_count: i64
    source_hash : i64
    fn_count    : i64                (= 1 + len(all_fns))
  Then fn_count function records, top_fn first:
    name                : bstr
    file                : bstr
    num_locals          : i64
    param_base          : i64
    arguments_slot      : i64
    expected_arg_count  : i64
    gen_prologue_end_ip : i64
    flags               : i64        (7-bit packing, see _pack_flags)
    locals              : str_list
    params              : str_list
    free_vars           : str_list
    free_var_slots      : int_list
    lexical_names       : str_list
    self_name           : bstr
    constants.values    : str_list
    code                : i64 count, then per instruction 5 i64:
                          opcode_to_int(opcode), arg, arg2, line, arg3

FORMAT VERSION: 4.  ⚠️  If you add/remove/reorder any serialized field of
CompiledFunction / Instruction / ConstantPool (op.na.jac), change the opcode
enum, or change the CJS wrapper (_cjs_wrap_source), you MUST:
  1. bump JSBC_FORMAT_VER below, and
  2. update the encode/decode field order here to match.
The header also records the Opcode enum size (JSBC_OPCODE_COUNT) so a mismatched
engine/bytecode pair is detected at load (see the runtime failure policy).

Opcodes are (de)serialized via `opcode_to_int` / `opcode_from_int` from op.na.jac
— NOT via int(Opcode), which the Jac native backend does not lower correctly for
a tagged enum (verified Phase 1; see plan doc). Those maps live next to the
`Opcode` enum; keep them exhaustive and in sync with it.
"""

import from engine.src.bytecode.op {
    Opcode,
    Instruction,
    make_instruction,
    ConstantPool,
    make_constant_pool,
    CompiledFunction,
    make_compiled_fn,
    opcode_to_int,
    opcode_from_int
}
import from engine.src.runtime.mem { io_alloc, write_byte, read_byte }
import from engine.src.runtime.jsstring { str_chars }
import from engine.src.ffi.libc { memcpy }

glob JSBC_FORMAT_VER: int = 15,
     JSBC_OPCODE_COUNT: int = 143,
     JSBC_MAGIC: str = "JSBC";  # v15: PROP_INC megaop; v14: call-family arg3 bit 3 = has-spread (VM skips _expand_spreads when clear); v13: SET_LL_PROP; v12-v10: megaops/optimizer

# 141 + SET_LL_PROP + PROP_INC
# ══════════════════════════════════════════════════════════════════════════════
# Shared CJS wrapper — MUST be byte-identical between the runtime
# (_cjs_run_in_module) and js_compiler so top_fn/all_fns match. If this changes,
# bump JSBC_FORMAT_VER (existing .jsbc become stale).
# ══════════════════════════════════════════════════════════════════════════════

"""Wrap raw CJS module source in the CommonJS function shell + invocation.
Identical to what _cjs_run_in_module compiles at runtime."""
def:pub _cjs_wrap_source(source: str) -> str {
    return (
        "var __jac_cjs_run__ = (function(exports, require, module, __filename, __dirname){\n"
        + source
        + "\n});\n"
        + "__jac_cjs_run__(exports, module.require, module, __filename, __dirname);"
    );
}

# ══════════════════════════════════════════════════════════════════════════════
# JSBCBlob — result of an encode (a raw byte buffer + its length)
# ══════════════════════════════════════════════════════════════════════════════

obj JSBCBlob {
    has ptr: int = 0,
        size: int = 0;
}

# ══════════════════════════════════════════════════════════════════════════════
# JSBCModule — result of a decode
# ══════════════════════════════════════════════════════════════════════════════

obj JSBCModule {
    has top_fn: CompiledFunction,
        all_fns: list[CompiledFunction],
        source_hash: int = 0,
        format_ver: int = 0,
        opcode_count: int = 0,
        ok: bool = False,
        err: str = "";
}


# False if magic/header failed to parse
# human-readable failure reason when ok=False
# ══════════════════════════════════════════════════════════════════════════════
# Flags bitfield pack/unpack — the 7 bool fields of CompiledFunction.
#   bit0 is_strict  bit1 is_async  bit2 is_generator  bit3 is_method
#   bit4 has_rest   bit5 is_bound  bit6 is_field_init
# ══════════════════════════════════════════════════════════════════════════════

def _pack_flags(fn: CompiledFunction) -> int {
    f: int = 0;
    if fn.is_strict {
        f = f + 1;
    }
    if fn.is_async {
        f = f + 2;
    }
    if fn.is_generator {
        f = f + 4;
    }
    if fn.is_method {
        f = f + 8;
    }
    if fn.has_rest {
        f = f + 16;
    }
    if fn.is_bound {
        f = f + 32;
    }
    if fn.is_field_init {
        f = f + 64;
    }
    return f;
}

# ══════════════════════════════════════════════════════════════════════════════
# Encoder — accumulates into a refcount-managed list[int] of bytes.
#
# CRITICAL: the accumulator is a `list[int]`, NOT a hand-grown raw io_alloc'd
# buffer. An earlier version kept a raw `int` buffer and grew it (io_alloc a
# bigger one + memcpy) once it exceeded 64 KB; that grow path SIGSEGV'd on every
# builtin whose blob crossed 64 KB (buffer/stream/http_server/events — all the
# larger ones), while files that fit in the initial buffer (path, no grow) were
# fine — and only in the optimized `make` binary, not the OPT=0 JIT. A list[int]
# sidesteps hand-rolled buffer growth entirely (append handles it), is
# refcount-managed and NUL-safe, and the raw output buffer is materialized ONCE at
# the very end (_finish) and handed straight to fwrite with no intervening
# allocation.
# ══════════════════════════════════════════════════════════════════════════════

obj JSBCWriter {
    has bytes: list[int];

    """Append one byte (0..255)."""
    def w_u8(v: int) {
        self.bytes.append(v & 255);
    }

    """Append a signed integer as a zigzag LEB128 varint. 95% of the values in a
    builtin (opcodes, args, small counts) are 0..127 and encode to a SINGLE byte —
    vs a fixed 8-byte i64 this shrinks the format ~73% and cuts decode's per-field
    read work proportionally. Zigzag maps small negatives (e.g. arg=-1) to small
    magnitudes so they stay 1 byte too.

    Implementation notes for Jac native i64: `v << 1` would overflow the signed
    i64 for large magnitudes and trip the runtime overflow check, so zigzag is
    applied 7 bits at a time. We walk the value as a two's-complement bit pattern:
    an arithmetic `v >> 7` feeds sign bits in for negatives, and each 7-bit group
    is masked out. The zigzag transform is folded in by XORing every emitted group
    with `sign & 127` (sign = 0 for non-negative, 127 after masking for negative)
    and prepending the low bit of the sign as bit 0 — equivalent to the standard
    (n<<1)^(n>>63) but overflow-free."""
    def w_i64(v: int) {
        # zigzag without a full-width shift: emit groups of the *magnitude*.
        # zz = (v << 1) ^ (v >> 63). Bit 0 of zz = sign bit of v; bits k+1 of zz =
        # bit k of (v ^ (v>>63)) i.e. of v's magnitude-ish value. We reconstruct
        # zz's 7-bit groups incrementally: carry the sign bit through.
        signbit: int = (v >> 63) & 1;  # 1 if negative
        m: int = v ^ (v >> 63);  # |v|-1 for neg, v for non-neg (>=0, no overflow)
        # zz = (m << 1) | signbit  — m is now non-negative so (m<<1) is safe up to
        # bit 63; but m can be up to 2^63-1, so (m<<1) still overflows. Emit
        # groups by shifting m (safe, non-negative) and injecting signbit as bit 0.
        first: bool = True;
        pending: int = signbit;  # bit 0 of zz
        while True {
            # take 7 zz-bits: on the first group, bit0=signbit + low 6 bits of m;
            # subsequent groups are 7 bits of m shifted appropriately.
            group: int = 0;
            if first {
                group = (pending | ((m & 63) << 1)) & 127;
                m = m >> 6;
                first = False;
            } else {
                group = m & 127;
                m = m >> 7;
            }
            if m != 0 {
                self.bytes.append(group | 128);
            } else {
                self.bytes.append(group);
            }
            if m == 0 {
                break;
            }
        }
    }

    """Append a length-prefixed byte string: i64 byte-count then each raw byte.
    Uses str_chars so the count matches the emitted byte stream (NUL-safe)."""
    def w_bstr(s: str) {
        chars: list[str] = str_chars(s);
        self.w_i64(len(chars));
        for c in chars {
            self.bytes.append(ord(c) & 255);
        }
    }

    """Append a list of bstr preceded by its i64 count."""
    def w_str_list(xs: list[str]) {
        self.w_i64(len(xs));
        for x in xs {
            self.w_bstr(x);
        }
    }

    """Append a list of i64 preceded by its i64 count."""
    def w_int_list(xs: list[int]) {
        self.w_i64(len(xs));
        for x in xs {
            self.w_i64(x);
        }
    }
}

def _make_writer -> JSBCWriter {
    # Fresh, non-shared list (see make_constant_pool for why a bare [] literal can
    # alias a shared singleton).
    b: list[int] = [0];
    del b[0];
    return JSBCWriter(bytes=b);
}

"""Serialize one CompiledFunction record. Field order is FIXED and documented in
the module grammar — do not reorder without bumping JSBC_FORMAT_VER."""
def _encode_fn(w: JSBCWriter, fn: CompiledFunction) {
    w.w_bstr(fn.name);
    w.w_bstr(fn.file);
    # The function's OWN local count: the register translator bumps
    # num_locals for its temporaries, which the decoder re-derives.
    if fn.risa == 1 {
        w.w_i64(fn.reg_tmp_base);
    } else {
        w.w_i64(fn.num_locals);
    }
    w.w_i64(fn.param_base);
    w.w_i64(fn.arguments_slot);
    w.w_i64(fn.expected_arg_count);
    w.w_i64(fn.gen_prologue_end_ip);
    w.w_i64(_pack_flags(fn));
    w.w_str_list(fn.locals);
    w.w_str_list(fn.params);
    w.w_str_list(fn.free_vars);
    w.w_int_list(fn.free_var_slots);
    w.w_str_list(fn.lexical_names);
    w.w_bstr(fn.self_name);
    w.w_str_list(fn.constants.values);
    # code: count, then 5 i64 per instruction (opcode id, arg, arg2, line, arg3)
    w.w_i64(len(fn.code));
    for ins in fn.code {
        w.w_i64(opcode_to_int(ins.opcode));
        w.w_i64(ins.arg);
        w.w_i64(ins.arg2);
        w.w_i64(ins.line);
        w.w_i64(ins.arg3);
    }
}

"""Materialize the accumulated byte list into a fresh io_alloc'd raw buffer and
return a JSBCBlob { ptr, size }. Done as the LAST step of jsbc_encode; the caller
hands ptr straight to fwrite. io_alloc is a plain calloc (no refcount header) so
the buffer is not auto-freed — the caller simply drops the reference after
writing."""
def _finish(w: JSBCWriter) -> JSBCBlob {
    n: int = len(w.bytes);
    buf: int = io_alloc(n + 1);
    i: int = 0;
    while i < n {
        write_byte(buf, i, w.bytes[i]);
        i = i + 1;
    }
    return JSBCBlob(ptr=buf, size=n);
}

"""Encode a module (top_fn + all_fns) to the .jsbc v4 packed-binary form.
Returns a JSBCBlob { ptr, size }; hand it straight to fwrite. Do NOT allocate
between this return and the fwrite: the buffer is a raw `int` pointer the GC does
not trace (see JSBCWriter's note)."""
def:pub jsbc_encode(
    top_fn: CompiledFunction, all_fns: list[CompiledFunction], source_hash: int
) -> JSBCBlob {
    w: JSBCWriter = _make_writer();
    # magic: 4 raw bytes 'J','S','B','C'
    w.w_u8(74);  # 'J'
    w.w_u8(83);  # 'S'
    w.w_u8(66);  # 'B'
    w.w_u8(67);  # 'C'
    w.w_i64(JSBC_FORMAT_VER);
    w.w_i64(JSBC_OPCODE_COUNT);
    w.w_i64(source_hash);
    fn_count: int = 1 + len(all_fns);
    w.w_i64(fn_count);
    _encode_fn(w, top_fn);
    for f in all_fns {
        _encode_fn(w, f);
    }
    return _finish(w);
}

# ══════════════════════════════════════════════════════════════════════════════
# Decoder — cursor over a FIXED raw byte buffer (mem.na.jac read_byte/read_u64).
#
# The byte source is a raw io_alloc'd buffer (ptr,len), NOT a Jac str: a binary
# blob cast to a str would be strlen-truncated at its first NUL. read_byte/read_u64
# index by explicit offset (never strlen), so embedded NUL bytes round-trip.
#
# The buffer MUST be a single FIXED allocation (no realloc/grow) — that was the
# whole earlier decoder-crash bug: a growable buffer (io_alloc-bigger + memcpy)
# corrupted mid-decode. The caller reads the whole file once into a fixed
# io_alloc(file_size+1) buffer (fs.na.jac _read_file_bytes). The backend is
# refcounting (not tracing GC), and the raw calloc buffer has no refcount header,
# so it is never freed under us mid-decode — a per-byte list[int] copy (the prior
# approach) was pure overhead and made decode the #1 startup cost (~48ms), so we
# read the buffer directly. On an out-of-bounds read the reader flips ok=False.
# ══════════════════════════════════════════════════════════════════════════════

obj JSBCReader {
    has buf: int = 0,
        len: int = 0,
        pos: int = 0,
        ok: bool = True;

    """Read one unsigned byte; advance 1. Bounds-checked."""
    def r_u8 -> int {
        if self.pos + 1 > self.len {
            self.ok = False;
            return 0;
        }
        v: int = read_byte(self.buf, self.pos);
        self.pos = self.pos + 1;
        return v;
    }

    """Read a signed zigzag-LEB128 varint (see JSBCWriter.w_i64). 95% of stored
    values are a single byte, so the common path is one read_byte + one OR. Bits
    are accumulated into `result` (bits 0..62, always non-negative so no i64
    overflow) plus a separate `bit63` flag; the final zigzag decode reconstructs
    the signed value. Validated byte-for-byte against standard zigzag LEB128 over
    the full i64 range including INT64_MIN/MAX."""
    def r_i64 -> int {
        if self.pos + 1 > self.len {
            self.ok = False;
            return 0;
        }
        # Fast path: single-byte varint (no continuation bit). ~95% of all stored
        # values. Inline the zigzag decode: for a 1-byte code the value is 0..63
        # in magnitude, so no bit63/overflow handling is needed at all.
        b0: int = read_byte(self.buf, self.pos);
        if (b0 & 128) == 0 {
            self.pos = self.pos + 1;
            if (b0 & 1) == 0 {
                return b0 >> 1;
            }
            return -((b0 >> 1) + 1);
        }
        # Slow path: multi-byte varint.
        result: int = 0;  # bits 0..62 (< 2^63, never negative)
        bit63: int = 0;
        shift: int = 0;
        while True {
            if self.pos + 1 > self.len {
                self.ok = False;
                return 0;
            }
            b: int = read_byte(self.buf, self.pos);
            self.pos = self.pos + 1;
            chunk: int = b & 127;
            if shift <= 56 {
                # all 7 bits land in bits 0..62 — the overwhelmingly common path
                result = result | (chunk << shift);
            } elif shift < 63 {
                lown: int = 63 - shift;
                result = result | ((chunk & ((1 << lown) - 1)) << shift);
                if ((chunk >> lown) & 1) != 0 {
                    bit63 = 1;
                }
            } else {
                if (chunk & 1) != 0 {
                    bit63 = 1;
                }
            }
            shift = shift + 7;
            if (b & 128) == 0 {
                break;
            }
            if shift > 70 {
                self.ok = False;
                return 0;
            }  # malformed: too long
        }
        lsb: int = result & 1;
        mag: int = result >> 1;
        if bit63 != 0 {
            mag = mag | (1 << 62);
        }
        if lsb == 0 {
            return mag;
        }
        return -(mag + 1);
    }

    """Read a length-prefixed byte string: i64 count then that many raw bytes,
    rebuilt into a properly length-stamped Jac str by char-append (NUL-safe)."""
    def r_bstr -> str {
        n: int = self.r_i64();
        if n < 0 or self.pos + n > self.len {
            self.ok = False;
            return "";
        }
        if n == 0 {
            return "";
        }
        # Copy the n-byte range into a fresh io_alloc'd (zero-filled → NUL-
        # terminated at [n]) buffer and cast it to a Jac str in ONE shot. The old
        # per-byte `chr()`+list.append+ "".join built ~3n tiny allocations per
        # string and was the single hottest function in the whole engine (~10% of
        # all instructions at startup, feeding the malloc/free churn) — every
        # identifier / string constant of every builtin flowed through it. memcpy +
        # cast is 1 alloc + 1 copy. (Mirrors _read_file_sync_str's buffer→str cast;
        # same strlen caveat: an embedded NUL would truncate — builtin identifiers
        # and string literals never contain one.)
        dst: int = io_alloc(n + 1);
        memcpy(dst, self.buf + self.pos, n);
        self.pos = self.pos + n;
        out: str = dst;  # jac:ignore[E1001] pointer reinterpret
        return out;
    }

    """Read a count-prefixed list of bstr."""
    def r_str_list -> list[str] {
        count: int = self.r_i64();
        out: list[str] = [];
        if count < 0 {
            self.ok = False;
            return out;
        }
        i: int = 0;
        while i < count and self.ok {
            out.append(self.r_bstr());
            i = i + 1;
        }
        return out;
    }

    """Read a count-prefixed list of i64."""
    def r_int_list -> list[int] {
        count: int = self.r_i64();
        out: list[int] = [];
        if count < 0 {
            self.ok = False;
            return out;
        }
        i: int = 0;
        while i < count and self.ok {
            out.append(self.r_i64());
            i = i + 1;
        }
        return out;
    }
}

# flipped False on a bounds violation
def _make_reader(buf: int, blen: int) -> JSBCReader {
    return JSBCReader(buf=buf, len=blen, pos=0, ok=True);
}

"""Decode one CompiledFunction record. Field order must match _encode_fn."""
def _decode_fn(r: JSBCReader) -> CompiledFunction {
    name: str = r.r_bstr();
    file: str = r.r_bstr();
    fn: CompiledFunction = make_compiled_fn(name, file);
    # .jsbc ships pre-optimized bytecode (the optimizer ran at precompile
    # inside compile → _pop_fn); mark it so runtime paths never re-run
    # the pass on decoded functions.
    fn.optimized = 1;
    fn.num_locals = r.r_i64();
    fn.param_base = r.r_i64();
    fn.arguments_slot = r.r_i64();
    fn.expected_arg_count = r.r_i64();
    fn.gen_prologue_end_ip = r.r_i64();
    flags: int = r.r_i64();
    fn.is_strict = (flags & 1) != 0;
    fn.is_async = (flags & 2) != 0;
    fn.is_generator = (flags & 4) != 0;
    fn.is_method = (flags & 8) != 0;
    fn.has_rest = (flags & 16) != 0;
    fn.is_bound = (flags & 32) != 0;
    fn.is_field_init = (flags & 64) != 0;
    fn.locals = r.r_str_list();
    fn.params = r.r_str_list();
    fn.free_vars = r.r_str_list();
    fn.free_var_slots = r.r_int_list();
    fn.lexical_names = r.r_str_list();
    fn.self_name = r.r_bstr();
    # constants → rebuild ConstantPool
    const_vals: list[str] = r.r_str_list();
    pool: ConstantPool = make_constant_pool();
    for cv in const_vals {
        pool.values.append(cv);
    }
    fn.constants = pool;
    # code
    code_count: int = r.r_i64();
    code: list[Instruction] = [];
    ci: int = 0;
    while ci < code_count and r.ok {
        op_id: int = r.r_i64();
        arg: int = r.r_i64();
        arg2: int = r.r_i64();
        line: int = r.r_i64();
        arg3: int = r.r_i64();
        op: Opcode = opcode_from_int(op_id);
        if op == Opcode.TAIL_CALL {
            fn.has_tail_call = True;
        }
        code.append(make_instruction(op, arg, arg2, line, arg3));
        ci = ci + 1;
    }
    fn.code = code;
    # Register ISA: the .jsbc ships the (optimized) stack code; the register
    # form is derived lazily when the function first runs (VM._reg_ready).
    return fn;
}

"""Decode a .jsbc v4 binary blob (a FIXED raw byte buffer ptr + length) into a
JSBCModule. On a header/magic mismatch or a bounds violation, returns a module
with ok=False and err set (caller enforces the failure policy). The buffer must be
a single fixed allocation the caller keeps referenced (fs.na.jac _read_file_bytes);
it is read by explicit offset and never freed under us (refcounting backend, no rc
header on the calloc buffer)."""
def:pub jsbc_decode(buf: int, blen: int) -> JSBCModule {
    r: JSBCReader = _make_reader(buf, blen);
    empty_fn: CompiledFunction = make_compiled_fn("", "");
    mod: JSBCModule = JSBCModule(
        top_fn=empty_fn,
        all_fns=[],
        source_hash=0,
        format_ver=0,
        opcode_count=0,
        ok=False,
        err=""
    );
    # magic: 4 raw bytes 'J','S','B','C'
    m0: int = r.r_u8();
    m1: int = r.r_u8();
    m2: int = r.r_u8();
    m3: int = r.r_u8();
    if m0 != 74 or m1 != 83 or m2 != 66 or m3 != 67 {
        mod.err = "bad magic: expected JSBC";
        return mod;
    }
    mod.format_ver = r.r_i64();
    mod.opcode_count = r.r_i64();
    # Reject a stale/newer format BEFORE decoding any function: the per-function
    # field layout is version-specific, so decoding a mismatched blob would read
    # fields at the wrong offsets and desync the reader. Caller enforces the miss
    # policy (parse fallback / regenerate) off ok=False.
    if mod.format_ver != JSBC_FORMAT_VER or mod.opcode_count != JSBC_OPCODE_COUNT {
        mod.err = "format/opcode-count mismatch (stale .jsbc)";
        return mod;
    }
    mod.source_hash = r.r_i64();
    fn_count: int = r.r_i64();
    if fn_count < 1 {
        mod.err = "fn_count < 1";
        return mod;
    }
    mod.top_fn = _decode_fn(r);
    rest: list[CompiledFunction] = [];
    i: int = 1;
    while i < fn_count and r.ok {
        rest.append(_decode_fn(r));
        i = i + 1;
    }
    mod.all_fns = rest;
    if not r.ok {
        mod.err = "truncated/corrupt .jsbc (read past end)";
        return mod;
    }
    mod.ok = True;
    return mod;
}
