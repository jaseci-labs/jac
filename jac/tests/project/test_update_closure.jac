"""Regression test for targeted `jac update <targets>` closure advancement.

A targeted update must advance every dependency reachable from the
targets (npm-update-like), not just the targets themselves: a
branch-tracking transitive of an updated root must move with it, while
unrelated packages stay pinned (minimal churn).
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { project }
import from jaclang.project.config { set_config }
import from jaclang.project.jac_provider { JacGitProvider }
import from jaclang.project.providers { InstallContext }
import from jaclang.project.lockfile { jac_lock_rows, read_lock }


def make_git_repo_on_main(path: Path, jac_toml: str, files: dict) -> str {
    path.mkdir(parents=True, exist_ok=True);
    (path / "jac.toml").write_text(jac_toml, encoding="utf-8");
    for (name, content) in files.items() {
        (path / name).write_text(content, encoding="utf-8");
    }
    env = dict(os.environ);
    subprocess.run(["git", "init", "-q", "-b", "main", str(path)], check=True, env=env);
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
            "init"
        ],
        check=True,
        env=env
    );
    return subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True
    ).stdout.strip();
}

def git_commit_all(path: Path, marker: str, message: str = "next") -> str {
    (path / "changes.log").write_text(marker + "\n", encoding="utf-8");
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
    return subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True
    ).stdout.strip();
}


def isolate_store -> tuple {
    tmp = tempfile.mkdtemp(prefix="jac_update_store_");
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


test "targeted update advances target-reachable transitives and freezes the rest" {
    (store_tmp, old_env) = isolate_store();
    cwd = os.getcwd();
    try {
        outer = Path(tempfile.mkdtemp(prefix="jac_update_closure_"));

        # T: branch-tracking transitive of R.
        origin_t = outer / "t_repo";
        t1 = make_git_repo_on_main(
            origin_t,
            '[project]\nname = "t"\nversion = "1.0.0"\n',
            {"t.jac": "def t() -> int { return 1; }\n"}
        );
        # R: the update target; requires T by branch.
        origin_r = outer / "r_repo";
        r1 = make_git_repo_on_main(
            origin_r,
            '[project]\nname = "r"\nversion = "1.0.0"\n\n'
            f'[dependencies.jac]\nt = {{ git = "{origin_t}", branch = "main" }}\n',
            {"r.jac": "def r() -> int { return 2; }\n"}
        );
        # U: unrelated root dep that must stay frozen.
        origin_u = outer / "u_repo";
        u1 = make_git_repo_on_main(
            origin_u,
            '[project]\nname = "u"\nversion = "1.0.0"\n',
            {"u.jac": "def u() -> int { return 3; }\n"}
        );

        project_dir = outer / "proj";
        project_dir.mkdir();
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nr = {{ git = "{origin_r}", branch = "main" }}\n'
            f'u = {{ git = "{origin_u}", branch = "main" }}\n',
            encoding="utf-8"
        );
        os.chdir(project_dir);
        set_config(None);
        import from jaclang.project.config { get_config }
        config = get_config();
        assert config is not None;

        # Seed the lock with everything at commit1.
        provider = JacGitProvider();
        assert provider.install_all(config, [], InstallContext());
        rows = jac_lock_rows(read_lock(project_dir));
        assert rows["t"]["sha"] == t1;
        assert rows["r"]["sha"] == r1;
        assert rows["u"]["sha"] == u1;
        assert rows["t"]["requested_by"] == ["r"];
        assert rows["r"]["requested_by"] == ["root"];
        assert rows["u"]["requested_by"] == ["root"];

        # Advance both the target (R) and its transitive (T) on main.
        t2 = git_commit_all(origin_t, "t2", "advance t");
        r2 = git_commit_all(origin_r, "r2", "advance r");

        result = project.update(packages=["r"]);
        assert result == 0 , f"targeted update failed: {result}";

        rows = jac_lock_rows(read_lock(project_dir));
        assert rows["r"]["sha"] == r2 , "target R did not advance";
        assert rows["t"]["sha"] == t2 , (
            "transitive T reachable from R did not advance with it"
        );
        assert rows["u"]["sha"] == u1 , "unrelated U was unpinned and churned";
        assert rows["t"]["requested_by"] == ["r"];
        assert rows["r"]["requested_by"] == ["root"];
        assert rows["u"]["requested_by"] == ["root"];
    } finally {
        os.chdir(cwd);
        set_config(None);
        restore_store(store_tmp, old_env);
        shutil.rmtree(outer, ignore_errors=True);
    }
}


test "targeted update advances transitives newly reachable from the fresh manifest" {
    (store_tmp, old_env) = isolate_store();
    cwd = os.getcwd();
    try {
        outer = Path(tempfile.mkdtemp(prefix="jac_update_fresh_"));

        # T: update target; its v1 manifest has no dependencies at all.
        origin_t = outer / "t_repo";
        t1 = make_git_repo_on_main(
            origin_t,
            '[project]\nname = "t"\nversion = "1.0.0"\n',
            {"t.jac": "def t() -> int { return 1; }\n"}
        );
        # D: plain dep, required only by U at seed time.
        origin_d = outer / "d_repo";
        d1 = make_git_repo_on_main(
            origin_d,
            '[project]\nname = "d"\nversion = "1.0.0"\n',
            {"d.jac": "def d() -> int { return 2; }\n"}
        );
        # U: unrelated root dep whose manifest requires D by branch.
        origin_u = outer / "u_repo";
        u1 = make_git_repo_on_main(
            origin_u,
            '[project]\nname = "u"\nversion = "1.0.0"\n\n'
            f'[dependencies.jac]\nd = {{ git = "{origin_d}", branch = "main" }}\n',
            {"u.jac": "def u() -> int { return 3; }\n"}
        );

        project_dir = outer / "proj";
        project_dir.mkdir();
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nt = {{ git = "{origin_t}", branch = "main" }}\n'
            f'u = {{ git = "{origin_u}", branch = "main" }}\n',
            encoding="utf-8"
        );
        os.chdir(project_dir);
        set_config(None);
        import from jaclang.project.config { get_config }
        config = get_config();
        assert config is not None;

        # Seed the lock: T is dep-free, D is reachable only through U.
        provider = JacGitProvider();
        assert provider.install_all(config, [], InstallContext());
        rows = jac_lock_rows(read_lock(project_dir));
        assert rows["t"]["sha"] == t1;
        assert rows["u"]["sha"] == u1;
        assert rows["d"]["sha"] == d1;
        assert rows["d"]["requested_by"] == ["u"];

        # Advance D on main, then publish a T manifest that requires D too.
        d2 = git_commit_all(origin_d, "d2", "advance d");
        (origin_t / "jac.toml").write_text(
            '[project]\nname = "t"\nversion = "1.0.0"\n\n'
            f'[dependencies.jac]\nd = {{ git = "{origin_d}", branch = "main" }}\n',
            encoding="utf-8"
        );
        t2 = git_commit_all(origin_t, "t2", "t requires d");

        result = project.update(packages=["t"]);
        assert result == 0 , f"targeted update failed: {result}";

        rows = jac_lock_rows(read_lock(project_dir));
        assert rows["t"]["sha"] == t2 , "target T did not advance";
        assert rows["d"]["sha"] == d2 , (
            "D newly reachable from T's fresh manifest replayed its stale pin"
        );
        assert rows["u"]["sha"] == u1 , "unrelated U was unpinned and churned";
    } finally {
        os.chdir(cwd);
        set_config(None);
        restore_store(store_tmp, old_env);
        shutil.rmtree(outer, ignore_errors=True);
    }
}
