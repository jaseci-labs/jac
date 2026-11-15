"""Bundled native `hashlib`/`hmac` cross-backend equivalence fixture (#6978 Phase 1).

The SAME `import hashlib; import hmac;` binds CPython's `hashlib`/`hmac` on the sv
(Python) backend and the bundled `na_stdlib/hashlib.jac` / `hmac.jac`
Mechanism-F modules -- thin pure-Jac surfaces over OpenSSL's `libcrypto` (the FFI
floor) -- on the na (native LLVM) backend. Module-qualified `hashlib.sha256(...)`
access on the native pathway is the whole-module-import support added in #6978
(the bundled module links and `mod.func(...)` routes to its function exactly like
`import from hashlib { sha256 }`); the sv side reads the same `hashlib` attribute,
which `install_native_wrappers` never shadows (it only rebinds top-level names),
pinning the reference to CPython.

The message/key are function-LOCAL byte literals, not module `glob`s: a
module-level `glob x: bytes = b"..."` is currently not initialized along the na
JIT path (it reads empty), so a shared glob would feed an empty buffer to the
digests here -- tracked as a separate native-glob-init follow-up. Locals sidestep
it and keep the two backends fed identical input.

The harness then asserts byte-for-byte: every algorithm's `hexdigest` matches
CPython (md5/sha1/sha2/sha3/blake2), incremental `update` matches a one-shot
hash, `digest()` is non-consuming, `copy()` snapshots an independent state
(hashlib and hmac alike), the `digest_size`/`block_size`/`name` attributes
agree, `hashlib.new` round-trips and pins `ValueError` on a bogus name, HMAC
matches CPython's `hmac` (including the required-`digestmod` `TypeError` and
`msg=None`), and `compare_digest` agrees. ES/JS opts out.

This is the first F-module over the large bundled `libcrypto.a` (staged into the
payload in #6978 Phase 0.2), proving the archive links and runs before the
security-critical `ssl` floor is layered on the same archive (Phase 1 proper).
"""

import hashlib;
import hmac;


def hashlib_py -> dict[any, any] {
    msg = b"The quick brown fox jumps over the lazy dog";
    key = b"a-secret-hmac-key";

    inc = hashlib.sha256(b"");
    inc.update(b"The quick brown fox ");
    inc.update(b"jumps over the lazy dog");

    nc = hashlib.sha256(b"abc");
    nc_first = nc.hexdigest();
    nc.update(b"def");
    nc_second = nc.hexdigest();

    cp_src = hashlib.sha256(b"abc");
    cp = cp_src.copy();
    cp_src.update(b"1");
    cp.update(b"2");

    hm_src = hmac.new(key, msg, "sha256");
    hm_cp = hm_src.copy();
    hm_src.update(b"1");
    hm_cp.update(b"2");

    err_new = "?";
    try {
        hashlib.new("bogus");
    } except ValueError as e {
        err_new = str(e);
    }
    err_hm = "?";
    try {
        hmac.new(key, msg);
    } except TypeError as e {
        err_hm = str(e);
    }
    err_msg = "?";
    try {
        bad_msg: any = "str";
        hmac.new(key, bad_msg, "sha256");
    } except TypeError as e {
        err_msg = str(e);
    }
    err_keystr = "?";
    try {
        bad_key: any = "str";
        hmac.new(bad_key, msg, "sha256");
    } except TypeError as e {
        err_keystr = str(e);
    }
    err_keyint = "?";
    try {
        bad_ki: any = 123;
        hmac.new(bad_ki, msg, "sha256");
    } except TypeError as e {
        err_keyint = str(e);
    }
    err_msgint = "?";
    try {
        bad_mi: any = 123;
        hmac.new(key, bad_mi, "sha256");
    } except TypeError as e {
        err_msgint = str(e);
    }

    return {
        "md5": hashlib.md5(msg).hexdigest(),
        "sha1": hashlib.sha1(msg).hexdigest(),
        "sha224": hashlib.sha224(msg).hexdigest(),
        "sha256": hashlib.sha256(msg).hexdigest(),
        "sha384": hashlib.sha384(msg).hexdigest(),
        "sha512": hashlib.sha512(msg).hexdigest(),
        "sha3_224": hashlib.sha3_224(msg).hexdigest(),
        "sha3_256": hashlib.sha3_256(msg).hexdigest(),
        "sha3_384": hashlib.sha3_384(msg).hexdigest(),
        "blake2b": hashlib.blake2b(msg).hexdigest(),
        "blake2s": hashlib.blake2s(msg).hexdigest(),
        "sha256_empty": hashlib.sha256(b"").hexdigest(),
        "sha256_incremental": inc.hexdigest(),
        "sha256_nc_first": nc_first,
        "sha256_nc_second": nc_second,
        "sha256_copy_orig": cp_src.hexdigest(),
        "sha256_copy_clone": cp.hexdigest(),
        "hmac_copy_orig": hm_src.hexdigest(),
        "hmac_copy_clone": hm_cp.hexdigest(),
        "sha256_size": hashlib.sha256(b"").digest_size,
        "sha256_block": hashlib.sha256(b"").block_size,
        "sha256_name": hashlib.sha256(b"").name,
        "sha512_size": hashlib.sha512(b"").digest_size,
        "blake2b_size": hashlib.blake2b(msg).digest_size,
        "blake2s_block": hashlib.blake2s(msg).block_size,
        "hashlib_new": hashlib.new("sha256", msg).hexdigest(),
        "new_err": err_new,
        "hmac_sha256": hmac.new(key, msg, "sha256").hexdigest(),
        "hmac_sha1": hmac.new(key, msg, "sha1").hexdigest(),
        "hmac_sha512": hmac.new(key, msg, "sha512").hexdigest(),
        "hmac_name": hmac.new(key, msg, "sha256").name,
        "hmac_sha3_name": hmac.new(key, msg, "sha3_256").name,
        "hmac_size": hmac.new(key, msg, "sha256").digest_size,
        "hmac_msg_none": hmac.new(key, None, "sha256").hexdigest(),
        "hmac_err_nodm": err_hm,
        "hmac_err_msgstr": err_msg,
        "hmac_err_keystr": err_keystr,
        "hmac_err_keyint": err_keyint,
        "hmac_err_msgint": err_msgint,
        "cd_eq": 1 if hmac.compare_digest(b"abc", b"abc") else 0,
        "cd_neq": 1 if hmac.compare_digest(b"abc", b"abd") else 0,
        "cd_len": 1 if hmac.compare_digest(b"abc", b"ab") else 0,

    };
}


def hashlib_cl -> dict[any, any] {
    return {};
}


def hashlib_na -> dict[str, any] {
    msg = b"The quick brown fox jumps over the lazy dog";
    key = b"a-secret-hmac-key";

    inc = hashlib.sha256(b"");
    inc.update(b"The quick brown fox ");
    inc.update(b"jumps over the lazy dog");

    nc = hashlib.sha256(b"abc");
    nc_first = nc.hexdigest();
    nc.update(b"def");
    nc_second = nc.hexdigest();

    cp_src = hashlib.sha256(b"abc");
    cp = cp_src.copy();
    cp_src.update(b"1");
    cp.update(b"2");

    hm_src = hmac.new(key, msg, "sha256");
    hm_cp = hm_src.copy();
    hm_src.update(b"1");
    hm_cp.update(b"2");

    err_new = "?";
    try {
        hashlib.new("bogus");
    } except ValueError as e {
        err_new = str(e);
    }
    err_hm = "?";
    try {
        hmac.new(key, msg);
    } except TypeError as e {
        err_hm = str(e);
    }
    err_msg = "?";
    try {
        bad_msg: any = "str";
        hmac.new(key, bad_msg, "sha256");
    } except TypeError as e {
        err_msg = str(e);
    }
    err_keystr = "?";
    try {
        bad_key: any = "str";
        hmac.new(bad_key, msg, "sha256");
    } except TypeError as e {
        err_keystr = str(e);
    }
    err_keyint = "?";
    try {
        bad_ki: any = 123;
        hmac.new(bad_ki, msg, "sha256");
    } except TypeError as e {
        err_keyint = str(e);
    }
    err_msgint = "?";
    try {
        bad_mi: any = 123;
        hmac.new(key, bad_mi, "sha256");
    } except TypeError as e {
        err_msgint = str(e);
    }

    return {
        "md5": hashlib.md5(msg).hexdigest(),
        "sha1": hashlib.sha1(msg).hexdigest(),
        "sha224": hashlib.sha224(msg).hexdigest(),
        "sha256": hashlib.sha256(msg).hexdigest(),
        "sha384": hashlib.sha384(msg).hexdigest(),
        "sha512": hashlib.sha512(msg).hexdigest(),
        "sha3_224": hashlib.sha3_224(msg).hexdigest(),
        "sha3_256": hashlib.sha3_256(msg).hexdigest(),
        "sha3_384": hashlib.sha3_384(msg).hexdigest(),
        "blake2b": hashlib.blake2b(msg).hexdigest(),
        "blake2s": hashlib.blake2s(msg).hexdigest(),
        "sha256_empty": hashlib.sha256(b"").hexdigest(),
        "sha256_incremental": inc.hexdigest(),
        "sha256_nc_first": nc_first,
        "sha256_nc_second": nc_second,
        "sha256_copy_orig": cp_src.hexdigest(),
        "sha256_copy_clone": cp.hexdigest(),
        "hmac_copy_orig": hm_src.hexdigest(),
        "hmac_copy_clone": hm_cp.hexdigest(),
        "sha256_size": hashlib.sha256(b"").digest_size,
        "sha256_block": hashlib.sha256(b"").block_size,
        "sha256_name": hashlib.sha256(b"").name,
        "sha512_size": hashlib.sha512(b"").digest_size,
        "blake2b_size": hashlib.blake2b(msg).digest_size,
        "blake2s_block": hashlib.blake2s(msg).block_size,
        "hashlib_new": hashlib.new("sha256", msg).hexdigest(),
        "new_err": err_new,
        "hmac_sha256": hmac.new(key, msg, "sha256").hexdigest(),
        "hmac_sha1": hmac.new(key, msg, "sha1").hexdigest(),
        "hmac_sha512": hmac.new(key, msg, "sha512").hexdigest(),
        "hmac_name": hmac.new(key, msg, "sha256").name,
        "hmac_sha3_name": hmac.new(key, msg, "sha3_256").name,
        "hmac_size": hmac.new(key, msg, "sha256").digest_size,
        "hmac_msg_none": hmac.new(key, None, "sha256").hexdigest(),
        "hmac_err_nodm": err_hm,
        "hmac_err_msgstr": err_msg,
        "hmac_err_keystr": err_keystr,
        "hmac_err_keyint": err_keyint,
        "hmac_err_msgint": err_msgint,
        "cd_eq": 1 if hmac.compare_digest(b"abc", b"abc") else 0,
        "cd_neq": 1 if hmac.compare_digest(b"abc", b"abd") else 0,
        "cd_len": 1 if hmac.compare_digest(b"abc", b"ab") else 0,

    };
}
