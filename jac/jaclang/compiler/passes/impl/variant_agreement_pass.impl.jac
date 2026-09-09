impl variant_sibling(mod_path: str) -> (str | None) {
    if not mod_path or not mod_path.endswith('.jac') {
        return None;
    }
    for marker in ANNEX_MARKERS {
        if mod_path.endswith(marker) {
            return None;
        }
    }
    if mod_path.endswith(VARIANT_SUFFIX) {
        sibling = mod_path[:-len(VARIANT_SUFFIX)] + '.jac';
    } else {
        sibling = mod_path[:-4] + VARIANT_SUFFIX;
    }
    return sibling if os.path.isfile(sibling) else None;
}

impl annotation_text(nd: (UniNode | None)) -> str {
    if nd is None {
        return '';
    }
    import from jaclang.compiler.tools.unparse_pass { unparse_node }
    try {
        return ' '.join(unparse_node(nd).split());
    } except Exception {
        return '';
    }
}

impl public_surface(mod: Module) -> dict[str, tuple[str, str, UniNode]] {
    out: dict[str, tuple[str, str, UniNode]] = {};

    def visible(name: str, access: SymbolAccess) -> bool {
        return bool(name)
            and not name.startswith('_')
            and access != SymbolAccess.PRIVATE;
    }

    for stmt in mod.body {
        if isinstance(stmt, Ability) and isinstance(stmt.name_ref, Name) {
            name = stmt.name_ref.value;
            if not visible(name, stmt.access_type) {
                continue;
            }
            parts: list[str] = [];
            ret = '';
            sig = stmt.signature;
            if isinstance(sig, FuncSignature) {
                for p in sig.get_parameters() {
                    tag = p.type_tag.tag if p.type_tag is not None else None;
                    parts.append(f"{p.name.value}: {annotation_text(tag)}");
                }
                ret = annotation_text(sig.return_type);
            }
            out[name] = ('ability', f"({', '.join(parts)}) -> {ret}", stmt);
        } elif isinstance(stmt, Archetype) {
            name = stmt.name.value;
            if not visible(name, stmt.access_type) {
                continue;
            }
            fields: list[str] = [];
            for hv in stmt.get_all_sub_nodes(typ=HasVar) {
                if hv.find_parent_of_type(Archetype) is not stmt {
                    continue;
                }
                tag = hv.type_tag.tag if hv.type_tag is not None else None;
                fields.append(f"{hv.name.value}: {annotation_text(tag)}");
            }
            out[name] = (stmt.arch_type.value, '{' + ', '.join(fields) + '}', stmt);
        } elif isinstance(stmt, Enum) {
            name = stmt.name.value;
            if not visible(name, stmt.access_type) {
                continue;
            }
            out[name] = ('enum', '', stmt);
        } elif isinstance(stmt, GlobalVars) {
            for assign in stmt.assignments {
                tag = assign.type_tag.tag if assign.type_tag is not None else None;
                for tgt in assign.target {
                    if isinstance(tgt, Name) and visible(tgt.value, stmt.access_type) {
                        out[tgt.value] = ('glob', annotation_text(tag), tgt);
                    }
                }
            }
        }
    }
    return out;
}

impl VariantAgreementPass.postinit -> None {
    super.postinit();
}

impl VariantAgreementPass._run_impl(ir_in: Module) -> Module {
    if ir_in.is_raised_from_py or ir_in.stub_only {
        return ir_in;
    }
    mod_path = ir_in.loc.mod_path if ir_in.loc else '';
    sibling = variant_sibling(mod_path);
    if sibling is None {
        return ir_in;
    }
    other = self._parse_sibling(sibling);
    if other is None {
        return ir_in;
    }
    if mod_path.endswith(VARIANT_SUFFIX) {
        self._compare(other, ir_in);
    } else {
        self._compare(ir_in, other);
    }
    return ir_in;
}

impl VariantAgreementPass._parse_sibling(path: str) -> (Module | None) {
    found = self.prog.find_module(path);
    if found is not None and not found.parse_failed {
        return found;
    }
    import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
    import from jaclang.compiler.frontend.parser.frontend { parse }
    try {
        (mod, had_error) = parse(read_file_with_encoding(path), path, prog=None);
    } except Exception {
        return None;
    }
    return None if had_error else mod;
}

impl VariantAgreementPass._emit_once(nd: UniNode, **kwargs: any) -> None {
    msg = E5105.format_message(**kwargs);
    for pool in (self.prog.errors_had, self.errors_had) {
        for e in pool {
            if (
                e.code is E5105
                and e.msg == msg
                and e.loc.mod_path == nd.loc.mod_path
                and e.loc.first_line == nd.loc.first_line
                and e.loc.col_start == nd.loc.col_start
            ) {
                return;
            }
        }
    }
    self.emit(E5105, node_override=nd, **kwargs);
}

impl VariantAgreementPass._compare(base: Module, variant: Module) -> None {
    base_name = os.path.basename(base.loc.mod_path or '') if base.loc else '';
    var_name = os.path.basename(variant.loc.mod_path or '') if variant.loc else '';
    base_surface = public_surface(base);
    var_surface = public_surface(variant);
    for (name, entry_sym) in var_surface.items() {
        (kind, detail, node_ref) = entry_sym;
        if name not in base_surface {
            self._emit_once(
                node_ref,
                variant=var_name,
                base=base_name,
                name=name,
                detail=f"'{name}' is not a public symbol of the base module"
            );
            continue;
        }
        (base_kind, base_detail, _base_node) = base_surface[name];
        if base_kind != kind {
            self._emit_once(
                node_ref,
                variant=var_name,
                base=base_name,
                name=name,
                detail=f"declared as {kind} in the variant but {base_kind} in the base"
            );
        } elif base_detail != detail {
            self._emit_once(
                node_ref,
                variant=var_name,
                base=base_name,
                name=name,
                detail=f"the variant declares {detail} but the base declares {base_detail}"
            );
        }
    }
    for (name, entry_sym) in base_surface.items() {
        if name in var_surface {
            continue;
        }
        (kind, _detail, _node) = entry_sym;
        self._emit_once(
            variant,
            variant=var_name,
            base=base_name,
            name=name,
            detail=f"public {kind} '{name}' is missing from the variant"
        );
    }
}

impl VariantAgreementPass.transform(ir_in: Module) -> Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, Module);
    return out;
}

impl VariantAgreementPass.run_walk with Module entry {
    self.ir_out = self._run_impl(here);
}
