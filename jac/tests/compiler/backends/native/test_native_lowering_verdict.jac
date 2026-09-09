"""Lowering failures survive IR linking and retain ABI-preserving method names."""
import from jaclang.compiler.backends.native.llvm { ir, binding as llvm }
import from jaclang.compiler.backends.native.lowering {
    NativeLoweringIssue,
    NativeLoweringKind,
    native_lowering_issues
}
import from jaclang.compiler.backends.native.na_compile_pass {
    native_demoted_ir_symbols
}
import from tests.support { compile_native }

test "method demotion is visible without changing the method ABI name" {
    (_, module) = compile_native("partial_native.jac");
    text = str(module.gen.llvm_ir);
    issues = native_lowering_issues(text);
    assert any(issue.symbol == "Literal.evaluate" for issue in issues);
    assert "Literal.evaluate" in native_demoted_ir_symbols(text);
}

test "lowering records retain details through bitcode and linking" {
    left = ir.Module(name="left");
    right = ir.Module(name="right");
    NativeLoweringIssue(
        symbol="Model.value",
        kind=NativeLoweringKind.FIELD,
        source="quoted\"/source.jac",
        code="E5092",
        detail="field\n☃"
    ).record(
        left
    );
    NativeLoweringIssue(
        symbol="Model.run",
        kind=NativeLoweringKind.CALLABLE,
        source="other.jac",
        code="E5090",
        detail="unsupported call"
    ).record(
        right
    );
    linked = llvm.parse_assembly(str(left));
    linked.link_in(llvm.parse_assembly(str(right)));
    restored = llvm.parse_bitcode(linked.as_bitcode());
    restored.verify();
    issues = native_lowering_issues(str(restored));
    assert len(issues) == 2;
    fields = [
        issue
        for issue in issues
        if issue.kind == NativeLoweringKind.FIELD
    ];
    assert len(fields) == 1;
    assert fields[0].source == "quoted\"/source.jac";
    assert fields[0].detail == "field\n☃";
    assert native_demoted_ir_symbols(str(restored)) == ["Model.run"];
}

test "invalid lowering metadata cannot silently pass coverage" {
    failed = False;
    try {
        native_lowering_issues("!jac.native.lowering.v1 = !{!12}\n");
    } except (KeyError, ValueError) {
        failed = True;
    }
    assert failed;
}
