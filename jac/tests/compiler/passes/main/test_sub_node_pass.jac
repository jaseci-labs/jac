"""Sub node pass tests – migrated from test_sub_node_pass.py."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes { UniPass }

glob EXAMPLES = os.path.join(
         str(Path(jaclang.__file__).parent.parent), "examples"
     );

test "sub node pass" {
    out = JacProgram();
    code_gen = out.compile(
        file_path=os.path.join(EXAMPLES, "manual_code", "circle.jac")
    );
    for i in code_gen.kid[1].kid {
        for (k, v) in i._sub_node_tab.items() {
            for n in v {
                assert n in UniPass.get_all_sub_nodes(i, k, brute_force=True);
            }
        }
    }
    assert not out.errors_had;
}
