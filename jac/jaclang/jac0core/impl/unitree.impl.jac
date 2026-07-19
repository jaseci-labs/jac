impl UniNode.postinit -> None {
    self.parent = None;
    self.kid = [x.set_parent(self) for x in self.kid];
    self.__sub_node_tab = None;
    self._in_mod_nodes = [];
    self._gen = None;
    self.loc = CodeLocInfo(*self.resolve_tok_range());
}


impl UniNode._sub_node_tab.getter -> dict[(type, list[UniNode])] {
    if (self.__sub_node_tab is None) {
        self.__sub_node_tab = {};
        self._construct_sub_node_tab();
    }
    return self.__sub_node_tab;
}

impl UniNode._construct_sub_node_tab -> None {
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

impl UniNode._invalidate_sub_node_tab -> None {
    cur: (UniNode | None) = self;
    while cur is not None and cur.__sub_node_tab is not None {
        cur.__sub_node_tab = None;
        cur = cur.parent;
    }
}

impl UniNode.sym_tab.getter -> UniScopeNode {
    nd: (UniNode | None) = self;

    while nd is not None {
        if isinstance(nd, UniScopeNode) {
            if isinstance(nd, Module) {
                return nd;
            }

            if nd.parent_scope is not None {
                return nd;
            }
        }
        nd = nd.parent;
    }
    raise ValueError("No scope found");
}

impl UniNode.add_kids_left(
    nodes: Sequence[UniNode], pos_update: bool = True, parent_update: bool = False
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
    self._invalidate_sub_node_tab();
    return self;
}

impl UniNode.add_kids_right(
    nodes: Sequence[UniNode], pos_update: bool = True, parent_update: bool = False
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
    self._invalidate_sub_node_tab();
    return self;
}

impl UniNode.insert_kids_at_pos(
    nodes: Sequence[UniNode], pos: int, pos_update: bool = True
) -> UniNode {
    self.kid = [*self.kid[:pos], *nodes, *self.kid[pos:]];
    if pos_update {
        for i in nodes {
            i.parent = self;
        }
        self.loc.update_token_range(*self.resolve_tok_range());
    }
    self._invalidate_sub_node_tab();
    return self;
}

impl UniNode.set_kids(nodes: Sequence[UniNode]) -> UniNode {
    self.kid = [*nodes];
    for i in nodes {
        i.parent = self;
    }
    self.loc.update_token_range(*self.resolve_tok_range());
    self._invalidate_sub_node_tab();
    return self;
}

impl UniNode.set_parent(parent: UniNode) -> UniNode {
    self.parent = parent;
    return self;
}

impl UniNode.resolve_tok_range -> tuple[(Token, Token)] {
    if len(self.kid) {
        return (self.kid[0].loc.first_tok, self.kid[-1].loc.last_tok);
    } elif isinstance(self, Token) {
        return (self, self);
    } else {
        raise ValueError(f"Empty kid for Token {type(self).__name__}");
    }
}

impl UniNode.gen_token(name: Tok, value: (str | None) = None) -> Token {
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

impl UniNode.get_all_sub_nodes(typ: type[T]) -> list[T] {
    import from jaclang.jac0core.passes { UniPass }
    return UniPass.get_all_sub_nodes(nd=self, typ=typ);
}

impl UniNode.find_parent_of_type(typ: type[T]) -> (T | None) {
    import from jaclang.jac0core.passes { UniPass }
    return UniPass.find_parent_of_type(nd=self, typ=typ);
}

impl UniNode.parent_of_type(typ: type[T]) -> T {
    ret = self.find_parent_of_type(typ);
    if isinstance(ret, typ) {
        return ret;
    } else {
        raise ValueError(f"Parent of type {typ} not found from{type(self)}.");
    }
}

impl UniNode.codespace -> CodeContext {
    import from jaclang.jac0core.ext_registry { is_client_module, is_native_module }
    if isinstance(self, ContextAwareNode) {
        if (self.code_context == CodeContext.CLIENT) {
            return CodeContext.CLIENT;
        }
        if (self.code_context == CodeContext.NATIVE) {
            return CodeContext.NATIVE;
        }
    }
    nd: (UniNode | None) = self.parent;
    while (nd is not None) {
        if isinstance(nd, ServerBlock) {
            return CodeContext.SERVER;
        }
        if isinstance(nd, ClientBlock) {
            return CodeContext.CLIENT;
        }
        if isinstance(nd, NativeBlock) {
            return CodeContext.NATIVE;
        }
        if isinstance(nd, ContextAwareNode) {
            if nd._source_context_token() is not None {
                return nd.code_context;
            }
            context = nd.code_context;
            if (context == CodeContext.CLIENT) {
                return CodeContext.CLIENT;
            }
            if (context == CodeContext.NATIVE) {
                return CodeContext.NATIVE;
            }
        }
        if isinstance(nd, Module) {
            if nd.decided_codespace == CodeContext.NATIVE.value {
                return CodeContext.NATIVE;
            }
            if nd.decided_codespace == CodeContext.CLIENT.value {
                return CodeContext.CLIENT;
            }
            mp = nd.loc.mod_path if nd.loc is not None else '';
            if mp and is_native_module(mp) {
                return CodeContext.NATIVE;
            }
            if mp and is_client_module(mp) {
                return CodeContext.CLIENT;
            }
            return CodeContext.SERVER;
        }
        nd = nd.parent;
    }
    return CodeContext.SERVER;
}

impl UniNode.in_client_context -> bool {
    return self.codespace() == CodeContext.CLIENT;
}

impl UniNode.in_native_context -> bool {
    return self.codespace() == CodeContext.NATIVE;
}

impl Module.declares_codespace(ctx: CodeContext, path_hint: str = '') -> bool {
    import from jaclang.jac0core.ext_registry { is_client_module, is_native_module }
    if ctx != CodeContext.SERVER and self.decided_codespace == ctx.value {
        return True;
    }
    mp = self.loc.mod_path
        if (self.loc is not None and self.loc.mod_path)
        else path_hint;
    if ctx == CodeContext.NATIVE and bool(mp) and is_native_module(mp) {
        return True;
    }
    if ctx == CodeContext.CLIENT and bool(mp) and is_client_module(mp) {
        return True;
    }
    if self.body {
        for _stmt in self.body {
            if ctx == CodeContext.NATIVE and isinstance(_stmt, NativeBlock) {
                return True;
            }
            if ctx == CodeContext.CLIENT and isinstance(_stmt, ClientBlock) {
                return True;
            }

            if ctx != CodeContext.SERVER
            and isinstance(_stmt, ContextAwareNode)
            and _stmt.code_context == ctx {
                return True;
            }
        }
    }
    return False;
}

impl UniNode.to_dict -> dict[(str, str)] {
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

impl UniNode.pp(depth: (int | None) = None) -> str {
    return print_ast_tree(self, max_depth=depth);
}

impl UniNode.printgraph -> str {
    return printgraph_ast_tree(self);
}

impl UniNode.flatten -> list[UniNode] {
    ret: list[UniNode] = [self];
    for k in self.kid {
        ret += k.flatten();
    }
    return ret;
}

impl UniNode.unparse -> str {
    if self.gen.jac {
        return self.gen.jac;
    }
    return ' '.join([i.unparse() for i in self.kid]);
}


impl Symbol.init(
    defn: NameAtom,
    access: SymbolAccess,
    parent_tab: (UniScopeNode | None) = None,
    imported: bool = False
) -> None {
    self.defn = [defn];
    self.uses = [];
    self.imported = imported;
    defn.sym = self;
    self.access = access;
    self.parent_tab = parent_tab;
    self.semstr = '';
}

impl Symbol.decl.getter -> NameAtom {
    return self.defn[0];
}

impl Symbol.sym_name.getter -> str {
    return self.decl.sym_name;
}

impl Symbol.sym_type.getter -> SymbolType {
    return self.decl.sym_category;
}

impl Symbol.sym_dotted_name.getter -> str {
    out = [self.defn[0].sym_name];
    current_tab: (UniScopeNode | None) = self.parent_tab;
    while (current_tab is not None) {
        out.append(current_tab.scope_name);
        current_tab = current_tab.parent_scope;
    }
    out.reverse();
    return '.'.join(out);
}

impl Symbol.symbol_table.getter -> (UniScopeNode | None) {
    if self.parent_tab {
        return self.parent_tab.find_scope(self.sym_name);
    }
    return None;
}

impl Symbol.storage.getter -> SymbolStorage {
    owner = self.parent_tab;
    while (
        owner is not None
        and not isinstance(owner, UniScopeNode.get_python_scoping_nodes())
    ) {
        owner = owner.parent_scope;
    }
    if (owner is None) or isinstance(owner, Module) {
        return SymbolStorage.MODULE_GLOBAL;
    }
    if isinstance(owner, (Archetype, Enum)) {
        return SymbolStorage.CLASS_FIELD;
    }

    if isinstance(self.decl.name_of, ParamVar) {
        return SymbolStorage.PARAM;
    }

    barriers = UniScopeNode.get_python_scoping_nodes();
    def_scope: (UniNode | None) = self.decl.parent;
    while (
        def_scope is not None
        and not isinstance(def_scope, barriers)
        and not isinstance(def_scope, LambdaExpr)
    ) {
        def_scope = def_scope.parent;
    }
    for use in self.uses {
        cur = use.parent;
        while (
            cur is not None
            and not isinstance(cur, barriers)
            and not isinstance(cur, LambdaExpr)
        ) {
            cur = cur.parent;
        }
        if (cur is None) or (cur is def_scope) {
            continue;
        }

        if isinstance(cur, ImplDef) and (cur.decl_link is def_scope) {
            continue;
        }
        if isinstance(def_scope, ImplDef) and (def_scope.decl_link is cur) {
            continue;
        }
        return SymbolStorage.CAPTURED;
    }
    return SymbolStorage.LOCAL;
}

impl Symbol.add_defn(nd: NameAtom) -> None {
    self.defn.append(nd);
    nd.sym = self;
}

impl Symbol.add_use(nd: NameAtom) -> None {
    self.uses.append(nd);
    nd.sym = self;
}

impl Symbol.__repr__ -> str {
    return f"Symbol({self.sym_name}, {self.sym_type}, {self.access},{self.defn})";
}

impl UniScopeNode._init_scope(
    name: str, parent_scope: (UniScopeNode | None) = None
) -> None {
    self.scope_name = name;
    self.parent_scope = parent_scope;
    self.kid_scope: list[UniScopeNode] = [];
    self.names_in_scope: dict[(str, Symbol)] = {};
    self.names_in_scope_overload: dict[(str, list[Symbol])] = {};
    self.implicit_rebinds: dict[(str, Symbol)] = {};
}

impl UniScopeNode.lookup(
    name: str, deep: bool = True, incl_inner_scope: bool = False
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

    impl_def: ImplDef | None = (
        self if isinstance(self, ImplDef) else self.find_parent_of_type(ImplDef)
    );
    if (impl_def and impl_def.decl_link and impl_def.decl_link.sym_tab) {
        return impl_def.decl_link.sym_tab.lookup(
            name, deep=True, incl_inner_scope=False
        );
    }
    return None;
}

impl UniScopeNode.lookup_all(name: str, deep: bool = True) -> list[Symbol] {
    result: list[Symbol] = [];
    if name in self.names_in_scope {
        result.append(self.names_in_scope[name]);
    }
    if name in self.names_in_scope_overload {
        result.extend(self.names_in_scope_overload[name]);
    }
    if result {
        return result;
    }
    if deep and self.parent_scope {
        return self.parent_scope.lookup_all(name, deep);
    }
    return result;
}

impl UniScopeNode.insert(
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

impl UniScopeNode.find_scope(name: str) -> (UniScopeNode | None) {
    for k in self.kid_scope {
        if (k.scope_name == name) {
            return k;
        }
    }
    return None;
}

impl UniScopeNode.get_enclosing_captures -> list[Symbol] {
    out: list[Symbol] = [];
    func_scopes = (Ability, ImplDef, LambdaExpr, Test);
    for name in self.get_all_sub_nodes(Name) {
        sym = name.sym;
        if (sym is None) {
            continue;
        }
        tab = sym.parent_tab;
        if ((tab is None) or (tab is self) or not isinstance(tab, func_scopes)) {
            continue;
        }

        scope = self.parent_scope;
        while (scope is not None) {
            if (scope is tab) {
                if sym not in out {
                    out.append(sym);
                }
                break;
            }
            scope = scope.parent_scope;
        }
    }
    return out;
}

impl UniScopeNode.link_kid_scope(key_node: UniScopeNode) -> UniScopeNode {
    key_node.parent_scope = self;
    self.kid_scope.append(key_node);
    return self.kid_scope[-1];
}

impl UniScopeNode.def_insert(
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

impl UniScopeNode.chain_def_insert(node_list: list[AstSymbolNode]) -> None {
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

impl UniScopeNode.use_lookup(
    nd: AstSymbolNode, sym_table: (UniScopeNode | None) = None
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

impl UniScopeNode.chain_use_lookup(node_list: Sequence[AstSymbolNode]) -> None {
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

impl UniScopeNode.update_py_ctx_for_def(nd: AstSymbolNode) -> None {
    nd.name_spec.py_ctx_func = ast3.Store;
    if (isinstance(nd, (TupleVal, ListVal)) and nd.values) {
        def fix(item: TupleVal | ListVal | UnaryExpr) {
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

impl UniScopeNode.sym_pp(depth: (int | None) = None) -> str {
    return print_symtab_tree(root_node=self, depth=depth);
}

impl UniScopeNode.sym_printgraph -> str {
    return printgraph_symtab_tree(self);
}

impl UniScopeNode.__repr__ -> str {
    out = f"{self.scope_name} {super().__repr__()}:\n";
    for (k, v) in self.names_in_scope.items() {
        out += f"    {k}: {v}\n";
    }
    return out;
}

impl AstSymbolNode._init_symbol(
    sym_name: str, name_spec: NameAtom, sym_category: SymbolType
) -> None {
    self.name_spec = name_spec;
    self.name_spec.name_of = self;
    self.name_spec._sym_name = sym_name;
    self.name_spec._sym_category = sym_category;
    self.semstr = '';
}


impl AstSymbolNode.sym.getter -> (Symbol | None) {
    return self.name_spec.sym;
}

impl AstSymbolNode.sym_name.getter -> str {
    return self.name_spec.sym_name;
}

impl AstSymbolNode.sym_category.getter -> SymbolType {
    return self.name_spec.sym_category;
}

impl AstSymbolNode.py_ctx_func.getter -> type[ast3.AST] {
    return self.name_spec.py_ctx_func;
}

impl AstSymbolNode.type_sym_tab.getter -> (UniScopeNode | None) {
    return self.name_spec.type_sym_tab;
}

impl AstSymbolStubNode._init_stub(sym_type: SymbolType) -> None {
    AstSymbolNode._init_symbol(
        self,
        sym_name=f"[{self.__class__.__name__}]",
        name_spec=Name.gen_stub_from_node(self, f"[{self.__class__.__name__}]"),
        sym_category=sym_type
    );
}


impl AstAccessNode.access_type.getter -> SymbolAccess {
    return SymbolAccess.PRIVATE
        if (self.access and (self.access.tag.name == Tok.KW_PRIV))
        else SymbolAccess.PROTECTED
            if (self.access and (self.access.tag.name == Tok.KW_PROT))
            else SymbolAccess.PUBLIC;
}

impl AstAccessNode.public_access.getter -> bool {
    return (self.access_type == SymbolAccess.PUBLIC);
}

impl ContextAwareNode.postinit -> None {
    self.code_context = CodeContext.SERVER;
}


impl ContextAwareNode._source_context_token -> (Token | None) {
    for kid in self.kid {
        if (
            isinstance(kid, Token)
            and (kid.name in (Tok.KW_CLIENT, Tok.KW_SERVER, Tok.KW_NATIVE))
        ) {
            return kid;
        }
    }
    return None;
}

impl WalkerStmtOnlyNode.postinit -> None {
    self.from_walker = False;
}


impl UniCFGNode.postinit -> None {
    self.bb_in = [];
    self.bb_out = [];

    self.affected_symbols = set();
}

impl ConditionalNode.postinit -> None {
    UniCFGNode.postinit(self);
}

impl CfgExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    ConditionalNode.postinit(self);
}


impl UniCFGNode.get_head -> UniCFGNode {
    nd = self;
    while (
        nd.bb_in
        and (len(nd.bb_in) == 1)
        and not isinstance(
            nd,
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and not isinstance(
            nd.bb_in[0],
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and nd.bb_in[0].bb_out
        and (len(nd.bb_in[0].bb_out) == 1)
    ) {
        nd = nd.bb_in[0];
    }
    return nd;
}

impl UniCFGNode.get_tail -> UniCFGNode {
    nd = self;
    while (
        nd.bb_out
        and (len(nd.bb_out) == 1)
        and not isinstance(
            nd,
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and not isinstance(
            nd.bb_out[0],
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and nd.bb_out[0].bb_in
        and (len(nd.bb_out[0].bb_in) == 1)
    ) {
        nd = nd.bb_out[0];
    }
    return nd;
}

impl Expr.postinit -> None {
    self._type_sym_tab = None;
    self.type = None;
    self.attached_tokens = None;
}


impl CodeBlockStmt.postinit -> None {
    UniCFGNode.postinit(self);
}


impl AstImplNeedingNode.needs_impl.getter -> bool {
    return (self.body is None);
}

impl NameAtom.postinit -> None {
    self.name_of = self;
    self._sym = None;
    self._sym_name = '';
    self._sym_category = SymbolType.UNKNOWN;
    self._py_ctx_func = ast3.Load;
    AtomExpr.postinit(self);
}


impl NameAtom.sym_name.getter -> str {
    return self._sym_name;
}

impl NameAtom.sym_category.getter -> SymbolType {
    return self._sym_category;
}

impl NameAtom.create_symbol(
    access: SymbolAccess,
    parent_tab: (UniScopeNode | None) = None,
    imported: bool = False
) -> Symbol {
    sym = Symbol(defn=self, access=access, parent_tab=parent_tab, imported=imported);
    return sym;
}

impl NameAtom.clean_type.getter -> str {
    if self.type {
        return str(self.type).replace('builtins.', '');
    }
    return '';
}

impl NameAtom.sem_token.getter -> (tuple[(SemTokType, SemTokMod)] | None) {
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
        if self.type is not None
        and type(self.type).__name__ in ('FunctionType', 'OverloadedType') {
            return (SemTokType.FUNCTION, SemTokMod.DEFINITION);
        }
        return (SemTokType.PROPERTY, SemTokMod.DEFINITION);
    }

    if self.is_getattr_resolved {
        return (SemTokType.PROPERTY, SemTokMod.DEFINITION);
    }
    return None;
}

impl ArchSpec.postinit -> None {
    CodeBlockStmt.postinit(self);
}


impl SubTag.postinit -> None {
    UniNode.postinit(self);
}


impl Module.postinit -> None {
    self.src_terminals = self.terminals;
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=self.name);
}


impl Module.annexable_by.getter -> (str | None) {
    if self.stub_only {
        return None;
    }
    return discover_base_file(self.loc.mod_path);
}

impl Module.format -> str {
    import from jaclang.compiler.passes.tool.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.passes.tool.jac_formatter_pass { JacFormatPass }
    import from jaclang.jac0core.program { JacProgram }
    return JacFormatPass(
        ir_in=DocIRGenPass(ir_in=self, prog=JacProgram()).ir_out, prog=JacProgram()
    ).ir_out.gen.jac;
}

impl Module.unparse(requires_format: bool = True) -> str {
    import from jaclang.compiler.passes.tool.normalize_pass { NormalizePass }
    import from jaclang.jac0core.program { JacProgram }

    own_path = self.loc.mod_path;
    saved_body = self.body;
    saved_kid = self.kid;
    head_kid = [
        k
        for k in saved_kid
        if (not k.loc.mod_path) or (k.loc.mod_path == own_path)
    ];
    filtered = len(head_kid) != len(saved_kid);
    if filtered {
        self.body = [
            st
            for st in saved_body
            if (not st.loc.mod_path) or (st.loc.mod_path == own_path)
        ];
        self.set_kids(nodes=head_kid or [EmptyToken()]);
    }
    try {
        NormalizePass(ir_in=self, prog=JacProgram());
        if requires_format {
            return self.format();
        }
        import from jaclang.compiler.passes.tool.unparse_pass { UnparsePass }
        UnparsePass(ir_in=self, prog=JacProgram());
        return self.gen.jac;
    } finally {
        if filtered {
            self.body = saved_body;
            self.set_kids(nodes=saved_kid);
        }
    }
}

impl ProgramModule.postinit -> None {
    self.main = self.main_mod or Module.make_stub();
    self.kid = [self.main];
    UniNode.postinit(self);
    self.hub = {self.loc.mod_path: self.main_mod} if self.main_mod else {};
}


impl TypeParam.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.TYPE
    );
}


impl TypeAlias.postinit -> None {
    self.type_params = `list(self.type_params) if self.type_params else [];
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.TYPE
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    ContextAwareNode.postinit(self);
}


impl GlobalVars.postinit -> None {
    UniNode.postinit(self);
    ContextAwareNode.postinit(self);
}


impl Test.postinit -> None {
    Test.TEST_COUNT += 1 if isinstance(self.name, Token) else 0;
    self.name: Name = self.name
        if isinstance(self.name, Name)
        else Name(
            orig_src=self.name.orig_src,
            name=Tok.NAME.value,
            value=f"_jac_gen_{Test.TEST_COUNT}",
            col_start=self.name.loc.col_start,
            col_end=self.name.loc.col_end,
            line=self.name.loc.first_line,
            end_line=self.name.loc.last_line,
            pos_start=self.name.pos_start,
            pos_end=self.name.pos_end
        );
    self.name.parent = self;
    self.name._sym_name = f"test_{self.name.value}"
        if not self.name.value.startswith('test_')
        else self.name.value;
    self.body = `list(self.body);
    UniNode.postinit(self);

    if (self.description is None and self.name not in self.kid) {
        self.insert_kids_at_pos([self.name], pos=1, pos_update=False);
    }
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.sym_name,
        name_spec=self.name,
        sym_category=SymbolType.TEST
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}


impl ModuleCode.postinit -> None {
    UniNode.postinit(self);
    ContextAwareNode.postinit(self);
}


impl ClientBlock.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
}


impl ServerBlock.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
}


impl NativeBlock.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
}


impl PyInlineCode.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl Import.postinit -> None {
    self.hint = None;
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}

impl Import.is_jac.getter -> bool {
    if (self.hint and (self.hint.tag.value == 'jac')) {
        return True;
    }
    if not self.hint {
        return self.__jac_detected;
    }
    return False;
}

impl Import.__jac_detected.getter -> bool {
    import from jaclang.jac0core.ext_registry { is_jac, INIT_FILES }
    if self.from_loc {
        if is_jac(self.from_loc.resolve_relative_path()) {
            return True;
        }
        if os.path.isdir(self.from_loc.resolve_relative_path()) {
            for init_name in INIT_FILES {
                if os.path.exists(
                    os.path.join(self.from_loc.resolve_relative_path(), init_name)
                ) {
                    return True;
                }
            }
            for i in self.items {
                if (
                    isinstance(i, ModuleItem)
                    and is_jac(self.from_loc.resolve_relative_path(i.name.value))
                ) {
                    return True;
                }
            }
        }
    }
    return `any(
        (isinstance(i, ModulePath) and is_jac(i.resolve_relative_path()))
        for i in self.items
    );
}

impl Import.has_string_path.getter -> bool {
    if (self.from_loc is not None and self.from_loc.string_path_value is not None) {
        return True;
    }
    for item in self.items {
        if (isinstance(item, ModulePath) and item.string_path_value is not None) {
            return True;
        }
    }
    return False;
}

impl Import.is_sv_marked.getter -> bool {
    tok = self._source_context_token();
    return (tok is not None and tok.name == Tok.KW_SERVER);
}

impl Import.is_cl_marked.getter -> bool {
    tok = self._source_context_token();
    return (tok is not None and tok.name == Tok.KW_CLIENT);
}

impl Import.is_virtual_jac.getter -> bool {
    if self.from_loc is not None {
        return self.from_loc.dot_path_str.startswith('@jac/');
    }
    for item in self.items {
        if isinstance(item, ModulePath) {
            spv = item.string_path_value;
            if (spv is not None and spv.startswith('@jac/')) {
                return True;
            }
        }
    }
    return False;
}

impl Import.has_clib_decls.getter -> bool {
    return bool(self.clib_decls);
}

impl Import.ecosystem.getter -> str {
    if self.has_clib_decls {
        return 'clib';
    }
    if self.is_virtual_jac {
        return 'virtual';
    }
    if self.has_string_path {
        return 'string';
    }
    if self.is_jac {
        return 'jac';
    }
    return 'py';
}

impl ModulePath.postinit -> None {
    self.abs_path = None;
    UniNode.postinit(self);
}


impl ModulePath.is_import_from.getter -> bool {
    if (self.parent and isinstance(self.parent, Import)) {
        return (self.parent.from_loc == self);
    }
    return False;
}

impl ModulePath.string_path_value.getter -> (str | None) {
    if (self.path and (len(self.path) == 1) and isinstance(self.path[0], String)) {
        return self.path[0].lit_value;
    }
    return None;
}

impl ModulePath.dot_path_str.getter -> str {
    spv = self.string_path_value;
    if spv is not None {
        return (('.' * self.level) + spv);
    }
    return (
        ('.' * self.level) + '.'.join([p.value for p in self.path] if self.path else [])
    );
}

impl ModulePath.base_module_name.getter -> str {
    spv = self.string_path_value;
    if spv is not None {
        return spv;
    }
    return '.'.join([p.value for p in self.path] if self.path else []);
}

impl ModulePath.resolve_relative_path(target_item: (str | None) = None) -> str {
    bundled = self.native_bundled_path();
    if bundled is not None {
        return bundled;
    }
    target = self.dot_path_str + (f".{target_item}" if target_item else '');
    return resolve_relative_path(target, self.loc.mod_path);
}

impl ModulePath.native_bundled_path -> (str | None) {
    import os;
    import from jaclang.jac0core.codeinfo {
        is_bundled_native_module,
        resolve_native_module
    }
    mod_path = self.loc.mod_path if self.loc else None;
    is_native = self.in_native_context()
    or (mod_path is not None and mod_path.endswith('.na.jac'));
    if not is_native {
        return None;
    }
    base = self.dot_path_str;
    if not is_bundled_native_module(base) {
        return None;
    }
    base_dir = os.path.dirname(mod_path) if mod_path else os.getcwd();
    (_src, full_path) = resolve_native_module(base, base_dir);
    return full_path;
}

impl ModulePath.resolve_relative_path_list -> list[str] {
    parts = self.dot_path_str.split('.');
    if not parts {
        return [];
    }

    full_path = self.resolve_relative_path();

    paths: list[str] = [''] * len(parts);
    paths[-1] = full_path;

    full_basename = os.path.basename(full_path);
    cur_dir = os.path.dirname(full_path);
    if full_basename.startswith('__init__') {
        cur_dir = os.path.dirname(cur_dir);
    }
    for i in range(len(parts) - 2, -1, -1) {
        init_found = False;
        for init_name in ('__init__.jac', '__init__.py', '__init__.pyi') {
            init_path = os.path.join(cur_dir, init_name);
            if os.path.isfile(init_path) {
                paths[i] = init_path;
                init_found = True;
                break;
            }
        }
        if not init_found {
            paths[i] = cur_dir;
        }
        cur_dir = os.path.dirname(cur_dir);
    }
    return paths;
}

impl ModuleItem.postinit -> None {
    UniNode.postinit(self);
    self.abs_path = None;
}


impl ModuleItem.from_parent.getter -> Import {
    if (not self.parent or not isinstance(self.parent, Import)) {
        raise ValueError('Import parent not found. Not Possible.');
    }
    return self.parent;
}

impl ModuleItem.from_mod_path.getter -> ModulePath {
    if not self.from_parent.from_loc {
        raise ValueError('Module items should have module path. Not Possible.');
    }
    return self.from_parent.from_loc;
}

impl ModuleItem.resolve_relative_path -> str {
    item_name = self.name.value if isinstance(self.name, Name) else None;

    if item_name is None {
        return self.from_mod_path.resolve_relative_path();
    }

    return self.from_mod_path.resolve_relative_path(target_item=item_name);
}

impl Archetype.postinit -> None {
    self.base_classes = `list(self.base_classes) if self.base_classes else [];
    self.type_params = `list(self.type_params) if self.type_params else [];
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category={
            Tok.KW_OBJECT.value: SymbolType.OBJECT_ARCH,
            Tok.KW_NODE.value: SymbolType.NODE_ARCH,
            Tok.KW_EDGE.value: SymbolType.EDGE_ARCH,
            Tok.KW_WALKER.value: SymbolType.WALKER_ARCH
        }.get(
            self.arch_type.name, SymbolType.TYPE
        )
    );
    ArchSpec.postinit(self);
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}


impl Archetype._get_impl_resolved_body -> list {
    return `list(self.body)
        if isinstance(self.body, Sequence)
        else `list(self.body.body)
            if (isinstance(self.body, ImplDef) and isinstance(self.body.body, Sequence))
            else [];
}

impl Archetype.is_abstract.getter -> bool {
    body = self._get_impl_resolved_body();
    return `any((isinstance(i, Ability) and i.is_abstract) for i in body);
}

impl Archetype.arch_kind.getter -> (str | None) {
    return {
        SymbolType.NODE_ARCH: "node",
        SymbolType.EDGE_ARCH: "edge",
        SymbolType.WALKER_ARCH: "walker"
    }.get(
        self.sym_category
    );
}

impl Archetype.get_has_vars -> list[HasVar] {
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

impl Archetype.get_methods -> list[Ability] {
    body = self._get_impl_resolved_body();
    methods: list[Ability] = [];
    for nd in body {
        if (isinstance(nd, Ability) and nd.is_method) {
            methods.append(nd);
        }
    }
    return methods;
}

impl ImplDef.postinit -> None {
    self.spec = `list(self.spec) if isinstance(self.spec, Sequence) else self.spec;
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=('impl.' + '.'.join([x.sym_name for x in self.target])),
        name_spec=self.create_impl_name_node(),
        sym_category=SymbolType.IMPL
    );
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=self.sym_name);
    ContextAwareNode.postinit(self);
}


impl ImplDef.create_impl_name_node -> Name {
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

impl SemDef.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=('sem.' + '.'.join([x.sym_name for x in self.target])),
        name_spec=self.create_sem_name_node(),
        sym_category=SymbolType.SEM
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
}


impl SemDef.create_sem_name_node -> Name {
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

impl Enum.postinit -> None {
    self.base_classes = `list(self.base_classes) if self.base_classes else [];
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.ENUM_ARCH
    );
    ArchSpec.postinit(self);
    UniScopeNode._init_scope(self, name=self.sym_name);
    ContextAwareNode.postinit(self);
}


impl Ability.postinit -> None {
    UniNode.postinit(self);
    if (self.name_ref is None) {
        first_tok = self.kid[0]
            if (self.kid and isinstance(self.kid[0], Token))
            else None;
        if (first_tok is None) {
            raise ValueError('Cannot create synthetic name_ref without location info.');
        }
        event_type = 'entry'
            if (
                isinstance(self.signature, EventSignature)
                and (self.signature.event.name == Tok.KW_ENTRY)
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
        name_spec_for_init = self.name_ref;
    }
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.py_resolve_name(),
        name_spec=name_spec_for_init,
        sym_category=SymbolType.ABILITY
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}


impl Ability.is_method.getter -> bool {
    return (self.method_owner is not None);
}

impl Ability.is_cls_method.getter -> bool {
    return (
        self.is_classmethod
        or (
            self.is_method
            and `any(
                (isinstance(dec, Name) and (dec.sym_name == 'classmethod'))
                for dec in (self.decorators or ())
            )
        )
    );
}

impl Ability.is_def.getter -> bool {
    return (not self.signature or isinstance(self.signature, FuncSignature));
}

impl Ability.method_owner.getter -> Archetype | Enum | None {
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
    if (found is None) and (self.accessor_kind != "") {
        nodew = self.parent;
        while nodew is not None {
            if isinstance(nodew, (Archetype, Enum)) {
                return nodew;
            }
            nodew = nodew.parent;
        }
    }
    return found;
}

impl Ability.is_genai_ability.getter -> bool {
    return isinstance(self.body, Expr);
}

impl Ability.py_resolve_name -> str {
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
        raise NotImplementedError;
    }
}

impl Ability.event_trigger_type_names -> (list[str] | None) {
    if self.event_triggers is None {
        return None;
    }
    names: list[str] = [];
    for t in self.event_triggers {
        for part in t.mangle().split("|") {
            name = part.strip();
            if name.startswith("type[") and name.endswith("]") {
                name = name[5:-1];
            }
            if name and name not in names {
                names.append(name);
            }
        }
    }
    return names;
}

impl FuncSignature.postinit -> None {
    self.posonly_params = `list(self.posonly_params);
    self.params = `list(self.params) if self.params else [];
    self.kwonlyargs = `list(self.kwonlyargs);
    UniNode.postinit(self);
}


impl FuncSignature.get_parameters -> list[ParamVar] {
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

impl FuncSignature.is_static.getter -> bool {
    return (
        (isinstance(self.parent, Ability) and self.parent.is_static)
        or (
            isinstance(self.parent, ImplDef)
            and isinstance(self.parent.decl_link, Ability)
            and self.parent.decl_link.is_static
        )
    );
}

impl FuncSignature.is_in_py_class.getter -> bool {
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

impl EventSignature.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}


impl ParamVar.postinit -> None {
    self.param_kind = ParamKind.NORMAL;
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self, sym_name=self.name.value, name_spec=self.name, sym_category=SymbolType.VAR
    );
}


impl ParamVar.is_vararg.getter -> bool {
    return bool((self.unpack and (self.unpack.name == Tok.STAR_MUL.name)));
}

impl ParamVar.is_kwargs.getter -> bool {
    return bool((self.unpack and (self.unpack.name == Tok.STAR_POW.name)));
}

impl ArchHas.postinit -> None {
    self.vars = `list(self.vars);
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl HasVar.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.HAS_VAR
    );
}


impl TypedCtxBlock.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}


impl OpenStmt.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl IfStmt.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl ElseStmt.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}


impl ExprStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl TryStmt.postinit -> None {
    self.body = `list(self.body);
    self.excepts = `list(self.excepts);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl Except.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl FinallyStmt.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl AwaitingClause.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl IterForStmt.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl InForStmt.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl WhileStmt.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl ForeverStmt.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl WithStmt.postinit -> None {
    self.body = `list(self.body);
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl ExprAsItem.postinit -> None {
    UniNode.postinit(self);
}


impl RaiseStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl AssertStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl CtrlStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl DeleteStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl DeleteStmt.py_ast_targets.getter -> list[ast3.AST] {
    return [i.gen.py_ast[0] for i in self.target.values]
        if (isinstance(self.target, TupleVal) and self.target.values)
        else self.target.gen.py_ast;
}

impl ReportStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl ReturnStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl VisitStmt.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl DisengageStmt.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl AwaitExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl CastExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl Assignment.postinit -> None {
    self.target = `list(self.target);
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl ConcurrentExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl BinaryExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl CompareExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl BoolExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl LambdaExpr.postinit -> None {
    if (isinstance(self.body, Sequence) and not isinstance(self.body, Expr)) {
        self.body = `list(self.body);
    } else {
        self.body = cast(Expr, self.body);
    }
    UniNode.postinit(self);
    Expr.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}

impl LambdaExpr.captures.getter -> list[Symbol] {
    return self.get_enclosing_captures();
}

impl LambdaExpr.tail_return_expr -> Expr | None {
    """Implicit return: a braced body consisting of a single expression
    statement returns that expression's value. Any other body (multiple
    statements, or a non-expression statement) uses an explicit `return`.""";
    if not (isinstance(self.body, Sequence) and not isinstance(self.body, Expr)) {
        return None;
    }
    stmts = [
        s
        for s in self.body
        if not isinstance(s, Semi)
    ];
    if (len(stmts) == 1 and isinstance(stmts[0], ExprStmt)) {
        return stmts[0].expr;
    }
    return None;
}


impl UnaryExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl IfElseExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl MultiString.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.STRING);
}

impl MultiString.lit_value.getter -> str | bytes {
    parts: list[str | bytes] = [];
    for s in self.strings {
        if isinstance(s, String) {
            parts.append(s.lit_value);
        }
    }

    if parts and isinstance(parts[0], `bytes) {
        return b"".join(parts);
    }
    return "".join(parts);
}


impl FString.postinit -> None {
    self.parts = `list(self.parts);
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.STRING);
}


impl FormattedValue.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl ListVal.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl SetVal.postinit -> None {
    self.values = `list(self.values) if self.values else [];
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl TupleVal.postinit -> None {
    self.values = `list(self.values);
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl DictVal.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl KVPair.postinit -> None {
    UniNode.postinit(self);
}


impl KWPair.postinit -> None {
    UniNode.postinit(self);
}


impl InnerCompr.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}


impl ListCompr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}


impl DictCompr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}


impl AtomTrailer.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl AtomTrailer.as_attr_list.getter -> list[AstSymbolNode] {
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

impl AtomUnit.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl YieldExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl FuncCall.postinit -> None {
    self.params = `list(self.params) if self.params else [];
    self.callee_decl = None;
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl Slice.postinit -> None {
    UniNode.postinit(self);
}


impl IndexSlice.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl EdgeRefTrailer.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}


impl EdgeOpRef.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl DisconnectOp.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}


impl ConnectOp.postinit -> None {
    UniNode.postinit(self);
}


impl FilterCompr.postinit -> None {
    self.compares = `list(self.compares);
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl AssignCompr.postinit -> None {
    self.assigns = `list(self.assigns);
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl JsxElement.postinit -> None {
    self.attributes = `list(self.attributes) if self.attributes else [];
    self.children = `list(self.children) if self.children else [];
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.OBJECT_ARCH);
}


impl JsxElement.get_body_start_line -> (int | None) {
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

impl JsxElement.get_body_end_line -> (int | None) {
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

impl JsxElementName.postinit -> None {
    self.parts = `list(self.parts);
    UniNode.postinit(self);
}


impl JsxAttribute.postinit -> None {
    UniNode.postinit(self);
}


impl JsxSpreadAttribute.postinit -> None {
    JsxAttribute.postinit(self);
}


impl JsxNormalAttribute.postinit -> None {
    JsxAttribute.postinit(self);
}


impl JsxChild.postinit -> None {
    UniNode.postinit(self);
}


impl JsxText.postinit -> None {
    JsxChild.postinit(self);
}


impl JsxText.get_normalized_text -> str {
    import re;
    raw = self.value.value if isinstance(self.value, Token) else str(self.value);
    if not raw {
        return "";
    }
    lines = re.split(r'\r\n|\n|\r', raw);

    last_non_empty = -1;
    for i in range(len(lines)) {
        if re.search(r'[^ \t]', lines[i]) {
            last_non_empty = i;
        }
    }
    result = "";
    for i in range(len(lines)) {
        line = lines[i].replace('\t', ' ');
        is_first = i == 0;
        is_last = i == len(lines) - 1;
        if not is_first {
            line = re.sub(r'^[ ]+', '', line);
        }
        if not is_last {
            line = re.sub(r'[ ]+$', '', line);
        }
        if line {
            if last_non_empty >= 0 and i != last_non_empty {
                line += ' ';
            }
            result += line;
        }
    }
    return result;
}

impl JsxExpression.postinit -> None {
    JsxChild.postinit(self);
}


impl JsxSlot.postinit -> None {
    JsxChild.postinit(self);
}


impl JsxComment.postinit -> None {
    JsxChild.postinit(self);
}


impl MatchStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl MatchCase.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}


impl SwitchStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl SwitchCase.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}


impl MatchOr.postinit -> None {
    UniNode.postinit(self);
}


impl MatchAs.postinit -> None {
    UniNode.postinit(self);
}


impl MatchValue.postinit -> None {
    UniNode.postinit(self);
}


impl MatchSingleton.postinit -> None {
    UniNode.postinit(self);
}


impl MatchSequence.postinit -> None {
    UniNode.postinit(self);
}


impl MatchMapping.postinit -> None {
    UniNode.postinit(self);
}


impl MatchKVPair.postinit -> None {
    UniNode.postinit(self);
}


impl MatchStar.postinit -> None {
    UniNode.postinit(self);
}


impl MatchArch.postinit -> None {
    self.arg_patterns = `list(self.arg_patterns) if self.arg_patterns else None;
    self.kw_patterns = `list(self.kw_patterns) if self.kw_patterns else None;
    UniNode.postinit(self);
}


impl Token.init(
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
    self._is_synthetic = False;
    self.kid = [];
    UniNode.postinit(self);
}

impl Token.__repr__ -> str {
    return f"Token({self.name}, {self.value}, {self.loc})";
}

impl Token.unparse -> str {
    if self.gen.jac {
        return self.gen.jac;
    }
    return self.value;
}

impl Name.init(
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
    self.is_enum_stmt = is_enum_stmt;
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
    self.name_of = self;
    self._sym = None;
    self._sym_name = '';
    self._sym_category = SymbolType.UNKNOWN;
    self._py_ctx_func = ast3.Load;
    Expr.postinit(self);
    AstSymbolNode._init_symbol(
        self, sym_name=value, name_spec=self, sym_category=SymbolType.VAR
    );
}

impl SpecialVarRef.init(var: Name, is_enum_stmt: bool = False) -> None {
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
        pos_end=var.pos_end,
        is_enum_stmt=is_enum_stmt
    );
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.py_resolve_name(),
        name_spec=self,
        sym_category=SymbolType.VAR
    );
}

impl SpecialVarRef.py_resolve_name -> str {
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
        raise NotImplementedError('ICE: Special var reference not implemented');
    }
}

impl Literal.init(
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
    AstSymbolStubNode._init_stub(self, sym_type=self.SYMBOL_TYPE);
    Expr.postinit(self);
}

impl Literal.lit_value.getter -> int | str | float | bool | None | Callable[
    ([], Any)
] | EllipsisType {
    raise NotImplementedError;
}

impl BuiltinType.lit_value.getter -> Callable[([], Any)] {
    if (self.value not in Literal.type_map) {
        raise TypeError(f"ICE: {self.value} is not a callable builtin");
    }
    return Literal.type_map[self.value];
}

impl Float.lit_value.getter -> float {
    return float(self.value);
}

impl Int.lit_value.getter -> int {
    return int(self.value, 0);
}

impl String.lit_value.getter -> str {
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
            fstring_parent2: FString = self.parent;
            is_raw2 = False;
            if (
                fstring_parent2
                and fstring_parent2.start
                and fstring_parent2.start.value
            ) {
                prefix2 = fstring_parent2.start.value.lower();
                is_raw2 = 'r' in prefix2;
            }
            if not is_raw2 {
                result = self.value;
                try {
                    result = ast3.literal_eval(f'"{result}"');
                } except (ValueError, SyntaxError) {
                    placeholder = '\x00';
                    result = result.replace('\\\\', placeholder);
                    result = result.replace('\\n', '\n');
                    result = result.replace('\\t', '\t');
                    result = result.replace('\\r', '\r');
                    result = result.replace(placeholder, '\\');
                }
                return result;
            }
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

                try {
                    result = ast3.literal_eval(f'"{result}"');
                } except (ValueError, SyntaxError) {
                    placeholder = '\x00';
                    result = result.replace('\\\\', placeholder);
                    result = result.replace('\\n', '\n');
                    result = result.replace('\\t', '\t');
                    result = result.replace('\\r', '\r');
                    result = result.replace(placeholder, '\\');
                }
                return result;
            }
        }
        return self.value;
    }
}

impl Bool.lit_value.getter -> bool {
    return (self.value == 'True');
}

impl Null.lit_value.getter -> None {
    return None;
}

impl Ellipsis.lit_value.getter -> EllipsisType {
    return ...;
}

impl EmptyToken.init(orig_src: (Source | None) = None) -> None {
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

impl Semi.init(
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
    CodeBlockStmt.postinit(self);
}

impl CommentToken.init(
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
    self.kid = [x.set_parent(self) for x in kid];
    self.loc = CodeLocInfo(*self.resolve_tok_range());
}

impl Source.init(source: str, mod_path: str) -> None {
    super.init(self);
    self.value = source;
    self.hash = md5(source.encode()).hexdigest();
    self.file_path = mod_path;
    self.comments = [];
    self.inline_suppressions = {};
}

impl Source.code.getter -> str {
    return self.value;
}

impl PythonModuleAst.init(ast: ast3.Module, orig_src: Source) -> None {
    super.init();
    self.ast = ast;
    self.orig_src = orig_src;
    self.file_path = orig_src.file_path;
}

impl UniNode.gen.getter -> CodeGenTarget {
    if (self._gen is None) {
        self._gen = CodeGenTarget();
    }
    return self._gen;
}

impl UniNode.gen.setter(value: CodeGenTarget) {
    self._gen = value;
}

impl Expr.type_sym_tab.getter -> (UniScopeNode | None) {
    return self._type_sym_tab;
}

impl Expr.type_sym_tab.setter(type_sym_tab: UniScopeNode) {
    self._type_sym_tab = type_sym_tab;
}

impl NameAtom.sym.getter -> (Symbol | None) {
    return self._sym;
}

impl NameAtom.sym.setter(sym: Symbol) {
    self._sym = sym;
}

impl NameAtom.py_ctx_func.getter -> type[ast3.expr_context] {
    return self._py_ctx_func;
}

impl NameAtom.py_ctx_func.setter(py_ctx_func: type[ast3.expr_context]) {
    self._py_ctx_func = py_ctx_func;
}
