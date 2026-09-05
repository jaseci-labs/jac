import from jaclang.compiler.frontend.constant { OwnershipKind }

glob _NA_ABC_REDUCTIONS: dict[str, tuple] = {
         "Sequence": ("list", "tuple", "str", "bytes", "bytearray"),
         "MutableSequence": ("list", "bytearray"),
         "Mapping": ("dict", ),
         "MutableMapping": ("dict", ),
         "Set": ("set", "frozenset"),
         "AbstractSet": ("set", "frozenset"),
         "MutableSet": ("set", ),
         "ByteString": ("bytes", "bytearray")
     },
     _NA_ABC_OPAQUE: tuple = (
         "Iterable",
         "Iterator",
         "Reversible",
         "Generator",
         "Container",
         "Collection",
         "Sized",
         "Hashable",
         "Callable",
         "Awaitable",
         "Coroutine",
         "AsyncIterable",
         "AsyncIterator",
         "AsyncGenerator",
         "MappingView",
         "KeysView",
         "ItemsView",
         "ValuesView",
         "Buffer"
     );

impl NaIRGenCalls._arch_alias_target(nd: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(nd, uni.NameAtom) {
        return None;
    }
    sym = nd.sym;
    if sym is None {
        return None;
    }
    d = sym.decl;
    if d is None {
        return None;
    }
    nof = d.name_of;
    if isinstance(nof, uni.Archetype) and nof.name.value != self._get_name(nd) {
        return nof.name.value;
    }
    par = d.parent;
    if isinstance(par, uni.ModuleItem) and par.alias is d {
        return self._get_name(par.name);
    }
    return None;
}

impl NaIRGenCalls._erased_generic_ctor(nd: uni.FuncCall) -> (str | None) {
    _tgt = nd.target;
    if not isinstance(_tgt, uni.AtomTrailer)
        or _tgt.is_attr
        or not isinstance(_tgt.right, uni.IndexSlice) {
        return None;
    }
    if self._ct_ctor_slots(_tgt) {
        return self._get_name(_tgt.target);
    }
    _base_tk = self._type_key_of(_tgt.target);
    if _base_tk is None or not _base_tk.startswith("type[") {
        return None;
    }
    _tk = self._type_key_of(_tgt);
    if _tk is None or not _tk.startswith("type[") or not _tk.endswith("]") {
        return None;
    }
    return self._erased_arch_base(_tk[5:-1]);
}

impl NaIRGenCalls._linked_callee_decl(
    func: (ir.Function | None)
) -> (uni.Ability | None) {
    if func is None {
        return None;
    }
    rec = self._linked_fn_decls.get(id(func));
    if rec is None or rec[0] is not func {
        return None;
    }
    return rec[1];
}

impl NaIRGenCalls._callee_sig_of(
    nd: uni.FuncCall, func: (ir.Function | None) = None
) -> (uni.FuncSignature | None) {
    linked = self._linked_callee_decl(func);
    if linked is not None and isinstance(linked.signature, uni.FuncSignature) {
        return linked.signature;
    }
    decl = nd.callee_decl;
    sig = decl.signature if decl is not None else None;
    return sig if isinstance(sig, uni.FuncSignature) else None;
}

impl NaIRGenCalls._arch_init_sig_of(type_name: str) -> (uni.FuncSignature | None) {
    arch = self.arch_ast_map.get(type_name);
    if not isinstance(arch, uni.Archetype) or arch.body is None {
        return None;
    }
    for stmt in arch.body {
        if isinstance(stmt, uni.Ability)
            and stmt.name_ref is not None
            and stmt.name_ref.sym_name in ("init", "__init__")
            and isinstance(stmt.signature, uni.FuncSignature) {
            return stmt.signature;
        }
    }
    return None;
}

impl NaIRGenCalls._default_arg_fallback(t: ir.Type) -> ir.Value {
    if isinstance(t, ir.PointerType) {
        if t.pointee == self._get_bytes_struct_type() {
            return self._make_global_bytes(b"");
        }
        return ir.Constant(t, None);
    }
    if isinstance(t, (ir.IntType, ir.DoubleType)) {
        return ir.Constant(t, 0);
    }
    return ir.Constant(t, None);
}

impl NaIRGenCalls._codegen_bound_args(
    nd: uni.FuncCall, func: ir.Function, self_offset: int = 0
) -> list {
    raw = nd.params or [];
    positional: list = [];
    kw_map: dict = {};
    kw_spreads: list = [];
    kw_order: list = [];
    _unpack_names: list = [];
    for param in raw {
        if isinstance(param, uni.KWPair) {
            key = param.key.sym_name if param.key is not None else None;
            if key is not None {
                kw_map[key] = param.value;
                kw_order.append(("lit", key));
            } else {
                kw_spreads.append(param.value);
                kw_order.append(("spread", param.value));
            }
        } elif (
            isinstance(param, uni.UnaryExpr)
            and isinstance(param.op, uni.Token)
            and param.op.name in (Tok.STAR_MUL, Tok.STAR_POW)
        ) {
            if param.op.name == Tok.STAR_POW {
                kw_spreads.append(param.operand);
                kw_order.append(("spread", param.operand));
                continue;
            }
            _tv = self._codegen_expr(param.operand);
            _tt = _tv.type if _tv is not None else None;
            _tup_ptr = (
                _tv is not None
                and isinstance(_tt, ir.PointerType)
                and isinstance(_tt.pointee, ir.LiteralStructType)
            );
            _tup_val = _tv is not None and isinstance(_tt, ir.LiteralStructType);
            _is_list_sp = False;
            if _tv is not None and not _tup_ptr and isinstance(_tt, ir.PointerType) {
                for (_sln, _slt) in self.list_types.items() {
                    if _slt.as_pointer() == _tt {
                        _is_list_sp = True;
                        break;
                    }
                }
            }
            if (_tup_ptr or _tup_val) and _tv is not None {
                _sp32 = ir.IntType(32);
                _tup_elems: tuple = ();
                if _tup_ptr and isinstance(_tt, ir.PointerType) {
                    _tup_elems = _tt.pointee.elements;
                } elif isinstance(_tt, ir.LiteralStructType) {
                    _tup_elems = _tt.elements;
                }
                for (_ei, _et) in enumerate(_tup_elems) {
                    if _tup_ptr {
                        _ep = self.builder.gep(
                            _tv,
                            [ir.Constant(_sp32, 0), ir.Constant(_sp32, _ei)],
                            name=f"spread.{_ei}"
                        );
                        _ev = self.builder.load(_ep, name=f"spread.v.{_ei}");
                    } else {
                        _ev = self.builder.extract_value(
                            _tv, _ei, name=f"spread.v.{_ei}"
                        );
                    }
                    if isinstance(_ev.type, ir.PointerType) {
                        self._emit_rc_retain(_ev, op="spread_elem", loc="");
                        self._mark_owned(_ev);
                    }
                    positional.append(("spread.val", _ev));
                }
                if _tup_ptr and _tv is not None and self._is_owned(_tv) {
                    self._emit_rc_release_simple(_tv, op="spread_tuple", loc="");
                }
            } elif _is_list_sp {
                positional.append(("spread.list.val", _tv));
            } else {
                _unpack_names.append(param.op.value);
            }
        } else {
            positional.append(param);
        }
    }
    if _unpack_names {
        self.emit(
            E5092,
            node_override=nd,
            kind="call argument unpacking",
            name=", ".join(_unpack_names),
            help_text="Only tuple spreads (static arity) and list spreads into a variadic callee lower natively; `**` unpacking and spreads of other types are not lowered - pass the elements explicitly or move the call to a @sv/Python context."
        );
    }

    callee_sig = self._callee_sig_of(nd, func);
    if kw_spreads and (callee_sig is None or callee_sig.kwargs is None) {
        self.emit(
            E5092,
            node_override=nd,
            kind="call argument unpacking",
            name="**",
            help_text="A `**` spread carries keys known only at runtime, so the callee needs a `**kwargs` sink to receive keys that match no declared parameter. Give the callee a `**kwargs` parameter, or pass the arguments explicitly."
        );
        kw_spreads = [];
        kw_order = [];
    }
    args: list = [];

    if callee_sig is None {
        for p in positional {
            if isinstance(p, tuple) and p and p[0] == "spread.val" {
                args.append(p[1]);
                continue;
            }
            if isinstance(p, tuple) and p and p[0] == "spread.list.val" {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="call argument unpacking",
                    name="*",
                    help_text="A list spread has no static arity, so it cannot fill fixed parameters; spread a tuple instead, or make the callee variadic."
                );
                continue;
            }
            v = self._codegen_expr(p);
            if v is not None {
                args.append(v);
            }
        }
        slot = self_offset + len(args);
        while slot < len(func.args) {
            args.append(self._default_arg_fallback(func.args[slot].type));
            slot += 1;
        }
        return args;
    }

    sig_params = callee_sig.get_parameters();
    _self_skip = 0;
    if (
        self_offset > 0
        and sig_params
        and sig_params[0].name
        and sig_params[0].name.value == "self"
    ) {
        sig_params = sig_params[1:];
        _self_skip = 1;
    }
    _has_pack = (callee_sig.varargs is not None) or (callee_sig.kwargs is not None);
    if _has_pack and func.function_type.var_arg {
        _has_pack = False;
    }
    _sig_is_callees = (self_offset - _self_skip + len(callee_sig.get_parameters()))
        == len(func.args);
    if _has_pack {
        _chk = self_offset - _self_skip
            + len(callee_sig.posonly_params or [])
            + len(callee_sig.params or []);
        if callee_sig.varargs is not None {
            _vt_ok = False;
            if _chk < len(func.args)
                and isinstance(func.args[_chk].type, ir.PointerType) {
                for (_, _lt) in self.list_types.items() {
                    if _lt.as_pointer() == func.args[_chk].type {
                        _vt_ok = True;
                        break;
                    }
                }
            }
            if not _vt_ok {
                if _sig_is_callees {
                    self._emit_pack_slot_refusal(nd, "*");
                }
                _has_pack = False;
            }
            _chk += 1;
        }
        _chk += len(callee_sig.kwonlyargs or []);
        if _has_pack and callee_sig.kwargs is not None {
            _dt_ok = False;
            if _chk < len(func.args)
                and isinstance(func.args[_chk].type, ir.PointerType) {
                for (_dk, _dt) in self.dict_types.items() {
                    if _dk.startswith("ptr:")
                        and _dt.as_pointer() == func.args[_chk].type {
                        _dt_ok = True;
                        break;
                    }
                }
            }
            if not _dt_ok {
                if _sig_is_callees {
                    self._emit_pack_slot_refusal(nd, "**");
                }
                _has_pack = False;
            }
        }
    }
    if not _has_pack {
        for (pix, sp) in enumerate(sig_params) {
            slot = self_offset + pix;
            if (
                slot >= len(func.args)
                and not func.function_type.var_arg
                and pix >= len(positional)
            ) {
                break;
            }
            expected_type = func.args[slot].type
                if slot < len(func.args)
                else ir.IntType(64);
            chosen: (uni.Expr | None) = None;
            if pix < len(positional) {
                chosen = positional[pix];
            } elif sp.name.sym_name in kw_map {
                chosen = kw_map[sp.name.sym_name];
            } elif sp.value is not None {
                chosen = sp.value;
                if isinstance(chosen, (uni.Null, uni.Ellipsis))
                    and str(chosen.loc.mod_path).endswith(".pyi") {
                    chosen = None;
                }
            }
            if isinstance(chosen, tuple) and chosen and chosen[0] == "spread.val" {
                val = chosen[1];
            } elif isinstance(chosen, tuple)
                and chosen
                and chosen[0] == "spread.list.val" {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="call argument unpacking",
                    name="*",
                    help_text="A list spread has no static arity, so it cannot fill fixed parameters; spread a tuple instead, or make the callee variadic."
                );
                val = None;
            } else {
                val = self._codegen_expr(chosen)
                    if isinstance(chosen, uni.UniNode)
                    else None;
            }
            if val is not None {
                args.append(val);
            } else {
                args.append(self._default_arg_fallback(expected_type));
            }
        }

        for pix in range(len(sig_params), len(positional)) {
            _extra_p = positional[pix];
            if isinstance(_extra_p, tuple)
                and _extra_p
                and _extra_p[0] == "spread.val" {
                args.append(_extra_p[1]);
                continue;
            }
            if isinstance(_extra_p, tuple)
                and _extra_p
                and _extra_p[0] == "spread.list.val" {
                continue;
            }
            v = self._codegen_expr(_extra_p);
            if v is not None {
                args.append(v);
            }
        }
    } else {
        _fixed = list(callee_sig.posonly_params or []) + list(callee_sig.params or []);
        _n_posonly = len(callee_sig.posonly_params or []);
        if _self_skip and _fixed {
            _fixed = _fixed[1:];
            _n_posonly = _n_posonly - 1 if _n_posonly > 0 else 0;
        }
        _bind_records: list = [];
        for (pix, sp) in enumerate(_fixed) {
            slot = self_offset + pix;
            expected_type = func.args[slot].type
                if slot < len(func.args)
                else ir.IntType(64);
            chosen = None;
            _from_pos = False;
            _from_kw = False;
            if pix < len(positional) {
                chosen = positional[pix];
                _from_pos = True;
            } elif sp.name.sym_name in kw_map {
                chosen = kw_map.pop(sp.name.sym_name);
                _from_kw = True;
            } elif sp.value is not None {
                chosen = sp.value;
                if isinstance(chosen, (uni.Null, uni.Ellipsis))
                    and str(chosen.loc.mod_path).endswith(".pyi") {
                    chosen = None;
                }
            }
            if isinstance(chosen, tuple) and chosen and chosen[0] == "spread.val" {
                val = chosen[1];
            } elif isinstance(chosen, tuple)
                and chosen
                and chosen[0] == "spread.list.val" {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="call argument unpacking",
                    name="*",
                    help_text="A list spread has no static arity, so it cannot fill fixed parameters; spread a tuple instead, or make the callee variadic."
                );
                val = None;
            } else {
                val = self._codegen_expr(chosen)
                    if isinstance(chosen, uni.UniNode)
                    else None;
            }
            if val is not None {
                args.append(val);
            } else {
                args.append(self._default_arg_fallback(expected_type));
            }
            if kw_spreads and pix >= _n_posonly {
                _bind_records.append(
                    self._prep_kwbind_record(
                        sp.name.sym_name,
                        expected_type,
                        len(args) - 1,
                        args[-1],
                        "pos" if _from_pos else ("kw" if _from_kw else None),
                        "positional" if sp.value is None else None
                    )
                );
            }
        }
        _slot = self_offset + len(_fixed);
        if callee_sig.varargs is not None {
            _pack_t = func.args[_slot].type if _slot < len(func.args) else None;
            _lv = self._codegen_varargs_list(nd, positional[len(_fixed):], _pack_t);
            if _lv is not None {
                args.append(_lv);
            } elif _pack_t is not None {
                args.append(self._default_arg_fallback(_pack_t));
            }
            _slot += 1;
        }
        for sp in (callee_sig.kwonlyargs or []) {
            expected_type = func.args[_slot].type
                if _slot < len(func.args)
                else ir.IntType(64);
            chosen = None;
            _from_kw = False;
            if sp.name.sym_name in kw_map {
                chosen = kw_map.pop(sp.name.sym_name);
                _from_kw = True;
            } elif sp.value is not None {
                chosen = sp.value;
                if isinstance(chosen, (uni.Null, uni.Ellipsis))
                    and str(chosen.loc.mod_path).endswith(".pyi") {
                    chosen = None;
                }
            }
            if isinstance(chosen, tuple) and chosen and chosen[0] == "spread.val" {
                val = chosen[1];
            } elif isinstance(chosen, tuple)
                and chosen
                and chosen[0] == "spread.list.val" {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="call argument unpacking",
                    name="*",
                    help_text="A list spread has no static arity, so it cannot fill fixed parameters; spread a tuple instead, or make the callee variadic."
                );
                val = None;
            } else {
                val = self._codegen_expr(chosen)
                    if isinstance(chosen, uni.UniNode)
                    else None;
            }
            if val is not None {
                args.append(val);
            } else {
                args.append(self._default_arg_fallback(expected_type));
            }
            if kw_spreads {
                _bind_records.append(
                    self._prep_kwbind_record(
                        sp.name.sym_name,
                        expected_type,
                        len(args) - 1,
                        args[-1],
                        "kw" if _from_kw else None,
                        "keyword-only" if sp.value is None else None
                    )
                );
            }
            _slot += 1;
        }
        if callee_sig.kwargs is not None {
            _kw_t = func.args[_slot].type if _slot < len(func.args) else None;
            _dv = self._codegen_kwargs_dict(nd, kw_map, _kw_t, kw_order, _bind_records);
            if _dv is not None {
                args.append(_dv);
            } elif _kw_t is not None {
                args.append(self._default_arg_fallback(_kw_t));
            }
        }
        for _rec in _bind_records {
            if _rec["alloca"] is None {
                continue;
            }
            if _rec["missing_msg"] is not None {
                _flv = self.builder.load(_rec["flag"], name="kwbind.flag");
                self._emit_runtime_raise(
                    self.builder.not_(_flv, name="kwbind.unbound"),
                    "TypeError",
                    _rec["missing_msg"]
                );
            }
            _bv = self.builder.load(_rec["alloca"], name="kwbind.final");
            if isinstance(_bv.type, ir.PointerType) {
                self._mark_owned(_bv);
            }
            args[_rec["args_idx"]] = _bv;
        }
    }

    _nc_name = nd.target.sym_name if isinstance(nd.target, uni.Name) else None;
    _nc_entry = self.nested_captures.get(_nc_name) if _nc_name is not None else None;
    if _nc_entry is not None and _nc_entry[0] is func {
        for (_cname, _cmode) in _nc_entry[1] {
            _c_slot = self.local_vars.get(_cname);
            if _c_slot is None {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="function",
                    name=f"{_nc_name} (captured '{_cname}' not in the calling frame)",
                    help_text="A capturing nested function can only be called from a frame that defines or forwards its captures. Pass the value as an explicit parameter instead."
                );

                while len(args) < len(func.args) {
                    args.append(self._default_arg_fallback(func.args[len(args)].type));
                }
                return args;
            }
            if _cmode == "ptr" {
                args.append(_c_slot);
            } else {
                args.append(self.builder.load(_c_slot, name=f"cap.{_cname}"));
            }
        }
    }

    if func.function_type.var_arg {
        return args;
    }
    expected_argc = len(func.args) - self_offset;
    if len(args) > expected_argc {
        if len(args) > len(sig_params) {
            self.emit(
                E5092,
                node_override=nd,
                kind="expression",
                name=f"call with {len(args)} arguments (native accepts {expected_argc})",
                help_text="The resolved (frontend) signature allows more arguments than the native implementation declares (a variadic stub over a bounded native function). Pass fewer arguments or fold the extras before the call."
            );
            return args[:expected_argc];
        }

        return args;
    }
    while len(args) < expected_argc {
        slot = self_offset + len(args);
        args.append(self._default_arg_fallback(func.args[slot].type));
    }
    return args;
}

impl NaIRGenCalls._emit_pack_slot_refusal(nd: uni.FuncCall, star: str) -> None {
    """Refuse a call whose callee declares a pack it could not lay out.

    Binding the extras positionally into a slot that is not a pack is the one
    answer this site may never give: the callee reads that slot as its whole
    parameter pack, so the mismatch is a silent misread at run time rather
    than a missing feature.

    Reached only when the signature that declares the pack is the one the
    called function was built from. A bundled native module whose typeshed
    stub is variadic while its own definition is fixed-arity -- `os.path.join`
    is the standing example -- resolves a signature belonging to a different
    implementation, and positional binding against the real one is correct.
    """;
    _sink = "*args" if star == "*" else "**kwargs";
    self.emit(
        E5092,
        node_override=nd,
        kind="variadic call",
        name=star,
        help_text=(
            f"The callee declares a `{star}` pack, but its `{_sink}` slot did "
            f"not lay out as a native list or dict, so the arguments this "
            f"site would pack have nowhere to go. Annotate the pack with an "
            f"element type that lowers, or move the call to a @sv/Python "
            f"context."
        )
    );
}

impl NaIRGenCalls._codegen_varargs_list(
    nd: uni.FuncCall, extras: list, expected: (ir.Type | None)
) -> (ir.Value | None) {
    spec: (str | None) = None;
    if expected is not None and isinstance(expected, ir.PointerType) {
        for (tn, lt) in self.list_types.items() {
            if lt.as_pointer() == expected {
                spec = tn;
                break;
            }
        }
    }
    helpers = self.list_helpers.get(spec) if spec is not None else None;
    if helpers is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="variadic parameter",
            name="*",
            help_text="The callee's *args slot did not resolve to a registered native list type; annotate the variadic parameter with a lowerable element type."
        );
        return None;
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    lv = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="varargs.new"
    );
    for e in extras {
        if isinstance(e, tuple) and e and e[0] == "spread.list.val" {
            _src = e[1];
            _src_h = None;
            for (_sn, _slt) in self.list_types.items() {
                if _slt.as_pointer() == _src.type {
                    _src_h = self.list_helpers.get(_sn);
                    break;
                }
            }
            if _src_h is None {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="call argument unpacking",
                    name="*",
                    help_text="The spread list's element type did not resolve to a registered native list; annotate it with a lowerable element type."
                );
                continue;
            }
            i64 = ir.IntType(64);
            _cp_fn = self.builder.function;
            _cp_loop = _cp_fn.append_basic_block("spread.loop");
            _cp_body = _cp_fn.append_basic_block("spread.body");
            _cp_done = _cp_fn.append_basic_block("spread.done");
            _cp_len = self.builder.call(_src_h["len"], [_src], name="spread.len");
            _cp_pre = self.builder.block;
            self.builder.branch(_cp_loop);
            self._builder = ir.IRBuilder(_cp_loop);
            _cp_i = self.builder.phi(i64, name="spread.i");
            _cp_i.add_incoming(ir.Constant(i64, 0), _cp_pre);
            self.builder.cbranch(
                self.builder.icmp_unsigned(">=", _cp_i, _cp_len, name="spread.atend"),
                _cp_done,
                _cp_body
            );
            self._builder = ir.IRBuilder(_cp_body);
            _cp_e = self.builder.call(_src_h["get"], [_src, _cp_i], name="spread.elem");
            _cp_e2 = self._coerce_type(_cp_e, helpers["elem_type"]);
            self._rc_call_with_ctx(
                helpers["append"], [lv, _cp_e2], op="list_init", loc=_loc
            );
            _cp_i1 = self.builder.add(_cp_i, ir.Constant(i64, 1), name="spread.i1");
            _cp_i.add_incoming(_cp_i1, self.builder.block);
            self.builder.branch(_cp_loop);
            self._builder = ir.IRBuilder(_cp_done);
            if isinstance(_src.type, ir.PointerType) and self._is_owned(_src) {
                self._emit_rc_release_simple(_src, op="spread_list", loc=_loc);
            }
            continue;
        }
        if isinstance(e, tuple) and e and e[0] == "spread.val" {
            v = e[1];
        } else {
            v = self._codegen_expr(e);
            if v is None {
                self.emit(
                    E5092, node_override=e, kind="expression", name="variadic argument"
                );
                continue;
            }
        }
        if v is None {
            continue;
        }
        _orig = v;
        v2 = self._coerce_type(v, helpers["elem_type"]);
        self._rc_call_with_ctx(helpers["append"], [lv, v2], op="list_init", loc=_loc);
        if isinstance(_orig.type, ir.PointerType) and self._is_owned(_orig) {
            self._emit_rc_release_simple(_orig, op="list_init", loc=_loc);
        }
    }
    return self._mark_owned(lv);
}

impl NaIRGenCalls._codegen_kwargs_dict(
    nd: uni.FuncCall,
    leftover: dict,
    expected: (ir.Type | None),
    order: (list | None) = None,
    bind_records: (list | None) = None
) -> (ir.Value | None) {
    dict_key: (str | None) = None;
    if expected is not None and isinstance(expected, ir.PointerType) {
        for (dk, dt) in self.dict_types.items() {
            if dt.as_pointer() == expected {
                dict_key = dk;
                break;
            }
        }
    }
    if dict_key is not None and not dict_key.startswith("ptr:") {
        dict_key = None;
    }
    helpers = self.dict_helpers.get(dict_key) if dict_key is not None else None;
    if helpers is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="variadic parameter",
            name="**",
            help_text="The callee's **kwargs slot did not resolve to a registered str-keyed native dict type; annotate the variadic parameter with a lowerable value type."
        );
        return None;
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    dv = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="kwargs.new"
    );

    _skip_dv: (ir.Value | None) = None;
    _unbound: list = [];
    for _br in (bind_records or []) {
        if _br["alloca"] is not None {
            _unbound.append(_br);
        }
    }
    if _unbound {
        _skip_dv = self._rc_call_with_ctx(
            helpers["new"], [], op="new", loc=_loc, name="kwbind.names"
        );
        for _br in _unbound {
            self._rc_call_with_ctx(
                helpers["set_ph"],
                [
                    _skip_dv,
                    self._make_global_string(_br["name"], name_prefix=".kwname"),
                    self._default_arg_fallback(helpers["val_type"]),
                    ir.Constant(ir.IntType(64), self._static_str_hash(_br["name"]))
                ],
                op="dict_init",
                loc=_loc
            );
        }
    }
    _seen_spread = False;
    for _entry in (order or []) {
        (_kind, _payload) = _entry;
        if _kind == "lit" {
            kname: str = _payload;
            if kname not in leftover {
                continue;
            }
            v = self._codegen_expr(leftover[kname]);
            if v is None {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="expression",
                    name=f"keyword argument '{kname}'"
                );
                continue;
            }
            k = self._make_global_string(kname, name_prefix=".kwname");
            _lkh = ir.Constant(ir.IntType(64), self._static_str_hash(kname));
            if _seen_spread {
                self._emit_runtime_raise(
                    self.builder.call(
                        helpers["contains_ph"], [dv, k, _lkh], name="kwargs.dup"
                    ),
                    "TypeError",
                    f"got multiple values for keyword argument '{kname}'"
                );
            }
            _orig = v;
            v2 = self._coerce_type(v, helpers["val_type"]);
            self._rc_call_with_ctx(
                helpers["set_ph"], [dv, k, v2, _lkh], op="dict_init", loc=_loc
            );
            if isinstance(_orig.type, ir.PointerType) and self._is_owned(_orig) {
                self._emit_rc_release_simple(_orig, op="dict_init", loc=_loc);
            }
            continue;
        }
        _seen_spread = True;
        sp_expr = _payload;
        sv = self._codegen_expr(sp_expr);
        if sv is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="call argument unpacking",
                name="**",
                help_text="The spread operand did not lower to a value."
            );
            continue;
        }

        for _rec in (bind_records or []) {
            _kg = self._make_global_string(_rec["name"], name_prefix=".kwname");
            _rkh = ir.Constant(ir.IntType(64), self._static_str_hash(_rec["name"]));
            _has = self.builder.call(
                helpers["contains_ph"], [sv, _kg, _rkh], name="kwbind.has"
            );
            if _rec["alloca"] is None {
                self._emit_runtime_raise(_has, "TypeError", _rec["dup_msg"]);
                continue;
            }
            _flv = self.builder.load(_rec["flag"], name="kwbind.flag");
            self._emit_runtime_raise(
                self.builder.and_(_has, _flv, name="kwbind.dup"),
                "TypeError",
                _rec["dup_msg"]
            );
            _do = self.builder.and_(
                _has, self.builder.not_(_flv, name="kwbind.unset"), name="kwbind.do"
            );
            _bfn = self.builder.block.function;
            _bind_bb = _bfn.append_basic_block("kwbind.set");
            _cont_bb = _bfn.append_basic_block("kwbind.cont");
            self.builder.cbranch(_do, _bind_bb, _cont_bb);
            self.builder.position_at_end(_bind_bb);
            _bv = self.builder.call(
                helpers["get_ph"], [sv, _kg, _rkh], name="kwbind.get"
            );
            _bv = self._coerce_type(_bv, _rec["slot_type"]);
            if isinstance(_rec["slot_type"], ir.PointerType) {
                self._emit_rc_retain(_bv, op="kwbind", loc=_loc);
                _old = self.builder.load(_rec["alloca"], name="kwbind.old");
                self._emit_rc_release_simple(_old, op="kwbind", loc=_loc);
            }
            self.builder.store(_bv, _rec["alloca"]);
            self.builder.store(ir.Constant(ir.IntType(1), 1), _rec["flag"]);
            self.builder.branch(_cont_bb);
            self.builder.position_at_end(_cont_bb);
        }
        assert dict_key is not None , "the helper lookup above needs a key";
        if not self._merge_dict_into(
            dv, sv, helpers, dict_key, _loc, skip_keys=_skip_dv
        ) {
            self.emit(
                E5092,
                node_override=nd,
                kind="call argument unpacking",
                name="**",
                help_text="A `**` spread must be a dict of the same key/value types as the callee's `**kwargs` sink."
            );
            continue;
        }
        if isinstance(sv.type, ir.PointerType) and self._is_owned(sv) {
            self._emit_rc_release_simple(sv, op="dict_init", loc=_loc);
        }
    }
    if _skip_dv is not None {
        self._emit_rc_release_simple(_skip_dv, op="dict_init", loc=_loc);
    }
    return self._mark_owned(dv);
}

impl NaIRGenCalls._merge_dict_into(
    dst: ir.Value,
    src: ir.Value,
    helpers: dict,
    dict_key: str,
    loc: str,
    skip_keys: (ir.Value | None) = None
) -> bool {
    src_t = self.dict_types.get(dict_key);
    if src_t is None
        or not isinstance(src.type, ir.PointerType)
        or src.type != src_t.as_pointer() {
        return False;
    }
    i64 = ir.IntType(64);
    fn = self.builder.block.function;
    head_bb = fn.append_basic_block("kwsp.head");
    body_bb = fn.append_basic_block("kwsp.body");
    step_bb = fn.append_basic_block("kwsp.step");
    end_bb = fn.append_basic_block("kwsp.end");
    idx_slot = self._entry_alloca(i64, "kwsp.idx");
    self.builder.store(ir.Constant(i64, 0), idx_slot);
    self.builder.branch(head_bb);

    self.builder.position_at_end(head_bb);
    idx = self.builder.load(idx_slot, name="kwsp.i");
    n = self.builder.call(helpers["len"], [src], name="kwsp.n");
    self.builder.cbranch(
        self.builder.icmp_signed("<", idx, n, name="kwsp.ok"), body_bb, end_bb
    );

    self.builder.position_at_end(body_bb);
    k = self.builder.call(helpers["get_key"], [src, idx], name="kwsp.k");
    if skip_keys is not None {
        merge_bb = fn.append_basic_block("kwsp.merge");
        self.builder.cbranch(
            self.builder.call(helpers["contains"], [skip_keys, k], name="kwsp.bound"),
            step_bb,
            merge_bb
        );
        self.builder.position_at_end(merge_bb);
    }
    v = self.builder.call(helpers["get_val"], [src, idx], name="kwsp.v");
    self._emit_runtime_raise(
        self.builder.call(helpers["contains"], [dst, k], name="kwsp.dup"),
        "TypeError",
        "got multiple values for a keyword argument"
    );
    self._rc_call_with_ctx(
        helpers["set"],
        [
            dst,
            self._coerce_type(k, helpers["key_type"]),
            self._coerce_type(v, helpers["val_type"])
        ],
        op="dict_init",
        loc=loc
    );
    self.builder.branch(step_bb);

    self.builder.position_at_end(step_bb);
    self.builder.store(
        self.builder.add(idx, ir.Constant(i64, 1), name="kwsp.i.next"), idx_slot
    );
    self.builder.branch(head_bb);

    self.builder.position_at_end(end_bb);
    return True;
}

impl NaIRGenCalls._codegen_call_args(nd: uni.FuncCall) -> list {
    arg_vals: list[ir.Value] = [];
    for param in (nd.params or []) {
        v = self._coerce_narrowed_arg(param, self._codegen_expr(param));
        if v is not None {
            arg_vals.append(v);
        }
    }
    return arg_vals;
}

impl NaIRGenCalls._coerce_narrowed_arg(
    nd: (uni.UniNode | None), val: (ir.Value | None)
) -> (ir.Value | None) {
    if val is None or self._opt_payload_of(val.type) is None {
        return val;
    }
    _arg_nd = nd.value if isinstance(nd, uni.KWPair) else nd;
    if not isinstance(_arg_nd, uni.Expr) or _arg_nd.type is None {
        return val;
    }
    _want = self._lower_type(_arg_nd.type);
    if _want is None
        or isinstance(_want, ir.VoidType)
        or self._opt_payload_of(_want) is not None {
        return val;
    }
    return self._coerce_type(val, _want);
}

impl NaIRGenCalls._codegen_receiver(nd: (uni.UniNode | None)) -> (ir.Value | None) {
    _rv = self._codegen_expr(nd);
    return self._opt_unwrap_attr(_rv) if _rv is not None else None;
}

impl NaIRGenCalls._emit_take_ref(value: ir.Value, op: str, loc: str = "") -> None {
    if isinstance(value.type, ir.PointerType) and not self._is_owned(value) {
        self._emit_rc_retain(value, op=op, loc=loc);
        return;
    }
    if self._opt_ptr_payload_of(value.type) is not None and not self._is_owned(value) {
        _tr_pv = self.builder.extract_value(value, 1, name="takeref.opt.pv");
        self._emit_rc_retain(_tr_pv, op=op, loc=loc);
    }
}

impl NaIRGenCalls._codegen_decorated_call(
    nd: uni.FuncCall, func_name: str
) -> (ir.Value | None) {
    (raw_fn, slot_gv, _dec_names, fnty) = self.decorated_fns[func_name];
    args: list[ir.Value] = self._codegen_bound_args(nd, raw_fn, self_offset=0);
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(fnty.args) {
            coerced.append(self._coerce_type(arg, fnty.args[i]));
        } else {
            coerced.append(arg);
        }
    }
    fptr = self.builder.load(slot_gv, name=f"decslot.{func_name}");
    result = self.builder.call(fptr, coerced, name=f"call.{func_name}");
    self._release_owned_args(coerced, op="call_arg");
    return result;
}

impl NaIRGenCalls._emit_unsupported_builtin_call(
    nd: uni.FuncCall, func_name: str
) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="builtin call",
        name=func_name,
        help_text="This builtin is implemented for some argument types but could not be lowered for the argument(s) at this call site (for example `sum`/`min`/`max` over a `range` rather than a list). Restructure to a supported form, or move the code to a @sv/Python context."
    );
}

impl NaIRGenCalls._emit_new(nd: uni.FuncCall) -> (ir.Value | None) {
    params_l = nd.params or [];
    if not params_l or any([isinstance(p, uni.KWPair) for p in params_l]) {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name="new",
            help_text="new() takes a class followed by positional constructor arguments only."
        );
        return None;
    }
    cls_name = self._get_name(params_l[0]);
    if cls_name is None or cls_name not in self.struct_types {
        cls_name = self._struct_name_of(nd);
    }
    if cls_name is None or cls_name not in self.struct_types {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name="new",
            help_text="new() lowers natively only when the first argument statically names an archetype whose native layout is visible to this module; dynamic class values are not supported in native code."
        );
        return None;
    }
    return self._codegen_instantiation(
        nd, type_name_override=cls_name, ctor_params=list(params_l[1:])
    );
}

impl NaIRGenCalls._native_module_call_target(nd: uni.FuncCall) -> (tuple | None) {
    trailer = nd.target;
    if not isinstance(trailer, uni.AtomTrailer) or not trailer.is_attr {
        return None;
    }

    if isinstance(trailer.target, uni.AtomTrailer) {
        return None;
    }
    mod_name = self._get_name(trailer.target);
    method_name = self._get_name(trailer.right);
    if mod_name is None or method_name is None {
        return None;
    }

    if (
        self?._native_module_imports
        and mod_name in self._native_module_imports
        and mod_name not in self.local_vars
        and mod_name not in self.struct_types
    ) {
        return (mod_name, method_name);
    }
    return None;
}

impl NaIRGenCalls._codegen_intrinsic(
    nd: uni.FuncCall, intr: IntrinsicEntry
) -> (ir.Value | None) {
    import from jaclang.compiler.intrinsic_registry { IntrinsicDispatch }

    positional: list = [];
    _has_kw = False;
    for p in (nd.params or []) {
        if isinstance(p, uni.KWPair) {
            _has_kw = True;
        } else {
            positional.append(p);
        }
    }
    if _has_kw {
        self._emit_intrinsic_misuse(nd, intr, "keyword arguments are not accepted");
        return None;
    }
    if len(positional) != intr.arity() {
        self._emit_intrinsic_misuse(
            nd, intr, f"expected {intr.arity()} argument(s), got {len(positional)}"
        );
        return None;
    }
    _emitters: dict[IntrinsicDispatch, Callable[..., (ir.Value | None)]] = {
        IntrinsicDispatch.RC_RUNTIME: self._emit_intrinsic_rc_runtime,
        IntrinsicDispatch.FLOAT_BITS: self._emit_intrinsic_float_bits,
        IntrinsicDispatch.BITS_FLOAT: self._emit_intrinsic_bits_float,
        IntrinsicDispatch.MEM_LOAD: self._emit_intrinsic_mem_load,
        IntrinsicDispatch.MEM_STORE: self._emit_intrinsic_mem_store,
        IntrinsicDispatch.ATOMIC_XCHG: self._emit_intrinsic_atomic_xchg,
        IntrinsicDispatch.CALL_DTOR: self._emit_intrinsic_call_dtor
    };
    handler = _emitters.get(intr.dispatch);
    if handler is None {
        self.emit(
            E9001,
            node_override=nd,
            pass_name="NaIRGenPass",
            details=f"intrinsic '{intr.name}' registers dispatch key {intr.dispatch.value} with no mapped emitter"
        );
        return None;
    }
    return handler(nd, intr, positional);
}

impl NaIRGenCalls._emit_intrinsic_misuse(
    nd: uni.FuncCall, intr: IntrinsicEntry, reason: str
) -> None {
    for e in self.errors_had {
        if (
            e.code is E5095
            and e.loc.mod_path == nd.loc.mod_path
            and e.loc.first_line == nd.loc.first_line
            and e.loc.col_start == nd.loc.col_start
        ) {
            return;
        }
    }
    self.emit(E5095, node_override=nd, name=intr.name, reason=reason);
}

impl NaIRGenCalls._intrinsic_operand(
    nd: uni.FuncCall, intr: IntrinsicEntry, arg: uni.Expr, spec: str
) -> (ir.Value | None) {
    arg_val = self._codegen_expr(arg);
    if arg_val is None {
        self._emit_intrinsic_misuse(nd, intr, "operand did not lower to a value");
        return None;
    }
    if spec == "i64" and isinstance(arg_val.type, ir.PointerType) {
        arg_val = self.builder.ptrtoint(arg_val, ir.IntType(64), name="intr.addr");
    }
    if not isinstance(arg_val.type, (ir.IntType, ir.FloatType, ir.DoubleType)) {
        self._emit_intrinsic_misuse(
            nd,
            intr,
            f"operand of type {arg_val.type} does not fit registered parameter type {spec}"
        );
        return None;
    }
    if spec == "f64" {
        if not isinstance(arg_val.type, ir.DoubleType) {
            arg_val = self._coerce_type(arg_val, ir.DoubleType());
        }
        return arg_val;
    }
    if not isinstance(arg_val.type, ir.IntType) or arg_val.type.width != 64 {
        arg_val = self._coerce_type(arg_val, ir.IntType(64));
    }
    return arg_val;
}

impl NaIRGenCalls._emit_intrinsic_rc_runtime(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list
) -> (ir.Value | None) {
    if intr.gc_mode_gate is not None and self._gc_mode() != intr.gc_mode_gate {
        return None;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    self.builder.call(self.llvm_module.get_global(intr.name), []);
    return None;
}

impl NaIRGenCalls._emit_intrinsic_float_bits(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list
) -> (ir.Value | None) {
    arg_val = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    if arg_val is None {
        return None;
    }
    return self.builder.bitcast(arg_val, ir.IntType(64), name="float_bits");
}

impl NaIRGenCalls._emit_intrinsic_bits_float(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list
) -> (ir.Value | None) {
    arg_val = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    if arg_val is None {
        return None;
    }
    return self.builder.bitcast(arg_val, ir.DoubleType(), name="bits_float");
}

impl NaIRGenCalls._emit_intrinsic_mem_load(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list
) -> (ir.Value | None) {
    addr = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    if addr is None {
        return None;
    }
    i64 = ir.IntType(64);
    slot = self.builder.inttoptr(addr, i64.as_pointer(), name="mem.p");
    return self.builder.load(slot, name="mem.ld");
}

impl NaIRGenCalls._emit_intrinsic_mem_store(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list
) -> (ir.Value | None) {
    addr = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    val = self._intrinsic_operand(nd, intr, args[1], intr.param_specs[1]);
    if addr is None or val is None {
        return None;
    }
    i64 = ir.IntType(64);
    slot = self.builder.inttoptr(addr, i64.as_pointer(), name="mem.p");
    self.builder.store(val, slot);
    return None;
}

impl NaIRGenCalls._emit_intrinsic_atomic_xchg(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list
) -> (ir.Value | None) {
    addr = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    val = self._intrinsic_operand(nd, intr, args[1], intr.param_specs[1]);
    if addr is None or val is None {
        return None;
    }
    i64 = ir.IntType(64);
    slot = self.builder.inttoptr(addr, i64.as_pointer(), name="mem.p");
    return self.builder.atomic_rmw(
        "xchg", slot, val, ordering="acq_rel", name="mem.xchg"
    );
}

impl NaIRGenCalls._emit_intrinsic_call_dtor(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list
) -> (ir.Value | None) {
    fn_val = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    obj_val = self._intrinsic_operand(nd, intr, args[1], intr.param_specs[1]);
    if fn_val is None or obj_val is None {
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    dtor_ty = ir.FunctionType(ir.VoidType(), [i8p]).as_pointer();
    fn_ptr = self.builder.inttoptr(fn_val, dtor_ty, name="dtor.fn");
    obj_ptr = self.builder.inttoptr(obj_val, i8p, name="dtor.obj");
    self.builder.call(fn_ptr, [obj_ptr]);
    return None;
}

impl NaIRGenCalls._codegen_call(nd: uni.FuncCall) -> (ir.Value | None) {
    import from jaclang.compiler.intrinsic_registry { INTRINSIC_REGISTRY }
    import from jaclang.compiler.symbol_utils {
        erased_field_marker_default,
        erased_identity_call_arg,
        is_erased_field_marker
    }

    _identity_arg = erased_identity_call_arg(nd);
    if _identity_arg is not None {
        return self._codegen_expr(_identity_arg);
    }

    if is_erased_field_marker(nd) {
        _marker_default = erased_field_marker_default(nd);
        return (
            self._codegen_expr(_marker_default) if _marker_default is not None else None
        );
    }

    _call_kind = nd.call_kind or "";

    _sized_call = self._codegen_sized_builtin_call(
        nd, self._get_name(nd.target), _call_kind
    );
    if _sized_call is not None {
        return _sized_call;
    }

    _mod_qual: (str | None) = None;
    if _call_kind == "method" {
        _mod_fn = self._native_module_call_target(nd);
        if _mod_fn is None {
            return self._codegen_method_call(nd);
        }
        (_mod_qual, func_name) = _mod_fn;
    } else {
        func_name = self._get_name(nd.target);
        if func_name is None {
            _erased_ctor = self._erased_generic_ctor(nd);
            if _erased_ctor is not None {
                return self._codegen_instantiation(nd, type_name_override=_erased_ctor);
            }
            return None;
        }
    }

    _intrinsic_entry = INTRINSIC_REGISTRY.get(func_name);
    if _intrinsic_entry is not None {
        return self._codegen_intrinsic(nd, _intrinsic_entry);
    }

    if _call_kind != "method" and func_name not in self.local_vars {
        _ec_name = self._enum_ctor_target(nd);
        if _ec_name is not None {
            return self._codegen_enum_ctor(nd, _ec_name);
        }
    }

    import from jaclang.compiler.types { types as jtypes }
    _callee_t = nd.target?.type;
    if isinstance(_callee_t, jtypes.ClassType)
        and _callee_t.private.distinct_key is not None {
        _cast_params = nd.params or [];
        if len(_cast_params) == 1 {
            _cast_arg = self._codegen_expr(_cast_params[0]);
            if _cast_arg is not None {
                _cast_res = self._dispatch_builtin(
                    _callee_t.shared.class_name,
                    [_cast_arg],
                    kwargs=self._split_call_kwargs(nd),
                    kw_node=nd,
                    type_key=(self._type_key_of(_cast_params[0]) or "")
                );
                if isinstance(_cast_arg.type, ir.PointerType)
                    and self._is_owned(_cast_arg) {
                    self._emit_rc_release_simple(
                        _cast_arg, op="distinct_cast_arg", loc=""
                    );
                }
                if _cast_res is not None {
                    return _cast_res;
                }
            }
        }
        self.emit(
            E5092,
            node_override=nd,
            kind="distinct cast",
            name=func_name or _callee_t.shared.class_name
        );
        return None;
    }

    if _call_kind == "builtin" {
        if func_name == "print" {
            return self._emit_print(nd);
        }

        if func_name == "managed" {
            params_l = nd.params or [];
            if not params_l {
                return None;
            }
            _managed_arg = params_l[0];
            if not isinstance(_managed_arg, uni.FuncCall) {
                return self._codegen_expr(_managed_arg);
            }
            _saved_managed_ctor = self._managed_ctor_node;
            self._managed_ctor_node = id(_managed_arg);
            try {
                return self._codegen_expr(_managed_arg);
            } finally {
                self._managed_ctor_node = _saved_managed_ctor;
            }
        }

        if func_name == "new" {
            return self._emit_new(nd);
        }

        if func_name == "take" {
            return self._emit_take(nd);
        }

        if func_name == "swap" {
            return self._emit_swap(nd);
        }

        if func_name == "Region" {
            import from jaclang.compiler.expr_keys { is_builtin_region_type }
            if is_builtin_region_type(nd.type) or "Region" not in self.struct_types {
                return self._region_new_handle();
            }
            return self._codegen_instantiation(nd);
        }

        if func_name == "region_of" {
            params_l = nd.params or [];
            if not params_l {
                return None;
            }
            _rof_val = self._codegen_expr(params_l[0]);
            if _rof_val is None {
                return None;
            }
            return self._region_of_value(_rof_val);
        }

        if func_name == "isinstance" {
            return self._emit_isinstance(nd);
        }

        if func_name == "type" {
            _cid_params = nd.params or [];
            if len(_cid_params) == 1 {
                _scalar = self._scalar_shape(_cid_params[0]);
                if _scalar is not None {
                    return self._codegen_type_name_str(_scalar.name);
                }
                _cid = self._codegen_class_id(_cid_params[0]);
                if _cid is not None {
                    return _cid;
                }
            }
        }

        if func_name == "id" {
            _id_params = nd.params or [];
            if len(_id_params) == 1 {
                _id_val = self._codegen_expr(_id_params[0]);
                if _id_val is not None
                    and self._opt_payload_of(_id_val.type) is not None {
                    _id_val = self._coerce_type(
                        _id_val, self._opt_payload_of(_id_val.type)
                    );
                }
                if (_id_val is not None and isinstance(_id_val.type, ir.PointerType)) {
                    return self.builder.ptrtoint(
                        _id_val, ir.IntType(64), name="id.p2i"
                    );
                }
                if (
                    _id_val is not None
                    and self?.jacval_type
                    and _id_val.type == self.jacval_type
                ) {
                    return self.builder.extract_value(_id_val, 1, name="id.jv.payload");
                }
            }
        }

        if func_name == "len" {
            params_l = nd.params or [];
            if params_l {
                elem_type_name: (str | None) = None;
                arg_val = self._codegen_expr(params_l[0]);
                if arg_val is not None
                    and self._opt_payload_of(arg_val.type) is not None {
                    arg_val = self._coerce_type(
                        arg_val, self._opt_payload_of(arg_val.type)
                    );
                }
                if arg_val is not None {
                    _len_result: (ir.Value | None) = None;

                    if self._str_desc_ty is not None
                        and arg_val.type == self._str_desc_ty {
                        _len_result = self.builder.extract_value(
                            arg_val,
                            len(list(self._str_desc_ty.elements)) - 1,
                            name="s.len.o1"
                        );
                    }

                    if _len_result is None
                        and self?.jacval_type
                        and arg_val.type == self.jacval_type {
                        _len_result = self._codegen_any_len(arg_val);
                    }

                    if _len_result is None and self._is_bytes_value(arg_val) {
                        _len_result = self._bytes_len_val(arg_val);
                    }

                    if _len_result is None {
                        for (dict_key, helpers) in self.dict_helpers.items() {
                            dict_type = self.dict_types.get(dict_key);
                            if dict_type is not None
                                and arg_val.type == dict_type.as_pointer() {
                                _len_result = self.builder.call(
                                    helpers["len"], [arg_val], name="dict.len"
                                );
                                break;
                            }
                        }
                    }

                    if _len_result is None {
                        for (set_key, helpers) in self.set_helpers.items() {
                            set_type = self.set_types.get(set_key);
                            if set_type is not None
                                and arg_val.type == set_type.as_pointer() {
                                _len_result = self.builder.call(
                                    helpers["len"], [arg_val], name="set.len"
                                );
                                break;
                            }
                        }
                    }

                    if _len_result is None {
                        if elem_type_name is None {
                            elem_type_name = self._infer_list_elem_type(arg_val);
                        }
                        if elem_type_name is not None {
                            helpers = self.list_helpers.get(elem_type_name);
                            if helpers is not None {
                                _len_result = self.builder.call(
                                    helpers["len"], [arg_val], name="list.len"
                                );
                            }
                        }
                    }

                    if _len_result is None
                        and arg_val.type == ir.IntType(8).as_pointer() {
                        _len_result = self._call_str_len(
                            self.builder, arg_val, name="str.len"
                        );
                    }
                    if _len_result is not None {
                        if isinstance(arg_val.type, ir.PointerType)
                            and self._is_owned(arg_val) {
                            self._emit_rc_release_simple(arg_val, op="len_arg", loc="");
                        }
                        return _len_result;
                    }
                }
            }
        }

        if func_name == "iter" {
            built = self._build_iter_from_expr(nd);
            if built is not None {
                (iter_val, _ename, _etype) = built;
                return iter_val;
            }
            self._emit_unsupported_builtin_call(nd, "iter");
            return None;
        }
        if func_name == "next" {
            return self._codegen_next(nd);
        }

        if func_name == "complex" {
            params_l = nd.params or [];
            if len(params_l) >= 2 {
                real_val = self._codegen_expr(params_l[0]);
                imag_val = self._codegen_expr(params_l[1]);
                if real_val is not None and imag_val is not None {
                    f64 = ir.DoubleType();
                    i64 = ir.IntType(64);
                    real_f = self._coerce_type(real_val, f64)
                        if not isinstance(real_val.type, ir.DoubleType)
                        else real_val;
                    imag_f = self._coerce_type(imag_val, f64)
                        if not isinstance(imag_val.type, ir.DoubleType)
                        else imag_val;
                    ctype = self.complex_struct_type;
                    raw = self.builder.call(
                        self.rc_alloc_fn, [ir.Constant(i64, 16)], name="complex.raw"
                    );
                    ptr = self.builder.bitcast(
                        raw, ctype.as_pointer(), name="complex.ptr"
                    );
                    rp = self.builder.gep(
                        ptr,
                        [
                            ir.Constant(ir.IntType(32), 0),
                            ir.Constant(ir.IntType(32), 0)
                        ],
                        name="complex.re.ptr"
                    );
                    ip = self.builder.gep(
                        ptr,
                        [
                            ir.Constant(ir.IntType(32), 0),
                            ir.Constant(ir.IntType(32), 1)
                        ],
                        name="complex.im.ptr"
                    );
                    self.builder.store(real_f, rp);
                    self.builder.store(imag_f, ip);
                    return ptr;
                }
            }
        }

        if func_name == "range" {
            params_l = nd.params or [];
            i64 = ir.IntType(64);
            i32 = ir.IntType(32);
            start_v: (ir.Value | None) = None;
            stop_v: (ir.Value | None) = None;
            step_v: (ir.Value | None) = None;
            if len(params_l) == 1 {
                start_v = ir.Constant(i64, 0);
                stop_v = self._codegen_expr(params_l[0]);
                step_v = ir.Constant(i64, 1);
            } elif len(params_l) == 2 {
                start_v = self._codegen_expr(params_l[0]);
                stop_v = self._codegen_expr(params_l[1]);
                step_v = ir.Constant(i64, 1);
            } elif len(params_l) >= 3 {
                start_v = self._codegen_expr(params_l[0]);
                stop_v = self._codegen_expr(params_l[1]);
                step_v = self._codegen_expr(params_l[2]);
            }
            if start_v is not None and stop_v is not None and step_v is not None {
                start_v = self._coerce_type(start_v, i64);
                stop_v = self._coerce_type(stop_v, i64);
                step_v = self._coerce_type(step_v, i64);
                rtype = self.range_struct_type;
                raw = self.builder.call(
                    self.rc_alloc_fn, [ir.Constant(i64, 24)], name="range.raw"
                );
                ptr = self.builder.bitcast(raw, rtype.as_pointer(), name="range.ptr");
                z0 = ir.Constant(i32, 0);
                self.builder.store(
                    start_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 0)], name="range.sp")
                );
                self.builder.store(
                    stop_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 1)], name="range.ep")
                );
                self.builder.store(
                    step_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 2)], name="range.tp")
                );
                return ptr;
            }
        }

        if func_name == "slice" {
            params_l = nd.params or [];
            i64 = ir.IntType(64);
            i32 = ir.IntType(32);
            start_v: (ir.Value | None) = None;
            stop_v: (ir.Value | None) = None;
            step_v: (ir.Value | None) = None;
            if len(params_l) == 1 {
                start_v = ir.Constant(i64, 0);
                stop_v = self._codegen_expr(params_l[0]);
                step_v = ir.Constant(i64, 1);
            } elif len(params_l) == 2 {
                start_v = self._codegen_expr(params_l[0]);
                stop_v = self._codegen_expr(params_l[1]);
                step_v = ir.Constant(i64, 1);
            } elif len(params_l) >= 3 {
                start_v = self._codegen_expr(params_l[0]);
                stop_v = self._codegen_expr(params_l[1]);
                step_v = self._codegen_expr(params_l[2]);
            }
            if start_v is not None and stop_v is not None and step_v is not None {
                start_v = self._coerce_type(start_v, i64);
                stop_v = self._coerce_type(stop_v, i64);
                step_v = self._coerce_type(step_v, i64);
                stype = self.slice_struct_type;
                raw = self.builder.call(
                    self.rc_alloc_fn, [ir.Constant(i64, 24)], name="slice.raw"
                );
                ptr = self.builder.bitcast(raw, stype.as_pointer(), name="slice.ptr");
                z0 = ir.Constant(i32, 0);
                self.builder.store(
                    start_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 0)], name="slice.sp")
                );
                self.builder.store(
                    stop_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 1)], name="slice.ep")
                );
                self.builder.store(
                    step_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 2)], name="slice.tp")
                );
                return ptr;
            }
        }

        if func_name
            in ("abs", "min", "max", "pow", "divmod", "sum", "any", "all", "format") {
            params_l = nd.params or [];
            arg_vals: list[ir.Value] = [];
            arg_nodes: list = [];
            for param in params_l {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                    arg_nodes.append(param);
                }
            }
            if arg_vals {
                result = self._dispatch_builtin(
                    func_name, arg_vals, arg_nodes=arg_nodes
                );

                for _barg in arg_vals {
                    if isinstance(_barg.type, ir.PointerType)
                        and self._is_owned(_barg) {
                        self._emit_rc_release_simple(_barg, op="builtin_arg", loc="");
                    }
                }
                if result is not None {
                    return result;
                }

                self._emit_unsupported_builtin_call(nd, func_name);
                return None;
            }
        }

        if func_name == "bytearray" and not (nd.params or []) {
            _ba_empty = self._dispatch_builtin(
                "bytearray", [], kwargs=self._split_call_kwargs(nd), kw_node=nd
            );
            if _ba_empty is not None {
                return _ba_empty;
            }
            self._emit_unsupported_builtin_call(nd, func_name);
            return None;
        }

        if func_name
            in (
                "ord",
                "int",
                "chr",
                "str",
                "hex",
                "oct",
                "bin",
                "round",
                "float",
                "bool",
                "sorted",
                "reversed",
                "list",
                "set",
                "frozenset",
                "dict",
                "bytes",
                "bytearray",
                "id",
                "hash",
                "repr",
                "ascii"
            ) {
            params_l = nd.params or [];
            _ez_peer = self._spec_from_container_ptr(self._peer_container_ty)
                if not params_l and func_name in ("list", "set")
                else None;
            if not params_l
                and func_name in ("list", "set")
                and (self._empty_ctor_args_of(nd) or _ez_peer is not None) {
                _ez_args = self._empty_ctor_args_of(nd);
                _ez_elem: ir.Type = ir.IntType(8).as_pointer();
                _ez_spec = "ptr";
                if not _ez_args and _ez_peer is not None {
                    _ez_pt = self.set_helpers
                        if func_name == "set"
                        else self.list_helpers;
                    _ez_ph = _ez_pt.get(_ez_peer);
                    if _ez_ph is not None {
                        return self.builder.call(
                            _ez_ph["new"], [], name=f"{func_name}.empty"
                        );
                    }
                }
                if _ez_args {
                    _ez_low = self._elem_storage_llvm(_ez_args[0]);
                    if _ez_low is not None {
                        if self._str_desc_ty is not None
                            and _ez_low == self._str_desc_ty {
                            _ez_low = ir.IntType(8).as_pointer();
                        }
                        _ez_elem = _ez_low;
                        if isinstance(_ez_low, ir.DoubleType) {
                            _ez_spec = "f64";
                        } elif isinstance(_ez_low, ir.PointerType) {
                            _ez_spec = "ptr";
                        } else {
                            _ez_spec = "i64";
                        }
                    }
                }
                if func_name == "set" {
                    self._emit_set_helpers(_ez_spec, _ez_elem);
                    _ez_h = self.set_helpers.get(_ez_spec);
                } else {
                    self._emit_list_helpers(_ez_spec, _ez_elem);
                    _ez_h = self.list_helpers.get(_ez_spec);
                }
                if _ez_h is not None {
                    return self.builder.call(
                        _ez_h["new"], [], name=f"{func_name}.empty"
                    );
                }
                self._emit_unsupported_builtin_call(nd, func_name);
                return None;
            }
            if params_l {
                arg_val = self._codegen_expr(params_l[0]);
                if arg_val is not None {
                    result = self._dispatch_builtin(
                        func_name,
                        [arg_val],
                        kwargs=self._split_call_kwargs(nd),
                        kw_node=nd,
                        type_key=(self._type_key_of(params_l[0]) or ""),
                        arg_nodes=[params_l[0]]
                    );

                    if isinstance(arg_val.type, ir.PointerType)
                        and self._is_owned(arg_val) {
                        self._emit_rc_release_simple(
                            arg_val, op="builtin1_arg", loc=""
                        );
                    }
                    if result is not None {
                        return result;
                    }

                    if not self._split_call_kwargs(nd) {
                        self._emit_unsupported_builtin_call(nd, func_name);
                    }
                    return None;
                }
            }
        }

        if func_name == "input" {
            i8p = ir.IntType(8).as_pointer();
            params_l = nd.params or [];

            if params_l {
                prompt_val = self._codegen_expr(params_l[0]);
                if prompt_val is not None {
                    _prompt_orig = prompt_val;
                    printf = self._get_printf();
                    fmt = self._get_fmt_string("%s");
                    fmt_ptr = self.builder.bitcast(fmt, i8p, name="fmt.ptr");

                    if isinstance(prompt_val.type, ir.PointerType)
                        and prompt_val.type != i8p {
                        prompt_val = self.builder.bitcast(
                            prompt_val, i8p, name="prompt.cast"
                        );
                    }
                    self.builder.call(printf, [fmt_ptr, prompt_val]);

                    if isinstance(_prompt_orig.type, ir.PointerType)
                        and self._is_owned(_prompt_orig) {
                        self._emit_rc_release_simple(
                            _prompt_orig, op="input_prompt", loc=""
                        );
                    }
                }
            }

            buf_size = 256;
            buf_type = ir.ArrayType(ir.IntType(8), buf_size);
            buf = self.builder.alloca(buf_type, name="input.buf");
            buf_ptr = self.builder.bitcast(buf, i8p, name="input.ptr");

            import platform;
            stdin_name = "__stdinp" if platform.system() == "Darwin" else "stdin";
            if stdin_name not in self.extern_funcs {
                stdin_type = i8p;
                stdin_global = ir.GlobalVariable(
                    self.llvm_module, stdin_type, name=stdin_name
                );
                stdin_global.linkage = "external";
                if "windows" in str(self.llvm_module.triple or "") {
                    stdin_global.storage_class = "dllimport";
                }
                self.extern_funcs[stdin_name] = stdin_global;
            }
            stdin_var = self.extern_funcs[stdin_name];
            stdin_val = self.builder.load(stdin_var, name="stdin.val");
            fgets = self._get_or_declare_extern(
                "fgets", i8p, [i8p, ir.IntType(32), i8p]
            );
            size_val = ir.Constant(ir.IntType(32), buf_size);
            fgets_ret = self.builder.call(
                fgets, [buf_ptr, size_val, stdin_val], name="fgets.result"
            );

            func = self.builder.function;
            eof_bb = func.append_basic_block(name="input.eof");
            ok_bb = func.append_basic_block(name="input.ok");
            merge_bb = func.append_basic_block(name="input.merge");
            null_ptr = ir.Constant(i8p, None);
            is_eof = self.builder.icmp_signed("==", fgets_ret, null_ptr, name="is.eof");
            self.builder.cbranch(is_eof, eof_bb, ok_bb);

            self.builder.position_at_start(eof_bb);
            eof_str = self._str_alloc(
                self.builder, ir.Constant(ir.IntType(64), 1), name="eof.str"
            );
            self._str_finish(self.builder, eof_str, ir.Constant(ir.IntType(64), 0));
            self.builder.branch(merge_bb);
            eof_bb_end = self.builder.block;

            self.builder.position_at_start(ok_bb);

            slen = self._call_str_len_raw(self.builder, buf_ptr, name="input.len");

            alloc_size = self.builder.add(
                slen, ir.Constant(ir.IntType(64), 1), name="alloc.size"
            );
            result_ptr = self._str_alloc(self.builder, alloc_size, name="input.result");
            memcpy = self._get_or_declare_extern(
                "memcpy", i8p, [i8p, i8p, ir.IntType(64)]
            );
            self.builder.call(memcpy, [result_ptr, buf_ptr, alloc_size]);

            has_len = self.builder.icmp_signed(
                ">", slen, ir.Constant(ir.IntType(64), 0), name="has.len"
            );
            strip_bb = func.append_basic_block(name="input.strip");
            nostrip_bb = func.append_basic_block(name="input.nostrip");
            self.builder.cbranch(has_len, strip_bb, nostrip_bb);
            self.builder.position_at_start(strip_bb);
            last_idx = self.builder.sub(
                slen, ir.Constant(ir.IntType(64), 1), name="last.idx"
            );
            last_ptr = self.builder.gep(result_ptr, [last_idx], name="last.ptr");
            last_byte = self.builder.load(last_ptr, name="last.byte");
            is_newline = self.builder.icmp_signed(
                "==", last_byte, ir.Constant(ir.IntType(8), 10), name="is.nl"
            );

            null_byte = ir.Constant(ir.IntType(8), 0);
            store_val = self.builder.select(
                is_newline, null_byte, last_byte, name="strip.nl"
            );
            self.builder.store(store_val, last_ptr);

            strip_cr_bb = func.append_basic_block(name="input.strip.cr");
            self.builder.cbranch(is_newline, strip_cr_bb, nostrip_bb);
            self.builder.position_at_start(strip_cr_bb);

            has_cr_len = self.builder.icmp_signed(
                ">=", slen, ir.Constant(ir.IntType(64), 2), name="has.cr.len"
            );
            strip_cr_check_bb = func.append_basic_block(name="input.strip.cr.check");
            self.builder.cbranch(has_cr_len, strip_cr_check_bb, nostrip_bb);
            self.builder.position_at_start(strip_cr_check_bb);

            cr_idx = self.builder.sub(
                slen, ir.Constant(ir.IntType(64), 2), name="cr.idx"
            );
            cr_ptr = self.builder.gep(result_ptr, [cr_idx], name="cr.ptr");
            cr_byte = self.builder.load(cr_ptr, name="cr.byte");
            is_cr = self.builder.icmp_signed(
                "==", cr_byte, ir.Constant(ir.IntType(8), 13), name="is.cr"
            );

            store_cr_val = self.builder.select(
                is_cr, null_byte, cr_byte, name="strip.cr"
            );
            self.builder.store(store_cr_val, cr_ptr);
            self.builder.branch(nostrip_bb);
            self.builder.position_at_start(nostrip_bb);
            final_len = self._call_str_len(
                self.builder, result_ptr, name="input.final.len"
            );
            self._str_finish(self.builder, result_ptr, final_len);
            self.builder.branch(merge_bb);
            ok_bb_end = self.builder.block;

            self.builder.position_at_start(merge_bb);
            phi = self.builder.phi(i8p, name="input.phi");
            phi.add_incoming(eof_str, eof_bb_end);
            phi.add_incoming(result_ptr, ok_bb_end);
            return phi;
        }

        if func_name == "open" {
            _open_result = self._emit_open(nd);
            if _open_result is not None {
                return _open_result;
            }
            self.emit(E5092, node_override=nd, kind="function", name=func_name);
            return None;
        }
    }

    if func_name in self.struct_types {
        return self._codegen_instantiation(nd);
    }
    _alias_arch = self._arch_alias_target(nd.target);
    if _alias_arch is not None and _alias_arch in self.struct_types {
        return self._codegen_instantiation(nd, type_name_override=_alias_arch);
    }
    if (
        func_name in self._native_skipped_methods and func_name not in self.generic_fns
    ) {
        self.emit(
            E5092,
            node_override=nd,
            kind="function",
            name=func_name,
            help_text=f"'{func_name}' demoted to its Python-only implementation "
            f"(native seam), so a native caller cannot reach it; hoist the "
            f"blocking construct out of '{func_name}' or move this caller off "
            f"the native pathway."
        );
        return None;
    }
    if func_name in self.decorated_fns {
        return self._codegen_decorated_call(nd, func_name);
    }
    func = self.func_symtab.get(func_name);
    if func is not None and _mod_qual is not None {
        _dm = self._func_def_mod.get(func_name);
        if _dm is not None and _dm != _mod_qual {
            func = None;
        }
    }
    if func is None {
        manifest = self.ir_in.gen.interop_manifest;
        binding = manifest.bindings.get(func_name);
        _src_ab: (uni.Ability | None) = None;
        if binding is not None
            and binding.source_module is not None
            and func_name not in self.generic_fns {
            _src_ab = self._find_source_ability(binding.source_module, func_name);
            if _src_ab is not None and _src_ab.type_params {
                self.generic_fns[func_name] = _src_ab;
            }
        }
        if binding is not None
            and func_name not in self.generic_fns
            and (
                binding.source_context.value == "server"
                or (
                    binding.source_context.value == "native"
                    and binding.source_module is not None
                )
            ) {
            sig = _src_ab.signature
                if _src_ab is not None
                    and isinstance(_src_ab.signature, uni.FuncSignature)
                else None;
            if sig is None {
                sig = self._callee_sig_of(nd);
            }
            if sig is None
                and isinstance(binding.ast_node, uni.Ability)
                and isinstance(binding.ast_node.signature, uni.FuncSignature) {
                sig = binding.ast_node.signature;
            }
            if sig is None {
                self.emit(
                    E5092, node_override=nd, kind="function signature", name=func_name
                );
                return None;
            }
            if sig.varargs is not None or sig.kwargs is not None {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="function",
                    name=func_name,
                    help_text="A variadic function cannot be called across the native interop boundary yet; wrap it in a fixed-arity function on the defining side."
                );
                return None;
            }
            param_ir_types: list = [];
            for p in sig.get_parameters() {
                param_ir_types.append(
                    self._resolve_jac_type(p.type_tag)
                        if p.type_tag is not None
                        else ir.IntType(64)
                );
            }
            ret_ir_type = self._resolve_jac_type(sig.return_type);
            func = self._get_or_declare_extern(func_name, ret_ir_type, param_ir_types);
        }
    }
    if func is None and func_name in self.generic_fns {
        func = self._instantiate_generic(nd, func_name);
        if func is None {
            return None;
        }
    }
    if func is None {
        if func_name in self.local_vars {
            _alloca = self.local_vars[func_name];
            _loaded = self.builder.load(_alloca, name=f"fptr.{func_name}");
            _clos_name = self._closure_struct_of(_loaded.type);
            if _clos_name is not None {
                return self._codegen_closure_call(nd, _loaded, _clos_name);
            }
            if (
                isinstance(_loaded.type, ir.PointerType)
                and isinstance(_loaded.type.pointee, ir.FunctionType)
            ) {
                _fn_type = _loaded.type.pointee;
                _iargs: list[ir.Value] = [];
                _iparams = nd.params or [];
                for _ip in _iparams {
                    _iv = self._codegen_expr(_ip);
                    if _iv is not None {
                        _iargs.append(_iv);
                    }
                }
                _icoerced: list[ir.Value] = [];
                for (_ii, _ia) in enumerate(_iargs) {
                    if _ii < len(_fn_type.args) {
                        _icoerced.append(self._coerce_type(_ia, _fn_type.args[_ii]));
                    } else {
                        _icoerced.append(_ia);
                    }
                }

                if func_name in self.lambda_captures {
                    for (_cname, _c_alloca) in self.lambda_captures[func_name] {
                        _cval = self.builder.load(_c_alloca, name=f"cap.{_cname}");
                        _icoerced.append(_cval);
                    }
                }
                _icall_result = self.builder.call(
                    _loaded, _icoerced, name=f"icall.{func_name}"
                );

                for _icarg in _iargs {
                    if isinstance(_icarg.type, ir.PointerType)
                        and self._is_owned(_icarg) {
                        self._emit_rc_release_simple(_icarg, op="icall_arg", loc="");
                    }
                }
                return _icall_result;
            }
        }

        if func_name in self.global_vars {
            _gvar = self.global_vars[func_name];
            _gloaded = self.builder.load(_gvar, name=f"fptr.{func_name}");
            _gclos_name = self._closure_struct_of(_gloaded.type);
            if _gclos_name is not None {
                return self._codegen_closure_call(nd, _gloaded, _gclos_name);
            }
        }

        if _call_kind != "builtin" {
            self.emit(E5092, node_override=nd, kind="function", name=func_name);
        }
        return None;
    }

    args: list[ir.Value] = self._codegen_bound_args(nd, func, self_offset=0);

    if func_name in self.clib_fn_abi {
        return self._codegen_clib_call(func, func_name, args);
    }

    _is_foreign = func_name in self.clib_extern_names;
    coerced: list[ir.Value] = [];

    _clib_str_args: set = set();
    _clib_str_ret = False;
    _clib_managed_ret = False;
    if _is_foreign {
        import from jaclang.compiler.backends.native.foreign { declared_type_name }
        _clib_sig = self._callee_sig_of(nd);
        if _clib_sig is not None {
            for (_ci, _cp) in enumerate(_clib_sig.get_parameters()) {
                if _cp.type_tag is not None
                    and declared_type_name(_cp.type_tag.tag) == "str" {
                    _clib_str_args.add(_ci);
                }
            }
            _clib_ret_name = declared_type_name(_clib_sig.return_type) or "";
            _clib_str_ret = _clib_ret_name == "str";
            _clib_managed_ret = _clib_ret_name.split("[")[0] in ("list", "dict", "set");
        }
    }
    release_args: list[ir.Value] = [];
    _i8ptr = ir.IntType(8).as_pointer();
    for (i, arg) in enumerate(args) {
        if (
            _is_foreign
            and self._is_bytes_value(arg)
            and i < len(func.args)
            and (func.args[i].type == _i8ptr or self._is_bytes_type(func.args[i].type))
        ) {
            coerced.append(
                self._bytes_data_ptr(arg) if func.args[i].type == _i8ptr else arg
            );
            release_args.append(arg);
        } elif (
            _is_foreign
            and i in _clib_str_args
            and i < len(func.args)
            and func.args[i].type == _i8ptr
            and isinstance(arg.type, ir.PointerType)
        ) {
            coerced.append(self._membrane_str_out(self.builder, arg));
            release_args.append(arg);
        } elif i < len(func.args) {
            _c = self._coerce_type(arg, func.args[i].type);
            coerced.append(_c);
            release_args.append(_c);
        } else {
            coerced.append(arg);
            release_args.append(arg);
        }
    }
    if self._nogc_headerless() {
        _skip_own: set = set();
        _is_ctor = isinstance(nd.target, uni.Name)
            and (
                nd.target.sym_name in self.arch_ast_map
                or self._arch_alias_target(nd.target) in self.arch_ast_map
            );
        _sig = None if _is_ctor else self._callee_sig_of(nd, func);
        _sig_params = _sig.get_parameters() if _sig is not None else [];
        if _is_ctor {
            for _oi in range(len(release_args)) {
                _skip_own.add(_oi);
            }
        } elif _sig is not None and len(_sig_params) == len(release_args) {
            for (_oi, _op) in enumerate(_sig_params) {
                if _op.type_tag is not None
                    and _op.type_tag.ownership == OwnershipKind.OWN {
                    _skip_own.add(_oi);
                }
            }
        }
        if _skip_own {
            _kept: list = [];
            for (_ri, _rv) in enumerate(release_args) {
                if _ri not in _skip_own {
                    _kept.append(_rv);
                }
            }
            release_args = _kept;
            _param_idx: dict = {};
            for (_pi2, _p2) in enumerate(_sig_params) {
                _param_idx[_p2.name.sym_name] = _pi2;
            }
            _pos = 0;
            for _pa in (nd.params or []) {
                _aidx = -1;
                _anode: (uni.Expr | None) = None;
                if isinstance(_pa, uni.KWPair) {
                    _anode = _pa.value;
                    _k = _pa.key.sym_name if _pa.key is not None else None;
                    if _k is not None and _k in _param_idx {
                        _aidx = _param_idx[_k];
                    }
                } else {
                    _anode = _pa;
                    _aidx = _pos;
                    _pos += 1;
                }
                if not (_is_ctor or _aidx in _skip_own) {
                    continue;
                }
                if not isinstance(_anode, uni.Name) {
                    continue;
                }
                _salloca = self.local_vars.get(_anode.sym_name);
                if _salloca is not None
                    and isinstance(_salloca.type, ir.PointerType)
                    and isinstance(_salloca.type.pointee, ir.PointerType) {
                    self.builder.store(
                        ir.Constant(_salloca.type.pointee, None), _salloca
                    );
                }
            }
        }
    }
    if _is_foreign {
        _actual_params = func.function_type.args;
        for (_ai, _av) in enumerate(coerced) {
            if _ai < len(_actual_params) and _av.type != _actual_params[_ai] {
                coerced[_ai] = self._clib_reinterpret(
                    _av, _actual_params[_ai], name=f"clib.arg.{_ai}"
                );
            }
        }
    }
    if not self._call_args_lowered(nd, func, func_name, coerced) {
        return None;
    }
    result = self.builder.call(func, coerced, name=f"call.{func_name}");
    if func_name in self.clib_extern_names {
        _declared = self.clib_declared_sigs.get(func_name);
        _declared_ret = _declared[0] if _declared is not None else None;
        if (
            isinstance(_declared_ret, ir.Type)
            and not isinstance(_declared_ret, ir.VoidType)
            and result.type != _declared_ret
            and not _clib_str_ret
            and not _clib_managed_ret
        ) {
            result = self._clib_reinterpret(result, _declared_ret, name="clib.ret");
        } elif _clib_str_ret and isinstance(result.type, ir.PointerType) {
            result = self._membrane_str_in(self.builder, result);
        } elif _clib_managed_ret and isinstance(result.type, ir.PointerType) {
            result = self._mark_owned(result);
        }
    }

    self._release_owned_args(release_args, op="call_arg");

    if func_name in self.clib_extern_names {
        for (sname, abi_type) in self.clib_struct_abi_types.items() {
            if result.type == abi_type {
                result = self._coerce_type(
                    result, self.struct_types[sname].as_pointer()
                );
                break;
            }
        }

        if not isinstance(result.type, ir.PointerType) {
            for (sname, stype) in self.struct_types.items() {
                if sname in self.clib_struct_names and result.type == stype {
                    result = self._coerce_type(result, stype.as_pointer());
                    break;
                }
            }
        }
    }

    return result;
}

impl NaIRGenCalls._jacval_tags_for_type(name: str) -> list[int] {
    if name == "int" {
        return [0, 7];
    }
    if name == "bool" {
        return [7];
    }
    if name == "float" {
        return [1];
    }
    if name == "str" {
        return [2];
    }
    if name == "list" {
        return [3];
    }
    if name == "dict" {
        return [4];
    }
    if name == "set" or name == "frozenset" {
        return [5];
    }
    if name == "NoneType" {
        return [8];
    }
    return [];
}

impl NaIRGenCalls._isinstance_static_verdict(
    name: str, operand: ir.Value
) -> (bool | None) {
    """Answer the arms whose native representation carries no JacVal tag.

    A native tuple is an unboxed literal struct and a `bytes` / `bytearray` is
    a pointer to its own runtime struct, so none of the three is reachable
    through a tag compare -- but each is fully decided by the operand's LLVM
    type, which is known here. Returning `True`/`False` settles that arm at
    compile time; `None` means the name is not one of these and falls through
    to the tag and vtable machinery.
    """;
    if name == "tuple" {
        return self._tuple_struct_of_value(operand) is not None;
    }
    if name == "bytes" {
        return self._is_bytes_value(operand);
    }
    if name == "bytearray" {
        _ba = self.list_types.get("u8");
        return _ba is not None and operand.type == _ba.as_pointer();
    }
    return None;
}

impl NaIRGenCalls._isinstance_abc_reduction(
    type_expr: uni.UniNode, name: str
) -> (list[str] | None) {
    """The native shapes an `isinstance` arm naming a stdlib ABC reduces to.

    A `collections.abc` class is a Python object no native unit can host, so a
    check against one is only answerable by reducing it to the finite set of
    native runtime shapes that inhabit it. `_NA_ABC_REDUCTIONS` holds the
    reductions that are exact rather than approximate: every entry is a
    container ABC whose members, among values a native unit can hold, are
    precisely the listed builtins. Protocol-shaped ABCs are deliberately absent
    -- an archetype with `__iter__` inhabits `Iterable` too, so a builtin-only
    answer there would be silently wrong. Those sit in `_NA_ABC_OPAQUE`.

    `None` means the arm is not a stdlib ABC and the caller should treat it as
    it always has. An empty list means it is one this backend refuses to guess
    at, and the caller turns that into a diagnostic rather than an answer.
    """;
    if name in self.struct_types or name in self.enum_types {
        return None;
    }
    try {
        import from jaclang.compiler.types.types { ClassType as _AbcClassType }
    } except ImportError {
        return None;
    }
    t = type_expr.type if isinstance(type_expr, uni.Expr) else None;
    if not isinstance(t, _AbcClassType) or t._shared is None {
        return None;
    }
    if not t.shared.is_from_stdlib_stub {
        return None;
    }
    cn = t.shared.class_name;
    if cn in _NA_ABC_REDUCTIONS {
        return list(_NA_ABC_REDUCTIONS[cn]);
    }
    if cn in _NA_ABC_OPAQUE {
        return [];
    }
    return None;
}

impl NaIRGenCalls._isinstance_target_names(
    nd: uni.FuncCall, operand: ir.Value, type_arg: uni.UniNode
) -> (list[str] | None) {
    """Flatten the type argument into the type names the check has to test.

    A tuple argument contributes each of its arms; a stdlib ABC arm expands to
    the native shapes it reduces to, and keeps its own name too whenever some
    archetype names it in an MRO, so a user type registered under the ABC still
    answers through the vtable arm. `None` means a diagnostic was emitted.
    """;
    raw: list = list(type_arg.values or [])
        if isinstance(type_arg, uni.TupleVal)
        else [type_arg];
    pyb_operand = self._isinstance_operand_is_pyb(nd, operand);
    names: list[str] = [];
    for v in raw {
        nm = self._isinstance_type_name(v);
        if nm is None {
            continue;
        }
        reduced = self._isinstance_abc_reduction(v, nm);
        if reduced is None {
            if nm not in names {
                names.append(nm);
            }
            continue;
        }
        if not reduced or pyb_operand {
            self.emit(
                E5092,
                node_override=nd,
                kind="builtin call",
                name=f"isinstance against `{nm}`",
                help_text=(
                    "This operand's class inherits a Python-side base, so which abstract base classes it inhabits is decided by an MRO this native unit only holds a shadow handle to. Test the concrete type instead (`list`, `dict`, an archetype), or move the code to a @sv/Python context."
                        if pyb_operand
                        else "This abstract base class has no exact answer over native values -- an archetype can inhabit it without naming it, so a native check would have to guess. Test the concrete type instead (`list`, `dict`, an archetype), or move the code to a @sv/Python context."
                )
            );
            return None;
        }
        for _b in reduced {
            if _b not in names {
                names.append(_b);
            }
        }
        if nm not in names and self._vtable_candidates([nm]) {
            names.append(nm);
        }
    }
    return names;
}

impl NaIRGenCalls._isinstance_operand_is_pyb(
    nd: uni.FuncCall, operand: ir.Value
) -> bool {
    """Does the operand's class reach its bases through the Python bridge?

    A class with a Python-side base carries an MRO this unit never modelled --
    `PyBase(ABC)` in the interop fixtures is exactly that shape -- so which
    abstract base classes such an instance inhabits is not answerable from the
    native layout. Only the reduction cares: an archetype arm still answers
    through the vtable, whose MRO covers the layout-trusted bases.
    """;
    arch = self._isinstance_operand_arch(nd, operand);
    if arch is None {
        return False;
    }
    for cand in self._mro_of(arch) {
        if self._pyb_base_of(cand) is not None {
            return True;
        }
    }
    return False;
}

impl NaIRGenCalls._isinstance_type_name(nd: uni.UniNode) -> (str | None) {
    if (
        isinstance(nd, uni.FuncCall)
        and self._get_name(nd.target) == "type"
        and nd.params
        and len(nd.params) == 1
        and isinstance(nd.params[0], uni.Null)
    ) {
        import from jaclang.compiler.symbol_utils { classify_call, CallKind }
        if classify_call(nd) == CallKind.BUILTIN {
            return "NoneType";
        }
        return None;
    }
    _mn_nd = nd;
    while isinstance(_mn_nd, uni.AtomUnit) and _mn_nd.value is not None {
        _mn_nd = _mn_nd.value;
    }
    if self._mono_mangle_map
        and isinstance(_mn_nd, uni.Name)
        and _mn_nd.sym is not None {
        nd = _mn_nd;
        _mn_decl = nd.sym.decl.name_of if nd.sym.decl is not None else None;
        if isinstance(_mn_decl, uni.ParamVar) and _mn_decl.type_tag is not None {
            _mn_tag = _mn_decl.type_tag.tag;
            while isinstance(_mn_tag, uni.AtomUnit) and _mn_tag.value is not None {
                _mn_tag = _mn_tag.value;
            }
            if (
                isinstance(_mn_tag, uni.AtomTrailer)
                and isinstance(_mn_tag.target, uni.Name)
                and _mn_tag.target.value == "type"
                and isinstance(_mn_tag.right, uni.IndexSlice)
                and len(_mn_tag.right.slices) == 1
            ) {
                _mn_inner = _mn_tag.right.slices[0].start;
                if isinstance(_mn_inner, uni.Name)
                    and _mn_inner.value in self._mono_mangle_map {
                    return self._mono_mangle_map[_mn_inner.value];
                }
            }
        }
    }
    _alias_nm = self._arch_alias_target(nd);
    if _alias_nm is not None {
        return _alias_nm;
    }
    return self._get_name(nd);
}

impl NaIRGenCalls._enum_union_tags(
    operand_expr: uni.UniNode, names: list[str]
) -> tuple {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _EnClassType,
            EnumMemberType as _EnMemberType,
            UnionType as _EnUnionType
        }
    } except ImportError {
        return ([], names, );
    }
    t = operand_expr.type if isinstance(operand_expr, uni.Expr) else None;
    members: list = [];
    if isinstance(t, _EnUnionType) {
        members = list(t.types or []);
    } elif t is not None {
        members = [t];
    }
    if not members {
        return ([], names, );
    }
    member_rows: list = [];
    for m in members {
        cls = m.enum_class if isinstance(m, _EnMemberType) else m;
        if not isinstance(cls, _EnClassType) or cls._shared is None {
            return ([], names, );
        }
        cn = cls.shared.class_name;
        if cls.is_enum_class() {
            member_rows.append((cn, True, [0], ));
        } elif cn in ("NoneType", "None") {
            member_rows.append((cn, False, [8], ));
        } elif cn == "bool" {
            member_rows.append((cn, False, [7], ));
        } elif cn == "int" {
            member_rows.append((cn, False, [0, 7], ));
        } elif cn == "float" {
            member_rows.append((cn, False, [1], ));
        } elif cn == "str" {
            member_rows.append((cn, False, [2], ));
        } elif cn in ("list", "dict", "set", "tuple") {
            member_rows.append((cn, False, [3, 4, 5], ));
        } else {
            member_rows.append((cn, False, [6], ));
        }
    }
    resolved: list[int] = [];
    still: list[str] = [];
    for nm in names {
        hit = False;
        for row in member_rows {
            if row[0] == nm and row[1] {
                clash = False;
                for other in member_rows {
                    if other[0] != nm and (0 in other[2]) {
                        clash = True;
                        break;
                    }
                }
                hit = not clash;
                break;
            }
        }
        if hit {
            if 0 not in resolved {
                resolved.append(0);
            }
        } else {
            still.append(nm);
        }
    }
    return (resolved, still, );
}

impl NaIRGenCalls._emit_isinstance(nd: uni.FuncCall) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    params = nd.params or [];
    if len(params) < 2 {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    operand = self._codegen_expr(params[0]);
    if operand is None {
        return None;
    }
    if self._opt_payload_of(operand.type) is None {
        if not isinstance(operand.type, ir.PointerType) {
            return self._emit_isinstance_core(nd, operand);
        }

        _nn_fn = self.builder.block.function;
        _nn_bb = _nn_fn.append_basic_block("isinst.nn");
        _nn_done_bb = _nn_fn.append_basic_block("isinst.nn.done");
        _nn_ok = self.builder.icmp_unsigned(
            "!=", operand, ir.Constant(operand.type, None), name="isinst.nonnull"
        );
        _nn_entry = self.builder.block;
        self.builder.cbranch(_nn_ok, _nn_bb, _nn_done_bb);
        self.builder.position_at_end(_nn_bb);
        _nn_inner = self._emit_isinstance_core(nd, operand);
        _nn_inner_bb = self.builder.block;
        self.builder.branch(_nn_done_bb);
        self.builder.position_at_end(_nn_done_bb);
        if _nn_inner is None {
            return None;
        }
        _nn_res = self.builder.phi(i1, name="isinst.nn.res");
        _nn_res.add_incoming(ir.Constant(i1, 0), _nn_entry);
        _nn_res.add_incoming(_nn_inner, _nn_inner_bb);
        return _nn_res;
    }
    fn = self.builder.block.function;
    some_bb = fn.append_basic_block("isinst.opt.some");
    done_bb = fn.append_basic_block("isinst.opt.done");
    opt_tag = self.builder.extract_value(operand, 0, name="isinst.opt.tag");
    opt_set = self.builder.icmp_signed(
        "!=", opt_tag, ir.Constant(i8, 0), name="isinst.opt.set"
    );
    payload = self.builder.extract_value(operand, 1, name="isinst.opt.val");
    entry_bb = self.builder.block;
    self.builder.cbranch(opt_set, some_bb, done_bb);
    self.builder.position_at_end(some_bb);
    inner = self._emit_isinstance_core(nd, payload);
    inner_bb = self.builder.block;
    self.builder.branch(done_bb);
    self.builder.position_at_end(done_bb);
    if inner is None {
        return None;
    }
    res = self.builder.phi(i1, name="isinst.opt.res");
    res.add_incoming(ir.Constant(i1, 0), entry_bb);
    res.add_incoming(inner, inner_bb);
    return res;
}

impl NaIRGenCalls._emit_isinstance_core(
    nd: uni.FuncCall, operand: ir.Value
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    params = nd.params or [];

    type_arg = params[1];
    if not isinstance(type_arg, uni.TupleVal) {
        _rt_res = self._emit_isinstance_runtime(nd, operand, type_arg);
        if _rt_res is not None {
            return _rt_res;
        }
    }
    names = self._isinstance_target_names(nd, operand, type_arg);
    if names is None {
        return None;
    }
    _short = self._isinstance_unprovable_class(
        names, self._isinstance_operand_arch(nd, operand)
    );
    if _short is not None {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name=f"isinstance against `{'`, `'.join(names)}`",
            help_text=(
                f"`{_short}` subclasses a class another module defines, so this unit linearized it from a base whose own bases it could not see yet -- its ancestor chain stops one link short of the classes named here, and answering from it is how a check reports `False` for a base the operand genuinely derives from. Test the concrete class instead, or declare `{_short}` in the module that defines its base."
            )
        );
        return None;
    }
    tags: list[int] = [];
    unresolved: list[str] = [];
    static_seen = False;
    static_hit = False;
    for nm in names {
        verdict = self._isinstance_static_verdict(nm, operand);
        if verdict is not None {
            static_seen = True;
            static_hit = static_hit or verdict;
            continue;
        }
        nm_tags = self._jacval_tags_for_type(nm);
        if not nm_tags {
            unresolved.append(nm);
        }
        for t in nm_tags {
            if t not in tags {
                tags.append(t);
            }
        }
    }
    if static_hit {
        if isinstance(operand.type, ir.PointerType) and self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return ir.Constant(i1, 1);
    }
    if unresolved {
        (_enum_tags, unresolved) = self._enum_union_tags(params[0], unresolved);
        for _et in _enum_tags {
            if _et not in tags {
                tags.append(_et);
            }
        }
    }
    if unresolved {
        if not tags {
            return self._emit_isinstance_user(nd, operand, unresolved);
        }
        return self._emit_isinstance_mixed(nd, operand, tags, unresolved);
    }
    if not tags {
        if static_seen {
            if isinstance(operand.type, ir.PointerType) and self._is_owned(operand) {
                self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
            }
            return ir.Constant(i1, 0);
        }
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    if isinstance(operand.type, ir.PointerType) {
        _pt_res = self._emit_isinstance_ptr_tags(operand, tags);
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return _pt_res;
    }
    boxed = self._box_to_jacval(operand);
    tag = self.builder.extract_value(boxed, 0, name="isinst.tag");
    result: (ir.Value | None) = None;
    for t in sorted(tags) {
        cmp = self.builder.icmp_unsigned(
            "==", tag, ir.Constant(i8, t), name="isinst.cmp"
        );
        result = cmp
            if result is None
            else self.builder.or_(result, cmp, name="isinst.or");
    }

    if isinstance(operand.type, ir.PointerType) and self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    return result;
}

impl NaIRGenCalls._emit_isinstance_ptr_tags(
    operand: ir.Value, tags: list[int]
) -> ir.Value {
    i1 = ir.IntType(1);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();

    _prefixes: dict[int, str] = {3: "list_", 4: "dict_", 5: "set_"};
    if 6 in tags {
        return ir.Constant(i1, 1);
    }
    _want = [
        t
        for t in sorted(tags)
        if t in _prefixes
    ];
    if not _want {
        return ir.Constant(i1, 0);
    }
    b = self.builder;
    raw = b.bitcast(operand, i8p, name="isinst.hdr.raw");
    fn = b.block.function;
    pre_bb = b.block;
    tag_bb = fn.append_basic_block("isinst.hdr.tag");
    cmp_bb = fn.append_basic_block("isinst.hdr.cmp");
    done_bb = fn.append_basic_block("isinst.hdr.done");
    magic_ok = self._emit_magic_check(b, raw, name_prefix="isinst.mc");
    b.cbranch(magic_ok, tag_bb, done_bb);

    b.position_at_end(tag_bb);
    tag_slot = b.gep(raw, [ir.Constant(i64, HDR_TAG_OFF)], name="isinst.tag.slot");
    tag_pp = b.bitcast(tag_slot, i8p.as_pointer(), name="isinst.tag.pp");
    tag_ptr = b.load(tag_pp, name="isinst.tag.name");
    tag_nn = b.icmp_unsigned(
        "!=", tag_ptr, ir.Constant(i8p, None), name="isinst.tag.nn"
    );
    b.cbranch(tag_nn, cmp_bb, done_bb);

    b.position_at_end(cmp_bb);
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    matched: (ir.Value | None) = None;
    for t in _want {
        pfx = _prefixes[t];
        pfx_gv = self._get_snprintf_fmt(pfx);
        pfx_ptr = b.gep(
            pfx_gv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="isinst.pfx"
        );
        cmp_res = b.call(
            memcmp_fn,
            [tag_ptr, pfx_ptr, ir.Constant(i64, len(pfx))],
            name="isinst.memcmp"
        );
        eq = b.icmp_signed("==", cmp_res, ir.Constant(i32, 0), name="isinst.pfx.eq");
        matched = eq if matched is None else b.or_(matched, eq, name="isinst.pfx.or");
    }
    cmp_end_bb = b.block;
    b.branch(done_bb);

    b.position_at_end(done_bb);
    res = b.phi(i1, name="isinst.hdr.res");
    res.add_incoming(ir.Constant(i1, 0), pre_bb);
    res.add_incoming(ir.Constant(i1, 0), tag_bb);
    res.add_incoming(matched, cmp_end_bb);
    return res;
}

impl NaIRGenCalls._emit_isinstance_mixed(
    nd: uni.FuncCall, operand: ir.Value, tags: list[int], names: list[str]
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);

    _by_name = self._isinstance_needs_class_name(names);
    if _by_name and self._nogc_headerless() {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    target_vtables = [] if _by_name else self._vtable_candidates(names);
    if not _by_name and not target_vtables {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

    boxed = self._box_to_jacval(operand);
    tag = self.builder.extract_value(boxed, 0, name="isinst.tag");
    payload = self.builder.extract_value(boxed, 1, name="isinst.payload");

    prim: (ir.Value | None) = None;
    for t in sorted(tags) {
        cmp = self.builder.icmp_unsigned(
            "==", tag, ir.Constant(i8, t), name="isinst.cmp"
        );
        prim = cmp if prim is None else self.builder.or_(prim, cmp, name="isinst.or");
    }
    if prim is None {
        prim = ir.Constant(i1, 0);
    }

    pre_bb = self.builder.block;
    obj_bb = self.builder.append_basic_block(name="isinst.mix.obj");
    load_bb = self.builder.append_basic_block(name="isinst.mix.load");
    merge_bb = self.builder.append_basic_block(name="isinst.mix.merge");
    is_obj = self.builder.icmp_unsigned(
        "==", tag, ir.Constant(i8, 6), name="isinst.isobj"
    );
    self.builder.cbranch(is_obj, obj_bb, merge_bb);

    self.builder.position_at_end(obj_bb);
    is_null = self.builder.icmp_signed(
        "==", payload, ir.Constant(payload.type, 0), name="isinst.mix.null"
    );
    self.builder.cbranch(is_null, merge_bb, load_bb);

    self.builder.position_at_end(load_bb);
    user_or: (ir.Value | None) = None;
    if _by_name {
        user_or = self._isinstance_class_name_hit(
            self.builder.inttoptr(payload, i8.as_pointer(), name="isinst.mix.obj"),
            names
        );
        if user_or is None {
            self._emit_unsupported_builtin_call(nd, "isinstance");
            return None;
        }
    } else {
        i8_pp = i8.as_pointer().as_pointer();
        slot_pp = self.builder.inttoptr(
            payload, i8_pp.as_pointer(), name="isinst.mix.slot"
        );
        vptr = self.builder.load(slot_pp, name="isinst.mix.vptr");
        for vt in target_vtables {
            vt_base = self.builder.gep(
                vt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="isinst.mix.vt"
            );
            eq = self.builder.icmp_unsigned("==", vptr, vt_base, name="isinst.mix.eq");
            user_or = eq
                if user_or is None
                else self.builder.or_(user_or, eq, name="isinst.mix.uor");
        }
    }
    end_load = self.builder.block;
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
    result = self.builder.phi(i1, name="isinst.mix.result");
    result.add_incoming(prim, pre_bb);
    result.add_incoming(ir.Constant(i1, 0), obj_bb);
    result.add_incoming(user_or, end_load);

    if isinstance(operand.type, ir.PointerType) and self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    return result;
}

impl NaIRGenCalls._emit_isinstance_user(
    nd: uni.FuncCall, operand: ir.Value, names: list[str]
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);

    if not isinstance(operand.type, ir.PointerType) {
        if self?.jacval_type and operand.type == self.jacval_type {
            return self._emit_isinstance_mixed(nd, operand, [], names);
        }
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

    if self._isinstance_needs_class_name(names) {
        _nm_hit = (
            None
                if self._nogc_headerless()
                else self._isinstance_class_name_hit(operand, names)
        );
        if _nm_hit is None {
            self._emit_unsupported_builtin_call(nd, "isinstance");
            return None;
        }
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return _nm_hit;
    }

    target_vtables = self._vtable_candidates(names);
    if not target_vtables {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

    struct_name = self._struct_name_of(nd.params[0] if nd.params else None);
    if (
        struct_name is not None
        and struct_name in self.struct_types
        and not self._arch_has_vtable(struct_name)
    ) {
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return ir.Constant(i1, 0);
    }

    pre_bb = self.builder.block;
    null_ptr = ir.Constant(operand.type, None);
    is_null = self.builder.icmp_unsigned(
        "==", operand, null_ptr, name="isinst.null.chk"
    );
    nonnull_bb = self.builder.append_basic_block(name="isinst.nonnull");
    merge_bb = self.builder.append_basic_block(name="isinst.merge");
    self.builder.cbranch(is_null, merge_bb, nonnull_bb);

    self.builder.position_at_end(nonnull_bb);
    i8_pp = i8.as_pointer().as_pointer();
    op_as = self.builder.bitcast(operand, i8_pp.as_pointer(), name="isinst.obj");
    vptr = self.builder.load(op_as, name="isinst.vptr");
    cmp: (ir.Value | None) = None;
    for vt in target_vtables {
        vt_base = self.builder.gep(
            vt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="isinst.vt.base"
        );
        eq = self.builder.icmp_unsigned("==", vptr, vt_base, name="isinst.eq");
        cmp = eq if cmp is None else self.builder.or_(cmp, eq, name="isinst.or");
    }

    if self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    end_nonnull = self.builder.block;
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
    result = self.builder.phi(i1, name="isinst.result");
    result.add_incoming(ir.Constant(i1, 0), pre_bb);
    result.add_incoming(cmp, end_nonnull);
    return result;
}

impl NaIRGenCalls._flow_future_licensed(nd: uni.ConcurrentExpr) -> (uni.Name | None) {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    asgn = nd.parent;
    if not (
        isinstance(asgn, uni.Assignment)
        and asgn.value is nd
        and asgn.aug_op is None
        and len(asgn.target) == 1
        and isinstance(asgn.target[0], uni.Name)
    ) {
        return None;
    }
    h = asgn.target[0];
    if h.sym is None {
        return None;
    }
    _fn = asgn.find_parent_of_type(uni.Ability);
    _scope = _fn if _fn is not None else asgn.find_parent_of_type(uni.ModuleCode);
    if _scope is None {
        return None;
    }
    _spawn_loop = (
        asgn.find_parent_of_type(uni.InForStmt)
        or asgn.find_parent_of_type(uni.WhileStmt)
        or asgn.find_parent_of_type(uni.IterForStmt)
    );
    _waits = 0;
    for use in _scope.get_all_sub_nodes(uni.Name) {
        if use.sym is not h.sym or use is h {
            continue;
        }
        _p = use.parent;
        _use_loop = (
            use.find_parent_of_type(uni.InForStmt)
            or use.find_parent_of_type(uni.WhileStmt)
            or use.find_parent_of_type(uni.IterForStmt)
        );
        if isinstance(_p, uni.ConcurrentExpr)
            and _p.target is use
            and _p.tok is not None
            and _p.tok.name == Tok.KW_WAIT
            and _use_loop is _spawn_loop {
            _waits += 1;
            continue;
        }
        return None;
    }
    if _waits != 1 {
        return None;
    }
    return h;
}

impl NaIRGenCalls._try_flow_future(nd: uni.ConcurrentExpr) -> (ir.Value | None) {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    if nd.tok is None {
        return None;
    }
    _par_ok = (self.ir_in.gen.nogc_enforced and self._gc_mode() == "none")
        or (self._gc_mode() == "rc" and not self._rc_debug_codegen);
    if not _par_ok
        or "wasm" in str(self.llvm_module.triple)
        or self._gen_ctx is not None {
        return None;
    }
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8p = ir.IntType(8).as_pointer();
    if nd.tok.name == Tok.KW_WAIT {
        if not isinstance(nd.target, uni.Name) or nd.target.sym is None {
            return None;
        }
        _meta = self.flow_future_meta.get(id(nd.target.sym));
        if _meta is None {
            return None;
        }
        (fut_ty, res_ty) = _meta;
        _slot = self.local_vars.get(nd.target.sym_name);
        if _slot is None {
            _slot = self.global_vars.get(nd.target.sym_name);
        }
        if _slot is None {
            return None;
        }
        _hv = self.builder.load(_slot, name="fut.h");
        if isinstance(_hv.type, ir.DoubleType) {
            _hv = self.builder.bitcast(_hv, i64, name="fut.h.i");
        }
        if isinstance(_hv.type, ir.PointerType) {
            _fut = self.builder.bitcast(_hv, fut_ty.as_pointer(), name="fut.p");
        } else {
            _fut = self.builder.inttoptr(_hv, fut_ty.as_pointer(), name="fut.p");
        }
        _tid = self.builder.load(
            self.builder.gep(
                _fut, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="fut.tid.s"
            ),
            name="fut.tid"
        );
        _join_bb = self.builder.function.append_basic_block("fut.join");
        _done_bb = self.builder.function.append_basic_block("fut.done");
        self.builder.cbranch(
            self.builder.icmp_signed("!=", _tid, ir.Constant(i64, 0), name="fut.live"),
            _join_bb,
            _done_bb
        );
        self.builder.position_at_end(_join_bb);
        _pjoin = self._get_or_declare_extern("pthread_join", i32, [i64, i8p]);
        self.builder.call(_pjoin, [_tid, ir.Constant(i8p, None)]);
        self.builder.branch(_done_bb);
        self.builder.position_at_end(_done_bb);
        _res = self.builder.load(
            self.builder.gep(
                _fut, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="fut.res.s"
            ),
            name="fut.res"
        );
        _free = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
        self.builder.call(_free, [self.builder.bitcast(_fut, i8p, name="fut.i8")]);
        if isinstance(res_ty, ir.PointerType) {
            self._mark_owned(_res);
        }
        return _res;
    }
    if nd.tok.name != Tok.KW_FLOW {
        return None;
    }
    call = nd.target;
    if not isinstance(call, uni.FuncCall) or not isinstance(call.target, uni.Name) {
        return None;
    }
    fname = call.target.sym_name;
    callee = self.func_symtab.get(fname);
    if callee is None
        or not isinstance(callee, ir.Function)
        or fname in self.clib_fn_abi
        or fname in self.clib_extern_names {
        return None;
    }
    _res_ty = callee.function_type.return_type;
    _res_ok = (isinstance(_res_ty, ir.IntType) and _res_ty.width == 64)
        or isinstance(_res_ty, ir.DoubleType)
        or isinstance(_res_ty, ir.PointerType);
    if not _res_ok {
        return None;
    }
    h = self._flow_future_licensed(nd);
    if h is None {
        return None;
    }
    _argv: list = [];
    for p in (call.params or []) {
        if isinstance(p, uni.KWPair) {
            return None;
        }
        _v = self._codegen_expr(p);
        if _v is None {
            return None;
        }
        _argv.append(_v);
    }
    if len(_argv) != len(callee.args) {
        return None;
    }
    _cargs: list = [];
    for (i, a) in enumerate(_argv) {
        _cargs.append(self._coerce_type(a, callee.args[i].type));
    }
    fut_ty = ir.LiteralStructType([i64, _res_ty] + [a.type for a in _cargs]);
    self._str_count += 1;
    _fid = self._str_count;
    _task_fn = ir.Function(
        self.llvm_module, ir.FunctionType(i8p, [i8p]), name=f"__jac_flow_task_{_fid}"
    );
    _task_fn.linkage = "private";
    _tb = ir.IRBuilder(_task_fn.append_basic_block("entry"));
    _tf = _tb.bitcast(_task_fn.args[0], fut_ty.as_pointer(), name="t.fut");
    _t_args: list = [];
    for i in range(len(_cargs)) {
        _t_args.append(
            _tb.load(
                _tb.gep(
                    _tf,
                    [ir.Constant(i32, 0), ir.Constant(i32, 2 + i)],
                    name=f"t.a{i}.s"
                ),
                name=f"t.a{i}"
            )
        );
    }
    _t_res = _tb.call(callee, _t_args, name="t.call");
    _tb.store(
        _t_res, _tb.gep(_tf, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="t.res.s")
    );
    if self._gc_mode() != "none" {
        _saved_b = self._builder;
        self._builder = _tb;
        for (i, a) in enumerate(_cargs) {
            if isinstance(a.type, ir.PointerType) {
                self._emit_rc_release_simple(_t_args[i], op="flow_arg", loc="");
            }
        }
        self._builder = _saved_b;
    }
    _tb.ret(ir.Constant(i8p, None));
    _malloc = self._get_or_declare_extern("malloc", i8p, [i64]);
    _sz = self.builder.ptrtoint(
        self.builder.gep(
            ir.Constant(fut_ty.as_pointer(), None),
            [ir.Constant(i32, 1)],
            name="fut.szp"
        ),
        i64,
        name="fut.sz"
    );
    _fut8 = self.builder.call(_malloc, [_sz], name="fut.raw");
    _fut = self.builder.bitcast(_fut8, fut_ty.as_pointer(), name="fut.new");
    for (i, a) in enumerate(_cargs) {
        if isinstance(a.type, ir.PointerType) and self._gc_mode() != "none" {
            self._emit_rc_retain(a, op="flow_arg", loc="");
        }
        self.builder.store(
            a,
            self.builder.gep(
                _fut, [ir.Constant(i32, 0), ir.Constant(i32, 2 + i)], name=f"fut.a{i}.s"
            )
        );
    }
    _tid_slot = self.builder.gep(
        _fut, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="fut.tid.w"
    );
    self.builder.store(ir.Constant(i64, 0), _tid_slot);
    _thr_fnty_p = ir.FunctionType(i8p, [i8p]).as_pointer();
    _pcreate = self._get_or_declare_extern(
        "pthread_create", i32, [i64.as_pointer(), i8p, _thr_fnty_p, i8p]
    );
    _crc = self.builder.call(
        _pcreate, [_tid_slot, ir.Constant(i8p, None), _task_fn, _fut8], name="fut.crc"
    );
    _seq_bb = self.builder.function.append_basic_block("fut.seq");
    _ok_bb = self.builder.function.append_basic_block("fut.spawned");
    self.builder.cbranch(
        self.builder.icmp_signed("!=", _crc, ir.Constant(i32, 0), name="fut.crc.bad"),
        _seq_bb,
        _ok_bb
    );
    self.builder.position_at_end(_seq_bb);
    self.builder.store(ir.Constant(i64, 0), _tid_slot);
    self.builder.call(_task_fn, [_fut8]);
    self.builder.branch(_ok_bb);
    self.builder.position_at_end(_ok_bb);
    self.flow_future_meta[id(h.sym)] = (fut_ty, _res_ty);
    _hraw = self.builder.ptrtoint(_fut8, i64, name="fut.h.raw");
    if isinstance(_res_ty, ir.DoubleType) {
        return self.builder.bitcast(_hraw, ir.DoubleType(), name="fut.h.f");
    }
    if isinstance(_res_ty, ir.PointerType) {
        return self.builder.bitcast(_fut8, _res_ty, name="fut.h.p");
    }
    return _hraw;
}

impl NaIRGenCalls._empty_ctor_args_of(nd: uni.FuncCall) -> list {
    _own = self._container_type_args(nd?.type);
    if _own {
        return _own;
    }
    _cur: (uni.UniNode | None) = nd;
    _par = _cur?.parent;
    while isinstance(_par, uni.CfgExpr) {
        _cur = _par;
        _par = _par.parent;
    }
    if isinstance(_par, uni.IfElseExpr) {
        _sib = _par.else_value if _par.value is _cur else _par.value;
        if _sib is not _cur {
            return self._container_type_args(self._unwrap_cfg_expr(_sib)?.type);
        }
    }
    return [];
}

impl NaIRGenCalls._unwrap_cfg_expr(e: any) -> any {
    _cur = e;
    while isinstance(_cur, uni.CfgExpr) {
        _cur = _cur.expr;
    }
    return _cur;
}

impl NaIRGenCalls._call_args_lowered(
    nd: uni.UniNode, func: ir.Function, func_name: str, coerced: list
) -> bool {
    """Whether every argument reached the callee's parameter type.

    `_coerce_type` answers with the value unchanged when it has no coercion
    for a pair, so a lowering that lost a type upstream reaches the builder
    with an argument the callee cannot take. The builder's `TypeError` is
    then reported as an internal compiler error, which buries the real
    defect under a crash. Refusing here demotes the one callable and names
    the parameter that did not line up, so the coverage records a fact rather
    than a stack trace.
    """;
    _n = min(len(coerced), len(func.args));
    for _i in range(_n) {
        if coerced[_i].type == func.args[_i].type {
            continue;
        }
        self.emit(
            E5092,
            node_override=nd,
            kind="call argument",
            name=f"{func_name} parameter {_i + 1}",
            help_text=f"The argument lowered to `{coerced[_i].type}` but "
            f"`{func_name}` takes `{func.args[_i].type}` there, and no "
            "coercion connects the two. Some type upstream of this call was "
            "lost -- an unlinked imported archetype, an erased container "
            "element, or a narrow the backend could not follow."
        );
        return False;
    }
    return True;
}

impl NaIRGenCalls._spec_from_container_ptr(t: (ir.Type | None)) -> (str | None) {
    if t is None or not isinstance(t, ir.PointerType) {
        return None;
    }
    for _tbl in (self.list_types, self.set_types) {
        for (spec, lt) in _tbl.items() {
            if lt.as_pointer() == t {
                return spec;
            }
        }
    }
    return None;
}

impl NaIRGenCalls._container_type_args(t: any) -> list {
    if t is None {
        return [];
    }
    for _cand in (t?.types or [t]) {
        _priv = _cand?.private;
        if _priv is not None and (_priv?.type_args or []) {
            return list(_priv.type_args);
        }
    }
    return [];
}

impl NaIRGenCalls._prep_kwbind_record(
    name: str,
    slot_type: ir.Type,
    args_idx: int,
    stored: ir.Value,
    bound_kind: (str | None),
    required_kind: (str | None)
) -> dict {
    rec: dict = {};
    rec["name"] = name;
    rec["slot_type"] = slot_type;
    rec["args_idx"] = args_idx;
    rec["alloca"] = None;
    rec["flag"] = None;
    rec["missing_msg"] = None;
    if bound_kind is not None {
        _noun = "argument" if bound_kind == "pos" else "keyword argument";
        rec["dup_msg"] = f"got multiple values for {_noun} '{name}'";
        return rec;
    }
    rec["dup_msg"] = f"got multiple values for keyword argument '{name}'";
    _al = self._entry_alloca(slot_type, f"kwbind.{name}");
    _init = self._coerce_type(stored, slot_type);
    if isinstance(slot_type, ir.PointerType) and not self._is_owned(stored) {
        self._emit_rc_retain(_init, op="kwbind", loc="");
    }
    self.builder.store(_init, _al);
    _fl = self._entry_alloca(ir.IntType(1), f"kwbind.{name}.bound");
    self.builder.store(ir.Constant(ir.IntType(1), 0), _fl);
    rec["alloca"] = _al;
    rec["flag"] = _fl;
    if required_kind is not None {
        rec["missing_msg"] = f"missing 1 required {required_kind} argument: '{name}'";
    }
    return rec;
}

impl NaIRGenCalls._codegen_sized_builtin_call(
    nd: uni.FuncCall, func_name: (str | None), call_kind: str
) -> (ir.Value | None) {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if call_kind == "method" and isinstance(nd.target, uni.AtomTrailer) {
        _owner = self._get_name(nd.target.target);
        _attr = self._get_name(nd.target.right);
        if (
            _owner is not None
            and _attr == "wrap"
            and JAC_TYPE_REGISTRY.is_sized(_owner)
            and _owner not in self.local_vars
        ) {
            return self._codegen_sized_wrap(nd, _owner);
        }
        return None;
    }
    if func_name is None or func_name in self.local_vars {
        return None;
    }
    if JAC_TYPE_REGISTRY.is_sized(func_name) {
        return self._codegen_sized_cast(nd, func_name);
    }
    if func_name.startswith("wrapping_") and JAC_TYPE_REGISTRY.is_builtin(func_name) {
        return self._codegen_wrapping(nd, func_name);
    }
    return None;
}


impl NaIRGenCalls._emit_take(nd: uni.FuncCall) -> (ir.Value | None) {
    params_l = list(nd.params or []);
    if len(params_l) != 1 or isinstance(params_l[0], uni.KWPair) {
        self.emit(E5092, node_override=nd, kind="take() call", name="take");
        return None;
    }
    _place = params_l[0];
    _slot = self._codegen_place_ptr(_place);
    if _slot is None {
        self.emit(
            E5092,
            node_override=_place,
            kind="take() place",
            name=type(_place).__name__,
            help_text="take() moves out of a local or an attribute of an archetype instance."
        );
        return None;
    }
    _val = self.builder.load(_slot, name="take.val");
    self.builder.store(ir.Constant(_slot.type.pointee, None), _slot);
    return _val;
}

impl NaIRGenCalls._emit_swap(nd: uni.FuncCall) -> (ir.Value | None) {
    params_l = list(nd.params or []);
    if len(params_l) != 2 or any([isinstance(_p, uni.KWPair) for _p in params_l]) {
        self.emit(E5092, node_override=nd, kind="swap() call", name="swap");
        return None;
    }
    _slots: list = [];
    for _p in params_l {
        _place = _p.operand if isinstance(_p, uni.UnaryExpr) else _p;
        _slot = self._codegen_place_ptr(_place);
        if _slot is None {
            self.emit(
                E5092,
                node_override=_place,
                kind="swap() place",
                name=type(_place).__name__,
                help_text="swap() exchanges two locals or two attributes of archetype instances."
            );
            return None;
        }
        _slots.append(_slot);
    }
    if _slots[0].type != _slots[1].type {
        self.emit(
            E5092,
            node_override=nd,
            kind="swap() operands",
            name="swap",
            help_text="swap() needs two places of the same type."
        );
        return None;
    }
    _a = self.builder.load(_slots[0], name="swap.a");
    _b = self.builder.load(_slots[1], name="swap.b");
    self.builder.store(_b, _slots[0]);
    self.builder.store(_a, _slots[1]);
    return ir.Constant(ir.IntType(64), 0);
}
