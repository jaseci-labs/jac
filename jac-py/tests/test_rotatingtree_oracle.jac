"""Differential oracle for jac-py/Modules/rotatingtree staged port.

Reuses the c2jac lift oracle harness: system cc on the pinned C source vs
jac run on the checked-in staged .jac must agree on RotatingTree_RandomBits(3).
"""

import os;
import from tests.support { JAC_ROOT }
import from tests.compiler.c2jac.lift_oracle { assert_staged_jac_matches_c }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MODULES: str = os.path.join(REPO_ROOT, "jac-py", "Modules"),
     ROTATINGTREE_C: str = os.path.join(MODULES, "rotatingtree.c"),
     ROTATINGTREE_JAC: str = os.path.join(MODULES, "rotatingtree.jac"),
     _DRIVER: str = "#include <stdio.h>\n"
     "int RotatingTree_RandomBits(int bits);\n"
     "int main(void) {\n"
     "    printf(\"%d\\n\", RotatingTree_RandomBits(3));\n"
     "    return 0;\n"
     "}\n",
     _ENTRY: str = "with entry {\n" "    print(RotatingTree_RandomBits(3));\n" "}\n";


test "jac-py rotatingtree: cc vs staged jac agree on RotatingTree_RandomBits(3)" {
    assert_staged_jac_matches_c(
        ROTATINGTREE_C, ROTATINGTREE_JAC, _DRIVER, _ENTRY, include_dirs=[MODULES]
    );
}
