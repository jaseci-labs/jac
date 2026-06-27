"""Tests for the `jac x` command (run an installed console-script under the runtime).

These exercise the resolver helpers and the `x` handler directly, without going
through CLI startup, so they do not depend on a real venv or network installs.
Fake packages with `console_scripts` entry points are fabricated on disk and
discovered via importlib.metadata exactly as a real install would be.
"""

import os;
import sys;
import tempfile;
import shutil;
import from pathlib { Path }
import from unittest.mock { patch }

import from jaclang.cli.commands { execution as exec_cmds }


"""Reset global config singleton (mirrors test_dependencies)."""
def reset_config {
    import from jaclang.project { config as config_mod }
    config_mod._config = None;
}

"""Fabricate an installed package exposing one console-script in `site_dir`.

Writes `<pkg>/__init__.py` (whose `main` is `body`) plus a `.dist-info` with
METADATA and entry_points.txt, so importlib.metadata finds the entry point and
`ep.load()` can import it once `site_dir` is on sys.path.
"""
def make_fake_tool(site_dir: Path, script: str, pkg: str, body: str) {
    pkg_dir = site_dir / pkg;
    pkg_dir.mkdir(parents=True, exist_ok=True);
    (pkg_dir / "__init__.py").write_text(body);
    dist = site_dir / (pkg + "-1.0.dist-info");
    dist.mkdir(parents=True, exist_ok=True);
    (dist / "METADATA").write_text(
        "Metadata-Version: 2.1\nName: " + pkg + "\nVersion: 1.0\n"
    );
    (dist / "entry_points.txt").write_text(
        "[console_scripts]\n" + script + " = " + pkg + ":main\n"
    );
}

"""A `main` body that exits with `code`."""
def exit_body(code: int) -> str {
    return "import sys\ndef main():\n    sys.exit(" + str(code) + ")\n";
}

"""Find the entry point named `script` in `site_dir` (or None)."""
def find_ep(site_dir: Path, script: str) -> object {
    for (n, d, ep) in exec_cmds._console_scripts_in(site_dir) {
        if n == script {
            return ep;
        }
    }
    return None;
}

"""Drop a fabricated package from sys.path / sys.modules so tests don't leak."""
def cleanup_site(site_dir: Path, pkgs: list) {
    site_str = str(site_dir);
    if site_str in sys.path {
        sys.path.remove(site_str);
    }
    for pkg in pkgs {
        sys.modules.pop(pkg, None);
    }
}


# ===== _console_scripts_in =====
test "_console_scripts_in discovers console-script entry points" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    try {
        site = Path(tmp) / "site";
        make_fake_tool(site, "demo", "demo_disco_pkg", exit_body(0));
        found = exec_cmds._console_scripts_in(site);
        names = [n for (n, d, ep) in found];
        assert "demo" in names;
        for (n, d, ep) in found {
            if n == "demo" {
                assert d == "demo_disco_pkg";
                assert ep.group == "console_scripts";
            }
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "_console_scripts_in returns empty for a missing dir" {
    missing = Path(tempfile.gettempdir()) / "jac_x_definitely_missing_dir_xyz";
    assert exec_cmds._console_scripts_in(missing) == [];
}


# ===== _run_entry_point =====
test "_run_entry_point runs the tool, forwards argv, returns its exit code" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    saved_path = list(sys.path);
    saved_argv = list(sys.argv);
    try {
        site = Path(tmp) / "site";
        argv_file = str(Path(tmp) / "argv.txt");
        body = "import sys\ndef main():\n    open(" + repr(argv_file) + ", 'w').write(repr(sys.argv))\n    sys.exit(7)\n";
        make_fake_tool(site, "demo", "demo_run_pkg", body);

        ep = find_ep(site, "demo");
        assert ep is not None;
        rc = exec_cmds._run_entry_point("demo", ep, site, ["alpha", "beta"]);

        assert rc == 7;
        # The tool saw itself as argv[0] with the forwarded args after it.
        recorded = Path(argv_file).read_text();
        assert recorded == repr(["demo", "alpha", "beta"]);
        # The caller's argv was restored.
        assert sys.argv == saved_argv;
    } finally {
        cleanup_site(Path(tmp) / "site", ["demo_run_pkg"]);
        sys.path.clear();
        sys.path.extend(saved_path);
        sys.argv.clear();
        sys.argv.extend(saved_argv);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "_run_entry_point treats a clean (None) exit as success" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    saved_path = list(sys.path);
    saved_argv = list(sys.argv);
    try {
        site = Path(tmp) / "site";
        # main returns normally -> no SystemExit -> rc 0.
        make_fake_tool(site, "demo", "demo_none_pkg", "def main():\n    return None\n");
        ep = find_ep(site, "demo");
        rc = exec_cmds._run_entry_point("demo", ep, site, []);
        assert rc == 0;
    } finally {
        cleanup_site(Path(tmp) / "site", ["demo_none_pkg"]);
        sys.path.clear();
        sys.path.extend(saved_path);
        sys.argv.clear();
        sys.argv.extend(saved_argv);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===== x() precedence (project venv before global site) =====
test "x runs the project-tier tool when it shadows a global one" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    saved_path = list(sys.path);
    saved_argv = list(sys.argv);
    try {
        proj_site = Path(tmp) / "proj";
        glob_site = Path(tmp) / "glob";
        make_fake_tool(proj_site, "demo", "demo_proj_pkg", exit_body(11));
        make_fake_tool(glob_site, "demo", "demo_glob_pkg", exit_body(22));

        sites = [("project", proj_site), ("global", glob_site)];
        with patch(
            "jaclang.cli.commands.execution._tool_site_dirs", return_value=sites
        ) {
            rc = exec_cmds.x(name="demo");
        }
        # Project tier wins -> its exit code (11), not the global one (22).
        assert rc == 11;
    } finally {
        cleanup_site(Path(tmp) / "proj", ["demo_proj_pkg"]);
        cleanup_site(Path(tmp) / "glob", ["demo_glob_pkg"]);
        sys.path.clear();
        sys.path.extend(saved_path);
        sys.argv.clear();
        sys.argv.extend(saved_argv);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "x falls back to the global tier when the project lacks the tool" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    saved_path = list(sys.path);
    saved_argv = list(sys.argv);
    try {
        proj_site = Path(tmp) / "proj";
        glob_site = Path(tmp) / "glob";
        # Project has some other tool; global has 'demo'.
        make_fake_tool(proj_site, "other", "demo_other_pkg", exit_body(5));
        make_fake_tool(glob_site, "demo", "demo_fallback_pkg", exit_body(22));

        sites = [("project", proj_site), ("global", glob_site)];
        with patch(
            "jaclang.cli.commands.execution._tool_site_dirs", return_value=sites
        ) {
            rc = exec_cmds.x(name="demo");
        }
        assert rc == 22;
    } finally {
        cleanup_site(Path(tmp) / "proj", ["demo_other_pkg"]);
        cleanup_site(Path(tmp) / "glob", ["demo_fallback_pkg"]);
        sys.path.clear();
        sys.path.extend(saved_path);
        sys.argv.clear();
        sys.argv.extend(saved_argv);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "x returns 1 when no tier provides the tool" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    try {
        glob_site = Path(tmp) / "glob";
        make_fake_tool(glob_site, "demo", "demo_missing_pkg", exit_body(0));
        sites = [("global", glob_site)];
        with patch(
            "jaclang.cli.commands.execution._tool_site_dirs", return_value=sites
        ) {
            rc = exec_cmds.x(name="not-installed");
        }
        assert rc == 1;
    } finally {
        cleanup_site(Path(tmp) / "glob", ["demo_missing_pkg"]);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "x with no name (or --list) lists tools and returns 0" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    try {
        glob_site = Path(tmp) / "glob";
        make_fake_tool(glob_site, "demo", "demo_list_pkg", exit_body(0));
        sites = [("global", glob_site)];
        with patch(
            "jaclang.cli.commands.execution._tool_site_dirs", return_value=sites
        ) {
            assert exec_cmds.x(list_tools=True) == 0;
            assert exec_cmds.x(name="") == 0;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===== _tool_site_dirs ordering (the precedence the live demo couldn't show) =====
test "_tool_site_dirs lists the project venv before the global site" {
    reset_config();
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    old_cwd = os.getcwd();
    try {
        project_dir = Path(tmp) / "proj";
        project_dir.mkdir();
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "xproj"\nversion = "0.1.0"\n'
        );
        os.chdir(project_dir);
        reset_config();

        sites = exec_cmds._tool_site_dirs(False);
        labels = [label for (label, d) in sites];
        assert labels[0] == "project";
        assert "global" in labels;
        # The project tier points inside this project's .jac/venv.
        proj_path = str(sites[0][1]);
        assert ".jac" in proj_path;
        assert "venv" in proj_path;
        assert str(project_dir) in proj_path;
    } finally {
        os.chdir(old_cwd);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "_tool_site_dirs with use_global skips the project tier" {
    reset_config();
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    old_cwd = os.getcwd();
    try {
        project_dir = Path(tmp) / "proj";
        project_dir.mkdir();
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "xproj"\nversion = "0.1.0"\n'
        );
        os.chdir(project_dir);
        reset_config();

        sites = exec_cmds._tool_site_dirs(True);
        labels = [label for (label, d) in sites];
        assert "project" not in labels;
    } finally {
        os.chdir(old_cwd);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}
