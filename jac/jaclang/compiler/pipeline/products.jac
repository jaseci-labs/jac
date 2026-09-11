import from jaclang.compiler.ir.identity { MutationPermit }
import type from jaclang.compiler.session.services { AnalysisServices }
import from weakref { WeakSet }
import from jaclang.compiler.pipeline.contracts { TaskAddress, ResultAddress }
import from jaclang.compiler.ir.identity { GraphId }
import from jaclang.compiler.backends.common.artifact_store { ArtifactStore }
import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import type from jaclang.compiler.pipeline.pass_base { Transform }
import from jaclang.compiler.pipeline.contracts { ProductKey, ProductRecord }
import from jaclang.compiler.analysis.placement.state { PlacementState }
import type from jaclang.compiler.analysis.placement.summary { PlacementSummary }
import from jaclang.compiler.analysis.boundaries.facts { ServingFacts }
import from jaclang.compiler.analysis.placement.products { PlacementSpaces }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.pipeline.pass_base { PassResult }
import type from jaclang.compiler.lowering.mtir { Info }
import from jaclang.compiler.pipeline.contracts {
    PassIdentity,
    AnalysisFact,
    CompilationProduct,
    ProductTask
}

import from weakref { ReferenceType }

obj ModuleProducts {
    has owner: ReferenceType[uni.Module],
        identity: GraphId,
        path: str,
        facts: set[AnalysisFact] = set(),
        completed: set[PassIdentity] = set(),
        tasks: dict[tuple[CompilationProduct, str], ProductTask] = {};
}

obj PendingPassResults {
    has module: uni.Module,
        results: dict[str, PassResult];
}

obj ProductStore {
    has mutations: MutationPermit postinit,
        artifacts: ArtifactStore postinit,
        _values: dict[ResultAddress, ProductRecord[object]] postinit,
        versions: dict[ResultAddress, int] postinit,
        result_owners: dict[ResultAddress, GraphId] postinit,
        pending_results:
            dict[TaskAddress, dict[ResultAddress, ProductRecord[object]]] postinit,
        placement_state: PlacementState postinit,
        mtir_map: dict[(str, Info)] postinit,
        pass_runs: dict[str, int] postinit,
        pass_time: dict[str, float] postinit,
        phase_time: dict[str, float] postinit,
        modules: dict[int, ModuleProducts] postinit,
        dependents: dict[TaskAddress, set[TaskAddress]] postinit,
        active: list[TaskAddress] postinit,
        early_passes: dict[int, PendingPassResults] postinit,
        cache_events: dict[str, int] postinit,
        failed_paths: set[str] postinit,
        invalid_graphs: WeakSet[Module] postinit,
        _dropping: bool = False,
        _pending_drops: set[int] = set();

    def init {
        self.mutations = MutationPermit();
        self.artifacts = ArtifactStore();
        self._values = {};
        self.versions = {};
        self.result_owners = {};
        self.pending_results = {};
        self.placement_state = PlacementState();
        self.mtir_map: dict[(str, Info)] = {};
        self.pass_runs: dict[str, int] = {};
        self.pass_time: dict[str, float] = {};
        self.phase_time: dict[str, float] = {};
        self.modules = {};
        self.dependents = {};
        self.active = [];
        self.early_passes: dict[int, PendingPassResults] = {};
        self.cache_events: dict[str, int] = {};
        self.failed_paths = set();
        self.invalid_graphs = WeakSet();
        self._dropping = False;
        self._pending_drops = set();
    }

    def publish[T](path: str, key: ProductKey[T], value: T, recipe: str = "") {
        if not isinstance(value, key.result_type) {
            raise TypeError(f"Invalid result type for {key.product.value}");
        }
        address = (os.path.realpath(path), key.product, recipe);
        version = self.versions.get(address, 0) + 1;
        record = ProductRecord(value=value, version=version);
        if self.active {
            self.pending_results.setdefault(self.active[-1], {})[address] = record;
        } else {
            self._values[address] = record;
            self.result_owners.pop(address, None);
            self.versions[address] = version;
        }
    }

    def lookup[T](path: str, key: ProductKey[T], recipe: str = "") -> T | None {
        address: ResultAddress = (os.path.realpath(path), key.product, recipe);
        staged = self.pending_results.get(self.active[-1], {}).get(address)
            if self.active
            else None;
        record = staged if staged is not None else self._values.get(address);
        if record is None or record.state != TaskState.SUCCEEDED {
            return None;
        }
        value = record.value;
        if not isinstance(value, key.result_type) {
            raise TypeError(f"Corrupt result type for {key.product.value}");
        }
        if self.active and staged is None {
            reader = self.active[-1];
            parent = self.modules[reader[0]].tasks[(reader[1], reader[2])];
            parent.dependencies[address] = record.version;
        }
        return value;
    }

    def finish(address: TaskAddress, task: ProductTask, path: str) {
        staged = self.pending_results.pop(address, {});
        if task.state != TaskState.SUCCEEDED {
            return;
        }
        for (key, record) in staged.items() {
            self._values[key] = record;
            self.versions[key] = record.version;
            self.result_owners[key] = address[0];
        }
        key: ResultAddress = (os.path.realpath(path), address[1], address[2]);
        current = self.versions.get(key, 0);
        task.version = current if current > task.initial_version else current + 1;
        self.versions[key] = task.version;
        if self.active {
            reader = self.active[-1];
            parent = self.modules[reader[0]].tasks[(reader[1], reader[2])];
            parent.dependencies[key] = task.version;
        }
    }

    def result[T](path: str, key: ProductKey[T], recipe: str = "") -> T {
        value = self.lookup(path, key, recipe);
        if value is None {
            raise ProductUnavailable(
                f"{key.product.value} has no committed result for {path}"
            );
        }
        return value;
    }

    def discard(path: str, product: CompilationProduct) {
        path = os.path.realpath(path);
        for address in list(self.versions) {
            if address[0] == path and address[1] == product {
                self._values.pop(address, None);
                self.result_owners.pop(address, None);
                self.versions[address] = self.versions.get(address, 0) + 1;
            }
        }
    }

    def module(module: uni.Module) -> ModuleProducts {
        if module in self.invalid_graphs {
            raise ProductUnavailable(
                "This contextual graph was invalidated; request a fresh compilation"
            );
        }
        import weakref;
        key = id(module);
        current = self.modules.get(key);
        if current is not None and current.owner() is module {
            return current;
        }
        self.drop_module(key);
        module.attach_permit(self.mutations);
        current = ModuleProducts(
            owner=weakref.ref(
                module,
                lambda (_ref: ReferenceType[uni.Module]) { self.drop_module(key); }
            ),
            identity=GraphId(key),
            path=product_path(module)
        );
        self.modules[key] = current;
        return current;
    }

    def has_module(module: uni.Module) -> bool {
        current = self.modules.get(id(module));
        return current is not None and current.owner() is module;
    }

    def provided(module: uni.Module) -> set[AnalysisFact] {
        return self.module(module).facts;
    }

    def provides(module: uni.Module, fact: AnalysisFact) -> bool {
        return self.has_module(module) and fact in self.modules[id(module)].facts;
    }

    def mark(module: uni.Module, facts: set[AnalysisFact]) {
        self.module(module).facts = set(facts);
    }

    def drop_module(key: int) {
        self._pending_drops.add(key);
        if self._dropping {
            return;
        }
        self._dropping = True;
        try {
            while self._pending_drops {
                self._drop_module(self._pending_drops.pop());
            }
        } finally {
            self._dropping = False;
        }
    }

    def _drop_module(key: int) {
        removed = self.modules.pop(key, None);
        for address in list(self.result_owners) {
            if self.result_owners[address] == key {
                self._values.pop(address, None);
                self.result_owners.pop(address, None);
                self.versions[address] = self.versions.get(address, 0) + 1;
            }
        }
        self.early_passes.pop(key, None);
        for address in list(self.dependents) {
            if address[0] == key {
                self.dependents.pop(address, None);
            } else {
                self.dependents[address] = {
                    reader
                    for reader in self.dependents[address]
                    if reader[0] != key
                };
            }
        }
    }

    def clear {
        for record in self.modules.values() {
            owner = record.owner();
            if owner is not None {
                self.invalid_graphs.add(owner);
            }
        }
        self.artifacts.clear();
        self.modules.clear();
        self.dependents.clear();
        self.active.clear();
        self.early_passes.clear();
        self._values.clear();
        self.versions.clear();
        self.result_owners.clear();
        self.pending_results.clear();
        self.placement_state.clear();
        self.failed_paths.clear();
    }

    def __len__ -> int {
        return len(self.modules);
    }

    def record_early(module: uni.Module, results: dict[str, PassResult]) {
        self.early_passes[id(module)] = PendingPassResults(module, results);
    }

    def take_early(module: uni.Module, name: str) -> (PassResult | None) {
        pending = self.early_passes.get(id(module));
        if pending is None {
            return None;
        }
        result = pending.results.pop(name, None);
        if not pending.results {
            self.early_passes.pop(id(module));
        }
        return result;
    }
}


import os;
import time;
import type from jaclang.compiler.session.session { JacProgram }
import type from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.pipeline.contracts {
    PassIdentity,
    CompilationProduct,
    ProductTask,
    ProductUnavailable,
    TaskState
}

def invalidate_product(
    program: AnalysisServices, module: Module, product: CompilationProduct
) {
    program = program.module_context(module);
    import from jaclang.compiler.pipeline.schedule {
        product_pipeline,
        pass_provides,
        PRODUCT_REQUIREMENTS
    }
    pending: list[TaskAddress] = [(GraphId(id(module)), product, "")];
    seen: set[TaskAddress] = set();
    while pending {
        address = pending.pop();
        if address in seen {
            continue;
        }
        seen.add(address);
        record = program.analysis.modules.get(address[0]);
        if record is None {
            continue;
        }
        task = record.tasks.get((address[1], address[2]));
        if task is not None and task.state == TaskState.RUNNING {
            continue;
        }
        record.tasks.pop((address[1], address[2]), None);
        for step in product_pipeline(address[1]) {
            record.completed.discard(step);
            record.facts.difference_update(pass_provides(step));
        }
        pending.extend(program.analysis.dependents.pop(address, set()));
        for (dependent, requirements) in PRODUCT_REQUIREMENTS.items() {
            if any(required == address[1] for (required, fact) in requirements) {
                pending.append((address[0], dependent, ""));
            }
        }
        owner = record.owner();
        if owner is not None {
            path = product_path(owner);
            program.analysis.discard(path, address[1]);
            if address[1] == CompilationProduct.CLIENT {
                _discard_client_artifact(program, owner);
            }
        }
    }
}

def invalidate_client_product(program: AnalysisServices, module: Module) {
    invalidate_product(program, module, CompilationProduct.CLIENT);
}

def _discard_client_artifact(program: AnalysisServices, module: Module) {
    artifact_for(module).js = '';
    artifact_for(module).es_ast = None;
    path = product_path(module);
    program.hub.client_artifacts.pop(path, None);
    import from jaclang.compiler.session.context { cache_scope }
    import from jaclang.compiler.session.cache.artifact_codec { get_module_cache_path }
    identity = '' if program.is_bootstrap() else program.context_key;
    with cache_scope(identity, program.options, program) {
        try {
            get_module_cache_path(path).unlink(missing_ok=True);
        } except OSError {}
    }
}


def require_product(
    program: AnalysisServices, module: Module, product: CompilationProduct
) -> bool {
    program = program.module_context(module);
    import from jaclang.compiler.pipeline.schedule {
        product_pipeline,
        PRODUCT_REQUIREMENTS
    }
    program.analysis.module(module);
    tasks = program.analysis.module(module).tasks;
    address: TaskAddress = (GraphId(id(module)), product, "");
    if program.analysis.active and program.analysis.active[-1] != address {
        program.analysis.dependents.setdefault(address, set()).add(
            program.analysis.active[-1]
        );
    }
    task = tasks.get((product, ""));
    if task is not None and task.state == TaskState.SUCCEEDED {
        if any(
            program.analysis.versions.get(dependency, 0) != version
            for (dependency, version) in task.dependencies.items()
        ) {
            invalidate_product(program, module, product);
            task = None;
        }
    }
    if task is not None {
        if task.state == TaskState.RUNNING {
            raise RuntimeError(
                f"Compilation dependency cycle: {product.value} of {module.loc.mod_path}"
            );
        }
        if task.state == TaskState.SUCCEEDED and program.analysis.active {
            reader = program.analysis.active[-1];
            parent = program.analysis.modules[reader[0]].tasks[(reader[1], reader[2])];
            dependency = (product_path(module), product, "");
            parent.dependencies[dependency] = program.analysis.versions.get(
                dependency, 0
            );
        }
        return task.state == TaskState.SUCCEEDED;
    }
    task = ProductTask(
        product,
        TaskState.RUNNING,
        initial_version=program.analysis.versions.get(
            (product_path(module), product, ""), 0
        )
    );
    tasks[(product, "")] = task;
    program.analysis.active.append(address);
    start = time.perf_counter();
    before = len(program.errors_had);
    generation = program.analysis.mutations.generation;
    passes: list[PassIdentity] = [];
    try {
        for (prerequisite, fact) in PRODUCT_REQUIREMENTS.get(product, []) {
            if fact is not None and program.analysis.provides(module, fact) {
                continue;
            }
            if not require_product(program, module, prerequisite) {
                task.state = TaskState.FAILED;
                return False;
            }
        }
        passes = product_pipeline(product);
        if not passes {
            task.state = TaskState.UNAVAILABLE;
            return False;
        }
        import from jaclang.compiler.pipeline.executor { execute_passes }
        execute_passes(program, module, passes);
        import from jaclang.compiler.pipeline.schedule { product_has_result }
        if not product_has_result(program, module, product) {
            task.state = TaskState.UNAVAILABLE;
            return False;
        }
        task.state = TaskState.CANCELLED
            if program.options.cancel_token is not None
                and program.options.cancel_token.is_set()
            else (
                TaskState.SUCCEEDED
                    if len(program.errors_had) == before
                    else TaskState.FAILED
            );
        return task.state == TaskState.SUCCEEDED;
    } except ProductUnavailable {
        task.state = TaskState.UNAVAILABLE;
        return False;
    } except Exception {
        task.state = TaskState.FAILED;
        raise;
    } finally {
        program.analysis.active.pop();
        task.elapsed = time.perf_counter() - start;
        dependency = (product_path(module), product, "");
        program.analysis.finish(address, task, product_path(module));
        if task.state in (TaskState.FAILED, TaskState.CANCELLED)
            or (
                task.state == TaskState.UNAVAILABLE
                and program.analysis.mutations.generation != generation
            ) {
            mark_failed_graph(program, module);
        }
        if not program.analysis.active {
            discard_failed_graphs(program);
        }
    }
}


def mark_failed_graph(program: AnalysisServices, module: Module) {
    path = product_path(module);
    program.analysis.invalid_graphs.add(module);
    program.analysis.failed_paths.add(path);
    program.analysis.failed_paths.update(program.transitive_dependents(path));
    for address in program.analysis.active {
        record = program.analysis.modules.get(address[0]);
        owner = record.owner() if record is not None else None;
        if owner is not None {
            program.analysis.failed_paths.add(product_path(owner));
        }
    }
}

def discard_failed_graphs(program: AnalysisServices) {
    paths = set(program.analysis.failed_paths);
    program.analysis.failed_paths.clear();
    for path in paths {
        program.invalidate_module(path);
    }
}

def product_path(module: Module) -> str {
    return os.path.realpath(module.loc.mod_path or f"@{id(module)}");
}
