import from jaclang.runtime.scalars { range_of, shape_of, wrap_value }

impl NativeLowering._scalar_shape_named(name: (str | None)) -> (ScalarShape | None) {
    if name is None {
        return None;
    }
    return shape_of(name);
}

impl NativeLowering._scalar_shape(nd: (uni.UniNode | None)) -> (ScalarShape | None) {
    while isinstance(nd, uni.CfgExpr) {
        nd = nd.expr;
    }
    if not isinstance(nd, uni.Expr) {
        return None;
    }
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    if nd.coerce_to is not None {
        coerced = self._scalar_shape_named(nd.coerce_to);
        if coerced is not None {
            return coerced;
        }
    }
    return self._scalar_shape_named(primitive_type_name_of(nd.type));
}

impl NativeLowering._is_signed_sized_node(nd: (uni.UniNode | None)) -> bool {
    shape = self._scalar_shape(nd);
    return shape is not None and shape.sized and not shape.is_float and shape.signed;
}

impl NativeLowering._is_unsigned_node(nd: (uni.UniNode | None)) -> bool {
    shape = self._scalar_shape(nd);
    return shape is not None
        and shape.sized
        and not shape.is_float
        and not shape.signed;
}

impl NativeLowering._is_sized_node(nd: (uni.UniNode | None)) -> bool {
    shape = self._scalar_shape(nd);
    return shape is not None and shape.sized;
}

impl NativeLowering._sized_cast_operand(
    nd: uni.FuncCall, name: str
) -> (tuple[ScalarShape, any] | None) {
    dst = self._scalar_shape_named(name);
    params: Sequence[any] = nd.params or [];
    if dst is None or len(params) != 1 {
        self.emit(E5092, node_override=nd, kind="fixed-width cast", name=name);
        return None;
    }
    return (dst, params[0]);
}

impl NativeLowering._sized_wrap_operand(
    nd: uni.FuncCall, name: str
) -> (tuple[ScalarShape, any] | None) {
    dst = self._scalar_shape_named(name);
    params: Sequence[any] = nd.params or [];
    if dst is None or dst.is_float or len(params) != 1 {
        self.emit(E5092, node_override=nd, kind="fixed-width wrap", name=name);
        return None;
    }
    return (dst, params[0]);
}
