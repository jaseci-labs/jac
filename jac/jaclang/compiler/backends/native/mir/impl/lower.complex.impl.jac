impl MirLowering.complex_make(re: MirValue, im: MirValue) -> MirValue {
    return self.emit_value(MirOp.TUPLE_MAKE, mir_complex(), [re, im]);
}

impl MirLowering.complex_parts(value: MirValue) -> tuple[MirValue, MirValue] {
    b = self.builder();
    if value.type.kind == MirKind.COMPLEX {
        return (
            self.emit_value(MirOp.TUPLE_GET, mir_float(), [value], int_value=0),
            self.emit_value(MirOp.TUPLE_GET, mir_float(), [value], int_value=1)
        );
    }
    return (b.convert(value, mir_float()), b.const_float(0.0, mir_float()));
}

impl MirLowering.complex_call(args: list[uni.Expr], site: uni.UniNode) -> MirValue {
    b = self.builder();
    zero = b.const_float(0.0, mir_float());
    if len(args) > 2 {
        raise MirRefused(
            mir_refusal("call", f"complex with {len(args)} arguments", site)
        );
    }
    parts: list[MirValue] = [];
    for arg in args {
        value = self.lower_expr(arg);
        if value.type.kind != MirKind.COMPLEX and not value.type.is_numeric() {
            raise MirRefused(
                mir_refusal(
                    "call",
                    f"complex of {value.type.render()}",
                    arg,
                    "Native complex() takes numbers; parse a complex literal on the server."
                )
            );
        }
        parts.append(value);
    }
    if not parts {
        return self.complex_make(zero, zero);
    }
    (re, im) = self.complex_parts(parts[0]);
    if len(parts) == 1 {
        return self.complex_make(re, im);
    }
    (sr, si) = self.complex_parts(parts[1]);
    if parts[1].type.kind != MirKind.COMPLEX {
        if parts[0].type.kind != MirKind.COMPLEX {
            return self.complex_make(re, sr);
        }
        return self.complex_make(re, b.binary("add", im, sr));
    }
    return self.complex_make(b.binary("sub", re, si), b.binary("add", im, sr));
}

impl MirLowering.f_abs(x: MirValue) -> MirValue {
    b = self.builder();
    bits = self.emit_value(MirOp.BITCAST, mir_int(64, True, True), [x]);
    mask = b.const_int((1 << 63) - 1, bits.type);
    return self.emit_value(MirOp.BITCAST, mir_float(), [b.binary("and", bits, mask)]);
}

impl MirLowering.f_copysign(mag: MirValue, sign: MirValue) -> MirValue {
    b = self.builder();
    wide = mir_int(64, True, True);
    low = b.const_int((1 << 63) - 1, wide);
    high = b.const_int(-(1 << 63), wide);
    kept = b.binary("and", self.emit_value(MirOp.BITCAST, wide, [mag]), low);
    signed = b.binary("and", self.emit_value(MirOp.BITCAST, wide, [sign]), high);
    return self.emit_value(MirOp.BITCAST, mir_float(), [b.binary("or", kept, signed)]);
}

impl MirLowering.f_isnan(x: MirValue) -> MirValue {
    return self.builder().compare("ne", x, x);
}

impl MirLowering.f_isinf(x: MirValue) -> MirValue {
    b = self.builder();
    return b.compare("eq", self.f_abs(x), b.const_float(float("inf"), mir_float()));
}

impl MirLowering.f_isfinite(x: MirValue) -> MirValue {
    b = self.builder();
    return b.compare("lt", self.f_abs(x), b.const_float(float("inf"), mir_float()));
}

impl MirLowering.f_box(x: MirValue) -> MirValue {
    b = self.builder();
    return self.f_copysign(
        b.select(
            self.f_isinf(x),
            b.const_float(1.0, mir_float()),
            b.const_float(0.0, mir_float())
        ),
        x
    );
}

impl MirLowering.f_unnan(cond: MirValue, x: MirValue) -> MirValue {
    b = self.builder();
    return b.select(
        b.binary("and", cond, self.f_isnan(x)),
        self.f_copysign(b.const_float(0.0, mir_float()), x),
        x
    );
}

impl MirLowering.complex_prod(
    ar: MirValue, ai: MirValue, br: MirValue, bi: MirValue
) -> tuple[MirValue, MirValue] {
    b = self.builder();
    one = b.const_float(1.0, mir_float());
    zero = b.const_float(0.0, mir_float());
    inf = b.const_float(float("inf"), mir_float());
    ac = b.binary("mul", ar, br);
    bd = b.binary("mul", ai, bi);
    ad = b.binary("mul", ar, bi);
    bc = b.binary("mul", ai, br);
    rr = b.binary("sub", ac, bd);
    ri = b.binary("add", ad, bc);
    both_nan = b.binary("and", self.f_isnan(rr), self.f_isnan(ri));
    a_inf = self.f_isinf(ar);
    b_inf = self.f_isinf(ai);
    z_inf = b.binary("or", a_inf, b_inf);
    a1 = b.select(z_inf, self.f_copysign(b.select(a_inf, one, zero), ar), ar);
    b1 = b.select(z_inf, self.f_copysign(b.select(b_inf, one, zero), ai), ai);
    c1 = self.f_unnan(z_inf, br);
    d1 = self.f_unnan(z_inf, bi);
    c_inf = self.f_isinf(c1);
    d_inf = self.f_isinf(d1);
    w_inf = b.binary("or", c_inf, d_inf);
    c2 = b.select(w_inf, self.f_copysign(b.select(c_inf, one, zero), c1), c1);
    d2 = b.select(w_inf, self.f_copysign(b.select(d_inf, one, zero), d1), d1);
    a2 = self.f_unnan(w_inf, a1);
    b2 = self.f_unnan(w_inf, b1);
    boxed = b.binary("or", z_inf, w_inf);
    prod_inf = b.binary(
        "or",
        b.binary("or", self.f_isinf(ac), self.f_isinf(bd)),
        b.binary("or", self.f_isinf(ad), self.f_isinf(bc))
    );
    ovf = b.binary("and", b.logical_not(boxed), prod_inf);
    a3 = self.f_unnan(ovf, a2);
    b3 = self.f_unnan(ovf, b2);
    c3 = self.f_unnan(ovf, c2);
    d3 = self.f_unnan(ovf, d2);
    recalc = b.binary("and", both_nan, b.binary("or", boxed, ovf));
    rec_r = b.binary(
        "mul", inf, b.binary("sub", b.binary("mul", a3, c3), b.binary("mul", b3, d3))
    );
    rec_i = b.binary(
        "mul", inf, b.binary("add", b.binary("mul", a3, d3), b.binary("mul", b3, c3))
    );
    return (b.select(recalc, rec_r, rr), b.select(recalc, rec_i, ri));
}

impl MirLowering.complex_quot(
    ar: MirValue, ai: MirValue, br: MirValue, bi: MirValue, real: bool
) -> tuple[MirValue, MirValue] {
    b = self.builder();
    fn = self.st().fn;
    f64 = mir_float();
    zero = b.const_float(0.0, f64);
    inf = b.const_float(float("inf"), f64);
    res_r = self.temp_slot(f64);
    res_i = self.temp_slot(f64);
    abs_br = self.f_abs(br);
    abs_bi = self.f_abs(bi);
    re_bb = fn.new_block("cq.re");
    re_zero_bb = fn.new_block("cq.re.zero");
    re_div_bb = fn.new_block("cq.re.div");
    chk_im_bb = fn.new_block("cq.chk.im");
    im_bb = fn.new_block("cq.im");
    nan_bb = fn.new_block("cq.nan");
    post_bb = fn.new_block("cq.post");
    rec_bb = fn.new_block("cq.rec");
    rec_a_bb = fn.new_block("cq.rec.a");
    rec_chk_b_bb = fn.new_block("cq.rec.chkb");
    rec_b_bb = fn.new_block("cq.rec.b");
    done_bb = fn.new_block("cq.done");
    b.cond_branch(b.compare("ge", abs_br, abs_bi), re_bb, chk_im_bb);

    b.position(re_bb);
    b.cond_branch(b.compare("eq", abs_br, zero), re_zero_bb, re_div_bb);
    b.position(re_zero_bb);
    b.store(res_r, zero);
    b.store(res_i, zero);
    b.branch(post_bb);
    b.position(re_div_bb);
    ratio = b.binary("div", bi, br);
    denom = b.binary("add", b.binary("mul", bi, ratio), br);
    if real {
        b.store(res_r, b.binary("div", ar, denom));
        b.store(res_i, b.binary("div", b.binary("mul", b.negate(ar), ratio), denom));
    } else {
        b.store(
            res_r,
            b.binary("div", b.binary("add", b.binary("mul", ai, ratio), ar), denom)
        );
        b.store(
            res_i,
            b.binary("div", b.binary("sub", ai, b.binary("mul", ar, ratio)), denom)
        );
    }
    b.branch(post_bb);

    b.position(chk_im_bb);
    b.cond_branch(b.compare("ge", abs_bi, abs_br), im_bb, nan_bb);
    b.position(im_bb);
    ratio2 = b.binary("div", br, bi);
    denom2 = b.binary("add", b.binary("mul", br, ratio2), bi);
    if real {
        b.store(res_r, b.binary("div", b.binary("mul", ar, ratio2), denom2));
        b.store(res_i, b.binary("div", b.negate(ar), denom2));
    } else {
        b.store(
            res_r,
            b.binary("div", b.binary("add", b.binary("mul", ar, ratio2), ai), denom2)
        );
        b.store(
            res_i,
            b.binary("div", b.binary("sub", b.binary("mul", ai, ratio2), ar), denom2)
        );
    }
    b.branch(post_bb);

    b.position(nan_bb);
    b.store(res_r, b.const_float(float("nan"), f64));
    b.store(res_i, b.const_float(float("nan"), f64));
    b.branch(post_bb);

    b.position(post_bb);
    cur_r = b.load(res_r, f64);
    cur_i = b.load(res_i, f64);
    nan_pair = b.binary("and", self.f_isnan(cur_r), self.f_isnan(cur_i));
    b.cond_branch(nan_pair, rec_bb, done_bb);

    b.position(rec_bb);
    if real {
        b.branch(rec_chk_b_bb);
    } else {
        a_inf = b.binary("or", self.f_isinf(ar), self.f_isinf(ai));
        b_fin = b.binary("and", self.f_isfinite(br), self.f_isfinite(bi));
        b.cond_branch(b.binary("and", a_inf, b_fin), rec_a_bb, rec_chk_b_bb);
    }
    b.position(rec_a_bb);
    if real {
        b.branch(done_bb);
    } else {
        box_ax = self.f_box(ar);
        box_ay = self.f_box(ai);
        b.store(
            res_r,
            b.binary(
                "mul",
                inf,
                b.binary(
                    "add", b.binary("mul", box_ax, br), b.binary("mul", box_ay, bi)
                )
            )
        );
        b.store(
            res_i,
            b.binary(
                "mul",
                inf,
                b.binary(
                    "sub", b.binary("mul", box_ay, br), b.binary("mul", box_ax, bi)
                )
            )
        );
        b.branch(done_bb);
    }

    b.position(rec_chk_b_bb);
    b_inf = b.binary("or", self.f_isinf(abs_br), self.f_isinf(abs_bi));
    a_fin = b.binary("and", self.f_isfinite(ar), self.f_isfinite(ai));
    b.cond_branch(b.binary("and", b_inf, a_fin), rec_b_bb, done_bb);
    b.position(rec_b_bb);
    box_x = self.f_box(br);
    box_y = self.f_box(bi);
    if real {
        b.store(res_r, b.binary("mul", zero, b.binary("mul", ar, box_x)));
        b.store(res_i, b.binary("mul", zero, b.binary("mul", b.negate(ar), box_y)));
        b.branch(done_bb);
        b.position(done_bb);
        return (b.load(res_r, f64), b.load(res_i, f64));
    }
    b.store(
        res_r,
        b.binary(
            "mul",
            zero,
            b.binary("add", b.binary("mul", ar, box_x), b.binary("mul", ai, box_y))
        )
    );
    b.store(
        res_i,
        b.binary(
            "mul",
            zero,
            b.binary("sub", b.binary("mul", ai, box_x), b.binary("mul", ar, box_y))
        )
    );
    b.branch(done_bb);

    b.position(done_bb);
    return (b.load(res_r, f64), b.load(res_i, f64));
}

impl MirLowering.complex_arith(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    for side in (left, right) {
        if side.type.kind != MirKind.COMPLEX and not side.type.is_numeric() {
            raise MirRefused(
                mir_refusal("binary operator", f"{op} on {side.type.render()}", site)
            );
        }
    }
    zero = b.const_float(0.0, mir_float());
    left_complex = left.type.kind == MirKind.COMPLEX;
    right_complex = right.type.kind == MirKind.COMPLEX;
    (ar, ai) = self.complex_parts(left);
    (br, bi) = self.complex_parts(right);
    if op == Tok.PLUS {
        if not right_complex {
            return self.complex_make(b.binary("add", ar, br), ai);
        }
        if not left_complex {
            return self.complex_make(b.binary("add", br, ar), bi);
        }
        return self.complex_make(b.binary("add", ar, br), b.binary("add", ai, bi));
    }
    if op == Tok.MINUS {
        if not right_complex {
            return self.complex_make(b.binary("sub", ar, br), ai);
        }
        if not left_complex {
            return self.complex_make(b.binary("sub", ar, br), b.negate(bi));
        }
        return self.complex_make(b.binary("sub", ar, br), b.binary("sub", ai, bi));
    }
    if op == Tok.STAR_MUL {
        if not right_complex {
            return self.complex_make(b.binary("mul", ar, br), b.binary("mul", ai, br));
        }
        if not left_complex {
            return self.complex_make(b.binary("mul", br, ar), b.binary("mul", bi, ar));
        }
        (pr, pi) = self.complex_prod(ar, ai, br, bi);
        return self.complex_make(pr, pi);
    }
    if op == Tok.DIV {
        if not right_complex {
            self.raise_if(
                b.compare("eq", br, zero), "ZeroDivisionError", "division by zero"
            );
            return self.complex_make(b.binary("div", ar, br), b.binary("div", ai, br));
        }
        self.raise_if(
            b.binary("and", b.compare("eq", br, zero), b.compare("eq", bi, zero)),
            "ZeroDivisionError",
            "division by zero"
        );
        (qr, qi) = self.complex_quot(ar, ai, br, bi, not left_complex);
        return self.complex_make(qr, qi);
    }
    if op == Tok.STAR_POW {
        return self.complex_pow(ar, ai, br, bi);
    }
    raise MirRefused(
        mir_refusal(
            "binary operator",
            f"{OPERATOR_SYMBOLS.get(op, op)} on complex",
            site,
            "Native complex numbers support +, -, *, / and **."
        )
    );
}

impl MirLowering.libm(name: str, args: list[MirValue]) -> MirValue {
    f64 = mir_float();
    if name not in self.mir.externs {
        self.mir.externs[name] = MirExtern(
            symbol=name, ret=f64, params=[f64 for _ in args], c_abi=True
        );
    }
    made = self.builder().call(name, args, f64);
    if made is None {
        raise MirRefused(mir_refusal("call", name));
    }
    return made;
}

impl MirLowering.complex_pow(
    ar: MirValue, ai: MirValue, br: MirValue, bi: MirValue
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    f64 = mir_float();
    zero = b.const_float(0.0, f64);
    one = b.const_float(1.0, f64);
    res_r = self.temp_slot(f64);
    res_i = self.temp_slot(f64);
    acc_r = self.temp_slot(f64);
    acc_i = self.temp_slot(f64);
    cur_r = self.temp_slot(f64);
    cur_i = self.temp_slot(f64);
    mask = self.temp_slot(mir_int());
    int_bb = fn.new_block("cp.int");
    loop_bb = fn.new_block("cp.loop");
    body_bb = fn.new_block("cp.body");
    mul_bb = fn.new_block("cp.mul");
    sq_bb = fn.new_block("cp.sq");
    after_bb = fn.new_block("cp.after");
    inv_bb = fn.new_block("cp.inv");
    keep_bb = fn.new_block("cp.keep");
    gen_bb = fn.new_block("cp.gen");
    one_bb = fn.new_block("cp.one");
    gen2_bb = fn.new_block("cp.gen2");
    azero_bb = fn.new_block("cp.azero");
    calc_bb = fn.new_block("cp.calc");
    chk_bb = fn.new_block("cp.chk");
    done_bb = fn.new_block("cp.done");
    whole = b.binary(
        "and",
        b.compare("eq", bi, zero),
        b.binary(
            "and",
            b.compare("eq", br, self.libm("floor", [br])),
            b.compare("le", self.f_abs(br), b.const_float(100.0, f64))
        )
    );
    b.cond_branch(whole, int_bb, gen_bb);

    b.position(int_bb);
    n = b.convert(br, mir_int());
    negative = b.compare("lt", n, b.const_int(0, mir_int()));
    m = b.select(negative, b.binary("sub", b.const_int(0, mir_int()), n), n);
    b.store(acc_r, one);
    b.store(acc_i, zero);
    b.store(cur_r, ar);
    b.store(cur_i, ai);
    b.store(mask, b.const_int(1, mir_int()));
    b.branch(loop_bb);

    b.position(loop_bb);
    b.cond_branch(b.compare("ge", m, b.load(mask, mir_int())), body_bb, after_bb);

    b.position(body_bb);
    b.cond_branch(
        b.compare(
            "ne", b.binary("and", m, b.load(mask, mir_int())), b.const_int(0, mir_int())
        ),
        mul_bb,
        sq_bb
    );

    b.position(mul_bb);
    (mr, mi) = self.complex_prod(
        b.load(acc_r, f64), b.load(acc_i, f64), b.load(cur_r, f64), b.load(cur_i, f64)
    );
    b.store(acc_r, mr);
    b.store(acc_i, mi);
    b.branch(sq_bb);

    b.position(sq_bb);
    b.store(mask, b.binary("shl", b.load(mask, mir_int()), b.const_int(1, mir_int())));
    c_r = b.load(cur_r, f64);
    c_i = b.load(cur_i, f64);
    (sr, si) = self.complex_prod(c_r, c_i, c_r, c_i);
    b.store(cur_r, sr);
    b.store(cur_i, si);
    b.branch(loop_bb);

    b.position(after_bb);
    b.cond_branch(negative, inv_bb, keep_bb);

    b.position(inv_bb);
    pw_r = b.load(acc_r, f64);
    pw_i = b.load(acc_i, f64);
    self.raise_if(
        b.binary("and", b.compare("eq", pw_r, zero), b.compare("eq", pw_i, zero)),
        "ZeroDivisionError",
        "zero to a negative or complex power"
    );
    (qr, qi) = self.complex_quot(one, zero, pw_r, pw_i, False);
    b.store(res_r, qr);
    b.store(res_i, qi);
    b.branch(chk_bb);

    b.position(keep_bb);
    b.store(res_r, b.load(acc_r, f64));
    b.store(res_i, b.load(acc_i, f64));
    b.branch(chk_bb);

    b.position(gen_bb);
    b.cond_branch(
        b.binary("and", b.compare("eq", br, zero), b.compare("eq", bi, zero)),
        one_bb,
        gen2_bb
    );

    b.position(one_bb);
    b.store(res_r, one);
    b.store(res_i, zero);
    b.branch(done_bb);

    b.position(gen2_bb);
    b.cond_branch(
        b.binary("and", b.compare("eq", ar, zero), b.compare("eq", ai, zero)),
        azero_bb,
        calc_bb
    );

    b.position(azero_bb);
    self.raise_if(
        b.binary("or", b.compare("ne", bi, zero), b.compare("lt", br, zero)),
        "ZeroDivisionError",
        "zero to a negative or complex power"
    );
    b.store(res_r, zero);
    b.store(res_i, zero);
    b.branch(done_bb);

    b.position(calc_bb);
    vabs = self.libm("hypot", [ar, ai]);
    length = self.libm("pow", [vabs, br]);
    at = self.libm("atan2", [ai, ar]);
    phase = b.binary("mul", at, br);
    imaginary = b.compare("ne", bi, zero);
    scaled = b.binary(
        "mul", length, self.libm("exp", [b.binary("mul", b.negate(at), bi)])
    );
    turned = b.binary("add", phase, b.binary("mul", bi, self.libm("log", [vabs])));
    length = b.select(imaginary, scaled, length);
    phase = b.select(imaginary, turned, phase);
    b.store(res_r, b.binary("mul", length, self.libm("cos", [phase])));
    b.store(res_i, b.binary("mul", length, self.libm("sin", [phase])));
    b.branch(chk_bb);

    b.position(chk_bb);
    self.raise_if(
        b.binary(
            "or", self.f_isinf(b.load(res_r, f64)), self.f_isinf(b.load(res_i, f64))
        ),
        "OverflowError",
        "complex exponentiation"
    );
    b.branch(done_bb);

    b.position(done_bb);
    return self.complex_make(b.load(res_r, f64), b.load(res_i, f64));
}

impl MirLowering.complex_compare(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> (MirValue | None) {
    if MirKind.COMPLEX not in (left.type.kind, right.type.kind) {
        return None;
    }
    if op in (Tok.KW_IS, Tok.KW_ISN, Tok.KW_IN, Tok.KW_NIN) {
        return None;
    }
    if op not in (Tok.EE, Tok.NE) {
        raise MirRefused(
            mir_refusal(
                "comparison",
                f"{OPERATOR_SYMBOLS.get(op, op)} on complex",
                site,
                "Complex numbers are unordered; only == and != compare them."
            )
        );
    }
    for side in (left, right) {
        if side.type.kind != MirKind.COMPLEX and not side.type.is_numeric() {
            return None;
        }
    }
    b = self.builder();
    (ar, ai) = self.complex_parts(left);
    (br, bi) = self.complex_parts(right);
    same = b.binary("and", b.compare("eq", ar, br), b.compare("eq", ai, bi));
    return same if op == Tok.EE else b.logical_not(same);
}

impl MirLowering.complex_truthy(value: MirValue) -> MirValue {
    b = self.builder();
    zero = b.const_float(0.0, mir_float());
    (re, im) = self.complex_parts(value);
    return b.binary("or", b.compare("ne", re, zero), b.compare("ne", im, zero));
}
