"""Tests for jaclang.project.dependencies module."""

import os;
import sys;
import tempfile;
import shutil;
import from pathlib { Path }
import from unittest.mock { MagicMock, patch }

import from jaclang.project.config { JacConfig }
import from jaclang.project.dependencies {
    DependencyInstaller,
    DependencyResolver,
    ResolvedDependency,
    add_venv_to_path,
    get_venv_site_packages,
    is_venv_in_path,
    remove_venv_from_path
}

def reset_config {
    """Reset global config singleton."""
    import from jaclang.project { config as config_mod }
    config_mod._config = None;
}

def make_temp_project -> tuple {
    """Create a temporary project directory with jac.toml. Returns (temp_dir, project_dir)."""
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    project_dir = Path(tmp) / "test_project";
    project_dir.mkdir();

    jac_toml = project_dir / "jac.toml";
    jac_toml.write_text(
        '[project]\nname = "test-project"\nversion = "0.1.0"\ndescription = "A test project"\nentry-point = "main.jac"\n\n[dependencies]\nrequests = ">=2.28.0"\n\n[dev-dependencies]\npytest = ">=8.0.0"\n\n[run]\nmain = true\ncache = true\n\n[scripts]\ntest = "jac test"\n'
    );

    src_dir = project_dir / "src";
    src_dir.mkdir();
    main_jac = src_dir / "main.jac";
    main_jac.write_text(
        '"""Test main file."""\n\nwith entry {\n    print("Hello, World!");\n}\n'
    );

    return (tmp, project_dir);
}

def create_test_project(tmpdir: str, toml_content: str = "") -> str {
    """Create a minimal jac project for testing."""
    project_path = os.path.join(tmpdir, "testproj");
    os.makedirs(project_path, exist_ok=True);
    if not toml_content {
        toml_content = '[project]\nname = "testproj"\nversion = "0.1.0"\n\n[dependencies]\nrequests = ">=2.28.0"\nflask = "~=3.0"\n\n[dev-dependencies]\npytest = ">=8.0.0"\n';
    }
    f = open(os.path.join(project_path, "jac.toml"), "w");
    f.write(toml_content);
    f.close();
    return project_path;
}

# ===== TestDependencyInstaller =====
test "DependencyInstaller init with config" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);
        assert installer.config == config;
        assert installer.venv_dir == project_dir / ".jac" / "venv";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller init without config fails" {
    reset_config();
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    old_cwd = os.getcwd();
    os.chdir(tmp);
    try {
        raised = False;
        try {
            DependencyInstaller();
        } except ValueError as e {
            raised = True;
            assert "No jac.toml found" in str(e);
        }
        assert raised , "Expected ValueError";
    } finally {
        os.chdir(old_cwd);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller ensure_venv creates" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);
        venv_dir = project_dir / ".jac" / "venv";
        assert not venv_dir.exists();

        with patch("venv.EnvBuilder") as mock_builder_class {
            mock_builder = MagicMock();
            mock_builder_class.return_value = mock_builder;
            installer.ensure_venv();
            mock_builder_class.assert_called_once();
            mock_builder.create.assert_called_once_with(str(venv_dir));
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller ensure_venv skips existing valid" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        venv_dir = project_dir / ".jac" / "venv";
        venv_dir.mkdir(parents=True, exist_ok=True);
        (venv_dir / "pyvenv.cfg").write_text("home = /usr/bin");
        bin_dir = venv_dir / "bin";
        bin_dir.mkdir(exist_ok=True);
        (bin_dir / "python").write_text("#!/usr/bin/env python");

        with patch("venv.EnvBuilder") as mock_builder_class {
            installer.ensure_venv();
            mock_builder_class.return_value.create.assert_not_called();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller ensure_venv recreates corrupted" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config, verbose=True);

        venv_dir = project_dir / ".jac" / "venv";
        venv_dir.mkdir(parents=True, exist_ok=True);
        (venv_dir / "pyvenv.cfg").write_text("home = /usr/bin");

        with patch("venv.EnvBuilder") as mock_builder_class {
            mock_builder = MagicMock();
            mock_builder_class.return_value = mock_builder;
            installer.ensure_venv();
            mock_builder.create.assert_called_once_with(str(venv_dir));
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller ensure_venv ensurepip missing" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        with patch("venv.EnvBuilder") as mock_builder_class {
            mock_builder = MagicMock();
            mock_builder.create.side_effect = Exception("No module named 'ensurepip'");
            mock_builder_class.return_value = mock_builder;
            raised = False;
            try {
                installer.ensure_venv();
            } except RuntimeError as e {
                raised = True;
                assert "sudo apt install python3-venv" in str(e);
            }
            assert raised , "Expected RuntimeError";
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller install_package success" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config, verbose=False);

        with patch.object(installer, "ensure_venv") as _ev, patch.object(
            installer, "_run_pip"
        ) as mock_pip {
            mock_pip.return_value = (0, "Successfully installed", "");
            result = installer.install_package(["requests>=2.28.0"]);
            assert result is True;
            mock_pip.assert_called_once();
            call_args = mock_pip.call_args[0][0];
            assert "install" in call_args;
            assert "--upgrade" in call_args;
            assert "requests>=2.28.0" in call_args;
            assert "--target" not in call_args;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller install_package failure" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        with patch.object(installer, "ensure_venv") as _ev, patch.object(
            installer, "_run_pip"
        ) as mock_pip {
            mock_pip.return_value = (1, "", "Package not found");
            result = installer.install_package(["nonexistent-package"]);
            assert result is False;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller install_package without version" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        with patch.object(installer, "ensure_venv") as _ev, patch.object(
            installer, "_run_pip"
        ) as mock_pip {
            mock_pip.return_value = (0, "", "");
            installer.install_package(["requests"]);
            call_args = mock_pip.call_args[0][0];
            assert "requests" in call_args;
            has_version = False;
            for arg in call_args {
                if "requests==" in str(arg) {
                    has_version = True;
                }
            }
            assert not has_version;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller install_git_package" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        with patch.object(installer, "ensure_venv") as _ev, patch.object(
            installer, "_run_pip"
        ) as mock_pip {
            mock_pip.return_value = (0, "", "");
            specs = installer._make_git_spec(
                "my-plugin", "https://github.com/user/plugin.git", branch="main"
            );
            result = installer.install_package([specs]);
            assert result is True;
            call_args = mock_pip.call_args[0][0];
            assert "git+https://github.com/user/plugin.git@main" in call_args;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller install_all" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        with patch.object(installer, "ensure_venv") as _ev, patch.object(
            installer, "_run_pip"
        ) as mock_pip {
            mock_pip.return_value = (0, "", "");
            pip_packages = installer.get_pip_package_specs(include_dev=False);
            git_packages = installer.get_git_package_specs();
            result = installer.install_package(pip_packages + git_packages);
            assert result is True;
            assert mock_pip.call_count == 1;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller install_all with dev" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        with patch.object(installer, "ensure_venv") as _ev, patch.object(
            installer, "_run_pip"
        ) as mock_pip {
            mock_pip.return_value = (0, "", "");
            pip_packages = installer.get_pip_package_specs(include_dev=True);
            git_packages = installer.get_git_package_specs();
            result = installer.install_package(pip_packages + git_packages);
            assert result is True;
            assert mock_pip.call_count == 1;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller is_installed" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        venv_dir = project_dir / ".jac" / "venv";
        venv_dir.mkdir(parents=True, exist_ok=True);

        with patch.object(installer, "_run_pip") as mock_pip {
            mock_pip.return_value = (0, "Name: requests\nVersion: 2.28.0", "");
            assert installer.is_installed("requests") is True;
            mock_pip.assert_called_with(["show", "requests"]);
            mock_pip.return_value = (
                1,
                "",
                "WARNING: Package(s) not found: nonexistent"
            );
            assert installer.is_installed("nonexistent") is False;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller get_installed_version not found" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        venv_dir = project_dir / ".jac" / "venv";
        venv_dir.mkdir(parents=True, exist_ok=True);

        with patch.object(installer, "_run_pip") as mock_pip {
            mock_pip.return_value = (
                1,
                "",
                "WARNING: Package(s) not found: nonexistent"
            );
            version = installer.get_installed_version("nonexistent");
            assert version is None;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller get_installed_version no venv" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);
        version = installer.get_installed_version("requests");
        assert version is None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller list_installed" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        venv_dir = project_dir / ".jac" / "venv";
        venv_dir.mkdir(parents=True, exist_ok=True);

        with patch.object(installer, "_run_pip") as mock_pip {
            mock_pip.return_value = (
                0,
                '[{"name":"requests","version":"2.28.0"},{"name":"numpy","version":"1.24.0"},{"name":"pip","version":"23.0"},{"name":"setuptools","version":"67.0"}]',
                ""
            );
            installed = installer.list_installed();
            assert "requests" in installed;
            assert "numpy" in installed;
            assert "pip" not in installed;
            assert "setuptools" not in installed;
            mock_pip.assert_called_with(["list", "--format=json"]);
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller get_installed_version" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        venv_dir = project_dir / ".jac" / "venv";
        venv_dir.mkdir(parents=True, exist_ok=True);

        with patch.object(installer, "_run_pip") as mock_pip {
            mock_pip.return_value = (
                0,
                "Name: numpy\nVersion: 2.4.1\nSummary: Fundamental package\n",
                ""
            );
            version = installer.get_installed_version("numpy");
            assert version == "2.4.1";
            mock_pip.assert_called_with(["show", "numpy"]);
            mock_pip.return_value = (
                1,
                "",
                "WARNING: Package(s) not found: nonexistent"
            );
            version = installer.get_installed_version("nonexistent");
            assert version is None;
            mock_pip.return_value = (
                0,
                "Name: strange-pkg\nSummary: Missing version field\n",
                ""
            );
            version = installer.get_installed_version("strange-pkg");
            assert version is None;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller uninstall_package" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config, verbose=True);

        venv_dir = project_dir / ".jac" / "venv";
        venv_dir.mkdir(parents=True, exist_ok=True);

        with patch.object(installer, "_run_pip") as mock_pip {
            mock_pip.return_value = (0, "Successfully uninstalled testpkg-1.0.0", "");
            result = installer.uninstall_package("testpkg");
            assert result is True;
            mock_pip.assert_called_once_with(["uninstall", "-y", "testpkg"]);
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller uninstall_package not installed" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);

        venv_dir = project_dir / ".jac" / "venv";
        venv_dir.mkdir(parents=True, exist_ok=True);

        with patch.object(installer, "_run_pip") as mock_pip {
            mock_pip.return_value = (
                1,
                "",
                "WARNING: Skipping testpkg as it is not installed."
            );
            result = installer.uninstall_package("testpkg");
            assert result is False;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyInstaller uninstall_package no venv" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);
        result = installer.uninstall_package("testpkg");
        assert result is False;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

# ===== TestDependencyResolver =====
test "DependencyResolver parse_spec with version" {
    reset_config();
    config = JacConfig();
    config.project_root = Path("/tmp");
    resolver = DependencyResolver(config=config);
    (name, version) = resolver.parse_spec("requests>=2.28.0");
    assert name == "requests";
    assert version == ">=2.28.0";
    reset_config();
}

test "DependencyResolver parse_spec without version" {
    reset_config();
    config = JacConfig();
    config.project_root = Path("/tmp");
    resolver = DependencyResolver(config=config);
    (name, version) = resolver.parse_spec("requests");
    assert name == "requests";
    assert version == "";
    reset_config();
}

test "DependencyResolver parse_spec with equals" {
    reset_config();
    config = JacConfig();
    config.project_root = Path("/tmp");
    resolver = DependencyResolver(config=config);
    (name, version) = resolver.parse_spec("numpy==1.24.0");
    assert name == "numpy";
    assert version == "==1.24.0";
    reset_config();
}

test "DependencyResolver parse_spec with tilde" {
    reset_config();
    config = JacConfig();
    config.project_root = Path("/tmp");
    resolver = DependencyResolver(config=config);
    (name, version) = resolver.parse_spec("django~=4.0");
    assert name == "django";
    assert version == "~=4.0";
    reset_config();
}

test "DependencyResolver resolve dependencies" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        resolver = DependencyResolver(config=config);
        resolved = resolver.resolve(include_dev=False);
        assert len(resolved) >= 1;
        names = [r.name for r in resolved];
        assert "requests" in names;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "DependencyResolver resolve with dev" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        resolver = DependencyResolver(config=config);
        resolved = resolver.resolve(include_dev=True);
        names = [r.name for r in resolved];
        assert "requests" in names;
        assert "pytest" in names;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

# ===== TestResolvedDependency =====
test "ResolvedDependency create" {
    reset_config();
    dep = ResolvedDependency(name="requests", version=">=2.28.0", source="pypi");
    assert dep.name == "requests";
    assert dep.version == ">=2.28.0";
    assert dep.source == "pypi";
    assert dep.extras == [];
    assert dep.dependencies == [];
    reset_config();
}

test "ResolvedDependency with extras" {
    reset_config();
    dep = ResolvedDependency(
        name="requests",
        version="2.28.0",
        source="pypi",
        extras=["security"],
        dependencies=["urllib3", "certifi"]
    );
    assert dep.extras == ["security"];
    assert dep.dependencies == ["urllib3", "certifi"];
    reset_config();
}

# ===== TestPathManagement =====
test "add_venv_to_path" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    saved_path = list(sys.path);
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        site_packages = get_venv_site_packages(config.get_venv_dir());
        site_packages.mkdir(parents=True, exist_ok=True);
        site_str = str(site_packages);
        if site_str in sys.path {
            sys.path.remove(site_str);
        }
        add_venv_to_path(config);
        assert site_str in sys.path;
        sys.path.remove(site_str);
    } finally {
        sys.path.clear();
        sys.path.extend(saved_path);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "remove_venv_from_path" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    saved_path = list(sys.path);
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        site_packages = get_venv_site_packages(config.get_venv_dir());
        site_packages.mkdir(parents=True, exist_ok=True);
        site_str = str(site_packages);
        if site_str not in sys.path {
            sys.path.insert(0, site_str);
        }
        remove_venv_from_path(config);
        assert site_str not in sys.path;
    } finally {
        sys.path.clear();
        sys.path.extend(saved_path);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "is_venv_in_path" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    saved_path = list(sys.path);
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        site_packages = get_venv_site_packages(config.get_venv_dir());
        site_packages.mkdir(parents=True, exist_ok=True);
        site_str = str(site_packages);

        if site_str in sys.path {
            sys.path.remove(site_str);
        }
        assert is_venv_in_path(config) is False;

        sys.path.insert(0, site_str);
        assert is_venv_in_path(config) is True;

        sys.path.remove(site_str);
    } finally {
        sys.path.clear();
        sys.path.extend(saved_path);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "add_venv_no_config" {
    reset_config();
    add_venv_to_path(None);
    reset_config();
}

test "add_venv_dir_not_exists" {
    reset_config();
    (tmp, project_dir) = make_temp_project();
    saved_path = list(sys.path);
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        site_packages = get_venv_site_packages(config.get_venv_dir());
        site_str = str(site_packages);
        if site_str in sys.path {
            sys.path.remove(site_str);
        }
        add_venv_to_path(config);
        assert site_str not in sys.path;
    } finally {
        sys.path.clear();
        sys.path.extend(saved_path);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

# ===== TestProjectCommands =====
test "install with pip and git deps" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        toml = '[project]\nname = "testproj"\nversion = "0.1.0"\n\n[dependencies]\nrequests = ">=2.28.0"\n\n[dependencies.git]\nmy-lib = {git = "https://github.com/user/my-lib.git", branch = "main"}\n';
        project_path = create_test_project(tmp, toml);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.return_value = (
                    0,
                    "Successfully installed requests-2.31.0",
                    ""
                );
                result = proj_cmds.install();
            }
            assert result == 0;
            mock_pip.assert_called();
            call_args = mock_pip.call_args[0][0];
            assert "install" in call_args;
            assert "--upgrade" in call_args;
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "install pip and npm deps" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        toml = '[project]\nname = "fullstack"\nversion = "0.1.0"\n\n[dependencies]\nrequests = "~=2.31"\nflask = "~=3.0"\n\n[dependencies.npm]\nreact = "^18.0.0"\ntypescript = "^5.0.0"\n\n[dev-dependencies]\npytest = ">=8.0.0"\n';
        project_path = create_test_project(tmp, toml);
        os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            mock_install_all = MagicMock();
            mock_dep_type = MagicMock();
            mock_dep_type.install_all_handler = mock_install_all;
            mock_dep_type.install_handler = MagicMock();

            mock_registry = MagicMock();
            mock_registry.get_all.return_value = {"npm": mock_dep_type};

            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip, patch(
                "jaclang.project.dep_registry.get_dependency_registry",
                return_value=mock_registry
            ) as _reg {
                mock_pip.return_value = (
                    0,
                    "Successfully installed requests-2.31.0 flask-3.0.0",
                    ""
                );
                result = proj_cmds.install();
            }
            assert result == 0;
            mock_pip.assert_called();
            pip_call_args = mock_pip.call_args[0][0];
            assert "install" in pip_call_args;
            assert "--upgrade" in pip_call_args;
            mock_install_all.assert_called_once();
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "install with plugin deps" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        toml = '[project]\nname = "testproj"\nversion = "0.1.0"\n\n[dependencies]\n\n[dependencies.npm]\nreact = "18.0"\n';
        project_path = create_test_project(tmp, toml);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            mock_install_all = MagicMock();
            mock_dep_type = MagicMock();
            mock_dep_type.install_all_handler = mock_install_all;
            mock_dep_type.install_handler = MagicMock();

            mock_registry = MagicMock();
            mock_registry.get_all.return_value = {"npm": mock_dep_type};

            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip, patch(
                "jaclang.project.dep_registry.get_dependency_registry",
                return_value=mock_registry
            ) as _reg {
                mock_pip.return_value = (0, "", "");
                result = proj_cmds.install();
            }
            assert result == 0;
            mock_install_all.assert_called_once();
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "install plugin deps individual fallback" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        toml = '[project]\nname = "testproj"\nversion = "0.1.0"\n\n[dependencies]\n\n[dependencies.npm]\nreact = "18.0"\nvue = "3.0"\n';
        project_path = create_test_project(tmp, toml);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            mock_install_handler = MagicMock();
            mock_dep_type = MagicMock();
            mock_dep_type.install_all_handler = None;
            mock_dep_type.install_handler = mock_install_handler;

            mock_registry = MagicMock();
            mock_registry.get_all.return_value = {"npm": mock_dep_type};

            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip, patch(
                "jaclang.project.dep_registry.get_dependency_registry",
                return_value=mock_registry
            ) as _reg {
                mock_pip.return_value = (0, "", "");
                result = proj_cmds.install();
            }
            assert result == 0;
            assert mock_install_handler.call_count == 2;
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "install no toml" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    original_cwd = os.getcwd();
    os.chdir(tmp);
    reset_config();
    try {
        result = proj_cmds.install();
        assert result == 1;
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "add no args errors" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            result = proj_cmds.add();
            assert result == 1;
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add no toml errors" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    original_cwd = os.getcwd();
    os.chdir(tmp);
    reset_config();
    try {
        result = proj_cmds.add(packages=["requests"]);
        assert result == 1;
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "add resolves version" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        venv_dir = os.path.join(project_path, ".jac", "venv");
        os.makedirs(venv_dir, exist_ok=True);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.side_effect = [
                    (0, "Successfully installed numpy-1.26.4", ""),
                    (0, "Name: numpy\nVersion: 1.26.4\nSummary: ...", "")
                ];
                result = proj_cmds.add(packages=["numpy"]);
            }
            assert result == 0;
            config = JacConfig.load(Path(project_path) / "jac.toml");
            assert "numpy" in config.dependencies;
            assert config.dependencies["numpy"] == "~=1.26";
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add with explicit version" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.return_value = (0, "Successfully installed numpy-1.24.0", "");
                result = proj_cmds.add(packages=["numpy>=1.24"]);
            }
            assert result == 0;
            config = JacConfig.load(Path(project_path) / "jac.toml");
            assert "numpy" in config.dependencies;
            assert config.dependencies["numpy"] == ">=1.24";
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "update all deps" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.side_effect = [
                    (0, "Successfully installed requests-2.31.0 flask-3.1.0", ""),
                    (0, "Name: requests\nVersion: 2.31.0", ""),
                    (0, "Name: flask\nVersion: 3.1.0", "")
                ];
                result = proj_cmds.update();
            }
            assert result == 0;
            config = JacConfig.load(Path(project_path) / "jac.toml");
            assert config.dependencies["requests"] == ">=2.28.0";
            assert config.dependencies["flask"] == "~=3.1";
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "update specific package" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        toml = '[project]\nname = "testproj"\nversion = "0.1.0"\n\n[dependencies]\nrequests = "~=2.28"\nflask = "~=3.0"\n\n[dev-dependencies]\npytest = ">=8.0.0"\n';
        project_path = create_test_project(tmp, toml);
        os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.side_effect = [
                    (0, "Successfully installed requests-2.32.0", ""),
                    (0, "Name: requests\nVersion: 2.32.0", "")
                ];
                result = proj_cmds.update(packages=["requests"]);
            }
            assert result == 0;
            config = JacConfig.load(Path(project_path) / "jac.toml");
            assert config.dependencies["requests"] == "~=2.32";
            assert config.dependencies["flask"] == "~=3.0";
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "update unknown package errors" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            result = proj_cmds.update(packages=["nonexistent"]);
            assert result == 1;
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "update no toml errors" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    original_cwd = os.getcwd();
    os.chdir(tmp);
    reset_config();
    try {
        result = proj_cmds.update();
        assert result == 1;
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "add dev dependency" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.side_effect = [
                    (0, "Successfully installed pytest-cov-7.0.0", ""),
                    (0, "Name: pytest-cov\nVersion: 7.0.0", "")
                ];
                result = proj_cmds.add(packages=["pytest-cov"], dev=True);
            }
            assert result == 0;
            config = JacConfig.load(Path(project_path) / "jac.toml");
            assert "pytest-cov" in config.dev_dependencies;
            assert config.dev_dependencies["pytest-cov"] == "~=7.0";
            assert "pytest-cov" not in config.dependencies;
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add multiple packages" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.side_effect = [
                    (0, "Successfully installed numpy-2.4.2", ""),
                    (0, "Name: numpy\nVersion: 2.4.2", ""),
                    (0, "Successfully installed pandas-3.0.0", ""),
                    (0, "Name: pandas\nVersion: 3.0.0", "")
                ];
                result = proj_cmds.add(packages=["numpy", "pandas"]);
            }
            assert result == 0;
            config = JacConfig.load(Path(project_path) / "jac.toml");
            assert config.dependencies["numpy"] == "~=2.4";
            assert config.dependencies["pandas"] == "~=3.0";
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add pip failure no toml update" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        toml_path = os.path.join(project_path, "jac.toml");
        f = open(toml_path);
        original_toml = f.read();
        f.close();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.return_value = (
                    1,
                    "",
                    "ERROR: No matching distribution found for badpkg"
                );
                result = proj_cmds.add(packages=["badpkg"]);
            }
            assert result == 1;
            f = open(toml_path);
            current_toml = f.read();
            f.close();
            assert current_toml == original_toml;
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add git dependency" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.return_value = (0, "Successfully installed my-lib", "");
                result = proj_cmds.add(git="https://github.com/user/my-lib.git");
            }
            assert result == 0;
            config = JacConfig.load(Path(project_path) / "jac.toml");
            assert "my-lib" in config.git_dependencies;
            assert config.git_dependencies["my-lib"]["git"] == "https://github.com/user/my-lib.git";
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "update with dev deps" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        toml = '[project]\nname = "testproj"\nversion = "0.1.0"\n\n[dependencies]\nrequests = "~=2.28"\nflask = "~=3.0"\n\n[dev-dependencies]\npytest = "~=8.0"\n';
        project_path = create_test_project(tmp, toml);
        os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.side_effect = [
                    (0, "Successfully installed", ""),
                    (0, "Name: requests\nVersion: 2.32.0", ""),
                    (0, "Name: flask\nVersion: 3.1.0", ""),
                    (0, "Name: pytest\nVersion: 8.3.0", "")
                ];
                result = proj_cmds.update(dev=True);
            }
            assert result == 0;
            config = JacConfig.load(Path(project_path) / "jac.toml");
            assert config.dependencies["requests"] == "~=2.32";
            assert config.dependencies["flask"] == "~=3.1";
            assert config.dev_dependencies["pytest"] == "~=8.3";
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "install empty deps" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        toml = '[project]\nname = "empty"\nversion = "0.1.0"\n\n[dependencies]\n\n[dev-dependencies]\n';
        project_path = create_test_project(tmp, toml);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            result = proj_cmds.install();
            assert result == 0;
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "remove package" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.return_value = (
                    0,
                    "Successfully uninstalled requests-2.31.0",
                    ""
                );
                result = proj_cmds.remove(packages=["requests"]);
            }
            assert result == 0;
            config = JacConfig.load(Path(project_path) / "jac.toml");
            assert "requests" not in config.dependencies;
            assert "flask" in config.dependencies;
            mock_pip.assert_called_with(["uninstall", "-y", "requests"]);
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "remove dev dep without flag" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            with patch("jaclang.project.dependencies.DependencyInstaller.ensure_venv") as _ev, patch(
                "jaclang.project.dependencies.DependencyInstaller._run_pip"
            ) as mock_pip {
                mock_pip.return_value = (
                    0,
                    "Successfully uninstalled pytest-8.0.0",
                    ""
                );
                result = proj_cmds.remove(packages=["pytest"]);
            }
            assert result == 0;
            config = JacConfig.load(Path(project_path) / "jac.toml");
            assert "pytest" not in config.dev_dependencies;
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "remove no args errors" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            result = proj_cmds.remove();
            assert result == 1;
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "remove no toml errors" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    original_cwd = os.getcwd();
    os.chdir(tmp);
    reset_config();
    try {
        result = proj_cmds.remove(packages=["requests"]);
        assert result == 1;
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "remove nonexistent package" {
    reset_config();
    import from jaclang.cli.commands { project as proj_cmds }
    tmp = tempfile.mkdtemp(prefix="jac_test_");
    try {
        project_path = create_test_project(tmp);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        reset_config();
        try {
            result = proj_cmds.remove(packages=["nonexistent"]);
            assert result == 0;
        } finally {
            os.chdir(original_cwd);
            reset_config();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
