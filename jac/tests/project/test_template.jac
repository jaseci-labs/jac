import os;
import base64;
import shutil;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.project.config { JacConfig }
import from jaclang.project.template_loader {
    load_template_from_directory,
    scaffold_app
}
import from jaclang.project.template_registry {
    ProjectTemplate,
    TemplateRegistry,
    get_template_registry,
    initialize_template_registry
}

glob FIXTURE_BASE = str(Path(__file__).parent / "fixtures");

def _app_name(app: any) -> str {
    if app is None {
        raise AssertionError("expected an app, got None");
    }
    return str(app.name);
}


def fixture_path(filename: str) -> str {
    p = os.path.join(FIXTURE_BASE, filename);
    if not os.path.exists(p) {
        raise FileNotFoundError(f"Fixture not found: {p}");
    }
    return p;
}

def _publishable(tmpdir: str, hook: bool = False) -> Path {
    template_dir = Path(tmpdir) / "starter";
    (template_dir / "assets").mkdir(parents=True);
    options = "\n[jacpack.options]\npost_create_hook = \"os:getcwd\"\n" if hook else "";
    (template_dir / "jac.toml").write_text(
        "[project]\nname = \"{{name}}\"\nversion = \"0.1.0\"\nentry-point = \"main\"\n\n"
        "[jacpack]\nname = \"acme/starter\"\nversion = \"1.2.0\"\n"
        "description = \"A starter template\"\n"
            + options
    );
    (template_dir / "main.jac").write_text(
        "with entry {\n    print(\"{{name}}\");\n}\n"
    );
    (template_dir / "assets" / "logo.png").write_bytes(
        b"\x89PNG\r\n\x1a\n" + bytes(range(256))
    );
    return template_dir;
}

# --- Template packages ---
test "a template project builds into a template package" {
    import from jaclang.packages.artifact { build_package }
    import from jaclang.packages.templates { unpack_template }
    with TemporaryDirectory() as tmpdir {
        built = build_package(JacConfig.load(_publishable(tmpdir) / "jac.toml"));
        assert built.manifest["role"] == "template";
        assert built.manifest["name"] == "acme/starter";
        assert built.manifest["version"] == "1.2.0";
        unpacked = unpack_template(built.data, "acme/starter");
        try {
            assert not (unpacked / "_precompiled").exists();
            template = load_template_from_directory(unpacked, allow_hooks=False);
            assert template.name == "acme/starter";
            assert "{{name}}" in template.files["main.jac"];
            logo = template.files["assets/logo.png"];
            assert logo.startswith("base64:");
            assert base64.b64decode(logo[7:]).startswith(b"\x89PNG");
        } finally {
            shutil.rmtree(unpacked, ignore_errors=True);
        }
    }
}

test "a template from a package cannot run a post-create hook" {
    with TemporaryDirectory() as tmpdir {
        template_dir = _publishable(tmpdir, hook=True);
        assert load_template_from_directory(template_dir).post_create is not None;
        raised = False;
        try {
            load_template_from_directory(template_dir, allow_hooks=False);
        } except ValueError as e {
            raised = True;
            assert "post_create_hook" in str(e);
        }
        assert raised;
    }
}

test "a published template resolves by name and range" {
    import os;
    import from unittest.mock { patch }
    import from jaclang.packages.templates { fetch_template }
    import from tests.packages.fixture_registry {
        FixtureRegistry,
        fresh_dir,
        isolated_env
    }
    tmp = fresh_dir("jac-template-");
    registry = FixtureRegistry.create(tmp / "registry");
    with patch.dict(os.environ, isolated_env(tmp, registry.base_dir)) {
        registry.publish(_publishable(str(tmp)));
        unpacked = fetch_template("acme/starter@^1.1");
        try {
            template = load_template_from_directory(unpacked, allow_hooks=False);
            assert template.description == "A starter template";
        } finally {
            shutil.rmtree(unpacked, ignore_errors=True);
        }
    }
}

# --- LoadTemplateFromDirectory tests ---
test "load from directory" {
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    assert isinstance(template, ProjectTemplate);
    assert template.name == "minimal";
}

test "load extracts config" {
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    assert "project" in template.config;
    assert template.config["project"]["name"] == "{{name}}";
    assert template.config["project"]["entry-point"] == "main";
}

# --- TemplateRegistration tests ---
test "register template from dict" {
    initialize_template_registry();
    registry = get_template_registry();
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    registry.register(template.to_dict());
    assert registry.get("minimal") is not None;
}

test "get registered template" {
    initialize_template_registry();
    registry = get_template_registry();
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    registry.register(template.to_dict());
    retrieved = registry.get("minimal");
    assert retrieved is not None;
    assert retrieved.name == "minimal";
    assert retrieved.description == "A minimal test template";
}

test "list templates includes registered" {
    initialize_template_registry();
    registry = get_template_registry();
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    registry.register(template.to_dict());
    templates = registry.list_templates();
    names = [name for (name, _) in templates];
    assert "minimal" in names;
}

# --- Workspace templates and app scaffolds ---
def _service_template -> ProjectTemplate {
    return ProjectTemplate(
        name="service",
        description="svc",
        kind="service",
        config={
            "project": {"name": "{{name}}", "entry-point": "main", "kind": "service"}
        },
        files={"main.jac": "walker:pub Ping {}\n", "README.md": "# {{name}}\n"}
    );
}

test "template dir with [apps] loads as a workspace template" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(tmpdir) / "ws";
        (template_dir / "web").mkdir(parents=True);
        (template_dir / "jac.toml").write_text(
            '[project]\nname = "{{name}}"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n[apps.api]\nkind = "service"\nentry-point = "core.api"\n\n[jacpack]\nname = "ws"\ndescription = "workspace template"\n'
        );
        (template_dir / "web" / "main.jac").write_text("with entry {}\n");
        tmpl = load_template_from_directory(template_dir);
        assert tmpl.kind == "workspace";
        assert "jacpack" not in tmpl.config;
        assert set(tmpl.config["apps"].keys()) == {"web", "api"};
        assert "web/main.jac" in tmpl.files;
    }
}

test "a single-app [apps] template takes that app's kind" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(tmpdir) / "mob";
        template_dir.mkdir();
        (template_dir / "jac.toml").write_text(
            '[project]\nname = "{{name}}"\ndefault-app = "main"\n\n[apps.main]\nkind = "mobile"\nentry-point = "main"\n\n[dependencies.npm]\nreact = "^18.2.0"\n\n[dependencies.npm.native]\nreact-native-svg = "^15.13.0"\n\n[jacpack]\nname = "mobile"\ndescription = "mobUI app"\n'
        );
        (template_dir / "main.jac").write_text("with entry {}\n");
        tmpl = load_template_from_directory(template_dir);
        assert tmpl.kind == "mobile" , "one app: the template is that app's kind";
        registry = TemplateRegistry();
        registry.register(tmpl.to_dict());
        found = registry.get_by_kind("mobile");
        assert found is not None and found.name == "mobile";
        assert registry.get_by_kind("workspace") is None;
    }
}

test "template dir with an invalid [apps] table is rejected" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(tmpdir) / "ws";
        template_dir.mkdir();
        (template_dir / "jac.toml").write_text(
            '[project]\nname = "{{name}}"\nkind = "cli"\n\n[apps.web]\nkind = "web-app"\nentry-point = "main"\n\n[jacpack]\nname = "ws"\ndescription = "bad"\n'
        );
        raised = False;
        try {
            load_template_from_directory(template_dir);
        } except ValueError as e {
            raised = True;
            assert "[apps]" in str(e) , str(e);
        }
        assert raised , "Expected ValueError for [project] kind alongside [apps]";
    }
}

test "scaffold_app appends an [apps] table and copies the template" {
    with TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir) / "proj";
        (root_path / "web").mkdir(parents=True);
        (root_path / "jac.toml").write_text(
            '[project]\nname = "acme"\nversion = "0.1.0"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n[serve]\nport = 8090\n'
        );
        (root_path / "web" / "main.jac").write_text("with entry {}\n");
        created = scaffold_app(
            str(root_path), "api", "service", "services/api", _service_template()
        );
        assert str(root_path / "services" / "api" / "main.jac") in created;
        assert str(root_path / "services" / "api" / "README.md") in created;
        assert (root_path / "services" / "api" / "README.md").read_text() == "# api\n";
        text = (root_path / "jac.toml").read_text();
        assert "[serve]\nport = 8090" in text , "existing content must be untouched";
        assert '[apps.web]\nkind = "web-app"\nentry-point = "web.main"' in text;
        assert "[apps.api]" in text;
        assert "jacpack" not in text;
        cfg = JacConfig.load(root_path / "jac.toml");
        assert list(cfg.apps.keys()) == ["web", "api"];
        assert cfg.apps["api"].kind == "service";
        assert cfg.apps["api"].entry_point == "services.api.main";
    }
}

def _mobile_template -> ProjectTemplate {
    return ProjectTemplate(
        name="mobile",
        description="mobUI app",
        kind="mobile",
        config={
            "project": {"name": "{{name}}", "default-app": "main"},
            "apps": {
                "main": {"kind": "mobile", "platform": "ios", "entry-point": "app"}
            },
            "dependencies": {
                "npm": {
                    "react": "^18.2.0",
                    "lucide-react-native": "^0.469.0",
                    "native": {"react-native-svg": "^15.13.0"}
                }
            }
        },
        files={"app.jac": "with entry {}\n", "theme.jac": "obj Theme {}\n"}
    );
}

test "scaffold_app copies the sole app's keys and npm deps as overlays" {
    with TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir) / "proj";
        (root_path / "web").mkdir(parents=True);
        (root_path / "jac.toml").write_text(
            '[project]\nname = "acme"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n[dependencies.npm]\nreact = "^19"\n'
        );
        (root_path / "web" / "main.jac").write_text("with entry {}\n");
        created = scaffold_app(
            str(root_path), "mobile", "mobile", "mobile", _mobile_template()
        );
        assert str(root_path / "mobile" / "app.jac") in created;
        assert str(root_path / "mobile" / "theme.jac") in created;
        text = (root_path / "jac.toml").read_text();
        assert "[apps.mobile.dependencies.npm]" in text;
        assert "[apps.mobile.dependencies.npm.native]" in text;
        cfg = JacConfig.load(root_path / "jac.toml");
        app = cfg.apps["mobile"];
        assert app.kind == "mobile";
        assert app.ui() == "mobui" , "kind = mobile is mobUI with no other key";
        assert app.platform == "ios";
        assert app.entry_point == "mobile.app" , "entry-point comes from the app table";
        assert app.entry_path(str(root_path)) == str(root_path / "mobile" / "app.jac");
        assert app.overlays["dependencies"]["npm"]["lucide-react-native"] == "^0.469.0";
        assert app.overlays["dependencies"]["npm"]["native"]["react-native-svg"]
            == "^15.13.0";
        eff = cfg.effective_for_app("mobile");
        assert eff.plugin_dependencies["npm"]["react"] == "^18.2.0" , "app overlay wins";
        assert eff.plugin_dependencies["npm"]["lucide-react-native"] == "^0.469.0";
        assert eff.get_plugin_deps("npm")["lucide-react-native"] == "^0.469.0";
        assert "native" not in eff.get_plugin_deps("npm");
        assert cfg.plugin_dependencies["npm"] == {"react": "^19"} , "base deps untouched";
        assert "lucide-react-native"
            not in cfg.effective_for_app("web").plugin_dependencies["npm"];
        assert _app_name(cfg.app_for_path(str(root_path / "mobile" / "app.jac")))
            == "mobile";
    }
}

test "scaffold_app migrates a single-app project into a workspace" {
    with TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir) / "proj";
        root_path.mkdir();
        (root_path / "jac.toml").write_text(
            '[project]\nname = "acme"\nkind = "cli"\nentry-point = "main"\n\n'
            '[dependencies.pypi]\nrequests = ">=2"\n'
        );
        (root_path / "main.jac").write_text("with entry {}\n");
        scaffold_app(str(root_path), "api", "service", "api", _service_template());
        cfg = JacConfig.load(root_path / "jac.toml");
        assert cfg.is_workspace;
        assert list(cfg.apps.keys()) == ["acme", "api"];
        assert cfg.apps["acme"].kind == "cli";
        assert cfg.apps["acme"].entry_point == "main";
        assert cfg.default_app == "acme" , "bare `jac run` keeps running the old app";
        assert cfg.project.kind == "" and cfg.project.entry_point == "main";
        assert cfg.pypi_dependencies["requests"] == ">=2";
        assert cfg.resolve_app("").name == "acme";
        assert (root_path / "api" / "main.jac").exists();
    }
}

test "scaffold_app rejects duplicate names, entry modules and unknown kinds" {
    with TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir) / "proj";
        root_path.mkdir();
        (root_path / "jac.toml").write_text(
            '[project]\nname = "acme"\n\n[apps.api]\nkind = "service"\nentry-point = "api.main"\n'
        );
        for (args, needle) in [
            (("api", "service", "api2"), "already exists"),
            (("api2", "service", "api"), "entry-point already declared"),
            (("svc", "nope", "svc"), "Unknown app kind"),
            (("bad/name", "service", "x"), "cannot contain")
        ] {
            raised = False;
            try {
                scaffold_app(
                    str(root_path), args[0], args[1], args[2], _service_template()
                );
            } except ValueError as e {
                raised = True;
                assert needle in str(e) , str(e);
            }
            assert raised , f"Expected ValueError for {args}";
        }
        assert (root_path / "jac.toml").read_text().count("[apps.") == 1 , (
            "a rejected scaffold must leave jac.toml untouched"
        );
    }
}

def _entry_template -> ProjectTemplate {
    return ProjectTemplate(
        name="worker",
        description="service with its own entry",
        kind="service",
        config={
            "project": {"name": "{{name}}", "entry-point": "server", "kind": "service"}
        },
        files={"server.jac": "walker:pub Ping {}\n"}
    );
}

test "scaffold_app honors a template entry-point other than the kind default" {
    with TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir) / "proj";
        (root_path / "web").mkdir(parents=True);
        (root_path / "jac.toml").write_text(
            '[project]\nname = "acme"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n'
        );
        (root_path / "web" / "main.jac").write_text("with entry {}\n");
        created = scaffold_app(
            str(root_path), "worker", "service", "services/worker", _entry_template()
        );
        assert str(root_path / "services" / "worker" / "server.jac") in created;
        text = (root_path / "jac.toml").read_text();
        assert 'entry-point = "services.worker.server"' in text , text;
        cfg = JacConfig.load(root_path / "jac.toml");
        app = cfg.apps["worker"];
        assert app.entry_point == "services.worker.server" , app.entry_point;
        assert app.entry_path(str(root_path))
            == str(root_path / "services" / "worker" / "server.jac");
        assert _app_name(
            cfg.app_for_path(str(root_path / "services" / "worker" / "server.jac"))
        )
            == "worker";
    }
}

test "scaffold_app migration keeps the base app loadable and reusable" {
    import from jaclang.project.template_loader { migrate_implicit_app }
    with TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir) / "proj";
        root_path.mkdir();
        (root_path / "jac.toml").write_text(
            '[project]\nname = "acme"\nkind = "web-app"\nentry-point = "app"\n\n'
            '[serve]\nport = 8090\n'
        );
        (root_path / "app.jac").write_text("with entry {}\n");
        lines = (root_path / "jac.toml").read_text().split("\n");
        base_name = migrate_implicit_app(lines, JacConfig.load(root_path / "jac.toml"));
        assert base_name == "acme" , base_name;
        (root_path / "jac.toml").write_text("\n".join(lines));
        cfg = JacConfig.load(root_path / "jac.toml");
        assert cfg.is_workspace and cfg.default_app == "acme";
        assert cfg.project.kind == "" and cfg.serve.port == 8090;
        assert cfg.apps["acme"].kind == "web-app";
        assert cfg.apps["acme"].entry_point == "app";
        assert cfg.apps["acme"].ui() == "dom";
        text = (root_path / "jac.toml").read_text();
        assert "client_kind" not in text and "client =" not in text , (
            "migration never writes the removed client keys"
        );
    }
}

test "a template carrying the removed client keys is rejected on load" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(tmpdir) / "stale";
        template_dir.mkdir();
        (template_dir / "jac.toml").write_text(
            '[project]\nname = "{{name}}"\n\n[apps.main]\nkind = "mobile"\nentry-point = "main"\nclient = "react-native"\nclient_kind = "mobui"\n\n[jacpack]\nname = "stale"\ndescription = "pre-refactor mobile template"\n'
        );
        (template_dir / "main.jac").write_text("with entry {}\n");
        raised = False;
        try {
            load_template_from_directory(template_dir);
        } except ValueError as e {
            raised = True;
            assert "[apps.main] 'client' was removed" in str(e) , str(e);
        }
        assert raised , "a stale template must not load with the removed client keys";
    }
}
