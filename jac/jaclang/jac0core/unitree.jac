import ast as ast3;
import builtins;
import os;
import from collections.abc { Callable, Sequence }
import from copy { copy }
import from enum { IntEnum }
import from hashlib { md5 }
import from types { EllipsisType }
import from typing { Any, cast }
import from jaclang.jac0core.bccache { discover_base_file }
import type from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.codeinfo { CodeGenTarget, CodeLocInfo }
import from jaclang.jac0core.constant {
    DELIM_MAP,
    CodeContext,
    EdgeDir,
    OwnershipKind,
    SymbolAccess,
    SymbolStorage,
    SymbolType
}
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.jac0core.constant { JacSemTokenModifier as SemTokMod }
import from jaclang.jac0core.constant { JacSemTokenType as SemTokType }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.modresolver { resolve_relative_path }
import type from jaclang.compiler.type_system.types { TypeBase }

import from jaclang.jac0core.treeprinter {
    print_ast_tree,
    print_symtab_tree,
    printgraph_ast_tree,
    printgraph_symtab_tree
}

obj UniNode {
    has kid: Sequence[UniNode] = [],
        parent: (UniNode | None) by postinit,
        __sub_node_tab: (dict[(type, list[UniNode])] | None) by postinit,
        _in_mod_nodes: list[UniNode] by postinit,
        _gen: (CodeGenTarget | None) by postinit,
        loc: CodeLocInfo by postinit;

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
    def get_all_sub_nodes[T](typ: type[T]) -> list[T];
    def find_parent_of_type[T](typ: type[T]) -> (T | None);
    def parent_of_type[T](typ: type[T]) -> T;
    def in_client_context -> bool;
    def in_native_context -> bool;
    def to_dict -> dict[(str, str)];
    def pp(depth: (int | None) = None) -> str;
    def printgraph -> str;
    def flatten -> list[UniNode];
    def unparse -> str;
}

obj Symbol {
    has defn: list[NameAtom] by postinit,
        uses: list[NameAtom] by postinit,
        access: SymbolAccess by postinit,
        parent_tab: (UniScopeNode | None) by postinit,
        imported: bool by postinit,
        semstr: str by postinit,
        ownership: OwnershipKind = OwnershipKind.NONE;

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
    has scope_name: str by postinit,
        parent_scope: (UniScopeNode | None) by postinit,
        kid_scope: list[UniScopeNode] by postinit,
        names_in_scope: dict[(str, Symbol)] by postinit,
        names_in_scope_overload: dict[(str, list[Symbol])] by postinit;

    def _init_scope(name: str, parent_scope: (UniScopeNode | None) = None) -> None;
    static def get_python_scoping_nodes -> tuple[(type[UniScopeNode], ...)] {
        return (Module, Enum, Archetype, Ability, ImplDef, Test);
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
    def update_py_ctx_for_def(nd: AstSymbolNode) -> None;
    def sym_pp(depth: (int | None) = None) -> str;
    def sym_printgraph -> str;
    def __repr__ -> str;
}

obj AstSymbolNode(UniNode) {
    has name_spec: NameAtom by postinit,
        semstr: str by postinit;

    def _init_symbol(
        sym_name: str, name_spec: NameAtom, sym_category: SymbolType
    ) -> None;

    has sym: (Symbol | None) { getter; }
    has sym_name: str { getter; }
    has sym_category: SymbolType { getter; }
    has py_ctx_func: type[ast3.AST] { getter; }
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
    has code_context: CodeContext by postinit;

    def postinit -> None;
    def _source_context_token -> (Token | None);
}

obj AstDocNode(UniNode) {
    has doc: (String | None) = None;
}

obj AstAsyncNode(UniNode) {
    has is_async: bool = False;
}

obj AstElseBodyNode(UniNode) {
    has else_body: (ElseStmt | ElseIf | None) = None;
}

obj AstTypedVarNode(UniNode) {
    has type_tag: (SubTag[Expr] | None) = None;
}

obj WalkerStmtOnlyNode(UniNode) {
    has from_walker: bool by postinit;

    def postinit -> None;
}

obj UniCFGNode(UniNode) {
    has bb_in: list[UniCFGNode] by postinit,
        bb_out: list[UniCFGNode] by postinit,
        affected_symbols: set[str] by postinit;

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
    has _type_sym_tab: (UniScopeNode | None) by postinit,
        type: (TypeBase | None) by postinit,
        attached_tokens: (list[Token] | None) by postinit;

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

obj AstImplNeedingNode[T](AstSymbolNode) {
    has body: (T | None);
    has needs_impl: bool { getter; }
}

obj NameAtom(AtomExpr, EnumBlockStmt) {
    has name_of: AstSymbolNode by postinit,
        _sym: (Symbol | None) by postinit,
        _sym_name: str by postinit,
        _sym_category: SymbolType by postinit,
        _py_ctx_func: type[ast3.expr_context] by postinit,
        is_getattr_resolved: bool = False;

    def postinit -> None;

    has sym: (Symbol | None) { getter; setter(sym: Symbol); }
    has sym_name: str { getter; }
    has sym_category: SymbolType { getter; }

    def create_symbol(
        access: SymbolAccess,
        parent_tab: (UniScopeNode | None) = None,
        imported: bool = False
    ) -> Symbol;

    has clean_type: str { getter; }
    has py_ctx_func: type[ast3.expr_context] {
        getter;
        setter(py_ctx_func: type[ast3.expr_context]);
    }

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
        is_raised_from_py: bool = False;

    def postinit -> None;

    has annexable_by: (str | None) { getter; }

    def format -> str;
    def unparse(requires_format: bool = True) -> str;
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
        main: Module by postinit,
        hub: dict[(str, Module)] by postinit;

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

obj TypeAlias(ContextAwareNode, AstAccessNode, ElementStmt, AstSymbolNode, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: Name,
        type_params: (Sequence[TypeParam] | None),
        value: Expr;

    def postinit -> None;
}

obj GlobalVars(ContextAwareNode, ElementStmt, AstAccessNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has assignments: Sequence[Assignment],
        is_frozen: bool;

    def postinit -> None;
}

obj Test(ContextAwareNode, AstSymbolNode, ElementStmt, CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    with entry {
        TEST_COUNT = 0;
    }

    has name: (Name | Token),
        body: Sequence[CodeBlockStmt],
        description: (String | None) = None,
        decorators: (Sequence[Expr] | None) = None;

    def postinit -> None;
}

obj ModuleCode(ContextAwareNode, ElementStmt, ArchBlockStmt, EnumBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: (Name | None),
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

obj ClientBlock(ElementStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: Sequence[ElementStmt],
        implicit: bool = False;

    def postinit -> None;
}

obj ServerBlock(ElementStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: Sequence[ElementStmt],
        implicit: bool = False;

    def postinit -> None;
}

obj NativeBlock(ElementStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: Sequence[ElementStmt],
        implicit: bool = False;

    def postinit -> None;
}

obj PyInlineCode(ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has code: Token;

    def postinit -> None;
}

obj Import(ContextAwareNode, ElementStmt, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has from_loc: (ModulePath | None),
        items: (Sequence[ModuleItem] | Sequence[ModulePath]),
        is_absorb: bool,
        is_typed: bool = False,
        clib_decls: (Sequence[UniNode] | None) = None,
        hint: (SubTag[Token] | None) by postinit;

    def postinit -> None;

    has is_jac: bool { getter; }
    has __jac_detected: bool { getter; }
}

obj ModulePath(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has path: (Sequence[(Name | String)] | None),
        level: int,
        alias: (Name | None),
        abs_path: (str | None) by postinit;

    def postinit -> None;

    has is_import_from: bool { getter; }
    has dot_path_str: str { getter; }
    has base_module_name: str { getter; }

    def resolve_relative_path(target_item: (str | None) = None) -> str;
    def resolve_relative_path_list -> list[str];
    def native_bundled_path -> (str | None);
}

obj ModuleItem(UniNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: (Name | Token),
        alias: (Name | None),
        abs_path: (str | None) by postinit;

    def postinit -> None;

    has from_parent: Import { getter; }
    has from_mod_path: ModulePath { getter; }

    def resolve_relative_path -> str;
}

obj Archetype(ContextAwareNode, ArchSpec, AstAccessNode, ArchBlockStmt, AstImplNeedingNode, UniScopeNode, UniCFGNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: Name,
        arch_type: Token,
        base_classes: (Sequence[Expr] | None),
        type_params: (Sequence[TypeParam] | None) = None,
        src_endpoint: (Expr | None) = None,
        tgt_endpoint: (Expr | None) = None;

    def postinit -> None;
    def _get_impl_resolved_body -> list;

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

obj SemDef(ElementStmt, AstSymbolNode, UniScopeNode) {
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

class ParamKind(IntEnum) {
    with entry {
        POSONLY = 0;
        NORMAL = 1;
        VARARG = 2;
        KWONLY = 3;
        KWARG = 4;
    }
}

obj ParamVar(AstSymbolNode, AstTypedVarNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has name: Name,
        unpack: (Token | None),
        value: (Expr | None),
        param_kind: ParamKind by postinit;

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

obj RegionStmt(CodeBlockStmt, UniScopeNode) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has body: Sequence[CodeBlockStmt];

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
        in_fstring: bool;

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

    has py_ast_targets: list[ast3.AST] { getter; }
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

    has expr: (Expr | None);

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

obj GlobalStmt(CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Sequence[NameAtom];

    def postinit -> None;
}

obj NonLocalStmt(GlobalStmt) {
    def accept_enter(v: UniPass) -> None;
    def accept_exit(v: UniPass) -> None;
}

obj Assignment(AstTypedVarNode, EnumBlockStmt, CodeBlockStmt) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    has target: Sequence[Expr],
        value: Expr | YieldExpr | None,
        mutable: bool = True,
        aug_op: (Token | None) = None,
        na_move_lowerable: bool = False;

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
        callee_decl: (Ability | None) by postinit;

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
        compares: Sequence[CompareExpr];

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

    has orig_src: Source by postinit,
        line_no: int by postinit,
        end_line: int by postinit,
        c_start: int by postinit,
        c_end: int by postinit,
        pos_start: int by postinit,
        pos_end: int by postinit,
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
    def unparse -> str;
}

obj Name(Token, NameAtom) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;
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

    has orig: Name by postinit;

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

    has lit_value:
        int | str | bytes | float | bool | None | Callable[([], Any)] | EllipsisType {
        getter;
    }
}

obj BuiltinType(Name, Literal) {
    def accept_exit(v: UniPass) -> None;
    def accept_enter(v: UniPass) -> None;

    with entry {
        SYMBOL_TYPE = SymbolType.VAR;
    }

    has lit_value: Callable[([], Any)] { getter; }
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

    has lit_value: EllipsisType { getter; }
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
        kid: Sequence[UniNode],
        is_inline: bool = False
    ) -> None;
}

obj Source(EmptyToken) {
    has comments: list[CommentToken] by postinit,
        inline_suppressions: dict[int, set[str]] by postinit,
        file_path: str by postinit;

    def init(source: str, mod_path: str) -> None;

    has code: str { getter; }
}

obj PythonModuleAst(EmptyToken) {
    has orig_src: Source by postinit,
        file_path: str by postinit;

    def init(ast: ast3.Module, orig_src: Source) -> None;
}
