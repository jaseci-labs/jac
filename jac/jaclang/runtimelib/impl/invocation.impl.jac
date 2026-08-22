import asyncio;
import os;
import sys;
import traceback;
import from inspect { isgenerator }
import from typing { AsyncGenerator, Generator }
import from jaclang { JacRuntime as Jac }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.jac0core.ext_registry { base_stem }
import from jaclang.runtimelib.server {
    ExecutionManager,
    ModuleIntrospector,
    UserManager
}
import from jaclang.runtimelib.transport { TransportResponse, Meta }


def _http_status(response: TransportResponse, fallback: int = 200) -> int {
    if response.meta and response.meta.extra {
        return int(response.meta.extra.get("http_status", fallback));
    }
    return fallback if response.ok else 500;
}


def _request_id(response: TransportResponse) -> str {
    if response.meta and response.meta.request_id {
        return response.meta.request_id;
    }
    return new_request_id();
}


impl InvocationResult.from_transport(response: TransportResponse) -> InvocationResult {
    stream = None;
    is_stream = False;
    if response.meta and response.meta.extra {
        if response.meta.extra.get("streaming") {
            is_stream = True;
            stream = response.meta.extra.get("stream");
        }
    }
    return InvocationResult(
        ok=response.ok,
        data=response.data,
        error=response.error,
        http_status=_http_status(response),
        request_id=_request_id(response),
        is_stream=is_stream,
        stream=stream
    );
}


impl InvocationResult.to_transport -> TransportResponse {
    meta = Meta(
        request_id=self.request_id or new_request_id(),
        extra={"http_status": self.http_status}
    );
    if self.is_stream and self.stream is not None {
        meta.extra["streaming"] = True;
        meta.extra["stream"] = self.stream;
    }
    if self.ok {
        return TransportResponse.success(data=self.data, meta=meta);
    }
    if self.error {
        return TransportResponse.fail(
            code=self.error.code,
            message=self.error.message,
            details=self.error.details,
            meta=meta
        );
    }
    return TransportResponse.fail(
        code="EXECUTION_ERROR", message="Invocation failed", meta=meta
    );
}


impl InvocationResult.to_body -> dict {
    body: dict = {"ok": self.ok};
    if self.ok {
        body["data"] = self.data;
        return body;
    }
    err = self.error;
    code = err.code if err is not None else "EXECUTION_ERROR";
    message = err.message if err is not None else "Invocation failed";
    envelope: dict = {"code": code, "message": message};
    if err is not None and err.details is not None {
        envelope["details"] = err.details;
    }
    body["error"] = envelope;
    return body;
}


def _normalize_execution_result(result: any, request_id: str) -> TransportResponse {
    if isgenerator(result) or isinstance(result, AsyncGenerator) {
        return TransportResponse.success(
            data=None,
            meta=Meta(
                request_id=request_id,
                extra={"http_status": 200, "streaming": True, "stream": result}
            )
        );
    }
    if isinstance(result, dict) and "error" in result {
        code = "EXECUTION_ERROR";
        http_status = 500;
        if result.get("error_code") == "write_conflict" {
            code = "OCC_CONFLICT";
            http_status = int(result.get("http_status", 409));
        }
        details = result.get("traceback") if "traceback" in result else None;
        return TransportResponse.fail(
            code=code,
            message=str(result.get("error", "Execution failed")),
            details=details,
            meta=Meta(request_id=request_id, extra={"http_status": http_status})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(request_id=request_id, extra={"http_status": 200})
    );
}


def _validate_fields(
    field_meta: dict, fields: dict, drop_unknown: bool
) -> ValidationOutcome {
    for (fname, meta) in field_meta.items() {
        if fname == "_jac_spawn_node" {
            continue;
        }
        if isinstance(meta, dict) and meta.get("required") and fname not in fields {
            return ValidationOutcome(error=f"Missing required field '{fname}'");
        }
    }
    coerced: dict = {};
    for (fname, value) in fields.items() {
        if fname == "_jac_spawn_node" {
            coerced[fname] = value;
            continue;
        }
        if fname not in field_meta {
            if drop_unknown {
                continue;
            }
            coerced[fname] = value;
            continue;
        }
        meta = field_meta[fname];
        type_name = meta.get("type", "Any") if isinstance(meta, dict) else "Any";
        (ok, cv) = coerce_scalar(type_name, value);
        if not ok {
            return ValidationOutcome(
                error=f"Field '{fname}' expected type {type_name}"
            );
        }
        coerced[fname] = cv;
    }
    return ValidationOutcome(fields=coerced);
}


def _validation_error(message: str, request_id: str) -> InvocationResult {
    return InvocationResult.from_transport(
        TransportResponse.fail(
            code="VALIDATION_ERROR",
            message=message,
            meta=Meta(request_id=request_id, extra={"http_status": 422})
        )
    );
}


def _ensure_guest_user(user_manager: any) -> None {
    if user_manager.get_root_id(Con.GUEST.value) is not None {
        return;
    }
    if hasattr(user_manager, "create_internal_user") {
        user_manager.create_internal_user(Con.GUEST.value, "__no_password__");
    } elif not user_manager.user_exists(Con.GUEST.value) {
        user_manager.create_user(Con.GUEST.value, "__no_password__");
    }
}


impl InvocationDispatcher.invoke(request: InvocationRequest) -> InvocationResult {
    request_id = new_request_id();
    self.introspector.load();

    if request.kind == InvocationKind.WALKER {
        walkers = self.introspector.get_walkers();
        if request.name not in walkers {
            return InvocationResult.from_transport(
                TransportResponse.fail(
                    code="NOT_FOUND",
                    message=f"Walker '{request.name}' not found",
                    meta=Meta(request_id=request_id, extra={"http_status": 404})
                )
            );
        }
        requires_auth = self.introspector.is_auth_required_for_walker(request.name);
        target: any = walkers[request.name];
        field_meta = self.introspector.introspect_walker(target).get("fields", {});
        drop_unknown = True;
    } else {
        functions = self.introspector.get_functions();
        if request.name not in functions {
            return InvocationResult.from_transport(
                TransportResponse.fail(
                    code="NOT_FOUND",
                    message=f"Function '{request.name}' not found",
                    meta=Meta(request_id=request_id, extra={"http_status": 404})
                )
            );
        }
        requires_auth = self.introspector.is_auth_required_for_function(request.name);
        target = functions[request.name];
        field_meta = self.introspector.introspect_callable(target).get(
            "parameters", {}
        );
        drop_unknown = False;
    }

    username: (str | None) = None;
    if request.identity_prevalidated {
        username = request.resolved_user;
        if request.token and username is None {
            return InvocationResult.from_transport(
                TransportResponse.fail(
                    code="UNAUTHORIZED",
                    message="Unauthorized",
                    meta=Meta(request_id=request_id, extra={"http_status": 401})
                )
            );
        }
    } elif request.token {
        username = self.user_manager.validate_token(request.token);
        if not username {
            return InvocationResult.from_transport(
                TransportResponse.fail(
                    code="UNAUTHORIZED",
                    message="Unauthorized",
                    meta=Meta(request_id=request_id, extra={"http_status": 401})
                )
            );
        }
    }
    if requires_auth and not username {
        return InvocationResult.from_transport(
            TransportResponse.fail(
                code="UNAUTHORIZED",
                message="Unauthorized",
                meta=Meta(request_id=request_id, extra={"http_status": 401})
            )
        );
    }
    effective_user = username or Con.GUEST.value;
    if effective_user == Con.GUEST.value {
        _ensure_guest_user(self.user_manager);
    }

    validation = _validate_fields(field_meta, dict(request.fields), drop_unknown);
    if validation.error is not None {
        return _validation_error(validation.error, request_id);
    }
    coerced_fields = validation.fields;

    if request.kind == InvocationKind.WALKER {
        if request.node_id {
            coerced_fields["_jac_spawn_node"] = request.node_id;
        }
        result = await self.execution_manager.spawn_walker(
            target, coerced_fields, effective_user
        );
    } else {
        result = await self.execution_manager.execute_function(
            target, coerced_fields, effective_user
        );
    }

    return InvocationResult.from_transport(
        _normalize_execution_result(result, request_id)
    );
}


impl prepare_invocation_runtime(
    jac_file: str, graph_path: str
) -> PreparedInvocationRuntime {
    (base, _) = os.path.split(jac_file);
    base = base or "./";
    mod = base_stem(jac_file);
    os.makedirs(graph_path, exist_ok=True);
    Jac.set_base_path(graph_path);

    prior_ctx = Jac.exec_ctx;
    mach = Jac.create_j_context(
        user_root=None, base_path_dir=graph_path, full_target_path=jac_file
    );
    Jac.set_context(mach);
    try {
        if mod in Jac.loaded_modules {
            del Jac.loaded_modules[mod];
        }
        if mod in sys.modules {
            del sys.modules[mod];
        }
        Jac.jac_import(target=mod, base_path=base, lng="jac");

        user_manager = UserManager(base_path=graph_path);
        _ensure_guest_user(user_manager);

        def _shared_root_id -> (str | None) {
            return user_manager.get_root_id(Con.GUEST.value);
        }
        Jac.set_shared_root_resolver(_shared_root_id);

        introspector = ModuleIntrospector(mod, graph_path);
        introspector.load();
        execution_manager = ExecutionManager(
            base_path=graph_path, user_manager=user_manager
        );
        dispatcher = InvocationDispatcher(
            introspector=introspector,
            execution_manager=execution_manager,
            user_manager=user_manager
        );
        return PreparedInvocationRuntime(
            dispatcher=dispatcher,
            introspector=introspector,
            execution_manager=execution_manager,
            user_manager=user_manager,
            module_name=mod,
            _prior_ctx=prior_ctx
        );
    } except Exception {
        if mod in Jac.loaded_modules {
            del Jac.loaded_modules[mod];
        }
        if mod in sys.modules {
            del sys.modules[mod];
        }
        Jac.set_shared_root_resolver(None);
        Jac.set_context(prior_ctx);
        mach.close();
        raise;
    }
}


impl PreparedInvocationRuntime.close{
    Jac.set_shared_root_resolver(None);
    if self.user_manager is not None {
        try {
            self.user_manager.close();
        } except Exception as e {
            sys.stderr.write(
                "invocation runtime: user_manager close failed: " + str(e) + "\n"
            );
        }
    }
    Jac.set_context(self._prior_ctx);
    self._prior_ctx = None;
}


impl _invoke_sync(
    dispatcher: InvocationDispatcher, request: InvocationRequest
) -> InvocationResult {
    try {
        asyncio.get_running_loop();
    } except RuntimeError {
        disp: any = dispatcher;
        return asyncio.run(disp.invoke(request));
    }
    raise RuntimeError(
        "_invoke_sync cannot be called from a running event loop; use await dispatcher.invoke()"
    );
}
