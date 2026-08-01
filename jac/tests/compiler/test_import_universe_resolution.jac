"""Resolution decides what an import is -- not quoting.

A bare identifier module name resolves across the universe in order:
local Jac module, then Python, then (for client-placed code) the client
npm world -- where "npm world" is the union of jac.toml
`[dependencies.npm]`, the active client framework's own packages, and
what is physically installed under `.jac/client/node_modules`. Inference
types the import from the resolved artifact (`.d.ts` for npm), emission
follows the same classification, and an import that client code uses but
that resolves nowhere is a hard error -- never a silent drop.
"""

import os;
import shutil;
import tempfile;
import jaclang;
import jaclang.jac0core.unitree as uni;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }

glob REACT_DTS = (
         "export declare function createContext(x: any): any;\n"
         "export declare function useEffect(cb: any, deps?: any): void;\n"
     ),
     REACT_JS = (
         "export function createContext(x) { return { value: x }; }\n"
         "export function useEffect(cb, deps) {}\n"
     );

def _write_project(base: str, files: dict[str, str], npm_deps: str = "") -> Path {
    proj = Path(base);
    proj.mkdir(parents=True, exist_ok=True);
    (proj / "jac.toml").write_text(
        '[project]\nname = "universe"\nversion = "0.1.0"\n'
        'entry-point = "main.jac"\n\n[dependencies.npm]\n'
            + npm_deps
    );
    for (rel, content) in files.items() {
        f = proj / rel;
        f.parent.mkdir(parents=True, exist_ok=True);
        f.write_text(content);
    }
    return proj;
}

def _install_pkg(proj: Path, name: str, with_types: bool = True) {
    pkg = proj / ".jac" / "client" / "node_modules" / name;
    pkg.mkdir(parents=True, exist_ok=True);
    types_line = '"types": "index.d.ts",' if with_types else '';
    pkg_json = (
        '{"name": "'
        + name
        + '", "version": "1.0.0",'
        + types_line
        + '"main": "index.js"}'
    );
    (pkg / "package.json").write_text(pkg_json);
    (pkg / "index.js").write_text(REACT_JS);
    if with_types {
        (pkg / "index.d.ts").write_text(REACT_DTS);
    }
}

def _compile(proj: Path, type_check: bool = False) -> tuple {
    prog = JacProgram();
    mod = prog.compile(str(proj / "main.jac"), type_check=type_check);
    errs = [
        e.code.code
        for e in prog.errors_had
        if e.code is not None
    ];
    warns = [
        w.code.code
        for w in prog.warnings_had
        if w.code is not None
    ];
    return (prog, mod, errs, warns);
}

def _import_stamp(mod: uni.Module, base_name: str) -> str {
    for stmt in mod.body {
        if (
            isinstance(stmt, uni.Import)
            and stmt.from_loc is not None
            and stmt.from_loc.base_module_name == base_name
        ) {
            return str(stmt.code_context);
        }
    }
    return "missing";
}

glob CLIENT_APP = (
         "import from react { createContext }\n"
         "\n"
         "glob ctx: any = createContext(None);\n"
         "\n"
         "def:pub app -> JsxElement {\n"
         "    return <div>{str(ctx)}</div>;\n"
         "}\n"
     );

test "bare npm import in a client module is placed client plus emitted" {
    tmp = tempfile.mkdtemp(prefix="jac_universe_");
    try {
        proj = _write_project(tmp, {"main.jac": CLIENT_APP});
        _install_pkg(proj, "react");
        (prog, mod, errs, warns) = _compile(proj, type_check=True);
        assert _import_stamp(mod, "react") == "client" , "bare react import should classify client via resolution";
        js = mod.gen.js or "";
        assert 'from "react"' in js , "emitted JS must import from the npm package";
        assert "createContext" in js;
        assert "W1100" not in warns , "resolved npm import must not warn module-not-found";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "framework packages classify client before any install" {
    tmp = tempfile.mkdtemp(prefix="jac_universe_");
    try {
        proj = _write_project(tmp, {"main.jac": CLIENT_APP});
        (prog, mod, errs, warns) = _compile(proj);
        assert _import_stamp(mod, "react") == "client" , "the active framework's own package is always npm";
        js = mod.gen.js or "";
        assert 'from "react"' in js;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "a local jac module shadows the npm name" {
    tmp = tempfile.mkdtemp(prefix="jac_universe_");
    try {
        proj = _write_project(
            tmp,
            {
                "main.jac": (
                    "import from react { Helper }\n"
                    "\n"
                    "def:pub app -> JsxElement {\n"
                    "    return <div><Helper/></div>;\n"
                    "}\n"
                ),
                "react.jac": (
                    "def:pub Helper -> JsxElement {\n"
                    "    return <span>local</span>;\n"
                    "}\n"
                )
            }
        );
        _install_pkg(proj, "react");
        (prog, mod, errs, warns) = _compile(proj, type_check=True);
        js = mod.gen.js or "";
        assert "./react.js" in js , "local jac module must win over the npm package";
        assert 'from "react"' not in js.replace("./react.js", "") , "npm specifier must not appear";
        assert "W1105" in warns , "shadowing an npm name deserves a diagnostic";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "a dropped client-used import is a hard error" {
    tmp = tempfile.mkdtemp(prefix="jac_universe_");
    try {
        proj = _write_project(
            tmp,
            {
                "main.jac": (
                    "import from ghost_pkg { spooky }\n"
                    "\n"
                    "def:pub app -> JsxElement {\n"
                    "    return <div>{spooky()}</div>;\n"
                    "}\n"
                )
            }
        );
        (prog, mod, errs, warns) = _compile(proj);
        assert "E5084" in errs , "client code using an unresolvable import must fail the build";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "server-only python import in a mixed module prunes silently" {
    tmp = tempfile.mkdtemp(prefix="jac_universe_");
    try {
        proj = _write_project(
            tmp,
            {
                "main.jac": (
                    "import from os { getcwd }\n"
                    "\n"
                    "def:pub where_am_i -> str {\n"
                    "    return getcwd();\n"
                    "}\n"
                    "\n"
                    "def:pub app -> JsxElement {\n"
                    "    return <div>hello</div>;\n"
                    "}\n"
                )
            }
        );
        (prog, mod, errs, warns) = _compile(proj);
        assert "E5084" not in errs , "server-side uses must not trip the client import error";
        js = mod.gen.js or "";
        assert 'from "os"' not in js , "python import must stay out of the bundle";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
