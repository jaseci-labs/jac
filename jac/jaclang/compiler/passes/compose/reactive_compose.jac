import from jaclang.compiler.passes.ecmascript.intent.model { IntentComponent }
import from jaclang.compiler.passes.ecmascript.reactive_intent { IntentLeaf }
import from jaclang.compiler.passes.compose.compose_leaves {
    intent_expr_to_src,
    intent_stmts_to_src
}

obj ReactiveComposeEmitter {
    def emit_prelude(comp: IntentComponent) -> str;
    def _expr_src(expr: (IntentLeaf | None)) -> str;
    def _stmts_src(stmts: list[IntentLeaf], indent: str = "        ") -> str;
}
