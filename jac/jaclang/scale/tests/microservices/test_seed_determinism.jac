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


test "staged pod binary reuses its stable path across packs" {
    import from jaclang.scale.injector.bundle { _staged_pod_jac }
    cache = tempfile.mkdtemp();
    saved = os.environ.get("JAC_SCALE_CACHE_DIR");
    os.environ["JAC_SCALE_CACHE_DIR"] = cache;
    try {
        first = _staged_pod_jac(b"ELF-one");
        mtime = first.stat().st_mtime_ns;
        # identical bytes: no rewrite, same file
        assert _staged_pod_jac(b"ELF-one").stat().st_mtime_ns == mtime;
        # new binary content replaces the file at the same stable path
        second = _staged_pod_jac(b"ELF-two");
        assert second == first;
        assert second.read_bytes() == b"ELF-two";
    } finally {
        os.environ.pop("JAC_SCALE_CACHE_DIR", None);
        if saved is not None {
            os.environ["JAC_SCALE_CACHE_DIR"] = saved;
        }
        import shutil;
        shutil.rmtree(cache, ignore_errors=True);
    }
}
