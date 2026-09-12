import type from jaclang.compiler.session.services { AnalysisServices }
import os;
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.analysis.boundaries.classify { native_only_import_target }

import from jaclang.compiler.pipeline.program_pass { ProgramTransform }

walker NativeImportFactsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        stamp_native_import_facts(ir_in, self.prog);
        return ir_in;
    }
}

def stamp_native_import_facts(mod: uni.Module, target_program: AnalysisServices) {
    """Stamp each import with the emitter's native-only verdict.

    NativeImportFactsPass calls this helper with the compilation context.
    It resolves native placement before the emitter consumes the verdict.
    """;
    import os;
    import from jaclang.compiler.analysis.binding.module_facts { ModuleFacts }
    needs_native = mod.decided_codespace == 'native'
        or ModuleFacts.has_native_context_stmts(mod);
    for imp in mod.get_all_sub_nodes(uni.Import) {
        target = native_only_import_target(imp, target_program);
        imp.native_only_drop = needs_native
            and target is not None
            and (os.sep + 'jaclang' + os.sep) not in os.path.abspath(target);
    }
}
