"""L1 unit tests for the shared static-asset resolver (#8125, RFC #8124).

These test the one core that every run mode (monolith, gateway, embedded, dev)
will consume: `asset_root_table` / `resolve_asset` / `asset_response` in
`jaclang/runtimelib/serving/static_assets.jac`. Because there is exactly one
resolver, every resolution invariant is asserted here, once. Host wiring and
cross-mode parity live in the L2/L3 tests (see 8125_plan.md §8).

TDD: this file is written before the module exists. Until
`static_assets.jac` lands, importing it fails and every test below is red.
No mocks — real tempdir trees, real Path resolution.

(`root` is a Jac built-in — the graph root node — so the project dir is `proj`.)
"""

import os;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.serving.static_assets {
    AssetRoot,
    asset_root_table,
    resolve_asset,
    asset_response
}


# A fresh temp project dir. Callers create the dirs/files they need.
def _project -> Path {
    return Path(tempfile.mkdtemp());
}


# Create proj/rel with `data`, making parent dirs. Returns the file path.
def _write(proj: Path, rel: str, data: bytes) -> Path {
    target = proj / rel;
    target.parent.mkdir(parents=True, exist_ok=True);
    target.write_bytes(data);
    return target;
}


# The standard table for a project whose client build is at .jac/client/dist.
def _table(proj: Path) -> list[AssetRoot] {
    return asset_root_table(proj, proj / ".jac" / "client" / "dist", []);
}


# ---- the DX fix: public/ at the web root ---------------------------------

test "public/ asset resolves at the web root (the amplify bug)" {
    proj = _project();
    _write(proj, "public/brand/logo.png", b"PNG_DATA");

    result = resolve_asset(_table(proj), "/brand/logo.png");

    assert result is not None , "public/brand/logo.png must be reachable at /brand/logo.png";
    (path, _) = result;
    assert path.read_bytes() == b"PNG_DATA";
}


test "public/ file with a no-allowlist extension resolves (.webmanifest, .wasm)" {
    proj = _project();
    _write(proj, "public/manifest.webmanifest", b"{}");
    _write(proj, "public/app.wasm", b"\x00asm");

    tbl = _table(proj);
    assert resolve_asset(tbl, "/manifest.webmanifest") is not None , ".webmanifest must resolve (no extension allowlist)";
    assert resolve_asset(tbl, "/app.wasm") is not None , ".wasm must resolve (no extension allowlist)";
}


# ---- containment: jail + no source-file leak (I4) ------------------------

test "bare project files never resolve (/package.json leak is closed)" {
    proj = _project();
    _write(proj, "package.json", b"{\"secrets\":true}");
    _write(proj, "src/app.js", b"console.log(1)");

    tbl = _table(proj);
    assert resolve_asset(tbl, "/package.json") is None , "project root is not an asset root — /package.json must not be servable";
    assert resolve_asset(tbl, "/src/app.js") is None , "src/ is not an asset root — source files must not be servable";
}


test "..-traversal escapes are jailed" {
    proj = _project();
    _write(proj, "public/logo.png", b"OK");
    _write(proj, "secret.txt", b"classified");

    assert resolve_asset(_table(proj), "/../secret.txt") is None , ".. must not escape a declared asset root";
}


test "a URL with an embedded null byte is a miss, not an unhandled exception" {
    proj = _project();
    _write(proj, "public/logo.png", b"OK");

    # Path.resolve() raises ValueError (not OSError) on an embedded NUL, so a
    # request for /%00 must not escape resolve_asset as an exception - every
    # host consuming this resolver would otherwise turn it into a 500.
    assert resolve_asset(_table(proj), "/\x00") is None , "an embedded null byte must resolve to a miss, not raise";
}


test "symlink pointing outside a root is jailed" {
    proj = _project();
    (proj / "public").mkdir(parents=True, exist_ok=True);
    outside = proj / "outside.txt";
    outside.write_bytes(b"classified");
    os.symlink(str(outside), str(proj / "public" / "link.txt"));

    assert resolve_asset(_table(proj), "/link.txt") is None , "a symlink resolving outside its root must not be served";
}


# ---- determinism: no basename flattening / no aliasing (I5) ---------------

test "no basename flattening: a deep URL does not match a shallow file" {
    proj = _project();
    _write(proj, "assets/logo.png", b"LOGO");

    assert resolve_asset(_table(proj), "/static/assets/x/deep/logo.png") is None , "must not alias assets/logo.png — exact path only";
}


test "one URL maps to at most one file (exact path within a root)" {
    proj = _project();
    _write(proj, "assets/img/icon.svg", b"SVG");

    # project assets are served under /static/assets/ at their real relative path
    result = resolve_asset(_table(proj), "/static/assets/img/icon.svg");
    assert result is not None , "assets/img/icon.svg resolves at /static/assets/img/icon.svg (the #6872 URL space)";
    assert resolve_asset(_table(proj), "/static/assets/icon.svg") is None , "the same file must not also answer at /static/assets/icon.svg (no basename flattening)";
}


# ---- table ordering (first hit wins) -------------------------------------

test "built client dist wins over public/ for the same URL" {
    proj = _project();
    _write(proj, ".jac/client/dist/index.html", b"DIST");
    _write(proj, "public/index.html", b"PUBLIC");

    result = resolve_asset(_table(proj), "/index.html");
    assert result is not None;
    (path, _) = result;
    assert path.read_bytes() == b"DIST" , "a built index.html must win over a stray public/index.html";
}


test "configured mounts win first and keep exclusive ownership" {
    proj = _project();
    _write(proj, "public/data.json", b"FROM_PUBLIC");
    mount_dir = _project();
    _write(mount_dir, "data.json", b"FROM_MOUNT");

    table = asset_root_table(
        proj,
        proj / ".jac" / "client" / "dist",
        [{"url_prefix": "files", "local_path": str(mount_dir)}]
    );
    result = resolve_asset(table, "/files/data.json");
    assert result is not None;
    (path, _) = result;
    assert path.read_bytes() == b"FROM_MOUNT" , "a configured mount owns its url_prefix";
}


test "a mount miss is exclusive: it never falls through to public/ or assets/" {
    proj = _project();
    _write(proj, "public/files/data.json", b"FROM_PUBLIC");
    mount_dir = _project();

    table = asset_root_table(
        proj,
        proj / ".jac" / "client" / "dist",
        [{"url_prefix": "files", "local_path": str(mount_dir)}]
    );
    result = resolve_asset(table, "/files/data.json");
    assert result is None , (
        "a static_mount owns its prefix exclusively; a miss must not fall "
        "through to public/files/data.json (or assets/)"
    );
}


test "a mount on the reserved static prefix still lets project /static assets resolve" {
    proj = _project();
    _write(proj, "assets/logo.svg", b"<svg/>");
    mount_dir = _project();

    table = asset_root_table(
        proj,
        proj / ".jac" / "client" / "dist",
        [{"url_prefix": "static", "local_path": str(mount_dir)}]
    );
    result = resolve_asset(table, "/static/assets/logo.svg");
    assert result is not None , (
        "a mount claiming 'static' must not shadow a real project /static asset "
        "(#7020); the static/assets->assets root still serves it"
    );
    (path, _) = result;
    assert path.read_bytes() == b"<svg/>";
}


# NOTE — one-law / reserved-segment protection ("public/user/data.json" must not
# serve at /user/data.json) is a HOST-DISPATCH invariant, not a resolver one: in
# every host, reserved paths classify before static, so the resolver is never
# asked for them. Asserting it here would force a backwards layering dependency
# (runtimelib core -> scale/routing.jac). It is asserted at L2 against the real
# gateway/monolith dispatch instead. The core resolver stays dependency-free.

# ---- the --scale bundle parity trap: dist/ is excluded from the image -----

test "project-root dist/ is not an asset root (bundle-exclusion parity)" {
    proj = _project();
    # `"dist"` is in the --scale bundle's _EXCLUDE_DIRS, so a project-root dist/
    # is absent in k8s. It must therefore be a miss in EVERY mode, not just k8s —
    # the table uses .jac/client/dist, never bare dist/.
    _write(proj, "dist/legacy.png", b"LEGACY");

    assert resolve_asset(_table(proj), "/legacy.png") is None , "bare dist/ must not be an asset root — 404s consistently across modes";
    assert resolve_asset(_table(proj), "/dist/legacy.png") is None , "dist/ is not exposed at its own path either";
}


# ---- honest miss -----------------------------------------------------------

test "a genuinely missing asset resolves to None" {
    proj = _project();
    _write(proj, "public/exists.png", b"OK");

    assert resolve_asset(_table(proj), "/missing.png") is None , "a miss is None — resolve_asset never falls back to index.html";
}


# ---- asset_response: response construction --------------------------------

test "asset_response serves 200 with the right content type" {
    proj = _project();
    target = _write(proj, "public/logo.png", b"PNG_DATA");

    resp = asset_response(target);
    assert resp.status_code == 200;
    assert resp.body_bytes() == b"PNG_DATA";
    assert "image/png" in resp.content_type_header();
}


test "asset_response does not blanket-cache mutable files for a year" {
    proj = _project();
    target = _write(proj, "public/logo.png", b"PNG_DATA");

    resp = asset_response(target);
    cache = resp.headers.get("Cache-Control") or "";
    # The monolith's blanket `max-age=31536000` on every file is the bug we are
    # removing. A hashed/immutable long-cache split is #8126; #8125 just must not
    # ship the blanket-immutable regression.
    assert "31536000" not in cache , "an unhashed, mutable asset must not be cached immutable for a year";
}
