import from jaclang.compiler.pipeline.contracts { PassIdentity }
import from jaclang.compiler.pipeline.executor { execute_passes }
import from jaclang.compiler.pipeline.contracts { AnalysisFact }

import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.pipeline.schedule {
    pass_requires,
    pass_provides,
    get_analysis_sched,
    get_ir_gen_sched,
    get_boundary_analysis_sched,
    get_py_code_gen,
    module_pipeline,
    CompilationPhase,
    providers_of,
    validate_schedule
}
import from jaclang.compiler.session.session { JacProgram }


test "schedule omitting a declared dependency fails fast at construction" {
    err = '';
    try {
        validate_schedule([PassIdentity.OwnershipCheckPass], origin='test schedule');
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'CfgSucc'" in err;
    assert 'scheduling error' in err;
}

test "validation names the first missing analysis with CfgSucc preprovided" {
    err = '';
    try {
        validate_schedule(
            [PassIdentity.OwnershipCheckPass],
            preprovided={AnalysisFact.CFG_SUCC},
            origin='test schedule'
        );
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'TypeOf'" in err;
}

test "validation accepts a schedule whose dependencies are preprovided" {
    sched = validate_schedule(
        [PassIdentity.OwnershipCheckPass],
        preprovided={AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF},
        origin='test schedule'
    );
    assert sched == [PassIdentity.OwnershipCheckPass];
}

test "validation accepts a schedule whose dependencies run earlier in it" {
    sched = validate_schedule(
        [
            PassIdentity.CFGBuildPass,
            PassIdentity.TypeCheckPass,
            PassIdentity.OwnershipCheckPass
        ],
        origin='test schedule'
    );
    assert len(sched) == 3;
}

test "the analysis stage always carries type checking and the checkers" {
    sched = get_analysis_sched();
    assert PassIdentity.TypeCheckPass in sched;
    assert PassIdentity.StaticAnalysisPass in sched;
    assert PassIdentity.OwnershipCheckPass in sched;
    assert sched.index(PassIdentity.TypeCheckPass)
        < sched.index(PassIdentity.OwnershipCheckPass);
}

test "the canonical compile pipeline validates end to end" {
    sched = get_ir_gen_sched() + get_analysis_sched() + get_boundary_analysis_sched();
    sched += get_py_code_gen(provided=providers_of(sched));
    assert PassIdentity.CFGBuildPass in sched;
    assert PassIdentity.TypeCheckPass in sched;
    assert PassIdentity.OwnershipCheckPass in sched;
    assert sched.index(PassIdentity.CFGBuildPass)
        < sched.index(PassIdentity.TypeCheckPass);
    validate_schedule(sched, origin='compile schedule');
}

test "every declared requirement is satisfied within the one pipeline" {
    sched = get_ir_gen_sched() + get_analysis_sched() + get_boundary_analysis_sched();
    sched += get_py_code_gen(provided=providers_of(sched));
    provided: set[AnalysisFact] = set();
    for p in sched {
        for tag in pass_requires(p) {
            assert tag in provided , f"{p.value} requires '{tag}' with no earlier provider";
        }
        for tag in pass_provides(p) {
            provided.add(tag);
        }
    }
}

test "providers_of reports the tags a schedule segment supplies" {
    assert AnalysisFact.CFG_SUCC in providers_of([PassIdentity.CFGBuildPass]);
    assert AnalysisFact.TYPE_OF in providers_of([PassIdentity.TypeCheckPass]);
    assert providers_of([]) == set();
}

test "the executor rejects an incoherent schedule before running any pass" {
    prog = JacProgram();
    stub = uni.Module.make_stub(inject_name='sched_stub');
    err = '';
    try {
        execute_passes(prog, stub, [PassIdentity.OwnershipCheckPass]);
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'CfgSucc'" in err;
    assert 'scheduling error' in err;
}

test "the module pipeline declares its complete phase order" {
    assert [step.phase for step in module_pipeline()]
        == [
            CompilationPhase.PARSE,
            CompilationPhase.IR,
            CompilationPhase.PLACEMENT,
            CompilationPhase.ANALYSIS,
            CompilationPhase.BOUNDARIES,
            CompilationPhase.NATIVE_CHECKS,
            CompilationPhase.CLIENT_DEPENDENCIES,
            CompilationPhase.INTERFACE,
            CompilationPhase.CODEGEN
        ];
}


test "symbols-only requests never resolve types to serialize an interface" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.compiler.session.options { CompileOptions }
    with TemporaryDirectory() as td {
        path = Path(td) / 'main.jac';
        path.write_text('def value -> int { return 1; }\n');
        program = JacProgram();
        import from jaclang.compiler.analysis.interfaces.interface_pass {
            InterfaceFactsPass
        }
        with patch.object(
            InterfaceFactsPass,
            'transform',
            side_effect=AssertionError(
                'symbols-only compilation resolved interface types'
            )
        ) as encode {
            module = program.compile(
                str(path), options=CompileOptions(symtab_ir_only=True)
            );
            assert not encode.called;
        }
        assert not program.errors_had;
        assert not program.analysis.provides(module, AnalysisFact.TYPE_OF);
    }
}

test "dependency interfaces are scheduled by the importing module interface producer" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from jaclang.compiler.pipeline.progress {
        pipeline_progress,
        ProgressEvent,
        ProgressState
    }
    import from jaclang.compiler.session.options { CompileOptions }
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        dependency = base / 'helper.jac';
        dependency.write_text('def value -> int { return 1; }');
        main = base / 'main.jac';
        main.write_text('import helper; def value -> int { return helper.value(); }');
        interfaces: list[str] = [];
        bindings: list[str] = [];
        def observe(event: ProgressEvent) {
            if event.operation == PassIdentity.InterfaceFactsPass.value
                and event.state == ProgressState.STARTED {
                interfaces.append(event.path);
            }
            if event.operation == PassIdentity.SymTabBuildPass.value
                and event.state == ProgressState.STARTED
                and event.path in (str(main), str(dependency)) {
                bindings.append(event.path);
            }
        }
        program = JacProgram();
        with pipeline_progress.listen(observe) {
            program.compile(
                str(main),
                options=CompileOptions(
                    no_cgen=True, no_ir_cache=True, default_codespace='server'
                )
            );
        }
        assert not program.errors_had , [str(error) for error in program.errors_had];
        assert interfaces == [str(main), str(dependency)] , interfaces;
        assert program.source_store.parses == 2;
        assert bindings == [str(main), str(dependency)] , bindings;
    }
}
