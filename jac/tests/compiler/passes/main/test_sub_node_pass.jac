"""Sub node pass tests – migrated from test_sub_node_pass.py."""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes { UniPass }

glob LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "sub node pass" {
    out = JacProgram();
    code_gen = out.compile(file_path=os.path.join(LANG_FIXTURES, "circle.jac"));
    for i in code_gen.kid[1].kid {
        for (k, v) in i._sub_node_tab.items() {
            for n in v {
                assert n in UniPass.get_all_sub_nodes(i, k);
            }
        }
    }
    assert not out.errors_had;
}
