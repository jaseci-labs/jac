"""Tests for jac_shadcn.shadcn_handler.init_shadcn_theme and the
path-traversal validator. HTTP is mocked via monkeypatching.

The URL-positional form was removed -- init_shadcn_theme now takes
explicit theme params and composes the registry URL from
config._raw_data["jac-shadcn"]["registry"] (or the public default).
"""

import tempfile;
import tomlkit;
import from pathlib { Path }
import from unittest.mock { patch }

import jac_shadcn.shadcn_handler as handler;
import from jac_shadcn.shadcn_handler {
    init_shadcn_theme,
    _validate_component_filename
}
import from jac_shadcn.lockfile { load_lockfile }


obj MockConfig {
    has project_root: str,
        _raw_data: dict = {};
}


def _make_theme_response() -> dict {
    return {
        "global_css": "/* test global css */\n",
        "npm_deps": {"clsx": "^2.1.1", "tailwind-merge": "^3.5.0"},
        "npm_dev_deps": {"@tailwindcss/vite": "^4.0.0"},
        "vite_config": {"plugins": ["tailwindcss()"]},
        "default_components": ["button"]
    };
}


def _make_button_response() -> dict {
    return {
        "name": "button",
        "file": "button.cl.jac",
        "content": "// generated button component\n",
        "npmDeps": ["class-variance-authority", "radix-ui"],
        "version": "1.0.0"
    };
}


def _scaffold(tmpdir: str, registry: str = "https://example.org") -> MockConfig {
    toml_path = Path(tmpdir) / "jac.toml";
    toml_path.write_text(
        '[project]\nname = "test"\n\n' + '[jac-shadcn]\nregistry = "' + registry + '"\n'
    );
    return MockConfig(
        project_root=tmpdir, _raw_data={"jac-shadcn": {"registry": registry}}
    );
}


# ── Path-traversal validator ──
test "validator accepts a plain .cl.jac filename" {
    assert _validate_component_filename("button", "button.cl.jac") == "button.cl.jac";
}

test "validator rejects parent-directory traversal" {
    assert _validate_component_filename("evil", "../escape.cl.jac") is None;
}

test "validator rejects forward-slash subpath" {
    assert _validate_component_filename("evil", "sub/dir.cl.jac") is None;
}

test "validator rejects backslash subpath" {
    assert _validate_component_filename("evil", "sub\\dir.cl.jac") is None;
}

test "validator rejects absolute path" {
    assert _validate_component_filename("evil", "/etc/passwd.cl.jac") is None;
}

test "validator rejects null byte" {
    assert _validate_component_filename("evil", "button\x00.cl.jac") is None;
}

test "validator rejects wrong suffix" {
    assert _validate_component_filename("button", "button.txt") is None;
    assert _validate_component_filename("button", "button.jac") is None;
}

test "validator rejects empty filename" {
    assert _validate_component_filename("button", "") is None;
    assert _validate_component_filename("button", None) is None;
}


# ── init_shadcn_theme: happy path with mocked HTTP ──
test "init writes global.css, syncs [jac-shadcn], vite config, default components" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        responses = {
            "theme": _make_theme_response(),
            "button": _make_button_response()
        };
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return responses["theme"];
            }
            if "/component/button" in url {
                return responses["button"];
            }
            return None;
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            result = init_shadcn_theme(
                config, style="nova", theme="blue", font="outfit"
            );
        }
        assert result == True;
        # global.css written, wrapped in managed/user marker structure
        css = (Path(tmpdir) / "global.css").read_text();
        assert "/* === jac-shadcn:managed BEGIN === */" in css;
        assert "/* === jac-shadcn:user BEGIN === */" in css;
        assert "/* test global css */" in css;
        # [jac-shadcn] section synced with the params we passed
        doc = tomlkit.parse((Path(tmpdir) / "jac.toml").read_text());
        assert doc["jac-shadcn"]["style"] == "nova";
        assert doc["jac-shadcn"]["theme"] == "blue";
        assert doc["jac-shadcn"]["font"] == "outfit";
        # Registry URL is preserved (already in jac.toml from _scaffold).
        assert doc["jac-shadcn"]["registry"] == "https://example.org";
        # npm deps + dev deps patched in via tomlkit
        assert "clsx" in doc["dependencies"]["npm"];
        assert "@tailwindcss/vite" in doc["dependencies"]["npm"]["dev"];
        # vite plugin section created
        assert doc["plugins"]["client"]["vite"]["plugins"][0] == "tailwindcss()";
        # default component installed + lockfile entry written
        assert (Path(tmpdir) / "components" / "ui" / "button.cl.jac").exists();
        lock = load_lockfile(Path(tmpdir));
        assert "button" in lock["components"];
        assert lock["components"]["button"]["version"] == "1.0.0";
    }
}


test "init falls back to defaults when called with no theme args" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _make_theme_response();
            }
            return _make_button_response();
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config);
        }
        doc = tomlkit.parse((Path(tmpdir) / "jac.toml").read_text());
        assert doc["jac-shadcn"]["style"] == "nova";
        assert doc["jac-shadcn"]["baseColor"] == "neutral";
        assert doc["jac-shadcn"]["theme"] == "neutral";
        assert doc["jac-shadcn"]["font"] == "figtree";
    }
}


test "init uses [jac-shadcn].registry from jac.toml, not public default" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir, registry="https://my.private-mirror.test");
        seen: list = [];
        def fake_fetch(url: str, silent: bool = False) -> dict {
            seen.append(url);
            if "/theme" in url {
                return _make_theme_response();
            }
            return _make_button_response();
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova");
        }
        # The /theme URL was composed against the mirror, not the public default.
        assert any("my.private-mirror.test" in u for u in seen);
    }
}


test "init warns on legacy global.css with no markers, then writes wrapped form" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        (Path(tmpdir) / "global.css").write_text("/* original user css */\n");
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _make_theme_response();
            }
            return _make_button_response();
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova");
        }
        css = (Path(tmpdir) / "global.css").read_text();
        assert "/* original user css */" not in css;
        assert "/* === jac-shadcn:managed BEGIN === */" in css;
        assert "/* === jac-shadcn:user BEGIN === */" in css;
        assert "/* test global css */" in css;
    }
}


test "init preserves user-marked section across re-runs" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _make_theme_response();
            }
            return _make_button_response();
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova");
        }
        css_path = Path(tmpdir) / "global.css";
        injected = css_path.read_text().replace(
            "/* === jac-shadcn:user BEGIN === */\n/* Anything between these markers survives `jac shadcn upgrade`. */\n/* === jac-shadcn:user END === */",
            "/* === jac-shadcn:user BEGIN === */\n.my-button { color: hotpink; }\n/* === jac-shadcn:user END === */"
        );
        css_path.write_text(injected);
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova");
        }
        after = css_path.read_text();
        assert ".my-button { color: hotpink; }" in after;
        assert "/* test global css */" in after;
    }
}


test "init does not duplicate [plugins.client.vite] when it already exists" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "test"\n\n' + '[jac-shadcn]\nregistry = "https://example.org"\n\n' + '[plugins.client.vite]\nplugins = ["custom()"]\n'
        );
        config = MockConfig(
            project_root=tmpdir,
            _raw_data={"jac-shadcn": {"registry": "https://example.org"}}
        );
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _make_theme_response();
            }
            return _make_button_response();
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova");
        }
        doc = tomlkit.parse(toml_path.read_text());
        assert doc["plugins"]["client"]["vite"]["plugins"][0] == "custom()";
    }
}


test "init returns False on network failure" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        def fake_fetch(url: str, silent: bool = False) -> dict {
            return None;
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            result = init_shadcn_theme(config, style="nova");
        }
        assert result == False;
    }
}


test "init refuses to write a traversal filename from default components" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir);
        evil_button = {
            "name": "button",
            "file": "../../../etc/owned.cl.jac",
            "content": "pwned",
            "npmDeps": [],
            "version": "1.0.0"
        };
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _make_theme_response();
            }
            return evil_button;
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova");
        }
        ui_dir = Path(tmpdir) / "components" / "ui";
        for f in ui_dir.rglob("*") {
            assert "owned" not in str(f);
        }
    }
}


# ── Regression: don't write to ancestor project when nested ──
test "init writes to project_root in config, NOT to any ancestor jac.toml" {
    # Reproduces the user-reported bug where `jac create myapp` from a dir
    # that happened to live INSIDE another jac project caused jaclang's
    # cached get_config() to return the parent's config, so init wrote
    # there. Once the post-hook started passing force_discover=True, the
    # right config reached init -- this test pins that behavior by feeding
    # an explicit MockConfig pointing at the child dir.
    with tempfile.TemporaryDirectory() as parent_root {
        # Set up a fake parent jac project that ALSO has [jac-shadcn].
        # If init ever writes here, the test catches it.
        parent_toml = Path(parent_root) / "jac.toml";
        parent_toml.write_text(
            '[project]\nname = "parent"\n\n' + '[jac-shadcn]\nstyle = "vega"\nregistry = "https://example.org"\n\n' + '[dependencies.npm]\n'
        );
        # Inside the parent, create a child project (simulates `jac create
        # myapp` run from a dir nested in the parent).
        child = Path(parent_root) / "child-project";
        child.mkdir();
        child_toml = child / "jac.toml";
        child_toml.write_text(
            '[project]\nname = "child"\n\n' + '[jac-shadcn]\nstyle = "nova"\nregistry = "https://example.org"\n'
        );
        # Hand init a config that points squarely at the child. This is
        # what the post-hook now does via get_config(start_path=child,
        # force_discover=True).
        config = MockConfig(
            project_root=str(child),
            _raw_data={
                "jac-shadcn": {"style": "nova", "registry": "https://example.org"}
            }
        );
        def fake_fetch(url: str, silent: bool = False) -> dict {
            if "/theme" in url {
                return _make_theme_response();
            }
            return _make_button_response();
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="nova");
        }
        # Child got everything.
        child_doc = tomlkit.parse(child_toml.read_text());
        assert child_doc["jac-shadcn"]["style"] == "nova";
        assert "clsx" in child_doc["dependencies"]["npm"];
        assert (child / "components" / "ui" / "button.cl.jac").exists();
        assert (child / "global.css").exists();
        assert (child / "jac-shadcn.lock").exists();
        # Parent was NOT touched.
        parent_doc = tomlkit.parse(parent_toml.read_text());
        assert parent_doc["jac-shadcn"]["style"] == "vega";  # untouched
        # No deps leaked into parent's [dependencies.npm]
        parent_npm = parent_doc.get("dependencies", {}).get("npm", {});
        for key in parent_npm.keys() {
            assert False;  # parent should have no npm entries (was empty)
        }
        assert not (Path(parent_root) / "components" / "ui").exists();
        assert not (Path(parent_root) / "jac-shadcn.lock").exists();
    }
}
