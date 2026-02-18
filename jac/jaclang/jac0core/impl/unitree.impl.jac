"""Implementation for unitree constructs."""

"""Initialize ast."""
impl UniNode.init(self: UniNode, kid: Sequence[UniNode]) -> None {
    self.parent: (UniNode | None) = None;
    self.kid: list[UniNode] = [x.set_parent(self) for x in kid];
    self.__sub_node_tab: (dict[(type, list[UniNode])] | None) = None;
    self._in_mod_nodes: list[UniNode] = [];
    self._gen: (CodeGenTarget | None) = None;
    self.loc: CodeLocInfo = CodeLocInfo(*self.resolve_tok_range());
}

"""Lazy initialization of sub node table."""
@ property
impl UniNode._sub_node_tab(self: UniNode) -> dict[(type, list[UniNode])] {
    if (self.__sub_node_tab is None) {
        self.__sub_node_tab = {};
        self._construct_sub_node_tab();
    }
    return self.__sub_node_tab;
}

"""Construct sub node table."""
impl UniNode._construct_sub_node_tab(self: UniNode) -> None {
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
@ property
impl UniNode.sym_tab(self: UniNode) -> UniScopeNode {
    return self
    if isinstance(self, UniScopeNode)
    else self.parent_of_type(UniScopeNode);
}

"""Add kid left."""
impl UniNode.add_kids_left(
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
impl UniNode.add_kids_right(
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
impl UniNode.insert_kids_at_pos(
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
impl UniNode.set_kids(self: UniNode, nodes: Sequence[UniNode]) -> UniNode {
    self.kid = [*nodes];
    for i in nodes {
        i.parent = self;
    }
    self.loc.update_token_range(*self.resolve_tok_range());
    return self;
}

"""Set parent."""
impl UniNode.set_parent(self: UniNode, parent: UniNode) -> UniNode {
    self.parent = parent;
    return self;
}

impl UniNode.resolve_tok_range(self: UniNode) -> tuple[(Token, Token)] {
    if len(self.kid) {
        return (self.kid[0].loc.first_tok, self.kid[-1].loc.last_tok);
    } elif isinstance(self, Token) {
        return (self, self);
    } else {
        raise ValueError(f"Empty kid for Token {type(self).__name__}") ;
    }
}

impl UniNode.gen_token(self: UniNode, name: Tok, value: (str | None) = None) -> Token {
    import from jaclang.jac0core.constant { TOKEN_MAP }
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
impl UniNode.get_all_sub_nodes(
    self: UniNode, typ: type[T], brute_force: bool = True
) -> list[T] {
    import from jaclang.jac0core.passes { UniPass }
    return UniPass.get_all_sub_nodes(nd=self, typ=typ, brute_force=brute_force);
}

"""Get parent of type."""
impl UniNode.find_parent_of_type(self: UniNode, typ: type[T]) -> (T | None) {
    import from jaclang.jac0core.passes { UniPass }
    return UniPass.find_parent_of_type(nd=self, typ=typ);
}

impl UniNode.parent_of_type(self: UniNode, typ: type[T]) -> T {
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
impl UniNode.in_client_context(self: UniNode) -> bool {
    nd: (UniNode | None) = self.parent;
    while (nd is not None) {
        if isinstance(nd, ServerBlock) {
            return False;
        }
        if isinstance(nd, ClientBlock) {
            return True;
        }
        if isinstance(nd, Ability) {
            context = getattr(nd, 'code_context', CodeContext.SERVER);
            if (context == CodeContext.CLIENT) {
                return True;
            }
        }
        nd = nd.parent;
    }
    return False;
}

"""Check if this node is in a native context.

        This covers:
        - Nodes inside an explicit na {} block in a .jac file
        - Nodes inside a function marked with NATIVE context in .na.jac files
        - Overridden by sv {} or cl {} blocks
        """
impl UniNode.in_native_context(self: UniNode) -> bool {
    nd: (UniNode | None) = self.parent;
    while (nd is not None) {
        if isinstance(nd, (ServerBlock, ClientBlock)) {
            return False;
        }
        if isinstance(nd, NativeBlock) {
            return True;
        }
        if isinstance(nd, Ability) {
            context = getattr(nd, 'code_context', CodeContext.SERVER);
            if (context == CodeContext.NATIVE) {
                return True;
            }
        }
        nd = nd.parent;
    }
    return False;
}

"""Return dict representation of node."""
impl UniNode.to_dict(self: UniNode) -> dict[(str, str)] {
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
impl UniNode.pp(self: UniNode, depth: (int | None) = None) -> str {
    return print_ast_tree(self, max_depth=depth);
}

"""Print ast."""
impl UniNode.printgraph(self: UniNode) -> str {
    return printgraph_ast_tree(self);
}

"""Flatten ast."""
impl UniNode.flatten(self: UniNode) -> list[UniNode] {
    ret: list[UniNode] = [self];
    for k in self.kid {
        ret += k.flatten();
    }
    return ret;
}

impl UniNode.unparse(self: UniNode) -> str {
    if self.gen.jac {
        return self.gen.jac;
    }
    return ' '.join([i.unparse() for i in self.kid]);
}

"""Initialize."""
impl Symbol.init(
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
@ property
impl Symbol.decl(self: Symbol) -> NameAtom {
    return self.defn[0];
}

"""Get name."""
@ property
impl Symbol.sym_name(self: Symbol) -> str {
    return self.decl.sym_name;
}

"""Get sym_type."""
@ property
impl Symbol.sym_type(self: Symbol) -> SymbolType {
    return self.decl.sym_category;
}

"""Return a full path of the symbol."""
@ property
impl Symbol.sym_dotted_name(self: Symbol) -> str {
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
@ property
impl Symbol.symbol_table(self: Symbol) -> (UniScopeNode | None) {
    if self.parent_tab {
        return self.parent_tab.find_scope(self.sym_name);
    }
    return None;
}

"""Add defn."""
impl Symbol.add_defn(self: Symbol, nd: NameAtom) -> None {
    self.defn.append(nd);
    nd.sym = self;
}

"""Add use."""
impl Symbol.add_use(self: Symbol, nd: NameAtom) -> None {
    self.uses.append(nd);
    nd.sym = self;
}

"""Repr."""
impl Symbol.__repr__(self: Symbol) -> str {
    return f"Symbol({self.sym_name}, {self.sym_type}, {self.access},{self.defn})";
}

"""Initialize."""
impl UniScopeNode.init(
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
impl UniScopeNode.get_type(self: UniScopeNode) -> SymbolType {
    if isinstance(self, AstSymbolNode) {
        return self.sym_category;
    }
    return SymbolType.VAR;
}

"""Get parent."""
impl UniScopeNode.get_parent(self: UniScopeNode) -> (UniScopeNode | None) {
    return self.parent_scope;
}

"""Lookup a variable in the symbol table."""
impl UniScopeNode.lookup(
    self: UniScopeNode, name: str, deep: bool = True, incl_inner_scope: bool = False
) -> (Symbol | None) {
    if (name in self.names_in_scope) {
        return self.names_in_scope[name];
    }
    if (
        (deep and self.parent_scope)
        and (sym := self.parent_scope.lookup(name, deep, incl_inner_scope))
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
    # If not found and we're in/under an ImplDef, check the declaration's symbol table
    impl_def: ImplDef | None = (
        self if isinstance(self, ImplDef) else self.find_parent_of_type(ImplDef)
    );
    if (impl_def and impl_def.decl_link and impl_def.decl_link.sym_tab) {
        return impl_def.decl_link.sym_tab.lookup(
            name, deep=True, incl_inner_scope=True
        );
    }
    return None;
}

"""Set a variable in the symbol table.

        Returns original symbol as collision if single check fails, none
otherwise.
        Also updates node.sym to create pointer to symbol.
        """
impl UniScopeNode.insert(
    self: UniScopeNode,
    nd: AstSymbolNode,
    access_spec: AstAccessNode | None | SymbolAccess = None,
    single: bool = False,
    force_overwrite: bool = False,
    imported: bool = False
) -> (UniNode | None) {
    collision = self.names_in_scope[nd.sym_name].defn[-1]
    if (single and (nd.sym_name in self.names_in_scope))
    else None;
    symbol = nd.name_spec.create_symbol(
        access=access_spec
        if isinstance(access_spec, SymbolAccess)
        else access_spec.access_type if access_spec else SymbolAccess.PUBLIC,
        parent_tab=self,
        imported=imported
    );
    if (nd.sym_name in self.names_in_scope) {
        self.names_in_scope_overload.setdefault(nd.sym_name, []).append(symbol);
    }
    if (force_overwrite or (nd.sym_name not in self.names_in_scope)) {
        self.names_in_scope[nd.sym_name] = symbol;
    } else {
        self.names_in_scope[nd.sym_name].add_defn(nd.name_spec);
    }
    nd.name_spec.sym = self.names_in_scope[nd.sym_name];
    return collision;
}

"""Find a scope in the symbol table."""
impl UniScopeNode.find_scope(self: UniScopeNode, name: str) -> (UniScopeNode | None) {
    for k in self.kid_scope {
        if (k.scope_name == name) {
            return k;
        }
    }
    return None;
}

"""Push a new scope onto the symbol table."""
impl UniScopeNode.link_kid_scope(
    self: UniScopeNode, key_node: UniScopeNode
) -> UniScopeNode {
    key_node.parent_scope = self;
    self.kid_scope.append(key_node);
    return self.kid_scope[-1];
}

"""Inherit symbol table."""
impl UniScopeNode.inherit_sym_tab(
    self: UniScopeNode, target_sym_tab: UniScopeNode
) -> None {
    for i in target_sym_tab.names_in_scope.values() {
        self.def_insert(i.decl, access_spec=i.access);
    }
}

"""Insert into symbol table."""
impl UniScopeNode.def_insert(
    self: UniScopeNode,
    nd: AstSymbolNode,
    access_spec: AstAccessNode | None | SymbolAccess = None,
    single_decl: (str | None) = None,
    force_overwrite: bool = False,
    imported: bool = False
) -> (Symbol | None) {
    if (nd.sym and (self == nd.sym.parent_tab)) {
        return nd.sym;
    }
    self.insert(
        nd=nd,
        single=(single_decl is not None),
        access_spec=access_spec,
        force_overwrite=force_overwrite,
        imported=imported
    );
    self.update_py_ctx_for_def(nd);
    return nd.sym;
}

"""Link chain of containing names to symbol."""
impl UniScopeNode.chain_def_insert(
    self: UniScopeNode, node_list: list[AstSymbolNode]
) -> None {
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
impl UniScopeNode.use_lookup(
    self: UniScopeNode, nd: AstSymbolNode, sym_table: (UniScopeNode | None) = None
) -> (Symbol | None) {
    if nd.sym {
        return nd.sym;
    }
    if not sym_table {
        sym_table = nd.sym_tab;
    }
    if sym_table {
        lookup = sym_table.lookup(name=nd.sym_name, deep=True);
        lookup.add_use(nd.name_spec) if lookup else None;
    }
    return nd.sym;
}

"""Link chain of containing names to symbol."""
impl UniScopeNode.chain_use_lookup(
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
impl UniScopeNode.update_py_ctx_for_def(self: UniScopeNode, nd: AstSymbolNode) -> None {
    nd.name_spec.py_ctx_func = ast3.Store;
    if (isinstance(nd, (TupleVal, ListVal)) and nd.values) {
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
        fix(nd);
    }
}

"""Pretty print."""
impl UniScopeNode.sym_pp(self: UniScopeNode, depth: (int | None) = None) -> str {
    return print_symtab_tree(`root=self, depth=depth);
}

"""Generate dot graph for sym table."""
impl UniScopeNode.sym_printgraph(self: UniScopeNode) -> str {
    return printgraph_symtab_tree(self);
}

"""Repr."""
impl UniScopeNode.__repr__(self: UniScopeNode) -> str {
    out = f"{self.scope_name} {super.__repr__()}:\n";
    for (k, v) in self.names_in_scope.items() {
        out += f"    {k}: {v}\n";
    }
    return out;
}

impl AstSymbolNode.init(
    self: AstSymbolNode, sym_name: str, name_spec: NameAtom, sym_category: SymbolType
) -> None {
    self.name_spec = name_spec;
    self.name_spec.name_of = self;
    self.name_spec._sym_name = sym_name;
    self.name_spec._sym_category = sym_category;
    self.semstr = '';
}

@ property
impl AstSymbolNode.sym(self: AstSymbolNode) -> (Symbol | None) {
    return self.name_spec.sym;
}

@ property
impl AstSymbolNode.sym_name(self: AstSymbolNode) -> str {
    return self.name_spec.sym_name;
}

@ property
impl AstSymbolNode.sym_category(self: AstSymbolNode) -> SymbolType {
    return self.name_spec.sym_category;
}

@ property
impl AstSymbolNode.py_ctx_func(self: AstSymbolNode) -> type[ast3.AST] {
    return self.name_spec.py_ctx_func;
}

@ property
impl AstSymbolNode.expr_type(self: AstSymbolNode) -> str {
    return self.name_spec.expr_type;
}

"""Get type symbol table."""
@ property
impl AstSymbolNode.type_sym_tab(self: AstSymbolNode) -> (UniScopeNode | None) {
    return self.name_spec.type_sym_tab;
}

impl AstSymbolStubNode.init(self: AstSymbolStubNode, sym_type: SymbolType) -> None {
    AstSymbolNode.init(
        self,
        sym_name=f"[{self.__class__.__name__}]",
        name_spec=Name.gen_stub_from_node(self, f"[{self.__class__.__name__}]"),
        sym_category=sym_type
    );
}

impl AstAccessNode.init(self: AstAccessNode, access: (SubTag[Token] | None)) -> None {
    self.access: (SubTag[Token] | None) = access;
}

@ property
impl AstAccessNode.access_type(self: AstAccessNode) -> SymbolAccess {
    return SymbolAccess.PRIVATE
    if (self.access and (self.access.tag.name == Tok.KW_PRIV))
    else SymbolAccess.PROTECTED
    if (self.access and (self.access.tag.name == Tok.KW_PROT))
    else SymbolAccess.PUBLIC;
}

@ property
impl AstAccessNode.public_access(self: AstAccessNode) -> bool {
    return (self.access_type == SymbolAccess.PUBLIC);
}

"""Initialize with code context.

        Args:
            code_context: Code execution context (SERVER or CLIENT), defaults to
SERVER
        """
impl ContextAwareNode.init(
    self: ContextAwareNode, code_context: CodeContext = CodeContext.SERVER
) -> None {
    self.code_context = code_context;
}

"""Return the original context token (cl or sv) if present on this node."""
impl ContextAwareNode._source_context_token(self: ContextAwareNode) -> (Token | None) {
    for kid in self.kid {
        if (isinstance(kid, Token) and (kid.name in (Tok.KW_CLIENT, Tok.KW_SERVER))) {
            return kid;
        }
    }
    return None;
}

impl AstDocNode.init(self: AstDocNode, doc: (String | None)) -> None {
    self.doc: (String | None) = doc;
}

impl AstAsyncNode.init(self: AstAsyncNode, is_async: bool) -> None {
    self.is_async: bool = is_async;
}

impl AstElseBodyNode.init(
    self: AstElseBodyNode, else_body: ElseStmt | ElseIf | None
) -> None {
    self.else_body: ElseStmt | ElseIf | None = else_body;
}

impl AstTypedVarNode.init(
    self: AstTypedVarNode, type_tag: (SubTag[Expr] | None)
) -> None {
    self.type_tag: (SubTag[Expr] | None) = type_tag;
}

impl WalkerStmtOnlyNode.init(self: WalkerStmtOnlyNode) -> None {
    self.from_walker: bool = False;
}

"""Initialize basic block statement node."""
impl UniCFGNode.init(self: UniCFGNode) -> None {
    self.bb_in: list[UniCFGNode] = [];
    self.bb_out: list[UniCFGNode] = [];
}

"""Get head by walking up the CFG iteratively."""
impl UniCFGNode.get_head(self: UniCFGNode) -> UniCFGNode {
    nd = self;
    while (
        nd.bb_in
        and (len(nd.bb_in) == 1)
        and not isinstance(nd.bb_in[0], (InForStmt, IterForStmt, WhileStmt))
        and nd.bb_in[0].bb_out
        and (len(nd.bb_in[0].bb_out) == 1)
    ) {
        nd = nd.bb_in[0];
    }
    return nd;
}

"""Get tail by walking down the CFG iteratively."""
impl UniCFGNode.get_tail(self: UniCFGNode) -> UniCFGNode {
    nd = self;
    while (
        nd.bb_out
        and (len(nd.bb_out) == 1)
        and not isinstance(nd.bb_out[0], (InForStmt, IterForStmt, WhileStmt))
        and nd.bb_out[0].bb_in
        and (len(nd.bb_out[0].bb_in) == 1)
    ) {
        nd = nd.bb_out[0];
    }
    return nd;
}

impl Expr.init(self: Expr) -> None {
    self._sym_type: str = 'NoType';
    self._type_sym_tab: (UniScopeNode | None) = None;
    self.type: (TypeBase | None) = None;
    self.attached_tokens: (list[Token] | None) = None;
}

impl EnumBlockStmt.init(self: EnumBlockStmt, is_enum_stmt: bool) -> None {
    self.is_enum_stmt = is_enum_stmt;
}

"""Initialize code block statement node."""
impl CodeBlockStmt.init(self: CodeBlockStmt) -> None {
    UniCFGNode.init(self);
}

impl AstImplNeedingNode.init(self: AstImplNeedingNode, body: (T | None)) -> None {
    self.body = body;
}

@ property
impl AstImplNeedingNode.needs_impl(self: AstImplNeedingNode) -> bool {
    return (self.body is None);
}

impl NameAtom.init(self: NameAtom, is_enum_stmt: bool) -> None {
    self.name_of: AstSymbolNode = self;
    self._sym: (Symbol | None) = None;
    self._sym_name: str = '';
    self._sym_category: SymbolType = SymbolType.UNKNOWN;
    self._py_ctx_func: type[ast3.expr_context] = ast3.Load;
    AtomExpr.init(self);
    EnumBlockStmt.init(self, is_enum_stmt=is_enum_stmt);
}

@ property
impl NameAtom.sym_name(self: NameAtom) -> str {
    return self._sym_name;
}

@ property
impl NameAtom.sym_category(self: NameAtom) -> SymbolType {
    return self._sym_category;
}

"""Create symbol."""
impl NameAtom.create_symbol(
    self: NameAtom,
    access: SymbolAccess,
    parent_tab: (UniScopeNode | None) = None,
    imported: bool = False
) -> Symbol {
    sym = Symbol(defn=self, access=access, parent_tab=parent_tab, imported=imported);
    return sym;
}

@ property
impl NameAtom.clean_type(self: NameAtom) -> str {
    ret_type = self.expr_type.replace('builtins.', '').replace('NoType', '');
    return ret_type;
}

"""Resolve semantic token."""
@ property
impl NameAtom.sem_token(self: NameAtom) -> (tuple[(SemTokType, SemTokMod)] | None) {
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

impl ArchSpec.init(
    self: ArchSpec, decorators: (Sequence[Expr] | None), is_async: bool = False
) -> None {
    self.decorators = decorators;
    CodeBlockStmt.init(self);
    AstAsyncNode.init(self, is_async=is_async);
}

impl SubTag.init(self: SubTag, tag: T, kid: Sequence[UniNode]) -> None {
    self.tag: T = tag;
    UniNode.init(self, kid=kid);
}

impl Module.init(
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
@ property
impl Module.annexable_by(self: Module) -> (str | None) {
    if self.stub_only {
        return None;
    }
    return discover_base_file(self.loc.mod_path);
}

"""Get all sub nodes of type."""
impl Module.format(self: Module) -> str {
    import from jaclang.compiler.passes.tool.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.passes.tool.jac_formatter_pass { JacFormatPass }
    import from jaclang.jac0core.program { JacProgram }
    return JacFormatPass(
        ir_in=DocIRGenPass(ir_in=self, prog=JacProgram()).ir_out, prog=JacProgram()
    ).ir_out.gen.jac;
}

impl Module.unparse(self: Module, requires_format: bool = True) -> str {
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

"""Initialize whole program node."""
impl ProgramModule.init(self: ProgramModule, main_mod: (Module | None) = None) -> None {
    self.main = main_mod or Module.make_stub();
    UniNode.init(self, kid=[self.main]);
    self.hub: dict[(str, Module)] = {self.loc.mod_path: main_mod} if main_mod else {};
}

impl TypeParam.init(
    self: TypeParam,
    name: Name,
    bound: (Expr | None),
    default_val: (Expr | None),
    kid: Sequence[UniNode]
) -> None {
    self.name = name;
    self.bound = bound;
    self.default_val = default_val;
    UniNode.init(self, kid=kid);
    AstSymbolNode.init(
        self, sym_name=name.value, name_spec=name, sym_category=SymbolType.TYPE
    );
}

impl TypeAlias.init(
    self: TypeAlias,
    name: Name,
    type_params: (Sequence[TypeParam] | None),
    value: Expr,
    access: (SubTag[Token] | None),
    kid: Sequence[UniNode],
    doc: (String | None) = None
) -> None {
    self.name = name;
    self.type_params: list[TypeParam] = `list(type_params) if type_params else [];
    self.value = value;
    UniNode.init(self, kid=kid);
    AstSymbolNode.init(
        self, sym_name=name.value, name_spec=name, sym_category=SymbolType.TYPE
    );
    AstAccessNode.init(self, access=access);
    AstDocNode.init(self, doc=doc);
    UniScopeNode.init(self, name=self.sym_name);
    ContextAwareNode.init(self);
}

impl GlobalVars.init(
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

impl Test.init(
    self: Test,
    name: (Name | Token),
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode],
    doc: (String | None) = None,
    description: (String | None) = None
) -> None {
    self.description: (String | None) = description;
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
    # Only insert synthetic name into kids if no description string present
    # (the description String is already in the kid list from the parser)
    if (self.description is None and self.name not in self.kid) {
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

impl ModuleCode.init(
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

impl ClientBlock.init(
    self: ClientBlock,
    body: Sequence[ElementStmt],
    kid: Sequence[UniNode],
    implicit: bool = False
) -> None {
    self.body = `list(body);
    self.implicit = implicit;
    UniNode.init(self, kid=kid);
}

impl ServerBlock.init(
    self: ServerBlock,
    body: Sequence[ElementStmt],
    kid: Sequence[UniNode],
    implicit: bool = False
) -> None {
    self.body = `list(body);
    self.implicit = implicit;
    UniNode.init(self, kid=kid);
}

impl NativeBlock.init(
    self: NativeBlock,
    body: Sequence[ElementStmt],
    kid: Sequence[UniNode],
    implicit: bool = False
) -> None {
    self.body = `list(body);
    self.implicit = implicit;
    UniNode.init(self, kid=kid);
}

impl PyInlineCode.init(
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

impl Import.init(
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
@ property
impl Import.is_py(self: Import) -> bool {
    if (self.hint and (self.hint.tag.value == 'py')) {
        return True;
    }
    if not self.hint {
        return not self.__jac_detected;
    }
    return False;
}

"""Check if import is jac."""
@ property
impl Import.is_jac(self: Import) -> bool {
    if (self.hint and (self.hint.tag.value == 'jac')) {
        return True;
    }
    if not self.hint {
        return self.__jac_detected;
    }
    return False;
}

"""Check if import is jac."""
@ property
impl Import.__jac_detected(self: Import) -> bool {
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
                os.path.join(self.from_loc.resolve_relative_path(), '__init__.cl.jac')
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

impl ModulePath.init(
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
@ property
impl ModulePath.is_import_from(self: ModulePath) -> bool {
    if (self.parent and isinstance(self.parent, Import)) {
        return (self.parent.from_loc == self);
    }
    return False;
}

"""Get path string."""
@ property
impl ModulePath.dot_path_str(self: ModulePath) -> str {
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
impl ModulePath.resolve_relative_path(
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
impl ModulePath.resolve_relative_path_list(self: ModulePath) -> list[str] {
    parts = self.dot_path_str.split('.');
    paths = [];
    for i in range(len(parts)) {
        sub_path = '.'.join(parts[:(i + 1)]);
        paths.append(resolve_relative_path(sub_path, self.loc.mod_path));
    }
    return paths;
}

impl ModuleItem.init(
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
@ property
impl ModuleItem.from_parent(self: ModuleItem) -> Import {
    if (not self.parent or not isinstance(self.parent, Import)) {
        raise ValueError('Import parent not found. Not Possible.') ;
    }
    return self.parent;
}

"""Get relevant module path."""
@ property
impl ModuleItem.from_mod_path(self: ModuleItem) -> ModulePath {
    if not self.from_parent.from_loc {
        raise ValueError('Module items should have module path. Not Possible.') ;
    }
    return self.from_parent.from_loc;
}

impl Archetype.init(
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
) -> None {
    self.name = name;
    self.arch_type = arch_type;
    self.base_classes: list[Expr] = `list(base_classes) if base_classes else [];
    self.type_params: list[TypeParam] = `list(type_params) if type_params else [];
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

impl Archetype._get_impl_resolved_body(self: Archetype) -> list {
    return `list(self.body)
    if isinstance(self.body, Sequence)
    else `list(self.body.body)
    if (isinstance(self.body, ImplDef) and isinstance(self.body.body, Sequence))
    else [];
}

@ property
impl Archetype.is_abstract(self: Archetype) -> bool {
    body = self._get_impl_resolved_body();
    return `any((isinstance(i, Ability) and i.is_abstract) for i in body);
}

impl Archetype.get_has_vars(self: Archetype) -> list[HasVar] {
    body = self._get_impl_resolved_body();
    has_vars: list[HasVar] = [];
    for nd in body {
        if not isinstance(nd, ArchHas) {
            continue;
        }
        for has_ in nd.vars {
            if isinstance(has_, HasVar) {
                has_vars.append(has_);
            }
        }
    }
    return has_vars;
}

impl Archetype.get_methods(self: Archetype) -> list[Ability] {
    body = self._get_impl_resolved_body();
    methods: list[Ability] = [];
    for nd in body {
        if (isinstance(nd, Ability) and nd.is_method) {
            methods.append(nd);
        }
    }
    return methods;
}

impl ImplDef.init(
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

impl ImplDef.create_impl_name_node(self: ImplDef) -> Name {
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

impl SemDef.init(
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

impl SemDef.create_sem_name_node(self: SemDef) -> Name {
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

impl Enum.init(
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
        self, sym_name=name.value, name_spec=name, sym_category=SymbolType.ENUM_ARCH
    );
    AstImplNeedingNode.init(self, body=body);
    AstAccessNode.init(self, access=access);
    AstDocNode.init(self, doc=doc);
    ArchSpec.init(self, decorators=decorators);
    UniScopeNode.init(self, name=self.sym_name);
    ContextAwareNode.init(self);
}

impl Ability.init(
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
            raise ValueError('Cannot create synthetic name_ref without location info.') ;
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

@ property
impl Ability.is_method(self: Ability) -> bool {
    return (self.method_owner is not None);
}

"""Check if this ability is a class method."""
@ property
impl Ability.is_cls_method(self: Ability) -> bool {
    return (
        self.is_method
        and `any(
            (isinstance(dec, Name) and (dec.sym_name == 'classmethod'))
            for dec in (self.decorators or ())
        )
    );
}

@ property
impl Ability.is_def(self: Ability) -> bool {
    return (not self.signature or isinstance(self.signature, FuncSignature));
}

@ property
impl Ability.method_owner(self: Ability) -> Archetype | Enum | None {
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

@ property
impl Ability.is_genai_ability(self: Ability) -> bool {
    return isinstance(self.body, Expr);
}

"""Get the range of positional arguments for this ability.

        Returns -1 for maximum number of arguments if there is an unpacked
parameter (e.g., *args).
        """
impl Ability.get_pos_argc_range(self: Ability) -> tuple[(int, int)] {
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

impl Ability.py_resolve_name(self: Ability) -> str {
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

impl FuncSignature.init(
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
impl FuncSignature.get_parameters(self: FuncSignature) -> list[ParamVar] {
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

@ property
impl FuncSignature.is_static(self: FuncSignature) -> bool {
    return (
        (isinstance(self.parent, Ability) and self.parent.is_static)
        or (
            isinstance(self.parent, ImplDef)
            and isinstance(self.parent.decl_link, Ability)
            and self.parent.decl_link.is_static
        )
    );
}

@ property
impl FuncSignature.is_in_py_class(self: FuncSignature) -> bool {
    is_archi = self.find_parent_of_type(Archetype);
    is_class = (is_archi is not None) and (is_archi.arch_type.name == Tok.KW_CLASS);
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

impl EventSignature.init(
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

impl ParamVar.init(
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

@ property
impl ParamVar.is_vararg(self: ParamVar) -> bool {
    return bool((self.unpack and (self.unpack.name == Tok.STAR_MUL.name)));
}

@ property
impl ParamVar.is_kwargs(self: ParamVar) -> bool {
    return bool((self.unpack and (self.unpack.name == Tok.STAR_POW.name)));
}

impl ArchHas.init(
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

impl HasVar.init(
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

impl TypedCtxBlock.init(
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

impl IfStmt.init(
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

impl ElseStmt.init(
    self: ElseStmt, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode]
) -> None {
    self.body: list[CodeBlockStmt] = `list(body);
    UniNode.init(self, kid=kid);
    UniScopeNode.init(self, name=f"{self.__class__.__name__}");
}

impl ExprStmt.init(
    self: ExprStmt, expr: Expr, in_fstring: bool, kid: Sequence[UniNode]
) -> None {
    self.expr = expr;
    self.in_fstring = in_fstring;
    UniNode.init(self, kid=kid);
    CodeBlockStmt.init(self);
}

impl TryStmt.init(
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

impl Except.init(
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

impl FinallyStmt.init(
    self: FinallyStmt, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode]
) -> None {
    self.body: list[CodeBlockStmt] = `list(body);
    UniNode.init(self, kid=kid);
    UniScopeNode.init(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.init(self);
}

impl IterForStmt.init(
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

impl InForStmt.init(
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

impl WhileStmt.init(
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

impl WithStmt.init(
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

impl ExprAsItem.init(
    self: ExprAsItem, expr: Expr, alias: (Expr | None), kid: Sequence[UniNode]
) -> None {
    self.expr = expr;
    self.alias = alias;
    UniNode.init(self, kid=kid);
}

impl RaiseStmt.init(
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

impl AssertStmt.init(
    self: AssertStmt, condition: Expr, error_msg: (Expr | None), kid: Sequence[UniNode]
) -> None {
    self.condition = condition;
    self.error_msg = error_msg;
    UniNode.init(self, kid=kid);
    CodeBlockStmt.init(self);
}

impl CtrlStmt.init(self: CtrlStmt, ctrl: Token, kid: Sequence[UniNode]) -> None {
    self.ctrl = ctrl;
    UniNode.init(self, kid=kid);
    CodeBlockStmt.init(self);
}

impl DeleteStmt.init(self: DeleteStmt, target: Expr, kid: Sequence[UniNode]) -> None {
    self.target = target;
    UniNode.init(self, kid=kid);
    CodeBlockStmt.init(self);
}

"""Get Python AST targets (without setting ctx)."""
@ property
impl DeleteStmt.py_ast_targets(self: DeleteStmt) -> list[ast3.AST] {
    return [i.gen.py_ast[0] for i in self.target.values]
    if (isinstance(self.target, TupleVal) and self.target.values)
    else self.target.gen.py_ast;
}

impl ReportStmt.init(self: ReportStmt, expr: Expr, kid: Sequence[UniNode]) -> None {
    self.expr = expr;
    UniNode.init(self, kid=kid);
    CodeBlockStmt.init(self);
}

impl ReturnStmt.init(
    self: ReturnStmt, expr: (Expr | None), kid: Sequence[UniNode]
) -> None {
    self.expr = expr;
    UniNode.init(self, kid=kid);
    CodeBlockStmt.init(self);
}

impl VisitStmt.init(
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

"""Initialize disengage statement node."""
impl DisengageStmt.init(self: DisengageStmt, kid: Sequence[UniNode]) -> None {
    UniNode.init(self, kid=kid);
    WalkerStmtOnlyNode.init(self);
    CodeBlockStmt.init(self);
}

impl AwaitExpr.init(self: AwaitExpr, target: Expr, kid: Sequence[UniNode]) -> None {
    self.target = target;
    UniNode.init(self, kid=kid);
    Expr.init(self);
}

impl GlobalStmt.init(
    self: GlobalStmt, target: Sequence[NameAtom], kid: Sequence[UniNode]
) -> None {
    self.target: list[NameAtom] = `list(target);
    UniNode.init(self, kid=kid);
    CodeBlockStmt.init(self);
}

impl Assignment.init(
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

impl ConcurrentExpr.init(
    self: ConcurrentExpr, tok: (Token | None), target: Expr, kid: Sequence[UniNode]
) -> None {
    UniNode.init(self, kid=kid);
    Expr.init(self);
    self.tok = tok;
    self.target = target;
}

impl BinaryExpr.init(
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

impl CompareExpr.init(
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

impl BoolExpr.init(
    self: BoolExpr, op: Token, values: list[Expr], kid: Sequence[UniNode]
) -> None {
    self.values = values;
    self.op = op;
    UniNode.init(self, kid=kid);
    Expr.init(self);
}

impl LambdaExpr.init(
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

impl UnaryExpr.init(
    self: UnaryExpr, operand: Expr, op: Token, kid: Sequence[UniNode]
) -> None {
    self.operand = operand;
    self.op = op;
    UniNode.init(self, kid=kid);
    Expr.init(self);
}

impl IfElseExpr.init(
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

impl MultiString.init(
    self: MultiString, strings: Sequence[(String | FString)], kid: Sequence[UniNode]
) -> None {
    self.strings = strings;
    UniNode.init(self, kid=kid);
    Expr.init(self);
    AstSymbolStubNode.init(self, sym_type=SymbolType.STRING);
}

impl FString.init(
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

impl FormattedValue.init(
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

impl ListVal.init(
    self: ListVal, values: Sequence[Expr], kid: Sequence[UniNode]
) -> None {
    self.values = values;
    UniNode.init(self, kid=kid);
    Expr.init(self);
    AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
}

impl SetVal.init(
    self: SetVal, values: (Sequence[Expr] | None), kid: Sequence[UniNode]
) -> None {
    self.values: list[Expr] = `list(values) if values else [];
    UniNode.init(self, kid=kid);
    Expr.init(self);
    AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
}

impl TupleVal.init(
    self: TupleVal, values: Sequence[(Expr | KWPair)], kid: Sequence[UniNode]
) -> None {
    self.values = `list(values);
    UniNode.init(self, kid=kid);
    Expr.init(self);
    AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
}

impl DictVal.init(
    self: DictVal, kv_pairs: Sequence[KVPair], kid: Sequence[UniNode]
) -> None {
    self.kv_pairs = kv_pairs;
    UniNode.init(self, kid=kid);
    Expr.init(self);
    AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
}

impl KVPair.init(
    self: KVPair, key: (Expr | None), value: Expr, kid: Sequence[UniNode]
) -> None {
    self.key = key;
    self.value = value;
    UniNode.init(self, kid=kid);
}

impl KWPair.init(
    self: KWPair, key: (NameAtom | None), value: Expr, kid: Sequence[UniNode]
) -> None {
    self.key = key;
    self.value = value;
    UniNode.init(self, kid=kid);
}

impl InnerCompr.init(
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

impl ListCompr.init(
    self: ListCompr, out_expr: Expr, compr: list[InnerCompr], kid: Sequence[UniNode]
) -> None {
    self.out_expr = out_expr;
    self.compr = compr;
    UniNode.init(self, kid=kid);
    Expr.init(self);
    AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
    UniScopeNode.init(self, name=f"{self.__class__.__name__}");
}

impl DictCompr.init(
    self: DictCompr, kv_pair: KVPair, compr: list[InnerCompr], kid: Sequence[UniNode]
) -> None {
    self.kv_pair = kv_pair;
    self.compr = compr;
    UniNode.init(self, kid=kid);
    Expr.init(self);
    AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
    UniScopeNode.init(self, name=f"{self.__class__.__name__}");
}

impl AtomTrailer.init(
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

@ property
impl AtomTrailer.as_attr_list(self: AtomTrailer) -> list[AstSymbolNode] {
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

impl AtomUnit.init(
    self: AtomUnit, value: Expr | YieldExpr | Ability, kid: Sequence[UniNode]
) -> None {
    self.value = value;
    UniNode.init(self, kid=kid);
    Expr.init(self);
}

impl YieldExpr.init(
    self: YieldExpr, expr: (Expr | None), with_from: bool, kid: Sequence[UniNode]
) -> None {
    self.expr = expr;
    self.with_from = with_from;
    UniNode.init(self, kid=kid);
    Expr.init(self);
}

impl FuncCall.init(
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

impl IndexSlice.init(
    self: IndexSlice, slices: list[Slice], is_range: bool, kid: Sequence[UniNode]
) -> None {
    self.slices = slices;
    self.is_range = is_range;
    UniNode.init(self, kid=kid);
    Expr.init(self);
    AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
}

impl EdgeRefTrailer.init(
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

impl EdgeOpRef.init(
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

impl DisconnectOp.init(
    self: DisconnectOp, edge_spec: EdgeOpRef, kid: Sequence[UniNode]
) -> None {
    self.edge_spec = edge_spec;
    UniNode.init(self, kid=kid);
    WalkerStmtOnlyNode.init(self);
}

impl ConnectOp.init(
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

impl FilterCompr.init(
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

impl AssignCompr.init(
    self: AssignCompr, assigns: Sequence[KWPair], kid: Sequence[UniNode]
) -> None {
    self.assigns = `list(assigns);
    UniNode.init(self, kid=kid);
    Expr.init(self);
    AstSymbolStubNode.init(self, sym_type=SymbolType.SEQUENCE);
}

impl JsxElement.init(
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
    self.children: list[(JsxChild | JsxElement)] = `list(children) if children else [];
    self.is_self_closing = is_self_closing;
    self.is_fragment = is_fragment;
    UniNode.init(self, kid=kid);
    Expr.init(self);
    AstSymbolStubNode.init(self, sym_type=SymbolType.OBJECT_ARCH);
}

"""Get the source line after the opening tag's '>' token (body start)."""
impl JsxElement.get_body_start_line(self: JsxElement) -> (int | None) {
    if not self.kid {
        return None;
    }
    opening_tag = self.kid[0];
    if isinstance(opening_tag, JsxElement) {
        for k in opening_tag.kid {
            if (isinstance(k, Token) and (k.name == Tok.JSX_TAG_END) and k.loc) {
                return k.loc.last_line + 1;
            }
        }
    }
    return None;
}

"""Get the source line of the closing tag's '</' token (body end)."""
impl JsxElement.get_body_end_line(self: JsxElement) -> (int | None) {
    if not self.kid {
        return None;
    }
    closing_tag = self.kid[-1];
    if isinstance(closing_tag, JsxElement) {
        for k in closing_tag.kid {
            if (isinstance(k, Token) and (k.name == Tok.JSX_CLOSE_START) and k.loc) {
                return k.loc.first_line;
            }
        }
    }
    return None;
}

impl JsxElementName.init(
    self: JsxElementName, parts: Sequence[(Name | Token)], kid: Sequence[UniNode]
) -> None {
    self.parts = `list(parts);
    UniNode.init(self, kid=kid);
}

impl JsxAttribute.init(self: JsxAttribute, kid: Sequence[UniNode]) -> None {
    UniNode.init(self, kid=kid);
}

impl JsxSpreadAttribute.init(
    self: JsxSpreadAttribute, expr: Expr, kid: Sequence[UniNode]
) -> None {
    self.expr = expr;
    JsxAttribute.init(self, kid=kid);
}

impl JsxNormalAttribute.init(
    self: JsxNormalAttribute,
    name: (Name | Token),
    value: String | Expr | None,
    kid: Sequence[UniNode]
) -> None {
    self.name = name;
    self.value = value;
    JsxAttribute.init(self, kid=kid);
}

impl JsxChild.init(self: JsxChild, kid: Sequence[UniNode]) -> None {
    UniNode.init(self, kid=kid);
}

impl JsxText.init(self: JsxText, value: (str | Token), kid: Sequence[UniNode]) -> None {
    self.value = value;
    JsxChild.init(self, kid=kid);
}

"""Normalize JSX text whitespace (single source of truth).

    HTML-like rules: strip leading/trailing newline+whitespace,
    collapse internal newline+whitespace sequences to a single space.
    """
impl JsxText.get_normalized_text(self: JsxText) -> str {
    import re;
    raw = self.value.value if isinstance(self.value, Token) else str(self.value);
    stripped = raw.strip();
    if not stripped {
        return "";
    }
    # Strip leading newline+whitespace, trailing whitespace
    result = re.sub(r'^\s*\n\s*', '', raw).rstrip();
    if not result {
        result = stripped;
    }
    # Collapse internal newline+whitespace to single space
    return re.sub(r'\s*\n\s*', ' ', result);
}

impl JsxExpression.init(
    self: JsxExpression, expr: Expr, kid: Sequence[UniNode]
) -> None {
    self.expr = expr;
    JsxChild.init(self, kid=kid);
}

impl MatchStmt.init(
    self: MatchStmt, target: Expr, cases: list[MatchCase], kid: Sequence[UniNode]
) -> None {
    self.target = target;
    self.cases = cases;
    UniNode.init(self, kid=kid);
    CodeBlockStmt.init(self);
}

impl MatchCase.init(
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

impl SwitchStmt.init(
    self: SwitchStmt, target: Expr, cases: list[SwitchCase], kid: Sequence[UniNode]
) -> None {
    self.target = target;
    self.cases = cases;
    UniNode.init(self, kid=kid);
    CodeBlockStmt.init(self);
}

impl SwitchCase.init(
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

impl MatchOr.init(
    self: MatchOr, patterns: list[MatchPattern], kid: Sequence[UniNode]
) -> None {
    self.patterns = patterns;
    UniNode.init(self, kid=kid);
}

impl MatchAs.init(
    self: MatchAs,
    name: NameAtom,
    pattern: (MatchPattern | None),
    kid: Sequence[UniNode]
) -> None {
    self.name = name;
    self.pattern = pattern;
    UniNode.init(self, kid=kid);
}

impl MatchValue.init(self: MatchValue, value: Expr, kid: Sequence[UniNode]) -> None {
    self.value = value;
    UniNode.init(self, kid=kid);
}

impl MatchSingleton.init(
    self: MatchSingleton, value: (Bool | Null), kid: Sequence[UniNode]
) -> None {
    self.value = value;
    UniNode.init(self, kid=kid);
}

impl MatchSequence.init(
    self: MatchSequence, values: list[MatchPattern], kid: Sequence[UniNode]
) -> None {
    self.values = values;
    UniNode.init(self, kid=kid);
}

impl MatchMapping.init(
    self: MatchMapping, values: list[(MatchKVPair | MatchStar)], kid: Sequence[UniNode]
) -> None {
    self.values = values;
    UniNode.init(self, kid=kid);
}

impl MatchKVPair.init(
    self: MatchKVPair,
    key: MatchPattern | NameAtom | AtomExpr,
    value: MatchPattern,
    kid: Sequence[UniNode]
) -> None {
    self.key = key;
    self.value = value;
    UniNode.init(self, kid=kid);
}

impl MatchStar.init(
    self: MatchStar, name: NameAtom, is_list: bool, kid: Sequence[UniNode]
) -> None {
    self.name = name;
    self.is_list = is_list;
    UniNode.init(self, kid=kid);
}

impl MatchArch.init(
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

impl Token.init(
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

impl Token.__repr__(self: Token) -> str {
    return f"Token({self.name}, {self.value}, {self.loc})";
}

impl Token.unparse(self: Token) -> str {
    if self.gen.jac {
        return self.gen.jac;
    }
    return self.value;
}

impl Name.init(
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

impl SpecialVarRef.init(
    self: SpecialVarRef, var: Name, is_enum_stmt: bool = False
) -> None {
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

impl SpecialVarRef.py_resolve_name(self: SpecialVarRef) -> str {
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
        return 'init';
    } elif (self.orig.name == Tok.KW_POST_INIT) {
        return '__post_init__';
    } else {
        raise NotImplementedError('ICE: Special var reference not implemented') ;
    }
}

impl Literal.init(
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
@ property
impl Literal.lit_value(
    self: Literal
) -> int | str | float | bool | None | Callable[([], Any)] | EllipsisType {
    raise NotImplementedError ;
}

"""Return literal value in its python type."""
@ property
impl BuiltinType.lit_value(self: BuiltinType) -> Callable[([], Any)] {
    if (self.value not in Literal.type_map) {
        raise TypeError(f"ICE: {self.value} is not a callable builtin") ;
    }
    return Literal.type_map[self.value];
}

@ property
impl Float.lit_value(self: Float) -> float {
    return float(self.value);
}

@ property
impl Int.lit_value(self: Int) -> int {
    return int(self.value, 0);
}

@ property
impl String.lit_value(self: String) -> str {
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
                    or (self.value.startswith("'''") and self.value.endswith("'''"))
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

@ property
impl Bool.lit_value(self: Bool) -> bool {
    return (self.value == 'True');
}

@ property
impl Null.lit_value(self: Null) -> None {
    return None;
}

@ property
impl Ellipsis.lit_value(self: Ellipsis) -> EllipsisType {
    return ...;
}

impl EmptyToken.init(self: EmptyToken, orig_src: (Source | None) = None) -> None {
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

"""Initialize token."""
impl Semi.init(
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

impl CommentToken.init(
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

@ property
impl CommentToken.left_node(self: CommentToken) -> (UniNode | None) {
    if (self.parent and ((idx := self.parent.kid.index(self)) > 0)) {
        return self.parent.kid[(idx - 1)];
    }
    return None;
}

@ property
impl CommentToken.right_node(self: CommentToken) -> (UniNode | None) {
    if (
        self.parent
        and ((idx := self.parent.kid.index(self)) < (len(self.parent.kid) - 1))
    ) {
        return self.parent.kid[(idx + 1)];
    }
    return None;
}

impl Source.init(self: Source, source: str, mod_path: str) -> None {
    super.init(self);
    self.value = source;
    self.hash = md5(source.encode()).hexdigest();
    self.file_path = mod_path;
    self.comments: list[CommentToken] = [];
}

"""Return the source code as string."""
@ property
impl Source.code(self: Source) -> str {
    return self.value;
}

impl PythonModuleAst.init(
    self: PythonModuleAst, ast: ast3.Module, orig_src: Source
) -> None {
    super.init();
    self.ast = ast;
    self.orig_src = orig_src;
    self.file_path = orig_src.file_path;
}
