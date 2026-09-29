"""AOT archive checksum probe; the caller supplies a synthetic ZIP path."""
import sys;
import from zipfile { ZipFile }
import from zlib { crc32 }

with entry {
    total = 0;
    with ZipFile(sys.argv[1]) as archive {
        names = archive.namelist();
        for name in names {
            data = archive.read(name);
            total = (total + crc32(data) + len(data)) & 4294967295;
        }
        print(len(names), total);
    }
}
