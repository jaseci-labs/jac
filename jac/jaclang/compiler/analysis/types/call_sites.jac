import from jaclang.compiler.ir.schema {
    BinaryExpr,
    Expr,
    FuncCall,
    KWPair,
    Token,
    TupleVal
}
import from jaclang.compiler.ir.enums { Tokens as Tok }

type CallExpr = FuncCall | BinaryExpr;

def _forward(expr: BinaryExpr) -> bool {
    if not isinstance(expr.op, Token)
        or expr.op.name
            not in (Tok.PIPE_FWD, Tok.A_PIPE_FWD, Tok.PIPE_BKWD, Tok.A_PIPE_BKWD) {
        raise ValueError("Call operands require a call or pipe expression");
    }
    return expr.op.name in (Tok.PIPE_FWD, Tok.A_PIPE_FWD);
}

def call_target(expr: CallExpr) -> Expr {
    if isinstance(expr, FuncCall) {
        return expr.target;
    }
    return expr.right if _forward(expr) else expr.left;
}

def call_params(expr: CallExpr) -> list[Expr | KWPair] {
    if isinstance(expr, FuncCall) {
        return list(expr.params or []);
    }
    argument = expr.left if _forward(expr) else expr.right;
    if isinstance(argument, TupleVal) and argument.values {
        return list(argument.values);
    }
    return [argument];
}
