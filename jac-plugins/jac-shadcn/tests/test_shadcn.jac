"""Tests for jac-shadcn plugin."""

import os;
import tempfile;
import tomlkit;
import from pathlib { Path }
import from unittest.mock { patch }

import jac_shadcn.shadcn_handler as handler;
import from jac_shadcn.shadcn_handler { _read_shadcn_config }
import from jac_shadcn.shadcn_handler { _resolve_peer_deps }
import from jac_shadcn.shadcn_handler { _update_npm_deps }
import from jac_shadcn.shadcn_handler { add_shadcn_components }
import from jac_shadcn.shadcn_handler { remove_shadcn_components }
import from jac_shadcn.shadcn_handler { _fetch_json }
import from jac_shadcn.lockfile { record_install, load_lockfile }
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


# ── tomlkit-based npm dep patching ──
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
        _update_npm_deps(config, {"clsx": "^9.9.9"});
        # Existing pin is preserved; we don't clobber user choices.
        doc = tomlkit.parse(toml_path.read_text());
        assert doc["dependencies"]["npm"]["clsx"] == "^2.1.1";
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

test "tomlkit patch preserves comments and surrounding sections" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '# top-level comment\n' + '[project]\nname = "demo"\n\n' + '[dependencies.npm]\n' + '# pinned for legal review\n' + 'clsx = "^2.1.1"\n\n' + '[jacpack.options]\ndirectories = ["components"]\n'
        );
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        _update_npm_deps(config, {"radix-ui": "^1.0.0"});
        content = toml_path.read_text();
        assert "# top-level comment" in content;
        assert "# pinned for legal review" in content;
        assert "[jacpack.options]" in content;
        assert "radix-ui" in content;
    }
}

test "tomlkit handles npm key with @scope/name format" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text('[dependencies.npm]\n');
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        _update_npm_deps(config, {"@radix-ui/react-dialog": "^1.0.0"});
        doc = tomlkit.parse(toml_path.read_text());
        assert "@radix-ui/react-dialog" in doc["dependencies"]["npm"];
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

test "remove auto-prunes deps owned only by the removed component" {
    with tempfile.TemporaryDirectory() as tmpdir {
        ui_dir = Path(tmpdir) / "components" / "ui";
        ui_dir.mkdir(parents=True);
        (ui_dir / "button.cl.jac").write_text("// button");
        (ui_dir / "card.cl.jac").write_text("// card");
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[dependencies.npm]\n' + 'class-variance-authority = "^0.7.0"\n' + 'radix-ui = "^1.0.0"\n'
        );
        record_install(
            Path(tmpdir), "button", "1.0.0", ["class-variance-authority", "radix-ui"]
        );
        record_install(Path(tmpdir), "card", "1.0.0", ["class-variance-authority"]);
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        result = remove_shadcn_components(config, ["button"]);
        assert result == True;
        doc = tomlkit.parse(toml_path.read_text());
        # radix-ui was only held by button -> pruned
        assert "radix-ui" not in doc["dependencies"]["npm"];
        # class-variance-authority still held by card -> kept
        assert "class-variance-authority" in doc["dependencies"]["npm"];
        lock = load_lockfile(Path(tmpdir));
        assert "button" not in lock["components"];
        assert "card" in lock["components"];
    }
}

test "remove --keep-deps leaves npm deps untouched" {
    with tempfile.TemporaryDirectory() as tmpdir {
        ui_dir = Path(tmpdir) / "components" / "ui";
        ui_dir.mkdir(parents=True);
        (ui_dir / "button.cl.jac").write_text("// button");
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text('[dependencies.npm]\n' + 'radix-ui = "^1.0.0"\n');
        record_install(Path(tmpdir), "button", "1.0.0", ["radix-ui"]);
        obj MockConfig {
            has project_root: str;
        }
        config = MockConfig(project_root=tmpdir);
        result = remove_shadcn_components(config, ["button"], keep_deps=True);
        assert result == True;
        doc = tomlkit.parse(toml_path.read_text());
        assert "radix-ui" in doc["dependencies"]["npm"];
        lock = load_lockfile(Path(tmpdir));
        assert "button" not in lock["components"];
    }
}


# ── add_shadcn_components with mocked registry ──
def _mock_registry() -> dict {
    return {
        "components": {
            "button": {
                "file": "button.cl.jac",
                "npmDeps": ["class-variance-authority"],
                "peerComponents": []
            },
            "card": {
                "file": "card.cl.jac",
                "npmDeps": ["class-variance-authority"],
                "peerComponents": []
            }
        },
        "sharedDeps": {}
    };
}


def _mock_component(name: str, version: str = "1.0.0") -> dict {
    return {
        "name": name,
        "file": name + ".cl.jac",
        "content": "// " + name + " component @ " + version + "\n",
        "npmDeps": ["class-variance-authority"],
        "version": version
    };
}


test "add records install in lockfile with version from response" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "demo"\n\n' + '[jac-shadcn]\nstyle = "nova"\nregistry = "https://example.org"\n'
        );
        obj MockConfig {
            has project_root: str,
                _raw_data: dict;
        }
        config = MockConfig(
            project_root=tmpdir,
            _raw_data={
                "jac-shadcn": {"style": "nova", "registry": "https://example.org"}
            }
        );
        def fake_fetch(url: str) -> dict {
            if url.endswith("/registry") {
                return _mock_registry();
            }
            if "/component/button" in url {
                return _mock_component("button", "1.2.3");
            }
            return None;
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            result = add_shadcn_components(config, ["button"]);
        }
        assert result == True;
        lock = load_lockfile(Path(tmpdir));
        assert lock["components"]["button"]["version"] == "1.2.3";
        assert "class-variance-authority" in lock["components"]["button"]["npm_deps"];
    }
}


test "add rejects component when registry returns traversal filename" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "demo"\n\n' + '[jac-shadcn]\nstyle = "nova"\nregistry = "https://example.org"\n'
        );
        obj MockConfig {
            has project_root: str,
                _raw_data: dict;
        }
        config = MockConfig(
            project_root=tmpdir,
            _raw_data={
                "jac-shadcn": {"style": "nova", "registry": "https://example.org"}
            }
        );
        def fake_fetch(url: str) -> dict {
            if url.endswith("/registry") {
                return _mock_registry();
            }
            return {
                "name": "button",
                "file": "../../escape.cl.jac",
                "content": "pwned",
                "npmDeps": [],
                "version": "1.0.0"
            };
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            add_shadcn_components(config, ["button"]);
        }
        # Nothing landed outside ui_dir
        ui_dir = Path(tmpdir) / "components" / "ui";
        for f in ui_dir.rglob("*") {
            assert "escape" not in str(f);
        }
        # Lockfile must not record a malicious install
        lock = load_lockfile(Path(tmpdir));
        assert "button" not in lock.get("components", {});
    }
}


test "add parses name@version and forwards version query param" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "demo"\n\n' + '[jac-shadcn]\nstyle = "nova"\nregistry = "https://example.org"\n'
        );
        obj MockConfig {
            has project_root: str,
                _raw_data: dict;
        }
        config = MockConfig(
            project_root=tmpdir,
            _raw_data={
                "jac-shadcn": {"style": "nova", "registry": "https://example.org"}
            }
        );
        seen_urls: list = [];
        def fake_fetch(url: str) -> dict {
            seen_urls.append(url);
            if url.endswith("/registry") {
                return _mock_registry();
            }
            return _mock_component("button", "1.5.0");
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            add_shadcn_components(config, ["button@1.5.0"]);
        }
        assert any("version=1.5.0" in u for u in seen_urls);
        lock = load_lockfile(Path(tmpdir));
        assert lock["components"]["button"]["version"] == "1.5.0";
    }
}


# ── Jacpack Template Tests ──
test "jacpack template directory exists and loads" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "shadcn";
    assert template_dir.exists();
    assert template_dir.is_dir();
    template = load_template_from_directory(template_dir);
    assert template is not None;
}

test "jacpack template has required fields" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "shadcn";
    template = load_template_from_directory(template_dir);
    assert template.name == "shadcn";
    assert template.description != "";
    assert template.config is not None;
    assert len(template.files) > 0;
    assert len(template.directories) > 0;
}

test "jacpack template config has shadcn section" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "shadcn";
    template = load_template_from_directory(template_dir);
    config = template.config;
    assert "jac-shadcn" in config;
    shadcn = config["jac-shadcn"];
    assert "style" in shadcn;
    assert "baseColor" in shadcn;
    assert "theme" in shadcn;
    # `registry` is intentionally NOT scaffolded -- the plugin's hardcoded
    # default is the canonical URL. Users add it only for self-hosted mirrors.
    assert "registry" not in shadcn;
}

test "jacpack template has npm dependencies" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "shadcn";
    template = load_template_from_directory(template_dir);
    npm = template.config["dependencies"]["npm"];
    assert "clsx" in npm;
    assert "tailwind-merge" in npm;
    assert "tw-animate-css" in npm;
}

test "jacpack template has required files" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "shadcn";
    template = load_template_from_directory(template_dir);
    # Files the template ships -- enough for `jac start main.jac` to render
    # a themed page at "/" after `jac install`.
    assert "main.jac" in template.files;
    assert "global.css" in template.files;
    assert "pages/layout.jac" in template.files;
    assert "pages/index.jac" in template.files;
    assert "components/home-page.cl.jac" in template.files;
    # lib/utils.cl.jac + components/ui/*.cl.jac are created on-demand by
    # `jac shadcn init` / `jac shadcn add`, not scaffolded by the template.
}


# ── Live Registry Smoke Test (the only live test) ──
test "live registry returns expected shape (smoke)" {
    # Single canary test that hits the real registry. If the registry
    # response shape drifts, this is the early-warning. All other tests
    # use mocked HTTP and are CI-safe regardless of registry health.
    data = _fetch_json("https://jac-shadcn.jaseci.org/registry");
    if data is None {
        # Registry unreachable -- skip rather than fail noisily in CI.
        return;
    }
    assert "components" in data;
    assert isinstance(data["components"], dict);
    assert len(data["components"]) > 0;
}
