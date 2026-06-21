"""Result-ownership classification (One Owner Per Analysis, Phase 7).

THE written reference-counting ownership invariant for Jac expression
results. Backends consume this classification instead of deciding
per emission site which values carry a reference; the rules below are
the single home of the answer to "does this expression's result arrive
with a +1 the consumer must balance?".

Classification:

- OWNED: the expression's pointer-typed result carries a +1 reference
  that its consumer must release, store, or hand on. Every
  pointer-returning call is OWNED (user functions RETAIN internally for
  borrowed refs or donate a named local's ref via the return path's
  skip-var mechanism; foreign scalar-pointer returns are treated as
  transferred until Phase 8 attaches declared borrow/move attributes to
  the foreign boundary). Fresh aggregate literals (list/set/dict),
  comprehensions, and fresh string buffers (f-strings, multi-part
  multistrings) are OWNED.

- BORROWED: reads through an existing owner - names and attribute /
  index loads. The owner (local, field, container) holds the reference;
  the reader must retain before storing the value anywhere that
  outlives the owner.

- STATIC: immortal literals (string constants and single-part
  multistrings); never retained or released.

- UNKNOWN: forms whose result ownership is decided by backend emission
  mechanics rather than expression shape (operator results, coercion /
  boxing temporaries the emitter materializes). Backends own the
  bookkeeping for these, driven by the classification of their source
  expressions.
"""
import jaclang.jac0core.unitree as uni;
import from enum { Enum }

enum Ownership {
    OWNED = "owned",
    BORROWED = "borrowed",
    STATIC = "static",
    UNKNOWN = "unknown"
}

"""True when a parameter symbol is rebound by a plain assignment in its
function body.

A parameter arrives BORROWED (the caller owns the value). When the body
rebinds it with a plain `param = expr` assignment, the slot must own its
contents so each overwrite can release the previous occupant without
double-freeing the caller's reference - which requires taking one +1 on
the incoming value at function entry. This predicate is that analysis
fact. Aug-assignments (in-place mutations), walrus bindings, loop
targets, and unpacking bindings keep the borrow, exactly matching the
plain-assignment-only promotion the backend previously decided lazily.
"""
def param_plainly_rebound(sym: (uni.Symbol | None)) -> bool {
    if sym is None {
        return False;
    }
    # A rebinding of an existing symbol registers on `uses` (the symbol
    # table reserves `defn` for declarations), so scan both lists; being a
    # direct member of an Assignment's target list is what distinguishes a
    # plain rebinding from a read (and from unpacking, whose names sit
    # inside a Tuple/List target rather than the target list itself).
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

"""Names first bound inside a loop body, in source order.

THE loop-exit release list (Phase 7): a local whose first binding sits
inside the body holds a fresh value each iteration, so the back edge
must release it (and null its slot) or a later early return leaks the
previous iteration's value. A name is a first binding exactly when it
IS its symbol's first definition entry; names bound before the loop and
merely reassigned inside keep their assignment-site release discipline
and are not listed. Backends apply their own representation filters
(pointer-typed slots only) when consuming the list.
"""
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

"""Classify an expression's result ownership (see module docstring).

Pure function of expression shape: SetCompr/GenCompr are covered by the
ListCompr arm through inheritance.
"""
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
