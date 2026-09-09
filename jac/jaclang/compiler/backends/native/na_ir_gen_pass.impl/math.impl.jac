import from jaclang.compiler.frontend.const_fold { fold_const }

glob _MATH_CONSTS: dict[str, float] = {
         "pi": 3.141592653589793,
         "e": 2.718281828459045,
         "tau": 6.283185307179586,
         "inf": float("inf"),
         "nan": float("nan"),

     },
     _MATH_UNARY: dict[str, str] = {
         "sqrt": "sqrt",
         "sin": "sin",
         "cos": "cos",
         "tan": "tan",
         "asin": "asin",
         "acos": "acos",
         "atan": "atan",
         "sinh": "sinh",
         "cosh": "cosh",
         "tanh": "tanh",
         "asinh": "asinh",
         "acosh": "acosh",
         "atanh": "atanh",
         "exp": "exp",
         "expm1": "expm1",
         "log2": "log2",
         "log10": "log10",
         "log1p": "log1p",
         "fabs": "fabs",
         "cbrt": "cbrt",
         "erf": "erf",
         "erfc": "erfc",
         "gamma": "tgamma",
         "lgamma": "lgamma",

     },
     _MATH_BINARY: dict[str, str] = {
         "pow": "pow",
         "atan2": "atan2",
         "hypot": "hypot",
         "fmod": "fmod",
         "copysign": "copysign",
         "remainder": "remainder",

     },
     _MATH_TO_INT: set[str] = {"floor", "ceil", "trunc"};

impl NaIRGenPass._emit_math_const(name: str) -> (ir.Value | None) {
    if name in _MATH_CONSTS {
        return ir.Constant(ir.DoubleType(), _MATH_CONSTS[name]);
    }
    return None;
}

impl NaIRGenPass._emit_math_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) {
    f64 = ir.DoubleType();
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    params = nd.params or [];

    args: list[ir.Value] = [];
    for p in params {
        v = self._codegen_expr(p);
        if v is None {
            return None;
        }
        args.append(self._coerce_type(v, f64));
    }

    if name in _MATH_UNARY and len(args) == 1 {
        fn = self._get_or_declare_extern(_MATH_UNARY[name], f64, [f64]);
        return self.builder.call(fn, [args[0]], name=f"math.{name}");
    }

    if name in _MATH_TO_INT and len(args) == 1 {
        fn = self._get_or_declare_extern(name, f64, [f64]);
        d = self.builder.call(fn, [args[0]], name=f"math.{name}.d");
        return self.builder.fptosi(d, i64, name=f"math.{name}");
    }

    if name in _MATH_BINARY and len(args) == 2 {
        fn = self._get_or_declare_extern(_MATH_BINARY[name], f64, [f64, f64]);
        return self.builder.call(fn, [args[0], args[1]], name=f"math.{name}");
    }

    if name == "log" and len(args) >= 1 {
        logfn = self._get_or_declare_extern("log", f64, [f64]);
        lx = self.builder.call(logfn, [args[0]], name="math.log.x");
        if len(args) == 1 {
            return lx;
        }
        lb = self.builder.call(logfn, [args[1]], name="math.log.base");
        return self.builder.fdiv(lx, lb, name="math.log");
    }

    if name == "degrees" and len(args) == 1 {
        k = ir.Constant(f64, 180.0 / 3.141592653589793);
        return self.builder.fmul(args[0], k, name="math.degrees");
    }
    if name == "radians" and len(args) == 1 {
        k = ir.Constant(f64, 3.141592653589793 / 180.0);
        return self.builder.fmul(args[0], k, name="math.radians");
    }

    if name == "isnan" and len(args) == 1 {
        return self.builder.fcmp_unordered("!=", args[0], args[0], name="math.isnan");
    }
    if name == "isinf" and len(args) == 1 {
        fabsfn = self._get_or_declare_extern("fabs", f64, [f64]);
        a = self.builder.call(fabsfn, [args[0]], name="math.isinf.abs");
        inf = ir.Constant(f64, float("inf"));
        return self.builder.fcmp_ordered("==", a, inf, name="math.isinf");
    }
    if name == "isfinite" and len(args) == 1 {
        ord_eq = self.builder.fcmp_ordered("==", args[0], args[0], name="math.fin.ord");
        fabsfn = self._get_or_declare_extern("fabs", f64, [f64]);
        a = self.builder.call(fabsfn, [args[0]], name="math.fin.abs");
        inf = ir.Constant(f64, float("inf"));
        not_inf = self.builder.fcmp_ordered("!=", a, inf, name="math.fin.noinf");
        return self.builder.and_(ord_eq, not_inf, name="math.isfinite");
    }

    return None;
}


impl NaIRGenPass._emit_float_pow(
    base: ir.Value, exp: ir.Value, unsigned: bool = False
) -> ir.Value {
    f64 = ir.DoubleType();
    (fleft, fright) = self._promote_to_float(base, exp, unsigned=unsigned);
    if isinstance(fleft.type, ir.FloatType) {
        f32 = ir.FloatType();
        powf_fn = self._get_or_declare_extern("powf", f32, [f32, f32]);
        return self.builder.call(powf_fn, [fleft, fright], name="pow.f32");
    }
    pow_fn = self._get_or_declare_extern("pow", f64, [f64, f64]);
    return self.builder.call(pow_fn, [fleft, fright], name="pow.f");
}

impl NaIRGenPass._emit_pow_zero_guard(base: ir.Value) -> None {
    if isinstance(base.type, ir.IntType) {
        is_zero = self.builder.icmp_signed(
            "==", base, ir.Constant(base.type, 0), name="pow.zero.b"
        );
    } else {
        fzero = ir.Constant(base.type, 0.0);
        is_zero = self.builder.fcmp_ordered("==", base, fzero, name="pow.zero.b");
    }
    self._emit_runtime_raise(
        is_zero, "ZeroDivisionError", "0.0 cannot be raised to a negative power"
    );
}

impl NaIRGenPass._codegen_int_pow(
    base: ir.Value, exp: ir.Value, unsigned: bool = False, checked: bool = False
) -> ir.Value {
    int_ty = base.type;
    one = ir.Constant(int_ty, 1);
    func = self.builder.function;

    result_alloca = self._entry_alloca(int_ty, "pow.result");
    counter_alloca = self._entry_alloca(int_ty, "pow.counter");
    self.builder.store(one, result_alloca);
    self.builder.store(ir.Constant(int_ty, 0), counter_alloca);

    cond_bb = func.append_basic_block(name="pow.cond");
    body_bb = func.append_basic_block(name="pow.body");
    end_bb = func.append_basic_block(name="pow.end");
    self.builder.branch(cond_bb);

    self.builder.position_at_end(cond_bb);
    counter = self.builder.load(counter_alloca, name="pow.i");
    cmp = self.builder.icmp_signed("<", counter, exp, name="pow.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);

    self.builder.position_at_end(body_bb);
    cur_result = self.builder.load(result_alloca, name="pow.cur");
    new_result = (
        self._emit_overflow_op("mul", cur_result, base, unsigned)
            if checked
            else self.builder.mul(cur_result, base, name="pow.mul")
    );
    self.builder.store(new_result, result_alloca);
    cur_counter = self.builder.load(counter_alloca, name="pow.ci");
    next_counter = self.builder.add(cur_counter, one, name="pow.inc");
    self.builder.store(next_counter, counter_alloca);
    self.builder.branch(cond_bb);

    self.builder.position_at_end(end_bb);
    return self.builder.load(result_alloca, name="pow.final");
}

impl NaIRGenPass._codegen_pow(
    base: ir.Value,
    exp: ir.Value,
    exp_node: (uni.Expr | None) = None,
    unsigned: bool = False,
    checked: bool = False
) -> ir.Value {
    f64 = ir.DoubleType();
    is_float_op = isinstance(base.type, (ir.DoubleType, ir.FloatType))
        or isinstance(exp.type, (ir.DoubleType, ir.FloatType));

    if is_float_op {
        exp_known_neg = False;
        if exp_node is not None {
            (rok, rv) = fold_const(exp_node);
            if rok and isinstance(rv, (int, float)) and rv < 0 {
                self._emit_pow_zero_guard(base);
                exp_known_neg = True;
            }
        }
        if not exp_known_neg {
            (fbase, fexp) = self._promote_to_float(base, exp);
            fzero = ir.Constant(f64, 0.0);
            is_neg = self.builder.fcmp_ordered("<", fexp, fzero, name="pow.fneg.chk");
            func = self.builder.function;
            neg_bb = func.append_basic_block(name="pow.fneg");
            pos_bb = func.append_basic_block(name="pow.fpos");
            merge_bb = func.append_basic_block(name="pow.fmerge");
            self.builder.cbranch(is_neg, neg_bb, pos_bb);
            self.builder.position_at_end(neg_bb);
            self._emit_pow_zero_guard(base);
            fres = self._emit_float_pow(base, exp);
            neg_pred = self.builder.block;
            self.builder.branch(merge_bb);
            self.builder.position_at_end(pos_bb);
            fpres = self._emit_float_pow(base, exp);
            pos_pred = self.builder.block;
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            phi = self.builder.phi(f64, name="pow.fres");
            phi.add_incoming(fres, neg_pred);
            phi.add_incoming(fpres, pos_pred);
            return phi;
        }
        return self._emit_float_pow(base, exp);
    }

    exp_known: bool = False;
    exp_val: int = 0;
    if exp_node is not None {
        (rok, rv) = fold_const(exp_node);
        if rok and isinstance(rv, int) {
            exp_known = True;
            exp_val = rv;
        }
    }

    (base, exp) = self._unify_int_widths(base, exp);

    if exp_known {
        if exp_val < 0 {
            self._emit_pow_zero_guard(base);
            return self._emit_float_pow(base, exp, unsigned);
        }
        return self._codegen_int_pow(base, exp, unsigned, checked);
    }
    if unsigned {
        return self._codegen_int_pow(base, exp, True, checked);
    }

    int_ty = base.type;
    izero = ir.Constant(int_ty, 0);
    is_neg = self.builder.icmp_signed("<", exp, izero, name="pow.neg.chk");

    func = self.builder.function;
    neg_bb = func.append_basic_block(name="pow.neg");
    pos_bb = func.append_basic_block(name="pow.pos");
    merge_bb = func.append_basic_block(name="pow.merge");
    self.builder.cbranch(is_neg, neg_bb, pos_bb);

    self.builder.position_at_end(neg_bb);
    self._emit_pow_zero_guard(base);
    fres = self._emit_float_pow(base, exp);
    neg_pred = self.builder.block;
    self.builder.branch(merge_bb);

    self.builder.position_at_end(pos_bb);
    iresult = self._codegen_int_pow(base, exp, unsigned, checked);
    pos_pred = self.builder.block;
    i_as_f = self.builder.sitofp(iresult, f64, name="pow.i2f");
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
    phi = self.builder.phi(f64, name="pow.res");
    phi.add_incoming(fres, neg_pred);
    phi.add_incoming(i_as_f, pos_pred);
    return phi;
}
