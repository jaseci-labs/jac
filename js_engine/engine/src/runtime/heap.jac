"""
GC Handles
Jac-native memory model for js_engine.

Jac native compiles every `obj` instantiation to a Boehm GC_malloc call and
traces all struct fields automatically.  There is no need for a manual heap
manager — the runtime already handles allocation, tracing, and collection.

 therefore provides two thin reference wrappers built on top of
Jac's implicit GC:

  JSHandle   — short-lived pin.  Keeps a JSValue reachable across a scope that
               might otherwise let it become unreachable.
               (mirrors a stack-pinned JSValue in a native C extension)

  StrongRef  — long-lived strong reference.  For global slots, prototype chain
               entries, registered callbacks — anything that must outlive normal
               stack lifetimes.
               (mirrors bun/src/bun.js/Strong.zig)

Factory functions (module-level, same idiom as jsvalue.na.jac):
  js_handle(v: JSValue) -> JSHandle
  js_strong_ref(v: JSValue) -> StrongRef
"""

import from engine.src.runtime.jsvalue { JSValue, jsv_undefined }


# ═══════════════════════════════════════════════════════════════════════════════
# JSHandle — short-lived GC-rooted reference
# ═══════════════════════════════════════════════════════════════════════════════

"""
A short-lived, GC-rooted wrapper around a JSValue.

Because JSHandle is a Jac `obj`, the runtime allocates it on the GC heap and
traces its `value` field.  The wrapped JSValue (and any heap data it points to
via `as_ptr`) will not be collected for as long as this handle is reachable.

Lifecycle:  js_handle(v) → get() / set() → release()
"""
obj:pub JSHandle {
    has value: JSValue;

    """Read the pinned value."""
    def:pub get -> JSValue {
        return self.value;
    }

    """Replace the pinned value (re-pin a different JSValue)."""
    def:pub set(v: JSValue) -> int {
        self.value = v;
        return 0;
    }

    """
    Drop the pin: reset stored value to `undefined`.
    The GC may reclaim whatever the previous value referenced once no other
    fields point to it.  Returns 0.
    """
    def:pub release -> int {
        self.value = jsv_undefined();
        return 0;
    }
}

"""Pin `v` under a new short-lived GC handle."""
def:pub js_handle(v: JSValue) -> JSHandle {
    return JSHandle(value=v);
}


# ═══════════════════════════════════════════════════════════════════════════════
# StrongRef — permanent strong reference
# ═══════════════════════════════════════════════════════════════════════════════

"""
A long-lived strong reference to a JSValue.

Semantics identical to JSHandle but documents intent: this reference is
intended to outlive the current call frame — e.g. a global object slot,
a prototype chain entry, or a registered callback.

Lifecycle:  js_strong_ref(v) → get() / set() → deinit()

Bun Zig equivalent: Strong / Strong.Impl (bun/src/bun.js/Strong.zig).
"""
obj:pub StrongRef {
    has value: JSValue;

    """Read the strongly-held value. (Bun Zig: Strong.get)"""
    def:pub get -> JSValue {
        return self.value;
    }

    """Replace the strongly-held value. (Bun Zig: Strong.set)"""
    def:pub set(v: JSValue) -> int {
        self.value = v;
        return 0;
    }

    """
    Release the strong reference: reset to `undefined`.
    After this the GC may collect the previously held value if nothing else
    references it.  (Bun Zig: Strong.deinit)
    """
    def:pub deinit -> int {
        self.value = jsv_undefined();
        return 0;
    }
}

"""Create a long-lived strong reference to `v`. (Bun Zig: Strong.create)"""
def:pub js_strong_ref(v: JSValue) -> StrongRef {
    return StrongRef(value=v);
}
