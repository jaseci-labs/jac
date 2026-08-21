import from "./bun_store.js" {
    __jacCommitGraph,
    __jacEnsureRoot,
    __jacInitBunStore,
    __jacInstallOspPersistHooks,
    __jacServerSpawnWalker
}

async def parseJsonBody(req: any) -> (dict | None) {
    try {
        return await req.json();
    } except Exception {
        return None;
    }
}

def deserializeWireValue(val: any) -> any {
    if val is None or type(val) != 'object' {
        return val;
    }
    if Array.isArray(val) {
        mapped: list = [];
        for item in val {
            mapped.push(deserializeWireValue(item));
        }
        return mapped;
    }
    if val.__type__ and val.__type__.__from_wire {
        return val.__type__.__from_wire(val);
    }
    if val.__type__ {
        ctor = globalThis[val.__type__];
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
        mapped: list = [];
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
            if not key.startsWith('_') {
                out[key] = serializeApiValue(val[key]);
            }
        }
        if val.constructor and val.constructor.name {
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

def okEnvelope(data: any) -> dict {
    return {'ok': True, 'data': data};
}

def errorEnvelope(message: str) -> dict {
    return {'ok': False, 'error': {'message': message}};
}

async def execWalker(walkerCls: any, fields: dict) -> any {
    inst = Object.assign(new(walkerCls), fields);
    return await __jacServerSpawnWalker(inst);
}

async def _preparePersistContext {
    __jacInstallOspPersistHooks();
    await __jacInitBunStore();
    __jacEnsureRoot();
}

async def handleFunctionCall(
    req: any, name: str, handlers: dict, params: (dict | None) = None
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
        result = Reflect.apply(fn, null, call_args);
        if result and type(result) == 'object' and result.then {
            result = await result;
        }
        await __jacCommitGraph();
        return okEnvelope(finalizeCallResponse(result, []));
    } except Exception as e {
        msg = e.message or String(e);
        return errorEnvelope(msg);
    }
}

async def handleWalkerSpawn(req: any, name: str, nodeId: str, handlers: dict) -> dict {
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
        msg = e.message or String(e);
        return errorEnvelope(msg);
    }
}

def startBunServer(opts: dict) {
    project = opts.project or 'jac-service';
    walkers = opts.walkers or [];
    functions = opts.functions or [];
    handlers = opts.handlers or {};
    params = opts.params or {};
    port = Number(opts.port or 8000);
    walkerFns = handlers.walkers or {};
    functionFns = handlers.functions or {};
    restspec = handlers.restspec or [];

    async def fetchHandler(req: any) -> any {
        url = new(URL, req.url);
        path = url.pathname;
        method = req.method;

        if method == 'GET' and path == '/functions' {
            return Response.json(functions);
        }
        if method == 'GET' and path == '/walkers' {
            return Response.json(walkers);
        }
        if method == 'GET' and (path == '/healthz' or path == '/__health') {
            return Response.json(
                {'project': project, 'walkers': walkers, 'functions': functions}
            );
        }

        fnMatch = path.match('^/function/([^/]+)$');
        if fnMatch and method == 'POST' {
            name = decodeURIComponent(fnMatch[1]);
            payload = await handleFunctionCall(req, name, functionFns, params);
            return Response.json(payload);
        }

        walkerMatch = path.match('^/walker/([^/]+)(?:/([^/]+))?$');
        if walkerMatch and method == 'POST' {
            name = decodeURIComponent(walkerMatch[1]);
            nodeId = '';
            if walkerMatch[2] {
                nodeId = decodeURIComponent(walkerMatch[2]);
            }
            payload = await handleWalkerSpawn(req, name, nodeId, walkerFns);
            return Response.json(payload);
        }

        for carrier in restspec {
            spec = carrier.fn?.restspec;
            if not spec {
                continue;
            }
            specPath = String(spec.path or '');
            if specPath == '' {
                continue;
            }
            if not specPath.startsWith('/') {
                specPath = '/' + specPath;
            }
            specMethod = String(spec.method or 'POST').toUpperCase();
            if path == specPath and method == specMethod {
                carrier_handlers: dict = {};
                carrier_handlers[carrier.name] = carrier.handler;
                payload = await handleFunctionCall(
                    req, carrier.name, carrier_handlers, params
                );
                return Response.json(payload);
            }
        }

        return new(Response, 'Not Found', {status: 404});
    }

    Bun.serve({port: port, hostname: '0.0.0.0', fetch: fetchHandler});
    console.log(f"Bun sv service '{project}' listening on http://0.0.0.0:{port}");
}
