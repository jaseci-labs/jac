def write_ascii(writer: ptr[PyUnicodeWriter], text: str);

def write_char(writer: ptr[PyUnicodeWriter], character: int);

def hex_value(character: int) -> int;

def write_hex_escape(writer: ptr[PyUnicodeWriter], character: int);

def escape_string(writer: ptr[PyUnicodeWriter], source: ptr[PyObject], ascii: bool);

def:pub jacpy_json_escape(source: ptr[PyObject], ascii: i64) -> ptr[PyObject];

def indexed(value: ptr[PyObject], position: int) -> ptr[PyObject];

obj json_input {
    has source: ptr[PyObject],
        length: int,
        position: int,
        strict: bool,
        data: ptr = ptr(),
        kind: i64 = 0;

    def postinit;
    def character(index: int) -> int;
    def whitespace;
    def error(message: str, position: int);
    def stop(position: int);
    def hex_escape(start: int) -> int;
    def string -> ptr[PyObject];
    def matches(text: str) -> bool;
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
    def array -> ptr[PyObject];
    def object -> ptr[PyObject];
    def value -> ptr[PyObject];
}

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

def encoding_error(kind: ptr[PyObject], message: str);

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
        indent_cache: list[ptr[PyObject]] = [];

    def initialize_indent(level: int);
    def close;
    def separator(level: int) -> ptr[PyObject];
    def newline(level: int);
    def mark(value: ptr[PyObject]) -> ptr[PyObject];
    def unmark(identity: ptr[PyObject]);
    def float_text(value: ptr[PyObject]) -> ptr[PyObject];
    def string(value: ptr[PyObject]);
    def encode(value: ptr[PyObject], level: int);
    def sequence(value: ptr[PyObject], level: int);
    def key_value(
        dictionary: ptr[PyObject],
        key: ptr[PyObject],
        value: ptr[PyObject],
        level: int,
        separator: ptr[PyObject],
        first: bool
    ) -> bool;

    def dictionary(value: ptr[PyObject], level: int);
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

impl jacpy_json_escape(source: ptr[PyObject], ascii: i64) -> ptr[PyObject] {
    writer = ptr[PyUnicodeWriter]();
    try {
        writer = new_writer();
        escape_string(writer, source, ascii != 0);
        result = PyUnicodeWriter_Finish(writer);
        writer = ptr[PyUnicodeWriter]();
        return result;
    } except boundary_failure {
        return NULL;
    } finally {
        if writer != 0 {
            PyUnicodeWriter_Discard(writer);
        }
    }
}

impl indexed(value: ptr[PyObject], position: int) -> ptr[PyObject] {
    try {
        index = required(PyLong_FromLongLong(i64(position)));
        try {
            return pair(value, index);
        } finally {
            jacpy_release(index);
        }
    } finally {
        jacpy_release(value);
    }
}

impl json_input.postinit {
    self.data = jacpy_unicode_data(self.source);
    self.kind = jacpy_unicode_kind(self.source);
}

impl json_input.character(index: int) -> int {
    if index < 0 or index >= self.length {
        return -1;
    }
    if self.kind == 1 {
        return int((ptr[u8](int(self.data)) + index).view(1)[0]);
    }
    if self.kind == 2 {
        return int((ptr[u16](int(self.data)) + index).view(1)[0]);
    }
    return int((ptr[u32](int(self.data)) + index).view(1)[0]);
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

impl json_input.error(message: str, position: int) {
    type = required(PyImport_ImportModuleAttrString("json.decoder", "JSONDecodeError"));
    try {
        text = text_object(message);
        try {
            index = required(PyLong_FromLongLong(i64(position)));
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

impl json_input.stop(position: int) {
    index = required(PyLong_FromLongLong(i64(position)));
    try {
        PyErr_SetObject(PyExc_StopIteration, index);
    } finally {
        jacpy_release(index);
    }
    raise boundary_failure();
}

impl json_input.hex_escape(start: int) -> int {
    if start + 4 >= self.length {
        self.error("Invalid \\uXXXX escape", start - 1);
    }
    result = 0;
    for i in range(start, start + 4) {
        value = hex_value(self.character(i));
        if value < 0 {
            self.error("Invalid \\uXXXX escape", start - 1);
        }
        result = (result << 4) | value;
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
            self.error("Invalid control character at", self.position);
        }
        self.position += 1;
    }
    if self.character(self.position) == 34 {
        result = required(
            PyUnicode_Substring(self.source, i64(start), i64(self.position))
        );
        self.position += 1;
        return result;
    }
    self.position = start;
    writer = new_writer();
    try {
        while True {
            start = self.position;
            while self.position < self.length {
                character = self.character(self.position);
                if character == 34 or character == 92 {
                    break;
                }
                if character < 32 and self.strict {
                    self.error("Invalid control character at", self.position);
                }
                self.position += 1;
            }
            if self.position >= self.length {
                self.error("Unterminated string starting at", begin);
            }
            checked(
                PyUnicodeWriter_WriteSubstring(
                    writer, self.source, i64(start), i64(self.position)
                )
            );
            character = self.character(self.position);
            self.position += 1;
            if character == 34 {
                break;
            }
            character = self.character(self.position);
            if character < 0 {
                self.error("Unterminated string starting at", begin);
            }
            self.position += 1;
            if character == 117 {
                character = self.hex_escape(self.position);
                self.position += 4;
                if 0xd800 <= character <= 0xdbff
                    and self.position + 6 < self.length
                    and self.character(self.position) == 92
                    and self.character(self.position + 1) == 117 {
                    second = self.hex_escape(self.position + 2);
                    if 0xdc00 <= second <= 0xdfff {
                        character = 65536 + ((character - 0xd800) << 10) + second
                            - 0xdc00;
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
                self.error("Invalid \\escape", self.position - 2);
            }
            write_char(writer, character);
        }
        result = PyUnicodeWriter_Finish(writer);
        writer = ptr[PyUnicodeWriter]();
        return required(result);
    } finally {
        if writer != 0 {
            PyUnicodeWriter_Discard(writer);
        }
    }
}

impl json_input.matches(text: str) -> bool {
    for i in range(len(text)) {
        if self.character(self.position + i) != ord(text[i]) {
            return False;
        }
    }
    return True;
}

impl json_scan.number -> ptr[PyObject] {
    start = self.input.position;
    if self.input.character(self.input.position) == 45 {
        self.input.position += 1;
    }
    character = self.input.character(self.input.position);
    if 49 <= character <= 57 {
        self.input.position += 1;
        while 48 <= self.input.character(self.input.position) <= 57 {
            self.input.position += 1;
        }
    } elif character == 48 {
        self.input.position += 1;
    } else {
        self.input.stop(start);
    }
    floating = False;
    if self.input.character(self.input.position) == 46
        and 48 <= self.input.character(self.input.position + 1) <= 57 {
        floating = True;
        self.input.position += 2;
        while 48 <= self.input.character(self.input.position) <= 57 {
            self.input.position += 1;
        }
    }
    if self.input.character(self.input.position) in [69, 101] {
        exponent = self.input.position;
        self.input.position += 1;
        if self.input.character(self.input.position) in [43, 45] {
            self.input.position += 1;
        }
        digits = self.input.position;
        while 48 <= self.input.character(self.input.position) <= 57 {
            self.input.position += 1;
        }
        if self.input.position == digits {
            self.input.position = exponent;
        } else {
            floating = True;
        }
    }
    text = required(
        PyUnicode_Substring(self.input.source, i64(start), i64(self.input.position))
    );
    try {
        return required(
            PyObject_CallOneArg(self.parse_float if floating else self.parse_int, text)
        );
    } finally {
        jacpy_release(text);
    }
}

impl json_scan.array -> ptr[PyObject] {
    result = required(jacpy_list_new());
    try {
        self.input.position += 1;
        self.input.whitespace();
        if self.input.character(self.input.position) != 93 {
            while True {
                value = self.value();
                try {
                    checked(PyList_Append(result, value));
                } finally {
                    jacpy_release(value);
                }
                self.input.whitespace();
                if self.input.character(self.input.position) == 93 {
                    break;
                }
                if self.input.character(self.input.position) != 44 {
                    self.input.error("Expecting ',' delimiter", self.input.position);
                }
                comma = self.input.position;
                self.input.position += 1;
                self.input.whitespace();
                if self.input.character(self.input.position) == 93 {
                    self.input.error(
                        "Illegal trailing comma before end of array", comma
                    );
                }
            }
        }
        self.input.position += 1;
        return result;
    } except boundary_failure {
        jacpy_release(result);
        raise;
    }
}

impl json_scan.object -> ptr[PyObject] {
    pairs = self.pairs_hook != Py_None;
    result = required(jacpy_list_new() if pairs else PyDict_New());
    try {
        self.input.position += 1;
        self.input.whitespace();
        if self.input.character(self.input.position) != 125 {
            while True {
                if self.input.character(self.input.position) != 34 {
                    self.input.error(
                        "Expecting property name enclosed in double quotes",
                        self.input.position
                    );
                }
                self.input.position += 1;
                original = self.input.string();
                key: ptr[PyObject] = NULL;
                try {
                    key = required(jacpy_dict_default(self.memo, original, original));
                } finally {
                    jacpy_release(original);
                }
                try {
                    self.input.whitespace();
                    if self.input.character(self.input.position) != 58 {
                        self.input.error(
                            "Expecting ':' delimiter", self.input.position
                        );
                    }
                    self.input.position += 1;
                    self.input.whitespace();
                    value = self.value();
                    try {
                        if pairs {
                            item = pair(key, value);
                            try {
                                checked(PyList_Append(result, item));
                            } finally {
                                jacpy_release(item);
                            }
                        } else {
                            checked(PyDict_SetItem(result, key, value));
                        }
                    } finally {
                        jacpy_release(value);
                    }
                } finally {
                    jacpy_release(key);
                }
                self.input.whitespace();
                if self.input.character(self.input.position) == 125 {
                    break;
                }
                if self.input.character(self.input.position) != 44 {
                    self.input.error("Expecting ',' delimiter", self.input.position);
                }
                comma = self.input.position;
                self.input.position += 1;
                self.input.whitespace();
                if self.input.character(self.input.position) == 125 {
                    self.input.error(
                        "Illegal trailing comma before end of object", comma
                    );
                }
            }
        }
        self.input.position += 1;
        hook = self.pairs_hook if pairs else self.object_hook;
        if hook != Py_None {
            return required(PyObject_CallOneArg(hook, result));
        }
        return Py_NewRef(result);
    } finally {
        jacpy_release(result);
    }
}

impl json_scan.value -> ptr[PyObject] {
    character = self.input.character(self.input.position);
    if character < 0 {
        self.input.stop(self.input.position);
    }
    if character == 34 {
        self.input.position += 1;
        return self.input.string();
    }
    if character == 123 or character == 91 {
        context = " while decoding a JSON object from a unicode string"
            if character == 123
            else " while decoding a JSON array from a unicode string";
        checked(jacpy_recursion_enter(context));
        try {
            return self.object() if character == 123 else self.array();
        } finally {
            Py_LeaveRecursiveCall();
        }
    }

    if character == 110 and self.input.matches("null") {
        self.input.position += 4;
        return Py_NewRef(Py_None);
    }
    if character == 116 and self.input.matches("true") {
        self.input.position += 4;
        return PyBool_FromLong(1);
    }
    if character == 102 and self.input.matches("false") {
        self.input.position += 5;
        return PyBool_FromLong(0);
    }
    constant = "";
    if character == 78 {
        constant = "NaN";
    } elif character == 73 {
        constant = "Infinity";
    } elif character == 45 and self.input.character(self.input.position + 1) == 73 {
        constant = "-Infinity";
    }
    if constant and self.input.matches(constant) {
        self.input.position += len(constant);
        text = text_object(constant);
        try {
            return required(PyObject_CallOneArg(self.parse_constant, text));
        } finally {
            jacpy_release(text);
        }
    }
    return self.number();
}

impl jacpy_json_scanstring(
    source: ptr[PyObject], end: i64, strict: i64
) -> ptr[PyObject] {
    try {
        size = int(jacpy_unicode_size(source));
        if end < 0 or end > i64(size) {
            object_error(PyExc_ValueError, "end is out of bounds");
            return NULL;
        }
        input = json_input(source, size, int(end), strict != 0);
        value = input.string();
        return indexed(value, input.position);
    } except boundary_failure {
        return NULL;
    }
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
    memo: ptr[PyObject] = NULL;
    try {
        if start < 0 {
            object_error(PyExc_ValueError, "idx cannot be negative");
            return NULL;
        }
        input = json_input(
            source, int(jacpy_unicode_size(source)), int(start), strict != 0
        );
        memo = required(PyDict_New());
        scanner = json_scan(
            input, memo, object_hook, pairs_hook, parse_float, parse_int, parse_constant
        );
        value = scanner.value();
        return indexed(value, input.position);
    } except boundary_failure {
        return NULL;
    } finally {
        if memo != 0 {
            jacpy_release(memo);
        }
    }
}

impl encoding_error(kind: ptr[PyObject], message: str) {
    object_error(kind, message);
    raise boundary_failure();
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
        newline = required(
            PyUnicode_Concat(self.indent_cache[(level - 1) * 2], self.indent)
        );
        try {
            separator = required(PyUnicode_Concat(self.item_separator, newline));
            self.indent_cache.append(separator);
            self.indent_cache.append(Py_NewRef(newline));
        } finally {
            jacpy_release(newline);
        }
    }
    return self.indent_cache[level * 2 - 1];
}

impl json_output.newline(level: int) {
    checked(PyUnicodeWriter_WriteStr(self.writer, self.indent_cache[level * 2]));
}

impl json_output.mark(value: ptr[PyObject]) -> ptr[PyObject] {
    if self.markers == Py_None {
        return NULL;
    }
    identity = required(PyLong_FromVoidPtr(value));
    try {
        found = PySequence_Contains(self.markers, identity);
        checked(found);
        if found != 0 {
            encoding_error(PyExc_ValueError, "Circular reference detected");
        }
        checked(PyDict_SetItem(self.markers, identity, value));
        return Py_NewRef(identity);
    } finally {
        jacpy_release(identity);
    }
}

impl json_output.unmark(identity: ptr[PyObject]) {
    if identity != 0 {
        checked(PyDict_DelItem(self.markers, identity));
    }
}

impl json_output.float_text(value: ptr[PyObject]) -> ptr[PyObject] {
    number = jacpy_float_value(value);
    if number != number
        or number > 1.7976931348623157e308
        or number < -1.7976931348623157e308 {
        if not self.allow_nan {
            encoding_error(
                PyExc_ValueError,
                "Out of range float values are not JSON compliant: " + repr_value(value)
            );
        }
        return text_object(
            "Infinity" if number > 0 else ("-Infinity" if number < 0 else "NaN")
        );
    }
    return required(jacpy_float_repr(value));
}

impl json_output.string(value: ptr[PyObject]) {
    encoded = required(PyObject_CallOneArg(self.encoder, value));
    try {
        if jacpy_is_unicode(encoded) == 0 {
            encoding_error(
                PyExc_TypeError,
                "encoder() must return a string, not " + type_name(encoded)[:80]
            );
        }
        checked(PyUnicodeWriter_WriteStr(self.writer, encoded));
    } finally {
        jacpy_release(encoded);
    }
}

impl json_output.encode(value: ptr[PyObject], level: int) {
    if value == Py_None {
        write_ascii(self.writer, "null");
    } elif jacpy_is_bool(value) != 0 {
        write_ascii(self.writer, "true" if PyObject_IsTrue(value) != 0 else "false");
    } elif jacpy_is_unicode(value) != 0 {
        self.string(value);
    } elif jacpy_is_long(value) != 0 {
        text = required(jacpy_long_repr(value));
        try {
            checked(PyUnicodeWriter_WriteStr(self.writer, text));
        } finally {
            jacpy_release(text);
        }
    } elif jacpy_is_float(value) != 0 {
        text = self.float_text(value);
        try {
            checked(PyUnicodeWriter_WriteStr(self.writer, text));
        } finally {
            jacpy_release(text);
        }
    } elif jacpy_is_list(value) != 0 or jacpy_is_tuple(value) != 0 {
        checked(jacpy_recursion_enter(" while encoding a JSON object"));
        try {
            self.sequence(value, level);
        } finally {
            Py_LeaveRecursiveCall();
        }
    } elif jacpy_is_dict(value) != 0 {
        checked(jacpy_recursion_enter(" while encoding a JSON object"));
        try {
            self.dictionary(value, level);
        } finally {
            Py_LeaveRecursiveCall();
        }
    } else {
        identity = self.mark(value);
        try {
            replacement = required(PyObject_CallOneArg(self.default_fn, value));
            try {
                checked(jacpy_recursion_enter(" while encoding a JSON object"));
                try {
                    self.encode(replacement, level);
                } except boundary_failure {
                    serialization_note(value, NULL, 0, 0);
                    raise;
                } finally {
                    Py_LeaveRecursiveCall();
                }
            } finally {
                jacpy_release(replacement);
            }
            self.unmark(identity);
        } finally {
            jacpy_release(identity);
        }
    }
}

impl json_output.sequence(value: ptr[PyObject], level: int) {
    sequence = required(
        PySequence_Fast(value, ptr[u8]("_iterencode_list needs a sequence"))
    );
    identity: ptr[PyObject] = NULL;
    try {
        if jacpy_fast_size(sequence) == 0 {
            write_ascii(self.writer, "[]");
            return;
        }
        identity = self.mark(value);
        write_char(self.writer, 91);
        if len(self.indent_cache) != 0 {
            level += 1;
        }
        separator = self.separator(level);
        if len(self.indent_cache) != 0 {
            self.newline(level);
        }
        i = 0;
        while i < int(jacpy_fast_size(sequence)) {
            item = required(jacpy_fast_item(sequence, i64(i)));
            try {
                if i != 0 {
                    checked(PyUnicodeWriter_WriteStr(self.writer, separator));
                }
                try {
                    self.encode(item, level);
                } except boundary_failure {
                    serialization_note(value, NULL, i, 1);
                    raise;
                }
            } finally {
                jacpy_release(item);
            }
            i += 1;
        }
        self.unmark(identity);
        if len(self.indent_cache) != 0 {
            self.newline(level - 1);
        }
        write_char(self.writer, 93);
    } finally {
        jacpy_release(identity);
        jacpy_release(sequence);
    }
}

impl json_output.key_value(
    dictionary: ptr[PyObject],
    key: ptr[PyObject],
    value: ptr[PyObject],
    level: int,
    separator: ptr[PyObject],
    first: bool
) -> bool {
    text: ptr[PyObject] = NULL;
    if jacpy_is_unicode(key) != 0 {
        text = Py_NewRef(key);
    } elif jacpy_is_float(key) != 0 {
        text = self.float_text(key);
    } elif key == Py_None {
        text = text_object("null");
    } elif jacpy_is_bool(key) != 0 {
        text = text_object("true" if PyObject_IsTrue(key) != 0 else "false");
    } elif jacpy_is_long(key) != 0 {
        text = required(jacpy_long_repr(key));
    } elif self.skipkeys {
        return first;
    } else {
        encoding_error(
            PyExc_TypeError,
            "keys must be str, int, float, bool or None, not " + type_name(key)[:100]
        );
    }
    try {
        if first {
            if len(self.indent_cache) != 0 {
                self.newline(level);
            }
        } else {
            checked(PyUnicodeWriter_WriteStr(self.writer, separator));
        }
        self.string(text);
    } finally {
        jacpy_release(text);
    }
    checked(PyUnicodeWriter_WriteStr(self.writer, self.key_separator));
    try {
        self.encode(value, level);
    } except boundary_failure {
        serialization_note(dictionary, key, 0, 2);
        raise;
    }
    return False;
}

impl json_output.dictionary(value: ptr[PyObject], level: int) {
    if jacpy_dict_size(value) == 0 {
        write_ascii(self.writer, "{}");
        return;
    }
    identity = self.mark(value);
    try {
        write_char(self.writer, 123);
        if len(self.indent_cache) != 0 {
            level += 1;
        }
        separator = self.separator(level);
        first = True;
        if self.sort_keys or jacpy_is_exact_dict(value) == 0 {
            items = required(PyMapping_Items(value));
            try {
                if self.sort_keys {
                    checked(PyList_Sort(items));
                }
                i = 0;
                while i < int(jacpy_list_size(items)) {
                    item = required(PyList_GetItemRef(items, i64(i)));
                    try {
                        if jacpy_is_tuple(item) == 0 or PyTuple_Size(item) != 2 {
                            encoding_error(
                                PyExc_ValueError, "items must return 2-tuples"
                            );
                        }
                        key = required(jacpy_tuple_item(item, 0));
                        try {
                            child = required(jacpy_tuple_item(item, 1));
                            try {
                                first = self.key_value(
                                    value, key, child, level, separator, first
                                );
                            } finally {
                                jacpy_release(child);
                            }
                        } finally {
                            jacpy_release(key);
                        }
                    } finally {
                        jacpy_release(item);
                    }
                    i += 1;
                }
            } finally {
                jacpy_release(items);
            }
        } else {
            position: i64 = 0;
            entry_key: ptr[PyObject] = NULL;
            entry_value: ptr[PyObject] = NULL;
            while PyDict_Next(value, &mut position, &mut entry_key, &mut entry_value)
                != 0 {
                key = Py_NewRef(entry_key);
                child = Py_NewRef(entry_value);
                try {
                    first = self.key_value(value, key, child, level, separator, first);
                } finally {
                    jacpy_release(child);
                    jacpy_release(key);
                }
            }
        }
        self.unmark(identity);
        if len(self.indent_cache) != 0 and not first {
            self.newline(level - 1);
        }
        write_char(self.writer, 125);
    } finally {
        jacpy_release(identity);
    }
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
            (flags & 4) != 0
        );
        try {
            output.initialize_indent(int(level));
            output.encode(value, 0);
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
