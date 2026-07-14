"""Regular .jac (no `na {}` block, not a `.na.jac`) that imports a bundled
na_stdlib module. Driven through `jac nacompile`, the file is auto-promoted to
the native backend; the import must pull the bundled `zlib` module's IR (and its
transitive `_zlib_native`) into the binary -- including each module's
`__jac_glob_init_<safe>` initializer, which the entry point calls. If the
cross-module merge is skipped (issue #7013 Finding 2), those initializers stay
undefined and the loader aborts with a symbol lookup error. CRC-32/ISO of
'123456789' is 0xCBF43926 == 3421780262."""
import from zlib { crc32 }

with entry {
    print("crc32:", crc32(b"123456789"));
}
