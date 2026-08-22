"""Tests for the placement facts API, the single placement query surface."""

import os;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.placement_facts {
    client_only_paths,
    discover_spaces,
    emits_server_code,
    is_client_only,
    module_spaces,
    project_root_of,
    require_project_root,
    toolchain_native_by_policy
}

glob FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace"
     );


def _fixture(name: str) -> str {
    return os.path.join(FIXTURE_DIR, name);
}


test "a markerless inferred client module rolls up client-only" {
    prog = JacProgram();
    mod = prog.compile(_fixture("infer_client_app.jac"), no_cgen=True);
    assert module_spaces(mod) == {"client"};
    assert is_client_only(mod);
    assert not emits_server_code(mod);
}


test "a mixed module emits server code and is never client-only" {
    prog = JacProgram();
    mod = prog.compile(_fixture("infer_three_spaces.jac"), no_cgen=True);
    spaces = module_spaces(mod);
    assert "client" in spaces;
    assert "server" in spaces;
    assert emits_server_code(mod);
    assert not is_client_only(mod);
}


test "an empty or unreadable module defaults to server" {
    assert module_spaces(None) == {"server"};
    facts = discover_spaces([_fixture("does_not_exist.jac")]);
    assert facts[os.path.abspath(_fixture("does_not_exist.jac"))] == {"server"};
}


test "discover_spaces batches paths and client_only_paths filters them" {
    paths = [_fixture("infer_client_app.jac"), _fixture("infer_three_spaces.jac")];
    facts = discover_spaces(paths);
    assert facts[os.path.abspath(paths[0])] == {"client"};
    assert "server" in facts[os.path.abspath(paths[1])];
    assert client_only_paths(paths) == {os.path.abspath(paths[0])};
}


test "require_project_root is loud where project_root_of is soft" {
    d = tempfile.mkdtemp(prefix="jac-no-project-");
    outside = os.path.join(d, "orphan.jac");
    assert project_root_of(outside) is None;
    caught = False;
    try {
        require_project_root(outside);
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "a module with compile errors is never classified client-only" {
    d = tempfile.mkdtemp(prefix="jac-broken-client-");
    broken = os.path.join(d, "broken_page.jac");
    with open(broken, "w") as f {
        f.write(
            "node Todo {\n    has text: str\n        done: bool = False\n}\n"
                + "def:pub app -> JsxElement {\n    return <div>x</div>;\n}\n"
        );
    }
    facts = discover_spaces([broken]);
    spaces = facts[os.path.abspath(broken)];
    assert "server" in spaces , spaces;
    assert client_only_paths([broken]) == set();
}


test "sealed images persist placement and expose it without re-derivation" {
    import json;
    import from jaclang.jac0core.placement_facts { sealed_spaces_for }
    import from jaclang.jac0core.sealed { SealedImage, MANIFEST_FORMAT }
    d = tempfile.mkdtemp(prefix="jac-sealed-facts-");
    pre = os.path.join(d, "_precompiled");
    os.makedirs(pre);
    manifest = {
        "format": MANIFEST_FORMAT,
        "package": "app",
        "python_tag": f"cpython-{sys.version_info.major}{sys.version_info.minor}",
        "modules": {"svc.jac": {"module": "app.svc", "jir": "svc.jir"}},
        "placement": {"svc.jac": ["server"], "ui/page.jac": ["client"]}
    };
    with open(os.path.join(pre, "MANIFEST.json"), "w") as f {
        json.dump(manifest, f);
    }
    assert sealed_spaces_for(os.path.join(d, "svc.jac")) == {"server"};
    assert sealed_spaces_for(os.path.join(d, "ui", "page.jac")) == {"client"};
    assert sealed_spaces_for(os.path.join(d, "unknown.jac")) is None;
    import from pathlib { Path }
    img = SealedImage(Path(pre), manifest);
    assert img.placement == {"svc.jac": ["server"], "ui/page.jac": ["client"]};
    old = SealedImage(Path(pre), {"format": 4, "package": "app", "modules": {}});
    assert old.placement == {};
}


test "placement_pins imports stay within the documented allowlist" {
    import from pathlib { Path }
    allow = {
        "jaclang/cli/commands/impl/fix.impl.jac",
        "jaclang/jac0core/compiler.jac",
        "jaclang/jac0core/impl/compiler.impl.jac",
        "jaclang/jac0core/jir.jac",
        "jaclang/jac0core/modresolver.jac",
        "jaclang/jac0core/passes/impl/boundary_analysis_pass.impl.jac",
        "jaclang/jac0core/placement.jac",
        "jaclang/jac0core/placement_facts.jac",
        "jaclang/jac0core/placement_pins.jac",
        "jaclang/jac0core/placement_solver.jac"
    };
    pkg = os.path.join(JAC_ROOT, "jaclang");
    offenders: list[str] = [];
    for p in sorted(Path(pkg).rglob("*.jac")) {
        if not p.is_file() {
            continue;
        }
        rel = p.relative_to(JAC_ROOT).as_posix();
        if "/tests/" in rel or "/fixtures/" in rel or "/vendor/" in rel {
            continue;
        }
        if "placement_pins" in p.read_text(encoding="utf-8", errors="ignore")
            and rel not in allow {
            offenders.append(rel);
        }
    }
    assert not offenders , offenders;
}


test "toolchain native policy matches na_stdlib and desktop native trees" {
    pkg = os.path.join(JAC_ROOT, "jaclang");
    na = os.path.join(pkg, "runtimelib", "na_stdlib", "_bz2_native.jac");
    assert toolchain_native_by_policy(pkg, na);
    other = os.path.join(pkg, "utils", "precompile_bytecode.jac");
    assert not toolchain_native_by_policy(pkg, other);
}
