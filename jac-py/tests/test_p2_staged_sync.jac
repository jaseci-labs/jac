"""Drift gate: staged oracle Modules/*.jac vs committed _lifted/p2_corpus_wave1/*.jac.

``lift`` modules must match byte-for-byte. ``hand`` modules are exempt (intentional
oracle edits); manifest notes require syncing staged -> _lifted after T8 burn-down.
"""

import json;
import os;
import from tests.support { JAC_ROOT }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MANIFEST_PATH: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p2_staged_manifest.json"
     );


def _load_json(path: str) -> dict {
    with open(path) as f {
        return json.load(f);
    }
}

def _read_text(path: str) -> str {
    with open(path) as f {
        return f.read();
    }
}


test "P2 staged manifest lists ten wave-1 modules" {
    manifest = _load_json(MANIFEST_PATH);
    modules = manifest["modules"] as list;
    assert len(modules) == 10 , len(modules);
    stems = sorted([row["stem"] for row in modules]);
    expected = sorted(
        [
            "_bisectmodule",
            "_heapqmodule",
            "getbuildinfo",
            "getcompiler",
            "getcopyright",
            "getplatform",
            "mysnprintf",
            "pyfpe",
            "pystrcmp",
            "rotatingtree",

        ]
    );
    assert stems == expected , stems;
}

test "P2 lift-staged modules match committed _lifted corpus" {
    manifest = _load_json(MANIFEST_PATH);
    staged_dir = os.path.join(REPO_ROOT, manifest["staged_dir"]);
    lifted_dir = os.path.join(REPO_ROOT, manifest["lifted_dir"]);
    mismatches: list = [];

    for row in (manifest["modules"] as list) {
        stem = row["stem"] as str;
        staging = row["staging"] as str;
        staged_path = os.path.join(staged_dir, f"{stem}.jac");
        lifted_path = os.path.join(lifted_dir, f"{stem}.jac");
        assert os.path.isfile(staged_path) , staged_path;
        assert os.path.isfile(lifted_path) , lifted_path;

        if staging == "lift" {
            staged_text = _read_text(staged_path);
            lifted_text = _read_text(lifted_path);
            if staged_text != lifted_text {
                mismatches.append(
                    f"{stem}: staged {manifest['staged_dir']}/{stem}.jac "
                        + f"!= {manifest['lifted_dir']}/{stem}.jac "
                        + "(re-lift with lift_p2_corpus.py or copy staged oracle)"
                );
            }
        } elif staging == "hand" {
            note = row.get("note");
            assert note , f"hand module {stem} needs manifest note for sync policy";
        } else {
            assert False , f"unknown staging {staging!r} for {stem}";
        }
    }

    assert not mismatches , "\n".join(mismatches);
}

test "P2 getplatform facade matches staged Modules oracle" {
    staged = os.path.join(REPO_ROOT, "jac-py", "Modules", "getplatform.jac");
    facade = os.path.join(REPO_ROOT, "jac-py", "jacpython", "getplatform.jac");
    assert os.path.isfile(staged) , staged;
    assert os.path.isfile(facade) , facade;
    assert _read_text(staged) == _read_text(facade) , (
        "jacpython/getplatform.jac must mirror Modules/getplatform.jac"
    );
}

test "P2 bisect/heapq facades are native (not Modules byte-copies, no host py blocks)" {
    # Unlike getplatform, product facades are native list algorithms; Modules/
    # stay C-API hand oracles for cc differentials (see p2_staged_manifest notes).
    # Avoid embedding the py-block delimiter as a contiguous literal in this file.
    py_block = ":" + ":py:" + ":";
    for stem in ["_bisectmodule", "_heapqmodule"] {
        staged = os.path.join(REPO_ROOT, "jac-py", "Modules", f"{stem}.jac");
        facade = os.path.join(REPO_ROOT, "jac-py", "jacpython", f"{stem}.jac");
        assert os.path.isfile(staged) , staged;
        assert os.path.isfile(facade) , facade;
        facade_text = _read_text(facade);
        assert py_block not in facade_text , (
            f"jacpython/{stem}.jac must not use host py-block delegation"
        );
        assert "_p2_" in facade_text , f"jacpython/{stem}.jac missing _p2_* surface";
        assert facade_text != _read_text(staged) , (
            f"jacpython/{stem}.jac must remain a native facade, not a Modules copy"
        );
    }
}
