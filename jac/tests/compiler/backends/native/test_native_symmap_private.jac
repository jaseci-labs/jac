"""JAC_SYMMAP names the private functions of a whole-program build.

Native binaries carry no symbol table, so profiling them relies on the
`<binary>.symmap` that the linker writes when JAC_SYMMAP is set. A function
with `private` linkage gets no symbol, so the map skipped it and a profile
charged its cost to the preceding named function; the runtime's refcount
helpers were the largest case. With JAC_SYMMAP set, the merged module of a
`--link-mode bitcode` build turns `private` functions into `internal` ones
before emitting, so each gets a symbol. Both linkages are local to the module,
and builds without JAC_SYMMAP are not touched.
"""

import os;
import subprocess;
import tempfile;
import jaclang.compiler.backends.native.llvm.binding as llvm;
import from jaclang.compiler.backends.native.link_plan { name_private_functions }
import from tests.support { jac_command, TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "symmap_private.jac"
     );

test "private definitions become internal; other functions keep their linkage" {
    mod = llvm.parse_assembly(
        "define private i64 @helper(i64 %x) {\n  ret i64 %x\n}\n"
            + "define internal i64 @local(i64 %x) {\n  ret i64 %x\n}\n"
            + "declare i64 @ext(i64)\n"
            + "define i64 @api(i64 %x) {\n"
            + "  %a = call i64 @helper(i64 %x)\n"
            + "  %b = call i64 @local(i64 %a)\n"
            + "  %c = call i64 @ext(i64 %b)\n"
            + "  ret i64 %c\n"
            + "}\n"
    );
    name_private_functions(mod);
    linkage = {fn.name: fn.linkage for fn in mod.functions};
    assert linkage["helper"] == llvm.Linkage.internal , linkage;
    assert linkage["local"] == llvm.Linkage.internal , linkage;
    assert linkage["ext"] == llvm.Linkage.external , linkage;
    assert linkage["api"] == llvm.Linkage.external , linkage;
}

test "a bitcode build's symbol map names the private refcount helpers" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "symmap_private");
        res = subprocess.run(
            jac_command("build", "--native", "--link-mode", "bitcode", FIXTURE)
                + ["-o", out_bin],
            capture_output=True,
            text=True,
            env={** os.environ, "JAC_SYMMAP": "1"}
        );
        assert res.returncode == 0 , res.stderr[-800:];
        ran = subprocess.run([out_bin], capture_output=True, text=True);
        assert ran.stdout == "16275\n" , ran.stdout;
        with open(out_bin + ".symmap") as f {
            names = {line.rsplit(" ", 1)[0] for line in f.read().splitlines()};
        }
        assert "__rc_release_simple" in names , "private release helper missing from the symbol map";
    }
}
