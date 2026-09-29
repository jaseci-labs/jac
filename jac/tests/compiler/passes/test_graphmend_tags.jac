"""Pass-schedule tags and the schedule-time gate."""
import os;
import from tests.support { GRAPHMEND_FIXTURES as FIXTURES }
import jaclang.compiler.driver.pipeline as pipeline_mod;
import from jaclang.compiler.driver.pipeline {
    contract_of,
    product_facts,
    product_passes,
    validate_schedule
}
import from jaclang.compiler.driver.pipeline_types {
    CompilationProduct,
    ProductRequest
}
import from jaclang.compiler.passes.graphmend.graph_break_detect_pass {
    GraphBreakDetectPass
}
import from jaclang.compiler.passes.graphmend.trap_lowering_pass { TrapLoweringPass }
import from jaclang.compiler.passes.graphmend.predicate_ctrl_flow_pass {
    PredicateCtrlFlowPass
}
import from jaclang.compiler.passes.graphmend.defer_side_effect_pass {
    DeferSideEffectPass
}

def _provides(p: type) -> tuple[str, ...] {
    return tuple(f.value for f in contract_of(p).provides);
}

def _requires(p: type) -> tuple[str, ...] {
    return tuple(f.value for f in contract_of(p).requires);
}

test "detect pass provides the graph-breaks tag" {
    assert _provides(GraphBreakDetectPass) == ('graph-breaks', );
}

test "transform passes require the graph-breaks tag" {
    for p in [TrapLoweringPass, PredicateCtrlFlowPass, DeferSideEffectPass] {
        assert 'graph-breaks' in _requires(p);
    }
}

test "the transform ordering constraints are declared as tags" {
    assert 'lowered-guards' in _provides(TrapLoweringPass);
    assert 'lowered-guards' in _requires(PredicateCtrlFlowPass);
    assert 'predicated-branches' in _provides(PredicateCtrlFlowPass);
    assert 'predicated-branches' in _requires(DeferSideEffectPass);
}

test "the graphmend schedule order derives from tags, not goal position" {
    ordered: list[type] = [
        GraphBreakDetectPass,
        TrapLoweringPass,
        PredicateCtrlFlowPass,
        DeferSideEffectPass
    ];
    assert validate_schedule(ordered, origin='graphmend tag-derivation test')
        == ordered;
    scrambled: list[type] = [
        DeferSideEffectPass,
        PredicateCtrlFlowPass,
        TrapLoweringPass
    ];
    refused = False;
    try {
        validate_schedule(scrambled, origin='graphmend tag-derivation test');
    } except RuntimeError {
        refused = True;
    }
    assert refused , "an order that ignores the tags must be refused";
}

glob GM_PASSES: list[type] = [
         GraphBreakDetectPass,
         TrapLoweringPass,
         PredicateCtrlFlowPass,
         DeferSideEffectPass
     ];

test "the graphmend product orders detect before the transforms and validates" {
    sched = product_passes(CompilationProduct.GRAPHMEND);
    validate_schedule(
        sched,
        preprovided=product_facts(CompilationProduct.ANALYSIS),
        origin='graphmend tag test'
    );
    assert sched.index(GraphBreakDetectPass) < sched.index(TrapLoweringPass);
    assert sched.index(TrapLoweringPass) < sched.index(PredicateCtrlFlowPass);
    assert sched.index(PredicateCtrlFlowPass) < sched.index(DeferSideEffectPass);
}

test "the codegen products schedule none of the four passes" {
    sched = product_passes(CompilationProduct.CODEGEN, ProductRequest(native=False))
        + product_passes(CompilationProduct.PY_IR);
    validate_schedule(
        sched,
        preprovided=product_facts(CompilationProduct.IR)
            | product_facts(CompilationProduct.FLOW)
            | product_facts(CompilationProduct.ANALYSIS),
        origin='graphmend off schedule'
    );
    for p in GM_PASSES {
        assert p not in sched , f"{p.__name__} must not be scheduled when off";
    }
}

"""Compile a fixture under the given graphmend setting and collect every pass
the compiler actually resolved into a schedule."""
def _scheduled_passes(name: str, gm: bool) -> list[type] {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.program { JacProgram }
    seen: list[type] = [];
    orig: any = pipeline_mod.execute_passes;
    def _spy(program: any, module: any, passes: any, cancel_token: any = None) -> any {
        seen.extend(passes);
        return orig(program, module, passes, cancel_token);
    }
    pipeline_mod.execute_passes = _spy;
    try {
        JacProgram().compile(
            file_path=os.path.join(FIXTURES, name), options=CompileOptions(graphmend=gm)
        );
    } finally {
        pipeline_mod.execute_passes = orig;
    }
    return seen;
}

test "an off compile never instantiates the graphmend passes" {
    off = _scheduled_passes("val_guard_all.jac", False);
    for p in GM_PASSES {
        assert p not in off , f"{p.__name__} was scheduled on an off compile";
    }
    on = _scheduled_passes("val_guard_all.jac", True);
    for p in GM_PASSES {
        assert p in on , f"{p.__name__} must run when graphmend is live";
    }
}
