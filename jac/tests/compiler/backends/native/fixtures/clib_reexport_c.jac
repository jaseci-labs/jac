"""The C binding a re-export chain starts from."""

import from "libc.so.6" { def labs(v: int) -> int;  }
