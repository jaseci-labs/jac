"""Regression test for targeted `jac update <targets>` closure advancement.

A targeted update must advance every dependency reachable from the
targets (npm-update-like), not just the targets themselves: a
branch-tracking transitive of an updated root must move with it, while
unrelated packages stay pinned (minimal churn).
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { project }
import from jaclang.project.config { set_config }
import from tests.deps_fixtures {
    git_commit_all,
    git_head,
    isolate_store,
    make_git_repo,
    restore_store
}

import from jaclang.project.jac_provider { JacDepProvider }
import from jaclang.project.providers { InstallContext }
import from jaclang.project.lockfile { jac_lock_rows, read_lock }


test "targeted update advances target-reachable transitives and freezes the rest" {
    (store_tmp, old_env) = isolate_store();
    cwd = os.getcwd();
    try {
        outer = Path(tempfile.mkdtemp(prefix="jac_update_closure_"));

        # T: branch-tracking transitive of R.
        origin_t = outer / "t_repo";
        make_git_repo(
            origin_t,
            '[project]\nname = "t"\nversion = "1.0.0"\n',
            {"t.jac": "def t() -> int { return 1; }\n"},
            branch="main"
        );
        t1 = git_head(origin_t);
        # R: the update target; requires T by branch.
        origin_r = outer / "r_repo";
        make_git_repo(
            origin_r,
            '[project]\nname = "r"\nversion = "1.0.0"\n\n'
            f'[dependencies.jac]\nt = {{ git = "{origin_t}", branch = "main" }}\n',
            {"r.jac": "def r() -> int { return 2; }\n"},
            branch="main"
        );
        r1 = git_head(origin_r);
        # U: unrelated root dep that must stay frozen.
        origin_u = outer / "u_repo";
        make_git_repo(
            origin_u,
            '[project]\nname = "u"\nversion = "1.0.0"\n',
            {"u.jac": "def u() -> int { return 3; }\n"},
            branch="main"
        );
        u1 = git_head(origin_u);

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
        provider = JacDepProvider();
        assert provider.install_all(config, [], InstallContext());
        rows = jac_lock_rows(read_lock(project_dir));
        assert rows["t"]["sha"] == t1;
        assert rows["r"]["sha"] == r1;
        assert rows["u"]["sha"] == u1;
        assert rows["t"]["requested_by"] == ["r"];
        assert rows["r"]["requested_by"] == ["root"];
        assert rows["u"]["requested_by"] == ["root"];

        # Advance both the target (R) and its transitive (T) on main.
        (origin_t / "changes.log").write_text("t2\n", encoding="utf-8");
        t2 = git_commit_all(origin_t, "advance t");
        (origin_r / "changes.log").write_text("r2\n", encoding="utf-8");
        r2 = git_commit_all(origin_r, "advance r");

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
        make_git_repo(
            origin_t,
            '[project]\nname = "t"\nversion = "1.0.0"\n',
            {"t.jac": "def t() -> int { return 1; }\n"},
            branch="main"
        );
        t1 = git_head(origin_t);
        # D: plain dep, required only by U at seed time.
        origin_d = outer / "d_repo";
        make_git_repo(
            origin_d,
            '[project]\nname = "d"\nversion = "1.0.0"\n',
            {"d.jac": "def d() -> int { return 2; }\n"},
            branch="main"
        );
        d1 = git_head(origin_d);
        # U: unrelated root dep whose manifest requires D by branch.
        origin_u = outer / "u_repo";
        make_git_repo(
            origin_u,
            '[project]\nname = "u"\nversion = "1.0.0"\n\n'
            f'[dependencies.jac]\nd = {{ git = "{origin_d}", branch = "main" }}\n',
            {"u.jac": "def u() -> int { return 3; }\n"},
            branch="main"
        );
        u1 = git_head(origin_u);

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
        provider = JacDepProvider();
        assert provider.install_all(config, [], InstallContext());
        rows = jac_lock_rows(read_lock(project_dir));
        assert rows["t"]["sha"] == t1;
        assert rows["u"]["sha"] == u1;
        assert rows["d"]["sha"] == d1;
        assert rows["d"]["requested_by"] == ["u"];
        (origin_d / "changes.log").write_text("d2\n", encoding="utf-8");
        d2 = git_commit_all(origin_d, "advance d");
        # Advance D on main, then publish a T manifest that requires D too.
        (origin_t / "jac.toml").write_text(
            '[project]\nname = "t"\nversion = "1.0.0"\n\n'
            f'[dependencies.jac]\nd = {{ git = "{origin_d}", branch = "main" }}\n',
            encoding="utf-8"
        );
        (origin_t / "changes.log").write_text("t2\n", encoding="utf-8");
        t2 = git_commit_all(origin_t, "t requires d");

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


test "failed convergence leaves materialized state and metadata untouched" {
    (store_tmp, old_env) = isolate_store();
    cwd = os.getcwd();
    try {
        outer = Path(tempfile.mkdtemp(prefix="jac_update_atomic_"));
        origin_t = outer / "t_repo";
        make_git_repo(
            origin_t,
            '[project]\nname = "t"\nversion = "1.0.0"\n',
            {"t.jac": "def t() -> int { return 1; }\n"},
            branch="main"
        );
        t1 = git_head(origin_t);
        origin_u = outer / "u_repo";
        make_git_repo(
            origin_u,
            '[project]\nname = "u"\nversion = "1.0.0"\n',
            {"u.jac": "def u() -> int { return 3; }\n"},
            branch="main"
        );
        u1 = git_head(origin_u);

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

        provider = JacDepProvider();
        assert provider.install_all(config, [], InstallContext());
        build = config.get_build_dir();
        rows_before = jac_lock_rows(read_lock(project_dir));
        deps_before = (build / "deps.json").read_bytes();
        assert not (build / "packages" / "t" / "changes.log").exists() , (
            "unexpected changes.log in the seeded tree"
        );

        # Advance t and publish a manifest whose newly required dep cannot
        # be fetched at all: convergence must abort after pass one's
        # resolution discovered it.
        not_a_repo = outer / "not_a_repo";
        not_a_repo.mkdir();
        (origin_t / "jac.toml").write_text(
            '[project]\nname = "t"\nversion = "1.0.0"\n\n'
            f'[dependencies.jac]\nx = {{ git = "{not_a_repo}", branch = "main" }}\n',
            encoding="utf-8"
        );
        (origin_t / "changes.log").write_text("t2\n", encoding="utf-8");
        t2 = git_commit_all(origin_t, "t requires x");

        result = project.update(packages=["t"]);
        assert result != 0 , "update with an unfetchable dep unexpectedly succeeded";

        rows_after = jac_lock_rows(read_lock(project_dir));
        assert rows_after == rows_before , "jac.lock changed on failed convergence";
        assert (build / "deps.json").read_bytes() == deps_before , (
            "deps map changed on failed convergence"
        );
        # t2's tree adds changes.log and the x dep to the manifest; if the
        # t@t2 resolution had been materialized before the failure, both
        # would now be visible under .jac/packages/t.
        assert not (build / "packages" / "t" / "changes.log").exists() , (
            "materialized t was replaced even though convergence failed"
        );
        assert "not_a_repo"
            not in (build / "packages" / "t" / "jac.toml").read_text() , (
            "materialized t carries the failed candidate manifest"
        );
        assert rows_after["t"]["sha"] == t1 and rows_after["u"]["sha"] == u1;
        assert not (build / "packages" / "x").exists() , (
            "unfetchable dep left materialized state behind"
        );
    } finally {
        os.chdir(cwd);
        set_config(None);
        restore_store(store_tmp, old_env);
        shutil.rmtree(outer, ignore_errors=True);
    }
}


test "update -d advances the dev closure and freezes main deps" {
    (store_tmp, old_env) = isolate_store();
    cwd = os.getcwd();
    try {
        outer = Path(tempfile.mkdtemp(prefix="jac_update_dev_"));

        origin_u = outer / "u_repo";
        make_git_repo(
            origin_u,
            '[project]\nname = "u"\nversion = "1.0.0"\n',
            {"u.jac": "def u() -> int { return 1; }\n"},
            branch="main"
        );
        u1 = git_head(origin_u);
        origin_d = outer / "d_repo";
        make_git_repo(
            origin_d,
            '[project]\nname = "d"\nversion = "1.0.0"\n',
            {"d.jac": "def d() -> int { return 2; }\n"},
            branch="main"
        );
        d1 = git_head(origin_d);

        project_dir = outer / "proj";
        project_dir.mkdir();
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nu = {{ git = "{origin_u}", branch = "main" }}\n\n'
            f'[dev-dependencies.jac]\nd = {{ git = "{origin_d}", branch = "main" }}\n',
            encoding="utf-8"
        );
        os.chdir(project_dir);
        set_config(None);
        import from jaclang.project.config { get_config }
        config = get_config();
        assert config is not None;

        provider = JacDepProvider();
        assert provider.install_all(config, [], InstallContext());
        rows = jac_lock_rows(read_lock(project_dir));
        assert rows["u"]["sha"] == u1;
        assert rows["d"]["sha"] == d1;

        (origin_u / "changes.log").write_text("u2\n", encoding="utf-8");
        u2 = git_commit_all(origin_u, "advance u");
        (origin_d / "changes.log").write_text("d2\n", encoding="utf-8");
        d2 = git_commit_all(origin_d, "advance d");

        result = project.update(packages=[]);
        assert result == 0 , f"plain update failed: {result}";
        rows = jac_lock_rows(read_lock(project_dir));
        assert rows["u"]["sha"] == u2 , "plain update did not advance main dep";
        assert rows["d"]["sha"] == d1 , "plain update advanced a dev dep";

        (origin_u / "changes.log").write_text("u3\n", encoding="utf-8");
        u3 = git_commit_all(origin_u, "advance u again");
        (origin_d / "changes.log").write_text("d3\n", encoding="utf-8");
        d3 = git_commit_all(origin_d, "advance d again");

        result = project.update(packages=[], dev=True);
        assert result == 0 , f"dev update failed: {result}";
        rows = jac_lock_rows(read_lock(project_dir));
        assert rows["d"]["sha"] == d3 , "update -d did not advance the dev dep";
        assert rows["u"]["sha"] == u2 , "update -d churned the main dep";
    } finally {
        os.chdir(cwd);
        set_config(None);
        restore_store(store_tmp, old_env);
        shutil.rmtree(outer, ignore_errors=True);
    }
}
