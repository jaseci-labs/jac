import from jaclang.compiler.expr_keys { type_tag_borrows }
impl NaIRGenObjects._devirt_closed_world(arch_name: str) -> bool {
    arch = self.arch_ast_map.get(arch_name);
    if arch is None {
        return False;
    }
    return arch.access_type == SymbolAccess.PRIVATE;
}


impl NaIRGenObjects._native_archetypes(module: uni.Module) -> list[uni.Archetype] {
    result: dict[(str, uni.Archetype)] = {};

    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Archetype) {
            aname = stmt.name.value if stmt.name else "unknown";
            if aname not in result or stmt.body is not None {
                result[aname] = stmt;
            }
        }
    }

    for arch in ModuleCodegenPass.shared_archetypes_for_context(
        module, CodeContext.NATIVE
    ) {
        aname = arch.name.value if arch.name else "unknown";
        if aname not in result {
            result[aname] = arch;
        }
    }

    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.ir_in, self.prog);
    out: list[uni.Archetype] = [];
    for a in result.values() {
        if a.type_params {
            aname = a.name.value if a.name else "unknown";
            if layout_reg.get_layout(aname) is None {
                continue;
            }
        }
        out.append(a);
    }
    return out;
}

impl NaIRGenObjects._forward_declare_archetype_names(module: uni.Module) -> None {
    for arch in self._native_archetypes(module) {
        aname = arch.name.value if arch.name else None;
        if aname is not None and aname not in self.struct_types {
            struct_type = self.llvm_module.context.get_identified_type(aname);
            self.struct_types[aname] = struct_type;
        }
    }
}

impl NaIRGenObjects._register_archetypes(module: uni.Module) -> None {
    archetypes: list[uni.Archetype] = self._native_archetypes(module);
    arch_map: dict[(str, uni.Archetype)] = {};
    for arch in archetypes {
        arch_map[arch.name.value if arch.name else "unknown"] = arch;
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        struct_type = self.llvm_module.context.get_identified_type(arch_name);
        self.struct_types[arch_name] = struct_type;
        self.has_native_code = True;
    }

    self._compute_osp_model(archetypes);

    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.ir_in, self.prog);
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        self.arch_ast_map[arch_name] = arch;
    }

    topo_order = layout_reg.get_topo_order();
    for topo_name in topo_order {
        if topo_name in arch_map {
            self._codegen_archetype(arch_map[topo_name]);
        }
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                        and isinstance(stmt.signature, uni.FuncSignature) {
                        self._forward_declare_method(arch_name, stmt);
                    } elif stmt.signature is None and stmt.body is not None {
                        method_name = stmt.name_ref.sym_name if stmt.name_ref else None;
                        if method_name is not None {
                            full_name = f"{arch_name}.{method_name}";
                            struct_ptr = self.struct_types[arch_name].as_pointer();
                            fnty = ir.FunctionType(ir.VoidType(), [struct_ptr]);
                            func = ir.Function(self.llvm_module, fnty, name=full_name);
                            func.args[0].name = "self";
                            self.func_symtab[full_name] = func;
                            self.method_funcs[full_name] = func;
                            self.has_native_code = True;
                        }
                    } elif isinstance(stmt.signature, uni.EventSignature) {
                        self._forward_declare_event_method(arch_name, stmt);
                        if arch.arch_kind is not None {
                            self._emit_osp_thunk(arch_name, stmt);
                        }
                    } else {
                        _sig_kind = (
                            type(stmt.signature).__name__
                                if stmt.signature is not None
                                else "no-signature"
                        );
                        _m_name = stmt.name_ref.sym_name if stmt.name_ref else "?";
                        self.emit(
                            E5092,
                            node_override=stmt,
                            kind="archetype method",
                            name=f"{arch_name}.{_m_name} ({_sig_kind})"
                        );
                    }
                }
            }
        }
        for (_slot, _accvar, _acc) in archetype_accessors(arch) {
            self._forward_declare_method(arch_name, _acc, field=_accvar);
        }
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        self._emit_struct_release_fn(arch_name);
        self._emit_trace_fn(arch_name);
    }

    for arch in archetypes {
        self._visit_nonprimary_ancestor_methods(arch, declare=True);
    }

    for topo_name in topo_order {
        if self._arch_has_vtable(topo_name) {
            self._build_vtable(topo_name);
        }
    }

    import from jaclang.compiler.passes.layout_pass { get_layout_registry as _no_glr }
    _no_reg = _no_glr(self.ir_in, self.prog);
    for (base_name, layout) in self.vtable_layouts.items() {
        if not self._devirt_closed_world(base_name) {
            continue;
        }
        non_overridden: set[str] = set();
        _no_base_lay = _no_reg.get_layout(base_name);
        for method_name in layout {
            defining_class = self._resolve_method_owner(base_name, method_name);
            if defining_class is None {
                continue;
            }
            _no_base_owner = defining_class;
            if _no_base_lay is not None {
                _no_bmi = _no_base_lay.method_index.get(method_name);
                if _no_bmi is not None and _no_bmi < len(_no_base_lay.methods) {
                    _no_base_owner = _no_base_lay.methods[_no_bmi].owner
                        or defining_class;
                }
            }

            overridden = False;
            for child_name in _no_reg.mro_order {
                if child_name == base_name
                    or base_name not in _no_reg.get_mro(child_name) {
                    continue;
                }
                _no_cl = _no_reg.get_layout(child_name);
                if _no_cl is None {
                    continue;
                }
                _no_cmi = _no_cl.method_index.get(method_name);
                if _no_cmi is None or _no_cmi >= len(_no_cl.methods) {
                    continue;
                }
                if _no_cl.methods[_no_cmi].owner != _no_base_owner {
                    overridden = True;
                    break;
                }
                child_arch = self.arch_ast_map.get(child_name);
                if child_arch is not None and child_arch.body is not None {
                    for stmt in child_arch.body {
                        if isinstance(stmt, uni.Ability) {
                            mn = stmt.name_ref.sym_name if stmt.name_ref else None;
                            if mn == method_name {
                                overridden = True;
                                break;
                            }
                        }
                    }
                }
                if not overridden and child_arch is not None {
                    for (_slot, _accvar, _acc) in archetype_accessors(child_arch) {
                        if _slot == method_name {
                            overridden = True;
                            break;
                        }
                    }
                }
                if overridden {
                    break;
                }
            }
            if not overridden {
                non_overridden.add(method_name);
            }
        }
        if non_overridden {
            self._non_overridden_methods[base_name] = non_overridden;
        }
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if self._arch_has_vtable(arch_name) {
            self._emit_vtable_global(arch_name);
        }
    }

    self._forward_declare_functions(module);

    self._register_osp_kernel_module();
    self._emit_osp_setup();
    import from jaclang.compiler.native_scope { scope_lowering_active }
    if scope_lowering_active() {
        self.ir_in.gen.jc_layout = self._build_jc_layout();
    }

    self._predemote_capability_constructors();
    self._codegen_constructors_first(archetypes);

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                        and isinstance(stmt.signature, uni.FuncSignature) {
                        self._codegen_method(arch_name, stmt);
                    } elif isinstance(stmt.signature, uni.EventSignature) {
                        self._codegen_event_method(arch_name, stmt);
                    } elif stmt.signature is None and stmt.body is not None {
                        self._codegen_no_sig_method(arch_name, stmt);
                    }
                }
            }
        }
        for (_slot, _accvar, _acc) in archetype_accessors(arch) {
            self._codegen_method(arch_name, _acc, field=_accvar);
        }
    }

    for arch in archetypes {
        self._visit_nonprimary_ancestor_methods(arch, declare=False);
    }

    self._generate_inherited_method_wrappers();
}

impl NaIRGenObjects._constructor_slots -> tuple {
    return ("init", "__init__", "postinit", "__post_init__", );
}

impl NaIRGenObjects._constructor_ability_for(
    cls: str, slot: str
) -> (uni.Ability | None) {
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

impl NaIRGenObjects._predemote_capability_constructors -> None {
    """Demote capability-blocked constructors before any body is lowered.

    Every other seam demotes at its own body-codegen point, which is enough
    because a call site that binds too early still resolves its callee by name.
    A construction site does not: it reads `init`/`postinit` straight out of
    `method_funcs` while lowering some OTHER archetype's body, so a constructor
    that only demoted later would already have been bound -- silently, to what
    becomes an abort stub. Running the constructor half of the capability
    partition up front makes the refusal independent of which archetype the
    backend reaches first.
    """;
    if not self._capability_demotions {
        return;
    }
    _slots = self._constructor_slots();
    for _full in list(self.method_funcs.keys()) {
        (_cls, _dot, _slot) = _full.rpartition(".");
        if not _dot or _slot not in _slots {
            continue;
        }
        _ability = self._constructor_ability_for(_cls, _slot);
        if _ability is None {
            continue;
        }
        _viols = self._capability_demotions.get(id(_ability));
        if _viols is None {
            continue;
        }
        _func = self.method_funcs.get(_full);
        if _func is None {
            continue;
        }
        self._claimed_capability_demotions.add(id(_ability));
        self._predemote_capability_unit(
            _full,
            _func,
            _viols,
            keep_func=_slot in self.vtable_method_indices.get(_cls, {})
        );
    }
}

impl NaIRGenObjects._codegen_constructors_first(archetypes: list) -> None {
    """Lower every constructor body before any other body is lowered.

    The companion to `_predemote_capability_constructors`, for the demotions
    the capability partition cannot predict: a structured error or an emitter
    exception while lowering a constructor. Those only surface at the
    constructor's own codegen point, and a construction site lowered before
    that point would already hold a direct reference to what becomes an abort
    stub. Lowering constructors first means every non-constructor body sees a
    settled answer from `_demoted_init_of`. A constructor that constructs
    another class whose constructor demotes later in this same pass is the one
    case left, and it is bounded by construction order among constructors.
    """;
    _slots = self._constructor_slots();
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is None {
            continue;
        }
        for stmt in arch.body {
            if isinstance(stmt, uni.Ability)
                and isinstance(stmt.signature, uni.FuncSignature)
                and stmt.name_ref is not None
                and stmt.name_ref.sym_name in _slots {
                self._codegen_method(arch_name, stmt);
            }
        }
    }
}

impl NaIRGenObjects._demoted_init_of(type_name: str) -> (str | None) {
    """The demoted initializer a `type_name()` would have needed, or None.

    Walks the MRO the way the construction site does and stops at the first
    class that provides an initializer at all, so a live `init` on a subclass
    still wins over a demoted one further up. The skipped-methods check comes
    first per candidate because a demotion that kept its function (a virtual
    slot) leaves the abort stub sitting in `method_funcs`.
    """;
    if not self._native_skipped_methods {
        return None;
    }
    for _cn in self._mro_of(type_name) {
        for _mn in ("init", "__init__") {
            _cand = f"{_cn}.{_mn}";
            if _cand in self._native_skipped_methods {
                return _cand;
            }
            if _cand in self.method_funcs {
                return None;
            }
        }
    }
    return None;
}

impl NaIRGenObjects._visit_nonprimary_ancestor_methods(
    arch: uni.Archetype, declare: bool
) -> None {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    import from jaclang.compiler.symbol_utils { collect_method_names }
    layout_reg = get_layout_registry(self.ir_in, self.prog);
    arch_name = arch.name.value if arch.name else "unknown";
    mro = self._mro_of(arch_name);
    if len(mro) < 2 {
        return;
    }
    provided_methods = collect_method_names(arch);
    for anc in mro[1:] {
        if layout_reg.is_primary_ancestor(arch_name, anc) {
            anc_arch = self.arch_ast_map.get(anc);
            if anc_arch is not None {
                provided_methods.update(collect_method_names(anc_arch));
            }
        }
    }
    for ancestor_name in mro[1:] {
        if layout_reg.is_primary_ancestor(arch_name, ancestor_name) {
            continue;
        }
        ancestor_arch = self.arch_ast_map.get(ancestor_name);
        if ancestor_arch is None or ancestor_arch.body is None {
            continue;
        }
        for stmt in ancestor_arch.body {
            if isinstance(stmt, uni.Ability)
                and stmt.signature is not None
                and isinstance(stmt.signature, uni.FuncSignature) {
                method_name = stmt.name_ref.sym_name if stmt.name_ref else None;
                if method_name is not None and method_name not in provided_methods {
                    full_name = f"{arch_name}.{method_name}";
                    if declare and full_name not in self.method_funcs {
                        self._forward_declare_method(arch_name, stmt);
                    } elif not declare and full_name in self.method_funcs {
                        self._codegen_method(arch_name, stmt);
                    }
                    provided_methods.add(method_name);
                }
            }
        }

        for (_slot, _accvar, _acc) in archetype_accessors(ancestor_arch) {
            if _slot in provided_methods {
                continue;
            }
            full_name = f"{arch_name}.{_slot}";
            if declare and full_name not in self.method_funcs {
                self._forward_declare_method(arch_name, _acc, field=_accvar);
            } elif not declare and full_name in self.method_funcs {
                self._codegen_method(arch_name, _acc, field=_accvar);
            }
            provided_methods.add(_slot);
        }
    }
}

impl NaIRGenObjects._codegen_archetype(nd: uni.Archetype) -> None {
    arch_name = (nd).name.value if (nd).name else "unknown";
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    _owner_mod = nd.find_parent_of_type(uni.Module) or self.ir_in;
    layout = get_layout_registry(_owner_mod, self.prog).get_layout(arch_name);
    if layout is None {
        return;
    }

    field_types: list[ir.Type] = [];
    field_index_map: dict[(str, int)] = {};
    field_type_map: dict[(str, ir.Type)] = {};
    field_default_map: dict[(str, object)] = {};
    foreign_fields: set = set();
    erased_tv_fields: dict[(str, list)] = {};

    if layout.vtable_ptr_slot is not None {
        field_types.append(ir.IntType(8).as_pointer().as_pointer());
    }
    if layout.type_tag_slot is not None {
        field_types.append(ir.IntType(64));
        self.osp_type_tag_field[arch_name] = layout.type_tag_slot;
    }
    if layout.reports_slot is not None {
        self._emit_list_helpers("jacval", self.jacval_type);
        _rep_lt = self.list_types.get("jacval");
        if _rep_lt is not None {
            field_types.append(_rep_lt.as_pointer());
            field_index_map["reports"] = layout.reports_slot;
            field_type_map["reports"] = _rep_lt.as_pointer();
            self.osp_reports_field[arch_name] = layout.reports_slot;
        }
    }

    self.parent_field_start[arch_name] = dict(layout.parent_field_start);

    for finfo in layout.fields {
        fname = finfo.name;
        var = finfo.decl_node;
        ftype: ir.Type = ir.IntType(64);
        if isinstance(var, uni.HasVar) and type_tag_borrows(var.type_tag) {
            if arch_name not in self.struct_field_borrow {
                self.struct_field_borrow[arch_name] = set();
            }
            self.struct_field_borrow[arch_name].add(fname);
        }
        if isinstance(var, uni.TypeParam) {
            ftype = self._resolve_jac_type(var.bound);
        } elif var is not None and var.type_tag is not None {
            if finfo.owner in self.clib_struct_names {
                _cf_fnty = False;
                try {
                    import from jaclang.compiler.types.types {
                        FunctionType as _ClibFnType
                    }
                    _cf_fnty = isinstance(var?.type, _ClibFnType);
                } except ImportError {}
                if _cf_fnty {
                    ftype = self._lower_clib_function_type(arch_name, fname, var.type);
                } else {
                    ftype = self._resolve_jac_type(var.type_tag);
                }
            } else {
                _fld_mark = len(self.errors_had);
                ftype = self._resolve_field_type(var);
                _opaque = self._opaque_field_if_unlowerable(
                    arch_name, fname, _fld_mark
                );
                if _opaque is not None {
                    ftype = _opaque;
                    foreign_fields.add(fname);
                }
                if self._foreign_optional_field(var?.type) {
                    foreign_fields.add(fname);
                }
                _etv = self._erased_typevar_names(var?.type);
                if _etv {
                    erased_tv_fields[fname] = _etv;
                }
                if self._nogc_headerless()
                    and self._hasvar_is_own(var)
                    and isinstance(ftype, ir.PointerType) {
                    _fpn = getattr(ftype.pointee, "name", "") or "";
                    _fstruct = self.struct_types.get(_fpn);
                    if _fstruct is not None
                        and _fpn != arch_name
                        and _fstruct?.elements is not None
                        and self._arch_is_acyclic(_fpn)
                        and not self._arch_is_osp_name(_fpn)
                        and _fpn not in self.clib_vtable_structs {
                        ftype = _fstruct;
                        if arch_name not in self.struct_field_inline {
                            self.struct_field_inline[arch_name] = set();
                        }
                        self.struct_field_inline[arch_name].add(fname);
                    }
                }
            }
            _ftag = var.type_tag.tag;
            ftag_name = self._get_name(_ftag);
            if ftag_name is not None and ftag_name in self.enum_types {
                if arch_name not in self.struct_field_enum_type {
                    self.struct_field_enum_type[arch_name] = {};
                }
                self.struct_field_enum_type[arch_name][fname] = ftag_name;
            }
            _fek = self._elem_keys_of_annotation(_ftag);
            if _fek {
                if arch_name not in self.struct_field_elem_keys {
                    self.struct_field_elem_keys[arch_name] = {};
                }
                self.struct_field_elem_keys[arch_name][fname] = _fek;
            }
        }
        field_types.append(ftype);
        field_index_map[fname] = finfo.index;
        field_type_map[fname] = ftype;

        if isinstance(var, uni.HasVar)
            and var.value is not None
            and fname not in foreign_fields {
            field_default_map[fname] = var.value;
        }
    }

    if (nd).body is not None {
        for stmt in (nd).body {
            if isinstance(stmt, uni.ArchHas) and stmt.is_static {
                self._register_static_fields(arch_name, stmt);
            } elif isinstance(stmt, uni.ModuleCode) {
                self._register_class_consts(nd, arch_name, stmt);
            }
        }
    }

    for (_esn, _esv) in self._erased_sig_typevars(nd).items() {
        if _esn not in erased_tv_fields {
            erased_tv_fields[_esn] = _esv;
        }
    }

    if arch_name in self.clib_struct_names and not struct_type.is_opaque {} else {
        struct_type.set_body(*field_types);
    }
    self.struct_field_indices[arch_name] = field_index_map;
    self.struct_field_order[arch_name] = [f.name for f in layout.fields];
    self.struct_field_types[arch_name] = field_type_map;
    self.struct_field_defaults[arch_name] = field_default_map;
    self.struct_field_foreign[arch_name] = foreign_fields;
    self.struct_field_erased_tv[arch_name] = erased_tv_fields;
    self.arch_type_params[arch_name] = [
        tp.name.value
        for tp in (nd.type_params or [])
        if tp?.name is not None
    ];
}

impl NaIRGenObjects._erased_sig_typevars(nd: uni.Archetype) -> dict {
    """The type params a method signature erases, keyed by the slot naming it.

    A sequence of `T` in a signature lays out as the pointer-flavoured list,
    exactly as a bare `T` lays out as a raw pointer, so an instantiation at a
    by-value type is as unsound there as it is in a field. Recording those
    slots alongside the erased fields lets the construction site refuse both
    with one rule.
    """;
    out: dict = {};
    if nd.body is None {
        return out;
    }
    for stmt in nd.body {
        if not isinstance(stmt, uni.Ability)
            or not isinstance(stmt.signature, uni.FuncSignature) {
            continue;
        }
        _mname = stmt.name_ref.sym_name if stmt.name_ref else "unnamed";
        for p in stmt.signature.get_parameters() {
            if p.type_tag is None or self._erased_seq_type(p?.type) is None {
                continue;
            }
            _pname = p.name.value if p.name else "arg";
            _star = "*" if p.is_vararg else "";
            out[f"{_mname}({_star}{_pname})"] = self._erased_typevar_names(
                (p.type.private.type_args or [None])[0]
            );
        }
    }
    return out;
}

impl NaIRGenObjects._reject_scalar_type_args(nd: uni.UniNode, type_name: str) -> bool {
    _erased = self.struct_field_erased_tv.get(type_name) or {};
    if not _erased {
        return False;
    }
    _params = self.arch_type_params.get(type_name) or [];
    if not _params {
        return False;
    }
    _args = self._container_type_args(nd?.type);
    if not _args {
        return False;
    }
    for (fname, tv_names) in _erased.items() {
        for tv_name in tv_names {
            if tv_name not in _params {
                continue;
            }
            _idx = _params.index(tv_name);
            if _idx >= len(_args) {
                continue;
            }
            _solved = self._lower_type(_args[_idx]);
            if _solved is None or isinstance(_solved, ir.PointerType) {
                continue;
            }
            return self._emit_scalar_type_arg_refusal(
                nd, type_name, fname, tv_name, _args[_idx]
            );
        }
    }
    return False;
}

impl NaIRGenObjects._emit_scalar_type_arg_refusal(
    nd: uni.UniNode, type_name: str, fname: str, tv_name: str, arg: any
) -> bool {
    self.emit(
        E5092,
        node_override=nd,
        kind="type argument",
        name=f"{type_name}[{arg}]",
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

impl NaIRGenObjects._register_static_fields(
    arch_name: str, archhas: uni.ArchHas
) -> None {
    for var in archhas.vars {
        fname = var.name.value if var.name else "field";
        full_name = f"{arch_name}.{fname}";
        if full_name in self.static_fields {
            continue;
        }
        ftype: ir.Type = ir.IntType(64);
        if var.type_tag is not None {
            ftype = self._resolve_decl_type(var.type_tag, var.value);
        } elif var.value is not None {
            inferred = self._infer_global_init_type(var.value);
            if inferred is not None {
                ftype = inferred;
            }
        }

        if full_name in self.llvm_module.globals {
            continue;
        }
        gv = ir.GlobalVariable(self.llvm_module, ftype, name=full_name);

        gv.linkage = "";
        const_init = self._codegen_const_expr(var.value, ftype)
            if var.value is not None
            else None;
        if const_init is not None {
            gv.initializer = const_init;
        } else {
            gv.initializer = ir.Constant(ftype, None);
        }
        self.static_fields[full_name] = gv;
        self.static_field_types[full_name] = ftype;
        self.global_vars[full_name] = gv;
        self.global_var_types[full_name] = ftype;
        self.has_native_code = True;

        if var.value is not None and const_init is None {
            if not self?._global_init_nodes {
                self._global_init_nodes: list = [];
            }
            self._global_init_nodes.append((full_name, var.value, ftype));
        }
    }
}

impl NaIRGenObjects._register_class_consts(
    nd: uni.Archetype, arch_name: str, block: uni.ModuleCode
) -> None {
    import from jaclang.compiler.passes.layout_pass { class_form_enum_scalar }
    if nd.name is None or class_form_enum_scalar(nd.name.type) is not None {
        return;
    }
    _owns = nd.find_parent_of_type(uni.Module) is self.ir_in;
    for stmt in (block.body or []) {
        if not isinstance(stmt, uni.Assignment) or stmt.value is None {
            continue;
        }
        _targets = stmt.target
            if isinstance(stmt.target, (list, tuple))
            else [(stmt.target)];
        for _t in _targets {
            _fname = self._get_name(_t);
            if _fname is None {
                continue;
            }
            self._register_one_class_const(arch_name, _fname, _t, stmt, _owns);
        }
    }
}

impl NaIRGenObjects._register_one_class_const(
    arch_name: str, fname: str, target: uni.UniNode, assign: uni.Assignment, owns: bool
) -> None {
    full_name = f"{arch_name}.{fname}";
    if full_name in self.static_fields or full_name in self.llvm_module.globals {
        return;
    }
    ftype = self._infer_global_init_type(target)
        if assign.type_tag is not None
        else None;
    if ftype is None {
        ftype = self._infer_global_init_type(assign.value);
    }
    if ftype is None {
        return;
    }
    gv = ir.GlobalVariable(self.llvm_module, ftype, name=full_name);
    gv.linkage = "";
    self.static_fields[full_name] = gv;
    self.static_field_types[full_name] = ftype;
    self.global_vars[full_name] = gv;
    self.global_var_types[full_name] = ftype;
    self.has_native_code = True;
    if not owns {
        return;
    }
    const_init = self._codegen_const_expr(assign.value, ftype);
    if const_init is None {
        const_init = self._class_const_enum_init(assign.value, ftype);
    }
    gv.initializer = const_init if const_init is not None else ir.Constant(ftype, None);

    if const_init is None {
        if not self?._global_init_nodes {
            self._global_init_nodes: list = [];
        }
        self._global_init_nodes.append((full_name, assign.value, ftype));
    }
}

impl NaIRGenObjects._class_const_enum_init(
    value: uni.UniNode, ftype: ir.Type
) -> (ir.Constant | None) {
    if not isinstance(value, uni.AtomTrailer) {
        return None;
    }
    _cls = self._get_name(value.target);
    _mem = self._get_name(value.right);
    if _cls is None or _mem is None {
        return None;
    }
    _full = f"{_cls}.{_mem}";
    if _full not in self.enum_values {
        self._codegen_enum_layout(_cls, None);
    }
    _val = self.enum_values.get(_full);
    if _val is None {
        _val = self._codegen_class_form_enum_member(value);
    }
    if not isinstance(_val, ir.Constant) or not isinstance(ftype, ir.IntType) {
        return None;
    }
    return ir.Constant(ftype, _val.constant);
}


impl NaIRGenObjects._method_slot_name(
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

impl NaIRGenObjects._forward_declare_method(
    arch_name: str,
    method: uni.Ability,
    field: (uni.HasVar | None) = None,
    imported: bool = False
) -> None {
    if method.is_comptime {
        return;
    }
    method_name = self._method_slot_name(method, field);
    full_name = f"{arch_name}.{method_name}";

    if method.type_params {
        self._generic_methods[full_name] = method;
        self.has_native_code = True;
        return;
    }
    if full_name in self.method_funcs {
        return;
    }
    if full_name in self._native_skipped_methods {
        return;
    }
    sig = method.signature;
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or (sig is None and field is None) {
        return;
    }

    _is_static = method.is_static or method.is_classmethod;

    _m_params = sig.get_parameters() if sig is not None else [];
    if (
        not _is_static
        and _m_params
        and _m_params[0].name
        and _m_params[0].name.value == "self"
    ) {
        _m_params = _m_params[1:];
    }
    if (
        method.is_classmethod
        and _m_params
        and _m_params[0].name
        and _m_params[0].name.value == "cls"
    ) {
        _m_params = _m_params[1:];
    }

    _self_type = self._class_form_enum_self_type(arch_name) or struct_type.as_pointer();

    _sig_mark = len(self.errors_had);
    _saved_sig_kind = self._sig_decl_kind;
    self._sig_decl_kind = "signature type";

    param_types: list[ir.Type] = [] if _is_static else [_self_type];
    for p in _m_params {
        param_types.append(
            self._resolve_sig_type(p) if p.type_tag is not None else ir.IntType(64)
        );
    }

    ret_type = self._resolve_sig_type(sig.return_type)
        if sig is not None
        else ir.IntType(64);

    if sig is None and field is not None {
        if method.accessor_kind == "property" {
            ret_type = self._resolve_sig_type(field);
        } elif method.accessor_kind == "setter" {
            param_types.append(self._resolve_sig_type(field));
        }
    }
    self._sig_decl_kind = _saved_sig_kind;
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=full_name);

    _base = 0 if _is_static else 1;
    if not _is_static {
        func.args[0].name = "self";
    }
    for (i, p) in enumerate(_m_params) {
        func.args[i + _base].name = p.name.value if p.name else f"arg{i}";
    }
    if len(func.args) > _base + len(_m_params) {
        func.args[_base + len(_m_params)].name = "value";
    }
    self._apply_ownership_param_attrs(func, _m_params, _base);
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;
    if _is_static {
        self.static_methods[full_name] = True;
    }

    if len(self.errors_had) > _sig_mark {
        self._demote_method_if_unlowerable(
            full_name,
            func,
            _sig_mark,
            keep_func=method_name in self.vtable_method_indices.get(arch_name, {}),
            stub_body=not imported
        );
    }
}

impl NaIRGenObjects._codegen_method(
    arch_name: str,
    method: uni.Ability,
    symbol_override: (str | None) = None,
    field: (uni.HasVar | None) = None
) -> None {
    if method.is_comptime {
        return;
    }
    method_name = self._method_slot_name(method, field);

    full_name = symbol_override or f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }
    if full_name in self._native_skipped_methods or func.blocks {
        return;
    }

    _pre_viols = self._capability_demotions.get(id(method));
    if _pre_viols is not None {
        self._claimed_capability_demotions.add(id(method));
        _pre_virtual = method_name in self.vtable_method_indices.get(arch_name, {});
        if self._predemote_capability_unit(
            full_name, func, _pre_viols, keep_func=_pre_virtual
        ) {
            return;
        }
    }

    block = func.append_basic_block(name="entry");
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_list_elem_struct = dict(self.var_list_elem_struct);
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};

    saved_self_arch = self._self_arch;
    self._self_arch = arch_name;

    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );

    _scan_body = ModuleCodegenPass.unwrap_body(method);
    if _scan_body is not None {
        _scan_owner = method.body if isinstance(method.body, uni.ImplDef) else method;
        self._scan_closure_escapes(_scan_owner, _scan_body);
    }

    _is_static = method.is_static or method.is_classmethod;
    _base = 0;
    sig = method.signature;
    _body_params = sig.get_parameters() if sig is not None else [];
    _self_param: (uni.ParamVar | None) = None;
    if (
        not _is_static
        and _body_params
        and _body_params[0].name
        and _body_params[0].name.value == "self"
    ) {
        _self_param = _body_params[0];
        _body_params = _body_params[1:];
    }
    self._self_owned = _self_param is not None and self._nogc_owned_param(_self_param);
    if not _is_static {
        self_alloca = self.builder.alloca(func.args[0].type, name="self");
        self.builder.store(func.args[0], self_alloca);
        self.local_vars["self"] = self_alloca;
        if not self._self_owned {
            self.param_vars.add("self");
        }
        _base = 1;
    }
    if (
        method.is_classmethod
        and _body_params
        and _body_params[0].name
        and _body_params[0].name.value == "cls"
    ) {
        _body_params = _body_params[1:];
    }

    _bound_params: list[tuple[(str, bool)]] = [
        ((p.name.value if p.name else f"arg{i}"), bool(p.name?.sym?.param_rebound), )
        for (i, p) in enumerate(_body_params)
    ];
    if sig is None and len(func.args) > _base + len(_bound_params) {
        _bound_params.append(("value", False, ));
    }
    for (i, (param_name, _p_rebound)) in enumerate(_bound_params) {
        arg_val = func.args[i + _base];
        if param_name in self.closure_cell_vars {
            slot = self._emit_closure_cell(param_name, arg_val.type);
            self.builder.store(arg_val, slot);
            self.local_vars[param_name] = slot;
            if isinstance(arg_val.type, ir.PointerType) {
                self._emit_rc_retain(arg_val, op="param_cell", loc=full_name);
            }
            continue;
        }
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;

        if isinstance(arg_val.type, ir.PointerType) and _p_rebound {
            self._emit_rc_retain(arg_val, op="param_promote", loc=full_name);
        } else {
            self.param_vars.add(param_name);
        }
    }

    _is_virtual = method_name in self.vtable_method_indices.get(arch_name, {});
    _local_mark = len(self.errors_had);

    try {
        body = ModuleCodegenPass.unwrap_body(method);
        if body is not None {
            self._codegen_body(body);
        }

        if not self.builder.block.is_terminated {
            _mth_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
                if method.loc
                else 0}";

            self._emit_scope_cleanup(skip_var=None, loc=_mth_loc);
            ret_type = func.return_value.type;
            if isinstance(ret_type, ir.VoidType) {
                self.builder.ret_void();
            } else {
                self.builder.ret(self._zero_const(ret_type));
            }
        }
        method.gen.llvm_ir = func;

        self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    } except Exception as _codegen_exc {
        if self._na_debug_on() {
            import sys;
            import traceback;
            sys.stderr.write(f"NA_DEBUG raise {full_name}\n");
            traceback.print_exc(file=sys.stderr);
        }
        self.emit(
            E5092,
            node_override=method,
            kind="method (native emitter error in)",
            name=full_name,
            help_text=f"The native backend raised {type(_codegen_exc).__name__} "
            f"while lowering this method; it falls back to its Python "
            f"implementation. Original error: {_codegen_exc}"
        );
    }

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_list_elem_struct;
    self._self_arch = saved_self_arch;
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;

    self._demote_method_if_unlowerable(
        full_name, func, _local_mark, keep_func=_is_virtual
    );
}

impl NaIRGenObjects._demote_method_if_unlowerable(
    full_name: str,
    func: ir.Function,
    local_mark: int,
    keep_func: bool = False,
    stub_body: bool = True
) -> bool {
    if len(self.errors_had) <= local_mark {
        return False;
    }
    _own = list(self.errors_had[local_mark:]);

    _na_debug = self._na_debug_on();
    if self._seam_warnings_on() {
        import from jaclang.cli.console { console }
        _why = "; ".join(str(e) for e in _own);
        console.warning(
            f"native seam -- demoting {full_name} to Python-only "
            f"(un-lowerable): {_why}"
        );
    }
    if _na_debug {
        import sys;
        sys.stderr.write(f"NA_DEBUG demote {full_name}\n");
        for _diag in _own {
            sys.stderr.write(f"NA_DEBUG   {_diag.pretty_print()}\n");
        }
    }
    if stub_body {
        try {
            import from jaclang.compiler.driver.na_coverage { na_coverage_seam }
            _first_code = _own[0].code.code if _own[0].code is not None else "";
            _code_tag = f"[{_first_code}] " if _first_code else "";
            na_coverage_seam(
                self.ir_in.loc.mod_path,
                f"{full_name}: {_code_tag}" + str(_own[0]).split('\n')[0]
            );
        } except Exception {}
    }
    del self.errors_had[local_mark:];

    if stub_body {
        func.blocks.clear();
        blk = func.append_basic_block(name="entry");
        b = ir.IRBuilder(blk);
        self._get_or_declare_extern("abort", ir.VoidType(), []);
        b.call(self.extern_funcs["abort"], []);
        b.unreachable();
    }
    if not keep_func {
        self.method_funcs.pop(full_name, None);
    }
    self.func_symtab.pop(full_name, None);
    self._native_skipped_methods.add(full_name);
    return True;
}

impl NaIRGenObjects._seam_warnings_on -> bool {
    """Whether a seam this run takes should also be announced on stderr.""";
    if self._na_debug_on() or bool(self.prog.options.native_debug) {
        return True;
    }
    try {
        import from jaclang.project.config { get_config }
        _cfg = get_config();
        if _cfg and _cfg.check {
            return bool(_cfg.check.warn_native_seams);
        }
    } except Exception {}
    return True;
}

impl NaIRGenObjects._opaque_field_if_unlowerable(
    arch_name: str, fname: str, local_mark: int
) -> (ir.Type | None) {
    """Spend a field declaration's refusal on the field, not on the module.

    A `has` type with no native layout sits outside every ability body, so
    `_demote_method_if_unlowerable` has nothing to take it from and the
    diagnostic used to survive to the end of the run, where a non-empty
    `errors_had` withholds the module's IR. The declaration owns it here the
    way #8285 made a signature's declaration own its own: the slot erases to
    an opaque pointer, the field is recorded so that every read and write of
    it refuses inside the callable that performs it, and the refusal is
    re-published as a coverage seam keyed on the field rather than swallowed.

    An erased slot is storage the native side never writes, so the field also
    joins `struct_field_foreign` -- the constructor, the tracer, the arena and
    the reference counter all already skip that set.
    """;
    if len(self.errors_had) <= local_mark {
        return None;
    }
    _own = list(self.errors_had[local_mark:]);
    _first = _own[0];
    _code = _first.code.code if _first.code is not None else "";
    _why = str(_first).split('\n')[0];

    if self._seam_warnings_on() {
        import from jaclang.cli.console { console }
        console.warning(
            f"native seam -- erasing field {arch_name}.{fname} to an "
            f"opaque slot (un-lowerable declaration): "
                + "; ".join(str(e) for e in _own)
        );
    }
    try {
        import from jaclang.compiler.driver.na_coverage { na_coverage_seam }
        na_coverage_seam(
            self.ir_in.loc.mod_path,
            f"{arch_name}.{fname}: " + (f"[{_code}] " if _code else "") + _why
        );
    } except Exception {}
    del self.errors_had[local_mark:];
    if arch_name not in self.struct_field_opaque {
        self.struct_field_opaque[arch_name] = {};
    }
    self.struct_field_opaque[arch_name][fname] = _why;
    return ir.IntType(8).as_pointer();
}

impl NaIRGenObjects._refuse_opaque_field(
    nd: (uni.UniNode | None), type_name: (str | None), fname: str
) -> bool {
    """Refuse a touch of an erased slot, inside the callable that touches it.

    The slot carries no value the native side put there, so answering with
    its bits would be wrong rather than merely un-lowered. Emitting here puts
    the diagnostic inside the enclosing callable's demotion window, which is
    what turns one un-lowerable declaration into a seam per method that reads
    or writes it instead of a dead module.
    """;
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

impl NaIRGenObjects._codegen_no_sig_method(
    arch_name: str, method: uni.Ability
) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }

    block = func.append_basic_block(name="entry");
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_list_elem_struct = dict(self.var_list_elem_struct);
    saved_self_arch = self._self_arch;
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    self._self_arch = arch_name;
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};

    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );

    _scan_body = ModuleCodegenPass.unwrap_body(method);
    if _scan_body is not None {
        _scan_owner = method.body if isinstance(method.body, uni.ImplDef) else method;
        self._scan_closure_escapes(_scan_owner, _scan_body);
    }

    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    self.param_vars.add("self");

    body = ModuleCodegenPass.unwrap_body(method);
    if body is not None {
        self._codegen_body(body);
    }

    if not self.builder.block.is_terminated {
        _nosig_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
            if method.loc
            else 0}";

        self._emit_scope_cleanup(skip_var=None, loc=_nosig_loc);
        self.builder.ret_void();
    }
    method.gen.llvm_ir = func;

    self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_list_elem_struct;
    self._self_arch = saved_self_arch;
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;
}

impl NaIRGenObjects._trigger_member_structs(tag: (uni.UniNode | None)) -> list[str] {
    out: list[str] = [];
    if tag is None {
        return out;
    }
    parts: list[uni.UniNode] = [];
    if isinstance(tag, uni.TupleVal) {
        parts = list(tag.values or []);
    } elif isinstance(tag, uni.BinaryExpr) and getattr(tag.op, "value", "") == "|" {
        parts = [tag.left, tag.right];
    } else {
        parts = [tag];
    }
    for part in parts {
        if isinstance(part, uni.TupleVal)
            or (
                isinstance(part, uni.BinaryExpr)
                and getattr(part.op, "value", "") == "|"
            ) {
            for nm in self._trigger_member_structs(part) {
                if nm not in out {
                    out.append(nm);
                }
            }
            continue;
        }
        name = self._get_name(part);
        if name is not None and name in self.struct_types and name not in out {
            out.append(name);
        }
    }
    return out;
}

impl NaIRGenObjects._trigger_struct_names(method: uni.Ability) -> list[str] {
    names = method.event_trigger_type_names();
    if names is None {
        sig = method.signature;
        tag = sig.arch_tag_info if isinstance(sig, uni.EventSignature) else None;
        return self._trigger_member_structs(tag);
    }
    return [
        nm
        for nm in names
        if nm in self.struct_types
    ];
}

impl NaIRGenObjects._read_field_or_refuse(
    nd: uni.UniNode, obj_val: ir.Value, field_name: str, arch_name: str
) -> (ir.Value | None) {
    """Read a field, naming the ancestor when an inherited one is unreachable.

    Only the inherited case speaks up here. Every other way a name can miss
    the layout already has an owner further out that reports it, and claiming
    them from this depth would rename diagnostics this change has no business
    touching.
    """;
    _mark = len(self.errors_had);
    _val = self._codegen_field_access(obj_val, field_name, arch_name, nd);
    if _val is None and len(self.errors_had) == _mark {
        _val = self._codegen_class_const_read(obj_val, arch_name, field_name);
        if _val is None {
            self._emit_field_access_refusal(nd, arch_name, field_name);
        }
    }
    return _val;
}

impl NaIRGenObjects._unadopted_field_owner(
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
        _bn = self._get_name(_base);
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

impl NaIRGenObjects._emit_field_access_refusal(
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

impl NaIRGenObjects._class_const_declarer(
    arch_name: str, field_name: str
) -> (str | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    _seen: list[str] = list(self._mro_of(arch_name));
    for _cls in get_layout_registry(self.ir_in, self.prog).mro_order {
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

impl NaIRGenObjects._mro_of(arch_name: str) -> list[str] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    mro = get_layout_registry(self.ir_in, self.prog).get_mro(arch_name);
    return mro or [arch_name];
}

impl NaIRGenObjects._arch_layout(arch_name: str) -> (ArchetypeLayout | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }

    _owner = None;
    _arch_nd = self.arch_ast_map.get(arch_name);
    if _arch_nd is not None {
        _owner = _arch_nd.find_parent_of_type(uni.Module);
    }
    for _cand in [_owner, self.ir_in] {
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

impl NaIRGenObjects._arch_has_vtable(arch_name: str) -> bool {
    if arch_name not in self.struct_types {
        return False;
    }
    lay = self._arch_layout(arch_name);
    return lay is not None and lay.has_vtable;
}

impl NaIRGenObjects._union_layout_conflict(members: list[str]) -> (str | None) {
    if len(members) <= 1 {
        return None;
    }
    base = members[0];
    base_idx = self.struct_field_indices.get(base, {});
    base_types = self.struct_field_types.get(base, {});
    for fname in base_idx {
        for other in members[1:] {
            other_idx = self.struct_field_indices.get(other, {});
            if fname not in other_idx {
                continue;
            }
            other_types = self.struct_field_types.get(other, {});
            if other_idx[fname] != base_idx[fname]
                or base_types.get(fname) != other_types.get(fname) {
                return fname;
            }
        }
    }
    return None;
}

impl NaIRGenObjects._forward_declare_event_method(
    arch_name: str, method: uni.Ability
) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    if full_name in self.method_funcs {
        return;
    }
    sig = method.signature;
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or not isinstance(sig, uni.EventSignature) {
        return;
    }
    loc_type: ir.Type = ir.IntType(8).as_pointer();
    if sig.arch_tag_info is not None {
        _members = self._trigger_struct_names(method);
        if _members {
            loc_type = self.struct_types[_members[0]].as_pointer();
        } else {
            loc_type = self._resolve_jac_type(sig.arch_tag_info);
        }
    }
    fnty = ir.FunctionType(ir.VoidType(), [struct_type.as_pointer(), loc_type]);
    func = ir.Function(self.llvm_module, fnty, name=full_name);
    func.args[0].name = "self";
    func.args[1].name = "here" if sig.from_walker else "visitor";
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;
}

impl NaIRGenObjects._codegen_event_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    sig = method.signature;
    if func is None or not isinstance(sig, uni.EventSignature) {
        return;
    }
    _pre_viols = self._capability_demotions.get(id(method));
    if _pre_viols is not None {
        self._claimed_capability_demotions.add(id(method));
        if self._predemote_capability_unit(
            full_name, func, _pre_viols, keep_func=True
        ) {
            return;
        }
    }
    block = func.append_basic_block(name="entry");
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_list_elem_struct = dict(self.var_list_elem_struct);
    saved_self_arch = self._self_arch;
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    saved_region_opens = self.region_open_stack;
    self._self_arch = arch_name;
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};
    self.region_open_stack = [];
    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );
    _scan_body = ModuleCodegenPass.unwrap_body(method);
    if _scan_body is not None {
        _scan_owner = method.body if isinstance(method.body, uni.ImplDef) else method;
        self._scan_closure_escapes(_scan_owner, _scan_body);
    }
    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    self.param_vars.add("self");

    loc_name = "here" if sig.from_walker else "visitor";
    loc_arg = func.args[1];
    loc_alloca = self.builder.alloca(loc_arg.type, name=loc_name);
    self.builder.store(loc_arg, loc_alloca);
    self.local_vars[loc_name] = loc_alloca;
    self.param_vars.add(loc_name);
    _grow_anchor = loc_arg if sig.from_walker else func.args[0];
    self._region_enter(self._region_of_value(_grow_anchor));
    self.region_open_stack.append(len(self.loop_stack));
    if sig.arch_tag_info is not None {
        _members = self._trigger_struct_names(method);
        _conflict = self._union_layout_conflict(_members);
        if _conflict is not None {
            self.emit(
                E5091,
                node_override=sig.arch_tag_info,
                members=", ".join(_members),
                field=_conflict
            );
        }
    }
    body = ModuleCodegenPass.unwrap_body(method);
    if body is not None {
        self._codegen_body(body);
    }
    self.region_open_stack.pop();
    if not self.builder.block.is_terminated {
        self._region_leave();
        _ev_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
            if method.loc
            else 0}";
        self._emit_scope_cleanup(skip_var=None, loc=_ev_loc);
        self.builder.ret_void();
    }
    method.gen.llvm_ir = func;
    self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_list_elem_struct;
    self._self_arch = saved_self_arch;
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;
    self.region_open_stack = saved_region_opens;
}

impl NaIRGenObjects._emit_heap_object_alloc(
    nd: uni.UniNode, type_name: str, size: ir.Value, headerless: bool
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    if headerless {
        _malloc_fn = self._get_or_declare_extern("malloc", i8p, [i64]);
        raw_ptr = self.builder.call(_malloc_fn, [size], name="raw.ptr");
        self._emit_struct_drop_fn(type_name);
        return raw_ptr;
    }
    _inst_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    _alloc_fn = self.rc_alloc_fn;
    assert _alloc_fn is not None , "rc helpers are emitted before allocation";
    raw_ptr = self._rc_call_with_ctx(
        _alloc_fn, [size], op="new", loc=_inst_loc, name="raw.ptr"
    );
    self._emit_struct_release_fn(type_name);
    _dtor_fn_s = self.struct_release_fns.get(type_name);
    if _dtor_fn_s is not None {
        _dtor_slot_s = self.builder.gep(
            raw_ptr, [ir.Constant(i64, HDR_DTOR_OFF)], name="obj_dtor_slot"
        );
        _dtor_slot_i64_s = self.builder.bitcast(
            _dtor_slot_s, i64.as_pointer(), name="obj_dtor_i64p"
        );
        _dtor_i64_s = self.builder.ptrtoint(_dtor_fn_s, i64, name="obj_dtor_i64");
        self.builder.store(_dtor_i64_s, _dtor_slot_i64_s);
    }
    self._emit_trace_fn(type_name);
    _trace_fn_s = self.struct_trace_fns.get(type_name);
    self._require_trace_fn(
        type_name,
        (
            self._struct_has_ref_fields(type_name)
            and not self._arch_is_acyclic(type_name)
        ),
        _trace_fn_s is not None
    );
    if self.rc_set_type_fn is not None {
        self._emit_set_type_tag(self.builder, raw_ptr, type_name);
    }
    return raw_ptr;
}

impl NaIRGenObjects._stack_alloc_target_ok(nd: uni.UniNode) -> bool {
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

impl NaIRGenObjects._empty_container_for_field(
    ftype: (ir.Type | None), label: str
) -> (ir.Value | None) {
    if ftype is None or not isinstance(ftype, ir.PointerType) {
        return None;
    }
    for (dict_key, dtype) in self.dict_types.items() {
        if ftype == dtype.as_pointer() {
            dict_helpers = self.dict_helpers.get(dict_key);
            return (
                self.builder.call(dict_helpers["new"], [], name=f"dict.{label}")
                    if dict_helpers is not None
                    else None
            );
        }
    }
    for (list_key, ltype) in self.list_types.items() {
        if ftype == ltype.as_pointer() {
            list_helpers = self.list_helpers.get(list_key);
            return (
                self.builder.call(list_helpers["new"], [], name=f"list.{label}")
                    if list_helpers is not None
                    else None
            );
        }
    }
    for (set_key, stype) in self.set_types.items() {
        if ftype == stype.as_pointer() {
            set_helpers = self.set_helpers.get(set_key);
            return (
                self.builder.call(set_helpers["new"], [], name=f"set.{label}")
                    if set_helpers is not None
                    else None
            );
        }
    }
    return None;
}

impl NaIRGenObjects._codegen_instantiation(
    nd: (uni.FuncCall | uni.Name),
    type_name_override: (str | None) = None,
    ctor_params: (list | None) = None
) -> (ir.Value | None) {
    _is_call = isinstance(nd, uni.FuncCall);
    type_name = type_name_override
        if type_name_override is not None
        else self._get_name(nd.target if _is_call else nd);
    if type_name is None or type_name not in self.struct_types {
        return None;
    }
    if self._reject_scalar_type_args(nd, type_name) {
        return None;
    }
    _demoted_init = self._demoted_init_of(type_name);
    if _demoted_init is not None {
        self.emit(
            E5092,
            node_override=nd,
            kind="constructor",
            name=f"{type_name}() via {_demoted_init}",
            help_text=(
                "The initializer was demoted to its Python implementation, so "
                "native construction has no initializer to call and would "
                "leave the object half-built. Construct this class from a "
                "Python/@sv context, or make the initializer lowerable."
            )
        );
        return None;
    }
    struct_type = self.struct_types[type_name];
    struct_ptr_type = struct_type.as_pointer();

    params = ctor_params
        if ctor_params is not None
        else ((nd.params or []) if _is_call else []);
    _has_init = (
        f"{type_name}.init" in self.method_funcs
        or f"{type_name}.__init__" in self.method_funcs
    );
    _pos_field_pairs: list = [];
    if not _has_init {
        _pos_args = [
            p
            for p in params
            if not isinstance(p, uni.KWPair)
        ];
        if _pos_args and self._pyb_base_of(type_name) is not None {
            self.emit(
                E5092,
                node_override=nd,
                kind="constructor call",
                name=type_name,
                help_text=(
                    f"'{type_name}' inherits from a Python-side base, so its "
                    f"constructor arguments cannot be matched positionally; "
                    f"use keyword arguments."
                )
            );
            return None;
        }
        if _pos_args {
            _order = self.struct_field_order.get(type_name);
            if _order is None or len(_pos_args) > len(_order) {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="constructor call",
                    name=type_name,
                    help_text=f"Positional arguments to '{type_name}' lower natively only up to its declared has-field count and only when its field layout is visible to this module."
                );
                return None;
            }
            for (_pi, _pv) in enumerate(_pos_args) {
                _pos_field_pairs.append((_order[_pi], _pv));
            }
        }
    }

    _vt_struct = type_name in self.clib_vtable_structs;
    _stack_ok = (
        not _vt_struct
        and self._stack_alloc_target_ok(nd)
        and self._arch_is_acyclic(type_name)
        and not self._struct_has_ref_fields(type_name)
        and not self._arch_has_vtable(type_name)
        and not self._arch_is_osp_name(type_name)
        and f"{type_name}.drop" not in self.func_symtab
        and not self.struct_field_inline.get(type_name, None)
        and self._pyb_base_of(type_name) is None
    );
    _headerless = self._nogc_headerless() and not self._arch_is_osp_name(type_name);
    if _stack_ok and _headerless {
        obj_ptr = self._entry_alloca(struct_type, f"stk.{type_name}");
        self.rc_stack_promotions += 1;
        _tgt_asgn = nd.find_parent_of_type(uni.Assignment);
        if _tgt_asgn is not None
            and len(_tgt_asgn.target) == 1
            and isinstance(_tgt_asgn.target[0], uni.Name) {
            self.nogc_no_free_vars.add(_tgt_asgn.target[0].sym_name);
        }
    } elif _stack_ok {
        self.rc_stack_promotions += 1;
        _i8 = ir.IntType(8);
        _i32s = ir.IntType(32);
        _i64s = ir.IntType(64);
        _hdr_arr = ir.ArrayType(_i8, HDR_TOTAL);
        _slab_ty = ir.LiteralStructType([_hdr_arr, struct_type]);
        _slab = self._entry_alloca(_slab_ty, f"stk.{type_name}");
        obj_ptr = self.builder.gep(
            _slab, [ir.Constant(_i32s, 0), ir.Constant(_i32s, 1)], name="stk.obj"
        );
        _stk_i8 = self.builder.bitcast(obj_ptr, _i8.as_pointer(), name="stk.i8");
        _stk_rc_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_RC_OFF)], name="stk.rc.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, RC_SENTINEL),
            self.builder.bitcast(_stk_rc_slot, _i64s.as_pointer(), name="stk.rc.p")
        );
        _stk_dtor_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_DTOR_OFF)], name="stk.dtor.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, 0),
            self.builder.bitcast(_stk_dtor_slot, _i64s.as_pointer(), name="stk.dtor.p")
        );
        _stk_aid_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_ALLOC_ID_OFF)], name="stk.aid.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, 0),
            self.builder.bitcast(_stk_aid_slot, _i64s.as_pointer(), name="stk.aid.p")
        );
        if self.rc_set_type_fn is not None {
            self._emit_set_type_tag(self.builder, _stk_i8, type_name);
        }
    } elif _vt_struct {
        obj_ptr = self._clib_alloc_vtable(type_name);
    } else {
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        _region_eligible = (
            id(nd) != self._managed_ctor_node
            and not self._arch_is_walker_name(type_name)
            and not bool(getattr(self.prog.options, "kernel_unit", False))
        );
        if not _region_eligible {
            raw_ptr = self._emit_heap_object_alloc(nd, type_name, size, _headerless);
        } else {
            _i8p_a = ir.IntType(8).as_pointer();
            _func_a = self.builder.function;
            _heap_bb = _func_a.append_basic_block(name="alloc.heap");
            _rgn_bb = _func_a.append_basic_block(name="alloc.region");
            _merge_bb = _func_a.append_basic_block(name="alloc.merge");
            _cur = self._region_current();
            self.builder.cbranch(
                self.builder.icmp_unsigned(
                    "==", _cur, ir.Constant(_i8p_a, None), name="alloc.nocur"
                ),
                _heap_bb,
                _rgn_bb
            );
            self.builder.position_at_end(_heap_bb);
            _heap_raw = self._emit_heap_object_alloc(nd, type_name, size, _headerless);
            _heap_end = self.builder.block;
            self.builder.branch(_merge_bb);
            self.builder.position_at_end(_rgn_bb);
            _rgn_raw = self._region_alloc_object(_cur, size, type_name);
            _rgn_end = self.builder.block;
            self.builder.branch(_merge_bb);
            self.builder.position_at_end(_merge_bb);
            _phi = self.builder.phi(_i8p_a, name="alloc.raw");
            _phi.add_incoming(_heap_raw, _heap_end);
            _phi.add_incoming(_rgn_raw, _rgn_end);
            raw_ptr = _phi;
        }
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
    }

    vtable_global = self._vtable_global_for(type_name);
    if vtable_global is not None {
        vtable_base = self.builder.gep(
            vtable_global,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.base"
        );
        vtable_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.slot"
        );
        self.builder.store(vtable_base, vtable_slot);
    }

    _tt_idx = self.osp_type_tag_field.get(type_name);
    if _tt_idx is not None {
        _tt_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), _tt_idx)],
            name="type_tag.slot"
        );

        _tt_val = stable_osp_tag(type_name);
        self.builder.store(ir.Constant(ir.IntType(64), _tt_val), _tt_slot);

        if not self._arch_is_walker_name(type_name) {
            self._osp_make_immortal(obj_ptr);
        }
    }

    _rep_idx = self.osp_reports_field.get(type_name);
    if _rep_idx is not None {
        _rep_h = self.list_helpers.get("jacval");
        if _rep_h is not None {
            _rep_list = self._rc_call_with_ctx(
                _rep_h["new"], [], op="new", loc="", name="reports.init"
            );
            self.builder.store(
                _rep_list,
                self.builder.gep(
                    obj_ptr,
                    [
                        ir.Constant(ir.IntType(32), 0),
                        ir.Constant(ir.IntType(32), _rep_idx)
                    ],
                    name="reports.slot"
                )
            );
        }
    }

    field_indices = self.struct_field_indices.get(type_name, {});
    field_types = self.struct_field_types.get(type_name, {});
    field_defaults = self.struct_field_defaults.get(type_name, {});
    foreign_fields = self.struct_field_foreign.get(type_name, set());

    set_fields: set[str] = set();
    _field_inits: list = list(_pos_field_pairs);
    for param in params {
        if isinstance(param, uni.KWPair) {
            _kn = param.key.sym_name if param.key else None;
            if _kn is not None {
                _field_inits.append((_kn, param.value));
            }
        }
    }
    if isinstance(nd, uni.FuncCall) {
        for (_ct_name, _ct_expr) in self._ct_ctor_slots(nd.target) {
            _field_inits.append((_ct_name, _ct_expr));
        }
    }
    for (key_name, init_expr) in _field_inits {
        if key_name not in field_indices or key_name in set_fields {
            continue;
        }
        if self._refuse_opaque_field(init_expr, type_name, key_name) {
            continue;
        }
        if key_name in foreign_fields {
            continue;
        }
        val = self._codegen_expr(init_expr);
        if val is None {
            val = self._empty_container_for_field(
                field_types.get(key_name), f"ctor.{key_name}"
            );
            if val is None {
                continue;
            }
        }
        idx = field_indices[key_name];
        ftype = field_types[key_name];

        if key_name in self.struct_field_inline.get(type_name, set()) {
            _inl_fp = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"field.{key_name}"
            );
            self._store_inline_field(type_name, key_name, _inl_fp, val, False);
            self._nogc_consume_local(init_expr);
            set_fields.add(key_name);
            continue;
        }

        _is_clib_cb = (
            type_name in self.clib_vtable_structs
            and isinstance(ftype, ir.PointerType)
            and isinstance(ftype.pointee, ir.FunctionType)
        );
        if _is_clib_cb {
            val = self._clib_coerce_callback(val, ftype);
        } else {
            val = self._coerce_type(val, ftype);
        }

        if not _vt_struct {
            self._emit_take_ref(
                val,
                op="ctor_field",
                loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                    if nd.loc
                    else 0}"
            );
        }
        field_ptr = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{key_name}"
        );
        self.builder.store(val, field_ptr);
        self._nogc_consume_local(init_expr);
        set_fields.add(key_name);
    }

    for (fname, default_expr) in field_defaults.items() {
        if fname not in set_fields {
            val = self._codegen_expr(default_expr);

            if val is None {
                val = self._empty_container_for_field(
                    field_types.get(fname), f"dflt.{fname}"
                );
            }
            if val is not None
                and fname in self.struct_field_inline.get(type_name, set()) {
                _inl_fp = self.builder.gep(
                    obj_ptr,
                    [
                        ir.Constant(ir.IntType(32), 0),
                        ir.Constant(ir.IntType(32), field_indices[fname])
                    ],
                    name=f"field.{fname}"
                );
                self._store_inline_field(type_name, fname, _inl_fp, val, False);
                set_fields.add(fname);
                continue;
            }
            if val is not None {
                idx = field_indices[fname];
                ftype = field_types[fname];

                _is_clib_cb_d = (
                    type_name in self.clib_vtable_structs
                    and isinstance(ftype, ir.PointerType)
                    and isinstance(ftype.pointee, ir.FunctionType)
                );
                if _is_clib_cb_d {
                    val = self._clib_coerce_callback(val, ftype);
                } else {
                    val = self._coerce_type(val, ftype);
                }

                if not _vt_struct {
                    self._emit_take_ref(
                        val,
                        op="ctor_field",
                        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                            if nd.loc
                            else 0}"
                    );
                }
                field_ptr = self.builder.gep(
                    obj_ptr,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                    name=f"default.{fname}"
                );
                self.builder.store(val, field_ptr);
                set_fields.add(fname);
            }
        }
    }

    for (fname, idx) in field_indices.items() {
        if fname not in set_fields {
            ftype = field_types[fname];
            zero_val = ir.Constant(ftype, None);
            field_ptr = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"zero.{fname}"
            );
            self.builder.store(zero_val, field_ptr);
        }
    }

    if not self._codegen_pyb_shadow_init(
        nd, type_name, obj_ptr, params, field_indices
    ) {
        return None;
    }

    init_fn: (ir.Function | None) = None;
    _init_owner: str = type_name;
    for _init_cls in self._mro_of(type_name) {
        for candidate in [f"{_init_cls}.init", f"{_init_cls}.__init__"] {
            if candidate in self.method_funcs {
                init_fn = self.method_funcs[candidate];
                _init_owner = _init_cls;
                break;
            }
        }
        if init_fn is not None {
            break;
        }
    }
    if init_fn is not None and _init_owner != type_name {
        import from jaclang.compiler.passes.layout_pass {
            get_layout_registry as _ci_glr
        }
        if not _ci_glr(self.ir_in, self.prog).is_primary_ancestor(
            type_name, _init_owner
        ) {
            self.emit(
                E5092,
                node_override=nd,
                kind="constructor",
                name=f"{type_name}() via {_init_owner}.init",
                help_text=(
                    "The inherited initializer belongs to an ancestor that is "
                    "not layout-prefix-compatible with this class, so calling "
                    "it directly would address the wrong field offsets."
                )
            );
            return None;
        }
    }
    if init_fn is not None {
        init_args: list[ir.Value] = [obj_ptr];
        init_sig = self._arch_init_sig_of(_init_owner) if _is_call else None;
        if init_sig is not None {
            _init_pos: list = [];
            _init_kw: dict = {};
            for param in params {
                if isinstance(param, uni.KWPair) {
                    _k = param.key.sym_name if param.key is not None else None;
                    if _k is not None {
                        _init_kw[_k] = param.value;
                    }
                } else {
                    _init_pos.append(param);
                }
            }
            _sig_params = init_sig.get_parameters();
            for (pix, sp) in enumerate(_sig_params) {
                _slot = 1 + pix;
                _expected = init_fn.args[_slot].type
                    if _slot < len(init_fn.args)
                    else ir.IntType(64);
                _chosen: (uni.Expr | None) = None;
                if pix < len(_init_pos) {
                    _chosen = _init_pos[pix];
                } elif sp.name.sym_name in _init_kw {
                    _chosen = _init_kw[sp.name.sym_name];
                } elif sp.value is not None {
                    _chosen = sp.value;
                }
                _val = self._codegen_expr(_chosen) if _chosen is not None else None;
                if _val is not None {
                    init_args.append(_val);
                } else {
                    init_args.append(self._default_arg_fallback(_expected));
                }
            }
            for pix in range(len(_sig_params), len(_init_pos)) {
                _extra = self._codegen_expr(_init_pos[pix]);
                if _extra is not None {
                    init_args.append(_extra);
                }
            }
        } else {
            for param in params {
                if not isinstance(param, uni.KWPair) {
                    val = self._codegen_expr(param);
                    if val is not None {
                        init_args.append(val);
                    }
                }
            }
            _fill = len(init_args);
            while _fill < len(init_fn.args) {
                init_args.append(self._default_arg_fallback(init_fn.args[_fill].type));
                _fill += 1;
            }
        }

        coerced_args: list[ir.Value] = [];
        for (i, arg) in enumerate(init_args) {
            if i < len(init_fn.args) {
                coerced_args.append(self._coerce_type(arg, init_fn.args[i].type));
            } else {
                coerced_args.append(arg);
            }
        }
        self.builder.call(init_fn, coerced_args, name="call.init");
    }

    _pi_auto = init_fn is None;
    for _pi_cls in self._mro_of(type_name) {
        _pi_arch = self.arch_ast_map.get(_pi_cls);
        if _pi_arch is None {
            continue;
        }
        _pi_own_init = False;
        if _pi_arch.body is not None {
            for _pi_stmt in _pi_arch.body {
                if isinstance(_pi_stmt, uni.Ability)
                    and _pi_stmt.name_ref is not None
                    and _pi_stmt.name_ref.sym_name in ("init", "__init__") {
                    _pi_own_init = True;
                    break;
                }
            }
        }
        if _pi_own_init {
            _pi_auto = False;
            break;
        }
        _pi_fielded = False;
        for _pi_var in _pi_arch.get_has_vars() {
            if not _pi_var.accessors {
                _pi_fielded = True;
                break;
            }
        }
        if _pi_fielded {
            _pi_auto = True;
            break;
        }
    }
    _pi_full: (str | None) = None;
    if _pi_auto {
        for _pi_cls in self._mro_of(type_name) {
            for pname in [f"{_pi_cls}.__post_init__", f"{_pi_cls}.postinit"] {
                if pname in self._native_skipped_methods {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="constructor",
                        name=f"{type_name}() via {pname}",
                        help_text=(
                            "The post-initializer was demoted to its Python "
                            "implementation, so native construction has no "
                            "post-initializer to call and would leave the "
                            "object half-built. Construct this class from a "
                            "Python/@sv context, or make the post-initializer "
                            "lowerable."
                        )
                    );
                    return None;
                }
                if pname in self.method_funcs {
                    _pi_full = pname;
                    break;
                }
            }
            if _pi_full is not None {
                break;
            }
        }
    }
    if _pi_full is not None {
        postinit_fn = self._receiver_routed_method_fn(
            nd, _pi_full, ["__post_init__", "postinit"], type_name
        );
        if postinit_fn is None {
            return None;
        }
        self.builder.call(
            postinit_fn, [self._coerce_type(obj_ptr, postinit_fn.args[0].type)]
        );
    }
    return obj_ptr;
}

impl NaIRGenObjects._unregistered_class_target(target: uni.UniNode) -> (str | None) {
    """The class a `Cls.method(...)` names when the native lane has no `Cls`.

    The native import walk registers a struct type for an imported archetype
    only when it walked that archetype's module; a module it classified
    Python-side (a Python base, a `::py::` body) leaves nothing behind, so the
    class name resolves to no native type at all. That is the same crossing a
    cross-module free-function call makes, and the free-function form refuses
    out loud -- this lookup is what lets the class-qualified form say the same
    thing instead of dropping the call on the floor.

    Only a name that resolves to an archetype declared in *another* Jac module
    answers, so an instance receiver, an enum, and an in-module class that has
    simply not been registered yet all stay out of it.
    """;
    import os;
    name = self._get_name(target);
    if name is None or name in self.struct_types or name in self.local_vars {
        return None;
    }
    sym = target?.sym;
    decl = sym.decl if sym is not None else None;
    if decl is None {
        return None;
    }
    arch = decl.find_parent_of_type(uni.Archetype);
    if arch is None or arch.name is None or arch.name.value != name {
        return None;
    }
    decl_mod = decl.find_parent_of_type(uni.Module);
    path = decl_mod.loc.mod_path if decl_mod?.loc else None;
    if not path or not path.endswith(".jac") {
        return None;
    }
    own_path = os.path.realpath(self.ir_in.loc.mod_path) if self.ir_in?.loc else "";
    if os.path.realpath(path) == own_path {
        return None;
    }
    return name;
}

impl NaIRGenObjects._codegen_method_call(nd: uni.FuncCall) -> (ir.Value | None) {
    result = self._codegen_method_call_inner(nd);
    if result is not None
        and nd.callee_decl is not None
        and nd.callee_decl.receiver_mode == OwnershipKind.OWN
        and isinstance(nd.target, uni.AtomTrailer)
        and not self.builder.block.is_terminated {
        self._nogc_consume_local(nd.target.target);
    }
    return result;
}

impl NaIRGenObjects._codegen_method_call_inner(nd: uni.FuncCall) -> (ir.Value | None) {
    trailer = nd.target;
    if not isinstance(trailer, uni.AtomTrailer) or not trailer.is_attr {
        return None;
    }
    target_name = self._get_name(trailer.target);
    method_name = self._get_name(trailer.right);
    if method_name is None {
        return None;
    }
    if target_name == "super" and self._self_arch is not None {
        _sup_names = [method_name];
        if method_name == "postinit" {
            _sup_names.append("__post_init__");
        } elif method_name == "init" {
            _sup_names.append("__init__");
        }
        _sup_full: (str | None) = None;
        for _cn in self._mro_of(self._self_arch)[1:] {
            for _mn in _sup_names {
                _cand = f"{_cn}.{_mn}";
                if _cand in self.method_funcs
                    and _cand not in self._native_skipped_methods {
                    _sup_full = _cand;
                    break;
                }
            }
            if _sup_full is not None {
                break;
            }
        }
        _self_slot = self.local_vars.get("self");
        if _sup_full is not None and _self_slot is not None {
            _self_val = self.builder.load(_self_slot, name="super.self");
            return self._emit_class_routed_call(
                nd, _sup_full, _sup_names, _self_val, self._self_arch
            );
        }
        if self._pyb_base_of(self._self_arch) is not None {
            _pyb_sup = self._codegen_pyb_super_call(nd, method_name);
            if _pyb_sup is not None {
                return _pyb_sup;
            }
            return None;
        }
        self.emit(
            E5092,
            node_override=nd,
            kind="call",
            name=f"super.{method_name}",
            help_text=(
                "No MRO ancestor of this class provides a native lowering "
                "of this method, so the super call cannot lower."
            )
        );
        return None;
    }
    if method_name == "partition" {
        import from jaclang.compiler.expr_keys { is_builtin_region_type }
        if is_builtin_region_type(trailer.target.type) {
            _pt_recv = self._codegen_expr(trailer.target);
            if _pt_recv is None {
                return None;
            }
            return self._region_partition(_pt_recv);
        }
    }
    if (
        method_name in ("get", "keys", "values", "items", "setdefault", "update", "pop")
        and self._type_key_of(trailer.target) in ("any", "Any")
    ) {
        self.emit(
            E5092,
            node_override=nd,
            kind="method",
            name=f"{method_name} (on an `any` receiver)",
            help_text=(
                "Method calls on an `any`-typed dict are not lowered natively "
                "yet; annotate the receiver with a concrete dict[...] type or "
                "move this code to a @sv/Python context."
            )
        );
        return None;
    }

    if (
        target_name is not None
        and target_name in self.struct_types
        and target_name not in self.local_vars
    ) {
        _sfull: (str | None) = None;
        _mnames = [method_name];
        if method_name == "postinit" {
            _mnames.append("__post_init__");
        } elif method_name == "init" {
            _mnames.append("__init__");
        }
        for _cn in self._mro_of(target_name) {
            _cand = f"{_cn}.{method_name}";
            if _cand in self.static_methods {
                _sfull = _cand;
                break;
            }
        }
        if _sfull is not None
            and (
                _sfull in self._native_skipped_methods
                or _sfull not in self.method_funcs
            ) {
            self.emit(
                E5092,
                node_override=nd,
                kind="method",
                name=_sfull,
                help_text=(
                    f"'{method_name}' has no native lowering and was demoted "
                    f"to its Python implementation; it cannot be called from "
                    f"native code. Call it from a Python/@sv context instead."
                )
            );
            return None;
        }
        if _sfull is None {
            for _cn in self._mro_of(target_name) {
                for _mn in _mnames {
                    _icand = f"{_cn}.{_mn}";
                    if _icand in self.method_funcs
                        and _icand not in self._native_skipped_methods {
                        _sfull = _icand;
                        break;
                    }
                }
                if _sfull is not None {
                    break;
                }
            }
        }
        if _sfull is not None {
            return self._emit_class_routed_call(nd, _sfull, _mnames, None, None);
        }
    }

    _xmod_cls = self._unregistered_class_target(trailer.target);
    if _xmod_cls is not None {
        self.emit(
            E5092,
            node_override=nd,
            kind="method",
            name=f"{_xmod_cls}.{method_name}",
            help_text=(
                f"'{_xmod_cls}' is declared in a module the native lane did "
                f"not lower, so it has no native '{method_name}' to call. A "
                f"free function from that module refuses here for the same "
                f"reason. Call it from a Python/@sv context, or move the "
                f"shared code into a module the native lane can lower."
            )
        );
        return None;
    }

    _fld_struct = self._struct_name_of(trailer.target);
    if (
        _fld_struct is not None
        and _fld_struct in self.struct_field_types
        and method_name in self.struct_field_types[_fld_struct]
    ) {
        _fld_ty = self.struct_field_types[_fld_struct][method_name];
        if (
            isinstance(_fld_ty, ir.PointerType)
            and isinstance(_fld_ty.pointee, ir.FunctionType)
        ) {
            _obj_v = self._codegen_expr(trailer.target);
            if _obj_v is not None {
                _idx = self.struct_field_indices[_fld_struct][method_name];
                _fld_ptr = self.builder.gep(
                    _obj_v,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), _idx)],
                    name=f"{method_name}.fldptr"
                );
                _fnp = self.builder.load(_fld_ptr, name=f"{method_name}.fn");
                _fn_ty = _fld_ty.pointee;
                _is_clib = _fld_struct in self.clib_struct_names;
                _cargs: list[ir.Value] = [];
                for (_i, _p) in enumerate(nd.params or []) {
                    _pv = self._codegen_expr(_p);
                    if _pv is not None {
                        if _i < len(_fn_ty.args) {
                            _pv = (
                                self._clib_fnptr_arg(_pv, _fn_ty.args[_i])
                                    if _is_clib
                                    else self._coerce_type(_pv, _fn_ty.args[_i])
                            );
                        }
                        _cargs.append(_pv);
                    }
                }
                _r = self.builder.call(_fnp, _cargs, name=f"icall.{method_name}");
                if isinstance(_fn_ty.return_type, ir.VoidType) {
                    return None;
                }
                if _is_clib {
                    return self._clib_fnptr_ret(_fld_struct, method_name, _r);
                }
                return _r;
            }
        }
    }

    if (
        target_name == "sys"
        and self?._native_stdlib_modules
        and "sys" in self._native_stdlib_modules
    ) {
        if method_name == "exit" {
            arg_vals = self._codegen_call_args(nd);
            return self._emit_sys_exit(arg_vals);
        }
    }

    if (
        target_name == "math"
        and self?._native_stdlib_modules
        and "math" in self._native_stdlib_modules
    ) {
        _mres = self._emit_math_call(method_name, nd);
        if _mres is not None {
            return _mres;
        }
    }

    if (
        target_name == "time"
        and self?._native_stdlib_modules
        and "time" in self._native_stdlib_modules
        and method_name in NATIVE_TIME_FUNCS
    ) {
        return self._emit_time_call(method_name, nd);
    }

    if (
        isinstance(trailer.target, uni.AtomTrailer)
        and trailer.target.is_attr
        and self._get_name(trailer.target.target) == "os"
        and self._get_name(trailer.target.right) == "path"
        and self?._native_stdlib_modules
        and "os" in self._native_stdlib_modules
    ) {
        if method_name not in NATIVE_OSPATH_FUNCS {
            self.emit(E5090, node_override=nd, kind="os.path member", name=method_name);
            return None;
        }
        return self._emit_ospath_call(method_name, nd);
    }

    if (
        isinstance(trailer.target, uni.AtomTrailer)
        and trailer.target.is_attr
        and self._get_name(trailer.target.target) == "os"
        and self._get_name(trailer.target.right) == "environ"
        and self?._native_stdlib_modules
        and "os" in self._native_stdlib_modules
    ) {
        _env_res = self._emit_os_environ_call(method_name, nd);
        if _env_res is not None {
            return _env_res;
        }
    }

    if (
        target_name == "os"
        and self?._native_stdlib_modules
        and "os" in self._native_stdlib_modules
        and method_name in NATIVE_OS_FUNCS
    ) {
        return self._emit_os_call(method_name, nd);
    }

    if (
        target_name == "random"
        and self?._native_stdlib_modules
        and "random" in self._native_stdlib_modules
        and method_name in NATIVE_RANDOM_FUNCS
    ) {
        return self._emit_random_call(method_name, nd);
    }

    if (
        target_name == "struct"
        and self?._native_stdlib_modules
        and "struct" in self._native_stdlib_modules
        and method_name in NATIVE_STRUCT_FUNCS
    ) {
        return self._emit_struct_call(method_name, nd);
    }

    if target_name == "int" and method_name == "from_bytes" {
        arg_vals = self._codegen_call_args(nd);
        if arg_vals {
            self._ensure_emitters();
            _emitter = self._native_emitters.get("int");
            if _emitter is not None {
                _ctx = self._native_emit_ctx_class(pass_ref=self, type_key="");
                result = _emitter.emit_from_bytes(_ctx, arg_vals);
                if result is not None {
                    return result;
                }
            }
        }
    }
    if target_name == "float" and method_name == "fromhex" {
        arg_vals = self._codegen_call_args(nd);
        if arg_vals {
            self._ensure_emitters();
            _emitter = self._native_emitters.get("float");
            if _emitter is not None {
                _ctx = self._native_emit_ctx_class(pass_ref=self, type_key="");
                result = _emitter.emit_fromhex(_ctx, arg_vals);
                if result is not None {
                    return result;
                }
            }
        }
    }

    list_spec = self._list_spec_of(trailer.target);
    if list_spec == "u8" and method_name in ("append", "extend") {
        _ba_recv = self._codegen_receiver(trailer.target);
        if _ba_recv is not None {
            _ba_res = self._dispatch_bytearray_method(method_name, _ba_recv, nd);
            if _ba_res is not None {
                return _ba_res;
            }
        }
    }
    if list_spec is not None {
        list_val = self._codegen_receiver(trailer.target);
        if list_val is not None {
            _shape_spec = self._infer_list_elem_type(list_val);
            elem_type_name = _shape_spec if _shape_spec is not None else list_spec;
            arg_vals = self._codegen_call_args(nd);
            _orig_args = list(arg_vals);

            _prep_idx = -1;
            if method_name == "append" and arg_vals {
                _prep_idx = 0;
            } elif method_name == "insert" and len(arg_vals) > 1 {
                _prep_idx = 1;
            }
            if _prep_idx >= 0 {
                _prep_params = list(nd.params or []);
                if _prep_idx < len(_prep_params) {
                    _prep_e = _prep_params[_prep_idx];
                    _prep_e = (
                        _prep_e.value if isinstance(_prep_e, uni.KWPair) else _prep_e
                    );
                    arg_vals[_prep_idx] = self._nogc_elem_prep(
                        _prep_e, arg_vals[_prep_idx]
                    );
                }
            }

            _elem_struct = self.var_list_elem_struct.get(target_name);
            if _elem_struct is not None
                and isinstance(_elem_struct, ir.PointerType)
                and isinstance(_elem_struct.pointee, ir.LiteralStructType) {
                _tidx = -1;
                if method_name == "append" and arg_vals {
                    _tidx = 0;
                } elif method_name == "insert" and len(arg_vals) > 1 {
                    _tidx = 1;
                }
                if _tidx >= 0 {
                    arg_vals[_tidx] = self._coerce_tuple_to_struct(
                        arg_vals[_tidx], _elem_struct.pointee
                    );
                }
            }
            if method_name == "append" {
                self._set_rc_ctx(
                    "append",
                    f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                        if nd.loc
                        else 0}"
                );
            }
            result = self._dispatch_primitive_method(
                "list",
                method_name,
                list_val,
                arg_vals,
                elem_type_name,
                kwargs=self._split_call_kwargs(nd),
                kw_node=nd
            );

            self._clear_rc_ctx();
            if result is not None {
                if method_name == "insert" and not self._nogc_headerless() {
                    self._release_owned_args(_orig_args, op="list_method_arg");
                }
                return result;
            }
        }
    }

    set_spec = self._set_spec_of(trailer.target);
    if set_spec is not None {
        elem_type_name = set_spec;
        set_val = self._codegen_receiver(trailer.target);
        if set_val is not None {
            arg_vals = self._codegen_call_args(nd);
            if method_name == "add" and arg_vals {
                _sprep_params = list(nd.params or []);
                if _sprep_params {
                    _sprep_e = _sprep_params[0];
                    _sprep_e = (
                        _sprep_e.value if isinstance(_sprep_e, uni.KWPair) else _sprep_e
                    );
                    arg_vals[0] = self._nogc_elem_prep(_sprep_e, arg_vals[0]);
                }
            }
            result = self._dispatch_primitive_method(
                "set", method_name, set_val, arg_vals, elem_type_name
            );
            if result is not None {
                return result;
            }
        }
    }

    tuple_type_key = self._tuple_key_of(trailer.target);
    if tuple_type_key is not None {
        tuple_val = self._codegen_receiver(trailer.target);
        if tuple_val is not None {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "tuple", method_name, tuple_val, arg_vals, tuple_type_key
            );
            if result is not None {
                return result;
            }
        }
    }

    dict_type_key: (str | None) = self._dict_key_of(trailer.target);
    if dict_type_key is None and target_name is not None {
        probe_val = self._codegen_receiver(trailer.target);
        if probe_val is not None {
            dict_type_info = self._infer_dict_type(probe_val);
            if dict_type_info is not None {
                dict_type_key = f"{dict_type_info[0]}:{dict_type_info[1]}";
            }
        }
    }
    if dict_type_key is not None {
        dict_val = self._codegen_receiver(trailer.target);
        dict_type_key = self._dict_key_reconcile(dict_type_key, dict_val);
        if dict_val is not None and dict_type_key is not None {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "dict", method_name, dict_val, arg_vals, dict_type_key
            );
            if result is not None {
                return result;
            }
        }
    }

    if method_name in self._primitive_method_names("int") {
        int_val = self._codegen_receiver(trailer.target);
        if int_val is not None and isinstance(int_val.type, ir.IntType) {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "int", method_name, int_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }

    if method_name in self._primitive_method_names("float") {
        float_val = self._codegen_receiver(trailer.target);
        if float_val is not None and isinstance(float_val.type, ir.DoubleType) {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "float", method_name, float_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }

    if method_name in self._primitive_method_names("complex") {
        cval = self._codegen_receiver(trailer.target);
        if cval is not None and cval.type == self.complex_struct_type.as_pointer() {
            result = self._dispatch_primitive_method(
                "complex", method_name, cval, [], ""
            );
            if result is not None {
                return result;
            }
        }
    }

    if method_name in ("count", "index") {
        if self._type_key_of(trailer.target) == "range" {
            rng_val = self._codegen_receiver(trailer.target);
            if rng_val is not None {
                arg_vals = self._codegen_call_args(nd);
                result = self._dispatch_primitive_method(
                    "range", method_name, rng_val, arg_vals, ""
                );
                if result is not None {
                    return result;
                }
            }
        }
    }

    if method_name in self._primitive_method_names("bytes") {
        bytes_val = self._codegen_receiver(trailer.target);
        if bytes_val is not None and self._is_bytes_value(bytes_val) {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "bytes", method_name, bytes_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }

    if method_name in self._primitive_method_names("str") {
        str_val = self._str_norm(self._codegen_receiver(trailer.target));
        if str_val is not None
            and self._opt_payload_of(str_val.type) == ir.IntType(8).as_pointer() {
            str_val = self._coerce_type(str_val, ir.IntType(8).as_pointer());
        }
        if str_val is not None and str_val.type == ir.IntType(8).as_pointer() {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "str", method_name, str_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }

    type_name: (str | None) = self._struct_name_of(trailer.target);
    obj_val: (ir.Value | None) = None;
    if type_name is None {
        obj_val = self._codegen_receiver(trailer.target);
        if obj_val is not None {
            type_name = self._infer_type_name(obj_val);

            if type_name is None {
                elem_type_name = self._infer_list_elem_type(obj_val);
                if elem_type_name is not None {
                    arg_vals = self._codegen_call_args(nd);
                    if method_name == "append" {
                        self._set_rc_ctx(
                            "append",
                            f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                                if nd.loc
                                else 0}"
                        );
                    }
                    result = self._dispatch_primitive_method(
                        "list", method_name, obj_val, arg_vals, elem_type_name
                    );
                    self._clear_rc_ctx();
                    if result is not None {
                        return result;
                    }
                }
            }
        }
    }
    if type_name is None {
        return None;
    }

    func = self._resolve_method(type_name, method_name);
    _is_mono_method = False;
    if func is None {
        _gm_owner: (str | None) = None;
        for _gm_cur in self._mro_of(type_name) {
            if f"{_gm_cur}.{method_name}" in self._generic_methods {
                _gm_owner = _gm_cur;
                break;
            }
        }
        if _gm_owner is not None {
            _gm_errs = len(self.errors_had);
            func = self._instantiate_generic_method(nd, _gm_owner, method_name);
            if func is None {
                if len(self.errors_had) == _gm_errs {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="method",
                        name=f"{_gm_owner}.{method_name}"
                    );
                }
                return None;
            }
            _is_mono_method = True;
        }
    }
    _demoted = False;
    if func is None {
        if f"{type_name}.{method_name}" in self._native_skipped_methods {
            _demoted = True;
        } else {
            _owner = self._resolve_method_owner(type_name, method_name);
            if _owner is not None
                and f"{_owner}.{method_name}" in self._native_skipped_methods {
                _demoted = True;
            }
        }
    }
    if func is None {
        if _demoted {
            self.emit(
                E5092,
                node_override=nd,
                kind="method",
                name=f"{type_name}.{method_name}",
                help_text=(
                    f"'{method_name}' has no native lowering and was demoted to "
                    f"its Python implementation; it cannot be called from native "
                    f"code. Call it from a Python/@sv context instead."
                )
            );
            return None;
        }
        if self._pyb_base_of(type_name) is not None {
            return self._codegen_pyb_method_call(nd, type_name, method_name);
        }
        return None;
    }

    if obj_val is None {
        obj_val = self._codegen_receiver(trailer.target);
    }
    if obj_val is None {
        return None;
    }
    obj_val = self._opt_unwrap_attr(obj_val);

    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.method.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
    }

    args: list[ir.Value] = [obj_val]
        + self._codegen_bound_args(nd, func, self_offset=1);

    if self._arch_has_vtable(type_name) and not _is_mono_method {
        result = self._codegen_virtual_call(obj_val, method_name, args, type_name);
        if result is not None {
            if isinstance(func.return_value.type, ir.VoidType) {
                return ir.Constant(ir.IntType(64), 0);
            }

            return result;
        }
    }

    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(func.args) {
            coerced.append(self._coerce_type(arg, func.args[i].type));
        } else {
            coerced.append(arg);
        }
    }
    result = self.builder.call(func, coerced, name=f"call.{method_name}");

    self._release_owned_args(coerced, op="call_arg");

    if isinstance(func.return_value.type, ir.VoidType) {
        return ir.Constant(ir.IntType(64), 0);
    }

    return result;
}

impl NaIRGenObjects._emit_obj_str(val: ir.Value) -> (ir.Value | None) {
    type_name = self._infer_type_name(val);
    if type_name is None {
        return None;
    }

    func = self._resolve_method(type_name, "__str__");

    i8p = ir.IntType(8).as_pointer();
    is_null = self.builder.icmp_unsigned(
        "==", val, ir.Constant(val.type, None), name="objstr.isnull"
    );
    fn = self.builder.basic_block.function;
    null_bb = fn.append_basic_block(name="objstr.null");
    live_bb = fn.append_basic_block(name="objstr.live");
    cont_bb = fn.append_basic_block(name="objstr.cont");
    self.builder.cbranch(is_null, null_bb, live_bb);

    self.builder.position_at_end(null_bb);
    none_s = self._make_global_string("None", name_prefix=".objstr.none");
    null_end = self.builder.basic_block;
    self.builder.branch(cont_bb);

    self.builder.position_at_end(live_bb);
    if func is None {
        live_res = self._emit_default_obj_repr(val, type_name);
    } else {
        was_owned = self._is_owned(val);
        if was_owned {
            val.is_owned = False;
        }
        result = None;
        if self._arch_has_vtable(type_name) {
            result = self._codegen_virtual_call(val, "__str__", [val], type_name);
        }
        if result is None {
            coerced = [self._coerce_type(val, func.args[0].type)];
            result = self.builder.call(func, coerced, name="call.__str__");
        }
        if was_owned {
            val.is_owned = True;
        }
        live_res = result;
    }
    live_res = self._coerce_type(live_res, i8p);
    live_end = self.builder.basic_block;
    self.builder.branch(cont_bb);

    self.builder.position_at_end(cont_bb);
    phi = self.builder.phi(i8p, name="objstr.result");
    phi.add_incoming(none_s, null_end);
    phi.add_incoming(live_res, live_end);

    return self._mark_owned(phi);
}

impl NaIRGenObjects._emit_default_obj_repr(val: ir.Value, type_name: str) -> ir.Value {
    b = self.builder;
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);

    buf_len = len(type_name) + 48;
    buf = self._rc_call_with_ctx(
        self.rc_alloc_fn,
        [ir.Constant(i64, buf_len)],
        op="obj_repr",
        loc="",
        name="obj.repr.buf"
    );
    self._emit_set_type_tag(b, buf, "str");
    snprintf = self._get_or_declare_extern(
        "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
    );
    fmt = self._make_global_string(
        "<%s object at 0x%llx>", name_prefix=".obj.repr.fmt"
    );
    name_g = self._make_global_string(type_name, name_prefix=".obj.repr.name");
    addr = b.ptrtoint(val, i64, name="obj.repr.addr");
    b.call(
        snprintf,
        [buf, ir.Constant(i64, buf_len), fmt, name_g, addr],
        name="obj.repr.snprintf"
    );
    return self._mark_owned(buf);
}

impl NaIRGenObjects._opt_unwrap_attr(obj_val: ir.Value) -> ir.Value {
    _ua_opt = self._opt_payload_of(obj_val.type);
    if _ua_opt is None {
        return obj_val;
    }
    _ua_tag = self.builder.extract_value(obj_val, 0, name="attr.opt.tag");
    _ua_none = self.builder.icmp_signed(
        "==", _ua_tag, ir.Constant(ir.IntType(8), 0), name="attr.opt.none"
    );
    self._emit_runtime_raise(
        _ua_none, "AttributeError", "'NoneType' object has no attribute"
    );
    return self.builder.extract_value(obj_val, 1, name="attr.opt.val");
}

impl NaIRGenObjects._opt_unwrap_guarded(
    val: (ir.Value | None), what: str, msg: str
) -> (ir.Value | None) {
    """Payload of an optional container, guarded by the absence CPython raises on.

    `has parts: (list[Item] | None)` lowers to a `JacOpt` -- a presence tag
    beside the container pointer -- so a loop, comprehension or slice reading
    the slot receives the wrapper, not a list. Handing that wrapper to the
    container helpers is what used to raise `Type of #1 arg mismatch` out of
    the builder and cost the whole function an ICE. Unwrapping here restores
    the container the rest of the lowering expects; the `None` arm raises
    rather than reading a null, so the two pathways agree on the absent case
    as well as the present one.
    """;
    if val is None {
        return None;
    }
    if self._opt_payload_of(val.type) is None {
        return val;
    }
    _uw_tag = self.builder.extract_value(val, 0, name=f"{what}.opt.tag");
    _uw_none = self.builder.icmp_signed(
        "==", _uw_tag, ir.Constant(ir.IntType(8), 0), name=f"{what}.opt.none"
    );
    self._emit_runtime_raise(_uw_none, "TypeError", msg);
    return self.builder.extract_value(val, 1, name=f"{what}.opt.val");
}

impl NaIRGenObjects._opt_unwrap_iterable(
    coll_val: (ir.Value | None)
) -> (ir.Value | None) {
    return self._opt_unwrap_guarded(
        coll_val, "iter", "'NoneType' object is not iterable"
    );
}

impl NaIRGenObjects._opt_unwrap_subscript(val: (ir.Value | None)) -> (ir.Value | None) {
    return self._opt_unwrap_guarded(
        val, "sub", "'NoneType' object is not subscriptable"
    );
}

impl NaIRGenObjects._accessor_slot_of(
    type_name: str, field_name: str, kind: str
) -> (str | None) {
    _slot = f"{field_name}.{ACCESSOR_SLOT_SUFFIX[kind]}";
    _lay = self._arch_layout(type_name);
    if _lay is not None and _slot in _lay.method_index {
        return _slot;
    }

    return _slot if self._resolve_method(type_name, _slot) is not None else None;
}

impl NaIRGenObjects._codegen_accessor_call(
    obj_val: ir.Value, type_name: str, slot: str, args: list[ir.Value]
) -> (ir.Value | None) {
    func = self._resolve_method(type_name, slot);
    if func is None {
        return None;
    }
    _all_args: list[ir.Value] = [obj_val] + args;
    if self._arch_has_vtable(type_name) {
        result = self._codegen_virtual_call(obj_val, slot, _all_args, type_name);
        if result is not None {
            return self._own_accessor_result(result);
        }
    }
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(_all_args) {
        coerced.append(
            self._coerce_type(arg, func.args[i].type) if i < len(func.args) else arg
        );
    }
    return self._own_accessor_result(
        self.builder.call(func, coerced, name=f"acc.{slot}")
    );
}

impl NaIRGenObjects._own_accessor_result(result: ir.Value) -> ir.Value {
    if isinstance(result.type, ir.PointerType)
        or self._opt_ptr_payload_of(result.type) is not None {
        return self._mark_owned(result);
    }
    return result;
}

impl NaIRGenObjects._receiver_union_parts(
    nd: (uni.UniNode | None)
) -> (list[str] | None) {
    if not isinstance(nd, uni.AtomTrailer) or not isinstance(nd.target, uni.Expr) {
        return None;
    }
    _rk = self._mangled_of(self._flow_narrowed_type_of(nd.target));
    if _rk is None or "|" not in _rk {
        return None;
    }
    _rp = [
        p
        for p in self._split_union_key(_rk)
        if p in self.struct_types
    ];
    return _rp if len(_rp) >= 2 else None;
}

impl NaIRGenObjects._emit_dispatched_field_ptr(
    obj_val: ir.Value,
    type_name: str,
    field_name: str,
    ftype: (ir.Type | None),
    parts: (list[str] | None) = None
) -> (ir.Value | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry as _df_glr }
    reg = _df_glr(self.ir_in, self.prog);
    _base_lay = reg.get_layout(type_name);
    if _base_lay is None or not _base_lay.has_vtable {
        return None;
    }
    _base_idx = _base_lay.field_index.get(field_name);
    if _base_idx is None and ftype is not None {
        return None;
    }
    _variants: list[tuple] = [];
    _uniform = True;
    for _cls in reg.mro_order {
        _cls_mro = self._mro_of(_cls);
        if parts {
            _dom_ok = False;
            for _pp in parts {
                if _pp in _cls_mro {
                    _dom_ok = True;
                    break;
                }
            }
            if not _dom_ok {
                continue;
            }
        } elif type_name not in _cls_mro {
            continue;
        }
        _lay = reg.get_layout(_cls);
        if _lay is None or _cls not in self.struct_types {
            continue;
        }
        _ci = _lay.field_index.get(field_name);
        if _ci is None {
            continue;
        }
        _vt = self._vtable_global_for(_cls) if _lay.has_vtable else None;
        if _vt is None {
            continue;
        }
        _cls_elems = self.struct_types[_cls].elements;
        if _ci >= len(_cls_elems) {
            continue;
        }
        if ftype is None {
            if field_name in self.struct_field_inline.get(_cls, set()) {
                return None;
            }
            _vf = _cls_elems[_ci];
            if _variants and _vf != _variants[0][3] {
                return None;
            }
            _variants.append((_cls, _vt, _ci, _vf));
        } else {
            _variants.append((_cls, _vt, _ci, ftype));
        }
        if _base_idx is None or _ci != _base_idx {
            _uniform = False;
        }
    }
    if ftype is None {
        if not _variants {
            return None;
        }
        ftype = _variants[0][3];
    }
    if field_name == "affected_symbols" and self._na_debug_on() {
        import sys as _df_sys;
        _df_sys.stderr.write(
            f"DFDIAG {type_name}.{field_name}: base_idx={_base_idx} "
            f"variants={len(_variants)} uniform={_uniform}\n"
        );
    }
    if _uniform or not _variants {
        return None;
    }
    i32 = ir.IntType(32);
    _fp_t = ftype.as_pointer();
    b = self.builder;
    _df_vpp = b.gep(
        obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="df.vt.pp"
    );
    _df_vtp = b.load(_df_vpp, name="df.vt");
    _df_fnc = b.block.function;
    _df_done = _df_fnc.append_basic_block(name=f"df.{field_name}.done");
    _df_incoming: list[tuple] = [];
    for (_vc, _vt, _ci, _vft) in _variants {
        _df_hit = _df_fnc.append_basic_block(name=f"df.{field_name}.{_vc}");
        _df_nxt = _df_fnc.append_basic_block(name=f"df.{field_name}.n.{_vc}");
        _df_eq = b.icmp_unsigned(
            "==",
            _df_vtp,
            b.bitcast(_vt, _df_vtp.type, name="df.cand"),
            name=f"df.eq.{_vc}"
        );
        b.cbranch(_df_eq, _df_hit, _df_nxt);
        b.position_at_end(_df_hit);
        _df_typed = b.bitcast(
            obj_val, self.struct_types[_vc].as_pointer(), name=f"df.self.{_vc}"
        );
        _df_p = b.gep(
            _df_typed, [ir.Constant(i32, 0), ir.Constant(i32, _ci)], name=f"df.p.{_vc}"
        );
        _df_pc = b.bitcast(_df_p, _fp_t, name=f"df.pc.{_vc}");
        _df_incoming.append((_df_pc, b.block));
        b.branch(_df_done);
        b.position_at_end(_df_nxt);
    }

    if _base_idx is not None {
        _df_fb_recv = obj_val;
        if type_name in self.struct_types {
            _df_fb_recv = b.bitcast(
                obj_val, self.struct_types[type_name].as_pointer(), name="df.self.fb"
            );
        }
        _df_fb = b.gep(
            _df_fb_recv,
            [ir.Constant(i32, 0), ir.Constant(i32, _base_idx)],
            name="df.p.fb"
        );
        _df_fbc = b.bitcast(_df_fb, _fp_t, name="df.pc.fb");
        _df_incoming.append((_df_fbc, b.block));
    } else {
        self._emit_runtime_raise(
            ir.Constant(ir.IntType(1), 1),
            "AttributeError",
            f"object has no attribute '{field_name}'"
        );
        _df_incoming.append((ir.Constant(_fp_t, None), b.block));
    }
    b.branch(_df_done);
    b.position_at_end(_df_done);
    _df_phi = b.phi(_fp_t, name=f"df.{field_name}.ptr");
    for (_pv, _pb) in _df_incoming {
        _df_phi.add_incoming(_pv, _pb);
    }
    return _df_phi;
}

impl NaIRGenObjects._narrow_receiver_ptr(
    obj_val: ir.Value, type_name: str
) -> (ir.Value | None) {
    obj_val = self._opt_unwrap_attr(obj_val);

    if (
        self?.jacval_type
        and obj_val.type == self.jacval_type
        and type_name in self.struct_types
    ) {
        obj_val = self._unbox_from_jacval(
            obj_val, self.struct_types[type_name].as_pointer()
        );
    }
    if isinstance(obj_val.type, ir.IntType) and (type_name in self.struct_types) {
        obj_val = self.builder.inttoptr(
            obj_val, self.struct_types[type_name].as_pointer(), name="osp.handle.ptr"
        );
    }

    target_struct = self.struct_types.get(type_name);
    if target_struct is not None
        and isinstance(obj_val.type, ir.PointerType)
        and obj_val.type.pointee is not target_struct {
        obj_val = self.builder.bitcast(
            obj_val, target_struct.as_pointer(), name=f"narrow.{type_name}"
        );
    }

    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.field.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
        return obj_val;
    }
    return None;
}

impl NaIRGenObjects._class_const_global(
    arch_name: str, field_name: str
) -> (ir.GlobalVariable | None) {
    for _cn in self._mro_of(arch_name) {
        _gv = self.static_fields.get(f"{_cn}.{field_name}");
        if _gv is not None {
            return _gv;
        }
    }
    return None;
}

impl NaIRGenObjects._class_const_variants(arch_name: str, field_name: str) -> tuple {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    reg = get_layout_registry(self.ir_in, self.prog);
    out: list[tuple] = [];
    _whole = True;
    for _cls in reg.mro_order {
        if _cls == arch_name or arch_name not in self._mro_of(_cls) {
            continue;
        }
        _gv = self._class_const_global(_cls, field_name);
        if _gv is None {
            continue;
        }
        _vt = self._vtable_global_for(_cls);
        if _vt is None {
            _whole = False;
            continue;
        }
        out.append((_cls, _vt, _gv));
    }
    return (out, _whole, );
}

impl NaIRGenObjects._codegen_class_const_read(
    obj_val: ir.Value, type_name: str, field_name: str
) -> (ir.Value | None) {
    _own = self._class_const_global(type_name, field_name);
    (_variants, _whole) = self._class_const_variants(type_name, field_name);
    if not _whole or (_own is None and not _variants) {
        return None;
    }
    _ty = _own.type.pointee if _own is not None else _variants[0][2].type.pointee;
    _uniform = True;
    for (_vc, _vt, _gv) in _variants {
        if _gv.type.pointee != _ty {
            return None;
        }
        if _gv is not _own {
            _uniform = False;
        }
    }
    if _uniform and _own is not None {
        return self.builder.load(_own, name=f"cconst.{field_name}");
    }
    if not self._arch_has_vtable(type_name) {
        return None;
    }
    _recv = self._narrow_receiver_ptr(obj_val, type_name);
    if _recv is None {
        return None;
    }

    i32 = ir.IntType(32);
    b = self.builder;
    _cc_vpp = b.gep(_recv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="cc.vt.pp");
    _cc_vtp = b.load(_cc_vpp, name="cc.vt");
    _cc_fn = b.block.function;
    _cc_done = _cc_fn.append_basic_block(name=f"cc.{field_name}.done");
    _cc_incoming: list[tuple] = [];
    for (_vc, _vt, _gv) in _variants {
        _cc_hit = _cc_fn.append_basic_block(name=f"cc.{field_name}.{_vc}");
        _cc_nxt = _cc_fn.append_basic_block(name=f"cc.{field_name}.n.{_vc}");
        _cc_eq = b.icmp_unsigned(
            "==",
            _cc_vtp,
            b.bitcast(_vt, _cc_vtp.type, name="cc.cand"),
            name=f"cc.eq.{_vc}"
        );
        b.cbranch(_cc_eq, _cc_hit, _cc_nxt);
        b.position_at_end(_cc_hit);
        _cc_incoming.append((b.load(_gv, name=f"cc.{field_name}.{_vc}.v"), b.block));
        b.branch(_cc_done);
        b.position_at_end(_cc_nxt);
    }
    if _own is not None {
        _cc_incoming.append((b.load(_own, name=f"cc.{field_name}.fb"), b.block));
    } else {
        self._emit_runtime_raise(
            ir.Constant(ir.IntType(1), 1),
            "AttributeError",
            f"class has no attribute '{field_name}'"
        );
        _cc_incoming.append((self._default_arg_fallback(_ty), b.block));
    }
    b.branch(_cc_done);
    b.position_at_end(_cc_done);
    _cc_phi = b.phi(_ty, name=f"cc.{field_name}");
    for (_pv, _pb) in _cc_incoming {
        _cc_phi.add_incoming(_pv, _pb);
    }
    return _cc_phi;
}

impl NaIRGenObjects._codegen_field_access(
    obj_val: ir.Value, field_name: str, type_name: str, nd: (uni.UniNode | None) = None
) -> (ir.Value | None) {
    field_indices = self.struct_field_indices.get(type_name);
    _getter = self._accessor_slot_of(type_name, field_name, "property");
    if _getter is None and (field_indices is None or field_name not in field_indices) {
        _uf_recv = self._narrow_receiver_ptr(obj_val, type_name);
        if _uf_recv is not None {
            _uf_ptr = self._emit_dispatched_field_ptr(
                _uf_recv,
                type_name,
                field_name,
                None,
                parts=self._receiver_union_parts(nd)
            );
            if _uf_ptr is not None {
                return self.builder.load(_uf_ptr, name=f"field.{field_name}");
            }
        }
        return None;
    }
    if _getter is None and self._refuse_opaque_field(nd, type_name, field_name) {
        return None;
    }
    _recv = self._narrow_receiver_ptr(obj_val, type_name);
    if _recv is None {
        return None;
    }
    obj_val = _recv;
    if _getter is not None {
        return self._codegen_accessor_call(obj_val, type_name, _getter, []);
    }
    field_ptr = self._field_slot_ptr(obj_val, field_name, type_name);
    if field_name in self.struct_field_inline.get(type_name, set()) {
        return field_ptr;
    }
    return self.builder.load(field_ptr, name=f"field.{field_name}");
}

impl NaIRGenObjects._field_slot_ptr(
    obj_val: ir.Value, field_name: str, type_name: str
) -> ir.Value {
    idx = self.struct_field_indices[type_name][field_name];
    field_ptr: (ir.Value | None) = None;
    _struct_t = self.struct_types.get(type_name);
    if (
        _struct_t is not None
        and idx < len(_struct_t.elements)
        and field_name not in self.struct_field_inline.get(type_name, set())
    ) {
        field_ptr = self._emit_dispatched_field_ptr(
            obj_val, type_name, field_name, _struct_t.elements[idx]
        );
    }
    if field_ptr is None {
        field_ptr = self.builder.gep(
            obj_val,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{field_name}.ptr"
        );
    }
    return field_ptr;
}

impl NaIRGenObjects._codegen_place_ptr(expr: uni.Expr) -> (ir.Value | None) {
    if isinstance(expr, uni.Name) {
        return self.local_vars.get(expr.sym_name);
    }
    if not (isinstance(expr, uni.AtomTrailer) and expr.is_attr) {
        return None;
    }
    field_name = self._get_name(expr.right);
    if field_name is None {
        return None;
    }
    obj_val = self._codegen_expr(expr.target);
    if obj_val is None {
        return None;
    }
    obj_val = self._opt_unwrap_attr(obj_val);
    type_name = self._struct_name_of(expr.target);
    if type_name is None {
        type_name = self._infer_type_name(obj_val);
    }
    if type_name is None {
        return None;
    }
    field_indices = self.struct_field_indices.get(type_name);
    if field_indices is None or field_name not in field_indices {
        return None;
    }
    if field_name in self.struct_field_inline.get(type_name, set()) {
        return None;
    }
    if self._accessor_slot_of(type_name, field_name, "property") is not None {
        return None;
    }
    _recv = self._narrow_receiver_ptr(obj_val, type_name);
    if _recv is None {
        return None;
    }
    return self._field_slot_ptr(_recv, field_name, type_name);
}

impl NaIRGenObjects._hasvar_is_own(var: uni.UniNode) -> bool {
    _tt = var?.type_tag;
    if _tt is None {
        return False;
    }
    if _tt.ownership == OwnershipKind.OWN {
        return True;
    }
    _inner = _tt.tag;
    return isinstance(_inner, uni.UnaryExpr) and _inner.ownership == OwnershipKind.OWN;
}

impl NaIRGenObjects._store_inline_field(
    type_name: str,
    fname: str,
    field_ptr: ir.Value,
    value: (ir.Value | None),
    drop_old: bool
) -> None {
    i8p = ir.IntType(8).as_pointer();
    _ftype = self.struct_field_types.get(type_name, {}).get(fname);
    _pname = getattr(_ftype, "name", "") or "";
    if drop_old and _pname {
        _dropf = self._emit_struct_drop_fields_fn(_pname);
        if _dropf is not None {
            self.builder.call(
                _dropf, [self.builder.bitcast(field_ptr, i8p, name=f"inl.{fname}.old")]
            );
        }
    }
    if value is None {
        return;
    }
    if isinstance(value.type, ir.PointerType) {
        _src = self.builder.load(value, name=f"inl.{fname}.src");
        self.builder.store(_src, field_ptr);
        _free = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
        self.builder.call(
            _free, [self.builder.bitcast(value, i8p, name=f"inl.{fname}.shell")]
        );
    } else {
        self.builder.store(value, field_ptr);
    }
}

impl NaIRGenObjects._codegen_field_aug_assign(
    target: uni.AtomTrailer,
    rhs: ir.Value,
    aug_op: str,
    rhs_node: (uni.Expr | None) = None
) -> (ir.Value | None) {
    field_name = self._get_name(target.right);
    if field_name is None {
        return None;
    }
    type_name: (str | None) = self._struct_name_of(target.target);
    obj_val = self._codegen_expr(target.target);
    if obj_val is None {
        return None;
    }
    if type_name is None {
        type_name = self._infer_type_name(obj_val);
    }
    if type_name is None {
        return None;
    }

    current = self._read_field_or_refuse(target, obj_val, field_name, type_name);
    if current is None {
        return None;
    }

    scalar = self._apply_scalar_aug_op(
        current,
        rhs,
        aug_op,
        rhs_node,
        unsigned=self._is_unsigned_node(target),
        checked=self._is_sized_node(target) or self._is_sized_node(rhs_node)
    );
    if scalar is not None {
        return scalar;
    }

    coerced = self._coerce_type(rhs, current.type);

    if aug_op == "+=" and isinstance(current.type, ir.PointerType) {
        result = self._emit_binary_op(Tok.PLUS, current, coerced);
        return result if result is not None else current;
    }

    return coerced;
}

impl NaIRGenObjects._codegen_field_assign(
    target: uni.AtomTrailer,
    value: ir.Value,
    skip_narrow_coerce: bool = False,
    value_node: (uni.Expr | None) = None
) -> None {
    _fa_errs = len(self.errors_had);
    field_name = self._get_name(target.right);
    _sa_target = self._get_name(target.target);
    if _sa_target is None {
        _sa_tk = self._type_key_of(target.target);
        if _sa_tk is not None {
            _sa_tkn = _sa_tk.replace(" ", "");
            if _sa_tkn.startswith("type[") and _sa_tkn.endswith("]") {
                _sa_target = _sa_tkn[5:-1];
            }
        }
    }
    if _sa_target is not None
        and field_name is not None
        and _sa_target in self.struct_types
        and _sa_target not in self.local_vars {
        for _sa_cn in self._mro_of(_sa_target) {
            _sa_sf = f"{_sa_cn}.{field_name}";
            if _sa_sf in self.static_fields {
                _sa_val = self._coerce_type(value, self.static_field_types[_sa_sf]);
                self.builder.store(_sa_val, self.static_fields[_sa_sf]);
                return;
            }
        }
    }
    obj_val = self._codegen_expr(target.target);
    if obj_val is not None {
        obj_val = self._opt_unwrap_attr(obj_val);
    }
    type_name: (str | None) = self._struct_name_of(target.target);
    if (
        obj_val is not None
        and self?.jacval_type
        and obj_val.type == self.jacval_type
        and type_name is not None
        and type_name in self.struct_types
    ) {
        obj_val = self._unbox_from_jacval(
            obj_val, self.struct_types[type_name].as_pointer()
        );
    }
    if type_name is None and obj_val is not None {
        type_name = self._infer_type_name(obj_val);
    }
    field_indices = self.struct_field_indices.get(type_name)
        if type_name is not None
        else None;
    _setter = self._accessor_slot_of(type_name, field_name, "setter")
        if (type_name is not None and field_name is not None)
        else None;
    if (
        field_name is None
        or obj_val is None
        or type_name is None
        or (
            _setter is None
            and (field_indices is None or field_name not in field_indices)
        )
    ) {
        if (
            field_name is not None
            and obj_val is not None
            and type_name is not None
            and _setter is None
            and self._pyb_base_of(type_name) is not None
        ) {
            self._codegen_pyb_field_assign(target, value, obj_val);
            return;
        }
        if len(self.errors_had) == _fa_errs {
            self.emit(
                E5092,
                node_override=target,
                kind="field assignment",
                name=(field_name or "<field>")
            );
        }
        return;
    }

    if _setter is None and self._refuse_opaque_field(target, type_name, field_name) {
        return;
    }

    if _setter is not None {
        _fs_struct = self.struct_types.get(type_name);
        if _fs_struct is not None
            and isinstance(obj_val.type, ir.PointerType)
            and obj_val.type.pointee != _fs_struct {
            obj_val = self.builder.bitcast(
                obj_val, _fs_struct.as_pointer(), name="acc.recv.cast"
            );
        }
        if self._codegen_accessor_call(obj_val, type_name, _setter, [value]) is None {
            self.emit(
                E5092,
                node_override=target,
                kind="field assignment",
                name=field_name,
                help_text=f"'{type_name}.{field_name}' is a property whose "
                f"setter has no native lowering."
            );
        }
        return;
    }
    field_types = self.struct_field_types.get(type_name);
    idx = field_indices[field_name];
    ftype = field_types[field_name];

    _fa_struct = self.struct_types.get(type_name);
    if (
        _fa_struct is not None
        and isinstance(obj_val.type, ir.PointerType)
        and obj_val.type.pointee != _fa_struct
    ) {
        obj_val = self.builder.bitcast(
            obj_val, _fa_struct.as_pointer(), name="fa.recv.cast"
        );
    }

    _slot_struct = self.struct_types.get(type_name);
    _slot_elems = _slot_struct?.elements if _slot_struct is not None else None;
    if _slot_elems is not None
        and idx < len(_slot_elems)
        and _slot_elems[idx] != ftype {
        ftype = _slot_elems[idx];
    }

    if field_name in self.struct_field_inline.get(type_name, set()) {
        _inl_fp = self.builder.gep(
            obj_val,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{field_name}.ptr"
        );
        self._store_inline_field(type_name, field_name, _inl_fp, value, True);
        self._nogc_consume_local(value_node);
        return;
    }

    _vt_struct = type_name in self.clib_vtable_structs;
    _is_clib_cb = (
        _vt_struct
        and isinstance(ftype, ir.PointerType)
        and isinstance(ftype.pointee, ir.FunctionType)
    );
    if _is_clib_cb {
        value = self._clib_coerce_callback(value, ftype);
    } elif not (skip_narrow_coerce and value.type != ftype) {
        value = self._coerce_type(value, ftype);
    }
    field_ptr: (ir.Value | None) = None;
    if not _vt_struct {
        field_ptr = self._emit_dispatched_field_ptr(
            obj_val, type_name, field_name, ftype
        );
    }
    if field_ptr is None {
        field_ptr = self.builder.gep(
            obj_val,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{field_name}.ptr"
        );
    }

    _borrow_field = field_name in self.struct_field_borrow.get(type_name, set());
    if isinstance(ftype, ir.PointerType) and not _vt_struct and not _borrow_field {
        self._emit_take_ref(
            value,
            op="field_set",
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{target.loc.first_line
                if target.loc
                else 0}"
        );
        old_field_val = self.builder.load(field_ptr, name=f"field.{field_name}.old");
        self._emit_rc_release_simple(
            old_field_val,
            op="field_set",
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{target.loc.first_line
                if target.loc
                else 0}"
        );
    }
    _fs_opt = self._opt_payload_of(ftype);
    if _fs_opt is not None
        and isinstance(_fs_opt, ir.PointerType)
        and not _vt_struct
        and not _borrow_field {
        _fs_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{target.loc.first_line
            if target.loc
            else 0}";
        _fs_new_pv = self.builder.extract_value(
            value, 1, name=f"field.{field_name}.newpv"
        );
        self._emit_take_ref(_fs_new_pv, op="field_set", loc=_fs_loc);
        _fs_old = self.builder.load(field_ptr, name=f"field.{field_name}.old");
        _fs_old_pv = self.builder.extract_value(
            _fs_old, 1, name=f"field.{field_name}.oldpv"
        );
        self._emit_rc_release_simple(_fs_old_pv, op="field_set", loc=_fs_loc);
    }
    self.builder.store(value, field_ptr);
    self._nogc_consume_local(value_node);
}

impl NaIRGenObjects._receiver_routed_method_fn(
    nd: uni.UniNode, _sfull: str, _mnames: list[str], _recv_cls: (str | None)
) -> (ir.Function | None) {
    _sfunc = self.method_funcs[_sfull];

    _owner_cls = _sfull.partition(".")[0];
    if (
        _recv_cls is not None
        and _recv_cls != _owner_cls
        and _recv_cls in self.struct_types
        and _sfull not in self.static_methods
    ) {
        import from jaclang.compiler.passes.layout_pass {
            get_layout_registry as _sc_glr
        }
        _sc_reg = _sc_glr(self.ir_in, self.prog);
        if not _sc_reg.is_primary_ancestor(_recv_cls, _owner_cls) {
            _mn_part = _sfull.partition(".")[2];
            _spec_key = f"{_recv_cls}.{_mn_part}${_owner_cls}";
            if _spec_key not in self.method_funcs
                and _spec_key not in self._native_skipped_methods {
                _anc_arch = self.arch_ast_map.get(_owner_cls);
                _anc_meth: (uni.Ability | None) = None;
                if _anc_arch is not None and _anc_arch.body is not None {
                    for _ab in _anc_arch.body {
                        if isinstance(_ab, uni.Ability)
                            and _ab.name_ref is not None
                            and _ab.name_ref.sym_name in _mnames
                            and _ab.signature is not None {
                            _anc_meth = _ab;
                            break;
                        }
                    }
                }
                if _anc_meth is None {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="call",
                        name=_sfull,
                        help_text=(
                            "An unbound ancestor call runs the "
                            "ancestor's body on this receiver, whose "
                            "field layout differs; specializing it "
                            "needs the ancestor's source, which is "
                            "not visible to this unit."
                        )
                    );
                    return None;
                }
                _spec_arg_tys: list[ir.Type] = [
                    self.struct_types[_recv_cls].as_pointer()
                ];
                for _at in _sfunc.function_type.args[1:] {
                    _spec_arg_tys.append(_at);
                }
                _spec_fnty = ir.FunctionType(
                    _sfunc.function_type.return_type, _spec_arg_tys
                );
                _spec_fn = ir.Function(self.llvm_module, _spec_fnty, name=_spec_key);
                for (_sai, _sa) in enumerate(_sfunc.args) {
                    if _sai < len(_spec_fn.args) {
                        _spec_fn.args[_sai].name = _sa.name;
                    }
                }
                self.method_funcs[_spec_key] = _spec_fn;
                self._codegen_method(_recv_cls, _anc_meth, symbol_override=_spec_key);
            }
            _spec_ready = self.method_funcs.get(_spec_key);
            if _spec_ready is None {
                self.emit(E5092, node_override=nd, kind="call", name=_spec_key);
                return None;
            }
            _sfunc = _spec_ready;
        }
    }
    return _sfunc;
}

impl NaIRGenObjects._emit_class_routed_call(
    nd: uni.FuncCall,
    _sfull: str,
    _mnames: list[str],
    _given_recv: (ir.Value | None),
    _given_recv_cls: (str | None)
) -> (ir.Value | None) {
    method_name = _sfull.partition(".")[2];
    _recv_cls: (str | None) = _given_recv_cls;
    if _recv_cls is None {
        _recv_first = (nd.params or [None])[0];
        _recv_cls = (
            self._struct_name_of(_recv_first)
                if _recv_first is not None and not isinstance(_recv_first, uni.KWPair)
                else None
        );
    }
    _sfunc = self._receiver_routed_method_fn(nd, _sfull, _mnames, _recv_cls);
    if _sfunc is None {
        return None;
    }

    _spos: list[uni.UniNode] = [];
    _skw: dict[str, uni.UniNode] = {};
    for _p in (nd.params or []) {
        if isinstance(_p, uni.KWPair) {
            if _p.key is not None {
                _skw[_p.key.sym_name] = _p.value;
            }
        } else {
            _spos.append(_p);
        }
    }
    _sdefaults: dict[str, uni.UniNode] = {};
    _sarch_nd = self.arch_ast_map.get(_sfull.split(".")[0]);
    if _sarch_nd is not None and _sarch_nd.body is not None {
        for _sb in _sarch_nd.body {
            if isinstance(_sb, uni.Ability)
                and _sb.name_ref is not None
                and _sb.name_ref.sym_name in _mnames
                and isinstance(_sb.signature, uni.FuncSignature) {
                for _sprm in _sb.signature.get_parameters() {
                    if isinstance(_sprm, uni.ParamVar)
                        and _sprm.name is not None
                        and _sprm.value is not None {
                        _sdefaults[_sprm.name.value] = _sprm.value;
                    }
                }
                break;
            }
        }
    }
    _sargs: list[ir.Value] = [];
    _bad_arg = False;
    if _given_recv is not None {
        _sargs.append(_given_recv);
    }
    for _p in _spos {
        _pv = self._codegen_expr(_p);
        if _pv is None {
            return None;
        }
        _sargs.append(_pv);
    }
    _used_kw: set[str] = set();
    for _ai in range(len(_sargs), len(_sfunc.args)) {
        _an = _sfunc.args[_ai].name or "";
        if _an in _skw {
            _pv = self._codegen_expr(_skw[_an]);
            if _pv is None {
                return None;
            }
            _used_kw.add(_an);
            _sargs.append(_pv);
        } elif _an in _sdefaults {
            _pv = self._codegen_expr(_sdefaults[_an]);
            if _pv is None {
                _pv = self._default_arg_fallback(_sfunc.args[_ai].type);
            }
            _sargs.append(_pv);
        } else {
            if _an == "" and _skw {
                _bad_arg = True;
            }
            _sargs.append(self._default_arg_fallback(_sfunc.args[_ai].type));
        }
    }
    if _bad_arg or (len(_used_kw) < len(_skw)) {
        self.emit(
            E5092,
            node_override=nd,
            kind="call",
            name=_sfull,
            help_text=(
                "A keyword argument on this class-routed call could "
                "not be matched to the callee's parameters, so the "
                "call cannot lower faithfully."
            )
        );
        return None;
    }
    for (_i, _sv) in enumerate(_sargs) {
        if _i < len(_sfunc.args) {
            _sargs[_i] = self._coerce_type(_sv, _sfunc.args[_i].type);
        }
    }
    _sr = self.builder.call(_sfunc, _sargs, name=f"scall.{method_name}");
    if isinstance(_sfunc.return_value.type, ir.VoidType) {
        return None;
    }
    return _sr;
}


impl NaIRGenObjects._jc_abi_offsets(field_types: list) -> tuple {
    offsets: list[int] = [];
    off = 0;
    for ft in field_types {
        sz = 8;
        if isinstance(ft, ir.IntType) {
            sz = 1 if ft.width <= 8 else (ft.width // 8);
        } elif isinstance(ft, ir.DoubleType) {
            sz = 8;
        } elif isinstance(ft, ir.PointerType) {
            sz = 8;
        } elif ft?.elements and ft.elements is not None {
            (_sub, _ssz) = self._jc_abi_offsets(list(ft.elements));
            _align = 8;
            if off % _align != 0 {
                off += _align - (off % _align);
            }
            offsets.append(off);
            off += _ssz;
            continue;
        }
        if off % sz != 0 {
            off += sz - (off % sz);
        }
        offsets.append(off);
        off += sz;
    }
    if off % 8 != 0 {
        off += 8 - (off % 8);
    }
    return (offsets, off);
}

impl NaIRGenObjects._build_jc_layout -> str {
    import json;
    out: dict = {"classes": {}};
    _model = self.ir_in.gen.osp_model;
    _tags = _model.tags if _model is not None else {};
    for arch_name in self.struct_field_indices {
        st = self.struct_types.get(arch_name);
        if st is None or st?.elements is None {
            continue;
        }
        (offsets, total) = self._jc_abi_offsets(list(st.elements));
        idx_map = self.struct_field_indices.get(arch_name, {});
        ftypes = self.struct_field_types.get(arch_name, {});
        enum_map = self.struct_field_enum_type.get(arch_name, {});
        fields: dict = {};
        for (fname, fidx) in idx_map.items() {
            if fidx >= len(offsets) {
                continue;
            }
            ft = ftypes.get(fname);
            code = "opaque";
            aux = "";
            if fname in enum_map {
                code = "enum";
                aux = enum_map[fname];
            } elif fname in self.struct_field_erased_tv.get(arch_name, {}) {
                code = "obj";
            } elif (
                isinstance(ft, ir.PointerType)
                and isinstance(ft.pointee, ir.IntType)
                and ft.pointee.width == 8
            ) {
                code = "str";
            } elif getattr(ft, "name", "") == "JacVal" {
                code = "union";
            } elif (
                ft?.elements
                and ft.elements is not None
                and len(ft.elements) == 2
                and isinstance(ft.elements[0], ir.IntType)
                and isinstance(ft.elements[1], ir.PointerType)
            ) {
                code = "optref";
                _opn = getattr(ft.elements[1].pointee, "name", "") or "";
                aux = _opn;
            } elif isinstance(ft, ir.IntType) {
                code = "bool" if ft.width == 1 else "int";
            } elif isinstance(ft, ir.DoubleType) {
                code = "float";
            } elif isinstance(ft, ir.PointerType) {
                _pn = getattr(ft.pointee, "name", "") or "";
                _is_list = False;
                for (_, _lt) in self.list_types.items() {
                    if ft == _lt.as_pointer() {
                        _is_list = True;
                        break;
                    }
                }
                if _is_list {
                    code = "natlist";
                    aux = _pn;
                } elif _pn in self.struct_field_indices {
                    code = "obj";
                    aux = _pn;
                } elif _pn == "jac.str" or _pn.endswith(".str") or _pn == "str" {
                    code = "str";
                } else {
                    code = "ptr";
                    aux = _pn;
                }
            }
            fields[fname] = {
                "index": fidx,
                "offset": offsets[fidx],
                "code": code,
                "aux": aux
            };
        }
        _lay_tag_idx = self.osp_type_tag_field.get(arch_name);
        out["classes"][arch_name] = {
            "size": total,
            "tag": _tags.get(arch_name, 0),
            "tag_offset": offsets[_lay_tag_idx]
                if (_lay_tag_idx is not None and _lay_tag_idx < len(offsets))
                else -1,
            "fields": fields
        };
    }
    return json.dumps(out);
}
