impl NaIRGenPass._scan_closure_escapes(
    nd: uni.UniNode, body: Sequence[uni.UniNode]
) -> None {
    if not body {
        return;
    }
    direct_names: list[uni.Name] = [];
    for nm in nd.element_sub_nodes(uni.Name) {
        if nm.enclosing_frame is nd {
            direct_names.append(nm);
        }
    }
    for sub in nd.element_sub_nodes(uni.Ability) {
        if sub.enclosing_frame is not nd or self._ability_is_generator(sub) {
            continue;
        }
        sname = sub.name_ref.sym_name if sub.name_ref else None;
        if sname is None {
            continue;
        }
        escapes = False;
        for nm in direct_names {
            if nm.value != sname {
                continue;
            }
            _np = nm.parent;
            if not (isinstance(_np, uni.FuncCall) and _np.target is nm) {
                escapes = True;
                break;
            }
        }
        if not escapes {
            continue;
        }
        for cap_sym in sub.get_enclosing_captures() {
            if frame_owns(nd, cap_sym) {
                self.closure_cell_vars.add(cap_sym.sym_name);
            }
        }
    }
    for lam in nd.element_sub_nodes(uni.LambdaExpr) {
        if lam.enclosing_frame is not nd {
            continue;
        }
        for cap_sym in lam.captures {
            if frame_owns(nd, cap_sym) {
                self.closure_cell_vars.add(cap_sym.sym_name);
            }
        }
    }
}

impl NaIRGenPass._closure_sig_struct(
    fnty: ir.FunctionType
) -> tuple[str, ir.IdentifiedStructType, ir.FunctionType] {
    key = str(fnty);
    _existing = self._closure_sig_keys.get(key);
    if _existing is not None {
        (st, fnty_env) = self.closure_sig_registry[_existing];
        return (_existing, st, fnty_env);
    }
    self._closure_uid += 1;
    name = f"JacClosure.{self._closure_uid}";
    i64 = ir.IntType(64);
    i8p: any = ir.IntType(8).as_pointer();
    self._register_iter_struct(name, ["fn", "env"], [i64, i8p]);
    fnty_env = ir.FunctionType(fnty.return_type, list(fnty.args) + [i8p]);
    st = self.struct_types[name];
    self.closure_sig_registry[name] = (st, fnty_env);
    self._closure_sig_keys[key] = name;
    return (name, st, fnty_env);
}

impl NaIRGenPass._wrap_fn_as_closure_value(val: ir.Value) -> ir.Value {
    fnty: (ir.FunctionType | None) = None;
    if isinstance(val.type, ir.FunctionType) {
        fnty = val.type;
    } elif isinstance(val.type, ir.PointerType)
        and isinstance(val.type.pointee, ir.FunctionType) {
        fnty = val.type.pointee;
    }
    if fnty is None {
        return val;
    }
    (_, sig_st, _) = self._closure_sig_struct(fnty);
    return self._coerce_type(val, sig_st.as_pointer());
}

impl NaIRGenPass._closure_struct_of(val_type: ir.Type) -> (str | None) {
    if not isinstance(val_type, ir.PointerType) {
        return None;
    }
    pname: any = val_type.pointee?.name;
    if pname is not None and pname in self.closure_sig_registry {
        return pname;
    }
    return None;
}

impl NaIRGenPass._callable_signature_of(val_type: ir.Type) -> (ir.FunctionType | None) {
    closure_name = self._closure_struct_of(val_type);
    if closure_name is not None {
        (_, signature) = self.closure_sig_registry[closure_name];
        return ir.FunctionType(signature.return_type, list(signature.args)[:-1]);
    }
    if isinstance(val_type, ir.PointerType)
        and isinstance(val_type.pointee, ir.FunctionType) {
        return val_type.pointee;
    }
    return None;
}

impl NaIRGenPass._closure_cell_struct(slot_type: ir.Type) -> str {
    key = str(slot_type);
    _existing = self._closure_cell_structs.get(key);
    if _existing is not None {
        return _existing;
    }
    self._closure_uid += 1;
    name = f"JacCell.{self._closure_uid}";
    self._register_iter_struct(name, ["val"], [slot_type]);
    self._closure_cell_structs[key] = name;
    return name;
}

impl NaIRGenPass._emit_closure_cell(var_name: str, slot_type: ir.Type) -> ir.Value {
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    cell_name = self._closure_cell_struct(slot_type);
    i32 = ir.IntType(32);
    func = self.builder.function;
    _gc = self._gen_ctx;
    if _gc is not None and func is _gc.resume_fn {
        _cell_st = self.struct_types[cell_name];
        cell_ptr_ty: ir.Type = _cell_st.as_pointer();
        handle_slot = self._entry_alloca(cell_ptr_ty, f"__cell_{var_name}");
        (_sn, _soff, _st) = _gc.slots[-1];
        _gc.cell_inits.append(
            NativeGeneratorCellInit(
                name=var_name, cell_name=cell_name, slot_off=_soff, val_type=slot_type
            )
        );
        entry_block = func.entry_basic_block;
        cur_block = self.builder.block;
        self.builder.position_at_end(entry_block);
        _gen_cell = self.builder.load(handle_slot, name=f"cellh.{var_name}");
        _gen_slot = self.builder.gep(
            _gen_cell,
            [ir.Constant(i32, 0), ir.Constant(i32, 0)],
            name=f"cell.{var_name}"
        );
        self.builder.position_at_end(cur_block);
        self.closure_cell_handles[var_name] = _gen_cell;
        return _gen_slot;
    }
    entry_block = func.entry_basic_block;
    cur_block = self.builder.block;
    if entry_block.instructions {
        self.builder.position_before(entry_block.instructions[0]);
    } else {
        self.builder.position_at_start(entry_block);
    }
    cell = self._alloc_iter_struct(cell_name);
    slot = self.builder.gep(
        cell, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name=f"cell.{var_name}"
    );
    if isinstance(slot_type, ir.IntType) {
        self.builder.store(ir.Constant(slot_type, 0), slot);
    } elif isinstance(slot_type, (ir.DoubleType, ir.FloatType)) {
        self.builder.store(ir.Constant(slot_type, 0.0), slot);
    } else {
        self.builder.store(ir.Constant(slot_type, None), slot);
    }
    self.builder.position_at_end(cur_block);
    self.closure_cell_handles[var_name] = cell;
    return slot;
}

impl NaIRGenPass._emit_closure_thunk(
    target_fn: ir.Function,
    declared_count: int,
    cap_info: list[tuple[str, str, ir.Type]]
) -> ir.Function {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    self._closure_uid += 1;
    env_name = f"JacClosureEnv.{self._closure_uid}";
    field_names: list[str] = [];
    field_types: list[ir.Type] = [];
    links = self.closure_pass_links.get(target_fn.name, {});
    for (cname, cmode, hidden_ty) in cap_info {
        slot_ty: ir.Type = hidden_ty;
        if cmode == "ptr" {
            assert isinstance(hidden_ty, ir.PointerType);
            _cap_pointee = hidden_ty.pointee;
            assert _cap_pointee is not None;
            slot_ty = _cap_pointee;
        }
        cell_name = self._closure_cell_struct(slot_ty);
        if cname in links {
            cell_name = self._pass_link_struct(cell_name);
        }
        field_names.append(cname);
        field_types.append(self.struct_types[cell_name].as_pointer());
    }
    self._register_iter_struct(env_name, field_names, field_types);

    fnty = target_fn.function_type;
    declared = list(fnty.args)[:declared_count];
    thunk_ty = ir.FunctionType(fnty.return_type, declared + [i8p]);
    thunk: ir.Function = ir.Function(
        self.llvm_module, thunk_ty, name=f"__jac_closure_{target_fn.name}"
    );
    thunk.linkage = "private";
    thunk.args[-1].name = "env";

    saved_builder = self._builder;
    self._builder = ir.IRBuilder(thunk.append_basic_block("entry"));
    _env_st = self.struct_types[env_name];
    envp = self.builder.bitcast(thunk.args[-1], _env_st.as_pointer(), name="env.typed");
    call_args: list[ir.Value] = [];
    for _declared_arg in list(thunk.args)[:-1] {
        call_args.append(_declared_arg);
    }
    for (i, _cap) in enumerate(cap_info) {
        (cname, cmode, _hidden_ty) = _cap;
        fslot = self.builder.gep(
            envp, [ir.Constant(i32, 0), ir.Constant(i32, i)], name=f"env.{cname}"
        );
        cell = self.builder.load(fslot, name=f"cell.{cname}");
        if cname in links {
            cell = self.builder.load(
                self.builder.gep(
                    cell,
                    [ir.Constant(i32, 0), ir.Constant(i32, 0)],
                    name=f"pass.{cname}.cell"
                ),
                name=f"pass.{cname}"
            );
        }
        vslot = self.builder.gep(
            cell, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name=f"cellv.{cname}"
        );
        if cmode == "ptr" {
            call_args.append(vslot);
        } else {
            call_args.append(self.builder.load(vslot, name=f"capv.{cname}"));
        }
    }
    if isinstance(thunk_ty.return_type, ir.VoidType) {
        self.builder.call(target_fn, call_args);
        self.builder.ret_void();
    } else {
        res = self.builder.call(target_fn, call_args, name="clos.inner");
        self.builder.ret(res);
    }
    self._builder = saved_builder;
    thunk.jac_env_struct = env_name;
    return thunk;
}

impl NaIRGenPass._emit_closure_pair(
    target_fn: ir.Function,
    declared_fnty: ir.FunctionType,
    cap_info: list[tuple[str, str, ir.Type]]
) -> (ir.Value | None) {
    rebinds = self.closure_rebinds.get(target_fn.name, set());
    for (cname, _cmode, _ht) in cap_info {
        if cname not in self.closure_cell_handles
            and (cname not in rebinds or cname not in self.local_vars) {
            return None;
        }
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    (sig_name, _sig_st, _fnty_env) = self._closure_sig_struct(declared_fnty);
    _tname = target_fn.name;
    _cached_thunk = self.closure_thunks.get(_tname);
    if _cached_thunk is None {
        _cached_thunk = self._emit_closure_thunk(
            target_fn, len(declared_fnty.args), cap_info
        );
        self.closure_thunks[_tname] = _cached_thunk;
    }
    thunk: ir.Function = _cached_thunk;
    env_name = thunk.jac_env_struct;
    assert env_name is not None;
    env_field_types = self.struct_field_types[env_name];
    links = self.closure_pass_links.get(target_fn.name, {});
    env = self._alloc_iter_struct(env_name);
    for (i, _cap) in enumerate(cap_info) {
        cname = _cap[0];
        if cname in rebinds and cname not in self.closure_cell_handles {
            fresh_ty = env_field_types[cname];
            assert isinstance(fresh_ty, ir.PointerType);
            fresh_struct = fresh_ty.pointee;
            assert isinstance(fresh_struct, ir.IdentifiedStructType);
            fresh = self._alloc_iter_struct(fresh_struct.name);
            current = self.builder.load(self.local_vars[cname], name=f"rebind.{cname}");
            self.builder.store(
                current,
                self.builder.gep(
                    fresh,
                    [ir.Constant(i32, 0), ir.Constant(i32, 0)],
                    name=f"rebind.{cname}.slot"
                )
            );
            self._emit_take_ref(current, op="closure_rebind", loc="");
            self.builder.store(
                fresh,
                self.builder.gep(
                    env,
                    [ir.Constant(i32, 0), ir.Constant(i32, i)],
                    name=f"envf.{cname}"
                )
            );
            continue;
        }
        cell = self.closure_cell_handles[cname];
        if cname in links {
            held = self._current_pass_link(links[cname]);
            if held is not None {
                cell = held;
            }
        }
        fty: ir.Type = env_field_types[cname];
        cellv = cell
            if cell.type == fty
            else self.builder.bitcast(cell, fty, name=f"cellc.{cname}");
        fslot = self.builder.gep(
            env, [ir.Constant(i32, 0), ir.Constant(i32, i)], name=f"envf.{cname}"
        );
        self.builder.store(cellv, fslot);
        self._emit_rc_retain(cell, op="closure_env", loc="");
    }
    clos = self._alloc_iter_struct(sig_name);
    fn_slot = self.builder.gep(
        clos, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="clos.fn.slot"
    );
    self.builder.store(self.builder.ptrtoint(thunk, i64, name="clos.fn"), fn_slot);
    env_slot = self.builder.gep(
        clos, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="clos.env.slot"
    );
    self.builder.store(self.builder.bitcast(env, i8p, name="clos.env.i8"), env_slot);
    self._mark_owned(clos);
    return clos;
}

impl NaIRGenPass._emit_closure_value(
    var_name: str, nd: uni.UniNode
) -> (ir.Value | None) {
    cap_entry = self.scope.closure(var_name);
    if cap_entry is None {
        return None;
    }
    (fn, caps) = cap_entry;
    declared_count = len(fn.args) - len(caps);
    if declared_count < 0 {
        return None;
    }
    fnty = fn.function_type;
    declared_fnty = ir.FunctionType(fnty.return_type, list(fnty.args)[:declared_count]);
    cap_info: list[tuple[str, str, ir.Type]] = [];
    for (i, _cap) in enumerate(caps) {
        (cname, cmode) = _cap;
        cap_info.append((cname, cmode, fnty.args[declared_count + i]));
    }
    return self._emit_closure_pair(fn, declared_fnty, cap_info);
}

impl NaIRGenPass._emit_closure_escape_error(var_name: str, nd: uni.UniNode) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="expression",
        name=f"'{var_name}' (capturing closure used as a value)",
        help_text="This closure's captured variables could not be promoted to shared heap cells in this frame (e.g. the capture is itself borrowed from an outer function, or the closure is a generator), so it can only be called directly here. Move the captured state into this frame, or use an object holding the state."
    );
}

impl NaIRGenPass._codegen_closure_call(
    nd: uni.FuncCall, clos_val: ir.Value, struct_name: str
) -> (ir.Value | None) {
    (_st, fnty_env) = self.closure_sig_registry[struct_name];
    i32 = ir.IntType(32);
    declared = list(fnty_env.args)[:-1];
    raw_args: list[ir.Value] = [];
    for p in (nd.params or []) {
        v = self._codegen_expr(p);
        if v is not None {
            raw_args.append(v);
        }
    }
    coerced: list[ir.Value] = [];
    for (i, a) in enumerate(raw_args) {
        if i < len(declared) {
            coerced.append(self._coerce_type(a, declared[i]));
        } else {
            coerced.append(a);
        }
    }
    while len(coerced) < len(declared) {
        coerced.append(self._default_arg_fallback(declared[len(coerced)]));
    }
    fn_slot = self.builder.gep(
        clos_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ccall.fn.slot"
    );
    fn_i64 = self.builder.load(fn_slot, name="ccall.fn.i64");
    fn_ptr = self.builder.inttoptr(fn_i64, fnty_env.as_pointer(), name="ccall.fn");
    env_slot = self.builder.gep(
        clos_val, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="ccall.env.slot"
    );
    env = self.builder.load(env_slot, name="ccall.env");
    result: any = None;
    if isinstance(fnty_env.return_type, ir.VoidType) {
        result = self.builder.call(fn_ptr, coerced + [env]);
    } else {
        result = self.builder.call(fn_ptr, coerced + [env], name="ccall");
    }
    for a in raw_args {
        if isinstance(a.type, ir.PointerType) and self._is_owned(a) {
            self._emit_rc_release_simple(a, op="ccall_arg", loc="");
        }
    }
    if isinstance(clos_val.type, ir.PointerType) and self._is_owned(clos_val) {
        self._emit_rc_release_simple(clos_val, op="ccall_target", loc="");
    }
    return result;
}

impl NaIRGenPass._emit_bound_method_value(
    receiver: ir.Value, type_name: str, method_name: str
) -> (ir.Value | None) {
    func = self._resolve_method(type_name, method_name);
    struct_t = self.struct_types.get(type_name);
    if func is None or struct_t is None {
        return None;
    }
    if self._is_static_method_func(func) {
        return self._wrap_fn_as_closure_value(func);
    }
    if not isinstance(receiver.type, ir.PointerType) {
        return None;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    fnty = func.function_type;
    declared_fnty = ir.FunctionType(fnty.return_type, list(fnty.args)[1:]);
    (sig_name, _sig_st, fnty_env) = self._closure_sig_struct(declared_fnty);
    thunk_key = f"__jac_bound.{type_name}.{method_name}";
    thunk: (ir.Function | None) = self.closure_thunks.get(thunk_key);
    if thunk is None {
        thunk = ir.Function(self.llvm_module, fnty_env, name=thunk_key);
        thunk.linkage = "private";
        thunk.args[-1].name = "self_env";
        saved_builder = self._builder;
        self._builder = ir.IRBuilder(thunk.append_basic_block("entry"));
        recv = self.builder.bitcast(
            thunk.args[-1], struct_t.as_pointer(), name="bound.self"
        );
        call_args: list[ir.Value] = [recv] + list(thunk.args)[:-1];
        result: (ir.Value | None) = None;
        if self._arch_has_vtable(type_name) {
            result = self._codegen_virtual_call(
                recv, method_name, call_args, type_name
            );
        }
        if result is None {
            coerced = [
                self._coerce_type(a, func.args[i].type)
                for (i, a) in enumerate(call_args)
            ];
            result = self.builder.call(func, coerced, name="bound.call");
        }
        if isinstance(fnty_env.return_type, ir.VoidType) {
            self.builder.ret_void();
        } else {
            self.builder.ret(self._coerce_type(result, fnty_env.return_type));
        }
        self._builder = saved_builder;
        self.closure_thunks[thunk_key] = thunk;
    }
    clos = self._alloc_iter_struct(sig_name);
    fn_slot = self.builder.gep(
        clos, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="bound.fn.slot"
    );
    self.builder.store(self.builder.ptrtoint(thunk, i64, name="bound.fn"), fn_slot);
    env_slot = self.builder.gep(
        clos, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="bound.env.slot"
    );
    self._emit_rc_retain(receiver, op="bound_method", loc="");
    self.builder.store(self.builder.bitcast(receiver, i8p, name="bound.env"), env_slot);
    self._mark_owned(clos);
    return clos;
}

impl NaIRGenPass._register_pass_links(
    closure: uni.UniNode, target_fn: ir.Function
) -> None {
    links = self.loop_links.of_closure(closure);
    if links {
        by_name: dict[str, PassLink] = {};
        for link in links {
            by_name[link.sym.sym_name] = link;
        }
        self.closure_pass_links[target_fn.name] = by_name;
    }
    rebinds = self.loop_links.rebinds_of(closure);
    if rebinds {
        names: set[str] = set();
        for sym in rebinds {
            names.add(sym.sym_name);
        }
        self.closure_rebinds[target_fn.name] = names;
    }
}

impl NaIRGenPass._pass_link_struct(cell_name: str) -> str {
    existing = self._pass_link_structs.get(cell_name);
    if existing is not None {
        return existing;
    }
    self._closure_uid += 1;
    name = f"JacPassLink.{self._closure_uid}";
    self._register_iter_struct(
        name, ["cell"], [self.struct_types[cell_name].as_pointer()]
    );
    self._pass_link_structs[cell_name] = name;
    return name;
}

impl NaIRGenPass._current_pass_link(link: PassLink) -> (ir.Value | None) {
    var_name = link.sym.sym_name;
    cell = self.closure_cell_handles.get(var_name);
    if cell is None or not isinstance(cell.type, ir.PointerType) {
        return None;
    }
    cell_struct = cell.type.pointee;
    if not isinstance(cell_struct, ir.IdentifiedStructType) {
        return None;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    link_name = self._pass_link_struct(cell_struct.name);
    link_ty = self.struct_types[link_name].as_pointer();
    func = self.builder.function;
    slot_key = f"{func.name}.pass.{link.index}";
    made_slot = self._pass_link_slots.get(slot_key);
    slot: ir.Value;
    if made_slot is None {
        slot = self._entry_alloca(link_ty, f".pass.{link.index}");
        self.local_vars[f".pass.{link.index}"] = slot;
        self._pass_link_slots[slot_key] = (slot, link_name, cell_struct.name);
    } else {
        slot = made_slot[0];
    }
    i32 = ir.IntType(32);
    current = self.builder.load(slot, name=f"pass.{var_name}");
    missing = self.builder.icmp_unsigned(
        "==", current, ir.Constant(link_ty, None), name=f"pass.{var_name}.missing"
    );
    open_bb = func.append_basic_block(name="pass.open");
    ready_bb = func.append_basic_block(name="pass.ready");
    self.builder.cbranch(missing, open_bb, ready_bb);
    self.builder.position_at_end(open_bb);
    made = self._alloc_iter_struct(link_name);
    self.builder.store(
        cell,
        self.builder.gep(
            made, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="pass.cell.slot"
        )
    );
    self._emit_rc_retain(cell, op="pass_link", loc="");
    self.builder.store(made, slot);
    self.builder.branch(ready_bb);
    self.builder.position_at_end(ready_bb);
    return self.builder.load(slot, name=f"pass.{var_name}.held");
}

impl NaIRGenPass._emit_pass_link_detaches(loop: (LoopStmt | None)) -> None {
    if loop is None or self._builder is None or self.builder.block.is_terminated {
        return;
    }
    i32 = ir.IntType(32);
    for link in self.loop_links.of_loop(loop) {
        func = self.builder.function;
        made = self._pass_link_slots.get(f"{func.name}.pass.{link.index}");
        if made is None {
            continue;
        }
        (slot, link_name, cell_name) = made;
        link_ty = self.struct_types[link_name].as_pointer();
        current = self.builder.load(slot, name="pass.current");
        present = self.builder.icmp_unsigned(
            "!=", current, ir.Constant(link_ty, None), name="pass.present"
        );
        detach_bb = func.append_basic_block(name="pass.detach");
        done_bb = func.append_basic_block(name="pass.detached");
        self.builder.cbranch(present, detach_bb, done_bb);
        self.builder.position_at_end(detach_bb);
        cell_slot = self.builder.gep(
            current, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="pass.cell.slot"
        );
        shared = self.builder.load(cell_slot, name="pass.shared");
        kept = self._alloc_iter_struct(cell_name);
        value = self.builder.load(
            self.builder.gep(
                shared, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="pass.val.slot"
            ),
            name="pass.val"
        );
        self.builder.store(
            value,
            self.builder.gep(
                kept, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="pass.kept.slot"
            )
        );
        self._emit_take_ref(value, op="pass_detach", loc="");
        self.builder.store(kept, cell_slot);
        self._emit_rc_release_typed(shared, op="pass_detach", loc="");
        self._emit_rc_release_typed(current, op="pass_detach", loc="");
        self.builder.store(ir.Constant(link_ty, None), slot);
        self.builder.branch(done_bb);
        self.builder.position_at_end(done_bb);
    }
}

impl NaIRGenPass._codegen_pass_body(loop: LoopStmt) -> None {
    if isinstance(loop.body, (list, tuple)) {
        self._codegen_body(loop.body);
    }
    self._emit_pass_link_detaches(loop);
}

impl NaIRGenPass._binding_slot(var_type: ir.Type, var_name: str) -> ir.Value {
    if var_name in self.closure_cell_vars
        and var_name not in self.closure_cell_handles {
        return self._emit_closure_cell(var_name, var_type);
    }
    return self._entry_alloca(var_type, var_name);
}
