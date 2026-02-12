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
import from typing { TYPE_CHECKING, Any, Generic, TypeVar, cast }
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
    def init(self: UniNode, kid: Sequence[UniNode]) -> None {
        self.parent: (UniNode | None) = None;
        self.kid: list[UniNode] = [x.set_parent(self) for x in kid];
        self.__sub_node_tab: (dict[(type, list[UniNode])] | None) = None;
        self._in_mod_nodes: list[UniNode] = [];
        self._gen: (CodeGenTarget | None) = None;
        self.loc: CodeLocInfo = CodeLocInfo(*self.resolve_tok_range());
    }

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
    def _sub_node_tab(self: UniNode) -> dict[(type, list[UniNode])] {
        if (self.__sub_node_tab is None) {
            self.__sub_node_tab = {};
            self._construct_sub_node_tab();
        }
        return self.__sub_node_tab;
    }

    """Construct sub node table."""
    def _construct_sub_node_tab(self: UniNode) -> None {
        for i in self.kid {
            if not i {
                continue;
            }
            for (k, v) in i._sub_node_tab.items() {
                if (k in self.__sub_node_tab) {
                    self.__sub_node_tab[k].extend(v);
                } else {
                    self.__sub_node_tab[k] = copy(v);
                }
            }
            if (`type(i) in self.__sub_node_tab) {
                self.__sub_node_tab[`type(i)].append(i);
            } else {
                self.__sub_node_tab[`type(i)] = [i];
            }
        }
    }

    """Get symbol table."""
    @property
    def sym_tab(self: UniNode) -> UniScopeNode {
        return self
        if isinstance(self, UniScopeNode)
        else self.parent_of_type(UniScopeNode);
    }

    """Add kid left."""
    def add_kids_left(
        self: UniNode,
        nodes: Sequence[UniNode],
        pos_update: bool = True,
        parent_update: bool = False
    ) -> UniNode {
        self.kid = [*nodes, *self.kid];
        if pos_update {
            for i in nodes {
                i.parent = self;
            }
            self.loc.update_first_token(self.kid[0].loc.first_tok);
        } elif parent_update {
            for i in nodes {
                i.parent = self;
            }
        }
        return self;
    }

    """Add kid right."""
    def add_kids_right(
        self: UniNode,
        nodes: Sequence[UniNode],
        pos_update: bool = True,
        parent_update: bool = False
    ) -> UniNode {
        self.kid = [*self.kid, *nodes];
        if pos_update {
            for i in nodes {
                i.parent = self;
            }
            self.loc.update_last_token(self.kid[-1].loc.last_tok);
        } elif parent_update {
            for i in nodes {
                i.parent = self;
            }
        }
        return self;
    }

    """Insert kids at position."""
    def insert_kids_at_pos(
        self: UniNode, nodes: Sequence[UniNode], pos: int, pos_update: bool = True
    ) -> UniNode {
        self.kid = [*self.kid[:pos], *nodes, *self.kid[pos:]];
        if pos_update {
            for i in nodes {
                i.parent = self;
            }
            self.loc.update_token_range(*self.resolve_tok_range());
        }
        return self;
    }

    """Set kids."""
    def set_kids(self: UniNode, nodes: Sequence[UniNode]) -> UniNode {
        self.kid = [*nodes];
        for i in nodes {
            i.parent = self;
        }
        self.loc.update_token_range(*self.resolve_tok_range());
        return self;
    }

    """Set parent."""
    def set_parent(self: UniNode, parent: UniNode) -> UniNode {
        self.parent = parent;
        return self;
    }

    def resolve_tok_range(self: UniNode) -> tuple[(Token, Token)] {
        if len(self.kid) {
            return (self.kid[0].loc.first_tok, self.kid[-1].loc.last_tok);
        } elif isinstance(self, Token) {
            return (self, self);
        } else {
            raise ValueError(f"Empty kid for Token {type(self).__name__}") ;
        }
    }

    def gen_token(self: UniNode, name: Tok, value: (str | None) = None) -> Token {
        import from jaclang.jac0core.jac_parser { TOKEN_MAP }
        value = value
        or (
            DELIM_MAP[name]
            if (name in DELIM_MAP)
            else TOKEN_MAP.get(name.value, name.value)
        );
        return Token(
            name=name,
            value=value,
            orig_src=self.loc.orig_src,
            col_start=self.loc.col_start,
            col_end=0,
            line=self.loc.first_line,
            end_line=self.loc.last_line,
            pos_start=0,
            pos_end=0
        );
    }

    """Get all sub nodes of type."""
    def get_all_sub_nodes(
        self: UniNode, typ: type[T], brute_force: bool = True
    ) -> list[T] {
        import from jaclang.jac0core.passes { UniPass }
        return UniPass.get_all_sub_nodes(`node=self, typ=typ, brute_force=brute_force);
    }

    """Get parent of type."""
    def find_parent_of_type(self: UniNode, typ: type[T]) -> (T | None) {
        import from jaclang.jac0core.passes { UniPass }
        return UniPass.find_parent_of_type(`node=self, typ=typ);
    }

    def parent_of_type(self: UniNode, typ: type[T]) -> T {
        ret = self.find_parent_of_type(typ);
        if isinstance(ret, typ) {
            return ret;
        } else {
            raise ValueError(f"Parent of type {typ} not found from{type(self)}.") ;
        }
    }

    """Check if this node is in a client-side context.

        This covers:
        - Nodes inside an explicit cl {} block in a .jac file
        - Nodes inside a function marked with CLIENT context in .cl.jac files
        - Overridden by sv {} blocks (server takes precedence)

        Uses single traversal for efficiency since this is called frequently.
        """
    def in_client_context(self: UniNode) -> bool {
        `node: (UniNode | None) = self.parent;
        while (`node is not None) {
            if isinstance(`node, ServerBlock) {
                return False;
            }
            if isinstance(`node, ClientBlock) {
                return True;
            }
            if isinstance(`node, Ability) {
                context = getattr(`node, 'code_context', CodeContext.SERVER);
                if (context == CodeContext.CLIENT) {
                    return True;
                }
            }
            `node = `node.parent;
        }
        return False;
    }

    """Check if this node is in a native context.

        This covers:
        - Nodes inside an explicit na {} block in a .jac file
        - Nodes inside a function marked with NATIVE context in .na.jac files
        - Overridden by sv {} or cl {} blocks
        """
    def in_native_context(self: UniNode) -> bool {
        `node: (UniNode | None) = self.parent;
        while (`node is not None) {
            if isinstance(`node, (ServerBlock, ClientBlock)) {
                return False;
            }
            if isinstance(`node, NativeBlock) {
                return True;
            }
            if isinstance(`node, Ability) {
                context = getattr(`node, 'code_context', CodeContext.SERVER);
                if (context == CodeContext.NATIVE) {
                    return True;
                }
            }
            `node = `node.parent;
        }
        return False;
    }

    """Return dict representation of node."""
    def to_dict(self: UniNode) -> dict[(str, str)] {
        ret = {
            'node': str(`type(self).__name__),
            'kid': str(
                [
                    x.to_dict()
                    for x in self.kid
                    if x
                ]
            ),
            'line': str(self.loc.first_line),
            'col': str(self.loc.col_start)
        };
        if isinstance(self, Token) {
            ret['name'] = self.name;
            ret['value'] = self.value;
        }
        return ret;
    }

    """Print ast."""
    def pp(self: UniNode, depth: (int | None) = None) -> str {
        return print_ast_tree(self, max_depth=depth);
    }

    """Print ast."""
    def printgraph(self: UniNode) -> str {
        return printgraph_ast_tree(self);
    }

    """Flatten ast."""
    def flatten(self: UniNode) -> list[UniNode] {
        ret: list[UniNode] = [self];
        for k in self.kid {
            ret += k.flatten();
        }
        return ret;
    }

    def unparse(self: UniNode) -> str {
        if self.gen.jac {
            return self.gen.jac;
        }
        return ' '.join([i.unparse() for i in self.kid]);
    }
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
    ) -> None {
        self.defn: list[NameAtom] = [defn];
        self.uses: list[NameAtom] = [];
        self.imported: bool = imported;
        defn.sym = self;
        self.access: SymbolAccess = access;
        self.parent_tab = parent_tab;
        self.semstr: str = '';
    }

    """Get decl."""
    @property
    def decl(self: Symbol) -> NameAtom {
        return self.defn[0];
    }

    """Get name."""
    @property
    def sym_name(self: Symbol) -> str {
        return self.decl.sym_name;
    }

    """Get sym_type."""
    @property
    def sym_type(self: Symbol) -> SymbolType {
        return self.decl.sym_category;
    }

    """Return a full path of the symbol."""
    @property
    def sym_dotted_name(self: Symbol) -> str {
        out = [self.defn[0].sym_name];
        current_tab: (UniScopeNode | None) = self.parent_tab;
        while (current_tab is not None) {
            out.append(current_tab.scope_name);
            current_tab = current_tab.parent_scope;
        }
        out.reverse();
        return '.'.join(out);
    }

    """Get symbol table."""
    @property
    def symbol_table(self: Symbol) -> (UniScopeNode | None) {
        if self.parent_tab {
            return self.parent_tab.find_scope(self.sym_name);
        }
        return None;
    }

    """Add defn."""
    def add_defn(self: Symbol, `node: NameAtom) -> None {
        self.defn.append(`node);
        `node.sym = self;
    }

    """Add use."""
    def add_use(self: Symbol, `node: NameAtom) -> None {
        self.uses.append(`node);
        `node.sym = self;
    }

    """Repr."""
    def __repr__(self: Symbol) -> str {
        return f"Symbol({self.sym_name}, {self.sym_type}, {self.access},{self.defn})";
    }
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
    ) -> None {
        self.scope_name = name;
        self.parent_scope = parent_scope;
        self.kid_scope: list[UniScopeNode] = [];
        self.names_in_scope: dict[(str, Symbol)] = {};
        self.names_in_scope_overload: dict[(str, list[Symbol])] = {};
        self.inherited_scope: list[InheritedSymbolTable] = [];
    }

    """Get type."""
    def get_type(self: UniScopeNode) -> SymbolType {
        if isinstance(self, AstSymbolNode) {
            return self.sym_category;
        }
        return SymbolType.VAR;
    }

    """Get parent."""
    def get_parent(self: UniScopeNode) -> (UniScopeNode | None) {
        return self.parent_scope;
    }

    static def get_python_scoping_nodes -> tuple[(type[UniScopeNode], ...)] {
        return (Module, Enum, Archetype, Ability, ImplDef, Test);
    }

    """Lookup a variable in the symbol table."""
    def lookup(
        self: UniScopeNode,
        name: str,
        deep: bool = True,
        incl_inner_scope: bool = False
    ) -> (Symbol | None) {
        if (name in self.names_in_scope) {
            return self.names_in_scope[name];
        }
        if (
            (deep and self.parent_scope)
            and (sym := self.parent_scope.lookup(name, deep))
        ) {
            return sym;
        }
        if incl_inner_scope {
            for kid in self.kid_scope {
                if isinstance(kid, UniScopeNode.get_python_scoping_nodes()) {
                    continue;
                }
                if ((sym := kid.lookup(name, False, True)) is not None) {
                    return sym;
                }
            }
        }
        return None;
    }

    """Set a variable in the symbol table.

        Returns original symbol as collision if single check fails, none
otherwise.
        Also updates node.sym to create pointer to symbol.
        """
    def insert(
        self: UniScopeNode,
        `node: AstSymbolNode,
        access_spec: AstAccessNode | None | SymbolAccess = None,
        single: bool = False,
        force_overwrite: bool = False,
        imported: bool = False
    ) -> (UniNode | None) {
        collision = self.names_in_scope[`node.sym_name].defn[-1]
        if (single and (`node.sym_name in self.names_in_scope))
        else None;
        symbol = `node.name_spec.create_symbol(
            access=access_spec
            if isinstance(access_spec, SymbolAccess)
            else access_spec.access_type if access_spec else SymbolAccess.PUBLIC,
            parent_tab=self,
            imported=imported
        );
        if (`node.sym_name in self.names_in_scope) {
            self.names_in_scope_overload.setdefault(`node.sym_name, []).append(symbol);
        }
        if (force_overwrite or (`node.sym_name not in self.names_in_scope)) {
            self.names_in_scope[`node.sym_name] = symbol;
        } else {
            self.names_in_scope[`node.sym_name].add_defn(`node.name_spec);
        }
        `node.name_spec.sym = self.names_in_scope[`node.sym_name];
        return collision;
    }

    """Find a scope in the symbol table."""
    def find_scope(self: UniScopeNode, name: str) -> (UniScopeNode | None) {
        for k in self.kid_scope {
            if (k.scope_name == name) {
                return k;
            }
        }
        return None;
    }

    """Push a new scope onto the symbol table."""
    def link_kid_scope(self: UniScopeNode, key_node: UniScopeNode) -> UniScopeNode {
        key_node.parent_scope = self;
        self.kid_scope.append(key_node);
        return self.kid_scope[-1];
    }

    """Inherit symbol table."""
    def inherit_sym_tab(self: UniScopeNode, target_sym_tab: UniScopeNode) -> None {
        for i in target_sym_tab.names_in_scope.values() {
            self.def_insert(i.decl, access_spec=i.access);
        }
    }

    """Insert into symbol table."""
    def def_insert(
        self: UniScopeNode,
        `node: AstSymbolNode,
        access_spec: AstAccessNode | None | SymbolAccess = None,
        single_decl: (str | None) = None,
        force_overwrite: bool = False,
        imported: bool = False
    ) -> (Symbol | None) {
        if (`node.sym and (self == `node.sym.parent_tab)) {
            return `node.sym;
        }
        self.insert(
            `node=`node,
            single=(single_decl is not None),
            access_spec=access_spec,
            force_overwrite=force_overwrite,
            imported=imported
        );
        self.update_py_ctx_for_def(`node);
        return `node.sym;
    }

    """Link chain of containing names to symbol."""
    def chain_def_insert(self: UniScopeNode, node_list: list[AstSymbolNode]) -> None {
        if not node_list {
            return;
        }
        cur_sym_tab: (UniScopeNode | None) = node_list[0].sym_tab;
        node_list[-1].name_spec.py_ctx_func = ast3.Store;
        if isinstance(node_list[-1].name_spec, AstSymbolNode) {
            node_list[-1].name_spec.py_ctx_func = ast3.Store;
        }
        node_list = node_list[:-1];
        for i in node_list {
            cur_sym_tab = lookup.decl.sym_tab
            if (lookup := self.use_lookup(i, sym_table=cur_sym_tab))
            else None;
        }
    }

    """Link to symbol."""
    def use_lookup(
        self: UniScopeNode,
        `node: AstSymbolNode,
        sym_table: (UniScopeNode | None) = None
    ) -> (Symbol | None) {
        if `node.sym {
            return `node.sym;
        }
        if not sym_table {
            sym_table = `node.sym_tab;
        }
        if sym_table {
            lookup = sym_table.lookup(name=`node.sym_name, deep=True);
            lookup.add_use(`node.name_spec) if lookup else None;
        }
        return `node.sym;
    }

    """Link chain of containing names to symbol."""
    def chain_use_lookup(
        self: UniScopeNode, node_list: Sequence[AstSymbolNode]
    ) -> None {
        if not node_list {
            return;
        }
        cur_sym_tab: (UniScopeNode | None) = node_list[0].sym_tab;
        for i in node_list {
            if (cur_sym_tab is None) {
                break;
            }
            lookup = self.use_lookup(i, sym_table=cur_sym_tab);
            if lookup {
                cur_sym_tab = lookup.decl.sym_tab;
                if (cur_sym_tab.scope_name != i.sym_name) {
                    t = cur_sym_tab.find_scope(i.sym_name);
                    if t {
                        cur_sym_tab = t;
                    }
                }
            } else {
                cur_sym_tab = None;
            }
        }
    }

    """Update python context for definition."""
    def update_py_ctx_for_def(self: UniScopeNode, `node: AstSymbolNode) -> None {
        `node.name_spec.py_ctx_func = ast3.Store;
        if (isinstance(`node, (TupleVal, ListVal)) and `node.values) {
            def fix(item: TupleVal | ListVal | UnaryExpr) -> None {
                if isinstance(item, UnaryExpr) {
                    if isinstance(item.operand, AstSymbolNode) {
                        item.operand.name_spec.py_ctx_func = ast3.Store;
                    }
                } elif isinstance(item, (TupleVal, ListVal)) {
                    for i in item.values {
                        if isinstance(i, AstSymbolNode) {
                            i.name_spec.py_ctx_func = ast3.Store;
                        } elif isinstance(i, AtomTrailer) {
                            self.chain_def_insert(i.as_attr_list);
                        }
                        if isinstance(i, (TupleVal, ListVal, UnaryExpr)) {
                            fix(i);
                        }
                    }
                }
            }
            fix(`node);
        }
    }

    """Pretty print."""
    def sym_pp(self: UniScopeNode, depth: (int | None) = None) -> str {
        return print_symtab_tree(`root=self, depth=depth);
    }

    """Generate dot graph for sym table."""
    def sym_printgraph(self: UniScopeNode) -> str {
        return printgraph_symtab_tree(self);
    }

    """Repr."""
    def __repr__(self: UniScopeNode) -> str {
        out = f"{self.scope_name} {super.__repr__()}:\n";
        for (k, v) in self.names_in_scope.items() {
            out += f"    {k}: {v}\n";
        }
        return out;
    }
}

"""Nodes that have link to a symbol in symbol table."""
class AstSymbolNode(UniNode) {
    def init(
        self: AstSymbolNode,
        sym_name: str,
        name_spec: NameAtom,
        sym_category: SymbolType
    ) -> None {
        self.name_spec = name_spec;
        self.name_spec.name_of = self;
        self.name_spec._sym_name = sym_name;
        self.name_spec._sym_category = sym_category;
        self.semstr = '';
    }

    @property
    def sym(self: AstSymbolNode) -> (Symbol | None) {
        return self.name_spec.sym;
    }

    @property
    def sym_name(self: AstSymbolNode) -> str {
        return self.name_spec.sym_name;
    }

    @property
    def sym_category(self: AstSymbolNode) -> SymbolType {
        return self.name_spec.sym_category;
    }

    @property
    def py_ctx_func(self: AstSymbolNode) -> type[ast3.AST] {
        return self.name_spec.py_ctx_func;
    }

    @property
    def expr_type(self: AstSymbolNode) -> str {
        return self.name_spec.expr_type;
    }

    """Get type symbol table."""
    @property
    def type_sym_tab(self: AstSymbolNode) -> (UniScopeNode | None) {
        return self.name_spec.type_sym_tab;
    }
}

"""Nodes that have link to a symbol in symbol table."""
class AstSymbolStubNode(AstSymbolNode) {
    def init(self: AstSymbolStubNode, sym_type: SymbolType) -> None {
        AstSymbolNode.init(
            self,
            sym_name=f"[{self.__class__.__name__}]",
            name_spec=Name.gen_stub_from_node(self, f"[{self.__class__.__name__}]"),
            sym_category=sym_type
        );
    }
}

"""Nodes that have access."""
class AstAccessNode(UniNode) {
    def init(self: AstAccessNode, access: (SubTag[Token] | None)) -> None {
        self.access: (SubTag[Token] | None) = access;
    }

    @property
    def access_type(self: AstAccessNode) -> SymbolAccess {
        return SymbolAccess.PRIVATE
        if (self.access and (self.access.tag.name == Tok.KW_PRIV))
        else SymbolAccess.PROTECTED
        if (self.access and (self.access.tag.name == Tok.KW_PROT))
        else SymbolAccess.PUBLIC;
    }

    @property
    def public_access(self: AstAccessNode) -> bool {
        return (self.access_type == SymbolAccess.PUBLIC);
    }
}

glob T = TypeVar('T', bound=UniNode);
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
    ) -> None {
        self.code_context = code_context;
    }

    """Return the original context token (cl or sv) if present on this node."""
    def _source_context_token(self: ContextAwareNode) -> (Token | None) {
        for kid in self.kid {
            if (
                isinstance(kid, Token) and (kid.name in (Tok.KW_CLIENT, Tok.KW_SERVER))
            ) {
                return kid;
            }
        }
        return None;
    }
}

"""Nodes that have access."""
class AstDocNode(UniNode) {
    def init(self: AstDocNode, doc: (String | None)) -> None {
        self.doc: (String | None) = doc;
    }
}

"""Nodes that have access."""
class AstAsyncNode(UniNode) {
    def init(self: AstAsyncNode, is_async: bool) -> None {
        self.is_async: bool = is_async;
    }
}

"""Nodes that have access."""
class AstElseBodyNode(UniNode) {
    def init(self: AstElseBodyNode, else_body: ElseStmt | ElseIf | None) -> None {
        self.else_body: ElseStmt | ElseIf | None = else_body;
    }
}

"""Nodes that have access."""
class AstTypedVarNode(UniNode) {
    def init(self: AstTypedVarNode, type_tag: (SubTag[Expr] | None)) -> None {
        self.type_tag: (SubTag[Expr] | None) = type_tag;
    }
}

"""WalkerStmtOnlyNode node type for Jac Ast."""
class WalkerStmtOnlyNode(UniNode) {
    def init(self: WalkerStmtOnlyNode) -> None {
        self.from_walker: bool = False;
    }
}

"""BasicBlockStmt node type for Jac Uniir."""
class UniCFGNode(UniNode) {
    """Initialize basic block statement node."""
    def init(self: UniCFGNode) -> None {
        self.bb_in: list[UniCFGNode] = [];
        self.bb_out: list[UniCFGNode] = [];
    }

    """Get head by walking up the CFG iteratively."""
    def get_head(self: UniCFGNode) -> UniCFGNode {
        `node = self;
        while (
            `node.bb_in
            and (len(`node.bb_in) == 1)
            and not isinstance(`node.bb_in[0], (InForStmt, IterForStmt, WhileStmt))
            and `node.bb_in[0].bb_out
            and (len(`node.bb_in[0].bb_out) == 1)
        ) {
            `node = `node.bb_in[0];
        }
        return `node;
    }

    """Get tail by walking down the CFG iteratively."""
    def get_tail(self: UniCFGNode) -> UniCFGNode {
        `node = self;
        while (
            `node.bb_out
            and (len(`node.bb_out) == 1)
            and not isinstance(`node.bb_out[0], (InForStmt, IterForStmt, WhileStmt))
            and `node.bb_out[0].bb_in
            and (len(`node.bb_out[0].bb_in) == 1)
        ) {
            `node = `node.bb_out[0];
        }
        return `node;
    }
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
    def init(self: Expr) -> None {
        self._sym_type: str = 'NoType';
        self._type_sym_tab: (UniScopeNode | None) = None;
        self.type: (TypeBase | None) = None;
        self.attached_tokens: (list[Token] | None) = None;
    }

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
    def init(self: EnumBlockStmt, is_enum_stmt: bool) -> None {
        self.is_enum_stmt = is_enum_stmt;
    }
}

"""CodeBlockStmt node type for Jac Ast."""
class CodeBlockStmt(UniCFGNode) {
    """Initialize code block statement node."""
    def init(self: CodeBlockStmt) -> None {
        UniCFGNode.init(self);
    }
}

"""AstImplNeedingNode node type for Jac Ast."""
class AstImplNeedingNode(AstSymbolNode, Generic[T]) {
    def init(self: AstImplNeedingNode, body: (T | None)) -> None {
        self.body = body;
    }

    @property
    def needs_impl(self: AstImplNeedingNode) -> bool {
        return (self.body is None);
    }
}

"""NameAtom node type for Jac Ast."""
class NameAtom(AtomExpr, EnumBlockStmt) {
    def init(self: NameAtom, is_enum_stmt: bool) -> None {
        self.name_of: AstSymbolNode = self;
        self._sym: (Symbol | None) = None;
        self._sym_name: str = '';
        self._sym_category: SymbolType = SymbolType.UNKNOWN;
        self._py_ctx_func: type[ast3.expr_context] = ast3.Load;
        AtomExpr.init(self);
        EnumBlockStmt.init(self, is_enum_stmt=is_enum_stmt);
    }

    @property
    def sym(self: NameAtom) -> (Symbol | None) {
        return self._sym;
    }

    @sym.setter
    def sym(self: NameAtom, sym: Symbol) -> None {
        self._sym = sym;
    }

    @property
    def sym_name(self: NameAtom) -> str {
        return self._sym_name;
    }

    @property
    def sym_category(self: NameAtom) -> SymbolType {
        return self._sym_category;
    }

    """Create symbol."""
    def create_symbol(
        self: NameAtom,
        access: SymbolAccess,
        parent_tab: (UniScopeNode | None) = None,
        imported: bool = False
    ) -> Symbol {
        sym = Symbol(
            defn=self, access=access, parent_tab=parent_tab, imported=imported
        );
        return sym;
    }

    @property
    def clean_type(self: NameAtom) -> str {
        ret_type = self.expr_type.replace('builtins.', '').replace('NoType', '');
        return ret_type;
    }

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
    def sem_token(self: NameAtom) -> (tuple[(SemTokType, SemTokMod)] | None) {
        if isinstance(self.name_of, BuiltinType) {
            return (SemTokType.CLASS, SemTokMod.DECLARATION);
        }
        name_of = self.sym.decl.name_of
        if (self.sym and not isinstance(self.sym.decl.name_of, Name))
        else self.name_of;
        if isinstance(name_of, ModulePath) {
            return (SemTokType.NAMESPACE, SemTokMod.DEFINITION);
        }
        if isinstance(name_of, Archetype) {
            return (SemTokType.CLASS, SemTokMod.DECLARATION);
        }
        if isinstance(name_of, Enum) {
            return (SemTokType.ENUM, SemTokMod.DECLARATION);
        }
        if (isinstance(name_of, Ability) and name_of.is_method) {
            return (SemTokType.METHOD, SemTokMod.DECLARATION);
        }
        if isinstance(name_of, (Ability, Test)) {
            return (SemTokType.FUNCTION, SemTokMod.DECLARATION);
        }
        if isinstance(name_of, ParamVar) {
            return (SemTokType.PARAMETER, SemTokMod.DECLARATION);
        }
        if (self.sym and self.sym_name.isupper()) {
            return (SemTokType.VARIABLE, SemTokMod.READONLY);
        }
        if (
            self.sym
            and (self.sym.decl.name_of == self.sym.decl)
            and (self.sym_name in dir(builtins))
            and callable(getattr(builtins, self.sym_name))
        ) {
            return (SemTokType.FUNCTION, SemTokMod.DEFINITION);
        }
        if self.sym {
            return (SemTokType.PROPERTY, SemTokMod.DEFINITION);
        }
        return None;
    }
}

"""ArchSpec node type for Jac Ast."""
class ArchSpec(ElementStmt, CodeBlockStmt, AstSymbolNode, AstAsyncNode, AstDocNode) {
    def init(
        self: ArchSpec, decorators: (Sequence[Expr] | None), is_async: bool = False
    ) -> None {
        self.decorators = decorators;
        CodeBlockStmt.init(self);
        AstAsyncNode.init(self, is_async=is_async);
    }
}

"""MatchPattern node type for Jac Ast."""
class MatchPattern(UniNode) {}

"""SubTag node type for Jac Ast."""
class SubTag(UniNode, Generic[T]) {
    def init(self: SubTag, tag: T, kid: Sequence[UniNode]) -> None {
        self.tag: T = tag;
        UniNode.init(self, kid=kid);
    }
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
    ) -> None {
        self.name = name;
        self.source = source;
        self.body = body;
        self.stub_only = stub_only;
        self.impl_mod: list[Module] = [];
        self.test_mod: list[Module] = [];
        self.src_terminals: list[Token] = terminals;
        self.is_raised_from_py: bool = False;
        self.has_syntax_errors: bool = False;
        UniNode.init(self, kid=kid);
        AstDocNode.init(self, doc=doc);
        UniScopeNode.init(self, name=self.name);
    }

    """Get the base module path that this annex file belongs to.

        Uses discover_base_file to find the base .jac file for annex files
        (.impl.jac, .test.jac). Handles all discovery scenarios:
        - Same directory: foo.impl.jac -> foo.jac
        - Module-specific folder: foo.impl/bar.impl.jac -> foo.jac
        - Shared folder: impl/foo.impl.jac -> foo.jac
        """
    @property
    def annexable_by(self: Module) -> (str | None) {
        if self.stub_only {
            return None;
        }
        return discover_base_file(self.loc.mod_path);
    }

    """Get all sub nodes of type."""
    def format(self: Module) -> str {
        import from jaclang.compiler.passes.tool.doc_ir_gen_pass { DocIRGenPass }
        import from jaclang.compiler.passes.tool.jac_formatter_pass { JacFormatPass }
        import from jaclang.jac0core.program { JacProgram }
        return JacFormatPass(
            ir_in=DocIRGenPass(ir_in=self, prog=JacProgram()).ir_out, prog=JacProgram()
        ).ir_out.gen.jac;
    }

    def unparse(self: Module, requires_format: bool = True) -> str {
        import from jaclang.compiler.passes.tool.normalize_pass { NormalizePass }
        import from jaclang.jac0core.program { JacProgram }
        NormalizePass(ir_in=self, prog=JacProgram());
        if requires_format {
            return self.format();
        }
        import from jaclang.compiler.passes.tool.unparse_pass { UnparsePass }
        UnparsePass(ir_in=self, prog=JacProgram());
        return self.gen.jac;
    }

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
    static def get_href_path(`node: UniNode) -> str {
        parent = `node.find_parent_of_type(Module);
        mod_list: list[(Module | Archetype)] = [];
        if isinstance(`node, (Module, Archetype)) {
            mod_list.append(`node);
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
    def init(self: ProgramModule, main_mod: (Module | None) = None) -> None {
        self.main = main_mod or Module.make_stub();
        UniNode.init(self, kid=[self.main]);
        self.hub: dict[(str, Module)] = {self.loc.mod_path: main_mod}
        if main_mod
        else {};
    }
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
    ) -> None {
        self.assignments = assignments;
        self.is_frozen = is_frozen;
        UniNode.init(self, kid=kid);
        AstAccessNode.init(self, access=access);
        AstDocNode.init(self, doc=doc);
        ContextAwareNode.init(self);
    }
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
        doc: (String | None) = None
    ) -> None {
        Test.TEST_COUNT += 1 if isinstance(name, Token) else 0;
        self.name: Name = name
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
            pos_end=name.pos_end
        );
        self.name.parent = self;
        self.name._sym_name = f"test_{self.name.value}"
        if not self.name.value.startswith('test_')
        else self.name.value;
        self.body: list[CodeBlockStmt] = `list(body);
        UniNode.init(self, kid=kid);
        if (self.name not in self.kid) {
            self.insert_kids_at_pos([self.name], pos=1, pos_update=False);
        }
        AstSymbolNode.init(
            self,
            sym_name=self.name.sym_name,
            name_spec=self.name,
            sym_category=SymbolType.TEST
        );
        AstDocNode.init(self, doc=doc);
        UniScopeNode.init(self, name=self.sym_name);
        ContextAwareNode.init(self);
    }
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
    ) -> None {
        self.name = name;
        self.body = body;
        UniNode.init(self, kid=kid);
        AstDocNode.init(self, doc=doc);
        EnumBlockStmt.init(self, is_enum_stmt=is_enum_stmt);
        ContextAwareNode.init(self);
    }
}

"""ClientBlock node type for cl { ... } blocks in Jac Ast."""
class ClientBlock(ElementStmt) {
    def init(
        self: ClientBlock,
        body: Sequence[ElementStmt],
        kid: Sequence[UniNode],
        implicit: bool = False
    ) -> None {
        self.body = `list(body);
        self.implicit = implicit;
        UniNode.init(self, kid=kid);
    }
}

"""ServerBlock node type for sv { ... } blocks in Jac Ast."""
class ServerBlock(ElementStmt) {
    def init(
        self: ServerBlock,
        body: Sequence[ElementStmt],
        kid: Sequence[UniNode],
        implicit: bool = False
    ) -> None {
        self.body = `list(body);
        self.implicit = implicit;
        UniNode.init(self, kid=kid);
    }
}

"""NativeBlock node type for na { ... } blocks in Jac Ast."""
class NativeBlock(ElementStmt) {
    def init(
        self: NativeBlock,
        body: Sequence[ElementStmt],
        kid: Sequence[UniNode],
        implicit: bool = False
    ) -> None {
        self.body = `list(body);
        self.implicit = implicit;
        UniNode.init(self, kid=kid);
    }
}

"""PyInlineCode node type for Jac Ast."""
class PyInlineCode(ElementStmt, ArchBlockStmt, EnumBlockStmt, CodeBlockStmt) {
    def init(
        self: PyInlineCode,
        code: Token,
        kid: Sequence[UniNode],
        is_enum_stmt: bool = False,
        doc: (String | None) = None
    ) -> None {
        self.code = code;
        UniNode.init(self, kid=kid);
        AstDocNode.init(self, doc=doc);
        CodeBlockStmt.init(self);
        EnumBlockStmt.init(self, is_enum_stmt=is_enum_stmt);
    }
}

"""Import node type for Jac Ast."""
class Import(ContextAwareNode, ElementStmt, CodeBlockStmt) {
    def init(
        self: Import,
        from_loc: (ModulePath | None),
        items: (Sequence[ModuleItem] | Sequence[ModulePath]),
        is_absorb: bool,
        kid: Sequence[UniNode],
        doc: (String | None) = None
    ) -> None {
        self.hint = None;
        self.from_loc = from_loc;
        self.items = items;
        self.is_absorb = is_absorb;
        UniNode.init(self, kid=kid);
        AstDocNode.init(self, doc=doc);
        CodeBlockStmt.init(self);
        ContextAwareNode.init(self);
    }

    """Check if import is python."""
    @property
    def is_py(self: Import) -> bool {
        if (self.hint and (self.hint.tag.value == 'py')) {
            return True;
        }
        if not self.hint {
            return not self.__jac_detected;
        }
        return False;
    }

    """Check if import is jac."""
    @property
    def is_jac(self: Import) -> bool {
        if (self.hint and (self.hint.tag.value == 'jac')) {
            return True;
        }
        if not self.hint {
            return self.__jac_detected;
        }
        return False;
    }

    """Check if import is jac."""
    @property
    def __jac_detected(self: Import) -> bool {
        if self.from_loc {
            if self.from_loc.resolve_relative_path().endswith(('.jac', '.cl.jac')) {
                return True;
            }
            if os.path.isdir(self.from_loc.resolve_relative_path()) {
                if os.path.exists(
                    os.path.join(self.from_loc.resolve_relative_path(), '__init__.jac')
                ) {
                    return True;
                }
                if os.path.exists(
                    os.path.join(
                        self.from_loc.resolve_relative_path(), '__init__.cl.jac'
                    )
                ) {
                    return True;
                }
                for i in self.items {
                    if (
                        isinstance(i, ModuleItem)
                        and self.from_loc.resolve_relative_path(i.name.value).endswith(
                            ('.jac', '.cl.jac')
                        )
                    ) {
                        return True;
                    }
                }
            }
        }
        return `any(
            (
                isinstance(i, ModulePath)
                and i.resolve_relative_path().endswith(('.jac', '.cl.jac'))
            ) for i in self.items
        );
    }
}

"""ModulePath node type for Jac Ast."""
class ModulePath(UniNode) {
    def init(
        self: ModulePath,
        path: (Sequence[(Name | String)] | None),
        level: int,
        alias: (Name | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.path = path;
        self.level = level;
        self.alias = alias;
        self.abs_path: (str | None) = None;
        UniNode.init(self, kid=kid);
    }

    """Check if this modulepath is from import."""
    @property
    def is_import_from(self: ModulePath) -> bool {
        if (self.parent and isinstance(self.parent, Import)) {
            return (self.parent.from_loc == self);
        }
        return False;
    }

    """Get path string."""
    @property
    def dot_path_str(self: ModulePath) -> str {
        if (self.path and (len(self.path) == 1) and isinstance(self.path[0], String)) {
            return (('.' * self.level) + self.path[0].lit_value);
        }
        return (
            ('.' * self.level) + '.'.join(
                [p.value for p in self.path] if self.path else []
            )
        );
    }

    """Convert an import target string into a relative file path."""
    def resolve_relative_path(
        self: ModulePath, target_item: (str | None) = None
    ) -> str {
        target = self.dot_path_str + (f".{target_item}" if target_item else '');
        if target.startswith('@jac/') {
            import jaclang.runtimelib;
            runtime_dir = os.path.dirname(jaclang.runtimelib.__file__);
            module_name = target[5:];
            module_map = {'runtime': 'client_runtime.cl.jac'};
            if (module_name in module_map) {
                return os.path.join(runtime_dir, module_map[module_name]);
            }
            for ext in ['.cl.jac', '.jac', '.js'] {
                path = os.path.join(runtime_dir, (module_name + ext));
                if os.path.exists(path) {
                    return path;
                }
            }
            return os.path.join(runtime_dir, (module_name + '.jac'));
        }
        return resolve_relative_path(target, self.loc.mod_path);
    }

    """Convert an import target string into a relative file path."""
    def resolve_relative_path_list(self: ModulePath) -> list[str] {
        parts = self.dot_path_str.split('.');
        paths = [];
        for i in range(len(parts)) {
            sub_path = '.'.join(parts[:(i + 1)]);
            paths.append(resolve_relative_path(sub_path, self.loc.mod_path));
        }
        return paths;
    }
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
    ) -> None {
        self.name = name;
        self.alias = alias;
        UniNode.init(self, kid=kid);
        self.abs_path: (str | None) = None;
    }

    """Get import parent."""
    @property
    def from_parent(self: ModuleItem) -> Import {
        if (not self.parent or not isinstance(self.parent, Import)) {
            raise ValueError('Import parent not found. Not Possible.') ;
        }
        return self.parent;
    }

    """Get relevant module path."""
    @property
    def from_mod_path(self: ModuleItem) -> ModulePath {
        if not self.from_parent.from_loc {
            raise ValueError('Module items should have module path. Not Possible.') ;
        }
        return self.from_parent.from_loc;
    }
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
        decorators: (Sequence[Expr] | None) = None
    ) -> None {
        self.name = name;
        self.arch_type = arch_type;
        self.base_classes: list[Expr] = `list(base_classes) if base_classes else [];
        UniNode.init(self, kid=kid);
        AstSymbolNode.init(
            self,
            sym_name=name.value,
            name_spec=name,
            sym_category={
                Tok.KW_OBJECT.value: SymbolType.OBJECT_ARCH,
                Tok.KW_NODE.value: SymbolType.NODE_ARCH,
                Tok.KW_EDGE.value: SymbolType.EDGE_ARCH,
                Tok.KW_WALKER.value: SymbolType.WALKER_ARCH
            }.get(
                arch_type.name, SymbolType.TYPE
            )
        );
        AstImplNeedingNode.init(self, body=body);
        AstAccessNode.init(self, access=access);
        AstDocNode.init(self, doc=doc);
        ArchSpec.init(self, decorators=decorators);
        UniScopeNode.init(self, name=self.sym_name);
        CodeBlockStmt.init(self);
        ContextAwareNode.init(self);
    }

    def _get_impl_resolved_body(self: Archetype) -> list {
        return `list(self.body)
        if isinstance(self.body, Sequence)
        else `list(self.body.body)
        if (isinstance(self.body, ImplDef) and isinstance(self.body.body, Sequence))
        else [];
    }

    @property
    def is_abstract(self: Archetype) -> bool {
        body = self._get_impl_resolved_body();
        return `any((isinstance(i, Ability) and i.is_abstract) for i in body);
    }

    def get_has_vars(self: Archetype) -> list[HasVar] {
        body = self._get_impl_resolved_body();
        has_vars: list[HasVar] = [];
        for `node in body {
            if not isinstance(`node, ArchHas) {
                continue;
            }
            for has_ in `node.vars {
                if isinstance(has_, HasVar) {
                    has_vars.append(has_);
                }
            }
        }
        return has_vars;
    }

    def get_methods(self: Archetype) -> list[Ability] {
        body = self._get_impl_resolved_body();
        methods: list[Ability] = [];
        for `node in body {
            if (isinstance(`node, Ability) and `node.is_method) {
                methods.append(`node);
            }
        }
        return methods;
    }
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
    ) -> None {
        self.decorators = decorators;
        self.target = target;
        self.spec = `list(spec) if isinstance(spec, Sequence) else spec;
        self.body = body;
        self.doc = doc;
        self.decl_link = decl_link;
        UniNode.init(self, kid=kid);
        AstSymbolNode.init(
            self,
            sym_name=('impl.' + '.'.join([x.sym_name for x in self.target])),
            name_spec=self.create_impl_name_node(),
            sym_category=SymbolType.IMPL
        );
        CodeBlockStmt.init(self);
        UniScopeNode.init(self, name=self.sym_name);
        ContextAwareNode.init(self);
    }

    def create_impl_name_node(self: ImplDef) -> Name {
        ret = Name(
            orig_src=self.target[-1].loc.orig_src,
            name=Tok.NAME.value,
            value=('impl.' + '.'.join([x.sym_name for x in self.target])),
            col_start=self.target[0].loc.col_start,
            col_end=self.target[-1].loc.col_end,
            line=self.target[0].loc.first_line,
            end_line=self.target[-1].loc.last_line,
            pos_start=self.target[0].loc.pos_start,
            pos_end=self.target[-1].loc.pos_end
        );
        ret.parent = self;
        return ret;
    }
}

"""SemDef node type for Jac Ast."""
class SemDef(ElementStmt, AstSymbolNode, UniScopeNode) {
    def init(
        self: SemDef, target: Sequence[NameAtom], value: String, kid: Sequence[UniNode]
    ) -> None {
        self.target = target;
        self.value = value;
        UniNode.init(self, kid=kid);
        AstSymbolNode.init(
            self,
            sym_name=('sem.' + '.'.join([x.sym_name for x in self.target])),
            name_spec=self.create_sem_name_node(),
            sym_category=SymbolType.SEM
        );
        UniScopeNode.init(self, name=self.sym_name);
    }

    def create_sem_name_node(self: SemDef) -> Name {
        ret = Name(
            orig_src=self.target[-1].loc.orig_src,
            name=Tok.NAME.value,
            value=('sem.' + '.'.join([x.sym_name for x in self.target])),
            col_start=self.target[0].loc.col_start,
            col_end=self.target[-1].loc.col_end,
            line=self.target[0].loc.first_line,
            end_line=self.target[-1].loc.last_line,
            pos_start=self.target[0].loc.pos_start,
            pos_end=self.target[-1].loc.pos_end
        );
        ret.parent = self;
        return ret;
    }
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
    ) -> None {
        self.name = name;
        self.base_classes: list[Expr] = `list(base_classes) if base_classes else [];
        UniNode.init(self, kid=kid);
        AstSymbolNode.init(
            self,
            sym_name=name.value,
            name_spec=name,
            sym_category=SymbolType.ENUM_ARCH
        );
        AstImplNeedingNode.init(self, body=body);
        AstAccessNode.init(self, access=access);
        AstDocNode.init(self, doc=doc);
        ArchSpec.init(self, decorators=decorators);
        UniScopeNode.init(self, name=self.sym_name);
        ContextAwareNode.init(self);
    }
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
    ) -> None {
        self.is_override = is_override;
        self.is_static = is_static;
        self.is_abstract = is_abstract;
        self.decorators = decorators;
        self.signature = signature;
        UniNode.init(self, kid=kid);
        AstImplNeedingNode.init(self, body=body);
        if (name_ref is None) {
            first_tok = kid[0] if (kid and isinstance(kid[0], Token)) else None;
            if (first_tok is None) {
                raise ValueError(
                    'Cannot create synthetic name_ref without location info.'
                ) ;
            }
            event_type = 'entry'
            if (
                isinstance(signature, EventSignature)
                and (signature.event.name == Tok.KW_ENTRY)
            )
            else 'exit';
            synthetic_name = f"__ability_{event_type}_{first_tok.line_no}_{first_tok.c_start}__";
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
                is_enum_stmt=False
            );
            name_spec_for_init: (Name | NameAtom) = synthetic_name_ref;
            self.name_ref = synthetic_name_ref;
        } else {
            name_spec_for_init = name_ref;
            self.name_ref = name_ref;
        }
        AstSymbolNode.init(
            self,
            sym_name=self.py_resolve_name(),
            name_spec=name_spec_for_init,
            sym_category=SymbolType.ABILITY
        );
        AstAccessNode.init(self, access=access);
        AstDocNode.init(self, doc=doc);
        AstAsyncNode.init(self, is_async=is_async);
        UniScopeNode.init(self, name=self.sym_name);
        CodeBlockStmt.init(self);
        ContextAwareNode.init(self);
    }

    @property
    def is_method(self: Ability) -> bool {
        return (self.method_owner is not None);
    }

    """Check if this ability is a class method."""
    @property
    def is_cls_method(self: Ability) -> bool {
        return (
            self.is_method
            and `any(
                (isinstance(dec, Name) and (dec.sym_name == 'classmethod'))
                for dec in (self.decorators or ())
            )
        );
    }

    @property
    def is_def(self: Ability) -> bool {
        return (not self.signature or isinstance(self.signature, FuncSignature));
    }

    @property
    def method_owner(self: Ability) -> Archetype | Enum | None {
        found = (
            self.parent
            if (self.parent and isinstance(self.parent, (Archetype, Enum)))
            else None
        )
        or (
            self.parent.decl_link
            if (
                self.parent
                and isinstance(self.parent, ImplDef)
                and isinstance(self.parent.decl_link, (Archetype, Enum))
            )
            else None
        );
        return found;
    }

    @property
    def is_genai_ability(self: Ability) -> bool {
        return isinstance(self.body, Expr);
    }

    """Get the range of positional arguments for this ability.

        Returns -1 for maximum number of arguments if there is an unpacked
parameter (e.g., *args).
        """
    def get_pos_argc_range(self: Ability) -> tuple[(int, int)] {
        (mn, mx) = (0, 0);
        if isinstance(self.signature, FuncSignature) {
            for param in self.signature.params {
                if param.unpack {
                    if (param.unpack == Tok.STAR_MUL) {
                        mx = -1;
                    }
                    break;
                }
                mn += 1;
                mx += 1;
            }
        }
        return (mn, mx);
    }

    def py_resolve_name(self: Ability) -> str {
        if (self.name_ref is None) {
            event_type = 'entry'
            if (
                isinstance(self.signature, EventSignature)
                and (self.signature.event.name == Tok.KW_ENTRY)
            )
            else 'exit';
            return f"__ability_{event_type}_{self.loc.first_line}_{self.loc.col_start}__";
        } elif isinstance(self.name_ref, Name) {
            return self.name_ref.value;
        } elif isinstance(self.name_ref, SpecialVarRef) {
            return self.name_ref.py_resolve_name();
        } else {
            raise NotImplementedError ;
        }
    }
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
    ) -> None {
        self.posonly_params: list[ParamVar] = `list(posonly_params);
        self.params: list[ParamVar] = `list(params) if params else [];
        self.varargs = varargs;
        self.kwonlyargs: list[ParamVar] = `list(kwonlyargs);
        self.kwargs = kwargs;
        self.return_type = return_type;
        UniNode.init(self, kid=kid);
    }

    """Return all parameters in the declared order."""
    def get_parameters(self: FuncSignature) -> list[ParamVar] {
        params = self.posonly_params + self.params;
        if self.varargs {
            params.append(self.varargs);
        }
        params += self.kwonlyargs;
        if self.kwargs {
            params.append(self.kwargs);
        }
        return params;
    }

    @property
    def is_static(self: FuncSignature) -> bool {
        return (
            (isinstance(self.parent, Ability) and self.parent.is_static)
            or (
                isinstance(self.parent, ImplDef)
                and isinstance(self.parent.decl_link, Ability)
                and self.parent.decl_link.is_static
            )
        );
    }

    @property
    def is_in_py_class(self: FuncSignature) -> bool {
        is_archi = self.find_parent_of_type(Archetype);
        is_class = (
            (is_archi is not None) and (is_archi.arch_type.name == Tok.KW_CLASS)
        );
        return (
            (
                isinstance(self.parent, Ability)
                and (self.parent.is_method is not None)
                and is_class
            )
            or (
                isinstance(self.parent, ImplDef)
                and isinstance(self.parent.decl_link, Ability)
                and self.parent.decl_link.is_method
                and is_class
            )
        );
    }
}

"""EventSignature node type for Jac Ast."""
class EventSignature(WalkerStmtOnlyNode) {
    def init(
        self: EventSignature,
        event: Token,
        arch_tag_info: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.event = event;
        self.arch_tag_info = arch_tag_info;
        UniNode.init(self, kid=kid);
        WalkerStmtOnlyNode.init(self);
    }
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
    ) -> None {
        self.name = name;
        self.unpack = unpack;
        self.param_kind = ParamKind.NORMAL;
        self.value = value;
        UniNode.init(self, kid=kid);
        AstSymbolNode.init(
            self, sym_name=name.value, name_spec=name, sym_category=SymbolType.VAR
        );
        AstTypedVarNode.init(self, type_tag=type_tag);
    }

    @property
    def is_vararg(self: ParamVar) -> bool {
        return bool((self.unpack and (self.unpack.name == Tok.STAR_MUL.name)));
    }

    @property
    def is_kwargs(self: ParamVar) -> bool {
        return bool((self.unpack and (self.unpack.name == Tok.STAR_POW.name)));
    }
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
    ) -> None {
        self.is_static = is_static;
        self.vars: list[HasVar] = `list(vars);
        self.is_frozen = is_frozen;
        UniNode.init(self, kid=kid);
        AstAccessNode.init(self, access=access);
        AstDocNode.init(self, doc=doc);
        CodeBlockStmt.init(self);
    }
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
    ) -> None {
        self.name = name;
        self.value = value;
        self.defer = defer;
        UniNode.init(self, kid=kid);
        AstSymbolNode.init(
            self, sym_name=name.value, name_spec=name, sym_category=SymbolType.HAS_VAR
        );
        AstTypedVarNode.init(self, type_tag=type_tag);
    }
}

"""TypedCtxBlock node type for Jac Ast."""
class TypedCtxBlock(CodeBlockStmt, WalkerStmtOnlyNode, UniScopeNode) {
    def init(
        self: TypedCtxBlock,
        type_ctx: Expr,
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode]
    ) -> None {
        self.type_ctx = type_ctx;
        self.body = body;
        UniNode.init(self, kid=kid);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
        CodeBlockStmt.init(self);
        WalkerStmtOnlyNode.init(self);
    }
}

"""IfStmt node type for Jac Ast."""
class IfStmt(CodeBlockStmt, AstElseBodyNode, UniScopeNode) {
    def init(
        self: IfStmt,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: ElseStmt | ElseIf | None,
        kid: Sequence[UniNode]
    ) -> None {
        self.condition = condition;
        self.body: list[CodeBlockStmt] = `list(body);
        UniNode.init(self, kid=kid);
        AstElseBodyNode.init(self, else_body=else_body);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
        CodeBlockStmt.init(self);
    }
}

"""ElseIf node type for Jac Ast."""
class ElseIf(IfStmt) {}

"""ElseStmt node type for Jac Ast."""
class ElseStmt(UniScopeNode) {
    def init(
        self: ElseStmt, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode]
    ) -> None {
        self.body: list[CodeBlockStmt] = `list(body);
        UniNode.init(self, kid=kid);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
    }
}

"""ExprStmt node type for Jac Ast."""
class ExprStmt(CodeBlockStmt) {
    def init(
        self: ExprStmt, expr: Expr, in_fstring: bool, kid: Sequence[UniNode]
    ) -> None {
        self.expr = expr;
        self.in_fstring = in_fstring;
        UniNode.init(self, kid=kid);
        CodeBlockStmt.init(self);
    }
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
    ) -> None {
        self.body: list[CodeBlockStmt] = `list(body);
        self.excepts: list[Except] = `list(excepts);
        self.finally_body = finally_body;
        UniNode.init(self, kid=kid);
        AstElseBodyNode.init(self, else_body=else_body);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
        CodeBlockStmt.init(self);
    }
}

"""Except node type for Jac Ast."""
class Except(CodeBlockStmt, UniScopeNode) {
    def init(
        self: Except,
        ex_type: Expr,
        name: (Name | None),
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode]
    ) -> None {
        self.ex_type = ex_type;
        self.name = name;
        self.body: list[CodeBlockStmt] = `list(body);
        UniNode.init(self, kid=kid);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
        CodeBlockStmt.init(self);
    }
}

"""FinallyStmt node type for Jac Ast."""
class FinallyStmt(CodeBlockStmt, UniScopeNode) {
    def init(
        self: FinallyStmt, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode]
    ) -> None {
        self.body: list[CodeBlockStmt] = `list(body);
        UniNode.init(self, kid=kid);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
        CodeBlockStmt.init(self);
    }
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
    ) -> None {
        self.iter = iter;
        self.condition = condition;
        self.count_by = count_by;
        self.body: list[CodeBlockStmt] = `list(body);
        UniNode.init(self, kid=kid);
        AstAsyncNode.init(self, is_async=is_async);
        AstElseBodyNode.init(self, else_body=else_body);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
        CodeBlockStmt.init(self);
    }
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
    ) -> None {
        self.target = target;
        self.collection = collection;
        self.body: list[CodeBlockStmt] = `list(body);
        UniNode.init(self, kid=kid);
        AstAsyncNode.init(self, is_async=is_async);
        AstElseBodyNode.init(self, else_body=else_body);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
        CodeBlockStmt.init(self);
    }
}

"""WhileStmt node type for Jac Ast."""
class WhileStmt(AstElseBodyNode, CodeBlockStmt, UniScopeNode) {
    def init(
        self: WhileStmt,
        condition: Expr,
        body: Sequence[CodeBlockStmt],
        else_body: (ElseStmt | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.condition = condition;
        self.body: list[CodeBlockStmt] = `list(body);
        UniNode.init(self, kid=kid);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
        AstElseBodyNode.init(self, else_body=else_body);
        CodeBlockStmt.init(self);
    }
}

"""WithStmt node type for Jac Ast."""
class WithStmt(AstAsyncNode, CodeBlockStmt, UniScopeNode) {
    def init(
        self: WithStmt,
        is_async: bool,
        exprs: Sequence[ExprAsItem],
        body: Sequence[CodeBlockStmt],
        kid: Sequence[UniNode]
    ) -> None {
        self.exprs = exprs;
        self.body: list[CodeBlockStmt] = `list(body);
        UniNode.init(self, kid=kid);
        AstAsyncNode.init(self, is_async=is_async);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
        CodeBlockStmt.init(self);
    }
}

"""ExprAsItem node type for Jac Ast."""
class ExprAsItem(UniNode) {
    def init(
        self: ExprAsItem, expr: Expr, alias: (Expr | None), kid: Sequence[UniNode]
    ) -> None {
        self.expr = expr;
        self.alias = alias;
        UniNode.init(self, kid=kid);
    }
}

"""RaiseStmt node type for Jac Ast."""
class RaiseStmt(CodeBlockStmt) {
    def init(
        self: RaiseStmt,
        cause: (Expr | None),
        from_target: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.cause = cause;
        self.from_target = from_target;
        UniNode.init(self, kid=kid);
        CodeBlockStmt.init(self);
    }
}

"""AssertStmt node type for Jac Ast."""
class AssertStmt(CodeBlockStmt) {
    def init(
        self: AssertStmt,
        condition: Expr,
        error_msg: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.condition = condition;
        self.error_msg = error_msg;
        UniNode.init(self, kid=kid);
        CodeBlockStmt.init(self);
    }
}

"""CtrlStmt node type for Jac Ast."""
class CtrlStmt(CodeBlockStmt) {
    def init(self: CtrlStmt, ctrl: Token, kid: Sequence[UniNode]) -> None {
        self.ctrl = ctrl;
        UniNode.init(self, kid=kid);
        CodeBlockStmt.init(self);
    }
}

"""DeleteStmt node type for Jac Ast."""
class DeleteStmt(CodeBlockStmt) {
    def init(self: DeleteStmt, target: Expr, kid: Sequence[UniNode]) -> None {
        self.target = target;
        UniNode.init(self, kid=kid);
        CodeBlockStmt.init(self);
    }

    """Get Python AST targets (without setting ctx)."""
    @property
    def py_ast_targets(self: DeleteStmt) -> list[ast3.AST] {
        return [i.gen.py_ast[0] for i in self.target.values]
        if (isinstance(self.target, TupleVal) and self.target.values)
        else self.target.gen.py_ast;
    }
}

"""ReportStmt node type for Jac Ast."""
class ReportStmt(CodeBlockStmt) {
    def init(self: ReportStmt, expr: Expr, kid: Sequence[UniNode]) -> None {
        self.expr = expr;
        UniNode.init(self, kid=kid);
        CodeBlockStmt.init(self);
    }
}

"""ReturnStmt node type for Jac Ast."""
class ReturnStmt(CodeBlockStmt) {
    def init(self: ReturnStmt, expr: (Expr | None), kid: Sequence[UniNode]) -> None {
        self.expr = expr;
        UniNode.init(self, kid=kid);
        CodeBlockStmt.init(self);
    }
}

"""VisitStmt node type for Jac Ast."""
class VisitStmt(WalkerStmtOnlyNode, AstElseBodyNode, CodeBlockStmt) {
    def init(
        self: VisitStmt,
        insert_loc: (Expr | None),
        target: Expr,
        else_body: (ElseStmt | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.insert_loc = insert_loc;
        self.target = target;
        UniNode.init(self, kid=kid);
        WalkerStmtOnlyNode.init(self);
        AstElseBodyNode.init(self, else_body=else_body);
        CodeBlockStmt.init(self);
    }
}

"""DisengageStmt node type for Jac Ast."""
class DisengageStmt(WalkerStmtOnlyNode, CodeBlockStmt) {
    """Initialize disengage statement node."""
    def init(self: DisengageStmt, kid: Sequence[UniNode]) -> None {
        UniNode.init(self, kid=kid);
        WalkerStmtOnlyNode.init(self);
        CodeBlockStmt.init(self);
    }
}

"""AwaitExpr node type for Jac Ast."""
class AwaitExpr(Expr) {
    def init(self: AwaitExpr, target: Expr, kid: Sequence[UniNode]) -> None {
        self.target = target;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
}

"""GlobalStmt node type for Jac Ast."""
class GlobalStmt(CodeBlockStmt) {
    def init(
        self: GlobalStmt, target: Sequence[NameAtom], kid: Sequence[UniNode]
    ) -> None {
        self.target: list[NameAtom] = `list(target);
        UniNode.init(self, kid=kid);
        CodeBlockStmt.init(self);
    }
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
    ) -> None {
        self.target: list[Expr] = `list(target);
        self.value = value;
        self.mutable = mutable;
        self.aug_op = aug_op;
        UniNode.init(self, kid=kid);
        AstTypedVarNode.init(self, type_tag=type_tag);
        CodeBlockStmt.init(self);
        EnumBlockStmt.init(self, is_enum_stmt=is_enum_stmt);
    }
}

"""ConcurrentExpr node type for Jac Ast."""
class ConcurrentExpr(Expr) {
    def init(
        self: ConcurrentExpr, tok: (Token | None), target: Expr, kid: Sequence[UniNode]
    ) -> None {
        UniNode.init(self, kid=kid);
        Expr.init(self);
        self.tok = tok;
        self.target = target;
    }
}

"""BinaryExpr node type for Jac Ast."""
class BinaryExpr(Expr) {
    def init(
        self: BinaryExpr,
        left: Expr,
        right: Expr,
        op: Token | DisconnectOp | ConnectOp,
        kid: Sequence[UniNode]
    ) -> None {
        self.left = left;
        self.right = right;
        self.op = op;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
}

"""CompareExpr node type for Jac Ast."""
class CompareExpr(Expr) {
    def init(
        self: CompareExpr,
        left: Expr,
        rights: list[Expr],
        ops: list[Token],
        kid: Sequence[UniNode]
    ) -> None {
        self.left = left;
        self.rights = rights;
        self.ops = ops;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
}

"""BoolExpr node type for Jac Ast."""
class BoolExpr(Expr) {
    def init(
        self: BoolExpr, op: Token, values: list[Expr], kid: Sequence[UniNode]
    ) -> None {
        self.values = values;
        self.op = op;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
}

"""LambdaExpr node type for Jac Ast."""
class LambdaExpr(Expr, UniScopeNode) {
    def init(
        self: LambdaExpr,
        body: (Expr | Sequence[CodeBlockStmt]),
        kid: Sequence[UniNode],
        signature: (FuncSignature | None) = None
    ) -> None {
        self.signature = signature;
        if (isinstance(body, Sequence) and not isinstance(body, Expr)) {
            self.body: (Expr | Sequence[CodeBlockStmt]) = `list(body);
        } else {
            self.body = cast(Expr, body);
        }
        UniNode.init(self, kid=kid);
        Expr.init(self);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
    }
}

"""UnaryExpr node type for Jac Ast."""
class UnaryExpr(Expr) {
    def init(self: UnaryExpr, operand: Expr, op: Token, kid: Sequence[UniNode]) -> None {
        self.operand = operand;
        self.op = op;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
}

"""IfElseExpr node type for Jac Ast."""
class IfElseExpr(Expr) {
    def init(
        self: IfElseExpr,
        condition: Expr,
        value: Expr,
        else_value: Expr,
        kid: Sequence[UniNode]
    ) -> None {
        self.condition = condition;
        self.value = value;
        self.else_value = else_value;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
}

"""MultiString node type for Jac Ast."""
class MultiString(AtomExpr) {
    def init(
        self: MultiString,
        strings: Sequence[(String | FString)],
        kid: Sequence[UniNode]
    ) -> None {
        self.strings = strings;
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.STRING);
    }
}

"""FString node type for Jac Ast."""
class FString(AtomExpr) {
    def init(
        self: FString,
        start: (Token | None),
        parts: Sequence[(String | FormattedValue)],
        end: (Token | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.start = start;
        self.parts: list[(String | FormattedValue)] = `list(parts);
        self.end = end;
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.STRING);
    }
}

"""FormattedValue node type for Jac Ast."""
class FormattedValue(Expr) {
    def init(
        self: FormattedValue,
        format_part: Expr,
        conversion: int,
        format_spec: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.format_part: Expr = format_part;
        self.conversion: int = conversion;
        self.format_spec: (Expr | None) = format_spec;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
}

"""ListVal node type for Jac Ast."""
class ListVal(AtomExpr) {
    def init(self: ListVal, values: Sequence[Expr], kid: Sequence[UniNode]) -> None {
        self.values = values;
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
    }
}

"""SetVal node type for Jac Ast."""
class SetVal(AtomExpr) {
    def init(
        self: SetVal, values: (Sequence[Expr] | None), kid: Sequence[UniNode]
    ) -> None {
        self.values: list[Expr] = `list(values) if values else [];
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
    }
}

"""TupleVal node type for Jac Ast."""
class TupleVal(AtomExpr) {
    def init(
        self: TupleVal, values: Sequence[(Expr | KWPair)], kid: Sequence[UniNode]
    ) -> None {
        self.values = `list(values);
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
    }
}

"""DictVal node type for Jac Ast."""
class DictVal(AtomExpr) {
    def init(self: DictVal, kv_pairs: Sequence[KVPair], kid: Sequence[UniNode]) -> None {
        self.kv_pairs = kv_pairs;
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
    }
}

"""KVPair node type for Jac Ast."""
class KVPair(UniNode) {
    def init(
        self: KVPair, key: (Expr | None), value: Expr, kid: Sequence[UniNode]
    ) -> None {
        self.key = key;
        self.value = value;
        UniNode.init(self, kid=kid);
    }
}

"""KWPair node type for Jac Ast."""
class KWPair(UniNode) {
    def init(
        self: KWPair, key: (NameAtom | None), value: Expr, kid: Sequence[UniNode]
    ) -> None {
        self.key = key;
        self.value = value;
        UniNode.init(self, kid=kid);
    }
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
    ) -> None {
        self.target = target;
        self.collection = collection;
        self.conditional = conditional;
        UniNode.init(self, kid=kid);
        AstAsyncNode.init(self, is_async=is_async);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
    }
}

"""ListCompr node type for Jac Ast."""
class ListCompr(AtomExpr, UniScopeNode) {
    def init(
        self: ListCompr,
        out_expr: Expr,
        compr: list[InnerCompr],
        kid: Sequence[UniNode]
    ) -> None {
        self.out_expr = out_expr;
        self.compr = compr;
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
    }
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
    ) -> None {
        self.kv_pair = kv_pair;
        self.compr = compr;
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
    }
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
    ) -> None {
        self.target = target;
        self.right = right;
        self.is_attr = is_attr;
        self.is_null_ok = is_null_ok;
        self.is_genai = is_genai;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }

    @property
    def as_attr_list(self: AtomTrailer) -> list[AstSymbolNode] {
        left = self.right if isinstance(self.right, AtomTrailer) else self.target;
        right = self.target if isinstance(self.right, AtomTrailer) else self.right;
        trag_list: list[AstSymbolNode] = [right]
        if isinstance(right, AstSymbolNode)
        else [];
        while (isinstance(left, AtomTrailer) and left.is_attr) {
            if isinstance(left.right, AstSymbolNode) {
                trag_list.insert(0, left.right);
            }
            left = left.target;
        }
        if isinstance(left, AstSymbolNode) {
            trag_list.insert(0, left);
        }
        return trag_list;
    }
}

"""AtomUnit node type for Jac Ast."""
class AtomUnit(Expr) {
    def init(
        self: AtomUnit, value: Expr | YieldExpr | Ability, kid: Sequence[UniNode]
    ) -> None {
        self.value = value;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
}

"""YieldExpr node type for Jac Ast."""
class YieldExpr(Expr) {
    def init(
        self: YieldExpr, expr: (Expr | None), with_from: bool, kid: Sequence[UniNode]
    ) -> None {
        self.expr = expr;
        self.with_from = with_from;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
}

"""FuncCall node type for Jac Ast."""
class FuncCall(Expr) {
    def init(
        self: FuncCall,
        target: Expr,
        params: (Sequence[(Expr | KWPair)] | None),
        genai_call: (Expr | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.target = target;
        self.params = `list(params) if params else [];
        self.genai_call = genai_call;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
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
    ) -> None {
        self.slices = slices;
        self.is_range = is_range;
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
    }
}

"""EdgeRefTrailer node type for Jac Ast."""
class EdgeRefTrailer(Expr) {
    def init(
        self: EdgeRefTrailer,
        chain: list[(Expr | FilterCompr)],
        edges_only: bool,
        is_async: bool,
        kid: Sequence[UniNode]
    ) -> None {
        self.chain = chain;
        self.edges_only = edges_only;
        self.is_async = is_async;
        UniNode.init(self, kid=kid);
        Expr.init(self);
    }
}

"""EdgeOpRef node type for Jac Ast."""
class EdgeOpRef(WalkerStmtOnlyNode, AtomExpr) {
    def init(
        self: EdgeOpRef,
        filter_cond: (FilterCompr | None),
        edge_dir: EdgeDir,
        kid: Sequence[UniNode]
    ) -> None {
        self.filter_cond = filter_cond;
        self.edge_dir = edge_dir;
        UniNode.init(self, kid=kid);
        Expr.init(self);
        WalkerStmtOnlyNode.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
    }
}

"""DisconnectOp node type for Jac Ast."""
class DisconnectOp(WalkerStmtOnlyNode) {
    def init(self: DisconnectOp, edge_spec: EdgeOpRef, kid: Sequence[UniNode]) -> None {
        self.edge_spec = edge_spec;
        UniNode.init(self, kid=kid);
        WalkerStmtOnlyNode.init(self);
    }
}

"""ConnectOpRef node type for Jac Ast."""
class ConnectOp(UniNode) {
    def init(
        self: ConnectOp,
        conn_type: (Expr | None),
        conn_assign: (AssignCompr | None),
        edge_dir: EdgeDir,
        kid: Sequence[UniNode]
    ) -> None {
        self.conn_type = conn_type;
        self.conn_assign = conn_assign;
        self.edge_dir = edge_dir;
        UniNode.init(self, kid=kid);
    }
}

"""FilterCompr node type for Jac Ast."""
class FilterCompr(AtomExpr) {
    def init(
        self: FilterCompr,
        f_type: (Expr | None),
        compares: Sequence[CompareExpr],
        kid: Sequence[UniNode]
    ) -> None {
        self.f_type = f_type;
        self.compares = `list(compares);
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
    }
}

"""AssignCompr node type for Jac Ast."""
class AssignCompr(AtomExpr) {
    def init(
        self: AssignCompr, assigns: Sequence[KWPair], kid: Sequence[UniNode]
    ) -> None {
        self.assigns = `list(assigns);
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
    }
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
    ) -> None {
        self.name = name;
        self.attributes = `list(attributes) if attributes else [];
        self.children: list[(JsxChild | JsxElement)] = `list(children)
        if children
        else [];
        self.is_self_closing = is_self_closing;
        self.is_fragment = is_fragment;
        UniNode.init(self, kid=kid);
        Expr.init(self);
        AstSymbolStubNode.init(self, sym_type=SymbolType.OBJECT_ARCH);
    }
}

"""JsxElementName node type for Jac Ast."""
class JsxElementName(UniNode) {
    def init(
        self: JsxElementName, parts: Sequence[(Name | Token)], kid: Sequence[UniNode]
    ) -> None {
        self.parts = `list(parts);
        UniNode.init(self, kid=kid);
    }
}

"""JsxAttribute node type for Jac Ast (base class)."""
class JsxAttribute(UniNode) {
    def init(self: JsxAttribute, kid: Sequence[UniNode]) -> None {
        UniNode.init(self, kid=kid);
    }
}

"""JsxSpreadAttribute node type for Jac Ast."""
class JsxSpreadAttribute(JsxAttribute) {
    def init(self: JsxSpreadAttribute, expr: Expr, kid: Sequence[UniNode]) -> None {
        self.expr = expr;
        JsxAttribute.init(self, kid=kid);
    }
}

"""JsxNormalAttribute node type for Jac Ast."""
class JsxNormalAttribute(JsxAttribute) {
    def init(
        self: JsxNormalAttribute,
        name: (Name | Token),
        value: String | Expr | None,
        kid: Sequence[UniNode]
    ) -> None {
        self.name = name;
        self.value = value;
        JsxAttribute.init(self, kid=kid);
    }
}

"""JsxChild node type for Jac Ast (base class)."""
class JsxChild(UniNode) {
    def init(self: JsxChild, kid: Sequence[UniNode]) -> None {
        UniNode.init(self, kid=kid);
    }
}

"""JsxText node type for Jac Ast."""
class JsxText(JsxChild) {
    def init(self: JsxText, value: (str | Token), kid: Sequence[UniNode]) -> None {
        self.value = value;
        JsxChild.init(self, kid=kid);
    }
}

"""JsxExpression node type for Jac Ast."""
class JsxExpression(JsxChild) {
    def init(self: JsxExpression, expr: Expr, kid: Sequence[UniNode]) -> None {
        self.expr = expr;
        JsxChild.init(self, kid=kid);
    }
}

"""MatchStmt node type for Jac Ast."""
class MatchStmt(CodeBlockStmt) {
    def init(
        self: MatchStmt, target: Expr, cases: list[MatchCase], kid: Sequence[UniNode]
    ) -> None {
        self.target = target;
        self.cases = cases;
        UniNode.init(self, kid=kid);
        CodeBlockStmt.init(self);
    }
}

"""MatchCase node type for Jac Ast."""
class MatchCase(UniScopeNode) {
    def init(
        self: MatchCase,
        pattern: MatchPattern,
        guard: (Expr | None),
        body: list[CodeBlockStmt],
        kid: Sequence[UniNode]
    ) -> None {
        self.pattern = pattern;
        self.guard = guard;
        self.body = body;
        UniNode.init(self, kid=kid);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
    }
}

"""SwitchStmt node type for Jac Ast."""
class SwitchStmt(CodeBlockStmt) {
    def init(
        self: SwitchStmt, target: Expr, cases: list[SwitchCase], kid: Sequence[UniNode]
    ) -> None {
        self.target = target;
        self.cases = cases;
        UniNode.init(self, kid=kid);
        CodeBlockStmt.init(self);
    }
}

"""SwitchCase node type for Jac Ast."""
class SwitchCase(UniScopeNode) {
    def init(
        self: SwitchCase,
        pattern: (MatchPattern | None),
        body: list[CodeBlockStmt],
        kid: Sequence[UniNode]
    ) -> None {
        self.pattern = pattern;
        self.body = body;
        UniNode.init(self, kid=kid);
        UniScopeNode.init(self, name=f"{self.__class__.__name__}");
    }
}

"""MatchOr node type for Jac Ast."""
class MatchOr(MatchPattern) {
    def init(
        self: MatchOr, patterns: list[MatchPattern], kid: Sequence[UniNode]
    ) -> None {
        self.patterns = patterns;
        UniNode.init(self, kid=kid);
    }
}

"""MatchAs node type for Jac Ast."""
class MatchAs(MatchPattern) {
    def init(
        self: MatchAs,
        name: NameAtom,
        pattern: (MatchPattern | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.name = name;
        self.pattern = pattern;
        UniNode.init(self, kid=kid);
    }
}

"""MatchWild node type for Jac Ast."""
class MatchWild(MatchPattern) {}

"""MatchValue node type for Jac Ast."""
class MatchValue(MatchPattern) {
    def init(self: MatchValue, value: Expr, kid: Sequence[UniNode]) -> None {
        self.value = value;
        UniNode.init(self, kid=kid);
    }
}

"""MatchSingleton node type for Jac Ast."""
class MatchSingleton(MatchPattern) {
    def init(
        self: MatchSingleton, value: (Bool | Null), kid: Sequence[UniNode]
    ) -> None {
        self.value = value;
        UniNode.init(self, kid=kid);
    }
}

"""MatchSequence node type for Jac Ast."""
class MatchSequence(MatchPattern) {
    def init(
        self: MatchSequence, values: list[MatchPattern], kid: Sequence[UniNode]
    ) -> None {
        self.values = values;
        UniNode.init(self, kid=kid);
    }
}

"""MatchMapping node type for Jac Ast."""
class MatchMapping(MatchPattern) {
    def init(
        self: MatchMapping,
        values: list[(MatchKVPair | MatchStar)],
        kid: Sequence[UniNode]
    ) -> None {
        self.values = values;
        UniNode.init(self, kid=kid);
    }
}

"""MatchKVPair node type for Jac Ast."""
class MatchKVPair(MatchPattern) {
    def init(
        self: MatchKVPair,
        key: MatchPattern | NameAtom | AtomExpr,
        value: MatchPattern,
        kid: Sequence[UniNode]
    ) -> None {
        self.key = key;
        self.value = value;
        UniNode.init(self, kid=kid);
    }
}

"""MatchStar node type for Jac Ast."""
class MatchStar(MatchPattern) {
    def init(
        self: MatchStar, name: NameAtom, is_list: bool, kid: Sequence[UniNode]
    ) -> None {
        self.name = name;
        self.is_list = is_list;
        UniNode.init(self, kid=kid);
    }
}

"""MatchArch node type for Jac Ast."""
class MatchArch(MatchPattern) {
    def init(
        self: MatchArch,
        name: (AtomTrailer | NameAtom),
        arg_patterns: (Sequence[MatchPattern] | None),
        kw_patterns: (Sequence[MatchKVPair] | None),
        kid: Sequence[UniNode]
    ) -> None {
        self.name = name;
        self.arg_patterns = `list(arg_patterns) if arg_patterns else None;
        self.kw_patterns = `list(kw_patterns) if kw_patterns else None;
        UniNode.init(self, kid=kid);
    }
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
    ) -> None {
        self.orig_src = orig_src;
        self.name = name;
        self.value = value;
        self.line_no = line;
        self.end_line = end_line;
        self.c_start = col_start;
        self.c_end = col_end;
        self.pos_start = pos_start;
        self.pos_end = pos_end;
        UniNode.init(self, kid=[]);
    }

    def __repr__(self: Token) -> str {
        return f"Token({self.name}, {self.value}, {self.loc})";
    }

    def unparse(self: Token) -> str {
        if self.gen.jac {
            return self.gen.jac;
        }
        return self.value;
    }
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
    ) -> None {
        self.is_kwesc = is_kwesc;
        Token.init(
            self,
            orig_src=orig_src,
            name=name,
            value=value,
            line=line,
            end_line=end_line,
            col_start=col_start,
            col_end=col_end,
            pos_start=pos_start,
            pos_end=pos_end
        );
        NameAtom.init(self, is_enum_stmt=is_enum_stmt);
        AstSymbolNode.init(
            self, sym_name=value, name_spec=self, sym_category=SymbolType.VAR
        );
    }

    """Generate name from node."""
    static def gen_stub_from_node(
        `node: AstSymbolNode, name_str: str, set_name_of: (AstSymbolNode | None) = None
    ) -> Name {
        ret = Name(
            orig_src=`node.loc.orig_src,
            name=Tok.NAME.value,
            value=name_str,
            col_start=`node.loc.col_start,
            col_end=`node.loc.col_end,
            line=`node.loc.first_line,
            end_line=`node.loc.last_line,
            pos_start=`node.loc.pos_start,
            pos_end=`node.loc.pos_end
        );
        ret.parent = `node.parent;
        ret.name_of = set_name_of or ret;
        return ret;
    }
}

"""SpecialVarRef node type for Jac Ast."""
class SpecialVarRef(Name) {
    def init(self: SpecialVarRef, var: Name, is_enum_stmt: bool = False) -> None {
        self.orig = var;
        Name.init(
            self,
            orig_src=var.orig_src,
            name=var.name,
            value=self.py_resolve_name(),
            line=var.line_no,
            end_line=var.end_line,
            col_start=var.c_start,
            col_end=var.c_end,
            pos_start=var.pos_start,
            pos_end=var.pos_end
        );
        NameAtom.init(self, is_enum_stmt=is_enum_stmt);
        AstSymbolNode.init(
            self,
            sym_name=self.py_resolve_name(),
            name_spec=self,
            sym_category=SymbolType.VAR
        );
    }

    def py_resolve_name(self: SpecialVarRef) -> str {
        if (self.orig.name == Tok.KW_SELF) {
            return 'self';
        }
        if (self.orig.name == Tok.KW_PROPS) {
            return 'props';
        } elif (self.orig.name == Tok.KW_SUPER) {
            return 'super';
        } elif (self.orig.name == Tok.KW_ROOT) {
            return Con.ROOT.value;
        } elif (self.orig.name == Tok.KW_HERE) {
            return Con.HERE.value;
        } elif (self.orig.name == Tok.KW_VISITOR) {
            return Con.VISITOR.value;
        } elif (self.orig.name == Tok.KW_INIT) {
            return '__init__';
        } elif (self.orig.name == Tok.KW_POST_INIT) {
            return '__post_init__';
        } else {
            raise NotImplementedError('ICE: Special var reference not implemented') ;
        }
    }
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
    ) -> None {
        Token.init(
            self,
            orig_src=orig_src,
            name=name,
            value=value,
            line=line,
            end_line=end_line,
            col_start=col_start,
            col_end=col_end,
            pos_start=pos_start,
            pos_end=pos_end
        );
        AstSymbolStubNode.init(self, sym_type=self.SYMBOL_TYPE);
        Expr.init(self);
    }

    """Return literal value in its python type."""
    @property
    def lit_value(
        self: Literal
    ) -> int | str | float | bool | None | Callable[([], Any)] | EllipsisType {
        raise NotImplementedError ;
    }
}

"""BuiltinType node type for Jac Ast."""
class BuiltinType(Name, Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.VAR;
    }

    """Return literal value in its python type."""
    @property
    def lit_value(self: BuiltinType) -> Callable[([], Any)] {
        if (self.value not in Literal.type_map) {
            raise TypeError(f"ICE: {self.value} is not a callable builtin") ;
        }
        return Literal.type_map[self.value];
    }
}

"""Float node type for Jac Ast."""
class Float(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    @property
    def lit_value(self: Float) -> float {
        return float(self.value);
    }
}

"""Int node type for Jac Ast."""
class Int(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NUMBER;
    }

    @property
    def lit_value(self: Int) -> int {
        return int(self.value);
    }
}

"""String node type for Jac Ast."""
class String(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.STRING;
    }

    @property
    def lit_value(self: String) -> str {
        if isinstance(self.value, `bytes) {
            return self.value;
        }
        if `any(
            (
                self.value.startswith(prefix)
                and self.value[len(prefix):].startswith(("'", '"'))
            ) for prefix in ['r', 'b', 'br', 'rb']
        ) {
            return eval(self.value);
        } elif self.value.startswith(("'", '"')) {
            if (
                not self.find_parent_of_type(FString)
                or not (self.parent and isinstance(self.parent, FString))
            ) {
                try {
                    return ast3.literal_eval(self.value);
                } except (ValueError, SyntaxError) {
                    if (
                        (self.value.startswith('"""') and self.value.endswith('"""'))
                        or (
                            self.value.startswith("'''") and self.value.endswith("'''")
                        )
                    ) {
                        return self.value[3:-3];
                    }
                    return self.value[1:-1];
                }
            }
            try {
                return ast3.literal_eval(self.value);
            } except (ValueError, SyntaxError) {
                return self.value;
            }
        } else {
            if (self.parent and isinstance(self.parent, FString)) {
                fstring_parent: FString = self.parent;
                is_raw = False;
                if (fstring_parent.start and fstring_parent.start.value) {
                    prefix = fstring_parent.start.value.lower();
                    is_raw = 'r' in prefix;
                }
                if not is_raw {
                    result = self.value;
                    placeholder = '\x00';
                    result = result.replace('\\\\', placeholder);
                    result = result.replace('\\n', '\n');
                    result = result.replace('\\t', '\t');
                    result = result.replace('\\r', '\r');
                    result = result.replace(placeholder, '\\');
                    return result;
                }
            }
            return self.value;
        }
    }
}

"""Bool node type for Jac Ast."""
class Bool(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.BOOL;
    }

    @property
    def lit_value(self: Bool) -> bool {
        return (self.value == 'True');
    }
}

"""Null node type for Jac Ast."""
class Null(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    @property
    def lit_value(self: Null) -> None {
        return None;
    }
}

"""Ellipsis node type for Jac Ast."""
class Ellipsis(Literal) {
    with entry {
        SYMBOL_TYPE = SymbolType.NULL;
    }

    @property
    def lit_value(self: Ellipsis) -> EllipsisType {
        return ...;
    }
}

"""EmptyToken node type for Jac Ast."""
class EmptyToken(Token) {
    def init(self: EmptyToken, orig_src: (Source | None) = None) -> None {
        super.init(
            name='EmptyToken',
            orig_src=(orig_src or Source('', '')),
            value='',
            line=0,
            end_line=0,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0
        );
    }
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
    ) -> None {
        Token.init(
            self,
            orig_src=orig_src,
            name=name,
            value=value,
            line=line,
            end_line=end_line,
            col_start=col_start,
            col_end=col_end,
            pos_start=pos_start,
            pos_end=pos_end
        );
        CodeBlockStmt.init(self);
    }
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
    ) -> None {
        self.is_inline = is_inline;
        Token.init(
            self,
            orig_src=orig_src,
            name=name,
            value=value,
            line=line,
            end_line=end_line,
            col_start=col_start,
            col_end=col_end,
            pos_start=pos_start,
            pos_end=pos_end
        );
        UniNode.init(self, kid=kid);
    }

    @property
    def left_node(self: CommentToken) -> (UniNode | None) {
        if (self.parent and ((idx := self.parent.kid.index(self)) > 0)) {
            return self.parent.kid[(idx - 1)];
        }
        return None;
    }

    @property
    def right_node(self: CommentToken) -> (UniNode | None) {
        if (
            self.parent
            and ((idx := self.parent.kid.index(self)) < (len(self.parent.kid) - 1))
        ) {
            return self.parent.kid[(idx + 1)];
        }
        return None;
    }
}

"""SourceString node type for Jac Ast."""
class Source(EmptyToken) {
    def init(self: Source, source: str, mod_path: str) -> None {
        super.init(self);
        self.value = source;
        self.hash = md5(source.encode()).hexdigest();
        self.file_path = mod_path;
        self.comments: list[CommentToken] = [];
    }

    """Return the source code as string."""
    @property
    def code(self: Source) -> str {
        return self.value;
    }
}

"""SourceString node type for Jac Ast."""
class PythonModuleAst(EmptyToken) {
    def init(self: PythonModuleAst, ast: ast3.Module, orig_src: Source) -> None {
        super.init();
        self.ast = ast;
        self.orig_src = orig_src;
        self.file_path = orig_src.file_path;
    }
}
