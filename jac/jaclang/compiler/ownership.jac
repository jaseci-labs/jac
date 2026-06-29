import jaclang.jac0core.unitree as uni;
import from enum { Enum }

enum Ownership {
    OWNED = "owned",
    BORROWED = "borrowed",
    STATIC = "static",
    UNKNOWN = "unknown"
}

def param_plainly_rebound(sym: (uni.Symbol | None)) -> bool {
    if sym is None {
        return False;
    }

    for d in (list(sym.defn) + list(sym.uses)) {
        asg = d.find_parent_of_type(uni.Assignment);
        if asg is None or asg.aug_op is not None {
            continue;
        }
        targets = asg.target
            if isinstance(asg.target, (list, tuple))
            else [(asg.target)];
        if d in targets {
            return True;
        }
    }
    return False;
}

def loop_body_locals(body: (list | tuple | None)) -> list[str] {
    out: list[str] = [];
    seen: set[str] = set();
    if not body {
        return out;
    }
    for stmt in body {
        for nm in stmt.get_all_sub_nodes(typ=uni.Name) {
            sym = nm.sym;
            if sym is None or not sym.defn {
                continue;
            }
            if sym.defn[0] is nm and nm.sym_name not in seen {
                seen.add(nm.sym_name);
                out.append(nm.sym_name);
            }
        }
    }
    return out;
}

def result_ownership(expr: (uni.Expr | None)) -> Ownership {
    if expr is None {
        return Ownership.UNKNOWN;
    }
    if isinstance(expr, uni.FuncCall) {
        return Ownership.OWNED;
    }
    if isinstance(
        expr, (uni.ListVal, uni.SetVal, uni.DictVal, uni.ListCompr, uni.DictCompr)
    ) {
        return Ownership.OWNED;
    }
    if isinstance(expr, uni.FString) {
        return Ownership.OWNED;
    }
    if isinstance(expr, uni.MultiString) {
        if len(expr.strings) == 1 and not isinstance(expr.strings[0], uni.FString) {
            return Ownership.STATIC;
        }
        return Ownership.OWNED;
    }
    if isinstance(expr, uni.String) {
        return Ownership.STATIC;
    }
    if isinstance(expr, (uni.Name, uni.AtomTrailer)) {
        return Ownership.BORROWED;
    }
    return Ownership.UNKNOWN;
}
