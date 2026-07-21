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
import from unittest.mock { patch, MagicMock }

import from jaclang.cli.commands { execution as exec_cmds }
import from jaclang.cli.commands { project as proj_cmds }


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
        # The caller's argv and sys.path were both restored (no tier leak).
        assert sys.argv == saved_argv;
        assert sys.path == saved_path;
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

        tiers = [("project", "py", proj_site), ("global", "py", glob_site)];
        with patch("jaclang.cli.commands.execution._tool_tiers", return_value=tiers) {
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

        tiers = [("project", "py", proj_site), ("global", "py", glob_site)];
        with patch("jaclang.cli.commands.execution._tool_tiers", return_value=tiers) {
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
        tiers = [("global", "py", glob_site)];
        with patch("jaclang.cli.commands.execution._tool_tiers", return_value=tiers) {
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
        tiers = [("global", "py", glob_site)];
        with patch("jaclang.cli.commands.execution._tool_tiers", return_value=tiers) {
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


# ===== npm tier: discovery, tier ordering, routing, and bun exec =====
"""Create a node_modules/.bin shim named `tool` in `bin_dir`."""
def make_fake_node_bin(bin_dir: Path, tool: str) -> Path {
    bin_dir.mkdir(parents=True, exist_ok=True);
    shim = bin_dir / tool;
    shim.write_text("#!/usr/bin/env node\nconsole.log('hi');\n");
    return shim;
}

test "_node_tools_in lists bins and returns empty for a missing dir" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    try {
        bin_dir = Path(tmp) / "bin";
        make_fake_node_bin(bin_dir, "eslint");
        make_fake_node_bin(bin_dir, "vite");
        names = exec_cmds._node_tools_in(bin_dir);
        assert "eslint" in names;
        assert "vite" in names;
        assert exec_cmds._node_tools_in(Path(tmp) / "nope") == [];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "_find_node_tool resolves a present shim and None otherwise" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    try {
        bin_dir = Path(tmp) / "bin";
        make_fake_node_bin(bin_dir, "vite");
        found = exec_cmds._find_node_tool(bin_dir, "vite");
        assert found is not None;
        assert found.name == "vite";
        assert exec_cmds._find_node_tool(bin_dir, "absent") is None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "_tool_tiers orders project python, project npm, global python, then global npm" {
    reset_config();
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    old_cwd = os.getcwd();
    old_env = os.environ.get("JAC_GLOBAL_DIR");
    try {
        project_dir = Path(tmp) / "proj";
        project_dir.mkdir();
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "xproj"\nversion = "0.1.0"\n'
        );
        os.chdir(project_dir);
        os.environ["JAC_GLOBAL_DIR"] = str(Path(tmp) / "gdir");
        reset_config();

        # Tiers are (scope, kind, loc): scope in {project, global}, kind in {py, node}.
        kinds = [
            (scope, kind) for (scope, kind, loc) in exec_cmds._tool_tiers(False, False)
        ];
        assert ("project", "py") in kinds;
        assert ("project", "node") in kinds;
        assert ("global", "py") in kinds;
        assert ("global", "node") in kinds;
        # Locality-first: project venv, project npm, then the two global tiers.
        assert kinds.index(("project", "py")) < kinds.index(("project", "node"));
        assert kinds.index(("project", "node")) < kinds.index(("global", "py"));
        assert kinds.index(("global", "py")) < kinds.index(("global", "node"));
    } finally {
        os.chdir(old_cwd);
        if old_env is None {
            os.environ.pop("JAC_GLOBAL_DIR", None);
        } else {
            os.environ["JAC_GLOBAL_DIR"] = old_env;
        }
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "_tool_tiers with use_node yields only the npm tier" {
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

        tiers = exec_cmds._tool_tiers(False, True);
        kinds = {kind for (label, kind, loc) in tiers};
        assert kinds == {"node"};
    } finally {
        os.chdir(old_cwd);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "_tool_tiers with use_global keeps only global tiers, including a global npm tier" {
    reset_config();
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    old_cwd = os.getcwd();
    old_env = os.environ.get("JAC_GLOBAL_DIR");
    try {
        project_dir = Path(tmp) / "proj";
        project_dir.mkdir();
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "xproj"\nversion = "0.1.0"\n'
        );
        os.chdir(project_dir);
        os.environ["JAC_GLOBAL_DIR"] = str(Path(tmp) / "gdir");
        reset_config();

        tiers = exec_cmds._tool_tiers(True, False);
        scopes = {scope for (scope, kind, loc) in tiers};
        kinds = {(scope, kind) for (scope, kind, loc) in tiers};
        # The global filter drops every project tier ...
        assert scopes == {"global"};
        # ... but a global npm tier now sits alongside the global python site,
        # so `jac x --global` can run node tools too.
        assert ("global", "py") in kinds;
        assert ("global", "node") in kinds;
    } finally {
        os.chdir(old_cwd);
        if old_env is None {
            os.environ.pop("JAC_GLOBAL_DIR", None);
        } else {
            os.environ["JAC_GLOBAL_DIR"] = old_env;
        }
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "x routes an npm-tier match to the node runner" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    try {
        bin_dir = Path(tmp) / "bin";
        make_fake_node_bin(bin_dir, "demo");
        tiers = [("node", "node", bin_dir)];
        with patch("jaclang.cli.commands.execution._tool_tiers", return_value=tiers), patch(
            "jaclang.cli.commands.execution._run_node_tool", return_value=42
        ) as mock_node {
            rc = exec_cmds.x(name="demo", args=["build"]);
        }
        assert rc == 42;
        assert mock_node.called;
        # Called as _run_node_tool(name, shim_path, args).
        assert mock_node.call_args[0][0] == "demo";
        assert mock_node.call_args[0][1].name == "demo";
        assert mock_node.call_args[0][2] == ["build"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "_run_node_tool invokes bun with the shim and forwards args" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    try {
        bin_dir = Path(tmp) / "bin";
        shim = make_fake_node_bin(bin_dir, "demo");
        with patch(
            "jaclang.runtimelib.client.bun_installer.get_bun", return_value="/fake/bun"
        ), patch("subprocess.run") as mock_run {
            mock_run.return_value = MagicMock(returncode=3);
            rc = exec_cmds._run_node_tool("demo", shim, ["a", "b"]);
        }
        assert rc == 3;
        assert mock_run.call_args[0][0] == ["/fake/bun", str(shim), "a", "b"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "_run_node_tool errors cleanly when bun is unavailable" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    try {
        shim = make_fake_node_bin(Path(tmp) / "bin", "demo");
        with patch(
            "jaclang.runtimelib.client.bun_installer.get_bun", return_value=None
        ) {
            assert exec_cmds._run_node_tool("demo", shim, []) == 1;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "x --list includes npm tools" {
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    try {
        bin_dir = Path(tmp) / "bin";
        make_fake_node_bin(bin_dir, "vite");
        tiers = [("node", "node", bin_dir)];
        with patch("jaclang.cli.commands.execution._tool_tiers", return_value=tiers) {
            assert exec_cmds.x(list_tools=True) == 0;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===== global npm tools: resolve (jac x --global) + install (jac install --npm --global) =====
"""The jac-owned global npm bin dir for a given JAC_GLOBAL_DIR prefix."""
def global_npm_bin(prefix: Path) -> Path {
    return prefix / "npm" / "node_modules" / ".bin";
}

test "x --global resolves a global npm tool through the node runner" {
    reset_config();
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    old_env = os.environ.get("JAC_GLOBAL_DIR");
    try {
        gdir = Path(tmp) / "gdir";
        os.environ["JAC_GLOBAL_DIR"] = str(gdir);
        make_fake_node_bin(global_npm_bin(gdir), "demo");
        reset_config();

        with patch(
            "jaclang.cli.commands.execution._run_node_tool", return_value=77
        ) as mock_node {
            rc = exec_cmds.x(name="demo", use_global=True, args=["v"]);
        }
        assert rc == 77;
        assert mock_node.called;
        # Routed as _run_node_tool(name, shim_path, args) from the global bin dir.
        assert mock_node.call_args[0][0] == "demo";
        assert mock_node.call_args[0][1].name == "demo";
        assert mock_node.call_args[0][2] == ["v"];
    } finally {
        if old_env is None {
            os.environ.pop("JAC_GLOBAL_DIR", None);
        } else {
            os.environ["JAC_GLOBAL_DIR"] = old_env;
        }
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "run_npm_add --global installs into the jac global npm dir via bun add" {
    import from jaclang.runtimelib.client { cli as npm_cli }
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    old_env = os.environ.get("JAC_GLOBAL_DIR");
    try {
        gdir = Path(tmp) / "gdir";
        os.environ["JAC_GLOBAL_DIR"] = str(gdir);
        with patch(
            "jaclang.runtimelib.client.bun_installer.get_bun", return_value="/fake/bun"
        ), patch("subprocess.run") as mock_run {
            mock_run.return_value = MagicMock(returncode=0);
            rc = npm_cli.run_npm_add(["eslint@9"], False, True);
        }
        assert rc == 0;
        # `bun add <specs>` ran in the jac-owned global npm root (no project needed).
        argv = mock_run.call_args[0][0];
        assert argv[0] == "/fake/bun";
        assert argv[1] == "add";
        assert "eslint@9" in argv;
        npm_root = gdir / "npm";
        assert mock_run.call_args[1]["cwd"] == str(npm_root);
        assert (npm_root / "package.json").exists();
    } finally {
        if old_env is None {
            os.environ.pop("JAC_GLOBAL_DIR", None);
        } else {
            os.environ["JAC_GLOBAL_DIR"] = old_env;
        }
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "run_npm_add --global --dev forwards --dev to bun add" {
    import from jaclang.runtimelib.client { cli as npm_cli }
    tmp = tempfile.mkdtemp(prefix="jac_x_test_");
    old_env = os.environ.get("JAC_GLOBAL_DIR");
    try {
        os.environ["JAC_GLOBAL_DIR"] = str(Path(tmp) / "gdir");
        with patch(
            "jaclang.runtimelib.client.bun_installer.get_bun", return_value="/fake/bun"
        ), patch("subprocess.run") as mock_run {
            mock_run.return_value = MagicMock(returncode=0);
            rc = npm_cli.run_npm_add(["typescript"], True, True);
        }
        assert rc == 0;
        assert "--dev" in mock_run.call_args[0][0];
    } finally {
        if old_env is None {
            os.environ.pop("JAC_GLOBAL_DIR", None);
        } else {
            os.environ["JAC_GLOBAL_DIR"] = old_env;
        }
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "install --npm --global routes to the global npm installer" {
    with patch(
        "jaclang.runtimelib.client.cli.run_npm_add", return_value=0
    ) as mock_add {
        rc = proj_cmds.install(packages=["eslint"], npm=True, install_global=True);
    }
    assert rc == 0;
    assert mock_add.called;
    # install_global is forwarded so the npm channel honors --global.
    forwarded = (
        (len(mock_add.call_args[0]) >= 3 and mock_add.call_args[0][2] == True)
        or mock_add.call_args[1].get("install_global") == True
    );
    assert forwarded;
}
