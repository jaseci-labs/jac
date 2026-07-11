"""Tests for the built-in shadcn provider (component handler + registry)."""

import os;
import tempfile;
import from pathlib { Path }
import from importlib.resources { files }
import from jaclang.cli.shadcn.shadcn_handler { _read_shadcn_config }
import from jaclang.cli.shadcn.shadcn_handler { _resolve_peer_deps }
import from jaclang.cli.shadcn.shadcn_handler { _update_npm_deps }
import from jaclang.cli.shadcn.shadcn_handler { add_shadcn_components }
import from jaclang.cli.shadcn.shadcn_handler { remove_shadcn_components }
import from jaclang.cli.shadcn.shadcn_handler { load_registry }
import from jaclang.cli.shadcn.shadcn_handler { parse_style_css }
import from jaclang.cli.shadcn.shadcn_handler { resolve_component }
import from jaclang.cli.shadcn.shadcn_handler { resolve_single_component }


# The jac-shadcn template dir, resolved from the installed package (robust to
# the test file's own location).
glob _TEMPLATE_DIR: any = Path(str(files("jaclang.cli.shadcn"))) / "templates" / "jac-shadcn";


# Module-level config mocks. A dataclass declared inside a test function can't
# resolve its `__module__`, so these must live at module scope. `MockConfig`
# carries an explicit `_raw_data`; `MockConfigBare` omits it (to exercise the
# handler's `not hasattr(config, "_raw_data")` branch).
obj MockConfig {
    has project_root: any = None,
        _raw_data: any = None;
}

obj MockConfigBare {
    has project_root: any = None;
}


# ── Config Reader Tests ──
test "read shadcn config returns none when no project root" {
    result = _read_shadcn_config(MockConfigBare());
    assert result is None;
}

test "read shadcn config returns none when no raw data" {
    result = _read_shadcn_config(MockConfigBare(project_root="/tmp"));
    assert result is None;
}

test "read shadcn config returns section when present" {
    config = MockConfig(
        project_root="/tmp",
        _raw_data={"jac-shadcn": {"style": "nova", "registry": "http://localhost:8004"}}
    );
    result = _read_shadcn_config(config);
    assert result is not None;
    assert result["style"] == "nova";
    assert result["registry"] == "http://localhost:8004";
}

test "read shadcn config returns none when section missing" {
    config = MockConfig(project_root="/tmp", _raw_data={"dependencies": {"npm": {}}});
    result = _read_shadcn_config(config);
    assert result is None;
}


# ── Peer Dependency Resolution Tests ──
test "resolve peer deps with no dependencies" {
    registry_data = {
        "components": {"button": {"file": "button.cl.jac", "peerComponents": []}}
    };
    result = _resolve_peer_deps(["button"], registry_data, set());
    assert result == ["button"];
}

test "resolve peer deps adds missing peers" {
    registry_data = {
        "components": {
            "dialog": {"file": "dialog.cl.jac", "peerComponents": ["button"]},
            "button": {"file": "button.cl.jac", "peerComponents": []}
        }
    };
    result = _resolve_peer_deps(["dialog"], registry_data, set());
    assert "dialog" in result;
    assert "button" in result;
    assert len(result) == 2;
}

test "resolve peer deps skips existing components" {
    registry_data = {
        "components": {
            "dialog": {"file": "dialog.cl.jac", "peerComponents": ["button"]},
            "button": {"file": "button.cl.jac", "peerComponents": []}
        }
    };
    result = _resolve_peer_deps(["dialog"], registry_data, {"button"});
    assert result == ["dialog"];
}

test "resolve peer deps handles unknown component" {
    registry_data = {"components": {}};
    result = _resolve_peer_deps(["nonexistent"], registry_data, set());
    assert result == [];
}

test "resolve peer deps handles transitive deps" {
    registry_data = {
        "components": {
            "a": {"file": "a.cl.jac", "peerComponents": ["b"]},
            "b": {"file": "b.cl.jac", "peerComponents": ["c"]},
            "c": {"file": "c.cl.jac", "peerComponents": []}
        }
    };
    result = _resolve_peer_deps(["a"], registry_data, set());
    assert len(result) == 3;
    assert "a" in result;
    assert "b" in result;
    assert "c" in result;
}

test "resolve peer deps no duplicates" {
    registry_data = {
        "components": {
            "a": {"file": "a.cl.jac", "peerComponents": ["c"]},
            "b": {"file": "b.cl.jac", "peerComponents": ["c"]},
            "c": {"file": "c.cl.jac", "peerComponents": []}
        }
    };
    result = _resolve_peer_deps(["a", "b"], registry_data, set());
    assert result.count("c") == 1;
}


# ── Update NPM Deps Tests ──
test "update npm deps adds new dependency" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text('[dependencies.npm]\nclsx = "^2.1.1"\n');
        _update_npm_deps(MockConfig(project_root=tmpdir), {"tailwind-merge": "^3.5.0"});
        content = toml_path.read_text();
        assert "tailwind-merge" in content;
        assert "clsx" in content;
    }
}

test "update npm deps skips existing dependency" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        original = '[dependencies.npm]\nclsx = "^2.1.1"\n';
        toml_path.write_text(original);
        _update_npm_deps(MockConfig(project_root=tmpdir), {"clsx": "^2.1.1"});
        content = toml_path.read_text();
        assert content == original;
    }
}

test "update npm deps does nothing for empty deps" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        original = '[dependencies.npm]\n';
        toml_path.write_text(original);
        _update_npm_deps(MockConfig(project_root=tmpdir), {});
        content = toml_path.read_text();
        assert content == original;
    }
}


# ── Remove Components Tests ──
test "remove existing component" {
    with tempfile.TemporaryDirectory() as tmpdir {
        ui_dir = Path(tmpdir) / "components" / "ui";
        ui_dir.mkdir(parents=True);
        (ui_dir / "button.cl.jac").write_text("// button component");
        result = remove_shadcn_components(MockConfig(project_root=tmpdir), ["button"]);
        assert result == True;
        assert not (ui_dir / "button.cl.jac").exists();
    }
}

test "remove nonexistent component returns false" {
    with tempfile.TemporaryDirectory() as tmpdir {
        ui_dir = Path(tmpdir) / "components" / "ui";
        ui_dir.mkdir(parents=True);
        result = remove_shadcn_components(
            MockConfig(project_root=tmpdir), ["nonexistent"]
        );
        assert result == False;
    }
}

test "remove from missing ui dir returns false" {
    with tempfile.TemporaryDirectory() as tmpdir {
        result = remove_shadcn_components(MockConfig(project_root=tmpdir), ["button"]);
        assert result == False;
    }
}

test "remove multiple components" {
    with tempfile.TemporaryDirectory() as tmpdir {
        ui_dir = Path(tmpdir) / "components" / "ui";
        ui_dir.mkdir(parents=True);
        (ui_dir / "button.cl.jac").write_text("// button");
        (ui_dir / "card.cl.jac").write_text("// card");
        result = remove_shadcn_components(
            MockConfig(project_root=tmpdir), ["button", "card"]
        );
        assert result == True;
        assert not (ui_dir / "button.cl.jac").exists();
        assert not (ui_dir / "card.cl.jac").exists();
    }
}

test "remove resolves registry filename mismatch" {
    # `jac install --shadcn input-otp` installs as otp_input.cl.jac (registry file
    # `otp-input.cl.jac`, dashes → underscores); remove by the registry name
    # must resolve to that file, not input_otp.cl.jac.
    with tempfile.TemporaryDirectory() as tmpdir {
        ui_dir = Path(tmpdir) / "components" / "ui";
        ui_dir.mkdir(parents=True);
        (ui_dir / "otp_input.cl.jac").write_text("// otp input");
        result = remove_shadcn_components(
            MockConfig(project_root=tmpdir), ["input-otp"]
        );
        assert result == True;
        assert not (ui_dir / "otp_input.cl.jac").exists();
    }
}


# ── Jacpack Template Tests ──
test "jacpack template directory exists and loads" {
    import from jaclang.project.template_loader { load_template_from_directory }
    assert _TEMPLATE_DIR.exists();
    assert _TEMPLATE_DIR.is_dir();
    template = load_template_from_directory(_TEMPLATE_DIR);
    assert template is not None;
}

test "jacpack template has required fields" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template = load_template_from_directory(_TEMPLATE_DIR);
    assert template.name == "jac-shadcn";
    assert template.description != "";
    assert template.config is not None;
    assert len(template.files) > 0;
    assert len(template.directories) > 0;
}

test "jacpack template config has shadcn section" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template = load_template_from_directory(_TEMPLATE_DIR);
    config = template.config;
    assert "jac-shadcn" in config;
    shadcn = config["jac-shadcn"];
    assert "style" in shadcn;
    assert "registry" in shadcn;
    assert "baseColor" in shadcn;
    assert "theme" in shadcn;
}

test "jacpack template has npm dependencies" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template = load_template_from_directory(_TEMPLATE_DIR);
    npm = template.config["dependencies"]["npm"];
    assert "clsx" in npm;
    assert "tailwind-merge" in npm;
    assert "tw-animate-css" in npm;
}

test "jacpack template has required files" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template = load_template_from_directory(_TEMPLATE_DIR);
    assert "main.jac" in template.files;
    assert "styles/global.css" in template.files;
}


# ── Bundled Registry Tests ──
test "bundled registry loads with components" {
    data = load_registry();
    assert data is not None;
    assert "components" in data;
    assert isinstance(data["components"], dict);
    assert len(data["components"]) > 0;
    assert "button" in data["components"];
}

test "resolve single bundled component applies style" {
    data = resolve_single_component("button", "nova");
    assert data is not None;
    assert "error" not in data;
    assert data["name"] == "button";
    assert len(data["content"]) > 0;
    # cn-* tokens should have been resolved away in the delivered source.
    assert "cn-" not in data["content"];
}

test "resolve unknown component returns error" {
    data = resolve_single_component("nonexistent", "nova");
    assert "error" in data;
}

test "parse style css produces resolution map" {
    resolution_map = parse_style_css("nova");
    assert len(resolution_map) > 0;
    for key in resolution_map {
        assert key.startswith("cn-");
    }
}

test "resolve component replaces tokens longest first" {
    resolution_map = {"cn-foo": "A", "cn-foo-bar": "B"};
    result = resolve_component("x cn-foo-bar cn-foo y", resolution_map);
    assert result == "x B A y";
}

test "add components from bundled registry" {
    with tempfile.TemporaryDirectory() as tmpdir {
        # Set up a minimal project with jac.toml
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "test"\n\n[jac-shadcn]\nstyle = "nova"\n\n[dependencies.npm]\nclsx = "^2.1.1"\n'
        );
        config = MockConfig(
            project_root=tmpdir, _raw_data={"jac-shadcn": {"style": "nova"}}
        );
        result = add_shadcn_components(config, ["button"]);
        assert result == True;
        ui_dir = Path(tmpdir) / "components" / "ui";
        assert ui_dir.exists();
        # Check button file was created
        button_files = list(ui_dir.glob("button*.cl.jac"));
        assert len(button_files) > 0;
        # Check utils was created
        utils_path = Path(tmpdir) / "lib" / "utils.cl.jac";
        assert utils_path.exists();
    }
}

test "add components fails without shadcn config" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = MockConfig(project_root=tmpdir, _raw_data={});
        result = add_shadcn_components(config, ["button"]);
        assert result == False;
    }
}

test "add hyphenated component installs underscored file name" {
    # GUARD: a hyphen cannot appear in a Jac module name, so `install --shadcn
    # dropdown-menu` MUST write `dropdown_menu.cl.jac`. A hyphenated file is not
    # importable (unquoted = parse error, quoted = unresolved). Do not drop the
    # install-side dash-to-underscore conversion.
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "test"\n\n[jac-shadcn]\nstyle = "nova"\n\n[dependencies.npm]\nclsx = "^2.1.1"\n'
        );
        config = MockConfig(
            project_root=tmpdir, _raw_data={"jac-shadcn": {"style": "nova"}}
        );
        result = add_shadcn_components(config, ["dropdown-menu"]);
        assert result == True;
        ui_dir = Path(tmpdir) / "components" / "ui";
        assert (ui_dir / "dropdown_menu.cl.jac").exists();
        assert not (ui_dir / "dropdown-menu.cl.jac").exists();
        for installed in ui_dir.glob("*.cl.jac") {
            assert "-" not in installed.name;
        }
    }
}

test "add double-stem-mismatch component installs underscored file name" {
    # `input-otp` -> registry file `otp-input.cl.jac` -> installed `otp_input.cl.jac`.
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "test"\n\n[jac-shadcn]\nstyle = "nova"\n\n[dependencies.npm]\nclsx = "^2.1.1"\n'
        );
        config = MockConfig(
            project_root=tmpdir, _raw_data={"jac-shadcn": {"style": "nova"}}
        );
        result = add_shadcn_components(config, ["input-otp"]);
        assert result == True;
        ui_dir = Path(tmpdir) / "components" / "ui";
        assert (ui_dir / "otp_input.cl.jac").exists();
        assert not (ui_dir / "otp-input.cl.jac").exists();
    }
}

test "registry uses valid Jac module names throughout" {
    # GUARD: a hyphen is the minus operator and cannot be a Jac module name, so
    # no registry file may be hyphenated and no relative (dot-prefixed) import
    # may contain a hyphen - else the import cannot match its file.
    import from jaclang.cli.shadcn.shadcn_handler { _registry_dir }
    import re;
    ui_dir = _registry_dir() / "components" / "ui";
    for source_file in ui_dir.glob("*.cl.jac") {
        assert "-" not in source_file.name;
        for spec in re.findall(r'import from "(\.[^"]*)"', source_file.read_text()) {
            assert "-" not in spec;
        }
    }
}

test "component with a peer resolves to a matching underscored import" {
    # combobox imports .input_group and declares input-group as a peer, so the
    # peer installs and the import matches the installed file name.
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "test"\n\n[jac-shadcn]\nstyle = "nova"\n\n[dependencies.npm]\nclsx = "^2.1.1"\n'
        );
        config = MockConfig(
            project_root=tmpdir, _raw_data={"jac-shadcn": {"style": "nova"}}
        );
        result = add_shadcn_components(config, ["combobox"]);
        assert result == True;
        ui_dir = Path(tmpdir) / "components" / "ui";
        assert (ui_dir / "input_group.cl.jac").exists();
        combobox_src = (ui_dir / "combobox.cl.jac").read_text();
        assert 'import from ".input_group"' in combobox_src;
        assert 'import from ".input-group"' not in combobox_src;
    }
}
