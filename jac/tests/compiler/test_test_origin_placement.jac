"""Test code must not constrain its module's placement.

A `*.test.jac` annex is woven into the module it tests, and inline `test`
blocks sit in the module body, so every placement scan used to see test code:
a test that touched `root` pushed the module under test off native, and a
module with a `node` archetype was anchored to the server as a persistent
graph. Placement now reads the module through
`ModuleFacts.iter_placement_stmts`, which leaves tests out, and assigns each
test its own codespace: a test that carries a blocker runs on the server while
the module it tests stays native. Non-test code in a test annex (helpers,
imports) is still the module's own code and is still weighed.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from tests.support { jac_command }
import from jaclang.compiler.placement.placement {
    _element_reqs,
    module_anchor_reasons,
    module_has_root_access,
    native_blocker_scan,
    scan_native_blockers
}

glob CALC: str = "def add(a: int, b: int) -> int { return a + b; }\n"
         + "with entry { print(add(1, 2)); }\n",
     GRAPH_CALC: str = "node Item { has v: int = 0; }\n"
         + "def add(a: int, b: int) -> int { return a + b; }\n",
     ROOT_TEST: str = "test \"reaches the graph\" {\n"
         + "    assert root is not None;\n"
         + "    assert add(1, 2) == 3;\n"
         + "}\n",
     GRAPH_TEST: str = "test \"builds a graph\" {\n"
         + "    root ++> Item(v=add(1, 2));\n"
         + "    assert len([root -->]) >= 1;\n"
         + "}\n",
     ASYNC_HELPER: str = "async def probe() -> int { return 1; }\n"
         + "test \"async helper\" {\n"
         + "    assert True;\n"
         + "}\n";

def _proj(base: str, annex: str) -> str {
    d = tempfile.mkdtemp(prefix="jactestorigin_");
    with open(os.path.join(d, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"t\"\nentry-point = \"main\"\n");
    }
    with open(os.path.join(d, "main.jac"), "w") as f {
        f.write("with entry {}\n");
    }
    with open(os.path.join(d, "calc.jac"), "w") as f {
        f.write(base);
    }
    if annex {
        with open(os.path.join(d, "calc.test.jac"), "w") as f {
            f.write(annex);
        }
    }
    return d;
}

def _compile(
    base: str, annex: str, native_required: bool = False
) -> tuple[JacProgram, uni.Module, str] {
    d = _proj(base, annex);
    prog = JacProgram();
    mod = prog.compile(
        os.path.join(d, "calc.jac"),
        options=CompileOptions(no_ir_cache=True, native_required=native_required)
    );
    return (prog, mod, d);
}

def _tests_of(mod: uni.Module) -> list[uni.Test] {
    return [
        stmt
        for stmt in mod.body
        if isinstance(stmt, uni.Test)
    ];
}

def _named(mod: uni.Module, name: str) -> uni.ContextAwareNode {
    for stmt in mod.body {
        if isinstance(stmt, uni.Ability)
            and stmt.name_ref is not None
            and stmt.name_ref.sym_name == name {
            return stmt;
        }
        if isinstance(stmt, uni.Archetype) and stmt.name.value == name {
            return stmt;
        }
    }
    raise LookupError(name);
}


test "a module with no test annex keeps its native preference" {
    (prog, mod, d) = _compile(CALC, "");
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        assert mod.decided_codespace == "native" , mod.decided_codespace;
        (blocker, _deps) = scan_native_blockers(mod, d);
        assert not blocker , blocker;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a test annex touching root stays on the server, its module stays native" {
    (prog, mod, d) = _compile(CALC, ROOT_TEST);
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        scan = native_blocker_scan(mod, d);
        assert not scan.first() , f"test code entered the module scan: {scan.first()}";
        assert [why for (_t, why) in scan.tests]
            == ["root access (persistent graph)"] , scan.tests;
        assert mod.decided_codespace == "native" , (
            f"a test annex demoted the module under test: {mod.decided_codespace}"
        );
        assert _named(mod, "add").code_context == uni.CodeContext.NATIVE;
        tests = _tests_of(mod);
        assert len(tests) == 1 , tests;
        assert tests[0].code_context == uni.CodeContext.SERVER , tests[0].code_context;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a node archetype is not anchored by a test that touches root" {
    (prog, mod, d) = _compile(GRAPH_CALC, GRAPH_TEST);
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        assert not module_has_root_access(mod) , "test code counted as root access";
        anchors = module_anchor_reasons(mod);
        assert not anchors , f"test code anchored the module: {anchors}";
        item = _named(mod, "Item");
        assert ["PERSIST", "node archetype"] not in _element_reqs(item) , _element_reqs(
            item
        );
        (blocker, _deps) = scan_native_blockers(mod, d);
        assert not blocker , blocker;
        assert mod.decided_codespace == "native" , (
            "a root-touching test forced the module to the server: "
            + mod.decided_codespace
        );
        assert item.code_context == uni.CodeContext.NATIVE , item.code_context;
        assert _tests_of(mod)[0].code_context == uni.CodeContext.SERVER;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "root access outside a test still anchors a node archetype" {
    (prog, mod, d) = _compile(
        GRAPH_CALC + "def seed { root ++> Item(); }\n", GRAPH_TEST
    );
    try {
        assert module_has_root_access(mod);
        anchors = module_anchor_reasons(mod);
        assert "graph archetype 'Item'" in anchors , anchors;
        assert mod.decided_codespace != "native" , mod.decided_codespace;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a non-test helper in a test annex is still weighed" {
    (prog, mod, d) = _compile(CALC, ASYNC_HELPER);
    try {
        weighed = ModuleFacts.iter_placement_stmts(mod);
        assert any(
            isinstance(stmt, uni.Ability) and stmt.is_async for stmt in weighed
        ) , "the annex helper was left out of the placement view";
        assert not any(isinstance(stmt, uni.Test) for stmt in weighed);
        (blocker, _deps) = scan_native_blockers(mod, d);
        assert blocker == "async ability" , blocker;
        assert mod.decided_codespace != "native" , mod.decided_codespace;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "an inline test block touching root does not push its module off native" {
    (prog, mod, d) = _compile(CALC + ROOT_TEST, "");
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        (blocker, _deps) = scan_native_blockers(mod, d);
        assert not blocker , f"inline test code entered the blocker scan: {blocker}";
        assert mod.decided_codespace == "native" , mod.decided_codespace;
        assert _tests_of(mod)[0].code_context == uni.CodeContext.SERVER;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a test whose import cannot be native is placed on the server" {
    d = _proj(CALC, "");
    try {
        with open(os.path.join(d, "server_helper.jac"), "w") as f {
            f.write(
                "async def ping() -> int { return 1; }\n"
                    + "def two() -> int { return 2; }\n"
            );
        }
        with open(os.path.join(d, "only_tests.jac"), "w") as f {
            f.write(
                "test \"uses a server helper\" {\n"
                    + "    import from server_helper { two }\n"
                    + "    assert two() == 2;\n"
                    + "}\n"
            );
        }
        prog = JacProgram();
        mod = prog.compile(
            os.path.join(d, "only_tests.jac"), options=CompileOptions(no_ir_cache=True)
        );
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        tests = _tests_of(mod);
        assert len(tests) == 1 , tests;
        assert tests[0].code_context == uni.CodeContext.SERVER , (
            f"a test importing a server-only module was placed {tests[0].code_context}"
        );
        assert not ModuleFacts.has_native_context_stmts(mod) , (
            "a test-only module whose tests run on the server still has native code"
        );
        assert mod.decided_codespace != "native" , mod.decided_codespace;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a native-required module still reports a test that cannot be native" {
    (prog, mod, d) = _compile(CALC, ROOT_TEST, native_required=True);
    try {
        msgs = [str(e) for e in prog.errors_had];
        assert any("calc.test.jac" in m and "root" in m for m in msgs) , (
            f"a native-required test was moved off native silently: {msgs}"
        );
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a server-placed test reads the module's globals and calls its functions" {
    d = _proj(
        "import math;\n"
            + "glob LIMITS: dict[str, int] = {\"a\": 1};\n"
            + "def add(a: int, b: int) -> int { return a + b; }\n",
        "test \"server test reaches native code\" {\n"
            + "    import jaclang;\n"
            + "    assert jaclang is not None;\n"
            + "    assert LIMITS[\"a\"] == 1;\n"
            + "    assert add(2, 3) == 5;\n"
            + "    assert math.floor(2.5) == 2;\n"
            + "}\n"
    );
    try {
        prog = JacProgram();
        mod = prog.compile(
            os.path.join(d, "calc.jac"), options=CompileOptions(no_ir_cache=True)
        );
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        assert _tests_of(mod)[0].code_context == uni.CodeContext.SERVER;
        assert _named(mod, "add").code_context == uni.CodeContext.NATIVE , (
            "a native function a server test calls stays native and is bridged"
        );
        proc = subprocess.run(
            jac_command("test", "calc.jac"),
            cwd=d,
            capture_output=True,
            text=True,
            timeout=900
        );
        assert proc.returncode == 0 , f"exit {proc.returncode}\n{proc.stdout}\n{proc.stderr}";
        assert "1 passed" in proc.stdout , proc.stdout;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}
