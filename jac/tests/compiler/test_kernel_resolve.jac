"""`resolve_kernel()` is the one kernel lookup (#8943).

Its precedence is fixed: the explicit switch, the sealed image, the source
tree by plan digest, then the store parser when there is no toolchain. A
source tree with no kernel derives one on the first parse; a kernel whose
sidecar plan digest disagrees with the plan the cache computes is rebuilt;
nothing raises about a missing kernel a build could make.
"""

import json;
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.kernel_resolve {
    KERNEL_LIB_ENV,
    KernelUnavailable,
    read_sidecar,
    resolve_kernel,
    source_tree_kernel_path
}
import from jaclang.compiler.native_compiler { ensure_loaded, reset_loaded }

def _with_env(name: str, value: (str | None), fn: any) -> any {
    prev = os.environ.get(name);
    if value is None {
        os.environ.pop(name, None);
    } else {
        os.environ[name] = value;
    }
    try {
        return fn();
    } finally {
        if prev is None {
            os.environ.pop(name, None);
        } else {
            os.environ[name] = prev;
        }
    }
}

test "the off switch selects the store parser" {
    reset_loaded();
    try {
        assert _with_env(KERNEL_LIB_ENV, "off", lambda () { resolve_kernel(); }) is None;
        assert _with_env(KERNEL_LIB_ENV, "off", lambda () { ensure_loaded(); }) is None;
    } finally {
        reset_loaded();
    }
}

test "the catalog build never loads a kernel" {
    reset_loaded();
    try {
        assert _with_env("JAC_STUBCAT_BUILDING", "1", lambda () { resolve_kernel(); }) is None;
    } finally {
        reset_loaded();
    }
}

test "an explicit path must carry its sidecar" {
    tmp = tempfile.mkdtemp(prefix="jac-kernel-");
    bogus = os.path.join(tmp, "libjac_compiler.so");
    Path(bogus).write_bytes(b"not a library");
    raised = False;
    try {
        _with_env(KERNEL_LIB_ENV, bogus, lambda () { resolve_kernel(); });
    } except KernelUnavailable {
        raised = True;
    }
    assert raised , "a kernel path without its .layout.json sidecar is refused";
}

test "the sidecar reader wants a classes map" {
    tmp = tempfile.mkdtemp(prefix="jac-kernel-");
    lib = os.path.join(tmp, "libjac_compiler.so");
    Path(lib + ".layout.json").write_text(json.dumps({"plan_digest": "x"}));
    assert read_sidecar(lib) is None;
    Path(lib + ".layout.json").write_text(
        json.dumps({"classes": {}, "plan_digest": "x", "layout_digest": "y"})
    );
    found = read_sidecar(lib);
    assert found is not None and found["plan_digest"] == "x";
}

test "the source-tree kernel lives beside the loader" {
    path = source_tree_kernel_path();
    assert os.path.basename(os.path.dirname(path)) == "compiler";
    assert "jac_compiler" in os.path.basename(path);
}
