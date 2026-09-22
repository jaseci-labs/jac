"""JSX child slots are typed like attributes, so `{X if not items else None}`
lowers `not items` through the Python-truthiness helper. Before this the
evaluator validated attributes but never visited child expressions, so a
collection in a slot condition carried no type and `not items` became a bare
JavaScript `!items`, which is false for an empty list: empty states never
rendered and `if items` rendered for an empty list."""

import os;
import shutil;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob SRC: str = "def:pub Demo(items: list[str]) -> JsxElement {\n"
         + "    has local: list[str] = [];\n"
         + "    return\n"
         + "        <div>\n"
         + "            {<span>empty</span> if not items else None}\n"
         + "            {<span>some</span> if items else None}\n"
         + "            {<span>nolocal</span> if not local else None}\n"
         + "            <span>{\"a\" if not items else \"b\"}</span>\n"
         + "            <span title={\"x\" if not items else \"y\"}>t</span>\n"
         + "        </div>;\n"
         + "}\n";

test "jsx child slot conditions use python truthiness" {
    d = tempfile.mkdtemp(prefix="jacjsx_");
    try {
        with open(os.path.join(d, "jac.toml"), "w") as f {
            f.write("[project]\nname = \"t\"\nentry-point = \"main\"\n");
        }
        with open(os.path.join(d, "main.jac"), "w") as f {
            f.write("with entry {}\n");
        }
        with open(os.path.join(d, "demo.jac"), "w") as f {
            f.write(SRC);
        }
        prog = JacProgram();
        mod = prog.compile(
            os.path.join(d, "demo.jac"), options=CompileOptions(no_ir_cache=True)
        );
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        js = mod.gen.js;
        assert js , "no client output";
        stripped = js.replace("_jac.builtin.bool(items)", "");
        assert "!items" not in stripped , js;
        assert "(items ?" not in js , js;
        assert "!__jacS_local.val" not in js , js;
        assert js.count("_jac.builtin.bool(items)") >= 4 , js;
        assert "_jac.builtin.bool(__jacS_local.val)" in js , js;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}
