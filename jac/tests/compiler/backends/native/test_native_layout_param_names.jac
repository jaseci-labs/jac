"""A unit's interface records parameter names as the source spells them.

Recording a lowering-chosen name instead (an IR name uniquified with a `.N`
suffix) made a unit's interface digest differ between two lowerings of the
same source, and every consumer was lowered again.
"""
import os;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { native_force_opts }

test "interface parameter names are the source names" {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "param_probe.jac");
        with open(path, "w") as f {
            f.write(
                "def pick(here: int, count: int, here_too: int) -> int {\n"
                "    return here + count + here_too;\n"
                "}\n"
            );
        }
        options = native_force_opts();
        options.skip_native_engine = True;
        prog = JacProgram();
        mod = prog.compile(file_path=path, options=options);
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        iface = mod.gen.native_iface;
        assert iface is not None , "native lowering produced no interface";
        assert iface.exports["pick"].param_names == ["here", "count", "here_too"] , (
            iface.exports["pick"].param_names
        );
    }
}
