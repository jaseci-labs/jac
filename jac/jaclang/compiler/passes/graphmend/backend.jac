import from jaclang.compiler.driver.pipeline { register_codegen_backend }
import from jaclang.compiler.passes.context { PassSchedule }
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

def graphmend_codegen_schedule -> PassSchedule {
    return [
        GraphBreakDetectPass,
        TrapLoweringPass,
        PredicateCtrlFlowPass,
        DeferSideEffectPass
    ];
}

with entry {
    register_codegen_backend("graphmend", graphmend_codegen_schedule);
}
