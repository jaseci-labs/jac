"""The LLVM shim links the pinned LLVM, so building it fetches that LLVM
first: `jac native build llvm-shim` works on a fresh checkout, where
`zig build` defines no `jacllvm` step until `zig build fetch-llvm` ran."""

import json;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.compiler.backends.native.llvm.shim_path as shim_path;
import from jaclang.compiler.backends.native.llvm.shim_path { ShimArtifact }

test "a shim build fetches the pinned LLVM before it links the shim" {
    calls: list[list[str]] = [];
    lines: list[str] = [];
    def run(argv: list[str], **kwargs: any) -> any {
        calls.append(list(argv));
        return None;
    }
    with TemporaryDirectory() as tmp {
        with patch("subprocess.run", side_effect=run), patch.object(
            shim_path, "_repo_root", return_value=tmp
        ), patch.object(
            ShimArtifact, "checkout_path", return_value=str(Path(tmp) / "libjacllvm.so")
        ) {
            ShimArtifact().build(lines.append, False, False);
        }
    }
    assert calls
        == [["zig", "build", "fetch-llvm"], ["zig", "build", "jacllvm"]] , calls;
    assert any("fetch-llvm" in line for line in lines) , lines;
}

def _pins(tmp: str, slices: dict[str, any]) {
    os.makedirs(os.path.join(tmp, "bootstrap"));
    Path(tmp, "bootstrap", "pins.json").write_text(
        json.dumps({"llvm": {"slices": slices}})
    );
}

test "a host without a pinned LLVM is a blocker that names the pin" {
    with TemporaryDirectory() as tmp {
        assert "bootstrap/pins.json" in shim_path.pinned_llvm_blocker(tmp);
        _pins(tmp, {"linux-x86_64": {}});
        with patch.object(shim_path, "llvm_host", return_value="linux-x86_64") {
            assert shim_path.pinned_llvm_blocker(tmp) == "";
        }
        with patch.object(shim_path, "llvm_host", return_value="win32-amd64") {
            why = shim_path.pinned_llvm_blocker(tmp);
        }
        assert "win32-amd64" in why and "linux-x86_64" in why , why;
    }
}
