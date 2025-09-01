"""Abstract class for IR Passes for Jac."""

from __future__ import annotations

import ast as ast3
import builtins
import os
from copy import copy
from dataclasses import dataclass
from hashlib import md5
from types import EllipsisType
from typing import (
    Any,
    Callable,
    Generic,
    Optional,
    Sequence,
    Type,
    TypeVar,
)


from jaclang.compiler import TOKEN_MAP
from jaclang.compiler.codeinfo import CodeGenTarget, CodeLocInfo
from jaclang.compiler.constant import (
    Constants as Con,
    EdgeDir,
    JacSemTokenModifier as SemTokMod,
    JacSemTokenType as SemTokType,
    SymbolType,
)
from jaclang.compiler.constant import DELIM_MAP, SymbolAccess, Tokens as Tok
from jaclang.compiler.type_system.types import TypeBase
from jaclang.utils import resolve_relative_path
from jaclang.utils.treeprinter import (
    print_ast_tree,
    print_symtab_tree,
    printgraph_ast_tree,
    printgraph_symtab_tree,
)


class UniNode:
    """Abstract syntax tree node for Jac."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        """Initialize ast."""
        self.parent: Optional[UniNode] = None
        self.kid: list[UniNode] = [x.set_parent(self) for x in kid]
        self._sub_node_tab: dict[type, list[UniNode]] = {}
        self.construct_sub_node_tab()
        self._in_mod_nodes: list[UniNode] = []
        self.gen: CodeGenTarget = CodeGenTarget()
        self.loc: CodeLocInfo = CodeLocInfo(*self.resolve_tok_range())

    def construct_sub_node_tab(self) -> None:
        """Construct sub node table."""
        for i in self.kid:
            if not i:
                continue
            for k, v in i._sub_node_tab.items():
                if k in self._sub_node_tab:
                    self._sub_node_tab[k].extend(v)
                else:
                    self._sub_node_tab[k] = copy(v)
            if type(i) in self._sub_node_tab:
                self._sub_node_tab[type(i)].append(i)
            else:
                self._sub_node_tab[type(i)] = [i]

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

    def gen_token(self, name: Tok, value: Optional[str] = None) -> Token:
        value = (
            value
            if value
            else (
                DELIM_MAP[name]
                if name in DELIM_MAP
                else TOKEN_MAP[name.value] if name.value in TOKEN_MAP else name.value
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

    def get_all_sub_nodes(self, typ: Type[T], brute_force: bool = True) -> list[T]:
        """Get all sub nodes of type."""
        from jaclang.compiler.passes import UniPass

        return UniPass.get_all_sub_nodes(node=self, typ=typ, brute_force=brute_force)

    def find_parent_of_type(self, typ: Type[T]) -> Optional[T]:
        """Get parent of type."""
        from jaclang.compiler.passes import UniPass

        return UniPass.find_parent_of_type(node=self, typ=typ)

    def parent_of_type(self, typ: Type[T]) -> T:
        ret = self.find_parent_of_type(typ)
        if isinstance(ret, typ):
            return ret
        else:
            raise ValueError(f"Parent of type {typ} not found from {type(self)}.")

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

    def pp(self, depth: Optional[int] = None) -> str:
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

    def normalize(self, deep: bool = False) -> bool:
        return False

    def unparse(self) -> str:
        valid = self.normalize()
        res = " ".join([i.unparse() for i in self.kid])
        if not valid:
            raise NotImplementedError(f"Node {type(self).__name__} is not valid.")
        return res


# Symbols can have mulitple definitions but resolves decl to be the
# first such definition in a given scope.
class Symbol:
    """Symbol."""

    def __init__(
        self,
        defn: NameAtom,
        access: SymbolAccess,
        parent_tab: UniScopeNode,
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
    def symbol_table(self) -> Optional[UniScopeNode]:
        """Get symbol table."""
        return self.parent_tab.find_scope(self.sym_name)

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


class UniScopeNode(UniNode):
    """Symbol Table."""

    def __init__(
        self,
        name: str,
        parent_scope: Optional[UniScopeNode] = None,
    ) -> None:
        """Initialize."""
        self.scope_name = name
        self.parent_scope = parent_scope
        self.kid_scope: list[UniScopeNode] = []
        self.names_in_scope: dict[str, Symbol] = {}
        self.inherited_scope: list[InheritedSymbolTable] = []

    def get_type(self) -> SymbolType:
        """Get type."""
        if isinstance(self, AstSymbolNode):
            return self.sym_category
        return SymbolType.VAR

    def get_parent(self) -> Optional[UniScopeNode]:
        """Get parent."""
        return self.parent_scope

    def lookup(self, name: str, deep: bool = True) -> Optional[Symbol]:
        """Lookup a variable in the symbol table."""
        if name in self.names_in_scope:
            return self.names_in_scope[name]
        for i in self.inherited_scope:
            found = i.lookup(name, deep=False)
            if found:
                return found
        if deep and self.parent_scope:
            return self.parent_scope.lookup(name, deep)
        return None

    def insert(
        self,
        node: AstSymbolNode,
        access_spec: Optional[AstAccessNode] | SymbolAccess = None,
        single: bool = False,
        force_overwrite: bool = False,
        imported: bool = False,
    ) -> Optional[UniNode]:
        """Set a variable in the symbol table.

        Returns original symbol as collision if single check fails, none otherwise.
        Also updates node.sym to create pointer to symbol.
        """
        collision = (
            self.names_in_scope[node.sym_name].defn[-1]
            if single and node.sym_name in self.names_in_scope
            else None
        )
        if force_overwrite or node.sym_name not in self.names_in_scope:
            self.names_in_scope[node.sym_name] = Symbol(
                defn=node.name_spec,
                access=(
                    access_spec
                    if isinstance(access_spec, SymbolAccess)
                    else access_spec.access_type if access_spec else SymbolAccess.PUBLIC
                ),
                parent_tab=self,
                imported=imported,
            )
        else:
            self.names_in_scope[node.sym_name].add_defn(node.name_spec)
        node.name_spec.sym = self.names_in_scope[node.sym_name]
        return collision

    def find_scope(self, name: str) -> Optional[UniScopeNode]:
        """Find a scope in the symbol table."""
        for k in self.kid_scope:
            if k.scope_name == name:
                return k
        for k2 in self.inherited_scope:
            if k2.base_symbol_table.scope_name == name:
                return k2.base_symbol_table
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
        access_spec: Optional[AstAccessNode] | SymbolAccess = None,
        single_decl: Optional[str] = None,
        force_overwrite: bool = False,
        imported: bool = False,
    ) -> Optional[Symbol]:
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
        sym_table: Optional[UniScopeNode] = None,
    ) -> Optional[Symbol]:
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

    def inherit_baseclasses_sym(self, node: Archetype | Enum) -> None:
        """Inherit base classes symbol tables."""
        if node.base_classes:
            for base_cls in node.base_classes:
                if (
                    isinstance(base_cls, AstSymbolNode)
                    and (found := self.use_lookup(base_cls))
                    and found
                ):
                    found_tab = found.decl.sym_tab
                    inher_sym_tab = InheritedSymbolTable(
                        base_symbol_table=found_tab, load_all_symbols=True, symbols=[]
                    )
                    self.inherited_scope.append(inher_sym_tab)
                    base_cls.name_spec.name_of = found.decl.name_of

    def sym_pp(self, depth: Optional[int] = None) -> str:
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


class InheritedSymbolTable:
    """Inherited symbol table."""

    def __init__(
        self,
        base_symbol_table: UniScopeNode,
        load_all_symbols: bool = False,  # This is needed for python imports
        symbols: Optional[list[str]] = None,
    ) -> None:
        """Initialize."""
        self.base_symbol_table: UniScopeNode = base_symbol_table
        self.load_all_symbols: bool = load_all_symbols
        self.symbols: list[str] = symbols if symbols else []

    def lookup(self, name: str, deep: bool = False) -> Optional[Symbol]:
        """Lookup a variable in the symbol table."""
        if self.load_all_symbols:
            return self.base_symbol_table.lookup(name, deep)
        else:
            if name in self.symbols:
                return self.base_symbol_table.lookup(name, deep)
            else:
                return None


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
    def sym(self) -> Optional[Symbol]:
        return self.name_spec.sym

    @property
    def sym_name(self) -> str:
        return self.name_spec.sym_name

    @property
    def sym_category(self) -> SymbolType:
        return self.name_spec.sym_category

    @property
    def py_ctx_func(self) -> Type[ast3.AST]:
        return self.name_spec.py_ctx_func

    @property
    def expr_type(self) -> str:
        return self.name_spec.expr_type

    @property
    def type_sym_tab(self) -> Optional[UniScopeNode]:
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

    def __init__(self, access: Optional[SubTag[Token]]) -> None:
        self.access: Optional[SubTag[Token]] = access

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


T = TypeVar("T", bound=UniNode)


class AstDocNode(UniNode):
    """Nodes that have access."""

    def __init__(self, doc: Optional[String]) -> None:
        self.doc: Optional[String] = doc


class AstAsyncNode(UniNode):
    """Nodes that have access."""

    def __init__(self, is_async: bool) -> None:
        self.is_async: bool = is_async


class AstElseBodyNode(UniNode):
    """Nodes that have access."""

    def __init__(self, else_body: Optional[ElseStmt | ElseIf]) -> None:
        self.else_body: Optional[ElseStmt | ElseIf] = else_body


class AstTypedVarNode(UniNode):
    """Nodes that have access."""

    def __init__(self, type_tag: Optional[SubTag[Expr]]) -> None:
        self.type_tag: Optional[SubTag[Expr]] = type_tag


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
        self._type_sym_tab: Optional[UniScopeNode] = None

        # When the type of an expression is resolved, we'll be caching
        # the type here.
        #
        # TODO:
        # 1. Find a better name for this
        # 2. Migrate this to expr_type property
        self.type: TypeBase | None = None

    @property
    def expr_type(self) -> str:
        return self._sym_type

    @expr_type.setter
    def expr_type(self, sym_type: str) -> None:
        self._sym_type = sym_type

    @property
    def type_sym_tab(self) -> Optional[UniScopeNode]:
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

    def __init__(self, body: Optional[T]) -> None:
        self.body = body

    @property
    def needs_impl(self) -> bool:
        return self.body is None


class NameAtom(AtomExpr, EnumBlockStmt):
    """NameAtom node type for Jac Ast."""

    def __init__(self, is_enum_stmt: bool) -> None:
        self.name_of: AstSymbolNode = self
        self._sym: Optional[Symbol] = None
        self._sym_name: str = ""
        self._sym_category: SymbolType = SymbolType.UNKNOWN
        self._py_ctx_func: Type[ast3.expr_context] = ast3.Load
        AtomExpr.__init__(self)
        EnumBlockStmt.__init__(self, is_enum_stmt=is_enum_stmt)

    @property
    def sym(self) -> Optional[Symbol]:
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

    @property
    def clean_type(self) -> str:
        ret_type = self.expr_type.replace("builtins.", "").replace("NoType", "")
        return ret_type

    @property
    def py_ctx_func(self) -> Type[ast3.expr_context]:
        """Get python context function."""
        return self._py_ctx_func

    @py_ctx_func.setter
    def py_ctx_func(self, py_ctx_func: Type[ast3.expr_context]) -> None:
        """Set python context function."""
        self._py_ctx_func = py_ctx_func

    @property
    def sem_token(self) -> Optional[tuple[SemTokType, SemTokMod]]:
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

    def normalize(self, deep: bool = False) -> bool:
        res = self.tag.normalize() if deep else True
        self.set_kids(nodes=[self.gen_token(Tok.COLON), self.tag])
        return res


# AST Mid Level Node Types
# --------------------------
class Module(AstDocNode, UniScopeNode):
    """Whole Program node type for Jac Ast."""

    def __init__(
        self,
        name: str,
        source: Source,
        doc: Optional[String],
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

        UniNode.__init__(self, kid=kid)
        AstDocNode.__init__(self, doc=doc)
        UniScopeNode.__init__(self, name=self.name)

    @property
    def annexable_by(self) -> Optional[str]:
        """Get annexable by."""
        if not self.stub_only and (
            self.loc.mod_path.endswith(".impl.jac")
            or self.loc.mod_path.endswith(".test.jac")
        ):
            head_mod_name = self.name.split(".")[0]
            potential_path = os.path.join(
                os.path.dirname(self.loc.mod_path),
                f"{head_mod_name}.jac",
            )
            if os.path.exists(potential_path) and potential_path != self.loc.mod_path:
                return potential_path
            annex_dir = os.path.split(os.path.dirname(self.loc.mod_path))[-1]
            if annex_dir.endswith(".impl") or annex_dir.endswith(".test"):
                head_mod_name = os.path.split(os.path.dirname(self.loc.mod_path))[
                    -1
                ].split(".")[0]
                potential_path = os.path.join(
                    os.path.dirname(os.path.dirname(self.loc.mod_path)),
                    f"{head_mod_name}.jac",
                )
                if (
                    os.path.exists(potential_path)
                    and potential_path != self.loc.mod_path
                ):
                    return potential_path
        return None

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.doc.normalize() if self.doc else True
            for i in self.body:
                res = res and i.normalize()
        new_kid: list[UniNode] = []
        if self.doc:
            new_kid.append(self.doc)
        new_kid.extend(self.body)
        self.set_kids(nodes=new_kid if len(new_kid) else [EmptyToken()])
        return res

    def format(self) -> str:
        """Get all sub nodes of type."""
        from jaclang.compiler.passes.tool import DocIRGenPass, JacFormatPass
        from jaclang.compiler.program import JacProgram

        return JacFormatPass(
            ir_in=DocIRGenPass(
                ir_in=self,
                prog=JacProgram(),
            ).ir_out,
            prog=JacProgram(),
        ).ir_out.gen.jac

    def unparse(self, requires_format: bool = True) -> str:
        unparsed = super().unparse()
        if not requires_format:
            return unparsed
        return self.format()

    @staticmethod
    def make_stub(
        inject_name: Optional[str] = None, inject_src: Optional[Source] = None
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

    def __init__(self, main_mod: Optional[Module] = None) -> None:
        """Initialize whole program node."""
        self.main = main_mod if main_mod else Module.make_stub()
        UniNode.__init__(self, kid=[self.main])
        self.hub: dict[str, Module] = {self.loc.mod_path: main_mod} if main_mod else {}


class GlobalVars(ElementStmt, AstAccessNode):
    """GlobalVars node type for Jac Ast."""

    def __init__(
        self,
        access: Optional[SubTag[Token]],
        assignments: Sequence[Assignment],
        is_frozen: bool,
        kid: Sequence[UniNode],
        doc: Optional[String] = None,
    ) -> None:
        self.assignments = assignments
        self.is_frozen = is_frozen
        UniNode.__init__(self, kid=kid)
        AstAccessNode.__init__(self, access=access)
        AstDocNode.__init__(self, doc=doc)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.access.normalize(deep) if self.access else True
            for assign in self.assignments:
                res = res and assign.normalize(deep)
            res = res and self.doc.normalize(deep) if self.doc else res
        new_kid: list[UniNode] = []
        if self.doc:
            new_kid.append(self.doc)
        if self.is_frozen:
            new_kid.append(self.gen_token(Tok.KW_LET))
        else:
            new_kid.append(self.gen_token(Tok.KW_GLOBAL))
        if self.access:
            new_kid.append(self.access)
        for i, assign in enumerate(self.assignments):
            new_kid.append(assign)
            if i < len(self.assignments) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        self.set_kids(nodes=new_kid)
        return res


class Test(AstSymbolNode, ElementStmt, UniScopeNode):
    """Test node type for Jac Ast."""

    TEST_COUNT = 0

    def __init__(
        self,
        name: Name | Token,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
        doc: Optional[String] = None,
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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.name.normalize(deep)
            for stmt in self.body:
                res = res and stmt.normalize(deep)
            res = res and self.doc.normalize(deep) if self.doc else res
        new_kid: list[UniNode] = []
        if self.doc:
            new_kid.append(self.doc)
        new_kid.append(self.gen_token(Tok.KW_TEST))
        new_kid.append(self.name)
        new_kid.append(self.gen_token(Tok.LBRACE))
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


class ModuleCode(ElementStmt, ArchBlockStmt, EnumBlockStmt):
    """ModuleCode node type for Jac Ast."""

    def __init__(
        self,
        name: Optional[Name],
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
        is_enum_stmt: bool = False,
        doc: Optional[String] = None,
    ) -> None:
        self.name = name
        self.body = body
        UniNode.__init__(self, kid=kid)
        AstDocNode.__init__(self, doc=doc)
        EnumBlockStmt.__init__(self, is_enum_stmt=is_enum_stmt)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.name.normalize(deep) if self.name else res
            for stmt in self.body:
                res = res and stmt.normalize(deep)
            res = res and self.doc.normalize(deep) if self.doc else res
        new_kid: list[UniNode] = []
        if self.doc:
            new_kid.append(self.doc)
        new_kid.append(self.gen_token(Tok.KW_WITH))
        new_kid.append(self.gen_token(Tok.KW_ENTRY))
        if self.name:
            new_kid.append(self.gen_token(Tok.COLON))
            new_kid.append(self.name)
        new_kid.append(self.gen_token(Tok.LBRACE))
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


class PyInlineCode(ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt):
    """PyInlineCode node type for Jac Ast."""

    def __init__(
        self,
        code: Token,
        kid: Sequence[UniNode],
        is_enum_stmt: bool = False,
        doc: Optional[String] = None,
    ) -> None:
        self.code = code
        UniNode.__init__(self, kid=kid)
        AstDocNode.__init__(self, doc=doc)
        CodeBlockStmt.__init__(self)
        EnumBlockStmt.__init__(self, is_enum_stmt=is_enum_stmt)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.code.normalize(deep)
            res = res and self.doc.normalize(deep) if self.doc else res
        new_kid: list[UniNode] = []
        if self.doc:
            new_kid.append(self.doc)
        new_kid.append(self.code)
        self.set_kids(nodes=new_kid)
        return res


class Import(ElementStmt, CodeBlockStmt):
    """Import node type for Jac Ast."""

    def __init__(
        self,
        from_loc: Optional[ModulePath],
        items: Sequence[ModuleItem] | Sequence[ModulePath],
        is_absorb: bool,  # For includes
        kid: Sequence[UniNode],
        doc: Optional[String] = None,
    ) -> None:
        self.hint = None
        self.from_loc = from_loc
        self.items = items
        self.is_absorb = is_absorb
        UniNode.__init__(self, kid=kid)
        AstDocNode.__init__(self, doc=doc)
        CodeBlockStmt.__init__(self)

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
            if self.from_loc.resolve_relative_path().endswith(".jac"):
                return True
            if os.path.isdir(self.from_loc.resolve_relative_path()):
                if os.path.exists(
                    os.path.join(self.from_loc.resolve_relative_path(), "__init__.jac")
                ):
                    return True
                for i in self.items:
                    if isinstance(
                        i, ModuleItem
                    ) and self.from_loc.resolve_relative_path(i.name.value).endswith(
                        ".jac"
                    ):
                        return True
        return any(
            isinstance(i, ModulePath) and i.resolve_relative_path().endswith(".jac")
            for i in self.items
        )

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.hint.normalize(deep) if self.hint else res
            res = res and self.from_loc.normalize(deep) if self.from_loc else res
            for item in self.items:
                res = res and item.normalize(deep)
            res = res and self.doc.normalize(deep) if self.doc else res
        new_kid: list[UniNode] = []
        if self.doc:
            new_kid.append(self.doc)
        if self.is_absorb:
            new_kid.append(self.gen_token(Tok.KW_INCLUDE))
        else:
            new_kid.append(self.gen_token(Tok.KW_IMPORT))
        if self.from_loc:
            new_kid.append(self.gen_token(Tok.KW_FROM))
            new_kid.append(self.from_loc)
            new_kid.append(self.gen_token(Tok.LBRACE))
        for idx, itm in enumerate(self.items):
            new_kid.append(itm)
            if idx < len(self.items) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        if self.from_loc:
            new_kid.append(self.gen_token(Tok.RBRACE))
        else:
            new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class ModulePath(AstSymbolNode):
    """ModulePath node type for Jac Ast."""

    def __init__(
        self,
        path: Optional[Sequence[Name]],
        level: int,
        alias: Optional[Name],
        kid: Sequence[UniNode],
    ) -> None:
        self.path = path
        self.level = level
        self.alias = alias
        self.abs_path: Optional[str] = None

        name_spec = alias if alias else path[0] if path else None

        UniNode.__init__(self, kid=kid)
        if not name_spec:
            pkg_name = self.loc.mod_path
            for _ in range(self.level):
                pkg_name = os.path.dirname(pkg_name)
            pkg_name = pkg_name.split(os.sep)[-1]
            name_spec = Name.gen_stub_from_node(self, pkg_name)
            self.level += 1
        if not isinstance(name_spec, Name):
            raise ValueError("ModulePath should have a name spec. Impossible.")
        AstSymbolNode.__init__(
            self,
            sym_name=name_spec.sym_name,
            name_spec=name_spec,
            sym_category=SymbolType.MODULE,
        )

    @property
    def dot_path_str(self) -> str:
        """Get path string."""
        return ("." * self.level) + ".".join(
            [p.value for p in self.path] if self.path else [self.name_spec.sym_name]
        )

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            if self.path:
                for item in self.path:
                    res = res and item.normalize(deep)
            res = res and self.alias.normalize(deep) if self.alias else res
        new_kid: list[UniNode] = []
        for _ in range(self.level):
            new_kid.append(self.gen_token(Tok.DOT))
        if self.path:
            for idx, item in enumerate(self.path):
                new_kid.append(item)
                if idx < len(self.path) - 1:
                    new_kid.append(self.gen_token(Tok.DOT))
        if self.alias:
            new_kid.append(self.gen_token(Tok.KW_AS))
            new_kid.append(self.alias)
        self.set_kids(nodes=new_kid)
        return res

    def resolve_relative_path(self, target_item: Optional[str] = None) -> str:
        """Convert an import target string into a relative file path."""
        target = self.dot_path_str + (f".{target_item}" if target_item else "")
        return resolve_relative_path(target, self.loc.mod_path)


class ModuleItem(AstSymbolNode):
    """ModuleItem node type for Jac Ast."""

    def __init__(
        self,
        name: Name,
        alias: Optional[Name],
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.alias = alias
        UniNode.__init__(self, kid=kid)
        AstSymbolNode.__init__(
            self,
            sym_name=alias.sym_name if alias else name.sym_name,
            name_spec=alias or name,
            sym_category=SymbolType.MOD_VAR,
        )
        self.abs_path: Optional[str] = None

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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = res and self.name.normalize(deep)
            res = res and self.alias.normalize(deep) if self.alias else res
        new_kid: list[UniNode] = [self.name]
        if self.alias:
            new_kid.append(self.gen_token(Tok.KW_AS))
            new_kid.append(self.alias)
        self.set_kids(nodes=new_kid)
        return res


class Archetype(
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
        access: Optional[SubTag[Token]],
        base_classes: Sequence[Expr] | None,
        body: Sequence[ArchBlockStmt] | ImplDef | None,
        kid: Sequence[UniNode],
        doc: Optional[String] = None,
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
            sym_category=(
                SymbolType.OBJECT_ARCH
                if arch_type.name == Tok.KW_OBJECT
                else (
                    SymbolType.NODE_ARCH
                    if arch_type.name == Tok.KW_NODE
                    else (
                        SymbolType.EDGE_ARCH
                        if arch_type.name == Tok.KW_EDGE
                        else (
                            SymbolType.WALKER_ARCH
                            if arch_type.name == Tok.KW_WALKER
                            else SymbolType.TYPE
                        )
                    )
                )
            ),
        )
        AstImplNeedingNode.__init__(self, body=body)
        AstAccessNode.__init__(self, access=access)
        AstDocNode.__init__(self, doc=doc)
        ArchSpec.__init__(self, decorators=decorators)
        UniScopeNode.__init__(self, name=self.sym_name)
        CodeBlockStmt.__init__(self)

    @property
    def is_abstract(self) -> bool:
        body = (
            list(self.body)
            if isinstance(self.body, Sequence)
            else (
                list(self.body.body)
                if isinstance(self.body, ImplDef)
                and isinstance(self.body.body, Sequence)
                else []
            )
        )
        return any(isinstance(i, Ability) and i.is_abstract for i in body)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.name.normalize(deep)
            res = res and self.arch_type.normalize(deep)
            res = res and self.access.normalize(deep) if self.access else res
            for base in self.base_classes:
                res = res and base.normalize(deep)
            if isinstance(self.body, ImplDef):
                res = res and self.body.normalize(deep)
            elif isinstance(self.body, Sequence):
                for stmt in self.body:
                    res = res and stmt.normalize(deep)
            else:
                res = res and self.body.normalize(deep) if self.body else res
            res = res and self.doc.normalize(deep) if self.doc else res
            for dec in self.decorators or []:
                res = res and dec.normalize(deep)
        new_kid: list[UniNode] = []
        if self.doc:
            new_kid.append(self.doc)
        if self.decorators:
            new_kid.append(self.gen_token(Tok.DECOR_OP))
            for idx, dec in enumerate(self.decorators):
                new_kid.append(dec)
                if idx < len(self.decorators) - 1:
                    new_kid.append(self.gen_token(Tok.DECOR_OP))
        if self.is_async:
            new_kid.append(self.gen_token(Tok.KW_ASYNC))
        new_kid.append(self.arch_type)
        if self.access:
            new_kid.append(self.access)
        new_kid.append(self.name)
        if self.base_classes:
            new_kid.append(self.gen_token(Tok.LPAREN))
            for idx, base in enumerate(self.base_classes):
                new_kid.append(base)
                if idx < len(self.base_classes) - 1:
                    new_kid.append(self.gen_token(Tok.COMMA))
            new_kid.append(self.gen_token(Tok.RPAREN))
        if self.body:
            if isinstance(self.body, ImplDef):
                new_kid.append(self.gen_token(Tok.SEMI))
            else:
                new_kid.append(self.gen_token(Tok.LBRACE))
                for stmt in self.body:
                    new_kid.append(stmt)
                new_kid.append(self.gen_token(Tok.RBRACE))
        else:
            new_kid.append(self.gen_token(Tok.LBRACE))
            new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


class ImplDef(CodeBlockStmt, ElementStmt, ArchBlockStmt, AstSymbolNode, UniScopeNode):
    """AstImplOnlyNode node type for Jac Ast."""

    def __init__(
        self,
        decorators: Optional[Sequence[Expr]],
        target: Sequence[NameAtom],
        spec: Sequence[Expr] | FuncSignature | EventSignature | None,
        body: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr,
        kid: Sequence[UniNode],
        doc: Optional[String] = None,
        decl_link: Optional[UniNode] = None,
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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for item in self.target:
                res = res and item.normalize(deep)
            if isinstance(self.spec, Sequence):
                for sp in self.spec:
                    res = res and sp.normalize(deep)
            else:
                res = res and self.spec.normalize(deep) if self.spec else res
            if isinstance(self.body, Expr):
                res = res and self.body.normalize(deep)
            else:
                for stmt in self.body:
                    res = res and stmt.normalize(deep)
            res = res and self.doc.normalize(deep) if self.doc else res
            if self.decorators:
                for dec in self.decorators:
                    res = res and dec.normalize(deep)
        new_kid: list[UniNode] = []
        if self.doc:
            new_kid.append(self.doc)
        if self.decorators:
            new_kid.append(self.gen_token(Tok.DECOR_OP))
            for i, dec in enumerate(self.decorators):
                new_kid.append(dec)
                if i < len(self.decorators) - 1:
                    new_kid.append(self.gen_token(Tok.DECOR_OP))
        new_kid.append(self.gen_token(Tok.KW_IMPL))
        for idx, item in enumerate(self.target):
            new_kid.append(item)
            if idx < len(self.target) - 1:
                new_kid.append(self.gen_token(Tok.DOT))
        if self.spec:
            if isinstance(self.spec, Sequence):
                new_kid.append(self.gen_token(Tok.LPAREN))
                for idx, sp in enumerate(self.spec):
                    new_kid.append(sp)
                    if idx < len(self.spec) - 1:
                        new_kid.append(self.gen_token(Tok.COMMA))
                new_kid.append(self.gen_token(Tok.RPAREN))
            else:
                new_kid.append(self.spec)
        if isinstance(self.body, Expr):
            new_kid.append(self.body)
        else:
            new_kid.append(self.gen_token(Tok.LBRACE))
            prev_stmt = None
            for stmt in self.body:
                if isinstance(prev_stmt, EnumBlockStmt) and prev_stmt.is_enum_stmt:
                    new_kid.append(self.gen_token(Tok.COMMA))
                new_kid.append(stmt)
                prev_stmt = stmt
            new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for item in self.target:
                res = res and item.normalize(deep)
            res = res and self.value.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_SEM),
        ]
        for idx, item in enumerate(self.target):
            new_kid.append(item)
            if idx < len(self.target) - 1:
                new_kid.append(self.gen_token(Tok.DOT))
        new_kid.append(self.gen_token(Tok.EQ))
        new_kid.append(self.value)
        new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class Enum(ArchSpec, AstAccessNode, AstImplNeedingNode, ArchBlockStmt, UniScopeNode):
    """Enum node type for Jac Ast."""

    def __init__(
        self,
        name: Name,
        access: Optional[SubTag[Token]],
        base_classes: Sequence[Expr] | None,
        body: Sequence[EnumBlockStmt] | ImplDef | None,
        kid: Sequence[UniNode],
        doc: Optional[String] = None,
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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.name.normalize(deep)
            res = res and self.access.normalize(deep) if self.access else res
            for base in self.base_classes:
                res = res and base.normalize(deep)
            if isinstance(self.body, ImplDef):
                res = res and self.body.normalize(deep)
            elif isinstance(self.body, Sequence):
                for stmt in self.body:
                    res = res and stmt.normalize(deep)
            else:
                res = res and self.body.normalize(deep) if self.body else res
            res = res and self.doc.normalize(deep) if self.doc else res
            for dec in self.decorators or []:
                res = res and dec.normalize(deep)
        new_kid: list[UniNode] = []
        if self.decorators:
            new_kid.append(self.gen_token(Tok.DECOR_OP))
            for idx, dec in enumerate(self.decorators):
                new_kid.append(dec)
                if idx < len(self.decorators) - 1:
                    new_kid.append(self.gen_token(Tok.DECOR_OP))
        if self.doc:
            new_kid.append(self.doc)
        new_kid.append(self.gen_token(Tok.KW_ENUM))
        if self.access:
            new_kid.append(self.access)
        new_kid.append(self.name)
        if self.base_classes:
            new_kid.append(self.gen_token(Tok.COLON))
            for idx, base in enumerate(self.base_classes):
                new_kid.append(base)
                if idx < len(self.base_classes) - 1:
                    new_kid.append(self.gen_token(Tok.COMMA))
            new_kid.append(self.gen_token(Tok.COLON))
        if self.body:
            if isinstance(self.body, ImplDef):
                new_kid.append(self.gen_token(Tok.SEMI))
            else:
                new_kid.append(self.gen_token(Tok.LBRACE))
                prev_stmt = None
                for stmt in self.body:
                    if isinstance(prev_stmt, EnumBlockStmt) and prev_stmt.is_enum_stmt:
                        new_kid.append(self.gen_token(Tok.COMMA))
                    new_kid.append(stmt)
                    prev_stmt = stmt
                new_kid.append(self.gen_token(Tok.RBRACE))
        else:
            new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class Ability(
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
        name_ref: NameAtom,
        is_async: bool,
        is_override: bool,
        is_static: bool,
        is_abstract: bool,
        access: Optional[SubTag[Token]],
        signature: FuncSignature | EventSignature | None,
        body: Sequence[CodeBlockStmt] | ImplDef | Expr | None,
        kid: Sequence[UniNode],
        doc: Optional[String] = None,
        decorators: Sequence[Expr] | None = None,
    ) -> None:
        self.name_ref = name_ref
        self.is_override = is_override
        self.is_static = is_static
        self.is_abstract = is_abstract
        self.decorators = decorators
        self.signature = signature

        UniNode.__init__(self, kid=kid)
        AstImplNeedingNode.__init__(self, body=body)
        AstSymbolNode.__init__(
            self,
            sym_name=self.py_resolve_name(),
            name_spec=name_ref,
            sym_category=SymbolType.ABILITY,
        )
        AstAccessNode.__init__(self, access=access)
        AstDocNode.__init__(self, doc=doc)
        AstAsyncNode.__init__(self, is_async=is_async)
        UniScopeNode.__init__(self, name=self.sym_name)
        CodeBlockStmt.__init__(self)

    @property
    def is_method(self) -> bool:
        return self.method_owner is not None

    @property
    def is_def(self) -> bool:
        return not self.signature or isinstance(self.signature, FuncSignature)

    @property
    def method_owner(self) -> Optional[Archetype | Enum]:
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
        if isinstance(self.name_ref, Name):
            return self.name_ref.value
        elif isinstance(self.name_ref, SpecialVarRef):
            return self.name_ref.py_resolve_name()
        else:
            raise NotImplementedError

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.name_ref.normalize(deep)
            res = res and self.access.normalize(deep) if self.access else res
            res = res and self.signature.normalize(deep) if self.signature else res
            if isinstance(self.body, ImplDef):
                res = res and self.body.normalize(deep)
            elif isinstance(self.body, Sequence):
                for stmt in self.body:
                    res = res and stmt.normalize(deep)
            else:
                res = res and self.body.normalize(deep) if self.body else res
            for dec in self.decorators or []:
                res = res and dec.normalize(deep)
            res = res and self.doc.normalize(deep) if self.doc else res
        new_kid: list[UniNode] = []
        if self.doc:
            new_kid.append(self.doc)
        if self.decorators:
            new_kid.append(self.gen_token(Tok.DECOR_OP))
            for idx, dec in enumerate(self.decorators):
                new_kid.append(dec)
                if idx < len(self.decorators) - 1:
                    new_kid.append(self.gen_token(Tok.DECOR_OP))
            new_kid.append(self.gen_token(Tok.WS))
        if self.is_async:
            new_kid.append(self.gen_token(Tok.KW_ASYNC))
        if self.is_override:
            new_kid.append(self.gen_token(Tok.KW_OVERRIDE))
        if self.is_static:
            new_kid.append(self.gen_token(Tok.KW_STATIC))
        new_kid.append(
            self.gen_token(Tok.KW_CAN)
            if not self.is_def
            else self.gen_token(Tok.KW_DEF)
        )
        if self.access:
            new_kid.append(self.access)
        new_kid.append(self.name_ref)
        if self.signature:
            new_kid.append(self.signature)
        if self.is_genai_ability:
            new_kid.append(self.gen_token(Tok.KW_BY))
        if self.is_abstract:
            new_kid.append(self.gen_token(Tok.KW_ABSTRACT))
        if self.body is not None:
            if isinstance(self.body, ImplDef):
                new_kid.append(self.gen_token(Tok.SEMI))
            elif isinstance(self.body, Sequence):
                new_kid.append(self.gen_token(Tok.LBRACE))
                for stmt in self.body:
                    new_kid.append(stmt)
                new_kid.append(self.gen_token(Tok.RBRACE))
            else:
                new_kid.append(self.body)
                if self.is_genai_ability:
                    new_kid.append(self.gen_token(Tok.SEMI))
        else:
            new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class FuncSignature(UniNode):
    """FuncSignature node type for Jac Ast."""

    def __init__(
        self,
        params: Sequence[ParamVar] | None,
        return_type: Optional[Expr],
        kid: Sequence[UniNode],
    ) -> None:
        self.params: list[ParamVar] = list(params) if params else []
        self.return_type = return_type
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        is_lambda = self.parent and isinstance(self.parent, LambdaExpr)
        if deep:
            for prm in self.params:
                res = res and prm.normalize(deep)
            res = res and self.return_type.normalize(deep) if self.return_type else res
        new_kid: list[UniNode] = [self.gen_token(Tok.LPAREN)] if not is_lambda else []
        for idx, prm in enumerate(self.params):
            new_kid.append(prm)
            if idx < len(self.params) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        if not is_lambda:
            new_kid.append(self.gen_token(Tok.RPAREN))
        if self.return_type:
            new_kid.append(self.gen_token(Tok.RETURN_HINT))
            new_kid.append(self.return_type)
        self.set_kids(nodes=new_kid)
        return res

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
        arch_tag_info: Optional[Expr],
        kid: Sequence[UniNode],
    ) -> None:
        self.event = event
        self.arch_tag_info = arch_tag_info
        UniNode.__init__(self, kid=kid)
        WalkerStmtOnlyNode.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.event.normalize(deep)
            res = (
                res and self.arch_tag_info.normalize(deep)
                if self.arch_tag_info
                else res
            )
        new_kid: list[UniNode] = [self.gen_token(Tok.KW_WITH)]
        if self.arch_tag_info:
            new_kid.append(self.arch_tag_info)
        new_kid.append(self.event)
        self.set_kids(nodes=new_kid)
        return res


class ParamVar(AstSymbolNode, AstTypedVarNode):
    """ParamVar node type for Jac Ast."""

    def __init__(
        self,
        name: Name,
        unpack: Optional[Token],
        type_tag: SubTag[Expr],
        value: Optional[Expr],
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.unpack = unpack
        self.value = value
        UniNode.__init__(self, kid=kid)
        AstSymbolNode.__init__(
            self,
            sym_name=name.value,
            name_spec=name,
            sym_category=SymbolType.VAR,
        )
        AstTypedVarNode.__init__(self, type_tag=type_tag)

    def normalize(self, deep: bool = True) -> bool:
        res = True
        if deep:
            res = self.name.normalize(deep)
            res = res and self.unpack.normalize(deep) if self.unpack else res
            res = res and self.type_tag.normalize(deep) if self.type_tag else res
            res = res and self.value.normalize(deep) if self.value else res
        new_kid: list[UniNode] = []
        if self.unpack:
            new_kid.append(self.unpack)
        new_kid.append(self.name)
        if self.type_tag:
            new_kid.append(self.type_tag)
        if self.value:
            new_kid.append(self.gen_token(Tok.EQ))
            new_kid.append(self.value)
        self.set_kids(nodes=new_kid)
        return res


# TODO: Must deal with codeblockstmt here, should only be in ArchBocks
# but had to do this for impls to work, probably should do checks in the
# static analysis phase
class ArchHas(AstAccessNode, AstDocNode, ArchBlockStmt, CodeBlockStmt):
    """ArchHas node type for Jac Ast."""

    def __init__(
        self,
        is_static: bool,
        access: Optional[SubTag[Token]],
        vars: Sequence[HasVar],
        is_frozen: bool,
        kid: Sequence[UniNode],
        doc: Optional[String] = None,
    ) -> None:
        self.is_static = is_static
        self.vars: list[HasVar] = list(vars)
        self.is_frozen = is_frozen
        UniNode.__init__(self, kid=kid)
        AstAccessNode.__init__(self, access=access)
        AstDocNode.__init__(self, doc=doc)
        CodeBlockStmt.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.access.normalize(deep) if self.access else res
            for var in self.vars:
                res = res and var.normalize(deep)
            res = res and self.doc.normalize(deep) if self.doc else res
        new_kid: list[UniNode] = []
        if self.doc:
            new_kid.append(self.doc)
        if self.is_static:
            new_kid.append(self.gen_token(Tok.KW_STATIC))
        (
            new_kid.append(self.gen_token(Tok.KW_LET))
            if self.is_frozen
            else new_kid.append(self.gen_token(Tok.KW_HAS))
        )
        if self.access:
            new_kid.append(self.access)
        for i, var in enumerate(self.vars):
            new_kid.append(var)
            if i < len(self.vars) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class HasVar(AstSymbolNode, AstTypedVarNode):
    """HasVar node type for Jac Ast."""

    def __init__(
        self,
        name: Name,
        type_tag: SubTag[Expr],
        value: Optional[Expr],
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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.name.normalize(deep)
            res = res and self.type_tag.normalize(deep) if self.type_tag else res
            res = res and self.value.normalize(deep) if self.value else res
        new_kid: list[UniNode] = [self.name]
        if self.type_tag:
            new_kid.append(self.type_tag)
        if self.value:
            new_kid.append(self.gen_token(Tok.EQ))
            new_kid.append(self.value)
        if self.defer:
            new_kid.append(self.gen_token(Tok.KW_BY))
            new_kid.append(self.gen_token(Tok.KW_POST_INIT))
        self.set_kids(nodes=new_kid)
        return res


class TypedCtxBlock(CodeBlockStmt, UniScopeNode):
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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.type_ctx.normalize(deep)
            for stmt in self.body:
                res = res and stmt.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.RETURN_HINT),
            self.type_ctx,
            self.gen_token(Tok.LBRACE),
        ]
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


class IfStmt(CodeBlockStmt, AstElseBodyNode, UniScopeNode):
    """IfStmt node type for Jac Ast."""

    def __init__(
        self,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: Optional[ElseStmt | ElseIf],
        kid: Sequence[UniNode],
    ) -> None:
        self.condition = condition
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        AstElseBodyNode.__init__(self, else_body=else_body)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.condition.normalize(deep)
            for stmt in self.body:
                res = res and stmt.normalize(deep)
            res = res and self.else_body.normalize(deep) if self.else_body else res
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_IF),
            self.condition,
            self.gen_token(Tok.LBRACE),
        ]
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        if self.else_body:
            new_kid.append(self.else_body)
        self.set_kids(nodes=new_kid)
        return res


class ElseIf(IfStmt):
    """ElseIf node type for Jac Ast."""

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.condition.normalize(deep)
            for stmt in self.body:
                res = res and stmt.normalize(deep)
            res = res and self.else_body.normalize(deep) if self.else_body else res
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_ELIF),
            self.condition,
            self.gen_token(Tok.LBRACE),
        ]
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        if self.else_body:
            new_kid.append(self.else_body)
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for stmt in self.body:
                res = res and stmt.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_ELSE),
            self.gen_token(Tok.LBRACE),
        ]
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = True) -> bool:
        res = self.expr.normalize(deep) if deep else False
        new_kid: list[UniNode] = []
        if self.in_fstring:
            new_kid.append(self.expr)
        else:
            new_kid.append(self.expr)
            new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res and self.expr is not None


class TryStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode):
    """TryStmt node type for Jac Ast."""

    def __init__(
        self,
        body: Sequence[CodeBlockStmt],
        excepts: Sequence[Except],
        else_body: Optional[ElseStmt],
        finally_body: Optional[FinallyStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.body: list[CodeBlockStmt] = list(body)
        self.excepts: list[Except] = list(excepts)
        self.finally_body = finally_body
        UniNode.__init__(self, kid=kid)
        AstElseBodyNode.__init__(self, else_body=else_body)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for stmt in self.body:
                res = res and stmt.normalize(deep)
            for exc in self.excepts:
                res = res and exc.normalize(deep)
            res = res and self.else_body.normalize(deep) if self.else_body else res
            res = (
                res and self.finally_body.normalize(deep) if self.finally_body else res
            )
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_TRY),
            self.gen_token(Tok.LBRACE),
        ]
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        for exc in self.excepts:
            new_kid.append(exc)
        if self.else_body:
            new_kid.append(self.else_body)
        if self.finally_body:
            new_kid.append(self.finally_body)
        self.set_kids(nodes=new_kid)
        return res


class Except(CodeBlockStmt, UniScopeNode):
    """Except node type for Jac Ast."""

    def __init__(
        self,
        ex_type: Expr,
        name: Optional[Name],
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.ex_type = ex_type
        self.name = name
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        CodeBlockStmt.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.ex_type.normalize(deep)
            res = res and self.name.normalize(deep) if self.name else res
            for stmt in self.body:
                res = res and stmt.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_EXCEPT),
            self.ex_type,
        ]
        if self.name:
            new_kid.append(self.gen_token(Tok.KW_AS))
            new_kid.append(self.name)
        new_kid.append(self.gen_token(Tok.LBRACE))
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for stmt in self.body:
                res = res and stmt.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_FINALLY),
            self.gen_token(Tok.LBRACE),
        ]
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


class IterForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode):
    """IterForStmt node type for Jac Ast."""

    def __init__(
        self,
        iter: Assignment,
        is_async: bool,
        condition: Expr,
        count_by: Assignment,
        body: Sequence[CodeBlockStmt],
        else_body: Optional[ElseStmt],
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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.iter.normalize(deep)
            res = self.condition.normalize(deep)
            res = self.count_by.normalize(deep)
            for stmt in self.body:
                res = res and stmt.normalize(deep)
            res = res and self.else_body.normalize(deep) if self.else_body else res
        new_kid: list[UniNode] = []
        if self.is_async:
            new_kid.append(self.gen_token(Tok.KW_ASYNC))
        new_kid.append(self.gen_token(Tok.KW_FOR))
        new_kid.append(self.iter)
        new_kid.append(self.gen_token(Tok.KW_TO))
        new_kid.append(self.condition)
        new_kid.append(self.gen_token(Tok.KW_BY))
        new_kid.append(self.count_by)
        new_kid.append(self.gen_token(Tok.LBRACE))
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        if self.else_body:
            new_kid.append(self.else_body)
        self.set_kids(nodes=new_kid)
        return res


class InForStmt(AstAsyncNode, AstElseBodyNode, CodeBlockStmt, UniScopeNode):
    """InForStmt node type for Jac Ast."""

    def __init__(
        self,
        target: Expr,
        is_async: bool,
        collection: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: Optional[ElseStmt],
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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = res and self.target.normalize(deep)
            res = res and self.collection.normalize(deep)
            for stmt in self.body:
                res = res and stmt.normalize(deep)
            res = res and self.else_body.normalize(deep) if self.else_body else res
        new_kid: list[UniNode] = []
        if self.is_async:
            new_kid.append(self.gen_token(Tok.KW_ASYNC))
        new_kid.append(self.gen_token(Tok.KW_FOR))
        new_kid.append(self.target)
        new_kid.append(self.gen_token(Tok.KW_IN))
        new_kid.append(self.collection)

        new_kid.append(self.gen_token(Tok.LBRACE))
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        if self.else_body:
            new_kid.append(self.else_body)
        self.set_kids(nodes=new_kid)
        return res


class WhileStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode):
    """WhileStmt node type for Jac Ast."""

    def __init__(
        self,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: Optional[ElseStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.condition = condition
        self.body: list[CodeBlockStmt] = list(body)
        UniNode.__init__(self, kid=kid)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")
        AstElseBodyNode.__init__(self, else_body=else_body)
        CodeBlockStmt.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.condition.normalize(deep)
            for stmt in self.body:
                res = res and stmt.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_WHILE),
            self.condition,
            self.gen_token(Tok.LBRACE),
        ]
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        if self.else_body:
            new_kid.append(self.else_body)
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for item in self.exprs:
                res = res and item.normalize(deep)
            for stmt in self.body:
                res = res and stmt.normalize(deep)
        new_kid: list[UniNode] = []
        if self.is_async:
            new_kid.append(self.gen_token(Tok.KW_ASYNC))
        new_kid.append(self.gen_token(Tok.KW_WITH))
        for idx, item in enumerate(self.exprs):
            new_kid.append(item)
            if idx < len(self.exprs) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        new_kid.append(self.gen_token(Tok.LBRACE))
        for stmt in self.body:
            new_kid.append(stmt)
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


class ExprAsItem(UniNode):
    """ExprAsItem node type for Jac Ast."""

    def __init__(
        self,
        expr: Expr,
        alias: Optional[Expr],
        kid: Sequence[UniNode],
    ) -> None:
        self.expr = expr
        self.alias = alias
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = True) -> bool:
        res = True
        if deep:
            res = self.expr.normalize(deep)
            res = res and self.alias.normalize(deep) if self.alias else res
        new_kid: list[UniNode] = [self.expr]
        if self.alias:
            new_kid.append(self.gen_token(Tok.KW_AS))
            new_kid.append(self.alias)
        self.set_kids(nodes=new_kid)
        return res


class RaiseStmt(CodeBlockStmt):
    """RaiseStmt node type for Jac Ast."""

    def __init__(
        self,
        cause: Optional[Expr],
        from_target: Optional[Expr],
        kid: Sequence[UniNode],
    ) -> None:
        self.cause = cause
        self.from_target = from_target
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = res and self.cause.normalize(deep) if self.cause else res
            res = res and self.from_target.normalize(deep) if self.from_target else res
        new_kid: list[UniNode] = [self.gen_token(Tok.KW_RAISE)]
        if self.cause:
            new_kid.append(self.cause)
        if self.from_target:
            new_kid.append(self.gen_token(Tok.KW_FROM))
            new_kid.append(self.from_target)
        new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class AssertStmt(CodeBlockStmt):
    """AssertStmt node type for Jac Ast."""

    def __init__(
        self,
        condition: Expr,
        error_msg: Optional[Expr],
        kid: Sequence[UniNode],
    ) -> None:
        self.condition = condition
        self.error_msg = error_msg
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.condition.normalize(deep)
            res = res and self.error_msg.normalize(deep) if self.error_msg else res
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_ASSERT),
            self.condition,
        ]
        if self.error_msg:
            new_kid.append(self.gen_token(Tok.COMMA))
            new_kid.append(self.error_msg)
        new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class CheckStmt(CodeBlockStmt):
    """CheckStmt node type for Jac Ast."""

    def __init__(
        self,
        target: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.target.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_CHECK),
            self.target,
            self.gen_token(Tok.SEMI),
        ]
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.ctrl.normalize(deep)
        new_kid: list[UniNode] = [self.ctrl, self.gen_token(Tok.SEMI)]
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.target.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_DELETE),
            self.target,
            self.gen_token(Tok.SEMI),
        ]
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.expr.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_REPORT),
            self.expr,
            self.gen_token(Tok.SEMI),
        ]
        self.set_kids(nodes=new_kid)
        return res


class ReturnStmt(CodeBlockStmt):
    """ReturnStmt node type for Jac Ast."""

    def __init__(
        self,
        expr: Optional[Expr],
        kid: Sequence[UniNode],
    ) -> None:
        self.expr = expr
        UniNode.__init__(self, kid=kid)
        CodeBlockStmt.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.expr.normalize(deep) if self.expr else res
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_RETURN),
        ]
        if self.expr:
            new_kid.append(self.expr)
        new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class VisitStmt(WalkerStmtOnlyNode, AstElseBodyNode, CodeBlockStmt):
    """VisitStmt node type for Jac Ast."""

    def __init__(
        self,
        insert_loc: Optional[Expr],
        target: Expr,
        else_body: Optional[ElseStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.insert_loc = insert_loc
        self.target = target
        UniNode.__init__(self, kid=kid)
        WalkerStmtOnlyNode.__init__(self)
        AstElseBodyNode.__init__(self, else_body=else_body)
        CodeBlockStmt.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.insert_loc.normalize(deep) if self.insert_loc else res
            res = self.target.normalize(deep)
            res = res and self.else_body.normalize(deep) if self.else_body else res
        new_kid: list[UniNode] = []
        new_kid.append(self.gen_token(Tok.KW_VISIT))
        if self.insert_loc:
            new_kid.append(self.gen_token(Tok.COLON))
            new_kid.append(self.insert_loc)
            new_kid.append(self.gen_token(Tok.COLON))
        new_kid.append(self.target)
        if self.else_body:
            new_kid.append(self.else_body)
        else:
            new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        """Normalize disengage statement node."""
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_DISENGAGE),
            self.gen_token(Tok.SEMI),
        ]
        self.set_kids(nodes=new_kid)
        return True


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.target.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_AWAIT),
            self.target,
        ]
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for item in self.target:
                res = res and item.normalize(deep)
        new_kid: list[UniNode] = [self.gen_token(Tok.GLOBAL_OP)]
        for idx, item in enumerate(self.target):
            new_kid.append(item)
            if idx < len(self.target) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class NonLocalStmt(GlobalStmt):
    """NonLocalStmt node type for Jac Ast."""

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for item in self.target:
                res = res and item.normalize(deep)
        new_kid: list[UniNode] = [self.gen_token(Tok.NONLOCAL_OP)]
        for idx, item in enumerate(self.target):
            new_kid.append(item)
            if idx < len(self.target) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class Assignment(AstTypedVarNode, EnumBlockStmt, CodeBlockStmt):
    """Assignment node type for Jac Ast."""

    def __init__(
        self,
        target: Sequence[Expr],
        value: Optional[Expr | YieldExpr],
        type_tag: Optional[SubTag[Expr]],
        kid: Sequence[UniNode],
        mutable: bool = True,
        aug_op: Optional[Token] = None,
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

    def normalize(self, deep: bool = True) -> bool:
        res = True
        if deep:
            for t in self.target:
                res = res and t.normalize(deep)
            res = res and self.value.normalize(deep) if self.value else res
            res = res and self.type_tag.normalize(deep) if self.type_tag else res
            res = res and self.aug_op.normalize(deep) if self.aug_op else res
        new_kid: list[UniNode] = []
        for idx, targ in enumerate(self.target):
            new_kid.append(targ)
            if idx < len(self.target) - 1:
                new_kid.append(self.gen_token(Tok.EQ))
        if self.type_tag:
            new_kid.append(self.type_tag)
        if self.aug_op:
            new_kid.append(self.aug_op)
        if self.value:
            if not self.aug_op:
                new_kid.append(self.gen_token(Tok.EQ))
            new_kid.append(self.value)
        if isinstance(self.parent, GlobalVars):
            if self.parent.assignments.index(self) == len(self.parent.assignments) - 1:
                new_kid.append(self.gen_token(Tok.SEMI))
        elif (not self.is_enum_stmt) and not (
            isinstance(self.parent, IterForStmt)
            and self in [self.parent.iter, self.parent.count_by]
        ):
            new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class ConcurrentExpr(Expr):
    """ConcurrentExpr node type for Jac Ast."""

    def __init__(
        self,
        tok: Optional[Token],
        target: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        self.tok = tok
        self.target = target

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.target.normalize(deep)
            res = res and self.target.normalize(deep) if self.target else res
        new_kid: list[UniNode] = []
        if isinstance(self.tok, Token) and self.tok.value == "flow":
            new_kid.append(self.gen_token(Tok.KW_FLOW))
        elif isinstance(self.tok, Token) and self.tok.value == "wait":
            new_kid.append(self.gen_token(Tok.KW_WAIT))
        new_kid.append(self.target)
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.left.normalize(deep)
            res = res and self.right.normalize(deep) if self.right else res
            res = res and self.op.normalize(deep) if self.op else res
        new_kid: list[UniNode] = [self.left, self.op, self.right]
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.left.normalize(deep)
            for right in self.rights:
                res = res and right.normalize(deep)
            for op in self.ops:
                res = res and op.normalize(deep)
        new_kid: list[UniNode] = [self.left]
        for i, right in enumerate(self.rights):
            new_kid.append(self.ops[i])
            new_kid.append(right)
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for value in self.values:
                res = res and value.normalize(deep)
            res = res and self.op.normalize(deep) if self.op else res
        new_kid: list[UniNode] = []
        for i, value in enumerate(self.values):
            if i > 0:
                new_kid.append(self.op)
            new_kid.append(value)
        self.set_kids(nodes=new_kid)
        return res


class LambdaExpr(Expr, UniScopeNode):
    """LambdaExpr node type for Jac Ast."""

    def __init__(
        self,
        body: Expr,
        kid: Sequence[UniNode],
        signature: Optional[FuncSignature] = None,
    ) -> None:
        self.signature = signature
        self.body = body
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.signature.normalize(deep) if self.signature else res
            res = res and self.body.normalize(deep)
        new_kid: list[UniNode] = [self.gen_token(Tok.KW_LAMBDA)]
        if self.signature:
            new_kid.append(self.signature)
        new_kid += [self.gen_token(Tok.COLON), self.body]
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.operand.normalize(deep)
            res = res and self.op.normalize(deep) if self.op else res
        new_kid: list[UniNode] = [self.op, self.operand]
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.condition.normalize(deep)
            res = res and self.value.normalize(deep)
            res = res and self.else_value.normalize(deep)
        new_kid: list[UniNode] = [
            self.value,
            self.gen_token(Tok.KW_IF),
            self.condition,
            self.gen_token(Tok.KW_ELSE),
            self.else_value,
        ]
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for string in self.strings:
                res = res and string.normalize(deep)
        new_kid: list[UniNode] = []
        for string in self.strings:
            new_kid.append(string)
        self.set_kids(nodes=new_kid)
        return res


class FString(AtomExpr):
    """FString node type for Jac Ast."""

    def __init__(
        self,
        parts: Sequence[String | ExprStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.parts: list[String | ExprStmt] = list(parts)
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.STRING)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for part in self.parts:
                res = res and part.normalize(deep)
        new_kid: list[UniNode] = []
        is_single_quote = (
            isinstance(self.kid[0], Token) and self.kid[0].name == Tok.FSTR_SQ_START
        )
        if is_single_quote:
            new_kid.append(self.gen_token(Tok.FSTR_SQ_START))
        else:
            new_kid.append(self.gen_token(Tok.FSTR_START))
        for i in self.parts:
            if isinstance(i, String):
                i.value = (
                    "{{" if i.value == "{" else "}}" if i.value == "}" else i.value
                )
                new_kid.append(i)
            else:
                new_kid.append(self.gen_token(Tok.LBRACE))
                new_kid.append(i)
                new_kid.append(self.gen_token(Tok.RBRACE))
        if is_single_quote:
            new_kid.append(self.gen_token(Tok.FSTR_SQ_END))
        else:
            new_kid.append(self.gen_token(Tok.FSTR_END))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for i in self.values:
                res = res and i.normalize(deep)
        new_kid: list[UniNode] = [self.gen_token(Tok.LSQUARE)]
        for idx, val in enumerate(self.values):
            new_kid.append(val)
            if idx < len(self.values) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        new_kid.append(self.gen_token(Tok.RSQUARE))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for i in self.values:
                res = res and i.normalize(deep)
        new_kid: list[UniNode] = [self.gen_token(Tok.LBRACE)]
        for idx, val in enumerate(self.values):
            new_kid.append(val)
            if idx < len(self.values) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for i in self.values:
                res = res and i.normalize(deep)
        in_ret_type = (
            self.parent
            and isinstance(self.parent, IndexSlice)
            and self.parent
            and isinstance(self.parent.parent, AtomTrailer)
            and self.parent.parent
            and isinstance(self.parent.parent.parent, FuncSignature)
        )
        new_kid: list[UniNode] = (
            [
                self.gen_token(Tok.LPAREN),
            ]
            if not in_ret_type
            else []
        )
        for idx, i in enumerate(self.values):
            new_kid.append(i)
            if idx < len(self.values) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        if len(self.values) == 1:
            new_kid.append(self.gen_token(Tok.COMMA))
        if not in_ret_type:
            new_kid.append(self.gen_token(Tok.RPAREN))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for kv_pair in self.kv_pairs:
                res = res and kv_pair.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.LBRACE),
        ]
        for i, kv_pair in enumerate(self.kv_pairs):
            new_kid.append(kv_pair)
            if i < len(self.kv_pairs) - 1:
                new_kid.append(self.gen_token(Tok.COMMA))
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


class KVPair(UniNode):
    """KVPair node type for Jac Ast."""

    def __init__(
        self,
        key: Optional[Expr],  # is **key if blank
        value: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.key = key
        self.value = value
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.key.normalize(deep) if self.key else res
            res = res and self.value.normalize(deep)
        new_kid: list[UniNode] = []
        if self.key:
            new_kid.append(self.key)
            new_kid.append(self.gen_token(Tok.COLON))
        else:
            new_kid.append(self.gen_token(Tok.STAR_POW))
        new_kid.append(self.value)
        self.set_kids(nodes=new_kid)
        return res


class KWPair(UniNode):
    """KWPair node type for Jac Ast."""

    def __init__(
        self,
        key: Optional[NameAtom],  # is **value if blank
        value: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.key = key
        self.value = value
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.key.normalize(deep) if self.key else res
            res = res and self.value.normalize(deep)
        new_kid: list[UniNode] = []
        if self.key:
            new_kid.append(self.key)
            new_kid.append(self.gen_token(Tok.EQ))
        else:
            new_kid.append(self.gen_token(Tok.STAR_POW))
        new_kid.append(self.value)
        self.set_kids(nodes=new_kid)
        return res


class InnerCompr(AstAsyncNode, UniScopeNode):
    """InnerCompr node type for Jac Ast."""

    def __init__(
        self,
        is_async: bool,
        target: Expr,
        collection: Expr,
        conditional: Optional[list[Expr]],
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        self.collection = collection
        self.conditional = conditional
        UniNode.__init__(self, kid=kid)
        AstAsyncNode.__init__(self, is_async=is_async)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.target.normalize(deep)
            res = res and self.collection.normalize(deep)
            for cond in self.conditional if self.conditional else []:
                res = res and cond.normalize(deep)
        new_kid: list[UniNode] = []
        if self.is_async:
            new_kid.append(self.gen_token(Tok.KW_ASYNC))
        new_kid.append(self.gen_token(Tok.KW_FOR))
        new_kid.append(self.target)
        new_kid.append(self.gen_token(Tok.KW_IN))
        new_kid.append(self.collection)
        for cond in self.conditional if self.conditional else []:
            new_kid.append(self.gen_token(Tok.KW_IF))
            new_kid.append(cond)
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.out_expr.normalize(deep)
            for comp in self.compr:
                res = res and comp.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.LSQUARE),
            self.out_expr,
        ]
        for comp in self.compr:
            new_kid.append(comp)
        new_kid.append(self.gen_token(Tok.RSQUARE))
        self.set_kids(nodes=new_kid)
        return res


class GenCompr(ListCompr):
    """GenCompr node type for Jac Ast."""

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.out_expr.normalize(deep)
            for comp in self.compr:
                res = res and comp.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.LPAREN),
            self.out_expr,
        ]
        for comp in self.compr:
            new_kid.append(comp)
        new_kid.append(self.gen_token(Tok.RPAREN))
        self.set_kids(nodes=new_kid)
        return res


class SetCompr(ListCompr):
    """SetCompr node type for Jac Ast."""

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.out_expr.normalize(deep)
            for comp in self.compr:
                res = res and comp.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.LBRACE),
            self.out_expr,
        ]
        for comp in self.compr:
            new_kid.append(comp)
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        res = self.kv_pair.normalize(deep)
        for comp in self.compr:
            res = res and comp.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.LBRACE),
            self.kv_pair,
        ]
        for comp in self.compr:
            new_kid.append(comp)
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = True) -> bool:
        res = True
        if deep:
            res = self.target.normalize(deep)
            res = res and self.right.normalize(deep) if self.right else res
        new_kid: list[UniNode] = [self.target]
        if self.is_null_ok:
            new_kid.append(self.gen_token(Tok.NULL_OK))
        if self.is_attr:
            new_kid.append(self.gen_token(Tok.DOT))
        if self.right:
            new_kid.append(self.right)
        self.set_kids(nodes=new_kid)
        return res

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
        value: Expr | YieldExpr,
        kid: Sequence[UniNode],
    ) -> None:
        self.value = value
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)

    def normalize(self, deep: bool = True) -> bool:
        res = True
        if deep:
            res = self.value.normalize(deep)
        new_kid: list[UniNode] = []
        new_kid.append(self.gen_token(Tok.LPAREN))
        new_kid.append(self.value)
        new_kid.append(self.gen_token(Tok.RPAREN))
        self.set_kids(nodes=new_kid)
        return res


class YieldExpr(Expr):
    """YieldExpr node type for Jac Ast."""

    def __init__(
        self,
        expr: Optional[Expr],
        with_from: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.expr = expr
        self.with_from = with_from
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.expr.normalize(deep) if self.expr else res
        new_kid: list[UniNode] = [self.gen_token(Tok.KW_YIELD)]
        if self.with_from:
            new_kid.append(self.gen_token(Tok.KW_FROM))
        if self.expr:
            new_kid.append(self.expr)
        new_kid.append(self.gen_token(Tok.SEMI))
        self.set_kids(nodes=new_kid)
        return res


class FuncCall(Expr):
    """FuncCall node type for Jac Ast."""

    def __init__(
        self,
        target: Expr,
        params: Sequence[Expr | KWPair] | None,
        genai_call: Optional[Expr],
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        self.params = list(params) if params else []
        self.genai_call = genai_call
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)

    def normalize(self, deep: bool = True) -> bool:
        res = True
        if deep:
            res = self.target.normalize(deep)
            for prm in self.params:
                res = res and prm.normalize(deep)
        new_kids = [self.target, self.gen_token(Tok.LPAREN, "(")]
        for i, prm in enumerate(self.params):
            new_kids.append(prm)
            if i < len(self.params) - 1:
                new_kids.append(self.gen_token(Tok.COMMA))
        if self.genai_call:
            new_kids.append(self.gen_token(Tok.KW_BY))
            new_kids.append(self.genai_call)
        new_kids.append(self.gen_token(Tok.RPAREN, ")"))
        self.set_kids(nodes=new_kids)
        return res


class IndexSlice(AtomExpr):
    """IndexSlice node type for Jac Ast."""

    @dataclass
    class Slice:
        """Slice node type for Jac Ast."""

        start: Optional[Expr]
        stop: Optional[Expr]
        step: Optional[Expr]

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

    def normalize(self, deep: bool = True) -> bool:
        res = True
        if deep:
            for slice in self.slices:
                res = slice.start.normalize(deep) if slice.start else res
                res = res and slice.stop.normalize(deep) if slice.stop else res
                res = res and slice.step.normalize(deep) if slice.step else res
        new_kid: list[UniNode] = []
        new_kid.append(self.gen_token(Tok.LSQUARE))
        if self.is_range:
            for i, slice in enumerate(self.slices):
                if i > 0:
                    new_kid.append(self.gen_token(Tok.COMMA))
                if slice.start:
                    new_kid.append(slice.start)
                new_kid.append(self.gen_token(Tok.COLON))
                if slice.stop:
                    new_kid.append(slice.stop)
                if slice.step:
                    new_kid.append(self.gen_token(Tok.COLON))
                    new_kid.append(slice.step)
        elif len(self.slices) == 1 and self.slices[0].start:
            new_kid.append(self.slices[0].start)
        else:
            res = False
        new_kid.append(self.gen_token(Tok.RSQUARE))
        self.set_kids(nodes=new_kid)
        return res


class TypeRef(AtomExpr):
    """ArchRef node type for Jac Ast."""

    def __init__(
        self,
        target: NameAtom,
        kid: Sequence[UniNode],
    ) -> None:
        self.target = target
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolNode.__init__(
            self,
            sym_name=target.sym_name,
            name_spec=target,
            sym_category=SymbolType.TYPE,
        )

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.target.normalize(deep)
        new_kid: list[UniNode] = [self.gen_token(Tok.TYPE_OP), self.target]
        self.set_kids(nodes=new_kid)
        return res


class EdgeRefTrailer(Expr):
    """EdgeRefTrailer node type for Jac Ast."""

    def __init__(
        self,
        chain: list[Expr | FilterCompr],
        edges_only: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.chain = chain
        self.edges_only = edges_only
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)

    def normalize(self, deep: bool = True) -> bool:
        res = True
        for expr in self.chain:
            res = res and expr.normalize(deep)
        new_kid: list[UniNode] = []
        new_kid.append(self.gen_token(Tok.LSQUARE))
        if self.edges_only:
            new_kid.append(self.gen_token(Tok.KW_EDGE))
        new_kid.extend(self.chain)
        new_kid.append(self.gen_token(Tok.RSQUARE))
        self.set_kids(nodes=new_kid)
        return res


class EdgeOpRef(WalkerStmtOnlyNode, AtomExpr):
    """EdgeOpRef node type for Jac Ast."""

    def __init__(
        self,
        filter_cond: Optional[FilterCompr],
        edge_dir: EdgeDir,
        kid: Sequence[UniNode],
    ) -> None:
        self.filter_cond = filter_cond
        self.edge_dir = edge_dir
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        WalkerStmtOnlyNode.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.filter_cond.normalize(deep) if self.filter_cond else res
        new_kid: list[UniNode] = []
        if self.edge_dir == EdgeDir.IN:
            if not self.filter_cond:
                new_kid.append(self.gen_token(Tok.ARROW_L))
            else:
                new_kid.append(self.gen_token(Tok.ARROW_L_P1))
                new_kid.append(self.filter_cond)
                new_kid.append(self.gen_token(Tok.ARROW_L_P2))
        elif self.edge_dir == EdgeDir.OUT:
            if not self.filter_cond:
                new_kid.append(self.gen_token(Tok.ARROW_R))
            else:
                new_kid.append(self.gen_token(Tok.ARROW_R_P1))
                new_kid.append(self.filter_cond)
                new_kid.append(self.gen_token(Tok.ARROW_R_P2))
        else:
            if not self.filter_cond:
                new_kid.append(self.gen_token(Tok.ARROW_BI))
            else:
                new_kid.append(self.gen_token(Tok.ARROW_L_P1))
                new_kid.append(self.filter_cond)
                new_kid.append(self.gen_token(Tok.ARROW_R_P2))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.edge_spec.normalize(deep)
        new_kid: list[UniNode] = [self.gen_token(Tok.KW_DELETE), self.edge_spec]
        self.set_kids(nodes=new_kid)
        return res


class ConnectOp(UniNode):
    """ConnectOpRef node type for Jac Ast."""

    def __init__(
        self,
        conn_type: Optional[Expr],
        conn_assign: Optional[AssignCompr],
        edge_dir: EdgeDir,
        kid: Sequence[UniNode],
    ) -> None:
        self.conn_type = conn_type
        self.conn_assign = conn_assign
        self.edge_dir = edge_dir
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.conn_type.normalize(deep) if self.conn_type else res
            res = res and self.conn_assign.normalize(deep) if self.conn_assign else res
        new_kid: list[UniNode] = []
        if self.edge_dir == EdgeDir.IN:
            if not self.conn_assign and not self.conn_type:
                new_kid.append(self.gen_token(Tok.CARROW_L))
            else:
                new_kid.append(self.gen_token(Tok.CARROW_L_P1))
                if self.conn_type:
                    new_kid.append(self.conn_type)
                if self.conn_assign:
                    new_kid.append(self.gen_token(Tok.COLON))
                    new_kid.append(self.conn_assign)
                new_kid.append(self.gen_token(Tok.CARROW_L_P2))
        elif self.edge_dir == EdgeDir.OUT:
            if not self.conn_assign and not self.conn_type:
                new_kid.append(self.gen_token(Tok.CARROW_R))
            else:
                new_kid.append(self.gen_token(Tok.CARROW_R_P1))
                if self.conn_type:
                    new_kid.append(self.conn_type)
                if self.conn_assign:
                    new_kid.append(self.gen_token(Tok.COLON))
                    new_kid.append(self.conn_assign)
                new_kid.append(self.gen_token(Tok.CARROW_R_P2))
        else:
            if not self.conn_assign and not self.conn_type:
                new_kid.append(self.gen_token(Tok.CARROW_BI))
            else:
                new_kid.append(self.gen_token(Tok.CARROW_L_P1))
                if self.conn_type:
                    new_kid.append(self.conn_type)
                if self.conn_assign:
                    new_kid.append(self.gen_token(Tok.COLON))
                    new_kid.append(self.conn_assign)
                new_kid.append(self.gen_token(Tok.CARROW_R_P2))
        self.set_kids(nodes=new_kid)
        return res


class FilterCompr(AtomExpr):
    """FilterCompr node type for Jac Ast."""

    def __init__(
        self,
        f_type: Optional[Expr],
        compares: Sequence[CompareExpr],
        kid: Sequence[UniNode],
    ) -> None:
        self.f_type = f_type
        self.compares = list(compares)
        UniNode.__init__(self, kid=kid)
        Expr.__init__(self)
        AstSymbolStubNode.__init__(self, sym_type=SymbolType.SEQUENCE)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.f_type.normalize(deep) if self.f_type else res
            for comp in self.compares:
                res = res and comp.normalize(deep)
        new_kid: list[UniNode] = []
        if not isinstance(self.parent, EdgeOpRef):
            new_kid.append(self.gen_token(Tok.LPAREN))
            if self.f_type:
                new_kid.append(self.gen_token(Tok.TYPE_OP))
            new_kid.append(self.gen_token(Tok.NULL_OK))
        if self.f_type:
            new_kid.append(self.f_type)
        if self.compares:
            if self.f_type:
                new_kid.append(self.gen_token(Tok.COLON))
            for i, comp in enumerate(self.compares):
                new_kid.append(comp)
                if i < len(self.compares) - 1:
                    new_kid.append(self.gen_token(Tok.COMMA))
        if not isinstance(self.parent, EdgeOpRef):
            new_kid.append(self.gen_token(Tok.RPAREN))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for assign in self.assigns:
                res = res and assign.normalize(deep)
        new_kid: list[UniNode] = []
        if isinstance(self.parent, ConnectOp):
            for i, assign in enumerate(self.assigns):
                new_kid.append(assign)
                if i < len(self.assigns) - 1:
                    new_kid.append(self.gen_token(Tok.COMMA))
        else:
            new_kid.append(self.gen_token(Tok.LPAREN))
            new_kid.append(self.gen_token(Tok.EQ))
            for i, assign in enumerate(self.assigns):
                new_kid.append(assign)
                if i < len(self.assigns) - 1:
                    new_kid.append(self.gen_token(Tok.COMMA))
            new_kid.append(self.gen_token(Tok.RPAREN))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.target.normalize(deep)
            for case in self.cases:
                res = res and case.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.KW_MATCH),
            self.target,
        ]
        new_kid.append(self.gen_token(Tok.LBRACE))
        for case in self.cases:
            new_kid.append(case)
        new_kid.append(self.gen_token(Tok.RBRACE))

        self.set_kids(nodes=new_kid)
        return res


class MatchCase(UniScopeNode):
    """MatchCase node type for Jac Ast."""

    def __init__(
        self,
        pattern: MatchPattern,
        guard: Optional[Expr],
        body: list[CodeBlockStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.pattern = pattern
        self.guard = guard
        self.body = body
        UniNode.__init__(self, kid=kid)
        UniScopeNode.__init__(self, name=f"{self.__class__.__name__}")

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.pattern.normalize(deep)
            res = res and self.guard.normalize(deep) if self.guard else res
            for stmt in self.body:
                res = res and stmt.normalize(deep)
        new_kid: list[UniNode] = [self.gen_token(Tok.KW_CASE), self.pattern]
        if self.guard:
            new_kid.append(self.gen_token(Tok.KW_IF))
            new_kid.append(self.guard)
        new_kid.append(self.gen_token(Tok.COLON))
        if self.body:
            new_kid.extend([*self.body])
        self.set_kids(nodes=new_kid)
        return res


class MatchOr(MatchPattern):
    """MatchOr node type for Jac Ast."""

    def __init__(
        self,
        patterns: list[MatchPattern],
        kid: Sequence[UniNode],
    ) -> None:
        self.patterns = patterns
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for pattern in self.patterns:
                res = res and pattern.normalize(deep)
        new_kid: list[UniNode] = []
        for pattern in self.patterns:
            new_kid.append(pattern)
            new_kid.append(self.gen_token(Tok.KW_OR))
        new_kid.pop()
        self.set_kids(nodes=new_kid)
        return res


class MatchAs(MatchPattern):
    """MatchAs node type for Jac Ast."""

    def __init__(
        self,
        name: NameAtom,
        pattern: Optional[MatchPattern],
        kid: Sequence[UniNode],
    ) -> None:
        self.name = name
        self.pattern = pattern
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.name.normalize(deep)
            res = res and self.pattern.normalize(deep) if self.pattern else res
        new_kid: list[UniNode] = []
        if self.pattern:
            new_kid.append(self.pattern)
            new_kid.append(self.gen_token(Tok.KW_AS))
        new_kid.append(self.name)
        self.set_kids(nodes=new_kid)
        return res


class MatchWild(MatchPattern):
    """MatchWild node type for Jac Ast."""

    def normalize(self, deep: bool = False) -> bool:
        """Normalize match wild card node."""
        UniNode.set_kids(
            self,
            nodes=[
                Name(
                    orig_src=self.loc.orig_src,
                    name=Tok.NAME,
                    value="_",
                    col_start=self.loc.col_start,
                    col_end=self.loc.col_end,
                    line=self.loc.first_line,
                    end_line=self.loc.last_line,
                    pos_start=self.loc.pos_start,
                    pos_end=self.loc.pos_end,
                )
            ],
        )
        return True


class MatchValue(MatchPattern):
    """MatchValue node type for Jac Ast."""

    def __init__(
        self,
        value: Expr,
        kid: Sequence[UniNode],
    ) -> None:
        self.value = value
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.value.normalize(deep)
        self.set_kids(nodes=[self.value])
        return res


class MatchSingleton(MatchPattern):
    """MatchSingleton node type for Jac Ast."""

    def __init__(
        self,
        value: Bool | Null,
        kid: Sequence[UniNode],
    ) -> None:
        self.value = value
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        self.set_kids(nodes=[self.value])
        return res


class MatchSequence(MatchPattern):
    """MatchSequence node type for Jac Ast."""

    def __init__(
        self,
        values: list[MatchPattern],
        kid: Sequence[UniNode],
    ) -> None:
        self.values = values
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for value in self.values:
                res = res and value.normalize(deep)
        new_kid: list[UniNode] = [self.gen_token(Tok.LSQUARE)]
        for value in self.values:
            new_kid.append(value)
            new_kid.append(self.gen_token(Tok.COMMA))
        new_kid.pop()
        new_kid.append(self.gen_token(Tok.RSQUARE))
        self.set_kids(nodes=new_kid)
        return res


class MatchMapping(MatchPattern):
    """MatchMapping node type for Jac Ast."""

    def __init__(
        self,
        values: list[MatchKVPair | MatchStar],
        kid: Sequence[UniNode],
    ) -> None:
        self.values = values
        UniNode.__init__(self, kid=kid)

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            for value in self.values:
                res = res and value.normalize(deep)
        new_kid: list[UniNode] = [self.gen_token(Tok.LBRACE)]
        for value in self.values:
            new_kid.append(value)
            new_kid.append(self.gen_token(Tok.COMMA))
        new_kid.pop()
        new_kid.append(self.gen_token(Tok.RBRACE))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = (
                self.key.normalize(deep) if isinstance(self.key, MatchPattern) else True
            )
            res = res and self.value.normalize(deep)
        op = Tok.EQ if isinstance(self.key, Name) else Tok.COLON
        new_kid: list[UniNode] = [self.key, self.gen_token(op), self.value]
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.name.normalize(deep)
        new_kid: list[UniNode] = [
            self.gen_token(Tok.STAR_MUL if self.is_list else Tok.STAR_POW)
        ]
        new_kid.append(self.name)
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = False) -> bool:
        res = True
        if deep:
            res = self.name.normalize(deep)
            for arg in self.arg_patterns or []:
                res = res and arg.normalize(deep)
            for kw in self.kw_patterns or []:
                res = res and kw.normalize(deep)
        new_kid: list[UniNode] = [self.name]
        new_kid.append(self.gen_token(Tok.LPAREN))
        if self.arg_patterns:
            for idx, arg in enumerate(self.arg_patterns):
                new_kid.append(arg)
                if idx < len(self.arg_patterns) - 1:
                    new_kid.append(self.gen_token(Tok.COMMA))
            if self.kw_patterns:
                new_kid.append(self.gen_token(Tok.COMMA))
        if self.kw_patterns:
            for idx, kw in enumerate(self.kw_patterns):
                new_kid.append(kw)
                if idx < len(self.kw_patterns) - 1:
                    new_kid.append(self.gen_token(Tok.COMMA))
        new_kid.append(self.gen_token(Tok.RPAREN))
        self.set_kids(nodes=new_kid)
        return res


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

    def normalize(self, deep: bool = True) -> bool:
        return bool(self.value and self.name)

    def unparse(self) -> str:
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

    def unparse(self) -> str:
        super().unparse()
        return (f"<>{self.value}" if self.is_kwesc else self.value) + (
            ",\n" if self.is_enum_stmt else ""
        )

    @staticmethod
    def gen_stub_from_node(
        node: AstSymbolNode, name_str: str, set_name_of: Optional[AstSymbolNode] = None
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
            return self.value

    def normalize(self, deep: bool = True) -> bool:
        self.value = r"%s" % self.value
        return True

    def unparse(self) -> str:
        super().unparse()
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
    def left_node(self) -> Optional[UniNode]:
        if self.parent and (idx := self.parent.kid.index(self)) > 0:
            return self.parent.kid[idx - 1]
        return None

    @property
    def right_node(self) -> Optional[UniNode]:
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
