import os;
import type from collections.abc { Sequence }
import type from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
import from jaclang.compiler.frontend.srcloc { CodeLocInfo }
import from jaclang.compiler.frontend.constant {
    BUILTIN_CALLABLE_NAMES,
    DELIM_MAP,
    BindingKind,
    CodeContext,
    EdgeDir,
    ExprCtx,
    OwnershipKind,
    SymbolAccess,
    SymbolStorage,
    SymbolType
}
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.compiler.frontend.constant { JacSemTokenModifier as SemTokMod }
import from jaclang.compiler.frontend.constant { JacSemTokenType as SemTokType }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.frontend.constant { ParamKind }
import type from jaclang.compiler.types.types { TypeBase }
import from jaclang.compiler.frontend.roles {
    Role,
    Kid,
    ImplOf,
    AccessRole,
    AccessorsRole,
    AliasRole,
    ArchTagInfoRole,
    ArchTypeRole,
    ArgPatternsRole,
    AssignmentsRole,
    AssignsRole,
    AttributesRole,
    AugOpRole,
    AwaitingBodyRole,
    BaseClassesRole,
    BodyRole,
    BoundRole,
    CasesRole,
    CastTypeRole,
    CauseRole,
    ChainRole,
    ChildrenRole,
    ClibDeclsRole,
    CodeRole,
    CollectionRole,
    ComparesRole,
    ComprRole,
    ConditionRole,
    ConditionalRole,
    ConnAssignRole,
    ConnTypeRole,
    CountByRole,
    CtrlRole,
    DecoratorsRole,
    DefaultValRole,
    DescriptionRole,
    DocRole,
    DynamicTagRole,
    EdgeSpecRole,
    ElseBodyRole,
    ElseValueRole,
    EndRole,
    ErrorMsgRole,
    EventRole,
    ExTypeRole,
    ExceptsRole,
    ExprRole,
    ExprsRole,
    FTypeRole,
    FilterCondRole,
    FinallyBodyRole,
    FormatPartRole,
    FormatSpecRole,
    FromLocRole,
    FromTargetRole,
    GuardRole,
    HintRole,
    InsertLocRole,
    ItemsRole,
    IterRole,
    KeyRole,
    KeywordsRole,
    KvPairRole,
    KvPairsRole,
    KwPatternsRole,
    KwargsRole,
    KwonlyargsRole,
    LeftRole,
    MainRole,
    NameRole,
    NameRefRole,
    OpRole,
    OperandRole,
    OpsRole,
    OutExprRole,
    ParamsRole,
    PartsRole,
    PathRole,
    PatternRole,
    PatternsRole,
    PosonlyParamsRole,
    ReturnTypeRole,
    RightRole,
    RightsRole,
    SignatureRole,
    SlicesRole,
    SpecRole,
    SrcEndpointRole,
    StartRole,
    StepRole,
    StopRole,
    StringsRole,
    TargetRole,
    TgtEndpointRole,
    TokRole,
    TypeCtxRole,
    TypeParamsRole,
    TypeTagRole,
    UnpackRole,
    ValueRole,
    ValueTypeRole,
    ValuesRole,
    VarargsRole,
    VarsRole
}
import from jaclang.compiler.frontend.relations {
    Absorbs,
    CalleeDecl,
    EventTriggerOf,
    NarrowedTypeOf,
    TypeOf,
    CfgFalse,
    CfgSucc,
    CfgTrue,
    DecidedCodespace,
    Defines,
    InScope,
    PlacedIn,
    ScopeChild,
    ScopeParent,
    ScopeOverload,
    ScopePrimary,
    SymOf,
    Uses,
    codespace_node
}


walker TreeWalker {}

node UniNode {
    has _ctx_parent: (UniNode | None) postinit,
        _struct_frozen: bool postinit,
        _in_mod_nodes: list[UniNode] postinit,
        _gen: (CodeGenTarget | None) postinit,
        loc: CodeLocInfo postinit,
        _role_shapes: (dict[type, str] | None) postinit,
        __sub_node_tab: (dict[(type, list[UniNode])] | None) postinit,
        ct_pruned: bool postinit;

    def postinit -> None;
    can walk_kids with TreeWalker entry;

    has kid: list[UniNode] { getter; }
    has parent: (UniNode | None) { getter; }
    has gen: CodeGenTarget { getter; setter(value: CodeGenTarget); }
    has _sub_node_tab: dict[(type, list[UniNode])] { getter; }

    def _link(kid: Sequence[UniNode], roles: dict[type, any]) -> None;
    def detached_copy -> UniNode;
    def __deepcopy__(memo: dict) -> UniNode;
    def _assert_thawed -> None;
    def freeze_structure -> None;
    def thaw_structure -> None;
    def structure_thawed -> StructureThaw;
    def _attach(child: UniNode, role: type[Role]) -> None;
    def _role_clear(role: type[Role]) -> None;
    def _as_node_list(value: any) -> list[UniNode];
    def _children -> list[UniNode];
    def _role_shaped(role: type[Role], found: list[UniNode]) -> any;
    def _role_set(role: type[Role], value: any) -> None;
    def link_impl(impl_node: UniNode) -> None;
    def _construct_sub_node_tab -> None;
    def _invalidate_sub_node_tab -> None;

    has sym_tab: UniScopeNode { getter; }

    def add_kids_left(
        nodes: Sequence[UniNode],
        pos_update: bool = True,
        parent_update: bool = False,
        role: (type[Role] | None) = None
    ) -> UniNode;

    def add_kids_right(
        nodes: Sequence[UniNode],
        pos_update: bool = True,
        parent_update: bool = False,
        role: (type[Role] | None) = None
    ) -> UniNode;

    def insert_kids_at_pos(
        nodes: Sequence[UniNode],
        pos: int,
        pos_update: bool = True,
        role: (type[Role] | None) = None
    ) -> UniNode;

    def set_kids(nodes: Sequence[UniNode], pos_update: bool = True) -> UniNode;
    def replace_kid(old: UniNode, new: UniNode) -> UniNode;
    def set_parent(parent: UniNode) -> UniNode;
    def resolve_tok_range -> tuple[(Token, Token)];
    def gen_token(name: Tok, value: (str | None) = None) -> Token;
    def get_all_sub_nodes[T](typ: type[T]) -> list[T] {
        result: list[T] = [];
        if typ in self._sub_node_tab {
            for i in self._sub_node_tab[typ] {
                if isinstance(i, typ) {
                    result.append(i);
                }
            }
        }
        return result;
    }

    def find_parent_of_type[T](typ: type[T]) -> (T | None) {
        nd: (UniNode | None) = self.parent;
        while nd is not None {
            if isinstance(nd, typ) {
                return nd;
            }
            nd = nd.parent;
        }
        return None;
    }

    def parent_of_type[T](typ: type[T]) -> T {
        ret = self.find_parent_of_type(typ);
        if isinstance(ret, typ) {
            return ret;
        }
        raise ValueError(f"Parent of type {typ} not found from{type(self)}.");
    }

    def codespace -> CodeContext;
    def in_client_context -> bool;
    def in_native_context -> bool;
    def flatten -> list[UniNode];
    def __repr__ -> str;
}

node Symbol {
    has name: str postinit,
        access: SymbolAccess postinit,
        imported: bool postinit,
        semstr: str postinit,
        ownership: OwnershipKind = OwnershipKind.NONE,
        param_rebound: bool = False,
        na_escapes: bool = False,
        na_region_handle: bool = False,
        na_stack_ok: bool = False,
        _in_stub_scope: (bool | None) = None,
        _binding_kind: (BindingKind | None) = None,
        provider: any = None;

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
    has storage: SymbolStorage { getter; }
    has binding_kind: BindingKind { getter; setter(binding_kind: BindingKind); }

    def add_defn(nd: NameAtom) -> None;
    def add_use(nd: NameAtom) -> None;
    def in_stub_scope -> bool;
    def __repr__ -> str;
}

obj StructureThaw {
    has target: UniNode,
        refreeze: bool = False;

    def __enter__ -> StructureThaw;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
}

node UniScopeNode(UniNode) {
    has scope_name: str postinit,
        implicit_rebinds: dict[(str, Symbol)] postinit,
        _names_index: dict[(str, Symbol)] postinit,
        _overload_index: dict[(str, list[Symbol])] postinit;

    has parent_scope: (UniScopeNode | None) {
        getter;
        setter(parent_scope: (UniScopeNode | None));
    }

    has kid_scope: list[UniScopeNode] { getter; }
    has names_in_scope: dict[(str, Symbol)] { getter; }
    has names_in_scope_overload: dict[(str, list[Symbol])] { getter; }

    def _init_scope(name: str, parent_scope: (UniScopeNode | None) = None) -> None;
    static def is_python_scoping(nd: (UniNode | None)) -> bool {
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
    def _drop_primary(sym: Symbol) -> None;
    def get_enclosing_captures -> list[Symbol];
    def link_kid_scope(key_node: UniScopeNode) -> UniScopeNode;
    def def_insert(
        nd: AstSymbolNode,
        access_spec: AstAccessNode | None | SymbolAccess = None,
        single_decl: (str | None) = None,
        force_overwrite: bool = False,
        imported: bool = False
    ) -> (Symbol | None);

    def chain_def_insert(node_list: list[AstSymbolNode]) -> None;
    def use_lookup(
        nd: AstSymbolNode, sym_table: (UniScopeNode | None) = None
    ) -> (Symbol | None);

    def chain_use_lookup(node_list: Sequence[AstSymbolNode]) -> None;
    def update_expr_ctx_for_def(nd: AstSymbolNode) -> None;
    def _fix_store_ctx(item: UniNode) -> None;
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

node AstAccessNode(UniNode) {
    has access: (SubTag[Token] | None) { getter; }
    has access_type: SymbolAccess { getter; }
    has public_access: bool { getter; }

    def init(
        *, access: (SubTag[Token] | None) = None, kid: Sequence[UniNode] = []
    ) -> None;

    def __repr__ -> str;
}

node ContextAwareNode(UniNode) {
    has codespace_dual: bool = False;
    has code_context: CodeContext { getter; setter(code_context: CodeContext); }

    def init(*, codespace_dual: bool = False, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node AstDocNode(UniNode) {
    has doc: (String | None) { getter; }

    def set_doc(elem_doc: (String | None)) -> None;
    def init(*, doc: (String | None) = None, kid: Sequence[UniNode] = []) -> None;
    def __repr__ -> str;
}

node AstAsyncNode(UniNode) {
    has is_async: bool = False;

    def init(*, is_async: bool = False, kid: Sequence[UniNode] = []) -> None;
    def __repr__ -> str;
}

node AstElseBodyNode(UniNode) {
    has else_body: (ElseStmt | ElseIf | None) { getter; }

    def init(
        *, else_body: (ElseStmt | ElseIf | None) = None, kid: Sequence[UniNode] = []
    ) -> None;

    def __repr__ -> str;
}

node AstTypedVarNode(UniNode) {
    has type: (TypeBase | None) { getter; setter(type: (TypeBase | None)); }
    has type_tag: (SubTag[Expr] | None) { getter; }

    def init(
        *,
        type_tag: (SubTag[Expr] | None) = None,
        type: (TypeBase | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def __repr__ -> str;
}

node WalkerStmtOnlyNode(UniNode) {
    has from_walker: bool postinit;

    def init(*, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node UniCFGNode(UniNode) {
    has affected_symbols: set[str] postinit;
    has bb_in: list[UniCFGNode] { getter; }
    has bb_out: list[UniCFGNode] { getter; }

    def cfg_link(target: UniCFGNode) -> None;
    def init(*, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def get_head -> UniCFGNode;
    def get_tail -> UniCFGNode;
    def __repr__ -> str;
}

node ConditionalNode(UniCFGNode) {
    has sc_true_target: (UniCFGNode | None) {
        getter;
        setter(sc_true_target: (UniCFGNode | None));
    }

    has sc_false_target: (UniCFGNode | None) {
        getter;
        setter(sc_false_target: (UniCFGNode | None));
    }

    def init(
        *,
        sc_true_target: (UniCFGNode | None) = None,
        sc_false_target: (UniCFGNode | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node Expr(UniNode) {
    has type: (TypeBase | None) { getter; setter(type: (TypeBase | None)); }
    has narrowed_type: (TypeBase | None) {
        getter;
        setter(narrowed_type: (TypeBase | None));
    }

    has _type_sym_tab: (UniScopeNode | None) postinit,
        _type_cache: (TypeBase | None) postinit,
        _type_cache_ok: bool postinit,
        ct_value: any postinit,
        coerce_to: (str | None) postinit,
        fw: (str | None) postinit,
        fw_safe: bool postinit,
        attached_tokens: (list[Token] | None) postinit;

    def init(*, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;

    has type_sym_tab: (UniScopeNode | None) {
        getter;
        setter(type_sym_tab: UniScopeNode);
    }

    def __repr__ -> str;
}

node CfgExpr(Expr, ConditionalNode) {
    has expr: Expr { getter; }

    def init(
        *,
        sc_true_target: (UniCFGNode | None) = None,
        sc_false_target: (UniCFGNode | None) = None,
        expr: Expr,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node AtomExpr(Expr, AstSymbolStubNode) {}

node ElementStmt(AstDocNode) {}

node ArchBlockStmt(UniNode) {}

node EnumBlockStmt(UniNode) {
    has is_enum_stmt: bool = False;

    def init(*, is_enum_stmt: bool = False, kid: Sequence[UniNode] = []) -> None;
    def __repr__ -> str;
}

node CodeBlockStmt(UniCFGNode) {
    def init(*, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node AstImplNeedingNode(AstSymbolNode) {
    has body: (Sequence[UniNode] | UniNode | None) { getter; }
    has needs_impl: bool { getter; }

    def init(
        *, body: (Sequence[UniNode] | UniNode | None), kid: Sequence[UniNode] = []
    ) -> None;

    def __repr__ -> str;
}

node NameAtom(AtomExpr, EnumBlockStmt) {
    has name_of: AstSymbolNode postinit,
        _sym_name: str postinit,
        _sym_category: SymbolType postinit,
        _expr_ctx: ExprCtx postinit,
        is_getattr_resolved: bool = False;

    def init(
        *,
        is_enum_stmt: bool = False,
        is_getattr_resolved: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;

    has sym: (Symbol | None) { getter; setter(sym: Symbol); }
    has sym_name: str { getter; }
    has sym_category: SymbolType { getter; }

    def bind_sym(
        name_of: AstSymbolNode, sym_name: str, sym_category: SymbolType
    ) -> None;

    def create_symbol(
        access: SymbolAccess,
        parent_tab: (UniScopeNode | None) = None,
        imported: bool = False
    ) -> Symbol;

    has clean_type: str { getter; }
    has expr_ctx: ExprCtx { getter; setter(expr_ctx: ExprCtx); }
    has sem_token: (tuple[(SemTokType, SemTokMod)] | None) { getter; }

    def __repr__ -> str;
}

node ArchSpec(ElementStmt, CodeBlockStmt, AstSymbolNode, AstAsyncNode, AstDocNode) {
    has decorators: (Sequence[Expr] | None) { getter; }

    def init(
        *,
        doc: (String | None) = None,
        is_async: bool = False,
        decorators: (Sequence[Expr] | None),
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node MatchPattern(UniNode) {}

node SubTag[T](UniNode) {
    has tag: T,
        ownership: OwnershipKind = OwnershipKind.NONE;

    def init(
        *,
        tag: T,
        ownership: OwnershipKind = OwnershipKind.NONE,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node Module(AstDocNode, UniScopeNode) {
    has name: str,
        source: Source,
        terminals: list[Token],
        stub_only: bool = False,
        src_terminals: list[Token] = [],
        is_raised_from_py: bool = False,
        parse_failed: bool = False,
        mobui_enforced_root: (str | None) = None,
        jac_project_root: (str | None) = None,
        access_enforced: bool = False,
        app: (str | None) = None,
        app_root: (str | None) = None,
        app_kind: str = "",
        owner_app: (str | None) = None,
        ct_resolved: bool = False,
        ct_file_deps: list[str] postinit,
        ct_body_deps: list[str] postinit,
        native_viols_reported: bool = False,
        client_viols_reported: bool = False,
        rc_last_use: dict[int, list[str]] postinit,
        rc_move_in: set[int] postinit,
        own_move_sites: set[int] postinit;

    has body: Sequence[ElementStmt | String | EmptyToken] { getter; }

    def init(
        *,
        doc: (String | None) = None,
        name: str,
        source: Source,
        body: Sequence[ElementStmt | String | EmptyToken],
        terminals: list[Token],
        stub_only: bool = False,
        src_terminals: list[Token] = [],
        is_raised_from_py: bool = False,
        parse_failed: bool = False,
        mobui_enforced_root: (str | None) = None,
        jac_project_root: (str | None) = None,
        access_enforced: bool = False,
        ct_resolved: bool = False,
        native_viols_reported: bool = False,
        client_viols_reported: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    has decided_codespace: str { getter; setter(decided_codespace: str); }
    has codespace_inferred: bool = False;

    def postinit -> None;

    has annexable_by: (str | None) { getter; }

    def declares_codespace(ctx: CodeContext, path_hint: str = '') -> bool;
    def absorb_annex_body(stmts: Sequence[UniNode]) -> None;
    static def make_stub(
        inject_name: (str | None) = None, inject_src: (Source | None) = None
    ) -> Module {
        return Module(
            name=(inject_name or ''),
            source=(inject_src or Source('', '')),
            doc=None,
            body=[],
            terminals=[],
            stub_only=True,
            kid=[EmptyToken()]
        );
    }

    def __repr__ -> str;
}

node ProgramModule(UniNode) {
    has hub: dict[(str, Module)] postinit;
    has main_mod: (Module | None) { getter; setter(main_mod: (Module | None)); }
    has main: Module { getter; }

    def init(*, main_mod: (Module | None) = None, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node TypeParam(AstSymbolNode, UniNode) {
    has name: Name { getter; }
    has bound: (Expr | None) { getter; }
    has default_val: (Expr | None) { getter; }
    has is_comptime: bool = False;

    def init(
        *,
        name: Name,
        bound: (Expr | None),
        default_val: (Expr | None),
        is_comptime: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node TypeAlias(ContextAwareNode, AstAccessNode, ElementStmt, AstSymbolNode, UniScopeNode, CodeBlockStmt) {
    has is_distinct: bool = False;
    has name: Name { getter; }
    has type_params: (Sequence[TypeParam] | None) { getter; }
    has value: Expr { getter; }

    def init(
        *,
        doc: (String | None) = None,
        access: (SubTag[Token] | None) = None,
        codespace_dual: bool = False,
        name: Name,
        type_params: (Sequence[TypeParam] | None),
        value: Expr,
        is_distinct: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node GlobalVars(ContextAwareNode, ElementStmt, AstAccessNode, ArchBlockStmt, CodeBlockStmt) {
    has is_frozen: bool;
    has assignments: Sequence[Assignment] { getter; }

    def init(
        *,
        access: (SubTag[Token] | None) = None,
        doc: (String | None) = None,
        codespace_dual: bool = False,
        assignments: Sequence[Assignment],
        is_frozen: bool,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node Test(ContextAwareNode, AstSymbolNode, ElementStmt, CodeBlockStmt, UniScopeNode) {
    has name: Name { getter; }
    has body: Sequence[CodeBlockStmt] { getter; }
    has description: (String | None) { getter; }
    has decorators: (Sequence[Expr] | None) { getter; }

    def init(
        *,
        doc: (String | None) = None,
        codespace_dual: bool = False,
        name: Name,
        body: Sequence[CodeBlockStmt],
        description: (String | None) = None,
        decorators: (Sequence[Expr] | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node ModuleCode(ContextAwareNode, ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt) {
    has name: (Name | None) { getter; }
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(
        *,
        is_enum_stmt: bool = False,
        doc: (String | None) = None,
        codespace_dual: bool = False,
        name: (Name | None),
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node PyInlineCode(ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt) {
    has code: Token { getter; }

    def init(
        *,
        is_enum_stmt: bool = False,
        doc: (String | None) = None,
        code: Token,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

obj ImportBoundaryFacts {
    has native_from_path: (str | None) = None,
        from_loc_resolved: (str | None) = None,
        is_service: bool = False,
        pinned_server: bool = False,
        client_native_edge: bool = False,
        sv_abilities: dict[(str, Ability)] = {},
        sv_walkers: dict[(str, Archetype)] = {},
        na_target_decls: dict[(str, Ability)] = {},
        na_unmappable_targets: list[str] = [],
        native_absorb_path: (str | None) = None,
        native_item_paths: dict[(str, str)] = {},
        bridged_decls: dict[(str, Ability)] = {},
        cross_app_kind: str = "local";
}

node Import(ContextAwareNode, ElementStmt, CodeBlockStmt) {
    has is_absorb: bool,
        is_typed: bool = False,
        is_comptime: bool = False,
        jac_detected: (bool | None) postinit,
        boundary_facts: (ImportBoundaryFacts | None) postinit,
        native_only_drop: bool postinit;

    has from_loc: (ModulePath | None) { getter; }
    has items: Sequence[(ModuleItem | ModulePath)] { getter; }
    has clib_decls: (Sequence[UniNode] | None) { getter; }
    has hint: (SubTag[Token] | None) { getter; }

    def init(
        *,
        doc: (String | None) = None,
        codespace_dual: bool = False,
        from_loc: (ModulePath | None),
        items: Sequence[(ModuleItem | ModulePath)],
        is_absorb: bool,
        is_typed: bool = False,
        clib_decls: (Sequence[UniNode] | None) = None,
        is_comptime: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    has absorbed_mod: (Module | None) {
        getter;
        setter(absorbed_mod: (Module | None));
    }

    def postinit -> None;

    has is_jac: bool { getter; }
    has __jac_detected: bool { getter; }
    has has_string_path: bool { getter; }
    has has_clib_decls: bool { getter; }
    has is_service_import: bool { getter; }
    has is_virtual_jac: bool { getter; }
    has ecosystem: str { getter; }

    def __repr__ -> str;
}

node ModulePath(UniNode) {
    has level: int,
        abs_path: (str | None) postinit;

    has path: (Sequence[(Name | String)] | None) { getter; }
    has alias: (Name | None) { getter; }

    def init(
        *,
        path: (Sequence[(Name | String)] | None),
        level: int,
        alias: (Name | None),
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;

    has is_import_from: bool { getter; }
    has dot_path_str: str { getter; }
    has base_module_name: str { getter; }
    has string_path_value: (str | None) { getter; }

    def resolve_relative_path(target_item: (str | None) = None) -> str;
    def resolve_relative_path_list -> list[str];
    def native_bundled_path -> (str | None);
    def __repr__ -> str;
}

node ModuleItem(UniNode) {
    has abs_path: (str | None) postinit;
    has name: (Name | Token) { getter; }
    has alias: (Name | None) { getter; }

    def init(
        *, name: (Name | Token), alias: (Name | None), kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;

    has from_parent: Import { getter; }
    has from_mod_path: ModulePath { getter; }
    has binding_name: (Name | None) { getter; }

    def resolve_relative_path -> str;
    def __repr__ -> str;
}

node Archetype(ContextAwareNode, ArchSpec, AstAccessNode, ArchBlockStmt, AstImplNeedingNode, UniScopeNode, UniCFGNode) {
    has name: Name { getter; }
    has arch_type: Token { getter; }
    has base_classes: (Sequence[Expr] | None) { getter; }
    has keywords: (Sequence[KWPair] | None) { getter; }
    has type_params: (Sequence[TypeParam] | None) { getter; }
    has src_endpoint: (Expr | None) { getter; }
    has tgt_endpoint: (Expr | None) { getter; }

    def init(
        *,
        doc: (String | None) = None,
        is_async: bool = False,
        body: (Sequence[UniNode] | UniNode | None),
        access: (SubTag[Token] | None) = None,
        decorators: (Sequence[Expr] | None),
        codespace_dual: bool = False,
        name: Name,
        arch_type: Token,
        base_classes: (Sequence[Expr] | None),
        keywords: (Sequence[KWPair] | None) = None,
        type_params: (Sequence[TypeParam] | None) = None,
        src_endpoint: (Expr | None) = None,
        tgt_endpoint: (Expr | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def _get_impl_resolved_body -> list[UniNode];

    has is_abstract: bool { getter; }
    has arch_kind: (str | None) { getter; }

    def get_has_vars -> list[HasVar];
    def get_methods -> list[Ability];
    def __repr__ -> str;
}

node ImplDef(ContextAwareNode, CodeBlockStmt, ElementStmt, ArchBlockStmt, AstSymbolNode, UniScopeNode) {
    has decorators: (Sequence[Expr] | None) { getter; }
    has target: Sequence[NameAtom] { getter; }
    has spec: (Sequence[Expr] | FuncSignature | EventSignature | None) { getter; }
    has body: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr { getter; }
    has decl_link: (UniNode | None) { getter; }

    def init(
        *,
        doc: (String | None) = None,
        codespace_dual: bool = False,
        decorators: (Sequence[Expr] | None),
        target: Sequence[NameAtom],
        spec: (Sequence[Expr] | FuncSignature | EventSignature | None),
        body: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def create_impl_name_node -> Name;
    def __repr__ -> str;
}

node SemDef(ElementStmt, AstSymbolNode, UniScopeNode, CodeBlockStmt) {
    has target: Sequence[NameAtom] { getter; }
    has value: MultiString { getter; }

    def init(
        *,
        doc: (String | None) = None,
        target: Sequence[NameAtom],
        value: MultiString,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def create_sem_name_node -> Name;
    def __repr__ -> str;
}

node Enum(ContextAwareNode, ArchSpec, AstAccessNode, AstImplNeedingNode, ArchBlockStmt, UniScopeNode) {
    has name: Name { getter; }
    has value_type: (Expr | None) { getter; }
    has base_classes: (Sequence[Expr] | None) { getter; }

    def init(
        *,
        doc: (String | None) = None,
        is_async: bool = False,
        body: (Sequence[UniNode] | UniNode | None),
        access: (SubTag[Token] | None) = None,
        decorators: (Sequence[Expr] | None),
        codespace_dual: bool = False,
        name: Name,
        value_type: (Expr | None),
        base_classes: (Sequence[Expr] | None),
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node Ability(ContextAwareNode, AstAccessNode, ElementStmt, AstAsyncNode, ArchBlockStmt, CodeBlockStmt, AstImplNeedingNode, UniScopeNode) {
    has is_override: bool,
        is_static: bool,
        is_classmethod: bool,
        is_abstract: bool,
        accessor_kind: str = "",
        is_comptime: bool = False;

    has event_triggers: (list[TypeBase] | None) {
        getter;
        setter(event_triggers: (list[TypeBase] | None));
    }

    has name_ref: (NameAtom | None) { getter; }
    has signature: FuncSignature | EventSignature | None { getter; }
    has decorators: (Sequence[Expr] | None) { getter; }
    has type_params: (Sequence[TypeParam] | None) { getter; }

    def init(
        *,
        body: (Sequence[UniNode] | UniNode | None),
        is_async: bool = False,
        doc: (String | None) = None,
        access: (SubTag[Token] | None) = None,
        codespace_dual: bool = False,
        name_ref: (NameAtom | None),
        is_override: bool,
        is_static: bool,
        is_classmethod: bool,
        is_abstract: bool,
        signature: FuncSignature | EventSignature | None,
        decorators: (Sequence[Expr] | None) = None,
        type_params: (Sequence[TypeParam] | None) = None,
        accessor_kind: str = "",
        is_comptime: bool = False,
        event_triggers: (list[TypeBase] | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;

    has receiver_mode: OwnershipKind = OwnershipKind.NONE;
    has is_method: bool { getter; }
    has is_cls_method: bool { getter; }
    has is_def: bool { getter; }
    has method_owner: Archetype | Enum | None { getter; }
    has is_genai_ability: bool { getter; }

    def py_resolve_name -> str;
    def event_trigger_type_names -> (list[str] | None);
    def __repr__ -> str;
}

node FuncSignature(UniNode) {
    has posonly_params: Sequence[ParamVar] { getter; }
    has params: (Sequence[ParamVar] | None) { getter; }
    has varargs: (ParamVar | None) { getter; }
    has kwonlyargs: Sequence[ParamVar] { getter; }
    has kwargs: (ParamVar | None) { getter; }
    has return_type: (Expr | None) { getter; }

    def init(
        *,
        posonly_params: Sequence[ParamVar],
        params: (Sequence[ParamVar] | None),
        varargs: (ParamVar | None),
        kwonlyargs: Sequence[ParamVar],
        kwargs: (ParamVar | None),
        return_type: (Expr | None),
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def get_parameters -> list[ParamVar];

    has is_static: bool { getter; }
    has is_in_py_class: bool { getter; }

    def __repr__ -> str;
}

node EventSignature(WalkerStmtOnlyNode) {
    has event: Token { getter; }
    has arch_tag_info: (Expr | None) { getter; }

    def init(
        *, event: Token, arch_tag_info: (Expr | None), kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node ParamVar(AstSymbolNode, AstTypedVarNode) {
    has param_kind: ParamKind postinit,
        is_comptime: bool = False;

    has name: Name { getter; }
    has unpack: (Token | None) { getter; }
    has value: (Expr | None) { getter; }

    def init(
        *,
        type_tag: (SubTag[Expr] | None) = None,
        type: (TypeBase | None) = None,
        name: Name,
        unpack: (Token | None),
        value: (Expr | None),
        is_comptime: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;

    has is_vararg: bool { getter; }
    has is_kwargs: bool { getter; }

    def __repr__ -> str;
}

node ArchHas(AstAccessNode, AstDocNode, ArchBlockStmt, CodeBlockStmt) {
    has is_static: bool,
        is_frozen: bool;

    has vars: Sequence[HasVar] { getter; }

    def init(
        *,
        doc: (String | None) = None,
        access: (SubTag[Token] | None) = None,
        is_static: bool,
        vars: Sequence[HasVar],
        is_frozen: bool,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node HasVar(AstSymbolNode, AstTypedVarNode) {
    has defer: bool;
    has name: Name { getter; }
    has value: (Expr | None) { getter; }
    has accessors: (Sequence[Ability] | None) { getter; }

    def init(
        *,
        type_tag: (SubTag[Expr] | None) = None,
        type: (TypeBase | None) = None,
        name: Name,
        value: (Expr | None),
        defer: bool,
        accessors: (Sequence[Ability] | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node TypedCtxBlock(CodeBlockStmt, WalkerStmtOnlyNode, UniScopeNode) {
    has type_ctx: Expr { getter; }
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(
        *, type_ctx: Expr, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node OpenStmt(CodeBlockStmt, UniScopeNode) {
    has target: Expr { getter; }
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(
        *, target: Expr, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node IfStmt(CodeBlockStmt, AstElseBodyNode, UniScopeNode) {
    has is_comptime: bool = False,
        ct_taken: (bool | None) = None;

    has condition: Expr { getter; }
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(
        *,
        else_body: (ElseStmt | ElseIf | None) = None,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        is_comptime: bool = False,
        ct_taken: (bool | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node ElseIf(IfStmt) {
    def init(
        *,
        else_body: (ElseStmt | ElseIf | None) = None,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode] = []
    ) -> None;

    def __repr__ -> str;
}

node ElseStmt(UniScopeNode) {
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(*, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node ExprStmt(CodeBlockStmt) {
    has in_fstring: bool,
        has_semi: bool = True;

    has expr: Expr { getter; }

    def init(
        *,
        expr: Expr,
        in_fstring: bool,
        has_semi: bool = True,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node TryStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has body: Sequence[CodeBlockStmt] { getter; }
    has excepts: Sequence[Except] { getter; }
    has awaiting_body: (AwaitingClause | None) { getter; }
    has finally_body: (FinallyStmt | None) { getter; }

    def init(
        *,
        else_body: (ElseStmt | ElseIf | None) = None,
        body: Sequence[CodeBlockStmt],
        excepts: Sequence[Except],
        awaiting_body: (AwaitingClause | None),
        finally_body: (FinallyStmt | None),
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node AwaitingClause(CodeBlockStmt, UniScopeNode) {
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(*, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node Except(CodeBlockStmt, UniScopeNode) {
    has ex_type: Expr { getter; }
    has name: (Name | None) { getter; }
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(
        *,
        ex_type: Expr,
        name: (Name | None),
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node FinallyStmt(CodeBlockStmt, UniScopeNode) {
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(*, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node IterForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has iter: Assignment { getter; }
    has condition: Expr { getter; }
    has count_by: Assignment { getter; }
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(
        *,
        else_body: (ElseStmt | ElseIf | None) = None,
        is_async: bool = False,
        iter: Assignment,
        condition: Expr,
        count_by: Assignment,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node InForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has is_comptime: bool = False;
    has target: Expr { getter; }
    has collection: Expr { getter; }
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(
        *,
        else_body: (ElseStmt | ElseIf | None) = None,
        is_async: bool = False,
        target: Expr,
        collection: Expr,
        body: Sequence[CodeBlockStmt],
        is_comptime: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node WhileStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has condition: Expr { getter; }
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(
        *,
        else_body: (ElseStmt | ElseIf | None) = None,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node ForeverStmt(CodeBlockStmt, UniScopeNode) {
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(*, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node WithStmt(AstAsyncNode, CodeBlockStmt, UniScopeNode) {
    has exprs: Sequence[ExprAsItem] { getter; }
    has body: Sequence[CodeBlockStmt] { getter; }

    def init(
        *,
        is_async: bool = False,
        exprs: Sequence[ExprAsItem],
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node ExprAsItem(UniNode) {
    has expr: Expr { getter; }
    has alias: (Expr | None) { getter; }

    def init(*, expr: Expr, alias: (Expr | None), kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node RaiseStmt(CodeBlockStmt) {
    has cause: (Expr | None) { getter; }
    has from_target: (Expr | None) { getter; }

    def init(
        *, cause: (Expr | None), from_target: (Expr | None), kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node AssertStmt(ElementStmt, CodeBlockStmt) {
    has is_comptime: bool = False;
    has condition: Expr { getter; }
    has error_msg: (Expr | None) { getter; }

    def init(
        *,
        condition: Expr,
        error_msg: (Expr | None),
        is_comptime: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node CtrlStmt(CodeBlockStmt) {
    has ctrl: Token { getter; }

    def init(*, ctrl: Token, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node DeleteStmt(CodeBlockStmt) {
    has targets: list[Expr] { getter; }

    def init(*, targets: list[Expr], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
    def leaf_targets -> list[Expr];
    static def unwrap_target(target: Expr) -> Expr;
    static def is_location(target: Expr) -> bool;
    static def type_may_hold_graph(t: (TypeBase | None)) -> bool;
    static def target_may_hold_graph(target: Expr) -> bool;
}

node ReportStmt(CodeBlockStmt) {
    has expr: Expr { getter; }

    def init(*, expr: Expr, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node ReturnStmt(CodeBlockStmt) {
    has is_implicit: bool = False;
    has expr: (Expr | None) { getter; }

    def init(
        *, expr: (Expr | None), is_implicit: bool = False, kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node VisitStmt(WalkerStmtOnlyNode, AstElseBodyNode, CodeBlockStmt) {
    has insert_loc: (Expr | None) { getter; }
    has target: Expr { getter; }

    def init(
        *,
        else_body: (ElseStmt | ElseIf | None) = None,
        insert_loc: (Expr | None),
        target: Expr,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node DisengageStmt(WalkerStmtOnlyNode, CodeBlockStmt) {
    def init(*, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node AwaitExpr(Expr) {
    has target: Expr { getter; }

    def init(*, target: Expr, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node CastExpr(Expr) {
    has value: Expr { getter; }
    has cast_type: Expr { getter; }

    def init(*, value: Expr, cast_type: Expr, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node Assignment(AstTypedVarNode, EnumBlockStmt, CodeBlockStmt) {
    has mutable: bool = True,
        na_move_lowerable: bool = False,
        na_overwrite_consumed: bool = False,
        na_flow_reduce: str = "",
        is_comptime: bool = False;

    has target: Sequence[Expr] { getter; }
    has value: Expr | YieldExpr | None { getter; }
    has aug_op: (Token | None) { getter; }

    def init(
        *,
        is_enum_stmt: bool = False,
        type_tag: (SubTag[Expr] | None) = None,
        type: (TypeBase | None) = None,
        target: Sequence[Expr],
        value: Expr | YieldExpr | None,
        mutable: bool = True,
        aug_op: (Token | None) = None,
        na_move_lowerable: bool = False,
        na_overwrite_consumed: bool = False,
        na_flow_reduce: str = "",
        is_comptime: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node ConcurrentExpr(Expr) {
    has tok: (Token | None) { getter; }
    has target: Expr { getter; }

    def init(
        *, tok: (Token | None), target: Expr, kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node BinaryExpr(Expr) {
    has left: Expr { getter; }
    has right: Expr { getter; }
    has op: Token | DisconnectOp | ConnectOp { getter; }

    def init(
        *,
        left: Expr,
        right: Expr,
        op: Token | DisconnectOp | ConnectOp,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node CompareExpr(Expr) {
    has left: Expr { getter; }
    has rights: list[Expr] { getter; }
    has ops: list[Token] { getter; }

    def init(
        *, left: Expr, rights: list[Expr], ops: list[Token], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node BoolExpr(Expr) {
    has op: Token { getter; }
    has values: list[CfgExpr] { getter; }

    def init(*, op: Token, values: list[CfgExpr], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node LambdaExpr(Expr, UniScopeNode) {
    has body: (Expr | Sequence[CodeBlockStmt]) { getter; }
    has signature: (FuncSignature | None) { getter; }

    def init(
        *,
        body: (Expr | Sequence[CodeBlockStmt]),
        signature: (FuncSignature | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def tail_return_expr -> Expr | None;

    has captures: list[Symbol] { getter; }

    def __repr__ -> str;
}

node UnaryExpr(Expr) {
    has ownership: OwnershipKind = OwnershipKind.NONE;
    has operand: Expr { getter; }
    has op: Token { getter; }

    def init(
        *,
        operand: Expr,
        op: Token,
        ownership: OwnershipKind = OwnershipKind.NONE,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node IfElseExpr(Expr) {
    has condition: CfgExpr { getter; }
    has value: CfgExpr { getter; }
    has else_value: CfgExpr { getter; }

    def init(
        *,
        condition: CfgExpr,
        value: CfgExpr,
        else_value: CfgExpr,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node MultiString(AtomExpr) {
    has strings: Sequence[(String | FString)] { getter; }

    def init(
        *, strings: Sequence[(String | FString)], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;

    has lit_value: str | bytes { getter; }

    def __repr__ -> str;
}

node FString(AtomExpr) {
    has start: (Token | None) { getter; }
    has parts: Sequence[(String | FormattedValue)] { getter; }
    has end: (Token | None) { getter; }

    def init(
        *,
        start: (Token | None),
        parts: Sequence[(String | FormattedValue)],
        end: (Token | None),
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node FormattedValue(Expr) {
    has conversion: int;
    has format_part: Expr { getter; }
    has format_spec: (Expr | None) { getter; }

    def init(
        *,
        format_part: Expr,
        conversion: int,
        format_spec: (Expr | None),
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node ListVal(AtomExpr) {
    has values: Sequence[Expr] { getter; }

    def init(*, values: Sequence[Expr], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node SetVal(AtomExpr) {
    has values: (Sequence[Expr] | None) { getter; }

    def init(*, values: (Sequence[Expr] | None), kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node TupleVal(AtomExpr) {
    has values: Sequence[(Expr | KWPair)] { getter; }

    def init(
        *, values: Sequence[(Expr | KWPair)], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node DictVal(AtomExpr) {
    has kv_pairs: Sequence[KVPair] { getter; }

    def init(*, kv_pairs: Sequence[KVPair], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node KVPair(UniNode) {
    has key: (Expr | None) { getter; }
    has value: Expr { getter; }

    def init(*, key: (Expr | None), value: Expr, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node KWPair(UniNode) {
    has key: (NameAtom | None) { getter; }
    has value: Expr { getter; }

    def init(
        *, key: (NameAtom | None), value: Expr, kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node InnerCompr(AstAsyncNode, UniScopeNode, UniCFGNode) {
    has target: Expr { getter; }
    has collection: Expr { getter; }
    has conditional: (list[Expr] | None) { getter; }

    def init(
        *,
        is_async: bool = False,
        target: Expr,
        collection: Expr,
        conditional: (list[Expr] | None),
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node ListCompr(AtomExpr, UniScopeNode, UniCFGNode) {
    has out_expr: Expr { getter; }
    has compr: list[InnerCompr] { getter; }

    def init(
        *, out_expr: Expr, compr: list[InnerCompr], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node GenCompr(ListCompr) {
    def init(
        *, out_expr: Expr, compr: list[InnerCompr], kid: Sequence[UniNode] = []
    ) -> None;

    def __repr__ -> str;
}

node SetCompr(ListCompr) {
    def init(
        *, out_expr: Expr, compr: list[InnerCompr], kid: Sequence[UniNode] = []
    ) -> None;

    def __repr__ -> str;
}

node DictCompr(AtomExpr, UniScopeNode, UniCFGNode) {
    has kv_pair: KVPair { getter; }
    has compr: list[InnerCompr] { getter; }

    def init(
        *, kv_pair: KVPair, compr: list[InnerCompr], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node AtomTrailer(Expr) {
    has is_attr: bool,
        is_null_ok: bool,
        is_genai: bool = False;

    has target: Expr { getter; }
    has right: (AtomExpr | Expr) { getter; }

    def init(
        *,
        target: Expr,
        right: (AtomExpr | Expr),
        is_attr: bool,
        is_null_ok: bool,
        is_genai: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;

    has as_attr_list: list[AstSymbolNode] { getter; }

    def __repr__ -> str;
}

node AtomUnit(Expr) {
    has value: Expr | YieldExpr | Ability { getter; }

    def init(
        *, value: Expr | YieldExpr | Ability, kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node YieldExpr(Expr) {
    has with_from: bool;
    has expr: (Expr | None) { getter; }

    def init(
        *, expr: (Expr | None), with_from: bool, kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node FuncCall(Expr) {
    has genai_call: (Expr | None),
        call_kind: (str | None) = None,
        chunks_recv_type: (str | None) = None;

    has callee_decl: (Ability | None) {
        getter;
        setter(callee_decl: (Ability | None));
    }

    has target: Expr { getter; }
    has params: (Sequence[(Expr | KWPair)] | None) { getter; }

    def init(
        *,
        target: Expr,
        params: (Sequence[(Expr | KWPair)] | None),
        genai_call: (Expr | None),
        call_kind: (str | None) = None,
        chunks_recv_type: (str | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node Slice(UniNode) {
    has start: (Expr | None) { getter; }
    has stop: (Expr | None) { getter; }
    has step: (Expr | None) { getter; }

    def init(
        *,
        start: (Expr | None),
        stop: (Expr | None),
        step: (Expr | None),
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node IndexSlice(AtomExpr) {
    has is_range: bool;
    has slices: list[Slice] { getter; }

    def init(
        *, slices: list[Slice], is_range: bool, kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node EdgeRefTrailer(Expr) {
    has edges_only: bool,
        is_async: bool;

    has chain: list[(Expr | FilterCompr)] { getter; }

    def init(
        *,
        chain: list[(Expr | FilterCompr)],
        edges_only: bool,
        is_async: bool,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node EdgeOpRef(WalkerStmtOnlyNode, AtomExpr) {
    has edge_dir: EdgeDir;
    has filter_cond: (FilterCompr | None) { getter; }

    def init(
        *,
        filter_cond: (FilterCompr | None),
        edge_dir: EdgeDir,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node DisconnectOp(WalkerStmtOnlyNode) {
    has edge_spec: EdgeOpRef { getter; }

    def init(*, edge_spec: EdgeOpRef, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node ConnectOp(UniNode) {
    has edge_dir: EdgeDir;
    has conn_type: (Expr | None) { getter; }
    has conn_assign: (AssignCompr | None) { getter; }

    def init(
        *,
        conn_type: (Expr | None),
        conn_assign: (AssignCompr | None),
        edge_dir: EdgeDir,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node FilterCompr(AtomExpr) {
    has f_type: (Expr | None) { getter; }
    has compares: Sequence[Expr] { getter; }

    def init(
        *, f_type: (Expr | None), compares: Sequence[Expr], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node AssignCompr(AtomExpr) {
    has assigns: Sequence[KWPair] { getter; }

    def init(*, assigns: Sequence[KWPair], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node JsxElement(AtomExpr) {
    has is_self_closing: bool,
        is_fragment: bool;

    has name: (JsxElementName | None) { getter; }
    has attributes: (Sequence[JsxAttribute] | None) { getter; }
    has children: (Sequence[(JsxChild | JsxElement)] | None) { getter; }
    has dynamic_tag: (Expr | None) { getter; }

    def init(
        *,
        name: (JsxElementName | None),
        attributes: (Sequence[JsxAttribute] | None),
        children: (Sequence[(JsxChild | JsxElement)] | None),
        is_self_closing: bool,
        is_fragment: bool,
        dynamic_tag: (Expr | None) = None,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def get_body_start_line -> (int | None);
    def get_body_end_line -> (int | None);
    def __repr__ -> str;
}

node JsxElementName(UniNode) {
    has parts: Sequence[(Name | Token)] { getter; }

    def init(*, parts: Sequence[(Name | Token)], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node JsxAttribute(UniNode) {
    def init(*, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node JsxSpreadAttribute(JsxAttribute) {
    has expr: Expr { getter; }

    def init(*, expr: Expr, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node JsxNormalAttribute(JsxAttribute) {
    has is_shorthand: bool = False;
    has name: (Name | Token) { getter; }
    has value: String | Expr | None { getter; }

    def init(
        *,
        name: (Name | Token),
        value: String | Expr | None,
        is_shorthand: bool = False,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node JsxChild(UniNode) {
    def init(*, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node JsxText(JsxChild) {
    has value: (str | Token);

    def init(*, value: (str | Token), kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def get_normalized_text -> str;
    def __repr__ -> str;
}

node JsxExpression(JsxChild) {
    has expr: Expr { getter; }

    def init(*, expr: Expr, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node JsxSlot(JsxChild) {
    has body: list[UniNode] { getter; }

    def init(*, body: list[UniNode], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node JsxComment(JsxChild) {
    has value: Token { getter; }

    def init(*, value: Token, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node MatchStmt(CodeBlockStmt) {
    has target: Expr { getter; }
    has cases: list[MatchCase] { getter; }

    def init(
        *, target: Expr, cases: list[MatchCase], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node MatchCase(CodeBlockStmt, UniScopeNode) {
    has pattern: MatchPattern { getter; }
    has guard: (Expr | None) { getter; }
    has body: list[CodeBlockStmt] { getter; }

    def init(
        *,
        pattern: MatchPattern,
        guard: (Expr | None),
        body: list[CodeBlockStmt],
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node SwitchStmt(CodeBlockStmt) {
    has target: Expr { getter; }
    has cases: list[SwitchCase] { getter; }

    def init(
        *, target: Expr, cases: list[SwitchCase], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node SwitchCase(CodeBlockStmt, UniScopeNode) {
    has pattern: (MatchPattern | None) { getter; }
    has body: list[CodeBlockStmt] { getter; }

    def init(
        *,
        pattern: (MatchPattern | None),
        body: list[CodeBlockStmt],
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node MatchOr(MatchPattern) {
    has patterns: list[MatchPattern] { getter; }

    def init(*, patterns: list[MatchPattern], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node MatchAs(MatchPattern) {
    has name: NameAtom { getter; }
    has pattern: (MatchPattern | None) { getter; }

    def init(
        *, name: NameAtom, pattern: (MatchPattern | None), kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node MatchWild(MatchPattern) {
    def init(*, kid: Sequence[UniNode] = []) -> None;
    def __repr__ -> str;
}

node MatchValue(MatchPattern) {
    has value: Expr { getter; }

    def init(*, value: Expr, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node MatchSingleton(MatchPattern) {
    has value: (Bool | Null) { getter; }

    def init(*, value: (Bool | Null), kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node MatchSequence(MatchPattern) {
    has values: list[MatchPattern] { getter; }

    def init(*, values: list[MatchPattern], kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node MatchMapping(MatchPattern) {
    has values: list[(MatchKVPair | MatchStar)] { getter; }

    def init(
        *, values: list[(MatchKVPair | MatchStar)], kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node MatchKVPair(MatchPattern) {
    has key: MatchPattern | NameAtom | AtomExpr { getter; }
    has value: MatchPattern { getter; }

    def init(
        *,
        key: MatchPattern | NameAtom | AtomExpr,
        value: MatchPattern,
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node MatchStar(MatchPattern) {
    has is_list: bool;
    has name: NameAtom { getter; }

    def init(*, name: NameAtom, is_list: bool, kid: Sequence[UniNode] = []) -> None;
    def postinit -> None;
    def __repr__ -> str;
}

node MatchArch(MatchPattern) {
    has name: (AtomTrailer | NameAtom) { getter; }
    has arg_patterns: (Sequence[MatchPattern] | None) { getter; }
    has kw_patterns: (Sequence[MatchKVPair] | None) { getter; }

    def init(
        *,
        name: (AtomTrailer | NameAtom),
        arg_patterns: (Sequence[MatchPattern] | None),
        kw_patterns: (Sequence[MatchKVPair] | None),
        kid: Sequence[UniNode] = []
    ) -> None;

    def postinit -> None;
    def __repr__ -> str;
}

node Token(UniNode) {
    has orig_src: Source postinit,
        name: str postinit,
        value: str postinit,
        line_no: int postinit,
        end_line: int postinit,
        c_start: int postinit,
        c_end: int postinit,
        pos_start: int postinit,
        pos_end: int postinit,
        _is_synthetic: bool = False;

    def init(
        orig_src: Source,
        name: str,
        value: str,
        line: int,
        end_line: int,
        col_start: int,
        col_end: int,
        pos_start: int,
        pos_end: int
    ) -> None;

    def __repr__ -> str;
}

node Name(Token, NameAtom) {
    has is_kwesc: bool postinit,
        is_enum_stmt: bool postinit;

    def init(
        orig_src: Source,
        name: str,
        value: str,
        line: int,
        end_line: int,
        col_start: int,
        col_end: int,
        pos_start: int,
        pos_end: int,
        is_enum_stmt: bool = False,
        is_kwesc: bool = False
    ) -> None;

    static def gen_stub_from_node(
        nd: AstSymbolNode, name_str: str, set_name_of: (AstSymbolNode | None) = None
    ) -> Name {
        ret = Name(
            orig_src=nd.loc.orig_src,
            name=Tok.NAME.value,
            value=name_str,
            col_start=nd.loc.col_start,
            col_end=nd.loc.col_end,
            line=nd.loc.first_line,
            end_line=nd.loc.last_line,
            pos_start=nd.loc.pos_start,
            pos_end=nd.loc.pos_end
        );
        if nd.parent is not None {
            ret.set_parent(nd.parent);
        }
        ret.name_of = set_name_of or ret;
        return ret;
    }

    def __repr__ -> str;
}

node SpecialVarRef(Name) {
    has orig: Name postinit;

    def init(var: Name, is_enum_stmt: bool = False) -> None;
    def py_resolve_name -> str;
    def __repr__ -> str;
}

node Literal(Token, AtomExpr) {
    with entry {
        SYMBOL_TYPE = SymbolType.VAR;
        type_map = {
            'int': int,
            'float': float,
            'str': str,
            'bool': bool,
            'bytes': `bytes,
            'list': `list,
            'tuple': `tuple,
            'set': `set,
            'dict': `dict,
            'type': `type
        };
    }

    def init(
        orig_src: Source,
        name: str,
        value: str,
        line: int,
        end_line: int,
        col_start: int,
        col_end: int,
        pos_start: int,
        pos_end: int
    ) -> None;

    has lit_value: int | str | bytes | float | bool | None | type | object { getter; }

    def __repr__ -> str;
}

node BuiltinType(Name, Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.VAR;
    }

    has lit_value: type { getter; }

    def __repr__ -> str;
}

node Float(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    has lit_value: float { getter; }

    def __repr__ -> str;
}

node Int(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    has lit_value: int { getter; }

    def __repr__ -> str;
}

node String(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.STRING;
    }

    has lit_value: str | bytes { getter; }

    def __repr__ -> str;
}

node Bool(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.BOOL;
    }

    has lit_value: bool { getter; }

    def __repr__ -> str;
}

node Null(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    has lit_value: None { getter; }

    def __repr__ -> str;
}

node Ellipsis(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    has lit_value: object { getter; }

    def __repr__ -> str;
}

node EmptyToken(Token) {
    def init(orig_src: (Source | None) = None) -> None;
    def __repr__ -> str;
}

node Semi(Token, CodeBlockStmt) {
    def init(
        orig_src: Source,
        name: str,
        value: str,
        line: int,
        end_line: int,
        col_start: int,
        col_end: int,
        pos_start: int,
        pos_end: int
    ) -> None;

    def __repr__ -> str;
}

node CommentToken(Token) {
    def init(
        orig_src: Source,
        name: str,
        value: str,
        line: int,
        end_line: int,
        col_start: int,
        col_end: int,
        pos_start: int,
        pos_end: int,
        kid: Sequence[UniNode]
    ) -> None;

    def __repr__ -> str;
}

node Source(EmptyToken) {
    has comments: list[CommentToken] postinit,
        inline_suppressions: dict[int, set[str]] postinit,
        file_path: str postinit,
        _hash: str postinit;

    def init(source: str, mod_path: str) -> None;

    has code: str { getter; }
    has hash: str { getter; }

    def __repr__ -> str;
}

node PythonModuleAst(EmptyToken) {
    has ast: object postinit,
        orig_src: Source postinit,
        file_path: str postinit;

    def init(ast: object, orig_src: Source) -> None;
    def __repr__ -> str;
}

glob _HEX_DIGITS: str = '0123456789abcdefABCDEF',
     _OCT_DIGITS: str = '01234567',
     _LIT_PREFIX_CHARS: str = 'bBrR',
     _MAX_CODE_POINT: int = 1114111,
     _SIMPLE_ESCAPES: dict[str, str] = {
         '\\': '\\',
         "'": "'",
         '"': '"',
         'a': '\x07',
         'b': '\x08',
         'f': '\x0c',
         'n': '\n',
         'r': '\r',
         't': '\t',
         'v': '\x0b'
     };

def _lit_prefix_len(text: str) -> int {
    n = len(text);
    i = 0;
    while (i < n and i < 2) {
        ch = text[i];
        if (ch == '"' or ch == "'") {
            return i;
        }
        if (ch not in _LIT_PREFIX_CHARS) {
            return -1;
        }
        i += 1;
    }
    if (i < n and (text[i] == '"' or text[i] == "'")) {
        return i;
    }
    return -1;
}

def _lit_quote_len(text: str, start: int) -> int {
    if ((len(text) - start) >= 6) {
        opener = text[start:start + 3];
        if (opener == '"""' or opener == "'''") {
            return 3;
        }
    }
    return 1;
}

def _hex_escape_value(text: str, at: int, width: int, kind: str) -> int {
    digits = text[at + 2:at + 2 + width];
    bad = len(digits) != width;
    if not bad {
        for c in digits {
            if (c not in _HEX_DIGITS) {
                bad = True;
                break;
            }
        }
    }
    if bad {
        raise ValueError(
            f"truncated \\{kind} escape: expected {width} hex digits, got '{digits}'"
        );
    }
    code = int(digits, 16);
    if (code > _MAX_CODE_POINT) {
        raise ValueError(f"illegal Unicode character in \\{kind}{digits} escape");
    }
    return code;
}

def _decode_str_escapes(text: str) -> str {
    if ('\\' not in text) {
        return text;
    }
    out: list[str] = [];
    i = 0;
    n = len(text);
    while (i < n) {
        ch = text[i];
        if (ch != '\\' or (i + 1) >= n) {
            out.append(ch);
            i += 1;
            continue;
        }
        nxt = text[i + 1];
        if (nxt in _SIMPLE_ESCAPES) {
            out.append(_SIMPLE_ESCAPES[nxt]);
            i += 2;
            continue;
        }
        if (nxt == '\n') {
            i += 2;
            continue;
        }
        if (nxt == '\r') {
            i += 3 if ((i + 2) < n and text[i + 2] == '\n') else 2;
            continue;
        }
        if (nxt in _OCT_DIGITS) {
            j = i + 1;
            end = min(n, i + 4);
            while (j < end and text[j] in _OCT_DIGITS) {
                j += 1;
            }
            out.append(chr(int(text[i + 1:j], 8)));
            i = j;
            continue;
        }
        if (nxt == 'x' or nxt == 'u' or nxt == 'U') {
            width = 2 if (nxt == 'x') else (4 if (nxt == 'u') else 8);
            out.append(chr(_hex_escape_value(text, i, width, nxt)));
            i += 2 + width;
            continue;
        }
        if (nxt == 'N') {
            raise ValueError(
                "the \\N{name} escape is not supported: the Unicode name "
                "database is not available to the compiler, so write the "
                "code point as \\uXXXX or \\UXXXXXXXX instead"
            );
        }
        out.append('\\');
        out.append(nxt);
        i += 2;
    }
    return ''.join(out);
}

def _decode_bytes_escapes(text: str, is_raw: bool) -> bytes {
    out: list[int] = [];
    i = 0;
    n = len(text);
    while (i < n) {
        ch = text[i];
        code = ord(ch);
        if (code > 127) {
            raise ValueError('bytes can only contain ASCII literal characters');
        }
        if (is_raw or ch != '\\' or (i + 1) >= n) {
            out.append(code);
            i += 1;
            continue;
        }
        nxt = text[i + 1];
        if (nxt in _SIMPLE_ESCAPES) {
            out.append(ord(_SIMPLE_ESCAPES[nxt]));
            i += 2;
            continue;
        }
        if (nxt == '\n') {
            i += 2;
            continue;
        }
        if (nxt == '\r') {
            i += 3 if ((i + 2) < n and text[i + 2] == '\n') else 2;
            continue;
        }
        if (nxt in _OCT_DIGITS) {
            j = i + 1;
            end = min(n, i + 4);
            while (j < end and text[j] in _OCT_DIGITS) {
                j += 1;
            }
            out.append(int(text[i + 1:j], 8) % 256);
            i = j;
            continue;
        }
        if (nxt == 'x') {
            out.append(_hex_escape_value(text, i, 2, 'x'));
            i += 4;
            continue;
        }
        if (ord(nxt) > 127) {
            raise ValueError('bytes can only contain ASCII literal characters');
        }
        out.append(92);
        out.append(ord(nxt));
        i += 2;
    }
    return bytes(out);
}

def decode_string_literal(text: str) -> str | bytes {
    start = _lit_prefix_len(text);
    if (start < 0) {
        return text;
    }
    prefix = text[:start].lower();
    quote_len = _lit_quote_len(text, start);
    body = text[start + quote_len:len(text) - quote_len];
    is_raw = 'r' in prefix;
    if ('b' in prefix) {
        return _decode_bytes_escapes(body, is_raw);
    }
    if is_raw {
        return body;
    }
    return _decode_str_escapes(body);
}

def is_identifier_slot(nd: UniNode) -> bool;

def find_python_scope_node_of(nd: UniNode) -> (UniScopeNode | None);

def find_typed_decl_scope_of(nd: AstSymbolNode) -> UniScopeNode;

def def_insert_unpacking(
    nd: Expr, sym_tab: UniScopeNode, rebind_in_python_scope: bool = False
) -> None;

def bind_assignment_targets(nd: Assignment) -> None;

def lookup_enclosing_binding(from_scope: UniScopeNode, name: str) -> (Symbol | None);

def rebind_or_def_insert(
    target: AstSymbolNode, py_scope: UniScopeNode, single_decl: str
) -> None;

def record_cross_scope_rebind(py_scope: UniScopeNode, name: str, sym: Symbol) -> None;

def _ability_of_defn(defn_node: UniNode) -> (Ability | None);

def ability_of_symbol(sym: (Symbol | None)) -> (Ability | None);

def binding_kind_of_decl(decl: NameAtom) -> BindingKind;

def import_chain_of(sym: Symbol) -> list[Symbol];

def resolved_decl_of(sym: Symbol) -> (NameAtom | None);

def kind_has_runtime_binding(
    kind: BindingKind, decl: (NameAtom | None), space: CodeContext
) -> bool;

def has_runtime_binding(sym: Symbol, space: CodeContext) -> bool;

def is_client_destined(nd: UniNode) -> bool;

def type_only_import_of(nd: NameAtom) -> (ModuleItem | None);

def in_type_position(nd: UniNode) -> bool;
