glob _PYB_BRIDGE_MODULE: str = "jaclang.runtime.interop_bridge";

impl NaIRGenPass._pyb_base_of(arch_name: str) -> (tuple | None) {
    """The first Python-side base on `arch_name`'s MRO, as (name, path).

    A base counts as Python-side when its symbol resolves to a jac
    archetype in a module the native import walk did not register, which
    is exactly the cross-module-trust "layout only" case. Bases that are
    native (same unit or linked import) recurse so a native class over a
    Python-based native class classifies the same way.

    A subscripted generic base (`PyGenBase[int]`) is unwrapped to its
    target before resolution: the subscript is type-position information
    the bridge does not need, and leaving it wrapped made the base
    invisible, so stores to inherited fields demoted instead of
    bridging. The shape was found on the compiler's own pass chain, back
    when it spelled `Transform[Module, Module]`; the chain is
    monomorphic now, and user code still writes it.

    A base the native lane erases at compile time is never Python-side, even
    when its declaration is reachable: `NATIVE_ERASED_BASES` names the
    bases lowering drops outright, so they contribute no shadow and no
    slots. The distinction only became observable once `PassRim` moved
    from a `.py` to a `.jac`, which made its declaration resolvable while
    the base claim -- an admission about the *base*, not about the unit --
    stayed the same. Resolving one is not the same as inheriting one.
    """;
    import os;
    import from jaclang.compiler.frontend.codeinfo { NATIVE_ERASED_BASES }
    if arch_name in self._pyb_base_memo {
        cached = self._pyb_base_memo[arch_name];
        return cached;
    }
    self._pyb_base_memo[arch_name] = None;
    arch = self.arch_ast_map.get(arch_name);
    if not isinstance(arch, uni.Archetype) {
        return None;
    }
    if arch.arch_kind is not None or self._arch_is_osp_name(arch_name) {
        return None;
    }
    _own_path = os.path.realpath(self.ir_in.loc.mod_path) if self.ir_in?.loc else "";
    for base_expr in (arch.base_classes or []) {
        if isinstance(base_expr, uni.AtomTrailer)
            and isinstance(base_expr.right, uni.IndexSlice) {
            base_expr = base_expr.target;
        }
        bname = self._get_name(base_expr);
        if bname is None {
            continue;
        }
        if bname in ("Node", "Edge", "Walker", "Object", "Obj", "Root", "Archetype") {
            continue;
        }
        if bname in self.arch_ast_map {
            sub = self._pyb_base_of(bname);
            if sub is not None {
                self._pyb_base_memo[arch_name] = sub;
                return sub;
            }
            continue;
        }
        if bname in NATIVE_ERASED_BASES {
            continue;
        }
        sym = base_expr.sym if isinstance(base_expr, uni.NameAtom) else None;
        decl = sym.decl if sym is not None else None;
        if decl is None {
            continue;
        }
        base_arch = decl.find_parent_of_type(uni.Archetype);
        if base_arch is None {
            continue;
        }
        decl_mod = decl.find_parent_of_type(uni.Module);
        path = decl_mod.loc.mod_path if decl_mod is not None else None;
        if not path or not path.endswith(".jac") {
            continue;
        }
        if os.path.realpath(path) == _own_path {
            continue;
        }
        found = (bname, os.path.abspath(path), );
        self._pyb_base_memo[arch_name] = found;
        return found;
    }
    return None;
}

impl NaIRGenPass._pyb_shadow_postinit_owner(arch_name: str) -> (str | None) {
    """The Python-side ancestor of `arch_name` that owns a `postinit`, if any.

    Construction of a native class over a Python-side base runs that
    base's initializer on the Python shadow, not on the native object.
    When the base chain carries a `postinit`, whatever it stores or
    dispatches lands on the shadow, where the subclass's native slots do
    not exist and its overrides are not on the shadow's class. This walk
    is what names that ancestor so the refusal can point at it.

    Native ancestors are walked through rather than reported: their
    `postinit` lowers (or is demoted with its own diagnostic), so it is
    not a shadow-side initializer. A subscripted base is unwrapped the
    same way `_pyb_base_of` unwraps it.
    """;
    arch = self.arch_ast_map.get(arch_name);
    if not isinstance(arch, uni.Archetype) {
        return None;
    }
    seen: set = {arch_name};
    queue: list = list(arch.base_classes or []);
    while queue {
        base_expr = queue.pop(0);
        if isinstance(base_expr, uni.AtomTrailer)
            and isinstance(base_expr.right, uni.IndexSlice) {
            base_expr = base_expr.target;
        }
        bname = self._get_name(base_expr);
        if bname is None or bname in seen {
            continue;
        }
        seen.add(bname);
        if bname in ("Node", "Edge", "Walker", "Object", "Obj", "Root", "Archetype") {
            continue;
        }
        sym = base_expr.sym if isinstance(base_expr, uni.NameAtom) else None;
        decl = sym.decl if sym is not None else None;
        base_arch = decl.find_parent_of_type(uni.Archetype)
            if decl is not None
            else None;
        if base_arch is None {
            continue;
        }
        if bname not in self.arch_ast_map {
            for stmt in (base_arch.body or []) {
                if isinstance(stmt, uni.Ability)
                    and stmt.name_ref is not None
                    and stmt.name_ref.sym_name in ("postinit", "__post_init__") {
                    return bname;
                }
            }
        }
        queue.extend(base_arch.base_classes or []);
    }
    return None;
}

impl NaIRGenPass._pyb_native_override_owner(arch_name: str, meth: str) -> (str | None) {
    """The native class on `arch_name`'s MRO that owns a live `meth` body.

    A name is a native override only while its body is still native: a
    method already demoted to its Python implementation is served from the
    same place the shadow would find it, so it is no longer a divergence
    and must not be reported as one.
    """;
    for _sc in self._mro_of(arch_name) {
        _k = f"{_sc}.{meth}";
        if _k in self.method_funcs and _k not in self._native_skipped_methods {
            return _sc;
        }
    }
    return None;
}

impl NaIRGenPass._pyb_shadowed_dispatch(
    arch_name: str, method_name: str
) -> (tuple | None) {
    """`(base, dispatched, owner)` when a shadow call would run the wrong body.

    The bridge builds the shadow as `type(name, (base,), {})` -- the
    Python-side base chain and none of the native subclass's bodies. So a
    base method invoked on the shadow resolves `self.X()` against that
    hollow class: it finds the base's own `X`, never the override the
    native subclass declares. The override is skipped and nothing says so
    (#8310), which is the same wrongness class as the hollow construction
    E5088 refuses one call shallower.

    The walk is deliberately narrow. It reports only what it can SEE: a
    Python-side ancestor that declares `method_name`, whose body contains a
    literal `self.X(...)` call, where `X` has a live native override on
    `arch_name`'s MRO. Reflective dispatch (`getattr(self, n)()`), a body
    written inside an inline `::py::` block, and dispatch routed through a
    Python-resident helper are all invisible here and stay unreported --
    this closes the shapes the tree can prove, not every shape that exists.
    """;
    arch = self.arch_ast_map.get(arch_name);
    if not isinstance(arch, uni.Archetype) {
        return None;
    }
    seen: set = {arch_name};
    queue: list = list(arch.base_classes or []);
    while queue {
        base_expr = queue.pop(0);
        if isinstance(base_expr, uni.AtomTrailer)
            and isinstance(base_expr.right, uni.IndexSlice) {
            base_expr = base_expr.target;
        }
        bname = self._get_name(base_expr);
        if bname is None or bname in seen {
            continue;
        }
        seen.add(bname);
        if bname in ("Node", "Edge", "Walker", "Object", "Obj", "Root", "Archetype") {
            continue;
        }
        sym = base_expr.sym if isinstance(base_expr, uni.NameAtom) else None;
        decl = sym.decl if sym is not None else None;
        base_arch = decl.find_parent_of_type(uni.Archetype)
            if decl is not None
            else None;
        if base_arch is None {
            continue;
        }

        if bname not in self.arch_ast_map {
            for stmt in (base_arch.body or []) {
                if not isinstance(stmt, uni.Ability) {
                    continue;
                }
                if stmt.name_ref is None or stmt.name_ref.sym_name != method_name {
                    continue;
                }
                for _call in stmt.get_all_sub_nodes(uni.FuncCall) {
                    _tgt = _call.target;
                    if not isinstance(_tgt, uni.AtomTrailer) or not _tgt.is_attr {
                        continue;
                    }
                    if self._get_name(_tgt.target) != "self" {
                        continue;
                    }
                    _dispatched = self._get_name(_tgt.right);
                    if _dispatched is None {
                        continue;
                    }
                    _owner = self._pyb_native_override_owner(arch_name, _dispatched);
                    if _owner is not None {
                        return (bname, _dispatched, _owner);
                    }
                }
            }
        }
        queue.extend(base_arch.base_classes or []);
    }
    return None;
}

impl NaIRGenPass._pyb_cstr(text: str) -> ir.Value {
    return self._make_global_string(text, name_prefix=".pyb.str");
}

impl NaIRGenPass._pyb_helper(name: str) -> ir.Function {
    """Get-or-emit one of the fixed `__jac_pyb_*` runtime helpers.

    Each helper wraps a short libpython C-API sequence in its own
    PyGILState_Ensure/Release pair, so native code stays correct no
    matter whether its caller held the GIL. A failed call surfaces via
    PyErr_Print (loud on stderr) and a zero value rather than a crash.
    """;
    cached = self._pyb_helper_fns.get(name);
    if cached is not None {
        return cached;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    f64 = ir.DoubleType();
    void = ir.VoidType();
    gil_on = self._get_or_declare_extern("PyGILState_Ensure", i32, []);
    gil_off = self._get_or_declare_extern("PyGILState_Release", void, [i32]);
    err_print = self._get_or_declare_extern("PyErr_Print", void, []);
    fn: (ir.Function | None) = None;
    if name == "from_i64" {
        cfn = self._get_or_declare_extern("PyLong_FromLongLong", i8p, [i64]);
        fn = self._pyb_emit_conv1(name, cfn, i64, i8p, gil_on, gil_off);
    } elif name == "from_bool" {
        cfn = self._get_or_declare_extern("PyBool_FromLong", i8p, [i64]);
        fn = self._pyb_emit_conv1(name, cfn, i64, i8p, gil_on, gil_off);
    } elif name == "from_f64" {
        cfn = self._get_or_declare_extern("PyFloat_FromDouble", i8p, [f64]);
        fn = self._pyb_emit_conv1(name, cfn, f64, i8p, gil_on, gil_off);
    } elif name == "from_cstr" {
        cfn = self._get_or_declare_extern("PyUnicode_FromString", i8p, [i8p]);
        fn = self._pyb_emit_conv1(name, cfn, i8p, i8p, gil_on, gil_off);
    } elif name == "tuple_new" {
        cfn = self._get_or_declare_extern("PyTuple_New", i8p, [i64]);
        fn = self._pyb_emit_conv1(name, cfn, i64, i8p, gil_on, gil_off);
    } elif name == "dict_new" {
        cfn = self._get_or_declare_extern("PyDict_New", i8p, []);
        fn = self._define_function("__jac_pyb_dict_new", ir.FunctionType(i8p, []));
        fn.linkage = "private";
        b = ir.IRBuilder(fn.append_basic_block("entry"));
        g = b.call(gil_on, [], name="gil");
        r = b.call(cfn, [], name="d");
        b.call(gil_off, [g]);
        b.ret(r);
    } elif name == "to_i64" {
        cfn = self._get_or_declare_extern("PyLong_AsLongLong", i64, [i8p]);
        dec = self._get_or_declare_extern("Py_DecRef", void, [i8p]);
        fn = self._define_function("__jac_pyb_to_i64", ir.FunctionType(i64, [i8p]));
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        work = fn.append_basic_block("work");
        b = ir.IRBuilder(`entry);
        isnull = b.icmp_unsigned(
            "==", fn.args[0], ir.Constant(i8p, None), name="isnull"
        );
        null_bb = fn.append_basic_block("null");
        b.cbranch(isnull, null_bb, work);
        b = ir.IRBuilder(null_bb);
        b.ret(ir.Constant(i64, 0));
        b = ir.IRBuilder(work);
        g = b.call(gil_on, [], name="gil");
        v = b.call(cfn, [fn.args[0]], name="v");
        b.call(dec, [fn.args[0]]);
        b.call(gil_off, [g]);
        b.ret(v);
    } elif name == "to_bool" {
        cfn = self._get_or_declare_extern("PyObject_IsTrue", i32, [i8p]);
        dec = self._get_or_declare_extern("Py_DecRef", void, [i8p]);
        fn = self._define_function("__jac_pyb_to_bool", ir.FunctionType(i64, [i8p]));
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        work = fn.append_basic_block("work");
        null_bb = fn.append_basic_block("null");
        b = ir.IRBuilder(`entry);
        isnull = b.icmp_unsigned(
            "==", fn.args[0], ir.Constant(i8p, None), name="isnull"
        );
        b.cbranch(isnull, null_bb, work);
        b = ir.IRBuilder(null_bb);
        b.ret(ir.Constant(i64, 0));
        b = ir.IRBuilder(work);
        g = b.call(gil_on, [], name="gil");
        t = b.call(cfn, [fn.args[0]], name="t");
        b.call(dec, [fn.args[0]]);
        b.call(gil_off, [g]);
        b.ret(b.sext(t, i64, name="t64"));
    } elif name == "to_f64" {
        cfn = self._get_or_declare_extern("PyFloat_AsDouble", f64, [i8p]);
        dec = self._get_or_declare_extern("Py_DecRef", void, [i8p]);
        fn = self._define_function("__jac_pyb_to_f64", ir.FunctionType(f64, [i8p]));
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        work = fn.append_basic_block("work");
        null_bb = fn.append_basic_block("null");
        b = ir.IRBuilder(`entry);
        isnull = b.icmp_unsigned(
            "==", fn.args[0], ir.Constant(i8p, None), name="isnull"
        );
        b.cbranch(isnull, null_bb, work);
        b = ir.IRBuilder(null_bb);
        b.ret(ir.Constant(f64, 0.0));
        b = ir.IRBuilder(work);
        g = b.call(gil_on, [], name="gil");
        v = b.call(cfn, [fn.args[0]], name="v");
        b.call(dec, [fn.args[0]]);
        b.call(gil_off, [g]);
        b.ret(v);
    } elif name == "to_bytes" {
        cfn = self._get_or_declare_extern("PyUnicode_AsUTF8String", i8p, [i8p]);
        dec = self._get_or_declare_extern("Py_DecRef", void, [i8p]);
        fn = self._define_function("__jac_pyb_to_bytes", ir.FunctionType(i8p, [i8p]));
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        work = fn.append_basic_block("work");
        null_bb = fn.append_basic_block("null");
        err_bb = fn.append_basic_block("err");
        ok_bb = fn.append_basic_block("ok");
        b = ir.IRBuilder(`entry);
        isnull = b.icmp_unsigned(
            "==", fn.args[0], ir.Constant(i8p, None), name="isnull"
        );
        b.cbranch(isnull, null_bb, work);
        b = ir.IRBuilder(null_bb);
        b.ret(ir.Constant(i8p, None));
        b = ir.IRBuilder(work);
        g = b.call(gil_on, [], name="gil");
        bt = b.call(cfn, [fn.args[0]], name="b");
        b.call(dec, [fn.args[0]]);
        bnull = b.icmp_unsigned("==", bt, ir.Constant(i8p, None), name="bnull");
        b.cbranch(bnull, err_bb, ok_bb);
        b = ir.IRBuilder(err_bb);
        b.call(err_print, []);
        b.call(gil_off, [g]);
        b.ret(ir.Constant(i8p, None));
        b = ir.IRBuilder(ok_bb);
        b.call(gil_off, [g]);
        b.ret(bt);
    } elif name == "bytes_data" {
        cfn = self._get_or_declare_extern("PyBytes_AsString", i8p, [i8p]);
        fn = self._define_function("__jac_pyb_bytes_data", ir.FunctionType(i8p, [i8p]));
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        work = fn.append_basic_block("work");
        null_bb = fn.append_basic_block("null");
        b = ir.IRBuilder(`entry);
        isnull = b.icmp_unsigned(
            "==", fn.args[0], ir.Constant(i8p, None), name="isnull"
        );
        b.cbranch(isnull, null_bb, work);
        b = ir.IRBuilder(null_bb);
        _saved = self._builder;
        self._builder = b;
        empty = self._pyb_cstr("");
        self._builder = _saved;
        b.ret(empty);
        b = ir.IRBuilder(work);
        g = b.call(gil_on, [], name="gil");
        p = b.call(cfn, [fn.args[0]], name="p");
        b.call(gil_off, [g]);
        b.ret(p);
    } elif name == "drop" {
        dec = self._get_or_declare_extern("Py_DecRef", void, [i8p]);
        fn = self._define_function("__jac_pyb_drop", ir.FunctionType(void, [i8p]));
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        work = fn.append_basic_block("work");
        done = fn.append_basic_block("done");
        b = ir.IRBuilder(`entry);
        isnull = b.icmp_unsigned(
            "==", fn.args[0], ir.Constant(i8p, None), name="isnull"
        );
        b.cbranch(isnull, done, work);
        b = ir.IRBuilder(work);
        g = b.call(gil_on, [], name="gil");
        b.call(dec, [fn.args[0]]);
        b.call(gil_off, [g]);
        b.branch(done);
        b = ir.IRBuilder(done);
        b.ret_void();
    } elif name == "tuple_set" {
        cfn = self._get_or_declare_extern("PyTuple_SetItem", i32, [i8p, i64, i8p]);
        fn = self._define_function(
            "__jac_pyb_tuple_set", ir.FunctionType(void, [i8p, i64, i8p])
        );
        fn.linkage = "private";
        b = ir.IRBuilder(fn.append_basic_block("entry"));
        g = b.call(gil_on, [], name="gil");
        b.call(cfn, [fn.args[0], fn.args[1], fn.args[2]], name="rc");
        b.call(gil_off, [g]);
        b.ret_void();
    } elif name == "dict_set" {
        cfn = self._get_or_declare_extern("PyDict_SetItemString", i32, [i8p, i8p, i8p]);
        dec = self._get_or_declare_extern("Py_DecRef", void, [i8p]);
        fn = self._define_function(
            "__jac_pyb_dict_set", ir.FunctionType(void, [i8p, i8p, i8p])
        );
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        work = fn.append_basic_block("work");
        done = fn.append_basic_block("done");
        b = ir.IRBuilder(`entry);
        isnull = b.icmp_unsigned(
            "==", fn.args[2], ir.Constant(i8p, None), name="isnull"
        );
        b.cbranch(isnull, done, work);
        b = ir.IRBuilder(work);
        g = b.call(gil_on, [], name="gil");
        b.call(cfn, [fn.args[0], fn.args[1], fn.args[2]], name="rc");
        b.call(dec, [fn.args[2]]);
        b.call(gil_off, [g]);
        b.branch(done);
        b = ir.IRBuilder(done);
        b.ret_void();
    } elif name == "getattr" {
        cfn = self._get_or_declare_extern("PyObject_GetAttrString", i8p, [i8p, i8p]);
        fn = self._define_function(
            "__jac_pyb_getattr", ir.FunctionType(i8p, [i8p, i8p])
        );
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        work = fn.append_basic_block("work");
        null_bb = fn.append_basic_block("null");
        err_bb = fn.append_basic_block("err");
        ok_bb = fn.append_basic_block("ok");
        b = ir.IRBuilder(`entry);
        isnull = b.icmp_unsigned(
            "==", fn.args[0], ir.Constant(i8p, None), name="isnull"
        );
        b.cbranch(isnull, null_bb, work);
        b = ir.IRBuilder(null_bb);
        b.ret(ir.Constant(i8p, None));
        b = ir.IRBuilder(work);
        g = b.call(gil_on, [], name="gil");
        r = b.call(cfn, [fn.args[0], fn.args[1]], name="r");
        rnull = b.icmp_unsigned("==", r, ir.Constant(i8p, None), name="rnull");
        b.cbranch(rnull, err_bb, ok_bb);
        b = ir.IRBuilder(err_bb);
        b.call(err_print, []);
        b.call(gil_off, [g]);
        b.ret(ir.Constant(i8p, None));
        b = ir.IRBuilder(ok_bb);
        b.call(gil_off, [g]);
        b.ret(r);
    } elif name == "setattr" {
        cfn = self._get_or_declare_extern(
            "PyObject_SetAttrString", i32, [i8p, i8p, i8p]
        );
        dec = self._get_or_declare_extern("Py_DecRef", void, [i8p]);
        fn = self._define_function(
            "__jac_pyb_setattr", ir.FunctionType(void, [i8p, i8p, i8p])
        );
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        work = fn.append_basic_block("work");
        err_bb = fn.append_basic_block("err");
        fin_bb = fn.append_basic_block("fin");
        done = fn.append_basic_block("done");
        b = ir.IRBuilder(`entry);
        hnull = b.icmp_unsigned("==", fn.args[0], ir.Constant(i8p, None), name="hnull");
        vnull = b.icmp_unsigned("==", fn.args[2], ir.Constant(i8p, None), name="vnull");
        bad = b.or_(hnull, vnull, name="bad");
        b.cbranch(bad, done, work);
        b = ir.IRBuilder(work);
        g = b.call(gil_on, [], name="gil");
        rc = b.call(cfn, [fn.args[0], fn.args[1], fn.args[2]], name="rc");
        failed = b.icmp_signed("!=", rc, ir.Constant(i32, 0), name="failed");
        b.cbranch(failed, err_bb, fin_bb);
        b = ir.IRBuilder(err_bb);
        b.call(err_print, []);
        b.branch(fin_bb);
        b = ir.IRBuilder(fin_bb);
        b.call(dec, [fn.args[2]]);
        b.call(gil_off, [g]);
        b.branch(done);
        b = ir.IRBuilder(done);
        b.ret_void();
    } elif name == "callmeth" {
        getat = self._get_or_declare_extern("PyObject_GetAttrString", i8p, [i8p, i8p]);
        pycall = self._get_or_declare_extern("PyObject_Call", i8p, [i8p, i8p, i8p]);
        dec = self._get_or_declare_extern("Py_DecRef", void, [i8p]);
        fn = self._define_function(
            "__jac_pyb_callmeth", ir.FunctionType(i8p, [i8p, i8p, i8p, i8p])
        );
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        m_err = fn.append_basic_block("m_err");
        m_ok = fn.append_basic_block("m_ok");
        r_err = fn.append_basic_block("r_err");
        fin_bb = fn.append_basic_block("fin");
        b = ir.IRBuilder(`entry);
        g = b.call(gil_on, [], name="gil");
        rslot = b.alloca(i8p, name="rslot");
        b.store(ir.Constant(i8p, None), rslot);
        m = b.call(getat, [fn.args[0], fn.args[1]], name="m");
        mnull = b.icmp_unsigned("==", m, ir.Constant(i8p, None), name="mnull");
        b.cbranch(mnull, m_err, m_ok);
        b = ir.IRBuilder(m_err);
        b.call(err_print, []);
        b.branch(fin_bb);
        b = ir.IRBuilder(m_ok);
        r = b.call(pycall, [m, fn.args[2], fn.args[3]], name="r");
        b.call(dec, [m]);
        b.store(r, rslot);
        rnull = b.icmp_unsigned("==", r, ir.Constant(i8p, None), name="rnull");
        b.cbranch(rnull, r_err, fin_bb);
        b = ir.IRBuilder(r_err);
        b.call(err_print, []);
        b.branch(fin_bb);
        b = ir.IRBuilder(fin_bb);
        b.call(dec, [fn.args[2]]);
        kwnull = b.icmp_unsigned(
            "==", fn.args[3], ir.Constant(i8p, None), name="kwnull"
        );
        kw_drop = fn.append_basic_block("kw_drop");
        out_bb = fn.append_basic_block("out");
        b.cbranch(kwnull, out_bb, kw_drop);
        b = ir.IRBuilder(kw_drop);
        b.call(dec, [fn.args[3]]);
        b.branch(out_bb);
        b = ir.IRBuilder(out_bb);
        rv = b.load(rslot, name="rv");
        b.call(gil_off, [g]);
        b.ret(rv);
    } elif name == "bridge" {
        imp = self._get_or_declare_extern("PyImport_ImportModule", i8p, [i8p]);
        getat = self._get_or_declare_extern("PyObject_GetAttrString", i8p, [i8p, i8p]);
        pycall = self._get_or_declare_extern("PyObject_Call", i8p, [i8p, i8p, i8p]);
        dec = self._get_or_declare_extern("Py_DecRef", void, [i8p]);
        fn = self._define_function(
            "__jac_pyb_bridge", ir.FunctionType(i8p, [i8p, i8p])
        );
        fn.linkage = "private";
        `entry = fn.append_basic_block("entry");
        mod_err = fn.append_basic_block("mod_err");
        mod_ok = fn.append_basic_block("mod_ok");
        f_err = fn.append_basic_block("f_err");
        f_ok = fn.append_basic_block("f_ok");
        r_err = fn.append_basic_block("r_err");
        fin_bb = fn.append_basic_block("fin");
        b = ir.IRBuilder(`entry);
        g = b.call(gil_on, [], name="gil");
        rslot = b.alloca(i8p, name="rslot");
        b.store(ir.Constant(i8p, None), rslot);
        _saved = self._builder;
        self._builder = b;
        mod_name = self._pyb_cstr(_PYB_BRIDGE_MODULE);
        self._builder = _saved;
        mod = b.call(imp, [mod_name], name="mod");
        mnull = b.icmp_unsigned("==", mod, ir.Constant(i8p, None), name="mnull");
        b.cbranch(mnull, mod_err, mod_ok);
        b = ir.IRBuilder(mod_err);
        b.call(err_print, []);
        b.branch(fin_bb);
        b = ir.IRBuilder(mod_ok);
        f = b.call(getat, [mod, fn.args[0]], name="f");
        b.call(dec, [mod]);
        fnull = b.icmp_unsigned("==", f, ir.Constant(i8p, None), name="fnull");
        b.cbranch(fnull, f_err, f_ok);
        b = ir.IRBuilder(f_err);
        b.call(err_print, []);
        b.branch(fin_bb);
        b = ir.IRBuilder(f_ok);
        r = b.call(pycall, [f, fn.args[1], ir.Constant(i8p, None)], name="r");
        b.call(dec, [f]);
        b.store(r, rslot);
        rnull = b.icmp_unsigned("==", r, ir.Constant(i8p, None), name="rnull");
        b.cbranch(rnull, r_err, fin_bb);
        b = ir.IRBuilder(r_err);
        b.call(err_print, []);
        b.branch(fin_bb);
        b = ir.IRBuilder(fin_bb);
        b.call(dec, [fn.args[1]]);
        rv = b.load(rslot, name="rv");
        b.call(gil_off, [g]);
        b.ret(rv);
    } elif name == "shadow" {
        bridge = self._pyb_helper("bridge");
        tup_new = self._pyb_helper("tuple_new");
        tup_set = self._pyb_helper("tuple_set");
        from_i64 = self._pyb_helper("from_i64");
        fn = self._define_function("__jac_pyb_shadow", ir.FunctionType(i8p, [i64]));
        fn.linkage = "private";
        b = ir.IRBuilder(fn.append_basic_block("entry"));
        t = b.call(tup_new, [ir.Constant(i64, 1)], name="t");
        a0 = b.call(from_i64, [fn.args[0]], name="a0");
        b.call(tup_set, [t, ir.Constant(i64, 0), a0]);
        _saved = self._builder;
        self._builder = b;
        fname = self._pyb_cstr("_pyb_shadow_of");
        self._builder = _saved;
        r = b.call(bridge, [fname, t], name="r");
        b.ret(r);
    } elif name == "drop_owner" {
        bridge = self._pyb_helper("bridge");
        tup_new = self._pyb_helper("tuple_new");
        tup_set = self._pyb_helper("tuple_set");
        from_i64 = self._pyb_helper("from_i64");
        dropf = self._pyb_helper("drop");
        fn = self._define_function(
            "__jac_pyb_drop_owner", ir.FunctionType(void, [i64])
        );
        fn.linkage = "private";
        b = ir.IRBuilder(fn.append_basic_block("entry"));
        t = b.call(tup_new, [ir.Constant(i64, 1)], name="t");
        a0 = b.call(from_i64, [fn.args[0]], name="a0");
        b.call(tup_set, [t, ir.Constant(i64, 0), a0]);
        _saved = self._builder;
        self._builder = b;
        fname = self._pyb_cstr("_pyb_drop_owner");
        self._builder = _saved;
        r = b.call(bridge, [fname, t], name="r");
        b.call(dropf, [r]);
        b.ret_void();
    }
    if fn is None {
        raise RuntimeError(f"unknown pyb helper '{name}'");
    }
    self._pyb_helper_fns[name] = fn;
    return fn;
}

impl NaIRGenPass._pyb_emit_conv1(
    name: str,
    cfn: ir.Function,
    arg_ty: ir.Type,
    ret_ty: ir.Type,
    gil_on: ir.Function,
    gil_off: ir.Function
) -> ir.Function {
    fn = self._define_function(f"__jac_pyb_{name}", ir.FunctionType(ret_ty, [arg_ty]));
    fn.linkage = "private";
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    g = b.call(gil_on, [], name="gil");
    r = b.call(cfn, [fn.args[0]], name="r");
    b.call(gil_off, [g]);
    b.ret(r);
    return fn;
}

impl NaIRGenPass._pyb_owner_addr(obj_val: ir.Value) -> ir.Value {
    i64 = ir.IntType(64);
    if isinstance(obj_val.type, ir.IntType) {
        return self._coerce_type(obj_val, i64);
    }
    return self.builder.ptrtoint(obj_val, i64, name="pyb.owner");
}

impl NaIRGenPass._pyb_shadow_of_val(obj_val: ir.Value) -> ir.Value {
    return self.builder.call(
        self._pyb_helper("shadow"), [self._pyb_owner_addr(obj_val)], name="pyb.shadow"
    );
}

impl NaIRGenPass._pyb_to_py(
    nd: (uni.UniNode | None), val: ir.Value
) -> (ir.Value | None) {
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    tk = self._type_key_of(nd) if nd is not None else None;
    tkn = tk.replace(" ", "") if tk is not None else "";
    if tkn == "bool" or val.type == ir.IntType(1) {
        v = self._coerce_type(val, i64);
        return self.builder.call(self._pyb_helper("from_bool"), [v], name="pyb.obool");
    }
    if isinstance(val.type, ir.DoubleType) or tkn == "float" {
        v = self._coerce_type(val, ir.DoubleType());
        return self.builder.call(self._pyb_helper("from_f64"), [v], name="pyb.ofloat");
    }
    if tkn == "str"
        or (self._str_desc_ty is not None and val.type == self._str_desc_ty) {
        p = self._str_arg(val);
        if p is not None and p.type == i8p {
            return self.builder.call(
                self._pyb_helper("from_cstr"), [p], name="pyb.ostr"
            );
        }
        return None;
    }
    if isinstance(val.type, ir.IntType) {
        v = self._coerce_type(val, i64);
        return self.builder.call(self._pyb_helper("from_i64"), [v], name="pyb.oint");
    }
    if isinstance(val.type, ir.PointerType) {
        sk = self._struct_name_for_key(tkn) if tkn else None;
        if sk is not None and sk in self.struct_types {
            addr = self.builder.ptrtoint(val, i64, name="pyb.rawaddr");
            return self.builder.call(
                self._pyb_helper("from_i64"), [addr], name="pyb.oraw"
            );
        }
    }
    return None;
}

impl NaIRGenPass._pyb_ret_key(nd: uni.FuncCall) -> (str | None) {
    tk = self._type_key_of(nd);
    tkn = tk.replace(" ", "") if tk is not None else "";
    if tkn in ("", "Unknown") and isinstance(nd.parent, uni.ExprStmt) {
        return "None";
    }
    return tk;
}

impl NaIRGenPass._pyb_from_py(
    handle: ir.Value, type_key: (str | None)
) -> (ir.Value | None) {
    i64 = ir.IntType(64);
    tkn = type_key.replace(" ", "") if type_key is not None else "";
    if tkn in ("None", "NoneType", "type[NoneType]") {
        self.builder.call(self._pyb_helper("drop"), [handle]);
        return ir.Constant(i64, 0);
    }
    if tkn == "int" {
        return self.builder.call(self._pyb_helper("to_i64"), [handle], name="pyb.i64");
    }
    if tkn == "bool" {
        v = self.builder.call(self._pyb_helper("to_bool"), [handle], name="pyb.b64");
        return self.builder.icmp_unsigned("!=", v, ir.Constant(i64, 0), name="pyb.b1");
    }
    if tkn == "float" {
        return self.builder.call(self._pyb_helper("to_f64"), [handle], name="pyb.f64");
    }
    if tkn == "str" {
        bt = self.builder.call(
            self._pyb_helper("to_bytes"), [handle], name="pyb.bytes"
        );
        data = self.builder.call(self._pyb_helper("bytes_data"), [bt], name="pyb.data");
        s = self._membrane_str_in(self.builder, data);
        self.builder.call(self._pyb_helper("drop"), [bt]);
        self._mark_owned(s);
        return s;
    }
    sk = self._struct_name_for_key(tkn) if tkn else None;
    if sk is not None and sk in self.struct_types {
        v = self.builder.call(self._pyb_helper("to_i64"), [handle], name="pyb.rawback");
        return self.builder.inttoptr(
            v, self.struct_types[sk].as_pointer(), name="pyb.rawptr"
        );
    }
    return None;
}

impl NaIRGenPass._pyb_build_args(
    params: list, skip_kwargs: bool = False
) -> (tuple | None) {
    """Marshal call params into (PyTuple handle, PyDict handle | None).

    Returns None when any argument's type cannot cross the boundary;
    the caller reports the seam.
    """;
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    pos: list = [];
    kwp: list = [];
    for p in (params or []) {
        if isinstance(p, uni.KWPair) {
            if p.key is None {
                return None;
            }
            kwp.append(p);
        } else {
            pos.append(p);
        }
    }
    if skip_kwargs and kwp {
        return None;
    }
    marshalled: list = [];
    for p in pos {
        v = self._codegen_expr(p);
        if v is None {
            return None;
        }
        o = self._pyb_to_py(p, v);
        if o is None {
            return None;
        }
        marshalled.append(o);
    }
    kw_pairs: list = [];
    for p in kwp {
        v = self._codegen_expr(p.value);
        if v is None {
            return None;
        }
        o = self._pyb_to_py(p.value, v);
        if o is None {
            return None;
        }
        kw_pairs.append((p.key.sym_name, o, ));
    }
    t = self.builder.call(
        self._pyb_helper("tuple_new"),
        [ir.Constant(i64, len(marshalled))],
        name="pyb.args"
    );
    for (i, o) in enumerate(marshalled) {
        self.builder.call(self._pyb_helper("tuple_set"), [t, ir.Constant(i64, i), o]);
    }
    kw: (ir.Value | None) = None;
    if kw_pairs {
        kw = self.builder.call(self._pyb_helper("dict_new"), [], name="pyb.kwargs");
        for (kname, o) in kw_pairs {
            self.builder.call(
                self._pyb_helper("dict_set"), [kw, self._pyb_cstr(kname), o]
            );
        }
    }
    return (t, kw, );
}

impl NaIRGenPass._pyb_bridge_call(fn_name: str, args: list[ir.Value]) -> ir.Value {
    i64 = ir.IntType(64);
    t = self.builder.call(
        self._pyb_helper("tuple_new"), [ir.Constant(i64, len(args))], name="pyb.brargs"
    );
    for (i, o) in enumerate(args) {
        self.builder.call(self._pyb_helper("tuple_set"), [t, ir.Constant(i64, i), o]);
    }
    return self.builder.call(
        self._pyb_helper("bridge"), [self._pyb_cstr(fn_name), t], name=f"pyb.{fn_name}"
    );
}

impl NaIRGenPass._codegen_pyb_field_load(
    nd: uni.AtomTrailer, obj_val: ir.Value, field_name: str
) -> (ir.Value | None) {
    tk = self._type_key_of(nd);
    shadow = self._pyb_shadow_of_val(obj_val);
    o = self.builder.call(
        self._pyb_helper("getattr"),
        [shadow, self._pyb_cstr(field_name)],
        name=f"pyb.get.{field_name}"
    );
    self.builder.call(self._pyb_helper("drop"), [shadow]);
    val = self._pyb_from_py(o, tk);
    if val is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="inherited field read",
            name=field_name,
            help_text=(
                f"'{field_name}' lives on a Python-side base and its type "
                f"'{tk}' cannot cross the Python-base boundary yet (int, "
                f"bool, float, str and class handles can)."
            )
        );
        return None;
    }
    return val;
}

impl NaIRGenPass._codegen_pyb_field_assign(
    target: uni.AtomTrailer, value: ir.Value, obj_val: ir.Value
) -> (ir.Value | None) {
    field_name = self._get_name(target.right);
    if field_name is None {
        return None;
    }
    obj_val = self._opt_unwrap_attr(obj_val);
    o = self._pyb_to_py(target, value);
    if o is None {
        tk = self._type_key_of(target);
        self.emit(
            E5092,
            node_override=target,
            kind="inherited field assignment",
            name=field_name,
            help_text=(
                f"'{field_name}' lives on a Python-side base and a value of "
                f"type '{tk}' cannot cross the Python-base boundary yet "
                f"(int, bool, float, str and class handles can)."
            )
        );
        return None;
    }
    shadow = self._pyb_shadow_of_val(obj_val);
    self.builder.call(
        self._pyb_helper("setattr"), [shadow, self._pyb_cstr(field_name), o]
    );
    self.builder.call(self._pyb_helper("drop"), [shadow]);
    return ir.Constant(ir.IntType(64), 0);
}

impl NaIRGenPass._codegen_pyb_method_call(
    nd: uni.FuncCall, type_name: str, method_name: str
) -> (ir.Value | None) {
    """Invoke a Python-side base's method on the shadow beside the object.

    The shadow carries the base chain and none of this class's bodies, so a
    base method that dispatches `self.X()` resolves it against that hollow
    class and finds the base's X rather than the override declared here. The
    wrong body runs and nothing says so (#8310) -- the same wrongness E5088
    refuses one call shallower, at construction. Per the class-tier doctrine
    the answer is the refusal arm, not teaching the shadow to delegate back:
    the call is refused before it is built and its owning callable demotes to
    the Python lane, where the whole chain agrees again.
    """;
    _shadowed = self._pyb_shadowed_dispatch(type_name, method_name);
    if _shadowed is not None {
        (_sh_base, _sh_disp, _sh_owner) = _shadowed;
        self.emit(
            E5089,
            node_override=nd,
            cls=_sh_owner,
            meth=method_name,
            base=_sh_base,
            over=_sh_disp
        );
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    trailer = nd.target;
    if not isinstance(trailer, uni.AtomTrailer) {
        return None;
    }
    obj_val = self._codegen_expr(trailer.target);
    if obj_val is None {
        return None;
    }
    obj_val = self._opt_unwrap_attr(obj_val);
    built = self._pyb_build_args(nd.params or []);
    if built is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="inherited method call",
            name=f"{type_name}.{method_name}",
            help_text=(
                "An argument's type cannot cross the Python-base boundary "
                "yet (int, bool, float, str and class handles can)."
            )
        );
        return None;
    }
    (t, kw) = built;
    kw_val = kw if kw is not None else ir.Constant(i8p, None);
    shadow = self._pyb_shadow_of_val(obj_val);
    r = self.builder.call(
        self._pyb_helper("callmeth"),
        [shadow, self._pyb_cstr(method_name), t, kw_val],
        name=f"pyb.call.{method_name}"
    );
    self.builder.call(self._pyb_helper("drop"), [shadow]);
    ret = self._pyb_from_py(r, self._pyb_ret_key(nd));
    if ret is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="inherited method call",
            name=f"{type_name}.{method_name}",
            help_text=(
                f"The return type '{self._type_key_of(nd)}' cannot cross "
                f"the Python-base boundary yet (int, bool, float, str and "
                f"class handles can)."
            )
        );
        return None;
    }
    return ret;
}

impl NaIRGenPass._codegen_pyb_super_call(
    nd: uni.FuncCall, method_name: str
) -> (ir.Value | None) {
    i64 = ir.IntType(64);
    pb = self._pyb_base_of(self._self_arch) if self._self_arch else None;
    _self_slot = self.local_vars.get("self");
    if pb is None or _self_slot is None {
        return None;
    }
    (bname, _bpath) = pb;
    if method_name == "postinit" {
        meth_names = ["__post_init__", "postinit"];
    } elif method_name == "init" {
        meth_names = ["__init__", "init"];
    } else {
        meth_names = [method_name];
    }
    built = self._pyb_build_args(nd.params or []);
    if built is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="call",
            name=f"super.{method_name}",
            help_text=(
                "An argument's type cannot cross the Python-base boundary "
                "yet (int, bool, float, str and class handles can)."
            )
        );
        return None;
    }
    (t, kw) = built;
    if kw is None {
        kw = self.builder.call(self._pyb_helper("dict_new"), [], name="pyb.sup.kw");
    }
    self_val = self.builder.load(_self_slot, name="pyb.sup.self");
    shadow = self._pyb_shadow_of_val(self_val);
    mt = self.builder.call(
        self._pyb_helper("tuple_new"),
        [ir.Constant(i64, len(meth_names))],
        name="pyb.sup.meths"
    );
    for (i, mn) in enumerate(meth_names) {
        mo = self.builder.call(
            self._pyb_helper("from_cstr"), [self._pyb_cstr(mn)], name="pyb.mn"
        );
        self.builder.call(self._pyb_helper("tuple_set"), [mt, ir.Constant(i64, i), mo]);
    }
    anchor = self.builder.call(
        self._pyb_helper("from_cstr"), [self._pyb_cstr(bname)], name="pyb.anch"
    );
    r = self._pyb_bridge_call("_pyb_super_call", [shadow, anchor, mt, t, kw]);
    ret = self._pyb_from_py(r, self._pyb_ret_key(nd));
    if ret is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="call",
            name=f"super.{method_name}",
            help_text=(
                f"The return type '{self._type_key_of(nd)}' cannot cross "
                f"the Python-base boundary yet."
            )
        );
        return None;
    }
    return ret;
}

impl NaIRGenPass._codegen_pyb_shadow_init(
    nd: (uni.FuncCall | uni.Name),
    type_name: str,
    obj_ptr: ir.Value,
    params: list,
    native_fields: dict
) -> bool {
    i64 = ir.IntType(64);
    pb = self._pyb_base_of(type_name);
    if pb is None {
        return True;
    }
    (bname, bpath) = pb;
    suppress = 0;
    for _sc in self._mro_of(type_name) {
        for pn in [f"{_sc}.__post_init__", f"{_sc}.postinit"] {
            if pn in self.method_funcs and pn not in self._native_skipped_methods {
                suppress = 1;
                break;
            }
        }
        if suppress {
            break;
        }
    }
    if not suppress {
        shadow_owner = self._pyb_shadow_postinit_owner(type_name);
        if shadow_owner is not None {
            self.emit(E5088, node_override=nd, cls=type_name, owner=shadow_owner);
            return False;
        }
    }
    kwd = self.builder.call(self._pyb_helper("dict_new"), [], name="pyb.ctor.kw");
    for param in (params or []) {
        if not isinstance(param, uni.KWPair) or param.key is None {
            continue;
        }
        kn = param.key.sym_name;
        if kn in native_fields {
            continue;
        }
        v = self._codegen_expr(param.value);
        o = self._pyb_to_py(param.value, v) if v is not None else None;
        if o is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="constructor argument",
                name=f"{type_name}({kn}=...)",
                help_text=(
                    f"'{kn}' targets a Python-side base field and its type "
                    f"cannot cross the Python-base boundary yet (int, bool, "
                    f"float, str and class handles can)."
                )
            );
            return False;
        }
        self.builder.call(self._pyb_helper("dict_set"), [kwd, self._pyb_cstr(kn), o]);
    }
    args: list = [
        self.builder.call(
            self._pyb_helper("from_cstr"), [self._pyb_cstr(bpath)], name="pyb.ctor.path"
        ),
        self.builder.call(
            self._pyb_helper("from_cstr"), [self._pyb_cstr(bname)], name="pyb.ctor.base"
        ),
        self.builder.call(
            self._pyb_helper("from_cstr"),
            [self._pyb_cstr(type_name)],
            name="pyb.ctor.cls"
        ),
        kwd,
        self.builder.call(
            self._pyb_helper("from_bool"),
            [ir.Constant(i64, suppress)],
            name="pyb.ctor.sup"
        ),
        self.builder.call(
            self._pyb_helper("from_i64"),
            [self._pyb_owner_addr(obj_ptr)],
            name="pyb.ctor.addr"
        )
    ];
    r = self._pyb_bridge_call("_pyb_instantiate", args);
    self.builder.call(self._pyb_helper("drop"), [r]);
    return True;
}
