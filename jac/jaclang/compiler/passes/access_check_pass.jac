import os;

walker AccessCheckPass {
    has ctx: CompileContext,
        module: Module,
        _enforce: bool = False,
        _bridged_syms: set[int] = set(),
        _bridged_mods: set[str] = set();

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
    def _is_subclass_of(child: Archetype, ancestor: Archetype) -> bool;
}
