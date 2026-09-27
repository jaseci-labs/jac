"""Client boundary audits consume only their compilation program's metadata."""
import from unittest.mock { patch }
import from jaclang.compiler.boundary_audit { boundary_audit }
import from jaclang.compiler.driver.program { JacProgram }

test "boundary audits do not include an unrelated selfhost program" {
    current = JacProgram();
    current.compile(
        file_path="audit_current.jac",
        use_str="def:pub app_endpoint(value: int) -> int { return value; }"
    );
    unrelated = JacProgram();
    unrelated.compile(
        file_path="audit_unrelated.jac",
        use_str="def:pub unrelated_endpoint(value: int) -> int { return value; }"
    );
    assert not current.errors_had , str(current.errors_had);
    assert not unrelated.errors_had , str(unrelated.errors_had);
    with patch.object(
        current._get_compiler().selfhost, "peek_program", return_value=unrelated
    ) {
        audit = boundary_audit(current, []);
        assert {effect["name"] for effect in audit["effects"].values()}
            == {"app_endpoint"} , str(audit);
    }
}
