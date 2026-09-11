import io;
import os;
import shutil;
import subprocess;
import sys;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.tests.support { require_pod_binary }
import from jaclang.scale.injector.bundle {
    DEFAULT_SEAL_TIMEOUT_S,
    _stage_app,
    nested_sanitized_tomls,
    pack_jab,
    sanitized_jac_toml,
    seal_timeout_setting
}


def _mini_app -> str {
    d = tempfile.mkdtemp(prefix="jac-app-");
    Path(d, "jac.toml").write_text("[project]\nname = \"mini\"\n");
    Path(d, "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    return d;
}


def _pinned_app -> str {
    # A markerless-era app: pinned client subtree, a nested project, secrets
    # in jac.toml, and a .env that must never reach the stage.
    d = tempfile.mkdtemp(prefix="jac-app-");
    Path(d, "jac.toml").write_text(
        "[project]\nname = \"mini\"\n\n[scale]\nseal_timeout = 123\n\n"
            + "[scale.secrets]\nAPI_KEY = \"hunter2\"\n\n"
            + "[placement.pins]\n\"ui*\" = \"client\"\n"
    );
    Path(d, "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    os.makedirs(os.path.join(d, "ui"));
    Path(d, "ui", "page.jac").write_text("def page -> str { return \"ui\"; }\n");
    os.makedirs(os.path.join(d, "docsite"));
    Path(d, "docsite", "jac.toml").write_text("[project]\nname = \"docs\"\n");
    Path(d, "docsite", "index.jac").write_text("def d -> str { return \"x\"; }\n");
    Path(d, ".env").write_text("SECRET=1\n");
    return d;
}


test "staging writes sanitized root and nested jac.toml before the seal runs" {
    base = Path(_pinned_app());
    stage_root = _stage_app(base, sanitized_jac_toml(base));
    stage = stage_root / "app";
    root_toml = (stage / "jac.toml").read_text();
    assert "placement.pins" in root_toml;
    assert "secrets" not in root_toml;
    assert "seal_timeout" in root_toml;
    assert (stage / "docsite" / "jac.toml").is_file();
    assert not (stage / ".env").exists();
}


test "placement pins are readable from inside the seal stage (issue 7866)" {
    base = Path(_pinned_app());
    stage_root = _stage_app(base, sanitized_jac_toml(base));
    import from jaclang.compiler.placement.placement_pins { config_module_pin }
    staged_page = stage_root / "app" / "ui" / "page.jac";
    assert config_module_pin(str(staged_page)) == "client";
}


test "nested project tomls are sanitized and enumerated" {
    base = Path(_pinned_app());
    nested = nested_sanitized_tomls(base);
    assert list(nested.keys()) == ["docsite/jac.toml"];
    assert "docs" in nested["docsite/jac.toml"];
}


test "seal timeout comes from [scale] seal_timeout with a safe default" {
    assert seal_timeout_setting(_pinned_app()) == 123;
    assert seal_timeout_setting(_mini_app()) == DEFAULT_SEAL_TIMEOUT_S;
}


test "the seal skips pinned and inferred client modules and nested projects" {
    base = Path(_pinned_app());
    os.makedirs(os.path.join(str(base), "pages"));
    Path(str(base), "pages", "home.jac").write_text(
        "def:pub home -> JsxElement {\n    return <div>hi</div>;\n}\n"
    );
    stage_root = _stage_app(base, sanitized_jac_toml(base));
    stage = stage_root / "app";
    import from jaclang.dist.precompile_bytecode { sealable_sources }
    rels = {
        Path(p).relative_to(stage).as_posix() for p in sealable_sources(str(stage))
    };
    assert rels == {"__init__.jac", "svc.jac"} , rels;
    import from jaclang.dist.precompile_bytecode { placement_facts_map }
    placement = placement_facts_map(str(stage));
    assert placement["svc.jac"] == ["server"];
    assert placement["ui/page.jac"] == ["client"];
    assert placement["pages/home.jac"] == ["client"];
    assert "docsite/index.jac" not in placement;
}


test "any discovery error voids client skips so failures surface per-file" {
    base = Path(_pinned_app());
    os.makedirs(os.path.join(str(base), "pages"));
    Path(str(base), "pages", "broken.jac").write_text(
        "node T {\n    has a: str\n        b: int = 0\n}\n"
            + "def:pub page -> JsxElement {\n    return <div>x</div>;\n}\n"
    );
    stage_root = _stage_app(base, sanitized_jac_toml(base));
    stage = stage_root / "app";
    import from jaclang.dist.precompile_bytecode { sealable_sources }
    rels = {
        Path(p).relative_to(stage).as_posix() for p in sealable_sources(str(stage))
    };
    assert "pages/broken.jac" in rels , rels;
    assert "ui/page.jac" in rels , rels;
}


test "a project without jac.toml stages the minimal placeholder for the seal" {
    import from jaclang.scale.injector.bundle { PLACEHOLDER_JAC_TOML }
    d = tempfile.mkdtemp(prefix="jac-app-");
    Path(d, "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    stage_root = _stage_app(Path(d), sanitized_jac_toml(Path(d)));
    staged = (stage_root / "app" / "jac.toml").read_text();
    assert staged == PLACEHOLDER_JAC_TOML;
}


test "sealing an app tree without jac.toml fails loudly before compiling" {
    import from jaclang.dist.precompile_bytecode { main as seal_main }
    d = tempfile.mkdtemp(prefix="jac-app-");
    app = Path(d, "app");
    app.mkdir();
    (app / "__init__.jac").write_text("");
    (app / "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    old_argv = sys.argv;
    sys.argv = ["precompile", d, "--seal"];
    code = 0;
    try {
        seal_main();
    } except SystemExit as e {
        code = int(e.code or 0);
    } finally {
        sys.argv = old_argv;
    }
    assert code == 1;
}


def _names(raw: bytes) -> list[str] {
    # A .jab is a gzip tar, so r:gz opens it like any bundle.
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        return tar.getnames();
    }
}


test "pack_jab on a nonexistent app directory is a hard error" {
    caught = "";
    try {
        pack_jab("/tmp/jac-no-such-app-dir", b"binary");
    } except ValueError as e {
        caught = str(e);
    }
    assert "does not exist" in caught , caught;
}


test "pack_jab without a pod binary is a hard error (a .jab requires a seal)" {
    caught = False;
    try {
        pack_jab(_mini_app(), b"");
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "an unrunnable pod binary fails the seal instead of shipping unsealed" {
    caught = False;
    try {
        pack_jab(_mini_app(), b"not-an-elf");
    } except Exception {
        caught = True;
    }
    assert caught;
}


test "the seal and vendor subprocesses run without persistent storage (issue 8094)" {
    import from jaclang.scale.injector.bundle { seal_step_env }
    import from jaclang.server.session { SCRATCH_ENV }
    env = seal_step_env();
    assert env.get(SCRATCH_ENV) == "1" , (
        "the seal/vendor children stage the app under a fresh temp path, so a "
        f"persistent store there is a permanent orphan; {SCRATCH_ENV} was "
        f"{env.get(SCRATCH_ENV)!r}"
    );
    for banned in ["PYTHONPATH", "JAC_DEV_SOURCE"] {
        assert banned not in env , f"{banned} must stay out of the seal env";
    }
}


test "staging roots left by dead processes are reaped (issue 8094)" {
    import from jaclang.scale.injector.bundle { reap_stale_stage_roots }
    holder = tempfile.mkdtemp(prefix="jac-reap-");
    dead = subprocess.Popen([sys.executable, "-c", "pass"]);
    dead.`wait();
    saved_tempdir = tempfile.tempdir;
    tempfile.tempdir = holder;
    try {
        stale = Path(holder, f"jac-app-precompile-{dead.pid}-abcd");
        stale.mkdir();
        Path(stale, "app").mkdir();
        mine = Path(holder, f"jac-app-precompile-{os.getpid()}-efgh");
        mine.mkdir();
        # Staging roots from releases that did not name their pid: only age
        # can tell those apart, and a seal never runs for a day.
        legacy_old = Path(holder, "jac-app-precompile-oldrelease");
        legacy_old.mkdir();
        os.utime(str(legacy_old), (0, 0));
        legacy_new = Path(holder, "jac-app-precompile-newrelease");
        legacy_new.mkdir();
        removed = reap_stale_stage_roots();
        assert not stale.exists() , (
            f"a staging root owned by dead pid {dead.pid} must be reaped"
        );
        assert not legacy_old.exists() , (
            "a day-old staging root with no pid in its name must be reaped"
        );
        assert mine.exists() , "a live process's staging root must be left alone";
        assert legacy_new.exists() , (
            "a fresh staging root with no pid in its name may still be in use"
        );
        assert removed == 2 , f"expected 2 reaped staging roots, got {removed}";
    } finally {
        tempfile.tempdir = saved_tempdir;
        shutil.rmtree(holder, ignore_errors=True);
    }
}


test "staging a project cleans up after itself" {
    import from jaclang.scale.injector.bundle { stage_roots_in_use }
    base = Path(_mini_app());
    stage_root = _stage_app(base, sanitized_jac_toml(base));
    assert stage_root.name.startswith(f"jac-app-precompile-{os.getpid()}-") , (
        f"staging roots must carry their owning pid: {stage_root.name}"
    );
    assert str(stage_root) in stage_roots_in_use() , (
        "a live staging root must be tracked so it is removed on exit"
    );
    shutil.rmtree(str(stage_root), ignore_errors=True);
}


test "a real pod binary seals and serves an entry named app" {
    # The checkout's own binary stands in for the downloaded pod binary; the
    # mechanism (stage -> precompile_bytecode.jac --seal -> pack _precompiled/**)
    # is identical for release binaries.
    jac_bin = require_pod_binary();
    import json;
    base = Path(_mini_app());
    (base / "jac.toml").write_text(
        '[project]\nname="mini"\nkind="service"\nentry-point="app"\n'
    );
    (base / "app.jac").write_text(
        'import from svc { ping }\n'
            + 'walker:pub echo { can run with Root entry { report "hello"; } }\n'
    );
    raw = pack_jab(str(base), jac_bin.read_bytes());
    names = _names(raw);
    assert "svc.jac" in names;
    assert ".jac/serve_manifest.json" in names;
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as archive {
        serving = archive.extractfile(".jac/serve_manifest.json");
        assert serving is not None;
        assert json.loads(serving.read())["func_access"]["ping"] is False;
        manifest = archive.extractfile("_precompiled/MANIFEST.json");
        assert manifest is not None;
        assert ".jac/serve_manifest.json" in json.loads(manifest.read())["payloads"];
    }
    # The sealed manifest sits at the tar root, which is what makes this a .jab.
    assert "_precompiled/MANIFEST.json" in names;
    pre = [
        n
        for n in names
        if n.startswith("_precompiled/")
    ];
    assert any([n.endswith("svc.jir") for n in pre]) , pre;
    with tempfile.TemporaryDirectory(prefix="jac-sealed-entry-") as tmp {
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as archive {
            archive.extractall(tmp, filter="data");
        }
        env = dict(os.environ);
        env["JAC_NO_DEV_SOURCE"] = "1";
        result = subprocess.run(
            [str(jac_bin), "run", "--serve", "--faux", "app.jac"],
            cwd=tmp,
            env=env,
            capture_output=True,
            text=True,
            timeout=90
        );
        assert result.returncode == 0 , result.stdout + result.stderr;
        assert "/walker/echo" in result.stdout , result.stdout;
        assert "Preparing dynamically imported module" not in result.stdout;
    }
}

test "sealing includes bytecode imports and serving exports despite client placement" {
    import json;
    import from unittest.mock { patch }
    import jaclang.dist.precompile_bytecode as precompiler;
    with tempfile.TemporaryDirectory(prefix="jac-seal-closure-") as tmp {
        base = Path(tmp) / "app";
        base.mkdir();
        (base / "jac.toml").write_text(
            '[project]\nname="closure"\nkind="service"\nentry-point="main"\n'
        );
        main = base / "main.jac";
        shared = base / "shared.jac";
        exported = base / "exported.jac";
        unused = base / "unused.jac";
        shared.write_text('def:pub value -> str { return "shared"; }\n');
        exported.write_text('def:pub exposed -> str { return "exported"; }\n');
        unused.write_text('def:pub page -> JsxElement { return <div>unused</div>; }\n');
        main.write_text(
            'import from shared { value }\ndef:pub ping -> str { return value(); }\n'
        );
        artifact = precompiler.precompile_unit(str(main), str(base));
        assert artifact is not None;
        out = base / "_precompiled" / "units";
        out.mkdir(parents=True);
        (out / "main.jir").write_bytes(artifact);
        (base / ".jac").mkdir(exist_ok=True);
        (base / ".jac" / "serve_manifest.json").write_text(
            json.dumps(
                {
                    "cross_bindings": [
                        {
                            "src": "exported.jac",
                            "name": "exposed",
                            "kind": "def",
                            "auth": False
                        }
                    ]
                }
            )
        );
        with patch.object(
            precompiler, "_sealable_cache", {(str(base), ""): [str(main)]}
        ), patch.object(
            precompiler,
            "_placement_cache",
            {
                (str(base), ""): {
                    str(main): {"server"},
                    str(shared): {"client"},
                    str(exported): {"client"},
                    str(unused): {"client"}
                }
            }
        ) {
            assert precompiler.seal_runtime_closure(base, out, False);
            assert (out / "shared.jir").is_file();
            assert (out / "exported.jir").is_file();
            assert not (out / "unused.jir").exists();
            assert precompiler._placement_cache[(str(base), "")][str(shared)]
                == {"client", "server"};
        }
    }
}


test "an explicit app seal follows its entry and excludes unrelated apps" {
    import from jaclang.dist.precompile_bytecode { sealable_sources }
    with tempfile.TemporaryDirectory() as td {
        base = Path(td);
        (base / 'jac.toml').write_text(
            '[project]\nname = "selected"\ndefault-app = "web"\n'
                + '[apps.web]\nkind = "service"\nentry-point = "web"\n'
                + '[apps.scoring]\nkind = "service"\nentry-point = "scoring"\n'
                + '[apps.cli]\nkind = "cli"\nentry-point = "cli"\n'
                + '[apps.desktop]\nkind = "desktop"\nentry-point = "desktop"\n'
        );
        (base / 'web.jac').write_text(
            'import from helper { value }\ndef:pub read -> int { return value(); }\n'
        );
        (base / 'helper.jac').write_text('def:pub value -> int { return 7; }\n');
        (base / 'scoring.jac').write_text('def:pub score -> int { return 42; }\n');
        (base / 'desktop.jac').write_text('def:pub app -> int { return 1; }\n');
        (base / 'cli.jac').write_text('this is deliberately invalid Jac');
        sources = {Path(p).name for p in sealable_sources(td)};
        assert sources == {'web.jac', 'helper.jac', 'scoring.jac'} , sources;
        (base / 'cli.jac').write_text('def:pub main -> int { return 3; }\n');
        assert {Path(p).name for p in sealable_sources(td, 'cli')} == {'cli.jac'};
        assert {Path(p).name for p in sealable_sources(td, 'desktop')}
            == {'desktop.jac'};
    }
}
