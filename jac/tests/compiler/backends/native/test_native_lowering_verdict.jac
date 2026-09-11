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

test "AOT debug compilation leaves object emission to the final linker" {
    import from pathlib { Path }
    import from unittest.mock { patch }
    import from tests.support { NATIVE_FIXTURES, native_force_opts }
    import from jaclang.compiler.driver.program { JacProgram }
    options = native_force_opts(opt_level=0);
    options.aot_mode = True;
    options.native_debug = True;
    options.native_closed_world = True;
    options.no_ir_cache = True;
    prog = JacProgram();
    with patch.object(llvm.TargetMachine, "emit_object") as emit {
        ast = prog.compile(
            file_path=str(Path(NATIVE_FIXTURES) / "inheritance.jac"), options=options
        );
        emit.assert_not_called();
    }
    assert not prog.errors_had;
    assert ast is not None;
    assert ast.gen.native_bitcode is not None;
    assert "llvm.type.checked.load" in str(ast.gen.llvm_ir);
}

test "closed world Jac lowering annotates inherited virtual calls" {
    import from tests.support { compile_native_ir, native_force_opts }
    options = native_force_opts();
    options.native_closed_world = True;
    ast = compile_native_ir("inheritance.jac", options=options);
    text = str(ast.gen.llvm_ir);
    assert "llvm.type.checked.load" in text;
    assert "!vcall_visibility" in text;
    assert '!"jac.vtable.Animal"' in text;
    clone = options.clone_for_native_import();
    assert clone.native_closed_world;
    before = clone.codegen_fingerprint();
    clone.native_closed_world = False;
    assert before != clone.codegen_fingerprint();
}

test "closed world virtual elimination preserves live inherited dispatch" {
    import from jaclang.compiler.backends.native.shared_emit { init_object_codegen }
    init_object_codegen();
    target = llvm.Target.from_default_triple();
    assert isinstance(target, llvm.Target);
    machine = target.create_target_machine();
    assert isinstance(machine, llvm.TargetMachine);
    for (visibility, offset, rejected) in [(1, 0, False), (1, 8, True), (0, 0, True)] {
        body = '@vtable = constant [2 x ptr] [ptr @good, ptr @unsupported.__jac_demoted], !type !0, !type !1, !vcall_visibility !2\n'
        'define i64 @good() { ret i64 42 }\n'
        'define i64 @unsupported.__jac_demoted() { ret i64 0 }\n'
        'declare {ptr, i1} @llvm.type.checked.load(ptr, i32, metadata)\n'
        'define i64 @entry() {\n'
        f'%checked = call {{ptr, i1}} @llvm.type.checked.load(ptr @vtable, i32 {offset}, metadata !"Base")\n'
        '%fn = extractvalue {ptr, i1} %checked, 0\n'
        '%v = call i64 %fn()\nret i64 %v\n}\n'
        '!0 = !{i64 0, !"Base"}\n!1 = !{i64 0, !"Derived"}\n'
        f'!2 = !{{i64 {visibility}}}\n'
        '!llvm.module.flags = !{!3}\n!3 = !{i32 1, !"Virtual Function Elim", i32 1}\n';
        module = llvm.parse_assembly(body);
        module.data_layout = str(machine.target_data);
        caught = False;
        try {
            prepare_native_library(module, machine, {"entry"});
        } except ValueError {
            caught = True;
        }
        assert caught == rejected;
        if not rejected {
            text = str(module);
            assert "unsupported.__jac_demoted" not in text;
            assert "call { ptr, i1 } @llvm.type.checked.load" not in text;
            assert len(machine.emit_object(module)) > 0;
        }
    }
}

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
    legacy = llvm.parse_assembly(
        'declare i64 @lost.__jac_demoted()\n'
        'define i64 @entry() { %v = call i64 @lost.__jac_demoted()\nret i64 %v }'
    );
    caught = False;
    try {
        prepare_native_library(legacy, machine, {"entry"});
    } except ValueError {
        caught = True;
    }
    assert caught , "a referenced legacy demotion declaration must be rejected";
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
