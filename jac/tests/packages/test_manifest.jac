import tempfile;
import tomllib;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.project.dependencies { ManifestError, PackageDep }
import from jaclang.packages.migrate { migrate_manifest }

glob MODERN: str = (
         "[project]\nname = \"acme/app\"\nversion = \"1.0.0\"\n"
         "exports = [\"core\"]\n\n"
         "[dependencies]\n\"jaseci/vecdb\" = \"^2.1\"\n"
         "\"acme/util\" = { path = \"../util\" }\n"
         "\"acme/fork\" = { git = \"https://example.com/fork.git\", rev = \"v1\" }\n\n"
         "[dependencies.pypi]\nnumpy = \">=2\"\n"
         "privlib = { git = \"https://example.com/p.git\", branch = \"main\" }\n\n"
         "[dependencies.npm]\nd3 = \"^7\"\n\n"
         "[dev-dependencies]\n\"acme/testkit\" = \"^0.3\"\n\n"
         "[dev-dependencies.pypi]\npytest = \">=8\"\n\n"
         "[registries]\ninternal = \"https://example.com/index/\"\n"
     ),
     LEGACY: str = (
         "[project]\nname = \"old\"\n\n"
         "# the app's own deps\n"
         "[dependencies]\nrequests = \">=2.28\"\nnumpy = \"~=2.0\"\n\n"
         "[dependencies.git]\nmylib = { git = \"https://example.com/m.git\", branch = \"main\" }\n\n"
         "[dependencies.npm]\nreact = \"^19\"\n\n"
         "[dev-dependencies]\npytest = \">=8\"\n"
     );

test "the dependency tables split Jac packages from PyPI and npm" {
    cfg = JacConfig.from_toml_str(MODERN);
    assert sorted(cfg.dependencies) == ["acme/fork", "acme/util", "jaseci/vecdb"];
    assert cfg.dependencies["jaseci/vecdb"].version == "^2.1";
    assert cfg.dependencies["jaseci/vecdb"].kind() == "registry";
    assert cfg.dependencies["acme/util"].kind() == "path";
    assert cfg.dependencies["acme/fork"].rev == "v1";
    assert cfg.pypi_dependencies == {"numpy": ">=2"};
    assert cfg.pypi_git_dependencies["privlib"]["git"] == "https://example.com/p.git";
    assert cfg.plugin_dependencies["npm"] == {"d3": "^7"};
    assert list(cfg.dev_dependencies) == ["acme/testkit"];
    assert cfg.pypi_dev_dependencies == {"pytest": ">=8"};
    assert cfg.registries == {"internal": "https://example.com/index/"};
    assert cfg.project.exports == ["core"];
}

test "a bare PyPI name under [dependencies] is an error that names the move" {
    for text in (
        "[dependencies]\nrequests = \">=2\"\n",
        "[dependencies.git]\nlib = { git = \"https://x/y.git\" }\n",
        "[dependencies]\nlib = { path = \"../lib\" }\n",
        "[dependencies]\nlib = { git = \"https://x/y.git\", rev = \"abc\" }\n"
    ) {
        try {
            JacConfig.from_toml_str(text);
            assert False , text;
        } except ManifestError as e {
            assert "jac fix dependencies" in str(e) or "org/name" in str(e) , str(e);
        }
    }
}

test "an unscoped table under [dependencies] belongs to a plugin ecosystem" {
    cfg = JacConfig.from_toml_str(
        "[dependencies.system]\ngit = \"*\"\nffmpeg = \"*\"\n"
    );
    assert cfg.get_plugin_deps("system") == {"git": "*", "ffmpeg": "*"};
    assert not cfg.dependencies;
    only_git = JacConfig.from_toml_str("[dependencies.system]\ngit = \"*\"\n");
    assert only_git.get_plugin_deps("system") == {"git": "*"};
}

test "a package dependency serializes back to the form it was written in" {
    assert PackageDep(name="a/b", version="^1").to_toml() == "^1";
    assert PackageDep(name="a/b", path="../b").to_toml() == {"path": "../b"};
    assert PackageDep(name="a/b", git="https://x", rev="v1").to_toml()
        == {"git": "https://x", "rev": "v1"};
}

test "saving the manifest keeps both kinds of dependencies" {
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "jac.toml";
        path.write_text(MODERN);
        cfg = JacConfig.load(path);
        cfg.add_dependency("jaseci/extra", "^1", dep_type="jac");
        cfg.add_dependency("pandas", ">=2", dep_type="pypi");
        cfg.remove_dependency("acme/util", dep_type="jac");
        cfg.save();
        again = JacConfig.load(path);
        assert "jaseci/extra" in again.dependencies;
        assert "acme/util" not in again.dependencies;
        assert again.pypi_dependencies["pandas"] == ">=2";
        assert again.pypi_git_dependencies["privlib"]["branch"] == "main";
        assert again.plugin_dependencies["npm"] == {"d3": "^7"};
    }
}

test "jac fix dependencies moves PyPI entries without touching the rest" {
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "jac.toml";
        path.write_text(LEGACY);
        result = migrate_manifest(path);
        assert sorted(result.moved)
            == [
                "dependencies.git",
                "dependencies.numpy",
                "dependencies.requests",
                "dev-dependencies.pytest"
            ];
        doc = tomllib.loads(result.text);
        assert doc["dependencies"]["pypi"]["requests"] == ">=2.28";
        assert doc["dependencies"]["pypi"]["mylib"]["git"]
            == "https://example.com/m.git";
        assert doc["dependencies"]["npm"] == {"react": "^19"};
        assert doc["dev-dependencies"]["pypi"] == {"pytest": ">=8"};
        assert "# the app's own deps" in result.text;
        path.write_text(result.text);
        cfg = JacConfig.load(path);
        assert cfg.pypi_dependencies == {"requests": ">=2.28", "numpy": "~=2.0"};
        assert not cfg.dependencies;
        assert not migrate_manifest(path).moved;
    }
}
