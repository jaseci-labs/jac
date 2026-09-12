import type from jaclang.compiler.session.services { AnalysisServices }
import from jaclang.compiler.session.import_paths { resolve_import_path }
import from jaclang.compiler.analysis.boundaries.classify { is_service_bridge_import }
import os;
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.ir.schema { ability_of_symbol }
import from jaclang.compiler.ir.enums { CodeContext }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.analysis.boundaries.classify {
    ClientImportVerdict,
    _default_codespace_for,
    classify_client_import_item,
    import_declares_native_target,
    is_client_boundary_import,
    is_client_native_edge_import
}

import from jaclang.compiler.pipeline.program_pass { ProgramTransform }

walker BoundaryFactsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        stamp_boundary_facts(ir_in, self.prog);
        return ir_in;
    }
}

def stamp_boundary_facts(mod: uni.Module, target_program: AnalysisServices) {
    import from jaclang.compiler.session.native_resolution {
        is_bundled_native_module,
        resolve_native_module
    }
    import from jaclang.compiler.analysis.placement.pins { config_module_pin }

    base_dir = '.';
    if mod.loc {
        base_dir = os.path.dirname(mod.loc.mod_path);
    }
    _sb_opts = target_program.options;
    in_native_mod = mod.loc is not None
        and (
            mod.decided_codespace == 'native'
            or (
                _sb_opts is not None
                and _sb_opts.aot_mode
                and not target_program.is_bootstrap()
                and _default_codespace_for(target_program) == 'native'
            )
        );

    def resolve_native(module_name: str, inferred_ok: bool) -> (str | None) {
        (src_mod_str, _full_path) = resolve_native_module(
            module_name, base_dir, allow_inferred=inferred_ok
        );
        return src_mod_str;
    }

    def source_mod_for(resolved_path: (str | None)) -> (uni.Module | None) {
        if resolved_path is None or not os.path.isfile(resolved_path) {
            return None;
        }
        return target_program.load_dependency_module(
            resolved_path, importer_path=mod.loc.mod_path, need_tree=True
        );
    }

    def collect_abilities(nd: uni.UniNode, out: dict[(str, uni.Ability)]) {
        if isinstance(nd, uni.Ability) and nd.sym_name {
            out[nd.sym_name] = nd;
        }
        for k in nd.kid {
            collect_abilities(k, out);
        }
    }

    def collect_walkers(nd: uni.UniNode, out: dict[(str, uni.Archetype)]) {
        if isinstance(nd, uni.Archetype) and nd.sym_name {
            if nd.arch_kind == 'walker' {
                out[nd.sym_name] = nd;
            }
        }
        for k in nd.kid {
            collect_walkers(k, out);
        }
    }

    def imported_names(imp: uni.Import) -> set[str] {
        names: set[str] = set();
        for item in imp.items {
            if isinstance(item, uni.ModuleItem) {
                names.add(item.name.value);
            }
        }
        return names;
    }

    def stamp_sv_decls(imp: uni.Import, facts: uni.ImportBoundaryFacts) -> None {
        wanted = imported_names(imp);
        if not wanted {
            return;
        }
        src = source_mod_for(facts.from_loc_resolved);
        if src is None {
            return;
        }
        abilities: dict[(str, uni.Ability)] = {};
        walkers: dict[(str, uni.Archetype)] = {};
        try {
            collect_abilities(src, abilities);
        } except Exception {}
        try {
            collect_walkers(src, walkers);
        } except Exception {}
        for name in wanted {
            wk_decl = walkers.get(name);
            if wk_decl is not None {
                facts.sv_walkers[name] = wk_decl;
                continue;
            }
            ab_decl = abilities.get(name);
            if ab_decl is not None {
                facts.sv_abilities[name] = ab_decl;
            }
        }
    }

    def stamp_na_decls(imp: uni.Import, facts: uni.ImportBoundaryFacts) -> None {
        wanted = imported_names(imp);
        if not wanted {
            return;
        }
        src = source_mod_for(facts.from_loc_resolved);
        if src is None {
            return;
        }
        for decl in src.body {
            if not isinstance(decl, (uni.Ability, uni.Archetype, uni.Enum)) {
                continue;
            }
            name = decl.sym_name;
            if (
                not name
                or name not in wanted
                or name in facts.na_target_decls
                or name in facts.na_unmappable_targets
            ) {
                continue;
            }
            if isinstance(decl, uni.Ability)
                and isinstance(decl.signature, uni.FuncSignature) {
                facts.na_target_decls[name] = decl;
            } else {
                facts.na_unmappable_targets.append(name);
            }
        }
    }

    for nd in mod.get_all_sub_nodes(uni.Import) {
        facts = uni.ImportBoundaryFacts();
        nd.boundary_facts = facts;
        native_ctx = nd.codespace() == CodeContext.NATIVE;

        if (nd.from_loc and isinstance(nd.from_loc, uni.ModulePath)) {
            module_name = nd.from_loc.dot_path_str;
            if (not module_name and nd.from_loc.path) {
                module_name = '.'.join(p.value for p in nd.from_loc.path);
            }
            if module_name {
                cl_na_edge = is_client_native_edge_import(nd, target_program);
                facts.client_native_edge = cl_na_edge;
                na_intent = (
                    native_ctx
                    or in_native_mod
                    or import_declares_native_target(nd)
                    or cl_na_edge
                );
                facts.native_from_path = resolve_native(module_name, na_intent);
                try {
                    facts.from_loc_resolved = resolve_import_path(nd.from_loc);
                } except Exception {
                    facts.from_loc_resolved = None;
                }
                facts.is_service = is_service_bridge_import(nd);
                if (nd.items and not facts.is_service and nd.in_client_context()) {
                    resolved = facts.from_loc_resolved;
                    if (resolved is not None and resolved.endswith('.jac')) {
                        try {
                            facts.pinned_server = (
                                config_module_pin(resolved) == 'server'
                            );
                        } except Exception {
                            facts.pinned_server = False;
                        }
                    }
                }
                if (
                    (facts.is_service and not facts.native_from_path)
                    or (nd.items and not facts.is_service and facts.pinned_server)
                ) {
                    stamp_sv_decls(nd, facts);
                }
                if (cl_na_edge and nd.items) {
                    stamp_na_decls(nd, facts);
                }
                if (
                    nd.items
                    and not facts.is_service
                    and not facts.pinned_server
                    and not cl_na_edge
                    and is_client_boundary_import(nd)
                ) {
                    linked_mod = source_mod_for(facts.from_loc_resolved);
                    if linked_mod is not None {
                        for item in nd.items {
                            if not isinstance(item, uni.ModuleItem) {
                                continue;
                            }
                            verdict = classify_client_import_item(linked_mod, item);
                            if verdict != ClientImportVerdict.BRIDGED {
                                continue;
                            }
                            sym_name = item.name.value;
                            decl = ability_of_symbol(linked_mod.lookup(sym_name));
                            if decl is not None {
                                facts.bridged_decls[sym_name] = decl;
                            }
                        }
                    }
                }
            }
        }

        if ((not nd.from_loc) and nd.is_absorb and nd.items and (not nd.clib_decls)) {
            item = nd.items[0];
            if (isinstance(item, uni.ModulePath) and item.path) {
                module_name = '.'.join(p.value for p in item.path);
                if module_name {
                    na_intent = (
                        native_ctx or in_native_mod or import_declares_native_target(nd)
                    );
                    facts.native_absorb_path = resolve_native(module_name, na_intent);
                }
            }
            continue;
        }

        if ((not nd.from_loc) and nd.items and (not nd.clib_decls)) {
            for item in nd.items {
                if (isinstance(item, uni.ModulePath) and item.path) {
                    whole_name = '.'.join(p.value for p in item.path);
                    eligible = is_bundled_native_module(whole_name)
                        or (item.alias is None and len(item.path) == 1);
                    if (whole_name and eligible) {
                        na_intent = (
                            native_ctx
                            or in_native_mod
                            or import_declares_native_target(nd)
                        );
                        item_path = resolve_native(whole_name, na_intent);
                        if item_path {
                            facts.native_item_paths[whole_name] = item_path;
                        }
                    }
                }
            }
        }
    }
}
