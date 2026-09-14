import os;
import from pathlib { Path }
import from jaclang.project.config { config_scope }
import from jaclang.compiler.driver.compilation_context {
    CompilationContext,
    InputManifest,
    analysis_options,
    context_identity
}
import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.progstate { DepGraph }
import from jaclang.compiler.frontend.unitree { Module }
import from .symbol_index { SymbolIndex }

obj WorkspaceIndexer {
    has program: JacProgram,
        index: SymbolIndex;

    def collect(module: Module, inputs: InputManifest) {
        owner = self.program.module_owner(module);
        if owner is None
            or not owner.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF) {
            return;
        }
        shard = self.index.collect(module, owner.context_key, inputs, owner.deps);
        self.index.install(shard);
        self.index.persist(shard, owner.options);
    }

    def load(path: str) -> bool {
        path = os.path.realpath(path);
        with self.program.source_store.capture() as inputs, config_scope(
            Path(path).parent
        ) {
            for options in analysis_options(path, self.program) {
                identity = context_identity(options);
                key = (identity, path);
                shard = self.index.shards.get(key);
                if shard is None
                    or not shard.inputs.is_current(self.program.source_store) {
                    if not self.index.load(
                        path, identity, self.program.source_store, options
                    ) {
                        return False;
                    }
                    shard = self.index.shards[key];
                }
                context = self.program.contexts.setdefault(
                    identity, CompilationContext(DepGraph())
                );
                for (importer, targets) in shard.dependencies.items() {
                    context.deps.begin(importer);
                    for target in targets {
                        context.deps.record(importer, target);
                    }
                    context.deps.finish(importer, True);
                }
            }
            return inputs.is_current(self.program.source_store);
        }
    }
}
