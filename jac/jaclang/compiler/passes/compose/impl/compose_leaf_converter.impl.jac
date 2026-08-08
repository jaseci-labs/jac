import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.intent.semantics { IntentLeaf }

impl ComposeLeafConverter.convert_expr(nd: uni.UniNode) -> (IntentLeaf | None) {
    return self.lowerer.convert_expr(nd) if self.lowerer is not None else None;
}

impl ComposeLeafConverter.convert_stmts(nodes: list[uni.UniNode]) -> list[IntentLeaf] {
    if self.lowerer is None {
        return [];
    }
    return self.lowerer.convert_stmts(nodes);
}
