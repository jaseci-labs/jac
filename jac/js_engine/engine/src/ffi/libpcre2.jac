"""PCRE2 (Perl-Compatible Regular Expressions v2) C FFI bindings.

8-bit / PCRE2_CODE_UNIT_WIDTH=8 flavour (`_8`-suffix functions).

All other modules should import from this file rather than touching the .so
directly:

    import from engine.src.ffi.libpcre2 { pcre2_compile_8, pcre2_match_8, ... }

PCRE2 compile-time option flags (32-bit bitmask passed to pcre2_compile_8):

  PCRE2_CASELESS  = 0x00000008   JS /i flag
  PCRE2_MULTILINE = 0x00000400   JS /m flag
  PCRE2_DOTALL    = 0x00000020   JS /s flag
  PCRE2_UTF       = 0x00080000   treat pattern/subject as UTF-8

PCRE2_SIZE is size_t (uint64_t on x86-64).
Pass PCRE2_ZERO_TERMINATED (-1 cast to size_t) to let PCRE2 find the NUL.

Variable-length lookbehind needs PCRE2 10.45+ (pcre2_set_max_varlookbehind_8);
libjs_native.so carries the build.zig.zon-pinned PCRE2.

Bun reference:
  JavaScriptCore/yarr/ — Bun uses JSC Yarr, but the public API is equivalent.
"""

import from "libjs_native.so" {
    # ── Compile ───────────────────────────────────────────────────────────────
    # Compile a regex pattern into an opaque pcre2_code* handle.
    #
    # pattern     : regex source string (char*)
    # length      : byte count of pattern, or PCRE2_ZERO_TERMINATED (-1)
    # options     : bitwise-OR of PCRE2_CASELESS / PCRE2_MULTILINE / etc.
    # errorcode   : pointer to int  — receives error code on failure
    # erroroffset : pointer to size_t — receives byte offset of error
    # ccontext    : compile context ptr, or 0 for defaults
    #
    # Returns pcre2_code* (non-zero) on success, 0 (NULL) on error.
    def:pub pcre2_compile_8(
        pattern: str,
        length: int,
        options: int,
        errorcode: int,
        erroroffset: int,
        ccontext: int
    ) -> int;
    # ── Compile context ───────────────────────────────────────────────────────
    # Create a compile context (used to pass options like max_varlookbehind).
    # gcontext : 0 = NULL = use defaults
    # Returns pcre2_compile_context* or 0 on failure.
    def:pub pcre2_compile_context_create_8(gcontext: int) -> int;
    # Set the maximum variable-length lookbehind size (PCRE2 10.45+).
    # value=0 disables variable-length lookbehinds (default before 10.45).
    # value=255 allows lookbehinds with bounded quantifiers up to 255 chars.
    # After calling this, bounded quantifiers like \s{0,255} compile in lookbehinds.
    # Unbounded quantifiers (\s*, \s+) still need pre-transformation — see regexp.na.jac.
    # Returns 0 on success, PCRE2_ERROR_BADDATA on invalid value.
    def:pub pcre2_set_max_varlookbehind_8(ccontext: int, value: int) -> int;
    # Set PCRE2_EXTRA_* compile options on a compile context (bitmask).
    # regexp.jac uses PCRE2_EXTRA_ALLOW_SURROGATE_ESCAPES (0x1) so a JS /u pattern
    # can name surrogate code points (`/[\uD800-\uDFFF]/u`).
    def:pub pcre2_set_compile_extra_options_8(
        ccontext: int, extra_options: int
    ) -> int;
    # Free a compile context created above.
    def:pub pcre2_compile_context_free_8(ccontext: int) -> None;
    # ── Match-data block ──────────────────────────────────────────────────────
    # Allocate a match_data block large enough for the given compiled pattern.
    # gcontext : 0 = NULL
    def:pub pcre2_match_data_create_from_pattern_8(code: int, gcontext: int) -> int;
    # Free a match_data block created above.
    def:pub pcre2_match_data_free_8(match_data: int) -> None;
    # ── Match context (step limit / timeout guard) ───────────────────────────
    def:pub pcre2_match_context_create_8(gcontext: int) -> int;  def:
        pub pcre2_match_context_free_8(mcontext: int) -> None;
    # Limit backtracking steps; returns 0 on success.
    def:pub pcre2_set_match_limit_8(mcontext: int, limit: int) -> int;
    # ── Match ─────────────────────────────────────────────────────────────────
    # Run a match.
    #
    # code        : compiled pcre2_code*
    # subject     : input string (char*)
    # length      : byte count of subject (use len(s) for ASCII)
    # startoffset : byte offset at which to start matching
    # options     : match-time options (0 for default)
    # match_data  : output block
    # mcontext    : 0 = NULL = use defaults
    #
    # Returns:
    #   >= 1      : number of capture groups + 1 (match succeeded)
    #   0         : ovector too small (shouldn't happen with create_from_pattern)
    #   -1        : PCRE2_ERROR_NOMATCH
    #   < -1      : other error
    def:pub pcre2_match_8(
        code: int,
        subject: str,
        length: int,
        startoffset: int,
        options: int,
        match_data: int,
        mcontext: int
    ) -> int;
    # ── Ovector accessors ─────────────────────────────────────────────────────
    # Returns pointer to the output vector: an array of size_t pairs
    # [start0, end0, start1, end1, ...] (full match + captures).
    # PCRE2_UNSET (~size_t(0) = -1 as i64) means "group did not participate".
    def:pub pcre2_get_ovector_pointer_8(match_data: int) -> int;
    # Number of (start,end) pairs in the ovector — ≥ 1 (full match always present).
    def:pub pcre2_get_ovector_count_8(match_data: int) -> int;
    # ── Pattern info ──────────────────────────────────────────────────────────
    # Query compiled pattern metadata.
    # what  : PCRE2_INFO_CAPTURECOUNT = 4  (writes uint32_t into `where`)
    # where : pointer to output buffer (io_alloc(8) is sufficient)
    def:pub pcre2_pattern_info_8(code: int, what: int, where: int) -> int;
    # ── Free ──────────────────────────────────────────────────────────────────
    # Release a compiled pcre2_code* handle.
    def:pub pcre2_code_free_8(code: int) -> None;
}
