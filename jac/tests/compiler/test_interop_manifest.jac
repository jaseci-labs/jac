"""The interop manifest as single source of truth (jac#7760).

BoundaryAnalysisPass is the one producer of cross-codespace facts: bridged
plain client imports record typed cl -> sv bindings, every native binding
carries a real signature, unmappable ctypes wire types are compile
diagnostics (E5093), and endpoint effects come from the graph effect
analysis it runs over the typed tree.
"""

import os;
import tempfile;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

def write_mods(mods: dict[str, str]) -> str {
    tmp = tempfile.mkdtemp(prefix="jac_interop_manifest_");
    for (fname, src) in mods.items() {
        with open(os.path.join(tmp, fname), "w") as f {
            f.write(src);
        }
    }
    return tmp;
}

test "bridged plain client import records a typed cl->sv binding" {
    tmp = write_mods(
        {
            "jac.toml": ('[placement.pins]\nprovider = "server"\n'),
            "provider.jac": (
                "def:pub greet(who: str) -> str {\n" "    return \"hi \" + who;\n" "}\n"
            ),
            "app.jac": (
                "import from .provider { greet as hello }\n\n"
                "def:pub Panel -> JsxElement {\n"
                "    return <div>{hello(\"x\")}</div>;\n"
                "}\n"
            )
        }
    );
    prog = JacProgram();
    mod = prog.compile(os.path.join(tmp, "app.jac"));
    binding = mod.gen.interop_manifest.bindings.get("hello");
    assert binding is not None , (
        f"bridged import must record a binding; got keys: "
        f"{list(mod.gen.interop_manifest.bindings.keys())}"
    );
    assert binding.name == "greet" , "binding keeps the export name";
    assert binding.source_context.value == "server";
    assert "client" in {c.value for c in binding.callers};
    assert binding.param_names == ["who"];
    assert binding.param_types == ["str"];
    assert binding.ret_type == "str";
    assert binding.kind == "function";
}

test "unmappable ctypes wire type across na->sv is E5093" {
    tmp = write_mods(
        {
            "jac.toml": ('[placement.pins]\n"main.crunch" = "native"\n'),
            "main.jac": (
                "def py_helper(vals: list[int]) -> int {\n"
                "    return len(vals);\n"
                "}\n"
                "def crunch -> int {\n"
                "    return py_helper([1, 2]);\n"
                "}\n"
            )
        }
    );
    prog = JacProgram();
    prog.compile(
        os.path.join(tmp, "main.jac"),
        options=CompileOptions(default_codespace='server')
    );
    msgs = [e.pretty_print() for e in prog.errors_had];
    assert any(["E5093" in m for m in msgs]) , (
        f"a list param crossing the na->sv ctypes boundary must be E5093,"
        f" got: {msgs}"
    );
}

test "primitive na->sv signatures stay clean of E5093" {
    tmp = write_mods(
        {
            "main.jac": (
                "def py_helper(x: int, tag: str) -> float {\n"
                "    return x * 1.5;\n"
                "}\n"
                "na {\n"
                "    def crunch -> float {\n"
                "        return py_helper(2, \"k\");\n"
                "    }\n"
                "}\n"
            )
        }
    );
    prog = JacProgram();
    prog.compile(
        os.path.join(tmp, "main.jac"),
        options=CompileOptions(default_codespace='server')
    );
    msgs = [e.pretty_print() for e in prog.errors_had];
    assert not any(["E5093" in m for m in msgs]) , (
        f"int/str/float are ctypes-mappable and must not raise E5093: {msgs}"
    );
}

test "native module's pinned-server import records an na->sv binding" {
    # The na -> sv edge (interop matrix row 8): a native-pinned module
    # importing from a server-pinned provider. The binding is the one the
    # sealed-pair gate reads -- `native_imports` non-empty is what drops the
    # standalone exe at build time and keeps the run host-driven.
    tmp = write_mods(
        {
            "jac.toml": ('[placement.pins]\nmain = "native"\nhelper = "server"\n'),
            "helper.jac": (
                "def:pub py_double(x: int) -> int {\n" "    return x * 2;\n" "}\n"
            ),
            "main.jac": (
                "import from .helper { py_double }\n\n"
                "def crunch(x: int) -> int {\n"
                "    return py_double(x);\n"
                "}\n"
            )
        }
    );
    prog = JacProgram();
    mod = prog.compile(
        os.path.join(tmp, "main.jac"),
        options=CompileOptions(default_codespace='server')
    );
    imports = mod.gen.interop_manifest.native_imports;
    names = [b.name for b in imports];
    assert "py_double" in names , (
        f"native caller of a pinned-server fn must land in native_imports; "
        f"got: {names} (bindings: "
        f"{list(mod.gen.interop_manifest.bindings.keys())})"
    );
    binding = mod.gen.interop_manifest.bindings["py_double"];
    assert binding.source_context.value == "server";
    assert "native" in {c.value for c in binding.callers};
    assert binding.param_types == ["int"] , (
        f"expected int param on the ctypes wire, got {binding.param_types}"
    );
}

test "native import of a pinned-server type records a type binding" {
    # A native module importing a non-ability symbol (an obj) from a
    # server-pinned provider must register the data shape, not fabricate a
    # zero-arg int function binding for the type name. The module is forced
    # native: a native pin is a preference, and a module whose only element
    # is an import has nothing to place native.
    tmp = write_mods(
        {
            "jac.toml": ('[placement.pins]\nmain = "native"\nhelper = "server"\n'),
            "helper.jac": ("obj:pub Point {\n" "    has x: int;\n" "}\n"),
            "main.jac": ("import from .helper { Point }\n")
        }
    );
    prog = JacProgram();
    mod = prog.compile(
        os.path.join(tmp, "main.jac"),
        options=CompileOptions(default_codespace='server', force_codespace='native')
    );
    binding = mod.gen.interop_manifest.bindings.get("Point");
    assert binding is not None , (
        f"type import from a pinned-server provider must record a binding; "
        f"got keys: {list(mod.gen.interop_manifest.bindings.keys())}"
    );
    assert binding.kind == "type" , (
        f"expected a type binding for the imported obj, got kind={binding.kind}"
    );
    assert "Point" in [b.name for b in mod.gen.interop_manifest.native_imports] , (
        "type imports stay in native_imports: the native module still depends "
        "on the server module, so the standalone-exe refusal must keep firing"
    );
    msgs = [e.pretty_print() for e in prog.errors_had];
    assert not any(["E5093" in m for m in msgs]) , (
        f"type bindings carry no call signature and must not raise E5093: {msgs}"
    );
}

test "a native call that cannot cross into a pinned-server import stays in Python" {
    # The na -> sv import edge is judged by the boundary rule before anything
    # is lowered: a list does not cross into Python, so the caller is placed
    # in Python, nothing native is generated, and nothing has to be demoted.
    tmp = write_mods(
        {
            "jac.toml": ('[placement.pins]\nmain = "native"\nhelper = "server"\n'),
            "helper.jac": (
                "def:pub collect(vals: list[int]) -> int {\n"
                "    return len(vals);\n"
                "}\n"
            ),
            "main.jac": (
                "import from .helper { collect }\n\n"
                "def crunch -> int {\n"
                "    return collect([1, 2]);\n"
                "}\n"
            )
        }
    );
    main_path = os.path.join(tmp, "main.jac");
    prog = JacProgram();
    mod = prog.compile(main_path, options=CompileOptions(default_codespace='server'));
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    crunch = [
        stmt
        for stmt in mod.body
        if isinstance(stmt, uni.Ability)
    ][0];
    assert crunch.code_context.value == 'server' , (
        "a list cannot cross into the server module, so the caller stays in Python"
    );
    refused = prog.analysis.placement_refusals[os.path.realpath(main_path)]['native'];
    assert id(crunch) in refused , "the refusal is a recorded placement fact";
    assert not mod.gen.native_codespace , "nothing in the module is native";
}

test "native default codespace stamps the na->sv caller once" {
    # The aot + native-default-codespace path stamps the module-level verdict
    # once (gen.native_codespace): the binding records a NATIVE caller, never
    # a meaningless SERVER caller from the stamp pass disagreeing with the
    # analysis pass.
    tmp = write_mods(
        {
            "jac.toml": ('[placement.pins]\nhelper = "server"\n'),
            "helper.jac": (
                "def:pub py_double(x: int) -> int {\n" "    return x * 2;\n" "}\n"
            ),
            "main.jac": (
                "import from .helper { py_double }\n\n"
                "def crunch(x: int) -> int {\n"
                "    return py_double(x);\n"
                "}\n"
            )
        }
    );
    prog = JacProgram();
    mod = prog.compile(
        os.path.join(tmp, "main.jac"),
        options=CompileOptions(default_codespace='native', aot_mode=True)
    );
    binding = mod.gen.interop_manifest.bindings.get("py_double");
    assert binding is not None , (
        f"native-default import must record a binding; got keys: "
        f"{list(mod.gen.interop_manifest.bindings.keys())}"
    );
    assert {c.value for c in binding.callers} == {"native"} , (
        f"the single stamped verdict must yield exactly the NATIVE caller, "
        f"got callers: {{c.value for c in binding.callers}}"
    );
    assert binding.source_context.value == "server";
}

test "endpoint effects come from the types of what each endpoint changes" {
    tmp = write_mods(
        {
            "main.jac": (
                "node Note {\n"
                "    has text: str = \"\",\n"
                "        tags: list[str] = [],\n"
                "        meta: dict[str, str] = {},\n"
                "        data: bytearray = bytearray(4);\n"
                "    def rename(text: str) -> None {\n"
                "        self.text = text;\n"
                "    }\n"
                "    can touched with toucher entry {\n"
                "        self.text = \"t\";\n"
                "    }\n"
                "    can based with Base entry {\n"
                "        self.text = \"b\";\n"
                "    }\n"
                "}\n"
                "walker Base {}\n"
                "obj Branch {\n"
                "    has children: list[Branch] = [Branch() for i in range(0)];\n"
                "}\n"
                "obj Maker {\n"
                "    def postinit -> None {\n"
                "        root ++> Note();\n"
                "    }\n"
                "}\n"
                "def put(m: dict[str, str]) -> None {\n"
                "    m[\"k\"] = \"v\";\n"
                "}\n"
                "obj Row {\n"
                "    has text: str = \"\";\n"
                "}\n"
                "def count_of(items: list[str]) -> int {\n"
                "    return len(sorted(items));\n"
                "}\n"
                "def:pub add_note(text: str) -> None {\n"
                "    root ++> Note(text=text);\n"
                "}\n"
                "def:pub read_only -> int {\n"
                "    return 1;\n"
                "}\n"
                "walker:pub read_local_values {\n"
                "    has seen: int = 0;\n"
                "    can start with Root entry {\n"
                "        rows: list[str] = [];\n"
                "        for n in [-->[?:Note]] {\n"
                "            rows.append(n.text.lower());\n"
                "            row = Row(text=n.meta.get(\"k\", \"\"));\n"
                "            row.text = str(len(n.tags));\n"
                "        }\n"
                "        self.seen = count_of(rows);\n"
                "        report rows;\n"
                "    }\n"
                "}\n"
                "walker:pub set_field_item {\n"
                "    can start with Root entry {\n"
                "        for n in [-->[?:Note]] {\n"
                "            n.meta[\"k\"] = \"v\";\n"
                "        }\n"
                "    }\n"
                "}\n"
                "walker:pub append_field {\n"
                "    can start with Root entry {\n"
                "        for n in [-->[?:Note]] {\n"
                "            n.tags.append(\"x\");\n"
                "        }\n"
                "    }\n"
                "}\n"
                "walker:pub alias_field {\n"
                "    can start with Root entry {\n"
                "        for n in [-->[?:Note]] {\n"
                "            meta = n.meta;\n"
                "            meta[\"k\"] = \"v\";\n"
                "        }\n"
                "    }\n"
                "}\n"
                "walker:pub call_node_method {\n"
                "    can start with Root entry {\n"
                "        for n in [-->[?:Note]] {\n"
                "            n.rename(\"x\");\n"
                "        }\n"
                "    }\n"
                "}\n"
                "walker:pub helper_gets_field {\n"
                "    can start with Root entry {\n"
                "        for n in [-->[?:Note]] {\n"
                "            put(n.meta);\n"
                "        }\n"
                "    }\n"
                "}\n"
                "walker:pub double_alias {\n"
                "    can start with Root entry {\n"
                "        for n in [-->[?:Note]] {\n"
                "            first = n.meta;\n"
                "            second = first;\n"
                "            second[\"k\"] = \"v\";\n"
                "        }\n"
                "    }\n"
                "}\n"
                "walker:pub buffer_view {\n"
                "    can start with Root entry {\n"
                "        for n in [-->[?:Note]] {\n"
                "            view = memoryview(n.data);\n"
                "            view[0] = 1;\n"
                "        }\n"
                "    }\n"
                "}\n"
                "walker:pub uses_setattr {\n"
                "    can start with Root entry {\n"
                "        for n in [-->[?:Note]] {\n"
                "            setattr(n, \"text\", \"x\");\n"
                "        }\n"
                "    }\n"
                "}\n"
                "walker:pub toucher {\n"
                "    can start with Root entry {\n"
                "        visit [-->];\n"
                "    }\n"
                "}\n"
                "walker:pub child_walker(Base) {\n"
                "    can start with Root entry {\n"
                "        visit [-->];\n"
                "    }\n"
                "}\n"
                "def:pub make_branch -> int {\n"
                "    tree = Branch();\n"
                "    return len(tree.children);\n"
                "}\n"
                "def:pub make_obj -> int {\n"
                "    made = Maker();\n"
                "    return 1;\n"
                "}\n"
                "walker:pub spawn_writer {\n"
                "    can start with Root entry {\n"
                "        root spawn set_field_item();\n"
                "    }\n"
                "}\n"
            )
        }
    );
    prog = JacProgram();
    mod = prog.compile(os.path.join(tmp, "main.jac"));
    effects = mod.gen.interop_manifest.endpoint_effects;
    import from jaclang.compiler.frontend.codeinfo { endpoint_key }
    expected = {
        ("func", "add_note"): True,
        ("func", "read_only"): False,
        ("walker", "read_local_values"): False,
        ("walker", "set_field_item"): True,
        ("walker", "append_field"): True,
        ("walker", "alias_field"): True,
        ("walker", "call_node_method"): True,
        ("walker", "spawn_writer"): True,
        ("walker", "helper_gets_field"): True,
        ("walker", "double_alias"): True,
        ("walker", "buffer_view"): True,
        ("walker", "uses_setattr"): True,
        ("walker", "toucher"): True,
        ("func", "make_obj"): True,
        ("walker", "child_walker"): True,
        ("func", "make_branch"): False
    };
    for ((kind, name), writes) in expected.items() {
        effect = effects.get(endpoint_key(mod, kind, name));
        assert effect is not None , f"{name} must be classified; got {effects}";
        assert bool(effect["writes"]) == writes , (
            f"{name} must classify as {'writer' if writes else 'reader'}; got {effect}"
        );
    }
}
