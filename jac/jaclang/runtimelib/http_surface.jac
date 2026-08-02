"""Transport-neutral HTTP route surface for walker/function invocation.

This module is the single source of truth for *how a request path/verb maps to a
walker or function call*. It is shared by every front door that speaks HTTP-shaped
requests -- today the desktop `sv` bridge (`inprocess_dispatch.forward`), later the
FastAPI adapter -- so custom `@restspec` paths/verbs, GET+query binding, and path
params behave identically across transports.

Design constraints (see docs/desktop-portal-architecture.md, sections 7-9):

- It MUST stay importable on the lean desktop boot path. It therefore imports NO
  FastAPI / starlette / pydantic and NO `jaclang.scale.*` module. The tiny path-
  param extractor is re-implemented locally rather than imported from
  `jaclang.scale.shared.utils` for exactly this reason.
- It supplies *binding metadata only*. Field validation and the authoritative type
  coercion / 422 semantics stay in `InvocationDispatcher`; the light scalar coercion
  here only mirrors what an HTTP transport does when it turns the query string "30"
  into the int 30 before the dispatcher ever sees it.

The `restspec` metadata it introspects is stamped by the `@restspec` decorator
(`runtimelib/impl/builtin.impl.jac`): the decorator sets `cls.restspec` to a
`JacAPIServer.RestSpecs` instance carrying `method`, `path`, `protocol`,
`broadcast`, `produces`, `envelope`. A walker/function with no decorator has no
`restspec` attribute and defaults to POST `/walker/{name}` or `/function/{name}`.
"""

import from jaclang.runtimelib.invocation { InvocationKind, InvocationRequest }


# HTTP-only capabilities that only the opt-in [desktop.http] FastAPI sidecar can
# serve. When one is attempted in lean mode (no sidecar) the request fails with a
# stable, structured capability error instead of a bare 404 -- see
# capability_error() below. Kept in sync with desktop_config.HTTP_CAPABILITIES and
# the sidecar registration in native/http_sidecar.jac.
glob HTTP_CAPABILITIES: tuple = ("multipart", "webhooks", "websockets", "openapi");

# Default HTTP status per capability: multipart is a media-type mismatch on the
# lean JSON path (415), the rest are simply not implemented without the sidecar
# (501).
glob _CAPABILITY_STATUS: dict = {
    "multipart": 415,
    "webhooks": 501,
    "websockets": 501,
    "openapi": 501
};


def capability_error(capability: str, http_status: int = 0) -> dict {
    # Build the structured error envelope for an HTTP-only feature attempted
    # without the [desktop.http] sidecar. Shared by the sv bridge / native
    # dispatch and mirrored cl-side in the client routing module so both front
    # doors fail identically: a clear code, the capability name, and a hint that
    # names [desktop.http] and how to enable it.
    status = http_status if http_status > 0 else int(
        _CAPABILITY_STATUS.get(capability, 501)
    );
    return {
        "ok": False,
        "http_status": status,
        "error": {
            "code": "CAPABILITY_NOT_AVAILABLE",
            "capability": capability,
            "message": (
                "the '"
                + capability
                + "' feature requires the opt-in desktop HTTP sidecar, which is "
                + "not enabled for this app"
            ),
            "hint": (
                "enable it in jac.toml: [desktop.http] enabled = true, "
                + "capabilities = [\""
                + capability
                + "\"]"
            )
        }
    };
}


def _extract_path_params(path: str) -> list[str] {
    # Local copy of jaclang.scale.shared.utils._extract_path_param_names -- kept
    # here so importing http_surface never drags in a jaclang.scale module on the
    # lean desktop boot path.
    names: list[str] = [];
    if not path {
        return names;
    }
    for segment in path.split("/") {
        if segment.startswith("{") and segment.endswith("}") and len(segment) > 2 {
            raw = segment[1:-1].strip();
            if raw {
                pname = raw.split(":", 1)[0].strip();
                if pname and pname not in names {
                    names.append(pname);
                }
            }
        }
    }
    return names;
}


def _norm_method(raw: any) -> str {
    # restspec.method may be an http.HTTPMethod (a StrEnum whose value is the verb)
    # or a plain string or "" (the RestSpecs default). Empty -> POST, matching the
    # FastAPI adapter's `restspec.method if restspec?.method else HTTPMethod.POST`.
    val = getattr(raw, "value", raw);
    text = str(val or "").upper();
    return text or "POST";
}


def _literal_seg_count(path_template: str) -> int {
    n = 0;
    for seg in path_template.strip("/").split("/") {
        if seg and not seg.startswith("{") {
            n += 1;
        }
    }
    return n;
}


def _coerce_scalar(type_name: str, value: any) -> any {
    # Mirror the transport-level string->scalar coercion FastAPI performs for path
    # and query params. Body values arrive already typed from JSON, so they skip
    # this. The dispatcher re-validates regardless, so a miss here is harmless.
    if value is None or not isinstance(value, str) {
        return value;
    }
    core = type_name.strip();
    if core == "int" {
        try {
            return int(value);
        } except Exception {
            return value;
        }
    }
    if core == "float" {
        try {
            return float(value);
        } except Exception {
            return value;
        }
    }
    if core == "bool" {
        low = value.strip().lower();
        if low in ("true", "1", "yes", "on") {
            return True;
        }
        if low in ("false", "0", "no", "off") {
            return False;
        }
    }
    return value;
}


obj RouteSpec {
    has method: str,
        path_template: str,
        kind: InvocationKind,
        name: str,
        path_params: list[str] = [],
        node_param: str = "",
        field_types: dict[str, str] = {},
        query_fields: list[str] = [];
}


obj HttpSurface {
    has routes: list[RouteSpec] = [];

    def add(spec: RouteSpec) -> None {
        self.routes.append(spec);
    }

    def finalize -> None {
        # Prefer routes with more literal (non-param) segments so a literal path
        # like `/walker/foo` is matched before a fully-templated `/walker/{name}`.
        # Decorate with the original index so RouteSpec objects are never compared.
        decorated = [
            (-_literal_seg_count(r.path_template), i, r)
            for (i, r) in enumerate(self.routes)
        ];
        decorated.sort();
        self.routes = [
            d[2]
            for d in decorated
        ];
    }

    def match(method: str, path: str) -> (tuple[RouteSpec, dict] | None) {
        m = _norm_method(method);
        target = path.split("?", 1)[0];
        segs = [
            s
            for s in target.strip("/").split("/")
            if s
        ];
        for route in self.routes {
            if route.method != m {
                continue;
            }
            tsegs = [
                s
                for s in route.path_template.strip("/").split("/")
                if s
            ];
            if len(tsegs) != len(segs) {
                continue;
            }
            pp: dict = {};
            ok = True;
            for (i, tseg) in enumerate(tsegs) {
                if tseg.startswith("{") and tseg.endswith("}") {
                    pname = tseg[1:-1].split(":", 1)[0].strip();
                    pp[pname] = segs[i];
                } elif tseg != segs[i] {
                    ok = False;
                    break;
                }
            }
            if ok {
                return (route, pp);
            }
        }
        return None;
    }

    def bind(
        spec: RouteSpec,
        path_params: dict,
        query: dict,
        body: any,
        token: str = ""
    ) -> InvocationRequest {
        fields: dict = {};
        node_id: (str | None) = None;

        # JSON body (POST-shaped) supplies the bulk of the fields as-is.
        if isinstance(body, dict) {
            for (k, v) in body.items() {
                fields[k] = v;
            }
        }

        # Query string supplies only *declared* fields (GET-shaped binding). This
        # matches the FastAPI adapter's forward_undeclared_query_params=False, so a
        # cache-buster like `?v=123` never reaches the walker/function.
        if query {
            for fname in spec.query_fields {
                if fname in query {
                    raw = query[fname];
                    if isinstance(raw, list) {
                        raw = raw[-1] if raw else None;
                    }
                    fields[fname] = _coerce_scalar(
                        spec.field_types.get(fname, "Any"), raw
                    );
                }
            }
        }

        # Path params override; the walker node segment ({nd}) maps to node_id.
        for (pname, pval) in path_params.items() {
            if spec.node_param and pname == spec.node_param {
                node_id = pval;
                continue;
            }
            fields[pname] = _coerce_scalar(spec.field_types.get(pname, "str"), pval);
        }

        return InvocationRequest(
            kind=spec.kind,
            name=spec.name,
            fields=fields,
            node_id=node_id,
            token=token
        );
    }
}


def _field_binding(
    meta: dict, path_params: list[str], method: str
) -> tuple[dict, list] {
    field_types: dict = {};
    query_fields: list = [];
    is_get = (method == "GET");
    for (fname, fmeta) in meta.items() {
        if fname == "_jac_spawn_node" {
            continue;
        }
        tname = fmeta.get("type", "Any") if isinstance(fmeta, dict) else "Any";
        field_types[fname] = tname;
        if fname in path_params {
            continue;
        }
        if is_get {
            query_fields.append(fname);
        }
    }
    return (field_types, query_fields);
}


def build_surface(introspector: any) -> HttpSurface {
    # Introspect a loaded app module's walkers + functions into a route table.
    # Registers, for every walker: its (restspec or default) route plus a node-
    # scoped `<path>/{nd}` variant (the `{nd}` segment binds
    # InvocationRequest.node_id, exactly like the FastAPI adapter). For every
    # function: its (restspec or default) route. Verb/path/param binding is
    # derived from restspec + field introspection.
    surface = HttpSurface(routes=[]);

    walkers = introspector.get_walkers();
    for (wname, wcls) in walkers.items() {
        rs = getattr(wcls, "restspec", None);
        method = _norm_method(getattr(rs, "method", "")) if rs else "POST";
        rpath = (getattr(rs, "path", "") or "") if rs else "";
        spec_path = rpath or f"/walker/{wname}";
        path_params = _extract_path_params(spec_path);
        meta = introspector.introspect_walker(wcls).get("fields", {});
        (field_types, query_fields) = _field_binding(meta, path_params, method);
        surface.add(
            RouteSpec(
                method=method,
                path_template=spec_path,
                kind=InvocationKind.WALKER,
                name=str(wname),
                path_params=path_params,
                node_param="",
                field_types=field_types,
                query_fields=query_fields
            )
        );
        surface.add(
            RouteSpec(
                method=method,
                path_template=spec_path + "/{nd}",
                kind=InvocationKind.WALKER,
                name=str(wname),
                path_params=path_params + ["nd"],
                node_param="nd",
                field_types=field_types,
                query_fields=query_fields
            )
        );
    }

    functions = introspector.get_functions();
    for (fname, fobj) in functions.items() {
        rs = getattr(fobj, "restspec", None);
        method = _norm_method(getattr(rs, "method", "")) if rs else "POST";
        rpath = (getattr(rs, "path", "") or "") if rs else "";
        spec_path = rpath or f"/function/{fname}";
        path_params = _extract_path_params(spec_path);
        meta = introspector.introspect_callable(fobj).get("parameters", {});
        (field_types, query_fields) = _field_binding(meta, path_params, method);
        surface.add(
            RouteSpec(
                method=method,
                path_template=spec_path,
                kind=InvocationKind.FUNCTION,
                name=str(fname),
                path_params=path_params,
                node_param="",
                field_types=field_types,
                query_fields=query_fields
            )
        );
    }

    surface.finalize();
    return surface;
}
