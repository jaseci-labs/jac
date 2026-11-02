import json;
import os;
import subprocess;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.dist.jab { materialize_jab }
import from jaclang.dist.seal { build_jab }
import from jaclang.packages.install { sync }
import from jaclang.project.config { JacConfig, set_config }
import from tests.packages.fixture_registry {
    FixtureRegistry,
    fresh_dir,
    isolated_env,
    package_toml,
    write_tree
}
import from tests.support { jac_command }

test "an app image carries its packages and runs without the store" {
    tmp = fresh_dir("jac-image-");
    registry = FixtureRegistry.create(tmp / "registry");
    with patch.dict(os.environ, isolated_env(tmp, registry.base_dir)) {
        write_tree(
            tmp / "core",
            {
                "jac.toml": package_toml("acme/core", "1.0.0", ["text"]),
                "text.jac": "def shout(s: str) -> str {\n    return s.upper();\n}\n"
            }
        );
        registry.publish(tmp / "core");
        app = tmp / "app";
        write_tree(
            app,
            {
                "jac.toml": "[project]\nname = \"imgapp\"\nentry-point = \"main\"\n\n[placement]\ndefault = \"server\"\n\n[dependencies]\n\"acme/core\" = \"^1\"\n",
                "main.jac": "import from acme.core.text { shout }\n\nwith entry {\n    print(shout(\"sealed\"));\n}\n"
            }
        );
        config = JacConfig.load(app / "jac.toml");
        sync(config);
        out = tmp / "out" / "imgapp.jab";
        try {
            build_jab(config, out, bake_client=False);
        } finally {
            set_config(None);
        }
        img = materialize_jab(str(out));
        vendored = img / ".jac" / "packages" / "acme" / "core";
        assert (vendored / "text.jac").is_file() and not vendored.is_symlink();
        manifest = json.loads((img / "_precompiled" / "MANIFEST.json").read_text());
        assert manifest["role"] == "app";
        assert manifest.get("packages") == {"acme/core": "1.0.0"} , manifest.get(
            "packages"
        );
        modules = {row["module"] for row in manifest["modules"].values()};
        assert "acme.core.text" in modules , sorted(modules)[:20];
    }
    empty_store = tmp / "no-store";
    env = {** os.environ, "JAC_PACKAGE_STORE": str(empty_store)};
    run = subprocess.run(
        jac_command("run", str(out)),
        cwd=str(tmp),
        capture_output=True,
        text=True,
        env=env
    );
    assert "SEALED" in run.stdout , run.stdout + run.stderr;
}
