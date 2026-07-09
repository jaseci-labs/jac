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
