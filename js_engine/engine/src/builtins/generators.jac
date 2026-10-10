"""
Generator Functions

Implements the suspended-frame generator protocol:
  function* gen() { yield 1; yield 2; }
  const g = gen();
  g.next()   → { value: 1, done: false }
  g.next()   → { value: 2, done: false }
  g.next()   → { value: undefined, done: true }

Design:
  - A generator function, when called, creates a JSGeneratorState and wraps it
    in a plain JSObject with a hidden "_KEY_IS_GEN" marker property.
  - JSGeneratorState stores a snapshot of the full CallFrame state needed to
    resume: locals, free_vals, this_val, the CompiledFunction, and the saved IP.
  - On YIELD, the VM saves the current frame state into the JSGeneratorState and
    returns control to the caller with { value, done: false }.
  - On .next(val), the VM restores the frame and resumes from the saved IP,
    injecting the sent value onto the operand stack.
  - On function exit (RETURN / RETURN_UNDEFINED), the VM produces { value, done: true }.

Bun reference: bun/src/bun.js/VirtualMachine.zig (generator resume)
JSC reference: Source/JavaScriptCore/runtime/JSGenerator.h
ECMAScript spec: §27.5 Generator Objects
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_boolean,
    jsv_is_object_cell,
    jsv_is_int32,
    jsv_to_int32,
    jsv_to_table_id
}
import from engine.src.builtins.generator_type { JSGeneratorState }
import from engine.src.runtime.realm { Realm, gc_note_alloc }
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.wk_keys { WK_VALUE, WK_DONE }
import from engine.src.runtime.jsobject {
    js_object_create,
    js_object_create_null,
    js_object_get,
    js_object_set,
    js_object_has_own,
    js_object_brand,
    js_object_new_shaped2,
    js_object_ic_shape,
    js_object_own_data_slot,
    js_object_ic_hit,
    js_object_get_ordinary_proto
}
import from engine.src.runtime.jsobj_type { BRAND_GENERATOR }
import from engine.src.builtins.markers {
    _KEY_IS_GEN_MARK,
    _KEY_GEN_IDX_MARK,
    _KEY_ASYNC_GEN_MARK
}
import from engine.src.bytecode.op { CompiledFunction }
import from engine.src.runtime.gc_pin { gc_pin_value }

# ══════════════════════════════════════════════════════════════════════════════
# Hidden keys for generator object detection
# ══════════════════════════════════════════════════════════════════════════════

"""Hidden object key marking a JSObject as a generator instance: the reserved
markers._KEY_IS_GEN_MARK (set by gen_seed_keys), mirrored in the object's
brand as BRAND_GENERATOR."""
glob _KEY_IS_GEN: int = 0;

"""Hidden object key storing the index into _GEN_REALM.generators."""
glob _KEY_GEN_IDX: int = 0;

"""Hidden object key marking a generator as an *async* generator."""
glob _KEY_ASYNC_GEN: int = 0;

"""[[Prototype]] for generator iterator objects (inherits Iterator.prototype helpers)."""
glob _GEN_INSTANCE_PROTO: JSValue = js_undefined();

def:pub gen_set_instance_proto(proto: JSValue) {
    _GEN_INSTANCE_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

def:pub gen_get_instance_proto -> JSValue {
    return _GEN_INSTANCE_PROTO;
}

"""Call once at startup (from init_global) to seed the hidden keys."""
def:pub gen_seed_keys -> None {
    if _KEY_GEN_IDX != 0 {
        return;
    }
    _KEY_IS_GEN = _KEY_IS_GEN_MARK;
    _KEY_GEN_IDX = _KEY_GEN_IDX_MARK;
    _KEY_ASYNC_GEN = _KEY_ASYNC_GEN_MARK;
}


# ══════════════════════════════════════════════════════════════════════════════
# Factory & accessors
# ══════════════════════════════════════════════════════════════════════════════

# Shape of an iterator result {value, done} (see js_iter_result); shapes are
# immutable and never freed. (Globs are declared above their writers: Jac
# binds an assignment that precedes the declaration as a local.)
glob _IR_SHAPE: int = -1,
     _IR_PROTO_IDX: int = -1,
     _GEN_SID: int = -1,
     _GEN_IDX_SI: int = -1;

# The layout every sync generator object is born with (shapes do not depend
# on the prototype): its shape id and the state index's slot (V4.18).
"""
Build the {value, done} iterator result object.
ECMAScript §7.4.6 CreateIterResultObject.
"""
def:pub js_iter_result(value: JSValue, done: bool) -> JSValue {
    # Every result has the same layout, learned from the first one: later
    # ones are born at that shape (two property adds per iterator step
    # before, each a transition-cache probe and a slot append).
    if _IR_SHAPE > 0 {
        return js_object_new_shaped2(
            _ir_proto_idx(), _IR_SHAPE, value, js_boolean(done)
        );
    }
    # Well-known key ids (interning "value"/"done" per result was a string
    # hash + compare each, on every iterator step).
    js_obj: JSValue = js_object_create(js_object_get_ordinary_proto());
    js_object_set(js_obj, WK_VALUE, value);
    js_object_set(js_obj, WK_DONE, js_boolean(done));
    if js_object_own_data_slot(js_obj, WK_VALUE) == 0
        and js_object_own_data_slot(js_obj, WK_DONE) == 1 {
        _IR_SHAPE = js_object_ic_shape(js_obj);
    }
    return js_obj;
}


"""Table id of %Object.prototype% once it exists (-1 before: a null
[[Prototype]] during early bootstrap)."""
def _ir_proto_idx -> int {
    if _IR_PROTO_IDX > 0 {
        return _IR_PROTO_IDX;
    }
    ip_p: JSValue = js_object_get_ordinary_proto();
    if jsv_is_object_cell(ip_p) and jsv_to_table_id(ip_p) > 0 {
        _IR_PROTO_IDX = jsv_to_table_id(ip_p);
    }
    return _IR_PROTO_IDX;
}

"""Create a fresh generator object wrapping the given JSGeneratorState.

If is_async is True, the object is also marked as an async generator
via the hidden _KEY_ASYNC_GEN marker."""
def:pub js_generator_create(
    func: CompiledFunction,
    locals: list[JSValue],
    free_vals: list[JSValue],
    this_val: JSValue,
    is_async: bool = False,
    start_ip: int = 0,
    super_fn: JSValue = js_undefined(),
    module_fns: list[CompiledFunction] = []
) -> JSValue {
    state: JSGeneratorState = JSGeneratorState(
        func=func,
        locals=locals,
        free_vals=free_vals,
        this_val=this_val,
        super_fn=super_fn,
        saved_ip=start_ip,
        catch_stack=[],
        done=False,
        send_val=js_undefined(),
        throw_mode=False,
        ret_mode=False,
        saved_stack=[],
        stack_base=0,
        delegate_gen=js_undefined(),
        async_promise=js_undefined(),
        # The generator function's compilation unit: run_generator switches to it
        # for every step, so MAKE_CLOSURE / function refs in the body resolve in the
        # generator's own module even when a different module calls .next().
        module_fns=module_fns,
        executing=False
    );
    # Prefer a tombstoned slot from the GC free-list when available.
    idx: int = -1;
    if len(_GEN_REALM.free_generator_slots) > 0 {
        idx = _GEN_REALM.free_generator_slots[len(_GEN_REALM.free_generator_slots) - 1];
        del _GEN_REALM.free_generator_slots[len(_GEN_REALM.free_generator_slots) - 1];
        _GEN_REALM.generators[idx] = state;
        if idx < len(_GEN_REALM.generators_mark_epoch) {
            _GEN_REALM.generators_mark_epoch[idx] = 0;
        } else {
            _GEN_REALM.generators_mark_epoch.append(0);
        }
    } else {
        _GEN_REALM.generators.append(state);
        _GEN_REALM.generators_mark_epoch.append(0);  # A2.2b GC mark bitmap
        idx = len(_GEN_REALM.generators) - 1;
    }
    gc_note_alloc(_GEN_REALM);  # G0.4: account generator allocation (reuse or append)

    js_obj: JSValue = js_undefined();
    if jsv_is_object_cell(_GEN_INSTANCE_PROTO)
        and jsv_to_table_id(_GEN_INSTANCE_PROTO) > 0 {
        js_obj = js_object_create(_GEN_INSTANCE_PROTO);
    } else {
        js_obj = js_object_create_null();
    }
    js_object_set(js_obj, _KEY_IS_GEN, js_int(1));
    js_object_set(js_obj, _KEY_GEN_IDX, js_int(idx));
    if is_async {
        js_object_set(js_obj, _KEY_ASYNC_GEN, js_int(1));
    } elif _GEN_SID < 0 {
        # learn the sync generator layout from the first one
        gc_si: int = js_object_own_data_slot(js_obj, _KEY_GEN_IDX);
        if gc_si >= 0 {
            _GEN_IDX_SI = gc_si;
            _GEN_SID = js_object_ic_shape(js_obj);
        }
    }
    return js_obj;
}

"""Return True if v is a generator object."""
def:pub js_is_generator(v: JSValue) -> bool {
    return (js_object_brand(v) & BRAND_GENERATOR) != 0;
}

"""Return True if v is an *async* generator object."""
def:pub js_is_async_generator(v: JSValue) -> bool {
    if _GEN_SID > 0 and js_object_ic_shape(v) == _GEN_SID {
        return False;
    }
    if not js_is_generator(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_ASYNC_GEN);
}

"""Return the JSGeneratorState for a generator object (caller must check js_is_generator first)."""
def:pub js_get_generator_state(v: JSValue) -> JSGeneratorState {
    if _GEN_SID > 0 {
        gg_iv: JSValue = js_object_ic_hit(v, _GEN_SID, _GEN_IDX_SI);
        if jsv_is_int32(gg_iv) {
            return _GEN_REALM.generators[jsv_to_int32(gg_iv)];
        }
    }
    idx_v: JSValue = js_object_get(v, _KEY_GEN_IDX);
    idx: int = jsv_to_int32(idx_v);
    return _GEN_REALM.generators[idx];
}

"""Update the generator state back into the table after mutation."""
def:pub js_set_generator_state(v: JSValue, state: JSGeneratorState) -> None {
    if _GEN_SID > 0 {
        gs_iv: JSValue = js_object_ic_hit(v, _GEN_SID, _GEN_IDX_SI);
        if jsv_is_int32(gs_iv) {
            _GEN_REALM.generators[jsv_to_int32(gs_iv)] = state;
            return;
        }
    }
    idx_v: JSValue = js_object_get(v, _KEY_GEN_IDX);
    idx: int = jsv_to_int32(idx_v);
    _GEN_REALM.generators[idx] = state;
}

glob _GEN_REALM: Realm;

def:pub gen_set_realm(r: Realm) {
    _GEN_REALM = r;
}
