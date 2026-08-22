# P3 object-core corpus ratchet (TODO.md P3.1a/P3.1b).
#
# ``test_int`` baseline 119 = 114 arithmetic/conversion pairs + 5 memoryview ``int()``
# slices (Gap #4); a drop to 114 with zero failures means those five errored/skipped.
# Run via ``jac run`` (not ``jac test``): importing pyc_first through the replay
# harness would otherwise collect pyc_first.jac's 38 regression tests first and
# mutate ceval state before corpus counts are measured.
import json;
import os;
import from layer0_replay_harness {
    ReplayResult,
    layer0_replay_source,
    layer1_replay_source,
}

glob P3_MANIFEST_PATH: str = os.path.join(
         "jac-py", "tools", "p3_object_core", "manifest.json"
     ),
     P3_REF_ROOT: str = os.path.join("reference", "cpython");


def _p3_load_manifest -> dict {
    with open(P3_MANIFEST_PATH) as f {
        return json.load(f);
    }
}

def _p3_read_corpus(rel_path: str) -> str {
    with open(os.path.join(P3_REF_ROOT, rel_path)) as f {
        return f.read();
    }
}

def _p3_assert_replay_baseline(stem: str, result: ReplayResult, baseline: dict) {
    assert result.passed == (baseline["passed"] as int) , stem
        + " passed="
        + str(result.passed)
        + " baseline="
        + str(baseline["passed"]);
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

def _p3_run_layer0(manifest: dict) {
    for spec in manifest["layer0_files"] as list {
        stem: str = spec["stem"] as str;
        src = _p3_read_corpus(spec["path"] as str);
        result = layer0_replay_source(src);
        _p3_assert_replay_baseline(stem, result, spec["baseline"] as dict);
    }
}

def _p3_run_layer1(manifest: dict) {
    for spec in manifest["layer1_files"] as list {
        stem: str = spec["stem"] as str;
        src = _p3_read_corpus(spec["path"] as str);
        result = layer1_replay_source(src);
        _p3_assert_replay_baseline(stem, result, spec["baseline"] as dict);
    }
}

with entry {
    manifest = _p3_load_manifest();
    _p3_run_layer0(manifest);
    _p3_run_layer1(manifest);
    print("P3 corpus ratchet: Layer-0/1 baselines OK");
}
