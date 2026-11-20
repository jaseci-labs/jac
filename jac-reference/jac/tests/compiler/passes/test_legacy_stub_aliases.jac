"""Legacy stub aliases retain their RHS types during overload selection."""
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "direct and renamed TypeAlias markers preserve overload argument types" {
    base = Path(__file__).parent / "fixtures" / "checker";
    good = JacProgram();
    good.compile(
        str(base / "checker_legacy_stub_aliases.jac"),
        options=CompileOptions(no_cgen=True, default_codespace="server")
    );
    assert not good.errors_had , "\n".join(e.pretty_print() for e in good.errors_had);
    bad = JacProgram();
    bad.compile(
        str(base / "checker_legacy_stub_aliases_err.jac"),
        options=CompileOptions(no_cgen=True, default_codespace="server")
    );
    assert len(bad.errors_had) == 1;
    assert bad.errors_had[0].code is not None;
    assert bad.errors_had[0].code.code == "E1002";
}
