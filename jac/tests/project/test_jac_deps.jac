"""Tests for the pure-jac dependency provider ([dependencies.jac]).

Covers jaclang.project.jac_store (URL normalization, tree hashing,
content-addressed fetch from local git fixtures) and
jaclang.project.jac_provider (spec parsing, closure resolution, flat
unification conflicts, [override], deps map, remove).
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.project.config { JacConfig }
import from jaclang.project.jac_store {
    JacDepError,
    dirhash,
    fetch_package,
    git_package_name,
    materialize,
    normalize_git_url,
    store_root
}
import from jaclang.project.jac_provider {
    JacGitProvider,
    JacPackage,
    manifest_jac_deps,
    parse_jac_spec,
    pth_lines,
    read_deps_map,
    read_deps_roots,
    version_satisfied
}
import from jaclang.project.providers { InstallContext, get_provider_registry }
import from jaclang.project.lockfile {
    jac_lock_rows,
    read_lock,
    update_jac_rows,
    write_lock
}


def make_git_repo(path: Path, jac_toml: str, files: dict, branch: str = "") -> str {
    path.mkdir(parents=True, exist_ok=True);
    (path / "jac.toml").write_text(jac_toml, encoding="utf-8");
    for (name, content) in files.items() {
        target = path / name;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(content, encoding="utf-8");
    }
    env = dict(os.environ);
    subprocess.run(
        ["git", "init", "-q"] + (["-b", branch] if branch else []) + [str(path)],
        check=True,
        env=env
    );
    subprocess.run(
        [
            "git",
            "-C",
            str(path),
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "add",
            "-A"
        ],
        check=True,
        env=env
    );
    subprocess.run(
        [
            "git",
            "-C",
            str(path),
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "commit",
            "-q",
            "-m",
            "init"
        ],
        check=True,
        env=env
    );
    return str(path);
}


def make_project(toml_text: str) -> tuple[JacConfig, str] {
    tmp = tempfile.mkdtemp(prefix="jac_dep_test_");
    project_dir = Path(tmp) / "proj";
    project_dir.mkdir();
    (project_dir / "jac.toml").write_text(toml_text, encoding="utf-8");
    config = JacConfig.load(project_dir / "jac.toml");
    config.project_root = project_dir;
    return (config, tmp);
}


def isolate_store -> tuple {
    tmp = tempfile.mkdtemp(prefix="jac_store_test_");
    old = os.environ.get("JAC_GLOBAL_DIR");
    os.environ["JAC_GLOBAL_DIR"] = tmp;
    return (tmp, old);
}


def restore_store(tmp: str, old: str | None) {
    if old is None {
        os.environ.pop("JAC_GLOBAL_DIR", None);
    } else {
        os.environ["JAC_GLOBAL_DIR"] = old;
    }
    shutil.rmtree(tmp, ignore_errors=True);
}

def git_head(path: Path) -> str {
    return subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True
    ).stdout.strip();
}


def git_commit_all(path: Path, message: str = "next") -> str {
    env = dict(os.environ);
    subprocess.run(["git", "-C", str(path), "add", "-A"], check=True, env=env);
    subprocess.run(
        [
            "git",
            "-C",
            str(path),
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "commit",
            "-q",
            "-m",
            message
        ],
        check=True,
        env=env
    );
    return git_head(path);
}


def git_branch(path: Path) -> str {
    return subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--abbrev-ref", "HEAD"],
        check=True,
        capture_output=True,
        text=True
    ).stdout.strip();
}


# ===== URL and spec parsing =====
test "normalize_git_url canonical forms" {
    assert normalize_git_url("github.com/foo/bar") == "https://github.com/foo/bar";
    assert (
        normalize_git_url("https://github.com/foo/bar.git")
        == "https://github.com/foo/bar"
    );
    assert (
        normalize_git_url("git@github.com:foo/bar/") == "https://github.com/foo/bar"
    );
    assert (
        normalize_git_url("ssh://git@github.com/foo/bar")
        == "https://github.com/foo/bar"
    );
    assert normalize_git_url("/tmp/some/repo") == "/tmp/some/repo";
    assert normalize_git_url("../local/repo") == "../local/repo";
    raised = False;
    try {
        normalize_git_url("ftp://example.com/x");
    } except JacDepError {
        raised = True;
    }
    assert raised;
}

test "git_package_name extracts last segment" {
    assert git_package_name("github.com/foo/my-lib.git") == "my-lib";
    assert git_package_name("/tmp/some/repo/") == "repo";
}

test "parse_jac_spec forms" {
    (name, ent) = parse_jac_spec("jac:github.com/foo/mylib");
    assert name == "mylib";
    assert ent == {"git": "github.com/foo/mylib"};
    (name, ent) = parse_jac_spec("jac:github.com/foo/mylib@v1.2");
    assert ent == {"git": "github.com/foo/mylib", "ref": "v1.2"};
    (name, ent) = parse_jac_spec("jac:github.com/foo/mylib@" + "a" * 40);
    assert ent == {"git": "github.com/foo/mylib", "commit": "a" * 40};
    (name, ent) = parse_jac_spec("jac:../utils");
    assert name == "utils";
    assert ent == {"path": "../utils"};
    raised = False;
    try {
        parse_jac_spec("jac:justaname");
    } except JacDepError {
        raised = True;
    }
    assert raised;
}

# ===== tree hashing =====
test "dirhash stable, sensitive, ignores junk dirs" {
    tmp = tempfile.mkdtemp(prefix="jac_hash_test_");
    try {
        a = Path(tmp) / "a";
        b = Path(tmp) / "b";
        for d in (a, b) {
            d.mkdir();
            (d / "lib.jac").write_text("def f -> int { return 1; }\n");
            (d / ".jac").mkdir();
            (d / ".jac" / "cache.bin").write_text("junk");
        }
        assert dirhash(a) == dirhash(b);
        (a / "extra.jac").write_text("def g {}\n");
        assert dirhash(a) != dirhash(b);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


def make_plain_pkg(path: Path, jac_toml: str, files: dict) -> str {
    path.mkdir(parents=True, exist_ok=True);
    (path / "jac.toml").write_text(jac_toml, encoding="utf-8");
    for (name, content) in files.items() {
        (path / name).write_text(content, encoding="utf-8");
    }
    return str(path);
}


# ===== manifest table round-trip =====
test "jac manifest table round-trips through save" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\n'
        'mylib = { git = "github.com/foo/mylib", branch = "main" }\n\n'
        '[dev-dependencies.jac]\n'
        'utils = { path = "../utils" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        (deps, dev_deps) = manifest_jac_deps(config);
        assert deps["mylib"]["git"] == "github.com/foo/mylib";
        assert deps["mylib"]["branch"] == "main";
        assert dev_deps["utils"]["path"] == "../utils";
        config.save();
        toml_loc = config.toml_path;
        assert toml_loc is not None;
        reloaded = JacConfig.load(toml_loc);
        (deps2, dev_deps2) = manifest_jac_deps(reloaded);
        assert deps2["mylib"] == deps["mylib"];
        assert dev_deps2["utils"] == dev_deps["utils"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

# ===== closure resolution (path deps, offline) =====
test "path dep closure writes deps map" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nlibb = { path = "../libb" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        libb = base / "libb";
        libc = base / "libc";
        libc.mkdir();
        (libc / "jac.toml").write_text(
            '[project]\nname = "libc"\nversion = "1.0.0"\n', encoding="utf-8"
        );
        (libc / "libc.jac").write_text(
            "def c() -> int { return 3; }\n", encoding="utf-8"
        );
        make_plain_pkg(
            libb,
            '[project]\nname = "libb"\nversion = "1.0.0"\n\n'
            '[dependencies.jac]\nlibc = { path = "../libc" }\n',
            {"libb.jac": "def b() -> int { return 2; }\n"}
        );
        provider = JacGitProvider();
        resolved = provider.resolve_closure(config, InstallContext());
        assert sorted(resolved.keys()) == ["libb", "libc"];
        assert resolved["libc"].requested_by == ["libb"];
        assert resolved["libc"].local_path == libc.resolve();
        provider.save_deps_map(config, resolved);
        map_path = config.get_build_dir() / "deps.json";
        assert map_path.is_file();
        roots = read_deps_roots(config.project_root or Path.cwd());
        assert len(roots) == 2;
        assert str(libb.resolve()) in [str(Path(r).resolve()) for r in roots];
        lines = pth_lines(resolved);
        assert sorted(str(Path(p).resolve()) for p in lines)
            == sorted([str(libb.resolve()), str(libc.resolve())]);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "name collision across requirers is a hard error" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nx = { path = "../x" }\ny = { path = "../y" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        for pkg in ("x", "y") {
            sub = base / pkg;
            sub_toml = (
                f'[project]\nname = "{pkg}"\nversion = "1.0.0"\n\n'
                f'[dependencies.jac]\nshared = {{ path = "../shared_{pkg}" }}\n'
            );
            make_plain_pkg(sub, sub_toml, {});
            shared = base / f"shared_{pkg}";
            make_plain_pkg(
                shared, '[project]\nname = "shared"\nversion = "1.0.0"\n', {}
            );
        }
        provider = JacGitProvider();
        try {
            provider.resolve_closure(config, InstallContext());
            assert False;
        } except JacDepError as e {
            assert "collision" in str(e);
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "override replaces a transitive entry" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nx = { path = "../x" }\n\n'
        '[override]\nshared = { path = "../shared_override" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        make_plain_pkg(
            base / "x",
            '[project]\nname = "x"\nversion = "1.0.0"\n\n'
            '[dependencies.jac]\nshared = { path = "../shared_x" }\n',
            {}
        );
        make_plain_pkg(
            base / "shared_x", '[project]\nname = "shared"\nversion = "1.0.0"\n', {}
        );
        make_plain_pkg(
            base / "shared_override",
            '[project]\nname = "shared"\nversion = "9.9.9"\n',
            {}
        );
        provider = JacGitProvider();
        resolved = provider.resolve_closure(config, InstallContext());
        shared = resolved["shared"];
        shared_dir = base / "shared_override";
        assert shared.key == os.path.realpath(str(shared_dir));
        assert shared.requested_by == ["x"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

# ===== git deps (local fixture origin) =====
test "git dep fetches into store and dedupes" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_git_test_");
        origin = make_git_repo(
            Path(outer) / "origin",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        fetched = fetch_package(url=origin, ref="");
        assert Path(fetched["path"]).is_dir();
        assert (Path(fetched["path"]) / "mylib.jac").is_file();
        assert fetched["tree"].startswith("sha256-");
        assert not (Path(fetched["path"]) / ".git").exists();
        refetched = fetch_package(url=origin, sha=fetched["sha"]);
        assert refetched["path"] == fetched["path"];
        assert refetched["tree"] == fetched["tree"];
        assert store_root().is_dir();
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}

test "git dep end-to-end through the provider" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_git_e2e_");
        origin = make_git_repo(
            Path(outer) / "origin",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{origin}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacGitProvider();
            ok = provider.install_all(config, [], InstallContext());
            assert ok;
            roots = read_deps_roots(config.project_root or Path.cwd());
            assert len(roots) == 1;
            assert (Path(roots[0]) / "mylib.jac").is_file();
            local = config.get_build_dir() / "packages" / "mylib";
            assert (local / "mylib.jac").is_file();
            assert (local / "jac.toml").is_file();
            assert not (local / ".git").exists();
            resolved = provider.resolve_closure(config, InstallContext());
            assert resolved["mylib"].version == "1.2.0";
            assert resolved["mylib"].sha;
            ok2 = provider.remove_package(config, "mylib", False, InstallContext());
            assert ok2;
            assert read_deps_roots(config.project_root or Path.cwd()) == [];
            (deps, _) = manifest_jac_deps(config);
            assert "mylib" not in deps;
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}

test "registry exposes the jac provider" {
    registry = get_provider_registry();
    provider = registry.get("jac");
    assert provider is not None;
    assert provider.name == "jac";
    assert registry.get_by_flag("--npm") is not None;
}

# ===== jac.lock =====
test "lock rows round-trip through install" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_lock_rt_");
        origin = make_git_repo(
            Path(outer) / "origin",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{origin}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacGitProvider();
            ok = provider.install_all(config, [], InstallContext());
            assert ok;
            lock_file = (config.project_root or Path.cwd()) / "jac.lock";
            assert lock_file.is_file();
            rows = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert "mylib" in rows;
            row = rows["mylib"];
            assert row["git"] == origin;
            assert row["sha"];
            assert row["tree"].startswith("sha256-");
            assert row["version"] == "1.2.0";
            assert row["requested_by"] == ["root"];
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}

test "frozen replay keeps the recorded commit" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_lock_fz_");
        origin_path = Path(outer) / "origin";
        origin = make_git_repo(
            origin_path,
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{origin}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacGitProvider();
            ok = provider.install_all(config, [], InstallContext());
            assert ok;
            rows = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            pinned_sha = rows["mylib"]["sha"];
            (origin_path / "extra.jac").write_text(
                "def extra() -> int { return 7; }\n", encoding="utf-8"
            );
            env = dict(os.environ);
            subprocess.run(
                ["git", "-C", str(origin_path), "add", "-A"], check=True, env=env
            );
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(origin_path),
                    "-c",
                    "user.name=t",
                    "-c",
                    "user.email=t@t",
                    "commit",
                    "-q",
                    "-m",
                    "second"
                ],
                check=True,
                env=env
            );
            replayed = provider.resolve_closure(
                config,
                InstallContext(frozen=True),
                frozen_pins=jac_lock_rows(read_lock(config.project_root or Path.cwd()))
            );
            assert replayed["mylib"].sha == pinned_sha;
            fresh = provider.resolve_closure(config, InstallContext());
            assert fresh["mylib"].sha != pinned_sha;
            assert update_jac_rows(config.project_root or Path.cwd(), fresh);
            rows2 = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert rows2["mylib"]["sha"] == fresh["mylib"].sha;
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "frozen install_all replays a moved branch from the recorded commit" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_lock_fzb_");
        origin_path = Path(outer) / "origin";
        origin = make_git_repo(
            origin_path,
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"},
            branch="main"
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\n'
            f'mylib = {{ git = "{origin}", branch = "main" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacGitProvider();
            assert provider.install_all(config, [], InstallContext());
            rows = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert rows["mylib"]["ref"] == "main";
            pinned_sha = rows["mylib"]["sha"];
            # main advances past the recorded commit.
            (origin_path / "mylib.jac").write_text(
                "def hello() -> int { return 43; }\n", encoding="utf-8"
            );
            moved = git_commit_all(origin_path, "advance main");
            assert moved != pinned_sha;
            # Cold store: the replay must re-fetch, so it exercises the
            # commit-first checkout instead of a store hit.
            store_dir = store_root();
            for item in store_dir.iterdir() {
                if item.is_dir() {
                    shutil.rmtree(item, ignore_errors=True);
                } else {
                    item.unlink();
                }
            }
            assert provider.install_all(config, [], InstallContext(frozen=True));
            rows2 = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert rows2["mylib"]["sha"] == pinned_sha;
            assert rows2["mylib"]["ref"] == "main";
            # A fresh (non-frozen, pin-free) resolution still follows main.
            fresh = provider.resolve_closure(config, InstallContext());
            assert fresh["mylib"].sha == moved;
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}

test "frozen install errors when manifest is ahead of lock" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_lock_st_");
        origin = make_git_repo(
            Path(outer) / "origin",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        origin2 = make_git_repo(
            Path(outer) / "origin2",
            '[project]\nname = "otherlib"\nversion = "2.0.0"\n',
            {"otherlib.jac": "def other() -> int { return 1; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{origin}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacGitProvider();
            ok = provider.install_all(config, [], InstallContext());
            assert ok;
            section = config.plugin_dependencies.setdefault("jac", {});
            section["newdep"] = {"git": origin2};
            config.save();
            frozen_ok = provider.install_all(config, [], InstallContext(frozen=True));
            assert not frozen_ok;
            fresh_ok = provider.install_all(config, [], InstallContext());
            assert fresh_ok;
            rows = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert "newdep" in rows;
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}

test "why chains trace reverse edges" {
    import from jaclang.project.lockfile { why_chains }
    lock_data = {
        "jac": {
            "mylib": {"git": "https://x", "requested_by": ["root"]},
            "shared": {"git": "https://y", "requested_by": ["mylib", "other"]}
        },
        "python_graph": {"requests": ["root"], "urllib3": ["requests"]}
    };
    chains = why_chains(lock_data, "urllib3");
    assert chains == [("python", ["urllib3", "requests", "root"])];
    shared_chains = why_chains(lock_data, "shared");
    assert ("jac", ["shared", "mylib", "root"]) in shared_chains;
    assert ("jac", ["shared", "other"]) in shared_chains;
    assert why_chains(lock_data, "mylib") == [("jac", ["mylib", "root"])];
    assert why_chains(lock_data, "nope") == [("jac", ["nope"])];
}


test "dependency paths with control characters are rejected" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nevil = { path = "../ok\\nimport os" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        make_plain_pkg(base / "ok", '[project]\nname = "ok"\nversion = "1.0.0"\n', {});
        provider = JacGitProvider();
        try {
            provider.resolve_closure(config, InstallContext());
            assert False;
        } except JacDepError as e {
            assert "control characters" in str(e);
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "pth lines reject executable injection" {
    pkg = JacPackage(name="x", local_path=Path("/tmp/x\nimport os"));
    try {
        pth_lines({"x": pkg});
        assert False;
    } except JacDepError as e {
        assert "import map" in str(e);
    }
}


test "override resolves a genuine cross-parent conflict" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nx = { path = "../x" }\ny = { path = "../y" }\n\n'
        '[override]\nshared = { path = "../shared_override" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        make_plain_pkg(
            base / "x",
            '[project]\nname = "x"\nversion = "1.0.0"\n\n'
            '[dependencies.jac]\nshared = { path = "../shared_x" }\n',
            {}
        );
        make_plain_pkg(
            base / "y",
            '[project]\nname = "y"\nversion = "1.0.0"\n\n'
            '[dependencies.jac]\nshared = { path = "../shared_y" }\n',
            {}
        );
        make_plain_pkg(
            base / "shared_x", '[project]\nname = "shared"\nversion = "1.0.0"\n', {}
        );
        make_plain_pkg(
            base / "shared_y", '[project]\nname = "shared"\nversion = "2.0.0"\n', {}
        );
        make_plain_pkg(
            base / "shared_override",
            '[project]\nname = "shared"\nversion = "9.9.9"\n',
            {}
        );
        provider = JacGitProvider();
        resolved = provider.resolve_closure(config, InstallContext());
        assert sorted(resolved.keys()) == ["shared", "x", "y"];
        assert resolved["shared"].key
            == os.path.realpath(str(base / "shared_override"));
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
test "failed replacement restores the previous dependency entry" {
    # Replacing an existing dep with a spec that fails to resolve must
    # restore the overwritten entry in jac.toml: the valid dependency
    # survives, only the failed spec is discarded.
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nlibb = { path = "../libb" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        make_plain_pkg(
            base / "libb",
            '[project]\nname = "libb"\nversion = "1.0.0"\n',
            {"libb.jac": "def b() -> int { return 2; }\n"}
        );
        broken = base / "broken" / "libb";
        broken.mkdir(parents=True);
        provider = JacGitProvider();
        via = provider.add_spec(config, "jac:file://" + str(broken));
        assert via is None;
        (deps, dev_deps) = manifest_jac_deps(config);
        assert "libb" in deps;
        assert str(deps["libb"].get("path", "")) == "../libb";
        reloaded = JacConfig.load(Path(str(config.project_root)) / "jac.toml");
        (disk_deps, disk_dev) = manifest_jac_deps(reloaded);
        assert "libb" in disk_deps;
        assert str(disk_deps["libb"].get("path", "")) == "../libb";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "failed no-save install restores the recorded package state" {
    # A mid-closure materialization failure must not leave .jac/packages
    # holding code the deps map does not describe: the sweep failure rolls
    # package dirs back to the deps map recorded on disk.
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_nosave_t_");
        libb_origin = make_git_repo(
            Path(outer) / "libb",
            '[project]\nname = "libb"\nversion = "1.0.0"\n',
            {"libb.jac": "def b() -> int { return 2; }\n"}
        );
        fresh_origin = make_git_repo(
            Path(outer) / "fresh1",
            '[project]\nname = "fresh1"\nversion = "1.0.0"\n',
            {"fresh1.jac": "def f() -> int { return 1; }\n"}
        );
        broken_origin = make_git_repo(
            Path(outer) / "breakme",
            '[project]\nname = "breakme"\nversion = "1.0.0"\n',
            {"breakme.jac": "def m() -> int { return 0; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            '[dependencies.jac]\nlibb = { git = "file://' + libb_origin + '" }\n'
        );
        (config, tmp) = make_project(toml_text);
        provider = JacGitProvider();
        # Seed a good recorded state: resolve, materialize, save the map.
        seeded = provider.resolve_closure(config, InstallContext());
        provider.save_deps_map(config, seeded);
        packages_root = config.get_build_dir() / "packages";
        assert (packages_root / "libb").is_dir();
        def fake_materialize(src: Path, dest: Path) -> Path {
            if Path(str(dest)).name == "breakme" {
                raise OSError("simulated mid-sweep failure");
            }
            return materialize(src, dest);
        }
        with patch(
            "jaclang.project.jac_provider.materialize", fake_materialize
        ) {
            ok = provider.install_no_save(
                config,
                ["jac:file://" + fresh_origin, "jac:file://" + broken_origin],
                InstallContext()
            );
        }
        assert ok is False;
        data = read_deps_map(config);
        names = sorted(
            p.get("name", "")
            for p in data.get("packages", [])
            if isinstance(p, dict)
        );
        assert names == ["libb"];
        assert (packages_root / "libb").is_dir();
        assert not (packages_root / "fresh1").exists();
        assert not (packages_root / "breakme").exists();
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "frozen install fails when a transitive dep misses the lock" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_frozen_t_");
        sub_origin = make_git_repo(
            Path(outer) / "sub",
            '[project]\nname = "sub"\nversion = "1.0.0"\n',
            {"sub.jac": "def s() -> int { return 1; }\n"}
        );
        mylib_origin = make_git_repo(
            Path(outer) / "mylib",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n\n'
            f'[dependencies.jac]\nsub = {{ git = "{sub_origin}" }}\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{mylib_origin}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacGitProvider();
            assert provider.install_all(config, [], InstallContext());
            lock = read_lock(config.project_root or Path.cwd());
            rows = jac_lock_rows(lock);
            assert "sub" in rows;
            del rows["sub"];
            lock["jac"] = rows;
            assert write_lock(config.project_root or Path.cwd(), lock);
            assert not provider.install_all(config, [], InstallContext(frozen=True));
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "targeted replay keeps non-targeted deps pinned" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_targeted_");
        origin_a_path = Path(outer) / "a";
        origin_a = make_git_repo(
            origin_a_path,
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        origin_b = make_git_repo(
            Path(outer) / "b",
            '[project]\nname = "otherlib"\nversion = "2.0.0"\n',
            {"otherlib.jac": "def other() -> int { return 1; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{origin_a}" }}\n'
            f'otherlib = {{ git = "{origin_b}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacGitProvider();
            assert provider.install_all(config, [], InstallContext());
            old_b = jac_lock_rows(read_lock(config.project_root or Path.cwd()))[
                "otherlib"
            ]["sha"];
            (origin_a_path / "extra.jac").write_text(
                "def extra() -> int { return 7; }\n", encoding="utf-8"
            );
            new_a = git_commit_all(origin_a_path, "advance");
            pins = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert pins["mylib"]["sha"] != new_a;
            del pins["mylib"];
            resolved = provider.resolve_closure(
                config, InstallContext(), frozen_pins=pins
            );
            assert resolved["mylib"].sha == new_a;
            assert resolved["otherlib"].sha == old_b;
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "dedupe keeps the requested origin provenance" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_dedupe_");
        payload = '[project]\nname = "mylib"\nversion = "1.2.0"\n';
        files = {"mylib.jac": "def hello() -> int { return 42; }\n"};
        origin_a = make_git_repo(Path(outer) / "a", payload, files);
        origin_b = make_git_repo(Path(outer) / "b", payload, files);
        env = dict(os.environ);
        subprocess.run(
            [
                "git",
                "-C",
                str(Path(outer) / "b"),
                "-c",
                "user.name=t",
                "-c",
                "user.email=t@t",
                "commit",
                "-q",
                "--allow-empty",
                "-m",
                "second"
            ],
            check=True,
            env=env
        );
        sha_a = git_head(Path(outer) / "a");
        sha_b = git_head(Path(outer) / "b");
        assert sha_a != sha_b;
        first = fetch_package(url=origin_a, ref="");
        second = fetch_package(url=origin_b, ref="");
        assert first["tree"] == second["tree"];
        assert first["path"] == second["path"];
        assert second["sha"] == sha_b;
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "moved tag fails and moved branch replays" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_ref_check_");
        origin_path = Path(outer) / "origin";
        origin = make_git_repo(
            origin_path,
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        head1 = git_head(origin_path);
        subprocess.run(["git", "-C", str(origin_path), "tag", "v1"], check=True);
        (origin_path / "mylib.jac").write_text(
            "def hello() -> int { return 43; }\n", encoding="utf-8"
        );
        head2 = git_commit_all(origin_path, "move on");
        subprocess.run(
            ["git", "-C", str(origin_path), "tag", "-f", "v1", head2],
            check=True,
            capture_output=True
        );
        branch = git_branch(origin_path);
        replayed = fetch_package(url=origin, ref=branch, sha=head1);
        assert replayed["sha"] == head1;
        try {
            fetch_package(url=origin, ref="v1", sha=head1);
            assert False;
        } except JacDepError as e {
            assert "no longer resolves" in str(e);
        }
        ok = fetch_package(url=origin, ref="v1", sha=head2);
        assert ok["sha"] == head2;
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "materialization copies files and preserves symlinks" {
    tmp = tempfile.mkdtemp(prefix="jac_material_");
    try {
        src = Path(tmp) / "src";
        (src / "sub").mkdir(parents=True);
        (src / "a.txt").write_text("one", encoding="utf-8");
        (src / "sub" / "b.txt").write_text("two", encoding="utf-8");
        outside = Path(tmp) / "outside";
        outside.mkdir();
        os.symlink(str(outside), str(src / "link"));
        dest = Path(tmp) / "dest";
        materialize(src, dest);
        assert (dest / "a.txt").is_file();
        assert (dest / "link").is_symlink();
        (dest / "a.txt").write_text("CHANGED", encoding="utf-8");
        assert (src / "a.txt").read_text(encoding="utf-8") == "one";
        assert (dest / "link").resolve() == outside.resolve();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "lock writer emits valid TOML for odd names and values" {
    tmp = tempfile.mkdtemp(prefix="jac_lock_toml_");
    try {
        ok = write_lock(
            Path(tmp),
            {
                "jac": {
                    "my.json": {
                        "git": "https://x/my-json",
                        "path": "C:\\Users\\x\"y",
                        "sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                        "tree": "sha256-deadbeef",
                        "requested_by": ["root"]
                    },
                    "plain": {
                        "git": "https://x/plain",
                        "sha": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
                    }
                },
                "python": {"some-pkg": "==1.0.0"},
                "python_graph": {"requests": ["root"]},
                "npm": {"left-pad": "1.2.3"}
            }
        );
        assert ok;
        data = read_lock(Path(tmp));
        rows = jac_lock_rows(data);
        assert rows["my.json"]["path"] == "C:\\Users\\x\"y";
        assert rows["my.json"]["requested_by"] == ["root"];
        assert data["python"]["some-pkg"] == "==1.0.0";
        assert data["python_graph"]["requests"] == ["root"];
        assert data["npm"]["left-pad"] == "1.2.3";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "why chains surface every ecosystem for a shared name" {
    import from jaclang.project.lockfile { why_chains }
    lock_data = {
        "jac": {"dup": {"git": "https://x", "requested_by": ["root"]}},
        "python_graph": {"dup": ["root"], "requests": ["root"]}
    };
    chains = why_chains(lock_data, "dup");
    assert len(chains) == 2;
    assert ("jac", ["dup", "root"]) in chains;
    assert ("python", ["dup", "root"]) in chains;
}


test "read_deps_roots ignores malformed deps maps" {
    import from jaclang.project.config { get_config, set_config }
    cwd = os.getcwd();
    payloads = [
        '[]',
        '7',
        '"str"',
        '{"packages": 5}',
        '{"packages": ["nope", 7, null, {"local": 9}]}'
    ];
    try {
        # Each case gets its own fresh project dir: a fresh deps.json path
        # means a fresh _deps_roots_cache key, so no case can serve a stale
        # cache entry on coarse-mtime filesystems.
        for payload in payloads {
            case_dir = Path(tempfile.mkdtemp(prefix="jac_deps_roots_"));
            (case_dir / "jac.toml").write_text(
                '[project]\nname = "proj"\nversion = "0.1.0"\n', encoding="utf-8"
            );
            os.chdir(case_dir);
            set_config(None);
            config = get_config();
            assert config is not None;
            config.get_build_dir().mkdir(parents=True, exist_ok=True);
            (config.get_build_dir() / "deps.json").write_text(
                payload, encoding="utf-8"
            );
            assert read_deps_roots(case_dir) == [] , (
                f"malformed deps map not ignored: {payload}"
            );
        }
        # A well-formed map still yields its existing local roots.
        good = Path(tempfile.mkdtemp(prefix="jac_deps_roots_"));
        (good / "jac.toml").write_text(
            '[project]\nname = "proj"\nversion = "0.1.0"\n', encoding="utf-8"
        );
        os.chdir(good);
        set_config(None);
        gconfig = get_config();
        assert gconfig is not None;
        gconfig.get_build_dir().mkdir(parents=True, exist_ok=True);
        pkg_dir = good / "vendor" / "local_pkg";
        pkg_dir.mkdir(parents=True);
        (gconfig.get_build_dir() / "deps.json").write_text(
            f'{{"packages": ["junk", {{"local": "{pkg_dir}"}}]}}', encoding="utf-8"
        );
        assert read_deps_roots(good) == [str(pkg_dir)];
    } finally {
        os.chdir(cwd);
        set_config(None);
    }
}


test "safe dependency name check rejects traversal components" {
    import from jaclang.project.jac_provider { _safe_dep_name }
    bs = chr(92);
    ok = ["mylib", "my-lib", "My_Lib2", "a.b.c", "lib-1.2"];
    for name in ok {
        assert _safe_dep_name(name) , f"safe name rejected: {name}";
    }
    bad = [
        "",
        ".",
        "..",
        "a/b",
        bs.join(["..", "..", "escaped"]),
        "C:" + bs + "temp",
        "con",
        "COM1",
        "nul.txt",
        " x",
        "x ",
        "x.",
        "a" + chr(9)
    ];
    for name in bad {
        assert not _safe_dep_name(name) , f"unsafe name accepted: {name}";
    }
}


test "transitive dependency with unsafe name is rejected" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_unsafe_name_");
        bs = chr(92);
        origin_path = Path(outer) / "origin";
        # Windows traversal name: on Windows this escapes .jac/packages.
        bad_name = ".." + bs + ".." + bs + "escaped";
        origin = make_git_repo(
            origin_path,
            "[project]\nname = \"outer\"\nversion = \"1.0.0\"\n\n"
            "[dependencies.jac]\n"
            + "\"" + bad_name + "\" = { path = \"../sibling\" }\n",
            {"outer.jac": "def o() -> int { return 1; }\n"}
        );
        (config, tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nouter = {{ git = "{origin}", branch = "main" }}\n'
        );
        try {
            provider = JacGitProvider();
            assert not provider.install_all(config, [], InstallContext()) , (
                "unsafe transitive dependency name was accepted"
            );
            packages_root = config.get_build_dir() / "packages";
            assert not (config.get_build_dir() / "escaped").exists();
            assert not (Path(tmp) / "escaped").exists();
            if packages_root.is_dir() {
                for item in packages_root.iterdir() {
                    assert item.name == "outer" , (
                        f"unexpected package directory: {item.name}"
                    );
                }
            }
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "frozen install validates path dependency tree hashes" {
    (store_tmp, old_env) = isolate_store();
    try {
        (config, tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            '[dependencies.jac]\nutils = { path = "../utils" }\n'
        );
        utils = Path(tmp) / "utils";
        utils.mkdir();
        (utils / "jac.toml").write_text(
            '[project]\nname = "utils"\nversion = "1.0.0"\n', encoding="utf-8"
        );
        (utils / "utils.jac").write_text(
            "def u() -> int { return 1; }\n", encoding="utf-8"
        );
        project_dir = Path(tmp) / "proj";
        try {
            provider = JacGitProvider();
            assert provider.install_all(config, [], InstallContext());
            rows = jac_lock_rows(read_lock(project_dir));
            assert os.path.realpath(rows["utils"]["path"]) == os.path.realpath(
                str(utils)
            ) , f"lock row path mismatch: {rows['utils']}";
            assert rows["utils"]["tree"] , "lock row records no tree hash";

            # Unchanged content: frozen replay succeeds.
            assert provider.install_all(config, [], InstallContext(frozen=True));

            # Content drift must fail the frozen replay.
            (utils / "utils.jac").write_text(
                "def u() -> int { return 999; }\n", encoding="utf-8"
            );
            assert not provider.install_all(
                config, [], InstallContext(frozen=True)
            ) , "frozen replay accepted drifted path dependency content";

            # Restoring the recorded content unblocks the replay.
            (utils / "utils.jac").write_text(
                "def u() -> int { return 1; }\n", encoding="utf-8"
            );
            assert provider.install_all(config, [], InstallContext(frozen=True));
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "frozen install requires lock rows for transitive path deps" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_frozen_tpath_");
        origin_path = Path(outer) / "origin";
        origin = make_git_repo(
            origin_path,
            '[project]\nname = "outer"\nversion = "1.0.0"\n\n'
            '[dependencies.jac]\ntv = { path = "tv" }\n',
            {
                "outer.jac": "def o() -> int { return 1; }\n",
                "tv/jac.toml": '[project]\nname = "tv"\nversion = "1.0.0"\n',
                "tv/tv.jac": "def t() -> int { return 2; }\n"
            },
            branch="main"
        );
        (config, tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nouter = {{ git = "{origin}", branch = "main" }}\n'
        );
        project_dir = Path(tmp) / "proj";
        try {
            provider = JacGitProvider();
            assert provider.install_all(config, [], InstallContext());
            rows = jac_lock_rows(read_lock(project_dir));
            assert "tv" in rows , f"transitive path dep not locked: {rows.keys()}";

            # Drop the transitive path row: frozen replay must fail.
            import from jaclang.project.lockfile { write_lock }
            trimmed = {name: row for (name, row) in rows.items() if name != "tv"};
            assert write_lock(project_dir, {"jac": trimmed});
            assert not provider.install_all(
                config, [], InstallContext(frozen=True)
            ) , "frozen replay accepted a missing transitive path lock row";

            # Restore the full lock: frozen replay succeeds again.
            assert write_lock(project_dir, {"jac": rows});
            assert provider.install_all(config, [], InstallContext(frozen=True));
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "no-save install materializes without touching manifest or lock" {
    import from jaclang.cli.commands { project }
    import from jaclang.project.config { set_config }
    import from jaclang.project.jac_provider { read_deps_map }
    (store_tmp, old_env) = isolate_store();
    cwd = os.getcwd();
    try {
        outer = tempfile.mkdtemp(prefix="jac_nosave_");
        # The install derives the dep name from the URL's last segment.
        origin_path = Path(outer) / "mylib";
        origin = make_git_repo(
            origin_path,
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        (config, tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n'
        );
        project_dir = Path(tmp) / "proj";
        try {
            os.chdir(project_dir);
            set_config(None);
            toml_before = (project_dir / "jac.toml").read_text(encoding="utf-8");

            result = project.install(
                packages=[f"jac:file://{origin}"], no_save=True
            );
            assert result == 0 , f"no-save install failed: {result}";

            # Manifest untouched; no lock created.
            assert (project_dir / "jac.toml").read_text(
                encoding="utf-8"
            ) == toml_before , "jac.toml was modified by --no-save";
            assert not (project_dir / "jac.lock").exists() , (
                "--no-save wrote a lockfile"
            );

            # But the closure is installed into the project's dep state.
            fresh = JacConfig.load(project_dir / "jac.toml");
            fresh.project_root = project_dir;
            installed = {
                p.get("name", "")
                for p in read_deps_map(fresh).get("packages", [])
            };
            assert "mylib" in installed , f"deps map missing mylib: {installed}";
            assert (
                fresh.get_build_dir() / "packages" / "mylib" / "mylib.jac"
            ).is_file() , "mylib was not materialized under .jac/packages";

            # Import path discovery picks the materialized root up.
            roots = read_deps_roots(project_dir);
            assert any("mylib" in p for p in roots) , (
                f"deps roots do not include mylib: {roots}"
            );
        } finally {
            os.chdir(cwd);
            set_config(None);
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "why chains keep same-shaped chains across ecosystems" {
    import from jaclang.project.lockfile { why_chains }
    lock_data = {
        "jac": {"dup": {"git": "https://x", "requested_by": []}},
        "npm": {"dup": "1.0.0"}
    };
    chains = why_chains(lock_data, "dup");
    assert ("jac", ["dup"]) in chains , f"jac chain dropped: {chains}";
    assert ("npm", ["dup"]) in chains , (
        f"npm chain suppressed by same-shaped jac chain: {chains}"
    );
    py_lock = {"python_graph": {"dup": []}, "npm": {"dup": "1.0.0"}};
    py_chains = why_chains(py_lock, "dup");
    assert ("python", ["dup"]) in py_chains , f"python chain dropped: {py_chains}";
    assert ("npm", ["dup"]) in py_chains , (
        f"npm chain suppressed by same-shaped python chain: {py_chains}"
    );
}
