import type from jaclang.compiler.passes.compose.kotlin_ast { KtNode }
import from jaclang.compiler.passes.ecmascript.intent.es_leaves {
    IntentExpr,
    IntentStmt
}

import from jaclang.compiler.passes.ecmascript.intent.semantics { IntentLeaf }

def is_kt_leaf(item: IntentLeaf) -> bool;
def intent_expr_to_kt(expr: (IntentExpr | None)) -> (KtNode | None);
def intent_stmt_to_kt(stmt: IntentStmt) -> (KtNode | None);
def intent_stmts_to_kt(stmts: list[IntentStmt]) -> list[KtNode];
def intent_expr_to_src(expr: (IntentExpr | None)) -> str;
def intent_stmts_to_src(stmts: list[IntentStmt], indent: str = "        ") -> str;
