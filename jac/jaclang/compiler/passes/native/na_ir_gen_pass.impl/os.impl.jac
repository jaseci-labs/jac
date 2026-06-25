"""os / os.path module codegen: lower `os.<fn>` and `os.path.<fn>` to libc.

Mechanism A/H (issues #6404 / #6940). Flat `os.*` calls map to libc (getpid/
getcwd/getenv/chdir/mkdir/makedirs/rmdir/unlink/rename/system); makedirs is the
classic `mkdir -p` loop over libc mkdir. `os.path.*` covers the workhorse string
ops (join/basename/dirname) plus the syscall-backed ones (exists/isfile/isdir
via access/stat, realpath via libc realpath(3)). The pure-string helpers
(split/splitext/normpath/...) live in the Mechanism-B bundled `os.path` module
(`runtimelib/na_stdlib/os/path.na.jac`), reached via `import from os.path`.

The struct-stat st_mode offset (24) is the x86-64 Linux glibc layout; like
sys.byteorder this assumes the AOT target is the host arch.
"""

"""Lower a flat `os.<fn>(args)` call to libc. Returns None for void ops."""
impl NaIRGenPass._emit_os_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    params = nd.params or [];

    if name == "getpid" {
        fn = self._get_or_declare_extern("getpid", i32, []);
        pid = self.builder.call(fn, [], name="os.getpid");
        return self.builder.sext(pid, i64, name="os.getpid.i64");
    }

    if name == "getcwd" {
        buf = self.builder.alloca(ir.ArrayType(ir.IntType(8), 4096), name="os.cwd.buf");
        bufp = self.builder.gep(
            buf, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="os.cwd.bufp"
        );
        fn = self._get_or_declare_extern("getcwd", i8p, [i8p, i64]);
        self.builder.call(fn, [bufp, ir.Constant(i64, 4096)], name="os.getcwd");
        return self._rc_strdup(bufp, name="os.cwd.str");
    }

    if name == "getenv" {
        if not params {
            return None;
        }
        nameval = self._codegen_expr(params[0]);
        if nameval is None {
            return None;
        }
        fn = self._get_or_declare_extern("getenv", i8p, [i8p]);
        val = self.builder.call(fn, [nameval], name="os.getenv");
        # NULL -> None (unset var); else copy into an RC string.
        func = self.builder.function;
        null_bb = func.append_basic_block(name="getenv.null");
        ok_bb = func.append_basic_block(name="getenv.ok");
        merge_bb = func.append_basic_block(name="getenv.merge");
        is_null = self.builder.icmp_signed(
            "==", val, ir.Constant(i8p, None), name="getenv.isnull"
        );
        self.builder.cbranch(is_null, null_bb, ok_bb);
        self.builder.position_at_end(null_bb);
        # Unset var: Python's `os.getenv(key, default)` returns `default`
        # (and `None` when no default is given). Returning a bare NULL for a
        # 2-arg call whose default is a string made every downstream string op
        # (`len`, `+`, `!=`, ...) `strlen` a NULL pointer and segfault at
        # startup (issue #6688: `os.getenv("QP_SMOKE", "") != ""`).
        null_res: ir.Value = ir.Constant(i8p, None);
        if len(params) >= 2 {
            _default_val = self._codegen_expr(params[1]);
            if _default_val is not None
            and isinstance(_default_val.type, ir.PointerType) {
                null_res = self._coerce_type(_default_val, i8p);
                # os.getenv's result is consumed as an OWNED ref (a FuncCall
                # result), so retain a borrowed default to balance the
                # consumer's release; static literals and owned temporaries are
                # handled by _emit_take_ref's ownership check.
                self._emit_take_ref(null_res, op="getenv_default", loc="");
            }
        }
        self.builder.branch(merge_bb);
        null_end = self.builder.block;
        self.builder.position_at_end(ok_bb);
        copied = self._rc_strdup(val, name="os.getenv.str");
        self.builder.branch(merge_bb);
        ok_end = self.builder.block;
        self.builder.position_at_end(merge_bb);
        phi = self.builder.phi(i8p, name="os.getenv.res");
        phi.add_incoming(null_res, null_end);
        phi.add_incoming(copied, ok_end);
        return phi;
    }

    if name == "system" {
        if not params {
            return None;
        }
        cmd = self._codegen_expr(params[0]);
        if cmd is None {
            return None;
        }
        fn = self._get_or_declare_extern("system", i32, [i8p]);
        rc = self.builder.call(fn, [cmd], name="os.system");
        return self.builder.sext(rc, i64, name="os.system.i64");
    }

    # Single-path-arg void ops.
    _single: dict[str, str] = {
        "chdir": "chdir",
        "rmdir": "rmdir",
        "remove": "unlink",
        "unlink": "unlink",

    };
    if name in _single and params {
        p = self._codegen_expr(params[0]);
        if p is None {
            return None;
        }
        fn = self._get_or_declare_extern(_single[name], i32, [i8p]);
        self.builder.call(fn, [p], name=f"os.{name}");
        return None;
    }

    # os.mkdir(path, mode=0o777)
    if name == "mkdir" and params {
        p = self._codegen_expr(params[0]);
        if p is None {
            return None;
        }
        mode = ir.Constant(i32, 0o777);
        if len(params) >= 2 {
            mv = self._codegen_expr(params[1]);
            if mv is not None {
                mode = self._coerce_type(mv, i32);
            }
        }
        fn = self._get_or_declare_extern("mkdir", i32, [i8p, i32]);
        self.builder.call(fn, [p, mode], name="os.mkdir");
        return None;
    }

    # os.makedirs(path, mode=0o777): create every leading directory component,
    # then the leaf. Implemented as the classic `mkdir -p` over libc mkdir
    # (issue #6940 Phase 1): the path is copied into a mutable scratch buffer and
    # walked; at each '/' the prefix is NUL-terminated in place, mkdir'd (EEXIST
    # on an existing prefix is ignored, exactly as `mkdir -p`), then the '/'
    # restored. NB: unlike CPython's `exist_ok=False` default, an already-existing
    # leaf is not an error here -- a documented divergence on the unsupported edge.
    if name == "makedirs" and params {
        p = self._codegen_expr(params[0]);
        if p is None {
            return None;
        }
        mode = ir.Constant(i32, 0o777);
        if len(params) >= 2 {
            mv = self._codegen_expr(params[1]);
            if mv is not None {
                mode = self._coerce_type(mv, i32);
            }
        }
        strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
        memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        mkdir_fn = self._get_or_declare_extern("mkdir", i32, [i8p, i32]);
        malloc_fn = self._get_or_declare_extern("malloc", i8p, [i64]);
        free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
        plen = self.builder.call(strlen_fn, [p], name="mkdirs.len");
        # Heap scratch sized to the path (incl. NUL) so it can be mutated in
        # place. A fixed-size stack buffer would overflow for a path at/above its
        # capacity (the path is an arbitrary-length caller argument), so the
        # buffer is malloc'd to plen+1 and freed before returning.
        copy_n = self.builder.add(plen, ir.Constant(i64, 1), name="mkdirs.copyn");
        bufp = self.builder.call(malloc_fn, [copy_n], name="mkdirs.buf");
        self.builder.call(memcpy_fn, [bufp, p, copy_n]);
        i_ptr = self.builder.alloca(i64, name="mkdirs.i");
        # Start at 1 so a leading '/' (POSIX root) is never NUL-terminated alone.
        self.builder.store(ir.Constant(i64, 1), i_ptr);
        func = self.builder.function;
        head_bb = func.append_basic_block(name="mkdirs.head");
        body_bb = func.append_basic_block(name="mkdirs.body");
        slash_bb = func.append_basic_block(name="mkdirs.slash");
        cont_bb = func.append_basic_block(name="mkdirs.cont");
        after_bb = func.append_basic_block(name="mkdirs.after");
        self.builder.branch(head_bb);
        self.builder.position_at_end(head_bb);
        i_val = self.builder.load(i_ptr, name="mkdirs.iv");
        loop_cond = self.builder.icmp_signed("<", i_val, plen, name="mkdirs.cond");
        self.builder.cbranch(loop_cond, body_bb, after_bb);
        self.builder.position_at_end(body_bb);
        ch_ptr = self.builder.gep(bufp, [i_val], name="mkdirs.chp");
        ch = self.builder.load(ch_ptr, name="mkdirs.ch");
        is_slash = self.builder.icmp_signed(
            "==", ch, ir.Constant(i8, 47), name="mkdirs.issl"
        );
        self.builder.cbranch(is_slash, slash_bb, cont_bb);
        self.builder.position_at_end(slash_bb);
        self.builder.store(ir.Constant(i8, 0), ch_ptr);
        self.builder.call(mkdir_fn, [bufp, mode], name="mkdirs.mid");
        self.builder.store(ir.Constant(i8, 47), ch_ptr);
        self.builder.branch(cont_bb);
        self.builder.position_at_end(cont_bb);
        next_i = self.builder.add(i_val, ir.Constant(i64, 1), name="mkdirs.next");
        self.builder.store(next_i, i_ptr);
        self.builder.branch(head_bb);
        self.builder.position_at_end(after_bb);
        # Finally create the full (leaf) path, then release the scratch buffer.
        self.builder.call(mkdir_fn, [bufp, mode], name="mkdirs.leaf");
        self.builder.call(free_fn, [bufp], name="mkdirs.free");
        return None;
    }

    # os.rename(src, dst)
    if name == "rename" and len(params) >= 2 {
        src = self._codegen_expr(params[0]);
        dst = self._codegen_expr(params[1]);
        if src is None or dst is None {
            return None;
        }
        fn = self._get_or_declare_extern("rename", i32, [i8p, i8p]);
        self.builder.call(fn, [src, dst], name="os.rename");
        return None;
    }

    return None;
}

"""Lower `os.path.<fn>(args)`. join/basename/dirname are string ops;
exists/isfile/isdir use access/stat. Returns None if unsupported."""
impl NaIRGenPass._emit_ospath_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    params = nd.params or [];

    # os.path.join(a, b, ...): fold left. b absolute (leading '/') resets the
    # accumulator; a trailing '/' on the accumulator avoids a doubled separator.
    if name == "join" and params {
        acc = self._codegen_expr(params[0]);
        if acc is None {
            return None;
        }
        sep = self._make_global_string("/", name_prefix=".ospath.sep");
        strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
        for idx in range(1, len(params)) {
            b = self._codegen_expr(params[idx]);
            if b is None {
                return None;
            }
            # b[0] == '/'  -> b is absolute, replaces acc.
            b0 = self.builder.load(b, name="join.b0");
            b_abs = self.builder.icmp_signed(
                "==", b0, ir.Constant(i8, 47), name="join.babs"
            );
            # acc ends with '/'?
            alen = self.builder.call(strlen_fn, [acc], name="join.alen");
            a_empty = self.builder.icmp_signed(
                "==", alen, ir.Constant(i64, 0), name="join.aempty"
            );
            last_idx = self.builder.sub(alen, ir.Constant(i64, 1), name="join.lastidx");
            last_ptr = self.builder.gep(acc, [last_idx], name="join.lastptr");
            last_ch = self.builder.load(last_ptr, name="join.lastch");
            a_slash = self.builder.icmp_signed(
                "==", last_ch, ir.Constant(i8, 47), name="join.aslash"
            );
            # need_sep = not b_abs and not a_empty and not a_slash
            no_sep = self.builder.or_(a_empty, a_slash, name="join.nosep0");
            no_sep = self.builder.or_(no_sep, b_abs, name="join.nosep");
            with_sep = self._emit_binary_op(Tok.PLUS, acc, sep);
            joined_sep = self._emit_binary_op(Tok.PLUS, with_sep, b);
            joined_nosep = self._emit_binary_op(Tok.PLUS, acc, b);
            # absolute b: result is just b.
            picked = self.builder.select(
                no_sep, joined_nosep, joined_sep, name="join.pick"
            );
            acc = self.builder.select(b_abs, b, picked, name="join.acc");
        }
        return acc;
    }

    # os.path.basename(p): substring after the last '/'.
    if name == "basename" and params {
        p = self._codegen_expr(params[0]);
        if p is None {
            return None;
        }
        strrchr_fn = self._get_or_declare_extern("strrchr", i8p, [i8p, i32]);
        hit = self.builder.call(strrchr_fn, [p, ir.Constant(i32, 47)], name="bn.hit");
        is_null = self.builder.icmp_signed(
            "==", hit, ir.Constant(i8p, None), name="bn.isnull"
        );
        # start = hit ? hit+1 : p
        after = self.builder.gep(hit, [ir.Constant(i64, 1)], name="bn.after");
        start = self.builder.select(is_null, p, after, name="bn.start");
        return self._rc_strdup(start, name="bn.str");
    }

    # os.path.dirname(p): everything before the last '/' (or "" if none).
    if name == "dirname" and params {
        p = self._codegen_expr(params[0]);
        if p is None {
            return None;
        }
        strrchr_fn = self._get_or_declare_extern("strrchr", i8p, [i8p, i32]);
        hit = self.builder.call(strrchr_fn, [p, ir.Constant(i32, 47)], name="dn.hit");
        func = self.builder.function;
        none_bb = func.append_basic_block(name="dn.none");
        cut_bb = func.append_basic_block(name="dn.cut");
        merge_bb = func.append_basic_block(name="dn.merge");
        is_null = self.builder.icmp_signed(
            "==", hit, ir.Constant(i8p, None), name="dn.isnull"
        );
        self.builder.cbranch(is_null, none_bb, cut_bb);
        self.builder.position_at_end(none_bb);
        empty_res = self._make_global_string("", name_prefix=".dirname.empty");
        self.builder.branch(merge_bb);
        none_end = self.builder.block;
        self.builder.position_at_end(cut_bb);
        # len = hit - p  (chars before the last '/')
        hit_i = self.builder.ptrtoint(hit, i64, name="dn.hiti");
        p_i = self.builder.ptrtoint(p, i64, name="dn.pi");
        dlen = self.builder.sub(hit_i, p_i, name="dn.len");
        bufsz = self.builder.add(dlen, ir.Constant(i64, 1), name="dn.bufsz");
        self._set_rc_ctx("dirname", "");
        raw = self._rc_alloc(bufsz, name="dn.raw");
        self._clear_rc_ctx();
        memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        self.builder.call(memcpy_fn, [raw, p, dlen]);
        nul_ptr = self.builder.gep(raw, [dlen], name="dn.nulptr");
        self.builder.store(ir.Constant(i8, 0), nul_ptr);
        self._emit_set_type_tag(self.builder, raw, "str");
        self._mark_owned(raw);
        self.builder.branch(merge_bb);
        cut_end = self.builder.block;
        self.builder.position_at_end(merge_bb);
        phi = self.builder.phi(i8p, name="dn.res");
        phi.add_incoming(empty_res, none_end);
        phi.add_incoming(raw, cut_end);
        return phi;
    }

    # os.path.realpath(p): libc realpath(3) into a PATH_MAX buffer (issue #6940
    # Phase 1). realpath resolves symlinks + makes absolute; for an existing path
    # it agrees with CPython's posixpath.realpath. On error (NULL return, e.g. a
    # missing component) fall back to a copy of the input rather than raise --
    # CPython's realpath is likewise non-strict by default.
    if name == "realpath" and params {
        p = self._codegen_expr(params[0]);
        if p is None {
            return None;
        }
        buf = self.builder.alloca(ir.ArrayType(i8, 4096), name="rp.buf");
        bufp = self.builder.gep(
            buf, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="rp.bufp"
        );
        fn = self._get_or_declare_extern("realpath", i8p, [i8p, i8p]);
        res = self.builder.call(fn, [p, bufp], name="rp.call");
        func = self.builder.function;
        null_bb = func.append_basic_block(name="rp.null");
        ok_bb = func.append_basic_block(name="rp.ok");
        merge_bb = func.append_basic_block(name="rp.merge");
        is_null = self.builder.icmp_signed(
            "==", res, ir.Constant(i8p, None), name="rp.isnull"
        );
        self.builder.cbranch(is_null, null_bb, ok_bb);
        self.builder.position_at_end(null_bb);
        fallback = self._rc_strdup(p, name="rp.fallback");
        self.builder.branch(merge_bb);
        null_end = self.builder.block;
        self.builder.position_at_end(ok_bb);
        resolved = self._rc_strdup(bufp, name="rp.str");
        self.builder.branch(merge_bb);
        ok_end = self.builder.block;
        self.builder.position_at_end(merge_bb);
        phi = self.builder.phi(i8p, name="rp.res");
        phi.add_incoming(fallback, null_end);
        phi.add_incoming(resolved, ok_end);
        return phi;
    }

    # os.path.exists(p): access(p, F_OK) == 0
    if name == "exists" and params {
        p = self._codegen_expr(params[0]);
        if p is None {
            return None;
        }
        fn = self._get_or_declare_extern("access", i32, [i8p, i32]);
        rc = self.builder.call(fn, [p, ir.Constant(i32, 0)], name="ospath.access");
        return self.builder.icmp_signed(
            "==", rc, ir.Constant(i32, 0), name="ospath.exists"
        );
    }

    # os.path.isfile / isdir: stat(p, &buf); inspect st_mode (offset 24, i32).
    if (name == "isfile" or name == "isdir") and params {
        p = self._codegen_expr(params[0]);
        if p is None {
            return None;
        }
        # struct stat is 144 bytes on x86-64 Linux; st_mode is a 32-bit field
        # at byte offset 24.
        buf = self.builder.alloca(ir.ArrayType(i8, 144), name="stat.buf");
        bufp = self.builder.gep(
            buf, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="stat.bufp"
        );
        fn = self._get_or_declare_extern("stat", i32, [i8p, i8p]);
        rc = self.builder.call(fn, [p, bufp], name="ospath.stat");
        ok = self.builder.icmp_signed("==", rc, ir.Constant(i32, 0), name="stat.ok");
        mode_p8 = self.builder.gep(bufp, [ir.Constant(i64, 24)], name="stat.modep8");
        mode_p = self.builder.bitcast(mode_p8, i32.as_pointer(), name="stat.modep");
        mode = self.builder.load(mode_p, name="stat.mode");
        fmt = self.builder.and_(mode, ir.Constant(i32, 0o170000), name="stat.fmt");
        want = 0o040000 if name == "isdir" else 0o100000;
        kind = self.builder.icmp_signed(
            "==", fmt, ir.Constant(i32, want), name=f"ospath.{name}.kind"
        );
        return self.builder.and_(ok, kind, name=f"ospath.{name}");
    }

    return None;
}
