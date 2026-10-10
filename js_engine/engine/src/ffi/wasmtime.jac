"""Wasmtime C API FFI bindings for js_engine (Phase 0 — see docs/wasm.md).

Links the vendored Bytecode Alliance Wasmtime C API (lib/libwasmtime.so,
pinned v48.0.2) and exposes the *minimal* compile → instantiate → call-export
path needed to prove the link works. No JS `WebAssembly` surface yet; that
arrives in Phase 2.

The Wasmtime flat C API ("wasmtime_*", declared in lib/wasmtime/include/
wasmtime/*.h) is used in preference to the spec "wasm_*" API because it passes
plain pointers + out-params, which map cleanly onto jac int/Ptr FFI. The
struct-heavy spec API (wasm_val_vec_t, wasm_byte_vec_t by value) does not.

Native handles are opaque pointers held as ints. We stash them in bridge-side
tables (index 0 = sentinel) exactly like ffi/zlib.jac's z_stream table, so a
future dispatch layer can refer to modules/instances by small-int handle.

── C signatures replicated here (verified against the pinned headers) ──

  wasm_engine_t*      wasm_engine_new(void);
  void                wasm_engine_delete(wasm_engine_t*);
  wasmtime_store_t*   wasmtime_store_new(wasm_engine_t*, void* data, void* finalizer);
  wasmtime_context_t* wasmtime_store_context(wasmtime_store_t*);
  void                wasmtime_store_delete(wasmtime_store_t*);
  wasmtime_error_t*   wasmtime_module_new(wasm_engine_t*, const uint8_t* wasm,
                                          size_t wasm_len, wasmtime_module_t** ret);
  wasmtime_error_t*   wasmtime_module_validate(wasm_engine_t*, const uint8_t*, size_t);
                        // NULL error => valid; non-NULL => invalid (delete it)
  void                wasmtime_module_delete(wasmtime_module_t*);
  wasmtime_error_t*   wasmtime_instance_new(wasmtime_context_t*, const wasmtime_module_t*,
                                            const wasmtime_extern_t* imports, size_t nimports,
                                            wasmtime_instance_t* out, wasm_trap_t** trap);
  bool                wasmtime_instance_export_get(wasmtime_context_t*, const wasmtime_instance_t*,
                                                   const char* name, size_t name_len,
                                                   wasmtime_extern_t* item_out);
  wasmtime_error_t*   wasmtime_func_call(wasmtime_context_t*, const wasmtime_func_t* func,
                                         const wasmtime_val_t* args, size_t nargs,
                                         wasmtime_val_t* results, size_t nresults,
                                         wasm_trap_t** trap);
  void                wasmtime_error_message(const wasmtime_error_t*, wasm_name_t* out);
  void                wasmtime_error_delete(wasmtime_error_t*);
  void                wasm_trap_message(const wasm_trap_t*, wasm_message_t* out);
  void                wasm_trap_delete(wasm_trap_t*);
  void                wasm_byte_vec_delete(wasm_byte_vec_t*);

── Struct layouts (x86-64, confirmed with a C offsetof probe) ──

  wasmtime_val_t     : 32 bytes.  kind (u8) @0 ; union `of` @8 (i32/i64/f32/f64).
  wasmtime_extern_t  : 32 bytes.  kind (u8) @0 ; union `of` @8.
                       of.func is a wasmtime_func_t (store_id u64 @8, private @16).
  wasmtime_instance_t: 16 bytes.  store_id (u64) @0 ; private @8.
                       Passed by pointer to instance_new / export_get, so we
                       just hold a 16-byte scratch buffer.
  wasm_byte_vec_t    : 16 bytes.  size (size_t) @0 ; data (char*) @8.
                       Filled by *_message; free with wasm_byte_vec_delete.

Extern kinds: FUNC=0 GLOBAL=1 TABLE=2 MEMORY=3 SHAREDMEMORY=4 TAG=5.
Val kinds:    I32=0 I64=1 F32=2 F64=3 (v128/refs deferred).
"""

import from "lib/libwasmtime.so" {
    def:pub wasm_engine_new -> int;  def:pub wasm_engine_delete(engine: int) -> None;  def:
        pub wasmtime_store_new(engine: int, data: int, finalizer: int) -> int;  def:
        pub wasmtime_store_context(store: int) -> int;  def:pub wasmtime_store_delete(
        store: int
    ) -> None;  def:pub wasmtime_module_new(
        engine: int, wasm_ptr: int, wasm_len: int, ret_out: int
    ) -> int;
    # Returns a wasmtime_error_t* (0/NULL => valid; non-NULL => invalid).
    def:pub wasmtime_module_validate(
        engine: int, wasm_ptr: int, wasm_len: int
    ) -> int;  def:pub wasmtime_module_delete(module: int) -> None;  def:
        pub wasmtime_instance_new(
        ctx: int,
        module: int,
        imports: int,
        nimports: int,
        instance_out: int,
        trap_out: int
    ) -> int;  def:pub wasmtime_instance_export_get(
        ctx: int, instance: int, name: str, name_len: int, item_out: int
    ) -> bool;
    # bool wasmtime_instance_export_nth(ctx, inst, index, char** name, size_t* name_len,
    #                                   wasmtime_extern_t* item)  — enumerate exports
    def:pub wasmtime_instance_export_nth(
        ctx: int,
        instance: int,
        index: int,
        name_out: int,
        name_len_out: int,
        item_out: int
    ) -> bool;  def:pub wasmtime_func_call(
        ctx: int,
        func: int,
        args: int,
        nargs: int,
        results: int,
        nresults: int,
        trap_out: int
    ) -> int;  def:pub wasmtime_error_message(error: int, out_vec: int) -> None;  def:
        pub wasmtime_error_delete(error: int) -> None;  def:pub wasm_trap_message(
        trap: int, out_vec: int
    ) -> None;  def:pub wasm_trap_delete(trap: int) -> None;  def:
        pub wasm_byte_vec_delete(vec: int) -> None;
    # ── Linear-memory C API (Phase 1 — shared linear memory) ──────────────────
    # uint8_t*  wasmtime_memory_data(ctx, const wasmtime_memory_t* mem)
    def:pub wasmtime_memory_data(ctx: int, memory: int) -> int;
    # size_t    wasmtime_memory_data_size(const ctx, const wasmtime_memory_t*)
    def:pub wasmtime_memory_data_size(ctx: int, memory: int) -> int;
    # uint64_t  wasmtime_memory_size(const ctx, const wasmtime_memory_t*)  (pages)
    def:pub wasmtime_memory_size(ctx: int, memory: int) -> int;
    # wasmtime_error_t* wasmtime_memory_grow(ctx, const mem*, u64 delta, u64* prev)
    def:pub wasmtime_memory_grow(
        ctx: int, memory: int, delta: int, prev_out: int
    ) -> int;
    # wasmtime_error_t* wasmtime_memory_new(ctx, const wasm_memorytype_t*, wasmtime_memory_t* ret)
    def:pub wasmtime_memory_new(ctx: int, ty: int, ret_out: int) -> int;
    # wasmtime_error_t* wasmtime_memorytype_new(u64 min, bool max_present, u64 max,
    #                       bool is_64, bool shared, u8 page_size_log2, wasm_memorytype_t** ret)
    def:pub wasmtime_memorytype_new(
        min_pages: int,
        max_present: bool,
        max_pages: int,
        is_64: bool,
        shared: bool,
        page_size_log2: int,
        ret_out: int
    ) -> int;  def:pub wasm_memorytype_delete(ty: int) -> None;
    # ── Function type introspection (Phase 2 — general marshaller) ────────────
    # wasm_functype_t* wasmtime_func_type(const ctx, const wasmtime_func_t*)  (owned)
    def:pub wasmtime_func_type(ctx: int, func: int) -> int;
    # const wasm_valtype_vec_t* wasm_functype_params(const wasm_functype_t*)
    def:pub wasm_functype_params(functype: int) -> int;
    # const wasm_valtype_vec_t* wasm_functype_results(const wasm_functype_t*)
    def:pub wasm_functype_results(functype: int) -> int;  def:pub wasm_functype_delete(
        functype: int
    ) -> None;
    # wasm_valkind_t wasm_valtype_kind(const wasm_valtype_t*)  (u8: I32=0..F64=3)
    def:pub wasm_valtype_kind(valtype: int) -> int;
    # ── Module import/export introspection (Phase 2 — Module.imports/exports) ──
    # void wasmtime_module_imports(const wasmtime_module_t*, wasm_importtype_vec_t* out)
    def:pub wasmtime_module_imports(module: int, out_vec: int) -> None;  def:
        pub wasmtime_module_exports(module: int, out_vec: int) -> None;  def:
        pub wasm_importtype_vec_delete(vec: int) -> None;  def:
        pub wasm_exporttype_vec_delete(vec: int) -> None;
    # const wasm_name_t* wasm_importtype_module / _name (wasm_byte_vec_t*: size@0 data@8)
    def:pub wasm_importtype_module(it: int) -> int;  def:pub wasm_importtype_name(
        it: int
    ) -> int;  def:pub wasm_importtype_type(it: int) -> int;  def:
        pub wasm_exporttype_name(et: int) -> int;  def:pub wasm_exporttype_type(
        et: int
    ) -> int;
    # wasm_externkind_t wasm_externtype_kind(const wasm_externtype_t*) (FUNC=0..MEMORY=3)
    def:pub wasm_externtype_kind(et: int) -> int;
    # wasm_functype_t* wasm_externtype_as_functype(wasm_externtype_t*)  (borrowed view)
    def:pub wasm_externtype_as_functype(et: int) -> int;
    # ── Global read (Phase 2 — exported-global .value, e.g. es-module-lexer) ──
    # void wasmtime_global_get(ctx, const wasmtime_global_t*, wasmtime_val_t* out)
    def:pub wasmtime_global_get(ctx: int, global: int, val_out: int) -> None;
    # ── Phase 3: type construction (functype/globaltype/tabletype/valtype) ─────
    # own wasm_valtype_t* wasm_valtype_new(wasm_valkind_t)   (I32=0..F64=3, FUNCREF=129, EXTERNREF=128)
    def:pub wasm_valtype_new(kind: int) -> int;
    # void wasm_valtype_vec_new(own wasm_valtype_vec_t* out, size_t, own wasm_valtype_t* const[])
    def:pub wasm_valtype_vec_new(out_vec: int, size: int, data: int) -> None;  def:
        pub wasm_valtype_vec_new_empty(out_vec: int) -> None;
    # own wasm_functype_t* wasm_functype_new(own wasm_valtype_vec_t* params, own results)
    def:pub wasm_functype_new(params_vec: int, results_vec: int) -> int;
    # own wasm_globaltype_t* wasm_globaltype_new(own wasm_valtype_t*, wasm_mutability_t)  (CONST=0/VAR=1)
    def:pub wasm_globaltype_new(content: int, mutability: int) -> int;  def:
        pub wasm_globaltype_delete(gt: int) -> None;
    # own wasm_tabletype_t* wasm_tabletype_new(own wasm_valtype_t*, const wasm_limits_t*)
    def:pub wasm_tabletype_new(element: int, limits: int) -> int;  def:
        pub wasm_tabletype_delete(tt: int) -> None;
    # ── Phase 3: host functions (JS→WASM imported callbacks) ──────────────────
    # void wasmtime_func_new(ctx, const wasm_functype_t*, wasmtime_func_callback_t cb,
    #                        void* env, void (*finalizer)(void*), wasmtime_func_t* ret)
    def:pub wasmtime_func_new(
        ctx: int, functype: int, callback: int, env: int, finalizer: int, ret_out: int
    ) -> None;
    # ── Phase 3: global create + set ──────────────────────────────────────────
    # wasmtime_error_t* wasmtime_global_new(ctx, const wasm_globaltype_t*, const wasmtime_val_t*, wasmtime_global_t* ret)
    def:pub wasmtime_global_new(ctx: int, gt: int, val: int, ret_out: int) -> int;
    # wasmtime_error_t* wasmtime_global_set(ctx, const wasmtime_global_t*, const wasmtime_val_t*)
    def:pub wasmtime_global_set(ctx: int, global: int, val: int) -> int;
    # ── Phase 3: tables ───────────────────────────────────────────────────────
    # wasmtime_error_t* wasmtime_table_new(ctx, const wasm_tabletype_t*, const wasmtime_val_t* init, wasmtime_table_t* out)
    def:pub wasmtime_table_new(
        ctx: int, tt: int, init_val: int, table_out: int
    ) -> int;
    # bool wasmtime_table_get(ctx, const wasmtime_table_t*, uint64_t index, wasmtime_val_t* out)
    def:pub wasmtime_table_get(
        ctx: int, table: int, index: int, val_out: int
    ) -> bool;
    # wasmtime_error_t* wasmtime_table_set(ctx, const wasmtime_table_t*, uint64_t index, const wasmtime_val_t*)
    def:pub wasmtime_table_set(ctx: int, table: int, index: int, val: int) -> int;
    # uint64_t wasmtime_table_size(const ctx, const wasmtime_table_t*)
    def:pub wasmtime_table_size(ctx: int, table: int) -> int;
    # wasmtime_error_t* wasmtime_table_grow(ctx, const wasmtime_table_t*, uint64_t delta, const wasmtime_val_t* init, uint64_t* prev)
    def:pub wasmtime_table_grow(
        ctx: int, table: int, delta: int, init_val: int, prev_out: int
    ) -> int;
    # ── Phase 3: trap creation (throw a JS error back into WASM) ──────────────
    # wasm_trap_t* wasmtime_trap_new(const char* msg, size_t msg_len)
    def:pub wasmtime_trap_new(msg: str, msg_len: int) -> int;
    # ── Phase 3: global type introspection (mutability of exported globals) ───
    # wasm_globaltype_t* wasmtime_global_type(const ctx, const wasmtime_global_t*)  (owned)
    def:pub wasmtime_global_type(ctx: int, global: int) -> int;
    # wasm_mutability_t wasm_globaltype_mutability(const wasm_globaltype_t*)  (CONST=0/VAR=1)
    def:pub wasm_globaltype_mutability(gt: int) -> int;
}

import from engine.src.ffi.libc { calloc, free }
import from engine.src.runtime.mem {
    io_alloc,
    io_free,
    str_from_raw,
    read_byte,
    read_u32,
    read_u64,
    read_i32,
    write_byte,
    write_i32,
    write_i64
}
import from engine.src.runtime.jsstring { str_substr, str_char_at }
import from engine.src.runtime.jsvalue { jsv_double_bits, jsv_double_from_bits }

# ── Constants ────────────────────────────────────────────────────────────────

glob:pub WASMTIME_I32: int = 0,
     WASMTIME_I64: int = 1,
     WASMTIME_F32: int = 2,
     WASMTIME_F64: int = 3,
     WASMTIME_EXTERN_FUNC: int = 0,
     WASMTIME_EXTERN_GLOBAL: int = 1,
     WASMTIME_EXTERN_TABLE: int = 2,
     WASMTIME_EXTERN_MEMORY: int = 3,
     WASMTIME_FUNCREF: int = 5,
     WASMTIME_EXTERNREF: int = 6,
     WASM_VALKIND_EXTERNREF: int = 128,
     WASM_VALKIND_FUNCREF: int = 129,
     WASM_MUT_CONST: int = 0,
     WASM_MUT_VAR: int = 1;

# Reference val kinds (Phase 3 — funcref/externref for tables).

# wasm_valkind_t (the SPEC wasm_* API) reference kinds — DIFFERENT numbers from
# the flat wasmtime_valkind_t above: EXTERNREF=128, FUNCREF=129. These are what
# wasm_valtype_new expects when building a tabletype/globaltype element type.

# wasm_mutability_t.
# Struct sizes (bytes), confirmed via offsetof probe against the pinned headers.
glob:priv _SIZEOF_VAL: int = 32,
     _SIZEOF_EXTERN: int = 32,
     _SIZEOF_INSTANCE: int = 16,
     _SIZEOF_BYTE_VEC: int = 16,
     _OFF_KIND: int = 0,
     _OFF_OF: int = 8,
     _OFF_VEC_SIZE: int = 0,
     _OFF_VEC_DATA: int = 8,
     _WASM_ENGINE: int = 0,
     _WASM_STORES: list[int] = [0],
     _WASM_CTXS: list[int] = [0],
     _WASM_MODULES: list[int] = [0],
     _WASM_LAST_ERR: str = "",
     _WASM_MEMS: list[int] = [0],
     _WASM_MEM_STORES: list[int] = [0],
     _SIZEOF_MEMORY: int = 24;  # wasmtime_val_t

# wasmtime_extern_t
# wasmtime_instance_t
# wasm_byte_vec_t (size_t + char*)

# Field offsets within a wasmtime_val_t / wasmtime_extern_t.
# discriminant (u8)
# union payload

# wasm_byte_vec_t field offsets.
# size_t
# char*

# ── Bridge-side handle tables (index 0 = sentinel, never valid) ──────────────

# single shared engine (lazy-created)
# store handles
# context ptr per store slot (parallel)
# module handles

# Memory handle table (Phase 1). Each slot holds a pointer to an io_alloc'd
# 16-byte wasmtime_memory_t (store_id u64 @0, private @8). The struct is a
# store-index handle, NOT the linear-memory pointer — the actual byte buffer is
# fetched live via wasmtime_memory_data() each time (it can move on grow). We
# also record the owning store handle in parallel so callers pass just the
# memory handle. Index 0 = sentinel.
# ptr to 24-byte wasmtime_memory_t
# owning store handle (parallel)

# wasmtime_memory_t is 24 bytes: { u64 store_id; u32 __private1; u32 __private2 }
# in an anonymous struct, padded to 24 (NOT 16 — the anon-struct member forces
# 8-byte tail padding). Confirmed via `sizeof` probe against the pinned headers.
# Undersizing this (16) makes wasmtime_memory_new overflow the buffer by 8 bytes
# and corrupt the heap, surfacing as a free() abort at wasmtime_store_delete;
# and truncates the 24→16 extern-extraction copy so wasmtime_memory_data gets a
# bogus memory index (panic: index < num_defined_memories). Tables and globals
# are likewise 24 bytes; funcs and instances are 16.
# wasmtime_memory_t (24, not 16!)
# ── Public helpers ───────────────────────────────────────────────────────────

"""Return the last error string recorded by a wasm_* helper ("" if none)."""
def:pub wasm_last_error -> str {
    return _WASM_LAST_ERR;
}

"""Lazily create (or return) the shared Wasmtime engine handle.
Returns 0 on allocation failure."""
def:pub wasm_engine -> int {
    if _WASM_ENGINE == 0 {
        _WASM_ENGINE = wasm_engine_new();
    }
    return _WASM_ENGINE;
}

"""Create a fresh store bound to the shared engine. Returns a store handle
(>= 1) whose context is tracked in parallel, or 0 on failure."""
def:pub wasm_store_open -> int {
    eng: int = wasm_engine();
    if eng == 0 {
        _WASM_LAST_ERR = "engine alloc failed";
        return 0;
    }
    st: int = wasmtime_store_new(eng, 0, 0);
    if st == 0 {
        _WASM_LAST_ERR = "store alloc failed";
        return 0;
    }
    ctx: int = wasmtime_store_context(st);
    _WASM_STORES.append(st);
    _WASM_CTXS.append(ctx);
    return len(_WASM_STORES) - 1;
}

"""Return the wasmtime_context_t* for an open store handle, or 0 if invalid."""
def:pub wasm_store_context(store_handle: int) -> int {
    if store_handle < 1 or store_handle >= len(_WASM_CTXS) {
        return 0;
    }
    return _WASM_CTXS[store_handle];
}

"""Compile a WASM binary (raw byte pointer + length) into a module.
Returns a module handle (>= 1) on success, or 0 on compile error
(message retrievable via wasm_last_error())."""
def:pub wasm_module_compile(wasm_ptr: int, wasm_len: int) -> int {
    eng: int = wasm_engine();
    if eng == 0 {
        _WASM_LAST_ERR = "engine alloc failed";
        return 0;
    }

    # wasmtime_module_t** ret — one pointer slot.
    ret_out: int = io_alloc(8);
    err: int = wasmtime_module_new(eng, wasm_ptr, wasm_len, ret_out);
    if err != 0 {
        _set_err(_consume_error_message(err), WASM_ERRCLASS_COMPILE);
        io_free(ret_out);
        return 0;
    }
    module: int = read_u64(ret_out, 0);
    io_free(ret_out);
    if module == 0 {
        _set_err("module_new returned null", WASM_ERRCLASS_COMPILE);
        return 0;
    }

    _WASM_MODULES.append(module);
    return len(_WASM_MODULES) - 1;
}

"""Validate a WASM binary without compiling it. Returns True if valid.
wasmtime_module_validate returns a wasmtime_error_t* — NULL means valid; a
non-NULL error carries the reason (recorded in wasm_last_error()) and must be
deleted."""
def:pub wasm_module_valid(wasm_ptr: int, wasm_len: int) -> bool {
    eng: int = wasm_engine();
    if eng == 0 {
        return False;
    }
    err: int = wasmtime_module_validate(eng, wasm_ptr, wasm_len);
    if err == 0 {
        return True;
    }
    _set_err(_consume_error_message(err), WASM_ERRCLASS_COMPILE);
    return False;
}

"""Instantiate a compiled module (module handle) in a store (store handle)
with no imports. Returns an instance-scratch pointer (16-byte
wasmtime_instance_t, io_alloc'd — caller keeps it alive for export/call), or
0 on link error / trap. On failure wasm_last_error() holds the reason."""
def:pub wasm_instance_new(store_handle: int, module_handle: int) -> int {
    ctx: int = wasm_store_context(store_handle);
    if ctx == 0 {
        _WASM_LAST_ERR = "invalid store handle";
        return 0;
    }
    if module_handle < 1 or module_handle >= len(_WASM_MODULES) {
        _WASM_LAST_ERR = "invalid module handle";
        return 0;
    }
    module: int = _WASM_MODULES[module_handle];

    inst_out: int = io_alloc(_SIZEOF_INSTANCE);
    trap_out: int = io_alloc(8);
    err: int = wasmtime_instance_new(ctx, module, 0, 0, inst_out, trap_out);
    if err != 0 {
        _set_err(_consume_error_message(err), WASM_ERRCLASS_LINK);
        io_free(inst_out);
        io_free(trap_out);
        return 0;
    }
    trap: int = read_u64(trap_out, 0);
    io_free(trap_out);
    if trap != 0 {
        _set_err(_consume_trap_message(trap), WASM_ERRCLASS_RUNTIME);
        io_free(inst_out);
        return 0;
    }
    return inst_out;
}

"""Look up an exported function by name on an instance (instance-scratch
pointer from wasm_instance_new). Returns a pointer to a freshly-allocated
16-byte wasmtime_func_t (the export's func value, extracted from the
wasmtime_extern_t), or 0 if not found or not a function. Caller frees via
io_free when done (or reuses across calls)."""
def:pub wasm_export_func(store_handle: int, instance_ptr: int, name: str) -> int {
    ctx: int = wasm_store_context(store_handle);
    if ctx == 0 or instance_ptr == 0 {
        return 0;
    }

    item_out: int = io_alloc(_SIZEOF_EXTERN);
    found: bool = wasmtime_instance_export_get(
        ctx, instance_ptr, name, len(name), item_out
    );
    if not found {
        _WASM_LAST_ERR = "export not found: " + name;
        io_free(item_out);
        return 0;
    }
    kind: int = read_byte(item_out, _OFF_KIND);
    if kind != WASMTIME_EXTERN_FUNC {
        _WASM_LAST_ERR = "export is not a function: " + name;
        io_free(item_out);
        return 0;
    }
    # Copy the 16-byte wasmtime_func_t (the union payload at offset _OFF_OF)
    # into its own buffer so the caller owns a stable func pointer.
    func_ptr: int = io_alloc(16);
    write_i64(func_ptr, 0, read_u64(item_out, _OFF_OF + 0));
    write_i64(func_ptr, 8, read_u64(item_out, _OFF_OF + 8));
    io_free(item_out);
    return func_ptr;
}

# ── Module import/export introspection (Phase 2) ─────────────────────────────
# wasm_importtype_vec_t / wasm_exporttype_vec_t are 16 bytes: size @0, T** @8.
glob:priv _SIZEOF_TYPE_VEC: int = 16;

"""Owned Jac copy of `n` bytes at `ptr`, memory that Wasmtime owns.

Never cast such a pointer to `str` (`s: str = ptr`): a cast's refcount checks
read the 32 bytes before the pointer, which io_alloc zeroes but Wasmtime's
allocator does not, and when those bytes happened to pass the header check the
cast's release freed (or corrupted) memory Wasmtime owns — the intermittent
"double free or corruption" abort in test_wasm_esm_lexer under load. The bytes
go through an io_alloc buffer and str_from_raw (stops at a NUL, as the cast
did) instead."""
def:priv _wasm_foreign_str(ptr: int, n: int) -> str {
    if ptr == 0 or n <= 0 {
        return "";
    }
    wf_p: int = io_alloc(n + 1);
    wf_i: int = 0;
    while wf_i < n {
        write_byte(wf_p, wf_i, read_byte(ptr, wf_i));
        wf_i = wf_i + 1;
    }
    write_byte(wf_p, n, 0);
    wf_s: str = str_from_raw(wf_p);
    io_free(wf_p);
    return wf_s;
}

"""Copy a wasm_name_t* (wasm_byte_vec_t: size@0, char* data@8) into an owned
Jac str. The name is engine-owned and valid until the vec is deleted, so copy
now."""
def:priv _name_ptr_to_str(name_ptr: int) -> str {
    if name_ptr == 0 {
        return "";
    }
    size: int = read_u64(name_ptr, _OFF_VEC_SIZE);
    data: int = read_u64(name_ptr, _OFF_VEC_DATA);
    if data == 0 or size <= 0 {
        return "";
    }
    return _wasm_foreign_str(data, size);
}

# Cached module import/export records (filled by wasm_module_scan_*; read via
# the count/getter helpers immediately after). Parallel lists.
glob:priv _WASM_IMP_MODULES: list[str] = [],
     _WASM_IMP_NAMES: list[str] = [],
     _WASM_IMP_KINDS: list[int] = [],
     _WASM_IMP_PKINDS: list[list[int]] = [],
     _WASM_IMP_RKINDS: list[list[int]] = [],
     _WASM_EXP_NAMES: list[str] = [],
     _WASM_EXP_KINDS: list[int] = [];

# Per-import func signature cache (empty for non-func imports). Parallel to the
# import lists above; filled by wasm_module_scan_imports so wasm_imports_add_func
# can build the host functype without the JS side supplying the signature.
"""Scan a module handle's imports into the cache. Returns the import count
(or -1 if the module handle is invalid)."""
def:pub wasm_module_scan_imports(module_handle: int) -> int {
    if module_handle < 1 or module_handle >= len(_WASM_MODULES) {
        return 0 - 1;
    }
    module: int = _WASM_MODULES[module_handle];
    if module == 0 {
        return 0 - 1;
    }
    _WASM_IMP_MODULES = [];
    _WASM_IMP_NAMES = [];
    _WASM_IMP_KINDS = [];
    _WASM_IMP_PKINDS = [];
    _WASM_IMP_RKINDS = [];
    vec: int = io_alloc(_SIZEOF_TYPE_VEC);
    wasmtime_module_imports(module, vec);
    n: int = read_u64(vec, _OFF_VALTYPE_VEC_SIZE);
    data: int = read_u64(vec, _OFF_VALTYPE_VEC_DATA);
    i: int = 0;
    while i < n {
        it: int = read_u64(data, i * 8);
        et: int = wasm_importtype_type(it);
        # wasm_externtype_kind returns wasm_externkind_t (uint8_t); the C ABI
        # leaves the upper bits of the return register undefined, so mask to the
        # low byte (a dirty high-byte value made every kind mis-read as garbage).
        ekind: int = wasm_externtype_kind(et) & 0xFF;
        _WASM_IMP_MODULES.append(_name_ptr_to_str(wasm_importtype_module(it)));
        _WASM_IMP_NAMES.append(_name_ptr_to_str(wasm_importtype_name(it)));
        _WASM_IMP_KINDS.append(ekind);
        pk: list[int] = [];
        rk: list[int] = [];
        if ekind == WASMTIME_EXTERN_FUNC {
            ft: int = wasm_externtype_as_functype(et);  # borrowed view (do NOT delete)
            if ft != 0 {
                pv: int = wasm_functype_params(ft);
                rv: int = wasm_functype_results(ft);
                np: int = read_u64(pv, _OFF_VALTYPE_VEC_SIZE);
                nr: int = read_u64(rv, _OFF_VALTYPE_VEC_SIZE);
                j: int = 0;
                while j < np {
                    pk.append(_valtype_vec_kind(pv, j));
                    j = j + 1;
                }
                j = 0;
                while j < nr {
                    rk.append(_valtype_vec_kind(rv, j));
                    j = j + 1;
                }
            }
        }
        _WASM_IMP_PKINDS.append(pk);
        _WASM_IMP_RKINDS.append(rk);
        i = i + 1;
    }
    wasm_importtype_vec_delete(vec);
    io_free(vec);
    return n;
}

"""Cached func-import signature accessors (valid after wasm_module_scan_imports).
Return [] / empty for non-func imports."""
def:pub wasm_import_param_kinds(i: int) -> list[int] {
    if i < 0 or i >= len(_WASM_IMP_PKINDS) {
        return [];
    }
    return _WASM_IMP_PKINDS[i];
}

def:pub wasm_import_result_kinds(i: int) -> list[int] {
    if i < 0 or i >= len(_WASM_IMP_RKINDS) {
        return [];
    }
    return _WASM_IMP_RKINDS[i];
}

def:pub wasm_module_import_module(i: int) -> str {
    if i < 0 or i >= len(_WASM_IMP_MODULES) {
        return "";
    }
    return _WASM_IMP_MODULES[i];
}

def:pub wasm_module_import_name(i: int) -> str {
    if i < 0 or i >= len(_WASM_IMP_NAMES) {
        return "";
    }
    return _WASM_IMP_NAMES[i];
}

def:pub wasm_module_import_kind(i: int) -> int {
    if i < 0 or i >= len(_WASM_IMP_KINDS) {
        return 0 - 1;
    }
    return _WASM_IMP_KINDS[i];
}

"""Scan a module handle's exports into the cache. Returns the export count
(or -1 if invalid)."""
def:pub wasm_module_scan_exports(module_handle: int) -> int {
    if module_handle < 1 or module_handle >= len(_WASM_MODULES) {
        return 0 - 1;
    }
    module: int = _WASM_MODULES[module_handle];
    if module == 0 {
        return 0 - 1;
    }
    _WASM_EXP_NAMES = [];
    _WASM_EXP_KINDS = [];
    vec: int = io_alloc(_SIZEOF_TYPE_VEC);
    wasmtime_module_exports(module, vec);
    n: int = read_u64(vec, _OFF_VALTYPE_VEC_SIZE);
    data: int = read_u64(vec, _OFF_VALTYPE_VEC_DATA);
    i: int = 0;
    while i < n {
        et: int = read_u64(data, i * 8);
        _WASM_EXP_NAMES.append(_name_ptr_to_str(wasm_exporttype_name(et)));
        _WASM_EXP_KINDS.append(wasm_externtype_kind(wasm_exporttype_type(et)) & 0xFF);
        i = i + 1;
    }
    wasm_exporttype_vec_delete(vec);
    io_free(vec);
    return n;
}

def:pub wasm_module_export_name(i: int) -> str {
    if i < 0 or i >= len(_WASM_EXP_NAMES) {
        return "";
    }
    return _WASM_EXP_NAMES[i];
}

def:pub wasm_module_export_kind(i: int) -> int {
    if i < 0 or i >= len(_WASM_EXP_KINDS) {
        return 0 - 1;
    }
    return _WASM_EXP_KINDS[i];
}

# ── Instance handle table (Phase 2) ──────────────────────────────────────────
# The JS shim references instances by small-int handle (JS numbers hold these
# fine). Each slot records the owning store handle and the io_alloc'd 16-byte
# wasmtime_instance_t scratch pointer (parallel lists; index 0 = sentinel).
glob:priv _WASM_INSTS: list[int] = [0],
     _WASM_INST_STORES: list[int] = [0];  # instance-scratch ptr

# owning store handle (parallel)
"""Compile+instantiate a module handle in a fresh store, returning an instance
HANDLE (>= 1) suitable for the JS shim, or 0 on failure (wasm_last_error()).
This bundles store creation so the JS side only juggles module/instance ints."""
def:pub wasm_instantiate_handle(module_handle: int) -> int {
    store_h: int = wasm_store_open();
    if store_h == 0 {
        return 0;
    }
    inst_ptr: int = wasm_instance_new(store_h, module_handle);
    if inst_ptr == 0 {
        wasm_store_close(store_h);
        return 0;
    }
    _WASM_INSTS.append(inst_ptr);
    _WASM_INST_STORES.append(store_h);
    return len(_WASM_INSTS) - 1;
}

"""Owning store handle for an instance handle, or 0 if invalid."""
def:pub wasm_inst_store(inst_handle: int) -> int {
    if inst_handle < 1 or inst_handle >= len(_WASM_INST_STORES) {
        return 0;
    }
    return _WASM_INST_STORES[inst_handle];
}

"""Instance-scratch pointer for an instance handle, or 0 if invalid."""
def:pub wasm_inst_ptr(inst_handle: int) -> int {
    if inst_handle < 1 or inst_handle >= len(_WASM_INSTS) {
        return 0;
    }
    return _WASM_INSTS[inst_handle];
}

"""Number of exports on an instance handle. Counts by probing export_nth until
it returns false (Wasmtime has no direct count on the flat API)."""
def:pub wasm_inst_export_count(inst_handle: int) -> int {
    ctx: int = wasm_store_context(wasm_inst_store(inst_handle));
    inst: int = wasm_inst_ptr(inst_handle);
    if ctx == 0 or inst == 0 {
        return 0;
    }
    name_out: int = io_alloc(8);
    name_len_out: int = io_alloc(8);
    item_out: int = io_alloc(_SIZEOF_EXTERN);
    n: int = 0;
    more: bool = True;
    while more {
        found: bool = wasmtime_instance_export_nth(
            ctx, inst, n, name_out, name_len_out, item_out
        );
        if found {
            n = n + 1;
        } else {
            more = False;
        }
    }
    io_free(name_out);
    io_free(name_len_out);
    io_free(item_out);
    return n;
}

"""Name of the i-th export on an instance handle (or "" if out of range).
The name ptr returned by export_nth is store-owned and valid only until the
next context API call, so we copy it into an owned Jac str immediately."""
def:pub wasm_inst_export_name(inst_handle: int, index: int) -> str {
    ctx: int = wasm_store_context(wasm_inst_store(inst_handle));
    inst: int = wasm_inst_ptr(inst_handle);
    if ctx == 0 or inst == 0 {
        return "";
    }
    name_out: int = io_alloc(8);
    name_len_out: int = io_alloc(8);
    item_out: int = io_alloc(_SIZEOF_EXTERN);
    result: str = "";
    found: bool = wasmtime_instance_export_nth(
        ctx, inst, index, name_out, name_len_out, item_out
    );
    if found {
        name_ptr: int = read_u64(name_out, 0);
        name_len: int = read_u64(name_len_out, 0);
        if name_ptr != 0 and name_len > 0 {
            result = _wasm_foreign_str(name_ptr, name_len);
        }
    }
    io_free(name_out);
    io_free(name_len_out);
    io_free(item_out);
    return result;
}

"""Extern kind (FUNC=0/GLOBAL=1/TABLE=2/MEMORY=3) of the i-th export on an
instance handle, or -1 if out of range."""
def:pub wasm_inst_export_kind(inst_handle: int, index: int) -> int {
    ctx: int = wasm_store_context(wasm_inst_store(inst_handle));
    inst: int = wasm_inst_ptr(inst_handle);
    if ctx == 0 or inst == 0 {
        return 0 - 1;
    }
    name_out: int = io_alloc(8);
    name_len_out: int = io_alloc(8);
    item_out: int = io_alloc(_SIZEOF_EXTERN);
    kind: int = 0 - 1;
    found: bool = wasmtime_instance_export_nth(
        ctx, inst, index, name_out, name_len_out, item_out
    );
    if found {
        kind = read_byte(item_out, _OFF_KIND);
    }
    io_free(name_out);
    io_free(name_len_out);
    io_free(item_out);
    return kind;
}

"""Look up an exported function on an instance HANDLE by name and return an
owned wasmtime_func_t ptr (0 if missing / not a function). Convenience wrapper
over wasm_export_func using the instance table."""
def:pub wasm_inst_export_func(inst_handle: int, name: str) -> int {
    return wasm_export_func(
        wasm_inst_store(inst_handle), wasm_inst_ptr(inst_handle), name
    );
}

"""Look up an exported memory on an instance HANDLE by name and return a memory
handle (0 if missing / not a memory)."""
def:pub wasm_inst_export_memory(inst_handle: int, name: str) -> int {
    return wasm_export_memory(
        wasm_inst_store(inst_handle), wasm_inst_ptr(inst_handle), name
    );
}

# ── Function handle table (Phase 2) ──────────────────────────────────────────
# The JS shim wraps each exported function as a callable that holds a small-int
# func handle. Each slot records the owned wasmtime_func_t ptr, the owning store
# handle, and the cached param/result kind lists (fetched once at bind time so
# repeated calls skip the functype round-trip). Index 0 = sentinel.
glob:priv _WASM_FUNCS: list[int] = [0],
     _WASM_FUNC_STORES: list[int] = [0],
     _WASM_FUNC_PKINDS: list[list[int]] = [[]],
     _WASM_FUNC_RKINDS: list[list[int]] = [[]];  # owned wasmtime_func_t ptr

# owning store handle
# cached param kinds
# cached result kinds
"""Bind an exported function on an instance handle by name: look it up, fetch
its signature once, and register a func handle (>= 1) for the JS shim to call
via wasm_func_invoke_*. Returns 0 on failure (missing / not a function)."""
def:pub wasm_bind_export_func(inst_handle: int, name: str) -> int {
    store_h: int = wasm_inst_store(inst_handle);
    fptr: int = wasm_export_func(store_h, wasm_inst_ptr(inst_handle), name);
    if fptr == 0 {
        return 0;
    }
    sig: list[int] = wasm_func_signature(store_h, fptr);
    if len(sig) < 2 or sig[0] < 0 {
        io_free(fptr);
        _WASM_LAST_ERR = "could not read function signature";
        return 0;
    }
    nparams: int = sig[0];
    nresults: int = sig[1];
    pk: list[int] = [];
    rk: list[int] = [];
    i: int = 0;
    while i < nparams {
        pk.append(sig[2 + i]);
        i = i + 1;
    }
    i = 0;
    while i < nresults {
        rk.append(sig[2 + nparams + i]);
        i = i + 1;
    }
    _WASM_FUNCS.append(fptr);
    _WASM_FUNC_STORES.append(store_h);
    _WASM_FUNC_PKINDS.append(pk);
    _WASM_FUNC_RKINDS.append(rk);
    return len(_WASM_FUNCS) - 1;
}

"""Param count for a func handle (so the JS shim knows how many args to marshal
and whether each is a float kind). Returns -1 if invalid."""
def:pub wasm_func_param_count(func_handle: int) -> int {
    if func_handle < 1 or func_handle >= len(_WASM_FUNC_PKINDS) {
        return 0 - 1;
    }
    return len(_WASM_FUNC_PKINDS[func_handle]);
}

"""Kind (I32=0/I64=1/F32=2/F64=3) of the i-th param of a func handle, or -1."""
def:pub wasm_func_param_kind(func_handle: int, i: int) -> int {
    if func_handle < 1 or func_handle >= len(_WASM_FUNC_PKINDS) {
        return 0 - 1;
    }
    pk: list[int] = _WASM_FUNC_PKINDS[func_handle];
    if i < 0 or i >= len(pk) {
        return 0 - 1;
    }
    return pk[i];
}

"""Invoke a func handle. arg_ints/arg_dbls are parallel per-param lists (the JS
shim fills the one matching each param's kind). Results land in the module
_WASM_CALL_RES_* globals (read via wasm_call_result_*). Returns True on success;
False on trap/error (wasm_last_error())."""
def:pub wasm_func_invoke(
    func_handle: int, arg_ints: list[int], arg_dbls: list[float]
) -> bool {
    if func_handle < 1 or func_handle >= len(_WASM_FUNCS) {
        _WASM_LAST_ERR = "invalid function handle";
        return False;
    }
    fptr: int = _WASM_FUNCS[func_handle];
    if fptr == 0 {
        _WASM_LAST_ERR = "freed function handle";
        return False;
    }
    return wasm_call_export(
        _WASM_FUNC_STORES[func_handle],
        fptr,
        _WASM_FUNC_PKINDS[func_handle],
        _WASM_FUNC_RKINDS[func_handle],
        arg_ints,
        arg_dbls
    );
}

# ── General function-call marshaller (Phase 2) ───────────────────────────────
# wasm_valkind_t offsets in a wasm_valtype_vec_t: size @0, data (ptr to array of
# wasm_valtype_t*) @8. Each element is an 8-byte pointer.
glob:priv _OFF_VALTYPE_VEC_SIZE: int = 0,
     _OFF_VALTYPE_VEC_DATA: int = 8;

"""Read the value-kind (I32=0/I64=1/F32=2/F64=3) of the i-th element of a
wasm_valtype_vec_t (size @0, wasm_valtype_t** data @8)."""
def:priv _valtype_vec_kind(vec: int, i: int) -> int {
    data: int = read_u64(vec, _OFF_VALTYPE_VEC_DATA);
    vt: int = read_u64(data, i * 8);
    # Mask the uint8_t return (upper return-register bits are undefined per ABI).
    return wasm_valtype_kind(vt) & 0xFF;
}

"""Number of params (idx 0) or results (idx 1) an exported function takes,
returned as [param_count, result_count] plus their kinds packed into a small
int list: [nparams, nresults, p0,p1,..., r0,r1,...]. Returns [-1] on failure.
The functype is owned; we read it then delete it."""
def:pub wasm_func_signature(store_handle: int, func_ptr: int) -> list[int] {
    fail: list[int] = [0 - 1];
    ctx: int = wasm_store_context(store_handle);
    if ctx == 0 or func_ptr == 0 {
        return fail;
    }
    ft: int = wasmtime_func_type(ctx, func_ptr);
    if ft == 0 {
        return fail;
    }
    params_vec: int = wasm_functype_params(ft);
    results_vec: int = wasm_functype_results(ft);
    nparams: int = read_u64(params_vec, _OFF_VALTYPE_VEC_SIZE);
    nresults: int = read_u64(results_vec, _OFF_VALTYPE_VEC_SIZE);
    out: list[int] = [nparams, nresults];
    i: int = 0;
    while i < nparams {
        out.append(_valtype_vec_kind(params_vec, i));
        i = i + 1;
    }
    i = 0;
    while i < nresults {
        out.append(_valtype_vec_kind(results_vec, i));
        i = i + 1;
    }
    wasm_functype_delete(ft);
    return out;
}

"""Call an exported function with arbitrary arity and value types (i32/i64/f32/
f64). `arg_ints` and `arg_dbls` are parallel lists: for integer kinds the value
is in arg_ints[i], for float kinds it is in arg_dbls[i] (the dispatch layer
decides which based on the signature it fetched via wasm_func_signature).
`param_kinds`/`result_kinds` are the kind lists from wasm_func_signature.

Returns a parallel pair of result lists via out-params is not possible in one
call, so we stash the results in module globals _WASM_CALL_RES_INT /
_WASM_CALL_RES_DBL / _WASM_CALL_RES_KIND (read immediately after). Returns True
on success; on trap/error records wasm_last_error() and returns False."""
glob:priv _WASM_CALL_RES_INT: list[int] = [];
glob:priv _WASM_CALL_RES_DBL: list[float] = [],
     _WASM_CALL_RES_KIND: list[int] = [];

def:pub wasm_call_result_count -> int {
    return len(_WASM_CALL_RES_KIND);
}
def:pub wasm_call_result_kind(i: int) -> int {
    if i < 0 or i >= len(_WASM_CALL_RES_KIND) {
        return 0 - 1;
    }
    return _WASM_CALL_RES_KIND[i];
}

def:pub wasm_call_result_int(i: int) -> int {
    if i < 0 or i >= len(_WASM_CALL_RES_INT) {
        return 0;
    }
    return _WASM_CALL_RES_INT[i];
}

def:pub wasm_call_result_dbl(i: int) -> float {
    if i < 0 or i >= len(_WASM_CALL_RES_DBL) {
        return 0.0;
    }
    return _WASM_CALL_RES_DBL[i];
}

"""Write one wasmtime_val_t at slot `i` of the args buffer from kind + value."""
def:priv _write_val(buf: int, i: int, kind: int, ival: int, dval: float) {
    base: int = i * _SIZEOF_VAL;
    write_byte(buf, base + _OFF_KIND, kind);
    if kind == WASMTIME_I32 {
        write_i32(buf, base + _OFF_OF, ival);
    } elif kind == WASMTIME_I64 {
        write_i64(buf, base + _OFF_OF, ival);
    } elif kind == WASMTIME_F32 {
        # wasmtime_val_t stores f32 as a 32-bit float at _OFF_OF; store the
        # truncated bit pattern of the double.
        write_i32(buf, base + _OFF_OF, _f32_bits(dval));
    } else {
        # F64 (and any unknown → treat as f64)
        write_i64(buf, base + _OFF_OF, jsv_double_bits(dval));
    }
}

"""Read one wasmtime_val_t at slot `i` of the results buffer into the module
result globals, using its own kind byte."""
def:priv _read_val_into_results(buf: int, i: int) {
    base: int = i * _SIZEOF_VAL;
    kind: int = read_byte(buf, base + _OFF_KIND);
    _WASM_CALL_RES_KIND.append(kind);
    if kind == WASMTIME_I32 {
        _WASM_CALL_RES_INT.append(read_i32(buf, base + _OFF_OF));
        _WASM_CALL_RES_DBL.append(0.0);
    } elif kind == WASMTIME_I64 {
        _WASM_CALL_RES_INT.append(read_u64(buf, base + _OFF_OF));
        _WASM_CALL_RES_DBL.append(0.0);
    } elif kind == WASMTIME_F32 {
        _WASM_CALL_RES_INT.append(0);
        _WASM_CALL_RES_DBL.append(_f32_from_bits(read_u32(buf, base + _OFF_OF)));
    } else {
        _WASM_CALL_RES_INT.append(0);
        _WASM_CALL_RES_DBL.append(jsv_double_from_bits(read_u64(buf, base + _OFF_OF)));
    }
}

"""Truncate a float64 to float32 and return its 32-bit IEEE-754 bit pattern.
Uses a round-trip through wasmtime_val_t-adjacent memory is unnecessary — we
approximate via the double bit pattern's exponent/mantissa. For Phase 2 the
common workloads (es-module-lexer, add) are i32-only, so f32 fidelity is best-
effort: we down-convert by storing the double and reading a single-precision
view through a scratch buffer using memcpy-free typed writes is not available,
so we compute f32 bits from the double bits directly (IEEE-754 narrowing)."""
def:priv _f32_bits(d: float) -> int {
    db: int = jsv_double_bits(d);
    sign: int = (db >> 63) & 0x1;
    exp: int = (db >> 52) & 0x7FF;
    man: int = db & 0xF_FFFF_FFFF_FFFF;
    if exp == 0 {
        return sign << 31;  # zero / subnormal-underflow → signed zero
    }
    if exp == 0x7FF {
        # inf / nan
        fexp: int = 0xFF;
        fman: int = 0;
        if man != 0 {
            fman = 1;
        }
        return (sign << 31) | (fexp << 23) | (fman << 22);
    }
    # Rebias exponent from 1023 to 127.
    e: int = exp - 1023 + 127;
    if e <= 0 {
        return sign << 31;
    }  # underflow to zero
    if e >= 0xFF {
        return (sign << 31) | (0xFF << 23);
    }  # overflow to inf
    fman2: int = man >> 29;  # 52-bit mantissa → 23-bit
    return (sign << 31) | (e << 23) | fman2;
}

"""Widen a 32-bit IEEE-754 bit pattern to a float64. Inverse of _f32_bits."""
def:priv _f32_from_bits(fb: int) -> float {
    sign: int = (fb >> 31) & 0x1;
    exp: int = (fb >> 23) & 0xFF;
    man: int = fb & 0x7F_FFFF;
    db: int = 0;
    if exp == 0 {
        db = sign << 63;  # zero (subnormals → zero)
    } elif exp == 0xFF {
        de: int = 0x7FF;
        dm: int = 0;
        if man != 0 {
            dm = 1 << 51;
        }
        db = (sign << 63) | (de << 52) | dm;
    } else {
        e: int = exp - 127 + 1023;
        db = (sign << 63) | (e << 52) | (man << 29);
    }
    return jsv_double_from_bits(db);
}

"""General export call. store_handle + instance ptr + name identify the func.
param_kinds/result_kinds come from wasm_func_signature. arg_ints/arg_dbls are
the marshalled argument values (parallel lists, one per param). Results land in
the module _WASM_CALL_RES_* globals (read via wasm_call_result_*). Returns True
on success; False on trap/error (message in wasm_last_error())."""
def:pub wasm_call_export(
    store_handle: int,
    func_ptr: int,
    param_kinds: list[int],
    result_kinds: list[int],
    arg_ints: list[int],
    arg_dbls: list[float]
) -> bool {
    ctx: int = wasm_store_context(store_handle);
    if ctx == 0 or func_ptr == 0 {
        _set_err("invalid call args", WASM_ERRCLASS_RUNTIME);
        return False;
    }

    # Clear stale error state so the JS shim's post-invoke trap probe (checks the
    # error class when a void func returns undefined) does not see a prior error.
    _set_err("", WASM_ERRCLASS_NONE);

    _WASM_CALL_RES_INT = [];
    _WASM_CALL_RES_DBL = [];
    _WASM_CALL_RES_KIND = [];

    nparams: int = len(param_kinds);
    nresults: int = len(result_kinds);

    args_buf: int = 0;
    if nparams > 0 {
        args_buf = io_alloc(_SIZEOF_VAL * nparams);
    }
    i: int = 0;
    while i < nparams {
        k: int = param_kinds[i];
        iv: int = 0;
        dv: float = 0.0;
        if i < len(arg_ints) {
            iv = arg_ints[i];
        }
        if i < len(arg_dbls) {
            dv = arg_dbls[i];
        }
        _write_val(args_buf, i, k, iv, dv);
        i = i + 1;
    }

    res_buf: int = 0;
    if nresults > 0 {
        res_buf = io_alloc(_SIZEOF_VAL * nresults);
    }
    trap_out: int = io_alloc(8);

    err: int = wasmtime_func_call(
        ctx, func_ptr, args_buf, nparams, res_buf, nresults, trap_out
    );
    if err != 0 {
        _set_err(_consume_error_message(err), WASM_ERRCLASS_RUNTIME);
        if args_buf != 0 {
            io_free(args_buf);
        }
        if res_buf != 0 {
            io_free(res_buf);
        }
        io_free(trap_out);
        return False;
    }
    trap: int = read_u64(trap_out, 0);
    io_free(trap_out);
    if trap != 0 {
        _set_err(_consume_trap_message(trap), WASM_ERRCLASS_RUNTIME);
        if args_buf != 0 {
            io_free(args_buf);
        }
        if res_buf != 0 {
            io_free(res_buf);
        }
        return False;
    }

    i = 0;
    while i < nresults {
        _read_val_into_results(res_buf, i);
        i = i + 1;
    }
    if args_buf != 0 {
        io_free(args_buf);
    }
    if res_buf != 0 {
        io_free(res_buf);
    }
    return True;
}

# ── Exported globals — read only (Phase 2 gate; full Global is Phase 3) ──────
# wasmtime_global_t is 24 bytes (like memory/table). We hold it in a handle
# table and read its current value via wasmtime_global_get. Mutation, standalone
# `new WebAssembly.Global`, and imported globals are Phase 3.
glob:priv _WASM_GLOBALS: list[int] = [0],
     _WASM_GLOBAL_STORES: list[int] = [0];  # ptr to 24-byte wasmtime_global_t

# owning store handle (parallel)
"""Extract an exported global by name from an instance handle and register it.
Returns a global handle (>= 1), or 0 if missing / not a global."""
def:pub wasm_export_global(inst_handle: int, name: str) -> int {
    store_h: int = wasm_inst_store(inst_handle);
    ctx: int = wasm_store_context(store_h);
    inst: int = wasm_inst_ptr(inst_handle);
    if ctx == 0 or inst == 0 {
        _WASM_LAST_ERR = "invalid store/instance";
        return 0;
    }

    item_out: int = io_alloc(_SIZEOF_EXTERN);
    found: bool = wasmtime_instance_export_get(ctx, inst, name, len(name), item_out);
    if not found {
        _WASM_LAST_ERR = "export not found: " + name;
        io_free(item_out);
        return 0;
    }
    kind: int = read_byte(item_out, _OFF_KIND);
    if kind != WASMTIME_EXTERN_GLOBAL {
        _WASM_LAST_ERR = "export is not a global: " + name;
        io_free(item_out);
        return 0;
    }
    # Copy the full 24-byte wasmtime_global_t out of the extern union (@_OFF_OF).
    gptr: int = io_alloc(_SIZEOF_MEMORY);  # 24 bytes, same size class
    write_i64(gptr, 0, read_u64(item_out, _OFF_OF + 0));
    write_i64(gptr, 8, read_u64(item_out, _OFF_OF + 8));
    write_i64(gptr, 16, read_u64(item_out, _OFF_OF + 16));
    io_free(item_out);
    # Record the declared mutability so the JS shim can enforce the mutable check
    # on an exported global's .value set (Phase 3). wasmtime_global_type is owned.
    mutable: bool = False;
    gt: int = wasmtime_global_type(ctx, gptr);
    if gt != 0 {
        if (wasm_globaltype_mutability(gt) & 0xFF) == WASM_MUT_VAR {
            mutable = True;
        }
        wasm_globaltype_delete(gt);
    }
    return _wasm_global_register(store_h, gptr, mutable);
}

"""Value kind (I32=0/I64=1/F32=2/F64=3) of an exported global's current value,
or -1 if the handle is invalid. Reads the live value each call."""
def:pub wasm_global_kind(global_handle: int) -> int {
    if global_handle < 1 or global_handle >= len(_WASM_GLOBALS) {
        return 0 - 1;
    }
    ctx: int = wasm_store_context(_WASM_GLOBAL_STORES[global_handle]);
    gptr: int = _WASM_GLOBALS[global_handle];
    if ctx == 0 or gptr == 0 {
        return 0 - 1;
    }
    val_out: int = io_alloc(_SIZEOF_VAL);
    wasmtime_global_get(ctx, gptr, val_out);
    k: int = read_byte(val_out, _OFF_KIND);
    io_free(val_out);
    return k;
}

"""Integer value of an exported global (valid for i32/i64 kinds). Reads live."""
def:pub wasm_global_get_int(global_handle: int) -> int {
    if global_handle < 1 or global_handle >= len(_WASM_GLOBALS) {
        return 0;
    }
    ctx: int = wasm_store_context(_WASM_GLOBAL_STORES[global_handle]);
    gptr: int = _WASM_GLOBALS[global_handle];
    if ctx == 0 or gptr == 0 {
        return 0;
    }
    val_out: int = io_alloc(_SIZEOF_VAL);
    wasmtime_global_get(ctx, gptr, val_out);
    k: int = read_byte(val_out, _OFF_KIND);
    out: int = 0;
    if k == WASMTIME_I32 {
        out = read_i32(val_out, _OFF_OF);
    } else {
        out = read_u64(val_out, _OFF_OF);
    }
    io_free(val_out);
    return out;
}

"""Float value of an exported global (valid for f32/f64 kinds). Reads live."""
def:pub wasm_global_get_dbl(global_handle: int) -> float {
    if global_handle < 1 or global_handle >= len(_WASM_GLOBALS) {
        return 0.0;
    }
    ctx: int = wasm_store_context(_WASM_GLOBAL_STORES[global_handle]);
    gptr: int = _WASM_GLOBALS[global_handle];
    if ctx == 0 or gptr == 0 {
        return 0.0;
    }
    val_out: int = io_alloc(_SIZEOF_VAL);
    wasmtime_global_get(ctx, gptr, val_out);
    out: float = jsv_double_from_bits(read_u64(val_out, _OFF_OF));
    io_free(val_out);
    return out;
}

# ── Linear memory (Phase 1 — shared linear memory) ───────────────────────────

"""Register a 16-byte wasmtime_memory_t (already io_alloc'd) owned by a store
handle into the memory table. Returns a memory handle (>= 1)."""
def:priv _wasm_mem_register(store_handle: int, mem_ptr: int) -> int {
    _WASM_MEMS.append(mem_ptr);
    _WASM_MEM_STORES.append(store_handle);
    return len(_WASM_MEMS) - 1;
}

"""Extract an exported memory by name from an instance and register it.
Returns a memory handle (>= 1), or 0 if the export is missing / not a memory.
Mirrors wasm_export_func but for WASMTIME_EXTERN_MEMORY (kind 3): copies the
16-byte wasmtime_memory_t from the extern union payload into its own buffer."""
def:pub wasm_export_memory(store_handle: int, instance_ptr: int, name: str) -> int {
    ctx: int = wasm_store_context(store_handle);
    if ctx == 0 or instance_ptr == 0 {
        _WASM_LAST_ERR = "invalid store/instance";
        return 0;
    }

    item_out: int = io_alloc(_SIZEOF_EXTERN);
    found: bool = wasmtime_instance_export_get(
        ctx, instance_ptr, name, len(name), item_out
    );
    if not found {
        _WASM_LAST_ERR = "export not found: " + name;
        io_free(item_out);
        return 0;
    }
    kind: int = read_byte(item_out, _OFF_KIND);
    if kind != WASMTIME_EXTERN_MEMORY {
        _WASM_LAST_ERR = "export is not a memory: " + name;
        io_free(item_out);
        return 0;
    }
    # Copy the full 24-byte wasmtime_memory_t out of the extern union (@_OFF_OF).
    # It is 24 bytes (store_id u64 + 2× u32 private, tail-padded); copying only 16
    # leaves __private2 zeroed → Wasmtime decodes a bogus memory index and panics.
    mem_ptr: int = io_alloc(_SIZEOF_MEMORY);
    write_i64(mem_ptr, 0, read_u64(item_out, _OFF_OF + 0));
    write_i64(mem_ptr, 8, read_u64(item_out, _OFF_OF + 8));
    write_i64(mem_ptr, 16, read_u64(item_out, _OFF_OF + 16));
    io_free(item_out);
    return _wasm_mem_register(store_handle, mem_ptr);
}

"""Create a fresh standalone linear memory in a store (for the JS
`WebAssembly.Memory({initial,maximum})` path — Phase 2, but usable now to test
round-trips without an instance). min/max are in WASM pages (64 KiB).
max_pages < 0 means "no maximum". Returns a memory handle (>= 1) or 0."""
def:pub wasm_memory_create(store_handle: int, min_pages: int, max_pages: int) -> int {
    ctx: int = wasm_store_context(store_handle);
    if ctx == 0 {
        _WASM_LAST_ERR = "invalid store handle";
        return 0;
    }

    ty_out: int = io_alloc(8);
    has_max: bool = max_pages >= 0;
    mx: int = max_pages;
    if not has_max {
        mx = 0;
    }
    # page_size_log2 = 16 → 64 KiB pages (the WASM MVP fixed page size, 2**16).
    # NOTE: 0 is NOT a "use default" sentinel here — it literally means a 1-byte
    # page (2**0), which yields a 1-byte "1 page" memory. Must pass 16.
    err: int = wasmtime_memorytype_new(
        min_pages, has_max, mx, False, False, 16, ty_out
    );
    if err != 0 {
        _WASM_LAST_ERR = _consume_error_message(err);
        io_free(ty_out);
        return 0;
    }
    ty: int = read_u64(ty_out, 0);
    io_free(ty_out);
    if ty == 0 {
        _WASM_LAST_ERR = "memorytype_new returned null";
        return 0;
    }

    mem_ptr: int = io_alloc(_SIZEOF_MEMORY);
    err2: int = wasmtime_memory_new(ctx, ty, mem_ptr);
    # wasmtime_memory_new borrows `ty` by const-ref (does not take ownership),
    # so we delete our memorytype regardless of success.
    wasm_memorytype_delete(ty);
    if err2 != 0 {
        _WASM_LAST_ERR = _consume_error_message(err2);
        io_free(mem_ptr);
        return 0;
    }
    return _wasm_mem_register(store_handle, mem_ptr);
}

"""Return the wasmtime_memory_t* (struct handle) for a memory handle, or 0."""
def:priv _wasm_mem_struct(mem_handle: int) -> int {
    if mem_handle < 1 or mem_handle >= len(_WASM_MEMS) {
        return 0;
    }
    return _WASM_MEMS[mem_handle];
}

"""Return the owning store's context ptr for a memory handle, or 0."""
def:priv _wasm_mem_ctx(mem_handle: int) -> int {
    if mem_handle < 1 or mem_handle >= len(_WASM_MEM_STORES) {
        return 0;
    }
    return wasm_store_context(_WASM_MEM_STORES[mem_handle]);
}

"""Live base pointer of a memory handle's linear memory. This is the address
JS/JAC read/write through — it is Wasmtime-owned and MUST NOT be freed by
js_engine. Re-fetch it after every grow (it can move). Returns 0 if invalid."""
def:pub wasm_memory_data_ptr(mem_handle: int) -> int {
    ctx: int = _wasm_mem_ctx(mem_handle);
    mem: int = _wasm_mem_struct(mem_handle);
    if ctx == 0 or mem == 0 {
        return 0;
    }
    return wasmtime_memory_data(ctx, mem);
}

"""Byte length of a memory handle's linear memory (pages * page_size)."""
def:pub wasm_memory_data_size(mem_handle: int) -> int {
    ctx: int = _wasm_mem_ctx(mem_handle);
    mem: int = _wasm_mem_struct(mem_handle);
    if ctx == 0 or mem == 0 {
        return 0;
    }
    return wasmtime_memory_data_size(ctx, mem);
}

"""Length in WASM pages (64 KiB) of a memory handle's linear memory."""
def:pub wasm_memory_size_pages(mem_handle: int) -> int {
    ctx: int = _wasm_mem_ctx(mem_handle);
    mem: int = _wasm_mem_struct(mem_handle);
    if ctx == 0 or mem == 0 {
        return 0;
    }
    return wasmtime_memory_size(ctx, mem);
}

"""Grow a memory handle by `delta` pages. Returns the previous size in pages on
success, or -1 on failure (message in wasm_last_error()). After a successful
grow the base ptr AND byte length can change — callers MUST re-read
wasm_memory_data_ptr / wasm_memory_data_size and re-wrap any external
ArrayBuffer view (detach the old one). Matches Node's detach-on-grow."""
def:pub wasm_memory_grow(mem_handle: int, delta: int) -> int {
    ctx: int = _wasm_mem_ctx(mem_handle);
    mem: int = _wasm_mem_struct(mem_handle);
    if ctx == 0 or mem == 0 {
        _WASM_LAST_ERR = "invalid memory handle";
        return 0 - 1;
    }
    prev_out: int = io_alloc(8);
    err: int = wasmtime_memory_grow(ctx, mem, delta, prev_out);
    if err != 0 {
        _WASM_LAST_ERR = _consume_error_message(err);
        io_free(prev_out);
        return 0 - 1;
    }
    prev: int = read_u64(prev_out, 0);
    io_free(prev_out);
    return prev;
}

"""Free a memory handle's struct buffer and clear its slot. Does NOT free the
Wasmtime linear memory itself — that is owned by the store/instance and is
released when the store is deleted. Safe on already-freed handles."""
def:pub wasm_memory_free(mem_handle: int) -> None {
    if mem_handle < 1 or mem_handle >= len(_WASM_MEMS) {
        return;
    }
    mem: int = _WASM_MEMS[mem_handle];
    if mem == 0 {
        return;
    }
    io_free(mem);  # frees the 16-byte struct handle, NOT the lin-mem
    _WASM_MEMS[mem_handle] = 0;
    _WASM_MEM_STORES[mem_handle] = 0;
}

"""Call an exported function that takes two i32 args and returns one i32.
This is the Phase-0 smoke shape only; the general marshaller lands in Phase 3.
Returns the i32 result. On error/trap, records wasm_last_error() and returns
the sentinel provided in `on_error`."""
def:pub wasm_call_i32_i32_i32(
    store_handle: int, func_ptr: int, a: int, b: int, on_error: int
) -> int {
    ctx: int = wasm_store_context(store_handle);
    if ctx == 0 or func_ptr == 0 {
        _WASM_LAST_ERR = "invalid call args";
        return on_error;
    }

    # args: wasmtime_val_t[2]
    args: int = io_alloc(_SIZEOF_VAL * 2);
    write_byte(args, 0 * _SIZEOF_VAL + _OFF_KIND, WASMTIME_I32);
    write_i32(args, 0 * _SIZEOF_VAL + _OFF_OF, a);
    write_byte(args, 1 * _SIZEOF_VAL + _OFF_KIND, WASMTIME_I32);
    write_i32(args, 1 * _SIZEOF_VAL + _OFF_OF, b);

    # results: wasmtime_val_t[1]
    results: int = io_alloc(_SIZEOF_VAL);
    trap_out: int = io_alloc(8);

    err: int = wasmtime_func_call(ctx, func_ptr, args, 2, results, 1, trap_out);
    if err != 0 {
        _WASM_LAST_ERR = _consume_error_message(err);
        io_free(args);
        io_free(results);
        io_free(trap_out);
        return on_error;
    }
    trap: int = read_u64(trap_out, 0);
    io_free(trap_out);
    if trap != 0 {
        _WASM_LAST_ERR = _consume_trap_message(trap);
        io_free(args);
        io_free(results);
        return on_error;
    }

    out: int = read_u32(results, _OFF_OF);
    io_free(args);
    io_free(results);
    return out;
}

"""Call an exported func taking two i32 args and returning nothing (the Phase-1
`store8(off,val)` shape — used to make WASM write into its own linear memory).
Returns True on success; on error/trap records wasm_last_error() and returns
False."""
def:pub wasm_call_i32_i32_void(
    store_handle: int, func_ptr: int, a: int, b: int
) -> bool {
    ctx: int = wasm_store_context(store_handle);
    if ctx == 0 or func_ptr == 0 {
        _WASM_LAST_ERR = "invalid call args";
        return False;
    }

    args: int = io_alloc(_SIZEOF_VAL * 2);
    write_byte(args, 0 * _SIZEOF_VAL + _OFF_KIND, WASMTIME_I32);
    write_i32(args, 0 * _SIZEOF_VAL + _OFF_OF, a);
    write_byte(args, 1 * _SIZEOF_VAL + _OFF_KIND, WASMTIME_I32);
    write_i32(args, 1 * _SIZEOF_VAL + _OFF_OF, b);
    trap_out: int = io_alloc(8);

    err: int = wasmtime_func_call(ctx, func_ptr, args, 2, 0, 0, trap_out);
    if err != 0 {
        _WASM_LAST_ERR = _consume_error_message(err);
        io_free(args);
        io_free(trap_out);
        return False;
    }
    trap: int = read_u64(trap_out, 0);
    io_free(trap_out);
    if trap != 0 {
        _WASM_LAST_ERR = _consume_trap_message(trap);
        io_free(args);
        return False;
    }
    io_free(args);
    return True;
}

"""Call an exported func taking one i32 arg and returning one i32 (the Phase-1
`load8(off)->val` shape — used to make WASM read its own linear memory).
Returns the i32 result, or `on_error` on error/trap."""
def:pub wasm_call_i32_i32(
    store_handle: int, func_ptr: int, a: int, on_error: int
) -> int {
    ctx: int = wasm_store_context(store_handle);
    if ctx == 0 or func_ptr == 0 {
        _WASM_LAST_ERR = "invalid call args";
        return on_error;
    }

    args: int = io_alloc(_SIZEOF_VAL);
    write_byte(args, _OFF_KIND, WASMTIME_I32);
    write_i32(args, _OFF_OF, a);
    results: int = io_alloc(_SIZEOF_VAL);
    trap_out: int = io_alloc(8);

    err: int = wasmtime_func_call(ctx, func_ptr, args, 1, results, 1, trap_out);
    if err != 0 {
        _WASM_LAST_ERR = _consume_error_message(err);
        io_free(args);
        io_free(results);
        io_free(trap_out);
        return on_error;
    }
    trap: int = read_u64(trap_out, 0);
    io_free(trap_out);
    if trap != 0 {
        _WASM_LAST_ERR = _consume_trap_message(trap);
        io_free(args);
        io_free(results);
        return on_error;
    }
    out: int = read_u32(results, _OFF_OF);
    io_free(args);
    io_free(results);
    return out;
}

# ══════════════════════════════════════════════════════════════════════════════
# Phase 3 — Imports (JS→WASM callbacks), Tables, Globals (create/set), Traps,
# i64↔BigInt marshalling.  See docs/wasm.md Phase 3.
# ══════════════════════════════════════════════════════════════════════════════

# Error classification — the JS shim maps compile/link/runtime errors to the
# distinct WebAssembly error classes. Set alongside _WASM_LAST_ERR by each
# helper that records an error. 0=none 1=compile 2=link 3=runtime(trap).
glob:pub WASM_ERRCLASS_NONE: int = 0,
     WASM_ERRCLASS_COMPILE: int = 1,
     WASM_ERRCLASS_LINK: int = 2,
     WASM_ERRCLASS_RUNTIME: int = 3;

glob:priv _WASM_LAST_ERRCLASS: int = 0;

"""Classification of the last recorded error (see WASM_ERRCLASS_*)."""
def:pub wasm_last_error_class -> int {
    return _WASM_LAST_ERRCLASS;
}

def:priv _set_err(msg: str, cls: int) {
    _WASM_LAST_ERR = msg;
    _WASM_LAST_ERRCLASS = cls;
}

"""Record the message of a JS error thrown inside a host import (read by the
trampoline to build the trap message). Classifies as runtime."""
def:pub wasm_set_host_throw(msg: str) {
    _set_err(msg, WASM_ERRCLASS_RUNTIME);
}

# ── i64 ↔ decimal string (BigInt bridge; parsed BigInt arrives as decimal) ────

"""Parse a signed decimal string into an i64 (Jac int is 64-bit). Best-effort:
ignores overflow beyond 64 bits (WASM i64 wraps mod 2^64 anyway). Empty/invalid
→ 0."""
def:pub wasm_i64_from_decimal(s: str) -> int {
    n: int = len(s);
    if n == 0 {
        return 0;
    }
    zero: int = int(str_char_at("0", 0));
    i: int = 0;
    neg: bool = False;
    c0: str = str_char_at(s, 0);
    if c0 == "-" {
        neg = True;
        i = 1;
    } elif c0 == "+" {
        i = 1;
    }
    acc: int = 0;
    while i < n {
        d: int = int(str_char_at(s, i)) - zero;
        if d < 0 or d > 9 {
            i = n;
        } else {
            acc = acc * 10 + d;
            i = i + 1;
        }
    }
    if neg {
        return 0 - acc;
    }
    return acc;
}

"""Render an i64 as a signed decimal string (for i64→BigInt on the JS side)."""
def:pub wasm_i64_to_decimal(v: int) -> str {
    return str(v);
}

# ── Standalone / mutable globals (create + set) ──────────────────────────────
# Extends the Phase-2 exported-global table with a parallel mutability flag so
# the shim can enforce the mutable check on .value set.
glob:priv _WASM_GLOBAL_MUT: list[bool] = [False];  # parallel to _WASM_GLOBALS

def:priv _wasm_global_register(store_h: int, gptr: int, mutable: bool) -> int {
    _WASM_GLOBALS.append(gptr);
    _WASM_GLOBAL_STORES.append(store_h);
    # Keep _WASM_GLOBAL_MUT parallel: it may have lagged behind if Phase-2
    # exported globals were registered before this list existed conceptually.
    while len(_WASM_GLOBAL_MUT) < len(_WASM_GLOBALS) - 1 {
        _WASM_GLOBAL_MUT.append(False);
    }
    _WASM_GLOBAL_MUT.append(mutable);
    return len(_WASM_GLOBALS) - 1;
}

"""True if a global handle is mutable (registered via create; exported globals
default to their declared mutability recorded at bind time)."""
def:pub wasm_global_is_mutable(global_handle: int) -> bool {
    if global_handle < 1 or global_handle >= len(_WASM_GLOBAL_MUT) {
        return False;
    }
    return _WASM_GLOBAL_MUT[global_handle];
}

"""Create a standalone WebAssembly.Global in a fresh store. `val_kind` is a flat
WASMTIME_* kind (I32/I64/F32/F64). Initial value in ival (int kinds) or dval
(float kinds). Returns a global handle (>=1) or 0."""
def:pub wasm_global_create(
    val_kind: int, mutable: bool, ival: int, dval: float
) -> int {
    store_h: int = wasm_store_open();
    if store_h == 0 {
        return 0;
    }
    ctx: int = wasm_store_context(store_h);

    vt: int = wasm_valtype_new(val_kind);
    mflag: int = WASM_MUT_CONST;
    if mutable {
        mflag = WASM_MUT_VAR;
    }
    gt: int = wasm_globaltype_new(vt, mflag);  # takes ownership of vt
    if gt == 0 {
        _set_err("globaltype_new failed", WASM_ERRCLASS_RUNTIME);
        return 0;
    }

    val_buf: int = io_alloc(_SIZEOF_VAL);
    _write_val(val_buf, 0, val_kind, ival, dval);

    gptr: int = io_alloc(_SIZEOF_MEMORY);  # 24-byte wasmtime_global_t
    err: int = wasmtime_global_new(ctx, gt, val_buf, gptr);
    wasm_globaltype_delete(gt);
    io_free(val_buf);
    if err != 0 {
        _set_err(_consume_error_message(err), WASM_ERRCLASS_RUNTIME);
        io_free(gptr);
        return 0;
    }
    return _wasm_global_register(store_h, gptr, mutable);
}

"""Set a mutable global's value (int kinds via ival, float via dval, chosen by
the global's current kind). Returns True on success; False on error/immutable."""
def:pub wasm_global_set_val(global_handle: int, ival: int, dval: float) -> bool {
    if global_handle < 1 or global_handle >= len(_WASM_GLOBALS) {
        _set_err("invalid global handle", WASM_ERRCLASS_RUNTIME);
        return False;
    }
    ctx: int = wasm_store_context(_WASM_GLOBAL_STORES[global_handle]);
    gptr: int = _WASM_GLOBALS[global_handle];
    if ctx == 0 or gptr == 0 {
        _set_err("invalid global handle", WASM_ERRCLASS_RUNTIME);
        return False;
    }
    kind: int = wasm_global_kind(global_handle);
    val_buf: int = io_alloc(_SIZEOF_VAL);
    _write_val(val_buf, 0, kind, ival, dval);
    err: int = wasmtime_global_set(ctx, gptr, val_buf);
    io_free(val_buf);
    if err != 0 {
        _set_err(_consume_error_message(err), WASM_ERRCLASS_RUNTIME);
        return False;
    }
    return True;
}

# ── Tables (funcref/externref) ───────────────────────────────────────────────
# Handle table for wasmtime_table_t (24 bytes, like memory/global). The element
# kind (funcref/externref) is tracked in parallel for get/set marshalling.
glob:priv _WASM_TABLES: list[int] = [0],
     _WASM_TABLE_STORES: list[int] = [0],
     _WASM_TABLE_ELEMS: list[int] = [0];  # ptr to 24-byte wasmtime_table_t

# owning store handle
# element valkind (funcref/externref)
def:priv _wasm_table_register(store_h: int, tptr: int, elem_kind: int) -> int {
    _WASM_TABLES.append(tptr);
    _WASM_TABLE_STORES.append(store_h);
    _WASM_TABLE_ELEMS.append(elem_kind);
    return len(_WASM_TABLES) - 1;
}

# wasm_limits_t is { u32 min; u32 max } (8 bytes). max=0xffffffff means "no max".
glob:priv _WASM_LIMITS_MAX_DEFAULT: int = 0xFFFFFFFF;

"""Create a standalone WebAssembly.Table in a fresh store. `elem_kind` is a flat
WASMTIME_* ref kind (FUNCREF=5/EXTERNREF=6). initial/maximum in elements
(maximum<0 → no maximum). New slots are initialised to null. Returns a table
handle (>=1) or 0."""
def:pub wasm_table_create(elem_kind: int, initial: int, maximum: int) -> int {
    store_h: int = wasm_store_open();
    if store_h == 0 {
        return 0;
    }
    ctx: int = wasm_store_context(store_h);

    # Element valtype uses the SPEC valkind numbers (funcref=129/externref=128).
    vk: int = WASM_VALKIND_FUNCREF;
    if elem_kind == WASMTIME_EXTERNREF {
        vk = WASM_VALKIND_EXTERNREF;
    }
    vt: int = wasm_valtype_new(vk);

    limits: int = io_alloc(8);
    write_i32(limits, 0, initial);
    if maximum < 0 {
        write_i32(limits, 4, _WASM_LIMITS_MAX_DEFAULT);
    } else {
        write_i32(limits, 4, maximum);
    }
    tt: int = wasm_tabletype_new(vt, limits);  # takes ownership of vt, borrows limits
    io_free(limits);
    if tt == 0 {
        _set_err("tabletype_new failed", WASM_ERRCLASS_RUNTIME);
        return 0;
    }

    # Initial value: a null ref of the element kind.
    init_buf: int = io_alloc(_SIZEOF_VAL);
    write_byte(init_buf, _OFF_KIND, elem_kind);
    write_i64(init_buf, _OFF_OF + 0, 0);  # null funcref/externref
    write_i64(init_buf, _OFF_OF + 8, 0);

    tptr: int = io_alloc(_SIZEOF_MEMORY);  # 24-byte wasmtime_table_t
    err: int = wasmtime_table_new(ctx, tt, init_buf, tptr);
    wasm_tabletype_delete(tt);
    io_free(init_buf);
    if err != 0 {
        _set_err(_consume_error_message(err), WASM_ERRCLASS_RUNTIME);
        io_free(tptr);
        return 0;
    }
    return _wasm_table_register(store_h, tptr, elem_kind);
}

def:priv _wasm_table_ctx(table_handle: int) -> int {
    if table_handle < 1 or table_handle >= len(_WASM_TABLE_STORES) {
        return 0;
    }
    return wasm_store_context(_WASM_TABLE_STORES[table_handle]);
}

def:priv _wasm_table_struct(table_handle: int) -> int {
    if table_handle < 1 or table_handle >= len(_WASM_TABLES) {
        return 0;
    }
    return _WASM_TABLES[table_handle];
}

"""Extract an exported table by name from an instance handle and register it.
Returns a table handle (>=1), or 0 if missing / not a table."""
def:pub wasm_export_table(inst_handle: int, name: str) -> int {
    store_h: int = wasm_inst_store(inst_handle);
    ctx: int = wasm_store_context(store_h);
    inst: int = wasm_inst_ptr(inst_handle);
    if ctx == 0 or inst == 0 {
        _set_err("invalid store/instance", WASM_ERRCLASS_LINK);
        return 0;
    }
    item_out: int = io_alloc(_SIZEOF_EXTERN);
    found: bool = wasmtime_instance_export_get(ctx, inst, name, len(name), item_out);
    if not found {
        _set_err("export not found: " + name, WASM_ERRCLASS_LINK);
        io_free(item_out);
        return 0;
    }
    kind: int = read_byte(item_out, _OFF_KIND);
    if kind != WASMTIME_EXTERN_TABLE {
        _set_err("export is not a table: " + name, WASM_ERRCLASS_LINK);
        io_free(item_out);
        return 0;
    }
    tptr: int = io_alloc(_SIZEOF_MEMORY);
    write_i64(tptr, 0, read_u64(item_out, _OFF_OF + 0));
    write_i64(tptr, 8, read_u64(item_out, _OFF_OF + 8));
    write_i64(tptr, 16, read_u64(item_out, _OFF_OF + 16));
    io_free(item_out);
    # Element kind unknown here without tabletype introspection; default funcref
    # (the common case). get/set below read the actual val kind byte anyway.
    return _wasm_table_register(store_h, tptr, WASMTIME_FUNCREF);
}

"""Number of elements in a table handle, or 0 if invalid."""
def:pub wasm_table_size(table_handle: int) -> int {
    ctx: int = _wasm_table_ctx(table_handle);
    tbl: int = _wasm_table_struct(table_handle);
    if ctx == 0 or tbl == 0 {
        return 0;
    }
    return wasmtime_table_size(ctx, tbl);
}

"""Get element kind at `index`: -1 out-of-bounds; 0 = null ref; 1 = non-null
funcref; 2 = non-null externref. (js_engine's JS Table.get returns a funcref
wrapper / null / the externref object; externref host-values are not yet round-
tripped, so a non-null externref surfaces as an opaque marker.)"""
def:pub wasm_table_get_kind(table_handle: int, index: int) -> int {
    ctx: int = _wasm_table_ctx(table_handle);
    tbl: int = _wasm_table_struct(table_handle);
    if ctx == 0 or tbl == 0 {
        return 0 - 1;
    }
    val_out: int = io_alloc(_SIZEOF_VAL);
    ok: bool = wasmtime_table_get(ctx, tbl, index, val_out);
    if not ok {
        io_free(val_out);
        return 0 - 1;
    }
    k: int = read_byte(val_out, _OFF_KIND);
    lo: int = read_u64(val_out, _OFF_OF + 0);
    io_free(val_out);
    if lo == 0 {
        return 0;
    }  # null ref
    if k == WASMTIME_EXTERNREF {
        return 2;
    }
    return 1;  # non-null funcref
}

"""Set table[index] = null (the only value js_engine can currently marshal into a
funcref/externref slot without a host-func handle). Returns True on success."""
def:pub wasm_table_set_null(table_handle: int, index: int) -> bool {
    ctx: int = _wasm_table_ctx(table_handle);
    tbl: int = _wasm_table_struct(table_handle);
    if ctx == 0 or tbl == 0 {
        _set_err("invalid table handle", WASM_ERRCLASS_RUNTIME);
        return False;
    }
    elem: int = WASMTIME_FUNCREF;
    if table_handle < len(_WASM_TABLE_ELEMS) {
        elem = _WASM_TABLE_ELEMS[table_handle];
    }
    val_buf: int = io_alloc(_SIZEOF_VAL);
    write_byte(val_buf, _OFF_KIND, elem);
    write_i64(val_buf, _OFF_OF + 0, 0);
    write_i64(val_buf, _OFF_OF + 8, 0);
    err: int = wasmtime_table_set(ctx, tbl, index, val_buf);
    io_free(val_buf);
    if err != 0 {
        _set_err(_consume_error_message(err), WASM_ERRCLASS_RUNTIME);
        return False;
    }
    return True;
}

"""Set table[index] = an exported/bound WASM function (by func handle). Returns
True on success. Marshals the func handle's wasmtime_func_t into a funcref."""
def:pub wasm_table_set_func(table_handle: int, index: int, func_handle: int) -> bool {
    ctx: int = _wasm_table_ctx(table_handle);
    tbl: int = _wasm_table_struct(table_handle);
    if ctx == 0 or tbl == 0 {
        _set_err("invalid table handle", WASM_ERRCLASS_RUNTIME);
        return False;
    }
    if func_handle < 1 or func_handle >= len(_WASM_FUNCS) {
        _set_err("invalid function handle", WASM_ERRCLASS_RUNTIME);
        return False;
    }
    fptr: int = _WASM_FUNCS[func_handle];
    if fptr == 0 {
        _set_err("freed function handle", WASM_ERRCLASS_RUNTIME);
        return False;
    }
    val_buf: int = io_alloc(_SIZEOF_VAL);
    write_byte(val_buf, _OFF_KIND, WASMTIME_FUNCREF);
    # funcref payload is a wasmtime_func_t (16 bytes) at _OFF_OF.
    write_i64(val_buf, _OFF_OF + 0, read_u64(fptr, 0));
    write_i64(val_buf, _OFF_OF + 8, read_u64(fptr, 8));
    err: int = wasmtime_table_set(ctx, tbl, index, val_buf);
    io_free(val_buf);
    if err != 0 {
        _set_err(_consume_error_message(err), WASM_ERRCLASS_RUNTIME);
        return False;
    }
    return True;
}

"""Grow a table by `delta` elements (new slots = null). Returns the previous
size, or -1 on failure."""
def:pub wasm_table_grow(table_handle: int, delta: int) -> int {
    ctx: int = _wasm_table_ctx(table_handle);
    tbl: int = _wasm_table_struct(table_handle);
    if ctx == 0 or tbl == 0 {
        _set_err("invalid table handle", WASM_ERRCLASS_RUNTIME);
        return 0 - 1;
    }
    elem: int = WASMTIME_FUNCREF;
    if table_handle < len(_WASM_TABLE_ELEMS) {
        elem = _WASM_TABLE_ELEMS[table_handle];
    }
    init_buf: int = io_alloc(_SIZEOF_VAL);
    write_byte(init_buf, _OFF_KIND, elem);
    write_i64(init_buf, _OFF_OF + 0, 0);
    write_i64(init_buf, _OFF_OF + 8, 0);
    prev_out: int = io_alloc(8);
    err: int = wasmtime_table_grow(ctx, tbl, delta, init_buf, prev_out);
    io_free(init_buf);
    if err != 0 {
        _set_err(_consume_error_message(err), WASM_ERRCLASS_RUNTIME);
        io_free(prev_out);
        return 0 - 1;
    }
    prev: int = read_u64(prev_out, 0);
    io_free(prev_out);
    return prev;
}

# ══════════════════════════════════════════════════════════════════════════════
# Host imports (JS→WASM callbacks) — the re-entrant trampoline.
# ══════════════════════════════════════════════════════════════════════════════
#
# Wasmtime calls a host import through a C function pointer with the signature
#   wasm_trap_t* (*)(void* env, wasmtime_caller_t* caller,
#                    const wasmtime_val_t* args, size_t nargs,
#                    wasmtime_val_t* results, size_t nresults)
# `_wasm_host_trampoline` below IS that C function (Jac `def`s with int/ptr
# params compile to the plain C ABI — same mechanism as NAPI's _napi_dispatch,
# whose address is handed to C via ptrtoint). Its `env` argument is the small-int
# "import index" we register at instantiate time; it re-enters the VM through a
# registered host-call callback (set by the dispatch layer, which owns the VM),
# marshals args→JSValues and the JS return→results, and returns NULL (no trap) or
# a wasmtime_trap_t* if the JS callback threw.
#
# The host-call callback contract (registered via wasm_register_host_call):
#   fn(import_index: int, nargs: int) -> int
#     - reads marshalled args from the module _WASM_HOST_ARG_* globals
#     - runs the JS import fn (re-entering the VM)
#     - writes results into _WASM_HOST_RES_* globals
#     - returns 0 on success, 1 if the JS fn threw (→ trap), 2 for "no VM"

# Single-slot registry (same dict-in-slot pattern as vm_obs's _OBS_CALL_TABLE,
# which avoids a nullable Callable glob — Jac rejects `= None` on a non-Optional
# Callable). Slot 0 holds the VM-backed host-call bridge once registered.
glob:priv _WASM_HOST_CALL_TABLE: dict[int, Callable[[int, int], int]] = {},
     _WASM_HOST_ARG_KINDS: list[int] = [],
     _WASM_HOST_ARG_INTS: list[int] = [],
     _WASM_HOST_ARG_DBLS: list[float] = [],
     _WASM_HOST_RES_KINDS: list[int] = [],
     _WASM_HOST_RES_INTS: list[int] = [],
     _WASM_HOST_RES_DBLS: list[float] = [],
     _WASM_HOST_IMPORT_RESULT_KINDS: list[list[int]] = [];

# Marshalling scratch (single-threaded; a host import cannot re-enter itself
# before the previous frame's results are consumed because wasm_func_call is
# synchronous). Args flow trampoline→JS; results flow JS→trampoline.

# Per-import result-kind template (what the WASM signature demands the host
# produce), indexed by import index. Filled at instantiate time.
"""Register the VM-backed host-call callback (called once at startup by the
dispatch layer, mirroring js_object_register_obs_impl)."""
def:pub wasm_register_host_call(cb: Callable[[int, int], int]) {
    _WASM_HOST_CALL_TABLE = {};
    _WASM_HOST_CALL_TABLE[0] = cb;
}

# Accessors the dispatch layer uses to read marshalled args / write results.
def:pub wasm_host_arg_count -> int {
    return len(_WASM_HOST_ARG_KINDS);
}
def:pub wasm_host_arg_kind(i: int) -> int {
    if i < 0 or i >= len(_WASM_HOST_ARG_KINDS) {
        return 0 - 1;
    }
    return _WASM_HOST_ARG_KINDS[i];
}

def:pub wasm_host_arg_int(i: int) -> int {
    if i < 0 or i >= len(_WASM_HOST_ARG_INTS) {
        return 0;
    }
    return _WASM_HOST_ARG_INTS[i];
}

def:pub wasm_host_arg_dbl(i: int) -> float {
    if i < 0 or i >= len(_WASM_HOST_ARG_DBLS) {
        return 0.0;
    }
    return _WASM_HOST_ARG_DBLS[i];
}

"""Expected result kinds for an import index (the WASM func's declared results)."""
def:pub wasm_host_result_kind_count(import_index: int) -> int {
    if import_index < 0 or import_index >= len(_WASM_HOST_IMPORT_RESULT_KINDS) {
        return 0;
    }
    return len(_WASM_HOST_IMPORT_RESULT_KINDS[import_index]);
}

def:pub wasm_host_result_kind(import_index: int, i: int) -> int {
    if import_index < 0 or import_index >= len(_WASM_HOST_IMPORT_RESULT_KINDS) {
        return 0 - 1;
    }
    rk: list[int] = _WASM_HOST_IMPORT_RESULT_KINDS[import_index];
    if i < 0 or i >= len(rk) {
        return 0 - 1;
    }
    return rk[i];
}

"""The dispatch layer calls this to push one marshalled result (int kinds via
ival, float kinds via dval)."""
def:pub wasm_host_push_result(kind: int, ival: int, dval: float) {
    _WASM_HOST_RES_KINDS.append(kind);
    _WASM_HOST_RES_INTS.append(ival);
    _WASM_HOST_RES_DBLS.append(dval);
}

"""Reset the host result accumulator (dispatch layer calls before pushing)."""
def:pub wasm_host_reset_results {
    _WASM_HOST_RES_KINDS = [];
    _WASM_HOST_RES_INTS = [];
    _WASM_HOST_RES_DBLS = [];
}

# ── Import extern builder ────────────────────────────────────────────────────
# The JS shim declares, per module import (in the order Module.imports reports),
# what host value to supply. We build a wasmtime_extern_t[] before instantiate.
# Only host FUNCTIONS are wired for re-entry; host memory/table/global imports
# supply an existing native handle's extern.
glob:priv _WASM_IMPORT_EXTERNS: int = 0,
     _WASM_IMPORT_COUNT: int = 0,
     _WASM_IMPORT_STORE: int = 0,
     _WASM_IMPORT_JSFN_TABLE: list[int] = [];  # io_alloc'd wasmtime_extern_t[]

# store the host funcs are created in
# Per-import host-func-created funcref (so the extern survives); the trampoline
# env is the import index into these parallel lists.
# opaque token per import (JS fn id)
"""Begin building the imports array for `nimports` module imports, all created
in store `store_h`. Allocates the wasmtime_extern_t[] scratch."""
def:pub wasm_imports_begin(store_h: int, nimports: int) {
    _WASM_IMPORT_STORE = store_h;
    _WASM_IMPORT_COUNT = nimports;
    _WASM_IMPORT_JSFN_TABLE = [];
    _WASM_HOST_IMPORT_RESULT_KINDS = [];
    if nimports > 0 {
        _WASM_IMPORT_EXTERNS = io_alloc(_SIZEOF_EXTERN * nimports);
    } else {
        _WASM_IMPORT_EXTERNS = 0;
    }
}

"""Open a fresh store, scan the module's imports (caching signatures), and begin
building the imports array. Returns the import count (>=0), or -1 on failure."""
def:pub wasm_imports_begin_for_module(module_handle: int) -> int {
    n: int = wasm_module_scan_imports(module_handle);
    if n < 0 {
        _set_err("invalid module handle", WASM_ERRCLASS_LINK);
        return 0 - 1;
    }
    store_h: int = wasm_store_open();
    if store_h == 0 {
        return 0 - 1;
    }
    wasm_imports_begin(store_h, n);
    return n;
}

"""Add a host FUNCTION import at slot `idx`, using the WASM-declared signature
cached by wasm_module_scan_imports (so the JS side supplies only the index +
callback token). `js_fn_token` is an opaque int the dispatch layer maps back to
the JS callback (typically the import index). Returns True on success."""
def:pub wasm_imports_add_func(idx: int, js_fn_token: int) -> bool {
    if _WASM_IMPORT_EXTERNS == 0 or idx < 0 or idx >= _WASM_IMPORT_COUNT {
        _set_err("import slot out of range", WASM_ERRCLASS_LINK);
        return False;
    }
    ctx: int = wasm_store_context(_WASM_IMPORT_STORE);
    if ctx == 0 {
        _set_err("invalid import store", WASM_ERRCLASS_LINK);
        return False;
    }

    param_kinds: list[int] = wasm_import_param_kinds(idx);
    result_kinds: list[int] = wasm_import_result_kinds(idx);

    # Build wasm_functype_t from the declared signature.
    ft: int = _build_functype(param_kinds, result_kinds);
    if ft == 0 {
        _set_err("functype build failed", WASM_ERRCLASS_LINK);
        return False;
    }

    # Record this import's result-kind template (keyed by import index = env).
    while len(_WASM_HOST_IMPORT_RESULT_KINDS) <= idx {
        _WASM_HOST_IMPORT_RESULT_KINDS.append([]);
    }
    _WASM_HOST_IMPORT_RESULT_KINDS[idx] = result_kinds;
    while len(_WASM_IMPORT_JSFN_TABLE) <= idx {
        _WASM_IMPORT_JSFN_TABLE.append(0);
    }
    _WASM_IMPORT_JSFN_TABLE[idx] = js_fn_token;

    # Create the host func; env encodes the import index so the trampoline knows
    # which JS callback to run. wasmtime_func_new writes a wasmtime_func_t (16B).
    func_out: int = io_alloc(16);
    trampoline: int = _wasm_host_trampoline;  # ptrtoint of the Jac fn (C ABI)
    wasmtime_func_new(ctx, ft, trampoline, idx, 0, func_out);
    wasm_functype_delete(ft);

    # Store the func into extern slot `idx`: kind=FUNC, of.func = the 16-byte func.
    base: int = idx * _SIZEOF_EXTERN;
    write_byte(_WASM_IMPORT_EXTERNS, base + _OFF_KIND, WASMTIME_EXTERN_FUNC);
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 0, read_u64(func_out, 0));
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 8, read_u64(func_out, 8));
    io_free(func_out);
    return True;
}

"""Add a host MEMORY import at slot `idx` from an existing native memory handle."""
def:pub wasm_imports_add_memory(idx: int, mem_handle: int) -> bool {
    if _WASM_IMPORT_EXTERNS == 0 or idx < 0 or idx >= _WASM_IMPORT_COUNT {
        return False;
    }
    mem: int = _wasm_mem_struct(mem_handle);
    if mem == 0 {
        _set_err("invalid memory import handle", WASM_ERRCLASS_LINK);
        return False;
    }
    base: int = idx * _SIZEOF_EXTERN;
    write_byte(_WASM_IMPORT_EXTERNS, base + _OFF_KIND, WASMTIME_EXTERN_MEMORY);
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 0, read_u64(mem, 0));
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 8, read_u64(mem, 8));
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 16, read_u64(mem, 16));
    return True;
}

"""Add a host GLOBAL import at slot `idx` from an existing native global handle."""
def:pub wasm_imports_add_global(idx: int, global_handle: int) -> bool {
    if _WASM_IMPORT_EXTERNS == 0 or idx < 0 or idx >= _WASM_IMPORT_COUNT {
        return False;
    }
    if global_handle < 1 or global_handle >= len(_WASM_GLOBALS) {
        return False;
    }
    g: int = _WASM_GLOBALS[global_handle];
    if g == 0 {
        _set_err("invalid global import handle", WASM_ERRCLASS_LINK);
        return False;
    }
    base: int = idx * _SIZEOF_EXTERN;
    write_byte(_WASM_IMPORT_EXTERNS, base + _OFF_KIND, WASMTIME_EXTERN_GLOBAL);
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 0, read_u64(g, 0));
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 8, read_u64(g, 8));
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 16, read_u64(g, 16));
    return True;
}

"""Add a host TABLE import at slot `idx` from an existing native table handle."""
def:pub wasm_imports_add_table(idx: int, table_handle: int) -> bool {
    if _WASM_IMPORT_EXTERNS == 0 or idx < 0 or idx >= _WASM_IMPORT_COUNT {
        return False;
    }
    t: int = _wasm_table_struct(table_handle);
    if t == 0 {
        _set_err("invalid table import handle", WASM_ERRCLASS_LINK);
        return False;
    }
    base: int = idx * _SIZEOF_EXTERN;
    write_byte(_WASM_IMPORT_EXTERNS, base + _OFF_KIND, WASMTIME_EXTERN_TABLE);
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 0, read_u64(t, 0));
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 8, read_u64(t, 8));
    write_i64(_WASM_IMPORT_EXTERNS, base + _OFF_OF + 16, read_u64(t, 16));
    return True;
}

"""Build a wasm_functype_t* from flat WASMTIME_* param/result kind lists. Owned
by the caller (delete after use). Returns 0 on failure."""
def:priv _build_functype(param_kinds: list[int], result_kinds: list[int]) -> int {
    np: int = len(param_kinds);
    nr: int = len(result_kinds);
    params_vec: int = io_alloc(_SIZEOF_TYPE_VEC);
    results_vec: int = io_alloc(_SIZEOF_TYPE_VEC);
    if np > 0 {
        pdata: int = io_alloc(8 * np);
        i: int = 0;
        while i < np {
            write_i64(pdata, i * 8, wasm_valtype_new(param_kinds[i]));
            i = i + 1;
        }
        wasm_valtype_vec_new(params_vec, np, pdata);
        io_free(pdata);
    } else {
        wasm_valtype_vec_new_empty(params_vec);
    }
    if nr > 0 {
        rdata: int = io_alloc(8 * nr);
        i2: int = 0;
        while i2 < nr {
            write_i64(rdata, i2 * 8, wasm_valtype_new(result_kinds[i2]));
            i2 = i2 + 1;
        }
        wasm_valtype_vec_new(results_vec, nr, rdata);
        io_free(rdata);
    } else {
        wasm_valtype_vec_new_empty(results_vec);
    }
    ft: int = wasm_functype_new(params_vec, results_vec);  # consumes the vecs
    io_free(params_vec);
    io_free(results_vec);
    return ft;
}

"""Instantiate a compiled module handle in the store built up by
wasm_imports_begin/add_*, wiring the imports array. Returns an instance HANDLE
(>=1), or 0 on link error / trap (wasm_last_error()/_class())."""
def:pub wasm_instantiate_with_imports(module_handle: int) -> int {
    store_h: int = _WASM_IMPORT_STORE;
    ctx: int = wasm_store_context(store_h);
    if ctx == 0 {
        _set_err("invalid import store", WASM_ERRCLASS_LINK);
        return 0;
    }
    if module_handle < 1 or module_handle >= len(_WASM_MODULES) {
        _set_err("invalid module handle", WASM_ERRCLASS_LINK);
        return 0;
    }
    module: int = _WASM_MODULES[module_handle];

    inst_out: int = io_alloc(_SIZEOF_INSTANCE);
    trap_out: int = io_alloc(8);
    # Push the store's VM context so the trampoline (fired if the module has a
    # start function that calls an import at instantiate time) can re-enter.
    err: int = wasmtime_instance_new(
        ctx, module, _WASM_IMPORT_EXTERNS, _WASM_IMPORT_COUNT, inst_out, trap_out
    );
    if _WASM_IMPORT_EXTERNS != 0 {
        io_free(_WASM_IMPORT_EXTERNS);
        _WASM_IMPORT_EXTERNS = 0;
    }
    if err != 0 {
        _set_err(_consume_error_message(err), WASM_ERRCLASS_LINK);
        io_free(inst_out);
        io_free(trap_out);
        return 0;
    }
    trap: int = read_u64(trap_out, 0);
    io_free(trap_out);
    if trap != 0 {
        _set_err(_consume_trap_message(trap), WASM_ERRCLASS_RUNTIME);
        io_free(inst_out);
        return 0;
    }
    _WASM_INSTS.append(inst_out);
    _WASM_INST_STORES.append(store_h);
    return len(_WASM_INSTS) - 1;
}

# ── The trampoline (raw C ABI; Wasmtime calls this) ──────────────────────────
"""C callback Wasmtime invokes for every host import. Signature:
  wasm_trap_t* (*)(void* env, wasmtime_caller_t* caller,
                   const wasmtime_val_t* args, size_t nargs,
                   wasmtime_val_t* results, size_t nresults)
`env` is the import index. Marshals args→_WASM_HOST_ARG_*, invokes the JS import
fn through the registered host-call callback (re-entering the VM), then marshals
_WASM_HOST_RES_* → the results buffer. Returns 0 (NULL, no trap) on success or a
wasmtime_trap_t* if the JS callback threw."""
def:pub _wasm_host_trampoline(
    env: int, caller: int, args: int, nargs: int, results: int, nresults: int
) -> int {
    import_index: int = env;

    # Marshal WASM args → host arg globals.
    _WASM_HOST_ARG_KINDS = [];
    _WASM_HOST_ARG_INTS = [];
    _WASM_HOST_ARG_DBLS = [];
    i: int = 0;
    while i < nargs {
        base: int = i * _SIZEOF_VAL;
        k: int = read_byte(args, base + _OFF_KIND);
        _WASM_HOST_ARG_KINDS.append(k);
        if k == WASMTIME_I32 {
            _WASM_HOST_ARG_INTS.append(read_i32(args, base + _OFF_OF));
            _WASM_HOST_ARG_DBLS.append(0.0);
        } elif k == WASMTIME_I64 {
            _WASM_HOST_ARG_INTS.append(read_u64(args, base + _OFF_OF));
            _WASM_HOST_ARG_DBLS.append(0.0);
        } elif k == WASMTIME_F32 {
            _WASM_HOST_ARG_INTS.append(0);
            _WASM_HOST_ARG_DBLS.append(_f32_from_bits(read_u32(args, base + _OFF_OF)));
        } else {
            _WASM_HOST_ARG_INTS.append(0);
            _WASM_HOST_ARG_DBLS.append(
                jsv_double_from_bits(read_u64(args, base + _OFF_OF))
            );
        }
        i = i + 1;
    }
    _WASM_HOST_RES_KINDS = [];
    _WASM_HOST_RES_INTS = [];
    _WASM_HOST_RES_DBLS = [];

    # Re-enter the VM to run the JS import fn.
    if 0 not in _WASM_HOST_CALL_TABLE {
        return wasmtime_trap_new("wasm host import: no VM callback registered", 44);
    }
    cb: Callable[[int, int], int] = _WASM_HOST_CALL_TABLE[0];
    rc: int = cb(import_index, nargs);
    if rc == 1 {
        # JS callback threw — surface as a trap (message carries the error text).
        tmsg: str = _WASM_LAST_ERR;
        if len(tmsg) == 0 {
            tmsg = "wasm host import threw";
        }
        return wasmtime_trap_new(tmsg, len(tmsg));
    }
    if rc == 2 {
        return wasmtime_trap_new("wasm host import: no active VM", 30);
    }

    # Marshal host results → the results buffer, using the WASM-declared result
    # kinds (authoritative; the host may have produced a number for any).
    j: int = 0;
    while j < nresults {
        want_kind: int = wasm_host_result_kind(import_index, j);
        if want_kind < 0 {
            want_kind = WASMTIME_I32;
        }
        iv: int = 0;
        dv: float = 0.0;
        if j < len(_WASM_HOST_RES_INTS) {
            iv = _WASM_HOST_RES_INTS[j];
        }
        if j < len(_WASM_HOST_RES_DBLS) {
            dv = _WASM_HOST_RES_DBLS[j];
        }
        _write_val(results, j, want_kind, iv, dv);
        j = j + 1;
    }
    return 0;  # NULL trap — success
}

"""Free a module handle and clear its slot (safe on already-freed handles)."""
def:pub wasm_module_free(module_handle: int) -> None {
    if module_handle < 1 or module_handle >= len(_WASM_MODULES) {
        return;
    }
    module: int = _WASM_MODULES[module_handle];
    if module == 0 {
        return;
    }
    wasmtime_module_delete(module);
    _WASM_MODULES[module_handle] = 0;
}

"""Close a store handle and clear its slot (safe on already-closed handles)."""
def:pub wasm_store_close(store_handle: int) -> None {
    if store_handle < 1 or store_handle >= len(_WASM_STORES) {
        return;
    }
    st: int = _WASM_STORES[store_handle];
    if st == 0 {
        return;
    }
    wasmtime_store_delete(st);
    _WASM_STORES[store_handle] = 0;
    _WASM_CTXS[store_handle] = 0;
}

# ── Internal: message extraction ─────────────────────────────────────────────

"""Read a wasmtime_error_t message into a Jac str, then delete the error.
The message goes into a wasm_byte_vec_t (size @0, data @8), which we copy out
and free with wasm_byte_vec_delete."""
def:priv _consume_error_message(err: int) -> str {
    vec: int = io_alloc(_SIZEOF_BYTE_VEC);
    wasmtime_error_message(err, vec);
    msg: str = _byte_vec_to_str(vec);
    wasm_byte_vec_delete(vec);
    io_free(vec);
    wasmtime_error_delete(err);
    return msg;
}

"""Read a wasm_trap_t message into a Jac str, then delete the trap."""
def:priv _consume_trap_message(trap: int) -> str {
    vec: int = io_alloc(_SIZEOF_BYTE_VEC);
    wasm_trap_message(trap, vec);
    msg: str = _byte_vec_to_str(vec);
    wasm_byte_vec_delete(vec);
    io_free(vec);
    wasm_trap_delete(trap);
    return msg;
}

"""Copy a wasm_byte_vec_t (size @0, char* data @8) into an owned Jac str.
Message vecs from Wasmtime are NUL-terminated; we bound the copy by size."""
def:priv _byte_vec_to_str(vec: int) -> str {
    size: int = read_u64(vec, _OFF_VEC_SIZE);
    data: int = read_u64(vec, _OFF_VEC_DATA);
    if data == 0 or size <= 0 {
        return "";
    }
    return _wasm_foreign_str(data, size);
}

# ── Phase-0 self-test ────────────────────────────────────────────────────────
# Lives in this FFI module (which has no `with entry`) so main.jac can import
# and run it env-gated. Standalone `jac nacompile` of a leaf file does NOT
# reliably propagate the libwasmtime.so DT_NEEDED through the transitive jac
# import (see docs/wasm.md Phase 0 / issues note), so the smoke MUST run inside
# the full engine build to link Wasmtime correctly.

# Assembled WASM binary for the canonical `add` module (42 bytes):
#   (module (func (export "add") (param i32 i32) (result i32)
#     local.get 0 local.get 1 i32.add))
glob:priv _ADD_WASM: list[int] = [
         0x00,
         0x61,
         0x73,
         0x6d,
         0x01,
         0x00,
         0x00,
         0x00,  # magic + version
         0x01,
         0x07,
         0x01,
         0x60,
         0x02,
         0x7f,
         0x7f,
         0x01,
         0x7f,  # type: (i32 i32)->i32
         0x03,
         0x02,
         0x01,
         0x00,  # func section
         0x07,
         0x07,
         0x01,
         0x03,
         0x61,
         0x64,
         0x64,
         0x00,
         0x00,  # export "add" -> func 0
         0x0a,
         0x09,
         0x01,
         0x07,
         0x00,
         0x20,
         0x00,
         0x20,
         0x01,
         0x6a,
         0x0b  # code
     ];

def:priv _write_add_wasm -> int {
    n: int = len(_ADD_WASM);
    buf: int = io_alloc(n);
    i: int = 0;
    while i < n {
        write_byte(buf, i, _ADD_WASM[i]);
        i = i + 1;
    }
    return buf;
}

"""Run the Phase-0 compile → instantiate → call smoke: assert add(2,3)==5 and
add(40,2)==42 through a real Wasmtime-compiled module. Prints only OK lines on
success (and FAIL lines otherwise). Returns True iff both assertions hold."""
def:pub wasm_phase0_smoke -> bool {
    n: int = len(_ADD_WASM);
    wasm_ptr: int = _write_add_wasm();
    ok: bool = True;

    if not wasm_module_valid(wasm_ptr, n) {
        print("FAIL validate: " + wasm_last_error());
        ok = False;
    } else {
        print("OK validate");
        module_h: int = wasm_module_compile(wasm_ptr, n);
        if module_h == 0 {
            print("FAIL compile: " + wasm_last_error());
            ok = False;
        } else {
            print("OK compile");
            store_h: int = wasm_store_open();
            if store_h == 0 {
                print("FAIL store: " + wasm_last_error());
                ok = False;
            } else {
                inst: int = wasm_instance_new(store_h, module_h);
                if inst == 0 {
                    print("FAIL instantiate: " + wasm_last_error());
                    ok = False;
                } else {
                    print("OK instantiate");
                    func: int = wasm_export_func(store_h, inst, "add");
                    if func == 0 {
                        print("FAIL export: " + wasm_last_error());
                        ok = False;
                    } else {
                        print("OK export add");
                        r1: int = wasm_call_i32_i32_i32(store_h, func, 2, 3, 0 - 1);
                        if r1 == 5 {
                            print("OK call add(2,3)==5");
                        } else {
                            print(
                                "FAIL call add(2,3)="
                                    + str(r1)
                                    + " err="
                                    + wasm_last_error()
                            );
                            ok = False;
                        }
                        r2: int = wasm_call_i32_i32_i32(store_h, func, 40, 2, 0 - 1);
                        if r2 == 42 {
                            print("OK call add(40,2)==42");
                        } else {
                            print(
                                "FAIL call add(40,2)="
                                    + str(r2)
                                    + " err="
                                    + wasm_last_error()
                            );
                            ok = False;
                        }
                        io_free(func);
                    }
                    io_free(inst);
                }
                wasm_store_close(store_h);
            }
            wasm_module_free(module_h);
        }
    }
    io_free(wasm_ptr);
    if ok {
        print("OK wasmtime phase0 smoke passed");
    } else {
        print("FAIL wasmtime phase0 smoke");
    }
    return ok;
}

# ── Phase-1 self-test — shared linear memory ─────────────────────────────────
# Gate (docs/wasm.md Phase 1): JS reads/writes the exact bytes WASM wrote,
# including after memory.grow. Runs inside the full engine build (env-gated in
# main.jac on JS_ENGINE_WASM_MEM_SMOKE=1), for the same transitive-DT_NEEDED
# reason as Phase 0.
#
# The module below exports a linear memory plus two funcs so we can drive WASM
# writes/reads directly:
#   (module
#     (memory (export "mem") 1 10)                 ;; 1 page init, 10 pages max
#     (func (export "store8") (param i32 i32)      ;; off,val → mem[off]=val
#       local.get 0 local.get 1 i32.store8)
#     (func (export "load8") (param i32) (result i32)  ;; off → mem[off]
#       local.get 0 i32.load8_u))
# Liveness proof: after WASM store8 writes a byte, reading that byte through the
# *live base pointer* wasm_memory_data() must return the same value — with NO
# copy anywhere. That base pointer is exactly what binary_register_buffer stores
# as BackingStore.ptr, and exactly what buf_get_byte / a Uint8Array over
# Memory.buffer read through — so this is the identical mechanism JS uses.
glob:priv _MEM_WASM: list[int] = [
         0x00,
         0x61,
         0x73,
         0x6d,
         0x01,
         0x00,
         0x00,
         0x00,  # magic+version
         0x01,
         0x0b,
         0x02,
         0x60,
         0x02,
         0x7f,
         0x7f,
         0x00,  # type0 (i32 i32)->()
         0x60,
         0x01,
         0x7f,
         0x01,
         0x7f,  # type1 (i32)->(i32)
         0x03,
         0x03,
         0x02,
         0x00,
         0x01,  # funcs: t0,t1
         0x05,
         0x04,
         0x01,
         0x01,
         0x01,
         0x0a,  # memory: min1 max10
         0x07,
         0x18,
         0x03,  # exports: 3
         0x03,
         0x6d,
         0x65,
         0x6d,
         0x02,
         0x00,  #   "mem"    mem 0
         0x06,
         0x73,
         0x74,
         0x6f,
         0x72,
         0x65,
         0x38,
         0x00,
         0x00,  #   "store8" func 0
         0x05,
         0x6c,
         0x6f,
         0x61,
         0x64,
         0x38,
         0x00,
         0x01,  #   "load8"  func 1
         0x0a,
         0x13,
         0x02,  # code: 2 bodies
         0x09,
         0x00,
         0x20,
         0x00,
         0x20,
         0x01,
         0x3a,
         0x00,
         0x00,
         0x0b,  # store8
         0x07,
         0x00,
         0x20,
         0x00,
         0x2d,
         0x00,
         0x00,
         0x0b  # load8
     ];

def:priv _write_mem_wasm -> int {
    n: int = len(_MEM_WASM);
    buf: int = io_alloc(n);
    i: int = 0;
    while i < n {
        write_byte(buf, i, _MEM_WASM[i]);
        i = i + 1;
    }
    return buf;
}

# WASM page size (bytes).
glob:priv _WASM_PAGE: int = 65536;

"""Phase-1 round-trip over an *instance-exported* memory. Returns True on pass.
Proves: (1) WASM writes → live-view read byte-exact; (2) live-view write → WASM
read byte-exact; (3) grow preserves old bytes, exposes new pages, and the base
ptr is re-fetched (Node detaches the old buffer — the old ptr/len are stale)."""
def:priv _wasm_mem_roundtrip -> bool {
    n: int = len(_MEM_WASM);
    wasm_ptr: int = _write_mem_wasm();
    ok: bool = True;

    mod_h: int = wasm_module_compile(wasm_ptr, n);
    io_free(wasm_ptr);
    if mod_h == 0 {
        print("FAIL mem compile: " + wasm_last_error());
        return False;
    }
    print("OK mem compile");

    store_h: int = wasm_store_open();
    if store_h == 0 {
        print("FAIL mem store: " + wasm_last_error());
        return False;
    }

    inst: int = wasm_instance_new(store_h, mod_h);
    if inst == 0 {
        print("FAIL mem instantiate: " + wasm_last_error());
        wasm_store_close(store_h);
        wasm_module_free(mod_h);
        return False;
    }
    print("OK mem instantiate");

    mem_h: int = wasm_export_memory(store_h, inst, "mem");
    store8: int = wasm_export_func(store_h, inst, "store8");
    load8: int = wasm_export_func(store_h, inst, "load8");
    if mem_h == 0 or store8 == 0 or load8 == 0 {
        print("FAIL mem exports: " + wasm_last_error());
        io_free(inst);
        wasm_store_close(store_h);
        wasm_module_free(mod_h);
        return False;
    }
    print("OK mem exports (mem/store8/load8)");

    base0: int = wasm_memory_data_ptr(mem_h);
    size0: int = wasm_memory_data_size(mem_h);
    pages0: int = wasm_memory_size_pages(mem_h);
    if base0 == 0 or size0 != _WASM_PAGE or pages0 != 1 {
        print(
            "FAIL mem geometry base="
                + str(base0)
                + " size="
                + str(size0)
                + " pages="
                + str(pages0)
        );
        io_free(inst);
        wasm_store_close(store_h);
        wasm_module_free(mod_h);
        return False;
    }
    print("OK mem geometry (1 page, 65536 bytes)");

    # (1) WASM writes a pattern; read it back through the LIVE base ptr.
    i: int = 0;
    while i < 16 {
        val: int = (i * 7 + 3) & 255;
        if not wasm_call_i32_i32_void(store_h, store8, i, val) {
            print("FAIL wasm store8 off=" + str(i) + " err=" + wasm_last_error());
            ok = False;
            i = 16;
        } else {
            i = i + 1;
        }
    }
    if ok {
        i = 0;
        while i < 16 {
            expect: int = (i * 7 + 3) & 255;
            got: int = read_byte(base0, i);
            if got != expect {
                print(
                    "FAIL live-read off="
                        + str(i)
                        + " got="
                        + str(got)
                        + " want="
                        + str(expect)
                );
                ok = False;
                i = 16;
            } else {
                i = i + 1;
            }
        }
    }
    if ok {
        print("OK WASM wrote → live view read byte-exact (16 bytes)");
    }

    # (2) Write through the live base ptr; WASM reads it back.
    if ok {
        write_byte(base0, 100, 0xAB);
        write_byte(base0, 101, 0xCD);
        r100: int = wasm_call_i32_i32(store_h, load8, 100, 0 - 1);
        r101: int = wasm_call_i32_i32(store_h, load8, 101, 0 - 1);
        if r100 == 0xAB and r101 == 0xCD {
            print("OK live view wrote → WASM read byte-exact");
        } else {
            print("FAIL wasm read-back r100=" + str(r100) + " r101=" + str(r101));
            ok = False;
        }
    }

    # (3) grow: preserve old bytes, expose new pages, base ptr re-fetched.
    if ok {
        # Sentinel at the very top of page 0, just below the grow boundary.
        write_byte(base0, _WASM_PAGE - 1, 0x5A);
        prev_pages: int = wasm_memory_grow(mem_h, 2);  # +2 pages → 3 total
        if prev_pages != 1 {
            print(
                "FAIL grow prev_pages=" + str(prev_pages) + " err=" + wasm_last_error()
            );
            ok = False;
        } else {
            base1: int = wasm_memory_data_ptr(mem_h);
            size1: int = wasm_memory_data_size(mem_h);
            pages1: int = wasm_memory_size_pages(mem_h);
            if size1 != _WASM_PAGE * 3 or pages1 != 3 or base1 == 0 {
                print(
                    "FAIL grown geometry size="
                        + str(size1)
                        + " pages="
                        + str(pages1)
                        + " base="
                        + str(base1)
                );
                ok = False;
            } else {
                print("OK grow 1→3 pages (196608 bytes)");
                # Old bytes preserved (re-read through the NEW base ptr).
                old_ok: bool = (
                    read_byte(base1, 0) == 3
                    and read_byte(base1, _WASM_PAGE - 1) == 0x5A
                    and read_byte(base1, 100) == 0xAB
                );
                if not old_ok {
                    print(
                        "FAIL grow lost old bytes b0="
                            + str(read_byte(base1, 0))
                            + " sentinel="
                            + str(read_byte(base1, _WASM_PAGE - 1))
                    );
                    ok = False;
                } else {
                    print("OK old bytes preserved after grow");
                }
                # New pages accessible: write near the top, WASM reads it back.
                if ok {
                    hi: int = _WASM_PAGE * 3 - 4;
                    write_byte(base1, hi, 0x77);
                    rhi: int = wasm_call_i32_i32(store_h, load8, hi, 0 - 1);
                    if rhi == 0x77 {
                        print("OK new pages accessible (WASM read grown region)");
                    } else {
                        print("FAIL new-page read rhi=" + str(rhi));
                        ok = False;
                    }
                }
                # Detach-on-grow contract: the OLD base ptr moved (or, if it
                # happened to stay, the old *length* is now stale). In JS terms
                # the old ArrayBuffer is detached (zero-length) and callers must
                # re-read memory.buffer. We assert the re-fetched geometry is the
                # authoritative one (size1) and that reads must use base1.
                if ok {
                    if base1 != base0 {
                        print("OK detach-on-grow: base ptr moved (old buffer stale)");
                    } else {
                        print(
                            "OK detach-on-grow: base stable, old length stale (old size="
                                + str(size0)
                                + " new="
                                + str(size1)
                                + ")"
                        );
                    }
                }
            }
        }
    }

    io_free(load8);
    io_free(store8);
    wasm_memory_free(mem_h);
    io_free(inst);
    wasm_store_close(store_h);
    wasm_module_free(mod_h);
    return ok;
}

"""Phase-1 round-trip over a *standalone* linear memory (the future
`WebAssembly.Memory({initial,maximum})` path via wasm_memory_create): create,
write through the live base ptr, grow, verify old bytes survive. Returns True on
pass."""
def:priv _wasm_standalone_mem -> bool {
    store_h: int = wasm_store_open();
    if store_h == 0 {
        print("FAIL standalone store: " + wasm_last_error());
        return False;
    }
    mem_h: int = wasm_memory_create(store_h, 1, 4);  # 1 page init, 4 max
    if mem_h == 0 {
        print("FAIL standalone memory create: " + wasm_last_error());
        wasm_store_close(store_h);
        return False;
    }
    base0: int = wasm_memory_data_ptr(mem_h);
    size0: int = wasm_memory_data_size(mem_h);
    ok: bool = True;
    if base0 == 0 or size0 != _WASM_PAGE {
        print("FAIL standalone geometry base=" + str(base0) + " size=" + str(size0));
        ok = False;
    } else {
        print("OK standalone Memory(1,4) created (65536 bytes)");
        write_byte(base0, 0, 0xDE);
        write_byte(base0, size0 - 1, 0xAD);
        prev: int = wasm_memory_grow(mem_h, 1);  # → 2 pages
        base1: int = wasm_memory_data_ptr(mem_h);
        size1: int = wasm_memory_data_size(mem_h);
        if prev != 1 or size1 != _WASM_PAGE * 2 {
            print("FAIL standalone grow prev=" + str(prev) + " size=" + str(size1));
            ok = False;
        } elif read_byte(base1, 0) != 0xDE
            or read_byte(base1, _WASM_PAGE - 1) != 0xAD {
            print("FAIL standalone grow lost bytes");
            ok = False;
        } else {
            print("OK standalone Memory grow 1→2 pages, old bytes preserved");
        }
    }
    wasm_memory_free(mem_h);
    wasm_store_close(store_h);
    return ok;
}

"""Run the Phase-1 shared-linear-memory smoke. Prints OK/FAIL lines; returns
True iff every check passes (gate: JS reads/writes exactly the bytes WASM wrote,
including after grow)."""
def:pub wasm_phase1_mem_smoke -> bool {
    ok1: bool = _wasm_mem_roundtrip();
    ok2: bool = _wasm_standalone_mem();
    ok: bool = ok1 and ok2;
    if ok {
        print("OK wasmtime phase1 memory smoke passed");
    } else {
        print("FAIL wasmtime phase1 memory smoke");
    }
    return ok;
}
