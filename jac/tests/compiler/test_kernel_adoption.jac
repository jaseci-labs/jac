"""A seal adopts the stage-0 kernel only when it was built from the sealed tree.

One builder makes every target's kernel (#10219) and each platform's seal
adopts its own. Adoption reads the kernel's record the way the boot does:
every source the build read must still have the digest the record carries.
A refused kernel is never copied into the package.
"""
import json;
import hashlib;
import tempfile;
import from pathlib { Path }
import from jaclang.dist.precompile_bytecode { adopt_kernel }
import from jaclang.compiler.backends.native.kernel_resolve { kernel_lib_name }
import from jaclang.jac0core.stage0 { RECORD_FORMAT, RECORD_SUFFIX, python_version }

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

def _write_kernel(kdir: str, inputs: dict[str, str]) {
    lib = Path(kdir) / kernel_lib_name();
    lib.write_bytes(b"not a kernel");
    record = {
        "format": RECORD_FORMAT,
        "artifact_sha256": hashlib.sha256(b"not a kernel").hexdigest(),
        "triple": "",
        "python": python_version(),
        "producer": "a test",
        "inputs": inputs
    };
    Path(str(lib) + RECORD_SUFFIX).write_text(json.dumps(record));
    Path(str(lib) + ".layout.json").write_text("{}");
}

test "a directory without a kernel and its record is refused" {
    with tempfile.TemporaryDirectory(prefix="jac-adopt-") as kdir {
        told = _refusal(kdir);
        assert "not built" in told , told;
    }
}

test "a kernel built from other sources is refused and not copied in" {
    target = _pkg_root() / "compiler" / "_kernel" / kernel_lib_name();
    before = target.read_bytes() if target.is_file() else None;
    with tempfile.TemporaryDirectory(prefix="jac-adopt-") as kdir {
        _write_kernel(kdir, {"jaclang/compiler/target_spec.jac": "0" * 64});
        told = _refusal(kdir);
        assert "was not built from this tree" in told , told;
        assert "target_spec.jac changed" in told , told;
    }
    after = target.read_bytes() if target.is_file() else None;
    assert before == after;
}

test "a kernel naming sources this tree lacks is refused" {
    with tempfile.TemporaryDirectory(prefix="jac-adopt-") as kdir {
        _write_kernel(kdir, {"jaclang/compiler/no_such_unit.jac": "0" * 64});
        told = _refusal(kdir);
        assert "no_such_unit.jac is gone" in told , told;
    }
}
