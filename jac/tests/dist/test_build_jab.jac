"""Building a jab for one app of a workspace.

`build_jab` is the one way to seal a project into a `.jab`: `jac build`, the
binary projection and the desktop host all go through it. For a workspace it
takes the app to seal, and the sealed manifest must describe THAT app -- its
kind and its entry -- because `jac run <jab>` and the desktop host read the
manifest to decide what to boot. `jac build cli` used to stamp the default
app's manifest: the seal step received `--app cli` as two argv tokens while the
precompiler only understood `--app=cli`.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.dist.jab { jab_app_meta, materialize_jab }
import from jaclang.dist.seal { build_jab }
import from jaclang.project.config { JacConfig, set_config }


glob _TOML: str = (
         "[project]\n"
         "name = \"sealed_ws\"\n"
         "default-app = \"web\"\n"
         "\n"
         "[apps.web]\n"
         "kind = \"web-app\"\n"
         "path = \"web\"\n"
         "\n"
         "[apps.cli]\n"
         "kind = \"cli\"\n"
         "entry-point = \"cli_app.jac\"\n"
     ),
     _WEB_SRC: str = (
         "import from core.helper { label }\n"
         "\n"
         "walker:pub Hello {\n"
         "    has who: str = \"world\";\n"
         "\n"
         "    can run with Root entry {\n"
         "        report label(self.who);\n"
         "    }\n"
         "}\n"
     ),
     _CLI_SRC: str = (
         "import from core.helper { label }\n"
         "\n"
         "with entry {\n"
         "    print(label(\"cli\"));\n"
         "}\n"
     ),
     _HELPER_SRC: str = (
         "def label(text: str) -> str {\n" "    return \"[\" + text + \"]\";\n" "}\n"
     );


def _workspace -> str {
    tmp = tempfile.mkdtemp(prefix="jac_build_jab_");
    dest = os.path.join(tmp, "sealed_ws");
    os.makedirs(os.path.join(dest, "web"), exist_ok=True);
    os.makedirs(os.path.join(dest, "core"), exist_ok=True);
    (Path(dest) / "jac.toml").write_text(_TOML);
    (Path(dest) / "web" / "main.jac").write_text(_WEB_SRC);
    (Path(dest) / "cli_app.jac").write_text(_CLI_SRC);
    (Path(dest) / "core" / "helper.jac").write_text(_HELPER_SRC);
    return dest;
}


test "build_jab seals the named app and its manifest names it" {
    ws = _workspace();
    try {
        config = JacConfig.load(Path(ws) / "jac.toml");
        out = Path(ws) / "out" / "cli.jab";
        built = build_jab(config, out, app="cli", bake_client=False);
        assert built == out and out.is_file() , built;
        img = materialize_jab(str(out));
        meta = jab_app_meta(img);
        assert meta["kind"] == "cli" , meta;
        assert meta["app"] == "cli" , meta;
        assert meta["entry"]["path"] == "cli_app.jac" , meta;
        assert (img / "jac.toml").is_file() , "the workspace jac.toml ships in the image";
        assert (img / "core" / "helper.jac").is_file() , "the whole workspace server side ships";
        assert (img / "web" / "main.jac").is_file() , "the other app ships too";
    } finally {
        set_config(None);
        shutil.rmtree(os.path.dirname(ws), ignore_errors=True);
    }
}


test "build_jab seals the default app when no app is named" {
    ws = _workspace();
    try {
        config = JacConfig.load(Path(ws) / "jac.toml");
        out = Path(ws) / "out" / "default.jab";
        build_jab(config, out, bake_client=False);
        meta = jab_app_meta(materialize_jab(str(out)));
        assert meta["kind"] == "web-app" and meta["app"] == "web" , meta;
    } finally {
        set_config(None);
        shutil.rmtree(os.path.dirname(ws), ignore_errors=True);
    }
}
