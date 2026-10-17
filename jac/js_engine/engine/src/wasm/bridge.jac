"""Engine-facing WebAssembly API (globalThis.__wasm) on the Jac-native
interpreter (engine/src/wasm/compile.jac + exec.jac).

Keeps the function names and value-kind constants of the former Wasmtime
bridge so dispatch.jac / vm.jac / webassembly.js are unchanged in shape.
Every object crosses to JS as a small integer handle (JS stores handles as
int32 Numbers; record pointers would not fit).

Host imports: each imported JS function gets a fresh token
(wasm_new_host_token); the VM keeps token -> JS callback, and a call from
wasm marshals arguments into the wasm_host_arg_* accessors, runs the
registered callback, and reads results pushed via wasm_host_push_result.
"""

import from engine.src.ffi.libm { fmod }
import from engine.src.wasm.compile {
    WModule, WImport, WExport, FuncType, compile_module, wasm_compile_error,
    T_I32, T_I64, T_F32, T_F64, T_FUNCREF, T_EXTERNREF,
    EXT_FUNC, EXT_TABLE, EXT_MEMORY, EXT_GLOBAL, f32_bits_to_f64
}
import from engine.src.wasm.exec {
    WInstance, instantiate, invoke, invoke_result, invoke_result_count,
    wasm_trap_message, wasm_link_error, wasm_set_trap, new_host_func,
    new_memory, mem_base, mem_size, mem_pages, mem_grow, new_table,
    table_size, table_get, table_set, table_grow, table_elem_type,
    new_global, global_type, global_mutable, global_get, global_set,
    canon_type, type_params, type_results, func_type_id, set_host_handler,
    export_index
}

# ── Value kinds / extern kinds / error classes (JS-visible numbering) ───────
glob:pub WASMTIME_I32: int = 0;
glob:pub WASMTIME_I64: int = 1;
glob:pub WASMTIME_F32: int = 2;
glob:pub WASMTIME_F64: int = 3;
glob:pub WASMTIME_FUNCREF: int = 5;
glob:pub WASMTIME_EXTERNREF: int = 6;

glob:pub WASMTIME_EXTERN_FUNC: int = 0;
glob:pub WASMTIME_EXTERN_GLOBAL: int = 1;
glob:pub WASMTIME_EXTERN_TABLE: int = 2;
glob:pub WASMTIME_EXTERN_MEMORY: int = 3;

glob:pub WASM_ERRCLASS_NONE: int = 0;
glob:pub WASM_ERRCLASS_COMPILE: int = 1;
glob:pub WASM_ERRCLASS_LINK: int = 2;
glob:pub WASM_ERRCLASS_RUNTIME: int = 3;

def _kind_of(vt: int) -> int {
    if vt == T_I32 { return WASMTIME_I32; }
    if vt == T_I64 { return WASMTIME_I64; }
    if vt == T_F32 { return WASMTIME_F32; }
    if vt == T_F64 { return WASMTIME_F64; }
    if vt == T_FUNCREF { return WASMTIME_FUNCREF; }
    return WASMTIME_EXTERNREF;
}

def _vt_of(kind: int) -> int {
    if kind == WASMTIME_I32 { return T_I32; }
    if kind == WASMTIME_I64 { return T_I64; }
    if kind == WASMTIME_F32 { return T_F32; }
    if kind == WASMTIME_F64 { return T_F64; }
    if kind == WASMTIME_FUNCREF { return T_FUNCREF; }
    return T_EXTERNREF;
}

def _extern_of(k: int) -> int {
    if k == EXT_FUNC { return WASMTIME_EXTERN_FUNC; }
    if k == EXT_TABLE { return WASMTIME_EXTERN_TABLE; }
    if k == EXT_MEMORY { return WASMTIME_EXTERN_MEMORY; }
    return WASMTIME_EXTERN_GLOBAL;
}

# ── Errors ───────────────────────────────────────────────────────────────────
glob _ERR: str = "";
glob _ERRCLASS: int = 0;

def _set_err(msg: str, cls: int) -> None { _ERR = msg; _ERRCLASS = cls; }

def:pub wasm_last_error() -> str { return _ERR; }
def:pub wasm_last_error_class() -> int { return _ERRCLASS; }

# ── Number helpers shared with dispatch / vm ────────────────────────────────

"""JS ToInt32 of a Number: NaN/±Infinity -> 0, else truncate and wrap
modulo 2^32 into the signed i32 range."""
def:pub wasm_f64_to_i32(d: float) -> int {
    if d - d != 0.0 { return 0; }
    return int(i32.wrap(int(fmod(d, 4294967296.0))));   # |x| < 2^32; int() truncates
}

"""Number -> i64 (convenience path; the spec takes BigInt). Out-of-range and
non-finite values map to 0 instead of panicking."""
def:pub wasm_f64_to_i64(d: float) -> int {
    if d - d != 0.0 { return 0; }
    if d >= 9223372036854775807.0 or d < -9223372036854775807.0 { return 0; }
    return int(d);
}

"""BigInt decimal string -> i64, wrapping modulo 2^64 (ToBigInt64)."""
def:pub wasm_i64_from_decimal(s: str) -> int {
    n: int = len(s);
    i: int = 0;
    neg: bool = False;
    if n > 0 and s[0] == "-" { neg = True; i = 1; }
    elif n > 0 and s[0] == "+" { i = 1; }
    acc: int = 0;
    while i < n {
        d: int = ord(s[i]) - 48;
        if d < 0 or d > 9 { break; }
        acc = wrapping_add(wrapping_mul(acc, 10), d);
        i = i + 1;
    }
    if neg { return wrapping_sub(0, acc); }
    return acc;
}

def:pub wasm_i64_to_decimal(v: int) -> str { return str(v); }

"""JS-side value (int or double, by kind) -> slot representation.
For FUNCREF, `ival` is a JS-visible func handle (0 = null), mapped to the
internal record pointer here. For EXTERNREF, `ival` is the extern id (raw)."""
def _to_slot(kind: int, ival: int, dval: float) -> int {
    if kind == WASMTIME_I32 { return int(i32.wrap(ival)); }
    if kind == WASMTIME_F32 { return __float_bits(float(f32(dval))); }
    if kind == WASMTIME_F64 { return __float_bits(dval); }
    if kind == WASMTIME_FUNCREF {
        if ival >= 1 and ival < len(_FUNCS) { return _FUNCS[ival]; }
        return 0;
    }
    return ival;
}

"""Raw bit pattern -> slot (NaN-box args that must not pass through a
JSValue double, which canonicalises the payload/sign). For F32, `ival` is
the f32 bit pattern (low 32 bits); for F64 the full 64-bit pattern."""
def _to_slot_bits(kind: int, ival: int) -> int {
    if kind == WASMTIME_F32 { return __float_bits(f32_bits_to_f64(ival & 4294967295)); }
    if kind == WASMTIME_F64 { return ival; }
    return _to_slot(kind, ival, 0.0);
}

def _slot_dbl(v: int) -> float { return __bits_float(v); }

# ── Handle tables (index 0 is never valid) ───────────────────────────────────
glob _MODS: list[WModule] = [WModule()];
glob _INSTS: list[WInstance] = [WInstance()];
glob _FUNCS: list[int] = [0];
glob _FUNC_H: dict[int, int] = {};
glob _MEMS: list[int] = [0];
glob _MEM_H: dict[int, int] = {};
glob _TABLES: list[int] = [0];
glob _TABLE_H: dict[int, int] = {};
glob _GLOBALS: list[int] = [0];
glob _GLOBAL_H: dict[int, int] = {};

def _func_handle(f: int) -> int {
    if f in _FUNC_H { return _FUNC_H[f]; }
    h: int = len(_FUNCS);
    _FUNCS.append(f);
    _FUNC_H[f] = h;
    return h;
}

def _mem_handle(m: int) -> int {
    if m in _MEM_H { return _MEM_H[m]; }
    h: int = len(_MEMS);
    _MEMS.append(m);
    _MEM_H[m] = h;
    return h;
}

def _table_handle(t: int) -> int {
    if t in _TABLE_H { return _TABLE_H[t]; }
    h: int = len(_TABLES);
    _TABLES.append(t);
    _TABLE_H[t] = h;
    return h;
}

def _global_handle(g: int) -> int {
    if g in _GLOBAL_H { return _GLOBAL_H[g]; }
    h: int = len(_GLOBALS);
    _GLOBALS.append(g);
    _GLOBAL_H[g] = h;
    return h;
}

def _valid(h: int, n: int) -> bool { return h >= 1 and h < n; }

# ── Modules ──────────────────────────────────────────────────────────────────

"""Single shared "store" (kept for API shape: memories etc. are store-free)."""
def:pub wasm_store_open() -> int { return 1; }

def:pub wasm_module_compile(ptr: int, length: int) -> int {
    m: WModule | None = compile_module(ptr, length);
    if m == None {
        _set_err(wasm_compile_error(), WASM_ERRCLASS_COMPILE);
        return 0;
    }
    _set_err("", WASM_ERRCLASS_NONE);
    h: int = len(_MODS);
    _MODS.append(m);
    return h;
}

def:pub wasm_module_valid(ptr: int, length: int) -> bool {
    m: WModule | None = compile_module(ptr, length);
    if m == None { _set_err(wasm_compile_error(), WASM_ERRCLASS_COMPILE); return False; }
    return True;
}

def:pub wasm_module_free(h: int) -> None {
    if _valid(h, len(_MODS)) { _MODS[h] = WModule(); }
}

glob _SCAN_IMP: list[WImport] = [];
glob _SCAN_EXP: list[WExport] = [];

def:pub wasm_module_scan_imports(h: int) -> int {
    if not _valid(h, len(_MODS)) { _set_err("invalid module handle", WASM_ERRCLASS_LINK); return -1; }
    _SCAN_IMP = _MODS[h].imports;
    return len(_SCAN_IMP);
}

def:pub wasm_module_import_module(i: int) -> str { return _SCAN_IMP[i].module; }
def:pub wasm_module_import_name(i: int) -> str { return _SCAN_IMP[i].name; }
def:pub wasm_module_import_kind(i: int) -> int { return _extern_of(_SCAN_IMP[i].kind); }

def:pub wasm_module_scan_exports(h: int) -> int {
    if not _valid(h, len(_MODS)) { return -1; }
    _SCAN_EXP = _MODS[h].exports;
    return len(_SCAN_EXP);
}

def:pub wasm_module_export_name(i: int) -> str { return _SCAN_EXP[i].name; }
def:pub wasm_module_export_kind(i: int) -> int { return _extern_of(_SCAN_EXP[i].kind); }

# ── Instantiation ────────────────────────────────────────────────────────────
glob _PENDING: list[int] = [];
glob _PENDING_MOD: int = 0;

def _finish_instantiate(h: int, imports: list[int]) -> int {
    inst: WInstance | None = instantiate(_MODS[h], imports);
    if inst == None {
        if wasm_link_error() != "" { _set_err(wasm_link_error(), WASM_ERRCLASS_LINK); }
        else { _set_err(wasm_trap_message(), WASM_ERRCLASS_RUNTIME); }
        return 0;
    }
    _set_err("", WASM_ERRCLASS_NONE);
    ih: int = len(_INSTS);
    _INSTS.append(inst);
    return ih;
}

def:pub wasm_instantiate_handle(h: int) -> int {
    _ensure_host();
    if not _valid(h, len(_MODS)) { _set_err("invalid module handle", WASM_ERRCLASS_LINK); return 0; }
    return _finish_instantiate(h, []);
}

def:pub wasm_imports_begin_for_module(h: int) -> int {
    _ensure_host();
    if not _valid(h, len(_MODS)) { _set_err("invalid module handle", WASM_ERRCLASS_LINK); return -1; }
    _PENDING_MOD = h;
    _PENDING = [];
    n: int = len(_MODS[h].imports);
    i: int = 0;
    while i < n { _PENDING.append(0); i = i + 1; }
    return n;
}

glob _NEXT_TOKEN: int = 1;

"""A fresh token for one imported JS function (the VM keys callbacks by it)."""
def:pub wasm_new_host_token() -> int {
    t: int = _NEXT_TOKEN;
    _NEXT_TOKEN = _NEXT_TOKEN + 1;
    return t;
}

def _pending_ok(idx: int, kind: int) -> bool {
    if idx < 0 or idx >= len(_PENDING) { _set_err("import slot out of range", WASM_ERRCLASS_LINK); return False; }
    if _MODS[_PENDING_MOD].imports[idx].kind != kind { _set_err("incompatible import type", WASM_ERRCLASS_LINK); return False; }
    return True;
}

"""Import slot `idx` is a JS function, called through the VM by `token`."""
def:pub wasm_imports_add_func(idx: int, token: int) -> bool {
    if not _pending_ok(idx, EXT_FUNC) { return False; }
    m: WModule = _MODS[_PENDING_MOD];
    tid: int = canon_type(m.types[m.funcs[m.imports[idx].index].type_index]);
    _TOKEN_TYPE[token] = tid;
    _PENDING[idx] = new_host_func(tid, token);
    return True;
}

"""Import slot `idx` is an exported wasm function (direct call, type-checked
at instantiation)."""
def:pub wasm_imports_add_wasm_func(idx: int, fh: int) -> bool {
    if not _pending_ok(idx, EXT_FUNC) { return False; }
    if not _valid(fh, len(_FUNCS)) { _set_err("invalid function handle", WASM_ERRCLASS_LINK); return False; }
    _PENDING[idx] = _FUNCS[fh];
    return True;
}

def:pub wasm_imports_add_memory(idx: int, mh: int) -> bool {
    if not _pending_ok(idx, EXT_MEMORY) { return False; }
    if not _valid(mh, len(_MEMS)) { _set_err("invalid memory handle", WASM_ERRCLASS_LINK); return False; }
    _PENDING[idx] = _MEMS[mh];
    return True;
}

def:pub wasm_imports_add_global(idx: int, gh: int) -> bool {
    if not _pending_ok(idx, EXT_GLOBAL) { return False; }
    if not _valid(gh, len(_GLOBALS)) { _set_err("invalid global handle", WASM_ERRCLASS_LINK); return False; }
    _PENDING[idx] = _GLOBALS[gh];
    return True;
}

def:pub wasm_imports_add_table(idx: int, th: int) -> bool {
    if not _pending_ok(idx, EXT_TABLE) { return False; }
    if not _valid(th, len(_TABLES)) { _set_err("invalid table handle", WASM_ERRCLASS_LINK); return False; }
    _PENDING[idx] = _TABLES[th];
    return True;
}

def:pub wasm_instantiate_with_imports(h: int) -> int {
    if h != _PENDING_MOD { _set_err("imports were built for another module", WASM_ERRCLASS_LINK); return 0; }
    imps: list[int] = _PENDING;
    _PENDING = [];
    return _finish_instantiate(h, imps);
}

# ── Instance exports ─────────────────────────────────────────────────────────

def:pub wasm_inst_export_count(ih: int) -> int {
    if not _valid(ih, len(_INSTS)) { return 0; }
    return len(_INSTS[ih].export_names);
}

def:pub wasm_inst_export_name(ih: int, i: int) -> str { return _INSTS[ih].export_names[i]; }
def:pub wasm_inst_export_kind(ih: int, i: int) -> int { return _extern_of(_INSTS[ih].export_kinds[i]); }

def _export(ih: int, name: str, kind: int) -> int {
    if not _valid(ih, len(_INSTS)) { _set_err("invalid instance handle", WASM_ERRCLASS_LINK); return 0; }
    inst: WInstance = _INSTS[ih];
    i: int = export_index(inst, name);
    if i < 0 or inst.export_kinds[i] != kind { _set_err("no such export: " + name, WASM_ERRCLASS_LINK); return 0; }
    return inst.export_vals[i];
}

def:pub wasm_bind_export_func(ih: int, name: str) -> int {
    f: int = _export(ih, name, EXT_FUNC);
    if f == 0 { return 0; }
    return _func_handle(f);
}

def:pub wasm_inst_export_memory(ih: int, name: str) -> int {
    m: int = _export(ih, name, EXT_MEMORY);
    if m == 0 { return 0; }
    return _mem_handle(m);
}

def:pub wasm_export_global(ih: int, name: str) -> int {
    g: int = _export(ih, name, EXT_GLOBAL);
    if g == 0 { return 0; }
    return _global_handle(g);
}

def:pub wasm_export_table(ih: int, name: str) -> int {
    t: int = _export(ih, name, EXT_TABLE);
    if t == 0 { return 0; }
    return _table_handle(t);
}

# ── Function calls ───────────────────────────────────────────────────────────

def:pub wasm_func_param_count(fh: int) -> int {
    if not _valid(fh, len(_FUNCS)) { return -1; }
    return len(type_params(func_type_id(_FUNCS[fh])));
}

def:pub wasm_func_param_kind(fh: int, i: int) -> int {
    if not _valid(fh, len(_FUNCS)) { return -1; }
    ps: list[int] = type_params(func_type_id(_FUNCS[fh]));
    if i < 0 or i >= len(ps) { return -1; }
    return _kind_of(ps[i]);
}

glob _RES_KIND: list[int] = [];
glob _RES_INT: list[int] = [];
glob _RES_DBL: list[float] = [];

def:pub wasm_call_result_count() -> int { return len(_RES_KIND); }
def:pub wasm_call_result_kind(i: int) -> int { return _RES_KIND[i]; }
def:pub wasm_call_result_int(i: int) -> int { return _RES_INT[i]; }
def:pub wasm_call_result_dbl(i: int) -> float { return _RES_DBL[i]; }

"""Call an exported function. Argument lists are parallel per param (ints for
integer/ref kinds, doubles for float kinds). `arg_raw` (same length, may be
empty) marks params that carry a raw bit pattern in arg_ints — used for
NaN-payload float args, which must not pass through a JSValue double (the
JS number canonicalises payload and sign). Returns False on trap."""
def:pub wasm_func_invoke(fh: int, arg_ints: list[int], arg_dbls: list[float], arg_raw: list[int]) -> bool {
    _set_err("", WASM_ERRCLASS_NONE);
    if not _valid(fh, len(_FUNCS)) { _set_err("invalid function handle", WASM_ERRCLASS_RUNTIME); return False; }
    f: int = _FUNCS[fh];
    tid: int = func_type_id(f);
    ps: list[int] = type_params(tid);
    args: list[int] = [];
    i: int = 0;
    while i < len(ps) {
        iv: int = 0;
        dv: float = 0.0;
        raw: int = 0;
        if i < len(arg_ints) { iv = arg_ints[i]; }
        if i < len(arg_dbls) { dv = arg_dbls[i]; }
        if i < len(arg_raw) { raw = arg_raw[i]; }
        k: int = _kind_of(ps[i]);
        if raw != 0 { args.append(_to_slot_bits(k, iv)); }
        else { args.append(_to_slot(k, iv, dv)); }
        i = i + 1;
    }
    if invoke(f, args) != 0 {
        _set_err(wasm_trap_message(), WASM_ERRCLASS_RUNTIME);
        return False;
    }
    rs: list[int] = type_results(tid);
    _RES_KIND = [];
    _RES_INT = [];
    _RES_DBL = [];
    j: int = 0;
    while j < len(rs) {
        k: int = _kind_of(rs[j]);
        v: int = invoke_result(j);
        _RES_KIND.append(k);
        if k == WASMTIME_F32 or k == WASMTIME_F64 { _RES_INT.append(0); _RES_DBL.append(_slot_dbl(v)); }
        elif k == WASMTIME_FUNCREF { _RES_INT.append(0 if v == 0 else _func_handle(v)); _RES_DBL.append(0.0); }
        elif k == WASMTIME_EXTERNREF { _RES_INT.append(v); _RES_DBL.append(0.0); }
        else { _RES_INT.append(v); _RES_DBL.append(0.0); }
        j = j + 1;
    }
    return True;
}

# ── Host imports ─────────────────────────────────────────────────────────────
glob _HOST_CB: list[Callable[[int, int], int]] = [];
glob _TOKEN_TYPE: dict[int, int] = {};
glob _HOST_ARG_KINDS: list[int] = [];
glob _HOST_ARG_INTS: list[int] = [];
glob _HOST_ARG_DBLS: list[float] = [];
glob _HOST_RES_KINDS: list[int] = [];
glob _HOST_RES_INTS: list[int] = [];
glob _HOST_RES_DBLS: list[float] = [];
glob _HOST_THROW: str = "";
glob _HOST_READY: bool = False;

def:pub wasm_register_host_call(cb: Callable[[int, int], int]) -> None {
    if len(_HOST_CB) == 0 { _HOST_CB.append(cb); } else { _HOST_CB[0] = cb; }
}

def _ensure_host() -> None {
    if not _HOST_READY {
        set_host_handler(_host_dispatch);
        _HOST_READY = True;
    }
}

def:pub wasm_host_arg_count() -> int { return len(_HOST_ARG_KINDS); }
def:pub wasm_host_arg_kind(i: int) -> int { return _HOST_ARG_KINDS[i]; }
def:pub wasm_host_arg_int(i: int) -> int { return _HOST_ARG_INTS[i]; }
def:pub wasm_host_arg_dbl(i: int) -> float { return _HOST_ARG_DBLS[i]; }

def:pub wasm_host_result_kind_count(token: int) -> int {
    if not (token in _TOKEN_TYPE) { return 0; }
    return len(type_results(_TOKEN_TYPE[token]));
}

def:pub wasm_host_result_kind(token: int, i: int) -> int {
    rs: list[int] = type_results(_TOKEN_TYPE[token]);
    if i < 0 or i >= len(rs) { return -1; }
    return _kind_of(rs[i]);
}

def:pub wasm_host_push_result(kind: int, ival: int, dval: float) -> None {
    _HOST_RES_KINDS.append(kind);
    _HOST_RES_INTS.append(ival);
    _HOST_RES_DBLS.append(dval);
}

def:pub wasm_host_reset_results() -> None {
    _HOST_RES_KINDS = [];
    _HOST_RES_INTS = [];
    _HOST_RES_DBLS = [];
}

def:pub wasm_set_host_throw(msg: str) -> None { _HOST_THROW = msg; }

"""exec.jac host handler: run the JS import `token` with the args in `slots`
and write its results back into `slots`."""
def _host_dispatch(token: int, slots: int, frec: int) -> int {
    tid: int = func_type_id(frec);
    ps: list[int] = type_params(tid);
    _HOST_ARG_KINDS = [];
    _HOST_ARG_INTS = [];
    _HOST_ARG_DBLS = [];
    i: int = 0;
    while i < len(ps) {
        k: int = _kind_of(ps[i]);
        v: int = __mem_load_i64(slots + i * 8);
        _HOST_ARG_KINDS.append(k);
        if k == WASMTIME_F32 or k == WASMTIME_F64 { _HOST_ARG_INTS.append(0); _HOST_ARG_DBLS.append(_slot_dbl(v)); }
        elif k == WASMTIME_FUNCREF { _HOST_ARG_INTS.append(0 if v == 0 else _func_handle(v)); _HOST_ARG_DBLS.append(0.0); }
        else { _HOST_ARG_INTS.append(v); _HOST_ARG_DBLS.append(0.0); }
        i = i + 1;
    }
    if len(_HOST_CB) == 0 { return wasm_set_trap("wasm host import: no VM callback registered"); }
    _HOST_THROW = "";
    wasm_host_reset_results();
    cb: Callable[[int, int], int] = _HOST_CB[0];
    rc: int = cb(token, len(ps));
    if rc == 1 {
        msg: str = _HOST_THROW;
        if msg == "" { msg = "wasm host import threw"; }
        return wasm_set_trap(msg);
    }
    if rc == 2 { return wasm_set_trap("wasm host import: no active VM"); }
    rs: list[int] = type_results(tid);
    j: int = 0;
    while j < len(rs) {
        iv: int = 0;
        dv: float = 0.0;
        if j < len(_HOST_RES_INTS) { iv = _HOST_RES_INTS[j]; dv = _HOST_RES_DBLS[j]; }
        __mem_store_i64(slots + j * 8, _to_slot(_kind_of(rs[j]), iv, dv));
        j = j + 1;
    }
    return 0;
}

# ── Memories ─────────────────────────────────────────────────────────────────

def:pub wasm_memory_create(store_h: int, min_pages: int, max_pages: int) -> int {
    if min_pages > 65536 or (max_pages >= 0 and (max_pages > 65536 or max_pages < min_pages)) {
        _set_err("invalid memory limits", WASM_ERRCLASS_RUNTIME);
        return 0;
    }
    m: int = new_memory(min_pages, max_pages);
    if m == 0 { _set_err("memory allocation failed", WASM_ERRCLASS_RUNTIME); return 0; }
    return _mem_handle(m);
}

def:pub wasm_memory_data_ptr(mh: int) -> int {
    if not _valid(mh, len(_MEMS)) { return 0; }
    return mem_base(_MEMS[mh]);
}

def:pub wasm_memory_data_size(mh: int) -> int {
    if not _valid(mh, len(_MEMS)) { return 0; }
    return mem_size(_MEMS[mh]);
}

def:pub wasm_memory_size_pages(mh: int) -> int {
    if not _valid(mh, len(_MEMS)) { return 0; }
    return mem_pages(_MEMS[mh]);
}

def:pub wasm_memory_grow(mh: int, delta: int) -> int {
    if not _valid(mh, len(_MEMS)) { _set_err("invalid memory handle", WASM_ERRCLASS_RUNTIME); return -1; }
    old: int = mem_grow(_MEMS[mh], delta);
    if old < 0 { _set_err("memory.grow failed", WASM_ERRCLASS_RUNTIME); }
    return old;
}

"""Memories are shared with instances that may still use them; never freed."""
def:pub wasm_memory_free(mh: int) -> None { return; }

# ── Globals ──────────────────────────────────────────────────────────────────

def:pub wasm_global_create(kind: int, mutable: bool, ival: int, dval: float) -> int {
    return _global_handle(new_global(_vt_of(kind), mutable, _to_slot(kind, ival, dval)));
}

def:pub wasm_global_kind(gh: int) -> int {
    if not _valid(gh, len(_GLOBALS)) { return -1; }
    return _kind_of(global_type(_GLOBALS[gh]));
}

def:pub wasm_global_is_mutable(gh: int) -> bool {
    if not _valid(gh, len(_GLOBALS)) { return False; }
    return global_mutable(_GLOBALS[gh]);
}

def:pub wasm_global_get_int(gh: int) -> int {
    if not _valid(gh, len(_GLOBALS)) { return 0; }
    return global_get(_GLOBALS[gh]);
}

def:pub wasm_global_get_dbl(gh: int) -> float {
    if not _valid(gh, len(_GLOBALS)) { return 0.0; }
    return _slot_dbl(global_get(_GLOBALS[gh]));
}

def:pub wasm_global_set_val(gh: int, ival: int, dval: float) -> bool {
    if not _valid(gh, len(_GLOBALS)) { _set_err("invalid global handle", WASM_ERRCLASS_RUNTIME); return False; }
    g: int = _GLOBALS[gh];
    if not global_mutable(g) { _set_err("global is immutable", WASM_ERRCLASS_RUNTIME); return False; }
    global_set(g, _to_slot(_kind_of(global_type(g)), ival, dval));
    return True;
}

# ── Tables ───────────────────────────────────────────────────────────────────

def:pub wasm_table_create(elem_kind: int, initial: int, maximum: int, init_ref: int) -> int {
    if maximum >= 0 and maximum < initial { _set_err("invalid table limits", WASM_ERRCLASS_RUNTIME); return 0; }
    if initial > 10000000 { _set_err("table too large", WASM_ERRCLASS_RUNTIME); return 0; }
    t: int = new_table(_vt_of(elem_kind), initial, maximum);
    fill: int = init_ref;
    if table_elem_type(t) == T_FUNCREF and fill != 0 {
        if not _valid(fill, len(_FUNCS)) { _set_err("invalid function handle", WASM_ERRCLASS_RUNTIME); return 0; }
        fill = _FUNCS[fill];
    }
    if fill != 0 {
        i: int = 0;
        while i < initial { table_set(t, i, fill); i = i + 1; }
    }
    return _table_handle(t);
}

def:pub wasm_table_size(th: int) -> int {
    if not _valid(th, len(_TABLES)) { return 0; }
    return table_size(_TABLES[th]);
}

"""-1 out of bounds; 0 null; 1 non-null funcref; 2 non-null externref."""
def:pub wasm_table_get_kind(th: int, i: int) -> int {
    if not _valid(th, len(_TABLES)) { return -1; }
    t: int = _TABLES[th];
    if i < 0 or i >= table_size(t) { return -1; }
    if table_get(t, i) == 0 { return 0; }
    if table_elem_type(t) == T_EXTERNREF { return 2; }
    return 1;
}

def:pub wasm_table_set_null(th: int, i: int) -> bool {
    if not _valid(th, len(_TABLES)) { _set_err("invalid table handle", WASM_ERRCLASS_RUNTIME); return False; }
    t: int = _TABLES[th];
    if i < 0 or i >= table_size(t) { _set_err("table index out of bounds", WASM_ERRCLASS_RUNTIME); return False; }
    table_set(t, i, 0);
    return True;
}

def:pub wasm_table_set_func(th: int, i: int, fh: int) -> bool {
    if not _valid(th, len(_TABLES)) { _set_err("invalid table handle", WASM_ERRCLASS_RUNTIME); return False; }
    if not _valid(fh, len(_FUNCS)) { _set_err("invalid function handle", WASM_ERRCLASS_RUNTIME); return False; }
    t: int = _TABLES[th];
    if table_elem_type(t) != T_FUNCREF { _set_err("table element type mismatch", WASM_ERRCLASS_RUNTIME); return False; }
    if i < 0 or i >= table_size(t) { _set_err("table index out of bounds", WASM_ERRCLASS_RUNTIME); return False; }
    table_set(t, i, _FUNCS[fh]);
    return True;
}

def:pub wasm_table_grow(th: int, delta: int, init_ref: int) -> int {
    if not _valid(th, len(_TABLES)) { _set_err("invalid table handle", WASM_ERRCLASS_RUNTIME); return -1; }
    t: int = _TABLES[th];
    fill: int = init_ref;
    if table_elem_type(t) == T_FUNCREF and fill != 0 {
        if not _valid(fill, len(_FUNCS)) { _set_err("invalid function handle", WASM_ERRCLASS_RUNTIME); return -1; }
        fill = _FUNCS[fill];
    }
    old: int = table_grow(t, delta, fill);
    if old < 0 { _set_err("table.grow failed", WASM_ERRCLASS_RUNTIME); }
    return old;
}

"""Element kind of a table (WASMTIME_FUNCREF / WASMTIME_EXTERNREF), -1 on a
bad handle."""
def:pub wasm_table_elem_kind(th: int) -> int {
    if not _valid(th, len(_TABLES)) { return -1; }
    return _kind_of(table_elem_type(_TABLES[th]));
}

"""Ref slot at `i`: funcref tables return the func handle, externref tables
the extern id. -1 out of bounds, 0 null."""
def:pub wasm_table_get_ref(th: int, i: int) -> int {
    if not _valid(th, len(_TABLES)) { return -1; }
    t: int = _TABLES[th];
    if i < 0 or i >= table_size(t) { return -1; }
    v: int = table_get(t, i);
    if v == 0 { return 0; }
    if table_elem_type(t) == T_FUNCREF { return _func_handle(v); }
    return v;
}

"""Store a ref slot: `ival` is a func handle for funcref tables, a raw extern
id for externref tables (the caller computes it from the JSValue)."""
def:pub wasm_table_set_ref(th: int, i: int, ival: int) -> bool {
    if not _valid(th, len(_TABLES)) { _set_err("invalid table handle", WASM_ERRCLASS_RUNTIME); return False; }
    t: int = _TABLES[th];
    if i < 0 or i >= table_size(t) { _set_err("table index out of bounds", WASM_ERRCLASS_RUNTIME); return False; }
    if table_elem_type(t) == T_FUNCREF {
        if ival == 0 { table_set(t, i, 0); return True; }
        if not _valid(ival, len(_FUNCS)) { _set_err("invalid function handle", WASM_ERRCLASS_RUNTIME); return False; }
        table_set(t, i, _FUNCS[ival]);
        return True;
    }
    table_set(t, i, ival);
    return True;
}

"""Ref slot of a global: func handle for funcref, extern id for externref."""
def:pub wasm_global_get_ref(gh: int) -> int {
    if not _valid(gh, len(_GLOBALS)) { return 0; }
    v: int = global_get(_GLOBALS[gh]);
    if v == 0 { return 0; }
    if global_type(_GLOBALS[gh]) == T_FUNCREF { return _func_handle(v); }
    return v;
}

"""Set a ref-typed global: func handle for funcref, extern id for externref."""
def:pub wasm_global_set_ref(gh: int, ival: int) -> bool {
    if not _valid(gh, len(_GLOBALS)) { _set_err("invalid global handle", WASM_ERRCLASS_RUNTIME); return False; }
    g: int = _GLOBALS[gh];
    if not global_mutable(g) { _set_err("global is immutable", WASM_ERRCLASS_RUNTIME); return False; }
    v: int = ival;
    if global_type(g) == T_FUNCREF {
        if ival == 0 { v = 0; }
        elif _valid(ival, len(_FUNCS)) { v = _FUNCS[ival]; }
        else { _set_err("invalid function handle", WASM_ERRCLASS_RUNTIME); return False; }
    }
    global_set(g, v);
    return True;
}
