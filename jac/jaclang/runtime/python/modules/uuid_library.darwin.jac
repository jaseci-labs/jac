"""<uuid/uuid.h> as macOS provides it: uuid_generate_time() in libSystem.

macOS has no uuid_generate_time_safe(), so the generator reports no status.
"""

import from c { def uuid_generate_time(out: ptr[u8]);  }

glob HAVE_UUID_HEADER: bool = True,
     HAVE_GENERATE_TIME_SAFE: bool = False,
     HAVE_GENERATE_TIME_SAFE_STABLE_MAC: bool = False;

# Fill the 16 bytes at out; the status of uuid_generate_time_safe() where the
# library has it, otherwise 0.
def generate_time(out: ptr[u8]) -> i32 {
    uuid_generate_time(out);
    return i32(0);
}
