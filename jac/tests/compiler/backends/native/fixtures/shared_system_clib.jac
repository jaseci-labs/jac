"""A shared library calling a system C library by its bare name (`crypto`), after
an explicit libc import that must still be listed last among the needed libraries."""

import from "libc.so.6" { def getpid -> i32;  }

import from crypto { def OpenSSL_version_num -> int;  }

def:pub openssl_version -> int {
    return OpenSSL_version_num();
}

def:pub process_id -> int {
    return getpid();
}
