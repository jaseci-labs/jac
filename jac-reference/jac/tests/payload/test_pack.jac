"""`payload pack`: `[stub][payload][trailer]` with the trailer encoded by the
single-source-of-truth codec in na_stdlib/_fused/trailer.jac."""

import contextlib;
import hashlib;
import io;
import os;
import shutil;
import tempfile;

import from jaclang.dist.payload.cli { main }
import from jaclang.dist.payload.pack { pack }
import from jaclang.dist.fused.trailer { MAGIC, TRAILER_LEN, parse_trailer }

def read(path: str) -> bytes {
    with open(path, "rb") as f {
        return f.read();
    }
}

def write(path: str, data: bytes) {
    with open(path, "wb") as f {
        f.write(data);
    }
}

test "pack appends the payload and an 80-byte trailer the codec parses back" {
    tmp = tempfile.mkdtemp(prefix="jac-payload-pack-");
    try {
        stub = os.path.join(tmp, "stub");
        payload = os.path.join(tmp, "payload.tar.zst");
        out = os.path.join(tmp, "jac");
        stub_bytes = b"\x7fELF-fake-launcher-stub\n" * 17;
        payload_bytes = bytes(range(256)) * 7 + b"tail";
        write(stub, stub_bytes);
        write(payload, payload_bytes);

        pack(stub, payload, out);

        data = read(out);
        assert len(data) == len(stub_bytes) + len(payload_bytes) + TRAILER_LEN;
        assert data[:len(stub_bytes)] == stub_bytes;
        assert data[len(stub_bytes):len(stub_bytes) + len(payload_bytes)]
            == payload_bytes;
        trailer = data[-TRAILER_LEN:];
        assert trailer[:8] == b"JACBIN01";
        assert trailer[8:16] == len(payload_bytes).to_bytes(8, "little");
        assert trailer[16:] == hashlib.sha256(payload_bytes).hexdigest().encode();
        t = parse_trailer(trailer, MAGIC);
        assert t is not None;
        assert t.payload_len == len(payload_bytes);
        assert t.hash_hex == hashlib.sha256(payload_bytes).hexdigest();
        assert (os.stat(out).st_mode & 0o111) == 0o111 , "pack must chmod 0o755";

        out2 = os.path.join(tmp, "jac2");
        rc = main(["pack", stub, payload, out2]);
        assert rc == 0;
        assert read(out2) == data , "the cli path must produce the same bytes";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "pack usage and missing inputs exit non-zero" {
    err = io.StringIO();
    with contextlib.redirect_stderr(err) {
        rc = main(["pack", "only-one"]);
    }
    assert rc == 1;
    assert "usage: payload pack <stub> <payload.tar.zst> <out>" in err.getvalue();

    tmp = tempfile.mkdtemp(prefix="jac-payload-pack-");
    try {
        err = io.StringIO();
        with contextlib.redirect_stderr(err) {
            rc = main(
                [
                    "pack",
                    os.path.join(tmp, "missing-stub"),
                    os.path.join(tmp, "missing-payload"),
                    os.path.join(tmp, "out")
                ]
            );
        }
        assert rc == 1;
        assert err.getvalue().startswith("payload: pack:");
        assert not os.path.exists(os.path.join(tmp, "out"));
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
