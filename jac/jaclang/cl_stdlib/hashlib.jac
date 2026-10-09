obj _SHA256 {
    has _hex: str;

    def hexdigest -> str {
        return self._hex;
    }
}


def _sha256_hex(data: bytes) -> str {
    bun_glob: any = globalThis.Bun;
    hasher: any = new(bun_glob.CryptoHasher, "sha256");
    hasher.update(data);
    return hasher.digest("hex");
}


def:pub sha256(data: bytes) -> _SHA256 {
    return _SHA256(_hex=_sha256_hex(data));
}
