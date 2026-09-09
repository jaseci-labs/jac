impl NaIRGenPass._int_width_of(val: ir.Value) -> int {
    ty = val.type;
    assert isinstance(ty, ir.IntType) , "a sized integer op needs an integer";
    return ty.width;
}


import from jaclang.runtime.scalars { range_of, shape_of, wrap_value }

glob OVERFLOW_MSG: str = "integer overflow",
     SHIFT_MSG: str = "shift count out of range";

def _signed_repr(width: int, value: int) -> int {
    mask = (1 << width) - 1;
    out = value & mask;
    if out >= (1 << (width - 1)) {
        out -= 1 << width;
    }
    return out;
}

impl NaIRGenPass._scalar_shape_named(name: (str | None)) -> (ScalarShape | None) {
    if name is None {
        return None;
    }
    return shape_of(name);
}

impl NaIRGenPass._scalar_shape(nd: (uni.UniNode | None)) -> (ScalarShape | None) {
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

impl NaIRGenPass._is_signed_sized_node(nd: (uni.UniNode | None)) -> bool {
    shape = self._scalar_shape(nd);
    return shape is not None and shape.sized and not shape.is_float and shape.signed;
}

impl NaIRGenPass._is_unsigned_node(nd: (uni.UniNode | None)) -> bool {
    shape = self._scalar_shape(nd);
    return shape is not None
        and shape.sized
        and not shape.is_float
        and not shape.signed;
}

impl NaIRGenPass._is_sized_node(nd: (uni.UniNode | None)) -> bool {
    shape = self._scalar_shape(nd);
    return shape is not None and shape.sized;
}

impl NaIRGenPass._scalar_llvm(shape: ScalarShape) -> ir.Type {
    if shape.is_float {
        return ir.FloatType() if shape.width == 32 else ir.DoubleType();
    }
    return ir.IntType(shape.width);
}

impl NaIRGenPass._convert_scalar(
    val: ir.Value, src: ScalarShape, dst: ScalarShape
) -> ir.Value {
    dst_ty = self._scalar_llvm(dst);
    if val.type == dst_ty {
        return val;
    }
    from_unsigned = (not src.signed) or val.type == ir.IntType(1);
    if isinstance(val.type, ir.IntType) and isinstance(dst_ty, ir.IntType) {
        if self._int_width_of(val) < dst_ty.width {
            if from_unsigned {
                return self.builder.zext(val, dst_ty, name="widen.z");
            }
            return self.builder.sext(val, dst_ty, name="widen.s");
        }
        return self.builder.trunc(val, dst_ty, name="narrow");
    }
    if isinstance(val.type, ir.IntType) {
        if from_unsigned {
            return self.builder.uitofp(val, dst_ty, name="u2f");
        }
        return self.builder.sitofp(val, dst_ty, name="s2f");
    }
    if isinstance(dst_ty, ir.IntType) {
        return self._emit_float_to_int_cast(val, src, dst);
    }
    if isinstance(val.type, ir.FloatType) and isinstance(dst_ty, ir.DoubleType) {
        return self.builder.fpext(val, dst_ty, name="fpext");
    }
    if isinstance(val.type, ir.DoubleType) and isinstance(dst_ty, ir.FloatType) {
        return self.builder.fptrunc(val, dst_ty, name="fptrunc");
    }
    return val;
}

impl NaIRGenPass._lower_coercion(nd: uni.Expr, val: ir.Value) -> ir.Value {
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    dst = self._scalar_shape_named(nd.coerce_to);
    if dst is None {
        return val;
    }
    dst_ty = self._scalar_llvm(dst);
    if isinstance(val, ir.Constant) and isinstance(val.constant, (int, float)) {
        if isinstance(dst_ty, ir.IntType) {
            return ir.Constant(dst_ty, _signed_repr(dst.width, int(val.constant)));
        }
        return ir.Constant(dst_ty, float(val.constant));
    }
    src = self._scalar_shape_named(primitive_type_name_of(nd.type));
    if src is None {
        if isinstance(val.type, ir.IntType) {
            src = shape_of("bool" if self._int_width_of(val) == 1 else "int");
        } elif isinstance(val.type, (ir.FloatType, ir.DoubleType)) {
            src = shape_of("float");
        }
    }
    if src is None
        or not isinstance(val.type, (ir.IntType, ir.FloatType, ir.DoubleType)) {
        return val;
    }
    return self._convert_scalar(val, src, dst);
}

impl NaIRGenPass._emit_checked_int_cast(
    val: ir.Value, src: ScalarShape, dst: ScalarShape
) -> ir.Value {
    dst_ty = ir.IntType(dst.width);
    if self._int_width_of(val) == 1 {
        return self.builder.zext(val, dst_ty, name="cast.bool");
    }
    wide = ir.IntType(128);
    ext = (
        self.builder.sext(val, wide, name="cast.wide")
            if src.signed
            else self.builder.zext(val, wide, name="cast.wide")
    );
    (lo, hi) = range_of(dst.name);
    too_small = self.builder.icmp_signed(
        "<", ext, ir.Constant(wide, lo), name="cast.lo"
    );
    too_big = self.builder.icmp_signed(">", ext, ir.Constant(wide, hi), name="cast.hi");
    bad = self.builder.or_(too_small, too_big, name="cast.bad");
    self._emit_runtime_raise(bad, "OverflowError", OVERFLOW_MSG);
    return self.builder.trunc(ext, dst_ty, name="cast.val");
}

impl NaIRGenPass._emit_float_to_int_cast(
    val: ir.Value, src: ScalarShape, dst: ScalarShape
) -> ir.Value {
    f64 = ir.DoubleType();
    if isinstance(val.type, ir.FloatType) {
        val = self.builder.fpext(val, f64, name="cast.fpext");
    }
    (lo, hi) = range_of(dst.name);
    lo_m1 = lo - 1;
    hi_p1 = hi + 1;
    if float(lo_m1) == lo_m1 {
        above = self.builder.fcmp_ordered(
            ">", val, ir.Constant(f64, float(lo_m1)), name="cast.f.lo"
        );
    } else {
        above = self.builder.fcmp_ordered(
            ">=", val, ir.Constant(f64, float(lo)), name="cast.f.lo"
        );
    }
    if float(hi_p1) == hi_p1 {
        below = self.builder.fcmp_ordered(
            "<", val, ir.Constant(f64, float(hi_p1)), name="cast.f.hi"
        );
    } else {
        below = self.builder.fcmp_ordered(
            "<=", val, ir.Constant(f64, float(hi)), name="cast.f.hi"
        );
    }
    ok = self.builder.and_(above, below, name="cast.f.ok");
    bad = self.builder.not_(ok, name="cast.f.bad");
    self._emit_runtime_raise(bad, "OverflowError", OVERFLOW_MSG);
    dst_ty = ir.IntType(dst.width);
    if dst.signed {
        return self.builder.fptosi(val, dst_ty, name="cast.f2s");
    }
    return self.builder.fptoui(val, dst_ty, name="cast.f2u");
}

impl NaIRGenPass._emit_wrap_to(
    val: ir.Value, src: ScalarShape, dst: ScalarShape
) -> ir.Value {
    dst_ty = ir.IntType(dst.width);
    if isinstance(val.type, (ir.FloatType, ir.DoubleType)) {
        if isinstance(val.type, ir.FloatType) {
            val = self.builder.fpext(val, ir.DoubleType(), name="wrap.fpext");
        }
        wide = self.builder.fptosi(val, ir.IntType(128), name="wrap.f2i");
        return self.builder.trunc(wide, dst_ty, name="wrap.val");
    }
    if self._int_width_of(val) == dst.width {
        return val;
    }
    if self._int_width_of(val) > dst.width {
        return self.builder.trunc(val, dst_ty, name="wrap.val");
    }
    if src.signed and self._int_width_of(val) > 1 {
        return self.builder.sext(val, dst_ty, name="wrap.s");
    }
    return self.builder.zext(val, dst_ty, name="wrap.z");
}

impl NaIRGenPass._codegen_sized_cast(nd: uni.FuncCall, name: str) -> (ir.Value | None) {
    dst = self._scalar_shape_named(name);
    params = nd.params or [];
    if dst is None or len(params) != 1 {
        self.emit(E5092, node_override=nd, kind="fixed-width cast", name=name);
        return None;
    }
    arg = params[0];
    val = self._codegen_expr(arg);
    if val is None {
        return None;
    }
    src = self._scalar_shape(arg);
    if src is None {
        if isinstance(val.type, ir.IntType) {
            src = shape_of("bool" if self._int_width_of(val) == 1 else "int");
        } elif isinstance(val.type, (ir.FloatType, ir.DoubleType)) {
            src = shape_of("float");
        }
    }
    if src is None
        or not isinstance(val.type, (ir.IntType, ir.FloatType, ir.DoubleType)) {
        self.emit(E5092, node_override=nd, kind="fixed-width cast", name=name);
        return None;
    }
    if dst.is_float {
        return self._convert_scalar(val, src, dst);
    }
    if src.is_float {
        return self._emit_float_to_int_cast(val, src, dst);
    }
    return self._emit_checked_int_cast(val, src, dst);
}

impl NaIRGenPass._codegen_sized_wrap(nd: uni.FuncCall, name: str) -> (ir.Value | None) {
    dst = self._scalar_shape_named(name);
    params = nd.params or [];
    if dst is None or dst.is_float or len(params) != 1 {
        self.emit(E5092, node_override=nd, kind="fixed-width wrap", name=name);
        return None;
    }
    arg = params[0];
    val = self._codegen_expr(arg);
    if val is None {
        return None;
    }
    src = self._scalar_shape(arg);
    if src is None {
        if isinstance(val.type, ir.IntType) {
            src = shape_of("bool" if self._int_width_of(val) == 1 else "int");
        } else {
            src = shape_of("float");
        }
    }
    if src is None {
        return None;
    }
    return self._emit_wrap_to(val, src, dst);
}

impl NaIRGenPass._codegen_sized_bound(name: str, attr: str) -> (ir.Value | None) {
    shape = self._scalar_shape_named(name);
    if shape is None or shape.is_float or attr not in ("MIN", "MAX") {
        return None;
    }
    (lo, hi) = range_of(name);
    value = lo if attr == "MIN" else hi;
    return ir.Constant(ir.IntType(shape.width), _signed_repr(shape.width, value));
}

impl NaIRGenPass._codegen_type_name_str(name: str) -> ir.Value {
    return self._make_global_string(f"<class '{name}'>", name_prefix=".typename");
}

impl NaIRGenPass._codegen_wrapping(nd: uni.FuncCall, name: str) -> (ir.Value | None) {
    params = nd.params or [];
    vals: list = [];
    for p in params {
        v = self._codegen_expr(p);
        if v is None or not isinstance(v.type, ir.IntType) {
            self.emit(E5092, node_override=nd, kind="wrapping builtin", name=name);
            return None;
        }
        vals.append(v);
    }
    if name == "wrapping_neg" and len(vals) == 1 {
        return self.builder.sub(ir.Constant(vals[0].type, 0), vals[0], name="wneg");
    }
    if len(vals) != 2 or vals[0].type != vals[1].type {
        self.emit(E5092, node_override=nd, kind="wrapping builtin", name=name);
        return None;
    }
    (a, b) = (vals[0], vals[1]);
    if name == "wrapping_add" {
        return self.builder.add(a, b, name="wadd");
    }
    if name == "wrapping_sub" {
        return self.builder.sub(a, b, name="wsub");
    }
    if name == "wrapping_mul" {
        return self.builder.mul(a, b, name="wmul");
    }
    if name == "wrapping_shl" {
        count = self.builder.and_(
            b, ir.Constant(b.type, self._int_width_of(a) - 1), name="wshl.count"
        );
        return self.builder.shl(a, count, name="wshl");
    }
    self.emit(E5092, node_override=nd, kind="wrapping builtin", name=name);
    return None;
}

impl NaIRGenPass._emit_overflow_op(
    op: str, left: ir.Value, right: ir.Value, unsigned: bool
) -> ir.Value {
    int_ty = left.type;
    assert isinstance(int_ty, ir.IntType) , "an overflow-checked op needs an integer";
    prefix = "u" if unsigned else "s";
    overflow_ret = ir.LiteralStructType([int_ty, ir.IntType(1)]);
    intrinsic = self._get_or_declare_extern(
        f"llvm.{prefix}{op}.with.overflow.i{int_ty.width}",
        overflow_ret,
        [int_ty, int_ty]
    );
    result = self.builder.call(intrinsic, [left, right], name=f"{op}.ovf");
    val = self.builder.extract_value(result, 0, name=f"{op}.val");
    overflow = self.builder.extract_value(result, 1, name=f"{op}.overflow");
    self._emit_runtime_raise(overflow, "OverflowError", OVERFLOW_MSG);
    return val;
}

impl NaIRGenPass._emit_checked_neg(val: ir.Value) -> ir.Value {
    return self._emit_overflow_op("sub", ir.Constant(val.type, 0), val, False);
}

impl NaIRGenPass._emit_checked_abs(val: ir.Value) -> ir.Value {
    int_ty = val.type;
    assert isinstance(int_ty, ir.IntType) , "a sized integer op needs an integer";
    zero = ir.Constant(int_ty, 0);
    min_val = ir.Constant(int_ty, -(1 << (int_ty.width - 1)));
    is_min = self.builder.icmp_signed("==", val, min_val, name="abs.min");
    self._emit_runtime_raise(is_min, "OverflowError", OVERFLOW_MSG);
    is_neg = self.builder.icmp_signed("<", val, zero, name="abs.neg");
    negated = self.builder.sub(zero, val, name="abs.negated");
    return self.builder.select(is_neg, negated, val, name="abs");
}

impl NaIRGenPass._emit_shift_count_check(count: ir.Value, width: int) -> None {
    bad = self.builder.icmp_unsigned(
        ">=", count, ir.Constant(count.type, width), name="shift.bad"
    );
    self._emit_runtime_raise(bad, "OverflowError", SHIFT_MSG);
}

impl NaIRGenPass._shift_count_as(count: ir.Value, target: ir.IntType) -> ir.Value {
    if count.type == target {
        return count;
    }
    if self._int_width_of(count) > target.width {
        return self.builder.trunc(count, target, name="shift.count");
    }
    return self.builder.zext(count, target, name="shift.count");
}

impl NaIRGenPass._emit_checked_shl(
    left: ir.Value, right: ir.Value, unsigned: bool
) -> ir.Value {
    self._emit_shift_count_check(right, self._int_width_of(left));
    _shift_ty = left.type;
    assert isinstance(_shift_ty, ir.IntType) , "a shift operates on an integer";
    right = self._shift_count_as(right, _shift_ty);
    res = self.builder.shl(left, right, name="shl");
    back = (
        self.builder.lshr(res, right, name="shl.back")
            if unsigned
            else self.builder.ashr(res, right, name="shl.back")
    );
    lost = self.builder.icmp_signed("!=", back, left, name="shl.lost");
    self._emit_runtime_raise(lost, "OverflowError", OVERFLOW_MSG);
    return res;
}

impl NaIRGenPass._emit_shr(
    left: ir.Value, right: ir.Value, unsigned: bool
) -> ir.Value {
    self._emit_shift_count_check(right, self._int_width_of(left));
    _shift_ty = left.type;
    assert isinstance(_shift_ty, ir.IntType) , "a shift operates on an integer";
    right = self._shift_count_as(right, _shift_ty);
    if unsigned {
        return self.builder.lshr(left, right, name="lshr");
    }
    return self.builder.ashr(left, right, name="ashr");
}

impl NaIRGenPass._emit_int_divmod(
    left: ir.Value, right: ir.Value, unsigned: bool, trap_min: bool = True
) -> tuple[(ir.Value, ir.Value)] {
    int_ty = left.type;
    assert isinstance(int_ty, ir.IntType) , "an overflow-checked op needs an integer";
    if unsigned {
        return (
            self.builder.udiv(left, right, name="udiv"),
            self.builder.urem(left, right, name="urem")
        );
    }
    min_val = ir.Constant(int_ty, -(1 << (int_ty.width - 1)));
    is_min = self.builder.icmp_signed("==", left, min_val, name="div.min");
    is_m1 = self.builder.icmp_signed(
        "==", right, ir.Constant(int_ty, -1), name="div.m1"
    );
    bad = self.builder.and_(is_min, is_m1, name="div.ovf");
    if trap_min {
        self._emit_runtime_raise(bad, "OverflowError", OVERFLOW_MSG);
        return self._codegen_int_floor_divmod(left, right);
    }
    safe = self.builder.select(bad, ir.Constant(int_ty, 1), right, name="mod.safe");
    return self._codegen_int_floor_divmod(left, safe);
}
