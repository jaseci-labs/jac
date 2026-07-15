import from collections.abc { Sequence }
import from typing { TypeAlias }
import jaclang.jac0core.unitree as uni;
import jaclang.compiler.passes.main.dataflow as dataflow;
import from jaclang.jac0core.constant { OwnershipKind, SymbolStorage, is_borrow_kind }
import from jaclang.jac0core.passes.transform { Transform }

glob SymId: TypeAlias = int;

enum Ownership {
    OWNED = "owned",
    BORROWED = "borrowed",
    STATIC = "static",
    UNKNOWN = "unknown"
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

def loop_body_locals(body: (Sequence[uni.UniNode] | None)) -> list[str] {
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

obj RcFactsPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None,
        _node_use: dict[int, set[SymId]] = {},
        _node_def: dict[int, set[SymId]] = {};

    static has PROVIDES: tuple = ('rc-facts', ),
        REQUIRES: tuple = ('cfg', );

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _stamp_param_rebound(ir_in: uni.Module) -> None;
    def _stamp_escapes(ir_in: uni.Module) -> None;
    def _use_ok_for_stack(nm: uni.NameAtom) -> bool;
    def _enclosing_fn_scope(nd: uni.UniNode) -> (uni.UniNode | None);
    def _is_param_sym(sym: uni.Symbol) -> bool;
    def _stamp_last_use(ir_in: uni.Module) -> None;
    def _collect_last_use(
        owner: uni.UniNode, body: Sequence[uni.UniNode], out: dict[int, list[str]]
    ) -> None;

    def _param_plainly_rebound(sym: uni.Symbol) -> bool;
    def _stamp_move_lowerable(ir_in: uni.Module) -> None;
    def _cfg_owner(sub: uni.UniNode) -> (uni.UniCFGNode | None);
    def _is_def_name(nm: uni.Name) -> bool;
    def _is_alias_value(nm: uni.Name) -> bool;
    def _move_candidate_source(nd: uni.Assignment) -> (uni.Name | None);
    def _live_transfer(nd: uni.UniCFGNode, out_set: set[SymId]) -> set[SymId];
    def _solve_liveness(
        cfg_nodes: list[uni.UniCFGNode], tracked: set[SymId]
    ) -> dict[int, set[SymId]];
}
