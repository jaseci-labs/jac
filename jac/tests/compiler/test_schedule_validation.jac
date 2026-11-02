import from jaclang.compiler.driver.pipeline_types { AnalysisFact }

import jaclang.compiler.frontend.unitree as uni;
import jaclang.compiler.driver.pass_registry as pass_registry;
import from jaclang.compiler.driver.pass_registry {
    CFG_BUILD_STEP,
    OWNERSHIP_CHECK_STEP,
    PassStep,
    STATIC_ANALYSIS_STEP,
    TYPE_CHECK_STEP
}
import from jaclang.compiler.driver.pipeline {
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


test "schedule omitting a declared dependency fails fast at construction" {
    err = '';
    try {
        validate_schedule([OWNERSHIP_CHECK_STEP], origin='test schedule');
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
            [OWNERSHIP_CHECK_STEP],
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
        [OWNERSHIP_CHECK_STEP],
        preprovided={AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF},
        origin='test schedule'
    );
    assert sched == [OWNERSHIP_CHECK_STEP];
}

test "validation accepts a schedule whose dependencies run earlier in it" {
    sched = validate_schedule(
        [CFG_BUILD_STEP, TYPE_CHECK_STEP, OWNERSHIP_CHECK_STEP], origin='test schedule'
    );
    assert len(sched) == 3;
}

test "the analysis stage always carries type checking and the checkers" {
    sched = product_passes(CompilationProduct.ANALYSIS);
    assert TYPE_CHECK_STEP in sched;
    assert STATIC_ANALYSIS_STEP in sched;
    assert OWNERSHIP_CHECK_STEP in sched;
    assert sched.index(TYPE_CHECK_STEP) < sched.index(OWNERSHIP_CHECK_STEP);
}

def canonical_pipeline -> list[PassStep] {
    sched: list[PassStep] = [];
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
    assert CFG_BUILD_STEP in sched;
    assert TYPE_CHECK_STEP in sched;
    assert OWNERSHIP_CHECK_STEP in sched;
    assert sched.index(CFG_BUILD_STEP) < sched.index(TYPE_CHECK_STEP);
    validate_schedule(sched, origin='compile schedule');
}

test "every declared requirement is satisfied within the one pipeline" {
    sched = canonical_pipeline();
    provided: set[AnalysisFact] = set();
    for step in sched {
        for tag in step.contract.requires {
            assert tag in provided , f"{step.name} requires '{tag}' with no earlier provider";
        }
        for tag in step.contract.provides {
            provided.add(tag);
        }
    }
}

test "providers_of reports the tags a schedule segment supplies" {
    assert AnalysisFact.CFG_SUCC in providers_of([CFG_BUILD_STEP]);
    assert AnalysisFact.TYPE_OF in providers_of([TYPE_CHECK_STEP]);
    assert providers_of([]) == set();
}

test "execute_passes rejects an incoherent schedule before running any pass" {
    prog = JacProgram();
    stub = uni.Module.make_stub(inject_name='sched_stub');
    err = '';
    try {
        execute_passes(prog, stub, [OWNERSHIP_CHECK_STEP]);
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'CfgSucc'" in err;
    assert 'scheduling error' in err;
}

test "every registry step is named for the pass class it loads" {
    steps = [
        value
        for value in vars(pass_registry).values()
        if isinstance(value, PassStep)
    ];
    assert len(steps) == len({step.name for step in steps});
    for step in steps {
        assert step.load().__name__ == step.name , step.name;
    }
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
