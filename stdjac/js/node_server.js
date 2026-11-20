// A `node` space's endpoints, served as a native space's are: POST
// /__jac/call/<space>/<module>/<name> with {"args": {<name>: <value>, ...}},
// the arguments by name (one left out takes its default, null is None, a
// name the function has no parameter for is refused), answered
// {"ok": true, "data": ...} or {"ok": false, "kind": ..., "detail": ...}.
// `:pub` takes anyone; an untagged function another space calls takes only a
// caller with the deployment's key (x-jac-key, JAC_DEPLOY_KEY), or the app's
// own code when the app runs the space in its own process (trusted, through
// `port`: stdjac.node_space).
import { createHash, timingSafeEqual } from "node:crypto";
import http from "node:http";
import { NA, encode, revive } from "./core.js";

// Whether `given` is the deployment's key `key`, compared in constant time
// (their digests, which are the same length whatever the key's), and never
// with no key set.
function signed(key, given) {
    if (key === "" || typeof given !== "string") return false;
    const digest = (s) => createHash("sha256").update(s, "utf8").digest();
    return timingSafeEqual(digest(key), digest(given));
}

// The reply to a call of `path` with JSON `text`: [status, body].
async function respond(space, endpoints, path, text, trusted) {
    const m = /^\/__jac\/call\/([^/]+)\/([^/]+)\/([^/?]+)/.exec(path || "");
    const ep = m && m[1] === space ? endpoints[m[2] + "/" + m[3]] : undefined;
    if (!ep) return [404, { ok: false, kind: "rejected", detail: "no such endpoint" }];
    if (!ep.pub && !trusted) {
        return [403, { ok: false, kind: "rejected", detail: "this endpoint is the deployment's own" }];
    }
    let given;
    try {
        given = JSON.parse(text || "{}").args || {};
    } catch (e) {
        return [400, { ok: false, kind: "rejected", detail: "the request is not JSON" }];
    }
    if (typeof given !== "object" || Array.isArray(given)) {
        return [400, { ok: false, kind: "rejected", detail: "the arguments are not a JSON object of them by name" }];
    }
    const names = ep.params.map((p) => p[0]);
    for (const k of Object.keys(given)) {
        if (!names.includes(k)) return [400, { ok: false, kind: "rejected", detail: m[3] + ": no parameter '" + k + "'" }];
    }
    const args = [];
    for (const [k, required] of ep.params) {
        if (Object.hasOwn(given, k)) args.push(revive(given[k]));
        else if (required) return [400, { ok: false, kind: "rejected", detail: m[3] + ": missing argument '" + k + "'" }];
        else args.push(NA);
    }
    while (args.length > 0 && args[args.length - 1] === NA) args.pop();
    try {
        // A stream endpoint gives its items' iterator, which the caller reads.
        if (ep.stream) return [200, null, ep.fn(...args)];
        return [200, { ok: true, data: encode(await ep.fn(...args)) }];
    } catch (e) {
        return [500, { ok: false, kind: "failed", detail: String((e && e.message) || e) }];
    }
}

const failed = (e) => ({ ok: false, kind: "failed", detail: String((e && e.message) || e) });

// What a native app running the space in its own process calls: a request
// made in-process, answered as one over HTTP is, [status, JSON text].
// A stream crosses the port as one its caller pulls (stdjac.remote): its call
// is answered with the id it was opened as, /__jac/stream/<id> gives its next
// item, its end or what it failed with, and /__jac/stream/<id>/close closes one
// its caller leaves early.
export function port({ space, endpoints }) {
    const open = new Map();
    let opened = 0;
    const pull = async (rest) => {
        const closing = rest.endsWith("/close");
        const id = closing ? rest.slice(0, -6) : rest;
        const items = open.get(id);
        if (!items) return [404, { ok: false, kind: "rejected", detail: "no such stream" }];
        if (closing) {
            open.delete(id);
            try { if (items.return) await items.return(); } catch (e) { /* (It was closing.) */ }
            return [200, { ok: true }];
        }
        let r;
        try { r = await items.next(); } catch (e) { open.delete(id); return [500, failed(e)]; }
        if (r.done) { open.delete(id); return [200, { ok: true, end: true }]; }
        return [200, { ok: true, data: encode(r.value) }];
    };
    return async (path, text, caller, trusted) => {
        if ((path || "").startsWith("/__jac/stream/")) {
            const [status, body] = await pull(path.slice("/__jac/stream/".length));
            return [status, JSON.stringify(body)];
        }
        const [status, body, items] = await respond(space, endpoints, path, text, trusted);
        if (items) {
            opened += 1;
            open.set(String(opened), items);
            return [200, JSON.stringify({ ok: true, stream: String(opened) })];
        }
        return [status, JSON.stringify(body)];
    };
}

export function serve({ space, app, endpoints }) {
    const key = process.env.JAC_DEPLOY_KEY || "";
    const listen = process.env["JAC_" + app.toUpperCase().replace(/-/g, "_") + "_LISTEN"] || "127.0.0.1:8000";
    const at = listen.lastIndexOf(":");
    const host = listen.slice(0, at);
    const port = Number(listen.slice(at + 1));
    const server = http.createServer((req, res) => {
        const reply = (status, body) => {
            res.writeHead(status, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
            res.end(JSON.stringify(body));
        };
        if (req.method === "OPTIONS") {
            res.writeHead(204, {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type, Authorization, x-jac-key",
                "Access-Control-Allow-Methods": "POST",
            });
            return res.end();
        }
        if (req.method !== "POST") return reply(404, { ok: false, kind: "rejected", detail: "no such endpoint" });
        const trusted = signed(key, req.headers["x-jac-key"]);
        let text = "";
        req.on("data", (c) => { text += c; });
        req.on("end", async () => {
            const [status, body, items] = await respond(space, endpoints, req.url, text, trusted);
            if (!items) return reply(status, body);
            // A stream: each item an event as it is made, then its end, or
            // what it failed with; one whose client has gone is closed.
            res.writeHead(200, { "Content-Type": "text/event-stream", "Cache-Control": "no-cache", "X-Accel-Buffering": "no", "Access-Control-Allow-Origin": "*" });
            let gone = false;
            res.on("close", () => { gone = true; });
            try {
                for (;;) {
                    const r = await items.next();
                    if (gone) { if (items.return) await items.return(); return; }
                    if (r.done) break;
                    res.write("data: " + JSON.stringify(encode(r.value)) + "\n\n");
                }
                res.write("event: end\ndata: {}\n\n");
            } catch (e) {
                res.write("event: error\ndata: " + JSON.stringify(failed(e)) + "\n\n");
            }
            res.end();
        });
    });
    server.listen(port, host, () => {
        console.log("listening on http://" + host + ":" + server.address().port + "/");
    });
    return server;
}
