import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from jaclang.compiler.pipeline.keys { SERVING }
import os;
import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.analysis.boundaries.facts { ServingFacts, ServingBinding }
import from jaclang.compiler.ir.enums { Tokens as Tok }

walker ServingFactsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        facts = ServingFacts();
        manifest = artifact_for(ir_in).interop_manifest;
        if manifest {
            facts.func_access.update(manifest.func_access);
            facts.walker_access.update(manifest.walker_access);
            facts.effects.update(manifest.endpoint_effects);
            for binding in manifest.server_exports_to_client {
                decl = binding.ast_node;
                if decl is None or not decl.loc.mod_path {
                    continue;
                }
                access = decl?.access;
                facts.cross_bindings.append(
                    ServingBinding(
                        binding.name,
                        binding.kind,
                        os.path.realpath(decl.loc.mod_path),
                        not (access is not None and access.tag.name == Tok.KW_PUB)
                    )
                );
            }
        }
        self.prog.analysis.publish(ir_in.loc.mod_path, SERVING, facts);
        return ir_in;
    }
}
