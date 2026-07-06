import os;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle { pack_source, content_address }
import from jaclang.scale.injector.binary { pack_binary_bytes }


test "identical content packs to identical bytes (content-address stable)" {
    # Content-addressed seed-skip only works if the archives are deterministic:
    # zeroed gzip header time and normalized member mtimes/owners.
    assert pack_binary_bytes(b"ELF") == pack_binary_bytes(b"ELF");

    d = tempfile.mkdtemp();
    src = Path(d, "svc.jac");
    src.write_text("x = 1;");
    first = pack_source(d);
    # A different mtime on the same content must not change the digest.
    os.utime(str(src), (0, 0));
    try {
        assert content_address(pack_source(d)) == content_address(first);
    } finally {
        import shutil;
        shutil.rmtree(d, ignore_errors=True);
    }
}
