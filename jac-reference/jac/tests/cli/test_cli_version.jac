"""The reported jac version comes from the jaclang manifest, which lives in the
repo-root jac.toml, not beside the `jac/` source directory. Probing only
`<source>/jac.toml` missed it and fell back to stale package metadata, so a
dev checkout of 0.38.0 reported 0.16.7."""

import tempfile;
import from pathlib { Path }
import from jaclang.cli.manifest_route { _jaclang_manifest_version }

test "the version comes from the nearest jaclang manifest above the source" {
    with tempfile.TemporaryDirectory() as tmp {
        base = Path(tmp);
        (base / "jac.toml").write_text(
            '[project]\nname = "jaclang"\nversion = "9.8.7"\n', encoding="utf-8"
        );
        site = base / "jac" / "examples" / "site";
        site.mkdir(parents=True);
        (site / "jac.toml").write_text(
            '[project]\nname = "site"\nversion = "1.0.0"\n', encoding="utf-8"
        );
        (base / "jac" / "jaclang").mkdir();
        assert _jaclang_manifest_version(base / "jac") == "9.8.7";
        assert _jaclang_manifest_version(base / "jac" / "jaclang") == "9.8.7";
        assert _jaclang_manifest_version(site) == "9.8.7";
    }
}

test "a tree with no jaclang manifest reports none" {
    with tempfile.TemporaryDirectory() as tmp {
        base = Path(tmp);
        (base / "jac.toml").write_text(
            '[project]\nname = "site"\nversion = "1.0.0"\n', encoding="utf-8"
        );
        assert _jaclang_manifest_version(base) is None;
    }
}
