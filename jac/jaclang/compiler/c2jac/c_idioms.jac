"""Structural recognizers for the C malloc/realloc pointer idioms (§7).

Extracted from mapper.jac. These functions are pure *structural tests* over the
pycparser c_ast: given a node, they answer "is this `malloc(n*sizeof(T))`?",
"what element type?", "is this a `realloc` of a known list?" — without building
any output node or recording any tag. The mapper's node-building idiom handlers
(`_malloc_array`, `_realloc_elide`, …) call these to decide *whether* an idiom
applies, then emit the faithful Jac form and stamp the Tier verdict.

Keeping the recognition logic separate from the emission/tagging logic means the
"what shape is this" rules can be read, tested, and extended on their own.
"""

import from pycparser { c_ast }
import from jaclang.compiler.c2jac.c_types { C_PRIM_MAP, user_type_name }

def flatten_mult(nd: object, acc: list) {
    # Collect the multiplicative factors of a `*`-chain into acc (so
    # `n * sizeof(T)` and `2 * n * sizeof(T)` both yield a flat factor list).
    if isinstance(nd, c_ast.BinaryOp) and nd.op == "*" {
        flatten_mult(nd.left, acc);
        flatten_mult(nd.right, acc);
    } else {
        acc.append(nd);
    }
}

def sizeof_type(f: object) -> str | None {
    # Raw C type name of a `sizeof(T)` / `sizeof(T*)` factor, else None.
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
    # A malloc element type we can default-initialize into a Jac list: any
    # user type, or a numeric/bool primitive. char (string buffer) and void
    # are not list-of-objects — they stay Tier-B.
    if tname in C_PRIM_MAP {
        return C_PRIM_MAP.get(tname, "int") in ("int", "float", "bool");
    }
    return True;
}

def malloc_array_match(nd: object) -> str | None {
    # Pure structural test (no node-building, no tagging): if nd is
    # `malloc(<count> * sizeof(T))` with at least one non-sizeof factor and a
    # list-able element T, return T's C name; else None.
    if not isinstance(nd, c_ast.FuncCall) {
        return None;
    }
    if not isinstance(nd.name, c_ast.ID) or nd.name.name != "malloc" {
        return None;
    }
    if nd.args is None or len(nd.args.exprs) != 1 {
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
    # Returns the struct/typedef name if nd is malloc(sizeof(T)) for a named type T, else None.
    if not isinstance(nd.name, c_ast.ID) or nd.name.name != "malloc" {
        return None;
    }
    if nd.args is None or len(nd.args.exprs) != 1 {
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
    # True if nd is `realloc(p, …)` where p is an ID currently proven list-bound.
    # Such a reassignment yields the same logical buffer, so list-boundness is
    # preserved across `arr = realloc(arr, …)` rather than dropped (§7.5).
    if not isinstance(nd, c_ast.FuncCall) {
        return False;
    }
    if not isinstance(nd.name, c_ast.ID) or nd.name.name != "realloc" {
        return False;
    }
    if nd.args is None or len(nd.args.exprs) < 1 {
        return False;
    }
    ptr = nd.args.exprs[0];
    return isinstance(ptr, c_ast.ID) and ptr.name in list_bound;
}
