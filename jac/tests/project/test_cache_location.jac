"""Tests that user module JIR cache lives in the project-local .jac/ directory,
while compiler/bootstrap cache remains in the global cache."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.jac0core.jir { get_jir_cache_dir, get_module_cache_path }
import from jaclang.project.config { JacConfig, set_config }
import jaclang.project.config as config_mod;
import jaclang;


glob JAC_TOML_CONTENT = "[project]\nname = \"test-project\"\nversion = \"0.1.0\"\ndescription = \"A test project\"\nentry-point = \"main.jac\"\n",
     MAIN_JAC_CONTENT = "\"\"\"Test main file.\"\"\"\n\nwith entry {\n    print(\"Hello, World!\");\n}\n";


"""Create a temporary project directory with jac.toml and a .jac source file."""
def make_temp_project(temp_dir: Path) -> Path {
    project_dir = temp_dir / "test_project";
    project_dir.mkdir();
    jac_toml = project_dir / "jac.toml";
    jac_toml.write_text(JAC_TOML_CONTENT);
    main_jac = project_dir / "main.jac";
    main_jac.write_text(MAIN_JAC_CONTENT);
    return project_dir;
}


# ===========================================================================
# User module cache should be project-local
# ===========================================================================
test "user module cache path is under project local .jac directory" {
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            project_dir = make_temp_project(Path(tmpdir));
            source_file = str(project_dir / "main.jac");
            # Load project config so the system knows we're in a project
            cfg = JacConfig.load(project_dir / "jac.toml");
            set_config(cfg);
            # Get the cache path for a user module
            cache_path = get_module_cache_path(source_file);
            # The cache path should be under the project's .jac/cache/ directory,
            # NOT under the global cache
            global_cache = get_jir_cache_dir();
            project_cache = cfg.get_cache_dir();
            assert not str(cache_path).startswith(str(global_cache)) , (
                f"User module cache should NOT be in global cache.\n"
                f"  Got:      {cache_path}\n"
                f"  Global:   {global_cache}\n"
                f"  Expected: under {project_cache}"
            );
            assert str(cache_path).startswith(str(project_cache)) , (
                f"User module cache should be under project .jac/cache/ directory.\n"
                f"  Got:      {cache_path}\n"
                f"  Expected: under {project_cache}"
            );
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "bootstrap and compiler cache remains in global cache" {
    # The global JIR cache directory should be platform-appropriate
    global_cache = get_jir_cache_dir();
    home = Path.home();

    # Should NOT be under any project directory
    # Should be in a well-known platform location
    cache_str = str(global_cache);
    assert ".cache" in cache_str
    or "Library/Caches" in cache_str
    or "AppData" in cache_str , (
        f"Global cache should be in platform cache directory, got: {global_cache}"
    );
}

test "external packages use global cache even with active project" {
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            project_dir = make_temp_project(Path(tmpdir));
            cfg = JacConfig.load(project_dir / "jac.toml");
            set_config(cfg);
            # A file outside the project (e.g. jaclang internal or installed plugin)
            # should go to the global cache, not the project-local cache
            external_file = str(Path(jaclang.__file__).parent / "cli" / "cli.jac");
            cache_path = get_module_cache_path(external_file);
            global_cache = get_jir_cache_dir();
            project_cache = cfg.get_cache_dir();
            assert str(cache_path).startswith(str(global_cache)) , (
                f"External package modules should use global cache.\n"
                f"  Got:      {cache_path}\n"
                f"  Expected: under {global_cache}"
            );
            assert not str(cache_path).startswith(str(project_cache)) , (
                f"External package modules should NOT go in project cache.\n"
                f"  Got:      {cache_path}\n"
                f"  Project:  {project_cache}"
            );
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "user module cache uses .jac dir relative to source when no project context" {
    old_config = config_mod._config;
    try {
        # Set an invalid config to prevent auto-discovery from cwd
        config_mod._config = JacConfig();

        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            source_file = str(Path(tmpdir) / "standalone.jac");
            Path(source_file).write_text(MAIN_JAC_CONTENT);
            cache_path = get_module_cache_path(source_file);
            global_cache = get_jir_cache_dir();
            # Without a project context, cache should be in .jac/cache/
            # relative to the source file, NOT in the global cache
            expected_cache_dir = Path(tmpdir) / ".jac" / "cache";
            assert not str(cache_path).startswith(str(global_cache)) , (
                f"Without project context, cache should NOT be in global cache.\n"
                f"  Got:      {cache_path}\n"
                f"  Global:   {global_cache}\n"
                f"  Expected: under {expected_cache_dir}"
            );
            assert str(cache_path).startswith(str(expected_cache_dir)) , (
                f"Without project context, cache should be in .jac/cache/ next to source.\n"
                f"  Got:      {cache_path}\n"
                f"  Expected: under {expected_cache_dir}"
            );
        }
    } finally {
        config_mod._config = old_config;
    }
}
