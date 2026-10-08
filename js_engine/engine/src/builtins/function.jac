"""
Built-in: Function

JS function objects: JS-defined closures, native built-ins, and the
`Function` constructor that compiles a source string at runtime.

Bun reference   : bun/src/bun.js/bindings/JSFunction.* (JSC::JSFunction)
                  bun/src/js/builtins/Function.ts
ECMAScript spec : §20.2 — https://tc39.es/ecma262/#sec-function-objects

Encoding scheme (JSValue.tag == Object, as_ptr < 0):
  JS closure  : -(as_ptr + 1) in [0, BUILTIN_BASE-1]  → _FN_REALM.closures idx
  Native builtin: -(as_ptr + 1) >= BUILTIN_BASE         → _FN_REALM.builtins idx
  Ordinary object: as_ptr >= 1

The VM dispatches `is_fn_val` closures in CALL/CALL_METHOD.
"""

import from engine.src.vm.closure_type { JSClosure }
import from engine.src.vm.vm {
    VM,
    make_vm,
    make_closure,
    is_fn_val,
    get_fn_idx,
    js_fn_val
}
import from engine.src.runtime.encoding { FN_BUILTIN_BASE, FN_NATIVE_BASE }
import from engine.src.bytecode.op { CompiledFunction, make_compiled_fn }
import from engine.src.bytecode.compiler { Compiler, make_compiler }
import from engine.src.parser.parser { parse }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    jsv_is_cell,
    jsv_cell_kind,
    jsv_to_table_id,
    jsv_from_cell_kind,
    jsv_from_string_id,
    JS_CELL_KIND_NATIVE,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_null,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_undefined,
    jsv_to_bool,
    jsv_to_int32,
    jsv_to_double
}
import from engine.src.builtins.function_type { JSFunctionMeta, BuiltinFn }
import from engine.src.runtime.realm { Realm, gc_note_alloc }
import from engine.src.vm.vm_obs { js_to_string_observable }
import from engine.src.builtins.array { js_is_array, js_array_len, js_array_get }
import from engine.src.runtime.jsstring { str_intern, str_heap, str_from_id }
import from engine.src.runtime.jsobject {
    KEY_LENGTH,
    js_object_create_null,
    js_object_get
}

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Constants
# ══════════════════════════════════════════════════════════════════════════════

# BUILTIN_BASE lives in runtime/encoding.na.jac (1_000_000).
# ══════════════════════════════════════════════════════════════════════════════
# 4.  Encoding helpers — distinguish closures from built-ins
# ══════════════════════════════════════════════════════════════════════════════

"""Return True if v encodes a native built-in (not a JS closure)."""
glob _FN_REALM: Realm;

def:pub fn_realm_set(r: Realm) {
    _FN_REALM = r;
}

def:pub is_builtin_val(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    id: int = jsv_to_table_id(v);
    return id >= FN_BUILTIN_BASE and id < FN_NATIVE_BASE;
}

"""Return the _FN_REALM.builtins index for a built-in function value."""
def:pub get_builtin_idx(v: JSValue) -> int {
    return jsv_to_table_id(v) - FN_BUILTIN_BASE;
}

"""Encode a _FN_REALM.builtins index as a JSValue."""
def:pub js_builtin_val(idx: int) -> JSValue {
    return jsv_from_cell_kind(FN_BUILTIN_BASE + idx, JS_CELL_KIND_NATIVE);
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  js_function_create / js_function_create_src
# ══════════════════════════════════════════════════════════════════════════════

"""
Allocate a new JS function from a CompiledFunction and its captured
free-variable values.  Appends to _FN_REALM.closures and _FN_REALM.functions
(padding the latter to keep indices aligned).

Returns JSValue{tag=Object, as_ptr=-(idx+1)} — the standard fn-val encoding
used by is_fn_val / get_fn_idx throughout the VM.

ECMAScript §10.2.3 OrdinaryFunctionCreate
"""
def:pub js_function_create(fn: CompiledFunction, closure: list[JSValue]) -> JSValue {
    return js_function_create_src(fn, closure, "");
}

"""Like js_function_create but also records the original source text for .toString()."""
def:pub js_function_create_src(
    fn: CompiledFunction, closure: list[JSValue], src: str
) -> JSValue {
    # Create the .prototype object that will be shared by the closure and metadata.
    # new Foo() sets new_obj.[[Prototype]] = Foo.prototype (i.e. this object).
    proto: JSValue = js_object_create_null();
    cl: JSClosure = make_closure(fn, closure, js_undefined(), proto);

    # A2.4: reuse a tombstoned closure slot from the GC free-list if available.
    if len(_FN_REALM.free_closure_slots) > 0 {
        last: int = len(_FN_REALM.free_closure_slots) - 1;
        idx: int = _FN_REALM.free_closure_slots[last];
        del _FN_REALM.free_closure_slots[last];
        _FN_REALM.closures[idx] = cl;
        _FN_REALM.closures_mark_epoch[idx] = 0;
        # Reuse the parallel function metadata slot if it exists.
        if idx < len(_FN_REALM.functions) {
            _FN_REALM.functions[idx] = JSFunctionMeta(
                name=fn.name, arg_count=len(fn.params), prototype_obj=proto, source=src
            );
            _FN_REALM.functions_mark_epoch[idx] = 0;
        }
        return js_fn_val(idx);
    }

    idx: int = len(_FN_REALM.closures);
    _FN_REALM.closures.append(cl);
    _FN_REALM.closures_mark_epoch.append(0);  # A2.2b GC mark bitmap
    gc_note_alloc(_FN_REALM);  # G0.4: account closure allocation

    # Pad _FN_REALM.functions with dummy entries for any closures that were created
    # earlier (by the VM's MAKE_FUNCTION opcode) without going through here.
    dummy_proto: JSValue = js_object_create_null();
    while len(_FN_REALM.functions) < idx {
        dummy: JSFunctionMeta = JSFunctionMeta(
            name="", arg_count=0, prototype_obj=dummy_proto, source=""
        );
        _FN_REALM.functions.append(dummy);
    }

    meta: JSFunctionMeta = JSFunctionMeta(
        name=fn.name, arg_count=len(fn.params), prototype_obj=proto, source=src
    );
    _FN_REALM.functions.append(meta);
    _FN_REALM.functions_mark_epoch.append(0);  # A2.2b GC mark bitmap
    return js_fn_val(idx);
}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  Metadata accessors
# ══════════════════════════════════════════════════════════════════════════════

"""
Return the function name.

For functions created via js_function_create, reads _FN_REALM.functions.
For VM-created closures (MAKE_FUNCTION opcode), falls back to the
CompiledFunction.name field.
For built-ins, reads _FN_REALM.builtins.
ECMAScript §10.2.11 SetFunctionName
"""
def:pub js_fn_get_name(fn_val: JSValue) -> str {
    if is_builtin_val(fn_val) {
        bidx: int = get_builtin_idx(fn_val);
        if bidx >= 0 and bidx < len(_FN_REALM.builtins) {
            return _FN_REALM.builtins[bidx].name;
        }
        return "";
    }
    if not is_fn_val(fn_val) {
        return "";
    }
    idx: int = get_fn_idx(fn_val);
    if idx < len(_FN_REALM.functions) {
        m: JSFunctionMeta = _FN_REALM.functions[idx];
        if len(m.name) > 0 {
            return m.name;
        }
    }
    if idx < len(_FN_REALM.closures) {
        return _FN_REALM.closures[idx].func.name;
    }
    return "";
}

"""
Return the formal parameter count (ECMAScript §10.2.8 MakeArgGetter).
Used as the JS .length property.
"""
def:pub js_fn_get_length(fn_val: JSValue) -> int {
    if is_builtin_val(fn_val) {
        bidx: int = get_builtin_idx(fn_val);
        if bidx >= 0 and bidx < len(_FN_REALM.builtins) {
            return _FN_REALM.builtins[bidx].arity;
        }
        return 0;
    }
    if not is_fn_val(fn_val) {
        return 0;
    }
    idx: int = get_fn_idx(fn_val);
    if idx < len(_FN_REALM.functions) {
        m: JSFunctionMeta = _FN_REALM.functions[idx];
        if m.arg_count > 0 or len(m.name) > 0 {
            return m.arg_count;
        }
    }
    if idx < len(_FN_REALM.closures) {
        return len(_FN_REALM.closures[idx].func.params);
    }
    return 0;
}

"""Return the .prototype property of a JS function (ECMAScript §10.2.10)."""
def:pub js_fn_get_prototype(fn_val: JSValue) -> JSValue {
    if not is_fn_val(fn_val) {
        return js_undefined();
    }
    idx: int = get_fn_idx(fn_val);
    if idx < len(_FN_REALM.functions) {
        return _FN_REALM.functions[idx].prototype_obj;
    }
    return js_undefined();
}

# ══════════════════════════════════════════════════════════════════════════════
# 7.  js_function_call
# ══════════════════════════════════════════════════════════════════════════════

"""
Invoke fn_val with the given this_val and args.

For JS-defined closures: creates a fresh VM and calls vm.run().
For built-ins: not yet dispatchable . Returns undefined.

ECMAScript §10.2.1 [[Call]]
"""
def:pub js_function_call(
    fn_val: JSValue, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if is_builtin_val(fn_val) {
        # Built-in dispatch is wired in
        return js_undefined();
    }
    if not is_fn_val(fn_val) {
        return js_undefined();
    }
    idx: int = get_fn_idx(fn_val);
    cl: JSClosure = _FN_REALM.closures[idx];
    vm: VM = make_vm();
    result: JSValue = vm.run_cl(cl, fn_val, this_val, args);
    return result;
}

# ══════════════════════════════════════════════════════════════════════════════
# 8.  js_builtin_create
# ══════════════════════════════════════════════════════════════════════════════

"""
Register a native Jac function as a callable JS built-in.

`kind` is a stable numeric ID; 's dispatch table will call the
correct Jac implementation when the VM executes CALL on the resulting value.

ECMAScript §10.3 Built-in Function Objects
"""
def:pub js_builtin_create(name: str, arity: int, kind: int) -> JSValue {
    b: BuiltinFn = BuiltinFn(name=name, arity=arity, kind=kind);
    _FN_REALM.builtins.append(b);
    _FN_REALM.builtins_mark_epoch.append(0);  # A2.2b GC mark bitmap
    return js_builtin_val(len(_FN_REALM.builtins) - 1);
}

# ══════════════════════════════════════════════════════════════════════════════
# 9.  Function constructor — new Function(p1, p2, body)
# ══════════════════════════════════════════════════════════════════════════════

"""
`Function(body)` or `Function("p1, p2", body)` — parse and compile at runtime.

The last argument is the body; earlier arguments are parameter names (joined
with commas).  The resulting function is named "anonymous".

ECMAScript §20.2.1.1 CreateDynamicFunction
"""
def:pub js_Function(args: list[JSValue]) -> JSValue {
    param_str: str = "";
    body_str: str = "";
    n: int = len(args);
    if n == 0 {
        body_str = "";
    } elif n == 1 {
        body_str = _jsv_to_str(args[0]);
    } else {
        body_str = _jsv_to_str(args[n - 1]);
        pi: int = 0;
        while pi < n - 1 {
            if pi > 0 {
                param_str = param_str + ",";
            }
            param_str = param_str + _jsv_to_str(args[pi]);
            pi = pi + 1;
        }
    }
    src: str = "function anonymous(" + param_str + ") {\n" + body_str + "\n}";
    c: Compiler = make_compiler();
    top_fn: CompiledFunction = c.compile_program(parse(src));
    # c.all_fns[0] is the inner "anonymous" function produced by the compiler
    if len(c.all_fns) > 0 {
        inner_fn: CompiledFunction = c.all_fns[0];
        return js_function_create_src(inner_fn, [], src);
    }
    # Fallback: use top-level function if no inner functions were produced
    return js_function_create_src(top_fn, [], src);
}

"""Coerce a JSValue to a Jac str for parameter / body assembly."""
def _jsv_to_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    if jsv_is_undefined(v) {
        return "undefined";
    }
    if jsv_is_null(v) {
        return "null";
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return "true";
        } else {
            return "false";
        }
    }
    if jsv_is_int32(v) {
        return str(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return str(jsv_to_double(v));
    }
    # CreateDynamicFunction ToString-coerces EVERY argument — an ARRAY of
    # parameter names must become "a,b,c" via Array.prototype.toString
    # (rollup's test harness passes `new Function(contextKeys, code)`).
    # Arrays are joined inline: the observable ToString needs an active obs
    # context, which this path does not have.
    if js_is_array(v) {
        ts_n: int = js_array_len(v);
        ts_out: str = "";
        ts_i: int = 0;
        while ts_i < ts_n {
            if ts_i > 0 {
                ts_out = ts_out + ",";
            }
            ts_el: JSValue = js_array_get(v, ts_i);
            if not jsv_is_undefined(ts_el) and not jsv_is_null(ts_el) {
                ts_out = ts_out + _jsv_to_str(ts_el);
            }
            ts_i = ts_i + 1;
        }
        return ts_out;
    }
    if jsv_is_cell(v) {
        ts_obs: str = js_to_string_observable(v);
        if ts_obs != "" {
            return ts_obs;
        }
        return "[object Object]";
    }
    return "";
}

# ══════════════════════════════════════════════════════════════════════════════
# 10.  Function.prototype methods
# ══════════════════════════════════════════════════════════════════════════════

"""
Function.prototype.call(thisArg, arg1, arg2, …)

Invokes fn_val with an explicit `this` binding and individual arguments.
ECMAScript §20.2.3.3
"""
def:pub js_Function_prototype_call(
    fn_val: JSValue, this_arg: JSValue, args: list[JSValue]
) -> JSValue {
    return js_function_call(fn_val, this_arg, args);
}

"""
Function.prototype.apply(thisArg, argsArray)

Invokes fn_val with an explicit `this` and arguments supplied as an
array-like object.  If argsArray is null/undefined, calls with no args.
ECMAScript §20.2.3.1
"""
def:pub js_Function_prototype_apply(
    fn_val: JSValue, this_arg: JSValue, args_array: JSValue
) -> JSValue {
    call_args: list[JSValue] = [];
    if jsv_is_object_cell(args_array) {
        len_v: JSValue = js_object_get(args_array, KEY_LENGTH);
        n: int = 0;
        if jsv_is_int32(len_v) {
            n = jsv_to_int32(len_v);
        } elif jsv_is_double(len_v) {
            n = int(jsv_to_double(len_v));
        }
        ai: int = 0;
        while ai < n {
            k: int = str_intern(str(ai));
            call_args.append(js_object_get(args_array, k));
            ai = ai + 1;
        }
    }
    return js_function_call(fn_val, this_arg, call_args);
}

"""
Function.prototype.bind(thisArg, partialArg1, …)

Returns a new function with `this` permanently bound to thisArg and
zero or more partial arguments prepended.

The bound function is stored in _FN_REALM.closures as a stub entry;
 will reroute CALL through the binding chain.
ECMAScript §20.2.3.2
"""
def:pub js_Function_prototype_bind(
    fn_val: JSValue, bound_this: JSValue, partial_args: list[JSValue]
) -> JSValue {
    # Create a stub CompiledFunction to anchor the closure entry.
    stub_fn: CompiledFunction = make_compiled_fn("<bound>", "<bind>");
    # Store bound_this as the lexical_this field so  can retrieve it.
    # Bound functions have no .prototype (ECMAScript §20.2.3.2 step 13).
    cl: JSClosure = make_closure(stub_fn, partial_args, bound_this, js_undefined());
    _FN_REALM.closures.append(cl);
    _FN_REALM.closures_mark_epoch.append(0);  # A2.2b GC mark bitmap
    gc_note_alloc(_FN_REALM);  # G0.4: account closure allocation
    idx: int = len(_FN_REALM.closures) - 1;

    # Compute result .length = max(0, target.length - len(partial_args))
    orig_len: int = js_fn_get_length(fn_val);
    result_len: int = orig_len - len(partial_args);
    if result_len < 0 {
        result_len = 0;
    }

    # Pad and append metadata. Bound functions have no `.prototype` (ES §20.2.3.2).
    while len(_FN_REALM.functions) < idx {
        dp: JSValue = js_object_create_null();
        d: JSFunctionMeta = JSFunctionMeta(
            name="", arg_count=0, prototype_obj=dp, source=""
        );
        _FN_REALM.functions.append(d);
        _FN_REALM.functions_mark_epoch.append(0);  # A2.2b GC mark bitmap (pad entry)
    }
    bound_meta: JSFunctionMeta = JSFunctionMeta(
        name="bound " + js_fn_get_name(fn_val),
        arg_count=result_len,
        prototype_obj=js_undefined(),
        source=""
    );
    _FN_REALM.functions.append(bound_meta);
    _FN_REALM.functions_mark_epoch.append(0);  # A2.2b GC mark bitmap
    return js_fn_val(idx);
}

"""
Function.prototype.toString()

Returns the reconstructed source text when available, otherwise the
canonical "[native code]" form required by the spec.
ECMAScript §20.2.3.5
"""
def:pub js_Function_prototype_toString(fn_val: JSValue) -> JSValue {
    if is_builtin_val(fn_val) {
        bidx: int = get_builtin_idx(fn_val);
        bname: str = "";
        if bidx >= 0 and bidx < len(_FN_REALM.builtins) {
            bname = _FN_REALM.builtins[bidx].name;
        }
        if len(bname) == 0 {
            bname = "anonymous";
        }
        return _fn_js_str("function " + bname + "() { [native code] }");
    }
    if is_fn_val(fn_val) {
        idx: int = get_fn_idx(fn_val);
        # Source text lives on the closure's CompiledFunction (closures[idx].func.source),
        # which the compiler always populates. Read it FIRST so a user function
        # stringifies to its real source (ES §20.2.3.5), matching the VM path and
        # the String()/dispatch path; JSFunctionMeta.source is not always populated.
        if idx < len(_FN_REALM.closures) {
            csrc0: str = _FN_REALM.closures[idx].func.source;
            if len(csrc0) > 0 {
                return _fn_js_str(csrc0);
            }
        }
        if idx < len(_FN_REALM.functions) {
            meta: JSFunctionMeta = _FN_REALM.functions[idx];
            if len(meta.source) > 0 {
                return _fn_js_str(meta.source);
            }
            fname: str = meta.name;
            if len(fname) == 0 {
                fname = "anonymous";
            }
            return _fn_js_str("function " + fname + "() { [native code] }");
        }
        if idx < len(_FN_REALM.closures) {
            cname: str = _FN_REALM.closures[idx].func.name;
            if len(cname) == 0 {
                cname = "anonymous";
            }
            return _fn_js_str("function " + cname + "() { [native code] }");
        }
    }
    return _fn_js_str("function anonymous() { [native code] }");
}

"""Create a JSValue with tag=String from a Jac str."""
def _fn_js_str(s: str) -> JSValue {
    return jsv_from_string_id(str_heap(s));  # G1.5: fn source (toString) is a transient value
}

"""
Return the fn_props backing JSObject for a JS closure value.

Every JS-defined closure has a fn_props field (a plain JS_CELL_KIND_OBJECT)
that stores user-defined properties set via assignment or Object.defineProperty.
Returns js_undefined() if v is not a closure or the index is out of range.

Used by js_Object_defineProperty to redirect property definitions onto
the closure's backing object.
ECMAScript §10.2 (ordinary function objects are objects).
"""
def:pub js_fn_get_fn_props(v: JSValue) -> JSValue {
    if not is_fn_val(v) {
        return js_undefined();
    }
    idx: int = get_fn_idx(v);
    if idx < len(_FN_REALM.closures) {
        return _FN_REALM.closures[idx].fn_props;
    }
    return js_undefined();
}

"""Public predicate: True if v encodes a JS-defined closure (not a built-in)."""
def:pub js_is_fn_val(v: JSValue) -> bool {
    return is_fn_val(v);
}
