---
description: The native codecs and unicodedata modules, as CPython's - every text encoding but the CJK multibyte ones, the error handlers, incremental and stream codecs, and the Unicode 17 character database.
keywords: codecs, codecs.encode, codecs.decode, codecs.lookup, codecs.register, codecs.unregister, codecs.register_error, codecs.lookup_error, codecs.CodecInfo, codecs.getencoder, codecs.getdecoder, codecs.getincrementalencoder, codecs.getincrementaldecoder, codecs.getreader, codecs.getwriter, codecs.open, codecs.EncodedFile, codecs.iterencode, codecs.iterdecode, codecs.BOM_UTF8, codecs.StreamReader, codecs.StreamWriter, encodings, text encoding, error handler, unicodedata, unicodedata.name, unicodedata.lookup, unicodedata.category, unicodedata.normalize, unicodedata.is_normalized, unicodedata.numeric, unicodedata.decimal, unicodedata.digit, unicodedata.east_asian_width, unicodedata.decomposition, unicodedata.bidirectional, unicodedata.combining, unicodedata.mirrored, unicodedata.unidata_version, unicodedata.ucd_3_2_0, Unicode database
---
# codecs and unicodedata

`codecs` is CPython's codec registry: every text encoding CPython ships but the CJK multibyte
ones, the bytes-to-bytes codecs (`hex`, `base64`, `zlib`, `bz2`, `quopri`, `uu`) and `rot13`,
every error handler, and the incremental and stream classes built on them. `str.encode`,
`bytes.decode`, `open(..., encoding=...)` and `io.TextIOWrapper` reach the same codecs.
`unicodedata` is CPython's character database, built from CPython's own tables for Unicode
17.0.0. Both are native (see [The library](index.md), `jac docs library`).

```jac
import codecs;
import unicodedata;

with entry {
    print(codecs.encode("café", "utf-16-le"), codecs.decode(b"caf\xe9", "cp1252"));
    print(codecs.lookup("latin1").name, codecs.lookup("UTF8").name, codecs.BOM_UTF8);
    dec = codecs.getincrementaldecoder("utf-8")();
    print(repr(dec.decode(b"caf\xc3")), repr(dec.decode(b"\xa9", final=True)));
    print(
        codecs.encode("abc", "rot13"),
        codecs.decode(b"68656c6c6f", "hex"),
        codecs.encode(b"hi", "base64"),
    );
    print("bücher.de".encode("idna"), codecs.decode(b"Hello\\nWorld", "unicode_escape"));
    try {
        codecs.lookup("euc_jp");
    } except LookupError as e {
        print("LookupError:", e);
    }
    print(unicodedata.name("é"), unicodedata.lookup("SNOWMAN"), unicodedata.category("A"));
    print(
        unicodedata.normalize("NFD", "é") == "é",
        unicodedata.numeric("½"),
        unicodedata.unidata_version,
    );
    print(
        unicodedata.east_asian_width("世"),
        unicodedata.decomposition("é"),
        unicodedata.bidirectional("A"),
    );
}
```

```output
b'c\x00a\x00f\x00\xe9\x00' café
iso8859-1 utf-8 b'\xef\xbb\xbf'
'caf' 'é'
nop b'hello' b'aGk=\n'
b'xn--bcher-kva.de' Hello
World
LookupError: unknown encoding: euc_jp
LATIN SMALL LETTER E WITH ACUTE ☃ Lu
True 0.5 17.0.0
W 0065 0301 L
```

## The encodings

A name is looked up as CPython looks it up: case and `-`, `_` and spaces do not matter, and each
encoding's aliases are CPython's (`latin1`, `L1`, `iso-8859-1` and `8859` are one encoding).

| Family | Encodings |
|---|---|
| Unicode | `utf-8`, `utf-8-sig`, `utf-16`, `utf-16-le`, `utf-16-be`, `utf-32` (and its `-le`, `-be`), `utf-7`, `unicode_escape`, `raw_unicode_escape` |
| ASCII and Latin | `ascii`, `latin-1`, `iso8859-2` to `iso8859-16` |
| Code pages | `cp037` to `cp1258`, among them `cp437`, `cp850`, `cp1252` |
| Others | The Mac sets (`mac-roman`, `mac-cyrillic`, ...), `koi8-r`, `koi8-u`, `koi8-t`, `kz1048`, `ptcp154`, `hp-roman8`, `tis-620`, `palmos`, `charmap`, `idna`, `punycode` |
| Bytes to bytes | `hex`, `base64`, `quopri`, `uu`, `zlib`, `bz2` (with `codecs.encode`/`decode` only) |
| Text to text | `rot13` |

The CJK multibyte encodings (`shift_jis`, `euc_jp`, `gb2312`, `gbk`, `gb18030`, `big5`,
`euc_kr`, `iso2022_jp`, `cp932` and the rest) are not there: their names raise
`LookupError: unknown encoding`, as a name no codec has does.

The error handlers are CPython's: `strict`, `ignore`, `replace`, `backslashreplace`,
`xmlcharrefreplace`, `namereplace`, `surrogateescape` and `surrogatepass`.
`codecs.register_error(name, handler)` adds one, which every encoding then takes. A handler
receives the error (its type is the union of the three `UnicodeError`s) and returns the
replacement and the position to go on from. `codecs.register(search)` adds a search function
that finds codecs of a program's own.

```jac
import codecs;

def stars(err: UnicodeEncodeError | UnicodeDecodeError | UnicodeTranslateError) -> tuple[str
    | bytes, int] {
    return ("*" * (err.end - err.start), err.end);
}

with entry {
    codecs.register_error("stars", stars);
    print("café €".encode("ascii", "stars"), "é€".encode("ascii", "namereplace"));
}
```

```output
b'caf* *' b'\\N{LATIN SMALL LETTER E WITH ACUTE}\\N{EURO SIGN}'
```

## What is there

| Name | What it is |
|---|---|
| `encode(obj, encoding="utf-8", errors="strict")`, `decode(...)` | One whole conversion |
| `lookup(encoding)` | The `CodecInfo`: `name`, `encode`, `decode`, `incrementalencoder`, `incrementaldecoder`, `streamreader`, `streamwriter` |
| `getencoder`, `getdecoder`, `getincrementalencoder`, `getincrementaldecoder`, `getreader`, `getwriter` | Parts of a `CodecInfo` by name |
| `register`, `unregister`, `register_error`, `lookup_error` | The registries |
| `Codec`, `IncrementalEncoder`, `IncrementalDecoder`, `BufferedIncrementalEncoder`, `BufferedIncrementalDecoder`, `StreamReader`, `StreamWriter`, `StreamReaderWriter`, `StreamRecoder` | The base classes a codec of a program's own derives from |
| `open(filename, mode="r", encoding=None, errors="strict", buffering=-1)`, `EncodedFile(file, data_encoding, file_encoding=None, errors="strict")` | A file read and written through a codec |
| `iterencode`, `iterdecode` | A codec over an iterable of chunks |
| `BOM_UTF8`, `BOM_UTF16`, `BOM_UTF16_LE`, `BOM_UTF16_BE`, `BOM_UTF32`, ... | The byte-order marks |
| `utf_8_encode`, `utf_8_decode`, `latin_1_encode`, `charmap_build`, ... | The functions of CPython's `_codecs` that `codecs` exports |
| `strict_errors`, `ignore_errors`, `replace_errors`, `backslashreplace_errors`, `xmlcharrefreplace_errors`, `namereplace_errors` | The handlers as functions |

`StreamReader.charbuffertype` is not written yet (E1030).

## unicodedata

`unicodedata` answers for Unicode 17.0.0, as CPython 3.15 does: `name`, `lookup` (with
CPython's aliases and named sequences), `category`, `bidirectional`, `combining`,
`east_asian_width`, `mirrored`, `decomposition`, `decimal`, `digit`, `numeric`, `normalize` and
`is_normalized` for the four forms, and Python 3.15's `block`, `isxidstart`, `isxidcontinue`,
`iter_graphemes`, `grapheme_cluster_break`, `indic_conjunct_break` and `extended_pictographic`.
`ucd_3_2_0` is the database of Unicode 3.2.0 that IDNA uses, a `UCD` with the same methods. A
character with no name raises `ValueError: no such name`, and a name no character has
`KeyError: "undefined character name 'NOPE'"`, as in CPython.

## Speed

`unicodedata.normalize`, `name` and `lookup` run 3 to 10 times slower than CPython's C.
