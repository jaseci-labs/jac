"""The character-width-independent half of the _sre matching engine.

Modules/_sre/sre.c and sre.h in native Jac: the SRE_STATE, SRE_REPEAT and
match context records, the character predicates of each flavour (ASCII,
locale, Unicode), and the parts of the data stack and the repeat pool that
the Python-facing code uses too (growing and freeing the stack, clearing the
pool). The matcher, which sre_lib.h generates once per character width, is
modules/sre_ucs{1,2,4}.jac, with its own copies of the helpers it runs on
every step. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    PyMem_Free,
    PyMem_Realloc,
    PyObject,
    Py_buffer,
    _PyUnicode_IsAlpha,
    _PyUnicode_IsDecimalDigit,
    _PyUnicode_IsDigit,
    _PyUnicode_IsLinebreak,
    _PyUnicode_IsNumeric,
    _PyUnicode_IsWhitespace,
    _PyUnicode_ToLowercase,
    _PyUnicode_ToUppercase
}
import from jaclang.runtime.python.modules.sre_locale {
    sre_isalnum,
    sre_tolower,
    sre_toupper
}

import from c {
    # SRE_REPEAT: a REPEAT operator's context. `pattern` points at the
    # operator's arguments; the pool links chain the used and unused records.
    obj SreRepeat {
        has count: i64,
            pattern: ptr[u32],
            last_ptr: ptr,
            prev: ptr[SreRepeat],
            pool_prev: ptr[SreRepeat],
            pool_next: ptr[SreRepeat];
    }
    # SRE_STATE. `position` is the C's `ptr`: the current position, which is
    # also the end of the current slice.
    obj SreState {
        has position: ptr,
            beginning: ptr,
            start: ptr,
            end: ptr,
            string: ptr[PyObject],
            buffer: Py_buffer,
            pos: i64,
            endpos: i64,
            isbytes: i32,
            charsize: i32,
            match_all: i32,
            must_advance: i32,
            debug: i32,
            lastmark: i32,
            lastindex: i32,
            mark: ptr[ptr],
            data_stack: ptr[u8],
            data_stack_size: i64,
            data_stack_base: i64,
            repeat: ptr[SreRepeat],
            repeat_pool_used: ptr[SreRepeat],
            repeat_pool_unused: ptr[SreRepeat],
            sigcount: u64;
    }
    # SRE(match_context): one level of the matcher's explicit stack. The C's
    # `u` union keeps either `chr` or `rep`; `position` is its `ptr`.
    obj SreContext {
        has count: i64,
            chr: u32,
            lastmark: i32,
            rep: ptr[SreRepeat],
            lastindex: i32,
            toplevel: i32,
            pattern: ptr[u32],
            position: ptr,
            jump: i32,
            last_ctx_pos: i64;
    }
}

# Sizes of the records above: SreState is embedded in a scanner object, a
# context and a repeat are allocated by size.
glob SRE_STATE_SIZE: Final[int] = 232,
     SRE_CONTEXT_SIZE: Final[int] = 64,
     SRE_REPEAT_SIZE: Final[int] = 48,
     # offsetof(SRE_REPEAT, last_ptr)
     SRE_REPEAT_LAST_PTR: Final[int] = 16;

# Error codes.
glob SRE_ERROR_ILLEGAL: Final[int] = -1,
     SRE_ERROR_STATE: Final[int] = -2,
     SRE_ERROR_RECURSION_LIMIT: Final[int] = -3,
     SRE_ERROR_MEMORY: Final[int] = -9,
     SRE_ERROR_INTERRUPTED: Final[int] = -10;

# The jump values a context resumes at (sre_lib.h's JUMP_*).
glob JUMP_NONE: Final[i32] = 0,
     JUMP_MAX_UNTIL_1: Final[i32] = 1,
     JUMP_MAX_UNTIL_2: Final[i32] = 2,
     JUMP_MAX_UNTIL_3: Final[i32] = 3,
     JUMP_MIN_UNTIL_1: Final[i32] = 4,
     JUMP_MIN_UNTIL_2: Final[i32] = 5,
     JUMP_MIN_UNTIL_3: Final[i32] = 6,
     JUMP_REPEAT: Final[i32] = 7,
     JUMP_REPEAT_ONE_1: Final[i32] = 8,
     JUMP_REPEAT_ONE_2: Final[i32] = 9,
     JUMP_MIN_REPEAT_ONE: Final[i32] = 10,
     JUMP_BRANCH: Final[i32] = 11,
     JUMP_ASSERT: Final[i32] = 12,
     JUMP_ASSERT_NOT: Final[i32] = 13,
     JUMP_POSS_REPEAT_1: Final[i32] = 14,
     JUMP_POSS_REPEAT_2: Final[i32] = 15,
     JUMP_ATOMIC_GROUP: Final[i32] = 16;

# SRE_MAXREPEAT on a 64-bit build: (SRE_CODE)~0.
glob SRE_MAXREPEAT: Final[u32] = 0xFFFFFFFF;

# ASCII predicates (Include/pyctype.h over the C locale)

# SRE_IS_DIGIT
def sre_is_digit(ch: u32) -> bool {
    return ch >= 0x30 and ch <= 0x39;
}

# SRE_IS_SPACE: space, \t, \n, \v, \f and \r.
def sre_is_space(ch: u32) -> bool {
    return ch == 0x20 or (ch >= 0x09 and ch <= 0x0D);
}

# SRE_IS_LINEBREAK
def sre_is_linebreak(ch: u32) -> bool {
    return ch == 0x0A;
}

# Py_ISALPHA on an ASCII character.
def ascii_is_alpha(ch: u32) -> bool {
    return (ch >= 0x41 and ch <= 0x5A) or (ch >= 0x61 and ch <= 0x7A);
}

# SRE_IS_WORD
def sre_is_word(ch: u32) -> bool {
    return ascii_is_alpha(ch) or sre_is_digit(ch) or ch == 0x5F;
}

# sre_lower_ascii()
def sre_lower_ascii(ch: u32) -> u32 {
    if ch >= 0x41 and ch <= 0x5A {
        return ch + u32(0x20);
    }
    return ch;
}

# Locale predicates

# SRE_LOC_IS_ALNUM
def sre_loc_is_alnum(ch: u32) -> bool {
    return (ch & ~u32(255)) == 0 and sre_isalnum(ch);
}

# SRE_LOC_IS_WORD
def sre_loc_is_word(ch: u32) -> bool {
    return sre_loc_is_alnum(ch) or ch == 0x5F;
}

# sre_lower_locale()
def sre_lower_locale(ch: u32) -> u32 {
    return sre_tolower(ch) if ch < 256 else ch;
}

# sre_upper_locale()
def sre_upper_locale(ch: u32) -> u32 {
    return sre_toupper(ch) if ch < 256 else ch;
}

# Unicode predicates (Include/cpython/unicodeobject.h)

# SRE_UNI_IS_DIGIT: Py_UNICODE_ISDECIMAL
def sre_uni_is_digit(ch: u32) -> bool {
    return _PyUnicode_IsDecimalDigit(ch) != 0;
}

# SRE_UNI_IS_SPACE: Py_UNICODE_ISSPACE, whose ASCII half is the
# _Py_ascii_whitespace table (\t to \r, \x1c to \x1f and space).
def sre_uni_is_space(ch: u32) -> bool {
    if ch < 128 {
        return (ch >= 0x09 and ch <= 0x0D) or (ch >= 0x1C and ch <= 0x20);
    }
    return _PyUnicode_IsWhitespace(ch) != 0;
}

# SRE_UNI_IS_LINEBREAK
def sre_uni_is_linebreak(ch: u32) -> bool {
    return _PyUnicode_IsLinebreak(ch) != 0;
}

# SRE_UNI_IS_ALNUM: Py_UNICODE_ISALNUM
def sre_uni_is_alnum(ch: u32) -> bool {
    return _PyUnicode_IsAlpha(ch) != 0
        or _PyUnicode_IsDecimalDigit(ch) != 0
        or _PyUnicode_IsDigit(ch) != 0
        or _PyUnicode_IsNumeric(ch) != 0;
}

# SRE_UNI_IS_WORD
def sre_uni_is_word(ch: u32) -> bool {
    return sre_uni_is_alnum(ch) or ch == 0x5F;
}

# sre_lower_unicode()
def sre_lower_unicode(ch: u32) -> u32 {
    return _PyUnicode_ToLowercase(ch);
}

# sre_upper_unicode()
def sre_upper_unicode(ch: u32) -> u32 {
    return _PyUnicode_ToUppercase(ch);
}

# char_loc_ignore(): `ch` is `pattern` in either case of the current locale.
def char_loc_ignore(pattern: u32, ch: u32) -> bool {
    return ch == pattern
        or sre_lower_locale(ch) == pattern
        or sre_upper_locale(ch) == pattern;
}

# The data stack

def data_stack_dealloc(state: ptr[SreState]) {
    st = state.view(1);
    if st[0].data_stack {
        PyMem_Free(st[0].data_stack);
        st[0].data_stack = ptr[u8]();
    }
    st[0].data_stack_size = 0;
    st[0].data_stack_base = 0;
}

# Make room for `size` more bytes: 0, or SRE_ERROR_MEMORY with the stack freed.
def data_stack_grow(state: ptr[SreState], size: i64) -> i64 {
    st = state.view(1);
    minsize = st[0].data_stack_base + size;
    cursize = st[0].data_stack_size;
    if cursize < minsize {
        cursize = minsize + minsize // 4 + 1024;
        stack = PyMem_Realloc(st[0].data_stack, u64(cursize));
        if not stack {
            data_stack_dealloc(state);
            return SRE_ERROR_MEMORY;
        }
        st[0].data_stack = ptr[u8](stack);
        st[0].data_stack_size = cursize;
    }
    return 0;
}

# The SRE_REPEAT pool: records the matcher still uses are on a doubly
# linked list, so a match that ends early frees them all in state_fini();
# freed records are kept on a singly linked list for reuse. The matcher takes
# and returns records (repeat_pool_malloc, repeat_pool_free).

def repeat_pool_clear(state: ptr[SreState]) {
    st = state.view(1);
    # clear used pool
    next = st[0].repeat_pool_used;
    st[0].repeat_pool_used = ptr[SreRepeat]();
    while next {
        temp = next;
        next = temp.view(1)[0].pool_next;
        PyMem_Free(temp);
    }
    # clear unused pool
    next = st[0].repeat_pool_unused;
    st[0].repeat_pool_unused = ptr[SreRepeat]();
    while next {
        temp = next;
        next = temp.view(1)[0].pool_next;
        PyMem_Free(temp);
    }
}
