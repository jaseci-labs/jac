import os;
import tempfile;
import from jaclang.jac0core.program { JacProgram }

def write_mods(mods: dict[str, str]) -> str {
    tmp = tempfile.mkdtemp(prefix="jac_endpoint_effect_res_");
    for (fname, src) in mods.items() {
        with open(os.path.join(tmp, fname), "w") as f {
            f.write(src);
        }
    }
    return tmp;
}

def compile_effects(mods: dict[str, str]) -> dict {
    tmp = write_mods(mods);
    prog = JacProgram();
    mod = prog.compile(os.path.join(tmp, "main.jac"));
    msgs = [e.pretty_print() for e in prog.errors_had];
    assert not msgs , f"fixture must compile cleanly, got: {msgs}";
    return mod.gen.interop_manifest.endpoint_effects;
}

test "endpoint calling a top-level writer helper gets the exact writer verdict" {
    effects = compile_effects(
        {
            "main.jac": (
                "node Note {\n"
                "    has text: str = \"\";\n"
                "}\n"
                "def add_note(text: str) -> None {\n"
                "    root ++> Note(text=text);\n"
                "}\n"
                "def:pub save_note(text: str) -> dict {\n"
                "    add_note(text);\n"
                "    return {};\n"
                "}\n"
            )
        }
    );
    assert effects.get("func:save_note") == {"is_writer": True, "touches": ["Note"]} , (
        f"top-level helper write must resolve through the deep lookup; got"
        f" {effects.get('func:save_note')}"
    );
}

test "endpoint reaching a writer through a nested function stays a writer" {
    effects = compile_effects(
        {
            "main.jac": (
                "node Note {\n"
                "    has text: str = \"\";\n"
                "}\n"
                "def outer_helper(text: str) -> None {\n"
                "    def nested_writer(msg: str) -> None {\n"
                "        root ++> Note(text=msg);\n"
                "    }\n"
                "    nested_writer(text);\n"
                "}\n"
                "def:pub save_nested(text: str) -> dict {\n"
                "    outer_helper(text);\n"
                "    return {};\n"
                "}\n"
            )
        }
    );
    assert effects.get("func:save_nested")
        == {"is_writer": True, "touches": ["Note"]} , (
        f"nested callees resolve only via a deep enclosing-scope lookup, so a"
        f" shallow resolver misses this write; got"
        f" {effects.get('func:save_nested')}"
    );
}

test "endpoint calling a writer method keeps the unresolved method verdict" {
    effects = compile_effects(
        {
            "main.jac": (
                "node Note {\n"
                "    has text: str = \"\";\n"
                "}\n"
                "obj Store {\n"
                "    def write_note(text: str) -> None {\n"
                "        root ++> Note(text=text);\n"
                "    }\n"
                "}\n"
                "def:pub save_via_method(text: str) -> dict {\n"
                "    st = Store();\n"
                "    st.write_note(text);\n"
                "    return {};\n"
                "}\n"
            )
        }
    );
    assert effects.get("func:save_via_method")
        == {"is_writer": False, "touches": ["*"]} , (
        f"the AtomTrailer branch does not currently see the method body, so"
        f" the verdict stays reader; got {effects.get('func:save_via_method')}"
    );
}

test "endpoint calling a cross-module writer helper keeps the import-binding verdict" {
    effects = compile_effects(
        {
            "helper_mod.jac": (
                "node Note {\n"
                "    has text: str = \"\";\n"
                "}\n"
                "def remote_add(text: str) -> None {\n"
                "    root ++> Note(text=text);\n"
                "}\n"
            ),
            "main.jac": (
                "import from helper_mod { remote_add }\n"
                "def:pub save_remote(text: str) -> dict {\n"
                "    remote_add(text);\n"
                "    return {};\n"
                "}\n"
            )
        }
    );
    assert effects.get("func:save_remote") == {"is_writer": False, "touches": ["*"]} , (
        f"cross-module callees resolve to the import binding and their body is"
        f" not followed today; got {effects.get('func:save_remote')}"
    );
}

test "endpoint constructing a node archetype touches exactly that archetype" {
    effects = compile_effects(
        {
            "main.jac": (
                "node Todo {\n"
                "    has title: str = \"\";\n"
                "}\n"
                "def:pub make_todo(title: str) -> dict {\n"
                "    root ++> Todo(title=title);\n"
                "    return {};\n"
                "}\n"
            )
        }
    );
    assert effects.get("func:make_todo") == {"is_writer": True, "touches": ["Todo"]} , (
        f"a NODE_ARCH constructor call must record the archetype by name; got"
        f" {effects.get('func:make_todo')}"
    );
}

test "pure endpoint gets the exact reader verdict with wildcard touches" {
    effects = compile_effects(
        {
            "main.jac": (
                "def:pub get_stats -> dict {\n" "    return {\"count\": 10};\n" "}\n"
            )
        }
    );
    assert effects.get("func:get_stats") == {"is_writer": False, "touches": ["*"]} , (
        f"a pure endpoint must classify as reader with the wildcard touches"
        f" list; got {effects.get('func:get_stats')}"
    );
}
