"""`@restspec` routes must answer the same way in dev as they do when served.

A `@restspec(method=GET, path="/install.sh")` function claims a literal HTTP
path. `jac run --serve` answers it with the function's payload; `jac run --dev`
answered it with the SPA HTML shell, because the Vite dev proxy forwards a
fixed list of prefixes (`/walker`, `/function`, `/user`, ...) and everything
else falls through to Vite's SPA fallback. Hitting the same path on the API
port did not help: the core server's GET catch-all rendered the SPA there too,
and in dev that render kicks off a cold production client build inline in the
request thread, so the request never gets a response head at all.

Pinned here: the paths `@restspec` claims are declared to the dev proxy, the
core server answers them itself with the declared media type and no envelope,
and a dev-mode SPA fallback never blocks on a production bundle build.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.testing.testing { JacTestClient }


"""Reach an API by name so this suite compiles against a build that lacks it
and fails on the assertion instead of at import."""
def _call(target: any, name: str, *args: any, **kwargs: any) -> any {
    member = getattr(target, name, None);
    assert member is not None , f"{type(target).__name__} has no '{name}'";
    return member(*args, **kwargs);
}


"""A project skeleton the Vite bundler is willing to configure."""
def _min_project(project_dir: str) -> Path {
    Path(os.path.join(project_dir, "jac.toml")).write_text(
        '[project]\nname = "restspec-dev-test"\nversion = "1.0.0"\n', encoding="utf-8"
    );
    entry_file = Path(project_dir) / ".jac" / "client" / "build" / "main.js";
    entry_file.parent.mkdir(parents=True, exist_ok=True);
    entry_file.write_text("// entry", encoding="utf-8");
    return entry_file;
}


"""An app whose only public surface is two GET @restspec functions -- the
shape the jaclang.org site uses for /install.sh and /llms.txt."""
def _restspec_app(project_dir: str) -> str {
    app = os.path.join(project_dir, "app.jac");
    Path(app).write_text(
        'import from http { HTTPMethod }\n'
        '\n'
        '@restspec(\n'
        '    method=HTTPMethod.GET,\n'
        '    path="/install.sh",\n'
        '    produces="text/x-shellscript",\n'
        '    envelope=False\n'
        ')\n'
        'def:pub install_sh -> str {\n'
        '    return "#!/usr/bin/env bash\\necho jac\\n";\n'
        '}\n'
        '\n'
        '@restspec(method=HTTPMethod.GET, path="/llms.txt", produces="text/plain")\n'
        'def:pub llms_txt -> str {\n'
        '    return "jac docs";\n'
        '}\n'
        '\n'
        '@restspec(method=HTTPMethod.GET, path="/echo", envelope=False)\n'
        'def:pub echo(word: str = "none") -> str {\n'
        '    return "you said " + word;\n'
        '}\n'
        '\n'
        '@restspec(method=HTTPMethod.GET, produces="application/octet-stream", envelope=False)\n'
        'def:pub raw_bytes -> bytes {\n'
        '    return b"\\x00binary";\n'
        '}\n'
        '\n'
        '@restspec(method=HTTPMethod.GET, path="/nothing", envelope=False)\n'
        'def:pub nothing -> str | None {\n'
        '    return None;\n'
        '}\n',
        encoding="utf-8"
    );
    return app;
}


test "the dev vite config proxies the paths @restspec claims" {
    import from jaclang.client.vite_bundler { ViteBundler }

    with TemporaryDirectory() as tmp {
        entry_file = _min_project(tmp);
        bundler = ViteBundler(Path(tmp));
        config_path = _call(
            bundler,
            "create_vite_config",
            entry_file,
            is_dev=True,
            api_port=8123,
            api_paths=["/install.sh", "/llms.txt"]
        );
        text = config_path.read_text(encoding="utf-8");
        assert '"^/install\\\\.sh$"' in text , (
            f"declared restspec paths must reach the dev proxy table; got:\n{text}"
        );
        assert '"^/llms\\\\.txt$"' in text , (
            f"declared restspec paths must reach the dev proxy table; got:\n{text}"
        );
        assert "http://localhost:8123" in text , (
            "the restspec proxy entries must target the api port"
        );
    }
}


test "the server reports the api paths a module declares" {
    with TemporaryDirectory() as tmp {
        app = _restspec_app(tmp);
        client = JacTestClient.from_file(app, base_path=tmp);
        try {
            paths = _call(client.server.introspector, "declared_api_paths");
        } finally {
            client.close();
        }
        assert "/install.sh" in paths , (
            f"the introspector must report @restspec paths; got {paths}"
        );
        assert "/llms.txt" in paths , (
            f"the introspector must report @restspec paths; got {paths}"
        );
    }
}


test "the core server answers a GET @restspec path with its own payload" {
    with TemporaryDirectory() as tmp {
        app = _restspec_app(tmp);
        client = JacTestClient.from_file(app, base_path=tmp);
        try {
            response = client.get("/install.sh");
            body = response.text;
            content_type = "".join(
                v
                for (k, v) in response.headers.items()
                if k.lower() == "content-type"
            );
            status = response.status_code;
        } finally {
            client.close();
        }
        assert status == 200 , f"GET /install.sh should serve the function; got {status}";
        assert "#!/usr/bin/env bash" in body , (
            f"GET /install.sh must return the function's payload, not a shell; got {body[:200]!r}"
        );
        assert "<!DOCTYPE html>" not in body , (
            "GET /install.sh must not fall through to the SPA catch-all"
        );
        assert "text/x-shellscript" in content_type , (
            f"the declared media type must be honored; got {content_type!r}"
        );
    }
}


test "an enveloped GET @restspec path still returns the transport envelope" {
    with TemporaryDirectory() as tmp {
        app = _restspec_app(tmp);
        client = JacTestClient.from_file(app, base_path=tmp);
        try {
            response = client.get("/llms.txt");
            status = response.status_code;
            body = response.text;
        } finally {
            client.close();
        }
        assert status == 200 , f"GET /llms.txt should serve the function; got {status}";
        assert "jac docs" in body , (
            f"GET /llms.txt must return the function's payload; got {body[:200]!r}"
        );
    }
}


test "a GET @restspec binds its arguments from the query string" {
    with TemporaryDirectory() as tmp {
        app = _restspec_app(tmp);
        client = JacTestClient.from_file(app, base_path=tmp);
        try {
            response = client.get("/echo", params={"word": "hello"});
            status = response.status_code;
            body = response.text;
        } finally {
            client.close();
        }
        assert status == 200 , f"GET /echo should serve the function; got {status}";
        assert "you said hello" in body , (
            "a GET route has no body, so its arguments come from the query "
            f"string; got {body[:200]!r}"
        );
    }
}


"""An app with a real client root export, so the SPA fallback has a page to
render and a 404 can only come from the dev guard."""
def _spa_app(project_dir: str) -> str {
    app = os.path.join(project_dir, "spa.jac");
    Path(app).write_text(
        'def:pub app -> JsxElement {\n' '    return <div>hello</div>;\n' '}\n',
        encoding="utf-8"
    );
    return app;
}


"""Records every attempt to build a production client bundle and fails it.

Returns (calls, spy): install the spy over the introspector's bundle builder
and a non-empty `calls` means the request path tried to build."""
def _build_spy -> tuple[(list[str], any)] {
    calls: list[str] = [];

    def spy(module: any) -> any {
        calls.append("build");
        raise RuntimeError("a production bundle build was attempted");
    }
    return (calls, spy);
}


"""Reset the config singleton this fixture pins, so a pinned root app does
not leak into the next test in this worker."""
def _reset_config {
    import from jaclang.project { config as config_mod }
    config_mod._config = None;
    config_mod._config_explicit = False;
    config_mod._config_by_root = {};
}


test "in dev the API port never builds a production client bundle" {
    # The hang: the SPA fallback called ensure_bundle() inside the request
    # thread, which in dev is a cold `bun install` plus a full vite build,
    # untimed and under a lock, so the request never got a response head.
    #
    # Both halves have to bite. The fixture exports a client root named `app`,
    # which the server infers as the root page, so the SPA fallback really
    # does have a page to render and a 404 can only come from the dev guard,
    # not from having nothing to serve. And the bundle builder is spied on,
    # so "refused" has to mean refused before the build, not a
    # ClientBundleError raised after one.
    import from jaclang.client.client_bundle { ClientBundleError }

    with TemporaryDirectory() as tmp {
        app = _spa_app(tmp);
        client = JacTestClient.from_file(app, base_path=tmp);
        (builds, spy) = _build_spy();
        try {
            introspector = client.server.introspector;
            setattr(introspector._bundle_builder, "build", spy);
            client.server.resolved_settings().dev = True;
            introspector.dev_mode = True;
            root_app = introspector.resolve_root_app();
            raised = "";
            try {
                introspector.ensure_bundle();
            } except ClientBundleError as e {
                raised = str(e);
            }
            unknown = client.get("/no-such-page");
            status = unknown.status_code;
            body = unknown.text;
        } finally {
            client.close();
            _reset_config();
        }
        assert root_app == "app" , (
            "the fixture must resolve a root app, or the 404 below proves "
            f"nothing; got {root_app!r}"
        );
        assert "dev server owns the client" in raised , (
            "ensure_bundle must refuse for the dev reason, before building; "
            f"got {raised!r}"
        );
        assert builds == [] , (
            "a bundle build in the request path is the hang itself; "
            f"the builder ran {len(builds)} time(s)"
        );
        assert status == 404 , (
            f"an unknown dev path must answer, not hang or render; got {status}"
        );
        assert "dev server on the web port" in body , (
            "the 404 has to be the dev guard's, not the render path failing "
            f"for some other reason; got {body[:200]!r}"
        );
    }
}


test "the dev proxy drops built-in prefixes the app claims as client routes" {
    # /docs is a built-in proxy prefix AND a page route on the jaclang.org
    # site. Forwarding it to the API port, which in dev no longer renders the
    # SPA, 404s every /docs/* URL in dev while --serve serves them.
    import from jaclang.client.vite_bundler { ViteBundler, DEV_PROXY_PREFIXES }

    with TemporaryDirectory() as tmp {
        entry_file = _min_project(tmp);
        bundler = ViteBundler(Path(tmp));
        config_path = bundler.create_vite_config(
            entry_file, is_dev=True, api_port=8123, client_paths=["/docs"]
        );
        text = config_path.read_text(encoding="utf-8");
    }
    assert '"/docs"' not in text , (
        f"a client-claimed prefix must not be proxied to the api port:\n{text}"
    );
    assert '"/walker"' in text , (
        f"unclaimed built-in prefixes must still be proxied:\n{text}"
    );
    assert "/docs" in DEV_PROXY_PREFIXES , (
        "the built-in list is what the server filters against"
    );
}


test "a declared literal path is proxied as an exact match, not a prefix" {
    # A prefix key routes /install.sh.bak and /install.shed to the API too.
    import from jaclang.client.vite_bundler { ViteBundler }

    with TemporaryDirectory() as tmp {
        entry_file = _min_project(tmp);
        bundler = ViteBundler(Path(tmp));
        config_path = bundler.create_vite_config(
            entry_file,
            is_dev=True,
            api_port=8123,
            api_paths=["/install.sh", "/board/{id}", "/"]
        );
        text = config_path.read_text(encoding="utf-8");
    }
    assert '"^/install\\\\.sh$"' in text , (
        f"a parameter-free path must proxy as an anchored regex:\n{text}"
    );
    assert '"/board"' in text , (
        f"a parameterised path keeps its static prefix:\n{text}"
    );
    assert '\n      "/": {' not in text , (
        f'"/" would route every SPA route to the api port:\n{text}'
    );
}


test "a path-less @restspec still serves its declared method" {
    # A spec that names only a method used to be filed under "path parameters,
    # websockets, webhooks and broadcast" and dropped: none of which applied.
    # The default route is the one the server already publishes for the name.
    with TemporaryDirectory() as tmp {
        app = _restspec_app(tmp);
        client = JacTestClient.from_file(app, base_path=tmp);
        try {
            paths = client.server.introspector.declared_api_paths();
            response = client.get("/function/raw_bytes");
            status = response.status_code;
        } finally {
            client.close();
        }
        assert status == 200 , (
            f"GET /function/raw_bytes must honor the declared method; got {status}"
        );
        assert "/function/raw_bytes" not in paths , (
            "a default route is already proxied by the built-in /function "
            f"prefix and needs no extra entry; got {paths}"
        );
    }
}


test "a raw payload is written through, bytes and None included" {
    # json.dumps(bytes) raises, and None used to serialise to the literal
    # text "null" instead of an empty body.
    with TemporaryDirectory() as tmp {
        app = _restspec_app(tmp);
        client = JacTestClient.from_file(app, base_path=tmp);
        try {
            raw = client.get("/function/raw_bytes");
            empty = client.get("/nothing");
        } finally {
            client.close();
        }
        assert raw.status_code == 200 , (
            f"a bytes payload must not 500 on serialisation; got {raw.status_code}"
        );
        assert "binary" in raw.text , (
            f"the bytes payload must reach the wire; got {raw.text[:80]!r}"
        );
        assert empty.status_code == 200 , (
            f"a None payload must still answer; got {empty.status_code}"
        );
        assert empty.text == "" , (
            f"a None payload is an empty body, not \"null\"; got {empty.text!r}"
        );
    }
}
