"""T6 P2 conformance harness skeleton (PLAN.md §6.6).

Runs embedded pure-Python Lib/test-style snippets on the host CPython interpreter,
optionally runs staged ``Modules/*.jac`` differential legs via ``libtest_runner``,
records pass/fail, and writes ``conformance_manifest.json``. Lifted C module ports
without a stdlib equivalent are documented as oracle- or deferred-gated only.

Oracle differential tests live in ``test_p2_module_oracles.jac`` and
``test_rotatingtree_oracle.jac``; this harness covers the libtest leg and the
manifest ratchet.
"""

import json;
import os;
import from tests.support { JAC_ROOT }
import from tests.jacpy.libtest_runner {
    run_libtest_host_for_gate,
    run_libtest_jac_differential_for_gate,
    run_libtest_jacpython_for_gate
}


glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MANIFEST_PATH: str = os.path.join(
         REPO_ROOT, "jac-py", "tests", "conformance_manifest.json"
     ),
     P2_CORPUS_MANIFEST: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p2_corpus", "manifest.json"
     ),
     P2_MODULE_COUNT: int = 10,
     JACPYTHON_CAPABLE_LIBTEST: list[str] = [
         "getplatform",
         "_bisectmodule",
         "_heapqmodule",
     ];


obj P2ModuleGate {
    has stem: str,
        gate_type: str,
        status: str,
        oracle_tests: list[str],
        libtest_snippets: list[str],
        notes: str;
}


glob P2_MODULE_GATES: list[P2ModuleGate] = [
         P2ModuleGate(
             stem="mysnprintf",
             gate_type="oracle",
             status="gated",
             oracle_tests=["test_p2_module_oracles.jac"],
             libtest_snippets=[],
             notes="No Python stdlib equivalent; cc vs staged jac oracle (PyOS_vsnprintf)."
         ),
         P2ModuleGate(
             stem="pystrcmp",
             gate_type="oracle",
             status="gated",
             oracle_tests=["test_p2_module_oracles.jac"],
             libtest_snippets=[],
             notes="No Python stdlib equivalent; cc vs lifted jac oracle."
         ),
         P2ModuleGate(
             stem="rotatingtree",
             gate_type="oracle",
             status="gated",
             oracle_tests=["test_rotatingtree_oracle.jac"],
             libtest_snippets=[],
             notes="No Python stdlib equivalent; cc vs lifted jac oracle."
         ),
         P2ModuleGate(
             stem="getbuildinfo",
             gate_type="oracle",
             status="gated",
             oracle_tests=["test_p2_module_oracles.jac"],
             libtest_snippets=[],
             notes="Build-info internals; cc vs staged jac oracle (hand-edited empty-string semantics)."
         ),
         P2ModuleGate(
             stem="_bisectmodule",
             gate_type="libtest",
             status="gated",
             oracle_tests=["test_p2_module_oracles.jac"],
             libtest_snippets=["bisect_precomputed", "bisect_insort"],
             notes="Algorithm parity via bisect stdlib; C port oracle-gated separately."
         ),
         P2ModuleGate(
             stem="_heapqmodule",
             gate_type="libtest",
             status="gated",
             oracle_tests=["test_p2_module_oracles.jac"],
             libtest_snippets=["heapq_push_pop", "heapq_heapify"],
             notes="Algorithm parity via heapq stdlib; C port oracle-gated separately."
         ),
         P2ModuleGate(
             stem="getplatform",
             gate_type="libtest",
             status="gated",
             oracle_tests=["test_p2_module_oracles.jac"],
             libtest_snippets=["platform_basic"],
             notes="Partial Lib/test via platform module; Py_GetPlatform oracle-gated separately."
         ),
         P2ModuleGate(
             stem="getcompiler",
             gate_type="oracle",
             status="gated",
             oracle_tests=["test_p2_module_oracles.jac"],
             libtest_snippets=[],
             notes="No Python stdlib equivalent; cc vs lifted jac oracle."
         ),
         P2ModuleGate(
             stem="getcopyright",
             gate_type="oracle",
             status="gated",
             oracle_tests=["test_p2_module_oracles.jac"],
             libtest_snippets=[],
             notes="No Python stdlib equivalent; cc vs lifted jac oracle."
         ),
         P2ModuleGate(
             stem="pyfpe",
             gate_type="oracle",
             status="gated",
             oracle_tests=["test_p2_module_oracles.jac"],
             libtest_snippets=[],
             notes="Legacy FPE hook; cc vs lifted jac oracle."
         ),

     ];


def run_libtest_snippets -> dict {
    results: dict = {};
    for gate in P2_MODULE_GATES {
        if gate.gate_type != "libtest" {
            continue;
        }
        results[gate.stem] = run_libtest_host_for_gate(gate.libtest_snippets);
    }
    return results;
}


def run_jac_differential_snippets -> dict {
    results: dict = {};
    for gate in P2_MODULE_GATES {
        if gate.gate_type != "libtest" {
            continue;
        }
        results[gate.stem] = run_libtest_jac_differential_for_gate(
            gate.libtest_snippets
        );
    }
    return results;
}


def run_jacpython_snippets -> dict {
    results: dict = {};
    for gate in P2_MODULE_GATES {
        if gate.gate_type != "libtest" {
            continue;
        }
        results[gate.stem] = run_libtest_jacpython_for_gate(gate.libtest_snippets);
    }
    return results;
}


def build_manifest(
    libtest_results: dict, jac_differential_results: dict, jacpython_results: dict
) -> dict {
    modules: list = [];
    for gate in P2_MODULE_GATES {
        row = {
            "stem": gate.stem,
            "gate_type": gate.gate_type,
            "status": gate.status,
            "oracle_tests": gate.oracle_tests,
            "libtest_snippets": gate.libtest_snippets,
            "notes": gate.notes,

        };
        if gate.stem in libtest_results {
            row["libtest"] = libtest_results[gate.stem];
        }
        if gate.stem in jac_differential_results {
            row["jac_differential"] = jac_differential_results[gate.stem];
        }
        if gate.stem in jacpython_results {
            row["jacpython"] = jacpython_results[gate.stem];
        }
        modules.append(row);
    }
    return {
        "version": 1,
        "wave": "p2_wave1",
        "description": "P2 proving wave conformance manifest (T6 skeleton)",
        "module_count": P2_MODULE_COUNT,
        "modules": modules,
        "libtest_results": libtest_results,
        "jac_differential_results": jac_differential_results,
        "jacpython_results": jacpython_results,

    };
}


def write_manifest(path: str = MANIFEST_PATH) -> dict {
    libtest_results = run_libtest_snippets();
    jac_differential_results = run_jac_differential_snippets();
    jacpython_results = run_jacpython_snippets();
    manifest = build_manifest(
        libtest_results, jac_differential_results, jacpython_results
    );
    with open(path, "w") as f {
        json.dump(manifest, f, indent=2);
        f.write("\n");
    }
    return manifest;
}


def load_manifest(path: str = MANIFEST_PATH) -> dict {
    with open(path) as f {
        return json.load(f);
    }
}


def assert_all_modules_gated(manifest: dict) {
    modules = manifest["modules"] as list;
    assert len(modules) == P2_MODULE_COUNT , len(modules);
    for row in modules {
        row_spec = row as dict;
        assert row_spec["status"] == "gated" , row_spec;
        oracle_tests = row_spec.get("oracle_tests", []);
        assert len(oracle_tests) > 0 , f"{row_spec.get('stem', '?')}: missing oracle_tests";
        for test_name in (oracle_tests as list) {
            test_path = os.path.join(os.path.dirname(MANIFEST_PATH), test_name);
            assert os.path.isfile(test_path) , f"oracle test not found: {test_path}";
        }
    }
}


def assert_libtest_zero_failures(manifest: dict) {
    libtest_results = manifest["libtest_results"] as dict;
    for (stem, row) in libtest_results.items() {
        detail = row as dict;
        assert (detail["failed"] as int) == 0 , f"{stem}: {detail}";
    }
}


def assert_jac_differential_zero_failures(manifest: dict) -> None {
    jac_results = manifest.get("jac_differential_results") as dict | None;
    if jac_results is None {
        return;
    }
    for (stem, row) in jac_results.items() {
        detail = row as dict;
        assert (detail["failed"] as int) == 0 , f"{stem} jac differential: {detail}";
    }
}


def assert_jacpython_zero_failures(manifest: dict) -> None {
    jac_results = manifest.get("jacpython_results") as dict | None;
    if jac_results is None {
        return;
    }
    for (stem, row) in jac_results.items() {
        detail = row as dict;
        assert (detail["failed"] as int) == 0 , f"{stem} jacpython: {detail}";
        if stem in JACPYTHON_CAPABLE_LIBTEST {
            assert (detail["passed"] as int) >= 1 , f"{stem} jacpython: expected passed >= 1, got {detail}";
            assert (detail["skipped"] as int) == 0 , f"{stem} jacpython: expected no skips, got {detail}";
        }
    }
}


with entry {
    manifest = write_manifest();
    assert_all_modules_gated(manifest);
    assert_libtest_zero_failures(manifest);
    assert_jac_differential_zero_failures(manifest);
    assert_jacpython_zero_failures(manifest);
    print(f"wrote {MANIFEST_PATH} ({P2_MODULE_COUNT} modules gated)");
}


test "P2 conformance: corpus manifest lists ten modules" {
    corpus = json.load(open(P2_CORPUS_MANIFEST));
    assert len(corpus["files"] as list) == P2_MODULE_COUNT;
}


test "P2 conformance: host libtest snippets pass on CPython" {
    results = run_libtest_snippets();
    for (stem, row) in results.items() {
        detail = row as dict;
        assert (detail["failed"] as int) == 0 , f"{stem}: {detail}";
    }
}


test "P2 conformance: jac differential staged modules pass when enabled" {
    results = run_jac_differential_snippets();
    for (stem, row) in results.items() {
        detail = row as dict;
        assert (detail["failed"] as int) == 0 , f"{stem}: {detail}";
    }
}


test "P2 conformance: jacpython libtest shims pass when enabled" {
    results = run_jacpython_snippets();
    for (stem, row) in results.items() {
        detail = row as dict;
        assert (detail["failed"] as int) == 0 , f"{stem}: {detail}";
    }
}


test "P2 conformance: manifest ratchet — all modules gated" {
    manifest = write_manifest();
    assert_all_modules_gated(manifest);
    assert_libtest_zero_failures(manifest);
    assert_jac_differential_zero_failures(manifest);
    assert_jacpython_zero_failures(manifest);
    on_disk = load_manifest();
    assert_all_modules_gated(on_disk);
    assert_libtest_zero_failures(on_disk);
    assert_jac_differential_zero_failures(on_disk);
    assert_jacpython_zero_failures(on_disk);
}
