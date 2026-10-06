impl NativeLowering._devirt_closed_world(arch_name: str) -> bool {
    arch = self.arch_ast_map.get(arch_name);
    if arch is None {
        return False;
    }
    return arch.access_type == SymbolAccess.PRIVATE;
}

impl NativeLowering._arch_key(arch: uni.Archetype) -> str {
    import from jaclang.compiler.passes.layout_pass { archetype_native_name }
    return archetype_native_name(arch);
}

impl NativeLowering._arch_ref_key(nd: (uni.UniNode | None)) -> (str | None) {
    import from jaclang.compiler.passes.layout_pass { referenced_native_name }
    return referenced_native_name(nd);
}

impl NativeLowering._arch_display(arch_name: str) -> str {
    import from jaclang.compiler.frontend.codeinfo { native_arch_display }
    return native_arch_display(arch_name);
}

impl NativeLowering._native_archetypes(module: uni.Module) -> list[uni.Archetype] {
    result: dict[(str, uni.Archetype)] = {};

    for stmt in ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Archetype) {
            aname = self._arch_key(stmt);
            if aname not in result or stmt.body is not None {
                result[aname] = stmt;
            }
        }
    }

    for arch in ModuleFacts.shared_archetypes_for_context(module, CodeContext.NATIVE) {
        aname = self._arch_key(arch);
        if aname not in result {
            result[aname] = arch;
        }
    }

    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.module, self.prog);
    out: list[uni.Archetype] = [];
    for a in result.values() {
        if a.type_params {
            aname = self._arch_key(a);
            if layout_reg.get_layout(aname) is None {
                continue;
            }
        }
        out.append(a);
    }
    return out;
}

impl NativeLowering._constructor_slots -> tuple[str, ...] {
    return ("init", "__init__", "postinit", "__post_init__", );
}

impl NativeLowering._constructor_ability_for(cls: str, slot: str) -> (uni.Ability | None) {
    for _cn in self._mro_of(cls) {
        _arch = self.arch_ast_map.get(_cn);
        if _arch is None or _arch.body is None {
            continue;
        }
        for _st in _arch.body {
            if isinstance(_st, uni.Ability)
                and _st.name_ref is not None
                and _st.name_ref.sym_name == slot {
                return _st;
            }
        }
    }
    return None;
}

impl NativeLowering._derived_field_decls(nd: uni.Archetype) -> dict[str, uni.HasVar] {
    arch_name = nd.name.value if nd.name else "";
    decls: dict[str, uni.HasVar] = {};
    for cls in reversed(self._mro_of(arch_name)) {
        arch = nd if cls == arch_name else self.arch_ast_map.get(cls);
        if arch is None {
            continue;
        }
        for var in arch.get_has_vars() {
            owner = var.find_parent_of_type(uni.ArchHas);
            if var.name is None
                or var.accessors
                or (owner is not None and owner.is_static) {
                continue;
            }
            decls[var.name.value] = var;
        }
    }
    return decls;
}

impl NativeLowering._emit_scalar_type_arg_refusal(
    nd: uni.UniNode, type_name: str, fname: str, tv_name: str, arg: any
) -> bool {
    """Refuse a touch of an erased slot, inside the callable that touches it.

    The slot carries no value the native side put there, so answering with
    its bits would be wrong rather than merely un-lowered. Emitting here puts
    the diagnostic inside the enclosing callable's demotion window, which is
    what turns one un-lowerable declaration into a seam per method that reads
    or writes it instead of a dead module.
    """;
    self.emit(
        E5092,
        node_override=nd,
        kind="type argument",
        name=f"{self._arch_display(type_name)}[{arg}]",
        help_text=(
            f"A generic archetype is type-erased natively: one struct is "
            f"shared by every instantiation, so a slot typed by '{tv_name}' "
            f"-- here '{type_name}.{fname}' -- is a raw pointer. A pointer "
            f"slot cannot carry '{arg}', whose native representation is a "
            f"value rather than a reference, and for an optional slot the "
            f"null that spells None would alias a zero payload. Instantiate "
            f"'{type_name}' at an archetype type, or declare '{fname}' with "
            f"a concrete type."
        )
    );
    return True;
}

impl NativeLowering._method_slot_name(
    method: uni.Ability, field: (uni.HasVar | None)
) -> str {
    if field is not None {
        _fname = field.name.value if field.name else "field";
        _slot = accessor_slot_name(_fname, method);
        if _slot is not None {
            return _slot;
        }
    }
    return method.name_ref.sym_name if method.name_ref else "unnamed";
}

impl NativeLowering._seam_warnings_on -> bool {
    """Whether a seam this run takes should also be announced on stderr.""";
    if self._na_debug_on() or bool(self.prog.options.native_debug) {
        return True;
    }
    import from jaclang.compiler.frontend.host { active_host }
    defaults = active_host().project_defaults();
    return defaults.check.warn_native_seams if defaults is not None else True;
}

impl NativeLowering._refuse_opaque_field(
    nd: (uni.UniNode | None), type_name: (str | None), fname: str
) -> bool {
    if type_name is None {
        return False;
    }
    for _cn in self._mro_of(type_name) {
        _why = self.struct_field_opaque.get(_cn, {}).get(fname);
        if _why is not None {
            self.emit(
                E5092, node_override=nd, kind="erased field", name=f"{_cn}.{fname}"
            );
            return True;
        }
    }
    return False;
}

impl NativeLowering._unadopted_field_owner(
    arch_name: str, field_name: str
) -> (str | None) {
    """The ancestor that declares a field this class's layout does not hold.

    A subclass whose ancestor lays out in another unit adopts that unit's slot
    assignment, and where the two disagree about the header slots there is no
    assignment to adopt. Naming the ancestor turns the resulting refusal from
    'some attribute did not lower' into the layout fact behind it.
    """;
    _arch = self.arch_ast_map.get(arch_name);
    if _arch is None {
        return None;
    }
    for _base in (_arch.base_classes or []) {
        _bn = self._arch_ref_key(_base) or self._get_name(_base);
        if _bn is None or _bn == arch_name {
            continue;
        }
        _blay = self._arch_layout(_bn);
        if _blay is not None and field_name in _blay.field_index {
            return _bn;
        }
        _up = self._unadopted_field_owner(_bn, field_name);
        if _up is not None {
            return _up;
        }
    }
    return None;
}

impl NativeLowering._emit_field_access_refusal(
    nd: uni.UniNode, arch_name: str, field_name: str
) -> None {
    _owner = self._unadopted_field_owner(arch_name, field_name);
    if _owner is None {
        _decl = self._class_const_declarer(arch_name, field_name);
        if _decl is not None {
            self.emit(
                E5092,
                node_override=nd,
                kind="class-level attribute read",
                name=field_name,
                help_text=(
                    f"'{field_name}' is a class-level attribute of '{_decl}', "
                    f"not an instance field. Reading it through an instance "
                    f"needs every declaring class in the hierarchy to carry "
                    f"the value in one shape the receiver's vtable can select "
                    f"between, and this hierarchy does not. Read it off the "
                    f"class, or move this code to a @sv/Python context."
                )
            );
        }
        return;
    }
    self.emit(
        E5092,
        node_override=nd,
        kind="inherited field access",
        name=field_name,
        help_text=(
            f"'{field_name}' is declared by '{_owner}', which lays out in "
            f"another unit with no vtable slot, while '{arch_name}' needs "
            f"that slot for one. No offset satisfies both units, so the "
            f"field is not reachable from here. Read it through an "
            f"'{_owner}'-typed value, or move this code to a @sv/Python "
            f"context."
        )
    );
}

impl NativeLowering._class_const_declarer(
    arch_name: str, field_name: str
) -> (str | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    _seen: list[str] = list(self._mro_of(arch_name));
    for _cls in get_layout_registry(self.module, self.prog).mro_order {
        if arch_name in self._mro_of(_cls) and _cls not in _seen {
            _seen.append(_cls);
        }
    }
    for _cls in _seen {
        _arch = self.arch_ast_map.get(_cls);
        if _arch is None or _arch.body is None {
            continue;
        }
        for stmt in _arch.body {
            if not isinstance(stmt, uni.ModuleCode) {
                continue;
            }
            for _a in (stmt.body or []) {
                if not isinstance(_a, uni.Assignment) {
                    continue;
                }
                _tg = _a.target
                    if isinstance(_a.target, (list, tuple))
                    else [(_a.target)];
                for _t in _tg {
                    if self._get_name(_t) == field_name {
                        return _cls;
                    }
                }
            }
        }
    }
    return None;
}

impl NativeLowering._mro_of(arch_name: str) -> list[str] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    mro = get_layout_registry(self.module, self.prog).get_mro(arch_name);
    return mro or [arch_name];
}

impl NativeLowering._arch_layout(arch_name: str) -> (ArchetypeLayout | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }

    _owner = None;
    _arch_nd = self.arch_ast_map.get(arch_name);
    if _arch_nd is not None {
        _owner = _arch_nd.find_parent_of_type(uni.Module);
    }
    for _cand in [_owner, self.module] {
        if _cand is None {
            continue;
        }
        lay = get_layout_registry(_cand, self.prog).get_layout(arch_name);
        if lay is not None {
            return lay;
        }
    }
    return None;
}

impl NativeLowering._event_from_walker(method: uni.Ability) -> bool {
    owner = method.find_parent_of_type(uni.Archetype);
    if owner is not None {
        return owner.arch_kind == "walker";
    }
    sig = method.signature;
    return isinstance(sig, uni.EventSignature) and sig.from_walker;
}

impl NativeLowering._stack_alloc_target_ok(nd: uni.UniNode) -> bool {
    p = nd.parent;
    if not isinstance(p, uni.Assignment) or p.aug_op is not None or p.value is not nd {
        return False;
    }
    targets = p.target if isinstance(p.target, (list, tuple)) else [(p.target)];
    if len(targets) != 1 or not isinstance(targets[0], uni.Name) {
        return False;
    }
    sym = targets[0].sym;
    return sym is not None and sym.na_stack_ok;
}

impl NativeLowering._hasvar_is_own(var: uni.UniNode) -> bool {
    if not isinstance(var, uni.HasVar) {
        return False;
    }
    _tt = var.type_tag;
    if _tt is None {
        return False;
    }
    if _tt.ownership == OwnershipKind.OWN {
        return True;
    }
    _inner = _tt.tag;
    return isinstance(_inner, uni.UnaryExpr) and _inner.ownership == OwnershipKind.OWN;
}
