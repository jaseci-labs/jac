import from crypto { def EVP_MD_CTX_new -> int;  }
import from crypto { def EVP_MD_CTX_free(ctx: int) -> None;  }
import from crypto { def EVP_DigestInit_ex(ctx: int, md: int, engine: int) -> i32;  }
import from crypto { def EVP_DigestUpdate(ctx: int, data: bytes, n: u64) -> i32;  }
import from crypto {
    def EVP_DigestFinal_ex(ctx: int, md_out: bytes, outlen: bytes) -> i32;
}

import from crypto { def EVP_md5 -> int;  }
import from crypto { def EVP_sha1 -> int;  }
import from crypto { def EVP_sha224 -> int;  }
import from crypto { def EVP_sha256 -> int;  }
import from crypto { def EVP_sha384 -> int;  }
import from crypto { def EVP_sha512 -> int;  }
import from crypto { def EVP_sha3_256 -> int;  }
import from crypto { def EVP_sha3_512 -> int;  }

import from crypto { def HMAC_CTX_new -> int;  }
import from crypto { def HMAC_CTX_free(ctx: int) -> None;  }
import from crypto {
    def HMAC_Init_ex(ctx: int, key: bytes, keylen: i32, md: int, engine: int) -> i32;
}
import from crypto { def HMAC_Update(ctx: int, data: bytes, n: u64) -> i32;  }
import from crypto { def HMAC_Final(ctx: int, md_out: bytes, outlen: bytes) -> i32;  }


def:pub evp_md_for(name: str) -> int {
    if name == "md5" {
        return EVP_md5();
    } elif name == "sha1" {
        return EVP_sha1();
    } elif name == "sha224" {
        return EVP_sha224();
    } elif name == "sha256" {
        return EVP_sha256();
    } elif name == "sha384" {
        return EVP_sha384();
    } elif name == "sha512" {
        return EVP_sha512();
    } elif name == "sha3_256" {
        return EVP_sha3_256();
    } elif name == "sha3_512" {
        return EVP_sha3_512();
    }
    return 0;
}


def:pub digest_size_for(name: str) -> int {
    if name == "md5" {
        return 16;
    } elif name == "sha1" {
        return 20;
    } elif name == "sha224" {
        return 28;
    } elif name == "sha256" {
        return 32;
    } elif name == "sha384" {
        return 48;
    } elif name == "sha512" {
        return 64;
    } elif name == "sha3_256" {
        return 32;
    } elif name == "sha3_512" {
        return 64;
    }
    return 0;
}


def:pub block_size_for(name: str) -> int {
    if name == "md5" {
        return 64;
    } elif name == "sha1" {
        return 64;
    } elif name == "sha224" {
        return 64;
    } elif name == "sha256" {
        return 64;
    } elif name == "sha384" {
        return 128;
    } elif name == "sha512" {
        return 128;
    } elif name == "sha3_256" {
        return 136;
    } elif name == "sha3_512" {
        return 72;
    }
    return 0;
}


def:pub evp_digest(md: int, chunks: list[bytes], digest_size: int) -> bytes {
    ctx: int = EVP_MD_CTX_new();
    if ctx == 0 {
        raise ValueError("EVP_MD_CTX_new failed (out of memory)");
    }
    if EVP_DigestInit_ex(ctx, md, 0) != 1 {
        EVP_MD_CTX_free(ctx);
        raise ValueError("EVP_DigestInit_ex failed");
    }
    for c in chunks {
        if EVP_DigestUpdate(ctx, c, len(c)) != 1 {
            EVP_MD_CTX_free(ctx);
            raise ValueError("EVP_DigestUpdate failed");
        }
    }
    out = b"\x00" * digest_size;

    outlen = b"\x00" * 4;
    if EVP_DigestFinal_ex(ctx, out, outlen) != 1 {
        EVP_MD_CTX_free(ctx);
        raise ValueError("EVP_DigestFinal_ex failed");
    }
    EVP_MD_CTX_free(ctx);
    return out;
}


def:pub hmac_digest(
    md: int, key: bytes, chunks: list[bytes], digest_size: int
) -> bytes {
    ctx: int = HMAC_CTX_new();
    if ctx == 0 {
        raise ValueError("HMAC_CTX_new failed (out of memory)");
    }
    if HMAC_Init_ex(ctx, key, len(key), md, 0) != 1 {
        HMAC_CTX_free(ctx);
        raise ValueError("HMAC_Init_ex failed");
    }
    for c in chunks {
        if HMAC_Update(ctx, c, len(c)) != 1 {
            HMAC_CTX_free(ctx);
            raise ValueError("HMAC_Update failed");
        }
    }
    out = b"\x00" * digest_size;

    outlen = b"\x00" * 4;
    if HMAC_Final(ctx, out, outlen) != 1 {
        HMAC_CTX_free(ctx);
        raise ValueError("HMAC_Final failed");
    }
    HMAC_CTX_free(ctx);
    return out;
}


def:pub to_hex(data: bytes) -> str {
    digits: str = "0123456789abcdef";
    out: str = "";
    n: int = len(data);
    i: int = 0;
    while i < n {
        v: int = data[i];
        out += digits[(v // 16) % 16];
        out += digits[v % 16];
        i += 1;
    }
    return out;
}
