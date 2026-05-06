"""Tests for jac-shadcn plugin."""

import os;
import tempfile;
import from pathlib { Path }
import from jac_shadcn.shadcn_handler { _read_shadcn_config }
import from jac_shadcn.shadcn_handler { _resolve_peer_deps }
import from jac_shadcn.shadcn_handler { _update_npm_deps }
import from jac_shadcn.shadcn_handler { add_shadcn_components }
import from jac_shadcn.shadcn_handler { remove_shadcn_components }
import from jac_shadcn.shadcn_handler { _fetch_json }
import from jac_shadcn.plugin { JacShadcnPlugin }


# ── Config Reader Tests ──
test "read shadcn config returns none when no project root" {
    obj MockConfig {
        has project_root: None = None;
    }
    result = _read_shadcn_config(MockConfig());
    assert result is None;
}

test "read shadcn config returns none when no raw data" {
    obj MockConfig {
        has project_root: str = "/tmp";
    }
    result = _read_shadcn_config(MockConfig());
    assert result is None;
}

test "read shadcn config returns section when present" {
    obj MockConfig {
        has project_root: str = "/tmp",
            _raw_data: dict = {
                "jac-shadcn": {"style": "nova", "registry": "http://localhost:8004"}
            };
    }
    result = _read_shadcn_config(MockConfig());
    assert result is not None;
    assert result["style"] == "nova";
    assert result["registry"] == "http://localhost:8004";
}

test "read shadcn config returns none when section missing" {
    obj MockConfig {
        has project_root: str = "/tmp",
            _raw_data: dict = {"dependencies": {"npm": {}}};
    }
    result = _read_shadcn_config(MockConfig());
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
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        _update_npm_deps(config, {"tailwind-merge": "^3.5.0"});
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
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        _update_npm_deps(config, {"clsx": "^2.1.1"});
        content = toml_path.read_text();
        assert content == original;
    }
}

test "update npm deps does nothing for empty deps" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        original = '[dependencies.npm]\n';
        toml_path.write_text(original);
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        _update_npm_deps(config, {});
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
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        result = remove_shadcn_components(config, ["button"]);
        assert result == True;
        assert not (ui_dir / "button.cl.jac").exists();
    }
}

test "remove nonexistent component returns false" {
    with tempfile.TemporaryDirectory() as tmpdir {
        ui_dir = Path(tmpdir) / "components" / "ui";
        ui_dir.mkdir(parents=True);
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        result = remove_shadcn_components(config, ["nonexistent"]);
        assert result == False;
    }
}

test "remove from missing ui dir returns false" {
    with tempfile.TemporaryDirectory() as tmpdir {
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        result = remove_shadcn_components(config, ["button"]);
        assert result == False;
    }
}

test "remove multiple components" {
    with tempfile.TemporaryDirectory() as tmpdir {
        ui_dir = Path(tmpdir) / "components" / "ui";
        ui_dir.mkdir(parents=True);
        (ui_dir / "button.cl.jac").write_text("// button");
        (ui_dir / "card.cl.jac").write_text("// card");
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        result = remove_shadcn_components(config, ["button", "card"]);
        assert result == True;
        assert not (ui_dir / "button.cl.jac").exists();
        assert not (ui_dir / "card.cl.jac").exists();
    }
}


# ── Jacpack Template Tests ──
test "jacpack template directory exists and loads" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "jac-shadcn";
    assert template_dir.exists();
    assert template_dir.is_dir();
    template = load_template_from_directory(template_dir);
    assert template is not None;
}

test "jacpack template has required fields" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "jac-shadcn";
    template = load_template_from_directory(template_dir);
    assert template.name == "jac-shadcn";
    assert template.description != "";
    assert template.config is not None;
    assert len(template.files) > 0;
    assert len(template.directories) > 0;
}

test "jacpack template config has shadcn section" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "jac-shadcn";
    template = load_template_from_directory(template_dir);
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
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "jac-shadcn";
    template = load_template_from_directory(template_dir);
    npm = template.config["dependencies"]["npm"];
    assert "clsx" in npm;
    assert "tailwind-merge" in npm;
    assert "tw-animate-css" in npm;
}

test "jacpack template has required files" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "jac-shadcn";
    template = load_template_from_directory(template_dir);
    assert "main.jac" in template.files;
    assert "global.css" in template.files;
    assert "lib/utils.cl.jac" in template.files;
}


# ── Live Registry Integration Tests ──
test "fetch registry index from live server" {
    data = _fetch_json("https://jac-shadcn.jaseci.org/registry");
    assert data is not None;
    assert "components" in data;
    assert isinstance(data["components"], dict);
    assert len(data["components"]) > 0;
}

test "fetch single component from live server" {
    data = _fetch_json("https://jac-shadcn.jaseci.org/component/button?style=nova");
    assert data is not None;
    assert "name" in data;
    assert "content" in data;
    assert len(data["content"]) > 0;
}

test "add components from live registry" {
    with tempfile.TemporaryDirectory() as tmpdir {
        # Set up a minimal project with jac.toml
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "test"\n\n[jac-shadcn]\nstyle = "nova"\nregistry = "https://jac-shadcn.jaseci.org"\n\n[dependencies.npm]\nclsx = "^2.1.1"\n'
        );
        obj MockConfig {
            has project_root: str,
                _raw_data: dict;
        }
        config = MockConfig(
            project_root=tmpdir,
            _raw_data={
                "jac-shadcn": {
                    "style": "nova",
                    "registry": "https://jac-shadcn.jaseci.org"
                }
            }
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
        obj MockConfig {
            has project_root: str,
                _raw_data: dict;
        }
        config = MockConfig(project_root=tmpdir, _raw_data={});
        result = add_shadcn_components(config, ["button"]);
        assert result == False;
    }
}
