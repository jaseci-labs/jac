import from _hashlib_native {
    evp_md_for,
    digest_size_for,
    block_size_for,
    evp_digest,
    to_hex
}


obj:pub Hash {
    has _md: int,
        _chunks: list[bytes],
        digest_size: int,
        block_size: int,
        name: str;

    def update(data: bytes) {
        self._chunks.append(data);
    }

    def digest -> bytes {
        return evp_digest(self._md, self._chunks, self.digest_size);
    }

    def hexdigest -> str {
        return to_hex(self.digest());
    }

    def copy -> Hash {
        cp: list[bytes] = [];
        for c in self._chunks {
            cp.append(c);
        }
        return Hash(
            _md=self._md,
            _chunks=cp,
            digest_size=self.digest_size,
            block_size=self.block_size,
            name=self.name
        );
    }
}


def:priv new(name: str, data: bytes = b"") -> Hash {
    md: int = evp_md_for(name);
    if md == 0 {
        raise ValueError("unsupported hash type " + name);
    }
    h = Hash(
        _md=md,
        _chunks=[],
        digest_size=digest_size_for(name),
        block_size=block_size_for(name),
        name=name
    );
    h.update(data);
    return h;
}


def:pub md5(data: bytes = b"") -> Hash {
    return new("md5", data);
}


def:pub sha1(data: bytes = b"") -> Hash {
    return new("sha1", data);
}


def:pub sha224(data: bytes = b"") -> Hash {
    return new("sha224", data);
}


def:pub sha256(data: bytes = b"") -> Hash {
    return new("sha256", data);
}


def:pub sha384(data: bytes = b"") -> Hash {
    return new("sha384", data);
}


def:pub sha512(data: bytes = b"") -> Hash {
    return new("sha512", data);
}


def:pub sha3_256(data: bytes = b"") -> Hash {
    return new("sha3_256", data);
}


def:pub sha3_512(data: bytes = b"") -> Hash {
    return new("sha3_512", data);
}
