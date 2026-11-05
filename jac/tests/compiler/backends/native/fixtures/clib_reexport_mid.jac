"""Re-exports the C binding, as js_engine's ffi/libm re-exports ffi/libc's time."""

import from clib_reexport_c { labs }
