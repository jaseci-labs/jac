/** JS server runtime for Bun-hosted sv services (P1 stateless + P2 BunStore). */

import {
  __jacCommitGraph,
  __jacEnsureRoot,
  __jacInitBunStore,
  __jacInstallOspPersistHooks,
  __jacServerSpawnWalker,
} from "./bun_store.js";

export async function parseJsonBody(req) {
  try {
    return await req.json();
  } catch {
    return null;
  }
}

export function deserializeWireValue(val) {
  if (val == null || typeof val !== "object") {
    return val;
  }
  if (Array.isArray(val)) {
    return val.map(deserializeWireValue);
  }
  if (val.__type__ && val.__type__.__from_wire) {
    return val.__type__.__from_wire(val);
  }
  if (val.__type__) {
    const ctor = globalThis[val.__type__];
    if (ctor && ctor.__from_wire) {
      return ctor.__from_wire(val);
    }
  }
  return val;
}

export function deserializeWireArgs(args) {
  const out = {};
  for (const key of Object.keys(args)) {
    out[key] = deserializeWireValue(args[key]);
  }
  return out;
}

export function serializeApiValue(val) {
  if (val == null) {
    return null;
  }
  const t = typeof val;
  if (t === "string" || t === "number" || t === "boolean") {
    return val;
  }
  if (Array.isArray(val)) {
    return val.map(serializeApiValue);
  }
  if (val.__to_wire) {
    return val.__to_wire();
  }
  if (typeof val === "object") {
    const out = {};
    for (const key of Object.keys(val)) {
      if (!key.startsWith("_")) {
        out[key] = serializeApiValue(val[key]);
      }
    }
    if (val.constructor && val.constructor.name) {
      out._jac_type = val.constructor.name;
      out._jac_archetype = "walker";
    }
    return out;
  }
  return String(val);
}

export function finalizeCallResponse(result, reports = []) {
  return {
    result: serializeApiValue(result),
    reports: serializeApiValue(reports),
  };
}

export function okEnvelope(data) {
  return { ok: true, data };
}

export function errorEnvelope(message) {
  return { ok: false, error: { message } };
}

export async function execWalker(walkerCls, fields) {
  const inst = Object.assign(new walkerCls(), fields);
  return await __jacServerSpawnWalker(inst);
}

async function _preparePersistContext() {
  __jacInstallOspPersistHooks();
  await __jacInitBunStore();
  __jacEnsureRoot();
}

export async function handleFunctionCall(req, name, handlers) {
  const fn = handlers[name];
  if (!fn) {
    return errorEnvelope(`Unknown function '${name}'`);
  }
  const body = await parseJsonBody(req);
  if (body == null) {
    return errorEnvelope("Invalid JSON");
  }
  const args = deserializeWireArgs(body);
  try {
    await _preparePersistContext();
    let result = fn(args);
    if (result && typeof result === "object" && result.then) {
      result = await result;
    }
    await __jacCommitGraph();
    return okEnvelope(finalizeCallResponse(result, []));
  } catch (e) {
    const msg = e.message ? e.message : String(e);
    return errorEnvelope(msg);
  }
}

export async function handleWalkerSpawn(req, name, nodeId, handlers) {
  const spawnFn = handlers[name];
  if (!spawnFn) {
    return errorEnvelope(`Unknown walker '${name}'`);
  }
  const body = await parseJsonBody(req);
  if (body == null) {
    return errorEnvelope("Invalid JSON");
  }
  const fields = deserializeWireArgs(body);
  if (nodeId) {
    fields._jac_spawn_node = nodeId;
  }
  try {
    await _preparePersistContext();
    const result = await spawnFn(fields);
    await __jacCommitGraph();
    const reports = result?.reports || [];
    const payload =
      result && result.result != null
        ? finalizeCallResponse(result.result, reports)
        : finalizeCallResponse(result, reports);
    return okEnvelope(payload);
  } catch (e) {
    const msg = e.message ? e.message : String(e);
    return errorEnvelope(msg);
  }
}

export function startBunServer(opts) {
  const project = opts.project || "jac-service";
  const walkers = opts.walkers || [];
  const functions = opts.functions || [];
  const handlers = opts.handlers || {};
  const port = Number(opts.port || 8000);
  const walkerFns = handlers.walkers || {};
  const functionFns = handlers.functions || {};
  const restspec = handlers.restspec || [];

  Bun.serve({
    port,
    hostname: "0.0.0.0",
    fetch: async (req) => {
      const url = new URL(req.url);
      const path = url.pathname;
      const method = req.method;

      if (method === "GET" && path === "/functions") {
        return Response.json(functions);
      }
      if (method === "GET" && path === "/walkers") {
        return Response.json(walkers);
      }
      if (method === "GET" && (path === "/healthz" || path === "/__health")) {
        return Response.json({ project, walkers, functions });
      }

      const fnMatch = path.match(/^\/function\/([^/]+)$/);
      if (fnMatch && method === "POST") {
        const name = decodeURIComponent(fnMatch[1]);
        const payload = await handleFunctionCall(req, name, functionFns);
        return Response.json(payload);
      }

      const walkerMatch = path.match(/^\/walker\/([^/]+)(?:\/([^/]+))?$/);
      if (walkerMatch && method === "POST") {
        const name = decodeURIComponent(walkerMatch[1]);
        let nodeId = "";
        if (walkerMatch[2]) {
          nodeId = decodeURIComponent(walkerMatch[2]);
        }
        const payload = await handleWalkerSpawn(req, name, nodeId, walkerFns);
        return Response.json(payload);
      }

      for (const carrier of restspec) {
        const spec = carrier.fn?.restspec;
        if (!spec) {
          continue;
        }
        let specPath = String(spec.path || "");
        if (specPath === "") {
          continue;
        }
        if (!specPath.startsWith("/")) {
          specPath = "/" + specPath;
        }
        const specMethod = String(spec.method || "POST").toUpperCase();
        if (path === specPath && method === specMethod) {
          const payload = await handleFunctionCall(req, carrier.name, {
            [carrier.name]: carrier.handler,
          });
          return Response.json(payload);
        }
      }

      return new Response("Not Found", { status: 404 });
    },
  });
  console.log(
    `Bun sv service '${project}' listening on http://0.0.0.0:${port}`
  );
}

export { __jacInitBunStore, __jacServerSpawnWalker };
