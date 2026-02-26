"""Tests for JacKit component handler (jac add --kit / jac remove --kit)."""

import os;
import tempfile;
import shutil;
import json;
import from pathlib { Path }
import from unittest.mock { patch, MagicMock }

import from jac_client.plugin.kit_handler {
    _read_kit_config,
    _resolve_peer_deps,
    _update_npm_deps,
    add_kit_components,
    remove_kit_components
}


"""Create a temporary project with jac.toml containing [kit] config."""
def make_kit_project(
    style: str = "nova",
    registry_url: str = "http://localhost:9999",
    extra_npm: str = ""
) -> tuple {
    tmp = tempfile.mkdtemp(prefix="jac_kit_test_");
    project_dir = Path(tmp) / "test_project";
    project_dir.mkdir();

    npm_section = 'radix-ui = "*"\n' + extra_npm;
    toml_content = (
        '[project]\nname = "kit-test"\nversion = "1.0.0"\nentry-point = "main.jac"\n\n'
        + '[dependencies.npm]\n' + npm_section + '\n'
        + '[kit]\nstyle = "' + style + '"\n'
        + 'registry = "' + registry_url + '"\n'
    );

    jac_toml = project_dir / "jac.toml";
    jac_toml.write_text(toml_content);

    return (tmp, project_dir);
}


"""Create a mock config object that mimics JacConfig."""
def make_mock_config(project_dir: Path) -> Any {
    config = MagicMock();
    config.project_root = project_dir;
    return config;
}


"""Build a mock registry response."""
def make_mock_registry() -> dict {
    return {
        "version": "1.0.0",
        "components": {
            "button": {
                "file": "button.cl.jac",
                "npmDeps": ["class-variance-authority"],
                "peerComponents": []
            },
            "input": {
                "file": "input.cl.jac",
                "npmDeps": [],
                "peerComponents": []
            },
            "textarea": {
                "file": "textarea.cl.jac",
                "npmDeps": [],
                "peerComponents": []
            },
            "input-group": {
                "file": "input-group.cl.jac",
                "npmDeps": [],
                "peerComponents": ["button", "input", "textarea"]
            },
            "alert-dialog": {
                "file": "alert-dialog.cl.jac",
                "npmDeps": [],
                "peerComponents": ["button"]
            },
            "card": {
                "file": "card.cl.jac",
                "npmDeps": [],
                "peerComponents": []
            }
        },
        "sharedDeps": {
            "clsx": "*",
            "tailwind-merge": "*"
        }
    };
}


"""Build a mock component response."""
def make_mock_component(name: str) -> dict {
    return {
        "name": name,
        "file": name + ".cl.jac",
        "content": 'cl {\n    def:pub ' + name.replace("-", "_").title().replace("_", "") + '(props: Any) -> JsxElement {\n        return <div>{"' + name + '"}</div>;\n    }\n}\n',
        "npmDeps": ["class-variance-authority"] if name == "button" else [],
        "peerComponents": []
    };
}


# ===== _read_kit_config tests =====

test "read kit config returns config when present" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        result = _read_kit_config(config);
        assert result is not None;
        assert result["style"] == "nova";
        assert "registry" in result;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "read kit config returns None when no kit section" {
    tmp = tempfile.mkdtemp(prefix="jac_kit_test_");
    project_dir = Path(tmp) / "test_project";
    project_dir.mkdir();
    (project_dir / "jac.toml").write_text('[project]\nname = "no-kit"\n');
    try {
        config = make_mock_config(project_dir);
        result = _read_kit_config(config);
        assert result is None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "read kit config returns None when no project root" {
    config = MagicMock();
    config.project_root = None;
    result = _read_kit_config(config);
    assert result is None;
}


# ===== _resolve_peer_deps tests =====

test "resolve peer deps no peers" {
    registry = make_mock_registry();
    result = _resolve_peer_deps(["button", "card"], registry, set());
    assert result == ["button", "card"];
}

test "resolve peer deps with peers" {
    registry = make_mock_registry();
    result = _resolve_peer_deps(["input-group"], registry, set());
    assert "input-group" in result;
    assert "button" in result;
    assert "input" in result;
    assert "textarea" in result;
    assert len(result) == 4;
}

test "resolve peer deps skips existing" {
    registry = make_mock_registry();
    existing: set = {"button", "input"};
    result = _resolve_peer_deps(["input-group"], registry, existing);
    assert "input-group" in result;
    assert "textarea" in result;
    assert "button" not in result;
    assert "input" not in result;
    assert len(result) == 2;
}

test "resolve peer deps all existing returns empty" {
    registry = make_mock_registry();
    existing: set = {"button"};
    result = _resolve_peer_deps(["button"], registry, existing);
    assert result == [];
}

test "resolve peer deps unknown component warns" {
    registry = make_mock_registry();
    result = _resolve_peer_deps(["nonexistent"], registry, set());
    assert result == [];
}

test "resolve peer deps transitive via alert-dialog" {
    registry = make_mock_registry();
    result = _resolve_peer_deps(["alert-dialog"], registry, set());
    assert "alert-dialog" in result;
    assert "button" in result;
    assert len(result) == 2;
}

test "resolve peer deps no duplicates" {
    registry = make_mock_registry();
    result = _resolve_peer_deps(["alert-dialog", "input-group"], registry, set());
    button_count = 0;
    for name in result {
        if name == "button" {
            button_count = button_count + 1;
        }
    }
    assert button_count == 1;
}


# ===== _update_npm_deps tests =====

test "update npm deps adds new deps" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        _update_npm_deps(config, {"new-dep": "*", "another-dep": "^1.0"});
        content = (project_dir / "jac.toml").read_text();
        assert "new-dep" in content;
        assert "another-dep" in content;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "update npm deps skips existing" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        content_before = (project_dir / "jac.toml").read_text();
        radix_count_before = content_before.count("radix-ui");
        _update_npm_deps(config, {"radix-ui": "*"});
        content_after = (project_dir / "jac.toml").read_text();
        radix_count_after = content_after.count("radix-ui");
        assert radix_count_before == radix_count_after;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "update npm deps empty dict is noop" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        content_before = (project_dir / "jac.toml").read_text();
        _update_npm_deps(config, {});
        content_after = (project_dir / "jac.toml").read_text();
        assert content_before == content_after;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===== add_kit_components tests =====

test "add single component" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        registry = make_mock_registry();
        button_comp = make_mock_component("button");

        def mock_fetch(url: str) -> Any {
            if "/registry" in url {
                return registry;
            }
            if "/component/button" in url {
                return button_comp;
            }
            return None;
        }

        with patch("jac_client.plugin.kit_handler._fetch_json", side_effect=mock_fetch) {
            result = add_kit_components(config, ["button"]);
        }

        assert result == True;
        ui_dir = project_dir / "components" / "ui";
        assert ui_dir.exists();
        assert (ui_dir / "button.cl.jac").exists();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add component creates utils" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        registry = make_mock_registry();
        button_comp = make_mock_component("button");

        def mock_fetch(url: str) -> Any {
            if "/registry" in url {
                return registry;
            }
            if "/component/button" in url {
                return button_comp;
            }
            return None;
        }

        with patch("jac_client.plugin.kit_handler._fetch_json", side_effect=mock_fetch) {
            add_kit_components(config, ["button"]);
        }

        utils_path = project_dir / "lib" / "utils.cl.jac";
        assert utils_path.exists();
        content = utils_path.read_text();
        assert "twMerge" in content;
        assert "clsx" in content;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add component with peer deps" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        registry = make_mock_registry();

        def mock_fetch(url: str) -> Any {
            if "/registry" in url {
                return registry;
            }
            for name in ["input-group", "button", "input", "textarea"] {
                if ("/component/" + name) in url {
                    return make_mock_component(name);
                }
            }
            return None;
        }

        with patch("jac_client.plugin.kit_handler._fetch_json", side_effect=mock_fetch) {
            result = add_kit_components(config, ["input-group"]);
        }

        assert result == True;
        ui_dir = project_dir / "components" / "ui";
        assert (ui_dir / "input-group.cl.jac").exists();
        assert (ui_dir / "button.cl.jac").exists();
        assert (ui_dir / "input.cl.jac").exists();
        assert (ui_dir / "textarea.cl.jac").exists();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add component skips existing" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        registry = make_mock_registry();

        ui_dir = project_dir / "components" / "ui";
        ui_dir.mkdir(parents=True);
        (ui_dir / "button.cl.jac").write_text("existing content");

        def mock_fetch(url: str) -> Any {
            if "/registry" in url {
                return registry;
            }
            return None;
        }

        with patch("jac_client.plugin.kit_handler._fetch_json", side_effect=mock_fetch) {
            result = add_kit_components(config, ["button"]);
        }

        assert result == True;
        content = (ui_dir / "button.cl.jac").read_text();
        assert content == "existing content";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add multiple components" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        registry = make_mock_registry();

        def mock_fetch(url: str) -> Any {
            if "/registry" in url {
                return registry;
            }
            for name in ["button", "card", "input"] {
                if ("/component/" + name) in url {
                    return make_mock_component(name);
                }
            }
            return None;
        }

        with patch("jac_client.plugin.kit_handler._fetch_json", side_effect=mock_fetch) {
            result = add_kit_components(config, ["button", "card", "input"]);
        }

        assert result == True;
        ui_dir = project_dir / "components" / "ui";
        assert (ui_dir / "button.cl.jac").exists();
        assert (ui_dir / "card.cl.jac").exists();
        assert (ui_dir / "input.cl.jac").exists();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add component updates npm deps" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        registry = make_mock_registry();
        button_comp = make_mock_component("button");

        def mock_fetch(url: str) -> Any {
            if "/registry" in url {
                return registry;
            }
            if "/component/button" in url {
                return button_comp;
            }
            return None;
        }

        with patch("jac_client.plugin.kit_handler._fetch_json", side_effect=mock_fetch) {
            add_kit_components(config, ["button"]);
        }

        content = (project_dir / "jac.toml").read_text();
        assert "class-variance-authority" in content;
        assert "clsx" in content;
        assert "tailwind-merge" in content;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add component no kit section fails" {
    tmp = tempfile.mkdtemp(prefix="jac_kit_test_");
    project_dir = Path(tmp) / "test_project";
    project_dir.mkdir();
    (project_dir / "jac.toml").write_text('[project]\nname = "no-kit"\n');
    try {
        config = make_mock_config(project_dir);
        result = add_kit_components(config, ["button"]);
        assert result == False;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add component registry fetch fails" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);

        def mock_fetch(url: str) -> Any {
            return None;
        }

        with patch("jac_client.plugin.kit_handler._fetch_json", side_effect=mock_fetch) {
            result = add_kit_components(config, ["button"]);
        }

        assert result == False;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add component fetch error skips component" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        registry = make_mock_registry();

        def mock_fetch(url: str) -> Any {
            if "/registry" in url {
                return registry;
            }
            if "/component/button" in url {
                return {"error": "Not found"};
            }
            return None;
        }

        with patch("jac_client.plugin.kit_handler._fetch_json", side_effect=mock_fetch) {
            result = add_kit_components(config, ["button"]);
        }

        assert result == False;
        ui_dir = project_dir / "components" / "ui";
        assert not (ui_dir / "button.cl.jac").exists();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add passes style to component fetch" {
    (tmp, project_dir) = make_kit_project(style="vega");
    try {
        config = make_mock_config(project_dir);
        registry = make_mock_registry();
        button_comp = make_mock_component("button");
        fetched_urls: list = [];

        def mock_fetch(url: str) -> Any {
            fetched_urls.append(url);
            if "/registry" in url {
                return registry;
            }
            if "/component/button" in url {
                return button_comp;
            }
            return None;
        }

        with patch("jac_client.plugin.kit_handler._fetch_json", side_effect=mock_fetch) {
            add_kit_components(config, ["button"]);
        }

        found_style = False;
        for url in fetched_urls {
            if "style=vega" in url {
                found_style = True;
            }
        }
        assert found_style;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "add does not recreate existing utils" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        registry = make_mock_registry();
        button_comp = make_mock_component("button");

        lib_dir = project_dir / "lib";
        lib_dir.mkdir(parents=True);
        (lib_dir / "utils.cl.jac").write_text("custom utils content");

        def mock_fetch(url: str) -> Any {
            if "/registry" in url {
                return registry;
            }
            if "/component/button" in url {
                return button_comp;
            }
            return None;
        }

        with patch("jac_client.plugin.kit_handler._fetch_json", side_effect=mock_fetch) {
            add_kit_components(config, ["button"]);
        }

        content = (lib_dir / "utils.cl.jac").read_text();
        assert content == "custom utils content";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===== remove_kit_components tests =====

test "remove single component" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        ui_dir = project_dir / "components" / "ui";
        ui_dir.mkdir(parents=True);
        (ui_dir / "button.cl.jac").write_text("button content");

        result = remove_kit_components(config, ["button"]);

        assert result == True;
        assert not (ui_dir / "button.cl.jac").exists();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "remove multiple components" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        ui_dir = project_dir / "components" / "ui";
        ui_dir.mkdir(parents=True);
        (ui_dir / "button.cl.jac").write_text("button");
        (ui_dir / "card.cl.jac").write_text("card");
        (ui_dir / "input.cl.jac").write_text("input");

        result = remove_kit_components(config, ["button", "card"]);

        assert result == True;
        assert not (ui_dir / "button.cl.jac").exists();
        assert not (ui_dir / "card.cl.jac").exists();
        assert (ui_dir / "input.cl.jac").exists();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "remove nonexistent component warns" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        ui_dir = project_dir / "components" / "ui";
        ui_dir.mkdir(parents=True);

        result = remove_kit_components(config, ["nonexistent"]);

        assert result == False;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "remove mixed existing and nonexistent" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        ui_dir = project_dir / "components" / "ui";
        ui_dir.mkdir(parents=True);
        (ui_dir / "button.cl.jac").write_text("button");

        result = remove_kit_components(config, ["button", "nonexistent"]);

        assert result == True;
        assert not (ui_dir / "button.cl.jac").exists();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "remove no ui directory fails" {
    (tmp, project_dir) = make_kit_project();
    try {
        config = make_mock_config(project_dir);
        result = remove_kit_components(config, ["button"]);
        assert result == False;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
