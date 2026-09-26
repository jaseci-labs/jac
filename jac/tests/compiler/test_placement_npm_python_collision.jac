"""A bare `import from X` is classified by what X resolves to for the
importing file, not by what happens to be installed under
`.jac/client/node_modules` (#9159).

Vite and friends fill the client node_modules tree with transitive
packages, and many of them share a name with a Python module (`dotenv`,
`argparse`, ...). An installed directory of that name used to be npm
evidence on its own, so a server-side Python import was seeded client and
dragged every element that used it, `walker:pub` endpoints included, into
the bundle. The universe is ordered instead: local Jac, then a declared
`[dependencies.npm]` name or the client framework's own packages, then
Python, and only then an installed-but-undeclared package.
"""

import os;
import shutil;
import tempfile;
import jaclang.compiler.frontend.unitree as uni;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.placement.placement_export { collect_placement_rows }
import from jaclang.compiler.placement.placement_pins {
    classify_bare_import,
    in_client_npm_world
}

glob STDLIB_SERVER_APP = (
         "import from argparse { ArgumentParser }\n"
         "\n"
         "def parser_ready() -> bool {\n"
         "    return ArgumentParser() is not None;\n"
         "}\n"
         "\n"
         "walker:pub settings_probe {\n"
         "    can go with Root entry {\n"
         "        report {\"ready\": parser_ready()};\n"
         "    }\n"
         "}\n"
     );


def _write_project(base: str, files: dict[str, str], npm_deps: str = "") -> Path {
    proj = Path(base);
    proj.mkdir(parents=True, exist_ok=True);
    toml = '[project]\nname = "npmcollision"\nversion = "0.1.0"\nentry-point = "main"\n';
    if npm_deps {
        toml += "\n[dependencies.npm]\n" + npm_deps;
    }
    (proj / "jac.toml").write_text(toml);
    for (rel, content) in files.items() {
        f = proj / rel;
        f.parent.mkdir(parents=True, exist_ok=True);
        f.write_text(content);
    }
    return proj;
}


def _install_pkg(proj: Path, name: str) {
    pkg = proj / ".jac" / "client" / "node_modules" / name;
    pkg.mkdir(parents=True, exist_ok=True);
    (pkg / "package.json").write_text(
        '{"name": "' + name + '", "version": "16.4.5", "main": "index.js"}'
    );
    (pkg / "index.js").write_text("export function nothing() {}\n");
}


def _compile(proj: Path) -> tuple[JacProgram, uni.Module] {
    prog = JacProgram();
    mod = prog.compile(str(proj / "main.jac"), no_cgen=True);
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    return (prog, mod);
}


def _stamps(mod: uni.Module) -> dict[str, str] {
    out: dict[str, str] = {};
    for stmt in mod.body {
        if isinstance(stmt, uni.Import) and stmt.from_loc is not None {
            out["from:" + stmt.from_loc.dot_path_str] = str(stmt.code_context);
        } elif isinstance(stmt, uni.Ability) and isinstance(stmt.name_ref, uni.Name) {
            out[stmt.name_ref.value] = str(stmt.code_context);
        } elif isinstance(stmt, uni.Archetype) {
            out[stmt.name.value] = str(stmt.code_context);
        }
    }
    return out;
}


def _evidence(prog: JacProgram, proj: Path, name: str) -> list[str] {
    rows = collect_placement_rows(prog);
    module_rows = rows.get(os.path.abspath(str(proj / "main.jac")));
    assert module_rows is not None , list(rows.keys());
    for row in module_rows["rows"] {
        if row["name"] == name {
            return [str(n) for n in row["evidence"]];
        }
    }
    return [];
}


test "a stdlib name stays server when an undeclared npm package shares it" {
    tmp = tempfile.mkdtemp(prefix="jac_npm_collision_");
    try {
        proj = _write_project(tmp, {"main.jac": STDLIB_SERVER_APP});
        _install_pkg(proj, "argparse");
        (prog, mod) = _compile(proj);
        stamps = _stamps(mod);
        assert stamps["from:argparse"] == "server" , stamps;
        assert stamps["parser_ready"] == "server" , stamps;
        assert stamps["settings_probe"] == "server" , stamps;
        notes = _evidence(prog, proj, "from:argparse");
        assert not any(n.startswith("NPM:") for n in notes) , notes;
        assert any(n.startswith("PY:") and "npm" in n for n in notes) , f"--placements must name the python-over-npm rule: {notes}";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "a sibling python module stays server when an undeclared npm package shares its name" {
    tmp = tempfile.mkdtemp(prefix="jac_npm_collision_");
    try {
        proj = _write_project(
            tmp,
            {
                "main.jac": (
                    "import from settings_util { load_settings }\n"
                    "\n"
                    "def:pub settings_loaded() -> bool {\n"
                    "    return bool(load_settings());\n"
                    "}\n"
                ),
                "settings_util.py": "def load_settings() -> bool:\n    return True\n"
            }
        );
        _install_pkg(proj, "settings_util");
        (prog, mod) = _compile(proj);
        stamps = _stamps(mod);
        assert stamps["from:settings_util"] == "server" , stamps;
        assert stamps["settings_loaded"] == "server" , stamps;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "a declared npm dependency wins over a same-named python module" {
    tmp = tempfile.mkdtemp(prefix="jac_npm_collision_");
    try {
        proj = _write_project(
            tmp,
            {
                "main.jac": (
                    "import from argparse { ArgumentParser }\n"
                    "\n"
                    "def parser_ready() -> bool {\n"
                    "    return ArgumentParser() is not None;\n"
                    "}\n"
                )
            },
            npm_deps='argparse = "*"\n'
        );
        _install_pkg(proj, "argparse");
        (prog, mod) = _compile(proj);
        stamps = _stamps(mod);
        assert stamps["from:argparse"] == "client" , stamps;
        notes = _evidence(prog, proj, "from:argparse");
        assert any(n.startswith("NPM:") and "[dependencies.npm]" in n for n in notes) , f"--placements must name the declared-dependency rule: {notes}";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "an undeclared installed package with no python counterpart is still npm" {
    tmp = tempfile.mkdtemp(prefix="jac_npm_collision_");
    try {
        proj = _write_project(
            tmp,
            {
                "main.jac": (
                    "import from widget_kit { makeWidget }\n"
                    "\n"
                    "def widget_label() -> str {\n"
                    "    return str(makeWidget());\n"
                    "}\n"
                )
            }
        );
        _install_pkg(proj, "widget_kit");
        (prog, mod) = _compile(proj);
        stamps = _stamps(mod);
        assert stamps["from:widget_kit"] == "client" , stamps;
        notes = _evidence(prog, proj, "from:widget_kit");
        assert any(n.startswith("NPM:") and "node_modules" in n for n in notes) , f"--placements must name the installed-package rule: {notes}";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "classify_bare_import orders the universe and names each rule" {
    tmp = tempfile.mkdtemp(prefix="jac_npm_collision_");
    try {
        proj = _write_project(
            tmp,
            {
                "main.jac": "def:pub app -> JsxElement { return <div/>; }\n",
                "helpers.jac": "def helper -> int { return 1; }\n"
            }
        );
        for name in ["helpers", "argparse", "widget_kit"] {
            _install_pkg(proj, name);
        }
        main = str(proj / "main.jac");
        assert classify_bare_import("helpers", main).world == "jac" , "a local jac module wins over the installed package";
        assert in_client_npm_world("helpers", main) , "membership still sees the installed package (W1105)";
        framework = classify_bare_import("react", main);
        assert framework.world == "npm" and "framework package" in framework.rule , framework.rule;
        shadowed = classify_bare_import("argparse", main);
        assert shadowed.world == "py" and "undeclared npm package" in shadowed.rule , shadowed.rule;
        assert shadowed.path != "" , "the python resolution is reported";
        installed = classify_bare_import("widget_kit", main);
        assert installed.world == "npm" and "node_modules" in installed.rule , installed.rule;
        ghost = classify_bare_import("ghost_pkg", main);
        assert ghost.world == "py" and ghost.path == "" , (ghost.world, ghost.path);
        assert not in_client_npm_world("ghost_pkg", main);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
