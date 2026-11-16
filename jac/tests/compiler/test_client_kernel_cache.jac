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
import shutil;
import tempfile;
import jaclang.compiler.backends.es.client_kernel_cache as ckc;
import from jaclang.compiler.frontend.codeinfo { kernel_unit_path }

def concatenated_sources -> str {
    texts: list[str] = [];
    for rel in ckc.OSP_CORE_PARTS {
        head = kernel_unit_path(rel);
        (folder, name) = os.path.split(head);
        stem = name[:-len(".jac")];
        parts = [
            head,
            os.path.join(folder, stem + ".impl.jac"),
            os.path.join(folder, "impl", stem + ".impl.jac")
        ];
        annex_dir = os.path.join(folder, stem + ".impl");
        if os.path.isdir(annex_dir) {
            for listed in sorted(os.listdir(annex_dir)) {
                if listed.endswith(".impl.jac") {
                    parts.append(os.path.join(annex_dir, listed));
                }
            }
        }
        for part in parts {
            if part == head or os.path.isfile(part) {
                with open(part, "r", encoding="utf-8") as handle {
                    texts.append(handle.read());
                }
            }
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
    artifact = ckc._find_cached(ckc._artifact_name(digest));
    assert artifact is not None and os.path.isfile(artifact) , (
        "the lowered JS was not stored"
    );
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


def _unwritable_cache_home(scratch: str) -> str {
    blocker = os.path.join(scratch, "not-a-dir");
    with open(blocker, "w", encoding="utf-8") as handle {
        handle.write("");
    }
    return os.path.join(blocker, "cache");
}

def _swap_cache(cache_home: str, temp_root: str) -> tuple[(str | None), (str | None)] {
    saved = (os.environ.get("JAC_CACHE_HOME"), tempfile.tempdir);
    os.environ["JAC_CACHE_HOME"] = cache_home;
    tempfile.tempdir = temp_root;
    ckc._OSP_CORE_JS_MEMO.clear();
    return saved;
}

def _restore_cache(saved: tuple[(str | None), (str | None)]) {
    (home, temp_root) = saved;
    if home is None {
        os.environ.pop("JAC_CACHE_HOME", None);
    } else {
        os.environ["JAC_CACHE_HOME"] = home;
    }
    tempfile.tempdir = temp_root;
    ckc._OSP_CORE_JS_MEMO.clear();
}

test "an unwritable jac cache stores the kernel in the temp fallback and reads it back" {
    ckc._OSP_CORE_JS_MEMO.clear();
    expected = ckc.osp_core_js();
    scratch = tempfile.mkdtemp();
    fallback_root = tempfile.mkdtemp();
    saved = _swap_cache(_unwritable_cache_home(scratch), fallback_root);
    try {
        js1 = ckc.osp_core_js();
        (unit, digest) = ckc._unit_source_path();
        artifact = ckc._find_cached(ckc._artifact_name(digest));
        fallback = ckc._fallback_dir(False);
        assert fallback is not None , "the private temp fallback was not created";
        assert js1 == expected , "the fallback lowered different kernel JS";
        assert unit.startswith(fallback) , f"unit not in the fallback: {unit}";
        assert artifact is not None and artifact.startswith(fallback) , (
            f"artifact not in the fallback: {artifact}"
        );
        back = os.path.getmtime(artifact) - 5.0;
        os.utime(artifact, (back, back));
        stamp = os.path.getmtime(artifact);
        ckc._OSP_CORE_JS_MEMO.clear();
        assert ckc.osp_core_js() == expected;
        assert os.path.getmtime(artifact) == stamp , (
            "the second process lowered again instead of reading the fallback"
        );
    } finally {
        _restore_cache(saved);
        shutil.rmtree(scratch, ignore_errors=True);
        shutil.rmtree(fallback_root, ignore_errors=True);
    }
}

test "kernel JS is still returned when no folder accepts the artifact" {
    ckc._OSP_CORE_JS_MEMO.clear();
    expected = ckc.osp_core_js();
    scratch = tempfile.mkdtemp();
    fallback_root = tempfile.mkdtemp();
    saved = _swap_cache(_unwritable_cache_home(scratch), fallback_root);
    try {
        (_, digest) = ckc._unit_source_path();
        name = ckc._artifact_name(digest);
        fallback = ckc._fallback_dir(True);
        assert fallback is not None , "the private temp fallback was not created";
        os.makedirs(os.path.join(fallback, name));
        ckc._OSP_CORE_JS_MEMO.clear();
        assert ckc.osp_core_js() == expected;
        assert ckc._find_cached(name) is None , "an artifact was stored after all";
    } finally {
        _restore_cache(saved);
        shutil.rmtree(scratch, ignore_errors=True);
        shutil.rmtree(fallback_root, ignore_errors=True);
    }
}


def _no_tempdir -> str {
    raise FileNotFoundError("no usable temporary directory");
}

test "a missing temp directory does not block a writable jac cache" {
    ckc._OSP_CORE_JS_MEMO.clear();
    expected = ckc.osp_core_js();
    cache_home = tempfile.mkdtemp();
    saved = _swap_cache(cache_home, tempfile.gettempdir());
    original_gettempdir = tempfile.gettempdir;
    tempfile.gettempdir = _no_tempdir;
    try {
        assert ckc.osp_core_js() == expected;
        (_, digest) = ckc._unit_source_path();
        artifact = ckc._find_cached(ckc._artifact_name(digest));
        assert artifact is not None and artifact.startswith(cache_home) , (
            f"artifact not in the jac cache: {artifact}"
        );
        assert ckc._fallback_dir(True) is None;
    } finally {
        tempfile.gettempdir = original_gettempdir;
        _restore_cache(saved);
        shutil.rmtree(cache_home, ignore_errors=True);
    }
}

def _plant_artifact(folder: str, name: str) {
    os.makedirs(folder, exist_ok=True);
    with open(os.path.join(folder, name), "w", encoding="utf-8") as handle {
        handle.write("PLANTED");
    }
}

test "a temp fallback another user could write to is neither read nor used" {
    ckc._OSP_CORE_JS_MEMO.clear();
    expected = ckc.osp_core_js();
    (_, digest) = ckc._unit_source_path();
    name = ckc._artifact_name(digest);
    user = str(os.getuid()) if os?.getuid else os.environ.get("USERNAME", "user");
    for layout in ["others-writable", "symlink"] {
        cache_home = tempfile.mkdtemp();
        fallback_root = tempfile.mkdtemp();
        base = os.path.join(fallback_root, f"jac-cache-{user}");
        if layout == "others-writable" {
            _plant_artifact(os.path.join(base, "jir", "client_kernel"), name);
            os.chmod(base, 0o777);
        } else {
            elsewhere = os.path.join(fallback_root, "elsewhere");
            _plant_artifact(os.path.join(elsewhere, "jir", "client_kernel"), name);
            os.symlink(elsewhere, base);
        }
        saved = _swap_cache(cache_home, fallback_root);
        try {
            assert ckc._fallback_dir(True) is None , f"{layout}: fallback trusted";
            assert ckc.osp_core_js() == expected , f"{layout}: planted JS was served";
        } finally {
            _restore_cache(saved);
            shutil.rmtree(cache_home, ignore_errors=True);
            shutil.rmtree(fallback_root, ignore_errors=True);
        }
    }
}
