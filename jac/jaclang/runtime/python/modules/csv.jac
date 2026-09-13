"""CSV dialect policy and reader/writer state machines in native Jac.

CPython owns public objects and protocol calls; typed native state owns parsing
and quoting. Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    boundary_failure,
    required,
    checked,
    object_error,
    text_object,
    type_name,
    object_tuple,
    jacpy_retain,
    jacpy_release,
    jacpy_none,
    jacpy_boolean,
    jacpy_int,
    jacpy_is_none,
    jacpy_is_unicode,
    jacpy_is_exact_long,
    jacpy_type_check,
    jacpy_long_as_int32,
    jacpy_integer_value,
    jacpy_truth,
    jacpy_error_pending,
    jacpy_clear_error,
    jacpy_error_is,
    jacpy_set_exception,
    jacpy_getattr_string,
    jacpy_dict_get,
    jacpy_dict_set,
    jacpy_dict_pop_discard,
    jacpy_dict_keys,
    jacpy_tuple_item,
    jacpy_unicode_size,
    jacpy_unicode_char,
    jacpy_writer_new,
    jacpy_writer_char,
    jacpy_writer_finish,
    jacpy_writer_discard,
    jacpy_list_new,
    jacpy_list_append,
    jacpy_iter,
    jacpy_iter_next,
    jacpy_number_float,
    jacpy_number_check,
    jacpy_object_str,
    jacpy_call_one
}
import from jaclang.runtime.python.bindings.state { NativeState }

obj CsvConfig(NativeState) {
    has limit: i64 = 128 * 1024;

    def clear {}
    def traverse_refs(visitor: u64, context: u64) -> i32 {
        return i32(0);
    }
}

def:priv fail(kind: str, message: str) {
    object_error(kind, message);
    raise boundary_failure();
}

def:priv csv_error(error: u64, message: str) {
    jacpy_set_exception(error, message, i64(len(message.encode("utf-8"))));
    raise boundary_failure();
}

def:priv pending {
    if jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
}

def:priv dialect_char(name: str, value: u64, fallback: int, optional: bool) -> int {
    if value == 0 {
        return fallback;
    }
    if optional and jacpy_is_none(value) != 0 {
        return -1;
    }
    expected = "\""
        + name
        + "\" must be a unicode character"
        + (" or None" if optional else "")
        + ", not ";
    if jacpy_is_unicode(value) == 0 {
        fail("TypeError", expected + type_name(value, True));
    }
    size = int(jacpy_unicode_size(value));
    if size != 1 {
        fail("TypeError", expected + "a string of length " + str(size));
    }
    return int(jacpy_unicode_char(value, 0));
}

def:priv dialect_bool(value: u64, fallback: bool) -> bool {
    if value == 0 {
        return fallback;
    }
    result = jacpy_truth(value);
    checked(result);
    return result != 0;
}

def:priv valid_character(name: str, character: int, space: bool, terminator: u64) {
    if character == 10 or character == 13 or (character == 32 and not space) {
        fail("ValueError", "bad " + name + " value");
    }
    for i in range(int(jacpy_unicode_size(terminator))) {
        if int(jacpy_unicode_char(terminator, i64(i))) == character {
            fail("ValueError", "bad " + name + " or lineterminator value");
        }
    }
}

def:pub jacpy_csv_dialect(
    base: u64, overrides: u64, registry: u64, dialect_type: u64, error: u64
) -> u64 {
    dialect: u64 = 0;
    values: list[u64] = [];
    result: list[u64] = [];
    try {
        if base != 0 {
            if jacpy_is_unicode(base) != 0 {
                dialect = jacpy_dict_get(registry, base);
                pending();
                if dialect == 0 {
                    csv_error(error, "unknown dialect");
                }
            } else {
                dialect = jacpy_retain(base);
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
            return jacpy_retain(dialect);
        }
        for i in range(len(names)) {
            if values[i] == 0 and dialect != 0 {
                values[i] = jacpy_getattr_string(dialect, names[i]);
                if values[i] == 0 {
                    jacpy_clear_error();
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
                "TypeError",
                "\"lineterminator\" must be a string, not "
                    + type_name(terminator, True)
            );
        }
        quotechar = dialect_char(names[4], values[4], 34, True);
        quoting = 0;
        if values[5] != 0 {
            if jacpy_is_exact_long(values[5]) == 0 {
                fail(
                    "TypeError",
                    "\"quoting\" must be an integer, not " + type_name(values[5], True)
                );
            }
            quoting = int(jacpy_long_as_int32(values[5]));
            pending();
        }
        skipspace = dialect_bool(values[6], False);
        strict = dialect_bool(values[7], False);
        if quoting < 0 or quoting > 5 {
            fail("TypeError", "bad \"quoting\" value");
        }
        if values[4] != 0 and jacpy_is_none(values[4]) != 0 and values[5] == 0 {
            quoting = 3;
        }
        if quoting != 3 and quotechar == -1 {
            fail("TypeError", "quotechar must be set if quoting enabled");
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
                        "ValueError", "bad " + labels[i] + " or " + labels[j] + " value"
                    );
                }
            }
        }
        result.append(required(jacpy_int(i64(delimiter))));
        result.append(required(jacpy_boolean(i64(doublequote))));
        result.append(required(jacpy_int(i64(escapechar))));
        result.append(jacpy_retain(terminator));
        result.append(required(jacpy_int(i64(quotechar))));
        result.append(required(jacpy_int(i64(quoting))));
        result.append(required(jacpy_boolean(i64(skipspace))));
        result.append(required(jacpy_boolean(i64(strict))));
        return object_tuple(result);
    } except boundary_failure {
        return 0;
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

obj csv_dialect {
    has delimiter: int,
        doublequote: bool,
        escapechar: int,
        terminator: u64,
        quotechar: int,
        quoting: int,
        skipspace: bool,
        strict: bool;
}

def:priv setting(options: u64, index: int) -> int {
    value = required(jacpy_tuple_item(options, i64(index)));
    try {
        return int(jacpy_integer_value(value));
    } finally {
        jacpy_release(value);
    }
}

def:priv settings(options: u64) -> csv_dialect {
    # The caller retains options throughout this borrowed Unicode reference.
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

def:priv unicode_field(characters: list[int]) -> u64 {
    writer = required(jacpy_writer_new());
    try {
        for character in characters {
            checked(jacpy_writer_char(writer, i64(character)));
        }
        result = jacpy_writer_finish(writer);
        writer = 0;
        return required(result);
    } finally {
        if writer != 0 {
            jacpy_writer_discard(writer);
        }
    }
}

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
    has fields: u64 = 0,
        field: list[int] = [],
        state: parse_state = parse_state.START_RECORD,
        unquoted: bool = False,
        line_num: int = 0;

    def reset {
        fields = required(jacpy_list_new());
        old = self.fields;
        self.fields = fields;
        jacpy_release(old);
        self.field.clear();
        self.state = parse_state.START_RECORD;
        self.unquoted = False;
    }

    def save(dialect: csv_dialect) {
        value: u64 = 0;
        try {
            if self.unquoted
                and len(self.field) == 0
                and (dialect.quoting == 4 or dialect.quoting == 5) {
                value = jacpy_none();
            } else {
                value = unicode_field(self.field);
                if self.unquoted
                    and len(self.field) != 0
                    and (dialect.quoting == 2 or dialect.quoting == 4) {
                    numeric = required(jacpy_number_float(value));
                    jacpy_release(value);
                    value = numeric;
                }
                self.field.clear();
            }
            checked(jacpy_list_append(self.fields, value));
        } finally {
            jacpy_release(value);
        }
    }

    def append(character: int, module: CsvConfig, error: u64) {
        limit = int(module.limit);
        if len(self.field) >= limit {
            csv_error(error, "field larger than field limit (" + str(limit) + ")");
        }
        self.field.append(character);
    }

    def feed(character: int, dialect: csv_dialect, module: CsvConfig, error: u64) {
        # -2 is the physical line boundary; -1 is an unset dialect character.
        if self.state == parse_state.START_RECORD {
            if character == -2 {
                return;
            }
            if character == 10 or character == 13 {
                self.state = parse_state.EAT_CRNL;
                return;
            }
            self.state = parse_state.START_FIELD;
        }
        if self.state == parse_state.START_FIELD {
            self.unquoted = True;
            if character == 10 or character == 13 or character == -2 {
                self.save(dialect);
                self.state = parse_state.START_RECORD
                    if character == -2
                    else parse_state.EAT_CRNL;
            } elif character == dialect.quotechar and dialect.quoting != 3 {
                self.unquoted = False;
                self.state = parse_state.IN_QUOTED_FIELD;
            } elif character == dialect.escapechar {
                self.state = parse_state.ESCAPED_CHAR;
            } elif character == 32 and dialect.skipspace {
                return;
            } elif character == dialect.delimiter {
                self.save(dialect);
            } else {
                self.append(character, module, error);
                self.state = parse_state.IN_FIELD;
            }
        } elif self.state == parse_state.ESCAPED_CHAR {
            if character == 10 or character == 13 {
                self.append(character, module, error);
                self.state = parse_state.AFTER_ESCAPED_CRNL;
                return;
            }
            self.append(10 if character == -2 else character, module, error);
            self.state = parse_state.IN_FIELD;
        } elif self.state == parse_state.IN_FIELD
            or self.state == parse_state.AFTER_ESCAPED_CRNL {
            if self.state == parse_state.AFTER_ESCAPED_CRNL and character == -2 {
                return;
            }
            if character == 10 or character == 13 or character == -2 {
                self.save(dialect);
                self.state = parse_state.START_RECORD
                    if character == -2
                    else parse_state.EAT_CRNL;
            } elif character == dialect.escapechar {
                self.state = parse_state.ESCAPED_CHAR;
            } elif character == dialect.delimiter {
                self.save(dialect);
                self.state = parse_state.START_FIELD;
            } else {
                self.append(character, module, error);
            }
        } elif self.state == parse_state.IN_QUOTED_FIELD {
            if character == -2 {
                return;
            }
            if character == dialect.escapechar {
                self.state = parse_state.ESCAPE_IN_QUOTED_FIELD;
            } elif character == dialect.quotechar and dialect.quoting != 3 {
                self.state = parse_state.QUOTE_IN_QUOTED_FIELD
                    if dialect.doublequote
                    else parse_state.IN_FIELD;
            } else {
                self.append(character, module, error);
            }
        } elif self.state == parse_state.ESCAPE_IN_QUOTED_FIELD {
            self.append(10 if character == -2 else character, module, error);
            self.state = parse_state.IN_QUOTED_FIELD;
        } elif self.state == parse_state.QUOTE_IN_QUOTED_FIELD {
            if dialect.quoting != 3 and character == dialect.quotechar {
                self.append(character, module, error);
                self.state = parse_state.IN_QUOTED_FIELD;
            } elif character == dialect.delimiter {
                self.save(dialect);
                self.state = parse_state.START_FIELD;
            } elif character == 10 or character == 13 or character == -2 {
                self.save(dialect);
                self.state = parse_state.START_RECORD
                    if character == -2
                    else parse_state.EAT_CRNL;
            } elif not dialect.strict {
                self.append(character, module, error);
                self.state = parse_state.IN_FIELD;
            } else {
                csv_error(
                    error,
                    "'"
                        + chr(dialect.delimiter)
                        + "' expected after '"
                        + chr(dialect.quotechar)
                        + "'"
                );
            }
        } elif self.state == parse_state.EAT_CRNL {
            if character == 10 or character == 13 {
                return;
            }
            if character == -2 {
                self.state = parse_state.START_RECORD;
            } else {
                csv_error(
                    error,
                    "new-line character seen in unquoted field - do you need to open the file with newline=''?"
                );
            }
        }
    }
}

def:pub jacpy_csv_reader_new -> csv_reader {
    return csv_reader();
}

def:pub jacpy_csv_reader_clear(reader: csv_reader) {
    old = reader.fields;
    reader.fields = 0;
    jacpy_release(old);
}

def:pub jacpy_csv_reader_fields(reader: csv_reader) -> u64 {
    return reader.fields;
}

def:pub jacpy_csv_reader_line(reader: csv_reader) -> i64 {
    return i64(reader.line_num);
}

def:pub jacpy_csv_read(
    reader: csv_reader, iterator: u64, options: u64, module: CsvConfig, error: u64
) -> u64 {
    try {
        reader.reset();
        dialect = settings(options);
        while True {
            line = jacpy_iter_next(iterator);
            if line == 0 {
                pending();
                if len(reader.field) != 0
                    or reader.state == parse_state.IN_QUOTED_FIELD {
                    if dialect.strict {
                        csv_error(error, "unexpected end of data");
                    }
                    reader.save(dialect);
                    break;
                }
                return 0;
            }
            try {
                if jacpy_is_unicode(line) == 0 {
                    csv_error(
                        error,
                        "iterator should return strings, not "
                            + type_name(line)[:200]
                            + " (the file should be opened in text mode)"
                    );
                }
                if reader.fields == 0 {
                    csv_error(error, "iterator has already advanced the reader");
                }
                reader.line_num += 1;
                for i in range(int(jacpy_unicode_size(line))) {
                    reader.feed(
                        int(jacpy_unicode_char(line, i64(i))), dialect, module, error
                    );
                }
            } finally {
                jacpy_release(line);
            }
            reader.feed(-2, dialect, module, error);
            if reader.state == parse_state.START_RECORD {
                break;
            }
        }
        fields = reader.fields;
        reader.fields = 0;
        return fields;
    } except boundary_failure {
        return 0;
    }
}

obj csv_writer {
    has record: list[int] = [],
        num_fields: int = 0;

    def append(field: u64, quoted: bool, dialect: csv_dialect, error: u64) {
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
            character = int(jacpy_unicode_char(field, i64(i)));
            special = character == dialect.delimiter
                or character == dialect.escapechar
                or character == dialect.quotechar
                or character == 10
                or character == 13;
            if not special {
                for j in range(int(jacpy_unicode_size(dialect.terminator))) {
                    if int(jacpy_unicode_char(dialect.terminator, i64(j)))
                        == character {
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

    def row(value: u64, output: u64, options: u64, error: u64) -> u64 {
        iterator = jacpy_iter(value);
        if iterator == 0 {
            if jacpy_error_is("TypeError") != 0 {
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
                field = jacpy_iter_next(iterator);
                if field == 0 {
                    pending();
                    break;
                }
                try {
                    quoted = dialect.quoting == 1
                        or (dialect.quoting == 2 and jacpy_number_check(field) == 0)
                        or (dialect.quoting == 4 and jacpy_is_unicode(field) != 0)
                        or (dialect.quoting == 5 and jacpy_is_none(field) == 0);
                    null_field = jacpy_is_none(field) != 0;
                    if jacpy_is_unicode(field) != 0 {
                        self.append(field, quoted, dialect, error);
                    } elif null_field {
                        self.append(u64(0), quoted, dialect, error);
                    } else {
                        text = required(jacpy_object_str(field));
                        jacpy_release(field);
                        field = 0;
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
                    or (
                        null_field and (dialect.quoting == 4 or dialect.quoting == 5)
                    ) {
                    csv_error(error, "single empty field record must be quoted");
                }
                self.num_fields -= 1;
                self.append(u64(0), True, dialect, error);
            }
            for i in range(int(jacpy_unicode_size(dialect.terminator))) {
                self.record.append(int(jacpy_unicode_char(dialect.terminator, i64(i))));
            }
            line = unicode_field(self.record);
            try {
                return required(jacpy_call_one(output, line));
            } finally {
                jacpy_release(line);
            }
        } finally {
            jacpy_release(iterator);
        }
    }
}

def:pub jacpy_csv_writer_new -> csv_writer {
    return csv_writer();
}

def:pub jacpy_csv_write(
    writer: csv_writer, value: u64, output: u64, options: u64, error: u64, many: i64
) -> u64 {
    try {
        if many == 0 {
            return writer.row(value, output, options, error);
        }
        iterator = required(jacpy_iter(value));
        try {
            while True {
                row = jacpy_iter_next(iterator);
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
        return jacpy_none();
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_csv_registry(
    registry: u64, key: u64, value: u64, error: u64, operation: i64
) -> u64 {
    try {
        if operation == 0 {
            return required(jacpy_dict_keys(registry));
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
            checked(jacpy_dict_set(registry, key, value));
        } else {
            removed = jacpy_dict_pop_discard(registry, key);
            checked(removed);
            if removed == 0 {
                csv_error(error, "unknown dialect");
            }
        }
        return jacpy_none();
    } except boundary_failure {
        return 0;
    }
}
