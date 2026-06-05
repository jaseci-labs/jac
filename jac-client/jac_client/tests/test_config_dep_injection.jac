"""Tests for client npm dependency injection gating in JacClientConfig.load().

Reading client config must NEVER mutate a project's jac.toml unless that
project has explicitly opted into the client via a [plugins.client] section.
Previously, merely booting the API server (which reads client config) would
inject react/vite/etc. into a backend-only project's jac.toml.
"""

import os;
import tempfile;
import from pathlib { Path }

"""Write a jac.toml into temp_dir and return its path + original bytes."""
def _write_toml(temp_dir: str, content: str) -> tuple[Path, bytes] {
    config_path = Path(temp_dir) / "jac.toml";
    config_path.write_text(content);
    return (config_path, config_path.read_bytes());
}

# =============================================================================
# Non-client project: reading config must not mutate jac.toml
# =============================================================================
"""A project without [plugins.client] is left untouched when config is read."""
test "non client project config read does not mutate jac toml" {
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Backend-only project: no [plugins.client] section.
            (config_path, original_bytes) = _write_toml(
                temp_dir,
                '[project]\nname = "backend-app"\nversion = "1.0.0"\n'
                'entry-point = "main.jac"\n'
            );

            config = JacClientConfig(Path(temp_dir));
            # This is the exact read path the API server boot triggers.
            pkg = config.get_package_config();

            # jac.toml must be byte-for-byte unchanged.
            assert config_path.read_bytes() == original_bytes , (
                "Reading client config must not rewrite a non-client jac.toml"
            );
            # And no npm dependencies should have been injected.
            assert "dependencies.npm" not in config_path.read_text() , (
                "No [dependencies.npm] section should be injected for a "
                "non-client project"
            );
            assert pkg.get("dependencies", {}) == {} , (
                "Non-client project should report no runtime npm dependencies"
            );
            assert pkg.get("devDependencies", {}) == {} , (
                "Non-client project should report no dev npm dependencies"
            );
        } finally {
            os.chdir(original_cwd);
        }
    }
}

# =============================================================================
# Client project: self-healing dependency injection still works
# =============================================================================
"""A project with [plugins.client] still gets core deps injected on load."""
test "client project gets dependencies injected on load" {
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Opted-in client project with no npm deps declared yet.
            (config_path, _) = _write_toml(
                temp_dir,
                '[project]\nname = "client-app"\nversion = "1.0.0"\n'
                'entry-point = "main.jac"\n\n[plugins.client]\n'
            );

            config = JacClientConfig(Path(temp_dir));
            pkg = config.get_package_config();

            deps = pkg.get("dependencies", {});
            dev_deps = pkg.get("devDependencies", {});
            # Core runtime + dev deps should be self-healed in.
            assert "react" in deps , "react should be injected for a client project";
            assert "react-dom" in deps , "react-dom should be injected";
            assert "vite" in dev_deps , "vite should be injected as a dev dependency";
            assert "typescript" in dev_deps , "typescript should be injected as a dev dependency";
            # And persisted back to jac.toml.
            assert "dependencies.npm" in config_path.read_text() , (
                "Injected deps should be written to a client project's jac.toml"
            );
        } finally {
            os.chdir(original_cwd);
        }
    }
}
