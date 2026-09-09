import os;
import from jaclang.compiler.frontend.unitree {
    Archetype,
    AstSymbolNode,
    AtomTrailer,
    Import,
    Module,
    ModuleItem,
    ModulePath,
    Name,
    Symbol,
    UniNode
}
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.frontend.constant { SymbolAccess }
import from jaclang.compiler.frontend.diagnostics {
    E2034,
    W2034,
    E2035,
    W2035,
    E2037,
    W2037,
    E2038,
    W2038,
    E2039,
    W2039,
    E2040,
    W2040
}

walker AccessCheckPass(Transform) {
    has ir_in: Module,
        cancel_token: any = None,
        _enforce: bool = False,
        _bridged_syms: set[int] = set(),
        _bridged_mods: set[str] = set();

    static has PROVIDES: tuple = ('access-checks', );

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _collect_bridged_imports(ir_in: Module) -> None;
    def _check_use(use_node: AstSymbolNode, sym: Symbol) -> None;
    def _module_app_facts(mod: Module) -> tuple[(str | None), (str | None)];
    def _check_app_laws(
        use_node: AstSymbolNode, sym: Symbol, def_module: Module
    ) -> bool;

    def _check_member(use_node: AstSymbolNode, sym: Symbol, owner: Archetype) -> None;
    def _declaring_archetype(sym: Symbol) -> (Archetype | None);
    def _declaring_module(sym: Symbol) -> (Module | None);
    def _base_archetype(expr: UniNode) -> (Archetype | None);
    def _is_subclass_of(child: Archetype, ancestor: Archetype) -> bool;
}
