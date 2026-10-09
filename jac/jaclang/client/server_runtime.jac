import from "./bun_store.js" {
    __jacCommitGraph,
    __jacEnsureRoot,
    __jacInitBunStore,
    __jacInstallOspPersistHooks,
    __jacServerSpawnWalker
}

async def parseJsonBody(req: any) -> any {
    try {
        text = await req.text();

        if not text or not text.strip() {
            empty: dict = {};
            return empty;
        }
        return JSON.parse(text);
    } except Exception {
        return None;
    }
}

def deserializeWireValue(val: any) -> any {
    if val is None or type(val) != 'object' {
        return val;
    }
    if Array.isArray(val) {
        mapped: any = [];
        for item in val {
            mapped.push(deserializeWireValue(item));
        }
        return mapped;
    }
    gtab: any = globalThis;
    if val.__type__ and val.__type__.__from_wire {
        return val.__type__.__from_wire(val);
    }
    if val.__type__ {
        ctor: any = gtab[val.__type__];
        if ctor and ctor.__from_wire {
            return ctor.__from_wire(val);
        }
    }
    return val;
}

def deserializeWireArgs(args: dict) -> dict {
    out: dict = {};
    for key in Object.keys(args) {
        out[key] = deserializeWireValue(args[key]);
    }
    return out;
}

def serializeApiValue(val: any) -> any {
    if val is None {
        return None;
    }
    t = type(val);
    if t == 'string' or t == 'number' or t == 'boolean' {
        return val;
    }
    if Array.isArray(val) {
        mapped: any = [];
        for item in val {
            mapped.push(serializeApiValue(item));
        }
        return mapped;
    }
    if val.__to_wire {
        return val.__to_wire();
    }
    if type(val) == 'object' {
        out: dict = {};
        for key in Object.keys(val) {
            if key[:1] != '_' {
                out[key] = serializeApiValue(val[key]);
            }
        }

        if (
            val.constructor
            and val.constructor.name
            and val.constructor.name != 'Object'
        ) {
            out['_jac_type'] = val.constructor.name;
            out['_jac_archetype'] = 'walker';
        }
        return out;
    }
    return String(val);
}

def finalizeCallResponse(result: any, reports: any = []) -> dict {
    return {'result': serializeApiValue(result), 'reports': serializeApiValue(reports)};
}

def envelopeResponse(payload: any) -> any {
    status: any = 200;
    if not payload.ok {
        status = 500;
    }
    resp: any = Response;
    return resp.json(payload, {status: status});
}

def okEnvelope(data: any) -> dict {
    return {'ok': True, 'type': 'response', 'data': data, 'error': None};
}

def _error_text(e: any) -> str {
    return e.message or String(e);
}

def errorEnvelope(message: any) -> dict {
    return {
        'ok': False,
        'type': 'error',
        'data': None,
        'error': {'code': 'EXECUTION_ERROR', 'message': message, 'details': None}
    };
}

async def:pub execWalker(walkerCls: any, fields: dict) -> any {
    inst = Object.assign(new(walkerCls), fields);
    return await __jacServerSpawnWalker(inst);
}

async def _preparePersistContext {
    __jacInstallOspPersistHooks();
    await __jacInitBunStore();
    __jacEnsureRoot();
}

async def handleFunctionCall(
    req: any, name: str, handlers: any, params: any = None
) -> dict {
    fn = handlers[name];
    if not fn {
        return errorEnvelope(f"Unknown function '{name}'");
    }
    body = await parseJsonBody(req);
    if body is None {
        return errorEnvelope('Invalid JSON');
    }
    args = deserializeWireArgs(body);
    call_args: list = [];
    if params is not None and name in params {
        for pname in params[name] {
            if pname in args {
                call_args.append(args[pname]);
            } else {
                call_args.append(null);
            }
        }
    } else {
        call_args = [args];
    }
    try {
        await _preparePersistContext();
        refl: any = Reflect;
        result = refl.apply(fn, null, call_args);
        if result and type(result) == 'object' and result.then {
            result = await result;
        }
        await __jacCommitGraph();
        return okEnvelope(finalizeCallResponse(result, []));
    } except Exception as e {
        return errorEnvelope(_error_text(e));
    }
}

async def handleWalkerSpawn(req: any, name: str, nodeId: str, handlers: any) -> dict {
    spawnFn = handlers[name];
    if not spawnFn {
        return errorEnvelope(f"Unknown walker '{name}'");
    }
    body = await parseJsonBody(req);
    if body is None {
        return errorEnvelope('Invalid JSON');
    }
    fields = deserializeWireArgs(body);
    if nodeId {
        fields['_jac_spawn_node'] = nodeId;
    }
    try {
        await _preparePersistContext();
        result = await spawnFn(fields);
        await __jacCommitGraph();
        reports = result?.reports or [];
        if result and result.result is not None {
            payload = finalizeCallResponse(result.result, reports);
        } else {
            payload = finalizeCallResponse(result, reports);
        }
        return okEnvelope(payload);
    } except Exception as e {
        return errorEnvelope(_error_text(e));
    }
}

def:pub startBunServer(opts: any) {
    project = opts.project or 'jac-service';
    walkers = opts.walkers or [];
    functions = opts.functions or [];
    handlers: any = opts.handlers or {};
    params: any = opts.params or {};
    port = Number(opts.port or 8000);
    walkerFns: any = handlers.walkers or {};
    functionFns: any = handlers.functions or {};
    restspec: any = handlers.restspec or [];

    async def fetchHandler(req: any) -> any {
        ucls: any = URL;
        url: any = new(ucls, req.url);
        path = url.pathname;
        method = req.method;

        resp: any = Response;
        if method == 'GET' and path == '/functions' {
            return resp.json(functions);
        }
        if method == 'GET' and path == '/walkers' {
            return resp.json(walkers);
        }
        if method == 'GET' and (path == '/healthz' or path == '/__health') {
            return resp.json(
                {'project': project, 'walkers': walkers, 'functions': functions}
            );
        }

        re1: any = new(RegExp, '^/function/([^/]+)$');
        fnMatch = re1.exec(path);
        if fnMatch and method == 'POST' {
            dec: any = decodeURIComponent;
            name = dec(fnMatch[1]);
            payload = await handleFunctionCall(req, name, functionFns, params);
            return envelopeResponse(payload);
        }

        re2: any = new(RegExp, '^/walker/([^/]+)(?:/([^/]+))?$');
        walkerMatch = re2.exec(path);
        if walkerMatch and method == 'POST' {
            dec2: any = decodeURIComponent;
            name = dec2(walkerMatch[1]);
            nodeId = '';
            if walkerMatch[2] {
                nodeId = dec2(walkerMatch[2]);
            }
            payload = await handleWalkerSpawn(req, name, nodeId, walkerFns);
            return envelopeResponse(payload);
        }

        for carrier in restspec {
            spec = carrier.fn?.restspec;
            if not spec {
                continue;
            }
            specPath: str = str(spec.path or '');
            if specPath == '' {
                continue;
            }
            if specPath[0:1] != '/' {
                specPath = '/' + specPath;
            }
            specMethod: str = str(spec.method or 'POST').upper();
            if path == specPath and method == specMethod {
                carrier_handlers: dict = {};
                carrier_handlers[carrier.name] = carrier.handler;
                payload = await handleFunctionCall(
                    req, carrier.name, carrier_handlers, params
                );
                return envelopeResponse(payload);
            }
        }

        return new(resp, 'Not Found', {status: 404});
    }

    bun: any = Bun;
    bun.serve({port: port, hostname: '0.0.0.0', fetch: fetchHandler});
    console.log(f"Bun sv service '{project}' listening on http://0.0.0.0:{port}");
}
