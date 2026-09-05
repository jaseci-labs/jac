import from jaclang.compiler.frontend.unitree { BinaryExpr, Expr, Name, Token }
import from jaclang.compiler.frontend.constant { Tokens as Tok }

glob JSX_RETURN_TYPE_NAMES: list[str] = ["JsxElement", "JsxPage", "JsxLayout"],
     JSX_RUNTIME_PREFIX: str = "__jac";

def is_jsx_runtime_helper(name: (str | None)) -> bool {
    return name is not None and name.startswith(JSX_RUNTIME_PREFIX);
}

def return_type_is_jsx(rt: (Expr | None)) -> bool {
    if rt is None {
        return False;
    }
    if (
        isinstance(rt, BinaryExpr)
        and isinstance(rt.op, Token)
        and rt.op.name == Tok.BW_OR
    ) {
        return return_type_is_jsx(rt.left) or return_type_is_jsx(rt.right);
    }
    return isinstance(rt, Name) and rt.value in JSX_RETURN_TYPE_NAMES;
}
