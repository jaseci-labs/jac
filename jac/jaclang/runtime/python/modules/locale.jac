"""POSIX locale support; derived from CPython 3.14.6 Modules/_localemodule.c.

See ../LICENSE.cpython. The C library's locale state is process-wide; these
functions read and change it with setlocale(), localeconv(), nl_langinfo(),
the wide-character collation functions and, where the C library has them,
the gettext message catalogs (modules/locale_platform.<os>.jac). The module
state holds locale.Error.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_char_max,
    jacpy_clear_errno,
    jacpy_errno,
    jacpy_release,
    lconv,
    NULL,
    _Py_GetLocaleconvNumeric,
    _Py_GetLocaleEncodingObject,
    Py_NewRef,
    PyBytes_AsString,
    PyDict_New,
    PyDict_SetItemString,
    PyErr_NoMemory,
    PyErr_SetFromErrno,
    PyErr_SetString,
    PyExc_OSError,
    PyExc_RuntimeError,
    PyExc_RuntimeWarning,
    PyExc_ValueError,
    PyList_New,
    PyList_SetItem,
    PyLong_FromLong,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_Realloc,
    _PyMem_Strdup,
    PyObject,
    PyUnicode_AsWideCharString,
    PyUnicode_DecodeLocale,
    PyUnicode_FromKindAndData,
    PyUnicode_FromString,
    PyUnicode_FSConverter
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.bindings.converters { borrowed_none }
import from jaclang.runtime.python.modules.errno_constants { ERANGE }
import from jaclang.runtime.python.modules.locale_constants {
    ALT_DIGITS,
    CONSTANTS,
    ERA,
    LC_CTYPE,
    LC_MESSAGES,
    LC_MONETARY,
    LC_NUMERIC,
    LC_TIME
}
import from jaclang.runtime.python.modules.locale_platform {
    GLIBC,
    bind_textdomain_codeset,
    bindtextdomain,
    dcgettext,
    dgettext,
    gettext,
    textdomain
}
import from c {
    def setlocale(category: i32, locale: ptr[u8]) -> ptr[u8];  def localeconv -> ptr[
        lconv
    ];  def nl_langinfo(item: i32) -> ptr[u8];  def strlen(s: ptr[u8]) -> u64;  def strcmp(
        s1: ptr[u8], s2: ptr[u8]
    ) -> i32;  def wcslen(s: ptr[i32]) -> u64;  def wcscoll(
        ws1: ptr[i32], ws2: ptr[i32]
    ) -> i32;  def wcsxfrm(ws1: ptr[i32], ws2: ptr[i32], n: u64) -> u64;
}

# The module state reference holding locale.Error.
glob ERROR: int = 0;

glob:priv PyUnicode_4BYTE_KIND: i32 = 4,
     SIZEOF_WCHAR_T: i64 = 4;

def:priv locale_error(module: ptr[PyObject], message: str) {
    PyErr_SetString(jacpy_binding_state_get(module, i64(ERROR)), message);
}

def:priv byte_at(text: ptr[u8], index: int) -> int {
    return int((text + index).view(1)[0]);
}

"""A C `char` read as a byte, sign-extended where the target's char is signed."""
def:priv char_value(byte: int) -> int {
    return byte - 256 if jacpy_char_max() == 127 and byte > 127 else byte;
}

"""copy_grouping(): the grouping is terminated by either 0 or CHAR_MAX."""
def:priv copy_grouping(text: ptr[u8]) -> ptr[PyObject] {
    if byte_at(text, 0) == 0 {
        # empty string: no grouping at all
        return PyList_New(0);
    }
    char_max = int(jacpy_char_max());
    count = 0;
    while byte_at(text, count) != 0 and char_value(byte_at(text, count)) != char_max {
        count += 1;
    }
    result = PyList_New(i64(count + 1));
    if not result {
        return NULL;
    }
    for i in range(count + 1) {
        val = PyLong_FromLong(i64(char_value(byte_at(text, i))));
        if not val {
            jacpy_release(result);
            return NULL;
        }
        PyList_SetItem(result, i64(i), val);
    }
    return result;
}

def _locale_setlocale_impl(
    module: ptr[PyObject], category: i32, locale: ptr[u8]
) -> ptr[PyObject] {
    if locale {
        # set locale
        result = setlocale(category, locale);
        if not result {
            # operation failed, no setting was changed
            locale_error(module, "unsupported locale setting");
            return NULL;
        }
        return PyUnicode_DecodeLocale(result, ptr[u8]());
    }
    # get locale
    result = setlocale(category, ptr[u8]());
    if not result {
        locale_error(module, "locale query failed");
        return NULL;
    }
    return PyUnicode_DecodeLocale(result, ptr[u8]());
}

def:priv locale_is_ascii(text: ptr[u8]) -> bool {
    return strlen(text) == u64(1) and byte_at(text, 0) <= 127;
}

def:priv is_all_ascii(text: ptr[u8]) -> bool {
    index = 0;
    while byte_at(text, index) != 0 {
        if byte_at(text, index) > 127 {
            return False;
        }
        index += 1;
    }
    return True;
}

def:priv set_decoded(dict_: ptr[PyObject], key: str, text: ptr[u8]) -> bool {
    value = PyUnicode_DecodeLocale(text, ptr[u8]());
    if not value {
        return False;
    }
    status = PyDict_SetItemString(dict_, key, value);
    jacpy_release(value);
    return status >= 0;
}

def:priv set_owned(dict_: ptr[PyObject], key: str, value: ptr[PyObject]) -> bool {
    if not value {
        return False;
    }
    status = PyDict_SetItemString(dict_, key, value);
    jacpy_release(value);
    return status >= 0;
}

"""The monetary strings, decoded with LC_CTYPE temporarily set to the
LC_MONETARY locale when the two differ and one of them is not ASCII."""
def:priv locale_decode_monetary(dict_: ptr[PyObject], lc: ptr[lconv]) -> i32 {
    change_locale = not locale_is_ascii(lc.view(1)[0].int_curr_symbol)
        or not locale_is_ascii(lc.view(1)[0].currency_symbol)
        or not locale_is_ascii(lc.view(1)[0].mon_decimal_point)
        or not locale_is_ascii(lc.view(1)[0].mon_thousands_sep);
    # Keep a copy of the LC_CTYPE locale
    oldloc = ptr[u8]();
    loc = ptr[u8]();
    if change_locale {
        oldloc = setlocale(i32(LC_CTYPE), ptr[u8]());
        if not oldloc {
            PyErr_SetString(
                PyExc_RuntimeWarning, "failed to get LC_CTYPE locale"
            );
            return i32(-1);
        }
        oldloc = _PyMem_Strdup(oldloc);
        if not oldloc {
            PyErr_NoMemory();
            return i32(-1);
        }
        loc = setlocale(i32(LC_MONETARY), ptr[u8]());
        if loc and strcmp(loc, oldloc) == 0 {
            loc = ptr[u8]();
        }
        if loc {
            setlocale(i32(LC_CTYPE), loc);
        }
    }
    res = i32(-1);
    if set_decoded(dict_, "int_curr_symbol", lc.view(1)[0].int_curr_symbol)
        and set_decoded(dict_, "currency_symbol", lc.view(1)[0].currency_symbol)
        and set_decoded(dict_, "mon_decimal_point", lc.view(1)[0].mon_decimal_point)
        and set_decoded(dict_, "mon_thousands_sep", lc.view(1)[0].mon_thousands_sep) {
        res = i32(0);
    }
    if loc {
        setlocale(i32(LC_CTYPE), oldloc);
    }
    PyMem_Free(oldloc);
    return res;
}

def:priv set_char(dict_: ptr[PyObject], key: str, byte: u8) -> bool {
    return set_owned(dict_, key, PyLong_FromLong(i64(char_value(int(byte)))));
}

def:priv fill_localeconv(result: ptr[PyObject], lc: ptr[lconv]) -> bool {
    # Monetary information: LC_MONETARY encoding
    if locale_decode_monetary(result, lc) < 0
        or not set_owned(
            result, "mon_grouping", copy_grouping(lc.view(1)[0].mon_grouping)
        )
        or not set_decoded(result, "positive_sign", lc.view(1)[0].positive_sign)
        or not set_decoded(result, "negative_sign", lc.view(1)[0].negative_sign)
        or not set_char(result, "int_frac_digits", lc.view(1)[0].int_frac_digits)
        or not set_char(result, "frac_digits", lc.view(1)[0].frac_digits)
        or not set_char(result, "p_cs_precedes", lc.view(1)[0].p_cs_precedes)
        or not set_char(result, "p_sep_by_space", lc.view(1)[0].p_sep_by_space)
        or not set_char(result, "n_cs_precedes", lc.view(1)[0].n_cs_precedes)
        or not set_char(result, "n_sep_by_space", lc.view(1)[0].n_sep_by_space)
        or not set_char(result, "p_sign_posn", lc.view(1)[0].p_sign_posn)
        or not set_char(result, "n_sign_posn", lc.view(1)[0].n_sign_posn) {
        return False;
    }
    # Numeric information: LC_NUMERIC encoding
    decimal_point: ptr[PyObject] = NULL;
    thousands_sep: ptr[PyObject] = NULL;
    if _Py_GetLocaleconvNumeric(lc, &mut decimal_point, &mut thousands_sep) < 0 {
        jacpy_release(decimal_point);
        jacpy_release(thousands_sep);
        return False;
    }
    if not set_owned(result, "decimal_point", decimal_point) {
        jacpy_release(thousands_sep);
        return False;
    }
    return set_owned(result, "thousands_sep", thousands_sep)
        and set_owned(result, "grouping", copy_grouping(lc.view(1)[0].grouping));
}

def _locale_localeconv_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    result = PyDict_New();
    if not result {
        return NULL;
    }
    # if LC_NUMERIC is different in the C library, use saved value
    lc = localeconv();
    if not fill_localeconv(result, lc) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def _locale_strcoll_impl(
    module: ptr[PyObject], os1: ptr[PyObject], os2: ptr[PyObject]
) -> ptr[PyObject] {
    result: ptr[PyObject] = NULL;
    # Convert the unicode strings to wchar[].
    ws1 = PyUnicode_AsWideCharString(os1, None);
    ws2 = ptr[i32]();
    if ws1 {
        ws2 = PyUnicode_AsWideCharString(os2, None);
        if ws2 {
            # Collate the strings.
            result = PyLong_FromLong(i64(wcscoll(ws1, ws2)));
        }
    }
    # Deallocate everything.
    PyMem_Free(ws1);
    PyMem_Free(ws2);
    return result;
}

"""Codes above 0xFFFF are not all code points, so each becomes the pair
0x1xxxx (the high 16 bits) and 0x0xxxx (the low 16 bits), which keeps the
order of the keys."""
def:priv transformed_key(buf: ptr[i32], n2: int) -> ptr[PyObject] {
    codes = buf.view(n2);
    n3 = 0;
    for i in range(n2) {
        if u32(codes[i]) > u32(0x10000) {
            n3 += 1;
        }
    }
    if n3 == 0 {
        return PyUnicode_FromKindAndData(i32(SIZEOF_WCHAR_T), buf, i64(n2));
    }
    n3 += n2;
    buf2 = ptr[u32](PyMem_Malloc(u64(n3) * u64(4)));
    if not buf2 {
        return PyErr_NoMemory();
    }
    out = buf2.view(n3);
    j = 0;
    for i in range(n2) {
        c = u32(codes[i]);
        if c > u32(0x10000) {
            out[j] = (c >> u32(16)) | u32(0x10000);
            out[j + 1] = c & u32(0xFFFF);
            j += 2;
        } else {
            out[j] = c;
            j += 1;
        }
    }
    result = PyUnicode_FromKindAndData(PyUnicode_4BYTE_KIND, buf2, i64(n3));
    PyMem_Free(buf2);
    return result;
}

def:priv strxfrm_of(s: ptr[i32], length: i64) -> ptr[PyObject] {
    if wcslen(s) != u64(length) {
        object_error(PyExc_ValueError, "embedded null character");
        return NULL;
    }
    # assume no change in size, first
    n1 = length + 1;
    # Yet another +1 is needed to work around a platform bug in wcsxfrm()
    # on macOS. See gh-130567.
    buf = ptr[i32](PyMem_Malloc(u64(n1 + 1) * u64(SIZEOF_WCHAR_T)));
    if not buf {
        return PyErr_NoMemory();
    }
    jacpy_clear_errno();
    n2 = wcsxfrm(buf, s, u64(n1));
    errno = jacpy_errno();
    if errno != 0 and errno != ERANGE {
        PyMem_Free(buf);
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    if n2 >= u64(n1) {
        # more space needed
        new_buf = ptr[i32](PyMem_Realloc(buf, (n2 + u64(1)) * u64(SIZEOF_WCHAR_T)));
        if not new_buf {
            PyMem_Free(buf);
            return PyErr_NoMemory();
        }
        buf = new_buf;
        jacpy_clear_errno();
        n2 = wcsxfrm(buf, s, n2 + u64(1));
        if jacpy_errno() != 0 {
            PyMem_Free(buf);
            return PyErr_SetFromErrno(PyExc_OSError);
        }
    }
    # The result is just a sequence of integers, they are not necessary
    # Unicode code points, so PyUnicode_FromWideChar() cannot be used here.
    result = transformed_key(buf, int(n2));
    PyMem_Free(buf);
    return result;
}

def _locale_strxfrm_impl(module: ptr[PyObject], str_: ptr[PyObject]) -> ptr[PyObject] {
    n1: i64 = 0;
    s = PyUnicode_AsWideCharString(str_, &mut n1);
    if not s {
        return NULL;
    }
    result = strxfrm_of(s, n1);
    PyMem_Free(s);
    return result;
}

"""change_locale(): make the LC_CTYPE locale temporarily the same as the locale
of category. Returns the status (-1 error, 0 unchanged, 1 changed) and a copy
of the previous LC_CTYPE locale to restore, NULL when unchanged."""
def:priv change_locale(category: i64) -> tuple[i32, ptr[u8]] {
    # Keep a copy of the LC_CTYPE locale
    oldloc = setlocale(i32(LC_CTYPE), ptr[u8]());
    if not oldloc {
        object_error(PyExc_RuntimeError, "failed to get LC_CTYPE locale");
        return (i32(-1), ptr[u8]());
    }
    oldloc = _PyMem_Strdup(oldloc);
    if not oldloc {
        PyErr_NoMemory();
        return (i32(-1), ptr[u8]());
    }
    # Set a new locale if it is different.
    loc = setlocale(i32(category), ptr[u8]());
    if not loc or strcmp(loc, oldloc) == 0 {
        PyMem_Free(oldloc);
        return (i32(0), ptr[u8]());
    }
    setlocale(i32(LC_CTYPE), loc);
    return (i32(1), oldloc);
}

"""restore_locale(): restore the old LC_CTYPE locale."""
def:priv restore_locale(oldloc: ptr[u8]) {
    if oldloc {
        setlocale(i32(LC_CTYPE), oldloc);
        PyMem_Free(oldloc);
    }
}

"""decode_strings(): glibc's NUL-separated list of at most max_count strings
as one string with semicolon-separated items, as POSIX specifies."""
def:priv decode_strings(result: ptr[u8], max_count: int) -> ptr[PyObject] {
    size = 0;
    count = 0;
    while count < max_count and byte_at(result, size) != 0 {
        size += int(strlen(result + size)) + 1;
        count += 1;
    }
    buf = ptr[u8](PyMem_Malloc(u64(size)));
    if not buf {
        return PyErr_NoMemory();
    }
    source = result.view(size);
    target = buf.view(size);
    for i in range(size) {
        target[i] = source[i];
    }
    # Replace all NULs but the last with semicolons.
    index = 0;
    count -= 1;
    while count > 0 {
        index += int(strlen(buf + index));
        target[index] = u8(59);
        index += 1;
        count -= 1;
    }
    pyresult = PyUnicode_DecodeLocale(buf, ptr[u8]());
    PyMem_Free(buf);
    return pyresult;
}

"""The category a langinfo constant belongs to, as CPython's table has it."""
def:priv langinfo_category(name: str) -> i64 {
    if name == "RADIXCHAR" or name == "THOUSEP" {
        return LC_NUMERIC;
    }
    if name == "CRNCYSTR" {
        return LC_MONETARY;
    }
    if name == "CODESET" {
        return LC_CTYPE;
    }
    if name == "YESEXPR" or name == "NOEXPR" {
        return LC_MESSAGES;
    }
    return LC_TIME;
}

def:priv langinfo_value(item: i32, category: i64) -> ptr[PyObject] {
    # Check NULL as a workaround for GNU libc's returning NULL instead of an
    # empty string for nl_langinfo(ERA).
    result = nl_langinfo(item);
    if not result or byte_at(result, 0) == 0 {
        return PyUnicode_FromString("");
    }
    oldloc = ptr[u8]();
    # gh-133740: glibc always changes the locale for ALT_DIGITS and ERA.
    if category != LC_CTYPE
        and (
            (GLIBC and (i64(item) == ALT_DIGITS or i64(item) == ERA))
            or not is_all_ascii(result)
        ) {
        (status, oldloc) = change_locale(category);
        if status < 0 {
            return NULL;
        }
    }
    pyresult: ptr[PyObject] = NULL;
    # According to the POSIX specification the result must be a sequence of
    # semicolon-separated strings. But in glibc they are NUL-separated.
    if GLIBC and i64(item) == ALT_DIGITS {
        pyresult = decode_strings(result, 100);
    } elif GLIBC and i64(item) == ERA {
        pyresult = decode_strings(result, 0x7FFFFFFFFFFFFFFF);
    } else {
        pyresult = PyUnicode_DecodeLocale(result, ptr[u8]());
    }
    restore_locale(oldloc);
    return pyresult;
}

def _locale_nl_langinfo_impl(module: ptr[PyObject], item: i32) -> ptr[PyObject] {
    # Check whether this is a supported constant. GNU libc sometimes returns
    # numeric values in the char* return value, which would crash
    # PyUnicode_FromString.
    for (name, value) in CONSTANTS {
        if value == i64(item) and not name.startswith("LC_") {
            return langinfo_value(item, langinfo_category(name));
        }
    }
    object_error(PyExc_ValueError, "unsupported langinfo constant");
    return NULL;
}

def _locale_gettext_impl(module: ptr[PyObject], in_: str) -> ptr[PyObject] {
    return PyUnicode_DecodeLocale(gettext(in_), ptr[u8]());
}

def _locale_dgettext_impl(
    module: ptr[PyObject], domain: ptr[u8], in_: str
) -> ptr[PyObject] {
    return PyUnicode_DecodeLocale(dgettext(domain, in_), ptr[u8]());
}

def _locale_dcgettext_impl(
    module: ptr[PyObject], domain: ptr[u8], msgid: str, category: i32
) -> ptr[PyObject] {
    return PyUnicode_DecodeLocale(dcgettext(domain, msgid, category), ptr[u8]());
}

def _locale_textdomain_impl(module: ptr[PyObject], domain: ptr[u8]) -> ptr[PyObject] {
    current = textdomain(domain);
    if not current {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return PyUnicode_DecodeLocale(current, ptr[u8]());
}

def _locale_bindtextdomain_impl(
    module: ptr[PyObject], domain: str, dirname_obj: ptr[PyObject]
) -> ptr[PyObject] {
    if not domain {
        locale_error(module, "domain must be a non-empty string");
        return NULL;
    }
    dirname_bytes: ptr[PyObject] = NULL;
    dirname = ptr[u8]();
    if dirname_obj != borrowed_none() {
        if PyUnicode_FSConverter(dirname_obj, &mut dirname_bytes) == 0 {
            return NULL;
        }
        dirname = PyBytes_AsString(dirname_bytes);
    }
    current_dirname = bindtextdomain(domain, dirname);
    if not current_dirname {
        PyErr_SetFromErrno(PyExc_OSError);
        jacpy_release(dirname_bytes);
        return NULL;
    }
    result = PyUnicode_DecodeLocale(current_dirname, ptr[u8]());
    jacpy_release(dirname_bytes);
    return result;
}

def _locale_bind_textdomain_codeset_impl(
    module: ptr[PyObject], domain: str, codeset: ptr[u8]
) -> ptr[PyObject] {
    current = bind_textdomain_codeset(domain, codeset);
    if current {
        return PyUnicode_DecodeLocale(current, ptr[u8]());
    }
    return Py_NewRef(borrowed_none());
}

def _locale_getencoding_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return _Py_GetLocaleEncodingObject();
}
