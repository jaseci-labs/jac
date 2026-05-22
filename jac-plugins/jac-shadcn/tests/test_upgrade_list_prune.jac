"""Tests for upgrade, list, prune, and the new
`jac shadcn` action dispatcher. HTTP is mocked via monkeypatching."""

import tempfile;
import tomlkit;
import from pathlib { Path }
import from unittest.mock { patch }

import jac_shadcn.shadcn_handler as handler;
import from jac_shadcn.shadcn_handler {
    upgrade_shadcn_components,
    list_shadcn_components,
    prune_orphan_deps,
}
import from jac_shadcn.shadcn_cli { shadcn }
import from jac_shadcn.lockfile { record_install, load_lockfile }


obj MockConfig {
    has project_root: str,
        _raw_data: dict = {};
}


def _scaffold(tmpdir: str, with_shadcn: bool = True) -> MockConfig {
    toml_path = Path(tmpdir) / "jac.toml";
    if with_shadcn {
        toml_path.write_text(
            '[project]\nname = "demo"\n\n' + '[jac-shadcn]\nstyle = "nova"\nregistry = "https://example.org"\n' + '\n[dependencies.npm]\n'
        );
        return MockConfig(
            project_root=tmpdir,
            _raw_data={
                "jac-shadcn": {"style": "nova", "registry": "https://example.org"}
            }
        );
    }
    toml_path.write_text('[project]\nname = "demo"\n\n');
    return MockConfig(project_root=tmpdir, _raw_data={});
}


def _mock_component(name: str, version: str = "1.0.0") -> dict {
    return {
        "name": name,
        "file": name + ".cl.jac",
        "content": "// " + name + " @ " + version + "\n",
        "npmDeps": ["radix-ui"],
        "version": version
    };
}


def _mock_registry() -> dict {
    return {
        "components": {
            "button": {
                "file": "button.cl.jac",
                "npmDeps": ["radix-ui"],
                "peerComponents": []
            },
            "card": {"file": "card.cl.jac", "npmDeps": [], "peerComponents": []},
            "dialog": {
                "file": "dialog.cl.jac",
                "npmDeps": ["radix-ui"],
                "peerComponents": []
            }
        },
        "sharedDeps": {}
    };
}


# ── upgrade ──
test "upgrade fails clearly when no [jac-shadcn] section" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir, with_shadcn=False);
        result = upgrade_shadcn_components(config, [], None);
        assert result == False;
    }
}

test "upgrade fails clearly when lockfile is empty" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        result = upgrade_shadcn_components(config, [], None);
        assert result == False;
    }
}

test "upgrade rejects names not in lockfile with close-match hint" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        record_install(Path(tmpdir), "button", "1.0.0", []);
        result = upgrade_shadcn_components(config, ["buton"], None);
        assert result == False;
    }
}

test "upgrade re-fetches all installed components when names is empty" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        record_install(Path(tmpdir), "button", "1.0.0", ["radix-ui"]);
        record_install(Path(tmpdir), "card", "1.0.0", []);
        seen: list = [];
        def fake_fetch(url: str) -> dict {
            seen.append(url);
            if "button" in url {
                return _mock_component("button", "1.1.0");
            }
            return _mock_component("card", "1.1.0");
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            result = upgrade_shadcn_components(config, [], None);
        }
        assert result == True;
        # Both component endpoints were hit
        assert any("button" in u for u in seen);
        assert any("card" in u for u in seen);
        # Lockfile versions updated
        lock = load_lockfile(Path(tmpdir));
        assert lock["components"]["button"]["version"] == "1.1.0";
        assert lock["components"]["card"]["version"] == "1.1.0";
    }
}

test "upgrade --style switches style in jac.toml and re-fetches" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        record_install(Path(tmpdir), "button", "1.0.0", []);
        seen: list = [];
        def fake_fetch(url: str) -> dict {
            seen.append(url);
            return _mock_component("button", "1.0.0");
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            upgrade_shadcn_components(config, [], "vega");
        }
        assert any("style=vega" in u for u in seen);
        doc = tomlkit.parse((Path(tmpdir) / "jac.toml").read_text());
        assert doc["jac-shadcn"]["style"] == "vega";
    }
}

test "upgrade scoped to a single named component" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        record_install(Path(tmpdir), "button", "1.0.0", []);
        record_install(Path(tmpdir), "card", "1.0.0", []);
        seen: list = [];
        def fake_fetch(url: str) -> dict {
            seen.append(url);
            return _mock_component("button", "1.2.0");
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            upgrade_shadcn_components(config, ["button"], None);
        }
        # Only the named component was fetched
        assert any("button" in u for u in seen);
        assert not any("card" in u for u in seen);
    }
}


# ── list ──
test "list --installed-only prints from lockfile without network" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        record_install(Path(tmpdir), "button", "1.0.0", []);
        # If --installed-only short-circuits, _fetch_json is never called.
        with patch.object(
            handler, "_fetch_json", side_effect=Exception("should not be called")
        ) {
            result = list_shadcn_components(config, installed_only=True);
        }
        assert result == True;
    }
}

test "list --installed-only on empty lockfile prints empty hint" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        with patch.object(handler, "_fetch_json", side_effect=Exception("nope")) {
            result = list_shadcn_components(config, installed_only=True);
        }
        assert result == True;
    }
}

test "list with registry call shows available components" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        record_install(Path(tmpdir), "button", "1.0.0", []);
        with patch.object(handler, "_fetch_json", return_value=_mock_registry()) {
            result = list_shadcn_components(config, installed_only=False);
        }
        assert result == True;
    }
}

test "list returns False when registry unreachable" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        with patch.object(handler, "_fetch_json", return_value=None) {
            result = list_shadcn_components(config, installed_only=False);
        }
        assert result == False;
    }
}


# ── prune ──
test "prune is a no-op when jac.toml has no [dependencies.npm]" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir, with_shadcn=False);
        result = prune_orphan_deps(config);
        assert result == True;
    }
}

test "prune leaves user-pinned deps alone" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "demo"\n\n' + '[jac-shadcn]\nstyle = "nova"\nregistry = "https://example.org"\n\n' + '[dependencies.npm]\n' + 'lodash = "^4.0.0"\n'  # user-pinned, never shadcn-managed
        );
        result = prune_orphan_deps(config);
        assert result == True;
        doc = tomlkit.parse(toml_path.read_text());
        # User-pinned dep survives (not shape "*").
        assert "lodash" in doc["dependencies"]["npm"];
    }
}

test "prune drops shadcn-managed deps that no installed component holds" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "demo"\n\n' + '[jac-shadcn]\nstyle = "nova"\nregistry = "https://example.org"\n\n' + '[dependencies.npm]\n' + 'orphan-pkg = "*"\n'  # shape "*" => shadcn-managed, not held
             + 'radix-ui = "*"\n'  # held by button
        );
        record_install(Path(tmpdir), "button", "1.0.0", ["radix-ui"]);
        result = prune_orphan_deps(config);
        assert result == True;
        doc = tomlkit.parse(toml_path.read_text());
        assert "orphan-pkg" not in doc["dependencies"]["npm"];
        assert "radix-ui" in doc["dependencies"]["npm"];
    }
}


# ── shadcn() dispatcher ──
test "shadcn() rejects unknown action" {
    rc = shadcn(action="frobnicate", packages=[]);
    assert rc == 1;
}
