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
class UniNode {
    """Initialize ast."""
    def init(self: UniNode, kid: Sequence[UniNode]) -> None;

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
class Symbol {
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
class UniScopeNode(UniNode) {
    """Initialize."""
    def init(
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
class AstSymbolNode(UniNode) {
    def init(
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

    @property
    def expr_type(self: AstSymbolNode) -> str;

    """Get type symbol table."""
    @property
    def type_sym_tab(self: AstSymbolNode) -> (UniScopeNode | None);
}

"""Nodes that have link to a symbol in symbol table."""
class AstSymbolStubNode(AstSymbolNode) {
    def init(self: AstSymbolStubNode, sym_type: SymbolType) -> None;
}

"""Nodes that have access."""
class AstAccessNode(UniNode) {
    def init(self: AstAccessNode, access: (SubTag[Token] | None)) -> None;
    @property
    def access_type(self: AstAccessNode) -> SymbolAccess;

    @property
    def public_access(self: AstAccessNode) -> bool;
}

"""Base class for nodes that can be marked with execution context
(client/server)."""
class ContextAwareNode(UniNode) {
    """Initialize with code context.

        Args:
            code_context: Code execution context (SERVER or CLIENT), defaults to
SERVER
        """
    def init(
        self: ContextAwareNode, code_context: CodeContext = CodeContext.SERVER
    ) -> None;

    """Return the original context token (cl or sv) if present on this node."""
    def _source_context_token(self: ContextAwareNode) -> (Token | None);
}

"""Nodes that have access."""
class AstDocNode(UniNode) {
    def init(self: AstDocNode, doc: (String | None)) -> None;
}

"""Nodes that have access."""
class AstAsyncNode(UniNode) {
    def init(self: AstAsyncNode, is_async: bool) -> None;
}

"""Nodes that have access."""
class AstElseBodyNode(UniNode) {
    def init(self: AstElseBodyNode, else_body: ElseStmt | ElseIf | None) -> None;
}

"""Nodes that have access."""
class AstTypedVarNode(UniNode) {
    def init(self: AstTypedVarNode, type_tag: (SubTag[Expr] | None)) -> None;
}

"""WalkerStmtOnlyNode node type for Jac Ast."""
class WalkerStmtOnlyNode(UniNode) {
    def init(self: WalkerStmtOnlyNode) -> None;
}

"""BasicBlockStmt node type for Jac Uniir."""
class UniCFGNode(UniNode) {
    """Initialize basic block statement node."""
    def init(self: UniCFGNode) -> None;

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
class Expr(UniNode) {
    def init(self: Expr) -> None;
    @property
    def expr_type(self: Expr) -> str {
        return self._sym_type;
    }

    @expr_type.setter
    def expr_type(self: Expr, sym_type: str) -> None {
        self._sym_type = sym_type;
    }

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
class AtomExpr(Expr, AstSymbolStubNode) {}

"""ElementStmt node type for Jac Ast."""
class ElementStmt(AstDocNode) {}

"""ArchBlockStmt node type for Jac Ast."""
class ArchBlockStmt(UniNode) {}

"""EnumBlockStmt node type for Jac Ast."""
class EnumBlockStmt(UniNode) {
    def init(self: EnumBlockStmt, is_enum_stmt: bool) -> None;
}

"""CodeBlockStmt node type for Jac Ast."""
class CodeBlockStmt(UniCFGNode) {
    """Initialize code block statement node."""
    def init(self: CodeBlockStmt) -> None;
}

"""AstImplNeedingNode node type for Jac Ast."""
class AstImplNeedingNode[T](AstSymbolNode) {
    def init(self: AstImplNeedingNode, body: (T | None)) -> None;
    @property
    def needs_impl(self: AstImplNeedingNode) -> bool;
}

"""NameAtom node type for Jac Ast."""
class NameAtom(AtomExpr, EnumBlockStmt) {
    def init(self: NameAtom, is_enum_stmt: bool) -> None;
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
class ArchSpec(ElementStmt, CodeBlockStmt, AstSymbolNode, AstAsyncNode, AstDocNode) {
    def init(
        self: ArchSpec, decorators: (Sequence[Expr] | None), is_async: bool = False
    ) -> None;
}

"""MatchPattern node type for Jac Ast."""
class MatchPattern(UniNode) {}

"""SubTag node type for Jac Ast."""
class SubTag[T](UniNode) {
    def init(self: SubTag, tag: T, kid: Sequence[UniNode]) -> None;
}

"""Whole Program node type for Jac Ast."""
class Module(AstDocNode, UniScopeNode) {
    def init(
        self: Module,
        name: str,
        source: Source,
        doc: (String | None),
        body: Sequence[ElementStmt | String | EmptyToken],
        terminals: list[Token],
        kid: Sequence[UniNode],
        stub_only: bool = False
    ) -> None;

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
class ProgramModule(UniNode) {
    """Initialize whole program node."""
    def init(self: ProgramModule, main_mod: (Module | None) = None) -> None;
}

"""TypeParam node type for Jac Ast: T, T: Bound, T = Default."""
class TypeParam(AstSymbolNode, UniNode) {
    def init(
        self: TypeParam,
        name: Name,
        bound: (Expr | None),
        default_val: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""TypeAlias node type for Jac Ast: type Name[T, E = X] = TypeExpr;"""
class TypeAlias(ContextAwareNode, AstAccessNode, ElementStmt, AstSymbolNode, UniScopeNode) {
    def init(
        self: TypeAlias,
        name: Name,
        type_params: (Sequence[TypeParam] | None),
        value: Expr,
        access: (SubTag[Token] | None),
        kid: Sequence[UniNode],
        doc: (String | None) = None
    ) -> None;
}

"""GlobalVars node type for Jac Ast."""
class GlobalVars(ContextAwareNode, ElementStmt, AstAccessNode) {
    def init(
        self: GlobalVars,
        access: (SubTag[Token] | None),
        assignments: Sequence[Assignment],
        is_frozen: bool,
        kid: Sequence[UniNode],
        doc: (String | None) = None
    ) -> None;
}

"""Test node type for Jac Ast."""
class Test(ContextAwareNode, AstSymbolNode, ElementStmt, UniScopeNode) {
    with entry {
        TEST_COUNT = 0;
    }

    def init(
        self: Test,
        name: (Name | Token),
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
        doc: (String | None) = None,
        description: (String | None) = None
    ) -> None;
}

"""ModuleCode node type for Jac Ast."""
class ModuleCode(ContextAwareNode, ElementStmt, ArchBlockStmt, EnumBlockStmt) {
    def init(
        self: ModuleCode,
        name: (Name | None),
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
        is_enum_stmt: bool = False,
        doc: (String | None) = None
    ) -> None;
}

"""ClientBlock node type for cl { ... } blocks in Jac Ast."""
class ClientBlock(ElementStmt) {
    def init(
        self: ClientBlock,
        body: Sequence[ElementStmt],
        kid: Sequence[UniNode],
        implicit: bool = False
    ) -> None;
}

"""ServerBlock node type for sv { ... } blocks in Jac Ast."""
class ServerBlock(ElementStmt) {
    def init(
        self: ServerBlock,
        body: Sequence[ElementStmt],
        kid: Sequence[UniNode],
        implicit: bool = False
    ) -> None;
}

"""NativeBlock node type for na { ... } blocks in Jac Ast."""
class NativeBlock(ElementStmt) {
    def init(
        self: NativeBlock,
        body: Sequence[ElementStmt],
        kid: Sequence[UniNode],
        implicit: bool = False
    ) -> None;
}

"""PyInlineCode node type for Jac Ast."""
class PyInlineCode(ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt) {
    def init(
        self: PyInlineCode,
        code: Token,
        kid: Sequence[UniNode],
        is_enum_stmt: bool = False,
        doc: (String | None) = None
    ) -> None;
}

"""Import node type for Jac Ast."""
class Import(ContextAwareNode, ElementStmt, CodeBlockStmt) {
    def init(
        self: Import,
        from_loc: (ModulePath | None),
        items: (Sequence[ModuleItem] | Sequence[ModulePath]),
        is_absorb: bool,
        kid: Sequence[UniNode],
        doc: (String | None) = None,
        clib_decls: (Sequence[UniNode] | None) = None
    ) -> None;

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
class ModulePath(UniNode) {
    def init(
        self: ModulePath,
        path: (Sequence[(Name | String)] | None),
        level: int,
        alias: (Name | None),
        kid: Sequence[UniNode]
    ) -> None;

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
class ModuleItem(UniNode) {
    def init(
        self: ModuleItem,
        name: (Name | Token),
        alias: (Name | None),
        kid: Sequence[UniNode]
    ) -> None;

    """Get import parent."""
    @property
    def from_parent(self: ModuleItem) -> Import;

    """Get relevant module path."""
    @property
    def from_mod_path(self: ModuleItem) -> ModulePath;
}

"""ObjectArch node type for Jac Ast."""
class Archetype(ContextAwareNode, ArchSpec, AstAccessNode, ArchBlockStmt, AstImplNeedingNode, UniScopeNode, UniCFGNode) {
    def init(
        self: Archetype,
        name: Name,
        arch_type: Token,
        access: (SubTag[Token] | None),
        base_classes: (Sequence[Expr] | None),
        body: Sequence[ArchBlockStmt] | ImplDef | None,
        kid: Sequence[UniNode],
        doc: (String | None) = None,
        decorators: (Sequence[Expr] | None) = None,
        type_params: (Sequence[TypeParam] | None) = None
    ) -> None;

    def _get_impl_resolved_body(self: Archetype) -> list;
    @property
    def is_abstract(self: Archetype) -> bool;

    def get_has_vars(self: Archetype) -> list[HasVar];
    def get_methods(self: Archetype) -> list[Ability];
}

"""AstImplOnlyNode node type for Jac Ast."""
class ImplDef(ContextAwareNode, CodeBlockStmt, ElementStmt, ArchBlockStmt, AstSymbolNode, UniScopeNode) {
    def init(
        self: ImplDef,
        decorators: (Sequence[Expr] | None),
        target: Sequence[NameAtom],
        spec: (Sequence[Expr] | FuncSignature | EventSignature | None),
        body: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr,
        kid: Sequence[UniNode],
        doc: (String | None) = None,
        decl_link: (UniNode | None) = None
    ) -> None;

    def create_impl_name_node(self: ImplDef) -> Name;
}

"""SemDef node type for Jac Ast."""
class SemDef(ElementStmt, AstSymbolNode, UniScopeNode) {
    def init(
        self: SemDef, target: Sequence[NameAtom], value: String, kid: Sequence[UniNode]
    ) -> None;

    def create_sem_name_node(self: SemDef) -> Name;
}

"""Enum node type for Jac Ast."""
class Enum(ContextAwareNode, ArchSpec, AstAccessNode, AstImplNeedingNode, ArchBlockStmt, UniScopeNode) {
    def init(
        self: Enum,
        name: Name,
        access: (SubTag[Token] | None),
        base_classes: (Sequence[Expr] | None),
        body: Sequence[EnumBlockStmt] | ImplDef | None,
        kid: Sequence[UniNode],
        doc: (String | None) = None,
        decorators: (Sequence[Expr] | None) = None
    ) -> None;
}

"""Ability node type for Jac Ast."""
class Ability(ContextAwareNode, AstAccessNode, ElementStmt, AstAsyncNode, ArchBlockStmt, CodeBlockStmt, AstImplNeedingNode, UniScopeNode) {
    def init(
        self: Ability,
        name_ref: (NameAtom | None),
        is_async: bool,
        is_override: bool,
        is_static: bool,
        is_abstract: bool,
        access: (SubTag[Token] | None),
        signature: FuncSignature | EventSignature | None,
        body: (Sequence[CodeBlockStmt] | ImplDef | Expr | None),
        kid: Sequence[UniNode],
        doc: (String | None) = None,
        decorators: (Sequence[Expr] | None) = None
    ) -> None;

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
class FuncSignature(UniNode) {
    def init(
        self: FuncSignature,
        posonly_params: Sequence[ParamVar],
        params: (Sequence[ParamVar] | None),
        varargs: (ParamVar | None),
        kwonlyargs: Sequence[ParamVar],
        kwargs: (ParamVar | None),
        return_type: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None;

    """Return all parameters in the declared order."""
    def get_parameters(self: FuncSignature) -> list[ParamVar];

    @property
    def is_static(self: FuncSignature) -> bool;

    @property
    def is_in_py_class(self: FuncSignature) -> bool;
}

"""EventSignature node type for Jac Ast."""
class EventSignature(WalkerStmtOnlyNode) {
    def init(
        self: EventSignature,
        event: Token,
        arch_tag_info: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None;
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
class ParamVar(AstSymbolNode, AstTypedVarNode) {
    def init(
        self: ParamVar,
        name: Name,
        unpack: (Token | None),
        type_tag: SubTag[Expr],
        value: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None;

    @property
    def is_vararg(self: ParamVar) -> bool;

    @property
    def is_kwargs(self: ParamVar) -> bool;
}

"""ArchHas node type for Jac Ast."""
class ArchHas(AstAccessNode, AstDocNode, ArchBlockStmt, CodeBlockStmt) {
    def init(
        self: ArchHas,
        is_static: bool,
        access: (SubTag[Token] | None),
        vars: Sequence[HasVar],
        is_frozen: bool,
        kid: Sequence[UniNode],
        doc: (String | None) = None
    ) -> None;
}

"""HasVar node type for Jac Ast."""
class HasVar(AstSymbolNode, AstTypedVarNode) {
    def init(
        self: HasVar,
        name: Name,
        type_tag: SubTag[Expr],
        value: (Expr | None),
        defer: bool,
        kid: Sequence[UniNode]
    ) -> None;
}

"""TypedCtxBlock node type for Jac Ast."""
class TypedCtxBlock(CodeBlockStmt, WalkerStmtOnlyNode, UniScopeNode) {
    def init(
        self: TypedCtxBlock,
        type_ctx: Expr,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode]
    ) -> None;
}

"""IfStmt node type for Jac Ast."""
class IfStmt(CodeBlockStmt, AstElseBodyNode, UniScopeNode) {
    def init(
        self: IfStmt,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: ElseStmt | ElseIf | None,
        kid: Sequence[UniNode]
    ) -> None;
}

"""ElseIf node type for Jac Ast."""
class ElseIf(IfStmt) {}

"""ElseStmt node type for Jac Ast."""
class ElseStmt(UniScopeNode) {
    def init(
        self: ElseStmt, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode]
    ) -> None;
}

"""ExprStmt node type for Jac Ast."""
class ExprStmt(CodeBlockStmt) {
    def init(
        self: ExprStmt, expr: Expr, in_fstring: bool, kid: Sequence[UniNode]
    ) -> None;
}

"""TryStmt node type for Jac Ast."""
class TryStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    def init(
        self: TryStmt,
        body: Sequence[CodeBlockStmt],
        excepts: Sequence[Except],
        else_body: (ElseStmt | None),
        finally_body: (FinallyStmt | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""Except node type for Jac Ast."""
class Except(CodeBlockStmt, UniScopeNode) {
    def init(
        self: Except,
        ex_type: Expr,
        name: (Name | None),
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode]
    ) -> None;
}

"""FinallyStmt node type for Jac Ast."""
class FinallyStmt(CodeBlockStmt, UniScopeNode) {
    def init(
        self: FinallyStmt, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode]
    ) -> None;
}

"""IterForStmt node type for Jac Ast."""
class IterForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    def init(
        self: IterForStmt,
        iter: Assignment,
        is_async: bool,
        condition: Expr,
        count_by: Assignment,
        body: Sequence[CodeBlockStmt],
        else_body: (ElseStmt | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""InForStmt node type for Jac Ast."""
class InForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    def init(
        self: InForStmt,
        target: Expr,
        is_async: bool,
        collection: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: (ElseStmt | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""WhileStmt node type for Jac Ast."""
class WhileStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    def init(
        self: WhileStmt,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: (ElseStmt | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""WithStmt node type for Jac Ast."""
class WithStmt(AstAsyncNode, CodeBlockStmt, UniScopeNode) {
    def init(
        self: WithStmt,
        is_async: bool,
        exprs: Sequence[ExprAsItem],
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode]
    ) -> None;
}

"""ExprAsItem node type for Jac Ast."""
class ExprAsItem(UniNode) {
    def init(
        self: ExprAsItem, expr: Expr, alias: (Expr | None), kid: Sequence[UniNode]
    ) -> None;
}

"""RaiseStmt node type for Jac Ast."""
class RaiseStmt(CodeBlockStmt) {
    def init(
        self: RaiseStmt,
        cause: (Expr | None),
        from_target: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""AssertStmt node type for Jac Ast."""
class AssertStmt(CodeBlockStmt) {
    def init(
        self: AssertStmt,
        condition: Expr,
        error_msg: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""CtrlStmt node type for Jac Ast."""
class CtrlStmt(CodeBlockStmt) {
    def init(self: CtrlStmt, ctrl: Token, kid: Sequence[UniNode]) -> None;
}

"""DeleteStmt node type for Jac Ast."""
class DeleteStmt(CodeBlockStmt) {
    def init(self: DeleteStmt, target: Expr, kid: Sequence[UniNode]) -> None;
    """Get Python AST targets (without setting ctx)."""
    @property
    def py_ast_targets(self: DeleteStmt) -> list[ast3.AST];
}

"""ReportStmt node type for Jac Ast."""
class ReportStmt(CodeBlockStmt) {
    def init(self: ReportStmt, expr: Expr, kid: Sequence[UniNode]) -> None;
}

"""ReturnStmt node type for Jac Ast."""
class ReturnStmt(CodeBlockStmt) {
    def init(self: ReturnStmt, expr: (Expr | None), kid: Sequence[UniNode]) -> None;
}

"""VisitStmt node type for Jac Ast."""
class VisitStmt(WalkerStmtOnlyNode, AstElseBodyNode, CodeBlockStmt) {
    def init(
        self: VisitStmt,
        insert_loc: (Expr | None),
        target: Expr,
        else_body: (ElseStmt | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""DisengageStmt node type for Jac Ast."""
class DisengageStmt(WalkerStmtOnlyNode, CodeBlockStmt) {
    """Initialize disengage statement node."""
    def init(self: DisengageStmt, kid: Sequence[UniNode]) -> None;
}

"""AwaitExpr node type for Jac Ast."""
class AwaitExpr(Expr) {
    def init(self: AwaitExpr, target: Expr, kid: Sequence[UniNode]) -> None;
}

"""GlobalStmt node type for Jac Ast."""
class GlobalStmt(CodeBlockStmt) {
    def init(
        self: GlobalStmt, target: Sequence[NameAtom], kid: Sequence[UniNode]
    ) -> None;
}

"""NonLocalStmt node type for Jac Ast."""
class NonLocalStmt(GlobalStmt) {}

"""Assignment node type for Jac Ast."""
class Assignment(AstTypedVarNode, EnumBlockStmt, CodeBlockStmt) {
    def init(
        self: Assignment,
        target: Sequence[Expr],
        value: Expr | YieldExpr | None,
        type_tag: (SubTag[Expr] | None),
        kid: Sequence[UniNode],
        mutable: bool = True,
        aug_op: (Token | None) = None,
        is_enum_stmt: bool = False
    ) -> None;
}

"""ConcurrentExpr node type for Jac Ast."""
class ConcurrentExpr(Expr) {
    def init(
        self: ConcurrentExpr, tok: (Token | None), target: Expr, kid: Sequence[UniNode]
    ) -> None;
}

"""BinaryExpr node type for Jac Ast."""
class BinaryExpr(Expr) {
    def init(
        self: BinaryExpr,
        left: Expr,
        right: Expr,
        op: Token | DisconnectOp | ConnectOp,
        kid: Sequence[UniNode]
    ) -> None;
}

"""CompareExpr node type for Jac Ast."""
class CompareExpr(Expr) {
    def init(
        self: CompareExpr,
        left: Expr,
        rights: list[Expr],
        ops: list[Token],
        kid: Sequence[UniNode]
    ) -> None;
}

"""BoolExpr node type for Jac Ast."""
class BoolExpr(Expr) {
    def init(
        self: BoolExpr, op: Token, values: list[Expr], kid: Sequence[UniNode]
    ) -> None;
}

"""LambdaExpr node type for Jac Ast."""
class LambdaExpr(Expr, UniScopeNode) {
    def init(
        self: LambdaExpr,
        body: (Expr | Sequence[CodeBlockStmt]),
        kid: Sequence[UniNode],
        signature: (FuncSignature | None) = None
    ) -> None;
}

"""UnaryExpr node type for Jac Ast."""
class UnaryExpr(Expr) {
    def init(self: UnaryExpr, operand: Expr, op: Token, kid: Sequence[UniNode]) -> None;
}

"""IfElseExpr node type for Jac Ast."""
class IfElseExpr(Expr) {
    def init(
        self: IfElseExpr,
        condition: Expr,
        value: Expr,
        else_value: Expr,
        kid: Sequence[UniNode]
    ) -> None;
}

"""MultiString node type for Jac Ast."""
class MultiString(AtomExpr) {
    def init(
        self: MultiString,
        strings: Sequence[(String | FString)],
        kid: Sequence[UniNode]
    ) -> None;
}

"""FString node type for Jac Ast."""
class FString(AtomExpr) {
    def init(
        self: FString,
        start: (Token | None),
        parts: Sequence[(String | FormattedValue)],
        end: (Token | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""FormattedValue node type for Jac Ast."""
class FormattedValue(Expr) {
    def init(
        self: FormattedValue,
        format_part: Expr,
        conversion: int,
        format_spec: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""ListVal node type for Jac Ast."""
class ListVal(AtomExpr) {
    def init(self: ListVal, values: Sequence[Expr], kid: Sequence[UniNode]) -> None;
}

"""SetVal node type for Jac Ast."""
class SetVal(AtomExpr) {
    def init(
        self: SetVal, values: (Sequence[Expr] | None), kid: Sequence[UniNode]
    ) -> None;
}

"""TupleVal node type for Jac Ast."""
class TupleVal(AtomExpr) {
    def init(
        self: TupleVal, values: Sequence[(Expr | KWPair)], kid: Sequence[UniNode]
    ) -> None;
}

"""DictVal node type for Jac Ast."""
class DictVal(AtomExpr) {
    def init(self: DictVal, kv_pairs: Sequence[KVPair], kid: Sequence[UniNode]) -> None;
}

"""KVPair node type for Jac Ast."""
class KVPair(UniNode) {
    def init(
        self: KVPair, key: (Expr | None), value: Expr, kid: Sequence[UniNode]
    ) -> None;
}

"""KWPair node type for Jac Ast."""
class KWPair(UniNode) {
    def init(
        self: KWPair, key: (NameAtom | None), value: Expr, kid: Sequence[UniNode]
    ) -> None;
}

"""InnerCompr node type for Jac Ast."""
class InnerCompr(AstAsyncNode, UniScopeNode) {
    def init(
        self: InnerCompr,
        is_async: bool,
        target: Expr,
        collection: Expr,
        conditional: (list[Expr] | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""ListCompr node type for Jac Ast."""
class ListCompr(AtomExpr, UniScopeNode) {
    def init(
        self: ListCompr,
        out_expr: Expr,
        compr: list[InnerCompr],
        kid: Sequence[UniNode]
    ) -> None;
}

"""GenCompr node type for Jac Ast."""
class GenCompr(ListCompr) {}

"""SetCompr node type for Jac Ast."""
class SetCompr(ListCompr) {}

"""DictCompr node type for Jac Ast."""
class DictCompr(AtomExpr, UniScopeNode) {
    def init(
        self: DictCompr,
        kv_pair: KVPair,
        compr: list[InnerCompr],
        kid: Sequence[UniNode]
    ) -> None;
}

"""AtomTrailer node type for Jac Ast."""
class AtomTrailer(Expr) {
    def init(
        self: AtomTrailer,
        target: Expr,
        right: (AtomExpr | Expr),
        is_attr: bool,
        is_null_ok: bool,
        kid: Sequence[UniNode],
        is_genai: bool = False
    ) -> None;

    @property
    def as_attr_list(self: AtomTrailer) -> list[AstSymbolNode];
}

"""AtomUnit node type for Jac Ast."""
class AtomUnit(Expr) {
    def init(
        self: AtomUnit, value: Expr | YieldExpr | Ability, kid: Sequence[UniNode]
    ) -> None;
}

"""YieldExpr node type for Jac Ast."""
class YieldExpr(Expr) {
    def init(
        self: YieldExpr, expr: (Expr | None), with_from: bool, kid: Sequence[UniNode]
    ) -> None;
}

"""FuncCall node type for Jac Ast."""
class FuncCall(Expr) {
    def init(
        self: FuncCall,
        target: Expr,
        params: (Sequence[(Expr | KWPair)] | None),
        genai_call: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""IndexSlice node type for Jac Ast."""
class IndexSlice(AtomExpr) {
    """Slice node type for Jac Ast."""
    @dataclass
    class Slice {
        with entry {
            start: (Expr | None);
            stop: (Expr | None);
            step: (Expr | None);
        }
    }

    def init(
        self: IndexSlice, slices: list[Slice], is_range: bool, kid: Sequence[UniNode]
    ) -> None;
}

"""EdgeRefTrailer node type for Jac Ast."""
class EdgeRefTrailer(Expr) {
    def init(
        self: EdgeRefTrailer,
        chain: list[(Expr | FilterCompr)],
        edges_only: bool,
        is_async: bool,
        kid: Sequence[UniNode]
    ) -> None;
}

"""EdgeOpRef node type for Jac Ast."""
class EdgeOpRef(WalkerStmtOnlyNode, AtomExpr) {
    def init(
        self: EdgeOpRef,
        filter_cond: (FilterCompr | None),
        edge_dir: EdgeDir,
        kid: Sequence[UniNode]
    ) -> None;
}

"""DisconnectOp node type for Jac Ast."""
class DisconnectOp(WalkerStmtOnlyNode) {
    def init(self: DisconnectOp, edge_spec: EdgeOpRef, kid: Sequence[UniNode]) -> None;
}

"""ConnectOpRef node type for Jac Ast."""
class ConnectOp(UniNode) {
    def init(
        self: ConnectOp,
        conn_type: (Expr | None),
        conn_assign: (AssignCompr | None),
        edge_dir: EdgeDir,
        kid: Sequence[UniNode]
    ) -> None;
}

"""FilterCompr node type for Jac Ast."""
class FilterCompr(AtomExpr) {
    def init(
        self: FilterCompr,
        f_type: (Expr | None),
        compares: Sequence[CompareExpr],
        kid: Sequence[UniNode]
    ) -> None;
}

"""AssignCompr node type for Jac Ast."""
class AssignCompr(AtomExpr) {
    def init(
        self: AssignCompr, assigns: Sequence[KWPair], kid: Sequence[UniNode]
    ) -> None;
}

"""JsxElement node type for Jac Ast."""
class JsxElement(AtomExpr) {
    def init(
        self: JsxElement,
        name: (JsxElementName | None),
        attributes: (Sequence[JsxAttribute] | None),
        children: (Sequence[(JsxChild | JsxElement)] | None),
        is_self_closing: bool,
        is_fragment: bool,
        kid: Sequence[UniNode]
    ) -> None;

    """Get the source line after the opening tag's '>' token (body start)."""
    def get_body_start_line(self: JsxElement) -> (int | None);

    """Get the source line of the closing tag's '</' token (body end)."""
    def get_body_end_line(self: JsxElement) -> (int | None);
}

"""JsxElementName node type for Jac Ast."""
class JsxElementName(UniNode) {
    def init(
        self: JsxElementName, parts: Sequence[(Name | Token)], kid: Sequence[UniNode]
    ) -> None;
}

"""JsxAttribute node type for Jac Ast (base class)."""
class JsxAttribute(UniNode) {
    def init(self: JsxAttribute, kid: Sequence[UniNode]) -> None;
}

"""JsxSpreadAttribute node type for Jac Ast."""
class JsxSpreadAttribute(JsxAttribute) {
    def init(self: JsxSpreadAttribute, expr: Expr, kid: Sequence[UniNode]) -> None;
}

"""JsxNormalAttribute node type for Jac Ast."""
class JsxNormalAttribute(JsxAttribute) {
    def init(
        self: JsxNormalAttribute,
        name: (Name | Token),
        value: String | Expr | None,
        kid: Sequence[UniNode]
    ) -> None;
}

"""JsxChild node type for Jac Ast (base class)."""
class JsxChild(UniNode) {
    def init(self: JsxChild, kid: Sequence[UniNode]) -> None;
}

"""JsxText node type for Jac Ast."""
class JsxText(JsxChild) {
    def init(self: JsxText, value: (str | Token), kid: Sequence[UniNode]) -> None;
    """Normalize JSX text whitespace (single source of truth).

    HTML-like rules: strip leading/trailing newline+whitespace,
    collapse internal newline+whitespace sequences to a single space.
    """
    def get_normalized_text(self: JsxText) -> str;
}

"""JsxExpression node type for Jac Ast."""
class JsxExpression(JsxChild) {
    def init(self: JsxExpression, expr: Expr, kid: Sequence[UniNode]) -> None;
}

"""MatchStmt node type for Jac Ast."""
class MatchStmt(CodeBlockStmt) {
    def init(
        self: MatchStmt, target: Expr, cases: list[MatchCase], kid: Sequence[UniNode]
    ) -> None;
}

"""MatchCase node type for Jac Ast."""
class MatchCase(UniScopeNode) {
    def init(
        self: MatchCase,
        pattern: MatchPattern,
        guard: (Expr | None),
        body: list[CodeBlockStmt],
        kid: Sequence[UniNode]
    ) -> None;
}

"""SwitchStmt node type for Jac Ast."""
class SwitchStmt(CodeBlockStmt) {
    def init(
        self: SwitchStmt, target: Expr, cases: list[SwitchCase], kid: Sequence[UniNode]
    ) -> None;
}

"""SwitchCase node type for Jac Ast."""
class SwitchCase(UniScopeNode) {
    def init(
        self: SwitchCase,
        pattern: (MatchPattern | None),
        body: list[CodeBlockStmt],
        kid: Sequence[UniNode]
    ) -> None;
}

"""MatchOr node type for Jac Ast."""
class MatchOr(MatchPattern) {
    def init(
        self: MatchOr, patterns: list[MatchPattern], kid: Sequence[UniNode]
    ) -> None;
}

"""MatchAs node type for Jac Ast."""
class MatchAs(MatchPattern) {
    def init(
        self: MatchAs,
        name: NameAtom,
        pattern: (MatchPattern | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""MatchWild node type for Jac Ast."""
class MatchWild(MatchPattern) {}

"""MatchValue node type for Jac Ast."""
class MatchValue(MatchPattern) {
    def init(self: MatchValue, value: Expr, kid: Sequence[UniNode]) -> None;
}

"""MatchSingleton node type for Jac Ast."""
class MatchSingleton(MatchPattern) {
    def init(
        self: MatchSingleton, value: (Bool | Null), kid: Sequence[UniNode]
    ) -> None;
}

"""MatchSequence node type for Jac Ast."""
class MatchSequence(MatchPattern) {
    def init(
        self: MatchSequence, values: list[MatchPattern], kid: Sequence[UniNode]
    ) -> None;
}

"""MatchMapping node type for Jac Ast."""
class MatchMapping(MatchPattern) {
    def init(
        self: MatchMapping,
        values: list[(MatchKVPair | MatchStar)],
        kid: Sequence[UniNode]
    ) -> None;
}

"""MatchKVPair node type for Jac Ast."""
class MatchKVPair(MatchPattern) {
    def init(
        self: MatchKVPair,
        key: MatchPattern | NameAtom | AtomExpr,
        value: MatchPattern,
        kid: Sequence[UniNode]
    ) -> None;
}

"""MatchStar node type for Jac Ast."""
class MatchStar(MatchPattern) {
    def init(
        self: MatchStar, name: NameAtom, is_list: bool, kid: Sequence[UniNode]
    ) -> None;
}

"""MatchArch node type for Jac Ast."""
class MatchArch(MatchPattern) {
    def init(
        self: MatchArch,
        name: (AtomTrailer | NameAtom),
        arg_patterns: (Sequence[MatchPattern] | None),
        kw_patterns: (Sequence[MatchKVPair] | None),
        kid: Sequence[UniNode]
    ) -> None;
}

"""Token node type for Jac Ast."""
class Token(UniNode) {
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
class Name(Token, NameAtom) {
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
class SpecialVarRef(Name) {
    def init(self: SpecialVarRef, var: Name, is_enum_stmt: bool = False) -> None;
    def py_resolve_name(self: SpecialVarRef) -> str;
}

"""Literal node type for Jac Ast."""
class Literal(Token, AtomExpr) {
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
class BuiltinType(Name, Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.VAR;
    }

    """Return literal value in its python type."""
    @property
    def lit_value(self: BuiltinType) -> Callable[([], Any)];
}

"""Float node type for Jac Ast."""
class Float(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    @property
    def lit_value(self: Float) -> float;
}

"""Int node type for Jac Ast."""
class Int(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    @property
    def lit_value(self: Int) -> int;
}

"""String node type for Jac Ast."""
class String(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.STRING;
    }

    @property
    def lit_value(self: String) -> str;
}

"""Bool node type for Jac Ast."""
class Bool(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.BOOL;
    }

    @property
    def lit_value(self: Bool) -> bool;
}

"""Null node type for Jac Ast."""
class Null(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    @property
    def lit_value(self: Null) -> None;
}

"""Ellipsis node type for Jac Ast."""
class Ellipsis(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    @property
    def lit_value(self: Ellipsis) -> EllipsisType;
}

"""EmptyToken node type for Jac Ast."""
class EmptyToken(Token) {
    def init(self: EmptyToken, orig_src: (Source | None) = None) -> None;
}

"""Semicolon node type for Jac Ast."""
class Semi(Token, CodeBlockStmt) {
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
class CommentToken(Token) {
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
class Source(EmptyToken) {
    def init(self: Source, source: str, mod_path: str) -> None;
    """Return the source code as string."""
    @property
    def code(self: Source) -> str;
}

"""SourceString node type for Jac Ast."""
class PythonModuleAst(EmptyToken) {
    def init(self: PythonModuleAst, ast: ast3.Module, orig_src: Source) -> None;
}
