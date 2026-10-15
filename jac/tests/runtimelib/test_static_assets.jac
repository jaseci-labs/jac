"""L1 unit tests for the shared static-asset resolver (#8125, RFC #8124).

These test the one core that every run mode (monolith, gateway, embedded, dev)
will consume: `asset_root_table` / `resolve_asset` / `asset_cache_policy` in
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
import from jaclang.server.serving.static_assets {
    AssetRoot,
    asset_root_table,
    resolve_asset,
    mount_claims,
    asset_cache_policy
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

test "public/ files resolve at the web root with no extension allowlist (the amplify bug)" {
    proj = _project();
    _write(proj, "public/brand/logo.png", b"PNG_DATA");
    _write(proj, "public/manifest.webmanifest", b"{}");
    _write(proj, "public/app.wasm", b"\x00asm");

    tbl = _table(proj);
    for (url, expected) in [
        ("/brand/logo.png", b"PNG_DATA"),
        ("/manifest.webmanifest", b"{}"),
        ("/app.wasm", b"\x00asm")
    ] {
        result = resolve_asset(tbl, url);
        assert result is not None , f"public/ file must be reachable at {url}";
        (path, _) = result;
        assert path.read_bytes() == expected;
    }
}


# ---- containment: jail, no source leak, honest miss (I4) ------------------

test "nothing outside the declared asset roots resolves" {
    proj = _project();
    # positive control, so the table below cannot pass vacuously
    _write(proj, "public/logo.png", b"OK");
    _write(proj, "package.json", b"{\"secrets\":true}");
    _write(proj, "src/app.js", b"console.log(1)");
    _write(proj, "secret.txt", b"classified");
    # `dist` is in the --scale bundle's _EXCLUDE_DIRS, so a project-root dist/
    # is absent in k8s; it must be a miss in every mode, not just k8s.
    _write(proj, "dist/legacy.png", b"LEGACY");
    os.symlink(str(proj / "secret.txt"), str(proj / "public" / "link.txt"));

    tbl = _table(proj);
    assert resolve_asset(tbl, "/logo.png") is not None;
    # Path.resolve() raises ValueError (not OSError) on an embedded NUL, so
    # /%00 must be a miss rather than a 500 in every host.
    for url in [
        "/package.json",
        "/src/app.js",
        "/../secret.txt",
        "/link.txt",
        "/\x00",
        "/legacy.png",
        "/dist/legacy.png",
        "/missing.png"
    ] {
        assert resolve_asset(tbl, url) is None , f"{url} must not resolve";
    }
}


# ---- determinism: no basename flattening / no aliasing (I5) ---------------

test "exact path only: no basename flattening, one URL maps to one file" {
    proj = _project();
    _write(proj, "assets/img/icon.svg", b"SVG");
    _write(proj, "assets/logo.png", b"LOGO");

    tbl = _table(proj);
    # project assets/ are served under /static/assets/ at their real relative
    # path (the #6872 URL space)
    assert resolve_asset(tbl, "/static/assets/img/icon.svg") is not None;
    for url in [
        "/static/assets/icon.svg",
        "/static/assets/x/deep/logo.png",
        "/sub/logo.png",
        "/static/sub/logo.png"
    ] {
        assert resolve_asset(tbl, url) is None , f"{url} must not alias a shallower file";
    }
}


# ---- table ordering (first hit wins) -------------------------------------

test "table order: built dist beats public/, and a configured mount wins first" {
    proj = _project();
    _write(proj, ".jac/client/dist/index.html", b"DIST");
    _write(proj, "public/index.html", b"PUBLIC");
    _write(proj, "public/data.json", b"FROM_PUBLIC");
    mount_dir = _project();
    _write(mount_dir, "data.json", b"FROM_MOUNT");

    table = asset_root_table(
        proj,
        proj / ".jac" / "client" / "dist",
        [{"url_prefix": "files", "local_path": str(mount_dir)}]
    );
    for (url, expected) in [
        ("/index.html", b"DIST"),
        ("/files/data.json", b"FROM_MOUNT")
    ] {
        result = resolve_asset(table, url);
        assert result is not None;
        (path, _) = result;
        assert path.read_bytes() == expected , f"{url} resolved to the wrong root";
    }
}


test "a mount miss is exclusive: it never falls through to public/, assets/, or the static tier" {
    # (mount url_prefix, a real file placed where the leak would be served
    # from, the request path that misses in the mount and should 404 rather
    # than reach that file)
    cases = [
        ("files", "public/files/data.json", "/files/data.json"),
        # a mount nested under the reserved static/ tier (unlike a mount at
        # exactly "static", which is an additive overlay per #7020) must be
        # just as exclusive as any other prefix -- a miss must not fall
        # through to the built-in static->dist root three entries down.
        ("static/brand", ".jac/client/dist/brand/logo.png", "/static/brand/logo.png"),

    ];
    for (prefix, leak_rel, request_path) in cases {
        proj = _project();
        _write(proj, leak_rel, b"LEAK");
        mount_dir = _project();

        table = asset_root_table(
            proj,
            proj / ".jac" / "client" / "dist",
            [{"url_prefix": prefix, "local_path": str(mount_dir)}]
        );
        result = resolve_asset(table, request_path);
        assert result is None , (
            f"a static_mount at '{prefix}' owns its prefix exclusively; a miss "
            f"must not fall through to {leak_rel}"
        );
        assert mount_claims(table, request_path) , (
            f"mount_claims must agree that '{prefix}' owns {request_path} "
            "exclusively, so a host can turn this miss into a hard 404 instead "
            "of falling through to its own asset table or the SPA shell"
        );
    }
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
    assert not mount_claims(table, "/static/assets/logo.svg") , (
        "a mount at 'static' is an additive overlay (#7020), not an exclusive "
        "owner, so a miss under it must not be turned into a hard 404"
    );
}


test "mount_claims separates a claimed prefix from a path nobody claims" {
    proj = _project();
    mount_dir = _project();
    dist = proj / ".jac" / "client" / "dist";

    # (mounts, request path, expected claim)
    cases = [
        # outside every mount's prefix: a host may keep looking elsewhere
        (["files"], "/brand/logo.png", False),
        # the bare mount prefix itself is owned, with or without a trailing
        # slash, or a client-page fallback could serve the SPA at the mount root
        (["docs"], "/docs", True),
        (["docs"], "/docs/", True),
        # a broader additive "static" overlay listed first must not mask a
        # nested exclusive mount's claim
        (["static", "static/brand"], "/static/brand/logo.png", True)
    ];
    for (prefixes, request_path, expected) in cases {
        table = asset_root_table(
            proj,
            dist,
            [{"url_prefix": p, "local_path": str(mount_dir)} for p in prefixes]
        );
        assert mount_claims(table, request_path) == expected , (
            f"mount_claims({prefixes}, {request_path}) must be {expected}"
        );
    }
}


# NOTE — one-law / reserved-segment protection ("public/user/data.json" must not
# serve at /user/data.json) is a HOST-DISPATCH invariant, not a resolver one: in
# every host, reserved paths classify before static, so the resolver is never
# asked for them. Asserting it here would force a backwards layering dependency
# (runtimelib core -> scale/routing.jac). It is asserted at L2 against the real
# gateway/monolith dispatch instead. The core resolver stays dependency-free.

# ---- asset_cache_policy: cache-control decision ----------------------------
# Response construction (status, ETag, 304, Range) is shared with the rest of
# the server through files.jac's file_response; asset_cache_policy only owns
# the one decision specific to these roots -- whether a hit is cacheable.

test "asset_cache_policy revalidates html shells and static files, never caches for a year" {
    proj = _project();
    png = _write(proj, "public/logo.png", b"PNG_DATA");
    html = _write(proj, "public/index.html", b"<html></html>");

    assert asset_cache_policy(html) == "no-cache";
    policy = asset_cache_policy(png);
    assert "max-age=3600" in policy;
    assert "must-revalidate" in policy;
    # The monolith's blanket `max-age=31536000` on every file is the bug we are
    # removing. A hashed/immutable long-cache split is #8126; #8125 just must not
    # ship the blanket-immutable regression.
    assert "31536000" not in policy , "an unhashed, mutable asset must not be cached immutable for a year";
}
