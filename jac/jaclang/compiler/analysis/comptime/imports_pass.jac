import os;
import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import jaclang.compiler.ir.schema as uni;

walker ComptimeImportsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        if self.prog.is_bootstrap() {
            return ir_in;
        }
        path = os.path.realpath(ir_in.loc.mod_path);
        saved = self.prog.options;
        try {
            for edge in self.prog.deps.imports.get(path, []) {
                if edge.is_comptime
                    and edge.target.endswith('.jac')
                    and edge.target != path
                    and os.path.isfile(edge.target) {
                    self.prog.load_dependency_module(
                        edge.target, importer_path=path, need_tree=True
                    );
                }
            }
        } finally {
            self.prog.options = saved;
        }
        return ir_in;
    }
}
