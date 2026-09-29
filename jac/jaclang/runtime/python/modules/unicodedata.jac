"""The unicodedata module: Modules/unicodedata.c in native Jac.

Character properties, the four normalization forms and their quick checks,
character names, aliases and named sequences, and the Unicode 3.2.0 database
IDNA reads through `unicodedata.ucd_3_2_0`, over the tables unicodedata_db.jac
and unicodename_db.jac lay out as C data. The name lookups are also the
_PyUnicode_Name_CAPI capsule that the unicode-escape codec imports for
\\N{...}. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    jacpy_unicode_ascii,
    jacpy_unicode_data,
    jacpy_unicode_kind,
    jacpy_unicode_size,
    NULL,
    Py_GetConstant,
    Py_NewRef,
    Py_TYPE,
    PyCapsule_New,
    PyErr_Format,
    PyErr_NoMemory,
    PyExc_KeyError,
    PyExc_ValueError,
    PyFloat_FromDouble,
    PyLong_FromLong,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_Realloc,
    PyModule_Type,
    PyObject,
    PyType_IsSubtype,
    PyUnicode_Compare,
    PyUnicode_CompareWithASCIIString,
    PyUnicode_DecodeUTF8Stateful,
    PyUnicode_FromKindAndData,
    PyUnicode_FromObject,
    PyUnicode_FromOrdinal,
    _PyUnicode_ToDecimalDigit,
    _PyUnicode_ToDigit,
    _PyUnicode_ToNumeric
}
import from jaclang.runtime.python.capi { c_string_length, c_string_text, object_error }
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}
import from jaclang.runtime.python.bindings.type { jacpy_binding_allocate }
import from jaclang.runtime.python.modules.unicodedata_db {
    COMP_SHIFT,
    CHANGES_3_2_0_SHIFT,
    ChangeRecord,
    DECOMP_SHIFT,
    DatabaseRecord,
    NORMALIZATION_3_2_0_LENGTH,
    Reindex,
    SHIFT,
    TOTAL_LAST,
    _PyUnicode_BidirectionalNames,
    _PyUnicode_CategoryNames,
    _PyUnicode_Database_Records,
    _PyUnicode_EastAsianWidthNames,
    ucd_change_records_3_2_0,
    ucd_changes_3_2_0_data,
    ucd_changes_3_2_0_index,
    ucd_comp_data,
    ucd_comp_index,
    ucd_decomp_data,
    ucd_decomp_index1,
    ucd_decomp_index2,
    ucd_decomp_prefix,
    ucd_index1,
    ucd_index2,
    ucd_nfc_first,
    ucd_nfc_last,
    ucd_normalization_3_2_0
}
import from jaclang.runtime.python.modules.unicodename_db {
    DAWG_CODEPOINT_TO_POS_NOTFOUND,
    DAWG_CODEPOINT_TO_POS_SHIFT,
    DERIVED_NAME_PREFIXES_LENGTH,
    DERIVED_NAME_RANGES_LENGTH,
    NAME_MAXLEN,
    aliases_end,
    aliases_start,
    named_sequences_end,
    named_sequences_start,
    ucn_dawg_codepoint_to_pos_index1,
    ucn_dawg_codepoint_to_pos_index2,
    ucn_dawg_pos_to_codepoint,
    ucn_derived_name_prefixes,
    ucn_derived_name_ranges,
    ucn_name_aliases,
    ucn_named_sequence_chars,
    ucn_named_sequence_lengths,
    ucn_packed_name_dawg
}

# For Hangul decomposition.
glob:priv SBase: int = 0xAC00,
     LBase: int = 0x1100,
     VBase: int = 0x1161,
     TBase: int = 0x11A7,
     LCount: int = 19,
     VCount: int = 21,
     TCount: int = 28,
     NCount: int = 588,
     SCount: int = 11172,
     PyUnicode_2BYTE_KIND: i32 = 2,
     PyUnicode_4BYTE_KIND: i32 = 4,
     Py_CONSTANT_EMPTY_STR: u32 = 7,
     PY_SSIZE_T_MAX: int = 0x7FFFFFFFFFFFFFFF,
     # Small combining runs are usually cheaper with insertion sort.
     CANONICAL_ORDERING_COUNTING_SORT_THRESHOLD: int = 20,
     # QuickcheckResult: this needs to match the logic in makeunicodedata.py
     # which constructs the quickcheck data.
     YES: int = 0,
     MAYBE: int = 1,
     NO: int = 2;

# The syllable names of the Hangul jamo: leading consonants, vowels and
# trailing consonants (hangul_syllables[][3] in C, by column).
import from c {
    glob:priv hangul_leading: list[ptr[u8]] = [
             ptr[u8]("G"),
             ptr[u8]("GG"),
             ptr[u8]("N"),
             ptr[u8]("D"),
             ptr[u8]("DD"),
             ptr[u8]("R"),
             ptr[u8]("M"),
             ptr[u8]("B"),
             ptr[u8]("BB"),
             ptr[u8]("S"),
             ptr[u8]("SS"),
             ptr[u8](""),
             ptr[u8]("J"),
             ptr[u8]("JJ"),
             ptr[u8]("C"),
             ptr[u8]("K"),
             ptr[u8]("T"),
             ptr[u8]("P"),
             ptr[u8]("H")
         ],
         hangul_vowels: list[ptr[u8]] = [
             ptr[u8]("A"),
             ptr[u8]("AE"),
             ptr[u8]("YA"),
             ptr[u8]("YAE"),
             ptr[u8]("EO"),
             ptr[u8]("E"),
             ptr[u8]("YEO"),
             ptr[u8]("YE"),
             ptr[u8]("O"),
             ptr[u8]("WA"),
             ptr[u8]("WAE"),
             ptr[u8]("OE"),
             ptr[u8]("YO"),
             ptr[u8]("U"),
             ptr[u8]("WEO"),
             ptr[u8]("WE"),
             ptr[u8]("WI"),
             ptr[u8]("YU"),
             ptr[u8]("EU"),
             ptr[u8]("YI"),
             ptr[u8]("I")
         ],
         hangul_trailing: list[ptr[u8]] = [
             ptr[u8](""),
             ptr[u8]("G"),
             ptr[u8]("GG"),
             ptr[u8]("GS"),
             ptr[u8]("N"),
             ptr[u8]("NJ"),
             ptr[u8]("NH"),
             ptr[u8]("D"),
             ptr[u8]("L"),
             ptr[u8]("LG"),
             ptr[u8]("LM"),
             ptr[u8]("LB"),
             ptr[u8]("LS"),
             ptr[u8]("LT"),
             ptr[u8]("LP"),
             ptr[u8]("LH"),
             ptr[u8]("M"),
             ptr[u8]("B"),
             ptr[u8]("BS"),
             ptr[u8]("S"),
             ptr[u8]("SS"),
             ptr[u8]("NG"),
             ptr[u8]("J"),
             ptr[u8]("C"),
             ptr[u8]("K"),
             ptr[u8]("T"),
             ptr[u8]("P"),
             ptr[u8]("H")
         ];
}

# ------------- Previous-version API -------------------------------------

# The definition of the unicodedata.UCD type, bound by the module binding.
glob UCD_token = ClassToken();

# PreviousDBVersion: a UCD object's database, the changes of an older
# Unicode version against the current one, as C data (the name and the two
# lookups); a UCD object's native state points at it.
import from c {
    obj PreviousDBVersionRecord {
        has name: ptr[u8],
            getrecord: Callable[[u32], ptr[ChangeRecord]],
            normalization: Callable[[u32], u32];
    }
    # Unicode database version 3.2.0 used by the IDNA encoding
    glob ucd_3_2_0_version: PreviousDBVersionRecord = PreviousDBVersionRecord(
             name=ptr[u8]("3.2.0"),
             getrecord=get_change_3_2_0,
             normalization=normalization_3_2_0
         );
}

obj PreviousDBVersion(NativeState) {
    has record: ptr[PreviousDBVersionRecord] = ptr[PreviousDBVersionRecord]();

    override def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    override def clear {}
}

# UCD_Check: whether self is a unicodedata.UCD instance. A module function's
# self is the module, and the capsule API passes NULL.
def:priv ucd_check(self: ptr[PyObject]) -> bool {
    if not self {
        return False;
    }
    tp = Py_TYPE(self);
    module_type = addressof(PyModule_Type);
    return tp != module_type and PyType_IsSubtype(tp, module_type) == 0;
}

# The older database self answers from, or NULL for the current one.
def:priv old_version(self: ptr[PyObject]) -> ptr[PreviousDBVersionRecord] {
    if not ucd_check(self) {
        return ptr[PreviousDBVersionRecord]();
    }
    definition = UCD_token.definition_of(Py_TYPE(self));
    if jacpy_binding_native_present(self, definition) == 0 {
        return ptr[PreviousDBVersionRecord]();
    }
    state = jacpy_binding_native_get(self, definition);
    if not isinstance(state, PreviousDBVersion) {
        return ptr[PreviousDBVersionRecord]();
    }
    return state.record;
}

# get_old_record: the change record of code point `c` in database `old`.
def:priv get_old_record(
    old: ptr[PreviousDBVersionRecord], c: int
) -> ptr[ChangeRecord] {
    return old.view(1)[0].getrecord(u32(c));
}

def get_change_3_2_0(code: u32) -> ptr[ChangeRecord] {
    n = int(code);
    index = 0;
    if n < 0x110000 {
        index = int(
            (addressof(ucd_changes_3_2_0_index) + (n >> CHANGES_3_2_0_SHIFT)).view(1)[0]
        );
        index = int(
            (
                addressof(ucd_changes_3_2_0_data)
                + (
                    (index << CHANGES_3_2_0_SHIFT)
                    + (n & ((1 << CHANGES_3_2_0_SHIFT) - 1))
                )
            ).view(
                1
            )[0]
        );
    }
    return addressof(ucd_change_records_3_2_0) + index;
}

def normalization_3_2_0(code: u32) -> u32 {
    changes = addressof(ucd_normalization_3_2_0);
    for i in range(NORMALIZATION_3_2_0_LENGTH) {
        change = changes + i;
        if change.view(1)[0].code == code {
            return change.view(1)[0].value;
        }
    }
    return u32(0);
}

# The database record of a code point (_getrecord_ex).
def:priv record_of(code: int) -> ptr[DatabaseRecord] {
    index = 0;
    if code < 0x110000 {
        index = int((addressof(ucd_index1) + (code >> SHIFT)).view(1)[0]);
        index = int(
            (
                addressof(ucd_index2) + ((index << SHIFT) + (code & ((1 << SHIFT) - 1)))
            ).view(
                1
            )[0]
        );
    }
    return addressof(_PyUnicode_Database_Records) + index;
}

def:priv combining_of(code: int) -> int {
    return int(record_of(code).view(1)[0].combining);
}

# The name at `index` of a NULL-terminated table of C strings, as a str.
def:priv table_text(table: ptr[ptr[u8]], index: int) -> ptr[PyObject] {
    return c_string_text((table + index).view(1)[0]);
}

# --- Module API ---------------------------------------------------------

def unicodedata_UCD_decimal_impl(
    self: ptr[PyObject], chr: i32, default_value: ptr[PyObject]
) -> ptr[PyObject] {
    have_old = False;
    rc = 0;
    c = int(chr);
    old = old_version(self);
    if not old.is_null() {
        record = get_old_record(old, c);
        if record.view(1)[0].category_changed == 0 {
            # unassigned
            have_old = True;
            rc = -1;
        } elif record.view(1)[0].decimal_changed != 0xFF {
            have_old = True;
            rc = int(record.view(1)[0].decimal_changed);
        }
    }
    if not have_old {
        rc = int(_PyUnicode_ToDecimalDigit(u32(c)));
    }
    if rc < 0 {
        if not default_value {
            object_error(PyExc_ValueError, "not a decimal");
            return NULL;
        }
        return Py_NewRef(default_value);
    }
    return PyLong_FromLong(i64(rc));
}

def unicodedata_UCD_digit_impl(
    self: ptr[PyObject], chr: i32, default_value: ptr[PyObject]
) -> ptr[PyObject] {
    rc = int(_PyUnicode_ToDigit(u32(int(chr))));
    if rc < 0 {
        if not default_value {
            object_error(PyExc_ValueError, "not a digit");
            return NULL;
        }
        return Py_NewRef(default_value);
    }
    return PyLong_FromLong(i64(rc));
}

def unicodedata_UCD_numeric_impl(
    self: ptr[PyObject], chr: i32, default_value: ptr[PyObject]
) -> ptr[PyObject] {
    have_old = False;
    rc = 0.0;
    c = int(chr);
    old = old_version(self);
    if not old.is_null() {
        record = get_old_record(old, c);
        if record.view(1)[0].category_changed == 0 {
            # unassigned
            have_old = True;
            rc = -1.0;
        } elif record.view(1)[0].numeric_changed != 0.0 {
            have_old = True;
            rc = float(record.view(1)[0].numeric_changed);
        }
    }
    if not have_old {
        rc = float(_PyUnicode_ToNumeric(u32(c)));
    }
    if rc == -1.0 {
        if not default_value {
            object_error(PyExc_ValueError, "not a numeric character");
            return NULL;
        }
        return Py_NewRef(default_value);
    }
    return PyFloat_FromDouble(rc);
}

def unicodedata_UCD_category_impl(self: ptr[PyObject], chr: i32) -> ptr[PyObject] {
    c = int(chr);
    index = int(record_of(c).view(1)[0].category);
    old = old_version(self);
    if not old.is_null() {
        changed = get_old_record(old, c).view(1)[0].category_changed;
        if changed != 0xFF {
            index = int(changed);
        }
    }
    return table_text(addressof(_PyUnicode_CategoryNames), index);
}

def unicodedata_UCD_bidirectional_impl(self: ptr[PyObject], chr: i32) -> ptr[PyObject] {
    c = int(chr);
    index = int(record_of(c).view(1)[0].bidirectional);
    old = old_version(self);
    if not old.is_null() {
        record = get_old_record(old, c);
        if record.view(1)[0].category_changed == 0 {
            index = 0;
        } elif record.view(1)[0].bidir_changed != 0xFF {
            index = int(record.view(1)[0].bidir_changed);
        }
    }
    return table_text(addressof(_PyUnicode_BidirectionalNames), index);
}

def unicodedata_UCD_combining_impl(self: ptr[PyObject], chr: i32) -> i32 {
    c = int(chr);
    index = combining_of(c);
    old = old_version(self);
    if not old.is_null() and get_old_record(old, c).view(1)[0].category_changed == 0 {
        index = 0;
    }
    return i32(index);
}

def unicodedata_UCD_mirrored_impl(self: ptr[PyObject], chr: i32) -> i32 {
    c = int(chr);
    index = int(record_of(c).view(1)[0].mirrored);
    old = old_version(self);
    if not old.is_null() {
        record = get_old_record(old, c);
        if record.view(1)[0].category_changed == 0 {
            index = 0;
        } elif record.view(1)[0].mirrored_changed != 0xFF {
            index = int(record.view(1)[0].mirrored_changed);
        }
    }
    return i32(index);
}

def unicodedata_UCD_east_asian_width_impl(
    self: ptr[PyObject], chr: i32
) -> ptr[PyObject] {
    c = int(chr);
    index = int(record_of(c).view(1)[0].east_asian_width);
    old = old_version(self);
    if not old.is_null() {
        record = get_old_record(old, c);
        if record.view(1)[0].category_changed == 0 {
            index = 0;
        } elif record.view(1)[0].east_asian_width_changed != 0xFF {
            index = int(record.view(1)[0].east_asian_width_changed);
        }
    }
    return table_text(addressof(_PyUnicode_EastAsianWidthNames), index);
}

def:priv decomp_word(index: int) -> int {
    return int((addressof(ucd_decomp_data) + index).view(1)[0]);
}

# Where a code point's decomposition starts in decomp_data: its header
# word, whose high byte is the number of code points (usually one or two)
# and whose low byte is the prefix code.
def:priv decomp_start(code: int) -> int {
    index = int((addressof(ucd_decomp_index1) + (code >> DECOMP_SHIFT)).view(1)[0]);
    return int(
        (
            addressof(ucd_decomp_index2)
            + ((index << DECOMP_SHIFT) + (code & ((1 << DECOMP_SHIFT) - 1)))
        ).view(
            1
        )[0]
    );
}

# Write `value` as at least four uppercase hex digits ("%04X") at
# buffer[at]; the index after them.
def:priv put_hex(buffer: ptr[u8], at: int, value: int) -> int {
    digits = 4;
    while (value >> (4 * digits)) != 0 {
        digits += 1;
    }
    for i in range(digits) {
        nibble = (value >> (4 * (digits - 1 - i))) & 15;
        (buffer + (at + i)).view(1)[0] = u8(
            nibble + 48 if nibble < 10 else nibble + 55
        );
    }
    return at + digits;
}

# Copy the C string `text` to buffer[at]; the index after it.
def:priv put_text(buffer: ptr[u8], at: int, text: ptr[u8]) -> int {
    size = c_string_length(text);
    for i in range(size) {
        (buffer + (at + i)).view(1)[0] = (text + i).view(1)[0];
    }
    return at + size;
}

# A str of the first `size` bytes of `buffer` (PyUnicode_FromStringAndSize).
def:priv buffer_text(buffer: ptr[u8], size: int) -> ptr[PyObject] {
    return PyUnicode_DecodeUTF8Stateful(ptr(buffer), i64(size), ptr[u8](), None);
}

def unicodedata_UCD_decomposition_impl(self: ptr[PyObject], chr: i32) -> ptr[PyObject] {
    code = int(chr);
    old = old_version(self);
    if not old.is_null()
        and get_old_record(old, code).view(1)[0].category_changed == 0 {
        # unassigned
        return Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    }
    decomp = ptr[u8](PyMem_Malloc(u64(256)));
    if decomp.is_null() {
        PyErr_NoMemory();
        return NULL;
    }
    i = 0;
    # Hangul Decomposition.
    # See section 3.12.2, "Hangul Syllable Decomposition"
    # https://www.unicode.org/versions/latest/core-spec/chapter-3/#G56669
    if SBase <= code and code < SBase + SCount {
        SIndex = code - SBase;
        L = LBase + SIndex // NCount;
        V = VBase + (SIndex % NCount) // TCount;
        T = TBase + SIndex % TCount;
        i = put_hex(decomp, i, L);
        (decomp + i).view(1)[0] = u8(32);
        i = put_hex(decomp, i + 1, V);
        if T != TBase {
            (decomp + i).view(1)[0] = u8(32);
            i = put_hex(decomp, i + 1, T);
        }
    } else {
        index = 0;
        if code >= 0 and code < 0x110000 {
            index = decomp_start(code);
        }
        # high byte is number of hex bytes (usually one or two), low byte
        # is prefix code (from decomp_prefix)
        count = decomp_word(index) >> 8;
        prefix_index = decomp_word(index) & 255;
        # copy prefix
        i = put_text(
            decomp, 0, (addressof(ucd_decomp_prefix) + prefix_index).view(1)[0]
        );
        while count > 0 {
            count -= 1;
            if i != 0 {
                (decomp + i).view(1)[0] = u8(32);
                i += 1;
            }
            index += 1;
            i = put_hex(decomp, i, decomp_word(index));
        }
    }
    result = buffer_text(decomp, i);
    PyMem_Free(ptr(decomp));
    return result;
}

# A growable array of UCS-4 code points in C memory (PyMem).
obj Ucs4Buffer {
    has data: ptr[u32] = ptr[u32](),
        length: int = 0;

    def allocate(size: int) -> bool {
        self.data = ptr[u32](PyMem_Malloc(u64(size * 4)));
        if self.data.is_null() {
            PyErr_NoMemory();
            return False;
        }
        return True;
    }

    def resize(size: int) -> bool {
        grown = PyMem_Realloc(ptr(self.data), u64(size * 4));
        if not grown {
            self.release();
            PyErr_NoMemory();
            return False;
        }
        self.data = ptr[u32](grown);
        return True;
    }

    def at(index: int) -> int {
        return int((self.data + index).view(1)[0]);
    }

    def put(index: int, value: int) {
        (self.data + index).view(1)[0] = u32(value);
    }

    def text -> ptr[PyObject] {
        return PyUnicode_FromKindAndData(
            PyUnicode_4BYTE_KIND, ptr(self.data), i64(self.length)
        );
    }

    def release {
        if not self.data.is_null() {
            PyMem_Free(ptr(self.data));
            self.data = ptr[u32]();
        }
    }
}

# PyUnicode_READ over a str's kind and data.
def:priv read_char(kind: int, data: ptr, index: int) -> int {
    if kind == 1 {
        return int((ptr[u8](data) + index).view(1)[0]);
    }
    if kind == 2 {
        return int((ptr[u16](data) + index).view(1)[0]);
    }
    return int((ptr[u32](data) + index).view(1)[0]);
}

def:priv canonical_ordering_sort_insertion(buffer: Ucs4Buffer, start: int, end: int) {
    for i in range(start + 1, end) {
        code = buffer.at(i);
        combining = combining_of(code);
        j = i;
        while j > start {
            previous = buffer.at(j - 1);
            if combining_of(previous) <= combining {
                break;
            }
            buffer.put(j, previous);
            j -= 1;
        }
        if j != i {
            buffer.put(j, code);
        }
    }
}

def:priv canonical_ordering_sort_counting(
    buffer: Ucs4Buffer, start: int, end: int, sortbuf: Ucs4Buffer
) {
    counts = [0 for _ in range(256)];
    run_length = end - start;
    total = 0;
    for i in range(start, end) {
        counts[combining_of(buffer.at(i))] += 1;
    }
    for i in range(256) {
        count = counts[i];
        counts[i] = total;
        total += count;
    }
    # Reuse counts[] as the next output slot for each CCC.
    for i in range(start, end) {
        code = buffer.at(i);
        combining = combining_of(code);
        sortbuf.put(counts[combining], code);
        counts[combining] += 1;
    }
    for i in range(run_length) {
        buffer.put(start + i, sortbuf.at(i));
    }
}

# The canonical decomposition (compatibility with `k`) of `input` in
# canonical order: nfd_nfkd before its result becomes a str. None with the
# exception set on failure.
def:priv decompose(
    self: ptr[PyObject], input: ptr[PyObject], k: bool
) -> (Ucs4Buffer | None) {
    old = old_version(self);
    # Longest decomposition in Unicode 3.2: U+FDFA
    stack: list[int] = [];
    isize = int(jacpy_unicode_size(input));
    space = isize;
    # Overallocate at most 10 characters.
    if space > 10 {
        if space <= PY_SSIZE_T_MAX - 10 {
            space += 10;
        }
    } else {
        space *= 2;
    }
    osize = space;
    output = Ucs4Buffer();
    if not output.allocate(space) {
        return None;
    }
    i = 0;
    o = 0;
    kind = int(jacpy_unicode_kind(input));
    data = jacpy_unicode_data(input);
    while i < isize {
        stack.append(read_char(kind, data, i));
        i += 1;
        while stack {
            code = stack.pop();
            # Hangul Decomposition adds three characters in
            # a single step, so we need at least that much room.
            if space < 3 {
                osize += 10;
                space += 10;
                if not output.resize(osize) {
                    return None;
                }
            }
            # Hangul Decomposition.
            # See section 3.12.2, "Hangul Syllable Decomposition"
            # https://www.unicode.org/versions/latest/core-spec/chapter-3/#G56669
            if SBase <= code and code < SBase + SCount {
                SIndex = code - SBase;
                L = LBase + SIndex // NCount;
                V = VBase + (SIndex % NCount) // TCount;
                T = TBase + SIndex % TCount;
                output.put(o, L);
                output.put(o + 1, V);
                o += 2;
                space -= 2;
                if T != TBase {
                    output.put(o, T);
                    o += 1;
                    space -= 1;
                }
                continue;
            }
            # normalization changes
            if not old.is_null() {
                value = int(old.view(1)[0].normalization(u32(code)));
                if value != 0 {
                    stack.append(value);
                    continue;
                }
            }
            # Other decompositions.
            index = 0;
            if code < 0x110000
                and not (
                    not old.is_null()
                    and get_old_record(old, code).view(1)[0].category_changed == 0
                ) {
                index = decomp_start(code);
            }
            count = decomp_word(index) >> 8;
            prefix = decomp_word(index) & 255;
            index += 1;
            # Copy character if it is not decomposable, or has a
            # compatibility decomposition, but we do NFD.
            if count == 0 or (prefix != 0 and not k) {
                output.put(o, code);
                o += 1;
                space -= 1;
                continue;
            }
            # Copy decomposition onto the stack, in reverse order.
            while count > 0 {
                count -= 1;
                stack.append(decomp_word(index + count));
            }
        }
    }
    output.length = o;
    # Sort each consecutive combining-character run canonically.
    sortbuf = Ucs4Buffer();
    sortbuflen = 0;
    i = 0;
    while i < o {
        prev = combining_of(output.at(i));
        if prev == 0 {
            i += 1;
            continue;
        }
        needs_sort = False;
        run_start = i;
        i += 1;
        while i < o {
            cur = combining_of(output.at(i));
            if cur == 0 {
                break;
            }
            if prev > cur {
                needs_sort = True;
            }
            prev = cur;
            i += 1;
        }
        if not needs_sort {
            continue;
        }
        run_length = i - run_start;
        if run_length < CANONICAL_ORDERING_COUNTING_SORT_THRESHOLD {
            canonical_ordering_sort_insertion(output, run_start, i);
            continue;
        }
        if run_length > sortbuflen {
            if not (
                sortbuf.resize(run_length)
                    if sortbuflen
                    else sortbuf.allocate(run_length)
            ) {
                output.release();
                return None;
            }
            sortbuflen = run_length;
        }
        canonical_ordering_sort_counting(output, run_start, i, sortbuf);
    }
    sortbuf.release();
    return output;
}

def:priv nfd_nfkd(self: ptr[PyObject], input: ptr[PyObject], k: bool) -> ptr[PyObject] {
    decomposed = decompose(self, input, k);
    if decomposed is None {
        return NULL;
    }
    result = decomposed.text();
    decomposed.release();
    return result;
}

def:priv find_nfc_index(nfc: ptr[Reindex], code: int) -> int {
    index = 0;
    while True {
        item = nfc + index;
        start = int(item.view(1)[0].start);
        if start == 0 {
            return -1;
        }
        if code < start {
            return -1;
        }
        if code <= start + int(item.view(1)[0].count) {
            return int(item.view(1)[0].index) + (code - start);
        }
        index += 1;
    }
    return -1;
}

def:priv nfc_nfkc(self: ptr[PyObject], input: ptr[PyObject], k: bool) -> ptr[PyObject] {
    decomposed = decompose(self, input, k);
    if decomposed is None {
        return NULL;
    }
    length = decomposed.length;
    # We allocate a buffer for the output.
    # If we find that we made no changes, we still return
    # the NFD result.
    output = Ucs4Buffer();
    if not output.allocate(length) {
        decomposed.release();
        return NULL;
    }
    first = addressof(ucd_nfc_first);
    last = addressof(ucd_nfc_last);
    skipped: list[int] = [];
    i = 0;
    o = 0;
    while i < length {
        was_skipped = False;
        for index in range(len(skipped)) {
            if skipped[index] == i {
                # *i character is skipped.
                # Remove from list.
                skipped[index] = skipped[len(skipped) - 1];
                skipped.pop();
                i += 1;
                was_skipped = True;
                break;
            }
        }
        if was_skipped {
            continue;
        }
        # Hangul Composition. We don't need to check for <LV,T>
        # pairs, since we always have decomposed data.
        code = decomposed.at(i);
        if LBase <= code
            and code < LBase + LCount
            and i + 1 < length
            and VBase <= decomposed.at(i + 1)
            and decomposed.at(i + 1) < VBase + VCount {
            # check L character is a modern leading consonant (0x1100 ~ 0x1112)
            # and V character is a modern vowel (0x1161 ~ 0x1175).
            LIndex = code - LBase;
            VIndex = decomposed.at(i + 1) - VBase;
            code = SBase + (LIndex * VCount + VIndex) * TCount;
            i += 2;
            if i < length
                and TBase < decomposed.at(i)
                and decomposed.at(i) < TBase + TCount {
                # check T character is a modern trailing consonant
                # (0x11A8 ~ 0x11C2).
                code += decomposed.at(i) - TBase;
                i += 1;
            }
            output.put(o, code);
            o += 1;
            continue;
        }
        # code is still input[i] here
        f = find_nfc_index(first, code);
        if f == -1 {
            output.put(o, code);
            o += 1;
            i += 1;
            continue;
        }
        # Find next unblocked character.
        i1 = i + 1;
        comb = 0;
        # output base character for now; might be updated later.
        output.put(o, decomposed.at(i));
        while i1 < length {
            code1 = decomposed.at(i1);
            comb1 = combining_of(code1);
            if comb != 0 {
                if comb1 == 0 {
                    break;
                }
                if comb >= comb1 {
                    # Character is blocked.
                    i1 += 1;
                    continue;
                }
            }
            l = find_nfc_index(last, code1);
            # i1 cannot be combined with i. If i1
            # is a starter, we don't need to look further.
            # Otherwise, record the combining class.
            composed = 0;
            if l != -1 {
                index = f * TOTAL_LAST + l;
                index1 = int(
                    (addressof(ucd_comp_index) + (index >> COMP_SHIFT)).view(1)[0]
                );
                composed = int(
                    (
                        addressof(ucd_comp_data)
                        + ((index1 << COMP_SHIFT) + (index & ((1 << COMP_SHIFT) - 1)))
                    ).view(
                        1
                    )[0]
                );
            }
            if composed == 0 {
                # not_combinable
                if comb1 == 0 {
                    break;
                }
                comb = comb1;
                i1 += 1;
                continue;
            }
            # Replace the original character.
            output.put(o, composed);
            # Mark the second character unused.
            skipped.append(i1);
            i1 += 1;
            f = find_nfc_index(first, composed);
            if f == -1 {
                break;
            }
        }
        # Output character was already written.
        # Just advance the indices.
        o += 1;
        i += 1;
    }
    if o == length {
        # No changes. Return original string.
        output.release();
        result = decomposed.text();
        decomposed.release();
        return result;
    }
    decomposed.release();
    output.length = o;
    result = output.text();
    output.release();
    return result;
}

# Run the Unicode normalization "quickcheck" algorithm.
#
# Return YES or NO if quickcheck determines the input is certainly
# normalized or certainly not, and MAYBE if quickcheck is unable to
# tell.
#
# If `yes_only` is true, then return MAYBE as soon as we determine
# the answer is not YES.
#
# For background and details on the algorithm, see UAX #15:
#   https://www.unicode.org/reports/tr15/#Detecting_Normalization_Forms
def:priv is_normalized_quickcheck(
    self: ptr[PyObject], input: ptr[PyObject], nfc: bool, k: bool, yes_only: bool
) -> int {
    # UCD 3.2.0 is requested, quickchecks must be disabled.
    if ucd_check(self) {
        return MAYBE;
    }
    if jacpy_unicode_ascii(input) != 0 {
        return YES;
    }
    prev_combining = 0;
    # The two quickcheck bits at this shift have type QuickcheckResult.
    quickcheck_shift = (4 if nfc else 0) + (2 if k else 0);
    # certainly normalized, unless we find something
    result = YES;
    kind = int(jacpy_unicode_kind(input));
    data = jacpy_unicode_data(input);
    length = int(jacpy_unicode_size(input));
    for i in range(length) {
        record = record_of(read_char(kind, data, i));
        combining = int(record.view(1)[0].combining);
        if combining != 0 and prev_combining > combining {
            # non-canonical sort order, not normalized
            return NO;
        }
        prev_combining = combining;
        quickcheck_whole = int(record.view(1)[0].normalization_quick_check);
        if yes_only {
            if (quickcheck_whole & (3 << quickcheck_shift)) != 0 {
                return MAYBE;
            }
        } else {
            check = (quickcheck_whole >> quickcheck_shift) & 3;
            if check == NO {
                return NO;
            }
            if check == MAYBE {
                # this string might need normalization
                result = MAYBE;
            }
        }
    }
    return result;
}

def unicodedata_UCD_is_normalized_impl(
    self: ptr[PyObject], form: ptr[PyObject], input: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_unicode_size(input) == 0 {
        # special case empty input strings.
        return PyBool_FromLong(1);
    }
    nfc = False;
    k = False;
    if PyUnicode_CompareWithASCIIString(form, "NFC") == 0 {
        nfc = True;
    } elif PyUnicode_CompareWithASCIIString(form, "NFKC") == 0 {
        nfc = True;
        k = True;
    } elif PyUnicode_CompareWithASCIIString(form, "NFD") == 0 {
        # matches default values for `nfc` and `k`
        k = False;
    } elif PyUnicode_CompareWithASCIIString(form, "NFKD") == 0 {
        k = True;
    } else {
        object_error(PyExc_ValueError, "invalid normalization form");
        return NULL;
    }
    m = is_normalized_quickcheck(self, input, nfc, k, False);
    if m == MAYBE {
        cmp = nfc_nfkc(self, input, k) if nfc else nfd_nfkd(self, input, k);
        if not cmp {
            return NULL;
        }
        match_ = PyUnicode_Compare(input, cmp);
        jacpy_release(cmp);
        return PyBool_FromLong(i64(match_ == 0));
    }
    return PyBool_FromLong(i64(m == YES));
}

def unicodedata_UCD_normalize_impl(
    self: ptr[PyObject], form: ptr[PyObject], input: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_unicode_size(input) == 0 {
        # Special case empty input strings, since resizing
        # them later would cause internal errors.
        return PyUnicode_FromObject(input);
    }
    if PyUnicode_CompareWithASCIIString(form, "NFC") == 0 {
        if is_normalized_quickcheck(self, input, True, False, True) == YES {
            return PyUnicode_FromObject(input);
        }
        return nfc_nfkc(self, input, False);
    }
    if PyUnicode_CompareWithASCIIString(form, "NFKC") == 0 {
        if is_normalized_quickcheck(self, input, True, True, True) == YES {
            return PyUnicode_FromObject(input);
        }
        return nfc_nfkc(self, input, True);
    }
    if PyUnicode_CompareWithASCIIString(form, "NFD") == 0 {
        if is_normalized_quickcheck(self, input, False, False, True) == YES {
            return PyUnicode_FromObject(input);
        }
        return nfd_nfkd(self, input, False);
    }
    if PyUnicode_CompareWithASCIIString(form, "NFKD") == 0 {
        if is_normalized_quickcheck(self, input, False, True, True) == YES {
            return PyUnicode_FromObject(input);
        }
        return nfd_nfkd(self, input, True);
    }
    object_error(PyExc_ValueError, "invalid normalization form");
    return NULL;
}

# -------------------------------------------------------------------------
# database code (cut and pasted from the unidb package)

def:priv find_prefix_id(code: int) -> int {
    ranges = addressof(ucn_derived_name_ranges);
    for i in range(DERIVED_NAME_RANGES_LENGTH) {
        item = ranges + i;
        if code < int(item.view(1)[0].first) {
            return -1;
        }
        if code <= int(item.view(1)[0].last) {
            return int(item.view(1)[0].prefixid);
        }
    }
    return -1;
}

# whether the given code point is in the PUA range that we are using to
# store aliases and named sequences
def:priv is_alias(cp: int) -> bool {
    return cp >= aliases_start and cp < aliases_end;
}

def:priv is_named_seq(cp: int) -> bool {
    return cp >= named_sequences_start and cp < named_sequences_end;
}

def:priv byte_at(text: ptr[u8], index: int) -> int {
    return int((text + index).view(1)[0]);
}

# Py_TOUPPER and Py_TOLOWER: ASCII letters only.
def:priv ascii_upper(c: int) -> int {
    return c - 32 if c >= 97 and c <= 122 else c;
}

def:priv ascii_lower(c: int) -> int {
    return c + 32 if c >= 65 and c <= 90 else c;
}

# PyOS_strnicmp: compare at most `size` bytes of two C strings, ignoring
# ASCII case and stopping at a NUL.
def:priv strnicmp(s1: ptr[u8], s2: ptr[u8], size: int) -> int {
    if size == 0 {
        return 0;
    }
    i = 0;
    remaining = size;
    while True {
        remaining -= 1;
        c1 = byte_at(s1, i);
        c2 = byte_at(s2, i);
        if not (
            remaining > 0 and c1 != 0 and c2 != 0 and ascii_lower(c1) == ascii_lower(c2)
        ) {
            return ascii_lower(c1) - ascii_lower(c2);
        }
        i += 1;
    }
    return 0;
}

# DAWG decoding: the scratch values of one walk over packed_name_dawg.
#
# A node is encoded by a varint. The lowest bit of that int is set if the
# node is a final, accepting state. The higher bits of that int represent
# the number of names that are encoded by the sub-DAWG started by this node.
# It's used to compute the position of a name. The starting node of the
# DAWG is at position 0. The varint representing a node is followed by the
# node's edges.
#
# A DAWG edge is comprised of the size of the label of the string attached
# to the edge, the characters of that edge, the target node, and whether
# the edge is the last edge in the list of edges following a node, encoded
# as a varint (bit 0: last edge, bit 1: the label is one character, the
# rest: the target's offset from the previous edge's target, or from the
# first edge for the first one), then the label size unless it is one,
# then the label characters. A final node without outgoing edges is
# followed by a 0 byte, which decode_edge reports as -1.
obj Dawg {
    has value: int = 0,
        final: bool = False,
        size: int = 0,
        label_offset: int = 0,
        target_node_offset: int = 0;

    def byte(index: int) -> int {
        return int((addressof(ucn_packed_name_dawg) + index).view(1)[0]);
    }

    # A varint at `index` into self.value; the index after it.
    def decode_varint_unsigned(index: int) -> int {
        res = 0;
        shift = 0;
        while True {
            byte = self.byte(index);
            res |= (byte & 0x7F) << shift;
            index += 1;
            shift += 7;
            if (byte & 0x80) == 0 {
                self.value = res;
                return index;
            }
        }
        return index;
    }

    # 1 if the edge matched, 0 if it didn't (but further edges could
    # match) and -1 if the name cannot match at all.
    def match_edge(name: ptr[u8], namelen: int, namepos: int) -> int {
        if self.size > 1 and namepos + self.size > namelen {
            return 0;
        }
        for i in range(self.size) {
            if self.byte(self.label_offset + i)
                != ascii_upper(byte_at(name, namepos + i)) {
                if i > 0 {
                    return -1;
                }
                return 0;
            }
        }
        return 1;
    }

    def decode_node(node_offset: int) -> int {
        node_offset = self.decode_varint_unsigned(node_offset);
        self.final = (self.value & 1) != 0;
        return node_offset;
    }

    def node_is_final(node_offset: int) -> bool {
        self.decode_varint_unsigned(node_offset);
        return (self.value & 1) != 0;
    }

    def node_descendant_count(node_offset: int) -> int {
        self.decode_varint_unsigned(node_offset);
        return self.value >> 1;
    }

    def decode_edge(
        is_first_edge: bool, prev_target_node_offset: int, edge_offset: int
    ) -> int {
        edge_offset = self.decode_varint_unsigned(edge_offset);
        num = self.value;
        if num == 0 and is_first_edge {
            # trying to decode past a final node without outgoing edges
            return -1;
        }
        last_edge = num & 1;
        num >>= 1;
        len_is_one = (num & 1) != 0;
        num >>= 1;
        self.target_node_offset = prev_target_node_offset + num;
        if len_is_one {
            self.size = 1;
        } else {
            self.size = self.byte(edge_offset);
            edge_offset += 1;
        }
        self.label_offset = edge_offset;
        return last_edge;
    }

    # The position of `name` in the DAWG's order of names, or -1.
    def lookup_packed(name: ptr[u8], namelen: int) -> int {
        stringpos = 0;
        node_offset = 0;
        # the number of final nodes that we skipped to match name
        result = 0;
        while stringpos < namelen {
            edge_offset = self.decode_node(node_offset);
            final = self.final;
            prev_target_node_offset = edge_offset;
            is_first_edge = True;
            while True {
                last_edge = self.decode_edge(
                    is_first_edge, prev_target_node_offset, edge_offset
                );
                if last_edge == -1 {
                    return -1;
                }
                is_first_edge = False;
                prev_target_node_offset = self.target_node_offset;
                matched = self.match_edge(name, namelen, stringpos);
                if matched == -1 {
                    return -1;
                }
                if matched != 0 {
                    if final {
                        result += 1;
                    }
                    stringpos += self.size;
                    node_offset = self.target_node_offset;
                    break;
                }
                if last_edge != 0 {
                    return -1;
                }
                size = self.size;
                label_offset = self.label_offset;
                result += self.node_descendant_count(self.target_node_offset);
                edge_offset = label_offset + size;
            }
        }
        if self.node_is_final(node_offset) {
            return result;
        }
        return -1;
    }

    # Write the name at DAWG position `pos` into buffer; False when it does
    # not fit in `buflen` bytes or there is none.
    def inverse_lookup(buffer: ptr[u8], buflen: int, pos: int) -> bool {
        node_offset = 0;
        bufpos = 0;
        while True {
            edge_offset = self.decode_node(node_offset);
            if self.final {
                if pos == 0 {
                    if bufpos + 1 == buflen {
                        return False;
                    }
                    (buffer + bufpos).view(1)[0] = u8(0);
                    return True;
                }
                pos -= 1;
            }
            prev_target_node_offset = edge_offset;
            is_first_edge = True;
            while True {
                last_edge = self.decode_edge(
                    is_first_edge, prev_target_node_offset, edge_offset
                );
                if last_edge == -1 {
                    return False;
                }
                is_first_edge = False;
                prev_target_node_offset = self.target_node_offset;
                size = self.size;
                label_offset = self.label_offset;
                target_node_offset = self.target_node_offset;
                descendant_count = self.node_descendant_count(target_node_offset);
                if pos < descendant_count {
                    if bufpos + size >= buflen {
                        # buffer overflow
                        return False;
                    }
                    for i in range(size) {
                        (buffer + bufpos).view(1)[0] = u8(self.byte(label_offset + i));
                        bufpos += 1;
                    }
                    node_offset = target_node_offset;
                    break;
                } elif last_edge == 0 {
                    pos -= descendant_count;
                    edge_offset = label_offset + size;
                } else {
                    return False;
                }
            }
        }
        return False;
    }
}

# Find the name associated with the given code point. If
# with_alias_and_seq is set, check for names in the Private Use Area 15
# that we are using for aliases and named sequences.
def:priv getucname(
    self: ptr[PyObject],
    code: int,
    buffer: ptr[u8],
    buflen: int,
    with_alias_and_seq: bool
) -> bool {
    if code >= 0x110000 {
        return False;
    }
    # XXX should we just skip all the code points in the PUAs here?
    if not with_alias_and_seq and (is_alias(code) or is_named_seq(code)) {
        return False;
    }
    old = old_version(self);
    if not old.is_null() {
        # in 3.2.0 there are no aliases and named sequences
        if is_alias(code) or is_named_seq(code) {
            return False;
        }
        if get_old_record(old, code).view(1)[0].category_changed == 0 {
            # unassigned
            return False;
        }
    }
    prefixid = find_prefix_id(code);
    if prefixid == 0 {
        # Hangul syllable.
        SIndex = code - SBase;
        L = SIndex // NCount;
        V = (SIndex % NCount) // TCount;
        T = SIndex % TCount;
        if buflen < 27 {
            # Worst case: HANGUL SYLLABLE <10chars>.
            return False;
        }
        at = put_text(buffer, 0, ptr[u8]("HANGUL SYLLABLE "));
        at = put_text(buffer, at, (addressof(hangul_leading) + L).view(1)[0]);
        at = put_text(buffer, at, (addressof(hangul_vowels) + V).view(1)[0]);
        at = put_text(buffer, at, (addressof(hangul_trailing) + T).view(1)[0]);
        (buffer + at).view(1)[0] = u8(0);
        return True;
    }
    # Only support CJK unified ideographs.
    # Support for Tangut ideographs is a new feature in 3.15.
    if prefixid == 1 {
        prefix = (addressof(ucn_derived_name_prefixes) + prefixid).view(1)[0];
        # snprintf(buffer, buflen, "%s%04X", prefix, code) >= buflen
        size = c_string_length(prefix);
        digits = 4;
        while (code >> (4 * digits)) != 0 {
            digits += 1;
        }
        if size + digits >= buflen {
            return False;
        }
        at = put_text(buffer, 0, prefix);
        at = put_hex(buffer, at, code);
        (buffer + at).view(1)[0] = u8(0);
        return True;
    }
    # get position of codepoint in order of names in the dawg
    offset = int(
        (
            addressof(ucn_dawg_codepoint_to_pos_index1)
            + (code >> DAWG_CODEPOINT_TO_POS_SHIFT)
        ).view(
            1
        )[0]
    );
    offset = int(
        (
            addressof(ucn_dawg_codepoint_to_pos_index2)
            + (
                (offset << DAWG_CODEPOINT_TO_POS_SHIFT)
                + (code & ((1 << DAWG_CODEPOINT_TO_POS_SHIFT) - 1))
            )
        ).view(
            1
        )[0]
    );
    if offset == DAWG_CODEPOINT_TO_POS_NOTFOUND {
        return False;
    }
    return Dawg().inverse_lookup(buffer, buflen, offset);
}

# The column index of the longest syllable of `column` that `text` starts
# with (ignoring case), and its length; (-1, 0) when none does.
def:priv find_syllable(
    text: ptr[u8], column: ptr[ptr[u8]], count: int
) -> tuple[int, int] {
    length = -1;
    pos = -1;
    for i in range(count) {
        syllable = (column + i).view(1)[0];
        len1 = c_string_length(syllable);
        if len1 <= length {
            continue;
        }
        if strnicmp(text, syllable, len1) == 0 {
            length = len1;
            pos = i;
        }
    }
    if length == -1 {
        length = 0;
    }
    return (pos, length);
}

def:priv parse_hex_code(name: ptr[u8], namelen: int) -> int {
    if namelen < 4 or namelen > 6 {
        return -1;
    }
    if byte_at(name, 0) == 48 {
        return -1;
    }
    v = 0;
    for i in range(namelen) {
        v *= 16;
        c = ascii_upper(byte_at(name, i));
        if c >= 48 and c <= 57 {
            v += c - 48;
        } elif c >= 65 and c <= 70 {
            v += c - 65 + 10;
        } else {
            return -1;
        }
    }
    if v > 0x10FFFF {
        return -1;
    }
    return v;
}

# Return the code point associated with the given name, or -1. Named
# aliases are not resolved, they are returned as a code point in the PUA.
def:priv getcode(name: ptr[u8], namelen: int) -> int {
    prefixes = addressof(ucn_derived_name_prefixes);
    i = 0;
    prefixlen = 0;
    while i < DERIVED_NAME_PREFIXES_LENGTH {
        prefix = (prefixes + i).view(1)[0];
        prefixlen = c_string_length(prefix);
        if strnicmp(name, prefix, prefixlen) == 0 {
            break;
        }
        i += 1;
    }
    if i == 0 {
        # Hangul syllables.
        pos = name + 16;
        (L, length) = find_syllable(pos, addressof(hangul_leading), LCount);
        pos += length;
        (V, length) = find_syllable(pos, addressof(hangul_vowels), VCount);
        pos += length;
        (T, length) = find_syllable(pos, addressof(hangul_trailing), TCount);
        pos += length;
        if L != -1 and V != -1 and T != -1 and (pos - name) == namelen {
            return SBase + (L * VCount + V) * TCount + T;
        }
        # Otherwise, it's an illegal syllable name.
        return -1;
    }
    if i < DERIVED_NAME_PREFIXES_LENGTH {
        v = parse_hex_code(name + prefixlen, namelen - prefixlen);
        if find_prefix_id(v) != i {
            return -1;
        }
        return v;
    }
    position = Dawg().lookup_packed(name, namelen);
    if position < 0 {
        return -1;
    }
    return int((addressof(ucn_dawg_pos_to_codepoint) + position).view(1)[0]);
}

# The capsule's getname() and getcode(): _PyUnicode_Name_CAPI.
def:priv capi_getucname(
    code: u32, buffer: ptr[u8], buflen: i32, with_alias_and_seq: i32
) -> i32 {
    return i32(
        getucname(NULL, int(code), buffer, int(buflen), with_alias_and_seq != 0)
    );
}

def:priv capi_getcode(
    name: ptr[u8], namelen: i32, code: ptr[u32], with_named_seq: i32
) -> i32 {
    found = getcode(name, int(namelen));
    if found < 0 {
        return i32(0);
    }
    # check if named sequences are allowed
    if with_named_seq == 0 and is_named_seq(found) {
        return i32(0);
    }
    # if the code point is in the PUA range that we use for aliases,
    # convert it to obtain the right code point
    if is_alias(found) {
        found = int((addressof(ucn_name_aliases) + (found - aliases_start)).view(1)[0]);
    }
    code.view(1)[0] = u32(found);
    return i32(1);
}

import from c {
    # pycore_ucnhash.h
    obj _PyUnicode_Name_CAPI {
        has getname: Callable[[u32, ptr[u8], i32, i32], i32],
            getcode: Callable[[ptr[u8], i32, ptr[u32], i32], i32];
    }
    # Statically allocated so that any cached pointers stay valid after
    # unicodedata is removed from sys.modules and the capsule is gc'd
    # (gh-149449).
    glob:priv unicodedata_capi: _PyUnicode_Name_CAPI = _PyUnicode_Name_CAPI(
             getname=capi_getucname, getcode=capi_getcode
         );
}

def unicodedata_create_capi -> ptr[PyObject] {
    return PyCapsule_New(
        ptr(addressof(unicodedata_capi)), "unicodedata._ucnhash_CAPI", NULL
    );
}

# -------------------------------------------------------------------------
# Python bindings

def unicodedata_UCD_name_impl(
    self: ptr[PyObject], chr: i32, default_value: ptr[PyObject]
) -> ptr[PyObject] {
    name = ptr[u8](PyMem_Malloc(u64(NAME_MAXLEN + 1)));
    if name.is_null() {
        PyErr_NoMemory();
        return NULL;
    }
    if not getucname(self, int(chr), name, NAME_MAXLEN, False) {
        PyMem_Free(ptr(name));
        if not default_value {
            object_error(PyExc_ValueError, "no such name");
            return NULL;
        }
        return Py_NewRef(default_value);
    }
    result = c_string_text(name);
    PyMem_Free(ptr(name));
    return result;
}

def unicodedata_UCD_lookup_impl(
    self: ptr[PyObject], name: ptr[u8], name_length: i64
) -> ptr[PyObject] {
    if name_length > NAME_MAXLEN {
        object_error(PyExc_KeyError, "name too long");
        return NULL;
    }
    code = getcode(name, int(name_length));
    if code < 0 {
        return PyErr_Format(PyExc_KeyError, "undefined character name '%s'", name);
    }
    if ucd_check(self) {
        # in 3.2.0 there are no aliases and named sequences
        if is_alias(code) or is_named_seq(code) {
            return PyErr_Format(PyExc_KeyError, "undefined character name '%s'", name);
        }
    }
    # check if code is in the PUA range that we use for named sequences
    # and convert it
    if is_named_seq(code) {
        index = code - named_sequences_start;
        return PyUnicode_FromKindAndData(
            PyUnicode_2BYTE_KIND,
            ptr(addressof(ucn_named_sequence_chars) + index * 4),
            i64((addressof(ucn_named_sequence_lengths) + index).view(1)[0])
        );
    }
    if is_alias(code) {
        code = int((addressof(ucn_name_aliases) + (code - aliases_start)).view(1)[0]);
    }
    return PyUnicode_FromOrdinal(i32(code));
}

# new_previous_version: a UCD object of `ucd_type` answering from the older
# database `version`; NULL with the exception set on failure.
def new_previous_version(
    ucd_type: ptr[PyObject], version: ptr[PreviousDBVersionRecord]
) -> ptr[PyObject] {
    self = jacpy_binding_allocate(ucd_type);
    if not self {
        return NULL;
    }
    state = PreviousDBVersion(record=version);
    if jacpy_binding_native_set(self, UCD_token.definition_of(ucd_type), state) < 0 {
        jacpy_release(self);
        return NULL;
    }
    return self;
}

# The unidata_version member of a UCD object.
def ucd_unidata_version(self: ptr[PyObject]) -> ptr[PyObject] {
    old = old_version(self);
    if old.is_null() {
        return NULL;
    }
    return c_string_text(old.view(1)[0].name);
}
