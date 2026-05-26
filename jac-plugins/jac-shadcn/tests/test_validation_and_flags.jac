"""Tests for validation module, declarative flag flow,
3-level fallback, and the `jac create` post-hook integration."""

import tempfile;
import tomlkit;
import os;
import from pathlib { Path }
import from unittest.mock { patch }

import jac_shadcn.shadcn_handler as handler;
import jac_shadcn.validation as validation;
import from jac_shadcn.validation {
    validate_field,
    validate_theme_params,
    KNOWN_STYLES,
    KNOWN_THEMES,
    KNOWN_FONTS,
    KNOWN_RADII,
}
import from jac_shadcn.shadcn_cli { shadcn, _resolve_theme_params, _resolve_registry, }
import from jac_shadcn.shadcn_handler { init_shadcn_theme, _read_shadcn_config }


obj MockConfig {
    has project_root: str,
        _raw_data: dict = {};
}


def _scaffold(tmpdir: str, registry: str = "https://example.org") -> MockConfig {
    Path(
        tmpdir / "jac.toml" if isinstance(tmpdir, Path) else Path(tmpdir) / "jac.toml"
    ).write_text(
        '[project]\nname = "demo"\n\n' + '[jac-shadcn]\nregistry = "' + registry + '"\n'
    );
    return MockConfig(
        project_root=tmpdir, _raw_data={"jac-shadcn": {"registry": registry}}
    );
}


# ── Validation: hardcoded list correctness ──
test "KNOWN_STYLES matches registry's 5 styles" {
    assert sorted(KNOWN_STYLES) == ["lyra", "maia", "mira", "nova", "vega"];
}

test "KNOWN_RADII uses long form (small/medium/large, not sm/md/lg)" {
    assert "small" in KNOWN_RADII;
    assert "medium" in KNOWN_RADII;
    assert "large" in KNOWN_RADII;
    assert "sm" not in KNOWN_RADII;
}

test "KNOWN_THEMES has all 21 (4 base + 17 accent)" {
    assert len(KNOWN_THEMES) == 21;
    assert "rose" in KNOWN_THEMES;
    assert "neutral" in KNOWN_THEMES;
}

test "KNOWN_FONTS includes the common ones" {
    for f in ["inter", "figtree", "geist", "outfit"] {
        assert f in KNOWN_FONTS;
    }
}


# ── validate_field ──
test "validate_field accepts empty value as 'not specified'" {
    (ok, suggestions) = validate_field("style", "", "https://example.org");
    assert ok == True;
    assert suggestions == [];
}

test "validate_field accepts None" {
    (ok, suggestions) = validate_field("style", None, "https://example.org");
    assert ok == True;
}

test "validate_field accepts valid value" {
    (ok, suggestions) = validate_field("style", "nova", "https://example.org");
    assert ok == True;
}

test "validate_field rejects close typo with did-you-mean suggestion" {
    # Force the cache to skip /options so we use the hardcoded list.
    validation._options_cache["https://example.org"] = {};
    (ok, suggestions) = validate_field("style", "nva", "https://example.org");
    assert ok == False;
    assert "nova" in suggestions;
}

test "validate_field rejects nonsense with no suggestion" {
    validation._options_cache["https://example.org"] = {};
    (ok, suggestions) = validate_field("style", "qqqqqqqq", "https://example.org");
    assert ok == False;
    # No close match within cutoff
    assert suggestions == [] or "nova" not in suggestions;
}


# ── validate_theme_params (bulk) ──
test "validate_theme_params returns empty list on all-valid input" {
    validation._options_cache["https://example.org"] = {};
    errors = validate_theme_params(
        {"style": "nova", "theme": "rose", "font": "figtree"}, "https://example.org"
    );
    assert errors == [];
}

test "validate_theme_params surfaces every invalid field" {
    validation._options_cache["https://example.org"] = {};
    errors = validate_theme_params(
        {"style": "helios", "theme": "ultraviolet"}, "https://example.org"
    );
    assert len(errors) == 2;
}


# ── 3-level fallback ──
test "resolve_theme_params: flag > jac.toml > default (flag wins)" {
    config = MockConfig(
        project_root="/tmp",
        _raw_data={"jac-shadcn": {"style": "vega", "theme": "blue"}}
    );
    resolved = _resolve_theme_params(config, "nova", "", "", "", "", "");
    # Flag wins for style; jac.toml wins for theme; default wins for the rest.
    assert resolved["style"] == "nova";
    assert resolved["theme"] == "blue";
    assert resolved["baseColor"] == "neutral";
}

test "resolve_theme_params: jac.toml > default when no flag" {
    config = MockConfig(
        project_root="/tmp",
        _raw_data={"jac-shadcn": {"style": "mira", "font": "outfit"}}
    );
    resolved = _resolve_theme_params(config, "", "", "", "", "", "");
    assert resolved["style"] == "mira";
    assert resolved["font"] == "outfit";
    assert resolved["theme"] == "neutral";  # default
}

test "resolve_theme_params: default when no flag and no jac.toml entry" {
    config = MockConfig(project_root="/tmp", _raw_data={"jac-shadcn": {}});
    resolved = _resolve_theme_params(config, "", "", "", "", "", "");
    assert resolved == {
        "style": "nova",
        "baseColor": "neutral",
        "theme": "neutral",
        "font": "figtree",
        "radius": "default",
        "menuAccent": "subtle"
    };
}


# ── registry resolution ──
test "resolve_registry: jac.toml registry wins" {
    config = MockConfig(
        project_root="/tmp", _raw_data={"jac-shadcn": {"registry": "https://my.mirror"}}
    );
    assert _resolve_registry(config) == "https://my.mirror";
}

test "resolve_registry: public default when missing" {
    config = MockConfig(project_root="/tmp", _raw_data={});
    assert _resolve_registry(config) == "https://jac-shadcn.jaseci.org";
}


# ── jac shadcn dispatcher: invalid action ──
test "shadcn() rejects unknown action" {
    rc = shadcn(action="frobnicate", packages=[]);
    assert rc == 1;
}


# ── init via the new flag-based signature ──
test "init composes URL from [jac-shadcn].registry + theme params" {
    with tempfile.TemporaryDirectory() as tmpdir {
        config = _scaffold(tmpdir, registry="https://my.mirror.test");
        seen: list = [];
        def fake_fetch(url: str, silent: bool = False) -> dict {
            seen.append(url);
            if "/theme" in url {
                return {
                    "global_css": "/* x */\n",
                    "npm_deps": {},
                    "npm_dev_deps": {},
                    "vite_config": {},
                    "default_components": []
                };
            }
            return None;
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="vega", base_color="zinc", theme="emerald");
        }
        theme_calls = [
            u
            for u in seen
            if "/theme" in u
        ];
        assert any("my.mirror.test" in u for u in theme_calls);
        assert any("style=vega" in u for u in theme_calls);
        assert any("baseColor=zinc" in u for u in theme_calls);
        assert any("theme=emerald" in u for u in theme_calls);
    }
}


test "init overwrites template-default [jac-shadcn] with passed params" {
    with tempfile.TemporaryDirectory() as tmpdir {
        # Simulate the template-scaffolded state: jac.toml has [jac-shadcn] with
        # default values from the template.
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "demo"\n\n' + '[jac-shadcn]\n' + 'style = "nova"\nbaseColor = "neutral"\ntheme = "neutral"\n' + 'font = "figtree"\nradius = "default"\nmenuAccent = "subtle"\n' + 'registry = "https://example.org"\n'
        );
        config = MockConfig(
            project_root=tmpdir,
            _raw_data={
                "jac-shadcn": {
                    "style": "nova",
                    "baseColor": "neutral",
                    "theme": "neutral",
                    "font": "figtree",
                    "radius": "default",
                    "menuAccent": "subtle",
                    "registry": "https://example.org"
                }
            }
        );
        def fake_fetch(url: str, silent: bool = False) -> dict {
            return {
                "global_css": "/* x */\n",
                "npm_deps": {},
                "npm_dev_deps": {},
                "vite_config": {},
                "default_components": []
            };
        }
        with patch.object(handler, "_fetch_json", side_effect=fake_fetch) {
            init_shadcn_theme(config, style="vega", theme="rose", font="outfit");
        }
        doc = tomlkit.parse(toml_path.read_text());
        # User's explicit values won over the template-pre-populated section.
        assert doc["jac-shadcn"]["style"] == "vega";
        assert doc["jac-shadcn"]["theme"] == "rose";
        assert doc["jac-shadcn"]["font"] == "outfit";
        # Untouched user-customized registry preserved.
        assert doc["jac-shadcn"]["registry"] == "https://example.org";
    }
}
