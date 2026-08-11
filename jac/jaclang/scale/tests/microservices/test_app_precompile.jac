import io;
import os;
import sys;
import tarfile;
import tempfile;
import from pathlib { Path }
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
    import from jaclang.jac0core.placement_pins { config_module_pin }
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
    import from jaclang.utils.precompile_bytecode { sealable_sources }
    rels = {
        Path(p).relative_to(stage).as_posix() for p in sealable_sources(str(stage))
    };
    assert rels == {"__init__.jac", "svc.jac"} , rels;
    import from jaclang.utils.precompile_bytecode { placement_facts_map }
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
    import from jaclang.utils.precompile_bytecode { sealable_sources }
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
    import from jaclang.utils.precompile_bytecode { main as seal_main }
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


test "a real pod binary seals the app into a .jab (source + _precompiled + manifest)" {
    # The checkout's own binary stands in for the downloaded pod binary; the
    # mechanism (stage -> precompile_bytecode.jac --seal -> pack _precompiled/**)
    # is identical for release binaries.
    jac_bin = Path(__file__).parents[4] / "zig-out" / "bin" / "jac";
    if not jac_bin.is_file() {
        return;
    }
    names = _names(pack_jab(_mini_app(), jac_bin.read_bytes()));
    assert "svc.jac" in names;
    # The sealed manifest sits at the tar root, which is what makes this a .jab.
    assert "_precompiled/MANIFEST.json" in names;
    pre = [
        n
        for n in names
        if n.startswith("_precompiled/")
    ];
    assert any([n.endswith("svc.jir") for n in pre]) , pre;
}
