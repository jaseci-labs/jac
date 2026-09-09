"""Lowering failures survive IR linking and retain ABI-preserving method names."""
import from jaclang.compiler.backends.native.llvm { ir, binding as llvm }
import from jaclang.compiler.backends.native.lowering {
    NativeLoweringIssue,
    NativeLoweringKind,
    native_lowering_issues,
    prepare_native_library
}
import from jaclang.compiler.backends.native.na_compile_pass {
    native_demoted_ir_symbols
}
import from tests.support { compile_native }

test "library closure checks exports and indirect dependencies before optimization" {
    import from jaclang.compiler.backends.native.shared_emit { init_object_codegen }
    init_object_codegen();
    target = llvm.Target.from_default_triple();
    assert isinstance(target, llvm.Target);
    machine = target.create_target_machine();
    assert isinstance(machine, llvm.TargetMachine);
    for (body, exports, rejected) in [
        (
            'define i64 @entry() { ret i64 7 }\ndefine i64 @unsupported() { ret i64 0 }',
            {"entry"},
            False
        ),
        (
            'define i64 @entry() { %v = call i64 @unsupported()\nret i64 %v }\ndefine i64 @unsupported() { ret i64 0 }',
            {"entry"},
            True
        ),
        (
            '@dispatch = global ptr @unsupported\ndefine i64 @entry() { ret i64 7 }\ndefine i64 @unsupported() { ret i64 0 }',
            {"entry", "dispatch"},
            True
        ),
        (
            'define i64 @entry() { ret i64 7 }\ndefine i64 @unsupported() { ret i64 0 }',
            {"entry", "unsupported"},
            True
        ),
        ('define i64 @entry() { ret i64 7 }', {"entry"}, True)
    ] {
        records = ir.Module(name="verdict");
        NativeLoweringIssue(
            symbol="unsupported",
            kind=NativeLoweringKind.CALLABLE,
            source="fixture.jac",
            code="E5092",
            detail="cannot lower"
        ).record(
            records
        );
        module = llvm.parse_assembly(str(records) + "\n" + body);
        caught = False;
        try {
            prepare_native_library(module, machine, exports);
        } except ValueError {
            caught = True;
        }
        assert caught == rejected;
        if not rejected {
            text = str(module);
            assert "define i64 @entry" in text;
            assert "define internal i64 @unsupported" not in text;
        }
    }
}

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

test "runtime unit caches cannot admit partial native lowering" {
    import os;
    import tempfile;
    import from jaclang.compiler.backends.native.na_compile_pass {
        _compile_kernel_unit_ir,
        _kernel_unit_opts,
        native_compiler_fingerprint
    }
    import from jaclang.compiler.backends.common.kernel_units {
        store_unit_artifact,
        unit_artifact_path
    }
    opts = _kernel_unit_opts("cycles", False);
    fingerprint = native_compiler_fingerprint(opts);
    with tempfile.TemporaryDirectory() as directory {
        unit = os.path.join(directory, os.path.basename(directory) + ".jac");
        with open(unit, "w") as stream {
            stream.write("def probe -> int { return 1; }\n");
        }
        artifact = unit_artifact_path(unit, "ll", fingerprint);
        key = f"{unit}|{fingerprint}";
        try {
            for kind in [NativeLoweringKind.FIELD, NativeLoweringKind.CALLABLE] {
                partial = ir.Module(name="partial");
                NativeLoweringIssue(
                    symbol="Runtime.operation",
                    kind=kind,
                    source=unit,
                    code="E5092",
                    detail="unsupported runtime operation"
                ).record(
                    partial
                );
                text = str(partial);
                assert _compile_kernel_unit_ir(unit, {key: text}, opts) is None;
                store_unit_artifact(unit, "ll", fingerprint, text);
                assert _compile_kernel_unit_ir(unit, {}, opts) is None;
            }
            legacy = 'define void @"lost.__jac_demoted"() { ret void }\n';
            assert _compile_kernel_unit_ir(unit, {key: legacy}, opts) is None;
            store_unit_artifact(unit, "ll", fingerprint, legacy);
            assert _compile_kernel_unit_ir(unit, {}, opts) is None;
            valid = str(ir.Module(name="complete"));
            assert _compile_kernel_unit_ir(unit, {key: valid}, opts) == valid;
        } finally {
            if os.path.exists(artifact) {
                os.remove(artifact);
            }
        }
    }
}
