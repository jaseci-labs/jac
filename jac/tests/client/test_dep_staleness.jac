"""Dependency staleness: node_modules must re-sync when the generated
manifest changes (editing [dependencies.npm] previously never re-ran bun
install once node_modules existed, so new packages failed to resolve)."""

import hashlib;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.client.vite_bundler { ViteBundler, client_deps_stale }

def _tree -> Path {
    d = Path(tempfile.mkdtemp(prefix="jacdeps_"));
    (d / "configs").mkdir();
    (d / "node_modules").mkdir();
    return d;
}

test "missing node_modules is stale" {
    d = Path(tempfile.mkdtemp(prefix="jacdeps_"));
    try {
        assert client_deps_stale(d);
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "matching marker is fresh; manifest edit flips to stale" {
    d = _tree();
    try {
        manifest = d / "configs" / "package.json";
        manifest.write_text('{"dependencies": {"a": "1"}}');
        digest = hashlib.sha256(manifest.read_bytes()).hexdigest();
        (d / "node_modules" / ".jac-deps-hash").write_text(digest);
        assert not client_deps_stale(d);
        manifest.write_text('{"dependencies": {"a": "1", "b": "2"}}');
        assert client_deps_stale(d);
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "existing node_modules without a marker is stale" {
    d = _tree();
    try {
        (d / "configs" / "package.json").write_text("{}");
        assert client_deps_stale(d);
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

class _RecordingBundler(ViteBundler) {
    has saw_stale: bool = False;

    override def install_packages(
        self: _RecordingBundler,
        install_dir: Path | None = None,
        force: bool = False,
        capture_output: bool = False,
        clean_stale: bool = False
    ) -> None {
        self.saw_stale = install_dir is not None and client_deps_stale(install_dir);
    }
}

def _project_manifest(deps: str) -> str {
    return '[project]\nname = "deps"\nkind = "web-app"\n\n[dependencies.npm]\n' + deps;
}

test "dev server re-syncs node_modules after a jac.toml dependency edit" {
    import from jaclang.project.config { JacConfig, get_config, set_config }

    previous = get_config();
    project = Path(tempfile.mkdtemp(prefix="jacdeps_"));
    try {
        toml = project / "jac.toml";
        before = _project_manifest('a = "1"\n');
        toml.write_text(before);
        set_config(JacConfig.from_toml_str(before, toml));
        first = _RecordingBundler(project);
        build_dir = first._get_client_dir();
        manifest = first.create_package_json();
        (build_dir / "node_modules").mkdir();
        (build_dir / "node_modules" / ".jac-deps-hash").write_text(
            hashlib.sha256(manifest.read_bytes()).hexdigest()
        );
        first._ensure_dev_dependencies(build_dir);
        assert not first.saw_stale , "an unchanged jac.toml must not reinstall";

        after = _project_manifest('a = "1"\nb = "2"\n');
        toml.write_text(after);
        set_config(JacConfig.from_toml_str(after, toml));
        second = _RecordingBundler(project);
        second._ensure_dev_dependencies(build_dir);
        assert '"b"' in manifest.read_text() , "the manifest must follow jac.toml";
        assert second.saw_stale , "a new dependency must trigger a reinstall";
    } finally {
        set_config(previous);
        shutil.rmtree(project, ignore_errors=True);
    }
}
