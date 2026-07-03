import from jaclang.vendor.pycparser { c_ast }
import from jaclang.compiler.c2jac.c_types { JacPrim, C_PRIM_MAP, user_type_name }

def flatten_mult(nd: object, acc: list) {
    if isinstance(nd, c_ast.BinaryOp) and nd.op == "*" {
        flatten_mult(nd.left, acc);
        flatten_mult(nd.right, acc);
    } else {
        acc.append(nd);
    }
}

def sizeof_type(f: object) -> str | None {
    if not isinstance(f, c_ast.UnaryOp) or f.op != "sizeof" {
        return None;
    }
    inner = f.expr;
    if isinstance(inner, c_ast.ID) {
        return inner.name;
    }
    if isinstance(inner, c_ast.Typename) {
        tt = inner.type;
        if isinstance(tt, c_ast.PtrDecl) {
            tt = tt.type;
        }
        if isinstance(tt, c_ast.TypeDecl) {
            it = tt.type;
            if isinstance(it, c_ast.Struct) and it.name {
                return it.name;
            }
            names = it?.names;
            if names {
                return names[-1];
            }
        }
    }
    return None;
}

def is_listable_elem(tname: str) -> bool {
    if tname in C_PRIM_MAP {
        return C_PRIM_MAP.get(tname, JacPrim.INT) in (
            JacPrim.INT,
            JacPrim.FLOAT,
            JacPrim.BOOL
        );
    }
    return True;
}

def _is_call_1arg(nd: object, fname: str) -> bool {
    if not isinstance(nd, c_ast.FuncCall) {
        return False;
    }
    if not isinstance(nd.name, c_ast.ID) or nd.name.name != fname {
        return False;
    }
    return nd.args is not None and len(nd.args.exprs) == 1;
}

def realloc_ptr_arg(nd: object) -> object | None {
    if not isinstance(nd, c_ast.FuncCall) {
        return None;
    }
    if not isinstance(nd.name, c_ast.ID) or nd.name.name != "realloc" {
        return None;
    }
    if nd.args is None or len(nd.args.exprs) < 1 {
        return None;
    }
    return nd.args.exprs[0];
}

def malloc_array_match(nd: object) -> str | None {
    if not _is_call_1arg(nd, "malloc") {
        return None;
    }
    factors: list = [];
    flatten_mult(nd.args.exprs[0], factors);
    sizeof_name: str | None = None;
    others = 0;
    for f in factors {
        t = sizeof_type(f);
        if t is not None and sizeof_name is None {
            sizeof_name = t;
        } else {
            others += 1;
        }
    }
    if sizeof_name is None or others == 0 {
        return None;
    }
    if not is_listable_elem(sizeof_name) {
        return None;
    }
    return sizeof_name;
}

def malloc_struct_type(nd: object) -> str | None {
    if not _is_call_1arg(nd, "malloc") {
        return None;
    }
    arg = nd.args.exprs[0];
    if not isinstance(arg, c_ast.UnaryOp) or arg.op != "sizeof" {
        return None;
    }
    inner = arg.expr;
    if isinstance(inner, c_ast.Typename) and isinstance(inner.type, c_ast.TypeDecl) {
        return user_type_name(inner.type.type);
    }
    if isinstance(inner, c_ast.ID) {
        return inner.name;
    }
    return None;
}

def realloc_of_list_bound(nd: object, list_bound: set) -> bool {
    ptr = realloc_ptr_arg(nd);
    return isinstance(ptr, c_ast.ID) and ptr.name in list_bound;
}
