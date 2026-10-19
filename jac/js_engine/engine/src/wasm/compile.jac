"""WebAssembly binary decoder, validator and code generator (Jac native).

compile_module(ptr, len) decodes and validates a module and lowers every
function body to the interpreter's internal code (see exec.jac). Errors are
reported through wasm_compile_error(): "" on success, otherwise a message
prefixed "malformed: " (decode errors) or "invalid: " (validation errors).

Internal code
-------------
Each function compiles to a flat array of 64-bit words in raw memory. The
operand stack is resolved statically: validation knows the stack height at
every instruction, so operands are fixed frame slots (byte offsets from the
frame pointer) and there is no push/pop at run time. A frame is
    slot 0 .. nparams-1           params
    slot nparams .. nlocals-1     declared locals (zeroed on entry)
    slot nlocals ..               operand stack
A call's arguments are the top `nparams` operand slots; the callee's frame
starts right there, so arguments become its params without copying and its
results land where the caller expects them.

Op numbering: memory and numeric instructions keep their wasm opcode
(0x28..0x3e loads/stores, 0x45..0xc4 numeric); control and other ops use the
internal numbers below; 0xfc-prefixed ops are 0xe0 + subopcode.
"""

import from engine.src.runtime.mem { io_alloc, io_free }

# ── Value types (wasm binary type bytes) ─────────────────────────────────────
# i32=0x7f  i64=0x7e  f32=0x7d  f64=0x7c  funcref=0x70  externref=0x6f
glob:pub T_I32: int = 127,
     T_I64: int = 126,
     T_F32: int = 125,
     T_F64: int = 124,
     T_FUNCREF: int = 112,
     T_EXTERNREF: int = 111;
glob T_UNKNOWN: int = 0;  # polymorphic stack bottom

# ── Internal opcodes (keep in sync with exec.jac dispatch) ─────────────────
glob:pub OP_UNREACHABLE: int = 0,
     OP_JMP: int = 2,
     OP_BR_IF: int = 3,
     OP_BR_UNLESS: int = 4,
     OP_BR_TABLE: int = 5,
     OP_RET: int = 6,
     OP_CALL: int = 7,
     OP_CALL_INDIRECT: int = 8,
     OP_COPY: int = 9,
     OP_CONST: int = 10,
     OP_SELECT: int = 11,
     OP_GLOBAL_GET: int = 12,
     OP_GLOBAL_SET: int = 13,
     OP_TABLE_GET: int = 14,
     OP_TABLE_SET: int = 15,
     OP_REF_IS_NULL: int = 16,
     OP_REF_FUNC: int = 17,
     OP_MEM_SIZE: int = 18,
     OP_MEM_GROW: int = 19,
     OP_FC: int = 224,
     EXT_FUNC: int = 0,
     EXT_TABLE: int = 1,
     EXT_MEMORY: int = 2,
     EXT_GLOBAL: int = 3,
     CE_CONST: int = 0,
     CE_GLOBAL_GET: int = 1,
     CE_REF_NULL: int = 2,
     CE_REF_FUNC: int = 3;

# tgt
# c tgt            jump if slot c != 0
# c tgt            jump if slot c == 0
# i n tgt*(n+1)
# src n            results fp+src.. -> fp..
# fidx argoff
# tidx typeid argoff elemslot
# dst src
# dst value
# dst a b c
# dst g
# g src
# dst t i
# t i v
# dst a
# dst fidx
# dst
# dst              (dst also holds delta)
# 0xe0 + fc subopcode

# ── Module representation ────────────────────────────────────────────────────

# Constant expression kinds.
# value = bits (f32 stored as double bits)
# value = global index

# value = func index
obj:pub FuncType {
    has params: list[int] = [],
        results: list[int] = [];
}

obj:pub WImport {
    has module: str = "",
        name: str = "",
        kind: int = 0,
        index: int = 0;
}

# func: type index; table/memory/global: index in its space
obj:pub WExport {
    has name: str = "",
        kind: int = 0,
        index: int = 0;
}

obj:pub WTable {
    has elem: int = 112,
        min: int = 0,
        max: int = -1;
}

obj:pub WGlobal {
    has vtype: int = 127,
        mutable: bool = False,
        ce_kind: int = 0,
        ce_value: int = 0;
}

obj:pub WElem {
    has mode: int = 0,
        table: int = 0,
        off_kind: int = 0,
        off_value: int = 0,
        etype: int = 112,
        ce_kinds: list[int] = [],
        ce_values: list[int] = [];  # 0 active, 1 passive, 2 declarative
}

# per element: CE_REF_FUNC / CE_REF_NULL / CE_GLOBAL_GET
obj:pub WData {
    has mode: int = 0,
        memory: int = 0,
        off_kind: int = 0,
        off_value: int = 0,
        ptr: int = 0,
        size: int = 0;  # 0 active, 1 passive
}

# into the module's own copy of the bytes
obj:pub WFunc {
    has type_index: int = 0,
        code: int = 0,
        code_words: int = 0,
        nlocals: int = 0,
        max_slots: int = 0;
}

# raw word array (0 for imports)

# params + declared locals
obj:pub WModule {
    has bytes: int = 0,
        nbytes: int = 0,
        types: list[FuncType] = [],
        imports: list[WImport] = [],
        funcs: list[WFunc] = [],
        n_imported_funcs: int = 0,
        tables: list[WTable] = [],
        n_imported_tables: int = 0,
        mem_min: list[int] = [],
        mem_max: list[int] = [],
        n_imported_mems: int = 0,
        globals: list[WGlobal] = [],
        n_imported_globals: int = 0,
        exports: list[WExport] = [],
        start: int = -1,
        elems: list[WElem] = [],
        datas: list[WData] = [],
        data_count: int = -1;  # owned copy of the module bytes
}

# imported first, then defined
# ── Errors ───────────────────────────────────────────────────────────────────
glob _ERR: str = "",
     _ERR_POS: int = 0,
     _NEED_DC: bool = False;

# memory.init / data.drop seen without a data count section: malformed if the
# module has a data section, else the segment index is simply unknown.
def:pub wasm_compile_error -> str {
    return _ERR;
}
def:pub wasm_compile_error_pos -> int {
    return _ERR_POS;
}

def _malformed(msg: str) {
    if _ERR == "" {
        _ERR = "malformed: " + msg;
        _ERR_POS = _RP;
    }
}

def _invalid(msg: str) {
    if _ERR == "" {
        _ERR = "invalid: " + msg;
        _ERR_POS = _RP;
    }
}

# ── Reader ───────────────────────────────────────────────────────────────────
# _RB buffer, _RP position (offset), _RE end offset of the current (sub)range
glob _RB: int = 0,
     _RP: int = 0,
     _RE: int = 0;

def _u8 -> int {
    if _RP >= _RE {
        _malformed("unexpected end");
        return 0;
    }
    b: int = int(__mem_load_i8(_RB + _RP)) & 255;
    _RP = _RP + 1;
    return b;
}

"""Unsigned LEB128 of at most `bits` bits."""
def _uleb(bits: int) -> int {
    result: int = 0;
    shift: int = 0;
    maxbytes: int = (bits + 6) // 7;
    i: int = 0;
    while True {
        if _RP >= _RE {
            _malformed("unexpected end");
            return 0;
        }
        b: int = int(__mem_load_i8(_RB + _RP)) & 255;
        _RP = _RP + 1;
        i = i + 1;
        if i == maxbytes {
            # Last allowed byte: no continuation and no bits beyond `bits`.
            if (b & 128) != 0 {
                _malformed("integer representation too long");
                return 0;
            }
            used: int = bits - shift;
            if used < 7 and (b >> used) != 0 {
                _malformed("integer too large");
                return 0;
            }
        }
        result = result | ((b & 127) << shift);
        if (b & 128) == 0 {
            break;
        }
        shift = shift + 7;
    }
    return result;
}

def _u32 -> int {
    return _uleb(32);
}

"""Signed LEB128 of at most `bits` bits, returned sign-extended."""
def _sleb(bits: int) -> int {
    result: int = 0;
    shift: int = 0;
    maxbytes: int = (bits + 6) // 7;
    i: int = 0;
    b: int = 0;
    while True {
        if _RP >= _RE {
            _malformed("unexpected end");
            return 0;
        }
        b = int(__mem_load_i8(_RB + _RP)) & 255;
        _RP = _RP + 1;
        i = i + 1;
        if i == maxbytes {
            if (b & 128) != 0 {
                _malformed("integer representation too long");
                return 0;
            }
            # Remaining bits must all be copies of the sign bit.
            used: int = bits - shift;  # payload bits that may come from this byte
            if used < 7 {
                rest: int = (b & 127) >> (used - 1);  # sign bit and above
                if rest != 0 and rest != (127 >> (used - 1)) {
                    _malformed("integer too large");
                    return 0;
                }
            }
        }
        result = result | ((b & 127) << shift);
        shift = shift + 7;
        if (b & 128) == 0 {
            break;
        }
    }
    if shift < 64 and (b & 64) != 0 {
        result = result | ((0 - 1) << shift);
    }
    if bits == 32 {
        result = int(i32.wrap(result));
    }
    return result;
}

def _f32bits -> int {
    if _RP + 4 > _RE {
        _malformed("unexpected end");
        _RP = _RE;
        return 0;
    }
    v: int = int(__mem_load_i32(_RB + _RP)) & 4294967295;
    _RP = _RP + 4;
    return v;
}

def _f64bits -> int {
    if _RP + 8 > _RE {
        _malformed("unexpected end");
        _RP = _RE;
        return 0;
    }
    v: int = __mem_load_i64(_RB + _RP);
    _RP = _RP + 8;
    return v;
}

"""Decode a UTF-8 name of `n` bytes at the cursor into a str (validating)."""
def _name -> str {
    n: int = _u32();
    if _ERR != "" {
        return "";
    }
    if _RP + n > _RE {
        _malformed("unexpected end");
        _RP = _RE;
        return "";
    }
    out: str = "";
    end: int = _RP + n;
    while _RP < end {
        b0: int = int(__mem_load_i8(_RB + _RP)) & 255;
        cp: int = 0;
        extra: int = 0;
        if b0 < 128 {
            cp = b0;
            extra = 0;
        } elif b0 >= 194 and b0 < 224 {
            cp = b0 & 31;
            extra = 1;
        } elif b0 >= 224 and b0 < 240 {
            cp = b0 & 15;
            extra = 2;
        } elif b0 >= 240 and b0 < 245 {
            cp = b0 & 7;
            extra = 3;
        } else {
            _malformed("malformed UTF-8 encoding");
            _RP = end;
            return "";
        }
        if _RP + 1 + extra > end {
            _malformed("malformed UTF-8 encoding");
            _RP = end;
            return "";
        }
        k: int = 1;
        while k <= extra {
            bk: int = int(__mem_load_i8(_RB + _RP + k)) & 255;
            if (bk & 192) != 128 {
                _malformed("malformed UTF-8 encoding");
                _RP = end;
                return "";
            }
            cp = (cp << 6) | (bk & 63);
            k = k + 1;
        }
        if (extra == 2 and (cp < 2048 or (cp >= 55296 and cp < 57344)))
            or (extra == 3 and (cp < 65536 or cp > 1114111)) {
            _malformed("malformed UTF-8 encoding");
            _RP = end;
            return "";
        }
        if cp == 0 {
            # Jac str is a C string (no embedded NUL). Store the engine's
            # 4-char NUL sentinel so the name round-trips through str_intern
            # back to a real U+0000 in the JS string table.
            out = out + "\\x00";
        } else {
            out = out + chr(cp);
        }
        _RP = _RP + 1 + extra;
    }
    return out;
}

def _valtype -> int {
    t: int = _u8();
    if t == 127 or t == 126 or t == 125 or t == 124 or t == 112 or t == 111 {
        return t;
    }
    if _ERR == "" {
        _malformed("malformed value type");
    }
    return 0;
}

def _reftype -> int {
    t: int = _u8();
    if t == 112 or t == 111 {
        return t;
    }
    if _ERR == "" {
        _malformed("malformed reference type");
    }
    return 0;
}

def _is_num(t: int) -> bool {
    return t == 127 or t == 126 or t == 125 or t == 124;
}
def _is_ref(t: int) -> bool {
    return t == 112 or t == 111;
}

"""Limits: returns [min, max] (max = -1 when absent)."""
def _limits(is_memory: bool) -> list[int] {
    flag: int = _u8();
    if flag > 1 {
        if is_memory and (flag == 2 or flag == 3) {
            _malformed("shared memory");
        } else {
            _malformed("integer too large");
        }
        return [0, -1];
    }
    mn: int = _u32();
    mx: int = -1;
    if flag == 1 {
        mx = _u32();
    }
    return [mn, mx];
}

# ── Constant expressions ─────────────────────────────────────────────────────
glob _CE_KIND: int = 0,
     _CE_VALUE: int = 0;

"""Read one constant expression of type `want`; result in _CE_KIND/_CE_VALUE.
`nglobals` is how many globals are visible (imported ones only, for globals;
all imported for offsets)."""
def _const_expr(m: WModule, want: int, nglobals: int, funcs_total: int) -> None {
    op: int = _u8();
    got: int = 0;
    if op == 65 {
        _CE_KIND = CE_CONST;
        _CE_VALUE = _sleb(32);
        got = T_I32;
    } elif op == 66 {
        _CE_KIND = CE_CONST;
        _CE_VALUE = _sleb(64);
        got = T_I64;
    } elif op == 67 {
        _CE_KIND = CE_CONST;
        _CE_VALUE = __float_bits(f32_bits_to_f64(_f32bits()));
        got = T_F32;
    } elif op == 68 {
        _CE_KIND = CE_CONST;
        _CE_VALUE = _f64bits();
        got = T_F64;
    } elif op == 208 {
        _CE_KIND = CE_REF_NULL;
        _CE_VALUE = 0;
        got = _reftype();
    } elif op == 210 {
        _CE_KIND = CE_REF_FUNC;
        _CE_VALUE = _u32();
        got = T_FUNCREF;
        if _ERR == "" and _CE_VALUE >= funcs_total {
            _invalid("unknown function " + str(_CE_VALUE));
        } else {
            _declare_ref(_CE_VALUE);
        }
    } elif op == 35 {
        _CE_KIND = CE_GLOBAL_GET;
        _CE_VALUE = _u32();
        if _ERR != "" {
            return;
        }
        if _CE_VALUE >= len(m.globals) {
            _invalid("unknown global " + str(_CE_VALUE));
            return;
        }
        if _CE_VALUE >= nglobals {
            _invalid("unknown global " + str(_CE_VALUE));
            return;
        }
        g: WGlobal = m.globals[_CE_VALUE];
        if g.mutable {
            _invalid("constant expression required");
            return;
        }
        got = g.vtype;
    } elif op == 11 {
        _invalid("type mismatch");
        return;
    } else {
        if _ERR == "" {
            if _is_known_op(op) {
                _invalid("constant expression required");
            } else {
                _malformed("illegal opcode");
            }
        }
        return;
    }
    if _ERR != "" {
        return;
    }
    nxt: int = _u8();
    if _ERR != "" {
        return;
    }
    if nxt != 11 {
        if _is_known_op(nxt) {
            _invalid("constant expression required");
        } else {
            _malformed("illegal opcode");
        }
        return;
    }
    if got != want {
        _invalid("type mismatch");
    }
}

def _is_known_op(op: int) -> bool {
    return op <= 17
        or op == 26
        or op == 27
        or op == 28
        or (op >= 32 and op <= 38)
        or (op >= 40 and op <= 196)
        or op == 208
        or op == 209
        or op == 210
        or op == 252;
}

# Functions referenced outside code (C.refs) — ref.func in bodies must be here.
glob _DECLARED: list[int] = [];

def _declare_ref(fidx: int) {
    while len(_DECLARED) <= fidx {
        _DECLARED.append(0);
    }
    _DECLARED[fidx] = 1;
}

def _is_declared(fidx: int) -> bool {
    return fidx < len(_DECLARED) and _DECLARED[fidx] == 1;
}

# ── f32 bit helpers shared with exec (payload-preserving) ───────────────────

# The i64 sign bit. Shifting a 1 into bit 63 can trip the native overflow
# check, so sign bits are OR-ed in from this constant instead.
glob:pub SIGN64: int = -9223372036854775807 - 1;

def _sign64(s: int) -> int {
    if s != 0 {
        return SIGN64;
    }
    return 0;
}

"""The double of the f32 with bits `b` (low 32 bits). NaN payloads (and the
signaling bit) are kept, shifted into the double's mantissa, so
f64_to_f32_bits returns the original bits."""
def:pub f32_bits_to_f64(b: int) -> float {
    sign: int = (b >> 31) & 1;
    e: int = (b >> 23) & 255;
    frac: int = b & 8388607;
    if e == 255 {
        return __bits_float(_sign64(sign) | (2047 << 52) | (frac << 29));
    }
    if e == 0 {
        if frac == 0 {
            return __bits_float(_sign64(sign));
        }
        # subnormal: frac * 2^-149, exact in a double
        v: float = float(frac) * 1.401298464324817e-45;
        if sign == 1 {
            return 0.0 - v;
        }
        return v;
    }
    return __bits_float(_sign64(sign) | ((e - 127 + 1023) << 52) | (frac << 29));
}

"""Bits of an f32-representable double (as produced by f32 arithmetic or
f32_bits_to_f64). NaN payloads are kept."""
def:pub f64_to_f32_bits(d: float) -> int {
    db: int = __float_bits(d);
    sign: int = (db >> 63) & 1;
    e: int = (db >> 52) & 2047;
    frac: int = db & 4503599627370495;
    if e == 2047 {
        f: int = frac >> 29;
        if frac != 0 and f == 0 {
            f = 4194304;
        }
        return (sign << 31) | 2139095040 | f;
    }
    if e == 0 {
        return sign << 31;
    }
    fe: int = e - 1023 + 127;
    if fe > 0 {
        return (sign << 31) | (fe << 23) | (frac >> 29);
    }
    # f32 subnormal: magnitude / 2^-149 is an exact integer
    mag: float = __bits_float(db & 9223372036854775807);
    return (sign << 31) | int(mag * 7.1362384635297994e+44);
}

# ── Numeric opcode signatures (0x45..0xc4) ───────────────────────────────────
glob _SIG_A: list[int] = [],
     _SIG_B: list[int] = [],
     _SIG_R: list[int] = [],
     _SIG_READY: bool = False;  # first operand type (0 = none)

# second operand type (0 = unary)
# result type
def _sig(op: int, a: int, b: int, r: int) {
    _SIG_A[op] = a;
    _SIG_B[op] = b;
    _SIG_R[op] = r;
}

def _sig_range(lo: int, hi: int, a: int, b: int, r: int) {
    op: int = lo;
    while op <= hi {
        _sig(op, a, b, r);
        op = op + 1;
    }
}

def _init_sigs -> None {
    if _SIG_READY {
        return;
    }
    i: int = 0;
    while i < 256 {
        _SIG_A.append(0);
        _SIG_B.append(0);
        _SIG_R.append(0);
        i = i + 1;
    }
    I: int = T_I32;
    L: int = T_I64;
    F: int = T_F32;
    D: int = T_F64;
    _sig(69, I, 0, I);  # i32.eqz
    _sig_range(70, 79, I, I, I);  # i32 compares
    _sig(80, L, 0, I);  # i64.eqz
    _sig_range(81, 90, L, L, I);  # i64 compares
    _sig_range(91, 96, F, F, I);  # f32 compares
    _sig_range(97, 102, D, D, I);  # f64 compares
    _sig_range(103, 105, I, 0, I);  # i32 clz ctz popcnt
    _sig_range(106, 120, I, I, I);  # i32 binops
    _sig_range(121, 123, L, 0, L);  # i64 clz ctz popcnt
    _sig_range(124, 138, L, L, L);  # i64 binops
    _sig_range(139, 145, F, 0, F);  # f32 unops
    _sig_range(146, 152, F, F, F);  # f32 binops
    _sig_range(153, 159, D, 0, D);  # f64 unops
    _sig_range(160, 166, D, D, D);  # f64 binops
    _sig(167, L, 0, I);  # i32.wrap_i64
    _sig(168, F, 0, I);
    _sig(169, F, 0, I);
    _sig(170, D, 0, I);
    _sig(171, D, 0, I);
    _sig(172, I, 0, L);
    _sig(173, I, 0, L);
    _sig(174, F, 0, L);
    _sig(175, F, 0, L);
    _sig(176, D, 0, L);
    _sig(177, D, 0, L);
    _sig(178, I, 0, F);
    _sig(179, I, 0, F);
    _sig(180, L, 0, F);
    _sig(181, L, 0, F);
    _sig(182, D, 0, F);
    _sig(183, I, 0, D);
    _sig(184, I, 0, D);
    _sig(185, L, 0, D);
    _sig(186, L, 0, D);
    _sig(187, F, 0, D);
    _sig(188, F, 0, I);
    _sig(189, D, 0, L);
    _sig(190, I, 0, F);
    _sig(191, L, 0, D);
    _sig(192, I, 0, I);
    _sig(193, I, 0, I);
    _sig(194, L, 0, L);
    _sig(195, L, 0, L);
    _sig(196, L, 0, L);
    _SIG_READY = True;
}

# ── Function body compiler state ─────────────────────────────────────────────
glob _C: list[int] = [],
     _TS: list[int] = [],
     _MAXH: int = 0,
     _NLOC: int = 0,
     _LT: list[int] = [],
     _CK: list[int] = [],
     _CH: list[int] = [],
     _CP: list[list[int]] = [],
     _CR: list[list[int]] = [],
     _CU: list[bool] = [],
     _CD: list[bool] = [],
     _CL: list[int] = [],
     _CF: list[list[int]] = [],
     _CE: list[int] = [];  # emitted words

# operand type stack
# max operand stack height
# params + locals
# local types
# Control frames (parallel lists).
# kind: 0 block, 1 loop, 2 if, 3 else, 4 func
# operand height at entry (below params)
# param types
# result types
# unreachable (validation: stack is polymorphic)
# dead: inside unreachable code, emit nothing
# loop start (word index)
# fixup word positions -> end
# if: position of the BR_UNLESS target word (-1 none)
def _emit(w: int) {
    _C.append(w);
}

def _slot(h: int) -> int {
    return (_NLOC + h) * 8;
}

def _push(t: int) {
    _TS.append(t);
    if len(_TS) > _MAXH {
        _MAXH = len(_TS);
    }
}

def _pop_any -> int {
    top: int = len(_CK) - 1;
    if len(_TS) == _CH[top] {
        if _CU[top] {
            return T_UNKNOWN;
        }
        _invalid("type mismatch");
        return T_UNKNOWN;
    }
    return _TS.pop();
}

def _pop(want: int) -> int {
    got: int = _pop_any();
    if got != want and got != T_UNKNOWN and want != T_UNKNOWN {
        _invalid("type mismatch");
    }
    return got;
}

"""True when no code should be emitted at this point."""
def _unreachable -> bool {
    return _CU[len(_CU) - 1] or _CD[len(_CD) - 1];
}

def _set_unreachable {
    top: int = len(_CK) - 1;
    while len(_TS) > _CH[top] {
        _TS.pop();
    }
    _CU[top] = True;
}

def _push_ctrl(kind: int, params: list[int], results: list[int]) {
    _CK.append(kind);
    _CH.append(len(_TS));
    _CP.append(params);
    _CR.append(results);
    dead: bool = False;
    if len(_CU) > 0 {
        dead = _CU[len(_CU) - 1] or _CD[len(_CD) - 1];
    }
    _CU.append(False);
    _CD.append(dead);
    _CL.append(len(_C));
    _CF.append([]);
    _CE.append(-1);
    for t in params {
        _push(t);
    }
}

def _label_types(depth: int) -> list[int] {
    i: int = len(_CK) - 1 - depth;
    if _CK[i] == 1 {
        return _CP[i];
    }
    return _CR[i];
}

"""Pop the label's types and push them back: the label's own types for
br/br_if (their result type), the popped ones for br_table (so differing
label types still check against a polymorphic stack)."""
def _check_label_values(types: list[int], keep_popped: bool) {
    n: int = len(types);
    popped: list[int] = [];
    k: int = n - 1;
    while k >= 0 {
        popped.append(_pop(types[k]));
        k = k - 1;
    }
    k = n - 1;
    while k >= 0 {
        if keep_popped {
            _push(popped[k]);
        } else {
            _push(types[n - 1 - k]);
        }
        k = k - 1;
    }
}

"""Emit the slot moves for a branch to label `depth` (values on top of the
current stack go to the label's base) and the jump itself."""
def _emit_branch_moves(depth: int) {
    i: int = len(_CK) - 1 - depth;
    types: list[int] = _label_types(depth);
    n: int = len(types);
    src: int = len(_TS) - n;
    dst: int = _CH[i];
    if src != dst {
        k: int = 0;
        while k < n {
            _emit(OP_COPY);
            _emit(_slot(dst + k));
            _emit(_slot(src + k));
            k = k + 1;
        }
    }
}

def _emit_jump_to(depth: int) {
    i: int = len(_CK) - 1 - depth;
    _emit(OP_JMP);
    if _CK[i] == 1 {
        _emit(_CL[i]);
    } else {
        _CF[i].append(len(_C));
        _emit(0);
    }
}

"""True when a branch to `depth` needs no slot moves."""
def _branch_is_direct(depth: int) -> bool {
    i: int = len(_CK) - 1 - depth;
    n: int = len(_label_types(depth));
    return n == 0 or len(_TS) - n == _CH[i];
}

def _target_word(depth: int, pos: int) {
    i: int = len(_CK) - 1 - depth;
    if _CK[i] == 1 {
        _C[pos] = _CL[i];
    } else {
        _CF[i].append(pos);
    }
}

"""Block type: returns [params, results]."""
glob _BT_P: list[int] = [];
glob _BT_R: list[int] = [];

def _blocktype(m: WModule) -> None {
    _BT_P = [];
    _BT_R = [];
    if _RP >= _RE {
        _malformed("unexpected end");
        return;
    }
    b: int = int(__mem_load_i8(_RB + _RP)) & 255;
    if b == 64 {
        _RP = _RP + 1;
        return;
    }
    if b == 127 or b == 126 or b == 125 or b == 124 or b == 112 or b == 111 {
        _RP = _RP + 1;
        _BT_R = [b];
        return;
    }
    idx: int = _sleb(33);
    if _ERR != "" {
        return;
    }
    if idx < 0 or idx >= len(m.types) {
        _invalid("unknown type");
        return;
    }
    ft: FuncType = m.types[idx];
    for t in ft.params {
        _BT_P.append(t);
    }
    for t in ft.results {
        _BT_R.append(t);
    }
}

def _memarg(m: WModule, width: int) -> int {
    align: int = _u32();
    off: int = _u32();
    if _ERR != "" {
        return 0;
    }
    if len(m.mem_min) == 0 {
        _invalid("unknown memory 0");
        return 0;
    }
    if align >= 32 or (1 << align) > width {
        _invalid("alignment must not be larger than natural");
    }
    return off;
}

def _need_mem(m: WModule) {
    if len(m.mem_min) == 0 {
        _invalid("unknown memory 0");
    }
}

def _table_type(m: WModule, t: int) -> int {
    if t >= len(m.tables) {
        _invalid("unknown table " + str(t));
        return T_FUNCREF;
    }
    return m.tables[t].elem;
}

def _func_type(m: WModule, fidx: int) -> FuncType {
    return m.types[m.funcs[fidx].type_index];
}

def _load_width(op: int) -> int {
    if op == 40 or op == 42 or op == 52 or op == 53 {
        return 4;
    }
    if op == 41 or op == 43 {
        return 8;
    }
    if op == 44 or op == 45 or op == 48 or op == 49 {
        return 1;
    }
    if op == 46 or op == 47 or op == 50 or op == 51 {
        return 2;
    }
    return 4;
}

def _load_type(op: int) -> int {
    if op == 40 or (op >= 44 and op <= 47) {
        return T_I32;
    }
    if op == 42 {
        return T_F32;
    }
    if op == 43 {
        return T_F64;
    }
    return T_I64;
}

def _store_width(op: int) -> int {
    if op == 54 or op == 56 or op == 62 {
        return 4;
    }
    if op == 55 or op == 57 {
        return 8;
    }
    if op == 58 or op == 60 {
        return 1;
    }
    return 2;
}

def _store_type(op: int) -> int {
    if op == 54 or op == 58 or op == 59 {
        return T_I32;
    }
    if op == 56 {
        return T_F32;
    }
    if op == 57 {
        return T_F64;
    }
    return T_I64;
}

"""Compile one function body (cursor at the body's locals, _RE at its end)."""
def _compile_body(m: WModule, fidx: int) -> None {
    f: WFunc = m.funcs[fidx];
    ft: FuncType = m.types[f.type_index];
    _C = [];
    _TS = [];
    _MAXH = 0;
    _LT = [];
    for t in ft.params {
        _LT.append(t);
    }
    # Locals
    ngroups: int = _u32();
    total: int = len(ft.params);
    g: int = 0;
    while g < ngroups and _ERR == "" {
        cnt: int = _u32();
        if _ERR != "" {
            return;
        }
        if cnt > 50000 or total + cnt > 50000 {
            _malformed("too many locals");
            return;
        }
        t: int = _valtype();
        if _ERR != "" {
            return;
        }
        k: int = 0;
        while k < cnt {
            _LT.append(t);
            k = k + 1;
        }
        total = total + cnt;
        g = g + 1;
    }
    if _ERR != "" {
        return;
    }
    _NLOC = total;
    _CK = [];
    _CH = [];
    _CP = [];
    _CR = [];
    _CU = [];
    _CD = [];
    _CL = [];
    _CF = [];
    _CE = [];
    _push_ctrl(4, [], ft.results);

    while len(_CK) > 0 and _ERR == "" {
        if _RP >= _RE {
            _malformed("unexpected end of section or function");
            return;
        }
        op: int = _u8();
        if op >= 69 and op <= 196 {
            # numeric
            a: int = _SIG_A[op];
            b: int = _SIG_B[op];
            if b != 0 {
                _pop(b);
                _pop(a);
                h: int = len(_TS);
                _push(_SIG_R[op]);
                if not _unreachable() {
                    _emit(op);
                    _emit(_slot(h));
                    _emit(_slot(h));
                    _emit(_slot(h + 1));
                }
            } else {
                _pop(a);
                h1: int = len(_TS);
                _push(_SIG_R[op]);
                if not _unreachable() {
                    _emit(op);
                    _emit(_slot(h1));
                    _emit(_slot(h1));
                }
            }
        } elif op == 32 {  # local.get
            x: int = _u32();
            if _ERR != "" {
                return;
            }
            if x >= _NLOC {
                _invalid("unknown local " + str(x));
                return;
            }
            h2: int = len(_TS);
            _push(_LT[x]);
            if not _unreachable() {
                _emit(OP_COPY);
                _emit(_slot(h2));
                _emit(x * 8);
            }
        } elif op == 33 {  # local.set
            x2: int = _u32();
            if _ERR != "" {
                return;
            }
            if x2 >= _NLOC {
                _invalid("unknown local " + str(x2));
                return;
            }
            _pop(_LT[x2]);
            if not _unreachable() {
                _emit(OP_COPY);
                _emit(x2 * 8);
                _emit(_slot(len(_TS)));
            }
        } elif op == 34 {  # local.tee
            x3: int = _u32();
            if _ERR != "" {
                return;
            }
            if x3 >= _NLOC {
                _invalid("unknown local " + str(x3));
                return;
            }
            _pop(_LT[x3]);
            _push(_LT[x3]);
            if not _unreachable() {
                _emit(OP_COPY);
                _emit(x3 * 8);
                _emit(_slot(len(_TS) - 1));
            }
        } elif op >= 65 and op <= 68 {  # consts
            v: int = 0;
            t2: int = T_I32;
            if op == 65 {
                v = _sleb(32);
            } elif op == 66 {
                v = _sleb(64);
                t2 = T_I64;
            } elif op == 67 {
                v = __float_bits(f32_bits_to_f64(_f32bits()));
                t2 = T_F32;
            } else {
                v = _f64bits();
                t2 = T_F64;
            }
            h3: int = len(_TS);
            _push(t2);
            if not _unreachable() {
                _emit(OP_CONST);
                _emit(_slot(h3));
                _emit(v);
            }
        } elif op >= 40 and op <= 53 {  # loads
            off: int = _memarg(m, _load_width(op));
            _pop(T_I32);
            h4: int = len(_TS);
            _push(_load_type(op));
            if not _unreachable() {
                _emit(op);
                _emit(_slot(h4));
                _emit(_slot(h4));
                _emit(off);
            }
        } elif op >= 54 and op <= 62 {  # stores
            off2: int = _memarg(m, _store_width(op));
            _pop(_store_type(op));
            _pop(T_I32);
            h5: int = len(_TS);
            if not _unreachable() {
                _emit(op);
                _emit(_slot(h5));
                _emit(_slot(h5 + 1));
                _emit(off2);
            }
        } elif op == 2 or op == 3 {  # block / loop
            _blocktype(m);
            if _ERR != "" {
                return;
            }
            k2: int = len(_BT_P) - 1;
            while k2 >= 0 {
                _pop(_BT_P[k2]);
                k2 = k2 - 1;
            }
            if op == 2 {
                _push_ctrl(0, _BT_P, _BT_R);
            } else {
                _push_ctrl(1, _BT_P, _BT_R);
            }
        } elif op == 4 {  # if
            _blocktype(m);
            if _ERR != "" {
                return;
            }
            _pop(T_I32);
            k3: int = len(_BT_P) - 1;
            while k3 >= 0 {
                _pop(_BT_P[k3]);
                k3 = k3 - 1;
            }
            cond_h: int = len(_TS) + len(_BT_P);
            _push_ctrl(2, _BT_P, _BT_R);
            top: int = len(_CK) - 1;
            if not _CD[top] {
                _emit(OP_BR_UNLESS);
                _emit(_slot(cond_h));
                _CE[top] = len(_C);
                _emit(0);
            }
        } elif op == 5 {  # else
            top2: int = len(_CK) - 1;
            if _CK[top2] != 2 {
                _invalid("else without if");
                return;
            }
            _end_check(top2);
            if _ERR != "" {
                return;
            }
            if not _unreachable() {
                _emit(OP_JMP);
                _CF[top2].append(len(_C));
                _emit(0);
            }
            if _CE[top2] >= 0 {
                _C[_CE[top2]] = len(_C);
                _CE[top2] = -1;
            }
            while len(_TS) > _CH[top2] {
                _TS.pop();
            }
            _CK[top2] = 3;
            _CU[top2] = False;
            for t3 in _CP[top2] {
                _push(t3);
            }
        } elif op == 11 {  # end
            top3: int = len(_CK) - 1;
            _end_check(top3);
            if _ERR != "" {
                return;
            }
            if _CK[top3] == 2 {
                # if without else: params must equal results
                if len(_CP[top3]) != len(_CR[top3]) {
                    _invalid("type mismatch");
                    return;
                }
                kk: int = 0;
                while kk < len(_CP[top3]) {
                    if _CP[top3][kk] != _CR[top3][kk] {
                        _invalid("type mismatch");
                        return;
                    }
                    kk = kk + 1;
                }
                if _CE[top3] >= 0 {
                    _C[_CE[top3]] = len(_C);
                }
            }
            if _CK[top3] == 4 {
                # Branches to the function label land on the final RET.
                for pos in _CF[top3] {
                    _C[pos] = len(_C);
                }
                if not _CU[top3] or len(_CF[top3]) > 0 {
                    _emit(OP_RET);
                    _emit(_slot(0));
                    _emit(len(_CR[top3]));
                }
                _CK.pop();
                _CH.pop();
                _CP.pop();
                _CR.pop();
                _CU.pop();
                _CD.pop();
                _CL.pop();
                _CF.pop();
                _CE.pop();
                # anything after the final end is malformed
                if _RP != _RE {
                    _malformed("section size mismatch");
                }
                break;
            }
            for pos2 in _CF[top3] {
                _C[pos2] = len(_C);
            }
            res: list[int] = _CR[top3];
            h6: int = _CH[top3];
            _CK.pop();
            _CH.pop();
            _CP.pop();
            _CR.pop();
            _CU.pop();
            _CD.pop();
            _CL.pop();
            _CF.pop();
            _CE.pop();
            while len(_TS) > h6 {
                _TS.pop();
            }
            for t4 in res {
                _push(t4);
            }
        } elif op == 12 {  # br
            d: int = _u32();
            if _ERR != "" {
                return;
            }
            if d >= len(_CK) {
                _invalid("unknown label");
                return;
            }
            _check_label_values(_label_types(d), False);
            if not _unreachable() {
                _emit_branch_moves(d);
                _emit_jump_to(d);
            }
            _set_unreachable();
        } elif op == 13 {  # br_if
            d2: int = _u32();
            if _ERR != "" {
                return;
            }
            if d2 >= len(_CK) {
                _invalid("unknown label");
                return;
            }
            _pop(T_I32);
            cslot: int = _slot(len(_TS));
            _check_label_values(_label_types(d2), False);
            if not _unreachable() {
                if _branch_is_direct(d2) {
                    _emit(OP_BR_IF);
                    _emit(cslot);
                    _emit(0);
                    _target_word(d2, len(_C) - 1);
                } else {
                    _emit(OP_BR_UNLESS);
                    _emit(cslot);
                    skip_pos: int = len(_C);
                    _emit(0);
                    _emit_branch_moves(d2);
                    _emit_jump_to(d2);
                    _C[skip_pos] = len(_C);
                }
            }
        } elif op == 14 {  # br_table
            n: int = _u32();
            if _ERR != "" {
                return;
            }
            if n > 100000 {
                _malformed("unexpected end");
                return;
            }
            depths: list[int] = [];
            k4: int = 0;
            while k4 <= n and _ERR == "" {
                depths.append(_u32());
                k4 = k4 + 1;
            }
            if _ERR != "" {
                return;
            }
            _pop(T_I32);
            islot: int = _slot(len(_TS));
            dflt: int = depths[n];
            if dflt >= len(_CK) {
                _invalid("unknown label");
                return;
            }
            arity: int = len(_label_types(dflt));
            for dd in depths {
                if dd >= len(_CK) {
                    _invalid("unknown label");
                    return;
                }
                lt: list[int] = _label_types(dd);
                if len(lt) != arity {
                    _invalid("type mismatch");
                    return;
                }
                # check against current stack without consuming
                _check_label_values(lt, True);
                if _ERR != "" {
                    return;
                }
            }
            if not _unreachable() {
                _emit(OP_BR_TABLE);
                _emit(islot);
                _emit(n);
                tbase: int = len(_C);
                k5: int = 0;
                while k5 <= n {
                    _emit(0);
                    k5 = k5 + 1;
                }
                k5 = 0;
                while k5 <= n {
                    dd2: int = depths[k5];
                    if _branch_is_direct(dd2) {
                        _target_word(dd2, tbase + k5);
                    } else {
                        _C[tbase + k5] = len(_C);
                        _emit_branch_moves(dd2);
                        _emit_jump_to(dd2);
                    }
                    k5 = k5 + 1;
                }
            }
            _set_unreachable();
        } elif op == 15 {  # return
            fr: list[int] = _CR[0];
            _check_label_values(fr, False);
            if not _unreachable() {
                _emit(OP_RET);
                _emit(_slot(len(_TS) - len(fr)));
                _emit(len(fr));
            }
            _set_unreachable();
        } elif op == 0 {  # unreachable
            if not _unreachable() {
                _emit(OP_UNREACHABLE);
            }
            _set_unreachable();
        } elif op == 1 {} elif op == 16 {  # nop  # call
            ci: int = _u32();
            if _ERR != "" {
                return;
            }
            if ci >= len(m.funcs) {
                _invalid("unknown function " + str(ci));
                return;
            }
            cft: FuncType = _func_type(m, ci);
            k6: int = len(cft.params) - 1;
            while k6 >= 0 {
                _pop(cft.params[k6]);
                k6 = k6 - 1;
            }
            base: int = len(_TS);
            for t5 in cft.results {
                _push(t5);
            }
            if not _unreachable() {
                _emit(OP_CALL);
                _emit(ci);
                _emit(_slot(base));
            }
        } elif op == 17 {  # call_indirect
            ti: int = _u32();
            tab: int = _u32();
            if _ERR != "" {
                return;
            }
            if tab >= len(m.tables) {
                _invalid("unknown table " + str(tab));
                return;
            }
            if ti >= len(m.types) {
                _invalid("unknown type");
                return;
            }
            if m.tables[tab].elem != T_FUNCREF {
                _invalid("type mismatch");
                return;
            }
            _pop(T_I32);
            eslot: int = _slot(len(_TS));
            ift: FuncType = m.types[ti];
            k7: int = len(ift.params) - 1;
            while k7 >= 0 {
                _pop(ift.params[k7]);
                k7 = k7 - 1;
            }
            base2: int = len(_TS);
            for t6 in ift.results {
                _push(t6);
            }
            if not _unreachable() {
                _emit(OP_CALL_INDIRECT);
                _emit(tab);
                _emit(ti);
                _emit(_slot(base2));
                _emit(eslot);
            }
        } elif op == 26 {  # drop
            _pop_any();
        } elif op == 27 or op == 28 {  # select
            st: int = 0;
            if op == 28 {
                ns: int = _u32();
                if _ERR != "" {
                    return;
                }
                if ns != 1 {
                    _invalid("invalid result arity");
                    return;
                }
                st = _valtype();
                if _ERR != "" {
                    return;
                }
            }
            _pop(T_I32);
            if op == 28 {
                _pop(st);
                _pop(st);
            } else {
                t7: int = _pop_any();
                t8: int = _pop_any();
                if _is_ref(t7) or _is_ref(t8) {
                    _invalid("type mismatch");
                    return;
                }
                if t7 != T_UNKNOWN and t8 != T_UNKNOWN and t7 != t8 {
                    _invalid("type mismatch");
                    return;
                }
                st = t7;
                if st == T_UNKNOWN {
                    st = t8;
                }
            }
            h7: int = len(_TS);
            _push(st);
            if not _unreachable() {
                _emit(OP_SELECT);
                _emit(_slot(h7));
                _emit(_slot(h7));
                _emit(_slot(h7 + 1));
                _emit(_slot(h7 + 2));
            }
        } elif op == 35 {  # global.get
            gi: int = _u32();
            if _ERR != "" {
                return;
            }
            if gi >= len(m.globals) {
                _invalid("unknown global " + str(gi));
                return;
            }
            h8: int = len(_TS);
            _push(m.globals[gi].vtype);
            if not _unreachable() {
                _emit(OP_GLOBAL_GET);
                _emit(_slot(h8));
                _emit(gi);
            }
        } elif op == 36 {  # global.set
            gi2: int = _u32();
            if _ERR != "" {
                return;
            }
            if gi2 >= len(m.globals) {
                _invalid("unknown global " + str(gi2));
                return;
            }
            if not m.globals[gi2].mutable {
                _invalid("global is immutable");
                return;
            }
            _pop(m.globals[gi2].vtype);
            if not _unreachable() {
                _emit(OP_GLOBAL_SET);
                _emit(gi2);
                _emit(_slot(len(_TS)));
            }
        } elif op == 37 {  # table.get
            tg: int = _u32();
            if _ERR != "" {
                return;
            }
            et: int = _table_type(m, tg);
            if _ERR != "" {
                return;
            }
            _pop(T_I32);
            h9: int = len(_TS);
            _push(et);
            if not _unreachable() {
                _emit(OP_TABLE_GET);
                _emit(_slot(h9));
                _emit(tg);
                _emit(_slot(h9));
            }
        } elif op == 38 {  # table.set
            ts: int = _u32();
            if _ERR != "" {
                return;
            }
            et2: int = _table_type(m, ts);
            if _ERR != "" {
                return;
            }
            _pop(et2);
            _pop(T_I32);
            h10: int = len(_TS);
            if not _unreachable() {
                _emit(OP_TABLE_SET);
                _emit(ts);
                _emit(_slot(h10));
                _emit(_slot(h10 + 1));
            }
        } elif op == 63 or op == 64 {  # memory.size / memory.grow
            mi: int = _u8();
            if _ERR != "" {
                return;
            }
            if mi != 0 {
                _malformed("zero byte expected");
                return;
            }
            _need_mem(m);
            if op == 64 {
                _pop(T_I32);
            }
            h11: int = len(_TS);
            _push(T_I32);
            if not _unreachable() {
                if op == 63 {
                    _emit(OP_MEM_SIZE);
                    _emit(_slot(h11));
                } else {
                    _emit(OP_MEM_GROW);
                    _emit(_slot(h11));
                }
            }
        } elif op == 208 {  # ref.null
            rt: int = _reftype();
            if _ERR != "" {
                return;
            }
            h12: int = len(_TS);
            _push(rt);
            if not _unreachable() {
                _emit(OP_CONST);
                _emit(_slot(h12));
                _emit(0);
            }
        } elif op == 209 {  # ref.is_null
            t9: int = _pop_any();
            if t9 != T_UNKNOWN and not _is_ref(t9) {
                _invalid("type mismatch");
                return;
            }
            h13: int = len(_TS);
            _push(T_I32);
            if not _unreachable() {
                _emit(OP_REF_IS_NULL);
                _emit(_slot(h13));
                _emit(_slot(h13));
            }
        } elif op == 210 {  # ref.func
            rf: int = _u32();
            if _ERR != "" {
                return;
            }
            if rf >= len(m.funcs) {
                _invalid("unknown function " + str(rf));
                return;
            }
            if not _is_declared(rf) {
                _invalid("undeclared function reference");
                return;
            }
            h14: int = len(_TS);
            _push(T_FUNCREF);
            if not _unreachable() {
                _emit(OP_REF_FUNC);
                _emit(_slot(h14));
                _emit(rf);
            }
        } elif op == 252 {
            _compile_fc(m);
        } else {
            _malformed("illegal opcode " + str(op));
            return;
        }
    }
    if _ERR != "" {
        return;
    }
    if len(_CK) != 0 {
        _malformed("unexpected end");
        return;
    }
    # Finalize: relocate word-index targets to absolute addresses.
    nwords: int = len(_C);
    code: int = io_alloc(nwords * 8 + 8);
    _relocate(code);
    f.code = code;
    f.code_words = nwords;
    f.nlocals = _NLOC;
    f.max_slots = _NLOC + _MAXH + 1;
}

"""Validate the frame's results at end/else."""
def _end_check(top: int) {
    res: list[int] = _CR[top];
    n: int = len(res);
    k: int = n - 1;
    while k >= 0 {
        _pop(res[k]);
        k = k - 1;
    }
    if len(_TS) != _CH[top] {
        _invalid("type mismatch");
    }
    for t in res {
        _push(t);
    }
}

# Positions in _C that hold jump targets (word indices) — rewritten to
# absolute addresses by _relocate. Rather than tracking them, the relocator
# re-walks the code knowing each op's operand layout.
def _relocate(code: int) {
    i: int = 0;
    n: int = len(_C);
    while i < n {
        op: int = _C[i];
        __mem_store_i64(code + i * 8, op);
        w: int = _op_words(op, i);
        if op == OP_JMP {
            __mem_store_i64(code + (i + 1) * 8, code + _C[i + 1] * 8);
        } elif op == OP_BR_IF or op == OP_BR_UNLESS {
            __mem_store_i64(code + (i + 1) * 8, _C[i + 1]);
            __mem_store_i64(code + (i + 2) * 8, code + _C[i + 2] * 8);
        } elif op == OP_BR_TABLE {
            __mem_store_i64(code + (i + 1) * 8, _C[i + 1]);
            __mem_store_i64(code + (i + 2) * 8, _C[i + 2]);
            k: int = 0;
            while k <= _C[i + 2] {
                __mem_store_i64(code + (i + 3 + k) * 8, code + _C[i + 3 + k] * 8);
                k = k + 1;
            }
        } else {
            k2: int = 1;
            while k2 < w {
                __mem_store_i64(code + (i + k2) * 8, _C[i + k2]);
                k2 = k2 + 1;
            }
        }
        i = i + w;
    }
}

"""Words occupied by the instruction at word index i (op included)."""
def _op_words(op: int, i: int) -> int {
    if op == OP_UNREACHABLE {
        return 1;
    }
    if op == OP_JMP {
        return 2;
    }
    if op == OP_BR_IF or op == OP_BR_UNLESS {
        return 3;
    }
    if op == OP_BR_TABLE {
        return 4 + _C[i + 2];
    }
    if op == OP_RET
        or op == OP_CALL
        or op == OP_COPY
        or op == OP_CONST
        or op == OP_GLOBAL_GET
        or op == OP_GLOBAL_SET
        or op == OP_REF_IS_NULL
        or op == OP_REF_FUNC {
        return 3;
    }
    if op == OP_CALL_INDIRECT {
        return 5;
    }
    if op == OP_SELECT {
        return 5;
    }
    if op == OP_TABLE_GET or op == OP_TABLE_SET {
        return 4;
    }
    if op == OP_MEM_SIZE or op == OP_MEM_GROW {
        return 2;
    }
    if op >= 40 and op <= 62 {
        return 4;
    }
    if op >= 69 and op <= 196 {
        if _SIG_B[op] != 0 {
            return 4;
        }
        return 3;
    }
    if op >= OP_FC {
        sub: int = op - OP_FC;
        if sub <= 7 {
            return 3;
        }  # trunc_sat: dst a
        if sub == 8 {
            return 5;
        }  # memory.init seg d s n -> seg base
        if sub == 9 {
            return 2;
        }  # data.drop seg
        if sub == 10 or sub == 11 {
            return 2;
        }  # memory.copy/fill base
        if sub == 12 {
            return 4;
        }  # table.init seg t base
        if sub == 13 {
            return 2;
        }  # elem.drop seg
        if sub == 14 {
            return 4;
        }  # table.copy dt st base
        if sub == 15 {
            return 4;
        }  # table.grow dst t base
        if sub == 16 {
            return 3;
        }  # table.size dst t
        if sub == 17 {
            return 3;
        }  # table.fill t base
    }
    return 1;
}

def _compile_fc(m: WModule) -> None {
    sub: int = _u32();
    if _ERR != "" {
        return;
    }
    if sub <= 7 {
        a: int = T_F32;
        r: int = T_I32;
        if sub == 2 or sub == 3 {
            a = T_F64;
        }
        if sub == 4 or sub == 5 {
            r = T_I64;
        }
        if sub == 6 or sub == 7 {
            a = T_F64;
            r = T_I64;
        }
        _pop(a);
        h: int = len(_TS);
        _push(r);
        if not _unreachable() {
            _emit(OP_FC + sub);
            _emit(_slot(h));
            _emit(_slot(h));
        }
        return;
    }
    if sub == 8 {  # memory.init seg mem
        seg: int = _u32();
        mi: int = _u8();
        if _ERR != "" {
            return;
        }
        if mi != 0 {
            _malformed("zero byte expected");
            return;
        }
        _need_mem(m);
        if m.data_count < 0 {
            _NEED_DC = True;
        } elif seg >= m.data_count {
            _invalid("unknown data segment " + str(seg));
            return;
        }
        _pop(T_I32);
        _pop(T_I32);
        _pop(T_I32);
        if not _unreachable() {
            _emit(OP_FC + 8);
            _emit(seg);
            _emit(_slot(len(_TS)));
            _emit(0);
            _emit(0);
        }
        return;
    }
    if sub == 9 {  # data.drop
        seg2: int = _u32();
        if _ERR != "" {
            return;
        }
        if m.data_count < 0 {
            _NEED_DC = True;
        } elif seg2 >= m.data_count {
            _invalid("unknown data segment " + str(seg2));
            return;
        }
        if not _unreachable() {
            _emit(OP_FC + 9);
            _emit(seg2);
        }
        return;
    }
    if sub == 10 {  # memory.copy
        a1: int = _u8();
        a2: int = _u8();
        if _ERR != "" {
            return;
        }
        if a1 != 0 or a2 != 0 {
            _malformed("zero byte expected");
            return;
        }
        _need_mem(m);
        _pop(T_I32);
        _pop(T_I32);
        _pop(T_I32);
        if not _unreachable() {
            _emit(OP_FC + 10);
            _emit(_slot(len(_TS)));
        }
        return;
    }
    if sub == 11 {  # memory.fill
        a3: int = _u8();
        if _ERR != "" {
            return;
        }
        if a3 != 0 {
            _malformed("zero byte expected");
            return;
        }
        _need_mem(m);
        _pop(T_I32);
        _pop(T_I32);
        _pop(T_I32);
        if not _unreachable() {
            _emit(OP_FC + 11);
            _emit(_slot(len(_TS)));
        }
        return;
    }
    if sub == 12 {  # table.init seg table
        seg3: int = _u32();
        t: int = _u32();
        if _ERR != "" {
            return;
        }
        et: int = _table_type(m, t);
        if _ERR != "" {
            return;
        }
        if seg3 >= len(m.elems) {
            _invalid("unknown elem segment " + str(seg3));
            return;
        }
        if m.elems[seg3].etype != et {
            _invalid("type mismatch");
            return;
        }
        _pop(T_I32);
        _pop(T_I32);
        _pop(T_I32);
        if not _unreachable() {
            _emit(OP_FC + 12);
            _emit(seg3);
            _emit(t);
            _emit(_slot(len(_TS)));
        }
        return;
    }
    if sub == 13 {  # elem.drop
        seg4: int = _u32();
        if _ERR != "" {
            return;
        }
        if seg4 >= len(m.elems) {
            _invalid("unknown elem segment " + str(seg4));
            return;
        }
        if not _unreachable() {
            _emit(OP_FC + 13);
            _emit(seg4);
        }
        return;
    }
    if sub == 14 {  # table.copy dst src
        td: int = _u32();
        tsrc: int = _u32();
        if _ERR != "" {
            return;
        }
        e1: int = _table_type(m, td);
        e2: int = _table_type(m, tsrc);
        if _ERR != "" {
            return;
        }
        if e1 != e2 {
            _invalid("type mismatch");
            return;
        }
        _pop(T_I32);
        _pop(T_I32);
        _pop(T_I32);
        if not _unreachable() {
            _emit(OP_FC + 14);
            _emit(td);
            _emit(tsrc);
            _emit(_slot(len(_TS)));
        }
        return;
    }
    if sub == 15 {  # table.grow
        tg: int = _u32();
        if _ERR != "" {
            return;
        }
        e3: int = _table_type(m, tg);
        if _ERR != "" {
            return;
        }
        _pop(T_I32);
        _pop(e3);
        h2: int = len(_TS);
        _push(T_I32);
        if not _unreachable() {
            _emit(OP_FC + 15);
            _emit(_slot(h2));
            _emit(tg);
            _emit(_slot(h2));
        }
        return;
    }
    if sub == 16 {  # table.size
        tz: int = _u32();
        if _ERR != "" {
            return;
        }
        _table_type(m, tz);
        if _ERR != "" {
            return;
        }
        h3: int = len(_TS);
        _push(T_I32);
        if not _unreachable() {
            _emit(OP_FC + 16);
            _emit(_slot(h3));
            _emit(tz);
        }
        return;
    }
    if sub == 17 {  # table.fill
        tf: int = _u32();
        if _ERR != "" {
            return;
        }
        e4: int = _table_type(m, tf);
        if _ERR != "" {
            return;
        }
        _pop(T_I32);
        _pop(e4);
        _pop(T_I32);
        if not _unreachable() {
            _emit(OP_FC + 17);
            _emit(tf);
            _emit(_slot(len(_TS)));
        }
        return;
    }
    _malformed("illegal opcode 0xfc " + str(sub));
}

# ── Module decoding ──────────────────────────────────────────────────────────

def _section_order(id: int) -> int {
    # custom=0; data count (12) sits between element (9) and code (10).
    if id == 12 {
        return 10;
    }
    if id == 10 {
        return 11;
    }
    if id == 11 {
        return 12;
    }
    return id;
}

"""Release a module's native buffers: the copied wasm bytes and every
compiled function body. For discarded modules only -- an instantiated
instance aliases the code pointers, so a module that produced instances
must keep them until its instances are gone."""
def:pub free_module_buffers(m: WModule) {
    if m.bytes != 0 {
        io_free(m.bytes);
        m.bytes = 0;
    }
    i: int = m.n_imported_funcs;
    while i < len(m.funcs) {
        if m.funcs[i].code != 0 {
            io_free(m.funcs[i].code);
            m.funcs[i].code = 0;
        }
        i = i + 1;
    }
}

"""Decode + validate + compile. Returns the module, or None with
wasm_compile_error() set."""
def:pub compile_module(src: int, n: int) -> WModule | None {
    _ERR = "";
    _NEED_DC = False;
    _init_sigs();
    _DECLARED = [];
    m: WModule = WModule();
    buf: int = io_alloc(n + 8);
    k: int = 0;
    while k + 8 <= n {
        __mem_store_i64(buf + k, __mem_load_i64(src + k));
        k = k + 8;
    }
    while k < n {
        __mem_store_i8(buf + k, __mem_load_i8(src + k));
        k = k + 1;
    }
    m.bytes = buf;
    m.nbytes = n;
    _RB = buf;
    _RP = 0;
    _RE = n;
    if n < 4 or __mem_load_i32(buf) != 1836278016 {
        _malformed("magic header not detected");
        free_module_buffers(m);
        return None;
    }
    if n < 8 {
        _malformed("unexpected end");
        free_module_buffers(m);
        return None;
    }
    if __mem_load_i32(buf + 4) != 1 {
        _malformed("unknown binary version");
        free_module_buffers(m);
        return None;
    }
    _RP = 8;
    last: int = 0;
    func_type_idx: list[int] = [];
    code_seen: bool = False;
    data_seen: bool = False;
    ncode: int = -1;
    while _RP < n and _ERR == "" {
        id: int = _u8();
        size: int = _u32();
        if _ERR != "" {
            break;
        }
        if _RP + size > n {
            _malformed("section size mismatch");
            break;
        }
        send: int = _RP + size;
        if id > 12 {
            _malformed("malformed section id");
            break;
        }
        if id != 0 {
            ordv: int = _section_order(id);
            if ordv <= last {
                _malformed("unexpected content after last section");
                break;
            }
            last = ordv;
        }
        _RE = send;
        if id == 0 {
            _name();
            _RP = send;
        } elif id == 1 {
            _sec_type(m);
        } elif id == 2 {
            _sec_import(m);
        } elif id == 3 {
            cnt: int = _u32();
            i: int = 0;
            while i < cnt and _ERR == "" {
                ti: int = _u32();
                if _ERR != "" {
                    break;
                }
                if ti >= len(m.types) {
                    _invalid("unknown type");
                    break;
                }
                f: WFunc = WFunc(type_index=ti);
                m.funcs.append(f);
                i = i + 1;
            }
            if _ERR == "" and cnt > 0 {
                ncode = cnt;
            }
            if _ERR == "" and cnt == 0 {
                ncode = 0;
            }
        } elif id == 4 {
            cnt2: int = _u32();
            i2: int = 0;
            while i2 < cnt2 and _ERR == "" {
                et: int = _reftype();
                lim: list[int] = _limits(False);
                if _ERR != "" {
                    break;
                }
                if lim[1] >= 0 and lim[1] < lim[0] {
                    _invalid("size minimum must not be greater than maximum");
                    break;
                }
                m.tables.append(WTable(elem=et, min=lim[0], max=lim[1]));
                i2 = i2 + 1;
            }
        } elif id == 5 {
            cnt3: int = _u32();
            i3: int = 0;
            while i3 < cnt3 and _ERR == "" {
                lim2: list[int] = _limits(True);
                if _ERR != "" {
                    break;
                }
                _check_mem_limits(lim2[0], lim2[1]);
                m.mem_min.append(lim2[0]);
                m.mem_max.append(lim2[1]);
                i3 = i3 + 1;
            }
            if _ERR == "" and len(m.mem_min) > 1 {
                _invalid("multiple memories");
            }
        } elif id == 6 {
            _sec_global(m);
        } elif id == 7 {
            _sec_export(m);
        } elif id == 8 {
            st: int = _u32();
            if _ERR != "" {
                break;
            }
            if st >= len(m.funcs) {
                _invalid("unknown function " + str(st));
                break;
            }
            sft: FuncType = _func_type(m, st);
            if len(sft.params) != 0 or len(sft.results) != 0 {
                _invalid("start function");
                break;
            }
            m.start = st;
        } elif id == 9 {
            _sec_elem(m);
        } elif id == 12 {
            m.data_count = _u32();
        } elif id == 10 {
            code_seen = True;
            cnt4: int = _u32();
            if _ERR != "" {
                break;
            }
            ndef: int = len(m.funcs) - m.n_imported_funcs;
            if cnt4 != ndef {
                _malformed("function and code section have inconsistent lengths");
                break;
            }
            i4: int = 0;
            while i4 < cnt4 and _ERR == "" {
                bsize: int = _u32();
                if _ERR != "" {
                    break;
                }
                if _RP + bsize > send {
                    _malformed("unexpected end");
                    break;
                }
                bend: int = _RP + bsize;
                _RE = bend;
                _compile_body(m, m.n_imported_funcs + i4);
                if _ERR != "" {
                    break;
                }
                _RP = bend;
                _RE = send;
                i4 = i4 + 1;
            }
        } elif id == 11 {
            data_seen = True;
            _sec_data(m);
        }
        if _ERR != "" {
            break;
        }
        if _RP != send {
            _malformed("section size mismatch");
            break;
        }
        _RE = n;
    }
    if _ERR != "" {
        free_module_buffers(m);
        return None;
    }
    ndef2: int = len(m.funcs) - m.n_imported_funcs;
    if not code_seen and ndef2 > 0 {
        _malformed("function and code section have inconsistent lengths");
        free_module_buffers(m);
        return None;
    }
    if _NEED_DC {
        if data_seen {
            _malformed("data count section required");
        } else {
            _invalid("unknown data segment");
        }
        free_module_buffers(m);
        return None;
    }
    if m.data_count >= 0 and m.data_count != len(m.datas) {
        _malformed("data count and data section have inconsistent lengths");
        free_module_buffers(m);
        return None;
    }
    return m;
}

def _check_mem_limits(mn: int, mx: int) -> None {
    if mn > 65536 {
        _invalid("memory size must be at most 65536 pages (4GiB)");
        return;
    }
    if mx >= 0 {
        if mx > 65536 {
            _invalid("memory size must be at most 65536 pages (4GiB)");
            return;
        }
        if mx < mn {
            _invalid("size minimum must not be greater than maximum");
        }
    }
}

def _sec_type(m: WModule) -> None {
    cnt: int = _u32();
    i: int = 0;
    while i < cnt and _ERR == "" {
        form: int = _u8();
        if _ERR != "" {
            return;
        }
        if form != 96 {
            _malformed("integer representation too long");
            return;
        }
        ft: FuncType = FuncType();
        np: int = _u32();
        k: int = 0;
        while k < np and _ERR == "" {
            ft.params.append(_valtype());
            k = k + 1;
        }
        nr: int = _u32();
        k = 0;
        while k < nr and _ERR == "" {
            ft.results.append(_valtype());
            k = k + 1;
        }
        m.types.append(ft);
        i = i + 1;
    }
}

def _sec_import(m: WModule) -> None {
    cnt: int = _u32();
    i: int = 0;
    while i < cnt and _ERR == "" {
        imp: WImport = WImport();
        imp.module = _name();
        imp.name = _name();
        kind: int = _u8();
        if _ERR != "" {
            return;
        }
        imp.kind = kind;
        if kind == 0 {
            ti: int = _u32();
            if _ERR != "" {
                return;
            }
            if ti >= len(m.types) {
                _invalid("unknown type");
                return;
            }
            imp.index = len(m.funcs);
            m.funcs.append(WFunc(type_index=ti));
            m.n_imported_funcs = m.n_imported_funcs + 1;
        } elif kind == 1 {
            et: int = _reftype();
            lim: list[int] = _limits(False);
            if _ERR != "" {
                return;
            }
            if lim[1] >= 0 and lim[1] < lim[0] {
                _invalid("size minimum must not be greater than maximum");
                return;
            }
            imp.index = len(m.tables);
            m.tables.append(WTable(elem=et, min=lim[0], max=lim[1]));
            m.n_imported_tables = m.n_imported_tables + 1;
        } elif kind == 2 {
            lim2: list[int] = _limits(True);
            if _ERR != "" {
                return;
            }
            _check_mem_limits(lim2[0], lim2[1]);
            imp.index = len(m.mem_min);
            m.mem_min.append(lim2[0]);
            m.mem_max.append(lim2[1]);
            m.n_imported_mems = m.n_imported_mems + 1;
            if len(m.mem_min) > 1 {
                _invalid("multiple memories");
                return;
            }
        } elif kind == 3 {
            vt: int = _valtype();
            mutb: int = _u8();
            if _ERR != "" {
                return;
            }
            if mutb > 1 {
                _malformed("malformed mutability");
                return;
            }
            imp.index = len(m.globals);
            m.globals.append(WGlobal(vtype=vt, mutable=(mutb == 1)));
            m.n_imported_globals = m.n_imported_globals + 1;
        } else {
            _malformed("malformed import kind");
            return;
        }
        m.imports.append(imp);
        i = i + 1;
    }
}

def _sec_global(m: WModule) -> None {
    cnt: int = _u32();
    i: int = 0;
    while i < cnt and _ERR == "" {
        vt: int = _valtype();
        mutb: int = _u8();
        if _ERR != "" {
            return;
        }
        if mutb > 1 {
            _malformed("malformed mutability");
            return;
        }
        _const_expr(m, vt, m.n_imported_globals, len(m.funcs));
        if _ERR != "" {
            return;
        }
        m.globals.append(
            WGlobal(vtype=vt, mutable=(mutb == 1), ce_kind=_CE_KIND, ce_value=_CE_VALUE)
        );
        i = i + 1;
    }
}

def _sec_export(m: WModule) -> None {
    cnt: int = _u32();
    i: int = 0;
    seen: dict[str, int] = {};
    while i < cnt and _ERR == "" {
        nm: str = _name();
        kind: int = _u8();
        idx: int = _u32();
        if _ERR != "" {
            return;
        }
        if kind == 0 {
            if idx >= len(m.funcs) {
                _invalid("unknown function " + str(idx));
                return;
            }
            _declare_ref(idx);
        } elif kind == 1 {
            if idx >= len(m.tables) {
                _invalid("unknown table " + str(idx));
                return;
            }
        } elif kind == 2 {
            if idx >= len(m.mem_min) {
                _invalid("unknown memory " + str(idx));
                return;
            }
        } elif kind == 3 {
            if idx >= len(m.globals) {
                _invalid("unknown global " + str(idx));
                return;
            }
        } else {
            _malformed("malformed export kind");
            return;
        }
        if nm in seen {
            _invalid("duplicate export name");
            return;
        }
        seen[nm] = 1;
        m.exports.append(WExport(name=nm, kind=kind, index=idx));
        i = i + 1;
    }
}

def _sec_elem(m: WModule) -> None {
    cnt: int = _u32();
    i: int = 0;
    while i < cnt and _ERR == "" {
        flags: int = _u32();
        if _ERR != "" {
            return;
        }
        if flags > 7 {
            _malformed("malformed elements segment kind");
            return;
        }
        e: WElem = WElem();
        passive_or_decl: bool = (flags & 1) == 1;
        explicit_table: bool = (flags & 2) == 2;
        uses_exprs: bool = (flags & 4) == 4;
        if not passive_or_decl {
            e.mode = 0;
            if explicit_table {
                e.table = _u32();
            }
            if _ERR != "" {
                return;
            }
            if e.table >= len(m.tables) {
                _invalid("unknown table " + str(e.table));
                return;
            }
            _const_expr(m, T_I32, m.n_imported_globals, len(m.funcs));
            if _ERR != "" {
                return;
            }
            e.off_kind = _CE_KIND;
            e.off_value = _CE_VALUE;
        } else {
            if explicit_table {
                e.mode = 2;
            } else {
                e.mode = 1;
            }
        }
        # element type
        if (flags & 3) != 0 {
            if uses_exprs {
                e.etype = _reftype();
            } else {
                ek: int = _u8();
                if _ERR != "" {
                    return;
                }
                if ek != 0 {
                    _malformed("malformed element kind");
                    return;
                }
                e.etype = T_FUNCREF;
            }
        }
        if _ERR != "" {
            return;
        }
        nel: int = _u32();
        k: int = 0;
        while k < nel and _ERR == "" {
            if uses_exprs {
                _const_expr(m, e.etype, m.n_imported_globals, len(m.funcs));
                e.ce_kinds.append(_CE_KIND);
                e.ce_values.append(_CE_VALUE);
            } else {
                fi: int = _u32();
                if _ERR != "" {
                    return;
                }
                if fi >= len(m.funcs) {
                    _invalid("unknown function " + str(fi));
                    return;
                }
                _declare_ref(fi);
                e.ce_kinds.append(CE_REF_FUNC);
                e.ce_values.append(fi);
            }
            k = k + 1;
        }
        if _ERR != "" {
            return;
        }
        if e.mode == 0 and m.tables[e.table].elem != e.etype {
            _invalid("type mismatch");
            return;
        }
        m.elems.append(e);
        i = i + 1;
    }
}

def _sec_data(m: WModule) -> None {
    cnt: int = _u32();
    i: int = 0;
    while i < cnt and _ERR == "" {
        flags: int = _u32();
        if _ERR != "" {
            return;
        }
        d: WData = WData();
        if flags == 0 or flags == 2 {
            if flags == 2 {
                d.memory = _u32();
            }
            if _ERR != "" {
                return;
            }
            if d.memory >= len(m.mem_min) {
                _invalid("unknown memory " + str(d.memory));
                return;
            }
            _const_expr(m, T_I32, m.n_imported_globals, len(m.funcs));
            if _ERR != "" {
                return;
            }
            d.off_kind = _CE_KIND;
            d.off_value = _CE_VALUE;
        } elif flags == 1 {
            d.mode = 1;
        } else {
            _malformed("malformed data segment kind");
            return;
        }
        sz: int = _u32();
        if _ERR != "" {
            return;
        }
        if _RP + sz > _RE {
            _malformed("unexpected end of section or function");
            return;
        }
        d.ptr = _RB + _RP;
        d.size = sz;
        _RP = _RP + sz;
        m.datas.append(d);
        i = i + 1;
    }
}
