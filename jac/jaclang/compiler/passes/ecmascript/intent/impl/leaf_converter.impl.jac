import jaclang.jac0core.unitree as uni;
import jaclang.compiler.passes.ecmascript.estree as es;
import from typing { cast }
import from jaclang.compiler.passes.ecmascript.intent.semantics { IntentLeaf }

impl LeafConverter.convert_ref_seed(nd: uni.UniNode) -> IntentLeaf {
    expr = self.convert_expr(nd);
    if expr is not None {
        return expr;
    }
    return self.null_expr;
}

impl LeafConverter.convert_assignment_value(
    nd: uni.Assignment, value_nd: (uni.UniNode | None)
) -> (IntentLeaf | None) {
    if value_nd is None {
        return None;
    }
    return self.convert_expr(value_nd);
}

impl LeafConverter.convert_stmts(nodes: list[uni.UniNode]) -> list[IntentLeaf] {
    return [];
}

impl EsastLeafConverter.convert_expr(nd: uni.UniNode) -> (IntentLeaf | None) {
    if nd.gen.es_ast {
        return cast(es.Expression, nd.gen.es_ast);
    }
    return None;
}

impl EsastLeafConverter.convert_assignment_value(
    nd: uni.Assignment, value_nd: (uni.UniNode | None)
) -> (IntentLeaf | None) {
    if value_nd and value_nd.gen.es_ast {
        return cast(es.Expression, value_nd.gen.es_ast);
    }
    if nd.aug_op {
        return cast(es.Expression, es.Literal(value=0));
    }
    return self.fallback_expr;
}

impl EsastLeafConverter.convert_stmts(nodes: list[uni.UniNode]) -> list[IntentLeaf] {
    if self.pass_inst is None {
        return [];
    }
    return cast(list[IntentLeaf], self.pass_inst._collect_stmt_body(nodes));
}
