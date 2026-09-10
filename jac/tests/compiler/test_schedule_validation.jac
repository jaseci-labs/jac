import from jaclang.compiler.driver.pipeline_types { AnalysisFact }

import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.pipeline {
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
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
import from jaclang.compiler.passes.ownership_check_pass { OwnershipCheckPass }
import from jaclang.compiler.passes.static_analysis_pass { StaticAnalysisPass }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }


test "schedule omitting a declared dependency fails fast at construction" {
    err = '';
    try {
        validate_schedule([OwnershipCheckPass], origin='test schedule');
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
            [OwnershipCheckPass],
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
        [OwnershipCheckPass],
        preprovided={AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF},
        origin='test schedule'
    );
    assert sched == [OwnershipCheckPass];
}

test "validation accepts a schedule whose dependencies run earlier in it" {
    sched = validate_schedule(
        [CFGBuildPass, TypeCheckPass, OwnershipCheckPass], origin='test schedule'
    );
    assert len(sched) == 3;
}

test "the analysis stage always carries type checking and the checkers" {
    sched = get_analysis_sched();
    assert TypeCheckPass in sched;
    assert StaticAnalysisPass in sched;
    assert OwnershipCheckPass in sched;
    assert sched.index(TypeCheckPass) < sched.index(OwnershipCheckPass);
}

test "the canonical compile pipeline validates end to end" {
    sched = get_ir_gen_sched() + get_analysis_sched() + get_boundary_analysis_sched();
    sched += get_py_code_gen(provided=providers_of(sched));
    assert CFGBuildPass in sched;
    assert TypeCheckPass in sched;
    assert OwnershipCheckPass in sched;
    assert sched.index(CFGBuildPass) < sched.index(TypeCheckPass);
    validate_schedule(sched, origin='compile schedule');
}

test "every declared requirement is satisfied within the one pipeline" {
    sched = get_ir_gen_sched() + get_analysis_sched() + get_boundary_analysis_sched();
    sched += get_py_code_gen(provided=providers_of(sched));
    provided: set[AnalysisFact] = set();
    for p in sched {
        for tag in pass_requires(p) {
            assert tag in provided , f"{p.__name__} requires '{tag}' with no earlier provider";
        }
        for tag in pass_provides(p) {
            provided.add(tag);
        }
    }
}

test "providers_of reports the tags a schedule segment supplies" {
    assert AnalysisFact.CFG_SUCC in providers_of([CFGBuildPass]);
    assert AnalysisFact.TYPE_OF in providers_of([TypeCheckPass]);
    assert providers_of([]) == set();
}

test "run_schedule rejects an incoherent schedule before running any pass" {
    prog = JacProgram();
    stub = uni.Module.make_stub(inject_name='sched_stub');
    err = '';
    try {
        prog.run_schedule(stub, [OwnershipCheckPass]);
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
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    with TemporaryDirectory() as td {
        path = Path(td) / 'main.jac';
        path.write_text('def value -> int { return 1; }\n');
        program = JacProgram();
        registry = program.iface_registry();
        with patch.object(
            type(registry),
            '_encode_iface',
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
        assert not program.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF);
    }
}
