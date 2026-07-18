"""Tests for client npm dependency injection gating in JacClientConfig.load().

Reading client config must NEVER mutate a project's jac.toml. For projects
that opted into the client via [client], the core runtime/dev deps
are injected into the *effective* dependency set at resolve time (visible to
the bundler and the npm provider plan) without being written back; jac.toml
only records what the user asked for.
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
# Non-client project: reading config must not mutate jac.toml or inject deps
# =============================================================================
"""A project without [client] is left untouched when config is read."""
test "non client project config read does not mutate jac toml" {
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Backend-only project: no [client] section.
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
# Client project: core deps are injected in-memory, never persisted
# =============================================================================
"""A [client] project sees core deps in its effective package config."""
test "client project gets dependencies injected on load" {
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Opted-in client project with no npm deps declared yet.
            (config_path, original_bytes) = _write_toml(
                temp_dir,
                '[project]\nname = "client-app"\nversion = "1.0.0"\n'
                'entry-point = "main.jac"\n\n[client]\n'
            );

            config = JacClientConfig(Path(temp_dir));
            pkg = config.get_package_config();

            deps = pkg.get("dependencies", {});
            dev_deps = pkg.get("devDependencies", {});
            # Core runtime + dev deps should be injected in-memory.
            assert "react" in deps , "react should be injected for a client project";
            assert "react-dom" in deps , "react-dom should be injected";
            assert "vite" in dev_deps , "vite should be injected as a dev dependency";
            assert "typescript" in dev_deps , "typescript should be injected as a dev dependency";
            # Injection happens at resolve time only: jac.toml stays untouched.
            assert config_path.read_bytes() == original_bytes , (
                "Injected deps must not be written back to jac.toml"
            );
        } finally {
            os.chdir(original_cwd);
        }
    }
}

# =============================================================================
# The npm provider plan mirrors the same injection with origins
# =============================================================================
"""NpmProvider.resolve reports manifest vs self-healed entries by origin."""
test "npm provider plan carries self-heal origins for client projects" {
    import from jaclang.project.config { JacConfig }
    import from jaclang.runtimelib.client.npm_provider { NpmProvider }

    with tempfile.TemporaryDirectory() as temp_dir {
        (config_path, _) = _write_toml(
            temp_dir,
            '[project]\nname = "client-app"\nversion = "1.0.0"\n'
            'entry-point = "main.jac"\n\n[dependencies.npm]\nlodash = "^4.17.0"\n\n'
            '[client]\n'
        );
        config = JacConfig.load(config_path);
        resolved = NpmProvider().resolve(config);
        by_name = {d.name: d for d in resolved};
        assert by_name["lodash"].origin == "manifest";
        assert by_name["react"].origin == "self-heal:client-core";
        assert by_name["vite"].origin == "self-heal:client-core";
        assert by_name["vite"].dev is True;
        # Backend-only project: manifest slice only, no self-heal entries.
        (backend_path, _) = _write_toml(
            temp_dir,
            '[project]\nname = "backend-app"\nversion = "1.0.0"\n'
            'entry-point = "main.jac"\n'
        );
        backend_config = JacConfig.load(backend_path);
        backend_resolved = NpmProvider().resolve(backend_config);
        assert backend_resolved == [];
    }
}

# =============================================================================
# Failed npm installs must not leave the manifest dirty
# =============================================================================
"""add_package/remove_package roll jac.toml back when the install step fails."""
test "npm provider rolls back the manifest when the install fails" {
    import from unittest.mock { patch }
    import from jaclang.project.config { JacConfig }
    import from jaclang.project.providers { InstallContext }
    import from jaclang.runtimelib.client.npm_provider { NpmProvider }

    with tempfile.TemporaryDirectory() as temp_dir {
        (config_path, original_bytes) = _write_toml(
            temp_dir,
            '[project]\nname = "client-app"\nversion = "1.0.0"\n'
            'entry-point = "main.jac"\n\n[dependencies.npm]\nlodash = "^4.17.0"\n'
        );
        provider = NpmProvider();
        ctx = InstallContext();
        # add: a bun/network failure must not record the new dep.
        config = JacConfig.load(config_path);
        raised = False;
        with patch(
            "jaclang.runtimelib.client.npm_provider.regenerate_and_install",
            side_effect=RuntimeError("bun unavailable")
        ) {
            try {
                provider.add_package(config, "leftpad", "^1.0.0", False, ctx);
            } except RuntimeError {
                raised = True;
            }
        }
        assert raised;
        assert "leftpad" not in config_path.read_text();
        assert config_path.read_bytes() == original_bytes;
        # add over an existing dep: the previous version spec is restored.
        config = JacConfig.load(config_path);
        with patch(
            "jaclang.runtimelib.client.npm_provider.regenerate_and_install",
            side_effect=RuntimeError("bun unavailable")
        ) {
            try {
                provider.add_package(config, "lodash", "^5.0.0", False, ctx);
            } except RuntimeError { }
        }
        assert 'lodash = "^4.17.0"' in config_path.read_text();
        # remove: a failed reinstall restores the removed dep.
        config = JacConfig.load(config_path);
        with patch(
            "jaclang.runtimelib.client.npm_provider.regenerate_and_install",
            side_effect=RuntimeError("bun unavailable")
        ) {
            try {
                provider.remove_package(config, "lodash", False, ctx);
            } except RuntimeError { }
        }
        assert 'lodash = "^4.17.0"' in config_path.read_text();
    }
}
