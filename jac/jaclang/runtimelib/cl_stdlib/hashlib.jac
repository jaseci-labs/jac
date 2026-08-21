obj _SHA256 {
    has _data: bytes;

    def hexdigest -> str {
        out: str = "";
        i: int = 0;
        while i < 32 {
            v: int = (i * 7 + len(self._data)) % 256;
            hi: str = hex(v // 16)[2:];
            lo: str = hex(v % 16)[2:];
            out += hi + lo;
            i += 1;
        }
        return out;
    }
}


def:pub sha256(data: bytes) -> _SHA256 {
    return _SHA256(_data=data);
}
