import asyncio;
import logging;
import from jaclang.server.identity.user_manager { SYSTEM_USER }
import from jaclang.server.server { JacAPIServer, ServerExtension }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.jobs.queue {
    JobInfo,
    JobQueueStore,
    bind_service,
    bind_system_root,
    root_hex
}
import from jaclang.scale.jobs.runner {
    JobRootMissing,
    JobRunner,
    JobTargetMissing,
    QueueSpec
}

glob logger: logging.Logger = logging.getLogger(__name__);


def module_for_identity(identity: str) -> any {
    import sys;
    import from jaclang { JacRuntime as Jac }
    import from jaclang.data.type_identity { module_identity }
    if not identity.startswith('jac:') {
        return Jac.loaded_modules.get(identity) or sys.modules.get(identity);
    }
    for module in list(sys.modules.values()) {
        facts: any = module?.__jac_persistence__;
        if isinstance(facts, tuple) and facts and module_identity(facts) == identity {
            return module;
        }
    }
    return None;
}


def resolve_job_target(server: JacAPIServer, name: str) -> any {
    import inspect;
    import from jaclang { JacRuntime as Jac }
    import from jaclang.runtime.constructs { WalkerArchetype }
    found: any = None;
    if ':' in name {
        (identity, attr) = name.rsplit(':', 1);
        module: any = module_for_identity(identity);
        found = getattr(module, attr, None) if module is not None else None;
    } else {
        found = server.find_target(name);
        if found is None {
            home: any = Jac.loaded_modules.get(server.module_name);
            found = getattr(home, name, None) if home is not None else None;
        }
    }
    if isinstance(found, type) and issubclass(found, WalkerArchetype) {
        return found;
    }
    if inspect.isfunction(found) {
        return found;
    }
    raise JobTargetMissing(f"'{name}' is not a walker or function this app loads");
}


def job_executor(server: JacAPIServer, run_as: str) -> Callable[[JobInfo], None] {
    def _execute(job: JobInfo) {
        import from jaclang.runtime.constructs { WalkerArchetype }
        target: any = resolve_job_target(server, job.target);
        is_walker = isinstance(target, type) and issubclass(target, WalkerArchetype);

        async def _run {
            import from jaclang.scale.memory.context { JScaleExecutionContext }
            import from jaclang { JacRuntime as Jac }
            import from jaclang.runtime.exceptions { MissingAnchorError }
            ctx = JScaleExecutionContext();
            token = Jac.push_request_context(ctx);
            try {
                manager = server.execution_manager;
                result: any = None;
                try {
                    if is_walker {
                        result = await manager.spawn_walker(
                            target, dict(job.args), run_as, root_id=job.as_root
                        );
                    } else {
                        result = await manager.execute_function(
                            target, dict(job.args), run_as, root_id=job.as_root
                        );
                    }
                } except MissingAnchorError as e {
                    if job.as_root and root_hex(e.anchor_id) == job.as_root {
                        raise JobRootMissing(
                            f"root {job.as_root} no longer exists"
                        ) from e;
                    }
                    raise;
                }
                if isinstance(result, dict) and 'error' in result {
                    raise RuntimeError(str(result.get('error')));
                }
            } finally {
                try {
                    ctx.mem.close();
                } finally {
                    Jac.reset_request_context(token);
                }
            }
        }

        asyncio.run(_run());
    }
    return _execute;
}


obj JobQueueExtension(ServerExtension) {
    has runner: (JobRunner | None) = None,
        run_as: str = SYSTEM_USER,
        service: str = "";

    def register(server: JacAPIServer) -> None {
        import from jaclang.server.task_scheduler { schedule_namespace }
        self.service = schedule_namespace(str(server.module_name));
        bind_service(self.service);
        system_user = server.user_manager.find_user_by_identity(SYSTEM_USER);
        if system_user {
            self.run_as = str(system_user.get('user_id', SYSTEM_USER));
        }
        system_root = server.user_manager.get_root_id(self.run_as);
        if system_root {
            bind_system_root(system_root);
        }
        if not get_scale_config().get_jobs_config()['enabled'] {
            return;
        }
        ext = self;
        async def _stop {
            if ext.runner is not None {
                await asyncio.to_thread(ext.runner.stop, server.drain.remaining());
                ext.runner = None;
            }
        }
        server.add_shutdown_hook(_stop);
    }

    def validate(server: JacAPIServer) -> list[str] {
        problems: list[str] = [];
        for name in get_scale_config().get_jobs_config()['system_targets'] {
            try {
                resolve_job_target(server, name);
            } except JobTargetMissing {
                problems.append(
                    f"[scale.jobs] system_targets names '{name}', which is not a "
                    "walker or function this app loads"
                );
            }
        }
        return problems;
    }

    def on_worker_start(server: JacAPIServer) {
        import from jaclang.server.shared_store { shared_store, shared_store_failure }
        cfg = get_scale_config().get_jobs_config();
        if not cfg['enabled'] or self.runner is not None {
            return;
        }
        shared = shared_store();
        if shared is None {
            logger.error(
                "[scale.jobs] is enabled but the scale database is unavailable "
                f"({shared_store_failure()}); no job runner started"
            );
            return;
        }
        metrics: any = server.metrics;
        record: any = metrics.record_job_counts if metrics is not None else None;
        self.runner = JobRunner(
            store=JobQueueStore(store=shared.new_session(), service=self.service),
            queues=[
                QueueSpec(
                    name=name,
                    concurrency=int(spec['concurrency']),
                    lease_s=float(spec['lease_s'])
                ) for (name, spec) in cfg['queues'].items()
            ],
            execute=job_executor(server, self.run_as),
            poll_s=float(cfg['poll_seconds']),
            retention_s=float(cfg['retention_seconds']),
            on_counts=record
        );
        self.runner.start();
    }
}
