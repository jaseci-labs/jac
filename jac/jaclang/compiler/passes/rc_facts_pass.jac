import from typing { TypeAlias }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Assignment,
    AtomTrailer,
    BinaryExpr,
    BoolExpr,
    CompareExpr,
    DictCompr,
    DictVal,
    Expr,
    FString,
    FuncCall,
    FuncSignature,
    IfElseExpr,
    IfStmt,
    InForStmt,
    IterForStmt,
    KWPair,
    LambdaExpr,
    ListCompr,
    ListVal,
    Module,
    ModuleCode,
    MultiString,
    Name,
    NameAtom,
    ParamVar,
    ReturnStmt,
    SetVal,
    String,
    Symbol,
    Test,
    UnaryExpr,
    UniCFGNode,
    UniNode,
    WhileStmt
}
import from jaclang.compiler.passes.dataflow { solve_backward_gen_kill }
import from jaclang.compiler.frontend.constant {
    OwnershipKind,
    SymbolStorage,
    is_borrow_kind
}
import from jaclang.compiler.passes.transform { Transform }

glob SymId: TypeAlias = int;

enum Ownership {
    OWNED = "owned",
    BORROWED = "borrowed",
    STATIC = "static",
    UNKNOWN = "unknown"
}

def result_ownership(expr: (Expr | None)) -> Ownership {
    if expr is None {
        return Ownership.UNKNOWN;
    }
    if isinstance(expr, FuncCall) {
        return Ownership.OWNED;
    }
    if isinstance(expr, (ListVal, SetVal, DictVal, ListCompr, DictCompr)) {
        return Ownership.OWNED;
    }
    if isinstance(expr, FString) {
        return Ownership.OWNED;
    }
    if isinstance(expr, MultiString) {
        if len(expr.strings) == 1 and not isinstance(expr.strings[0], FString) {
            return Ownership.STATIC;
        }
        return Ownership.OWNED;
    }
    if isinstance(expr, String) {
        return Ownership.STATIC;
    }
    if isinstance(expr, (Name, AtomTrailer)) {
        return Ownership.BORROWED;
    }
    return Ownership.UNKNOWN;
}

def loop_body_locals(body: (Sequence[UniNode] | None)) -> list[str] {
    out: list[str] = [];
    seen: set[str] = set();
    if not body {
        return out;
    }
    for stmt in body {
        for nm in stmt.get_all_sub_nodes(typ=Name) {
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

walker RcFactsPass(Transform) {
    has ir_in: Module,
        cancel_token: any = None,
        _node_use: dict[int, set[SymId]] = {},
        _node_def: dict[int, set[SymId]] = {};

    static has PROVIDES: tuple = ('rc-facts', ),
        REQUIRES: tuple = ('CfgSucc', );

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _stamp_param_rebound(ir_in: Module) -> None;
    def _stamp_escapes(ir_in: Module) -> None;
    def _call_use_stack_safe(nm: NameAtom, sym: Symbol) -> bool;
    def _borrow_arg_callee_ok(bx: UnaryExpr) -> bool;
    def _scalar_attr_read(nm: NameAtom) -> bool;
    def _stamp_region_handles(ir_in: Module) -> None;
    def _asn_makes_region_handle(nd: Assignment) -> bool;
    def _use_ok_for_stack(nm: NameAtom) -> bool;
    def _enclosing_fn_scope(nd: UniNode) -> (UniNode | None);
    def _is_param_sym(sym: Symbol) -> bool;
    def _last_use_tracked(sym: Symbol) -> bool;
    def _stamp_last_use(ir_in: Module) -> None;
    def _stamp_move_in(ir_in: Module) -> None;
    def _collect_last_use(
        owner: UniNode, body: Sequence[UniNode], out: dict[int, list[str]]
    ) -> None;

    def _param_plainly_rebound(sym: Symbol) -> bool;
    def _stamp_move_lowerable(ir_in: Module) -> None;
    def _cfg_owner(sub: UniNode) -> (UniCFGNode | None);
    def _is_def_name(nm: NameAtom) -> bool;
    def _is_alias_value(nm: Name) -> bool;
    def _move_candidate_source(nd: Assignment) -> (Name | None);
    def _solve_liveness(
        cfg_nodes: list[UniCFGNode], tracked: set[SymId]
    ) -> dict[int, set[SymId]];
}
