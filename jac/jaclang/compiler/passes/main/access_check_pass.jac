import os;
import from jaclang.jac0core.unitree {
    Archetype,
    AstSymbolNode,
    AtomTrailer,
    Module,
    Name,
    Symbol,
    UniNode
}
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.constant { SymbolAccess }
import from jaclang.jac0core.diagnostics {
    E2034,
    W2034,
    E2035,
    W2035,
    E2037,
    W2037,
    E2038,
    W2038
}

obj AccessCheckPass(Transform) {
    has ir_in: Module,
        cancel_token: any = None,
        _enforce: bool = False;

    static has PROVIDES: tuple = ('access-checks', );

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _check_use(use_node: AstSymbolNode, sym: Symbol) -> None;
    def _check_member(use_node: AstSymbolNode, sym: Symbol, owner: Archetype) -> None;
    def _declaring_archetype(sym: Symbol) -> (Archetype | None);
    def _base_archetype(expr: UniNode) -> (Archetype | None);
    def _is_subclass_of(child: Archetype, ancestor: Archetype) -> bool;
}
