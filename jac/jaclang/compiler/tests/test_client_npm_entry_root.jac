"""Type-checker tests for npm resolution from library client modules.

Regression coverage for the W1100 cascade on `@jac/runtime` re-exports: npm
package resolution walked up from the file containing the import statement to
its nearest jac.toml, so an `import from 'react-router-dom'` inside the shipped
client runtime resolved against the jaclang tree (or site-packages), never the
app project whose `.jac/client/node_modules` actually holds the package. Any
app symbol demanded through such a re-export (e.g. `<Outlet/>`) then cascaded
W1100 -> W1051 into user code.

The fix picks one resolution base per package: the importing file's own
installation when present, otherwise the compiled program's entry root, and
uses that same installation for both the module and its .d.ts declarations.
A library module importing an npm package installed only in the app's tree
must type-check clean; a library with its own untyped installation must not
borrow the entry project's declarations; a genuinely missing package must
still warn.
"""

import os;
import sys;
import shutil;
import tempfile;
import from jaclang.jac0core.program { JacProgram }


glob _LIB_SRC: str = (
         "import from 'fake-widgets' { makeWidget as _mw }\n"
         "\n"
         "glob make_widget = _mw;\n"
     ),
     _ENTRY_SRC: str = (
         "import from libmod { make_widget }\n"
         "\n"
         "def:pub run -> None {\n"
         "    make_widget();\n"
         "}\n"
     );


"""Install a fake-widgets package under `proj`'s client node_modules."""
def _install_pkg(proj: str, typed: bool) {
    pkg = os.path.join(proj, ".jac", "client", "node_modules", "fake-widgets");
    os.makedirs(pkg, exist_ok=True);
    pkg_json = '{"name": "fake-widgets", "main": "index.js"}\n';
    if typed {
        pkg_json = (
            '{"name": "fake-widgets", "main": "index.js",' ' "types": "index.d.ts"}\n'
        );
    }
    with open(os.path.join(pkg, "package.json"), "w") as f {
        f.write(pkg_json);
    }
    with open(os.path.join(pkg, "index.js"), "w") as f {
        f.write("export function makeWidget() { return {}; }\n");
    }
    if typed {
        with open(os.path.join(pkg, "index.d.ts"), "w") as f {
            f.write("export declare function makeWidget(): string;\n");
        }
    }
}


"""Write an app project and a separate library project; return (entry_file, lib_dir)."""
def _write_projects(
    base_dir: str, with_pkg: bool, lib_pkg: bool = False
) -> tuple[str, str] {
    app = os.path.join(base_dir, "app");
    lib = os.path.join(base_dir, "lib");
    os.makedirs(app, exist_ok=True);
    os.makedirs(lib, exist_ok=True);
    for proj in (app, lib) {
        with open(os.path.join(proj, "jac.toml"), "w") as f {
            f.write("[project]\nname = \"" + os.path.basename(proj) + "\"\n");
        }
    }
    if with_pkg {
        _install_pkg(app, typed=lib_pkg);
    }
    if lib_pkg {
        _install_pkg(lib, typed=False);
    }
    entry_file = os.path.join(app, "main.jac");
    with open(entry_file, "w") as f {
        f.write(_ENTRY_SRC);
    }
    with open(os.path.join(lib, "libmod.jac"), "w") as f {
        f.write(_LIB_SRC);
    }
    return (entry_file, lib);
}


"""Type-check the app entry with the library project visible on `sys.path`."""
def _check(entry_file: str, lib_dir: str) -> JacProgram {
    sys.path.insert(0, lib_dir);
    try {
        prog = JacProgram();
        prog.compile(file_path=entry_file, type_check=True, no_cgen=True);
        return prog;
    } finally {
        sys.path.remove(lib_dir);
    }
}


test "npm import in a library module resolves from the app entry root" {
    base_dir = tempfile.mkdtemp(prefix="jac_npm_root_");
    try {
        (entry_file, lib_dir) = _write_projects(base_dir, with_pkg=True);
        prog = _check(entry_file, lib_dir);
        w1100 = [
            str(w)
            for w in prog.warnings_had
            if w.code and w.code.code == "W1100"
        ];
        assert w1100 == [] , w1100;
    } finally {
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}


test "library-local installation never borrows entry declarations" {
    base_dir = tempfile.mkdtemp(prefix="jac_npm_root_");
    try {
        (entry_file, lib_dir) = _write_projects(base_dir, with_pkg=True, lib_pkg=True);
        prog = _check(entry_file, lib_dir);
        codes = [
            w.code.code
            for w in prog.warnings_had
            if w.code
        ];
        assert "W1100" not in codes , codes;
        assert "W1102" in codes , (
            "library's own untyped installation must stay foreign any; typing"
            + " it means the entry project's declarations leaked across"
            + " installations: "
            + str(codes)
        );
    } finally {
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}


test "npm import missing from both project roots still warns" {
    base_dir = tempfile.mkdtemp(prefix="jac_npm_root_");
    try {
        (entry_file, lib_dir) = _write_projects(base_dir, with_pkg=False);
        prog = _check(entry_file, lib_dir);
        w1100 = [
            str(w)
            for w in prog.warnings_had
            if w.code and w.code.code == "W1100"
        ];
        assert w1100 != [] , "unresolvable npm package must keep warning W1100";
    } finally {
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}
