"""
runtime/gc.na.jac — Mark-and-sweep GC over Realm cell tables (Phase A2.4).

Public API
──────────
  gc_trace(realm, v)            — mark v reachable; recursively trace its children
  gc_mark_roots(realm, extras)  — mark all GC roots + extra JSValues from VM stack
  gc_sweep_objects(realm)       — tombstone unreachable object slots; return freed count
  gc_sweep_closures(realm)      — tombstone unreachable closure slots; return freed count
  gc_collect(realm, extras)     — full cycle: roots → sweep → clear → return freed

Sweep strategy: Option-B tombstone + free-list.
  Dead slots get cell_flags = CELL_FLAG_DEAD; the 1-based index is pushed
  onto realm.free_object_slots (or free_closure_slots) so _obj_alloc /
  js_function_create_src can reuse them next allocation.

Index conventions (mirrors gc_mark.na.jac):
  objects  — 1-based external index (bitmap position = idx-1).
  closures — 0-based.

Phase: A2.4
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_is_cell,
    jsv_cell_kind,
    jsv_to_table_id,
    jsv_is_int32,
    jsv_to_int32,
    js_undefined,
    jsv_from_object_id,
    jsv_from_cell_kind,
    jsv_from_string_id,
    jsv_is_object_cell,
    jsv_is_string_cell,
    JS_CELL_KIND_OBJECT,
    JS_CELL_KIND_NATIVE,
    JS_CELL_KIND_HTMLDDA,
    JS_CELL_KIND_STRING,
    JS_CELL_KIND_SYMBOL
}
import from engine.src.runtime.realm { Realm, gc_mark_byte }
import from engine.src.runtime.jscell {
    CELL_KIND_OBJECT,
    CELL_KIND_CLOSURE,
    CELL_KIND_FUNCTION,
    CELL_KIND_BUILTIN,
    CELL_KIND_NATIVE,
    CELL_KIND_MAP,
    CELL_KIND_SET,
    CELL_KIND_GENERATOR,
    CELL_KIND_REGEXP,
    CELL_KIND_TIMER,
    CELL_FLAG_DEAD,
    FLAG_IS_PROTO,
    FLAG_OLD,
    FLAG_REMEMBERED
}
import from engine.src.runtime.gc_barrier {
    gc_gen_on,
    gc_rem_objs,
    gc_rem_vals,
    gc_barrier_reset
}
import from engine.src.runtime.gc_mark { gc_mark, gc_is_marked, gc_clear_marks }
import from engine.src.runtime.jsobject {
    js_object_gc_children,
    js_object_gc_push_children,
    js_object_get
}
import from engine.src.runtime.encoding { FN_BUILTIN_BASE, FN_NATIVE_BASE }
import from engine.src.builtins.markers {
    _KEY_IS_MAP,
    _KEY_IS_SET,
    _KEY_IS_WEAKMAP,
    _KEY_IS_WEAKSET,
    _KEY_IS_REGEXP_MARK,
    _KEY_IS_GEN_MARK,
    _KEY_GEN_IDX_MARK
}
import from engine.src.ffi.libpcre2 { pcre2_code_free_8 }  # G0.5: free swept regexp C-heap
import from engine.src.builtins.map_type { MAP_NO_VALS, MAP_NO_INDEX }
import from engine.src.builtins.set_type { SET_NO_VALS, SET_NO_INDEX }
import from engine.src.builtins.generator_type { JSGeneratorState }
import from engine.src.runtime.binary_state {
    BINARY_KIND_ARRAY_BUFFER,
    BINARY_KIND_TYPED_ARRAY,
    BINARY_KIND_DATA_VIEW,
    binary_store_ptr_for_slot,
    binary_view_buffer_id
}
import from napi.src.napi_binary { napi_binary_on_arraybuffer_swept }
import from engine.src.runtime.jsstring {
    str_intern,
    str_from_id,
    HEAP_STRING_BASE,
    gc_str_bytes_reset
}
import from engine.src.runtime.shape { shape_keys, shape_key_count, shape_slot_count, shape_mem_stats, shape_deepest_leaves }
import from engine.src.runtime.jsobj_type {
    JSObject,
    MAP_MODE_DICT,
    ELEMS_NONE,
    ArgsState,
    ProxyState,
    proto_epoch_bump,
    proto_epoch_bump_gc,
    BRAND_MAP,
    BRAND_SET,
    BRAND_WEAKMAP,
    BRAND_WEAKSET,
    BRAND_GENERATOR,
    BRAND_REGEXP
}
import from engine.src.ffi.libc { write, getenv, abort }
import from engine.src.ffi.libuv { uv_hrtime }
import from engine.src.runtime.mem { read_byte, write_byte }
# Pin registry lives in its own leaf module so any module can pin glob-held
# singletons without an import cycle through this file.
import from engine.src.runtime.gc_pin {
    gc_pinned_list,
    gc_pinned_live_lists,
    gc_await_roots_map
}

# ── Diagnostic counters ───────────────────────────────────────────────────────
glob:pub gc_total_cycles: int = 0,
     gc_total_freed: int = 0,
     gc_total_ns: int = 0;  # total full collections run since startup

# total cells reclaimed across all cycles
# TEMP GC-sweep diagnostic (env JAC_GC_TRACE=1): per-collection print of the
# object-array span the sweep walks vs. the live count, plus a running total of
# slots swept. Latched: -1 unknown, 0 off, 1 on. Strip once the sweep cost is
# characterised.
glob _GC_TRACE: int = -1,
     _GC_TRACE_SWEPT: int = 0;

# cumulative object-slots walked by gc_sweep_objects
"""Return [cycles, freed] diagnostic tuple."""
def:pub gc_stats -> list[int] {
    out: list[int] = [];
    out.append(gc_total_cycles);
    out.append(gc_total_freed);
    return out;
}

# ── Monitor (bracketed collection window) ─────────────────────────────────────
glob:pub gc_monitor_active: bool = False;
glob gc_monitor_start_cycles: int = 0,
     gc_monitor_start_freed: int = 0;

glob:pub gc_monitor_cycles: int = 0,
     gc_monitor_freed: int = 0;  # cycles fired since startMonitor()

# cells freed since startMonitor()
"""Begin a monitoring window.  Resets the delta counters."""
def:pub gc_start_monitor {
    gc_monitor_active = True;
    gc_monitor_start_cycles = gc_total_cycles;
    gc_monitor_start_freed = gc_total_freed;
    gc_monitor_cycles = 0;
    gc_monitor_freed = 0;
}

"""Wall time spent in collections so far, in ns."""
def:pub gc_time_ns -> int {
    return gc_total_ns;
}

"""End the monitoring window and snapshot the deltas."""
def:pub gc_stop_monitor {
    if gc_monitor_active {
        gc_monitor_cycles = gc_total_cycles - gc_monitor_start_cycles;
        gc_monitor_freed = gc_total_freed - gc_monitor_start_freed;
        gc_monitor_active = False;
    }
}

"""Return live monitor deltas (works during an active window)."""
def:pub gc_live_monitor_stats -> list[int] {
    out: list[int] = [];
    out.append(gc_total_cycles - gc_monitor_start_cycles);
    out.append(gc_total_freed - gc_monitor_start_freed);
    return out;
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_trace — recursive mark + child traversal
# ─────────────────────────────────────────────────────────────────────────────

# gc_trace's worklist, empty between calls: one list for every root (a list
# per call was two allocations per root value).
glob _GC_WORK: list[JSValue] = [];
# This collection's mode: generational on (cells marked get FLAG_OLD), and
# whether it is a verification pass (JAC_GC_VERIFY) — references to dead
# cells are recorded in _GC_VERIFY_BAD instead of being skipped.
glob _GC_GEN_CYCLE: bool = False,
     _GC_VERIFY: int = -1,
     _GC_VERIFYING: bool = False,
     _GC_VERIFY_BAD: list[JSValue] = [];

"""Mark v reachable and recursively trace all JSValues it references.

Handles cycle detection: if the mark bit is already set the function returns
immediately without re-traversing.  Unknown / non-cell JSValues are silently
skipped (undefined, null, bool, int32, float64).
"""
def:pub gc_trace(realm: Realm, v: JSValue) {
    # G0.3: iterative mark via an explicit worklist, NOT native recursion.
    # A deep object graph / prototype chain / flattened-rope tree would blow
    # the C stack under the old recursive gc_trace; a heap-backed worklist has
    # no such bound. Cycle safety is unchanged: a cell is marked when popped,
    # and gc_is_marked short-circuits any later pop of the same cell, so cyclic
    # graphs terminate. A cell may be pushed more than once (referenced by
    # several parents) — harmless; the second pop is a marked no-op.
    if not jsv_is_cell(v) {
        return;
    }
    # The shared worklist is empty on entry and on return (a nested call
    # would drain the caller's pending cells too — they are traced either way).
    work: list[JSValue] = _GC_WORK;
    work.append(v);
    _gc_drain(realm, work);
}

"""Trace everything pushed on `work` (gc_trace's loop)."""
def _gc_drain(realm: Realm, work: list[JSValue]) -> None {
    while len(work) > 0 {
        gc_wtop: int = len(work) - 1;
        gc_cur: JSValue = work[gc_wtop];
        del work[gc_wtop];
        _gc_trace_one(realm, gc_cur, work);
    }
}

"""Mark one popped cell and push its direct children onto `work`.

This is the former recursive gc_trace body with every `gc_trace(realm, X)`
recursive call replaced by `work.append(X)` — identical traversal, no native
recursion. All the marked/dead/bounds checks stay at entry (mark-on-pop), so
pushing an already-marked or non-cell value is a cheap no-op here.
"""
def _gc_trace_one(realm: Realm, v: JSValue, work: list[JSValue]) -> None {
    if not jsv_is_cell(v) {
        return;
    }
    kind: int = jsv_cell_kind(v);

    if kind == JS_CELL_KIND_OBJECT or kind == JS_CELL_KIND_HTMLDDA {
        idx: int = jsv_to_table_id(v);  # 1-based
        if idx <= 0 or idx > len(realm.objects) {
            return;
        }
        # gc_is_marked + gc_mark on the epoch row, read once. A row still 0 was
        # allocated since the last cycle: record it, the sweep trims the
        # buffers of these first-time survivors only.
        gc_mp: int = realm.objmark_ptr;
        gc_eb: int = gc_mark_byte(realm);
        if idx > realm.objmark_len {
            return;
        }
        gc_old: int = read_byte(gc_mp, idx - 1);
        if gc_old == gc_eb {
            return;
        }  # cycle guard
        if gc_old == 255 {
            # a dead row the sweep parked: a live reference to it is a
            # missing write barrier (verification) — else skipped
            if _GC_VERIFYING {
                _GC_VERIFY_BAD.append(v);
            }
            return;
        }
        write_byte(gc_mp, idx - 1, gc_eb);
        if gc_old == 0 {
            realm.gc_young_objs.append(idx);
        }
        _gc_trace_obj(realm, idx, work, gc_mp, gc_eb);
    } elif kind == JS_CELL_KIND_NATIVE {
        table_id: int = jsv_to_table_id(v);
        if table_id < FN_BUILTIN_BASE {
            # Closure — 0-based index
            cl_idx: int = table_id;
            if cl_idx < 0 or cl_idx >= len(realm.closures) {
                return;
            }
            if gc_is_marked(realm, CELL_KIND_CLOSURE, cl_idx) {
                return;
            }
            gc_mark(realm, CELL_KIND_CLOSURE, cl_idx);
            gc_cl_cf: int = realm.closures[cl_idx].cell_flags;
            if gc_cl_cf == CELL_FLAG_DEAD {
                if _GC_VERIFYING {
                    _GC_VERIFY_BAD.append(v);
                }
                return;
            }
            if _GC_GEN_CYCLE and (gc_cl_cf & FLAG_OLD) == 0 {
                realm.closures[cl_idx].cell_flags = gc_cl_cf | FLAG_OLD;
            }

            # Trace captured free variables
            for cv in realm.closures[cl_idx].free_vals {
                work.append(cv);
            }
            # Trace ALL JSValue-holding fields. Invariant: this list must stay
            # in sync with vm/closure_type.jac — a new JSValue field on
            # JSClosure that is not traced here gets its referent swept while
            # live (use-after-free).
            work.append(realm.closures[cl_idx].lexical_this);
            work.append(realm.closures[cl_idx].prototype_obj);
            work.append(realm.closures[cl_idx].super_class);
            work.append(realm.closures[cl_idx].fn_props);
            work.append(realm.closures[cl_idx].home_object);
            work.append(realm.closures[cl_idx].object_proto);
            work.append(realm.closures[cl_idx].lexical_new_target);
            work.append(realm.closures[cl_idx].jac_module);
            for cwo in realm.closures[cl_idx].captured_with_objs {
                work.append(cwo);
            }
            # this_binding_cell / class_brand use raw 0 as the "unset" sentinel
            # (not js_undefined); 0 NaN-boxes as string cell id 0, harmless to
            # push (a marked/no-child no-op) but skipped for clarity.
            gc_tbc: JSValue = realm.closures[cl_idx].this_binding_cell;
            if gc_tbc != 0 {
                work.append(gc_tbc);
            }
            gc_cbr: JSValue = realm.closures[cl_idx].class_brand;
            if gc_cbr != 0 {
                work.append(gc_cbr);
            }

            # Also mark the parallel JSFunctionMeta entry (same index)
            if cl_idx < len(realm.functions_mark_epoch) {
                gc_mark(realm, CELL_KIND_FUNCTION, cl_idx);
            }
        } elif table_id < FN_NATIVE_BASE {
            # Builtin — mark only, no JSValue children
            bi_idx: int = table_id - FN_BUILTIN_BASE;
            if bi_idx >= 0 and bi_idx < len(realm.builtins) {
                gc_mark(realm, CELL_KIND_BUILTIN, bi_idx);
            }
        } else {
            # Native registry — mark + trace lazy own-property store (R3).
            na_idx: int = table_id - FN_NATIVE_BASE;
            if na_idx >= 0 and na_idx < len(realm.natives) {
                if gc_is_marked(realm, CELL_KIND_NATIVE, na_idx) {
                    return;
                }
                gc_mark(realm, CELL_KIND_NATIVE, na_idx);
                work.append(realm.natives[na_idx].props);
            }
        }
    } elif kind == JS_CELL_KIND_STRING {
        # G1.4 heap-string / rope marking. Interned strings (id < HEAP_STRING_BASE)
        # are immortal (§5) — no-op. Heap strings (id >= HEAP_STRING_BASE) are
        # collectible: stamp the slot's mark epoch, and if it is a ROPE node
        # (rope_left >= 0) push its two child string ids so they are kept alive
        # too (a lazy SLICE node has only its parent in rope_left; rope_right
        # <= -2 encodes its offset, see jsstring.str_slice_cell). The epoch stamp doubles as the cycle guard (a shared rope child is
        # traced once per cycle). A DEAD slot (mark_epoch == -1) cannot appear
        # here — a dead slot's id is only handed out again by str_heap/str_rope,
        # which re-stamp it live first.
        gc_sid: int = jsv_to_table_id(v);
        if gc_sid >= HEAP_STRING_BASE {
            gc_hidx: int = gc_sid - HEAP_STRING_BASE;
            if gc_hidx >= 0 and gc_hidx < len(realm.heap_strings_mark_epoch) {
                if _GC_VERIFYING and realm.heap_strings_mark_epoch[gc_hidx] == -1 {
                    _GC_VERIFY_BAD.append(v);
                }
                if realm.heap_strings_mark_epoch[gc_hidx] != realm.gc_epoch {
                    realm.heap_strings_mark_epoch[gc_hidx] = realm.gc_epoch;
                    if gc_hidx < len(realm.rope_left)
                        and realm.rope_left[gc_hidx] >= 0 {
                        work.append(jsv_from_string_id(realm.rope_left[gc_hidx]));
                        if realm.rope_right[gc_hidx] >= 0 {
                            work.append(jsv_from_string_id(realm.rope_right[gc_hidx]));
                        }
                    }
                }
            }
        }
    }
    # JS_CELL_KIND_SYMBOL: interned scalar, no children to trace.
}

"""Push the children of object `idx` (marked this cycle) onto `work`:
prototype, slots / elements / dict entries / accessors, a view's buffer, the
Map / Set / WeakMap / WeakSet / RegExp / generator state behind its hidden
marker keys. Generational: the row becomes old (FLAG_OLD) here. Also used
for remembered objects, which a minor collection finds already marked."""
def _gc_trace_obj(
    realm: Realm, idx: int, work: list[JSValue], gc_mp: int, gc_eb: int
) -> None {
    # Check tombstone via int field read (avoids typed-local JSObject issue)
    gc_obj_cf: int = realm.objects[idx - 1].cell_flags;
    if gc_obj_cf == CELL_FLAG_DEAD {
        return;
    }
    if _GC_GEN_CYCLE and (gc_obj_cf & FLAG_OLD) == 0 {
        realm.objects[idx - 1].cell_flags = gc_obj_cf | FLAG_OLD;
    }
    # The marker keys probed below are own properties mirrored in `brand`:
    # skip each prototype-walking probe unless this object carries it.
    gc_brand: int = realm.objects[idx - 1].brand;

    # Follow prototype chain
    gc_proto_idx: int = realm.objects[idx - 1].prototype_idx;
    if gc_proto_idx > 0
        and (
            gc_proto_idx > realm.objmark_len
            or read_byte(gc_mp, gc_proto_idx - 1) != gc_eb
        ) {
        work.append(jsv_from_object_id(gc_proto_idx));
    }
    # Walk all property values + accessor getters/setters via a helper
    # in jsobject.na.jac (same module as JSObject) — the inline pattern
    #   for k in realm.objects[idx-1].entries {
    #       gc_trace(realm, realm.objects[idx-1].entries[k].value);
    #   }
    # exposes a cross-module dict-subscript field-access codegen bug:
    # `realm.objects[idx-1].entries[k].value` evaluates to 0
    # instead of the JSValue field, leaving children unmarked.
    # See: js_engine/issues/cross-module-dict-subscript-field-access-zero/
    js_object_gc_push_children(idx, work);

    # view→buffer strong edge (formerly the inline JSObject.binary_buffer
    # field, now a native TypedArrayData/DataViewData.buffer_id — traced here
    # because jsobject cannot import binary_state; Phase 1).
    gc_bin_kind: int = realm.objects[idx - 1].bkind();
    if gc_bin_kind == BINARY_KIND_TYPED_ARRAY
        or gc_bin_kind == BINARY_KIND_DATA_VIEW {
        gc_buf_id: int = binary_view_buffer_id(
            gc_bin_kind, realm.objects[idx - 1].bslot()
        );
        if gc_buf_id > 0 {
            work.append(jsv_from_object_id(gc_buf_id));
        }
    }

    # Trace Map/Set backing stores referenced by hidden index properties
    obj_v: JSValue = jsv_from_object_id(idx);
    map_idx_v: JSValue = js_undefined();
    if (gc_brand & BRAND_MAP) != 0 {
        map_idx_v = js_object_get(obj_v, _KEY_IS_MAP);
    }
    if jsv_is_int32(map_idx_v) {
        mid: int = jsv_to_int32(map_idx_v);
        if mid >= 0 and mid < len(realm.maps) {
            if not gc_is_marked(realm, CELL_KIND_MAP, mid) {
                gc_mark(realm, CELL_KIND_MAP, mid);
                if _GC_GEN_CYCLE and realm.maps[mid].cell_flags != CELL_FLAG_DEAD {
                    realm.maps[mid].cell_flags = realm.maps[mid].cell_flags | FLAG_OLD;
                }
                # Map entries (deleted keys are the hole — a no-op to
                # trace); keys/vals hold WeakMap entries.
                for me_k in realm.maps[mid].ekeys {
                    work.append(me_k);
                }
                for me_v in realm.maps[mid].evals {
                    work.append(me_v);
                }
                ms_keys: list[JSValue] = realm.maps[mid].keys;
                ms_vals: list[JSValue] = realm.maps[mid].vals;
                for mk in ms_keys {
                    work.append(mk);
                }
                for mv in ms_vals {
                    work.append(mv);
                }
            }
        }
    }
    # WeakMap shares the maps table via _KEY_IS_WEAKMAP. G1.3 weak semantics:
    # keep the backing STORE alive (the WeakMap object is reachable) but do
    # NOT strong-trace its keys/values here — a WeakMap entry keeps its value
    # alive only if the key is otherwise reachable. Record the live store for
    # the post-mark ephemeron fixpoint (gc_collect → _gc_weak_ephemeron).
    wmap_idx_v: JSValue = js_undefined();
    if (gc_brand & BRAND_WEAKMAP) != 0 {
        wmap_idx_v = js_object_get(obj_v, _KEY_IS_WEAKMAP);
    }
    if jsv_is_int32(wmap_idx_v) {
        wmid: int = jsv_to_int32(wmap_idx_v);
        if wmid >= 0 and wmid < len(realm.maps) {
            if not gc_is_marked(realm, CELL_KIND_MAP, wmid) {
                gc_mark(realm, CELL_KIND_MAP, wmid);
                if _GC_GEN_CYCLE and realm.maps[wmid].cell_flags != CELL_FLAG_DEAD {
                    realm.maps[wmid].cell_flags = realm.maps[wmid].cell_flags | FLAG_OLD;
                }
                realm.gc_scan_weakmaps.append(wmid);
            }
        }
    }
    set_idx_v: JSValue = js_undefined();
    if (gc_brand & BRAND_SET) != 0 {
        set_idx_v = js_object_get(obj_v, _KEY_IS_SET);
    }
    if jsv_is_int32(set_idx_v) {
        sid: int = jsv_to_int32(set_idx_v);
        if sid >= 0 and sid < len(realm.sets) {
            if not gc_is_marked(realm, CELL_KIND_SET, sid) {
                gc_mark(realm, CELL_KIND_SET, sid);
                if _GC_GEN_CYCLE and realm.sets[sid].cell_flags != CELL_FLAG_DEAD {
                    realm.sets[sid].cell_flags = realm.sets[sid].cell_flags | FLAG_OLD;
                }
                for se_k in realm.sets[sid].ekeys {
                    work.append(se_k);
                }
                set_items: list[JSValue] = realm.sets[sid].items;
                for sv in set_items {
                    work.append(sv);
                }
            }
        }
    }
    # WeakSet: keep the backing store alive but do NOT strong-trace its items
    # (G1.3). Record it; _gc_weak_clear drops unmarked items post-mark.
    wset_idx_v: JSValue = js_undefined();
    if (gc_brand & BRAND_WEAKSET) != 0 {
        wset_idx_v = js_object_get(obj_v, _KEY_IS_WEAKSET);
    }
    if jsv_is_int32(wset_idx_v) {
        wsid: int = jsv_to_int32(wset_idx_v);
        if wsid >= 0 and wsid < len(realm.sets) {
            if not gc_is_marked(realm, CELL_KIND_SET, wsid) {
                gc_mark(realm, CELL_KIND_SET, wsid);
                if _GC_GEN_CYCLE and realm.sets[wsid].cell_flags != CELL_FLAG_DEAD {
                    realm.sets[wsid].cell_flags = realm.sets[wsid].cell_flags | FLAG_OLD;
                }
                realm.gc_scan_weaksets.append(wsid);
            }
        }
    }
    # G0.5: RegExp compiled-state cell referenced by _KEY_IS_REGEXP. A regexp
    # cell has no JSValue children (pattern/flags/group_names are native
    # strings), so marking it is enough to keep it (and its pcre2_code) live.
    re_idx_v: JSValue = js_undefined();
    if (gc_brand & BRAND_REGEXP) != 0 {
        re_idx_v = js_object_get(obj_v, _KEY_IS_REGEXP_MARK);
    }
    if jsv_is_int32(re_idx_v) {
        rid: int = jsv_to_int32(re_idx_v);
        if rid >= 0 and rid < len(realm.regexps) {
            gc_mark(realm, CELL_KIND_REGEXP, rid);
        }
    }

    # Generator objects wrap a JSGeneratorState in realm.generators via a
    # hidden _KEY_GEN_IDX_MARK property.  Trace the suspended frame so values
    # reachable only through a yield-point local/free_val survive --gc.
    gen_mark_v: JSValue = js_undefined();
    if (gc_brand & BRAND_GENERATOR) != 0 {
        gen_mark_v = js_object_get(obj_v, _KEY_IS_GEN_MARK);
    }
    if jsv_is_int32(gen_mark_v) and jsv_to_int32(gen_mark_v) == 1 {
        gen_idx_v: JSValue = js_object_get(obj_v, _KEY_GEN_IDX_MARK);
        if jsv_is_int32(gen_idx_v) {
            gidx: int = jsv_to_int32(gen_idx_v);
            if gidx >= 0 and gidx < len(realm.generators) {
                if not gc_is_marked(realm, CELL_KIND_GENERATOR, gidx) {
                    gc_mark(realm, CELL_KIND_GENERATOR, gidx);
                    gst: JSGeneratorState = realm.generators[gidx];
                    if gst.cell_flags != CELL_FLAG_DEAD {
                        for glv in gst.locals {
                            work.append(glv);
                        }
                        for gfv in gst.free_vals {
                            work.append(gfv);
                        }
                        for gsv in gst.saved_stack {
                            work.append(gsv);
                        }
                        work.append(gst.this_val);
                        work.append(gst.send_val);
                        work.append(gst.delegate_gen);
                        work.append(gst.async_promise);
                        work.append(gst.super_fn);
                    }
                }
            }
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_mark_roots — seed the mark phase from all known roots
# ─────────────────────────────────────────────────────────────────────────────

"""Root one suspended generator / async frame: trace its locals, free vars, saved
operand stack, this/send/delegate/promise/super, and MARK the state so
gc_sweep_generators cannot reclaim it. No-op for out-of-range / dead / done."""
def _gc_root_gen_state(realm: Realm, gnr: int) -> None {
    if gnr < 0 or gnr >= len(realm.generators) {
        return;
    }
    ags: JSGeneratorState = realm.generators[gnr];
    if ags.cell_flags == CELL_FLAG_DEAD or ags.done {
        return;
    }
    for agl in ags.locals {
        gc_trace(realm, agl);
    }
    for agf in ags.free_vals {
        gc_trace(realm, agf);
    }
    for ags2 in ags.saved_stack {
        gc_trace(realm, ags2);
    }
    gc_trace(realm, ags.this_val);
    gc_trace(realm, ags.send_val);
    gc_trace(realm, ags.delegate_gen);
    gc_trace(realm, ags.async_promise);
    gc_trace(realm, ags.super_fn);
    if not gc_is_marked(realm, CELL_KIND_GENERATOR, gnr) {
        gc_mark(realm, CELL_KIND_GENERATOR, gnr);
    }
}

"""Mark all GC roots reachable from a Realm.

extras — additional JSValues from the VM operand stack and frame locals.
         Pass [] when calling outside a VM context (e.g., from tests).
"""
def:pub gc_mark_roots(realm: Realm, extras: list[JSValue]) {
    # Global object
    gc_trace(realm, realm.global_this);

    # Uncaught exceptions pending re-throw
    for v in realm.uncaught_exceptions {
        gc_trace(realm, v);
    }

    # Microtask queue
    for v in realm.microtask_fns {
        gc_trace(realm, v);
    }
    for lst in realm.microtask_args {
        for v in lst {
            gc_trace(realm, v);
        }
    }

    # process.nextTick queue
    for v in realm.next_tick_fns {
        gc_trace(realm, v);
    }
    for lst in realm.next_tick_args {
        for v in lst {
            gc_trace(realm, v);
        }
    }

    # Promise reaction queues
    for v in realm.react_on_f {
        gc_trace(realm, v);
    }
    for v in realm.react_on_r {
        gc_trace(realm, v);
    }
    for v in realm.react_vals {
        gc_trace(realm, v);
    }
    for v in realm.react_next_p {
        gc_trace(realm, v);
    }

    # Timer callbacks (each timer holds a callable JSValue).
    # G0.5: a cleared timer (clearTimeout/clearInterval, or an already-fired
    # one-shot) must NOT keep its callback — and everything the callback
    # captured — rooted; only pending timers' callbacks are live roots.
    for t in realm.timers {
        if not t.cleared {
            gc_trace(realm, t.callback);
        }
    }

    # Temporary roots: Promises created before run_cl calls in NATIVE_KIND_PROMISE_* handlers.
    # These are push/popped around each run_cl call to prevent GC collecting
    # freshly-created next_p Promises before they are pushed onto the JS stack.
    for v in realm.gc_temp_roots {
        gc_trace(realm, v);
    }

    # VM operand stack + frame locals (provided by the caller)
    for v in extras {
        gc_trace(realm, v);
    }

    # Realm-held caches whose objects may be reachable ONLY through them.
    # import.meta objects: cached per module; module code holds no other ref
    # between accesses — unrooted, --gc swept live import.meta objects and the
    # cache then returned a recycled EMPTY object (vite constants.js died on
    # fileURLToPath(import.meta.url === undefined)).
    for imk in realm.import_meta_cache {
        gc_trace(realm, realm.import_meta_cache[imk]);
    }
    # Template-literal site arrays: spec requires the SAME frozen array per
    # site on every evaluation — a swept+recycled slot breaks identity and
    # corrupts the cached strings.
    for tck in realm.template_cache {
        gc_trace(realm, realm.template_cache[tck]);
    }
    # Timer callbacks that have FIRED and are queued to run (moved out of
    # realm.timers, so the t.callback root above no longer covers them).
    for v in realm.fired_fns {
        gc_trace(realm, v);
    }
    for lst in realm.fired_args {
        for v in lst {
            gc_trace(realm, v);
        }
    }
    # FinalizationRegistry queue entries (callbacks + held values).
    for v in realm.finalization_queue {
        gc_trace(realm, v);
    }
    # Cached Array.prototype.values fn (usually reachable via array_proto,
    # rooted here for safety — it is read directly off the realm).
    gc_trace(realm, realm.array_values_fn);

    # Suspended ASYNC frames. When `await`ing a pending promise, the async
    # function's frame is snapshotted into a JSGeneratorState in
    # realm.generators and referenced only by an INTEGER index inside the
    # promise's async-resume reaction marker — not by any traceable JSValue.
    # So the live suspended state was invisible to the mark; gc_sweep_generators
    # reclaimed it and cleared its `locals` to [], and when the promise settled
    # _resume_async_frame restored an EMPTY locals list → the first STORE_LOCAL
    # aborted with "list assignment index out of range" (vite@6 config load:
    # async `bundleConfigFile` under --gc). A suspended async frame is exactly a
    # non-done, non-dead generator state whose async_promise is a real promise
    # (plain `function*` states leave async_promise = undefined and stay
    # collectible via their generator object as before). Root it and trace the
    # snapshot so the frame survives until it is resumed.
    gnr: int = 0;
    while gnr < len(realm.generators) {
        ags: JSGeneratorState = realm.generators[gnr];
        if ags.cell_flags != CELL_FLAG_DEAD
            and not ags.done
            and jsv_is_object_cell(ags.async_promise) {
            _gc_root_gen_state(realm, gnr);
        }
        gnr = gnr + 1;
    }

    # Explicitly pinned values (module cache exports, global singletons, etc.)
    for v in gc_pinned_list() {
        gc_trace(realm, v);
    }

    # Promises awaited by suspended async frames (see gc_pin.gc_await_root_add):
    # the awaiting frame holds no GC-visible reference to the promise it is
    # blocked on, so root it here until the frame resumes.
    gc_awr: dict[int, JSValue] = gc_await_roots_map();
    for gc_awk in gc_awr {
        gc_trace(realm, gc_awr[gc_awk]);
        # ALSO root the suspended async frame's STATE (keyed by generator index
        # gc_awk). It is referenced only by this integer — invisible to the mark —
        # and a top-level-await frame's async_promise may be undefined, so the
        # generator scan above skips it and gc_sweep_generators empties its locals
        # → resume aborts in load_local/_push with "list index out of range".
        # Repro: esbuild async service, 2nd transform under --gc
        # (esbuild_crash_min.mjs); works without --gc. The await-roots map is the
        # authoritative "currently suspended on await" set (added in _op_await,
        # dropped in _resume_async_frame), so this roots exactly the right frames.
        _gc_root_gen_state(realm, gc_awk);
    }

    # Registered live root lists (glob callback queues — contents churn)
    for rl in gc_pinned_live_lists() {
        for v in rl {
            gc_trace(realm, v);
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_sweep_objects — reclaim unmarked object slots
# ─────────────────────────────────────────────────────────────────────────────

"""Sweep realm.objects; tombstone unreachable slots; push freed indices onto
the free-list so _obj_alloc can reuse them.

Returns the number of slots freed this cycle."""
def:pub gc_sweep_objects(realm: Realm) -> int {
    freed: int = 0;
    i: int = 0;
    n: int = len(realm.objects);
    sw_mp: int = realm.objmark_ptr;
    sw_epoch: int = gc_mark_byte(realm);
    # ArrayBuffers dying this cycle (rows still unmarked): an external one's
    # addon finalizer fires now, as the eager sweep did for every dead row.
    if len(realm.gc_ab_rows) > 0 {
        _gc_sweep_ab_rows(realm, sw_mp, n, sw_epoch);
    }
    while i < n {
        # Decided from the epoch row alone for a marked (live) row and a -1 row
        # (parked dead by an earlier sweep): reading the object itself cost a
        # cache miss per row, millions of rows per cycle in a big heap.
        sw_m: int = read_byte(sw_mp, i);
        if sw_m == sw_epoch or sw_m == 255 {
            i += 1;
            continue;
        }
        # Dead: park the row. Its payload (slots, elements, property maps) is
        # released by _obj_alloc when it reuses the row — reading every dead
        # object here, millions per cycle, was most of the sweep.
        write_byte(sw_mp, i, 255);  # _obj_alloc stamps 0 again when it reuses the row
        realm.free_object_slots.append(i + 1);  # push 1-based index
        freed += 1;
        i += 1;
    }
    # Give back the slack in the slot / element buffers of the objects that
    # survived their first collection: objects are mostly built up while
    # young, and trimming every live object each cycle read each one.
    for sw_y in realm.gc_young_objs {
        if read_byte(sw_mp, sw_y - 1) == sw_epoch {
            realm.objects[sw_y - 1].strim();
            realm.objects[sw_y - 1].etrim();
        }
    }
    realm.gc_young_objs = [];
    # Side-table rows (Phase 1) of the objects swept above are pruned in ONE
    # pass per table, never with a per-row `del` inside the loop: a jac `del
    # d[k]` removes k from the dict's insertion-ordered key list by linear scan
    # + memmove, so deleting the row of every dead object made a sweep O(n²) in
    # the number of dying `arguments` objects — a react-dom transform put 21 of
    # 30 profile samples on that scan, with the build stuck ~83% in sweep.
    if len(realm.args_slots) > 0 {
        _gc_prune_args_rows(realm);
    }
    if len(realm.proxy_slots) > 0 {
        _gc_prune_proxy_rows(realm);
    }
    return freed;
}

"""The ArrayBuffer rows (js_object_note_array_buffer) unmarked this cycle:
fire the NAPI external-buffer finalizer of each and forget the row; a row
since reused by a non-ArrayBuffer is forgotten too."""
def _gc_sweep_ab_rows(realm: Realm, mp: int, n: int, epoch: int) {
    ab_kept: dict[int, bool] = {};
    for ab_id in realm.gc_ab_rows {
        if ab_id <= 0 or ab_id > n or read_byte(mp, ab_id - 1) == 255 {
            continue;
        }
        if realm.objects[ab_id - 1].bkind() != BINARY_KIND_ARRAY_BUFFER {
            continue;
        }
        if read_byte(mp, ab_id - 1) == epoch {
            ab_kept[ab_id] = True;
            continue;
        }
        napi_binary_on_arraybuffer_swept(
            binary_store_ptr_for_slot(realm.objects[ab_id - 1].bslot())
        );
    }
    realm.gc_ab_rows = ab_kept;
}

"""Drop mapped-arguments side-table rows whose owner slot is dead. Rebuilds
the table (O(rows)) instead of deleting rows one by one (O(rows) each)."""
def _gc_prune_args_rows(realm: Realm) {
    kept: dict[int, ArgsState] = {};
    for ak in realm.args_slots {
        if read_byte(realm.objmark_ptr, ak - 1) != 255 {
            kept[ak] = realm.args_slots[ak];
        }
    }
    realm.args_slots = kept;
}

"""Drop Proxy side-table rows whose owner slot is dead (see _gc_prune_args_rows)."""
def _gc_prune_proxy_rows(realm: Realm) {
    kept: dict[int, ProxyState] = {};
    for pk in realm.proxy_slots {
        if read_byte(realm.objmark_ptr, pk - 1) != 255 {
            kept[pk] = realm.proxy_slots[pk];
        }
    }
    realm.proxy_slots = kept;
}

"""Sweep unmarked Map backing-store slots."""
def:pub gc_sweep_maps(realm: Realm) -> int {
    freed: int = 0;
    i: int = 0;
    n: int = len(realm.maps);
    mp_marks: list[int] = realm.maps_mark_epoch;
    while len(mp_marks) < n {
        mp_marks.append(0);
    }
    mp_epoch: int = realm.gc_epoch;
    while i < n {
        # Live and parked-dead (-1) rows are decided from the epoch row, as in
        # gc_sweep_objects; both reuse sites stamp the row 0 again.
        mp_m: int = mp_marks[i];
        if mp_m == mp_epoch or mp_m == -1 {
            i += 1;
            continue;
        }
        mp_marks[i] = -1;
        # G0.5: only sweep a live (non-tombstoned) unmarked slot ONCE — otherwise
        # a swept-but-not-yet-reused slot would be re-pushed every cycle,
        # duplicating it in free_map_slots (mirrors gc_sweep_objects).
        if realm.maps[i].cell_flags != CELL_FLAG_DEAD {
            realm.maps[i].ekeys = MAP_NO_VALS;
            realm.maps[i].evals = MAP_NO_VALS;
            realm.maps[i].key_index = MAP_NO_INDEX;
            realm.maps[i].keys = MAP_NO_VALS;
            realm.maps[i].vals = MAP_NO_VALS;
            realm.maps[i].owned = False;
            realm.maps[i].head = -1;
            realm.maps[i].live_count = 0;
            realm.maps[i].cell_flags = CELL_FLAG_DEAD;  # tombstone
            realm.free_map_slots.append(i);  # G0.5: reusable slot
            freed += 1;
        }
        i += 1;
    }
    return freed;
}

"""Sweep unmarked Set backing-store slots."""
def:pub gc_sweep_sets(realm: Realm) -> int {
    freed: int = 0;
    i: int = 0;
    n: int = len(realm.sets);
    while i < n {
        # G0.5: sweep each live unmarked slot once, then tombstone (see gc_sweep_maps).
        if realm.sets[i].cell_flags != CELL_FLAG_DEAD {
            if not gc_is_marked(realm, CELL_KIND_SET, i) {
                realm.sets[i].ekeys = SET_NO_VALS;
                realm.sets[i].key_index = SET_NO_INDEX;
                realm.sets[i].items = SET_NO_VALS;
                realm.sets[i].owned = False;
                realm.sets[i].head = -1;
                realm.sets[i].live_count = 0;
                realm.sets[i].cell_flags = CELL_FLAG_DEAD;  # tombstone
                realm.free_set_slots.append(i);  # G0.5: reusable slot
                freed += 1;
            }
        }
        i += 1;
    }
    return freed;
}

"""A minor collection's closure / Map / Set sweeps: only the slots created
since the last collection can be unreached — the same per-slot decision as
gc_sweep_closures / gc_sweep_maps / gc_sweep_sets, over the young lists."""
def _gc_sweep_young_tables(realm: Realm) -> int {
    yt_freed: int = 0;
    yt_ep: int = realm.gc_epoch;
    for yt_c in realm.gc_young_closures {
        if yt_c >= 0 and yt_c < len(realm.closures) and yt_c < len(realm.closures_mark_epoch) {
            yt_cm: int = realm.closures_mark_epoch[yt_c];
            if yt_cm != yt_ep and yt_cm != -1 {
                realm.closures_mark_epoch[yt_c] = -1;
                if realm.closures[yt_c].cell_flags != CELL_FLAG_DEAD {
                    realm.closures[yt_c].cell_flags = CELL_FLAG_DEAD;
                    realm.free_closure_slots.append(yt_c);
                    yt_freed += 1;
                }
            }
        }
    }
    for yt_m in realm.gc_young_maps {
        if yt_m >= 0 and yt_m < len(realm.maps) and yt_m < len(realm.maps_mark_epoch) {
            yt_mm: int = realm.maps_mark_epoch[yt_m];
            if yt_mm != yt_ep and yt_mm != -1 {
                realm.maps_mark_epoch[yt_m] = -1;
                if realm.maps[yt_m].cell_flags != CELL_FLAG_DEAD {
                    realm.maps[yt_m].ekeys = MAP_NO_VALS;
                    realm.maps[yt_m].evals = MAP_NO_VALS;
                    realm.maps[yt_m].key_index = MAP_NO_INDEX;
                    realm.maps[yt_m].keys = MAP_NO_VALS;
                    realm.maps[yt_m].vals = MAP_NO_VALS;
                    realm.maps[yt_m].owned = False;
                    realm.maps[yt_m].head = -1;
                    realm.maps[yt_m].live_count = 0;
                    realm.maps[yt_m].cell_flags = CELL_FLAG_DEAD;
                    realm.free_map_slots.append(yt_m);
                    yt_freed += 1;
                }
            }
        }
    }
    for yt_s in realm.gc_young_sets {
        if yt_s >= 0 and yt_s < len(realm.sets) and realm.sets[yt_s].cell_flags != CELL_FLAG_DEAD {
            if not gc_is_marked(realm, CELL_KIND_SET, yt_s) {
                realm.sets[yt_s].ekeys = SET_NO_VALS;
                realm.sets[yt_s].key_index = SET_NO_INDEX;
                realm.sets[yt_s].items = SET_NO_VALS;
                realm.sets[yt_s].owned = False;
                realm.sets[yt_s].head = -1;
                realm.sets[yt_s].live_count = 0;
                realm.sets[yt_s].cell_flags = CELL_FLAG_DEAD;
                realm.free_set_slots.append(yt_s);
                yt_freed += 1;
            }
        }
    }
    return yt_freed;
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_sweep_regexps — reclaim unmarked RegExp compiled-state slots (G0.5)
# ─────────────────────────────────────────────────────────────────────────────

"""Sweep realm.regexps: for each unmarked, live slot, free its pcre2_code C-heap
handle, tombstone the slot (cell_flags = CELL_FLAG_DEAD, skip re-sweep), and push
its index onto free_regexp_slots for reuse by _get_or_compile. `_RE_CACHE` is
self-validating on lookup (it checks cell_flags + pattern), so no cross-module
cache invalidation is needed here. Only regexps referenced by a live RegExp
object (via _KEY_IS_REGEXP, marked during the object trace) survive; transient
internal-match regexps and dead RegExp objects' slots are reclaimed.

Returns the number of slots freed this cycle."""
def:pub gc_sweep_regexps(realm: Realm) -> int {
    freed: int = 0;
    i: int = 0;
    n: int = len(realm.regexps);
    while i < n {
        if realm.regexps[i].cell_flags != CELL_FLAG_DEAD {
            if not gc_is_marked(realm, CELL_KIND_REGEXP, i) {
                if realm.regexps[i].pcre2_code_ptr != 0 {
                    pcre2_code_free_8(realm.regexps[i].pcre2_code_ptr);
                    realm.regexps[i].pcre2_code_ptr = 0;
                }
                realm.regexps[i].cell_flags = CELL_FLAG_DEAD;  # tombstone
                realm.free_regexp_slots.append(i);  # reusable slot
                freed += 1;
            }
        }
        i += 1;
    }
    return freed;
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_sweep_heap_strings — reclaim unmarked heap strings + rope nodes (G1.4)
# ─────────────────────────────────────────────────────────────────────────────

"""Free heap strings (flat leaves AND rope nodes) that were not marked this
cycle, and recycle their slots via free_heap_string_slots (str_heap/str_rope
pop them). Interned strings are not stored here, so they are never touched.

A slot's mark epoch is the sole state: `== gc_epoch` (marked this cycle, keep),
`-1` (already dead/free — skip, no double-free/dup-push), anything else (a stale
epoch → unmarked → dead now). Releasing the `str` (=> "") drops the only heap
reference to the flattened text; rope children are separate slots reclaimed on
their own merits. Runs in the sweep phase (after the mark + weak passes, before
gc_clear_marks bumps the epoch). Returns the number of slots freed."""
def:pub gc_sweep_heap_strings(realm: Realm) -> int {
    freed: int = 0;
    live_bytes: int = 0;
    i: int = 0;
    n: int = len(realm.heap_strings);
    # Safety net: keep the epoch array as long as the table (alloc sites already
    # maintain it in lockstep; a missing slot reads as unmarked here).
    while len(realm.heap_strings_mark_epoch) < n {
        realm.heap_strings_mark_epoch.append(0);
    }
    while i < n {
        hs_me: int = realm.heap_strings_mark_epoch[i];
        if hs_me != -1 {  # not already dead
            if hs_me != realm.gc_epoch {  # unmarked this cycle → reclaim
                realm.heap_strings[i] = "";  # release the flattened text
                realm.rope_left[i] = -1;
                realm.rope_right[i] = -1;
                realm.rope_len[i] = 0;
                realm.heap_ascii[i] = 0;
                realm.heap_strings_mark_epoch[i] = -1;  # dead sentinel
                realm.free_heap_string_slots.append(i);
                freed += 1;
            } elif realm.rope_left[i] < 0 {
                live_bytes = live_bytes + realm.rope_len[i];  # surviving flat leaf
            }
        }
        i += 1;
    }
    # Re-arm the byte-based string trigger from the surviving heap (jsstring.jac
    # _hs_note_bytes): the next collection comes after ~one live-heap's worth
    # of fresh string bytes, floored at 64MB.
    gc_str_bytes_reset(live_bytes, len(realm.objects) - len(realm.free_object_slots));
    return freed;
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_sweep_closures — reclaim unmarked closure slots
# ─────────────────────────────────────────────────────────────────────────────

"""Sweep realm.closures; tombstone unreachable slots; push freed indices onto
the closure free-list.

Returns the number of slots freed this cycle."""
def:pub gc_sweep_closures(realm: Realm) -> int {
    freed: int = 0;
    i: int = 0;
    n: int = len(realm.closures);
    cl_marks: list[int] = realm.closures_mark_epoch;
    while len(cl_marks) < n {
        cl_marks.append(0);
    }
    cl_epoch: int = realm.gc_epoch;
    while i < n {
        # Same as gc_sweep_objects: live and parked-dead (-1) rows are decided
        # from the epoch row without reading the closure; both reuse sites
        # stamp the row 0 again.
        cl_m: int = cl_marks[i];
        if cl_m == cl_epoch or cl_m == -1 {
            i += 1;
            continue;
        }
        cl_marks[i] = -1;
        gc_cl_sw_cf: int = realm.closures[i].cell_flags;
        if gc_cl_sw_cf != CELL_FLAG_DEAD {
            realm.closures[i].cell_flags = CELL_FLAG_DEAD;
            realm.free_closure_slots.append(i);  # 0-based index
            freed += 1;
        }
        i += 1;
    }
    return freed;
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_sweep_generators — reclaim unmarked generator slots
# ─────────────────────────────────────────────────────────────────────────────

"""Sweep realm.generators; tombstone unreachable slots; push freed indices onto
the free-list so js_generator_create can reuse them.

Returns the number of slots freed this cycle."""
def:pub gc_sweep_generators(realm: Realm) -> int {
    freed: int = 0;
    i: int = 0;
    n: int = len(realm.generators);
    while i < n {
        gst_cf: int = realm.generators[i].cell_flags;
        if gst_cf != CELL_FLAG_DEAD {
            if not gc_is_marked(realm, CELL_KIND_GENERATOR, i) {
                # Drop heavyweight references so the state is inert if somehow
                # re-read before the slot is reused.
                empty_v: list[JSValue] = [];
                realm.generators[i].locals = empty_v;
                realm.generators[i].free_vals = [];
                realm.generators[i].saved_stack = [];
                realm.generators[i].cell_flags = CELL_FLAG_DEAD;
                realm.free_generator_slots.append(i);
                freed = freed + 1;
            }
        }
        i = i + 1;
    }
    return freed;
}

# ─────────────────────────────────────────────────────────────────────────────
# G1.3 weak semantics — ephemeron fixpoint + dead-entry clearing
# ─────────────────────────────────────────────────────────────────────────────

"""True if v's cell is marked this cycle, OR v is a value the collector never
reclaims (primitives, interned strings, symbols, builtins/native-registry).
Used by the weak passes to decide key-liveness and whether a value still needs
tracing. Mirrors the kind dispatch in _gc_trace_one for the collectible kinds."""
def _gc_value_marked(realm: Realm, v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return True;
    }
    vk: int = jsv_cell_kind(v);
    if vk == JS_CELL_KIND_OBJECT or vk == JS_CELL_KIND_HTMLDDA {
        oidx: int = jsv_to_table_id(v);
        if oidx <= 0 or oidx > len(realm.objects) {
            return True;
        }
        return gc_is_marked(realm, CELL_KIND_OBJECT, oidx);
    } elif vk == JS_CELL_KIND_NATIVE {
        tid: int = jsv_to_table_id(v);
        if tid < FN_BUILTIN_BASE {
            if tid < 0 or tid >= len(realm.closures) {
                return True;
            }
            return gc_is_marked(realm, CELL_KIND_CLOSURE, tid);
        }
        return True;  # builtins / native-registry — effectively permanent roots
    }
    return True;  # strings / symbols — not collected (see plan §5)
}

"""Ephemeron fixpoint (G1.3): a WeakMap entry (k, v) keeps v alive iff k is
otherwise reachable. Repeatedly scan the live weakmaps recorded during the main
mark; for any entry whose key is marked but whose value is an unmarked cell,
trace the value. Iterate until a full pass marks nothing new — a value can make
another weakmap's key live, and gc_trace may discover further live weakmaps
(extending gc_scan_weakmaps), both of which require another round."""
def _gc_weak_ephemeron(realm: Realm) {
    changed: bool = True;
    while changed {
        changed = False;
        wi: int = 0;
        while wi < len(realm.gc_scan_weakmaps) {
            wmid: int = realm.gc_scan_weakmaps[wi];
            if wmid >= 0 and wmid < len(realm.maps) {
                ki: int = 0;
                kn: int = len(realm.maps[wmid].keys);
                while ki < kn {
                    ek: JSValue = realm.maps[wmid].keys[ki];
                    if _gc_value_marked(realm, ek) {
                        ev: JSValue = realm.maps[wmid].vals[ki];
                        if jsv_is_cell(ev) and not _gc_value_marked(realm, ev) {
                            gc_trace(realm, ev);
                            changed = True;
                        }
                    }
                    ki = ki + 1;
                }
            }
            wi = wi + 1;
        }
    }
}

"""Clear dead weak entries after the ephemeron converges (G1.3): drop WeakMap
entries whose key is unmarked and WeakSet items that are unmarked, BEFORE the
sweep tombstones+recycles those slots (else a reused slot id would resurrect a
stale weak entry — ABA). Rebuilds the parallel keys/vals (weakmap) and items
(weakset) lists, mirroring js_weakmap_delete / js_weakset_delete."""
def _gc_weak_clear(realm: Realm) {
    wi: int = 0;
    while wi < len(realm.gc_scan_weakmaps) {
        wmid: int = realm.gc_scan_weakmaps[wi];
        if wmid >= 0 and wmid < len(realm.maps) {
            nk: list[JSValue] = [];
            nv: list[JSValue] = [];
            ki: int = 0;
            kn: int = len(realm.maps[wmid].keys);
            while ki < kn {
                ek: JSValue = realm.maps[wmid].keys[ki];
                if _gc_value_marked(realm, ek) {
                    nk.append(ek);
                    nv.append(realm.maps[wmid].vals[ki]);
                }
                ki = ki + 1;
            }
            realm.maps[wmid].keys = nk;
            realm.maps[wmid].vals = nv;
        }
        wi = wi + 1;
    }
    si: int = 0;
    while si < len(realm.gc_scan_weaksets) {
        wsid: int = realm.gc_scan_weaksets[si];
        if wsid >= 0 and wsid < len(realm.sets) {
            ni: list[JSValue] = [];
            ii: int = 0;
            inn: int = len(realm.sets[wsid].items);
            while ii < inn {
                it: JSValue = realm.sets[wsid].items[ii];
                if _gc_value_marked(realm, it) {
                    ni.append(it);
                }
                ii = ii + 1;
            }
            realm.sets[wsid].items = ni;
        }
        si = si + 1;
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_collect — full mark-and-sweep cycle
# ─────────────────────────────────────────────────────────────────────────────

"""A minor collection's roots beyond gc_mark_roots: every live generator
state (a handful at a time; mutated on each suspend without a barrier), the
children of the remembered old objects (already marked, so the trace would
stop at them) and of the old mapped `arguments` objects (their parameter
bindings live in the activation's locals list, written without a barrier),
and the values logged by the non-object barriers."""
def _gc_minor_roots(realm: Realm) -> None {
    mr_g: int = 0;
    while mr_g < len(realm.generators) {
        if realm.generators[mr_g].cell_flags != CELL_FLAG_DEAD
            and not realm.generators[mr_g].done {
            _gc_root_gen_state(realm, mr_g);
        }
        mr_g = mr_g + 1;
    }
    mr_mp: int = realm.objmark_ptr;
    mr_eb: int = gc_mark_byte(realm);
    mr_work: list[JSValue] = _GC_WORK;
    for mr_oid in gc_rem_objs() {
        if mr_oid > 0
            and mr_oid <= len(realm.objects)
            and mr_oid <= realm.objmark_len
            and read_byte(mr_mp, mr_oid - 1) == mr_eb {
            _gc_trace_obj(realm, mr_oid, mr_work, mr_mp, mr_eb);
            _gc_drain(realm, mr_work);
        }
    }
    for mr_aid in realm.args_slots {
        if mr_aid > 0
            and mr_aid <= len(realm.objects)
            and mr_aid <= realm.objmark_len
            and read_byte(mr_mp, mr_aid - 1) == mr_eb {
            _gc_trace_obj(realm, mr_aid, mr_work, mr_mp, mr_eb);
            _gc_drain(realm, mr_work);
        }
    }
    for mr_v in gc_rem_vals() {
        gc_trace(realm, mr_v);
    }
}

"""A minor collection's object sweep: only the rows allocated since the last
collection (realm.gc_young_alloc) can be unreached — a 0 mark byte — the
old rows read as marked. Same parking, trimming and side-table pruning as
gc_sweep_objects."""
def gc_sweep_objects_young(realm: Realm) -> int {
    freed: int = 0;
    sw_mp: int = realm.objmark_ptr;
    sw_epoch: int = gc_mark_byte(realm);
    if len(realm.gc_ab_rows) > 0 {
        _gc_sweep_ab_rows(realm, sw_mp, len(realm.objects), sw_epoch);
    }
    for sw_i in realm.gc_young_alloc {
        if sw_i > 0 and sw_i <= realm.objmark_len and read_byte(sw_mp, sw_i - 1) == 0 {
            write_byte(sw_mp, sw_i - 1, 255);
            realm.free_object_slots.append(sw_i);
            freed += 1;
        }
    }
    for sw_y in realm.gc_young_objs {
        if read_byte(sw_mp, sw_y - 1) == sw_epoch {
            realm.objects[sw_y - 1].strim();
            realm.objects[sw_y - 1].etrim();
        }
    }
    realm.gc_young_objs = [];
    if len(realm.args_slots) > 0 {
        _gc_prune_args_rows(realm);
    }
    if len(realm.proxy_slots) > 0 {
        _gc_prune_proxy_rows(realm);
    }
    return freed;
}

"""End of a cycle: un-flag the remembered objects, forget them and the logged
values, and start a new young-allocation list."""
def _gc_barrier_end(realm: Realm) -> None {
    for be_oid in gc_rem_objs() {
        if be_oid > 0 and be_oid <= len(realm.objects) {
            realm.objects[be_oid - 1].cell_flags = realm.objects[be_oid - 1].cell_flags
                & ~FLAG_REMEMBERED;
        }
    }
    gc_barrier_reset();
    realm.gc_young_alloc = [];
    realm.gc_young_closures = [];
    realm.gc_young_maps = [];
    realm.gc_young_sets = [];
}

"""JAC_GC_VERIFY=1: after every minor collection run a full one that records
references to dead cells (a missing write barrier freed a live young cell)."""
def _gc_verify_on -> bool {
    return _gc_verify_level() >= 1;
}

"""JAC_GC_VERIFY level: 0 off; 1 the minor pre-sweep check; 2 also, after
every collection (major ones too), a full re-mark that reports references
to cells already dead — a value that was hidden from an earlier collection
(an unrooted native temporary, a missing barrier) and has resurfaced."""
def _gc_verify_level -> int {
    if _GC_VERIFY < 0 {
        vl_env: str = getenv("JAC_GC_VERIFY");
        if vl_env == None {
            _GC_VERIFY = 0;
        } elif vl_env == "2" {
            _GC_VERIFY = 2;
        } else {
            _GC_VERIFY = 1;
        }
    }
    return _GC_VERIFY;
}

"""Where a verification pass found `bad` referenced (diagnostics): live
objects, every closure field, native props, Map / Set storages, generator
states and the root lists; up to 8 hits."""
def _gc_verify_referrers(realm: Realm, bad: JSValue, extras: list[JSValue]) -> str {
    vr: str = "";
    vr_n: int = 0;
    vr_i: int = 1;
    while vr_i <= len(realm.objects) and vr_n < 8 {
        if read_byte(realm.objmark_ptr, vr_i - 1) == gc_mark_byte(realm) {
            for vr_c in js_object_gc_children(vr_i) {
                if vr_c == bad {
                    vr = vr + " object#" + str(vr_i) + "(flags=" + str(realm.objects[vr_i - 1].cell_flags)
                        + ",brand=" + str(realm.objects[vr_i - 1].brand) + ",class=" + str(realm.objects[vr_i - 1].class_id) + ")";
                    vr_n = vr_n + 1;
                    break;
                }
            }
            if realm.objects[vr_i - 1].prototype_idx > 0
                and jsv_from_object_id(realm.objects[vr_i - 1].prototype_idx) == bad {
                vr = vr + " object#" + str(vr_i) + "(as prototype)";
                vr_n = vr_n + 1;
            }
        }
        vr_i = vr_i + 1;
    }
    vr_ci: int = 0;
    while vr_ci < len(realm.closures) and vr_n < 8 {
        if realm.closures[vr_ci].cell_flags != CELL_FLAG_DEAD {
            vr_f: str = "";
            for vr_fv in realm.closures[vr_ci].free_vals {
                if vr_fv == bad { vr_f = "free_vals"; }
            }
            for vr_cw in realm.closures[vr_ci].captured_with_objs {
                if vr_cw == bad { vr_f = "captured_with_objs"; }
            }
            if realm.closures[vr_ci].lexical_this == bad { vr_f = "lexical_this"; }
            if realm.closures[vr_ci].prototype_obj == bad { vr_f = "prototype_obj"; }
            if realm.closures[vr_ci].super_class == bad { vr_f = "super_class"; }
            if realm.closures[vr_ci].fn_props == bad { vr_f = "fn_props"; }
            if realm.closures[vr_ci].home_object == bad { vr_f = "home_object"; }
            if realm.closures[vr_ci].object_proto == bad { vr_f = "object_proto"; }
            if realm.closures[vr_ci].lexical_new_target == bad { vr_f = "lexical_new_target"; }
            if realm.closures[vr_ci].jac_module == bad { vr_f = "jac_module"; }
            if realm.closures[vr_ci].this_binding_cell == bad { vr_f = "this_binding_cell"; }
            if realm.closures[vr_ci].class_brand == bad { vr_f = "class_brand"; }
            if vr_f != "" {
                vr = vr + " closure#" + str(vr_ci) + "." + vr_f + "(flags=" + str(realm.closures[vr_ci].cell_flags) + ")";
                vr_n = vr_n + 1;
            }
        }
        vr_ci = vr_ci + 1;
    }
    vr_ni: int = 0;
    while vr_ni < len(realm.natives) {
        if realm.natives[vr_ni].props == bad {
            vr = vr + " native#" + str(vr_ni) + ".props";
        }
        vr_ni = vr_ni + 1;
    }
    vr_mi: int = 0;
    while vr_mi < len(realm.maps) {
        if realm.maps[vr_mi].cell_flags != CELL_FLAG_DEAD {
            vr_mh: bool = False;
            for vr_mk in realm.maps[vr_mi].keys { if vr_mk == bad { vr_mh = True; } }
            for vr_mv in realm.maps[vr_mi].vals { if vr_mv == bad { vr_mh = True; } }
            for vr_mk2 in realm.maps[vr_mi].ekeys { if vr_mk2 == bad { vr_mh = True; } }
            for vr_mv2 in realm.maps[vr_mi].evals { if vr_mv2 == bad { vr_mh = True; } }
            if vr_mh {
                vr = vr + " map#" + str(vr_mi) + "(flags=" + str(realm.maps[vr_mi].cell_flags) + ")";
            }
        }
        vr_mi = vr_mi + 1;
    }
    vr_si: int = 0;
    while vr_si < len(realm.sets) {
        if realm.sets[vr_si].cell_flags != CELL_FLAG_DEAD {
            vr_sh: bool = False;
            for vr_sk in realm.sets[vr_si].items { if vr_sk == bad { vr_sh = True; } }
            for vr_sk2 in realm.sets[vr_si].ekeys { if vr_sk2 == bad { vr_sh = True; } }
            if vr_sh {
                vr = vr + " set#" + str(vr_si) + "(flags=" + str(realm.sets[vr_si].cell_flags) + ")";
            }
        }
        vr_si = vr_si + 1;
    }
    vr_gi: int = 0;
    while vr_gi < len(realm.generators) {
        if realm.generators[vr_gi].cell_flags != CELL_FLAG_DEAD {
            vr_gh: bool = False;
            for vr_gl in realm.generators[vr_gi].locals { if vr_gl == bad { vr_gh = True; } }
            for vr_gs in realm.generators[vr_gi].saved_stack { if vr_gs == bad { vr_gh = True; } }
            for vr_gf in realm.generators[vr_gi].free_vals { if vr_gf == bad { vr_gh = True; } }
            if vr_gh {
                vr = vr + " generator#" + str(vr_gi);
            }
        }
        vr_gi = vr_gi + 1;
    }
    vr_ei: int = 0;
    while vr_ei < len(extras) {
        if extras[vr_ei] == bad {
            vr = vr + " ROOT(vm extras #" + str(vr_ei) + " of " + str(len(extras)) + ")";
            break;
        }
        vr_ei = vr_ei + 1;
    }
    return vr;
}

"""Report the dead cells a verification pass reached, with what still
references them, then abort."""
def _gc_verify_report(realm: Realm, extras: list[JSValue]) -> None {
    vr_msg: str = "[GCVERIFY] " + str(len(_GC_VERIFY_BAD))
        + " young cell(s) a minor collection would have freed are reachable (missing write barrier)\n";
    write(2, vr_msg, len(vr_msg));
    vr_k: int = 0;
    for vr_bad in _GC_VERIFY_BAD {
        if vr_k >= 5 {
            break;
        }
        vr_k = vr_k + 1;
        vr_what: str = "";
        if jsv_cell_kind(vr_bad) == JS_CELL_KIND_NATIVE and jsv_to_table_id(vr_bad) < len(realm.closures) {
            vr_what = " fn=" + realm.closures[jsv_to_table_id(vr_bad)].func.name;
        } elif jsv_cell_kind(vr_bad) == JS_CELL_KIND_OBJECT and jsv_to_table_id(vr_bad) <= len(realm.objects) {
            vr_ob: int = jsv_to_table_id(vr_bad) - 1;
            vr_what = " brand=" + str(realm.objects[vr_ob].brand) + " class=" + str(realm.objects[vr_ob].class_id)
                + " slots=" + str(realm.objects[vr_ob].slen()) + " elems=" + str(realm.objects[vr_ob].elen());
        }
        vr_line: str = "  young cell kind=" + str(jsv_cell_kind(vr_bad)) + " id="
            + str(jsv_to_table_id(vr_bad)) + vr_what + "; referenced by:"
            + _gc_verify_referrers(realm, vr_bad, extras) + "\n";
        write(2, vr_line, len(vr_line));
    }
}

"""Run a complete GC cycle:
  1. Mark phase: gc_mark_roots → gc_trace all reachable cells.
  2. G1.3 weak passes: ephemeron fixpoint, then clear dead weak entries.
  3. Sweep phase: tombstone unreachable objects and closures.
  4. Clear all marks for the next cycle (G1.1: bump gc_epoch — O(1)).
  5. Return total number of cells freed.

extras — JSValues from the VM stack / frame locals.  Pass [] in test contexts.

Re-entrancy guard: returns 0 immediately if a collection is already in
progress (prevents recursion if a finalizer allocates).
"""
# TEMP diagnostic (JAC_GC_TRACE=1, printed at select cycles): categorise the
# LIVE object slots to tell legitimate Vite/React state (a few dominant shapes,
# named by their keys) from runtime retention (dict-mode deopt / arguments
# objects). Walks realm.objects once; safe to allocate (called after
# gc_in_progress=False). Strip with the rest of the JAC_GC_TRACE scaffolding.
def _gc_type_breakdown(realm: Realm) {
    total: int = 0;
    bin_ct: int = 0;
    args_ct: int = 0;
    arr_ct: int = 0;
    dict_ct: int = 0;
    shape_ct: int = 0;
    dict_keys_sum: int = 0;
    shape_hist: dict[int, int] = {};
    _bi: int = 0;
    _bn: int = len(realm.objects);
    while _bi < _bn {
        _bo: JSObject = realm.objects[_bi];
        if _bo.cell_flags == CELL_FLAG_DEAD
            or (_bi < realm.objmark_len and read_byte(realm.objmark_ptr, _bi) == 255) {
            _bi = _bi + 1;
            continue;
        }
        total = total + 1;
        if _bo.bkind() != 0 {
            bin_ct = bin_ct + 1;
        } elif _bo.arguments_obj() {
            args_ct = args_ct + 1;
        } elif _bo.elems_kind != ELEMS_NONE {
            arr_ct = arr_ct + 1;
        } elif _bo.mode == MAP_MODE_DICT {
            dict_ct = dict_ct + 1;
            dict_keys_sum = dict_keys_sum + len(_bo.ko_ro());
        } else {
            shape_ct = shape_ct + 1;
            _sid: int = _bo.shape_id;
            if _sid in shape_hist {
                shape_hist[_sid] = shape_hist[_sid] + 1;
            } else {
                shape_hist[_sid] = 1;
            }
        }
        _bi = _bi + 1;
    }
    _davg: int = 0;
    if dict_ct > 0 {
        _davg = dict_keys_sum // dict_ct;
    }
    _hdr: str = "[GCBREAK] cyc="
        + str(gc_total_cycles)
        + " live="
        + str(total)
        + " binary="
        + str(bin_ct)
        + " arguments="
        + str(args_ct)
        + " array="
        + str(arr_ct)
        + " dictMode="
        + str(dict_ct)
        + "(avgKeys="
        + str(_davg)
        + ")"
        + " shapeMode="
        + str(shape_ct)
        + "\n";
    write(2, _hdr, len(_hdr));
    # Top-12 shapes by live count, with resolved key names (a shape's key-set
    # self-classifies: {type,props,key,ref}=React element, hidden marker keys
    # =promise/array, etc.).
    _picked: dict[int, int] = {};
    _shown: int = 0;
    while _shown < 12 {
        _best_sid: int = -1;
        _best_ct: int = -1;
        for _s2 in shape_hist {
            if _s2 in _picked {
                continue;
            }
            if shape_hist[_s2] > _best_ct {
                _best_ct = shape_hist[_s2];
                _best_sid = _s2;
            }
        }
        if _best_sid < 0 {
            break;
        }
        _picked[_best_sid] = 1;
        _keys: list[int] = shape_keys(_best_sid);
        _keys_n: int = shape_key_count(_best_sid);
        _kstr: str = "";
        _ki: int = 0;
        while _ki < _keys_n and _ki < 8 {
            if _ki > 0 {
                _kstr = _kstr + ",";
            }
            _kn: str = str_from_id(_keys[_ki]);
            if len(_kn) == 0 {
                _kn = "#" + str(_keys[_ki]);
            }
            _kstr = _kstr + _kn;
            _ki = _ki + 1;
        }
        if _keys_n > 8 {
            _kstr = _kstr + ",+" + str(_keys_n - 8);
        }
        _line: str = "  shape#"
            + str(_best_sid)
            + " x"
            + str(_best_ct)
            + " nkeys="
            + str(_keys_n)
            + " {"
            + _kstr
            + "}\n";
        write(2, _line, len(_line));
        _shown = _shown + 1;
    }
    _deep_live: int = 0;
    for _s3 in shape_hist {
        if shape_slot_count(_s3) >= 128 { _deep_live = _deep_live + shape_hist[_s3]; }
    }
    _ss: list[int] = shape_mem_stats();
    _sl: str = "[GCSHAPE] shapes=" + str(_ss[0]) + " chainIdx=" + str(_ss[1])
        + " idxEntries=" + str(_ss[2]) + " keysCache=" + str(_ss[3])
        + " edges=" + str(_ss[4]) + " leaves>=128slots=" + str(_ss[5])
        + " liveObjs>=128slots=" + str(_deep_live) + "\n";
    write(2, _sl, len(_sl));
    for _lsid in shape_deepest_leaves(12) {
        _lk: list[int] = shape_keys(_lsid);
        _lk_n: int = shape_key_count(_lsid);
        _lks: str = "";
        _lj: int = 0;
        while _lj < _lk_n {
            if _lj < 6 or _lj >= _lk_n - 2 {
                _lkn: str = str_from_id(_lk[_lj]);
                if len(_lkn) == 0 { _lkn = "#" + str(_lk[_lj]); }
                if len(_lkn) > 24 { _lkn = _lkn[0:24]; }
                _lks = _lks + _lkn + ",";
            } elif _lj == 6 {
                _lks = _lks + "…,";
            }
            _lj = _lj + 1;
        }
        _ll: str = "  leaf#" + str(_lsid) + " slots=" + str(shape_slot_count(_lsid))
            + " live=" + str(shape_hist.get(_lsid, 0)) + " {" + _lks + "}\n";
        write(2, _ll, len(_ll));
    }
}

# TEMP diagnostic (JAC_GC_TRACE=1): break down the LIVE heap-string population
# to find who retains the huge string memory. Reports: live count, total MB,
# rope(unflattened) vs flat, interned-table size, free slots, and a length
# histogram (count + MB per bucket) — many-small (interning/per-char garbage)
# vs few-huge (module sources / MagicString outputs held live). NOTE: per-string
# allocation SITE is not available in-engine (needs the mp2 malloc profiler);
# this names WHAT is retained (size/shape), not WHERE it was allocated.
def _gc_string_breakdown(realm: Realm) {
    _n: int = len(realm.heap_strings);
    if _n > len(realm.heap_strings_mark_epoch) {
        _n = len(realm.heap_strings_mark_epoch);
    }
    if _n > len(realm.rope_len) {
        _n = len(realm.rope_len);
    }
    if _n > len(realm.rope_left) {
        _n = len(realm.rope_left);
    }
    live: int = 0;
    ropes: int = 0;
    flats: int = 0;
    total_chars: int = 0;
    b_ct: list[int] = [0, 0, 0, 0, 0, 0, 0];
    b_by: list[int] = [0, 0, 0, 0, 0, 0, 0];
    _i: int = 0;
    while _i < _n {
        if realm.heap_strings_mark_epoch[_i] == -1 {
            _i = _i + 1;
            continue;
        }
        live = live + 1;
        _ln: int = realm.rope_len[_i];
        total_chars = total_chars + _ln;
        if realm.rope_left[_i] >= 0 {
            ropes = ropes + 1;
        } else {
            flats = flats + 1;
        }
        _b: int = 6;
        if _ln <= 16 {
            _b = 0;
        } elif _ln <= 64 {
            _b = 1;
        } elif _ln <= 256 {
            _b = 2;
        } elif _ln <= 1024 {
            _b = 3;
        } elif _ln <= 16384 {
            _b = 4;
        } elif _ln <= 262144 {
            _b = 5;
        } else {
            _b = 6;
        }
        b_ct[_b] = b_ct[_b] + 1;
        b_by[_b] = b_by[_b] + _ln;
        _i = _i + 1;
    }
    _hdr: str = "[GCSTR] cyc="
        + str(gc_total_cycles)
        + " liveHstr="
        + str(live)
        + " totMB="
        + str(total_chars // 1048576)
        + " ropes="
        + str(ropes)
        + " flats="
        + str(flats)
        + " interned="
        + str(realm.intern_next_id)
        + " freeSlots="
        + str(len(realm.free_heap_string_slots))
        + "\n";
    write(2, _hdr, len(_hdr));
    _labels: list[str] = ["<=16", "<=64", "<=256", "<=1K", "<=16K", "<=256K", ">256K"];
    _bi2: int = 0;
    while _bi2 < 7 {
        if b_ct[_bi2] > 0 {
            _l: str = "  len"
                + _labels[_bi2]
                + ": "
                + str(b_ct[_bi2])
                + " strs, "
                + str(b_by[_bi2] // 1024)
                + "KB\n";
            write(2, _l, len(_l));
        }
        _bi2 = _bi2 + 1;
    }
}

def:pub gc_collect(realm: Realm, extras: list[JSValue]) -> int {
    if realm.gc_in_progress {
        return 0;
    }
    realm.gc_in_progress = True;
    gc_t0: int = uv_hrtime();
    # Generational (docs/GENERATIONAL_GC.md): a minor collection keeps the
    # epoch, so the cells marked by the last collection still read as marked
    # (old) and the trace stops at them; a major one un-marks everything
    # first (the epoch bump that used to end every collection).
    _GC_GEN_CYCLE = gc_gen_on();
    gc_minor: bool = _GC_GEN_CYCLE and not realm.gc_next_major and not _GC_VERIFYING;
    if not gc_minor {
        gc_clear_marks(realm, -1);  # -1 clears ALL tables at once
    }

    # G1.3: reset per-cycle weak-scan scratch before the mark records into it.
    realm.gc_scan_weakmaps = [];
    realm.gc_scan_weaksets = [];

    gc_mark_roots(realm, extras);
    if gc_minor {
        _gc_minor_roots(realm);
        if _gc_verify_on() {
            # JAC_GC_VERIFY: the young cells this minor would free must be
            # unreachable — re-mark everything from the roots (this
            # collection becomes a major) and check.
            vf_objs: list[int] = [];
            vf_mp: int = realm.objmark_ptr;
            for vf_o in realm.gc_young_alloc {
                if vf_o > 0 and vf_o <= realm.objmark_len and read_byte(vf_mp, vf_o - 1) == 0 {
                    vf_objs.append(vf_o);
                }
            }
            vf_cls: list[int] = [];
            for vf_c in realm.gc_young_closures {
                if vf_c >= 0 and vf_c < len(realm.closures_mark_epoch)
                    and realm.closures_mark_epoch[vf_c] != realm.gc_epoch {
                    vf_cls.append(vf_c);
                }
            }
            gc_minor = False;
            gc_clear_marks(realm, -1);
            realm.gc_scan_weakmaps = [];
            realm.gc_scan_weaksets = [];
            gc_mark_roots(realm, extras);
            for vf_o2 in vf_objs {
                if read_byte(realm.objmark_ptr, vf_o2 - 1) == gc_mark_byte(realm) {
                    _GC_VERIFY_BAD.append(jsv_from_object_id(vf_o2));
                }
            }
            for vf_c2 in vf_cls {
                if realm.closures_mark_epoch[vf_c2] == realm.gc_epoch {
                    _GC_VERIFY_BAD.append(jsv_from_cell_kind(vf_c2, JS_CELL_KIND_NATIVE));
                }
            }
            if len(_GC_VERIFY_BAD) > 0 {
                _gc_verify_report(realm, extras);
                abort();
            }
        }
    }

    # G1.3 weak semantics: resolve ephemerons (trace values of live-key weakmap
    # entries to a fixpoint), then drop entries with dead keys / dead weakset
    # items — all BEFORE the sweep reclaims those objects.
    _gc_weak_ephemeron(realm);
    _gc_weak_clear(realm);

    freed: int = 0;
    gc_t_mark: int = uv_hrtime();
    if gc_minor {
        freed = freed + gc_sweep_objects_young(realm);
    } else {
        freed = freed + gc_sweep_objects(realm);
    }
    gc_t_swo: int = uv_hrtime();
    if gc_minor {
        freed = freed + _gc_sweep_young_tables(realm);
    } else {
        freed = freed + gc_sweep_closures(realm);
        freed = freed + gc_sweep_maps(realm);
        freed = freed + gc_sweep_sets(realm);
    }
    freed = freed + gc_sweep_generators(realm);
    freed = freed + gc_sweep_regexps(realm);  # G0.5
    gc_t_swc: int = uv_hrtime();
    freed = freed + gc_sweep_heap_strings(realm);  # G1.4
    gc_t_sws: int = uv_hrtime();

    _gc_barrier_end(realm);
    realm.gc_last_minor = gc_minor;

    realm.gc_in_progress = False;
    gc_total_cycles = gc_total_cycles + 1;
    gc_total_ns = gc_total_ns + (uv_hrtime() - gc_t0);
    gc_total_freed = gc_total_freed + freed;
    # Update live monitor deltas (gc_monitor_cycles/freed computed lazily in gc_live_monitor_stats).

    # TEMP diagnostic (JAC_GC_TRACE=1): characterise the sweep cost.
    if _GC_TRACE != 0 {
        if _GC_TRACE < 0 {
            if getenv("JAC_GC_TRACE") != None {
                _GC_TRACE = 1;
            } else {
                _GC_TRACE = 0;
            }
        }
        if _GC_TRACE == 1 {
            _gc_span: int = len(realm.objects);
            _gc_free: int = len(realm.free_object_slots);
            _GC_TRACE_SWEPT = _GC_TRACE_SWEPT + _gc_span;
            # Heap-string span + total chars (≈bytes for ASCII; rope_len is the
            # per-slot char length, so this is the heap-string/rope memory the
            # io_alloc meter does NOT see — the last unmetered candidate for the
            # 23GB sink).
            _hs_span: int = len(realm.heap_strings);
            _hs_free: int = len(realm.free_heap_string_slots);
            _hs_chars: int = 0;
            _hs_i: int = 0;
            while _hs_i < _hs_span {
                _hs_chars = _hs_chars + realm.rope_len[_hs_i];
                _hs_i = _hs_i + 1;
            }
            _gc_msg: str = "[GCTRACE] cyc="
                + str(gc_total_cycles)
                + (" minor" if gc_minor else " major")
                + " ms="
                + str((uv_hrtime() - gc_t0) // 1000000)
                + " mark="
                + str((gc_t_mark - gc_t0) // 1000000)
                + " swo="
                + str((gc_t_swo - gc_t_mark) // 1000000)
                + " swc="
                + str((gc_t_swc - gc_t_swo) // 1000000)
                + " sws="
                + str((gc_t_sws - gc_t_swc) // 1000000)
                + " objspan="
                + str(_gc_span)
                + " objlive="
                + str(_gc_span - _gc_free)
                + " objfree="
                + str(_gc_free)
                + " hstr="
                + str(_hs_span)
                + " hstrfree="
                + str(_hs_free)
                + " hstrMB="
                + str(_hs_chars // 1048576)
                + " clos="
                + str(len(realm.closures))
                + "/free="
                + str(len(realm.free_closure_slots))
                + " gens="
                + str(len(realm.generators))
                + "/free="
                + str(len(realm.free_generator_slots))
                + " maps="
                + str(len(realm.maps))
                + "/"
                + str(len(realm.free_map_slots))
                + " sets="
                + str(len(realm.sets))
                + "/"
                + str(len(realm.free_set_slots))
                + " interned="
                + str(realm.intern_next_id)
                + " thr="
                + str(realm.gc_threshold)
                + " freed="
                + str(freed)
                + " cumSwept="
                + str(_GC_TRACE_SWEPT)
                + "\n";
            write(2, _gc_msg, len(_gc_msg));
            if gc_total_cycles % 20 == 0 {
                _gc_type_breakdown(realm);
                _gc_string_breakdown(realm);
            }
        }
    }
    if not _GC_VERIFYING and _gc_verify_level() >= 2 {
        _GC_VERIFYING = True;
        _GC_VERIFY_BAD = [];
        realm.gc_next_major = True;
        gc_collect(realm, extras);
        _GC_VERIFYING = False;
        if len(_GC_VERIFY_BAD) > 0 {
            vp_msg: str = "[GCVERIFY] after a " + ("minor" if gc_minor else "major")
                + " collection: references to dead cells follow\n";
            write(2, vp_msg, len(vp_msg));
            _gc_verify_report(realm, extras);
            abort();
        }
    }
    return freed;
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_tick — threshold-based auto-trigger (A2.4b)
# ─────────────────────────────────────────────────────────────────────────────

"""Increment the allocation counter; trigger gc_collect when the threshold
is reached.  Called once per cell allocation in the hot path.

extras — live JSValues from the current call frame (VM stack slice).
"""
def:pub gc_tick(realm: Realm, extras: list[JSValue]) -> None {
    if not realm.gc_enabled {
        return;
    }
    realm.gc_alloc_count = realm.gc_alloc_count + 1;
    if realm.gc_alloc_count >= realm.gc_threshold {
        realm.gc_alloc_count = 0;
        gc_collect(realm, extras);
    }
}
