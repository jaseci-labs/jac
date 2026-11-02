impl cg_wildcard_check(p: pattern) -> bool {
    return isinstance(p, MatchAs) and p.name is None;
}

impl cg_wildcard_star_check(p: pattern) -> bool {
    return isinstance(p, MatchStar) and p.name is None;
}

impl cg_ensure_fail_pop(c: cpy_compiler, pc: cpy_pattern_context, n: int) {
    size = n + 1;
    while len(pc.fail_pop) < size {
        pc.fail_pop.append(cg_new_label(c));
    }
}

impl cg_jump_to_fail_pop(
    c: cpy_compiler, loc: srcloc, pc: cpy_pattern_context, op: int
) {
    pops = pc.on_top + len(pc.stores);
    cg_ensure_fail_pop(c, pc, pops);
    cg_addop_j(c, op, pc.fail_pop[pops], loc);
}

impl cg_emit_and_reset_fail_pop(c: cpy_compiler, loc: srcloc, pc: cpy_pattern_context) {
    size = len(pc.fail_pop);
    if size == 0 {
        return;
    }
    size -= 1;
    while size > 0 {
        cg_use_label(c, pc.fail_pop[size]);
        cg_addop(c, OP_POP_TOP, loc);
        size -= 1;
    }
    cg_use_label(c, pc.fail_pop[0]);
    pc.fail_pop = [];
}

impl cg_error_duplicate_store(c: cpy_compiler, loc: srcloc, n: str) {
    cpy_compile_error(c, loc, "multiple assignments to name '" + n + "' in pattern");
}

impl cg_pattern_helper_rotate(c: cpy_compiler, loc: srcloc, count: int) {
    while 1 < count {
        cg_addop_i(c, OP_SWAP, count, loc);
        count -= 1;
    }
}

impl cg_pattern_helper_store_name(
    c: cpy_compiler, loc: srcloc, n: str | None, pc: cpy_pattern_context
) {
    if n is None {
        cg_addop(c, OP_POP_TOP, loc);
        return;
    }
    if n in pc.stores {
        cg_error_duplicate_store(c, loc, n);
    }
    rotations = pc.on_top + len(pc.stores) + 1;
    cg_pattern_helper_rotate(c, loc, rotations);
    pc.stores.append(n);
}

impl cg_pattern_unpack_helper(c: cpy_compiler, loc: srcloc, elts: list[pattern]) {
    n = len(elts);
    seen_star = False;
    i = 0;
    while i < n {
        elt = elts[i];
        if isinstance(elt, MatchStar) and not seen_star {
            if i >= (1 << 8) or n - i - 1 >= (2147483647 >> 8) {
                cpy_compile_error(
                    c, loc, "too many expressions in star-unpacking sequence pattern"
                );
            }
            cg_addop_i(c, OP_UNPACK_EX, i + ((n - i - 1) << 8), loc);
            seen_star = True;
        } elif isinstance(elt, MatchStar) {
            cpy_compile_error(
                c, loc, "multiple starred expressions in sequence pattern"
            );
        }
        i += 1;
    }
    if not seen_star {
        cg_addop_i(c, OP_UNPACK_SEQUENCE, n, loc);
    }
}

impl cg_pattern_helper_sequence_unpack(
    c: cpy_compiler,
    loc: srcloc,
    patterns: list[pattern],
    star: int,
    pc: cpy_pattern_context
) {
    cg_pattern_unpack_helper(c, loc, patterns);
    size = len(patterns);
    pc.on_top += size;
    for p in patterns {
        pc.on_top -= 1;
        cg_pattern_subpattern(c, p, pc);
    }
}

impl cg_pattern_helper_sequence_subscr(
    c: cpy_compiler,
    loc: srcloc,
    patterns: list[pattern],
    star: int,
    pc: cpy_pattern_context
) {
    pc.on_top += 1;
    size = len(patterns);
    i = 0;
    while i < size {
        p = patterns[i];
        if cg_wildcard_check(p) or i == star {
            i += 1;
            continue;
        }
        cg_addop_i(c, OP_COPY, 1, loc);
        if i < star {
            cg_load_int(c, i, loc);
        } else {
            cg_addop(c, OP_GET_LEN, loc);
            cg_load_int(c, size - i, loc);
            cg_addop_i(c, OP_BINARY_OP, NB_SUBTRACT, loc);
        }
        cg_addop_i(c, OP_BINARY_OP, NB_SUBSCR, loc);
        cg_pattern_subpattern(c, p, pc);
        i += 1;
    }
    pc.on_top -= 1;
    cg_addop(c, OP_POP_TOP, loc);
}

impl cg_pattern_subpattern(c: cpy_compiler, p: pattern, pc: cpy_pattern_context) {
    allow_irrefutable = pc.allow_irrefutable;
    pc.allow_irrefutable = True;
    cg_pattern(c, p, pc);
    pc.allow_irrefutable = allow_irrefutable;
}

impl cg_pattern_as(c: cpy_compiler, p: MatchAs, pc: cpy_pattern_context) {
    loc = pattern_loc(p);
    sub = p.pattern;
    if sub is None {
        if not pc.allow_irrefutable {
            pname = p.name;
            if pname is not None {
                cpy_compile_error(
                    c,
                    loc,
                    "name capture '" + pname + "' makes remaining patterns unreachable"
                );
            }
            cpy_compile_error(c, loc, "wildcard makes remaining patterns unreachable");
        }
        cg_pattern_helper_store_name(c, loc, p.name, pc);
        return;
    }
    pc.on_top += 1;
    cg_addop_i(c, OP_COPY, 1, loc);
    cg_pattern(c, sub, pc);
    pc.on_top -= 1;
    cg_pattern_helper_store_name(c, loc, p.name, pc);
}

impl cg_pattern_star(c: cpy_compiler, p: MatchStar, pc: cpy_pattern_context) {
    cg_pattern_helper_store_name(c, pattern_loc(p), p.name, pc);
}

impl cg_validate_kwd_attrs(c: cpy_compiler, attrs: list[str], patterns: list[pattern]) {
    nattrs = len(attrs);
    i = 0;
    while i < nattrs {
        attr = attrs[i];
        j = i + 1;
        while j < nattrs {
            if attrs[j] == attr {
                cpy_compile_error(
                    c,
                    pattern_loc(patterns[j]),
                    "attribute name repeated in class pattern: " + attr
                );
            }
            j += 1;
        }
        i += 1;
    }
}

impl cg_pattern_class(c: cpy_compiler, p: MatchClass, pc: cpy_pattern_context) {
    loc = pattern_loc(p);
    patterns = p.patterns;
    kwd_attrs = p.kwd_attrs;
    kwd_patterns = p.kwd_patterns;
    nargs = len(patterns);
    nattrs = len(kwd_attrs);
    nkwd_patterns = len(kwd_patterns);
    if nattrs != nkwd_patterns {
        cpy_compile_error(
            c,
            loc,
            "kwd_attrs ("
                + str(nattrs)
                + ") / kwd_patterns ("
                + str(nkwd_patterns)
                + ") length mismatch in class pattern"
        );
    }
    if nattrs {
        cg_validate_kwd_attrs(c, kwd_attrs, kwd_patterns);
    }
    cg_visit_expr(c, p.cls);
    names: list[PyObj] = [];
    for name in kwd_attrs {
        names.append(PyStr(t="str", val=name));
    }
    cg_load_const(c, PyTuple(t="tuple", items=names), loc);
    cg_addop_i(c, OP_MATCH_CLASS, nargs, loc);
    cg_addop_i(c, OP_COPY, 1, loc);
    cg_load_none(c, loc);
    cg_addop_i(c, OP_IS_OP, 1, loc);
    pc.on_top += 1;
    cg_jump_to_fail_pop(c, loc, pc, OP_POP_JUMP_IF_FALSE);
    cg_addop_i(c, OP_UNPACK_SEQUENCE, nargs + nattrs, loc);
    pc.on_top += nargs + nattrs - 1;
    i = 0;
    while i < nargs + nattrs {
        pc.on_top -= 1;
        sub = patterns[i] if i < nargs else kwd_patterns[i - nargs];
        if cg_wildcard_check(sub) {
            cg_addop(c, OP_POP_TOP, loc);
        } else {
            cg_pattern_subpattern(c, sub, pc);
        }
        i += 1;
    }
}

impl cg_mapping_key_identity(value: PyObj) -> str {
    if isinstance(value, PyBool) {
        return "num:" + ("1" if value.val else "0");
    }
    if isinstance(value, PyInt) {
        return "num:" + str(value.val);
    }
    if isinstance(value, PyBigInt) {
        return "num:" + integer_decimal(value);
    }
    if isinstance(value, PyFloat) {
        fv = value.val;
        if fv == fv and fv > -9.0e18 and fv < 9.0e18 and fv == float(int(fv)) {
            return "num:" + str(int(fv));
        }
        return "float:" + str(id(value)) if fv != fv else "fnum:" + repr(fv);
    }
    if isinstance(value, PyComplex) {
        if value.imag == 0.0 {
            return cg_mapping_key_identity(PyFloat(t="float", val=value.real));
        }
        return "complex:" + repr(value.real) + ":" + repr(value.imag);
    }
    return constant_key(value);
}

impl cg_const_repr(value: PyObj) -> str {
    if isinstance(value, PyStr) {
        return repr(value.val);
    }
    if isinstance(value, PyBool) {
        return "True" if value.val else "False";
    }
    if isinstance(value, PyInt) {
        return str(value.val);
    }
    if isinstance(value, PyBigInt) {
        return integer_decimal(value);
    }
    if isinstance(value, PyFloat) {
        return repr(value.val);
    }
    if isinstance(value, PyBytes) {
        return repr(bytes(value.val));
    }
    if isinstance(value, PyNoneType) {
        return "None";
    }
    if isinstance(value, PyComplex) {
        imag = cg_float_repr_short(value.imag);
        if value.real == 0.0 and not repr(value.real).startswith("-") {
            return imag + "j";
        }
        if not (imag.startswith("-") or imag.startswith("+")) {
            imag = "+" + imag;
        }
        return "(" + cg_float_repr_short(value.real) + imag + "j)";
    }
    return value.t;
}

impl cg_float_repr_short(v: float) -> str {
    text = repr(v);
    if text.endswith(".0") {
        text = text[:len(text) - 2];
    }
    return text;
}

impl cg_pattern_mapping_key(c: cpy_compiler, seen: set[str], p: MatchMapping, i: int) {
    key = p.keys[i];
    if key is None {
        cpy_compile_error(
            c,
            pattern_loc(p.patterns[i]),
            "can't use NULL keys in MatchMapping (set 'rest' parameter instead)"
        );
        return;
    }
    if isinstance(key, Constant) {
        ident = cg_mapping_key_identity(key.value);
        if ident in seen {
            cpy_compile_error(
                c,
                pattern_loc(p),
                "mapping pattern checks duplicate key ("
                    + cg_const_repr(key.value)
                    + ")"
            );
        }
        seen.add(ident);
    } elif not isinstance(key, Attribute) {
        cpy_compile_error(
            c,
            pattern_loc(p),
            "mapping pattern keys may only match literals and attribute lookups"
        );
    }
    cg_visit_expr(c, key);
}

impl cg_pattern_mapping(c: cpy_compiler, p: MatchMapping, pc: cpy_pattern_context) {
    loc = pattern_loc(p);
    keys = p.keys;
    patterns = p.patterns;
    size = len(keys);
    npatterns = len(patterns);
    if size != npatterns {
        cpy_compile_error(
            c,
            loc,
            "keys ("
                + str(size)
                + ") / patterns ("
                + str(npatterns)
                + ") length mismatch in mapping pattern"
        );
    }
    star_target = p.rest;
    pc.on_top += 1;
    cg_addop(c, OP_MATCH_MAPPING, loc);
    cg_jump_to_fail_pop(c, loc, pc, OP_POP_JUMP_IF_FALSE);
    if not size and star_target is None {
        pc.on_top -= 1;
        cg_addop(c, OP_POP_TOP, loc);
        return;
    }
    if size {
        cg_addop(c, OP_GET_LEN, loc);
        cg_load_int(c, size, loc);
        cg_addop_i(c, OP_COMPARE_OP, compare_oparg(CMP_GE), loc);
        cg_jump_to_fail_pop(c, loc, pc, OP_POP_JUMP_IF_FALSE);
    }
    seen: set[str] = set();
    i = 0;
    while i < size {
        cg_pattern_mapping_key(c, seen, p, i);
        i += 1;
    }
    cg_addop_i(c, OP_BUILD_TUPLE, size, loc);
    cg_addop(c, OP_MATCH_KEYS, loc);
    pc.on_top += 2;
    cg_addop_i(c, OP_COPY, 1, loc);
    cg_load_none(c, loc);
    cg_addop_i(c, OP_IS_OP, 1, loc);
    cg_jump_to_fail_pop(c, loc, pc, OP_POP_JUMP_IF_FALSE);
    cg_addop_i(c, OP_UNPACK_SEQUENCE, size, loc);
    pc.on_top += size - 1;
    i = 0;
    while i < size {
        pc.on_top -= 1;
        cg_pattern_subpattern(c, patterns[i], pc);
        i += 1;
    }
    pc.on_top -= 2;
    if star_target is not None {
        cg_addop_i(c, OP_BUILD_MAP, 0, loc);
        cg_addop_i(c, OP_SWAP, 3, loc);
        cg_addop_i(c, OP_DICT_UPDATE, 2, loc);
        cg_addop_i(c, OP_UNPACK_SEQUENCE, size, loc);
        while size {
            cg_addop_i(c, OP_COPY, 1 + size, loc);
            size -= 1;
            cg_addop_i(c, OP_SWAP, 2, loc);
            cg_addop(c, OP_DELETE_SUBSCR, loc);
        }
        cg_pattern_helper_store_name(c, loc, star_target, pc);
    } else {
        cg_addop(c, OP_POP_TOP, loc);
        cg_addop(c, OP_POP_TOP, loc);
    }
}

impl cg_pattern_or(c: cpy_compiler, p: MatchOr, pc: cpy_pattern_context) {
    loc = pattern_loc(p);
    end = cg_new_label(c);
    size = len(p.patterns);
    old_stores = pc.stores;
    old_allow_irrefutable = pc.allow_irrefutable;
    old_fail_pop = pc.fail_pop;
    old_on_top = pc.on_top;
    control: list[str] | None = None;
    i = 0;
    while i < size {
        alt = p.patterns[i];
        aloc = pattern_loc(alt);
        pc.stores = [];
        pc.allow_irrefutable = i == size - 1 and old_allow_irrefutable;
        pc.fail_pop = [];
        pc.on_top = 0;
        cg_addop_i(c, OP_COPY, 1, aloc);
        cg_pattern(c, alt, pc);
        nstores = len(pc.stores);
        if i == 0 {
            control = pc.stores;
        } elif control is not None and nstores != len(control) {
            cpy_compile_error(c, loc, "alternative patterns bind different names");
        } elif control is not None and nstores {
            icontrol = nstores;
            while icontrol > 0 {
                icontrol -= 1;
                name = control[icontrol];
                if name not in pc.stores {
                    cpy_compile_error(
                        c, loc, "alternative patterns bind different names"
                    );
                }
                istores = pc.stores.index(name);
                if icontrol != istores {
                    rotations = istores + 1;
                    rotated = pc.stores[0:rotations];
                    rest = pc.stores[rotations:];
                    at = icontrol - istores;
                    pc.stores = rest[0:at] + rotated + rest[at:];
                    while rotations > 0 {
                        rotations -= 1;
                        cg_pattern_helper_rotate(c, aloc, icontrol + 1);
                    }
                }
            }
        }
        cg_addop_j(c, OP_JUMP, end, aloc);
        cg_emit_and_reset_fail_pop(c, aloc, pc);
        i += 1;
    }
    pc.stores = old_stores;
    pc.allow_irrefutable = old_allow_irrefutable;
    pc.fail_pop = old_fail_pop;
    pc.on_top = old_on_top;
    cg_addop(c, OP_POP_TOP, loc);
    cg_jump_to_fail_pop(c, loc, pc, OP_JUMP);
    cg_use_label(c, end);
    ctl: list[str] = control if control is not None else [];
    nstores = len(ctl);
    nrots = nstores + 1 + pc.on_top + len(pc.stores);
    i = 0;
    while i < nstores {
        cg_pattern_helper_rotate(c, loc, nrots);
        name = ctl[i];
        if name in pc.stores {
            cg_error_duplicate_store(c, loc, name);
        }
        pc.stores.append(name);
        i += 1;
    }
    cg_addop(c, OP_POP_TOP, loc);
}

impl cg_pattern_sequence(c: cpy_compiler, p: MatchSequence, pc: cpy_pattern_context) {
    loc = pattern_loc(p);
    patterns = p.patterns;
    size = len(patterns);
    star = -1;
    only_wildcard = True;
    star_wildcard = False;
    i = 0;
    while i < size {
        sub = patterns[i];
        if isinstance(sub, MatchStar) {
            if star >= 0 {
                cpy_compile_error(c, loc, "multiple starred names in sequence pattern");
            }
            star_wildcard = cg_wildcard_star_check(sub);
            only_wildcard = only_wildcard and star_wildcard;
            star = i;
            i += 1;
            continue;
        }
        only_wildcard = only_wildcard and cg_wildcard_check(sub);
        i += 1;
    }
    pc.on_top += 1;
    cg_addop(c, OP_MATCH_SEQUENCE, loc);
    cg_jump_to_fail_pop(c, loc, pc, OP_POP_JUMP_IF_FALSE);
    if star < 0 {
        cg_addop(c, OP_GET_LEN, loc);
        cg_load_int(c, size, loc);
        cg_addop_i(c, OP_COMPARE_OP, compare_oparg(CMP_EQ), loc);
        cg_jump_to_fail_pop(c, loc, pc, OP_POP_JUMP_IF_FALSE);
    } elif size > 1 {
        cg_addop(c, OP_GET_LEN, loc);
        cg_load_int(c, size - 1, loc);
        cg_addop_i(c, OP_COMPARE_OP, compare_oparg(CMP_GE), loc);
        cg_jump_to_fail_pop(c, loc, pc, OP_POP_JUMP_IF_FALSE);
    }
    pc.on_top -= 1;
    if only_wildcard {
        cg_addop(c, OP_POP_TOP, loc);
    } elif star_wildcard {
        cg_pattern_helper_sequence_subscr(c, loc, patterns, star, pc);
    } else {
        cg_pattern_helper_sequence_unpack(c, loc, patterns, star, pc);
    }
}

impl cg_pattern_value(c: cpy_compiler, p: MatchValue, pc: cpy_pattern_context) {
    loc = pattern_loc(p);
    value = p.value;
    if not (isinstance(value, Constant) or isinstance(value, Attribute)) {
        cpy_compile_error(
            c, loc, "patterns may only match literals and attribute lookups"
        );
    }
    cg_visit_expr(c, value);
    cg_addop_i(c, OP_COMPARE_OP, compare_oparg(CMP_EQ), loc);
    cg_addop(c, OP_TO_BOOL, loc);
    cg_jump_to_fail_pop(c, loc, pc, OP_POP_JUMP_IF_FALSE);
}

impl cg_pattern_singleton(c: cpy_compiler, p: MatchSingleton, pc: cpy_pattern_context) {
    loc = pattern_loc(p);
    cg_load_const(c, p.value, loc);
    cg_addop_i(c, OP_IS_OP, 0, loc);
    cg_jump_to_fail_pop(c, loc, pc, OP_POP_JUMP_IF_FALSE);
}

impl cg_pattern(c: cpy_compiler, p: pattern, pc: cpy_pattern_context) {
    if isinstance(p, MatchValue) {
        cg_pattern_value(c, p, pc);
    } elif isinstance(p, MatchSingleton) {
        cg_pattern_singleton(c, p, pc);
    } elif isinstance(p, MatchSequence) {
        cg_pattern_sequence(c, p, pc);
    } elif isinstance(p, MatchMapping) {
        cg_pattern_mapping(c, p, pc);
    } elif isinstance(p, MatchClass) {
        cg_pattern_class(c, p, pc);
    } elif isinstance(p, MatchStar) {
        cg_pattern_star(c, p, pc);
    } elif isinstance(p, MatchAs) {
        cg_pattern_as(c, p, pc);
    } elif isinstance(p, MatchOr) {
        cg_pattern_or(c, p, pc);
    } else {
        cpy_compile_error(c, pattern_loc(p), "invalid match pattern node in AST");
    }
}

impl cg_match(c: cpy_compiler, s: Match) {
    pc = cpy_pattern_context(stores=[], fail_pop=[]);
    cg_visit_expr(c, s.subject);
    end = cg_new_label(c);
    cases = len(s.cases);
    m = s.cases[cases - 1];
    has_default = 1 if cg_wildcard_check(m.pattern) and 1 < cases else 0;
    i = 0;
    while i < cases - has_default {
        m = s.cases[i];
        ploc = pattern_loc(m.pattern);
        if i != cases - has_default - 1 {
            cg_addop_i(c, OP_COPY, 1, ploc);
        }
        pc.stores = [];
        pc.allow_irrefutable = m.guard is not None or i == cases - 1;
        pc.fail_pop = [];
        pc.on_top = 0;
        cg_pattern(c, m.pattern, pc);
        for name in pc.stores {
            cg_nameop(c, ploc, name, CG_STORE);
        }
        guard = m.guard;
        if guard is not None {
            cg_ensure_fail_pop(c, pc, 0);
            cg_jump_if(c, ploc, guard, pc.fail_pop[0], False);
        }
        if i != cases - has_default - 1 {
            cg_addop(c, OP_POP_TOP, next_location());
        }
        cg_visit_stmts(c, m.body);
        cg_addop_j(c, OP_JUMP, end, no_location());
        cg_emit_and_reset_fail_pop(c, ploc, pc);
        i += 1;
    }
    if has_default {
        m = s.cases[cases - 1];
        ploc = pattern_loc(m.pattern);
        if cases == 1 {
            cg_addop(c, OP_POP_TOP, ploc);
        } else {
            cg_addop(c, OP_NOP, ploc);
        }
        guard = m.guard;
        if guard is not None {
            cg_jump_if(c, ploc, guard, end, False);
        }
        cg_visit_stmts(c, m.body);
    }
    cg_use_label(c, end);
}
