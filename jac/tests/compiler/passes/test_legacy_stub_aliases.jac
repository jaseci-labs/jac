"""Legacy stub aliases retain their RHS types during overload selection."""
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support { diagnostics_text, error_codes, kernel_check_file }

test "direct and renamed TypeAlias markers preserve overload argument types" {
    base = Path(__file__).parent / "fixtures" / "checker";
    good = kernel_check_file(
        str(base / "checker_legacy_stub_aliases.jac"),
        CompileOptions(default_codespace="server")
    );
    assert good.ok() , diagnostics_text(good);
    bad = kernel_check_file(
        str(base / "checker_legacy_stub_aliases_err.jac"),
        CompileOptions(default_codespace="server")
    );
    assert error_codes(bad) == ["E1002"] , diagnostics_text(bad);
}
