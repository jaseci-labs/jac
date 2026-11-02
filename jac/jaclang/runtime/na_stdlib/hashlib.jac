obj Hash {
    has _core: DigestCore,
        digest_size: int,
        block_size: int,
        name: str;

    def update(data: bytes);
    def digest -> bytes;
    def hexdigest -> str;
    def copy -> Hash;
    def drop;
}


def:pub new(name: str, data: bytes = b"") -> Hash;


def:pub md5(data: bytes = b"") -> Hash;


def:pub sha1(data: bytes = b"") -> Hash;


def:pub sha224(data: bytes = b"") -> Hash;


def:pub sha256(data: bytes = b"") -> Hash;


def:pub sha384(data: bytes = b"") -> Hash;


def:pub sha512(data: bytes = b"") -> Hash;


def:pub sha3_224(data: bytes = b"") -> Hash;


def:pub sha3_256(data: bytes = b"") -> Hash;


def:pub sha3_384(data: bytes = b"") -> Hash;


def:pub sha3_512(data: bytes = b"") -> Hash;


def:pub blake2b(data: bytes = b"") -> Hash;


def:pub blake2s(data: bytes = b"") -> Hash;
