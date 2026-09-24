import from jaclang.compiler.backends.native.llvm { ir }

impl NaIRGenPass._emit_utf8_helpers -> None {
    if self.utf8_cplen_fn is not None {
        return;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    if self.str_len_fn is None {
        self._emit_str_len_helpers();
    }
    if self.str_isascii_fn is None {
        self._emit_str_len_helpers();
    }
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);

    cplen_fn = self._define_function(
        "__jac_utf8_cplen", ir.FunctionType(i64, [i8p, i64])
    );
    cplen_fn.linkage = "private";
    cplen_fn.args[0].name = "s";
    cplen_fn.args[1].name = "n";
    _u_entry = cplen_fn.append_basic_block("entry");
    _u_ascii = cplen_fn.append_basic_block("ascii");
    _u_chk = cplen_fn.append_basic_block("chk");
    _u_body = cplen_fn.append_basic_block("body");
    _u_done = cplen_fn.append_basic_block("done");
    b = ir.IRBuilder(_u_entry);
    _u_isa = b.call(
        self.str_isascii_fn, [cplen_fn.args[0], cplen_fn.args[1]], name="u8cp.isa"
    );
    b.cbranch(_u_isa, _u_ascii, _u_chk);
    b = ir.IRBuilder(_u_ascii);
    b.ret(cplen_fn.args[1]);
    b = ir.IRBuilder(_u_chk);
    ui = b.phi(i64, name="u8cp.i");
    ui.add_incoming(zero, _u_entry);
    uc = b.phi(i64, name="u8cp.c");
    uc.add_incoming(zero, _u_entry);
    ugo = b.icmp_unsigned("<", ui, cplen_fn.args[1], name="u8cp.go");
    b.cbranch(ugo, _u_body, _u_done);
    b = ir.IRBuilder(_u_body);
    ub_p = b.gep(cplen_fn.args[0], [ui], name="u8cp.p");
    ub8 = b.load(ub_p, name="u8cp.b");
    ubv = b.zext(ub8, i64, name="u8cp.bv");
    uhi = b.icmp_unsigned(">=", ubv, ir.Constant(i64, 0xC0), name="u8cp.hi");
    ulo = b.icmp_unsigned("<", ubv, ir.Constant(i64, 0x80), name="u8cp.lo");
    ulead = b.or_(uhi, ulo, name="u8cp.lead");
    uc1 = b.select(ulead, b.add(uc, one, name="u8cp.cinc"), uc, name="u8cp.c1");
    ui1 = b.add(ui, one, name="u8cp.i1");
    ui.add_incoming(ui1, _u_body);
    uc.add_incoming(uc1, _u_body);
    b.branch(_u_chk);
    b = ir.IRBuilder(_u_done);
    b.ret(uc);
    self.utf8_cplen_fn = cplen_fn;

    cpoff_fn = self._define_function(
        "__jac_utf8_cp_off", ir.FunctionType(i64, [i8p, i64, i64])
    );
    cpoff_fn.linkage = "private";
    cpoff_fn.args[0].name = "s";
    cpoff_fn.args[1].name = "n";
    cpoff_fn.args[2].name = "k";
    _o_entry = cpoff_fn.append_basic_block("entry");
    _o_ascii = cpoff_fn.append_basic_block("ascii");
    _o_chk = cpoff_fn.append_basic_block("chk");
    _o_body = cpoff_fn.append_basic_block("body");
    _o_found = cpoff_fn.append_basic_block("found");
    _o_cont = cpoff_fn.append_basic_block("cont");
    _o_done = cpoff_fn.append_basic_block("done");
    b = ir.IRBuilder(_o_entry);
    _o_isa = b.call(
        self.str_isascii_fn, [cpoff_fn.args[0], cpoff_fn.args[1]], name="u8of.isa"
    );
    b.cbranch(_o_isa, _o_ascii, _o_chk);
    b = ir.IRBuilder(_o_ascii);
    _o_k = cpoff_fn.args[2];
    _o_clamp = b.select(
        b.icmp_signed("<", _o_k, cpoff_fn.args[1], name="u8of.klt"),
        _o_k,
        cpoff_fn.args[1],
        name="u8of.kmin"
    );
    _o_clamp = b.select(
        b.icmp_signed("<", _o_clamp, zero, name="u8of.kneg"),
        zero,
        _o_clamp,
        name="u8of.kmax"
    );
    b.ret(_o_clamp);
    b = ir.IRBuilder(_o_chk);
    oi = b.phi(i64, name="u8of.i");
    oi.add_incoming(zero, _o_entry);
    ocnt = b.phi(i64, name="u8of.cnt");
    ocnt.add_incoming(zero, _o_entry);
    ogo = b.icmp_unsigned("<", oi, cpoff_fn.args[1], name="u8of.go");
    b.cbranch(ogo, _o_body, _o_done);
    b = ir.IRBuilder(_o_body);
    ob_p = b.gep(cpoff_fn.args[0], [oi], name="u8of.p");
    ob8 = b.load(ob_p, name="u8of.b");
    obv = b.zext(ob8, i64, name="u8of.bv");
    ohi = b.icmp_unsigned(">=", obv, ir.Constant(i64, 0xC0), name="u8of.hi");
    olo = b.icmp_unsigned("<", obv, ir.Constant(i64, 0x80), name="u8of.lo");
    olead = b.or_(ohi, olo, name="u8of.lead");
    oeq = b.icmp_signed("==", ocnt, cpoff_fn.args[2], name="u8of.eq");
    oisk = b.and_(olead, oeq, name="u8of.isk");
    b.cbranch(oisk, _o_found, _o_cont);
    b = ir.IRBuilder(_o_found);
    b.ret(oi);
    b = ir.IRBuilder(_o_cont);
    ocnt1 = b.select(olead, b.add(ocnt, one, name="u8of.cinc"), ocnt, name="u8of.c1");
    oi1 = b.add(oi, one, name="u8of.i1");
    oi.add_incoming(oi1, _o_cont);
    ocnt.add_incoming(ocnt1, _o_cont);
    b.branch(_o_chk);
    b = ir.IRBuilder(_o_done);
    b.ret(cpoff_fn.args[1]);
    self.utf8_cp_off_fn = cpoff_fn;

    cplat_fn = self._define_function(
        "__jac_utf8_cp_len_at", ir.FunctionType(i64, [i8p, i64])
    );
    cplat_fn.linkage = "private";
    cplat_fn.args[0].name = "s";
    cplat_fn.args[1].name = "off";
    _l_entry = cplat_fn.append_basic_block("entry");
    b = ir.IRBuilder(_l_entry);
    lp = b.gep(cplat_fn.args[0], [cplat_fn.args[1]], name="u8la.p");
    lb8 = b.load(lp, name="u8la.b");
    lbv = b.zext(lb8, i64, name="u8la.bv");
    lis1 = b.icmp_unsigned("<", lbv, ir.Constant(i64, 0x80), name="u8la.is1");
    ll12 = b.select(lis1, one, ir.Constant(i64, 2), name="u8la.l12");
    lis3 = b.icmp_unsigned("<", lbv, ir.Constant(i64, 0xF0), name="u8la.is3");
    ll34 = b.select(lis3, ir.Constant(i64, 3), ir.Constant(i64, 4), name="u8la.l34");
    lis2 = b.icmp_unsigned("<", lbv, ir.Constant(i64, 0xE0), name="u8la.is2");
    ll = b.select(lis2, ll12, ll34, name="u8la.len");
    b.ret(ll);
    self.utf8_cp_len_at_fn = cplat_fn;

    cpat_fn = self._define_function(
        "__jac_utf8_cp_at_off", ir.FunctionType(i8p, [i8p, i64])
    );
    cpat_fn.linkage = "private";
    cpat_fn.args[0].name = "s";
    cpat_fn.args[1].name = "off";
    _a_entry = cpat_fn.append_basic_block("entry");
    _a_ascii = cpat_fn.append_basic_block("ascii");
    _a_multi = cpat_fn.append_basic_block("multi");
    _a_cchk = cpat_fn.append_basic_block("cpy.chk");
    _a_cbody = cpat_fn.append_basic_block("cpy.body");
    _a_cdone = cpat_fn.append_basic_block("cpy.done");
    b = ir.IRBuilder(_a_entry);
    acp = b.gep(cpat_fn.args[0], [cpat_fn.args[1]], name="u8at.cp");
    ab8 = b.load(acp, name="u8at.b");
    abv = b.zext(ab8, i64, name="u8at.bv");
    aisc = b.icmp_unsigned("<", abv, ir.Constant(i64, 0x80), name="u8at.ascii");
    b.cbranch(aisc, _a_ascii, _a_multi);
    b = ir.IRBuilder(_a_ascii);
    cache_gv = self._get_char_cache_gv();
    cached = b.gep(
        cache_gv,
        [
            ir.Constant(ir.IntType(32), 0),
            abv,
            ir.Constant(ir.IntType(32), 2),
            ir.Constant(ir.IntType(32), 0)
        ],
        name="u8at.cached"
    );
    b.ret(cached);
    b = ir.IRBuilder(_a_multi);
    ais1 = b.icmp_unsigned("<", abv, ir.Constant(i64, 0x80), name="u8at.is1");
    al12 = b.select(ais1, one, ir.Constant(i64, 2), name="u8at.l12");
    ais3 = b.icmp_unsigned("<", abv, ir.Constant(i64, 0xF0), name="u8at.is3");
    al34 = b.select(ais3, ir.Constant(i64, 3), ir.Constant(i64, 4), name="u8at.l34");
    ais2 = b.icmp_unsigned("<", abv, ir.Constant(i64, 0xE0), name="u8at.is2");
    al = b.select(ais2, al12, al34, name="u8at.len");
    asize = b.add(al, one, name="u8at.size");
    abuf = b.call(self.rc_alloc_fn, [asize], name="u8at.buf");
    self._emit_set_type_tag(b, abuf, "str");
    b.branch(_a_cchk);
    b = ir.IRBuilder(_a_cchk);
    at = b.phi(i64, name="u8at.t");
    at.add_incoming(zero, _a_multi);
    atgo = b.icmp_unsigned("<", at, al, name="u8at.go");
    b.cbranch(atgo, _a_cbody, _a_cdone);
    b = ir.IRBuilder(_a_cbody);
    asp = b.gep(acp, [at], name="u8at.sp");
    av = b.load(asp, name="u8at.v");
    adp = b.gep(abuf, [at], name="u8at.dp");
    b.store(av, adp);
    at1 = b.add(at, one, name="u8at.t1");
    at.add_incoming(at1, _a_cbody);
    b.branch(_a_cchk);
    b = ir.IRBuilder(_a_cdone);
    anul = b.gep(abuf, [al], name="u8at.nul");
    b.store(ir.Constant(i8, 0), anul);
    self._stamp_str_len(b, abuf, al);
    b.ret(abuf);
    self.utf8_cp_at_off_fn = cpat_fn;

    adv_fn = self._define_function(
        "__jac_utf8_advance", ir.FunctionType(i64, [i8p, i64, i64, i64])
    );
    adv_fn.linkage = "private";
    adv_fn.args[0].name = "s";
    adv_fn.args[1].name = "n";
    adv_fn.args[2].name = "off";
    adv_fn.args[3].name = "delta";
    _v_entry = adv_fn.append_basic_block("entry");
    _v_ascii = adv_fn.append_basic_block("ascii");
    _v_loop = adv_fn.append_basic_block("loop");
    _v_work = adv_fn.append_basic_block("work");
    _v_fchk = adv_fn.append_basic_block("fwdchk");
    _v_fwd = adv_fn.append_basic_block("fwd");
    _v_back = adv_fn.append_basic_block("back");
    _v_scan = adv_fn.append_basic_block("scan");
    _v_scanld = adv_fn.append_basic_block("scanld");
    _v_scancont = adv_fn.append_basic_block("scancont");
    _v_backdone = adv_fn.append_basic_block("backdone");
    _v_merge = adv_fn.append_basic_block("merge");
    _v_done = adv_fn.append_basic_block("done");
    b = ir.IRBuilder(_v_entry);
    _v_isa = b.call(
        self.str_isascii_fn, [adv_fn.args[0], adv_fn.args[1]], name="u8adv.isa"
    );
    b.cbranch(_v_isa, _v_ascii, _v_loop);
    b = ir.IRBuilder(_v_ascii);
    _v_sum = b.add(adv_fn.args[2], adv_fn.args[3], name="u8adv.sum");
    _v_fpos = b.icmp_signed(">", adv_fn.args[3], zero, name="u8adv.dpos");
    _v_clamp = b.select(
        b.icmp_signed(">", _v_sum, adv_fn.args[1], name="u8adv.over"),
        adv_fn.args[1],
        _v_sum,
        name="u8adv.clamp"
    );
    b.ret(b.select(_v_fpos, _v_clamp, _v_sum, name="u8adv.res"));
    b = ir.IRBuilder(_v_loop);
    voff = b.phi(i64, name="u8adv.off");
    voff.add_incoming(adv_fn.args[2], _v_entry);
    vrem = b.phi(i64, name="u8adv.rem");
    vrem.add_incoming(adv_fn.args[3], _v_entry);
    vpos = b.icmp_signed(">", vrem, zero, name="u8adv.pos");
    vneg = b.icmp_signed("<", vrem, zero, name="u8adv.neg");
    vmore = b.or_(vpos, vneg, name="u8adv.more");
    b.cbranch(vmore, _v_work, _v_done);
    b = ir.IRBuilder(_v_work);
    b.cbranch(vpos, _v_fchk, _v_back);
    b = ir.IRBuilder(_v_fchk);
    b.cbranch(
        b.icmp_signed("<", voff, adv_fn.args[1], name="u8adv.inb"), _v_fwd, _v_done
    );
    b = ir.IRBuilder(_v_fwd);
    vfl = b.call(self.utf8_cp_len_at_fn, [adv_fn.args[0], voff], name="u8adv.fl");
    voff_f = b.add(voff, vfl, name="u8adv.off.f");
    vrem_f = b.sub(vrem, one, name="u8adv.rem.f");
    b.branch(_v_merge);
    b = ir.IRBuilder(_v_back);
    vob = b.sub(voff, one, name="u8adv.ob");
    b.branch(_v_scan);
    b = ir.IRBuilder(_v_scan);
    vo_p = b.phi(i64, name="u8adv.o");
    vo_p.add_incoming(vob, _v_back);
    vo_inb = b.icmp_signed(">=", vo_p, zero, name="u8adv.inb");
    b.cbranch(vo_inb, _v_scanld, _v_backdone);
    b = ir.IRBuilder(_v_scanld);
    vbp = b.gep(adv_fn.args[0], [vo_p], name="u8adv.bp");
    vbv = b.zext(b.load(vbp, name="u8adv.b"), i64, name="u8adv.bv");
    vcont = b.and_(
        b.icmp_unsigned(">=", vbv, ir.Constant(i64, 0x80), name="u8adv.chi"),
        b.icmp_unsigned("<", vbv, ir.Constant(i64, 0xC0), name="u8adv.clo"),
        name="u8adv.iscont"
    );
    b.cbranch(vcont, _v_scancont, _v_backdone);
    b = ir.IRBuilder(_v_scancont);
    vo_n = b.sub(vo_p, one, name="u8adv.on");
    vo_p.add_incoming(vo_n, _v_scancont);
    b.branch(_v_scan);
    b = ir.IRBuilder(_v_backdone);
    voff_b = vo_p;
    vrem_b = b.add(vrem, one, name="u8adv.rem.b");
    b.branch(_v_merge);
    b = ir.IRBuilder(_v_merge);
    voff_n = b.phi(i64, name="u8adv.off.n");
    voff_n.add_incoming(voff_f, _v_fwd);
    voff_n.add_incoming(voff_b, _v_backdone);
    vrem_n = b.phi(i64, name="u8adv.rem.n");
    vrem_n.add_incoming(vrem_f, _v_fwd);
    vrem_n.add_incoming(vrem_b, _v_backdone);
    voff.add_incoming(voff_n, _v_merge);
    vrem.add_incoming(vrem_n, _v_merge);
    b.branch(_v_loop);
    b = ir.IRBuilder(_v_done);
    b.ret(voff);
    self.utf8_advance_fn = adv_fn;
}

impl NaIRGenPass._call_utf8_cplen(
    b: ir.IRBuilder, ptr: ir.Value, nbytes: ir.Value, name: str = "u8.cplen"
) -> ir.Value {
    self._emit_utf8_helpers();
    nbytes = self._coerce_type(nbytes, ir.IntType(64));
    return b.call(self.utf8_cplen_fn, [ptr, nbytes], name=name);
}

impl NaIRGenPass._call_utf8_cp_off(
    b: ir.IRBuilder,
    ptr: ir.Value,
    nbytes: ir.Value,
    cp_index: ir.Value,
    name: str = "u8.cpoff"
) -> ir.Value {
    self._emit_utf8_helpers();
    nbytes = self._coerce_type(nbytes, ir.IntType(64));
    cp_index = self._coerce_type(cp_index, ir.IntType(64));
    return b.call(self.utf8_cp_off_fn, [ptr, nbytes, cp_index], name=name);
}

impl NaIRGenPass._call_utf8_cp_len_at(
    b: ir.IRBuilder, ptr: ir.Value, off: ir.Value, name: str = "u8.cplenat"
) -> ir.Value {
    self._emit_utf8_helpers();
    off = self._coerce_type(off, ir.IntType(64));
    return b.call(self.utf8_cp_len_at_fn, [ptr, off], name=name);
}

impl NaIRGenPass._call_utf8_cp_at_off(
    b: ir.IRBuilder, ptr: ir.Value, off: ir.Value, name: str = "u8.cpat"
) -> ir.Value {
    self._emit_utf8_helpers();
    off = self._coerce_type(off, ir.IntType(64));
    return b.call(self.utf8_cp_at_off_fn, [ptr, off], name=name);
}

impl NaIRGenPass._call_utf8_advance(
    b: ir.IRBuilder,
    ptr: ir.Value,
    nbytes: ir.Value,
    off: ir.Value,
    delta: ir.Value,
    name: str = "u8.adv"
) -> ir.Value {
    self._emit_utf8_helpers();
    nbytes = self._coerce_type(nbytes, ir.IntType(64));
    off = self._coerce_type(off, ir.IntType(64));
    delta = self._coerce_type(delta, ir.IntType(64));
    return b.call(self.utf8_advance_fn, [ptr, nbytes, off, delta], name=name);
}
