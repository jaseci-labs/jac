import os;

import from jaclang.payload.fsutil { die, read_bytes, sha256_hex }
import from jaclang.runtimelib.fused.trailer { MAGIC, TRAILER_LEN, build_trailer }

impl pack(stub: str, payload: str, out: str) {
    try {
        stub_bytes = read_bytes(stub);
        payload_bytes = read_bytes(payload);
    } except OSError as e {
        die(f"pack: {type(e).__name__}: {e}");
    }
    trailer = build_trailer(MAGIC, len(payload_bytes), sha256_hex(payload_bytes));
    if len(trailer) != TRAILER_LEN {
        die(f"pack: trailer is {len(trailer)} bytes, expected {TRAILER_LEN}");
    }
    try {
        with open(out, "wb") as f {
            f.write(stub_bytes);
            f.write(payload_bytes);
            f.write(trailer);
        }
    } except OSError as e {
        die(f"pack: cannot write {out}: {type(e).__name__}: {e}");
    }
    try {
        os.chmod(out, 0o755);
    } except OSError { }
}
