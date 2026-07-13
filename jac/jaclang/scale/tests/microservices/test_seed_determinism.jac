import os;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle { pack_jab, content_address }
import from jaclang.scale.injector.binary { pack_binary_bytes }


glob _JAC_BIN: Path = Path(__file__).parents[4] / "zig-out" / "bin" / "jac";


test "identical content packs to identical bytes (content-address stable)" {
    # Content-addressed seed-skip only works if the archives are deterministic:
    # zeroed gzip header time and normalized member mtimes/owners.
    assert pack_binary_bytes(b"ELF") == pack_binary_bytes(b"ELF");

    if not _JAC_BIN.is_file() {
        return;
    }
    binary = _JAC_BIN.read_bytes();
    d = tempfile.mkdtemp();
    src = Path(d, "svc.jac");
    src.write_text("with entry { print(\"ok\"); }");
    first = pack_jab(d, "", binary);
    # A different mtime on the same content must not change the digest.
    os.utime(str(src), (0, 0));
    try {
        assert content_address(pack_jab(d, "", binary)) == content_address(first);
    } finally {
        import shutil;
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "sealed .jab cache: hit on unchanged inputs, miss on source change" {
    import from jaclang.scale.injector.bundle { _bundle_cache_key }
    if not _JAC_BIN.is_file() {
        return;
    }
    binary = _JAC_BIN.read_bytes();
    d = tempfile.mkdtemp();
    cache = tempfile.mkdtemp();
    saved = os.environ.get("JAC_SCALE_CACHE_DIR");
    os.environ["JAC_SCALE_CACHE_DIR"] = cache;
    try {
        src = Path(d, "svc.jac");
        src.write_text("with entry { print(\"ok\"); }");
        first = pack_jab(d, "", binary);
        jabs = list(Path(cache, "sealed-jabs").glob("*.jab"));
        assert len(jabs) == 1;
        # sentinel-replace the cache entry: a second pack must return it
        # verbatim, proving the seal was skipped
        jabs[0].write_bytes(b"SENTINEL");
        assert pack_jab(d, "", binary) == b"SENTINEL";
        # a source change keys differently and re-seals for real
        src.write_text("with entry { print(\"changed\"); }");
        assert pack_jab(d, "", binary) != b"SENTINEL";
    } finally {
        os.environ.pop("JAC_SCALE_CACHE_DIR", None);
        if saved is not None {
            os.environ["JAC_SCALE_CACHE_DIR"] = saved;
        }
        import shutil;
        shutil.rmtree(d, ignore_errors=True);
        shutil.rmtree(cache, ignore_errors=True);
    }
}


test "bundle cache key ignores the derived client dist" {
    import from jaclang.scale.injector.bundle { _bundle_cache_key }
    d = tempfile.mkdtemp();
    Path(d, "main.jac").write_text("with entry {}");
    before = _bundle_cache_key(Path(d), "mongo", b"BIN");
    dist = Path(d, ".jac", "client", "dist");
    dist.mkdir(parents=True);
    Path(dist, "client.abc123.js").write_text("bundled");
    assert _bundle_cache_key(Path(d), "mongo", b"BIN") == before;
    Path(d, "main.jac").write_text("with entry { print(1); }");
    assert _bundle_cache_key(Path(d), "mongo", b"BIN") != before;
}


test "unreadable input disables caching instead of keying a stale digest" {
    import from jaclang.scale.injector.bundle { _bundle_cache_key }
    if os.geteuid() == 0 {
        return;
    }
    d = tempfile.mkdtemp();
    Path(d, "main.jac").write_text("with entry {}");
    secret = Path(d, "data.txt");
    secret.write_text("x");
    os.chmod(str(secret), 0);
    try {
        assert _bundle_cache_key(Path(d), "", b"BIN") == "";
    } finally {
        os.chmod(str(secret), 0o644);
    }
}


test "a cache dir inside the project does not poison its own key" {
    import from jaclang.scale.injector.bundle { _bundle_cache_key }
    d = tempfile.mkdtemp();
    Path(d, "main.jac").write_text("with entry {}");
    saved = os.environ.get("JAC_SCALE_CACHE_DIR");
    os.environ["JAC_SCALE_CACHE_DIR"] = str(Path(d, ".cache"));
    try {
        before = _bundle_cache_key(Path(d).resolve(), "", b"BIN");
        jabs = Path(d, ".cache", "sealed-jabs");
        jabs.mkdir(parents=True);
        Path(jabs, "aaaa.jab").write_bytes(b"cached");
        assert _bundle_cache_key(Path(d).resolve(), "", b"BIN") == before;
    } finally {
        os.environ.pop("JAC_SCALE_CACHE_DIR", None);
        if saved is not None {
            os.environ["JAC_SCALE_CACHE_DIR"] = saved;
        }
    }
}


test "an unreadable directory also disables caching" {
    import from jaclang.scale.injector.bundle { _bundle_cache_key }
    if os.geteuid() == 0 {
        return;
    }
    d = tempfile.mkdtemp();
    Path(d, "main.jac").write_text("with entry {}");
    sub = Path(d, "data");
    sub.mkdir();
    Path(sub, "inner.txt").write_text("x");
    os.chmod(str(sub), 0);
    try {
        assert _bundle_cache_key(Path(d), "", b"BIN") == "";
    } finally {
        os.chmod(str(sub), 0o755);
    }
}
