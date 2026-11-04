"""The CORS headers a served app sends, and the one pair it refuses (#8863).

A response may not allow every origin and credentials together: browsers reject
it, so a credentialed cross-origin request fails with an opaque error. A default
app allows every origin without credentials, credentials are an explicit
`[serve] cors_credentials` for listed origins, and the wildcard pair is refused
before anything serves.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.testing.testing { JacTestClient }

glob APP_ORIGIN: str = "https://app.example",
     OTHER_ORIGIN: str = "https://other.example",
     CORS_ENV: list[str] = ["JAC_SERVE_CORS_ORIGINS", "JAC_SERVE_CORS_CREDENTIALS"];


"""The Access-Control-* headers a real app answers `method path` from `origin` with,
names lowercased. `serve_table` is the app's `[serve]` section."""
def _cors_headers(
    serve_table: str, method: str, path: str, origin: str
) -> dict[str, str] {
    request_headers = {"Origin": origin};
    if method == "OPTIONS" {
        request_headers["Access-Control-Request-Method"] = "POST";
    }
    with TemporaryDirectory() as tmp {
        project = Path(tmp).resolve();
        (project / "jac.toml").write_text('[project]\nname = "cors"\n\n' + serve_table);
        (project / "main.jac").write_text('def:pub ping -> str { return "pong"; }\n');
        with patch.dict(os.environ, {name: "" for name in CORS_ENV}) {
            client = JacTestClient.from_file(
                str(project / "main.jac"), base_path=str(project)
            );
            try {
                resp = client.request(method, path, headers=request_headers);
            } finally {
                client.close();
            }
        }
    }
    seen: dict[str, str] = {};
    for (name, value) in resp.headers.items() {
        if str(name).lower().startswith("access-control-") {
            seen[str(name).lower()] = str(value);
        }
    }
    return seen;
}


"""Problems `ServeSettings` finds in the CORS settings of `jac_toml`, with `env` set."""
def _cors_problems(jac_toml: str, env: (dict[str, str] | None) = None) -> list[str] {
    import from jaclang.server.settings { ServeSettings }
    with TemporaryDirectory() as tmp {
        (Path(tmp) / "jac.toml").write_text('[project]\nname = "cors"\n\n' + jac_toml);
        overrides = {name: "" for name in CORS_ENV};
        overrides.update(env or {});
        with patch.dict(os.environ, overrides) {
            problems = ServeSettings.load(tmp).validate();
        }
    }
    return [
        p
        for p in problems
        if "cors" in p
    ];
}


test "a default app allows every origin without claiming credentials" {
    for (method, path) in [
        ("GET", "/healthz"),
        ("OPTIONS", "/function/ping"),
        ("POST", "/function/ping")
    ] {
        seen = _cors_headers("", method, path, OTHER_ORIGIN);
        assert seen.get("access-control-allow-origin") == "*" , f"{method} {path}: {seen}";
        assert "access-control-allow-credentials" not in seen , (
            f"{method} {path} paired a wildcard origin with credentials: {seen}"
        );
    }
}


test "a listed origin is echoed, with credentials only when cors_credentials is on" {
    listed = f'[serve]\ncors_origins = ["{APP_ORIGIN}"]\n';
    plain = _cors_headers(listed, "GET", "/healthz", APP_ORIGIN);
    assert plain.get("access-control-allow-origin") == APP_ORIGIN , plain;
    assert "access-control-allow-credentials" not in plain , (
        f"credentials were allowed without cors_credentials: {plain}"
    );

    credentialed = listed + "cors_credentials = true\n";
    for (method, path) in [("GET", "/healthz"), ("OPTIONS", "/function/ping")] {
        seen = _cors_headers(credentialed, method, path, APP_ORIGIN);
        assert seen.get("access-control-allow-origin") == APP_ORIGIN , seen;
        assert seen.get("access-control-allow-credentials") == "true" , (
            f"{method} {path} dropped the credentials cors_credentials allows: {seen}"
        );
    }
    unlisted = _cors_headers(credentialed, "GET", "/healthz", OTHER_ORIGIN);
    assert unlisted == {} , f"an unlisted origin got CORS headers: {unlisted}";
}


test "cors_credentials with a wildcard origin is refused, naming both keys" {
    refused = _cors_problems("[serve]\ncors_credentials = true\n");
    assert len(refused) == 1 , (
        f"cors_credentials = true with the default cors_origins = ['*'] was not refused: {refused}"
    );
    assert "[serve] cors_origins" in refused[0] , refused[0];
    assert "[serve] cors_credentials" in refused[0] , refused[0];

    from_env = _cors_problems("", {"JAC_SERVE_CORS_CREDENTIALS": "true"});
    assert len(from_env) == 1 , (
        f"JAC_SERVE_CORS_CREDENTIALS=true with a wildcard origin was not refused: {from_env}"
    );

    listed = f'[serve]\ncors_origins = ["{APP_ORIGIN}"]\ncors_credentials = true\n';
    assert _cors_problems(listed) == [] , _cors_problems(listed);
    assert _cors_problems(
        "", {"JAC_SERVE_CORS_ORIGINS": APP_ORIGIN, "JAC_SERVE_CORS_CREDENTIALS": "true"}
    )
        == [];
}


test "the CORS middleware will not build the wildcard-credentials pair" {
    import from jaclang.server.serving.middleware { cors_middleware }
    cors_middleware(allow_origins=["*"]);
    cors_middleware(allow_origins=[APP_ORIGIN], allow_credentials=True);
    try {
        cors_middleware(allow_origins=["*"], allow_credentials=True);
        assert False , "cors_middleware built a wildcard origin with credentials";
    } except ValueError as refused {
        assert "allow_origins" in str(refused)
            and "allow_credentials" in str(refused) , (str(refused));
    }
}


test "[scale.gateway.cors] refuses allow_credentials with a wildcard origin" {
    import from jaclang.scale.config.config_loader { normalize_gateway_config }
    assert normalize_gateway_config({})["cors"]["allow_credentials"] is False;
    listed = normalize_gateway_config(
        {"cors": {"allow_origins": [APP_ORIGIN], "allow_credentials": True}}
    );
    assert listed["cors"]["allow_credentials"] is True , listed["cors"];
    try {
        normalize_gateway_config({"cors": {"allow_credentials": True}});
        assert False , "[scale.gateway.cors] accepted credentials with allow_origins = ['*']";
    } except ValueError as refused {
        assert "[scale.gateway.cors] allow_origins" in str(refused) , str(refused);
        assert "[scale.gateway.cors] allow_credentials" in str(refused) , str(refused);
    }
}


"""Whether a browser accepts the preflight answer `value` for `wanted`: `*` is a
wildcard only without credentials, and never stands for Authorization."""
def _preflight_allows(value: str, wanted: str, credentials: bool) -> bool {
    listed = [item.strip().lower() for item in value.split(",")];
    if wanted.lower() in listed {
        return True;
    }
    return "*" in listed and not credentials and wanted.lower() != "authorization";
}


test "a * in the gateway's allow_methods and allow_headers passes a preflight for Authorization" {
    import from jaclang.scale.config.config_loader { normalize_gateway_config }
    import from jaclang.server.serving.app { ServingApp }
    import from jaclang.server.serving.middleware { cors_middleware }
    import from jaclang.testing.testkit { ServingTestClient }
    rows = [
        ("the open default", {}),
        (
            "a listed origin with credentials",
            {"cors": {"allow_origins": [APP_ORIGIN], "allow_credentials": True}}
        )
    ];
    for (label, raw) in rows {
        cors = normalize_gateway_config(raw)["cors"];
        assert cors["allow_methods"] == ["*"] and cors["allow_headers"] == ["*"] , (
            f"{label}: {cors}"
        );
        app = ServingApp();
        app.add_middleware(cors_middleware(**cors));
        resp = ServingTestClient(app).options(
            "/function/ping",
            headers={
                "Origin": APP_ORIGIN,
                "Access-Control-Request-Method": "PUT",
                "Access-Control-Request-Headers": "authorization, content-type"
            }
        );
        seen: dict[str, str] = {};
        for (name, value) in resp.headers.items() {
            seen[str(name).lower()] = str(value);
        }
        credentials = seen.get("access-control-allow-credentials") == "true";
        assert credentials == cors["allow_credentials"] , f"{label}: {seen}";
        methods = seen.get("access-control-allow-methods", "");
        assert _preflight_allows(methods, "PUT", credentials) , (
            f"{label}: a browser refuses PUT after Allow-Methods {methods!r}"
        );
        for wanted in ["Authorization", "Content-Type"] {
            allowed = seen.get("access-control-allow-headers", "");
            assert _preflight_allows(allowed, wanted, credentials) , (
                f"{label}: a browser refuses {wanted} after Allow-Headers {allowed!r}"
            );
        }
    }
}
