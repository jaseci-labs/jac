import from jaclang.compiler.frontend.const_fold { fold_const }

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
