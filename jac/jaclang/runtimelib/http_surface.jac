import from jaclang.runtimelib.invocation {
    InvocationKind,
    InvocationRequest,
    coerce_scalar
}


glob HTTP_CAPABILITIES: tuple = ("multipart", "webhooks", "websockets", "openapi"),
     _CAPABILITY_STATUS: dict = {
         "multipart": 415,
         "webhooks": 501,
         "websockets": 501,
         "openapi": 501
     };


def capability_error(capability: str, http_status: int = 0) -> dict {
    status = http_status
        if http_status > 0
        else int(_CAPABILITY_STATUS.get(capability, 501));
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
    if value is None or not isinstance(value, str) {
        return value;
    }
    return coerce_scalar(type_name, value)[1];
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

    def add(spec: RouteSpec) {
        self.routes.append(spec);
    }

    def finalize {
        decorated = [
            (-_literal_seg_count(r.path_template), i, r)
            for (i, r) in enumerate(self.routes)
        ];
        decorated.sort();
        self.routes = [d[2] for d in decorated];
    }

    def resolve(method: str, path: str) -> (tuple[RouteSpec, dict] | None) {
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
        spec: RouteSpec, path_params: dict, query: dict, body: any, token: str = ""
    ) -> InvocationRequest {
        fields: dict = {};
        node_id: (str | None) = None;

        if isinstance(body, dict) {
            for (k, v) in body.items() {
                fields[k] = v;
            }
        }

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

        for (pname, pval) in path_params.items() {
            if spec.node_param and pname == spec.node_param {
                node_id = pval;
                continue;
            }
            fields[pname] = _coerce_scalar(spec.field_types.get(pname, "str"), pval);
        }

        return InvocationRequest(
            kind=spec.kind, name=spec.name, fields=fields, node_id=node_id, token=token
        );
    }
}


def _field_binding(
    meta: dict, path_params: list[str], method: str
) -> tuple[dict, list] {
    field_types: dict = {};
    query_fields: list = [];
    is_get = method == "GET";
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
    surface = HttpSurface(routes=[]);

    walkers = introspector.get_walkers();
    for (wname, wcls) in walkers.items() {
        wobj: any = wcls;
        rs = wobj?.restspec;
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
        fobj_any: any = fobj;
        rs = fobj_any?.restspec;
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
