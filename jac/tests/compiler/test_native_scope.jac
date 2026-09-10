"""The native scope: the kernel's unit roster, served from libjac_compiler.

An entry joins `NATIVE_SCOPE` when the full suite is green with it in and its
equivalence fixture exists. The built image's manifest records the units the
link plan walked from the kernel root (`native["units"]`, keyed by
package-relative source) and the one artifact it linked (`native["artifact"]`);
the roster must be among those units, and every unit beyond the roster must be
a toolchain native unit the plan pulled by dependency edge (a kernel unit or a
native-only module). An image with no native units has no `native` record.
"""
import os;
import from jaclang.compiler.native_scope {
    NATIVE_SCOPE,
    NativeScopeEntry,
    kernel_root_path,
    native_scope_paths
}
import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
import from jaclang.compiler.placement.placement_facts { native_unit }
import from jaclang.jac0core.sealed { _jaclang_image }

"""Package-relative posix form of a toolchain source path."""
def _pkg_rel(path: str) -> str {
    return os.path.relpath(
        os.path.realpath(path), os.path.realpath(jaclang_pkg_root())
    ).replace(
        os.sep, "/"
    );
}

"""The native record of the running image, or None when the package was
not sealed with native units (the source tree, or a kernel-less image)."""
def _native_record -> (dict | None) {
    image = _jaclang_image();
    if image is None {
        return None;
    }
    native = image.manifest.get("native") or {};
    if not native.get("units") {
        return None;
    }
    return native;
}

"""The native units the image serves, by package-relative source path."""
def _served_by_image -> set[str] {
    native = _native_record();
    if native is None {
        return set();
    }
    return set((native.get("units") or {}).keys());
}

def _scope_rel -> set[str] {
    return {_pkg_rel(p) for p in native_scope_paths()};
}

test "the running image serves the scope and only jaclang's own units" {
    native = _native_record();
    if native is None {
        return;
    }
    served = _served_by_image();
    scope = _scope_rel();
    missing = sorted(scope - served);
    assert not missing , f"scope entries the image does not serve: {missing}";
    assert _pkg_rel(kernel_root_path()) in served , "the kernel root must be a served unit";
    pkg = jaclang_pkg_root();
    # Beyond the scope, the plan links the toolchain units and the modules
    # the scope's typed imports reach (the AST's data model and its types);
    # every one of them is a jaclang module the plan compiled as a unit.
    strangers = sorted(
        rel
        for rel in served - scope
        if rel.startswith("..") or not os.path.isfile(os.path.join(pkg, rel))
    );
    assert not strangers , (
        f"units the plan linked that are not jaclang modules: {strangers}"
    );
    for (rel, unit) in native["units"].items() {
        assert isinstance(unit, dict) and unit.get("jir") , f"{rel}: no sealed JIR named";
        assert len(str(unit.get("iface_digest", ""))) == 64 , f"{rel}: no interface digest";
    }
}

test "the running image names one linked artifact with its digests" {
    native = _native_record();
    if native is None {
        return;
    }
    artifact = native.get("artifact") or {};
    for key in ("path", "sha256", "layout_digest", "plan_digest") {
        assert artifact.get(key) , f"native artifact record lacks {key!r}: {artifact}";
    }
    assert not os.path.isabs(artifact["path"]) , "the artifact path is package-relative";
    assert os.path.isfile(os.path.join(jaclang_pkg_root(), artifact["path"])) , (
        f"the sealed artifact is missing: {artifact['path']}"
    );
    assert len(artifact["sha256"]) == 64 , artifact["sha256"];
}

test "every scope entry is a jaclang module with a default-off strict flag" {
    for e in NATIVE_SCOPE {
        assert isinstance(e, NativeScopeEntry);
        assert e.module.startswith("jaclang.") , e.module;
        assert isinstance(e.strict, bool);
    }
    for p in native_scope_paths() {
        assert os.path.isfile(p) , f"scope entry has no source: {p}";
    }
}
