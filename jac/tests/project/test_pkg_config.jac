"""Tests for publishing fields in [project], [entrypoints], and [optional-dependencies]."""

import from jaclang.project.config { JacConfig }

# [project] publishing fields ---------------------------------------------------------------
test "parse project section populates publishing fields" {
    toml_str = """
[project]
name = "byllm"
version = "0.6.4"
description = "byLLM plugin"
requires-python = ">=3.11"
license = "MIT"
keywords = ["llm", "jac"]
readme = "README.md"
""";
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.project.name == "byllm";
    assert cfg.project.version == "0.6.4";
    assert cfg.project.description == "byLLM plugin";
    assert cfg.project.requires_python == ">=3.11";
    assert cfg.project.license == "MIT";
    assert cfg.project.keywords == ["llm", "jac"];
    assert cfg.project.readme == "README.md";
}

test "project authors and maintainers parsed as PersonConfig list" {
    toml_str = """
[project]
name = "p"
version = "1.0.0"

[[project.authors]]
name = "Jason Mars"
email = "jason@mars.ninja"

[[project.maintainers]]
name = "Jane Doe"
email = "jane@example.com"
""";
    cfg = JacConfig.from_toml_str(toml_str);
    assert len(cfg.project.authors) == 1;
    assert cfg.project.authors[0].name == "Jason Mars";
    assert cfg.project.authors[0].email == "jason@mars.ninja";
    assert cfg.project.maintainers[0].name == "Jane Doe";
}

test "project include packages and data parsed" {
    toml_str = """
[project]
name = "p"
version = "1.0.0"

[project.include]
packages = ["byllm*"]

[project.include.data]
byllm = ["*.jir"]
""";
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.project.include.packages == ["byllm*"];
    assert "byllm" in cfg.project.include.data;
    assert "*.jir" in cfg.project.include.data["byllm"];
}

test "project without publishing fields still has empty defaults" {
    cfg = JacConfig.from_toml_str("[project]\nname = \"myproj\"\n");
    assert cfg.project.name == "myproj";
    assert cfg.project.requires_python == "";
    assert cfg.project.keywords == [];
    assert cfg.project.maintainers == [];
}

test "project urls parsed" {
    toml_str = '[project]\nname = "p"\nversion = "1.0.0"\n\n[project.urls]\nrepository = "https://github.com/user/p"\nhomepage = "https://p.dev"\n';
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.project.urls["repository"] == "https://github.com/user/p";
    assert cfg.project.urls["homepage"] == "https://p.dev";
}

# [entrypoints] parsing -----------------------------------------------------------------------
test "entrypoints parsed into nested dict" {
    toml_str = '[project]\nname = "p"\nversion = "1.0.0"\n\n[entrypoints.jac]\nbyllm = "byllm.plugin:JacRuntime"\nbyllm_config = "byllm.plugin_config:Config"\n';
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.entrypoints["jac"]["byllm"] == "byllm.plugin:JacRuntime";
    assert cfg.entrypoints["jac"]["byllm_config"] == "byllm.plugin_config:Config";
}

# [optional-dependencies] parsing -------------------------------------------------------------
test "optional-dependencies parsed into nested dict" {
    toml_str = '[project]\nname = "p"\nversion = "1.0.0"\n\n[optional-dependencies.tools]\nwikipedia = "*"\n\n[optional-dependencies.video]\nopencv-python-headless = ">=4.0"\n';
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.optional_dependencies["tools"]["wikipedia"] == "*";
    assert cfg.optional_dependencies["video"]["opencv-python-headless"] == ">=4.0";
}
