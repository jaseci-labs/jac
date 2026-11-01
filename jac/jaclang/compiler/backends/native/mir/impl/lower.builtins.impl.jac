impl MirLowering.builtin_value(nd: uni.FuncCall, name: str) -> (MirValue | None) {
    if name == "jid" {
        return self.lower_jid(nd);
    }
    args = self.call_args(nd);
    if not args and name in ("list", "dict", "set") {
        made = self.expr_type(nd);
        if made.kind == MirKind.LIST {
            return self.new_list(made.payload(), 0);
        }
        if made.kind == MirKind.DICT {
            return self.new_dict(made.args[0], made.args[1], made);
        }
        if made.kind == MirKind.SET {
            return self.new_dict(made.payload(), None, made);
        }
        raise MirRefused(mir_refusal("call", f"{name}() as {made.render()}", nd));
    }
    if len(args) != 1 {
        return None;
    }
    b = self.builder();
    if name == "id" {
        value = self.lower_expr(args[0]);
        if not mir_holds_ref(value.type)
            or value.type.kind in (MirKind.STR, MirKind.ANY, MirKind.OPT, MirKind.TUPLE) {
            raise MirRefused(mir_refusal("call", f"id of {value.type.render()}", nd));
        }
        return self.address_of(value);
    }
    if name in ("list", "reversed") {
        value = self.lower_expr(args[0]);
        if value.type.kind != MirKind.LIST {
            raise MirRefused(mir_refusal("call", f"{name} of {value.type.render()}", nd));
        }
        made = self.runtime(
            "__jac_rt_list_copy",
            [value, b.const_int(self.elem_kind(value.type.payload(), nd), mir_int())]
        );
        if made is None {
            raise MirRefused(mir_refusal("call", name, nd));
        }
        copied = b.ref_cast(made, value.type, True);
        if name == "reversed" {
            self.runtime("__jac_rt_list_reverse", [copied]);
        }
        return copied;
    }
    return None;
}

impl MirLowering.list_concat(left: MirValue, right: MirValue) -> MirValue {
    b = self.builder();
    kind = b.const_int(self.elem_kind(left.type.payload(), self.module), mir_int());
    made = self.runtime("__jac_rt_list_copy", [left, kind]);
    if made is None {
        raise MirRefused(mir_refusal("binary operator", "list +"));
    }
    joined = b.ref_cast(made, left.type, True);
    self.runtime("__jac_rt_list_extend", [joined, right, kind]);
    return joined;
}

impl MirLowering.str_subscript(nd: uni.AtomTrailer) -> (MirValue | None) {
    right = nd.right;
    if nd.is_attr
        or not isinstance(right, uni.IndexSlice)
        or not isinstance(nd.target, uni.Expr)
        or right.is_range
        or len(right.slices) != 1
        or right.slices[0].start is None
        or self.expr_type(nd.target).kind != MirKind.STR {
        return None;
    }
    b = self.builder();
    text = self.spill(self.lower_expr(nd.target));
    position = right.slices[0].start;
    at = self.coerce(self.lower_expr(position), mir_int(), position);
    count = self.runtime(
        "__jac_rt_str_len",
        [b.str_part(text, "root"), b.str_part(text, "data"), b.str_part(text, "len")]
    );
    if count is None {
        raise MirRefused(mir_refusal("subscript", "str", nd));
    }
    wrapped = b.select(
        b.compare("lt", at, b.const_int(0, mir_int())), b.binary("add", at, count), at
    );
    self.raise_if(
        b.binary(
            "or",
            b.compare("lt", wrapped, b.const_int(0, mir_int())),
            b.compare("ge", wrapped, count)
        ),
        "IndexError",
        STR_INDEX_MESSAGE
    );
    made = self.runtime(
        "__jac_rt_str_char_at", [b.str_part(text, "data"), b.str_part(text, "len"), wrapped]
    );
    size = self.runtime("__jac_rt_str_size", [made]) if made is not None else None;
    if made is None or size is None {
        raise MirRefused(mir_refusal("subscript", "str", nd));
    }
    return b.str_make(made, made, size);
}
