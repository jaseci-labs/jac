"""Tests for jac-shadcn lockfile helpers."""

import tempfile;
import from pathlib { Path }
import from jac_shadcn.lockfile {
    lockfile_path,
    load_lockfile,
    save_lockfile,
    record_install,
    record_remove,
    compute_orphan_deps,
    installed_version,
}


test "load_lockfile returns empty dict when file missing" {
    with tempfile.TemporaryDirectory() as tmpdir {
        result = load_lockfile(Path(tmpdir));
        assert result == {};
        assert not lockfile_path(Path(tmpdir)).exists();
    }
}


test "record_install writes a single entry" {
    with tempfile.TemporaryDirectory() as tmpdir {
        record_install(
            Path(tmpdir), "button", "1.0.0", ["class-variance-authority", "radix-ui"]
        );
        data = load_lockfile(Path(tmpdir));
        assert data["version"] == 1;
        assert "button" in data["components"];
        entry = data["components"]["button"];
        assert entry["version"] == "1.0.0";
        assert "class-variance-authority" in entry["npm_deps"];
        assert "radix-ui" in entry["npm_deps"];
    }
}


test "record_install upserts when same name written twice" {
    with tempfile.TemporaryDirectory() as tmpdir {
        record_install(Path(tmpdir), "button", "1.0.0", ["clsx"]);
        record_install(Path(tmpdir), "button", "2.0.0", ["clsx", "radix-ui"]);
        data = load_lockfile(Path(tmpdir));
        entry = data["components"]["button"];
        assert entry["version"] == "2.0.0";
        assert "radix-ui" in entry["npm_deps"];
    }
}


test "record_remove drops the entry" {
    with tempfile.TemporaryDirectory() as tmpdir {
        record_install(Path(tmpdir), "button", "1.0.0", ["clsx"]);
        record_install(Path(tmpdir), "card", "1.0.0", ["clsx"]);
        record_remove(Path(tmpdir), "button");
        data = load_lockfile(Path(tmpdir));
        assert "button" not in data["components"];
        assert "card" in data["components"];
    }
}


test "record_remove is a no-op for missing entry" {
    with tempfile.TemporaryDirectory() as tmpdir {
        record_install(Path(tmpdir), "card", "1.0.0", ["clsx"]);
        record_remove(Path(tmpdir), "button");
        data = load_lockfile(Path(tmpdir));
        assert "card" in data["components"];
    }
}


test "compute_orphan_deps returns deps unique to removed components" {
    with tempfile.TemporaryDirectory() as tmpdir {
        record_install(
            Path(tmpdir), "button", "1.0.0", ["class-variance-authority", "radix-ui"]
        );
        record_install(Path(tmpdir), "card", "1.0.0", ["class-variance-authority"]);
        # Remove button only. radix-ui is unique to button -> orphan.
        # class-variance-authority is also used by card -> NOT an orphan.
        orphans = compute_orphan_deps(Path(tmpdir), ["button"]);
        assert "radix-ui" in orphans;
        assert "class-variance-authority" not in orphans;
    }
}


test "compute_orphan_deps returns all deps when removing the last user" {
    with tempfile.TemporaryDirectory() as tmpdir {
        record_install(Path(tmpdir), "card", "1.0.0", ["clsx", "shared-thing"]);
        orphans = compute_orphan_deps(Path(tmpdir), ["card"]);
        assert "clsx" in orphans;
        assert "shared-thing" in orphans;
    }
}


test "compute_orphan_deps handles missing lockfile gracefully" {
    with tempfile.TemporaryDirectory() as tmpdir {
        orphans = compute_orphan_deps(Path(tmpdir), ["button"]);
        assert orphans == [];
    }
}


test "installed_version returns recorded version or None" {
    with tempfile.TemporaryDirectory() as tmpdir {
        assert installed_version(Path(tmpdir), "button") is None;
        record_install(Path(tmpdir), "button", "1.2.3", []);
        assert installed_version(Path(tmpdir), "button") == "1.2.3";
    }
}


test "save_lockfile roundtrip preserves data" {
    with tempfile.TemporaryDirectory() as tmpdir {
        data = {
            "version": 1,
            "components": {
                "button": {"version": "1.0.0", "npm_deps": ["clsx", "radix-ui"]}
            }
        };
        save_lockfile(Path(tmpdir), data);
        loaded = load_lockfile(Path(tmpdir));
        assert loaded["version"] == 1;
        assert loaded["components"]["button"]["version"] == "1.0.0";
        assert "clsx" in loaded["components"]["button"]["npm_deps"];
    }
}
