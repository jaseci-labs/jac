"""Abstract class for IR Passes for Jac."""
import ast as ast3;
import builtins;
import os;
import from collections.abc { Callable, Sequence }
import from copy { copy }
import from enum { IntEnum }
import from hashlib { md5 }
import from types { EllipsisType }
import from typing { TYPE_CHECKING, Any, cast }
import from jaclang.jac0core.bccache { discover_base_file }
import from jaclang.jac0core.codeinfo { CodeGenTarget, CodeLocInfo }
import from jaclang.jac0core.constant {
    DELIM_MAP,
    CodeContext,
    EdgeDir,
    SymbolAccess,
    SymbolType
}
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.jac0core.constant { JacSemTokenModifier as SemTokMod }
import from jaclang.jac0core.constant { JacSemTokenType as SemTokType }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.modresolver { resolve_relative_path }

with entry {
    if TYPE_CHECKING {
        import from jaclang.compiler.type_system.types { TypeBase }
    }
}

import from jaclang.jac0core.treeprinter {
    print_ast_tree,
    print_symtab_tree,
    printgraph_ast_tree,
    printgraph_symtab_tree
}

"""Abstract syntax tree node for Jac."""
obj UniNode {
    """Initialize ast."""
    has kid: Sequence[UniNode] = [],
        parent: (UniNode | None) by postinit,
        __sub_node_tab: (dict[(type, list[UniNode])] | None) by postinit,
        _in_mod_nodes: list[UniNode] by postinit,
        _gen: (CodeGenTarget | None) by postinit,
        loc: CodeLocInfo by postinit;

    def postinit -> None;
    @property
    def gen -> CodeGenTarget {
        if (self._gen is None) {
            self._gen = CodeGenTarget();
        }
        return self._gen;
    }

    @gen.setter
    def gen(value: CodeGenTarget) {
        self._gen = value;
    }

    @property
    def _sub_node_tab -> dict[(type, list[UniNode])];

    def _construct_sub_node_tab -> None;
    @property
    def sym_tab -> UniScopeNode;

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
    def get_all_sub_nodes[T](typ: type[T], brute_force: bool = True) -> list[T];
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

"""Symbol."""
obj Symbol {
    has defn: list[NameAtom] by postinit,
        uses: list[NameAtom] by postinit,
        access: SymbolAccess by postinit,
        parent_tab: (UniScopeNode | None) by postinit,
        imported: bool by postinit,
        semstr: str by postinit;

    def init(
        defn: NameAtom,
        access: SymbolAccess,
        parent_tab: (UniScopeNode | None) = None,
        imported: bool = False
    ) -> None;

    @property
    def decl -> NameAtom;

    @property
    def sym_name -> str;

    @property
    def sym_type -> SymbolType;

    @property
    def sym_dotted_name -> str;

    @property
    def symbol_table -> (UniScopeNode | None);

    def add_defn(nd: NameAtom) -> None;
    def add_use(nd: NameAtom) -> None;
    def __repr__ -> str;
}

"""Represents an inherited symbol table for selective imports."""
obj InheritedSymbolTable {
    has base_symbol_table: UniScopeNode,
        load_all_symbols: bool = False,
        symbols: list[str] = [];
}

"""Symbol Table."""
obj UniScopeNode(UniNode) {
    """Initialize."""
    has scope_name: str by postinit,
        parent_scope: (UniScopeNode | None) by postinit,
        kid_scope: list[UniScopeNode] by postinit,
        names_in_scope: dict[(str, Symbol)] by postinit,
        names_in_scope_overload: dict[(str, list[Symbol])] by postinit;

    def _init_scope(name: str, parent_scope: (UniScopeNode | None) = None) -> None;
    def get_type -> SymbolType;
    def get_parent -> (UniScopeNode | None);
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

"""Nodes that have link to a symbol in symbol table."""
obj AstSymbolNode(UniNode) {
    has name_spec: NameAtom by postinit,
        semstr: str by postinit;

    def _init_symbol(
        sym_name: str, name_spec: NameAtom, sym_category: SymbolType
    ) -> None;

    @property
    def sym -> (Symbol | None);

    @property
    def sym_name -> str;

    @property
    def sym_category -> SymbolType;

    @property
    def py_ctx_func -> type[ast3.AST];

    @property
    def type_sym_tab -> (UniScopeNode | None);
}

"""Nodes that have link to a symbol in symbol table."""
obj AstSymbolStubNode(AstSymbolNode) {
    def _init_stub(sym_type: SymbolType) -> None;
}

"""Nodes that have access."""
obj AstAccessNode(UniNode) {
    has access: (SubTag[Token] | None) = None;

    @property
    def access_type -> SymbolAccess;

    @property
    def public_access -> bool;
}

"""Base class for nodes that can be marked with execution context
(client/server)."""
obj ContextAwareNode(UniNode) {
    has code_context: CodeContext by postinit;

    def postinit -> None;
    def _source_context_token -> (Token | None);
}

"""Nodes that have access."""
obj AstDocNode(UniNode) {
    has doc: (String | None) = None;
}

"""Nodes that have access."""
obj AstAsyncNode(UniNode) {
    has is_async: bool = False;
}

"""Nodes that have access."""
obj AstElseBodyNode(UniNode) {
    has else_body: (ElseStmt | ElseIf | None) = None;
}

"""Nodes that have access."""
obj AstTypedVarNode(UniNode) {
    has type_tag: (SubTag[Expr] | None) = None;
}

"""WalkerStmtOnlyNode node type for Jac Ast."""
obj WalkerStmtOnlyNode(UniNode) {
    has from_walker: bool by postinit;

    def postinit -> None;
}

"""BasicBlockStmt node type for Jac Uniir."""
obj UniCFGNode(UniNode) {
    has bb_in: list[UniCFGNode] by postinit,
        bb_out: list[UniCFGNode] by postinit,
        affected_symbols: set[str] by postinit;

    def postinit -> None;
    def get_head -> UniCFGNode;
    def get_tail -> UniCFGNode;
}

"""A CFG node that branches on a condition with true/false targets.
Used by CfgExpr wrappers inside BoolExpr operands and IfElseExpr branches."""
obj ConditionalNode(UniCFGNode) {
    has sc_true_target: (UniCFGNode | None) = None,
        sc_false_target: (UniCFGNode | None) = None;

    def postinit -> None;
}

"""Expression is a combination of values, variables operators and fuctions that
are evaluated to produce a value.

    1. Literal Expressions.
    2. Binary Operations.
    3. Unary Operations.
    4. Ternary Operations.
    5. Attribute Access.
    6. Subscript.
    7. Call Expression.
    8. List Value.
    9. Dictionary Value.
    10. Set Value.
    11. Generator Expression.
    12. Lambda Expression.
    13. Conditional Expression.
    14. Yield Expression.
    etc.

    An expression can be assigned to a variable, passed to a function, or
    retuurend from a function.

    Examples:
        "hello world"         # literal.
        <expr>(<expr>, ...);  # call.
        <expr>.NAME           # attribute.
        <expr>[<expr>]        # subscript.
        <expr> if <expr> else <expr>  # ternary.
    """
obj Expr(UniNode) {
    has _type_sym_tab: (UniScopeNode | None) by postinit,
        type: (TypeBase | None) by postinit,
        attached_tokens: (list[Token] | None) by postinit,
        backend_type_tag: (str | None) by postinit;

    def postinit -> None;
    @property
    def type_sym_tab -> (UniScopeNode | None) {
        return self._type_sym_tab;
    }

    @type_sym_tab.setter
    def type_sym_tab(type_sym_tab: UniScopeNode) {
        self._type_sym_tab = type_sym_tab;
    }
}

"""Wrapper that promotes an expression to a CFG-participating conditional node.
Used for each BoolExpr operand and each IfElseExpr branch so that type
narrowing can be resolved with a single backward CFG walk."""
obj CfgExpr(Expr, ConditionalNode) {
    has expr: Expr;

    def postinit -> None;
}

"""AtomExpr node type for Jac Ast."""
obj AtomExpr(Expr, AstSymbolStubNode) {}

"""ElementStmt node type for Jac Ast."""
obj ElementStmt(AstDocNode) {}

"""ArchBlockStmt node type for Jac Ast."""
obj ArchBlockStmt(UniNode) {}

"""EnumBlockStmt node type for Jac Ast."""
obj EnumBlockStmt(UniNode) {
    has is_enum_stmt: bool = False;
}

"""CodeBlockStmt node type for Jac Ast."""
obj CodeBlockStmt(UniCFGNode) {
    def postinit -> None;
}

"""AstImplNeedingNode node type for Jac Ast."""
obj AstImplNeedingNode[T](AstSymbolNode) {
    has body: (T | None);

    @property
    def needs_impl -> bool;
}

"""NameAtom node type for Jac Ast."""
obj NameAtom(AtomExpr, EnumBlockStmt) {
    has name_of: AstSymbolNode by postinit,
        _sym: (Symbol | None) by postinit,
        _sym_name: str by postinit,
        _sym_category: SymbolType by postinit,
        _py_ctx_func: type[ast3.expr_context] by postinit,
        is_getattr_resolved: bool = False;

    def postinit -> None;
    @property
    def sym -> (Symbol | None) {
        return self._sym;
    }

    @sym.setter
    def sym(sym: Symbol) {
        self._sym = sym;
    }

    @property
    def sym_name -> str;

    @property
    def sym_category -> SymbolType;

    def create_symbol(
        access: SymbolAccess,
        parent_tab: (UniScopeNode | None) = None,
        imported: bool = False
    ) -> Symbol;

    @property
    def clean_type -> str;

    @property
    def py_ctx_func -> type[ast3.expr_context] {
        return self._py_ctx_func;
    }

    @py_ctx_func.setter
    def py_ctx_func(py_ctx_func: type[ast3.expr_context]) {
        self._py_ctx_func = py_ctx_func;
    }

    @property
    def sem_token -> (tuple[(SemTokType, SemTokMod)] | None);
}

"""ArchSpec node type for Jac Ast."""
obj ArchSpec(ElementStmt, CodeBlockStmt, AstSymbolNode, AstAsyncNode, AstDocNode) {
    has decorators: (Sequence[Expr] | None);

    def postinit -> None;
}

"""MatchPattern node type for Jac Ast."""
obj MatchPattern(UniNode) {}

"""SubTag node type for Jac Ast."""
obj SubTag[T](UniNode) {
    has tag: T;

    def postinit -> None;
}

"""Whole Program node type for Jac Ast."""
obj Module(AstDocNode, UniScopeNode) {
    has name: str,
        source: Source,
        body: Sequence[ElementStmt | String | EmptyToken],
        terminals: list[Token],
        stub_only: bool = False,
        impl_mod: list[Module] = [],
        test_mod: list[Module] = [],
        variant_mod: list[Module] = [],
        src_terminals: list[Token] = [],
        is_raised_from_py: bool = False;

    def postinit -> None;
    @property
    def annexable_by -> (str | None);

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

    static def get_href_path(nd: UniNode) -> str {
        parent = nd.find_parent_of_type(Module);
        mod_list: list[(Module | Archetype)] = [];
        if isinstance(nd, (Module, Archetype)) {
            mod_list.append(nd);
        }
        while (parent is not None) {
            mod_list.append(parent);
            parent = parent.find_parent_of_type(Module);
        }
        mod_list.reverse();
        return '.'.join(
            p.name if isinstance(p, Module) else p.name.sym_name for p in mod_list
        );
    }
}

"""Whole Program node type for Jac Ast."""
obj ProgramModule(UniNode) {
    has main_mod: (Module | None) = None,
        main: Module by postinit,
        hub: dict[(str, Module)] by postinit;

    def postinit -> None;
}

"""TypeParam node type for Jac Ast: T, T: Bound, T = Default."""
obj TypeParam(AstSymbolNode, UniNode) {
    has name: Name,
        bound: (Expr | None),
        default_val: (Expr | None);

    def postinit -> None;
}

"""TypeAlias node type for Jac Ast: type Name[T, E = X] = TypeExpr;"""
obj TypeAlias(ContextAwareNode, AstAccessNode, ElementStmt, AstSymbolNode, UniScopeNode) {
    has name: Name,
        type_params: (Sequence[TypeParam] | None),
        value: Expr;

    def postinit -> None;
}

"""GlobalVars node type for Jac Ast."""
obj GlobalVars(ContextAwareNode, ElementStmt, AstAccessNode) {
    has assignments: Sequence[Assignment],
        is_frozen: bool;

    def postinit -> None;
}

"""Test node type for Jac Ast."""
obj Test(ContextAwareNode, AstSymbolNode, ElementStmt, CodeBlockStmt, UniScopeNode) {
    with entry {
        TEST_COUNT = 0;
    }

    has name: (Name | Token),
        body: Sequence[CodeBlockStmt],
        description: (String | None) = None,
        decorators: (Sequence[Expr] | None) = None;

    def postinit -> None;
}

"""ModuleCode node type for Jac Ast."""
obj ModuleCode(ContextAwareNode, ElementStmt, ArchBlockStmt, EnumBlockStmt) {
    has name: (Name | None),
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

"""ClientBlock node type for cl { ... } blocks in Jac Ast."""
obj ClientBlock(ElementStmt) {
    has body: Sequence[ElementStmt],
        implicit: bool = False;

    def postinit -> None;
}

"""ServerBlock node type for sv { ... } blocks in Jac Ast."""
obj ServerBlock(ElementStmt) {
    has body: Sequence[ElementStmt],
        implicit: bool = False;

    def postinit -> None;
}

"""NativeBlock node type for na { ... } blocks in Jac Ast."""
obj NativeBlock(ElementStmt) {
    has body: Sequence[ElementStmt],
        implicit: bool = False;

    def postinit -> None;
}

"""PyInlineCode node type for Jac Ast."""
obj PyInlineCode(ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt) {
    has code: Token;

    def postinit -> None;
}

"""Import node type for Jac Ast."""
obj Import(ContextAwareNode, ElementStmt, CodeBlockStmt) {
    has from_loc: (ModulePath | None),
        items: (Sequence[ModuleItem] | Sequence[ModulePath]),
        is_absorb: bool,
        clib_decls: (Sequence[UniNode] | None) = None,
        hint: (SubTag[Token] | None) by postinit;

    def postinit -> None;
    @property
    def is_py -> bool;

    @property
    def is_jac -> bool;

    @property
    def __jac_detected -> bool;
}

"""ModulePath node type for Jac Ast."""
obj ModulePath(UniNode) {
    has path: (Sequence[(Name | String)] | None),
        level: int,
        alias: (Name | None),
        abs_path: (str | None) by postinit;

    def postinit -> None;
    @property
    def is_import_from -> bool;

    @property
    def dot_path_str -> str;

    def resolve_relative_path(target_item: (str | None) = None) -> str;
    def resolve_relative_path_list -> list[str];
}

"""ModuleItem node type for Jac Ast.

    Name can be either:
    - Name: for regular named imports (e.g., useState, axios)
    - Token (KW_DEFAULT): for default imports (Category 2)
    - Token (STAR_MUL): for namespace imports (Category 4)
    """
obj ModuleItem(UniNode) {
    has name: (Name | Token),
        alias: (Name | None),
        abs_path: (str | None) by postinit;

    def postinit -> None;
    @property
    def from_parent -> Import;

    @property
    def from_mod_path -> ModulePath;

    def resolve_relative_path -> str;
}

"""ObjectArch node type for Jac Ast."""
obj Archetype(ContextAwareNode, ArchSpec, AstAccessNode, ArchBlockStmt, AstImplNeedingNode, UniScopeNode, UniCFGNode) {
    has name: Name,
        arch_type: Token,
        base_classes: (Sequence[Expr] | None),
        type_params: (Sequence[TypeParam] | None) = None;

    def postinit -> None;
    def _get_impl_resolved_body -> list;
    @property
    def is_abstract -> bool;

    def get_has_vars -> list[HasVar];
    def get_methods -> list[Ability];
}

"""AstImplOnlyNode node type for Jac Ast."""
obj ImplDef(ContextAwareNode, CodeBlockStmt, ElementStmt, ArchBlockStmt, AstSymbolNode, UniScopeNode) {
    has decorators: (Sequence[Expr] | None),
        target: Sequence[NameAtom],
        spec: (Sequence[Expr] | FuncSignature | EventSignature | None),
        body: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr,
        decl_link: (UniNode | None) = None;

    def postinit -> None;
    def create_impl_name_node -> Name;
}

"""SemDef node type for Jac Ast."""
obj SemDef(ElementStmt, AstSymbolNode, UniScopeNode) {
    has target: Sequence[NameAtom],
        value: String;

    def postinit -> None;
    def create_sem_name_node -> Name;
}

"""Enum node type for Jac Ast.

`value_type` holds the typed-base shorthand `: T` from `enum X: T { ... }`
(desugars to `class X(IntEnum)` for int, `class X(StrEnum)` for str, and the
mixin pattern `class X(T, Enum)` for everything else). `base_classes` holds
the parenthesized form `enum X(B1, B2) { ... }`. The two are mutually
exclusive at the grammar level — the parser never populates both.
"""
obj Enum(ContextAwareNode, ArchSpec, AstAccessNode, AstImplNeedingNode, ArchBlockStmt, UniScopeNode) {
    has name: Name,
        value_type: (Expr | None),
        base_classes: (Sequence[Expr] | None);

    def postinit -> None;
}

"""Ability node type for Jac Ast."""
obj Ability(ContextAwareNode, AstAccessNode, ElementStmt, AstAsyncNode, ArchBlockStmt, CodeBlockStmt, AstImplNeedingNode, UniScopeNode) {
    has name_ref: (NameAtom | None),
        is_override: bool,
        is_static: bool,
        is_classmethod: bool,
        is_abstract: bool,
        signature: FuncSignature | EventSignature | None,
        decorators: (Sequence[Expr] | None) = None,
        type_params: (Sequence[TypeParam] | None) = None;

    def postinit -> None;
    @property
    def is_method -> bool;

    @property
    def is_cls_method -> bool;

    @property
    def is_def -> bool;

    @property
    def method_owner -> Archetype | Enum | None;

    @property
    def is_genai_ability -> bool;

    def get_pos_argc_range -> tuple[(int, int)];
    def py_resolve_name -> str;
}

"""FuncSignature node type for Jac Ast."""
obj FuncSignature(UniNode) {
    has posonly_params: Sequence[ParamVar],
        params: (Sequence[ParamVar] | None),
        varargs: (ParamVar | None),
        kwonlyargs: Sequence[ParamVar],
        kwargs: (ParamVar | None),
        return_type: (Expr | None);

    def postinit -> None;
    def get_parameters -> list[ParamVar];
    @property
    def is_static -> bool;

    @property
    def is_in_py_class -> bool;
}

"""EventSignature node type for Jac Ast."""
obj EventSignature(WalkerStmtOnlyNode) {
    has event: Token,
        arch_tag_info: (Expr | None);

    def postinit -> None;
}

"""Parameter kinds."""
class ParamKind(IntEnum) {
    with entry {
        POSONLY = 0;
        NORMAL = 1;
        VARARG = 2;
        KWONLY = 3;
        KWARG = 4;
    }
}

"""ParamVar node type for Jac Ast."""
obj ParamVar(AstSymbolNode, AstTypedVarNode) {
    has name: Name,
        unpack: (Token | None),
        value: (Expr | None),
        param_kind: ParamKind by postinit;

    def postinit -> None;
    @property
    def is_vararg -> bool;

    @property
    def is_kwargs -> bool;
}

"""ArchHas node type for Jac Ast."""
obj ArchHas(AstAccessNode, AstDocNode, ArchBlockStmt, CodeBlockStmt) {
    has is_static: bool,
        vars: Sequence[HasVar],
        is_frozen: bool;

    def postinit -> None;
}

"""HasVar node type for Jac Ast."""
obj HasVar(AstSymbolNode, AstTypedVarNode) {
    has name: Name,
        value: (Expr | None),
        defer: bool;

    def postinit -> None;
}

"""TypedCtxBlock node type for Jac Ast."""
obj TypedCtxBlock(CodeBlockStmt, WalkerStmtOnlyNode, UniScopeNode) {
    has type_ctx: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

"""IfStmt node type for Jac Ast."""
obj IfStmt(CodeBlockStmt, AstElseBodyNode, UniScopeNode) {
    has condition: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

"""ElseIf node type for Jac Ast."""
obj ElseIf(IfStmt) {}

"""ElseStmt node type for Jac Ast."""
obj ElseStmt(UniScopeNode) {
    has body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

"""ExprStmt node type for Jac Ast."""
obj ExprStmt(CodeBlockStmt) {
    has expr: Expr,
        in_fstring: bool;

    def postinit -> None;
}

"""TryStmt node type for Jac Ast."""
obj TryStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has body: Sequence[CodeBlockStmt],
        excepts: Sequence[Except],
        finally_body: (FinallyStmt | None);

    def postinit -> None;
}

"""Except node type for Jac Ast."""
obj Except(CodeBlockStmt, UniScopeNode) {
    has ex_type: Expr,
        name: (Name | None),
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

"""FinallyStmt node type for Jac Ast."""
obj FinallyStmt(CodeBlockStmt, UniScopeNode) {
    has body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

"""IterForStmt node type for Jac Ast."""
obj IterForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has iter: Assignment,
        condition: Expr,
        count_by: Assignment,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

"""InForStmt node type for Jac Ast."""
obj InForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has target: Expr,
        collection: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

"""WhileStmt node type for Jac Ast."""
obj WhileStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has condition: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

"""WithStmt node type for Jac Ast."""
obj WithStmt(AstAsyncNode, CodeBlockStmt, UniScopeNode) {
    has exprs: Sequence[ExprAsItem],
        body: Sequence[CodeBlockStmt];

    def postinit -> None;
}

"""ExprAsItem node type for Jac Ast."""
obj ExprAsItem(UniNode) {
    has expr: Expr,
        alias: (Expr | None);

    def postinit -> None;
}

"""RaiseStmt node type for Jac Ast."""
obj RaiseStmt(CodeBlockStmt) {
    has cause: (Expr | None),
        from_target: (Expr | None);

    def postinit -> None;
}

"""AssertStmt node type for Jac Ast."""
obj AssertStmt(CodeBlockStmt) {
    has condition: Expr,
        error_msg: (Expr | None);

    def postinit -> None;
}

"""CtrlStmt node type for Jac Ast."""
obj CtrlStmt(CodeBlockStmt) {
    has ctrl: Token;

    def postinit -> None;
}

"""DeleteStmt node type for Jac Ast."""
obj DeleteStmt(CodeBlockStmt) {
    has target: Expr;

    def postinit -> None;
    @property
    def py_ast_targets -> list[ast3.AST];
}

"""ReportStmt node type for Jac Ast."""
obj ReportStmt(CodeBlockStmt) {
    has expr: Expr;

    def postinit -> None;
}

"""ReturnStmt node type for Jac Ast."""
obj ReturnStmt(CodeBlockStmt) {
    has expr: (Expr | None);

    def postinit -> None;
}

"""VisitStmt node type for Jac Ast."""
obj VisitStmt(WalkerStmtOnlyNode, AstElseBodyNode, CodeBlockStmt) {
    has insert_loc: (Expr | None),
        target: Expr;

    def postinit -> None;
}

"""DisengageStmt node type for Jac Ast."""
obj DisengageStmt(WalkerStmtOnlyNode, CodeBlockStmt) {
    def postinit -> None;
}

"""AwaitExpr node type for Jac Ast."""
obj AwaitExpr(Expr) {
    has target: Expr;

    def postinit -> None;
}

"""GlobalStmt node type for Jac Ast."""
obj GlobalStmt(CodeBlockStmt) {
    has target: Sequence[NameAtom];

    def postinit -> None;
}

"""NonLocalStmt node type for Jac Ast."""
obj NonLocalStmt(GlobalStmt) {}

"""Assignment node type for Jac Ast."""
obj Assignment(AstTypedVarNode, EnumBlockStmt, CodeBlockStmt) {
    has target: Sequence[Expr],
        value: Expr | YieldExpr | None,
        mutable: bool = True,
        aug_op: (Token | None) = None;

    def postinit -> None;
}

"""ConcurrentExpr node type for Jac Ast."""
obj ConcurrentExpr(Expr) {
    has tok: (Token | None),
        target: Expr;

    def postinit -> None;
}

"""BinaryExpr node type for Jac Ast."""
obj BinaryExpr(Expr) {
    has left: Expr,
        right: Expr,
        op: Token | DisconnectOp | ConnectOp;

    def postinit -> None;
}

"""CompareExpr node type for Jac Ast."""
obj CompareExpr(Expr) {
    has left: Expr,
        rights: list[Expr],
        ops: list[Token];

    def postinit -> None;
}

"""BoolExpr node type for Jac Ast.
Each operand is wrapped in a CfgExpr so that short-circuit evaluation
is modeled at the expression level in the CFG."""
obj BoolExpr(Expr) {
    has op: Token,
        values: list[CfgExpr];

    def postinit -> None;
}

"""LambdaExpr node type for Jac Ast."""
obj LambdaExpr(Expr, UniScopeNode) {
    has body: (Expr | Sequence[CodeBlockStmt]),
        signature: (FuncSignature | None) = None;

    def postinit -> None;
}

"""UnaryExpr node type for Jac Ast."""
obj UnaryExpr(Expr) {
    has operand: Expr,
        op: Token;

    def postinit -> None;
}

"""IfElseExpr node type for Jac Ast.
Each branch is wrapped in a CfgExpr so that conditional evaluation
is modeled at the expression level in the CFG."""
obj IfElseExpr(Expr) {
    has condition: CfgExpr,
        value: CfgExpr,
        else_value: CfgExpr;

    def postinit -> None;
}

"""MultiString node type for Jac Ast."""
obj MultiString(AtomExpr) {
    has strings: Sequence[(String | FString)];

    def postinit -> None;
}

"""FString node type for Jac Ast."""
obj FString(AtomExpr) {
    has start: (Token | None),
        parts: Sequence[(String | FormattedValue)],
        end: (Token | None);

    def postinit -> None;
}

"""FormattedValue node type for Jac Ast."""
obj FormattedValue(Expr) {
    has format_part: Expr,
        conversion: int,
        format_spec: (Expr | None);

    def postinit -> None;
}

"""ListVal node type for Jac Ast."""
obj ListVal(AtomExpr) {
    has values: Sequence[Expr];

    def postinit -> None;
}

"""SetVal node type for Jac Ast."""
obj SetVal(AtomExpr) {
    has values: (Sequence[Expr] | None);

    def postinit -> None;
}

"""TupleVal node type for Jac Ast."""
obj TupleVal(AtomExpr) {
    has values: Sequence[(Expr | KWPair)];

    def postinit -> None;
}

"""DictVal node type for Jac Ast."""
obj DictVal(AtomExpr) {
    has kv_pairs: Sequence[KVPair];

    def postinit -> None;
}

"""KVPair node type for Jac Ast."""
obj KVPair(UniNode) {
    has key: (Expr | None),
        value: Expr;

    def postinit -> None;
}

"""KWPair node type for Jac Ast."""
obj KWPair(UniNode) {
    has key: (NameAtom | None),
        value: Expr;

    def postinit -> None;
}

"""InnerCompr node type for Jac Ast."""
obj InnerCompr(AstAsyncNode, UniScopeNode, UniCFGNode) {
    has target: Expr,
        collection: Expr,
        conditional: (list[Expr] | None);

    def postinit -> None;
}

"""ListCompr node type for Jac Ast."""
obj ListCompr(AtomExpr, UniScopeNode) {
    has out_expr: Expr,
        compr: list[InnerCompr];

    def postinit -> None;
}

"""GenCompr node type for Jac Ast."""
obj GenCompr(ListCompr) {}

"""SetCompr node type for Jac Ast."""
obj SetCompr(ListCompr) {}

"""DictCompr node type for Jac Ast."""
obj DictCompr(AtomExpr, UniScopeNode) {
    has kv_pair: KVPair,
        compr: list[InnerCompr];

    def postinit -> None;
}

"""AtomTrailer node type for Jac Ast."""
obj AtomTrailer(Expr) {
    has target: Expr,
        right: (AtomExpr | Expr),
        is_attr: bool,
        is_null_ok: bool,
        is_genai: bool = False;

    def postinit -> None;
    @property
    def as_attr_list -> list[AstSymbolNode];
}

"""AtomUnit node type for Jac Ast."""
obj AtomUnit(Expr) {
    has value: Expr | YieldExpr | Ability;

    def postinit -> None;
}

"""YieldExpr node type for Jac Ast."""
obj YieldExpr(Expr) {
    has expr: (Expr | None),
        with_from: bool;

    def postinit -> None;
}

"""FuncCall node type for Jac Ast."""
obj FuncCall(Expr) {
    has target: Expr,
        params: (Sequence[(Expr | KWPair)] | None),
        genai_call: (Expr | None);

    def postinit -> None;
}

"""Slice item node type for IndexSlice."""
obj Slice(UniNode) {
    has start: (Expr | None),
        stop: (Expr | None),
        step: (Expr | None);

    def postinit -> None;
}

"""IndexSlice node type for Jac Ast."""
obj IndexSlice(AtomExpr) {
    has slices: list[Slice],
        is_range: bool;

    def postinit -> None;
}

"""EdgeRefTrailer node type for Jac Ast."""
obj EdgeRefTrailer(Expr) {
    has chain: list[(Expr | FilterCompr)],
        edges_only: bool,
        is_async: bool;

    def postinit -> None;
}

"""EdgeOpRef node type for Jac Ast."""
obj EdgeOpRef(WalkerStmtOnlyNode, AtomExpr) {
    has filter_cond: (FilterCompr | None),
        edge_dir: EdgeDir;

    def postinit -> None;
}

"""DisconnectOp node type for Jac Ast."""
obj DisconnectOp(WalkerStmtOnlyNode) {
    has edge_spec: EdgeOpRef;

    def postinit -> None;
}

"""ConnectOpRef node type for Jac Ast."""
obj ConnectOp(UniNode) {
    has conn_type: (Expr | None),
        conn_assign: (AssignCompr | None),
        edge_dir: EdgeDir;

    def postinit -> None;
}

"""FilterCompr node type for Jac Ast."""
obj FilterCompr(AtomExpr) {
    has f_type: (Expr | None),
        compares: Sequence[CompareExpr];

    def postinit -> None;
}

"""AssignCompr node type for Jac Ast."""
obj AssignCompr(AtomExpr) {
    has assigns: Sequence[KWPair];

    def postinit -> None;
}

"""JsxElement node type for Jac Ast."""
obj JsxElement(AtomExpr) {
    has name: (JsxElementName | None),
        attributes: (Sequence[JsxAttribute] | None),
        children: (Sequence[(JsxChild | JsxElement)] | None),
        is_self_closing: bool,
        is_fragment: bool;

    def postinit -> None;
    def get_body_start_line -> (int | None);
    def get_body_end_line -> (int | None);
}

"""JsxElementName node type for Jac Ast."""
obj JsxElementName(UniNode) {
    has parts: Sequence[(Name | Token)];

    def postinit -> None;
}

"""JsxAttribute node type for Jac Ast (base class)."""
obj JsxAttribute(UniNode) {
    def postinit -> None;
}

"""JsxSpreadAttribute node type for Jac Ast."""
obj JsxSpreadAttribute(JsxAttribute) {
    has expr: Expr;

    def postinit -> None;
}

"""JsxNormalAttribute node type for Jac Ast."""
obj JsxNormalAttribute(JsxAttribute) {
    has name: (Name | Token),
        value: String | Expr | None;

    def postinit -> None;
}

"""JsxChild node type for Jac Ast (base class)."""
obj JsxChild(UniNode) {
    def postinit -> None;
}

"""JsxText node type for Jac Ast."""
obj JsxText(JsxChild) {
    has value: (str | Token);

    def postinit -> None;
    def get_normalized_text -> str;
}

"""JsxExpression node type for Jac Ast."""
obj JsxExpression(JsxChild) {
    has expr: Expr;

    def postinit -> None;
}

"""MatchStmt node type for Jac Ast."""
obj MatchStmt(CodeBlockStmt) {
    has target: Expr,
        cases: list[MatchCase];

    def postinit -> None;
}

"""MatchCase node type for Jac Ast."""
obj MatchCase(CodeBlockStmt, UniScopeNode) {
    has pattern: MatchPattern,
        guard: (Expr | None),
        body: list[CodeBlockStmt];

    def postinit -> None;
}

"""SwitchStmt node type for Jac Ast."""
obj SwitchStmt(CodeBlockStmt) {
    has target: Expr,
        cases: list[SwitchCase];

    def postinit -> None;
}

"""SwitchCase node type for Jac Ast."""
obj SwitchCase(CodeBlockStmt, UniScopeNode) {
    has pattern: (MatchPattern | None),
        body: list[CodeBlockStmt];

    def postinit -> None;
}

"""MatchOr node type for Jac Ast."""
obj MatchOr(MatchPattern) {
    has patterns: list[MatchPattern];

    def postinit -> None;
}

"""MatchAs node type for Jac Ast."""
obj MatchAs(MatchPattern) {
    has name: NameAtom,
        pattern: (MatchPattern | None);

    def postinit -> None;
}

"""MatchWild node type for Jac Ast."""
obj MatchWild(MatchPattern) {}

"""MatchValue node type for Jac Ast."""
obj MatchValue(MatchPattern) {
    has value: Expr;

    def postinit -> None;
}

"""MatchSingleton node type for Jac Ast."""
obj MatchSingleton(MatchPattern) {
    has value: (Bool | Null);

    def postinit -> None;
}

"""MatchSequence node type for Jac Ast."""
obj MatchSequence(MatchPattern) {
    has values: list[MatchPattern];

    def postinit -> None;
}

"""MatchMapping node type for Jac Ast."""
obj MatchMapping(MatchPattern) {
    has values: list[(MatchKVPair | MatchStar)];

    def postinit -> None;
}

"""MatchKVPair node type for Jac Ast."""
obj MatchKVPair(MatchPattern) {
    has key: MatchPattern | NameAtom | AtomExpr,
        value: MatchPattern;

    def postinit -> None;
}

"""MatchStar node type for Jac Ast."""
obj MatchStar(MatchPattern) {
    has name: NameAtom,
        is_list: bool;

    def postinit -> None;
}

"""MatchArch node type for Jac Ast."""
obj MatchArch(MatchPattern) {
    has name: (AtomTrailer | NameAtom),
        arg_patterns: (Sequence[MatchPattern] | None),
        kw_patterns: (Sequence[MatchKVPair] | None);

    def postinit -> None;
}

"""Token node type for Jac Ast."""
obj Token(UniNode) {
    has orig_src: Source by postinit,
        line_no: int by postinit,
        end_line: int by postinit,
        c_start: int by postinit,
        c_end: int by postinit,
        pos_start: int by postinit,
        pos_end: int by postinit;

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

"""Name node type for Jac Ast."""
obj Name(Token, NameAtom) {
    has js_decl_kind: (str | None) by postinit;

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

"""SpecialVarRef node type for Jac Ast."""
obj SpecialVarRef(Name) {
    has orig: Name by postinit;

    def init(var: Name, is_enum_stmt: bool = False) -> None;
    def py_resolve_name -> str;
}

"""Literal node type for Jac Ast."""
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

    @property
    def lit_value -> int | str | float | bool | None | Callable[
        ([], Any)
    ] | EllipsisType;
}

"""BuiltinType node type for Jac Ast."""
obj BuiltinType(Name, Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.VAR;
    }

    @property
    def lit_value -> Callable[([], Any)];
}

"""Float node type for Jac Ast."""
obj Float(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    @property
    def lit_value -> float;
}

"""Int node type for Jac Ast."""
obj Int(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    @property
    def lit_value -> int;
}

"""String node type for Jac Ast."""
obj String(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.STRING;
    }

    @property
    def lit_value -> str;
}

"""Bool node type for Jac Ast."""
obj Bool(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.BOOL;
    }

    @property
    def lit_value -> bool;
}

"""Null node type for Jac Ast."""
obj Null(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    @property
    def lit_value -> None;
}

"""Ellipsis node type for Jac Ast."""
obj Ellipsis(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    @property
    def lit_value -> EllipsisType;
}

"""EmptyToken node type for Jac Ast."""
obj EmptyToken(Token) {
    def init(orig_src: (Source | None) = None) -> None;
}

"""Semicolon node type for Jac Ast."""
obj Semi(Token, CodeBlockStmt) {
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

"""CommentToken node type for Jac Ast."""
obj CommentToken(Token) {
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

    @property
    def left_node -> (UniNode | None);

    @property
    def right_node -> (UniNode | None);
}

"""SourceString node type for Jac Ast."""
obj Source(EmptyToken) {
    has comments: list[CommentToken] by postinit,
        inline_suppressions: dict[int, set[str]] by postinit,
        file_path: str by postinit;

    def init(source: str, mod_path: str) -> None;
    @property
    def code -> str;
}

"""SourceString node type for Jac Ast."""
obj PythonModuleAst(EmptyToken) {
    has orig_src: Source by postinit,
        file_path: str by postinit;

    def init(ast: ast3.Module, orig_src: Source) -> None;
}
