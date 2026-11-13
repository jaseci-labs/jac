"""Placement is one judgment, made after a module has been typed, and the
module is analyzed once.

A module with no declared codespace is typed with none assumed. What only one
codespace has is recorded on the typed module as a requirement or a refusal,
and the placement pass reads those to place each top-level element. The tree
it placed is the tree every backend reads: nothing types the module again. A
refusal only the backend can see places the module on the server in place,
before the Python backend runs. A backend crash is none of these: it is a
compiler error."""

import os;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.codeinfo { InteropBinding, InteropContext }
import from jaclang.compiler.capability_notes { capability_notes_of }
import from jaclang.compiler.driver.session_compile { drop_native_bindings }
import from jaclang.compiler.placement.placement_solver {
    invalidate_importers_es,
    native_placement_candidate
}
import from tests.support { JAC_ROOT }

glob PIN_FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace", "native_demoted_pin"
     ),
     SEAM_SRC = (
         "def helper(x: int) -> str {\n"
         "    s = \"abc\";\n"
         "    return f\"{s!a}{x}\";\n"
         "}\n\n"
         "def other(x: int) -> int {\n"
         "    return x * 2;\n"
         "}\n\n"
         "def mid(x: int) -> str {\n"
         "    return helper(other(x));\n"
         "}\n\n"
     ),
     REACHING_ENTRY = "with entry {\n    print(other(2));\n    print(mid(3));\n}\n",
     DRAG_SRC = (
         "def helper(xs: list[int]) -> str {\n"
         "    s = \"abc\";\n"
         "    return f\"{s!a}{len(xs)}\";\n"
         "}\n\n"
         "def other(x: int) -> int {\n"
         "    return x * 2;\n"
         "}\n\n"
         "def mid(x: int) -> str {\n"
         "    return helper([other(x)]);\n"
         "}\n\n"
         "with entry {\n"
         "    print(other(2));\n"
         "    print(mid(3));\n"
         "}\n"
     ),
     LATE_SRC = (
         "def other(x: int) -> int {\n"
         "    return x * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    s = {1, \"a\"};\n"
         "    print(other(2), len(s));\n"
         "}\n"
     ),
     CLEAN_SRC = (
         "def other(x: int) -> int {\n"
         "    return x * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    print(other(2));\n"
         "}\n"
     ),
     GAP_SRC = (
         "import json;\n\n"
         "def pretty(x: dict[str, int]) -> str {\n"
         "    return json.dumps(x, indent=2);\n"
         "}\n\n"
         "def double(n: int) -> int {\n"
         "    return n * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    print(double(2));\n"
         "}\n"
     ),
     SHARED_GAP_SRC = (
         "import json;\n\n"
         "def pretty(x: dict[str, int]) -> str {\n"
         "    return json.dumps(x, indent=2);\n"
         "}\n\n"
         "def plain(n: int) -> int {\n"
         "    return len(json.dumps([n, n + 1]));\n"
         "}\n\n"
         "with entry {\n"
         "    print(plain(1));\n"
         "}\n"
     ),
     ERASED_SRC = (
         "import json;\n\n"
         "with entry {\n"
         "    data = json.loads(\"[1, 2]\");\n"
         "    print(1 in data);\n"
         "}\n"
     ),
     STRICT_SRC = (
         "def run(t: any, x: int) -> int {\n"
         "    if x in t {\n"
         "        return 1;\n"
         "    }\n"
         "    return 0;\n"
         "}\n\n"
         "def narrow(x: int | None) -> int {\n"
         "    if x < 5 {\n"
         "        return 1;\n"
         "    }\n"
         "    return 0;\n"
         "}\n\n"
         "def other(x: int) -> int {\n"
         "    return x * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    print(other(2));\n"
         "}\n"
     ),
     ASYNC_SRC = (
         "async def fetch(x: int) -> int {\n"
         "    return x;\n"
         "}\n\n"
         "def double(n: int) -> int {\n"
         "    return n * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    print(double(2));\n"
         "}\n"
     ),
     PY_IMPORT_SRC = (
         "import pickle;\n\n"
         "def dump(n: int) -> int {\n"
         "    return len(pickle.dumps(n));\n"
         "}\n\n"
         "def double(n: int) -> int {\n"
         "    return n * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    print(double(2), dump(3));\n"
         "}\n"
     ),
     ROOT_SRC = (
         "def double(n: int) -> int {\n"
         "    return n * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    print(double(2), len([root-->]));\n"
         "}\n"
     ),
     TOKEN_SRC = (
         "import from contextvars { ContextVar, Token }\n\n"
         "def double(n: int) -> int {\n"
         "    return n * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    print(double(2));\n"
         "}\n"
     ),
     MIXED_LATE_SRC = (
         "import json;\n\n"
         "def pretty(x: dict[str, int]) -> str {\n"
         "    return json.dumps(x, indent=2);\n"
         "}\n\n"
         "def bad(n: int) -> int {\n"
         "    s = {1, \"a\"};\n"
         "    return len(s) + n;\n"
         "}\n\n"
         "def double(n: int) -> int {\n"
         "    return n * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    print(double(2), bad(1));\n"
         "}\n"
     ),
     PINNED_METHOD_SRC = (
         "obj Foo {\n"
         "    has n: int = 1;\n\n"
         "    def size -> int {\n"
         "        s = \"x\";\n"
         "        return len(f\"{s!a}\") + self.n;\n"
         "    }\n"
         "}\n\n"
         "with entry {\n"
         "    print(Foo().size());\n"
         "}\n"
     ),
     PINNED_LATE_METHOD_SRC = (
         "import json;\n\n"
         "def pretty(x: dict[str, int]) -> str {\n"
         "    return json.dumps(x, indent=2);\n"
         "}\n\n"
         "obj Foo {\n"
         "    has n: int = 1;\n\n"
         "    def size -> int {\n"
         "        s = {1, \"a\"};\n"
         "        return len(s) + self.n;\n"
         "    }\n"
         "}\n\n"
         "with entry {\n"
         "    print(Foo().size());\n"
         "}\n"
     ),
     OVERLOAD_STUB = (
         "from typing import Callable, overload\n"
         "@overload\n"
         "def run(a: int, b: str) -> int: ...\n"
         "@overload\n"
         "def run(a: Callable[[int], int], b: int) -> int: ...\n"
     ),
     OVERLOAD_SRC = (
         "import choices;\n\n"
         "def inc(x: int) -> int {\n"
         "    return x + 1;\n"
         "}\n\n"
         "def by_callable -> int {\n"
         "    return choices.run(inc, 3);\n"
         "}\n\n"
         "def by_address -> int {\n"
         "    return choices.run(inc, \"x\");\n"
         "}\n"
     ),
     NATIVE_ONLY_SRC = (
         "def size(f: File) -> int {\n"
         "    s = \"x\";\n"
         "    return len(f\"{s!a}\");\n"
         "}\n\n"
         "with entry {\n"
         "    print(1);\n"
         "}\n"
     );

"""Compile `text` under the native default, counting how often it is parsed."""
def compile_native_default(text: str) -> tuple[JacProgram, uni.Module, str, int] {
    import from unittest.mock { patch }
    import from jaclang.compiler.frontend.codeinfo {
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    path = os.path.realpath(os.path.join(tempfile.mkdtemp(), "m.jac"));
    with open(path, "w", encoding="utf-8") as fh {
        fh.write(text);
    }
    real_parse: any = getattr(JacProgram, "parse_source");
    parsed: list[str] = [];
    def count_parse(this: JacProgram, *args: any, **kwargs: any) -> uni.Module {
        parsed.append(os.path.realpath(str(args[1])));
        return real_parse(this, *args, **kwargs);
    }
    previous = get_effective_default_codespace_override();
    prog = JacProgram();
    try {
        with patch.object(JacProgram, "parse_source", count_parse) {
            mod = prog.compile(
                path, options=CompileOptions(default_codespace="native")
            );
        }
    } finally {
        set_effective_default_codespace(previous);
    }
    return (prog, mod, path, parsed.count(path));
}

"""Where each top-level function and the entry block were placed."""
def placed_by_name(mod: uni.Module) -> dict[str, str] {
    out: dict[str, str] = {};
    for stmt in mod.body {
        if isinstance(stmt, uni.Ability) and stmt.name_ref is not None {
            out[stmt.name_ref.sym_name] = stmt.code_context.value;
        } elif isinstance(stmt, uni.ModuleCode) {
            out["entry"] = stmt.code_context.value;
        }
    }
    return out;
}

test "an inferred native module is judged and analyzed once" {
    (prog, mod, path, parses) = compile_native_default(CLEAN_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert parses == 1 , f"placement needs no second analysis, got {parses}";
    assert mod.gen.placement_mode == 'inferred';
    assert mod.decided_codespace == 'native' and mod.codespace_inferred;
    assert mod.gen.llvm_ir is not None;
}

test "placement is per element: what cannot be native stays in Python, the rest is native" {
    (prog, mod, path, parses) = compile_native_default(SEAM_SRC + REACHING_ENTRY);
    assert parses == 1 , f"the module is analyzed once, got {parses} analyses";
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    placed = placed_by_name(mod);
    assert placed["helper"] == 'server' , placed;
    assert placed["other"] == 'native' , placed;
    assert placed["mid"] == 'server' , (
        f"`mid` gets a str back from `helper`, and the call bridge does not "
        f"convert a str: {placed}"
    );
    assert placed["entry"] == 'server' , (
        f"a module with Python elements runs its entry block in Python: {placed}"
    );
    assert mod.decided_codespace != 'native' , "a mixed module is not whole-module native";
    assert mod.gen.llvm_ir is not None;
}

test "a caller stays native only when its call can cross the boundary" {
    (prog, mod, path, parses) = compile_native_default(DRAG_SRC);
    assert parses == 1 , f"the module is analyzed once, got {parses} analyses";
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    placed = placed_by_name(mod);
    assert placed["helper"] == 'server' , placed;
    assert placed["mid"] == 'server' , (
        f"`mid` passes `helper` a list, which cannot cross into Python: {placed}"
    );
    assert placed["other"] == 'native' , placed;
    assert placed["entry"] == 'server' , placed;
}

test "a refusal only the backend can see places the module on the server in place" {
    (prog, mod, path, parses) = compile_native_default(LATE_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert parses == 1 , (
        f"the backend's refusal is a restamp of the typed tree, not a second "
        f"analysis, got {parses}"
    );
    assert mod.decided_codespace != 'native';
    assert set(placed_by_name(mod).values()) == {'server'} , placed_by_name(mod);
    assert mod.gen.llvm_ir is None;
    assert mod.gen.py_ast , "the Python backend emits the module it was handed";
}

test "a native library gap refuses the function that uses it, not the module" {
    (prog, mod, path, parses) = compile_native_default(GAP_SRC);
    assert not prog.errors_had , (
        f"a parameter the native json lacks is a placement fact, not a type "
        f"error: {[str(e) for e in prog.errors_had]}"
    );
    assert parses == 1 , f"the module is analyzed once, got {parses} analyses";
    placed = placed_by_name(mod);
    assert placed["pretty"] == 'server' and placed["double"] == 'native' , placed;
    assert placed["entry"] == 'server' , placed;
    imports = [
        s
        for s in mod.body
        if isinstance(s, uni.Import)
    ];
    assert imports[0].code_context.value == 'server' , (
        "an import no native element uses stays with the Python code that uses it"
    );
}

test "a gap behind an import that native code shares refuses only the code that uses it" {
    (prog, mod, path, parses) = compile_native_default(SHARED_GAP_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert parses == 1 , f"the module is analyzed once, got {parses} analyses";
    placed = placed_by_name(mod);
    assert placed["pretty"] == 'server' and placed["plain"] == 'native' , (
        f"the gap is on `pretty`'s call, so only `pretty` is refused: {placed}"
    );
    assert mod.gen.llvm_ir is not None;
}

test "what syntax alone closes the native preference is decided before typing" {
    (prog, mod, path, parses) = compile_native_default(ASYNC_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert parses == 1 , f"the module is analyzed once, got {parses} analyses";
    assert not mod.gen.native_undecided , (
        "the placement pass that runs before typing closes the preference"
    );
    assert "async" in mod.gen.native_closed_why , mod.gen.native_closed_why;
    assert set(placed_by_name(mod).values()) == {'server'} , (
        f"an async ability still keeps the module in Python: {placed_by_name(mod)}"
    );
    assert mod.gen.llvm_ir is None;
}

test "an import with no native form keeps the module in Python" {
    (prog, mod, path, parses) = compile_native_default(PY_IMPORT_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert parses == 1 , f"the module is analyzed once, got {parses} analyses";
    assert set(placed_by_name(mod).values()) == {'server'} , placed_by_name(mod);
}

test "only a module whose native preference is open asks for the trees native code reads" {
    import from unittest.mock { patch }
    import jaclang.compiler.driver.module_compile as module_compile;
    import from jaclang.compiler.frontend.codeinfo {
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    real_analyze: any = module_compile.analyze_module;
    seen: dict[str, tuple[bool, bool]] = {};
    def recording(
        program: JacProgram, path: str, options: CompileOptions, source: any = None
    ) -> any {
        task = real_analyze(program, path, options, source);
        seen[os.path.realpath(str(path))] = (
            options.native_tree_demand,
            options.need_full_ast
        );
        return task;
    }
    previous = get_effective_default_codespace_override();
    asked: dict[str, tuple[bool, bool]] = {};
    try {
        with patch.object(module_compile, "analyze_module", recording) {
            for (name, text) in [("closed", PY_IMPORT_SRC), ("open", CLEAN_SRC)] {
                path = os.path.realpath(os.path.join(tempfile.mkdtemp(), "m.jac"));
                with open(path, "w", encoding="utf-8") as fh {
                    fh.write(text);
                }
                JacProgram().compile(
                    path, options=CompileOptions(default_codespace="native")
                );
                asked[name] = seen.get(path, (False, False));
            }
        }
    } finally {
        set_effective_default_codespace(previous);
    }
    assert asked["closed"] == (False, False) , (
        "a module the syntax scan closed is placed on the server before typing, "
        "so its dependencies are read from their interfaces"
    );
    assert asked["open"] == (True, False) , (
        f"a module that may be placed native asks for the trees native lowering "
        f"reads, not for every dependency's tree: {asked['open']}"
    );
}

test "native lowering reads user and native-library trees, not the compiler's own" {
    import jaclang;
    import from jaclang.compiler.driver.ifacecache { native_lowering_reads }
    pkg = os.path.dirname(os.path.realpath(jaclang.__file__));
    assert not native_lowering_reads(
        os.path.join(pkg, "compiler", "frontend", "unitree.jac")
    );
    assert native_lowering_reads(os.path.join(pkg, "runtime", "na_stdlib", "json.jac"));
    assert native_lowering_reads(os.path.join(tempfile.mkdtemp(), "app.jac"));
}

test "access to the persistent graph still keeps the whole module in Python" {
    (prog, mod, path, parses) = compile_native_default(ROOT_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert set(placed_by_name(mod).values()) == {'server'} , placed_by_name(mod);
    assert mod.gen.llvm_ir is None;
}

test "what only matters natively is a note on the typed module, never a type error" {
    (prog, mod, path, parses) = compile_native_default(ERASED_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert parses == 1 , f"the module is analyzed once, got {parses} analyses";
    assert mod.decided_codespace != 'native';
    assert "E1124" in [note.code for note in capability_notes_of(prog, path, "native")];
}

test "a finding that only matters natively keeps its own code where native is required" {
    path = os.path.realpath(os.path.join(tempfile.mkdtemp(), "strict.jac"));
    with open(path, "w", encoding="utf-8") as fh {
        fh.write(STRICT_SRC);
    }
    forced = JacProgram();
    forced.compile(
        path, options=CompileOptions(force_codespace="native", no_cgen=True)
    );
    codes = [
        e.code.code
        for e in forced.errors_had
        if e.code is not None
    ];
    assert "E1124" in codes and "E1121" in codes , (
        f"forced native must report the recorded findings under their own "
        f"codes: {[str(e) for e in forced.errors_had]}"
    );
    (prog, mod, soft_path, parses) = compile_native_default(STRICT_SRC);
    assert not prog.errors_had , (
        f"under the default the same findings are reasons, not errors: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    placed = placed_by_name(mod);
    assert placed["run"] == 'server' and placed["narrow"] == 'server' , placed;
    assert placed["other"] == 'native' , placed;
}

test "a native-only construct in code that cannot be placed native is an error" {
    (prog, mod, path, parses) = compile_native_default(NATIVE_ONLY_SRC);
    unmet = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5090" and "native-only" in str(e)
    ];
    assert unmet , f"expected the unmet native requirement: {[
        str(e) for e in prog.errors_had
    ]}";
    assert "cannot be placed native" in (unmet[0].help_text or "");
}

test "a backend crash is a compiler error, never a placement decision" {
    import from unittest.mock { patch }
    import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
    real_body: any = NaIRGenPass._codegen_body;
    calls: list[int] = [];
    def crash_once(this: NaIRGenPass, *args: any) {
        calls.append(1);
        if len(calls) == 1 {
            raise RuntimeError("boom");
        }
        real_body(this, *args);
    }
    with patch.object(NaIRGenPass, "_codegen_body", crash_once) {
        (prog, mod, path, parses) = compile_native_default(CLEAN_SRC);
    }
    crashes = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E9003"
    ];
    assert crashes , f"a backend crash must surface as E9003: {[
        str(e) for e in prog.errors_had
    ]}";
    assert "boom" in str(crashes[0]);
    assert not [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5092"
    ] , "a crash must not read as a refusal";
    assert mod.decided_codespace == 'native' , "a crash must not move the module";
    assert mod.gen.jcir is None , "a crashed module must keep nothing to run";
}

test "a native type alias is something the native library provides" {
    (prog, mod, path, parses) = compile_native_default(TOKEN_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    placed = placed_by_name(mod);
    assert placed["double"] == 'native' , (
        f"importing the native contextvars' Token alias keeps the preference "
        f"open: {placed}"
    );
}

test "a late refusal in a mixed module settles the module on the server" {
    (prog, mod, path, parses) = compile_native_default(MIXED_LATE_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert parses == 1 , f"the module is analyzed once, got {parses} analyses";
    placed = placed_by_name(mod);
    assert set(placed.values()) == {'server'} , (
        f"a native element of a mixed module has no Python body to fall back "
        f"on, so the module moves as a whole: {placed}"
    );
    assert mod.gen.llvm_ir is None;
    assert mod.gen.py_ast , "the Python backend emits the module it was handed";
}

"""Compile `text` as m.jac in a project that pins `m.Foo` native."""
def compile_pinned_foo(text: str) -> JacProgram {
    import from jaclang.compiler.frontend.codeinfo {
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    base = tempfile.mkdtemp();
    with open(os.path.join(base, "jac.toml"), "w", encoding="utf-8") as fh {
        fh.write(
            '[project]\nname = "pinned-method"\n\n[placement.pins]\n"m.Foo" = "native"\n'
        );
    }
    path = os.path.realpath(os.path.join(base, "m.jac"));
    with open(path, "w", encoding="utf-8") as fh {
        fh.write(text);
    }
    previous = get_effective_default_codespace_override();
    prog = JacProgram();
    try {
        prog.compile(path, options=CompileOptions(default_codespace="native"));
    } finally {
        set_effective_default_codespace(previous);
    }
    return prog;
}

test "a refusal inside an element pinned native is an error" {
    prog = compile_pinned_foo(PINNED_METHOD_SRC);
    assert any("must be native" in (e.help_text or "") for e in prog.errors_had) , f"a method of a pinned archetype that cannot lower is an error: {[
        str(e) for e in prog.errors_had
    ]}";
}

test "a late refusal inside an element pinned native is an error" {
    prog = compile_pinned_foo(PINNED_LATE_METHOD_SRC);
    assert any("mixed element types" in str(e) for e in prog.errors_had) , (
        f"a method of a pinned archetype that refuses during lowering keeps its "
        f"error rather than an abort() body: {[str(e) for e in prog.errors_had]}"
    );
}

test "an overload the call does not select records no native requirement" {
    import from unittest.mock { patch }
    import from jaclang.compiler.types.type_evaluator { TypeEvaluator }
    base = tempfile.mkdtemp();
    with open(os.path.join(base, "choices.pyi"), "w", encoding="utf-8") as fh {
        fh.write(OVERLOAD_STUB);
    }
    path = os.path.realpath(os.path.join(base, "main.jac"));
    with open(path, "w", encoding="utf-8") as fh {
        fh.write(OVERLOAD_SRC);
    }
    prog = JacProgram();
    with patch.object(
        TypeEvaluator, "neutral_site", lambda (this: any, nd: any) { True }
    ) {
        prog.compile(path, options=CompileOptions(no_cgen=True));
    }
    owners: set[str] = set();
    for note in capability_notes_of(prog, path, "native") {
        if not note.requires {
            continue;
        }
        cur: (uni.UniNode | None) = note.site;
        while cur is not None and not isinstance(cur, uni.Ability) {
            cur = cur.parent;
        }
        if isinstance(cur, uni.Ability) and cur.name_ref is not None {
            owners.add(cur.name_ref.sym_name);
        }
    }
    assert "by_address" in owners , (
        f"the selected (int, str) overload takes the function as an address: {owners}"
    );
    assert "by_callable" not in owners , (
        f"the (int, str) overload was only tried; (Callable, int) was selected: {owners}"
    );
}

test "a docstring-only module is not a candidate for native placement" {
    path = os.path.join(tempfile.mkdtemp(), "__init__.jac");
    with open(path, "w") as fh {
        fh.write('"""pkg."""\n');
    }
    prog = JacProgram();
    mod = prog.compile(path, options=CompileOptions(no_cgen=True));
    prog.options = CompileOptions(default_codespace="native");
    (ok, why) = native_placement_candidate(mod, prog);
    assert not ok , "an empty module was a native candidate";
    assert "empty module" in why , why;
}

test "importer invalidation clears ES output and NATIVE bindings" {
    prog = JacProgram();
    app = prog.compile(os.path.join(PIN_FIXTURE_DIR, "app.jac"));
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    models_path = os.path.realpath(os.path.join(PIN_FIXTURE_DIR, "models.jac"));
    app.gen.js = "stale na glue";
    manifest = app.gen.interop_manifest;
    manifest.bindings["double"] = InteropBinding(
        name="double",
        source_context=InteropContext.NATIVE,
        callers={InteropContext.CLIENT},
        source_module=models_path
    );
    manifest.bindings["unrelated"] = InteropBinding(
        name="unrelated",
        source_context=InteropContext.SERVER,
        callers={InteropContext.CLIENT},
        source_module=models_path
    );
    cleared = invalidate_importers_es(prog, models_path);
    assert app in cleared , "the importer must be found by the hub walk";
    assert app.gen.js == "" , "stale ES output must be cleared";
    for m in cleared {
        drop_native_bindings(m, models_path);
    }
    assert "double" not in manifest.bindings , "the NATIVE binding naming the module must be dropped";
    assert "unrelated" in manifest.bindings , "bindings in other contexts must survive";
}
