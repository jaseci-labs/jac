import atexit;
import io;
import shutil;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle {
    assert_entry_module_ships,
    bundle_source_files,
    pack_jab,
    resolve_service_members,
    resolved_bundle_services,
    source_filter_for
}


glob _JAC_BIN: Path = Path(__file__).parents[4] / "zig-out" / "bin" / "jac",
     _ROOT: Path = Path(tempfile.mkdtemp(prefix="jac-bundle-services-")),
     _ROUTED_TOML: str = (
         "[project]\nname = \"mini\"\n\n[scale.microservices.routes]\n"
         "svc = \"/svc\"\n"
     ),
     _PING: str = "def:pub ping -> str { return \"pong\"; }\n";

with entry {
    atexit.register(shutil.rmtree, str(_ROOT), ignore_errors=True);
}


def _app(toml: str, files: dict[str, str], jacignore: (str | None) = None) -> Path {
    d = Path(tempfile.mkdtemp(dir=str(_ROOT)));
    (d / "jac.toml").write_text(toml);
    for (rel, text) in files.items() {
        p = d / rel;
        p.parent.mkdir(parents=True, exist_ok=True);
        p.write_text(text);
    }
    if jacignore is not None {
        (d / ".jacignore").write_text(jacignore);
    }
    return d;
}


def _members(base: Path) -> list[str] {
    return sorted([p.relative_to(base).as_posix() for p in bundle_source_files(base)]);
}


def _resolve(base: Path) -> dict[str, str] {
    return resolve_service_members(base, _members(base), source_filter_for(base));
}


def _pack_error(base: Path) -> str {
    try {
        pack_jab(str(base), b"binary");
    } except ValueError as e {
        return str(e);
    }
    return "";
}


test "a declared service resolves to its root module by default" {
    base = _app(_ROUTED_TOML, {"svc.jac": _PING, "main.jac": _PING});
    assert _resolve(base) == {"svc": "svc.jac", "main": "main.jac"};
}


test "a root module wins over nested same-named modules" {
    base = _app(
        _ROUTED_TOML, {"svc.jac": _PING, "lib/svc.jac": _PING, "main.jac": _PING}
    );
    assert _resolve(base) == {"svc": "svc.jac", "main": "main.jac"};
}


test "a single nested module resolves deterministically" {
    base = _app(_ROUTED_TOML, {"src/svc.jac": _PING, "main.jac": _PING});
    assert _resolve(base) == {"svc": "src/svc.jac", "main": "main.jac"};
}


test "an explicit file key is honored and validated" {
    toml = (
        _ROUTED_TOML
        + "\n[scale.microservices.services.svc]\nfile = \"src/entry.jac\"\n"
    );
    base = _app(toml, {"src/entry.jac": _PING, "svc.jac": _PING, "main.jac": _PING});
    assert _resolve(base) == {"svc": "src/entry.jac", "main": "main.jac"};
}


test "the implicit main service boots the configured entry point" {
    toml = (
        "[project]\nname = \"mini\"\nentry-point = \"src/app.jac\"\n\n"
        "[scale.microservices.routes]\nsvc = \"/svc\"\n"
    );
    base = _app(toml, {"svc.jac": _PING, "src/app.jac": _PING});
    assert _resolve(base) == {"svc": "svc.jac", "main": "src/app.jac"};
}


test "a same-named root stray never shadows the configured entry point" {
    toml = (
        "[project]\nname = \"mini\"\nentry-point = \"src/app.jac\"\n\n"
        "[scale.microservices.routes]\nsvc = \"/svc\"\n"
    );
    base = _app(toml, {"svc.jac": _PING, "app.jac": _PING, "src/app.jac": _PING});
    assert _resolve(base)["main"] == "src/app.jac";
}


test "same-named modules elsewhere never make the entry point ambiguous" {
    toml = (
        "[project]\nname = \"mini\"\nentry-point = \"src/app.jac\"\n\n"
        "[scale.microservices.routes]\nsvc = \"/svc\"\n"
    );
    base = _app(toml, {"svc.jac": _PING, "lib/app.jac": _PING, "src/app.jac": _PING});
    assert _resolve(base)["main"] == "src/app.jac";
}


test "an explicit main file overrides the entry point" {
    toml = (
        _ROUTED_TOML
        + "\n[scale.microservices.services.main]\nfile = \"boot/root.jac\"\n"
    );
    base = _app(toml, {"svc.jac": _PING, "main.jac": _PING, "boot/root.jac": _PING});
    assert _resolve(base) == {"svc": "svc.jac", "main": "boot/root.jac"};
}


test "a route covering the root suppresses the implicit main service" {
    toml = (
        "[project]\nname = \"mini\"\n\n[scale.microservices.routes]\n" "svc = \"/\"\n"
    );
    base = _app(toml, {"svc.jac": _PING});
    assert _resolve(base) == {"svc": "svc.jac"};
}


test "the resolver follows the routes the deploy emits pods for" {
    toml = "[project]\nname = \"mini\"\nentry-point = \"src/app.jac\"\n";
    base = _app(toml, {"svc.jac": _PING, "src/app.jac": _PING});
    assert resolved_bundle_services(str(base)) == {};
    declared = {"routes": {"svc": "/svc"}};
    assert resolved_bundle_services(str(base), declared)
        == {"svc": "svc.jac", "main": "src/app.jac"};
    normalized = {"routes": {"svc": "/svc", "main": "/__main__"}};
    assert resolved_bundle_services(str(base), normalized)
        == {"svc": "svc.jac", "main": "src/app.jac"};
}


test "the implicit main agrees with local microservice mode for a root entry point" {
    import from jaclang.project.config { get_config }
    import from jaclang.scale.runtime.routing { ensure_main_service }
    toml = (
        "[project]\nname = \"mini\"\nentry-point = \"app.jac\"\n\n"
        "[scale.microservices.routes]\nsvc = \"/svc\"\n"
    );
    base = _app(toml, {"svc.jac": _PING, "app.jac": _PING});
    routes: dict[str, str] = {"svc": "/svc"};
    service_files: dict[str, str] = {"svc": "svc.jac"};
    try {
        get_config(start_path=base, force_discover=True);
        ensure_main_service(routes, service_files);
    } finally {
        get_config(force_discover=True);
    }
    assert service_files["main"] == "app.jac" , service_files;
    assert _resolve(base)["main"] == service_files["main"];
}


test "the pack validates the config the deploy resolved, not jac.toml" {
    base = _app(_ROUTED_TOML, {"svc.jac": _PING, "main.jac": _PING});
    caught = "";
    try {
        pack_jab(str(base), b"binary", ms_config={"routes": {"ghost": "/ghost"}});
    } except ValueError as e {
        caught = str(e);
    }
    assert "'ghost'" in caught , caught;
    assert "'svc'" not in caught , caught;
}


test "a stale jac.toml route never fails a pack the deploy does not route" {
    base = _app(_ROUTED_TOML, {"main.jac": _PING});
    assert "'svc'" in _pack_error(base);
    caught = "";
    try {
        pack_jab(str(base), b"binary", ms_config={"routes": {}});
    } except Exception as e {
        caught = str(e);
    }
    assert "'svc'" not in caught , caught;
}


test "an unparseable jac.toml fails the pack instead of sealing blind" {
    base = _app("[project\nname = \"broken\"\n", {"main.jac": _PING});
    caught = _pack_error(base);
    assert "jac.toml" in caught , caught;
    assert "cannot be parsed" in caught , caught;
}


test "a missing implicit main module fails the pack naming the entry point" {
    base = _app(_ROUTED_TOML, {"svc.jac": _PING, "app.jac": _PING});
    caught = _pack_error(base);
    assert "'main'" in caught , caught;
    assert "main.jac" in caught , caught;
    assert "[project] entry-point" in caught , caught;
}


test "an explicit file that does not exist fails the pack" {
    toml = _ROUTED_TOML + "\n[scale.microservices.services.svc]\nfile = \"gone.jac\"\n";
    base = _app(toml, {"svc.jac": _PING});
    caught = _pack_error(base);
    assert "gone.jac" in caught , caught;
    assert "no such file" in caught , caught;
}


test "ambiguous service modules fail the pack naming every candidate" {
    base = _app(_ROUTED_TOML, {"a/svc.jac": _PING, "b/svc.jac": _PING});
    caught = _pack_error(base);
    assert "a/svc.jac" in caught , caught;
    assert "b/svc.jac" in caught , caught;
    assert "[scale.microservices.services.svc] file" in caught , caught;
}


test "parking a declared service module fails the pack, not the fleet" {
    base = _app(_ROUTED_TOML, {"svc.jac": _PING}, jacignore="svc.jac\n");
    caught = _pack_error(base);
    assert "svc.jac" in caught , caught;
    assert ".jacignore" in caught , caught;
}


test "parking the entry module fails the implicit main, not the fleet" {
    base = _app(
        _ROUTED_TOML, {"svc.jac": _PING, "main.jac": _PING}, jacignore="main.jac\n"
    );
    caught = "";
    try {
        resolved_bundle_services(str(base));
    } except ValueError as e {
        caught = str(e);
    }
    assert "'main'" in caught , caught;
    assert ".jacignore" in caught , caught;
}


test "a missing declared service module fails the pack" {
    base = _app(_ROUTED_TOML, {"other.jac": _PING});
    caught = _pack_error(base);
    assert "svc.jac" in caught , caught;
    assert "no such module" in caught , caught;
}


test "the entry-module guard covers baseline exclusions, not just .jacignore" {
    toml = "[project]\nname = \"mini\"\nentry-point = \"dist/main.jac\"\n";
    base = _app(toml, {"dist/main.jac": _PING});
    caught = "";
    try {
        assert_entry_module_ships(base, source_filter_for(base));
    } except ValueError as e {
        caught = str(e);
    }
    assert "entry module" in caught , caught;
    assert "dist" in caught , caught;
}


test "a sealed .jab ships exactly the sources the resolution ran against" {
    if not _JAC_BIN.is_file() {
        return;
    }
    base = _app(
        _ROUTED_TOML, {"svc.jac": _PING, "lib/svc.jac": _PING, "main.jac": _PING}
    );
    services = _resolve(base);
    raw = pack_jab(str(base), _JAC_BIN.read_bytes());
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        names = tar.getnames();
    }
    shipped_sources = sorted(
        [
            n
            for n in names
            if not n.startswith("_precompiled/") and not n.startswith("_vendor/")
        ]
    );
    assert shipped_sources == sorted(_members(base) + ["jac.toml"]) , (
        shipped_sources,
        _members(base)
    );
    for member in services.values() {
        assert member in names , (member, names);
    }
}
