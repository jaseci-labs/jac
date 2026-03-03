"""Abstract class for IR Passes for Jac."""
import ast as ast3;
import builtins;
import os;
import from collections.abc { Callable, Sequence }
import from copy { copy }
import from dataclasses { dataclass, field }
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

    def postinit(self: UniNode) -> None;
    """Lazy initialization of CodeGenTarget."""
    @property
    def gen(self: UniNode) -> CodeGenTarget {
        if (self._gen is None) {
            self._gen = CodeGenTarget();
        }
        return self._gen;
    }

    """Set CodeGenTarget."""
    @gen.setter
    def gen(self: UniNode, value: CodeGenTarget) -> None {
        self._gen = value;
    }

    """Lazy initialization of sub node table."""
    @property
    def _sub_node_tab(self: UniNode) -> dict[(type, list[UniNode])];

    """Construct sub node table."""
    def _construct_sub_node_tab(self: UniNode) -> None;

    """Get symbol table."""
    @property
    def sym_tab(self: UniNode) -> UniScopeNode;

    """Add kid left."""
    def add_kids_left(
        self: UniNode,
        nodes: Sequence[UniNode],
        pos_update: bool = True,
        parent_update: bool = False
    ) -> UniNode;

    """Add kid right."""
    def add_kids_right(
        self: UniNode,
        nodes: Sequence[UniNode],
        pos_update: bool = True,
        parent_update: bool = False
    ) -> UniNode;

    """Insert kids at position."""
    def insert_kids_at_pos(
        self: UniNode, nodes: Sequence[UniNode], pos: int, pos_update: bool = True
    ) -> UniNode;

    """Set kids."""
    def set_kids(self: UniNode, nodes: Sequence[UniNode]) -> UniNode;

    """Set parent."""
    def set_parent(self: UniNode, parent: UniNode) -> UniNode;

    def resolve_tok_range(self: UniNode) -> tuple[(Token, Token)];
    def gen_token(self: UniNode, name: Tok, value: (str | None) = None) -> Token;
    """Get all sub nodes of type."""
    def get_all_sub_nodes(
        self: UniNode, typ: type[T], brute_force: bool = True
    ) -> list[T];

    """Get parent of type."""
    def find_parent_of_type(self: UniNode, typ: type[T]) -> (T | None);

    def parent_of_type(self: UniNode, typ: type[T]) -> T;
    """Check if this node is in a client-side context.

        This covers:
        - Nodes inside an explicit cl {} block in a .jac file
        - Nodes inside a function marked with CLIENT context in .cl.jac files
        - Overridden by sv {} blocks (server takes precedence)

        Uses single traversal for efficiency since this is called frequently.
        """
    def in_client_context(self: UniNode) -> bool;

    """Check if this node is in a native context.

        This covers:
        - Nodes inside an explicit na {} block in a .jac file
        - Nodes inside a function marked with NATIVE context in .na.jac files
        - Overridden by sv {} or cl {} blocks
        """
    def in_native_context(self: UniNode) -> bool;

    """Return dict representation of node."""
    def to_dict(self: UniNode) -> dict[(str, str)];

    """Print ast."""
    def pp(self: UniNode, depth: (int | None) = None) -> str;

    """Print ast."""
    def printgraph(self: UniNode) -> str;

    """Flatten ast."""
    def flatten(self: UniNode) -> list[UniNode];

    def unparse(self: UniNode) -> str;
}

"""Symbol."""
obj Symbol {
    """Initialize."""
    def init(
        self: Symbol,
        defn: NameAtom,
        access: SymbolAccess,
        parent_tab: (UniScopeNode | None) = None,
        imported: bool = False
    ) -> None;

    """Get decl."""
    @property
    def decl(self: Symbol) -> NameAtom;

    """Get name."""
    @property
    def sym_name(self: Symbol) -> str;

    """Get sym_type."""
    @property
    def sym_type(self: Symbol) -> SymbolType;

    """Return a full path of the symbol."""
    @property
    def sym_dotted_name(self: Symbol) -> str;

    """Get symbol table."""
    @property
    def symbol_table(self: Symbol) -> (UniScopeNode | None);

    """Add defn."""
    def add_defn(self: Symbol, nd: NameAtom) -> None;

    """Add use."""
    def add_use(self: Symbol, nd: NameAtom) -> None;

    """Repr."""
    def __repr__(self: Symbol) -> str;
}

"""Represents an inherited symbol table for selective imports."""
@dataclass
class InheritedSymbolTable {
    with entry {
        base_symbol_table: UniScopeNode;
        load_all_symbols: bool = False;
        symbols: list[str] = field(default_factory=`list);
    }
}

"""Symbol Table."""
obj UniScopeNode(UniNode) {
    """Initialize."""
    has scope_name: str by postinit,
        parent_scope: (UniScopeNode | None) by postinit,
        kid_scope: list[UniScopeNode] by postinit,
        names_in_scope: dict[(str, Symbol)] by postinit,
        names_in_scope_overload: dict[(str, list[Symbol])] by postinit;

    def _init_scope(
        self: UniScopeNode, name: str, parent_scope: (UniScopeNode | None) = None
    ) -> None;

    """Get type."""
    def get_type(self: UniScopeNode) -> SymbolType;

    """Get parent."""
    def get_parent(self: UniScopeNode) -> (UniScopeNode | None);

    static def get_python_scoping_nodes -> tuple[(type[UniScopeNode], ...)] {
        return (Module, Enum, Archetype, Ability, ImplDef, Test);
    }

    """Lookup a variable in the symbol table."""
    def lookup(
        self: UniScopeNode,
        name: str,
        deep: bool = True,
        incl_inner_scope: bool = False
    ) -> (Symbol | None);

    """Lookup all overloads of a symbol in the symbol table."""
    def lookup_all(self: UniScopeNode, name: str, deep: bool = True) -> list[Symbol];

    """Set a variable in the symbol table.

        Returns original symbol as collision if single check fails, none
otherwise.
        Also updates node.sym to create pointer to symbol.
        """
    def insert(
        self: UniScopeNode,
        nd: AstSymbolNode,
        access_spec: AstAccessNode | None | SymbolAccess = None,
        single: bool = False,
        force_overwrite: bool = False,
        imported: bool = False
    ) -> (UniNode | None);

    """Find a scope in the symbol table."""
    def find_scope(self: UniScopeNode, name: str) -> (UniScopeNode | None);

    """Push a new scope onto the symbol table."""
    def link_kid_scope(self: UniScopeNode, key_node: UniScopeNode) -> UniScopeNode;

    """Inherit symbol table."""
    def inherit_sym_tab(self: UniScopeNode, target_sym_tab: UniScopeNode) -> None;

    """Insert into symbol table."""
    def def_insert(
        self: UniScopeNode,
        nd: AstSymbolNode,
        access_spec: AstAccessNode | None | SymbolAccess = None,
        single_decl: (str | None) = None,
        force_overwrite: bool = False,
        imported: bool = False
    ) -> (Symbol | None);

    """Link chain of containing names to symbol."""
    def chain_def_insert(self: UniScopeNode, node_list: list[AstSymbolNode]) -> None;

    """Link to symbol."""
    def use_lookup(
        self: UniScopeNode, nd: AstSymbolNode, sym_table: (UniScopeNode | None) = None
    ) -> (Symbol | None);

    """Link chain of containing names to symbol."""
    def chain_use_lookup(
        self: UniScopeNode, node_list: Sequence[AstSymbolNode]
    ) -> None;

    """Update python context for definition."""
    def update_py_ctx_for_def(self: UniScopeNode, nd: AstSymbolNode) -> None;

    """Pretty print."""
    def sym_pp(self: UniScopeNode, depth: (int | None) = None) -> str;

    """Generate dot graph for sym table."""
    def sym_printgraph(self: UniScopeNode) -> str;

    """Repr."""
    def __repr__(self: UniScopeNode) -> str;
}

"""Nodes that have link to a symbol in symbol table."""
obj AstSymbolNode(UniNode) {
    has name_spec: NameAtom by postinit,
        semstr: str by postinit;

    def _init_symbol(
        self: AstSymbolNode,
        sym_name: str,
        name_spec: NameAtom,
        sym_category: SymbolType
    ) -> None;

    @property
    def sym(self: AstSymbolNode) -> (Symbol | None);

    @property
    def sym_name(self: AstSymbolNode) -> str;

    @property
    def sym_category(self: AstSymbolNode) -> SymbolType;

    @property
    def py_ctx_func(self: AstSymbolNode) -> type[ast3.AST];

    """Get type symbol table."""
    @property
    def type_sym_tab(self: AstSymbolNode) -> (UniScopeNode | None);
}

"""Nodes that have link to a symbol in symbol table."""
obj AstSymbolStubNode(AstSymbolNode) {
    def _init_stub(self: AstSymbolStubNode, sym_type: SymbolType) -> None;
}

"""Nodes that have access."""
obj AstAccessNode(UniNode) {
    has access: (SubTag[Token] | None) = None;

    @property
    def access_type(self: AstAccessNode) -> SymbolAccess;

    @property
    def public_access(self: AstAccessNode) -> bool;
}

"""Base class for nodes that can be marked with execution context
(client/server)."""
obj ContextAwareNode(UniNode) {
    """Initialize with code context.

        Args:
            code_context: Code execution context (SERVER or CLIENT), defaults to
SERVER
        """
    has code_context: CodeContext by postinit;

    def postinit(self: ContextAwareNode) -> None;
    """Return the original context token (cl or sv) if present on this node."""
    def _source_context_token(self: ContextAwareNode) -> (Token | None);
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

    def postinit(self: WalkerStmtOnlyNode) -> None;
}

"""BasicBlockStmt node type for Jac Uniir."""
obj UniCFGNode(UniNode) {
    """Initialize basic block statement node."""
    has bb_in: list[UniCFGNode] by postinit,
        bb_out: list[UniCFGNode] by postinit,
        affected_symbols: set[str] by postinit;

    def postinit(self: UniCFGNode) -> None;
    """Get head by walking up the CFG iteratively."""
    def get_head(self: UniCFGNode) -> UniCFGNode;

    """Get tail by walking down the CFG iteratively."""
    def get_tail(self: UniCFGNode) -> UniCFGNode;
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
        attached_tokens: (list[Token] | None) by postinit;

    def postinit(self: Expr) -> None;
    """Get type symbol table."""
    @property
    def type_sym_tab(self: Expr) -> (UniScopeNode | None) {
        return self._type_sym_tab;
    }

    """Set type symbol table."""
    @type_sym_tab.setter
    def type_sym_tab(self: Expr, type_sym_tab: UniScopeNode) -> None {
        self._type_sym_tab = type_sym_tab;
    }
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
    """Initialize code block statement node."""
    def postinit(self: CodeBlockStmt) -> None;
}

"""AstImplNeedingNode node type for Jac Ast."""
obj AstImplNeedingNode[T](AstSymbolNode) {
    has body: (T | None);

    @property
    def needs_impl(self: AstImplNeedingNode) -> bool;
}

"""NameAtom node type for Jac Ast."""
obj NameAtom(AtomExpr, EnumBlockStmt) {
    has name_of: AstSymbolNode by postinit,
        _sym: (Symbol | None) by postinit,
        _sym_name: str by postinit,
        _sym_category: SymbolType by postinit,
        _py_ctx_func: type[ast3.expr_context] by postinit;

    def postinit(self: NameAtom) -> None;
    @property
    def sym(self: NameAtom) -> (Symbol | None) {
        return self._sym;
    }

    @sym.setter
    def sym(self: NameAtom, sym: Symbol) -> None {
        self._sym = sym;
    }

    @property
    def sym_name(self: NameAtom) -> str;

    @property
    def sym_category(self: NameAtom) -> SymbolType;

    """Create symbol."""
    def create_symbol(
        self: NameAtom,
        access: SymbolAccess,
        parent_tab: (UniScopeNode | None) = None,
        imported: bool = False
    ) -> Symbol;

    @property
    def clean_type(self: NameAtom) -> str;

    """Get python context function."""
    @property
    def py_ctx_func(self: NameAtom) -> type[ast3.expr_context] {
        return self._py_ctx_func;
    }

    """Set python context function."""
    @py_ctx_func.setter
    def py_ctx_func(self: NameAtom, py_ctx_func: type[ast3.expr_context]) -> None {
        self._py_ctx_func = py_ctx_func;
    }

    """Resolve semantic token."""
    @property
    def sem_token(self: NameAtom) -> (tuple[(SemTokType, SemTokMod)] | None);
}

"""ArchSpec node type for Jac Ast."""
obj ArchSpec(ElementStmt, CodeBlockStmt, AstSymbolNode, AstAsyncNode, AstDocNode) {
    has decorators: (Sequence[Expr] | None);

    def postinit(self: ArchSpec) -> None;
}

"""MatchPattern node type for Jac Ast."""
obj MatchPattern(UniNode) {}

"""SubTag node type for Jac Ast."""
obj SubTag[T](UniNode) {
    has tag: T;

    def postinit(self: SubTag) -> None;
}

"""Whole Program node type for Jac Ast."""
obj Module(AstDocNode, UniScopeNode) {
    has name: str,
        source: Source,
        body: Sequence[ElementStmt | String | EmptyToken],
        terminals: list[Token],
        stub_only: bool = False;

    def postinit(self: Module) -> None;
    """Get the base module path that this annex file belongs to.

        Uses discover_base_file to find the base .jac file for annex files
        (.impl.jac, .test.jac). Handles all discovery scenarios:
        - Same directory: foo.impl.jac -> foo.jac
        - Module-specific folder: foo.impl/bar.impl.jac -> foo.jac
        - Shared folder: impl/foo.impl.jac -> foo.jac
        """
    @property
    def annexable_by(self: Module) -> (str | None);

    """Get all sub nodes of type."""
    def format(self: Module) -> str;

    def unparse(self: Module, requires_format: bool = True) -> str;
    """Create a stub module."""
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

    """Return the full path of the module that contains this node."""
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
    """Initialize whole program node."""
    has main_mod: (Module | None) = None;

    def postinit(self: ProgramModule) -> None;
}

"""TypeParam node type for Jac Ast: T, T: Bound, T = Default."""
obj TypeParam(AstSymbolNode, UniNode) {
    has name: Name,
        bound: (Expr | None),
        default_val: (Expr | None);

    def postinit(self: TypeParam) -> None;
}

"""TypeAlias node type for Jac Ast: type Name[T, E = X] = TypeExpr;"""
obj TypeAlias(ContextAwareNode, AstAccessNode, ElementStmt, AstSymbolNode, UniScopeNode) {
    has name: Name,
        type_params: (Sequence[TypeParam] | None),
        value: Expr;

    def postinit(self: TypeAlias) -> None;
}

"""GlobalVars node type for Jac Ast."""
obj GlobalVars(ContextAwareNode, ElementStmt, AstAccessNode) {
    has assignments: Sequence[Assignment],
        is_frozen: bool;

    def postinit(self: GlobalVars) -> None;
}

"""Test node type for Jac Ast."""
obj Test(ContextAwareNode, AstSymbolNode, ElementStmt, UniScopeNode) {
    with entry {
        TEST_COUNT = 0;
    }

    has name: (Name | Token),
        body: Sequence[CodeBlockStmt],
        description: (String | None) = None;

    def postinit(self: Test) -> None;
}

"""ModuleCode node type for Jac Ast."""
obj ModuleCode(ContextAwareNode, ElementStmt, ArchBlockStmt, EnumBlockStmt) {
    has name: (Name | None),
        body: Sequence[CodeBlockStmt];

    def postinit(self: ModuleCode) -> None;
}

"""ClientBlock node type for cl { ... } blocks in Jac Ast."""
obj ClientBlock(ElementStmt) {
    has body: Sequence[ElementStmt],
        implicit: bool = False;

    def postinit(self: ClientBlock) -> None;
}

"""ServerBlock node type for sv { ... } blocks in Jac Ast."""
obj ServerBlock(ElementStmt) {
    has body: Sequence[ElementStmt],
        implicit: bool = False;

    def postinit(self: ServerBlock) -> None;
}

"""NativeBlock node type for na { ... } blocks in Jac Ast."""
obj NativeBlock(ElementStmt) {
    has body: Sequence[ElementStmt],
        implicit: bool = False;

    def postinit(self: NativeBlock) -> None;
}

"""PyInlineCode node type for Jac Ast."""
obj PyInlineCode(ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt) {
    has code: Token;

    def postinit(self: PyInlineCode) -> None;
}

"""Import node type for Jac Ast."""
obj Import(ContextAwareNode, ElementStmt, CodeBlockStmt) {
    has from_loc: (ModulePath | None),
        items: (Sequence[ModuleItem] | Sequence[ModulePath]),
        is_absorb: bool,
        clib_decls: (Sequence[UniNode] | None) = None;

    def postinit(self: Import) -> None;
    """Check if import is python."""
    @property
    def is_py(self: Import) -> bool;

    """Check if import is jac."""
    @property
    def is_jac(self: Import) -> bool;

    """Check if import is jac."""
    @property
    def __jac_detected(self: Import) -> bool;
}

"""ModulePath node type for Jac Ast."""
obj ModulePath(UniNode) {
    has path: (Sequence[(Name | String)] | None),
        level: int,
        alias: (Name | None);

    def postinit(self: ModulePath) -> None;
    """Check if this modulepath is from import."""
    @property
    def is_import_from(self: ModulePath) -> bool;

    """Get path string."""
    @property
    def dot_path_str(self: ModulePath) -> str;

    """Convert an import target string into a relative file path."""
    def resolve_relative_path(
        self: ModulePath, target_item: (str | None) = None
    ) -> str;

    """Convert an import target string into a relative file path."""
    def resolve_relative_path_list(self: ModulePath) -> list[str];
}

"""ModuleItem node type for Jac Ast.

    Name can be either:
    - Name: for regular named imports (e.g., useState, axios)
    - Token (KW_DEFAULT): for default imports (Category 2)
    - Token (STAR_MUL): for namespace imports (Category 4)
    """
obj ModuleItem(UniNode) {
    has name: (Name | Token),
        alias: (Name | None);

    def postinit(self: ModuleItem) -> None;
    """Get import parent."""
    @property
    def from_parent(self: ModuleItem) -> Import;

    """Get relevant module path."""
    @property
    def from_mod_path(self: ModuleItem) -> ModulePath;
}

"""ObjectArch node type for Jac Ast."""
obj Archetype(ContextAwareNode, ArchSpec, AstAccessNode, ArchBlockStmt, AstImplNeedingNode, UniScopeNode, UniCFGNode) {
    has name: Name,
        arch_type: Token,
        base_classes: (Sequence[Expr] | None),
        type_params: (Sequence[TypeParam] | None) = None;

    def postinit(self: Archetype) -> None;
    def _get_impl_resolved_body(self: Archetype) -> list;
    @property
    def is_abstract(self: Archetype) -> bool;

    def get_has_vars(self: Archetype) -> list[HasVar];
    def get_methods(self: Archetype) -> list[Ability];
}

"""AstImplOnlyNode node type for Jac Ast."""
obj ImplDef(ContextAwareNode, CodeBlockStmt, ElementStmt, ArchBlockStmt, AstSymbolNode, UniScopeNode) {
    has decorators: (Sequence[Expr] | None),
        target: Sequence[NameAtom],
        spec: (Sequence[Expr] | FuncSignature | EventSignature | None),
        body: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr,
        decl_link: (UniNode | None) = None;

    def postinit(self: ImplDef) -> None;
    def create_impl_name_node(self: ImplDef) -> Name;
}

"""SemDef node type for Jac Ast."""
obj SemDef(ElementStmt, AstSymbolNode, UniScopeNode) {
    has target: Sequence[NameAtom],
        value: String;

    def postinit(self: SemDef) -> None;
    def create_sem_name_node(self: SemDef) -> Name;
}

"""Enum node type for Jac Ast."""
obj Enum(ContextAwareNode, ArchSpec, AstAccessNode, AstImplNeedingNode, ArchBlockStmt, UniScopeNode) {
    has name: Name,
        base_classes: (Sequence[Expr] | None);

    def postinit(self: Enum) -> None;
}

"""Ability node type for Jac Ast."""
obj Ability(ContextAwareNode, AstAccessNode, ElementStmt, AstAsyncNode, ArchBlockStmt, CodeBlockStmt, AstImplNeedingNode, UniScopeNode) {
    has name_ref: (NameAtom | None),
        is_override: bool,
        is_static: bool,
        is_abstract: bool,
        signature: FuncSignature | EventSignature | None,
        decorators: (Sequence[Expr] | None) = None;

    def postinit(self: Ability) -> None;
    @property
    def is_method(self: Ability) -> bool;

    """Check if this ability is a class method."""
    @property
    def is_cls_method(self: Ability) -> bool;

    @property
    def is_def(self: Ability) -> bool;

    @property
    def method_owner(self: Ability) -> Archetype | Enum | None;

    @property
    def is_genai_ability(self: Ability) -> bool;

    """Get the range of positional arguments for this ability.

        Returns -1 for maximum number of arguments if there is an unpacked
parameter (e.g., *args).
        """
    def get_pos_argc_range(self: Ability) -> tuple[(int, int)];

    def py_resolve_name(self: Ability) -> str;
}

"""FuncSignature node type for Jac Ast."""
obj FuncSignature(UniNode) {
    has posonly_params: Sequence[ParamVar],
        params: (Sequence[ParamVar] | None),
        varargs: (ParamVar | None),
        kwonlyargs: Sequence[ParamVar],
        kwargs: (ParamVar | None),
        return_type: (Expr | None);

    def postinit(self: FuncSignature) -> None;
    """Return all parameters in the declared order."""
    def get_parameters(self: FuncSignature) -> list[ParamVar];

    @property
    def is_static(self: FuncSignature) -> bool;

    @property
    def is_in_py_class(self: FuncSignature) -> bool;
}

"""EventSignature node type for Jac Ast."""
obj EventSignature(WalkerStmtOnlyNode) {
    has event: Token,
        arch_tag_info: (Expr | None);

    def postinit(self: EventSignature) -> None;
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
        value: (Expr | None);

    def postinit(self: ParamVar) -> None;
    @property
    def is_vararg(self: ParamVar) -> bool;

    @property
    def is_kwargs(self: ParamVar) -> bool;
}

"""ArchHas node type for Jac Ast."""
obj ArchHas(AstAccessNode, AstDocNode, ArchBlockStmt, CodeBlockStmt) {
    has is_static: bool,
        vars: Sequence[HasVar],
        is_frozen: bool;

    def postinit(self: ArchHas) -> None;
}

"""HasVar node type for Jac Ast."""
obj HasVar(AstSymbolNode, AstTypedVarNode) {
    has name: Name,
        value: (Expr | None),
        defer: bool;

    def postinit(self: HasVar) -> None;
}

"""TypedCtxBlock node type for Jac Ast."""
obj TypedCtxBlock(CodeBlockStmt, WalkerStmtOnlyNode, UniScopeNode) {
    has type_ctx: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit(self: TypedCtxBlock) -> None;
}

"""IfStmt node type for Jac Ast."""
obj IfStmt(CodeBlockStmt, AstElseBodyNode, UniScopeNode) {
    has condition: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit(self: IfStmt) -> None;
}

"""ElseIf node type for Jac Ast."""
obj ElseIf(IfStmt) {}

"""ElseStmt node type for Jac Ast."""
obj ElseStmt(UniScopeNode) {
    has body: Sequence[CodeBlockStmt];

    def postinit(self: ElseStmt) -> None;
}

"""ExprStmt node type for Jac Ast."""
obj ExprStmt(CodeBlockStmt) {
    has expr: Expr,
        in_fstring: bool;

    def postinit(self: ExprStmt) -> None;
}

"""TryStmt node type for Jac Ast."""
obj TryStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has body: Sequence[CodeBlockStmt],
        excepts: Sequence[Except],
        finally_body: (FinallyStmt | None);

    def postinit(self: TryStmt) -> None;
}

"""Except node type for Jac Ast."""
obj Except(CodeBlockStmt, UniScopeNode) {
    has ex_type: Expr,
        name: (Name | None),
        body: Sequence[CodeBlockStmt];

    def postinit(self: Except) -> None;
}

"""FinallyStmt node type for Jac Ast."""
obj FinallyStmt(CodeBlockStmt, UniScopeNode) {
    has body: Sequence[CodeBlockStmt];

    def postinit(self: FinallyStmt) -> None;
}

"""IterForStmt node type for Jac Ast."""
obj IterForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has iter: Assignment,
        condition: Expr,
        count_by: Assignment,
        body: Sequence[CodeBlockStmt];

    def postinit(self: IterForStmt) -> None;
}

"""InForStmt node type for Jac Ast."""
obj InForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has target: Expr,
        collection: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit(self: InForStmt) -> None;
}

"""WhileStmt node type for Jac Ast."""
obj WhileStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    has condition: Expr,
        body: Sequence[CodeBlockStmt];

    def postinit(self: WhileStmt) -> None;
}

"""WithStmt node type for Jac Ast."""
obj WithStmt(AstAsyncNode, CodeBlockStmt, UniScopeNode) {
    has exprs: Sequence[ExprAsItem],
        body: Sequence[CodeBlockStmt];

    def postinit(self: WithStmt) -> None;
}

"""ExprAsItem node type for Jac Ast."""
obj ExprAsItem(UniNode) {
    has expr: Expr,
        alias: (Expr | None);

    def postinit(self: ExprAsItem) -> None;
}

"""RaiseStmt node type for Jac Ast."""
obj RaiseStmt(CodeBlockStmt) {
    has cause: (Expr | None),
        from_target: (Expr | None);

    def postinit(self: RaiseStmt) -> None;
}

"""AssertStmt node type for Jac Ast."""
obj AssertStmt(CodeBlockStmt) {
    has condition: Expr,
        error_msg: (Expr | None);

    def postinit(self: AssertStmt) -> None;
}

"""CtrlStmt node type for Jac Ast."""
obj CtrlStmt(CodeBlockStmt) {
    has ctrl: Token;

    def postinit(self: CtrlStmt) -> None;
}

"""DeleteStmt node type for Jac Ast."""
obj DeleteStmt(CodeBlockStmt) {
    has target: Expr;

    def postinit(self: DeleteStmt) -> None;
    """Get Python AST targets (without setting ctx)."""
    @property
    def py_ast_targets(self: DeleteStmt) -> list[ast3.AST];
}

"""ReportStmt node type for Jac Ast."""
obj ReportStmt(CodeBlockStmt) {
    has expr: Expr;

    def postinit(self: ReportStmt) -> None;
}

"""ReturnStmt node type for Jac Ast."""
obj ReturnStmt(CodeBlockStmt) {
    has expr: (Expr | None);

    def postinit(self: ReturnStmt) -> None;
}

"""VisitStmt node type for Jac Ast."""
obj VisitStmt(WalkerStmtOnlyNode, AstElseBodyNode, CodeBlockStmt) {
    has insert_loc: (Expr | None),
        target: Expr;

    def postinit(self: VisitStmt) -> None;
}

"""DisengageStmt node type for Jac Ast."""
obj DisengageStmt(WalkerStmtOnlyNode, CodeBlockStmt) {
    """Initialize disengage statement node."""
    def postinit(self: DisengageStmt) -> None;
}

"""AwaitExpr node type for Jac Ast."""
obj AwaitExpr(Expr) {
    has target: Expr;

    def postinit(self: AwaitExpr) -> None;
}

"""GlobalStmt node type for Jac Ast."""
obj GlobalStmt(CodeBlockStmt) {
    has target: Sequence[NameAtom];

    def postinit(self: GlobalStmt) -> None;
}

"""NonLocalStmt node type for Jac Ast."""
obj NonLocalStmt(GlobalStmt) {}

"""Assignment node type for Jac Ast."""
obj Assignment(AstTypedVarNode, EnumBlockStmt, CodeBlockStmt) {
    has target: Sequence[Expr],
        value: Expr | YieldExpr | None,
        mutable: bool = True,
        aug_op: (Token | None) = None;

    def postinit(self: Assignment) -> None;
}

"""ConcurrentExpr node type for Jac Ast."""
obj ConcurrentExpr(Expr) {
    has tok: (Token | None),
        target: Expr;

    def postinit(self: ConcurrentExpr) -> None;
}

"""BinaryExpr node type for Jac Ast."""
obj BinaryExpr(Expr) {
    has left: Expr,
        right: Expr,
        op: Token | DisconnectOp | ConnectOp;

    def postinit(self: BinaryExpr) -> None;
}

"""CompareExpr node type for Jac Ast."""
obj CompareExpr(Expr) {
    has left: Expr,
        rights: list[Expr],
        ops: list[Token];

    def postinit(self: CompareExpr) -> None;
}

"""BoolExpr node type for Jac Ast."""
obj BoolExpr(Expr) {
    has op: Token,
        values: list[Expr];

    def postinit(self: BoolExpr) -> None;
}

"""LambdaExpr node type for Jac Ast."""
obj LambdaExpr(Expr, UniScopeNode) {
    has body: (Expr | Sequence[CodeBlockStmt]),
        signature: (FuncSignature | None) = None;

    def postinit(self: LambdaExpr) -> None;
}

"""UnaryExpr node type for Jac Ast."""
obj UnaryExpr(Expr) {
    has operand: Expr,
        op: Token;

    def postinit(self: UnaryExpr) -> None;
}

"""IfElseExpr node type for Jac Ast."""
obj IfElseExpr(Expr) {
    has condition: Expr,
        value: Expr,
        else_value: Expr;

    def postinit(self: IfElseExpr) -> None;
}

"""MultiString node type for Jac Ast."""
obj MultiString(AtomExpr) {
    has strings: Sequence[(String | FString)];

    def postinit(self: MultiString) -> None;
}

"""FString node type for Jac Ast."""
obj FString(AtomExpr) {
    has start: (Token | None),
        parts: Sequence[(String | FormattedValue)],
        end: (Token | None);

    def postinit(self: FString) -> None;
}

"""FormattedValue node type for Jac Ast."""
obj FormattedValue(Expr) {
    has format_part: Expr,
        conversion: int,
        format_spec: (Expr | None);

    def postinit(self: FormattedValue) -> None;
}

"""ListVal node type for Jac Ast."""
obj ListVal(AtomExpr) {
    has values: Sequence[Expr];

    def postinit(self: ListVal) -> None;
}

"""SetVal node type for Jac Ast."""
obj SetVal(AtomExpr) {
    has values: (Sequence[Expr] | None);

    def postinit(self: SetVal) -> None;
}

"""TupleVal node type for Jac Ast."""
obj TupleVal(AtomExpr) {
    has values: Sequence[(Expr | KWPair)];

    def postinit(self: TupleVal) -> None;
}

"""DictVal node type for Jac Ast."""
obj DictVal(AtomExpr) {
    has kv_pairs: Sequence[KVPair];

    def postinit(self: DictVal) -> None;
}

"""KVPair node type for Jac Ast."""
obj KVPair(UniNode) {
    has key: (Expr | None),
        value: Expr;

    def postinit(self: KVPair) -> None;
}

"""KWPair node type for Jac Ast."""
obj KWPair(UniNode) {
    has key: (NameAtom | None),
        value: Expr;

    def postinit(self: KWPair) -> None;
}

"""InnerCompr node type for Jac Ast."""
obj InnerCompr(AstAsyncNode, UniScopeNode) {
    has target: Expr,
        collection: Expr,
        conditional: (list[Expr] | None);

    def postinit(self: InnerCompr) -> None;
}

"""ListCompr node type for Jac Ast."""
obj ListCompr(AtomExpr, UniScopeNode) {
    has out_expr: Expr,
        compr: list[InnerCompr];

    def postinit(self: ListCompr) -> None;
}

"""GenCompr node type for Jac Ast."""
obj GenCompr(ListCompr) {}

"""SetCompr node type for Jac Ast."""
obj SetCompr(ListCompr) {}

"""DictCompr node type for Jac Ast."""
obj DictCompr(AtomExpr, UniScopeNode) {
    has kv_pair: KVPair,
        compr: list[InnerCompr];

    def postinit(self: DictCompr) -> None;
}

"""AtomTrailer node type for Jac Ast."""
obj AtomTrailer(Expr) {
    has target: Expr,
        right: (AtomExpr | Expr),
        is_attr: bool,
        is_null_ok: bool,
        is_genai: bool = False;

    def postinit(self: AtomTrailer) -> None;
    @property
    def as_attr_list(self: AtomTrailer) -> list[AstSymbolNode];
}

"""AtomUnit node type for Jac Ast."""
obj AtomUnit(Expr) {
    has value: Expr | YieldExpr | Ability;

    def postinit(self: AtomUnit) -> None;
}

"""YieldExpr node type for Jac Ast."""
obj YieldExpr(Expr) {
    has expr: (Expr | None),
        with_from: bool;

    def postinit(self: YieldExpr) -> None;
}

"""FuncCall node type for Jac Ast."""
obj FuncCall(Expr) {
    has target: Expr,
        params: (Sequence[(Expr | KWPair)] | None),
        genai_call: (Expr | None);

    def postinit(self: FuncCall) -> None;
}

"""IndexSlice node type for Jac Ast."""
obj IndexSlice(AtomExpr) {
    """Slice node type for Jac Ast."""
    @dataclass
    class Slice {
        with entry {
            start: (Expr | None);
            stop: (Expr | None);
            step: (Expr | None);
        }
    }

    has slices: list[Slice],
        is_range: bool;

    def postinit(self: IndexSlice) -> None;
}

"""EdgeRefTrailer node type for Jac Ast."""
obj EdgeRefTrailer(Expr) {
    has chain: list[(Expr | FilterCompr)],
        edges_only: bool,
        is_async: bool;

    def postinit(self: EdgeRefTrailer) -> None;
}

"""EdgeOpRef node type for Jac Ast."""
obj EdgeOpRef(WalkerStmtOnlyNode, AtomExpr) {
    has filter_cond: (FilterCompr | None),
        edge_dir: EdgeDir;

    def postinit(self: EdgeOpRef) -> None;
}

"""DisconnectOp node type for Jac Ast."""
obj DisconnectOp(WalkerStmtOnlyNode) {
    has edge_spec: EdgeOpRef;

    def postinit(self: DisconnectOp) -> None;
}

"""ConnectOpRef node type for Jac Ast."""
obj ConnectOp(UniNode) {
    has conn_type: (Expr | None),
        conn_assign: (AssignCompr | None),
        edge_dir: EdgeDir;

    def postinit(self: ConnectOp) -> None;
}

"""FilterCompr node type for Jac Ast."""
obj FilterCompr(AtomExpr) {
    has f_type: (Expr | None),
        compares: Sequence[CompareExpr];

    def postinit(self: FilterCompr) -> None;
}

"""AssignCompr node type for Jac Ast."""
obj AssignCompr(AtomExpr) {
    has assigns: Sequence[KWPair];

    def postinit(self: AssignCompr) -> None;
}

"""JsxElement node type for Jac Ast."""
obj JsxElement(AtomExpr) {
    has name: (JsxElementName | None),
        attributes: (Sequence[JsxAttribute] | None),
        children: (Sequence[(JsxChild | JsxElement)] | None),
        is_self_closing: bool,
        is_fragment: bool;

    def postinit(self: JsxElement) -> None;
    """Get the source line after the opening tag's '>' token (body start)."""
    def get_body_start_line(self: JsxElement) -> (int | None);

    """Get the source line of the closing tag's '</' token (body end)."""
    def get_body_end_line(self: JsxElement) -> (int | None);
}

"""JsxElementName node type for Jac Ast."""
obj JsxElementName(UniNode) {
    has parts: Sequence[(Name | Token)];

    def postinit(self: JsxElementName) -> None;
}

"""JsxAttribute node type for Jac Ast (base class)."""
obj JsxAttribute(UniNode) {
    def postinit(self: JsxAttribute) -> None;
}

"""JsxSpreadAttribute node type for Jac Ast."""
obj JsxSpreadAttribute(JsxAttribute) {
    has expr: Expr;

    def postinit(self: JsxSpreadAttribute) -> None;
}

"""JsxNormalAttribute node type for Jac Ast."""
obj JsxNormalAttribute(JsxAttribute) {
    has name: (Name | Token),
        value: String | Expr | None;

    def postinit(self: JsxNormalAttribute) -> None;
}

"""JsxChild node type for Jac Ast (base class)."""
obj JsxChild(UniNode) {
    def postinit(self: JsxChild) -> None;
}

"""JsxText node type for Jac Ast."""
obj JsxText(JsxChild) {
    has value: (str | Token);

    def postinit(self: JsxText) -> None;
    """Normalize JSX text whitespace (single source of truth).

    HTML-like rules: strip leading/trailing newline+whitespace,
    collapse internal newline+whitespace sequences to a single space.
    """
    def get_normalized_text(self: JsxText) -> str;
}

"""JsxExpression node type for Jac Ast."""
obj JsxExpression(JsxChild) {
    has expr: Expr;

    def postinit(self: JsxExpression) -> None;
}

"""MatchStmt node type for Jac Ast."""
obj MatchStmt(CodeBlockStmt) {
    has target: Expr,
        cases: list[MatchCase];

    def postinit(self: MatchStmt) -> None;
}

"""MatchCase node type for Jac Ast."""
obj MatchCase(UniScopeNode) {
    has pattern: MatchPattern,
        guard: (Expr | None),
        body: list[CodeBlockStmt];

    def postinit(self: MatchCase) -> None;
}

"""SwitchStmt node type for Jac Ast."""
obj SwitchStmt(CodeBlockStmt) {
    has target: Expr,
        cases: list[SwitchCase];

    def postinit(self: SwitchStmt) -> None;
}

"""SwitchCase node type for Jac Ast."""
obj SwitchCase(UniScopeNode) {
    has pattern: (MatchPattern | None),
        body: list[CodeBlockStmt];

    def postinit(self: SwitchCase) -> None;
}

"""MatchOr node type for Jac Ast."""
obj MatchOr(MatchPattern) {
    has patterns: list[MatchPattern];

    def postinit(self: MatchOr) -> None;
}

"""MatchAs node type for Jac Ast."""
obj MatchAs(MatchPattern) {
    has name: NameAtom,
        pattern: (MatchPattern | None);

    def postinit(self: MatchAs) -> None;
}

"""MatchWild node type for Jac Ast."""
obj MatchWild(MatchPattern) {}

"""MatchValue node type for Jac Ast."""
obj MatchValue(MatchPattern) {
    has value: Expr;

    def postinit(self: MatchValue) -> None;
}

"""MatchSingleton node type for Jac Ast."""
obj MatchSingleton(MatchPattern) {
    has value: (Bool | Null);

    def postinit(self: MatchSingleton) -> None;
}

"""MatchSequence node type for Jac Ast."""
obj MatchSequence(MatchPattern) {
    has values: list[MatchPattern];

    def postinit(self: MatchSequence) -> None;
}

"""MatchMapping node type for Jac Ast."""
obj MatchMapping(MatchPattern) {
    has values: list[(MatchKVPair | MatchStar)];

    def postinit(self: MatchMapping) -> None;
}

"""MatchKVPair node type for Jac Ast."""
obj MatchKVPair(MatchPattern) {
    has key: MatchPattern | NameAtom | AtomExpr,
        value: MatchPattern;

    def postinit(self: MatchKVPair) -> None;
}

"""MatchStar node type for Jac Ast."""
obj MatchStar(MatchPattern) {
    has name: NameAtom,
        is_list: bool;

    def postinit(self: MatchStar) -> None;
}

"""MatchArch node type for Jac Ast."""
obj MatchArch(MatchPattern) {
    has name: (AtomTrailer | NameAtom),
        arg_patterns: (Sequence[MatchPattern] | None),
        kw_patterns: (Sequence[MatchKVPair] | None);

    def postinit(self: MatchArch) -> None;
}

"""Token node type for Jac Ast."""
obj Token(UniNode) {
    def init(
        self: Token,
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

    def __repr__(self: Token) -> str;
    def unparse(self: Token) -> str;
}

"""Name node type for Jac Ast."""
obj Name(Token, NameAtom) {
    def init(
        self: Name,
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

    """Generate name from node."""
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
    def init(self: SpecialVarRef, var: Name, is_enum_stmt: bool = False) -> None;
    def py_resolve_name(self: SpecialVarRef) -> str;
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
        self: Literal,
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

    """Return literal value in its python type."""
    @property
    def lit_value(
        self: Literal
    ) -> int | str | float | bool | None | Callable[([], Any)] | EllipsisType;
}

"""BuiltinType node type for Jac Ast."""
obj BuiltinType(Name, Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.VAR;
    }

    """Return literal value in its python type."""
    @property
    def lit_value(self: BuiltinType) -> Callable[([], Any)];
}

"""Float node type for Jac Ast."""
obj Float(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    @property
    def lit_value(self: Float) -> float;
}

"""Int node type for Jac Ast."""
obj Int(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    @property
    def lit_value(self: Int) -> int;
}

"""String node type for Jac Ast."""
obj String(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.STRING;
    }

    @property
    def lit_value(self: String) -> str;
}

"""Bool node type for Jac Ast."""
obj Bool(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.BOOL;
    }

    @property
    def lit_value(self: Bool) -> bool;
}

"""Null node type for Jac Ast."""
obj Null(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    @property
    def lit_value(self: Null) -> None;
}

"""Ellipsis node type for Jac Ast."""
obj Ellipsis(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    @property
    def lit_value(self: Ellipsis) -> EllipsisType;
}

"""EmptyToken node type for Jac Ast."""
obj EmptyToken(Token) {
    def init(self: EmptyToken, orig_src: (Source | None) = None) -> None;
}

"""Semicolon node type for Jac Ast."""
obj Semi(Token, CodeBlockStmt) {
    """Initialize token."""
    def init(
        self: Semi,
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
        self: CommentToken,
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
    def left_node(self: CommentToken) -> (UniNode | None);

    @property
    def right_node(self: CommentToken) -> (UniNode | None);
}

"""SourceString node type for Jac Ast."""
obj Source(EmptyToken) {
    def init(self: Source, source: str, mod_path: str) -> None;
    """Return the source code as string."""
    @property
    def code(self: Source) -> str;
}

"""SourceString node type for Jac Ast."""
obj PythonModuleAst(EmptyToken) {
    def init(self: PythonModuleAst, ast: ast3.Module, orig_src: Source) -> None;
}
