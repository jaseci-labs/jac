"""Single source of truth for the JIR on-disk container format.

Pure-Python leaf module (no jac, no heavy imports) so it is importable in the
bootstrap tier: both jir.jac (the writer) and sealed.py (the pure-Python section
reader that must load before any .jac module) import these from here instead of
each hand-maintaining a copy kept in sync by an assert. Section IDs are part of
the format regardless of who reads them, so they all live here.
"""

MAGIC = b"JIR\x00"
FORMAT_VERSION = 13
HEADER_SIZE = 32
HEADER_FMT = "<4sHHIIIIII"
EXTERNAL_REF = 0xFFFFFF
SECTIONS_MAGIC = b"JIRX"
SEC_BYTECODE = 0x02
SEC_MTIR = 0x03
SEC_LLVM_IR = 0x04
SEC_INTEROP = 0x05
SEC_NATIVE_OBJ = 0x06
SEC_SYMINDEX = 0x07
SEC_MODKEY = 0x08
SEC_DEBUG_SRC = 0x09
SEC_TERMINATOR = 0xFF
FLAG_PRECOMPILED = 0x02
FLAG_BOOTSTRAP = 0x04
PRECOMPILE_SENTINEL = "__PKG_ROOT__"
