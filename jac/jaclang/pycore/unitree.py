"""Abstract class for IR Passes for Jac."""

from __future__ import annotations

import ast as ast3
import builtins
import os
from collections.abc import Callable, Sequence
from copy import copy
from dataclasses import dataclass, field
from enum import IntEnum
from hashlib import md5
from types import EllipsisType
from typing import (
    TYPE_CHECKING,
    Any,
    Generic,
    TypeVar,
    cast,
)

from jaclang.pycore.bccache import discover_base_file
from jaclang.pycore.codeinfo import CodeGenTarget, CodeLocInfo
from jaclang.pycore.constant import (
    DELIM_MAP,
    CodeContext,
    EdgeDir,
    SymbolAccess,
    SymbolType,
)
from jaclang.pycore.constant import (
    Constants as Con,
)
from jaclang.pycore.constant import (
    JacSemTokenModifier as SemTokMod,
)
from jaclang.pycore.constant import (
    JacSemTokenType as SemTokType,
)
from jaclang.pycore.constant import Tokens as Tok
from jaclang.pycore.modresolver import resolve_relative_path

if TYPE_CHECKING:
    from jaclang.compiler.type_system.types import TypeBase
from jaclang.pycore.treeprinter import (
    print_ast_tree,
    print_symtab_tree,
    printgraph_ast_tree,
    printgraph_symtab_tree,
)


class UniNode:
    """Abstract syntax tree node for Jac."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        """Initialize ast."""
        self.parent: UniNode | None = None
        self.kid: list[UniNode] = [x.set_parent(self) for x in kid]
        self.__sub_node_tab: dict[type, list[UniNode]] | None = None
        self._in_mod_nodes: list[UniNode] = []
        self._gen: CodeGenTarget | None = None
        self.loc: CodeLocInfo = CodeLocInfo(*self.resolve_tok_range())

    @property
    def gen(self) -> CodeGenTarget:
        """Lazy initialization of CodeGenTarget."""
        if self._gen is None:
            self._gen = CodeGenTarget()
        return self._gen

    @gen.setter
    def gen(self, value: CodeGenTarget) -> None:
        """Set CodeGenTarget."""
        self._gen = value

    @property
    def _sub_node_tab(self) -> dict[type, list[UniNode]]:
        """Lazy initialization of sub node table."""
        if self.__sub_node_tab is None:
            self.__sub_node_tab = {}
            self._construct_sub_node_tab()
        return self.__sub_node_tab

    def _construct_sub_node_tab(self) -> None:
        """Construct sub node table."""
        for i in self.kid:
            if not i:
                continue
            for k, v in i._sub_node_tab.items():
                if k in self.__sub_node_tab:  # type: ignore
                    self.__sub_node_tab[k].extend(v)  # type: ignore
                else:
                    self.__sub_node_tab[k] = copy(v)  # type: ignore
            if type(i) in self.__sub_node_tab:  # type: ignore
                self.__sub_node_tab[type(i)].append(i)  # type: ignore
            else:
                self.__sub_node_tab[type(i)] = [i]  # type: ignore

    @property
    def sym_tab(self) -> UniScopeNode:
        """Get symbol table."""
        return (
            self
            if isinstance(self, UniScopeNode)
            else self.parent_of_type(UniScopeNode)
        )

    def add_kids_left(
        self,
        nodes: Sequence[UniNode],
        pos_update: bool = True,
        parent_update: bool = False,
    ) -> UniNode:
        """Add kid left."""
        self.kid = [*nodes, *self.kid]
        if pos_update:
            for i in nodes:
                i.parent = self
            self.loc.update_first_token(self.kid[0].loc.first_tok)
        elif parent_update:
            for i in nodes:
                i.parent = self
        return self

    def add_kids_right(
        self,
        nodes: Sequence[UniNode],
        pos_update: bool = True,
        parent_update: bool = False,
    ) -> UniNode:
        """Add kid right."""
        self.kid = [*self.kid, *nodes]
        if pos_update:
            for i in nodes:
                i.parent = self
            self.loc.update_last_token(self.kid[-1].loc.last_tok)
        elif parent_update:
            for i in nodes:
                i.parent = self
        return self

    def insert_kids_at_pos(
        self, nodes: Sequence[UniNode], pos: int, pos_update: bool = True
    ) -> UniNode:
        """Insert kids at position."""
        self.kid = [*self.kid[:pos], *nodes, *self.kid[pos:]]
        if pos_update:
            for i in nodes:
                i.parent = self
            self.loc.update_token_range(*self.resolve_tok_range())
        return self

    def set_kids(self, nodes: Sequence[UniNode]) -> UniNode:
        """Set kids."""
        self.kid = [*nodes]
        for i in nodes:
            i.parent = self
        self.loc.update_token_range(*self.resolve_tok_range())
        return self

    def set_parent(self, parent: UniNode) -> UniNode:
        """Set parent."""
        self.parent = parent
        return self

    def resolve_tok_range(self) -> tuple[Token, Token]:
        if len(self.kid):
            return (
                self.kid[0].loc.first_tok,
                self.kid[-1].loc.last_tok,
            )
        elif isinstance(self, Token):
            return (self, self)
        else:
            raise ValueError(f"Empty kid for Token {type(self).__name__}")

    def gen_token(self, name: Tok, value: str | None = None) -> Token:
        from jaclang.pycore.jac_parser import TOKEN_MAP

        value = (
            value
            if value
            else (
                DELIM_MAP[name]
                if name in DELIM_MAP
                else TOKEN_MAP.get(name.value, name.value)
            )
        )
        return Token(
            name=name,
            value=value,
            orig_src=self.loc.orig_src,
            col_start=self.loc.col_start,
            col_end=0,
            line=self.loc.first_line,
            end_line=self.loc.last_line,
            pos_start=0,
            pos_end=0,
        )

    def get_all_sub_nodes(self, typ: type[T], brute_force: bool = True) -> list[T]:
        """Get all sub nodes of type."""
        from jaclang.pycore.passes import UniPass

        return UniPass.get_all_sub_nodes(node=self, typ=typ, brute_force=brute_force)

    def find_parent_of_type(self, typ: type[T]) -> T | None:
        """Get parent of type."""
        from jaclang.pycore.passes import UniPass

        return UniPass.find_parent_of_type(node=self, typ=typ)

    def parent_of_type(self, typ: type[T]) -> T:
        ret = self.find_parent_of_type(typ)
        if isinstance(ret, typ):
            return ret
        else:
            raise ValueError(f"Parent of type {typ} not found from {type(self)}.")

    def in_client_context(self) -> bool:
        """Check if this node is in a client-side context.

        This covers:
        - Nodes inside an explicit cl {} block in a .jac file
        - Nodes inside a function marked with CLIENT context in .cl.jac files
        - Overridden by sv {} blocks (server takes precedence)

        Uses single traversal for efficiency since this is called frequently.
        """
        node: UniNode | None = self.parent
        while node is not None:
            # ServerBlock overrides - explicit server context
            if isinstance(node, ServerBlock):
                return False
            # ClientBlock marks client context
            if isinstance(node, ClientBlock):
                return True
            # Check for client-marked Ability (.cl.jac files)
            # Only return True for explicit CLIENT context; continue traversing
            # for SERVER (default) context as the ability may be nested in a ClientBlock
            if isinstance(node, Ability):
                context = getattr(node, "code_context", CodeContext.SERVER)
                if context == CodeContext.CLIENT:
                    return True
                # Continue traversing - nested functions may still be in a ClientBlock
            node = node.parent
        return False

    def in_native_context(self) -> bool:
        """Check if this node is in a native context.

        This covers:
        - Nodes inside an explicit na {} block in a .jac file
        - Nodes inside a function marked with NATIVE context in .na.jac files
        - Overridden by sv {} or cl {} blocks
        """
        node: UniNode | None = self.parent
        while node is not None:
            if isinstance(node, (ServerBlock, ClientBlock)):
                return False
            if isinstance(node, NativeBlock):
                return True
            if isinstance(node, Ability):
                context = getattr(node, "code_context", CodeContext.SERVER)
                if context == CodeContext.NATIVE:
                    return True
            node = node.parent
        return False

    def to_dict(self) -> dict[str, str]:
        """Return dict representation of node."""
        ret = {
            "node": str(type(self).__name__),
            "kid": str([x.to_dict() for x in self.kid if x]),
            "line": str(self.loc.first_line),
            "col": str(self.loc.col_start),
        }
        if isinstance(self, Token):
            ret["name"] = self.name
            ret["value"] = self.value
        return ret

    def pp(self, depth: int | None = None) -> str:
        """Print ast."""
        return print_ast_tree(self, max_depth=depth)

    def printgraph(self) -> str:
        """Print ast."""
        return printgraph_ast_tree(self)

    def flatten(self) -> list[UniNode]:
        """Flatten ast."""
        ret: list[UniNode] = [self]
        for k in self.kid:
            ret += k.flatten()
        return ret

    def unparse(self) -> str:
        if self.gen.jac:
            return self.gen.jac
        return " ".join([i.unparse() for i in self.kid])


# Symbols can have multiple definitions but resolves decl to be the
# first such definition in a given scope.
# Symbols may exist without a parent symbol table (parent_tab=None),
# such as imports like 'from a.b.c {...}' or with alias.
# These symbols(a,b,c) are not inserted into symbol tables
# but are still used for go-to-def, find references, and rename.
class Symbol:
    """Symbol."""

    def __init__(
        self,
        defn: NameAtom,
        access: SymbolAccess,
        parent_tab: UniScopeNode | None = None,
        imported: bool = False,
    ) -> None:
        """Initialize."""
        self.defn: list[NameAtom] = [defn]
        self.uses: list[NameAtom] = []
        self.imported: bool = imported
        defn.sym = self
        self.access: SymbolAccess = access
        self.parent_tab = parent_tab
        self.semstr: str = ""

    @property
    def decl(self) -> NameAtom:
        """Get decl."""
        return self.defn[0]

    @property
    def sym_name(self) -> str:
        """Get name."""
        return self.decl.sym_name

    @property
    def sym_type(self) -> SymbolType:
        """Get sym_type."""
        return self.decl.sym_category

    @property
    def sym_dotted_name(self) -> str:
        """Return a full path of the symbol."""
        out = [self.defn[0].sym_name]
        current_tab: UniScopeNode | None = self.parent_tab
        while current_tab is not None:
            out.append(current_tab.scope_name)
            current_tab = current_tab.parent_scope
        out.reverse()
        return ".".join(out)

    @property
    def symbol_table(self) -> UniScopeNode | None:
        """Get symbol table."""
        if self.parent_tab:
            return self.parent_tab.find_scope(self.sym_name)
        return None

    def add_defn(self, node: NameAtom) -> None:
        """Add defn."""
        self.defn.append(node)
        node.sym = self

    def add_use(self, node: NameAtom) -> None:
        """Add use."""
        self.uses.append(node)
        node.sym = self

    def __repr__(self) -> str:
        """Repr."""
        return f"Symbol({self.sym_name}, {self.sym_type}, {self.access}, {self.defn})"


@dataclass
class InheritedSymbolTable:
    """Represents an inherited symbol table for selective imports."""

    base_symbol_table: UniScopeNode
    load_all_symbols: bool = False
    symbols: list[str] = field(default_factory=list)


class UniScopeNode(UniNode):
    """Symbol Table."""

    def __init__(
        self,
        name: str,
        parent_scope: UniScopeNode | None = None,
    ) -> None:
        """Initialize."""
        self.scope_name = name
        self.parent_scope = parent_scope
        self.kid_scope: list[UniScopeNode] = []
        self.names_in_scope: dict[str, Symbol] = {}
        self.names_in_scope_overload: dict[str, list[Symbol]] = {}
        self.inherited_scope: list[InheritedSymbolTable] = []

    def get_type(self) -> SymbolType:
        """Get type."""
        if isinstance(self, AstSymbolNode):
            return self.sym_category
        return SymbolType.VAR

    def get_parent(self) -> UniScopeNode | None:
        """Get parent."""
        return self.parent_scope

    @staticmethod
    def get_python_scoping_nodes() -> tuple[type[UniScopeNode], ...]:
        return (
            Module,
            Enum,
            Archetype,
            Ability,
            ImplDef,
            Test,
        )

    def lookup(
        self,
        name: str,
        deep: bool = True,
        incl_inner_scope: bool = False,
    ) -> Symbol | None:
        """Lookup a variable in the symbol table."""
        if name in self.names_in_scope:
            return self.names_in_scope[name]

        if (deep and self.parent_scope) and (
            sym := self.parent_scope.lookup(name, deep)
        ):
            return sym

        if incl_inner_scope:
            for kid in self.kid_scope:
                if isinstance(
                    kid,
                    UniScopeNode.get_python_scoping_nodes(),
                ):
                    continue
                if (sym := kid.lookup(name, False, True)) is not None:
                    return sym

        return None

    def insert(
        self,
        node: AstSymbolNode,
        access_spec: AstAccessNode | None | SymbolAccess = None,
        single: bool = False,
        force_overwrite: bool = False,
        imported: bool = False,
    ) -> UniNode | None:
        """Set a variable in the symbol table.

        Returns original symbol as collision if single check fails, none otherwise.
        Also updates node.sym to create pointer to symbol.
        """
        collision = (
            self.names_in_scope[node.sym_name].defn[-1]
            if single and node.sym_name in self.names_in_scope
            else None
        )

        symbol = node.name_spec.create_symbol(
            access=(
                access_spec
                if isinstance(access_spec, SymbolAccess)
                else access_spec.access_type
                if access_spec
                else SymbolAccess.PUBLIC
            ),
            parent_tab=self,
            imported=imported,
        )

        if node.sym_name in self.names_in_scope:
            self.names_in_scope_overload.setdefault(node.sym_name, []).append(symbol)

        if force_overwrite or node.sym_name not in self.names_in_scope:
            self.names_in_scope[node.sym_name] = symbol
        else:
            self.names_in_scope[node.sym_name].add_defn(node.name_spec)
        node.name_spec.sym = self.names_in_scope[node.sym_name]
        return collision

    def find_scope(self, name: str) -> UniScopeNode | None:
        """Find a scope in the symbol table."""
        for k in self.kid_scope:
            if k.scope_name == name:
                return k
        return None

    def link_kid_scope(self, key_node: UniScopeNode) -> UniScopeNode:
        """Push a new scope onto the symbol table."""
        key_node.parent_scope = self
        self.kid_scope.append(key_node)
        return self.kid_scope[-1]

    def inherit_sym_tab(self, target_sym_tab: UniScopeNode) -> None:
        """Inherit symbol table."""
        for i in target_sym_tab.names_in_scope.values():
            self.def_insert(i.decl, access_spec=i.access)

    def def_insert(
        self,
        node: AstSymbolNode,
        access_spec: AstAccessNode | None | SymbolAccess = None,
        single_decl: str | None = None,
        force_overwrite: bool = False,
        imported: bool = False,
    ) -> Symbol | None:
        """Insert into symbol table."""
        if node.sym and self == node.sym.parent_tab:
            return node.sym
        self.insert(
            node=node,
            single=single_decl is not None,
            access_spec=access_spec,
            force_overwrite=force_overwrite,
            imported=imported,
        )
        self.update_py_ctx_for_def(node)
        return node.sym

    def chain_def_insert(self, node_list: list[AstSymbolNode]) -> None:
        """Link chain of containing names to symbol."""
        if not node_list:
            return
        cur_sym_tab: UniScopeNode | None = node_list[0].sym_tab
        node_list[-1].name_spec.py_ctx_func = ast3.Store
        if isinstance(node_list[-1].name_spec, AstSymbolNode):
            node_list[-1].name_spec.py_ctx_func = ast3.Store

        node_list = node_list[:-1]  # Just performs lookup mappings of pre assign chain
        for i in node_list:
            cur_sym_tab = (
                lookup.decl.sym_tab
                if (
                    lookup := self.use_lookup(
                        i,
                        sym_table=cur_sym_tab,
                    )
                )
                else None
            )

    def use_lookup(
        self,
        node: AstSymbolNode,
        sym_table: UniScopeNode | None = None,
    ) -> Symbol | None:
        """Link to symbol."""
        if node.sym:
            return node.sym
        if not sym_table:
            sym_table = node.sym_tab
        if sym_table:
            lookup = sym_table.lookup(name=node.sym_name, deep=True)
            lookup.add_use(node.name_spec) if lookup else None
        return node.sym

    def chain_use_lookup(self, node_list: Sequence[AstSymbolNode]) -> None:
        """Link chain of containing names to symbol."""
        if not node_list:
            return
        cur_sym_tab: UniScopeNode | None = node_list[0].sym_tab
        for i in node_list:
            if cur_sym_tab is None:
                break
            lookup = self.use_lookup(i, sym_table=cur_sym_tab)
            if lookup:
                cur_sym_tab = lookup.decl.sym_tab

                # check if the symbol table name is not the same as symbol name
                # then try to find a child scope with the same name
                # This is used to get the scope in case of
                #      import math;
                #      b = math.floor(1.7);
                if cur_sym_tab.scope_name != i.sym_name:
                    t = cur_sym_tab.find_scope(i.sym_name)
                    if t:
                        cur_sym_tab = t
            else:
                cur_sym_tab = None

    def update_py_ctx_for_def(self, node: AstSymbolNode) -> None:
        """Update python context for definition."""
        node.name_spec.py_ctx_func = ast3.Store
        if isinstance(node, (TupleVal, ListVal)) and node.values:
            # Handling of UnaryExpr case for item is only necessary for
            # the generation of Starred nodes in the AST for examples
            # like `(a, *b) = (1, 2, 3, 4)`.
            def fix(item: TupleVal | ListVal | UnaryExpr) -> None:
                if isinstance(item, UnaryExpr):
                    if isinstance(item.operand, AstSymbolNode):
                        item.operand.name_spec.py_ctx_func = ast3.Store
                elif isinstance(item, (TupleVal, ListVal)):
                    for i in item.values:
                        if isinstance(i, AstSymbolNode):
                            i.name_spec.py_ctx_func = ast3.Store
                        elif isinstance(i, AtomTrailer):
                            self.chain_def_insert(i.as_attr_list)
                        if isinstance(i, (TupleVal, ListVal, UnaryExpr)):
                            fix(i)

            fix(node)

    def sym_pp(self, depth: int | None = None) -> str:
        """Pretty print."""
        return print_symtab_tree(root=self, depth=depth)

    def sym_printgraph(self) -> str:
        """Generate dot graph for sym table."""
        return printgraph_symtab_tree(self)

    def __repr__(self) -> str:
        """Repr."""
        out = f"{self.scope_name} {super().__repr__()}:\n"
        for k, v in self.names_in_scope.items():
            out += f"    {k}: {v}\n"
        return out


class AstSymbolNode(UniNode):
    """Nodes that have link to a symbol in symbol table."""

    def __init__(
        self, sym_name: str, name_spec: NameAtom, sym_category: SymbolType
    ) -> None:
        self.name_spec = name_spec
        self.name_spec.name_of = self
        self.name_spec._sym_name = sym_name
        self.name_spec._sym_category = sym_category
        self.semstr = ""

    @property
    def sym(self) -> Symbol | None:
        return self.name_spec.sym

    @property
    def sym_name(self) -> str:
        return self.name_spec.sym_name

    @property
    def sym_category(self) -> SymbolType:
        return self.name_spec.sym_category

    @property
    def py_ctx_func(self) -> type[ast3.AST]:
        return self.name_spec.py_ctx_func

    @property
    def expr_type(self) -> str:
        return self.name_spec.expr_type

    @property
    def type_sym_tab(self) -> UniScopeNode | None:
        """Get type symbol table."""
        return self.name_spec.type_sym_tab


class AstSymbolStubNode(AstSymbolNode):
    """Nodes that have link to a symbol in symbol table."""

    def __init__(self, sym_type: SymbolType) -> None:
        AstSymbolNode.__init__(
            self,
            sym_name=f"[{self.__class__.__name__}]",
            name_spec=Name.gen_stub_from_node(self, f"[{self.__class__.__name__}]"),
            sym_category=sym_type,
        )


class AstAccessNode(UniNode):
    """Nodes that have access."""

    def __init__(self, access: SubTag[Token] | None) -> None:
        self.access: SubTag[Token] | None = access

    @property
    def access_type(self) -> SymbolAccess:
        return (
            SymbolAccess.PRIVATE
            if self.access and self.access.tag.name == Tok.KW_PRIV
            else (
                SymbolAccess.PROTECTED
                if self.access and self.access.tag.name == Tok.KW_PROT
                else SymbolAccess.PUBLIC
            )
        )

    @property
    def public_access(self) -> bool:
        return self.access_type == SymbolAccess.PUBLIC


T = TypeVar("T", bound=UniNode)


class ContextAwareNode(UniNode):
    """Base class for nodes that can be marked with execution context (client/server)."""

    def __init__(self, code_context: CodeContext = CodeContext.SERVER) -> None:
        """Initialize with code context.

        Args:
            code_context: Code execution context (SERVER or CLIENT), defaults to SERVER
        """
        self.code_context = code_context

    def _source_context_token(self) -> Token | None:
        """Return the original context token (cl or sv) if present on this node."""
        for kid in self.kid:
            if isinstance(kid, Token) and kid.name in (Tok.KW_CLIENT, Tok.KW_SERVER):
                return kid
        return None


class AstDocNode(UniNode):
    """Nodes that have access."""

    def __init__(self, doc: String | None) -> None:
        self.doc: String | None = doc


class AstAsyncNode(UniNode):
    """Nodes that have access."""

    def __init__(self, is_async: bool) -> None:
        self.is_async: bool = is_async


class AstElseBodyNode(UniNode):
    """Nodes that have access."""

    def __init__(self, else_body: ElseStmt | ElseIf | None) -> None:
        self.else_body: ElseStmt | ElseIf | None = else_body


class AstTypedVarNode(UniNode):
    """Nodes that have access."""

    def __init__(self, type_tag: SubTag[Expr] | None) -> None:
        self.type_tag: SubTag[Expr] | None = type_tag


class WalkerStmtOnlyNode(UniNode):
    """WalkerStmtOnlyNode node type for Jac Ast."""

    def __init__(self) -> None:
        self.from_walker: bool = False


class UniCFGNode(UniNode):
    """BasicBlockStmt node type for Jac Uniir."""

    def __init__(self) -> None:
        """Initialize basic block statement node."""
        self.bb_in: list[UniCFGNode] = []
        self.bb_out: list[UniCFGNode] = []

    def get_head(self) -> UniCFGNode:
        """Get head by walking up the CFG iteratively."""
        node = self
        while (
            node.bb_in
            and len(node.bb_in) == 1
            and not isinstance(node.bb_in[0], (InForStmt, IterForStmt, WhileStmt))
            and node.bb_in[0].bb_out
            and len(node.bb_in[0].bb_out) == 1
        ):
            node = node.bb_in[0]
        return node

    def get_tail(self) -> UniCFGNode:
        """Get tail by walking down the CFG iteratively."""
        node = self
        while (
            node.bb_out
            and len(node.bb_out) == 1
            and not isinstance(node.bb_out[0], (InForStmt, IterForStmt, WhileStmt))
            and node.bb_out[0].bb_in
            and len(node.bb_out[0].bb_in) == 1
        ):
            node = node.bb_out[0]
        return node


class Expr(UniNode):
    """Expression is a combination of values, variables operators and fuctions that are evaluated to produce a value.

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

    def __init__(self) -> None:
        self._sym_type: str = "NoType"
        self._type_sym_tab: UniScopeNode | None = None

        # When the type of an expression is resolved, we'll be caching
        # the type here.
        #
        # TODO:
        # 1. Find a better name for this
        # 2. Migrate this to expr_type property
        self.type: TypeBase | None = None

        # Temporary storage for attached tokens (e.g., braces in JSX attributes)
        # TODO: Refactor to eliminate this workaround
        self.attached_tokens: list[Token] | None = None

    @property
    def expr_type(self) -> str:
        return self._sym_type

    @expr_type.setter
    def expr_type(self, sym_type: str) -> None:
        self._sym_type = sym_type

    @property
    def type_sym_tab(self) -> UniScopeNode | None:
        """Get type symbol table."""
        return self._type_sym_tab

    @type_sym_tab.setter
    def type_sym_tab(self, type_sym_tab: UniScopeNode) -> None:
        """Set type symbol table."""
        self._type_sym_tab = type_sym_tab


class AtomExpr(Expr, AstSymbolStubNode):
    """AtomExpr node type for Jac Ast."""


class ElementStmt(AstDocNode):
    """ElementStmt node type for Jac Ast."""


class ArchBlockStmt(UniNode):
    """ArchBlockStmt node type for Jac Ast."""


class EnumBlockStmt(UniNode):
    """EnumBlockStmt node type for Jac Ast."""

    def __init__(self, is_enum_stmt: bool) -> None:
        self.is_enum_stmt = is_enum_stmt


class CodeBlockStmt(UniCFGNode):
    """CodeBlockStmt node type for Jac Ast."""

    def __init__(self) -> None:
        """Initialize code block statement node."""
        UniCFGNode.__init__(self)


class AstImplNeedingNode(AstSymbolNode, Generic[T]):
    """AstImplNeedingNode node type for Jac Ast."""

    def __init__(self, body: T | None) -> None:
        self.body = body

    @property
    def needs_impl(self) -> bool:
        return self.body is None


class NameAtom(AtomExpr, EnumBlockStmt):
    """NameAtom node type for Jac Ast."""

    def __init__(self, is_enum_stmt: bool) -> None:
        self.name_of: AstSymbolNode = self
        self._sym: Symbol | None = None
        self._sym_name: str = ""
        self._sym_category: SymbolType = SymbolType.UNKNOWN
        self._py_ctx_func: type[ast3.expr_context] = ast3.Load
        AtomExpr.__init__(self)
        EnumBlockStmt.__init__(self, is_enum_stmt=is_enum_stmt)

    @property
    def sym(self) -> Symbol | None:
        return self._sym

    @sym.setter
    def sym(self, sym: Symbol) -> None:
        self._sym = sym

    @property
    def sym_name(self) -> str:
        return self._sym_name

    @property
    def sym_category(self) -> SymbolType:
        return self._sym_category

    def create_symbol(
        self,
        access: SymbolAccess,
        parent_tab: UniScopeNode | None = None,
        imported: bool = False,
    ) -> Symbol:
        """Create symbol."""
        sym = Symbol(defn=self, access=access, parent_tab=parent_tab, imported=imported)
        return sym

    @property
    def clean_type(self) -> str:
        ret_type = self.expr_type.replace("builtins.", "").replace("NoType", "")
        return ret_type

    @property
    def py_ctx_func(self) -> type[ast3.expr_context]:
        """Get python context function."""
        return self._py_ctx_func

    @py_ctx_func.setter
    def py_ctx_func(self, py_ctx_func: type[ast3.expr_context]) -> None:
        """Set python context function."""
        self._py_ctx_func = py_ctx_func

    @property
    def sem_token(self) -> tuple[SemTokType, SemTokMod] | None:
        """Resolve semantic token."""
        if isinstance(self.name_of, BuiltinType):
            return SemTokType.CLASS, SemTokMod.DECLARATION
        name_of = (
            self.sym.decl.name_of
            if self.sym and not isinstance(self.sym.decl.name_of, Name)
            else self.name_of
        )
        if isinstance(name_of, ModulePath):
            return SemTokType.NAMESPACE, SemTokMod.DEFINITION
        if isinstance(name_of, Archetype):
            return SemTokType.CLASS, SemTokMod.DECLARATION
        if isinstance(name_of, Enum):
            return SemTokType.ENUM, SemTokMod.DECLARATION
        if isinstance(name_of, Ability) and name_of.is_method:
            return SemTokType.METHOD, SemTokMod.DECLARATION
        if isinstance(name_of, (Ability, Test)):
            return SemTokType.FUNCTION, SemTokMod.DECLARATION
        if isinstance(name_of, ParamVar):
            return SemTokType.PARAMETER, SemTokMod.DECLARATION
        if self.sym and self.sym_name.isupper():
            return SemTokType.VARIABLE, SemTokMod.READONLY
        if (
            self.sym
            and self.sym.decl.name_of == self.sym.decl
            and self.sym_name in dir(builtins)
            and callable(getattr(builtins, self.sym_name))
        ):
            return SemTokType.FUNCTION, SemTokMod.DEFINITION
        if self.sym:
            return SemTokType.PROPERTY, SemTokMod.DEFINITION
        return None


class ArchSpec(ElementStmt, CodeBlockStmt, AstSymbolNode, AstAsyncNode, AstDocNode):
    """ArchSpec node type for Jac Ast."""

    def __init__(
        self, decorators: Sequence[Expr] | None, is_async: bool = False
    ) -> None:
        self.decorators = decorators
        CodeBlockStmt.__init__(self)
        AstAsyncNode.__init__(self, is_async=is_async)


class MatchPattern(UniNode):
    """MatchPattern node type for Jac Ast."""


class SubTag(UniNode, Generic[T]):
    """SubTag node type for Jac Ast."""

    def __init__(
        self,
        tag: T,
        kid: Sequence[UniNode],
    ) -> None:
        self.tag: T = tag
        UniNode.__init__(self, kid=kid)


# AST Mid Level Node Types
# --------------------------
class Module(AstDocNode, UniScopeNode):
    """Whole Program node type for Jac Ast."""

    def __init__(
        self,
        name: str,
        source: Source,
        doc: String | None,
        body: Sequence[ElementStmt | String | EmptyToken],
        terminals: list[Token],
        kid: Sequence[UniNode],
        stub_only: bool = False,
    ) -> None:
        self.name = name
        self.source = source
        self.body = body
        self.stub_only = stub_only
        self.impl_mod: list[Module] = []
        self.test_mod: list[Module] = []
        self.src_terminals: list[Token] = terminals
        self.is_raised_from_py: bool = False

        # We continue to parse a module even if there are syntax errors
        # so that we can report more errors in a single pass and support
        # features like code completion, lsp, format etc. This flag
        # indicates if there were syntax errors during parsing.
        self.has_syntax_errors: bool = False

        UniNode.__init__(self, kid=kid)
        AstDocNode.__init__(self, doc=doc)
        UniScopeNode.__init__(self, name=self.name)

    @property
    def annexable_by(self) -> str | None:
        """Get the base module path that this annex file belongs to.

        Uses discover_base_file to find the base .jac file for annex files
        (.impl.jac, .test.jac). Handles all discovery scenarios:
        - Same directory: foo.impl.jac -> foo.jac
        - Module-specific folder: foo.impl/bar.impl.jac -> foo.jac
        - Shared folder: impl/foo.impl.jac -> foo.jac
        """
        if self.stub_only:
            return None
        return discover_base_file(self.loc.mod_path)

    def format(self) -> str:
        """Get all sub nodes of type."""
        from jaclang.compiler.passes.tool.doc_ir_gen_pass import DocIRGenPass
        from jaclang.compiler.passes.tool.jac_formatter_pass import JacFormatPass
        from jaclang.pycore.program import JacProgram

        return JacFormatPass(
            ir_in=DocIRGenPass(
                ir_in=self,
                prog=JacProgram(),
            ).ir_out,
            prog=JacProgram(),
        ).ir_out.gen.jac

    def unparse(self, requires_format: bool = True) -> str:
        from jaclang.compiler.passes.tool.normalize_pass import NormalizePass
        from jaclang.pycore.program import JacProgram

        NormalizePass(ir_in=self, prog=JacProgram())
        if requires_format:
            return self.format()
        from jaclang.compiler.passes.tool.unparse_pass import UnparsePass

        UnparsePass(ir_in=self, prog=JacProgram())
        return self.gen.jac

    @staticmethod
    def make_stub(
        inject_name: str | None = None, inject_src: Source | None = None
    ) -> Module:
        """Create a stub module."""
        return Module(
            name=inject_name or "",
            source=inject_src or Source("", ""),
            doc=None,
            body=[],
            terminals=[],
            stub_only=True,
            kid=[EmptyToken()],
        )

    @staticmethod
    def get_href_path(node: UniNode) -> str:
        """Return the full path of the module that contains this node."""
        parent = node.find_parent_of_type(Module)
        mod_list: list[Module | Archetype] = []
        if isinstance(node, (Module, Archetype)):
            mod_list.append(node)
        while parent is not None:
            mod_list.append(parent)
            parent = parent.find_parent_of_type(Module)
        mod_list.reverse()
        return ".".join(
            p.name if isinstance(p, Module) else p.name.sym_name for p in mod_list
        )


class ProgramModule(UniNode):
    """Whole Program node type for Jac Ast."""

    def __init__(self, main_mod: Module | None = None) -> None:
        """Initialize whole program node."""
        self.main = main_mod if main_mod else Module.make_stub()
        UniNode.__init__(self, kid=[self.main])
        self.hub: dict[str, Module] = {self.loc.mod_path: main_mod} if main_mod else {}


class GlobalVars(ContextAwareNode, ElementStmt, AstAccessNode):
    """GlobalVars node type for Jac Ast."""

    def __init__(
        self,
        access: SubTag[Token] | None,
        assignments: Sequence[Assignment],
        is_frozen: bool,
        kid: Sequence[UniNode],
        doc: String | None = None,
    ) -> None:
        self.assignments = assignments
        self.is_frozen = is_frozen
        UniNode.__init__(self, kid=kid)
        AstAccessNode.__init__(self, access=access)
        AstDocNode.__init__(self, doc=doc)
        ContextAwareNode.__init__(self)


class Test(ContextAwareNode, AstSymbolNode, ElementStmt, UniScopeNode):
    """Test node type for Jac Ast."""

    TEST_COUNT = 0

    def __init__(
        self,
        name: Name | Token,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
        doc: String | None = None,
    ) -> None:
        Test.TEST_COUNT += 1 if isinstance(name, Token) else 0
        self.name: Name = (  # for auto generated test names
            name
            if isinstance(name, Name)
            else Name(
                orig_src=name.orig_src,
                name=Tok.NAME.value,
                value=f"_jac_gen_{Test.TEST_COUNT}",
                col_start=name.loc.col_start,
                col_end=name.loc.col_end,
                line=name.loc.first_line,
                end_line=name.loc.last_line,
                pos_start=name.pos_start,
                pos_end=name.pos_end,
            )
        )
        self.name.parent = self
        self.name._sym_name = (
            f"test_{self.name.value}"
            if not self.name.value.startswith("test_")
            else self.name.value
        )
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        if self.name not in self.kid:
            self.insert_kids_at_pos([self.name], pos=1, pos_update=False)
        AstSymbolNode.__init__(
            self,
            sym_name=self.name.sym_name,
            name_spec=self.name,
            sym_category=SymbolType.TEST,
        )
        AstDocNode.__init__(self, doc=doc)
        UniScopeNode.__init__(self, name=self.sym_name)
        ContextAwareNode.__init__(self)


class ModuleCode(ContextAwareNode, ElementStmt, ArchBlockStmt, EnumBlockStmt):
    """ModuleCode node type for Jac Ast."""

    def __init__(
        self,
        name: Name | None,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
        is_enum_stmt: bool = False,
        doc: String | None = None,
    ) -> None:
        self.name = name
        self.body = body
        UniNode.__init__(self, kid=kid)
        AstDocNode.__init__(self, doc=doc)
        EnumBlockStmt.__init__(self, is_enum_stmt=is_enum_stmt)
        ContextAwareNode.__init__(self)


class ClientBlock(ElementStmt):
    """ClientBlock node type for cl { ... } blocks in Jac Ast."""

    def __init__(
        self,
        body: Sequence[ElementStmt],
        kid: Sequence[UniNode],
        implicit: bool = False,
    ) -> None:
        self.body = list(body)
        self.implicit = implicit
        UniNode.__init__(self, kid=kid)


class ServerBlock(ElementStmt):
    """ServerBlock node type for sv { ... } blocks in Jac Ast."""

    def __init__(
        self,
        body: Sequence[ElementStmt],
        kid: Sequence[UniNode],
        implicit: bool = False,
    ) -> None:
        self.body = list(body)
        self.implicit = implicit
        UniNode.__init__(self, kid=kid)


class NativeBlock(ElementStmt):
    """NativeBlock node type for na { ... } blocks in Jac Ast."""

    def __init__(
        self,
        body: Sequence[ElementStmt],
        kid: Sequence[UniNode],
        implicit: bool = False,
    ) -> None:
        self.body = list(body)
        self.implicit = implicit
        UniNode.__init__(self, kid=kid)


class PyInlineCode(ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt):
    """PyInlineCode node type for Jac Ast."""

    def __init__(
        self,
        code: Token,
        kid: Sequence[UniNode],
        is_enum_stmt: bool = False,
        doc: String | None = None,
    ) -> None:
        self.code = code
        UniNode.__init__(self, kid=kid)
        AstDocNode.__init__(self, doc=doc)
        CodeBlockStmt.__init__(self)
        EnumBlockStmt.__init__(self, is_enum_stmt=is_enum_stmt)


class Import(ContextAwareNode, ElementStmt, CodeBlockStmt):
    """Import node type for Jac Ast."""

    def __init__(
        self,
        from_loc: ModulePath | None,
        items: Sequence[ModuleItem] | Sequence[ModulePath],
        is_absorb: bool,  # For includes
        kid: Sequence[UniNode],
        doc: String | None = None,
    ) -> None:
        self.hint = None
        self.from_loc = from_loc
        self.items = items
        self.is_absorb = is_absorb
        UniNode.__init__(self, kid=kid)
        AstDocNode.__init__(self, doc=doc)
        CodeBlockStmt.__init__(self)
        ContextAwareNode.__init__(self)

    @property
    def is_py(self) -> bool:
        """Check if import is python."""
        if self.hint and self.hint.tag.value == "py":
            return True
        if not self.hint:
            return not self.__jac_detected
        return False

    @property
    def is_jac(self) -> bool:
        """Check if import is jac."""
        if self.hint and self.hint.tag.value == "jac":
            return True
        if not self.hint:
            return self.__jac_detected
        return False

    @property
    def __jac_detected(self) -> bool:
        """Check if import is jac."""
        if self.from_loc:
            if self.from_loc.resolve_relative_path().endswith((".jac", ".cl.jac")):
                return True
            if os.path.isdir(self.from_loc.resolve_relative_path()):
                if os.path.exists(
                    os.path.join(self.from_loc.resolve_relative_path(), "__init__.jac")
                ):
                    return True
                if os.path.exists(
                    os.path.join(
                        self.from_loc.resolve_relative_path(), "__init__.cl.jac"
                    )
                ):
                    return True
                for i in self.items:
                    if isinstance(
                        i, ModuleItem
                    ) and self.from_loc.resolve_relative_path(i.name.value).endswith(
                        (".jac", ".cl.jac")
                    ):
                        return True
        return any(
            isinstance(i, ModulePath)
            and i.resolve_relative_path().endswith((".jac", ".cl.jac"))
            for i in self.items
        )


class ModulePath(UniNode):
    """ModulePath node type for Jac Ast."""

    def __init__(
        self,
        path: Sequence[Name | String] | None,
        level: int,
        alias: Name | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.path = path
        self.level = level
        self.alias = alias
        self.abs_path: str | None = None
        UniNode.__init__(self, kid=kid)

    @property
    def is_import_from(self) -> bool:
        """Check if this modulepath is from import."""
        if self.parent and isinstance(self.parent, Import):
            return self.parent.from_loc == self
        return False

    @property
    def dot_path_str(self) -> str:
        """Get path string."""
        if self.path and len(self.path) == 1 and isinstance(self.path[0], String):
            # Handle string literal import path
            return ("." * self.level) + self.path[0].lit_value
        return ("." * self.level) + ".".join(
            [p.value for p in self.path] if self.path else []
        )

    def resolve_relative_path(self, target_item: str | None = None) -> str:
        """Convert an import target string into a relative file path."""
        target = self.dot_path_str + (f".{target_item}" if target_item else "")

        # Handle '@jac/' prefixed imports (built-in runtime modules)
        if target.startswith("@jac/"):
            import jaclang.runtimelib

            runtime_dir = os.path.dirname(jaclang.runtimelib.__file__)
            module_name = target[5:]  # Strip "@jac/"

            # Map module names to files
            module_map = {
                "runtime": "client_runtime.cl.jac",
            }

            if module_name in module_map:
                return os.path.join(runtime_dir, module_map[module_name])

            # Fallback: try direct file resolution
            for ext in [".cl.jac", ".jac", ".js"]:
                path = os.path.join(runtime_dir, module_name + ext)
                if os.path.exists(path):
                    return path

            return os.path.join(runtime_dir, module_name + ".jac")

        return resolve_relative_path(target, self.loc.mod_path)

    def resolve_relative_path_list(self) -> list[str]:
        """Convert an import target string into a relative file path."""
        parts = self.dot_path_str.split(".")
        paths = []
        for i in range(len(parts)):
            sub_path = ".".join(parts[: i + 1])
            paths.append(resolve_relative_path(sub_path, self.loc.mod_path))
        return paths


class ModuleItem(UniNode):
    """ModuleItem node type for Jac Ast.

    Name can be either:
    - Name: for regular named imports (e.g., useState, axios)
    - Token (KW_DEFAULT): for default imports (Category 2)
    - Token (STAR_MUL): for namespace imports (Category 4)
    """

    def __init__(
        self,
        name: Name | Token,
        alias: Name | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.alias = alias
        UniNode.__init__(self, kid=kid)
        self.abs_path: str | None = None

    @property
    def from_parent(self) -> Import:
        """Get import parent."""
        if not self.parent or not isinstance(self.parent, Import):
            raise ValueError("Import parent not found. Not Possible.")
        return self.parent

    @property
    def from_mod_path(self) -> ModulePath:
        """Get relevant module path."""
        if not self.from_parent.from_loc:
            raise ValueError("Module items should have module path. Not Possible.")
        return self.from_parent.from_loc


class Archetype(
    ContextAwareNode,
    ArchSpec,
    AstAccessNode,
    ArchBlockStmt,
    AstImplNeedingNode,
    UniScopeNode,
    UniCFGNode,
):
    """ObjectArch node type for Jac Ast."""

    def __init__(
        self,
        name: Name,
        arch_type: Token,
        access: SubTag[Token] | None,
        base_classes: Sequence[Expr] | None,
        body: Sequence[ArchBlockStmt] | ImplDef | None,
        kid: Sequence[UniNode],
        doc: String | None = None,
        decorators: Sequence[Expr] | None = None,
    ) -> None:
        self.name = name
        self.arch_type = arch_type
        self.base_classes: list[Expr] = list(base_classes) if base_classes else []
        UniNode.__init__(self, kid=kid)
        AstSymbolNode.__init__(
            self,
            sym_name=name.value,
            name_spec=name,
            sym_category={
                Tok.KW_OBJECT.value: SymbolType.OBJECT_ARCH,
                Tok.KW_NODE.value: SymbolType.NODE_ARCH,
                Tok.KW_EDGE.value: SymbolType.EDGE_ARCH,
                Tok.KW_WALKER.value: SymbolType.WALKER_ARCH,
            }.get(arch_type.name, SymbolType.TYPE),
        )
        AstImplNeedingNode.__init__(self, body=body)
        AstAccessNode.__init__(self, access=access)
        AstDocNode.__init__(self, doc=doc)
        ArchSpec.__init__(self, decorators=decorators)
        UniScopeNode.__init__(self, name=self.sym_name)
        CodeBlockStmt.__init__(self)
        ContextAwareNode.__init__(self)

    def _get_impl_resolved_body(self) -> list:
        return (
            list(self.body)
            if isinstance(self.body, Sequence)
            else (
                list(self.body.body)
                if isinstance(self.body, ImplDef)
                and isinstance(self.body.body, Sequence)
                else []
            )
        )

    @property
    def is_abstract(self) -> bool:
        body = self._get_impl_resolved_body()
        return any(isinstance(i, Ability) and i.is_abstract for i in body)

    def get_has_vars(self) -> list[HasVar]:
        body = self._get_impl_resolved_body()
        has_vars: list[HasVar] = []
        for node in body:
            if not isinstance(node, ArchHas):
                continue
            for has_ in node.vars:
                if isinstance(has_, HasVar):
                    has_vars.append(has_)
        return has_vars

    def get_methods(self) -> list[Ability]:
        body = self._get_impl_resolved_body()
        methods: list[Ability] = []
        for node in body:
            if isinstance(node, Ability) and node.is_method:
                methods.append(node)
        return methods


class ImplDef(
    ContextAwareNode,
    CodeBlockStmt,
    ElementStmt,
    ArchBlockStmt,
    AstSymbolNode,
    UniScopeNode,
):
    """AstImplOnlyNode node type for Jac Ast."""

    def __init__(
        self,
        decorators: Sequence[Expr] | None,
        target: Sequence[NameAtom],
        spec: Sequence[Expr] | FuncSignature | EventSignature | None,
        body: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr,
        kid: Sequence[UniNode],
        doc: String | None = None,
        decl_link: UniNode | None = None,
    ) -> None:
        self.decorators = decorators
        self.target = target
        self.spec = list(spec) if isinstance(spec, Sequence) else spec
        self.body = body
        self.doc = doc
        self.decl_link = decl_link
        UniNode.__init__(self, kid=kid)
        AstSymbolNode.__init__(
            self,
            sym_name="impl." + ".".join([x.sym_name for x in self.target]),
            name_spec=self.create_impl_name_node(),
            sym_category=SymbolType.IMPL,
        )
        CodeBlockStmt.__init__(self)
        UniScopeNode.__init__(self, name=self.sym_name)
        ContextAwareNode.__init__(self)

    def create_impl_name_node(self) -> Name:
        ret = Name(
            orig_src=self.target[-1].loc.orig_src,
            name=Tok.NAME.value,
            value="impl." + ".".join([x.sym_name for x in self.target]),
            col_start=self.target[0].loc.col_start,
            col_end=self.target[-1].loc.col_end,
            line=self.target[0].loc.first_line,
            end_line=self.target[-1].loc.last_line,
            pos_start=self.target[0].loc.pos_start,
            pos_end=self.target[-1].loc.pos_end,
        )
        ret.parent = self
        return ret


class SemDef(ElementStmt, AstSymbolNode, UniScopeNode):
    """SemDef node type for Jac Ast."""

    def __init__(
        self,
        target: Sequence[NameAtom],
        value: String,
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        self.value = value
        UniNode.__init__(self, kid=kid)
        AstSymbolNode.__init__(
            self,
            sym_name="sem." + ".".join([x.sym_name for x in self.target]),
            name_spec=self.create_sem_name_node(),
            sym_category=SymbolType.SEM,
        )
        UniScopeNode.__init__(self, name=self.sym_name)

    def create_sem_name_node(self) -> Name:
        ret = Name(
            orig_src=self.target[-1].loc.orig_src,
            name=Tok.NAME.value,
            value="sem." + ".".join([x.sym_name for x in self.target]),
            col_start=self.target[0].loc.col_start,
            col_end=self.target[-1].loc.col_end,
            line=self.target[0].loc.first_line,
            end_line=self.target[-1].loc.last_line,
            pos_start=self.target[0].loc.pos_start,
            pos_end=self.target[-1].loc.pos_end,
        )
        ret.parent = self
        return ret


class Enum(
    ContextAwareNode,
    ArchSpec,
    AstAccessNode,
    AstImplNeedingNode,
    ArchBlockStmt,
    UniScopeNode,
):
    """Enum node type for Jac Ast."""

    def __init__(
        self,
        name: Name,
        access: SubTag[Token] | None,
        base_classes: Sequence[Expr] | None,
        body: Sequence[EnumBlockStmt] | ImplDef | None,
        kid: Sequence[UniNode],
        doc: String | None = None,
        decorators: Sequence[Expr] | None = None,
    ) -> None:
        self.name = name
        self.base_classes: list[Expr] = list(base_classes) if base_classes else []
        UniNode.__init__(self, kid=kid)
        AstSymbolNode.__init__(
            self,
            sym_name=name.value,
            name_spec=name,
            sym_category=SymbolType.ENUM_ARCH,
        )
        AstImplNeedingNode.__init__(self, body=body)
        AstAccessNode.__init__(self, access=access)
        AstDocNode.__init__(self, doc=doc)
        ArchSpec.__init__(self, decorators=decorators)
        UniScopeNode.__init__(self, name=self.sym_name)
        ContextAwareNode.__init__(self)


class Ability(
    ContextAwareNode,
    AstAccessNode,
    ElementStmt,
    AstAsyncNode,
    ArchBlockStmt,
    CodeBlockStmt,
    AstImplNeedingNode,
    UniScopeNode,
):
    """Ability node type for Jac Ast."""

    def __init__(
        self,
        name_ref: NameAtom | None,
        is_async: bool,
        is_override: bool,
        is_static: bool,
        is_abstract: bool,
        access: SubTag[Token] | None,
        signature: FuncSignature | EventSignature | None,
        body: Sequence[CodeBlockStmt] | ImplDef | Expr | None,
        kid: Sequence[UniNode],
        doc: String | None = None,
        decorators: Sequence[Expr] | None = None,
    ) -> None:
        self.is_override = is_override
        self.is_static = is_static
        self.is_abstract = is_abstract
        self.decorators = decorators
        self.signature = signature

        UniNode.__init__(self, kid=kid)
        AstImplNeedingNode.__init__(self, body=body)

        # Create a synthetic name_ref if none provided
        if name_ref is None:
            # Extract location info from kid for positioning
            # Note: kid should always contain at least KW_CAN token from parser
            first_tok = kid[0] if kid and isinstance(kid[0], Token) else None
            if first_tok is None:
                raise ValueError(
                    "Cannot create synthetic name_ref without location info."
                )
            # Generate anonymous name based on event type and location
            event_type = (
                "entry"
                if isinstance(signature, EventSignature)
                and signature.event.name == Tok.KW_ENTRY
                else "exit"
            )
            synthetic_name = (
                f"__ability_{event_type}_{first_tok.line_no}_{first_tok.c_start}__"
            )
            synthetic_name_ref: NameAtom = Name(
                orig_src=first_tok.orig_src,
                name=Tok.NAME,
                value=synthetic_name,
                line=first_tok.line_no,
                end_line=first_tok.end_line,
                col_start=first_tok.c_start,
                col_end=first_tok.c_end,
                pos_start=first_tok.pos_start,
                pos_end=first_tok.pos_end,
                is_enum_stmt=False,
            )
            name_spec_for_init: Name | NameAtom = synthetic_name_ref
            self.name_ref = synthetic_name_ref
        else:
            name_spec_for_init = name_ref
            self.name_ref = name_ref

        AstSymbolNode.__init__(
            self,
            sym_name=self.py_resolve_name(),
            name_spec=name_spec_for_init,
            sym_category=SymbolType.ABILITY,
        )
        AstAccessNode.__init__(self, access=access)
        AstDocNode.__init__(self, doc=doc)
        AstAsyncNode.__init__(self, is_async=is_async)
        UniScopeNode.__init__(self, name=self.sym_name)
        CodeBlockStmt.__init__(self)
        ContextAwareNode.__init__(self)

    @property
    def is_method(self) -> bool:
        return self.method_owner is not None

    @property
    def is_cls_method(self) -> bool:
        """Check if this ability is a class method."""
        return self.is_method and any(
            isinstance(dec, Name) and dec.sym_name == "classmethod"
            for dec in self.decorators or ()
        )

    @property
    def is_def(self) -> bool:
        return not self.signature or isinstance(self.signature, FuncSignature)

    @property
    def method_owner(self) -> Archetype | Enum | None:
        found = (
            self.parent
            if self.parent and isinstance(self.parent, (Archetype, Enum))
            else None
        ) or (
            self.parent.decl_link
            if self.parent
            and isinstance(self.parent, ImplDef)
            and isinstance(self.parent.decl_link, (Archetype, Enum))
            else None
        )
        return found

    @property
    def is_genai_ability(self) -> bool:
        return isinstance(self.body, Expr)

    def get_pos_argc_range(self) -> tuple[int, int]:
        """Get the range of positional arguments for this ability.

        Returns -1 for maximum number of arguments if there is an unpacked parameter (e.g., *args).
        """
        mn, mx = 0, 0
        if isinstance(self.signature, FuncSignature):
            for param in self.signature.params:
                if param.unpack:
                    if param.unpack == Tok.STAR_MUL:
                        mx = -1
                    break
                mn += 1
                mx += 1
        return mn, mx

    def py_resolve_name(self) -> str:
        if self.name_ref is None:
            # Generate anonymous name based on event type and location
            event_type = (
                "entry"
                if isinstance(self.signature, EventSignature)
                and self.signature.event.name == Tok.KW_ENTRY
                else "exit"
            )
            return (
                f"__ability_{event_type}_{self.loc.first_line}_{self.loc.col_start}__"
            )
        elif isinstance(self.name_ref, Name):
            return self.name_ref.value
        elif isinstance(self.name_ref, SpecialVarRef):
            return self.name_ref.py_resolve_name()
        else:
            raise NotImplementedError


class FuncSignature(UniNode):
    """FuncSignature node type for Jac Ast."""

    def __init__(
        self,
        posonly_params: Sequence[ParamVar],
        params: Sequence[ParamVar] | None,
        varargs: ParamVar | None,
        kwonlyargs: Sequence[ParamVar],
        kwargs: ParamVar | None,
        return_type: Expr | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.posonly_params: list[ParamVar] = list(posonly_params)
        self.params: list[ParamVar] = list(params) if params else []
        self.varargs = varargs
        self.kwonlyargs: list[ParamVar] = list(kwonlyargs)
        self.kwargs = kwargs
        self.return_type = return_type
        UniNode.__init__(self, kid=kid)

    def get_parameters(self) -> list[ParamVar]:
        """Return all parameters in the declared order."""
        params = self.posonly_params + self.params
        if self.varargs:
            params.append(self.varargs)
        params += self.kwonlyargs
        if self.kwargs:
            params.append(self.kwargs)
        return params

    @property
    def is_static(self) -> bool:
        return (isinstance(self.parent, Ability) and self.parent.is_static) or (
            isinstance(self.parent, ImplDef)
            and isinstance(self.parent.decl_link, Ability)
            and self.parent.decl_link.is_static
        )

    @property
    def is_in_py_class(self) -> bool:
        is_archi = self.find_parent_of_type(Archetype)
        is_class = is_archi is not None and is_archi.arch_type.name == Tok.KW_CLASS

        return (
            isinstance(self.parent, Ability)
            and self.parent.is_method is not None
            and is_class
        ) or (
            isinstance(self.parent, ImplDef)
            and isinstance(self.parent.decl_link, Ability)
            and self.parent.decl_link.is_method
            and is_class
        )


class EventSignature(WalkerStmtOnlyNode):
    """EventSignature node type for Jac Ast."""

    def __init__(
        self,
        event: Token,
        arch_tag_info: Expr | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.event = event
        self.arch_tag_info = arch_tag_info
        UniNode.__init__(self, kid=kid)
        WalkerStmtOnlyNode.__init__(self)


class ParamKind(IntEnum):
    """Parameter kinds."""

    POSONLY = 0
    NORMAL = 1
    VARARG = 2
    KWONLY = 3
    KWARG = 4


class ParamVar(AstSymbolNode, AstTypedVarNode):
    """ParamVar node type for Jac Ast."""

    def __init__(
        self,
        name: Name,
        unpack: Token | None,
        type_tag: SubTag[Expr],
        value: Expr | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.unpack = unpack
        self.param_kind = ParamKind.NORMAL
        self.value = value
        UniNode.__init__(self, kid=kid)
        AstSymbolNode.__init__(
            self,
            sym_name=name.value,
            name_spec=name,
            sym_category=SymbolType.VAR,
        )
        AstTypedVarNode.__init__(self, type_tag=type_tag)

    @property
    def is_vararg(self) -> bool:
        return bool((self.unpack) and (self.unpack.name == Tok.STAR_MUL.name))

    @property
    def is_kwargs(self) -> bool:
        return bool((self.unpack) and (self.unpack.name == Tok.STAR_POW.name))


# TODO: Must deal with codeblockstmt here, should only be in ArchBocks
# but had to do this for impls to work, probably should do checks in the
# static analysis phase
class ArchHas(AstAccessNode, AstDocNode, ArchBlockStmt, CodeBlockStmt):
    """ArchHas node type for Jac Ast."""

    def __init__(
        self,
        is_static: bool,
        access: SubTag[Token] | None,
        vars: Sequence[HasVar],
        is_frozen: bool,
        kid: Sequence[UniNode],
        doc: String | None = None,
    ) -> None:
        self.is_static = is_static
        self.vars: list[HasVar] = list(vars)
        self.is_frozen = is_frozen
        UniNode.__init__(self, kid=kid)
        AstAccessNode.__init__(self, access=access)
        AstDocNode.__init__(self, doc=doc)
        CodeBlockStmt.__init__(self)


class HasVar(AstSymbolNode, AstTypedVarNode):
    """HasVar node type for Jac Ast."""

    def __init__(
        self,
        name: Name,
        type_tag: SubTag[Expr],
        value: Expr | None,
        defer: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.value = value
        self.defer = defer
        UniNode.__init__(self, kid=kid)
        AstSymbolNode.__init__(
            self,
            sym_name=name.value,
            name_spec=name,
            sym_category=SymbolType.HAS_VAR,
        )
        AstTypedVarNode.__init__(self, type_tag=type_tag)


class TypedCtxBlock(CodeBlockStmt, WalkerStmtOnlyNode, UniScopeNode):
    """TypedCtxBlock node type for Jac Ast."""

    def __init__(
        self,
        type_ctx: Expr,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.type_ctx = type_ctx
        self.body = body
        UniNode.__init__(self, kid=kid)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)
        WalkerStmtOnlyNode.__init__(self)


class IfStmt(CodeBlockStmt, AstElseBodyNode, UniScopeNode):
    """IfStmt node type for Jac Ast."""

    def __init__(
        self,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: ElseStmt | ElseIf | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.condition = condition
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        AstElseBodyNode.__init__(self, else_body=else_body)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)


class ElseIf(IfStmt):
    """ElseIf node type for Jac Ast."""


class ElseStmt(UniScopeNode):
    """ElseStmt node type for Jac Ast."""

    def __init__(
        self,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")


class ExprStmt(CodeBlockStmt):
    """ExprStmt node type for Jac Ast."""

    def __init__(
        self,
        expr: Expr,
        in_fstring: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.expr = expr
        self.in_fstring = in_fstring
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)


class TryStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode):
    """TryStmt node type for Jac Ast."""

    def __init__(
        self,
        body: Sequence[CodeBlockStmt],
        excepts: Sequence[Except],
        else_body: ElseStmt | None,
        finally_body: FinallyStmt | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.body: list[CodeBlockStmt] = list(body)
        self.excepts: list[Except] = list(excepts)
        self.finally_body = finally_body
        UniNode.__init__(self, kid=kid)
        AstElseBodyNode.__init__(self, else_body=else_body)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)


class Except(CodeBlockStmt, UniScopeNode):
    """Except node type for Jac Ast."""

    def __init__(
        self,
        ex_type: Expr,
        name: Name | None,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.ex_type = ex_type
        self.name = name
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)


class FinallyStmt(CodeBlockStmt, UniScopeNode):
    """FinallyStmt node type for Jac Ast."""

    def __init__(
        self,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)


class IterForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode):
    """IterForStmt node type for Jac Ast."""

    def __init__(
        self,
        iter: Assignment,
        is_async: bool,
        condition: Expr,
        count_by: Assignment,
        body: Sequence[CodeBlockStmt],
        else_body: ElseStmt | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.iter = iter
        self.condition = condition
        self.count_by = count_by
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        AstAsyncNode.__init__(self, is_async=is_async)
        AstElseBodyNode.__init__(self, else_body=else_body)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)


class InForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode):
    """InForStmt node type for Jac Ast."""

    def __init__(
        self,
        target: Expr,
        is_async: bool,
        collection: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: ElseStmt | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        self.collection = collection
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        AstAsyncNode.__init__(self, is_async=is_async)
        AstElseBodyNode.__init__(self, else_body=else_body)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)


class WhileStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode):
    """WhileStmt node type for Jac Ast."""

    def __init__(
        self,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: ElseStmt | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.condition = condition
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        AstElseBodyNode.__init__(self, else_body=else_body)
        CodeBlockStmt.__init__(self)


class WithStmt(AstAsyncNode, CodeBlockStmt, UniScopeNode):
    """WithStmt node type for Jac Ast."""

    def __init__(
        self,
        is_async: bool,
        exprs: Sequence[ExprAsItem],
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.exprs = exprs
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        AstAsyncNode.__init__(self, is_async=is_async)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)


class ExprAsItem(UniNode):
    """ExprAsItem node type for Jac Ast."""

    def __init__(
        self,
        expr: Expr,
        alias: Expr | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.expr = expr
        self.alias = alias
        UniNode.__init__(self, kid=kid)


class RaiseStmt(CodeBlockStmt):
    """RaiseStmt node type for Jac Ast."""

    def __init__(
        self,
        cause: Expr | None,
        from_target: Expr | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.cause = cause
        self.from_target = from_target
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)


class AssertStmt(CodeBlockStmt):
    """AssertStmt node type for Jac Ast."""

    def __init__(
        self,
        condition: Expr,
        error_msg: Expr | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.condition = condition
        self.error_msg = error_msg
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)


class CtrlStmt(CodeBlockStmt):
    """CtrlStmt node type for Jac Ast."""

    def __init__(
        self,
        ctrl: Token,
        kid: Sequence[UniNode],
    ) -> None:
        self.ctrl = ctrl
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)


class DeleteStmt(CodeBlockStmt):
    """DeleteStmt node type for Jac Ast."""

    def __init__(
        self,
        target: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)

    @property
    def py_ast_targets(self) -> list[ast3.AST]:
        """Get Python AST targets (without setting ctx)."""
        return (
            [i.gen.py_ast[0] for i in self.target.values]
            if isinstance(self.target, TupleVal) and self.target.values
            else self.target.gen.py_ast
        )


class ReportStmt(CodeBlockStmt):
    """ReportStmt node type for Jac Ast."""

    def __init__(
        self,
        expr: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.expr = expr
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)


class ReturnStmt(CodeBlockStmt):
    """ReturnStmt node type for Jac Ast."""

    def __init__(
        self,
        expr: Expr | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.expr = expr
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)


class VisitStmt(WalkerStmtOnlyNode, AstElseBodyNode, CodeBlockStmt):
    """VisitStmt node type for Jac Ast."""

    def __init__(
        self,
        insert_loc: Expr | None,
        target: Expr,
        else_body: ElseStmt | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.insert_loc = insert_loc
        self.target = target
        UniNode.__init__(self, kid=kid)
        WalkerStmtOnlyNode.__init__(self)
        AstElseBodyNode.__init__(self, else_body=else_body)
        CodeBlockStmt.__init__(self)


class DisengageStmt(WalkerStmtOnlyNode, CodeBlockStmt):
    """DisengageStmt node type for Jac Ast."""

    def __init__(
        self,
        kid: Sequence[UniNode],
    ) -> None:
        """Initialize disengage statement node."""
        UniNode.__init__(self, kid=kid)
        WalkerStmtOnlyNode.__init__(self)
        CodeBlockStmt.__init__(self)


class AwaitExpr(Expr):
    """AwaitExpr node type for Jac Ast."""

    def __init__(
        self,
        target: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class GlobalStmt(CodeBlockStmt):
    """GlobalStmt node type for Jac Ast."""

    def __init__(
        self,
        target: Sequence[NameAtom],
        kid: Sequence[UniNode],
    ) -> None:
        self.target: list[NameAtom] = list(target)
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)


class NonLocalStmt(GlobalStmt):
    """NonLocalStmt node type for Jac Ast."""


class Assignment(AstTypedVarNode, EnumBlockStmt, CodeBlockStmt):
    """Assignment node type for Jac Ast."""

    def __init__(
        self,
        target: Sequence[Expr],
        value: Expr | YieldExpr | None,
        type_tag: SubTag[Expr] | None,
        kid: Sequence[UniNode],
        mutable: bool = True,
        aug_op: Token | None = None,
        is_enum_stmt: bool = False,
    ) -> None:
        self.target: list[Expr] = list(target)
        self.value = value
        self.mutable = mutable
        self.aug_op = aug_op
        UniNode.__init__(self, kid=kid)
        AstTypedVarNode.__init__(self, type_tag=type_tag)
        CodeBlockStmt.__init__(self)
        EnumBlockStmt.__init__(self, is_enum_stmt=is_enum_stmt)


class ConcurrentExpr(Expr):
    """ConcurrentExpr node type for Jac Ast."""

    def __init__(
        self,
        tok: Token | None,
        target: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        self.tok = tok
        self.target = target


class BinaryExpr(Expr):
    """BinaryExpr node type for Jac Ast."""

    def __init__(
        self,
        left: Expr,
        right: Expr,
        op: Token | DisconnectOp | ConnectOp,
        kid: Sequence[UniNode],
    ) -> None:
        self.left = left
        self.right = right
        self.op = op
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class CompareExpr(Expr):
    """CompareExpr node type for Jac Ast."""

    def __init__(
        self,
        left: Expr,
        rights: list[Expr],
        ops: list[Token],
        kid: Sequence[UniNode],
    ) -> None:
        self.left = left
        self.rights = rights
        self.ops = ops
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class BoolExpr(Expr):
    """BoolExpr node type for Jac Ast."""

    def __init__(
        self,
        op: Token,
        values: list[Expr],
        kid: Sequence[UniNode],
    ) -> None:
        self.values = values
        self.op = op
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class LambdaExpr(Expr, UniScopeNode):
    """LambdaExpr node type for Jac Ast."""

    def __init__(
        self,
        body: Expr | Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
        signature: FuncSignature | None = None,
    ) -> None:
        self.signature = signature
        if isinstance(body, Sequence) and not isinstance(body, Expr):
            self.body: Expr | Sequence[CodeBlockStmt] = list(body)
        else:
            self.body = cast(Expr, body)
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")


class UnaryExpr(Expr):
    """UnaryExpr node type for Jac Ast."""

    def __init__(
        self,
        operand: Expr,
        op: Token,
        kid: Sequence[UniNode],
    ) -> None:
        self.operand = operand
        self.op = op
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class IfElseExpr(Expr):
    """IfElseExpr node type for Jac Ast."""

    def __init__(
        self,
        condition: Expr,
        value: Expr,
        else_value: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.condition = condition
        self.value = value
        self.else_value = else_value
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class MultiString(AtomExpr):
    """MultiString node type for Jac Ast."""

    def __init__(
        self,
        strings: Sequence[String | FString],
        kid: Sequence[UniNode],
    ) -> None:
        self.strings = strings
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.STRING)


class FString(AtomExpr):
    """FString node type for Jac Ast."""

    def __init__(
        self,
        start: Token | None,
        parts: Sequence[String | FormattedValue],
        end: Token | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.start = start
        self.parts: list[String | FormattedValue] = list(parts)
        self.end = end
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.STRING)


class FormattedValue(Expr):
    """FormattedValue node type for Jac Ast."""

    def __init__(
        self,
        format_part: Expr,
        conversion: int,
        format_spec: Expr | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.format_part: Expr = format_part
        self.conversion: int = conversion
        self.format_spec: Expr | None = format_spec
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class ListVal(AtomExpr):
    """ListVal node type for Jac Ast."""

    def __init__(
        self,
        values: Sequence[Expr],
        kid: Sequence[UniNode],
    ) -> None:
        self.values = values
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)


class SetVal(AtomExpr):
    """SetVal node type for Jac Ast."""

    def __init__(
        self,
        values: Sequence[Expr] | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.values: list[Expr] = list(values) if values else []
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)


class TupleVal(AtomExpr):
    """TupleVal node type for Jac Ast."""

    def __init__(
        self,
        values: Sequence[Expr | KWPair],
        kid: Sequence[UniNode],
    ) -> None:
        self.values = list(values)
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)


class DictVal(AtomExpr):
    """DictVal node type for Jac Ast."""

    def __init__(
        self,
        kv_pairs: Sequence[KVPair],
        kid: Sequence[UniNode],
    ) -> None:
        self.kv_pairs = kv_pairs
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)


class KVPair(UniNode):
    """KVPair node type for Jac Ast."""

    def __init__(
        self,
        key: Expr | None,  # is **key if blank
        value: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.key = key
        self.value = value
        UniNode.__init__(self, kid=kid)


class KWPair(UniNode):
    """KWPair node type for Jac Ast."""

    def __init__(
        self,
        key: NameAtom | None,  # is **value if blank
        value: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.key = key
        self.value = value
        UniNode.__init__(self, kid=kid)


class InnerCompr(AstAsyncNode, UniScopeNode):
    """InnerCompr node type for Jac Ast."""

    def __init__(
        self,
        is_async: bool,
        target: Expr,
        collection: Expr,
        conditional: list[Expr] | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        self.collection = collection
        self.conditional = conditional
        UniNode.__init__(self, kid=kid)
        AstAsyncNode.__init__(self, is_async=is_async)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")


class ListCompr(AtomExpr, UniScopeNode):
    """ListCompr node type for Jac Ast."""

    def __init__(
        self,
        out_expr: Expr,
        compr: list[InnerCompr],
        kid: Sequence[UniNode],
    ) -> None:
        self.out_expr = out_expr
        self.compr = compr
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")


class GenCompr(ListCompr):
    """GenCompr node type for Jac Ast."""


class SetCompr(ListCompr):
    """SetCompr node type for Jac Ast."""


class DictCompr(AtomExpr, UniScopeNode):
    """DictCompr node type for Jac Ast."""

    def __init__(
        self,
        kv_pair: KVPair,
        compr: list[InnerCompr],
        kid: Sequence[UniNode],
    ) -> None:
        self.kv_pair = kv_pair
        self.compr = compr
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")


class AtomTrailer(Expr):
    """AtomTrailer node type for Jac Ast."""

    def __init__(
        self,
        target: Expr,
        right: AtomExpr | Expr,
        is_attr: bool,
        is_null_ok: bool,
        kid: Sequence[UniNode],
        is_genai: bool = False,
    ) -> None:
        self.target = target
        self.right = right
        self.is_attr = is_attr
        self.is_null_ok = is_null_ok
        self.is_genai = is_genai
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)

    @property
    def as_attr_list(self) -> list[AstSymbolNode]:
        left = self.right if isinstance(self.right, AtomTrailer) else self.target
        right = self.target if isinstance(self.right, AtomTrailer) else self.right
        trag_list: list[AstSymbolNode] = (
            [right] if isinstance(right, AstSymbolNode) else []
        )
        while isinstance(left, AtomTrailer) and left.is_attr:
            if isinstance(left.right, AstSymbolNode):
                trag_list.insert(0, left.right)
            left = left.target
        if isinstance(left, AstSymbolNode):
            trag_list.insert(0, left)
        return trag_list


class AtomUnit(Expr):
    """AtomUnit node type for Jac Ast."""

    def __init__(
        self,
        value: Expr | YieldExpr | Ability,
        kid: Sequence[UniNode],
    ) -> None:
        self.value = value
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class YieldExpr(Expr):
    """YieldExpr node type for Jac Ast."""

    def __init__(
        self,
        expr: Expr | None,
        with_from: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.expr = expr
        self.with_from = with_from
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class FuncCall(Expr):
    """FuncCall node type for Jac Ast."""

    def __init__(
        self,
        target: Expr,
        params: Sequence[Expr | KWPair] | None,
        genai_call: Expr | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        self.params = list(params) if params else []
        self.genai_call = genai_call
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class IndexSlice(AtomExpr):
    """IndexSlice node type for Jac Ast."""

    @dataclass
    class Slice:
        """Slice node type for Jac Ast."""

        start: Expr | None
        stop: Expr | None
        step: Expr | None

    def __init__(
        self,
        slices: list[Slice],
        is_range: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.slices = slices
        self.is_range = is_range
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)


class EdgeRefTrailer(Expr):
    """EdgeRefTrailer node type for Jac Ast."""

    def __init__(
        self,
        chain: list[Expr | FilterCompr],
        edges_only: bool,
        is_async: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.chain = chain
        self.edges_only = edges_only
        self.is_async = is_async
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)


class EdgeOpRef(WalkerStmtOnlyNode, AtomExpr):
    """EdgeOpRef node type for Jac Ast."""

    def __init__(
        self,
        filter_cond: FilterCompr | None,
        edge_dir: EdgeDir,
        kid: Sequence[UniNode],
    ) -> None:
        self.filter_cond = filter_cond
        self.edge_dir = edge_dir
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        WalkerStmtOnlyNode.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)


class DisconnectOp(WalkerStmtOnlyNode):
    """DisconnectOp node type for Jac Ast."""

    def __init__(
        self,
        edge_spec: EdgeOpRef,
        kid: Sequence[UniNode],
    ) -> None:
        self.edge_spec = edge_spec
        UniNode.__init__(self, kid=kid)
        WalkerStmtOnlyNode.__init__(self)


class ConnectOp(UniNode):
    """ConnectOpRef node type for Jac Ast."""

    def __init__(
        self,
        conn_type: Expr | None,
        conn_assign: AssignCompr | None,
        edge_dir: EdgeDir,
        kid: Sequence[UniNode],
    ) -> None:
        self.conn_type = conn_type
        self.conn_assign = conn_assign
        self.edge_dir = edge_dir
        UniNode.__init__(self, kid=kid)


class FilterCompr(AtomExpr):
    """FilterCompr node type for Jac Ast."""

    def __init__(
        self,
        f_type: Expr | None,
        compares: Sequence[CompareExpr],
        kid: Sequence[UniNode],
    ) -> None:
        self.f_type = f_type
        self.compares = list(compares)
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)


class AssignCompr(AtomExpr):
    """AssignCompr node type for Jac Ast."""

    def __init__(
        self,
        assigns: Sequence[KWPair],
        kid: Sequence[UniNode],
    ) -> None:
        self.assigns = list(assigns)
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)


# JSX Nodes
# ---------


class JsxElement(AtomExpr):
    """JsxElement node type for Jac Ast."""

    def __init__(
        self,
        name: JsxElementName | None,
        attributes: Sequence[JsxAttribute] | None,
        children: Sequence[JsxChild | JsxElement] | None,
        is_self_closing: bool,
        is_fragment: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.attributes = list(attributes) if attributes else []
        self.children: list[JsxChild | JsxElement] = list(children) if children else []
        self.is_self_closing = is_self_closing
        self.is_fragment = is_fragment
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.OBJECT_ARCH)


class JsxElementName(UniNode):
    """JsxElementName node type for Jac Ast."""

    def __init__(
        self,
        parts: Sequence[Name | Token],
        kid: Sequence[UniNode],
    ) -> None:
        self.parts = list(parts)
        UniNode.__init__(self, kid=kid)


class JsxAttribute(UniNode):
    """JsxAttribute node type for Jac Ast (base class)."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        UniNode.__init__(self, kid=kid)


class JsxSpreadAttribute(JsxAttribute):
    """JsxSpreadAttribute node type for Jac Ast."""

    def __init__(
        self,
        expr: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.expr = expr
        JsxAttribute.__init__(self, kid=kid)


class JsxNormalAttribute(JsxAttribute):
    """JsxNormalAttribute node type for Jac Ast."""

    def __init__(
        self,
        name: Name | Token,
        value: String | Expr | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.value = value
        JsxAttribute.__init__(self, kid=kid)


class JsxChild(UniNode):
    """JsxChild node type for Jac Ast (base class)."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        UniNode.__init__(self, kid=kid)


class JsxText(JsxChild):
    """JsxText node type for Jac Ast."""

    def __init__(
        self,
        value: str | Token,
        kid: Sequence[UniNode],
    ) -> None:
        self.value = value
        JsxChild.__init__(self, kid=kid)


class JsxExpression(JsxChild):
    """JsxExpression node type for Jac Ast."""

    def __init__(
        self,
        expr: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.expr = expr
        JsxChild.__init__(self, kid=kid)


# Match Nodes
# ------------


class MatchStmt(CodeBlockStmt):
    """MatchStmt node type for Jac Ast."""

    def __init__(
        self,
        target: Expr,
        cases: list[MatchCase],
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        self.cases = cases
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)


class MatchCase(UniScopeNode):
    """MatchCase node type for Jac Ast."""

    def __init__(
        self,
        pattern: MatchPattern,
        guard: Expr | None,
        body: list[CodeBlockStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.pattern = pattern
        self.guard = guard
        self.body = body
        UniNode.__init__(self, kid=kid)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")


class SwitchStmt(CodeBlockStmt):
    """SwitchStmt node type for Jac Ast."""

    def __init__(
        self,
        target: Expr,
        cases: list[SwitchCase],
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        self.cases = cases
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)


class SwitchCase(UniScopeNode):
    """SwitchCase node type for Jac Ast."""

    def __init__(
        self,
        pattern: MatchPattern | None,
        body: list[CodeBlockStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.pattern = pattern
        self.body = body
        UniNode.__init__(self, kid=kid)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")


class MatchOr(MatchPattern):
    """MatchOr node type for Jac Ast."""

    def __init__(
        self,
        patterns: list[MatchPattern],
        kid: Sequence[UniNode],
    ) -> None:
        self.patterns = patterns
        UniNode.__init__(self, kid=kid)


class MatchAs(MatchPattern):
    """MatchAs node type for Jac Ast."""

    def __init__(
        self,
        name: NameAtom,
        pattern: MatchPattern | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.pattern = pattern
        UniNode.__init__(self, kid=kid)


class MatchWild(MatchPattern):
    """MatchWild node type for Jac Ast."""


class MatchValue(MatchPattern):
    """MatchValue node type for Jac Ast."""

    def __init__(
        self,
        value: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.value = value
        UniNode.__init__(self, kid=kid)


class MatchSingleton(MatchPattern):
    """MatchSingleton node type for Jac Ast."""

    def __init__(
        self,
        value: Bool | Null,
        kid: Sequence[UniNode],
    ) -> None:
        self.value = value
        UniNode.__init__(self, kid=kid)


class MatchSequence(MatchPattern):
    """MatchSequence node type for Jac Ast."""

    def __init__(
        self,
        values: list[MatchPattern],
        kid: Sequence[UniNode],
    ) -> None:
        self.values = values
        UniNode.__init__(self, kid=kid)


class MatchMapping(MatchPattern):
    """MatchMapping node type for Jac Ast."""

    def __init__(
        self,
        values: list[MatchKVPair | MatchStar],
        kid: Sequence[UniNode],
    ) -> None:
        self.values = values
        UniNode.__init__(self, kid=kid)


class MatchKVPair(MatchPattern):
    """MatchKVPair node type for Jac Ast."""

    def __init__(
        self,
        key: MatchPattern | NameAtom | AtomExpr,
        value: MatchPattern,
        kid: Sequence[UniNode],
    ) -> None:
        self.key = key
        self.value = value
        UniNode.__init__(self, kid=kid)


class MatchStar(MatchPattern):
    """MatchStar node type for Jac Ast."""

    def __init__(
        self,
        name: NameAtom,
        is_list: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.is_list = is_list
        UniNode.__init__(self, kid=kid)


class MatchArch(MatchPattern):
    """MatchArch node type for Jac Ast."""

    def __init__(
        self,
        name: AtomTrailer | NameAtom,
        arg_patterns: Sequence[MatchPattern] | None,
        kw_patterns: Sequence[MatchKVPair] | None,
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.arg_patterns = list(arg_patterns) if arg_patterns else None
        self.kw_patterns = list(kw_patterns) if kw_patterns else None
        UniNode.__init__(self, kid=kid)


# AST Terminal Node Types
# --------------------------
class Token(UniNode):
    """Token node type for Jac Ast."""

    def __init__(
        self,
        orig_src: Source,
        name: str,
        value: str,
        line: int,
        end_line: int,
        col_start: int,
        col_end: int,
        pos_start: int,
        pos_end: int,
    ) -> None:
        self.orig_src = orig_src
        self.name = name
        self.value = value
        self.line_no = line
        self.end_line = end_line
        self.c_start = col_start
        self.c_end = col_end
        self.pos_start = pos_start
        self.pos_end = pos_end
        UniNode.__init__(self, kid=[])

    def __repr__(self) -> str:
        return f"Token({self.name}, {self.value}, {self.loc})"

    def unparse(self) -> str:
        if self.gen.jac:
            return self.gen.jac
        return self.value


class Name(Token, NameAtom):
    """Name node type for Jac Ast."""

    def __init__(
        self,
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
        is_kwesc: bool = False,
    ) -> None:
        self.is_kwesc = is_kwesc
        Token.__init__(
            self,
            orig_src=orig_src,
            name=name,
            value=value,
            line=line,
            end_line=end_line,
            col_start=col_start,
            col_end=col_end,
            pos_start=pos_start,
            pos_end=pos_end,
        )
        NameAtom.__init__(self, is_enum_stmt=is_enum_stmt)
        AstSymbolNode.__init__(
            self,
            sym_name=value,
            name_spec=self,
            sym_category=SymbolType.VAR,
        )

    @staticmethod
    def gen_stub_from_node(
        node: AstSymbolNode, name_str: str, set_name_of: AstSymbolNode | None = None
    ) -> Name:
        """Generate name from node."""
        ret = Name(
            orig_src=node.loc.orig_src,
            name=Tok.NAME.value,
            value=name_str,
            col_start=node.loc.col_start,
            col_end=node.loc.col_end,
            line=node.loc.first_line,
            end_line=node.loc.last_line,
            pos_start=node.loc.pos_start,
            pos_end=node.loc.pos_end,
        )
        ret.parent = node.parent
        ret.name_of = set_name_of if set_name_of else ret
        return ret


class SpecialVarRef(Name):
    """SpecialVarRef node type for Jac Ast."""

    def __init__(
        self,
        var: Name,
        is_enum_stmt: bool = False,
    ) -> None:
        self.orig = var
        Name.__init__(
            self,
            orig_src=var.orig_src,
            name=var.name,
            value=self.py_resolve_name(),  # TODO: This shouldnt be necessary
            line=var.line_no,
            end_line=var.end_line,
            col_start=var.c_start,
            col_end=var.c_end,
            pos_start=var.pos_start,
            pos_end=var.pos_end,
        )
        NameAtom.__init__(self, is_enum_stmt=is_enum_stmt)
        AstSymbolNode.__init__(
            self,
            sym_name=self.py_resolve_name(),
            name_spec=self,
            sym_category=SymbolType.VAR,
        )

    def py_resolve_name(self) -> str:
        if self.orig.name == Tok.KW_SELF:
            return "self"
        if self.orig.name == Tok.KW_PROPS:
            return "props"
        elif self.orig.name == Tok.KW_SUPER:
            return "super"
        elif self.orig.name == Tok.KW_ROOT:
            return Con.ROOT.value
        elif self.orig.name == Tok.KW_HERE:
            return Con.HERE.value
        elif self.orig.name == Tok.KW_VISITOR:
            return Con.VISITOR.value
        elif self.orig.name == Tok.KW_INIT:
            return "__init__"
        elif self.orig.name == Tok.KW_POST_INIT:
            return "__post_init__"
        else:
            raise NotImplementedError("ICE: Special var reference not implemented")


class Literal(Token, AtomExpr):
    """Literal node type for Jac Ast."""

    SYMBOL_TYPE = SymbolType.VAR

    type_map = {
        "int": int,
        "float": float,
        "str": str,
        "bool": bool,
        "bytes": bytes,
        "list": list,
        "tuple": tuple,
        "set": set,
        "dict": dict,
        "type": type,
    }

    def __init__(
        self,
        orig_src: Source,
        name: str,
        value: str,
        line: int,
        end_line: int,
        col_start: int,
        col_end: int,
        pos_start: int,
        pos_end: int,
    ) -> None:
        Token.__init__(
            self,
            orig_src=orig_src,
            name=name,
            value=value,
            line=line,
            end_line=end_line,
            col_start=col_start,
            col_end=col_end,
            pos_start=pos_start,
            pos_end=pos_end,
        )
        AstSymbolStubNode.__init__(self, sym_type=self.SYMBOL_TYPE)
        Expr.__init__(self)

    @property
    def lit_value(
        self,
    ) -> int | str | float | bool | None | Callable[[], Any] | EllipsisType:
        """Return literal value in its python type."""
        raise NotImplementedError


class BuiltinType(Name, Literal):
    """BuiltinType node type for Jac Ast."""

    SYMBOL_TYPE = SymbolType.VAR

    @property
    def lit_value(self) -> Callable[[], Any]:
        """Return literal value in its python type."""
        if self.value not in Literal.type_map:
            raise TypeError(f"ICE: {self.value} is not a callable builtin")
        return Literal.type_map[self.value]


class Float(Literal):
    """Float node type for Jac Ast."""

    SYMBOL_TYPE = SymbolType.NUMBER

    @property
    def lit_value(self) -> float:
        return float(self.value)


class Int(Literal):
    """Int node type for Jac Ast."""

    SYMBOL_TYPE = SymbolType.NUMBER

    @property
    def lit_value(self) -> int:
        return int(self.value)


class String(Literal):
    """String node type for Jac Ast."""

    SYMBOL_TYPE = SymbolType.STRING

    @property
    def lit_value(self) -> str:
        if isinstance(self.value, bytes):
            return self.value
        if any(
            self.value.startswith(prefix)
            and self.value[len(prefix) :].startswith(("'", '"'))
            for prefix in ["r", "b", "br", "rb"]
        ):
            return eval(self.value)

        elif self.value.startswith(("'", '"')):
            if (not self.find_parent_of_type(FString)) or (
                not (self.parent and isinstance(self.parent, FString))
            ):
                try:
                    return ast3.literal_eval(self.value)
                except (ValueError, SyntaxError):
                    if (
                        self.value.startswith('"""') and self.value.endswith('"""')
                    ) or (self.value.startswith("'''") and self.value.endswith("'''")):
                        return self.value[3:-3]
                    return self.value[1:-1]
            try:
                return ast3.literal_eval(self.value)
            except (ValueError, SyntaxError):
                return self.value
        else:
            # For f-string literal parts (no quotes), decode common escape sequences
            # but only if the f-string is not a raw string (rf"..." or fr"...")
            if self.parent and isinstance(self.parent, FString):
                fstring_parent: FString = self.parent
                # Check if it's a raw f-string by looking at the start token
                is_raw = False
                if fstring_parent.start and fstring_parent.start.value:
                    prefix = fstring_parent.start.value.lower()
                    is_raw = "r" in prefix
                if not is_raw:
                    # Decode escape sequences in the correct order:
                    # First protect \\ by replacing with placeholder, then decode
                    # escape sequences, then restore backslashes
                    result = self.value
                    placeholder = "\x00"
                    result = result.replace("\\\\", placeholder)
                    result = result.replace("\\n", "\n")
                    result = result.replace("\\t", "\t")
                    result = result.replace("\\r", "\r")
                    result = result.replace(placeholder, "\\")
                    return result
            return self.value


class Bool(Literal):
    """Bool node type for Jac Ast."""

    SYMBOL_TYPE = SymbolType.BOOL

    @property
    def lit_value(self) -> bool:
        return self.value == "True"


class Null(Literal):
    """Null node type for Jac Ast."""

    SYMBOL_TYPE = SymbolType.NULL

    @property
    def lit_value(self) -> None:
        return None


class Ellipsis(Literal):
    """Ellipsis node type for Jac Ast."""

    SYMBOL_TYPE = SymbolType.NULL

    @property
    def lit_value(self) -> EllipsisType:
        return ...


class EmptyToken(Token):
    """EmptyToken node type for Jac Ast."""

    def __init__(self, orig_src: Source | None = None) -> None:
        super().__init__(
            name="EmptyToken",
            orig_src=orig_src or Source("", ""),
            value="",
            line=0,
            end_line=0,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0,
        )


class Semi(
    Token,
    CodeBlockStmt,
):
    """Semicolon node type for Jac Ast."""

    def __init__(
        self,
        orig_src: Source,
        name: str,
        value: str,
        line: int,
        end_line: int,
        col_start: int,
        col_end: int,
        pos_start: int,
        pos_end: int,
    ) -> None:
        """Initialize token."""
        Token.__init__(
            self,
            orig_src=orig_src,
            name=name,
            value=value,
            line=line,
            end_line=end_line,
            col_start=col_start,
            col_end=col_end,
            pos_start=pos_start,
            pos_end=pos_end,
        )
        CodeBlockStmt.__init__(self)


class CommentToken(Token):
    """CommentToken node type for Jac Ast."""

    def __init__(
        self,
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
        is_inline: bool = False,
    ) -> None:
        self.is_inline = is_inline

        Token.__init__(
            self,
            orig_src=orig_src,
            name=name,
            value=value,
            line=line,
            end_line=end_line,
            col_start=col_start,
            col_end=col_end,
            pos_start=pos_start,
            pos_end=pos_end,
        )

        UniNode.__init__(self, kid=kid)

    @property
    def left_node(self) -> UniNode | None:
        if self.parent and (idx := self.parent.kid.index(self)) > 0:
            return self.parent.kid[idx - 1]
        return None

    @property
    def right_node(self) -> UniNode | None:
        if (
            self.parent
            and (idx := self.parent.kid.index(self)) < len(self.parent.kid) - 1
        ):
            return self.parent.kid[idx + 1]
        return None


# ----------------
class Source(EmptyToken):
    """SourceString node type for Jac Ast."""

    def __init__(self, source: str, mod_path: str) -> None:
        super().__init__(self)
        self.value = source
        self.hash = md5(source.encode()).hexdigest()
        self.file_path = mod_path
        self.comments: list[CommentToken] = []

    @property
    def code(self) -> str:
        """Return the source code as string."""
        return self.value


class PythonModuleAst(EmptyToken):
    """SourceString node type for Jac Ast."""

    def __init__(self, ast: ast3.Module, orig_src: Source) -> None:
        super().__init__()
        self.ast = ast
        self.orig_src = orig_src
        self.file_path = orig_src.file_path
