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

impl NaIRGenPass._complex_aug_token(aug_op: str) -> (str | None) {
    return {
        "+=": Tok.PLUS,
        "-=": Tok.MINUS,
        "*=": Tok.STAR_MUL,
        "/=": Tok.DIV,
        "**=": Tok.STAR_POW
    }.get(
        aug_op
    );
}

impl NaIRGenPass._emit_complex_value(re: ir.Value, im: ir.Value) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    z0 = ir.Constant(i32, 0);
    z1 = ir.Constant(i32, 1);
    raw = self.builder.call(
        self.rc_alloc_fn, [ir.Constant(i64, 16)], name="cp.res.raw"
    );
    ptr = self.builder.bitcast(
        raw, self.complex_struct_type.as_pointer(), name="cp.res.ptr"
    );
    self.builder.store(re, self.builder.gep(ptr, [z0, z0], name="cp.res.rp"));
    self.builder.store(im, self.builder.gep(ptr, [z0, z1], name="cp.res.ip"));
    return ptr;
}

impl NaIRGenPass._load_complex_parts(ptr: ir.Value) -> tuple[(ir.Value, ir.Value)] {
    i32 = ir.IntType(32);
    z0 = ir.Constant(i32, 0);
    z1 = ir.Constant(i32, 1);
    re = self.builder.load(self.builder.gep(ptr, [z0, z0], name="c.re.p"), name="c.re");
    im = self.builder.load(self.builder.gep(ptr, [z0, z1], name="c.im.p"), name="c.im");
    return (re, im);
}

impl NaIRGenPass._target_fuses_fp -> bool {
    triple = str(self.llvm_module.triple or "").lower();
    return triple.startswith("aarch64") or triple.startswith("arm64");
}

impl NaIRGenPass._emit_fmadd(a: ir.Value, b: ir.Value, c: ir.Value) -> ir.Value {
    if self._target_fuses_fp() {
        f64 = ir.DoubleType();
        fma_fn = self._get_or_declare_extern("fma", f64, [f64, f64, f64]);
        return self.builder.call(fma_fn, [a, b, c], name="c.fma");
    }
    return self.builder.fadd(self.builder.fmul(a, b, name="c.fm"), c, name="c.fa");
}

impl NaIRGenPass._fp_fabs(v: ir.Value) -> ir.Value {
    f64 = ir.DoubleType();
    fabs_fn = self._get_or_declare_extern("fabs", f64, [f64]);
    return self.builder.call(fabs_fn, [v], name="c.abs");
}

impl NaIRGenPass._fp_copysign(mag: ir.Value, sgn: ir.Value) -> ir.Value {
    f64 = ir.DoubleType();
    copysign_fn = self._get_or_declare_extern("copysign", f64, [f64, f64]);
    return self.builder.call(copysign_fn, [mag, sgn], name="c.cps");
}

impl NaIRGenPass._fp_isnan(v: ir.Value) -> ir.Value {
    return self.builder.fcmp_unordered("!=", v, v, name="c.isnan");
}

impl NaIRGenPass._fp_isinf(v: ir.Value) -> ir.Value {
    inf = ir.Constant(ir.DoubleType(), float("inf"));
    return self.builder.fcmp_ordered("==", self._fp_fabs(v), inf, name="c.isinf");
}

impl NaIRGenPass._fp_isfinite(v: ir.Value) -> ir.Value {
    inf = ir.Constant(ir.DoubleType(), float("inf"));
    return self.builder.fcmp_ordered("<", self._fp_fabs(v), inf, name="c.isfin");
}

impl NaIRGenPass._emit_c_prod(
    ar: ir.Value, ai: ir.Value, br: ir.Value, bi: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    b = self.builder;
    f64 = ir.DoubleType();
    one = ir.Constant(f64, 1.0);
    zero = ir.Constant(f64, 0.0);
    inf = ir.Constant(f64, float("inf"));
    ac = b.fmul(ar, br, name="cm.ac");
    bd = b.fmul(ai, bi, name="cm.bd");
    ad = b.fmul(ar, bi, name="cm.ad");
    bc = b.fmul(ai, br, name="cm.bc");
    rr = b.fsub(ac, bd, name="cm.r");
    ri = b.fadd(ad, bc, name="cm.i");
    both_nan = b.and_(self._fp_isnan(rr), self._fp_isnan(ri), name="cm.nan2");
    a_inf = self._fp_isinf(ar);
    b_inf = self._fp_isinf(ai);
    z_inf = b.or_(a_inf, b_inf, name="cm.zinf");
    a1 = b.select(z_inf, self._fp_copysign(b.select(a_inf, one, zero), ar), ar);
    b1 = b.select(z_inf, self._fp_copysign(b.select(b_inf, one, zero), ai), ai);
    c1 = b.select(b.and_(z_inf, self._fp_isnan(br)), self._fp_copysign(zero, br), br);
    d1 = b.select(b.and_(z_inf, self._fp_isnan(bi)), self._fp_copysign(zero, bi), bi);
    c_inf = self._fp_isinf(c1);
    d_inf = self._fp_isinf(d1);
    w_inf = b.or_(c_inf, d_inf, name="cm.winf");
    c2 = b.select(w_inf, self._fp_copysign(b.select(c_inf, one, zero), c1), c1);
    d2 = b.select(w_inf, self._fp_copysign(b.select(d_inf, one, zero), d1), d1);
    a2 = b.select(b.and_(w_inf, self._fp_isnan(a1)), self._fp_copysign(zero, a1), a1);
    b2 = b.select(b.and_(w_inf, self._fp_isnan(b1)), self._fp_copysign(zero, b1), b1);
    boxed = b.or_(z_inf, w_inf, name="cm.boxed");
    prod_inf = b.or_(
        b.or_(self._fp_isinf(ac), self._fp_isinf(bd)),
        b.or_(self._fp_isinf(ad), self._fp_isinf(bc)),
        name="cm.pinf"
    );
    ovf = b.and_(b.not_(boxed), prod_inf, name="cm.ovf");
    a3 = b.select(b.and_(ovf, self._fp_isnan(a2)), self._fp_copysign(zero, a2), a2);
    b3 = b.select(b.and_(ovf, self._fp_isnan(b2)), self._fp_copysign(zero, b2), b2);
    c3 = b.select(b.and_(ovf, self._fp_isnan(c2)), self._fp_copysign(zero, c2), c2);
    d3 = b.select(b.and_(ovf, self._fp_isnan(d2)), self._fp_copysign(zero, d2), d2);
    recalc = b.and_(both_nan, b.or_(boxed, ovf), name="cm.recalc");
    rec_r = b.fmul(
        inf, self._emit_fmadd(a3, c3, b.fneg(b.fmul(b3, d3))), name="cm.rec.r"
    );
    rec_i = b.fmul(inf, self._emit_fmadd(a3, d3, b.fmul(b3, c3)), name="cm.rec.i");
    return (
        b.select(recalc, rec_r, rr, name="cm.out.r"),
        b.select(recalc, rec_i, ri, name="cm.out.i")
    );
}

impl NaIRGenPass._emit_c_quot(
    ar: ir.Value, ai: ir.Value, br: ir.Value, bi: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    f64 = ir.DoubleType();
    zero = ir.Constant(f64, 0.0);
    one = ir.Constant(f64, 1.0);
    inf = ir.Constant(f64, float("inf"));
    fnan = ir.Constant(f64, float("nan"));
    func = self.builder.function;
    res_r = self._entry_alloca(f64, "cq.r");
    res_i = self._entry_alloca(f64, "cq.i");
    abs_br = self._fp_fabs(br);
    abs_bi = self._fp_fabs(bi);
    re_bb = func.append_basic_block(name="cq.re");
    re_zero_bb = func.append_basic_block(name="cq.re.zero");
    re_div_bb = func.append_basic_block(name="cq.re.div");
    chk_im_bb = func.append_basic_block(name="cq.chk.im");
    im_bb = func.append_basic_block(name="cq.im");
    nan_bb = func.append_basic_block(name="cq.nan");
    post_bb = func.append_basic_block(name="cq.post");
    rec_bb = func.append_basic_block(name="cq.rec");
    rec_a_bb = func.append_basic_block(name="cq.rec.a");
    rec_chk_b_bb = func.append_basic_block(name="cq.rec.chkb");
    rec_b_bb = func.append_basic_block(name="cq.rec.b");
    done_bb = func.append_basic_block(name="cq.done");
    self.builder.cbranch(
        self.builder.fcmp_ordered(">=", abs_br, abs_bi, name="cq.ge"), re_bb, chk_im_bb
    );

    self.builder.position_at_end(re_bb);
    self.builder.cbranch(
        self.builder.fcmp_ordered("==", abs_br, zero, name="cq.bz"),
        re_zero_bb,
        re_div_bb
    );
    self.builder.position_at_end(re_zero_bb);
    self.builder.store(zero, res_r);
    self.builder.store(zero, res_i);
    self.builder.branch(post_bb);
    self.builder.position_at_end(re_div_bb);
    ratio = self.builder.fdiv(bi, br, name="cq.ratio");
    denom = self._emit_fmadd(bi, ratio, br);
    self.builder.store(
        self.builder.fdiv(self._emit_fmadd(ai, ratio, ar), denom, name="cq.rr"), res_r
    );
    self.builder.store(
        self.builder.fdiv(
            self._emit_fmadd(self.builder.fneg(ar), ratio, ai), denom, name="cq.ri"
        ),
        res_i
    );
    self.builder.branch(post_bb);

    self.builder.position_at_end(chk_im_bb);
    self.builder.cbranch(
        self.builder.fcmp_ordered(">=", abs_bi, abs_br, name="cq.ge2"), im_bb, nan_bb
    );
    self.builder.position_at_end(im_bb);
    ratio2 = self.builder.fdiv(br, bi, name="cq.ratio2");
    denom2 = self._emit_fmadd(br, ratio2, bi);
    self.builder.store(
        self.builder.fdiv(self._emit_fmadd(ar, ratio2, ai), denom2, name="cq.rr2"),
        res_r
    );
    self.builder.store(
        self.builder.fdiv(
            self._emit_fmadd(ai, ratio2, self.builder.fneg(ar)), denom2, name="cq.ri2"
        ),
        res_i
    );
    self.builder.branch(post_bb);

    self.builder.position_at_end(nan_bb);
    self.builder.store(fnan, res_r);
    self.builder.store(fnan, res_i);
    self.builder.branch(post_bb);

    self.builder.position_at_end(post_bb);
    cur_r = self.builder.load(res_r, name="cq.cur.r");
    cur_i = self.builder.load(res_i, name="cq.cur.i");
    self.builder.cbranch(
        self.builder.and_(self._fp_isnan(cur_r), self._fp_isnan(cur_i), name="cq.nan2"),
        rec_bb,
        done_bb
    );

    self.builder.position_at_end(rec_bb);
    a_inf = self.builder.or_(self._fp_isinf(ar), self._fp_isinf(ai), name="cq.ainf");
    b_fin = self.builder.and_(
        self._fp_isfinite(br), self._fp_isfinite(bi), name="cq.bfin"
    );
    self.builder.cbranch(
        self.builder.and_(a_inf, b_fin, name="cq.case.a"), rec_a_bb, rec_chk_b_bb
    );
    self.builder.position_at_end(rec_a_bb);
    box_ax = self._fp_copysign(
        self.builder.select(self._fp_isinf(ar), one, zero, name="cq.box_ax.m"), ar
    );
    box_ay = self._fp_copysign(
        self.builder.select(self._fp_isinf(ai), one, zero, name="cq.box_ay.m"), ai
    );
    self.builder.store(
        self.builder.fmul(
            inf,
            self._emit_fmadd(box_ax, br, self.builder.fmul(box_ay, bi)),
            name="cq.ra"
        ),
        res_r
    );
    self.builder.store(
        self.builder.fmul(
            inf,
            self._emit_fmadd(
                box_ay, br, self.builder.fneg(self.builder.fmul(box_ax, bi))
            ),
            name="cq.ia"
        ),
        res_i
    );
    self.builder.branch(done_bb);

    self.builder.position_at_end(rec_chk_b_bb);
    b_inf = self.builder.or_(
        self._fp_isinf(abs_br), self._fp_isinf(abs_bi), name="cq.binf"
    );
    a_fin = self.builder.and_(
        self._fp_isfinite(ar), self._fp_isfinite(ai), name="cq.afin"
    );
    self.builder.cbranch(
        self.builder.and_(b_inf, a_fin, name="cq.case.b"), rec_b_bb, done_bb
    );
    self.builder.position_at_end(rec_b_bb);
    box_x = self._fp_copysign(
        self.builder.select(self._fp_isinf(br), one, zero, name="cq.box_x.m"), br
    );
    box_y = self._fp_copysign(
        self.builder.select(self._fp_isinf(bi), one, zero, name="cq.box_y.m"), bi
    );
    self.builder.store(
        self.builder.fmul(
            zero,
            self._emit_fmadd(ar, box_x, self.builder.fmul(ai, box_y)),
            name="cq.rb"
        ),
        res_r
    );
    self.builder.store(
        self.builder.fmul(
            zero,
            self._emit_fmadd(
                ai, box_x, self.builder.fneg(self.builder.fmul(ar, box_y))
            ),
            name="cq.ib"
        ),
        res_i
    );
    self.builder.branch(done_bb);

    self.builder.position_at_end(done_bb);
    return (
        self.builder.load(res_r, name="cq.out.r"),
        self.builder.load(res_i, name="cq.out.i")
    );
}

impl NaIRGenPass._emit_rc_quot(
    x: ir.Value, br: ir.Value, bi: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    f64 = ir.DoubleType();
    zero = ir.Constant(f64, 0.0);
    one = ir.Constant(f64, 1.0);
    fnan = ir.Constant(f64, float("nan"));
    func = self.builder.function;
    res_r = self._entry_alloca(f64, "rq.r");
    res_i = self._entry_alloca(f64, "rq.i");
    abs_br = self._fp_fabs(br);
    abs_bi = self._fp_fabs(bi);
    re_bb = func.append_basic_block(name="rq.re");
    re_zero_bb = func.append_basic_block(name="rq.re.zero");
    re_div_bb = func.append_basic_block(name="rq.re.div");
    chk_im_bb = func.append_basic_block(name="rq.chk.im");
    im_bb = func.append_basic_block(name="rq.im");
    nan_bb = func.append_basic_block(name="rq.nan");
    post_bb = func.append_basic_block(name="rq.post");
    rec_bb = func.append_basic_block(name="rq.rec");
    done_bb = func.append_basic_block(name="rq.done");
    self.builder.cbranch(
        self.builder.fcmp_ordered(">=", abs_br, abs_bi, name="rq.ge"), re_bb, chk_im_bb
    );

    self.builder.position_at_end(re_bb);
    self.builder.cbranch(
        self.builder.fcmp_ordered("==", abs_br, zero, name="rq.bz"),
        re_zero_bb,
        re_div_bb
    );
    self.builder.position_at_end(re_zero_bb);
    self.builder.store(zero, res_r);
    self.builder.store(zero, res_i);
    self.builder.branch(post_bb);
    self.builder.position_at_end(re_div_bb);
    ratio = self.builder.fdiv(bi, br, name="rq.ratio");
    denom = self._emit_fmadd(bi, ratio, br);
    self.builder.store(self.builder.fdiv(x, denom, name="rq.rr"), res_r);
    self.builder.store(
        self.builder.fdiv(
            self.builder.fmul(self.builder.fneg(x), ratio, name="rq.ni"),
            denom,
            name="rq.ri"
        ),
        res_i
    );
    self.builder.branch(post_bb);

    self.builder.position_at_end(chk_im_bb);
    self.builder.cbranch(
        self.builder.fcmp_ordered(">=", abs_bi, abs_br, name="rq.ge2"), im_bb, nan_bb
    );
    self.builder.position_at_end(im_bb);
    ratio2 = self.builder.fdiv(br, bi, name="rq.ratio2");
    denom2 = self._emit_fmadd(br, ratio2, bi);
    self.builder.store(
        self.builder.fdiv(
            self.builder.fmul(x, ratio2, name="rq.nr2"), denom2, name="rq.rr2"
        ),
        res_r
    );
    self.builder.store(
        self.builder.fdiv(self.builder.fneg(x), denom2, name="rq.ri2"), res_i
    );
    self.builder.branch(post_bb);

    self.builder.position_at_end(nan_bb);
    self.builder.store(fnan, res_r);
    self.builder.store(fnan, res_i);
    self.builder.branch(post_bb);

    self.builder.position_at_end(post_bb);
    cur_r = self.builder.load(res_r, name="rq.cur.r");
    cur_i = self.builder.load(res_i, name="rq.cur.i");
    need = self.builder.and_(
        self.builder.and_(self._fp_isnan(cur_r), self._fp_isnan(cur_i)),
        self.builder.and_(
            self._fp_isfinite(x),
            self.builder.or_(self._fp_isinf(abs_br), self._fp_isinf(abs_bi))
        ),
        name="rq.need"
    );
    self.builder.cbranch(need, rec_bb, done_bb);
    self.builder.position_at_end(rec_bb);
    box_x = self._fp_copysign(
        self.builder.select(self._fp_isinf(br), one, zero, name="rq.box_x.m"), br
    );
    box_y = self._fp_copysign(
        self.builder.select(self._fp_isinf(bi), one, zero, name="rq.box_y.m"), bi
    );
    self.builder.store(
        self.builder.fmul(zero, self.builder.fmul(x, box_x), name="rq.rec.r"), res_r
    );
    self.builder.store(
        self.builder.fmul(
            zero, self.builder.fmul(self.builder.fneg(x), box_y), name="rq.rec.i"
        ),
        res_i
    );
    self.builder.branch(done_bb);

    self.builder.position_at_end(done_bb);
    return (
        self.builder.load(res_r, name="rq.out.r"),
        self.builder.load(res_i, name="rq.out.i")
    );
}

impl NaIRGenPass._emit_complex_binop(
    op: str, left: ir.Value, right: ir.Value
) -> (ir.Value | None) {
    ctype_ptr = self.complex_struct_type.as_pointer();
    f64 = ir.DoubleType();
    zero = ir.Constant(f64, 0.0);
    b = self.builder;
    l_cplx = left.type == ctype_ptr;
    r_cplx = right.type == ctype_ptr;
    if l_cplx and r_cplx {
        (ar, ai) = self._load_complex_parts(left);
        (br, bi) = self._load_complex_parts(right);
        if op == Tok.PLUS {
            return self._emit_complex_value(
                b.fadd(ar, br, name="cadd.r"), b.fadd(ai, bi, name="cadd.i")
            );
        }
        if op == Tok.MINUS {
            return self._emit_complex_value(
                b.fsub(ar, br, name="csub.r"), b.fsub(ai, bi, name="csub.i")
            );
        }
        if op == Tok.STAR_MUL {
            (pr, pi) = self._emit_c_prod(ar, ai, br, bi);
            return self._emit_complex_value(pr, pi);
        }
        if op == Tok.DIV {
            self._emit_runtime_raise(
                b.and_(b.fcmp_ordered("==", br, zero), b.fcmp_ordered("==", bi, zero)),
                "ZeroDivisionError",
                "division by zero"
            );
            (qr, qi) = self._emit_c_quot(ar, ai, br, bi);
            return self._emit_complex_value(qr, qi);
        }
        return None;
    }
    real_side = right if l_cplx else left;
    if not isinstance(real_side.type, (ir.IntType, ir.DoubleType, ir.FloatType)) {
        return None;
    }
    x = self._coerce_type(real_side, f64);
    if x is None {
        return None;
    }
    if l_cplx {
        (ar, ai) = self._load_complex_parts(left);
        if op == Tok.PLUS {
            return self._emit_complex_value(b.fadd(ar, x, name="crad.r"), ai);
        }
        if op == Tok.MINUS {
            return self._emit_complex_value(b.fsub(ar, x, name="crsb.r"), ai);
        }
        if op == Tok.STAR_MUL {
            return self._emit_complex_value(
                b.fmul(ar, x, name="crml.r"), b.fmul(ai, x, name="crml.i")
            );
        }
        if op == Tok.DIV {
            self._emit_runtime_raise(
                b.fcmp_ordered("==", x, zero), "ZeroDivisionError", "division by zero"
            );
            return self._emit_complex_value(
                b.fdiv(ar, x, name="crdv.r"), b.fdiv(ai, x, name="crdv.i")
            );
        }
        return None;
    }
    (br, bi) = self._load_complex_parts(right);
    if op == Tok.PLUS {
        return self._emit_complex_value(b.fadd(br, x, name="rcad.r"), bi);
    }
    if op == Tok.MINUS {
        return self._emit_complex_value(
            b.fsub(x, br, name="rcsb.r"), b.fneg(bi, name="rcsb.i")
        );
    }
    if op == Tok.STAR_MUL {
        return self._emit_complex_value(
            b.fmul(br, x, name="rcml.r"), b.fmul(bi, x, name="rcml.i")
        );
    }
    if op == Tok.DIV {
        self._emit_runtime_raise(
            b.and_(b.fcmp_ordered("==", br, zero), b.fcmp_ordered("==", bi, zero)),
            "ZeroDivisionError",
            "division by zero"
        );
        (qr, qi) = self._emit_rc_quot(x, br, bi);
        return self._emit_complex_value(qr, qi);
    }
    return None;
}

impl NaIRGenPass._codegen_complex_pow(
    base: ir.Value, exp: ir.Value
) -> (ir.Value | None) {
    f64 = ir.DoubleType();
    i64 = ir.IntType(64);
    ctype_ptr = self.complex_struct_type.as_pointer();
    _cb = base if base.type == ctype_ptr else self._emit_make_complex(base);
    _ce = exp if exp.type == ctype_ptr else self._emit_make_complex(exp);
    if _cb is None or _ce is None {
        return None;
    }
    (ar, ai) = self._load_complex_parts(_cb);
    (br, bi) = self._load_complex_parts(_ce);
    b = self.builder;
    fzero = ir.Constant(f64, 0.0);
    fone = ir.Constant(f64, 1.0);
    floor_fn = self._get_or_declare_extern("floor", f64, [f64]);
    hypot_fn = self._get_or_declare_extern("hypot", f64, [f64, f64]);
    pow_fn = self._get_or_declare_extern("pow", f64, [f64, f64]);
    atan2_fn = self._get_or_declare_extern("atan2", f64, [f64, f64]);
    exp_fn = self._get_or_declare_extern("exp", f64, [f64]);
    log_fn = self._get_or_declare_extern("log", f64, [f64]);
    cos_fn = self._get_or_declare_extern("cos", f64, [f64]);
    sin_fn = self._get_or_declare_extern("sin", f64, [f64]);
    func = b.function;
    res_r = self._entry_alloca(f64, "cp.res.r");
    res_i = self._entry_alloca(f64, "cp.res.i");
    acc_r = self._entry_alloca(f64, "cp.acc.r");
    acc_i = self._entry_alloca(f64, "cp.acc.i");
    cur_r = self._entry_alloca(f64, "cp.cur.r");
    cur_i = self._entry_alloca(f64, "cp.cur.i");
    mask_slot = self._entry_alloca(i64, "cp.mask");

    int_bb = func.append_basic_block(name="cp.int");
    loop_bb = func.append_basic_block(name="cp.loop");
    body_bb = func.append_basic_block(name="cp.body");
    mul_bb = func.append_basic_block(name="cp.mul");
    sq_bb = func.append_basic_block(name="cp.sq");
    after_bb = func.append_basic_block(name="cp.after");
    inv_bb = func.append_basic_block(name="cp.inv");
    keep_bb = func.append_basic_block(name="cp.keep");
    gen_bb = func.append_basic_block(name="cp.gen");
    one_bb = func.append_basic_block(name="cp.one");
    gen2_bb = func.append_basic_block(name="cp.gen2");
    azero_bb = func.append_basic_block(name="cp.azero");
    calc_bb = func.append_basic_block(name="cp.calc");
    im_bb = func.append_basic_block(name="cp.imexp");
    trig_bb = func.append_basic_block(name="cp.trig");
    chk_bb = func.append_basic_block(name="cp.chk");
    done_bb = func.append_basic_block(name="cp.done");

    is_int = b.and_(
        b.fcmp_ordered("==", bi, fzero, name="cp.bi0"),
        b.and_(
            b.fcmp_ordered(
                "==", br, b.call(floor_fn, [br], name="cp.flr"), name="cp.bint"
            ),
            b.fcmp_ordered(
                "<=", self._fp_fabs(br), ir.Constant(f64, 100.0), name="cp.small"
            ),
            name="cp.intchk"
        ),
        name="cp.isint"
    );
    b.cbranch(is_int, int_bb, gen_bb);

    b.position_at_end(int_bb);
    n = b.fptosi(br, i64, name="cp.n");
    is_neg = b.icmp_signed("<", n, ir.Constant(i64, 0), name="cp.nneg");
    m = b.select(is_neg, b.neg(n, name="cp.nabs"), n, name="cp.m");
    b.store(fone, acc_r);
    b.store(fzero, acc_i);
    b.store(ar, cur_r);
    b.store(ai, cur_i);
    b.store(ir.Constant(i64, 1), mask_slot);
    b.branch(loop_bb);

    b.position_at_end(loop_bb);
    mask_v = b.load(mask_slot, name="cp.mask.v");
    b.cbranch(b.icmp_signed(">=", m, mask_v, name="cp.more"), body_bb, after_bb);

    b.position_at_end(body_bb);
    b.cbranch(
        b.icmp_signed("!=", b.and_(m, mask_v), ir.Constant(i64, 0), name="cp.bit"),
        mul_bb,
        sq_bb
    );

    b.position_at_end(mul_bb);
    (mr, mi) = self._emit_c_prod(
        b.load(acc_r), b.load(acc_i), b.load(cur_r), b.load(cur_i)
    );
    b.store(mr, acc_r);
    b.store(mi, acc_i);
    b.branch(sq_bb);

    b.position_at_end(sq_bb);
    b.store(b.shl(b.load(mask_slot), ir.Constant(i64, 1), name="cp.mask.n"), mask_slot);
    c_r = b.load(cur_r, name="cp.c.r");
    c_i = b.load(cur_i, name="cp.c.i");
    (sr, si) = self._emit_c_prod(c_r, c_i, c_r, c_i);
    b.store(sr, cur_r);
    b.store(si, cur_i);
    b.branch(loop_bb);

    b.position_at_end(after_bb);
    b.cbranch(is_neg, inv_bb, keep_bb);

    b.position_at_end(inv_bb);
    pw_r = b.load(acc_r, name="cp.pw.r");
    pw_i = b.load(acc_i, name="cp.pw.i");
    self._emit_runtime_raise(
        b.and_(b.fcmp_ordered("==", pw_r, fzero), b.fcmp_ordered("==", pw_i, fzero)),
        "ZeroDivisionError",
        "zero to a negative or complex power"
    );
    (iq_r, iq_i) = self._emit_c_quot(fone, fzero, pw_r, pw_i);
    b.store(iq_r, res_r);
    b.store(iq_i, res_i);
    b.branch(chk_bb);

    b.position_at_end(keep_bb);
    b.store(b.load(acc_r), res_r);
    b.store(b.load(acc_i), res_i);
    b.branch(chk_bb);

    b.position_at_end(gen_bb);
    b.cbranch(
        b.and_(b.fcmp_ordered("==", br, fzero), b.fcmp_ordered("==", bi, fzero)),
        one_bb,
        gen2_bb
    );
    b.position_at_end(one_bb);
    b.store(fone, res_r);
    b.store(fzero, res_i);
    b.branch(done_bb);

    b.position_at_end(gen2_bb);
    b.cbranch(
        b.and_(b.fcmp_ordered("==", ar, fzero), b.fcmp_ordered("==", ai, fzero)),
        azero_bb,
        calc_bb
    );
    b.position_at_end(azero_bb);
    self._emit_runtime_raise(
        b.or_(b.fcmp_unordered("!=", bi, fzero), b.fcmp_ordered("<", br, fzero)),
        "ZeroDivisionError",
        "zero to a negative or complex power"
    );
    b.store(fzero, res_r);
    b.store(fzero, res_i);
    b.branch(done_bb);

    b.position_at_end(calc_bb);
    vabs = b.call(hypot_fn, [ar, ai], name="cp.vabs");
    len0 = b.call(pow_fn, [vabs, br], name="cp.len");
    at = b.call(atan2_fn, [ai, ar], name="cp.at");
    phase0 = b.fmul(at, br, name="cp.phase");
    calc_end = b.block;
    b.cbranch(b.fcmp_unordered("!=", bi, fzero, name="cp.bim"), im_bb, trig_bb);
    b.position_at_end(im_bb);
    len1 = b.fmul(
        len0, b.call(exp_fn, [b.fmul(b.fneg(at), bi)], name="cp.ex"), name="cp.len1"
    );
    phase1 = self._emit_fmadd(bi, b.call(log_fn, [vabs], name="cp.lv"), phase0);
    im_end = b.block;
    b.branch(trig_bb);
    b.position_at_end(trig_bb);
    len_v = b.phi(f64, name="cp.len.v");
    len_v.add_incoming(len0, calc_end);
    len_v.add_incoming(len1, im_end);
    phase_v = b.phi(f64, name="cp.phase.v");
    phase_v.add_incoming(phase0, calc_end);
    phase_v.add_incoming(phase1, im_end);
    b.store(b.fmul(len_v, b.call(cos_fn, [phase_v]), name="cp.rr"), res_r);
    b.store(b.fmul(len_v, b.call(sin_fn, [phase_v]), name="cp.ri"), res_i);
    b.branch(chk_bb);

    b.position_at_end(chk_bb);
    self._emit_runtime_raise(
        b.or_(
            self._fp_isinf(b.load(res_r, name="cp.chk.r")),
            self._fp_isinf(b.load(res_i, name="cp.chk.i"))
        ),
        "OverflowError",
        "complex exponentiation"
    );
    b.branch(done_bb);

    b.position_at_end(done_bb);
    return self._emit_complex_value(
        b.load(res_r, name="cp.out.r"), b.load(res_i, name="cp.out.i")
    );
}

impl NaIRGenPass._emit_make_complex(v: ir.Value) -> (ir.Value | None) {
    f64 = ir.DoubleType();
    fv = self._coerce_type(v, f64);
    if fv is None {
        return None;
    }
    return self._emit_complex_value(fv, ir.Constant(f64, 0.0));
}

impl NaIRGenPass._codegen_pow(
    base: ir.Value,
    exp: ir.Value,
    exp_node: (uni.Expr | None) = None,
    unsigned: bool = False,
    checked: bool = False
) -> (ir.Value | None) {
    ctype_ptr = self.complex_struct_type.as_pointer();
    if base.type == ctype_ptr or exp.type == ctype_ptr {
        return self._codegen_complex_pow(base, exp);
    }
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
