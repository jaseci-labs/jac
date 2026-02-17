"""Tests for jaclang.project.config module."""

import os;
import shutil;
import tempfile;
import tomllib;
import from pathlib { Path }
import from tempfile { TemporaryDirectory, NamedTemporaryFile }
import from jaclang.project.config {
    JacConfig,
    discover_config_files,
    find_project_root,
    get_config,
    interpolate_env_vars,
    is_in_project,
    set_config
}
import jaclang.project.config as config_mod;

glob FIXTURE_BASE = str(Path(__file__).parent / "fixtures"),
     JAC_TOML_CONTENT = "[project]\nname = \"test-project\"\nversion = \"0.1.0\"\ndescription = \"A test project\"\nentry-point = \"main.jac\"\n\n[dependencies]\nrequests = \">=2.28.0\"\n\n[dev-dependencies]\npytest = \">=8.0.0\"\n\n[run]\nmain = true\ncache = true\n\n[scripts]\ntest = \"jac test\"\n",
     MAIN_JAC_CONTENT = "\"\"\"Test main file.\"\"\"\n\nwith entry {\n    print(\"Hello, World!\");\n}\n",
     BASE_TOML = "[project]\nname = \"jactastic\"\n\n[serve]\nport = 8090\nbase_route_app = \"app\"\n\n[plugins.client]\n\n[dependencies.npm]\njac-client-node = \"1.0.4\"\n\n[dev-dependencies]\nwatchdog = \">=3.0\"\n",
     PROD_TOML = "[serve]\nport = 80\n\n[plugins.client]\nminify = true\n\n[plugins.byllm]\ndefault_model = \"gpt-4\"\n",
     LOCAL_TOML = "[serve]\nport = 9000\n\n[run]\ncache = false\n";

"""Create a temporary project directory with jac.toml."""
def make_temp_project(temp_dir: Path) -> Path {
    project_dir = temp_dir / "test_project";
    project_dir.mkdir();
    jac_toml = project_dir / "jac.toml";
    jac_toml.write_text(JAC_TOML_CONTENT);
    src_dir = project_dir / "src";
    src_dir.mkdir();
    main_jac = src_dir / "main.jac";
    main_jac.write_text(MAIN_JAC_CONTENT);
    return project_dir;
}

"""Write base, prod, and local TOML files into project_dir."""
def write_multi_profile(project_dir: Path) {
    (project_dir / "jac.toml").write_text(BASE_TOML);
    (project_dir / "jac.prod.toml").write_text(PROD_TOML);
    (project_dir / "jac.local.toml").write_text(LOCAL_TOML);
}

# ===========================================================================
# TestInterpolateEnvVars
# ===========================================================================
test "interpolate simple env var" {
    config_mod._config = None;
    os.environ["TEST_VAR"] = "hello";
    result = interpolate_env_vars("prefix-${TEST_VAR}-suffix");
    assert result == "prefix-hello-suffix";
    del os.environ["TEST_VAR"];
}

test "interpolate env var with default" {
    config_mod._config = None;
    os.environ.pop("NONEXISTENT_VAR", None);
    result = interpolate_env_vars("${NONEXISTENT_VAR:-default_value}");
    assert result == "default_value";
}

test "interpolate env var with default when set" {
    config_mod._config = None;
    os.environ["MY_VAR"] = "actual";
    result = interpolate_env_vars("${MY_VAR:-default}");
    assert result == "actual";
    del os.environ["MY_VAR"];
}

test "interpolate required env var missing" {
    config_mod._config = None;
    os.environ.pop("REQUIRED_VAR", None);
    raised = False;
    try {
        interpolate_env_vars("${REQUIRED_VAR}");
    } except ValueError as e {
        raised = True;
        assert "REQUIRED_VAR is not set" in str(e);
    }
    assert raised , "Expected ValueError for missing required env var";
}

test "interpolate required env var with custom error" {
    config_mod._config = None;
    os.environ.pop("MY_SECRET", None);
    raised = False;
    try {
        interpolate_env_vars("${MY_SECRET:?Secret must be configured}");
    } except ValueError as e {
        raised = True;
        assert "Secret must be configured" in str(e);
    }
    assert raised , "Expected ValueError with custom error message";
}

test "interpolate multiple env vars" {
    config_mod._config = None;
    os.environ["HOST"] = "localhost";
    os.environ["PORT"] = "8080";
    result = interpolate_env_vars("http://${HOST}:${PORT}/api");
    assert result == "http://localhost:8080/api";
    del os.environ["HOST"];
    del os.environ["PORT"];
}

test "interpolate non string passthrough" {
    config_mod._config = None;
    assert interpolate_env_vars(123) == 123;
    assert interpolate_env_vars(None) is None;
}

# ===========================================================================
# TestFindProjectRoot
# ===========================================================================
test "find project in current dir" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        result = find_project_root(temp_project);
        assert result is not None;
        (project_root, toml_path) = result;
        assert project_root.resolve() == temp_project.resolve();
        assert toml_path.resolve() == (temp_project / "jac.toml").resolve();
    }
}

test "find project in parent dir" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        subdir = temp_project / "src" / "submodule";
        subdir.mkdir(parents=True);
        result = find_project_root(subdir);
        assert result is not None;
        (project_root, toml_path) = result;
        assert project_root.resolve() == temp_project.resolve();
        assert toml_path.resolve() == (temp_project / "jac.toml").resolve();
    }
}

test "no project found" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        empty_dir = Path(tmpdir) / "empty";
        empty_dir.mkdir();
        result = find_project_root(empty_dir);
        assert result is None;
    }
}

test "is in project" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_project);
            assert is_in_project() is True;
            os.chdir(Path(tmpdir));
            assert is_in_project() is False;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

# ===========================================================================
# TestJacConfigLoad
# ===========================================================================
test "load basic config" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.project.name == "test-project";
        assert cfg.project.version == "0.1.0";
        assert cfg.project.description == "A test project";
        assert cfg.project.entry_point == "main.jac";
    }
}

test "load dependencies" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert "requests" in cfg.dependencies;
        assert cfg.dependencies["requests"] == ">=2.28.0";
    }
}

test "load dev dependencies" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert "pytest" in cfg.dev_dependencies;
        assert cfg.dev_dependencies["pytest"] == ">=8.0.0";
    }
}

test "load run config" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.run.main is True;
        assert cfg.run.cache is True;
    }
}

test "load scripts" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert "test" in cfg.scripts;
        assert cfg.scripts["test"] == "jac test";
    }
}

test "load nonexistent file" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        raised = False;
        try {
            JacConfig.load(Path(tmpdir) / "nonexistent.toml");
        } except FileNotFoundError {
            raised = True;
        }
        assert raised , "Expected FileNotFoundError for nonexistent file";
    }
}

test "project root set" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.project_root == temp_project;
        assert cfg.toml_path == temp_project / "jac.toml";
    }
}

# ===========================================================================
# TestJacConfigDiscover
# ===========================================================================
test "discover from project root" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.discover(temp_project);
        assert cfg is not None;
        assert cfg.project.name == "test-project";
    }
}

test "discover from subdirectory" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        subdir = temp_project / "src";
        cfg = JacConfig.discover(subdir);
        assert cfg is not None;
        assert cfg.project.name == "test-project";
    }
}

test "discover no project" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        cfg = JacConfig.discover(Path(tmpdir));
        assert cfg is None;
    }
}

# ===========================================================================
# TestJacConfigFromTomlStr
# ===========================================================================
test "parse minimal config" {
    config_mod._config = None;
    toml_str = "\n[project]\nname = \"minimal\"\n";
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.project.name == "minimal";
    assert cfg.project.version == "0.1.0";
}

test "parse full config" {
    config_mod._config = None;
    toml_str = "\n[project]\nname = \"full-project\"\nversion = \"1.2.3\"\ndescription = \"A full project\"\nauthors = [\"Jane Doe <jane@example.com>\"]\nlicense = \"MIT\"\nentry-point = \"app.jac\"\n\n[dependencies]\nnumpy = \">=1.24.0\"\npandas = \">=2.0.0\"\n\n[run]\nsession = \"my_session\"\nmain = false\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\ndirectory = \"tests\"\nverbose = true\nfail_fast = true\nmax_failures = 5\n\n[serve]\nport = 9000\n\n[cache]\nenabled = false\ndir = \".cache\"\n\n[scripts]\nstart = \"jac run app.jac\"\nlint = \"jac lint . --fix\"\n\n[plugins.byllm]\ndefault_model = \"gpt-4\"\ntemperature = 0.7\n\n[environments.development]\n[environments.development.serve]\nport = 3000\n\n[environments.production]\n[environments.production.serve]\nport = 8000\n";
    cfg = JacConfig.from_toml_str(toml_str);

    # Project
    assert cfg.project.name == "full-project";
    assert cfg.project.version == "1.2.3";
    assert cfg.project.description == "A full project";
    assert cfg.project.license == "MIT";
    assert cfg.project.entry_point == "app.jac";

    # Dependencies
    assert "numpy" in cfg.dependencies;
    assert "pandas" in cfg.dependencies;

    # Run config
    assert cfg.run.session == "my_session";
    assert cfg.run.main is False;
    assert cfg.run.cache is False;

    # Build config
    assert cfg.build.typecheck is True;

    # Test config
    assert cfg.test.directory == "tests";
    assert cfg.test.verbose is True;
    assert cfg.test.fail_fast is True;
    assert cfg.test.max_failures == 5;

    # Serve config
    assert cfg.serve.port == 9000;

    # Cache config
    assert cfg.cache.enabled is False;
    assert cfg.cache.dir == ".cache";

    # Scripts
    assert cfg.scripts["start"] == "jac run app.jac";
    assert cfg.scripts["lint"] == "jac lint . --fix";

    # Plugin config
    assert "byllm" in cfg.plugins;
    assert cfg.plugins["byllm"]["default_model"] == "gpt-4";

    # Environments
    assert "development" in cfg.environments;
    assert "production" in cfg.environments;
}

# ===========================================================================
# TestJacConfigProfiles
# ===========================================================================
test "apply profile" {
    config_mod._config = None;
    toml_str = "\n[project]\nname = \"profile-test\"\n\n[serve]\nport = 8000\n\n[environments.development]\n[environments.development.serve]\nport = 3000\n";
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.serve.port == 8000;
    cfg.apply_profile("development");
    assert cfg.serve.port == 3000;
}

test "profile inheritance" {
    config_mod._config = None;
    toml_str = "\n[project]\nname = \"inherit-test\"\n\n[serve]\nport = 8000\n\n[environments.base]\n[environments.base.serve]\nport = 9000\n\n[environments.staging]\ninherits = \"base\"\n\n[environments.staging.test]\nverbose = true\n";
    cfg = JacConfig.from_toml_str(toml_str);
    cfg.apply_profile("staging");
    assert cfg.serve.port == 9000;
    assert cfg.test.verbose is True;
}

test "apply nonexistent profile" {
    config_mod._config = None;
    toml_str = "\n[project]\nname = \"no-profile\"\n\n[serve]\nport = 8000\n";
    cfg = JacConfig.from_toml_str(toml_str);
    cfg.apply_profile("nonexistent");
    assert cfg.serve.port == 8000;
}

# ===========================================================================
# TestJacConfigDependencyManagement
# ===========================================================================
test "add python dependency" {
    config_mod._config = None;
    cfg = JacConfig();
    cfg.add_dependency("requests", ">=2.28.0");
    assert "requests" in cfg.dependencies;
    assert cfg.dependencies["requests"] == ">=2.28.0";
}

test "add dev dependency" {
    config_mod._config = None;
    cfg = JacConfig();
    cfg.add_dependency("pytest", ">=8.0.0", dev=True);
    assert "pytest" in cfg.dev_dependencies;
    assert cfg.dev_dependencies["pytest"] == ">=8.0.0";
}

test "add git dependency" {
    config_mod._config = None;
    cfg = JacConfig();
    cfg.add_dependency(
        "my-plugin", "https://github.com/user/plugin.git", dep_type="git"
    );
    assert "my-plugin" in cfg.git_dependencies;
    assert cfg.git_dependencies["my-plugin"]["git"] == "https://github.com/user/plugin.git";
}

test "add npm dependency" {
    config_mod._config = None;
    cfg = JacConfig();
    cfg.add_dependency("react", "^19.0.0", dep_type="npm");
    assert "npm" in cfg.plugin_dependencies;
    assert cfg.plugin_dependencies["npm"]["react"] == "^19.0.0";
}

test "remove python dependency" {
    config_mod._config = None;
    cfg = JacConfig();
    cfg.dependencies["requests"] = ">=2.28.0";
    result = cfg.remove_dependency("requests");
    assert result is True;
    assert "requests" not in cfg.dependencies;
}

test "remove nonexistent dependency" {
    config_mod._config = None;
    cfg = JacConfig();
    result = cfg.remove_dependency("nonexistent");
    assert result is False;
}

# ===========================================================================
# TestJacConfigMethods
# ===========================================================================
test "get build dir default" {
    config_mod._config = None;
    cfg = JacConfig();
    cfg.project_root = Path("/home/user/myproject");
    build_dir = cfg.get_build_dir();
    assert build_dir == Path("/home/user/myproject/.jac");
}

test "get build dir custom" {
    config_mod._config = None;
    toml_str = "\n[project]\nname = \"test\"\nversion = \"0.1.0\"\n\n[build]\ndir = \".build\"\n";
    cfg = JacConfig.from_toml_str(toml_str);
    cfg.project_root = Path("/home/user/myproject");
    build_dir = cfg.get_build_dir();
    assert build_dir == Path("/home/user/myproject/.build");
}

test "get cache dir" {
    config_mod._config = None;
    cfg = JacConfig();
    cfg.project_root = Path("/home/user/myproject");
    cache_dir = cfg.get_cache_dir();
    assert cache_dir == Path("/home/user/myproject/.jac/cache");
}

test "get venv dir" {
    config_mod._config = None;
    cfg = JacConfig();
    cfg.project_root = Path("/home/user/myproject");
    venv_dir = cfg.get_venv_dir();
    assert venv_dir == Path("/home/user/myproject/.jac/venv");
}

test "get data dir" {
    config_mod._config = None;
    cfg = JacConfig();
    cfg.project_root = Path("/home/user/myproject");
    data_dir = cfg.get_data_dir();
    assert data_dir == Path("/home/user/myproject/.jac/data");
}

test "get client dir" {
    config_mod._config = None;
    cfg = JacConfig();
    cfg.project_root = Path("/home/user/myproject");
    client_dir = cfg.get_client_dir();
    assert client_dir == Path("/home/user/myproject/.jac/client");
}

test "all dirs use custom build dir" {
    config_mod._config = None;
    toml_str = "\n[project]\nname = \"test\"\n\n[build]\ndir = \".custom-build\"\n";
    cfg = JacConfig.from_toml_str(toml_str);
    cfg.project_root = Path("/project");
    assert cfg.get_build_dir() == Path("/project/.custom-build");
    assert cfg.get_cache_dir() == Path("/project/.custom-build/cache");
    assert cfg.get_venv_dir() == Path("/project/.custom-build/venv");
    assert cfg.get_data_dir() == Path("/project/.custom-build/data");
    assert cfg.get_client_dir() == Path("/project/.custom-build/client");
}

test "is valid" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.is_valid() is True;
        empty_config = JacConfig();
        assert empty_config.is_valid() is False;
    }
}

test "get plugin config" {
    config_mod._config = None;
    toml_str = "\n[project]\nname = \"plugin-test\"\n\n[plugins.byllm]\nmodel = \"gpt-4\"\ntemperature = 0.5\n";
    cfg = JacConfig.from_toml_str(toml_str);
    byllm_config = cfg.get_plugin_config("byllm");
    assert byllm_config["model"] == "gpt-4";
    assert byllm_config["temperature"] == 0.5;
}

test "get plugin config missing" {
    config_mod._config = None;
    cfg = JacConfig();
    result = cfg.get_plugin_config("nonexistent");
    assert result == {};
}

test "create default toml" {
    config_mod._config = None;
    import from jaclang.project.template_registry {
        get_template_registry,
        initialize_template_registry
    }
    initialize_template_registry();
    registry = get_template_registry();
    template = registry.get_default();
    assert template is not None;
    assert "project" in template.config;
    assert "dependencies" in template.config;
}

# ===========================================================================
# TestGlobalConfig
# ===========================================================================
test "get config discovers" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_project);
            cfg = get_config();
            assert cfg is not None;
            assert cfg.project.name == "test-project";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "set config" {
    config_mod._config = None;
    custom_config = JacConfig();
    custom_config.project.name = "custom";
    set_config(custom_config);
    retrieved = get_config();
    assert retrieved is not None;
    assert retrieved.project.name == "custom";
}

test "get config force discover" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_project);
            get_config();
            custom = JacConfig();
            custom.project.name = "modified";
            set_config(custom);
            config2 = get_config(force_discover=True);
            assert config2 is not None;
            assert config2.project.name == "test-project";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

# ===========================================================================
# TestConfigFilesTracking
# ===========================================================================
test "load initializes config files" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert len(cfg.config_files) == 1;
        assert cfg.config_files[0] == temp_project / "jac.toml";
    }
}

test "discover initializes config files" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.discover(temp_project);
        assert cfg is not None;
        assert len(cfg.config_files) == 1;
    }
}

test "active profile default empty" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.active_profile == "";
    }
}

# ===========================================================================
# TestDiscoverConfigFiles
# ===========================================================================
test "only base exists" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        files = discover_config_files(temp_project);
        assert len(files) == 1;
        assert files[0] == temp_project / "jac.toml";
    }
}

test "with profile file" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        prod_toml = temp_project / "jac.prod.toml";
        prod_toml.write_text("[serve]\nport = 80\n");
        files = discover_config_files(temp_project, profile="prod");
        assert len(files) == 2;
        assert files[0] == temp_project / "jac.toml";
        assert files[1] == prod_toml;
    }
}

test "with local file" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        local_toml = temp_project / "jac.local.toml";
        local_toml.write_text("[run]\ncache = false\n");
        files = discover_config_files(temp_project);
        assert len(files) == 2;
        assert files[0] == temp_project / "jac.toml";
        assert files[1] == local_toml;
    }
}

test "all files present" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        (temp_project / "jac.staging.toml").write_text("[serve]\nport = 9000\n");
        (temp_project / "jac.local.toml").write_text("[run]\ncache = false\n");
        files = discover_config_files(temp_project, profile="staging");
        assert len(files) == 3;
        assert files[0].name == "jac.toml";
        assert files[1].name == "jac.staging.toml";
        assert files[2].name == "jac.local.toml";
    }
}

test "profile file missing" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        files = discover_config_files(temp_project, profile="nonexistent");
        assert len(files) == 1;
        assert files[0].name == "jac.toml";
    }
}

test "no profile skips profile file" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        (temp_project / "jac.prod.toml").write_text("[serve]\nport = 80\n");
        files = discover_config_files(temp_project, profile=None);
        assert len(files) == 1;
    }
}

test "empty directory" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        empty_dir = Path(tmpdir) / "empty";
        empty_dir.mkdir();
        files = discover_config_files(empty_dir);
        assert len(files) == 0;
    }
}

# ===========================================================================
# TestMergeFromTomlFile
# ===========================================================================
test "merge simple sections" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.run.cache is True;
        assert cfg.serve.port == 8000;
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[run]\ncache = false\n\n[serve]\nport = 9000\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.run.cache is False;
        assert cfg.serve.port == 9000;
    }
}

test "merge preserves unset values" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.run.main is True;
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[run]\ncache = false\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.run.cache is False;
        assert cfg.run.main is True;
    }
}

test "merge project kebab case" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[project]\nentry-point = \"app.jac\"\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.project.entry_point == "app.jac";
    }
}

test "merge check with nested lint" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text(
            "[check]\nwarnonly = true\n\n[check.lint]\nselect = [\"all\"]\n"
        );
        cfg.merge_from_toml_file(overlay);
        assert cfg.check.warnonly is True;
        assert cfg.check.lint.select == ["all"];
    }
}

test "merge plugins config" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text(
            "[plugins]\ndiscovery = \"manual\"\n\n[plugins.byllm]\ndefault_model = \"gpt-4\"\n"
        );
        cfg.merge_from_toml_file(overlay);
        assert cfg.plugins_config.discovery == "manual";
        assert "byllm" in cfg.plugins;
        assert cfg.plugins["byllm"]["default_model"] == "gpt-4";
    }
}

test "merge dependencies" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert "requests" in cfg.dependencies;
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[dependencies]\nnumpy = \">=1.24.0\"\n");
        cfg.merge_from_toml_file(overlay);
        assert "requests" in cfg.dependencies;
        assert "numpy" in cfg.dependencies;
        assert cfg.dependencies["numpy"] == ">=1.24.0";
    }
}

test "merge dependencies override" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.dependencies["requests"] == ">=2.28.0";
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[dependencies]\nrequests = \">=3.0.0\"\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.dependencies["requests"] == ">=3.0.0";
    }
}

test "merge dev dependencies" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[dev-dependencies]\nruff = \">=0.1.0\"\n");
        cfg.merge_from_toml_file(overlay);
        assert "ruff" in cfg.dev_dependencies;
        assert "pytest" in cfg.dev_dependencies;
    }
}

test "merge scripts" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert "test" in cfg.scripts;
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[scripts]\nbuild = \"jac build\"\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.scripts["test"] == "jac test";
        assert cfg.scripts["build"] == "jac build";
    }
}

test "merge environments" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text(
            "[environments.ci]\n\n[environments.ci.test]\nverbose = true\n"
        );
        cfg.merge_from_toml_file(overlay);
        assert "ci" in cfg.environments;
    }
}

test "merge tracks config file" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert len(cfg.config_files) == 1;
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[run]\ncache = false\n");
        cfg.merge_from_toml_file(overlay);
        assert len(cfg.config_files) == 2;
        assert overlay in cfg.config_files;
    }
}

test "merge no duplicate tracking" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[run]\ncache = false\n");
        cfg.merge_from_toml_file(overlay);
        cfg.merge_from_toml_file(overlay);
        assert cfg.config_files.count(overlay) == 1;
    }
}

test "merge updates raw data" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert "serve" not in cfg._raw_data;
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[serve]\nport = 9000\n");
        cfg.merge_from_toml_file(overlay);
        assert "serve" in cfg._raw_data;
        assert cfg._raw_data["serve"]["port"] == 9000;
    }
}

test "merge nonexistent file" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        original_port = cfg.serve.port;
        original_files = len(cfg.config_files);
        cfg.merge_from_toml_file(temp_project / "nonexistent.toml");
        assert cfg.serve.port == original_port;
        assert len(cfg.config_files) == original_files;
    }
}

test "merge ignores unknown keys" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[run]\nunknown_key = \"value\"\ncache = false\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.run.cache is False;
        assert not hasattr(cfg.run, "unknown_key");
    }
}

test "merge malformed toml" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        bad_file = temp_project / "bad.toml";
        bad_file.write_text("this is not valid toml [[[");
        raised = False;
        try {
            cfg.merge_from_toml_file(bad_file);
        } except tomllib.TOMLDecodeError {
            raised = True;
        }
        assert raised , "Expected TOMLDecodeError for malformed TOML";
    }
}

test "merge env interpolation" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text(
            "[plugins.byllm]\napi_key = \"${TEST_API_KEY:-default_key}\"\n"
        );
        os.environ.pop("TEST_API_KEY", None);
        cfg.merge_from_toml_file(overlay);
        assert cfg.plugins["byllm"]["api_key"] == "default_key";
    }
}

# ===========================================================================
# TestApplyProfileOverlay
# ===========================================================================
test "no profile applies local only" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        local = temp_project / "jac.local.toml";
        local.write_text("[run]\ncache = false\n");
        cfg.apply_profile_overlay(None);
        assert cfg.run.cache is False;
        assert cfg.active_profile == "";
    }
}

test "empty string profile treated as none" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        cfg.apply_profile_overlay("");
        assert cfg.active_profile == "";
    }
}

test "profile merges file and infile" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        jac_toml = temp_project / "jac.toml";
        jac_toml.write_text(
            "[project]\nname = \"test-project\"\n\n[serve]\nport = 8000\n\n[environments.prod]\n[environments.prod.serve]\nport = 443\n"
        );
        prod_toml = temp_project / "jac.prod.toml";
        prod_toml.write_text("[build]\ntypecheck = true\n");
        cfg = JacConfig.load(jac_toml);
        cfg.apply_profile_overlay("prod");
        assert cfg.build.typecheck is True;
        assert cfg.serve.port == 443;
        assert cfg.active_profile == "prod";
    }
}

test "local overrides profile" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        jac_toml = temp_project / "jac.toml";
        jac_toml.write_text("[project]\nname = \"test\"\n\n[serve]\nport = 8000\n");
        prod_toml = temp_project / "jac.prod.toml";
        prod_toml.write_text("[serve]\nport = 80\n");
        local_toml = temp_project / "jac.local.toml";
        local_toml.write_text("[serve]\nport = 9999\n");
        cfg = JacConfig.load(jac_toml);
        cfg.apply_profile_overlay("prod");
        assert cfg.serve.port == 9999;
    }
}

test "profile file missing infile still applied" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        jac_toml = temp_project / "jac.toml";
        jac_toml.write_text(
            "[project]\nname = \"test\"\n\n[serve]\nport = 8000\n\n[environments.staging]\n[environments.staging.serve]\nport = 9000\n"
        );
        cfg = JacConfig.load(jac_toml);
        cfg.apply_profile_overlay("staging");
        assert cfg.serve.port == 9000;
        assert cfg.active_profile == "staging";
    }
}

test "nonexistent profile no crash" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        original_port = cfg.serve.port;
        cfg.apply_profile_overlay("nonexistent");
        assert cfg.serve.port == original_port;
        assert cfg.active_profile == "nonexistent";
    }
}

test "no project root early return" {
    config_mod._config = None;
    cfg = JacConfig();
    assert cfg.project_root is None;
    cfg.apply_profile_overlay("prod");
    assert cfg.active_profile == "";
}

test "overlay tracks all config files" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        jac_toml = temp_project / "jac.toml";
        jac_toml.write_text("[project]\nname = \"test\"\n");
        prod_toml = temp_project / "jac.prod.toml";
        prod_toml.write_text("[serve]\nport = 80\n");
        local_toml = temp_project / "jac.local.toml";
        local_toml.write_text("[run]\ncache = false\n");
        cfg = JacConfig.load(jac_toml);
        cfg.apply_profile_overlay("prod");
        assert len(cfg.config_files) == 3;
        assert cfg.config_files[0] == jac_toml;
        assert cfg.config_files[1] == prod_toml;
        assert cfg.config_files[2] == local_toml;
    }
}

test "overlay priority order" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        jac_toml = temp_project / "jac.toml";
        jac_toml.write_text(
            "[project]\nname = \"test\"\n\n[test]\nverbose = false\n\n[environments.prod]\n[environments.prod.test]\nverbose = true\n"
        );
        prod_toml = temp_project / "jac.prod.toml";
        prod_toml.write_text("[test]\nfail_fast = true\n");
        local_toml = temp_project / "jac.local.toml";
        local_toml.write_text("[test]\nverbose = false\n");
        cfg = JacConfig.load(jac_toml);
        cfg.apply_profile_overlay("prod");
        assert cfg.test.fail_fast is True;
        assert cfg.test.verbose is False;
    }
}

test "no local file no error" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        cfg.apply_profile_overlay("prod");
        assert cfg.active_profile == "prod";
    }
}

# ===========================================================================
# TestMultiProfileBugFixes
# ===========================================================================
test "merge storage type mapping" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.storage.storage_type == "local";
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[storage]\ntype = \"s3\"\nbase_path = \"/data\"\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.storage.storage_type == "s3";
        assert cfg.storage.base_path == "/data";
    }
}

test "merge plugins deep nested" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        jac_toml = temp_project / "jac.toml";
        jac_toml.write_text(
            "[project]\nname = \"test\"\n\n[plugins.byllm]\ndefault_model = \"gpt-4\"\n\n[plugins.byllm.options]\ntemperature = 0.7\nmax_tokens = 1000\n"
        );
        cfg = JacConfig.load(jac_toml);
        assert cfg.plugins["byllm"]["options"]["temperature"] == 0.7;
        assert cfg.plugins["byllm"]["options"]["max_tokens"] == 1000;
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[plugins.byllm.options]\ntemperature = 0.9\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.plugins["byllm"]["options"]["temperature"] == 0.9;
        assert cfg.plugins["byllm"]["options"]["max_tokens"] == 1000;
        assert cfg.plugins["byllm"]["default_model"] == "gpt-4";
    }
}

test "apply profile build section" {
    config_mod._config = None;
    cfg = JacConfig.from_toml_str(
        "[project]\nname = \"test\"\n\n[build]\ntypecheck = false\n\n[environments.prod]\n[environments.prod.build]\ntypecheck = true\n"
    );
    assert cfg.build.typecheck is False;
    cfg.apply_profile("prod");
    assert cfg.build.typecheck is True;
}

test "apply profile format section" {
    config_mod._config = None;
    cfg = JacConfig.from_toml_str(
        "[project]\nname = \"test\"\n\n[environments.dev]\n[environments.dev.format]\noutfile = \"formatted.jac\"\n"
    );
    cfg.apply_profile("dev");
    assert cfg.format.outfile == "formatted.jac";
}

test "apply profile dot section" {
    config_mod._config = None;
    cfg = JacConfig.from_toml_str(
        "[project]\nname = \"test\"\n\n[environments.debug]\n[environments.debug.dot]\ndepth = 5\ntraverse = true\n"
    );
    cfg.apply_profile("debug");
    assert cfg.dot.depth == 5;
    assert cfg.dot.traverse is True;
}

test "apply profile cache section" {
    config_mod._config = None;
    cfg = JacConfig.from_toml_str(
        "[project]\nname = \"test\"\n\n[environments.ci]\n[environments.ci.cache]\nenabled = false\n"
    );
    cfg.apply_profile("ci");
    assert cfg.cache.enabled is False;
}

test "apply profile storage type mapping" {
    config_mod._config = None;
    cfg = JacConfig.from_toml_str(
        "[project]\nname = \"test\"\n\n[environments.prod]\n[environments.prod.storage]\ntype = \"s3\"\nbase_path = \"/prod-data\"\n"
    );
    cfg.apply_profile("prod");
    assert cfg.storage.storage_type == "s3";
    assert cfg.storage.base_path == "/prod-data";
}

test "apply profile check with lint" {
    config_mod._config = None;
    cfg = JacConfig.from_toml_str(
        "[project]\nname = \"test\"\n\n[environments.strict]\n[environments.strict.check]\nwarnonly = false\n\n[environments.strict.check.lint]\nselect = [\"all\"]\n"
    );
    cfg.apply_profile("strict");
    assert cfg.check.warnonly is False;
    assert cfg.check.lint.select == ["all"];
}

test "apply profile project kebab case" {
    config_mod._config = None;
    cfg = JacConfig.from_toml_str(
        "[project]\nname = \"test\"\nentry-point = \"main.jac\"\n\n[environments.alt]\n[environments.alt.project]\nentry-point = \"app.jac\"\n"
    );
    cfg.apply_profile("alt");
    assert cfg.project.entry_point == "app.jac";
}

test "apply profile dependencies and scripts" {
    config_mod._config = None;
    cfg = JacConfig.from_toml_str(
        "[project]\nname = \"test\"\n\n[dependencies]\nrequests = \">=2.0\"\n\n[scripts]\ntest = \"jac test\"\n\n[environments.prod]\n[environments.prod.dependencies]\ngunicorn = \">=21.0\"\n\n[environments.prod.scripts]\nstart = \"jac start --port 80\"\n"
    );
    cfg.apply_profile("prod");
    assert cfg.dependencies.get("gunicorn") == ">=21.0";
    assert cfg.dependencies.get("requests") == ">=2.0";
    assert cfg.scripts.get("start") == "jac start --port 80";
    assert cfg.scripts.get("test") == "jac test";
}

test "circular profile inheritance" {
    config_mod._config = None;
    cfg = JacConfig.from_toml_str(
        "[project]\nname = \"test\"\n\n[environments.a]\ninherits = \"b\"\n[environments.a.serve]\nport = 1000\n\n[environments.b]\ninherits = \"a\"\n[environments.b.serve]\nport = 2000\n"
    );
    cfg.apply_profile("a");
    assert cfg.serve.port == 1000;
}

test "three way circular inheritance" {
    config_mod._config = None;
    cfg = JacConfig.from_toml_str(
        "[project]\nname = \"test\"\n\n[environments.a]\ninherits = \"b\"\n[environments.a.serve]\nport = 1000\n\n[environments.b]\ninherits = \"c\"\n[environments.b.serve]\nport = 2000\n\n[environments.c]\ninherits = \"a\"\n[environments.c.serve]\nport = 3000\n"
    );
    cfg.apply_profile("a");
    assert cfg.serve.port == 1000;
}

test "discover with profile" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        jac_toml = temp_project / "jac.toml";
        jac_toml.write_text(
            "[project]\nname = \"test-project\"\nversion = \"0.1.0\"\n\n[serve]\nport = 8000\n\n[environments.prod]\n[environments.prod.serve]\nport = 443\n"
        );
        cfg = JacConfig.discover(temp_project, profile="prod");
        assert cfg is not None;
        assert cfg.serve.port == 443;
        assert cfg.active_profile == "prod";
    }
}

test "discover with profile none" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.discover(temp_project, profile=None);
        assert cfg is not None;
        assert cfg.active_profile == "";
    }
}

test "config files none default" {
    config_mod._config = None;
    cfg = JacConfig();
    assert cfg.config_files is None;
}

test "config files initialized on load" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.config_files is not None;
        assert len(cfg.config_files) == 1;
    }
}

test "merge initializes none config files" {
    config_mod._config = None;
    cfg = JacConfig();
    assert cfg.config_files is None;
    with TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "test.toml";
        toml_path.write_text("[run]\ncache = false\n");
        cfg.merge_from_toml_file(toml_path);
        assert cfg.config_files is not None;
        assert toml_path in cfg.config_files;
    }
}

test "merge format section" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[format]\noutfile = \"out.jac\"\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.format.outfile == "out.jac";
    }
}

test "merge dot section" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[dot]\ndepth = 3\ntraverse = true\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.dot.depth == 3;
        assert cfg.dot.traverse is True;
    }
}

test "merge cache section" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[cache]\nenabled = false\ndir = \".custom_cache\"\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.cache.enabled is False;
        assert cfg.cache.dir == ".custom_cache";
    }
}

test "merge environment section" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        cfg = JacConfig.load(temp_project / "jac.toml");
        overlay = temp_project / "overlay.toml";
        overlay.write_text("[environment]\ndefault_profile = \"dev\"\n");
        cfg.merge_from_toml_file(overlay);
        assert cfg.environment.default_profile == "dev";
    }
}

# ===========================================================================
# Integration tests for multi-file config layering (TestJactasticMultiProfile)
# ===========================================================================
test "load base only" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        cfg = JacConfig.load(temp_project / "jac.toml");
        assert cfg.project.name == "jactastic";
        assert cfg.serve.base_route_app == "app";
        assert cfg.serve.port == 8090;
        assert cfg.active_profile == "";
        assert len(cfg.config_files) == 1;
    }
}

test "discover no profile multi" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        cfg = JacConfig.discover(temp_project, profile=None);
        assert cfg is not None;
        assert cfg.project.name == "jactastic";
        assert cfg.active_profile == "";
    }
}

test "discover with prod profile multi" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        cfg = JacConfig.discover(temp_project, profile="prod");
        assert cfg is not None;
        assert cfg.active_profile == "prod";
        assert "byllm" in cfg.plugins;
        assert cfg.plugins["byllm"]["default_model"] == "gpt-4";
        assert cfg.plugins["client"]["minify"] is True;
        assert cfg.serve.port == 9000;
        assert cfg.run.cache is False;
    }
}

test "prod without local override" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        cfg = JacConfig.load(temp_project / "jac.toml");
        cfg.merge_from_toml_file(temp_project / "jac.prod.toml");
        assert cfg.serve.port == 80;
        assert cfg.serve.base_route_app == "app";
        assert cfg.plugins["client"]["minify"] is True;
    }
}

test "local overrides prod port" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        cfg = JacConfig.load(temp_project / "jac.toml");
        cfg.apply_profile_overlay("prod");
        assert cfg.serve.port == 9000;
    }
}

test "config files tracked in order" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        cfg = JacConfig.discover(temp_project, profile="prod");
        assert cfg is not None;
        assert len(cfg.config_files) == 3;
        assert cfg.config_files[0].name == "jac.toml";
        assert cfg.config_files[1].name == "jac.prod.toml";
        assert cfg.config_files[2].name == "jac.local.toml";
    }
}

test "base dependencies preserved" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        cfg = JacConfig.discover(temp_project, profile="prod");
        assert cfg is not None;
        assert "npm" in cfg.plugin_dependencies;
        assert cfg.plugin_dependencies["npm"]["jac-client-node"] == "1.0.4";
        assert "watchdog" in cfg.dev_dependencies;
    }
}

test "discover config files for prod" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        files = discover_config_files(temp_project, profile="prod");
        assert len(files) == 3;
        assert files[0] == temp_project / "jac.toml";
        assert files[1] == temp_project / "jac.prod.toml";
        assert files[2] == temp_project / "jac.local.toml";
    }
}

test "discover config files no profile multi" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        files = discover_config_files(temp_project);
        assert len(files) == 2;
        assert files[0] == temp_project / "jac.toml";
        assert files[1] == temp_project / "jac.local.toml";
    }
}

test "nonexistent profile still gets local" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        cfg = JacConfig.discover(temp_project, profile="staging");
        assert cfg is not None;
        assert cfg.active_profile == "staging";
        assert cfg.serve.port == 9000;
        assert cfg.run.cache is False;
    }
}

test "plugin deep merge across files" {
    config_mod._config = None;
    with TemporaryDirectory() as tmpdir {
        temp_project = make_temp_project(Path(tmpdir));
        write_multi_profile(temp_project);
        cfg = JacConfig.discover(temp_project, profile="prod");
        assert cfg is not None;
        assert "client" in cfg.plugins;
        assert cfg.plugins["client"]["minify"] is True;
        assert "byllm" in cfg.plugins;
        assert cfg.plugins["byllm"]["default_model"] == "gpt-4";
    }
}
