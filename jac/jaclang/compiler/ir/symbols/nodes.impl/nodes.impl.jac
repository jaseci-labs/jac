import from jaclang.compiler.ir.identity { RelationFamily }
impl Symbol.init(
    defn: NameAtom,
    access: SymbolAccess,
    parent_tab: (UniScopeNode | None) = None,
    imported: bool = False
) -> None {
    import from jaclang.compiler.ir.symbols.edges { Defines, InScope }

    import from jaclang.compiler.ir.ownership.facts { SymbolMemory }
    self.memory = SymbolMemory();
    self.name = defn.sym_name;
    self.imported = imported;
    self.access = access;
    self.semstr = '';
    self +>:Defines:+> defn;
    defn.sym = self;
    if parent_tab is not None {
        parent_tab +>:InScope:+> self;
    }
}

impl Symbol.defn.getter -> list[NameAtom] {
    import from jaclang.compiler.ir.symbols.edges { Defines }

    return [self->:Defines:->];
}

impl Symbol.uses.getter -> list[NameAtom] {
    import from jaclang.compiler.ir.symbols.edges { Uses }

    return [self->:Uses:->];
}

impl Symbol.parent_tab.getter -> (UniScopeNode | None) {
    import from jaclang.compiler.ir.symbols.edges { InScope }

    found = [self<-:InScope:<-];
    return found[0] if found else None;
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

impl Symbol.binding_kind.getter -> BindingKind {
    return self.binding_fact if self._binding_kind is None else self._binding_kind;
}

impl Symbol.binding_kind.setter(binding_kind: BindingKind) -> None {
    self._binding_kind = binding_kind;
}

impl Symbol.add_defn(nd: NameAtom) -> None {
    import from jaclang.compiler.ir.symbols.edges { Defines }

    self +>:Defines:+> nd;
    nd.sym = self;
}

impl Symbol.add_use(nd: NameAtom) -> None {
    import from jaclang.compiler.ir.symbols.edges { Uses }

    nd.sym = self;

    if self.in_stub_scope() {
        return;
    }
    self +>:Uses:+> nd;
}

impl Symbol.in_stub_scope -> bool {
    import from jaclang.compiler.ir.syntax.nodes { Module }

    memo = self._in_stub_scope;
    if memo is not None {
        return memo;
    }
    found = False;
    cur: (UniScopeNode | None) = self.parent_tab;
    while cur is not None {
        if isinstance(cur, Module) {
            found = cur.stub_only;
            break;
        }
        cur = cur.parent_scope;
    }
    self._in_stub_scope = found;
    return found;
}

impl Symbol.__repr__ -> str {
    return f"Symbol({self.sym_name}, {self.sym_type}, {self.access},{self.defn})";
}

impl UniScopeNode._init_scope(
    name: str, parent_scope: (UniScopeNode | None) = None
) -> None {
    self.declaration_symbol = None;

    self.capture_symbols = [];
    self.scope_name = name;
    self.implicit_rebinds: dict[(str, Symbol)] = {};
    self._names_index: dict[(str, Symbol)] = {};
    self._overload_index: dict[(str, list[Symbol])] = {};
    if parent_scope is not None {
        self.parent_scope = parent_scope;
    }
}

impl UniScopeNode.parent_scope.getter -> (UniScopeNode | None) {
    import from jaclang.compiler.ir.symbols.edges { ScopeChild, ScopeParent }

    found = [self<-:ScopeChild:<-];
    if found {
        return found[-1];
    }
    owners = [self->:ScopeParent:->];
    return owners[-1] if owners else None;
}

impl UniScopeNode.parent_scope.setter(parent_scope: (UniScopeNode | None)) {
    import from jaclang.compiler.ir.symbols.edges { ScopeChild, ScopeParent }

    # Replacements need preflight before deleting their old relation. Initial
    # connections are validated and claimed atomically by the connect operator.
    replacing = bool([self<-:ScopeChild:<-] or [self->:ScopeParent:->]);
    if replacing and parent_scope is not None {
        self.check_connection(parent_scope, RelationFamily.BINDING);
    }
    if replacing {
        self.changed_relations(RelationFamily.BINDING);
        del [edge self<-:ScopeChild:<-];
        self.changed_relations(RelationFamily.BINDING);
        del [edge self->:ScopeParent:->];
    }
    if parent_scope is not None {
        self +>:ScopeParent:+> parent_scope;
    }
}

impl UniScopeNode.kid_scope.getter -> list[UniScopeNode] {
    import from jaclang.compiler.ir.symbols.edges { ScopeChild }

    return [self->:ScopeChild:->];
}

impl UniScopeNode.names_in_scope.getter -> dict[(str, Symbol)] {
    import from jaclang.compiler.ir.symbols.edges { ScopePrimary }
    if self._names_index is None or self._names_generation != self.primary_revision {
        self._names_index = {
            binding.spelling: binding.symbol for binding in [self->:ScopePrimary:->]
        };
        self._names_generation = self.primary_revision;
    }
    return self._names_index;
}

impl UniScopeNode.names_in_scope_overload.getter -> dict[(str, list[Symbol])] {
    import from jaclang.compiler.ir.symbols.edges { ScopeOverload }
    if self._overload_index is None
        or self._overload_generation != self.overload_revision {
        index: dict[str, list[Symbol]] = {};
        for binding in [self->:ScopeOverload:->] {
            index.setdefault(binding.spelling, []).append(binding.symbol);
        }
        self._overload_index = index;
        self._overload_generation = self.overload_revision;
    }
    return self._overload_index;
}

impl UniScopeNode.lookup(
    name: str, deep: bool = True, incl_inner_scope: bool = False
) -> (Symbol | None) {
    import from jaclang.compiler.ir.syntax.nodes { ImplDef }

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
            if UniScopeNode.is_python_scoping(kid) {
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
    import from jaclang.compiler.ir.enums { SymbolAccess }

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
    current = self.names_in_scope;
    if nd.sym_name in current {
        self.adopt_overload(symbol, nd.sym_name);
    }
    if force_overwrite or nd.sym_name not in current {
        self.adopt_primary(symbol, nd.sym_name);
    } else {
        current[nd.sym_name].add_defn(nd.name_spec);
    }
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

impl UniScopeNode.set_primary_names(syms: dict[(str, Symbol)]) -> None {
    self.changed_relations(RelationFamily.BINDING);
    import from jaclang.compiler.ir.symbols.nodes { ScopeBinding }
    import from jaclang.compiler.ir.symbols.edges { ScopePrimary }

    bindings = [ScopeBinding.create(name, symbol) for (name, symbol) in syms.items()];
    self.changed_relations(RelationFamily.BINDING);
    del [edge self->:ScopePrimary:->];
    for binding in bindings {
        self +>:ScopePrimary:+> binding;
    }
    self.primary_revision += 1;
    self._names_index = dict(syms);
    self._names_generation = self.primary_revision;
}

impl UniScopeNode.adopt_primary(sym: Symbol, alias: str = "") -> None {
    self.changed_relations(RelationFamily.BINDING);
    import from jaclang.compiler.ir.symbols.nodes { ScopeBinding }
    import from jaclang.compiler.ir.symbols.edges { ScopePrimary }
    key = alias or sym.name;
    binding = ScopeBinding.create(key, sym);
    if key in self.names_in_scope {
        self._drop_primary(key);
    }
    self +>:ScopePrimary:+> binding;
    self.primary_revision += 1;
    if self._names_index is not None {
        self._names_index[key] = sym;
        self._names_generation = self.primary_revision;
    }
}

impl UniScopeNode._drop_primary(key: str) -> None {
    self.changed_relations(RelationFamily.BINDING);
    import from jaclang.compiler.ir.symbols.edges { ScopePrimary }
    edges = [edge self->:ScopePrimary:->];
    bindings = [self->:ScopePrimary:->];
    for i in range(len(bindings)) {
        if bindings[i].spelling == key {
            edge_to_drop = edges[i];
            del edge_to_drop;
        }
    }
    self.primary_revision += 1;
    if self._names_index is not None {
        self._names_index.pop(key, None);
        self._names_generation = self.primary_revision;
    }
}

impl UniScopeNode.link_kid_scope(key_node: UniScopeNode) -> UniScopeNode {
    import from jaclang.compiler.ir.symbols.edges { ScopeChild, ScopeParent }

    key_node.changed_relations(RelationFamily.BINDING);
    del [edge key_node<-:ScopeChild:<-];
    key_node.changed_relations(RelationFamily.BINDING);
    del [edge key_node->:ScopeParent:->];
    self +>:ScopeChild:+> key_node;
    return key_node;
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
    self.name_spec.bind_sym(self, sym_name, sym_category);
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

impl AstSymbolNode.expr_ctx.getter -> ExprCtx {
    return self.name_spec.expr_ctx;
}

impl AstSymbolNode.type_sym_tab.getter -> (UniScopeNode | None) {
    return self.name_spec.type_sym_tab;
}

impl AstSymbolStubNode._init_stub(sym_type: SymbolType) -> None {
    import from jaclang.compiler.ir.syntax.nodes { Name }

    AstSymbolNode._init_symbol(
        self,
        sym_name=f"[{self.__class__.__name__}]",
        name_spec=Name.gen_stub_from_node(self, f"[{self.__class__.__name__}]"),
        sym_category=sym_type
    );
}


impl AstImplNeedingNode.needs_impl.getter -> bool {
    return (self.body is None);
}


impl AstImplNeedingNode.link_impl(impl_node: ImplDef) -> None {
    import from jaclang.compiler.ir.symbols.edges { ImplOf }
    self +>:ImplOf:+> impl_node;
}

impl UniScopeNode.adopt_overload(sym: Symbol, alias: str = "") -> None {
    self.changed_relations(RelationFamily.BINDING);
    import from jaclang.compiler.ir.symbols.nodes { ScopeBinding }
    import from jaclang.compiler.ir.symbols.edges { ScopeOverload }
    key = alias or sym.name;
    binding = ScopeBinding.create(key, sym);
    self +>:ScopeOverload:+> binding;
    self.overload_revision += 1;
    if self._overload_index is not None {
        self._overload_index.setdefault(key, []).append(sym);
        self._overload_generation = self.overload_revision;
    }
}

impl ScopeBinding.symbol.getter -> Symbol {
    import from jaclang.compiler.ir.symbols.edges { BindingTarget }
    targets = [self->:BindingTarget:->];
    if len(targets) != 1 {
        raise ValueError("A scope binding requires exactly one symbol");
    }
    return targets[0];
}
