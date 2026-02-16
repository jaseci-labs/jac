"""Bytecode generation pass tests – migrated from test_pybc_gen_pass.py."""

import os;
import marshal;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures"
     );

test "simple bcgen" {
    jac_code = JacProgram().compile(file_path=os.path.join(FIXTURES, "func.jac"));
    bytecode = jac_code.gen.py_bytecode;
    assert bytecode is not None , "Expected bytecode to be generated";
    marshal.loads(bytecode);
}
