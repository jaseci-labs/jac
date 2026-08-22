import os;
import type from collections.abc { Sequence }
import from enum { IntEnum }
import type from jaclang.jac0core.passes.uni_pass { UniPass }
import type from jaclang.jac0core.codeinfo { CodeGenTarget }
import from jaclang.jac0core.srcloc { CodeLocInfo }
import from jaclang.jac0core.constant {
    BUILTIN_CALLABLE_NAMES,
    DELIM_MAP,
    CodeContext,
    EdgeDir,
    ExprCtx,
    OwnershipKind,
    SymbolAccess,
    SymbolStorage,
    SymbolType
}
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.jac0core.constant { JacSemTokenModifier as SemTokMod }
import from jaclang.jac0core.constant { JacSemTokenType as SemTokType }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.constant { ParamKind }
import type from jaclang.compiler.type_system.types { TypeBase }


obj UniNode {
    has kid: Sequence[UniNode] = [],
        parent: (UniNode | None) postinit,
        __sub_node_tab: (dict[(type, list[UniNode])] | None) postinit,
        _in_mod_nodes: list[UniNode] postinit,
        _gen: (CodeGenTarget | None) postinit,
        loc: CodeLocInfo postinit;

    def postinit -> None;
    def accept_enter(v: UniPass) -> None;
    def accept_exit(v: UniPass) -> None;

    has gen: CodeGenTarget { getter; setter(value: CodeGenTarget); }
    has _sub_node_tab: dict[(type, list[UniNode])] { getter; }

    def _construct_sub_node_tab -> None;
    def _invalidate_sub_node_tab -> None;

    has sym_tab: UniScopeNode { getter; }

    def add_kids_left(
        nodes: Sequence[UniNode], pos_update: bool = True, parent_update: bool = False
    ) -> UniNode;

    def add_kids_right(
        nodes: Sequence[UniNode], pos_update: bool = True, parent_update: bool = False
    ) -> UniNode;

    def insert_kids_at_pos(
        nodes: Sequence[UniNode], pos: int, pos_update: bool = True
    ) -> UniNode;

    def set_kids(nodes: Sequence[UniNode]) -> UniNode;
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
}

obj Symbol {
    has defn: list[NameAtom] postinit,
        uses: list[NameAtom] postinit,
        access: SymbolAccess postinit,
        parent_tab: (UniScopeNode | None) postinit,
        imported: bool postinit,
        semstr: str postinit,
        ownership: OwnershipKind = OwnershipKind.NONE,
        param_rebound: bool = False,
        na_escapes: bool = False,
        na_region_handle: bool = False,
        na_stack_ok: bool = False;

    def init(
        defn: NameAtom,
        access: SymbolAccess,
        parent_tab: (UniScopeNode | None) = None,
        imported: bool = False
    ) -> None;

    has decl: NameAtom { getter; }
    has sym_name: str { getter; }
    has sym_type: SymbolType { getter; }
    has sym_dotted_name: str { getter; }
    has symbol_table: (UniScopeNode | None) { getter; }
    has storage: SymbolStorage { getter; }

    def add_defn(nd: NameAtom) -> None;
    def add_use(nd: NameAtom) -> None;
    def __repr__ -> str;
}

obj InheritedSymbolTable {
    has base_symbol_table: UniScopeNode,
        load_all_symbols: bool = False,
        symbols: list[str] = [];
}

obj UniScopeNode(UniNode) {
    has scope_name: str postinit,
        parent_scope: (UniScopeNode | None) postinit,
        kid_scope: list[UniScopeNode] postinit,
        names_in_scope: dict[(str, Symbol)] postinit,
        names_in_scope_overload: dict[(str, list[Symbol])] postinit,
        implicit_rebinds: dict[(str, Symbol)] postinit;

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
}

obj AstSymbolNode(UniNode) {
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
}

obj AstSymbolStubNode(AstSymbolNode) {
    def _init_stub(sym_type: SymbolType) -> None;
}

obj AstAccessNode(UniNode) {
    has access: (SubTag[Token] | None) = None;
    has access_type: SymbolAccess { getter; }
    has public_access: bool { getter; }
}

obj ContextAwareNode(UniNode) {
    has code_context: CodeContext postinit,
        codespace_dual: bool = False;

    def postinit -> None;
}

obj AstDocNode(UniNode) {
    has doc: (String | None) = None;

    def set_doc(elem_doc: (String | None)) -> None;
}

obj AstAsyncNode(UniNode) {
    has is_async: bool = False;
}

obj AstElseBodyNode(UniNode) {
    has else_body: (ElseStmt | ElseIf | None) = None;
}

obj AstTypedVarNode(UniNode) {
    has type_tag: (SubTag[Expr] | None) = None,
        type: (TypeBase | None) = None;
}

obj WalkerStmtOnlyNode(UniNode) {
    has from_walker: bool postinit;

    def postinit -> None;
}

obj UniCFGNode(UniNode) {
    has bb_in: list[UniCFGNode] postinit,
        bb_out: list[UniCFGNode] postinit,
        affected_symbols: set[str] postinit;

    def postinit -> None;
    def get_head -> UniCFGNode;
    def get_tail -> UniCFGNode;
}

obj ConditionalNode(UniCFGNode) {
    has sc_true_target: (UniCFGNode | None) = None,
        sc_false_target: (UniCFGNode | None) = None;

    def postinit -> None;
}

obj Expr(UniNode) {
    has _type_sym_tab: (UniScopeNode | None) postinit,
        type: (TypeBase | None) postinit,
        narrowed_type: (TypeBase | None) postinit,
        attached_tokens: (list[Token] | None) postinit;

    def postinit -> None;

    has type_sym_tab: (UniScopeNode | None) {
        getter;
        setter(type_sym_tab: UniScopeNode);
    }
}

obj CfgExpr(Expr, ConditionalNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has expr: Expr;

    def postinit -> None;
}

obj AtomExpr(Expr, AstSymbolStubNode) {}

obj ElementStmt(AstDocNode) {}

obj ArchBlockStmt(UniNode) {}

obj EnumBlockStmt(UniNode) {
    has is_enum_stmt: bool = False;
}

obj CodeBlockStmt(UniCFGNode) {
    def postinit -> None;
}

obj AstImplNeedingNode(AstSymbolNode) {
    has body: (Sequence[UniNode] | UniNode | None);
    has needs_impl: bool { getter; }
}

obj NameAtom(AtomExpr, EnumBlockStmt) {
    has name_of: AstSymbolNode postinit,
        _sym: (Symbol | None) postinit,
        _sym_name: str postinit,
        _sym_category: SymbolType postinit,
        _expr_ctx: ExprCtx postinit,
        is_getattr_resolved: bool = False;

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
}

obj ArchSpec(ElementStmt, CodeBlockStmt, AstSymbolNode, AstAsyncNode, AstDocNode) {
    has decorators: (Sequence[Expr] | None);

    def postinit -> None;
}

obj MatchPattern(UniNode) {}

obj SubTag[T](UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has tag: T,
        ownership: OwnershipKind = OwnershipKind.NONE;

    def postinit -> None;
}

obj Module(AstDocNode, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: str,
        source: Source,
        body: Sequence[ElementStmt | String | EmptyToken],
        terminals: list[Token],
        stub_only: bool = False,
        src_terminals: list[Token] = [],
        is_raised_from_py: bool = False,
        has_synthesized_tokens: bool = False,
        decided_codespace: str = "",
        parse_failed: bool = False,
        mobui_enforced_root: (str | None) = None,
        jac_project_root: (str | None) = None,
        access_enforced: bool = False,
        native_viols_reported: bool = False,
        client_viols_reported: bool = False,
        rc_last_use: dict[int, list[str]] postinit,
        rc_move_in: set[int] postinit,
        anon_region_open: dict[int, int] postinit,
        anon_region_close: dict[int, int] postinit,
        anon_region_locals: dict[int, list[str]] postinit,
        annex_mods: list[Module] postinit;

    def postinit -> None;

    has annexable_by: (str | None) { getter; }

    def declares_codespace(ctx: CodeContext, path_hint: str = '') -> bool;
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
}

obj ProgramModule(UniNode) {
    has main_mod: (Module | None) = None,
        main: Module postinit,
        hub: dict[(str, Module)] postinit;

    def postinit -> None;
}

obj TypeParam(AstSymbolNode, UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: Name,
        bound: (Expr | None),
        default_val: (Expr | None);

    def postinit -> None;
}

obj TypeAlias(ContextAwareNode, AstAccessNode, ElementStmt, AstSymbolNode, UniScopeNode, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: Name,
        type_params: (Sequence[TypeParam] | None),
        value: Expr,
        is_distinct: bool = False;

    def postinit -> None;
}

obj GlobalVars(ContextAwareNode, ElementStmt, AstAccessNode, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has assignments: Sequence[Assignment],
        is_frozen: bool;

    def postinit -> None;
}

obj Test(ContextAwareNode, AstSymbolNode, ElementStmt, CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: Name,
        body: Sequence[CodeBlockStmt],
        description: (String | None) = None,
        decorators: (Sequence[Expr] | None) = None;

    def postinit -> None;
}

obj ModuleCode(ContextAwareNode, ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: (Name | None),
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj PyInlineCode(ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has code: Token;

    def postinit -> None;
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
        bridged_decls: dict[(str, Ability)] = {};
}

obj Import(ContextAwareNode, ElementStmt, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has from_loc: (ModulePath | None),
        items: Sequence[(ModuleItem | ModulePath)],
        is_absorb: bool,
        is_typed: bool = False,
        clib_decls: (Sequence[UniNode] | None) = None,
        clib_header: (String | None) = None,
        hint: (SubTag[Token] | None) postinit,
        absorbed_mod: (Module | None) postinit,
        jac_detected: (bool | None) postinit,
        boundary_facts: (ImportBoundaryFacts | None) postinit,
        native_only_drop: bool postinit;

    def postinit -> None;

    has is_jac: bool { getter; }
    has __jac_detected: bool { getter; }
    has has_string_path: bool { getter; }
    has has_clib_decls: bool { getter; }
    has is_service_import: bool { getter; }
    has is_virtual_jac: bool { getter; }
    has ecosystem: str { getter; }
}

obj ModulePath(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has path: (Sequence[(Name | String)] | None),
        level: int,
        alias: (Name | None),
        abs_path: (str | None) postinit;

    def postinit -> None;

    has is_import_from: bool { getter; }
    has dot_path_str: str { getter; }
    has base_module_name: str { getter; }
    has string_path_value: (str | None) { getter; }

    def resolve_relative_path(target_item: (str | None) = None) -> str;
    def resolve_relative_path_list -> list[str];
    def native_bundled_path -> (str | None);
}

obj ModuleItem(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: (Name | Token),
        alias: (Name | None),
        abs_path: (str | None) postinit;

    def postinit -> None;

    has from_parent: Import { getter; }
    has from_mod_path: ModulePath { getter; }
    has binding_name: (Name | None) { getter; }

    def resolve_relative_path -> str;
}

obj Archetype(ContextAwareNode, ArchSpec, AstAccessNode, ArchBlockStmt, AstImplNeedingNode, UniScopeNode, UniCFGNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: Name,
        arch_type: Token,
        base_classes: (Sequence[Expr] | None),
        keywords: (Sequence[KWPair] | None) = None,
        type_params: (Sequence[TypeParam] | None) = None,
        src_endpoint: (Expr | None) = None,
        tgt_endpoint: (Expr | None) = None;

    def postinit -> None;
    def _get_impl_resolved_body -> list[UniNode];

    has is_abstract: bool { getter; }
    has arch_kind: (str | None) { getter; }

    def get_has_vars -> list[HasVar];
    def get_methods -> list[Ability];
}

obj ImplDef(ContextAwareNode, CodeBlockStmt, ElementStmt, ArchBlockStmt, AstSymbolNode, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has decorators: (Sequence[Expr] | None),
        target: Sequence[NameAtom],
        spec: (Sequence[Expr] | FuncSignature | EventSignature | None),
        body: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr,
        decl_link: (UniNode | None) = None;

    def postinit -> None;
    def create_impl_name_node -> Name;
}

obj SemDef(ElementStmt, AstSymbolNode, UniScopeNode, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Sequence[NameAtom],
        value: MultiString;

    def postinit -> None;
    def create_sem_name_node -> Name;
}

obj Enum(ContextAwareNode, ArchSpec, AstAccessNode, AstImplNeedingNode, ArchBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: Name,
        value_type: (Expr | None),
        base_classes: (Sequence[Expr] | None);

    def postinit -> None;
}

obj Ability(ContextAwareNode, AstAccessNode, ElementStmt, AstAsyncNode, ArchBlockStmt, CodeBlockStmt, AstImplNeedingNode, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name_ref: (NameAtom | None),
        is_override: bool,
        is_static: bool,
        is_classmethod: bool,
        is_abstract: bool,
        signature: FuncSignature | EventSignature | None,
        decorators: (Sequence[Expr] | None) = None,
        type_params: (Sequence[TypeParam] | None) = None,
        accessor_kind: str = "",
        event_triggers: (list[TypeBase] | None) = None;

    def postinit -> None;

    has is_method: bool { getter; }
    has is_cls_method: bool { getter; }
    has is_def: bool { getter; }
    has method_owner: Archetype | Enum | None { getter; }
    has is_genai_ability: bool { getter; }

    def py_resolve_name -> str;
    def event_trigger_type_names -> (list[str] | None);
}

obj FuncSignature(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has posonly_params: Sequence[ParamVar],
        params: (Sequence[ParamVar] | None),
        varargs: (ParamVar | None),
        kwonlyargs: Sequence[ParamVar],
        kwargs: (ParamVar | None),
        return_type: (Expr | None);

    def postinit -> None;
    def get_parameters -> list[ParamVar];

    has is_static: bool { getter; }
    has is_in_py_class: bool { getter; }
}

obj EventSignature(WalkerStmtOnlyNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has event: Token,
        arch_tag_info: (Expr | None);

    def postinit -> None;
}

obj ParamVar(AstSymbolNode, AstTypedVarNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: Name,
        unpack: (Token | None),
        value: (Expr | None),
        param_kind: ParamKind postinit;

    def postinit -> None;

    has is_vararg: bool { getter; }
    has is_kwargs: bool { getter; }
}

obj ArchHas(AstAccessNode, AstDocNode, ArchBlockStmt, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has is_static: bool,
        vars: Sequence[HasVar],
        is_frozen: bool;

    def postinit -> None;
}

obj HasVar(AstSymbolNode, AstTypedVarNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: Name,
        value: (Expr | None),
        defer: bool,
        accessors: (Sequence[Ability] | None) = None;

    def postinit -> None;
}

obj TypedCtxBlock(CodeBlockStmt, WalkerStmtOnlyNode, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has type_ctx: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj OpenStmt(CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj IfStmt(CodeBlockStmt, AstElseBodyNode, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has condition: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj ElseIf(IfStmt) {
    def accept_enter(v: UniPass) -> None;
    def accept_exit(v: UniPass) -> None;
}

obj ElseStmt(UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj ExprStmt(CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has expr: Expr,
        in_fstring: bool,
        has_semi: bool = True;

    def postinit -> None;
}

obj TryStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: Sequence[CodeBlockStmt],
        excepts: Sequence[Except],
        awaiting_body: (AwaitingClause | None),
        finally_body: (FinallyStmt | None);

    def postinit -> None;
}

obj AwaitingClause(CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj Except(CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has ex_type: Expr,
        name: (Name | None),
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj FinallyStmt(CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj IterForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has iter: Assignment,
        condition: Expr,
        count_by: Assignment,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj InForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Expr,
        collection: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj WhileStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has condition: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj ForeverStmt(CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj WithStmt(AstAsyncNode, CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has exprs: Sequence[ExprAsItem],
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj ExprAsItem(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has expr: Expr,
        alias: (Expr | None);

    def postinit -> None;
}

obj RaiseStmt(CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has cause: (Expr | None),
        from_target: (Expr | None);

    def postinit -> None;
}

obj AssertStmt(CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has condition: Expr,
        error_msg: (Expr | None);

    def postinit -> None;
}

obj CtrlStmt(CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has ctrl: Token;

    def postinit -> None;
}

obj DeleteStmt(CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Expr;

    def postinit -> None;
}

obj ReportStmt(CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has expr: Expr;

    def postinit -> None;
}

obj ReturnStmt(CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has expr: (Expr | None),
        is_implicit: bool = False;

    def postinit -> None;
}

obj VisitStmt(WalkerStmtOnlyNode, AstElseBodyNode, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has insert_loc: (Expr | None),
        target: Expr;

    def postinit -> None;
}

obj DisengageStmt(WalkerStmtOnlyNode, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;
    def postinit -> None;
}

obj AwaitExpr(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Expr;

    def postinit -> None;
}

obj CastExpr(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has value: Expr,
        cast_type: Expr;

    def postinit -> None;
}

obj Assignment(AstTypedVarNode, EnumBlockStmt, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Sequence[Expr],
        value: Expr | YieldExpr | None,
        mutable: bool = True,
        aug_op: (Token | None) = None,
        na_move_lowerable: bool = False,
        na_overwrite_consumed: bool = False,
        na_flow_reduce: str = "";

    def postinit -> None;
}

obj ConcurrentExpr(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has tok: (Token | None),
        target: Expr;

    def postinit -> None;
}

obj BinaryExpr(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has left: Expr,
        right: Expr,
        op: Token | DisconnectOp | ConnectOp;

    def postinit -> None;
}

obj CompareExpr(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has left: Expr,
        rights: list[Expr],
        ops: list[Token];

    def postinit -> None;
}

obj BoolExpr(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has op: Token,
        values: list[CfgExpr];

    def postinit -> None;
}

obj LambdaExpr(Expr, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: (Expr | Sequence[CodeBlockStmt]),
        signature: (FuncSignature | None) = None;

    def postinit -> None;
    def tail_return_expr -> Expr | None;

    has captures: list[Symbol] { getter; }
}

obj UnaryExpr(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has operand: Expr,
        op: Token,
        ownership: OwnershipKind = OwnershipKind.NONE;

    def postinit -> None;
}

obj IfElseExpr(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has condition: CfgExpr,
        value: CfgExpr,
        else_value: CfgExpr;

    def postinit -> None;
}

obj MultiString(AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has strings: Sequence[(String | FString)];

    def postinit -> None;

    has lit_value: str | bytes { getter; }
}

obj FString(AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has start: (Token | None),
        parts: Sequence[(String | FormattedValue)],
        end: (Token | None);

    def postinit -> None;
}

obj FormattedValue(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has format_part: Expr,
        conversion: int,
        format_spec: (Expr | None);

    def postinit -> None;
}

obj ListVal(AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has values: Sequence[Expr];

    def postinit -> None;
}

obj SetVal(AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has values: (Sequence[Expr] | None);

    def postinit -> None;
}

obj TupleVal(AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has values: Sequence[(Expr | KWPair)];

    def postinit -> None;
}

obj DictVal(AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has kv_pairs: Sequence[KVPair];

    def postinit -> None;
}

obj KVPair(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has key: (Expr | None),
        value: Expr;

    def postinit -> None;
}

obj KWPair(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has key: (NameAtom | None),
        value: Expr;

    def postinit -> None;
}

obj InnerCompr(AstAsyncNode, UniScopeNode, UniCFGNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Expr,
        collection: Expr,
        conditional: (list[Expr] | None);

    def postinit -> None;
}

obj ListCompr(AtomExpr, UniScopeNode, UniCFGNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has out_expr: Expr,
        compr: list[InnerCompr];

    def postinit -> None;
}

obj GenCompr(ListCompr) {
    def accept_enter(v: UniPass) -> None;
    def accept_exit(v: UniPass) -> None;
}

obj SetCompr(ListCompr) {
    def accept_enter(v: UniPass) -> None;
    def accept_exit(v: UniPass) -> None;
}

obj DictCompr(AtomExpr, UniScopeNode, UniCFGNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has kv_pair: KVPair,
        compr: list[InnerCompr];

    def postinit -> None;
}

obj AtomTrailer(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Expr,
        right: (AtomExpr | Expr),
        is_attr: bool,
        is_null_ok: bool,
        is_genai: bool = False;

    def postinit -> None;

    has as_attr_list: list[AstSymbolNode] { getter; }
}

obj AtomUnit(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has value: Expr | YieldExpr | Ability;

    def postinit -> None;
}

obj YieldExpr(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has expr: (Expr | None),
        with_from: bool;

    def postinit -> None;
}

obj FuncCall(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Expr,
        params: (Sequence[(Expr | KWPair)] | None),
        genai_call: (Expr | None),
        call_kind: (str | None) = None,
        chunks_recv_type: (str | None) = None,
        callee_decl: (Ability | None) postinit;

    def postinit -> None;
}

obj Slice(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has start: (Expr | None),
        stop: (Expr | None),
        step: (Expr | None);

    def postinit -> None;
}

obj IndexSlice(AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has slices: list[Slice],
        is_range: bool;

    def postinit -> None;
}

obj EdgeRefTrailer(Expr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has chain: list[(Expr | FilterCompr)],
        edges_only: bool,
        is_async: bool;

    def postinit -> None;
}

obj EdgeOpRef(WalkerStmtOnlyNode, AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has filter_cond: (FilterCompr | None),
        edge_dir: EdgeDir;

    def postinit -> None;
}

obj DisconnectOp(WalkerStmtOnlyNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has edge_spec: EdgeOpRef;

    def postinit -> None;
}

obj ConnectOp(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has conn_type: (Expr | None),
        conn_assign: (AssignCompr | None),
        edge_dir: EdgeDir;

    def postinit -> None;
}

obj FilterCompr(AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has f_type: (Expr | None),
        compares: Sequence[Expr];

    def postinit -> None;
}

obj AssignCompr(AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has assigns: Sequence[KWPair];

    def postinit -> None;
}

obj JsxElement(AtomExpr) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: (JsxElementName | None),
        attributes: (Sequence[JsxAttribute] | None),
        children: (Sequence[(JsxChild | JsxElement)] | None),
        is_self_closing: bool,
        is_fragment: bool,
        dynamic_tag: (Expr | None) = None;

    def postinit -> None;
    def get_body_start_line -> (int | None);
    def get_body_end_line -> (int | None);
}

obj JsxElementName(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has parts: Sequence[(Name | Token)];

    def postinit -> None;
}

obj JsxAttribute(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;
    def postinit -> None;
}

obj JsxSpreadAttribute(JsxAttribute) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has expr: Expr;

    def postinit -> None;
}

obj JsxNormalAttribute(JsxAttribute) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: (Name | Token),
        value: String | Expr | None,
        is_shorthand: bool = False;

    def postinit -> None;
}

obj JsxChild(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;
    def postinit -> None;
}

obj JsxText(JsxChild) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has value: (str | Token);

    def postinit -> None;
    def get_normalized_text -> str;
}

obj JsxExpression(JsxChild) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has expr: Expr;

    def postinit -> None;
}

obj JsxSlot(JsxChild) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: list[UniNode];

    def postinit -> None;
}

obj JsxComment(JsxChild) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has value: Token;

    def postinit -> None;
}

obj MatchStmt(CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Expr,
        cases: list[MatchCase];

    def postinit -> None;
}

obj MatchCase(CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has pattern: MatchPattern,
        guard: (Expr | None),
        body: list[CodeBlockStmt];

    def postinit -> None;
}

obj SwitchStmt(CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Expr,
        cases: list[SwitchCase];

    def postinit -> None;
}

obj SwitchCase(CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has pattern: (MatchPattern | None),
        body: list[CodeBlockStmt];

    def postinit -> None;
}

obj MatchOr(MatchPattern) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has patterns: list[MatchPattern];

    def postinit -> None;
}

obj MatchAs(MatchPattern) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: NameAtom,
        pattern: (MatchPattern | None);

    def postinit -> None;
}

obj MatchWild(MatchPattern) {
    def accept_enter(v: UniPass) -> None;
    def accept_exit(v: UniPass) -> None;
}

obj MatchValue(MatchPattern) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has value: Expr;

    def postinit -> None;
}

obj MatchSingleton(MatchPattern) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has value: (Bool | Null);

    def postinit -> None;
}

obj MatchSequence(MatchPattern) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has values: list[MatchPattern];

    def postinit -> None;
}

obj MatchMapping(MatchPattern) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has values: list[(MatchKVPair | MatchStar)];

    def postinit -> None;
}

obj MatchKVPair(MatchPattern) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has key: MatchPattern | NameAtom | AtomExpr,
        value: MatchPattern;

    def postinit -> None;
}

obj MatchStar(MatchPattern) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: NameAtom,
        is_list: bool;

    def postinit -> None;
}

obj MatchArch(MatchPattern) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: (AtomTrailer | NameAtom),
        arg_patterns: (Sequence[MatchPattern] | None),
        kw_patterns: (Sequence[MatchKVPair] | None);

    def postinit -> None;
}

obj Token(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

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

obj Name(Token, NameAtom) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

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
        ret.parent = nd.parent;
        ret.name_of = set_name_of or ret;
        return ret;
    }
}

obj SpecialVarRef(Name) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has orig: Name postinit;

    def init(var: Name, is_enum_stmt: bool = False) -> None;
    def py_resolve_name -> str;
}

obj Literal(Token, AtomExpr) {
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
}

obj BuiltinType(Name, Literal) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    with entry {
        SYMBOL_TYPE = SymbolType.VAR;
    }

    has lit_value: type { getter; }
}

obj Float(Literal) {
    def accept_exit(v: UniPass) -> None;

    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    has lit_value: float { getter; }
}

obj Int(Literal) {
    def accept_exit(v: UniPass) -> None;

    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    has lit_value: int { getter; }
}

obj String(Literal) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    with entry {
        SYMBOL_TYPE = SymbolType.STRING;
    }

    has lit_value: str | bytes { getter; }
}

obj Bool(Literal) {
    def accept_exit(v: UniPass) -> None;

    with entry {
        SYMBOL_TYPE = SymbolType.BOOL;
    }

    has lit_value: bool { getter; }
}

obj Null(Literal) {
    def accept_exit(v: UniPass) -> None;

    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    has lit_value: None { getter; }
}

obj Ellipsis(Literal) {
    def accept_exit(v: UniPass) -> None;

    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    has lit_value: object { getter; }
}

obj EmptyToken(Token) {
    def init(orig_src: (Source | None) = None) -> None;
}

obj Semi(Token, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
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
}

obj CommentToken(Token) {
    def accept_exit(v: UniPass) -> None;
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
}

obj Source(EmptyToken) {
    has comments: list[CommentToken] postinit,
        inline_suppressions: dict[int, set[str]] postinit,
        file_path: str postinit,
        _hash: str postinit;

    def init(source: str, mod_path: str) -> None;

    has code: str { getter; }
    has hash: str { getter; }
}

obj PythonModuleAst(EmptyToken) {
    has ast: object postinit,
        orig_src: Source postinit,
        file_path: str postinit;

    def init(ast: object, orig_src: Source) -> None;
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

obj CModuleAst(EmptyToken) {
    has orig_src: Source postinit,
        file_path: str postinit;

    def init(ast: object, orig_src: Source) -> None;
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
