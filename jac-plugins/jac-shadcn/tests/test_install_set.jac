"""Tests for ESSENTIAL_COMPONENTS, install_set
(essential/all/bare), template-name rename (shadcn)."""

import tempfile;
import tomlkit;
import from pathlib { Path }
import from unittest.mock { patch }

import jac_shadcn.shadcn_handler as handler;
import from jac_shadcn.shadcn_handler { init_shadcn_theme }
import from jac_shadcn.lockfile { load_lockfile }


obj MockConfig {
    has project_root: str,
        _raw_data: dict = {};
}


def _scaffold(tmpdir: str) -> MockConfig {
    Path(Path(tmpdir) / "jac.toml").write_text(
        '[project]\nname = "demo"\n\n' + '[jac-shadcn]\nregistry = "https://example.org"\n'
    );
    return MockConfig(
        project_root=tmpdir,
        _raw_data={"jac-shadcn": {"registry": "https://example.org"}}
    );
}


def _theme_response_with_all() -> dict {
    # Registry advertises a big default set; only "all" should install them.
    return {
        "global_css": "/* x */\n",
        "npm_deps": {},
        "npm_dev_deps": {},
        "vite_config": {},
        "default_components": [
            "accordion",
            "alert",
            "alert-dialog",
            "aspect-ratio",
            "breadcrumb",
            "calendar",
            "carousel",
            "chart",
            "checkbox",
            "collapsible",
            "command",
            "context-menu",
            "drawer",
            "form",
            "hover-card",
            "menubar",
            "navigation-menu",
            "pagination",
            "popover",
            "progress",
            "radio-group",
            "resizable",
            "scroll-area",
            "select",
            "sheet",
            "slider",
            "switch",
            "table",
            "tabs",
            "textarea",
            "toggle",
            "tooltip"
        ]
    };
}


def _component_response(name: str) -> dict {
    return {
        "name": name,
        "file": name + ".cl.jac",
        "content": "// " + name + "\n",
        "npmDeps": [],
        "version": "1.0.0"
    };
}


# ── ESSENTIAL_COMPONENTS list ──
test "ESSENTIAL_COMPONENTS has exactly 10 names" {
    assert len(handler.ESSENTIAL_COMPONENTS) == 10;
}

test "ESSENTIAL_COMPONENTS covers the form + nav + layout basics" {
    expected = [
        "button",
        "card",
        "input",
        "label",
        "dialog",
        "dropdown-menu",
        "separator",
        "badge",
        "avatar",
        "skeleton"
    ];
    for name in expected {
        assert name in handler.ESSENTIAL_COMPONENTS;
    }
}


# ── install_set="essential" (default) ──
test "init default install_set installs exactly the 10 essentials" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        fetched: list = [];
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _theme_response_with_all();
            }
            # component URL: extract the component name
            name = url.split("/component/")[1].split("?")[0];
            fetched.append(name);
            return _component_response(name);
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova");
        }
        # Exactly the 10 essentials were fetched, nothing more.
        assert sorted(fetched) == sorted(handler.ESSENTIAL_COMPONENTS);
        # Files written
        ui_dir = Path(tmpdir) / "components" / "ui";
        installed_files = sorted([f.name for f in ui_dir.iterdir()]);
        assert installed_files == sorted(
            [n + ".cl.jac" for n in handler.ESSENTIAL_COMPONENTS]
        );
        # Lockfile records all 10
        lock = load_lockfile(Path(tmpdir));
        for name in handler.ESSENTIAL_COMPONENTS {
            assert name in lock["components"];
        }
    }
}


# ── install_set="all" ──
test "init install_set=all installs registry's full default_components list" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        fetched: list = [];
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _theme_response_with_all();
            }
            name = url.split("/component/")[1].split("?")[0];
            fetched.append(name);
            return _component_response(name);
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova", install_set="all");
        }
        # All 32 in the mock registry got fetched, NOT just essentials.
        expected = _theme_response_with_all()["default_components"];
        assert sorted(fetched) == sorted(expected);
        assert len(fetched) == len(expected);
        # Essential 'button' wasn't fetched because it's not in this mock's
        # default_components -- confirms we used registry's list, not the
        # essentials list.
        assert "button" not in fetched;
    }
}


# ── install_set="bare" ──
test "init install_set=bare writes theme/css but installs zero components" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        fetched: list = [];
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _theme_response_with_all();
            }
            fetched.append(url);
            return _component_response("never");
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova", install_set="bare");
        }
        # No /component/* fetches happened.
        assert fetched == [];
        # ui_dir is empty (or doesn't have any .cl.jac files yet).
        ui_dir = Path(tmpdir) / "components" / "ui";
        cl_files = list(ui_dir.glob("*.cl.jac"));
        assert cl_files == [];
        # Lockfile has no installed components.
        lock = load_lockfile(Path(tmpdir));
        components = lock.get("components", {});
        assert len(components) == 0 or all(False for _ in components.keys());
        # global.css still got written (theme/css setup ran)
        assert (Path(tmpdir) / "global.css").exists();
    }
}


# ── install_set unknown value falls back to essentials ──
test "init falls back to essentials on unrecognized install_set value" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        fetched: list = [];
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _theme_response_with_all();
            }
            name = url.split("/component/")[1].split("?")[0];
            fetched.append(name);
            return _component_response(name);
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova", install_set="potato");
        }
        # Falls back to essentials.
        assert sorted(fetched) == sorted(handler.ESSENTIAL_COMPONENTS);
    }
}


# ── Template rename to 'shadcn' ──
test "template registers under the name 'shadcn'" {
    import from jaclang.project.template_loader { load_template_from_directory }
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "shadcn";
    assert template_dir.exists();
    template = load_template_from_directory(template_dir);
    assert template.name == "shadcn";
}


test "template directory under 'jac-shadcn' no longer exists" {
    template_dir = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "jac-shadcn";
    assert not template_dir.exists();
}


# ── 0.5.1: registry omitted by default ──
test "init does not add a registry line to jac.toml when none was set" {
    with tempfile.TemporaryDirectory() as tmpdir {
        # Start with a project that has [jac-shadcn] but NO registry key
        # (the new template shape).
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "demo"\n\n[jac-shadcn]\nstyle = "nova"\n'
        );
        config = MockConfig(
            project_root=tmpdir, _raw_data={"jac-shadcn": {"style": "nova"}}
        );
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _theme_response_with_all();
            }
            name = url.split("/component/")[1].split("?")[0];
            return _component_response(name);
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova");
        }
        doc = tomlkit.parse(toml_path.read_text());
        # Plugin must NOT have written a registry line back.
        assert "registry" not in doc["jac-shadcn"];
    }
}


test "init preserves an explicit registry override" {
    with tempfile.TemporaryDirectory() as tmpdir {
        # User pointed at a self-hosted mirror.
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "demo"\n\n' + '[jac-shadcn]\nstyle = "nova"\nregistry = "https://my.mirror.test"\n'
        );
        config = MockConfig(
            project_root=tmpdir,
            _raw_data={
                "jac-shadcn": {"style": "nova", "registry": "https://my.mirror.test"}
            }
        );
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _theme_response_with_all();
            }
            name = url.split("/component/")[1].split("?")[0];
            return _component_response(name);
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova");
        }
        doc = tomlkit.parse(toml_path.read_text());
        # The user's mirror URL is left exactly as-is.
        assert doc["jac-shadcn"]["registry"] == "https://my.mirror.test";
    }
}


test "scaffolded template's jac.toml has no `registry =` line" {
    template_jac_toml = Path(__file__).resolve().parent.parent / "jac_shadcn" / "templates" / "shadcn" / "jac.toml";
    content = template_jac_toml.read_text();
    # Allowed: a commented-out hint line. Not allowed: an active assignment.
    for line in content.splitlines() {
        stripped = line.strip();
        if stripped.startswith("#") {
            continue;
        }
        assert not stripped.startswith("registry");
    }
}
