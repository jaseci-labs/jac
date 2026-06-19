---
name: jac-sv-endpoints
description: Server endpoints - REST API endpoints (/walker/<name>, /function/<name>), walker:pub, the response envelope, @restspec custom routes/methods, file uploads, typed responses. For any REST consumer, not just the jac client. Pair with `jac-sv-persistence` (graph queries), `jac-sv-auth` (auth semantics), `jac-sv-streaming` (SSE).
---

A Jac server exposes two endpoint shapes. **Functions** (`def:pub` / `def:priv` / plain `def`) are the natural fit for full-stack RPC - the jac client calls them like local functions and the return type is the wire format. **Walkers** (`walker:pub`) are the docs' primary pattern for pure API services consumed over raw REST: `has` fields are the request body, `report` values are the response. Both live in `main.jac`, a plain `.jac` server module, or a `.sv.jac` module (server is the default context). Streaming endpoints (`-> Generator`, SSE): `jac-sv-streaming`.

Auth/visibility is per-declaration (canonical semantics in `jac-sv-auth`):

- **`def:pub` / `walker:pub`** - no auth required. Anonymous callers run on the shared guest graph (`root.shared`); a caller who *does* send a valid token runs on their own root.
- **`def:priv` / plain `def` (and `walker:priv` / plain `walker`)** - JWT required; runs on the caller's own isolated root. Plain and `:priv` behave identically (verified against the live server).
- **`def _helper(...)`** - underscore prefix keeps a function OFF the API. Underscore-prefixed *walkers* are NOT inert: they become middleware hooks (`_before_request`, `_authenticate`) that run around every request.

## Function endpoints (RPC style)

Return types auto-serialize: node archetypes, primitives, `list[T]`, `dict`, `T | None`.

```jac
node Item {
    has title: str;
    has done: bool = False;
}

def:pub list_items() -> list[Item] {
    return [root -->][?:Item];
}

def:pub add_item(title: str) -> Item {
    return (root ++> Item(title=title))[0];
}

def:pub toggle_item(id: str) -> Item | None {
    for i in [root -->][?:Item] {
        if jid(i) == id {
            i.done = not i.done;
            return i;
        }
    }
    return None;
}
```

The find-by-`jid` loop (and why Python `id()` silently breaks) lives in `jac-sv-persistence` - same pattern for update/delete.

## Walker endpoints (REST style)

```jac
node Item {
    has title: str;
}

walker:pub add_task {
    has title: str;                       # request body field

    can create with Root entry {
        task = (root ++> Item(title=self.title))[0] as Item;   # ++> returns a list
        report {"id": jid(task), "title": task.title};   # response payload
    }
}
```

```bash
jac start api.jac --no_client       # API only, no frontend bundling (NOT --no-client)
curl -X POST http://localhost:8000/walker/add_task \
  -H "Content-Type: application/json" -d '{"title": "Write docs"}'
```

For typed report accumulation (`has reports: list[T] = [];`, exit-collector pattern), load `jac-walker-patterns` - it owns that pattern.

## REST surface

- `POST /walker/<name>` - spawn a walker; body maps onto `has` fields.
- `POST /function/<name>` - call a function; body maps onto parameters.
- `GET /docs` (Swagger), `/redoc`, `/openapi.json` - auto-generated; disable in prod with `[plugins.scale.server] docs_enabled = false`.
- `GET /graph` - live graph visualizer. `GET /healthz` (+ `/healthz/ready`, `/healthz/live`) - health probes.

Every response is wrapped in a standard envelope:

```json
{"ok": true, "type": "response",
 "data": {"result": <return value or executed walker>, "reports": [<report values>]},
 "error": null, "meta": {"extra": {"http_status": 200}}}
```

Errors flip `ok` to `false` and fill `error: {code, message}` (e.g. `UNAUTHORIZED` + `http_status: 401`). Returned archetypes carry `_jac_type` / `_jac_id` / `_jac_archetype` keys - wire bookkeeping that lets the jac client rehydrate real typed instances; raw REST consumers should read fields and ignore them.

## @restspec - custom methods and paths

Default is `POST` at the auto path. `restspec` and `APIProtocol` are ambient builtins; `HTTPMethod` needs an import:

```jac
import from http { HTTPMethod }

@restspec(method=HTTPMethod.GET, path="/users/{user_id}/orders")
walker:pub get_user_orders {
    has user_id: str;          # path parameter (matches {user_id})
    has status: str = "all";   # query parameter (GET)

    can fetch with Root entry { report {"user": self.user_id, "status": self.status}; }
}
```

Parameters are classified: **path** (name matches `{...}` in path) → **file** (`UploadFile` type) → **query** (GET) → **body** (other methods). `@restspec` works on `def :pub` functions too. `protocol=APIProtocol.WEBHOOK` / `WEBSOCKET` variants: see `jac-sv-deploy`.

## File uploads

```jac
import from http { UploadFile }

glob storage: any = store();   # ambient builtin; local disk by default

walker:pub upload_doc {
    has file: UploadFile;      # classified as a multipart file param

    can save with Root entry {
        storage.upload(self.file.file, f"docs/{self.file.filename}");
        report {"ok": True};
    }
}
```

S3 backends and `get_url` presigning: `jac-sv-deploy`.

## Pitfalls

- Mark an endpoint `async def:pub` when its body uses `await` (external API calls, LLM endpoints), so the result is awaited rather than handed back as an unresolved coroutine.
- Give every endpoint an explicit return type - **the return type IS the wire format**. Use typed objs/nodes for domain data (the client gets dot access: `items[0].title`); an ad-hoc `dict` is fine for a one-off payload (`{"liked": True, "likes": ...}`).
- **`_jac_id` is volatile** - the runtime assigns a fresh one to the walker instance and to every freshly-constructed report obj on every response (persistent node jids are stable). Strip it before hashing, caching, or diffing responses.
- Mixed visibility in one module is normal design: an anonymous `walker:pub` (public directory, trending) sits next to authenticated plain walkers.
- Walker spawns take **keyword** arguments mapped to `has` fields (`{"title": ...}` in the body); function calls take the declared parameters. Don't pass nodes by reference across the wire - pass `jid(node)` strings.
- **404/405 on a new endpoint = nothing references it.** An endpoint a client module reaches via `sv import` self-registers at startup; a top-level entry-module import is needed only when NO client stub references it (raw-fetch streams, REST-only walkers). Full rule: `jac-fullstack-patterns`.
- `jac start` needs a `jac.toml` in the cwd (`Error: No jac.toml found`); flags use underscores: `--no_client`, not `--no-client`.
- A `{"detail": "Invalid anchor id ..."}` 500 after editing node schemas = stale persisted anchors. Fix: stop the server, `rm -rf .jac/data/`, restart. Full schema-evolution story: `jac-sv-persistence`.
