import json;
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.packages.artifact { build_package }
import from jaclang.packages.index { IndexEntry, forget_registries }
import from jaclang.project.config { JacConfig }

def write_tree(base_dir: Path, files: dict[str, str]) {
    for (rel, body) in files.items() {
        target = base_dir / rel;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(body, encoding="utf-8");
    }
}

def package_toml(
    name: str,
    version: str,
    exports: list[str],
    deps: dict[str, str] | None = None,
    extra: str = ""
) -> str {
    lines = [
        "[project]",
        f"name = \"{name}\"",
        f"version = \"{version}\"",
        "jac-version = \">=0.1\"",
        "exports = [" + ", ".join([f"\"{e}\"" for e in exports]) + "]",
        "",
        "[project.urls]",
        f"repository = \"https://github.com/{name}\"",
        ""
    ];
    if deps {
        lines.append("[dependencies]");
        for (dep, req) in deps.items() {
            lines.append(f"\"{dep}\" = \"{req}\"");
        }
        lines.append("");
    }
    return "\n".join(lines) + extra;
}

obj FixtureRegistry {
    has base_dir: Path;

    static def create(base_dir: Path) -> FixtureRegistry {
        base_dir.mkdir(parents=True, exist_ok=True);
        (base_dir / "config.json").write_text(
            json.dumps({"protocol": 1, "blob_base": "blobs/", "repo": "test/index"}),
            encoding="utf-8"
        );
        (base_dir / "blobs").mkdir(exist_ok=True);
        return FixtureRegistry(base_dir=base_dir);
    }

    def publish(project_dir: Path, role: str = "lib") -> IndexEntry {
        cfg = JacConfig.load(project_dir / "jac.toml");
        built = build_package(cfg);
        (self.base_dir / "blobs" / f"{built.sha256}.jab").write_bytes(built.data);
        row = IndexEntry(
            name=built.manifest["name"],
            version=built.manifest["version"],
            sha256=built.sha256,
            role=built.manifest["role"],
            deps=dict(built.manifest.get("deps", {})),
            pypi=dict(built.manifest.get("pypi", {})),
            npm=dict(built.manifest.get("npm", {})),
            jac_version=str(built.manifest.get("jac_version", "")),
            api_digest=str(built.manifest.get("api_digest", "")),
            exports=list(built.manifest.get("exports", []))
        );
        index_file = self.base_dir / "index" / f"{row.name}.json";
        index_file.parent.mkdir(parents=True, exist_ok=True);
        with open(index_file, "a", encoding="utf-8") as fh {
            fh.write(row.to_line() + "\n");
        }
        forget_registries();
        return row;
    }
}

def isolated_env(tmp: Path, registry: Path) -> dict[str, str] {
    return {"JAC_PACKAGE_STORE": str(tmp / "store"), "JAC_REGISTRY": str(registry)};
}

def fresh_dir(prefix: str) -> Path {
    return Path(os.path.realpath(tempfile.mkdtemp(prefix=prefix)));
}
