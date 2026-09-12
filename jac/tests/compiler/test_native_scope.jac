"""The native scope: the list of compiler modules served from libjac_compiler.

An entry joins `NATIVE_SCOPE` when the full suite is green with it in and its
equivalence fixture exists. The built image's manifest must agree with the
file exactly; an empty scope is an image with no `native` record at all.
"""
import from jaclang.compiler.native_scope { NATIVE_SCOPE, NativeScopeEntry }
import from jaclang.compiler.driver.image { _jaclang_image }

def _served_by_image -> set[str] {
    image = _jaclang_image();
    if image is None {
        return set();
    }
    native = image.manifest.get("native") or {};
    return set(native.get("modules") or []);
}

test "the running image serves exactly the scope" {
    assert _served_by_image() == {e.module for e in NATIVE_SCOPE};
}

test "every scope entry is a jaclang module with a default-off strict flag" {
    for e in NATIVE_SCOPE {
        assert isinstance(e, NativeScopeEntry);
        assert e.module.startswith("jaclang.") , e.module;
        assert isinstance(e.strict, bool);
    }
}
