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
import from jaclang.project.config { JacConfig }
import from jaclang.project.jac_store {
    JacDepError,
    dirhash,
    fetch_package,
    git_package_name,
    normalize_git_url,
    store_root
}
import from jaclang.project.jac_provider {
    JacGitProvider,
    manifest_jac_deps,
    parse_jac_spec,
    pth_lines,
    read_deps_roots,
    version_satisfied
}
import from jaclang.project.providers { InstallContext, get_provider_registry }
import from jaclang.project.lockfile { jac_lock_rows, read_lock, update_jac_rows }


def make_git_repo(path: Path, jac_toml: str, files: dict) -> str {
    path.mkdir(parents=True, exist_ok=True);
    (path / "jac.toml").write_text(jac_toml, encoding="utf-8");
    for (name, content) in files.items() {
        target = path / name;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(content, encoding="utf-8");
    }
    env = dict(os.environ);
    subprocess.run(["git", "init", "-q", str(path)], check=True, env=env);
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
    assert chains == [["urllib3", "requests", "root"]];
    shared_chains = why_chains(lock_data, "shared");
    assert ["shared", "mylib", "root"] in shared_chains;
    assert ["shared", "other"] in shared_chains;
    assert why_chains(lock_data, "mylib") == [["mylib", "root"]];
    assert why_chains(lock_data, "nope") == [["nope"]];
}
