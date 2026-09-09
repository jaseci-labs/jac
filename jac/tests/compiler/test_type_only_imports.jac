"""Type-only import bindings: E1131 and E1132.

A TypeScript `interface` (or `type` alias) has no runtime export. Importing one
through a plain `import from` used to pass `jac check` silently and then emit a
named ESM specifier the browser refuses at link time, taking the whole module
graph down with it. The same hole existed with no npm involved: a client module
value-importing another `.jac` module's `type` alias emitted a specifier for a
binding the ES backend never defines.

Import bindings now carry a kind (value / type / both) inherited from whatever
they resolve to, so the checker speaks at the import instead of the browser
speaking at load:

- E1131: a type-only target reached through a plain (value) import.
- E1132: a binding brought in with `import type` used in value position.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from typing { cast }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.transform { Alert }
import from tests.compiler.passes.checker_npm_harness {
    check_npm_file,
    client_node_modules,
    install_npm_pkg,
    pretty_checker_errors,
    write_client_jac_project
}

glob KIND_DTS: str = (
         "export interface Iface { a: string; }\n"
         "export type Alias = string;\n"
         "export declare class C { v: string; }\n"
         "export declare const x: Iface;\n"
         "export declare function helper(): void;\n"
     ),
     MERMAID_DTS: str = (
         "export interface Mermaid {\n"
         "    initialize(config: any): void;\n"
         "}\n"
         "declare const mermaid: Mermaid;\n"
         "export default mermaid;\n"
     );


"""The diagnostic codes carried by a list of alerts, in order."""
def codes_of(alerts: list[Alert]) -> list[str] {
    return [
        a.code.code
        for a in alerts
        if a.code is not None
    ];
}


"""Every alert in `alerts` registered under `code`."""
def alerts_with(alerts: list[Alert], code: str) -> list[Alert] {
    return [
        a
        for a in alerts
        if a.code is not None and a.code.code == code
    ];
}


"""Install a package shipping one `.d.ts` and write the client project."""
def make_dts_project(
    proj_dir: Path, pkg: str, dts: str, mjs: str, project_name: str
) -> Path {
    install_npm_pkg(
        client_node_modules(proj_dir),
        pkg,
        '{"name":"'
            + pkg
            + '","version":"1.0.0",'
            '"exports":{".":{"types":"./dist/index.d.ts",'
            '"import":"./dist/index.mjs"}}}',
        {"dist/index.mjs": mjs, "dist/index.d.ts": dts}
    );
    write_client_jac_project(
        proj_dir, project_name, "lib/app.jac", pkg + ' = "^1.0.0"\n'
    );
    return proj_dir;
}


"""Materialize the mixed-kind `kindpkg` fixture project."""
def make_kind_project(proj_dir: Path) -> Path {
    return make_dts_project(
        proj_dir,
        "kindpkg",
        KIND_DTS,
        "export function helper() {}\nexport const x = {};\nexport class C {}\n",
        "kindfixture"
    );
}


"""Materialize the `mermaid` reproduction fixture project."""
def make_mermaid_project(proj_dir: Path) -> Path {
    return make_dts_project(
        proj_dir,
        "mermaid",
        MERMAID_DTS,
        "const mermaid = {};\nexport default mermaid;\n",
        "mermaidfixture"
    );
}


"""Write a client-pinned jac project root directory and return it."""
def write_pinned_project(proj_root: Path) -> Path {
    (proj_root / "jac.toml").write_text(
        '[project]\nname = "typeonly"\nversion = "0.1.0"\n'
        'entry-point = "app.jac"\n\n'
        '[placement.pins]\n"*" = "client"\n'
    );
    return proj_root;
}


"""Compile `path` and return (program, module)."""
def compile_module(path: Path) -> tuple[JacProgram, any] {
    prog = JacProgram();
    mod = prog.compile(str(path));
    return (prog, mod);
}


# ---------------------------------------------------------------------------
# 1. npm `.d.ts`: only the type-only kinds are refused
# ---------------------------------------------------------------------------

test "plain import of a d.ts interface is refused, its sibling function is not" {
    with TemporaryDirectory() as td {
        proj = make_kind_project(Path(cast(str, td)));
        f = proj / "lib" / "app.jac";
        f.write_text('import from "kindpkg" { Iface, helper }\n');
        (program, err_codes, _) = check_npm_file(f);
        hits = alerts_with(program.errors_had, "E1131");
        assert len(hits) == 1 , f"Expected exactly one E1131 (for Iface), got codes {err_codes}:\n{pretty_checker_errors(
            program
        )}";
        assert "Iface" in hits[0].msg , f"E1131 should name Iface, got: {hits[0].msg}";
        assert hits[0].loc.mod_path == str(f) , f"E1131 should be reported in the importing file, got {hits[
            0
        ].loc.mod_path}";
        assert hits[0].loc.first_line == 1 , f"E1131 should be anchored on line 1, got {hits[
            0
        ].loc.first_line}";
        src = f.read_text();
        assert src[hits[0].loc.pos_start:].startswith("Iface") , f"E1131 should be anchored at the Iface token, got offset {hits[
            0
        ].loc.pos_start} into {src!r}";
    }
}


test "plain import of a d.ts type alias is refused" {
    with TemporaryDirectory() as td {
        proj = make_kind_project(Path(cast(str, td)));
        f = proj / "lib" / "alias.jac";
        f.write_text('import from "kindpkg" { Alias }\n');
        (program, err_codes, _) = check_npm_file(f);
        assert "E1131" in err_codes , f"Expected E1131 for a d.ts `type` alias, got codes {err_codes}:\n{pretty_checker_errors(
            program
        )}";
    }
}


test "plain import of a d.ts class, const, or function is accepted" {
    with TemporaryDirectory() as td {
        proj = make_kind_project(Path(cast(str, td)));
        f = proj / "lib" / "values.jac";
        f.write_text('import from "kindpkg" { C, x, helper }\n');
        (program, err_codes, _) = check_npm_file(f);
        assert "E1131" not in err_codes , f"A class/const/function export is a runtime value; got codes {err_codes}:\n{pretty_checker_errors(
            program
        )}";
    }
}


# ---------------------------------------------------------------------------
# 2. `import type` is the accepted spelling and emits no JS
# ---------------------------------------------------------------------------

test "import type of a d.ts interface checks clean and emits no specifier" {
    with TemporaryDirectory() as td {
        proj = make_kind_project(Path(cast(str, td)));
        f = proj / "lib" / "typed.jac";
        f.write_text(
            'import type from "kindpkg" { Iface }\n\n'
            'def:pub label(v: Iface) -> str {\n'
            '    w = v as Iface;\n'
            '    return w.a;\n'
            '}\n'
        );
        (program, err_codes, _) = check_npm_file(f);
        assert not program.errors_had , f"`import type` in type position should check clean, got:\n{pretty_checker_errors(
            program
        )}";
        (prog2, mod) = compile_module(f);
        js = mod.gen.js;
        assert js.strip() , "Expected JS output for the client module";
        assert "kindpkg" not in js , f"A type-only import must not reach the ESM output:\n{js}";
        assert "Iface" not in js , f"A type-only binding must not reach the ESM output:\n{js}";
    }
}


# ---------------------------------------------------------------------------
# 3. Jac-to-Jac: a `type` alias is type-only with no npm involved
# ---------------------------------------------------------------------------

test "plain import of a jac type alias is refused; import type is clean" {
    with TemporaryDirectory() as td {
        proj_root = write_pinned_project(Path(cast(str, td)));
        (proj_root / "rows.jac").write_text("type Row = dict[str, int];\n");
        bad = proj_root / "bad.jac";
        bad.write_text(
            'import from .rows { Row }\n\n'
            'def:pub first(r: Row) -> int {\n'
            '    return len(r);\n'
            '}\n'
        );
        (prog_bad, _mod_bad) = compile_module(bad);
        assert "E1131" in codes_of(prog_bad.errors_had) , f"Expected E1131 value-importing a jac `type` alias, got {codes_of(
            prog_bad.errors_had
        )}";
        good = proj_root / "good.jac";
        good.write_text(
            'import type from .rows { Row }\n\n'
            'def:pub first(r: Row) -> int {\n'
            '    return len(r);\n'
            '}\n'
        );
        (prog_good, mod_good) = compile_module(good);
        assert "E1131" not in codes_of(prog_good.errors_had) , f"`import type` of a jac type alias should be clean, got {codes_of(
            prog_good.errors_had
        )}";
        assert "Row" not in mod_good.gen.js , f"A type-only binding must not reach the ESM output:\n{mod_good.gen.js}";
    }
}


glob BRAND_SRC: str = "type UserId := int;\n",
     BRAND_USE_SRC: str = (
         "import from .brands { UserId }\n\n"
         "def mk(raw: int) -> UserId {\n"
         "    return UserId(raw);\n"
         "}\n"
     );


"""Write an unpinned (server) jac project root and return it."""
def write_server_project(proj_root: Path, entry_mod: str) -> Path {
    (proj_root / "jac.toml").write_text(
        '[project]\nname = "typeonlysv"\nversion = "0.1.0"\n' 'entry-point = "'
            + entry_mod
            + '"\n'
    );
    return proj_root;
}


test "a server module may value-import a jac type alias and construct it" {
    # The python backend lowers `type UserId := int;` to a real runtime binding
    # (`UserId = int`), so `UserId(raw)` is the documented way to build a brand
    # -- E1107 exists to keep the base primitive precisely so this works. E1131
    # must not push cross-module brand construction onto `import type`.
    with TemporaryDirectory() as td {
        proj_root = write_server_project(Path(cast(str, td)), "use.jac");
        (proj_root / "brands.jac").write_text(BRAND_SRC);
        f = proj_root / "use.jac";
        f.write_text(BRAND_USE_SRC);
        (prog, _mod) = compile_module(f);
        assert not prog.errors_had , f"A server-side brand construction through a plain import must be clean, got {[
            str(e) for e in prog.errors_had
        ]}";
    }
}


test "a client module may not value-import a jac type alias" {
    # Only the ES backend erases an alias, so the very same pair is an error
    # once the importing module is client code.
    with TemporaryDirectory() as td {
        proj_root = write_pinned_project(Path(cast(str, td)));
        (proj_root / "brands.jac").write_text(BRAND_SRC);
        f = proj_root / "use.jac";
        f.write_text(BRAND_USE_SRC);
        (prog, _mod) = compile_module(f);
        hits = alerts_with(prog.errors_had, "E1131");
        assert len(hits) == 1 , f"Expected E1131 on the client side, got {codes_of(
            prog.errors_had
        )}";
        src = f.read_text();
        assert src[hits[0].loc.pos_start:].startswith("UserId") , "E1131 should be anchored at the UserId token";
        assert "in client code" in hits[0].msg , f"E1131 must scope the claim to client code, got: {hits[
            0
        ].msg}";
    }
}


test "import type of a jac alias erases it on the server too, so value use is E1132" {
    # The remedy E1131 offers has teeth: on the server an `import type` lowers
    # to a TYPE_CHECKING guard, so the name is not there at run time and the
    # constructor call is refused rather than left to fail as a NameError.
    with TemporaryDirectory() as td {
        proj_root = write_server_project(Path(cast(str, td)), "use.jac");
        (proj_root / "brands.jac").write_text(BRAND_SRC);
        f = proj_root / "use.jac";
        f.write_text(
            "import type from .brands { UserId }\n\n"
            "def mk(raw: int) -> UserId {\n"
            "    return UserId(raw);\n"
            "}\n"
        );
        (prog, _mod) = compile_module(f);
        assert "E1132" in codes_of(prog.errors_had) , f"Expected E1132 for a guarded alias used as a constructor, got {codes_of(
            prog.errors_had
        )}";
    }
}


test "a server has-field may be typed by a plainly imported jac alias" {
    # The docs' own caveat: an archetype field type is resolved at run time
    # through typing.get_type_hints, so pushing this onto `import type` would
    # break it. A plain import has to stay legal here.
    with TemporaryDirectory() as td {
        proj_root = write_server_project(Path(cast(str, td)), "store.jac");
        (proj_root / "rows.jac").write_text("type Row = dict[str, int];\n");
        f = proj_root / "store.jac";
        f.write_text(
            "import from .rows { Row }\n\n"
            "obj Store {\n"
            "    has rows: Row = {};\n"
            "}\n"
        );
        (prog, _mod) = compile_module(f);
        assert not prog.errors_had , f"A server `has` field typed by a plainly imported alias must be clean, got {[
            str(e) for e in prog.errors_had
        ]}";
    }
}


# ---------------------------------------------------------------------------
# 4. E1132: a type-only binding used in value position
# ---------------------------------------------------------------------------

glob POINT_SRC: str = (
         "obj Point {\n"
         "    has x: int = 0,\n"
         "        y: int = 0;\n"
         "    static def origin -> Point { return Point(); }\n"
         "}\n"
     ),
     VALUE_USES_SRC: str = (
         "import type from .point { Point }\n\n"
         "def:pub use(p: Point) -> int {\n"
         "    q = Point(1, 2);\n"
         "    f = Point.origin;\n"
         "    if isinstance(p, Point) {\n"
         "        return q.x;\n"
         "    }\n"
         "    return 0;\n"
         "}\n"
     ),
     TYPE_USES_SRC: str = (
         "import type from .point { Point }\n\n"
         "def:pub use(p: Point) -> int {\n"
         "    q: Point = p as Point;\n"
         "    return q.x;\n"
         "}\n"
     );


test "value uses of an import-type binding are refused in a client module" {
    with TemporaryDirectory() as td {
        proj_root = write_pinned_project(Path(cast(str, td)));
        (proj_root / "point.jac").write_text(POINT_SRC);
        f = proj_root / "uses.jac";
        f.write_text(VALUE_USES_SRC);
        (prog, _mod) = compile_module(f);
        hits = alerts_with(prog.errors_had, "E1132");
        assert len(hits) == 3 , f"Expected E1132 at the call, the attribute access and the isinstance arg; got {len(
            hits
        )}: {[a.msg for a in prog.errors_had]}";
        for a in hits {
            assert "Point" in a.msg , f"E1132 should name Point, got: {a.msg}";
        }
    }
}


test "type uses of an import-type binding are accepted in a client module" {
    with TemporaryDirectory() as td {
        proj_root = write_pinned_project(Path(cast(str, td)));
        (proj_root / "point.jac").write_text(POINT_SRC);
        f = proj_root / "typeuses.jac";
        f.write_text(TYPE_USES_SRC);
        (prog, _mod) = compile_module(f);
        assert "E1132" not in codes_of(prog.errors_had) , f"Annotations and `as` casts are type position; got {codes_of(
            prog.errors_had
        )}";
    }
}


test "value uses of an import-type binding are refused in a server module" {
    with TemporaryDirectory() as td {
        proj_root = Path(cast(str, td));
        (proj_root / "jac.toml").write_text(
            '[project]\nname = "typeonlysv"\nversion = "0.1.0"\n'
            'entry-point = "uses.jac"\n'
        );
        (proj_root / "point.jac").write_text(POINT_SRC);
        f = proj_root / "uses.jac";
        f.write_text(VALUE_USES_SRC);
        (prog, _mod) = compile_module(f);
        hits = alerts_with(prog.errors_had, "E1132");
        assert len(hits) == 3 , f"E1132 is codespace-independent; expected 3 on the server side, got {len(
            hits
        )}: {[a.msg for a in prog.errors_had]}";
    }
}


test "type uses of an import-type binding are accepted in a server module" {
    with TemporaryDirectory() as td {
        proj_root = Path(cast(str, td));
        (proj_root / "jac.toml").write_text(
            '[project]\nname = "typeonlysv"\nversion = "0.1.0"\n'
            'entry-point = "typeuses.jac"\n'
        );
        (proj_root / "point.jac").write_text(POINT_SRC);
        f = proj_root / "typeuses.jac";
        f.write_text(TYPE_USES_SRC);
        (prog, _mod) = compile_module(f);
        assert "E1132" not in codes_of(prog.errors_had) , f"Annotations and `as` casts are type position; got {codes_of(
            prog.errors_had
        )}";
    }
}


# ---------------------------------------------------------------------------
# 5. Guard: the bridged-import stub path still skips archetypes, keeps functions
# ---------------------------------------------------------------------------

test "bridged import stubs skip archetype items and keep function items" {
    # Guards the unification of `_sv_import_item_is_type` onto the binding-kind
    # fact: an `obj` crossing the client/server boundary is a type item (no RPC
    # stub -- it arrives as a boundary-type class), while the ability beside it
    # in the same import keeps its stub.
    with TemporaryDirectory() as td {
        proj_root = Path(cast(str, td));
        (proj_root / "jac.toml").write_text(
            '[project]\nname = "svstub"\nversion = "0.1.0"\n'
            'entry-point = "page.jac"\n\n'
            '[placement.pins]\napi = "server"\npage = "client"\n'
        );
        (proj_root / "api.jac").write_text(
            "obj Todo {\n"
            "    has title: str;\n"
            "}\n\n"
            "def:pub get_todos -> list[Todo] {\n"
            "    return [Todo(title=\"a\")];\n"
            "}\n"
        );
        page = proj_root / "page.jac";
        page.write_text(
            "import from .api { Todo, get_todos }\n\n"
            "def:pub app -> JsxElement {\n"
            "    has todos: list[Todo] = [];\n\n"
            "    async can with entry {\n"
            "        todos = await get_todos();\n"
            "    }\n"
            "    return <div>{len(todos)}</div>;\n"
            "}\n"
        );
        (prog, mod) = compile_module(page);
        assert "E1131" not in codes_of(prog.errors_had) , f"An `obj` is both a value and a type, so a plain import of one is legal. Got {codes_of(
            prog.errors_had
        )}";
        js = mod.gen.js;
        assert "__jacCallFunction" in js , f"get_todos should keep its RPC stub:\n{js}";
        assert "class Todo" in js , f"Todo should cross as a boundary-type class stub:\n{js}";
        assert "Todo = async" not in js , f"Todo is a type item and must not get an RPC stub:\n{js}";
    }
}


# ---------------------------------------------------------------------------
# 6. The original shape: mermaid's default export plus its interface
# ---------------------------------------------------------------------------

test "the mermaid shape is refused as written and clean when split" {
    with TemporaryDirectory() as td {
        proj = make_mermaid_project(Path(cast(str, td)));
        broken = proj / "lib" / "app.jac";
        broken.write_text(
            'import from "mermaid" { default as mermaid, Mermaid }\n\n'
            'glob _mm: Mermaid = mermaid as Mermaid;\n'
        );
        (program, err_codes, _) = check_npm_file(broken);
        hits = alerts_with(program.errors_had, "E1131");
        assert len(hits) == 1 , f"Expected exactly one E1131 (for Mermaid, not the default), got codes {err_codes}:\n{pretty_checker_errors(
            program
        )}";
        assert "Mermaid" in hits[0].msg , f"E1131 should name Mermaid, got: {hits[
            0
        ].msg}";
        broken_src = broken.read_text();
        assert broken_src[hits[0].loc.pos_start:].startswith("Mermaid") , f"E1131 should be anchored at the Mermaid token, got offset {hits[
            0
        ].loc.pos_start}";
        fixed = proj / "lib" / "fixed.jac";
        fixed.write_text(
            'import from "mermaid" { default as mermaid }\n'
            'import type from "mermaid" { Mermaid }\n\n'
            'glob _mm: Mermaid = mermaid as Mermaid;\n'
        );
        (program2, err_codes2, _) = check_npm_file(fixed);
        assert not program2.errors_had , f"The split form should check clean, got:\n{pretty_checker_errors(
            program2
        )}";
        (prog3, mod) = compile_module(fixed);
        js = mod.gen.js;
        assert 'import mermaid from "mermaid"' in js , f"Only the default value import should survive:\n{js}";
        assert "Mermaid" not in js.replace('import mermaid from "mermaid"', "") , f"The interface must not reach the ESM output:\n{js}";
    }
}


# ---------------------------------------------------------------------------
# 6. The binding's symbol category agrees with its kind
# ---------------------------------------------------------------------------

test "an imported d.ts binding takes the symbol category its kind implies" {
    import from jaclang.compiler.frontend.constant { SymbolType }
    import from jaclang.compiler.frontend.unitree { ModuleItem }

    # A binding that answers "kind: type" and "category: variable" at the same
    # time is one fact told two ways. Semantic tokens and hover read the
    # category, so the interface must not present itself as a variable.
    with TemporaryDirectory() as td {
        proj = make_kind_project(Path(cast(str, td)));
        f = proj / "lib" / "kinds.jac";
        f.write_text(
            'import type from "kindpkg" { Iface, Alias }\n'
            'import from "kindpkg" { C, x, helper }\n'
        );
        (prog, mod) = compile_module(f);
        cats: dict[str, any] = {};
        for it in mod.get_all_sub_nodes(ModuleItem) {
            binding = it.binding_name;
            if binding is not None {
                cats[it.name.value] = binding.sym_category;
            }
        }
        assert cats.get("Iface") == SymbolType.TYPE , f"a d.ts interface must be a type, got {cats.get(
            'Iface'
        )}";
        assert cats.get("Alias") == SymbolType.TYPE , f"a d.ts type alias must be a type, got {cats.get(
            'Alias'
        )}";
        # A class and an enum are values too, so they stay variables.
        assert cats.get("C") == SymbolType.VAR , f"a d.ts class must stay a variable, got {cats.get(
            'C'
        )}";
        assert cats.get("x") == SymbolType.VAR , f"a d.ts const must stay a variable, got {cats.get(
            'x'
        )}";
        assert cats.get("helper") == SymbolType.VAR , f"a d.ts function must stay a variable, got {cats.get(
            'helper'
        )}";
    }
}


# ---------------------------------------------------------------------------
# 7. The import chain is walked once, and every hop still counts
# ---------------------------------------------------------------------------

test "a typed import anywhere in the chain keeps the binding type-only" {
    # `Symbol.binding_kind` and `resolved_decl_of` share one chain walk. The
    # `import type` hop is in the middle here, so the answer can only be right
    # if every hop is inspected rather than just the end of the chain.
    with TemporaryDirectory() as td {
        proj_root = write_pinned_project(Path(cast(str, td)));
        (proj_root / "rows.jac").write_text("type Row = dict[str, int];\n");
        (proj_root / "hub.jac").write_text('import type from .rows { Row }\n');
        f = proj_root / "app.jac";
        f.write_text(
            'import from .hub { Row }\n\n'
            'def:pub first(r: Row) -> int {\n'
            '    return len(r);\n'
            '}\n'
        );
        (prog, _mod) = compile_module(f);
        assert "E1131" in codes_of(prog.errors_had) , f"A plain import through an `import type` hop must still be refused, got {codes_of(
            prog.errors_had
        )}";
    }
}
