"""Promise object data layer.

Promises are JSObjects with hidden sentinel keys.  All state mutations and
reactions are orchestrated from vm/vm.na.jac which has access to self.run().
This file only provides:
  • sentinel key constants  (hidden from user-land enumeration)
  • js_promise_create()     (allocate empty pending promise)
  • js_is_promise()         (type guard)
  • js_promise_get_state()  (0=pending 1=fulfilled 2=rejected)
  • js_promise_get_value()  (settled value)
  • js_promise_settle()     (used by VM to set state + value atomically)
  • resolve/reject wrapper creation (resolve_fn / reject_fn passable to executor)
  • reaction accessors      (add / iterate reactions on pending promises)

Bun Zig mapping:
  JSC::JSPromise            — JSPromise.h
  JSC::JSPromise::resolve   — JSPromise.cpp
  JSC::JSPromise::reject    — JSPromise.cpp
  JSC::JSPromise::perform   — JSPromise.cpp

ECMAScript §27.2 — Promise Objects
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_true,
    js_int,
    jsv_undefined,
    jsv_is_int32,
    jsv_is_object_cell,
    jsv_to_int32,
    jsv_from_string_id,
    jsv_to_table_id
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_get,
    js_object_set,
    js_object_has_own,
    js_object_define_property,
    js_function_get_proto,
    js_object_set_prototype,
    js_object_brand
}
import from engine.src.runtime.jsobj_type { JSProperty, BRAND_PROMISE }
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.builtins.array { js_array_create, js_array_push }
import from engine.src.runtime.gc_pin { gc_pin_value, gc_pin_live_list }
import from engine.src.builtins.markers {
    _KEY_IS_PROMISE,
    _KEY_PSTATE,
    _KEY_PVALUE,
    _KEY_IS_RESOLVE,
    _KEY_IS_REJECT,
    _KEY_PROMISE_REF,
    _KEY_PREACTIONS,
    _KEY_IS_ASYNC_RESUME,
    _KEY_IS_ASYNC_REJECT,
    _KEY_ASYNC_RESUME_IDX,
    _KEY_IS_ASYNC_ITER_RESUME,
    _KEY_IS_ASYNC_ITER_REJECT,
    _KEY_IS_TDZ,
    _KEY_IS_PROMISE_ALL_RESOLVE,
    _KEY_IS_PROMISE_ALL_REJECT,
    _KEY_IS_PROMISE_ALLSETTLED_RESOLVE,
    _KEY_IS_PROMISE_ALLSETTLED_REJECT,
    _KEY_IS_PROMISE_ANY_REJECT,
    _KEY_PROMISE_COMB_INDEX,
    _KEY_PROMISE_COMB_RESULT,
    _KEY_AH_ASYNC_ID,
    _KEY_AH_TRIGGER_ID
}

# Wave 20 — PromiseHook gate (near-zero cost when disabled)
glob:pub _AH_PROMISE_HOOKS: int = 0;
glob:priv _AH_NEXT_ASYNC_ID: int = 2,
     _AH_EXEC_ASYNC_ID: int = 1,
     _AH_INIT_AIDS: list[int] = [],
     _AH_INIT_TRIGGERS: list[int] = [],
     _AH_INIT_PROMISES: list[JSValue] = [],
     _AH_INIT_PROMISES_ROOTED: bool = False,
     _AH_RESOLVE_QUEUE: list[int] = [];  # 1 reserved for bootstrap

def:pub ah_promise_hooks_enable(v: int) {
    _AH_PROMISE_HOOKS = v;
}

def:pub ah_promise_hooks_enabled -> int {
    return _AH_PROMISE_HOOKS;
}

def:pub ah_set_execution_async_id(aid: int) {
    _AH_EXEC_ASYNC_ID = aid;
}

def:pub ah_get_execution_async_id -> int {
    return _AH_EXEC_ASYNC_ID;
}

def:pub ah_peek_next_async_id -> int {
    return _AH_NEXT_ASYNC_ID;
}

def:priv _ah_assign_ids(p: JSValue) -> None {
    if _AH_PROMISE_HOOKS == 0 {
        return;
    }
    if js_object_has_own(p, _KEY_AH_ASYNC_ID) {
        return;
    }
    aid: int = _AH_NEXT_ASYNC_ID;
    _AH_NEXT_ASYNC_ID = _AH_NEXT_ASYNC_ID + 1;
    js_object_set(p, _KEY_AH_ASYNC_ID, js_int(aid));
    js_object_set(p, _KEY_AH_TRIGGER_ID, js_int(_AH_EXEC_ASYNC_ID));
    _AH_INIT_AIDS.append(aid);
    _AH_INIT_TRIGGERS.append(_AH_EXEC_ASYNC_ID);
    if not _AH_INIT_PROMISES_ROOTED {
        # glob queue — contents invisible to the GC root walk
        gc_pin_live_list(_AH_INIT_PROMISES);
        _AH_INIT_PROMISES_ROOTED = True;
    }
    _AH_INIT_PROMISES.append(p);
}

"""Drain pending PROMISE init events into a JS array of
[asyncId, triggerId, promise, asyncId, triggerId, promise, ...]."""
def:pub ah_drain_init_events -> JSValue {
    arr: JSValue = js_array_create([]);
    i: int = 0;
    n: int = len(_AH_INIT_AIDS);
    while i < n {
        js_array_push(arr, js_int(_AH_INIT_AIDS[i]));
        js_array_push(arr, js_int(_AH_INIT_TRIGGERS[i]));
        js_array_push(arr, _AH_INIT_PROMISES[i]);
        i = i + 1;
    }
    _AH_INIT_AIDS = [];
    _AH_INIT_TRIGGERS = [];
    # Clear IN PLACE — the list identity is GC-rooted via gc_pin_live_list.
    while len(_AH_INIT_PROMISES) > 0 {
        del _AH_INIT_PROMISES[len(_AH_INIT_PROMISES) - 1];
    }
    return arr;
}

"""Drain pending promiseResolve events into a JS array of asyncIds."""
def:pub ah_drain_resolve_events -> JSValue {
    arr: JSValue = js_array_create([]);
    i: int = 0;
    n: int = len(_AH_RESOLVE_QUEUE);
    while i < n {
        js_array_push(arr, js_int(_AH_RESOLVE_QUEUE[i]));
        i = i + 1;
    }
    _AH_RESOLVE_QUEUE = [];
    return arr;
}

def:pub ah_promise_async_id(p: JSValue) -> int {
    if not jsv_is_object_cell(p) {
        return 0;
    }
    if not js_object_has_own(p, _KEY_IS_PROMISE) {
        return 0;
    }
    if not js_object_has_own(p, _KEY_AH_ASYNC_ID) {
        return 0;
    }
    sv: JSValue = js_object_get(p, _KEY_AH_ASYNC_ID);
    if jsv_is_int32(sv) {
        return jsv_to_int32(sv);
    }
    return 0;
}

# ── Promise state constants ───────────────────────────────────────────────────

glob:pub PROMISE_PENDING: int = 0,
     PROMISE_FULFILLED: int = 1,
     PROMISE_REJECTED: int = 2;

"""Internal: Promise.prototype object, wired by init_global."""
glob _PROMISE_PROTO: JSValue = jsv_undefined();

def:pub js_promise_set_proto(proto: JSValue) {
    _PROMISE_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

# Reaction object property keys (string-interned)
glob:pub _RKEY_ONFULFILL: int = 0,
     _RKEY_ONREJECT: int = 0,
     _RKEY_NEXT: int = 0;  # initialised in _promise_seed_keys()

# chained result promise
glob _promise_keys_seeded: bool = False;

"""Seed reaction key interned IDs once at startup."""
def:pub promise_seed_keys -> None {
    if _promise_keys_seeded {
        return;
    }
    _RKEY_ONFULFILL = str_intern("__RF__");
    _RKEY_ONREJECT = str_intern("__RJ__");
    _RKEY_NEXT = str_intern("__RN__");
    _promise_keys_seeded = True;
}

# ── Core factory ─────────────────────────────────────────────────────────────

"""Create a new pending Promise object."""
def:pub js_promise_create -> JSValue {
    p: JSValue = js_object_create(_PROMISE_PROTO)
        if jsv_is_object_cell(_PROMISE_PROTO)
        else js_object_create_null();
    js_object_set(p, _KEY_IS_PROMISE, js_true());
    js_object_set(p, _KEY_PSTATE, js_int(PROMISE_PENDING));
    js_object_set(p, _KEY_PVALUE, js_undefined());
    js_object_set(p, _KEY_PREACTIONS, js_array_create([]));
    _ah_assign_ids(p);
    return p;
}

"""Install the promise internal slots on an existing object.

Used by SUPER_CALL for `class X extends Promise`: the derived constructor has
already allocated `this` with X.prototype on its chain, so a fresh
js_promise_create() object would be the wrong identity. Initializing in place
makes `this` itself a real promise while keeping the subclass prototype, which
is what §27.2.3.1 (OrdinaryCreateFromConstructor + slot init) requires."""
def:pub js_promise_init_in_place(p: JSValue) {
    js_object_set(p, _KEY_IS_PROMISE, js_true());
    js_object_set(p, _KEY_PSTATE, js_int(PROMISE_PENDING));
    js_object_set(p, _KEY_PVALUE, js_undefined());
    js_object_set(p, _KEY_PREACTIONS, js_array_create([]));
    _ah_assign_ids(p);
}

"""Return True iff v is a Promise object."""
def:pub js_is_promise(v: JSValue) -> bool {
    # BRAND_PROMISE mirrors own _KEY_IS_PROMISE (0 for non-objects).
    if (js_object_brand(v) & BRAND_PROMISE) == 0 {
        return False;
    }
    # Guard against hidden-key collisions on ordinary objects.
    if not js_object_has_own(v, _KEY_PSTATE) {
        return False;
    }
    if not js_object_has_own(v, _KEY_PVALUE) {
        return False;
    }
    if not js_object_has_own(v, _KEY_PREACTIONS) {
        return False;
    }
    return True;
}

"""Return the current promise state (PROMISE_PENDING / FULFILLED / REJECTED)."""
def:pub js_promise_get_state(p: JSValue) -> int {
    sv: JSValue = js_object_get(p, _KEY_PSTATE);
    if jsv_is_int32(sv) {
        return jsv_to_int32(sv);
    }
    return PROMISE_PENDING;
}

"""Return the settled value (undefined if still pending)."""
def:pub js_promise_get_value(p: JSValue) -> JSValue {
    return js_object_get(p, _KEY_PVALUE);
}

"""Atomically settle a promise (fulfilled or rejected).
Called only by the VM once, when it knows the promise is still pending."""
def:pub js_promise_settle(p: JSValue, state: int, value: JSValue) {
    js_object_set(p, _KEY_PSTATE, js_int(state));
    js_object_set(p, _KEY_PVALUE, value);
    if _AH_PROMISE_HOOKS != 0 and js_object_has_own(p, _KEY_AH_ASYNC_ID) {
        sv: JSValue = js_object_get(p, _KEY_AH_ASYNC_ID);
        if jsv_is_int32(sv) {
            _AH_RESOLVE_QUEUE.append(jsv_to_int32(sv));
        }
    }
}

# ── Reaction list ─────────────────────────────────────────────────────────────

"""Return the reactions array stored on an unsettled promise."""
def:pub js_promise_get_reactions(p: JSValue) -> JSValue {
    return js_object_get(p, _KEY_PREACTIONS);
}

"""Add a reaction object {__RF__, __RJ__, __RN__} to a pending promise."""
def:pub js_promise_add_reaction(
    p: JSValue, on_fulfill: JSValue, on_reject: JSValue, next: JSValue
) {
    r: JSValue = js_object_create_null();
    js_object_set(r, _RKEY_ONFULFILL, on_fulfill);
    js_object_set(r, _RKEY_ONREJECT, on_reject);
    js_object_set(r, _RKEY_NEXT, next);
    arr: JSValue = js_object_get(p, _KEY_PREACTIONS);
    js_array_push(arr, r);
}

# ── Resolve / Reject callback wrappers ───────────────────────────────────────

"""Give a resolving-function marker object the `length`/`name` a built-in
function is required to expose.

§27.2.1.3.1/.2: both functions have length 1 and name "", with the standard
built-in attributes { writable: false, enumerable: false, configurable: true }.
These wrappers are plain marker objects rather than real closures, so nothing
supplies the properties for them — and js_object_set would create them as
writable *and enumerable*, which the prop-desc tests check explicitly."""
def _install_fn_len_name(fn: JSValue) {
    # §20.2: every built-in function has %Function.prototype% as its
    # [[Prototype]]. These markers were created null-proto, so
    # `Object.getPrototypeOf(resolveFn)` did not match Function.prototype and
    # Function.prototype.toString could not find a receiver to work with.
    fp: JSValue = js_function_get_proto();
    if jsv_is_object_cell(fp) and jsv_to_table_id(fp) > 0 {
        js_object_set_prototype(fn, fp);
    }
    k_len: int = str_intern("length");
    k_nm: int = str_intern("name");
    js_object_define_property(
        fn,
        k_len,
        JSProperty(
            key=k_len,
            value=js_int(1),
            writable=False,
            enumerable=False,
            configurable=True,
            deleted=False
        )
    );
    js_object_define_property(
        fn,
        k_nm,
        JSProperty(
            key=k_nm,
            value=jsv_from_string_id(str_intern("")),
            writable=False,
            enumerable=False,
            configurable=True,
            deleted=False
        )
    );
}

def:pub js_make_resolve_fn(promise: JSValue) -> JSValue {
    fn: JSValue = js_object_create_null();
    js_object_set(fn, _KEY_IS_RESOLVE, js_true());
    js_object_set(fn, _KEY_PROMISE_REF, promise);
    _install_fn_len_name(fn);
    return fn;
}

"""Create a reject callback that settles `promise` when called.
The VM detects this wrapper in its CALL handler via _KEY_IS_REJECT."""
def:pub js_make_reject_fn(promise: JSValue) -> JSValue {
    fn: JSValue = js_object_create_null();
    js_object_set(fn, _KEY_IS_REJECT, js_true());
    js_object_set(fn, _KEY_PROMISE_REF, promise);
    _install_fn_len_name(fn);
    return fn;
}

"""True iff v is a resolve wrapper created by js_make_resolve_fn."""
def:pub js_is_resolve_fn(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_RESOLVE);
}

"""True iff v is a reject wrapper created by js_make_reject_fn."""
def:pub js_is_reject_fn(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_REJECT);
}

def:pub js_is_promise_all_resolve_elem(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_PROMISE_ALL_RESOLVE);
}

def:pub js_is_promise_all_reject_elem(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_PROMISE_ALL_REJECT);
}

def:pub js_is_promise_allsettled_resolve_elem(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_PROMISE_ALLSETTLED_RESOLVE);
}

def:pub js_is_promise_allsettled_reject_elem(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_PROMISE_ALLSETTLED_REJECT);
}

def:pub js_is_promise_any_reject_elem(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_PROMISE_ANY_REJECT);
}

def:pub js_make_promise_all_resolve_elem(result_p: JSValue, index: int) -> JSValue {
    fn: JSValue = js_object_create_null();
    js_object_set(fn, _KEY_IS_PROMISE_ALL_RESOLVE, js_true());
    js_object_set(fn, _KEY_PROMISE_COMB_INDEX, js_int(index));
    js_object_set(fn, _KEY_PROMISE_COMB_RESULT, result_p);
    _install_fn_len_name(fn);
    return fn;
}

def:pub js_make_promise_all_reject_elem(result_p: JSValue) -> JSValue {
    fn: JSValue = js_object_create_null();
    js_object_set(fn, _KEY_IS_PROMISE_ALL_REJECT, js_true());
    js_object_set(fn, _KEY_PROMISE_COMB_RESULT, result_p);
    _install_fn_len_name(fn);
    return fn;
}

def:pub js_make_promise_allsettled_resolve_elem(
    result_p: JSValue, index: int
) -> JSValue {
    fn: JSValue = js_object_create_null();
    js_object_set(fn, _KEY_IS_PROMISE_ALLSETTLED_RESOLVE, js_true());
    js_object_set(fn, _KEY_PROMISE_COMB_INDEX, js_int(index));
    js_object_set(fn, _KEY_PROMISE_COMB_RESULT, result_p);
    _install_fn_len_name(fn);
    return fn;
}

def:pub js_make_promise_allsettled_reject_elem(
    result_p: JSValue, index: int
) -> JSValue {
    fn: JSValue = js_object_create_null();
    js_object_set(fn, _KEY_IS_PROMISE_ALLSETTLED_REJECT, js_true());
    js_object_set(fn, _KEY_PROMISE_COMB_INDEX, js_int(index));
    js_object_set(fn, _KEY_PROMISE_COMB_RESULT, result_p);
    _install_fn_len_name(fn);
    return fn;
}

def:pub js_make_promise_any_reject_elem(result_p: JSValue, index: int) -> JSValue {
    fn: JSValue = js_object_create_null();
    js_object_set(fn, _KEY_IS_PROMISE_ANY_REJECT, js_true());
    js_object_set(fn, _KEY_PROMISE_COMB_INDEX, js_int(index));
    js_object_set(fn, _KEY_PROMISE_COMB_RESULT, result_p);
    _install_fn_len_name(fn);
    return fn;
}

# ── Unhandled rejection tracking queue ───────────────────────────────────────
# Written by _promise_settle_and_drain (vm.na.jac) for settle-time rejections
# and by NATIVE_KIND_PROMISE_STATIC_REJECT (dispatch.na.jac) for Promise.reject().
# Drained by vm_dispatch_unhandled_rejections after each el_tick microtask drain.

glob _URQ_REASONS: list[int] = [],
     _URQ_PROMISES: list[int] = [];

"""Queue a promise rejection as potentially unhandled (no catch handler yet)."""
def:pub promise_track_unhandled(reason: JSValue, promise: JSValue) {
    _URQ_REASONS.append(reason);
    _URQ_PROMISES.append(promise);
}

"""Return the count of pending unhandled rejection entries."""
def:pub promise_unhandled_count -> int {
    return len(_URQ_REASONS);
}

"""Return the reason at index i."""
def:pub promise_unhandled_reason(i: int) -> JSValue {
    return _URQ_REASONS[i];
}

"""Return the promise at index i."""
def:pub promise_unhandled_promise(i: int) -> JSValue {
    return _URQ_PROMISES[i];
}

"""Clear the first n entries from the unhandled rejection queue.

O(remaining) rebuild instead of repeated `del [0]` (O(n^2) batch drain)."""
def:pub promise_unhandled_clear(n: int) -> None {
    if n <= 0 {
        return;
    }
    ur_r: list[JSValue] = [];
    ur_p: list[JSValue] = [];
    ur_i: int = n;
    ur_len: int = len(_URQ_REASONS);
    while ur_i < ur_len {
        ur_r.append(_URQ_REASONS[ur_i]);
        ur_p.append(_URQ_PROMISES[ur_i]);
        ur_i = ur_i + 1;
    }
    _URQ_REASONS = ur_r;
    _URQ_PROMISES = ur_p;
}

"""Remove a specific promise from the unhandled rejection queue (it got a handler)."""
def:pub promise_unmark_unhandled(promise: JSValue) -> None {
    i: int = 0;
    while i < len(_URQ_PROMISES) {
        if _URQ_PROMISES[i] == promise {
            del _URQ_PROMISES[i];
            del _URQ_REASONS[i];
            return;
        }
        i = i + 1;
    }
}
