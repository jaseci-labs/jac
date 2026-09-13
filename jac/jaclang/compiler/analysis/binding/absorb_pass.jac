import type from jaclang.compiler.session.services { AnalysisServices }
import from jaclang.compiler.session.import_paths { resolve_import_path }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.session.session { JacProgram }

import from jaclang.compiler.pipeline.program_pass { ProgramTransform }

walker AbsorbImportsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        resolve_absorb_imports(ir_in, self.prog);
        return ir_in;
    }
}

def resolve_absorb_imports(mod: uni.Module, target_program: AnalysisServices) {
    import from jaclang.compiler.ir.schema { find_python_scope_node_of }
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if imp.from_loc is not None {
            for item in imp.items {
                if (
                    isinstance(item, uni.ModulePath) and item.path and not item.alias
                ) {
                    imp.jac_detected = imp.is_jac;
                    break;
                }
            }
        }
        if not imp.is_absorb {
            continue;
        }
        if (find_python_scope_node_of(imp) is None) {
            continue;
        }
        path_node = imp.items[0];
        if not isinstance(path_node, uni.ModulePath) {
            continue;
        }
        resolved = resolve_import_path(path_node);
        module: (uni.Module | None) = None;
        if (resolved in target_program.mod.hub) {
            module = target_program.mod.hub[resolved];
        } elif resolved.endswith('.pyi') {
            try {
                module = target_program.load_dependency_module(
                    resolved, importer_path=mod.loc.mod_path
                );
            } except Exception {
                module = None;
            }
        } else {
            try {
                module = target_program.load_dependency_module(
                    resolved, importer_path=mod.loc.mod_path, need_tree=True
                );
            } except Exception {
                module = None;
            }
        }
        imp.absorbed_mod = module;
    }
}
