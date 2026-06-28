import from _hashlib_native {
    evp_md_for,
    digest_size_for,
    block_size_for,
    hmac_digest,
    to_hex
}


obj:pub HMAC {
    has _md: int,
        _key: bytes,
        _chunks: list[bytes],
        digest_size: int,
        block_size: int,
        name: str;

    def update(data: bytes) {
        self._chunks.append(data);
    }

    def digest -> bytes {
        return hmac_digest(self._md, self._key, self._chunks, self.digest_size);
    }

    def hexdigest -> str {
        return to_hex(self.digest());
    }

    def copy -> HMAC {
        cp: list[bytes] = [];
        for c in self._chunks {
            cp.append(c);
        }
        return HMAC(
            _md=self._md,
            _key=self._key,
            _chunks=cp,
            digest_size=self.digest_size,
            block_size=self.block_size,
            name=self.name
        );
    }
}


def:pub new(key: bytes, msg: bytes = b"", digestmod: str = "sha256") -> HMAC {
    md: int = evp_md_for(digestmod);
    if md == 0 {
        raise ValueError("unsupported hash type " + digestmod);
    }
    hm = HMAC(
        _md=md,
        _key=key,
        _chunks=[],
        digest_size=digest_size_for(digestmod),
        block_size=block_size_for(digestmod),
        name="hmac-" + digestmod
    );
    hm.update(msg);
    return hm;
}


def:pub digest(key: bytes, msg: bytes, digest: str) -> bytes {
    return new(key, msg, digest).digest();
}
