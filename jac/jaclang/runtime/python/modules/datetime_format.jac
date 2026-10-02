"""String format helpers and time module wrappers of the _datetime module.

Modules/_datetimemodule.c's ctime(), UTC offset and strftime() helpers in
native Jac. strftime() itself stays time.strftime(): the format is only
preprocessed here, giving %z, %:z, %Z and %f their datetime meanings and
padding four-digit years where the C library does not. See
../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    NULL,
    Py_None,
    PyErr_Occurred,
    PyErr_SetString,
    PyExc_TypeError,
    PyImport_ImportModuleAttrString,
    PyLong_AsLong,
    PyMem_Free,
    PyMem_Malloc,
    PyNumber_Long,
    PyObject,
    PyObject_CallFunction,
    PyObject_CallMethod,
    PyObject_CallNoArgs,
    PySequence_GetItem,
    PyUnicodeWriter,
    PyUnicodeWriter_Create,
    PyUnicodeWriter_Discard,
    PyUnicodeWriter_Finish,
    PyUnicodeWriter_WriteStr,
    PyUnicodeWriter_WriteSubstring,
    PyUnicode_FindChar,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    PyUnicode_GetLength,
    PyUnicode_ReadChar,
    PyUnicode_Substring,
    Py_NewRef,
    jacpy_is_unicode
}
import from jaclang.runtime.python.modules.time_records { tm }
import from jaclang.runtime.python.modules.datetime_calendar {
    days_before_month,
    weekday
}
import from jaclang.runtime.python.modules.datetime_objects {
    call_tzname,
    call_utcoffset,
    date_get_microsecond,
    datetime_check,
    delta_negative,
    get_day,
    get_month,
    get_tzinfo_member,
    get_year,
    td_days,
    td_microseconds,
    td_seconds,
    time_check,
    time_get_microsecond
}

import from c {
    def strftime(buffer: ptr[u8], size: u64, format: str, value: &tm) -> u64;
}

glob:priv DAY_NAMES: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
     MONTH_NAMES: list[str] = [
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ],
     # normalize_century()'s answer, computed once: -1 until then.
     CENTURY_CACHE: list[int] = [-1];

"""ctime() style text of a date or datetime at the given time of day."""
def format_ctime(
    date: ptr[PyObject], hours: int, minutes: int, seconds: int
) -> ptr[PyObject] {
    wday = weekday(get_year(date), get_month(date), get_day(date));
    return PyUnicode_FromFormat(
        "%s %s %2ld %02ld:%02ld:%02ld %04ld",
        DAY_NAMES[wday],
        MONTH_NAMES[get_month(date) - 1],
        get_day(date),
        hours,
        minutes,
        seconds,
        get_year(date)
    );
}

"""tzinfo.utcoffset(tzinfoarg) as `sign HH sep MM [sep SS [. UUUUUU]]`, the
empty string when it is None, or NULL with the error the offset check
raised."""
def format_utcoffset(
    sep: str, tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]
) -> ptr[PyObject] {
    offset = call_utcoffset(tzinfo, tzinfoarg);
    if not offset {
        return NULL;
    }
    if offset == Py_None {
        jacpy_release(offset);
        return PyUnicode_FromString("");
    }
    # Offset is normalized, so it is negative if days < 0
    sign = 43;
    if td_days(offset) < 0 {
        sign = 45;
        negated = delta_negative(offset);
        jacpy_release(offset);
        if not negated {
            return NULL;
        }
        offset = negated;
    }
    # Offset is not negative here.
    microseconds = td_microseconds(offset);
    seconds = td_seconds(offset);
    jacpy_release(offset);
    minutes = seconds // 60;
    seconds = seconds % 60;
    hours = minutes // 60;
    minutes = minutes % 60;
    if microseconds != 0 {
        return PyUnicode_FromFormat(
            "%c%02ld%s%02ld%s%02ld.%06ld",
            i32(sign),
            hours,
            sep,
            minutes,
            sep,
            seconds,
            microseconds
        );
    }
    if seconds != 0 {
        return PyUnicode_FromFormat(
            "%c%02ld%s%02ld%s%02ld", i32(sign), hours, sep, minutes, sep, seconds
        );
    }
    return PyUnicode_FromFormat("%c%02ld%s%02ld", i32(sign), hours, sep, minutes);
}

"""Whether the C library's strftime() writes a year below 1000 without
padding it to four digits, so %Y, %G, %F and %C need it done here."""
def normalize_century -> bool {
    if CENTURY_CACHE[0] < 0 {
        year = ptr[u8](PyMem_Malloc(5));
        answer = 0;
        if year {
            date = tm(tm_year=i32(-1801), tm_mon=i32(0), tm_mday=i32(1));
            written = strftime(year, 5, "%Y", &date);
            text = year.view(5);
            unpadded = not (
                text[0] == 48
                and text[1] == 48
                and text[2] == 57
                and text[3] == 57
                and text[4] == 0
            );
            answer = 1 if written != 0 and unpadded else 0;
            PyMem_Free(ptr(year));
        }
        CENTURY_CACHE[0] = answer;
    }
    return CENTURY_CACHE[0] == 1;
}

"""The %z (sep "") or %:z (sep ":") replacement for `object`."""
def make_somezreplacement(
    object: ptr[PyObject], sep: str, tzinfoarg: ptr[PyObject]
) -> ptr[PyObject] {
    tzinfo = get_tzinfo_member(object);
    if tzinfo == Py_None or not tzinfo {
        return PyUnicode_FromString("");
    }
    return format_utcoffset(sep, tzinfo, tzinfoarg);
}

"""The %Z replacement: the tzinfo's name with its % signs doubled."""
def make_Zreplacement(
    object: ptr[PyObject], tzinfoarg: ptr[PyObject]
) -> ptr[PyObject] {
    tzinfo = get_tzinfo_member(object);
    if tzinfo == Py_None or not tzinfo {
        return PyUnicode_FromString("");
    }
    temp = call_tzname(tzinfo, tzinfoarg);
    if not temp {
        return NULL;
    }
    if temp == Py_None {
        jacpy_release(temp);
        return PyUnicode_FromString("");
    }
    # Since the tzname is getting stuffed into the format, we have to double
    # any % signs so that strftime doesn't treat them as format codes.
    replacement = PyObject_CallMethod(temp, "replace", "ss", "%", "%%");
    jacpy_release(temp);
    if not replacement {
        return NULL;
    }
    if jacpy_is_unicode(replacement) == 0 {
        PyErr_SetString(PyExc_TypeError, "tzname.replace() did not return a string");
        jacpy_release(replacement);
        return NULL;
    }
    return replacement;
}

"""The %f replacement: the microseconds as six digits."""
def make_freplacement(object: ptr[PyObject]) -> ptr[PyObject] {
    microseconds = 0;
    if time_check(object) {
        microseconds = time_get_microsecond(object);
    } elif datetime_check(object) {
        microseconds = date_get_microsecond(object);
    }
    return PyUnicode_FromFormat("%06ld", microseconds);
}

"""The four-digit year text for a %Y, %G, %F or %C code when the year is
below 1000: NULL with no error when it needs no padding, NULL with an error
on failure."""
def padded_year(
    ch: int, timetuple: ptr[PyObject], strftime_function: ptr[PyObject]
) -> ptr[PyObject] {
    item = PySequence_GetItem(timetuple, 0);
    if not item {
        return NULL;
    }
    year = PyLong_AsLong(item);
    jacpy_release(item);
    if year == -1 and PyErr_Occurred() {
        return NULL;
    }
    # datetime(1000, 1, 1).strftime('%G') == '1000', so year 1000 for %G can
    # go on the fast path.
    if year >= 1000 {
        return NULL;
    }
    if ch == 71 {
        year_text = PyObject_CallFunction(strftime_function, "sO", "%G", timetuple);
        if not year_text {
            return NULL;
        }
        number = PyNumber_Long(year_text);
        jacpy_release(year_text);
        if not number {
            return NULL;
        }
        year = PyLong_AsLong(number);
        jacpy_release(number);
        if year == -1 and PyErr_Occurred() {
            return NULL;
        }
    }
    if ch == 70 {
        return PyUnicode_FromFormat("%04ld-%%m-%%d", year);
    }
    text = PyUnicode_FromFormat("%04ld", year);
    if not text or ch != 67 {
        return text;
    }
    century = PyUnicode_Substring(text, 0, PyUnicode_GetLength(text) - 2);
    jacpy_release(text);
    return century;
}

"""strftime() through time.strftime(), with %z, %:z, %Z and %f given their
datetime meanings by preprocessing the format. tzinfoarg is the argument
passed to the object's tzinfo methods."""
def wrap_strftime(
    object: ptr[PyObject],
    format: ptr[PyObject],
    timetuple: ptr[PyObject],
    tzinfoarg: ptr[PyObject]
) -> ptr[PyObject] {
    strftime_function = PyImport_ImportModuleAttrString("time", "strftime");
    if not strftime_function {
        return NULL;
    }
    replacements = StrftimeReplacements();
    result = rewrite_and_format(
        object, format, timetuple, tzinfoarg, strftime_function, replacements
    );
    jacpy_release(replacements.f);
    jacpy_release(replacements.z);
    jacpy_release(replacements.colon_z);
    jacpy_release(replacements.big_z);
    jacpy_release(strftime_function);
    return result;
}

"""The replacements wrap_strftime() computes at most once each."""
obj StrftimeReplacements {
    has z: ptr[PyObject] = NULL,
        colon_z: ptr[PyObject] = NULL,
        big_z: ptr[PyObject] = NULL,
        f: ptr[PyObject] = NULL;
}

# Scan the format for the escapes, building a new format, and call
# time.strftime() with it. Since computing the replacements is expensive,
# don't unless they're actually used.
def:priv rewrite_and_format(
    object: ptr[PyObject],
    format: ptr[PyObject],
    timetuple: ptr[PyObject],
    tzinfoarg: ptr[PyObject],
    strftime_function: ptr[PyObject],
    found: StrftimeReplacements
) -> ptr[PyObject] {
    writer = PyUnicodeWriter_Create(0);
    if not writer {
        return NULL;
    }
    flen = PyUnicode_GetLength(format);
    i: i64 = 0;
    start: i64 = 0;
    end: i64 = 0;
    while i != flen {
        i = PyUnicode_FindChar(format, u32(37), i, flen, i32(1));
        if i < 0 {
            break;
        }
        end = i;
        i += 1;
        if i == flen {
            break;
        }
        ch = int(PyUnicode_ReadChar(format, i));
        i += 1;
        # A % has been seen and ch is the character after it.
        replacement: ptr[PyObject] = NULL;
        if ch == 122 {
            # %z -> +HHMM
            if not found.z {
                found.z = make_somezreplacement(object, "", tzinfoarg);
                if not found.z {
                    PyUnicodeWriter_Discard(writer);
                    return NULL;
                }
            }
            replacement = found.z;
        } elif ch == 58 and i < flen and int(PyUnicode_ReadChar(format, i)) == 122 {
            # %:z -> +HH:MM
            i += 1;
            if not found.colon_z {
                found.colon_z = make_somezreplacement(object, ":", tzinfoarg);
                if not found.colon_z {
                    PyUnicodeWriter_Discard(writer);
                    return NULL;
                }
            }
            replacement = found.colon_z;
        } elif ch == 90 {
            # format tzname
            if not found.big_z {
                found.big_z = make_Zreplacement(object, tzinfoarg);
                if not found.big_z {
                    PyUnicodeWriter_Discard(writer);
                    return NULL;
                }
            }
            replacement = found.big_z;
        } elif ch == 102 {
            # format microseconds
            if not found.f {
                found.f = make_freplacement(object);
                if not found.f {
                    PyUnicodeWriter_Discard(writer);
                    return NULL;
                }
            }
            replacement = found.f;
        } elif normalize_century() and (ch == 89 or ch == 71 or ch == 70 or ch == 67) {
            # 0-pad year with century as necessary
            year = padded_year(ch, timetuple, strftime_function);
            if not year {
                if PyErr_Occurred() {
                    PyUnicodeWriter_Discard(writer);
                    return NULL;
                }
                continue;
            }
            written = PyUnicodeWriter_WriteSubstring(writer, format, start, end) >= 0
                and PyUnicodeWriter_WriteStr(writer, year) >= 0;
            jacpy_release(year);
            if not written {
                PyUnicodeWriter_Discard(writer);
                return NULL;
            }
            start = i;
            continue;
        } else {
            # percent followed by something else
            continue;
        }
        if PyUnicodeWriter_WriteSubstring(writer, format, start, end) < 0 {
            PyUnicodeWriter_Discard(writer);
            return NULL;
        }
        start = i;
        if PyUnicodeWriter_WriteStr(writer, replacement) < 0 {
            PyUnicodeWriter_Discard(writer);
            return NULL;
        }
    }
    newformat: ptr[PyObject] = NULL;
    if start == 0 {
        PyUnicodeWriter_Discard(writer);
        newformat = Py_NewRef(format);
    } else {
        if PyUnicodeWriter_WriteSubstring(writer, format, start, flen) < 0 {
            PyUnicodeWriter_Discard(writer);
            return NULL;
        }
        newformat = PyUnicodeWriter_Finish(writer);
        if not newformat {
            return NULL;
        }
    }
    result = PyObject_CallFunction(strftime_function, "OO", newformat, timetuple);
    jacpy_release(newformat);
    return result;
}

# ---------------------------------------------------------------------------
# Wrap functions from the time module.

"""time.time(), a Python float."""
def time_time -> ptr[PyObject] {
    function = PyImport_ImportModuleAttrString("time", "time");
    if not function {
        return NULL;
    }
    result = PyObject_CallNoArgs(function);
    jacpy_release(function);
    return result;
}

"""A time.struct_time; the weekday and day number are computed from the
year, month and day."""
def build_struct_time(
    y: int, m: int, d: int, hh: int, mm: int, ss: int, dstflag: int
) -> ptr[PyObject] {
    struct_time = PyImport_ImportModuleAttrString("time", "struct_time");
    if not struct_time {
        return NULL;
    }
    result = PyObject_CallFunction(
        struct_time,
        "((lllllllll))",
        y,
        m,
        d,
        hh,
        mm,
        ss,
        weekday(y, m, d),
        days_before_month(y, m) + d,
        dstflag
    );
    jacpy_release(struct_time);
    return result;
}
