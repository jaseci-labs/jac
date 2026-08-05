import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.intent.semantics { IntentLeaf }

obj LeafConverter {
    has null_expr: IntentLeaf,
        fallback_expr: IntentLeaf,
        reactive_vars: set[str] = set();

    def convert_expr(nd: uni.UniNode) -> (IntentLeaf | None);
    def convert_ref_seed(nd: uni.UniNode) -> IntentLeaf;
    def convert_assignment_value(
        nd: uni.Assignment, value_nd: (uni.UniNode | None)
    ) -> (IntentLeaf | None);

    def convert_stmts(nodes: list[uni.UniNode]) -> list[IntentLeaf];
}

import type from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }

obj EsastLeafConverter(LeafConverter) {
    has pass_inst: (EsastGenPass | None) = None;

    def convert_expr(nd: uni.UniNode) -> (IntentLeaf | None);
    def convert_assignment_value(
        nd: uni.Assignment, value_nd: (uni.UniNode | None)
    ) -> (IntentLeaf | None);

    def convert_stmts(nodes: list[uni.UniNode]) -> list[IntentLeaf];
}
