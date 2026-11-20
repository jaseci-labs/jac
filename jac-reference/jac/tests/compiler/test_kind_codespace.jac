"""Tests for kind-derived codespace: [project] kind feeds module placement (#8034).

A js-package project has no server, so every module compiles to the client
codespace by construction -- bare compiles (jac tool jac2js, check, langserve)
must agree with `jac build --as npm` instead of running full-stack inference
that silently drops evidence-free `pub` exports server-side.

The fixture is copied into a throwaway project per test: the kind under test
lives in a generated jac.toml beside it, and compiling it in place would
resolve the repo's own manifest instead.
"""

import os;
import shutil;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.placement.placement_pins { config_kind_space }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURE = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace", "kind_pub_exports.jac"
     ),
     SERVER_EVIDENCE_FIXTURE = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "fixtures",
         "codespace",
         "kind_server_evidence.jac"
     );


def _project(tmpdir: str, kind: str, fixture: str = "") -> str {
    kind_line = f"kind = \"{kind}\"\n" if kind else "";
    with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"probe\"\n" + kind_line);
    }
    return shutil.copy(fixture or FIXTURE, os.path.join(tmpdir, "lib.jac"));
}


def _nested_project(tmpdir: str, root_kind: str, nested_kind: str) -> str {
    root_kind_line = f"kind = \"{root_kind}\"\n" if root_kind else "";
    with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
        f.write(
            "[project]\nname = \"outer\"\n"
                + root_kind_line
                + "\n[project.include]\npackages = [\"extension\"]\n"
        );
    }
    inner = os.path.join(tmpdir, "extension");
    os.makedirs(inner, exist_ok=True);
    nested_kind_line = f"kind = \"{nested_kind}\"\n" if nested_kind else "";
    with open(os.path.join(inner, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"inner\"\n" + nested_kind_line);
    }
    return shutil.copy(FIXTURE, os.path.join(inner, "lib.jac"));
}


test "js-package kind resolves to the client codespace" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _project(tmpdir, "js-package");
        assert config_kind_space(lib) == "client";
    }
}


test "kinds without a declared codespace resolve to nothing" {
    for kind in ["cli", "web-app", "", "not-a-kind"] {
        with tempfile.TemporaryDirectory() as tmpdir {
            assert config_kind_space(_project(tmpdir, kind)) == "";
        }
    }
}


test "js-package bare compile emits every pub export" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _project(tmpdir, "js-package");
        prog = JacProgram();
        mod = prog.compile(lib);
        assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
        js = mod.gen.js or "";
        assert "function activate" in js;
        assert "function deactivate" in js , (
            "evidence-free pub export must not be dropped in a serverless project"
        );
        assert "deactivate" in js.split("export")[-1];
        assert "__jacEndpointEffects__" not in js , (
            "a js-package project has no server to serve endpoints"
        );
    }
}


test "full-stack inference is unchanged for kinds with a server" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _project(tmpdir, "web-app");
        prog = JacProgram();
        mod = prog.compile(lib);
        assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
        js = mod.gen.js or "";
        assert "function activate" in js;
        assert "function deactivate" not in js , (
            "evidence-free pub in a full-stack project stays a server endpoint"
        );
    }
}


test "genuine server evidence in a serverless kind is a hard error" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _project(tmpdir, "js-package", SERVER_EVIDENCE_FIXTURE);
        prog = JacProgram();
        prog.compile(lib);
        errs = [
            e
            for e in prog.errors_had
            if e.code is not None and e.code.code == 'E5087'
        ];
        assert errs , (
            "a js-package ships as an npm tarball with no server, so code "
            "that needs one must say so at compile time instead of being "
            f"silently server-placed; got {[str(e) for e in prog.errors_had]}"
        );
        assert 'js-package' in str(errs[0]) , "E5087 must name the project kind";
    }
}


test "the same server evidence is fine for a kind that has a server" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _project(tmpdir, "web-app", SERVER_EVIDENCE_FIXTURE);
        prog = JacProgram();
        prog.compile(lib);
        errs = [
            e
            for e in prog.errors_had
            if e.code is not None and e.code.code == 'E5087'
        ];
        assert not errs , f"{[str(e) for e in errs]}";
    }
}


test "a nested manifest inherits the enclosing project kind" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _nested_project(tmpdir, "js-package", "");
        assert config_kind_space(lib) == "client" , (
            "a nested jac.toml without a kind must not shadow the kind of "
            "the project that contains it"
        );
    }
}


test "a nested manifest with its own kind keeps it" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _nested_project(tmpdir, "js-package", "web-app");
        assert config_kind_space(lib) == "" , (
            "an explicit nested kind is a deliberate override"
        );
    }
}


test "nested kind inheritance reaches the compiler, not just the resolver" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _nested_project(tmpdir, "js-package", "");
        prog = JacProgram();
        mod = prog.compile(lib);
        assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
        js = mod.gen.js or "";
        assert "function deactivate" in js , (
            "the inherited serverless kind must place the evidence-free pub "
            f"export client-side; got:\n{js}"
        );
    }
}
