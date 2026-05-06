"""Tests for the [package], [entrypoints], and [optional-dependencies] fields
added to JacConfig in this branch (project/config.jac, impl/config.impl.jac).
"""

import from jaclang.project.config { JacConfig }

# [package] parsing -------------------------------------------------------------------------
test "parse package section populates PackageConfig" {
    toml_str = """
[package]
name = "byllm"
version = "0.6.4"
description = "byLLM plugin"
requires-python = ">=3.11"
license = "MIT"
keywords = ["llm", "jac"]
readme = "README.md"
""";
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.package is not None;
    assert cfg.package.name == "byllm";
    assert cfg.package.version == "0.6.4";
    assert cfg.package.description == "byLLM plugin";
    assert cfg.package.requires_python == ">=3.11";
    assert cfg.package.license == "MIT";
    assert cfg.package.keywords == ["llm", "jac"];
    assert cfg.package.readme == "README.md";
}

test "package authors and maintainers parsed as PersonConfig list" {
    toml_str = """
[package]
name = "p"
version = "1.0.0"

[[package.authors]]
name = "Jason Mars"
email = "jason@mars.ninja"

[[package.maintainers]]
name = "Jane Doe"
email = "jane@example.com"
""";
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.package is not None;
    assert len(cfg.package.authors) == 1;
    assert cfg.package.authors[0].name == "Jason Mars";
    assert cfg.package.authors[0].email == "jason@mars.ninja";
    assert cfg.package.maintainers[0].name == "Jane Doe";
}

test "package include packages and data parsed" {
    toml_str = """
[package]
name = "p"
version = "1.0.0"

[package.include]
packages = ["byllm*"]

[package.include.data]
byllm = ["*.jir"]
""";
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.package is not None;
    assert cfg.package.include.packages == ["byllm*"];
    assert "byllm" in cfg.package.include.data;
    assert "*.jir" in cfg.package.include.data["byllm"];
}

test "package section absent leaves cfg.package as None" {
    cfg = JacConfig.from_toml_str("[project]\nname = \"myproj\"\n");
    assert cfg.package is None;
}

test "package urls parsed" {
    toml_str = '[package]\nname = "p"\nversion = "1.0.0"\n\n[package.urls]\nrepository = "https://github.com/user/p"\nhomepage = "https://p.dev"\n';
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.package is not None;
    assert cfg.package.urls["repository"] == "https://github.com/user/p";
    assert cfg.package.urls["homepage"] == "https://p.dev";
}

# [entrypoints] parsing -------------------------------------------------------------------------
test "entrypoints parsed into nested dict" {
    toml_str = '[package]\nname = "p"\nversion = "1.0.0"\n\n[entrypoints.jac]\nbyllm = "byllm.plugin:JacRuntime"\nbyllm_config = "byllm.plugin_config:Config"\n';
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.entrypoints["jac"]["byllm"] == "byllm.plugin:JacRuntime";
    assert cfg.entrypoints["jac"]["byllm_config"] == "byllm.plugin_config:Config";
}

# [optional-dependencies] parsing ----------------------------------------------------------------------
test "optional-dependencies parsed into nested dict" {
    toml_str = '[package]\nname = "p"\nversion = "1.0.0"\n\n[optional-dependencies.tools]\nwikipedia = "*"\n\n[optional-dependencies.video]\nopencv-python-headless = ">=4.0"\n';
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.optional_dependencies["tools"]["wikipedia"] == "*";
    assert cfg.optional_dependencies["video"]["opencv-python-headless"] == ">=4.0";
}
