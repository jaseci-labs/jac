"""A kernel target points the kernel's package predicates at a foreign tree.

A stage-0 compiler builds the kernel for another jaclang tree (a staging copy
of the PR's sources) by installing a `KernelTarget` spec. With the spec
installed, the kernel root, the native-scope paths, the package-relative arch
scope and the placement tables all read from the target tree, while the unit
identities stay what they are in-tree, so the classes the kernel defines keep
their names. With no spec, every accessor falls back to the running package.
"""
import os;
import shutil;
import tempfile;
import from jaclang.compiler.frontend.codeinfo {
    is_kernel_unit_path,
    jaclang_pkg_root,
    native_arch_scope,
    native_stdlib_root,
    native_unit_identity
}
import from jaclang.compiler.kernel_target {
    KERNEL_TARGET_FORMAT,
    KernelTarget,
    active_kernel_target,
    is_target_package_path,
    read_kernel_target,
    set_kernel_target,
    target_pkg_root,
    write_kernel_target
}
import from jaclang.compiler.native_scope { kernel_root_path, native_scope_paths }
import from jaclang.compiler.placement.placement_facts { native_only }
import from jaclang.compiler.backends.native.kernel_stage0 {
    STAGE0_UNKNOWN_FORMAT,
    build_target_kernel,
    running_kernel_target
}
import from jaclang.project.modresolver { resolve_module }

"""Copy the running jaclang tree under `dst`, sources only; the vendored
typeshed is linked rather than copied."""
def _stage_copy(dst: str) -> str {
    src = jaclang_pkg_root();
    target = os.path.join(dst, "jaclang");
    shutil.copytree(
        src,
        target,
        ignore=shutil.ignore_patterns(
            "__pycache__", "_precompiled", "*.so", "*.so.*", "vendor", ".jac"
        )
    );
    os.symlink(os.path.join(src, "vendor"), os.path.join(target, "vendor"));
    return target;
}

test "a kernel target round-trips through its JSON form" {
    spec = running_kernel_target("/somewhere/jaclang");
    tmp = tempfile.mkdtemp(prefix="jac_kernel_target_");
    try {
        path = os.path.join(tmp, "target.json");
        write_kernel_target(spec, path);
        back = read_kernel_target(path);
        assert back is not None;
        assert back.to_dict() == spec.to_dict();
        assert back.root_module_path() == "/somewhere/jaclang/compiler/jc_unit.jac";
        # A format this compiler does not know is refused, and the stage-0
        # entry reports it with the status that sends the caller back to a
        # self-build.
        unknown = spec.to_dict();
        unknown["format"] = KERNEL_TARGET_FORMAT + 1;
        import json;
        with open(path, "w") as f {
            json.dump(unknown, f);
        }
        assert read_kernel_target(path) is None;
        assert build_target_kernel(path, os.path.join(tmp, "k.so"))
            == STAGE0_UNKNOWN_FORMAT;
        assert active_kernel_target() is None , "a refused spec must not be installed";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "a kernel target retargets the package predicates at a staging copy" {
    tmp = tempfile.mkdtemp(prefix="jac_kernel_stage_");
    prev = active_kernel_target();
    try {
        copy = _stage_copy(tmp);
        unitree_copy = os.path.join(copy, "compiler", "frontend", "unitree.jac");
        unitree_self = os.path.join(
            jaclang_pkg_root(), "compiler", "frontend", "unitree.jac"
        );
        # Without a spec the copy is a foreign tree: its classes would be
        # renamed with a per-file scope suffix.
        assert target_pkg_root() == jaclang_pkg_root();
        assert native_arch_scope(unitree_copy) != "";
        assert native_arch_scope(unitree_self) == "";
        identity = native_unit_identity(unitree_self);

        set_kernel_target(running_kernel_target(copy));
        real_copy = os.path.realpath(copy) + os.sep;
        assert os.path.realpath(kernel_root_path()).startswith(real_copy) , kernel_root_path();
        for p in native_scope_paths() {
            assert os.path.realpath(p).startswith(real_copy) , p;
        }
        assert is_target_package_path(unitree_copy);
        assert not is_target_package_path(unitree_self);
        assert native_arch_scope(unitree_copy) == "";
        assert native_unit_identity(unitree_copy) == identity;
        assert is_kernel_unit_path(os.path.join(copy, "runtime", "osp_kernel.jac"));
        assert os.path.realpath(str(native_stdlib_root())).startswith(real_copy);
        assert native_only(os.path.join(copy, "compiler", "jc_unit.jac"));
        (resolved, lang) = resolve_module(
            "jaclang.compiler.frontend.unitree",
            os.path.join(copy, "compiler", "jc_unit.jac")
        );
        assert lang == "jac" , lang;
        assert os.path.realpath(resolved) == os.path.realpath(unitree_copy) , resolved;
    } finally {
        set_kernel_target(prev);
        shutil.rmtree(tmp, ignore_errors=True);
    }
    assert target_pkg_root() == jaclang_pkg_root();
    assert native_arch_scope(unitree_copy) != "";
}

test "only a kernel target's units share module cache files across trees" {
    import from jaclang.compiler.driver.jir { get_module_cache_path }
    tmp = tempfile.mkdtemp(prefix="jac_kernel_cache_names_");
    prev = active_kernel_target();
    rel = os.path.join("compiler", "frontend", "unitree.jac");
    try {
        first = _stage_copy(os.path.join(tmp, "a"));
        second = _stage_copy(os.path.join(tmp, "b"));
        # A checkout and a kit (or two checkouts) share an identity and a
        # compiler generation; without a target their entries stay apart.
        running = get_module_cache_path(os.path.join(jaclang_pkg_root(), rel));
        assert get_module_cache_path(os.path.join(first, rel)) != running;
        assert get_module_cache_path(os.path.join(first, rel))
            != get_module_cache_path(os.path.join(second, rel));

        set_kernel_target(running_kernel_target(first));
        shared = get_module_cache_path(os.path.join(first, rel));
        set_kernel_target(running_kernel_target(second));
        assert get_module_cache_path(os.path.join(second, rel)) == shared;
    } finally {
        set_kernel_target(prev);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
