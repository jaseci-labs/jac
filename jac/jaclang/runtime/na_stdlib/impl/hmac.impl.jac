impl HMAC.update(data: bytes) {
    self._inner.update(data);
}

impl HMAC.digest -> bytes {
    outer = self._outer.clone();
    outer.update(self._inner.finish());
    return outer.finish();
}

impl HMAC.hexdigest -> str {
    return to_hex(self.digest());
}

impl HMAC.copy -> HMAC {
    return HMAC(
        _inner=self._inner.clone(),
        _outer=self._outer.clone(),
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
    inner = new_core(digestmod);
    outer = new_core(digestmod);
    if inner is None or outer is None {
        raise ValueError("unsupported hash type " + digestmod);
    }
    bs: int = inner.block_size;
    if len(k) > bs {
        shrink = new_core(digestmod);
        if shrink is not None {
            shrink.update(k);
            k = shrink.finish();
        }
    }
    ipad: list[int] = [];
    opad: list[int] = [];
    i: int = 0;
    while i < bs {
        kb: int = k[i] if i < len(k) else 0;
        ipad.append(kb ^ 0x36);
        opad.append(kb ^ 0x5c);
        i += 1;
    }
    inner.update(bytes(ipad));
    outer.update(bytes(opad));
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
        _inner=inner,
        _outer=outer,
        digest_size=inner.digest_size,
        block_size=bs,
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
