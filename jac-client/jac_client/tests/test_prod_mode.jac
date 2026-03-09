"""Tests for --prod flag and production mode build settings.

These tests validate the changes introduced for production builds:
1. PROD_MODE_ENV_VAR constant definition and usage (no magic strings)
2. Env var cleanup (try/finally) in WebTarget.build()
3. CLI --prod flag for start and build commands
4. Vite config sourcemap/minify settings based on prod mode
5. Import consistency across files
"""

import os;
import re;
import from pathlib { Path }

# =============================================================================
# Shared path constants (avoid repeating long path constructions)
# =============================================================================
glob _plugin_src = Path(__file__).parent.parent / "plugin" / "src",
     _plugin_dir = Path(__file__).parent.parent / "plugin",
     _vite_bundler_jac_path = _plugin_src / "vite_bundler.jac",
     _vite_bundler_impl_path = _plugin_src / "impl" / "vite_bundler.impl.jac",
     _web_target_impl_path = _plugin_src / "targets" / "impl" / "web_target.impl.jac",
     _client_jac_path = _plugin_dir / "client.jac",
     _client_impl_path = _plugin_dir / "impl" / "client.impl.jac",
     _cli_jac_path = _plugin_dir / "cli.jac",
     _execution_jac_path = Path(__file__).parent.parent.parent.parent.parent / "jac" / "jaclang" / "cli" / "commands" / "execution.jac",
     _execution_impl_path = Path(__file__).parent.parent.parent.parent.parent / "jac" / "jaclang" / "cli" / "commands" / "impl" / "execution.impl.jac";

# =============================================================================
# Test: PROD_MODE_ENV_VAR constant definition
# =============================================================================
test "prod mode env var constant defined in vite bundler" {
    print("[DEBUG] Starting test_prod_mode_env_var_constant_defined_in_vite_bundler");

    assert _vite_bundler_jac_path.exists() , (
        f"vite_bundler.jac not found at {_vite_bundler_jac_path}"
    );

    content = _vite_bundler_jac_path.read_text();

    assert "PROD_MODE_ENV_VAR" in content , (
        "vite_bundler.jac should define PROD_MODE_ENV_VAR"
    );
    assert '"JAC_CLIENT_PROD_MODE"' in content , (
        "PROD_MODE_ENV_VAR should equal 'JAC_CLIENT_PROD_MODE'"
    );
    # Verify it's defined alongside other env var constants
    assert "API_BASE_URL_ENV_VAR" in content , (
        "PROD_MODE_ENV_VAR should be defined alongside API_BASE_URL_ENV_VAR"
    );

    print("[DEBUG] PROD_MODE_ENV_VAR constant definition verified!");
}

test "prod mode env var string appears only once" {
    print("[DEBUG] Starting test_prod_mode_env_var_string_appears_only_once");

    content = _vite_bundler_jac_path.read_text();

    # The magic string should appear exactly once - in the constant definition
    count = content.count('"JAC_CLIENT_PROD_MODE"');
    assert count == 1 , (
        f"'JAC_CLIENT_PROD_MODE' string should appear exactly once "
        f"(constant definition), found {count} occurrence(s)"
    );

    print("[DEBUG] Magic string count verification passed!");
}

# =============================================================================
# Test: No magic strings in impl files
# =============================================================================
test "no magic string in web target impl" {
    print("[DEBUG] Starting test_no_magic_string_in_web_target_impl");

    assert _web_target_impl_path.exists() , (
        f"web_target.impl.jac not found at {_web_target_impl_path}"
    );

    content = _web_target_impl_path.read_text();

    assert '"JAC_CLIENT_PROD_MODE"' not in content , (
        "web_target.impl.jac should use PROD_MODE_ENV_VAR constant, "
        "not the string literal"
    );
    assert "PROD_MODE_ENV_VAR" in content , (
        "web_target.impl.jac should use the PROD_MODE_ENV_VAR constant"
    );

    print("[DEBUG] web_target.impl.jac magic string elimination verified!");
}

test "no magic string in client impl" {
    print("[DEBUG] Starting test_no_magic_string_in_client_impl");

    assert _client_impl_path.exists() , (
        f"client.impl.jac not found at {_client_impl_path}"
    );

    content = _client_impl_path.read_text();

    assert '"JAC_CLIENT_PROD_MODE"' not in content , (
        "client.impl.jac should use PROD_MODE_ENV_VAR constant, "
        "not the string literal"
    );
    assert "PROD_MODE_ENV_VAR" in content , (
        "client.impl.jac should use the PROD_MODE_ENV_VAR constant"
    );

    print("[DEBUG] client.impl.jac magic string elimination verified!");
}

test "no magic string in vite bundler impl" {
    print("[DEBUG] Starting test_no_magic_string_in_vite_bundler_impl");

    assert _vite_bundler_impl_path.exists() , (
        f"vite_bundler.impl.jac not found at {_vite_bundler_impl_path}"
    );

    content = _vite_bundler_impl_path.read_text();

    assert '"JAC_CLIENT_PROD_MODE"' not in content , (
        "vite_bundler.impl.jac should use PROD_MODE_ENV_VAR constant, "
        "not the string literal"
    );
    assert "PROD_MODE_ENV_VAR" in content , (
        "vite_bundler.impl.jac should use the PROD_MODE_ENV_VAR constant"
    );

    print("[DEBUG] vite_bundler.impl.jac magic string elimination verified!");
}

# =============================================================================
# Test: Import consistency
# =============================================================================
test "web target imports prod mode env var" {
    print("[DEBUG] Starting test_web_target_imports_prod_mode_env_var");

    content = _web_target_impl_path.read_text();

    assert (
        "import from jac_client.plugin.src.vite_bundler { ViteBundler, PROD_MODE_ENV_VAR }" in content
        or "PROD_MODE_ENV_VAR }" in content
    ) , ("web_target.impl.jac should import PROD_MODE_ENV_VAR from vite_bundler");

    print("[DEBUG] web_target.impl.jac import verification passed!");
}

test "client jac imports prod mode env var" {
    print("[DEBUG] Starting test_client_jac_imports_prod_mode_env_var");

    content = _client_jac_path.read_text();

    assert "PROD_MODE_ENV_VAR" in content , (
        "client.jac should import PROD_MODE_ENV_VAR"
    );
    assert (
        "import from .src.vite_bundler { ViteBundler, PROD_MODE_ENV_VAR }" in content
        or "PROD_MODE_ENV_VAR }" in content
    ) , ("client.jac should import PROD_MODE_ENV_VAR from vite_bundler");

    print("[DEBUG] client.jac import verification passed!");
}

# =============================================================================
# Test: Env var cleanup (try/finally) in WebTarget.build
# =============================================================================
test "env var cleanup pattern in web target build" {
    print("[DEBUG] Starting test_env_var_cleanup_pattern_in_web_target_build");

    content = _web_target_impl_path.read_text();

    # Find the build method
    build_start = content.index("impl WebTarget.build");
    # Find the next impl or function to isolate the build method
    next_section = content.find("\n\"\"\"", build_start + 50);
    if next_section == -1 {
        next_section = len(content);
    }
    build_section = content[build_start:next_section];

    assert "try {" in build_section , ("WebTarget.build() should use try block");
    assert "} finally {" in build_section , (
        "WebTarget.build() should use finally block for env var cleanup"
    );
    assert "os.environ.pop(PROD_MODE_ENV_VAR, None)" in build_section , (
        "WebTarget.build() should clean up env var in finally block"
    );

    print("[DEBUG] WebTarget.build() env var cleanup verification passed!");
}

test "env var set only when prod true" {
    print("[DEBUG] Starting test_env_var_set_only_when_prod_true");

    content = _web_target_impl_path.read_text();

    # Find the build method
    build_start = content.index("impl WebTarget.build");
    next_section = content.find("\n\"\"\"", build_start + 50);
    if next_section == -1 {
        next_section = len(content);
    }
    build_section = content[build_start:next_section];

    # Should set env var when prod is true
    assert 'if prod {' in build_section , (
        "WebTarget.build() should check if prod is true before setting env var"
    );
    assert 'os.environ[PROD_MODE_ENV_VAR] = "1"' in build_section , (
        "WebTarget.build() should set PROD_MODE_ENV_VAR to '1' when prod is true"
    );

    # Should NOT have an else clause that pops before the operation
    # (the pop should only be in finally)
    env_set_pos = build_section.index('os.environ[PROD_MODE_ENV_VAR] = "1"');
    try_pos = build_section.index("try {");
    # The env var should be set before the try block
    assert env_set_pos < try_pos , ("Env var should be set before the try block");

    print("[DEBUG] Env var set condition verification passed!");
}

# =============================================================================
# Test: CLI --prod flag
# =============================================================================
test "start command has prod flag" {
    print("[DEBUG] Starting test_start_command_has_prod_flag");

    # Check if execution.jac exists (core jac CLI)
    if not _execution_jac_path.exists() {
        print(f"[DEBUG] Skipping - execution.jac not found at {_execution_jac_path}");
        return;
    }

    content = _execution_jac_path.read_text();

    # Find the start command definition
    assert '"start"' in content or "'start'" in content , (
        "execution.jac should define the start command"
    );
    assert '"prod"' in content or "'prod'" in content , (
        "start command should have a prod argument"
    );
    # Check for the help text
    assert "Production mode" in content or "no HMR" in content , (
        "prod flag should have descriptive help text"
    );

    print("[DEBUG] start command --prod flag verification passed!");
}

test "build command has prod flag" {
    print("[DEBUG] Starting test_build_command_has_prod_flag");

    content = _cli_jac_path.read_text();

    # Find the build command registration
    assert 'name="build"' in content , ("cli.jac should register the build command");
    # Check for prod arg
    assert '"prod"' in content , ("build command should have a prod argument");
    # Check for the help text
    assert "Production build" in content or "minified" in content , (
        "prod flag should have descriptive help text"
    );

    print("[DEBUG] build command --prod flag verification passed!");
}

test "prod flag uses short flag P" {
    print("[DEBUG] Starting test_prod_flag_uses_short_flag_P");

    # Check build command
    cli_content = _cli_jac_path.read_text();
    assert 'short="P"' in cli_content , (
        "build command prod flag should use -P as short flag"
    );

    # Check start command if available
    if _execution_jac_path.exists() {
        exec_content = _execution_jac_path.read_text();
        assert 'short="P"' in exec_content , (
            "start command prod flag should use -P as short flag"
        );
    }

    print("[DEBUG] Short flag -P verification passed!");
}

# =============================================================================
# Test: Vite config sourcemap/minify settings
# =============================================================================
test "vite bundler checks prod mode env var" {
    print("[DEBUG] Starting test_vite_bundler_checks_prod_mode_env_var");

    content = _vite_bundler_impl_path.read_text();

    # Find the _generate_vite_config_content method
    assert "impl ViteBundler._generate_vite_config_content" in content , (
        "vite_bundler.impl.jac should implement _generate_vite_config_content"
    );

    # Should read the env var
    assert 'os.environ.get(PROD_MODE_ENV_VAR' in content , (
        "_generate_vite_config_content should read PROD_MODE_ENV_VAR"
    );

    print("[DEBUG] Vite bundler env var check verification passed!");
}

test "vite config has conditional sourcemap" {
    print("[DEBUG] Starting test_vite_config_has_conditional_sourcemap");

    content = _vite_bundler_impl_path.read_text();

    # Find config generation section
    assert "sourcemap_setting" in content , (
        "Vite config should have sourcemap_setting variable"
    );
    # Should be conditional on prod_mode
    assert '"false" if prod_mode else "true"' in content , (
        "sourcemap should be false in prod mode, true otherwise"
    );

    print("[DEBUG] Conditional sourcemap verification passed!");
}

test "vite config has conditional minify" {
    print("[DEBUG] Starting test_vite_config_has_conditional_minify");

    content = _vite_bundler_impl_path.read_text();

    # Find config generation section
    assert "minify_setting" in content , (
        "Vite config should have minify_setting variable"
    );
    # Should be conditional on prod_mode
    assert "esbuild" in content , ("minify should use esbuild in prod mode");
    assert "if prod_mode else" in content , (
        "minify should be conditional on prod_mode"
    );

    print("[DEBUG] Conditional minify verification passed!");
}

# =============================================================================
# Test: Execution impl handles prod flag
# =============================================================================
test "execution impl has prod override logic" {
    print("[DEBUG] Starting test_execution_impl_has_prod_override_logic");

    if not _execution_impl_path.exists() {
        print(
            f"[DEBUG] Skipping - execution.impl.jac not found at {_execution_impl_path}"
        );
        return;
    }

    content = _execution_impl_path.read_text();

    # Find the start implementation
    assert "impl start(" in content , (
        "execution.impl.jac should implement start command"
    );

    # Should handle prod overriding dev
    assert "if prod" in content , ("start impl should check prod flag");
    assert "dev = False" in content , ("prod=True should set dev=False");

    print("[DEBUG] Prod override logic verification passed!");
}

# =============================================================================
# Test: Client bundle builder uses prod mode
# =============================================================================
test "client bundle builder reads prod mode" {
    print("[DEBUG] Starting test_client_bundle_builder_reads_prod_mode");

    content = _client_impl_path.read_text();

    # Find get_client_bundle_builder implementation
    assert "impl JacClient.get_client_bundle_builder" in content , (
        "client.impl.jac should implement get_client_bundle_builder"
    );

    # Should read prod mode and pass to builder
    assert "prod_mode = os.environ.get(PROD_MODE_ENV_VAR" in content , (
        "get_client_bundle_builder should read PROD_MODE_ENV_VAR"
    );
    assert "vite_minify=prod_mode" in content , (
        "get_client_bundle_builder should pass prod_mode to vite_minify parameter"
    );

    print("[DEBUG] Client bundle builder prod mode verification passed!");
}

# =============================================================================
# Test: Default values
# =============================================================================
test "dev defaults to true in start command" {
    print("[DEBUG] Starting test_dev_defaults_to_true_in_start_command");

    if not _execution_jac_path.exists() {
        print(f"[DEBUG] Skipping - execution.jac not found at {_execution_jac_path}");
        return;
    }

    content = _execution_jac_path.read_text();

    # Find the dev arg definition
    # It should have default=True
    assert 'dev",' in content or '"dev"' in content , (
        "start command should have dev argument"
    );
    # Look for the default value
    assert "default=True" in content , ("dev argument should default to True");

    print("[DEBUG] Dev default value verification passed!");
}

test "prod defaults to false in start command" {
    print("[DEBUG] Starting test_prod_defaults_to_false_in_start_command");

    if not _execution_jac_path.exists() {
        print(f"[DEBUG] Skipping - execution.jac not found at {_execution_jac_path}");
        return;
    }

    content = _execution_jac_path.read_text();

    # Find the prod arg for start command - look for the pattern in start command context
    # The prod arg should have default=False
    start_idx = content.index('name="start"');
    next_cmd = content.find('@registry.command', start_idx + 1);
    if next_cmd == -1 {
        next_cmd = len(content);
    }
    start_section = content[start_idx:next_cmd];

    assert '"prod"' in start_section , ("start command should have prod argument");
    # Check that somewhere in the prod arg definition, default=False
    assert "default=False" in start_section , ("prod argument should default to False");

    print("[DEBUG] Prod default value verification passed!");
}

test "prod defaults to false in build command" {
    print("[DEBUG] Starting test_prod_defaults_to_false_in_build_command");

    content = _cli_jac_path.read_text();

    # Find the build command section
    build_idx = content.index('name="build"');
    next_cmd = content.find('@registry.command', build_idx + 1);
    if next_cmd == -1 {
        next_cmd = content.find('def build(', build_idx + 1);
    }
    if next_cmd == -1 {
        next_cmd = len(content);
    }
    build_section = content[build_idx:next_cmd];

    assert '"prod"' in build_section , ("build command should have prod argument");
    assert "default=False" in build_section , (
        "prod argument should default to False in build command"
    );

    print("[DEBUG] Build prod default value verification passed!");
}
