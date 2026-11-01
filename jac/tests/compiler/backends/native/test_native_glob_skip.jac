"""A dual-codespace module glob whose layout cannot lower natively and
that no native code references stays py-side instead of aborting the
build. A native reference keeps the ordinary lowering refusal (E5092)."""

import os;
import from tests.support {
    JAC_ROOT,
    diagnostics_text,
    error_codes,
    kernel_compile_file
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.kernel_api { CompileResult }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     );


def aot_native_compile(name: str) -> CompileResult {
    return kernel_compile_file(
        os.path.join(FIXTURES, name),
        CompileOptions(
            aot_mode=True,
            force_codespace="native",
            native_required=True,
            na_gc_mode="cycles"
        ),
        ["mir"]
    );
}


test "unreferenced non-lowerable glob is left py-side" {
    result = aot_native_compile("glob_skip_unused.jac");
    assert not result.errors , diagnostics_text(result);
}


test "natively referenced non-lowerable glob still errors" {
    result = aot_native_compile("glob_skip_used.jac");
    assert "E5092" in error_codes(result) , (
        f"expected a lowering refusal for the native use: {diagnostics_text(result)}"
    );
}
