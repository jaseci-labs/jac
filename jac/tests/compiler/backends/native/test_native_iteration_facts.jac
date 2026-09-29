"""Native iteration consumes types recorded for whole binding patterns."""
import from tests.support { unit_symbol }

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { InnerCompr, InForStmt, TupleVal }

test "tuple iteration targets retain analysis types and execute natively" {
    program = JacProgram();
    module = program.compile(
        os.path.join(
            TESTS_DIR,
            "compiler",
            "backends",
            "native",
            "fixtures",
            "iteration_facts.jac"
        ),
        options=CompileOptions(
            force_codespace="native", need_full_ast=True, no_ir_cache=True
        )
    );
    assert not program.errors_had , str(program.errors_had);
    count = 0;
    for target in module.get_all_sub_nodes(TupleVal) {
        if isinstance(target.parent, (InnerCompr, InForStmt)) {
            assert target.type is not None;
            count += 1;
        }
    }
    assert count == 4;
    engine = module.gen.native_engine;
    assert engine is not None;
    for (name, expected) in [("comprehension", 21), ("loop", 17)] {
        address = engine.get_function_address(unit_symbol(module, name));
        assert isinstance(address, int) and address != 0;
        assert ctypes.CFUNCTYPE(ctypes.c_int64)(address)() == expected;
    }
}
