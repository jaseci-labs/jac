"""Fixture: a native module whose imports bind `with ... as` aliases.

Expected: 0 errors. A native module analyses its imports in full, and each
import's interface is built first, which types the import's function bodies
before the checker has walked their `with` statements. The aliases must still
bind through `__enter__`, both in a local module and in the bundled native
`zipfile`, whose reader opens the archive with `with open(file, "rb")`.
"""

import from c { def abs(x: i32) -> i32;  }
import from checker_with_alias_native_dep_reader { Blob }
import from zipfile { ZipFile }

def blob_size(path: str) -> int {
    return len(Blob(path).data);
}

def archive_names(path: str) -> list[str] {
    return ZipFile(path).namelist();
}
