"""A seal adopts a prebuilt kernel only when it was built from the sealed tree.

One builder makes every target's kernel (#10219) and each platform's seal
adopts its own. Adoption checks the kernel the way the kit tier does at load:
the recorded unit sources, codegen, target and Python must match the tree
being sealed. A refused kernel is never copied into the package.
"""
import json;
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.dist.precompile_bytecode { adopt_kernel }
import from jaclang.compiler.backends.native.kernel_resolve { kernel_lib_name }
import from jaclang.compiler.target_spec { host_target_spec }

def _pkg_root -> Path {
    import jaclang;
    return Path(jaclang.__file__).resolve().parent;
}

def _refusal(kernel_dir: str) -> str {
    with tempfile.TemporaryDirectory(prefix="jac-adopt-out-") as out {
        try {
            adopt_kernel(_pkg_root(), Path(out), {}, kernel_dir);
        } except RuntimeError as err {
            return str(err);
        }
    }
    return "";
}

test "a directory without a kernel and its sidecar is refused" {
    with tempfile.TemporaryDirectory(prefix="jac-adopt-") as kdir {
        told = _refusal(kdir);
        assert "holds no" in told , told;
    }
}

test "a kernel built from other sources is refused and not copied in" {
    target = _pkg_root() / "compiler" / kernel_lib_name();
    before = target.read_bytes() if target.is_file() else None;
    with tempfile.TemporaryDirectory(prefix="jac-adopt-") as kdir {
        lib = Path(kdir) / kernel_lib_name();
        lib.write_bytes(b"not a kernel");
        ident = "jaclang/compiler/target_spec.jac";
        sidecar = {
            "unit_ids": [ident],
            "units": [str(_pkg_root() / "compiler" / "target_spec.jac")],
            "unit_sources": {ident: "0" * 64},
            "unit_policy": {ident: 0},
            "triple": host_target_spec().triple,
            "python": "3.14",
            "compiler_digest": "elsewhere",
            "codegen_identity": "elsewhere",
            "classes": {}
        };
        Path(str(lib) + ".layout.json").write_text(json.dumps(sidecar));
        told = _refusal(kdir);
        assert "was not built from this tree" in told , told;
        assert "target_spec.jac changed" in told , told;
    }
    after = target.read_bytes() if target.is_file() else None;
    assert before == after;
}

test "a kernel naming units this tree lacks is refused" {
    with tempfile.TemporaryDirectory(prefix="jac-adopt-") as kdir {
        lib = Path(kdir) / kernel_lib_name();
        lib.write_bytes(b"not a kernel");
        ident = "jaclang/compiler/no_such_unit.jac";
        sidecar = {
            "unit_ids": [ident],
            "units": [ident],
            "unit_sources": {ident: "0" * 64},
            "classes": {}
        };
        Path(str(lib) + ".layout.json").write_text(json.dumps(sidecar));
        told = _refusal(kdir);
        assert "lacks" in told and "no_such_unit.jac" in told , told;
    }
}
