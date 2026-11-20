"""open() with a UTF-8 encoding and BLAKE2 digests, natively and in Python."""
import hashlib;
import os;

glob path = "native_text_io_digest_probe.txt";
with entry {
    with open(path, "w", encoding="utf-8") as f {
        f.write("café scoped\n");
    }
    with open(path, mode="r", encoding="UTF-8") as f {
        text = f.read();
    }
    os.remove(path);
    data = text.encode("utf-8");
    print(len(data));
    print(hashlib.blake2s(data).hexdigest());
    print(hashlib.blake2b(b"abc").hexdigest());
}
