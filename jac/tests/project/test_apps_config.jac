"""Tests for [apps] workspaces: parsing, membership, ownership, overlays, plans."""

import os;
import tomllib;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.project.apps { AppConfig, implicit_app, parse_apps }
import from jaclang.project.config { JacConfig }
import from jaclang.project.kinds {
    KIND_SPECS,
    MOBILE_PLATFORMS,
    UI_DOM,
    UI_MOBUI,
    kind_has_client,
    kind_is_mobui,
    kind_ui,
    plan_app_run,
    plan_workspace,
    resolve_app_kind
}
import from jaclang.project.mobui_scope { mobui_module_exempt }
import jaclang.project.mobui_scope as pure_mod;
import jaclang.project.config as config_mod;

glob WORKSPACE_TOML = (
         '[project]\nname = "acme"\ndefault-app = "web"\n\n'
         '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
         '[apps.mobile]\nkind = "mobile"\npath = "mobile"\nplatform = "ios"\n\n'
         '[apps.social_graph]\nkind = "service"\n'
         'entry-point = "core/social_graph.jac"\nroute = "/api/social"\n\n'
         '[apps.web.serve]\nport = 8100\n\n'
         '[apps.social_graph.scale]\nhttp_activation = true\n\n'
         '[apps.mobile.dependencies.npm]\nlucide-react-native = "^0.4"\n\n'
         '[serve]\nport = 8090\n\n'
         '[dependencies.npm]\nreact = "^19"\n'
     ),
     MAIN_JAC = 'with entry {\n    print("hi");\n}\n';

def _app_name(app: any) -> str {
    if app is None {
        raise AssertionError("expected an app, got None");
    }
    return str(app.name);
}


"""Write a three-app workspace (web, mobile, file-rooted social_graph) under root_path."""
def write_workspace(root_path: Path, toml: str = WORKSPACE_TOML) -> Path {
    root_path.mkdir(parents=True, exist_ok=True);
    (root_path / "jac.toml").write_text(toml);
    (root_path / "web" / "pages").mkdir(parents=True, exist_ok=True);
    (root_path / "web" / "main.jac").write_text(MAIN_JAC);
    (root_path / "web" / "pages" / "home.jac").write_text(MAIN_JAC);
    (root_path / "mobile").mkdir(exist_ok=True);
    (root_path / "mobile" / "main.jac").write_text(MAIN_JAC);
    (root_path / "core").mkdir(exist_ok=True);
    (root_path / "core" / "social_graph.jac").write_text("walker:pub Hello {}\n");
    (root_path / "core" / "shared.jac").write_text(
        "def helper -> int {\n    return 1;\n}\n"
    );
    return root_path;
}

# ===========================================================================
# Parsing
# ===========================================================================
test "parse a three-app workspace" {
    cfg = JacConfig.from_toml_str(WORKSPACE_TOML);
    assert cfg.is_workspace;
    assert list(cfg.apps.keys()) == ["web", "mobile", "social_graph"];
    assert cfg.default_app == "web";
    assert cfg.project.default_app == "web";
    web = cfg.apps["web"];
    assert web.kind == "web-app";
    assert web.path == "web";
    assert not web.implicit;
    assert not web.is_file_rooted();
    assert web.ui() == "dom" , "a web-app renders the DOM";
    assert not hasattr(web, "client") and not hasattr(web, "client_kind") , (
        "AppConfig carries no client axis: the kind decides"
    );
    assert web.overlays == {"serve": {"port": 8100}};
    mobile = cfg.apps["mobile"];
    assert mobile.ui() == "mobui" , "a mobile app is mobUI by kind alone";
    assert mobile.platform == "ios";
    assert mobile.overlays["dependencies"]["npm"]["lucide-react-native"] == "^0.4";
    sg = cfg.apps["social_graph"];
    assert sg.is_file_rooted();
    assert sg.entry_point == "core/social_graph.jac";
    assert sg.route == "/api/social";
    assert sg.overlays == {"scale": {"http_activation": True}};
    assert cfg.serve.port == 8090 , "app overlays never leak into the base config";
    assert "scale" not in cfg.plugins;
}

test "no [apps] means one implicit app" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "hello"\nkind = "cli"\nentry-point = "app.jac"\n'
    );
    assert not cfg.is_workspace;
    assert list(cfg.apps.keys()) == ["hello"];
    app = cfg.apps["hello"];
    assert app.implicit;
    assert app.kind == "cli";
    assert app.entry_point == "app.jac";
    assert app.path == "";
    assert not app.is_file_rooted();
    assert app.ui() == "" , "a cli app has no client UI";
    assert cfg.resolve_app("") is app;
    assert cfg.default_app == "";
    bare = JacConfig.from_toml_str("[serve]\nport = 1\n");
    assert list(bare.apps.keys()) == ["main"];
    assert implicit_app(bare).name == "main";
}

test "[apps] next to [project] kind or entry-point is a hard error" {
    for key in [
        'kind = "cli"',
        'entry-point = "main.jac"',
        'entry_point = "main.jac"'
    ] {
        raised = False;
        try {
            JacConfig.from_toml_str(
                '[project]\nname = "x"\n' + key + '\n\n[apps.web]\nkind = "web-app"\n'
            );
        } except ValueError as e {
            raised = True;
            assert "[apps]" in str(e) , str(e);
        }
        assert raised , f"expected ValueError for [project] {key} alongside [apps]";
    }
}

test "default-app must name an app and needs [apps]" {
    raised = False;
    try {
        JacConfig.from_toml_str(
            '[project]\nname = "x"\ndefault-app = "zzz"\n\n[apps.web]\nkind = "web-app"\n'
        );
    } except ValueError as e {
        raised = True;
        assert "default-app" in str(e) , str(e);
    }
    assert raised , "expected ValueError for an unknown default-app";
    raised = False;
    try {
        JacConfig.from_toml_str('[project]\nname = "x"\ndefault-app = "x"\n');
    } except ValueError as e {
        raised = True;
        assert "[apps]" in str(e) , str(e);
    }
    assert raised , "expected ValueError for default-app without [apps]";
}

test "app validation rejects bad kinds, names and keys" {
    cases = [
        ('[apps.web]\nkind = "nope"\n', "kind="),
        ('[apps."a/b"]\nkind = "cli"\n', "cannot contain"),
        ('[apps."main.jac"]\nkind = "cli"\n', ".jac"),
        ('[apps.web]\npath = "web"\n', "required key 'kind'"),
        ('[apps.web]\nkind = "web-app"\ncolour = "red"\n', "unknown key"),
        ('[apps.web]\nkind = "web-app"\nroute = "api"\n', "must start with"),
        ('[apps.web]\nkind = "web-app"\npath = "/abs/web"\n', "relative")
    ];
    for (body, needle) in cases {
        raised = False;
        try {
            parse_apps({}, tomllib.loads(body)["apps"]);
        } except ValueError as e {
            raised = True;
            assert needle in str(e) , f"{body!r}: {e}";
        }
        assert raised , f"expected ValueError for {body!r}";
    }
}

test "the removed client and client_kind keys are hard errors with a pointer" {
    # `client` used to pick the client target (with aliases like "rn"), and
    # `client_kind` used to opt an app into mobUI. Both are gone: the kind
    # decides. Every spelling, and every value (even the old defaults), is
    # refused so a stale jac.toml never silently means something else.
    cases = [
        ('[apps.mobile]\nkind = "mobile"\nclient = "react-native"\n', "client"),
        ('[apps.mobile]\nkind = "mobile"\nclient = "rn"\n', "client"),
        ('[apps.web]\nkind = "web-app"\nclient = "web"\n', "client"),
        ('[apps.web]\nkind = "web-app"\nclient = "pwa"\n', "client"),
        ('[apps.web]\nkind = "web-app"\nclient = "flutter"\n', "client"),
        ('[apps.mobile]\nkind = "mobile"\nclient_kind = "mobui"\n', "client_kind"),
        ('[apps.web]\nkind = "web-app"\nclient_kind = "web"\n', "client_kind"),
        ('[apps.web]\nkind = "web-app"\nclient-kind = "mobui"\n', "client-kind"),
        ('[apps.web]\nkind = "web-app"\nclient_kind = "tv"\n', "client_kind")
    ];
    for (body, key) in cases {
        name = "mobile" if "[apps.mobile]" in body else "web";
        raised = False;
        try {
            parse_apps({}, tomllib.loads(body)["apps"]);
        } except ValueError as e {
            raised = True;
            msg = str(e);
            assert msg.startswith(f"[apps.{name}] '{key}' was removed: ") , (
                f"{body!r}: {msg}"
            );
            if key.startswith("client_") or key.startswith("client-") {
                assert "mobUI" in msg , msg;
            } else {
                assert "--platform web" in msg , msg;
                assert "kind" in msg , msg;
            }
        }
        assert raised , f"expected ValueError for {body!r}";
    }
    raised = False;
    try {
        JacConfig.from_toml_str(
            '[project]\nname = "x"\n\n[apps.mobile]\nkind = "mobile"\nclient = "rn"\n'
        );
    } except ValueError as e {
        raised = True;
        assert "[apps.mobile] 'client' was removed" in str(e) , str(e);
    }
    assert raised , "JacConfig.from_toml_str must surface the removed-key error";
}

test "[project] client_kind next to [apps] is no longer special-cased" {
    # Only kind / entry-point are refused beside [apps]; a stray
    # [project] client_kind is just an unknown key the loader ignores.
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "x"\nclient_kind = "mobui"\n\n[apps.web]\nkind = "web-app"\n'
    );
    assert cfg.is_workspace and list(cfg.apps) == ["web"];
    assert not hasattr(cfg.project, "client_kind");
    assert cfg.apps["web"].ui() == "dom";
}

test "dashed and underscored app keys are both accepted" {
    apps = parse_apps(
        {},
        tomllib.loads(
            '[apps.a]\nkind = "service"\nentry_point = "a.jac"\n\n'
            '[apps.b]\nkind = "service"\nentry-point = "b.jac"\n'
        )["apps"]
    );
    assert apps["a"].entry_point == "a.jac";
    assert apps["b"].entry_point == "b.jac";
}

# ===========================================================================
# Routes
# ===========================================================================
test "route defaults to /api/<name> and collisions are hard errors" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n'
        '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
        '[apps.api]\nkind = "service"\nentry-point = "api.jac"\n'
    );
    assert cfg.apps["web"].effective_route() == "/api/web";
    assert cfg.apps["api"].effective_route() == "/api/api";
    raised = False;
    try {
        JacConfig.from_toml_str(
            '[project]\nname = "acme"\n\n'
            '[apps.web]\nkind = "web-app"\npath = "web"\nroute = "/api/x"\n\n'
            '[apps.api]\nkind = "service"\nentry-point = "api.jac"\nroute = "/api/x"\n'
        );
    } except ValueError as e {
        raised = True;
        assert "/api/x" in str(e) , str(e);
        assert "web" in str(e) and "api" in str(e) , str(e);
    }
    assert raised , "expected ValueError for a route collision";
    no_server = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n'
        '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
        '[apps.tool]\nkind = "cli"\npath = "tool"\nroute = "/api/web"\n'
    );
    assert list(no_server.apps.keys()) == ["web", "tool"] , (
        "apps without a server never claim routes"
    );
}

# ===========================================================================
# Membership
# ===========================================================================
test "membership: dir-rooted, file-rooted and shared" {
    with TemporaryDirectory() as td {
        root_path = write_workspace(Path(td) / "acme");
        cfg = JacConfig.load(root_path / "jac.toml");
        assert _app_name(
            cfg.app_for_path(str(root_path / "web" / "pages" / "home.jac"))
        )
            == "web";
        assert _app_name(cfg.app_for_path(str(root_path / "mobile" / "main.jac")))
            == "mobile";
        sg_owner = cfg.app_for_path(str(root_path / "core" / "social_graph.jac"));
        assert sg_owner is not None and sg_owner.name == "social_graph";
        assert cfg.app_for_path(str(root_path / "core" / "shared.jac")) is None;
        assert cfg.app_for_path(str(root_path / "jac.toml")) is None;
        assert cfg.app_for_path(str(Path(td) / "elsewhere.jac")) is None;
        sg = cfg.apps["social_graph"];
        assert sg.root_dir(str(root_path)) == "";
        assert sg.entry_path(str(root_path))
            == str(root_path / "core" / "social_graph.jac");
        assert sg.contains(
            str(root_path), str(root_path / "core" / "social_graph.jac")
        );
        assert not sg.contains(str(root_path), str(root_path / "core" / "shared.jac"));
        web = cfg.apps["web"];
        assert web.root_dir(str(root_path)) == str(root_path / "web");
        assert web.entry_path(str(root_path)) == str(root_path / "web" / "main.jac");
    }
}

test "membership: nearest root_path wins" {
    with TemporaryDirectory() as td {
        root_path = write_workspace(
            Path(td) / "acme",
            '[project]\nname = "acme"\n\n'
            '[apps.site]\nkind = "web-app"\npath = "web"\n\n'
            '[apps.admin]\nkind = "web-app"\npath = "web/admin"\n'
        );
        (root_path / "web" / "admin").mkdir();
        (root_path / "web" / "admin" / "main.jac").write_text(MAIN_JAC);
        cfg = JacConfig.load(root_path / "jac.toml");
        assert _app_name(
            cfg.app_for_path(str(root_path / "web" / "admin" / "main.jac"))
        )
            == "admin";
        assert _app_name(cfg.app_for_path(str(root_path / "web" / "main.jac")))
            == "site";
        assert _app_name(
            cfg.app_for_path(str(root_path / "web" / "pages" / "home.jac"))
        )
            == "site";
    }
}

test "membership: the implicit app owns the whole project root_path" {
    with TemporaryDirectory() as td {
        root_path = Path(td) / "hello";
        (root_path / "lib").mkdir(parents=True);
        (root_path / "jac.toml").write_text(
            '[project]\nname = "hello"\nkind = "cli"\n'
        );
        (root_path / "lib" / "x.jac").write_text(MAIN_JAC);
        cfg = JacConfig.load(root_path / "jac.toml");
        owner = cfg.app_for_path(str(root_path / "lib" / "x.jac"));
        assert owner is not None and owner.implicit;
        assert owner.root_dir(str(root_path)) == str(root_path);
        assert cfg.app_for_path(str(Path(td) / "other.jac")) is None;
        bare = JacConfig(project_root=root_path);
        assert not bare.apps;
        bare_owner = bare.app_for_path(str(root_path / "lib" / "x.jac"));
        assert bare_owner is not None and bare_owner.implicit , (
            "a config built without an [apps] table still owns its root_path"
        );
        assert bare.app_for_path(str(Path(td) / "other.jac")) is None;
    }
}

# ===========================================================================
# Ownership (decision 2)
# ===========================================================================
test "owner: explicit file-rooted service app, default app, ambiguity without one" {
    with TemporaryDirectory() as td {
        root_path = write_workspace(Path(td) / "acme");
        cfg = JacConfig.load(root_path / "jac.toml");
        assert [a.name for a in cfg.serving_apps()] == ["web", "social_graph"];
        (owner, ambiguous) = cfg.owner_app_for_path(
            str(root_path / "core" / "social_graph.jac")
        );
        assert owner is not None and owner.name == "social_graph";
        assert not ambiguous;
        (owner, ambiguous) = cfg.owner_app_for_path(
            str(root_path / "core" / "shared.jac")
        );
        assert owner is not None and owner.name == "web";
        assert not ambiguous;
        no_default = write_workspace(
            Path(td) / "acme2", WORKSPACE_TOML.replace('default-app = "web"\n', "")
        );
        cfg2 = JacConfig.load(no_default / "jac.toml");
        (owner, ambiguous) = cfg2.owner_app_for_path(
            str(no_default / "core" / "shared.jac")
        );
        assert owner is None;
        assert ambiguous;
        (owner, ambiguous) = cfg.owner_app_for_path(
            str(root_path / "mobile" / "main.jac")
        );
        assert owner is not None and owner.name == "mobile";
        assert not ambiguous;
    }
}

test "owner: the sole serving app owns shared modules implicitly" {
    with TemporaryDirectory() as td {
        root_path = write_workspace(
            Path(td) / "acme",
            '[project]\nname = "acme"\n\n'
            '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
            '[apps.mobile]\nkind = "mobile"\npath = "mobile"\n'
        );
        cfg = JacConfig.load(root_path / "jac.toml");
        (owner, ambiguous) = cfg.owner_app_for_path(
            str(root_path / "core" / "shared.jac")
        );
        assert owner is not None and owner.name == "web";
        assert not ambiguous;
    }
}

test "owner: no serving apps means no owner and no ambiguity" {
    with TemporaryDirectory() as td {
        root_path = write_workspace(
            Path(td) / "acme",
            '[project]\nname = "acme"\n\n'
            '[apps.tool]\nkind = "cli"\npath = "web"\n\n'
            '[apps.mobile]\nkind = "mobile"\npath = "mobile"\n'
        );
        cfg = JacConfig.load(root_path / "jac.toml");
        assert cfg.serving_apps() == [];
        (owner, ambiguous) = cfg.owner_app_for_path(
            str(root_path / "core" / "shared.jac")
        );
        assert owner is None;
        assert not ambiguous;
    }
}

# ===========================================================================
# resolve_app
# ===========================================================================
test "resolve_app: explicit, default, sole, ambiguous" {
    cfg = JacConfig.from_toml_str(WORKSPACE_TOML);
    assert cfg.resolve_app("mobile").name == "mobile";
    assert cfg.resolve_app("").name == "web" , "default-app wins";
    raised = False;
    try {
        cfg.resolve_app("nope");
    } except ValueError as e {
        raised = True;
        assert "nope" in str(e) and "web" in str(e) , str(e);
    }
    assert raised , "expected ValueError for an unknown app";
    two = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n'
        '[apps.a]\nkind = "cli"\npath = "a"\n\n[apps.b]\nkind = "cli"\npath = "b"\n'
    );
    raised = False;
    try {
        two.resolve_app("");
    } except ValueError as e {
        raised = True;
        assert "default-app" in str(e) , str(e);
    }
    assert raised , "expected ValueError when no default app in a multi-app workspace";
    one = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n[apps.a]\nkind = "cli"\npath = "a"\n'
    );
    assert one.resolve_app("").name == "a" , "a sole app is the default";
    assert JacConfig().resolve_app("").implicit , "a bare config still resolves";
}

# ===========================================================================
# effective_for_app
# ===========================================================================
test "effective_for_app layers base, app overlays, profile and local" {
    config_mod._config = None;
    with TemporaryDirectory() as td {
        root_path = write_workspace(
            Path(td) / "acme",
            '[project]\nname = "acme"\n\n'
            '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
            '[apps.mobile]\nkind = "mobile"\npath = "mobile"\n\n'
            '[apps.web.serve]\nport = 8100\nsession = "web-sess"\n'
            'conflict_max_attempts = 3\n\n'
            '[apps.web.byllm]\nmodel = "web-model"\n\n'
            '[apps.mobile.dependencies.npm]\nlucide-react-native = "^0.4"\n\n'
            '[serve]\nport = 8090\nsession = "base-sess"\n\n'
            '[dependencies.npm]\nreact = "^19"\n\n'
            '[byllm]\nmodel = "base-model"\ntemperature = 0.1\n\n'
            '[environments.prod]\n[environments.prod.serve]\nsession = "prod-sess"\n'
        );
        (root_path / "jac.prod.toml").write_text(
            '[serve]\nconflict_max_attempts = 9\n'
        );
        (root_path / "jac.local.toml").write_text('[serve]\nconflict_backoff_ms = 7\n');
        cfg = JacConfig.discover(root_path, profile="prod");
        assert cfg is not None;
        assert cfg.active_profile == "prod";
        assert cfg.serve.port == 8090;
        assert cfg.serve.session == "prod-sess";
        web = cfg.effective_for_app("web");
        assert web.serve.port == 8100 , "app overlay beats base";
        assert web.serve.session == "prod-sess" , "[environments.prod] beats the overlay";
        assert web.serve.conflict_max_attempts == 9 , "jac.prod.toml beats the overlay";
        assert web.serve.conflict_backoff_ms == 7 , "jac.local.toml still applies";
        assert web.plugins["byllm"] == {"model": "web-model", "temperature": 0.1} , (
            "capability tables deep-merge"
        );
        assert web.active_profile == "prod";
        assert web.is_workspace;
        assert list(web.apps.keys()) == ["web", "mobile"];
        assert web.project_root == cfg.project_root;
        assert [p.name for p in web.config_files]
            == ["jac.toml", "jac.prod.toml", "jac.local.toml"];
        assert cfg.serve.port == 8090 , "the source config is untouched";
        mobile = cfg.effective_for_app("mobile");
        assert mobile.serve.port == 8090;
        assert mobile.plugin_dependencies["npm"]["lucide-react-native"] == "^0.4";
        assert mobile.plugin_dependencies["npm"]["react"] == "^19";
        assert "lucide-react-native" not in cfg.plugin_dependencies["npm"];
        again = web.effective_for_app("web");
        assert again.serve.port == 8100 and again.serve.conflict_backoff_ms == 7 , (
            "effective_for_app is idempotent"
        );
        raised = False;
        try {
            cfg.effective_for_app("nope");
        } except ValueError {
            raised = True;
        }
        assert raised , "expected ValueError for an unknown app";
    }
}

test "effective_for_app replays a directly applied profile" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n[apps.web]\nkind = "web-app"\npath = "web"\n\n'
        '[apps.web.serve]\nport = 8100\n\n[serve]\nport = 8090\n\n'
        '[environments.dev]\n[environments.dev.serve]\nsession = "dev"\n'
    );
    cfg.apply_profile("dev");
    web = cfg.effective_for_app("web");
    assert web.serve.port == 8100;
    assert web.serve.session == "dev";
}

test "effective_for_app of the implicit app is a plain clone" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "hello"\n\n[serve]\nport = 8090\n'
    );
    clone = cfg.effective_for_app("hello");
    assert clone is not cfg;
    assert clone.serve.port == 8090;
    assert clone.resolve_app("").implicit;
}

# ===========================================================================
# Kinds and plans
# ===========================================================================
test "kind specs carry ui and has_server; the client axis is gone" {
    assert UI_DOM == "dom" and UI_MOBUI == "mobui";
    assert MOBILE_PLATFORMS == ["android", "ios", "web"];
    assert KIND_SPECS["web-app"].ui == "dom";
    assert KIND_SPECS["web-app"].has_server;
    assert KIND_SPECS["service"].ui == "";
    assert KIND_SPECS["service"].has_server;
    assert KIND_SPECS["service-mesh"].has_server;
    assert KIND_SPECS["web-static"].ui == "dom";
    assert not KIND_SPECS["web-static"].has_server;
    assert KIND_SPECS["mobile"].ui == "mobui";
    assert KIND_SPECS["mobile"].flags == {} , (
        "the mobile kind has no client flag: the kind is the target"
    );
    assert KIND_SPECS["desktop"].ui == "dom";
    assert KIND_SPECS["desktop"].flags == {};
    assert KIND_SPECS["js-package"].ui == "dom";
    assert KIND_SPECS["js-package"].codespace == "client";
    for kind in ["cli", "cli-native", "native-binary", "native-lib", "py-package"] {
        assert KIND_SPECS[kind].ui == "";
        assert not KIND_SPECS[kind].has_server;
    }
    for spec in KIND_SPECS.values() {
        assert not hasattr(spec, "client_target") , "KindSpec.client_target is gone";
        assert "client" not in spec.flags , f"{spec.name}: no client flag on any kind";
    }
    # The helpers read the same table.
    assert kind_ui("mobile") == "mobui" and kind_ui("web-app") == "dom";
    assert kind_ui("cli") == "" and kind_ui("banana") == "";
    assert kind_has_client("web-static") and kind_has_client("desktop");
    assert kind_has_client("js-package") and kind_has_client("mobile");
    assert not kind_has_client("service") and not kind_has_client("");
    assert kind_is_mobui("mobile");
    for kind in ["web-app", "web-static", "desktop", "js-package", "cli", ""] {
        assert not kind_is_mobui(kind) , f"{kind!r} is not mobUI";
    }
    import jaclang.project as project_pkg;
    for name in ["kind_ui", "kind_has_client", "kind_is_mobui"] {
        assert name in project_pkg.__all__ , f"jaclang.project must export {name}";
        assert callable(getattr(project_pkg, name));
    }
    for gone in ["CLIENT_TARGETS", "normalize_client_target", "VALID_CLIENT_KINDS"] {
        assert gone not in project_pkg.__all__ , f"{gone} is gone";
        assert not hasattr(project_pkg, gone) , f"{gone} is gone";
    }
}

test "resolve_app_kind infers only for the implicit app" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "x"\n\n[dependencies]\njac-client = "*"\n'
    );
    app = cfg.resolve_app("");
    assert app.implicit and app.kind == "";
    assert resolve_app_kind(cfg, app, "") == "web-app";
    assert cfg.resolved_kind(app) == "web-app";
    plain = JacConfig.from_toml_str('[project]\nname = "x"\n');
    assert resolve_app_kind(plain, plain.resolve_app(""), "") == "cli";
    explicit = AppConfig(name="svc", kind="service", entry_point="svc.jac");
    assert resolve_app_kind(cfg, explicit, "") == "service";
    assert explicit.ui() == "";
}

test "plan_workspace produces one plan per app" {
    with TemporaryDirectory() as td {
        root_path = write_workspace(Path(td) / "acme");
        cfg = JacConfig.load(root_path / "jac.toml");
        plans = plan_workspace(cfg, str(root_path));
        assert [p.app for p in plans] == ["web", "mobile", "social_graph"];
        by_app = {p.app: p for p in plans};
        web = by_app["web"];
        assert web.kind == "web-app";
        assert web.action == "serve";
        assert web.entry_path == str(root_path / "web" / "main.jac");
        assert web.flags["port"] == 8100 , "the app's serve overlay feeds the plan";
        assert web.flags["dev"] is True;
        assert web.command_line().startswith("jac run web");
        mobile = by_app["mobile"];
        assert mobile.action == "build";
        assert mobile.spec.ui == "mobui";
        assert "client" not in mobile.flags , "plans carry no client flag";
        assert mobile.flags == {"platform": "ios"};
        assert mobile.command_line() == "jac build mobile --platform ios";
        assert mobile.entry_path == str(root_path / "mobile" / "main.jac");
        sg = by_app["social_graph"];
        assert sg.kind == "service";
        assert sg.entry_path == str(root_path / "core" / "social_graph.jac");
        assert sg.flags["port"] == 8090 , "no overlay: the base [serve] port applies";
        assert sg.flags["no_client"] is True;
        assert sg.command_line().startswith("jac run social_graph");
    }
}

test "plan_app_run for the implicit app keeps the single-app command line" {
    with TemporaryDirectory() as td {
        root_path = Path(td) / "hello";
        root_path.mkdir();
        (root_path / "jac.toml").write_text(
            '[project]\nname = "hello"\nkind = "cli"\n'
        );
        (root_path / "main.jac").write_text(MAIN_JAC);
        cfg = JacConfig.load(root_path / "jac.toml");
        plan = plan_app_run(cfg, str(root_path), cfg.resolve_app(""));
        assert plan.app == "";
        assert plan.kind == "cli";
        assert plan.command_line() == "jac run main.jac";
        assert plan.entry_path == str(root_path / "main.jac");
        assert plan_workspace(cfg, str(root_path))[0].entry_path == plan.entry_path;
    }
}

test "plan_app_run honors an entry overridden and names named-app outputs" {
    with TemporaryDirectory() as td {
        root_path = write_workspace(
            Path(td) / "acme",
            '[project]\nname = "acme"\n\n[apps.bin]\nkind = "native-binary"\npath = "web"\n'
        );
        cfg = JacConfig.load(root_path / "jac.toml");
        plan = plan_app_run(cfg, str(root_path), cfg.apps["bin"]);
        assert plan.flags["output"] == str(root_path / "dist" / "bin" / "main");
        overridden = plan_app_run(
            cfg,
            str(root_path),
            cfg.apps["bin"],
            entry_override=str(root_path / "web" / "pages" / "home.jac")
        );
        assert overridden.entry_path == str(root_path / "web" / "pages" / "home.jac");
        assert overridden.flags["output"] == str(root_path / "dist" / "bin" / "home");
    }
}

test "plan_app_run raises when a needs-entry app has no entry file" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n[apps.web]\nkind = "web-app"\npath = "web"\n'
    );
    with TemporaryDirectory() as td {
        raised = False;
        try {
            plan_app_run(cfg, td, cfg.apps["web"]);
        } except ValueError as e {
            raised = True;
            assert "web" in str(e) , str(e);
        }
        assert raised , "expected ValueError for a missing entry file";
    }
}

# ===========================================================================
# mobUI scope lane
# ===========================================================================
test "the mobUI guard scope answers from the owning app's kind" {
    # The compiler reads the app's ui off the workspace facts: a mobile app
    # switches the guard on for its root_dir; everything else is exempt.
    import from jaclang.compiler.placement.workspace { app_for_path }
    config_mod.set_config(None);
    with TemporaryDirectory() as td {
        root_path = write_workspace(Path(td) / "acme");
        try {
            mobile_main = str(root_path / "mobile" / "main.jac");
            web_main = str(root_path / "web" / "main.jac");
            shared = str(root_path / "core" / "shared.jac");
            mobile_app = app_for_path(mobile_main);
            assert mobile_app is not None and mobile_app.ui == "mobui";
            web_app = app_for_path(web_main);
            assert web_app is not None and web_app.ui == "dom";
            assert app_for_path(shared) is None , "shared code has no app";
            enforced_root = mobile_app.root_dir;
            assert Path(enforced_root).resolve() == (root_path / "mobile").resolve();
            assert not mobui_module_exempt(mobile_main, enforced_root);
            assert mobui_module_exempt(web_main, enforced_root) , (
                "another app's module is outside the mobile root"
            );
            assert mobui_module_exempt(shared, enforced_root) , (
                "shared code is outside the mobile root"
            );
            assert mobui_module_exempt(mobile_main, None) , "no root: nothing enforced";
            assert mobui_module_exempt(mobile_main, "") , "empty root: nothing enforced";
            assert not hasattr(mobile_app, "client_kind") , (
                "AppSpec carries ui, not client_kind"
            );
        } finally {
            config_mod.set_config(None);
        }
    }
}

test "the pure mobUI scope lane names no project config" {
    src = Path(pure_mod.__file__).read_text();
    assert "jaclang.project.config" not in src , (
        "mobui_scope grew a project-config dependency; that puts the config "
        "lane back into every pass closure that imports it. The kind is a "
        "module fact stamped by the driver."
    );
    import importlib.util;
    for gone in ["jaclang.project.client_kind", "jaclang.project.client_kind_paths"] {
        assert importlib.util.find_spec(gone) is None , f"{gone} was deleted";
    }
}

# ===========================================================================
# The compiler-side app fact digest
# ===========================================================================
glob _toml_bumps: dict[str, int] = {};

"""Rewrite the workspace toml and bump its mtime so the workspace cache misses."""
def _rewrite_toml(root_path: Path, toml: str) {
    toml_path = root_path / "jac.toml";
    toml_path.write_text(toml);
    key = str(toml_path);
    _toml_bumps[key] = _toml_bumps.get(key, 0) + 1;
    st = os.stat(toml_path);
    bump = 10 * _toml_bumps[key];
    os.utime(toml_path, (st.st_atime + bump, st.st_mtime + bump));
}

test "app_fact_digest tracks route, root, entry-point and file rooting" {
    import from jaclang.compiler.placement.workspace { app_fact_digest, app_for_path }
    with TemporaryDirectory() as td {
        root_path = write_workspace(Path(td) / "acme");
        (root_path / "core" / "social_graph2.jac").write_text("walker:pub Hi {}\n");
        (root_path / "web2").mkdir();
        (root_path / "web2" / "main.jac").write_text(MAIN_JAC);
        (root_path / "web" / "index.jac").write_text(MAIN_JAC);
        sg_file = str(root_path / "core" / "social_graph.jac");
        web_file = str(root_path / "web" / "main.jac");
        sg_before = app_fact_digest(app_for_path(sg_file));
        web_before = app_fact_digest(app_for_path(web_file));
        assert len(sg_before) == 12 and len(web_before) == 12;
        assert sg_before != web_before;
        assert app_fact_digest(app_for_path(sg_file)) == sg_before , "stable";
        _rewrite_toml(root_path, WORKSPACE_TOML.replace('/api/social', '/api/graph'));
        sg_route = app_fact_digest(app_for_path(sg_file));
        assert sg_route != sg_before , "the effective route is part of the digest";
        assert app_fact_digest(app_for_path(web_file)) == web_before , (
            "another app's route does not perturb this app"
        );
        _rewrite_toml(
            root_path,
            WORKSPACE_TOML.replace(
                'route = "/api/social"', 'route = "/api/social_graph"'
            )
        );
        sg_default = app_fact_digest(app_for_path(sg_file));
        _rewrite_toml(root_path, WORKSPACE_TOML.replace('route = "/api/social"\n', ""));
        assert app_fact_digest(app_for_path(sg_file)) == sg_default , (
            "an explicit route equal to the /api/<name> default is the same fact"
        );
        _rewrite_toml(
            root_path,
            WORKSPACE_TOML.replace("core/social_graph.jac", "core/social_graph2.jac")
        );
        sg2_file = str(root_path / "core" / "social_graph2.jac");
        assert app_fact_digest(app_for_path(sg2_file)) != sg_before , (
            "the entry-point is part of the digest"
        );
        _rewrite_toml(
            root_path, WORKSPACE_TOML.replace('path = "web"\n', 'path = "web2"\n')
        );
        web2_file = str(root_path / "web2" / "main.jac");
        assert app_fact_digest(app_for_path(web2_file)) != web_before , (
            "the app root is part of the digest"
        );
        _rewrite_toml(
            root_path,
            WORKSPACE_TOML.replace(
                '[apps.web]\nkind = "web-app"\npath = "web"\n',
                '[apps.web]\nkind = "web-app"\nentry-point = "web/main.jac"\n'
            )
        );
        web_rooted = app_fact_digest(app_for_path(web_file));
        assert web_rooted != web_before , "file rooting is part of the digest";
        assert app_for_path(str(root_path / "web" / "index.jac")) is None , (
            "a file-rooted app claims only its entry"
        );
    }
}

test "app_fact_digest does not depend on where the workspace is checked out" {
    import from jaclang.compiler.placement.workspace { app_fact_digest, app_for_path }
    with TemporaryDirectory() as td_a, TemporaryDirectory() as td_b {
        root_a = write_workspace(Path(td_a) / "acme");
        root_b = write_workspace(Path(td_b) / "elsewhere" / "acme");
        for rel in [("web", "main.jac"), ("core", "social_graph.jac")] {
            da = app_fact_digest(app_for_path(str(root_a.joinpath(*rel))));
            db = app_fact_digest(app_for_path(str(root_b.joinpath(*rel))));
            assert da == db , f"{rel}: {da} != {db}";
        }
    }
}
