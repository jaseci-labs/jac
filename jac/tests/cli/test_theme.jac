"""Tests for the shadcn theme handler (offline themed create + retheme)."""

import tempfile;
import from pathlib { Path }
import from jaclang.cli.shadcn.theme_handler {
    normalize_shadcn_config,
    load_themes,
    find_theme,
    resolve_css_vars,
    generate_global_css,
    generate_starter_main_jac,
    set_shadcn_section,
    materialize_themed_starter,
    retheme_project
}


# Module-level mock (a dataclass declared inside a test function can't resolve
# its `__module__`, so config mocks must live at module scope).
obj MockConfig {
    has project_root: any = None,
        _raw_data: any = None;
}


# ── Config normalization ──
test "normalize fills the 7 defaults" {
    cfg = normalize_shadcn_config(None);
    for key in [
        "style",
        "baseColor",
        "theme",
        "font",
        "radius",
        "menuAccent",
        "menuColor"
    ] {
        assert key in cfg;
    }
    assert cfg["style"] == "nova";
    assert cfg["theme"] == "neutral";
}

test "normalize keeps provided values" {
    cfg = normalize_shadcn_config({"theme": "rose", "font": "inter"});
    assert cfg["theme"] == "rose";
    assert cfg["font"] == "inter";
    assert cfg["style"] == "nova";
}


# ── Bundled themes ──
test "themes data loads" {
    themes = load_themes();
    assert len(themes) > 0;
    names = [t["name"] for t in themes];
    assert "rose" in names;
    assert "emerald" in names;
}

test "find theme by name" {
    assert find_theme("rose") is not None;
    assert find_theme("does-not-exist") is None;
}


# ── CSS variable resolution ──
test "resolve css vars produces light and dark primaries" {
    css = resolve_css_vars({"baseColor": "neutral", "theme": "rose"});
    assert "light" in css;
    assert "dark" in css;
    assert css["light"].get("primary");
    assert css["dark"].get("primary");
}

test "radius override applies" {
    css = resolve_css_vars(
        {"baseColor": "neutral", "theme": "neutral", "radius": "none"}
    );
    assert css["light"].get("radius") == "0";
}

test "menuAccent bold maps accent to primary" {
    css = resolve_css_vars(
        {"baseColor": "neutral", "theme": "rose", "menuAccent": "bold"}
    );
    assert css["light"]["accent"] == css["light"]["primary"];
}

test "unknown theme yields empty vars" {
    css = resolve_css_vars({"baseColor": "nope", "theme": "nope"});
    assert css["light"] == {};
}


# ── global.css generation ──
test "global css contains font import and theme tokens" {
    css_vars = resolve_css_vars({"baseColor": "neutral", "theme": "rose"});
    out = generate_global_css("inter", css_vars);
    assert '@import "@fontsource-variable/inter";' in out;
    assert ":root {" in out;
    assert "@theme inline {" in out;
    assert "--color-primary: var(--primary);" in out;
}

test "starter main imports button and card" {
    main = generate_starter_main_jac();
    assert "components.ui.button" in main;
    assert "components.ui.card" in main;
    assert "{{name}}" in main;
}


# ── jac.toml [jac-shadcn] patching ──
test "set shadcn section appends when missing" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text('[project]\nname = "x"\n');
        set_shadcn_section(toml_path, normalize_shadcn_config({"theme": "rose"}));
        content = toml_path.read_text();
        assert "[jac-shadcn]" in content;
        assert 'theme = "rose"' in content;
    }
}

test "set shadcn section replaces existing block" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[jac-shadcn]\nstyle = "nova"\ntheme = "neutral"\n\n[dependencies.npm]\nclsx = "^2.1.1"\n'
        );
        set_shadcn_section(toml_path, normalize_shadcn_config({"theme": "emerald"}));
        content = toml_path.read_text();
        assert 'theme = "emerald"' in content;
        assert 'theme = "neutral"' not in content;
        # The following section must survive.
        assert "[dependencies.npm]" in content;
        assert "clsx" in content;
    }
}


# ── Materialize a themed starter ──
test "materialize themed starter writes the project" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "demo"\n\n[dependencies.npm]\nclsx = "^2.1.1"\n'
        );
        cfg = normalize_shadcn_config({"theme": "rose", "font": "inter"});
        ok = materialize_themed_starter(tmpdir, "demo", cfg);
        assert ok == True;
        proj = Path(tmpdir);
        assert (proj / "components" / "ui" / "button.cl.jac").exists();
        assert (proj / "components" / "ui" / "card.cl.jac").exists();
        assert (proj / "lib" / "utils.cl.jac").exists();
        assert (proj / "styles" / "global.css").exists();
        assert (proj / "main.jac").exists();
        # global.css is themed for the requested font + theme.
        css = (proj / "styles" / "global.css").read_text();
        assert "@fontsource-variable/inter" in css;
        # main.jac has the project name substituted.
        assert "Welcome to demo" in (proj / "main.jac").read_text();
        # Components resolved (no leftover cn-* tokens).
        assert "cn-" not in (proj / "components" / "ui" / "button.cl.jac").read_text();
        # jac.toml records the chosen theme and quotes scoped npm keys.
        toml_text = toml_path.read_text();
        assert 'theme = "rose"' in toml_text;
        assert '"@fontsource-variable/inter"' in toml_text;
    }
}


# ── Retheme an existing project ──
test "retheme regenerates global css and persists config" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = Path(tmpdir) / "jac.toml";
        toml_path.write_text(
            '[project]\nname = "demo"\n\n[jac-shadcn]\nstyle = "nova"\ntheme = "neutral"\nfont = "figtree"\n\n[dependencies.npm]\nclsx = "^2.1.1"\n'
        );
        config = MockConfig(
            project_root=tmpdir,
            _raw_data={
                "jac-shadcn": {"style": "nova", "theme": "neutral", "font": "figtree"}
            }
        );
        ok = retheme_project(config, {"theme": "emerald", "font": "outfit"});
        assert ok == True;
        css = (Path(tmpdir) / "styles" / "global.css").read_text();
        assert "@fontsource-variable/outfit" in css;
        toml_text = toml_path.read_text();
        assert 'theme = "emerald"' in toml_text;
        assert 'font = "outfit"' in toml_text;
    }
}

test "retheme fails gracefully without a project" {
    assert retheme_project(MockConfig(), {}) == False;
}
