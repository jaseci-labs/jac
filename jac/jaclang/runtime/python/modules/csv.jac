obj CsvConfig(NativeState) {
    has limit: i64 = 128 * 1024;

    def clear;
    def traverse_refs(visitor: ptr, context: ptr) -> i32;
}

def:priv fail(kind: ptr[PyObject], message: str);

def:priv csv_error(error: ptr[PyObject], message: str);

def:priv pending;

def:priv dialect_char(
    name: str, value: ptr[PyObject], fallback: int, optional: bool
) -> int;

def:priv dialect_bool(value: ptr[PyObject], fallback: bool) -> bool;

def:priv valid_character(
    name: str, character: int, space: bool, terminator: ptr[PyObject]
);

def:pub jacpy_csv_dialect(
    base: ptr[PyObject],
    overrides: ptr[PyObject],
    registry: ptr[PyObject],
    dialect_type: ptr[PyObject],
    error: ptr[PyObject]
) -> ptr[PyObject];

obj csv_dialect {
    has delimiter: int,
        doublequote: bool,
        escapechar: int,
        terminator: ptr[PyObject],
        quotechar: int,
        quoting: int,
        skipspace: bool,
        strict: bool;
}

def:priv setting(options: ptr[PyObject], index: int) -> int;

def:priv settings(options: ptr[PyObject]) -> csv_dialect;

def:priv unicode_field(characters: list[int], maxchar: i64) -> ptr[PyObject];

def:priv read_failure(error: ptr[PyObject], message: str) -> i32;

def:priv reader_dialect(reader: csv_reader, options: ptr[PyObject]) -> i32;

def:priv buffer_field(buffer: ptr[u32], count: i64, maxchar: i64) -> ptr[PyObject];

enum parse_state {
    START_RECORD = 0,
    START_FIELD = 1,
    ESCAPED_CHAR = 2,
    IN_FIELD = 3,
    IN_QUOTED_FIELD = 4,
    ESCAPE_IN_QUOTED_FIELD = 5,
    QUOTE_IN_QUOTED_FIELD = 6,
    EAT_CRNL = 7,
    AFTER_ESCAPED_CRNL = 8
}

obj csv_reader {
    has fields: ptr[PyObject] = NULL,
        buffer: ptr[u32] = ptr[u32](),
        field_len: i64 = 0,
        field_size: i64 = 0,
        field_max: i64 = 0,
        state: parse_state = parse_state.START_RECORD,
        unquoted: bool = False,
        line_num: int = 0,
        options: ptr[PyObject] = NULL,
        dialect: (csv_dialect | None) = None;

    def reset -> i32;
    def save(dialect: csv_dialect) -> i32;
    def append(character: i64, module: CsvConfig, error: ptr[PyObject]) -> i32;
    def feed(
        character: i64, dialect: csv_dialect, module: CsvConfig, error: ptr[PyObject]
    ) -> i32;
}

def:pub jacpy_csv_reader_new -> csv_reader;

def:pub jacpy_csv_reader_clear(reader: csv_reader);

def:pub jacpy_csv_reader_fields(reader: csv_reader) -> ptr[PyObject];

def:pub jacpy_csv_reader_line(reader: csv_reader) -> i64;

def:pub jacpy_csv_read(
    reader: csv_reader,
    iterator: ptr[PyObject],
    options: ptr[PyObject],
    module: CsvConfig,
    error: ptr[PyObject]
) -> ptr[PyObject];

obj csv_writer {
    has record: list[int] = [],
        num_fields: int = 0;

    def append(
        field: ptr[PyObject], quoted: bool, dialect: csv_dialect, error: ptr[PyObject]
    );

    def row(
        value: ptr[PyObject],
        output: ptr[PyObject],
        options: ptr[PyObject],
        error: ptr[PyObject]
    ) -> ptr[PyObject];
}

def:pub jacpy_csv_writer_new -> csv_writer;

def:pub jacpy_csv_write(
    writer: csv_writer,
    value: ptr[PyObject],
    output: ptr[PyObject],
    options: ptr[PyObject],
    error: ptr[PyObject],
    many: i64
) -> ptr[PyObject];

def:pub jacpy_csv_registry(
    registry: ptr[PyObject],
    key: ptr[PyObject],
    value: ptr[PyObject],
    error: ptr[PyObject],
    operation: i64
) -> ptr[PyObject];

def:priv registry_call(
    module: ptr[PyObject], key: ptr[PyObject], operation: i64
) -> ptr[PyObject];

def _csv_list_dialects_impl(module: ptr[PyObject]) -> ptr[PyObject];

def _csv_get_dialect_impl(module: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def _csv_unregister_dialect_impl(
    module: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

def _csv_field_size_limit_impl(
    module: ptr[PyObject], new_limit: ptr[PyObject]
) -> ptr[PyObject];

impl CsvConfig.clear {}

impl CsvConfig.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl fail(kind: ptr[PyObject], message: str) {
    object_error(kind, message);
    raise boundary_failure();
}

impl csv_error(error: ptr[PyObject], message: str) {
    jacpy_set_exception(error, message, i64(len(message.encode("utf-8"))));
    raise boundary_failure();
}

impl pending {
    if jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
}

impl dialect_char(
    name: str, value: ptr[PyObject], fallback: int, optional: bool
) -> int {
    if value == 0 {
        return fallback;
    }
    if optional and value == Py_None {
        return -1;
    }
    expected = "\""
        + name
        + "\" must be a unicode character"
        + (" or None" if optional else "")
        + ", not ";
    if jacpy_is_unicode(value) == 0 {
        fail(PyExc_TypeError, expected + type_name(value, True));
    }
    size = int(jacpy_unicode_size(value));
    if size != 1 {
        fail(PyExc_TypeError, expected + "a string of length " + str(size));
    }
    return int(PyUnicode_ReadChar(value, 0));
}

impl dialect_bool(value: ptr[PyObject], fallback: bool) -> bool {
    if value == 0 {
        return fallback;
    }
    result = PyObject_IsTrue(value);
    checked(result);
    return result != 0;
}

impl valid_character(
    name: str, character: int, space: bool, terminator: ptr[PyObject]
) {
    if character == 10 or character == 13 or (character == 32 and not space) {
        fail(PyExc_ValueError, "bad " + name + " value");
    }
    for i in range(int(jacpy_unicode_size(terminator))) {
        if int(PyUnicode_ReadChar(terminator, i64(i))) == character {
            fail(PyExc_ValueError, "bad " + name + " or lineterminator value");
        }
    }
}

impl jacpy_csv_dialect(
    base: ptr[PyObject],
    overrides: ptr[PyObject],
    registry: ptr[PyObject],
    dialect_type: ptr[PyObject],
    error: ptr[PyObject]
) -> ptr[PyObject] {
    dialect: ptr[PyObject] = NULL;
    values: list[ptr[PyObject]] = [];
    result: list[ptr[PyObject]] = [];
    try {
        if base != 0 {
            if jacpy_is_unicode(base) != 0 {
                dialect = jacpy_dict_get(registry, base);
                pending();
                if dialect == 0 {
                    csv_error(error, "unknown dialect");
                }
            } else {
                dialect = Py_NewRef(base);
            }
        }
        names = [
            "delimiter",
            "doublequote",
            "escapechar",
            "lineterminator",
            "quotechar",
            "quoting",
            "skipinitialspace",
            "strict"
        ];
        overridden = False;
        for name in names {
            key = text_object(name);
            try {
                value = jacpy_dict_get(overrides, key);
                pending();
                overridden = overridden or value != 0;
                values.append(value);
            } finally {
                jacpy_release(key);
            }
        }
        if dialect != 0
            and not overridden
            and jacpy_type_check(dialect, dialect_type) != 0 {
            return Py_NewRef(dialect);
        }
        for i in range(len(names)) {
            if values[i] == 0 and dialect != 0 {
                values[i] = jacpy_object_getattr_text(dialect, names[i]);
                if values[i] == 0 {
                    PyErr_Clear();
                }
            }
        }
        delimiter = dialect_char(names[0], values[0], 44, False);
        doublequote = dialect_bool(values[1], True);
        escapechar = dialect_char(names[2], values[2], -1, True);
        terminator = values[3];
        if terminator == 0 {
            terminator = text_object("\r\n");
            values[3] = terminator;
        } elif jacpy_is_unicode(terminator) == 0 {
            fail(
                PyExc_TypeError,
                "\"lineterminator\" must be a string, not "
                    + type_name(terminator, True)
            );
        }
        quotechar = dialect_char(names[4], values[4], 34, True);
        quoting = 0;
        if values[5] != 0 {
            if jacpy_is_exact_long(values[5]) == 0 {
                fail(
                    PyExc_TypeError,
                    "\"quoting\" must be an integer, not " + type_name(values[5], True)
                );
            }
            quoting = int(PyLong_AsInt(values[5]));
            pending();
        }
        skipspace = dialect_bool(values[6], False);
        strict = dialect_bool(values[7], False);
        if quoting < 0 or quoting > 5 {
            fail(PyExc_TypeError, "bad \"quoting\" value");
        }
        if values[4] != 0 and values[4] == Py_None and values[5] == 0 {
            quoting = 3;
        }
        if quoting != 3 and quotechar == -1 {
            fail(PyExc_TypeError, "quotechar must be set if quoting enabled");
        }
        valid_character("delimiter", delimiter, True, terminator);
        valid_character("escapechar", escapechar, not skipspace, terminator);
        valid_character("quotechar", quotechar, not skipspace, terminator);
        chars = [delimiter, escapechar, quotechar];
        labels = ["delimiter", "escapechar", "quotechar"];
        for i in range(3) {
            for j in range(i + 1, 3) {
                if chars[i] == chars[j] and chars[i] != -1 {
                    fail(
                        PyExc_ValueError,
                        "bad " + labels[i] + " or " + labels[j] + " value"
                    );
                }
            }
        }
        result.append(required(PyLong_FromLongLong(i64(delimiter))));
        result.append(required(PyBool_FromLong(i64(doublequote))));
        result.append(required(PyLong_FromLongLong(i64(escapechar))));
        result.append(Py_NewRef(terminator));
        result.append(required(PyLong_FromLongLong(i64(quotechar))));
        result.append(required(PyLong_FromLongLong(i64(quoting))));
        result.append(required(PyBool_FromLong(i64(skipspace))));
        result.append(required(PyBool_FromLong(i64(strict))));
        return object_tuple(result);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(dialect);
        for value in values {
            jacpy_release(value);
        }
        for value in result {
            jacpy_release(value);
        }
    }
}

impl setting(options: ptr[PyObject], index: int) -> int {
    value = required(jacpy_tuple_item(options, i64(index)));
    try {
        return int(PyLong_AsLongLong(value));
    } finally {
        jacpy_release(value);
    }
}

impl settings(options: ptr[PyObject]) -> csv_dialect {
    terminator = required(jacpy_tuple_item(options, 3));
    jacpy_release(terminator);
    return csv_dialect(
        setting(options, 0),
        setting(options, 1) != 0,
        setting(options, 2),
        terminator,
        setting(options, 4),
        setting(options, 5),
        setting(options, 6) != 0,
        setting(options, 7) != 0
    );
}

impl unicode_field(characters: list[int], maxchar: i64) -> ptr[PyObject] {
    count = len(characters);
    result = PyUnicode_New(i64(count), u32(maxchar));
    if result == 0 {
        return NULL;
    }
    kind = jacpy_unicode_kind(result);
    data = jacpy_unicode_data(result);
    i = 0;
    if kind == 1 {
        out = ptr[u8](data);
        while i < count {
            (out + i).view(1)[0] = u8(characters[i]);
            i += 1;
        }
    } elif kind == 2 {
        out2 = ptr[u16](data);
        while i < count {
            (out2 + i).view(1)[0] = u16(characters[i]);
            i += 1;
        }
    } else {
        out4 = ptr[u32](data);
        while i < count {
            (out4 + i).view(1)[0] = u32(characters[i]);
            i += 1;
        }
    }
    return result;
}

impl reader_dialect(reader: csv_reader, options: ptr[PyObject]) -> i32 {
    try {
        reader.dialect = settings(options);
    } except boundary_failure {
        return i32(-1);
    }
    reader.options = options;
    return i32(0);
}

impl buffer_field(buffer: ptr[u32], count: i64, maxchar: i64) -> ptr[PyObject] {
    result = PyUnicode_New(count, u32(maxchar));
    if result == 0 {
        return NULL;
    }
    kind = jacpy_unicode_kind(result);
    data = jacpy_unicode_data(result);
    i: i64 = 0;
    if kind == 1 {
        out = ptr[u8](data);
        while i < count {
            (out + i).view(1)[0] = u8((buffer + i).view(1)[0]);
            i += 1;
        }
    } elif kind == 2 {
        out2 = ptr[u16](data);
        while i < count {
            (out2 + i).view(1)[0] = u16((buffer + i).view(1)[0]);
            i += 1;
        }
    } else {
        out4 = ptr[u32](data);
        while i < count {
            (out4 + i).view(1)[0] = (buffer + i).view(1)[0];
            i += 1;
        }
    }
    return result;
}

impl read_failure(error: ptr[PyObject], message: str) -> i32 {
    jacpy_set_exception(error, message, i64(len(message.encode("utf-8"))));
    return i32(-1);
}

impl csv_reader.reset -> i32 {
    fields = jacpy_list_new();
    if fields == 0 {
        return i32(-1);
    }
    old = self.fields;
    self.fields = fields;
    jacpy_release(old);
    self.field_len = 0;
    self.field_max = 0;
    self.state = parse_state.START_RECORD;
    self.unquoted = False;
    return i32(0);
}

impl csv_reader.save(dialect: csv_dialect) -> i32 {
    value: ptr[PyObject] = NULL;
    count = self.field_len;
    if self.unquoted
        and count == 0
        and (dialect.quoting == 4 or dialect.quoting == 5) {
        value = Py_NewRef(Py_None);
    } else {
        value = buffer_field(self.buffer, count, self.field_max);
        if value == 0 {
            return i32(-1);
        }
        if self.unquoted
            and count != 0
            and (dialect.quoting == 2 or dialect.quoting == 4) {
            numeric = PyNumber_Float(value);
            jacpy_release(value);
            if numeric == 0 {
                return i32(-1);
            }
            value = numeric;
        }
        self.field_len = 0;
        self.field_max = 0;
    }
    status = PyList_Append(self.fields, value);
    jacpy_release(value);
    return status;
}

impl csv_reader.append(character: i64, module: CsvConfig, error: ptr[PyObject]) -> i32 {
    limit = module.limit;
    count = self.field_len;
    if count >= limit {
        return read_failure(
            error, "field larger than field limit (" + str(limit) + ")"
        );
    }
    if count == self.field_size {
        size = 64 if count == 0 else count * 2;
        grown = ptr[u32](PyMem_Realloc(ptr(self.buffer), u64(size * 4)));
        if grown.is_null() {
            PyErr_NoMemory();
            return i32(-1);
        }
        self.buffer = grown;
        self.field_size = size;
    }
    (self.buffer + count).view(1)[0] = u32(character);
    self.field_len = count + 1;
    if character > self.field_max {
        self.field_max = character;
    }
    return i32(0);
}

impl csv_reader.feed(
    character: i64, dialect: csv_dialect, module: CsvConfig, error: ptr[PyObject]
) -> i32 {
    state = self.state;
    if state == parse_state.IN_FIELD {
        if character == 10 or character == 13 or character == -2 {
            self.state = parse_state.START_RECORD
                if character == -2
                else parse_state.EAT_CRNL;
            return self.save(dialect);
        }
        if character == dialect.escapechar {
            self.state = parse_state.ESCAPED_CHAR;
            return i32(0);
        }
        if character == dialect.delimiter {
            self.state = parse_state.START_FIELD;
            return self.save(dialect);
        }
        return self.append(character, module, error);
    }
    if state == parse_state.START_RECORD {
        if character == -2 {
            return i32(0);
        }
        if character == 10 or character == 13 {
            self.state = parse_state.EAT_CRNL;
            return i32(0);
        }
        state = parse_state.START_FIELD;
        self.state = state;
    }
    if state == parse_state.START_FIELD {
        self.unquoted = True;
        if character == 10 or character == 13 or character == -2 {
            self.state = parse_state.START_RECORD
                if character == -2
                else parse_state.EAT_CRNL;
            return self.save(dialect);
        } elif character == dialect.quotechar and dialect.quoting != 3 {
            self.unquoted = False;
            self.state = parse_state.IN_QUOTED_FIELD;
        } elif character == dialect.escapechar {
            self.state = parse_state.ESCAPED_CHAR;
        } elif character == 32 and dialect.skipspace {
            return i32(0);
        } elif character == dialect.delimiter {
            return self.save(dialect);
        } else {
            self.state = parse_state.IN_FIELD;
            return self.append(character, module, error);
        }
    } elif state == parse_state.ESCAPED_CHAR {
        if character == 10 or character == 13 {
            self.state = parse_state.AFTER_ESCAPED_CRNL;
            return self.append(character, module, error);
        }
        self.state = parse_state.IN_FIELD;
        return self.append(10 if character == -2 else character, module, error);
    } elif state == parse_state.AFTER_ESCAPED_CRNL {
        if character == -2 {
            return i32(0);
        }
        if character == 10 or character == 13 {
            self.state = parse_state.START_RECORD
                if character == -2
                else parse_state.EAT_CRNL;
            return self.save(dialect);
        } elif character == dialect.escapechar {
            self.state = parse_state.ESCAPED_CHAR;
        } elif character == dialect.delimiter {
            self.state = parse_state.START_FIELD;
            return self.save(dialect);
        } else {
            self.state = parse_state.IN_FIELD;
            return self.append(character, module, error);
        }
    } elif state == parse_state.IN_QUOTED_FIELD {
        if character == -2 {
            return i32(0);
        }
        if character == dialect.escapechar {
            self.state = parse_state.ESCAPE_IN_QUOTED_FIELD;
        } elif character == dialect.quotechar and dialect.quoting != 3 {
            self.state = parse_state.QUOTE_IN_QUOTED_FIELD
                if dialect.doublequote
                else parse_state.IN_FIELD;
        } else {
            return self.append(character, module, error);
        }
    } elif state == parse_state.ESCAPE_IN_QUOTED_FIELD {
        self.state = parse_state.IN_QUOTED_FIELD;
        return self.append(10 if character == -2 else character, module, error);
    } elif state == parse_state.QUOTE_IN_QUOTED_FIELD {
        if dialect.quoting != 3 and character == dialect.quotechar {
            self.state = parse_state.IN_QUOTED_FIELD;
            return self.append(character, module, error);
        } elif character == dialect.delimiter {
            self.state = parse_state.START_FIELD;
            return self.save(dialect);
        } elif character == 10 or character == 13 or character == -2 {
            self.state = parse_state.START_RECORD
                if character == -2
                else parse_state.EAT_CRNL;
            return self.save(dialect);
        } elif not dialect.strict {
            self.state = parse_state.IN_FIELD;
            return self.append(character, module, error);
        } else {
            return read_failure(
                error,
                "'"
                    + chr(dialect.delimiter)
                    + "' expected after '"
                    + chr(dialect.quotechar)
                    + "'"
            );
        }
    } elif state == parse_state.EAT_CRNL {
        if character == 10 or character == 13 {
            return i32(0);
        }
        if character == -2 {
            self.state = parse_state.START_RECORD;
        } else {
            return read_failure(
                error,
                "new-line character seen in unquoted field - do you need to open the file with newline=''?"
            );
        }
    }
    return i32(0);
}

impl jacpy_csv_reader_new -> csv_reader {
    return csv_reader();
}

impl jacpy_csv_reader_clear(reader: csv_reader) {
    buffer = reader.buffer;
    reader.buffer = ptr[u32]();
    reader.field_size = 0;
    reader.field_len = 0;
    PyMem_Free(ptr(buffer));
    old = reader.fields;
    reader.fields = NULL;
    jacpy_release(old);
}

impl jacpy_csv_reader_fields(reader: csv_reader) -> ptr[PyObject] {
    return reader.fields;
}

impl jacpy_csv_reader_line(reader: csv_reader) -> i64 {
    return i64(reader.line_num);
}

impl jacpy_csv_read(
    reader: csv_reader,
    iterator: ptr[PyObject],
    options: ptr[PyObject],
    module: CsvConfig,
    error: ptr[PyObject]
) -> ptr[PyObject] {
    if reader.reset() < 0 {
        return NULL;
    }
    if reader.dialect is None or reader.options != options {
        if reader_dialect(reader, options) < 0 {
            return NULL;
        }
    }
    dialect = reader.dialect;
    if not isinstance(dialect, csv_dialect) {
        return NULL;
    }
    while True {
        line = PyIter_Next(iterator);
        if line == 0 {
            if jacpy_error_pending() != 0 {
                return NULL;
            }
            if reader.field_len != 0 or reader.state == parse_state.IN_QUOTED_FIELD {
                if dialect.strict {
                    read_failure(error, "unexpected end of data");
                    return NULL;
                }
                if reader.save(dialect) < 0 {
                    return NULL;
                }
                break;
            }
            return NULL;
        }
        if jacpy_is_unicode(line) == 0 {
            read_failure(
                error,
                "iterator should return strings, not "
                    + type_name(line)[:200]
                    + " (the file should be opened in text mode)"
            );
            jacpy_release(line);
            return NULL;
        }
        if reader.fields == 0 {
            read_failure(error, "iterator has already advanced the reader");
            jacpy_release(line);
            return NULL;
        }
        reader.line_num += 1;
        kind = jacpy_unicode_kind(line);
        data = jacpy_unicode_data(line);
        size = jacpy_unicode_size(line);
        text = ptr[u8](data);
        text2 = ptr[u16](data);
        text4 = ptr[u32](data);
        limit = module.limit;
        delimiter = dialect.delimiter;
        escape = dialect.escapechar;
        quote = -1 if dialect.quoting == 3 else dialect.quotechar;
        i: i64 = 0;
        status: i32 = 0;
        while i < size {
            c: i64 = 0;
            if kind == 1 {
                c = i64((text + i).view(1)[0]);
            } elif kind == 2 {
                c = i64((text2 + i).view(1)[0]);
            } else {
                c = i64((text4 + i).view(1)[0]);
            }
            i += 1;
            state = reader.state;
            if c != escape
                and (
                    (
                        state == parse_state.IN_FIELD
                        and c != delimiter
                        and c != 10
                        and c != 13
                    )
                    or (state == parse_state.IN_QUOTED_FIELD and c != quote)
                ) {
                count = reader.field_len;
                if count < limit and count < reader.field_size {
                    (reader.buffer + count).view(1)[0] = u32(c);
                    reader.field_len = count + 1;
                    if c > reader.field_max {
                        reader.field_max = c;
                    }
                    continue;
                }
            }
            status = reader.feed(c, dialect, module, error);
            if status < 0 {
                break;
            }
        }
        jacpy_release(line);
        if status < 0 or reader.feed(-2, dialect, module, error) < 0 {
            return NULL;
        }
        if reader.state == parse_state.START_RECORD {
            break;
        }
    }
    fields = reader.fields;
    reader.fields = NULL;
    return fields;
}

impl csv_writer.append(
    field: ptr[PyObject], quoted: bool, dialect: csv_dialect, error: ptr[PyObject]
) {
    length = int(jacpy_unicode_size(field)) if field != 0 else 0;
    if length == 0 and dialect.delimiter == 32 and dialect.skipspace {
        if dialect.quoting == 3
            or (field == 0 and (dialect.quoting == 4 or dialect.quoting == 5)) {
            csv_error(
                error,
                "empty field must be quoted if delimiter is a space and skipinitialspace is true"
            );
        }
        quoted = True;
    }
    data: list[int] = [];
    for i in range(length) {
        character = int(PyUnicode_ReadChar(field, i64(i)));
        special = character == dialect.delimiter
            or character == dialect.escapechar
            or character == dialect.quotechar
            or character == 10
            or character == 13;
        if not special {
            for j in range(int(jacpy_unicode_size(dialect.terminator))) {
                if int(PyUnicode_ReadChar(dialect.terminator, i64(j))) == character {
                    special = True;
                    break;
                }
            }
        }
        if special {
            escape = dialect.quoting == 3;
            if not escape {
                if character == dialect.quotechar {
                    if dialect.doublequote {
                        data.append(dialect.quotechar);
                    } else {
                        escape = True;
                    }
                } elif character == dialect.escapechar {
                    escape = True;
                }
                if not escape {
                    quoted = True;
                }
            }
            if escape {
                if dialect.escapechar == -1 {
                    csv_error(error, "need to escape, but no escapechar set");
                }
                data.append(dialect.escapechar);
            }
        }
        data.append(character);
    }
    if self.num_fields > 0 {
        self.record.append(dialect.delimiter);
    }
    if quoted {
        self.record.append(dialect.quotechar);
    }
    self.record.extend(data);
    if quoted {
        self.record.append(dialect.quotechar);
    }
    self.num_fields += 1;
}

impl csv_writer.row(
    value: ptr[PyObject],
    output: ptr[PyObject],
    options: ptr[PyObject],
    error: ptr[PyObject]
) -> ptr[PyObject] {
    iterator = PyObject_GetIter(value);
    if iterator == 0 {
        if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
            csv_error(error, "iterable expected, not " + type_name(value)[:200]);
        }
        raise boundary_failure();
    }
    try {
        dialect = settings(options);
        self.record.clear();
        self.num_fields = 0;
        null_field = False;
        while True {
            field = PyIter_Next(iterator);
            if field == 0 {
                pending();
                break;
            }
            try {
                quoted = dialect.quoting == 1
                    or (dialect.quoting == 2 and PyNumber_Check(field) == 0)
                    or (dialect.quoting == 4 and jacpy_is_unicode(field) != 0)
                    or (dialect.quoting == 5 and field != Py_None);
                null_field = field == Py_None;
                if jacpy_is_unicode(field) != 0 {
                    self.append(field, quoted, dialect, error);
                } elif null_field {
                    self.append(NULL, quoted, dialect, error);
                } else {
                    text = required(PyObject_Str(field));
                    jacpy_release(field);
                    field = NULL;
                    try {
                        self.append(text, quoted, dialect, error);
                    } finally {
                        jacpy_release(text);
                    }
                }
            } finally {
                jacpy_release(field);
            }
        }
        if self.num_fields > 0 and len(self.record) == 0 {
            if dialect.quoting == 3
                or (null_field and (dialect.quoting == 4 or dialect.quoting == 5)) {
                csv_error(error, "single empty field record must be quoted");
            }
            self.num_fields -= 1;
            self.append(NULL, True, dialect, error);
        }
        for i in range(int(jacpy_unicode_size(dialect.terminator))) {
            self.record.append(int(PyUnicode_ReadChar(dialect.terminator, i64(i))));
        }
        maxchar = 0;
        for character in self.record {
            if character > maxchar {
                maxchar = character;
            }
        }
        line = required(unicode_field(self.record, i64(maxchar)));
        try {
            return required(PyObject_CallOneArg(output, line));
        } finally {
            jacpy_release(line);
        }
    } finally {
        jacpy_release(iterator);
    }
}

impl jacpy_csv_writer_new -> csv_writer {
    return csv_writer();
}

impl jacpy_csv_write(
    writer: csv_writer,
    value: ptr[PyObject],
    output: ptr[PyObject],
    options: ptr[PyObject],
    error: ptr[PyObject],
    many: i64
) -> ptr[PyObject] {
    try {
        if many == 0 {
            return writer.row(value, output, options, error);
        }
        iterator = required(PyObject_GetIter(value));
        try {
            while True {
                row = PyIter_Next(iterator);
                if row == 0 {
                    pending();
                    break;
                }
                try {
                    jacpy_release(writer.row(row, output, options, error));
                } finally {
                    jacpy_release(row);
                }
            }
        } finally {
            jacpy_release(iterator);
        }
        return Py_NewRef(Py_None);
    } except boundary_failure {
        return NULL;
    }
}

impl jacpy_csv_registry(
    registry: ptr[PyObject],
    key: ptr[PyObject],
    value: ptr[PyObject],
    error: ptr[PyObject],
    operation: i64
) -> ptr[PyObject] {
    try {
        if operation == 0 {
            return required(PyDict_Keys(registry));
        }
        if operation == 1 {
            found = jacpy_dict_get(registry, key);
            pending();
            if found == 0 {
                csv_error(error, "unknown dialect");
            }
            return found;
        }
        if operation == 2 {
            checked(PyDict_SetItem(registry, key, value));
        } else {
            removed = jacpy_dict_pop_discard(registry, key);
            checked(removed);
            if removed == 0 {
                csv_error(error, "unknown dialect");
            }
        }
        return Py_NewRef(Py_None);
    } except boundary_failure {
        return NULL;
    }
}

impl registry_call(
    module: ptr[PyObject], key: ptr[PyObject], operation: i64
) -> ptr[PyObject] {
    return jacpy_csv_registry(
        jacpy_binding_state_get(module, 1),
        key,
        NULL,
        jacpy_binding_state_get(module, 0),
        operation
    );
}

impl _csv_list_dialects_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return registry_call(module, NULL, 0);
}

impl _csv_get_dialect_impl(
    module: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    return registry_call(module, name, 1);
}

impl _csv_unregister_dialect_impl(
    module: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    return registry_call(module, name, 3);
}

impl _csv_field_size_limit_impl(
    module: ptr[PyObject], new_limit: ptr[PyObject]
) -> ptr[PyObject] {
    config: CsvConfig | None = None;
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, CsvConfig) {
            config = state;
        }
    }
    if config is None {
        object_error(PyExc_SystemError, "native CSV configuration is unavailable");
        return NULL;
    }
    old = config.limit;
    if new_limit != 0 {
        if jacpy_is_exact_long(new_limit) == 0 {
            object_error(PyExc_TypeError, "limit must be an integer");
            return NULL;
        }
        value = PyLong_AsLong(new_limit);
        if value == -1 and jacpy_error_pending() != 0 {
            return NULL;
        }
        config.limit = value;
    }
    return PyLong_FromLongLong(old);
}
