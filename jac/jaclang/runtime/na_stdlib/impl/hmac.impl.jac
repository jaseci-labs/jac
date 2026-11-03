impl HMAC.update(data: bytes) {
    self._core.update(data);
}

impl HMAC.digest -> bytes {
    return self._core.finish();
}

impl HMAC.hexdigest -> str {
    return to_hex(self.digest());
}

impl HMAC.copy -> HMAC {
    return HMAC(
        _core=self._core.clone(),
        digest_size=self.digest_size,
        block_size=self.block_size,
        name=self.name
    );
}

impl HMAC.drop {}

impl new(key: any, msg: any = None, digestmod: str = "") -> HMAC {
    k: bytes = b"";
    if isinstance(key, bytearray) {
        k = bytes(key);
    } elif isinstance(key, bytes) {
        k = key;
    } else {
        raise TypeError(
            "key: expected bytes or bytearray, but got '" + typename(key) + "'"
        );
    }
    if digestmod == "" {
        raise TypeError("Missing required argument 'digestmod'.");
    }
    core = new_hmac(digestmod, __bytes_data(k), len(k));
    if core is None {
        raise ValueError("unsupported hash type " + digestmod);
    }
    data: bytes = b"";
    if isinstance(msg, bytearray) {
        data = bytes(msg);
    } elif isinstance(msg, bytes) {
        data = msg;
    } elif isinstance(msg, str) {
        raise TypeError("Strings must be encoded before hashing");
    } elif msg is not None {
        raise TypeError("object supporting the buffer API required");
    }
    hm = HMAC(
        _core=core,
        digest_size=core.digest_size,
        block_size=core.block_size,
        name="hmac-" + digestmod
    );
    hm.update(data);
    return hm;
}

impl digest(key: any, msg: any, digest: str) -> bytes {
    return new(key, msg, digest).digest();
}

impl compare_digest(a: bytes, b: bytes) -> bool {
    same: bool = len(a) == len(b);
    left: bytes = b;
    diff: int = 1;
    if same {
        left = a;
        diff = 0;
    }
    i: int = 0;
    while i < len(b) {
        diff = diff | (left[i] ^ b[i]);
        i += 1;
    }
    return diff == 0;
}
