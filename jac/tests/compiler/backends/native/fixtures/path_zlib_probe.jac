"""AOT composition of native file reads and mutable-buffer decompression."""
import sys;
import zlib;
import from pathlib { Path }

with entry {
    compressed = Path(sys.argv[1]).read_bytes();
    assert zlib.decompress(bytearray(compressed)) == b"\x00\xffnative\r\n" * 500;
    assert zlib.decompress(compressed) == b"\x00\xffnative\r\n" * 500;
    print("NATIVE FILE ZLIB PASS");
}
