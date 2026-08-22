"""P3 object-core track gate skeleton (PLAN.md §7 P3, TODO.md §3).

Manifest ratchet: ``jac-py/tools/p3_object_core/manifest.json`` holds Layer-0/1
baselines and documents upcoming c2jac Objects/ targets.

Layer-0 corpus replay against those baselines is **P3.1a** work — it must live in
``jac-py/jacpython/layer0_replay.jac`` (or a sibling there), not here: ``jac-py/tests``
cannot ``import layer0_replay`` on collection (``ModuleNotFoundError``).

Layer-0/1 corpus replay ratchets live in ``jac-py/jacpython/layer0_replay_p3_gate.jac``
(``jac run`` via ``tools/p3_object_core/replay_gate.py``); this file validates manifest
shape and P3.1c Objects/ lift gates (``boolobject`` + ``sliceobject`` lifted).

Runtime parity probes (FIXME M11) run via ``tools/p3_object_core/runtime_gate.py`` on a
clean ceval slate; this file validates manifest wiring and invokes that driver.
"""

import json;
import os;
import subprocess;
import sys;
import from tests.support { JAC_ROOT }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MANIFEST_PATH: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p3_object_core", "manifest.json"
     ),
     JACPYTHON_DIR: str = os.path.join(REPO_ROOT, "jac-py", "jacpython"),
     RUNTIME_GATE: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p3_object_core", "runtime_gate.py"
     ),
     MAX_DENSITY: float = 0.15;


def _load_json(path: str) -> dict {
    with open(path) as f {
        return json.load(f);
    }
}


def _wave_spec(manifest: dict, stem: str) -> dict {
    for spec in (manifest["c2jac_objects_wave"] as list) {
        if (spec["stem"] as str) == stem {
            return spec;
        }
    }
    raise ValueError(f"missing c2jac_objects_wave entry {stem!r}");
}


def _report_path(lift_output: str) -> str {
    if lift_output.endswith(".jac") {
        return lift_output[:-4] + ".c2jac.report.json";
    }
    return lift_output + ".c2jac.report.json";
}


def _jac_loc(path: str) -> int {
    count = 0;
    with open(path) as f {
        for line in f {
            stripped = line.strip();
            if (not stripped) or stripped.startswith("#") {
                continue;
            }
            count += 1;
        }
    }
    return count;
}


test "P3 manifest: Layer-0 baseline entries present" {
    manifest = _load_json(MANIFEST_PATH);
    entries = manifest["layer0_files"] as list;
    assert len(entries) == 6;
    for spec in entries {
        baseline = spec["baseline"] as dict;
        assert (baseline["failed"] as int) == 0;
        assert (baseline["errored"] as int) == 0;
        assert (baseline["passed"] as int) > 0;
    }
}


test "P3 manifest: Layer-1 entries gated with honest skip counts (P3.1b)" {
    manifest = _load_json(MANIFEST_PATH);
    entries = manifest["layer1_files"] as list;
    assert len(entries) == 4;
    expected_stems = ["test_set", "test_generators", "test_list", "test_tuple"];
    seen: list[str] = [];
    for spec in entries {
        stem = spec["stem"] as str;
        seen.append(stem);
        assert (spec["status"] as str) == "gated";
        assert (spec["gate"] as str) == "P3.1b";
        baseline = spec["baseline"] as dict;
        assert (baseline["failed"] as int) == 0;
        assert (baseline["errored"] as int) == 0;
        assert (baseline["passed"] as int) > 0;
    }
    for stem in expected_stems {
        assert stem in seen;
    }
}


test "P3 manifest: boolobject and sliceobject lifted (P3.1c)" {
    manifest = _load_json(MANIFEST_PATH);
    bool_spec = _wave_spec(manifest, "boolobject");
    assert (bool_spec["status"] as str) == "lift";
    assert (bool_spec["staging"] as str) == "lift";
    assert (bool_spec["tier_b_baseline"] as int) == 9;
    bool_lift = os.path.join(REPO_ROOT, bool_spec["lift_output"] as str);
    assert os.path.isfile(bool_lift) , bool_lift;

    slice_spec = _wave_spec(manifest, "sliceobject");
    assert (slice_spec["status"] as str) == "lift";
    assert (slice_spec["staging"] as str) == "lift";
    slice_lift = os.path.join(REPO_ROOT, slice_spec["lift_output"] as str);
    assert os.path.isfile(slice_lift) , slice_lift;
}


test "P3 boolobject lift: tier_b ratchet and density below 15% (P3.1c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "boolobject");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
}


test "P3 boolobject lift: TRAP-doc quarantined_functions (P3.1c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "boolobject");
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    sidecar = _load_json(report_path);
    assert (sidecar["quarantined_functions"] as list)
        == ["bool_repr", "bool_vectorcall"];
}


test "P3 sliceobject lift: tier_b ratchet and empty quarantine (P3.1c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "sliceobject");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 abstract_protocol lift: tier_b ratchet and empty quarantine (P3.1e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "abstract_protocol");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 tupleobject_core lift: tier_b ratchet and empty quarantine (P3.2a)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "tupleobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 longobject_core lift: tier_b ratchet and empty quarantine (P3.2a)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "longobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 typeobject_core lift: tier_b ratchet and empty quarantine (P3.2a)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "typeobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 dictobject_core lift: tier_b ratchet and empty quarantine (P3.2a)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "dictobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 setobject_core lift: tier_b ratchet and empty quarantine (P3.2a)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "setobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 exceptions_core lift: tier_b ratchet and empty quarantine (P3.2a)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "exceptions_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 bytesobject_core lift: tier_b ratchet and empty quarantine (P3.2a)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "bytesobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 listobject_core lift: tier_b ratchet and empty quarantine (P3.2a)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "listobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 methodobject_core lift: tier_b ratchet and empty quarantine (P3.2b)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "methodobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 descrobject_core lift: tier_b ratchet and empty quarantine (P3.2b)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "descrobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 floatobject_core lift: tier_b ratchet and empty quarantine (P3.2c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "floatobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 complexobject_core lift: tier_b ratchet and empty quarantine (P3.2c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "complexobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 rangeobject_core lift: tier_b ratchet and empty quarantine (P3.2c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "rangeobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 enumobject_core lift: tier_b ratchet and empty quarantine (P3.2c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "enumobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 cellobject_core lift: tier_b ratchet and empty quarantine (P3.2c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "cellobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 funcobject_core lift: tier_b ratchet and empty quarantine (P3.2c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "funcobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 iterobject_core lift: tier_b ratchet and empty quarantine (P3.2c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "iterobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 classobject_core lift: tier_b ratchet and empty quarantine (P3.2c)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "classobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 codeobject_core lift: tier_b ratchet and empty quarantine (P3.2d)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "codeobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 moduleobject_core lift: tier_b ratchet and empty quarantine (P3.2d)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "moduleobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 weakrefobject_core lift: tier_b ratchet and empty quarantine (P3.2d)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "weakrefobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 bytearrayobject_core lift: tier_b ratchet and empty quarantine (P3.2d)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "bytearrayobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 memoryobject_core lift: tier_b ratchet and empty quarantine (P3.2d)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "memoryobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 frameobject_core lift: tier_b ratchet and empty quarantine (P3.2d)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "frameobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 genobject_core lift: tier_b ratchet and empty quarantine (P3.2d)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "genobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 odictobject_core lift: tier_b ratchet and empty quarantine (P3.2d)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "odictobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 unionobject_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "unionobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 namespaceobject_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "namespaceobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 capsule_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "capsule_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 structseq_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "structseq_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 fileobject_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "fileobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 call_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "call_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 bytes_methods_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "bytes_methods_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 picklebufobject_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "picklebufobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 genericaliasobject_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "genericaliasobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 typevarobject_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "typevarobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 interpolationobject_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "interpolationobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 templateobject_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "templateobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 object_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "object_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 unicodectype_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "unicodectype_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 unicodeobject_core lift: tier_b ratchet and empty quarantine (P3.2e)" {
    manifest = _load_json(MANIFEST_PATH);
    spec = _wave_spec(manifest, "unicodeobject_core");
    lift_path = os.path.join(REPO_ROOT, spec["lift_output"] as str);
    report_path = os.path.join(REPO_ROOT, _report_path(spec["lift_output"] as str));
    assert os.path.isfile(lift_path) , lift_path;
    sidecar = _load_json(report_path);
    baseline = spec["tier_b_baseline"] as int;
    tier_b = sidecar["tier_b_count"] as int;
    assert tier_b <= baseline , f"Tier-B regressed: {tier_b} > baseline {baseline}";
    density = (tier_b / _jac_loc(lift_path)) if _jac_loc(lift_path) else 0.0;
    assert density < MAX_DENSITY , f"density {density:.6f} >= {MAX_DENSITY}";
    assert (sidecar["quarantined_functions"] as list) == [];
}


test "P3 manifest: runtime_probe wired for every lift stem (M11)" {
    manifest = _load_json(MANIFEST_PATH);
    for spec in manifest["c2jac_objects_wave"] as list {
        if (spec["status"] as str) != "lift" {
            continue;
        }
        stem = spec["stem"] as str;
        assert "runtime_probe" in spec , f"missing runtime_probe for {stem!r}";
        probe = spec["runtime_probe"] as dict;
        src = probe["source"] as str;
        assert os.path.isfile(os.path.join(REPO_ROOT, src)) , src;
        baseline = probe["baseline"] as dict;
        assert (baseline["failed"] as int) == 0 , stem;
        assert (baseline["passed"] as int) > 0 , stem;
        mod = probe["jacpython_module"] as str;
        assert os.path.isfile(os.path.join(JACPYTHON_DIR, mod)) , mod;
    }
}


def _run_runtime_gate -> tuple[int, str] {
    py = os.path.join(REPO_ROOT, ".venv", "bin", "python");
    if not os.path.isfile(py) {
        py = sys.executable;
    }
    proc = subprocess.run(
        [py, RUNTIME_GATE], capture_output=True, text=True, cwd=REPO_ROOT, check=False
    );
    detail = (proc.stderr or proc.stdout or "runtime_gate failed").strip();
    return (proc.returncode, detail);
}


test "P3 runtime probes: jacpython Layer-1 replay matches manifest baselines (M11)" {
    if not os.environ.get("JACPYTHON_CPYTHON") {
        return;
    }
    (code, detail) = _run_runtime_gate();
    assert code == 0 , detail;
}
