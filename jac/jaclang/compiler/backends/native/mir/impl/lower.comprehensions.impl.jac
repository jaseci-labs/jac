impl MirLowering.lower_comprehension(nd: (uni.ListCompr | uni.DictCompr)) -> MirValue {
    b = self.builder();
    result_type = self.expr_type(nd);
    made: MirValue;
    if isinstance(nd, uni.DictCompr) {
        if result_type.kind != MirKind.DICT {
            raise MirRefused(mir_refusal("dict comprehension", result_type.render(), nd));
        }
        made = self.spill(self.new_dict(result_type.args[0], result_type.args[1], result_type));
    } elif isinstance(nd, uni.SetCompr) {
        if result_type.kind != MirKind.SET {
            raise MirRefused(mir_refusal("set comprehension", result_type.render(), nd));
        }
        made = self.spill(self.new_dict(result_type.payload(), None, result_type));
    } elif isinstance(nd, uni.GenCompr) {
        if result_type.kind != MirKind.ITER {
            raise MirRefused(mir_refusal("generator expression", result_type.render(), nd));
        }
        made = self.spill(self.new_list(result_type.payload(), 8));
    } else {
        if result_type.kind != MirKind.LIST {
            raise MirRefused(mir_refusal("list comprehension", result_type.render(), nd));
        }
        made = self.spill(self.new_list(result_type.payload(), 8));
    }
    self.compr_level(nd, list(nd.compr), 0, made);
    if isinstance(nd, uni.GenCompr) {
        elem = result_type.payload();
        handle = self.runtime_value(
            "__jac_rt_iter_list", [made, b.const_int(self.elem_kind(elem, nd), mir_int())]
        );
        return b.ref_cast(handle, result_type, True);
    }
    return made;
}

impl MirLowering.compr_level(
    nd: (uni.ListCompr | uni.DictCompr),
    levels: list[uni.InnerCompr],
    index: int,
    made: MirValue
) {
    if index == len(levels) {
        self.compr_emit(nd, made);
        return;
    }
    level = levels[index];
    if level.is_async {
        raise MirRefused(mir_refusal("comprehension", "async for", level));
    }
    b = self.builder();
    fn = self.st().fn;
    (cursors, counter) = self.open_sources(level.collection);
    head = fn.new_block("compr.head");
    after = fn.new_block("compr.exit");
    b.branch(head);
    b.position(head);
    values = self.step_sources(cursors, counter, after);
    self.bind_values(level.target, values, level);
    for condition in list(level.conditional or []) {
        keep = fn.new_block("compr.keep");
        b.cond_branch(self.truthy(self.lower_expr(condition), condition), keep, head);
        b.position(keep);
    }
    self.compr_level(nd, levels, index + 1, made);
    if not b.block.terminated() {
        b.branch(head);
    }
    b.position(after);
}

impl MirLowering.compr_emit(nd: (uni.ListCompr | uni.DictCompr), made: MirValue) {
    b = self.builder();
    if isinstance(nd, uni.DictCompr) {
        pair = nd.kv_pair;
        if pair.key is None {
            raise MirRefused(mir_refusal("dict comprehension", "unpacking", pair));
        }
        (key_type, value_type) = (made.type.args[0], made.type.args[1]);
        key_bits = self.to_bits(self.lower_expr(pair.key), key_type, pair.key);
        value_bits = self.to_bits(self.lower_expr(pair.value), value_type, pair.value);
        self.runtime(
            "__jac_rt_dict_set",
            [
                made,
                key_bits,
                value_bits,
                b.const_int(self.elem_kind(key_type, nd), mir_int()),
                b.const_int(self.elem_kind(value_type, nd), mir_int())
            ]
        );
        return;
    }
    elem = made.type.payload();
    bits = self.to_bits(self.lower_expr(nd.out_expr), elem, nd.out_expr);
    kind = b.const_int(self.elem_kind(elem, nd), mir_int());
    if made.type.kind == MirKind.SET {
        self.runtime(
            "__jac_rt_dict_set",
            [made, bits, b.const_int(0, mir_int()), kind, b.const_int(NO_VALUE_KIND, mir_int())]
        );
        return;
    }
    self.runtime("__jac_rt_list_push", [made, bits, kind]);
}
