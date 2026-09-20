"""Hashlib: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
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

    return {
        "md5": hashlib.md5(msg).hexdigest(),
        "sha1": hashlib.sha1(msg).hexdigest(),
        "sha224": hashlib.sha224(msg).hexdigest(),
        "sha256": hashlib.sha256(msg).hexdigest(),
        "sha384": hashlib.sha384(msg).hexdigest(),
        "sha512": hashlib.sha512(msg).hexdigest(),
        "sha3_256": hashlib.sha3_256(msg).hexdigest(),
        "sha256_empty": hashlib.sha256(b"").hexdigest(),
        "sha256_incremental": inc.hexdigest(),
        "sha256_nc_first": nc_first,
        "sha256_nc_second": nc_second,
        "sha256_size": hashlib.sha256(b"").digest_size,
        "sha256_block": hashlib.sha256(b"").block_size,
        "sha256_name": hashlib.sha256(b"").name,
        "sha512_size": hashlib.sha512(b"").digest_size,
        "hmac_sha256": hmac.new(key, msg, "sha256").hexdigest(),
        "hmac_sha1": hmac.new(key, msg, "sha1").hexdigest(),
        "hmac_sha512": hmac.new(key, msg, "sha512").hexdigest(),
        "hmac_name": hmac.new(key, msg, "sha256").name,
        "hmac_size": hmac.new(key, msg, "sha256").digest_size,

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

    return {
        "md5": hashlib.md5(msg).hexdigest(),
        "sha1": hashlib.sha1(msg).hexdigest(),
        "sha224": hashlib.sha224(msg).hexdigest(),
        "sha256": hashlib.sha256(msg).hexdigest(),
        "sha384": hashlib.sha384(msg).hexdigest(),
        "sha512": hashlib.sha512(msg).hexdigest(),
        "sha3_256": hashlib.sha3_256(msg).hexdigest(),
        "sha256_empty": hashlib.sha256(b"").hexdigest(),
        "sha256_incremental": inc.hexdigest(),
        "sha256_nc_first": nc_first,
        "sha256_nc_second": nc_second,
        "sha256_size": hashlib.sha256(b"").digest_size,
        "sha256_block": hashlib.sha256(b"").block_size,
        "sha256_name": hashlib.sha256(b"").name,
        "sha512_size": hashlib.sha512(b"").digest_size,
        "hmac_sha256": hmac.new(key, msg, "sha256").hexdigest(),
        "hmac_sha1": hmac.new(key, msg, "sha1").hexdigest(),
        "hmac_sha512": hmac.new(key, msg, "sha512").hexdigest(),
        "hmac_name": hmac.new(key, msg, "sha256").name,
        "hmac_size": hmac.new(key, msg, "sha256").digest_size,

    };
}
