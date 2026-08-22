impl ASTValidationPass.enter_match_stmt(
    self: ASTValidationPass, nd: MatchStmt
) -> None {
    if len(nd.cases) == 0 {
        self.emit(E0041, node_override=nd);
    }
}

impl ASTValidationPass.enter_module_code(
    self: ASTValidationPass, nd: ModuleCode
) -> None {
    if isinstance(nd.parent, Module) or nd.parent is None {
        for k in nd.kid {
            if isinstance(k, Token) and k.name == Tok.KW_EXIT {
                self.emit(E0031, node_override=nd);
                break;
            }
        }
    }
}

impl ASTValidationPass.enter_binary_expr(
    self: ASTValidationPass, nd: BinaryExpr
) -> None {
    if nd.op is not None and isinstance(nd.op, Token) and nd.op.name == Tok.WALRUS_EQ {
        if not isinstance(nd.left, Name) and not isinstance(nd.left, SpecialVarRef) {
            self.emit(E0020, node_override=nd.left);
        } else {
            self._reject_non_bindable(nd.left);
        }
    }
}

impl ASTValidationPass.enter_name(self: ASTValidationPass, nd: Name) -> None {
    if nd.value == "pass" {
        self.emit(E0010, node_override=nd, keyword="pass");
    }
}

impl ASTValidationPass.enter_param_var(self: ASTValidationPass, nd: ParamVar) -> None {
    ctx_owner = nd.find_parent_of_type(ContextAwareNode);
    if isinstance(nd.name, Name)
        and keyword.iskeyword(nd.name.value)
        and (ctx_owner is None or ctx_owner.code_context == CodeContext.SERVER) {
        self.emit(
            E0067, node_override=nd.name, name=nd.name.value, context='parameter'
        );
    }
    sig = nd.parent;
    if isinstance(sig, FuncSignature) and isinstance(sig.parent, LambdaExpr) {
        return;
    }
    if nd.type_tag is None {
        param_name = nd.name.value if isinstance(nd.name, Name) else str(nd.name);
        self.emit(E0052, node_override=nd, name=param_name);
    }
}

impl ASTValidationPass.enter_func_signature(
    self: ASTValidationPass, nd: FuncSignature
) -> None {
    has_slash = False;
    has_star = False;
    has_kwargs = False;
    for k in nd.kid {
        if isinstance(k, Token) and k.name == Tok.DIV {
            if has_slash {
                self.emit(E0050, node_override=k, param="/");
            } elif has_star {
                self.emit(E0051, node_override=k, first="/", second="*");
            } elif has_kwargs {
                self.emit(E0051, node_override=k, first="/", second="**kwargs");
            }
            has_slash = True;
        } elif isinstance(k, Token) and k.name == Tok.STAR_MUL {
            if has_star {
                self.emit(E0050, node_override=k, param="*");
            } elif has_kwargs {
                self.emit(E0051, node_override=k, first="*", second="**kwargs");
            }
            has_star = True;
        } elif isinstance(k, ParamVar) {
            if k.unpack and k.unpack?.name {
                if k.unpack.name == Tok.STAR_MUL {
                    if has_star {
                        self.emit(E0050, node_override=k, param="*");
                    } elif has_kwargs {
                        self.emit(E0051, node_override=k, first="*", second="**kwargs");
                    }
                    has_star = True;
                } elif k.unpack.name == Tok.STAR_POW {
                    if has_kwargs {
                        self.emit(E0050, node_override=k, param="**kwargs");
                    }
                    has_kwargs = True;
                }
            }
        }
    }
}

impl ASTValidationPass.enter_iter_for_stmt(
    self: ASTValidationPass, nd: IterForStmt
) -> None {
    if nd.count_by is not None
        and isinstance(nd.count_by, Assignment)
        and nd.count_by.aug_op is None {
        self.emit(E0023, node_override=nd.count_by);
    }
}

impl ASTValidationPass.enter_enum(self: ASTValidationPass, nd: Enum) -> None {
    if isinstance(nd.body, list) and len(nd.body) == 0 {
        self.emit(E0043, node_override=nd);
    }
}

impl ASTValidationPass.enter_switch_stmt(
    self: ASTValidationPass, nd: SwitchStmt
) -> None {
    if len(nd.cases) == 0 {
        self.emit(E0042, node_override=nd);
    }
}

impl ASTValidationPass._reject_non_bindable(
    self: ASTValidationPass, target: object
) -> None {
    non_bindable = {Tok.KW_ROOT, Tok.KW_SUPER};
    if isinstance(target, (TupleVal, ListVal)) {
        for el in target.values {
            self._reject_non_bindable(el);
        }
        return;
    }

    ref = target.right if isinstance(target, AtomTrailer) else target;

    if isinstance(ref, Name) and (not ref.is_kwesc) and ref.name in non_bindable {
        self.emit(E0024, node_override=ref, name=ref.value);
    }
}

impl ASTValidationPass.enter_assignment(
    self: ASTValidationPass, nd: Assignment
) -> None {
    for target in nd.target {
        self._reject_non_bindable(target);
    }
    self._check_render_phase_state_write(nd);
}

impl ASTValidationPass.enter_in_for_stmt(
    self: ASTValidationPass, nd: InForStmt
) -> None {
    self._reject_non_bindable(nd.target);
}

impl ASTValidationPass._check_render_phase_state_write(
    self: ASTValidationPass, nd: Assignment
) -> None {
    targets = nd.target if isinstance(nd.target, (list, tuple)) else [nd.target];
    if len(targets) != 1 or not isinstance(targets[0], Name) {
        return;
    }
    name = targets[0].sym_name;
    scope = nd.parent;
    while scope is not None {
        if isinstance(scope, LambdaExpr) {
            return;
        }
        if isinstance(scope, (Ability, ImplDef)) {
            if self._scope_declares_state(scope, name) and self._returns_jsx(scope) {
                self.emit(E0082, node_override=nd, name=name);
            }
            return;
        }
        scope = scope.parent;
    }
}

impl ASTValidationPass._scope_declares_state(
    self: ASTValidationPass, scope: (Ability | ImplDef), name: str
) -> bool {
    body = scope.body;
    if not isinstance(body, list) {
        return False;
    }
    for stmt in body {
        if isinstance(stmt, ArchHas) {
            for var in stmt.vars {
                if var.name.sym_name == name {
                    return True;
                }
            }
        }
    }
    return False;
}

impl ASTValidationPass._returns_jsx(
    self: ASTValidationPass, scope: (Ability | ImplDef)
) -> bool {
    sig: (FuncSignature | None) = None;
    if isinstance(scope, Ability) and isinstance(scope.signature, FuncSignature) {
        sig = scope.signature;
    } elif isinstance(scope, ImplDef) and isinstance(scope.spec, FuncSignature) {
        sig = scope.spec;
    }
    ret = sig.return_type if sig is not None else None;
    if ret is None {
        return False;
    }
    stack: list[UniNode] = [ret];
    while stack {
        probe = stack.pop();
        if isinstance(probe, Name)
            and probe.sym_name in ("JsxElement", "JsxPage", "JsxLayout") {
            return True;
        }
        kids = probe.kid;
        if isinstance(kids, list) {
            stack.extend(kids);
        }
    }
    return False;
}

impl ASTValidationPass.enter_inner_compr(
    self: ASTValidationPass, nd: InnerCompr
) -> None {
    self._reject_non_bindable(nd.target);
}

impl ASTValidationPass.enter_has_var(self: ASTValidationPass, nd: HasVar) -> None {
    ctx_owner = nd.find_parent_of_type(ContextAwareNode);
    if isinstance(nd.name, Name)
        and keyword.iskeyword(nd.name.value)
        and (ctx_owner is None or ctx_owner.code_context == CodeContext.SERVER) {
        self.emit(E0067, node_override=nd.name, name=nd.name.value, context='field');
    }
    self._reject_non_bindable(nd.name);
}

impl ASTValidationPass.enter_expr_as_item(
    self: ASTValidationPass, nd: ExprAsItem
) -> None {
    if nd.alias is not None {
        self._reject_non_bindable(nd.alias);
    }
}

impl ASTValidationPass.enter_delete_stmt(
    self: ASTValidationPass, nd: DeleteStmt
) -> None {
    self._reject_non_bindable(nd.target);
}

impl ASTValidationPass.enter_import(self: ASTValidationPass, nd: Import) -> None {
    if nd.items is not None
        and len(nd.items) == 0
        and (nd.clib_decls is None or len(nd.clib_decls) == 0) {
        self.emit(E0044, node_override=nd);
    }
}

impl ASTValidationPass.enter_yield_expr(
    self: ASTValidationPass, nd: YieldExpr
) -> None {
    if nd.find_parent_of_type(Ability) is None
        and nd.find_parent_of_type(ImplDef) is None {
        self.emit(E0055, node_override=nd);
    }
}

impl ASTValidationPass.enter_ctrl_stmt(self: ASTValidationPass, nd: CtrlStmt) -> None {
    if nd.ctrl is None or not isinstance(nd.ctrl, Token) {
        return;
    }
    kw = nd.ctrl.value;
    if kw not in ("break", "continue") {
        return;
    }

    parent = nd.parent;
    while parent is not None {
        if isinstance(parent, (InForStmt, IterForStmt, WhileStmt, ForeverStmt)) {
            return;
        }

        if kw == "break" and isinstance(parent, (SwitchStmt, MatchStmt)) {
            return;
        }

        if isinstance(parent, (Ability, ImplDef, Module)) {
            break;
        }
        parent = parent.parent;
    }
    self.emit(E0058, node_override=nd, keyword=kw);
}

impl ASTValidationPass.enter_global_vars(
    self: ASTValidationPass, nd: GlobalVars
) -> None {
    valid_parents = (Module, );
    if not isinstance(nd.parent, valid_parents) {
        self.emit(E0063, node_override=nd);
    }
}

impl ASTValidationPass.enter_func_call(self: ASTValidationPass, nd: FuncCall) -> None {
    if nd.params is None {
        return;
    }
    seen_kw = False;
    seen_kw_names: set[str] = set();
    for param in nd.params {
        if isinstance(param, KWPair) {
            seen_kw = True;
            if param.key is not None {
                kw_name = param.key.value
                    if isinstance(param.key, Name)
                    else str(param.key);
                if kw_name in seen_kw_names {
                    self.emit(E0065, node_override=param, name=kw_name);
                }
                seen_kw_names.add(kw_name);
            }
        } else {
            if seen_kw {
                self.emit(E0066, node_override=param);
            }
        }
    }
}

impl ASTValidationPass.enter_archetype(self: ASTValidationPass, nd: Archetype) -> None {
    if nd.base_classes is not None {
        seen_bases: set[str] = set();
        for base in nd.base_classes {
            base_name: str | None = None;
            if isinstance(base, Name) {
                base_name = base.value;
            } elif isinstance(base, AtomTrailer) and isinstance(base.right, Name) {
                base_name = base.right.value;
            }
            if base_name is not None {
                if base_name in seen_bases {
                    self.emit(E0075, node_override=base, name=base_name);
                }
                seen_bases.add(base_name);
            }
        }
    }

    body: list[UniNode] = [];
    if isinstance(nd.body, list) {
        for direct_item in nd.body {
            body.append(direct_item);
        }
    } elif isinstance(nd.body, ImplDef) and isinstance(nd.body.body, list) {
        for impl_item in nd.body.body {
            body.append(impl_item);
        }
    }

    properties_seen: set[str] = set();
    for item in body {
        if (
            isinstance(item, Ability)
            and item.name_ref is not None
            and item.decorators is not None
        ) {
            for dec in item.decorators {
                if isinstance(dec, Name) and dec.value == "property" {
                    pref = item.name_ref;
                    if isinstance(pref, Name) {
                        properties_seen.add(pref.value);
                    }
                    break;
                }
            }
        }
    }

    seen_methods: set[str] = set();
    seen_accessors: set[tuple[(str, str)]] = set();
    for item in body {
        if not (isinstance(item, Ability) and item.name_ref is not None) {
            continue;
        }
        has_overload = False;
        accessor_kind: (str | None) = None;
        accessor_target: (str | None) = None;
        if item.decorators is not None {
            for dec in item.decorators {
                if isinstance(dec, Name) and dec.value == "overload" {
                    has_overload = True;
                } elif (
                    isinstance(dec, AtomTrailer)
                    and isinstance(dec.right, Name)
                    and dec.right.value in ("setter", "getter", "deleter")
                    and isinstance(dec.target, Name)
                ) {
                    accessor_kind = dec.right.value;
                    accessor_target = dec.target.value;
                }
            }
        }

        if has_overload {
            continue;
        }
        nref = item.name_ref;
        if not isinstance(nref, Name) {
            continue;
        }
        mname = nref.value;

        dedup_name = '__init__'
            if (isinstance(nref, Name) and nref.name == Tok.KW_INIT)
            else mname;

        if (
            accessor_kind is not None
            and accessor_target == mname
            and mname in properties_seen
        ) {
            key = (mname, accessor_kind);
            if key in seen_accessors {
                self.emit(E0076, node_override=nref, name=mname);
            }
            seen_accessors.add(key);
            continue;
        }
        if dedup_name in seen_methods {
            self.emit(E0076, node_override=nref, name=mname);
        }
        seen_methods.add(dedup_name);
    }
}

impl ASTValidationPass.enter_try_stmt(self: ASTValidationPass, nd: TryStmt) -> None {
    if len(nd.excepts) == 0 and nd.finally_body is None and nd.awaiting_body is None {
        self.emit(E0040, node_override=nd);
    }

    for (i, exc) in enumerate(nd.excepts) {
        if exc.ex_type is None and i < len(nd.excepts) - 1 {
            self.emit(E0071, node_override=exc);
        }
    }
}

impl ASTValidationPass.enter_jsx_slot(self: ASTValidationPass, nd: JsxSlot) -> None {
    self._check_slot_body([s for s in nd.body], False, "");
}

impl ASTValidationPass.enter_expr_stmt(self: ASTValidationPass, nd: ExprStmt) -> None {
    if not nd.has_semi {
        self.emit(E2084, node_override=nd);
    }
}

impl ASTValidationPass._check_slot_body(
    self: ASTValidationPass, stmts: list[UniNode], in_loop: bool, loop_kw: str
) -> None {
    for s in stmts {
        if isinstance(s, ReturnStmt) {
            if s.expr is not None {
                self.emit(E2019, node_override=s);
            } else {
                self.emit(E2020, node_override=s);
            }
        } elif isinstance(s, CtrlStmt) {
            if in_loop and s.ctrl.value == "break" {
                self.emit(E2021, node_override=s, kw=s.ctrl.value, loop=loop_kw);
            }
        } elif isinstance(s, ArchHas) {
            self.emit(E2024, node_override=s);
        } elif isinstance(s, WhileStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                self.emit(W2019, node_override=s);
            }
            self._check_slot_body([b for b in s.body], True, "while");
            self._check_slot_else(s.else_body, in_loop, loop_kw);
        } elif isinstance(s, ForeverStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                self.emit(W2019, node_override=s);
            }
            self._check_slot_body([b for b in s.body], True, "forever");
        } elif isinstance(s, InForStmt) or isinstance(s, IterForStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                self.emit(W2021, node_override=s);
            }
            self._check_slot_body([b for b in s.body], True, "for");
            self._check_slot_else(s.else_body, in_loop, loop_kw);
        } elif isinstance(s, IfStmt) {
            self._check_slot_body([b for b in s.body], in_loop, loop_kw);
            self._check_slot_else(s.else_body, in_loop, loop_kw);
        } elif isinstance(s, WithStmt) {
            self._check_slot_body([b for b in s.body], in_loop, loop_kw);
        } elif isinstance(s, TryStmt) {
            if s.awaiting_body is not None {
                if s.finally_body is not None {
                    self.emit(E2022, node_override=s);
                }
                if not s.in_client_context() {
                    target = "na" if s.in_native_context() else "sv";
                    self.emit(W2020, node_override=s, target=target);
                }
            }
            self._check_slot_body([b for b in s.body], in_loop, loop_kw);
            if s.awaiting_body is not None {
                self._check_slot_body(
                    [b for b in s.awaiting_body.body], in_loop, loop_kw
                );
            }
            for ex in s.excepts {
                self._check_slot_body([b for b in ex.body], in_loop, loop_kw);
            }
            self._check_slot_else(s.else_body, in_loop, loop_kw);
            if s.finally_body is not None {
                self._check_slot_body(
                    [b for b in s.finally_body.body], in_loop, loop_kw
                );
            }
        } elif isinstance(s, MatchStmt) {
            for cs in s.cases {
                self._check_slot_body([b for b in cs.body], in_loop, loop_kw);
            }
        } elif isinstance(s, SwitchStmt) {
            for cs in s.cases {
                self._check_slot_body([b for b in cs.body], in_loop, loop_kw);
            }
        }
    }
}

impl ASTValidationPass._check_slot_else(
    self: ASTValidationPass, else_body: object, in_loop: bool, loop_kw: str
) -> None {
    if else_body is None {
        return;
    }
    if isinstance(else_body, IfStmt) {
        self._check_slot_body([else_body], in_loop, loop_kw);
    } elif isinstance(else_body, ElseStmt) {
        self._check_slot_body([b for b in else_body.body], in_loop, loop_kw);
    }
}

impl ASTValidationPass._slot_emits_keyless_jsx(
    self: ASTValidationPass, stmts: list[UniNode]
) -> bool {
    for s in stmts {
        if isinstance(s, ExprStmt) and isinstance(s.expr, JsxElement) {
            el = s.expr;
            if (
                not el.is_fragment
                and el.dynamic_tag is None
                and not self._slot_has_key_attr(el)
            ) {
                return True;
            }
        } elif isinstance(s, WhileStmt)
            or isinstance(s, ForeverStmt)
            or isinstance(s, InForStmt)
            or isinstance(s, IterForStmt)
            or isinstance(s, WithStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                return True;
            }
        } elif isinstance(s, IfStmt) or isinstance(s, ElseStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                return True;
            }
        } elif isinstance(s, TryStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                return True;
            }
            if s.awaiting_body is not None
                and self._slot_emits_keyless_jsx([b for b in s.awaiting_body.body]) {
                return True;
            }
            for ex in s.excepts {
                if self._slot_emits_keyless_jsx([b for b in ex.body]) {
                    return True;
                }
            }
            if s.else_body is not None
                and isinstance(s.else_body, ElseStmt)
                and self._slot_emits_keyless_jsx([b for b in s.else_body.body]) {
                return True;
            }
            if s.finally_body is not None
                and self._slot_emits_keyless_jsx([b for b in s.finally_body.body]) {
                return True;
            }
        } elif isinstance(s, MatchStmt) or isinstance(s, SwitchStmt) {
            for cs in s.cases {
                if self._slot_emits_keyless_jsx([b for b in cs.body]) {
                    return True;
                }
            }
        }
    }
    return False;
}

impl ASTValidationPass._slot_has_key_attr(
    self: ASTValidationPass, el: JsxElement
) -> bool {
    if el.attributes is None {
        return False;
    }
    for a in el.attributes {
        if (
            isinstance(a, JsxNormalAttribute)
            and a.name is not None
            and a.name.value == "key"
        ) {
            return True;
        }
    }
    return False;
}
