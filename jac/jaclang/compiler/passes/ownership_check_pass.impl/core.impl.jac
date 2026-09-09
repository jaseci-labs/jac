import from jaclang.compiler.frontend.diagnostics {
    E1301,
    E1316,
    E1317,
    E1318,
    E1302,
    E1303,
    E1304,
    E1305,
    E1306,
    E1311,
    W1312
}

glob _MOVE_EXEMPT_CALLS: tuple = (
         "len",
         "print",
         "range",
         "isinstance",
         "next",
         "abs",
         "min",
         "max",
         "sum",
         "sorted",
         "repr",
         "format",
         "chr",
         "ord",
         "hex",
         "oct",
         "bin"
     ),
     _NONRETAINING_METHOD_CALLS: tuple = (
         "find",
         "rfind",
         "index",
         "count",
         "startswith",
         "endswith",
         "upper",
         "lower",
         "strip",
         "lstrip",
         "rstrip",
         "split",
         "rsplit",
         "splitlines",
         "replace",
         "join",
         "get",
         "write",
         "issubset",
         "issuperset",
         "isdisjoint",
         "union",
         "intersection",
         "difference",
         "symmetric_difference"
     ),
     _NONRETAINING_STDLIB_MODULES: tuple = (
         "os",
         "sys",
         "time",
         "math",
         "random",
         "struct"
     );

impl OwnershipCheckPass.postinit -> None {
    super.postinit();
}

glob _MUTATING_CONTAINER_METHODS: frozenset[str] = frozenset(
         {
             "append",
             "insert",
             "add",
             "remove",
             "pop",
             "clear",
             "extend",
             "update",
             "setdefault",
             "popitem",
             "sort",
             "reverse",
             "discard"
         }
     );

impl OwnershipCheckPass._run_impl(ir_in: Module) -> Module {
    self.owned_decl = {};
    self.consumed_syms = set();
    self.borrow_meta = {};
    self.e1304_borrow_ids = set();
    self.in_consumed = {};
    self.in_live_borrows = {};
    self.in_reaching_borrows = {};
    self.consumed_at = {};
    self.borrow_created_at = {};
    self.idx_assignments = [];
    self.idx_names = [];
    self.idx_params = [];
    self.idx_returns = [];
    self.idx_concurrent = [];
    self.name_uses_by_sym = {};
    self.imm_decl = {};
    self.view_syms = set();
    self.view_elision_fns = {};
    ir_in.own_move_sites = set();
    self.receiver_modes = {};
    self.receiver_probe = set();
    self.arch_view_syms = set();

    self._build_index(ir_in);
    self._stamp_receiver_modes();
    self._stamp_raises_effects();
    self._stamp_ownership();
    self._stamp_loop_borrows();
    self._stamp_region_borrows();
    self._stamp_arch_view_bindings();
    self._process_partition_sugar();
    self._nogc_setup();
    self._emit_place_intrinsic_diagnostics();
    if not self.owned_decl
        and not self.borrow_meta
        and not self.imm_decl
        and not self._has_region_blocks()
        and not self.idx_concurrent
        and not self._flow_for_stmts()
        and self.nogc_prov is None {
        return ir_in;
    }

    cfg_nodes = [
        n
        for n in ir_in.flatten()
        if isinstance(n, UniCFGNode)
    ];
    self._run_dataflow(cfg_nodes);
    self._stamp_overwrite_consumed();
    self._stamp_move_sites();
    self._run_borrow_liveness(cfg_nodes);
    self._run_reaching_borrows(cfg_nodes);
    self._emit_diagnostics();
    self._emit_linear_diagnostics(cfg_nodes);
    self._emit_receiver_diagnostics();
    self._emit_raises_diagnostics();
    self._emit_place_move_diagnostics();
    self._emit_borrow_diagnostics();
    self._emit_element_space_conflicts();
    self._emit_move_while_borrowed(cfg_nodes);
    self._emit_escape_diagnostics();
    self._emit_view_diagnostics();
    self._emit_region_escape_diagnostics();
    self._emit_sendability_diagnostics();
    self._emit_flow_for_diagnostics();
    self._emit_chunk_view_diagnostics();
    self._emit_marker_diagnostics();
    self._emit_freeze_diagnostics();
    self._emit_seal_warnings();
    self._emit_enforcement_diagnostics();
    return ir_in;
}

impl OwnershipCheckPass._is_own_decl(nd: Assignment) -> (Name | None) {
    if not (nd.type_tag and nd.type_tag.ownership == OwnershipKind.OWN) {
        return None;
    }
    if len(nd.target) != 1 {
        return None;
    }
    target = nd.target[0];
    if isinstance(target, Name) and target.sym {
        return target;
    }
    return None;
}

impl OwnershipCheckPass._is_borrow_decl(nd: Assignment) -> (Name | None) {
    if not (nd.type_tag and is_borrow_kind(nd.type_tag.ownership)) {
        return None;
    }
    if len(nd.target) != 1 {
        return None;
    }
    target = nd.target[0];
    if isinstance(target, Name) and target.sym {
        return target;
    }
    return None;
}

impl OwnershipCheckPass._borrow_target(nd: Assignment) -> (Name | None) {
    decl_target = self._is_borrow_decl(nd);
    if decl_target is not None {
        return decl_target;
    }
    if len(nd.target) != 1 {
        return None;
    }
    target = nd.target[0];
    if isinstance(target, Name) and self._borrow_sym_of(target) is not None {
        return target;
    }
    return None;
}

impl OwnershipCheckPass._borrow_source_owner(nd: Assignment) -> (Name | None) {
    if not isinstance(nd.value, UnaryExpr) {
        return None;
    }
    is_borrow_val = is_borrow_kind(nd.value.ownership);

    if not is_borrow_val and len(nd.target) == 1 {
        tgt = nd.target[0];
        if isinstance(tgt, Name) and self._borrow_sym_of(tgt) is not None {
            is_borrow_val = True;
        }
    }
    if not is_borrow_val {
        return None;
    }
    operand = nd.value.operand;
    if self._owned_sym_of_expr(operand) is not None {
        place = self._place_of(operand);
        if place is not None {
            return place;
        }
    }
    return None;
}

impl OwnershipCheckPass._build_index(tree: UniNode) -> None {
    self.idx_assignments = tree.get_all_sub_nodes(Assignment);
    self.idx_names = tree.get_all_sub_nodes(Name);
    self.idx_params = tree.get_all_sub_nodes(ParamVar);
    self.idx_returns = tree.get_all_sub_nodes(ReturnStmt);
    self.idx_concurrent = tree.get_all_sub_nodes(ConcurrentExpr);
    for name in self.idx_names {
        sid = self._sym_id(name);
        if sid is None {
            continue;
        }
        if sid in self.name_uses_by_sym {
            self.name_uses_by_sym[sid].append(name);
        } else {
            self.name_uses_by_sym[sid] = [name];
        }
    }
}

impl OwnershipCheckPass._stamp_ownership -> None {
    for nd in self.idx_assignments {
        for tgt in nd.target {
            if isinstance(tgt, Name) and tgt.sym {
                tgt.sym.ownership = OwnershipKind.NONE;
            }
        }
    }
    for param in self.idx_params {
        name = param.name;
        if isinstance(name, Name) and name.sym {
            name.sym.ownership = OwnershipKind.NONE;
        }
    }

    for nd in self.idx_assignments {
        own_target = self._is_own_decl(nd);
        if own_target is not None and own_target.sym is not None {
            sid = self._name_sym_id(own_target);
            own_target.sym.ownership = OwnershipKind.OWN;
            self.owned_decl[sid] = own_target;
            if nd.type_tag is not None and nd.type_tag.linear {
                own_target.sym.linear = True;
                self.linear_decl[sid] = own_target;
            }
        }
        borrow_target = self._is_borrow_decl(nd);
        if borrow_target is not None and borrow_target.sym is not None {
            sid = self._name_sym_id(borrow_target);
            is_mut = nd.type_tag.ownership == OwnershipKind.MUT_BORROW
                if nd.type_tag
                else False;
            borrow_target.sym.ownership = OwnershipKind.MUT_BORROW
                if is_mut
                else OwnershipKind.BORROW;
            self.borrow_meta[sid] = BorrowMeta(
                name=borrow_target.sym_name, is_mut=is_mut
            );
            self.borrow_created_at[sid] = nd;
        }
        tag = nd.type_tag;
        _rhs_imm = (
            isinstance(nd.value, UnaryExpr) and nd.value.ownership == OwnershipKind.IMM
        );
        if (tag is not None or _rhs_imm) and len(nd.target) == 1 {
            target = nd.target[0];
            if isinstance(target, Name) and target.sym {
                sid = self._name_sym_id(target);
                if (tag is not None and tag.ownership == OwnershipKind.IMM)
                    or _rhs_imm {
                    target.sym.ownership = OwnershipKind.IMM;
                    self.imm_decl[sid] = target;
                }
            }
        }
    }

    for param in self.idx_params {
        tag = param.type_tag;
        if tag is None {
            continue;
        }
        name = param.name;
        if not (isinstance(name, Name) and name.sym) {
            continue;
        }
        sid = self._name_sym_id(name);
        if is_borrow_kind(tag.ownership) {
            is_mut = tag.ownership == OwnershipKind.MUT_BORROW;
            name.sym.ownership = OwnershipKind.MUT_BORROW
                if is_mut
                else OwnershipKind.BORROW;
            self.borrow_meta[sid] = BorrowMeta(name=name.sym_name, is_mut=is_mut);
            self.borrow_created_at[sid] = param;
        } elif tag.ownership == OwnershipKind.OWN {
            name.sym.ownership = OwnershipKind.OWN;
            self.owned_decl[sid] = name;
            if tag.linear {
                name.sym.linear = True;
                self.linear_decl[sid] = name;
            }
        } elif tag.ownership == OwnershipKind.IMM {
            name.sym.ownership = OwnershipKind.IMM;
            self.imm_decl[sid] = name;
        }
    }

    for nd in self.idx_assignments {
        borrow_target = self._borrow_target(nd);
        owner = self._borrow_source_owner(nd);
        if borrow_target is not None
            and borrow_target.sym is not None
            and owner is not None {
            borrow_id = self._name_sym_id(borrow_target);
            owner_id = self._name_sym_id(owner);
            self.borrow_meta[borrow_id] = BorrowMeta(
                name=borrow_target.sym_name,
                owner=owner_id,
                is_mut=is_mut_kind(borrow_target.sym.ownership)
                    or (
                        is_mut_kind(nd.value.ownership)
                            if isinstance(nd.value, UnaryExpr)
                            else False
                    ),
                field=self._single_field_of(nd.value.operand)
                    if isinstance(nd.value, UnaryExpr)
                    else ""
            );
            self.borrow_created_at[borrow_id] = nd;
        }
    }
}

impl OwnershipCheckPass._emit_seal_warnings -> None {
    for call in self.ir_in.get_all_sub_nodes(FuncCall) {
        _cd = call.callee_decl;
        if _cd is None
            or _cd.signature is None
            or not isinstance(_cd.signature, FuncSignature) {
            continue;
        }
        if isinstance(call.target, Name) and call.target.sym_name == "managed" {
            continue;
        }
        _params = _cd.signature.get_parameters();
        for (i, a) in enumerate(call.params or []) {
            if isinstance(a, KWPair) or not isinstance(a, Name) {
                continue;
            }
            if a.sym is None or a.sym.ownership != OwnershipKind.OWN {
                continue;
            }
            if i >= len(_params) {
                continue;
            }
            _ptag = _params[i].type_tag;
            if _ptag is not None and _ptag.ownership != OwnershipKind.NONE {
                continue;
            }
            self.emit(W1312, node_override=a, name=a.sym_name);
        }
    }
}

impl OwnershipCheckPass._emit_freeze_diagnostics -> None {
    for ux in self.ir_in.get_all_sub_nodes(UnaryExpr) {
        if ux.ownership != OwnershipKind.IMM {
            continue;
        }
        if ux.find_parent_of_type(SubTag) is not None
            or ux.find_parent_of_type(FuncSignature) is not None {
            continue;
        }
        arg = ux.operand;
        if isinstance(arg, Name) {
            s = arg.sym;
            if s is not None and s.ownership == OwnershipKind.OWN {
                continue;
            }
            self.emit(E1311, node_override=ux, name=arg.sym_name);
            continue;
        }
        if isinstance(
            arg, (FuncCall, ListVal, SetVal, DictVal, String, MultiString, FString)
        ) {
            continue;
        }
        self.emit(E1311, node_override=ux, name="<expression>");
    }
}

impl OwnershipCheckPass._spawn_move_gen(nd: UniCFGNode) -> set[SymId] {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    gen: set[SymId] = set();
    operands: list[Expr] = [];
    for bx in nd.get_all_sub_nodes(BinaryExpr) {
        if isinstance(bx.op, ConnectOp) {
            _seal_h = self._seal_connect_handle(bx);
            if _seal_h is not None {
                operands.append(_seal_h);
            }
        } elif bx.op?.name == Tok.KW_SPAWN {
            operands.append(bx.left);
            operands.append(bx.right);
        }
    }
    for ux in nd.get_all_sub_nodes(UnaryExpr) {
        if ux.op?.name == Tok.KW_SPAWN {
            operands.append(ux.operand);
        }
        if ux.ownership == OwnershipKind.IMM
            and ux.find_parent_of_type(SubTag) is None {
            operands.append(ux.operand);
        }
    }
    for opnd in operands {
        if isinstance(opnd, Name)
            and opnd.sym is not None
            and opnd.sym.ownership == OwnershipKind.OWN {
            sid = self._name_sym_id(opnd);
            gen.add(sid);
        }
    }
    return gen;
}

impl OwnershipCheckPass._emit_element_space_conflicts -> None {
    _writers = (
        "append",
        "insert",
        "add",
        "remove",
        "pop",
        "clear",
        "extend",
        "update"
    );
    for call in self.ir_in.get_all_sub_nodes(FuncCall) {
        tgt = call.target;
        if not (
            isinstance(tgt, AtomTrailer)
            and tgt.is_attr
            and isinstance(tgt.right, Name)
            and tgt.right.sym_name in _writers
        ) {
            continue;
        }
        _ownr = self._place_of(tgt.target);
        if _ownr is None
            or _ownr.sym is None
            or _ownr.sym.ownership != OwnershipKind.OWN {
            continue;
        }
        owner_id = self._name_sym_id(_ownr);
        cfg = self._cfg_owner(call);
        if cfg is None {
            continue;
        }
        _active = self._active_borrows_at(cfg);
        for (b, meta) in self.borrow_meta.items() {
            if meta.owner != owner_id {
                continue;
            }
            if not self._fields_overlap(meta.field, "[]") {
                continue;
            }
            _site = self.borrow_created_at.get(b);
            if isinstance(_site, InForStmt) {
                if not self._is_ancestor(_site, call) {
                    continue;
                }
            } elif b not in _active {
                continue;
            }
            bsite = self.borrow_created_at.get(b);
            bname = self._borrow_display_name(b, "");
            related = [(f"element loan of '{bname}' created here", bsite)]
                if bsite is not None
                else None;
            code = E1302 if self._borrow_is_mut_of(b) else E1303;
            self.emit(code, node_override=call, name=_ownr.sym_name, related=related);
            break;
        }
    }
}

impl OwnershipCheckPass._stamp_loop_borrows -> None {
    for st in self.ir_in.get_all_sub_nodes(InForStmt) {
        coll = st.collection;
        if not (isinstance(coll, UnaryExpr) and is_borrow_kind(coll.ownership)) {
            continue;
        }
        owner = self._place_of(coll.operand);
        if owner is None {
            _chk = self._chunks_shape_of(coll.operand);
            if _chk is not None {
                owner = self._place_of(_chk[0]);
            }
        }
        if owner is None
            or owner.sym is None
            or owner.sym.ownership != OwnershipKind.OWN {
            continue;
        }
        tgt = st.target;
        if not (isinstance(tgt, Name) and tgt.sym is not None) {
            continue;
        }
        borrow_id = self._name_sym_id(tgt);
        is_mut = is_mut_kind(coll.ownership);
        tgt.sym.ownership = OwnershipKind.MUT_BORROW
            if is_mut
            else OwnershipKind.BORROW;
        self.borrow_meta[borrow_id] = BorrowMeta(
            name=tgt.sym_name, owner=self._name_sym_id(owner), is_mut=is_mut, field="[]"
        );
        self.borrow_created_at[borrow_id] = st;
    }
}

impl OwnershipCheckPass._return_roots_at_param_borrow(nd: Expr | None) -> bool {
    base = self._place_of(nd);
    if base is None {
        return False;
    }
    if (
        base.sym is not None
        and base.sym.storage == SymbolStorage.PARAM
        and is_borrow_kind(base.sym.ownership)
    ) {
        return True;
    }
    _vsid = self._borrow_sym_of(nd);
    if _vsid is not None and _vsid in self.view_syms {
        return self._sym_is_param(self._view_root_owner(_vsid));
    }
    return False;
}

impl OwnershipCheckPass._borrow_region(sym_id: SymId) -> (UniScopeNode | None) {
    owner_id = self._borrow_owner_of(sym_id);
    if owner_id is not None and owner_id in self.owned_decl {
        return self.owned_decl[owner_id].find_parent_of_type(UniScopeNode);
    }
    return None;
}

impl OwnershipCheckPass._region_strictly_outlives(
    dest: UniScopeNode | None, region: UniScopeNode | None
) -> bool {
    if dest is None or region is None {
        return False;
    }
    if dest is region {
        return False;
    }
    return self._is_ancestor(dest, region);
}

impl OwnershipCheckPass._assign_kill_gen(
    nd: Assignment
) -> tuple[set[SymId], set[SymId]] {
    kill: set[SymId] = set();
    gen: set[SymId] = set();
    if nd.aug_op is not None {
        return (kill, gen);
    }
    decl_target = self._is_own_decl(nd);
    if decl_target is not None {
        kill.add(self._name_sym_id(decl_target));
    } else {
        for tgt in nd.target {
            owned = self._owned_sym_of(tgt);
            if owned is not None {
                kill.add(owned);
            }
        }
    }

    val_owned = self._owned_sym_of(nd.value);
    if val_owned is not None {
        gen.add(val_owned);
    }
    return (kill, gen);
}

impl OwnershipCheckPass._call_params(call: FuncCall) -> Sequence[Expr | KWPair] {
    return call.params or [];
}

impl OwnershipCheckPass._cfg_owner(sub: UniNode) -> (UniCFGNode | None) {
    if isinstance(sub, UniCFGNode) {
        return sub;
    }
    return sub.find_parent_of_type(UniCFGNode);
}

impl _stdlib_attr_call_root(call: FuncCall) -> (str | None) {
    if not isinstance(call.target, AtomTrailer) {
        return None;
    }
    _t = call.target.target;
    while isinstance(_t, AtomTrailer) {
        _t = _t.target;
    }
    if isinstance(_t, Name) {
        return _t.value;
    }
    return None;
}

impl OwnershipCheckPass._call_consumes_args(call: FuncCall) -> bool {
    if isinstance(call.target, Name) and call.target.sym_name in _MOVE_EXEMPT_CALLS {
        return False;
    }
    if isinstance(call.target, AtomTrailer) {
        if isinstance(call.target.right, Name)
            and call.target.right.value in _NONRETAINING_METHOD_CALLS {
            return False;
        }
        _stdlib_root = _stdlib_attr_call_root(call);
        if _stdlib_root is not None and _stdlib_root in _NONRETAINING_STDLIB_MODULES {
            return False;
        }
        if self._nogc_container_grow_method(call) is not None {
            return False;
        }
    }
    return True;
}

impl OwnershipCheckPass._call_move_gen(nd: UniCFGNode) -> set[SymId] {
    gen: set[SymId] = set();
    for call in nd.get_all_sub_nodes(FuncCall) {
        if self._cfg_owner(call) is not nd {
            continue;
        }
        if self._method_call_mode(call) == OwnershipKind.OWN {
            recv = self._method_call_receiver(call);
            recv_owned = self._owned_sym_of(recv);
            if recv_owned is not None {
                gen.add(recv_owned);
            }
        }
        consumes_all = self._call_consumes_args(call);
        for param in self._call_params(call) {
            arg: Expr | None = None;
            if isinstance(param, KWPair) {
                arg = param.value;
            } elif isinstance(param, Expr) {
                arg = param;
            }
            if not consumes_all and not self._grow_arg_moves(call, arg) {
                continue;
            }
            owned = self._owned_sym_of(arg);
            if owned is not None {
                gen.add(owned);
            }
        }
    }
    return gen;
}

impl OwnershipCheckPass._emit_linear_diagnostics(cfg_nodes: list[UniCFGNode]) -> None {
    if not self.linear_decl {
        return;
    }
    universe = set(self.linear_decl.keys());
    must_in = solve_forward_must(cfg_nodes, self._transfer, universe);
    for (sid, decl) in self.linear_decl.items() {
        scope: UniNode | None = decl.find_parent_of_type(Ability);
        if scope is None {
            scope = decl.find_parent_of_type(ModuleCode);
        }
        if scope is None {
            continue;
        }
        for n in cfg_nodes {
            if n is scope
                or not self._node_within(n, scope)
                or not self._is_scope_exit(n) {
                continue;
            }
            if sid not in self._transfer(n, must_in.get(id(n), set())) {
                self.emit(E1305, node_override=decl, name=decl.sym_name);
                break;
            }
        }
    }
}

impl OwnershipCheckPass._node_within(nd: UniNode, scope: UniNode) -> bool {
    cur: UniNode | None = nd.parent;
    while cur is not None {
        if cur is scope {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl OwnershipCheckPass._is_scope_exit(nd: UniCFGNode) -> bool {
    if not nd.bb_out {
        return bool(nd.bb_in);
    }
    if isinstance(nd, AstElseBodyNode) and nd.else_body is not None {
        return False;
    }
    for succ in nd.bb_out {
        if not self._node_within(succ, nd) {
            return False;
        }
    }
    return True;
}

impl OwnershipCheckPass._raise_type_name(nd: RaiseStmt) -> (str | None) {
    cause = nd.cause;
    if isinstance(cause, FuncCall) {
        cause = cause.target;
    }
    if isinstance(cause, Name) {
        return cause.sym_name;
    }
    if isinstance(cause, AtomTrailer) and isinstance(cause.right, Name) {
        return cause.right.sym_name;
    }
    if cause is None {
        handler = nd.find_parent_of_type(Except);
        if handler is not None {
            ex = handler.ex_type;
            if isinstance(ex, Name) {
                return ex.sym_name;
            }
        }
        return "Exception";
    }
    return None;
}

impl OwnershipCheckPass._handled_by_enclosing_try(
    nd: UniNode, exc: str, stop: UniNode
) -> bool {
    child: UniNode = nd;
    cur: UniNode | None = nd.parent;
    while cur is not None and cur is not stop {
        if isinstance(cur, TryStmt) and child in list(cur.body) {
            for handler in cur.excepts {
                ex = handler.ex_type;
                caught = ex.sym_name if isinstance(ex, Name) else None;
                if caught in (exc, "Exception", "BaseException") {
                    return True;
                }
            }
        }
        child = cur;
        cur = cur.parent;
    }
    return False;
}

impl OwnershipCheckPass._callee_ability(call: FuncCall) -> (Ability | None) {
    import from jaclang.compiler.symbol_utils { resolved_callee }
    return resolved_callee(call);
}

impl OwnershipCheckPass._local_raises(ab: UniNode) -> set[str] {
    out: set[str] = set();
    for rs in ab.get_all_sub_nodes(RaiseStmt) {
        owner = rs.find_parent_of_type(Ability);
        if isinstance(ab, Ability) {
            if owner is not ab {
                continue;
            }
        } elif owner is not None and self._node_within(owner, ab) {
            continue;
        }
        exc = self._raise_type_name(rs);
        if exc is None or self._handled_by_enclosing_try(rs, exc, ab) {
            continue;
        }
        out.add(exc);
    }
    for call in ab.get_all_sub_nodes(FuncCall) {
        owner = call.find_parent_of_type(Ability);
        if isinstance(ab, Ability) and owner is not ab {
            continue;
        }
        if not isinstance(ab, Ability)
            and owner is not None
            and self._node_within(owner, ab) {
            continue;
        }
        callee = self._callee_ability(call);
        if callee is None or callee is ab {
            continue;
        }
        for exc in callee.raises {
            if not self._handled_by_enclosing_try(call, exc, ab) {
                out.add(exc);
            }
        }
    }
    return out;
}

impl OwnershipCheckPass._stamp_raises_effects -> None {
    abilities = [
        ab
        for ab in self.ir_in.get_all_sub_nodes(Ability)
        if ab.body is not None
    ];
    if not abilities {
        return;
    }
    for ab in abilities {
        ab.raises = [];
    }
    changed = True;
    while changed {
        changed = False;
        for ab in abilities {
            new = sorted(self._local_raises(ab));
            if new != ab.raises {
                ab.raises = new;
                changed = True;
            }
        }
    }
}

impl OwnershipCheckPass._grow_arg_moves(call: FuncCall, arg: Expr | None) -> bool {
    if not isinstance(arg, Name) or self._owned_sym_of(arg) is None {
        return False;
    }
    _grow = self._nogc_container_grow_method(call);
    if _grow is None or _grow == "add" {
        return False;
    }
    _direct = False;
    for _p in self._call_params(call) {
        if (_p.value if isinstance(_p, KWPair) else _p) is arg {
            _direct = True;
            break;
        }
    }
    if not _direct {
        return False;
    }
    return not self._nogc_type_is_str(arg);
}

impl OwnershipCheckPass._return_move_gen(nd: UniCFGNode) -> set[SymId] {
    gen: set[SymId] = set();
    returns: list[ReturnStmt] = [];
    if isinstance(nd, ReturnStmt) {
        returns.append(nd);
    }
    for ret in nd.get_all_sub_nodes(ReturnStmt) {
        returns.append(ret);
    }
    for ret in returns {
        if self._cfg_owner(ret) is not nd {
            continue;
        }
        owned = self._owned_sym_of(ret.expr);
        if owned is not None {
            gen.add(owned);
        }
    }
    return gen;
}

impl OwnershipCheckPass._transfer(nd: UniCFGNode, in_set: set[SymId]) -> set[SymId] {
    out = set(in_set);
    assign_kill: set[SymId] = set();
    if isinstance(nd, Assignment) {
        (kill, gen) = self._assign_kill_gen(nd);
        assign_kill = kill;
        for g in gen {
            out.add(g);
            if g not in self.consumed_at {
                self.consumed_at[g] = nd.value if nd.value is not None else nd;
            }
        }
    }
    for g in self._call_move_gen(nd) {
        out.add(g);
        if g not in self.consumed_at {
            self.consumed_at[g] = nd;
        }
    }
    for g in self._return_move_gen(nd) {
        out.add(g);
        if g not in self.consumed_at {
            self.consumed_at[g] = nd;
        }
    }
    for g in self._spawn_move_gen(nd) {
        out.add(g);
        if g not in self.consumed_at {
            self.consumed_at[g] = nd;
        }
    }

    for k in assign_kill {
        out.discard(k);
    }
    return out;
}

impl OwnershipCheckPass._solve_forward_dataflow(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set[SymId]] {
    return solve_forward(cfg_nodes, transfer);
}

impl OwnershipCheckPass._solve_backward_dataflow(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set[SymId]] {
    return solve_backward(cfg_nodes, transfer);
}

impl OwnershipCheckPass._run_dataflow(cfg_nodes: list[UniCFGNode]) -> None {
    self.in_consumed = self._solve_forward_dataflow(cfg_nodes, self._transfer);
    self.consumed_syms = set();
    for n in cfg_nodes {
        out = self._transfer(n, self.in_consumed.get(id(n), set()));
        for consumed in out {
            self.consumed_syms.add(consumed);
        }
    }
}

impl OwnershipCheckPass._borrow_read_gen(nd: UniCFGNode) -> set[SymId] {
    gen: set[SymId] = set();
    for name in nd.get_all_sub_nodes(Name) {
        borrow = self._borrow_sym_of(name);
        if borrow is not None and self._is_read_name(name) {
            gen.add(borrow);
        }
    }
    return gen;
}

impl OwnershipCheckPass._borrow_assign_kill_gen(
    nd: UniCFGNode
) -> tuple[set[SymId], set[SymId]] {
    kill: set[SymId] = set();
    gen: set[SymId] = set();
    if isinstance(nd, Assignment) {
        target = self._borrow_target(nd);
        if target is not None {
            borrow_id = self._name_sym_id(target);
            kill.add(borrow_id);
            if self._borrow_source_owner(nd) is not None
                or (
                    borrow_id in self.arch_view_syms
                    and self.borrow_created_at.get(borrow_id) is nd
                ) {
                gen.add(borrow_id);
            }
        }
    }
    return (kill, gen);
}

impl OwnershipCheckPass._live_transfer(
    nd: UniCFGNode, out_set: set[SymId]
) -> set[SymId] {
    (kill, _) = self._borrow_assign_kill_gen(nd);
    new_in = set(out_set);
    for k in kill {
        new_in.discard(k);
    }
    for g in self._borrow_read_gen(nd) {
        new_in.add(g);
    }
    return new_in;
}

impl OwnershipCheckPass._run_borrow_liveness(cfg_nodes: list[UniCFGNode]) -> None {
    self.in_live_borrows = self._solve_backward_dataflow(
        cfg_nodes, self._live_transfer
    );
}

impl OwnershipCheckPass._reaching_transfer(
    nd: UniCFGNode, in_set: set[SymId]
) -> set[SymId] {
    out = set(in_set);
    (kill, gen) = self._borrow_assign_kill_gen(nd);
    for k in kill {
        out.discard(k);
    }
    for g in gen {
        out.add(g);
    }
    return out;
}

impl OwnershipCheckPass._run_reaching_borrows(cfg_nodes: list[UniCFGNode]) -> None {
    self.in_reaching_borrows = self._solve_forward_dataflow(
        cfg_nodes, self._reaching_transfer
    );
}

impl OwnershipCheckPass._is_ancestor(ancestor: UniNode, nd: UniNode) -> bool {
    cur: UniNode | None = nd;
    while cur is not None {
        if cur is ancestor {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl OwnershipCheckPass._classify_access(nd: Name) -> AccessKind {
    parent = nd.parent;
    if isinstance(parent, Assignment) {
        for tgt in parent.target {
            if tgt is nd {
                return AccessKind.ASSIGN_TARGET;
            }
            if not self._is_ancestor(tgt, nd) {
                continue;
            }
            held = nd.parent;
            if isinstance(held, AtomTrailer) {
                if held.right is nd {
                    return (
                        AccessKind.ATTR_TARGET
                            if held.is_attr
                            else AccessKind.SUBSCRIPT_TARGET
                    );
                }
                return AccessKind.READ;
            }
            return AccessKind.DESTRUCTURE_TARGET;
        }
        return AccessKind.READ;
    }
    if isinstance(parent, DeleteStmt) {
        return AccessKind.DELETE_TARGET;
    }
    if isinstance(parent, ReturnStmt) {
        return AccessKind.RETURN_VALUE;
    }
    if isinstance(parent, KWPair) or isinstance(parent, FuncCall) {
        return AccessKind.CALL_ARG;
    }
    return AccessKind.READ;
}

impl OwnershipCheckPass._is_write_target(nd: Name) -> bool {
    kind = self._classify_access(nd);
    return kind == AccessKind.ASSIGN_TARGET or kind == AccessKind.DESTRUCTURE_TARGET;
}

impl OwnershipCheckPass._is_read_name(nd: Name) -> bool {
    return not self._is_write_target(nd);
}

impl OwnershipCheckPass._stamp_overwrite_consumed -> None {
    for nd in self.idx_assignments {
        nd.na_overwrite_consumed = False;
        if nd.aug_op is not None or len(nd.target) != 1 {
            continue;
        }
        _tgt = nd.target[0];
        owned = self._owned_sym_of(_tgt);
        if owned is None {
            continue;
        }
        _cfg = self._cfg_owner(nd);
        if _cfg is None {
            continue;
        }
        if owned in self._call_move_gen(_cfg) {
            nd.na_overwrite_consumed = True;
        }
    }
}

impl OwnershipCheckPass._owned_field_of(expr: Expr | None) -> (Name | None) {
    if not (
        isinstance(expr, AtomTrailer) and expr.is_attr and isinstance(expr.right, Name)
    ) {
        return None;
    }
    fsym = expr.right.sym;
    if fsym is None or not fsym.defn {
        return None;
    }
    hv = fsym.defn[0].find_parent_of_type(HasVar);
    if hv is None or hv.type_tag is None {
        return None;
    }
    if self._nogc_tag_shape(hv.type_tag) != "heap" {
        return None;
    }
    if self._expr_scalar_typed(expr) or self._nogc_str_elem_ok(expr) {
        return None;
    }
    if self._own_field_target(expr) or self.nogc_prov is not None {
        return expr.right;
    }
    return None;
}

impl OwnershipCheckPass._place_text(expr: Expr) -> str {
    base = self._place_of(expr);
    field = (
        expr.right.sym_name
            if isinstance(expr, AtomTrailer) and isinstance(expr.right, Name)
            else ""
    );
    if base is None {
        return field;
    }
    return f"{base.sym_name}.{field}" if field else base.sym_name;
}

impl OwnershipCheckPass._owned_index_of(expr: Expr | None) -> (Name | None) {
    if not (isinstance(expr, AtomTrailer) and isinstance(expr.right, IndexSlice)) {
        return None;
    }
    if expr.right.is_range {
        return None;
    }
    base = self._place_of(expr);
    if base is None or base.sym is None {
        return None;
    }
    if not self._nogc_is_container_expr(expr.target) {
        return None;
    }
    if self._expr_scalar_typed(expr) or self._nogc_str_elem_ok(expr, idx_ctx=True) {
        return None;
    }
    if not self._nogc_expr_type_is_heap(expr) {
        return None;
    }
    if base.sym.ownership == OwnershipKind.OWN or self.nogc_prov is not None {
        return base;
    }
    return None;
}

impl OwnershipCheckPass._emit_place_move(expr: Expr) -> None {
    field = self._owned_field_of(expr);
    if field is not None {
        self.emit(
            E1316, node_override=expr, name=field.sym_name, place=self._place_text(expr)
        );
        return;
    }
    base = self._owned_index_of(expr);
    if base is not None {
        self.emit(
            E1317, node_override=expr, name=base.sym_name, place=f"{base.sym_name}[...]"
        );
    }
}

impl OwnershipCheckPass._callee_own_param_names(call: FuncCall) -> (set[str] | None) {
    tgt = call.target;
    sym = tgt.sym
        if isinstance(tgt, (Name, AtomTrailer)) and hasattr(tgt, "sym")
        else None;
    decl = sym.decl if sym is not None else None;
    ability = decl.find_parent_of_type(Ability) if decl is not None else None;
    if ability is None or not isinstance(ability.signature, FuncSignature) {
        return None;
    }
    out: set[str] = set();
    for (i, p) in enumerate(ability.signature.get_parameters()) {
        if p.type_tag is not None and p.type_tag.ownership == OwnershipKind.OWN {
            out.add(f"#{i}");
            if p.name is not None {
                out.add(p.name.sym_name);
            }
        }
    }
    return out;
}

impl OwnershipCheckPass._emit_place_move_diagnostics -> None {
    for nd in self.idx_assignments {
        if nd.aug_op is not None or len(nd.target) != 1 or nd.value is None {
            continue;
        }
        tgt = nd.target[0];
        dest_owning = self._is_own_decl(nd) is not None
            or (isinstance(tgt, AtomTrailer) and self._owned_field_of(tgt) is not None);
        if dest_owning {
            self._emit_place_move(nd.value);
        }
    }
    for call in self.ir_in.get_all_sub_nodes(FuncCall) {
        is_ctor = self._seal_arch_ctor(call) or self._nogc_fresh_arch_elem(call);
        own_params = None if is_ctor else self._callee_own_param_names(call);
        if not is_ctor and not own_params {
            continue;
        }
        for (i, param) in enumerate(self._call_params(call)) {
            arg = param.value if isinstance(param, KWPair) else param;
            if is_ctor {
                self._emit_place_move(arg);
                continue;
            }
            key = param.key.sym_name
                if isinstance(param, KWPair) and param.key is not None
                else f"#{i}";
            if key in own_params {
                self._emit_place_move(arg);
            }
        }
    }
    for ret in self.idx_returns {
        fn = ret.find_parent_of_type(Ability);
        if fn is None
            or not isinstance(fn.signature, FuncSignature)
            or ret.expr is None {
            continue;
        }
        rtype = fn.signature.return_type;
        if rtype is None {
            continue;
        }
        if isinstance(rtype, UnaryExpr)
            and (
                is_borrow_kind(rtype.ownership) or rtype.ownership == OwnershipKind.IMM
            ) {
            continue;
        }
        self._emit_place_move(ret.expr);
    }
}

impl OwnershipCheckPass._stamp_move_sites -> None {
    sites: set[int] = set();
    for nm in self.idx_names {
        if self._owned_sym_of(nm) is None {
            continue;
        }
        if not self._is_move_producing_use(nm)
            and not self._is_consuming_receiver(nm) {
            continue;
        }
        _cfg = self._cfg_owner(nm);
        if _cfg is not None and self._name_sym_id(nm) in self._consumed_gen_at(_cfg) {
            sites.add(id(nm));
        }
    }
    self.ir_in.own_move_sites = sites;
}

impl OwnershipCheckPass._is_consuming_receiver(nd: Name) -> bool {
    trailer = nd.parent;
    if not (
        isinstance(trailer, AtomTrailer) and trailer.target is nd and trailer.is_attr
    ) {
        return False;
    }
    call = trailer.parent;
    if not (isinstance(call, FuncCall) and call.target is trailer) {
        return False;
    }
    return self._method_call_mode(call) == OwnershipKind.OWN;
}

impl OwnershipCheckPass._method_call_receiver(call: FuncCall) -> (Name | None) {
    trailer = call.target;
    if not (isinstance(trailer, AtomTrailer) and trailer.is_attr) {
        return None;
    }
    return self._place_of(trailer.target);
}

impl OwnershipCheckPass._method_call_mode(call: FuncCall) -> OwnershipKind {
    trailer = call.target;
    if not (isinstance(trailer, AtomTrailer) and trailer.is_attr) {
        return OwnershipKind.NONE;
    }
    callee = call.callee_decl;
    if callee is None or not callee.is_method {
        if isinstance(trailer.right, Name)
            and trailer.right.sym_name in _MUTATING_CONTAINER_METHODS
            and self._nogc_is_container_expr(trailer.target) {
            return OwnershipKind.MUT_BORROW;
        }
        return OwnershipKind.NONE;
    }
    return self._receiver_mode(callee);
}

impl OwnershipCheckPass._is_builtin_mutator(ability: Ability | None) -> bool {
    if ability is None {
        return False;
    }
    _nm = ability.name_ref;
    _mname = _nm.sym_name if isinstance(_nm, Name) else "";
    if _mname not in _MUTATING_CONTAINER_METHODS {
        return False;
    }
    _arch = ability.find_parent_of_type(Archetype);
    return _arch is not None
        and _arch.name.value
            in (
                "list",
                "dict",
                "set",
                "MutableSequence",
                "MutableMapping",
                "MutableSet"
            );
}

impl OwnershipCheckPass._explicit_receiver_mode(
    ability: Ability
) -> (OwnershipKind | None) {
    sig = ability.signature;
    if not isinstance(sig, FuncSignature) {
        return None;
    }
    for p in sig.get_parameters() {
        if p.name is None or p.name.sym_name != "self" {
            continue;
        }
        if p.type_tag is None or p.type_tag.ownership == OwnershipKind.NONE {
            return None;
        }
        kind = p.type_tag.ownership;
        if kind == OwnershipKind.IMM {
            return OwnershipKind.BORROW;
        }
        return kind;
    }
    return None;
}

impl OwnershipCheckPass._method_writes_self(ability: Ability) -> bool {
    for asgn in ability.get_all_sub_nodes(Assignment) {
        for tgt in asgn.target {
            base = self._place_of(tgt);
            if isinstance(tgt, AtomTrailer)
                and base is not None
                and base.sym_name == "self" {
                return True;
            }
        }
    }
    for call in ability.get_all_sub_nodes(FuncCall) {
        if call.call_kind == "builtin"
            and isinstance(call.target, Name)
            and call.target.sym_name == "take" {
            for param in self._call_params(call) {
                if isinstance(param, Expr) {
                    base = self._place_of(param);
                    if base is not None and base.sym_name == "self" {
                        return True;
                    }
                }
            }
        }
        trailer = call.target;
        if not (isinstance(trailer, AtomTrailer) and trailer.is_attr) {
            continue;
        }
        base = self._place_of(trailer.target);
        if base is None or base.sym_name != "self" or trailer.target is base {
            continue;
        }
        if isinstance(trailer.right, Name)
            and trailer.right.sym_name in _MUTATING_CONTAINER_METHODS {
            return True;
        }
    }
    for un in ability.get_all_sub_nodes(UnaryExpr) {
        if is_mut_kind(un.ownership) {
            base = self._place_of(un.operand);
            if base is not None and base.sym_name == "self" {
                return True;
            }
        }
    }
    return False;
}

impl OwnershipCheckPass._trailer_writes_root(top: UniNode) -> bool {
    _p = top.parent;
    if isinstance(_p, Assignment) {
        for _t in _p.target {
            if _t is top {
                return True;
            }
        }
        return False;
    }
    if isinstance(_p, UnaryExpr) and is_mut_kind(_p.ownership) and _p.operand is top {
        return True;
    }
    if isinstance(_p, FuncCall) and _p.target is top and isinstance(top, AtomTrailer) {
        if isinstance(top.right, Name)
            and top.right.sym_name in _MUTATING_CONTAINER_METHODS {
            return True;
        }
        return self._receiver_mode(self._callee_ability(_p))
            == OwnershipKind.MUT_BORROW;
    }
    return False;
}

impl OwnershipCheckPass._name_written_through(nm: Name) -> bool {
    _sid = self._name_sym_id(nm);
    for _u in self.name_uses_by_sym.get(_sid, []) {
        if _u is nm {
            continue;
        }
        _top: UniNode = _u;
        while isinstance(_top.parent, AtomTrailer) and _top.parent.target is _top {
            _top = _top.parent;
        }
        if self._trailer_writes_root(_top) {
            return True;
        }
    }
    return False;
}

impl OwnershipCheckPass._self_method_callees(ability: Ability) -> list[Ability] {
    out: list[Ability] = [];
    for call in ability.get_all_sub_nodes(FuncCall) {
        trailer = call.target;
        if not (isinstance(trailer, AtomTrailer) and trailer.is_attr) {
            continue;
        }
        recv_root = self._place_of(trailer.target);
        if recv_root is None or recv_root.sym_name != "self" {
            continue;
        }
        callee = call.callee_decl;
        if callee is not None and callee.is_method {
            out.append(callee);
        }
    }
    return out;
}

impl OwnershipCheckPass._receiver_mode(ability: Ability | None) -> OwnershipKind {
    if ability is None or not ability.is_method or ability.is_static {
        return OwnershipKind.NONE;
    }
    key = id(ability);
    if key in self.receiver_modes {
        return self.receiver_modes[key];
    }
    explicit = self._explicit_receiver_mode(ability);
    if explicit is not None {
        self.receiver_modes[key] = explicit;
        return explicit;
    }
    if ability.find_parent_of_type(Module) is not self.ir_in {
        mode = ability.receiver_mode;
        if mode == OwnershipKind.NONE {
            mode = OwnershipKind.MUT_BORROW
                if self._is_builtin_mutator(ability)
                else OwnershipKind.BORROW;
        }
        self.receiver_modes[key] = mode;
        return mode;
    }
    if key in self.receiver_probe {
        return OwnershipKind.BORROW;
    }
    self.receiver_probe.add(key);
    mode = OwnershipKind.BORROW;
    if self._method_writes_self(ability) {
        mode = OwnershipKind.MUT_BORROW;
    } else {
        for callee in self._self_method_callees(ability) {
            if self._receiver_mode(callee) == OwnershipKind.MUT_BORROW {
                mode = OwnershipKind.MUT_BORROW;
                break;
            }
        }
    }
    self.receiver_probe.discard(key);
    self.receiver_modes[key] = mode;
    return mode;
}

impl OwnershipCheckPass._stamp_receiver_modes -> None {
    changed = True;
    methods = [
        a
        for a in self.ir_in.get_all_sub_nodes(Ability)
        if a.is_method
    ];
    while changed {
        changed = False;
        for m in methods {
            before = self.receiver_modes.get(id(m));
            self.receiver_modes.pop(id(m), None);
            mode = self._receiver_mode(m);
            self.receiver_modes[id(m)] = mode;
            if before != mode {
                changed = True;
            }
        }
    }
    for m in methods {
        m.receiver_mode = self.receiver_modes.get(id(m), OwnershipKind.NONE);
    }
}

impl OwnershipCheckPass._emit_receiver_diagnostics -> None {
    for call in self.ir_in.get_all_sub_nodes(FuncCall) {
        if call.call_kind == "builtin"
            and isinstance(call.target, Name)
            and call.target.sym_name in ("take", "swap") {
            for param in self._call_params(call) {
                if isinstance(param, Expr) {
                    recv = self._place_of(param);
                    if recv is not None {
                        self._check_mutating_receiver(recv, call, call.target.sym_name);
                    }
                }
            }
            continue;
        }
        if self._method_call_mode(call) != OwnershipKind.MUT_BORROW {
            continue;
        }
        recv = self._method_call_receiver(call);
        trailer = call.target;
        if recv is None or recv.sym is None or not isinstance(trailer, AtomTrailer) {
            continue;
        }
        method = trailer.right.sym_name if isinstance(trailer.right, Name) else "";
        self._check_mutating_receiver(recv, call, method);
    }
}

impl OwnershipCheckPass._check_mutating_receiver(
    recv: Name, call: FuncCall, method: str
) -> None {
    if recv.sym is None {
        return;
    }
    sid = self._name_sym_id(recv);
    if sid in self.imm_decl {
        self._emit_imm_mutation(sid, call, self.imm_decl.get(sid));
        return;
    }
    if sid in self.borrow_meta
        and sid not in self.view_syms
        and not self._borrow_is_mut_of(sid) {
        owner_id = self._borrow_owner_of(sid);
        self.emit(
            E1318,
            node_override=call,
            method=method,
            name=self._owned_name(owner_id, recv.sym_name)
                if owner_id is not None
                else recv.sym_name
        );
        return;
    }
    owner_id = self._target_owner_sym(recv);
    if owner_id is None {
        return;
    }
    cfg = self._cfg_owner(call);
    if cfg is None {
        return;
    }
    for borrow_id in self._active_borrows_at(cfg) {
        if owner_id in self._borrow_owners_of(borrow_id)
            and not self._borrow_is_mut_of(borrow_id) {
            borrow_site = self.borrow_created_at.get(borrow_id);
            borrow_name = self._borrow_display_name(borrow_id, "");
            related = [(f"shared borrow of '{borrow_name}' created here", borrow_site)]
                if borrow_site is not None
                else None;
            self.emit(
                E1303,
                node_override=call,
                name=self._owned_name(owner_id, ""),
                related=related
            );
            break;
        }
    }
}

impl OwnershipCheckPass._is_move_producing_use(nd: Name) -> bool {
    kind = self._classify_access(nd);
    if kind == AccessKind.CALL_ARG {
        _call = nd.find_parent_of_type(FuncCall);
        return (
            _call is None
            or self._call_consumes_args(_call)
            or self._grow_arg_moves(_call, nd)
        );
    }
    if kind == AccessKind.RETURN_VALUE {
        return True;
    }
    parent = nd.parent;
    if isinstance(parent, Assignment)
        and parent.aug_op is None
        and parent.value is nd {
        return True;
    }
    return False;
}

impl OwnershipCheckPass._sym_id(nd: UniNode | None) -> (SymId | None) {
    if isinstance(nd, Name) and nd.sym {
        return id(nd.sym);
    }
    return None;
}

impl OwnershipCheckPass._name_sym_id(nd: Name) -> SymId {
    return id(nd.sym);
}

impl OwnershipCheckPass._owned_sym_of(nd: UniNode | None) -> (SymId | None) {
    sid = self._sym_id(nd);
    if sid is not None and sid in self.owned_decl {
        return sid;
    }
    return None;
}

impl OwnershipCheckPass._owned_sym_of_expr(nd: Expr | None) -> (SymId | None) {
    if isinstance(nd, AtomTrailer)
        and isinstance(nd.right, IndexSlice)
        and self._nogc_type_is_str(nd) {
        return None;
    }
    cur = nd;
    while isinstance(cur, AtomTrailer) {
        cur = cur.target;
    }
    return self._owned_sym_of(cur);
}

impl OwnershipCheckPass._borrow_sym_of(nd: UniNode | None) -> (SymId | None) {
    sid = self._sym_id(nd);
    if sid is not None and sid in self.borrow_meta {
        return sid;
    }
    return None;
}

impl OwnershipCheckPass._owned_name(sym_id: SymId, fallback: str) -> str {
    decl = self.owned_decl.get(sym_id);
    if decl is not None {
        return decl.sym_name;
    }
    return fallback;
}

impl OwnershipCheckPass._borrow_owners_of(borrow_id: SymId) -> list[SymId] {
    meta = self.borrow_meta.get(borrow_id);
    if meta is None {
        return [];
    }
    out: list[SymId] = [];
    if meta.owner is not None {
        out.append(meta.owner);
    }
    for extra in meta.extra_owners {
        if extra not in out {
            out.append(extra);
        }
    }
    return out;
}

impl OwnershipCheckPass._borrow_owner_of(borrow_id: SymId) -> (SymId | None) {
    meta = self.borrow_meta.get(borrow_id);
    if meta is not None {
        return meta.owner;
    }
    return None;
}

impl OwnershipCheckPass._borrow_is_mut_of(borrow_id: SymId) -> bool {
    meta = self.borrow_meta.get(borrow_id);
    if meta is not None {
        return meta.is_mut;
    }
    return False;
}

impl OwnershipCheckPass._borrow_field_of(borrow_id: SymId) -> str {
    meta = self.borrow_meta.get(borrow_id);
    if meta is not None {
        return meta.field;
    }
    return "";
}

impl OwnershipCheckPass._single_field_of(nd: Expr | None) -> str {
    if isinstance(nd, AtomTrailer)
        and nd.is_attr
        and isinstance(nd.target, Name)
        and isinstance(nd.right, Name) {
        return nd.right.sym_name;
    }
    return "";
}

impl OwnershipCheckPass._fields_overlap(a: str, b: str) -> bool {
    return a == "" or b == "" or a == b;
}

impl OwnershipCheckPass._borrow_display_name(borrow_id: SymId, fallback: str) -> str {
    meta = self.borrow_meta.get(borrow_id);
    if meta is not None {
        return meta.name;
    }
    return fallback;
}

impl OwnershipCheckPass._target_owner_sym(nd: Expr) -> (SymId | None) {
    direct = self._owned_sym_of(nd);
    if direct is not None {
        return direct;
    }
    if isinstance(nd, AtomTrailer) and nd.is_attr {
        return self._owned_sym_of(nd.target);
    }
    return None;
}

impl OwnershipCheckPass._emit_diagnostics -> None {
    for nd in self.idx_names {
        if self._owned_sym_of(nd) is None {
            continue;
        }
        if self._is_write_target(nd) {
            continue;
        }
        owner = nd.find_parent_of_type(UniCFGNode);
        if owner is None {
            continue;
        }
        consumed = self.in_consumed.get(id(owner), set());
        sid = self._name_sym_id(nd);
        if sid in consumed {
            sym_name = self._owned_name(sid, nd.sym_name);
            move_site = self.consumed_at.get(sid);
            move_related = [(f"'{sym_name}' was moved here", move_site)]
                if move_site is not None
                else None;
            self.emit(E1301, node_override=nd, name=sym_name, related=move_related);
        } else {
            earlier = self._earlier_move_in_node(nd, sid);
            if earlier is not None {
                sym_name = self._owned_name(sid, nd.sym_name);
                self.emit(
                    E1301,
                    node_override=nd,
                    name=sym_name,
                    related=[(f"'{sym_name}' was moved here", earlier)]
                );
            }
        }
    }
}

impl OwnershipCheckPass._earlier_move_in_node(nd: Name, sid: SymId) -> (Name | None) {
    cfg = nd.find_parent_of_type(UniCFGNode);
    if cfg is None {
        return None;
    }
    my_pos = nd.loc.pos_start;
    best: Name | None = None;
    best_pos = -1;
    for other in self.name_uses_by_sym.get(sid, []) {
        if other is nd or other.loc.pos_start >= my_pos {
            continue;
        }
        if other.find_parent_of_type(UniCFGNode) is not cfg {
            continue;
        }
        if self._is_move_producing_use(other) and other.loc.pos_start > best_pos {
            best = other;
            best_pos = other.loc.pos_start;
        }
    }
    return best;
}

impl OwnershipCheckPass._active_borrows_at(cfg: UniCFGNode) -> set[SymId] {
    return self.in_live_borrows.get(id(cfg), set()).intersection(
        self.in_reaching_borrows.get(id(cfg), set())
    );
}

impl OwnershipCheckPass._consumed_gen_at(nd: UniCFGNode) -> set[SymId] {
    gen: set[SymId] = set();
    if isinstance(nd, Assignment) {
        (_kill, g) = self._assign_kill_gen(nd);
        for x in g {
            gen.add(x);
        }
    }
    for x in self._call_move_gen(nd) {
        gen.add(x);
    }
    for x in self._return_move_gen(nd) {
        gen.add(x);
    }
    return gen;
}

impl OwnershipCheckPass._emit_move_while_borrowed(cfg_nodes: list[UniCFGNode]) -> None {
    for n in cfg_nodes {
        active = self._active_borrows_at(n);
        if not active {
            continue;
        }
        `entry = self.in_consumed.get(id(n), set());
        for owner_id in self._consumed_gen_at(n) {
            if owner_id in `entry {
                continue;
            }
            for borrow_id in active {
                if owner_id in self._borrow_owners_of(borrow_id)
                    and borrow_id not in self.e1304_borrow_ids {
                    borrow_site = self.borrow_created_at.get(borrow_id);
                    borrow_name = self._borrow_display_name(borrow_id, "");
                    e1304_related = [
                        (f"borrow of '{borrow_name}' created here", borrow_site)
                    ]
                        if borrow_site is not None
                        else None;
                    self.emit(
                        E1304,
                        node_override=n,
                        name=self._owned_name(owner_id, ""),
                        related=e1304_related
                    );
                    self.e1304_borrow_ids.add(borrow_id);
                }
            }
        }
    }
}

impl OwnershipCheckPass._emit_borrow_diagnostics -> None {
    emitted_e1304: set[SymId] = set();
    for nd in self.idx_assignments {
        owner = self._borrow_source_owner(nd);
        target = self._borrow_target(nd);

        cfg = nd;
        if owner is not None and target is not None {
            borrow_id = self._name_sym_id(target);
            owner_id = self._name_sym_id(owner);
            active = self._active_borrows_at(cfg);
            for other in active {
                if self._borrow_owner_of(other) != owner_id {
                    continue;
                }
                if not self._fields_overlap(
                    self._borrow_field_of(borrow_id), self._borrow_field_of(other)
                ) {
                    continue;
                }
                if nd.value
                    and isinstance(nd.value, UnaryExpr)
                    and (
                        is_mut_kind(nd.value.ownership) or self._borrow_is_mut_of(other)
                    ) {
                    other_site = self.borrow_created_at.get(other);
                    other_name = self._borrow_display_name(other, "");
                    e1302_related = [
                        (f"existing borrow of '{other_name}' created here", other_site)
                    ]
                        if other_site is not None
                        else None;
                    self.emit(
                        E1302,
                        node_override=owner,
                        name=self._owned_name(owner_id, owner.sym_name),
                        related=e1302_related
                    );
                    break;
                }
            }
            owner_scope = self.owned_decl.get(owner_id, owner).find_parent_of_type(
                UniScopeNode
            );
            if owner_scope is not None and borrow_id not in emitted_e1304 {
                borrow_site = self.borrow_created_at.get(borrow_id);
                borrow_name = self._borrow_display_name(borrow_id, "");
                for use in self.name_uses_by_sym.get(borrow_id, []) {
                    if self._is_read_name(use)
                        and not self._is_ancestor(owner_scope, use) {
                        e1304_related = [
                            (f"borrow of '{borrow_name}' created here", borrow_site)
                        ]
                            if borrow_site is not None
                            else None;
                        self.emit(
                            E1304,
                            node_override=owner,
                            name=self._owned_name(owner_id, owner.sym_name),
                            related=e1304_related
                        );
                        emitted_e1304.add(borrow_id);
                        self.e1304_borrow_ids.add(borrow_id);
                        break;
                    }
                }
            }
        }
        for tgt in nd.target {
            tgt_owner_id = self._target_owner_sym(tgt);
            if tgt_owner_id is None {
                continue;
            }
            active = self._active_borrows_at(cfg);
            for borrow_id in active {
                if (
                    tgt_owner_id in self._borrow_owners_of(borrow_id)
                    and not self._borrow_is_mut_of(borrow_id)
                    and self._fields_overlap(
                        self._borrow_field_of(borrow_id), self._single_field_of(tgt)
                    )
                ) {
                    borrow_site = self.borrow_created_at.get(borrow_id);
                    borrow_name = self._borrow_display_name(borrow_id, "");
                    e1303_related = [
                        (f"shared borrow of '{borrow_name}' created here", borrow_site)
                    ]
                        if borrow_site is not None
                        else None;
                    self.emit(
                        E1303,
                        node_override=tgt,
                        name=self._owned_name(tgt_owner_id, ""),
                        related=e1303_related
                    );
                    break;
                }
            }
        }
    }
}

impl OwnershipCheckPass._escaping_borrow_owner(nd: Expr | None) -> (str | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, UnaryExpr) and nd.op.name == Tok.BW_AND {
        operand = nd.operand;
        place = self._place_of(operand);
        if isinstance(place, Name) and place.sym {
            if is_borrow_kind(nd.ownership) or self._sym_id(place) in self.owned_decl {
                return place.sym_name;
            }
        }
        return None;
    }
    borrow_id = self._borrow_sym_of(nd);
    if borrow_id is not None and isinstance(nd, Name) {
        owner_id = self._borrow_owner_of(borrow_id);
        if owner_id is not None {
            return self._owned_name(owner_id, nd.sym_name);
        }
        return self._borrow_display_name(borrow_id, nd.sym_name);
    }
    return None;
}

impl OwnershipCheckPass._owner_decl_related(
    borrow_id: (SymId | None), owner_name: str
) -> (list[tuple[str, UniNode]] | None) {
    if borrow_id is not None {
        owner_id = self._borrow_owner_of(borrow_id);
        if owner_id is not None {
            owner_decl = self.owned_decl.get(owner_id);
            if owner_decl is not None {
                return [(f"owner '{owner_name}' declared here", owner_decl)];
            }
        }
    }
    return None;
}

impl OwnershipCheckPass._emit_escape_diagnostics -> None {
    for ret in self.idx_returns {
        owner = self._escaping_borrow_owner(ret.expr);
        if owner is not None and not self._return_roots_at_param_borrow(ret.expr) {
            borrow_id = self._borrow_sym_of(ret.expr);
            e1306_related = self._owner_decl_related(borrow_id, owner);
            self.emit(E1306, node_override=ret.expr, name=owner, related=e1306_related);
        }
    }

    for nd in self.idx_assignments {
        if nd.aug_op is not None {
            continue;
        }
        stores_to_managed = False;
        for tgt in nd.target {
            if isinstance(tgt, AtomTrailer) {
                stores_to_managed = True;
            }
        }
        if stores_to_managed {
            owner = self._escaping_borrow_owner(nd.value);
            if owner is not None {
                borrow_id = self._borrow_sym_of(nd.value);
                e1306_related = self._owner_decl_related(borrow_id, owner);
                self.emit(
                    E1306, node_override=nd.value, name=owner, related=e1306_related
                );
            }
            continue;
        }

        for tgt in nd.target {
            if not (isinstance(tgt, Name) and tgt.sym) {
                continue;
            }
            borrow = self._borrow_sym_of(tgt);
            if borrow is None or borrow in self.e1304_borrow_ids {
                continue;
            }
            source_owner = self._borrow_source_owner(nd);
            if source_owner is None or source_owner.sym is None {
                continue;
            }
            region = source_owner.sym.decl.find_parent_of_type(UniScopeNode);
            dest = tgt.sym.decl.find_parent_of_type(UniScopeNode);
            if self._region_strictly_outlives(dest, region) {
                owner_id = self._name_sym_id(source_owner);
                owner_name = self._owned_name(owner_id, tgt.sym_name);
                owner_decl = self.owned_decl.get(owner_id);
                e1306_related = [(f"owner '{owner_name}' declared here", owner_decl)]
                    if owner_decl is not None
                    else None;
                self.emit(
                    E1306,
                    node_override=nd.value,
                    name=owner_name,
                    related=e1306_related
                );
            }
        }
    }
}

impl OwnershipCheckPass.transform(ir_in: Module) -> Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, Module);
    return out;
}

impl OwnershipCheckPass.run_walk with Module entry {
    self.ir_out = self._run_impl(here);
}
