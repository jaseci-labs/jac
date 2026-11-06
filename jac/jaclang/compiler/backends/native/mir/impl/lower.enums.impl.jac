impl MirLowering.enum_layout(t: (TypeBase | None), site: uni.UniNode) -> EnumLayout {
    decl = enum_decl_of(t);
    if decl is None {
        served = self.catalog_enum_layout(t);
        if served is not None {
            if not served.all_values_known {
                raise MirRefused(
                    mir_refusal(
                        "enum",
                        served.name,
                        site,
                        f"A native enum is a table of int or str member values; the stub for '{served.name}' gives a member some other value."
                    )
                );
            }
            return served;
        }
    }
    if decl is None or decl.name is None {
        raise MirRefused(
            mir_refusal(
                "enum",
                str(t),
                site,
                "A native enum is declared with `enum`, or as a class over int or str members."
            )
        );
    }
    name = decl.name.value;
    owner = decl.find_parent_of_type(uni.Module) or self.module;
    found = get_layout_registry(owner, self.prog).get_enum_layout(name);
    if found is None or not found.members {
        raise MirRefused(
            mir_refusal("enum", name, site, "The enum has no native layout.")
        );
    }
    if not found.all_values_known {
        raise MirRefused(
            mir_refusal(
                "enum",
                name,
                site,
                f"A native enum is a table of int or str member values. A member of '{name}' has some other value, so its members could not be told apart. Give every member an int or str value, or move the enum to a @sv/Python context."
            )
        );
    }
    return found;
}

impl MirLowering.catalog_enum_layout(t: (TypeBase | None)) -> (EnumLayout | None) {
    if not is_enum_class_type(t) or not isinstance(t, ClassType) {
        return None;
    }
    shared = t.shared;
    if not stub_scope(shared.symbol_table) or not shared.enum_members {
        return None;
    }
    known = self.catalog_enums.get(id(shared));
    if known is not None {
        return known;
    }
    values = [info.literal_value for info in shared.enum_members.values()];
    texts = all(isinstance(value, str) for value in values);
    whole = all(
        isinstance(value, int) and not isinstance(value, bool) for value in values
    );
    members: list[EnumMemberLayout] = [];
    for (ordinal, (name, info)) in enumerate(shared.enum_members.items()) {
        value = info.literal_value;
        members.append(
            EnumMemberLayout(
                name=name,
                ordinal=ordinal,
                int_value=value if isinstance(value, int) else 0,
                str_value=value if isinstance(value, str) else None
            )
        );
    }
    made = EnumLayout(
        name=class_type_native_name(t) or shared.class_name,
        is_string_enum=texts and not whole,
        is_class_form=True,
        all_values_known=texts or whole,
        members=members
    );
    self.catalog_enums[id(shared)] = made;
    return made;
}

impl MirLowering.enum_layout_of(value_type: MirType, site: uni.UniNode) -> EnumLayout {
    known = self.enum_types.get(value_type.name);
    if known is None {
        raise MirRefused(mir_refusal("enum", value_type.name, site));
    }
    return self.enum_layout(known, site);
}

impl MirLowering.enum_payload(layout: EnumLayout, member: EnumMemberLayout) -> int {
    return member.ordinal if layout.is_string_enum else member.int_value;
}

impl MirLowering.is_enum_class(nd: uni.UniNode) -> bool {
    if not isinstance(nd, uni.Expr) or not isinstance(nd.type, ClassType) {
        return False;
    }
    t = nd.type;
    return is_enum_class_type(t) and t.is_instantiable() and not t.is_instance();
}

impl MirLowering.attr_special(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not nd.is_attr
        or not isinstance(nd.right, uni.Name)
        or not isinstance(nd.target, uni.Expr) {
        return None;
    }
    if isinstance(nd.target.type, ModuleType) {
        return self.stdlib_attr(nd);
    }
    via_class = self.class_attr(nd);
    if via_class is not None {
        return via_class;
    }
    member = self.enum_member(nd);
    if member is not None {
        return member;
    }
    bound = self.sized_bound(nd);
    if bound is not None {
        return bound;
    }
    target_type = self.expr_type(nd.target);
    if target_type.kind == MirKind.COMPLEX and nd.right.value in ("real", "imag") {
        return self.emit_value(
            MirOp.TUPLE_GET,
            mir_float(),
            [self.lower_expr(nd.target)],
            int_value=0 if nd.right.value == "real" else 1
        );
    }
    if target_type.kind == MirKind.FILE and nd.right.value == "closed" {
        return self.runtime_value("__jac_rt_file_closed", [self.lower_expr(nd.target)]);
    }
    if target_type.kind == MirKind.ENUM and nd.right.value in ("name", "value") {
        return self.enum_attr(self.lower_expr(nd.target), nd.right.value, nd);
    }
    if target_type.kind == MirKind.CLASS and nd.right.value == "__name__" {
        return self.class_name_str(self.lower_expr(nd.target));
    }
    if nd.right.value == "__class__"
        and target_type.kind in (MirKind.OBJ, MirKind.ANY) {
        return self.class_of(self.lower_expr(nd.target), nd);
    }
    return None;
}

impl MirLowering.enum_member(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not self.is_enum_class(nd.target) or not isinstance(nd.right, uni.Name) {
        return None;
    }
    layout = self.enum_layout(nd.target.type, nd);
    for member in layout.members {
        if member.name == nd.right.value {
            return self.builder().const_int(
                self.enum_payload(layout, member), self.expr_type(nd)
            );
        }
    }
    raise MirRefused(mir_refusal("enum member", f"{layout.name}.{nd.right.value}", nd));
}

impl MirLowering.enum_attr(
    value: MirValue, name: str, site: uni.AtomTrailer
) -> MirValue {
    layout = self.enum_layout_of(value.type, site);
    if name == "name" {
        return self.enum_select(
            value, layout, [member.name for member in layout.members]
        );
    }
    if layout.is_string_enum {
        return self.enum_select(
            value, layout, [member.str_value or "" for member in layout.members]
        );
    }
    return self.builder().convert(value, mir_int());
}

impl MirLowering.enum_select(
    value: MirValue, layout: EnumLayout, texts: list[str]
) -> MirValue {
    b = self.builder();
    result = b.const_str(texts[-1], mir_str());
    pairs = list(zip(layout.members, texts));
    for (member, text) in reversed(pairs[:-1]) {
        result = b.select(
            b.compare(
                "eq", value, b.const_int(self.enum_payload(layout, member), value.type)
            ),
            b.const_str(text, mir_str()),
            result
        );
    }
    return result;
}

impl MirLowering.enum_str(value: MirValue, site: uni.UniNode) -> MirValue {
    layout = self.enum_layout_of(value.type, site);
    custom = self.enum_methods.get(f"{value.type.name}.__str__");
    if custom is not None and not custom.params {
        made = self.builder().call(custom.symbol, [value], custom.ret);
        if made is not None {
            return self.coerce(made, mir_str(), site);
        }
    }
    if self.enum_is_text(value.type) and layout.is_string_enum {
        return self.enum_select(
            value, layout, [member.str_value or "" for member in layout.members]
        );
    }
    return self.enum_select(
        value, layout, [f"{layout.name}.{member.name}" for member in layout.members]
    );
}

impl MirLowering.compare_special(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> (MirValue | None) {
    b = self.builder();
    if (left.type.kind == MirKind.ENUM or right.type.kind == MirKind.ENUM)
        and MirKind.OPT not in (left.type.kind, right.type.kind)
        and op not in (Tok.KW_IN, Tok.KW_NIN) {
        if MirKind.ANY in (left.type.kind, right.type.kind)
            and op in COMPARE_OPERATORS {
            return self.any_compare(COMPARE_OPERATORS[op], left, right, site);
        }
        if MirKind.ANY in (left.type.kind, right.type.kind)
            and op in (Tok.KW_IS, Tok.KW_ISN) {
            same = self.identity(left, right, site);
            return same if op == Tok.KW_IS else b.logical_not(same);
        }
        if MirKind.OPT in (left.type.kind, right.type.kind)
            and op in (Tok.EE, Tok.NE) {
            maybe = left if left.type.kind == MirKind.OPT else right;
            member = right if maybe is left else left;
            (held, payload, absent, done) = self.opt_begin(maybe, mir_bool());
            self.opt_switch(
                held,
                self.compare_values(
                    op,
                    payload if maybe is left else member,
                    member if maybe is left else payload,
                    site
                ),
                absent,
                done
            );
            return self.opt_end(held, b.const_bool(op == Tok.NE), done);
        }
        if left.type is not right.type
            and (left.type.is_numeric() or right.type.is_numeric()) {
            as_left = self.enum_as_int(left, site);
            as_right = self.enum_as_int(right, site);
            if as_left.type.kind != MirKind.ENUM
                and as_right.type.kind != MirKind.ENUM {
                return self.compare_values(op, as_left, as_right, site);
            }
        }
        if left.type is not right.type
            and op in (Tok.EE, Tok.NE)
            and (self.is_text(left) or self.is_text(right)) {
            member = left if left.type.kind == MirKind.ENUM else right;
            if self.enum_is_text(member.type) {
                text = self.enum_select(
                    member,
                    self.enum_layout_of(member.type, site),
                    [
                        known.str_value or ""
                        for known in self.enum_layout_of(member.type, site).members
                    ]
                );
                return self.compare_values(
                    op,
                    text if member is left else left,
                    text if member is right else right,
                    site
                );
            }
        }
        if left.type is not right.type
            and op in (Tok.EE, Tok.NE)
            and (left.type.is_numeric() or right.type.is_numeric()) {
            return b.const_bool(op == Tok.NE);
        }
        if left.type is not right.type {
            raise MirRefused(
                mir_refusal(
                    "comparison",
                    f"{left.type.render()} {op} {right.type.render()}",
                    site
                )
            );
        }
        if op in (Tok.EE, Tok.KW_IS) {
            return b.compare("eq", left, right);
        }
        if op in (Tok.NE, Tok.KW_ISN) {
            return b.compare("ne", left, right);
        }
        raise MirRefused(
            mir_refusal(
                "comparison",
                f"{op} on enum {left.type.name}",
                site,
                "Enum members compare by identity only."
            )
        );
    }
    if left.type.kind == MirKind.CLASS and right.type.kind == MirKind.CLASS {
        i8p = mir_c_ptr(mir_int(8, False));
        same = self.runtime_value(
            "__jac_rt_cstr_eq",
            [
                self.emit_value(MirOp.PTR_CAST, i8p, [left]),
                self.emit_value(MirOp.PTR_CAST, i8p, [right])
            ]
        );
        if op in (Tok.EE, Tok.KW_IS) {
            return same;
        }
        if op in (Tok.NE, Tok.KW_ISN) {
            return b.logical_not(same);
        }
        raise MirRefused(mir_refusal("comparison", f"{op} on types", site));
    }
    return None;
}

impl MirLowering.enum_is_text(t: MirType) -> bool {
    known = self.enum_types.get(t.name);
    if not isinstance(known, ClassType) or known._shared is None {
        return False;
    }
    return any(
        ancestor._shared is not None and ancestor.shared.class_name == "str"
        for ancestor in known.shared.mro
        if isinstance(ancestor, ClassType)
    );
}

impl MirLowering.enum_as_int(value: MirValue, site: uni.UniNode) -> MirValue {
    if value.type.kind != MirKind.ENUM
        or self.enum_layout_of(value.type, site).is_string_enum {
        return value;
    }
    return self.builder().convert(value, mir_int());
}

impl MirLowering.enum_coerce(
    value: MirValue, to: MirType, site: uni.UniNode
) -> MirValue {
    if value.type.kind == MirKind.ENUM and to.is_numeric() {
        as_int = self.enum_as_int(value, site);
        if as_int.type.kind == MirKind.INT {
            return self.coerce(as_int, to, site);
        }
    }
    if to.kind == MirKind.ENUM
        and value.type.kind in (MirKind.INT, MirKind.BOOL)
        and not self.enum_layout_of(to, site).is_string_enum {
        return self.builder().convert(self.coerce(value, mir_int(), site), to);
    }
    if value.type.kind == MirKind.ENUM and to.kind in (MirKind.STR, MirKind.STR_REF) {
        layout = self.enum_layout_of(value.type, site);
        if layout.is_string_enum {
            text = self.enum_select(
                value, layout, [member.str_value or "" for member in layout.members]
            );
            return self.coerce(text, to, site);
        }
    }
    raise MirRefused(
        mir_refusal(
            "conversion",
            f"{value.type.render()} to {to.render()}",
            site,
            "An enum member converts through `.value` or the enum's constructor."
        )
    );
}

impl MirLowering.enum_call(nd: uni.FuncCall) -> (MirValue | None) {
    if not self.is_enum_class(nd.target) {
        return None;
    }
    b = self.builder();
    layout = self.enum_layout(nd.target.type, nd);
    params = list(nd.params or []);
    if len(params) != 1 or isinstance(params[0], uni.KWPair) {
        raise MirRefused(
            mir_refusal(
                "enum constructor",
                layout.name,
                nd,
                f"Invoking '{layout.name}' as a constructor is a value-to-member lookup: the emitter checks the value against the declared member table and raises ValueError when it misses. It takes exactly one positional value. Read the member off the class, or move this call to a @sv/Python context."
            )
        );
    }
    result_type = self.expr_type(nd);
    value = self.lower_expr(params[0]);
    if value.type is result_type {
        return value;
    }
    if value.type.kind == MirKind.ANY {
        value = self.any_unbox(
            value, mir_str() if layout.is_string_enum else mir_int(), nd
        );
    }
    if value.type.kind == MirKind.STR_REF {
        value = self.as_text(value);
    }
    if value.type.kind == MirKind.ENUM {
        value = self.coerce(value, mir_str(), nd)
            if layout.is_string_enum
            else self.enum_as_int(value, nd);
    }
    if layout.is_string_enum {
        if value.type.kind != MirKind.STR {
            raise MirRefused(
                mir_refusal(
                    "enum constructor",
                    layout.name,
                    nd,
                    f"Invoking '{layout.name}' as a constructor is a value-to-member lookup. Its argument must be a string or a member of this enum."
                )
            );
        }
        ordinal = b.const_int(-1, mir_int());
        for member in reversed(layout.members) {
            hit = self.str_compare(
                "eq", value, b.const_str(member.str_value or "", mir_str())
            );
            ordinal = b.select(hit, b.const_int(member.ordinal, mir_int()), ordinal);
        }
        self.raise_if(
            b.compare("eq", ordinal, b.const_int(-1, mir_int())),
            "ValueError",
            f"is not a valid {layout.name}"
        );
        return b.convert(ordinal, result_type);
    }
    if value.type.kind != MirKind.INT {
        raise MirRefused(
            mir_refusal(
                "enum constructor",
                layout.name,
                nd,
                f"Invoking '{layout.name}' as a constructor is a value-to-member lookup. Its argument is not already an integer value, and coercing one to reach the table would answer for a value the caller never passed."
            )
        );
    }
    wide = b.convert(value, mir_int());
    known = b.const_bool(False);
    for member in layout.members {
        known = b.binary(
            "or", known, b.compare("eq", wide, b.const_int(member.int_value, mir_int()))
        );
    }
    self.raise_if(b.logical_not(known), "ValueError", f"is not a valid {layout.name}");
    return b.convert(wide, result_type);
}

impl MirLowering.enum_cursor(collection: uni.Expr) -> MirIterCursor {
    b = self.builder();
    layout = self.enum_layout(collection.type, collection);
    t = collection.type;
    if not isinstance(t, ClassType) {
        raise MirRefused(mir_refusal("iteration", str(t), collection));
    }
    elem = self.type_of(t.clone_as_instance(), MirPosition.VALUE, collection);
    position = self.temp_slot(mir_int());
    b.store(position, b.const_int(-1, mir_int()));
    return MirIterCursor(
        kind="enum",
        elem=elem,
        position=position,
        payloads=[self.enum_payload(layout, member) for member in layout.members]
    );
}

impl MirLowering.enum_self_type(decl: (uni.Archetype | uni.Enum)) -> (MirType | None) {
    sym = decl.name.sym if decl.name is not None else None;
    if sym is None {
        return None;
    }
    made = self.declared_type(sym);
    if not isinstance(made, ClassType) or not is_enum_class_type(made) {
        return None;
    }
    found = self.type_of(made.clone_as_instance(), MirPosition.VALUE, decl);
    return found if found.kind == MirKind.ENUM else None;
}

impl MirLowering.declare_enum_methods(
    decl: (uni.Archetype | uni.Enum), self_type: MirType
) {
    members: list[uni.Ability] = [];
    for stmt in list(ModuleFacts.unwrap_body(decl) or []) {
        if isinstance(stmt, uni.Ability) {
            members.append(stmt);
        } elif isinstance(stmt, uni.ModuleCode) {
            for inner in stmt.body {
                if isinstance(inner, uni.Ability) {
                    members.append(inner);
                }
            }
        }
    }
    path = self.module.loc.mod_path;
    for method in members {
        sig = method.signature;
        if not isinstance(sig, uni.FuncSignature) or method.is_static {
            continue;
        }
        name = self.name_of(method);
        params: list[MirType] = [];
        for pv in self.param_nodes(sig, True) {
            params.append(self.symbol_type(pv.name.sym, pv));
        }
        fn_type = self.declared_type(self.ability_sym(method));
        ret = mir_none();
        if isinstance(fn_type, FunctionType) {
            ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, method);
        }
        made = MirDecl(
            ability=method,
            symbol=native_symbol_name(
                native_unit_prefix(path),
                native_unit_spelling(f"{self_type.name}.{name}", path)
            ),
            params=params,
            ret=ret,
            self_type=self_type
        );
        key = id(method);
        self.decl_syms[id(self.ability_sym(method))] = key;
        self.decls[key] = made;
        self.enum_methods[f"{self_type.name}.{name}"] = made;
        self.order.append(key);
    }
}

impl MirLowering.enum_method_call(
    nd: uni.FuncCall, receiver: MirValue, name: str
) -> (MirValue | None) {
    decl = self.enum_methods.get(f"{receiver.type.name}.{name}")
        or self.foreign_enum_method(receiver.type, name);
    if decl is None {
        return None;
    }
    args = self.bound_args(nd, decl.ability, True);
    if len(args) != len(decl.params) {
        raise MirRefused(mir_refusal("call", f"{name} with {len(args)} arguments", nd));
    }
    values = [receiver]
        + [self.bound_value(arg, ptype) for (arg, ptype) in zip(args, decl.params)];
    made = self.builder().call(decl.symbol, values, decl.ret);
    return made if made is not None else self.builder().const_bool(False);
}

impl MirLowering.foreign_enum_method(
    enum_type: MirType, name: str
) -> (MirDecl | None) {
    known = self.enum_types.get(enum_type.name);
    decl = enum_decl_of(known) if known is not None else None;
    if decl is None {
        return None;
    }
    unit = decl.find_parent_of_type(uni.Module);
    if unit is None or unit is self.module or not unit.loc.mod_path.endswith(".jac") {
        return None;
    }
    members: list[uni.Ability] = [];
    for stmt in list(ModuleFacts.unwrap_body(decl) or []) {
        if isinstance(stmt, uni.Ability) {
            members.append(stmt);
        } elif isinstance(stmt, uni.ModuleCode) {
            for inner in stmt.body {
                if isinstance(inner, uni.Ability) {
                    members.append(inner);
                }
            }
        }
    }
    for method in members {
        sig = method.signature;
        if method.name_ref is None
            or self.name_of(method) != name
            or not isinstance(sig, uni.FuncSignature)
            or method.is_static {
            continue;
        }
        path = unit.loc.mod_path;
        params = [
            self.symbol_type(pv.name.sym, pv) for pv in self.param_nodes(sig, True)
        ];
        fn_type = self.declared_type(self.ability_sym(method));
        ret = mir_none();
        if isinstance(fn_type, FunctionType) {
            ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, method);
        }
        symbol = native_symbol_name(
            native_unit_prefix(path),
            native_unit_spelling(f"{enum_type.name}.{name}", path)
        );
        self.mir.externs[symbol] = MirExtern(
            symbol=symbol, ret=ret, params=[enum_type] + params
        );
        self.add_dep(path, symbol, method);
        made = MirDecl(
            ability=method, symbol=symbol, params=params, ret=ret, self_type=enum_type
        );
        self.enum_methods[f"{enum_type.name}.{name}"] = made;
        return made;
    }
    return None;
}

impl MirLowering.str_enum_int(nd: uni.FuncCall) -> (MirValue | None) {
    args = list(nd.params or []);
    if len(args) != 1
        or not isinstance(args[0], uni.Expr)
        or isinstance(args[0].type, (AnyType, FunctionType)) {
        return None;
    }
    subject = self.expr_type(args[0]);
    if subject.kind != MirKind.ENUM {
        return None;
    }
    layout = self.enum_layout_of(subject, nd);
    if not layout.is_string_enum {
        return None;
    }
    b = self.builder();
    self.lower_expr(args[0]);
    b.raise_builtin(
        "TypeError",
        f"int() argument must be a string, a bytes-like object or a real number, not '{layout.name}'"
    );
    b.position(self.st().fn.new_block("int.dead"));
    return b.const_int(0, mir_int());
}
