import from jaclang.compiler.ir.identity { RelationFamily }
impl Module.absorb_annex_body(stmts: Sequence[UniNode]) -> None {
    import from jaclang.compiler.ir.syntax.edges { BodyRole }

    self.add_kids_right(stmts, pos_update=False, parent_update=True, role=BodyRole);
}

impl Module.declares_codespace(ctx: CodeContext, path_hint: str = '') -> bool {
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }
    import from jaclang.compiler.ir.enums { CodeContext }

    if ctx != CodeContext.SERVER and self.decided_codespace == ctx.value {
        return True;
    }
    if self.body {
        for _stmt in self.body {
            if ctx != CodeContext.SERVER
                and isinstance(_stmt, ContextAwareNode)
                and _stmt.code_context == ctx {
                return True;
            }
        }
    }
    return False;
}

impl Module.set_code_context(context: CodeContext) -> None {
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }

    self.decided_codespace = context.value;
    for elem in self.body {
        if isinstance(elem, ContextAwareNode) {
            elem.code_context = context;
            if isinstance(elem, ModuleCode) and elem.body {
                for inner in elem.body {
                    if isinstance(inner, ContextAwareNode) {
                        inner.code_context = context;
                    }
                }
            }
        }
    }
}

impl same_lexical_scope(left: UniNode | None, right: UniNode | None) -> bool {
    if left is None or right is None {
        return False;
    }
    return left is right
        or (isinstance(left, ImplDef) and left.decl_link is right)
        or (isinstance(right, ImplDef) and right.decl_link is left);
}

impl AstDocNode.set_doc(elem_doc: (String | None)) -> None {
    import from jaclang.compiler.ir.syntax.edges { DocRole }

    self._role_set(DocRole, elem_doc);
}


impl NameAtom.bind_sym(
    name_of: AstSymbolNode, sym_name: str, sym_category: SymbolType
) -> None {
    self.name_of = name_of;
    self._sym_name = sym_name;
    self._sym_category = sym_category;
}


impl AstAccessNode.access_type.getter -> SymbolAccess {
    import from jaclang.compiler.ir.enums { SymbolAccess }
    import from jaclang.compiler.ir.enums { Tokens as Tok }

    return SymbolAccess.PRIVATE
        if (self.access and (self.access.tag.name == Tok.KW_PRIV))
        else SymbolAccess.PROTECTED
            if (self.access and (self.access.tag.name == Tok.KW_PROT))
            else SymbolAccess.PUBLIC;
}

impl AstAccessNode.public_access.getter -> bool {
    import from jaclang.compiler.ir.enums { SymbolAccess }

    return (self.access_type == SymbolAccess.PUBLIC);
}

impl Module.decided_codespace.getter -> str {
    import from jaclang.compiler.ir.placement.edges { DecidedCodespace }
    import from jaclang.compiler.ir.placement.nodes { Codespace }

    found = [self->:DecidedCodespace:->];
    if found {
        target: Codespace = found[0];
        return target.kind.value;
    }
    return "";
}

impl Module.decided_codespace.setter(decided_codespace: str) {
    import from jaclang.compiler.ir.enums { CodeContext }
    import from jaclang.compiler.ir.placement.edges { DecidedCodespace }
    import from jaclang.compiler.ir.placement.nodes { codespace_node }

    self.changed_relations(RelationFamily.PLACEMENT);
    del [edge self->:DecidedCodespace:->];
    if decided_codespace {
        self +>:DecidedCodespace:+> codespace_node(CodeContext(decided_codespace));
    }
}


impl WalkerStmtOnlyNode.postinit -> None {
    self.from_walker = False;
}


impl CfgExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.flow.nodes { ConditionalNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
    ConditionalNode.postinit(self);
}


impl CodeBlockStmt.postinit -> None {
    import from jaclang.compiler.ir.flow.nodes { UniCFGNode }

    UniCFGNode.postinit(self);
}


impl NameAtom.postinit -> None {
    import from jaclang.compiler.ir.enums { ExprCtx, SymbolType }

    self.name_of = self;
    self._sym_name = '';
    self._sym_category = SymbolType.UNKNOWN;
    self._expr_ctx = ExprCtx.LOAD;
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
    import from jaclang.compiler.ir.symbols.nodes { Symbol }

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
    import from jaclang.compiler.ir.enums { BUILTIN_CALLABLE_NAMES }
    import from jaclang.compiler.ir.enums { JacSemTokenModifier as SemTokMod }
    import from jaclang.compiler.ir.enums { JacSemTokenType as SemTokType }

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
        and (self.sym_name in BUILTIN_CALLABLE_NAMES)
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
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl Module.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    self.src_terminals = self.terminals;
    self.codespace_inferred = False;
    self.ct_file_deps = [];
    self.ct_body_deps = [];
    self.rc_last_use = {};
    self.rc_scope_cleanup = {};
    _rc_move_in: set[int] = set();
    self.rc_move_in = _rc_move_in;
    _own_move_sites: set[int] = set();
    self.own_move_sites = _own_move_sites;
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=self.name);
}


impl ProgramModule.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    main = self.main_mod;
    self.hub = {self.loc.mod_path: main} if main else {};
}


impl TypeParam.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.TYPE
    );
}


impl TypeAlias.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode, UniScopeNode }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.TYPE
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    ContextAwareNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl GlobalVars.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }

    UniNode.postinit(self);
    ContextAwareNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl Test.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode, UniScopeNode }
    import from jaclang.compiler.ir.enums { SymbolType }

    name_node = self.name;
    name_node.set_parent(self);
    name_node._sym_name = f"test_{name_node.value}"
        if not name_node.value.startswith('test_')
        else name_node.value;
    UniNode.postinit(self);

    if (self.description is None and name_node not in self.kid) {
        self.insert_kids_at_pos([name_node], pos=1, pos_update=False);
    }
    AstSymbolNode._init_symbol(
        self,
        sym_name=name_node.sym_name,
        name_spec=name_node,
        sym_category=SymbolType.TEST
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}


impl ModuleCode.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }

    UniNode.postinit(self);
    ContextAwareNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl PyInlineCode.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl Import.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }

    self.jac_detected = None;
    self.boundary_facts = None;
    self.native_only_drop = False;
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}

impl Import.is_jac.getter -> bool {
    if self.jac_detected is None {
        raise ValueError(
            "Import classification requires the scheduled dependency product"
        );
    }
    return self.jac_detected;
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
    import from jaclang.compiler.ir.base { UniNode }

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
        lv = self.path[0].lit_value;
        return lv if isinstance(lv, str) else None;
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

impl ModuleItem.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

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

impl ModuleItem.binding_name.getter -> (Name | None) {
    if isinstance(self.name, Name) {
        return self.name;
    }

    if self.name.value in ('default', '*') {
        return self.alias;
    }
    return None;
}

impl Archetype.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode, UniScopeNode }
    import from jaclang.compiler.ir.enums { SymbolType }
    import from jaclang.compiler.ir.enums { Tokens as Tok }

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


impl Archetype._get_impl_resolved_body -> list[UniNode] {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstImplNeedingNode }

    """The nested ternary this replaced lowers natively now, but not here:
    `Archetype.body` is the `T` of the generic `AstImplNeedingNode[T]`, whose
    layout is type-erased, so the narrow can say "a list" and not what of.
    Both copies then unify at `list[jacval]` and the coercion to the declared
    `list[UniNode]` is refused. The typed local below is what pins the element
    type, so the flat form stays until a generic archetype's layout carries
    its argument.""";
    src = self.body.body if isinstance(self.body, ImplDef) else self.body;
    out: list[UniNode] = [];
    if isinstance(src, list) {
        out.extend(src);
    }
    return out;
}

impl Archetype.is_abstract.getter -> bool {
    body = self._get_impl_resolved_body();
    return `any((isinstance(i, Ability) and i.is_abstract) for i in body);
}

impl Archetype.arch_kind.getter -> (str | None) {
    import from jaclang.compiler.ir.enums { SymbolType }

    kind_map: dict[SymbolType, str] = {
        SymbolType.NODE_ARCH: "node",
        SymbolType.EDGE_ARCH: "edge",
        SymbolType.WALKER_ARCH: "walker"
    };
    return kind_map.get(self.sym_category);
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
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode, UniScopeNode }
    import from jaclang.compiler.ir.enums { SymbolType }

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
    import from jaclang.compiler.ir.enums { Tokens as Tok }

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
    ret.set_parent(self);
    return ret;
}

impl SemDef.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode, UniScopeNode }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=('sem.' + '.'.join([x.sym_name for x in self.target])),
        name_spec=self.create_sem_name_node(),
        sym_category=SymbolType.SEM
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
}


impl SemDef.create_sem_name_node -> Name {
    import from jaclang.compiler.ir.enums { Tokens as Tok }

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
    ret.set_parent(self);
    return ret;
}

impl Enum.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode, UniScopeNode }
    import from jaclang.compiler.ir.enums { SymbolType }

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
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode, UniScopeNode }
    import from jaclang.compiler.ir.enums { SymbolType }
    import from jaclang.compiler.ir.enums { Tokens as Tok }
    import from jaclang.compiler.ir.syntax.edges { NameRefRole }

    _raises: list[str] = [];
    self.raises = _raises;
    UniNode.postinit(self);
    if (self.name_ref is None) {
        first_tok = self.kid[0]
            if (self.kid and isinstance(self.kid[0], Token))
            else None;
        if (first_tok is None) {
            raise ValueError('Cannot create synthetic name_ref without location info.');
        }
        if isinstance(self.signature, EventSignature)
            and (self.signature.event.name == Tok.KW_ENTRY) {
            event_type = "entry";
        } else {
            event_type = "exit";
        }
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
        self._role_set(NameRefRole, synthetic_name_ref);
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
    if self.is_classmethod {
        return True;
    }
    if not self.is_method {
        return False;
    }
    decorators = self.decorators;
    if decorators is not None {
        for dec in decorators {
            if isinstance(dec, Name) and dec.sym_name == 'classmethod' {
                return True;
            }
        }
    }
    return False;
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

    if found is None {
        nodew = self.parent;
        while isinstance(nodew, (IfStmt, ElseStmt, ModuleCode)) {
            nodew = nodew.parent;
        }
        if nodew is not self.parent and isinstance(nodew, (Archetype, Enum)) {
            mod = self.find_parent_of_type(Module);
            if mod is not None and mod.is_raised_from_py {
                return nodew;
            }
        }
    }
    return found;
}

impl Ability.is_genai_ability.getter -> bool {
    import from jaclang.compiler.ir.types.syntax { Expr }

    return isinstance(self.body, Expr);
}

impl Ability.py_resolve_name -> str {
    import from jaclang.compiler.ir.enums { Tokens as Tok }

    if (self.name_ref is None) {
        if isinstance(self.signature, EventSignature)
            and (self.signature.event.name == Tok.KW_ENTRY) {
            event_type = "entry";
        } else {
            event_type = "exit";
        }
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
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl FuncSignature.get_parameters -> list[ParamVar] {
    params: list[ParamVar] = [];
    params.extend(self.posonly_params);
    if self.params is not None {
        params.extend(self.params);
    }
    if self.varargs is not None {
        params.append(self.varargs);
    }
    params.extend(self.kwonlyargs);
    if self.kwargs is not None {
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
    import from jaclang.compiler.ir.enums { Tokens as Tok }

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
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}


impl ParamVar.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode }
    import from jaclang.compiler.ir.enums { SymbolType }
    import from jaclang.compiler.ir.enums { ParamKind }

    self.param_kind = ParamKind.NORMAL;
    UniNode.postinit(self);
    pv_spec: NameAtom = self.name;
    AstSymbolNode._init_symbol(
        self, sym_name=self.name.value, name_spec=pv_spec, sym_category=SymbolType.VAR
    );
}


impl ParamVar.is_vararg.getter -> bool {
    import from jaclang.compiler.ir.enums { Tokens as Tok }

    return bool((self.unpack and (self.unpack.name == Tok.STAR_MUL.name)));
}

impl ParamVar.is_kwargs.getter -> bool {
    import from jaclang.compiler.ir.enums { Tokens as Tok }

    return bool((self.unpack and (self.unpack.name == Tok.STAR_POW.name)));
}

impl ArchHas.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl HasVar.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    hv_spec: NameAtom = self.name;
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=hv_spec,
        sym_category=SymbolType.HAS_VAR
    );
}


impl TypedCtxBlock.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}


impl OpenStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl IfStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl ElseStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}


impl ExprStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl TryStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl Except.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl FinallyStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl AwaitingClause.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl IterForStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl InForStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl WhileStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl ForeverStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl WithStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}


impl ExprAsItem.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl RaiseStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl AssertStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl CtrlStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl DeleteStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl DeleteStmt.leaf_targets -> list[Expr] {
    import from jaclang.compiler.ir.types.syntax { Expr }

    leaves: list[Expr] = [];
    pending: list[Expr] = `list(self.targets);
    pending.reverse();
    while pending {
        inner = DeleteStmt.unwrap_target(pending.pop());
        if isinstance(inner, (TupleVal, ListVal)) {
            elems = [
                el
                for el in inner.values
                if isinstance(el, Expr)
            ];
            elems.reverse();
            pending.extend(elems);
        } else {
            leaves.append(inner);
        }
    }
    return leaves;
}


impl DeleteStmt.unwrap_target(target: Expr) -> Expr {
    import from jaclang.compiler.ir.types.syntax { Expr }

    inner: Expr = target;
    while isinstance(inner, AtomUnit) and isinstance(inner.value, Expr) {
        inner = inner.value;
    }
    return inner;
}


impl DeleteStmt.is_location(target: Expr) -> bool {
    inner = DeleteStmt.unwrap_target(target);
    if isinstance(inner, Name) {
        return True;
    }
    return isinstance(inner, AtomTrailer)
        and (inner.is_attr or isinstance(inner.right, IndexSlice));
}


impl DeleteStmt.type_has_graph_member(t: (TypeBase | None)) -> bool {
    import from jaclang.compiler.ir.types.nodes { ClassType, TypeVarType, UnionType }
    if isinstance(t, TypeVarType) {
        return DeleteStmt.type_has_graph_member(t.bound);
    }
    if isinstance(t, UnionType) {
        return any(DeleteStmt.type_has_graph_member(member) for member in t.types);
    }
    if isinstance(t, ClassType) {
        if t.is_node_type() or t.is_edge_type() or t.is_walker_type() {
            return True;
        }
        if t.is_builtin(["list", "tuple", "set", "frozenset"]) {
            return any(
                DeleteStmt.type_has_graph_member(item)
                for item in (t.private.type_args or [])
            );
        }
        if t.is_builtin("dict") and len(t.private.type_args or []) == 2 {
            return DeleteStmt.type_has_graph_member(t.private.type_args[1]);
        }
    }
    return False;
}

impl DeleteStmt.type_may_hold_graph(t: (TypeBase | None)) -> bool {
    import from jaclang.compiler.ir.types.nodes { ClassType, UnionType }
    if DeleteStmt.type_has_graph_member(t) {
        return True;
    }

    def never_graph(ty: any) -> bool {
        if isinstance(ty, UnionType) {
            return all(never_graph(m) for m in ty.types);
        }
        if not isinstance(ty, ClassType) {
            return False;
        }
        if ty.is_any_type() or not ty.is_builtin() {
            return False;
        }
        class_name = ty.shared.class_name;
        if class_name
            in (
                "int",
                "float",
                "complex",
                "str",
                "bytes",
                "bytearray",
                "bool",
                "None",
                "NoneType"
            ) {
            return True;
        }
        type_args = ty.private.type_args;
        if type_args is None or len(type_args) == 0 {
            return False;
        }
        if class_name in ("list", "tuple", "set", "frozenset") {
            return all(never_graph(a) for a in type_args);
        }
        if class_name == "dict" {
            return len(type_args) == 2 and never_graph(type_args[1]);
        }
        return False;
    }
    return not never_graph(t);
}


impl DeleteStmt.target_may_hold_graph(target: Expr) -> bool {
    return DeleteStmt.type_may_hold_graph(target.type);
}


impl ReportStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl ReturnStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl VisitStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl DisengageStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl AwaitExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}

impl CastExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl Assignment.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl ConcurrentExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl BinaryExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl CompareExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl BoolExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl LambdaExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}

impl LambdaExpr.captures.getter -> list[Symbol] {
    return list(self.capture_symbols);
}

impl LambdaExpr.tail_return_expr -> Expr | None {
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from collections.abc { Sequence }

    """Implicit return: a braced body consisting of a single expression
    statement returns that expression's value. Any other body (multiple
    statements, or a non-expression statement) uses an explicit `return`.""";
    if isinstance(self.body, Expr) or not isinstance(self.body, list) {
        return None;
    }
    body: Sequence[CodeBlockStmt] = self.body;
    stmts = [
        s
        for s in body
        if not isinstance(s, Semi)
    ];
    if (len(stmts) == 1 and isinstance(stmts[0], ExprStmt)) {
        return stmts[0].expr;
    }
    if (
        len(stmts) == 1
        and isinstance(stmts[0], ReturnStmt)
        and stmts[0].is_implicit
        and stmts[0].expr is not None
    ) {
        return stmts[0].expr;
    }
    return None;
}


impl UnaryExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl IfElseExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl MultiString.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.STRING);
}

impl MultiString.lit_value.getter -> str | bytes {
    text_parts: list[str] = [];
    byte_parts: list[int] = [];
    saw_bytes = False;
    for s in self.strings {
        if isinstance(s, String) {
            part = s.lit_value;
            if isinstance(part, `bytes) {
                raw_bytes: bytes = part;
                saw_bytes = True;
                k = 0;
                while (k < len(raw_bytes)) {
                    byte_parts.append(raw_bytes[k]);
                    k += 1;
                }
            } else {
                raw_text: str = part;
                text_parts.append(raw_text);
            }
        }
    }
    if saw_bytes {
        if text_parts {
            raise ValueError('cannot concatenate bytes and str literals');
        }
        return bytes(byte_parts);
    }
    return ''.join(text_parts);
}


impl FString.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.STRING);
}


impl FormattedValue.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl ListVal.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl SetVal.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl TupleVal.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl DictVal.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl KVPair.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl KWPair.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl InnerCompr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.flow.nodes { UniCFGNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}


impl ListCompr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.flow.nodes { UniCFGNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode, UniScopeNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}


impl DictCompr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.flow.nodes { UniCFGNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode, UniScopeNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}


impl AtomTrailer.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl AtomTrailer.as_attr_list.getter -> list[AstSymbolNode] {
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode }

    left = self.right if isinstance(self.right, AtomTrailer) else self.target;
    right = self.target if isinstance(self.right, AtomTrailer) else self.right;
    trag_list: list[AstSymbolNode] = [];
    if isinstance(right, AstSymbolNode) {
        trag_list.append(right);
    }
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
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}

impl GraphExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl YieldExpr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl FuncCall.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl Slice.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl IndexSlice.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl EdgeRefTrailer.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

    UniNode.postinit(self);
    Expr.postinit(self);
}


impl EdgeOpRef.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl DisconnectOp.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}


impl ConnectOp.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl FilterCompr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl AssignCompr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}


impl JsxElement.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { SymbolType }

    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.OBJECT_ARCH);
}


impl JsxElement.get_body_start_line -> (int | None) {
    import from jaclang.compiler.ir.enums { Tokens as Tok }

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
    import from jaclang.compiler.ir.enums { Tokens as Tok }

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
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl JsxAttribute.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl JsxSpreadAttribute.postinit -> None {
    JsxAttribute.postinit(self);
}


impl JsxNormalAttribute.postinit -> None {
    JsxAttribute.postinit(self);
}


impl JsxChild.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl JsxText.postinit -> None {
    JsxChild.postinit(self);
}


impl JsxText.get_normalized_text -> str {
    raw = self.value.value if isinstance(self.value, Token) else str(self.value);
    if not raw {
        return "";
    }
    lines = raw.replace('\r\n', '\n').replace('\r', '\n').split('\n');

    last_non_empty = -1;
    for i in range(len(lines)) {
        if lines[i].strip(' \t') != '' {
            last_non_empty = i;
        }
    }
    result = "";
    for i in range(len(lines)) {
        line = lines[i].replace('\t', ' ');
        is_first = i == 0;
        is_last = i == len(lines) - 1;
        if not is_first {
            line = line.lstrip(' ');
        }
        if not is_last {
            line = line.rstrip(' ');
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
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl MatchCase.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}


impl SwitchStmt.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}


impl SwitchCase.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}


impl MatchOr.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl MatchAs.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl MatchValue.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl MatchSingleton.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl MatchSequence.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl MatchMapping.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl MatchKVPair.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl MatchStar.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

    UniNode.postinit(self);
}


impl MatchArch.postinit -> None {
    import from jaclang.compiler.ir.base { UniNode }

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
    import from jaclang.compiler.ir.base { UniNode }

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
    UniNode.postinit(self);
}

impl Token.__repr__ -> str {
    return f"Token({self.name}, {self.value}, {self.loc})";
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
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode }
    import from jaclang.compiler.ir.types.syntax { Expr }
    import from jaclang.compiler.ir.enums { ExprCtx, SymbolType }

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
    self._sym_name = '';
    self._sym_category = SymbolType.UNKNOWN;
    self._expr_ctx = ExprCtx.LOAD;
    Expr.postinit(self);
    AstSymbolNode._init_symbol(
        self, sym_name=value, name_spec=self, sym_category=SymbolType.VAR
    );
}

impl SpecialVarRef.init(var: Name, is_enum_stmt: bool = False) -> None {
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolNode }
    import from jaclang.compiler.ir.enums { SymbolType }

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
    import from jaclang.compiler.ir.enums { Constants as Con }
    import from jaclang.compiler.ir.enums { Tokens as Tok }

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
    import from jaclang.compiler.ir.symbols.nodes { AstSymbolStubNode }
    import from jaclang.compiler.ir.types.syntax { Expr }

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

impl Literal.lit_value.getter -> int | str | float | bool | None | type | object {
    raise NotImplementedError;
}

impl BuiltinType.lit_value.getter -> type {
    if (self.value not in Literal.type_map) {
        raise TypeError(f"ICE: {self.value} is not a callable builtin");
    }
    tval = Literal.type_map[self.value];
    if isinstance(tval, type) {
        return tval;
    }
    raise TypeError(f"ICE: {self.value} is not a callable builtin");
}

impl Float.lit_value.getter -> float {
    return float(self.value);
}

impl Int.lit_value.getter -> int {
    return int(self.value, 0);
}

impl String.lit_value.getter -> str | bytes {
    if (self.parent and isinstance(self.parent, FString)) {
        fstring_parent: FString = self.parent;
        is_raw = False;
        if (fstring_parent.start and fstring_parent.start.value) {
            prefix = fstring_parent.start.value.lower();
            is_raw = 'r' in prefix;
        }
        if is_raw {
            return self.value;
        }
        return _decode_str_escapes(self.value);
    }
    return decode_string_literal(self.value);
}

impl Bool.lit_value.getter -> bool {
    return (self.value == 'True');
}

impl Null.lit_value.getter -> None {
    return None;
}

impl Ellipsis.lit_value.getter -> object {
    return ...;
}

impl EmptyToken.init(orig_src: (Source | None) = None) -> None {
    _src = orig_src;
    if _src is None {
        _src = Source('', '');
    }
    super.init(
        name='EmptyToken',
        orig_src=_src,
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
    import from jaclang.compiler.frontend.source_locations { CodeLocInfo }

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
    self._link(kid, {});
    (first_tok, last_tok) = self.resolve_tok_range();
    self.loc = CodeLocInfo(first_tok, last_tok);
}

impl Source.init(source: str, mod_path: str) -> None {
    super.init(orig_src=self);
    self.value = source;
    self._hash = "";
    self.file_path = mod_path;
    self.comments = [];
    self.inline_suppressions = {};
}

impl Source.hash.getter -> str {
    if not self._hash {
        h = 0xCBF29CE484222325;
        for b in self.value.encode() {
            h = ((h ^ b) * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF;
        }
        self._hash = f"{h:016x}";
    }
    return self._hash;
}

impl Source.code.getter -> str {
    return self.value;
}

impl PythonModuleAst.init(ast: object, orig_src: Source) -> None {
    super.init();
    self.ast = ast;
    self.orig_src = orig_src;
    self.file_path = orig_src.file_path;
}

impl FuncCall.callee_decl.getter -> (Ability | None) {
    import from jaclang.compiler.ir.symbols.edges { CalleeDecl }

    found = [self->:CalleeDecl:->];
    return found[0] if found else None;
}

impl FuncCall.callee_decl.setter(callee_decl: (Ability | None)) {
    import from jaclang.compiler.ir.symbols.edges { CalleeDecl }

    self.changed_relations(RelationFamily.BINDING);
    del [edge self->:CalleeDecl:->];
    if callee_decl is not None {
        self +>:CalleeDecl:+> callee_decl;
    }
}

impl Import.absorbed_mod.getter -> (Module | None) {
    import from jaclang.compiler.ir.symbols.edges { Absorbs }

    found = [self->:Absorbs:->];
    return found[0] if found else None;
}

impl Import.absorbed_mod.setter(absorbed_mod: (Module | None)) {
    import from jaclang.compiler.ir.symbols.edges { Absorbs }

    self.changed_relations(RelationFamily.BINDING);
    del [edge self->:Absorbs:->];
    if absorbed_mod is not None {
        self +>:Absorbs:+> absorbed_mod;
    }
}

impl NameAtom.sym.getter -> (Symbol | None) {
    import from jaclang.compiler.ir.symbols.edges { SymOf }

    found = [self->:SymOf:->];
    return found[0] if found else None;
}

impl NameAtom.sym.setter(sym: Symbol | None) {
    import from jaclang.compiler.ir.symbols.edges { SymOf }

    self.changed_relations(RelationFamily.BINDING);
    del [edge self->:SymOf:->];
    if sym is not None {
        self +>:SymOf:+> sym;
    }
}

impl NameAtom.expr_ctx.getter -> ExprCtx {
    return self._expr_ctx;
}

impl NameAtom.expr_ctx.setter(expr_ctx: ExprCtx) {
    self._expr_ctx = expr_ctx;
}

impl is_identifier_slot(nd: UniNode) -> bool {
    par = nd.parent;
    if isinstance(par, KWPair) {
        return par.key is nd;
    }
    if isinstance(par, AtomTrailer) {
        return par.is_attr and (par.right is nd);
    }
    if isinstance(par, (HasVar, ParamVar, Archetype, Enum)) {
        return par.name is nd;
    }
    if isinstance(par, Ability) {
        return par.name_ref is nd;
    }
    if isinstance(par, ModuleItem) {
        return (par.name is nd) or (par.alias is nd);
    }
    return False;
}

impl find_python_scope_node_of(nd: UniNode) -> (UniScopeNode | None) {
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    while nd.parent {
        scope_parent = nd.parent;
        if isinstance(scope_parent, UniScopeNode)
            and UniScopeNode.is_python_scoping(scope_parent) {
            return scope_parent;
        }
        nd = scope_parent;
    }
    return None;
}

impl find_typed_decl_scope_of(nd: AstSymbolNode) -> UniScopeNode {
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }

    if UniScopeNode.is_python_scoping(nd.sym_tab) {
        return nd.sym_tab;
    }
    py_scope = find_python_scope_node_of(nd);
    if isinstance(py_scope, (Ability, ImplDef, Test, LambdaExpr)) {
        return py_scope;
    }
    return nd.sym_tab;
}

impl _ability_of_defn(defn_node: UniNode) -> (Ability | None) {
    if isinstance(defn_node, Ability) {
        return defn_node;
    }
    if isinstance(defn_node.parent, Ability) {
        return defn_node.parent;
    }
    return None;
}

impl ability_of_symbol(sym: (Symbol | None)) -> (Ability | None) {
    if sym is None or not sym.defn {
        return None;
    }
    decl = _ability_of_defn(sym.defn[0]);

    if decl is not None and str(decl.loc.mod_path).endswith(".pyi") {
        for alt in sym.defn {
            alt_decl = _ability_of_defn(alt);
            if alt_decl is not None
                and not str(alt_decl.loc.mod_path).endswith(".pyi") {
                return alt_decl;
            }
        }
    }
    return decl;
}

impl import_chain_of(sym: Symbol) -> list[Symbol] {
    import from jaclang.compiler.ir.symbols.nodes { Symbol }

    seen: set[int] = set();
    chain: list[Symbol] = [];
    cur: Symbol = sym;
    while True {
        if id(cur) in seen or not cur.defn {
            return chain;
        }
        seen.add(id(cur));
        chain.append(cur);
        decl = cur.decl;
        if not isinstance(decl.parent, ModuleItem) {
            return chain;
        }
        nxt = decl.sym;
        if nxt is None or nxt is cur {
            return chain;
        }
        cur = nxt;
    }
}

impl resolved_decl_of(sym: Symbol) -> (NameAtom | None) {
    for cur in import_chain_of(sym) {
        decl = cur.decl;
        if not isinstance(decl.parent, ModuleItem) {
            return decl;
        }
    }
    return None;
}

impl kind_has_runtime_binding(
    kind: BindingKind, decl: (NameAtom | None), space: CodeContext
) -> bool {
    import from jaclang.compiler.ir.enums { CodeContext }

    if not kind.denotes_value() {
        return False;
    }
    if space != CodeContext.CLIENT {
        return True;
    }
    return decl is None or not isinstance(decl.name_of, TypeAlias);
}

impl has_runtime_binding(sym: Symbol, space: CodeContext) -> bool {
    return kind_has_runtime_binding(sym.binding_kind, resolved_decl_of(sym), space);
}

impl is_client_destined(nd: UniNode) -> bool {
    import from jaclang.compiler.ir.base { UniNode }
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }
    import from jaclang.compiler.ir.enums { CodeContext }

    cur: (UniNode | None) = nd;
    while cur is not None {
        if isinstance(cur, ContextAwareNode) {
            return (cur.code_context == CodeContext.CLIENT) or cur.codespace_dual;
        }
        cur = cur.parent;
    }
    return False;
}

impl type_only_import_of(nd: NameAtom) -> (ModuleItem | None) {
    sym = nd.sym;
    if sym is None or not sym.imported or not sym.defn {
        return None;
    }
    found: (ModuleItem | None) = None;
    for d in sym.defn {
        if d is nd or not isinstance(d.parent, ModuleItem) {
            return None;
        }
        if not d.parent.from_parent.is_typed {
            return None;
        }
        found = d.parent;
    }
    return found;
}

impl in_type_position(nd: UniNode, include_subscripts: bool = True) -> bool {
    import from jaclang.compiler.ir.base { UniNode }

    cur: UniNode = nd;
    parent = cur.parent;
    while parent is not None {
        if isinstance(parent, (SubTag, TypeAlias, TypeParam))
            or (include_subscripts and isinstance(parent, IndexSlice)) {
            return True;
        }
        if isinstance(parent, CastExpr) and parent.cast_type is cur {
            return True;
        }
        if isinstance(parent, FuncSignature) and parent.return_type is cur {
            return True;
        }
        cur = parent;
        parent = cur.parent;
    }
    return False;
}

impl Ability.event_triggers.getter -> (list[TypeBase] | None) {
    import from jaclang.compiler.ir.types.edges { EventTriggerOf }

    return [self->:EventTriggerOf:->];
}

impl Ability.event_triggers.setter(event_triggers: (list[TypeBase] | None)) -> None {
    import from jaclang.compiler.ir.types.edges { EventTriggerOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:EventTriggerOf:->];
    for t in (event_triggers or []) {
        self +>:EventTriggerOf:+> t;
    }
}
