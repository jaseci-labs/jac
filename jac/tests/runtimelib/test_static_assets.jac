"""The shared static-asset resolver: one jailed, ordered root table that every
run mode serves from. Real temp trees and real Path resolution, no mocks."""

import os;
import tempfile;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.server.serving.static_assets {
    AssetRoot,
    asset_root_table,
    resolve_asset,
    asset_cache_policy
}


# Create proj/rel with `data`, making parent dirs.
def _write(proj: Path, rel: str, data: bytes) {
    target = proj / rel;
    target.parent.mkdir(parents=True, exist_ok=True);
    target.write_bytes(data);
}


# The table for a project whose client build is at .jac/client/dist.
def _table(proj: Path) -> list[AssetRoot] {
    return asset_root_table(proj, proj / ".jac" / "client" / "dist");
}


test "asset URLs resolve to the first root that has the exact file" {
    with TemporaryDirectory() as tmp {
        proj = Path(tempfile.mkdtemp(dir=tmp));
        for (rel, data) in [
            ("public/brand/logo.png", b"PNG"),
            ("public/manifest.webmanifest", b"{}"),
            ("public/app.wasm", b"WASM"),
            (".jac/client/dist/index.html", b"DIST"),
            ("public/index.html", b"PUBLIC"),
            ("assets/img/icon.svg", b"SVG")
        ] {
            _write(proj, rel, data);
        }
        # A workspace app's own public/ comes before the workspace's.
        ws = Path(tempfile.mkdtemp(dir=tmp));
        for (rel, data) in [
            (
                "jac.toml",
                b'[project]\nname = "acme"\ndefault-app = "web"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n'
            ),
            ("web/main.jac", b'with entry {\n    print("hi");\n}\n'),
            ("web/public/shared.txt", b"FROM_APP"),
            ("public/shared.txt", b"FROM_WORKSPACE"),
            ("public/site.txt", b"WORKSPACE_ONLY")
        ] {
            _write(ws, rel, data);
        }
        # The served app is the runtime target, as `jac start web/main.jac` sets it.
        previous = Jac.get_full_target_path();
        Jac.set_full_target_path(str(ws / "web" / "main.jac"));
        try {
            ws_table = _table(ws);
        } finally {
            Jac.set_full_target_path(previous or "");
        }
        # (table, URL, expected bytes): public/ at the web root with no
        # extension allowlist, the built dist ahead of public/, assets/ at its
        # real path under /static/assets/
        for (table, url, expected) in [
            (_table(proj), "/brand/logo.png", b"PNG"),
            (_table(proj), "/manifest.webmanifest", b"{}"),
            (_table(proj), "/app.wasm", b"WASM"),
            (_table(proj), "/index.html", b"DIST"),
            (_table(proj), "/static/assets/img/icon.svg", b"SVG"),
            (ws_table, "/shared.txt", b"FROM_APP"),
            (ws_table, "/site.txt", b"WORKSPACE_ONLY")
        ] {
            hit = resolve_asset(table, url);
            assert hit is not None and hit.read_bytes() == expected , (url, hit);
        }
    }
}


test "nothing outside the declared roots, and no shorter alias, resolves" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        for (rel, data) in [
            ("public/logo.png", b"OK"),
            ("package.json", b"{}"),
            ("src/app.js", b"source"),
            ("secret.txt", b"classified"),
            # a project-root dist/ is excluded from the --scale bundle, so it is
            # a miss in every mode
            ("dist/legacy.png", b"LEGACY"),
            ("assets/logo.png", b"LOGO"),
            ("assets/img/icon.svg", b"SVG")
        ] {
            _write(proj, rel, data);
        }
        os.symlink(str(proj / "secret.txt"), str(proj / "public" / "link.txt"));
        table = _table(proj);
        # positive control, so the misses below cannot pass vacuously
        assert resolve_asset(table, "/logo.png") is not None;
        # Path.resolve() raises ValueError on a NUL, which must be a miss, not a 500
        for url in [
            "/package.json",
            "/src/app.js",
            "/../secret.txt",
            "/link.txt",
            "/\x00",
            "/legacy.png",
            "/dist/legacy.png",
            "/missing.png",
            "/static/logo.png",
            "/static/assets/x/logo.png",
            "/static/assets/icon.svg",
            "/sub/logo.png"
        ] {
            assert resolve_asset(table, url) is None , f"{url} must not resolve";
        }
    }
}


test "asset_cache_policy revalidates every asset and never caches an HTML shell" {
    # mimetypes serves .htm and any-case .html as text/html, so they are shells
    for (name, expected) in [
        ("index.html", "no-cache"),
        ("offline.htm", "no-cache"),
        ("help.HTML", "no-cache"),
        ("dashboard", "no-cache"),
        ("logo.png", "public, max-age=3600, must-revalidate"),
        ("app.js", "public, max-age=3600, must-revalidate")
    ] {
        assert asset_cache_policy(Path(name)) == expected , name;
    }
}
