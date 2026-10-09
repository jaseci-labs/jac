"""
runtime/realm.na.jac — Per-execution-context state container.

A3.0 (additive): Defines Realm obj and realm_new() factory.
A3.1 (thread-through): Realm holds all primitive / JSValue engine state.
A3.3 (typed cell tables): Realm holds all typed cell tables (JSObject,
  JSClosure, JSFunctionMeta, BuiltinFn, NativeFn, JSMapStorage, JSSetStorage,
  JSGeneratorState, JSRegExpState, TimerEntry).  Each type is defined in a
  *_type.na.jac file that does NOT import realm.na.jac (avoids cycles).

One Realm per Worker / vm.createContext.  The process-default
Realm is constructed in vm/event_loop.na.jac and passed through
the Jac call stack; C-level libuv callbacks read _DEFAULT_REALM.
"""

import from engine.src.runtime.jsvalue { JSValue }

# GC collection-frequency floor (allocations between collections, before the
# adaptive proportional-heap growth kicks in). Default 10000; override via the
# JAC_GC_MIN_THRESHOLD env var (wired in main.jac). Raising it makes GC collect
# LESS often (lower CPU overhead / higher peak). A leaf glob (not a Realm
# struct field) so tuning needs no struct-field scrub.
glob:pub _GC_MIN_THRESHOLD: int = 10000;

"""Set the GC collection-frequency floor (allocations between collections).
No-op for non-positive values."""
def:pub gc_min_threshold_set(n: int) {
    if n > 0 {
        _GC_MIN_THRESHOLD = n;
    }
}

# Allocations allowed between collections, as a percentage of the objects that
# survived the last one (JAC_GC_GROWTH, wired in main.jac; `--smol` sets 100).
# 100 lets the heap double before the next full mark-sweep; 200 lets it triple:
# fewer collections for a larger peak (jac_client: 40 collections, each
# memory-bound).
glob:pub _GC_GROWTH_PCT: int = 200;
# True once JAC_GC_GROWTH / --smol pinned the growth (gc_growth_pct_set); then
# gc_growth_pct_for uses it as is instead of tapering it.
glob:pub _GC_GROWTH_FIXED: bool = False;

"""Set the GC growth percentage (see _GC_GROWTH_PCT). No-op for non-positive values."""
def:pub gc_growth_pct_set(n: int) {
    if n > 0 {
        _GC_GROWTH_PCT = n;
        _GC_GROWTH_FIXED = True;
    }
}

"""Growth percentage for the next collection, given the live object count.
Up to 2M live objects it is the full _GC_GROWTH_PCT, so collections stay rare
for ordinary programs. Past that, a heap allowed to triple between collections
stops fitting in memory (a large vite build peaked at 22 GB with ~11M live
objects), so the growth tapers linearly to 50% at 8M live objects: extra
collections happen only where the heap is huge. A pinned value is used as is."""
def:pub gc_growth_pct_for(live: int) -> int {
    if _GC_GROWTH_FIXED or live <= 2000000 or _GC_GROWTH_PCT <= 50 {
        return _GC_GROWTH_PCT;
    }
    if live >= 8000000 {
        return 50;
    }
    return _GC_GROWTH_PCT - (_GC_GROWTH_PCT - 50) * (live - 2000000) // 6000000;
}

"""Whether new realms start with the collector on. On by default; `--nogc`
turns it off for every realm the process creates (main, secondary, workers)."""
glob:pub _GC_DEFAULT_ENABLED: bool = True;

def:pub gc_default_set(v: bool) {
    _GC_DEFAULT_ENABLED = v;
}

# Typed cell table types (each in a *_type.na.jac that does NOT import realm)
import from engine.src.runtime.jsobj_type { JSObject, ProxyState, ArgsState }
import from engine.src.vm.closure_type { JSClosure }
import from engine.src.builtins.function_type { JSFunctionMeta, BuiltinFn }
import from engine.src.builtins.native_type { NativeFn }
import from engine.src.builtins.map_type { JSMapStorage }
import from engine.src.builtins.set_type { JSSetStorage }
import from engine.src.builtins.generator_type { JSGeneratorState }
import from engine.src.builtins.regexp_type { JSRegExpState }
import from engine.src.vm.timer_type { TimerEntry }

# ══════════════════════════════════════════════════════════════════════════════
# Realm intrinsics (must precede Realm — forward reference)
# ══════════════════════════════════════════════════════════════════════════════

"""Per-realm intrinsic objects needed for GetFunctionRealm / species demotion."""
obj:pub RealmIntrinsics {
    has array_ctor: JSValue = 0,
        array_proto: JSValue = 0,
        object_ctor: JSValue = 0,
        object_proto: JSValue = 0,
        function_ctor: JSValue = 0,
        function_proto: JSValue = 0;
}

# ══════════════════════════════════════════════════════════════════════════════
# Realm object
# ══════════════════════════════════════════════════════════════════════════════

obj:pub Realm {
    # ── String interning (from jsstring.na.jac) ──────────────────────────────
    # Maps raw Jac str ↔ integer key-ID used by JSValue string cells.
    has intern_by_str: dict[str, int] = {},
        intern_by_id: dict[int, str] = {},
        intern_next_id: int = 0,
        intern_seeded: bool = False,
        symbols: list[str] = [],
        symbol_registry: dict[str, int] = {},
        symbol_seeded: bool = False,
        gc_alloc_count: int = 0,
        gc_threshold: int = 0,
        gc_enabled: bool = True,
        gc_in_progress: bool = False,
        weak_refs: dict[int, list[int]] = {},
        finalization_queue: list[JSValue] = [],
        gc_temp_roots: list[JSValue] = [],
        objects: list[JSObject] = [],
        closures: list[JSClosure] = [],
        functions: list[JSFunctionMeta] = [],
        builtins: list[BuiltinFn] = [],
        natives: list[NativeFn] = [],
        maps: list[JSMapStorage] = [],
        sets: list[JSSetStorage] = [],
        generators: list[JSGeneratorState] = [],
        regexps: list[JSRegExpState] = [],
        timers: list[TimerEntry] = [],
        free_object_slots: list[int] = [],
        free_closure_slots: list[int] = [],
        objects_mark_epoch: list[int] = [],
        closures_mark_epoch: list[int] = [],
        functions_mark_epoch: list[int] = [],
        builtins_mark_epoch: list[int] = [],
        natives_mark_epoch: list[int] = [],
        maps_mark_epoch: list[int] = [],
        sets_mark_epoch: list[int] = [],
        generators_mark_epoch: list[int] = [],
        regexps_mark_epoch: list[int] = [],
        timers_mark_epoch: list[int] = [],
        global_this: JSValue = 0,
        uncaught_exceptions: list[JSValue] = [],
        microtask_fns: list[JSValue] = [],
        microtask_args: list[list[JSValue]] = [],
        next_tick_fns: list[JSValue] = [],
        next_tick_args: list[list[JSValue]] = [],
        react_on_f: list[JSValue] = [],
        react_on_r: list[JSValue] = [],
        react_states: list[int] = [],
        react_vals: list[JSValue] = [],
        react_next_p: list[JSValue] = [],
        timer_next_id: int = 0,
        timer_loop_ptr: int = 0,
        timer_async_ptr: int = 0,
        fired_fns: list[JSValue] = [],
        fired_args: list[list[JSValue]] = [],
        el_handle: int = 0,
        vm_handle: int = 0,
        stack_limit: int = 0,
        heap_limit_bytes: int = 0,
        interrupt_flag: bool = False,
        pending_exit: bool = False,
        pending_exit_code: int = 0,
        array_values_fn: JSValue = 0,
        template_cache: dict[int, JSValue] = {},
        realm_id: int = 0,
        intrinsics: RealmIntrinsics = RealmIntrinsics(),
        heap_strings: list[str] = [],
        rope_left: list[int] = [],
        rope_right: list[int] = [],
        rope_len: list[int] = [],
        intern_ascii: dict[int, int] = {},
        heap_ascii: list[int] = [],
        free_generator_slots: list[int] = [],
        import_meta_cache: dict[str, JSValue] = {},
        gc_pending: bool = False,
        free_map_slots: list[int] = [],
        free_set_slots: list[int] = [],
        free_regexp_slots: list[int] = [],
        gc_epoch: int = 1,
        gc_scan_weakmaps: list[int] = [],
        gc_scan_weaksets: list[int] = [],
        heap_strings_mark_epoch: list[int] = [],
        free_heap_string_slots: list[int] = [],
        proxy_slots: dict[int, ProxyState] = {},
        args_slots: dict[int, ArgsState] = {},
        safepoint_req: bool = False;
}

# ── Symbol table (from jssymbol.na.jac) ──────────────────────────────────
# Each slot holds the description string; index = symbol ID in JSValue.

# Symbol.for() global registry

# ── GC control ───────────────────────────────────────────────────────────
# Typed cell tables are now on realm (objects, closures, …); the GC
# metadata below tracks allocation volume for the threshold-based
# mark-sweep trigger.

# trigger GC after this many allocs
# the collector runs unless --nogc was given (realm_new applies the flag)

# target_idx → [slot_addr, …]

# temporary GC roots (push before run_cl, pop after)

# ── Typed cell tables (migrated from module-level globs in A3.3) ─────────
# was _OBJECT_TABLE
# was _CLOSURE_TABLE
# was _FUNCTION_TABLE
# was _BUILTIN_TABLE
# was _NATIVE_TABLE
# was _MAP_TABLE
# was _SET_TABLE
# was _GENERATOR_TABLE
# was _REGEXP_TABLE
# was _TIMERS

# ── GC free-list (A2.4) — indices of tombstoned slots available for reuse ──
# 1-based external indices
# 0-based

# ── GC mark epochs (A2.2/A2.2b; G1.1 epoch marks) — parallel to cell tables ──
# Per slot: the `gc_epoch` at which it was last marked (0 = never). A slot is
# marked THIS cycle iff `*_mark_epoch[idx] == gc_epoch`; gc_clear_marks bumps
# `gc_epoch` (O(1)) instead of resetting these arrays (was `list[bool]`).

# ── VM execution state ───────────────────────────────────────────────────
# globalThis JS object

# ── Microtask / next-tick queues (from scheduler.na.jac) ─────────────────

# ── Promise reaction queues (from scheduler.na.jac _REACT_* globs) ───────

# ── Timer state (from timers.na.jac) ─────────────────────────────────────
# TimerEntry list is realm.timers (migrated from _TIMERS glob in A3.3).

# raw uv_loop_t*
# raw uv_async_t*

# ── Event loop / VM handles (opaque ints to avoid circular imports) ───────

# ── Interrupt / limits ───────────────────────────────────────────────────

# 0 = unlimited

# ── Pending process.exit() request ───────────────────────────────────────
# Set by NATIVE_KIND_PROCESS_EXIT; checked in el_run before final return.

# ── Cached canonical intrinsics (identity-stable references) ──────────────
# %Array.prototype.values% — the single native shared by Array.prototype
# `values`/@@iterator and by every `arguments` object's own @@iterator so
# that SameValue identity holds (ES §10.4.4).  Set in global_context_create.

# ── Tagged-template object cache (ES §13.2.8.4 [[TemplateMap]]) ────────────
# site-id → the frozen cooked-strings template object (with frozen own `.raw`).
# Each tagged-template *source site* yields the SAME object on every evaluation
# (SameValue identity), so a tag can key a cache off its strings argument.

# ── ECMAScript Realm Record (R13: cross-realm / $262.createRealm) ────────
# (merge: both branches appended struct fields — keep all four, at the end.)

# ── Non-interned (heap) string store ─────────────────────────────────────
# Interning is right for identifiers and property keys (short, few, reused —
# the dedup and O(1) equality pay off). It is catastrophic for computed
# string VALUES: `s += chunk` in a loop re-hashed the whole accumulated
# string and stored two more copies every iteration, making string concat
# O(n^2) in both time and memory (a 200KB result cost ~2GB). Computed
# strings go here instead — appended once, never hashed, never deduped.
# IDs are (HEAP_STRING_BASE + index); str_from_id resolves both stores.
# Appended at struct END — Realm field order is offset-sensitive
# (js_engine-vm-struct-field-order).

# Rope nodes: a concat result is stored lazily as (left_id, right_id) instead
# of eagerly copying both halves. `s += chunk` in a loop then costs O(1) per
# step; the flatten to a real string happens once, when the value is actually
# read (str_from_id). This is what makes concatenation amortized O(n) instead
# of O(n^2) without the aliasing hazard of in-place mutation — a rope node is
# immutable, so sharing a sub-rope across several values is always safe.
# Parallel to heap_strings by index: for heap id i, if rope_left[i] >= 0 the
# node is an unflattened rope of (rope_left[i] ++ rope_right[i]); once
# flattened, heap_strings[i] holds the text and rope_left[i] is set to -1.
# A lazy slice (jsstring.str_slice_cell) uses the same slots: rope_left[i] is
# its parent, rope_right[i] = -2 - byte offset (<= -2), rope_len[i] its length.
# Appended at struct END (js_engine-vm-struct-field-order).

# total char length, for cheap len() without flatten
# Per-string "is pure ASCII" cache (0=unknown, 1=ascii, 2=non-ascii). When a
# string is all-ASCII, UTF-8 byte index == UTF-16 unit index, so charAt /
# charCodeAt / codePointAt are O(1) (ord(s[i])) instead of scanning bytes
# [0,i] every call — which made those methods O(n^2) in a loop. The flag is
# computed once, during work already being done (str_intern's hash walk, or a
# rope flatten), so it adds no extra pass. Interned strings key by id; heap
# strings are parallel to heap_strings by index.
# Appended at struct END (js_engine-vm-struct-field-order).

# 0-based indices of tombstoned generator slots available for reuse.
# Appended struct END (js_engine-vm-struct-field-order).

# ES §16.2.1.10: `import.meta` returns the SAME object for a given module (the Module
# Record's [[ImportMeta]]), so properties added to it persist and `import.meta ===
# import.meta`. Cached here keyed by the module's filename. Appended struct END.

# Deferred-collection request from `global.gc()` (G0.2): the dispatch handler
# cannot collect directly — it has no access to the VM operand stack / frame
# locals, so a direct gc_collect would sweep values live only on the stack.
# Instead it sets this flag; the interpreter's loop-top safepoint (where the
# full root set is assemblable) services it. Appended struct END
# (js_engine-vm-struct-field-order).

# G0.5 slot-leak fix: GC free-lists for Map / Set backing-store slots, mirroring
# free_object_slots / free_closure_slots. gc_sweep_maps/sets tombstone an
# unmarked slot (cell_flags = CELL_FLAG_DEAD) and push its index here;
# js_map_create* / js_set_create* pop and reuse it instead of always appending
# (previously realm.maps/sets grew unbounded under Map/Set churn). Appended
# struct END (js_engine-vm-struct-field-order).

# G0.5 regexp GC-cell: swept regexp slots for reuse by _get_or_compile.
# gc_sweep_regexps tombstones an unmarked slot, frees its pcre2_code, and
# pushes its index here (previously realm.regexps grew unbounded under
# dynamic `new RegExp(...)` churn). Appended struct END.

# G1.1 epoch marks: monotonic mark epoch shared by all `*_mark_epoch` tables.
# gc_clear_marks does `gc_epoch += 1` (O(1) un-mark of every slot) instead of
# an O(live) per-cycle bitmap reset. Starts at 1 so the default slot stamp 0
# reads as "unmarked". Appended struct END (struct-field-add rule → scrub).

# G1.3 weak semantics: per-collection scratch. During the main mark, tracing
# a live WeakMap/WeakSet OBJECT records its backing-store index here (and does
# NOT strong-trace its keys/values). Between mark and sweep, gc_collect runs
# the ephemeron fixpoint over gc_scan_weakmaps (trace a value only if its key
# is otherwise marked) then clears entries with dead keys. Reset each cycle.

# G1.4 heap-string / rope GC: parallel to heap_strings. Per slot: the gc_epoch
# it was last marked (0 = unmarked, -1 = DEAD/free). gc_sweep_heap_strings
# frees unmarked flat leaves + rope nodes and recycles the slot via
# free_heap_string_slots (str_heap/str_rope pop it). Interned strings are NOT
# collected (immortal, §5); only ids >= HEAP_STRING_BASE participate.

# ── Object side-tables (docs/OBJECT_FOOTPRINT_PLAN.md) — sparse, keyed by
# 1-based object index; a row exists ONLY for objects that need the exotic
# state, so ordinary objects carry none of it inline. Appended at struct END
# (ABI). GC dels the row when the owning object slot is swept/reused.
# Phase 1: Proxy internal slots
# Phase 1: mapped-arguments aliasing

# ── Dispatch-loop safepoint request (VM_REARCH_PLAN V0.4) ────────────────
# True whenever gc_pending or pending_exit is: the interpreter tests this
# one byte per dispatch instead of both flags. Set it through
# realm_request_gc / realm_request_exit; a stale True is harmless (the
# loop's slow path recomputes it), a missing one stalls GC or exit.
# Appended at struct END (ABI).
"""Ask the dispatch loop to run a collection at its next safepoint."""
def:pub realm_request_gc(realm: Realm) {
    realm.gc_pending = True;
    realm.safepoint_req = True;
}

"""Ask every dispatch loop to stop (process.exit). The caller sets
pending_exit_code when it has one."""
def:pub realm_request_exit(realm: Realm) {
    realm.pending_exit = True;
    realm.safepoint_req = True;
}

"""G0.4 — real allocation accounting. Call at each genuine cell-allocation site
(objects, closures, generators, maps, sets, heap-strings) — NOT once per opcode.
Bumps the allocation counter and, once it reaches the adaptive threshold,
requests a collection via `gc_pending`. The VM loop-top safepoint (where the
full root set — operand stack + frame locals — is assemblable) services the
flag; the interpreter loop then only branches on `safepoint_req` (one
predictable branch per dispatch instead of a counter increment + two compares). No-op when
GC is disabled, so it is inert on the default (no-`--gc`) path."""
def:pub gc_note_alloc(realm: Realm) -> None {
    if not realm.gc_enabled {
        return;
    }
    realm.gc_alloc_count = realm.gc_alloc_count + 1;
    if realm.gc_alloc_count >= realm.gc_threshold {
        realm_request_gc(realm);
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# Factory
# ══════════════════════════════════════════════════════════════════════════════

"""Allocate and fully initialise a fresh, empty Realm.
   Multiple calls return independent objects — no shared state."""
def:pub realm_new -> Realm {
    r: Realm = Realm();

    # String interning
    r.intern_by_str = {};
    r.intern_by_id = {};
    r.intern_next_id = 0;
    r.intern_seeded = False;
    r.heap_strings = [];
    r.rope_left = [];
    r.rope_right = [];
    r.rope_len = [];
    r.intern_ascii = {};
    r.heap_ascii = [];

    # Symbol table
    r.symbols = [];
    r.symbol_registry = {};
    r.symbol_seeded = False;

    # GC control
    r.gc_alloc_count = 0;
    r.gc_threshold = _GC_MIN_THRESHOLD;
    r.gc_enabled = _GC_DEFAULT_ENABLED;  # on by default; --nogc turns it off
    r.gc_in_progress = False;
    r.gc_pending = False;
    r.safepoint_req = False;
    r.weak_refs = {};
    r.finalization_queue = [];
    r.gc_temp_roots = [];

    # GC free-lists (A2.4)
    r.free_object_slots = [];
    r.free_closure_slots = [];
    r.free_generator_slots = [];
    r.free_map_slots = [];  # G0.5
    r.free_set_slots = [];  # G0.5
    r.free_regexp_slots = [];  # G0.5
    r.import_meta_cache = {};

    # Typed cell tables
    r.objects = [];
    r.proxy_slots = {};  # object side-tables (Phase 1)
    r.args_slots = {};
    r.closures = [];
    r.functions = [];
    r.builtins = [];
    r.natives = [];
    r.maps = [];
    r.sets = [];
    r.generators = [];
    r.regexps = [];
    r.timers = [];

    # GC mark epochs (A2.2/A2.2b; G1.1) — parallel to cell tables; 0 = unmarked
    r.objects_mark_epoch = [];
    r.closures_mark_epoch = [];
    r.functions_mark_epoch = [];
    r.builtins_mark_epoch = [];
    r.natives_mark_epoch = [];
    r.maps_mark_epoch = [];
    r.sets_mark_epoch = [];
    r.generators_mark_epoch = [];
    r.regexps_mark_epoch = [];
    r.timers_mark_epoch = [];
    r.gc_epoch = 1;  # G1.1: first live epoch (0 = never-marked stamp)
    r.gc_scan_weakmaps = [];  # G1.3: live weakmap store indices (per cycle)
    r.gc_scan_weaksets = [];  # G1.3: live weakset store indices (per cycle)
    r.heap_strings_mark_epoch = [];  # G1.4: heap-string mark epochs (0=unmarked,-1=dead)
    r.free_heap_string_slots = [];  # G1.4: recycled heap-string slots

    # VM execution state
    r.global_this = 0;  # JS_UNDEFINED — populated by global_context_create
    r.uncaught_exceptions = [];

    # Microtask / next-tick queues
    r.microtask_fns = [];
    r.microtask_args = [];
    r.next_tick_fns = [];
    r.next_tick_args = [];

    # Promise reaction queues
    r.react_on_f = [];
    r.react_on_r = [];
    r.react_states = [];
    r.react_vals = [];
    r.react_next_p = [];

    # Timer state
    r.timer_next_id = 1;
    r.timer_loop_ptr = 0;
    r.timer_async_ptr = 0;
    r.fired_fns = [];
    r.fired_args = [];

    # Singletons (opaque int handles)
    r.el_handle = 0;
    r.vm_handle = 0;

    # Interrupt / limits
    r.stack_limit = 1024;
    r.heap_limit_bytes = 0;
    r.interrupt_flag = False;

    # Pending process.exit() request
    r.pending_exit = False;
    r.pending_exit_code = 0;

    # Cached canonical intrinsics
    r.array_values_fn = 0;

    # Tagged-template object cache
    r.template_cache = {};

    # ECMAScript Realm Record (cross-realm / $262.createRealm)
    r.realm_id = 0;
    r.intrinsics = RealmIntrinsics();

    return r;
}

# ══════════════════════════════════════════════════════════════════════════════
# Realm registry (GetFunctionRealm / $262.createRealm)
# ══════════════════════════════════════════════════════════════════════════════

glob _REALM_REGISTRY: dict[int, Realm] = {},
     _NEXT_REALM_ID: int = 1;

"""Assign a unique realm_id and register `r`. Returns the id."""
def:pub realm_register(r: Realm) -> int {
    rid: int = _NEXT_REALM_ID;
    _NEXT_REALM_ID = _NEXT_REALM_ID + 1;
    r.realm_id = rid;
    _REALM_REGISTRY[rid] = r;
    return rid;
}

"""Lookup a registered realm by id. Returns realm_id=0 sentinel if missing."""
def:pub realm_lookup(id: int) -> Realm {
    if id in _REALM_REGISTRY {
        return _REALM_REGISTRY[id];
    }
    sentinel: Realm = Realm();
    return sentinel;
}

"""True if `id` refers to a registered realm."""
def:pub realm_is_registered(id: int) -> bool {
    return id in _REALM_REGISTRY;
}
