impl NativeLowering._pyb_base_of(arch_name: str) -> (tuple[str, str] | None) {
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
    _own_path = os.path.realpath(self.module.loc.mod_path) if self.module?.loc else "";
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
        bkey = self._arch_ref_key(base_expr) or bname;
        if bkey in self.arch_ast_map {
            sub = self._pyb_base_of(bkey);
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

impl NativeLowering._pyb_shadow_postinit_owner(arch_name: str) -> (str | None) {
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
    queue: list[uni.Expr] = list(arch.base_classes or []);
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
        if (self._arch_ref_key(base_expr) or bname) not in self.arch_ast_map {
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

impl NativeLowering._pyb_ret_key(nd: uni.FuncCall) -> (str | None) {
    tk = self._type_key_of(nd);
    tkn = tk.replace(" ", "") if tk is not None else "";
    if tkn in ("", "Unknown") and isinstance(nd.parent, uni.ExprStmt) {
        return "None";
    }
    return tk;
}

impl NativeLowering._pyb_shadowed_dispatch_candidates(
    arch_name: str, method_name: str
) -> list[tuple[str, str]] {
    out: list[tuple[str, str]] = [];
    arch = self.arch_ast_map.get(arch_name);
    if not isinstance(arch, uni.Archetype) {
        return out;
    }
    seen: set = {arch_name};
    queue: list[uni.Expr] = list(arch.base_classes or []);
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

        if (self._arch_ref_key(base_expr) or bname) not in self.arch_ast_map {
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
                    out.append((bname, _dispatched));
                }
            }
        }
        queue.extend(base_arch.base_classes or []);
    }
    return out;
}

impl NativeLowering._pyb_super_call_meth_names(method_name: str) -> list[str] {
    if method_name == "postinit" {
        meth_names = ["__post_init__", "postinit"];
    } elif method_name == "init" {
        meth_names = ["__init__", "init"];
    } else {
        meth_names = [method_name];
    }
    return meth_names;
}
