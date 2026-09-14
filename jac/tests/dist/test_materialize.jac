"""Cold-start runtime cache maintenance.

`gc_stale` sweeps the runtime generations the freshly extracted one replaced.
The new one is published first, so a generation that refuses to delete costs
disk, not correctness, and must not take the process down (issue #9053). The
probe is compiled the way the launcher is: forced native over the fused runtime
staged beside it.
"""

import ctypes;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.client.targets.desktop.desktop_build { _stage_fused_runtime }
import from tests.support { compile_native, get_func }


glob _CACHE: str = "/tmp/jac_gc_stale_probe",
     _KEEP: str = "1111111111111111-aaaaaaaaaaaaaaaa";


# (generation, locked against deletion, survives the sweep, what that pins)
def _generations -> list[tuple[str, bool, bool, str]] {
    return [
        (
            "2222222222222222-aaaaaaaaaaaaaaaa",
            True,
            True,
            "a generation that will not delete stays put"
        ),
        (
            "3333333333333333-aaaaaaaaaaaaaaaa",
            False,
            False,
            "a generation that will delete still goes, whatever the sweep hit"
        ),
        (
            "2222222222222222-bbbbbbbbbbbbbbbb",
            False,
            True,
            "another binary's generations are not this sweep's"
        ),
        (
            "4444444444444444-aaaaaaaaaaaaaaaa.tmp.4242",
            False,
            True,
            "an in-flight extraction is not swept"
        ),
        (_KEEP, False, True, "the live generation must survive the sweep")
    ];
}


"""Source of a native probe that sweeps the crafted cache once."""
def _probe_source -> str {
    return (
        "import from fused.materialize { gc_stale }\n"
        "\n"
        "def sweep -> int {\n"
        f"    gc_stale(\"{_CACHE}\", \"{_KEEP}\");\n"
        "    return 1;\n"
        "}\n"
    );
}


"""Path of one runtime generation in the crafted cache."""
def _generation_path(name: str) -> str {
    return os.path.join(_CACHE, "rt", name);
}


"""Lay the crafted cache down, each generation holding one file."""
def _seed_cache {
    shutil.rmtree(_CACHE, ignore_errors=True);
    for (name, locked, _, _) in _generations() {
        full = _generation_path(name);
        os.makedirs(full, exist_ok=True);
        (open(os.path.join(full, "pinned.py"), "w")).close();
        os.chmod(full, 0o555 if locked else 0o755);
    }
}


"""Give back the write bit the seed withheld, so the cache can be removed."""
def _unlock_cache {
    for (name, locked, _, _) in _generations() {
        full = _generation_path(name);
        if locked and os.path.isdir(full) {
            os.chmod(full, 0o755);
        }
    }
}


"""Compile the sweep probe over a staged fused runtime and hand back its entry."""
def _sweep_probe(work: str) -> any {
    _stage_fused_runtime(Path(work));
    (Path(os.path.join(work, "gc_probe.jac"))).write_text(_probe_source());
    (eng, _) = compile_native("gc_probe.jac", work);
    if eng.get_function_address("jac_entry") != 0 {
        get_func(eng, "jac_entry", None)();
    }
    return get_func(eng, "sweep", ctypes.c_int64);
}


test "gc_stale clears replaced generations and survives one it cannot delete" {
    if os.geteuid() == 0 {
        testskip("root ignores the mode bits this test pins the directory with");
    }
    work = tempfile.mkdtemp(prefix="jac_gc_stale_");
    _seed_cache();
    try {
        sweep = _sweep_probe(work);
        assert sweep() == 1 , "the sweep must return, not abort the process";
        for (name, _, kept, pins) in _generations() {
            assert os.path.isdir(_generation_path(name)) == kept , pins;
        }
    } finally {
        _unlock_cache();
        shutil.rmtree(_CACHE, ignore_errors=True);
        shutil.rmtree(work, ignore_errors=True);
    }
}
