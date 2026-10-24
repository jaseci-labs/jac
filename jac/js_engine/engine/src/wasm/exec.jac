"""WebAssembly runtime + interpreter (Jac native).

Runtime records live in raw memory so the dispatch loop reads them with
single loads (layouts below, word = 8 bytes). Values in frame slots:
  i32        sign-extended int
  i64        int
  f32        bits of the double holding the f32 value (exact; NaN payloads
             preserved by f32_bits_to_f64/f64_to_f32_bits at the boundaries)
  f64        double bits
  funcref    FuncRec pointer, 0 = null
  externref  host-assigned nonzero id, 0 = null

FuncRec   0 code  1 nparams  2 nlocals  3 max_slots  4 nresults  5 inst
          6 type_id  7 host_index (-1 for wasm)  8 module func index
InstRec   0 funcs[]  1 mem  2 globals[] (cell ptrs)  3 tables[]  4 elems[]
          5 datas[]  6 type_ids[]
MemRec    0 base  1 size (bytes)  2 max pages  3 pages
          4 retained base (only after a grow whose JS-view detach failed)
TableRec  0 elems  1 size  2 max  3 elem type
SegRec    0 ptr  1 len (0 once dropped)
"""

import from engine.src.runtime.mem { io_alloc }
import from engine.src.ffi.libc { calloc, free, memcpy, memmove, memset }
import from engine.src.ffi.libm { sqrt, trunc, floor, ceil }
import from engine.src.wasm.compile {
    WModule,
    WFunc,
    FuncType,
    WImport,
    WExport,
    WGlobal,
    WElem,
    WData,
    WTable,
    f32_bits_to_f64,
    f64_to_f32_bits,
    SIGN64,
    T_I32,
    T_I64,
    T_F32,
    T_F64,
    T_FUNCREF,
    T_EXTERNREF,
    CE_CONST,
    CE_GLOBAL_GET,
    CE_REF_NULL,
    CE_REF_FUNC,
    EXT_FUNC,
    EXT_TABLE,
    EXT_MEMORY,
    EXT_GLOBAL
}

import from "libm.so.6" { def nearbyint(x: float) -> float;  }

glob M32: int = 4294967295,
     CANON_NAN: int = 9221120237041090560,
     F64_QUIET: int = 2251799813685248,
     MAX_PAGES: int = 65536,
     TABLE_MAX: int = 10000000,
     _TRAP: str = "";

# 0x7ff8000000000000
# 0x0008000000000000

# ── Traps ────────────────────────────────────────────────────────────────────
def:pub wasm_trap_message -> str {
    return _TRAP;
}

def _trap(msg: str) -> int {
    _TRAP = msg;
    return 1;
}

"""Record a trap raised by an embedder's host function (returns 1)."""
def:pub wasm_set_trap(msg: str) -> int {
    return _trap(msg);
}

# ── Canonical function types ─────────────────────────────────────────────────
glob _TYPE_KEYS: dict[str, int] = {},
     _TYPE_PARAMS: list[list[int]] = [[]],
     _TYPE_RESULTS: list[list[int]] = [[]];

def:pub canon_type(ft: FuncType) -> int {
    key: str = "";
    for t in ft.params {
        key = key + chr(t);
    }
    key = key + ":";
    for t2 in ft.results {
        key = key + chr(t2);
    }
    if key in _TYPE_KEYS {
        return _TYPE_KEYS[key];
    }
    id: int = len(_TYPE_PARAMS);
    _TYPE_KEYS[key] = id;
    _TYPE_PARAMS.append(ft.params);
    _TYPE_RESULTS.append(ft.results);
    return id;
}

def:pub type_params(id: int) -> list[int] {
    return _TYPE_PARAMS[id];
}

def:pub type_results(id: int) -> list[int] {
    return _TYPE_RESULTS[id];
}

# ── Records ──────────────────────────────────────────────────────────────────

def _words(n: int) -> int {
    p: int = calloc(1, n * 8 + 8);
    return p;
}

def _ld(p: int, i: int) -> int {
    return __mem_load_i64(p + i * 8);
}

def _st(p: int, i: int, v: int) {
    __mem_store_i64(p + i * 8, v);
}

"""A host function record (code = 0); host_index is the embedder's token."""
def:pub new_host_func(type_id: int, host_index: int) -> int {
    f: int = _words(9);
    ps: list[int] = _TYPE_PARAMS[type_id];
    _st(f, 0, 0);
    _st(f, 1, len(ps));
    _st(f, 2, len(ps));
    _st(f, 3, len(ps) + len(_TYPE_RESULTS[type_id]) + 1);
    _st(f, 4, len(_TYPE_RESULTS[type_id]));
    _st(f, 5, 0);
    _st(f, 6, type_id);
    _st(f, 7, host_index);
    _st(f, 8, -1);
    return f;
}

def:pub func_type_id(f: int) -> int {
    return _ld(f, 6);
}

def:pub func_host_index(f: int) -> int {
    return _ld(f, 7);
}

def:pub func_nparams(f: int) -> int {
    return _ld(f, 1);
}

def:pub func_nresults(f: int) -> int {
    return _ld(f, 4);
}

def:pub new_memory(min_pages: int, max_pages: int) -> int {
    m: int = _words(5);
    size: int = min_pages * 65536;
    base: int = calloc(1, size + 8);
    if base == 0 {
        free(m);
        return 0;
    }
    _st(m, 0, base);
    _st(m, 1, size);
    _st(m, 2, max_pages);
    _st(m, 3, min_pages);
    # Slot 4 is the fallback retention for a grow whose JS-view detachment
    # could not be confirmed: the replaced base stays alive until a later
    # successful grow releases it (see mem_grow), so JS views into it never
    # dangle. Zero when the last grow detached every JS view — or none.
    _st(m, 4, 0);
    return m;
}

def:pub mem_base(m: int) -> int {
    return _ld(m, 0);
}

def:pub mem_size(m: int) -> int {
    return _ld(m, 1);
}

def:pub mem_pages(m: int) -> int {
    return _ld(m, 3);
}

def:pub mem_max(m: int) -> int {
    return _ld(m, 2);
}

"""Grow by `delta` pages; returns the old page count or -1.

A failed grow leaves the current backing store (and its JS views) alone.
A successful grow publishes the new base first, then lets the growth
observer (set_grow_notify) detach JS views into the old base BEFORE it is
freed; the one-slot retention (slot 4) only holds a base whose detachment
could not be confirmed, until a later successful grow releases it."""
def:pub mem_grow(m: int, delta: int) -> int {
    old: int = _ld(m, 3);
    if delta == 0 {
        return old;
    }
    newp: int = old + delta;
    lim: int = _ld(m, 2);
    if lim < 0 or lim > MAX_PAGES {
        lim = MAX_PAGES;
    }
    if newp > lim {
        return -1;
    }
    nsize: int = newp * 65536;
    nb: int = calloc(1, nsize + 8);
    if nb == 0 {
        return -1;
    }
    ob: int = _ld(m, 0);
    memcpy(nb, ob, _ld(m, 1));
    # Publish the new backing store before notifying: the observer re-enters
    # the embedder, which may query this memory through the bridge.
    _st(m, 0, nb);
    _st(m, 1, nsize);
    _st(m, 3, newp);
    released: bool = True;
    if len(_GROW_NOTIFY) > 0 {
        released = _GROW_NOTIFY[0](m, ob) == 0;
    }
    prev: int = _ld(m, 4);
    if released {
        # A confirmed detach covers every JS view of `ob` and of `prev` (a
        # base parked by an earlier failed detach); both are safe to free.
        if prev != 0 {
            free(prev);
        }
        free(ob);
        _st(m, 4, 0);
    } else {
        # Detachment could not be confirmed (observer failed): keep `ob`
        # alive until a later successful grow releases it. `prev` was parked
        # the same way, so freeing it here could strand live JS views — it
        # leaks instead, which is the safe direction.
        _st(m, 4, ob);
    }
    return old;
}

def:pub new_table(elem: int, min_size: int, max_size: int) -> int {
    t: int = _words(4);
    if t == 0 {
        return 0;
    }
    cells: int = calloc(1, min_size * 8 + 8);
    if cells == 0 {
        free(t);
        return 0;
    }
    _st(t, 0, cells);
    _st(t, 1, min_size);
    _st(t, 2, max_size);
    _st(t, 3, elem);
    return t;
}

def:pub table_size(t: int) -> int {
    return _ld(t, 1);
}

def:pub table_max(t: int) -> int {
    return _ld(t, 2);
}

def:pub table_elem_type(t: int) -> int {
    return _ld(t, 3);
}

def:pub table_get(t: int, i: int) -> int {
    return _ld(_ld(t, 0), i);
}

def:pub table_set(t: int, i: int, v: int) {
    _st(_ld(t, 0), i, v);
}

"""Grow by `delta` entries filled with `init`; returns old size or -1."""
def:pub table_grow(t: int, delta: int, init: int) -> int {
    old: int = _ld(t, 1);
    newn: int = old + delta;
    lim: int = _ld(t, 2);
    if lim < 0 or lim > TABLE_MAX {
        lim = TABLE_MAX;
    }
    if newn > lim {
        return -1;
    }
    if delta == 0 {
        return old;
    }
    ne: int = calloc(1, newn * 8 + 8);
    if ne == 0 {
        return -1;
    }
    memcpy(ne, _ld(t, 0), old * 8);
    i: int = old;
    while i < newn {
        _st(ne, i, init);
        i = i + 1;
    }
    free(_ld(t, 0));
    _st(t, 0, ne);
    _st(t, 1, newn);
    return old;
}

"""A global cell (8 bytes) plus its type, tracked for import checks."""
glob _GLOBAL_TYPE: dict[int, int] = {};
glob _GLOBAL_MUT: dict[int, bool] = {};

def:pub new_global(vtype: int, mutable: bool, value: int) -> int {
    c: int = _words(1);
    _st(c, 0, value);
    _GLOBAL_TYPE[c] = vtype;
    _GLOBAL_MUT[c] = mutable;
    return c;
}

def:pub global_type(c: int) -> int {
    return _GLOBAL_TYPE[c];
}

def:pub global_mutable(c: int) -> bool {
    return _GLOBAL_MUT[c];
}

def:pub global_get(c: int) -> int {
    return _ld(c, 0);
}

def:pub global_set(c: int, v: int) {
    _st(c, 0, v);
}

# ── Instances ────────────────────────────────────────────────────────────────

obj:pub WInstance {
    has rec: int = 0,
        module: WModule = WModule(),
        funcs: list[int] = [],
        tables: list[int] = [],
        mem: int = 0,
        globals: list[int] = [],
        export_names: list[str] = [],
        export_kinds: list[int] = [],
        export_vals: list[int] = [];
}

glob _LINK_ERR: str = "";
def:pub wasm_link_error -> str {
    return _LINK_ERR;
}

"""Extern values supplied for each import, in import order (FuncRec /
TableRec / MemRec / global cell pointers)."""
def:pub instantiate(m: WModule, imports: list[int]) -> WInstance | None {
    _LINK_ERR = "";
    _TRAP = "";
    inst: WInstance = WInstance(module=m);
    nfuncs: int = len(m.funcs);
    rec: int = _words(8);
    inst.rec = rec;
    type_ids: int = _words(len(m.types) + 1);
    k: int = 0;
    while k < len(m.types) {
        _st(type_ids, k, canon_type(m.types[k]));
        k = k + 1;
    }
    _st(rec, 6, type_ids);
    funcs_arr: int = _words(nfuncs + 1);
    _st(rec, 0, funcs_arr);

    # Resolve imports with type checks.
    if len(imports) != len(m.imports) {
        _LINK_ERR = "import count mismatch";
        return None;
    }
    ii: int = 0;
    for imp in m.imports {
        v: int = imports[ii];
        if v == 0 {
            _LINK_ERR = "unknown import";
            return None;
        }
        if imp.kind == EXT_FUNC {
            want: int = canon_type(m.types[m.funcs[imp.index].type_index]);
            if _ld(v, 6) != want {
                _LINK_ERR = "incompatible import type";
                return None;
            }
            inst.funcs.append(v);
        } elif imp.kind == EXT_TABLE {
            tt: WTable = m.tables[imp.index];
            if _ld(v, 3) != tt.elem or _ld(v, 1) < tt.min {
                _LINK_ERR = "incompatible import type";
                return None;
            }
            if tt.max >= 0 and (_ld(v, 2) < 0 or _ld(v, 2) > tt.max) {
                _LINK_ERR = "incompatible import type";
                return None;
            }
            inst.tables.append(v);
        } elif imp.kind == EXT_MEMORY {
            mn: int = m.mem_min[imp.index];
            mx: int = m.mem_max[imp.index];
            if _ld(v, 3) < mn {
                _LINK_ERR = "incompatible import type";
                return None;
            }
            if mx >= 0 and (_ld(v, 2) < 0 or _ld(v, 2) > mx) {
                _LINK_ERR = "incompatible import type";
                return None;
            }
            inst.mem = v;
        } else {
            g: WGlobal = m.globals[imp.index];
            if not (v in _GLOBAL_TYPE) {
                _LINK_ERR = "incompatible import type";
                return None;
            }
            if _GLOBAL_TYPE[v] != g.vtype or _GLOBAL_MUT[v] != g.mutable {
                _LINK_ERR = "incompatible import type";
                return None;
            }
            inst.globals.append(v);
        }
        ii = ii + 1;
    }

    # Defined functions.
    fi: int = m.n_imported_funcs;
    while fi < nfuncs {
        wf: WFunc = m.funcs[fi];
        f: int = _words(9);
        ft: FuncType = m.types[wf.type_index];
        _st(f, 0, wf.code);
        _st(f, 1, len(ft.params));
        _st(f, 2, wf.nlocals);
        _st(f, 3, wf.max_slots);
        _st(f, 4, len(ft.results));
        _st(f, 5, rec);
        _st(f, 6, canon_type(ft));
        _st(f, 7, -1);
        _st(f, 8, fi);
        inst.funcs.append(f);
        fi = fi + 1;
    }
    k = 0;
    while k < nfuncs {
        _st(funcs_arr, k, inst.funcs[k]);
        k = k + 1;
    }

    # Tables and memory.
    ti: int = m.n_imported_tables;
    while ti < len(m.tables) {
        wt: WTable = m.tables[ti];
        nt: int = new_table(wt.elem, wt.min, wt.max);
        if nt == 0 {
            _LINK_ERR = "table allocation failed";
            return None;
        }
        inst.tables.append(nt);
        ti = ti + 1;
    }
    tables_arr: int = _words(len(inst.tables) + 1);
    k = 0;
    while k < len(inst.tables) {
        _st(tables_arr, k, inst.tables[k]);
        k = k + 1;
    }
    _st(rec, 3, tables_arr);
    if m.n_imported_mems == 0 and len(m.mem_min) > 0 {
        inst.mem = new_memory(m.mem_min[0], m.mem_max[0]);
        if inst.mem == 0 {
            _LINK_ERR = "memory allocation failed";
            return None;
        }
    }
    _st(rec, 1, inst.mem);

    # Globals (initializers may read imported globals and ref.func).
    gi: int = m.n_imported_globals;
    while gi < len(m.globals) {
        wg: WGlobal = m.globals[gi];
        inst.globals.append(
            new_global(wg.vtype, wg.mutable, _eval_ce(inst, wg.ce_kind, wg.ce_value))
        );
        gi = gi + 1;
    }
    globals_arr: int = _words(len(inst.globals) + 1);
    k = 0;
    while k < len(inst.globals) {
        _st(globals_arr, k, inst.globals[k]);
        k = k + 1;
    }
    _st(rec, 2, globals_arr);

    # Segments.
    elems_arr: int = _words(len(m.elems) + 1);
    k = 0;
    while k < len(m.elems) {
        e: WElem = m.elems[k];
        seg: int = _words(2);
        n: int = len(e.ce_kinds);
        vals: int = _words(n + 1);
        j: int = 0;
        while j < n {
            _st(vals, j, _eval_ce(inst, e.ce_kinds[j], e.ce_values[j]));
            j = j + 1;
        }
        _st(seg, 0, vals);
        _st(seg, 1, n);
        if e.mode != 1 {
            _st(seg, 1, 0);
        }  # active/declarative: dropped after use
        _st(elems_arr, k, seg);
        k = k + 1;
    }
    _st(rec, 4, elems_arr);
    datas_arr: int = _words(len(m.datas) + 1);
    k = 0;
    while k < len(m.datas) {
        d: WData = m.datas[k];
        dseg: int = _words(2);
        _st(dseg, 0, d.ptr);
        _st(dseg, 1, d.size);
        if d.mode == 0 {
            _st(dseg, 1, 0);
        }
        _st(datas_arr, k, dseg);
        k = k + 1;
    }
    _st(rec, 5, datas_arr);

    # Exports.
    for ex in m.exports {
        inst.export_names.append(ex.name);
        inst.export_kinds.append(ex.kind);
        if ex.kind == EXT_FUNC {
            inst.export_vals.append(inst.funcs[ex.index]);
        } elif ex.kind == EXT_TABLE {
            inst.export_vals.append(inst.tables[ex.index]);
        } elif ex.kind == EXT_MEMORY {
            inst.export_vals.append(inst.mem);
        } else {
            inst.export_vals.append(inst.globals[ex.index]);
        }
    }

    # Active element and data segments, in order (bulk-memory semantics: an
    # out-of-bounds segment traps after earlier ones were applied).
    k = 0;
    while k < len(m.elems) {
        e2: WElem = m.elems[k];
        if e2.mode == 0 {
            off: int = _eval_ce(inst, e2.off_kind, e2.off_value) & M32;
            t: int = inst.tables[e2.table];
            n2: int = len(e2.ce_kinds);
            if off + n2 > _ld(t, 1) {
                _trap("out of bounds table access");
                return None;
            }
            vals2: int = _ld(_ld(elems_arr, k), 0);
            j2: int = 0;
            while j2 < n2 {
                _st(_ld(t, 0), off + j2, _ld(vals2, j2));
                j2 = j2 + 1;
            }
        }
        k = k + 1;
    }
    k = 0;
    while k < len(m.datas) {
        d2: WData = m.datas[k];
        if d2.mode == 0 {
            doff: int = _eval_ce(inst, d2.off_kind, d2.off_value) & M32;
            if doff + d2.size > _ld(inst.mem, 1) {
                _trap("out of bounds memory access");
                return None;
            }
            memcpy(_ld(inst.mem, 0) + doff, d2.ptr, d2.size);
        }
        k = k + 1;
    }

    if m.start >= 0 {
        if invoke(inst.funcs[m.start], []) != 0 {
            return None;
        }
    }
    return inst;
}

def _eval_ce(inst: WInstance, kind: int, value: int) -> int {
    if kind == CE_CONST {
        return value;
    }
    if kind == CE_GLOBAL_GET {
        return _ld(inst.globals[value], 0);
    }
    if kind == CE_REF_FUNC {
        return inst.funcs[value];
    }
    return 0;
}

def:pub export_index(inst: WInstance, name: str) -> int {
    i: int = 0;
    while i < len(inst.export_names) {
        if inst.export_names[i] == name {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

# ── Host calls ───────────────────────────────────────────────────────────────
# The embedder's handler: (host_index, slots_ptr, func_rec) -> 0 ok / 1 trap.
# Arguments are read from slots_ptr[0..nparams) and results written to
# slots_ptr[0..nresults) in the slot representation above.
glob _HOST: list[Callable[[int, int, int], int]] = [];

def:pub set_host_handler(cb: Callable[[int, int, int], int]) {
    if len(_HOST) == 0 {
        _HOST.append(cb);
    } else {
        _HOST[0] = cb;
    }
}

# ── Stacks ───────────────────────────────────────────────────────────────────
glob VS_SLOTS: int = 1048576,
     FS_FRAMES: int = 65536,
     _VS: int = 0,
     _VS_END: int = 0,
     _VS_TOP: int = 0,
     _FS: int = 0,
     _FS_TOP: int = 0;  # 8 MiB of value slots

# call depth limit

# first free slot (bytes) for a new entry

# first free frame index
def _ensure_stacks {
    if _VS == 0 {
        _VS = calloc(1, VS_SLOTS * 8 + 64);
        _VS_END = _VS + VS_SLOTS * 8;
        _VS_TOP = _VS;
        _FS = calloc(1, FS_FRAMES * 24 + 64);
        _FS_TOP = 0;
    }
}

"""Call function record `f` with `args` (slot representation). Results are
read with invoke_result(i). Returns 0, or 1 on trap (wasm_trap_message())."""
glob _RESULTS: list[int] = [];

def:pub invoke(f: int, args: list[int]) -> int {
    _ensure_stacks();
    _TRAP = "";
    fp: int = _VS_TOP;
    need: int = _ld(f, 3);
    if fp + need * 8 > _VS_END {
        return _trap("call stack exhausted");
    }
    i: int = 0;
    while i < len(args) {
        __mem_store_i64(fp + i * 8, args[i]);
        i = i + 1;
    }
    saved_top: int = _VS_TOP;
    saved_fs: int = _FS_TOP;
    rc: int = 0;
    if _ld(f, 0) == 0 {
        _VS_TOP = fp + need * 8;
        hcb: Callable[[int, int, int], int] = _HOST[0];
        rc = hcb(_ld(f, 7), fp, f);
    } else {
        rc = _run(f, fp);
    }
    _VS_TOP = saved_top;
    _FS_TOP = saved_fs;
    _RESULTS = [];
    if rc == 0 {
        n: int = _ld(f, 4);
        j: int = 0;
        while j < n {
            _RESULTS.append(__mem_load_i64(fp + j * 8));
            j = j + 1;
        }
    }
    return rc;
}

def:pub invoke_result(i: int) -> int {
    return _RESULTS[i];
}

def:pub invoke_result_count -> int {
    return len(_RESULTS);
}

# ── Numeric helpers ──────────────────────────────────────────────────────────

def _fdiv(a: float, b: float) -> float {
    if b != 0.0 {
        return a / b;
    }
    if a != a or a == 0.0 {
        return __bits_float(CANON_NAN);
    }
    neg: bool = (__float_bits(a) < 0) != (__float_bits(b) < 0);
    if neg {
        return __bits_float(-4503599627370496);
    }  # -inf 0xfff0000000000000
    return __bits_float(9218868437227405312);  # +inf 0x7ff0000000000000
}

def _fmin(a: float, b: float) -> float {
    if a != a or b != b {
        return __bits_float(CANON_NAN);
    }
    if a == b {
        return __bits_float(__float_bits(a) | __float_bits(b));
    }
    if a < b {
        return a;
    }
    return b;
}

def _fmax(a: float, b: float) -> float {
    if a != a or b != b {
        return __bits_float(CANON_NAN);
    }
    if a == b {
        return __bits_float(__float_bits(a) & __float_bits(b));
    }
    if a > b {
        return a;
    }
    return b;
}

def _f32r(d: float) -> float {
    return float(f32(d));
}

def _clz64(x: int) -> int {
    if x == 0 {
        return 64;
    }
    if x < 0 {
        return 0;
    }
    n: int = 0;
    if (x >> 32) == 0 {
        n = n + 32;
        x = x << 32;
    }
    if (x >> 48) == 0 {
        n = n + 16;
        x = x << 16;
    }
    if (x >> 56) == 0 {
        n = n + 8;
        x = x << 8;
    }
    if (x >> 60) == 0 {
        n = n + 4;
        x = x << 4;
    }
    if (x >> 62) == 0 {
        n = n + 2;
        x = x << 2;
    }
    if (x >> 63) == 0 {
        n = n + 1;
    }
    return n;
}

def _popcnt64(x: int) -> int {
    n: int = 0;
    if x < 0 {
        n = 1;
        x = x & 9223372036854775807;
    }
    while x != 0 {
        x = x & (x - 1);
        n = n + 1;
    }
    return n;
}

def _ctz64(x: int) -> int {
    if x == 0 {
        return 64;
    }
    n: int = 0;
    while (x & 1) == 0 {
        x = x >> 1;
        n = n + 1;
    }
    return n;
}

def _shr_u64(a: int, k: int) -> int {
    return int(i64.wrap(u64.wrap(a) >> u64.wrap(k)));
}

def _ltu64(a: int, b: int) -> bool {
    return (a ^ SIGN64) < (b ^ SIGN64);
}

"""u64 magnitude -> nearest f32 (single rounding), as a double."""
def _u64_to_f32(a: int) -> float {
    if a >= 0 and a < 9007199254740992 {
        return _f32r(float(a));
    }
    # keep 53 significant bits with a sticky bit below the f32 rounding point
    m: int = _shr_u64(a, 11) | (1 if (a & 2047) != 0 else 0);
    return _f32r(float(m) * 2048.0);
}

def _i64_to_f32(a: int) -> float {
    if a >= 0 {
        return _u64_to_f32(a);
    }
    if a == SIGN64 {
        return -9.223372036854776e18;
    }
    return 0.0 - _u64_to_f32(0 - a);
}

def _u64_to_f64(a: int) -> float {
    if a >= 0 {
        return float(a);
    }
    return float(_shr_u64(a, 1) | (a & 1)) * 2.0;
}

# Truncation with trap checks. _TRUNC_ERR is set to the trap message.
glob _TRUNC_ERR: str = "";

def _trunc_s(d: float, lo: float, hi: float) -> int {
    if d != d {
        _TRUNC_ERR = "invalid conversion to integer";
        return 0;
    }
    t: float = trunc(d);
    if t < lo or t >= hi {
        _TRUNC_ERR = "integer overflow";
        return 0;
    }
    return int(t);
}

def _trunc_u64(d: float) -> int {
    if d != d {
        _TRUNC_ERR = "invalid conversion to integer";
        return 0;
    }
    t: float = trunc(d);
    if t <= -1.0 or t >= 18446744073709551616.0 {
        _TRUNC_ERR = "integer overflow";
        return 0;
    }
    if t >= 9223372036854775808.0 {
        return int(t - 9223372036854775808.0) ^ SIGN64;
    }
    return int(t);
}

def _sat_s(d: float, lo: float, hi: float, lo_i: int, hi_i: int) -> int {
    if d != d {
        return 0;
    }
    if d <= lo {
        return lo_i;
    }
    if d >= hi {
        return hi_i;
    }
    return int(trunc(d));
}

def _sat_u64(d: float) -> int {
    if d != d or d <= 0.0 {
        return 0;
    }
    if d >= 18446744073709551616.0 {
        return -1;
    }
    t: float = trunc(d);
    if t >= 9223372036854775808.0 {
        return int(t - 9223372036854775808.0) ^ SIGN64;
    }
    return int(t);
}

def _divs(a: int, b: int) -> int {
    q: int = a // b;
    if (a % b) != 0 and (a ^ b) < 0 {
        q = q + 1;
    }
    return q;
}

def _rems(a: int, b: int) -> int {
    if b == -1 {
        return 0;
    }
    r: int = a % b;
    if r != 0 and (a ^ b) < 0 {
        r = r - b;
    }
    return r;
}

# ── Interpreter loop ─────────────────────────────────────────────────────────

def _run(entry_f: int, entry_fp: int) -> int {
    f: int = entry_f;
    fp: int = entry_fp;
    base_depth: int = _FS_TOP;
    depth: int = base_depth;
    pc: int = __mem_load_i64(f);
    # zero declared locals
    z: int = __mem_load_i64(f + 8);
    nl: int = __mem_load_i64(f + 16);
    while z < nl {
        __mem_store_i64(fp + z * 8, 0);
        z = z + 1;
    }
    inst: int = __mem_load_i64(f + 40);
    funcs: int = __mem_load_i64(inst);
    mem: int = __mem_load_i64(inst + 8);
    mb: int = 0;
    ms: int = 0;
    if mem != 0 {
        mb = __mem_load_i64(mem);
        ms = __mem_load_i64(mem + 8);
    }

    while True {
        op: int = __mem_load_i64(pc);
        if op == 9 {  # COPY dst src
            __mem_store_i64(
                fp + __mem_load_i64(pc + 8),
                __mem_load_i64(fp + __mem_load_i64(pc + 16))
            );
            pc = pc + 24;
        } elif op == 10 {  # CONST dst v
            __mem_store_i64(fp + __mem_load_i64(pc + 8), __mem_load_i64(pc + 16));
            pc = pc + 24;
        } elif op == 106 {  # i32.add
            __mem_store_i64(
                fp + __mem_load_i64(pc + 8),
                int(
                    i32.wrap(
                        __mem_load_i64(fp + __mem_load_i64(pc + 16))
                            + __mem_load_i64(fp + __mem_load_i64(pc + 24))
                    )
                )
            );
            pc = pc + 32;
        } elif op == 3 {  # BR_IF c tgt
            if __mem_load_i64(fp + __mem_load_i64(pc + 8)) != 0 {
                pc = __mem_load_i64(pc + 16);
            } else {
                pc = pc + 24;
            }
        } elif op == 4 {  # BR_UNLESS c tgt
            if __mem_load_i64(fp + __mem_load_i64(pc + 8)) == 0 {
                pc = __mem_load_i64(pc + 16);
            } else {
                pc = pc + 24;
            }
        } elif op == 2 {  # JMP
            pc = __mem_load_i64(pc + 8);
        } elif op >= 40 and op <= 53 {  # loads: dst addr off
            ea: int = (__mem_load_i64(fp + __mem_load_i64(pc + 16)) & M32)
                + __mem_load_i64(pc + 24);
            dst: int = fp + __mem_load_i64(pc + 8);
            pc = pc + 32;
            if op == 40 {
                if ea + 4 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(dst, int(__mem_load_i32(mb + ea)));
            } elif op == 41 {
                if ea + 8 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(dst, __mem_load_i64(mb + ea));
            } elif op == 42 {
                if ea + 4 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(
                    dst,
                    __float_bits(f32_bits_to_f64(int(__mem_load_i32(mb + ea)) & M32))
                );
            } elif op == 43 {
                if ea + 8 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(dst, __mem_load_i64(mb + ea));
            } elif op == 44 or op == 48 {
                if ea + 1 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(dst, int(__mem_load_i8(mb + ea)));
            } elif op == 45 or op == 49 {
                if ea + 1 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(dst, int(__mem_load_i8(mb + ea)) & 255);
            } elif op == 46 or op == 50 {
                if ea + 2 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(dst, int(__mem_load_i16(mb + ea)));
            } elif op == 47 or op == 51 {
                if ea + 2 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(dst, int(__mem_load_i16(mb + ea)) & 65535);
            } elif op == 52 {
                if ea + 4 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(dst, int(__mem_load_i32(mb + ea)));
            } else {
                if ea + 4 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(dst, int(__mem_load_i32(mb + ea)) & M32);
            }
        } elif op >= 54 and op <= 62 {  # stores: addr val off
            ea2: int = (__mem_load_i64(fp + __mem_load_i64(pc + 8)) & M32)
                + __mem_load_i64(pc + 24);
            v: int = __mem_load_i64(fp + __mem_load_i64(pc + 16));
            pc = pc + 32;
            if op == 54 or op == 62 {
                if ea2 + 4 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i32(mb + ea2, i32.wrap(v));
            } elif op == 55 or op == 57 {
                if ea2 + 8 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i64(mb + ea2, v);
            } elif op == 56 {
                if ea2 + 4 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i32(mb + ea2, i32.wrap(f64_to_f32_bits(__bits_float(v))));
            } elif op == 58 or op == 60 {
                if ea2 + 1 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i8(mb + ea2, i8.wrap(v));
            } else {
                if ea2 + 2 > ms {
                    return _trap("out of bounds memory access");
                }
                __mem_store_i8(mb + ea2, i8.wrap(v));
                __mem_store_i8(mb + ea2 + 1, i8.wrap(v >> 8));
            }
        } elif op >= 69 and op <= 196 {
            d: int = fp + __mem_load_i64(pc + 8);
            a: int = __mem_load_i64(fp + __mem_load_i64(pc + 16));
            if op <= 120 {
                # i32 ops (and i64/float compares)
                if op == 69 {
                    __mem_store_i64(d, 1 if a == 0 else 0);
                    pc = pc + 24;
                } elif op <= 79 {
                    b: int = __mem_load_i64(fp + __mem_load_i64(pc + 24));
                    pc = pc + 32;
                    r: bool = False;
                    if op == 70 {
                        r = a == b;
                    } elif op == 71 {
                        r = a != b;
                    } elif op == 72 {
                        r = a < b;
                    } elif op == 73 {
                        r = (a & M32) < (b & M32);
                    } elif op == 74 {
                        r = a > b;
                    } elif op == 75 {
                        r = (a & M32) > (b & M32);
                    } elif op == 76 {
                        r = a <= b;
                    } elif op == 77 {
                        r = (a & M32) <= (b & M32);
                    } elif op == 78 {
                        r = a >= b;
                    } else {
                        r = (a & M32) >= (b & M32);
                    }
                    __mem_store_i64(d, 1 if r else 0);
                } elif op == 80 {
                    __mem_store_i64(d, 1 if a == 0 else 0);
                    pc = pc + 24;
                } elif op <= 90 {
                    b2: int = __mem_load_i64(fp + __mem_load_i64(pc + 24));
                    pc = pc + 32;
                    r2: bool = False;
                    if op == 81 {
                        r2 = a == b2;
                    } elif op == 82 {
                        r2 = a != b2;
                    } elif op == 83 {
                        r2 = a < b2;
                    } elif op == 84 {
                        r2 = _ltu64(a, b2);
                    } elif op == 85 {
                        r2 = a > b2;
                    } elif op == 86 {
                        r2 = _ltu64(b2, a);
                    } elif op == 87 {
                        r2 = a <= b2;
                    } elif op == 88 {
                        r2 = not _ltu64(b2, a);
                    } elif op == 89 {
                        r2 = a >= b2;
                    } else {
                        r2 = not _ltu64(a, b2);
                    }
                    __mem_store_i64(d, 1 if r2 else 0);
                } elif op <= 102 {
                    x: float = __bits_float(a);
                    y: float = __bits_float(
                        __mem_load_i64(fp + __mem_load_i64(pc + 24))
                    );
                    pc = pc + 32;
                    oo: int = op;
                    if oo >= 97 {
                        oo = oo - 6;
                    }
                    r3: bool = False;
                    if oo == 91 {
                        r3 = x == y;
                    } elif oo == 92 {
                        r3 = x != y;
                    } elif oo == 93 {
                        r3 = x < y;
                    } elif oo == 94 {
                        r3 = x > y;
                    } elif oo == 95 {
                        r3 = x <= y;
                    } else {
                        r3 = x >= y;
                    }
                    __mem_store_i64(d, 1 if r3 else 0);
                } elif op <= 105 {
                    u: int = a & M32;
                    if op == 103 {
                        __mem_store_i64(d, _clz64(u) - 32);
                    } elif op == 104 {
                        if u == 0 {
                            __mem_store_i64(d, 32);
                        } else {
                            __mem_store_i64(d, _ctz64(u));
                        }
                    } else {
                        __mem_store_i64(d, _popcnt64(u));
                    }
                    pc = pc + 24;
                } else {
                    b3: int = __mem_load_i64(fp + __mem_load_i64(pc + 24));
                    pc = pc + 32;
                    if op == 107 {
                        __mem_store_i64(d, int(i32.wrap(a - b3)));
                    } elif op == 108 {
                        __mem_store_i64(d, int(i32.wrap(a * b3)));
                    } elif op == 109 {
                        if b3 == 0 {
                            return _trap("integer divide by zero");
                        }
                        if a == -2147483648 and b3 == -1 {
                            return _trap("integer overflow");
                        }
                        __mem_store_i64(d, _divs(a, b3));
                    } elif op == 110 {
                        if b3 == 0 {
                            return _trap("integer divide by zero");
                        }
                        __mem_store_i64(d, int(i32.wrap((a & M32) // (b3 & M32))));
                    } elif op == 111 {
                        if b3 == 0 {
                            return _trap("integer divide by zero");
                        }
                        __mem_store_i64(d, _rems(a, b3));
                    } elif op == 112 {
                        if b3 == 0 {
                            return _trap("integer divide by zero");
                        }
                        __mem_store_i64(d, int(i32.wrap((a & M32) % (b3 & M32))));
                    } elif op == 113 {
                        __mem_store_i64(d, a & b3);
                    } elif op == 114 {
                        __mem_store_i64(d, a | b3);
                    } elif op == 115 {
                        __mem_store_i64(d, a ^ b3);
                    } elif op == 116 {
                        __mem_store_i64(d, int(i32.wrap(a << (b3 & 31))));
                    } elif op == 117 {
                        __mem_store_i64(d, a >> (b3 & 31));
                    } elif op == 118 {
                        __mem_store_i64(d, int(i32.wrap((a & M32) >> (b3 & 31))));
                    } elif op == 119 {
                        k: int = b3 & 31;
                        xu: int = a & M32;
                        __mem_store_i64(
                            d, int(i32.wrap((xu << k) | (xu >> ((32 - k) & 31))))
                        );
                    } else {
                        k2: int = b3 & 31;
                        xu2: int = a & M32;
                        __mem_store_i64(
                            d, int(i32.wrap((xu2 >> k2) | (xu2 << ((32 - k2) & 31))))
                        );
                    }
                }
            } elif op <= 138 {
                # i64
                if op <= 123 {
                    if op == 121 {
                        __mem_store_i64(d, _clz64(a));
                    } elif op == 122 {
                        __mem_store_i64(d, _ctz64(a));
                    } else {
                        __mem_store_i64(d, _popcnt64(a));
                    }
                    pc = pc + 24;
                } else {
                    b4: int = __mem_load_i64(fp + __mem_load_i64(pc + 24));
                    pc = pc + 32;
                    if op == 124 {
                        __mem_store_i64(d, wrapping_add(a, b4));
                    } elif op == 125 {
                        __mem_store_i64(d, wrapping_sub(a, b4));
                    } elif op == 126 {
                        __mem_store_i64(d, wrapping_mul(a, b4));
                    } elif op == 127 {
                        if b4 == 0 {
                            return _trap("integer divide by zero");
                        }
                        if a == SIGN64 and b4 == -1 {
                            return _trap("integer overflow");
                        }
                        __mem_store_i64(d, _divs(a, b4));
                    } elif op == 128 {
                        if b4 == 0 {
                            return _trap("integer divide by zero");
                        }
                        __mem_store_i64(d, int(i64.wrap(u64.wrap(a) // u64.wrap(b4))));
                    } elif op == 129 {
                        if b4 == 0 {
                            return _trap("integer divide by zero");
                        }
                        __mem_store_i64(d, _rems(a, b4));
                    } elif op == 130 {
                        if b4 == 0 {
                            return _trap("integer divide by zero");
                        }
                        __mem_store_i64(d, int(i64.wrap(u64.wrap(a) % u64.wrap(b4))));
                    } elif op == 131 {
                        __mem_store_i64(d, a & b4);
                    } elif op == 132 {
                        __mem_store_i64(d, a | b4);
                    } elif op == 133 {
                        __mem_store_i64(d, a ^ b4);
                    } elif op == 134 {
                        __mem_store_i64(d, wrapping_shl(a, b4 & 63));
                    } elif op == 135 {
                        __mem_store_i64(d, a >> (b4 & 63));
                    } elif op == 136 {
                        __mem_store_i64(d, _shr_u64(a, b4 & 63));
                    } elif op == 137 {
                        k3: int = b4 & 63;
                        if k3 == 0 {
                            __mem_store_i64(d, a);
                        } else {
                            __mem_store_i64(
                                d, wrapping_shl(a, k3) | _shr_u64(a, 64 - k3)
                            );
                        }
                    } else {
                        k4: int = b4 & 63;
                        if k4 == 0 {
                            __mem_store_i64(d, a);
                        } else {
                            __mem_store_i64(
                                d, _shr_u64(a, k4) | wrapping_shl(a, 64 - k4)
                            );
                        }
                    }
                }
            } elif op <= 166 {
                # f32 (139..152) and f64 (153..166) arithmetic
                is32: bool = op <= 152;
                oo2: int = op;
                if not is32 {
                    oo2 = op - 14;
                }
                x2: float = __bits_float(a);
                res: float = 0.0;
                if oo2 <= 145 {
                    pc = pc + 24;
                    if oo2 == 139 {
                        __mem_store_i64(d, a & 9223372036854775807);
                        continue;
                    } elif oo2 == 140 {
                        __mem_store_i64(d, a ^ SIGN64);
                        continue;
                    } elif oo2 == 141 {
                        res = ceil(x2);
                    } elif oo2 == 142 {
                        res = floor(x2);
                    } elif oo2 == 143 {
                        res = trunc(x2);
                    } elif oo2 == 144 {
                        res = nearbyint(x2);
                    } else {
                        res = sqrt(x2);
                    }
                    if res != res {
                        __mem_store_i64(d, __float_bits(res) | F64_QUIET);
                        continue;
                    }
                } else {
                    bb: int = __mem_load_i64(fp + __mem_load_i64(pc + 24));
                    pc = pc + 32;
                    y2: float = __bits_float(bb);
                    if oo2 == 146 {
                        res = x2 + y2;
                    } elif oo2 == 147 {
                        res = x2 - y2;
                    } elif oo2 == 148 {
                        res = x2 * y2;
                    } elif oo2 == 149 {
                        res = _fdiv(x2, y2);
                    } elif oo2 == 150 {
                        res = _fmin(x2, y2);
                    } elif oo2 == 151 {
                        res = _fmax(x2, y2);
                    } else {
                        __mem_store_i64(d, (a & 9223372036854775807) | (bb & SIGN64));
                        continue;
                    }
                }
                if is32 {
                    res = _f32r(res);
                }
                __mem_store_i64(d, __float_bits(res));
            } else {
                # conversions 167..196
                pc = pc + 24;
                _TRUNC_ERR = "";
                cv: int = 0;
                xf: float = __bits_float(a);
                if op == 167 {
                    cv = int(i32.wrap(a));
                } elif op == 168 or op == 170 {
                    cv = _trunc_s(xf, -2147483648.0, 2147483648.0);
                } elif op == 169 or op == 171 {
                    cv = int(i32.wrap(_trunc_s(xf, 0.0, 4294967296.0)));
                } elif op == 172 {
                    cv = a;
                } elif op == 173 {
                    cv = a & M32;
                } elif op == 174 or op == 176 {
                    cv = _trunc_s(xf, -9223372036854775808.0, 9223372036854775808.0);
                } elif op == 175 or op == 177 {
                    cv = _trunc_u64(xf);
                } elif op == 178 {
                    cv = __float_bits(_f32r(float(a)));
                } elif op == 179 {
                    cv = __float_bits(_f32r(float(a & M32)));
                } elif op == 180 {
                    cv = __float_bits(_i64_to_f32(a));
                } elif op == 181 {
                    cv = __float_bits(_u64_to_f32(a));
                } elif op == 182 {
                    cv = __float_bits(_f32r(xf));
                    if xf != xf {
                        cv = cv | F64_QUIET;
                    }
                } elif op == 183 {
                    cv = __float_bits(float(a));
                } elif op == 184 {
                    cv = __float_bits(float(a & M32));
                } elif op == 185 {
                    cv = __float_bits(float(a));
                } elif op == 186 {
                    cv = __float_bits(_u64_to_f64(a));
                } elif op == 187 {
                    cv = a;
                    if xf != xf {
                        cv = cv | F64_QUIET;
                    }
                } elif op == 188 {
                    cv = int(i32.wrap(f64_to_f32_bits(xf)));
                } elif op == 189 {
                    cv = a;
                } elif op == 190 {
                    cv = __float_bits(f32_bits_to_f64(a & M32));
                } elif op == 191 {
                    cv = a;
                } elif op == 192 {
                    cv = int(i8.wrap(a));
                } elif op == 193 {
                    cv = int(i16.wrap(a));
                } elif op == 194 {
                    cv = int(i8.wrap(a));
                } elif op == 195 {
                    cv = int(i16.wrap(a));
                } else {
                    cv = int(i32.wrap(a));
                }
                if _TRUNC_ERR != "" {
                    return _trap(_TRUNC_ERR);
                }
                __mem_store_i64(d, cv);
            }
        } elif op == 7 or op == 8 {  # CALL fidx argoff | CALL_INDIRECT t type argoff elem
            callee: int = 0;
            argoff: int = 0;
            if op == 7 {
                callee = __mem_load_i64(funcs + __mem_load_i64(pc + 8) * 8);
                argoff = __mem_load_i64(pc + 16);
                pc = pc + 24;
            } else {
                tab: int = __mem_load_i64(
                    __mem_load_i64(inst + 24) + __mem_load_i64(pc + 8) * 8
                );
                want: int = __mem_load_i64(
                    __mem_load_i64(inst + 48) + __mem_load_i64(pc + 16) * 8
                );
                argoff = __mem_load_i64(pc + 24);
                ei: int = __mem_load_i64(fp + __mem_load_i64(pc + 32)) & M32;
                pc = pc + 40;
                if ei >= __mem_load_i64(tab + 8) {
                    return _trap("undefined element");
                }
                callee = __mem_load_i64(__mem_load_i64(tab) + ei * 8);
                if callee == 0 {
                    return _trap("uninitialized element");
                }
                if __mem_load_i64(callee + 48) != want {
                    return _trap("indirect call type mismatch");
                }
            }
            nfp: int = fp + argoff;
            ccode: int = __mem_load_i64(callee);
            if ccode == 0 {
                # host function
                saved_top: int = _VS_TOP;
                saved_fs: int = _FS_TOP;
                _VS_TOP = nfp + __mem_load_i64(callee + 24) * 8;
                _FS_TOP = depth;
                if _VS_TOP > _VS_END {
                    return _trap("call stack exhausted");
                }
                hcb: Callable[[int, int, int], int] = _HOST[0];
                hrc: int = hcb(__mem_load_i64(callee + 56), nfp, callee);
                _VS_TOP = saved_top;
                _FS_TOP = saved_fs;
                if hrc != 0 {
                    return 1;
                }
                if mem != 0 {
                    mb = __mem_load_i64(mem);
                    ms = __mem_load_i64(mem + 8);
                }
                continue;
            }
            if nfp + __mem_load_i64(callee + 24) * 8 > _VS_END or depth >= FS_FRAMES {
                return _trap("call stack exhausted");
            }
            fr: int = _FS + depth * 24;
            __mem_store_i64(fr, pc);
            __mem_store_i64(fr + 8, fp);
            __mem_store_i64(fr + 16, f);
            depth = depth + 1;
            f = callee;
            fp = nfp;
            pc = ccode;
            z2: int = __mem_load_i64(f + 8);
            nl2: int = __mem_load_i64(f + 16);
            while z2 < nl2 {
                __mem_store_i64(fp + z2 * 8, 0);
                z2 = z2 + 1;
            }
            ninst: int = __mem_load_i64(f + 40);
            if ninst != inst {
                inst = ninst;
                funcs = __mem_load_i64(inst);
                mem = __mem_load_i64(inst + 8);
            }
            if mem != 0 {
                mb = __mem_load_i64(mem);
                ms = __mem_load_i64(mem + 8);
            }
        } elif op == 6 {  # RET src n
            src: int = __mem_load_i64(pc + 8);
            n: int = __mem_load_i64(pc + 16);
            if src != 0 {
                i: int = 0;
                while i < n {
                    __mem_store_i64(fp + i * 8, __mem_load_i64(fp + src + i * 8));
                    i = i + 1;
                }
            }
            if depth == base_depth {
                return 0;
            }
            depth = depth - 1;
            fr2: int = _FS + depth * 24;
            pc = __mem_load_i64(fr2);
            fp = __mem_load_i64(fr2 + 8);
            f = __mem_load_i64(fr2 + 16);
            pinst: int = __mem_load_i64(f + 40);
            if pinst != inst {
                inst = pinst;
                funcs = __mem_load_i64(inst);
                mem = __mem_load_i64(inst + 8);
            }
            if mem != 0 {
                mb = __mem_load_i64(mem);
                ms = __mem_load_i64(mem + 8);
            }
        } elif op == 5 {  # BR_TABLE i n tgt*
            idx: int = __mem_load_i64(fp + __mem_load_i64(pc + 8)) & M32;
            cnt: int = __mem_load_i64(pc + 16);
            if idx > cnt {
                idx = cnt;
            }
            pc = __mem_load_i64(pc + 24 + idx * 8);
        } elif op == 11 {  # SELECT dst a b c
            if __mem_load_i64(fp + __mem_load_i64(pc + 32)) != 0 {
                __mem_store_i64(
                    fp + __mem_load_i64(pc + 8),
                    __mem_load_i64(fp + __mem_load_i64(pc + 16))
                );
            } else {
                __mem_store_i64(
                    fp + __mem_load_i64(pc + 8),
                    __mem_load_i64(fp + __mem_load_i64(pc + 24))
                );
            }
            pc = pc + 40;
        } elif op == 12 {  # GLOBAL_GET dst g
            cell: int = __mem_load_i64(
                __mem_load_i64(inst + 16) + __mem_load_i64(pc + 16) * 8
            );
            __mem_store_i64(fp + __mem_load_i64(pc + 8), __mem_load_i64(cell));
            pc = pc + 24;
        } elif op == 13 {  # GLOBAL_SET g src
            cell2: int = __mem_load_i64(
                __mem_load_i64(inst + 16) + __mem_load_i64(pc + 8) * 8
            );
            __mem_store_i64(cell2, __mem_load_i64(fp + __mem_load_i64(pc + 16)));
            pc = pc + 24;
        } elif op == 0 {
            return _trap("unreachable");
        } elif op == 18 {  # MEM_SIZE
            __mem_store_i64(fp + __mem_load_i64(pc + 8), __mem_load_i64(mem + 24));
            pc = pc + 16;
        } elif op == 19 {  # MEM_GROW
            gd: int = fp + __mem_load_i64(pc + 8);
            pc = pc + 16;
            # A successful grow calls JavaScript to detach stale ArrayBuffers. That callback
            # can invoke another Wasm export, so reserve the active interpreter frame
            # and return-frame stack before crossing the VM boundary.
            saved_vs_top: int = _VS_TOP;
            saved_fs_top: int = _FS_TOP;
            frame_top: int = fp + __mem_load_i64(f + 24) * 8;
            if frame_top > _VS_TOP {
                _VS_TOP = frame_top;
            }
            if depth > _FS_TOP {
                _FS_TOP = depth;
            }
            old: int = mem_grow(mem, __mem_load_i64(gd) & M32);
            _VS_TOP = saved_vs_top;
            _FS_TOP = saved_fs_top;
            __mem_store_i64(gd, old);
            mb = __mem_load_i64(mem);
            ms = __mem_load_i64(mem + 8);
        } elif op == 14 {  # TABLE_GET dst t i
            tg: int = __mem_load_i64(
                __mem_load_i64(inst + 24) + __mem_load_i64(pc + 16) * 8
            );
            ti: int = __mem_load_i64(fp + __mem_load_i64(pc + 24)) & M32;
            if ti >= __mem_load_i64(tg + 8) {
                return _trap("out of bounds table access");
            }
            __mem_store_i64(
                fp + __mem_load_i64(pc + 8), __mem_load_i64(__mem_load_i64(tg) + ti * 8)
            );
            pc = pc + 32;
        } elif op == 15 {  # TABLE_SET t i v
            ts: int = __mem_load_i64(
                __mem_load_i64(inst + 24) + __mem_load_i64(pc + 8) * 8
            );
            tsi: int = __mem_load_i64(fp + __mem_load_i64(pc + 16)) & M32;
            if tsi >= __mem_load_i64(ts + 8) {
                return _trap("out of bounds table access");
            }
            __mem_store_i64(
                __mem_load_i64(ts) + tsi * 8,
                __mem_load_i64(fp + __mem_load_i64(pc + 24))
            );
            pc = pc + 32;
        } elif op == 16 {  # REF_IS_NULL
            __mem_store_i64(
                fp + __mem_load_i64(pc + 8),
                1 if __mem_load_i64(fp + __mem_load_i64(pc + 16)) == 0 else 0
            );
            pc = pc + 24;
        } elif op == 17 {  # REF_FUNC dst fidx
            __mem_store_i64(
                fp + __mem_load_i64(pc + 8),
                __mem_load_i64(funcs + __mem_load_i64(pc + 16) * 8)
            );
            pc = pc + 24;
        } elif op >= 224 {
            rc: int = _exec_fc(op - 224, pc, fp, inst, mem);
            if rc != 0 {
                return 1;
            }
            pc = pc + _fc_words(op - 224) * 8;
            if mem != 0 {
                mb = __mem_load_i64(mem);
                ms = __mem_load_i64(mem + 8);
            }
        } else {
            return _trap("bad opcode " + str(op));
        }
    }
    return 0;
}

def _fc_words(sub: int) -> int {
    if sub <= 7 {
        return 3;
    }
    if sub == 8 {
        return 5;
    }
    if sub == 9 or sub == 10 or sub == 11 or sub == 13 {
        return 2;
    }
    if sub == 12 or sub == 14 or sub == 15 {
        return 4;
    }
    return 3;
}

def _slot(fp: int, pc: int, k: int) -> int {
    return __mem_load_i64(fp + __mem_load_i64(pc + k * 8));
}

def _exec_fc(sub: int, pc: int, fp: int, inst: int, mem: int) -> int {
    if sub <= 7 {
        d: int = fp + __mem_load_i64(pc + 8);
        x: float = __bits_float(_slot(fp, pc, 2));
        v: int = 0;
        if sub == 0 or sub == 2 {
            v = _sat_s(x, -2147483649.0, 2147483648.0, -2147483648, 2147483647);
        } elif sub == 1 or sub == 3 {
            if x != x or x <= 0.0 {
                v = 0;
            } elif x >= 4294967296.0 {
                v = -1;
            } else {
                v = int(i32.wrap(int(trunc(x))));
            }
        } elif sub == 4 or sub == 6 {
            v = _sat_s(
                x,
                -9223372036854775808.0,
                9223372036854775808.0,
                SIGN64,
                9223372036854775807
            );
        } else {
            v = _sat_u64(x);
        }
        if sub == 0 or sub == 2 {
            # _sat_s bounds are exclusive; -2147483648.x truncates in range
            if x == x and x > -2147483649.0 and x < 2147483648.0 {
                v = int(trunc(x));
            }
        }
        if sub == 4 or sub == 6 {
            if x == x and x >= -9223372036854775808.0 and x < 9223372036854775808.0 {
                v = int(trunc(x));
            } elif x == x and x < -9223372036854775808.0 {
                v = SIGN64;
            }
        }
        __mem_store_i64(d, v);
        return 0;
    }
    if sub == 8 {  # memory.init seg base
        seg: int = __mem_load_i64(
            __mem_load_i64(inst + 40) + __mem_load_i64(pc + 8) * 8
        );
        base: int = __mem_load_i64(pc + 16);
        dd: int = __mem_load_i64(fp + base) & M32;
        ss: int = __mem_load_i64(fp + base + 8) & M32;
        nn: int = __mem_load_i64(fp + base + 16) & M32;
        if ss + nn > __mem_load_i64(seg + 8) or dd + nn > __mem_load_i64(mem + 8) {
            return _trap("out of bounds memory access");
        }
        memcpy(__mem_load_i64(mem) + dd, __mem_load_i64(seg) + ss, nn);
        return 0;
    }
    if sub == 9 {  # data.drop
        seg2: int = __mem_load_i64(
            __mem_load_i64(inst + 40) + __mem_load_i64(pc + 8) * 8
        );
        __mem_store_i64(seg2 + 8, 0);
        return 0;
    }
    if sub == 10 {  # memory.copy base
        b2: int = __mem_load_i64(pc + 8);
        d2: int = __mem_load_i64(fp + b2) & M32;
        s2: int = __mem_load_i64(fp + b2 + 8) & M32;
        n2: int = __mem_load_i64(fp + b2 + 16) & M32;
        msz: int = __mem_load_i64(mem + 8);
        if s2 + n2 > msz or d2 + n2 > msz {
            return _trap("out of bounds memory access");
        }
        memmove(__mem_load_i64(mem) + d2, __mem_load_i64(mem) + s2, n2);
        return 0;
    }
    if sub == 11 {  # memory.fill base
        b3: int = __mem_load_i64(pc + 8);
        d3: int = __mem_load_i64(fp + b3) & M32;
        v3: int = __mem_load_i64(fp + b3 + 8) & 255;
        n3: int = __mem_load_i64(fp + b3 + 16) & M32;
        if d3 + n3 > __mem_load_i64(mem + 8) {
            return _trap("out of bounds memory access");
        }
        memset(__mem_load_i64(mem) + d3, i32.wrap(v3), n3);
        return 0;
    }
    if sub == 12 {  # table.init seg t base
        seg3: int = __mem_load_i64(
            __mem_load_i64(inst + 32) + __mem_load_i64(pc + 8) * 8
        );
        t: int = __mem_load_i64(
            __mem_load_i64(inst + 24) + __mem_load_i64(pc + 16) * 8
        );
        b4: int = __mem_load_i64(pc + 24);
        d4: int = __mem_load_i64(fp + b4) & M32;
        s4: int = __mem_load_i64(fp + b4 + 8) & M32;
        n4: int = __mem_load_i64(fp + b4 + 16) & M32;
        if s4 + n4 > __mem_load_i64(seg3 + 8) or d4 + n4 > __mem_load_i64(t + 8) {
            return _trap("out of bounds table access");
        }
        memcpy(__mem_load_i64(t) + d4 * 8, __mem_load_i64(seg3) + s4 * 8, n4 * 8);
        return 0;
    }
    if sub == 13 {  # elem.drop
        seg4: int = __mem_load_i64(
            __mem_load_i64(inst + 32) + __mem_load_i64(pc + 8) * 8
        );
        __mem_store_i64(seg4 + 8, 0);
        return 0;
    }
    if sub == 14 {  # table.copy dt st base
        tdst: int = __mem_load_i64(
            __mem_load_i64(inst + 24) + __mem_load_i64(pc + 8) * 8
        );
        tsrc: int = __mem_load_i64(
            __mem_load_i64(inst + 24) + __mem_load_i64(pc + 16) * 8
        );
        b5: int = __mem_load_i64(pc + 24);
        d5: int = __mem_load_i64(fp + b5) & M32;
        s5: int = __mem_load_i64(fp + b5 + 8) & M32;
        n5: int = __mem_load_i64(fp + b5 + 16) & M32;
        if s5 + n5 > __mem_load_i64(tsrc + 8) or d5 + n5 > __mem_load_i64(tdst + 8) {
            return _trap("out of bounds table access");
        }
        memmove(__mem_load_i64(tdst) + d5 * 8, __mem_load_i64(tsrc) + s5 * 8, n5 * 8);
        return 0;
    }
    if sub == 15 {  # table.grow dst t base
        dg: int = fp + __mem_load_i64(pc + 8);
        tg: int = __mem_load_i64(
            __mem_load_i64(inst + 24) + __mem_load_i64(pc + 16) * 8
        );
        b6: int = __mem_load_i64(pc + 24);
        init: int = __mem_load_i64(fp + b6);
        n6: int = __mem_load_i64(fp + b6 + 8) & M32;
        __mem_store_i64(dg, int(i32.wrap(table_grow(tg, n6, init))));
        return 0;
    }
    if sub == 16 {  # table.size dst t
        tz: int = __mem_load_i64(
            __mem_load_i64(inst + 24) + __mem_load_i64(pc + 16) * 8
        );
        __mem_store_i64(fp + __mem_load_i64(pc + 8), __mem_load_i64(tz + 8));
        return 0;
    }
    # table.fill t base
    tf: int = __mem_load_i64(__mem_load_i64(inst + 24) + __mem_load_i64(pc + 8) * 8);
    b7: int = __mem_load_i64(pc + 16);
    i7: int = __mem_load_i64(fp + b7) & M32;
    v7: int = __mem_load_i64(fp + b7 + 8);
    n7: int = __mem_load_i64(fp + b7 + 16) & M32;
    if i7 + n7 > __mem_load_i64(tf + 8) {
        return _trap("out of bounds table access");
    }
    k: int = 0;
    while k < n7 {
        __mem_store_i64(__mem_load_i64(tf) + (i7 + k) * 8, v7);
        k = k + 1;
    }
    return 0;
}

# ── Memory growth notification ──────────────────────────────────────────────
# The embedder's growth observer: called with (MemRec, previous base ptr)
# right after a successful grow publishes the new backing store and before
# the old one is freed, so JS ArrayBuffers wrapping the old base can be
# detached first — both for Memory.prototype.grow and the wasm memory.grow
# opcode funnel through mem_grow.
glob _GROW_NOTIFY: list[Callable[[int, int], int]] = [];

"""Register the memory-growth observer (single slot, like the host handler).

The observer returns 0 once every JS view into the old base is detached
(or none exist); any other value keeps the old base alive (slot 4) until a
later successful grow releases it."""
def:pub set_grow_notify(cb: Callable[[int, int], int]) {
    if len(_GROW_NOTIFY) == 0 {
        _GROW_NOTIFY.append(cb);
    } else {
        _GROW_NOTIFY[0] = cb;
    }
}
