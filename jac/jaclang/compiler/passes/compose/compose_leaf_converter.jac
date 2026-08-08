import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.intent.leaf_converter { LeafConverter }
import from jaclang.compiler.passes.ecmascript.intent.semantics { IntentLeaf }
import from jaclang.compiler.passes.compose.jac_to_kotlin { JacToKotlin }

obj ComposeLeafConverter(LeafConverter) {
    has lowerer: (JacToKotlin | None) = None;

    def convert_expr(nd: uni.UniNode) -> (IntentLeaf | None);
    def convert_stmts(nodes: list[uni.UniNode]) -> list[IntentLeaf];
}
