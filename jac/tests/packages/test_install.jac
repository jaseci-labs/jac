import os;
import shutil;
import subprocess;
import from tempfile { TemporaryDirectory }
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.packages.index { forget_registries }
import from jaclang.packages.install { InstallError, sync, write_lock }
import from jaclang.packages.lock { Lockfile }
import from jaclang.project.config { JacConfig }
import from tests.packages.fixture_registry {
    FixtureRegistry,
    fresh_dir,
    isolated_env,
    package_toml,
    write_tree
}
import from tests.support { jac_command }

glob CORE_V1: str = "def shout(s: str) -> str {\n    return s.upper();\n}\n",
     CORE_V11: str = (
         "def shout(s: str) -> str {\n    return s.upper();\n}\n\n"
         "def whisper(s: str) -> str {\n    return s.lower();\n}\n"
     ),
     WEB_PAGE: str = (
         "import from acme.core.text { shout }\n\n"
         "def title(s: str) -> str {\n    return shout(s) + \"!\";\n}\n"
     ),
     APP_MAIN: str = (
         "import from acme.web.page { title }\n\n"
         "with entry {\n    print(title(\"hi\"));\n}\n"
     );

obj World {
    has tmp: Path,
        registry: FixtureRegistry,
        app: Path,
        env: dict[str, str];
}

def _config(project: Path) -> JacConfig {
    return JacConfig.load(project / "jac.toml");
}

def _world -> World {
    tmp = fresh_dir("jac-pkgs-");
    registry = FixtureRegistry.create(tmp / "registry");
    env = isolated_env(tmp, registry.base_dir);
    world = World(tmp=tmp, registry=registry, app=tmp / "app", env=env);
    with patch.dict(os.environ, env) {
        for (label, version, body) in (
            ("core1", "1.0.0", CORE_V1),
            ("core11", "1.1.0", CORE_V11)
        ) {
            write_tree(
                tmp / label,
                {
                    "jac.toml": package_toml("acme/core", version, ["text"]),
                    "text.jac": body
                }
            );
            registry.publish(tmp / label);
        }
        write_tree(
            tmp / "web",
            {
                "jac.toml": package_toml(
                    "acme/web", "1.0.0", ["page"], {"acme/core": "^1"}
                ),
                "page.jac": WEB_PAGE
            }
        );
        sync(_config(tmp / "web"));
        registry.publish(tmp / "web");
    }
    write_tree(
        world.app,
        {
            "jac.toml": "[project]\nname = \"app\"\n\n[dependencies]\n\"acme/web\" = \"^1\"\n",
            "main.jac": APP_MAIN
        }
    );
    return world;
}

def _versions(lock: Lockfile) -> dict[str, str] {
    return {p.name: p.version for p in lock.packages};
}

def _publish_version(
    registry: FixtureRegistry,
    base: Path,
    name: str,
    version: str,
    deps: dict[str, str] | None = None
) {
    package = base / f'{name.replace("/", "_")}-{version}';
    write_tree(
        package,
        {
            "jac.toml": package_toml(name, version, ["api"], deps),
            "api.jac": f'def version -> str {{ return "{version}"; }}\n'
        }
    );
    registry.publish(package);
}

def _resolver_world(
    base: Path,
    releases: dict[str, dict[str, dict[str, str]]],
    app_dependencies: dict[str, str]
) -> World {
    registry = FixtureRegistry.create(base / "registry");
    env = isolated_env(base, registry.base_dir);
    app = base / "app";
    for (name, versions) in releases.items() {
        for (version, deps) in versions.items() {
            _publish_version(registry, base, name, version, deps);
        }
    }
    dependencies = "";
    for (name, requirement) in app_dependencies.items() {
        dependencies += f'"{name}" = "{requirement}"\n';
    }
    write_tree(
        app,
        {
            "jac.toml": (
                "[project]\nname = \"app\"\nversion = \"0.1.0\"\n\n"
                + "[dependencies]\n"
                + dependencies
            ),
            "main.jac": "with entry { print(\"ok\"); }\n"
        }
    );
    return World(tmp=base, registry=registry, app=app, env=env);
}

def _install_world(w: World) -> Lockfile {
    with patch.dict(os.environ, w.env) {
        cfg = _config(w.app);
        result = sync(cfg);
        write_lock(cfg, result.lock);
        lock = Lockfile.read(w.app / "jac.lock");
        assert lock is not None;
        return lock;
    }
}

def _assert_mounted_version(w: World, package: str, version: str) {
    mount = w.app / ".jac" / "packages" / "local" / package / "api.jac";
    assert mount.exists() , f"missing mounted {package} package";
    assert f'return "{version}"' in mount.read_text() , (
        f"mounted {package} source does not match {version}"
    );
}

test "a rejected candidate cannot enable prereleases" {
    with TemporaryDirectory() as raw {
        base_dir = Path(raw);
        lib_releases = {"1.0.0": {}, "1.1.0": {}, "1.2.0": {}, "1.5.0-beta.1": {}};
        rejected = _resolver_world(
            base_dir / "rejected",
            {
                "local/lib": lib_releases,
                "local/bridge": {
                    "1.0.0": {},
                    "2.0.0": {"local/lib": ">=1.5.0-beta.1", "local/missing": "^1"}
                }
            },
            {"local/bridge": "*", "local/lib": "^1"}
        );
        removed = _resolver_world(
            base_dir / "removed",
            {"local/lib": lib_releases, "local/bridge": {"1.0.0": {}}},
            {"local/bridge": "*", "local/lib": "^1"}
        );
        rejected_lock = _install_world(rejected);
        removed_lock = _install_world(removed);
        expected = {"local/bridge": "1.0.0", "local/lib": "1.2.0"};
        assert _versions(rejected_lock) == expected;
        assert _versions(removed_lock) == expected;
        _assert_mounted_version(rejected, "lib", "1.2.0");
        _assert_mounted_version(removed, "lib", "1.2.0");
    }
}

test "an explicit root prerelease requirement is preserved" {
    with TemporaryDirectory() as raw {
        base_dir = Path(raw);
        lib_releases = {"1.0.0": {}, "1.1.0": {}, "1.2.0": {}, "1.5.0-beta.1": {}};
        explicit = _resolver_world(
            base_dir / "explicit",
            {"local/lib": lib_releases, "local/bridge": {"1.0.0": {}}},
            {"local/bridge": "*", "local/lib": ">=1.5.0-beta.1"}
        );
        explicit_lock = _install_world(explicit);
        assert _versions(explicit_lock)["local/lib"] == "1.5.0-beta.1";
        _assert_mounted_version(explicit, "lib", "1.5.0-beta.1");
    }
}

test "a registry package resolves, locks, mounts and imports" {
    w = _world();
    with patch.dict(os.environ, w.env) {
        cfg = _config(w.app);
        result = sync(cfg);
        write_lock(cfg, result.lock);
        assert _versions(result.lock) == {"acme/core": "1.1.0", "acme/web": "1.0.0"};
        web = result.lock.by_name()["acme/web"];
        assert web.source.startswith("registry+") and len(web.sha256) == 64;
        assert web.deps == ["acme/core"];
        mount = w.app / ".jac" / "packages" / "acme" / "web";
        assert mount.is_symlink();
        assert os.path.realpath(mount).startswith(str(w.tmp / "store"));
        again = Lockfile.read(w.app / "jac.lock");
        assert again is not None and _versions(again) == _versions(result.lock);
        env = dict(os.environ);
        run = subprocess.run(
            jac_command("run", "main.jac"),
            cwd=str(w.app),
            capture_output=True,
            text=True,
            env=env
        );
        assert "HI!" in run.stdout , run.stdout + run.stderr;
    }
}

test "the lock keeps a version until an update unlocks it" {
    w = _world();
    with patch.dict(os.environ, w.env) {
        cfg = _config(w.app);
        write_lock(cfg, sync(cfg).lock);
        write_tree(
            w.tmp / "core12",
            {
                "jac.toml": package_toml("acme/core", "1.2.0", ["text"]),
                "text.jac": CORE_V11
            }
        );
        w.registry.publish(w.tmp / "core12");
        kept = sync(_config(w.app));
        assert kept.lock.by_name()["acme/core"].version == "1.1.0";
        assert not kept.resolved;
        moved = sync(_config(w.app), update=["acme/core"]);
        assert moved.lock.by_name()["acme/core"].version == "1.2.0";
    }
}

test "a frozen install refuses a lock that no longer matches jac.toml" {
    w = _world();
    with patch.dict(os.environ, w.env) {
        cfg = _config(w.app);
        write_lock(cfg, sync(cfg).lock);
        (w.app / "jac.toml").write_text(
            "[project]\nname = \"app\"\n\n[dependencies]\n\"acme/web\" = \"^1\"\n\"acme/core\" = \"=1.0.0\"\n"
        );
        try {
            sync(_config(w.app), frozen=True);
            assert False , "a stale lock must fail a frozen install";
        } except InstallError as e {
            assert "out of date" in str(e);
        }
        pinned = sync(_config(w.app));
        assert pinned.lock.by_name()["acme/core"].version == "1.0.0";
    }
}

test "an unsatisfiable graph explains itself" {
    w = _world();
    with patch.dict(os.environ, w.env) {
        (w.app / "jac.toml").write_text(
            "[project]\nname = \"app\"\n\n[dependencies]\n\"acme/web\" = \"^1\"\n\"acme/core\" = \"^2\"\n"
        );
        try {
            sync(_config(w.app));
            assert False , "expected a resolution failure";
        } except InstallError as e {
            assert "acme/core" in str(e) and "version solving failed" in str(e) , str(
                e
            );
        }
    }
}

test "a path dependency mounts the directory in place" {
    w = _world();
    with patch.dict(os.environ, w.env) {
        write_tree(
            w.tmp / "util",
            {
                "jac.toml": package_toml("acme/util", "0.3.0", ["strings"]),
                "strings.jac": "def twice(s: str) -> str {\n    return s + s;\n}\n"
            }
        );
        (w.app / "jac.toml").write_text(
            "[project]\nname = \"app\"\n\n[dependencies]\n\"acme/util\" = { path = \"../util\" }\n"
        );
        result = sync(_config(w.app));
        util = result.lock.by_name()["acme/util"];
        assert util.source == "path+../util" and util.sha256 == "";
        mount = w.app / ".jac" / "packages" / "acme" / "util";
        assert os.path.realpath(mount) == str(w.tmp / "util");
    }
}

test "a git dependency locks its commit and content hash" {
    w = _world();
    repo = w.tmp / "gitpkg";
    write_tree(
        repo,
        {
            "jac.toml": package_toml("acme/gitpkg", "0.1.0", ["mod"]),
            "mod.jac": "def ok -> bool {\n    return True;\n}\n"
        }
    );
    git_env = {
        ** os.environ,
        "GIT_AUTHOR_NAME": "t",
        "GIT_AUTHOR_EMAIL": "t@example.com",
        "GIT_COMMITTER_NAME": "t",
        "GIT_COMMITTER_EMAIL": "t@example.com"
    };
    for args in (["init", "-q"], ["add", "."], ["commit", "-q", "-m", "init"]) {
        subprocess.run(["git", *args], cwd=str(repo), check=True, env=git_env);
    }
    commit = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=str(repo),
        check=True,
        capture_output=True,
        text=True
    ).stdout.strip();
    with patch.dict(os.environ, w.env) {
        (w.app / "jac.toml").write_text(
            "[project]\nname = \"app\"\n\n[dependencies]\n\"acme/gitpkg\" = { git = \""
                + repo.as_uri()
                + "\" }\n"
        );
        result = sync(_config(w.app));
        pkg = result.lock.by_name()["acme/gitpkg"];
        assert pkg.source == f"git+{repo.as_uri()}#{commit}";
        assert len(pkg.sha256) == 64;
        assert os.path.realpath(result.targets["acme/gitpkg"]).startswith(
            str(w.tmp / "store")
        );
    }
}

test "a blob that does not match its index hash is refused" {
    w = _world();
    with patch.dict(os.environ, w.env) {
        cfg = _config(w.app);
        lock = sync(cfg).lock;
        write_lock(cfg, lock);
        shutil.rmtree(w.tmp / "store");
        web = lock.by_name()["acme/web"];
        blob = w.registry.base_dir / "blobs" / f"{web.sha256}.jab";
        blob.write_bytes(blob.read_bytes() + b"tampered");
        forget_registries();
        try {
            sync(_config(w.app));
            assert False , "a tampered blob must not install";
        } except InstallError as e {
            assert "sha256" in str(e) , str(e);
        }
    }
}
