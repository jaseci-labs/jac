"""Type-checker coverage for the `@jac/mobui` surface.

`@jac/mobui` is the primitive set every `kind = "mobile"` app is written
against, and shared phone UI promoted to a workspace's `core/` tree imports it
too. The module resolver maps `@jac/<name>` to `jaclang/client/<name>.jac`,
but the mobUI shim ships as `client_mobui.jac`, so the import never resolved:
every `import from "@jac/mobui"` warned W1100, every primitive typed as
Unknown, and each use cascaded W1051 through the app. The runtime never
noticed because the bundler aliases the specifier on its own.

Resolving the shim is not enough on its own: it re-exports `react-native`,
whose declarations are absent from a react-native-web project's
`node_modules`, so the exports would still be Unknown. The typed surface is
the shim's sibling `client_mobui.d.ts`, read through the same declaration
route every npm import uses, and it must name every export the shim makes.
"""

import os;
import shutil;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.modresolver { resolve_jac_virtual_module_path }
import from jaclang.compiler.types.type_evaluator { FunctionType, UnknownType }
import from jaclang.compiler.frontend.unitree { Import, ModuleItem }


glob _TOML: str = (
         "[project]\n"
         "name = \"phone_ws\"\n"
         "\n"
         "[apps.mobile]\n"
         "kind = \"mobile\"\n"
         "path = \"mobile\"\n"
     ),
     _SHARED_SRC: str = (
         "import from \"@jac/mobui\" { View, Text, StyleSheet }\n"
         "\n"
         "glob:pub styles = StyleSheet.create({\"root\": {\"flex\": 1}});\n"
         "\n"
         "def:pub Phone(label: str) -> JsxElement {\n"
         "    return <View style={styles.root}><Text>{label}</Text></View>;\n"
         "}\n"
     ),
     _ENTRY_SRC: str = (
         "import from \"@jac/mobui\" { View, useWindowDimensions }\n"
         "import from core.phone { Phone }\n"
         "\n"
         "def:pub app -> JsxElement {\n"
         "    viewport = useWindowDimensions();\n"
         "    return <View style={{\"height\": viewport.height}}><Phone label=\"hi\"/></View>;\n"
         "}\n"
     );


"""Write a workspace with a mobile app over a shared core module; return the entry."""
def _write_workspace(base_dir: str) -> str {
    os.makedirs(os.path.join(base_dir, "mobile"), exist_ok=True);
    os.makedirs(os.path.join(base_dir, "core"), exist_ok=True);
    with open(os.path.join(base_dir, "jac.toml"), "w") as f {
        f.write(_TOML);
    }
    with open(os.path.join(base_dir, "core", "phone.jac"), "w") as f {
        f.write(_SHARED_SRC);
    }
    entry_file = os.path.join(base_dir, "mobile", "main.jac");
    with open(entry_file, "w") as f {
        f.write(_ENTRY_SRC);
    }
    return entry_file;
}


def _codes_by_file(prog: JacProgram) -> dict[str, list[str]] {
    out: dict[str, list[str]] = {};
    for w in prog.warnings_had {
        if not w.code {
            continue;
        }
        name = os.path.basename(w.loc.mod_path) if w.loc else "";
        out.setdefault(name, []).append(w.code.code);
    }
    return out;
}


def _import_binding_type(prog: JacProgram, mod_path: str, name: str) -> object {
    mod = prog.find_module(os.path.realpath(mod_path));
    assert mod is not None , mod_path;
    for imp in mod.get_all_sub_nodes(Import) {
        for item in imp.items {
            if isinstance(item, ModuleItem) and item.name.value == name {
                return item.name.type;
            }
        }
    }
    raise AssertionError(f"no import of {name} in {mod_path}");
}


test "the mobui shim resolves as a virtual module" {
    path = resolve_jac_virtual_module_path("@jac/mobui");
    assert path is not None and path.endswith("client_mobui.jac") , path;
    pwa = resolve_jac_virtual_module_path("@jac/pwa");
    assert pwa is not None and pwa.endswith("pwa_runtime.jac") , pwa;
}


test "mobui imports resolve and type from the app root and from shared code" {
    base_dir = tempfile.mkdtemp(prefix="jac_mobui_typing_");
    try {
        entry_file = _write_workspace(base_dir);
        prog = JacProgram();
        prog.compile(file_path=entry_file, no_cgen=True);
        errors = [str(e) for e in prog.errors_had];
        assert errors == [] , errors;
        codes = _codes_by_file(prog);
        for name in ("main.jac", "phone.jac") {
            file_codes = codes.get(name, []);
            assert "W1100" not in file_codes , (name, file_codes);
            assert "W1051" not in file_codes , (name, file_codes);
        }
        view_type = _import_binding_type(
            prog, os.path.join(base_dir, "core", "phone.jac"), "View"
        );
        assert isinstance(view_type, FunctionType) , view_type;
        sheet_type = _import_binding_type(
            prog, os.path.join(base_dir, "core", "phone.jac"), "StyleSheet"
        );
        assert not isinstance(sheet_type, UnknownType) , sheet_type;
    } finally {
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}


test "the mobui declarations name every export of the shim" {
    import jaclang;
    import from jaclang.compiler.types.ts_decl_parser { parse_dts }
    client_dir = os.path.join(os.path.dirname(jaclang.__file__), "client");
    shim = os.path.join(client_dir, "client_mobui.jac");
    dts = os.path.join(client_dir, "client_mobui.d.ts");
    assert os.path.isfile(dts) , dts;
    prog = JacProgram();
    prog.compile(file_path=shim, no_cgen=True);
    mod = prog.find_module(os.path.realpath(shim));
    assert mod is not None;
    exported = sorted(
        name
        for (name, sym) in mod.sym_tab.names_in_scope.items()
        if sym.decl and sym.decl.find_parent_of_type(Import) is None
    );
    assert exported , "shim exports nothing?";
    with open(dts, "r", encoding="utf-8") as f {
        decls = parse_dts(f.read());
    }
    missing = [
        name
        for name in exported
        if name not in decls
    ];
    assert missing == [] , missing;
}


test "an unknown prop on a mobui primitive is rejected" {
    base_dir = tempfile.mkdtemp(prefix="jac_mobui_typing_");
    try {
        entry_file = _write_workspace(base_dir);
        with open(os.path.join(base_dir, "core", "phone.jac"), "w") as f {
            f.write(
                _SHARED_SRC.replace(
                    "<View style={styles.root}>", "<View stlye={styles.root}>"
                )
            );
        }
        with open(entry_file, "w") as f {
            f.write(_ENTRY_SRC.replace("<View style=", "<View stlye="));
        }
        for root_file in (entry_file, os.path.join(base_dir, "core", "phone.jac")) {
            prog = JacProgram();
            prog.compile(file_path=root_file, no_cgen=True);
            codes = [
                e.code.code
                for e in prog.errors_had
                if e.code
            ];
            assert "E1101" in codes , (root_file, [str(e) for e in prog.errors_had]);
        }
    } finally {
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}
