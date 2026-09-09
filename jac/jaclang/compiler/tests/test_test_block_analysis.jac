"""A standalone `.test.jac` module is analyzed like any other module.

`_compile_once` skipped the whole analysis schedule whenever the file it was
handed was annex-shaped (`.impl.jac` / `.test.jac`), on the assumption that an
annex is always woven into a base module that gets analyzed instead. A
`.test.jac` with no base module beside it -- the site's
`socialize/fullstack.test.jac` -- has no such base, so it is itself the
compilation unit, and it was compiled with no type inference at all: every
`Expr.type` stayed None and the checker never stamped `FuncCall.call_kind`.
The ECMAScript backend then emitted an archetype constructor as a plain call
(`TestClient()` instead of `new TestClient()`) and left the `jid()` builtin
un-lowered, so the test blew up at runtime with `TypeError: Cannot call a
class constructor TestClient without |new|` and `ReferenceError: jid is not
defined`.
"""

import os;
import shutil;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { FuncCall, Module, Name, Test }


glob _TEST_MOD_SRC: str = (
         "import from \"@jac/runtime\" { __setLocalStorage }\n"
         "\n"
         "obj TestClient {\n"
         "    has token: str = \"tok\";\n"
         "\n"
         "    def activate {\n"
         "        __setLocalStorage(\"jac_token\", self.token);\n"
         "    }\n"
         "}\n"
         "\n"
         "test \"constructor and builtin calls inside a test block\" {\n"
         "    client = TestClient();\n"
         "    client.activate();\n"
         "    assert jid(client) is not None;\n"
         "}\n"
     );


"""Write a base-less `.test.jac` module in a fresh project; return its path."""
def _standalone_test_module -> tuple[str, str] {
    base = tempfile.mkdtemp(prefix="jac_test_block_");
    with open(os.path.join(base, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"testblock\"\nkind = \"web-app\"\n");
    }
    mod_path = os.path.join(base, "fullstack.test.jac");
    with open(mod_path, "w") as f {
        f.write(_TEST_MOD_SRC);
    }
    return (base, mod_path);
}


"""Every call the test block makes, keyed by the callee's spelled name."""
def _calls_in_test_blocks(mod: Module) -> dict[str, FuncCall] {
    out: dict[str, FuncCall] = {};
    for call in mod.get_all_sub_nodes(FuncCall) {
        if call.find_parent_of_type(Test) is None {
            continue;
        }
        if isinstance(call.target, Name) {
            out[call.target.sym_name] = call;
        }
    }
    return out;
}


test "the checker classifies calls inside a standalone test module" {
    (base, mod_path) = _standalone_test_module();
    try {
        prog = JacProgram();
        mod = prog.compile(mod_path);
        calls = _calls_in_test_blocks(mod);
        assert "TestClient" in calls , sorted(calls.keys());
        assert "jid" in calls , sorted(calls.keys());

        ctor = calls["TestClient"];
        assert ctor.call_kind == "instantiation" , ctor.call_kind;
        assert ctor.target.type is not None , (
            "the checker left the constructor's callee untyped inside the" " test block"
        );

        builtin = calls["jid"];
        assert builtin.call_kind == "builtin" , builtin.call_kind;
        assert builtin.target.type is not None , (
            "the checker left the builtin's callee untyped inside the test" " block"
        );
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


# Not a reproducer: this shape passes on main too, because the deleted
# `BoundaryAnalysisPass.exit_func_call` stopgap stamped `call_kind` late
# enough to lower these two calls. It is kept as the end-to-end guard that
# the stopgap's removal did not cost anything the bundle depended on -- the
# reproducer for the analysis skip is the checker-facts test above, which
# reads `call_kind` and `target.type` off the tree.
test "a standalone test module still lowers its test-block calls (stopgap retired)" {
    (base, mod_path) = _standalone_test_module();
    try {
        prog = JacProgram();
        mod = prog.compile(mod_path);
        js = mod.gen.js;
        assert "new TestClient({})" in js , (
            f"the archetype constructor reached the bundle as a plain call: {js}"
        );
        assert "_jac.builtin.jid(" in js , (
            f"the jid() builtin reached the bundle un-lowered: {js}"
        );
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}
