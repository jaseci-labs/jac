"""Dictionary type codegen and operations."""
"""Integer power operation using loop-based exponentiation."""
impl NaIRGenPass._codegen_int_pow(base: ir.Value, exp: ir.Value) -> ir.Value {
    # Simple loop-based integer exponentiation
    # result = 1; for i in range(exp): result *= base
    i64 = ir.IntType(64);
    # Guard: negative exponent is undefined for integer pow
    is_neg = self.builder.icmp_signed("<", exp, ir.Constant(i64, 0), name="pow.neg");
    self._emit_runtime_raise(is_neg, "ValueError", "negative exponent");
    func = self.builder.function;
    # Allocate result and counter
    result_alloca = self._entry_alloca(i64, "pow.result");
    counter_alloca = self._entry_alloca(i64, "pow.counter");
    self.builder.store(ir.Constant(i64, 1), result_alloca);
    self.builder.store(ir.Constant(i64, 0), counter_alloca);
    # Basic blocks
    cond_bb = func.append_basic_block(name="pow.cond");
    body_bb = func.append_basic_block(name="pow.body");
    end_bb = func.append_basic_block(name="pow.end");
    self.builder.branch(cond_bb);
    # Condition: counter < exp
    self.builder.position_at_end(cond_bb);
    counter = self.builder.load(counter_alloca, name="pow.i");
    cmp = self.builder.icmp_signed("<", counter, exp, name="pow.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    # Body: result *= base; counter++
    self.builder.position_at_end(body_bb);
    cur_result = self.builder.load(result_alloca, name="pow.cur");
    new_result = self.builder.mul(cur_result, base, name="pow.mul");
    self.builder.store(new_result, result_alloca);
    cur_counter = self.builder.load(counter_alloca, name="pow.ci");
    next_counter = self.builder.add(cur_counter, ir.Constant(i64, 1), name="pow.inc");
    self.builder.store(next_counter, counter_alloca);
    self.builder.branch(cond_bb);
    # End: return result
    self.builder.position_at_end(end_bb);
    return self.builder.load(result_alloca, name="pow.final");
}

"""Emit LLVM IR helper functions for a dictionary with given key/value types.

Open-addressing hash table with 1-byte fingerprint probing, inspired by
Swiss-Table / Abseil flat_hash_map.

Struct layout: Dict.K.V { i64 len, i64 cap, K* keys, V* vals, i8* ctrl, i64 used }
  Field 0  len : live entry count
  Field 1  cap : slot count (always a power of 2, initial 8)
  Field 2  keys: key slot array  [cap slots]
  Field 3  vals: val slot array  [cap slots]
  Field 4  ctrl: control byte array [cap bytes]
               0x00 = EMPTY      — probe terminates here (slot never used)
               0x01 = TOMBSTONE  — probe continues  (slot was deleted)
               0x80..0xFF = OCCUPIED; bits[6:0] = h2 fingerprint
  Field 5  used: live + tombstone count  (load-factor denominator)

Hash:  FNV-1a for str (i8*) keys; 64-bit multiplicative for int/ptr keys.
Probe: linear probing with power-of-2 mask.
Load:  rehash when used*4 > cap*3  (75% load factor).

Core probe helper __dict_find_K_V returns:
  slot >= 0 : key found at that slot
  slot <  0 : key not present; insert position = ~slot = xor(slot, -1)
"""
impl NaIRGenPass._emit_dict_helpers(
    key_type_name: str,
    val_type_name: str,
    key_type: ir.Type,
    val_type: ir.Type,
    key_size: int = 0
) -> None {
    dict_key = f"{key_type_name}:{val_type_name}";
    if dict_key in self.dict_helpers {
        return;
    }
    # Auto-detect key_size for tuple/struct pointer keys
    _key_sz: int = int(key_size);
    if _key_sz == 0 and isinstance(key_type, ir.PointerType) {
        _pointee = key_type?.pointee;
        if _pointee is not None and isinstance(_pointee, ir.LiteralStructType) {
            _key_sz = self._get_struct_size(_pointee);
        }
    }

    # ── Types ──────────────────────────────────────────────────────────────────
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    i8p = i8.as_pointer();
    is_str_key: bool = key_type == i8p;
    is_int_key: bool = isinstance(key_type, ir.IntType);

    CTRL_EMPTY: int = 0;
    CTRL_TOMBSTONE: int = 1;
    INIT_CAP: int = 8;
    FNV_BASIS: int = -3750763034362895579;  # 14695981039346656037 unsigned
    FNV_PRIME: int = 1099511628211;
    MUL_HASH_K: int = -7046029254386353131;  # 11400714819323198485 unsigned

    # ── Dict struct: {len, cap, K*, V*, i8*, used} (6 fields) ─────────────────
    dict_struct = self.llvm_module.context.get_identified_type(
        f"Dict.{key_type_name}.{val_type_name}"
    );
    dict_struct.set_body(
        i64, i64, key_type.as_pointer(), val_type.as_pointer(), i8p, i64
    );
    self.dict_types[dict_key] = dict_struct;
    dict_ptr_type = dict_struct.as_pointer();

    malloc_fn = self._get_or_declare_extern("malloc", i8p, [i64]);
    calloc_fn = self._get_or_declare_extern("calloc", i8p, [i64, i64]);
    strcmp_fn = self._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
    if self.rc_safe_free_fn is None {
        self._emit_rc_helpers();
    }
    if self.rc_retain_fn is None {
        self._emit_rc_helpers();
    }

    # ── Forward-declare destructor so new_fn can store its pointer ─────────────
    _rel_fn_name = f"__rc_release_dict_{dict_key.replace(':', '_')}";
    _rel_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
    try {
        _rel_fn_decl = self.llvm_module.get_global(_rel_fn_name);
    } except KeyError {
        _rel_fn_decl = ir.Function(self.llvm_module, _rel_fnty, name=_rel_fn_name);
        _rel_fn_decl.linkage = "private";
    }

    # =========================================================================
    # A. __dict_hash_K_V — 64-bit hash for a key.
    #    FNV-1a loop for i8* string keys; multiplicative hash otherwise.
    # =========================================================================
    hash_fnty = ir.FunctionType(i64, [key_type]);
    hash_fn = ir.Function(
        self.llvm_module, hash_fnty, name=f"__dict_hash_{key_type_name}_{val_type_name}"
    );
    hash_fn.linkage = "private";
    hash_fn.args[0].name = "key";
    bhe = ir.IRBuilder(hash_fn.append_basic_block("entry"));
    if is_str_key {
        h_a = bhe.alloca(i64, name="h");
        idx_a = bhe.alloca(i64, name="idx");
        bhe.store(ir.Constant(i64, FNV_BASIS), h_a);
        bhe.store(ir.Constant(i64, 0), idx_a);
        hlc = hash_fn.append_basic_block("lc");
        hlb = hash_fn.append_basic_block("lb");
        hrt = hash_fn.append_basic_block("rt");
        bhe.branch(hlc);
        blc = ir.IRBuilder(hlc);
        hidx = blc.load(idx_a, name="idx");
        hcp = blc.gep(hash_fn.args[0], [hidx], name="cp");
        hch = blc.load(hcp, name="ch");
        hend = blc.icmp_signed("==", hch, ir.Constant(i8, 0), name="end");
        blc.cbranch(hend, hrt, hlb);
        blb = ir.IRBuilder(hlb);
        hcur = blb.load(h_a, name="h");
        hce = blb.zext(hch, i64, name="ce");
        hxor = blb.xor(hcur, hce, name="hx");
        hmul = blb.mul(hxor, ir.Constant(i64, FNV_PRIME), name="hm");
        blb.store(hmul, h_a);
        blb.store(blb.add(hidx, ir.Constant(i64, 1), name="ni"), idx_a);
        blb.branch(hlc);
        brt = ir.IRBuilder(hrt);
        brt.ret(brt.load(h_a, name="hf"));
    } else {
        if isinstance(key_type, ir.PointerType) {
            ki = bhe.ptrtoint(hash_fn.args[0], i64, name="ki");
            bhe.ret(bhe.mul(ki, ir.Constant(i64, MUL_HASH_K), name="h"));
        } else {
            bhe.ret(bhe.mul(hash_fn.args[0], ir.Constant(i64, MUL_HASH_K), name="h"));
        }
    }

    # =========================================================================
    # B. __dict_find_K_V — core probe: locate a key in the hash table.
    #    Returns slot >= 0 when found.
    #    Returns ~slot (always < 0) when not found; ~result = best insert pos.
    #    Tombstones are skipped; the first tombstone seen becomes the insert pos.
    # =========================================================================
    find_fnty = ir.FunctionType(i64, [dict_ptr_type, key_type]);
    find_fn = ir.Function(
        self.llvm_module, find_fnty, name=f"__dict_find_{key_type_name}_{val_type_name}"
    );
    find_fn.linkage = "private";
    find_fn.args[0].name = "dict";
    find_fn.args[1].name = "key";
    bf = ir.IRBuilder(find_fn.append_basic_block("entry"));
    d_f = find_fn.args[0];
    k_f = find_fn.args[1];
    slot_a = bf.alloca(i64, name="slot");
    itomb_a = bf.alloca(i64, name="itomb");
    # Compute hash + fingerprint byte h2 (always 0x80..0xFF)
    hf = bf.call(hash_fn, [k_f], name="h");
    h2r = bf.lshr(hf, ir.Constant(i64, 57), name="h2r");
    h27 = bf.and_(h2r, ir.Constant(i64, 0x7F), name="h27");
    h2o = bf.or_(h27, ir.Constant(i64, 0x80), name="h2o");
    h2 = bf.trunc(h2o, i8, name="h2");
    # Load cap, mask, keys, ctrl
    capf = bf.load(
        bf.gep(d_f, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp"), name="cap"
    );
    keysf = bf.load(
        bf.gep(d_f, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"), name="keys"
    );
    ctrlf = bf.load(
        bf.gep(d_f, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"), name="ctrl"
    );
    maskf = bf.sub(capf, ir.Constant(i64, 1), name="mask");
    s0 = bf.and_(hf, maskf, name="s0");
    bf.store(s0, slot_a);
    bf.store(ir.Constant(i64, -1), itomb_a);
    # BB layout for probe loop
    probe_bb = find_fn.append_basic_block("probe");
    empty_bb = find_fn.append_basic_block("empty");
    fp_bb = find_fn.append_basic_block("fp");
    keq_bb = find_fn.append_basic_block("keq");
    tomb_bb = find_fn.append_basic_block("tomb");
    next_bb = find_fn.append_basic_block("next");
    found_bb = find_fn.append_basic_block("found");
    bf.branch(probe_bb);
    # probe: load ctrl[slot]
    bp = ir.IRBuilder(probe_bb);
    sl = bp.load(slot_a, name="sl");
    cbp = bp.gep(ctrlf, [sl], name="cbp");
    cb = bp.load(cbp, name="cb");
    emp = bp.icmp_unsigned("==", cb, ir.Constant(i8, CTRL_EMPTY), name="emp");
    bp.cbranch(emp, empty_bb, fp_bb);
    # empty: not found — pick best insert slot and return ~slot
    be = ir.IRBuilder(empty_bb);
    itomb = be.load(itomb_a, name="it");
    notmb = be.icmp_signed("==", itomb, ir.Constant(i64, -1), name="nt");
    ins = be.select(notmb, sl, itomb, name="ins");
    be.ret(be.xor(ins, ir.Constant(i64, -1), name="nfr"));
    # fp: check fingerprint match
    bfp = ir.IRBuilder(fp_bb);
    fpm = bfp.icmp_unsigned("==", cb, h2, name="fpm");
    bfp.cbranch(fpm, keq_bb, tomb_bb);
    # keq: fingerprint matched — compare actual key
    bke = ir.IRBuilder(keq_bb);
    kpke = bke.gep(keysf, [sl], name="kp");
    kke = bke.load(kpke, name="k");
    if is_int_key {
        keq = bke.icmp_signed("==", kke, k_f, name="keq");
    } elif is_str_key {
        cmpr = bke.call(strcmp_fn, [kke, k_f], name="scmp");
        keq = bke.icmp_signed("==", cmpr, ir.Constant(i32, 0), name="keq");
    } elif _key_sz > 0 {
        memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
        ki = bke.bitcast(kke, i8p, name="ki");
        ai = bke.bitcast(k_f, i8p, name="ai");
        cr = bke.call(memcmp_fn, [ki, ai, ir.Constant(i64, _key_sz)], name="mcr");
        keq = bke.icmp_signed("==", cr, ir.Constant(i32, 0), name="keq");
    } else {
        keq = bke.icmp_unsigned("==", kke, k_f, name="keq");
    }
    bke.cbranch(keq, found_bb, next_bb);
    # found: return slot (>= 0)
    bfnd = ir.IRBuilder(found_bb);
    bfnd.ret(sl);
    # tomb: not matched fingerprint OR tombstone; save first tombstone for insert
    btb = ir.IRBuilder(tomb_bb);
    ist = btb.icmp_unsigned("==", cb, ir.Constant(i8, CTRL_TOMBSTONE), name="ist");
    it2 = btb.load(itomb_a, name="it2");
    nt2 = btb.icmp_signed("==", it2, ir.Constant(i64, -1), name="nt2");
    ss = btb.and_(ist, nt2, name="ss");
    nit = btb.select(ss, sl, it2, name="nit");
    btb.store(nit, itomb_a);
    btb.branch(next_bb);
    # next: advance slot = (slot + 1) & mask
    bnx = ir.IRBuilder(next_bb);
    nsl = bnx.add(sl, ir.Constant(i64, 1), name="nsl");
    nslm = bnx.and_(nsl, maskf, name="nslm");
    bnx.store(nslm, slot_a);
    bnx.branch(probe_bb);

    # =========================================================================
    # C. __dict_new_K_V — allocate empty hash table (cap = INIT_CAP).
    #    Uses rc_alloc for the container struct; malloc for three data arrays.
    #    ctrl array is zeroed (CTRL_EMPTY = 0x00).
    # =========================================================================
    new_fnty2 = ir.FunctionType(dict_ptr_type, []);
    new_fn = ir.Function(
        self.llvm_module, new_fnty2, name=f"__dict_new_{key_type_name}_{val_type_name}"
    );
    new_fn.linkage = "private";
    bn = ir.IRBuilder(new_fn.append_basic_block("entry"));
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    # Allocate container struct via rc_alloc
    null_p = ir.Constant(dict_ptr_type, None);
    sg = bn.gep(null_p, [ir.Constant(i32, 1)], name="sg");
    ssz = bn.ptrtoint(sg, i64, name="ssz");
    raw = bn.call(self.rc_alloc_fn, [ssz], name="raw");
    dp = bn.bitcast(raw, dict_ptr_type, name="dp");
    # Set type tag
    if self.rc_set_type_fn is not None {
        _tn = _rel_fn_name[len("__rc_release_"):]
            if _rel_fn_name.startswith("__rc_release_")
            else "dict";
        _dpi8 = bn.bitcast(dp, i8p, name="dp.i8");
        self._emit_set_type_tag(bn, _dpi8, _tn);
    }
    # Store destructor pointer at dp - 8
    _i64p_n = i64.as_pointer();
    _drn = bn.bitcast(dp, i8p, name="dr");
    _dsln = bn.gep(_drn, [ir.Constant(i64, -8)], name="dsl");
    _dslip = bn.bitcast(_dsln, _i64p_n, name="dsli");
    _dti64 = bn.ptrtoint(_rel_fn_decl, i64, name="di");
    bn.store(_dti64, _dslip);
    # len = 0
    bn.store(
        ir.Constant(i64, 0),
        bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp")
    );
    # cap = INIT_CAP
    bn.store(
        ir.Constant(i64, INIT_CAP),
        bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp")
    );
    # keys = malloc(INIT_CAP * sizeof(K))
    kn = ir.Constant(key_type.as_pointer(), None);
    kgn = bn.gep(kn, [ir.Constant(i32, 1)], name="ksz");
    ksn = bn.ptrtoint(kgn, i64, name="ksz");
    kbn = bn.mul(ir.Constant(i64, INIT_CAP), ksn, name="kb");
    krn = bn.call(malloc_fn, [kbn], name="kr");
    kpn = bn.bitcast(krn, key_type.as_pointer(), name="kp");
    bn.store(kpn, bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kf"));
    # vals = malloc(INIT_CAP * sizeof(V))
    vn = ir.Constant(val_type.as_pointer(), None);
    vgn = bn.gep(vn, [ir.Constant(i32, 1)], name="vsz");
    vsn = bn.ptrtoint(vgn, i64, name="vsz");
    vbn = bn.mul(ir.Constant(i64, INIT_CAP), vsn, name="vb");
    vrn = bn.call(malloc_fn, [vbn], name="vr");
    vpn = bn.bitcast(vrn, val_type.as_pointer(), name="vp");
    bn.store(vpn, bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vf"));
    # ctrl = calloc(INIT_CAP, 1) — zero-initialized (CTRL_EMPTY = 0x00)
    cbn = ir.Constant(i64, INIT_CAP);
    crn = bn.call(calloc_fn, [cbn, ir.Constant(i64, 1)], name="cr");
    bn.store(crn, bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="cf"));
    # used = 0
    bn.store(
        ir.Constant(i64, 0),
        bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 5)], name="uf")
    );
    bn.ret(dp);

    # =========================================================================
    # D. __dict_rehash_K_V — double cap and reinsert all live entries.
    #    No RC operations during reinsert (refs are moved, not copied).
    #    After rehash: len = live entries, used = live entries (no tombstones).
    # =========================================================================
    rehash_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
    rehash_fn = ir.Function(
        self.llvm_module,
        rehash_fnty,
        name=f"__dict_rehash_{key_type_name}_{val_type_name}"
    );
    rehash_fn.linkage = "private";
    rehash_fn.args[0].name = "dict";
    brh = ir.IRBuilder(rehash_fn.append_basic_block("entry"));
    d_rh = rehash_fn.args[0];
    # Allocas for inner-loop state
    ok_a = brh.alloca(key_type, name="ok");
    ov_a = brh.alloca(val_type, name="ov");
    nh2_a = brh.alloca(i8, name="nh2");
    rslot_a = brh.alloca(i64, name="rsl");
    si_a = brh.alloca(i64, name="si");
    # Load old fields
    cap_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp");
    keys_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp");
    vals_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp");
    ctrl_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp");
    len_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp");
    used_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 5)], name="up");
    old_cap = brh.load(cap_prh, name="ocap");
    old_keys = brh.load(keys_prh, name="okeys");
    old_vals = brh.load(vals_prh, name="ovals");
    old_ctrl = brh.load(ctrl_prh, name="octrl");
    new_cap = brh.mul(old_cap, ir.Constant(i64, 2), name="ncap");
    new_mask = brh.sub(new_cap, ir.Constant(i64, 1), name="nmask");
    # Allocate new arrays
    kgnr = brh.gep(
        ir.Constant(key_type.as_pointer(), None), [ir.Constant(i32, 1)], name="ksz"
    );
    kszr = brh.ptrtoint(kgnr, i64, name="ksz");
    kbrh = brh.mul(new_cap, kszr, name="kb");
    nkr = brh.call(malloc_fn, [kbrh], name="nkr");
    new_keys = brh.bitcast(nkr, key_type.as_pointer(), name="nk");
    vgnr = brh.gep(
        ir.Constant(val_type.as_pointer(), None), [ir.Constant(i32, 1)], name="vsz"
    );
    vszr = brh.ptrtoint(vgnr, i64, name="vsz");
    vbrh = brh.mul(new_cap, vszr, name="vb");
    nvr = brh.call(malloc_fn, [vbrh], name="nvr");
    new_vals = brh.bitcast(nvr, val_type.as_pointer(), name="nv");
    ncr = brh.call(calloc_fn, [new_cap, ir.Constant(i64, 1)], name="ncr");
    # Install new arrays into struct; reset len=0, used=0
    brh.store(new_cap, cap_prh);
    brh.store(new_keys, keys_prh);
    brh.store(new_vals, vals_prh);
    brh.store(ncr, ctrl_prh);
    brh.store(ir.Constant(i64, 0), len_prh);
    brh.store(ir.Constant(i64, 0), used_prh);
    brh.store(ir.Constant(i64, 0), si_a);
    # Outer loop: iterate over old slots
    rl_bb = rehash_fn.append_basic_block("rl");
    rc_bb = rehash_fn.append_basic_block("rc");
    rn_bb = rehash_fn.append_basic_block("rn");
    ri_bb = rehash_fn.append_basic_block("ri");
    rp_bb = rehash_fn.append_basic_block("rp");
    ra_bb = rehash_fn.append_basic_block("ra");
    rd_bb = rehash_fn.append_basic_block("rd");
    rf_bb = rehash_fn.append_basic_block("rf");
    brh.branch(rl_bb);
    # rl: check si vs old_cap
    brl = ir.IRBuilder(rl_bb);
    si_rh = brl.load(si_a, name="si");
    rend = brl.icmp_unsigned(">=", si_rh, old_cap, name="rend");
    brl.cbranch(rend, rf_bb, rc_bb);
    # rc: check if occupied (ctrl >= 0x80)
    brc = ir.IRBuilder(rc_bb);
    ocbp = brc.gep(old_ctrl, [si_rh], name="ocbp");
    ocb = brc.load(ocbp, name="ocb");
    is_occ = brc.icmp_unsigned(">=", ocb, ir.Constant(i8, 0x80), name="occ");
    brc.cbranch(is_occ, ri_bb, rn_bb);
    # rn: advance si
    brn = ir.IRBuilder(rn_bb);
    brn.store(brn.add(si_rh, ir.Constant(i64, 1), name="nsi"), si_a);
    brn.branch(rl_bb);
    # ri: load old key/val, compute fingerprint, store in allocas
    bri = ir.IRBuilder(ri_bb);
    okp = bri.gep(old_keys, [si_rh], name="okp");
    ovp = bri.gep(old_vals, [si_rh], name="ovp");
    ok_v = bri.load(okp, name="ok");
    ov_v = bri.load(ovp, name="ov");
    bri.store(ok_v, ok_a);
    bri.store(ov_v, ov_a);
    nhr = bri.call(hash_fn, [ok_v], name="nh");
    nh2r0 = bri.lshr(nhr, ir.Constant(i64, 57), name="nh2r");
    nh2r7 = bri.and_(nh2r0, ir.Constant(i64, 0x7F), name="nh27");
    nh2ro = bri.or_(nh2r7, ir.Constant(i64, 0x80), name="nh2o");
    nh2 = bri.trunc(nh2ro, i8, name="nh2");
    bri.store(nh2, nh2_a);
    bri.store(bri.and_(nhr, new_mask, name="rs0"), rslot_a);
    bri.branch(rp_bb);
    # rp: probe new table for empty slot (no tombstones after fresh alloc)
    brp = ir.IRBuilder(rp_bb);
    rsl = brp.load(rslot_a, name="rsl");
    ncp = brp.gep(ncr, [rsl], name="ncp");
    nc = brp.load(ncp, name="nc");
    rse = brp.icmp_unsigned("==", nc, ir.Constant(i8, CTRL_EMPTY), name="rse");
    brp.cbranch(rse, rd_bb, ra_bb);
    # ra: advance probe slot
    bra = ir.IRBuilder(ra_bb);
    nrsl = bra.add(rsl, ir.Constant(i64, 1), name="nrsl");
    bra.store(bra.and_(nrsl, new_mask, name="nrslm"), rslot_a);
    bra.branch(rp_bb);
    # rd: insert at rsl (no RC retain — moving existing refs)
    brd = ir.IRBuilder(rd_bb);
    ok_d = brd.load(ok_a, name="ok");
    ov_d = brd.load(ov_a, name="ov");
    nh2_d = brd.load(nh2_a, name="nh2");
    brd.store(ok_d, brd.gep(new_keys, [rsl], name="nkp"));
    brd.store(ov_d, brd.gep(new_vals, [rsl], name="nvp"));
    brd.store(nh2_d, brd.gep(ncr, [rsl], name="ncp2"));
    cl_d = brd.load(len_prh, name="cl");
    brd.store(brd.add(cl_d, ir.Constant(i64, 1), name="nl"), len_prh);
    cu_d = brd.load(used_prh, name="cu");
    brd.store(brd.add(cu_d, ir.Constant(i64, 1), name="nu"), used_prh);
    brd.store(
        brd.add(brd.load(si_a, name="si2"), ir.Constant(i64, 1), name="nsi2"), si_a
    );
    brd.branch(rl_bb);
    # rf: free old arrays and return
    brf = ir.IRBuilder(rf_bb);
    brf.call(self.rc_safe_free_fn, [brf.bitcast(old_keys, i8p, name="oki8")]);
    brf.call(self.rc_safe_free_fn, [brf.bitcast(old_vals, i8p, name="ovi8")]);
    brf.call(self.rc_safe_free_fn, [old_ctrl]);
    brf.ret_void();

    # =========================================================================
    # E. __dict_set_K_V — insert or update key→val.
    #    Uses find_fn for the probe; calls rehash_fn if load factor >= 75%.
    # =========================================================================
    set_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type, key_type, val_type]);
    set_fn = ir.Function(
        self.llvm_module, set_fnty, name=f"__dict_set_{key_type_name}_{val_type_name}"
    );
    set_fn.linkage = "private";
    set_fn.args[0].name = "dict";
    set_fn.args[1].name = "key";
    set_fn.args[2].name = "val";
    bs = ir.IRBuilder(set_fn.append_basic_block("entry"));
    d_s = set_fn.args[0];
    k_s = set_fn.args[1];
    v_s = set_fn.args[2];
    res_s = bs.call(find_fn, [d_s, k_s], name="res");
    is_fnd = bs.icmp_signed(">=", res_s, ir.Constant(i64, 0), name="found");
    upd_bb = set_fn.append_basic_block("upd");
    ins_bb = set_fn.append_basic_block("ins");
    reh_bb = set_fn.append_basic_block("reh");
    done_s = set_fn.append_basic_block("done");
    bs.cbranch(is_fnd, upd_bb, ins_bb);
    # upd: update existing val at res_s (retain new, release old)
    bu = ir.IRBuilder(upd_bb);
    vals_as = bu.load(
        bu.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"), name="va"
    );
    vsp = bu.gep(vals_as, [res_s], name="vsp");
    if isinstance(val_type, ir.PointerType) {
        bu.call(self.rc_retain_fn, [bu.bitcast(v_s, i8p, name="nvc")]);
        ov_u = bu.load(vsp, name="ov");
        bu.store(v_s, vsp);
        bu.call(self.rc_release_simple_fn, [bu.bitcast(ov_u, i8p, name="ovc")]);
    } else {
        bu.store(v_s, vsp);
    }
    bu.ret_void();
    # ins: insert new entry at ~res_s
    bi = ir.IRBuilder(ins_bb);
    isl = bi.xor(res_s, ir.Constant(i64, -1), name="isl");
    # Recompute fingerprint for the insert slot
    h_s = bi.call(hash_fn, [k_s], name="h");
    h2r_s = bi.lshr(h_s, ir.Constant(i64, 57), name="h2r");
    h27_s = bi.and_(h2r_s, ir.Constant(i64, 0x7F), name="h27");
    h2o_s = bi.or_(h27_s, ir.Constant(i64, 0x80), name="h2o");
    h2_s = bi.trunc(h2o_s, i8, name="h2");
    # Load struct field pointers
    len_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lrp");
    keys_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="krp");
    vals_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vrp");
    ctrl_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="crp");
    used_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 5)], name="urp");
    cap_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="carp");
    ka_s = bi.load(keys_rp, name="ka");
    va_s = bi.load(vals_rp, name="va");
    ca_s = bi.load(ctrl_rp, name="ca");
    # Check if insert slot was TOMBSTONE (ctrl==1) — used stays unchanged for reuse
    icp = bi.gep(ca_s, [isl], name="icp");
    icb = bi.load(icp, name="icb");
    was_tb = bi.icmp_unsigned("==", icb, ir.Constant(i8, CTRL_TOMBSTONE), name="wt");
    # RC retain new key and val (new entry takes ownership)
    if isinstance(key_type, ir.PointerType) {
        bi.call(self.rc_retain_fn, [bi.bitcast(k_s, i8p, name="kc")]);
    }
    if isinstance(val_type, ir.PointerType) {
        bi.call(self.rc_retain_fn, [bi.bitcast(v_s, i8p, name="vc")]);
    }
    bi.store(k_s, bi.gep(ka_s, [isl], name="ksp"));
    bi.store(v_s, bi.gep(va_s, [isl], name="vsp"));
    bi.store(h2_s, icp);
    # len++ always
    cl_s = bi.load(len_rp, name="cl");
    bi.store(bi.add(cl_s, ir.Constant(i64, 1), name="nl"), len_rp);
    # used++ only when slot was EMPTY (not tombstone reuse)
    ntb = bi.not_(was_tb, name="ntb");
    cu_s = bi.load(used_rp, name="cu");
    nu_s = bi.add(cu_s, bi.zext(ntb, i64, name="ntbx"), name="nu");
    bi.store(nu_s, used_rp);
    # Rehash if used*4 > cap*3  (75% load factor)
    cc_s = bi.load(cap_rp, name="cc");
    u4 = bi.mul(nu_s, ir.Constant(i64, 4), name="u4");
    c3 = bi.mul(cc_s, ir.Constant(i64, 3), name="c3");
    nreh = bi.icmp_unsigned(">", u4, c3, name="nreh");
    bi.cbranch(nreh, reh_bb, done_s);
    # reh: grow the table
    breh = ir.IRBuilder(reh_bb);
    breh.call(rehash_fn, [d_s]);
    breh.branch(done_s);
    ir.IRBuilder(done_s).ret_void();

    # =========================================================================
    # F. __dict_get_K_V — lookup key, return value or zero/null if missing.
    # =========================================================================
    get_fnty = ir.FunctionType(val_type, [dict_ptr_type, key_type]);
    get_fn = ir.Function(
        self.llvm_module, get_fnty, name=f"__dict_get_{key_type_name}_{val_type_name}"
    );
    get_fn.linkage = "private";
    get_fn.args[0].name = "dict";
    get_fn.args[1].name = "key";
    bg = ir.IRBuilder(get_fn.append_basic_block("entry"));
    res_g = bg.call(find_fn, [get_fn.args[0], get_fn.args[1]], name="res");
    fnd_g = bg.icmp_signed(">=", res_g, ir.Constant(i64, 0), name="found");
    got_bb = get_fn.append_basic_block("got");
    miss_bb = get_fn.append_basic_block("miss");
    bg.cbranch(fnd_g, got_bb, miss_bb);
    bgg = ir.IRBuilder(got_bb);
    va_g = bgg.load(
        bgg.gep(get_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"),
        name="va"
    );
    bgg.ret(bgg.load(bgg.gep(va_g, [res_g], name="vsp"), name="v"));
    bmi = ir.IRBuilder(miss_bb);
    if isinstance(val_type, ir.PointerType) {
        bmi.ret(ir.Constant(val_type, None));
    } elif val_type?.elements and val_type.elements {
        bmi.ret(ir.Constant(val_type, [ir.Constant(e, 0) for e in val_type.elements]));
    } else {
        bmi.ret(ir.Constant(val_type, 0));
    }

    # =========================================================================
    # G. __dict_contains_K_V — return i1: 1 if key present, 0 if not.
    # =========================================================================
    contains_fnty = ir.FunctionType(i1, [dict_ptr_type, key_type]);
    contains_fn = ir.Function(
        self.llvm_module,
        contains_fnty,
        name=f"__dict_contains_{key_type_name}_{val_type_name}"
    );
    contains_fn.linkage = "private";
    contains_fn.args[0].name = "dict";
    contains_fn.args[1].name = "key";
    bc = ir.IRBuilder(contains_fn.append_basic_block("entry"));
    res_c = bc.call(find_fn, [contains_fn.args[0], contains_fn.args[1]], name="res");
    bc.ret(bc.icmp_signed(">=", res_c, ir.Constant(i64, 0), name="found"));

    # =========================================================================
    # H. __dict_remove_K_V — tombstone-delete a key (used by del/remove).
    #    Decrements len; does NOT change used (tombstone persists until rehash).
    #    RC-releases both key and val.  No-op when key not present.
    # =========================================================================
    remove_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type, key_type]);
    remove_fn = ir.Function(
        self.llvm_module,
        remove_fnty,
        name=f"__dict_remove_{key_type_name}_{val_type_name}"
    );
    remove_fn.linkage = "private";
    remove_fn.args[0].name = "dict";
    remove_fn.args[1].name = "key";
    brm = ir.IRBuilder(remove_fn.append_basic_block("entry"));
    d_rm = remove_fn.args[0];
    k_rm = remove_fn.args[1];
    res_rm = brm.call(find_fn, [d_rm, k_rm], name="res");
    fnd_rm = brm.icmp_signed(">=", res_rm, ir.Constant(i64, 0), name="found");
    del_bb = remove_fn.append_basic_block("del");
    done_rm = remove_fn.append_basic_block("done");
    brm.cbranch(fnd_rm, del_bb, done_rm);
    bdel = ir.IRBuilder(del_bb);
    ka_rm = bdel.load(
        bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"), name="ka"
    );
    va_rm = bdel.load(
        bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"), name="va"
    );
    ca_rm = bdel.load(
        bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"),
        name="ca"
    );
    lp_rm = bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp");
    if isinstance(key_type, ir.PointerType) {
        kv_rm = bdel.load(bdel.gep(ka_rm, [res_rm], name="kvp"), name="kv");
        bdel.call(self.rc_release_simple_fn, [bdel.bitcast(kv_rm, i8p, name="kc")]);
        # Null out dead key slot — prevents stale/dangling pointer in tombstone
        bdel.store(
            ir.Constant(key_type, None), bdel.gep(ka_rm, [res_rm], name="kclear")
        );
    }
    if isinstance(val_type, ir.PointerType) {
        vv_rm = bdel.load(bdel.gep(va_rm, [res_rm], name="vvp"), name="vv");
        bdel.call(self.rc_release_simple_fn, [bdel.bitcast(vv_rm, i8p, name="vc")]);
        # Null out dead val slot — prevents stale/dangling pointer in tombstone
        bdel.store(
            ir.Constant(val_type, None), bdel.gep(va_rm, [res_rm], name="vclear")
        );
    }
    bdel.store(ir.Constant(i8, CTRL_TOMBSTONE), bdel.gep(ca_rm, [res_rm], name="csp"));
    cl_rm = bdel.load(lp_rm, name="cl");
    bdel.store(bdel.sub(cl_rm, ir.Constant(i64, 1), name="nl"), lp_rm);
    bdel.branch(done_rm);
    ir.IRBuilder(done_rm).ret_void();

    # =========================================================================
    # I. __dict_pop_K_V — tombstone-delete and return the value.
    #    Caller takes ownership of the returned val (no RC release on val).
    #    RC-releases the key.  Returns zero/null when key not present.
    # =========================================================================
    pop_fnty = ir.FunctionType(val_type, [dict_ptr_type, key_type]);
    pop_fn = ir.Function(
        self.llvm_module, pop_fnty, name=f"__dict_pop_{key_type_name}_{val_type_name}"
    );
    pop_fn.linkage = "private";
    pop_fn.args[0].name = "dict";
    pop_fn.args[1].name = "key";
    bpop = ir.IRBuilder(pop_fn.append_basic_block("entry"));
    d_pop = pop_fn.args[0];
    k_pop = pop_fn.args[1];
    res_p = bpop.call(find_fn, [d_pop, k_pop], name="res");
    fnd_p = bpop.icmp_signed(">=", res_p, ir.Constant(i64, 0), name="found");
    del_p = pop_fn.append_basic_block("del");
    miss_p = pop_fn.append_basic_block("miss");
    bpop.cbranch(fnd_p, del_p, miss_p);
    bdp = ir.IRBuilder(del_p);
    ka_p = bdp.load(
        bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"), name="ka"
    );
    va_p = bdp.load(
        bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"), name="va"
    );
    ca_p = bdp.load(
        bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"),
        name="ca"
    );
    lp_p = bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp");
    v_out = bdp.load(bdp.gep(va_p, [res_p], name="vsp"), name="v");  # save val first
    # Ownership transfer: clear the val slot so the destructor won't double-release.
    if isinstance(val_type, ir.PointerType) {
        bdp.store(ir.Constant(val_type, None), bdp.gep(va_p, [res_p], name="vclear"));
    }
    if isinstance(key_type, ir.PointerType) {
        kv_p = bdp.load(bdp.gep(ka_p, [res_p], name="kvp"), name="kv");
        bdp.call(self.rc_release_simple_fn, [bdp.bitcast(kv_p, i8p, name="kc")]);
        bdp.store(ir.Constant(key_type, None), bdp.gep(ka_p, [res_p], name="kclear"));
    }
    bdp.store(ir.Constant(i8, CTRL_TOMBSTONE), bdp.gep(ca_p, [res_p], name="csp"));
    cl_p = bdp.load(lp_p, name="cl");
    bdp.store(bdp.sub(cl_p, ir.Constant(i64, 1), name="nl"), lp_p);
    bdp.ret(v_out);  # caller owns the value
    bmp = ir.IRBuilder(miss_p);
    if isinstance(val_type, ir.PointerType) {
        bmp.ret(ir.Constant(val_type, None));
    } elif val_type?.elements and val_type.elements {
        bmp.ret(ir.Constant(val_type, [ir.Constant(e, 0) for e in val_type.elements]));
    } else {
        bmp.ret(ir.Constant(val_type, 0));
    }

    # =========================================================================
    # J. __dict_len_K_V — return live entry count (field 0).
    # =========================================================================
    len_fn = self._emit_container_len_fn(
        f"__dict_len_{key_type_name}_{val_type_name}", dict_ptr_type
    );

    # =========================================================================
    # K. __dict_get_key_K_V / __dict_get_val_K_V
    #    Return the i-th live key/val by scanning ctrl bytes (O(cap)).
    #    Only used for dict iteration — not the hot path.
    # =========================================================================
    get_key_fnty = ir.FunctionType(key_type, [dict_ptr_type, i64]);
    get_key_fn = ir.Function(
        self.llvm_module,
        get_key_fnty,
        name=f"__dict_get_key_{key_type_name}_{val_type_name}"
    );
    get_key_fn.linkage = "private";
    get_key_fn.args[0].name = "dict";
    get_key_fn.args[1].name = "i";
    bgk = ir.IRBuilder(get_key_fn.append_basic_block("entry"));
    cnt_a = bgk.alloca(i64, name="cnt");
    sl_a = bgk.alloca(i64, name="sl");
    bgk.store(ir.Constant(i64, 0), cnt_a);
    bgk.store(ir.Constant(i64, 0), sl_a);
    d_gk = get_key_fn.args[0];
    tgt_gk = get_key_fn.args[1];
    cap_gk = bgk.load(
        bgk.gep(d_gk, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp"), name="cap"
    );
    keys_gk = bgk.load(
        bgk.gep(d_gk, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"),
        name="keys"
    );
    ctrl_gk = bgk.load(
        bgk.gep(d_gk, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"),
        name="ctrl"
    );
    lp_bb = get_key_fn.append_basic_block("lp");
    chk_bb = get_key_fn.append_basic_block("chk");
    occ_bb = get_key_fn.append_basic_block("occ");
    cnt_bb = get_key_fn.append_basic_block("cnt");
    ret_bb = get_key_fn.append_basic_block("ret");
    nxt_bb = get_key_fn.append_basic_block("nxt");
    oob_bb = get_key_fn.append_basic_block("oob");
    bgk.branch(lp_bb);
    blp = ir.IRBuilder(lp_bb);
    sl = blp.load(sl_a, name="sl");
    blp.cbranch(blp.icmp_unsigned(">=", sl, cap_gk, name="end"), oob_bb, chk_bb);
    bchk = ir.IRBuilder(chk_bb);
    cb_gk = bchk.load(bchk.gep(ctrl_gk, [sl], name="cbp"), name="cb");
    bchk.cbranch(
        bchk.icmp_unsigned(">=", cb_gk, ir.Constant(i8, 0x80), name="occ"),
        occ_bb,
        nxt_bb
    );
    bocc = ir.IRBuilder(occ_bb);
    cnt = bocc.load(cnt_a, name="cnt");
    bocc.cbranch(bocc.icmp_unsigned("==", cnt, tgt_gk, name="match"), ret_bb, cnt_bb);
    bret = ir.IRBuilder(ret_bb);
    bret.ret(bret.load(bret.gep(keys_gk, [sl], name="kp"), name="k"));
    bcnt = ir.IRBuilder(cnt_bb);
    bcnt.store(bcnt.add(cnt, ir.Constant(i64, 1), name="nc"), cnt_a);
    bcnt.branch(nxt_bb);
    bnxt = ir.IRBuilder(nxt_bb);
    bnxt.store(bnxt.add(sl, ir.Constant(i64, 1), name="nsl"), sl_a);
    bnxt.branch(lp_bb);
    boob = ir.IRBuilder(oob_bb);
    if isinstance(key_type, ir.PointerType) {
        boob.ret(ir.Constant(key_type, None));
    } else {
        boob.ret(ir.Constant(key_type, 0));
    }

    get_val_fnty = ir.FunctionType(val_type, [dict_ptr_type, i64]);
    get_val_fn = ir.Function(
        self.llvm_module,
        get_val_fnty,
        name=f"__dict_get_val_{key_type_name}_{val_type_name}"
    );
    get_val_fn.linkage = "private";
    get_val_fn.args[0].name = "dict";
    get_val_fn.args[1].name = "i";
    bgv = ir.IRBuilder(get_val_fn.append_basic_block("entry"));
    cnt_av = bgv.alloca(i64, name="cnt");
    sl_av = bgv.alloca(i64, name="sl");
    bgv.store(ir.Constant(i64, 0), cnt_av);
    bgv.store(ir.Constant(i64, 0), sl_av);
    d_gv = get_val_fn.args[0];
    tgt_gv = get_val_fn.args[1];
    cap_gv = bgv.load(
        bgv.gep(d_gv, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp"), name="cap"
    );
    vals_gv = bgv.load(
        bgv.gep(d_gv, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"),
        name="vals"
    );
    ctrl_gv = bgv.load(
        bgv.gep(d_gv, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"),
        name="ctrl"
    );
    vlp_bb = get_val_fn.append_basic_block("lp");
    vchk_bb = get_val_fn.append_basic_block("chk");
    vocc_bb = get_val_fn.append_basic_block("occ");
    vcnt_bb = get_val_fn.append_basic_block("cnt");
    vret_bb = get_val_fn.append_basic_block("ret");
    vnxt_bb = get_val_fn.append_basic_block("nxt");
    voob_bb = get_val_fn.append_basic_block("oob");
    bgv.branch(vlp_bb);
    bvlp = ir.IRBuilder(vlp_bb);
    slv = bvlp.load(sl_av, name="sl");
    bvlp.cbranch(bvlp.icmp_unsigned(">=", slv, cap_gv, name="end"), voob_bb, vchk_bb);
    bvchk = ir.IRBuilder(vchk_bb);
    cb_gv = bvchk.load(bvchk.gep(ctrl_gv, [slv], name="cbp"), name="cb");
    bvchk.cbranch(
        bvchk.icmp_unsigned(">=", cb_gv, ir.Constant(i8, 0x80), name="occ"),
        vocc_bb,
        vnxt_bb
    );
    bvocc = ir.IRBuilder(vocc_bb);
    cntv = bvocc.load(cnt_av, name="cnt");
    bvocc.cbranch(
        bvocc.icmp_unsigned("==", cntv, tgt_gv, name="match"), vret_bb, vcnt_bb
    );
    bvret = ir.IRBuilder(vret_bb);
    bvret.ret(bvret.load(bvret.gep(vals_gv, [slv], name="vp"), name="v"));
    bvcnt = ir.IRBuilder(vcnt_bb);
    bvcnt.store(bvcnt.add(cntv, ir.Constant(i64, 1), name="nc"), cnt_av);
    bvcnt.branch(vnxt_bb);
    bvnxt = ir.IRBuilder(vnxt_bb);
    bvnxt.store(bvnxt.add(slv, ir.Constant(i64, 1), name="nsl"), sl_av);
    bvnxt.branch(vlp_bb);
    bvoob = ir.IRBuilder(voob_bb);
    if isinstance(val_type, ir.PointerType) {
        bvoob.ret(ir.Constant(val_type, None));
    } elif val_type?.elements and val_type.elements {
        bvoob.ret(
            ir.Constant(val_type, [ir.Constant(e, 0) for e in val_type.elements])
        );
    } else {
        bvoob.ret(ir.Constant(val_type, 0));
    }

    # =========================================================================
    # L. __rc_release_dict_K_V — custom destructor.
    #    Iterates ctrl bytes; RC-releases key/val for each OCCUPIED slot.
    #    Frees keys, vals, ctrl arrays.  Then frees the container struct.
    # =========================================================================
    rel_fnty2 = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
    try {
        _ex = self.llvm_module.get_global(_rel_fn_name);
        if isinstance(_ex, ir.Function) and not _ex.blocks {
            release_fn = _ex;
            release_fn.linkage = "private";
        } else {
            release_fn = ir.Function(self.llvm_module, rel_fnty2, name=_rel_fn_name);
            release_fn.linkage = "private";
        }
    } except KeyError {
        release_fn = ir.Function(self.llvm_module, rel_fnty2, name=_rel_fn_name);
        release_fn.linkage = "private";
    }
    release_fn.args[0].name = "dict";
    (brel, done_rel_bb) = self._emit_rc_destructor_preamble(release_fn, dict_ptr_type);
    d_rel = release_fn.args[0];
    cap_rel = brel.load(
        brel.gep(d_rel, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp"),
        name="cap"
    );
    keys_rel = brel.load(
        brel.gep(d_rel, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"),
        name="keys"
    );
    vals_rel = brel.load(
        brel.gep(d_rel, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"),
        name="vals"
    );
    ctrl_rel = brel.load(
        brel.gep(d_rel, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"),
        name="ctrl"
    );
    need_kv = (
        isinstance(key_type, ir.PointerType) or isinstance(val_type, ir.PointerType)
    );
    if need_kv {
        si_ra = brel.alloca(i64, name="si");
        brel.store(ir.Constant(i64, 0), si_ra);
        rlp_bb = release_fn.append_basic_block("rlp");
        rchk_bb = release_fn.append_basic_block("rchk");
        rkv_bb = release_fn.append_basic_block("rkv");
        rnx_bb = release_fn.append_basic_block("rnx");
        rarr_bb = release_fn.append_basic_block("rarr");
        brel.branch(rlp_bb);
        brlp = ir.IRBuilder(rlp_bb);
        si_r = brlp.load(si_ra, name="si");
        brlp.cbranch(
            brlp.icmp_unsigned(">=", si_r, cap_rel, name="end"), rarr_bb, rchk_bb
        );
        brchk = ir.IRBuilder(rchk_bb);
        cb_r = brchk.load(brchk.gep(ctrl_rel, [si_r], name="cbp"), name="cb");
        brchk.cbranch(
            brchk.icmp_unsigned(">=", cb_r, ir.Constant(i8, 0x80), name="occ"),
            rkv_bb,
            rnx_bb
        );
        brkv = ir.IRBuilder(rkv_bb);
        if isinstance(key_type, ir.PointerType) {
            kv_r = brkv.load(brkv.gep(keys_rel, [si_r], name="kvp"), name="kv");
            brkv.call(self.rc_release_simple_fn, [brkv.bitcast(kv_r, i8p, name="kc")]);
        }
        if isinstance(val_type, ir.PointerType) {
            vv_r = brkv.load(brkv.gep(vals_rel, [si_r], name="vvp"), name="vv");
            brkv.call(self.rc_release_simple_fn, [brkv.bitcast(vv_r, i8p, name="vc")]);
        }
        brkv.branch(rnx_bb);
        brnx = ir.IRBuilder(rnx_bb);
        brnx.store(brnx.add(si_r, ir.Constant(i64, 1), name="nsi"), si_ra);
        brnx.branch(rlp_bb);
        brra = ir.IRBuilder(rarr_bb);
    } else {
        rarr_bb = release_fn.append_basic_block("rarr");
        brel.branch(rarr_bb);
        brra = ir.IRBuilder(rarr_bb);
    }
    brra.call(self.rc_safe_free_fn, [brra.bitcast(keys_rel, i8p, name="ki8")]);
    brra.call(self.rc_safe_free_fn, [brra.bitcast(vals_rel, i8p, name="vi8")]);
    brra.call(self.rc_safe_free_fn, [ctrl_rel]);
    # Remove from live-objects list, log, then free container struct
    _i8pc = i8p;
    _i64c = i64;
    _i64pc = _i64c.as_pointer();
    _ci8 = brra.bitcast(d_rel, _i8pc, name="ci8");
    _craw = brra.gep(_ci8, [ir.Constant(_i64c, -32)], name="cr");
    _captr = brra.bitcast(_craw, _i64pc, name="cap");
    _car = brra.load(_captr, name="car");
    _ca = brra.and_(_car, ir.Constant(_i64c, 4294967295), name="ca");
    _ctr = brra.gep(_ci8, [ir.Constant(_i64c, -24)], name="ctr");
    _ctpp = brra.bitcast(_ctr, _i8pc.as_pointer(), name="ctpp");
    _ct = brra.load(_ctpp, name="ct");
    lfb = release_fn.append_basic_block("lfb");
    afb = release_fn.append_basic_block("afb");
    self._emit_live_list_remove(brra, _ci8, _i8pc, _i64pc, lfb, lfb);
    self._emit_struct_free_log(release_fn, lfb, afb, _ci8, _craw, _ca, _ct);
    baf = ir.IRBuilder(afb);
    baf.call(self.rc_safe_free_fn, [_craw]);
    baf.branch(done_rel_bb);
    ir.IRBuilder(done_rel_bb).ret_void();
    self.dict_release_fns[dict_key] = release_fn;

    # =========================================================================
    # Store helpers — same external interface as before + new "remove"/"pop"/"find"
    # =========================================================================
    self.dict_helpers[dict_key] = {
        "new": new_fn,
        "set": set_fn,
        "get": get_fn,
        "len": len_fn,
        "contains": contains_fn,
        "get_key": get_key_fn,
        "get_val": get_val_fn,
        "remove": remove_fn,
        "pop": pop_fn,
        "find": find_fn,
        "key_type": key_type,
        "val_type": val_type
    };
}

"""Box any value into a JacVal tagged union {i8 tag, i64 payload}.

Tag 0 = int (i64 stored directly)
Tag 1 = float (f64 bitcast to i64)
Tag 2 = str (i8* ptrtoint to i64)
Tag 3 = list pointer (any List.T* ptrtoint to i64)
Tag 4 = dict pointer (any Dict.K:V* ptrtoint to i64)
Tag 5 = set pointer  (any Set.T* ptrtoint to i64)
"""
impl NaIRGenPass._box_to_jacval(value: ir.Value) -> ir.Value {
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    jv_alloca = self._entry_alloca(self.jacval_type, "jacval");
    tag_ptr = b.gep(
        jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="jv.tag.ptr"
    );
    payload_ptr = b.gep(
        jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="jv.payload.ptr"
    );
    if isinstance(value.type, ir.IntType) and value.type.width == 1 {
        # bool (i1) → box as int (tag 0) via zero-extension
        b.store(ir.Constant(i8, 0), tag_ptr);
        ext = b.zext(value, i64, name="jv.bext");
        b.store(ext, payload_ptr);
    } elif isinstance(value.type, ir.IntType) {
        # Any integer width → sign-extend to i64, tag 0.
        # Must use sext (not zext) so negative values like i32(-1) → 0xFFFFFFFFFFFFFFFF.
        b.store(ir.Constant(i8, 0), tag_ptr);
        if value.type.width == 64 {
            b.store(value, payload_ptr);
        } else {
            b.store(b.sext(value, i64, name="jv.iext"), payload_ptr);
        }
    } elif isinstance(value.type, ir.DoubleType) {
        # float → bitcast f64 to i64, tag 1
        b.store(ir.Constant(i8, 1), tag_ptr);
        payload = b.bitcast(value, i64, name="jv.f2i");
        b.store(payload, payload_ptr);
    } elif isinstance(value.type, ir.PointerType) {
        # Determine whether this is a list, dict, set, or plain string pointer.
        ptr_tag = 2;  # default: str (tag 2)
        for (_, ltype) in self.list_types.items() {
            if value.type == ltype.as_pointer() {
                ptr_tag = 3;
                break;
            }
        }
        if ptr_tag == 2 {
            for (_, dtype) in self.dict_types.items() {
                if value.type == dtype.as_pointer() {
                    ptr_tag = 4;
                    break;
                }
            }
        }
        if ptr_tag == 2 {
            for (_, stype) in self.set_types.items() {
                if value.type == stype.as_pointer() {
                    ptr_tag = 5;
                    break;
                }
            }
        }
        b.store(ir.Constant(i8, ptr_tag), tag_ptr);
        payload = b.ptrtoint(value, i64, name="jv.p2i");
        b.store(payload, payload_ptr);
    } else {
        # Unknown type: store zero int
        b.store(ir.Constant(i8, 0), tag_ptr);
        b.store(ir.Constant(i64, 0), payload_ptr);
    }
    return b.load(jv_alloca, name="jacval");
}

"""Generate code for a dict literal {k1: v1, k2: v2, ...}."""
impl NaIRGenPass._codegen_dict_val(nd: uni.DictVal) -> (ir.Value | None) {
    if not nd.kv_pairs {
        # Empty dict: need type hint
        return None;
    }
    # Get first key-value pair to determine types
    first_pair = nd.kv_pairs[0];
    first_key = self._codegen_expr(first_pair.key);
    first_val = self._codegen_expr(first_pair.value);
    if first_key is None or first_val is None {
        return None;
    }
    # Check if we should box values into JacVal (dict[str, any])
    use_jacval = self._dict_val_type_hint == "jacval";
    # Determine type names
    key_type = first_key.type;
    key_type_name = "i64";
    key_size = 0;
    if isinstance(key_type, ir.DoubleType) {
        key_type_name = "f64";
    } elif isinstance(key_type, ir.PointerType) {
        key_type_name = "ptr";
        # Check if key is a tuple (pointer to LiteralStructType)
        if isinstance(key_type.pointee, ir.LiteralStructType) {
            key_size = self._get_struct_size(key_type.pointee);
            key_type_name = f"tuple{key_size}";
        }
    }
    if use_jacval {
        val_type = self.jacval_type;
        val_type_name = "jacval";
    } else {
        val_type = first_val.type;
        val_type_name = "i64";
        if isinstance(val_type, ir.DoubleType) {
            val_type_name = "f64";
        } elif isinstance(val_type, ir.PointerType) {
            val_type_name = "ptr";
        }
    }
    dict_key = f"{key_type_name}:{val_type_name}";
    # Ensure helpers exist
    self._emit_dict_helpers(key_type_name, val_type_name, key_type, val_type, key_size);
    helpers = self.dict_helpers[dict_key];
    # Create new dict
    _dict_new_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    dict_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_dict_new_loc, name="dict.new"
    );
    self._mark_owned(dict_val);
    _dinit_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    # Add first pair (box if needed)
    first_store_val = self._box_to_jacval(first_val) if use_jacval else first_val;
    self._rc_call_with_ctx(
        helpers["set"],
        [dict_val, first_key, first_store_val],
        op="dict_init",
        loc=_dinit_loc
    );
    if isinstance(first_key.type, ir.PointerType) and self._is_owned(first_key) {
        self._emit_rc_release_simple(first_key, op="dict_init", loc=_dinit_loc);
    }
    if isinstance(first_val.type, ir.PointerType) and self._is_owned(first_val) {
        self._emit_rc_release_simple(first_val, op="dict_init", loc=_dinit_loc);
    }
    # Add remaining pairs
    for i in range(1, len(nd.kv_pairs)) {
        pair = nd.kv_pairs[i];
        k = self._codegen_expr(pair.key);
        v = self._codegen_expr(pair.value);
        if k is not None and v is not None {
            _orig_k = k;
            _orig_v = v;
            k = self._coerce_type(k, key_type);
            if use_jacval {
                v = self._box_to_jacval(v);
            } else {
                v = self._coerce_type(v, val_type);
            }
            self._rc_call_with_ctx(
                helpers["set"], [dict_val, k, v], op="dict_init", loc=_dinit_loc
            );
            if isinstance(_orig_k.type, ir.PointerType) and self._is_owned(_orig_k) {
                self._emit_rc_release_simple(_orig_k, op="dict_init", loc=_dinit_loc);
            }
            if isinstance(_orig_v.type, ir.PointerType) and self._is_owned(_orig_v) {
                self._emit_rc_release_simple(_orig_v, op="dict_init", loc=_dinit_loc);
            }
        }
    }
    self._mark_owned(dict_val);
    return dict_val;
}

"""Get value from dictionary by key (with KeyError check)."""
impl NaIRGenPass._codegen_dict_access(
    target_val: ir.Value, key_val: ir.Value, key_type_name: str, val_type_name: str
) -> (ir.Value | None) {
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return None;
    }
    key_type = helpers["key_type"];
    key_val = self._coerce_type(key_val, key_type);
    # KeyError: check if key exists before accessing
    key_exists = self.builder.call(
        helpers["contains"], [target_val, key_val], name="dict.has"
    );
    not_exists = self.builder.not_(key_exists, name="dict.nokey");
    self._emit_runtime_raise(not_exists, "KeyError", "key not found");
    return self.builder.call(helpers["get"], [target_val, key_val], name="dict.get");
}

"""Set value in dictionary by key."""
impl NaIRGenPass._codegen_dict_set(
    target_val: ir.Value,
    key_val: ir.Value,
    value: ir.Value,
    key_type_name: str,
    val_type_name: str
) -> None {
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return;
    }
    key_type = helpers["key_type"];
    val_type = helpers["val_type"];
    _orig_value = value;  # Save BEFORE potential coerce
    key_val = self._coerce_type(key_val, key_type);
    value = self._coerce_type(value, val_type);
    _dset_ctx_loc = getattr(
        _orig_value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
    );
    self._rc_call_with_ctx(
        helpers["set"], [target_val, key_val, value], op="dict_set", loc=_dset_ctx_loc
    );
    if isinstance(val_type, ir.PointerType) and self._is_owned(_orig_value) {
        _dset_loc = getattr(
            _orig_value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
        );
        self._emit_rc_release_simple(_orig_value, op="dict_set", loc=_dset_loc);
    }
}
