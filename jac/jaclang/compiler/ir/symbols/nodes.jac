import from jaclang.compiler.ir.identity { RelationFamily }
import from jaclang.compiler.ir.identity { GraphNode }
import from jaclang.compiler.ir.ownership.facts { SymbolMemory }
import type from jaclang.compiler.ir.syntax.nodes { ImplDef }
import type from collections.abc { Sequence }
import from jaclang.compiler.ir.enums {
    BindingKind,
    ExprCtx,
    OwnershipKind,
    SymbolAccess,
    SymbolStorage,
    SymbolType
}
import type from jaclang.compiler.ir.types.nodes { TypeBase }

import from jaclang.compiler.ir.base { UniNode }
import type from jaclang.compiler.ir.syntax.nodes {
    Ability,
    Archetype,
    AstAccessNode,
    Enum,
    ImplDef,
    LambdaExpr,
    Module,
    NameAtom,
    Test
}

obj SymbolProvider {
    def resolve_type(symbol: Symbol) -> TypeBase abst;
    def definition -> Symbol | None abst;
    def property_kind -> int abst;
    def property_write_kind -> int abst;
    def property_write_type -> TypeBase | None abst;
}

node Symbol(GraphNode) {
    has memory: SymbolMemory = SymbolMemory(),
        name: str postinit,
        access: SymbolAccess postinit,
        imported: bool postinit,
        semstr: str postinit,
        ownership: OwnershipKind = OwnershipKind.NONE,
        linear: bool = False,
        is_view: bool = False,
        _in_stub_scope: (bool | None) = None,
        _binding_kind: (BindingKind | None) = None,
        provider: SymbolProvider | None = None;

    def init(
        defn: NameAtom,
        access: SymbolAccess,
        parent_tab: (UniScopeNode | None) = None,
        imported: bool = False
    ) -> None;

    has defn: list[NameAtom] { getter; }
    has uses: list[NameAtom] { getter; }
    has parent_tab: (UniScopeNode | None) { getter; }
    has decl: NameAtom { getter; }
    has sym_name: str { getter; }
    has sym_type: SymbolType { getter; }
    has sym_dotted_name: str { getter; }
    has symbol_table: (UniScopeNode | None) { getter; }
    has storage: SymbolStorage = SymbolStorage.MODULE_GLOBAL,
        binding_fact: BindingKind = BindingKind.VALUE;

    has binding_kind: BindingKind { getter; setter(binding_kind: BindingKind); }

    def add_defn(nd: NameAtom) -> None;
    def add_use(nd: NameAtom) -> None;
    def in_stub_scope -> bool;
    def __repr__ -> str;
}

node UniScopeNode(UniNode) {
    has capture_symbols: list[Symbol] = [],
        declaration_symbol: Symbol | None = None,
        scope_name: str postinit,
        implicit_rebinds: dict[(str, Symbol)] postinit,
        primary_revision: int = 0,
        overload_revision: int = 0,
        _names_generation: int = -1,
        _overload_generation: int = -1,
        _names_index: dict[(str, Symbol)] | None postinit,
        _overload_index: dict[(str, list[Symbol])] | None postinit;

    has parent_scope: (UniScopeNode | None) {
        getter;
        setter(parent_scope: (UniScopeNode | None));
    }

    has kid_scope: list[UniScopeNode] { getter; }
    has names_in_scope: dict[(str, Symbol)] { getter; }
    has names_in_scope_overload: dict[(str, list[Symbol])] { getter; }

    def _init_scope(name: str, parent_scope: (UniScopeNode | None) = None) -> None;
    static def is_python_scoping(nd: (UniNode | None)) -> bool {
        import from jaclang.compiler.ir.syntax.nodes {
            Ability,
            Archetype,
            Enum,
            ImplDef,
            LambdaExpr,
            Module,
            Test
        }

        return isinstance(
            nd, (Module, Enum, Archetype, Ability, ImplDef, Test, LambdaExpr)
        );
    }

    def lookup(
        name: str, deep: bool = True, incl_inner_scope: bool = False
    ) -> (Symbol | None);

    def lookup_all(name: str, deep: bool = True) -> list[Symbol];
    def insert(
        nd: AstSymbolNode,
        access_spec: AstAccessNode | None | SymbolAccess = None,
        single: bool = False,
        force_overwrite: bool = False,
        imported: bool = False
    ) -> (UniNode | None);

    def find_scope(name: str) -> (UniScopeNode | None);
    def set_primary_names(syms: dict[(str, Symbol)]) -> None;
    def adopt_primary(sym: Symbol, alias: str = "") -> None;
    def _drop_primary(key: str) -> None;
    def adopt_overload(sym: Symbol, alias: str = "") -> None;
    def link_kid_scope(key_node: UniScopeNode) -> UniScopeNode;
    def __repr__ -> str;
    def init(*, kid: Sequence[UniNode] = []) -> None;
}

node AstSymbolNode(UniNode) {
    has name_spec: NameAtom postinit,
        semstr: str postinit;

    def _init_symbol(
        sym_name: str, name_spec: NameAtom, sym_category: SymbolType
    ) -> None;

    has sym: (Symbol | None) { getter; }
    has sym_name: str { getter; }
    has sym_category: SymbolType { getter; }
    has expr_ctx: ExprCtx { getter; }
    has type_sym_tab: (UniScopeNode | None) { getter; }

    def init(*, kid: Sequence[UniNode] = []) -> None;
    def __repr__ -> str;
}

node AstSymbolStubNode(AstSymbolNode) {
    def _init_stub(sym_type: SymbolType) -> None;
    def init(*, kid: Sequence[UniNode] = []) -> None;
    def __repr__ -> str;
}

node AstImplNeedingNode(AstSymbolNode) {
    def link_impl(impl_node: ImplDef) -> None;

    has body: (Sequence[UniNode] | UniNode | None) { getter; }
    has needs_impl: bool { getter; }

    def init(
        *, body: (Sequence[UniNode] | UniNode | None), kid: Sequence[UniNode] = []
    ) -> None;

    def __repr__ -> str;
}

node ScopeBinding(GraphNode) {
    has spelling: str;
    has symbol: Symbol { getter; }

    static def create(spelling: str, symbol: Symbol) -> ScopeBinding {
        import from jaclang.compiler.ir.symbols.edges { BindingTarget }
        binding = ScopeBinding(spelling=spelling);
        binding +>:BindingTarget:+> symbol;
        return binding;
    }
}
