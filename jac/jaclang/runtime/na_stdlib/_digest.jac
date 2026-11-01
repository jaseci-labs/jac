glob _MD5_K: list[u32] = [
         u32(0xd76aa478),
         u32(0xe8c7b756),
         u32(0x242070db),
         u32(0xc1bdceee),
         u32(0xf57c0faf),
         u32(0x4787c62a),
         u32(0xa8304613),
         u32(0xfd469501),
         u32(0x698098d8),
         u32(0x8b44f7af),
         u32(0xffff5bb1),
         u32(0x895cd7be),
         u32(0x6b901122),
         u32(0xfd987193),
         u32(0xa679438e),
         u32(0x49b40821),
         u32(0xf61e2562),
         u32(0xc040b340),
         u32(0x265e5a51),
         u32(0xe9b6c7aa),
         u32(0xd62f105d),
         u32(0x02441453),
         u32(0xd8a1e681),
         u32(0xe7d3fbc8),
         u32(0x21e1cde6),
         u32(0xc33707d6),
         u32(0xf4d50d87),
         u32(0x455a14ed),
         u32(0xa9e3e905),
         u32(0xfcefa3f8),
         u32(0x676f02d9),
         u32(0x8d2a4c8a),
         u32(0xfffa3942),
         u32(0x8771f681),
         u32(0x6d9d6122),
         u32(0xfde5380c),
         u32(0xa4beea44),
         u32(0x4bdecfa9),
         u32(0xf6bb4b60),
         u32(0xbebfbc70),
         u32(0x289b7ec6),
         u32(0xeaa127fa),
         u32(0xd4ef3085),
         u32(0x04881d05),
         u32(0xd9d4d039),
         u32(0xe6db99e5),
         u32(0x1fa27cf8),
         u32(0xc4ac5665),
         u32(0xf4292244),
         u32(0x432aff97),
         u32(0xab9423a7),
         u32(0xfc93a039),
         u32(0x655b59c3),
         u32(0x8f0ccc92),
         u32(0xffeff47d),
         u32(0x85845dd1),
         u32(0x6fa87e4f),
         u32(0xfe2ce6e0),
         u32(0xa3014314),
         u32(0x4e0811a1),
         u32(0xf7537e82),
         u32(0xbd3af235),
         u32(0x2ad7d2bb),
         u32(0xeb86d391)
     ],
     _MD5_S: list[u32] = [
         u32(7),
         u32(12),
         u32(17),
         u32(22),
         u32(7),
         u32(12),
         u32(17),
         u32(22),
         u32(7),
         u32(12),
         u32(17),
         u32(22),
         u32(7),
         u32(12),
         u32(17),
         u32(22),
         u32(5),
         u32(9),
         u32(14),
         u32(20),
         u32(5),
         u32(9),
         u32(14),
         u32(20),
         u32(5),
         u32(9),
         u32(14),
         u32(20),
         u32(5),
         u32(9),
         u32(14),
         u32(20),
         u32(4),
         u32(11),
         u32(16),
         u32(23),
         u32(4),
         u32(11),
         u32(16),
         u32(23),
         u32(4),
         u32(11),
         u32(16),
         u32(23),
         u32(4),
         u32(11),
         u32(16),
         u32(23),
         u32(6),
         u32(10),
         u32(15),
         u32(21),
         u32(6),
         u32(10),
         u32(15),
         u32(21),
         u32(6),
         u32(10),
         u32(15),
         u32(21),
         u32(6),
         u32(10),
         u32(15),
         u32(21)
     ],
     _SHA256_K: list[u32] = [
         u32(0x428a2f98),
         u32(0x71374491),
         u32(0xb5c0fbcf),
         u32(0xe9b5dba5),
         u32(0x3956c25b),
         u32(0x59f111f1),
         u32(0x923f82a4),
         u32(0xab1c5ed5),
         u32(0xd807aa98),
         u32(0x12835b01),
         u32(0x243185be),
         u32(0x550c7dc3),
         u32(0x72be5d74),
         u32(0x80deb1fe),
         u32(0x9bdc06a7),
         u32(0xc19bf174),
         u32(0xe49b69c1),
         u32(0xefbe4786),
         u32(0x0fc19dc6),
         u32(0x240ca1cc),
         u32(0x2de92c6f),
         u32(0x4a7484aa),
         u32(0x5cb0a9dc),
         u32(0x76f988da),
         u32(0x983e5152),
         u32(0xa831c66d),
         u32(0xb00327c8),
         u32(0xbf597fc7),
         u32(0xc6e00bf3),
         u32(0xd5a79147),
         u32(0x06ca6351),
         u32(0x14292967),
         u32(0x27b70a85),
         u32(0x2e1b2138),
         u32(0x4d2c6dfc),
         u32(0x53380d13),
         u32(0x650a7354),
         u32(0x766a0abb),
         u32(0x81c2c92e),
         u32(0x92722c85),
         u32(0xa2bfe8a1),
         u32(0xa81a664b),
         u32(0xc24b8b70),
         u32(0xc76c51a3),
         u32(0xd192e819),
         u32(0xd6990624),
         u32(0xf40e3585),
         u32(0x106aa070),
         u32(0x19a4c116),
         u32(0x1e376c08),
         u32(0x2748774c),
         u32(0x34b0bcb5),
         u32(0x391c0cb3),
         u32(0x4ed8aa4a),
         u32(0x5b9cca4f),
         u32(0x682e6ff3),
         u32(0x748f82ee),
         u32(0x78a5636f),
         u32(0x84c87814),
         u32(0x8cc70208),
         u32(0x90befffa),
         u32(0xa4506ceb),
         u32(0xbef9a3f7),
         u32(0xc67178f2)
     ],
     _SHA256_IV: list[u32] = [
         u32(0x6a09e667),
         u32(0xbb67ae85),
         u32(0x3c6ef372),
         u32(0xa54ff53a),
         u32(0x510e527f),
         u32(0x9b05688c),
         u32(0x1f83d9ab),
         u32(0x5be0cd19)
     ],
     _SHA224_IV: list[u32] = [
         u32(0xc1059ed8),
         u32(0x367cd507),
         u32(0x3070dd17),
         u32(0xf70e5939),
         u32(0xffc00b31),
         u32(0x68581511),
         u32(0x64f98fa7),
         u32(0xbefa4fa4)
     ],
     _SHA512_K: list[u64] = [
         u64(0x428a2f98d728ae22),
         u64(0x7137449123ef65cd),
         u64(0xb5c0fbcfec4d3b2f),
         u64(0xe9b5dba58189dbbc),
         u64(0x3956c25bf348b538),
         u64(0x59f111f1b605d019),
         u64(0x923f82a4af194f9b),
         u64(0xab1c5ed5da6d8118),
         u64(0xd807aa98a3030242),
         u64(0x12835b0145706fbe),
         u64(0x243185be4ee4b28c),
         u64(0x550c7dc3d5ffb4e2),
         u64(0x72be5d74f27b896f),
         u64(0x80deb1fe3b1696b1),
         u64(0x9bdc06a725c71235),
         u64(0xc19bf174cf692694),
         u64(0xe49b69c19ef14ad2),
         u64(0xefbe4786384f25e3),
         u64(0x0fc19dc68b8cd5b5),
         u64(0x240ca1cc77ac9c65),
         u64(0x2de92c6f592b0275),
         u64(0x4a7484aa6ea6e483),
         u64(0x5cb0a9dcbd41fbd4),
         u64(0x76f988da831153b5),
         u64(0x983e5152ee66dfab),
         u64(0xa831c66d2db43210),
         u64(0xb00327c898fb213f),
         u64(0xbf597fc7beef0ee4),
         u64(0xc6e00bf33da88fc2),
         u64(0xd5a79147930aa725),
         u64(0x06ca6351e003826f),
         u64(0x142929670a0e6e70),
         u64(0x27b70a8546d22ffc),
         u64(0x2e1b21385c26c926),
         u64(0x4d2c6dfc5ac42aed),
         u64(0x53380d139d95b3df),
         u64(0x650a73548baf63de),
         u64(0x766a0abb3c77b2a8),
         u64(0x81c2c92e47edaee6),
         u64(0x92722c851482353b),
         u64(0xa2bfe8a14cf10364),
         u64(0xa81a664bbc423001),
         u64(0xc24b8b70d0f89791),
         u64(0xc76c51a30654be30),
         u64(0xd192e819d6ef5218),
         u64(0xd69906245565a910),
         u64(0xf40e35855771202a),
         u64(0x106aa07032bbd1b8),
         u64(0x19a4c116b8d2d0c8),
         u64(0x1e376c085141ab53),
         u64(0x2748774cdf8eeb99),
         u64(0x34b0bcb5e19b48a8),
         u64(0x391c0cb3c5c95a63),
         u64(0x4ed8aa4ae3418acb),
         u64(0x5b9cca4f7763e373),
         u64(0x682e6ff3d6b2b8a3),
         u64(0x748f82ee5defb2fc),
         u64(0x78a5636f43172f60),
         u64(0x84c87814a1f0ab72),
         u64(0x8cc702081a6439ec),
         u64(0x90befffa23631e28),
         u64(0xa4506cebde82bde9),
         u64(0xbef9a3f7b2c67915),
         u64(0xc67178f2e372532b),
         u64(0xca273eceea26619c),
         u64(0xd186b8c721c0c207),
         u64(0xeada7dd6cde0eb1e),
         u64(0xf57d4f7fee6ed178),
         u64(0x06f067aa72176fba),
         u64(0x0a637dc5a2c898a6),
         u64(0x113f9804bef90dae),
         u64(0x1b710b35131c471b),
         u64(0x28db77f523047d84),
         u64(0x32caab7b40c72493),
         u64(0x3c9ebe0a15c9bebc),
         u64(0x431d67c49c100d4c),
         u64(0x4cc5d4becb3e42b6),
         u64(0x597f299cfc657e2a),
         u64(0x5fcb6fab3ad6faec),
         u64(0x6c44198c4a475817)
     ],
     _SHA512_IV: list[u64] = [
         u64(0x6a09e667f3bcc908),
         u64(0xbb67ae8584caa73b),
         u64(0x3c6ef372fe94f82b),
         u64(0xa54ff53a5f1d36f1),
         u64(0x510e527fade682d1),
         u64(0x9b05688c2b3e6c1f),
         u64(0x1f83d9abfb41bd6b),
         u64(0x5be0cd19137e2179)
     ],
     _SHA384_IV: list[u64] = [
         u64(0xcbbb9d5dc1059ed8),
         u64(0x629a292a367cd507),
         u64(0x9159015a3070dd17),
         u64(0x152fecd8f70e5939),
         u64(0x67332667ffc00b31),
         u64(0x8eb44a8768581511),
         u64(0xdb0c2e0d64f98fa7),
         u64(0x47b5481dbefa4fa4)
     ],
     _KECCAK_RC: list[u64] = [
         u64(0x0000000000000001),
         u64(0x0000000000008082),
         u64(0x800000000000808a),
         u64(0x8000000080008000),
         u64(0x000000000000808b),
         u64(0x0000000080000001),
         u64(0x8000000080008081),
         u64(0x8000000000008009),
         u64(0x000000000000008a),
         u64(0x0000000000000088),
         u64(0x0000000080008009),
         u64(0x000000008000000a),
         u64(0x000000008000808b),
         u64(0x800000000000008b),
         u64(0x8000000000008089),
         u64(0x8000000000008003),
         u64(0x8000000000008002),
         u64(0x8000000000000080),
         u64(0x000000000000800a),
         u64(0x800000008000000a),
         u64(0x8000000080008081),
         u64(0x8000000000008080),
         u64(0x0000000080000001),
         u64(0x8000000080008008)
     ],
     _BLAKE2_SIGMA: list[int] = [
         0,
         1,
         2,
         3,
         4,
         5,
         6,
         7,
         8,
         9,
         10,
         11,
         12,
         13,
         14,
         15,
         14,
         10,
         4,
         8,
         9,
         15,
         13,
         6,
         1,
         12,
         0,
         2,
         11,
         7,
         5,
         3,
         11,
         8,
         12,
         0,
         5,
         2,
         15,
         13,
         10,
         14,
         3,
         6,
         7,
         1,
         9,
         4,
         7,
         9,
         3,
         1,
         13,
         12,
         11,
         14,
         2,
         6,
         5,
         10,
         4,
         0,
         15,
         8,
         9,
         0,
         5,
         7,
         2,
         4,
         10,
         15,
         14,
         1,
         11,
         12,
         6,
         8,
         3,
         13,
         2,
         12,
         6,
         10,
         0,
         11,
         8,
         3,
         4,
         13,
         7,
         5,
         15,
         14,
         1,
         9,
         12,
         5,
         1,
         15,
         14,
         13,
         4,
         10,
         0,
         7,
         6,
         3,
         9,
         2,
         8,
         11,
         13,
         11,
         7,
         14,
         12,
         1,
         3,
         9,
         5,
         0,
         15,
         4,
         8,
         6,
         2,
         10,
         6,
         15,
         14,
         9,
         11,
         3,
         0,
         8,
         12,
         2,
         13,
         7,
         1,
         4,
         10,
         5,
         10,
         2,
         8,
         4,
         7,
         6,
         1,
         5,
         15,
         11,
         9,
         14,
         3,
         12,
         13,
         0
     ];

obj DigestCore {
    has name: str = "",
        block_size: int = 64,
        digest_size: int = 0,
        pending: bytearray = bytearray(0),
        used: int = 0,
        compressed: int = 0;

    def update(data: bytes);
    def absorb(address: int, size: int);
    def compress(address: int, last: bool);
    def finish -> bytes;
    def squeeze(size: int) -> bytes;
    def clone -> DigestCore;
    def carry(copy: DigestCore) -> DigestCore;
    def pad_md(big: bool, length_bytes: int);
}

obj Md5Core(DigestCore) {
    has h: list[u32] = [];

    override def compress(address: int, last: bool);
    override def finish -> bytes;
    override def clone -> DigestCore;
}

obj Sha1Core(DigestCore) {
    has h: list[u32] = [],
        w: list[u32] = [];

    override def compress(address: int, last: bool);
    override def finish -> bytes;
    override def clone -> DigestCore;
}

obj Sha256Core(DigestCore) {
    has h: list[u32] = [],
        w: list[u32] = [];

    override def compress(address: int, last: bool);
    override def finish -> bytes;
    override def clone -> DigestCore;
}

obj Sha512Core(DigestCore) {
    has h: list[u64] = [],
        w: list[u64] = [];

    override def compress(address: int, last: bool);
    override def finish -> bytes;
    override def clone -> DigestCore;
}

obj Sha3Core(DigestCore) {
    has a: list[u64] = [],
        b: list[u64] = [],
        suffix: int = 6;

    override def compress(address: int, last: bool);
    override def finish -> bytes;
    override def squeeze(size: int) -> bytes;
    override def clone -> DigestCore;
}

obj Blake2sCore(DigestCore) {
    has h: list[u32] = [],
        v: list[u32] = [],
        last_node: bool = False;

    override def compress(address: int, last: bool);
    override def finish -> bytes;
    override def clone -> DigestCore;
}

obj Blake2bCore(DigestCore) {
    has h: list[u64] = [],
        v: list[u64] = [],
        last_node: bool = False;

    override def compress(address: int, last: bool);
    override def finish -> bytes;
    override def clone -> DigestCore;
}

obj HmacCore(DigestCore) {
    has inner: DigestCore = DigestCore(),
        outer: DigestCore = DigestCore();

    override def absorb(address: int, size: int);
    override def finish -> bytes;
    override def clone -> DigestCore;
}

def:pub new_core(name: str) -> (DigestCore | None);

def:pub new_blake2(
    wide: bool,
    digest_size: int,
    key: int,
    key_size: int,
    salt: int,
    salt_size: int,
    person: int,
    person_size: int,
    fanout: int,
    depth: int,
    leaf_size: int,
    node_offset: u64,
    node_depth: int,
    inner_size: int,
    last_node: bool
) -> DigestCore;

def:pub new_hmac(name: str, key: int, key_size: int) -> (DigestCore | None);

def _setup(
    core: DigestCore, name: str, block_size: int, digest_size: int
) -> DigestCore;

def _copy(target: int, source: int, size: int);

def _zero(target: int, size: int);

def _rotl32(x: u32, n: u32) -> u32;

def _rotr32(x: u32, n: u32) -> u32;

def _rotr64(x: u64, n: int) -> u64;

def _rotl64(x: u64, n: int) -> u64;

def _bswap32(x: u32) -> u32;

def _le32(address: int) -> u32;

def _be32(address: int) -> u32;

def _le64(address: int) -> u64;

def _be64(address: int) -> u64;

def _words32(h: list[u32], size: int, big: bool) -> bytes;

def _words64(h: list[u64], size: int, big: bool) -> bytes;

def _keccak(a: list[u64], b: list[u64]);

def _msg32(address: int, s: int) -> u32;

def _msg64(address: int, s: int) -> u64;

def _md5_step(a: u32, b: u32, f: u32, i: int, address: int, word: int) -> u32;
