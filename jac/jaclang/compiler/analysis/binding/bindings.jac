import from jaclang.compiler.ir.schema {
    Ability,
    Archetype,
    Assignment,
    AstAccessNode,
    AstSymbolNode,
    AtomTrailer,
    BindingKind,
    Enum,
    Expr,
    ExprCtx,
    ImplDef,
    LambdaExpr,
    ListVal,
    Module,
    ModuleItem,
    Name,
    NameAtom,
    Null,
    ParamVar,
    SpecialVarRef,
    Symbol,
    SymbolAccess,
    SymbolStorage,
    SymbolType,
    Test,
    Tokens,
    TupleVal,
    TypeAlias,
    TypeParam,
    UnaryExpr,
    UniNode,
    UniScopeNode
}
import from collections.abc { Sequence }
import from jaclang.compiler.ir.schema {
    Symbol,
    SymbolAccess,
    UniScopeNode,
    UniNode,
    AstSymbolNode,
    AstAccessNode,
    NameAtom,
    Expr,
    Assignment,
    Archetype,
    Enum,
    TypeAlias,
    TypeParam,
    ModuleItem,
    Ability,
    ImplDef,
    LambdaExpr,
    Name,
    SpecialVarRef,
    Test,
    SymbolStorage,
    BindingKind,
    same_lexical_scope,
    find_python_scope_node_of,
    find_typed_decl_scope_of,
    import_chain_of
}

def classify_binding(symbol: Symbol) -> BindingKind {
    import from jaclang.compiler.ir.syntax.nodes { ModuleItem, import_chain_of }
    import from jaclang.compiler.analysis.binding.bindings { binding_kind_of_decl }
    import from jaclang.compiler.ir.enums { BindingKind }

    for cur in import_chain_of(symbol) {
        decl = cur.decl;
        item = decl.parent if isinstance(decl.parent, ModuleItem) else None;
        if item is not None and item.from_parent.is_typed {
            return BindingKind.TYPE;
        }
        if cur._binding_kind is not None {
            return cur._binding_kind;
        }
        if item is None {
            return binding_kind_of_decl(decl);
        }
    }
    return BindingKind.VALUE;
}

def classify_storage(symbol: Symbol) -> SymbolStorage {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.syntax.nodes {
        Archetype,
        Enum,
        LambdaExpr,
        Module,
        ParamVar,
        same_lexical_scope
    }
    import from jaclang.compiler.ir.enums { SymbolStorage }

    owner = symbol.parent_tab;
    while (owner is not None and not UniScopeNode.is_python_scoping(owner)) {
        owner = owner.parent_scope;
    }
    if (owner is None) or isinstance(owner, Module) {
        return SymbolStorage.MODULE_GLOBAL;
    }
    if isinstance(owner, (Archetype, Enum)) {
        return SymbolStorage.CLASS_FIELD;
    }

    if isinstance(symbol.decl.name_of, ParamVar) {
        return SymbolStorage.PARAM;
    }

    def_scope: (UniNode | None) = symbol.decl.parent;
    while (
        def_scope is not None
        and not UniScopeNode.is_python_scoping(def_scope)
        and not isinstance(def_scope, LambdaExpr)
    ) {
        def_scope = def_scope.parent;
    }
    for use in symbol.uses {
        cur = use.parent;
        while (
            cur is not None
            and not UniScopeNode.is_python_scoping(cur)
            and not isinstance(cur, LambdaExpr)
        ) {
            cur = cur.parent;
        }
        if cur is None or same_lexical_scope(cur, def_scope) {
            continue;
        }
        return SymbolStorage.CAPTURED;
    }
    return SymbolStorage.LOCAL;
}

def collect_capture_facts(module: Module, scopes: list[UniScopeNode]) {
    import from jaclang.compiler.ir.syntax.nodes {
        Ability,
        ImplDef,
        LambdaExpr,
        Name,
        SpecialVarRef,
        Test,
        is_identifier_slot,
        same_lexical_scope
    }
    seen: dict[UniScopeNode, set[Symbol]] = {};
    for scope in scopes {
        scope.capture_symbols = [];
        seen[scope] = set();
    }
    names: list[Name] = module.get_all_sub_nodes(Name);
    names.extend(module.get_all_sub_nodes(SpecialVarRef));
    for name in names {
        if is_identifier_slot(name) or name.sym is None {
            continue;
        }
        symbol = name.sym;
        declaration_scope = symbol.parent_tab;
        while declaration_scope is not None
            and not UniScopeNode.is_python_scoping(declaration_scope) {
            declaration_scope = declaration_scope.parent_scope;
        }
        if name.value == "super" and declaration_scope is not None {
            receiver = declaration_scope.lookup_local("self");
            if receiver is not None {
                symbol = receiver;
                declaration_scope = symbol.parent_tab;
            }
        }
        if not isinstance(declaration_scope, (Ability, ImplDef, LambdaExpr, Test)) {
            continue;
        }
        owner = name.parent;
        while owner is not None {
            if isinstance(owner, UniScopeNode)
                and owner in seen
                and symbol not in seen[owner]
                and not same_lexical_scope(owner, declaration_scope) {
                ancestor = owner.parent_scope;
                while ancestor is not None {
                    if same_lexical_scope(ancestor, declaration_scope) {
                        owner.capture_symbols.append(symbol);
                        seen[owner].add(symbol);
                        break;
                    }
                    ancestor = ancestor.parent_scope;
                }
            }
            owner = owner.parent;
        }
    }
}

def def_insert(
    scope: UniScopeNode,
    nd: AstSymbolNode,
    access_spec: AstAccessNode | None | SymbolAccess = None,
    single_decl: (str | None) = None,
    force_overwrite: bool = False,
    imported: bool = False
) -> (Symbol | None) {
    import from jaclang.compiler.ir.syntax.nodes { AstAccessNode }
    import from jaclang.compiler.ir.enums { SymbolAccess }

    if (nd.sym and (scope == nd.sym.parent_tab)) {
        return nd.sym;
    }
    scope.insert(
        nd=nd,
        single=(single_decl is not None),
        access_spec=access_spec,
        force_overwrite=force_overwrite,
        imported=imported
    );
    update_expr_ctx_for_def(scope, nd);
    return nd.sym;
}

def chain_def_insert(scope: UniScopeNode, node_list: list[AstSymbolNode]) -> None {
    import from jaclang.compiler.ir.enums { ExprCtx }

    if not node_list {
        return;
    }
    cur_sym_tab: (UniScopeNode | None) = node_list[0].sym_tab;
    node_list[-1].name_spec.expr_ctx = ExprCtx.STORE;
    if isinstance(node_list[-1].name_spec, AstSymbolNode) {
        node_list[-1].name_spec.expr_ctx = ExprCtx.STORE;
    }
    node_list = node_list[:-1];
    for i in node_list {
        cur_sym_tab = lookup.decl.sym_tab
            if (lookup := use_lookup(scope, i, sym_table=cur_sym_tab))
            else None;
    }
}

def use_lookup(
    scope: UniScopeNode, nd: AstSymbolNode, sym_table: (UniScopeNode | None) = None
) -> (Symbol | None) {
    if nd.sym {
        return nd.sym;
    }
    if not sym_table {
        sym_table = nd.sym_tab;
    }
    if sym_table {
        found = sym_table.lookup(name=nd.sym_name, deep=True);
        if found {
            found.add_use(nd.name_spec);
        }
    }
    return nd.sym;
}

def chain_use_lookup(scope: UniScopeNode, node_list: Sequence[AstSymbolNode]) -> None {
    import from collections.abc { Sequence }

    if not node_list {
        return;
    }
    cur_sym_tab: (UniScopeNode | None) = node_list[0].sym_tab;
    for i in node_list {
        if (cur_sym_tab is None) {
            break;
        }
        found = use_lookup(scope, i, sym_table=cur_sym_tab);
        if found {
            decl_tab = found.decl.sym_tab;
            cur_sym_tab = decl_tab;
            if decl_tab is not None and (decl_tab.scope_name != i.sym_name) {
                t = decl_tab.find_scope(i.sym_name);
                if t {
                    cur_sym_tab = t;
                }
            }
        } else {
            cur_sym_tab = None;
        }
    }
}

def _fix_store_ctx(scope: UniScopeNode, item: UniNode) {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.syntax.nodes {
        AtomTrailer,
        ListVal,
        TupleVal,
        UnaryExpr
    }
    import from jaclang.compiler.ir.enums { ExprCtx }

    if isinstance(item, UnaryExpr) {
        if isinstance(item.operand, AstSymbolNode) {
            item.operand.name_spec.expr_ctx = ExprCtx.STORE;
        }
    } elif isinstance(item, (TupleVal, ListVal)) {
        for i in item.values {
            if isinstance(i, AstSymbolNode) {
                i.name_spec.expr_ctx = ExprCtx.STORE;
            } elif isinstance(i, AtomTrailer) {
                chain_def_insert(scope, i.as_attr_list);
            }
            if isinstance(i, (TupleVal, ListVal, UnaryExpr)) {
                _fix_store_ctx(scope, i);
            }
        }
    }
}

def update_expr_ctx_for_def(scope: UniScopeNode, nd: AstSymbolNode) {
    import from jaclang.compiler.ir.syntax.nodes { ListVal, TupleVal }
    import from jaclang.compiler.ir.enums { ExprCtx }

    nd.name_spec.expr_ctx = ExprCtx.STORE;
    if isinstance(nd, (TupleVal, ListVal)) and nd.values {
        _fix_store_ctx(scope, nd);
    }
}

def lookup_enclosing_binding(from_scope: UniScopeNode, name: str) -> (Symbol | None) {
    import from jaclang.compiler.ir.symbols.nodes { Symbol, UniScopeNode }
    import from jaclang.compiler.ir.enums { SymbolType }

    scope = find_python_scope_node_of(from_scope);
    while scope is not None {
        if isinstance(scope, Module) {
            sym = scope.lookup_local(name);
            if sym is not None and sym.sym_type == SymbolType.MOD_VAR {
                return sym;
            }
            return None;
        }
        if isinstance(scope, (Ability, ImplDef, Test, LambdaExpr)) {
            sym = scope.lookup_local(name);
            if sym is not None {
                return sym;
            }
        }
        scope = find_python_scope_node_of(scope);
    }
    return None;
}

def record_cross_scope_rebind(py_scope: UniScopeNode, name: str, sym: Symbol) -> None {
    import from jaclang.compiler.ir.symbols.nodes { Symbol, UniScopeNode }
    import from jaclang.compiler.ir.enums { SymbolType }

    outer_tab = sym.parent_tab;
    if outer_tab is None or same_lexical_scope(outer_tab, py_scope) {
        return;
    }
    if not isinstance(py_scope, (Ability, ImplDef, Test)) {
        return;
    }
    if isinstance(outer_tab, Module) {
        if sym.sym_type == SymbolType.MOD_VAR {
            py_scope.implicit_rebinds[name] = sym;
        }
        return;
    }
    if isinstance(outer_tab, (Ability, ImplDef, Test)) {
        py_scope.implicit_rebinds[name] = sym;
    }
}

def rebind_or_def_insert(
    target: AstSymbolNode, py_scope: UniScopeNode, single_decl: str
) -> None {
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode, UniScopeNode }

    if isinstance(py_scope, (Ability, ImplDef, Test, LambdaExpr)) {
        outer_sym = lookup_enclosing_binding(py_scope, target.sym_name);
        if outer_sym is not None {
            outer_sym.add_use(target.name_spec);
            py_scope.adopt_primary(outer_sym, target.sym_name);
            py_scope.implicit_rebinds[target.sym_name] = outer_sym;
            return;
        }
    }
    def_insert(py_scope, target, single_decl=single_decl);
}

def def_insert_unpacking(
    nd: Expr, sym_tab: UniScopeNode, rebind_in_python_scope: bool = False
) -> None {
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { Tokens as Tok }

    if isinstance(nd, Name) {
        if rebind_in_python_scope {
            if ((existing := sym_tab.lookup(nd.sym_name, deep=False)) is not None) {
                existing.add_use(nd.name_spec);
                return;
            }
            py_scope = find_python_scope_node_of(nd);
            if py_scope is not None {
                if ((outer := py_scope.lookup(nd.sym_name, deep=False)) is not None) {
                    outer.add_use(nd.name_spec);
                    record_cross_scope_rebind(py_scope, nd.sym_name, outer);
                } else {
                    rebind_or_def_insert(nd, py_scope, single_decl='local var');
                }
                return;
            }
        }
        def_insert(sym_tab, nd, single_decl='iterator');
    } elif isinstance(nd, (TupleVal, ListVal)) {
        for target_var in nd.values {
            if isinstance(target_var, Expr) {
                def_insert_unpacking(target_var, sym_tab, rebind_in_python_scope);
            }
        }
    } elif (isinstance(nd, UnaryExpr) and (nd.op.name == Tok.STAR_MUL)) {
        def_insert_unpacking(nd.operand, sym_tab, rebind_in_python_scope);
    }
}

def binding_kind_of_decl(decl: NameAtom) -> BindingKind {
    import from jaclang.compiler.ir.enums { BindingKind }

    owner = decl.name_of;
    if isinstance(owner, (Archetype, Enum, TypeAlias)) {
        return BindingKind.BOTH;
    }
    if isinstance(owner, TypeParam) {
        return BindingKind.TYPE;
    }
    return BindingKind.VALUE;
}

def bind_assignment_targets(nd: Assignment) {
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode, UniScopeNode }
    import from jaclang.compiler.ir.enums { SymbolType }

    for i in nd.target {
        if isinstance(i, AstSymbolNode) {
            if isinstance(i, (ListVal, TupleVal)) {
                def_insert_unpacking(i, i.sym_tab, rebind_in_python_scope=True);
            } elif (
                (i.sym_name in i.sym_tab.names_in_scope)
                and ((sym := i.sym_tab.names_in_scope[i.sym_name]) is not None)
            ) {
                if sym.imported and isinstance(nd.value, Null) {
                    sym.add_defn(i.name_spec);
                }
                sym.add_use(i.name_spec);
                record_cross_scope_rebind(i.sym_tab, i.sym_name, sym);
            } elif (
                (nd.type_tag is None)
                and ((outer_has := i.sym_tab.lookup(i.sym_name, deep=True)) is not None)
                and outer_has.sym_type == SymbolType.HAS_VAR
                and isinstance(outer_has.parent_tab, Ability)
            ) {
                outer_has.add_use(i.name_spec);
            } elif (
                (nd.type_tag is None) and not UniScopeNode.is_python_scoping(i.sym_tab)
            ) {
                py_scope = find_python_scope_node_of(i);
                if py_scope is not None {
                    if (
                        (outer := py_scope.lookup(i.sym_name, deep=False)) is not None
                    ) {
                        if outer.imported and isinstance(nd.value, Null) {
                            outer.add_defn(i.name_spec);
                        }
                        outer.add_use(i.name_spec);
                        record_cross_scope_rebind(py_scope, i.sym_name, outer);
                    } else {
                        rebind_or_def_insert(i, py_scope, single_decl='local var');
                    }
                } else {
                    def_insert(i.sym_tab, i, single_decl='local var');
                }
            } elif (
                (nd.type_tag is None)
                and isinstance(i.sym_tab, (Ability, ImplDef, Test, LambdaExpr))
            ) {
                rebind_or_def_insert(i, i.sym_tab, single_decl='local var');
            } else {
                if isinstance(i.sym_tab, Enum) {
                    i.name_spec._sym_category = SymbolType.ENUM_MEMBER;
                }
                def_insert(find_typed_decl_scope_of(i), i, single_decl='local var');
            }
        }
    }
}
