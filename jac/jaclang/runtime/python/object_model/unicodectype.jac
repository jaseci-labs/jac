glob:priv ALPHA_MASK: u16 = 0x01,
     DECIMAL_MASK: u16 = 0x02,
     DIGIT_MASK: u16 = 0x04,
     LOWER_MASK: u16 = 0x08,
     TITLE_MASK: u16 = 0x40,
     UPPER_MASK: u16 = 0x80,
     XID_START_MASK: u16 = 0x100,
     XID_CONTINUE_MASK: u16 = 0x200,
     PRINTABLE_MASK: u16 = 0x400,
     NUMERIC_MASK: u16 = 0x800,
     CASE_IGNORABLE_MASK: u16 = 0x1000,
     CASED_MASK: u16 = 0x2000,
     EXTENDED_CASE_MASK: u16 = 0x4000;

def gettyperecord(code: u32) -> ptr[TypeRecord];

def add_delta(ch: u32, delta: i32) -> u32;

def extended_case(index: i64) -> u32;

def copy_extended(index: i64, n: i64, res: ptr[u32]);

def code_search(table: ptr[u32], length: i64, ch: u32) -> i64;

import from c {
    def _PyUnicode_ToTitlecase(ch: u32) -> u32 {
        ctype = gettyperecord(ch);
        if (ctype.view(1)[0].flags & EXTENDED_CASE_MASK) != 0 {
            return extended_case(i64(ctype.view(1)[0].title & 0xFFFF));
        }
        return add_delta(ch, ctype.view(1)[0].title);
    }  def _PyUnicode_IsTitlecase(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        return i32(1) if (ctype.view(1)[0].flags & TITLE_MASK) != 0 else i32(0);
    }  def _PyUnicode_IsXidStart(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        return i32(1) if (ctype.view(1)[0].flags & XID_START_MASK) != 0 else i32(0);
    }  def _PyUnicode_IsXidContinue(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        return i32(1) if (ctype.view(1)[0].flags & XID_CONTINUE_MASK) != 0 else i32(0);
    }  def _PyUnicode_ToDecimalDigit(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        if (ctype.view(1)[0].flags & DECIMAL_MASK) != 0 {
            return i32(ctype.view(1)[0].decimal);
        }
        return i32(-1);
    }  def _PyUnicode_IsDecimalDigit(ch: u32) -> i32 {
        if _PyUnicode_ToDecimalDigit(ch) < 0 {
            return i32(0);
        }
        return i32(1);
    }  def _PyUnicode_ToDigit(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        if (ctype.view(1)[0].flags & DIGIT_MASK) != 0 {
            return i32(ctype.view(1)[0].digit);
        }
        return i32(-1);
    }  def _PyUnicode_IsDigit(ch: u32) -> i32 {
        if _PyUnicode_ToDigit(ch) < 0 {
            return i32(0);
        }
        return i32(1);
    }  def _PyUnicode_IsNumeric(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        return i32(1) if (ctype.view(1)[0].flags & NUMERIC_MASK) != 0 else i32(0);
    }  def _PyUnicode_IsPrintable(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        return i32(1) if (ctype.view(1)[0].flags & PRINTABLE_MASK) != 0 else i32(0);
    }  def _PyUnicode_IsLowercase(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        return i32(1) if (ctype.view(1)[0].flags & LOWER_MASK) != 0 else i32(0);
    }  def _PyUnicode_IsUppercase(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        return i32(1) if (ctype.view(1)[0].flags & UPPER_MASK) != 0 else i32(0);
    }  def _PyUnicode_ToUppercase(ch: u32) -> u32 {
        ctype = gettyperecord(ch);
        if (ctype.view(1)[0].flags & EXTENDED_CASE_MASK) != 0 {
            return extended_case(i64(ctype.view(1)[0].upper & 0xFFFF));
        }
        return add_delta(ch, ctype.view(1)[0].upper);
    }  def _PyUnicode_ToLowercase(ch: u32) -> u32 {
        ctype = gettyperecord(ch);
        if (ctype.view(1)[0].flags & EXTENDED_CASE_MASK) != 0 {
            return extended_case(i64(ctype.view(1)[0].lower & 0xFFFF));
        }
        return add_delta(ch, ctype.view(1)[0].lower);
    }  def _PyUnicode_ToLowerFull(ch: u32, res: ptr[u32]) -> i32 {
        ctype = gettyperecord(ch);
        lower = ctype.view(1)[0].lower;
        if (ctype.view(1)[0].flags & EXTENDED_CASE_MASK) != 0 {
            n = i64(lower >> 24);
            copy_extended(i64(lower & 0xFFFF), n, res);
            return i32(n);
        }
        res.view(1)[0] = add_delta(ch, lower);
        return i32(1);
    }  def _PyUnicode_ToTitleFull(ch: u32, res: ptr[u32]) -> i32 {
        ctype = gettyperecord(ch);
        title = ctype.view(1)[0].title;
        if (ctype.view(1)[0].flags & EXTENDED_CASE_MASK) != 0 {
            n = i64(title >> 24);
            copy_extended(i64(title & 0xFFFF), n, res);
            return i32(n);
        }
        res.view(1)[0] = add_delta(ch, title);
        return i32(1);
    }  def _PyUnicode_ToUpperFull(ch: u32, res: ptr[u32]) -> i32 {
        ctype = gettyperecord(ch);
        upper = ctype.view(1)[0].upper;
        if (ctype.view(1)[0].flags & EXTENDED_CASE_MASK) != 0 {
            n = i64(upper >> 24);
            copy_extended(i64(upper & 0xFFFF), n, res);
            return i32(n);
        }
        res.view(1)[0] = add_delta(ch, upper);
        return i32(1);
    }  def _PyUnicode_ToFoldedFull(ch: u32, res: ptr[u32]) -> i32 {
        ctype = gettyperecord(ch);
        lower = ctype.view(1)[0].lower;
        if (ctype.view(1)[0].flags & EXTENDED_CASE_MASK) != 0
            and ((lower >> 20) & 7) != 0 {
            n = i64((lower >> 20) & 7);
            copy_extended(i64(lower & 0xFFFF) + i64(lower >> 24), n, res);
            return i32(n);
        }
        return _PyUnicode_ToLowerFull(ch, res);
    }  def _PyUnicode_IsCased(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        return i32(1) if (ctype.view(1)[0].flags & CASED_MASK) != 0 else i32(0);
    }  def _PyUnicode_IsCaseIgnorable(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        return i32(1)
            if (ctype.view(1)[0].flags & CASE_IGNORABLE_MASK) != 0
            else i32(0);
    }  def _PyUnicode_IsAlpha(ch: u32) -> i32 {
        ctype = gettyperecord(ch);
        return i32(1) if (ctype.view(1)[0].flags & ALPHA_MASK) != 0 else i32(0);
    }  def _PyUnicode_ToNumeric(ch: u32) -> f64 {
        i = code_search(addressof(uct_numeric_codes), NUMERIC_LENGTH, ch);
        if i < 0 {
            return -1.0;
        }
        value = i64((addressof(uct_numeric_value_index) + i).view(1)[0]);
        return (addressof(uct_numeric_values) + value).view(1)[0];
    }  def _PyUnicode_IsWhitespace(ch: u32) -> i32 {
        found = code_search(addressof(uct_whitespace), WHITESPACE_LENGTH, ch);
        return i32(1) if found >= 0 else i32(0);
    }  def _PyUnicode_IsLinebreak(ch: u32) -> i32 {
        found = code_search(addressof(uct_linebreak), LINEBREAK_LENGTH, ch);
        return i32(1) if found >= 0 else i32(0);
    }
}

impl gettyperecord(code: u32) -> ptr[TypeRecord] {
    index: i64 = 0;
    if code < u32(0x110000) {
        c = i64(code);
        index = i64((addressof(uct_index1) + (c >> SHIFT)).view(1)[0]);
        offset = (index << SHIFT) + (c & ((1 << SHIFT) - 1));
        index = i64((addressof(uct_index2) + offset).view(1)[0]);
    }
    return addressof(_PyUnicode_TypeRecords) + index;
}

impl add_delta(ch: u32, delta: i32) -> u32 {
    return u32.wrap(i64(ch) + i64(delta));
}

impl extended_case(index: i64) -> u32 {
    return (addressof(_PyUnicode_ExtendedCase) + index).view(1)[0];
}

impl copy_extended(index: i64, n: i64, res: ptr[u32]) {
    for i in range(n) {
        (res + i).view(1)[0] = extended_case(index + i);
    }
}

impl code_search(table: ptr[u32], length: i64, ch: u32) -> i64 {
    if length == 0 or ch < table.view(1)[0] or ch > (table + (length - 1)).view(1)[0] {
        return -1;
    }
    lo: i64 = 0;
    hi = length;
    while lo < hi {
        mid = (lo + hi) // 2;
        code = (table + mid).view(1)[0];
        if code < ch {
            lo = mid + 1;
        } elif code > ch {
            hi = mid;
        } else {
            return mid;
        }
    }
    return -1;
}
