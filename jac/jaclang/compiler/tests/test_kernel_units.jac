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
import jaclang.compiler.backends.es.jac_runtime_js as _rtjs;
import jaclang.compiler.backends.native.na_compile_pass as _nacp;
import from jaclang.compiler.backends.common.kernel_units {
    OSP_CORE_PARTS,
    osp_core_unit_path,
    store_unit_artifact,
    unit_artifact_path,
    unit_source
}

def _sole_artifact(unit_path: str, kind: str) -> str {
    units_dir = os.path.dirname(unit_path);
    stem = os.path.splitext(os.path.basename(unit_path))[0];
    hits = sorted(`glob.`glob(os.path.join(units_dir, f"{stem}.*.{kind}")));
    assert len(hits) == 1 , f"expected one {stem} {kind} artifact, got {hits}";
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

test "the unit path is content-keyed so two compiler trees cannot share it" {
    import hashlib;
    unit = osp_core_unit_path('cl');
    digest = hashlib.sha256(unit_source(OSP_CORE_PARTS).encode()).hexdigest()[:16];
    assert os.path.basename(unit) == f"osp_core_cl.{digest}.jac" , (
        "the unit filename does not pin the kernel sources it holds"
    );
}

test "a materialized unit is never rewritten underneath a reader" {
    unit = osp_core_unit_path('cl');
    back = os.path.getmtime(unit) - 5.0;
    os.utime(unit, (back, back));
    stamp = os.path.getmtime(unit);
    assert osp_core_unit_path('cl') == unit;
    assert os.path.getmtime(unit) == stamp , (
        "re-materializing rewrote a unit another process may be compiling"
    );
}

test "an artifact store leaves another compiler generation's artifact alone" {
    unit = osp_core_unit_path('cl');
    foreign = os.path.join(
        os.path.dirname(unit), "osp_core_cl.0123456789abcdef.feedfacefeedface.canary"
    );
    with open(foreign, "w") as f {
        f.write("; foreign generation\n");
    }
    store_unit_artifact(unit, "canary", "crossgen", "; mine\n");
    mine = unit_artifact_path(unit, "canary", "crossgen");
    assert os.path.exists(foreign) , (
        "storing an artifact deleted another compiler generation's artifact"
    );
    os.remove(foreign);
    os.remove(mine);
}

test "a superseded generation's artifacts retire once they go untouched" {
    import time;
    import from jaclang.compiler.backends.common.kernel_units { _RETIRED_UNITS }
    unit = osp_core_unit_path('cl');
    units_dir = os.path.dirname(unit);
    aged = os.path.join(
        units_dir, "osp_core_cl.0123456789abcdef.feedfacefeedface.canary"
    );
    recent = os.path.join(
        units_dir, "osp_core_cl.fedcba9876543210.cafebabecafebabe.canary"
    );
    for stray in [aged, recent] {
        with open(stray, "w") as f {
            f.write("; superseded\n");
        }
    }
    old_stamp = time.time() - (40.0 * 86400.0);
    os.utime(aged, (old_stamp, old_stamp));
    _RETIRED_UNITS.discard("osp_core_cl");
    osp_core_unit_path('cl');
    assert not os.path.exists(aged) , (
        "an untouched superseded artifact was not retired"
    );
    assert os.path.exists(recent) , (
        "a superseded artifact still in use was retired too eagerly"
    );
    assert os.path.exists(unit) , "retirement removed the live unit";
    os.remove(recent);
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
    driver_names = [
        "osp_conn",
        "osp_conn_many",
        "osp_refs",
        "osp_refs_many",
        "osp_refs_edge_pred",
        "osp_wrap1",
        "osp_destroy",
        "osp_is_dead",
        "osp_disconn_between",
        "osp_disconn_between_many",
        "osp_disconn_between_pred",
        "osp_edge_peer",
        "osp_spawn",
        "osp_visit",
        "osp_report",
        "osp_disengage",
        "osp_forget",
        "osp_register_type",
        "osp_register_desc",
        "osp_node_desc",
        "osp_is_a",
        "WalkerDesc",
        "NodeDesc",
        "Slot",
        "OspRuntime"
    ];
    for nm in driver_names {
        assert nm in js1 , f"kernel JS lost the driver-referenced name {nm}";
    }
    art = _sole_artifact(osp_core_unit_path('cl'), "mjs");
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
    art = _sole_artifact(osp_core_unit_path('na_cycles'), "ll");
    mtime1 = os.path.getmtime(art);
    _nacp._OSP_KERNEL_IR_CACHE.clear();
    ir2 = _nacp._compile_osp_kernel_ir("cycles", False);
    assert ir2 == ir1 , "kernel IR must be deterministic across rebuilds";
    assert os.path.getmtime(art) == mtime1 , (
        "rebuild rewrote the IR artifact -- warm read did not engage"
    );
}
