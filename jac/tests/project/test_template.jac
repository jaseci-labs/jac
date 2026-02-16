"""Tests for template bundling infrastructure."""

import json;
import os;
import base64;
import shutil;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.project.template_loader {
    bundle_template,
    load_template_from_json,
    load_template_from_directory
}
import from jaclang.project.template_registry {
    ProjectTemplate,
    get_template_registry,
    initialize_template_registry
}

glob FIXTURE_BASE = str(Path(__file__).parent / "fixtures");

def fixture_path(filename: str) -> str {
    p = os.path.join(FIXTURE_BASE, filename);
    if not os.path.exists(p) {
        raise FileNotFoundError(f"Fixture not found: {p}") ;
    }
    return p;
}

# --- BundleTemplate tests ---
test "bundle creates jacpack file" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(fixture_path("templates/minimal"));
        output_path = Path(tmpdir) / "minimal.jacpack";
        bundle_template(template_dir, output_path);
        assert output_path.exists();
        assert output_path.stat().st_size > 0;
    }
}

test "bundle contains required fields" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(fixture_path("templates/minimal"));
        output_path = Path(tmpdir) / "minimal.jacpack";
        bundle_template(template_dir, output_path);
        with open(output_path) as f {
            data = json.load(f);
        }
        assert data["name"] == "minimal";
        assert data["description"] == "A minimal test template";
        assert "config" in data;
        assert "files" in data;
        assert "directories" in data;
    }
}

test "bundle includes version metadata" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(fixture_path("templates/minimal"));
        output_path = Path(tmpdir) / "minimal.jacpack";
        bundle_template(template_dir, output_path);
        with open(output_path) as f {
            data = json.load(f);
        }
        assert data["jaclang"] == "0.9.0";
        assert "plugins" in data;
        assert len(data["plugins"]) == 1;
        assert data["plugins"][0]["name"] == "test-plugin";
        assert data["plugins"][0]["version"] == "1.0.0";
    }
}

test "bundle embeds file contents" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(fixture_path("templates/minimal"));
        output_path = Path(tmpdir) / "minimal.jacpack";
        bundle_template(template_dir, output_path);
        with open(output_path) as f {
            data = json.load(f);
        }
        assert "main.jac" in data["files"];
        assert "README.md" in data["files"];
        assert "{{name}}" in data["files"]["main.jac"];
    }
}

test "bundle missing directory raises" {
    with TemporaryDirectory() as tmpdir {
        raised = False;
        try {
            bundle_template(Path(tmpdir) / "nonexistent", Path(tmpdir) / "out.jacpack");
        } except ValueError as e {
            raised = True;
            assert "Template directory not found" in str(e);
        }
        assert raised , "Expected ValueError for missing directory";
    }
}

test "bundle missing manifest raises" {
    with TemporaryDirectory() as tmpdir {
        empty_dir = Path(tmpdir) / "empty";
        empty_dir.mkdir();
        raised = False;
        try {
            bundle_template(empty_dir, Path(tmpdir) / "out.jacpack");
        } except ValueError as e {
            raised = True;
            assert "No jac.toml found" in str(e);
        }
        assert raised , "Expected ValueError for missing manifest";
    }
}

test "bundle handles binary files" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(tmpdir) / "binary_template";
        template_dir.mkdir();
        assets_dir = template_dir / "assets";
        assets_dir.mkdir();
        jac_toml = template_dir / "jac.toml";
        jac_toml.write_text(
            "[project]\nname = \"{{name}}\"\nversion = \"0.1.0\"\nentry-point = \"main.jac\"\n\n[jacpack]\nname = \"binary-test\"\ndescription = \"Template with binary files\"\njaclang = \"0.9.0\"\n"
        );
        main_jac = template_dir / "main.jac";
        main_jac.write_text('print("Hello");');
        binary_content = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR" + bytes(range(256));
        binary_file = assets_dir / "test.png";
        binary_file.write_bytes(binary_content);
        output_path = Path(tmpdir) / "binary-test.jacpack";
        bundle_template(template_dir, output_path);
        with open(output_path) as f {
            data = json.load(f);
        }
        assert "main.jac" in data["files"];
        assert not data["files"]["main.jac"].startswith("base64:");
        assert "assets/test.png" in data["files"];
        assert data["files"]["assets/test.png"].startswith("base64:");
        encoded = data["files"]["assets/test.png"][7:];
        decoded = base64.b64decode(encoded);
        assert decoded == binary_content;
    }
}

# --- LoadTemplateFromJson tests ---
test "load returns project template" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(fixture_path("templates/minimal"));
        jacpack_path = Path(tmpdir) / "minimal.jacpack";
        bundle_template(template_dir, jacpack_path);
        template = load_template_from_json(jacpack_path);
        assert isinstance(template, ProjectTemplate);
        assert template.name == "minimal";
        assert template.description == "A minimal test template";
    }
}

test "load preserves files" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(fixture_path("templates/minimal"));
        jacpack_path = Path(tmpdir) / "minimal.jacpack";
        bundle_template(template_dir, jacpack_path);
        template = load_template_from_json(jacpack_path);
        assert "main.jac" in template.files;
        assert "README.md" in template.files;
    }
}

test "load missing file raises" {
    with TemporaryDirectory() as tmpdir {
        raised = False;
        try {
            load_template_from_json(Path(tmpdir) / "nonexistent.jacpack");
        } except ValueError as e {
            raised = True;
            assert "Template JSON not found" in str(e);
        }
        assert raised , "Expected ValueError for missing file";
    }
}

# --- LoadTemplateFromDirectory tests ---
test "load from directory" {
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    assert isinstance(template, ProjectTemplate);
    assert template.name == "minimal";
}

test "load extracts config" {
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    assert "project" in template.config;
    assert template.config["project"]["name"] == "{{name}}";
    assert template.config["project"]["entry-point"] == "main.jac";
}

# --- RoundTrip tests ---
test "round trip preserves data" {
    with TemporaryDirectory() as tmpdir {
        template_dir = Path(fixture_path("templates/minimal"));
        jacpack_path = Path(tmpdir) / "minimal.jacpack";
        original = load_template_from_directory(template_dir);
        bundle_template(template_dir, jacpack_path);
        loaded = load_template_from_json(jacpack_path);
        assert original.name == loaded.name;
        assert original.description == loaded.description;
        assert original.config == loaded.config;
        assert original.files == loaded.files;
        assert original.directories == loaded.directories;
        assert original.root_gitignore_entries == loaded.root_gitignore_entries;
    }
}

# --- ProjectTemplate.to_dict tests ---
test "to dict includes all fields" {
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    data = template.to_dict();
    assert "name" in data;
    assert "description" in data;
    assert "config" in data;
    assert "files" in data;
    assert "directories" in data;
    assert "root_gitignore_entries" in data;
}

test "to dict excludes post create" {
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    data = template.to_dict();
    assert "post_create" not in data;
}

# --- TemplateRegistration tests ---
test "register template from dict" {
    initialize_template_registry();
    registry = get_template_registry();
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    registry.register(template.to_dict());
    assert registry.has_template("minimal");
}

test "get registered template" {
    initialize_template_registry();
    registry = get_template_registry();
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    registry.register(template.to_dict());
    retrieved = registry.get("minimal");
    assert retrieved is not None;
    assert retrieved.name == "minimal";
    assert retrieved.description == "A minimal test template";
}

test "list templates includes registered" {
    initialize_template_registry();
    registry = get_template_registry();
    template_dir = Path(fixture_path("templates/minimal"));
    template = load_template_from_directory(template_dir);
    registry.register(template.to_dict());
    templates = registry.list_templates();
    names = [name for (name, _) in templates];
    assert "minimal" in names;
}
