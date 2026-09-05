import asyncio;
import dataclasses;
import inspect;
import json;
import os;
import from inspect { iscoroutine }
import from typing { get_type_hints }
import from jaclang.data.serializer { Serializer }
import from jaclang.client.client_bundle {
    ClientBundleError,
    MissingBunError,
    _ensure_js_generated
}
import from jaclang.runtime.exceptions { ReadOnlyRetry, WriteConflict }
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.server.net { PORT_RETRY_LIMIT }
import from jaclang.server.serving.server { ServingServer }
import type from jaclang.runtime.constructs { Archetype }

impl ExecutionManager.report_collector(
    call_state: CallState
) -> list[JsonValue] | Generator | AsyncGenerator {
    import from queue { Empty }
    final_reports: list[JsonValue] = [];
    while True {
        try {
            report_item = call_state.reports.get_nowait();
        } except Empty {
            return final_reports;
        }
        if report_item is call_state._sentinel {
            return final_reports;
        } elif isgenerator(report_item) or isinstance(report_item, AsyncGenerator) {
            return report_item;
        } else {
            final_reports.append(report_item);
        }
    }
}

async def _begin_request_context(user_root_id: str) -> tuple[(ExecutionContext, any)] {
    import from jaclang.runtime.osp_kernel_sv { isolate_request_walk_stack }
    parent = Jac.get_context();
    req_ctx = ExecutionContext(_parent=parent);
    await req_ctx.aset_user_root(user_root_id);
    token = Jac.push_request_context(req_ctx);

    isolate_request_walk_stack();
    return (req_ctx, token);
}

async def _abegin_user_request_context(
    user_manager: UserManager, username: str
) -> tuple[(ExecutionContext, any, str)] | dict[str, JsonValue] {
    import from jaclang.runtime.exceptions { MissingAnchorError }
    root_id = await user_manager.aget_root_id(username);
    if not root_id {
        import os;
        if username != Con.GUEST.value and os.environ.get('JAC_SV_SIBLING') {
            ensure_root = getattr(
                user_manager, 'ensure_user_root', user_manager.get_root_id
            );
            root_id = await asyncio.to_thread(ensure_root, username);
        }
        if not root_id {
            return {'error': 'User not found'};
        }
    }
    try {
        (ctx, token) = await _begin_request_context(root_id);
        return (ctx, token, root_id);
    } except MissingAnchorError {
        if username != Con.GUEST.value {
            raise RuntimeError(
                f"Root anchor {root_id} for user '{username}' does not "
                "exist in the anchor store. The data store was likely "
                "reset or migrated out from under the users db; restore "
                "it or re-register the user."
            );
        }
        import logging;
        logging.getLogger('jaclang.serve').warning(
            f"Guest root anchor {root_id} is missing from the anchor store; "
            "minting a fresh guest root."
        );
        healed_id = await asyncio.to_thread(user_manager.reset_root, username);
        if not healed_id {
            return {'error': 'User not found'};
        }
        (ctx, token) = await _begin_request_context(healed_id);
        return (ctx, token, healed_id);
    }
}

def _deserialize_wire_args(args: dict[(str, any)]) {
    for (k, v) in list(args.items()) {
        if isinstance(v, dict) and '__type__' in v {
            deserialized = Serializer.deserialize(v);
            if deserialized is not None {
                args[k] = deserialized;
            }
        } elif isinstance(v, list) {
            args[k] = [
                Serializer.deserialize(item)
                    if isinstance(item, dict) and '__type__' in item
                    else item for item in v
            ];
        }
    }
}

impl observe_read_tier_retry(metrics: any, unit_key: str) -> None {
    import logging;
    logging.getLogger("jaclang.serve").info(
        f"read tier: unit {unit_key or '<anonymous>'} wrote inside a read-only "
        "snapshot; re-running at SERIALIZABLE and recording it as a writer"
    );
    if metrics is not None {
        try {
            metrics.record_read_tier_retry(unit_key);
        } except Exception as e {
            logging.getLogger("jaclang.serve").debug(
                f"read tier retry metric not recorded: {type(e).__name__}: {e}"
            );
        }
    }
}


def _unit_key_for(target: any) -> (str | None) {
    mod = str(getattr(target, '__module__', '') or '');
    name = str(getattr(target, '__name__', '') or '');
    if not name {
        return None;
    }
    return f"{mod}.{name}";
}


def _occ_policy -> tuple[str, int, int] {
    mode = "retry";
    max_attempts = 5;
    backoff_ms = 0;
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        if cfg is not None {
            mode = str(cfg.serve.on_conflict).strip().lower();
            if mode not in ("retry", "fail") {
                mode = "retry";
            }
            max_attempts = cfg.serve.conflict_max_attempts;
            backoff_ms = cfg.serve.conflict_backoff_ms;
        }
    } except Exception {}
    return (mode, max_attempts, backoff_ms);
}

impl ExecutionManager._finalize_call_response(
    call_state: CallState, result: any
) -> dict[str, JsonValue] | Generator | AsyncGenerator {
    call_state.reports.put_nowait(call_state._sentinel);
    reports = await self.report_collector(call_state);
    await Jac.acommit();
    if isgenerator(result) or isinstance(result, AsyncGenerator) {
        return result;
    }
    if isgenerator(reports) or isinstance(reports, AsyncGenerator) {
        return reports;
    }

    envelope: dict[str, object] = {
        'result': Serializer.serialize(result, api_mode=True),
        'reports': Serializer.serialize(reports, api_mode=True)
    };
    ctx = Jac.get_context();
    if ctx.diagnostics {
        envelope['warnings'] = [d.to_dict() for d in ctx.diagnostics];
        ctx.diagnostics.clear();
    }
    return dict[(str, JsonValue)](envelope);
}

async def _run_function_with_occ(
    mgr: ExecutionManager,
    args: dict[(str, any)],
    username: str,
    run_attempt: Callable,
    deserialize_args: bool = True,
    include_traceback: bool = False,
    unit_key: (str | None) = None
) -> dict[str, JsonValue] | Generator | AsyncGenerator {
    resolved = await _abegin_user_request_context(mgr.user_manager, username);
    if isinstance(resolved, dict) {
        return resolved;
    }
    (ctx, req_token, root_id) = resolved;
    ctx.mem.unit_enter(unit_key);
    settled = False;
    try {
        if deserialize_args {
            _deserialize_wire_args(args);
        }
        (occ_mode, occ_max, occ_backoff_ms) = _occ_policy();
        max_attempts = 1 if occ_mode == "fail" else max(1, occ_max);
        attempt = 0;
        ro_retries = 0;
        while attempt < max_attempts {
            attempt += 1;
            call_token = ctx.call_state.set(CallState());
            call_state = ctx.call_state.get();
            try {
                outcome = await run_attempt(call_state, ctx);
                ctx.mem.unit_exit();
                settled = True;
                return outcome;
            } except ReadOnlyRetry as rr {
                settled = False;
                if ctx.mem.unit_depth() == 0 {
                    ctx.mem.unit_enter(unit_key);
                }
                ctx.mem.abort();
                ctx.pending_effects.clear();
                ctx.read_versions.clear();
                ctx.diagnostics.clear();
                ro_retries += 1;
                observe_read_tier_retry(mgr.metrics, rr.unit_key or unit_key or "");
                if ro_retries <= 2 {
                    attempt -= 1;
                }
                await ctx.aset_user_root(root_id);
            } except WriteConflict as wc {
                settled = False;
                if ctx.mem.unit_depth() == 0 {
                    ctx.mem.unit_enter(unit_key);
                }
                ctx.mem.abort();
                ctx.pending_effects.clear();
                ctx.read_versions.clear();

                ctx.diagnostics.clear();
                if attempt >= max_attempts {
                    return {
                        'error': wc.message(),
                        'error_code': 'write_conflict',
                        'http_status': 409
                    };
                }
                if occ_backoff_ms > 0 {
                    await asyncio.sleep(occ_backoff_ms * attempt / 1000.0);
                }
                await ctx.aset_user_root(root_id);
            } except Exception as e {
                ctx.mem.abort();
                if include_traceback {
                    import traceback;

                    return {'error': str(e), 'traceback': traceback.format_exc()};
                }
                return {'error': str(e)};
            } finally {
                ctx.call_state.reset(call_token);
            }
        }
        return {
            'error': 'write_conflict: retries exhausted',
            'error_code': 'write_conflict',
            'http_status': 409
        };
    } finally {
        try {
            if not settled {
                ctx.mem.unit_exit();
            }
        } except Exception as ue {
            import logging;
            logging.getLogger(__name__).warning(
                f"unit exit failed: {type(ue).__name__}: {ue}"
            );
        }
        Jac.reset_request_context(req_token);
    }
}

impl ExecutionManager.execute_function(
    func: Callable[(..., any)], args: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    import inspect;

    if inspect.iscoroutinefunction(func) {
        return await self.execute_function_async(func, args, username);
    }
    return await self.execute_function_sync(func, args, username);
}

impl ExecutionManager.execute_function_sync(
    func: Callable[(..., any)], args: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    async def run_attempt(
        call_state: CallState, _ctx: ExecutionContext
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator {
        result = await asyncio.to_thread(func, **args);

        if iscoroutine(result) {
            result = await result;
        }
        return await self._finalize_call_response(call_state, result);
    }
    return await _run_function_with_occ(
        self, args, username, run_attempt, unit_key=_unit_key_for(func)
    );
}

impl ExecutionManager.execute_function_async(
    func: Callable[(..., any)], args: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    async def run_attempt(
        call_state: CallState, _ctx: ExecutionContext
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator {
        result = await func(**args);
        return await self._finalize_call_response(call_state, result);
    }
    return await _run_function_with_occ(
        self, args, username, run_attempt, unit_key=_unit_key_for(func)
    );
}

impl ExecutionManager.spawn_walker(
    walker_cls: type[WalkerArchetype], fields: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    if walker_cls.__jac_async__ {
        return await self.spawn_walker_async(walker_cls, fields, username);
    }
    return await self.spawn_walker_sync(walker_cls, fields, username);
}

impl ExecutionManager.spawn_walker_sync(
    walker_cls: type[WalkerArchetype], fields: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    import from jaclang.runtime.constructs { NodeArchetype }
    target_node_id = fields.pop('_jac_spawn_node', None);
    _deserialize_wire_args(fields);

    async def run_attempt(
        call_state: CallState, ctx: ExecutionContext
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator {
        `walker = walker_cls(**fields);
        if target_node_id {
            target_node = await Jac.aget_object(target_node_id);
            if not isinstance(target_node, NodeArchetype) {
                return {'error': f"Invalid target node: {target_node_id}"};
            }
        } else {
            target_node = ctx.get_root();
        }
        result = await asyncio.to_thread(Jac.`spawn, `walker, target_node);

        if iscoroutine(result) {
            result = await result;
        }
        return await self._finalize_call_response(call_state, result);
    }
    return await _run_function_with_occ(
        self,
        fields,
        username,
        run_attempt,
        deserialize_args=False,
        include_traceback=True,
        unit_key=_unit_key_for(walker_cls)
    );
}

impl ExecutionManager.spawn_walker_async(
    walker_cls: type[WalkerArchetype], fields: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    import from jaclang.runtime.constructs { NodeArchetype }
    target_node_id = fields.pop('_jac_spawn_node', None);
    _deserialize_wire_args(fields);

    async def run_attempt(
        call_state: CallState, ctx: ExecutionContext
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator {
        `walker = walker_cls(**fields);
        if target_node_id {
            target_node = await Jac.aget_object(target_node_id);
            if not isinstance(target_node, NodeArchetype) {
                return {'error': f"Invalid target node: {target_node_id}"};
            }
        } else {
            target_node = ctx.get_root();
        }
        spawn_result = Jac.`spawn(`walker, target_node);
        if iscoroutine(spawn_result) {
            result = await spawn_result;
        } else {
            result = spawn_result;
        }
        return await self._finalize_call_response(call_state, result);
    }
    return await _run_function_with_occ(
        self,
        fields,
        username,
        run_attempt,
        deserialize_args=False,
        include_traceback=True,
        unit_key=_unit_key_for(walker_cls)
    );
}

impl ModuleIntrospector.postinit -> None {
    import threading;
    self._bundle_builder = Jac.get_client_bundle_builder();
    self._bundle_lock = threading.Lock();
}

impl ModuleIntrospector.load(force_reload: bool = False) -> None {
    import sys;
    loaded = Jac.loaded_modules.get(self.module_name);
    if (loaded is not None and self.module_file) {
        mod_file = loaded?.__file__;
        if not (
            mod_file
            and os.path.exists(mod_file)
            and os.path.realpath(mod_file) == os.path.realpath(self.module_file)
        ) {
            Jac.loaded_modules.pop(self.module_name, None);
            sys.modules.pop(self.module_name, None);
        }
    }
    needs_import = force_reload or (self.module_name not in Jac.loaded_modules);
    import_base = os.path.dirname(os.path.abspath(self.module_file))
        if self.module_file
        else self.base_path;
    if (needs_import and import_base) {
        Jac.jac_import(
            target=self.module_name,
            base_path=os.path.abspath(import_base),
            lng='jac',
            reload_module=force_reload
        );
    }
    module = Jac.loaded_modules.get(self.module_name);
    if (not module or ((self._module is module) and not needs_import)) {
        if module is not None and self._module is module {
            self._check_module_freshness();
        }
        return;
    }
    self._module = module;
    self._load_manifest();
    self._extract_access_levels();
    self._functions = self._collect_functions();
    self._walkers = self._collect_walkers();

    self._collect_cross_boundary_endpoints();
    self._fill_endpoint_effect_defaults();
    self._invalidate_bundle();
}

impl ModuleIntrospector._load_manifest -> None {
    self._spa_routes_loaded = False;
    self._spa_route_patterns = None;
    if not self._module {
        return;
    }
    base: dict = {};
    mod_path: str = getattr(self._module, '__file__', '');
    if mod_path {
        import from jaclang.server.sealed_serve { serve_manifest_for }
        sm = serve_manifest_for(mod_path);
        if sm is not None {
            base = dict(sm.get('client', {}) or {});
            base['endpoint_effects'] = sm.get('endpoint_effects', {}) or {};
            self._client_manifest = base;
            return;
        }
    }
    if mod_path {
        mod = Jac.get_program().find_module(os.path.abspath(mod_path));
        if not mod {
            mod = Jac.get_program().compile(mod_path);
        }
        if mod and mod.gen.client_manifest and not mod.gen.client_manifest.exports {
            _ensure_js_generated(mod, Jac.get_program());
        }
        if (mod and mod.gen.client_manifest) {
            manifest = mod.gen.client_manifest;
            base = {
                'exports': manifest.exports,
                'globals': manifest.globals,
                'params': manifest.params,
                'globals_values': manifest.globals_values,
                'has_client': manifest.has_client
            };
        }
    }

    aggregated: dict = {};

    for hub in Jac.get_program()._search_hubs() {
        for hub_mod in hub.values() {
            if hub_mod and hub_mod.gen.interop_manifest {
                for (ekey, eeff) in hub_mod.gen.interop_manifest.endpoint_effects.items() {
                    aggregated[ekey] = eeff;
                }
            }
        }
    }
    base['endpoint_effects'] = aggregated;
    self._client_manifest = base;
}

impl ModuleIntrospector._extract_access_levels -> None {
    if not self._module {
        return;
    }
    import jaclang.compiler.frontend.unitree as uni;
    self._function_access = {};
    self._walker_access = {};
    mod_path: str = getattr(self._module, '__file__', '');
    if mod_path {
        import from jaclang.server.sealed_serve { serve_manifest_for }
        sm = serve_manifest_for(mod_path);
        if sm is not None {
            self._function_access = dict(sm.get('func_access', {}) or {});
            self._walker_access = dict(sm.get('walker_access', {}) or {});
            return;
        }
    }
    main_mod = Jac.get_program().find_module(os.path.abspath(mod_path))
        if mod_path
        else None;
    if not main_mod and mod_path {
        try {
            main_mod = Jac.get_program().compile(os.path.abspath(mod_path));
        } except Exception as e {
            import logging;
            logging.getLogger(__name__).warning(
                "serve: fallback compile of %s failed; access table will be "
                "empty and endpoints default to auth-required: %s",
                mod_path,
                e
            );
            main_mod = None;
        }
    }
    if not main_mod {
        return;
    }

    sources: list = [main_mod];
    for item in main_mod.body {
        if isinstance(item, uni.Import) and item.is_jac and item.from_loc {
            try {
                src = item.from_loc.resolve_relative_path();
            } except Exception {
                continue;
            }
            if not (src and src.endswith(('.jac', '.jac'))) {
                continue;
            }
            prov = Jac.get_program().find_module(src);
            if not prov {
                try {
                    prov = Jac.get_program().compile(src);
                } except Exception {
                    prov = None;
                }
            }
            if prov {
                sources.append(prov);
            }
        }
    }
    import from jaclang.compiler.driver.schedules { get_boundary_analysis_sched }
    for src_mod in sources {
        if not (src_mod and src_mod.gen and src_mod.gen.interop_manifest) {
            continue;
        }
        man = src_mod.gen.interop_manifest;

        if not (man.walker_access or man.func_access) {
            try {
                Jac.get_program().run_schedule(src_mod, get_boundary_analysis_sched());
            } except Exception as e {
                import logging;
                logging.getLogger(__name__).warning(
                    "serve: boundary analysis of %s failed; its imported "
                    "endpoints will default to auth-required: %s",
                    src_mod?.loc?.mod_path,
                    e
                );
            }
            man = src_mod.gen.interop_manifest;
        }
        for (name, auth) in man.func_access.items() {
            if name not in self._function_access {
                self._function_access[name] = auth;
            }
        }
        for (name, auth) in man.walker_access.items() {
            if name not in self._walker_access {
                self._walker_access[name] = auth;
            }
        }
    }

    import from jaclang.runtime.archetype { WalkerArchetype as _WalkerArch }
    _live_missing = False;
    for _wname in dir(self._module) {
        _wcls = getattr(self._module, _wname, None);
        if (
            isinstance(_wcls, type)
            and issubclass(_wcls, _WalkerArch)
            and getattr(_wcls, '__module__', '') == self._module?.__name__
            and _wname not in self._walker_access
        ) {
            _live_missing = True;
            break;
        }
    }
    if _live_missing and mod_path {
        try {
            _fresh_mod = Jac.get_program().compile(os.path.abspath(mod_path));
            _fman = _fresh_mod.gen.interop_manifest;
            if _fman is not None {
                for (name, auth) in _fman.func_access.items() {
                    self._function_access[name] = auth;
                }
                for (name, auth) in _fman.walker_access.items() {
                    self._walker_access[name] = auth;
                }
            }
        } except Exception {}
    }
}


impl ModuleIntrospector._register_sealed_bindings(
    sm: dict[str, any], img_root: str
) -> None {
    import from jaclang.runtime.constructs { WalkerArchetype }

    def resolve_sealed(src_path: str, name: str) -> any {
        for loaded in list(Jac.loaded_modules.values()) {
            f = loaded?.__file__;
            if f and os.path.abspath(f) == os.path.abspath(src_path) {
                sym = getattr(loaded, name, None);
                if sym is not None {
                    return sym;
                }
            }
        }
        target = os.path.basename(src_path);
        if target.endswith('.jac') {
            target = target.removesuffix('.jac');
        }
        try {
            imported = Jac.jac_import(
                target=target, base_path=os.path.dirname(src_path), lng='jac'
            );
            if imported {
                return getattr(imported[0], name, None);
            }
        } except Exception as e {
            import logging;
            logging.getLogger("jaclang.serve").warning(
                "sealed cross-boundary endpoint '%s' unavailable: server module "
                "%r failed to import (%s: %s)",
                name,
                src_path,
                type(e).__name__,
                e
            );
            return None;
        }
        return None;
    }

    for b in sm.get('cross_bindings', []) or [] {
        name = b.get('name');
        rel = b.get('src');
        if not name or not rel {
            continue;
        }
        auth = bool(b.get('auth', True));
        src_path = os.path.join(img_root, rel);
        if b.get('kind') == 'walker' {
            if name in self._walkers {
                continue;
            }
            wcls = resolve_sealed(src_path, name);
            if isinstance(wcls, type) and issubclass(wcls, WalkerArchetype) {
                self._walkers[name] = wcls;
                self._walker_access[name] = auth;
            }
        } else {
            if name in self._functions {
                continue;
            }
            fn = resolve_sealed(src_path, name);
            if fn is not None and callable(fn) {
                self._functions[name] = fn;
                self._function_access[name] = auth;
            }
        }
    }
}

impl ModuleIntrospector._collect_cross_boundary_endpoints -> None {
    if not (self._module and Jac.get_program().mod) {
        return;
    }
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    import from jaclang.runtime.constructs { WalkerArchetype }

    sealed_mod_path: str = getattr(self._module, '__file__', '');
    if sealed_mod_path {
        import from jaclang.server.sealed_serve { serve_manifest_for, sealed_root_for }
        sm_sealed = serve_manifest_for(sealed_mod_path);
        if sm_sealed is not None {
            self._register_sealed_bindings(
                sm_sealed, sealed_root_for(sealed_mod_path) or ""
            );
            return;
        }
    }

    fn_bindings: dict[str, any] = {};
    walker_bindings: dict[str, any] = {};
    func_access: dict[str, bool] = {};
    walker_access: dict[str, bool] = {};

    for hub in Jac.get_program()._search_hubs() {
        for mod in hub.values() {
            man = mod.gen.interop_manifest if (mod and mod.gen) else None;
            if not man {
                continue;
            }
            for binding in man.server_exports_to_client {
                table = walker_bindings if binding.kind == 'walker' else fn_bindings;
                prior = table.get(binding.name);
                if prior is None {
                    table[binding.name] = binding;
                } elif prior.ast_node is not binding.ast_node {
                    import logging;
                    logging.getLogger("jaclang.serve").warning(
                        "conflicting cross-boundary %s binding '%s'; keeping the "
                        "first registration",
                        binding.kind,
                        binding.name
                    );
                }
            }
            for (acc_name, auth) in man.func_access.items() {
                if acc_name not in func_access {
                    func_access[acc_name] = auth;
                }
            }
            for (acc_name, auth) in man.walker_access.items() {
                if acc_name not in walker_access {
                    walker_access[acc_name] = auth;
                }
            }
        }
    }

    def resolve_symbol(src_path: str, name: str) -> any {
        for loaded in list(Jac.loaded_modules.values()) {
            f = loaded?.__file__;
            if f and os.path.abspath(f) == os.path.abspath(src_path) {
                sym = getattr(loaded, name, None);
                if sym is not None {
                    return sym;
                }
            }
        }
        target = os.path.basename(src_path);
        if target.endswith('.jac') {
            target = target.removesuffix('.jac');
        }
        try {
            imported = Jac.jac_import(
                target=target, base_path=os.path.dirname(src_path), lng='jac'
            );
            if imported {
                return getattr(imported[0], name, None);
            }
        } except Exception as e {
            import logging;
            logging.getLogger("jaclang.serve").warning(
                "cross-boundary endpoint '%s' unavailable: server module %r "
                "failed to import (%s: %s)",
                name,
                src_path,
                type(e).__name__,
                e
            );
            return None;
        }
        return None;
    }

    def auth_for(name: str, table: dict, ast_node: any) -> bool {
        auth = table.get(name, None);
        if auth is None {
            is_pub = ast_node is not None
                and ast_node?.access is not None
                and ast_node.access.tag.name == Tok.KW_PUB;
            auth = not is_pub;
        }
        return auth;
    }

    for (name, binding) in fn_bindings.items() {
        if name in self._functions {
            continue;
        }
        ast_node = binding?.ast_node;
        if ast_node is None {
            continue;
        }
        src_path: str = getattr(getattr(ast_node, 'loc', ''), 'mod_path', '');
        if not src_path {
            continue;
        }
        fn = resolve_symbol(src_path, name);
        if fn is None or not callable(fn) {
            continue;
        }
        self._functions[name] = fn;
        self._function_access[name] = auth_for(name, func_access, ast_node);
    }

    for (name, binding) in walker_bindings.items() {
        if name in self._walkers {
            continue;
        }
        ast_node = binding?.ast_node;
        if ast_node is None {
            continue;
        }
        src_path: str = getattr(getattr(ast_node, 'loc', ''), 'mod_path', '');
        if not src_path {
            continue;
        }
        wcls = resolve_symbol(src_path, name);
        if not (isinstance(wcls, type) and issubclass(wcls, WalkerArchetype)) {
            continue;
        }
        self._walkers[name] = wcls;
        self._walker_access[name] = auth_for(name, walker_access, ast_node);
    }
}


impl ModuleIntrospector._fill_endpoint_effect_defaults -> None {
    if not self._client_manifest {
        self._client_manifest = {};
    }
    effects = self._client_manifest.get('endpoint_effects', {});
    for name in self._walkers.keys() {
        key = f"walker:{name}";
        if key not in effects {
            effects[key] = {"is_writer": True, "touches": ["*"]};
        }
    }
    for name in self._functions.keys() {
        key = f"func:{name}";
        if key not in effects {
            effects[key] = {"is_writer": False, "touches": ["*"]};
        }
    }
    self._client_manifest['endpoint_effects'] = effects;
}


impl ModuleIntrospector._collect_functions -> dict[str, Callable[(..., any)]] {
    if not self._module {
        return {};
    }
    functions: dict[(str, Callable[(..., any)])] = {};
    export_names = set(self._client_manifest.get('exports', []));
    for (name, `obj) in inspect.getmembers(self._module) {
        if (inspect.isfunction(`obj) and not name.startswith('_')) {
            if getattr(`obj, '__module__', '').startswith('jaclang.') {
                continue;
            }
            functions[name] = `obj;
            if (name in export_names) {
                self._client_functions[name] = `obj;
            }
        }
    }
    for name in export_names {
        if ((name not in self._client_functions) and hasattr(self._module, name)) {
            attr = getattr(self._module, name);
            if callable(attr) {
                self._client_functions[name] = attr;
            }
        }
    }
    return functions;
}

impl ModuleIntrospector._collect_walkers -> dict[str, type[WalkerArchetype]] {
    import from jaclang.runtime.constructs { WalkerArchetype }
    if not self._module {
        return {};
    }
    walkers: dict[(str, type[WalkerArchetype])] = {};
    for (name, `obj) in inspect.getmembers(self._module) {
        if (
            isinstance(`obj, type)
            and issubclass(`obj, WalkerArchetype)
            and (`obj is not WalkerArchetype)
        ) {
            walkers[name] = `obj;
        }
    }
    return walkers;
}

impl ModuleIntrospector._check_module_freshness -> None {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    if not self._module {
        return;
    }

    current_module = Jac.loaded_modules.get(self.module_name);
    if (current_module is not None and current_module is not self._module) {
        self._module = current_module;
        self._load_manifest();
        self._extract_access_levels();
        self._functions = self._collect_functions();
        self._walkers = self._collect_walkers();
        self._collect_cross_boundary_endpoints();
        self._fill_endpoint_effect_defaults();
        self._invalidate_bundle();
        return;
    }

    needs_refresh = False;
    for (name, cached_cls) in self._walkers.items() {
        current_cls = getattr(self._module, name, None);
        if current_cls is not cached_cls {
            needs_refresh = True;
            break;
        }
    }
    if not needs_refresh {
        _fresh_walkers = self._collect_walkers();
        if set(_fresh_walkers.keys()) != set(self._walkers.keys()) {
            needs_refresh = True;
        }
    }
    if needs_refresh {
        self._load_manifest();
        self._extract_access_levels();
        self._functions = self._collect_functions();
        self._walkers = self._collect_walkers();
        self._collect_cross_boundary_endpoints();
        self._invalidate_bundle();
    }
}

impl ModuleIntrospector.get_functions -> dict[str, Callable[(..., any)]] {
    if not self._functions {
        self.load();
    } else {
        self._check_module_freshness();
    }
    return {
        k: v
        for (k, v) in self._functions.items()
        if not getattr(v, 'schedule_spec', '')
    };
}

impl ModuleIntrospector.get_walkers -> dict[str, type[WalkerArchetype]] {
    if not self._walkers {
        self.load();
    } else {
        self._check_module_freshness();
    }
    return {
        k: v
        for (k, v) in self._walkers.items()
        if not v?.schedule_spec
    };
}

impl ModuleIntrospector.get_client_functions -> dict[str, Callable[(..., any)]] {
    if not self._client_functions {
        self.load();
    }
    return dict(self._client_functions);
}

impl ModuleIntrospector.resolve_root_app(configured: str = "") -> str {
    if configured {
        return configured;
    }

    self.load();
    names = list(self._client_manifest.get('exports', []));
    if not names {
        return "";
    }
    by_lower: dict[(str, str)] = {};
    for n in names {
        by_lower.setdefault(n.lower(), n);
    }
    for candidate in ["app", "index", "main", "home", "root"] {
        if candidate in by_lower {
            return by_lower[candidate];
        }
    }
    return "";
}

impl ModuleIntrospector.introspect_callable(
    func: Callable[(..., any)]
) -> dict[str, any] {
    try {
        sig = inspect.signature(func);
        type_hints = get_type_hints(func);
    } except Exception {
        return {'parameters': {}, 'return_type': 'Any'};
    }
    params = {
        name: {
            'type': getattr(
                type_hints.get(name, any), '__name__', str(type_hints.get(name, any))
            ),
            'required': (param.`default == inspect.Parameter.empty),
            'default': None
                if (param.`default == inspect.Parameter.empty)
                else str(param.`default)
        } for (name, param) in sig.parameters.items()
    };
    return_type = type_hints.get('return', any);
    return {
        'parameters': params,
        'return_type': getattr(return_type, '__name__', str(return_type))
    };
}

impl ModuleIntrospector.introspect_walker(
    walker_cls: type[WalkerArchetype]
) -> dict[str, any] {
    try {
        sig = inspect.signature(walker_cls.init);
        try {
            type_hints = get_type_hints(walker_cls.init);
        } except Exception {
            type_hints = {};
        }
    } except Exception {
        return {'fields': {}};
    }

    factory_defaults: dict[str, any] = {};
    if dataclasses.is_dataclass(walker_cls) {
        for dc_field in dataclasses.fields(walker_cls) {
            if dc_field.default_factory is dataclasses.MISSING {
                continue;
            }
            try {
                factory_defaults[dc_field.name] = dc_field.default_factory();
            } except Exception {
                factory_defaults[dc_field.name] = None;
            }
        }
    }
    fields: dict[str, dict[str, any]] = {};
    for (name, param) in sig.parameters.items() {
        if (name in ('self', 'args', 'kwargs')) {
            continue;
        }

        type_obj = type_hints.get(name, None);
        if type_obj is not None {
            type_name = getattr(type_obj, '__name__', str(type_obj));
        } else {
            annotation = param.annotation;
            if (annotation != inspect.Parameter.empty) {
                type_name = getattr(annotation, '__name__', str(annotation));
            } else {
                type_name = 'Any';
            }
        }
        is_required = param.`default == inspect.Parameter.empty;
        if is_required {
            default_val = None;
        } elif name in factory_defaults {
            default_val = factory_defaults[name];
        } else {
            default_val = param.`default;
        }
        fields[name] = {
            'type': type_name,
            'required': is_required,
            'default': default_val
        };
    }
    fields['_jac_spawn_node'] = {
        'type': 'str (node ID, optional)',
        'required': False,
        'default': 'root'
    };
    return {'fields': fields};
}

impl ModuleIntrospector._invalidate_bundle -> None {
    with self._bundle_lock {
        self._bundle = None;
        self._bundle_error = None;
    }
}

impl ModuleIntrospector.ensure_bundle -> str {
    if not self._module {
        raise RuntimeError('Module not loaded');
    }
    if self._bundle {
        return self._bundle.hash;
    }
    if self.dev_mode {
        raise ClientBundleError(
            'the dev server owns the client in dev mode; the API port does not '
            'build a production bundle'
        );
    }

    entry_epoch = self._bundle_epoch;
    with self._bundle_lock {
        if self._bundle {
            return self._bundle.hash;
        }
        if self._bundle_error is not None and self._bundle_epoch != entry_epoch {
            raise ClientBundleError(self._bundle_error);
        }
        try {
            self._bundle = self._bundle_builder.build(self._module);
            self._bundle_error = None;
            self._bundle_epoch += 1;
            return self._bundle.hash;
        } except MissingBunError {
            self._bundle_epoch += 1;
            raise;
        } except Exception as exc {
            self._bundle_error = str(exc)
                or f"{type(exc).__name__} raised with no message";
            self._bundle_epoch += 1;
            raise ClientBundleError(self._bundle_error);
        }
    }
}

impl ModuleIntrospector.render_page(
    function_name: str, args: dict[(str, any)], username: str
) -> dict[str, any] {
    return Jac.render_page(self, function_name, args, username);
}

impl ModuleIntrospector.has_client_route(url_path: str) -> bool {
    if not self._spa_routes_loaded {
        self._spa_route_patterns = self._load_spa_routes();
        self._spa_routes_loaded = True;
    }
    patterns = self._spa_route_patterns;
    if patterns is None {
        return False;
    }
    segments = [
        seg
        for seg in url_path.split('/')
        if seg
    ];
    for pattern in patterns {
        if self._spa_route_matches(pattern, segments) {
            return True;
        }
    }
    return False;
}


impl ModuleIntrospector.spa_fallback_status(url_path: str) -> int {
    if not self._spa_routes_loaded {
        self._spa_route_patterns = self._load_spa_routes();
        self._spa_routes_loaded = True;
    }
    patterns = self._spa_route_patterns;
    if patterns is None {
        return 200;
    }
    segments = [
        seg
        for seg in url_path.split('/')
        if seg
    ];
    for pattern in patterns {
        if self._spa_route_matches(pattern, segments) {
            return 200;
        }
    }
    return 404;
}

impl ModuleIntrospector._load_spa_routes -> (list[str] | None) {
    import from pathlib { Path }
    import from jaclang.client.route_scanner { RouteScanner, resolve_route_exports }
    if not self.base_path {
        return None;
    }
    try {
        scanner = RouteScanner(
            project_root=Path(self.base_path), route_exports_of=resolve_route_exports
        );
        if not scanner.has_pages_dir() {
            return None;
        }
        return [
            `entry.path
            for `entry in scanner.scan()
            if `entry.path not in ('*', '/*')
        ];
    } except Exception {
        return None;
    }
}

impl ModuleIntrospector._spa_route_matches(pattern: str, segments: list[str]) -> bool {
    psegs = [
        seg
        for seg in pattern.split('/')
        if seg
    ];
    for (i, pseg) in enumerate(psegs) {
        if pseg == '*' {
            return True;
        }
        if i >= len(segments) {
            return False;
        }
        if pseg.startswith(':') {
            continue;
        }
        if pseg != segments[i] {
            return False;
        }
    }
    return len(segments) == len(psegs);
}

impl ModuleIntrospector.is_auth_required_for_function(func_name: str) -> bool {
    return self._function_access.get(func_name, True);
}

impl ModuleIntrospector.is_auth_required_for_walker(walker_name: str) -> bool {
    return self._walker_access.get(walker_name, True);
}


impl ModuleIntrospector.restspec_routes -> list[tuple[str, str, any]] {
    routes: list[tuple[str, str, any]] = [];
    try {
        for (name, target) in sorted(self.get_walkers().items()) {
            spec = target?.restspec;
            if spec is not None {
                routes.append((name, 'walker', spec));
            }
        }
        for (name, target) in sorted(self.get_functions().items()) {
            fn_target: any = target;
            fn_spec = fn_target?.restspec;
            if fn_spec is not None {
                routes.append((name, 'function', fn_spec));
            }
        }
    } except Exception {
        return routes;
    }
    return routes;
}


impl ModuleIntrospector.declared_api_paths -> list[str] {
    paths: list[str] = [];
    for (_name, _kind, spec) in self.restspec_routes() {
        path = str(spec.path or '');
        if not path.startswith('/') or path == '/' {
            continue;
        }
        if path not in paths {
            paths.append(path);
        }
    }
    return sorted(paths);
}


impl ModuleIntrospector.client_claimed_paths(candidates: list[str]) -> list[str] {
    claimed: list[str] = [];
    for candidate in candidates {
        try {
            if self.has_client_route(candidate) {
                claimed.append(candidate);
            }
        } except Exception {
            continue;
        }
    }
    return claimed;
}


impl ModuleIntrospector.walker_protocol(walker_name: str) -> APIProtocol {
    walkers = self.get_walkers();
    if walker_name not in walkers {
        return APIProtocol.HTTP;
    }
    restspec: any = target_restspec(walkers[walker_name]);
    if restspec?.protocol {
        return APIProtocol(restspec.protocol);
    }
    return APIProtocol.HTTP;
}

impl ModuleIntrospector.function_protocol(func_name: str) -> APIProtocol {
    functions = self.get_functions();
    if func_name not in functions {
        return APIProtocol.HTTP;
    }
    restspec: any = target_restspec(functions[func_name]);
    if restspec?.protocol {
        return APIProtocol(restspec.protocol);
    }
    return APIProtocol.HTTP;
}


def _warm_persistence {
    try {
        ctx = Jac.get_context();
        anchor = ctx.system_root;
        ctx.mem.commit();
        logger.debug(f"persistent store ready (system root {anchor.id})");
    } except Exception as e {
        logger.warning(
            f"persistent store not reachable while starting up "
            f"({type(e).__name__}: {e}); requests that touch graph state will "
            "provision it on demand"
        );
    }
}


impl JacAPIServer.postinit -> None {
    import from jaclang.server.identity.config { configure_identity, signing_secret }
    import from jaclang.server.task_scheduler { Scheduler }
    if self.settings is None {
        overrides: dict[str, any] = {};
        if self.port > 0 {
            overrides['port'] = self.port;
        }
        overrides['strict_port'] = self.strict_port;
        self.settings = ServeSettings.load(self.base_path, overrides);
    }
    self.port = self.settings.port;
    configure_identity(self.settings.auth, self.base_path);
    signing_secret();
    _warm_persistence();
    self.user_manager = UserManager(
        base_path=self.base_path, provision_unknown_users=self.is_sv_sibling
    );
    _um = self.user_manager;
    def _shared_root_id -> (str | None) {
        found = _um.get_root_id(Con.GUEST.value);
        if found is None {
            _um.ensure_internal_user(Con.GUEST.value, '__no_password__');
            found = _um.get_root_id(Con.GUEST.value);
        }
        return found;
    }
    Jac.set_shared_root_resolver(_shared_root_id);
    self.introspector = ModuleIntrospector(
        self.module_name, self.base_path, module_file=self.module_file
    );
    self.execution_manager = ExecutionManager(
        base_path=self.base_path, user_manager=self.user_manager
    );
    self.scheduler = Scheduler.instance();
    self.drain = DrainState(timeout=self.settings.timeouts.drain);
    if self.extensions is None {
        self.extensions = list(Jac.get_server_extensions());
    }
}

impl JacAPIServer.resolved_settings -> ServeSettings {
    if self.settings is None {
        self.settings = ServeSettings.load(self.base_path);
    }
    return self.settings;
}

impl JacAPIServer.identity -> UserManager {
    return self.user_manager;
}

impl JacAPIServer.require_app -> ServingApp {
    if self.app is None {
        raise RuntimeError('build_app() has not run');
    }
    return self.app;
}

impl JacAPIServer.add_endpoint(ep: JEndPoint) -> None {
    self._endpoints.append(ep);
    self.require_app().add_endpoint(ep);
}

impl JacAPIServer.add_ws_endpoint(path: str, handler: Callable[..., any]) -> None {
    self.require_app().add_ws_endpoint(WSEndPoint(path=path, handler=handler));
}

impl JacAPIServer.add_middleware(fn: Callable[..., any]) -> None {
    self.require_app().add_middleware(fn);
}

impl JacAPIServer.add_shutdown_hook(fn: Callable[..., any]) -> None {
    self.require_app().add_shutdown_hook(fn);
}

impl JacAPIServer._install_middleware -> None {
    import from jaclang.server.middleware { jwt_middleware, request_context_middleware }
    self.add_middleware(request_context_middleware());
    self.add_middleware(jwt_middleware(self.user_manager));
}

impl JacAPIServer.build_app -> ServingApp {
    import from jaclang.server.middleware { metrics_middleware }
    import from jaclang.server.serving.drain { drain_middleware }
    import from jaclang.server.serving.middleware {
        cors_middleware,
        custom_headers_middleware
    }
    import from jaclang.server.serving.openapi { register_docs_endpoints }
    import from jaclang.project.config { JacConfig }
    settings = self.resolved_settings();
    self.introspector.load();
    self.introspector.dev_mode = settings.dev;
    app = ServingApp(
        title=f"{self.module_name} API",
        version='1.0.0',
        multipart_spool_bytes=settings.limits.multipart_spool_bytes
    );
    if not settings.docs_enabled or self.introspector.has_client_route('/docs') {
        app.docs_url = None;
    }
    if not settings.docs_enabled {
        app.openapi_url = None;
    }
    self.app = app;
    self._endpoints = [];
    self._install_middleware();
    self.register_endpoints();
    for ext in (self.extensions or []) {
        ext.register(self);
    }
    self.add_middleware(drain_middleware(self.drain, self.module_name));
    self.add_middleware(
        cors_middleware(
            allow_origins=list(settings.cors_origins),
            allow_credentials=True,
            allow_methods=['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
            allow_headers=['Content-Type', 'Authorization', 'X-Request-Id']
        )
    );
    config = JacConfig.discover(Path(self.base_path) if self.base_path else None);
    if config
        and config.environments
        and 'response' in config.environments
        and 'headers' in config.environments['response'] {
        pairs = [
            (str(hn), str(hv))
            for (hn, hv) in config.environments['response']['headers'].items()
        ];
        if pairs {
            self.add_middleware(custom_headers_middleware(pairs));
        }
    }
    if self.metrics is not None {
        self.add_middleware(metrics_middleware(self.metrics, self.metrics_path));
    }
    if settings.dev {
        _self = self;
        async def hmr_refresh_middleware(request: any, call_next: any) -> any {
            if _self._hmr_pending {
                _self._refresh_dev_endpoints();
            }
            next_fn: any = call_next;
            return await next_fn(request);
        }
        self.add_middleware(hmr_refresh_middleware);
    }
    self._configure_openapi_security();
    register_docs_endpoints(app);
    return app;
}

impl JacAPIServer.register_endpoints -> None {
    import from jaclang.server.endpoints.auth { register_auth_endpoints }
    import from jaclang.server.endpoints.colocated { register_colocated_endpoints }
    import from jaclang.server.endpoints.introspection {
        register_introspection_endpoints
    }
    import from jaclang.server.endpoints.pages {
        register_diagnostics_endpoints,
        register_graph_endpoints,
        register_page_endpoints
    }
    import from jaclang.server.endpoints.walkers {
        register_function_endpoints,
        register_walker_endpoints
    }
    import from jaclang.server.serving.health { register_health_endpoints }
    settings = self.resolved_settings();
    register_health_endpoints(self.require_app(), self.drain);
    if settings.static_only {
        register_page_endpoints(self);
        return;
    }
    register_diagnostics_endpoints(self);
    register_auth_endpoints(self);
    register_introspection_endpoints(self);
    register_walker_endpoints(self);
    register_function_endpoints(self);
    register_colocated_endpoints(self);
    if settings.graph_enabled {
        register_graph_endpoints(self);
    }
    register_page_endpoints(self);
}

impl JacAPIServer._configure_openapi_security -> None {
    app = self.require_app();
    app.openapi_security = {
        'BearerAuth': {
            'type': 'http',
            'scheme': 'bearer',
            'bearerFormat': 'JWT',
            'description': "Enter your JWT token (without 'Bearer ' prefix)"
        }
    };
    app.openapi_cache = None;
}

impl JacAPIServer.enable_hmr(hot_reloader: any) -> None {
    self._hot_reloader = hot_reloader;
    def on_change(event: any) {
        self._hmr_pending = True;
        logger.debug(f"Change detected: {event.path}");
    }
    hot_reloader.watcher.add_callback(on_change);
}

impl JacAPIServer._refresh_dev_endpoints -> None {
    self._hmr_pending = False;
    self.introspector.load(force_reload=True);
    if self.app is None {
        return;
    }
    app = self.require_app();
    app.clear_routes();
    self._endpoints = [];
    import from jaclang.server.serving.openapi { register_docs_endpoints }
    self.register_endpoints();
    for ext in (self.extensions or []) {
        ext.register(self);
    }
    self._configure_openapi_security();
    register_docs_endpoints(app);
}

impl JacAPIServer.load_module(force_reload: bool = False) -> None {
    self.introspector.load(force_reload);
}

impl JacAPIServer.module.getter -> object {
    return self.introspector._module;
}

impl JacAPIServer.get_functions -> dict[str, Callable[(..., any)]] {
    return self.introspector.get_functions();
}

impl JacAPIServer.get_walkers -> dict[str, type[WalkerArchetype]] {
    return self.introspector.get_walkers();
}

impl JacAPIServer.print_endpoint_docs -> None {
    print_endpoint_docs(self);
}

impl JacAPIServer._ensure_sv_siblings -> None {
    if self.is_sv_sibling {
        return;
    }
    import from jaclang.server { sv_client }
    visited: set[str] = set();
    frontier: list[str] = sv_client.get_consumer_providers(self.module_name);
    while frontier {
        wave: list[str] = [
            p
            for p in frontier
            if p not in visited
        ];
        if not wave {
            break;
        }
        for p in wave {
            visited.add(p);
        }
        sv_client.ensure_all(wave);
        next_frontier: list[str] = [];
        for provider in wave {
            for transitive in sv_client.get_consumer_providers(provider) {
                if transitive not in visited {
                    next_frontier.append(transitive);
                }
            }
        }
        frontier = next_frontier;
    }
}

impl JacAPIServer._ensure_client_bundle -> None {
    import sys;
    import time;
    import from jaclang.cli.banners { JAC_DISCORD_URL }
    import from jaclang.cli.console { console }
    import from jaclang.client.client_diagnostics { format_build_diagnostics }
    import from jaclang.project.config { get_config }
    settings = self.resolved_settings();
    if settings.dev or settings.no_client or settings.client_dist {
        return;
    }
    client_exports = self.introspector._client_manifest.get('exports', []);
    if not client_exports {
        return;
    }
    import from jaclang.client.targets.registry { client_app_dir_for }
    config = get_config();
    dist_dir = client_app_dir_for(config) / 'dist'
        if config
        else Path(self.base_path) / '.jac' / 'client' / 'dist';
    if (dist_dir / 'manifest.json').exists() {
        console.print("  ✔ PWA bundle already built", style="success");
        return;
    }
    started = time.time();
    try {
        with console.status("Building client bundle...", spinner="dots") as _status {
            self.introspector.ensure_bundle();
        }
        console.print(
            f"  ✔ Client bundle ready ({time.time() - started:.1f}s)", style="success"
        );
    } except Exception as e {
        project_dir = config.project_root if config else Path.cwd();
        console.warning("Failed to build client bundle");
        console.print(file=sys.stderr);
        console.print(
            format_build_diagnostics(str(project_dir), str(e), config), file=sys.stderr
        );
        console.warning(
            'Client pages will not be available until this is fixed.', emoji=True
        );
        console.info('Try again after running: jac clean --all', emoji=True);
        console.info(
            f"If it still doesn't work, ask for help at {JAC_DISCORD_URL}", emoji=True
        );
    }
}

impl JacAPIServer._ensure_internal_users -> None {
    import from jaclang.server.identity.user_manager { SYSTEM_USER, UserRole }
    self.user_manager.ensure_internal_user(Con.GUEST.value, '__no_password__');
    self.user_manager.ensure_internal_user(
        SYSTEM_USER, '__no_login__', role=UserRole.SYSTEM.value
    );
}

impl JacAPIServer._register_scheduled_tasks -> None {
    import from jaclang.server.identity.user_manager { SYSTEM_USER }
    import from jaclang.server.task_scheduler { ScheduleSpec }
    _self = self;
    def _make_target(name: str, is_walker: bool) -> Callable[[], None] {
        async def _run -> any {
            intro = _self.introspector;
            registry: dict[str, any] = (
                dict(intro._walkers) if is_walker else dict(intro._functions)
            );
            if name not in registry {
                return {'error': f"'{name}' is no longer registered"};
            }
            ctx = Jac.create_j_context(user_root=None);
            token = Jac.push_request_context(ctx);
            try {
                if is_walker {
                    return await _self.execution_manager.spawn_walker(
                        registry[name], {}, SYSTEM_USER
                    );
                }
                return await _self.execution_manager.execute_function(
                    registry[name], {}, SYSTEM_USER
                );
            } finally {
                try {
                    ctx.close();
                } finally {
                    Jac.reset_request_context(token);
                }
            }
        }
        def target {
            outcome = asyncio.run(_run());
            if isinstance(outcome, dict) and 'error' in outcome {
                logger.error(f"scheduled {name} failed: {outcome.get('error')}");
            }
        }
        return target;
    }
    self.introspector.load();
    for (registry, is_walker) in [
        (dict(self.introspector._walkers), True),
        (dict(self.introspector._functions), False)
    ] {
        for (name, item) in registry.items() {
            spec = item?.schedule_spec;
            if not isinstance(spec, ScheduleSpec) {
                continue;
            }
            self.scheduler.register(
                name, _make_target(name, is_walker), spec, is_walker
            );
        }
    }
    if self.scheduler.has_pending() {
        logger.info(
            f"static scheduler: {len(self.scheduler._tasks)} task(s) registered"
        );
    }
    import from jaclang.server.identity.identity_storage { PgIdentityStorage }
    storage = self.user_manager._identity_storage;
    store: any = storage.store if isinstance(storage, PgIdentityStorage) else None;
    if store is not None {
        _store: any = store;
        def _lease(key: str, ttl: int) -> bool {
            import os;
            import socket;
            return bool(
                _store.kv_acquire_lease(
                    key, ttl, f"{socket.gethostname()}:{os.getpid()}"
                )
            );
        }
        self.scheduler.lease = _lease;
    }
}

impl JacAPIServer._validate_or_raise -> None {
    import from jaclang.server.settings { ServeConfigError }
    settings = self.resolved_settings();
    problems = settings.validate();
    for ext in (self.extensions or []) {
        problems.extend(ext.validate(self));
    }
    if problems {
        raise ServeConfigError(
            "cannot start the server:\n" + '\n'.join(f"  - {p}" for p in problems)
        );
    }
}

impl JacAPIServer._prepare_to_serve(dev: bool, no_client: bool) -> ServeSettings {
    import from jaclang.server.serving.accesslog { configure_access_logging }
    settings = self.resolved_settings();
    settings.dev = dev;
    settings.no_client = no_client;
    self.introspector.load();
    self._validate_or_raise();
    configure_access_logging(
        enabled=settings.access_log.enabled,
        format=settings.access_log.format,
        suppress_health_checks=settings.access_log.suppress_health_checks
    );
    self._ensure_sv_siblings();
    self._ensure_internal_users();
    self._ensure_client_bundle();
    self.build_app();
    self._register_scheduled_tasks();
    return settings;
}

impl JacAPIServer.serve_background(
    dev: bool = False,
    no_client: bool = False,
    on_ready: Callable[..., None] | None = None,
    port_retries: int = 0
) -> Callable[[], None] {
    import from jaclang.server.outbox { start_worker_if_bridging, stop_worker }
    settings = self._prepare_to_serve(dev, no_client);
    serving = ServingServer(
        app=self.require_app(), settings=settings, drain=self.drain
    );
    self.server = serving;
    self.scheduler.start_if_pending();
    start_worker_if_bridging();
    for ext in (self.extensions or []) {
        ext.on_worker_start(self);
    }
    def _ready(bound_port: int) {
        self.port = bound_port;
        if on_ready is not None {
            on_ready(bound_port);
        }
    }
    stop_transport = serving.serve_background(
        on_ready=_ready, port_retries=port_retries
    );
    def _stop {
        stop_transport();
        self.scheduler.stop();
        stop_worker();
    }
    return _stop;
}

impl JacAPIServer.start(
    dev: bool = False,
    no_client: bool = False,
    on_ready: Callable[..., None] | None = None
) -> int {
    import from jaclang.cli.console { console }
    import from jaclang.server.serving.supervisor { WorkerSupervisor }
    settings = self._prepare_to_serve(dev, no_client);

    def _announce(bound_port: int) {
        self.port = bound_port;
        scheme = settings.scheme();
        shown_host = 'localhost'
            if settings.host in ('0.0.0.0', '::')
            else settings.host;
        console.print(
            f"Jac API Server running on {scheme}://{shown_host}:{bound_port}"
                + (
                    f" ({settings.workers.count} workers, "
                    f"{settings.workers.threads} threads each)"
                        if settings.workers.multi_process()
                        else ''
                )
        );
        if on_ready {
            try {
                on_ready(bound_port);
            } except TypeError {
                on_ready();
            }
        }
    }

    port_retries = 0 if settings.strict_port else PORT_RETRY_LIMIT;
    if settings.workers.multi_process() {
        supervisor = WorkerSupervisor(
            settings=settings, worker_main=self._worker_main, on_ready=_announce
        );
        return supervisor.run(port_retries=port_retries);
    }
    code = self._worker_main(None, on_ready=_announce, port_retries=port_retries);
    console.print('\nShutting down server...');
    return code;
}

impl JacAPIServer._worker_main(
    handle: (WorkerHandle | None),
    on_ready: (Callable[[int], None] | None) = None,
    port_retries: int = 0
) -> int {
    import from jaclang.server.outbox { start_worker_if_bridging, stop_worker }
    settings = self.resolved_settings();
    serving = ServingServer(
        app=self.require_app(),
        settings=settings,
        drain=self.drain,
        sock=handle.listener if handle is not None else None,
        request_budget=handle.request_budget if handle is not None else 0,
        heartbeat=handle.heartbeat if handle is not None else None
    );
    self.server = serving;
    self.scheduler.start_if_pending();
    start_worker_if_bridging();
    for ext in (self.extensions or []) {
        ext.on_worker_start(self);
    }
    def _ready(bound_port: int) {
        self.port = bound_port;
        if on_ready is not None {
            on_ready(bound_port);
        }
        if handle is not None and handle.notify_ready is not None {
            handle.notify_ready();
        }
    }
    try {
        return serving.run(on_ready=_ready, port_retries=port_retries);
    } finally {
        self.scheduler.stop();
        stop_worker();
    }
}

impl JacAPIServer.request_stop -> None {
    if self.server is not None {
        self.server.request_stop();
    }
}


impl print_endpoint_docs(server: JacAPIServer) -> None {
    import from jaclang.cli.console { console }
    server.introspector.load();
    functions = server.introspector.get_functions();
    walkers = server.introspector.get_walkers();
    client_exports = server.introspector._client_manifest.get('exports', []);
    """Print section header.""";
    def section(title: str, auth: str = '') {
        console.print(f"{title}{f' ({auth})' if auth else ''}{('-' * 80)}");
    }
    """Print endpoint with description.""";
    def endpoint(method: str, path: str, desc: str, details: str = '') {
        console.print(f"{method:6} {path}");
        console.print(f"       {desc}");
        if details {
            console.print(f"       {details}");
        }
    }
    """Format parameter info.""";
    def format_param(name: str, info: dict[(str, any)]) -> str {
        req = 'required' if info['required'] else 'optional';
        `default = f", default: {info['default']}" if info.get('default') else '';
        return f"{name}: {info['type']} ({req}{`default})";
    }
    console.print(('\n' + ('=' * 80)));
    console.print(f"JAC API SERVER - {server.module_name}");
    console.print(('=' * 80));
    section('AUTHENTICATION');
    endpoint(
        'POST',
        '/user/register',
        'Create new user account',
        'Body: { "identities": [{ "type": "username", "value": str }], "credential": { "type": "password", "password": str } }'
    );
    endpoint(
        'POST',
        '/user/login',
        'Authenticate and get token',
        'Body: { "identity": { "type": "username", "value": str }, "credential": { "type": "password", "password": str } }'
    );
    endpoint(
        'GET',
        '/user/me',
        'Get authenticated user information',
        'Requires:  Authorization header with Bearer token'
    );
    section('INTROSPECTION', 'Authenticated');
    endpoint('GET', '/functions', 'List all functions → string[]');
    endpoint('GET', '/walkers', 'List all walkers → string[]');
    if functions {
        section('FUNCTIONS', 'Authenticated');
        for (name, func) in functions.items() {
            sig = server.introspector.introspect_callable(func);
            sig_params: dict[str, dict[str, any]] = sig['parameters'];
            params = [format_param(n, i) for (n, i) in sig_params.items()];
            params_str = ', '.join(params) if params else 'none';
            endpoint('GET', f"/function/{name}", 'Get signature');
            endpoint(
                'POST',
                f"/function/{name}",
                f"Call function → {sig['return_type']}",
                f"Args: {{ {params_str} }}" if params else 'No arguments'
            );
        }
    }
    if walkers {
        section('WALKERS', 'Authenticated');
        for (name, walker_cls) in walkers.items() {
            info = server.introspector.introspect_walker(walker_cls);
            info_fields: dict[str, dict[str, any]] = info['fields'];
            fields = [format_param(n, i) for (n, i) in info_fields.items()];
            fields_str = ', '.join(fields[:3]);
            if (len(fields) > 3) {
                fields_str += f", ... (+{(len(fields) - 3)} more)";
            }
            endpoint('GET', f"/walker/{name}", 'Get walker fields');
            endpoint(
                'POST',
                f"/walker/{name}",
                'Spawn walker',
                f"Fields: {{ {fields_str} }}" if fields else 'No fields'
            );
        }
    }
    import from jaclang.project.config { get_config }
    import from jaclang.server.endpoints.colocated {
        colocated_providers,
        provider_route
    }
    import from jaclang.server.static_files { sibling_app_names }
    config = get_config();
    root_app = server.introspector.resolve_root_app();
    section('CLIENT PAGES', 'Public');
    if client_exports {
        funcs_list = ', '.join(sorted(client_exports)[:8]);
        if (len(client_exports) > 8) {
            funcs_list += f" (+{(len(client_exports) - 8)} more)";
        }
        console.print(f"Available ({len(client_exports)}): {funcs_list}");
        endpoint(
            'GET',
            '/cl/<name>',
            'Render HTML for client function',
            'Example: /cl/App?arg1=value1'
        );
    } else {
        console.print(
            "\nNo client functions. Define with 'cl def' for browser-side rendering."
        );
    }
    for sibling in sibling_app_names(config, server.base_path) {
        endpoint('GET', f"/cl/{sibling}/", f"Sibling app bundle: dist/{sibling}");
    }
    for provider_app in colocated_providers() {
        route = provider_route(config, provider_app);
        endpoint('POST', f"{route}/walker/<name>", f"Colocated app {provider_app}");
    }
    section('STATIC');
    if root_app {
        endpoint('GET', '/', f'Serves client app: {root_app}');
    } else {
        endpoint('GET', '/', 'API information and endpoint list');
    }
    endpoint('GET', '/static/client.js', 'Client JavaScript bundle');
    total = 2 + 2 + (len(functions) * 2) + (len(walkers) * 2) + 2;
    console.print(('\n' + ('=' * 80)));
    console.print(
        f"TOTAL: {len(functions)} functions · {len(walkers)} walkers · {len(
            client_exports
        )} client functions · {total} endpoints"
    );
    console.print(('=' * 80));
    console.print('\nAuth: Bearer token (Authorization: Bearer <token>)\n');
}
