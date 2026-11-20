---
description: The native compression and archive modules, zlib, gzip, bz2, lzma, compression.zstd, zipfile and tarfile - what each has, where each is available, and how they differ from CPython's.
keywords: compression, zlib, gzip, bz2, lzma, compression.zstd, zipfile, tarfile, zlib.compress, zlib.decompress, zlib.compressobj, zlib.decompressobj, zlib.crc32, zlib.adler32, zlib.error, gzip.compress, gzip.decompress, gzip.open, gzip.GzipFile, bz2.compress, bz2.decompress, bz2.open, bz2.BZ2File, lzma.compress, lzma.decompress, lzma.open, lzma.LZMAFile, lzma.LZMAError, zipfile.ZipFile, zipfile.ZipInfo, zipfile.Path, zipfile.BadZipFile, zipfile.is_zipfile, tarfile.open, tarfile.TarFile, tarfile.TarInfo, tarfile.is_tarfile, tarfile.data_filter
---
# Compression and archives

Seven native modules compress data and read and write archives, each with the names and
behavior of CPython 3.15's module of the same name (see [The library](index.md),
`jac docs library`). They call the compression libraries CPython calls, so which ones a
program can use depends on the platform it is built for: see [Where they are](#where-they-are).

```jac
import bz2;
import compression.zstd;
import gzip;
import io;
import lzma;
import zlib;

with entry {
    data = b"jac " * 100;
    packed = zlib.compress(data, level=9);
    print(len(data), len(packed), zlib.decompress(packed) == data);
    raw = zlib.compress(data, wbits=-15);
    print(zlib.decompress(raw, wbits=-15) == data, zlib.MAX_WBITS);
    gz = gzip.compress(data, mtime=0);
    print(gz[:4], zlib.decompress(gz, wbits=47) == data, zlib.decompress(packed, wbits=47) == data);
    print(gzip.decompress(gzip.compress(b"first,") + gzip.compress(b"second")));
    print(zlib.crc32(b"jac"), zlib.adler32(b"jac"), zlib.crc32(b""), zlib.adler32(b""));
    c = zlib.compressobj(level=6);
    stream = c.compress(data[:200]) + c.compress(data[200:]) + c.flush();
    d = zlib.decompressobj();
    print(d.decompress(stream, 8), len(d.unconsumed_tail) > 0);
    print(d.decompress(d.unconsumed_tail) == data[8:], d.eof);
    print(bz2.compress(data)[:3], lzma.compress(data)[:3], compression.zstd.compress(data)[:3]);
    print(bz2.decompress(bz2.compress(data)) == data, lzma.decompress(lzma.compress(data)) == data);
    buf = io.BytesIO();
    with gzip.GzipFile(fileobj=buf, mode="wb", mtime=0) as f {
        f.write(b"line one\nline two\n");
    }
    buf.seek(0);
    with gzip.open(buf, "rt") as text {
        print([line.strip() for line in text]);
    }
    try {
        zlib.decompress(b"not zlib");
    } except zlib.error as e {
        print("zlib.error:", e);
    }
    try {
        lzma.decompress(b"not xz");
    } except lzma.LZMAError as e {
        print("LZMAError:", e);
    }
}
```

```output
400 17 True
True 15
b'\x1f\x8b\x08\x00' True True
b'first,second'
308084192 40239407 0 1
b'jac jac ' True
True True
b'BZh' b'\xfd7z' b'(\xb5/'
True True
['line one', 'line two']
zlib.error: Error -3 while decompressing data: incorrect header check
LZMAError: Input format not supported by decoder
```

## What is there

| Module | Names |
|---|---|
| `zlib` | `compress(data, level=-1, wbits=15)`, `decompress(data, wbits=15, bufsize=16384)`, `compressobj`, `decompressobj` (with `unused_data`, `unconsumed_tail`, `eof`, `flush`, `copy`), `crc32`, `adler32`, `crc32_combine`, `adler32_combine`, `error`, and the constants (`MAX_WBITS`, `Z_BEST_COMPRESSION`, `ZLIB_VERSION`, ...) |
| `gzip` | `compress(data, compresslevel=6, *, mtime=0)`, `decompress(data)`, `open(filename, mode="rb", ...)`, `GzipFile`, `BadGzipFile` |
| `bz2` | `compress(data, compresslevel=9)`, `decompress(data)`, `open`, `BZ2File`, `BZ2Compressor`, `BZ2Decompressor` |
| `lzma` | `compress(data, format=FORMAT_XZ, check=-1, preset=None, filters=None)`, `decompress`, `open`, `LZMAFile`, `LZMACompressor`, `LZMADecompressor`, `LZMAError`, `is_check_supported`, and the `FORMAT_*`, `CHECK_*`, `FILTER_*`, `PRESET_*`, `MODE_*` and `MF_*` constants |
| `compression.zstd` | Python 3.14's Zstandard: `compress(data, level=None, options=None, zstd_dict=None)`, `decompress`, `open`, `ZstdFile`, `ZstdCompressor`, `ZstdDecompressor`, `ZstdDict`, `train_dict`, `finalize_dict`, `get_frame_info`, `get_frame_size`, `CompressionParameter`, `DecompressionParameter`, `Strategy`, `ZstdError` |
| `compression.zlib`, `compression.gzip`, `compression.bz2`, `compression.lzma` | The four modules above under Python 3.14's package |
| `zipfile` | `ZipFile(file, mode="r", compression=ZIP_STORED, allowZip64=True, compresslevel=None, ...)`: `namelist`, `infolist`, `getinfo`, `read`, `open`, `extract`, `extractall`, `write`, `writestr`, `mkdir`, `testzip`, `setpassword`, `comment`, `close`, `with`; `ZipInfo`, `Path`, `is_zipfile`, `BadZipFile`, `LargeZipFile`; `ZIP_STORED`, `ZIP_DEFLATED`, `ZIP_BZIP2`, `ZIP_LZMA`, `ZIP_ZSTANDARD` |
| `tarfile` | `open(name=None, mode="r", fileobj=None, ...)`, `TarFile` (`getmembers`, `getnames`, `getmember`, `next`, iteration, `extractfile`, `extract`, `extractall`, `add`, `addfile`, `gettarinfo`, `list`), `TarInfo`, `is_tarfile`, the extraction filters (`data_filter`, `tar_filter`, `fully_trusted_filter`), the `TarError` classes, and the format constants |

`compression` is a package with no module of its own: import `compression.zstd`.

As in CPython:

- `zlib.decompress` reads the container `wbits` names: 15 a zlib stream, -15 raw deflate, and
  47 (32 + 15) either a zlib or a gzip stream, found from its header.
- `gzip.compress` writes `mtime` 0 by default, so its output is the same at each run, and
  `gzip.decompress` joins the members of a file made of several. A `GzipFile` writes the time
  now unless `mtime=` says otherwise.
- `zlib.crc32` and `zlib.adler32` continue from a running value; of `b""` they are 0 and 1.
  `zlib.crc32` is `binascii.crc32` (see [base64 and binascii](base64.md)).
- Data that does not decompress raises the module's own error: `zlib.error`,
  `gzip.BadGzipFile`, `lzma.LZMAError`, `compression.zstd.ZstdError`, and `OSError` from `bz2`.
- The functions take `bytes`, a `bytearray` or a `memoryview`.
- `open` reads and writes binary by default, and text with a `"t"` in the mode (`"rt"`, `"wt"`),
  through an `io.TextIOWrapper`.

## Archives

A `ZipFile` and a `TarFile` read and write a file they open from a name, or any binary file
object, such as an `io.BytesIO`:

```jac
import io;
import tarfile;
import zipfile;

with entry {
    buf = io.BytesIO();
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf {
        zf.writestr("notes/readme.txt", "hello\n" * 50);
        zf.writestr("data.bin", bytes(range(10)));
    }
    with zipfile.ZipFile(buf) as zf {
        for info in zf.infolist() {
            small = info.compress_size < info.file_size;
            print(info.filename, info.file_size, small, info.compress_type);
        }
        print(zf.read("data.bin"), zf.testzip());
        with zf.open("notes/readme.txt") as f {
            print(f.readline());
        }
        try {
            zf.read("missing.txt");
        } except KeyError as e {
            print("KeyError:", e);
        }
        print(sorted([p.name for p in zipfile.Path(zf).iterdir()]));
    }
    try {
        zipfile.ZipFile(io.BytesIO(b"plain text"));
    } except zipfile.BadZipFile as e {
        print("BadZipFile:", e);
    }
    packed = io.BytesIO();
    with tarfile.open(fileobj=packed, mode="w:gz") as tf {
        data = b"hello\n";
        header = tarfile.TarInfo("notes/readme.txt");
        header.size = len(data);
        tf.addfile(header, io.BytesIO(data));
    }
    packed.seek(0);
    with tarfile.open(fileobj=packed, mode="r:*") as tf {
        print(tf.getnames());
        member = tf.getmember("notes/readme.txt");
        print(member.size, member.isfile(), oct(member.mode), tf.extractfile(member).read());
    }
    print(tarfile.is_tarfile(io.BytesIO(b"plain text")), zipfile.is_zipfile(buf));
}
```

```output
notes/readme.txt 300 True 8
data.bin 10 False 8
b'\x00\x01\x02\x03\x04\x05\x06\x07\x08\t' None
b'hello\n'
KeyError: "There is no item named 'missing.txt' in the archive"
['data.bin', 'notes']
BadZipFile: File is not a zip file
['notes/readme.txt']
6 True 0o644 b'hello\n'
False True
```

- A zip member is stored, or compressed by zlib, bzip2, LZMA or Zstandard, and read whichever
  it is; a member encrypted with the traditional cipher is read with `setpassword` or `pwd=`.
  An archive past 4 GiB or 65,535 members is written as ZIP64.
- A tar archive is ustar, GNU or pax, plain or compressed: `"r:*"` finds the compression,
  `"w:gz"`, `"w:bz2"`, `"w:xz"` and `"w:zst"` write it, and `"r|*"` and `"w|gz"` read and write
  a stream that is never sought, such as a pipe.
- `tarfile`'s `extract` and `extractall` go through a filter, `data_filter` unless another is
  given, which refuses a member that would land outside the destination
  (`OutsideDestinationError`), an absolute path, a link out of the tree and a device file.

## Differences from CPython

- **`zipfile.PyZipFile` is left out** (E5142): it compiles Python source to bytecode, and a
  native program has no Python compiler. Archive the `.py` files themselves with
  `ZipFile.write`.
- **`zlib.ZLIBNG_VERSION` is left out** (E5142): CPython has it only when built against
  zlib-ng. `ZLIB_VERSION` and `ZLIB_RUNTIME_VERSION` are both the version of the zlib the
  program runs with, as it is built against no header.
- **`tarfile.TarFile.tarinfo` and `fileobject`, and `tarfile.PAX_NUMBER_FIELDS`, are not there
  yet**: their values are classes. A `TarFile` makes `TarInfo`s and `ExFileObject`s.
- **A `ZipFile` shared between threads needs a `Lock` of the program's own**: CPython guards
  reading one member while another is written with a lock of its own.

```jac
# expect: E5142
import zipfile;

with entry {
    print(zipfile.PyZipFile);
}
```

## Where they are

Each module calls a library of the operating system, which the program loads as it starts:

| Module | Library | macOS | Linux | Windows | WASI |
|---|---|---|---|---|---|
| `zlib`, `gzip` | zlib | the system's | `libz.so.1` | linked into the program | not available |
| `bz2` | bzip2 | the system's | `libbz2.so.1.0` | linked into the program | not available |
| `lzma` | XZ Utils' liblzma | the system's | `liblzma.so.5` | linked into the program | not available |
| `compression.zstd` | Zstandard | linked into the program | `libzstd.so.1` | linked into the program | not available |
| `zipfile`, `tarfile` | all four | as above | as above | as above | not available |

Where the system ships no such library, the program links the copy jac's toolchain ships,
and carries it. A wasm32-wasi program links only the WASI C library, so there the import stops
the build with W5021 (`the C library 'zstd' is not available on WASI`). `zipfile` and `tarfile`
need all four libraries because they read members and archives compressed by each.

## Where to go next

- A whole tree archived or unpacked in one call, `shutil.make_archive` and `unpack_archive`:
  [Files and directories](files.md).
- Checksums and text encodings of bytes: [base64 and binascii](base64.md), [hashlib](hashlib.md).
- Every native module: [Standard-library modules](stdlib.md).
