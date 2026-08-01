"""The interop manifest as single source of truth (jac#7760).

BoundaryAnalysisPass is the one producer of cross-codespace facts: bridged
plain client imports record typed cl -> sv bindings, every native binding
carries a real signature, unmappable ctypes wire types are compile
diagnostics (E5093), and endpoint effects come from the dedicated
EndpointEffectPass in the same schedule.
"""

import os;
import tempfile;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.program { JacProgram }

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
                "def py_helper(vals: list) -> int {\n"
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

test "endpoint effects are recorded by the dedicated effect pass" {
    tmp = write_mods(
        {
            "main.jac": (
                "node Note {\n"
                "    has text: str = \"\";\n"
                "}\n"
                "def:pub add_note(text: str) -> None {\n"
                "    root ++> Note(text=text);\n"
                "}\n"
                "def:pub read_only -> int {\n"
                "    return 1;\n"
                "}\n"
            )
        }
    );
    prog = JacProgram();
    mod = prog.compile(os.path.join(tmp, "main.jac"));
    effects = mod.gen.interop_manifest.endpoint_effects;
    writer = effects.get("func:add_note");
    reader = effects.get("func:read_only");
    assert writer is not None and writer["is_writer"] , (
        f"add_note connects a node and must classify as writer; got {effects}"
    );
    assert reader is not None and not reader["is_writer"] , (
        f"read_only must classify as non-writer; got {effects}"
    );
}
