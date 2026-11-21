"""A desktop app inside a workspace.

`[desktop]` is a plugin section like `[client]`: an app's `[apps.<name>.desktop]`
table overlays it for that app, and the desktop target keeps each app's
artifacts under its own client dir. Both facts are read through the same
machinery the client config already uses, so they are pinned here against a
two-app workspace.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.project.config { set_config }
import from jaclang.client.desktop_config { get_desktop_config, reset_desktop_config }


glob _TOML: str = (
         '[project]\nname = "kiosk_ws"\ndefault-app = "web"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n[apps.shell]\nkind = "desktop"\nentry-point = "shell.main"\n\n[apps.kiosk]\nkind = "desktop"\nentry-point = "kiosk.main"\n\n[desktop]\nname = "root-app"\n\n[desktop.window]\ntitle = "Root"\nwidth = 1000\n\n[apps.shell.desktop]\nname = "shell-app"\n\n[apps.shell.desktop.window]\ntitle = "Shell"\n'
     );


def _workspace -> str {
    # Canonical from the start: macOS mounts its temp dir behind /private, and
    # the target resolves project paths canonically.
    d = os.path.realpath(tempfile.mkdtemp(prefix="jac_desktop_ws_"));
    for app in ("web", "shell", "kiosk") {
        os.makedirs(os.path.join(d, app), exist_ok=True);
        with open(os.path.join(d, app, "main.jac"), "w") as f {
            f.write("def:pub app -> JsxElement {\n    return <div>hi</div>;\n}\n");
        }
    }
    with open(os.path.join(d, "jac.toml"), "w") as f {
        f.write(_TOML);
    }
    return d;
}


def _target(d: str, app: str) {
    Jac.set_full_target_path(os.path.join(d, app, "main.jac"));
    set_config(None);
    reset_desktop_config();
}


test "[apps.<name>.desktop] overlays [desktop] for that app only" {
    d = _workspace();
    try {
        _target(d, "shell");
        shell = get_desktop_config(project_dir=Path(d));
        assert shell.get_identity().name == "shell-app" , shell.get_identity();
        win = shell.get_window_config();
        assert win.title == "Shell" and win.width == 1000 , (win.title, win.width);

        _target(d, "kiosk");
        kiosk = get_desktop_config(project_dir=Path(d));
        assert kiosk.get_identity().name == "root-app" , kiosk.get_identity();
        assert kiosk.get_window_config().title == "Root";
    } finally {
        reset_desktop_config();
        set_config(None);
        Jac.set_full_target_path("");
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "each desktop app builds under its own client dir" {
    import from jaclang.client.targets.desktop.desktop_target { DesktopTarget }
    import from jaclang.project.config { get_config_for_dir }
    d = _workspace();
    try {
        target = DesktopTarget();
        _target(d, "shell");
        shell_out = target.out_dir_for(Path(d) / "shell" / "main.jac", Path(d));
        _target(d, "kiosk");
        kiosk_out = target.out_dir_for(Path(d) / "kiosk" / "main.jac", Path(d));
        assert shell_out
            == Path(d) / ".jac" / "client" / "shell" / "desktop" , shell_out;
        assert kiosk_out
            == Path(d) / ".jac" / "client" / "kiosk" / "desktop" , kiosk_out;
    } finally {
        set_config(None);
        Jac.set_full_target_path("");
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a single-app project keeps .jac/client/desktop" {
    import from jaclang.client.targets.desktop.desktop_target { DesktopTarget }
    d = os.path.realpath(tempfile.mkdtemp(prefix="jac_desktop_single_"));
    try {
        with open(os.path.join(d, "jac.toml"), "w") as f {
            f.write("[project]\nname = \"solo\"\nkind = \"desktop\"\n");
        }
        with open(os.path.join(d, "main.jac"), "w") as f {
            f.write("def:pub app -> JsxElement {\n    return <div>hi</div>;\n}\n");
        }
        Jac.set_full_target_path(os.path.join(d, "main.jac"));
        set_config(None);
        out = DesktopTarget().out_dir_for(Path(d) / "main.jac", Path(d));
        assert out == Path(d) / ".jac" / "client" / "desktop" , out;
    } finally {
        set_config(None);
        Jac.set_full_target_path("");
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "[desktop] backend is embedded by default, a URL when remote, nothing else" {
    d = _workspace();
    try {
        _target(d, "shell");
        assert get_desktop_config(project_dir=Path(d)).get_backend() == "embedded";
        toml = Path(d) / "jac.toml";
        toml.write_text(
            toml.read_text()
                + "\n[apps.kiosk.desktop]\nbackend = \"https://kiosk.example\"\n"
        );
        _target(d, "kiosk");
        assert get_desktop_config(project_dir=Path(d)).get_backend()
            == "https://kiosk.example";
        _target(d, "shell");
        assert get_desktop_config(project_dir=Path(d)).get_backend() == "embedded";
        toml.write_text(
            toml.read_text() + "\n[apps.web.desktop]\nbackend = \"sometimes\"\n"
        );
        _target(d, "web");
        raised = False;
        try {
            get_desktop_config(project_dir=Path(d)).get_backend();
        } except ValueError {
            raised = True;
        }
        assert raised , "backend must be 'embedded' or an http(s) URL";
    } finally {
        reset_desktop_config();
        set_config(None);
        Jac.set_full_target_path("");
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "remote desktop staging needs no local program in build or dev" {
    import from jaclang.client.targets.desktop.desktop_build { stage_program }
    import from unittest.mock { patch }
    import jaclang.dist.seal as seal;
    d = _workspace();
    try {
        base = Path(d);
        assets = base / "shell" / "assets";
        assets.mkdir();
        (assets / "logo.svg").write_text("<svg>desktop</svg>");
        with patch.object(
            seal,
            "build_jab",
            side_effect=AssertionError("remote desktops must not seal a local app")
        ) {
            for dist in [None, base / "dist"] {
                assert stage_program(
                    base / "shell" / "main.jac",
                    base,
                    base / "out",
                    "https://example.invalid",
                    dist
                )
                    == {};
            }
        }
        assert (base / "out" / "dist" / "assets" / "logo.svg").read_text()
            == "<svg>desktop</svg>";
    } finally {
        set_config(None);
        shutil.rmtree(d, ignore_errors=True);
    }
}


"""Raise the ValueError a bad `[desktop]` backend choice must raise, or fail."""
def _rejects(d: str, app: str, table: str, needle: str) {
    toml = Path(d) / "jac.toml";
    toml.write_text(_TOML + table);
    _target(d, app);
    raised = "";
    try {
        get_desktop_config(project_dir=Path(d)).validate();
    } except ValueError as e {
        raised = str(e);
    }
    assert needle in raised , (table, raised);
}


test "[desktop] backends names a runtime choice that builds every backend it lists" {
    d = _workspace();
    try {
        toml = Path(d) / "jac.toml";
        toml.write_text(
            _TOML
                + "\n[apps.kiosk.desktop.backends]\nlocal = \"embedded\"\nweb = \"https://kiosk.example/\"\n"
        );
        _target(d, "kiosk");
        cfg = get_desktop_config(project_dir=Path(d));
        assert cfg.get_backends()
            == {"local": "embedded", "web": "https://kiosk.example"};
        assert cfg.get_default_backend() == "ask";
        assert cfg.get_build_backend() == "embedded";
        cfg.validate();

        toml.write_text(
            toml.read_text() + "\n[apps.kiosk.desktop]\ndefault_backend = \"web\"\n"
        );
        _target(d, "kiosk");
        assert get_desktop_config(project_dir=Path(d)).get_default_backend() == "web";

        toml.write_text(
            _TOML
                + "\n[apps.kiosk.desktop.backends]\neu = \"https://eu.example\"\nus = \"https://us.example\"\n"
        );
        _target(d, "kiosk");
        cfg = get_desktop_config(project_dir=Path(d));
        assert cfg.get_build_backend() == "https://eu.example";

        _target(d, "shell");
        cfg = get_desktop_config(project_dir=Path(d));
        assert cfg.get_backends() == {};
        assert cfg.get_default_backend() == "";
        assert cfg.get_build_backend() == "embedded";
    } finally {
        reset_desktop_config();
        set_config(None);
        Jac.set_full_target_path("");
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "[desktop] backends rejects a choice the host could not offer" {
    d = _workspace();
    try {
        _rejects(
            d,
            "kiosk",
            "\n[apps.kiosk.desktop]\nbackend = \"https://a.example\"\n\n[apps.kiosk.desktop.backends]\na = \"embedded\"\nb = \"https://b.example\"\n",
            "not both"
        );
        _rejects(
            d,
            "kiosk",
            "\n[apps.kiosk.desktop.backends]\nonly = \"embedded\"\n",
            "at least two"
        );
        _rejects(d, "kiosk", "\n[apps.kiosk.desktop.backends]\n", "at least two");
        _rejects(
            d,
            "kiosk",
            "\n[apps.kiosk.desktop.backends]\na = \"embedded\"\nb = \"embedded\"\n",
            "only once"
        );
        _rejects(
            d,
            "kiosk",
            "\n[apps.kiosk.desktop.backends]\na = \"embedded\"\nb = \"ftp://b.example\"\n",
            "backends.b"
        );
        _rejects(
            d,
            "kiosk",
            "\n[apps.kiosk.desktop.backends]\nask = \"embedded\"\nb = \"https://b.example\"\n",
            "not 'ask'"
        );
        _rejects(
            d,
            "kiosk",
            "\n[apps.kiosk.desktop]\ndefault_backend = \"cloud\"\n\n[apps.kiosk.desktop.backends]\na = \"embedded\"\nb = \"https://b.example\"\n",
            "one of a, b"
        );
        _rejects(
            d,
            "kiosk",
            "\n[apps.kiosk.desktop]\ndefault_backend = \"a\"\n",
            "needs a [desktop] backends table"
        );
    } finally {
        reset_desktop_config();
        set_config(None);
        Jac.set_full_target_path("");
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a backend choice stages the assets a remote pick serves and seals the local app" {
    import from jaclang.client.targets.desktop.desktop_build { stage_program }
    import from unittest.mock { patch }
    import jaclang.dist.seal as seal;
    d = _workspace();
    try {
        base = Path(d);
        assets = base / "shell" / "assets";
        assets.mkdir();
        (assets / "logo.svg").write_text("<svg>desktop</svg>");
        sealed: list[any] = [];
        def fake_seal(config: any, out: Path, **kwargs: any) -> Path {
            sealed.append(out);
            return out;
        }
        _target(d, "shell");
        with patch.object(seal, "build_jab", side_effect=fake_seal) {
            program = stage_program(
                base / "shell" / "main.jac",
                base,
                base / "out",
                "embedded",
                base / "dist",
                serves_remote=True
            );
        }
        assert program == {"jab": "app.jab"} , program;
        assert sealed == [base / "out" / "app.jab"] , sealed;
        assert (base / "out" / "dist" / "assets" / "logo.svg").read_text()
            == "<svg>desktop</svg>";
    } finally {
        set_config(None);
        Jac.set_full_target_path("");
        shutil.rmtree(d, ignore_errors=True);
    }
}


"""A choice build leaves the API base to `/__jac/backend.js`: nothing in the
environment is baked in, and a fixed `[client.api] base_url` is refused rather
than silently overriding every pick."""
test "a backend choice build bakes no API base and refuses a fixed one" {
    import from unittest.mock { patch }
    import from jaclang.client.targets.desktop.desktop_target { DesktopTarget }
    import from jaclang.client.targets.web_target { WebTarget }
    import jaclang.client.targets.desktop.webview_shell as webview_shell;
    d = _workspace();
    prior = os.environ.get("JAC_CLIENT_API_BASE_URL");
    try {
        toml = Path(d) / "jac.toml";
        toml.write_text(
            _TOML
                + "\n[apps.kiosk.desktop.backends]\nlocal = \"embedded\"\nweb = \"https://web.example\"\n"
        );
        _target(d, "kiosk");
        seen: list[any] = [];
        def fake_build(
            target: any, entry_file: Path, proj: Path, platform: any = None
        ) -> Path {
            seen.append(os.environ.get("JAC_CLIENT_API_BASE_URL"));
            return Path(d) / "dist" / "client.js";
        }
        os.environ["JAC_CLIENT_API_BASE_URL"] = "https://stale.example";
        with patch.object(WebTarget, "build", fake_build), patch.object(
            webview_shell, "webview_build", return_value=Path(d) / "app"
        ) {
            DesktopTarget().build(Path(d) / "kiosk" / "main.jac", Path(d));
        }
        assert seen == [None] , seen;
        assert os.environ["JAC_CLIENT_API_BASE_URL"] == "https://stale.example" , "the env is restored";

        toml.write_text(
            toml.read_text() + "\n[client.api]\nbase_url = \"https://fixed.example\"\n"
        );
        _target(d, "kiosk");
        raised = "";
        try {
            DesktopTarget().build(Path(d) / "kiosk" / "main.jac", Path(d));
        } except ValueError as e {
            raised = str(e);
        }
        assert "base_url" in raised , raised;
    } finally {
        if prior is None {
            os.environ.pop("JAC_CLIENT_API_BASE_URL", None);
        } else {
            os.environ["JAC_CLIENT_API_BASE_URL"] = prior;
        }
        reset_desktop_config();
        set_config(None);
        Jac.set_full_target_path("");
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "[desktop] profiles needs an embedded backend" {
    d = _workspace();
    try {
        toml = Path(d) / "jac.toml";
        toml.write_text(_TOML + "\n[apps.kiosk.desktop]\nprofiles = true\n");
        _target(d, "kiosk");
        assert get_desktop_config(project_dir=Path(d)).get_profiles() == True;
        toml.write_text(
            _TOML
                + "\n[apps.kiosk.desktop]\nprofiles = true\n\n[apps.kiosk.desktop.backends]\nlocal = \"embedded\"\nweb = \"https://web.example\"\n"
        );
        _target(d, "kiosk");
        assert get_desktop_config(project_dir=Path(d)).get_profiles() == True;
        _target(d, "shell");
        assert get_desktop_config(project_dir=Path(d)).get_profiles() == False;
        _rejects(
            d,
            "kiosk",
            "\n[apps.kiosk.desktop]\nprofiles = true\nbackend = \"https://web.example\"\n",
            "profiles needs an embedded backend"
        );
        _rejects(
            d, "kiosk", "\n[apps.kiosk.desktop]\nprofiles = \"yes\"\n", "true or false"
        );
    } finally {
        reset_desktop_config();
        set_config(None);
        Jac.set_full_target_path("");
        shutil.rmtree(d, ignore_errors=True);
    }
}
