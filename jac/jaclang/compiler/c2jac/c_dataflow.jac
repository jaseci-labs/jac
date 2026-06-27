"""List-bound dataflow analysis across C control flow (§9.5).

Extracted from mapper.jac. `_list_bound` (a set of pointer names proven to back
a Jac list) is a MUST property: a name is list-bound at a point only when it is
provably list-bound on EVERY path reaching it. The mapper's control-flow handlers
(c_If / c_While / c_DoWhile / c_Switch) own the set and snapshot/restore it per
branch; these functions are the pure analysis primitives they call:

  - lb_merge          — intersect path-end states at a join
  - lb_assignment_kills — does `name = rhs` rebind name off its list?
  - collect_lb_kills  — which names a loop body may rebind to a non-list

Pulling the analysis out keeps the gen/kill/merge rules legible as a unit,
separate from the node-emission they guard.
"""

import from jaclang.vendor.pycparser { c_ast }
import from jaclang.compiler.c2jac.c_idioms { malloc_array_match }

def lb_merge(states: list) -> set {
    # Intersection across path-end states — list-bound only if list-bound on
    # all of them. Empty input (no reachable path) → empty set.
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
    # Mirrors c_Assignment's gen/preserve rules: `name = rhs` keeps list-bound
    # status only when rhs is a malloc-array (gen) or a self-realloc
    # `realloc(name, …)` (same logical buffer). Any other rhs rebinds the name
    # to a non-list → a kill. A cross-pointer `name = realloc(other, …)` is
    # treated as a kill here (conservative: at worst it demotes a later realloc
    # to Tier-B, which is always sound).
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
    # Names a loop body may rebind to a non-list on some iteration. Removing
    # them from `_list_bound` before walking the body makes a realloc inside
    # the loop sound across the 0-or-more iterations (a name killed on any
    # iteration is not provably list-bound on the back-edge); a re-gen earlier
    # in the same iteration re-adds it during the walk.
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
        # A re-decl rebinds the name; only a malloc-array init keeps it bound.
        decl_init = getattr(nd, "init");
        if decl_init is None or malloc_array_match(decl_init) is None {
            killed.add(nd.name);
        }
    }
    for (_, child) in nd.children() {
        collect_lb_kills(child, killed);
    }
}
