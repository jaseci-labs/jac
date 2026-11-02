import os;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.compilation_context { compilation_scope }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.packages.install { sync }
import from jaclang.project.config { JacConfig }
import from tests.packages.fixture_registry {
    FixtureRegistry,
    fresh_dir,
    isolated_env,
    package_toml,
    write_tree
}

def _codes(path: Path, project: Path) -> list[str] {
    program = JacProgram();
    options = CompileOptions(project_root=str(project));
    with compilation_scope(options) {
        program.compile(str(path), options=options);
    }
    return [
        a.code.code
        for a in program.errors_had
        if a.code is not None
    ];
}

test "an import of a module a package does not export is refused" {
    tmp = fresh_dir("jac-boundary-");
    registry = FixtureRegistry.create(tmp / "registry");
    env = isolated_env(tmp, registry.base_dir);
    with patch.dict(os.environ, env) {
        write_tree(
            tmp / "core",
            {
                "jac.toml": package_toml("acme/core", "1.0.0", ["text"]),
                "text.jac": "def shout(s: str) -> str {\n    return s.upper();\n}\n",
                "secret.jac": "def hidden -> int {\n    return 7;\n}\n"
            }
        );
        registry.publish(tmp / "core");
        app = tmp / "app";
        write_tree(
            app,
            {
                "jac.toml": "[project]\nname = \"app\"\n\n[dependencies]\n\"acme/core\" = \"^1\"\n",
                "ok.jac": "import from acme.core.text { shout }\n\nwith entry {\n    print(shout(\"a\"));\n}\n",
                "bad.jac": "import from acme.core.secret { hidden }\n\nwith entry {\n    print(hidden());\n}\n"
            }
        );
        sync(JacConfig.load(app / "jac.toml"));
        assert "E2096" not in _codes(app / "ok.jac", app);
        assert "E2096" in _codes(app / "bad.jac", app);
    }
}

test "a package imports its own modules by their qualified name" {
    tmp = fresh_dir("jac-boundary-");
    pkg = tmp / "lib";
    write_tree(
        pkg,
        {
            "jac.toml": package_toml("acme/lib", "0.1.0", ["api"]),
            "helpers.jac": "def one -> int {\n    return 1;\n}\n",
            "api.jac": "import from acme.lib.helpers { one }\n\ndef two -> int {\n    return one() + 1;\n}\n",
            "bare.jac": "import from helpers { one }\n\ndef three -> int {\n    return one() + 2;\n}\n",
            "rel.jac": "import from .helpers { one }\n\ndef four -> int {\n    return one() + 3;\n}\n"
        }
    );
    assert "E2095" not in _codes(pkg / "api.jac", pkg);
    assert "E2095" not in _codes(pkg / "rel.jac", pkg);
    assert "E2095" in _codes(pkg / "bare.jac", pkg);
}
