"""The client OSP kernel's JS is built once per source and backend.

`client_kernel_cache` concatenates the OSP kernel sources into one
content-keyed unit, lowers it to JS once, and serves later builds from the
stored artifact. These tests pin one stable identity per source, a unit never
rewritten under a reader, byte-identical rebuilds, and a warm rebuild that
reads the artifact instead of lowering again (observed as the artifact file
not being rewritten). The native kernel no longer has an artifact of its own:
it links from native units, whose reuse the link plan tests pin.
"""
import hashlib;
import os;
import jaclang.compiler.backends.es.client_kernel_cache as ckc;
import from jaclang.compiler.frontend.codeinfo { kernel_unit_path }

def concatenated_sources -> str {
    texts: list[str] = [];
    for rel in ckc.OSP_CORE_PARTS {
        with open(kernel_unit_path(rel), "r", encoding="utf-8") as handle {
            texts.append(handle.read());
        }
    }
    return "\n\n".join(texts);
}

test "the unit path is stable and content-keyed on the exact kernel sources" {
    (first, digest) = ckc._unit_source_path();
    (second, _) = ckc._unit_source_path();
    assert first == second , "the unit path must be stable across calls";
    source = concatenated_sources();
    assert digest == hashlib.sha256(source.encode()).hexdigest()[:16];
    assert os.path.basename(first) == f"osp_core_cl.{digest}.jac" , (
        "the unit filename does not pin the kernel sources it holds"
    );
    with open(first, "r", encoding="utf-8") as handle {
        assert handle.read() == source;
    }
}

test "a materialized unit is never rewritten underneath a reader" {
    (unit, _) = ckc._unit_source_path();
    back = os.path.getmtime(unit) - 5.0;
    os.utime(unit, (back, back));
    stamp = os.path.getmtime(unit);
    assert ckc._unit_source_path()[0] == unit;
    assert os.path.getmtime(unit) == stamp , (
        "re-materializing rewrote a unit another process may be compiling"
    );
}

test "client kernel JS is deterministic and the rebuild is a warm artifact read" {
    ckc._OSP_CORE_JS_MEMO.clear();
    js1 = ckc.osp_core_js();
    for name in [
        "osp_conn",
        "osp_refs",
        "osp_destroy",
        "osp_spawn",
        "osp_visit",
        "osp_report",
        "osp_register_type",
        "osp_node_desc",
        "osp_is_a",
        "OspWalkerDesc",
        "OspNodeDesc",
        "OspSlot",
        "OspRuntime"
    ] {
        assert name in js1 , f"kernel JS lost the driver-referenced name {name}";
    }
    (_, digest) = ckc._unit_source_path();
    artifact = ckc._artifact_path(digest);
    assert os.path.isfile(artifact) , "the lowered JS was not stored";
    back = os.path.getmtime(artifact) - 5.0;
    os.utime(artifact, (back, back));
    stamp = os.path.getmtime(artifact);
    ckc._OSP_CORE_JS_MEMO.clear();
    js2 = ckc.osp_core_js();
    assert js1 == js2 , "kernel JS must be deterministic";
    assert os.path.getmtime(artifact) == stamp , (
        "the rebuild rewrote the JS artifact: the warm read did not engage"
    );
}
