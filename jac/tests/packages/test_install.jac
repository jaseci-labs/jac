import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.packages.index { forget_registries }
import from jaclang.packages.install { InstallError, sync, write_lock }
import from jaclang.packages.lock { Lockfile }
import from jaclang.packages.resolve { GraphSource, ResolveError, pack_checkout }
import from jaclang.project.config { JacConfig }
import from jaclang.project.dependencies { PackageDep }
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

test "conflicting transitive path sources are rejected in either order" {
    w = _world();
    with patch.dict(os.environ, w.env) {
        write_tree(
            w.tmp / "shared_a",
            {
                "jac.toml": package_toml("local/shared", "1.0.0", ["api"]),
                "api.jac": "def marker -> str { return \"A\"; }\n"
            }
        );
        write_tree(
            w.tmp / "shared_b",
            {
                "jac.toml": package_toml("local/shared", "1.0.0", ["api"]),
                "api.jac": "def marker -> str { return \"B\"; }\n"
            }
        );
        for (name, path) in (("left", "../shared_a"), ("right", "../shared_b")) {
            write_tree(
                w.tmp / name,
                {
                    "jac.toml": (
                        "[project]\nname = \"local/"
                        + name
                        + "\"\n"
                        + "version = \"1.0.0\"\nexports = [\"api\"]\n\n"
                        + "[dependencies]\n\"local/shared\" = { path = \""
                        + path
                        + "\" }\n"
                    ),
                    "api.jac": "def marker -> str { return \"package\"; }\n"
                }
            );
        }
        for (order, label) in (
            (["left", "right"], "left-first"),
            (["right", "left"], "right-first")
        ) {
            app = w.tmp / label;
            write_tree(
                app,
                {
                    "jac.toml": (
                        "[project]\nname = \"app\"\nversion = \"1.0.0\"\n\n"
                        + "[dependencies]\n\"local/"
                        + order[0]
                        + "\" = { path = \"../"
                        + order[0]
                        + "\" }\n\"local/"
                        + order[1]
                        + "\" = { path = \"../"
                        + order[1]
                        + "\" }\n"
                    )
                }
            );
            try {
                sync(_config(app));
                assert False , "conflicting path sources must fail";
            } except InstallError as e {
                message = str(e);
                assert "local/shared" in message , message;
                assert "shared_a" in message and "shared_b" in message , message;
                assert str(w.tmp / "left" / "jac.toml") in message , message;
                assert str(w.tmp / "right" / "jac.toml") in message , message;
            }
            assert not (app / "jac.lock").exists();
            assert not (app / ".jac" / "packages").exists();
        }
    }
}

test "a repeated path source is validated before deduplication" {
    w = _world();
    with patch.dict(os.environ, w.env) {
        write_tree(
            w.tmp / "shared",
            {
                "jac.toml": package_toml("local/shared", "1.0.0", ["api"]),
                "api.jac": "def marker -> str { return \"shared\"; }\n"
            }
        );
        for (name, path) in (("left", "../shared"), ("missing", "../does_not_exist")) {
            write_tree(
                w.tmp / name,
                {
                    "jac.toml": (
                        "[project]\nname = \"local/"
                        + name
                        + "\"\n"
                        + "version = \"1.0.0\"\nexports = [\"api\"]\n\n"
                        + "[dependencies]\n\"local/shared\" = { path = \""
                        + path
                        + "\" }\n"
                    ),
                    "api.jac": "def marker -> str { return \"package\"; }\n"
                }
            );
        }
        for (order, label) in (
            (["left", "missing"], "missing-second"),
            (["missing", "left"], "missing-first")
        ) {
            app = w.tmp / label;
            write_tree(
                app,
                {
                    "jac.toml": (
                        "[project]\nname = \"app\"\nversion = \"1.0.0\"\n\n"
                        + "[dependencies]\n\"local/"
                        + order[0]
                        + "\" = { path = \"../"
                        + order[0]
                        + "\" }\n\"local/"
                        + order[1]
                        + "\" = { path = \"../"
                        + order[1]
                        + "\" }\n"
                    )
                }
            );
            try {
                sync(_config(app));
                assert False , "a missing repeated path source must fail";
            } except InstallError as e {
                assert "does_not_exist" in str(e) , str(e);
            }
            assert not (app / "jac.lock").exists();
            assert not (app / ".jac" / "packages").exists();
        }
    }
}

test "equivalent path aliases still deduplicate" {
    w = _world();
    with patch.dict(os.environ, w.env) {
        write_tree(
            w.tmp / "shared",
            {
                "jac.toml": package_toml("local/shared", "1.0.0", ["api"]),
                "api.jac": "def marker -> str { return \"shared\"; }\n"
            }
        );
        for (name, path) in (("left", "../shared"), ("alias", "../shared/../shared")) {
            write_tree(
                w.tmp / name,
                {
                    "jac.toml": (
                        "[project]\nname = \"local/"
                        + name
                        + "\"\n"
                        + "version = \"1.0.0\"\nexports = [\"api\"]\n\n"
                        + "[dependencies]\n\"local/shared\" = { path = \""
                        + path
                        + "\" }\n"
                    ),
                    "api.jac": "def marker -> str { return \"package\"; }\n"
                }
            );
        }
        app = w.tmp / "aliases";
        write_tree(
            app,
            {
                "jac.toml": (
                    "[project]\nname = \"app\"\nversion = \"1.0.0\"\n\n"
                    + "[dependencies]\n\"local/left\" = { path = \"../left\" }\n"
                    + "\"local/alias\" = { path = \"../alias\" }\n"
                )
            }
        );
        result = sync(_config(app));
        assert result.lock.by_name()["local/shared"].source == "path+../shared";
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

test "symlink aliases preserve local dependency cycles" {
    w = _world();
    with patch.dict(os.environ, w.env) {
        for (name, dependency, path) in (
            ("left", "right", "../right"),
            ("right", "left", "../left_alias")
        ) {
            write_tree(
                w.tmp / name,
                {
                    "jac.toml": package_toml("local/" + name, "1.0.0", ["api"])
                        + "\n[dependencies]\n\"local/"
                        + dependency
                        + "\" = { path = \""
                        + path
                        + "\" }\n",
                    "api.jac": "def ok -> bool { return True; }\n"
                }
            );
        }
        try {
            (w.tmp / "left_alias").symlink_to(w.tmp / "left", target_is_directory=True);
        } except OSError {
            import pytest;
            pytest.skip("directory symlinks are unavailable");
        }
        (w.app / "jac.toml").write_text(
            "[project]\nname = \"app\"\n\n[dependencies]\n"
                + "\"local/left\" = { path = \"../left\" }\n"
        );
        result = sync(_config(w.app));
        assert _versions(result.lock)
            == {"local/left": "1.0.0", "local/right": "1.0.0"};
        assert result.lock.by_name()["local/left"].source == "path+../left";
    }
}

test "repeated git sources compare resolved commits" {
    w = _world();
    repo = w.tmp / "gitpkg";
    write_tree(
        repo,
        {
            "jac.toml": package_toml("acme/gitpkg", "0.1.0", ["mod"]),
            "mod.jac": "def ok -> bool { return True; }\n"
        }
    );
    git_env = {
        ** os.environ,
        "GIT_AUTHOR_NAME": "t",
        "GIT_AUTHOR_EMAIL": "t@example.com",
        "GIT_COMMITTER_NAME": "t",
        "GIT_COMMITTER_EMAIL": "t@example.com"
    };
    for args in (
        ["init", "-q"],
        ["add", "."],
        ["commit", "-q", "-m", "first"],
        ["tag", "first"]
    ) {
        subprocess.run(["git", *args], cwd=str(repo), check=True, env=git_env);
    }
    first = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=str(repo),
        check=True,
        capture_output=True,
        text=True
    ).stdout.strip();
    (repo / "mod.jac").write_text("def ok -> bool { return False; }\n");
    for args in (["add", "."], ["commit", "-q", "-m", "second"]) {
        subprocess.run(["git", *args], cwd=str(repo), check=True, env=git_env);
    }
    with patch.dict(os.environ, w.env) {
        for (old, new) in ((first, "HEAD"), ("HEAD", first)) {
            resolver = GraphSource(root_dir=w.app, registries={});
            resolver.add_local(
                PackageDep(name="acme/gitpkg", git=repo.as_uri(), rev=old),
                w.tmp / "left"
            );
            try {
                resolver.add_local(
                    PackageDep(name="acme/gitpkg", git=repo.as_uri(), rev=new),
                    w.tmp / "right"
                );
                assert False , "different commits must not silently deduplicate";
            } except ResolveError as e {
                message = str(e);
                assert "acme/gitpkg" in message and first in message , message;
                assert str(w.tmp / "left" / "jac.toml") in message , message;
                assert str(w.tmp / "right" / "jac.toml") in message , message;
            }
        }
        resolver = GraphSource(root_dir=w.app, registries={});
        with patch(
            "jaclang.packages.resolve.pack_checkout", wraps=pack_checkout
        ) as pack {
            original = resolver.add_local(
                PackageDep(name="acme/gitpkg", git=repo.as_uri(), rev=first), w.app
            );
            alias = resolver.add_local(
                PackageDep(name="acme/gitpkg", git=repo.as_uri(), rev="first"), w.app
            );
            assert alias is original;
            assert pack.call_count == 1;
        }
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
