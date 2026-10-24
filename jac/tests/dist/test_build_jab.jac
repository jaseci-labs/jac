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
import from jaclang.dist.seal { build_jab, build_serve_manifest }
import from jaclang.project.config { JacConfig, set_config }

test "serve manifests analyze native imports without loading their libraries or retaining trees" {
    import from jaclang.runtime.runtime { JacRuntime }
    with tempfile.TemporaryDirectory() as directory {
        project_dir = Path(directory);
        (project_dir / "jac.toml").write_text(
            "[project]\nname = \"manifest_native\"\n"
            "[placement.pins]\nforeign = \"native\"\n"
        );
        (project_dir / "foreign.jac").write_text(
            "import from jac_manifest_absent_library { def foreign_value -> int; }\n"
            "def value() -> int { return foreign_value(); }\n"
        );
        entry_file = project_dir / "main.jac";
        entry_file.write_text(
            "walker:pub Greeting { can start with Root entry { report 42; } }\n"
        );
        runtime_program = JacRuntime.get_program();
        runtime_modules = dict(runtime_program.mod.hub);
        try {
            set_config(JacConfig.load(project_dir / "jac.toml"));
            manifest = build_serve_manifest(entry_file, project_dir);
            assert manifest is not None;
            greeting = manifest["surface"]["Greeting"];
            assert greeting["kind"] == "walker" , greeting;
            assert greeting["exposure"] == "public" , greeting;
            assert runtime_program.mod.hub == runtime_modules;
        } finally {
            set_config(None);
        }
    }
}


glob _TOML: str = (
         '[project]\nname = "sealed_ws"\ndefault-app = "web"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n[apps.cli]\nkind = "cli"\nentry-point = "cli_app"\n'
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


test "a sealed boot reads each module's imports from the seal instead of disassembling it" {
    import json;
    import from jaclang.compiler.backends.py { artifact_imports }
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.prepared { forget }
    ws = _workspace();
    real_sources = artifact_imports.runtime_sources;
    scanned: list[str] = [];
    def counting_sources(code: any, source: str, `root: str) -> set[str] {
        scanned.append(source);
        return real_sources(code, source, `root);
    }
    entry_file = "";
    manifest_path: (Path | None) = None;
    original_manifest = "";
    try {
        config = JacConfig.load(Path(ws) / "jac.toml");
        out = Path(ws) / "out" / "web.jab";
        build_jab(config, out, bake_client=False);
        img = materialize_jab(str(out));
        manifest_path = img / ".jac" / "serve_manifest.json";
        original_manifest = manifest_path.read_text();
        serving = json.loads(original_manifest);
        recorded: dict[str, list[str]] = serving.get("runtime_imports") or {};
        main_imports: list[str] = recorded.get("web/main.jac", []);
        assert "core/helper.jac" in main_imports , (
            f"the seal did not record web/main.jac's imports: {recorded}"
        );
        entry_file = str(img / "web" / "main.jac");
        artifact_imports.runtime_sources = counting_sources;
        prepared = prepare_application(entry_file, JacProgram(), str(img));
        assert os.path.realpath(str(img / "core" / "helper.jac")) in prepared.code , (
            "the sealed boot did not load the module web/main.jac imports"
        );
        assert not scanned , (
            f"the sealed boot disassembled {len(scanned)} modules whose imports the "
            f"seal had recorded: {scanned}"
        );
        partial = dict(serving);
        partial["runtime_imports"] = {
            source: imports
            for (source, imports) in recorded.items()
            if source != "web/main.jac"
        };
        missing = dict(serving);
        missing.pop("runtime_imports", None);
        for (label, variant) in [
            ("one module unrecorded", partial),
            ("no map", missing)
        ] {
            manifest_path.write_text(json.dumps(variant));
            forget(entry_file);
            scanned.clear();
            prepared = prepare_application(entry_file, JacProgram(), str(img));
            assert os.path.realpath(str(img / "core" / "helper.jac"))
                in prepared.code , (
                f"{label}: the boot did not load the module web/main.jac imports"
            );
            assert any(path.endswith("main.jac") for path in scanned) , (
                f"{label}: the boot did not fall back to reading web/main.jac's imports"
            );
        }
    } finally {
        if manifest_path is not None and original_manifest {
            manifest_path.write_text(original_manifest);
        }
        artifact_imports.runtime_sources = real_sources;
        if entry_file {
            forget(entry_file);
        }
        set_config(None);
        shutil.rmtree(os.path.dirname(ws), ignore_errors=True);
    }
}

test "only server and desktop apps include sibling services" {
    with tempfile.TemporaryDirectory() as directory {
        project_dir = Path(directory);
        api_dir = project_dir / "api";
        api_dir.mkdir();
        (project_dir / "jac.toml").write_text(
            "[project]\nname=\"topology\"\ndefault-app=\"cli\"\n"
                + "[apps.cli]\nkind=\"cli\"\nentry-point=\"cli\"\n"
                + "[apps.desktop]\nkind=\"desktop\"\nentry-point=\"main\"\n"
                + "[apps.api]\nkind=\"service\"\nentry-point=\"api.main\"\n"
        );
        (project_dir / "cli.jac").write_text("with entry {}\n");
        (project_dir / "main.jac").write_text("with entry {}\n");
        (api_dir / "main.jac").write_text("with entry {}\n");
        config = JacConfig.load(project_dir / "jac.toml");
        import from jaclang.server.assembly { service_apps }
        cli_services = service_apps(config, config.app("cli"));
        desktop_services = service_apps(config, config.app("desktop"));
        assert not cli_services , cli_services;
        assert [app.name for app in desktop_services] == ["api"] , desktop_services;
    }
}


"""A sealed image never carries secrets, and honors `.jacignore`.

The `.jab` is what a desktop build ships beside its binary and what `jac build`
hands out, so it must hold the same floor the deploy bundle does: no `.env`
files (a project's model and API keys live there), no key material. A tree
parked in `.jacignore` (a vendored jac checkout, local data) stays out too.
"""
test "build_jab never seals secrets and leaves out what .jacignore parks" {
    ws = _workspace();
    try {
        base = Path(ws);
        (base / ".env").write_text("ANTHROPIC_API_KEY=sk-ant-secret\n");
        (base / ".env.local").write_text("TOKEN=local\n");
        (base / "web" / ".env").write_text("NESTED=1\n");
        (base / "deploy.pem").write_text("-----BEGIN PRIVATE KEY-----\n");
        (base / "id_ed25519").write_text("key\n");
        (base / "vendor" / "jac").mkdir(parents=True);
        (base / "vendor" / "jac" / "big.jac").write_text("with entry { print(1); }\n");
        (base / "notes").mkdir();
        (base / "notes" / "todo.md").write_text("ship it\n");
        (base / ".jacignore").write_text("vendor/\nnotes/*.md\n");
        config = JacConfig.load(base / "jac.toml");
        out = base / "out" / "web.jab";
        build_jab(config, out, app="web", bake_client=False);
        img = materialize_jab(str(out));
        for leaked in [
            ".env",
            ".env.local",
            "web/.env",
            "deploy.pem",
            "id_ed25519",
            "vendor",
            "notes/todo.md"
        ] {
            assert not (img / leaked).exists() , f"{leaked} must not be sealed";
        }
        assert (img / "core" / "helper.jac").is_file() , "the app's own code still ships";
        assert (img / ".jacignore").is_file() , ".jacignore itself ships";
        import gzip;
        assert b"sk-ant-secret" not in gzip.decompress(out.read_bytes());
    } finally {
        set_config(None);
        shutil.rmtree(os.path.dirname(ws), ignore_errors=True);
    }
}
