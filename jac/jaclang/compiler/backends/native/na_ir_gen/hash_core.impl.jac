glob HASH_CTRL_EMPTY: int = 0,
     HASH_CTRL_TOMBSTONE: int = 1,
     HASH_INIT_CAP: int = 8,
     HASH_FNV_BASIS: int = -3750763034362895579,
     HASH_FNV_PRIME: int = 1099511628211,
     HASH_MUL_K: int = -7046029254386353131;

impl NaIRGenHashCore._emit_hash_core_helpers(
    family: str,
    type_key: str,
    cont_ptr_type: ir.Type,
    key_type: ir.Type,
    val_type: (ir.Type | None),
    key_type_name: str,
    key_size: int,
    layout: dict
) -> dict {
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    i8p: any = i8.as_pointer();
    _safe = type_key.replace(":", "_");
    _pre = f"__{family}";
    has_vals: bool = val_type is not None;
    _vt: ir.Type = val_type if val_type is not None else i64;
    _vt_dyn: any = val_type;
    is_str_key: bool = key_type == i8p;
    is_bytes_key: bool = key_type_name == "bytes";
    _key_sz: int = int(key_size);
    if _key_sz == 0 and isinstance(key_type, ir.PointerType) {
        _pointee = key_type?.pointee;
        if _pointee is not None and isinstance(_pointee, ir.LiteralStructType) {
            _key_sz = self._get_struct_size(_pointee);
        }
    }
    LEN_F = 0;
    CAP_F = 1;
    KEYS_F = layout["data_fields"][0][0];
    VALS_F = layout["data_fields"][1][0] if has_vals else -1;
    CTRL_F = layout["ctrl_idx"];
    USED_F = layout["used_idx"];
    ORDER_F = layout["order_idx"];

    malloc_fn = self._get_or_declare_extern("malloc", i8p, [i64]);
    calloc_fn = self._get_or_declare_extern("calloc", i8p, [i64, i64]);
    if self.rc_safe_free_fn is None or self.rc_retain_fn is None {
        self._emit_rc_helpers();
    }
    _hl = self._nogc_headerless();
    _free_hl = self._get_or_declare_extern("free", ir.VoidType(), [i8p])
        if _hl
        else None;

    hash_fnty = ir.FunctionType(i64, [key_type]);
    hash_fn: any = ir.Function(
        self.llvm_module, hash_fnty, name=f"{_pre}_hash_{_safe}"
    );
    hash_fn.linkage = "private";
    hash_fn.args[0].name = "key";
    bhe = ir.IRBuilder(hash_fn.append_basic_block("entry"));
    _tkf = self._tuple_key_fields(key_type)
        if (_key_sz > 0 and not is_bytes_key and not is_str_key)
        else None;
    if _tkf is not None {
        _hv: ir.Value = ir.Constant(i64, HASH_FNV_BASIS);
        for (_fi, _fk) in _tkf {
            _fv = self._tuple_key_field_val(bhe, hash_fn.args[0], _fi, _fk);
            if _fk == "str" or _fk == "jacstr" {
                _fh = bhe.call(self._str_fnv_fn(), [_fv], name=f"tk.sh{_fi}");
            } elif _fk == "f64" {
                _fh = bhe.bitcast(_fv, i64, name=f"tk.fb{_fi}");
            } elif _fk == "ptr" {
                _fh = bhe.ptrtoint(_fv, i64, name=f"tk.pi{_fi}");
            } elif isinstance(_fv.type, ir.IntType) and _fv.type.width == 64 {
                _fh = _fv;
            } else {
                _fh = bhe.zext(_fv, i64, name=f"tk.zx{_fi}");
            }
            _hv = bhe.mul(
                bhe.xor(_hv, _fh, name=f"tk.hx{_fi}"),
                ir.Constant(i64, HASH_FNV_PRIME),
                name=f"tk.hm{_fi}"
            );
        }
        bhe.ret(_hv);
    } elif is_bytes_key or is_str_key or _key_sz > 0 {
        h_a = bhe.alloca(i64, name="h");
        idx_a = bhe.alloca(i64, name="idx");
        bhe.store(ir.Constant(i64, HASH_FNV_BASIS), h_a);
        bhe.store(ir.Constant(i64, 0), idx_a);
        _hdata = None;
        _hlen = None;
        if is_bytes_key {
            _hlen = bhe.load(
                bhe.gep(
                    hash_fn.args[0],
                    [ir.Constant(i32, 0), ir.Constant(i32, 0)],
                    name="lp"
                ),
                name="blen"
            );
            _hdata = bhe.bitcast(
                bhe.gep(
                    hash_fn.args[0],
                    [ir.Constant(i32, 0), ir.Constant(i32, 1)],
                    name="dp"
                ),
                i8p,
                name="bdata"
            );
        } elif _key_sz > 0 {
            _hlen = ir.Constant(i64, _key_sz);
            _hdata = bhe.bitcast(hash_fn.args[0], i8p, name="kdata");
        } else {
            _hdata = hash_fn.args[0];
        }
        hlc = hash_fn.append_basic_block("lc");
        hlb = hash_fn.append_basic_block("lb");
        hrt = hash_fn.append_basic_block("rt");
        bhe.branch(hlc);
        blc = ir.IRBuilder(hlc);
        hidx = blc.load(idx_a, name="idx");
        if _hlen is not None {
            blc.cbranch(blc.icmp_unsigned("<", hidx, _hlen, name="more"), hlb, hrt);
            blb = ir.IRBuilder(hlb);
            hch = blb.load(blb.gep(_hdata, [hidx], name="cp"), name="ch");
        } else {
            hch0 = blc.load(blc.gep(_hdata, [hidx], name="cp"), name="ch");
            hend = blc.icmp_signed("==", hch0, ir.Constant(i8, 0), name="end");
            blc.cbranch(hend, hrt, hlb);
            blb = ir.IRBuilder(hlb);
            hch = hch0;
        }
        hcur = blb.load(h_a, name="h");
        hce = blb.zext(hch, i64, name="ce");
        hxor = blb.xor(hcur, hce, name="hx");
        hmul = blb.mul(hxor, ir.Constant(i64, HASH_FNV_PRIME), name="hm");
        blb.store(hmul, h_a);
        blb.store(blb.add(hidx, ir.Constant(i64, 1), name="ni"), idx_a);
        blb.branch(hlc);
        brt = ir.IRBuilder(hrt);
        brt.ret(brt.load(h_a, name="hf"));
    } else {
        if isinstance(key_type, ir.PointerType) {
            ki = bhe.ptrtoint(hash_fn.args[0], i64, name="ki");
            bhe.ret(bhe.mul(ki, ir.Constant(i64, HASH_MUL_K), name="h"));
        } elif isinstance(key_type, ir.DoubleType) {
            kbits = bhe.bitcast(hash_fn.args[0], i64, name="kbits");
            bhe.ret(bhe.mul(kbits, ir.Constant(i64, HASH_MUL_K), name="h"));
        } else {
            bhe.ret(bhe.mul(hash_fn.args[0], ir.Constant(i64, HASH_MUL_K), name="h"));
        }
    }

    find_fnty = ir.FunctionType(i64, [cont_ptr_type, key_type, i64]);
    find_fn: any = ir.Function(
        self.llvm_module, find_fnty, name=f"{_pre}_find_ph_{_safe}"
    );
    find_fn.linkage = "private";
    find_fn.args[0].name = "cont";
    find_fn.args[1].name = "key";
    find_fn.args[2].name = "h";
    bf = ir.IRBuilder(find_fn.append_basic_block("entry"));
    d_f = find_fn.args[0];
    k_f = find_fn.args[1];
    slot_a = bf.alloca(i64, name="slot");
    itomb_a = bf.alloca(i64, name="itomb");

    hf = find_fn.args[2];
    h2r = bf.lshr(hf, ir.Constant(i64, 57), name="h2r");
    h27 = bf.and_(h2r, ir.Constant(i64, 0x7F), name="h27");
    h2o = bf.or_(h27, ir.Constant(i64, 0x80), name="h2o");
    h2 = bf.trunc(h2o, i8, name="h2");

    capf = bf.load(
        bf.gep(d_f, [ir.Constant(i32, 0), ir.Constant(i32, CAP_F)], name="cp"),
        name="cap"
    );
    keysf = bf.load(
        bf.gep(d_f, [ir.Constant(i32, 0), ir.Constant(i32, KEYS_F)], name="kp"),
        name="keys"
    );
    ctrlf = bf.load(
        bf.gep(d_f, [ir.Constant(i32, 0), ir.Constant(i32, CTRL_F)], name="ctp"),
        name="ctrl"
    );
    maskf = bf.sub(capf, ir.Constant(i64, 1), name="mask");
    s0 = bf.and_(hf, maskf, name="s0");
    bf.store(s0, slot_a);
    bf.store(ir.Constant(i64, -1), itomb_a);

    cap0_bb = find_fn.append_basic_block("cap0");
    probe_bb = find_fn.append_basic_block("probe");
    empty_bb = find_fn.append_basic_block("empty");
    fp_bb = find_fn.append_basic_block("fp");
    keq_bb = find_fn.append_basic_block("keq");
    tomb_bb = find_fn.append_basic_block("tomb");
    next_bb = find_fn.append_basic_block("next");
    found_bb = find_fn.append_basic_block("found");
    _cap_is0 = bf.icmp_unsigned("==", capf, ir.Constant(i64, 0), name="cap.is0");
    bf.cbranch(_cap_is0, cap0_bb, probe_bb);
    ir.IRBuilder(cap0_bb).ret(ir.Constant(i64, -1));

    bp = ir.IRBuilder(probe_bb);
    sl = bp.load(slot_a, name="sl");
    cbp = bp.gep(ctrlf, [sl], name="cbp");
    cb = bp.load(cbp, name="cb");
    emp = bp.icmp_unsigned("==", cb, ir.Constant(i8, HASH_CTRL_EMPTY), name="emp");
    bp.cbranch(emp, empty_bb, fp_bb);

    be = ir.IRBuilder(empty_bb);
    itomb = be.load(itomb_a, name="it");
    notmb = be.icmp_signed("==", itomb, ir.Constant(i64, -1), name="nt");
    ins = be.select(notmb, sl, itomb, name="ins");
    be.ret(be.xor(ins, ir.Constant(i64, -1), name="nfr"));

    bfp = ir.IRBuilder(fp_bb);
    fpm = bfp.icmp_unsigned("==", cb, h2, name="fpm");
    bfp.cbranch(fpm, keq_bb, tomb_bb);

    bke = ir.IRBuilder(keq_bb);
    kke: any = bke.load(bke.gep(keysf, [sl], name="kp"), name="k");
    keq = self._emit_key_comparison(bke, key_type, kke, k_f, _key_sz);
    bke.cbranch(keq, found_bb, next_bb);

    bfnd = ir.IRBuilder(found_bb);
    bfnd.ret(sl);

    btb = ir.IRBuilder(tomb_bb);
    ist = btb.icmp_unsigned("==", cb, ir.Constant(i8, HASH_CTRL_TOMBSTONE), name="ist");
    it2 = btb.load(itomb_a, name="it2");
    nt2 = btb.icmp_signed("==", it2, ir.Constant(i64, -1), name="nt2");
    ss = btb.and_(ist, nt2, name="ss");
    nit = btb.select(ss, sl, it2, name="nit");
    btb.store(nit, itomb_a);
    btb.branch(next_bb);

    bnx = ir.IRBuilder(next_bb);
    nsl = bnx.add(sl, ir.Constant(i64, 1), name="nsl");
    nslm = bnx.and_(nsl, maskf, name="nslm");
    bnx.store(nslm, slot_a);
    bnx.branch(probe_bb);

    rehash_fnty = ir.FunctionType(ir.VoidType(), [cont_ptr_type]);
    rehash_fn: any = ir.Function(
        self.llvm_module, rehash_fnty, name=f"{_pre}_rehash_{_safe}"
    );
    rehash_fn.linkage = "private";
    rehash_fn.args[0].name = "cont";
    brh = ir.IRBuilder(rehash_fn.append_basic_block("entry"));
    d_rh = rehash_fn.args[0];

    ok_a = brh.alloca(key_type, name="ok");
    ov_a = brh.alloca(val_type, name="ov") if has_vals else None;
    nh2_a = brh.alloca(i8, name="nh2");
    rslot_a = brh.alloca(i64, name="rsl");
    si_a = brh.alloca(i64, name="si");

    cap_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, CAP_F)], name="cp");
    keys_prh = brh.gep(
        d_rh, [ir.Constant(i32, 0), ir.Constant(i32, KEYS_F)], name="kp"
    );
    vals_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, VALS_F)], name="vp")
        if has_vals
        else None;
    ctrl_prh = brh.gep(
        d_rh, [ir.Constant(i32, 0), ir.Constant(i32, CTRL_F)], name="ctp"
    );
    len_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, LEN_F)], name="lp");
    used_prh = brh.gep(
        d_rh, [ir.Constant(i32, 0), ir.Constant(i32, USED_F)], name="up"
    );
    ord_prh = brh.gep(
        d_rh, [ir.Constant(i32, 0), ir.Constant(i32, ORDER_F)], name="orp"
    );
    old_cap = brh.load(cap_prh, name="ocap");
    old_len = brh.load(len_prh, name="olen");
    old_keys = brh.load(keys_prh, name="okeys");
    old_vals = brh.load(vals_prh, name="ovals") if has_vals else None;
    old_ctrl = brh.load(ctrl_prh, name="octrl");
    old_order = brh.load(ord_prh, name="oorder");
    _ncap_dbl = brh.mul(old_cap, ir.Constant(i64, 2), name="ncap.dbl");
    _ocap_is0 = brh.icmp_unsigned("==", old_cap, ir.Constant(i64, 0), name="ocap.is0");
    new_cap = brh.select(
        _ocap_is0, ir.Constant(i64, HASH_INIT_CAP), _ncap_dbl, name="ncap"
    );
    new_mask = brh.sub(new_cap, ir.Constant(i64, 1), name="nmask");

    kgnr = brh.gep(
        ir.Constant(key_type.as_pointer(), None), [ir.Constant(i32, 1)], name="ksz"
    );
    kszr = brh.ptrtoint(kgnr, i64, name="ksz");
    kbrh = brh.mul(new_cap, kszr, name="kb");
    nkr = brh.call(malloc_fn, [kbrh], name="nkr");
    new_keys = brh.bitcast(nkr, key_type.as_pointer(), name="nk");
    new_vals = None;
    if has_vals {
        vgnr = brh.gep(
            ir.Constant(_vt.as_pointer(), None), [ir.Constant(i32, 1)], name="vsz"
        );
        vszr = brh.ptrtoint(vgnr, i64, name="vsz");
        vbrh = brh.mul(new_cap, vszr, name="vb");
        nvr = brh.call(malloc_fn, [vbrh], name="nvr");
        new_vals = brh.bitcast(nvr, _vt.as_pointer(), name="nv");
    }
    ncr = brh.call(calloc_fn, [new_cap, ir.Constant(i64, 1)], name="ncr");

    _nord_bytes = brh.mul(new_cap, ir.Constant(i64, 8), name="nordb");
    nordr = brh.call(malloc_fn, [_nord_bytes], name="nordr");
    new_order = brh.bitcast(nordr, i64.as_pointer(), name="norder");

    brh.store(new_cap, cap_prh);
    brh.store(new_keys, keys_prh);
    if has_vals {
        brh.store(new_vals, vals_prh);
    }
    brh.store(ncr, ctrl_prh);
    brh.store(new_order, ord_prh);
    brh.store(ir.Constant(i64, 0), len_prh);
    brh.store(ir.Constant(i64, 0), used_prh);
    brh.store(ir.Constant(i64, 0), si_a);

    rl_bb = rehash_fn.append_basic_block("rl");
    ri_bb = rehash_fn.append_basic_block("ri");
    rp_bb = rehash_fn.append_basic_block("rp");
    ra_bb = rehash_fn.append_basic_block("ra");
    rd_bb = rehash_fn.append_basic_block("rd");
    rf_bb = rehash_fn.append_basic_block("rf");
    brh.branch(rl_bb);

    brl = ir.IRBuilder(rl_bb);
    si_rh = brl.load(si_a, name="j");
    rend = brl.icmp_unsigned(">=", si_rh, old_len, name="rend");
    brl.cbranch(rend, rf_bb, ri_bb);

    bri = ir.IRBuilder(ri_bb);
    _osl = bri.load(bri.gep(old_order, [si_rh], name="osl.p"), name="osl");
    ok_v = bri.load(bri.gep(old_keys, [_osl], name="okp"), name="ok");
    bri.store(ok_v, ok_a);
    if has_vals {
        ov_v = bri.load(bri.gep(old_vals, [_osl], name="ovp"), name="ov");
        bri.store(ov_v, ov_a);
    }
    nhr = bri.call(hash_fn, [ok_v], name="nh");
    nh2r0 = bri.lshr(nhr, ir.Constant(i64, 57), name="nh2r");
    nh2r7 = bri.and_(nh2r0, ir.Constant(i64, 0x7F), name="nh27");
    nh2ro = bri.or_(nh2r7, ir.Constant(i64, 0x80), name="nh2o");
    nh2 = bri.trunc(nh2ro, i8, name="nh2");
    bri.store(nh2, nh2_a);
    bri.store(bri.and_(nhr, new_mask, name="rs0"), rslot_a);
    bri.branch(rp_bb);

    brp = ir.IRBuilder(rp_bb);
    rsl = brp.load(rslot_a, name="rsl");
    ncp = brp.gep(ncr, [rsl], name="ncp");
    nc = brp.load(ncp, name="nc");
    rse = brp.icmp_unsigned("==", nc, ir.Constant(i8, HASH_CTRL_EMPTY), name="rse");
    brp.cbranch(rse, rd_bb, ra_bb);

    bra = ir.IRBuilder(ra_bb);
    nrsl = bra.add(rsl, ir.Constant(i64, 1), name="nrsl");
    bra.store(bra.and_(nrsl, new_mask, name="nrslm"), rslot_a);
    bra.branch(rp_bb);

    brd = ir.IRBuilder(rd_bb);
    ok_d = brd.load(ok_a, name="ok");
    nh2_d = brd.load(nh2_a, name="nh2");
    brd.store(ok_d, brd.gep(new_keys, [rsl], name="nkp"));
    if has_vals {
        ov_d = brd.load(ov_a, name="ov");
        brd.store(ov_d, brd.gep(new_vals, [rsl], name="nvp"));
    }
    brd.store(nh2_d, brd.gep(ncr, [rsl], name="ncp2"));
    cl_d = brd.load(len_prh, name="cl");

    brd.store(rsl, brd.gep(new_order, [cl_d], name="nordp"));
    brd.store(brd.add(cl_d, ir.Constant(i64, 1), name="nl"), len_prh);
    cu_d = brd.load(used_prh, name="cu");
    brd.store(brd.add(cu_d, ir.Constant(i64, 1), name="nu"), used_prh);
    brd.store(brd.add(brd.load(si_a, name="j2"), ir.Constant(i64, 1), name="nj"), si_a);
    brd.branch(rl_bb);

    brf = ir.IRBuilder(rf_bb);
    if _hl {
        brf.call(_free_hl, [brf.bitcast(old_keys, i8p, name="oki8")]);
        if has_vals {
            brf.call(_free_hl, [brf.bitcast(old_vals, i8p, name="ovi8")]);
        }
        brf.call(_free_hl, [old_ctrl]);
        brf.call(_free_hl, [brf.bitcast(old_order, i8p, name="ordi8")]);
    } else {
        brf.call(self.rc_safe_free_fn, [brf.bitcast(old_keys, i8p, name="oki8")]);
        if has_vals {
            brf.call(self.rc_safe_free_fn, [brf.bitcast(old_vals, i8p, name="ovi8")]);
        }
        brf.call(self.rc_safe_free_fn, [old_ctrl]);
        brf.call(self.rc_safe_free_fn, [brf.bitcast(old_order, i8p, name="ordi8")]);
    }
    brf.ret_void();

    _ins_op = "set" if has_vals else "add";
    _ins_args = [cont_ptr_type, key_type, val_type, i64]
        if has_vals
        else [cont_ptr_type, key_type, i64];
    ins_fnty = ir.FunctionType(ir.VoidType(), _ins_args);
    ins_fn: any = ir.Function(
        self.llvm_module, ins_fnty, name=f"{_pre}_{_ins_op}_ph_{_safe}"
    );
    ins_fn.linkage = "private";
    ins_fn.args[0].name = "cont";
    ins_fn.args[1].name = "key";
    if has_vals {
        ins_fn.args[2].name = "val";
    }
    ins_fn.args[3 if has_vals else 2].name = "h";
    bs = ir.IRBuilder(ins_fn.append_basic_block("entry"));
    d_s = ins_fn.args[0];
    k_s = ins_fn.args[1];
    v_s: any = ins_fn.args[2] if has_vals else None;
    h_ins: any = ins_fn.args[3 if has_vals else 2];
    _sz_cap = bs.load(
        bs.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, CAP_F)], name="szc.p"),
        name="szc"
    );
    _sz0_bb = ins_fn.append_basic_block("cap0.grow");
    _sfind_bb = ins_fn.append_basic_block("find");
    bs.cbranch(
        bs.icmp_unsigned("==", _sz_cap, ir.Constant(i64, 0), name="szc.is0"),
        _sz0_bb,
        _sfind_bb
    );
    _bs0 = ir.IRBuilder(_sz0_bb);
    _bs0.call(rehash_fn, [d_s]);
    _bs0.branch(_sfind_bb);
    bs = ir.IRBuilder(_sfind_bb);
    res_s = bs.call(find_fn, [d_s, k_s, h_ins], name="res");
    is_fnd = bs.icmp_signed(">=", res_s, ir.Constant(i64, 0), name="found");
    upd_bb = ins_fn.append_basic_block("upd");
    ins_bb = ins_fn.append_basic_block("ins");
    reh_bb = ins_fn.append_basic_block("reh");
    done_s = ins_fn.append_basic_block("done");
    bs.cbranch(is_fnd, upd_bb, ins_bb);

    bu = ir.IRBuilder(upd_bb);
    if has_vals {
        vals_as = bu.load(
            bu.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, VALS_F)], name="vp"),
            name="va"
        );
        vsp = bu.gep(vals_as, [res_s], name="vsp");
        if self._elem_kind(_vt) != "raw" and not _hl {
            self._emit_elem_retain(bu, _vt, v_s);
            ov_u: any = bu.load(vsp, name="ov");
            bu.store(v_s, vsp);
            self._emit_elem_release(bu, _vt, ov_u);
        } else {
            bu.store(v_s, vsp);
        }
        bu.ret_void();
    } elif (
        _hl
        and isinstance(key_type, ir.PointerType)
        and isinstance(key_type.pointee, ir.IntType)
        and key_type.pointee.width == 8
    ) {
        _slot_ty_dup = self._nogc_elem_drop_slot_ty();
        _sslot_p = bu.gep(
            d_s,
            [ir.Constant(i32, 0), ir.Constant(i32, layout["drop_base"])],
            name="dup.slot.p"
        );
        _sslot = bu.load(_sslot_p, name="dup.slot");
        _shave = bu.icmp_unsigned(
            "!=", _sslot, ir.Constant(_slot_ty_dup, None), name="dup.have"
        );
        _dup_free_bb = ins_fn.append_basic_block("dup.free");
        _dup_done_bb = ins_fn.append_basic_block("dup.done");
        bu.cbranch(_shave, _dup_free_bb, _dup_done_bb);
        _fb = ir.IRBuilder(_dup_free_bb);
        _fb.call(_sslot, [_fb.bitcast(k_s, i8p, name="dup.i8")]);
        _fb.branch(_dup_done_bb);
        _db = ir.IRBuilder(_dup_done_bb);
        _db.ret_void();
    } else {
        bu.ret_void();
    }

    bi = ir.IRBuilder(ins_bb);
    isl = bi.xor(res_s, ir.Constant(i64, -1), name="isl");

    h_s = h_ins;
    h2r_s = bi.lshr(h_s, ir.Constant(i64, 57), name="h2r");
    h27_s = bi.and_(h2r_s, ir.Constant(i64, 0x7F), name="h27");
    h2o_s = bi.or_(h27_s, ir.Constant(i64, 0x80), name="h2o");
    h2_s = bi.trunc(h2o_s, i8, name="h2");

    len_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, LEN_F)], name="lrp");
    keys_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, KEYS_F)], name="krp");
    ctrl_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, CTRL_F)], name="crp");
    used_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, USED_F)], name="urp");
    cap_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, CAP_F)], name="carp");
    ka_s = bi.load(keys_rp, name="ka");
    ca_s = bi.load(ctrl_rp, name="ca");

    icp = bi.gep(ca_s, [isl], name="icp");
    icb = bi.load(icp, name="icb");
    was_tb = bi.icmp_unsigned(
        "==", icb, ir.Constant(i8, HASH_CTRL_TOMBSTONE), name="wt"
    );

    _k_ins = k_s;
    if _hl {
        if (
            has_vals
            and isinstance(key_type, ir.PointerType)
            and isinstance(key_type.pointee, ir.IntType)
            and key_type.pointee.width == 8
        ) {
            _k_src: any = bi.bitcast(k_s, i8p, name="ins_key_src");
            _k_ins = self._call_str_dup(bi, _k_src, name="ins_key_dup");
            _k_ins = bi.bitcast(_k_ins, key_type, name="ins_key_copy");
        }
    } else {
        if isinstance(key_type, ir.PointerType) {
            bi.call(self.rc_retain_fn, [bi.bitcast(k_s, i8p, name="kc")]);
        }
        if has_vals {
            self._emit_elem_retain(bi, _vt, v_s);
        }
    }
    bi.store(_k_ins, bi.gep(ka_s, [isl], name="ksp"));
    if has_vals {
        va_s = bi.load(
            bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, VALS_F)], name="vrp"),
            name="va"
        );
        bi.store(v_s, bi.gep(va_s, [isl], name="vsp"));
    }
    bi.store(h2_s, icp);

    cl_s = bi.load(len_rp, name="cl");
    ord_ip = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, ORDER_F)], name="orp");
    ord_a = bi.load(ord_ip, name="ora");
    bi.store(isl, bi.gep(ord_a, [cl_s], name="oslp"));
    bi.store(bi.add(cl_s, ir.Constant(i64, 1), name="nl"), len_rp);

    ntb = bi.not_(was_tb, name="ntb");
    cu_s = bi.load(used_rp, name="cu");
    nu_s = bi.add(cu_s, bi.zext(ntb, i64, name="ntbx"), name="nu");
    bi.store(nu_s, used_rp);

    cc_s = bi.load(cap_rp, name="cc");
    u4 = bi.mul(nu_s, ir.Constant(i64, 4), name="u4");
    c3 = bi.mul(cc_s, ir.Constant(i64, 3), name="c3");
    nreh = bi.icmp_unsigned(">", u4, c3, name="nreh");
    bi.cbranch(nreh, reh_bb, done_s);

    breh = ir.IRBuilder(reh_bb);
    breh.call(rehash_fn, [d_s]);
    breh.branch(done_s);
    ir.IRBuilder(done_s).ret_void();

    contains_fnty = ir.FunctionType(i1, [cont_ptr_type, key_type, i64]);
    contains_fn: any = ir.Function(
        self.llvm_module, contains_fnty, name=f"{_pre}_contains_ph_{_safe}"
    );
    contains_fn.linkage = "private";
    contains_fn.args[0].name = "cont";
    contains_fn.args[1].name = "key";
    contains_fn.args[2].name = "h";
    bc = ir.IRBuilder(contains_fn.append_basic_block("entry"));
    res_c = bc.call(
        find_fn,
        [contains_fn.args[0], contains_fn.args[1], contains_fn.args[2]],
        name="res"
    );
    bc.ret(bc.icmp_signed(">=", res_c, ir.Constant(i64, 0), name="found"));

    remove_fnty = ir.FunctionType(ir.VoidType(), [cont_ptr_type, key_type, i64]);
    remove_fn: any = ir.Function(
        self.llvm_module, remove_fnty, name=f"{_pre}_remove_ph_{_safe}"
    );
    remove_fn.linkage = "private";
    remove_fn.args[0].name = "cont";
    remove_fn.args[1].name = "key";
    remove_fn.args[2].name = "h";
    brm = ir.IRBuilder(remove_fn.append_basic_block("entry"));
    d_rm = remove_fn.args[0];
    res_rm: any = brm.call(
        find_fn, [d_rm, remove_fn.args[1], remove_fn.args[2]], name="res"
    );
    fnd_rm = brm.icmp_signed(">=", res_rm, ir.Constant(i64, 0), name="found");
    del_bb = remove_fn.append_basic_block("del");
    done_rm = remove_fn.append_basic_block("done");
    brm.cbranch(fnd_rm, del_bb, done_rm);
    bdel = ir.IRBuilder(del_bb);
    ka_rm = bdel.load(
        bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, KEYS_F)], name="kp"),
        name="ka"
    );
    ca_rm = bdel.load(
        bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, CTRL_F)], name="ctp"),
        name="ca"
    );
    lp_rm = bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, LEN_F)], name="lp");
    if isinstance(key_type, ir.PointerType) {
        kv_rm = bdel.load(bdel.gep(ka_rm, [res_rm], name="kvp"), name="kv");
        if _hl {
            bdel.call(_free_hl, [bdel.bitcast(kv_rm, i8p, name="kc")]);
        } else {
            bdel.call(self.rc_release_simple_fn, [bdel.bitcast(kv_rm, i8p, name="kc")]);
        }
        bdel.store(
            ir.Constant(key_type, None), bdel.gep(ka_rm, [res_rm], name="kclear")
        );
    }
    if has_vals and self._elem_kind(_vt) != "raw" {
        va_rm = bdel.load(
            bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, VALS_F)], name="vp"),
            name="va"
        );
        vv_rm: any = bdel.load(bdel.gep(va_rm, [res_rm], name="vvp"), name="vv");
        if not _hl {
            self._emit_elem_release(bdel, _vt, vv_rm);
        }
        bdel.store(
            ir.Constant(val_type, None), bdel.gep(va_rm, [res_rm], name="vclear")
        );
    }
    bdel.store(
        ir.Constant(i8, HASH_CTRL_TOMBSTONE), bdel.gep(ca_rm, [res_rm], name="csp")
    );
    cl_rm = bdel.load(lp_rm, name="cl");
    _new_len_rm: any = bdel.sub(cl_rm, ir.Constant(i64, 1), name="nl");
    bdel.store(_new_len_rm, lp_rm);

    bdel2 = self._emit_dict_order_compact(
        bdel, remove_fn, d_rm, res_rm, _new_len_rm, i32, i64, ORDER_F
    );
    bdel2.branch(done_rm);
    ir.IRBuilder(done_rm).ret_void();

    pop_fn: any = None;
    if has_vals {
        pop_fnty = ir.FunctionType(val_type, [cont_ptr_type, key_type, i64]);
        pop_fn = ir.Function(self.llvm_module, pop_fnty, name=f"{_pre}_pop_ph_{_safe}");
        pop_fn.linkage = "private";
        pop_fn.args[0].name = "cont";
        pop_fn.args[1].name = "key";
        pop_fn.args[2].name = "h";
        bpop = ir.IRBuilder(pop_fn.append_basic_block("entry"));
        d_pop = pop_fn.args[0];
        res_p: any = bpop.call(
            find_fn, [d_pop, pop_fn.args[1], pop_fn.args[2]], name="res"
        );
        fnd_p = bpop.icmp_signed(">=", res_p, ir.Constant(i64, 0), name="found");
        del_p = pop_fn.append_basic_block("del");
        miss_p = pop_fn.append_basic_block("miss");
        bpop.cbranch(fnd_p, del_p, miss_p);
        bdp = ir.IRBuilder(del_p);
        ka_p = bdp.load(
            bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, KEYS_F)], name="kp"),
            name="ka"
        );
        va_p = bdp.load(
            bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, VALS_F)], name="vp"),
            name="va"
        );
        ca_p = bdp.load(
            bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, CTRL_F)], name="ctp"),
            name="ca"
        );
        lp_p = bdp.gep(
            d_pop, [ir.Constant(i32, 0), ir.Constant(i32, LEN_F)], name="lp"
        );
        v_out = bdp.load(bdp.gep(va_p, [res_p], name="vsp"), name="v");
        if self._elem_kind(_vt) != "raw" {
            bdp.store(
                ir.Constant(val_type, None), bdp.gep(va_p, [res_p], name="vclear")
            );
        }
        if isinstance(key_type, ir.PointerType) {
            kv_p = bdp.load(bdp.gep(ka_p, [res_p], name="kvp"), name="kv");
            if _hl {
                bdp.call(_free_hl, [bdp.bitcast(kv_p, i8p, name="kc")]);
            } else {
                bdp.call(
                    self.rc_release_simple_fn, [bdp.bitcast(kv_p, i8p, name="kc")]
                );
            }
            bdp.store(
                ir.Constant(key_type, None), bdp.gep(ka_p, [res_p], name="kclear")
            );
        }
        bdp.store(
            ir.Constant(i8, HASH_CTRL_TOMBSTONE), bdp.gep(ca_p, [res_p], name="csp")
        );
        cl_p = bdp.load(lp_p, name="cl");
        _new_len_p: any = bdp.sub(cl_p, ir.Constant(i64, 1), name="nl");
        bdp.store(_new_len_p, lp_p);

        bdp2 = self._emit_dict_order_compact(
            bdp, pop_fn, d_pop, res_p, _new_len_p, i32, i64, ORDER_F
        );
        bdp2.ret(v_out);
        bmp = ir.IRBuilder(miss_p);
        if isinstance(val_type, ir.PointerType) {
            bmp.ret(ir.Constant(val_type, None));
        } elif _vt_dyn?.elements and _vt_dyn.elements {
            bmp.ret(
                ir.Constant(val_type, [self._zero_const(e) for e in _vt_dyn.elements])
            );
        } else {
            bmp.ret(ir.Constant(val_type, 0));
        }
    }

    clear_fnty = ir.FunctionType(ir.VoidType(), [cont_ptr_type]);
    clear_fn: any = ir.Function(
        self.llvm_module, clear_fnty, name=f"{_pre}_clear_{_safe}"
    );
    clear_fn.linkage = "private";
    clear_fn.args[0].name = "cont";
    bcl = ir.IRBuilder(clear_fn.append_basic_block("entry"));
    d_cl = clear_fn.args[0];
    cap_cl = bcl.load(
        bcl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, CAP_F)], name="cp"),
        name="cap"
    );
    ka_cl = bcl.load(
        bcl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, KEYS_F)], name="kp"),
        name="ka"
    );
    va_cl = bcl.load(
        bcl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, VALS_F)], name="vp"),
        name="va"
    )
        if has_vals
        else None;
    ca_cl = bcl.load(
        bcl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, CTRL_F)], name="ctp"),
        name="ca"
    );
    si_cl = bcl.alloca(i64, name="si");
    bcl.store(ir.Constant(i64, 0), si_cl);

    cl_loop = clear_fn.append_basic_block("loop");
    cl_chk = clear_fn.append_basic_block("chk");
    cl_live = clear_fn.append_basic_block("live");
    cl_zero = clear_fn.append_basic_block("zero");
    cl_done = clear_fn.append_basic_block("done");
    bcl.branch(cl_loop);

    blc_cl = ir.IRBuilder(cl_loop);
    si_v_cl = blc_cl.load(si_cl, name="si");
    blc_cl.cbranch(
        blc_cl.icmp_unsigned(">=", si_v_cl, cap_cl, name="end"), cl_done, cl_chk
    );

    bch_cl = ir.IRBuilder(cl_chk);
    cb_cl = bch_cl.load(bch_cl.gep(ca_cl, [si_v_cl], name="cbp"), name="cb");
    bch_cl.cbranch(
        bch_cl.icmp_unsigned(">=", cb_cl, ir.Constant(i8, 0x80), name="occ"),
        cl_live,
        cl_zero
    );

    blv_cl = ir.IRBuilder(cl_live);
    if isinstance(key_type, ir.PointerType) {
        kv_cl = blv_cl.load(blv_cl.gep(ka_cl, [si_v_cl], name="kvp"), name="kv");
        if _hl {
            blv_cl.call(_free_hl, [blv_cl.bitcast(kv_cl, i8p, name="kc")]);
        } else {
            blv_cl.call(
                self.rc_release_simple_fn, [blv_cl.bitcast(kv_cl, i8p, name="kc")]
            );
        }
        blv_cl.store(
            ir.Constant(key_type, None), blv_cl.gep(ka_cl, [si_v_cl], name="kclear")
        );
    }
    if has_vals and self._elem_kind(_vt) != "raw" {
        vv_cl: any = blv_cl.load(blv_cl.gep(va_cl, [si_v_cl], name="vvp"), name="vv");
        if not _hl {
            self._emit_elem_release(blv_cl, _vt, vv_cl);
        }
        blv_cl.store(
            ir.Constant(val_type, None), blv_cl.gep(va_cl, [si_v_cl], name="vclear")
        );
    }
    blv_cl.branch(cl_zero);

    bz_cl = ir.IRBuilder(cl_zero);
    bz_cl.store(
        ir.Constant(i8, HASH_CTRL_EMPTY), bz_cl.gep(ca_cl, [si_v_cl], name="czp")
    );
    bz_cl.store(bz_cl.add(si_v_cl, ir.Constant(i64, 1), name="nsi"), si_cl);
    bz_cl.branch(cl_loop);

    bdn_cl = ir.IRBuilder(cl_done);
    bdn_cl.store(
        ir.Constant(i64, 0),
        bdn_cl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, LEN_F)], name="lp")
    );
    bdn_cl.store(
        ir.Constant(i64, 0),
        bdn_cl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, USED_F)], name="up")
    );
    bdn_cl.ret_void();

    _gk_op = "get_key" if has_vals else "get";
    get_key_fnty = ir.FunctionType(key_type, [cont_ptr_type, i64]);
    get_key_fn: any = ir.Function(
        self.llvm_module, get_key_fnty, name=f"{_pre}_{_gk_op}_{_safe}"
    );
    get_key_fn.linkage = "private";
    get_key_fn.args[0].name = "cont";
    get_key_fn.args[1].name = "i";
    bgk = ir.IRBuilder(get_key_fn.append_basic_block("entry"));
    d_gk = get_key_fn.args[0];
    tgt_gk = get_key_fn.args[1];
    len_gk = bgk.load(
        bgk.gep(d_gk, [ir.Constant(i32, 0), ir.Constant(i32, LEN_F)], name="lp"),
        name="len"
    );
    gk_ok_bb = get_key_fn.append_basic_block("ok");
    gk_oob_bb = get_key_fn.append_basic_block("oob");
    _gk_inb = bgk.and_(
        bgk.icmp_signed(">=", tgt_gk, ir.Constant(i64, 0), name="gk.ge0"),
        bgk.icmp_signed("<", tgt_gk, len_gk, name="gk.lt"),
        name="gk.inb"
    );
    bgk.cbranch(_gk_inb, gk_ok_bb, gk_oob_bb);
    bok = ir.IRBuilder(gk_ok_bb);
    ord_gk = bok.load(
        bok.gep(d_gk, [ir.Constant(i32, 0), ir.Constant(i32, ORDER_F)], name="orp"),
        name="order"
    );
    keys_gk = bok.load(
        bok.gep(d_gk, [ir.Constant(i32, 0), ir.Constant(i32, KEYS_F)], name="kp"),
        name="keys"
    );
    _gk_slot = bok.load(bok.gep(ord_gk, [tgt_gk], name="gk.slp"), name="gk.slot");
    bok.ret(bok.load(bok.gep(keys_gk, [_gk_slot], name="gk.kp"), name="k"));
    boob = ir.IRBuilder(gk_oob_bb);
    if isinstance(key_type, ir.PointerType) {
        boob.ret(ir.Constant(key_type, None));
    } else {
        boob.ret(ir.Constant(key_type, 0));
    }

    core: dict = {
        "hash": hash_fn,
        "find_ph": find_fn,
        "rehash": rehash_fn,
        "insert_ph": ins_fn,
        "contains_ph": contains_fn,
        "remove_ph": remove_fn,
        "clear": clear_fn,
        "get_key": get_key_fn
    };
    if has_vals {
        core["pop_ph"] = pop_fn;

        get_fnty = ir.FunctionType(val_type, [cont_ptr_type, key_type, i64]);
        get_fn: any = ir.Function(
            self.llvm_module, get_fnty, name=f"{_pre}_get_ph_{_safe}"
        );
        get_fn.linkage = "private";
        get_fn.args[0].name = "cont";
        get_fn.args[1].name = "key";
        get_fn.args[2].name = "h";
        bg = ir.IRBuilder(get_fn.append_basic_block("entry"));
        res_g = bg.call(
            find_fn, [get_fn.args[0], get_fn.args[1], get_fn.args[2]], name="res"
        );
        fnd_g = bg.icmp_signed(">=", res_g, ir.Constant(i64, 0), name="found");
        got_bb = get_fn.append_basic_block("got");
        miss_bb = get_fn.append_basic_block("miss");
        bg.cbranch(fnd_g, got_bb, miss_bb);
        bgg = ir.IRBuilder(got_bb);
        va_g = bgg.load(
            bgg.gep(
                get_fn.args[0],
                [ir.Constant(i32, 0), ir.Constant(i32, VALS_F)],
                name="vp"
            ),
            name="va"
        );
        bgg.ret(bgg.load(bgg.gep(va_g, [res_g], name="vsp"), name="v"));
        bmi = ir.IRBuilder(miss_bb);
        if isinstance(val_type, ir.PointerType) {
            bmi.ret(ir.Constant(val_type, None));
        } elif _vt_dyn?.elements and _vt_dyn.elements {
            bmi.ret(
                ir.Constant(val_type, [self._zero_const(e) for e in _vt_dyn.elements])
            );
        } else {
            bmi.ret(ir.Constant(val_type, 0));
        }
        core["get_ph"] = get_fn;

        get_val_fnty = ir.FunctionType(val_type, [cont_ptr_type, i64]);
        get_val_fn: any = ir.Function(
            self.llvm_module, get_val_fnty, name=f"{_pre}_get_val_{_safe}"
        );
        get_val_fn.linkage = "private";
        get_val_fn.args[0].name = "cont";
        get_val_fn.args[1].name = "i";
        bgv = ir.IRBuilder(get_val_fn.append_basic_block("entry"));
        d_gv = get_val_fn.args[0];
        tgt_gv = get_val_fn.args[1];
        len_gv = bgv.load(
            bgv.gep(d_gv, [ir.Constant(i32, 0), ir.Constant(i32, LEN_F)], name="lp"),
            name="len"
        );
        gv_ok_bb = get_val_fn.append_basic_block("ok");
        gv_oob_bb = get_val_fn.append_basic_block("oob");
        _gv_inb = bgv.and_(
            bgv.icmp_signed(">=", tgt_gv, ir.Constant(i64, 0), name="gv.ge0"),
            bgv.icmp_signed("<", tgt_gv, len_gv, name="gv.lt"),
            name="gv.inb"
        );
        bgv.cbranch(_gv_inb, gv_ok_bb, gv_oob_bb);
        bvok = ir.IRBuilder(gv_ok_bb);
        ord_gv = bvok.load(
            bvok.gep(
                d_gv, [ir.Constant(i32, 0), ir.Constant(i32, ORDER_F)], name="orp"
            ),
            name="order"
        );
        vals_gv = bvok.load(
            bvok.gep(d_gv, [ir.Constant(i32, 0), ir.Constant(i32, VALS_F)], name="vp"),
            name="vals"
        );
        _gv_slot = bvok.load(bvok.gep(ord_gv, [tgt_gv], name="gv.slp"), name="gv.slot");
        bvok.ret(bvok.load(bvok.gep(vals_gv, [_gv_slot], name="gv.vp"), name="v"));
        bvoob = ir.IRBuilder(gv_oob_bb);
        if isinstance(val_type, ir.PointerType) {
            bvoob.ret(ir.Constant(val_type, None));
        } elif _vt_dyn?.elements and _vt_dyn.elements {
            bvoob.ret(
                ir.Constant(val_type, [self._zero_const(e) for e in _vt_dyn.elements])
            );
        } else {
            bvoob.ret(ir.Constant(val_type, 0));
        }
        core["get_val"] = get_val_fn;
    }

    _pub_specs: list = [
        ("find", "find", find_fn),
        ("insert", _ins_op, ins_fn),
        ("contains", "contains", contains_fn),
        ("remove", "remove", remove_fn)
    ];
    if has_vals {
        _pub_specs.append(("pop", "pop", core["pop_ph"]));
        _pub_specs.append(("get", "get", core["get_ph"]));
    }
    for (_wkey, _wop, _wcore) in _pub_specs {
        _w_args = [a.type for a in _wcore.args];
        _wfnty = ir.FunctionType(_wcore.function_type.return_type, _w_args[:-1]);
        _wfn: any = ir.Function(
            self.llvm_module, _wfnty, name=f"{_pre}_{_wop}_{_safe}"
        );
        _wfn.linkage = "private";
        _wfn.args[0].name = "cont";
        _wfn.args[1].name = "key";
        _wb = ir.IRBuilder(_wfn.append_basic_block("entry"));
        _wh = _wb.call(hash_fn, [_wfn.args[1]], name="h");
        if isinstance(_wcore.function_type.return_type, ir.VoidType) {
            _wb.call(_wcore, list(_wfn.args) + [_wh]);
            _wb.ret_void();
        } else {
            _wb.ret(_wb.call(_wcore, list(_wfn.args) + [_wh], name="res"));
        }
        core[_wkey] = _wfn;
    }
    return core;
}

impl NaIRGenHashCore._static_str_hash(key: str) -> int {
    mask = 0xFFFFFFFFFFFFFFFF;
    h = HASH_FNV_BASIS & mask;
    for b in key.encode("utf-8") {
        h = ((h ^ b) * HASH_FNV_PRIME) & mask;
    }
    return h - 0x10000000000000000 if h >= 0x8000000000000000 else h;
}

impl NaIRGenHashCore._static_key_hash_of(
    key_node: (uni.UniNode | None)
) -> (int | None) {
    if isinstance(key_node, uni.MultiString) {
        for s in key_node.strings {
            if not isinstance(s, uni.String) {
                return None;
            }
        }
    } elif not isinstance(key_node, uni.String) {
        return None;
    }
    v: any = None;
    try {
        v = key_node.lit_value;
    } except Exception {
        return None;
    }
    if not isinstance(v, str) or "\0" in v {
        return None;
    }
    return self._static_str_hash(v);
}

impl NaIRGenHashCore._static_key_op(
    helpers: dict, op: str, key_node: (uni.UniNode | None)
) -> tuple {
    plain = helpers[op];
    ph = helpers.get(f"{op}_ph");
    if ph is None or key_node is None {
        return (plain, None);
    }
    kt = helpers.get("key_type", helpers.get("elem_type"));
    if kt != ir.IntType(8).as_pointer() {
        return (plain, None);
    }
    h = self._static_key_hash_of(key_node);
    if h is None {
        return (plain, None);
    }
    return (ph, ir.Constant(ir.IntType(64), h));
}


impl NaIRGenHashCore._str_fnv_fn -> ir.Function {
    if self.str_fnv_fn is not None {
        return self.str_fnv_fn;
    }
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    fn = self._define_function("__jac_str_fnv", ir.FunctionType(i64, [i8p]));
    fn.linkage = "private";
    fn.args[0].name = "s";
    bb_entry = fn.append_basic_block("entry");
    lc = fn.append_basic_block("lc");
    lb = fn.append_basic_block("lb");
    rt = fn.append_basic_block("rt");
    b = ir.IRBuilder(bb_entry);
    h_a = b.alloca(i64, name="h");
    idx_a = b.alloca(i64, name="idx");
    b.store(ir.Constant(i64, HASH_FNV_BASIS), h_a);
    b.store(ir.Constant(i64, 0), idx_a);
    b.cbranch(
        b.icmp_unsigned("==", fn.args[0], ir.Constant(i8p, None), name="s.null"), rt, lc
    );
    b = ir.IRBuilder(lc);
    idx = b.load(idx_a, name="idx");
    ch = b.load(b.gep(fn.args[0], [idx], name="cp"), name="ch");
    b.cbranch(b.icmp_signed("==", ch, ir.Constant(i8, 0), name="end"), rt, lb);
    b = ir.IRBuilder(lb);
    cur = b.load(h_a, name="h");
    ce = b.zext(ch, i64, name="ce");
    b.store(
        b.mul(b.xor(cur, ce, name="hx"), ir.Constant(i64, HASH_FNV_PRIME), name="hm"),
        h_a
    );
    b.store(b.add(idx, ir.Constant(i64, 1), name="ni"), idx_a);
    b.branch(lc);
    b = ir.IRBuilder(rt);
    b.ret(b.load(h_a, name="hf"));
    self.str_fnv_fn = fn;
    return fn;
}

impl NaIRGenHashCore._tuple_key_fields(key_type: ir.Type) -> (list | None) {
    if not isinstance(key_type, ir.PointerType) {
        return None;
    }
    pointee = key_type.pointee;
    if not isinstance(pointee, ir.LiteralStructType) {
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    out: list = [];
    for (i, ety) in enumerate(pointee.elements) {
        if isinstance(ety, ir.IntType) {
            out.append((i, "int"));
        } elif isinstance(ety, ir.DoubleType) {
            out.append((i, "f64"));
        } elif ety == i8p {
            out.append((i, "str"));
        } elif self._str_desc_ty is not None and ety == self._str_desc_ty {
            out.append((i, "jacstr"));
        } elif isinstance(ety, ir.PointerType) {
            out.append((i, "ptr"));
        } else {
            return None;
        }
    }
    return out;
}

impl NaIRGenHashCore._tuple_key_field_val(
    b: ir.IRBuilder, key_ptr: ir.Value, idx: int, kind: str
) -> ir.Value {
    i32 = ir.IntType(32);
    path = [ir.Constant(i32, 0), ir.Constant(i32, idx)];
    if kind == "jacstr" {
        data_idx = JACSTR_DESC_FIELDS[self._str_desc_kind()].index("data");
        path.append(ir.Constant(i32, data_idx));
    }
    fp = b.gep(key_ptr, path, name=f"tk.fp{idx}");
    return b.load(fp, name=f"tk.f{idx}");
}


impl NaIRGenHashCore._tuple_spec_name(struct_type: ir.LiteralStructType) -> str {
    size = self._get_struct_size(struct_type);
    fields = self._tuple_key_fields(struct_type.as_pointer());
    if fields is None {
        return f"tuple{size}";
    }
    sig = "";
    for (i, kind) in fields {
        if kind == "int" {
            sig += f"i{struct_type.elements[i].width}";
        } elif kind == "f64" {
            sig += "f";
        } elif kind == "str" {
            sig += "s";
        } elif kind == "jacstr" {
            sig += "j";
        } else {
            sig += "p";
        }
    }
    return f"tuple{size}_{sig}";
}
