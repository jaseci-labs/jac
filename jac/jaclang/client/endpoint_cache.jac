def:pub __getEndpointEffects -> dict {
    effects: any = globalThis.__jacEndpointEffects__;
    if effects {
        return effects;
    }
    seed_fn: any = globalThis.__jacSeedEndpointEffects__;
    if seed_fn {
        effects = seed_fn();
        globalThis.__jacEndpointEffects__ = effects;
        return effects;
    }
    initText: (str | None) = None;

    if globalThis.document {
        try {
            initEl = document.getElementById("__jac_init__");
            if isinstance(initEl, HTMLElement) {
                initText = initEl.textContent;
            }
        } except Exception as e {
            console.warn("[jac-client] Failed to find __jac_init__ element:", e);
        }
    }
    if initText {
        try {
            data: any = JSON.parse(initText);
            effects = data["endpointEffects"] or {};
        } except Exception as e {
            console.warn(
                "[jac-client] Failed to parse __jac_init__ data, using empty effects:",
                e
            );
            effects = {};
        }
    } else {
        effects = {};
    }
    globalThis.__jacEndpointEffects__ = effects;
    return effects;
}

def:pub __getCacheState -> dict {
    state: any = globalThis.__jacCacheState__;
    if not state {
        state = {
            "cache": {},
            "order": [],
            "pending": {},
            "generations": {},
            "epoch": 0,
            "activeWrites": 0,
            "config": {"maxEntries": 500, "defaultTtlMs": 60000}
        };
        globalThis.__jacCacheState__ = state;
    }
    return state;
}

def:pub __isFresh(`entry: dict) -> bool {
    if not `entry {
        return False;
    }
    age = Date.now() - `entry["timestamp"];
    return age < `entry["ttl"];
}

def:pub __cacheGet(key: str) -> dict | None {
    state = __getCacheState();
    `entry = state["cache"][key];
    if not `entry {
        return None;
    }

    idx = state["order"].indexOf(key);
    if idx > -1 {
        state["order"].splice(idx, 1);
    }
    state["order"].push(key);
    return `entry;
}

def:pub __cacheSet(key: str, data: any, ttl: int) {
    state = __getCacheState();

    if state["cache"][key] {
        idx = state["order"].indexOf(key);
        if idx > -1 {
            state["order"].splice(idx, 1);
        }
    }

    while len(state["order"]) >= state["config"]["maxEntries"] {
        __evictOldest();
    }
    state["cache"][key] = {"data": data, "timestamp": Date.now(), "ttl": ttl};
    state["order"].push(key);
}

def:pub __evictOldest {
    state = __getCacheState();
    if len(state["order"]) > 0 {
        oldest = state["order"].shift();
        if oldest and state["cache"][oldest] {
            Reflect.deleteProperty(state["cache"], oldest);
        }
    }
}

def:pub __overlaps(list1: list[str], list2: list[str]) -> bool {
    if "*" in list1 or "*" in list2 {
        return bool(list1) and bool(list2);
    }
    for item in list1 {
        if item in list2 {
            return True;
        }
    }
    return False;
}

def:pub __invalidateEndpoint(endpoint_key: str) {
    state = __getCacheState();
    state["generations"][endpoint_key] = (state["generations"][endpoint_key] or 0) + 1;
    keys_to_delete = [];
    for key in Object.keys(state["cache"]) {
        if key.startswith(endpoint_key + ":") {
            keys_to_delete.append(key);
        }
    }
    for key in keys_to_delete {
        Reflect.deleteProperty(state["cache"], key);
        idx = state["order"].indexOf(key);
        if idx > -1 {
            state["order"].splice(idx, 1);
        }
    }
}

async def:pub __cachedEndpointCall(
    endpoint_key: str, args_key: str, fetch_fn: any
) -> any {
    effects = __getEndpointEffects();
    info = effects[endpoint_key];
    state = __getCacheState();
    generation = state["generations"][endpoint_key] or 0;
    epoch = state["epoch"];

    if info
        and not info["unknown"]
        and len(info["writes"]) == 0
        and state["activeWrites"] == 0 {
        cached = __cacheGet(args_key);
        if cached and __isFresh(cached) {
            return cached["data"];
        }
        pending = state["pending"][args_key];
        if pending
            and pending["generation"] == generation
            and pending["epoch"] == epoch {
            return await pending["promise"];
        }
        fetch_promise = fetch_fn();
        request = {"promise": fetch_promise, "generation": generation, "epoch": epoch};
        state["pending"][args_key] = request;
        try {
            data = await fetch_promise;
            if state["epoch"] == epoch
                and (state["generations"][endpoint_key] or 0) == generation
                and state["activeWrites"] == 0 {
                __cacheSet(args_key, data, state["config"]["defaultTtlMs"]);
            }
            return data;
        } finally {
            if state["pending"][args_key] == request {
                Reflect.deleteProperty(state["pending"], args_key);
            }
        }
    }

    if not info or info["unknown"] or len(info["writes"]) > 0 {
        state["activeWrites"] += 1;
        __invalidateEffects(info["writes"] if info else ["*"]);
        try {
            return await fetch_fn();
        } finally {
            __invalidateEffects(info["writes"] if info else ["*"]);
            state["activeWrites"] -= 1;
        }
    }
    return await fetch_fn();
}

def:pub __invalidateEffects(writes: list[str]) {
    effects = __getEndpointEffects();
    for endpoint_name in Object.keys(effects) {
        reader = effects[endpoint_name];
        if reader
            and not reader["unknown"]
            and len(reader["writes"]) == 0
            and __overlaps(reader["reads"], writes) {
            __invalidateEndpoint(endpoint_name);
        }
    }
}

def:pub __jacClearCache {
    state = __getCacheState();
    state["epoch"] += 1;
    state["pending"] = {};
    for key in Object.keys(state["cache"]) {
        Reflect.deleteProperty(state["cache"], key);
    }
    state["order"].splice(0, state["order"].length);
}


def:pub __endpointKey(kind: str, name: str, opts: dict | None) -> str {
    app = opts["app"] if opts and opts["app"] else "";
    module = opts["module"] if opts and opts["module"] else "";
    effects = __getEndpointEffects();
    if opts and opts["contract"] {
        return opts["contract"];
    }
    matches: list[str] = [];
    for key in Object.keys(effects) {
        info = effects[key];
        if info["kind"] == kind
            and info["name"] == name
            and (not app or info["app"] == app)
            and (not module or info["module"] == module) {
            matches.append(key);
        }
    }
    if len(matches) > 1 {
        raise Error("Ambiguous endpoint contract: " + kind + ":" + name);
    }
    if len(matches) == 1 {
        return matches[0];
    }
    return JSON.stringify([app, module, kind, name]);
}
