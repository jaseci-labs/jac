"""Kernel compilation units are stable, deterministic, cache-backed (#7963).

The OSP core (osp_kernel + osp_graph) and fmt kernel materialize at stable
paths under the jac cache root, and their derived outputs (kernel JS, kernel
LLVM IR) persist beside them as content-keyed artifacts. These tests pin the
properties the tempfile copy-and-compile scheme could not provide: one stable
identity per variant (no fresh path per process), byte-identical rebuilds,
and a warm second build that reads the artifact instead of recompiling
(observed as the artifact file not being rewritten). That observation is only
truthful because the store is idempotent: the key fixes the content, so a
store of the bytes already at a key leaves the file alone rather than
rewriting it under whatever other process is watching.
"""

import glob;
import os;
import jaclang.compiler.passes.ecmascript.jac_runtime_js as _rtjs;
import jaclang.compiler.passes.native.na_compile_pass as _nacp;
import from jaclang.jac0core.kernel_units {
    OSP_CORE_PARTS,
    osp_core_unit_path,
    store_unit_artifact,
    unit_artifact_path,
    unit_source
}

def _sole_artifact(name: str, kind: str) -> str {
    units_dir = os.path.dirname(osp_core_unit_path('cl'));
    hits = sorted(`glob.`glob(os.path.join(units_dir, f"{name}.*.{kind}")));
    assert len(hits) == 1 , f"expected one {name} {kind} artifact, got {hits}";
    return hits[0];
}

test "unit path is stable and carries the exact concatenated sources" {
    p1 = osp_core_unit_path('cl');
    p2 = osp_core_unit_path('cl');
    assert p1 == p2 , "variant path must be stable across calls";
    assert "kernel_units" in p1;
    with open(p1, "r") as f {
        assert f.read() == unit_source(OSP_CORE_PARTS);
    }
}

test "storing bytes already at an artifact key leaves the file untouched" {
    unit = osp_core_unit_path('cl');
    fp = "storecanary";
    text = "; artifact store canary\n";
    store_unit_artifact(unit, "canary", fp, text);
    path = unit_artifact_path(unit, "canary", fp);
    back = os.path.getmtime(path) - 5.0;
    os.utime(path, (back, back));
    stamp = os.path.getmtime(path);
    store_unit_artifact(unit, "canary", fp, text);
    assert os.path.getmtime(path) == stamp , (
        "a store of the bytes already at this key rewrote the artifact"
    );
    store_unit_artifact(unit, "canary", fp, f"{text}; drifted\n");
    assert os.path.getmtime(path) != stamp , (
        "a store of different bytes at this key must still land"
    );
    with open(path, "r") as f {
        assert f.read() == f"{text}; drifted\n";
    }
    os.remove(path);
}

test "client kernel JS is deterministic and the rebuild is a warm artifact read" {
    _rtjs._OSP_CORE_JS_CACHE.clear();
    js1 = _rtjs.build_osp_core_js();
    assert "osp_conn" in js1 , "kernel JS lost the graph store";
    assert "osp_spawn" in js1 , "kernel JS lost the walk engine";
    art = _sole_artifact("osp_core_cl", "mjs");
    mtime1 = os.path.getmtime(art);
    _rtjs._OSP_CORE_JS_CACHE.clear();
    js2 = _rtjs.build_osp_core_js();
    assert js1 == js2 , "kernel JS must be deterministic";
    assert os.path.getmtime(art) == mtime1 , (
        "rebuild rewrote the JS artifact -- warm read did not engage"
    );
}

test "native kernel IR is deterministic and the rebuild is a warm artifact read" {
    _nacp._OSP_KERNEL_IR_CACHE.clear();
    ir1 = _nacp._compile_osp_kernel_ir("cycles", False);
    assert ir1 is not None , "kernel IR build failed";
    art = _sole_artifact("osp_core_na_cycles", "ll");
    mtime1 = os.path.getmtime(art);
    _nacp._OSP_KERNEL_IR_CACHE.clear();
    ir2 = _nacp._compile_osp_kernel_ir("cycles", False);
    assert ir2 == ir1 , "kernel IR must be deterministic across rebuilds";
    assert os.path.getmtime(art) == mtime1 , (
        "rebuild rewrote the IR artifact -- warm read did not engage"
    );
}
