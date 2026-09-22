import os;

import from jaclang.dist.payload.fsutil {
    die,
    read_bytes,
    sha256_hex,
    strip_best_effort
}
import from jaclang.dist.fused.trailer {
    MAGIC,
    REGION_ALIGN,
    REGION_DESC_LEN,
    TRAILER_LEN,
    build_region_desc,
    build_trailer
}

impl pack(stub: str, payload: str, out: str, stubcat: str | None = None) {
    try {
        strip_best_effort(stub);
        stub_bytes = read_bytes(stub);
        payload_bytes = read_bytes(payload);
    } except OSError as e {
        die(f"pack: {type(e).__name__}: {e}");
    }

    head = stub_bytes;
    cat_bytes = b"";
    if stubcat is not None {
        try {
            cat_bytes = read_bytes(stubcat);
        } except OSError as e {
            die(f"pack: {type(e).__name__}: {e}");
        }
    }
    if len(cat_bytes) > 0 {
        pad = (REGION_ALIGN - (len(stub_bytes) % REGION_ALIGN)) % REGION_ALIGN;
        cat_off = len(stub_bytes) + pad;
        desc = build_region_desc(cat_off, len(cat_bytes));
        if len(desc) != REGION_DESC_LEN {
            die(
                f"pack: region descriptor is {len(desc)} bytes, expected {REGION_DESC_LEN}"
            );
        }
        head = stub_bytes + (b"\x00" * pad) + cat_bytes + desc;
    }
    trailer = build_trailer(MAGIC, len(payload_bytes), sha256_hex(payload_bytes));
    if len(trailer) != TRAILER_LEN {
        die(f"pack: trailer is {len(trailer)} bytes, expected {TRAILER_LEN}");
    }
    try {
        with open(out, "wb") as f {
            f.write(head);
            f.write(payload_bytes);
            f.write(trailer);
        }
    } except OSError as e {
        die(f"pack: cannot write {out}: {type(e).__name__}: {e}");
    }
    try {
        os.chmod(out, 0o755);
    } except OSError {}
}
