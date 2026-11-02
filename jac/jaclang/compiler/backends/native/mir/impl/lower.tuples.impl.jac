impl MirLowering.lower_tuple(nd: uni.TupleVal) -> MirValue {
    result_type = self.expr_type(nd);
    members: list[MirValue] = [];
    for (index, item) in enumerate(nd.values) {
        if not isinstance(item, uni.Expr) {
            raise MirRefused(mir_refusal("tuple", "keyword member", item));
        }
        value = self.lower_expr(item);
        if result_type.kind == MirKind.TUPLE and index < len(result_type.args) {
            value = self.coerce(value, result_type.args[index], item);
        }
        members.append(value);
    }
    made_type = result_type
        if result_type.kind == MirKind.TUPLE
        else mir_tuple([member.type for member in members]);
    return self.emit_value(MirOp.TUPLE_MAKE, made_type, members);
}

impl MirLowering.tuple_get(value: MirValue, index: int) -> MirValue {
    size = len(value.type.args);
    at = index + size if index < 0 else index;
    if at < 0 or at >= size {
        raise MirRefused(mir_refusal("subscript", f"tuple index {index} of {size}"));
    }
    return self.emit_value(MirOp.TUPLE_GET, value.type.args[at], [value], int_value=at);
}

impl MirLowering.unpack_into(targets: list[uni.Expr], value: MirValue, site: uni.UniNode) {
    if value.type.kind != MirKind.TUPLE or len(value.type.args) != len(targets) {
        raise MirRefused(
            mir_refusal("assignment", f"unpacking {value.type.render()} into {len(targets)} names", site)
        );
    }
    held = self.spill(value);
    for (index, target) in enumerate(targets) {
        part = self.tuple_get(held, index);
        if isinstance(target, uni.Name) {
            self.store_name(target, part);
        } elif isinstance(target, uni.TupleVal) {
            self.unpack_into([t for t in target.values if isinstance(t, uni.Expr)], part, target);
        } else {
            raise MirRefused(mir_refusal("assignment", type(target).__name__, target));
        }
    }
}
