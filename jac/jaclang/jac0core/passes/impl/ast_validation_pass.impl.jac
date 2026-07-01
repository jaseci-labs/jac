impl ASTValidationPass.enter_match_stmt(
    self: ASTValidationPass, nd: uni.MatchStmt
) -> None {
    if len(nd.cases) == 0 {
        self.emit(E0041, node_override=nd);
    }
}

impl ASTValidationPass.enter_module_code(
    self: ASTValidationPass, nd: uni.ModuleCode
) -> None {
    if isinstance(nd.parent, uni.Module) or nd.parent is None {
        for k in nd.kid {
            if isinstance(k, uni.Token) and k.name == Tok.KW_EXIT {
                self.emit(E0031, node_override=nd);
                break;
            }
        }
    }
}

impl ASTValidationPass.enter_binary_expr(
    self: ASTValidationPass, nd: uni.BinaryExpr
) -> None {
    if nd.op is not None
    and isinstance(nd.op, uni.Token)
    and nd.op.name == Tok.WALRUS_EQ {
        if not isinstance(nd.left, uni.Name)
        and not isinstance(nd.left, uni.SpecialVarRef) {
            self.emit(E0020, node_override=nd.left);
        } else {
            self._reject_non_bindable(nd.left);
        }
    }
}

impl ASTValidationPass.enter_name(self: ASTValidationPass, nd: uni.Name) -> None {
    if nd.value == "pass" {
        self.emit(E0010, node_override=nd, keyword="pass");
    }
}

impl ASTValidationPass.enter_param_var(
    self: ASTValidationPass, nd: uni.ParamVar
) -> None {
    sig = nd.parent;
    if isinstance(sig, uni.FuncSignature) and isinstance(sig.parent, uni.LambdaExpr) {
        return;
    }
    if nd.type_tag is None {
        param_name = nd.name.value if isinstance(nd.name, uni.Name) else str(nd.name);
        self.emit(E0052, node_override=nd, name=param_name);
    }
}

impl ASTValidationPass.enter_func_signature(
    self: ASTValidationPass, nd: uni.FuncSignature
) -> None {
    has_slash = False;
    has_star = False;
    has_kwargs = False;
    for k in nd.kid {
        if isinstance(k, uni.Token) and k.name == Tok.DIV {
            if has_slash {
                self.emit(E0050, node_override=k, param="/");
            } elif has_star {
                self.emit(E0051, node_override=k, first="/", second="*");
            } elif has_kwargs {
                self.emit(E0051, node_override=k, first="/", second="**kwargs");
            }
            has_slash = True;
        } elif isinstance(k, uni.Token) and k.name == Tok.STAR_MUL {
            if has_star {
                self.emit(E0050, node_override=k, param="*");
            } elif has_kwargs {
                self.emit(E0051, node_override=k, first="*", second="**kwargs");
            }
            has_star = True;
        } elif isinstance(k, uni.ParamVar) {
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
    self: ASTValidationPass, nd: uni.IterForStmt
) -> None {
    if nd.count_by is not None
    and isinstance(nd.count_by, uni.Assignment)
    and nd.count_by.aug_op is None {
        self.emit(E0023, node_override=nd.count_by);
    }
}

impl ASTValidationPass.enter_enum(self: ASTValidationPass, nd: uni.Enum) -> None {
    if nd.body is not None and len(nd.body) == 0 {
        self.emit(E0043, node_override=nd);
    }
}

impl ASTValidationPass.enter_switch_stmt(
    self: ASTValidationPass, nd: uni.SwitchStmt
) -> None {
    if len(nd.cases) == 0 {
        self.emit(E0042, node_override=nd);
    }
}

impl ASTValidationPass._reject_non_bindable(
    self: ASTValidationPass, target: object
) -> None {
    non_bindable = {Tok.KW_ROOT, Tok.KW_SUPER};
    if isinstance(target, (uni.TupleVal, uni.ListVal)) {
        for el in target.values {
            self._reject_non_bindable(el);
        }
        return;
    }

    ref = target.right if isinstance(target, uni.AtomTrailer) else target;

    if isinstance(ref, uni.Name) and (not ref.is_kwesc) and ref.name in non_bindable {
        self.emit(E0024, node_override=ref, name=ref.value);
    }
}

impl ASTValidationPass.enter_assignment(
    self: ASTValidationPass, nd: uni.Assignment
) -> None {
    for target in nd.target {
        self._reject_non_bindable(target);
    }
}

impl ASTValidationPass.enter_in_for_stmt(
    self: ASTValidationPass, nd: uni.InForStmt
) -> None {
    self._reject_non_bindable(nd.target);
}

impl ASTValidationPass.enter_inner_compr(
    self: ASTValidationPass, nd: uni.InnerCompr
) -> None {
    self._reject_non_bindable(nd.target);
}

impl ASTValidationPass.enter_has_var(self: ASTValidationPass, nd: uni.HasVar) -> None {
    self._reject_non_bindable(nd.name);
}

impl ASTValidationPass.enter_expr_as_item(
    self: ASTValidationPass, nd: uni.ExprAsItem
) -> None {
    if nd.alias is not None {
        self._reject_non_bindable(nd.alias);
    }
}

impl ASTValidationPass.enter_delete_stmt(
    self: ASTValidationPass, nd: uni.DeleteStmt
) -> None {
    self._reject_non_bindable(nd.target);
}

impl ASTValidationPass.enter_import(self: ASTValidationPass, nd: uni.Import) -> None {
    if nd.items is not None
    and len(nd.items) == 0
    and (nd.clib_decls is None or len(nd.clib_decls) == 0) {
        self.emit(E0044, node_override=nd);
    }
}

impl ASTValidationPass.enter_yield_expr(
    self: ASTValidationPass, nd: uni.YieldExpr
) -> None {
    if nd.find_parent_of_type(uni.Ability) is None
    and nd.find_parent_of_type(uni.ImplDef) is None {
        self.emit(E0055, node_override=nd);
    }
}

impl ASTValidationPass.enter_ctrl_stmt(
    self: ASTValidationPass, nd: uni.CtrlStmt
) -> None {
    if nd.ctrl is None or not isinstance(nd.ctrl, uni.Token) {
        return;
    }
    kw = nd.ctrl.value;
    if kw not in ("break", "continue") {
        return;
    }

    parent = nd.parent;
    while parent is not None {
        if isinstance(parent, (uni.InForStmt, uni.IterForStmt, uni.WhileStmt)) {
            return;
        }

        if kw == "break" and isinstance(parent, (uni.SwitchStmt, uni.MatchStmt)) {
            return;
        }

        if isinstance(parent, (uni.Ability, uni.ImplDef, uni.Module)) {
            break;
        }
        parent = parent.parent;
    }
    self.emit(E0058, node_override=nd, keyword=kw);
}

impl ASTValidationPass.enter_non_local_stmt(
    self: ASTValidationPass, nd: uni.NonLocalStmt
) -> None {
    if nd.find_parent_of_type(uni.Ability) is None
    and nd.find_parent_of_type(uni.ImplDef) is None {
        self.emit(E0062, node_override=nd);
    }
}

impl ASTValidationPass.enter_global_vars(
    self: ASTValidationPass, nd: uni.GlobalVars
) -> None {
    valid_parents = (uni.Module, uni.ClientBlock, uni.ServerBlock, uni.NativeBlock);
    if not isinstance(nd.parent, valid_parents) {
        self.emit(E0063, node_override=nd);
    }
}

impl ASTValidationPass.enter_func_call(
    self: ASTValidationPass, nd: uni.FuncCall
) -> None {
    if nd.params is None {
        return;
    }
    seen_kw = False;
    seen_kw_names: set[str] = set();
    for param in nd.params {
        if isinstance(param, uni.KWPair) {
            seen_kw = True;
            if param.key is not None {
                kw_name = param.key.value
                    if isinstance(param.key, uni.Name)
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

impl ASTValidationPass.enter_archetype(
    self: ASTValidationPass, nd: uni.Archetype
) -> None {
    if nd.base_classes is not None {
        seen_bases: set[str] = set();
        for base in nd.base_classes {
            base_name: str | None = None;
            if isinstance(base, uni.Name) {
                base_name = base.value;
            } elif isinstance(base, uni.AtomTrailer)
            and isinstance(base.right, uni.Name) {
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

    body: list = [];
    if isinstance(nd.body, (list, tuple)) {
        body = list(nd.body);
    } elif isinstance(nd.body, uni.ImplDef)
    and isinstance(nd.body.body, (list, tuple)) {
        body = list(nd.body.body);
    }

    properties_seen: set[str] = set();
    for item in body {
        if (
            isinstance(item, uni.Ability)
            and item.name_ref is not None
            and item.decorators is not None
        ) {
            for dec in item.decorators {
                if isinstance(dec, uni.Name) and dec.value == "property" {
                    properties_seen.add(item.name_ref.value);
                    break;
                }
            }
        }
    }

    seen_methods: set[str] = set();
    seen_accessors: set[tuple[(str, str)]] = set();
    for item in body {
        if not (isinstance(item, uni.Ability) and item.name_ref is not None) {
            continue;
        }
        has_overload = False;
        accessor_kind: (str | None) = None;
        accessor_target: (str | None) = None;
        if item.decorators is not None {
            for dec in item.decorators {
                if isinstance(dec, uni.Name) and dec.value == "overload" {
                    has_overload = True;
                } elif (
                    isinstance(dec, uni.AtomTrailer)
                    and isinstance(dec.right, uni.Name)
                    and dec.right.value in ("setter", "getter", "deleter")
                    and isinstance(dec.target, uni.Name)
                ) {
                    accessor_kind = dec.right.value;
                    accessor_target = dec.target.value;
                }
            }
        }

        if has_overload {
            continue;
        }
        mname = item.name_ref.value;

        dedup_name = '__init__' if item.name_ref.name == Tok.KW_INIT else mname;

        if (
            accessor_kind is not None
            and accessor_target == mname
            and mname in properties_seen
        ) {
            key = (mname, accessor_kind);
            if key in seen_accessors {
                self.emit(E0076, node_override=item.name_ref, name=mname);
            }
            seen_accessors.add(key);
            continue;
        }
        if dedup_name in seen_methods {
            self.emit(E0076, node_override=item.name_ref, name=mname);
        }
        seen_methods.add(dedup_name);
    }
}

impl ASTValidationPass.enter_try_stmt(
    self: ASTValidationPass, nd: uni.TryStmt
) -> None {
    if len(nd.excepts) == 0 and nd.finally_body is None and nd.awaiting_body is None {
        self.emit(E0040, node_override=nd);
    }

    for (i, exc) in enumerate(nd.excepts) {
        if exc.ex_type is None and i < len(nd.excepts) - 1 {
            self.emit(E0071, node_override=exc);
        }
    }
}

impl ASTValidationPass.enter_jsx_slot(
    self: ASTValidationPass, nd: uni.JsxSlot
) -> None {
    self._check_slot_body([s for s in nd.body], False, "");
}

impl ASTValidationPass._check_slot_body(
    self: ASTValidationPass, stmts: list, in_loop: bool, loop_kw: str
) -> None {
    for s in stmts {
        if isinstance(s, uni.ReturnStmt) {
            if s.expr is not None {
                self.emit(E2019, node_override=s);
            } else {
                self.emit(E2020, node_override=s);
            }
        } elif isinstance(s, uni.CtrlStmt) {
            if in_loop and s.ctrl.value == "break" {
                self.emit(E2021, node_override=s, kw=s.ctrl.value, loop=loop_kw);
            }
        } elif isinstance(s, uni.ArchHas) {
            self.emit(E2024, node_override=s);
        } elif isinstance(s, uni.WhileStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                self.emit(W2019, node_override=s);
            }
            self._check_slot_body([b for b in s.body], True, "while");
            self._check_slot_else(s.else_body, in_loop, loop_kw);
        } elif isinstance(s, uni.InForStmt) or isinstance(s, uni.IterForStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                self.emit(W2021, node_override=s);
            }
            self._check_slot_body([b for b in s.body], True, "for");
            self._check_slot_else(s.else_body, in_loop, loop_kw);
        } elif isinstance(s, uni.IfStmt) {
            self._check_slot_body([b for b in s.body], in_loop, loop_kw);
            self._check_slot_else(s.else_body, in_loop, loop_kw);
        } elif isinstance(s, uni.WithStmt) {
            self._check_slot_body([b for b in s.body], in_loop, loop_kw);
        } elif isinstance(s, uni.TryStmt) {
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
        } elif isinstance(s, uni.MatchStmt) {
            for cs in s.cases {
                self._check_slot_body([b for b in cs.body], in_loop, loop_kw);
            }
        } elif isinstance(s, uni.SwitchStmt) {
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
    if isinstance(else_body, uni.IfStmt) {
        self._check_slot_body([else_body], in_loop, loop_kw);
    } elif isinstance(else_body, uni.ElseStmt) {
        self._check_slot_body([b for b in else_body.body], in_loop, loop_kw);
    }
}

impl ASTValidationPass._slot_emits_keyless_jsx(
    self: ASTValidationPass, stmts: list
) -> bool {
    for s in stmts {
        if isinstance(s, uni.ExprStmt) and isinstance(s.expr, uni.JsxElement) {
            el = s.expr;
            if (
                not el.is_fragment
                and el.dynamic_tag is None
                and not self._slot_has_key_attr(el)
            ) {
                return True;
            }
        } elif isinstance(s, uni.WhileStmt)
        or isinstance(s, uni.InForStmt)
        or isinstance(s, uni.IterForStmt)
        or isinstance(s, uni.WithStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                return True;
            }
        } elif isinstance(s, uni.IfStmt) or isinstance(s, uni.ElseStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                return True;
            }
        } elif isinstance(s, uni.TryStmt) {
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
            and isinstance(s.else_body, uni.ElseStmt)
            and self._slot_emits_keyless_jsx([b for b in s.else_body.body]) {
                return True;
            }
            if s.finally_body is not None
            and self._slot_emits_keyless_jsx([b for b in s.finally_body.body]) {
                return True;
            }
        } elif isinstance(s, uni.MatchStmt) or isinstance(s, uni.SwitchStmt) {
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
    self: ASTValidationPass, el: uni.JsxElement
) -> bool {
    if el.attributes is None {
        return False;
    }
    for a in el.attributes {
        if (
            isinstance(a, uni.JsxNormalAttribute)
            and a.name is not None
            and a.name.value == "key"
        ) {
            return True;
        }
    }
    return False;
}
