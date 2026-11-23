"""Fixture for a shared library that calls into a system C library by its
bare name: `import from crypto` names libcrypto, which a checkout links
dynamically unless the static C floor is built."""

import from crypto { def OpenSSL_version_num -> int;  }

def:pub openssl_version -> int {
    return OpenSSL_version_num();
}
