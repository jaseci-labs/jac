import hashlib;
import hmac;

def payload(n: int, seed: int) -> bytes {
    out: list[int] = [];
    x: int = seed;
    i: int = 0;
    while i < n {
        x = (x * 1103515245 + 12345) % 2147483648;
        out.append((x >> 16) & 255);
        i += 1;
    }
    return bytes(out);
}

glob names: list[str] = [
         "md5",
         "sha1",
         "sha224",
         "sha256",
         "sha384",
         "sha512",
         "sha3_224",
         "sha3_256",
         "sha3_384",
         "sha3_512",
         "blake2b",
         "blake2s"
     ],
     sizes: list[int] = [
         0,
         1,
         3,
         55,
         56,
         57,
         63,
         64,
         65,
         71,
         72,
         103,
         104,
         111,
         112,
         119,
         127,
         128,
         129,
         135,
         136,
         137,
         143,
         144,
         145,
         255,
         256,
         1000
     ];

with entry {
    for name in names {
        for n in sizes {
            data = payload(n, n + 7);
            whole = hashlib.new(name, data);
            parts = hashlib.new(name);
            cut: int = n // 3;
            parts.update(data[:cut]);
            snapshot = parts.copy();
            parts.update(data[cut:]);
            snapshot.update(data[cut:]);
            key = payload(n % 200, n + 11);
            mac = hmac.new(key, data, name).hexdigest();
            print(
                name,
                n,
                whole.hexdigest(),
                parts.digest() == whole.digest(),
                snapshot.hexdigest() == whole.hexdigest(),
                whole.digest_size,
                whole.block_size,
                mac
            );
        }
    }
    print(hashlib.sha256(b"abc").hexdigest(), hashlib.md5().hexdigest());
}
