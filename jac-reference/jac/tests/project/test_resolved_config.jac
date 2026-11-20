"""All project consumers share the selected configuration and project scope."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.project.config {
    get_config,
    get_config_for_path,
    get_explicit_config,
    JacConfig,
    pin_project_scope,
    set_config
}

def project(base: Path) {
    (base / "jac.toml").write_text(
        '[project]\nname = "profiles"\n'
        '[serve]\nport = 8000\nhost = "base"\n'
        '[environment]\ndefault_profile = "production"\n'
    );
    (base / "jac.production.toml").write_text('[serve]\nport = 9000\n');
    (base / "jac.preview.toml").write_text('[serve]\nport = 9100\nhost = "preview"\n');
}

test "file and CLI readers share the environment-selected profile" {
    saved = get_explicit_config();
    set_config(None);
    try {
        with TemporaryDirectory() as directory, patch.dict(
            os.environ, {"JAC_PROFILE": "preview"}
        ) {
            base = Path(directory);
            project(base);
            file_config = get_config_for_path(base / "main.jac");
            assert file_config is not None;
            assert file_config.active_profile == "preview";
            assert file_config.serve.port == 9100;
            assert get_config(start_path=base) is file_config;
        }
    } finally {
        set_config(saved);
    }
}

test "default profiles and local overrides apply without a CLI dispatcher" {
    saved = get_explicit_config();
    set_config(None);
    try {
        with TemporaryDirectory() as directory, patch.dict(
            os.environ, {"JAC_PROFILE": ""}
        ) {
            base = Path(directory);
            project(base);
            (base / "jac.local.toml").write_text('[serve]\nport = 9200\n');
            config = get_config_for_path(base);
            assert config is not None;
            assert config.active_profile == "production";
            assert config.serve.port == 9200;
            assert len(config._layers) == 1;
            assert get_config_for_path(base) is config;
            assert len(config._layers) == 1;
        }
    } finally {
        set_config(saved);
    }
}

test "file configuration remains available without adopting it as the standalone scope" {
    saved = get_explicit_config();
    try {
        with TemporaryDirectory() as directory {
            base = Path(directory);
            project(base);
            pin_project_scope(None);
            assert get_config_for_path(base / "main.jac") is not None;
            assert get_config() is None;
        }
    } finally {
        set_config(saved);
    }
}

test "explicit profile changes replace the resolved config without retaining old overlays" {
    saved = get_explicit_config();
    set_config(None);
    try {
        with TemporaryDirectory() as directory, patch.dict(
            os.environ, {"JAC_PROFILE": "preview"}
        ) {
            base = Path(directory);
            project(base);
            preview = get_config(start_path=base);
            assert preview is not None and preview.serve.host == "preview";
            production = get_config(profile="production");
            assert production is not None;
            assert production.active_profile == "production";
            assert production.serve.port == 9000;
            assert production.serve.host == "base";
            assert production is get_config_for_path(base / "main.jac");
            assert production is get_config(profile="production");
            assert len(production._layers) == 1;
            assert preview.serve.host == "preview";
            unprofiled = get_config(profile="");
            assert unprofiled is not None and unprofiled.active_profile == "";
            assert unprofiled.serve.port == 8000;
            assert unprofiled.profile_override == "";
        }
    } finally {
        set_config(saved);
    }
}

test "fresh resolution preserves raw loading and picks each project's own default" {
    with TemporaryDirectory() as directory, patch.dict(
        os.environ, {"JAC_PROFILE": ""}
    ) {
        base = Path(directory);
        project(base);
        child = base / "child";
        child.mkdir();
        project(child);
        (child / "jac.toml").write_text(
            '[project]\nname = "child"\n' '[environment]\ndefault_profile = "preview"\n'
        );
        parent = JacConfig.resolve(base);
        assert parent is not None and parent.active_profile == "production";
        child_config = JacConfig.resolve(child, profile=parent.profile_override);
        assert child_config is not None and child_config.active_profile == "preview";
        assert JacConfig.load(base / "jac.toml").serve.port == 8000;
        local = JacConfig.resolve(child, profile="production");
        assert local is not None and local.active_profile == "production";
    }
}

test "refresh replaces the shared config and applies local settings once" {
    saved = get_explicit_config();
    set_config(None);
    try {
        with TemporaryDirectory() as directory, patch.dict(
            os.environ, {"JAC_PROFILE": ""}
        ) {
            base = Path(directory);
            project(base);
            before = get_config(start_path=base);
            (base / "jac.local.toml").write_text('[serve]\nport = 9200\n');
            after = get_config(start_path=base, force_discover=True);
            assert after is not None and after is not before;
            assert after.serve.port == 9200;
            assert after is get_config_for_path(base);
            assert len(after._layers) == 1;
        }
    } finally {
        set_config(saved);
    }
}

test "CLI argument defaults preserve environment selection and explicit profiles win" {
    import from jaclang.cli.command { CommandSpec }
    import from jaclang.cli.dispatch { _apply_profile }
    saved = get_explicit_config();
    set_config(None);
    try {
        with TemporaryDirectory() as directory, patch.dict(
            os.environ, {"JAC_PROFILE": "preview"}
        ) {
            base = Path(directory);
            project(base);
            config = get_config(start_path=base);
            meta = CommandSpec(name="run", help="run");
            args: dict[str, str] = {"profile": ""};
            _apply_profile(meta, args);
            assert get_config() is config;
            assert config is not None and config.active_profile == "preview";
            assert "profile" not in args;
            _apply_profile(meta, {"profile": "production"});
            config = get_config();
            assert config is not None and config.active_profile == "production";
        }
    } finally {
        set_config(saved);
    }
}

test "CLI discovery resolves the requested profile before loading other overlays" {
    import from jaclang.cli.dispatch { _discover_project_config }
    saved = get_explicit_config();
    set_config(None);
    try {
        with TemporaryDirectory() as directory, patch.dict(
            os.environ, {"JAC_PROFILE": "preview"}
        ) {
            base = Path(directory);
            project(base);
            (base / "jac.preview.toml").write_text("invalid toml");
            with patch("pathlib.Path.cwd", return_value=base) {
                _discover_project_config(profile="production");
            }
            config = get_config();
            assert config is not None and config.active_profile == "production";
        }
    } finally {
        set_config(saved);
    }
}
