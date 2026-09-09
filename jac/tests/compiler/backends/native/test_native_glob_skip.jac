"""A dual-codespace module glob whose layout cannot lower natively and
that no native code references stays py-side instead of aborting the
build. A native reference keeps the ordinary lowering error."""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     );


def aot_native_errors(name: str) -> list {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(
            aot_mode=True,
            force_codespace="native",
            force_target_program=True,
            memory_profile="managed",
            no_ir_cache=True
        )
    );
    return prog.errors_had;
}


test "unreferenced non-lowerable glob is left py-side" {
    errs = aot_native_errors("glob_skip_unused.jac");
    assert not errs , f"{[str(e) for e in errs]}";
}


test "natively referenced non-lowerable glob still errors" {
    errs = aot_native_errors("glob_skip_used.jac");
    assert errs , "expected a lowering error for the native use";
}
