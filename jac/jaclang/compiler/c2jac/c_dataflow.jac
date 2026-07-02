import from jaclang.vendor.pycparser { c_ast }
import from jaclang.compiler.c2jac.c_idioms { malloc_array_match }

def lb_merge(states: list) -> set {
    if not states {
        return set();
    }
    out: set = set(states[0]);
    for s in states[1:] {
        out &= s;
    }
    return out;
}

def lb_assignment_kills(name: str, rhs: object) -> bool {
    if malloc_array_match(rhs) is not None {
        return False;
    }
    if isinstance(rhs, c_ast.FuncCall)
    and isinstance(rhs.name, c_ast.ID)
    and rhs.name.name == "realloc"
    and rhs.args is not None
    and len(rhs.args.exprs) >= 1 {
        ptr = rhs.args.exprs[0];
        if isinstance(ptr, c_ast.ID) and ptr.name == name {
            return False;
        }
    }
    return True;
}

def collect_lb_kills(nd: object, killed: set) {
    if nd is None {
        return;
    }
    if isinstance(nd, c_ast.Assignment)
    and nd.op == "="
    and isinstance(nd.lvalue, c_ast.ID) {
        if lb_assignment_kills(nd.lvalue.name, nd.rvalue) {
            killed.add(nd.lvalue.name);
        }
    } elif isinstance(nd, c_ast.Decl) and nd.name is not None {
        decl_init = getattr(nd, "init");
        if decl_init is None or malloc_array_match(decl_init) is None {
            killed.add(nd.name);
        }
    }
    for (_, child) in nd.children() {
        collect_lb_kills(child, killed);
    }
}
