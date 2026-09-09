"""The native scope: the list of compiler modules served from libjac_compiler.

An entry joins `NATIVE_SCOPE` when the full suite is green with it in and its
equivalence fixture exists. The built image's manifest must agree with the
file exactly; an empty scope is an image with no `native` record at all.
"""
import from jaclang.compiler.native_scope { NATIVE_SCOPE }
import from jaclang.jac0core.sealed { _jaclang_image }

def _served_by_image -> set[str] {
    image = _jaclang_image();
    if image is None {
        return set();
    }
    native = image.manifest.get("native") or {};
    return set(native.get("modules") or []);
}

test "the running image serves exactly the scope" {
    assert _served_by_image() == set(NATIVE_SCOPE);
}

test "native scope contains unique jaclang module names" {
    assert len(set(NATIVE_SCOPE)) == len(NATIVE_SCOPE);
    for module in NATIVE_SCOPE {
        assert module.startswith("jaclang.") , module;
    }
}
