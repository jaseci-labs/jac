"""llhttp 9.4.1 C FFI bindings for js_engine.

Provides the complete lifecycle API for llhttp — a fast, pure-C HTTP/1.x
parser used by Node.js.  Other modules should import from this file rather
than importing the .so directly.

  import from engine.src.ffi.libllhttp {
      llhttp_alloc_parser, llhttp_execute, llhttp_settings_init, ...
  }

Struct sizes (verified with gcc against llhttp 9.4.1 headers):
    llhttp_t          : 96 bytes
    llhttp_settings_t : 200 bytes

llhttp_t (llhttp__internal_s) field offsets:
    _index           :  0  (int32)
    _span_pos0       :  8  (ptr)
    _span_cb0        : 16  (ptr)
    error            : 24  (int32)
    reason           : 32  (ptr  — char*)
    error_pos        : 40  (ptr  — char*)
    data             : 48  (ptr  — user data)
    _current         : 56  (ptr)
    content_length   : 64  (uint64)
    type             : 72  (uint8)
    method           : 73  (uint8)
    http_major       : 74  (uint8)
    http_minor       : 75  (uint8)
    header_state     : 76  (uint8)
    lenient_flags    : 78  (uint16)
    upgrade          : 80  (uint8)
    finish           : 81  (uint8)
    flags            : 82  (uint16)
    status_code      : 84  (uint16)
    initial_message_completed : 86 (uint8)
    settings         : 88  (ptr  — llhttp_settings_t*)

llhttp_settings_t (llhttp_settings_s) callback offsets (fn pointers, 8 bytes each):
    on_message_begin        :   0
    on_protocol             :   8
    on_url                  :  16
    on_status               :  24
    on_method               :  32
    on_version              :  40
    on_header_field         :  48
    on_header_value         :  56
    on_chunk_extension_name :  64
    on_chunk_extension_value:  72
    on_headers_complete     :  80
    on_body                 :  88
    on_message_complete     :  96
    on_protocol_complete    : 104
    on_url_complete         : 112
    on_status_complete      : 120
    on_method_complete      : 128
    on_version_complete     : 136
    on_header_field_complete: 144
    on_header_value_complete: 152
    on_chunk_ext_name_complete: 160
    on_chunk_ext_value_complete: 168
    on_chunk_header         : 176
    on_chunk_complete       : 184
    on_reset                : 192

llhttp is compiled into libjs_native.so (native/build_native.zig).
"""

# ── C library import ──────────────────────────────────────────────────────────

import from "libjs_native.so" {
    # ── Lifecycle ────────────────────────────────────────────────────────────

    # Initialize a pre-allocated llhttp_t in place.
    def:pub llhttp_init(parser: int, ptype: int, settings: int) -> None;
    # Reset the parser state (keep type and settings).
    def:pub llhttp_reset(parser: int) -> None;
    # ── Settings ─────────────────────────────────────────────────────────────

    # Zero-initialise a pre-allocated llhttp_settings_t (200 bytes).
    def:pub llhttp_settings_init(settings: int) -> None;
    # ── Execution ────────────────────────────────────────────────────────────

    # Feed data to the parser. Returns llhttp_errno_t (int).
    #   HPE_OK (0)               → success
    #   HPE_PAUSED (21)          → paused by callback
    #   HPE_PAUSED_UPGRADE (22)  → upgrade header seen
    #   any other value          → parse error
    def:pub llhttp_execute(parser: int, data: str, length: int) -> int;
    # Signal EOF (must call after last chunk if connection closes mid-message).
    def:pub llhttp_finish(parser: int) -> int;
    # ── Callbacks pause / resume ──────────────────────────────────────────────

    # Pause the parser from inside a callback.
    def:pub llhttp_pause(parser: int) -> None;
    # Resume after llhttp_pause().
    def:pub llhttp_resume(parser: int) -> None;
    # Resume after an upgrade (HPE_PAUSED_UPGRADE).
    def:pub llhttp_resume_after_upgrade(parser: int) -> None;
    # ── Field accessors ───────────────────────────────────────────────────────

    # Return the last errno (call after llhttp_execute returns non-zero).
    def:pub llhttp_get_errno(parser: int) -> int;
    # Return the human-readable reason for the last error (char* → int ptr).
    def:pub llhttp_get_error_reason(parser: int) -> int;
    # Return the position in the buffer where the error occurred (char* → int).
    def:pub llhttp_get_error_pos(parser: int) -> int;
    # Return the numeric HTTP status code (e.g. 200, 404).
    def:pub llhttp_get_status_code(parser: int) -> int;
    # Return the HTTP major/minor version byte (1 or 2 for HTTP/1.x).
    def:pub llhttp_get_http_major(parser: int) -> int;  def:pub llhttp_get_http_minor(
        parser: int
    ) -> int;
    # Return 1 if an Upgrade header was present, 0 otherwise.
    def:pub llhttp_get_upgrade(parser: int) -> int;
    # Return the parser type (0=BOTH, 1=REQUEST, 2=RESPONSE).
    def:pub llhttp_get_type(parser: int) -> int;
    # Return the method byte (use llhttp_method_name to convert to string).
    def:pub llhttp_get_method(parser: int) -> int;
    # Return 1 if the connection should be kept alive, 0 otherwise.
    def:pub llhttp_should_keep_alive(parser: int) -> int;
    # Return 1 if the message needs an EOF to finish (e.g. chunked).
    def:pub llhttp_message_needs_eof(parser: int) -> int;
    # ── Name helpers ──────────────────────────────────────────────────────────

    # Return the C string name of an llhttp_errno value (int ptr → str read via ctypes).
    def:pub llhttp_errno_name(err: int) -> int;
    # Return the C string name of an llhttp_method value (int ptr).
    def:pub llhttp_method_name(method: int) -> int;
    # Return the C string name of an llhttp_status value (int ptr).
    def:pub llhttp_status_name(status: int) -> int;
    # ── Lenient-mode flags ────────────────────────────────────────────────────

    def:pub llhttp_set_lenient_headers(parser: int, enabled: int) -> None;  def:
        pub llhttp_set_lenient_chunked_length(parser: int, enabled: int) -> None;  def:
        pub llhttp_set_lenient_keep_alive(parser: int, enabled: int) -> None;  def:
        pub llhttp_set_lenient_transfer_encoding(parser: int, enabled: int) -> None;  def:
        pub llhttp_set_lenient_version(parser: int, enabled: int) -> None;  def:
        pub llhttp_set_lenient_data_after_close(parser: int, enabled: int) -> None;  def:
        pub llhttp_set_lenient_optional_lf_after_cr(
        parser: int, enabled: int
    ) -> None;  def:pub llhttp_set_lenient_optional_cr_before_lf(
        parser: int, enabled: int
    ) -> None;  def:pub llhttp_set_lenient_optional_crlf_after_chunk(
        parser: int, enabled: int
    ) -> None;  def:pub llhttp_set_lenient_spaces_after_chunk_size(
        parser: int, enabled: int
    ) -> None;
}

# ── Parser type constants ─────────────────────────────────────────────────────

glob:pub LLHTTP_HTTP_BOTH: int = 0,
     LLHTTP_HTTP_REQUEST: int = 1,
     LLHTTP_HTTP_RESPONSE: int = 2,
     HPE_OK: int = 0,
     HPE_INTERNAL: int = 1,
     HPE_STRICT: int = 2,
     HPE_PAUSED: int = 21,
     HPE_PAUSED_UPGRADE: int = 22,
     HPE_PAUSED_H2_UPGRADE: int = 23,
     HPE_USER: int = 24,
     HPE_CR_EXPECTED: int = 25,
     LLHTTP_T_SIZE: int = 96,
     LLHTTP_SETTINGS_SIZE: int = 200,
     LLHTTP_OFF_ERROR: int = 24,
     LLHTTP_OFF_REASON: int = 32,
     LLHTTP_OFF_ERROR_POS: int = 40,
     LLHTTP_OFF_DATA: int = 48,
     LLHTTP_OFF_CONTENT_LEN: int = 64,
     LLHTTP_OFF_TYPE: int = 72,
     LLHTTP_OFF_METHOD: int = 73,
     LLHTTP_OFF_HTTP_MAJOR: int = 74,
     LLHTTP_OFF_HTTP_MINOR: int = 75,
     LLHTTP_OFF_LENIENT: int = 78,
     LLHTTP_OFF_UPGRADE: int = 80,
     LLHTTP_OFF_STATUS_CODE: int = 84,
     LLHTTP_OFF_SETTINGS: int = 88,
     LLHTTP_CB_ON_MESSAGE_BEGIN: int = 0,
     LLHTTP_CB_ON_PROTOCOL: int = 8,
     LLHTTP_CB_ON_URL: int = 16,
     LLHTTP_CB_ON_STATUS: int = 24,
     LLHTTP_CB_ON_METHOD: int = 32,
     LLHTTP_CB_ON_VERSION: int = 40,
     LLHTTP_CB_ON_HEADER_FIELD: int = 48,
     LLHTTP_CB_ON_HEADER_VALUE: int = 56,
     LLHTTP_CB_ON_CHUNK_EXT_NAME: int = 64,
     LLHTTP_CB_ON_CHUNK_EXT_VALUE: int = 72,
     LLHTTP_CB_ON_HEADERS_COMPLETE: int = 80,
     LLHTTP_CB_ON_BODY: int = 88,
     LLHTTP_CB_ON_MESSAGE_COMPLETE: int = 96,
     LLHTTP_CB_ON_PROTOCOL_COMPLETE: int = 104,
     LLHTTP_CB_ON_URL_COMPLETE: int = 112,
     LLHTTP_CB_ON_STATUS_COMPLETE: int = 120,
     LLHTTP_CB_ON_METHOD_COMPLETE: int = 128,
     LLHTTP_CB_ON_VERSION_COMPLETE: int = 136,
     LLHTTP_CB_ON_HEADER_FIELD_COMPLETE: int = 144,
     LLHTTP_CB_ON_HEADER_VALUE_COMPLETE: int = 152,
     LLHTTP_CB_ON_CHUNK_EXT_NAME_COMPLETE: int = 160,
     LLHTTP_CB_ON_CHUNK_EXT_VALUE_COMPLETE: int = 168,
     LLHTTP_CB_ON_CHUNK_HEADER: int = 176,
     LLHTTP_CB_ON_CHUNK_COMPLETE: int = 184,
     LLHTTP_CB_ON_RESET: int = 192;  # Accept both requests and responses

# Request parser
# Response parser

# ── Error code constants ──────────────────────────────────────────────────────

# No error
# Internal error
# Strict-mode parse error
# Paused by callback (normal flow)
# Upgrade header seen — caller must handle
# HTTP/2 upgrade
# User callback returned an error
# CR expected

# ── Struct size constants ─────────────────────────────────────────────────────

# sizeof(llhttp_t)
# sizeof(llhttp_settings_t)

# ── llhttp_t field byte-offsets ───────────────────────────────────────────────

# int32   — last errno
# ptr     — error reason string
# ptr     — error position in buffer
# ptr     — user data (void*)
# uint64  — content-length
# uint8   — parser type
# uint8   — HTTP method
# uint8   — major version
# uint8   — minor version
# uint16  — lenient flags
# uint8   — upgrade flag
# uint16  — status code
# ptr     — llhttp_settings_t*

# ── llhttp_settings_t callback byte-offsets ───────────────────────────────────

# llhttp_cb
# llhttp_data_cb
# llhttp_data_cb
# llhttp_data_cb
# llhttp_data_cb
# llhttp_data_cb
# llhttp_data_cb
# llhttp_data_cb
# llhttp_data_cb
# llhttp_data_cb
# llhttp_cb
# llhttp_data_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# llhttp_cb
# ── Low-level memory helpers (via libc) ───────────────────────────────────────

import from "libc.so.6" {
    def:pub calloc(n: int, size: int) -> int;  def:pub malloc(size: int) -> int;  def:
        pub free(ptr: int) -> None;  def:pub memset(
        ptr: int, value: i32, size: int
    ) -> int;  def:pub memcpy(dst: int, src: int, size: int) -> int;
}

import from engine.src.runtime.mem {
    read_ptr,
    read_byte,
    read_u32,
    read_u64,
    write_i64
}

# ── High-level helpers ────────────────────────────────────────────────────────

# Allocate a zeroed llhttp_t (96 bytes) and return the raw pointer.
# Caller must then call llhttp_alloc_settings() + llhttp_init() before use.
# Type: LLHTTP_HTTP_REQUEST=1 / LLHTTP_HTTP_RESPONSE=2 / LLHTTP_HTTP_BOTH=0.
def:pub llhttp_alloc_parser(ptype: int) -> int {
    return calloc(1, LLHTTP_T_SIZE);
}

# Allocate and zero-initialise a standalone llhttp_settings_t (200 bytes).
# Pass to llhttp_init() or write callbacks at documented offsets first.
def:pub llhttp_alloc_settings -> int {
    return calloc(1, LLHTTP_SETTINGS_SIZE);
}

# Write a callback fn pointer into a settings struct at the given slot offset.
# fn_ptr must be an untyped int local (Jac def ptr workaround).
# Example: cb: int = my_on_url; llhttp_set_callback(settings, LLHTTP_CB_ON_URL, cb);
def:pub llhttp_set_callback(settings: int, offset: int, fn_ptr: int) {
    write_i64(settings, offset, fn_ptr);
}

# Read the user data pointer stored in the parser (offset 48).
# Call from inside a callback to recover the context handle.
def:pub llhttp_get_user_data(parser: int) -> int {
    return read_ptr(parser, LLHTTP_OFF_DATA);
}

# Write the user data pointer into the parser (offset 48).
# Call after llhttp_init() to bind a context handle to the parser.
def:pub llhttp_set_user_data(parser: int, data: int) {
    write_i64(parser, LLHTTP_OFF_DATA, data);
}

# Spec-named aliases for user-data access (preferred in Phase B and later).
def:pub llhttp_read_data(parser: int) -> int {
    return read_u64(parser, LLHTTP_OFF_DATA);
}

def:pub llhttp_write_data(parser: int, data: int) {
    write_i64(parser, LLHTTP_OFF_DATA, data);
}

# Read the HTTP status code uint16 directly from the parser struct.
# Equivalent to llhttp_get_status_code() but avoids a C call for the hot path.
def:pub llhttp_read_status_code(parser: int) -> int {
    lo: int = read_byte(parser, LLHTTP_OFF_STATUS_CODE);
    hi: int = read_byte(parser, LLHTTP_OFF_STATUS_CODE + 1);
    return lo + hi * 256;
}

# NOTE: Smoke tests moved to engine/src/ffi/libllhttp_test.na.jac
# Library (FFI) modules must NOT contain `with entry {}` blocks — the compiler
# always emits `jac_entry` from them even when compiling as an imported module,
# which overwrites the main module's entry point and crashes with SIGSEGV.
# See: js_engine/issues/with-entry-in-imported-module-collides-jac-entry/
