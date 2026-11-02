impl MirLowering.enum_layout(t: (TypeBase | None), site: uni.UniNode) -> EnumLayout {
    decl = enum_decl_of(t);
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
        raise MirRefused(mir_refusal("enum", name, site, "The enum has no native layout."));
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
    if not nd.is_attr or not isinstance(nd.right, uni.Name) or not isinstance(nd.target, uni.Expr) {
        return None;
    }
    member = self.enum_member(nd);
    if member is not None {
        return member;
    }
    target_type = self.expr_type(nd.target);
    if target_type.kind == MirKind.ENUM and nd.right.value in ("name", "value") {
        return self.enum_attr(self.lower_expr(nd.target), nd.right.value, nd);
    }
    if target_type.kind == MirKind.CLASS and nd.right.value == "__name__" {
        return self.class_name_str(self.lower_expr(nd.target));
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
            return self.builder().const_int(self.enum_payload(layout, member), self.expr_type(nd));
        }
    }
    raise MirRefused(mir_refusal("enum member", f"{layout.name}.{nd.right.value}", nd));
}

impl MirLowering.enum_attr(value: MirValue, name: str, site: uni.AtomTrailer) -> MirValue {
    layout = self.enum_layout(site.target.type, site);
    if name == "name" {
        return self.enum_select(value, layout, [member.name for member in layout.members]);
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
    return self.enum_select(
        value, layout, [f"{layout.name}.{member.name}" for member in layout.members]
    );
}

impl MirLowering.compare_special(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> (MirValue | None) {
    b = self.builder();
    if left.type.kind == MirKind.ENUM or right.type.kind == MirKind.ENUM {
        if left.type is not right.type {
            raise MirRefused(
                mir_refusal(
                    "comparison", f"{left.type.render()} {op} {right.type.render()}", site
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
            mir_refusal("comparison", f"{op} on enum {left.type.name}", site, "Enum members compare by identity only.")
        );
    }
    if left.type.kind == MirKind.CLASS and right.type.kind == MirKind.CLASS {
        i8p = mir_c_ptr(mir_int(8, False));
        same = self.runtime_value(
            "__jac_rt_cstr_eq",
            [self.emit_value(MirOp.PTR_CAST, i8p, [left]), self.emit_value(MirOp.PTR_CAST, i8p, [right])]
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

impl MirLowering.enum_coerce(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue {
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
            hit = self.str_compare("eq", value, b.const_str(member.str_value or "", mir_str()));
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
