"""
Error Types & Exception Hierarchy.

Implements the seven standard JS error constructors and their prototype objects.
Each error is a plain JSObject with `name`, `message`, and `stack` properties
set on it and a prototype that inherits from the shared ERROR_PROTO.

Bun reference   : bun/src/bun.js/bindings/ErrorCode.zig
                  JSC native error types in JSC Error.h / ErrorPrototype
ECMAScript spec : §20.5 — Error Objects
                  https://tc39.es/ecma262/#sec-error-objects

Design note on format_stack / CallFrame:
  This module intentionally does NOT import CallFrame from vm/vm.na.jac.
  Doing so would create a circular dependency (runtime → vm → runtime).
  Instead format_stack accepts a pre-built list[str] of frame labels
  (e.g. ["fact (<anonymous>:1:30)", "outer (<anonymous>:1:52)"]).
  The VM builds these strings and calls format_stack / attach_stack itself.
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_from_int32,
    jsv_to_int32,
    jsv_is_int32,
    jsv_from_string_id,
    jsv_to_table_id,
    jsv_is_string_cell
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_get,
    js_object_set,
    js_object_define_nonenum
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.gc_pin { gc_pin_value }

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Well-known string key IDs
#     These are materialised on first use via str_intern.
# ══════════════════════════════════════════════════════════════════════════════

"""Return the interned key id for "message"."""
def key_message -> int {
    return str_intern("message");
}

"""Return the interned key id for "stack"."""
def:pub key_stack -> int {
    return str_intern("stack");
}

"""Interned key id for the INTERNAL captured-stack slot. Error.prototype.stack is a
V8-style accessor (get/set) whose getter reads this slot; instances therefore carry no
own "stack" data property (§ Error.prototype.stack is not per-instance)."""
def:pub key_stack_internal -> int {
    return str_intern("__errorStackData__");
}

"""Return the interned key id for "name"."""
def key_name -> int {
    return str_intern("name");
}

# ══════════════════════════════════════════════════════════════════════════════
# 2.  Prototype objects
#     All seven error types share ERROR_PROTO as the root; subtype protos
#     inherit from it via js_object_create(ERROR_PROTO).
#
#     The protos are initialised lazily (first access) because object creation
#     requires the string-intern table to be live; globs try to run before
#     module inits complete on some import paths.
# ══════════════════════════════════════════════════════════════════════════════

# Sentinel: as_int == 0 on tag=Int32 means uninitialised (safe because a valid
# JSObject value will have tag=Object, never Int32).
glob _ERROR_PROTO: JSValue = jsv_from_int32(0),
     _TYPE_ERROR_PROTO: JSValue = jsv_from_int32(0),
     _REFERENCE_ERROR_PROTO: JSValue = jsv_from_int32(0),
     _SYNTAX_ERROR_PROTO: JSValue = jsv_from_int32(0),
     _RANGE_ERROR_PROTO: JSValue = jsv_from_int32(0),
     _URI_ERROR_PROTO: JSValue = jsv_from_int32(0),
     _EVAL_ERROR_PROTO: JSValue = jsv_from_int32(0);

"""True if v is an uninitialised proto sentinel."""
def _proto_uninit(v: JSValue) -> bool {
    return jsv_is_int32(v) and jsv_to_int32(v) == 0;
}

"""Build a JSString JSValue wrapping a raw Jac string."""
def _js_string(s: str) -> JSValue {
    return jsv_from_string_id(str_intern(s));
}

"""Internal: return the Error proto as JSValue (used by sub-proto lazy init)."""
def get_error_proto_impl -> JSValue {
    if _proto_uninit(_ERROR_PROTO) {
        p: JSValue = js_object_create_null();
        js_object_define_nonenum(p, key_name(), _js_string("Error"));
        js_object_define_nonenum(p, key_message(), _js_string(""));
        # Error.prototype.stack is an accessor installed post-bootstrap (V8 model), not a data property.
        _ERROR_PROTO = p;
        gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
    }
    return _ERROR_PROTO;
}

"""
Lazily create and return the shared Error prototype.

Bun Zig equivalent: JSC::ErrorPrototype
"""
def:pub get_error_proto -> JSValue {
    if _proto_uninit(_ERROR_PROTO) {
        p: JSValue = js_object_create_null();
        js_object_define_nonenum(p, key_name(), _js_string("Error"));
        js_object_define_nonenum(p, key_message(), _js_string(""));
        # Error.prototype.stack is an accessor installed post-bootstrap (V8 model), not a data property.
        _ERROR_PROTO = p;
        gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
    }
    return _ERROR_PROTO;
}

"""Lazily create and return the TypeError prototype (inherits from Error.prototype)."""
def:pub get_type_error_proto -> JSValue {
    if _proto_uninit(_TYPE_ERROR_PROTO) {
        p: JSValue = js_object_create(get_error_proto_impl());
        js_object_define_nonenum(p, key_name(), _js_string("TypeError"));
        _TYPE_ERROR_PROTO = p;
        gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
    }
    return _TYPE_ERROR_PROTO;
}

"""Lazily create and return the ReferenceError prototype."""
def:pub get_reference_error_proto -> JSValue {
    if _proto_uninit(_REFERENCE_ERROR_PROTO) {
        p: JSValue = js_object_create(get_error_proto_impl());
        js_object_define_nonenum(p, key_name(), _js_string("ReferenceError"));
        _REFERENCE_ERROR_PROTO = p;
        gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
    }
    return _REFERENCE_ERROR_PROTO;
}

"""Lazily create and return the SyntaxError prototype."""
def:pub get_syntax_error_proto -> JSValue {
    if _proto_uninit(_SYNTAX_ERROR_PROTO) {
        p: JSValue = js_object_create(get_error_proto_impl());
        js_object_define_nonenum(p, key_name(), _js_string("SyntaxError"));
        _SYNTAX_ERROR_PROTO = p;
        gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
    }
    return _SYNTAX_ERROR_PROTO;
}

"""Lazily create and return the RangeError prototype."""
def:pub get_range_error_proto -> JSValue {
    if _proto_uninit(_RANGE_ERROR_PROTO) {
        p: JSValue = js_object_create(get_error_proto_impl());
        js_object_define_nonenum(p, key_name(), _js_string("RangeError"));
        _RANGE_ERROR_PROTO = p;
        gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
    }
    return _RANGE_ERROR_PROTO;
}

"""Lazily create and return the URIError prototype."""
def:pub get_uri_error_proto -> JSValue {
    if _proto_uninit(_URI_ERROR_PROTO) {
        p: JSValue = js_object_create(get_error_proto_impl());
        js_object_define_nonenum(p, key_name(), _js_string("URIError"));
        _URI_ERROR_PROTO = p;
        gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
    }
    return _URI_ERROR_PROTO;
}

"""Lazily create and return the EvalError prototype."""
def:pub get_eval_error_proto -> JSValue {
    if _proto_uninit(_EVAL_ERROR_PROTO) {
        p: JSValue = js_object_create(get_error_proto_impl());
        js_object_define_nonenum(p, key_name(), _js_string("EvalError"));
        _EVAL_ERROR_PROTO = p;
        gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
    }
    return _EVAL_ERROR_PROTO;
}

# ══════════════════════════════════════════════════════════════════════════════
# 3.  Core factory
# ══════════════════════════════════════════════════════════════════════════════

"""
Create an Error JSObject with `name`, `message`, and `stack` properties.

  name    — e.g. "TypeError"
  message — developer-supplied message string
  proto   — the subtype prototype to inherit from

Bun Zig: JSC::ErrorInstance (JSObject subclass with message/stack fields)
ECMAScript spec: §20.5.5 Properties of Error Instances
"""
def:pub create_error(name: str, message: str, proto: JSValue) -> JSValue {
    err: JSValue = js_object_create(proto);
    # ES §20.5.5 / §20.5.1.1: an Error instance gets `message` as an own
    # { w:T, e:F, c:T } property ONLY when a non-empty message was supplied — an
    # empty message leaves the inherited Error.prototype.message visible. `name`
    # is NEVER an own property; it is inherited from the prototype (adel_fixes
    # added an own `name`, which is spec-incorrect — dropped).
    #
    # Merge note: HEAD previously kept `message` ENUMERABLE as a workaround
    # because the class-subclassing path in vm.na.jac dropped non-enumerable
    # props. That path now copies full descriptors via js_object_all_keys +
    # js_object_get_own_property_descriptor (vm.na.jac ~13574), so non-enumerable
    # message propagates correctly — the workaround is obsolete, and the
    # spec-correct non-enumerable form is restored.
    if len(message) > 0 {
        js_object_define_nonenum(err, key_message(), _js_string(message));
    }
    # The captured stack lives in an INTERNAL slot; `err.stack` is served by the
    # accessor inherited from Error.prototype (V8 model), so instances have no own
    # "stack" data property. Non-enumerable / non-configurable internal storage.
    js_object_define_nonenum(
        err, key_stack_internal(), _js_string(name + ": " + message)
    );
    return err;
}

# ══════════════════════════════════════════════════════════════════════════════
# 4.  Native error constructors
#     Each matches a JSC::create*Error() helper in Error.h.
# ══════════════════════════════════════════════════════════════════════════════

"""Create a plain Error — catch-all when no more specific type applies."""
def:pub make_error(message: str) -> JSValue {
    return create_error("Error", message, get_error_proto());
}

"""
Create a TypeError.

Bun Zig: JSC::createTypeError()   Error.h
Thrown by the VM when an operation is applied to a wrong type
(e.g. calling a non-function).
"""
def:pub make_type_error(message: str) -> JSValue {
    return create_error("TypeError", message, get_type_error_proto());
}

"""
Create a ReferenceError.

Bun Zig: JSC::createReferenceError()   Error.h
Thrown when an undeclared identifier is read in strict mode.
"""
def:pub make_reference_error(message: str) -> JSValue {
    return create_error("ReferenceError", message, get_reference_error_proto());
}

"""
Create a SyntaxError.

Bun Zig: JSC::createSyntaxError()   Error.h
Thrown by the parser when source text is malformed.
"""
def:pub make_syntax_error(message: str) -> JSValue {
    return create_error("SyntaxError", message, get_syntax_error_proto());
}

"""
Create a RangeError.

Bun Zig: JSC::createRangeError()   Error.h
Thrown for values outside an allowed range (e.g. stack overflow, invalid array length).
"""
def:pub make_range_error(message: str) -> JSValue {
    return create_error("RangeError", message, get_range_error_proto());
}

"""
Create a URIError.

Thrown by decodeURI / encodeURI on malformed URI sequences.
"""
def:pub make_uri_error(message: str) -> JSValue {
    return create_error("URIError", message, get_uri_error_proto());
}

"""
Create an EvalError.

Largely historical; thrown by eval() in some edge cases.
"""
def:pub make_eval_error(message: str) -> JSValue {
    return create_error("EvalError", message, get_eval_error_proto());
}

"""Create a Node-style Error with a `code` property (e.g. MODULE_NOT_FOUND)."""
def:pub make_coded_error(
    name: str, message: str, code: str, proto: JSValue
) -> JSValue {
    err: JSValue = create_error(name, message, proto);
    js_object_set(err, str_intern("code"), _js_string(code));
    return err;
}

def:pub make_module_not_found(message: str) -> JSValue {
    return make_coded_error("Error", message, "MODULE_NOT_FOUND", get_error_proto());
}

def:pub make_err_esm_module_not_found(message: str) -> JSValue {
    return make_coded_error(
        "Error", message, "ERR_MODULE_NOT_FOUND", get_error_proto()
    );
}

def:pub make_err_package_path_not_exported(message: str) -> JSValue {
    return make_coded_error(
        "Error", message, "ERR_PACKAGE_PATH_NOT_EXPORTED", get_error_proto()
    );
}

def:pub make_err_invalid_package_target(message: str) -> JSValue {
    return make_coded_error(
        "Error", message, "ERR_INVALID_PACKAGE_TARGET", get_error_proto()
    );
}

def:pub make_err_require_esm(message: str) -> JSValue {
    return make_coded_error("Error", message, "ERR_REQUIRE_ESM", get_error_proto());
}

"""Thrown when require() loads an ES module whose evaluation depends on
unresolved top-level await (Node 22+ ERR_REQUIRE_ASYNC_MODULE)."""
def:pub make_err_require_async_module(message: str) -> JSValue {
    return make_coded_error(
        "Error", message, "ERR_REQUIRE_ASYNC_MODULE", get_error_proto()
    );
}

"""Node-compatible ERR_REQUIRE_ASYNC_MODULE with From/Requiring suffixes."""
def:pub make_err_require_async_module_full(
    filename: str, parent_filename: str
) -> JSValue {
    message: str = (
        "require() cannot be used on an ESM graph with top-level await. Use "
        + "import() instead. To see where the top-level await comes from, use "
        + "--experimental-print-required-tla."
    );
    if parent_filename != "" {
        message = message + "\n  From " + parent_filename + " ";
    }
    if filename != "" {
        message = message + "\n  Requiring " + filename + " ";
    }
    return make_err_require_async_module(message);
}

def:pub make_err_package_import_not_defined(message: str) -> JSValue {
    return make_coded_error(
        "Error", message, "ERR_PACKAGE_IMPORT_NOT_DEFINED", get_error_proto()
    );
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  Stack trace helpers
# ══════════════════════════════════════════════════════════════════════════════

"""
Format a V8-style stack trace string from a list of frame label strings.

Each element of `frame_labels` should be a pre-built string of the form:
  "functionName (filename:line:col)"
  (or just "functionName" when no source position is available).

The caller (VM) builds these strings from its CallFrame list before calling
this function, so that error.na.jac avoids importing vm/vm.na.jac.

Example output:
  "TypeError: bad arg\n    at foo (src.js:3:5)\n    at bar (src.js:10:1)"

Bun Zig: JSC::getStackTrace() + VirtualMachine.zig formatUnhandledException
ECMAScript spec: §20.5.3.3  Error.prototype.stack (de-facto standard)
"""
def:pub format_stack(error_name: str, message: str, frame_labels: list[str]) -> str {
    result: str = error_name + ": " + message;
    i: int = 0;
    while i < len(frame_labels) {
        result = result + "\n    at " + frame_labels[i];
        i = i + 1;
    }
    return result;
}

"""
Attach a formatted stack trace string to an existing Error JSObject.

Sets (or overwrites) the `stack` property.

Bun Zig: JSC::createStackTrace + ErrorInstance::finishCreation
"""
def:pub attach_stack(err: JSValue, stack_str: str) -> int {
    return js_object_set(err, key_stack_internal(), _js_string(stack_str));
}

"""
Read the `message` string from an Error object (or any JSValue).

Returns the raw Jac string, not a JSValue.  Used by the VM when it needs
to forward the message into a new error.
"""
def:pub error_message(err: JSValue) -> str {
    if jsv_is_object_cell(err) {
        msg: JSValue = js_object_get(err, key_message());
        if jsv_is_string_cell(msg) {
            return str_from_id(jsv_to_table_id(msg));
        }
    }
    if jsv_is_string_cell(err) {
        # Raw string was thrown (e.g. `throw "oops"`)
        return str_from_id(jsv_to_table_id(err));
    }
    return "(unknown error)";
}

"""
Read the `name` string from an Error object, or return "Error" as default.
"""
def:pub error_name(err: JSValue) -> str {
    if jsv_is_object_cell(err) {
        nm: JSValue = js_object_get(err, key_name());
        if jsv_is_string_cell(nm) {
            return str_from_id(jsv_to_table_id(nm));
        }
    }
    return "Error";
}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  Native exception side-channel
# ══════════════════════════════════════════════════════════════════════════════

"""
Global side-channel for native builtins (JSON.parse, decodeURI, etc.) to
signal a thrown exception back to the VM without needing a direct VM reference.

Flow:
  1. Builtin calls vm_throw_native(err) + returns js_undefined().
  2. After call_native() returns, the VM checks vm_has_native_exc().
  3. If true, vm_take_native_exc() retrieves the exception and the VM
     enters _unwind_in_frame() — the normal THROW path.

This avoids auto-detecting error objects (which would break `new Error()`
and other intentional error-object returns).
"""
glob _HAS_NATIVE_EXC: bool = False;
glob _NATIVE_EXC: int = 0;

"""Signal that a native builtin wants to throw `err`."""
def:pub vm_throw_native(err: JSValue) {
    _HAS_NATIVE_EXC = True;
    _NATIVE_EXC = err;
}

"""Check whether a native exception is pending."""
def:pub vm_has_native_exc -> bool {
    return _HAS_NATIVE_EXC;
}

"""Consume and return the pending native exception, clearing the flag."""
def:pub vm_take_native_exc -> JSValue {
    _HAS_NATIVE_EXC = False;
    exc: int = _NATIVE_EXC;
    _NATIVE_EXC = 0;
    return exc;
}
