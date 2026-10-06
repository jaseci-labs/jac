impl NativeLowering._vtable_symbol(arch_name: str) -> str {
    import from jaclang.compiler.frontend.codeinfo {
        native_symbol_name,
        native_unit_spelling
    }
    src = self._struct_source_mod.get(arch_name, "");
    prefix = self._prefix_of_path(src) if src else self._own_prefix();
    owner_path = src or (self.module.loc.mod_path if self.module?.loc else "");
    return native_symbol_name(
        prefix, native_unit_spelling(f"{arch_name}.__vtable", owner_path)
    );
}

impl NativeLowering._isinstance_unprovable_class(
    names: list[str], operand_arch: (str | None)
) -> (str | None) {
    """A class this operand could be whose MRO is too short to decide these names.

    A class that subclasses an imported one is linearized by its own module,
    which reaches the base's name but not the base's own bases -- those live in
    a registry that is only merged in later. The recorded MRO then stops one
    link short, and every ancestor past that link silently drops out of the
    hierarchy. Answering from those facts is how `isinstance` came to report
    `False` for a base a class genuinely derives from, so a site whose targets
    fall in the missing span refuses instead.

    A short chain elsewhere in the program is only this site's problem if the
    operand could actually hold one: a statically typed operand narrows the
    candidates to itself and its subclasses, and only an erased one has to
    answer for every class. That narrowing walks the candidate's chain link by
    link rather than reading its recorded MRO, because the recorded MRO is the
    very thing that is short -- reading it would drop a candidate precisely
    when the ancestor it omits is the operand's declared type, which is the
    case that most needs the refusal. Returns the class whose MRO is short, or
    `None` when every chain this operand could take is whole.
    """;
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }

    _missing = self._short_mro_reach;
    if _missing is None {
        reg = get_layout_registry(self.module, self.prog);
        _missing = {};
        for cand in reg.mro_order {
            recorded = self._mro_of(cand);
            _cand_lay = reg.layouts.get(cand);
            _parents = list(_cand_lay.parents or []) if _cand_lay is not None else [];
            _pmods = list(_cand_lay.parent_mods or []) if _cand_lay is not None else [];
            for step in recorded {
                if step != cand and step in _parents {
                    _pi = _parents.index(step);
                    _want = _pmods[_pi] if _pi < len(_pmods) else "";
                    _step_lay = reg.layouts.get(step);
                    _decl = _step_lay.decl_mod if _step_lay is not None else "";
                    if _want != _decl {
                        continue;
                    }
                }
                for anc in self._mro_of(step) {
                    if anc in recorded {
                        continue;
                    }
                    _short_of = _missing.get(anc);
                    if _short_of is None {
                        _missing[anc] = [cand];
                    } elif cand not in _short_of {
                        _short_of.append(cand);
                    }
                }
            }
        }
        self._short_mro_reach = _missing;
    }
    for name in names {
        for cand in (_missing.get(name) or []) {
            if operand_arch is None {
                return cand;
            }
            for step in self._mro_of(cand) {
                if operand_arch in self._mro_of(step) {
                    return cand;
                }
            }
        }
    }
    return None;
}

impl NativeLowering._module_class_name(expr: uni.UniNode) -> (str | None) {
    while isinstance(expr, uni.AtomUnit) {
        expr = expr.value;
    }
    if not isinstance(expr, uni.AtomTrailer)
        or not expr.is_attr
        or not isinstance(expr.target, uni.Expr)
        or not isinstance(expr.target.type, ModuleType)
        or not isinstance(expr.type, ClassType) {
        return None;
    }
    if not expr.type.is_instantiable() or expr.type.is_instance() {
        return None;
    }
    return expr.type.shared.class_name;
}

impl NativeLowering._is_runtime_class_tuple(t: any) -> bool {
    """Is this the type of a tuple whose every arm is a class handle?

    That is the shape `isinstance(x, types)` needs: the arms arrive as values,
    and each one has to be a `type[...]` so the compare has a class id to walk.
    An arity-less arm (the `UnknownType` a variadic tuple parks) is skipped, so
    both `tuple[type[T], type[T]]` and `tuple[type[T], ...]` qualify.
    """;
    try {
        import from jaclang.compiler.types.types { ClassType as _SeqClassType }
    } except ImportError {
        return False;
    }
    if not isinstance(t, _SeqClassType) or t._shared is None {
        return False;
    }
    if t.shared.class_name != "tuple" {
        return False;
    }
    saw_class = False;
    for a in (t.private.type_args or []) {
        am = self._mangled_of(a);
        if am is None {
            return False;
        }
        if am == "<unknown>" {
            continue;
        }
        if am != "type" and not am.startswith("type[") {
            return False;
        }
        saw_class = True;
    }
    return saw_class;
}
