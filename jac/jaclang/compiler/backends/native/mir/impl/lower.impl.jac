impl MirLowering.lower -> MirModule {
    self.declaration_types();
    self.adopt_imported_layouts();
    for ab in self.module_abilities() {
        try {
            self.declare(ab);
        } except MirRefused as err {
            name = self.name_of(ab);
            self.refusals.setdefault(name, []).append(refusal_of(err));
        }
    }
    for elem in self.module.body {
        if isinstance(elem, uni.Enum) {
            try {
                enum_type = self.enum_self_type(elem);
                if enum_type is not None {
                    self.declare_enum_methods(elem, enum_type);
                }
            } except MirRefused as err {
                self.refusals.setdefault(elem.name.value, []).append(refusal_of(err));
            }
        }
    }
    archetypes = self.module_archetypes();
    for arch in archetypes {
        try {
            self.declare_archetype(arch);
        } except MirRefused as err {
            self.refusals.setdefault(arch.name.value, []).append(refusal_of(err));
        }
    }
    self.declare_c_data();
    self.declare_clib_externs();
    self.declare_module_globals();
    self.declare_class_globals();
    for key in self.order {
        self.current = self.decl_label(self.decls[key]);
        made = self.lower_function(self.decls[key]);
        if made is not None {
            self.mir.functions.append(made);
        }
    }
    self.mir.functions.extend(self.function_default_thunks());
    for nd in self.module.body {
        if isinstance(nd, uni.Test) {
            self.current = nd.name.sym_name;
            tested = self.lower_test(nd);
            if tested is not None {
                self.mir.functions.append(tested);
            }
        }
    }
    for arch in archetypes {
        if archetype_native_name(arch) not in self.mir.objects {
            continue;
        }
        self.current = arch.name.value;
        self.mir.functions.extend(self.default_thunks(arch));
        made = self.lower_constructor(arch);
        if made is not None {
            self.mir.functions.append(made);
            for bound in self.lineage(arch) {
                adapter = self.class_entry(arch, bound);
                if adapter is not None {
                    self.mir.functions.append(adapter);
                }
            }
        }
        obj_def = self.object_def(arch);
        self.mir.functions.append(self.lower_drop(obj_def, arch));
        self.mir.functions.append(self.lower_trace(obj_def));
        layout = self.osp_layout(arch);
        if layout is not None and layout.arch_type == "edge" {
            fresh = self.default_entry(arch);
            if fresh is not None {
                self.mir.functions.append(fresh);
            }
        }
        thunk = self.lower_text_thunk(obj_def, arch);
        if thunk is not None {
            self.mir.functions.append(thunk);
            self.text_pairs.append((obj_def.drop_symbol, thunk.symbol));
        }
    }
    self.current = "with entry";
    self.lower_osp_module();
    self.mir.functions.extend(self.nested);
    self.nested = [];
    module_entry = self.lower_module_entry();
    for extra in (self.lower_module_init(), module_entry) {
        if extra is not None {
            self.mir.functions.append(extra);
        }
    }
    self.mir.functions.extend(self.nested);
    self.nested = [];
    self.lower_instances();
    self.record_defaults();
    self.settle();
    self.c_global_settle();
    return self.mir;
}

impl MirLowering.declaration_types {
    here = os.path.realpath(self.module.loc.mod_path);
    import from jaclang.compiler.driver.pipeline { require }
    import from jaclang.compiler.driver.pipeline_types {
        AnalysisFact,
        CompilationProduct
    }
    import from jaclang.compiler.passes.declaration_type_pass { importer_lowers_bodies }
    hub = self.prog.mod.hub;
    analysis = self.prog.analysis;
    seen: set[str] = {here};
    for imp in self.module.get_all_sub_nodes(uni.Import) {
        if imp.is_comptime or imp.clib_decls {
            continue;
        }
        paths: list[str] = [];
        if isinstance(imp.from_loc, uni.ModulePath) {
            paths.append(imp.from_loc.resolve_relative_path());
        } else {
            for item in imp.items {
                if isinstance(item, uni.ModulePath) {
                    paths.append(item.resolve_relative_path());
                }
            }
        }
        for path in paths {
            real = os.path.realpath(path) if path else "";
            if not real.endswith(".jac") or real in seen {
                continue;
            }
            seen.add(real);
            dep = hub.get(real) or hub.get(path);
            if dep is None
                or analysis.provides(dep, AnalysisFact.TYPE_OF)
                or analysis.provides(dep, AnalysisFact.DECL_TYPES) {
                continue;
            }
            require(
                self.prog,
                dep,
                CompilationProduct.ANALYSIS
                    if importer_lowers_bodies(dep)
                    else CompilationProduct.DECLARATIONS
            );
        }
    }
}

impl MirLowering.record_defaults {
    for decl in self.decls.values() {
        sig = decl.ability.signature;
        if decl.event
            or not isinstance(sig, uni.FuncSignature)
            or decl.ability.find_parent_of_type(uni.Module) is not self.module {
            continue;
        }
        self.mir.defaults[decl.symbol] = [
            " ".join(
                f"{tok.name}={tok.value}"
                for tok in pv.value.flatten()
                if isinstance(tok, uni.Token)
            )
                if pv.value is not None
                else "" for pv in sig.get_parameters()
        ];
    }
}

impl MirLowering.callees_of(fn: MirFunction) -> list[str] {
    found: list[str] = [];
    for blk in fn.blocks {
        for instr in blk.instrs {
            if instr.op in (MirOp.CALL, MirOp.FN_ADDR) and instr.callee {
                found.append(instr.callee);
            } elif instr.op == MirOp.CALL_FNPTR and instr.str_value {
                slot = instr.str_value.rsplit(".", 1)[-1];
                found.append(instr.str_value);
                for obj_def in self.mir.objects.values() {
                    for method in obj_def.vtable_methods {
                        if method.rsplit(".", 1)[-1] == slot {
                            found.append(method);
                        }
                    }
                }
            }
        }
    }
    return found;
}

impl MirLowering.settle {
    split = self.module.decided_codespace != "native"
        and not self.prog.options.native_required_for(self.module.loc.mod_path)
        and any(
            isinstance(elem, uni.ContextAwareNode)
                and elem.code_context == CodeContext.NATIVE for elem in self.module.body
        );
    for decl in list(self.decls.values()) if split else [] {
        if decl.owner is None
            and decl.symbol not in self.mir.demoted
            and decl.ability.find_parent_of_type(uni.Module) is self.module
            and isinstance(decl.ability, uni.ContextAwareNode)
            and decl.ability.code_context == CodeContext.SERVER {
            self.mir.demoted[decl.symbol] = "placed on the server";
            self.bridge_symbol(decl.symbol);
        }
    }
    symbols: dict[str, str] = {};
    for decl in self.decls.values() {
        symbols[self.refusal_key(decl)] = decl.symbol;
    }
    for (name, reasons) in self.refusals.items() {
        symbol = symbols.get(name, name);
        first = reasons[0];
        self.mir.demoted[symbol] = f"{first.kind} '{first.name}'";
        self.bridge_symbol(symbol);
    }
    changed = True;
    while changed {
        changed = False;
        for fn in list(self.mir.functions) {
            if fn.symbol in self.mir.demoted {
                continue;
            }
            for callee in self.callees_of(fn) {
                if callee in self.text_regs {
                    continue;
                }
                if callee in self.mir.demoted and callee not in self.mir.bridged {
                    self.mir.demoted[fn.symbol] = f"calls {callee}, which is not native";
                    self.bridge_symbol(fn.symbol);
                    changed = True;
                    break;
                }
            }
        }
    }
    dropped: set[str] = set();
    for (thunk, (block, instrs)) in self.text_regs.items() {
        if thunk in self.mir.demoted {
            self.mir.demoted.pop(thunk);
            dropped.add(thunk);
            gone = {id(instr) for instr in instrs};
            block.instrs = [
                instr
                for instr in block.instrs
                if id(instr) not in gone
            ];
        }
    }
    self.mir.functions = [
        fn
        for fn in self.mir.functions
        if (fn.symbol not in self.mir.demoted or fn.symbol in self.mir.bridged)
            and fn.symbol not in dropped
    ];
}

impl MirLowering.module_abilities -> list[uni.Ability] {
    found: list[uni.Ability] = [];
    for elem in self.module.body {
        if isinstance(elem, uni.Ability)
            and isinstance(elem.signature, uni.FuncSignature)
            and not elem.is_comptime {
            found.append(elem);
        } elif isinstance(elem, uni.Import) and elem.clib_decls {
            for decl in elem.clib_decls {
                if isinstance(decl, uni.Ability) and self.c_defines(decl) {
                    found.append(decl);
                }
            }
        }
    }
    return found;
}

impl MirLowering.declare(ab: uni.Ability) {
    sig = ab.signature;
    if not isinstance(sig, uni.FuncSignature) {
        raise MirRefused(mir_refusal("function", "event ability", ab));
    }
    if self.is_template(ab) {
        self.templates[id(ab)] = ab;
        return;
    }
    if clib_import_of(ab) is not None {
        self.declare_c_definition(ab);
        return;
    }
    params: list[MirType] = [];
    packed = sig.varargs is not None
        and is_va_list_type(sig.varargs.type)
        and sig.kwargs is None
        and not sig.kwonlyargs;
    for pv in self.param_nodes(sig, False) {
        if packed and pv is sig.varargs {
            continue;
        }
        params.append(self.symbol_type(pv.name.sym, pv));
    }
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(self.ability_sym(ab));
    ret = mir_none();
    if isinstance(fn_type, FunctionType) {
        ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, ab);
    }
    key = id(ab);
    self.decl_syms[id(self.ability_sym(ab))] = key;
    self.decls[key] = MirDecl(
        ability=ab, symbol=self.symbol_of(ab), params=params, ret=ret, c_variadic=packed
    );
    self.order.append(key);
}

impl MirLowering.symbol_of(ab: uni.Ability) -> str {
    return self.unit_symbol(self.name_of(ab), ab.access);
}

impl MirLowering.unit_symbol(
    name: str, access: (uni.SubTag[uni.Token] | None), path: str = ""
) -> str {
    path = path or self.module.loc.mod_path;
    spelled = native_unit_spelling(name, path);
    is_pub = bool(access and access.tag.name == Tok.KW_PUB);
    bundled = native_unit_identity(path).startswith("jaclang/runtime/na_stdlib/");
    if is_pub and not bundled {
        symbol = native_def_symbol(spelled);
        if path == self.module.loc.mod_path and symbol not in self.mir.public {
            self.mir.public.append(symbol);
        }
        return symbol;
    }
    return native_symbol_name(native_unit_prefix(path), spelled);
}

impl MirLowering.lower_function(decl: MirDecl) -> (MirFunction | None) {
    if decl.event {
        return self.lower_ability(decl);
    }
    ab = decl.ability;
    if self.is_generator(ab) {
        return self.lower_generator(decl);
    }
    fn = MirFunction(name=self.decl_label(decl), symbol=decl.symbol, ret=decl.ret);
    if decl.c_symbol {
        fn.c_symbol = decl.c_symbol;
        fn.linkage = "internal";
    }
    first = fn.new_block("entry");
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        sig = ab.signature;
        body = ab.body;
        if isinstance(body, uni.ImplDef) {
            spec = body.spec;
            if isinstance(spec, uni.FuncSignature) {
                sig = spec;
            } elif spec is not None {
                raise MirRefused(mir_refusal("function", "impl signature", ab));
            }
            body = body.body;
        }
        if not isinstance(sig, uni.FuncSignature) and not ab.accessor_kind {
            raise MirRefused(mir_refusal("function", "event ability", ab));
        }
        abstract = ab.is_abstract and not isinstance(body, (list, tuple));
        if abstract {
            body = [];
        }
        if not isinstance(body, (list, tuple)) {
            raise MirRefused(mir_refusal("function", "expression body", ab));
        }
        nodes = self.param_nodes(sig, decl.self_type is not None)
            if isinstance(sig, uni.FuncSignature)
            else [];
        packed: (uni.ParamVar | None) = None;
        if decl.c_variadic {
            packed = nodes[-1];
            nodes = nodes[:-1];
            fn.variadic = True;
        }
        if decl.self_type is not None {
            receiver = fn.new_value(decl.self_type, "self");
            fn.params.append(MirParam(name="self", value=receiver));
            self.st().self_value = receiver;
        }
        if len(nodes) != len(decl.params) {
            raise MirRefused(mir_refusal("function", "impl parameters differ", ab));
        }
        declared = ab.signature;
        twins = self.param_nodes(declared, decl.self_type is not None)
            if isinstance(declared, uni.FuncSignature) and declared is not sig
            else [];
        for (index, (pv, ptype)) in enumerate(zip(nodes, decl.params)) {
            value = fn.new_value(ptype, pv.name.value);
            fn.params.append(MirParam(name=pv.name.value, value=value));
            slot = self.local_slot(pv.name.sym, pv);
            self.builder().store(slot, value);
            if index < len(twins) and twins[index].name.sym is not None {
                self.st().locals[id(twins[index].name.sym)] = slot;
            }
        }
        if packed is not None {
            slot = self.local_slot(packed.name.sym, packed);
            started = self.emit_value(MirOp.VA_START, mir_c_ptr(mir_int(8, False)), []);
            self.builder().store(slot, self.coerce(started, slot.type, packed));
        }
        self.prepare_cells(ab, list(body));
        if clib_import_of(ab) is not None
            and not is_kernel_unit_path(self.module.loc.mod_path) {
            self.region_escape_entry();
        }
        self.lower_body(body);
        if abstract {
            self.builder().raise_builtin(
                "NotImplementedError", f"{self.name_of(ab)} is abstract"
            );
        }
        if not self.builder().block.terminated() {
            if decl.ret.kind == MirKind.NONE {
                self.drop_regions();
                self.builder().ret(None);
            } else {
                self.builder().unreachable();
            }
        }
        for blk in fn.blocks {
            if not blk.terminated() {
                self.builder().position(blk);
                self.builder().unreachable();
            }
        }
    } except MirRefused as err {
        self.refusals.setdefault(self.refusal_key(decl), []).append(refusal_of(err));
        self.state = None;
        return None;
    }
    self.state = None;
    return fn;
}

impl MirLowering.st -> MirFnState {
    if self.state is None {
        raise RuntimeError("MIR lowering has no function in progress");
    }
    return self.state;
}

impl MirLowering.builder -> MirBuilder {
    return self.st().b;
}

impl MirLowering.symbol_type(sym: (uni.Symbol | None), site: uni.UniNode) -> MirType {
    if sym is None {
        raise MirRefused(mir_refusal("name", "unresolved", site));
    }
    found = self.prog.get_type_evaluator().get_type_of_symbol(sym);
    return self.type_of(found, MirPosition.VALUE, site);
}

impl MirLowering.expr_type(nd: uni.Expr) -> MirType {
    return self.type_of(nd.type, MirPosition.VALUE, nd);
}

impl MirLowering.lower_body(stmts: Sequence[uni.UniNode]) {
    for stmt in stmts {
        if self.builder().block.terminated() {
            self.builder().position(self.st().fn.new_block("dead"));
        }
        self.lower_stmt(stmt);
        self.drop_last_uses(stmt);
    }
}

impl MirLowering.drop_consumed_args(nd: uni.FuncCall) {
    sites = self.module.own_move_sites;
    callee = nd.callee_decl;
    if not sites
        or not isinstance(callee, uni.Ability)
        or not isinstance(callee.signature, uni.FuncSignature)
        or self.builder().block.terminated()
        or self.st().generator is not None {
        return;
    }
    params = callee.signature.get_parameters();
    b = self.builder();
    for (index, arg) in enumerate(list(nd.params or [])) {
        if not isinstance(arg, uni.Name)
            or id(arg) not in sites
            or arg.sym is None
            or arg.sym.storage != SymbolStorage.LOCAL
            or index >= len(params) {
            continue;
        }
        param = params[index];
        if param.name.sym is None or param.name.sym.ownership != OwnershipKind.OWN {
            continue;
        }
        slot = self.st().local_names.get(arg.sym_name);
        if slot is None or not slot.is_slot or not mir_holds_ref(slot.type) {
            continue;
        }
        b.store(slot, b.const_null(slot.type));
    }
}

impl MirLowering.drop_last_uses(stmt: uni.UniNode) {
    if isinstance(stmt, (uni.ReturnStmt, uni.RaiseStmt))
        or self.builder().block.terminated()
        or self.st().generator is not None {
        return;
    }
    sites = self.module.own_move_sites;
    last_uses = self.module.rc_last_use.get(id(stmt)) or [];
    if not sites and not last_uses {
        return;
    }
    targets: list[str] = [];
    if isinstance(stmt, uni.Assignment) {
        targets = [
            t.sym_name
            for t in stmt.target
            if isinstance(t, uni.Name)
        ];
    }
    names: list[str] = [];
    if sites {
        for nm in stmt.get_all_sub_nodes(uni.Name) {
            if id(nm) not in sites
                or nm.sym is None
                or nm.find_parent_of_type(uni.CodeBlockStmt) is not stmt
                or nm.find_parent_of_type(uni.LambdaExpr) is not None
                or nm.sym.storage not in (SymbolStorage.LOCAL, SymbolStorage.PARAM)
                or nm.sym_name in targets
                or nm.sym_name in names {
                continue;
            }
            names.append(nm.sym_name);
        }
    }
    for ln in last_uses {
        if ln in names {
            continue;
        }
        sym = stmt.sym_tab.lookup(ln) if stmt.sym_tab is not None else None;
        if sym is None
            or sym.ownership != OwnershipKind.OWN
            or sym.storage != SymbolStorage.LOCAL {
            continue;
        }
        names.append(ln);
    }
    b = self.builder();
    for name in names {
        slot = self.st().local_names.get(name);
        if slot is None or not slot.is_slot {
            continue;
        }
        t = slot.type.payload() if slot.type.kind == MirKind.OPT else slot.type;
        if t.kind
            not in (
                MirKind.OBJ,
                MirKind.LIST,
                MirKind.DICT,
                MirKind.SET,
                MirKind.ANY
            ) {
            continue;
        }
        b.store(slot, b.const_null(slot.type));
    }
}

impl MirLowering.lower_stmt(nd: uni.UniNode) {
    if isinstance(nd, (uni.AssertStmt, uni.Ability)) and nd.is_comptime {
        return;
    }
    if isinstance(nd, uni.ExprStmt) and isinstance(nd.expr, uni.YieldExpr) {
        self.lower_yield(nd.expr);
    } elif isinstance(nd, uni.ExprStmt) {
        self.lower_expr(nd.expr);
    } elif isinstance(nd, uni.MatchStmt) {
        self.lower_match(nd);
    } elif isinstance(nd, uni.SwitchStmt) {
        self.lower_switch(nd);
    } elif isinstance(nd, uni.WithStmt) {
        self.lower_with(nd);
    } elif isinstance(nd, uni.OpenStmt) {
        self.lower_open(nd);
    } elif isinstance(nd, uni.Assignment) {
        self.lower_assignment(nd);
    } elif isinstance(nd, uni.ReturnStmt) {
        self.lower_return(nd);
    } elif isinstance(nd, uni.IfStmt) {
        self.lower_if(nd);
    } elif isinstance(nd, uni.WhileStmt) {
        self.lower_while(nd);
    } elif isinstance(nd, uni.ForeverStmt) {
        self.lower_forever(nd);
    } elif isinstance(nd, uni.CtrlStmt) {
        self.lower_ctrl(nd);
    } elif isinstance(nd, uni.InForStmt) {
        self.lower_for(nd);
    } elif isinstance(nd, uni.IterForStmt) {
        self.lower_iter_for(nd);
    } elif isinstance(nd, uni.DeleteStmt) {
        self.lower_delete(nd);
    } elif isinstance(nd, uni.TryStmt) {
        self.lower_try(nd);
    } elif isinstance(nd, uni.Ability)
        and isinstance(nd.signature, uni.FuncSignature) {
        body = nd.body.body if isinstance(nd.body, uni.ImplDef) else nd.body;
        if not isinstance(body, (list, tuple)) or nd.name_ref is None {
            raise MirRefused(mir_refusal("statement", "nested function", nd));
        }
        fn_type = self.type_of(
            self.prog.get_type_evaluator().get_type_of_symbol(self.ability_sym(nd)),
            MirPosition.VALUE,
            nd
        );
        made = self.lower_closure(
            nd, nd.signature, list(body), fn_type, self.name_of(nd)
        );
        if not isinstance(nd.name_ref, uni.Name) {
            raise MirRefused(mir_refusal("statement", "nested function name", nd));
        }
        self.store_name(nd.name_ref, made);
    } elif isinstance(nd, uni.RaiseStmt) {
        self.lower_raise(nd);
    } elif isinstance(nd, uni.AssertStmt) {
        self.lower_assert(nd);
    } elif isinstance(nd, (uni.VisitStmt, uni.ReportStmt, uni.DisengageStmt)) {
        self.lower_osp_stmt(nd);
    } elif not isinstance(nd, uni.Import) {
        raise MirRefused(mir_refusal("statement", type(nd).__name__, nd));
    }
}

impl MirLowering.lower_assignment(nd: uni.Assignment) {
    targets = list(nd.target);
    if len(targets) > 1 and nd.value is not None and nd.aug_op is None {
        value = self.lower_expr(nd.value);
        held = self.temp_slot(value.type);
        self.builder().store(held, value);
        for each in targets {
            self.assign_to(each, self.builder().load(held, held.type), nd);
        }
        return;
    }
    if len(targets) != 1 {
        raise MirRefused(mir_refusal("assignment", "several targets", nd));
    }
    target = targets[0];
    if isinstance(target, uni.TupleVal)
        and nd.value is not None
        and nd.aug_op is None {
        self.unpack_into(
            [
                t
                for t in target.values
                if isinstance(t, uni.Expr)
            ],
            self.lower_expr(nd.value),
            nd
        );
        return;
    }
    if isinstance(target, uni.AtomTrailer)
        and not target.is_attr
        and isinstance(target.target, uni.Expr)
        and nd.value is not None
        and nd.aug_op is None
        and self.expr_type(target.target).kind == MirKind.BYTEARRAY {
        self.bytearray_store(target, nd.value, nd);
        return;
    }
    if isinstance(target, uni.AtomTrailer)
        and not target.is_attr
        and isinstance(target.right, uni.IndexSlice)
        and isinstance(target.target, uni.Expr)
        and (
            mir_is_container(self.expr_type(target.target))
            or (
                self.expr_type(target.target).kind == MirKind.OPT
                and mir_is_container(self.expr_type(target.target).payload())
            )
        )
        and nd.value is not None {
        holder = self.lower_expr(target.target);
        if holder.type.kind == MirKind.OPT {
            holder = self.opt_unwrap_checked(
                holder, "'NoneType' object does not support item assignment"
            );
        }
        value = self.lower_expr(nd.value);
        if nd.aug_op is not None {
            op = AUG_OPERATORS.get(nd.aug_op.name);
            if op is None {
                raise MirRefused(
                    mir_refusal("augmented assignment", nd.aug_op.value, nd)
                );
            }
            current = self.container_get(holder, target.right, target);
            value = self.str_concat(current, value)
                if current.type.kind == MirKind.STR and op == Tok.PLUS
                else self.aug_arith(op, current, value, nd);
        }
        self.container_set(holder, target.right, value, nd);
        return;
    }
    if isinstance(target, uni.AtomTrailer) and self.accessor_set(target, nd) {
        return;
    }
    if isinstance(target, uni.AtomTrailer) and nd.value is not None {
        place = self.lower_place(target);
        value = self.lower_expr(nd.value);
        if nd.aug_op is not None {
            op = AUG_OPERATORS.get(nd.aug_op.name);
            if op is None {
                raise MirRefused(
                    mir_refusal("augmented assignment", nd.aug_op.value, nd)
                );
            }
            current = self.builder().load(place, self.place_elem(place));
            extended = self.list_extend_in_place(op, current, value, nd);
            if extended is not None {
                return;
            }
            value = self.str_concat(current, self.coerce(value, mir_str(), nd))
                if current.type.kind == MirKind.STR and op == Tok.PLUS
                else self.aug_arith(op, current, value, nd);
        }
        self.builder().store(place, self.coerce(value, self.place_elem(place), nd));
        return;
    }
    if not isinstance(target, uni.Name) {
        raise MirRefused(mir_refusal("assignment", type(target).__name__, nd));
    }
    if nd.aug_op is None
        and isinstance(nd.value, uni.FuncCall)
        and self.getattr_alias(target.sym) is not None {
        return;
    }
    if nd.value is None {
        self.local_slot(target.sym, target);
        return;
    }
    value = self.lower_expr(nd.value);
    if nd.aug_op is not None {
        op = AUG_OPERATORS.get(nd.aug_op.name);
        if op is None {
            raise MirRefused(mir_refusal("augmented assignment", nd.aug_op.value, nd));
        }
        current = self.lower_name(target);
        if self.list_extend_in_place(op, current, value, nd) is not None {
            return;
        }
        if current.type.kind == MirKind.SET
            and self.set_operator(op, current, value, True, nd) is not None {
            return;
        }
        if current.type.kind == MirKind.STR and op == Tok.PLUS {
            value = self.str_concat(current, self.coerce(value, mir_str(), nd));
        } else {
            value = self.aug_arith(op, current, value, nd);
        }
    }
    self.store_name(target, value);
}

impl MirLowering.exchange_place(arg: uni.Expr) -> MirValue {
    inner: uni.UniNode = arg;
    while True {
        if isinstance(inner, uni.AtomUnit) {
            inner = inner.value;
        } elif isinstance(inner, uni.UnaryExpr) and is_borrow_kind(inner.ownership) {
            inner = inner.operand;
        } else {
            break;
        }
    }
    if isinstance(inner, uni.Name) {
        return self.name_slot(inner);
    }
    if isinstance(inner, uni.AtomTrailer) {
        return self.lower_place(inner);
    }
    raise MirRefused(
        mir_refusal(
            "place",
            type(inner).__name__,
            arg,
            "take() and swap() act on a local or an attribute."
        )
    );
}

impl MirLowering.place_exchange(nd: uni.FuncCall, name: str) -> (MirValue | None) {
    args = self.call_args(nd);
    if len(args) != (1 if name == "take" else 2) {
        return None;
    }
    b = self.builder();
    first = self.exchange_place(args[0]);
    elem = self.place_elem(first);
    held = self.temp_slot(elem);
    b.store(held, b.load(first, elem));
    if name == "take" {
        if elem.kind in (MirKind.OPT, MirKind.ANY, MirKind.NONE) {
            emptied = self.coerce(self.none_value(), elem, nd);
        } elif mir_holds_ref(elem) {
            emptied = b.const_null(elem);
        } else {
            raise MirRefused(
                mir_refusal(
                    "take", elem.render(), nd, "take() empties an optional place."
                )
            );
        }
        b.store(first, emptied);
        return b.load(held, elem);
    }
    second = self.exchange_place(args[1]);
    b.store(first, self.coerce(b.load(second, self.place_elem(second)), elem, nd));
    b.store(second, self.coerce(b.load(held, elem), self.place_elem(second), nd));
    return self.none_value();
}

impl MirLowering.assign_to(target: uni.UniNode, value: MirValue, nd: uni.Assignment) {
    if isinstance(target, uni.Name) {
        self.store_name(target, value);
    } elif isinstance(target, uni.TupleVal) {
        self.unpack_into(
            [
                t
                for t in target.values
                if isinstance(t, uni.Expr)
            ],
            value,
            nd
        );
    } elif isinstance(target, uni.AtomTrailer)
        and not target.is_attr
        and isinstance(target.right, uni.IndexSlice)
        and isinstance(target.target, uni.Expr)
        and mir_is_container(self.expr_type(target.target)) {
        self.container_set(self.lower_expr(target.target), target.right, value, nd);
    } elif isinstance(target, uni.AtomTrailer)
        and self.expr_type(target.target).kind != MirKind.BYTEARRAY {
        place = self.lower_place(target);
        self.builder().store(place, self.coerce(value, self.place_elem(place), nd));
    } else {
        raise MirRefused(mir_refusal("assignment", type(target).__name__, nd));
    }
}

impl MirLowering.store_name(target: uni.Name, value: MirValue) {
    if target.sym is not None {
        cell = self.cell_of(id(target.sym));
        if cell is not None {
            self.cell_write(cell, value, self.st().cell_types[id(target.sym)], target);
            return;
        }
    }
    slot = self.name_slot(target);
    stored = self.coerce(value, self.place_elem(slot), target);
    if any(slot is held for held in self.st().region_slots) {
        self.region_call("__jac_region_drop", [self.builder().load(slot, slot.type)]);
    }
    self.builder().store(slot, stored);
}

impl MirLowering.name_slot(target: uni.Name) -> MirValue {
    if target.sym is not None and id(target.sym) not in self.st().locals {
        place = self.global_place(target);
        if place is not None {
            return place;
        }
    }
    return self.local_slot(target.sym, target);
}

impl MirLowering.local_slot(sym: (uni.Symbol | None), site: uni.UniNode) -> MirValue {
    if sym is None {
        raise MirRefused(mir_refusal("name", "unresolved", site));
    }
    key = id(sym);
    found = self.st().locals.get(key);
    if found is not None {
        return found;
    }
    slot_type = self.symbol_type(sym, site);
    namesake = self.st().local_names.get(sym.sym_name)
        if not self.comprehension_scoped(sym)
        else None;
    if namesake is not None and namesake.type is slot_type {
        self.st().locals[key] = namesake;
        return namesake;
    }
    fn = self.st().fn;
    first = fn.blocks[0];
    made = fn.new_value(slot_type, sym.sym_name);
    made.is_slot = True;
    made.is_temp = self.loop_scoped(sym);
    if slot_type.kind != MirKind.NONE {
        first.instrs.insert(
            0, MirInstr(op=MirOp.SLOT, result=made, type_arg=slot_type)
        );
    }
    if slot_type.kind == MirKind.REGION and sym.na_region_handle {
        empty = fn.new_value(slot_type);
        at = 0;
        while at < len(first.instrs)
            and first.instrs[at].op in (MirOp.SLOT, MirOp.EXC_FRAME, MirOp.ALLOCA) {
            at += 1;
        }
        first.instrs.insert(at, MirInstr(op=MirOp.STORE, operands=[made, empty]));
        first.instrs.insert(
            at, MirInstr(op=MirOp.CONST_NULL, result=empty, type_arg=slot_type)
        );
        self.st().region_slots.append(made);
    }
    self.st().locals[key] = made;
    if not self.comprehension_scoped(sym) {
        self.st().local_names.setdefault(sym.sym_name, made);
    }
    return made;
}

impl MirLowering.encloses(scope: (uni.UniScopeNode | None), nd: uni.UniNode) -> bool {
    if scope is None {
        return False;
    }
    walk: (uni.UniNode | None) = nd.parent;
    while walk is not None {
        if walk is scope {
            return True;
        }
        walk = walk.parent;
    }
    return False;
}

impl MirLowering.comprehension_scoped(sym: uni.Symbol) -> bool {
    scope = sym.parent_tab;
    return isinstance(
        scope, (uni.InnerCompr, uni.ListCompr, uni.DictCompr, uni.LambdaExpr)
    );
}

impl MirLowering.loop_scoped(sym: uni.Symbol) -> bool {
    if not sym.defn {
        return False;
    }
    child: uni.UniNode = sym.defn[0];
    walk = child.parent;
    while walk is not None
        and not isinstance(walk, (uni.Ability, uni.LambdaExpr, uni.Module)) {
        if isinstance(
            walk, (uni.WhileStmt, uni.ForeverStmt, uni.InForStmt, uni.IterForStmt)
        )
            and (
                any(child is stmt for stmt in walk.body)
                or (isinstance(walk, uni.InForStmt) and child is walk.target)
            )
            and all(self.within_body(use, walk) for use in sym.uses) {
            return True;
        }
        child = walk;
        walk = walk.parent;
    }
    return False;
}

impl MirLowering.within_body(
    nd: uni.UniNode,
    loop: (uni.WhileStmt | uni.ForeverStmt | uni.InForStmt | uni.IterForStmt)
) -> bool {
    child = nd;
    walk = nd.parent;
    while walk is not None {
        if walk is loop {
            return any(child is stmt for stmt in loop.body);
        }
        if isinstance(walk, (uni.Ability, uni.LambdaExpr)) {
            return False;
        }
        child = walk;
        walk = walk.parent;
    }
    return False;
}

impl MirLowering.lower_return(nd: uni.ReturnStmt) {
    ret = self.st().fn.ret;
    if nd.expr is None {
        if ret.kind != MirKind.NONE {
            raise MirRefused(mir_refusal("return", "missing value", nd));
        }
        self.leave_tries(0);
        self.drop_regions();
        self.builder().ret(None);
        return;
    }
    value = self.lower_expr(nd.expr);
    moved = self.c_bare(nd.expr);
    if isinstance(moved, uni.Name) and moved.sym is not None {
        held = self.st().locals.get(id(moved.sym));
        if held is not None and any(held is slot for slot in self.st().region_slots) {
            self.builder().store(held, self.builder().const_null(held.type));
        }
    }
    self.leave_tries(0);
    self.drop_regions();
    if ret.kind == MirKind.NONE {
        self.builder().ret(None);
        return;
    }
    self.builder().ret(self.coerce(value, ret, nd));
}

impl MirLowering.lower_if(nd: (uni.IfStmt | uni.ElseIf)) {
    if nd.is_comptime {
        raise MirRefused(mir_refusal("statement", "comptime if", nd));
    }
    cond = self.condition(nd.condition);
    fn = self.st().fn;
    then_bb = fn.new_block("then");
    else_bb = fn.new_block("else");
    done_bb = fn.new_block("endif");
    self.builder().cond_branch(cond, then_bb, else_bb);
    self.builder().position(then_bb);
    self.lower_body(nd.body);
    if not self.builder().block.terminated() {
        self.builder().branch(done_bb);
    }
    self.builder().position(else_bb);
    self.lower_else(nd.else_body, done_bb);
    self.builder().position(done_bb);
}

impl MirLowering.lower_else(nd: (uni.ElseStmt | uni.ElseIf | None), done: MirBlock) {
    if isinstance(nd, uni.ElseIf) {
        self.lower_if(nd);
    } elif isinstance(nd, uni.ElseStmt) {
        self.lower_body(nd.body);
    }
    if not self.builder().block.terminated() {
        self.builder().branch(done);
    }
}

impl MirLowering.lower_while(nd: uni.WhileStmt) {
    fn = self.st().fn;
    head = fn.new_block("while.head");
    body = fn.new_block("while.body");
    otherwise = fn.new_block("while.else");
    after = fn.new_block("while.exit");
    self.builder().branch(head);
    self.builder().position(head);
    cond = self.condition(nd.condition);
    self.builder().cond_branch(cond, body, otherwise);
    self.builder().position(body);
    self.st().loops.append(MirLoopTarget(head=head, after=after));
    self.lower_body(nd.body);
    self.st().loops.pop();
    if not self.builder().block.terminated() {
        self.builder().branch(head);
    }
    self.builder().position(otherwise);
    self.lower_else(nd.else_body, after);
    self.builder().position(after);
}

impl MirLowering.lower_forever(nd: uni.ForeverStmt) {
    fn = self.st().fn;
    head = fn.new_block("forever.body");
    after = fn.new_block("forever.exit");
    self.builder().branch(head);
    self.builder().position(head);
    self.st().loops.append(MirLoopTarget(head=head, after=after));
    self.lower_body(nd.body);
    self.st().loops.pop();
    if not self.builder().block.terminated() {
        self.builder().branch(head);
    }
    self.builder().position(after);
}

impl MirLowering.lower_iter_for(nd: uni.IterForStmt) {
    if nd.is_async {
        raise MirRefused(mir_refusal("statement", "async for", nd));
    }
    fn = self.st().fn;
    self.lower_assignment(nd.iter);
    head = fn.new_block("iterfor.head");
    body = fn.new_block("iterfor.body");
    step = fn.new_block("iterfor.step");
    otherwise = fn.new_block("iterfor.else");
    after = fn.new_block("iterfor.exit");
    self.builder().branch(head);
    self.builder().position(head);
    cond = self.condition(nd.condition);
    self.builder().cond_branch(cond, body, otherwise);
    self.builder().position(body);
    self.st().loops.append(MirLoopTarget(head=step, after=after));
    self.lower_body(nd.body);
    self.st().loops.pop();
    if not self.builder().block.terminated() {
        self.builder().branch(step);
    }
    self.builder().position(step);
    self.lower_assignment(nd.count_by);
    self.builder().branch(head);
    self.builder().position(otherwise);
    self.lower_else(nd.else_body, after);
    self.builder().position(after);
}

impl MirLowering.lower_ctrl(nd: uni.CtrlStmt) {
    if nd.ctrl.name == Tok.KW_SKIP {
        self.lower_osp_stmt(nd);
        return;
    }
    if not self.st().loops {
        raise MirRefused(mir_refusal("statement", nd.ctrl.value, nd));
    }
    target = self.st().loops[-1];
    if nd.ctrl.name in (Tok.KW_BREAK, Tok.KW_CONTINUE) {
        self.leave_tries(len(self.st().loops));
    }
    if nd.ctrl.name == Tok.KW_BREAK {
        self.builder().branch(target.after);
    } elif nd.ctrl.name == Tok.KW_CONTINUE {
        self.builder().branch(target.head);
    } else {
        raise MirRefused(mir_refusal("statement", nd.ctrl.value, nd));
    }
}

impl MirLowering.lower_expr(nd: uni.UniNode) -> MirValue {
    value: (MirValue | None) = None;
    if isinstance(nd, uni.Int) {
        bits = uni.int_literal_i64(nd.value);
        if bits is None {
            dest = self.literal_destination(nd);
            shape = shape_of(dest) if dest else None;
            if dest is not None and shape is not None and shape.is_float {
                value = self.builder().const_float(
                    uni.int_literal_float(nd.value), mir_float()
                );
                return self.coerce(value, mir_class_type_named(dest, nd), nd);
            }
            if shape is not None and not shape.signed and shape.width >= 64 {
                bits = uni.int_literal_u64_bits(nd.value);
            }
        }
        if bits is None {
            raise MirRefused(
                mir_refusal(
                    "integer literal",
                    nd.value,
                    nd,
                    "A native int is 64 bits and this literal does not fit one."
                )
            );
        }
        value = self.builder().const_int(
            bits, self.expr_type(nd) if nd.type is not None else mir_int()
        );
    } elif isinstance(nd, uni.Float) {
        value = self.builder().const_float(
            float(nd.value), self.expr_type(nd) if nd.type is not None else mir_float()
        );
    } elif isinstance(nd, uni.Bool) {
        value = self.builder().const_bool(nd.value.lower() in ("true", "1"));
    } elif isinstance(nd, uni.Ellipsis) {
        b = self.builder();
        made = self.any_make(
            b.const_int(ANY_ELLIPSIS_TAG, mir_int()), b.const_int(0, mir_int())
        );
        made.owned = True;
        value = made;
    } elif isinstance(nd, uni.Null) {
        value = self.none_value();
    } elif isinstance(nd, uni.TupleVal) {
        value = self.lower_tuple(nd);
    } elif isinstance(nd, uni.LambdaExpr) {
        tail = nd.body if isinstance(nd.body, uni.Expr) else nd.tail_return_expr();
        value = self.lower_closure(
            nd,
            nd.signature,
            tail if tail is not None else nd.body,
            self.expr_type(nd),
            f"lambda{len(self.nested)}"
        );
    } elif isinstance(nd, (uni.ListCompr, uni.DictCompr)) {
        value = self.lower_comprehension(nd);
    } elif isinstance(nd, uni.YieldExpr) {
        value = self.yield_expression(nd);
    } elif isinstance(nd, uni.ListVal) {
        value = self.lower_list_literal(nd);
    } elif isinstance(nd, uni.DictVal) {
        value = self.lower_dict_literal(nd);
    } elif isinstance(nd, uni.SetVal) {
        value = self.lower_set_literal(nd);
    } elif isinstance(nd, (uni.String, uni.MultiString)) {
        value = self.lower_string(nd);
    } elif isinstance(nd, uni.Name) {
        value = self.lower_name(nd);
    } elif isinstance(nd, uni.AtomUnit) {
        value = self.lower_expr(nd.value);
    } elif isinstance(nd, uni.CfgExpr) {
        value = self.lower_expr(nd.expr);
    } elif isinstance(nd, uni.CastExpr) {
        value = self.lower_cast(nd);
    } elif isinstance(nd, uni.BinaryExpr) {
        value = self.lower_binary(nd);
    } elif isinstance(nd, uni.CompareExpr) {
        value = self.lower_compare(nd);
    } elif isinstance(nd, uni.UnaryExpr) {
        value = self.lower_unary(nd);
    } elif isinstance(nd, uni.BoolExpr) {
        value = self.lower_bool(nd);
    } elif isinstance(nd, uni.IfElseExpr) {
        value = self.lower_if_else_expr(nd);
    } elif isinstance(nd, uni.FString) {
        value = self.lower_fstring(nd);
    } elif isinstance(nd, uni.FuncCall) {
        value = self.lower_call(nd);
        self.drop_consumed_args(nd);
    } elif isinstance(nd, uni.ConcurrentExpr) {
        value = self.lower_concurrent(nd);
    } elif isinstance(nd, uni.AwaitExpr) {
        value = self.coerce(self.lower_expr(nd.target), self.expr_type(nd), nd);
    } elif isinstance(nd, uni.AtomTrailer) {
        value = self.lower_trailer(nd);
    } elif isinstance(nd, uni.EdgeRefTrailer) {
        value = self.osp_typed(self.lower_edge_handles(nd), nd);
    } else {
        raise MirRefused(mir_refusal("expression", type(nd).__name__, nd));
    }
    if value is None {
        raise MirRefused(mir_refusal("expression", type(nd).__name__, nd));
    }
    if isinstance(nd, uni.Expr) and nd.coerce_to is not None {
        value = self.coerce(value, mir_class_type_named(nd.coerce_to, nd), nd);
    }
    return value;
}

impl MirLowering.lower_name(nd: uni.Name) -> MirValue {
    receiver = self.st().self_value;
    if nd.value == "self" and receiver is not None {
        return receiver;
    }
    if isinstance(nd, uni.SpecialVarRef)
        and nd.value in ("here", "visitor", "root")
        and (nd.sym is None or id(nd.sym) not in self.st().locals) {
        return self.osp_special(nd);
    }
    if nd.sym is not None {
        cell = self.cell_of(id(nd.sym));
        if cell is not None {
            return self.cell_read(cell, self.st().cell_types[id(nd.sym)]);
        }
    }
    if nd.sym is not None
        and id(nd.sym) not in self.st().locals
        and self.cell_of(id(nd.sym)) is None
        and id(nd.sym) not in self.decl_syms
        and self.global_declaration(nd.sym) is None
        and nd.sym.sym_name in self.st().local_names
        and not (
            self.comprehension_scoped(nd.sym) and self.encloses(nd.sym.parent_tab, nd)
        ) {
        namesake = self.st().local_names[nd.sym.sym_name];
        return self.coerce(
            self.builder().load(namesake, namesake.type), self.expr_type(nd), nd
        );
    }
    if nd.sym is None or id(nd.sym) not in self.st().locals {
        twin = self.variant_glob(nd) if nd.sym is not None else None;
        if twin is not None {
            made = self.variant_value(nd, twin);
            if made is not None {
                return made;
            }
        }
        folded = nd.ct_value;
        whole = int_host(folded) if isinstance(folded, CtInt) else None;
        if whole is not None and -(1 << 63) <= whole < (1 << 63) {
            return self.builder().const_int(whole, self.expr_type(nd));
        }
        if isinstance(folded, CtBool) {
            return self.builder().const_bool(folded.value);
        }
        if isinstance(folded, CtFloat) {
            return self.builder().const_float(folded.value, self.expr_type(nd));
        }
        final_value = final_glob_value(nd);
        (settled, scalar) = c_scalar_constant(final_value)
            if final_value is not None
            else (False, None);
        if settled and isinstance(scalar, bool) {
            return self.builder().const_bool(scalar);
        }
        if settled
            and isinstance(scalar, int)
            and -(1 << 63) <= scalar < (1 << 64)
            and self.expr_type(nd).kind == MirKind.INT {
            return self.builder().const_int(
                scalar - (1 << 64) if scalar >= (1 << 63) else scalar,
                self.expr_type(nd)
            );
        }
        if settled
            and isinstance(scalar, float)
            and self.expr_type(nd).kind == MirKind.FLOAT {
            return self.builder().const_float(scalar, self.expr_type(nd));
        }
        place = self.global_place(nd);
        if place is not None {
            return self.builder().load(place, self.place_elem(place));
        }
        decl = self.decls.get(self.decl_syms.get(id(nd.sym), -1))
            if nd.sym is not None
            else None;
        if decl is not None and not decl.c_symbol {
            address = self.emit_value(
                MirOp.FN_ADDR, mir_c_fn(decl.params, decl.ret), [], callee=decl.symbol
            );
            self.fn_values[address.id] = decl;
            return address;
        }
        named = self.class_reference(nd);
        if named is not None {
            return self.class_value(named);
        }
        if nd.value == "__name__" {
            return self.builder().const_str(
                module_dotted_name(self.module.loc.mod_path), mir_str()
            );
        }
        if nd.value == "__file__" {
            return self.builder().const_str(
                os.path.realpath(self.module.loc.mod_path), mir_str()
            );
        }
        target = nd.sym.decl.parent
            if nd.sym is not None and nd.sym.decl is not None
            else None;
        if isinstance(target, uni.Ability)
            and isinstance(target.parent, uni.Module)
            and target.parent is not self.module
            and target.loc.mod_path.endswith(".jac")
            and not self.template_of(target) {
            foreign = self.foreign_function_decl(target, nd);
            address = self.emit_value(
                MirOp.FN_ADDR,
                mir_c_fn(foreign.params, foreign.ret),
                [],
                callee=foreign.symbol
            );
            self.fn_values[address.id] = foreign;
            return address;
        }
        c_function = self.c_extern_address(nd);
        if c_function is not None {
            return c_function;
        }
        if named_function_of(nd) is not None {
            symbol = self.c_function_symbol(nd, False);
            held = self.mir.externs.get(symbol);
            if held is not None {
                return self.emit_value(
                    MirOp.FN_ADDR, mir_c_fn(held.params, held.ret), [], callee=symbol
                );
            }
        }
        raise MirRefused(mir_refusal("name", nd.value, nd));
    }
    slot = self.st().locals[id(nd.sym)];
    loaded = self.builder().load(slot, slot.type);
    if loaded.type.kind == MirKind.OPT
        and nd.type is not None
        and not (
            isinstance(nd.type, ClassType)
            and nd.type.shared.class_name in ("NoneType", "None")
        )
        and not (
            isinstance(nd.type, UnionType)
            and any(
                isinstance(member, ClassType)
                    and member.shared.class_name in ("NoneType", "None")
                for member in nd.type.types
            )
        ) {
        return self.narrow_down(self.opt_get(loaded), nd);
    }
    if loaded.type.kind == MirKind.OBJ {
        return self.narrow_down(loaded, nd);
    }
    if loaded.type.kind == MirKind.ANY {
        return self.narrow(loaded, nd);
    }
    return loaded;
}

impl MirLowering.pipe_call(nd: uni.BinaryExpr) -> MirValue {
    forward = isinstance(nd.op, uni.Token) and nd.op.name == Tok.PIPE_FWD;
    subject = nd.left if forward else nd.right;
    target = nd.right if forward else nd.left;
    decl = self.decls.get(self.decl_syms.get(id(target.sym), -1))
        if isinstance(target, uni.Name) and target.sym is not None
        else None;
    b = self.builder();
    value = self.lower_expr(subject);
    if decl is not None and decl.self_type is None {
        args = [value];
        if value.type.kind == MirKind.TUPLE and len(decl.params) > 1 {
            held = self.spill(value);
            args = [
                self.tuple_get(held, index) for index in range(len(value.type.args))
            ];
        }
        if len(args) != len(decl.params) {
            raise MirRefused(
                mir_refusal(
                    "pipe",
                    f"{len(args)} arguments into {self.name_of(decl.ability)}",
                    nd
                )
            );
        }
        values = [
            self.coerce(arg, ptype, subject) for (arg, ptype) in zip(args, decl.params)
        ];
        result = b.call(decl.symbol, values, decl.ret);
        return result if result is not None else self.none_value();
    }
    raise MirRefused(
        mir_refusal(
            "pipe",
            "target that is not a module function",
            nd,
            "A native pipe feeds its value into a named function of this module; call the function directly otherwise."
        )
    );
}

impl MirLowering.lower_binary(nd: uni.BinaryExpr) -> MirValue {
    if isinstance(nd.op, (uni.ConnectOp, uni.DisconnectOp))
        or (isinstance(nd.op, uni.Token) and nd.op.name == Tok.KW_SPAWN) {
        return self.lower_osp_binary(nd);
    }
    if not isinstance(nd.op, uni.Token) {
        raise MirRefused(mir_refusal("binary operator", type(nd.op).__name__, nd));
    }
    if nd.op.name == Tok.WALRUS_EQ and isinstance(nd.left, uni.Name) {
        self.store_name(nd.left, self.lower_expr(nd.right));
        return self.lower_name(nd.left);
    }
    if nd.op.name in (Tok.PIPE_FWD, Tok.PIPE_BKWD) {
        return self.pipe_call(nd);
    }
    left = self.lower_expr(nd.left);
    right = self.lower_expr(nd.right);
    if left.type.kind == MirKind.STR
        and right.type.kind == MirKind.STR
        and nd.op.name == Tok.PLUS {
        return self.str_concat(left, right);
    }
    if left.type.kind == MirKind.LIST
        and left.type is right.type
        and nd.op.name == Tok.PLUS {
        return self.list_concat(left, right);
    }
    if left.type.kind == MirKind.LIST
        and right.type.kind == MirKind.LIST
        and nd.op.name == Tok.PLUS {
        joined_type = self.expr_type(nd);
        if joined_type.kind == MirKind.LIST {
            made = self.spill(self.new_list(joined_type.payload(), 0));
            self.extend_from(made, self.spill(left), nd.left);
            self.extend_from(made, self.spill(right), nd.right);
            return made;
        }
    }
    if nd.op.name == Tok.STAR_MUL
        and MirKind.LIST in (left.type.kind, right.type.kind)
        and MirKind.INT in (left.type.kind, right.type.kind) {
        return self.list_repeat(
            left if left.type.kind == MirKind.LIST else right,
            right if left.type.kind == MirKind.LIST else left,
            nd
        );
    }
    via_set = self.set_operator(nd.op.name, left, right, False, nd);
    if via_set is not None {
        return via_set;
    }
    return self.arith(nd.op.name, left, right, nd);
}

impl MirLowering.pointer_arith(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> (MirValue | None) {
    if left.type.kind != MirKind.C_PTR or op not in (Tok.PLUS, Tok.MINUS) {
        return None;
    }
    b = self.builder();
    if right.type.kind == MirKind.C_PTR and op == Tok.MINUS {
        span = b.binary(
            "sub",
            self.emit_value(MirOp.PTR_INT, mir_int(), [left]),
            self.emit_value(MirOp.PTR_INT, mir_int(), [right])
        );
        elem = left.type.payload();
        if elem.kind in (MirKind.NONE, MirKind.VOID, MirKind.OBJ) {
            return span;
        }
        size = self.st().fn.new_value(mir_int());
        b.emit(MirInstr(op=MirOp.SIZEOF, result=size, type_arg=left.type));
        return b.binary("floordiv", span, size);
    }
    if right.type.kind not in (MirKind.INT, MirKind.BOOL) {
        raise MirRefused(mir_refusal("pointer arithmetic", right.type.render(), site));
    }
    step = b.convert(right, mir_int());
    offset = step
        if op == Tok.PLUS
        else b.binary("sub", b.const_int(0, mir_int()), step);
    if left.type.payload().kind == MirKind.OBJ {
        u8p = mir_c_ptr(mir_int(8, False));
        moved = self.emit_value(
            MirOp.PTR_OFFSET,
            u8p,
            [self.emit_value(MirOp.PTR_CAST, u8p, [left]), offset]
        );
        return self.emit_value(MirOp.PTR_CAST, left.type, [moved]);
    }
    return self.emit_value(MirOp.PTR_OFFSET, left.type, [left, offset]);
}

impl MirLowering.aug_arith(
    op: str, current: MirValue, value: MirValue, site: uni.UniNode
) -> MirValue {
    extended = self.list_extend_in_place(op, current, value, site);
    if extended is not None {
        return extended;
    }
    if current.type.kind == MirKind.OBJ {
        via_dunder = self.object_operator(op, current, value, site, True);
        if via_dunder is not None {
            return via_dunder;
        }
    }
    if op == Tok.PLUS
        and current.type.kind == MirKind.LIST
        and (
            mir_is_container(value.type)
            or value.type.kind in (MirKind.TUPLE, MirKind.ITER)
        ) {
        held = self.spill(current);
        self.extend_from(held, self.spill(value), site);
        return held;
    }
    return self.arith(op, current, value, site);
}

impl MirLowering.arith(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if MirKind.OBJ in (left.type.kind, right.type.kind) {
        via_dunder = self.object_operator(op, left, right, site);
        if via_dunder is not None {
            return via_dunder;
        }
    }
    if left.type.kind == MirKind.OPT or right.type.kind == MirKind.OPT {
        symbol = OPERATOR_SYMBOLS.get(op, op);
        names = [
            "NoneType" if side.type.kind == MirKind.OPT else side.type.render()
            for side in (left, right)
        ];
        message = f"unsupported operand type(s) for {symbol}: '{names[0]}' and '{names[
            1
        ]}'";
        if left.type.kind == MirKind.OPT {
            left = self.opt_unwrap_checked(left, message);
        }
        if right.type.kind == MirKind.OPT {
            right = self.opt_unwrap_checked(right, message);
        }
    }
    stepped = self.pointer_arith(op, left, right, site);
    if stepped is not None {
        return stepped;
    }
    if MirKind.ANY in (left.type.kind, right.type.kind) and op in ANY_ARITH_CODES {
        return self.any_arith(op, left, right, site);
    }
    left = self.enum_as_int(left, site);
    right = self.enum_as_int(right, site);
    if op == Tok.STAR_POW {
        return self.power(left, right, site);
    }
    if not left.type.is_numeric() or not right.type.is_numeric() {
        textual = self.text_binary(op, left, right, site);
        if textual is not None {
            return textual;
        }
        raise MirRefused(
            mir_refusal("binary operator", f"{op} on {left.type.render()}", site)
        );
    }
    if op == Tok.DIV
        or left.type.kind == MirKind.FLOAT
        or right.type.kind == MirKind.FLOAT {
        wide = mir_float(
            max(
                left.type.width if left.type.kind == MirKind.FLOAT else 64,
                right.type.width if right.type.kind == MirKind.FLOAT else 64
            )
        );
        fl = b.convert(left, wide);
        fr = b.convert(right, wide);
        if op == Tok.PLUS {
            return b.binary("add", fl, fr);
        }
        if op == Tok.MINUS {
            return b.binary("sub", fl, fr);
        }
        if op == Tok.STAR_MUL {
            return b.binary("mul", fl, fr);
        }
        if op in (Tok.DIV, Tok.MOD, Tok.FLOOR_DIV) {
            message = FLOAT_ZERO_DIVISION_MESSAGE;
            if op == Tok.MOD {
                message = FLOAT_ZERO_MODULO_MESSAGE;
            } elif op == Tok.FLOOR_DIV {
                message = FLOAT_ZERO_FLOOR_MESSAGE;
            }
            zero = b.const_float(0.0, wide);
            self.raise_if(b.compare("eq", fr, zero), "ZeroDivisionError", message);
            if op == Tok.DIV {
                return b.binary("div", fl, fr);
            }
            return b.binary("mod" if op == Tok.MOD else "floordiv", fl, fr);
        }
        raise MirRefused(mir_refusal("binary operator", f"{op} on float", site));
    }
    if op in (Tok.LSHIFT, Tok.RSHIFT) {
        shifted = b.convert(left, mir_int())
            if left.type.kind == MirKind.BOOL
            else left;
        count = b.convert(right, mir_int())
            if right.type.kind == MirKind.BOOL
            else right;
        return self.shift(op, shifted, count);
    }
    (li, ri) = self.unify_numeric(left, right, site);
    if op in (Tok.PLUS, Tok.MINUS, Tok.STAR_MUL) {
        name = "add" if op == Tok.PLUS else ("sub" if op == Tok.MINUS else "mul");
        self.raise_if(b.overflows(name, li, ri), "OverflowError", OVERFLOW_MESSAGE);
        return b.binary(name, li, ri);
    }
    if op in (Tok.FLOOR_DIV, Tok.MOD) {
        zero = b.const_int(0, ri.type);
        self.raise_if(
            b.compare("eq", ri, zero), "ZeroDivisionError", ZERO_DIVISION_MESSAGE
        );
        if op == Tok.FLOOR_DIV {
            self.raise_if(
                b.overflows("floordiv", li, ri), "OverflowError", OVERFLOW_MESSAGE
            );
            return b.binary("floordiv", li, ri);
        }
        if li.type.signed {
            minus_one = b.compare("eq", ri, b.const_int(-1, ri.type));
            return b.binary(
                "mod", li, b.select(minus_one, b.const_int(1, ri.type), ri)
            );
        }
        return b.binary("mod", li, ri);
    }
    if op == Tok.BW_AND {
        return b.binary("and", li, ri);
    }
    if op == Tok.BW_OR {
        return b.binary("or", li, ri);
    }
    if op == Tok.BW_XOR {
        return b.binary("xor", li, ri);
    }
    raise MirRefused(mir_refusal("binary operator", op, site));
}

impl MirLowering.shift(op: str, left: MirValue, right: MirValue) -> MirValue {
    b = self.builder();
    t = left.type;
    name = "shl" if op == Tok.LSHIFT else "shr";
    if t.is_sized() or right.type.is_sized() {
        unsigned_count = b.convert(right, mir_int(right.type.width, False));
        self.raise_if(
            b.compare("ge", unsigned_count, b.const_int(t.width, unsigned_count.type)),
            "OverflowError",
            SHIFT_MESSAGE
        );
        count = b.convert(right, t);
        result = b.binary(name, left, count);
        if name == "shl" {
            self.raise_if(
                b.compare("ne", b.binary("shr", result, count), left),
                "OverflowError",
                OVERFLOW_MESSAGE
            );
        }
        return result;
    }
    self.raise_if(
        b.compare("lt", right, b.const_int(0, right.type)),
        "ValueError",
        NEGATIVE_SHIFT_MESSAGE
    );
    count = b.convert(right, t);
    unsigned_count = b.convert(count, mir_int(64, False));
    wide = b.compare("ge", unsigned_count, b.const_int(64, unsigned_count.type));
    safe = b.binary("and", count, b.const_int(63, t));
    result = b.binary(name, left, safe);
    if name == "shr" {
        return b.select(wide, b.binary("shr", left, b.const_int(63, t)), result);
    }
    self.raise_if(
        b.binary("and", wide, b.compare("ne", left, b.const_int(0, t))),
        "OverflowError",
        OVERFLOW_MESSAGE
    );
    lost = b.compare("ne", b.binary("shr", result, safe), left);
    self.raise_if(
        b.binary("and", b.logical_not(wide), lost), "OverflowError", OVERFLOW_MESSAGE
    );
    return b.select(wide, b.const_int(0, t), result);
}

impl MirLowering.lower_compare(nd: uni.CompareExpr) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    result = fn.new_value(mir_bool(), "cmp.chain");
    fn.blocks[0].instrs.insert(
        0, MirInstr(op=MirOp.SLOT, result=result, type_arg=mir_bool())
    );
    done = fn.new_block("cmp.done");
    left = self.lower_expr(nd.left);
    left_nd: uni.Expr = nd.left;
    count = len(nd.ops);
    for (index, (op, right_nd)) in enumerate(zip(nd.ops, nd.rights)) {
        right = self.lower_expr(right_nd);
        verdict = self.view_compare(op.name, left_nd, left, right_nd, right)
            or self.compare_values(op.name, left, right, nd);
        left_nd = right_nd;
        b.store(result, verdict);
        if index + 1 < count {
            right = self.spill(right);
            more = fn.new_block("cmp.next");
            b.cond_branch(verdict, more, done);
            b.position(more);
        } else {
            b.branch(done);
        }
        left = right;
    }
    b.position(done);
    return b.load(result, mir_bool());
}

impl MirLowering.view_kind(nd: uni.Expr) -> str {
    t = nd.type;
    if isinstance(t, ClassType)
        and t._shared is not None
        and t.shared.class_name in ("dict_keys", "dict_items", "dict_values") {
        return t.shared.class_name;
    }
    return "";
}

impl MirLowering.view_compare(
    op: str, left_nd: uni.Expr, left: MirValue, right_nd: uni.Expr, right: MirValue
) -> (MirValue | None) {
    if op not in (Tok.EE, Tok.NE) {
        return None;
    }
    lv = self.view_kind(left_nd);
    rv = self.view_kind(right_nd);
    if not lv and not rv {
        return None;
    }
    b = self.builder();
    if "dict_values" in (lv, rv) {
        same = isinstance(left_nd, uni.Name)
            and isinstance(right_nd, uni.Name)
            and left_nd.sym is not None
            and left_nd.sym is right_nd.sym;
        return b.const_bool(same == (op == Tok.EE));
    }
    sides: list[MirValue] = [];
    for (kind, value) in ((lv, left), (rv, right)) {
        if kind {
            if value.type.kind != MirKind.LIST {
                return None;
            }
            elem = value.type.payload();
            made = self.spill(self.new_dict(elem, None, mir_set(elem)));
            self.extend_from(made, self.spill(value), left_nd);
            sides.append(made);
        } elif value.type.kind == MirKind.SET {
            sides.append(value);
        } else {
            return b.const_bool(op == Tok.NE);
        }
    }
    return self.compare_values(op, sides[0], sides[1], left_nd);
}

impl MirLowering.compare_values(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    if op in (Tok.KW_IS, Tok.KW_ISN, Tok.EE, Tok.NE)
        and MirKind.NONE in (left.type.kind, right.type.kind) {
        other = right if left.type.kind == MirKind.NONE else left;
        absent = self.is_absent(other);
        return absent
            if op in (Tok.KW_IS, Tok.EE)
            else self.builder().logical_not(absent);
    }
    special = self.compare_special(op, left, right, site);
    if special is not None {
        return special;
    }
    if op in (Tok.KW_IS, Tok.KW_ISN) {
        same = self.identity(left, right, site);
        return same if op == Tok.KW_IS else self.builder().logical_not(same);
    }
    if op in (Tok.KW_IN, Tok.KW_NIN)
        and right.type.kind == MirKind.OPT
        and mir_is_container(right.type.payload()) {
        right = self.opt_unwrap_checked(
            right, "argument of type 'NoneType' is not iterable"
        );
    }
    if op in (Tok.KW_IN, Tok.KW_NIN) {
        found = self.text_contains(left, right, site)
            if self.is_text(right) or self.is_byte_seq(right)
            else self.contains(left, right, site);
        return found if op == Tok.KW_IN else self.builder().logical_not(found);
    }
    name = COMPARE_OPERATORS.get(op);
    if name is None {
        raise MirRefused(mir_refusal("comparison", op, site));
    }
    if MirKind.ANY in (left.type.kind, right.type.kind) {
        return self.any_compare(name, left, right, site);
    }
    if name in ("eq", "ne") and MirKind.OPT in (left.type.kind, right.type.kind) {
        same = self.optional_eq(left, right, site);
        return same if name == "eq" else self.builder().logical_not(same);
    }
    if self.is_text(left) and self.is_text(right) {
        (left, right) = self.text_operands(left, right);
        return self.str_compare(name, left, right);
    }
    if self.is_byte_seq(left) and self.is_byte_seq(right) {
        (left_data, left_len) = self.byte_parts(self.spill(left));
        (right_data, right_len) = self.byte_parts(self.spill(right));
        order = self.call_rt(
            "__jac_rt_str_cmp", [left_data, left_len, right_data, right_len]
        );
        return self.builder().compare(
            name, order, self.builder().const_int(0, order.type)
        );
    }
    if left.type.kind == MirKind.TUPLE and right.type.kind == MirKind.TUPLE {
        return self.tuple_compare(op, name, left, right, site);
    }
    if mir_is_container(left.type) and name in ("eq", "ne") {
        same = self.container_eq(left, right);
        return same if name == "eq" else self.builder().logical_not(same);
    }
    if MirKind.C_PTR in (left.type.kind, right.type.kind)
        or MirKind.C_FN in (left.type.kind, right.type.kind) {
        words: list[MirValue] = [];
        for side in (left, right) {
            if side.type.kind in (MirKind.C_PTR, MirKind.C_FN) {
                words.append(
                    self.emit_value(MirOp.PTR_INT, mir_int(64, False), [side])
                );
            } elif side.type.kind in (MirKind.INT, MirKind.BOOL) {
                words.append(self.builder().convert(side, mir_int(64, False)));
            } else {
                raise MirRefused(
                    mir_refusal(
                        "comparison",
                        f"{left.type.render()} {op} {right.type.render()}",
                        site
                    )
                );
            }
        }
        return self.builder().compare(name, words[0], words[1]);
    }
    if name in ("eq", "ne")
        and left.type.kind in (MirKind.OBJ, MirKind.OSP)
        and right.type.kind in (MirKind.OBJ, MirKind.OSP) {
        return self.object_compare(name, left, right, site);
    }
    if self.value_comparable(left, right, name) {
        return self.any_compare(name, left, right, site);
    }
    if not left.type.is_numeric() or not right.type.is_numeric() {
        raise MirRefused(
            mir_refusal(
                "comparison", f"{left.type.render()} {op} {right.type.render()}", site
            )
        );
    }
    (l, r) = self.unify_numeric(left, right, site);
    return self.builder().compare(name, l, r);
}

impl MirLowering.lower_unary(nd: uni.UnaryExpr) -> MirValue {
    b = self.builder();
    op = nd.op.name;
    if op == Tok.NOT {
        return b.logical_not(self.condition(nd.operand));
    }
    if is_borrow_kind(nd.ownership) or nd.ownership == OwnershipKind.OWN {
        return self.lower_expr(nd.operand);
    }
    if nd.ownership is not None and int(nd.ownership.value) in (1, 4) {
        held = self.lower_expr(nd.operand);
        if int(nd.ownership.value) == 1 and self.is_text(held) {
            text = self.spill(self.as_text(held));
            return self.owned_text(
                self.call_rt(
                    "__jac_rt_str_new",
                    [b.str_part(text, "data"), b.str_part(text, "len")]
                )
            );
        }
        return held;
    }
    if op == Tok.MINUS {
        inner: uni.UniNode = nd.operand;
        while isinstance(inner, uni.AtomUnit) {
            inner = inner.value;
        }
        if isinstance(inner, uni.Int)
            and uni.int_literal_value(inner.value) == 1 << 63 {
            dest = self.literal_destination(inner);
            shape = shape_of(dest) if dest else None;
            wanted = self.expr_type(nd) if nd.type is not None else mir_int();
            if (shape is None or not shape.is_float)
                and wanted.kind == MirKind.INT
                and wanted.signed
                and wanted.width == 64 {
                return b.const_int(-(1 << 63), wanted);
            }
        }
    }
    value = self.enum_as_int(self.lower_expr(nd.operand), nd);
    if op == Tok.BW_AND and mir_holds_ref(value.type) {
        return value;
    }
    if value.type.kind == MirKind.ANY and op in ANY_UNARY_CODES {
        return self.any_from_box(
            self.runtime_value(
                "__jac_rt_any_unary",
                [b.const_int(ANY_UNARY_CODES[op], mir_int())]
                + self.any_parts(value)
            )
        );
    }
    if not value.type.is_numeric() {
        raise MirRefused(
            mir_refusal("unary operator", f"{op} on {value.type.render()}", nd)
        );
    }
    if op == Tok.PLUS {
        if value.type.kind == MirKind.BOOL {
            return b.convert(value, mir_int());
        }
        return value;
    }
    if op == Tok.MINUS {
        if value.type.kind == MirKind.FLOAT {
            return b.negate(value);
        }
        operand = b.convert(value, mir_int())
            if value.type.kind == MirKind.BOOL
            else value;
        zero = b.const_int(0, operand.type);
        self.raise_if(
            b.overflows("sub", zero, operand), "OverflowError", OVERFLOW_MESSAGE
        );
        return b.binary("sub", zero, operand);
    }
    if op == Tok.BW_NOT and value.type.kind != MirKind.FLOAT {
        operand = b.convert(value, mir_int())
            if value.type.kind == MirKind.BOOL
            else value;
        return b.binary("xor", operand, b.const_int(-1, operand.type));
    }
    raise MirRefused(mir_refusal("unary operator", op, nd));
}

impl MirLowering.condition_only(nd: uni.Expr) -> bool {
    current: uni.UniNode = nd;
    parent = nd.parent;
    while isinstance(parent, (uni.AtomUnit, uni.CfgExpr)) {
        current = parent;
        parent = parent.parent;
    }
    if isinstance(
        parent, (uni.IfStmt, uni.WhileStmt, uni.IfElseExpr, uni.AssertStmt)
    ) {
        return parent.condition is current;
    }
    if isinstance(parent, uni.UnaryExpr) {
        return parent.op.name == Tok.NOT;
    }
    if isinstance(parent, uni.InnerCompr) {
        return any(cond is current for cond in list(parent.conditional or []));
    }
    if isinstance(parent, uni.BoolExpr) {
        return self.condition_only(parent);
    }
    return False;
}

impl MirLowering.lower_bool(nd: uni.BoolExpr) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    tested = self.condition_only(nd);
    result_type = mir_bool() if tested else self.expr_type(nd);
    result = self.temp_slot(result_type);
    done = fn.new_block("bool.done");
    is_and = nd.op.name == Tok.KW_AND;
    values = list(nd.values);
    for (index, operand_nd) in enumerate(values) {
        operand = self.lower_expr(operand_nd);
        if tested {
            verdict = self.truthy(operand, operand_nd);
            b.store(result, verdict);
            if index + 1 < len(values) {
                more = fn.new_block("bool.next");
                if is_and {
                    b.cond_branch(verdict, more, done);
                } else {
                    b.cond_branch(verdict, done, more);
                }
                b.position(more);
            } else {
                b.branch(done);
            }
            continue;
        }
        if index + 1 < len(values) {
            keep = fn.new_block("bool.keep");
            more = fn.new_block("bool.next");
            verdict = self.truthy(operand, operand_nd);
            if is_and {
                b.cond_branch(verdict, more, keep);
            } else {
                b.cond_branch(verdict, keep, more);
            }
            b.position(keep);
            kept = operand;
            if not is_and
                and operand.type.kind == MirKind.OPT
                and result_type.kind not in (MirKind.OPT, MirKind.ANY) {
                kept = self.opt_get(operand);
            }
            b.store(result, self.coerce(kept, result_type, operand_nd));
            b.branch(done);
            b.position(more);
        } else {
            b.store(result, self.coerce(operand, result_type, operand_nd));
            b.branch(done);
        }
    }
    b.position(done);
    return b.load(result, result_type);
}

impl MirLowering.lower_call(nd: uni.FuncCall) -> MirValue {
    via_alias = self.alias_call(nd);
    if via_alias is not None {
        return via_alias;
    }
    if isinstance(nd.target, uni.Name)
        and nd.target.value in ("Region", "region_of")
        and (
            nd.target.sym is None
            or nd.target.sym.decl is None
            or nd.target.sym.decl.loc.mod_path.endswith(".pyi")
        )
        and (
            nd.target.value == "region_of" or self.expr_type(nd).kind == MirKind.REGION
        ) {
        regional = self.region_builtin(nd, nd.target.value);
        if regional is not None {
            return regional;
        }
    }
    if isinstance(nd.target, uni.Name)
        and INTRINSIC_REGISTRY.is_intrinsic(nd.target.value) {
        return self.intrinsic_call(nd, nd.target.value);
    }
    if is_builtin_addressof_call(nd) {
        return self.c_addressof(nd);
    }
    if is_builtin_pin_call(nd) {
        return self.c_pin(nd);
    }
    if isinstance(nd.target, uni.AtomTrailer)
        and nd.target.is_attr
        and isinstance(nd.target.target, uni.SpecialVarRef)
        and nd.target.target.value == "super"
        and isinstance(nd.target.right, uni.Name) {
        return self.super_call(nd, nd.target.right.value);
    }
    callee = nd.callee_decl;
    if callee is not None
        and contextmanager_ability(callee)
        and self.manager_item is not nd {
        raise MirRefused(
            mir_refusal(
                "call",
                f"@contextmanager {self.name_of(callee)} outside a with item"
                    if isinstance(callee, uni.Ability)
                    else "@contextmanager call outside a with item",
                nd,
                "A native @contextmanager generator is entered only as a with item."
            )
        );
    }
    if isinstance(nd.target, uni.Name)
        and nd.target.value == "cast"
        and (callee is None or callee.loc.mod_path.endswith(".pyi"))
        and len(self.call_args(nd)) == 2 {
        value = self.lower_expr(self.call_args(nd)[1]);
        wanted = self.expr_type(nd);
        return value if value.type is wanted else self.coerce(value, wanted, nd);
    }
    if isinstance(callee, uni.Ability) and self.template_of(callee) {
        owner = callee.find_parent_of_type(uni.Archetype);
        if owner is not None
            and not callee.is_static
            and isinstance(nd.target, uni.AtomTrailer)
            and nd.target.is_attr {
            via_method = self.method_call(nd, nd.target);
            if via_method is not None {
                return via_method;
            }
        }
        return self.generic_call(nd, callee, None, None);
    }
    if isinstance(callee, uni.Ability) and clib_import_of(callee) is not None {
        return self.c_call(nd, callee);
    }
    decl = self.decls.get(id(callee)) if callee is not None else None;
    if decl is None and isinstance(callee, uni.Ability) and callee.is_static {
        decl = self.foreign_static_decl(callee);
    }
    if decl is not None
        and decl.self_type is not None
        and isinstance(nd.target, uni.AtomTrailer)
        and nd.target.is_attr {
        via_method = self.method_call(nd, nd.target);
        if via_method is not None {
            return via_method;
        }
        if not self.is_class_operand(nd.target.target) {
            if decl.owner is not None
                and isinstance(nd.target.right, uni.Name)
                and isinstance(nd.target.target, uni.Expr) {
                via_owner = self.object_method(
                    nd,
                    self.lower_expr(nd.target.target),
                    decl.owner,
                    nd.target.right.value
                );
                if via_owner is not None {
                    return via_owner;
                }
            }
            raise MirRefused(
                mir_refusal(
                    "call",
                    f"method {self.name_of(decl.ability)} on {self.expr_type(
                        nd.target.target
                    ).render()}",
                    nd,
                    "The receiver's archetype is not statically known, so the method cannot be dispatched natively."
                )
            );
        }
    }
    if decl is not None and decl.c_variadic and decl.self_type is None {
        given = self.call_args(nd);
        if len(given) < len(decl.params) {
            raise MirRefused(
                mir_refusal(
                    "call",
                    f"{self.name_of(decl.ability)} with {len(given)} arguments",
                    nd
                )
            );
        }
        va_values = [
            self.coerce(self.lower_expr(va_arg), va_type, va_arg)
            for (va_arg, va_type) in zip(given, decl.params)
        ]
            + [self.c_vararg(va_arg) for va_arg in given[len(decl.params):]];
        va_result = self.builder().call(decl.symbol, va_values, decl.ret);
        if va_result is None {
            return self.builder().const_bool(False);
        }
        return va_result;
    }
    if decl is not None {
        args: list[MirValue] = [];
        params = self.bound_args(nd, decl.ability, decl.self_type is not None);
        if len(params) != len(decl.params) {
            raise MirRefused(
                mir_refusal(
                    "call",
                    f"{self.name_of(decl.ability)} with {len(params)} arguments",
                    nd
                )
            );
        }
        args.extend(self.bound_values(list(params), decl.params));
        result = self.builder().call(decl.symbol, args, decl.ret);
        if result is None {
            return self.builder().const_bool(False);
        }
        return result;
    }
    enum_made = self.enum_call(nd);
    if enum_made is not None {
        return enum_made;
    }
    if isinstance(callee, uni.Archetype) {
        return self.object_call(nd, callee);
    }
    if callee is None
        and isinstance(nd.target, uni.Expr)
        and isinstance(nd.target.type, ClassType)
        and not nd.target.type.is_instance() {
        constructed = self.arch_of_type(nd.target.type);
        if constructed is not None {
            return self.object_call(nd, constructed);
        }
    }
    if not isinstance(callee, (uni.Archetype, uni.Ability))
        and isinstance(nd.target, uni.Name)
        and nd.target.value == "type"
        and isinstance(nd.target.type, ClassType)
        and nd.target.type.is_builtin("type")
        and len(list(nd.params or [])) == 1
        and isinstance(list(nd.params or [])[0], uni.Expr) {
        return self.class_of(self.lower_expr(list(nd.params or [])[0]), nd);
    }
    if not isinstance(callee, (uni.Archetype, uni.Ability))
        and isinstance(nd.target, uni.Expr)
        and isinstance(nd.target.type, ClassType)
        and nd.target.type.is_builtin("type") {
        bound = self.class_bound(nd.target.type);
        if bound is None {
            raise MirRefused(
                mir_refusal(
                    "call",
                    f"construction through {nd.target.type}",
                    nd,
                    "Construction through a class value binds its arguments against the class's bound; annotate it as type[A] for an archetype A."
                )
            );
        }
        return self.class_value_call(nd, bound);
    }
    if isinstance(callee, uni.Ability) {
        imported = self.import_call(nd, callee);
        if imported is not None {
            return imported;
        }
    }
    name = self.call_name(nd);
    if isinstance(nd.target, uni.Name)
        and name.startswith("wrapping_")
        and callee is not None
        and os.path.basename(callee.loc.mod_path) == "jac_builtins.pyi" {
        return self.wrapping_call(nd, name, self.call_args(nd));
    }
    if isinstance(nd.target, uni.Name) and self.builtin_callee(callee) {
        builtin = self.builtin_call(nd, name);
        if builtin is not None {
            return builtin;
        }
    }
    if isinstance(nd.target, uni.Name) and INTRINSIC_REGISTRY.is_intrinsic(name) {
        return self.intrinsic_call(nd, name);
    }
    target = nd.target;
    if isinstance(target, uni.AtomTrailer) and target.is_attr {
        via_stdlib = self.stdlib_call(nd, target);
        if via_stdlib is not None {
            return via_stdlib;
        }
        via_method = self.method_call(nd, target);
        if via_method is not None {
            return via_method;
        }
    }
    if isinstance(target, uni.Expr)
        and isinstance(target.type, FunctionType)
        and self.expr_type(target).kind == MirKind.FN {
        return self.closure_call(nd, self.callee_value(target));
    }
    if isinstance(target, uni.Expr)
        and isinstance(target.type, FunctionType)
        and self.expr_type(target).kind == MirKind.C_FN {
        fnptr = self.lower_expr(target);
        fp_params = fnptr.type.args[1:];
        fp_args = self.call_args(nd);
        if len(fp_args) != len(fp_params) {
            raise MirRefused(
                mir_refusal(
                    "call", f"C function pointer with {len(fp_args)} arguments", nd
                )
            );
        }
        fp_values = [
            self.coerce(self.lower_expr(fp_arg), fp_type, fp_arg)
            for (fp_arg, fp_type) in zip(fp_args, fp_params)
        ];
        fp_ret = fnptr.type.args[0];
        fp_result = mir_none()
            if fp_ret.kind in (MirKind.NONE, MirKind.VOID)
            else fp_ret;
        return self.emit_value(MirOp.CALL_FNPTR, fp_result, [fnptr] + fp_values);
    }
    via_type = self.type_call(nd);
    if via_type is not None {
        return via_type;
    }
    if isinstance(target, uni.Expr)
        and target.type is not None
        and not isinstance(target.type, OverloadedType) {
        target_type = self.expr_type(target);
        if target_type.kind == MirKind.FN {
            return self.closure_call(nd, self.callee_value(target));
        }
    }
    bridged = self.python_call(nd);
    if bridged is not None {
        return bridged;
    }
    raise MirRefused(mir_refusal("call", name or type(target).__name__, nd));
}

impl MirLowering.truthy(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    if value.type.kind == MirKind.BOOL {
        return value;
    }
    if value.type.kind == MirKind.INT {
        return b.compare("ne", value, b.const_int(0, value.type));
    }
    if value.type.kind == MirKind.FLOAT {
        return b.compare("ne", value, b.const_float(0.0, value.type));
    }
    if value.type.kind in (MirKind.C_PTR, MirKind.C_FN, MirKind.REGION) {
        address = self.emit_value(MirOp.PTR_INT, mir_int(64, False), [value]);
        return b.compare("ne", address, b.const_int(0, address.type));
    }
    if self.is_text(value) {
        size = b.str_part(self.as_text(value), "len");
        return b.compare("ne", size, b.const_int(0, size.type));
    }
    if self.is_byte_seq(value) {
        size = self.byte_len(value);
        return b.compare("ne", size, b.const_int(0, size.type));
    }
    if mir_is_container(value.type) {
        size = self.container_len(value);
        return b.compare("ne", size, b.const_int(0, size.type));
    }
    if value.type.kind == MirKind.NONE {
        return b.const_bool(False);
    }
    if value.type.kind == MirKind.TUPLE {
        return b.const_bool(len(value.type.args) > 0);
    }
    if value.type.kind == MirKind.OPT {
        (held, payload, absent, done) = self.opt_begin(value, mir_bool());
        self.opt_switch(held, self.truthy(payload, site), absent, done);
        return self.opt_end(held, b.const_bool(False), done);
    }
    verdict = self.value_truthy(value, site);
    if verdict is not None {
        return verdict;
    }
    raise MirRefused(mir_refusal("truth test", value.type.render(), site));
}

impl MirLowering.coerce(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue {
    if value.type is to {
        return value;
    }
    if to.kind == MirKind.ANY or value.type.kind == MirKind.ANY {
        return self.any_box(value, site)
            if to.kind == MirKind.ANY
            else self.any_unbox(value, to, site);
    }
    if value.type.kind == MirKind.C_FN
        and to.kind == MirKind.FN
        and value.id in self.fn_values {
        return self.function_value(self.fn_values[value.id], to);
    }
    if MirKind.ENUM in (value.type.kind, to.kind)
        and MirKind.OPT not in (value.type.kind, to.kind) {
        return self.enum_coerce(value, to, site);
    }
    if to.kind == MirKind.ITER {
        return self.iter_coerce(value, to, site);
    }
    if to.kind == MirKind.OPT {
        if value.type.kind == MirKind.NONE {
            return self.builder().const_null(to);
        }
        if value.type.kind == MirKind.OPT {
            return self.opt_recast(value, to, site);
        }
        return self.opt_wrap(self.coerce(value, to.payload(), site), to);
    }
    if value.type.kind == MirKind.TUPLE
        and to.kind == MirKind.TUPLE
        and len(value.type.args) == len(to.args) {
        held = self.spill(value);
        return self.emit_value(
            MirOp.TUPLE_MAKE,
            to,
            [
                self.coerce(self.tuple_get(held, index), member, site)
                for (index, member) in enumerate(to.args)
            ]
        );
    }
    if value.type.kind == MirKind.OPT and value.type.payload() is to {
        return self.opt_get(value);
    }
    if value.type.kind == MirKind.OPT
        and to.kind not in (MirKind.OPT, MirKind.OPT_REF, MirKind.ANY, MirKind.NONE)
        and value.type.payload().kind != MirKind.OBJ {
        return self.coerce(
            self.opt_unwrap_checked(
                value, f"expected {to.render()}, got None", "TypeError"
            ),
            to,
            site
        );
    }
    if value.type.kind == MirKind.OPT
        and value.type.payload().kind == MirKind.OBJ
        and to.kind == MirKind.OBJ {
        return self.coerce(
            self.opt_unwrap_checked(
                value, f"expected {to.render()}, got None", "TypeError"
            ),
            to,
            site
        );
    }
    positioned = self.text_position(value, to);
    if positioned is not None {
        return positioned;
    }
    if value.type.is_numeric() and to.is_numeric() {
        return self.builder().convert(value, to);
    }
    if to.kind == MirKind.C_FN and value.type.kind == MirKind.FN {
        raise MirRefused(
            mir_refusal(
                "function pointer",
                f"{value.type.render()} as {to.render()}",
                site,
                "A C function pointer is the address of a named function; a Jac function value (a closure, or one read from a field or optional) has no C entry point."
            )
        );
    }
    if to.kind == MirKind.C_PTR and value.type.kind == MirKind.BOOL {
        return self.emit_value(
            MirOp.PTR_CAST, to, [self.builder().convert(value, mir_int())]
        );
    }
    if to.kind in (MirKind.C_PTR, MirKind.C_FN)
        and value.type.kind in (MirKind.C_PTR, MirKind.C_FN, MirKind.INT) {
        return self.emit_value(MirOp.PTR_CAST, to, [value]);
    }
    if to.kind == MirKind.INT and value.type.kind in (MirKind.C_PTR, MirKind.C_FN) {
        return self.emit_value(MirOp.PTR_INT, to, [value]);
    }
    if to.kind == MirKind.FN
        and value.type.kind == MirKind.INT
        and self.const_zero(value) {
        return self.builder().const_null(to);
    }
    if to.kind == MirKind.INT and value.type.kind == MirKind.FN {
        return self.emit_value(MirOp.PTR_INT, to, [value]);
    }
    if to.kind == MirKind.FN
        and value.type.kind == MirKind.FN
        and len(to.args) == len(value.type.args) {
        return self.closure_adapter(value, to, site);
    }
    if value.type.kind == MirKind.OBJ
        and to.kind == MirKind.OBJ
        and (
            self.obj_extends(value.type.name, to.name)
            or self.obj_extends(to.name, value.type.name)
        ) {
        return self.builder().ref_cast(value, to, False);
    }
    if value.type.kind == MirKind.OBJ and to.kind == MirKind.OBJ {
        return self.checked_cross_cast(value, to, site);
    }
    if mir_is_container(value.type) and to.kind == MirKind.OBJ {
        b = self.builder();
        b.raise_builtin(
            "TypeError", f"a {value.type.render()} is not a {to.render()} instance"
        );
        b.position(self.st().fn.new_block("cast.dead"));
        return b.const_null(to);
    }
    if value.type.kind == MirKind.CLASS and to.kind == MirKind.CLASS {
        return self.emit_value(MirOp.PTR_CAST, to, [value]);
    }
    if mir_is_container(to) and value.type.kind == to.kind {
        return self.container_rebuild(value, to, site);
    }
    if to.kind == MirKind.TUPLE
        and value.type.kind == MirKind.TUPLE
        and len(to.args) == len(value.type.args) {
        held = self.spill(value);
        members = [
            self.coerce(self.tuple_get(held, index), member, site)
            for (index, member) in enumerate(to.args)
        ];
        return self.emit_value(MirOp.TUPLE_MAKE, to, members);
    }
    if to.kind == MirKind.LIST and value.type.kind == MirKind.TUPLE {
        held = self.spill(value);
        made = self.spill(self.new_list(to.payload(), len(value.type.args)));
        for index in range(len(value.type.args)) {
            self.container_add(made, self.tuple_get(held, index), site);
        }
        return made;
    }
    raise MirRefused(
        mir_refusal("conversion", f"{value.type.render()} to {to.render()}", site)
    );
}

impl MirLowering.adopt_imported_layouts(target: (uni.Module | None) = None) {
    home = target or self.module;
    if id(home) in self.layout_owners {
        return;
    }
    self.layout_owners.add(id(home));
    merged: set[int] = {id(home)};
    evaluator = self.prog.get_type_evaluator();
    for arch in [
        elem
        for elem in home.body
        if isinstance(elem, uni.Archetype)
    ] {
        sym = arch.name.sym if arch.name is not None else None;
        made = evaluator.get_type_of_symbol(sym) if sym is not None else None;
        if not isinstance(made, ClassType) or made._shared is None {
            continue;
        }
        for ancestor in made.shared.mro {
            scope = ancestor.shared.symbol_table
                if ancestor._shared is not None
                else None;
            if not isinstance(scope, uni.Archetype) {
                continue;
            }
            owner = scope.find_parent_of_type(uni.Module);
            if owner is None
                or id(owner) in merged
                or not owner.loc.mod_path.endswith(".jac") {
                continue;
            }
            merged.add(id(owner));
            merge_imported_layouts(home, owner, self.prog);
        }
    }
    registry = get_layout_registry(self.module, self.prog);
    hub = self.prog.mod.hub;
    grew = True;
    while grew {
        grew = False;
        for (name, paths) in list(registry.parent_mods.items()) {
            for path in paths {
                dep = hub.get(path) or hub.get(os.path.realpath(path))
                    if path
                    else None;
                if dep is None
                    or id(dep) in merged
                    or not dep.loc.mod_path.endswith(".jac") {
                    continue;
                }
                merged.add(id(dep));
                try {
                    merge_imported_layouts(self.module, dep, self.prog);
                    grew = True;
                } except RuntimeError {
                    continue;
                }
            }
        }
    }
    for name in list(registry.layouts) {
        registry.get_layout(name);
    }
    if len(merged) > 1 {
        adopt_imported_bases(home);
    }
}

impl MirLowering.obj_extends(child: str, base: str) -> bool {
    arch = self.archetypes.get(child);
    if arch is None {
        return False;
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    layout = get_layout_registry(owner, self.prog).get_layout(child);
    if layout is not None and base in list(layout.mro) {
        return True;
    }
    sym = arch.name.sym if arch.name is not None else None;
    made = self.prog.get_type_evaluator().get_type_of_symbol(sym)
        if sym is not None
        else None;
    if not isinstance(made, ClassType) or made._shared is None {
        return False;
    }
    return any(
        class_type_native_name(ancestor) == base for ancestor in made.shared.mro
    );
}

impl MirLowering.unify_numeric(
    left: MirValue, right: MirValue, site: uni.UniNode
) -> tuple[MirValue, MirValue] {
    b = self.builder();
    l = b.convert(left, mir_int()) if left.type.kind == MirKind.BOOL else left;
    r = b.convert(right, mir_int()) if right.type.kind == MirKind.BOOL else right;
    if l.type.kind == MirKind.FLOAT or r.type.kind == MirKind.FLOAT {
        wide = mir_float(64);
        return (b.convert(l, wide), b.convert(r, wide));
    }
    if l.type is not r.type
        and l.type.kind == MirKind.INT
        and r.type.kind == MirKind.INT {
        common = self.common_int(l.type, r.type, site);
        if common is not None {
            return (b.convert(l, common), b.convert(r, common));
        }
    }
    if l.type is not r.type {
        raise MirRefused(
            mir_refusal(
                "integer operator layout",
                f"{l.type.render()} vs {r.type.render()}",
                site
            )
        );
    }
    return (l, r);
}

impl MirLowering.common_int(
    left: MirType, right: MirType, site: uni.UniNode
) -> (MirType | None) {
    if isinstance(site, uni.Expr) and isinstance(site.type, ClassType) {
        wanted = self.expr_type(site);
        if wanted.kind == MirKind.INT {
            return wanted;
        }
    }
    if left.signed == right.signed {
        return left if left.width >= right.width else right;
    }
    unsigned = right if left.signed else left;
    signed = left if left.signed else right;
    if unsigned.width < 64 {
        return mir_int(64, True, signed.is_sized() or unsigned.is_sized());
    }
    return None;
}

impl MirLowering.raise_if(cond: MirValue, exception: str, message: str) {
    b = self.builder();
    fn = self.st().fn;
    raise_bb = fn.new_block(f"raise.{exception}");
    ok_bb = fn.new_block("ok");
    b.cond_branch(cond, raise_bb, ok_bb);
    b.position(raise_bb);
    b.raise_builtin(exception, message);
    b.position(ok_bb);
}

impl MirLowering.name_of(ab: uni.Ability) -> str {
    name_ref = ab.name_ref;
    if name_ref is None {
        raise MirRefused(mir_refusal("function", "anonymous", ab));
    }
    return name_ref.sym_name;
}

impl MirLowering.ability_sym(ab: uni.Ability) -> uni.Symbol {
    name_ref = ab.name_ref;
    if name_ref is None or name_ref.sym is None {
        raise MirRefused(mir_refusal("function", "unresolved", ab));
    }
    return name_ref.sym;
}

impl MirLowering.type_of(
    t: (TypeBase | None), position: MirPosition, site: uni.UniNode
) -> MirType {
    self.ensure_c_types(t);
    if self.host_only_type(t) {
        return mir_any();
    }
    made = mir_type_of(t, position, site, self.type_env or None);
    self.ensure_objects(t);
    if made.kind == MirKind.ENUM and isinstance(t, ClassType) {
        self.enum_types.setdefault(made.name, t);
    } elif made.kind == MirKind.ENUM
        and isinstance(t, EnumMemberType)
        and t.enum_class is not None {
        self.enum_types.setdefault(made.name, t.enum_class.clone_as_instance());
    }
    return made;
}

impl MirLowering.ensure_objects(t: (TypeBase | None)) {
    if isinstance(t, FunctionType) {
        for param in t.parameters {
            self.ensure_objects(param.param_type);
        }
        self.ensure_objects(t.return_type);
        return;
    }
    if isinstance(t, UnionType) {
        for member in t.types {
            self.ensure_objects(member);
        }
        return;
    }
    if not isinstance(t, ClassType) or t._shared is None {
        return;
    }
    if t.private and t.private.type_args {
        for arg in t.private.type_args {
            self.ensure_objects(arg);
        }
    }
    scope = t.shared.symbol_table;
    if not isinstance(scope, uni.Archetype) or is_enum_class_type(t) {
        return;
    }
    if self.host_only_type(t) {
        return;
    }
    name = class_type_native_name(t);
    if name and name not in self.mir.objects and not stub_archetype(scope) {
        self.object_def(scope);
    }
}

impl MirLowering.ensure_c_types(t: (TypeBase | None)) {
    if t is None {
        return;
    }
    if isinstance(t, FunctionType) {
        for param in t.parameters {
            self.ensure_c_types(param.param_type);
        }
        self.ensure_c_types(t.return_type);
        return;
    }
    if isinstance(t, UnionType) {
        for member in t.types {
            self.ensure_c_types(member);
        }
        return;
    }
    kind = c_builtin_kind(t);
    if kind in ("ptr", "PtrView", "Pinned") {
        self.ensure_c_types(c_type_arg(t));
        return;
    }
    arch = self.c_struct_of(t);
    if arch is None {
        if isinstance(t, ClassType) and t.private and t.private.type_args {
            for arg in t.private.type_args {
                self.ensure_c_types(arg);
            }
        }
        return;
    }
    name = arch.name.value;
    site = f"{arch.loc.mod_path}:{arch.loc.first_line}:{arch.loc.col_start}";
    held = self.c_struct_sites.get(name);
    if held is not None {
        if held != site and not self.c_struct_same(arch, name) {
            raise MirRefused(
                mir_refusal(
                    "C struct",
                    name,
                    arch,
                    f"Another C struct named {name} is declared at {held}; one module "
                    "can use only one C struct of a name."
                )
            );
        }
        return;
    }
    self.c_struct_sites[name] = site;
    made = MirStructDef(name=name);
    self.mir.structs[name] = made;
    evaluator = self.prog.get_type_evaluator();
    for hv in self.arch_fields(arch) {
        sym = hv.name.sym;
        if sym is None {
            raise MirRefused(mir_refusal("C struct field", hv.name.value, hv));
        }
        field_type = evaluator.get_type_of_symbol(sym);
        self.ensure_c_types(field_type);
        self.ensure_objects(field_type);
        made.fields.append(
            MirStructField(
                name=hv.name.value,
                type=mir_type_of(field_type, MirPosition.C_FIELD, hv)
            )
        );
    }
}

impl MirLowering.c_struct_same(arch: uni.Archetype, name: str) -> bool {
    known = self.mir.structs.get(name);
    if known is None {
        return False;
    }
    fields = self.arch_fields(arch);
    if len(fields) != len(known.fields) {
        return False;
    }
    evaluator = self.prog.get_type_evaluator();
    for (hv, member) in zip(fields, known.fields) {
        sym = hv.name.sym;
        if sym is None or hv.name.value != member.name {
            return False;
        }
        if mir_type_of(evaluator.get_type_of_symbol(sym), MirPosition.C_FIELD, hv)
            is not member.type {
            return False;
        }
    }
    return True;
}

impl MirLowering.arch_fields(arch: uni.Archetype) -> list[uni.HasVar] {
    found: list[uni.HasVar] = [];
    body = arch.body;
    if not isinstance(body, (list, tuple)) {
        return found;
    }
    for stmt in body {
        if isinstance(stmt, uni.ArchHas) and not stmt.is_static {
            for hv in stmt.vars {
                found.append(hv);
            }
        }
    }
    return found;
}

impl MirLowering.runtime(name: str, args: list[MirValue]) -> (MirValue | None) {
    (params, ret) = mir_runtime_signature(name);
    self.mir.externs[name] = MirExtern(symbol=name, ret=ret, params=params);
    values = [
        self.builder().convert(arg, param)
            if arg.type.is_numeric() and param.is_numeric()
            else arg for (arg, param) in zip(args, params)
    ];
    return self.builder().call_runtime(name, values, ret);
}

impl MirLowering.temp_slot(type: MirType) -> MirValue {
    fn = self.st().fn;
    made = fn.new_value(type, "tmp");
    made.is_slot = True;
    made.is_temp = True;
    if type.kind != MirKind.NONE {
        fn.blocks[0].instrs.insert(
            0, MirInstr(op=MirOp.SLOT, result=made, type_arg=type)
        );
    }
    return made;
}

impl MirLowering.spill(value: MirValue) -> MirValue {
    if not value.owned or not mir_holds_ref(value.type) {
        return value;
    }
    slot = self.temp_slot(value.type);
    self.builder().store(slot, value);
    return self.builder().load(slot, slot.type);
}

impl MirLowering.bound_values(
    args: list[any], params: list[MirType]
) -> list[MirValue] {
    return [self.bound_value(arg, ptype) for (arg, ptype) in zip(args, params)];
}

impl MirLowering.lower_string(nd: (uni.String | uni.MultiString)) -> MirValue {
    literal = self.bytes_literal(nd);
    if literal is not None {
        return literal;
    }
    parts = nd.strings if isinstance(nd, uni.MultiString) else [nd];
    result: (MirValue | None) = None;
    for part in parts {
        piece: MirValue;
        if isinstance(part, uni.FString) {
            piece = self.lower_fstring(part);
        } elif isinstance(part, uni.String) and isinstance(part.lit_value, str) {
            piece = self.builder().const_str(part.lit_value, mir_str());
        } else {
            raise MirRefused(mir_refusal("expression", type(part).__name__, part));
        }
        result = piece if result is None else self.str_concat(result, piece);
    }
    if result is None {
        return self.builder().const_str("", mir_str());
    }
    return result;
}

impl MirLowering.str_concat(left: MirValue, right: MirValue) -> MirValue {
    b = self.builder();
    left_len = b.str_part(left, "len");
    right_len = b.str_part(right, "len");
    joined = self.runtime(
        "__jac_rt_str_concat",
        [b.str_part(left, "data"), left_len, b.str_part(right, "data"), right_len]
    );
    if joined is None {
        raise MirRefused(mir_refusal("string", "concatenation"));
    }
    return b.str_make(joined, joined, b.binary("add", left_len, right_len));
}

impl MirLowering.str_compare(op: str, left: MirValue, right: MirValue) -> MirValue {
    b = self.builder();
    order = self.runtime(
        "__jac_rt_str_cmp",
        [
            b.str_part(left, "data"),
            b.str_part(left, "len"),
            b.str_part(right, "data"),
            b.str_part(right, "len")
        ]
    );
    if order is None {
        raise MirRefused(mir_refusal("string", "comparison"));
    }
    return b.compare(op, order, b.const_int(0, order.type));
}

impl MirLowering.builtin_call(nd: uni.FuncCall, name: str) -> (MirValue | None) {
    if name in ("take", "swap") {
        return self.place_exchange(nd, name);
    }
    if name == "print" {
        return self.lower_print(nd);
    }
    if name == "input" {
        return self.input_call(nd);
    }
    if name == "open" {
        return self.open_call(nd);
    }
    if name == "new" and nd.params {
        made = list(nd.params);
        kind = made[0];
        arch = self.class_reference(kind) if isinstance(kind, uni.Expr) else None;
        if arch is not None {
            return self.object_call(nd, arch, 1);
        }
    }
    if name == "int" {
        refused = self.str_enum_int(nd);
        if refused is not None {
            return refused;
        }
    }
    textual = self.text_builtin(nd, name);
    if textual is not None {
        return textual;
    }
    if any(isinstance(arg, uni.KWPair) for arg in list(nd.params or [])) {
        if name == "sorted" {
            return self.iter_builtin(nd, name);
        }
        if name in ("min", "max") {
            return self.extreme_named(nd, name);
        }
        return None;
    }
    args = self.call_args(nd);
    if name == "len" and len(args) == 1 {
        value = self.as_text(self.lower_expr(args[0]));
        if value.type.kind == MirKind.STR {
            b = self.builder();
            counted = self.runtime(
                "__jac_rt_str_len",
                [
                    b.str_part(value, "root"),
                    b.str_part(value, "data"),
                    b.str_part(value, "len")
                ]
            );
            if counted is not None {
                return counted;
            }
        }
        if value.type.kind == MirKind.OPT and mir_is_container(value.type.payload()) {
            value = self.opt_unwrap_checked(
                value, "object of type 'NoneType' has no len()"
            );
        }
        if mir_is_container(value.type) {
            return self.container_len(value);
        }
        if value.type.kind == MirKind.TUPLE {
            return self.builder().const_int(len(value.type.args), mir_int());
        }
        if value.type.kind == MirKind.C_VIEW {
            return self.emit_value(MirOp.VIEW_LEN, mir_int(), [value]);
        }
        if value.type.kind == MirKind.ANY {
            held = self.spill(value);
            return self.runtime_value(
                "__jac_rt_any_len",
                [
                    self.emit_value(MirOp.ANY_TAG, mir_int(), [held]),
                    self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [held])
                ]
            );
        }
        raise MirRefused(mir_refusal("call", f"len of {value.type.render()}", nd));
    }
    if name == "isinstance" and len(args) == 2 {
        return self.isinstance_value(args[0], args[1], nd);
    }
    if name.startswith("wrapping_") {
        return self.wrapping_call(nd, name, args);
    }
    found = self.builtin_value(nd, name);
    if found is None {
        found = self.iter_builtin(nd, name);
    }
    return found if found is not None else self.value_builtin(nd, name);
}

impl MirLowering.to_str(value: MirValue, site: uni.UniNode) -> MirValue {
    return self.str_value(value, site);
}

impl MirLowering.lower_fstring(nd: uni.FString) -> MirValue {
    return self.fstring_value(nd);
}

impl MirLowering.lower_if_else_expr(nd: uni.IfElseExpr) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    result_type = self.expr_type(nd);
    held = self.temp_slot(result_type);
    then = fn.new_block("sel.then");
    otherwise = fn.new_block("sel.else");
    done = fn.new_block("sel.done");
    b.cond_branch(self.condition(nd.condition), then, otherwise);
    b.position(then);
    b.store(held, self.coerce(self.lower_expr(nd.value), result_type, nd.value));
    b.branch(done);
    b.position(otherwise);
    b.store(
        held, self.coerce(self.lower_expr(nd.else_value), result_type, nd.else_value)
    );
    b.branch(done);
    b.position(done);
    return b.load(held, result_type);
}

impl MirLowering.lower_for(nd: uni.InForStmt) {
    target = nd.target;
    if not isinstance(target, uni.Name) or target.sym is None or target.type is None {
        self.lower_for_core(nd);
        return;
    }
    element = self.expr_type(target);
    declared = self.symbol_type(target.sym, target);
    if element is declared
        or element.kind != MirKind.OBJ
        or declared.kind != MirKind.OBJ
        or self.obj_extends(element.name, declared.name)
        or self.obj_extends(declared.name, element.name) {
        self.lower_for_core(nd);
        return;
    }
    key = id(target.sym);
    previous = self.st().locals.get(key);
    self.st().locals[key] = self.temp_slot(element);
    try {
        self.lower_for_core(nd);
    } finally {
        if previous is None {
            self.st().locals.pop(key, None);
        } else {
            self.st().locals[key] = previous;
        }
    }
}

impl MirLowering.lower_for_core(nd: uni.InForStmt) {
    source = nd.collection;
    if isinstance(source, uni.FuncCall)
        and isinstance(source.target, uni.Name)
        and source.target.value == "range" {
        callee = source.callee_decl;
        if self.builtin_callee(callee) {
            bounds = self.call_args(source);
            if 1 <= len(bounds) <= 3 {
                self.lower_range_for(nd, bounds);
                return;
            }
        }
    }
    if self.is_special_source(source) {
        self.lower_for_sources(nd, None);
        return;
    }
    if isinstance(source, uni.TupleVal) and not source.values {
        after = self.st().fn.new_block("each.exit");
        self.lower_else(nd.else_body, after);
        self.builder().position(after);
        return;
    }
    holder = self.lower_expr(source);
    if self.is_text(holder) or self.is_byte_seq(holder) {
        self.lower_for_text(nd, holder);
        return;
    }
    if mir_is_container(holder.type) and isinstance(nd.target, uni.Name) {
        self.lower_for_container(nd, holder);
        return;
    }
    self.lower_for_sources(nd, holder);
}

impl MirLowering.lower_range_for(nd: uni.InForStmt, bounds: list[uni.Expr]) {
    b = self.builder();
    fn = self.st().fn;
    if not isinstance(nd.target, uni.Name) {
        raise MirRefused(mir_refusal("statement", "for target", nd.target));
    }
    values = [
        self.coerce(self.lower_expr(bound), mir_int(), bound) for bound in bounds
    ];
    start = b.const_int(0, mir_int());
    step = b.const_int(1, mir_int());
    stop = values[0];
    if len(values) >= 2 {
        start = values[0];
        stop = values[1];
    }
    if len(values) == 3 {
        step = values[2];
        self.raise_if(
            b.compare("eq", step, b.const_int(0, mir_int())),
            "ValueError",
            RANGE_STEP_MESSAGE
        );
    }
    limit = self.temp_slot(mir_int());
    stride = self.temp_slot(mir_int());
    current = self.temp_slot(mir_int());
    b.store(limit, stop);
    b.store(stride, step);
    b.store(current, start);
    head = fn.new_block("for.head");
    body = fn.new_block("for.body");
    advance = fn.new_block("for.step");
    otherwise = fn.new_block("for.else");
    after = fn.new_block("for.exit");
    b.branch(head);
    b.position(head);
    now = b.load(current, mir_int());
    end = b.load(limit, mir_int());
    pace = b.load(stride, mir_int());
    upward = b.compare("gt", pace, b.const_int(0, mir_int()));
    more = b.select(upward, b.compare("lt", now, end), b.compare("gt", now, end));
    b.cond_branch(more, body, otherwise);
    b.position(body);
    self.store_name(nd.target, now);
    self.st().loops.append(MirLoopTarget(head=advance, after=after));
    self.lower_body(nd.body);
    self.st().loops.pop();
    if not self.builder().block.terminated() {
        self.builder().branch(advance);
    }
    b.position(advance);
    was = b.load(current, mir_int());
    by_now = b.load(stride, mir_int());
    store_next = fn.new_block("for.next");
    b.cond_branch(b.overflows("add", was, by_now), otherwise, store_next);
    b.position(store_next);
    b.store(current, b.binary("add", was, by_now));
    b.branch(head);
    b.position(otherwise);
    self.lower_else(nd.else_body, after);
    b.position(after);
}

impl MirLowering.lower_print(nd: uni.FuncCall) -> MirValue {
    return self.print_call(nd);
}

impl MirLowering.emit_value(
    op: MirOp,
    type: MirType,
    operands: list[MirValue],
    sub: str = "",
    callee: str = "",
    int_value: int = 0,
    str_value: str = ""
) -> MirValue {
    result = self.st().fn.new_value(type);
    self.builder().emit(
        MirInstr(
            op=op,
            result=result,
            operands=operands,
            sub=sub,
            callee=callee,
            int_value=int_value,
            str_value=str_value,
            type_arg=type
        )
    );
    return result;
}

impl MirLowering.place_elem(place: MirValue) -> MirType {
    if place.is_slot {
        return place.type;
    }
    if place.type.kind != MirKind.C_PTR {
        raise RuntimeError(f"MIR place {place.render()} is not addressable");
    }
    return place.type.payload();
}

impl MirLowering.lower_place(nd: uni.UniNode) -> MirValue {
    if isinstance(nd, uni.Name) {
        if nd.sym is not None and id(nd.sym) not in self.st().locals {
            place = self.global_place(nd);
            if place is not None {
                return place;
            }
        }
        if nd.sym is None or id(nd.sym) not in self.st().locals {
            raise MirRefused(mir_refusal("place", nd.value, nd));
        }
        return self.st().locals[id(nd.sym)];
    }
    if isinstance(nd, uni.AtomUnit) {
        return self.lower_place(nd.value);
    }
    if not isinstance(nd, uni.AtomTrailer) {
        raise MirRefused(mir_refusal("place", type(nd).__name__, nd));
    }
    if nd.is_attr {
        right = nd.right;
        if not isinstance(right, uni.Name) {
            raise MirRefused(mir_refusal("attribute", type(right).__name__, nd));
        }
        target_type = nd.target.type if isinstance(nd.target, uni.Expr) else None;
        if isinstance(target_type, ModuleType) and right.sym is not None {
            imported = self.global_place(right);
            if imported is not None {
                return imported;
            }
        }
        if right.value == "value" and is_pinned_type(target_type) {
            box = self.lower_expr(nd.target);
            return self.emit_value(
                MirOp.PTR_CAST, mir_c_ptr(box.type.payload()), [box]
            );
        }
        arch = self.holder_arch(nd.target) if isinstance(nd.target, uni.Expr) else None;
        if arch is not None {
            subject = self.lower_expr(nd.target);
            owner = self.member_owner(right);
            if owner is not None
                and owner is not arch
                and owner.loc.mod_path.endswith(".jac")
                and self.obj_extends(
                    self.object_type(owner).name, self.object_type(arch).name
                ) {
                arch = owner;
            }
            derived = self.archetypes.get(subject.type.name)
                if subject.type.kind == MirKind.OBJ
                else None;
            if derived is not None
                and derived is not arch
                and self.obj_extends(subject.type.name, self.object_type(arch).name) {
                arch = derived;
            }
            wanted = self.object_type(arch);
            if subject.type.kind == MirKind.OBJ
                and wanted.kind == MirKind.OBJ
                and wanted is not subject.type
                and self.obj_extends(wanted.name, subject.type.name) {
                subject = self.builder().ref_cast(subject, wanted, False);
            }
            return self.field_place(subject, arch, right.value, nd);
        }
        members = self.union_archetypes(target_type);
        if members {
            return self.union_field_place(
                self.lower_expr(nd.target), members, right.value, nd
            );
        }
        if isinstance(nd.target, uni.Name)
            and nd.target.sym is not None
            and id(nd.target.sym) in self.st().locals {
            slot_type = self.st().locals[id(nd.target.sym)].type;
            if slot_type.kind == MirKind.OPT {
                slot_type = slot_type.payload();
            }
            if slot_type.kind == MirKind.OBJ and slot_type.name in self.archetypes {
                held = self.lower_expr(nd.target);
                if held.type is slot_type {
                    return self.field_place(
                        held, self.archetypes[slot_type.name], right.value, nd
                    );
                }
            }
        }
        if isinstance(target_type, UnionType) {
            held = self.lower_expr(nd.target);
            if held.type.kind == MirKind.OPT
                and held.type.payload().kind == MirKind.OBJ {
                b = self.builder();
                held = self.spill(held);
                missing = self.st().fn.new_block("attr.none");
                present = self.st().fn.new_block("attr.some");
                b.cond_branch(self.opt_present(held), present, missing);
                b.position(missing);
                b.raise_builtin(
                    "AttributeError",
                    f"'NoneType' object has no attribute '{right.value}'"
                );
                b.position(present);
                held = self.opt_get(held);
            }
            if held.type.kind == MirKind.OBJ and held.type.name in self.archetypes {
                return self.field_place(
                    held, self.archetypes[held.type.name], right.value, nd
                );
            }
            raise MirRefused(mir_refusal("attribute access", held.type.render(), nd));
        }
        base = self.struct_temp_place(nd.target)
            if isinstance(nd.target, uni.FuncCall)
            else self.lower_place(nd.target);
        holder = self.place_elem(base);
        if holder.kind != MirKind.C_STRUCT {
            raise MirRefused(mir_refusal("attribute access", holder.render(), nd));
        }
        layout = self.mir.structs[holder.name];
        if not any(member.name == right.value for member in layout.fields) {
            raise MirRefused(
                mir_refusal(
                    "C struct field",
                    f"{holder.name}.{right.value}",
                    nd,
                    f"The C struct {holder.name} this module lays out (declared at {self.c_struct_sites.get(
                        holder.name, '?'
                    )}) has no field {right.value}."
                )
            );
        }
        index = layout.index_of(right.value);
        return self.emit_value(
            MirOp.FIELD_ADDR,
            mir_c_ptr(layout.fields[index].type),
            [self.coerce_place(base)],
            int_value=index
        );
    }
    right = nd.right;
    if not isinstance(right, uni.IndexSlice)
        or right.is_range
        or len(right.slices) != 1 {
        raise MirRefused(mir_refusal("subscript", type(right).__name__, nd));
    }
    view = self.lower_expr(nd.target);
    if view.type.kind != MirKind.C_VIEW {
        hint: (str | None) = None;
        if view.type.kind == MirKind.LIST and view.type.payload().kind == MirKind.ANY {
            hint = "The element type is `any`, so native code has no layout to read it through; filter the edge reference with `[?:Type]` or annotate the list so the element has a known type.";
        }
        raise MirRefused(mir_refusal("subscript", view.type.render(), nd, hint));
    }
    start = right.slices[0].start;
    if start is None {
        raise MirRefused(mir_refusal("subscript", "missing index", nd));
    }
    position = self.lower_expr(start);
    if position.type.kind != MirKind.INT {
        raise MirRefused(mir_refusal("subscript index", position.type.render(), nd));
    }
    b = self.builder();
    length = self.emit_value(MirOp.VIEW_LEN, mir_int(), [view]);
    position = b.convert(position, mir_int());
    position = b.select(
        b.compare("lt", position, b.const_int(0, mir_int())),
        b.binary("add", position, length),
        position
    );
    below = b.compare("lt", position, b.const_int(0, position.type));
    beyond = b.compare("ge", position, length);
    self.raise_if(below, "IndexError", "PtrView index out of range");
    self.raise_if(beyond, "IndexError", "PtrView index out of range");
    return self.emit_value(
        MirOp.ELEM_ADDR, mir_c_ptr(view.type.payload()), [view, position]
    );
}

impl MirLowering.lower_trailer(nd: uni.AtomTrailer) -> MirValue {
    if isinstance(nd.right, uni.FilterCompr) {
        return self.lower_osp_filter(nd);
    }
    via_str = self.str_subscript(nd);
    if via_str is not None {
        return via_str;
    }
    via_sys = self.sys_attr(nd);
    if via_sys is not None {
        return via_sys;
    }
    special = self.attr_special(nd);
    if special is not None {
        return special;
    }
    via_accessor = self.accessor_get(nd);
    if via_accessor is not None {
        return via_accessor;
    }
    via_class_attr = self.instance_class_attr(nd);
    if via_class_attr is not None {
        return via_class_attr;
    }
    if not nd.is_attr
        and isinstance(nd.right, uni.IndexSlice)
        and isinstance(nd.target, uni.Expr)
        and (
            self.expr_type(nd.target).kind == MirKind.TUPLE
            or (
                self.expr_type(nd.target).kind == MirKind.OPT
                and self.expr_type(nd.target).payload().kind == MirKind.TUPLE
            )
        ) {
        slices = nd.right.slices;
        start = slices[0].start if len(slices) == 1 and not nd.right.is_range else None;
        folded = start.ct_value if isinstance(start, uni.Expr) else None;
        whole = int_host(folded) if isinstance(folded, CtInt) else None;
        if whole is None {
            raise MirRefused(
                mir_refusal("subscript", "tuple index that is not a constant", nd)
            );
        }
        held_tuple = self.lower_expr(nd.target);
        if held_tuple.type.kind == MirKind.OPT {
            held_tuple = self.opt_unwrap_checked(
                held_tuple, "'NoneType' object is not subscriptable", "TypeError"
            );
        }
        return self.tuple_get(held_tuple, whole);
    }
    if not nd.is_attr and isinstance(nd.right, uni.IndexSlice) {
        target_type = self.expr_type(nd.target)
            if isinstance(nd.target, uni.Expr)
            else mir_void();
        if mir_is_container(target_type) or target_type.kind == MirKind.ANY {
            got = self.container_get(self.lower_expr(nd.target), nd.right, nd);
            wanted = self.expr_type(nd);
            if got.type.kind == MirKind.ANY and wanted.kind != MirKind.ANY {
                return self.any_unbox(got, wanted, nd);
            }
            return got;
        }
        if target_type.kind == MirKind.OPT
            and mir_is_container(target_type.payload()) {
            return self.container_get(
                self.opt_unwrap_checked(
                    self.lower_expr(nd.target), "'NoneType' object is not subscriptable"
                ),
                nd.right,
                nd
            );
        }
        if target_type.kind
            in (MirKind.STR, MirKind.STR_REF, MirKind.BYTES, MirKind.BYTEARRAY) {
            return self.text_subscript(self.lower_expr(nd.target), nd.right, nd);
        }
    }
    via_union = self.union_field_read(nd);
    if via_union is not None {
        return via_union;
    }
    place = self.lower_place(nd);
    loaded = self.builder().load(place, self.place_elem(place));
    if nd.is_attr
        and loaded.type.kind == MirKind.ANY
        and not (
            isinstance(nd.type, TypeVarType) and nd.type.name not in self.type_env
        ) {
        wanted = self.expr_type(nd);
        if wanted.kind != MirKind.ANY {
            return self.any_unbox(loaded, wanted, nd);
        }
    }
    return self.narrowed_load(loaded, nd);
}

impl MirLowering.call_name(nd: uni.FuncCall) -> str {
    target = nd.target;
    if isinstance(target, uni.Name) {
        return target.value;
    }
    if isinstance(target, uni.AtomTrailer) and isinstance(target.right, uni.Name) {
        return target.right.value;
    }
    return "";
}

impl MirLowering.call_args(nd: uni.FuncCall) -> list[uni.Expr] {
    args: list[uni.Expr] = [];
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) {
            raise MirRefused(mir_refusal("call argument", "keyword", arg));
        }
        args.append(arg);
    }
    return args;
}

impl MirLowering.c_extern(
    callee: uni.Ability, site: uni.UniNode
) -> tuple[str, list[tuple[MirType, str]], MirType, str, bool] {
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(
        self.ability_sym(callee)
    );
    sig = callee.signature;
    symbol = self.name_of(callee);
    if not isinstance(fn_type, FunctionType)
        or not isinstance(sig, uni.FuncSignature) {
        raise MirRefused(mir_refusal("C call", symbol, site));
    }
    declared = sig.get_parameters();
    fixed = [
        pv
        for pv in declared
        if not (pv.is_vararg or pv.is_kwargs)
    ];
    variadic = any(pv.is_vararg for pv in declared);
    fallbacks = [p.param_type for p in fn_type.parameters];
    plans = [
        self.c_param_plan(
            pv,
            fallbacks[declared.index(pv)]
                if declared.index(pv) < len(fallbacks)
                else None,
            site
        ) for pv in fixed
    ];
    (ret, ret_plan) = self.c_return_plan(sig, fn_type.return_type, site);
    self.ensure_objects(fn_type);
    self.note_clib(clib_import_of(callee));
    owner = callee.find_parent_of_type(uni.Module);
    if owner is not None
        and owner is not self.module
        and owner.loc.mod_path.endswith(".jac")
        and isinstance(callee.body, list)
        and callee.body {
        unit = os.path.realpath(owner.loc.mod_path);
        if unit not in self.mir.deps {
            self.mir.deps.append(unit);
        }
    }
    self.mir.externs[symbol] = MirExtern(
        symbol=symbol,
        ret=ret,
        params=[plan[0] for plan in plans],
        variadic=variadic,
        c_abi=True
    );
    return (symbol, plans, ret, ret_plan, variadic);
}

impl MirLowering.mark_threaded {
    flag_type = mir_int(8, False);
    if RC_THREADED_FLAG not in self.mir.globals {
        self.mir.globals[RC_THREADED_FLAG] = MirGlobal(
            name=RC_THREADED_FLAG,
            symbol=RC_THREADED_FLAG,
            type=flag_type,
            linkage="external"
        );
    }
    place = self.emit_value(
        MirOp.GLOBAL_ADDR, mir_c_ptr(flag_type), [], str_value=RC_THREADED_FLAG
    );
    self.emit_value(
        MirOp.ATOMIC_STORE,
        mir_none(),
        [place, self.builder().const_int(1, flag_type)],
        str_value="monotonic"
    );
}

impl MirLowering.c_call(nd: uni.FuncCall, callee: uni.Ability) -> MirValue {
    (symbol, plans, ret, ret_plan, variadic) = self.c_extern(callee, nd);
    sig = callee.signature;
    args: list[any] = [];
    given = list(nd.params or []);
    if isinstance(sig, uni.FuncSignature)
        and sig.varargs is None
        and sig.kwargs is None
        and (
            any(isinstance(arg, uni.KWPair) for arg in given) or len(given) < len(plans)
        ) {
        args = list(self.bound_args(nd, callee, False));
        for arg in args {
            if not isinstance(arg, (uni.Expr, MirBound)) {
                raise MirRefused(
                    mir_refusal("C call", f"{symbol} argument binding", nd)
                );
            }
        }
    } else {
        args = self.call_args(nd);
    }
    if len(args) < len(plans) or (len(args) > len(plans) and not variadic) {
        raise MirRefused(
            mir_refusal("C call", f"{symbol} with {len(args)} arguments", nd)
        );
    }
    copybacks: list[tuple[MirValue, MirValue, MirType]] = [];
    values: list[MirValue] = [];
    for (index, arg) in enumerate(args) {
        if isinstance(arg, MirBound) {
            values.append(self.coerce(arg.value, plans[index][0], arg.site));
        } elif index < len(plans) {
            values.append(self.c_arg(arg, plans[index][0], plans[index][1], copybacks));
        } else {
            values.append(self.c_vararg(arg));
        }
    }
    result_type = mir_none() if ret.kind in (MirKind.NONE, MirKind.VOID) else ret;
    if symbol == "pthread_create" {
        self.mark_threaded();
    }
    result = self.emit_value(MirOp.CALL_C, result_type, values, callee=symbol);
    if mir_holds_ref(result_type) {
        result.owned = True;
    }
    b = self.builder();
    for (tmp, place, held) in copybacks {
        b.store(place, self.coerce(b.load(tmp, tmp.type), held, nd));
    }
    if ret_plan == "str" {
        text = self.call_rt("__jac_rt_str_from_cstr", [result]);
        return self.owned_text(text);
    }
    return result;
}

impl MirLowering.c_extern_address(nd: uni.Name) -> (MirValue | None) {
    held: (uni.UniNode | None) = nd.sym.decl if nd.sym is not None else None;
    hops = 0;
    while held is not None and not isinstance(held, uni.Ability) and hops < 3 {
        held = held.parent;
        hops += 1;
    }
    if not isinstance(held, uni.Ability) or clib_import_of(held) is None {
        return None;
    }
    (symbol, plans, ret, ret_plan, variadic) = self.c_extern(held, nd);
    shape = mir_c_fn(
        [plan[0] for plan in plans],
        mir_none() if ret.kind in (MirKind.NONE, MirKind.VOID) else ret
    );
    return self.emit_value(MirOp.FN_ADDR, shape, [], callee=symbol);
}

impl MirLowering.import_call(
    nd: uni.FuncCall, callee: uni.Ability
) -> (MirValue | None) {
    callee = self.variant_ability(callee);
    path = callee.loc.mod_path;
    if not isinstance(callee.parent, uni.Module)
        or not path.endswith(".jac")
        or os.path.realpath(path) == os.path.realpath(self.module.loc.mod_path) {
        return None;
    }
    if self.template_of(callee) {
        return self.generic_call(nd, callee, None, None);
    }
    decl = self.foreign_function_decl(callee, nd);
    (symbol, params, ret) = (decl.symbol, decl.params, decl.ret);
    args = self.bound_args(nd, callee, False);
    if len(args) != len(params) {
        raise MirRefused(
            mir_refusal("call", f"{symbol} with {len(args)} arguments", nd)
        );
    }
    values = self.bound_values(list(args), params);
    result = self.builder().call(symbol, values, ret);
    if result is None {
        return self.builder().const_bool(False);
    }
    return result;
}

impl MirLowering.foreign_function_decl(
    callee: uni.Ability, site: uni.UniNode
) -> MirDecl {
    known = self.decls.get(id(callee));
    if known is not None {
        return known;
    }
    path = callee.loc.mod_path;
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(
        self.ability_sym(callee)
    );
    if not isinstance(fn_type, FunctionType) {
        raise MirRefused(mir_refusal("call", self.name_of(callee), site));
    }
    sig = self.ability_sig(callee);
    params = [self.symbol_type(pv.name.sym, pv) for pv in self.param_nodes(sig, False)]
        if sig is not None
        else [
            self.type_of(p.param_type, MirPosition.VALUE, site)
            for p in fn_type.parameters
        ];
    ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, site);
    symbol = self.unit_symbol(self.name_of(callee), callee.access, path);
    self.require_dep_native(path, symbol, site);
    self.mir.externs[symbol] = MirExtern(symbol=symbol, ret=ret, params=params);
    unit = os.path.realpath(path);
    if unit not in self.mir.deps {
        self.mir.deps.append(unit);
    }
    self.imported_fns[self.name_of(callee)] = (unit, symbol);
    made = MirDecl(ability=callee, symbol=symbol, params=params, ret=ret);
    self.decls[id(callee)] = made;
    return made;
}

impl MirLowering.require_dep_native(path: str, symbol: str, site: uni.UniNode) {
    unit = os.path.realpath(path);
    prefix = native_unit_prefix(path) + ".";
    name = symbol[len(prefix):] if symbol.startswith(prefix) else symbol;
    if unit not in self.dep_verdicts {
        iface = active_host().native_dep_iface(self.prog, unit, self.prog.options);
        self.dep_verdicts[unit] = list(iface.demoted) if iface is not None else None;
    }
    demoted = self.dep_verdicts[unit];
    if demoted is None {
        if unit in self.prog.native_units().building
            or active_host().native_dep_discovery_open(self.prog) {
            return;
        }
        raise MirRefused(
            mir_refusal(
                "function",
                name,
                site,
                f"{os.path.basename(
                    path
                )} did not lower to a native unit, so native code cannot call '{name}'; it runs in Python."
            )
        );
    }
    if name in demoted {
        raise MirRefused(
            mir_refusal(
                "function",
                name,
                site,
                f"'{name}' was demoted to Python in {os.path.basename(
                    path
                )}, so native code cannot call it."
            )
        );
    }
}

impl MirLowering.rc_intrinsic(name: str) -> (MirValue | None) {
    b = self.builder();
    debug = bool(self.prog.options.rc_debug_codegen);
    if name in ("__rc_debug_enable", "__rc_debug_disable") {
        if debug {
            self.runtime(
                "__jac_rt_rc_debug_set", [b.const_bool(name == "__rc_debug_enable")]
            );
        } elif name == "__rc_debug_enable" {
            self.write_value(
                b.const_str(RC_DEBUG_OFF_NOTICE + "\n", mir_str()), 2, self.module
            );
            self.runtime("__jac_rt_flush", [b.const_int(2, mir_int())]);
        }
        return self.none_value();
    }
    hooks = {
        "__rc_gc_disable": "__jac_rt_gc_disable",
        "__rc_gc_enable": "__jac_rt_gc_enable",
        "__rc_collect_cycles": "__jac_rt_collect_cycles"
    };
    if name in hooks {
        self.runtime(hooks[name], []);
        return self.none_value();
    }
    return None;
}

impl MirLowering.intrinsic_call(nd: uni.FuncCall, name: str) -> MirValue {
    args = self.call_args(nd);
    rc_hook = self.rc_intrinsic(name);
    if rc_hook is not None {
        return rc_hook;
    }
    if name == "__global_block" {
        label = c_string_literal(args[0]) if args else None;
        (ok, size) = c_scalar_constant(args[1]) if len(args) == 2 else (False, None);
        if not label or not ok or not isinstance(size, int) or size <= 0 {
            raise MirRefused(
                mir_refusal(
                    "intrinsic",
                    name,
                    nd,
                    "The block is named by a string literal and sized by a positive constant.",
                    "E5095"
                )
            );
        }
        self.mir.global_blocks[label] = max(self.mir.global_blocks.get(label, 0), size);
        return self.emit_value(
            MirOp.GLOBAL_BLOCK, mir_int(64), [], str_value=label, int_value=size
        );
    }
    if name == "__mem_call_dtor" {
        target = self.intrinsic_operand(args[0], "i64");
        subject = self.intrinsic_operand(args[1], "i64");
        return self.emit_value(MirOp.CALL_DTOR, mir_none(), [target, subject]);
    }
    if name == "__alloca" and len(args) == 1 {
        return self.c_alloca(args[0]);
    }
    if name in ("__thread_local", "__c_thread_local") {
        return self.c_thread_local(nd, name, args);
    }
    if name == "__thread_local_block" {
        label = c_string_literal(args[0]) if args else None;
        (ok, size) = c_scalar_constant(args[1]) if len(args) == 2 else (False, None);
        if not label or not ok or not isinstance(size, int) or size <= 0 {
            raise MirRefused(
                mir_refusal(
                    "intrinsic",
                    name,
                    nd,
                    "The block is named by a string literal and sized by a positive constant.",
                    "E5095"
                )
            );
        }
        self.mir.tls_blocks[label] = max(self.mir.tls_blocks.get(label, 0), size);
        return self.emit_value(
            MirOp.TLS_BLOCK, mir_int(64), [], str_value=label, int_value=size
        );
    }
    found = INTRINSIC_REGISTRY.get(name);
    if found is None or len(args) != found.arity() {
        raise MirRefused(mir_refusal("intrinsic", name, nd, code="E5095"));
    }
    dispatch = found.dispatch;
    result_type = mir_spec_type(found.result_spec);
    if dispatch == IntrinsicDispatch.REGION_TLS {
        if name == "__jac_region_gbl_get" {
            self.mir.global_blocks["__jac_region_gbl"] = max(
                self.mir.global_blocks.get("__jac_region_gbl", 0), 64
            );
            return self.emit_value(
                MirOp.GLOBAL_BLOCK,
                mir_int(64),
                [],
                str_value="__jac_region_gbl",
                int_value=64
            );
        }
        self.mir.tls_blocks["__jac_region_tls"] = max(
            self.mir.tls_blocks.get("__jac_region_tls", 0), 8
        );
        cell = self.emit_value(
            MirOp.TLS_BLOCK, mir_int(64), [], str_value="__jac_region_tls", int_value=8
        );
        if name == "__jac_region_tls_get" {
            return self.emit_value(MirOp.MEM_LOAD, mir_int(64, True, True), [cell]);
        }
        stored = self.intrinsic_operand(args[0], "i64");
        return self.emit_value(MirOp.MEM_STORE, mir_none(), [cell, stored]);
    }
    if dispatch == IntrinsicDispatch.EXC_LONGJMP {
        buffer = self.intrinsic_operand(args[0], "i64");
        return self.emit_value(MirOp.LONGJMP, mir_none(), [buffer]);
    }
    if dispatch == IntrinsicDispatch.MEM_LOAD {
        address = self.intrinsic_operand(args[0], "i64");
        return self.emit_value(MirOp.MEM_LOAD, result_type, [address]);
    }
    if dispatch == IntrinsicDispatch.MEM_STORE {
        address = self.intrinsic_operand(args[0], "i64");
        value = self.intrinsic_operand(args[1], found.param_specs[1]);
        return self.emit_value(MirOp.MEM_STORE, mir_none(), [address, value]);
    }
    if dispatch in (IntrinsicDispatch.FLOAT_BITS, IntrinsicDispatch.BITS_FLOAT) {
        value = self.intrinsic_operand(args[0], found.param_specs[0]);
        return self.emit_value(MirOp.BITCAST, result_type, [value]);
    }
    if dispatch == IntrinsicDispatch.RC_RUNTIME {
        rt_name = {
            "__rc_gc_disable": "__jac_rt_gc_disable",
            "__rc_gc_enable": "__jac_rt_gc_enable",
            "__rc_collect_cycles": "__jac_rt_collect_cycles"
        }.get(
            name, ""
        );
        if rt_name {
            self.runtime(rt_name, []);
        }
        return self.none_value();
    }
    if dispatch == IntrinsicDispatch.BUFFER_DATA {
        held = self.spill(self.lower_expr(args[0]));
        if held.type.kind not in (MirKind.BYTES, MirKind.BYTEARRAY) {
            raise MirRefused(
                mir_refusal("intrinsic", f"{name} of {held.type.render()}", nd)
            );
        }
        (data, _) = self.byte_parts(held);
        return self.emit_value(MirOp.PTR_INT, mir_int(), [data]);
    }
    if dispatch == IntrinsicDispatch.LIST_DATA {
        operand: uni.UniNode = args[0];
        while isinstance(operand, uni.AtomUnit) {
            operand = operand.value;
        }
        if not isinstance(operand, (uni.Name, uni.AtomTrailer))
            or (isinstance(operand, uni.AtomTrailer) and operand.is_null_ok) {
            raise MirRefused(
                mir_refusal(
                    "intrinsic",
                    f"{name} of a temporary list: a temporary list is freed with the statement",
                    nd,
                    "Bind the list to a variable, a field or an element first; a temporary list and its buffer are freed when the statement ends.",
                    "E5095"
                )
            );
        }
        held = self.spill(self.lower_expr(args[0]));
        if held.type.kind != MirKind.LIST {
            raise MirRefused(
                mir_refusal("intrinsic", f"{name} of {held.type.render()}", nd)
            );
        }
        if self.elem_kind(held.type.payload(), nd) not in (KIND_INT, KIND_FLOAT) {
            raise MirRefused(
                mir_refusal(
                    "intrinsic",
                    f"{name} of {held.type.render()}: the list holds managed elements",
                    nd,
                    "A raw store through the buffer would bypass the elements' reference counts, so only int and float lists qualify.",
                    "E5095"
                )
            );
        }
        return self.emit_value(
            MirOp.MEM_LOAD,
            mir_int(),
            [
                self.builder().binary(
                    "add",
                    self.address_of(held),
                    self.builder().const_int(16, mir_int())
                )
            ]
        );
    }
    if dispatch == IntrinsicDispatch.STR_DATA {
        text = self.spill(self.as_text(self.lower_expr(args[0])));
        return self.emit_value(
            MirOp.PTR_INT, mir_int(), [self.builder().str_part(text, "data")]
        );
    }
    if dispatch == IntrinsicDispatch.REF_ADDR {
        held = self.lower_expr(args[0]);
        if not mir_holds_ref(held.type) {
            raise MirRefused(
                mir_refusal("intrinsic", f"{name} of {held.type.render()}", nd)
            );
        }
        return self.address_of(self.spill(held));
    }
    if dispatch == IntrinsicDispatch.ATOMIC_FENCE {
        order = self.memory_order(nd, args[0], "fence");
        return self.emit_value(MirOp.FENCE, mir_none(), [], str_value=order);
    }
    if dispatch == IntrinsicDispatch.ATOMIC_XCHG {
        address = self.intrinsic_operand(args[0], "i64");
        value = self.intrinsic_operand(args[1], "i64");
        return self.emit_value(
            MirOp.ATOMIC_RMW,
            result_type,
            [address, value],
            sub="xchg",
            str_value="seq_cst"
        );
    }
    if dispatch == IntrinsicDispatch.ATOMIC_LOAD {
        address = self.intrinsic_operand(args[0], "i64");
        order = self.memory_order(nd, args[1], "load");
        return self.emit_value(
            MirOp.ATOMIC_LOAD, result_type, [address], str_value=order
        );
    }
    if dispatch == IntrinsicDispatch.ATOMIC_STORE {
        address = self.intrinsic_operand(args[0], "i64");
        value = self.intrinsic_operand(args[1], found.param_specs[1]);
        order = self.memory_order(nd, args[2], "store");
        return self.emit_value(
            MirOp.ATOMIC_STORE, mir_none(), [address, value], str_value=order
        );
    }
    if dispatch == IntrinsicDispatch.ATOMIC_CAS {
        address = self.intrinsic_operand(args[0], "i64");
        expected = self.intrinsic_operand(args[1], found.param_specs[1]);
        desired = self.intrinsic_operand(args[2], found.param_specs[2]);
        order = self.memory_order(nd, args[3], "rmw");
        return self.emit_value(
            MirOp.ATOMIC_CAS, result_type, [address, expected, desired], str_value=order
        );
    }
    if dispatch == IntrinsicDispatch.ATOMIC_RMW {
        address = self.intrinsic_operand(args[0], "i64");
        value = self.intrinsic_operand(args[1], found.param_specs[1]);
        order = self.memory_order(nd, args[2], "rmw");
        operation = name[len("__atomic_"):].rsplit("_i", 1)[0];
        return self.emit_value(
            MirOp.ATOMIC_RMW,
            result_type,
            [address, value],
            sub="xchg" if operation == "swap" else operation,
            str_value=order
        );
    }
    raise MirRefused(mir_refusal("intrinsic", name, nd));
}

impl MirLowering.intrinsic_operand(arg: uni.Expr, spec: str) -> MirValue {
    value = self.lower_expr(arg);
    if value.type.kind == MirKind.C_PTR and spec == "i64" {
        return self.emit_value(MirOp.PTR_INT, mir_int(64, True, True), [value]);
    }
    return self.coerce(value, mir_spec_type(spec), arg);
}

impl MirLowering.memory_order(nd: uni.FuncCall, arg: uni.Expr, kind: str) -> str {
    (ok, value) = c_scalar_constant(arg);
    if not ok
        or not isinstance(value, int)
        or value < 0
        or value >= len(MEMORY_ORDERS) {
        raise MirRefused(
            mir_refusal(
                "intrinsic",
                self.call_name(nd),
                arg,
                "The memory order is a constant from 0 (relaxed) to 5 (seq_cst).",
                "E5095"
            )
        );
    }
    order = MEMORY_ORDERS[value];
    if (kind == "load" and order in ("release", "acq_rel"))
        or (kind == "store" and order in ("acquire", "acq_rel")) {
        raise MirRefused(
            mir_refusal(
                "intrinsic",
                self.call_name(nd),
                arg,
                f"A {kind} cannot use memory order {value}.",
                "E5095"
            )
        );
    }
    return order;
}

impl MirLowering.type_call(nd: uni.FuncCall) -> (MirValue | None) {
    result_type = self.expr_type(nd);
    if result_type.kind == MirKind.C_STRUCT
        and isinstance(nd.target, uni.Expr)
        and isinstance(nd.target.type, ClassType)
        and not nd.target.type.is_instance() {
        return self.c_struct_call(nd, result_type);
    }
    args = self.call_args(nd);
    if result_type.kind == MirKind.C_PTR {
        if not args {
            return self.emit_value(MirOp.PTR_NULL, result_type, []);
        }
        source = args[0];
        if isinstance(source, (uni.String, uni.MultiString)) {
            text = c_string_literal(source);
            if text is None {
                raise MirRefused(mir_refusal("C string", "not a literal", source));
            }
            return self.emit_value(MirOp.CSTR, result_type, [], str_value=text);
        }
        lent = self.c_borrow_operand(source);
        if lent is not None {
            return self.c_address(self.lower_place(lent), result_type);
        }
        value = self.lower_expr(source);
        if value.type.kind in (MirKind.INT, MirKind.C_PTR, MirKind.C_FN) {
            return self.emit_value(MirOp.PTR_CAST, result_type, [value]);
        }
        raise MirRefused(mir_refusal("pointer cast", value.type.render(), nd));
    }
    if result_type.is_numeric() and len(args) == 1 {
        value = self.lower_expr(args[0]);
        if value.type.kind == MirKind.OPT
            and (
                value.type.payload().is_numeric()
                or value.type.payload().kind == MirKind.ENUM
            ) {
            value = self.opt_unwrap_checked(
                value,
                f"{result_type.render()}() argument must be a string, a bytes-like object or a real number, not 'NoneType'"
            );
        }
        value = self.enum_as_int(value, args[0]);
        if value.type.kind in (MirKind.C_PTR, MirKind.C_FN)
            and result_type.kind == MirKind.INT {
            return self.emit_value(MirOp.PTR_INT, result_type, [value]);
        }
        if value.type.is_numeric() {
            return self.checked_cast(value, result_type, nd);
        }
    }
    return None;
}

impl MirLowering.method_call(
    nd: uni.FuncCall, target: uni.AtomTrailer
) -> (MirValue | None) {
    right = target.right;
    if not isinstance(right, uni.Name) {
        return None;
    }
    if isinstance(target.target, uni.SpecialVarRef)
        and target.target.value == "super" {
        return self.super_call(nd, right.value);
    }
    if isinstance(target.target, uni.FuncCall)
        and isinstance(target.target.target, uni.Name)
        and target.target.target.value == "super"
        and not list(target.target.params or []) {
        return self.super_call(nd, right.value);
    }
    if right.value == "wrap" and self.sized_type_name(target.target) is not None {
        return self.sized_wrap(nd, self.sized_type_name(target.target) or "");
    }
    if isinstance(target.target, uni.Name)
        and isinstance(target.target.type, ModuleType)
        and target.target.type.mod_name == "struct" {
        return self.struct_call(nd, right.value);
    }
    if isinstance(target.target, uni.Name)
        and isinstance(target.target.type, ModuleType)
        and target.target.type.mod_name == "copy"
        and right.value == "copy"
        and len(self.call_args(nd)) == 1 {
        value = self.lower_expr(self.call_args(nd)[0]);
        if value.type.kind == MirKind.OBJ {
            return self.object_copy(value, nd);
        }
        if value.type.kind in (MirKind.LIST, MirKind.SET) {
            made = self.spill(
                self.new_list(value.type.payload(), 4)
                    if value.type.kind == MirKind.LIST
                    else self.new_dict(value.type.payload(), None, value.type)
            );
            self.extend_from(made, self.spill(value), nd);
            return made;
        }
        if value.type.kind == MirKind.DICT {
            made = self.spill(
                self.new_dict(value.type.args[0], value.type.args[1], value.type)
            );
            self.merge_dict(made, self.spill(value), nd, False);
            return made;
        }
    }
    if isinstance(target.target, uni.Name)
        and isinstance(target.target.type, ModuleType)
        and target.target.type.mod_name == "sys"
        and right.value == "exit" {
        return self.sys_exit(nd);
    }
    if right.value == "bit_length"
        and not list(nd.params or [])
        and isinstance(target.target, uni.Expr)
        and self.expr_type(target.target).kind == MirKind.INT {
        b = self.builder();
        number = b.convert(self.lower_expr(target.target), mir_int());
        negative = b.compare("lt", number, b.const_int(0, mir_int()));
        magnitude = b.select(
            negative, b.binary("sub", b.const_int(0, mir_int()), number), number
        );
        self.mir.externs["llvm.ctlz.i64"] = MirExtern(
            symbol="llvm.ctlz.i64", ret=mir_int(), params=[mir_int(), mir_bool()]
        );
        zeros = self.emit_value(
            MirOp.CALL_C,
            mir_int(),
            [magnitude, b.const_bool(False)],
            callee="llvm.ctlz.i64"
        );
        return b.binary("sub", b.const_int(64, mir_int()), zeros);
    }
    if right.value in ("from_bytes", "to_bytes") {
        via_bytes = self.int_bytes_call(nd, target, right.value);
        if via_bytes is not None {
            return via_bytes;
        }
    }
    if isinstance(target.target, uni.Name)
        and target.target.value in ("bytes", "bytearray")
        and right.value == "fromhex" {
        made = self.builder().ref_cast(
            self.call_rt(
                "__jac_rt_bytes_fromhex",
                list(self.text_bytes(self.text_arg(self.call_args(nd)[0], nd)))
            ),
            mir_bytes(),
            True
        );
        return made if target.target.value == "bytes" else self.to_bytearray(made);
    }
    receiver_type = self.expr_type(target.target)
        if isinstance(target.target, uni.Expr)
        else mir_void();
    if mir_is_container(receiver_type) {
        return self.container_method(self.lower_expr(target.target), right.value, nd);
    }
    if receiver_type.kind == MirKind.FILE {
        return self.file_method(
            self.spill(self.lower_expr(target.target)), right.value, nd
        );
    }
    if receiver_type.kind
        in (MirKind.STR, MirKind.STR_REF, MirKind.BYTES, MirKind.BYTEARRAY) {
        return self.text_method(self.lower_expr(target.target), right.value, nd);
    }
    if receiver_type.kind == MirKind.ITER
        and right.value == "close"
        and not self.call_args(nd)
        and isinstance(target.target, uni.Expr)
        and isinstance(target.target.type, ClassType)
        and target.target.type.shared.class_name == "Generator" {
        return self.gen_close(self.lower_expr(target.target));
    }
    if receiver_type.kind == MirKind.INT
        and right.value in ("bit_length", "bit_count")
        and not self.call_args(nd) {
        return self.runtime_value(
            f"__jac_rt_int_{right.value}", [self.lower_expr(target.target)]
        );
    }
    if receiver_type.kind == MirKind.FLOAT
        and right.value == "is_integer"
        and not self.call_args(nd) {
        return self.runtime_value(
            "__jac_rt_float_is_integer", [self.lower_expr(target.target)]
        );
    }
    if receiver_type.kind == MirKind.ENUM {
        via_enum = self.enum_method_call(
            nd, self.lower_expr(target.target), right.value
        );
        if via_enum is not None {
            return via_enum;
        }
    }
    owner_arch = self.holder_arch(target.target)
        if isinstance(target.target, uni.Expr)
        else None;
    if owner_arch is None and isinstance(target.target, uni.Expr) {
        owner_arch = self.union_method_owner(nd, target.target);
    }
    if owner_arch is not None {
        if isinstance(target.target.type, ClassType)
            and not target.target.type.is_instance() {
            unbound = self.unbound_method(nd, owner_arch, right.value);
            if unbound is not None {
                return unbound;
            }
        }
        return self.object_method(
            nd, self.lower_expr(target.target), owner_arch, right.value
        );
    }
    if right.value == "arg"
        and isinstance(target.target, uni.Expr)
        and is_va_list_type(target.target.type) {
        return self.va_arg(nd, target.target);
    }
    if receiver_type.kind == MirKind.REGION
        and right.value == "partition"
        and not self.call_args(nd) {
        child = self.region_call(
            "__jac_region_partition", [self.lower_expr(target.target)]
        );
        return self.emit_value(MirOp.PTR_CAST, mir_region(), [child]);
    }
    if receiver_type.kind == MirKind.C_PTR {
        receiver = self.lower_expr(target.target);
        args = self.call_args(nd);
        if right.value == "view" and len(args) == 1 {
            count = self.lower_expr(args[0]);
            b = self.builder();
            address = self.emit_value(MirOp.PTR_INT, mir_int(64, False), [receiver]);
            self.raise_if(
                b.select(
                    b.compare("eq", address, b.const_int(0, address.type)),
                    b.compare(
                        "gt", b.convert(count, mir_int()), b.const_int(0, mir_int())
                    ),
                    b.const_bool(False)
                ),
                "ValueError",
                "cannot view elements of a null pointer"
            );
            return self.emit_value(
                MirOp.VIEW, mir_c_view(receiver.type.payload()), [receiver, count]
            );
        }
        if right.value == "is_null" and not args {
            address = self.emit_value(MirOp.PTR_INT, mir_int(64, False), [receiver]);
            return self.builder().compare(
                "eq", address, self.builder().const_int(0, address.type)
            );
        }
        return None;
    }
    if receiver_type.kind == MirKind.C_STRUCT {
        place = self.lower_place(target);
        field_type = self.place_elem(place);
        if field_type.kind != MirKind.C_FN {
            return None;
        }
        fnptr = self.builder().load(place, field_type);
        params = field_type.args[1:];
        args = self.call_args(nd);
        if len(args) != len(params) {
            raise MirRefused(
                mir_refusal("call", f"{right.value} with {len(args)} arguments", nd)
            );
        }
        values = [
            self.coerce(self.lower_expr(arg), ptype, arg)
            for (arg, ptype) in zip(args, params)
        ];
        ret = field_type.args[0];
        result_type = mir_none() if ret.kind in (MirKind.NONE, MirKind.VOID) else ret;
        return self.emit_value(MirOp.CALL_FNPTR, result_type, [fnptr] + values);
    }
    return None;
}

impl MirLowering.struct_temp_place(nd: uni.Expr) -> MirValue {
    value = self.lower_expr(nd);
    if value.type.kind != MirKind.C_STRUCT {
        raise MirRefused(mir_refusal("place", type(nd).__name__, nd));
    }
    held = self.temp_slot(value.type);
    self.builder().store(held, value);
    return held;
}

impl MirLowering.coerce_place(place: MirValue) -> MirValue {
    if not place.is_slot {
        return place;
    }
    return self.emit_value(MirOp.PTR_CAST, mir_c_ptr(place.type), [place]);
}

impl MirLowering.global_declaration(sym: uni.Symbol) -> (uni.Assignment | None) {
    child: (uni.UniNode | None) = sym.decl;
    if sym.imported {
        child = uni.resolved_decl_of(sym) or sym.decl;
    }
    cursor: (uni.UniNode | None) = child.parent if child is not None else None;
    while cursor is not None and not isinstance(cursor, uni.Assignment) {
        child = cursor;
        cursor = cursor.parent;
    }
    if isinstance(cursor, uni.Assignment)
        and isinstance(cursor.parent, uni.GlobalVars)
        and child is not cursor.value {
        return cursor;
    }
    if isinstance(cursor, uni.Assignment)
        and child is not cursor.value
        and self.entry_global(cursor, sym) {
        return cursor;
    }
    return None;
}

"""Is `sym`, bound by `assign`, a module global set by an entry block?

Python treats a top-level `with entry` assignment as module state, so a
function or lambda that reads the name reads it late-bound from the module.
A name only the entry block itself uses stays a local of the entry function.
"""
impl MirLowering.entry_global(assign: uni.Assignment, sym: uni.Symbol) -> bool {
    block = assign.parent;
    if not isinstance(block, uni.ModuleCode)
        or block.name is not None
        or not isinstance(block.parent, uni.Module) {
        return False;
    }
    owner = block.parent;
    key = id(owner);
    used = self.entry_globals.get(key);
    if used is None {
        used = set();
        for name in owner.get_all_sub_nodes(uni.Name) {
            held = name.sym;
            if held is None or id(held) in used {
                continue;
            }
            decl = held.decl;
            cursor: (uni.UniNode | None) = decl.parent if decl is not None else None;
            while cursor is not None and not isinstance(cursor, uni.Assignment) {
                cursor = cursor.parent;
            }
            if not isinstance(cursor, uni.Assignment)
                or not isinstance(cursor.parent, uni.ModuleCode)
                or cursor.parent.name is not None
                or cursor.parent.parent is not owner {
                continue;
            }
            if name.find_parent_of_type(uni.Ability) is not None
                or name.find_parent_of_type(uni.LambdaExpr) is not None {
                used.add(id(held));
            }
        }
        self.entry_globals[key] = used;
    }
    return id(sym) in used;
}

impl MirLowering.global_place(nd: uni.Name) -> (MirValue | None) {
    found = self.declare_global(nd);
    if found is None {
        return None;
    }
    if found.opaque or found.count >= 0 {
        raise MirRefused(
            mir_refusal(
                "C data object",
                found.name,
                nd,
                "An opaque C object or a C array is reached through its address: `addressof(name)`."
            )
        );
    }
    return self.emit_value(
        MirOp.GLOBAL_ADDR, mir_c_ptr(found.type), [], str_value=found.symbol
    );
}

impl MirLowering.declare_global(nd: uni.Name) -> (MirGlobal | None) {
    sym = nd.sym;
    if sym is None {
        return None;
    }
    c_assign = clib_global_of_name(nd);
    if c_assign is not None {
        return self.declare_c_global(c_assign);
    }
    declaration = self.global_declaration(sym);
    if declaration is None {
        return None;
    }
    owner = declaration.find_parent_of_type(uni.Module);
    if owner is not None
        and owner.loc.mod_path.endswith(".jac")
        and os.path.realpath(owner.loc.mod_path)
            != os.path.realpath(self.module.loc.mod_path) {
        group = declaration.parent;
        access = group.access if isinstance(group, uni.GlobalVars) else None;
        defined = declaration.target[0] if declaration.target else None;
        symbol = self.unit_symbol(
            defined.sym_name if isinstance(defined, uni.Name) else sym.sym_name,
            access,
            owner.loc.mod_path
        );
        held = self.mir.globals.get(symbol);
        if held is None {
            held = MirGlobal(
                name=sym.sym_name,
                symbol=symbol,
                type=self.symbol_type(sym, nd),
                linkage="external"
            );
            self.mir.globals[symbol] = held;
            unit = os.path.realpath(owner.loc.mod_path);
            if unit not in self.mir.deps {
                self.mir.deps.append(unit);
            }
        }
        return held;
    }
    found = self.mir.globals.get(sym.sym_name);
    if found is None {
        value_type = self.symbol_type(sym, nd);
        group = declaration.parent;
        access = group.access if isinstance(group, uni.GlobalVars) else None;
        is_priv = bool(access and access.tag.name == Tok.KW_PRIV);
        made = MirGlobal(
            name=sym.sym_name,
            symbol=self.unit_symbol(sym.sym_name, access),
            type=value_type,
            linkage="internal" if is_priv else ""
        );
        initial = declaration.value;
        if isinstance(declaration.parent, uni.ModuleCode) {
            self.mir.globals[sym.sym_name] = made;
            return made;
        }
        folded = initial.ct_value if isinstance(initial, uni.Expr) else None;
        whole = int_host(folded) if isinstance(folded, CtInt) else None;
        if whole is not None
            and -(1 << 63) <= whole < (1 << 63)
            and value_type.kind in (MirKind.INT, MirKind.FLOAT) {
            made.int_value = whole;
            made.float_value = float(whole);
        } elif isinstance(folded, CtFloat) and value_type.kind == MirKind.FLOAT {
            made.float_value = folded.value;
        } elif isinstance(folded, CtBool) and value_type.kind == MirKind.BOOL {
            made.int_value = 1 if folded.value else 0;
        } elif isinstance(initial, uni.Expr) {
            self.deferred_globals.append((made, initial));
        } else {
            raise MirRefused(
                mir_refusal("global initializer", sym.sym_name, declaration)
            );
        }
        self.mir.globals[sym.sym_name] = made;
        found = made;
    }
    return found;
}

impl MirLowering.literal_destination(nd: uni.Int) -> (str | None) {
    dest = nd.coerce_to;
    up: (uni.UniNode | None) = nd.parent;
    while dest is None
        and (
            isinstance(up, uni.AtomUnit)
            or (
                isinstance(up, uni.UnaryExpr)
                and isinstance(up.op, uni.Token)
                and up.op.name in (Tok.PLUS, Tok.MINUS)
            )
        ) {
        dest = up.coerce_to;
        up = up.parent;
    }
    if dest is None
        and isinstance(up, uni.FuncCall)
        and isinstance(up.target, uni.Name)
        and shape_of(up.target.value) is not None {
        dest = up.target.value;
    }
    if dest is None
        and isinstance(up, uni.FuncCall)
        and isinstance(up.target, uni.Expr)
        and c_builtin_kind(up.target.type) == "ptr" {
        dest = "u64";
    }
    return dest;
}

impl MirLowering.flush_stdio {
    b = self.builder();
    for fd in (1, 2) {
        self.runtime("__jac_rt_flush", [b.const_int(fd, mir_int())]);
    }
}

impl MirLowering.declare_clib_externs {
    for imp in self.module.get_all_sub_nodes(uni.Import) {
        for decl in list(imp.clib_decls or []) {
            if not isinstance(decl, uni.Ability)
                or not isinstance(decl.signature, uni.FuncSignature)
                or (
                    decl.body is not None
                    and not (isinstance(decl.body, list) and not decl.body)
                ) {
                continue;
            }
            try {
                self.c_extern(decl, decl);
            } except MirRefused {
                continue;
            }
        }
    }
}

impl MirLowering.const_zero(value: MirValue) -> bool {
    for blk in self.st().fn.blocks {
        for instr in blk.instrs {
            if instr.result is value {
                return instr.op == MirOp.CONST_INT and instr.int_value == 0;
            }
        }
    }
    return False;
}

impl MirLowering.builtin_callee(callee: (uni.UniNode | None)) -> bool {
    return callee is None or os.path.basename(callee.loc.mod_path) in BUILTIN_STUBS;
}
