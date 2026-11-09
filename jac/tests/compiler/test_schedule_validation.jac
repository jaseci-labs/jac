import from jaclang.compiler.driver.pipeline_types { AnalysisFact }

import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.pipeline {
    contract_of,
    execute_passes,
    product_passes,
    providers_of,
    validate_schedule
}
import from jaclang.compiler.driver.module_analysis { ANALYSIS_PLAN }
import from jaclang.compiler.driver.module_compile { CODEGEN_PLAN }
import from jaclang.compiler.driver.pipeline_types {
    CompilationProduct,
    ProductRequest
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
import from jaclang.compiler.passes.ownership_check_pass { OwnershipCheckPass }
import from jaclang.compiler.passes.static_analysis_pass { StaticAnalysisPass }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.passes.context { PassKind }


test "schedule omitting a declared dependency fails fast at construction" {
    err = '';
    try {
        validate_schedule([PassKind.OWNERSHIP_CHECK], origin='test schedule');
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
            [PassKind.OWNERSHIP_CHECK],
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
        [PassKind.OWNERSHIP_CHECK],
        preprovided={AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF},
        origin='test schedule'
    );
    assert sched == [PassKind.OWNERSHIP_CHECK];
}

test "validation accepts a schedule whose dependencies run earlier in it" {
    sched = validate_schedule(
        [PassKind.CFG_BUILD, PassKind.TYPE_CHECK, PassKind.OWNERSHIP_CHECK],
        origin='test schedule'
    );
    assert len(sched) == 3;
}

test "the analysis stage always carries type checking and the checkers" {
    sched = product_passes(CompilationProduct.ANALYSIS);
    assert PassKind.TYPE_CHECK in sched;
    assert PassKind.STATIC_ANALYSIS in sched;
    assert PassKind.OWNERSHIP_CHECK in sched;
    assert sched.index(PassKind.TYPE_CHECK) < sched.index(PassKind.OWNERSHIP_CHECK);
}

def canonical_pipeline -> list[PassKind] {
    sched: list[PassKind] = [];
    for product in (
        CompilationProduct.IR,
        CompilationProduct.ANALYSIS,
        CompilationProduct.BOUNDARIES,
        CompilationProduct.CODEGEN,
        CompilationProduct.PY_IR,
        CompilationProduct.FROZEN
    ) {
        sched.extend(product_passes(product, ProductRequest(native=True)));
    }
    return sched;
}

test "the canonical compile pipeline validates end to end" {
    sched = canonical_pipeline();
    assert PassKind.CFG_BUILD in sched;
    assert PassKind.TYPE_CHECK in sched;
    assert PassKind.OWNERSHIP_CHECK in sched;
    assert sched.index(PassKind.CFG_BUILD) < sched.index(PassKind.TYPE_CHECK);
    validate_schedule(sched, origin='compile schedule');
}

test "every declared requirement is satisfied within the one pipeline" {
    sched = canonical_pipeline();
    provided: set[AnalysisFact] = set();
    for p in sched {
        for tag in contract_of(p).requires {
            assert tag in provided , f"{p.value} requires '{tag}' with no earlier provider";
        }
        for tag in contract_of(p).provides {
            provided.add(tag);
        }
    }
}

test "providers_of reports the tags a schedule segment supplies" {
    assert AnalysisFact.CFG_SUCC in providers_of([PassKind.CFG_BUILD]);
    assert AnalysisFact.TYPE_OF in providers_of([PassKind.TYPE_CHECK]);
    assert providers_of([]) == set();
}

test "execute_passes rejects an incoherent schedule before running any pass" {
    prog = JacProgram();
    stub = uni.Module.make_stub(inject_name='sched_stub');
    err = '';
    try {
        execute_passes(prog, stub, [PassKind.OWNERSHIP_CHECK]);
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'CfgSucc'" in err;
    assert 'scheduling error' in err;
}

test "the module plan declares its complete step order" {
    assert [step.name for step in ANALYSIS_PLAN + CODEGEN_PLAN]
        == [
            "PARSE",
            "IR",
            "PLACEMENT",
            "ANALYSIS",
            "BOUNDARIES",
            "NATIVE_CHECKS",
            "CLIENT_DEPENDENCIES",
            "INTERFACE",
            "CODEGEN"
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
        assert not program.analysis.provides(module, AnalysisFact.TYPE_OF);
    }
}
