import from contextlib { contextmanager }

import from threading { Event }
import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
import from jaclang.compiler.driver.bccache { discover_base_file }
import from jaclang.compiler.passes.transform { Alert }

import os;
import copy;
import hashlib;
import json;
import from pathlib { Path }
import from jaclang.project.config { config_scope }
import from jaclang.compiler.driver.compilation_context {
    CompilationContext,
    AnalysisCacheBudget,
    analysis_options,
    context_identity,
    program_scope
}
import from jaclang.compiler.driver.inputs {
    InputManifest,
    SourceStore,
    SourceSnapshot
}
import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.progstate { DepGraph }
import from jaclang.compiler.frontend.unitree { Module }
import type from jaclang.compiler.tools.symbol_index { IndexShard, SymbolIndex }

obj AnalysisRecord {
    has files: list[str],
        inputs: InputManifest,
        shards: tuple[IndexShard, ...],
        errors: list[Alert],
        warnings: list[Alert],
        product: CompilationProduct,
        contexts: tuple[str, ...];

    def changed_inputs(store: SourceStore) -> set[str] {
        manifests = [shard.inputs for shard in self.shards] or [self.inputs];
        with store.capture() {
            return {
                path for manifest in manifests for path in manifest.changed_paths(store)
            };
        }
    }

    def is_current(store: SourceStore) -> bool {
        manifests = [shard.inputs for shard in self.shards] or [self.inputs];
        with store.capture() {
            return all(manifest.is_current(store) for manifest in manifests);
        }
    }
}

obj AnalysisResult {
    has module: Module,
        record: AnalysisRecord;
}

obj AnalysisChange {
    has producers: set[str],
        affected: set[str];
}

obj AppDiagnostics {
    has app: str,
        errors: list[Alert],
        warnings: list[Alert];
}

def merge_app_alerts(
    collected: list[AppDiagnostics]
) -> tuple[list[Alert], list[Alert]] {
    def key_of(alert: Alert) -> tuple[str, int, int, str, str] {
        code = alert.code.code if alert.code else '';
        return (
            alert.loc.mod_path,
            alert.loc.first_line,
            alert.loc.col_start,
            code,
            alert.msg
        );
    }

    def merge(select_warnings: bool) -> list[Alert] {
        seen_apps: dict[tuple[str, int, int, str, str], set[str]] = {};
        first: dict[tuple[str, int, int, str, str], Alert] = {};
        order: list[tuple[str, int, int, str, str]] = [];
        tagged: list[tuple[str, Alert]] = [];
        for entry_item in collected {
            app_name = entry_item.app;
            for alert in (
                entry_item.warnings if select_warnings else entry_item.errors
            ) {
                key = key_of(alert);
                if key not in seen_apps {
                    seen_apps[key] = set();
                    first[key] = alert;
                    order.append(key);
                }
                seen_apps[key].add(app_name);
                tagged.append((app_name, alert));
            }
        }
        shared = {
            key
            for key in order
            if len(seen_apps[key]) >= len(collected)
        };
        out: list[Alert] = [];
        emitted: set[tuple[str, int, int, str, str]] = set();
        for (app_name, alert) in tagged {
            key = key_of(alert);
            if key in shared {
                if key not in emitted {
                    emitted.add(key);
                    out.append(first[key]);
                }
                continue;
            }
            alert = copy.copy(alert);
            alert.msg = f"[app:{app_name}] {alert.msg}";
            out.append(alert);
        }
        return out;
    }

    return (merge(False), merge(True));
}

obj AnalysisService {
    has program: JacProgram,
        index: SymbolIndex,
        records: dict[str, AnalysisRecord] = {},
        budget: AnalysisCacheBudget = AnalysisCacheBudget();

    @contextmanager
    def scope(directory: Path) -> Iterator[SourceSnapshot] {
        with program_scope(self.program), self.program.source_store.capture() as inputs, config_scope(
            directory, inherit_explicit=False
        ) {
            yield inputs;
        }
    }

    def synchronize(
        sources: dict[str, str], changed_paths: set[str] | None = None
    ) -> AnalysisChange {
        changed = self.program.source_store.set_overrides(sources);
        changed.update(os.path.realpath(path) for path in (changed_paths or set()));
        if not changed {
            return AnalysisChange(set(), set());
        }
        producers = {discover_base_file(path) or path for path in changed};
        affected = set(producers);
        for path in changed | producers {
            affected.update(self.program.transitive_dependents(path));
        }
        for path in affected {
            self.program.invalidate_module(path);
            self.program.drop_module_alerts(path);
        }
        return AnalysisChange(producers, affected);
    }

    def analyze(
        path: str,
        product: CompilationProduct = CompilationProduct.ANALYSIS,
        cancel_token: Event | None = None
    ) -> AnalysisResult | None {
        if product not in (CompilationProduct.SYMBOLS, CompilationProduct.ANALYSIS) {
            raise ValueError(f'Unsupported analysis request: {product.value}');
        }
        if cancel_token is not None and cancel_token.is_set() {
            return None;
        }
        path = os.path.realpath(discover_base_file(path) or path);
        previous = self.records.get(path);
        if previous is not None {
            changed = previous.changed_inputs(self.program.source_store);
            if changed {
                self.synchronize(self.program.source_store.overrides, changed);
            }
        }
        with self.scope(Path(path).parent) as inputs {
            inputs.watch_configuration(path);
            files = [path];
            files.extend(self.program.source_store.annex_paths(path));
            targets = analysis_options(path, self.program, product, cancel_token);
            contexts = tuple(context_identity(options) for options in targets);
            reusable = previous is not None
                and previous.contexts == contexts
                and (
                    previous.product == product
                    or previous.product == CompilationProduct.ANALYSIS
                )
                and previous.is_current(self.program.source_store);
            if reusable and previous is not None {
                context = self.program.contexts.get(contexts[-1]);
                if context is not None and context.program is not None {
                    cached = context.program.mod.hub.get(path);
                    if cached is not None
                        and context.program.is_hub_entry_fresh(path)
                        and (
                            product == CompilationProduct.SYMBOLS
                            or cached.parse_failed
                            or context.program.analysis.analyses_run.provides(
                                cached, AnalysisFact.TYPE_OF
                            )
                        ) {
                        self.program.contexts.pop(contexts[-1]);
                        self.program.contexts[contexts[-1]] = context;
                        return AnalysisResult(cached, previous);
                    }
                }
            }
            builds: list[Module] = [];
            collected: list[AppDiagnostics] = [];
            try {
                for options in targets {
                    for file in files {
                        self.program.drop_module_alerts(file);
                    }
                    build = self.program.compile(file_path=path, options=options);
                    builds.append(build);
                    if cancel_token is not None and cancel_token.is_set() {
                        for touched in inputs.modules {
                            self.program.invalidate_module(touched);
                        }
                        return None;
                    }
                    collected.append(
                        AppDiagnostics(
                            options.target_app,
                            [
                                alert
                                for alert in self.program.errors_had
                                if alert.loc.mod_path in files
                            ],
                            [
                                alert
                                for alert in self.program.warnings_had
                                if alert.loc.mod_path in files
                            ]
                        )
                    );
                }
                shards: list[IndexShard] = [];
                for build in builds {
                    shard = self.collect(build);
                    if shard is not None {
                        shards.append(shard);
                    }
                }
                if not inputs.is_current(self.program.source_store) {
                    for touched in inputs.modules {
                        self.program.invalidate_module(touched);
                    }
                    return None;
                }
                (errors, warnings) = (previous.errors, previous.warnings)
                    if reusable and previous is not None
                    else merge_app_alerts(collected);
                for file in files {
                    self.program.drop_module_alerts(file);
                }
                self.program.errors_had.extend(errors);
                self.program.warnings_had.extend(warnings);
                record = AnalysisRecord(
                    files,
                    inputs.manifest(),
                    tuple(shards),
                    errors,
                    warnings,
                    product,
                    contexts
                );
                self.records[path] = record;
                return AnalysisResult(builds[-1], record);
            } except Exception {
                for touched in inputs.modules {
                    self.program.invalidate_module(touched);
                }
                raise;
            }
        }
    }

    def trim -> set[str] {
        return self.program.trim_analysis_cache(self.budget);
    }

    def forget(path: str) {
        self.program.release_module(path);
        for dependency_graph in self.program.dependency_graphs() {
            dependency_graph.forget(path);
        }
        for (context, indexed_path) in list(self.index.shards) {
            if indexed_path == path {
                self.index.discard(path, context);
            }
        }
        self.records.pop(path, None);
    }

    def collect(module: Module) -> IndexShard | None {
        owner = self.program.module_owner(module);
        if owner is None
            or not owner.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF) {
            return None;
        }
        with owner.source_store.capture() as snapshot {
            inputs = owner.hub.inputs.get(os.path.realpath(module.loc.mod_path));
            if inputs is None or not inputs.is_current(owner.source_store) {
                return None;
            }
            shard = self.index.collect(module, owner.context_key, inputs, owner.deps);
            signature = owner.iface_registry().analysis_signature(module);
            shard.inputs = snapshot.manifest();
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
                        for target in dependency.ct_file_deps + dependency.ct_body_deps
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
    }

    def load(path: str) -> bool {
        path = os.path.realpath(path);
        with self.scope(Path(path).parent) as inputs {
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
                for dependency in shard.inputs.files {
                    context.deps.record(shard.path, dependency);
                }
            }
            return inputs.is_current(self.program.source_store);
        }
    }
}
