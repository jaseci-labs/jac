"""Generated-style intrinsic manifest tables consumed by realm bootstrap.

Source of truth for names: engine/src/runtime/intrinsic_manifest.json.
Keep these lists in sync when editing the JSON (build-time codegen may
replace this file later).
"""

"""Identity-sensitive binary / reflection globals that must not be shared by
object identity across realms (fresh ctor/proto per realm)."""
glob:pub INTRINSIC_IDENTITY_SENSITIVE: list[str] = [
         "ArrayBuffer",
         "SharedArrayBuffer",
         "DataView",
         "TypedArray",
         "Int8Array",
         "Uint8Array",
         "Uint8ClampedArray",
         "Int16Array",
         "Uint16Array",
         "Int32Array",
         "Uint32Array",
         "Float16Array",
         "Float32Array",
         "Float64Array",
         "BigInt64Array",
         "BigUint64Array",
         "Atomics",
         "Reflect",
         "ShadowRealm"
     ];

"""Capability names that remain explicitly deferred (attribution allowlist)."""
glob:pub INTRINSIC_DEFERRED_CAPABILITIES: list[str] = [
         "AbstractModuleSource",
         "ShadowRealm.importValue module loading",
         "multi-agent Atomics wait/notify"
     ];

def:pub intrinsic_is_identity_sensitive(name: str) -> bool {
    for n in INTRINSIC_IDENTITY_SENSITIVE {
        if n == name {
            return True;
        }
    }
    return False;
}

def:pub intrinsic_is_deferred_capability(name: str) -> bool {
    for n in INTRINSIC_DEFERRED_CAPABILITIES {
        if n == name {
            return True;
        }
    }
    return False;
}
