import from c {
    def PyLong_FromString(s: ptr[u8], pend: ptr[ptr[u8]], base: i32) -> ptr[PyObject];
}

def write_ascii(writer: ptr[PyUnicodeWriter], text: str);

def write_char(writer: ptr[PyUnicodeWriter], character: int);

def hex_value(character: int) -> int;

def write_hex_escape(writer: ptr[PyUnicodeWriter], character: int);

def escape_string(writer: ptr[PyUnicodeWriter], source: ptr[PyObject], ascii: bool);

def:priv write_escaped(
    writer: ptr[PyUnicodeWriter], source: ptr[PyObject], ascii: bool
) -> i32;

def:priv escape_slow(
    writer: ptr[PyUnicodeWriter], source: ptr[PyObject], ascii: bool
) -> i32;

def:priv nan_failure(value: ptr[PyObject]);

def:pub jacpy_json_escape(source: ptr[PyObject], ascii: i64) -> ptr[PyObject];

def indexed(value: ptr[PyObject], position: i64) -> ptr[PyObject];

obj json_input {
    has source: ptr[PyObject],
        length: i64,
        position: i64,
        strict: bool,
        data: ptr = ptr(),
        kind: i64 = 0;

    def postinit;
    def character(index: i64) -> i64;
    def whitespace;
    def error(message: str, position: i64);
    def fail(message: str, position: i64) -> ptr[PyObject];
    def stop(position: i64) -> ptr[PyObject];
    def hex_escape(start: i64) -> i64;
    def string -> ptr[PyObject];
}

obj json_scan {
    has input: json_input,
        memo: ptr[PyObject],
        object_hook: ptr[PyObject],
        pairs_hook: ptr[PyObject],
        parse_float: ptr[PyObject],
        parse_int: ptr[PyObject],
        parse_constant: ptr[PyObject];

    def number -> ptr[PyObject];
    def constant(name: ptr[u8], size: i64) -> ptr[PyObject];
    def array -> ptr[PyObject];
    def object -> ptr[PyObject];
    def value -> ptr[PyObject];
}

def:priv input_matches_infinity(input: json_input, position: i64) -> bool;

def:priv new_writer_or_null -> ptr[PyUnicodeWriter];

def:pub jacpy_json_scanstring(
    source: ptr[PyObject], end: i64, strict: i64
) -> ptr[PyObject];

def:pub jacpy_json_scan(
    source: ptr[PyObject],
    start: i64,
    strict: i64,
    object_hook: ptr[PyObject],
    pairs_hook: ptr[PyObject],
    parse_float: ptr[PyObject],
    parse_int: ptr[PyObject],
    parse_constant: ptr[PyObject]
) -> ptr[PyObject];

import from jaclang.runtime.python.capi { type_name, repr_value, serialization_note }

def:priv encoding_failure(kind: ptr[PyObject], message: str) -> i32;

def:priv type_failure(prefix: str, value: ptr[PyObject], limit: int) -> i32;

obj json_output {
    has writer: ptr[PyUnicodeWriter],
        markers: ptr[PyObject],
        default_fn: ptr[PyObject],
        encoder: ptr[PyObject],
        indent: ptr[PyObject],
        key_separator: ptr[PyObject],
        item_separator: ptr[PyObject],
        sort_keys: bool,
        skipkeys: bool,
        allow_nan: bool,
        fast_encode: i64 = 0,
        indent_cache: list[ptr[PyObject]] = [];

    def initialize_indent(level: int);
    def close;
    def separator(level: int) -> ptr[PyObject];
    def newline(level: int) -> i32;
    def mark(value: ptr[PyObject]) -> ptr[PyObject];
    def float_text(value: ptr[PyObject]) -> ptr[PyObject];
    def string(value: ptr[PyObject]) -> i32;
    def encode(value: ptr[PyObject], level: int) -> i32;
    def fallback(value: ptr[PyObject], level: int) -> i32;
    def sequence(value: ptr[PyObject], level: int) -> i32;
    def key_value(
        dictionary: ptr[PyObject],
        key: ptr[PyObject],
        value: ptr[PyObject],
        level: int,
        separator: ptr[PyObject],
        first: bool
    ) -> i32;

    def dictionary(value: ptr[PyObject], level: int) -> i32;
}

def:pub jacpy_json_encode(
    value: ptr[PyObject], level: i64, settings: ptr[PyObject], flags: i64
) -> ptr[PyObject];

impl write_ascii(writer: ptr[PyUnicodeWriter], text: str) {
    checked(jacpy_unicode_writer_write_text(writer, text, i64(len(text))));
}

impl write_char(writer: ptr[PyUnicodeWriter], character: int) {
    checked(PyUnicodeWriter_WriteChar(writer, u32(character)));
}

impl hex_value(character: int) -> int {
    if 48 <= character <= 57 {
        return character - 48;
    }
    if 65 <= character <= 70 {
        return character - 55;
    }
    if 97 <= character <= 102 {
        return character - 87;
    }
    return -1;
}

impl write_hex_escape(writer: ptr[PyUnicodeWriter], character: int) {
    write_ascii(writer, "\\u");
    for shift in [12, 8, 4, 0] {
        digit = (character >> shift) & 15;
        write_char(writer, 48 + digit if digit < 10 else 87 + digit);
    }
}

impl escape_string(writer: ptr[PyUnicodeWriter], source: ptr[PyObject], ascii: bool) {
    write_char(writer, 34);
    for i in range(int(jacpy_unicode_size(source))) {
        character = int(PyUnicode_ReadChar(source, i64(i)));
        if character == 34 or character == 92 {
            write_char(writer, 92);
            write_char(writer, character);
        } elif character == 8 {
            write_ascii(writer, "\\b");
        } elif character == 9 {
            write_ascii(writer, "\\t");
        } elif character == 10 {
            write_ascii(writer, "\\n");
        } elif character == 12 {
            write_ascii(writer, "\\f");
        } elif character == 13 {
            write_ascii(writer, "\\r");
        } elif character < 32 or (ascii and character > 126) {
            if character > 65535 {
                write_hex_escape(writer, 0xd800 + ((character - 65536) >> 10));
                write_hex_escape(writer, 0xdc00 + ((character - 65536) & 1023));
            } else {
                write_hex_escape(writer, character);
            }
        } else {
            write_char(writer, character);
        }
    }
    write_char(writer, 34);
}

impl write_escaped(
    writer: ptr[PyUnicodeWriter], source: ptr[PyObject], ascii: bool
) -> i32 {
    size = jacpy_unicode_size(source);
    kind = jacpy_unicode_kind(source);
    data = jacpy_unicode_data(source);
    limit: u32 = u32(126) if ascii else u32(0x7FFFFFFF);
    i: i64 = 0;
    if kind == 1 {
        text = ptr[u8](data);
        while i < size {
            c = u32((text + i).view(1)[0]);
            if c < u32(32) or c == u32(34) or c == u32(92) or c > limit {
                break;
            }
            i += 1;
        }
    } elif kind == 2 {
        text2 = ptr[u16](data);
        while i < size {
            c = u32((text2 + i).view(1)[0]);
            if c < u32(32) or c == u32(34) or c == u32(92) or c > limit {
                break;
            }
            i += 1;
        }
    } else {
        text4 = ptr[u32](data);
        while i < size {
            c = (text4 + i).view(1)[0];
            if c < u32(32) or c == u32(34) or c == u32(92) or c > limit {
                break;
            }
            i += 1;
        }
    }
    if i == size {
        if PyUnicodeWriter_WriteChar(writer, u32(34)) < 0 {
            return i32(-1);
        }
        if PyUnicodeWriter_WriteStr(writer, source) < 0 {
            return i32(-1);
        }
        return PyUnicodeWriter_WriteChar(writer, u32(34));
    }
    return escape_slow(writer, source, ascii);
}

impl escape_slow(
    writer: ptr[PyUnicodeWriter], source: ptr[PyObject], ascii: bool
) -> i32 {
    try {
        escape_string(writer, source, ascii);
    } except boundary_failure {
        return i32(-1);
    }
    return i32(0);
}

impl jacpy_json_escape(source: ptr[PyObject], ascii: i64) -> ptr[PyObject] {
    writer = PyUnicodeWriter_Create(jacpy_unicode_size(source) + 2);
    if writer == 0 {
        return NULL;
    }
    if write_escaped(writer, source, ascii != 0) < 0 {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    return PyUnicodeWriter_Finish(writer);
}

impl indexed(value: ptr[PyObject], position: i64) -> ptr[PyObject] {
    if value == 0 {
        return NULL;
    }
    index = PyLong_FromLongLong(position);
    if index == 0 {
        jacpy_release(value);
        return NULL;
    }
    result = PyTuple_New(2);
    if result == 0 {
        jacpy_release(index);
        jacpy_release(value);
        return NULL;
    }
    jacpy_tuple_set_owned(result, 0, value);
    jacpy_tuple_set_owned(result, 1, index);
    return result;
}

impl json_input.postinit {
    self.data = jacpy_unicode_data(self.source);
    self.kind = jacpy_unicode_kind(self.source);
}

impl json_input.character(index: i64) -> i64 {
    if index < 0 or index >= self.length {
        return -1;
    }
    if self.kind == 1 {
        return i64((ptr[u8](self.data) + index).view(1)[0]);
    }
    if self.kind == 2 {
        return i64((ptr[u16](self.data) + index).view(1)[0]);
    }
    return i64((ptr[u32](self.data) + index).view(1)[0]);
}

impl json_input.whitespace {
    while True {
        character = self.character(self.position);
        if character != 32 and character != 9 and character != 10 and character != 13 {
            return;
        }
        self.position += 1;
    }
}

impl json_input.error(message: str, position: i64) {
    type = required(
        PyImport_ImportModuleAttrString(
            ptr[u8]("json.decoder"), ptr[u8]("JSONDecodeError")
        )
    );
    try {
        text = text_object(message);
        try {
            index = required(PyLong_FromLongLong(position));
            try {
                args = object_tuple([text, self.source, index]);
                try {
                    error = required(PyObject_Call(type, args, NULL));
                    try {
                        PyErr_SetObject(type, error);
                    } finally {
                        jacpy_release(error);
                    }
                } finally {
                    jacpy_release(args);
                }
            } finally {
                jacpy_release(index);
            }
        } finally {
            jacpy_release(text);
        }
    } finally {
        jacpy_release(type);
    }
    raise boundary_failure();
}

impl json_input.fail(message: str, position: i64) -> ptr[PyObject] {
    try {
        self.error(message, position);
    } except boundary_failure {}
    return NULL;
}

impl json_input.stop(position: i64) -> ptr[PyObject] {
    index = PyLong_FromLongLong(position);
    if index != 0 {
        PyErr_SetObject(PyExc_StopIteration, index);
        jacpy_release(index);
    }
    return NULL;
}

impl json_input.hex_escape(start: i64) -> i64 {
    if start + 4 >= self.length {
        return -1;
    }
    result: i64 = 0;
    i = start;
    while i < start + 4 {
        value = i64(hex_value(int(self.character(i))));
        if value < 0 {
            return -1;
        }
        result = (result << 4) | value;
        i += 1;
    }
    return result;
}

impl json_input.string -> ptr[PyObject] {
    begin = self.position - 1;
    start = self.position;

    while self.position < self.length {
        character = self.character(self.position);
        if character == 34 or character == 92 {
            break;
        }
        if character < 32 and self.strict {
            return self.fail("Invalid control character at", self.position);
        }
        self.position += 1;
    }
    if self.character(self.position) == 34 {
        result = PyUnicode_Substring(self.source, start, self.position);
        self.position += 1;
        return result;
    }
    self.position = start;
    writer = new_writer_or_null();
    if writer == 0 {
        return NULL;
    }
    while True {
        start = self.position;
        while self.position < self.length {
            character = self.character(self.position);
            if character == 34 or character == 92 {
                break;
            }
            if character < 32 and self.strict {
                PyUnicodeWriter_Discard(writer);
                return self.fail("Invalid control character at", self.position);
            }
            self.position += 1;
        }
        if self.position >= self.length {
            PyUnicodeWriter_Discard(writer);
            return self.fail("Unterminated string starting at", begin);
        }
        if PyUnicodeWriter_WriteSubstring(writer, self.source, start, self.position)
            < 0 {
            PyUnicodeWriter_Discard(writer);
            return NULL;
        }
        character = self.character(self.position);
        self.position += 1;
        if character == 34 {
            break;
        }
        character = self.character(self.position);
        if character < 0 {
            PyUnicodeWriter_Discard(writer);
            return self.fail("Unterminated string starting at", begin);
        }
        self.position += 1;
        if character == 117 {
            character = self.hex_escape(self.position);
            if character < 0 {
                PyUnicodeWriter_Discard(writer);
                return self.fail("Invalid \\uXXXX escape", self.position - 1);
            }
            self.position += 4;
            if 0xd800 <= character <= 0xdbff
                and self.position + 6 < self.length
                and self.character(self.position) == 92
                and self.character(self.position + 1) == 117 {
                second = self.hex_escape(self.position + 2);
                if second < 0 {
                    PyUnicodeWriter_Discard(writer);
                    return self.fail("Invalid \\uXXXX escape", self.position + 1);
                }
                if 0xdc00 <= second <= 0xdfff {
                    character = 65536 + ((character - 0xd800) << 10) + second - 0xdc00;
                    self.position += 6;
                }
            }
        } elif character == 98 {
            character = 8;
        } elif character == 102 {
            character = 12;
        } elif character == 110 {
            character = 10;
        } elif character == 114 {
            character = 13;
        } elif character == 116 {
            character = 9;
        } elif character != 34 and character != 92 and character != 47 {
            PyUnicodeWriter_Discard(writer);
            return self.fail("Invalid \\escape", self.position - 2);
        }
        if PyUnicodeWriter_WriteChar(writer, u32(character)) < 0 {
            PyUnicodeWriter_Discard(writer);
            return NULL;
        }
    }
    return PyUnicodeWriter_Finish(writer);
}

impl json_scan.number -> ptr[PyObject] {
    input = self.input;
    start = input.position;
    position = start;
    negative = input.character(position) == 45;
    if negative {
        position += 1;
    }
    character = input.character(position);
    if 49 <= character <= 57 {
        position += 1;
        while 48 <= input.character(position) <= 57 {
            position += 1;
        }
    } elif character == 48 {
        position += 1;
    } else {
        return input.stop(start);
    }
    floating = False;
    if input.character(position) == 46 and 48 <= input.character(position + 1) <= 57 {
        floating = True;
        position += 2;
        while 48 <= input.character(position) <= 57 {
            position += 1;
        }
    }
    character = input.character(position);
    if character == 69 or character == 101 {
        exponent = position;
        position += 1;
        character = input.character(position);
        if character == 43 or character == 45 {
            position += 1;
        }
        digits = position;
        while 48 <= input.character(position) <= 57 {
            position += 1;
        }
        if position == digits {
            position = exponent;
        } else {
            floating = True;
        }
    }
    input.position = position;
    custom = self.parse_float if floating else self.parse_int;
    builtin = ptr[PyObject](addressof(PyFloat_Type))
        if floating
        else ptr[PyObject](addressof(PyLong_Type));
    if custom != builtin {
        text = PyUnicode_Substring(input.source, start, position);
        if text == 0 {
            return NULL;
        }
        result = PyObject_CallOneArg(custom, text);
        jacpy_release(text);
        return result;
    }
    count = position - start;
    if not floating and count <= 18 {
        value: i64 = 0;
        i = start + 1 if negative else start;
        while i < position {
            value = value * 10 + (input.character(i) - 48);
            i += 1;
        }
        return PyLong_FromLongLong(-value if negative else value);
    }
    raw = PyBytes_FromStringAndSize(ptr[u8](), count);
    if raw == 0 {
        return NULL;
    }
    buffer = ptr[u8](PyBytes_AsString(raw));
    i = 0;
    while i < count {
        (buffer + i).view(1)[0] = u8(input.character(start + i));
        i += 1;
    }
    result = PyFloat_FromString(raw)
        if floating
        else PyLong_FromString(buffer, ptr[ptr[u8]](), i32(10));
    jacpy_release(raw);
    return result;
}

impl json_scan.constant(name: ptr[u8], size: i64) -> ptr[PyObject] {
    text = PyUnicode_FromString(name);
    if text == 0 {
        return NULL;
    }
    self.input.position += size;
    result = PyObject_CallOneArg(self.parse_constant, text);
    jacpy_release(text);
    return result;
}

impl json_scan.array -> ptr[PyObject] {
    input = self.input;
    result = jacpy_list_new();
    if result == 0 {
        return NULL;
    }
    input.position += 1;
    input.whitespace();
    if input.character(input.position) != 93 {
        while True {
            value = self.value();
            if value == 0 {
                jacpy_release(result);
                return NULL;
            }
            appended = PyList_Append(result, value);
            jacpy_release(value);
            if appended < 0 {
                jacpy_release(result);
                return NULL;
            }
            input.whitespace();
            character = input.character(input.position);
            if character == 93 {
                break;
            }
            if character != 44 {
                jacpy_release(result);
                return input.fail("Expecting ',' delimiter", input.position);
            }
            comma = input.position;
            input.position += 1;
            input.whitespace();
            if input.character(input.position) == 93 {
                jacpy_release(result);
                return input.fail("Illegal trailing comma before end of array", comma);
            }
        }
    }
    input.position += 1;
    return result;
}

impl json_scan.object -> ptr[PyObject] {
    input = self.input;
    pairs = self.pairs_hook != Py_None;
    result = jacpy_list_new() if pairs else PyDict_New();
    if result == 0 {
        return NULL;
    }
    input.position += 1;
    input.whitespace();
    if input.character(input.position) != 125 {
        while True {
            if input.character(input.position) != 34 {
                jacpy_release(result);
                return input.fail(
                    "Expecting property name enclosed in double quotes", input.position
                );
            }
            input.position += 1;
            original = input.string();
            if original == 0 {
                jacpy_release(result);
                return NULL;
            }
            key = jacpy_dict_default(self.memo, original, original);
            jacpy_release(original);
            if key == 0 {
                jacpy_release(result);
                return NULL;
            }
            input.whitespace();
            if input.character(input.position) != 58 {
                jacpy_release(key);
                jacpy_release(result);
                return input.fail("Expecting ':' delimiter", input.position);
            }
            input.position += 1;
            input.whitespace();
            value = self.value();
            if value == 0 {
                jacpy_release(key);
                jacpy_release(result);
                return NULL;
            }
            stored: i32 = 0;
            if pairs {
                item = PyTuple_New(2);
                if item == 0 {
                    stored = i32(-1);
                    jacpy_release(key);
                    jacpy_release(value);
                } else {
                    jacpy_tuple_set_owned(item, 0, key);
                    jacpy_tuple_set_owned(item, 1, value);
                    stored = PyList_Append(result, item);
                    jacpy_release(item);
                }
            } else {
                stored = PyDict_SetItem(result, key, value);
                jacpy_release(key);
                jacpy_release(value);
            }
            if stored < 0 {
                jacpy_release(result);
                return NULL;
            }
            input.whitespace();
            character = input.character(input.position);
            if character == 125 {
                break;
            }
            if character != 44 {
                jacpy_release(result);
                return input.fail("Expecting ',' delimiter", input.position);
            }
            comma = input.position;
            input.position += 1;
            input.whitespace();
            if input.character(input.position) == 125 {
                jacpy_release(result);
                return input.fail("Illegal trailing comma before end of object", comma);
            }
        }
    }
    input.position += 1;
    hook = self.pairs_hook if pairs else self.object_hook;
    if hook != Py_None {
        hooked = PyObject_CallOneArg(hook, result);
        jacpy_release(result);
        return hooked;
    }
    return result;
}

impl json_scan.value -> ptr[PyObject] {
    input = self.input;
    position = input.position;
    character = input.character(position);
    if character < 0 {
        return input.stop(position);
    }
    if character == 34 {
        input.position += 1;
        return input.string();
    }
    if character == 123 {
        if jacpy_recursion_enter(" while decoding a JSON object from a unicode string")
            != 0 {
            return NULL;
        }
        result = self.object();
        Py_LeaveRecursiveCall();
        return result;
    }
    if character == 91 {
        if jacpy_recursion_enter(" while decoding a JSON array from a unicode string")
            != 0 {
            return NULL;
        }
        result = self.array();
        Py_LeaveRecursiveCall();
        return result;
    }
    if character == 110
        and input.character(position + 1) == 117
        and input.character(position + 2) == 108
        and input.character(position + 3) == 108 {
        input.position += 4;
        return Py_NewRef(Py_None);
    }
    if character == 116
        and input.character(position + 1) == 114
        and input.character(position + 2) == 117
        and input.character(position + 3) == 101 {
        input.position += 4;
        return Py_NewRef(ptr[PyObject](addressof(_Py_TrueStruct)));
    }
    if character == 102
        and input.character(position + 1) == 97
        and input.character(position + 2) == 108
        and input.character(position + 3) == 115
        and input.character(position + 4) == 101 {
        input.position += 5;
        return Py_NewRef(ptr[PyObject](addressof(_Py_FalseStruct)));
    }
    if character == 78
        and input.character(position + 1) == 97
        and input.character(position + 2) == 78 {
        return self.constant(ptr[u8]("NaN"), 3);
    }
    if character == 73 and input_matches_infinity(input, position) {
        return self.constant(ptr[u8]("Infinity"), 8);
    }
    if character == 45
        and input.character(position + 1) == 73
        and input_matches_infinity(input, position + 1) {
        return self.constant(ptr[u8]("-Infinity"), 9);
    }
    return self.number();
}

impl input_matches_infinity(input: json_input, position: i64) -> bool {
    word = "Infinity";
    for i in range(8) {
        if input.character(position + i64(i)) != i64(ord(word[i])) {
            return False;
        }
    }
    return True;
}

impl new_writer_or_null -> ptr[PyUnicodeWriter] {
    return PyUnicodeWriter_Create(0);
}

impl jacpy_json_scanstring(
    source: ptr[PyObject], end: i64, strict: i64
) -> ptr[PyObject] {
    size = jacpy_unicode_size(source);
    if end < 0 or end > size {
        object_error(PyExc_ValueError, "end is out of bounds");
        return NULL;
    }
    input = json_input(source, size, end, strict != 0);
    value = input.string();
    return indexed(value, input.position);
}

impl jacpy_json_scan(
    source: ptr[PyObject],
    start: i64,
    strict: i64,
    object_hook: ptr[PyObject],
    pairs_hook: ptr[PyObject],
    parse_float: ptr[PyObject],
    parse_int: ptr[PyObject],
    parse_constant: ptr[PyObject]
) -> ptr[PyObject] {
    if start < 0 {
        object_error(PyExc_ValueError, "idx cannot be negative");
        return NULL;
    }
    input = json_input(source, jacpy_unicode_size(source), start, strict != 0);
    memo = PyDict_New();
    if memo == 0 {
        return NULL;
    }
    scanner = json_scan(
        input, memo, object_hook, pairs_hook, parse_float, parse_int, parse_constant
    );
    value = scanner.value();
    jacpy_release(memo);
    return indexed(value, input.position);
}

impl encoding_failure(kind: ptr[PyObject], message: str) -> i32 {
    object_error(kind, message);
    return i32(-1);
}

impl nan_failure(value: ptr[PyObject]) {
    try {
        object_error(
            PyExc_ValueError,
            "Out of range float values are not JSON compliant: " + repr_value(value)
        );
    } except boundary_failure {}
}

impl type_failure(prefix: str, value: ptr[PyObject], limit: int) -> i32 {
    try {
        object_error(PyExc_TypeError, prefix + type_name(value)[:limit]);
    } except boundary_failure {}
    return i32(-1);
}

impl json_output.initialize_indent(level: int) {
    if self.indent == Py_None {
        return;
    }
    newline = text_object("\n");
    try {
        if level != 0 {
            repeated = required(PySequence_Repeat(self.indent, i64(level)));
            try {
                joined = required(PyUnicode_Concat(newline, repeated));
                jacpy_release(newline);
                newline = joined;
            } finally {
                jacpy_release(repeated);
            }
        }
        self.indent_cache.append(Py_NewRef(newline));
    } finally {
        jacpy_release(newline);
    }
}

impl json_output.close {
    for item in self.indent_cache {
        jacpy_release(item);
    }
    self.indent_cache.clear();
}

impl json_output.separator(level: int) -> ptr[PyObject] {
    if len(self.indent_cache) == 0 {
        return self.item_separator;
    }
    if level * 2 >= len(self.indent_cache) {
        newline = PyUnicode_Concat(self.indent_cache[(level - 1) * 2], self.indent);
        if newline == 0 {
            return NULL;
        }
        separator = PyUnicode_Concat(self.item_separator, newline);
        if separator == 0 {
            jacpy_release(newline);
            return NULL;
        }
        self.indent_cache.append(separator);
        self.indent_cache.append(newline);
    }
    return self.indent_cache[level * 2 - 1];
}

impl json_output.newline(level: int) -> i32 {
    return PyUnicodeWriter_WriteStr(self.writer, self.indent_cache[level * 2]);
}

impl json_output.mark(value: ptr[PyObject]) -> ptr[PyObject] {
    identity = PyLong_FromVoidPtr(value);
    if identity == 0 {
        return NULL;
    }
    found = PyDict_Contains(self.markers, identity);
    if found != 0 {
        if found > 0 {
            object_error(PyExc_ValueError, "Circular reference detected");
        }
        jacpy_release(identity);
        return NULL;
    }
    if PyDict_SetItem(self.markers, identity, value) < 0 {
        jacpy_release(identity);
        return NULL;
    }
    return identity;
}

impl json_output.float_text(value: ptr[PyObject]) -> ptr[PyObject] {
    number = jacpy_float_value(value);
    if number != number
        or number > 1.7976931348623157e308
        or number < -1.7976931348623157e308 {
        if not self.allow_nan {
            nan_failure(value);
            return NULL;
        }
        if number > 0 {
            return PyUnicode_FromString(ptr[u8]("Infinity"));
        }
        if number < 0 {
            return PyUnicode_FromString(ptr[u8]("-Infinity"));
        }
        return PyUnicode_FromString(ptr[u8]("NaN"));
    }
    return jacpy_float_repr(value);
}

impl json_output.string(value: ptr[PyObject]) -> i32 {
    if self.fast_encode != 0 {
        return write_escaped(self.writer, value, self.fast_encode == 2);
    }
    encoded = PyObject_CallOneArg(self.encoder, value);
    if encoded == 0 {
        return i32(-1);
    }
    status: i32 = 0;
    if jacpy_is_unicode(encoded) == 0 {
        status = type_failure("encoder() must return a string, not ", encoded, 80);
    } else {
        status = PyUnicodeWriter_WriteStr(self.writer, encoded);
    }
    jacpy_release(encoded);
    return status;
}

impl json_output.encode(value: ptr[PyObject], level: int) -> i32 {
    if value == Py_None {
        return PyUnicodeWriter_WriteASCII(self.writer, ptr[u8]("null"), 4);
    }
    if value == ptr[PyObject](addressof(_Py_TrueStruct)) {
        return PyUnicodeWriter_WriteASCII(self.writer, ptr[u8]("true"), 4);
    }
    if value == ptr[PyObject](addressof(_Py_FalseStruct)) {
        return PyUnicodeWriter_WriteASCII(self.writer, ptr[u8]("false"), 5);
    }
    if jacpy_is_unicode(value) != 0 {
        return self.string(value);
    }
    if jacpy_is_long(value) != 0 {
        text = jacpy_long_repr(value);
        if text == 0 {
            return i32(-1);
        }
        status = PyUnicodeWriter_WriteStr(self.writer, text);
        jacpy_release(text);
        return status;
    }
    if jacpy_is_float(value) != 0 {
        text = self.float_text(value);
        if text == 0 {
            return i32(-1);
        }
        status = PyUnicodeWriter_WriteStr(self.writer, text);
        jacpy_release(text);
        return status;
    }
    if jacpy_is_list(value) != 0 or jacpy_is_tuple(value) != 0 {
        if jacpy_recursion_enter(" while encoding a JSON object") != 0 {
            return i32(-1);
        }
        status = self.sequence(value, level);
        Py_LeaveRecursiveCall();
        return status;
    }
    if jacpy_is_dict(value) != 0 {
        if jacpy_recursion_enter(" while encoding a JSON object") != 0 {
            return i32(-1);
        }
        status = self.dictionary(value, level);
        Py_LeaveRecursiveCall();
        return status;
    }
    return self.fallback(value, level);
}

impl json_output.fallback(value: ptr[PyObject], level: int) -> i32 {
    identity: ptr[PyObject] = NULL;
    if self.markers != Py_None {
        identity = self.mark(value);
        if identity == 0 {
            return i32(-1);
        }
    }
    replacement = PyObject_CallOneArg(self.default_fn, value);
    if replacement == 0 {
        jacpy_release(identity);
        return i32(-1);
    }
    if jacpy_recursion_enter(" while encoding a JSON object") != 0 {
        jacpy_release(replacement);
        jacpy_release(identity);
        return i32(-1);
    }
    status = self.encode(replacement, level);
    Py_LeaveRecursiveCall();
    jacpy_release(replacement);
    if status < 0 {
        serialization_note(value, NULL, 0, 0);
        jacpy_release(identity);
        return i32(-1);
    }
    if identity != 0 {
        status = PyDict_DelItem(self.markers, identity);
        jacpy_release(identity);
    }
    return status;
}

impl json_output.sequence(value: ptr[PyObject], level: int) -> i32 {
    sequence = PySequence_Fast(value, ptr[u8]("_iterencode_list needs a sequence"));
    if sequence == 0 {
        return i32(-1);
    }
    size = jacpy_fast_size(sequence);
    if size == 0 {
        jacpy_release(sequence);
        return PyUnicodeWriter_WriteASCII(self.writer, ptr[u8]("[]"), 2);
    }
    identity: ptr[PyObject] = NULL;
    if self.markers != Py_None {
        identity = self.mark(value);
        if identity == 0 {
            jacpy_release(sequence);
            return i32(-1);
        }
    }
    status = PyUnicodeWriter_WriteChar(self.writer, u32(91));
    indented = len(self.indent_cache) != 0;
    if indented {
        level += 1;
    }
    separator = self.separator(level);
    if separator == 0 {
        status = i32(-1);
    }
    if status >= 0 and indented {
        status = self.newline(level);
    }
    i: i64 = 0;
    while status >= 0 and i < jacpy_fast_size(sequence) {
        item = jacpy_fast_item(sequence, i);
        if item == 0 {
            status = i32(-1);
            break;
        }
        if i != 0 {
            status = PyUnicodeWriter_WriteStr(self.writer, separator);
        }
        if status >= 0 {
            status = self.encode(item, level);
            if status < 0 {
                serialization_note(value, NULL, int(i), 1);
            }
        }
        jacpy_release(item);
        i += 1;
    }
    if status >= 0 and identity != 0 {
        status = PyDict_DelItem(self.markers, identity);
    }
    if status >= 0 and indented {
        status = self.newline(level - 1);
    }
    if status >= 0 {
        status = PyUnicodeWriter_WriteChar(self.writer, u32(93));
    }
    jacpy_release(identity);
    jacpy_release(sequence);
    return status;
}

impl json_output.key_value(
    dictionary: ptr[PyObject],
    key: ptr[PyObject],
    value: ptr[PyObject],
    level: int,
    separator: ptr[PyObject],
    first: bool
) -> i32 {
    text: ptr[PyObject] = NULL;
    if jacpy_is_unicode(key) != 0 {
        text = Py_NewRef(key);
    } elif jacpy_is_float(key) != 0 {
        text = self.float_text(key);
    } elif key == Py_None {
        text = PyUnicode_FromString(ptr[u8]("null"));
    } elif key == ptr[PyObject](addressof(_Py_TrueStruct)) {
        text = PyUnicode_FromString(ptr[u8]("true"));
    } elif key == ptr[PyObject](addressof(_Py_FalseStruct)) {
        text = PyUnicode_FromString(ptr[u8]("false"));
    } elif jacpy_is_long(key) != 0 {
        text = jacpy_long_repr(key);
    } elif self.skipkeys {
        return i32(1);
    } else {
        return type_failure(
            "keys must be str, int, float, bool or None, not ", key, 100
        );
    }
    if text == 0 {
        return i32(-1);
    }
    status: i32 = 0;
    if first {
        if len(self.indent_cache) != 0 {
            status = self.newline(level);
        }
    } else {
        status = PyUnicodeWriter_WriteStr(self.writer, separator);
    }
    if status >= 0 {
        status = self.string(text);
    }
    jacpy_release(text);
    if status >= 0 {
        status = PyUnicodeWriter_WriteStr(self.writer, self.key_separator);
    }
    if status < 0 {
        return i32(-1);
    }
    if self.encode(value, level) < 0 {
        serialization_note(dictionary, key, 0, 2);
        return i32(-1);
    }
    return i32(0);
}

impl json_output.dictionary(value: ptr[PyObject], level: int) -> i32 {
    if jacpy_dict_size(value) == 0 {
        return PyUnicodeWriter_WriteASCII(self.writer, ptr[u8]("{}"), 2);
    }
    identity: ptr[PyObject] = NULL;
    if self.markers != Py_None {
        identity = self.mark(value);
        if identity == 0 {
            return i32(-1);
        }
    }
    status = PyUnicodeWriter_WriteChar(self.writer, u32(123));
    indented = len(self.indent_cache) != 0;
    if indented {
        level += 1;
    }
    separator = self.separator(level);
    if separator == 0 {
        status = i32(-1);
    }
    first = True;
    if status < 0 {
        jacpy_release(identity);
        return i32(-1);
    }
    if self.sort_keys or jacpy_is_exact_dict(value) == 0 {
        items = PyMapping_Items(value);
        if items == 0 or (self.sort_keys and PyList_Sort(items) < 0) {
            jacpy_release(items);
            jacpy_release(identity);
            return i32(-1);
        }
        i: i64 = 0;
        while i < jacpy_list_size(items) {
            item = PyList_GetItemRef(items, i);
            if item == 0 {
                status = i32(-1);
                break;
            }
            if jacpy_is_tuple(item) == 0 or PyTuple_Size(item) != 2 {
                jacpy_release(item);
                status = encoding_failure(
                    PyExc_ValueError, "items must return 2-tuples"
                );
                break;
            }
            key = jacpy_tuple_item(item, 0);
            child = jacpy_tuple_item(item, 1);
            jacpy_release(item);
            if key == 0 or child == 0 {
                jacpy_release(key);
                jacpy_release(child);
                status = i32(-1);
                break;
            }
            written = self.key_value(value, key, child, level, separator, first);
            jacpy_release(child);
            jacpy_release(key);
            if written < 0 {
                status = i32(-1);
                break;
            }
            if written == 0 {
                first = False;
            }
            i += 1;
        }
        jacpy_release(items);
    } else {
        position: i64 = 0;
        entry_key: ptr[PyObject] = NULL;
        entry_value: ptr[PyObject] = NULL;
        while PyDict_Next(value, &mut position, &mut entry_key, &mut entry_value)
            != 0 {
            key = Py_NewRef(entry_key);
            child = Py_NewRef(entry_value);
            written = self.key_value(value, key, child, level, separator, first);
            jacpy_release(child);
            jacpy_release(key);
            if written < 0 {
                status = i32(-1);
                break;
            }
            if written == 0 {
                first = False;
            }
        }
    }
    if status >= 0 and identity != 0 {
        status = PyDict_DelItem(self.markers, identity);
    }
    if status >= 0 and indented and not first {
        status = self.newline(level - 1);
    }
    if status >= 0 {
        status = PyUnicodeWriter_WriteChar(self.writer, u32(125));
    }
    jacpy_release(identity);
    return status;
}

impl jacpy_json_encode(
    value: ptr[PyObject], level: i64, settings: ptr[PyObject], flags: i64
) -> ptr[PyObject] {
    options: list[ptr[PyObject]] = [];
    writer = ptr[PyUnicodeWriter]();
    try {
        for i in range(6) {
            options.append(required(jacpy_tuple_item(settings, i64(i))));
        }
        writer = new_writer();
        output = json_output(
            writer,
            options[0],
            options[1],
            options[2],
            options[3],
            options[4],
            options[5],
            (flags & 1) != 0,
            (flags & 2) != 0,
            (flags & 4) != 0,
            (flags >> 3) & 3
        );
        try {
            output.initialize_indent(int(level));
            checked(output.encode(value, 0));
        } finally {
            output.close();
        }
        text = PyUnicodeWriter_Finish(writer);
        writer = ptr[PyUnicodeWriter]();
        text = required(text);
        try {
            return object_tuple([text]);
        } finally {
            jacpy_release(text);
        }
    } except boundary_failure {
        return NULL;
    } finally {
        if writer != 0 {
            PyUnicodeWriter_Discard(writer);
        }
        for option in options {
            jacpy_release(option);
        }
    }
}
