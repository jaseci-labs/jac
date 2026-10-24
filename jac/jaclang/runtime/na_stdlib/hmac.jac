obj:pub HMAC {
    has _inner: DigestCore,
        _outer: DigestCore,
        digest_size: int,
        block_size: int,
        name: str;

    def update(data: bytes);
    def digest -> bytes;
    def hexdigest -> str;
    def copy -> HMAC;
    def drop;
}


def:pub new(key: any, msg: any = None, digestmod: str = "") -> HMAC;


def:pub digest(key: any, msg: any, digest: str) -> bytes;


def:pub compare_digest(a: bytes, b: bytes) -> bool;
