# P3 object-core runtime parity ratchet (TODO.md item 5 / FIXME M11).
#
# Runs manifest ``runtime_probe`` Layer-1 replay snippets against jacpython's
# ceval and asserts per-stem baselines. Invoke via ``jac run`` (not ``jac test``)
# so pyc_first regression tests are not collected through the harness import graph.
import json;
import os;
import from layer0_replay_harness { ReplayResult, layer1_replay_source, }

glob P3_MANIFEST_PATH: str = os.path.join(
         "jac-py", "tools", "p3_object_core", "manifest.json"
     );


def _p3_load_manifest -> dict {
    with open(P3_MANIFEST_PATH) as f {
        return json.load(f);
    }
}


def _p3_read_probe(rel_path: str) -> str {
    with open(rel_path) as f {
        return f.read();
    }
}


def _p3_assert_runtime_baseline(stem: str, result: ReplayResult, baseline: dict) {
    assert result.passed == (baseline["passed"] as int) , stem
        + " passed="
        + str(result.passed)
        + " baseline="
        + str(baseline["passed"])
        + " failures="
        + str(result.failures);
    assert result.failed == (baseline["failed"] as int) , stem
        + " failed="
        + str(result.failed)
        + " failures="
        + str(result.failures);
    assert result.errored == (baseline["errored"] as int) , stem
        + " errored="
        + str(result.errored)
        + " errors="
        + str(result.errors);
    if "skipped" in baseline {
        assert result.skipped == (baseline["skipped"] as int) , stem
            + " skipped="
            + str(result.skipped)
            + " baseline="
            + str(baseline["skipped"]);
    }
}


def _p3_run_runtime_probes(manifest: dict) {
    for spec in manifest["c2jac_objects_wave"] as list {
        if not ("runtime_probe" in spec) {
            continue;
        }
        stem: str = spec["stem"] as str;
        probe = spec["runtime_probe"] as dict;
        src = _p3_read_probe(probe["source"] as str);
        result = layer1_replay_source(src);
        _p3_assert_runtime_baseline(stem, result, probe["baseline"] as dict);
    }
}

with entry {
    manifest = _p3_load_manifest();
    _p3_run_runtime_probes(manifest);
    print("P3 runtime probes: all stems OK");
}
