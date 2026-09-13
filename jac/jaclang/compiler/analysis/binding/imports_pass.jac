import from jaclang.compiler.analysis.binding.import_classification {
    detect_jac_import
}
import from jaclang.compiler.session.import_paths { resolve_import_path }
import os;
import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.analysis.binding.facts { ImportEdge }

walker DependencyFactsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        if ir_in.stub_only
            and os.path.realpath(ir_in.loc.mod_path) in self.prog.deps.imports {
            return ir_in;
        }
        edges: list[ImportEdge] = [];
        for imp in ir_in.get_all_sub_nodes(uni.Import) {
            imp.jac_detected = detect_jac_import(imp);
            if imp.is_virtual_jac {
                continue;
            }
            paths = [imp.from_loc]
                if imp.from_loc is not None
                else [
                    item
                    for item in imp.items
                    if isinstance(item, uni.ModulePath)
                ];
            for path in paths {
                try {
                    target = resolve_import_path(path);
                } except Exception {
                    continue;
                }
                if not isinstance(target, str) or not target {
                    continue;
                }
                target = os.path.realpath(target);
                edges.append(
                    ImportEdge(
                        target,
                        imp.is_jac,
                        imp.is_comptime,
                        imp.code_context,
                        imp.parent is ir_in,
                        imp.from_loc is not None
                    )
                );
                self.prog.record_dependency(ir_in.loc.mod_path, target);
            }
        }
        self.prog.deps.imports[os.path.realpath(ir_in.loc.mod_path)] = edges;
        return ir_in;
    }
}
