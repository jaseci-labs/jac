"""Dependency staleness: node_modules must re-sync when the generated
manifest changes (editing [dependencies.npm] previously never re-ran bun
install once node_modules existed, so new packages failed to resolve)."""

import hashlib;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.client.vite_bundler { client_deps_stale }

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
