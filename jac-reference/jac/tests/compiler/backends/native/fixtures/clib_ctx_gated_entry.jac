"""Native entry that uses only the transitive module's plain function."""

import from clib_ctx_gated_lib { plain_add }

def:pub use_plain_add(n: int) -> int {
    return plain_add(n);
}
