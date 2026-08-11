import from jaclang.cli.console { console }
import from jaclang.cli.banners { JAC_DISCORD_URL }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.client_bundle { MissingBunError, _ensure_js_generated }
import from jaclang.runtimelib.exceptions { WriteConflict }
import from jaclang.runtimelib.auth_models {
    IdentityType,
    LoginRequest,
    RegisterRequest
}

impl JacAPIServer._make_user_manager -> UserManager {
    return UserManager(base_path=self.base_path);
}

impl UserManager.postinit -> None {
    import sqlite3;
    import threading;

    data_path_override = os.environ.get('JAC_DATA_PATH');
    effective_data_path = data_path_override or self.base_path;
    data_dir = os.path.join(effective_data_path, ".jac", "data");
    os.makedirs(data_dir, exist_ok=True);
    self._db_path = os.path.join(data_dir, "main.db");
    self._conn = None;

    self._lock = threading.RLock();
}

impl UserManager._ensure_connection -> None {
    import sqlite3;
    with self._lock {
        if self._conn is not None {
            return;
        }
        self._conn = sqlite3.connect(self._db_path, check_same_thread=False);
        self._conn.execute("PRAGMA journal_mode=WAL");
        self._conn.execute("PRAGMA synchronous=NORMAL");
        self._conn.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                password_hash TEXT NOT NULL,
                token TEXT UNIQUE NOT NULL,
                root_id TEXT NOT NULL
            )
            """
        );
        self._conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_users_token ON users(token)"
        );
        self._conn.commit();
    }
}

impl UserManager.create_user(username: str, password: str) -> dict[str, str] {
    import from jaclang.jac0core.constructs { Root }
    self._ensure_connection();
    assert self._conn is not None;
    with self._lock {
        cursor = self._conn.execute(
            "SELECT 1 FROM users WHERE username = ?", (username, )
        );
        if cursor.fetchone() {
            return {'error': 'User already exists'};
        }
        ctx = Jac.get_context();
        user_root = Root();
        root_anchor = user_root.__jac__;
        Jac.save(root_anchor);
        Jac.commit(root_anchor);
        root_id = root_anchor.id.hex;
        token = secrets.token_urlsafe(32);
        password_hash = hashlib.sha256(password.encode()).hexdigest();
        self._conn.execute(
            "INSERT INTO users (username, password_hash, token, root_id) VALUES (?, ?, ?, ?)",
            (username, password_hash, token, root_id)
        );
        self._conn.commit();
        return {'username': username, 'token': token, 'root_id': root_id};
    }
}

impl UserManager.reset_root(username: str) -> (str | None) {
    import from jaclang.jac0core.constructs { Root }
    self._ensure_connection();
    assert self._conn is not None;
    with self._lock {
        cursor = self._conn.execute(
            "SELECT 1 FROM users WHERE username = ?", (username, )
        );
        if not cursor.fetchone() {
            return None;
        }
        user_root = Root();
        root_anchor = user_root.__jac__;
        Jac.save(root_anchor);
        Jac.commit(root_anchor);
        root_id = root_anchor.id.hex;
        self._conn.execute(
            "UPDATE users SET root_id = ? WHERE username = ?", (root_id, username)
        );
        self._conn.commit();
        return root_id;
    }
}

impl UserManager.authenticate(
    username: str, password: str
) -> (dict[(str, str)] | None) {
    self._ensure_connection();
    assert self._conn is not None;
    password_hash = hashlib.sha256(password.encode()).hexdigest();
    with self._lock {
        cursor = self._conn.execute(
            "SELECT token, root_id FROM users WHERE username = ? AND password_hash = ?",
            (username, password_hash)
        );
        row = cursor.fetchone();
    }
    if row {
        return {'username': username, 'token': row[0], 'root_id': row[1]};
    }
    return None;
}

impl UserManager.validate_token(token: str) -> (str | None) {
    self._ensure_connection();
    assert self._conn is not None;
    with self._lock {
        cursor = self._conn.execute(
            "SELECT username FROM users WHERE token = ?", (token, )
        );
        row = cursor.fetchone();
    }
    return row[0] if row else None;
}

impl UserManager.get_root_id(username: str) -> (str | None) {
    self._ensure_connection();
    assert self._conn is not None;
    with self._lock {
        cursor = self._conn.execute(
            "SELECT root_id FROM users WHERE username = ?", (username, )
        );
        row = cursor.fetchone();
    }
    return row[0] if row else None;
}

impl UserManager.aget_root_id(username: str) -> (str | None) {
    return await asyncio.to_thread(self.get_root_id, username);
}

impl UserManager.get_user(username: str) -> (dict[(str, str)] | None) {
    self._ensure_connection();
    assert self._conn is not None;
    with self._lock {
        cursor = self._conn.execute(
            "SELECT token, root_id FROM users WHERE username = ?", (username, )
        );
        row = cursor.fetchone();
    }
    if not row {
        return None;
    }
    return {'email': username, 'token': row[0], 'root_id': row[1]};
}

impl UserManager.user_exists(username: str) -> bool {
    self._ensure_connection();
    assert self._conn is not None;
    with self._lock {
        cursor = self._conn.execute(
            "SELECT 1 FROM users WHERE username = ?", (username, )
        );
        return cursor.fetchone() is not None;
    }
}

impl UserManager.update_username(
    current_username: str, new_username: str
) -> dict[str, str] {
    import hashlib;
    self._ensure_connection();
    assert self._conn is not None;
    with self._lock {
        cursor = self._conn.execute(
            "SELECT 1 FROM users WHERE username = ? ", (new_username, )
        );
        if cursor.fetchone() {
            return {'error': 'Username already taken'};
        }
        cursor = self._conn.execute(
            "UPDATE users SET username = ? WHERE username = ?",
            (new_username, current_username)
        );
        self._conn.commit();
        if cursor.rowcount == 0 {
            return {'error': 'User not found'};
        }
        cursor = self._conn.execute(
            "SELECT token, root_id FROM users WHERE username = ?", (new_username, )
        );
        row = cursor.fetchone();
        return {'username': new_username, 'token': row[0], 'root_id': row[1]};
    }
}

impl UserManager.update_password(
    username: str, current_password: str, new_password: str
) -> dict[str, str] {
    import hashlib;
    self._ensure_connection();
    assert self._conn is not None;
    with self._lock {
        current_password_hash = hashlib.sha256(current_password.encode()).hexdigest();
        cursor = self._conn.execute(
            "SELECT 1 FROM users WHERE username = ?  AND password_hash = ?",
            (username, current_password_hash)
        );
        if not cursor.fetchone() {
            return {'error': 'Current password is incorrect'};
        }
        new_password_hash = hashlib.sha256(new_password.encode()).hexdigest();
        cursor = self._conn.execute(
            "UPDATE users SET password_hash = ? WHERE username = ?",
            (new_password_hash, username)
        );
        self._conn.commit();
        return {'username': username, 'message': 'Password updated successfully'};
    }
}

impl UserManager.close -> None {
    with self._lock {
        if self._conn {
            self._conn.close();
            self._conn = None;
        }
    }
}

impl ExecutionManager.report_collector(call_state: CallState) -> dict[str, JsonValue] {
    import from queue { Empty }
    final_reports = [];
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

async def _begin_request_context(user_root_id: str) -> tuple[(ExecutionContext, Any)] {
    import from jaclang.jac0core.osp_kernel_sv { isolate_request_walk_stack }
    parent = Jac.get_context();
    req_ctx = ExecutionContext(_parent=parent);
    await req_ctx.aset_user_root(user_root_id);
    token = Jac.push_request_context(req_ctx);

    isolate_request_walk_stack();
    return (req_ctx, token);
}

async def _abegin_user_request_context(
    user_manager: UserManager, username: str
) -> tuple[(ExecutionContext, Any, str)] | dict[str, JsonValue] {
    import from jaclang.runtimelib.exceptions { MissingAnchorError }
    root_id = await user_manager.aget_root_id(username);
    if not root_id {
        import os;
        if (
            username != Con.GUEST.value
            and os.environ.get('JAC_SV_SIBLING')
            and hasattr(user_manager, 'ensure_user_root')
        ) {
            root_id = await asyncio.to_thread(user_manager.ensure_user_root, username);
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

def _deserialize_wire_args(args: dict[(str, Any)]) {
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

def _occ_policy -> tuple {
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
    } except Exception {
        ;
    }
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

    envelope: dict[str, JsonValue] = {
        'result': Serializer.serialize(result, api_mode=True),
        'reports': Serializer.serialize(reports, api_mode=True)
    };
    ctx = Jac.get_context();
    if ctx.diagnostics {
        envelope['warnings'] = [d.to_dict() for d in ctx.diagnostics];
        ctx.diagnostics.clear();
    }
    return envelope;
}

async def _run_function_with_occ(
    mgr: ExecutionManager,
    args: dict[(str, Any)],
    username: str,
    run_attempt: Callable,
    deserialize_args: bool = True,
    include_traceback: bool = False
) -> dict[str, JsonValue] | Generator | AsyncGenerator {
    resolved = await _abegin_user_request_context(mgr.user_manager, username);
    if isinstance(resolved, dict) {
        return resolved;
    }
    (ctx, req_token, root_id) = resolved;
    ctx.mem.unit_enter();
    try {
        if deserialize_args {
            _deserialize_wire_args(args);
        }
        (occ_mode, occ_max, occ_backoff_ms) = _occ_policy();
        max_attempts = 1 if occ_mode == "fail" else max(1, occ_max);
        attempt = 0;
        while attempt < max_attempts {
            attempt += 1;
            call_token = ctx.call_state.set(CallState());
            call_state = ctx.call_state.get();
            try {
                return await run_attempt(call_state, ctx);
            } except WriteConflict as wc {
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
            ctx.mem.unit_exit();
        } except Exception as ue {
            logger.warning(f"unit exit failed: {type(ue).__name__}: {ue}");
        }
        Jac.reset_request_context(req_token);
    }
}

impl ExecutionManager.execute_function(
    func: Callable[(..., Any)], args: dict[(str, Any)], username: str
) -> dict[str, JsonValue] {
    import inspect;

    if inspect.iscoroutinefunction(func) {
        return await self.execute_function_async(func, args, username);
    }
    return await self.execute_function_sync(func, args, username);
}

impl ExecutionManager.execute_function_sync(
    func: Callable[(..., Any)], args: dict[(str, Any)], username: str
) -> dict[str, JsonValue] {
    async def run_attempt(call_state: CallState, _ctx: ExecutionContext) {
        result = await asyncio.to_thread(func, **args);

        if iscoroutine(result) {
            result = await result;
        }
        return await self._finalize_call_response(call_state, result);
    }
    return await _run_function_with_occ(self, args, username, run_attempt);
}

impl ExecutionManager.execute_function_async(
    func: Callable[(..., Any)], args: dict[(str, Any)], username: str
) -> dict[str, JsonValue] {
    async def run_attempt(call_state: CallState, _ctx: ExecutionContext) {
        result = await func(**args);
        return await self._finalize_call_response(call_state, result);
    }
    return await _run_function_with_occ(self, args, username, run_attempt);
}

impl ExecutionManager.spawn_walker(
    walker_cls: type[WalkerArchetype], fields: dict[(str, Any)], username: str
) -> dict[str, JsonValue] {
    if walker_cls.__jac_async__ {
        return await self.spawn_walker_async(walker_cls, fields, username);
    }
    return await self.spawn_walker_sync(walker_cls, fields, username);
}

impl ExecutionManager.spawn_walker_sync(
    walker_cls: type[WalkerArchetype], fields: dict[(str, Any)], username: str
) -> dict[str, JsonValue] {
    import from jaclang.jac0core.constructs { NodeArchetype }
    target_node_id = fields.pop('_jac_spawn_node', None);
    _deserialize_wire_args(fields);

    async def run_attempt(call_state: CallState, ctx: ExecutionContext) {
        `walker = walker_cls(**fields);
        if target_node_id {
            target_node = await Jac.aget_object(target_node_id);
            if not isinstance(target_node, NodeArchetype) {
                return {'error': f"Invalid target node: {target_node_id}"};
            }
        } else {
            target_node = ctx.get_root();
        }
        result = await asyncio.to_thread(Jac.spawn, `walker, target_node);

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
        include_traceback=True
    );
}

impl ExecutionManager.spawn_walker_async(
    walker_cls: type[WalkerArchetype], fields: dict[(str, Any)], username: str
) -> dict[str, JsonValue] {
    import from jaclang.jac0core.constructs { NodeArchetype }
    target_node_id = fields.pop('_jac_spawn_node', None);
    _deserialize_wire_args(fields);

    async def run_attempt(call_state: CallState, ctx: ExecutionContext) {
        `walker = walker_cls(**fields);
        if target_node_id {
            target_node = await Jac.aget_object(target_node_id);
            if not isinstance(target_node, NodeArchetype) {
                return {'error': f"Invalid target node: {target_node_id}"};
            }
        } else {
            target_node = ctx.get_root();
        }
        spawn_result = Jac.spawn(`walker, target_node);
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
        include_traceback=True
    );
}

impl ModuleIntrospector.postinit -> None {
    self._bundle_builder = Jac.get_client_bundle_builder();
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
        return;
    }
    self._module = module;
    self._load_manifest();
    self._extract_access_levels();
    self._functions = self._collect_functions();
    self._walkers = self._collect_walkers();

    self._collect_cross_boundary_endpoints();
    self._fill_endpoint_effect_defaults();
    self._bundle = None;
    self._bundle_error = None;
}

impl ModuleIntrospector._load_manifest -> None {
    self._spa_routes_loaded = False;
    self._spa_route_patterns = None;
    if not self._module {
        return;
    }
    base: dict = {};
    mod_path = self._module?.__file__;
    if mod_path {
        import from jaclang.runtimelib.sealed_serve { serve_manifest_for }
        sm = serve_manifest_for(mod_path);
        if sm is not None {
            base = dict(sm.get('client', {}) or {});
            base['endpoint_effects'] = sm.get('endpoint_effects', {}) or {};
            self._client_manifest = base;
            return;
        }
    }
    if mod_path {
        mod = Jac.program.find_module(os.path.abspath(mod_path));
        if not mod {
            mod = Jac.program.compile(mod_path);
        }
        if mod and mod.gen.client_manifest and not mod.gen.client_manifest.exports {
            _ensure_js_generated(mod, Jac.program);
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

    for hub in Jac.program._search_hubs() {
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
    import jaclang.jac0core.unitree as uni;
    self._function_access = {};
    self._walker_access = {};
    mod_path = self._module?.__file__;
    if mod_path {
        import from jaclang.runtimelib.sealed_serve { serve_manifest_for }
        sm = serve_manifest_for(mod_path);
        if sm is not None {
            self._function_access = dict(sm.get('func_access', {}) or {});
            self._walker_access = dict(sm.get('walker_access', {}) or {});
            return;
        }
    }
    main_mod = Jac.program.find_module(os.path.abspath(mod_path)) if mod_path else None;

    if not main_mod and mod_path {
        try {
            main_mod = Jac.program.compile(os.path.abspath(mod_path));
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
            prov = Jac.program.find_module(src);
            if not prov {
                try {
                    prov = Jac.program.compile(src);
                } except Exception {
                    prov = None;
                }
            }
            if prov {
                sources.append(prov);
            }
        }
    }
    import from jaclang.jac0core.compiler { get_boundary_analysis_sched }
    for src_mod in sources {
        if not (src_mod and src_mod.gen and src_mod.gen.interop_manifest) {
            continue;
        }
        man = src_mod.gen.interop_manifest;

        if not (man.walker_access or man.func_access) {
            try {
                Jac.program.run_schedule(src_mod, get_boundary_analysis_sched());
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
}


impl ModuleIntrospector._register_sealed_bindings(
    sm: dict[str, any], img_root: str
) -> None {
    import from jaclang.jac0core.constructs { WalkerArchetype }

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
    if not (self._module and Jac.program and Jac.program.mod) {
        return;
    }
    import from jaclang.jac0core.constant { Tokens as Tok }
    import from jaclang.jac0core.constructs { WalkerArchetype }

    sealed_mod_path = self._module?.__file__;
    if sealed_mod_path {
        import from jaclang.runtimelib.sealed_serve {
            serve_manifest_for,
            sealed_root_for
        }
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

    for hub in Jac.program._search_hubs() {
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
        src_path = ast_node.loc.mod_path if (ast_node and ast_node?.loc) else None;
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
        src_path = ast_node.loc.mod_path if (ast_node and ast_node?.loc) else None;
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


impl ModuleIntrospector._collect_functions -> dict[str, Callable[(..., Any)]] {
    if not self._module {
        return {};
    }
    functions: dict[(str, Callable[(..., Any)])] = {};
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
    import from jaclang.jac0core.constructs { WalkerArchetype }
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
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
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
        self._bundle = None;
        self._bundle_error = None;
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
    if needs_refresh {
        self._load_manifest();
        self._extract_access_levels();
        self._functions = self._collect_functions();
        self._walkers = self._collect_walkers();
        self._collect_cross_boundary_endpoints();
        self._bundle = None;
        self._bundle_error = None;
    }
}

impl ModuleIntrospector.get_functions -> dict[str, Callable[(..., Any)]] {
    if not self._functions {
        self.load();
    } else {
        self._check_module_freshness();
    }
    return {
        k: v
        for (k, v) in self._functions.items()
        if not v?.schedule_spec
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

impl ModuleIntrospector.get_client_functions -> dict[str, Callable[(..., Any)]] {
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
    func: Callable[(..., Any)]
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
                type_hints.get(name, Any), '__name__', str(type_hints.get(name, Any))
            ),
            'required': (param.default == inspect.Parameter.empty),
            'default': None
                if (param.default == inspect.Parameter.empty)
                else str(param.default)
        } for (name, param) in sig.parameters.items()
    };
    return_type = type_hints.get('return', Any);
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
        is_required = param.default == inspect.Parameter.empty;
        if is_required {
            default_val = None;
        } elif name in factory_defaults {
            default_val = factory_defaults[name];
        } else {
            default_val = param.default;
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

impl ModuleIntrospector.ensure_bundle -> str {
    if not self._module {
        raise RuntimeError('Module not loaded');
    }
    if self._bundle {
        return self._bundle.hash;
    }

    if self._bundle_error {
        raise ClientBundleError(self._bundle_error);
    }
    try {
        self._bundle = self._bundle_builder.build(self._module);
        self._bundle_error = None;
        return self._bundle.hash;
    } except MissingBunError {
        self._bundle = None;
        raise;
    } except Exception as exc {
        self._bundle = None;
        self._bundle_error = str(exc);
        raise ClientBundleError(self._bundle_error);
    }
}

impl ModuleIntrospector.render_page(
    function_name: str, args: dict[(str, Any)], username: str
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
    import from jaclang.runtimelib.client.route_scanner {
        RouteScanner,
        resolve_route_exports
    }
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
            entry.path
            for entry in scanner.scan()
            if entry.path not in ('*', '/*')
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


impl AuthHandler.create_user(username: str, password: str) -> TransportResponse {
    if (not username or not password) {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Username and password required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self.user_manager.create_user(username, password);
    if ('error' in result) {
        return TransportResponse.fail(
            code='USER_EXISTS',
            message=result.get('error', 'User creation failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 201})
    );
}

impl AuthHandler.login(username: str, password: str) -> TransportResponse {
    if (not username or not password) {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Username and password required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self.user_manager.authenticate(username, password);
    if not result {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid credentials',
            meta=Meta(extra={'http_status': 401})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

impl AuthHandler.update_username(
    current_username: str, new_username: str, token: str
) -> TransportResponse {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }

    token_username = self.user_manager.validate_token(token);
    if not token_username {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid or expired token',
            meta=Meta(extra={'http_status': 401})
        );
    }

    if (token_username != current_username) {
        return TransportResponse.fail(
            code='FORBIDDEN',
            message='Cannot update another user\'s username',
            meta=Meta(extra={'http_status': 403})
        );
    }
    if (not new_username) {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='New username is required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self.user_manager.update_username(current_username, new_username);
    if ('error' in result) {
        return TransportResponse.fail(
            code='UPDATE_FAILED',
            message=result.get('error', 'Username update failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

impl AuthHandler.update_password(
    username: str, current_password: str, new_password: str, token: str
) -> TransportResponse {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }

    token_username = self.user_manager.validate_token(token);
    if not token_username {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid or expired token',
            meta=Meta(extra={'http_status': 401})
        );
    }

    if (token_username != username) {
        return TransportResponse.fail(
            code='FORBIDDEN',
            message='Cannot update another user\'s password',
            meta=Meta(extra={'http_status': 403})
        );
    }
    if (not current_password or not new_password) {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Current password and new password are required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self.user_manager.update_password(
        username, current_password, new_password
    );
    if ('error' in result) {
        return TransportResponse.fail(
            code='UPDATE_FAILED',
            message=result.get('error', 'Password update failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

impl AuthHandler.get_user_info(token: str) -> TransportResponse {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }

    username = self.user_manager.validate_token(token);
    if not username {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid or expired token',
            meta=Meta(extra={'http_status': 401})
        );
    }

    user_data = self.user_manager.get_user(username);
    if not user_data {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message='User not found',
            meta=Meta(extra={'http_status': 404})
        );
    }

    return TransportResponse.success(
        data={
            'username': username,
            'root_id': user_data['root_id'],
            'token': user_data['token']
        },
        meta=Meta(extra={'http_status': 200})
    );
}

impl IntrospectionHandler.list_functions -> TransportResponse {
    self.introspector.load();
    return TransportResponse.success(
        data={'functions': list(self.introspector.get_functions().keys())},
        meta=Meta(extra={'http_status': 200})
    );
}

impl IntrospectionHandler.list_walkers -> TransportResponse {
    self.introspector.load();
    return TransportResponse.success(
        data={'walkers': list(self.introspector.get_walkers().keys())},
        meta=Meta(extra={'http_status': 200})
    );
}

impl IntrospectionHandler.get_function_info(name: str) -> TransportResponse {
    self.introspector.load();
    functions = self.introspector.get_functions();
    if (name not in functions) {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message=f"Function '{name}' not found",
            meta=Meta(extra={'http_status': 404})
        );
    }
    signature = self.introspector.introspect_callable(functions[name]);
    return TransportResponse.success(
        data={'name': name, 'signature': signature},
        meta=Meta(extra={'http_status': 200})
    );
}

impl IntrospectionHandler.get_walker_info(name: str) -> TransportResponse {
    self.introspector.load();
    walkers = self.introspector.get_walkers();
    if (name not in walkers) {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message=f"Walker '{name}' not found",
            meta=Meta(extra={'http_status': 404})
        );
    }
    info = self.introspector.introspect_walker(walkers[name]);
    return TransportResponse.success(
        data={'name': name, 'info': info}, meta=Meta(extra={'http_status': 200})
    );
}

impl ExecutionHandler.call_function(
    name: str, args: dict[(str, Any)], username: str
) -> TransportResponse {
    self.introspector.load();
    functions = self.introspector.get_functions();
    if (name not in functions) {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message=f"Function '{name}' not found",
            meta=Meta(extra={'http_status': 404})
        );
    }
    result = await self.execution_manager.execute_function(
        functions[name], args, username
    );
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

impl ExecutionHandler.spawn_walker(
    name: str, fields: dict[(str, Any)], username: str
) -> TransportResponse {
    self.introspector.load();
    walkers = self.introspector.get_walkers();
    if (name not in walkers) {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message=f"Walker '{name}' not found",
            meta=Meta(extra={'http_status': 404})
        );
    }
    result = await self.execution_manager.spawn_walker(walkers[name], fields, username);
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServer.postinit -> None {
    import from jaclang.runtimelib.scheduler { Scheduler }
    self.user_manager = self._make_user_manager();

    _um = self.user_manager;
    def _shared_root_id -> (str | None) {
        if not _um.user_exists(Con.GUEST.value) {
            _um.create_user(Con.GUEST.value, '__no_password__');
        }
        return _um.get_root_id(Con.GUEST.value);
    }
    Jac.set_shared_root_resolver(_shared_root_id);
    self.introspector = ModuleIntrospector(
        self.module_name, self.base_path, module_file=self.module_file
    );
    self.execution_manager = ExecutionManager(
        base_path=self.base_path, user_manager=self.user_manager
    );
    self.auth_handler = AuthHandler(
        introspector=self.introspector,
        execution_manager=self.execution_manager,
        user_manager=self.user_manager
    );
    self.introspection_handler = IntrospectionHandler(
        introspector=self.introspector,
        execution_manager=self.execution_manager,
        user_manager=self.user_manager
    );
    self.execution_handler = ExecutionHandler(
        introspector=self.introspector,
        execution_manager=self.execution_manager,
        user_manager=self.user_manager
    );
    self.scheduler = Scheduler.instance();
    self.server = None;
    self.app = None;
}

impl JacAPIServer.build_app -> ServingApp {
    server = self;
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else 'cl';
    cl_route_path = f"/{cl_route_prefix}/";
    app = ServingApp(title=f"{self.module_name} API", version='1.0.0');
    if server.introspector.has_client_route('/docs') {
        app.docs_url = None;
    }
    app.add_middleware(
        cors_middleware(
            allow_origins=['*'],
            allow_methods=['GET', 'POST', 'PUT', 'OPTIONS'],
            allow_headers=['Content-Type', 'Authorization']
        )
    );
    custom_headers: list[tuple[str, str]] = [];
    if config
        and config.environments
        and 'response' in config.environments
        and 'headers' in config.environments['response'] {
        for (hn, hv) in config.environments['response']['headers'].items() {
            custom_headers.append((str(hn), str(hv)));
        }
    }
    if custom_headers {
        app.add_middleware(custom_headers_middleware(custom_headers));
    }

    def _bearer_token(request: Request) -> (str | None) {
        auth_header = request.headers.get('Authorization');
        return auth_header[7:]
            if (auth_header and auth_header.startswith('Bearer '))
            else None;
    }

    def _authenticate(request: Request) -> (str | None) {
        token = _bearer_token(request);
        return server.user_manager.validate_token(token) if token else None;
    }

    def _auth_or_guest(request: Request) -> str {
        username = _authenticate(request);
        if not username {
            username = Con.GUEST.value;
            if not server.user_manager.user_exists(username) {
                server.user_manager.create_user(username, '__no_password__');
            }
        }
        return username;
    }

    def _query_args(request: Request) -> dict[str, any] {
        return {
            key: values[0] if len(values) == 1 else values
            for (key, values) in request.query_params.raw.items()
            if key != 'mode'
        };
    }

    def _read_data(request: Request) -> (dict | None) {
        if not request.body {
            return {};
        }
        try {
            parsed = request.json_sync();
        } except Exception {
            return None;
        }
        return parsed if isinstance(parsed, dict) else {};
    }

    def _render_page_response(
        request: Request, func_name: str, args: dict[str, any], status: int = 200
    ) -> ServingResponse {
        username = _auth_or_guest(request);
        try {
            render_payload = server.introspector.render_page(func_name, args, username);
            return HTMLResponse(content=render_payload['html'], status_code=status);
        } except ValueError as exc {
            return JSONResponse(content={'error': str(exc)}, status_code=404);
        } except RuntimeError as exc {
            return JSONResponse(content={'error': str(exc)}, status_code=500);
        }
    }

    def _static_base -> str {
        ctx = Jac.get_context();
        bp = (ctx.base_path_dir if ctx else '') or Jac.get_base_path_dir();
        return bp or server.base_path;
    }

    def _file_response(candidate: any) -> ServingResponse {
        import mimetypes;
        name = str(candidate);
        if name.endswith('.css') {
            mime = 'text/css; charset=utf-8';
        } else {
            mime = mimetypes.guess_type(name)[0] or 'application/octet-stream';
        }
        resp = ServingResponse(content=candidate.read_bytes(), media_type=mime);
        resp.headers.set('Cache-Control', 'public, max-age=3600');
        return resp;
    }

    def _serve_static(request: Request, rel_path: str) -> ServingResponse {
        try {
            candidate = find_static_candidate(_static_base(), rel_path);
        } except Exception as exc {
            return JSONResponse(content={'error': str(exc)}, status_code=500);
        }
        if candidate is None {
            if rel_path.endswith('.css') {
                return JSONResponse(
                    content={'error': 'CSS file not found'}, status_code=404
                );
            }
            return JSONResponse(
                content={'error': 'Static file not found'}, status_code=404
            );
        }
        return _file_response(candidate);
    }

    def _health(request: Request) -> ServingResponse {
        return JSONResponse(content={'status': 'ok'});
    }

    def _graph_page(request: Request) -> ServingResponse {
        try {
            import jaclang.scale as scale_mod;
            template = Path(scale_mod.__file__).parent / 'templates' / 'graph.html';
            html_text = template.read_text(encoding='utf-8');
        } except (ImportError, OSError) as exc {
            return JSONResponse(
                content={
                    'error': (
                        "Graph visualizer template unavailable "
                        f"({type(exc).__name__}: {exc})"
                    )
                },
                status_code=503
            );
        }
        return HTMLResponse(content=html_text);
    }

    def _graph_data(request: Request) -> ServingResponse {
        import from jaclang.runtimelib.utils { collect_node_connections }
        username = _auth_or_guest(request);
        root_id = server.user_manager.get_root_id(username);
        if not root_id {
            return JSONResponse(
                content={'error': 'User root not found'}, status_code=404
            );
        }
        req_ctx = ExecutionContext(_parent=Jac.get_context());
        req_ctx.set_user_root(root_id);
        ctx_token = Jac.push_request_context(req_ctx);
        try {
            user_root = req_ctx.get_root();
            visited_nodes: set = set();
            connections: set = set();
            edge_ids: set = set();
            nodes: list[dict] = [];
            edges: list[dict] = [];
            collect_node_connections(user_root, visited_nodes, connections, edge_ids);
            nodes.append({'id': Jac.object_ref(user_root), 'label': 'root'});
            for node_arch in visited_nodes {
                if node_arch != user_root {
                    nodes.append(
                        {'id': Jac.object_ref(node_arch), 'label': repr(node_arch)}
                    );
                }
            }
            for (_, source_node, target_node, edge_arch) in connections {
                edge_data: dict = {
                    'from': Jac.object_ref(source_node),
                    'to': Jac.object_ref(target_node)
                };
                if repr(edge_arch) != 'GenericEdge()' {
                    edge_data['label'] = repr(edge_arch);
                }
                edges.append(edge_data);
            }
            return JSONResponse(
                content={'version': '1.0', 'nodes': nodes, 'edges': edges}
            );
        } finally {
            Jac.reset_request_context(ctx_token);
        }
    }

    def _client_js(request: Request) -> ServingResponse {
        try {
            js_code = Jac.get_client_js(server.introspector);
        } except RuntimeError as exc {
            return JSONResponse(content={'error': str(exc)}, status_code=500);
        }
        resp = ServingResponse(
            content=js_code, media_type='application/javascript; charset=utf-8'
        );
        resp.headers.set('Cache-Control', 'no-cache');
        return resp;
    }

    def _build_status(request: Request) -> ServingResponse {
        import from jaclang.runtimelib.hmr { get_build_status }
        return JSONResponse(content=get_build_status());
    }

    def _root_index(request: Request) -> ServingResponse {
        configured_root = config.serve.base_route_app if config else '';
        base_route_app = server.introspector.resolve_root_app(configured_root);
        if base_route_app {
            return _render_page_response(
                request,
                base_route_app,
                _query_args(request),
                server.introspector.spa_fallback_status('/')
            );
        }
        return JSONResponse(
            content={
                'message': 'Jac API Server',
                'endpoints': {
                    'POST /user/register': 'Create a new user',
                    'POST /user/login': 'Authenticate and get token',
                    'GET /user/info': 'Get user information (auth required)',
                    'GET /functions': 'List all available functions',
                    'GET /walkers': 'List all available walkers',
                    'GET /function/<name>': 'Get function signature',
                    'GET /walker/<name>': 'Get walker fields',
                    'POST /function/<name>': 'Call a function',
                    'POST /walker/<name>': 'Spawn a walker',
                    f'GET /{cl_route_prefix}/<name>': (
                        'Render HTML page for client function'
                    )
                }
            }
        );
    }

    def _cl_page(request: Request, name: str) -> ServingResponse {
        return _render_page_response(request, name, _query_args(request));
    }

    def _spa_or_asset(request: Request, rest: str) -> ServingResponse {
        path = f"/{rest}";
        if is_asset_request(path, cl_route_path) {
            return _serve_static(request, path[1:]);
        }
        configured_root = config.serve.base_route_app if config else '';
        base_route_app = server.introspector.resolve_root_app(configured_root);
        if base_route_app {
            return _render_page_response(
                request,
                base_route_app,
                {},
                server.introspector.spa_fallback_status(path)
            );
        }
        return JSONResponse(content={'error': 'Not found'}, status_code=404);
    }

    def _static_route(request: Request, file_path: str) -> ServingResponse {
        return _serve_static(request, file_path);
    }

    def _list_functions(request: Request) -> any {
        return server.introspection_handler.list_functions();
    }

    def _list_walkers(request: Request) -> any {
        return server.introspection_handler.list_walkers();
    }

    def _function_info(request: Request, name: str) -> any {
        server.introspector.load();
        if server.introspector.is_auth_required_for_function(name)
            and not _authenticate(request) {
            return JSONResponse(content={'error': 'Unauthorized'}, status_code=401);
        }
        return server.introspection_handler.get_function_info(name);
    }

    def _walker_info(request: Request, name: str) -> any {
        server.introspector.load();
        if server.introspector.is_auth_required_for_walker(name)
            and not _authenticate(request) {
            return JSONResponse(content={'error': 'Unauthorized'}, status_code=401);
        }
        return server.introspection_handler.get_walker_info(name);
    }

    def _user_info(request: Request) -> any {
        username = _authenticate(request);
        if not username {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Unauthorized - Authentication required',
                meta=Meta(extra={'http_status': 401})
            );
        }
        return server.auth_handler.get_user_info(_bearer_token(request));
    }

    def _protected(request: Request) -> any {
        if not _authenticate(request) {
            return JSONResponse(content={'error': 'Unauthorized'}, status_code=401);
        }
        return TransportResponse.success(
            data={'message': 'sucessful'}, meta=Meta(extra={'http_status': 200})
        );
    }

    def _register(request: Request) -> any {
        data = _read_data(request);
        if data is None {
            return JSONResponse(content={'error': 'Invalid JSON'}, status_code=400);
        }
        try {
            register_req = RegisterRequest.from_dict(data);
        } except ValueError as ve {
            return JSONResponse(content={'error': str(ve)}, status_code=400);
        }
        username_identity = None;
        for ident in register_req.identities {
            if ident.type == IdentityType.USERNAME.value {
                username_identity = ident;
                break;
            }
        }
        if username_identity is None {
            return JSONResponse(
                content={'error': "identity.type 'username' is required"},
                status_code=400
            );
        }
        return server.auth_handler.create_user(
            username_identity.value, register_req.credential.password
        );
    }

    def _login(request: Request) -> any {
        data = _read_data(request);
        if data is None {
            return JSONResponse(content={'error': 'Invalid JSON'}, status_code=400);
        }
        try {
            login_req = LoginRequest.from_dict(data);
        } except ValueError as ve {
            return JSONResponse(content={'error': str(ve)}, status_code=400);
        }
        if login_req.identity.type != IdentityType.USERNAME.value {
            return JSONResponse(
                content={'error': "identity.type must be 'username'"}, status_code=400
            );
        }
        return server.auth_handler.login(
            login_req.identity.value, login_req.credential.password
        );
    }

    def _call_function(request: Request, name: str) -> any {
        server.introspector.load();
        if server.introspector.is_auth_required_for_function(name) {
            username = _authenticate(request);
            if not username {
                return JSONResponse(content={'error': 'Unauthorized'}, status_code=401);
            }
        } else {
            username = _auth_or_guest(request);
        }
        data = _read_data(request);
        if data is None {
            return JSONResponse(content={'error': 'Invalid JSON'}, status_code=400);
        }
        return asyncio.run(
            server.execution_handler.call_function(name, data, username)
        );
    }

    def _spawn_walker(request: Request, name: str, node_id: str = '') -> any {
        server.introspector.load();
        if server.introspector.is_auth_required_for_walker(name) {
            username = _authenticate(request);
            if not username {
                return JSONResponse(content={'error': 'Unauthorized'}, status_code=401);
            }
        } else {
            username = _auth_or_guest(request);
        }
        data = _read_data(request);
        if data is None {
            return JSONResponse(content={'error': 'Invalid JSON'}, status_code=400);
        }
        fields = data | {'_jac_spawn_node': node_id};
        return asyncio.run(
            server.execution_handler.spawn_walker(name, fields, username)
        );
    }

    def _client_error(request: Request) -> any {
        data = _read_data(request);
        if data is None {
            return JSONResponse(content={'error': 'Invalid JSON'}, status_code=400);
        }
        message = data.get('message', '');
        if not message {
            return JSONResponse(
                content={'error': 'Missing required field: message'}, status_code=400
            );
        }
        import from jaclang.runtimelib.source_mapping {
            _error_rate_limiter,
            resolve_client_error_stacks,
            format_client_error_log
        }
        if not _error_rate_limiter.should_log(message) {
            return JSONResponse(content={'ok': True, 'throttled': True});
        }
        cfg = get_config();
        verbose = cfg.client_errors.verbose if cfg else False;
        (stack, component_stack) = resolve_client_error_stacks(
            server.base_path,
            data.get('stack', ''),
            data.get('componentStack', ''),
            verbose=verbose
        );
        log_parts = format_client_error_log(
            message,
            stack=stack,
            component_stack=component_stack,
            url=data.get('url', ''),
            source=data.get('source', '')
        );
        import logging;
        logging.getLogger('jaclang.client_errors').error('\n'.join(log_parts));
        return JSONResponse(content={'ok': True});
    }

    def _put_username(request: Request) -> any {
        token = _bearer_token(request);
        if not token {
            return JSONResponse(
                content={'error': 'Authentication required'}, status_code=401
            );
        }
        data = _read_data(request);
        if data is None {
            return JSONResponse(content={'error': 'Invalid JSON'}, status_code=400);
        }
        return server.auth_handler.update_username(
            data.get('current_username', ''), data.get('new_username', ''), token
        );
    }

    def _put_password(request: Request) -> any {
        token = _bearer_token(request);
        if not token {
            return JSONResponse(
                content={'error': 'Authentication required'}, status_code=401
            );
        }
        data = _read_data(request);
        if data is None {
            return JSONResponse(content={'error': 'Invalid JSON'}, status_code=400);
        }
        return server.auth_handler.update_password(
            data.get('username', ''),
            data.get('current_password', ''),
            data.get('new_password', ''),
            token
        );
    }

    def _not_found(request: Request) -> any {
        return JSONResponse(content={'error': 'Not found'}, status_code=404);
    }

    def _ep(
        method: HTTPMethod,
        path: str,
        cb: any,
        params: (list | None) = None,
        in_schema: bool = False
    ) {
        app.add_endpoint(
            JEndPoint(
                method=method,
                path=path,
                callback=cb,
                parameters=params,
                include_in_schema=in_schema,
                forward_undeclared_query_params=False
            )
        );
    }
    name_param = [APIParameter(name='name', kind=ParameterType.PATH)];
    _ep(HTTPMethod.GET, '/healthz', _health);
    _ep(HTTPMethod.GET, '/healthz/live', _health);
    _ep(HTTPMethod.GET, '/healthz/ready', _health);
    if not server.introspector.has_client_route('/graph') {
        _ep(HTTPMethod.GET, '/graph', _graph_page);
    }
    _ep(HTTPMethod.GET, '/graph/data', _graph_data);
    _ep(HTTPMethod.GET, '/static/client.js', _client_js);
    _ep(HTTPMethod.GET, '/__build_status', _build_status);
    _ep(
        HTTPMethod.GET,
        '/static/{file_path:path}',
        _static_route,
        params=[APIParameter(name='file_path', kind=ParameterType.PATH)]
    );
    _ep(HTTPMethod.GET, '/', _root_index);
    _ep(HTTPMethod.GET, f"/{cl_route_prefix}/{{name}}", _cl_page, params=name_param);
    _ep(HTTPMethod.GET, '/functions', _list_functions, in_schema=True);
    _ep(HTTPMethod.GET, '/walkers', _list_walkers, in_schema=True);
    _ep(
        HTTPMethod.GET,
        '/function/{name}',
        _function_info,
        params=name_param,
        in_schema=True
    );
    _ep(
        HTTPMethod.GET,
        '/walker/{name}',
        _walker_info,
        params=name_param,
        in_schema=True
    );
    _ep(HTTPMethod.GET, '/user/info', _user_info, in_schema=True);
    _ep(HTTPMethod.GET, '/protected', _protected);
    _ep(
        HTTPMethod.GET,
        '/{rest:path}',
        _spa_or_asset,
        params=[APIParameter(name='rest', kind=ParameterType.PATH)]
    );
    _ep(HTTPMethod.POST, '/user/register', _register, in_schema=True);
    _ep(HTTPMethod.POST, '/user/login', _login, in_schema=True);
    _ep(
        HTTPMethod.POST,
        '/function/{name}',
        _call_function,
        params=name_param,
        in_schema=True
    );
    _ep(
        HTTPMethod.POST,
        '/walker/{name}',
        _spawn_walker,
        params=name_param,
        in_schema=True
    );
    _ep(
        HTTPMethod.POST,
        '/walker/{name}/{node_id}',
        _spawn_walker,
        params=[
            APIParameter(name='name', kind=ParameterType.PATH),
            APIParameter(name='node_id', kind=ParameterType.PATH)
        ],
        in_schema=True
    );

    try {
        _named_walkers = list(server.introspector.get_walkers());
        _named_functions = list(server.introspector.get_functions());
    } except Exception {
        _named_walkers = [];
        _named_functions = [];
    }
    try {
        _all_targets = dict(server.introspector.get_walkers());
        _all_targets.update(server.introspector.get_functions());
        _spec_carriers = [
            n
            for (n, t) in _all_targets.items()
            if t?.restspec is not None
        ];
        if _spec_carriers {
            import logging;
            logging.getLogger(__name__).warning(
                "@restspec is ignored by the core server: "
                f"{', '.join(sorted(_spec_carriers))} will serve at the "
                "default /walker/ and /function/ POST routes only. Custom "
                "methods, paths, webhooks, and websockets need the scale "
                "serving stack (`jac start`)."
            );
        }
    } except Exception {
        ;
    }
    for _w_name in _named_walkers {
        def _mk_walker_ep(bound: str) -> Callable {
            def _spawn_named(request: Request, node_id: str = '') -> any {
                return _spawn_walker(request, bound, node_id);
            }
            return _spawn_named;
        }
        _named_walker = _mk_walker_ep(_w_name);
        _ep(HTTPMethod.POST, f'/walker/{_w_name}', _named_walker, in_schema=True);
        _ep(
            HTTPMethod.POST,
            f'/walker/{_w_name}/{{node_id}}',
            _named_walker,
            params=[APIParameter(name='node_id', kind=ParameterType.PATH)],
            in_schema=True
        );
    }
    for _f_name in _named_functions {
        def _mk_function_ep(bound: str) -> Callable {
            def _call_named(request: Request) -> any {
                return _call_function(request, bound);
            }
            return _call_named;
        }
        _ep(
            HTTPMethod.POST,
            f'/function/{_f_name}',
            _mk_function_ep(_f_name),
            in_schema=True
        );
    }
    _ep(HTTPMethod.POST, '/cl/__error__', _client_error);
    _ep(
        HTTPMethod.POST,
        '/{rest:path}',
        _not_found,
        params=[APIParameter(name='rest', kind=ParameterType.PATH)]
    );
    _ep(HTTPMethod.PUT, '/user/username', _put_username, in_schema=True);
    _ep(HTTPMethod.PUT, '/user/password', _put_password, in_schema=True);
    _ep(
        HTTPMethod.PUT,
        '/{rest:path}',
        _not_found,
        params=[APIParameter(name='rest', kind=ParameterType.PATH)]
    );
    register_docs_endpoints(app);
    return app;
}

impl JacAPIServer.load_module(force_reload: bool = False) -> None {
    self.introspector.load(force_reload);
}

impl JacAPIServer.module.getter -> object {
    return self.introspector._module;
}

impl JacAPIServer.get_functions -> dict[str, Callable[(..., Any)]] {
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
    import from jaclang.runtimelib { sv_client }
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

impl JacAPIServer.start(
    dev: bool = False,
    no_client: bool = False,
    on_ready: Callable[[int], None] | None = None
) -> None {
    import from pathlib { Path }
    self.introspector.load();
    self._ensure_sv_siblings();

    for (name, walker_cls) in self.introspector._walkers.items() {
        if walker_cls?.schedule_spec {
            self.scheduler.register(name, walker_cls, walker_cls.schedule_spec, True);
        }
    }
    for (name, func) in self.introspector._functions.items() {
        if func?.schedule_spec {
            self.scheduler.register(name, func, func.schedule_spec, False);
        }
    }
    if self.scheduler.has_pending() {
        console.print("Scheduler started");
        self.scheduler.start();
    }

    bundle_error = None;
    if not dev and not no_client {
        client_exports = self.introspector._client_manifest.get('exports', []);
        if client_exports {
            try {
                config = get_config();

                if config {
                    dist_dir = config.get_client_dir() / 'dist';
                } else {
                    dist_dir = Path(self.base_path) / '.jac' / 'client' / 'dist';
                }

                bundle_exists = dist_dir.exists() and any(dist_dir.glob('client.*.js'));
                if bundle_exists {
                    console.print(
                        "  ✔ Client bundle found (rebuilt on first request if stale)",
                        style="success"
                    );
                } else {
                    self.introspector.ensure_bundle();
                }
            } except Exception as e {
                bundle_error = str(e);
            }
        }
    }
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    configured_root = config.serve.base_route_app if config else "";
    base_route_app = self.introspector.resolve_root_app(configured_root);
    if self.port <= 0 {
        raise RuntimeError(
            "Cannot start server: no socket was bound (test mode, port=0)"
        );
    }
    self.app = self.build_app();
    serving = ServingServer(app=self.app, host='0.0.0.0', port=self.port);
    self.server = serving;

    def _announce(bound_port: int) {
        self.port = bound_port;
        console.print(f"Jac API Server running on http://0.0.0.0:{bound_port}");
        console.print(f"Module: {self.module_name}");
        console.print('\nAvailable endpoints:');
        console.print('  POST /user/register - Create a new user');
        console.print('  POST /user/login - Login and get auth token');
        console.print(
            '  GET  /user/info - Get current user information (auth required)'
        );
        console.print('  PUT  /user/username - Update username (auth required)');
        console.print('  PUT  /user/password - Update password (auth required)');
        console.print('  GET /functions - List all functions');
        console.print('  GET /walkers - List all walkers');
        console.print('  GET /function/<name> - Get function signature');
        console.print('  GET /walker/<name> - Get walker info');
        console.print('  POST /function/<name> - Call a function');
        console.print('  POST /walker/<name> - Spawn a walker');
        console.print(
            f'  GET /{cl_route_prefix}/<name> - Render HTML page for client function'
        );
        if base_route_app {
            origin = "configured" if configured_root else "inferred";
            console.print(f'\nBase route (/) {origin} to serve: {base_route_app}');
        }
        console.print('\nPress Ctrl+C to stop the server');
        if bundle_error {
            import sys;
            formatted_error = Jac.format_build_error(
                error_output=bundle_error,
                project_dir=Path(self.base_path),
                config=config
            );
            console.print(file=sys.stderr);
            console.print(formatted_error, file=sys.stderr);
            console.print(file=sys.stderr);
            console.warning(
                'Client pages will not be available until this is fixed.', emoji=True
            );
            console.print(file=sys.stderr);
            console.info(
                f'If it still doesn\'t work, ask for help at {JAC_DISCORD_URL}',
                emoji=True
            );
            console.print(file=sys.stderr);
        }
        if on_ready {
            try {
                on_ready(bound_port);
            } except TypeError {
                on_ready();
            }
        }
    }
    try {
        serving.run(on_ready=_announce);
        console.print('\nShutting down server...');
    } finally {
        self.scheduler.stop();
    }
}


impl print_endpoint_docs(server: JacAPIServer) -> None {
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
    def format_param(name: str, info: dict[(str, Any)]) -> str {
        req = 'required' if info['required'] else 'optional';
        `default = f", default: {info['default']}" if info.get('default') else '';
        return f"{name}: {info['type']} ({req}{default})";
    }
    console.print(('\n' + ('=' * 80)));
    console.print(f"JAC API SERVER - {server.module_name}");
    console.print(('=' * 80));
    section('AUTHENTICATION');
    endpoint(
        'POST',
        '/user/register',
        'Create new user account',
        'Body: { "username": str, "password": str }'
    );
    endpoint(
        'POST',
        '/user/login',
        'Authenticate and get token',
        'Body: { "username": str, "password": str }'
    );
    endpoint(
        'GET',
        '/user/info',
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
            params = [format_param(n, i) for (n, i) in sig['parameters'].items()];
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
            fields = [format_param(n, i) for (n, i) in info['fields'].items()];
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
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    configured_root = config.serve.base_route_app if config else "";
    base_route_app = server.introspector.resolve_root_app(configured_root);
    section('CLIENT PAGES', 'Public');
    if client_exports {
        funcs_list = ', '.join(sorted(client_exports)[:8]);
        if (len(client_exports) > 8) {
            funcs_list += f" (+{(len(client_exports) - 8)} more)";
        }
        console.print(f"Available ({len(client_exports)}): {funcs_list}");
        endpoint(
            'GET',
            f'/{cl_route_prefix}/<name>',
            'Render HTML for client function',
            f'Example: /{cl_route_prefix}/App?arg1=value1'
        );
    } else {
        console.print(
            "\nNo client functions. Define with 'cl def' for browser-side rendering."
        );
    }
    section('STATIC');
    if base_route_app {
        endpoint('GET', '/', f'Serves client app: {base_route_app}');
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
