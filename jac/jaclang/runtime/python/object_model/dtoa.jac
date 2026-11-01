import from c {
    def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  obj Bigint {
        has next: ptr[Bigint],
            k: i32,
            maxwds: i32,
            sign: i32,
            wds: i32,
            x: u32;
    }  glob:priv dtoa_tens: list[f64] = [
             1e0,
             1e1,
             1e2,
             1e3,
             1e4,
             1e5,
             1e6,
             1e7,
             1e8,
             1e9,
             1e10,
             1e11,
             1e12,
             1e13,
             1e14,
             1e15,
             1e16,
             1e17,
             1e18,
             1e19,
             1e20,
             1e21,
             1e22
         ],
         dtoa_bigtens: list[f64] = [1e16, 1e32, 1e64, 1e128, 1e256],
         dtoa_tinytens: list[f64] = [
             1e-16,
             1e-32,
             1e-64,
             1e-128,
             8.112963841460668e-225
         ],
         dtoa_p05: list[i32] = [i32(5), i32(25), i32(125)]; def _Py_dg_strtod(
        s00: ptr[u8], se: ptr[ptr[u8]]
    ) -> f64 {
        rv: f64 = 0.0;
        start = s00;
        s = s00;
        c = s.view(1)[0];
        sign: i32 = 0;
        if c == CH_MINUS {
            sign = 1;
            s = s + 1;
            c = s.view(1)[0];
        } elif c == CH_PLUS {
            s = s + 1;
            c = s.view(1)[0];
        }

        s1 = s;
        while c == CH_0 {
            s = s + 1;
            c = s.view(1)[0];
        }
        lz = int(s) != int(s1);

        s0 = s;
        s1 = s;
        while c >= CH_0 and c <= CH_9 {
            s = s + 1;
            c = s.view(1)[0];
        }
        ndigits: i64 = int(s) - int(s1);
        fraclen: i64 = 0;

        if c == CH_DOT {
            s = s + 1;
            c = s.view(1)[0];
            if ndigits == 0 {
                s1 = s;
                while c == CH_0 {
                    s = s + 1;
                    c = s.view(1)[0];
                }
                lz = lz or int(s) != int(s1);
                fraclen += int(s) - int(s1);
                s0 = s;
            }
            s1 = s;
            while c >= CH_0 and c <= CH_9 {
                s = s + 1;
                c = s.view(1)[0];
            }
            ndigits += int(s) - int(s1);
            fraclen += int(s) - int(s1);
        }

        if ndigits == 0 and not lz {
            if se {
                se.view(1)[0] = start;
            }
            return 0.0;
        }

        if ndigits > MAX_DIGITS or fraclen > MAX_DIGITS {
            if se {
                se.view(1)[0] = start;
            }
            return 0.0;
        }
        nd = i32(ndigits);
        nd0 = i32(ndigits) - i32(fraclen);

        e: i32 = 0;
        if c == CH_LOWER_E or c == CH_UPPER_E {
            start = s;
            s = s + 1;
            c = s.view(1)[0];

            esign: i32 = 0;
            if c == CH_MINUS {
                esign = 1;
                s = s + 1;
                c = s.view(1)[0];
            } elif c == CH_PLUS {
                s = s + 1;
                c = s.view(1)[0];
            }

            s1 = s;
            while c == CH_0 {
                s = s + 1;
                c = s.view(1)[0];
            }
            lz = int(s) != int(s1);

            s1 = s;
            abs_exp: u32 = u32(0);
            while c >= CH_0 and c <= CH_9 {
                abs_exp = wrapping_add(
                    wrapping_mul(u32(10), abs_exp), u32(c) - u32(48)
                );
                s = s + 1;
                c = s.view(1)[0];
            }

            if int(s) - int(s1) > 9 or abs_exp > MAX_ABS_EXP {
                e = i32(MAX_ABS_EXP);
            } else {
                e = i32(abs_exp);
            }
            if esign != 0 {
                e = -e;
            }

            if int(s) == int(s1) and not lz {
                s = start;
            }
        }

        e -= nd - nd0;
        if nd0 <= 0 {
            nd0 = nd;
        }

        if se {
            se.view(1)[0] = s;
        }

        if nd == 0 {
            return strtod_signed(rv, sign);
        }
        i: i32 = nd;
        while i > 0 {
            i -= 1;
            if sig_digit(s0, i, nd0) != CH_0 {
                i += 1;
                break;
            }
        }
        e += nd - i;
        nd = i;
        if nd0 > nd {
            nd0 = nd;
        }

        bc_e0 = e;
        e1 = e;
        y: u32 = u32(0);
        z: u32 = u32(0);
        i = 0;
        while i < nd {
            if i < 9 {
                y = u32(10) * y + u32(sig_digit(s0, i, nd0)) - u32(48);
            } elif i < DBL_DIG + 1 {
                z = u32(10) * z + u32(sig_digit(s0, i, nd0)) - u32(48);
            } else {
                break;
            }
            i += 1;
        }

        k = nd if nd < DBL_DIG + 1 else DBL_DIG + 1;
        rv = f64(y);
        if k > 9 {
            rv = tens(k - 9) * rv + f64(z);
        }
        if nd <= DBL_DIG {
            if e == 0 {
                return strtod_signed(rv, sign);
            }
            if e > 0 {
                if e <= Ten_pmax {
                    rv *= tens(e);
                    return strtod_signed(rv, sign);
                }
                i = DBL_DIG - nd;
                if e <= Ten_pmax + i {
                    e -= i;
                    rv *= tens(i);
                    rv *= tens(e);
                    return strtod_signed(rv, sign);
                }
            } elif e >= -Ten_pmax {
                rv /= tens(-e);
                return strtod_signed(rv, sign);
            }
        }
        e1 += nd - k;

        bc_scale: i32 = 0;
        j: i32 = 0;

        if e1 > 0 {
            i = e1 & 15;
            if i != 0 {
                rv *= tens(i);
            }
            e1 = e1 - (e1 & 15);
            if e1 != 0 {
                if e1 > DBL_MAX_10_EXP {
                    return strtod_overflow(sign);
                }
                e1 = e1 >> 4;
                j = 0;
                while e1 > 1 {
                    if (e1 & 1) != 0 {
                        rv *= bigtens(j);
                    }
                    j += 1;
                    e1 = e1 >> 1;
                }
                rv = set_word0(rv, wrapping_sub(word0(rv), P_EXP));
                rv *= bigtens(j);
                zw = word0(rv) & Exp_mask;
                if zw > Exp_msk1 * u32(DBL_MAX_EXP + Bias - P) {
                    return strtod_overflow(sign);
                }
                if zw > Exp_msk1 * u32(DBL_MAX_EXP + Bias - 1 - P) {
                    rv = make_double(Big0, Big1);
                } else {
                    rv = set_word0(rv, wrapping_add(word0(rv), P_EXP));
                }
            }
        } elif e1 < 0 {
            e1 = -e1;
            i = e1 & 15;
            if i != 0 {
                rv /= tens(i);
            }
            e1 = e1 >> 4;
            if e1 != 0 {
                if e1 >= (1 << n_bigtens) {
                    return strtod_underflow(sign);
                }
                if (e1 & Scale_Bit) != 0 {
                    bc_scale = 2 * P;
                }
                j = 0;
                while e1 > 0 {
                    if (e1 & 1) != 0 {
                        rv *= tinytens(j);
                    }
                    j += 1;
                    e1 = e1 >> 1;
                }
                if bc_scale != 0 {
                    j = 2 * P + 1 - i32((word0(rv) & Exp_mask) >> Exp_shift);
                    if j > 0 {
                        if j >= 32 {
                            w0 = word0(rv);
                            if j >= 53 {
                                w0 = u32(P + 2) * Exp_msk1;
                            } else {
                                w0 = w0 & shl32(u32(0xffffffff), j - 32);
                            }
                            rv = make_double(w0, u32(0));
                        } else {
                            rv = make_double(
                                word0(rv), word1(rv) & shl32(u32(0xffffffff), j)
                            );
                        }
                    }
                }
                if rv == 0.0 {
                    return strtod_underflow(sign);
                }
            }
        }

        bc_nd = nd;
        bc_nd0 = nd0;
        if nd > STRTOD_DIGLIM {
            i = 18;
            while i > 0 {
                i -= 1;
                if sig_digit(s0, i, nd0) != CH_0 {
                    i += 1;
                    break;
                }
            }
            e += nd - i;
            nd = i;
            if nd0 > nd {
                nd0 = nd;
            }
            if nd < 9 {
                y = u32(0);
                i = 0;
                while i < nd0 {
                    y = u32(10) * y + u32((s0 + i).view(1)[0]) - u32(48);
                    i += 1;
                }
                while i < nd {
                    y = u32(10) * y + u32((s0 + i + 1).view(1)[0]) - u32(48);
                    i += 1;
                }
            }
        }
        bd0 = s2b(s0, nd0, nd, y);
        if not bd0 {
            jacpy_set_errno(ENOMEM);
            return -1.0;
        }

        bb = ptr[Bigint]();
        bd = ptr[Bigint]();
        bs = ptr[Bigint]();
        delta = ptr[Bigint]();
        outcome: i32 = STRTOD_OK;

        while True {
            bd = Balloc(bd0.view(1)[0].k);
            if not bd {
                outcome = STRTOD_NOMEM;
                break;
            }
            Bcopy(bd, bd0);
            (bb, bbe) = sd2b(rv, bc_scale);
            if not bb {
                outcome = STRTOD_NOMEM;
                break;
            }
            odd = digits_of(bb).view(1)[0] & u32(1);

            bs = i2b(1);
            if not bs {
                outcome = STRTOD_NOMEM;
                break;
            }

            bb2: i32 = 0;
            bb5: i32 = 0;
            bd2: i32 = 0;
            bd5: i32 = 0;
            if e >= 0 {
                bd2 = e;
                bd5 = e;
            } else {
                bb2 = -e;
                bb5 = -e;
            }
            if bbe >= 0 {
                bb2 += bbe;
            } else {
                bd2 -= bbe;
            }
            bs2 = bb2;
            bb2 += 1;
            bd2 += 1;

            i = bb2 if bb2 < bd2 else bd2;
            if i > bs2 {
                i = bs2;
            }
            if i > 0 {
                bb2 -= i;
                bd2 -= i;
                bs2 -= i;
            }

            if bb5 > 0 {
                bs = pow5mult(bs, bb5);
                if not bs {
                    outcome = STRTOD_NOMEM;
                    break;
                }
                bb1 = mult(bs, bb);
                Bfree(bb);
                bb = bb1;
                if not bb {
                    outcome = STRTOD_NOMEM;
                    break;
                }
            }
            if bb2 > 0 {
                bb = lshift(bb, bb2);
                if not bb {
                    outcome = STRTOD_NOMEM;
                    break;
                }
            }
            if bd5 > 0 {
                bd = pow5mult(bd, bd5);
                if not bd {
                    outcome = STRTOD_NOMEM;
                    break;
                }
            }
            if bd2 > 0 {
                bd = lshift(bd, bd2);
                if not bd {
                    outcome = STRTOD_NOMEM;
                    break;
                }
            }
            if bs2 > 0 {
                bs = lshift(bs, bs2);
                if not bs {
                    outcome = STRTOD_NOMEM;
                    break;
                }
            }

            delta = diff(bb, bd);
            if not delta {
                outcome = STRTOD_NOMEM;
                break;
            }
            dsign = delta.view(1)[0].sign;
            delta.view(1)[0].sign = 0;
            i = cmp(delta, bs);
            if bc_nd > nd and i <= 0 {
                if dsign != 0 {
                    break;
                }

                if word1(rv) == u32(0) and (word0(rv) & Bndry_mask) == u32(0) {
                    j = i32((word0(rv) & Exp_mask) >> Exp_shift);
                    if j - bc_scale >= 2 {
                        rv -= 0.5 * sulp(rv, bc_scale);
                        break;
                    }
                }

                bc_nd = nd;
                i = -1;
            }

            if i < 0 {
                if dsign != 0
                    or word1(rv) != u32(0)
                    or (word0(rv) & Bndry_mask) != u32(0)
                    or (word0(rv) & Exp_mask) <= u32(2 * P + 1) * Exp_msk1 {
                    break;
                }
                if digits_of(delta).view(1)[0] == u32(0)
                    and delta.view(1)[0].wds <= 1 {
                    break;
                }
                delta = lshift(delta, Log2P);
                if not delta {
                    outcome = STRTOD_NOMEM;
                    break;
                }
                if cmp(delta, bs) > 0 {
                    (action, dropped) = drop_down(rv, bc_scale, bc_nd, nd);
                    rv = dropped;
                    outcome = action;
                }
                break;
            }
            if i == 0 {
                if dsign != 0 {
                    if (word0(rv) & Bndry_mask1) == Bndry_mask1
                        and word1(rv) == halfway_mask(rv, bc_scale) {
                        rv = make_double((word0(rv) & Exp_mask) + Exp_msk1, u32(0));
                        break;
                    }
                } elif (word0(rv) & Bndry_mask) == u32(0) and word1(rv) == u32(0) {
                    (action, dropped) = drop_down(rv, bc_scale, bc_nd, nd);
                    rv = dropped;
                    outcome = action;
                    break;
                }
                if odd == u32(0) {
                    break;
                }
                if dsign != 0 {
                    rv += sulp(rv, bc_scale);
                } else {
                    rv -= sulp(rv, bc_scale);
                    if rv == 0.0 {
                        if bc_nd > nd {
                            break;
                        }
                        outcome = STRTOD_UNDERFLOW;
                        break;
                    }
                }
                break;
            }
            aadj = ratio(delta, bs);
            aadj1: f64 = 0.0;
            if aadj <= 2.0 {
                if dsign != 0 {
                    aadj = 1.0;
                    aadj1 = 1.0;
                } elif word1(rv) != u32(0) or (word0(rv) & Bndry_mask) != u32(0) {
                    if word1(rv) == Tiny1 and word0(rv) == u32(0) {
                        if bc_nd > nd {
                            break;
                        }
                        outcome = STRTOD_UNDERFLOW;
                        break;
                    }
                    aadj = 1.0;
                    aadj1 = -1.0;
                } else {
                    if aadj < 2.0 / FLT_RADIX {
                        aadj = 1.0 / FLT_RADIX;
                    } else {
                        aadj *= 0.5;
                    }
                    aadj1 = -aadj;
                }
            } else {
                aadj *= 0.5;
                aadj1 = aadj if dsign != 0 else -aadj;
            }
            yw = word0(rv) & Exp_mask;

            skip_check = False;
            if yw == Exp_msk1 * u32(DBL_MAX_EXP + Bias - 1) {
                rv0 = rv;
                rv = set_word0(rv, wrapping_sub(word0(rv), P_EXP));
                adj = aadj1 * ulp(rv);
                rv += adj;
                if (word0(rv) & Exp_mask) >= Exp_msk1 * u32(DBL_MAX_EXP + Bias - P) {
                    if word0(rv0) == Big0 and word1(rv0) == Big1 {
                        outcome = STRTOD_OVERFLOW;
                        break;
                    }
                    rv = make_double(Big0, Big1);
                    skip_check = True;
                } else {
                    rv = set_word0(rv, wrapping_add(word0(rv), P_EXP));
                }
            } else {
                if bc_scale != 0 and yw <= u32(2 * P) * Exp_msk1 {
                    if aadj <= 2147483647.0 {
                        zi = u32(aadj);
                        if zi == u32(0) {
                            zi = u32(1);
                        }
                        aadj = f64(zi);
                        aadj1 = aadj if dsign != 0 else -aadj;
                    }
                    aadj2 = set_word0(
                        aadj1,
                        wrapping_sub(
                            wrapping_add(word0(aadj1), u32(2 * P + 1) * Exp_msk1), yw
                        )
                    );
                    aadj1 = aadj2;
                }
                adj = aadj1 * ulp(rv);
                rv += adj;
            }
            if not skip_check {
                zw = word0(rv) & Exp_mask;
                if bc_nd == nd and bc_scale == 0 and yw == zw {
                    lv = double_to_long(aadj);
                    aadj -= f64(lv);
                    if dsign != 0
                        or word1(rv) != u32(0)
                        or (word0(rv) & Bndry_mask) != u32(0) {
                        if aadj < 0.4999999 or aadj > 0.5000001 {
                            break;
                        }
                    } elif aadj < 0.4999999 / FLT_RADIX {
                        break;
                    }
                }
            }
            Bfree(bb);
            bb = ptr[Bigint]();
            Bfree(bd);
            bd = ptr[Bigint]();
            Bfree(bs);
            bs = ptr[Bigint]();
            Bfree(delta);
            delta = ptr[Bigint]();
        }
        if outcome == STRTOD_OK and bc_nd > nd {
            (error, compared) = bigcomp(rv, s0, bc_e0, bc_nd, bc_nd0, bc_scale);
            rv = compared;
            if error != 0 {
                outcome = STRTOD_NOMEM;
            }
        }

        result: f64 = 0.0;
        if outcome == STRTOD_OK {
            if bc_scale != 0 {
                rv *= make_double(wrapping_sub(Exp_1, u32(2 * P) * Exp_msk1), u32(0));
            }
            result = strtod_signed(rv, sign);
        } elif outcome == STRTOD_NOMEM {
            jacpy_set_errno(ENOMEM);
            result = -1.0;
        } elif outcome == STRTOD_UNDERFLOW {
            result = strtod_underflow(sign);
        } else {
            result = strtod_overflow(sign);
        }
        Bfree(bb);
        Bfree(bd);
        Bfree(bs);
        Bfree(bd0);
        Bfree(delta);
        return result;
    }  def _Py_dg_freedtoa(s: ptr[u8]) {
        b = ptr[Bigint](ptr[i32](s) - 1);
        kk = ptr[i32](b).view(1)[0];
        b.view(1)[0].k = kk;
        b.view(1)[0].maxwds = 1 << kk;
        Bfree(b);
    }  def _Py_dg_dtoa(
        dd: f64,
        mode: i32,
        ndigits: i32,
        decpt: ptr[i32],
        sign: ptr[i32],
        rve: ptr[ptr[u8]]
    ) -> ptr[u8] {
        u = dd;
        if (word0(u) & Sign_bit) != u32(0) {
            sign.view(1)[0] = 1;
            u = set_word0(u, word0(u) & u32(0x7fffffff));
        } else {
            sign.view(1)[0] = 0;
        }

        if (word0(u) & Exp_mask) == Exp_mask {
            decpt.view(1)[0] = 9999;
            if word1(u) == u32(0) and (word0(u) & u32(0xfffff)) == u32(0) {
                return nrv_alloc(ptr[u8]("Infinity"), rve, 8);
            }
            return nrv_alloc(ptr[u8]("NaN"), rve, 3);
        }
        if u == 0.0 {
            decpt.view(1)[0] = 1;
            return nrv_alloc(ptr[u8]("0"), rve, 1);
        }

        (b, be, bbits) = d2b(u);
        if not b {
            return ptr[u8]();
        }
        i = i32((word0(u) >> Exp_shift1) & (Exp_mask >> Exp_shift1));
        d2: f64 = 0.0;
        denorm = False;
        if i != 0 {
            d2 = set_word0(u, (word0(u) & Frac_mask1) | Exp_11);
            i -= Bias;
        } else {
            i = bbits + be + (Bias + (P - 1) - 1);
            xw: u32 = u32(0);
            if i > 32 {
                xw = shl32(word0(u), 64 - i) | (word1(u) >> u32(i - 32));
            } else {
                xw = shl32(word1(u), 32 - i);
            }
            d2 = f64(xw);
            d2 = set_word0(d2, wrapping_sub(word0(d2), u32(31) * Exp_msk1));
            i -= (Bias + (P - 1) - 1) + 1;
            denorm = True;
        }
        ds = (d2 - 1.5) * 0.289529654602168
            + 0.1760912590558
            + f64(i) * 0.301029995663981;
        k = i32(ds);
        if ds < 0.0 and ds != f64(k) {
            k -= 1;
        }
        k_check = True;
        if k >= 0 and k <= Ten_pmax {
            if u < tens(k) {
                k -= 1;
            }
            k_check = False;
        }
        j = bbits - i - 1;
        b2: i32 = 0;
        s2: i32 = 0;
        if j >= 0 {
            s2 = j;
        } else {
            b2 = -j;
        }
        b5: i32 = 0;
        s5: i32 = 0;
        if k >= 0 {
            s5 = k;
            s2 += k;
        } else {
            b2 -= k;
            b5 = -k;
        }
        dmode = mode;
        if dmode < 0 or dmode > 9 {
            dmode = 0;
        }

        try_quick = True;

        if dmode > 5 {
            dmode -= 4;
            try_quick = False;
        }
        leftright = True;
        want = ndigits;
        ilim: i32 = -1;
        ilim1: i32 = -1;
        if dmode == 0 or dmode == 1 {
            i = 18;
            want = 0;
        } elif dmode == 2 or dmode == 4 {
            if dmode == 2 {
                leftright = False;
            }
            if want <= 0 {
                want = 1;
            }
            ilim = want;
            ilim1 = want;
            i = want;
        } else {
            if dmode == 3 {
                leftright = False;
            }
            i = want + k + 1;
            ilim = i;
            ilim1 = i - 1;
            if i <= 0 {
                i = 1;
            }
        }
        s0 = rv_alloc(i);
        if not s0 {
            Bfree(b);
            return ptr[u8]();
        }
        s = s0;

        target: i32 = DTOA_NEXT;
        if ilim >= 0 and ilim <= Quick_max and try_quick {
            i = 0;
            saved = u;
            k0 = k;
            ilim0 = ilim;
            ieps: i32 = 2;
            if k > 0 {
                ds = tens(k & 0xf);
                j = k >> 4;
                if (j & Bletch) != 0 {
                    j = j & (Bletch - 1);
                    u /= bigtens(n_bigtens - 1);
                    ieps += 1;
                }
                while j != 0 {
                    if (j & 1) != 0 {
                        ieps += 1;
                        ds *= bigtens(i);
                    }
                    j = j >> 1;
                    i += 1;
                }
                u /= ds;
            } else {
                j1 = -k;
                if j1 != 0 {
                    u *= tens(j1 & 0xf);
                    j = j1 >> 4;
                    while j != 0 {
                        if (j & 1) != 0 {
                            ieps += 1;
                            u *= bigtens(i);
                        }
                        j = j >> 1;
                        i += 1;
                    }
                }
            }
            fast_failed = False;
            if k_check and u < 1.0 and ilim > 0 {
                if ilim1 <= 0 {
                    fast_failed = True;
                } else {
                    ilim = ilim1;
                    k -= 1;
                    u *= 10.0;
                    ieps += 1;
                }
            }
            if not fast_failed {
                eps = f64(ieps) * u + 7.0;
                eps = set_word0(eps, wrapping_sub(word0(eps), u32(P - 1) * Exp_msk1));
                if ilim == 0 {
                    u -= 5.0;
                    if u > eps {
                        target = DTOA_ONE_DIGIT;
                    } elif u < -eps {
                        target = DTOA_NO_DIGITS;
                    } else {
                        fast_failed = True;
                    }
                } elif leftright {
                    eps = 0.5 / tens(ilim - 1) - eps;
                    i = 0;
                    while True {
                        lv = i32(u);
                        u -= f64(lv);
                        s.view(1)[0] = u8(48 + lv);
                        s = s + 1;
                        if u < eps {
                            target = DTOA_RET1;
                            break;
                        }
                        if 1.0 - u < eps {
                            target = DTOA_BUMP_UP;
                            break;
                        }
                        i += 1;
                        if i >= ilim {
                            break;
                        }
                        eps *= 10.0;
                        u *= 10.0;
                    }
                    if target == DTOA_NEXT {
                        fast_failed = True;
                    }
                } else {
                    eps *= tens(ilim - 1);
                    i = 1;
                    while True {
                        lv = i32(u);
                        u -= f64(lv);
                        if u == 0.0 {
                            ilim = i;
                        }
                        s.view(1)[0] = u8(48 + lv);
                        s = s + 1;
                        if i == ilim {
                            if u > 0.5 + eps {
                                target = DTOA_BUMP_UP;
                            } elif u < 0.5 - eps {
                                s = strip_zeros(s);
                                target = DTOA_RET1;
                            }
                            break;
                        }
                        i += 1;
                        u *= 10.0;
                    }
                    if target == DTOA_NEXT {
                        fast_failed = True;
                    }
                }
            }
            if fast_failed {
                s = s0;
                u = saved;
                k = k0;
                ilim = ilim0;
            }
        }

        if target == DTOA_NEXT and be >= 0 and k <= Int_max {
            ds = tens(k);
            if want < 0 and ilim <= 0 {
                if ilim < 0 or u <= 5.0 * ds {
                    target = DTOA_NO_DIGITS;
                } else {
                    target = DTOA_ONE_DIGIT;
                }
            } else {
                i = 1;
                while True {
                    lv = i32(u / ds);
                    u -= f64(lv) * ds;
                    s.view(1)[0] = u8(48 + lv);
                    s = s + 1;
                    if u == 0.0 {
                        break;
                    }
                    if i == ilim {
                        u += u;
                        if u > ds or (u == ds and (lv & 1) != 0) {
                            (s, k) = bump_up(s, s0, k);
                        } else {
                            while int(s) > int(s0) and (s - 1).view(1)[0] == CH_0 {
                                s = s - 1;
                            }
                        }
                        break;
                    }
                    i += 1;
                    u *= 10.0;
                }
                target = DTOA_RET1;
            }
        }

        if target == DTOA_NEXT {
            (ok, s_end, k_out) = dtoa_bignum(
                b,
                u,
                dmode,
                want,
                k,
                k_check,
                leftright,
                ilim,
                ilim1,
                be,
                bbits,
                denorm,
                b2,
                b5,
                s2,
                s5,
                s0,
                s
            );
            if not ok {
                _Py_dg_freedtoa(s0);
                return ptr[u8]();
            }
            s = s_end;
            k = k_out;
        } else {
            if target == DTOA_BUMP_UP {
                (s, k) = bump_up(s, s0, k);
            } elif target == DTOA_NO_DIGITS {
                k = -1 - want;
            } elif target == DTOA_ONE_DIGIT {
                s.view(1)[0] = CH_1;
                s = s + 1;
                k += 1;
            }
            Bfree(b);
        }
        s.view(1)[0] = u8(0);
        decpt.view(1)[0] = k + 1;
        if rve {
            rve.view(1)[0] = s;
        }
        return s0;
    }  def _PyDtoa_Init(interp: ptr[u8]) -> PyStatus {
        p5s = ptr[ptr[Bigint]](interp + PyInterpreterState_DTOA_P5S);

        p5 = i2b(625);
        if not p5 {
            return dtoa_no_memory();
        }
        p5s.view(1)[0] = p5;

        i: i64 = 1;
        while i < Bigint_Pow5size {
            p5 = mult(p5, p5);
            if not p5 {
                return dtoa_no_memory();
            }
            (p5s + i).view(1)[0] = p5;
            i += 1;
        }
        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }  def _PyDtoa_Fini(interp: ptr[u8]) {
        p5s = ptr[ptr[Bigint]](interp + PyInterpreterState_DTOA_P5S);
        i: i64 = 0;
        while i < Bigint_Pow5size {
            p5 = (p5s + i).view(1)[0];
            (p5s + i).view(1)[0] = ptr[Bigint]();
            Bfree(p5);
            i += 1;
        }
    }
}

glob:priv CH_0: Final[u8] = u8(48),
     CH_1: Final[u8] = u8(49),
     CH_9: Final[u8] = u8(57),
     CH_PLUS: Final[u8] = u8(43),
     CH_MINUS: Final[u8] = u8(45),
     CH_DOT: Final[u8] = u8(46),
     CH_LOWER_E: Final[u8] = u8(101),
     CH_UPPER_E: Final[u8] = u8(69),
     STRTOD_DIGLIM: Final[i32] = 40,
     MAX_ABS_EXP: Final[u32] = u32(1100000000),
     MAX_DIGITS: Final[i64] = 1000000000,
     DBL_DIG: Final[i32] = 15,
     DBL_MAX_10_EXP: Final[i32] = 308,
     DBL_MAX_EXP: Final[i32] = 1024,
     FLT_RADIX: Final[f64] = 2.0,
     Exp_shift: Final[u32] = u32(20),
     Exp_shift1: Final[u32] = u32(20),
     Exp_msk1: Final[u32] = u32(0x100000),
     Exp_mask: Final[u32] = u32(0x7ff00000),
     P: Final[i32] = 53,
     P_EXP: Final[u32] = u32(0x3500000),
     Bias: Final[i32] = 1023,
     Etiny: Final[i32] = -1074,
     Exp_1: Final[u32] = u32(0x3ff00000),
     Exp_11: Final[u32] = u32(0x3ff00000),
     Ebits: Final[i32] = 11,
     Frac_mask: Final[u32] = u32(0xfffff),
     Frac_mask1: Final[u32] = u32(0xfffff),
     Ten_pmax: Final[i32] = 22,
     Bletch: Final[i32] = 0x10,
     Bndry_mask: Final[u32] = u32(0xfffff),
     Bndry_mask1: Final[u32] = u32(0xfffff),
     Sign_bit: Final[u32] = u32(0x80000000),
     Log2P: Final[i32] = 1,
     Tiny1: Final[u32] = u32(1),
     Quick_max: Final[i32] = 14,
     Int_max: Final[i32] = 14,
     Big0: Final[u32] = u32(0x7fefffff),
     Big1: Final[u32] = u32(0xffffffff),
     FFFFFFFF: Final[u64] = u64(0xffffffff),
     Scale_Bit: Final[i32] = 0x10,
     n_bigtens: Final[i32] = 5,
     kmask: Final[i32] = 31,
     STRTOD_OK: Final[i32] = 0,
     STRTOD_UNDERFLOW: Final[i32] = 1,
     STRTOD_NOMEM: Final[i32] = 2,
     STRTOD_OVERFLOW: Final[i32] = 3,
     DTOA_NEXT: Final[i32] = 0,
     DTOA_RET1: Final[i32] = 1,
     DTOA_BUMP_UP: Final[i32] = 2,
     DTOA_NO_DIGITS: Final[i32] = 3,
     DTOA_ONE_DIGIT: Final[i32] = 4;

def word0(d: f64) -> u32;

def word1(d: f64) -> u32;

def make_double(w0: u32, w1: u32) -> f64;

def set_word0(d: f64, w0: u32) -> f64;

def shl32(x: u32, n: i32) -> u32;

def tens(i: i32) -> f64;

def bigtens(i: i32) -> f64;

def tinytens(i: i32) -> f64;

def digits_of(b: ptr[Bigint]) -> ptr[u32];

def sig_digit(s0: ptr[u8], i: i32, nd0: i32) -> u8;

def strtod_signed(rv: f64, sign: i32) -> f64;

def strtod_underflow(sign: i32) -> f64;

def strtod_overflow(sign: i32) -> f64;

def double_to_long(d: f64) -> i32;

def halfway_mask(rv: f64, scale: i32) -> u32;

def drop_down(rv: f64, scale: i32, bc_nd: i32, nd: i32) -> tuple[i32, f64];

def dtoa_no_memory -> PyStatus;

def Balloc(k: i32) -> ptr[Bigint];

def Bfree(v: ptr[Bigint]);

def Bcopy(x: ptr[Bigint], y: ptr[Bigint]);

def multadd(b: ptr[Bigint], m: i32, a: i32) -> ptr[Bigint];

def s2b(s: ptr[u8], nd0: i32, nd: i32, y9: u32) -> ptr[Bigint];

def hi0bits(x: u32) -> i32;

def lo0bits(y: u32) -> tuple[i32, u32];

def i2b(i: i32) -> ptr[Bigint];

def mult(a: ptr[Bigint], b: ptr[Bigint]) -> ptr[Bigint];

def pow5mult(b: ptr[Bigint], k: i32) -> ptr[Bigint];

def lshift(b: ptr[Bigint], k: i32) -> ptr[Bigint];

def cmp(a: ptr[Bigint], b: ptr[Bigint]) -> i32;

def diff(a: ptr[Bigint], b: ptr[Bigint]) -> ptr[Bigint];

def ulp(x: f64) -> f64;

def b2d(a: ptr[Bigint]) -> tuple[f64, i32];

def sd2b(d: f64, scale: i32) -> tuple[ptr[Bigint], i32];

def d2b(d: f64) -> tuple[ptr[Bigint], i32, i32];

def ratio(a: ptr[Bigint], b: ptr[Bigint]) -> f64;

def dshift(b: ptr[Bigint], p2: i32) -> i32;

def quorem(b: ptr[Bigint], S: ptr[Bigint]) -> i32;

def sulp(x: f64, scale: i32) -> f64;

def bigcomp(
    rv: f64, s0: ptr[u8], e0: i32, nd: i32, nd0: i32, scale: i32
) -> tuple[i32, f64];

def rv_alloc(i: i32) -> ptr[u8];

def nrv_alloc(s: ptr[u8], rve: ptr[ptr[u8]], n: i32) -> ptr[u8];

def bump_up(s: ptr[u8], s0: ptr[u8], k: i32) -> tuple[ptr[u8], i32];

def strip_zeros(s: ptr[u8]) -> ptr[u8];

def dtoa_release(b: ptr[Bigint], S: ptr[Bigint], mhi: ptr[Bigint], mlo: ptr[Bigint]);

def dtoa_bignum(
    b: ptr[Bigint],
    u: f64,
    mode: i32,
    ndigits: i32,
    k: i32,
    k_check: bool,
    leftright: bool,
    ilim: i32,
    ilim1: i32,
    be: i32,
    bbits: i32,
    denorm: bool,
    b2: i32,
    b5: i32,
    s2: i32,
    s5: i32,
    s0: ptr[u8],
    s: ptr[u8]
) -> tuple[bool, ptr[u8], i32];

impl word0(d: f64) -> u32 {
    return u32.wrap(__float_bits(d) >> 32);
}

impl word1(d: f64) -> u32 {
    return u32.wrap(__float_bits(d));
}

impl make_double(w0: u32, w1: u32) -> f64 {
    return __bits_float(i64.wrap((u64(w0) << u64(32)) | u64(w1)));
}

impl set_word0(d: f64, w0: u32) -> f64 {
    return make_double(w0, word1(d));
}

impl shl32(x: u32, n: i32) -> u32 {
    return u32.wrap(u64(x) << u64(n & 31));
}

impl tens(i: i32) -> f64 {
    return (addressof(dtoa_tens) + i64(i)).view(1)[0];
}

impl bigtens(i: i32) -> f64 {
    return (addressof(dtoa_bigtens) + i64(i)).view(1)[0];
}

impl tinytens(i: i32) -> f64 {
    return (addressof(dtoa_tinytens) + i64(i)).view(1)[0];
}

impl digits_of(b: ptr[Bigint]) -> ptr[u32] {
    return ptr[u32](ptr[u8](b) + Bigint_X);
}

impl sig_digit(s0: ptr[u8], i: i32, nd0: i32) -> u8 {
    if i < nd0 {
        return (s0 + i64(i)).view(1)[0];
    }
    return (s0 + i64(i) + 1).view(1)[0];
}

impl strtod_signed(rv: f64, sign: i32) -> f64 {
    if sign != 0 {
        return -rv;
    }
    return rv;
}

impl strtod_underflow(sign: i32) -> f64 {
    if sign != 0 {
        return make_double(Sign_bit, u32(0));
    }
    return 0.0;
}

impl strtod_overflow(sign: i32) -> f64 {
    jacpy_set_errno(ERANGE);
    return strtod_signed(make_double(Exp_mask, u32(0)), sign);
}

impl double_to_long(d: f64) -> i32 {
    if d < 2147483648.0 and d >= -2147483648.0 {
        return i32(d);
    }
    return i32(-2147483647) - 1;
}

impl halfway_mask(rv: f64, scale: i32) -> u32 {
    if scale != 0 {
        y = word0(rv) & Exp_mask;
        if y <= u32(2 * P) * Exp_msk1 {
            return shl32(u32(0xffffffff), 2 * P + 1 - i32(y >> Exp_shift));
        }
    }
    return u32(0xffffffff);
}

impl drop_down(rv: f64, scale: i32, bc_nd: i32, nd: i32) -> tuple[i32, f64] {
    if scale != 0 {
        lw = word0(rv) & Exp_mask;
        if lw <= u32(2 * P + 1) * Exp_msk1 {
            if lw > u32(P + 2) * Exp_msk1 {
                return (STRTOD_OK, rv);
            }
            if bc_nd > nd {
                return (STRTOD_OK, rv);
            }
            return (STRTOD_UNDERFLOW, rv);
        }
    }
    lw = wrapping_sub(word0(rv) & Exp_mask, Exp_msk1);
    return (STRTOD_OK, make_double(lw | Bndry_mask1, u32(0xffffffff)));
}

impl dtoa_no_memory -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_ERROR,
        func=ptr[u8]("PyStatus_NoMemory"),
        err_msg=ptr[u8]("memory allocation failed"),
        exitcode=0
    );
}

impl Balloc(k: i32) -> ptr[Bigint] {
    interp = current_interp();
    freelist = ptr[ptr[Bigint]](interp + PyInterpreterState_DTOA_FREELIST);
    rv = ptr[Bigint]();
    if i64(k) <= Bigint_Kmax {
        rv = (freelist + i64(k)).view(1)[0];
    }
    if rv {
        (freelist + i64(k)).view(1)[0] = rv.view(1)[0].next;
    } else {
        x = 1 << k;
        len = (Bigint_SIZE + i64(x - 1) * 4 + 8 - 1) // 8;
        next_slot = ptr[ptr[f64]](interp + PyInterpreterState_DTOA_PREALLOCATED_NEXT);
        pmem_next = next_slot.view(1)[0];
        private_mem = interp + PyInterpreterState_DTOA_PREALLOCATED;
        if i64(k) <= Bigint_Kmax
            and (int(pmem_next) - int(private_mem)) // 8 + len
                <= Bigint_PREALLOC_SIZE {
            rv = ptr[Bigint](pmem_next);
            next_slot.view(1)[0] = pmem_next + len;
        } else {
            rv = ptr[Bigint](PyMem_Malloc(u64(len * 8)));
            if not rv {
                return rv;
            }
        }
        rv.view(1)[0].k = k;
        rv.view(1)[0].maxwds = x;
    }
    rv.view(1)[0].sign = 0;
    rv.view(1)[0].wds = 0;
    return rv;
}

impl Bfree(v: ptr[Bigint]) {
    if v {
        if i64(v.view(1)[0].k) > Bigint_Kmax {
            PyMem_Free(ptr(v));
        } else {
            interp = current_interp();
            freelist = ptr[ptr[Bigint]](interp + PyInterpreterState_DTOA_FREELIST);
            slot = freelist + i64(v.view(1)[0].k);
            v.view(1)[0].next = slot.view(1)[0];
            slot.view(1)[0] = v;
        }
    }
}

impl Bcopy(x: ptr[Bigint], y: ptr[Bigint]) {
    memcpy(
        ptr(ptr[u8](x) + Bigint_SIGN),
        ptr(ptr[u8](y) + Bigint_SIGN),
        u64(i64(y.view(1)[0].wds) * 4 + 2 * 4)
    );
}

impl multadd(b: ptr[Bigint], m: i32, a: i32) -> ptr[Bigint] {
    wds = b.view(1)[0].wds;
    x = digits_of(b);
    i: i32 = 0;
    carry = u64(a);
    while True {
        y = u64(x.view(1)[0]) * u64(m) + carry;
        carry = y >> u64(32);
        x.view(1)[0] = u32.wrap(y & FFFFFFFF);
        x = x + 1;
        i += 1;
        if i >= wds {
            break;
        }
    }
    if carry != u64(0) {
        if wds >= b.view(1)[0].maxwds {
            b1 = Balloc(b.view(1)[0].k + 1);
            if not b1 {
                Bfree(b);
                return b1;
            }
            Bcopy(b1, b);
            Bfree(b);
            b = b1;
        }
        (digits_of(b) + i64(wds)).view(1)[0] = u32.wrap(carry);
        wds += 1;
        b.view(1)[0].wds = wds;
    }
    return b;
}

impl s2b(s: ptr[u8], nd0: i32, nd: i32, y9: u32) -> ptr[Bigint] {
    x = (nd + 8) // 9;
    k: i32 = 0;
    y: i32 = 1;
    while x > y {
        y = y << 1;
        k += 1;
    }
    b = Balloc(k);
    if not b {
        return b;
    }
    digits_of(b).view(1)[0] = y9;
    b.view(1)[0].wds = 1;

    if nd <= 9 {
        return b;
    }

    p = s + 9;
    i: i32 = 9;
    while i < nd0 {
        b = multadd(b, 10, i32(p.view(1)[0]) - 48);
        p = p + 1;
        if not b {
            return b;
        }
        i += 1;
    }
    p = p + 1;
    while i < nd {
        b = multadd(b, 10, i32(p.view(1)[0]) - 48);
        p = p + 1;
        if not b {
            return b;
        }
        i += 1;
    }
    return b;
}

impl hi0bits(x: u32) -> i32 {
    k: i32 = 0;
    y = x;
    if (y & u32(0xffff0000)) == u32(0) {
        k = 16;
        y = y << u32(16);
    }
    if (y & u32(0xff000000)) == u32(0) {
        k += 8;
        y = y << u32(8);
    }
    if (y & u32(0xf0000000)) == u32(0) {
        k += 4;
        y = y << u32(4);
    }
    if (y & u32(0xc0000000)) == u32(0) {
        k += 2;
        y = y << u32(2);
    }
    if (y & u32(0x80000000)) == u32(0) {
        k += 1;
        if (y & u32(0x40000000)) == u32(0) {
            return 32;
        }
    }
    return k;
}

impl lo0bits(y: u32) -> tuple[i32, u32] {
    x = y;
    if (x & u32(7)) != u32(0) {
        if (x & u32(1)) != u32(0) {
            return (i32(0), y);
        }
        if (x & u32(2)) != u32(0) {
            return (i32(1), x >> u32(1));
        }
        return (i32(2), x >> u32(2));
    }
    k: i32 = 0;
    if (x & u32(0xffff)) == u32(0) {
        k = 16;
        x = x >> u32(16);
    }
    if (x & u32(0xff)) == u32(0) {
        k += 8;
        x = x >> u32(8);
    }
    if (x & u32(0xf)) == u32(0) {
        k += 4;
        x = x >> u32(4);
    }
    if (x & u32(0x3)) == u32(0) {
        k += 2;
        x = x >> u32(2);
    }
    if (x & u32(1)) == u32(0) {
        k += 1;
        x = x >> u32(1);
        if x == u32(0) {
            return (i32(32), y);
        }
    }
    return (k, x);
}

impl i2b(i: i32) -> ptr[Bigint] {
    b = Balloc(1);
    if not b {
        return b;
    }
    digits_of(b).view(1)[0] = u32(i);
    b.view(1)[0].wds = 1;
    return b;
}

impl mult(a: ptr[Bigint], b: ptr[Bigint]) -> ptr[Bigint] {
    if (digits_of(a).view(1)[0] == u32(0) and a.view(1)[0].wds == 1)
        or (digits_of(b).view(1)[0] == u32(0) and b.view(1)[0].wds == 1) {
        zero = Balloc(0);
        if not zero {
            return zero;
        }
        zero.view(1)[0].wds = 1;
        digits_of(zero).view(1)[0] = u32(0);
        return zero;
    }

    left = a;
    right = b;
    if left.view(1)[0].wds < right.view(1)[0].wds {
        left = b;
        right = a;
    }
    k = left.view(1)[0].k;
    wa = left.view(1)[0].wds;
    wb = right.view(1)[0].wds;
    wc = wa + wb;
    if wc > left.view(1)[0].maxwds {
        k += 1;
    }
    c = Balloc(k);
    if not c {
        return c;
    }
    x = digits_of(c);
    xa = x + i64(wc);
    while int(x) < int(xa) {
        x.view(1)[0] = u32(0);
        x = x + 1;
    }
    xa = digits_of(left);
    xae = xa + i64(wa);
    xb = digits_of(right);
    xbe = xb + i64(wb);
    xc0 = digits_of(c);
    while int(xb) < int(xbe) {
        y = xb.view(1)[0];
        xb = xb + 1;
        if y != u32(0) {
            x = xa;
            xc = xc0;
            carry: u64 = u64(0);
            while True {
                z = u64(x.view(1)[0]) * u64(y) + u64(xc.view(1)[0]) + carry;
                x = x + 1;
                carry = z >> u64(32);
                xc.view(1)[0] = u32.wrap(z & FFFFFFFF);
                xc = xc + 1;
                if int(x) >= int(xae) {
                    break;
                }
            }
            xc.view(1)[0] = u32.wrap(carry);
        }
        xc0 = xc0 + 1;
    }
    xc = digits_of(c) + i64(wc);
    while wc > 0 {
        xc = xc - 1;
        if xc.view(1)[0] != u32(0) {
            break;
        }
        wc -= 1;
    }
    c.view(1)[0].wds = wc;
    return c;
}

impl pow5mult(b: ptr[Bigint], k: i32) -> ptr[Bigint] {
    i = k & 3;
    if i != 0 {
        b = multadd(b, (addressof(dtoa_p05) + i64(i - 1)).view(1)[0], 0);
        if not b {
            return b;
        }
    }

    k = k >> 2;
    if k == 0 {
        return b;
    }
    p5s = ptr[ptr[Bigint]](current_interp() + PyInterpreterState_DTOA_P5S);
    while True {
        p5 = p5s.view(1)[0];
        p5s = p5s + 1;
        if (k & 1) != 0 {
            b1 = mult(b, p5);
            Bfree(b);
            b = b1;
            if not b {
                return b;
            }
        }
        k = k >> 1;
        if k == 0 {
            break;
        }
    }
    return b;
}

impl lshift(b: ptr[Bigint], k: i32) -> ptr[Bigint] {
    if k == 0 or (digits_of(b).view(1)[0] == u32(0) and b.view(1)[0].wds == 1) {
        return b;
    }

    n = k >> 5;
    k1 = b.view(1)[0].k;
    n1 = n + b.view(1)[0].wds + 1;
    i = b.view(1)[0].maxwds;
    while n1 > i {
        i = i << 1;
        k1 += 1;
    }
    b1 = Balloc(k1);
    if not b1 {
        Bfree(b);
        return b1;
    }
    x1 = digits_of(b1);
    i = 0;
    while i < n {
        x1.view(1)[0] = u32(0);
        x1 = x1 + 1;
        i += 1;
    }
    x = digits_of(b);
    xe = x + i64(b.view(1)[0].wds);
    kk = k & 0x1f;
    if kk != 0 {
        kr = u32(32 - kk);
        z: u32 = u32(0);
        while True {
            x1.view(1)[0] = shl32(x.view(1)[0], kk) | z;
            x1 = x1 + 1;
            z = x.view(1)[0] >> kr;
            x = x + 1;
            if int(x) >= int(xe) {
                break;
            }
        }
        x1.view(1)[0] = z;
        if z != u32(0) {
            n1 += 1;
        }
    } else {
        while True {
            x1.view(1)[0] = x.view(1)[0];
            x1 = x1 + 1;
            x = x + 1;
            if int(x) >= int(xe) {
                break;
            }
        }
    }
    b1.view(1)[0].wds = n1 - 1;
    Bfree(b);
    return b1;
}

impl cmp(a: ptr[Bigint], b: ptr[Bigint]) -> i32 {
    i = a.view(1)[0].wds;
    j = b.view(1)[0].wds;
    i -= j;
    if i != 0 {
        return i;
    }
    xa0 = digits_of(a);
    xa = xa0 + i64(j);
    xb0 = digits_of(b);
    xb = xb0 + i64(j);
    while True {
        xa = xa - 1;
        xb = xb - 1;
        if xa.view(1)[0] != xb.view(1)[0] {
            if xa.view(1)[0] < xb.view(1)[0] {
                return -1;
            }
            return 1;
        }
        if int(xa) <= int(xa0) {
            break;
        }
    }
    return 0;
}

impl diff(a: ptr[Bigint], b: ptr[Bigint]) -> ptr[Bigint] {
    i = cmp(a, b);
    if i == 0 {
        z = Balloc(0);
        if not z {
            return z;
        }
        z.view(1)[0].wds = 1;
        digits_of(z).view(1)[0] = u32(0);
        return z;
    }
    big = a;
    small = b;
    if i < 0 {
        big = b;
        small = a;
        i = 1;
    } else {
        i = 0;
    }
    c = Balloc(big.view(1)[0].k);
    if not c {
        return c;
    }
    c.view(1)[0].sign = i;
    wa = big.view(1)[0].wds;
    xa = digits_of(big);
    xae = xa + i64(wa);
    wb = small.view(1)[0].wds;
    xb = digits_of(small);
    xbe = xb + i64(wb);
    xc = digits_of(c);
    borrow: u64 = u64(0);
    while True {
        y = wrapping_sub(wrapping_sub(u64(xa.view(1)[0]), u64(xb.view(1)[0])), borrow);
        xa = xa + 1;
        xb = xb + 1;
        borrow = (y >> u64(32)) & u64(1);
        xc.view(1)[0] = u32.wrap(y & FFFFFFFF);
        xc = xc + 1;
        if int(xb) >= int(xbe) {
            break;
        }
    }
    while int(xa) < int(xae) {
        y = wrapping_sub(u64(xa.view(1)[0]), borrow);
        xa = xa + 1;
        borrow = (y >> u64(32)) & u64(1);
        xc.view(1)[0] = u32.wrap(y & FFFFFFFF);
        xc = xc + 1;
    }
    while True {
        xc = xc - 1;
        if xc.view(1)[0] != u32(0) {
            break;
        }
        wa -= 1;
    }
    c.view(1)[0].wds = wa;
    return c;
}

impl ulp(x: f64) -> f64 {
    lw = wrapping_sub(word0(x) & Exp_mask, u32(P - 1) * Exp_msk1);
    return make_double(lw, u32(0));
}

impl b2d(a: ptr[Bigint]) -> tuple[f64, i32] {
    xa0 = digits_of(a);
    xa = xa0 + i64(a.view(1)[0].wds);
    xa = xa - 1;
    y = xa.view(1)[0];
    k = hi0bits(y);
    e = 32 - k;
    if k < Ebits {
        w0 = Exp_1 | (y >> u32(Ebits - k));
        w: u32 = u32(0);
        if int(xa) > int(xa0) {
            xa = xa - 1;
            w = xa.view(1)[0];
        }
        w1 = shl32(y, (32 - Ebits) + k) | (w >> u32(Ebits - k));
        return (make_double(w0, w1), e);
    }
    z: u32 = u32(0);
    if int(xa) > int(xa0) {
        xa = xa - 1;
        z = xa.view(1)[0];
    }
    k -= Ebits;
    if k != 0 {
        w0 = Exp_1 | shl32(y, k) | (z >> u32(32 - k));
        y = u32(0);
        if int(xa) > int(xa0) {
            xa = xa - 1;
            y = xa.view(1)[0];
        }
        w1 = shl32(z, k) | (y >> u32(32 - k));
        return (make_double(w0, w1), e);
    }
    return (make_double(Exp_1 | y, z), e);
}

impl sd2b(d: f64, scale: i32) -> tuple[ptr[Bigint], i32] {
    b = Balloc(1);
    if not b {
        return (b, i32(0));
    }
    x = digits_of(b);

    b.view(1)[0].wds = 2;
    x.view(1)[0] = word1(d);
    (x + 1).view(1)[0] = word0(d) & Frac_mask;
    e = Etiny - 1 + i32((word0(d) & Exp_mask) >> Exp_shift);
    if e < Etiny {
        e = Etiny;
    } else {
        (x + 1).view(1)[0] = (x + 1).view(1)[0] | Exp_msk1;
    }

    if scale != 0 and (x.view(1)[0] != u32(0) or (x + 1).view(1)[0] != u32(0)) {
        e -= scale;
        if e < Etiny {
            sc = Etiny - e;
            e = Etiny;
            if sc >= 32 {
                x.view(1)[0] = (x + 1).view(1)[0];
                (x + 1).view(1)[0] = u32(0);
                sc -= 32;
            }
            if sc != 0 {
                x.view(1)[0] = (x.view(1)[0] >> u32(sc))
                    | shl32((x + 1).view(1)[0], 32 - sc);
                (x + 1).view(1)[0] = (x + 1).view(1)[0] >> u32(sc);
            }
        }
    }
    if (x + 1).view(1)[0] == u32(0) {
        b.view(1)[0].wds = 1;
    }

    return (b, e);
}

impl d2b(d: f64) -> tuple[ptr[Bigint], i32, i32] {
    b = Balloc(1);
    if not b {
        return (b, i32(0), i32(0));
    }
    x = digits_of(b);

    z = word0(d) & Frac_mask;
    w0 = word0(d) & u32(0x7fffffff);
    de = i32(w0 >> Exp_shift);
    if de != 0 {
        z = z | Exp_msk1;
    }
    k: i32 = 0;
    i: i32 = 0;
    y = word1(d);
    if y != u32(0) {
        (k, y) = lo0bits(y);
        if k != 0 {
            x.view(1)[0] = y | shl32(z, 32 - k);
            z = z >> u32(k);
        } else {
            x.view(1)[0] = y;
        }
        (x + 1).view(1)[0] = z;
        i = i32(2) if z != u32(0) else i32(1);
        b.view(1)[0].wds = i;
    } else {
        (k, z) = lo0bits(z);
        x.view(1)[0] = z;
        i = 1;
        b.view(1)[0].wds = 1;
        k += 32;
    }
    if de != 0 {
        return (b, de - Bias - (P - 1) + k, P - k);
    }
    return (
        b,
        de - Bias - (P - 1) + 1 + k,
        32 * i - hi0bits((x + i64(i - 1)).view(1)[0])
    );
}

impl ratio(a: ptr[Bigint], b: ptr[Bigint]) -> f64 {
    (da, ka) = b2d(a);
    (db, kb) = b2d(b);
    k = ka - kb + 32 * (a.view(1)[0].wds - b.view(1)[0].wds);
    if k > 0 {
        da = set_word0(da, wrapping_add(word0(da), u32.wrap(i64(k) * 0x100000)));
    } else {
        k = -k;
        db = set_word0(db, wrapping_add(word0(db), u32.wrap(i64(k) * 0x100000)));
    }
    return da / db;
}

impl dshift(b: ptr[Bigint], p2: i32) -> i32 {
    rv = hi0bits((digits_of(b) + i64(b.view(1)[0].wds - 1)).view(1)[0]) - 4;
    if p2 > 0 {
        rv -= p2;
    }
    return rv & kmask;
}

impl quorem(b: ptr[Bigint], S: ptr[Bigint]) -> i32 {
    n = S.view(1)[0].wds;
    if b.view(1)[0].wds < n {
        return 0;
    }
    sx = digits_of(S);
    n -= 1;
    sxe = sx + i64(n);
    bx = digits_of(b);
    bxe = bx + i64(n);
    q = bxe.view(1)[0] // (sxe.view(1)[0] + u32(1));
    if q != u32(0) {
        borrow: u64 = u64(0);
        carry: u64 = u64(0);
        while True {
            ys = u64(sx.view(1)[0]) * u64(q) + carry;
            sx = sx + 1;
            carry = ys >> u64(32);
            y = wrapping_sub(wrapping_sub(u64(bx.view(1)[0]), ys & FFFFFFFF), borrow);
            borrow = (y >> u64(32)) & u64(1);
            bx.view(1)[0] = u32.wrap(y & FFFFFFFF);
            bx = bx + 1;
            if int(sx) > int(sxe) {
                break;
            }
        }
        if bxe.view(1)[0] == u32(0) {
            bx = digits_of(b);
            while True {
                bxe = bxe - 1;
                if int(bxe) > int(bx) and bxe.view(1)[0] == u32(0) {
                    n -= 1;
                } else {
                    break;
                }
            }
            b.view(1)[0].wds = n;
        }
    }
    if cmp(b, S) >= 0 {
        q += u32(1);
        borrow: u64 = u64(0);
        carry: u64 = u64(0);
        bx = digits_of(b);
        sx = digits_of(S);
        while True {
            ys = u64(sx.view(1)[0]) + carry;
            sx = sx + 1;
            carry = ys >> u64(32);
            y = wrapping_sub(wrapping_sub(u64(bx.view(1)[0]), ys & FFFFFFFF), borrow);
            borrow = (y >> u64(32)) & u64(1);
            bx.view(1)[0] = u32.wrap(y & FFFFFFFF);
            bx = bx + 1;
            if int(sx) > int(sxe) {
                break;
            }
        }
        bx = digits_of(b);
        bxe = bx + i64(n);
        if bxe.view(1)[0] == u32(0) {
            while True {
                bxe = bxe - 1;
                if int(bxe) > int(bx) and bxe.view(1)[0] == u32(0) {
                    n -= 1;
                } else {
                    break;
                }
            }
            b.view(1)[0].wds = n;
        }
    }
    return i32(q);
}

impl sulp(x: f64, scale: i32) -> f64 {
    if scale != 0 and 2 * P + 1 > i32((word0(x) & Exp_mask) >> Exp_shift) {
        return make_double(u32(P + 2) * Exp_msk1, u32(0));
    }
    return ulp(x);
}

impl bigcomp(
    rv: f64, s0: ptr[u8], e0: i32, nd: i32, nd0: i32, scale: i32
) -> tuple[i32, f64] {
    p5 = nd + e0;
    (b, p2) = sd2b(rv, scale);
    if not b {
        return (i32(-1), rv);
    }

    odd = digits_of(b).view(1)[0] & u32(1);

    b = lshift(b, 1);
    if not b {
        return (i32(-1), rv);
    }
    digits_of(b).view(1)[0] = digits_of(b).view(1)[0] | u32(1);
    p2 -= 1;

    p2 -= p5;
    d = i2b(1);
    if not d {
        Bfree(b);
        return (i32(-1), rv);
    }
    if p5 > 0 {
        d = pow5mult(d, p5);
        if not d {
            Bfree(b);
            return (i32(-1), rv);
        }
    } elif p5 < 0 {
        b = pow5mult(b, -p5);
        if not b {
            Bfree(d);
            return (i32(-1), rv);
        }
    }
    b2: i32 = 0;
    d2: i32 = 0;
    if p2 > 0 {
        b2 = p2;
    } else {
        d2 = -p2;
    }
    i = dshift(d, d2);
    b2 += i;
    if b2 > 0 {
        b = lshift(b, b2);
        if not b {
            Bfree(d);
            return (i32(-1), rv);
        }
    }
    d2 += i;
    if d2 > 0 {
        d = lshift(d, d2);
        if not d {
            Bfree(b);
            return (i32(-1), rv);
        }
    }

    dd: i32 = 0;
    if cmp(b, d) >= 0 {
        dd = -1;
    } else {
        i = 0;
        while True {
            b = multadd(b, 10, 0);
            if not b {
                Bfree(d);
                return (i32(-1), rv);
            }
            dd = i32(sig_digit(s0, i, nd0)) - 48 - quorem(b, d);
            i += 1;

            if dd != 0 {
                break;
            }
            if digits_of(b).view(1)[0] == u32(0) and b.view(1)[0].wds == 1 {
                dd = i32(1) if i < nd else i32(0);
                break;
            }
            if not (i < nd) {
                dd = -1;
                break;
            }
        }
    }
    Bfree(b);
    Bfree(d);
    if dd > 0 or (dd == 0 and odd != u32(0)) {
        return (i32(0), rv + sulp(rv, scale));
    }
    return (i32(0), rv);
}

impl rv_alloc(i: i32) -> ptr[u8] {
    j: i64 = 4;
    k: i32 = 0;
    while Bigint_SIZE - 4 - 4 + j <= i64(i) {
        j = j << 1;
        k += 1;
    }
    r = ptr[i32](Balloc(k));
    if not r {
        return ptr[u8]();
    }
    r.view(1)[0] = k;
    return ptr[u8](r + 1);
}

impl nrv_alloc(s: ptr[u8], rve: ptr[ptr[u8]], n: i32) -> ptr[u8] {
    rv = rv_alloc(n);
    if not rv {
        return rv;
    }
    t = rv;
    src = s;
    while True {
        ch = src.view(1)[0];
        t.view(1)[0] = ch;
        src = src + 1;
        if ch == u8(0) {
            break;
        }
        t = t + 1;
    }
    if rve {
        rve.view(1)[0] = t;
    }
    return rv;
}

impl bump_up(s: ptr[u8], s0: ptr[u8], k: i32) -> tuple[ptr[u8], i32] {
    while True {
        s = s - 1;
        if s.view(1)[0] != CH_9 {
            break;
        }
        if int(s) == int(s0) {
            k += 1;
            s.view(1)[0] = CH_0;
            break;
        }
    }
    s.view(1)[0] = s.view(1)[0] + u8(1);
    return (s + 1, k);
}

impl strip_zeros(s: ptr[u8]) -> ptr[u8] {
    while True {
        s = s - 1;
        if s.view(1)[0] != CH_0 {
            break;
        }
    }
    return s + 1;
}

impl dtoa_release(b: ptr[Bigint], S: ptr[Bigint], mhi: ptr[Bigint], mlo: ptr[Bigint]) {
    Bfree(S);
    if mlo and int(mlo) != int(mhi) {
        Bfree(mlo);
    }
    Bfree(mhi);
    Bfree(b);
}

impl dtoa_bignum(
    b: ptr[Bigint],
    u: f64,
    mode: i32,
    ndigits: i32,
    k: i32,
    k_check: bool,
    leftright: bool,
    ilim: i32,
    ilim1: i32,
    be: i32,
    bbits: i32,
    denorm: bool,
    b2: i32,
    b5: i32,
    s2: i32,
    s5: i32,
    s0: ptr[u8],
    s: ptr[u8]
) -> tuple[bool, ptr[u8], i32] {
    S = ptr[Bigint]();
    mhi = ptr[Bigint]();
    mlo = ptr[Bigint]();
    m2 = b2;
    m5 = b5;
    i: i32 = 0;
    j: i32 = 0;
    if leftright {
        if denorm {
            i = be + (Bias + (P - 1) - 1 + 1);
        } else {
            i = 1 + P - bbits;
        }
        b2 += i;
        s2 += i;
        mhi = i2b(1);
        if not mhi {
            dtoa_release(b, S, mhi, mlo);
            return (False, s, k);
        }
    }
    if m2 > 0 and s2 > 0 {
        i = m2 if m2 < s2 else s2;
        b2 -= i;
        m2 -= i;
        s2 -= i;
    }
    if b5 > 0 {
        if leftright {
            if m5 > 0 {
                mhi = pow5mult(mhi, m5);
                if not mhi {
                    dtoa_release(b, S, mhi, mlo);
                    return (False, s, k);
                }
                b1 = mult(mhi, b);
                Bfree(b);
                b = b1;
                if not b {
                    dtoa_release(b, S, mhi, mlo);
                    return (False, s, k);
                }
            }
            j = b5 - m5;
            if j != 0 {
                b = pow5mult(b, j);
                if not b {
                    dtoa_release(b, S, mhi, mlo);
                    return (False, s, k);
                }
            }
        } else {
            b = pow5mult(b, b5);
            if not b {
                dtoa_release(b, S, mhi, mlo);
                return (False, s, k);
            }
        }
    }
    S = i2b(1);
    if not S {
        dtoa_release(b, S, mhi, mlo);
        return (False, s, k);
    }
    if s5 > 0 {
        S = pow5mult(S, s5);
        if not S {
            dtoa_release(b, S, mhi, mlo);
            return (False, s, k);
        }
    }

    spec_case = False;
    if mode < 2 or leftright {
        if word1(u) == u32(0)
            and (word0(u) & Bndry_mask) == u32(0)
            and (word0(u) & (Exp_mask & u32(0x7fe00000))) != u32(0) {
            b2 += Log2P;
            s2 += Log2P;
            spec_case = True;
        }
    }

    i = dshift(S, s2);
    b2 += i;
    m2 += i;
    s2 += i;
    if b2 > 0 {
        b = lshift(b, b2);
        if not b {
            dtoa_release(b, S, mhi, mlo);
            return (False, s, k);
        }
    }
    if s2 > 0 {
        S = lshift(S, s2);
        if not S {
            dtoa_release(b, S, mhi, mlo);
            return (False, s, k);
        }
    }
    if k_check {
        if cmp(b, S) < 0 {
            k -= 1;
            b = multadd(b, 10, 0);
            if not b {
                dtoa_release(b, S, mhi, mlo);
                return (False, s, k);
            }
            if leftright {
                mhi = multadd(mhi, 10, 0);
                if not mhi {
                    dtoa_release(b, S, mhi, mlo);
                    return (False, s, k);
                }
            }
            ilim = ilim1;
        }
    }
    if ilim <= 0 and (mode == 3 or mode == 5) {
        no_digits = False;
        if ilim < 0 {
            no_digits = True;
        } else {
            S = multadd(S, 5, 0);
            if not S {
                dtoa_release(b, S, mhi, mlo);
                return (False, s, k);
            }
            if cmp(b, S) <= 0 {
                no_digits = True;
            }
        }
        if no_digits {
            k = -1 - ndigits;
        } else {
            s.view(1)[0] = CH_1;
            s = s + 1;
            k += 1;
        }
        dtoa_release(b, S, mhi, mlo);
        return (True, s, k);
    }
    dig: i32 = 0;
    roundoff = False;
    finished = False;
    if leftright {
        if m2 > 0 {
            mhi = lshift(mhi, m2);
            if not mhi {
                dtoa_release(b, S, mhi, mlo);
                return (False, s, k);
            }
        }

        mlo = mhi;
        if spec_case {
            mhi = Balloc(mhi.view(1)[0].k);
            if not mhi {
                dtoa_release(b, S, mhi, mlo);
                return (False, s, k);
            }
            Bcopy(mhi, mlo);
            mhi = lshift(mhi, Log2P);
            if not mhi {
                dtoa_release(b, S, mhi, mlo);
                return (False, s, k);
            }
        }

        i = 1;
        while True {
            dig = quorem(b, S) + 48;
            j = cmp(b, mlo);
            delta = diff(S, mhi);
            if not delta {
                dtoa_release(b, S, mhi, mlo);
                return (False, s, k);
            }
            j1: i32 = 1;
            if delta.view(1)[0].sign == 0 {
                j1 = cmp(b, delta);
            }
            Bfree(delta);
            if j1 == 0 and mode != 1 and (word1(u) & u32(1)) == u32(0) {
                if dig == 57 {
                    s.view(1)[0] = CH_9;
                    s = s + 1;
                    roundoff = True;
                    break;
                }
                if j > 0 {
                    dig += 1;
                }
                s.view(1)[0] = u8(dig);
                s = s + 1;
                finished = True;
                break;
            }
            if j < 0 or (j == 0 and mode != 1 and (word1(u) & u32(1)) == u32(0)) {
                if not (digits_of(b).view(1)[0] == u32(0) and b.view(1)[0].wds <= 1) {
                    if j1 > 0 {
                        b = lshift(b, 1);
                        if not b {
                            dtoa_release(b, S, mhi, mlo);
                            return (False, s, k);
                        }
                        j1 = cmp(b, S);
                        if j1 > 0 or (j1 == 0 and (dig & 1) != 0) {
                            was = dig;
                            dig += 1;
                            if was == 57 {
                                s.view(1)[0] = CH_9;
                                s = s + 1;
                                roundoff = True;
                                break;
                            }
                        }
                    }
                }
                s.view(1)[0] = u8(dig);
                s = s + 1;
                finished = True;
                break;
            }
            if j1 > 0 {
                if dig == 57 {
                    s.view(1)[0] = CH_9;
                    s = s + 1;
                    roundoff = True;
                    break;
                }
                s.view(1)[0] = u8(dig + 1);
                s = s + 1;
                finished = True;
                break;
            }
            s.view(1)[0] = u8(dig);
            s = s + 1;
            if i == ilim {
                break;
            }
            b = multadd(b, 10, 0);
            if not b {
                dtoa_release(b, S, mhi, mlo);
                return (False, s, k);
            }
            if int(mlo) == int(mhi) {
                mhi = multadd(mhi, 10, 0);
                mlo = mhi;
                if not mlo {
                    dtoa_release(b, S, mhi, mlo);
                    return (False, s, k);
                }
            } else {
                mlo = multadd(mlo, 10, 0);
                if not mlo {
                    dtoa_release(b, S, mhi, mlo);
                    return (False, s, k);
                }
                mhi = multadd(mhi, 10, 0);
                if not mhi {
                    dtoa_release(b, S, mhi, mlo);
                    return (False, s, k);
                }
            }
            i += 1;
        }
    } else {
        i = 1;
        while True {
            dig = quorem(b, S) + 48;
            s.view(1)[0] = u8(dig);
            s = s + 1;
            if digits_of(b).view(1)[0] == u32(0) and b.view(1)[0].wds <= 1 {
                finished = True;
                break;
            }
            if i >= ilim {
                break;
            }
            b = multadd(b, 10, 0);
            if not b {
                dtoa_release(b, S, mhi, mlo);
                return (False, s, k);
            }
            i += 1;
        }
    }

    if finished {
        dtoa_release(b, S, mhi, mlo);
        return (True, s, k);
    }

    if not roundoff {
        b = lshift(b, 1);
        if not b {
            dtoa_release(b, S, mhi, mlo);
            return (False, s, k);
        }
        j = cmp(b, S);
        if j > 0 or (j == 0 and (dig & 1) != 0) {
            roundoff = True;
        } else {
            s = strip_zeros(s);
        }
    }
    if roundoff {
        carried = False;
        while True {
            s = s - 1;
            if s.view(1)[0] != CH_9 {
                break;
            }
            if int(s) == int(s0) {
                k += 1;
                s.view(1)[0] = CH_1;
                s = s + 1;
                carried = True;
                break;
            }
        }
        if not carried {
            s.view(1)[0] = s.view(1)[0] + u8(1);
            s = s + 1;
        }
    }
    dtoa_release(b, S, mhi, mlo);
    return (True, s, k);
}
