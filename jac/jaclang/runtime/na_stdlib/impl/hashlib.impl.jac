impl Hash.update(data: bytes) {
    self._core.update(data);
}

impl Hash.digest -> bytes {
    return self._core.finish();
}

impl Hash.hexdigest -> str {
    return to_hex(self.digest());
}

impl Hash.copy -> Hash {
    return Hash(
        _core=self._core.clone(),
        digest_size=self.digest_size,
        block_size=self.block_size,
        name=self.name
    );
}

impl Hash.drop {}

impl new(name: str, data: bytes = b"") -> Hash {
    core = new_core(name);
    if core is None {
        raise ValueError("unsupported hash type " + name);
    }
    h = Hash(
        _core=core, digest_size=core.digest_size, block_size=core.block_size, name=name
    );
    h.update(data);
    return h;
}

impl md5(data: bytes = b"") -> Hash {
    return new("md5", data);
}

impl sha1(data: bytes = b"") -> Hash {
    return new("sha1", data);
}

impl sha224(data: bytes = b"") -> Hash {
    return new("sha224", data);
}

impl sha256(data: bytes = b"") -> Hash {
    return new("sha256", data);
}

impl sha384(data: bytes = b"") -> Hash {
    return new("sha384", data);
}

impl sha512(data: bytes = b"") -> Hash {
    return new("sha512", data);
}

impl sha3_224(data: bytes = b"") -> Hash {
    return new("sha3_224", data);
}

impl sha3_256(data: bytes = b"") -> Hash {
    return new("sha3_256", data);
}

impl sha3_384(data: bytes = b"") -> Hash {
    return new("sha3_384", data);
}

impl sha3_512(data: bytes = b"") -> Hash {
    return new("sha3_512", data);
}

impl blake2b(data: bytes = b"") -> Hash {
    return new("blake2b", data);
}

impl blake2s(data: bytes = b"") -> Hash {
    return new("blake2s", data);
}
