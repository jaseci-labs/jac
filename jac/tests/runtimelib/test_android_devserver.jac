"""Tests for the Android HMR dev server — locks in the device-polling contract.

JacDevHostActivity polls `/_jac/dev/modules/manifest.json` and downloads the dex
at the manifest's `path`. These tests assert the server honors that contract
(missing dex -> 404, live state updates visible to the next poll) without a
device or a real build.
"""
import from jaclang.runtimelib.client.targets.android.dev_server {
    publish_hot_module,
    _resolve_versioned_dex
}
import from jaclang.runtimelib.client.targets.android_target { _jac_start_dev_server }
import from pathlib { Path }
import from urllib.request { urlopen }
import from urllib.error { HTTPError }
import from json { loads }

test "dev server serves manifest and dex with live state updates" {
    modules_root = Path("/tmp/_jactest_devserver_modules");
    modules_root.mkdir(parents=True, exist_ok=True);
    state: dict = {"modules_root": str(modules_root)};
    # Port 0 binds a free port; server_address[1] is the actual port.
    httpd = _jac_start_dev_server(0, state);
    port = httpd.server_address[1];
    base = f"http://127.0.0.1:{port}";

    try {
        # Manifest reflects the live state dict.
        m = loads(
            urlopen(base + "/_jac/dev/modules/manifest.json", timeout=3).read().decode()
        );
        assert m["version"] == "";
        assert m["path"] == "";

        # No dex staged yet -> 404.
        try {
            urlopen(
                base + "/_jac/dev/modules/android/0123456789abcdef/classes.dex",
                timeout=3
            );
            assert False , "expected 404 for missing dex";
        } except HTTPError as e {
            assert e.code == 404;
        }

        # Stage a dex and bump the version; the next poll sees both atomically.
        hexver = "fedcba9876543210";
        fake = modules_root / hexver / "classes.dex";
        fake.parent.mkdir(parents=True, exist_ok=True);
        fake.write_bytes(b"dex\n035\0" + b"\x00" * 40);
        publish_hot_module(state, hexver, str(fake));
        m2 = loads(
            urlopen(base + "/_jac/dev/modules/manifest.json", timeout=3).read().decode()
        );
        assert m2["version"] == hexver;
        assert m2["path"] == f"/_jac/dev/modules/android/{hexver}/classes.dex";
        data = urlopen(
            base + f"/_jac/dev/modules/android/{hexver}/classes.dex", timeout=3
        ).read();
        assert data == fake.read_bytes();

        # Legacy flat dex URL tracks the current module snapshot.
        data_legacy = urlopen(
            base + "/_jac/dev/modules/android/classes.dex", timeout=3
        ).read();
        assert data_legacy == fake.read_bytes();

        # Unknown path -> 404.
        try {
            urlopen(base + "/_jac/dev/other", timeout=3);
            assert False , "expected 404 for unknown path";
        } except HTTPError as e {
            assert e.code == 404;
        }

        # Path traversal must not escape the modules root (CVE-class guard):
        # a crafted version segment can never read files outside modules_root,
        # even when the target file exists on disk.
        try {
            urlopen(
                base + "/_jac/dev/modules/android/../../etc/classes.dex", timeout=3
            );
            assert False , "expected 404 for traversal attempt";
        } except HTTPError as e {
            assert e.code == 404;
        }
    } finally {
        httpd.shutdown();
        httpd.server_close();
    }
}

# The dev server is reachable only from the host (the device reaches it over
# `adb reverse` -> localhost). Binding 0.0.0.0 would expose the merged dex to
# the local network, so the bound address must be loopback.
test "dev server binds to loopback, not all interfaces" {
    httpd = _jac_start_dev_server(0, {"modules_root": "/tmp"});
    try {
        assert httpd.server_address[0] == "127.0.0.1";
    } finally {
        httpd.shutdown();
        httpd.server_close();
    }
}

# Unit test for the traversal guard without spinning a server: every shape of
# escaping version segment resolves to None.
test "_resolve_versioned_dex rejects traversal and malformed versions" {
    state: dict = {"modules_root": "/tmp/_jactest_resolve_modules"};
    # A legitimate 16-hex version under a real root resolves when the file exists.
    base_dir = Path("/tmp/_jactest_resolve_modules");
    hexver = "0123456789abcdef";
    real = base_dir / hexver / "classes.dex";
    real.parent.mkdir(parents=True, exist_ok=True);
    real.write_bytes(b"dex");
    assert _resolve_versioned_dex(
        state, f"/_jac/dev/modules/android/{hexver}/classes.dex"
    )
        == real.resolve();

    # Only the generated 16-hex version shape is accepted: short, non-hex, or
    # wrong-length segments resolve to None even when the file exists.
    assert _resolve_versioned_dex(state, "/_jac/dev/modules/android/v1/classes.dex")
        is None;
    assert _resolve_versioned_dex(
        state, "/_jac/dev/modules/android/0123456789abcde/classes.dex"
    )
        is None;
    assert _resolve_versioned_dex(
        state, "/_jac/dev/modules/android/0123456789abcdefg/classes.dex"
    )
        is None;

    # Traversal / separator / dot segments never resolve, regardless of files.
    assert _resolve_versioned_dex(state, "/_jac/dev/modules/android/../etc/classes.dex")
        is None;
    assert _resolve_versioned_dex(state, "/_jac/dev/modules/android/./classes.dex")
        is None;
    assert _resolve_versioned_dex(state, "/_jac/dev/modules/android//classes.dex")
        is None;
    # Wrong prefix / suffix are rejected before any filesystem touch.
    assert _resolve_versioned_dex(state, "/etc/passwd") is None;
    assert _resolve_versioned_dex(
        state, "/_jac/dev/modules/android/0123456789abcdef/notdex"
    )
        is None;
}
