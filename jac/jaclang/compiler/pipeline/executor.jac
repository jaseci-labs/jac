import from jaclang.compiler.pipeline.progress {
    pipeline_progress,
    ProgressEvent,
    ProgressState
}
import from jaclang.compiler.ir.identity { MutationScope, relation_bit }
import type from jaclang.compiler.session.services { AnalysisServices }
import type from jaclang.compiler.backends.es.framework_backend { FrameworkBackend }
import from jaclang.compiler.pipeline.contracts { PassSpec, PassContext }
import type from jaclang.compiler.pipeline.contracts { QuerySpec }
import time;
import type from threading { Event }
import type from jaclang.compiler.session.compiler { JacCompiler }
import type from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.ir.schema { Module, UniNode }
import from jaclang.compiler.pipeline.pass_base { Transform }
import from jaclang.compiler.pipeline.contracts { PassIdentity, UtilityProduct }
import from jaclang.compiler.session.diagnostics {
    build_diagnostic_policy,
    deliver_alerts
}
import atexit;
import os;
import sys;
import from collections.abc { Callable, Iterator, Sequence }
import from contextlib { contextmanager }
import from jaclang.compiler.pipeline.pass_base { Alert, DiagnosticPolicy }
import from jaclang.compiler.session.session { JacProgram }

def run_pass(
    step: PassIdentity | PassSpec,
    ir_in: UniNode,
    prog: AnalysisServices,
    cancel_token: Event | None = None,
    policy: (DiagnosticPolicy | None) = None,
    backend: FrameworkBackend | None = None
) -> Transform {
    import from jaclang.compiler.pipeline.schedule { PASS_REGISTRY }
    spec = PASS_REGISTRY[step] if isinstance(step, PassIdentity) else step;
    pol = policy if policy is not None else build_diagnostic_policy(prog);
    errors: list[Alert] = [];
    warnings: list[Alert] = [];
    inst: Transform | None = None;
    completed = prog.analysis.take_early(ir_in, spec.identity.value)
        if isinstance(ir_in, Module)
        else None;
    if completed is not None and isinstance(ir_in, Module) {
        if completed.errors_had or completed.warnings_had {
            sources = {ir_in.source.file_path: ir_in.source};
            for nd in ir_in._in_mod_nodes {
                sources[nd.loc.mod_path] = nd.loc.orig_src;
            }
            completed.errors_had = [
                alert
                for alert in completed.errors_had
                if alert.code is None
                    or not pol.is_suppressed(
                        alert.code, alert.loc, source=sources.get(alert.loc.mod_path)
                    )
            ];
            completed.warnings_had = [
                alert
                for alert in completed.warnings_had
                if alert.code is None
                    or not pol.is_suppressed(
                        alert.code, alert.loc, source=sources.get(alert.loc.mod_path)
                    )
            ];
        }
    }
    ir_in.attach_permit(prog.analysis.mutations);
    started = time.perf_counter();
    pipeline_progress.emit(
        ProgressEvent(
            spec.identity.value,
            ir_in.loc.mod_path,
            prog.context_key,
            ProgressState.STARTED
        )
    );
    try {
        import from jaclang.compiler.backends.common.artifact_store { artifact_scope }
        with artifact_scope(prog.analysis.artifacts), MutationScope(
            prog.analysis.mutations, sum(relation_bit(family) for family in spec.writes)
        ) {
            inst = spec.create(
                PassContext(
                    program=prog,
                    ir=ir_in,
                    policy=pol,
                    cancel_token=cancel_token,
                    completed=completed,
                    errors=errors,
                    warnings=warnings,
                    client_backend=backend
                )
            );
        }
    } finally {
        eff = pol;
        if completed is not None and isinstance(inst, Transform) {
            for alert in completed.errors_had + completed.warnings_had {
                alert.from_pass = type(inst);
            }
        }
        if isinstance(inst, Transform) and inst.policy is not None {
            eff = inst.policy;
        }
        deliver_alerts(errors, warnings, prog, eff);
        state = ProgressState.FAILED
            if not isinstance(inst, Transform) or errors
            else (
                ProgressState.CANCELLED
                    if isinstance(inst, Transform) and inst.cancel_requested
                    else ProgressState.SUCCEEDED
            );
        pipeline_progress.emit(
            ProgressEvent(
                spec.identity.value,
                ir_in.loc.mod_path,
                prog.context_key,
                state,
                time.perf_counter() - started
            )
        );
        try {
            ledger = prog.analysis;
            pass_name = spec.identity.value;
            ledger.pass_runs[pass_name] = ledger.pass_runs.get(pass_name, 0) + 1;
            if isinstance(inst, Transform) {
                ledger.pass_time[pass_name] = (
                    ledger.pass_time.get(pass_name, 0.0) + inst.time_taken
                );
            }
        } except Exception {}
    }
    assert inst is not None;
    return inst;
}

def compile_module(
    compiler: JacCompiler,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: str | None = None
) -> Module {
    import from jaclang.compiler.pipeline.schedule { module_pipeline }
    import from jaclang.compiler.pipeline.request { ModuleCompilation }
    task = ModuleCompilation(compiler, program, path, options, source);
    for step in module_pipeline() {
        if options.cancel_token is not None and options.cancel_token.is_set() {
            break;
        }
        started = time.perf_counter();
        try {
            if task.module in program.analysis.invalid_graphs {
                break;
            }
            step.execute(task);
        } finally {
            name = step.phase.name;
            program.analysis.phase_time[name] = (
                program.analysis.phase_time.get(name, 0.0) + time.perf_counter()
                - started
            );
        }
    }
    return task.module;
}

def execute_passes(
    program: AnalysisServices,
    module: Module,
    passes: list[PassIdentity],
    cancel_token: Event | None = None
) -> Module {
    import from jaclang.compiler.pipeline.schedule {
        validate_schedule,
        pass_provides,
        PASS_REGISTRY
    }
    import from jaclang.compiler.pipeline.executor { run_pass }
    import from jaclang.compiler.session.diagnostics { build_diagnostic_policy }
    import from jaclang.compiler.pipeline.contracts { ProductUnavailable }
    if module in program.analysis.invalid_graphs {
        raise ProductUnavailable(
            "Analysis graph was discarded after a failed or cancelled request"
        );
    }
    program.analysis.module(module);
    provided = program.analysis.provided(module);
    validate_schedule(
        passes,
        preprovided=provided,
        origin=f"schedule for module {module.loc.mod_path}"
    );
    policy = build_diagnostic_policy(program);
    completed = program.analysis.module(module).completed;
    for step in passes {
        if step in completed {
            continue;
        }
        if cancel_token is not None and cancel_token.is_set() {
            break;
        }
        result = run_pass(
            step, module, program, cancel_token=cancel_token, policy=policy
        );
        output = result.ir_out;
        assert isinstance(output, Module) , "A module pass must return a Module";
        module = output;
        if result.cancel_requested
            or not PASS_REGISTRY[step].can_continue(result.errors_had) {
            break;
        }
        provided.update(pass_provides(step));
        if cancel_token is None or not cancel_token.is_set() {
            completed.add(step);
        }
    }
    return module;
}


def run_utility(
    product: UtilityProduct,
    ir: UniNode,
    program: AnalysisServices,
    cancel_token: Event | None = None
) -> Transform {
    import from jaclang.compiler.pipeline.schedule { utility_pipeline }
    result: Transform | None = None;
    for step in utility_pipeline(product) {
        result = run_pass(step, ir, program, cancel_token=cancel_token);
    }
    assert result is not None;
    return result;
}


def execute_query[A, R](
    program: AnalysisServices, module: Module, spec: QuerySpec[A, R], request: A
) -> R {
    import from jaclang.compiler.ir.identity { GraphId }
    import from jaclang.compiler.pipeline.products {
        product_path,
        mark_failed_graph,
        discard_failed_graphs
    }
    import copy;
    import from jaclang.compiler.pipeline.contracts {
        QueryContext,
        ProductTask,
        TaskState,
        ProductUnavailable
    }
    import from jaclang.compiler.backends.common.artifact_store { artifact_scope }
    if program.options.cancel_token is not None
        and program.options.cancel_token.is_set() {
        raise ProductUnavailable("Query cancelled before execution");
    }
    task = ProductTask(spec.product, TaskState.RUNNING);
    work_module = copy.deepcopy(module) if spec.clone_syntax else module;
    record = program.analysis.module(work_module);
    recipe = spec.recipe(request);
    address = (record.identity, spec.product, recipe);
    previous = record.tasks.get((spec.product, recipe));
    if previous is not None and previous.state == TaskState.RUNNING {
        raise RuntimeError(f"Compilation query cycle: {spec.identity.value}");
    }
    if program.analysis.active {
        program.analysis.dependents.setdefault(address, set()).add(
            program.analysis.active[-1]
        );
    }
    record.tasks[(spec.product, recipe)] = task;
    task.initial_version = program.analysis.versions.get(
        (product_path(module), spec.product, recipe), 0
    );
    program.analysis.active.append(address);
    started = time.perf_counter();
    pipeline_progress.emit(
        ProgressEvent(
            spec.identity.value,
            module.loc.mod_path,
            program.context_key,
            ProgressState.STARTED
        )
    );
    try {
        context = QueryContext(program, work_module, build_diagnostic_policy(program));
        with artifact_scope(program.analysis.artifacts), MutationScope(
            program.analysis.mutations,
            sum(relation_bit(family) for family in spec.writes)
        ) {
            result = spec.create(context, request);
        }
        deliver_alerts(result.errors_had, result.warnings_had, program, context.policy);
        task.state = TaskState.CANCELLED
            if result.cancel_requested
            else (TaskState.FAILED if result.errors_had else TaskState.SUCCEEDED);
        if task.state != TaskState.SUCCEEDED {
            raise ProductUnavailable(
                f"Query {spec.identity.value} did not produce a valid result"
            );
        }
        return result.result;
    } except Exception {
        if task.state == TaskState.RUNNING {
            task.state = TaskState.FAILED;
        }
        raise;
    } finally {
        task.elapsed = time.perf_counter() - started;
        state = ProgressState.SUCCEEDED
            if task.state == TaskState.SUCCEEDED
            else (
                ProgressState.CANCELLED
                    if task.state == TaskState.CANCELLED
                    else ProgressState.FAILED
            );
        pipeline_progress.emit(
            ProgressEvent(
                spec.identity.value,
                module.loc.mod_path,
                program.context_key,
                state,
                task.elapsed
            )
        );
        program.analysis.active.pop();
        dependency = (product_path(module), spec.product, recipe);
        program.analysis.finish(address, task, product_path(module));
        if task.state != TaskState.SUCCEEDED and not spec.clone_syntax {
            mark_failed_graph(program, module);
        }
        if not program.analysis.active {
            discard_failed_graphs(program);
        }
        name = spec.identity.value;
        program.analysis.pass_runs[name] = program.analysis.pass_runs.get(name, 0) + 1;
        program.analysis.pass_time[name] = program.analysis.pass_time.get(name, 0.0)
            + task.elapsed;
    }
}
