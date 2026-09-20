"""An ordinary Jac file imports zlib when built as a hosted native application."""
import from zlib { crc32 }

with entry {
    print("crc32:", crc32(b"123456789"));
}
