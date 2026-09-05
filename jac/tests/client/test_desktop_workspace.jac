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
         "[project]\n"
         "name = \"kiosk_ws\"\n"
         "default-app = \"web\"\n"
         "\n"
         "[apps.web]\n"
         "kind = \"web-app\"\n"
         "path = \"web\"\n"
         "\n"
         "[apps.shell]\n"
         "kind = \"desktop\"\n"
         "path = \"shell\"\n"
         "\n"
         "[apps.kiosk]\n"
         "kind = \"desktop\"\n"
         "path = \"kiosk\"\n"
         "\n"
         "[desktop]\n"
         "name = \"root-app\"\n"
         "\n"
         "[desktop.window]\n"
         "title = \"Root\"\n"
         "width = 1000\n"
         "\n"
         "[apps.shell.desktop]\n"
         "name = \"shell-app\"\n"
         "\n"
         "[apps.shell.desktop.window]\n"
         "title = \"Shell\"\n"
     );


def _workspace -> str {
    d = tempfile.mkdtemp(prefix="jac_desktop_ws_");
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
    d = tempfile.mkdtemp(prefix="jac_desktop_single_");
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
