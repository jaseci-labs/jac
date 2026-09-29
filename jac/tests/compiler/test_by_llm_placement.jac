"""A `by llm` ability needs the Python byLLM runtime, so it is a server
anchor. Before this rule an anchor-free module holding only a `by llm`
def was inferred native under the shipped default; the native lowering
kept the signature but had no model call, so every invocation returned
None with no request sent and no diagnostic. Any jaclang import in the
same module masked the defect by anchoring it server."""

import os;
import shutil;
import tempfile;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.boundary_classify {
    ability_delegates_to_model,
    is_server_anchored_module
}
import from jaclang.compiler.placement.placement {
    module_anchor_reasons,
    scan_native_blockers
}

glob LLM_ONLY: str = "def greet(name: str) -> str by llm();\n"
         + "sem greet = \"Greet the person by name.\";\n"
         + "sem greet.name = \"The person's name.\";\n"
         + "with entry { print(greet(\"Mars\")); }\n",
     LLM_IN_RETURN: str = "obj Bot {\n"
         + "    has mood: str = \"calm\";\n"
         + "    def answer(question: str) -> str by llm();\n"
         + "}\n"
         + "def chat(q: str) -> str {\n"
         + "    return Bot().answer(q);\n"
         + "}\n",
     PURE: str = "def add(a: int, b: int) -> int { return a + b; }\n"
         + "with entry { print(add(1, 2)); }\n";

def _proj(files: dict[str, str]) -> str {
    d = tempfile.mkdtemp(prefix="jacbyllm_");
    with open(os.path.join(d, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"t\"\nentry-point = \"main\"\n");
    }
    for (name, content) in files.items() {
        with open(os.path.join(d, name), "w") as f {
            f.write(content);
        }
    }
    return d;
}

def _compile(src: str) -> tuple[JacProgram, uni.Module, str] {
    d = _proj({"main.jac": "with entry {}\n", "bot.jac": src});
    prog = JacProgram();
    mod = prog.compile(
        os.path.join(d, "bot.jac"), options=CompileOptions(no_ir_cache=True)
    );
    return (prog, mod, d);
}

test "a by llm def is recognised as model delegation" {
    (prog, mod, d) = _compile(LLM_ONLY);
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        abilities = mod.get_all_sub_nodes(uni.Ability);
        delegated = [
            a
            for a in abilities
            if ability_delegates_to_model(a)
        ];
        assert len(delegated) == 1;
        assert delegated[0].py_resolve_name() == "greet";
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "a module whose only anchor is a by llm def stays off the native lane" {
    (prog, mod, d) = _compile(LLM_ONLY);
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        assert mod.decided_codespace != "native" , (
            "the module lowered native, which drops the model call"
        );
        assert is_server_anchored_module(mod);
        reasons = module_anchor_reasons(mod);
        assert any("by llm" in r for r in reasons) , reasons;
        (blocker, _deps) = scan_native_blockers(mod, d);
        assert "by llm" in blocker , blocker;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "a by llm method inside an obj anchors the module the same way" {
    (prog, mod, d) = _compile(LLM_IN_RETURN);
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        assert mod.decided_codespace != "native";
        assert is_server_anchored_module(mod);
        assert any("by llm" in r for r in module_anchor_reasons(mod));
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "a pure module without model delegation keeps its native preference" {
    (prog, mod, d) = _compile(PURE);
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        assert mod.decided_codespace == "native" , mod.decided_codespace;
        assert not is_server_anchored_module(mod);
        assert not any("by llm" in r for r in module_anchor_reasons(mod));
        (blocker, _deps) = scan_native_blockers(mod, d);
        assert "by llm" not in blocker , blocker;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}
