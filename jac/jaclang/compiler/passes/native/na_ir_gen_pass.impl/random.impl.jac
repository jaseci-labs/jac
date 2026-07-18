glob _MT_N: int = 624,
     _MT_M: int = 397,
     _MT_MATRIX_A: int = 0x9908B0DF,
     _MT_UPPER: int = 0x80000000,
     _MT_LOWER: int = 0x7FFFFFFF;

impl NaIRGenPass._mt_ensure -> None {
    if "mt19937" in self._stdlib_helpers_emitted {
        return;
    }
    self._stdlib_helpers_emitted.add("mt19937");
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    void = ir.VoidType();
    arr_ty = ir.ArrayType(i32, _MT_N);

    mt = ir.GlobalVariable(self.llvm_module, arr_ty, name="__mt_state");
    mt.linkage = "internal";
    mt.global_constant = False;
    mt.initializer = ir.Constant(arr_ty, None);
    idx = ir.GlobalVariable(self.llvm_module, i32, name="__mt_index");
    idx.linkage = "internal";
    idx.global_constant = False;
    idx.initializer = ir.Constant(i32, _MT_N + 1);

    def elem(b: any, k: any) -> any {
        return b.gep(mt, [ir.Constant(i32, 0), k]);
    }

    f_init = ir.Function(
        self.llvm_module, ir.FunctionType(void, [i32]), "__mt_init_genrand"
    );
    b = ir.IRBuilder(f_init.append_basic_block("e"));
    s = f_init.args[0];
    b.store(s, elem(b, ir.Constant(i32, 0)));
    ip = b.alloca(i32, name="i");
    b.store(ir.Constant(i32, 1), ip);
    cond = f_init.append_basic_block("c");
    body = f_init.append_basic_block("b");
    done = f_init.append_basic_block("d");
    b.branch(cond);
    b.position_at_end(cond);
    i = b.load(ip);
    b.cbranch(b.icmp_unsigned("<", i, ir.Constant(i32, _MT_N)), body, done);
    b.position_at_end(body);
    i = b.load(ip);
    im1 = b.sub(i, ir.Constant(i32, 1));
    prev = b.load(elem(b, im1));
    x = b.xor(prev, b.lshr(prev, ir.Constant(i32, 30)));
    v = b.add(b.mul(ir.Constant(i32, 1812433253), x), i);
    b.store(v, elem(b, i));
    b.store(b.add(i, ir.Constant(i32, 1)), ip);
    b.branch(cond);
    b.position_at_end(done);
    b.store(ir.Constant(i32, _MT_N), idx);
    b.ret_void();

    f_iba = ir.Function(
        self.llvm_module,
        ir.FunctionType(void, [i32.as_pointer(), i32]),
        "__mt_init_by_array"
    );
    b = ir.IRBuilder(f_iba.append_basic_block("e"));
    key = f_iba.args[0];
    keylen = f_iba.args[1];
    b.call(f_init, [ir.Constant(i32, 19650218)]);
    ip = b.alloca(i32, name="i");
    jp = b.alloca(i32, name="j");
    kp = b.alloca(i32, name="k");
    b.store(ir.Constant(i32, 1), ip);
    b.store(ir.Constant(i32, 0), jp);

    klen_gt = b.icmp_unsigned(">", keylen, ir.Constant(i32, _MT_N));
    b.store(b.select(klen_gt, keylen, ir.Constant(i32, _MT_N)), kp);

    c1 = f_iba.append_basic_block("c1");
    b1 = f_iba.append_basic_block("b1");
    c2 = f_iba.append_basic_block("c2");
    b2 = f_iba.append_basic_block("b2");
    fin = f_iba.append_basic_block("fin");
    b.branch(c1);
    b.position_at_end(c1);
    kv = b.load(kp);
    b.cbranch(b.icmp_unsigned("!=", kv, ir.Constant(i32, 0)), b1, c2);
    b.position_at_end(b1);
    i = b.load(ip);
    j = b.load(jp);
    im1 = b.sub(i, ir.Constant(i32, 1));
    mi = b.load(elem(b, i));
    mim1 = b.load(elem(b, im1));
    t = b.xor(mim1, b.lshr(mim1, ir.Constant(i32, 30)));
    t = b.mul(t, ir.Constant(i32, 1664525));
    nv = b.add(b.add(b.xor(mi, t), b.load(b.gep(key, [j]))), j);
    b.store(nv, elem(b, i));
    i = b.add(i, ir.Constant(i32, 1));
    j = b.add(j, ir.Constant(i32, 1));

    ige = b.icmp_unsigned(">=", i, ir.Constant(i32, _MT_N));
    w1t = f_iba.append_basic_block("w1t");
    w1c = f_iba.append_basic_block("w1c");
    b.cbranch(ige, w1t, w1c);
    b.position_at_end(w1t);
    b.store(b.load(elem(b, ir.Constant(i32, _MT_N - 1))), elem(b, ir.Constant(i32, 0)));
    b.branch(w1c);
    b.position_at_end(w1c);
    i = b.select(ige, ir.Constant(i32, 1), i);

    jge = b.icmp_unsigned(">=", j, keylen);
    j = b.select(jge, ir.Constant(i32, 0), j);
    b.store(i, ip);
    b.store(j, jp);
    b.store(b.sub(b.load(kp), ir.Constant(i32, 1)), kp);
    b.branch(c1);

    b.position_at_end(c2);
    b.store(ir.Constant(i32, _MT_N - 1), kp);
    c2b = f_iba.append_basic_block("c2b");
    b.branch(c2b);
    b.position_at_end(c2b);
    kv = b.load(kp);
    b.cbranch(b.icmp_unsigned("!=", kv, ir.Constant(i32, 0)), b2, fin);
    b.position_at_end(b2);
    i = b.load(ip);
    im1 = b.sub(i, ir.Constant(i32, 1));
    mi = b.load(elem(b, i));
    mim1 = b.load(elem(b, im1));
    t = b.xor(mim1, b.lshr(mim1, ir.Constant(i32, 30)));
    t = b.mul(t, ir.Constant(i32, 1566083941));
    nv = b.sub(b.xor(mi, t), i);
    b.store(nv, elem(b, i));
    i = b.add(i, ir.Constant(i32, 1));
    ige = b.icmp_unsigned(">=", i, ir.Constant(i32, _MT_N));
    w2t = f_iba.append_basic_block("w2t");
    w2c = f_iba.append_basic_block("w2c");
    b.cbranch(ige, w2t, w2c);
    b.position_at_end(w2t);
    b.store(b.load(elem(b, ir.Constant(i32, _MT_N - 1))), elem(b, ir.Constant(i32, 0)));
    b.branch(w2c);
    b.position_at_end(w2c);
    i = b.select(ige, ir.Constant(i32, 1), i);
    b.store(i, ip);
    b.store(b.sub(b.load(kp), ir.Constant(i32, 1)), kp);
    b.branch(c2b);
    b.position_at_end(fin);
    b.store(ir.Constant(i32, _MT_UPPER), elem(b, ir.Constant(i32, 0)));
    b.store(ir.Constant(i32, _MT_N), idx);
    b.ret_void();

    f_gen = ir.Function(self.llvm_module, ir.FunctionType(i32, []), "__mt_genrand_u32");
    b = ir.IRBuilder(f_gen.append_basic_block("e"));
    need = b.icmp_unsigned(">=", b.load(idx), ir.Constant(i32, _MT_N));
    regen = f_gen.append_basic_block("regen");
    after = f_gen.append_basic_block("after");
    b.cbranch(need, regen, after);
    b.position_at_end(regen);
    kp = b.alloca(i32, name="k");
    b.store(ir.Constant(i32, 0), kp);
    gc = f_gen.append_basic_block("gc");
    gb = f_gen.append_basic_block("gb");
    gd = f_gen.append_basic_block("gd");
    b.branch(gc);
    b.position_at_end(gc);
    k = b.load(kp);
    b.cbranch(b.icmp_unsigned("<", k, ir.Constant(i32, _MT_N)), gb, gd);
    b.position_at_end(gb);
    k = b.load(kp);

    kp1 = b.urem(b.add(k, ir.Constant(i32, 1)), ir.Constant(i32, _MT_N));
    hi = b.and_(b.load(elem(b, k)), ir.Constant(i32, _MT_UPPER));
    lo = b.and_(b.load(elem(b, kp1)), ir.Constant(i32, _MT_LOWER));
    y = b.or_(hi, lo);

    kpm = b.urem(b.add(k, ir.Constant(i32, _MT_M)), ir.Constant(i32, _MT_N));
    nxt = b.xor(b.load(elem(b, kpm)), b.lshr(y, ir.Constant(i32, 1)));

    odd = b.icmp_unsigned("!=", b.and_(y, ir.Constant(i32, 1)), ir.Constant(i32, 0));
    nxt = b.select(odd, b.xor(nxt, ir.Constant(i32, _MT_MATRIX_A)), nxt);
    b.store(nxt, elem(b, k));
    b.store(b.add(k, ir.Constant(i32, 1)), kp);
    b.branch(gc);
    b.position_at_end(gd);
    b.store(ir.Constant(i32, 0), idx);
    b.branch(after);
    b.position_at_end(after);
    cur = b.load(idx);
    y = b.load(elem(b, cur));
    b.store(b.add(cur, ir.Constant(i32, 1)), idx);

    y = b.xor(y, b.lshr(y, ir.Constant(i32, 11)));
    y = b.xor(y, b.and_(b.shl(y, ir.Constant(i32, 7)), ir.Constant(i32, 0x9D2C5680)));
    y = b.xor(y, b.and_(b.shl(y, ir.Constant(i32, 15)), ir.Constant(i32, 0xEFC60000)));
    y = b.xor(y, b.lshr(y, ir.Constant(i32, 18)));
    b.ret(y);

    f_grb = ir.Function(
        self.llvm_module, ir.FunctionType(i64, [i32]), "__mt_getrandbits"
    );
    b = ir.IRBuilder(f_grb.append_basic_block("e"));
    kk = f_grb.args[0];
    resp = b.alloca(i64, name="res");
    shp = b.alloca(i32, name="sh");
    krem = b.alloca(i32, name="kr");
    b.store(ir.Constant(i64, 0), resp);
    b.store(ir.Constant(i32, 0), shp);
    b.store(kk, krem);
    wc = f_grb.append_basic_block("wc");
    wb = f_grb.append_basic_block("wb");
    wd = f_grb.append_basic_block("wd");
    b.branch(wc);
    b.position_at_end(wc);
    b.cbranch(b.icmp_unsigned(">", b.load(krem), ir.Constant(i32, 0)), wb, wd);
    b.position_at_end(wb);
    r = b.call(f_gen, []);
    kcur = b.load(krem);
    lt32 = b.icmp_unsigned("<", kcur, ir.Constant(i32, 32));

    shifted = b.lshr(r, b.sub(ir.Constant(i32, 32), kcur));
    r = b.select(lt32, shifted, r);
    r64 = b.zext(r, i64);
    contrib = b.shl(r64, b.zext(b.load(shp), i64));
    b.store(b.or_(b.load(resp), contrib), resp);
    b.store(b.add(b.load(shp), ir.Constant(i32, 32)), shp);

    kle = b.icmp_unsigned("<=", kcur, ir.Constant(i32, 32));
    b.store(
        b.select(kle, ir.Constant(i32, 0), b.sub(kcur, ir.Constant(i32, 32))), krem
    );
    b.branch(wc);
    b.position_at_end(wd);
    b.ret(b.load(resp));

    f_rb = ir.Function(self.llvm_module, ir.FunctionType(i64, [i64]), "__mt_randbelow");
    b = ir.IRBuilder(f_rb.append_basic_block("e"));
    n = f_rb.args[0];

    zero = f_rb.append_basic_block("zero");
    work = f_rb.append_basic_block("work");
    b.cbranch(b.icmp_unsigned("==", n, ir.Constant(i64, 0)), zero, work);
    b.position_at_end(zero);
    b.ret(ir.Constant(i64, 0));
    b.position_at_end(work);

    blp = b.alloca(i32, name="bl");
    tmpp = b.alloca(i64, name="tmp");
    b.store(ir.Constant(i32, 0), blp);
    b.store(n, tmpp);
    blc = f_rb.append_basic_block("blc");
    blb = f_rb.append_basic_block("blb");
    bld = f_rb.append_basic_block("bld");
    b.branch(blc);
    b.position_at_end(blc);
    b.cbranch(b.icmp_unsigned("!=", b.load(tmpp), ir.Constant(i64, 0)), blb, bld);
    b.position_at_end(blb);
    b.store(b.lshr(b.load(tmpp), ir.Constant(i64, 1)), tmpp);
    b.store(b.add(b.load(blp), ir.Constant(i32, 1)), blp);
    b.branch(blc);
    b.position_at_end(bld);
    kbits = b.load(blp);
    rc = f_rb.append_basic_block("rc");
    rdone = f_rb.append_basic_block("rdone");
    rv = b.alloca(i64, name="r");
    b.store(b.call(f_grb, [kbits]), rv);
    b.branch(rc);
    b.position_at_end(rc);

    ge = b.icmp_unsigned(">=", b.load(rv), n);
    redraw = f_rb.append_basic_block("redraw");
    b.cbranch(ge, redraw, rdone);
    b.position_at_end(redraw);
    b.store(b.call(f_grb, [kbits]), rv);
    b.branch(rc);
    b.position_at_end(rdone);
    b.ret(b.load(rv));
}

impl NaIRGenPass._emit_random_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) {
    self._mt_ensure();
    f64 = ir.DoubleType();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    params = nd.params or [];

    f_gen = self._get_or_declare_extern("__mt_genrand_u32", i32, []);
    f_iba = self._get_or_declare_extern(
        "__mt_init_by_array", ir.VoidType(), [i32.as_pointer(), i32]
    );
    f_grb = self._get_or_declare_extern("__mt_getrandbits", i64, [i32]);
    f_rb = self._get_or_declare_extern("__mt_randbelow", i64, [i64]);

    if name == "seed" and params {
        sv = self._codegen_expr(params[0]);
        if sv is None {
            return None;
        }
        sv = self._coerce_type(sv, i64);

        isneg = self.builder.icmp_signed("<", sv, ir.Constant(i64, 0));
        absv = self.builder.select(
            isneg, self.builder.sub(ir.Constant(i64, 0), sv), sv
        );
        low = self.builder.trunc(absv, i32);
        high = self.builder.trunc(self.builder.lshr(absv, ir.Constant(i64, 32)), i32);
        keybuf = self.builder.alloca(ir.ArrayType(i32, 2), name="seed.key");
        p0 = self.builder.gep(keybuf, [ir.Constant(i32, 0), ir.Constant(i32, 0)]);
        p1 = self.builder.gep(keybuf, [ir.Constant(i32, 0), ir.Constant(i32, 1)]);
        self.builder.store(low, p0);
        self.builder.store(high, p1);
        has_high = self.builder.icmp_unsigned("!=", high, ir.Constant(i32, 0));
        keylen = self.builder.select(
            has_high, ir.Constant(i32, 2), ir.Constant(i32, 1)
        );
        self.builder.call(f_iba, [p0, keylen]);
        return None;
    }

    if name == "random" {
        a = self.builder.lshr(self.builder.call(f_gen, []), ir.Constant(i32, 5));
        bb = self.builder.lshr(self.builder.call(f_gen, []), ir.Constant(i32, 6));
        a_f = self.builder.uitofp(self.builder.zext(a, i64), f64);
        b_f = self.builder.uitofp(self.builder.zext(bb, i64), f64);
        num = self.builder.fadd(
            self.builder.fmul(a_f, ir.Constant(f64, 67108864.0)), b_f
        );
        return self.builder.fmul(num, ir.Constant(f64, 1.0 / 9007199254740992.0));
    }

    if name == "getrandbits" and params {
        kv = self._codegen_expr(params[0]);
        if kv is None {
            return None;
        }
        return self.builder.call(f_grb, [self._coerce_type(kv, i32)]);
    }

    if name == "uniform" and len(params) >= 2 {
        av = self._coerce_type(self._codegen_expr(params[0]), f64);
        bv = self._coerce_type(self._codegen_expr(params[1]), f64);
        a2 = self.builder.lshr(self.builder.call(f_gen, []), ir.Constant(i32, 5));
        b2 = self.builder.lshr(self.builder.call(f_gen, []), ir.Constant(i32, 6));
        a_f = self.builder.uitofp(self.builder.zext(a2, i64), f64);
        b_f = self.builder.uitofp(self.builder.zext(b2, i64), f64);
        rnum = self.builder.fmul(
            self.builder.fadd(
                self.builder.fmul(a_f, ir.Constant(f64, 67108864.0)), b_f
            ),
            ir.Constant(f64, 1.0 / 9007199254740992.0)
        );
        span = self.builder.fsub(bv, av);
        return self.builder.fadd(av, self.builder.fmul(span, rnum));
    }

    if name == "randint" and len(params) >= 2 {
        av = self._coerce_type(self._codegen_expr(params[0]), i64);
        bv = self._coerce_type(self._codegen_expr(params[1]), i64);
        width = self.builder.add(self.builder.sub(bv, av), ir.Constant(i64, 1));
        return self.builder.add(av, self.builder.call(f_rb, [width]));
    }

    if name == "randrange" and params {
        if len(params) == 1 {
            stop = self._coerce_type(self._codegen_expr(params[0]), i64);
            return self.builder.call(f_rb, [stop]);
        }
        start = self._coerce_type(self._codegen_expr(params[0]), i64);
        stop = self._coerce_type(self._codegen_expr(params[1]), i64);
        return self.builder.add(
            start, self.builder.call(f_rb, [self.builder.sub(stop, start)])
        );
    }

    return None;
}
