import json;
import os;
import subprocess;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.packages.artifact { build_package }
import from jaclang.packages.index { IndexEntry, Registry, forget_registries }
import from jaclang.packages.publish { PublishError, plan_publish }
import from jaclang.packages.verify { verify_index }
import from jaclang.project.config { JacConfig }
import from tests.packages.fixture_registry {
    FixtureRegistry,
    fresh_dir,
    isolated_env,
    package_toml,
    write_tree
}

glob KIT_V1: str = (
         "def area(w: int, h: int) -> int {\n    return w * h;\n}\n\n"
         "def perimeter(w: int, h: int) -> int {\n    return 2 * (w + h);\n}\n"
     ),
     KIT_BREAKING: str = "def area(w: int, h: int) -> int {\n    return w * h;\n}\n";

def _git(repo: Path, *args: str) {
    env = {
        ** os.environ,
        "GIT_AUTHOR_NAME": "t",
        "GIT_AUTHOR_EMAIL": "t@example.com",
        "GIT_COMMITTER_NAME": "t",
        "GIT_COMMITTER_EMAIL": "t@example.com"
    };
    subprocess.run(
        ["git", *args], cwd=str(repo), check=True, env=env, capture_output=True
    );
}

def _kit(base: Path, version: str, body: str) -> JacConfig {
    write_tree(
        base, {"jac.toml": package_toml("acme/kit", version, ["geo"]), "geo.jac": body}
    );
    return JacConfig.load(base / "jac.toml");
}

test "a breaking change needs a major version to publish" {
    tmp = fresh_dir("jac-publish-");
    registry = FixtureRegistry.create(tmp / "registry");
    with patch.dict(os.environ, isolated_env(tmp, registry.base_dir)) {
        _kit(tmp / "v1", "1.0.0", KIT_V1);
        registry.publish(tmp / "v1");
        index = Registry(name="test", url=str(registry.base_dir));
        minor = plan_publish(
            _kit(tmp / "v11", "1.1.0", KIT_BREAKING), index, run_check=False
        );
        assert minor.previous is not None and minor.previous.version == "1.0.0";
        assert any("perimeter" in c.path for c in minor.changes);
        assert any("2.0.0" in p for p in minor.problems) , minor.problems;
        major = plan_publish(
            _kit(tmp / "v2", "2.0.0", KIT_BREAKING), index, run_check=False
        );
        assert not major.problems , major.problems;
        again = plan_publish(
            _kit(tmp / "v1b", "1.0.0", KIT_V1), index, run_check=False
        );
        assert any("already published" in p for p in again.problems);
    }
}

test "a package with a path dependency cannot be published" {
    tmp = fresh_dir("jac-publish-");
    registry = FixtureRegistry.create(tmp / "registry");
    with patch.dict(os.environ, isolated_env(tmp, registry.base_dir)) {
        write_tree(
            tmp / "pkg",
            {
                "jac.toml": package_toml("acme/pkg", "0.1.0", ["m"])
                    + "\n[dependencies]\n\"acme/local\" = { path = \"../local\" }\n",
                "m.jac": "def f -> int {\n    return 1;\n}\n"
            }
        );
        try {
            plan_publish(
                JacConfig.load(tmp / "pkg" / "jac.toml"),
                Registry(name="test", url=str(registry.base_dir)),
                run_check=False
            );
            assert False , "a path dependency must block publishing";
        } except PublishError as e {
            assert "path dependency" in str(e) , str(e);
        }
    }
}

def _index_repo(tmp: Path) -> Path {
    repo = tmp / "index-repo";
    write_tree(
        repo,
        {
            "config.json": json.dumps(
                {"protocol": 1, "blob_base": "blobs/", "repo": "t/i"}
            ),
            "orgs/acme.toml": "owners = [\"alice\"]\n",
            "reserved.txt": "jac\n"
        }
    );
    _git(repo, "init", "-q");
    _git(repo, "add", ".");
    _git(repo, "commit", "-q", "-m", "base");
    _git(repo, "branch", "-M", "main");
    _git(repo, "checkout", "-q", "-b", "change");
    return repo;
}

def _line(built: any, upload: str) -> str {
    return IndexEntry(
        name=built.manifest["name"],
        version=built.manifest["version"],
        sha256=built.sha256,
        role=built.manifest["role"],
        deps=dict(built.manifest.get("deps", {})),
        jac_version=str(built.manifest.get("jac_version", "")),
        api_digest=str(built.manifest.get("api_digest", "")),
        exports=list(built.manifest.get("exports", [])),
        upload=upload
    ).to_line();
}

test "the index verifier accepts a clean publish and rejects edits and strangers" {
    tmp = fresh_dir("jac-verify-");
    repo = _index_repo(tmp);
    with patch.dict(os.environ, {"JAC_PACKAGE_STORE": str(tmp / "store")}) {
        built = build_package(_kit(tmp / "v1", "1.0.0", KIT_V1));
        blob = tmp / f"{built.sha256}.jab";
        blob.write_bytes(built.data);
        write_tree(repo, {"index/acme/kit.json": _line(built, blob.as_uri()) + "\n"});
        _git(repo, "add", ".");
        _git(repo, "commit", "-q", "-m", "publish");
        forget_registries();
        ok = verify_index(repo, "main", "alice", any_upload=True);
        assert not ok.problems , ok.problems;
        assert ok.mirror == [{"sha256": built.sha256, "upload": blob.as_uri()}];
        stranger = verify_index(repo, "main", "mallory", any_upload=True);
        assert any("not an owner" in p for p in stranger.problems);
        remote = verify_index(repo, "main", "alice");
        assert any("GitHub release asset" in p for p in remote.problems);
        _git(repo, "checkout", "-q", "-b", "edit");
        _git(repo, "reset", "-q", "--hard", "change");
        edited = json.loads(_line(built, blob.as_uri()));
        edited["deps"] = {"acme/other": "^1"};
        write_tree(repo, {"index/acme/kit.json": json.dumps(edited) + "\n"});
        _git(repo, "add", ".");
        _git(repo, "commit", "-q", "-m", "publish-bad");
        bad = verify_index(repo, "main", "alice", any_upload=True);
        assert any("deps differ" in p for p in bad.problems) , bad.problems;
    }
}
