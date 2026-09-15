import os;
import hashlib;
import json;
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
import from .symbol_index { IndexShard, SymbolIndex }

obj WorkspaceIndexer {
    has program: JacProgram,
        index: SymbolIndex;

    def collect(module: Module, inputs: InputManifest) -> IndexShard | None {
        owner = self.program.module_owner(module);
        if owner is None
            or not owner.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF) {
            return None;
        }
        shard = self.index.collect(module, owner.context_key, inputs, owner.deps);
        signature = owner.iface_registry().analysis_signature(module);
        snapshot = owner.source_store.snapshot;
        if snapshot is not None {
            shard.inputs = snapshot.manifest();
        }
        if signature is not None {
            visible = {
                key: info.to_dict()
                for (key, info) in shard.definitions.items()
                if info.workspace_visible
            };
            shard.interface = hashlib.sha256(
                (signature + json.dumps(visible, sort_keys=True)).encode('utf-8')
            ).hexdigest();
        }
        for path in shard.inputs.files {
            dependency = owner.mod.hub.get(path);
            if dependency is not None {
                shard.body_dependencies.update(
                    os.path.realpath(target)
                    for target in [*dependency.ct_file_deps, *dependency.ct_body_deps]
                );
            }
        }
        previous = self.index.shards.get((shard.context, shard.path));
        if previous is not None {
            self.index.refresh_dependents(previous, shard);
        }
        self.index.install(shard);
        self.index.persist(shard, owner.options);
        return shard;
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
