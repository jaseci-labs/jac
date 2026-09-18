import from jaclang.compiler.frontend.roles { Kid }
import from jaclang.compiler.passes.context { CompileContext }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    CodeBlockStmt,
    FuncCall,
    ImplDef,
    Module,
    ModuleCode,
    Name,
    NameAtom,
    OpenStmt,
    Symbol,
    Test,
    UniNode
}

walker RegionInferPass {
    has ctx: CompileContext,
        module: Module,
        _use_index: (dict[int, list[NameAtom]] | None) = None;

    can run_walk with Module entry;
    def _run_impl(ir_in: Module) -> Module;
    def _sym_of(nm: NameAtom) -> (Symbol | None);
    def _uses_of(sym: Symbol) -> list[NameAtom];
    def _scan_block(body: Sequence[UniNode]) -> list[tuple[int, int]];
    def _arch_of_call(expr: (UniNode | None)) -> (Archetype | None);
    def _connect_chain_leaves(expr: UniNode) -> (list[Name] | None);
    def _blessed_arch_call(fc: FuncCall, member_sids: set[int]) -> bool;
    def _extent_poisoned(
        body: Sequence[UniNode], open_idx: int, close_idx: int, member_sids: set[int]
    ) -> bool;

    def _is_def_name(nm: NameAtom) -> bool;
    def _wrap_in_open(
        owner: (Ability | ModuleCode | ImplDef | Test),
        body: Sequence[UniNode],
        open_idx: int,
        close_idx: int
    ) -> (OpenStmt | None);
}
