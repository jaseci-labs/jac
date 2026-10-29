"""Which app an embedded desktop build seals.

`serving_app_for` picks the app a desktop image serves: the default app when it
has a server, else the first web app, else the app the entry file belongs to.
The default app's server-ness is decided by its kind (`AppConfig` carries no
`has_server` field of its own), pinned here against multi-app workspaces.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.client.targets.desktop.desktop_build { serving_app_for }


glob _MAIN = 'def:pub app -> JsxElement {\n    return <div>hi</div>;\n}\n',
     _DESKTOP_DEFAULT_TOML: str = (
         '[project]\nname = "kiosk_ws"\ndefault-app = "desktop"\n\n'
         '[apps.desktop]\nkind = "desktop"\nentry-point = "desktop.main"\n\n'
         '[apps.harness]\nkind = "service"\nentry-point = "harness.main"\n'
     ),
     _SERVICE_DEFAULT_TOML: str = (
         '[project]\nname = "svc_ws"\ndefault-app = "harness"\n\n'
         '[apps.harness]\nkind = "service"\nentry-point = "harness.main"\n\n'
         '[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n'
     ),
     _WEB_FALLBACK_TOML: str = (
         '[project]\nname = "web_ws"\ndefault-app = "desktop"\n\n'
         '[apps.desktop]\nkind = "desktop"\nentry-point = "desktop.main"\n\n'
         '[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n'
     );


def _workspace(toml: str) -> tuple[JacConfig, Path] {
    d = Path(os.path.realpath(tempfile.mkdtemp(prefix="jac_serving_app_")));
    (d / "jac.toml").write_text(toml);
    for app_dir in ("desktop", "harness", "web") {
        (d / app_dir).mkdir(exist_ok=True);
        (d / app_dir / "main.jac").write_text(_MAIN);
    }
    return (JacConfig.from_toml_str(toml, toml_path=d / "jac.toml"), d);
}


def _serve(
    config: JacConfig, d: Path, app_name: str, backend: str = "embedded"
) -> str {
    try {
        return serving_app_for(config, d / app_name / "main.jac", backend);
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a desktop default-app serves itself in an embedded build" {
    (config, d) = _workspace(_DESKTOP_DEFAULT_TOML);
    assert _serve(config, d, "desktop") == "desktop";
}


test "a default app with a server is served directly" {
    (config, d) = _workspace(_SERVICE_DEFAULT_TOML);
    assert _serve(config, d, "harness") == "harness";
}


test "a serverless default falls to the first web app" {
    (config, d) = _workspace(_WEB_FALLBACK_TOML);
    assert _serve(config, d, "desktop") == "web";
}
