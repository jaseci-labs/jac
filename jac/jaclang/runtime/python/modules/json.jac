"""JSON scanning and serialization over the shared CPython value boundary.

All token decisions, escaping, traversal and callback orchestration run natively.
CPython supplies Unicode storage, containers, scalar construction and exceptions.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    boundary_failure,
    required,
    checked,
    text_object,
    pair,
    object_tuple,
    object_error,
    jacpy_retain,
    jacpy_release,
    jacpy_int,
    jacpy_none,
    jacpy_boolean,
    jacpy_is_none,
    jacpy_list_new,
    jacpy_list_append,
    jacpy_dict_new,
    jacpy_dict_default,
    jacpy_dict_set,
    jacpy_call_one,
    jacpy_call,
    jacpy_import_attr,
    jacpy_raise_value,
    jacpy_set_object_exception,
    jacpy_recursion_enter,
    jacpy_recursion_leave,
    jacpy_writer_new,
    jacpy_writer_discard,
    jacpy_writer_finish,
    jacpy_writer_char,
    jacpy_writer_text,
    jacpy_writer_slice,
    jacpy_writer_ascii,
    jacpy_unicode_size,
    jacpy_unicode_char,
    jacpy_unicode_slice
}

def write_ascii(writer: u64, text: str) {
    checked(jacpy_writer_ascii(writer, text, i64(len(text))));
}

def write_char(writer: u64, character: int) {
    checked(jacpy_writer_char(writer, i64(character)));
}

def hex_value(character: int) -> int {
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

def write_hex_escape(writer: u64, character: int) {
    write_ascii(writer, "\\u");
    for shift in [12, 8, 4, 0] {
        digit = (character >> shift) & 15;
        write_char(writer, 48 + digit if digit < 10 else 87 + digit);
    }
}

def escape_string(writer: u64, source: u64, ascii: bool) {
    write_char(writer, 34);
    for i in range(int(jacpy_unicode_size(source))) {
        character = int(jacpy_unicode_char(source, i64(i)));
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

def:pub jacpy_json_escape(source: u64, ascii: i64) -> u64 {
    writer: u64 = 0;
    try {
        writer = required(jacpy_writer_new());
        escape_string(writer, source, ascii != 0);
        result = jacpy_writer_finish(writer);
        writer = 0;
        return result;
    } except boundary_failure {
        return 0;
    } finally {
        if writer != 0 {
            jacpy_writer_discard(writer);
        }
    }
}

# Both successful and failing indexed results consume their value reference.
def indexed(value: u64, position: int) -> u64 {
    try {
        index = required(jacpy_int(i64(position)));
        try {
            return pair(value, index);
        } finally {
            jacpy_release(index);
        }
    } finally {
        jacpy_release(value);
    }
}

obj json_input {
    has source: u64,
        length: int,
        position: int,
        strict: bool;

    def character(index: int) -> int {
        if index < 0 or index >= self.length {
            return -1;
        }
        return int(jacpy_unicode_char(self.source, i64(index)));
    }

    def whitespace {
        while self.character(self.position) in [32, 9, 10, 13] {
            self.position += 1;
        }
    }

    def error(message: str, position: int) {
        type = required(jacpy_import_attr("json.decoder", "JSONDecodeError"));
        try {
            text = text_object(message);
            try {
                index = required(jacpy_int(i64(position)));
                try {
                    args = object_tuple([text, self.source, index]);
                    try {
                        error = required(jacpy_call(type, args, u64(0)));
                        try {
                            jacpy_set_object_exception(type, error);
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

    def stop(position: int) {
        index = required(jacpy_int(i64(position)));
        try {
            jacpy_raise_value("StopIteration", index);
        } finally {
            jacpy_release(index);
        }
        raise boundary_failure();
    }

    def hex_escape(start: int) -> int {
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

    def string -> u64 {
        begin = self.position - 1;
        writer = required(jacpy_writer_new());
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
                    jacpy_writer_slice(
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
            result = jacpy_writer_finish(writer);
            writer = 0;
            return required(result);
        } finally {
            if writer != 0 {
                jacpy_writer_discard(writer);
            }
        }
    }

    def matches(text: str) -> bool {
        for i in range(len(text)) {
            if self.character(self.position + i) != ord(text[i]) {
                return False;
            }
        }
        return True;
    }
}

obj json_scan {
    has input: json_input,
        memo: u64,
        object_hook: u64,
        pairs_hook: u64,
        parse_float: u64,
        parse_int: u64,
        parse_constant: u64;

    def number -> u64 {
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
            jacpy_unicode_slice(self.input.source, i64(start), i64(self.input.position))
        );
        try {
            return required(
                jacpy_call_one(self.parse_float if floating else self.parse_int, text)
            );
        } finally {
            jacpy_release(text);
        }
    }

    def array -> u64 {
        result = required(jacpy_list_new());
        try {
            self.input.position += 1;
            self.input.whitespace();
            if self.input.character(self.input.position) != 93 {
                while True {
                    value = self.value();
                    try {
                        checked(jacpy_list_append(result, value));
                    } finally {
                        jacpy_release(value);
                    }
                    self.input.whitespace();
                    if self.input.character(self.input.position) == 93 {
                        break;
                    }
                    if self.input.character(self.input.position) != 44 {
                        self.input.error(
                            "Expecting ',' delimiter", self.input.position
                        );
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

    def object -> u64 {
        pairs = jacpy_is_none(self.pairs_hook) == 0;
        result = required(jacpy_list_new() if pairs else jacpy_dict_new());
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
                    key: u64 = 0;
                    try {
                        key = required(
                            jacpy_dict_default(self.memo, original, original)
                        );
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
                                    checked(jacpy_list_append(result, item));
                                } finally {
                                    jacpy_release(item);
                                }
                            } else {
                                checked(jacpy_dict_set(result, key, value));
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
                        self.input.error(
                            "Expecting ',' delimiter", self.input.position
                        );
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
            if jacpy_is_none(hook) == 0 {
                return required(jacpy_call_one(hook, result));
            }
            return jacpy_retain(result);
        } finally {
            jacpy_release(result);
        }
    }

    def value -> u64 {
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
                jacpy_recursion_leave();
            }
        }
        if self.input.matches("null") {
            self.input.position += 4;
            return jacpy_none();
        }
        if self.input.matches("true") {
            self.input.position += 4;
            return jacpy_boolean(1);
        }
        if self.input.matches("false") {
            self.input.position += 5;
            return jacpy_boolean(0);
        }
        for constant in ["NaN", "Infinity", "-Infinity"] {
            if self.input.matches(constant) {
                self.input.position += len(constant);
                text = text_object(constant);
                try {
                    return required(jacpy_call_one(self.parse_constant, text));
                } finally {
                    jacpy_release(text);
                }
            }
        }
        return self.number();
    }
}

def:pub jacpy_json_scanstring(source: u64, end: i64, strict: i64) -> u64 {
    try {
        size = int(jacpy_unicode_size(source));
        if end < 0 or end > i64(size) {
            object_error("ValueError", "end is out of bounds");
            return 0;
        }
        input = json_input(source, size, int(end), strict != 0);
        value = input.string();
        return indexed(value, input.position);
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_json_scan(
    source: u64,
    start: i64,
    strict: i64,
    object_hook: u64,
    pairs_hook: u64,
    parse_float: u64,
    parse_int: u64,
    parse_constant: u64
) -> u64 {
    memo: u64 = 0;
    try {
        if start < 0 {
            object_error("ValueError", "idx cannot be negative");
            return 0;
        }
        input = json_input(
            source, int(jacpy_unicode_size(source)), int(start), strict != 0
        );
        memo = required(jacpy_dict_new());
        scanner = json_scan(
            input, memo, object_hook, pairs_hook, parse_float, parse_int, parse_constant
        );
        value = scanner.value();
        return indexed(value, input.position);
    } except boundary_failure {
        return 0;
    } finally {
        if memo != 0 {
            jacpy_release(memo);
        }
    }
}

import from jaclang.runtime.python.capi {
    type_name,
    jacpy_error_pending,
    repr_value,
    jacpy_is_unicode,
    jacpy_is_long,
    jacpy_is_bool,
    jacpy_is_float,
    jacpy_is_list,
    jacpy_is_tuple,
    jacpy_is_dict,
    jacpy_is_exact_dict,
    jacpy_long_repr,
    jacpy_float_repr,
    jacpy_float_value,
    jacpy_truth,
    jacpy_identity,
    serialization_note,
    jacpy_sequence_fast,
    jacpy_fast_size,
    jacpy_fast_item,
    jacpy_mapping_items,
    jacpy_list_size,
    jacpy_list_item,
    jacpy_list_sort,
    jacpy_dict_size,
    jacpy_dict_entry,
    jacpy_dict_remove,
    jacpy_contains,
    jacpy_tuple_item,
    jacpy_tuple_size,
    jacpy_integer_value,
    jacpy_unicode_concat,
    jacpy_sequence_repeat
}

def encoding_error(kind: str, message: str) {
    object_error(kind, message);
    raise boundary_failure();
}


obj json_output {
    has writer: u64,
        markers: u64,
        default_fn: u64,
        encoder: u64,
        indent: u64,
        key_separator: u64,
        item_separator: u64,
        sort_keys: bool,
        skipkeys: bool,
        allow_nan: bool,
        indent_cache: list[u64] = [];

    def initialize_indent(level: int) {
        if jacpy_is_none(self.indent) != 0 {
            return;
        }
        newline = text_object("\n");
        try {
            if level != 0 {
                repeated = required(jacpy_sequence_repeat(self.indent, i64(level)));
                try {
                    joined = required(jacpy_unicode_concat(newline, repeated));
                    jacpy_release(newline);
                    newline = joined;
                } finally {
                    jacpy_release(repeated);
                }
            }
            self.indent_cache.append(jacpy_retain(newline));
        } finally {
            jacpy_release(newline);
        }
    }

    def close {
        for item in self.indent_cache {
            jacpy_release(item);
        }
        self.indent_cache.clear();
    }

    def separator(level: int) -> u64 {
        if len(self.indent_cache) == 0 {
            return self.item_separator;
        }
        if level * 2 >= len(self.indent_cache) {
            newline = required(
                jacpy_unicode_concat(self.indent_cache[(level - 1) * 2], self.indent)
            );
            try {
                separator = required(
                    jacpy_unicode_concat(self.item_separator, newline)
                );
                self.indent_cache.append(separator);
                self.indent_cache.append(jacpy_retain(newline));
            } finally {
                jacpy_release(newline);
            }
        }
        return self.indent_cache[level * 2 - 1];
    }

    def newline(level: int) {
        checked(jacpy_writer_text(self.writer, self.indent_cache[level * 2]));
    }

    def mark(value: u64) -> u64 {
        if jacpy_is_none(self.markers) != 0 {
            return 0;
        }
        identity = required(jacpy_identity(value));
        try {
            found = jacpy_contains(self.markers, identity);
            checked(found);
            if found != 0 {
                encoding_error("ValueError", "Circular reference detected");
            }
            checked(jacpy_dict_set(self.markers, identity, value));
            return jacpy_retain(identity);
        } finally {
            jacpy_release(identity);
        }
    }

    def unmark(identity: u64) {
        if identity != 0 {
            checked(jacpy_dict_remove(self.markers, identity));
        }
    }

    def float_text(value: u64) -> u64 {
        number = jacpy_float_value(value);
        if number != number
            or number > 1.7976931348623157e308
            or number < -1.7976931348623157e308 {
            if not self.allow_nan {
                encoding_error(
                    "ValueError",
                    "Out of range float values are not JSON compliant: "
                        + repr_value(value)
                );
            }
            return text_object(
                "Infinity" if number > 0 else ("-Infinity" if number < 0 else "NaN")
            );
        }
        return required(jacpy_float_repr(value));
    }

    def string(value: u64) {
        encoded = required(jacpy_call_one(self.encoder, value));
        try {
            if jacpy_is_unicode(encoded) == 0 {
                encoding_error(
                    "TypeError",
                    "encoder() must return a string, not " + type_name(encoded)[:80]
                );
            }
            checked(jacpy_writer_text(self.writer, encoded));
        } finally {
            jacpy_release(encoded);
        }
    }

    def encode(value: u64, level: int) {
        if jacpy_is_none(value) != 0 {
            write_ascii(self.writer, "null");
        } elif jacpy_is_bool(value) != 0 {
            write_ascii(self.writer, "true" if jacpy_truth(value) != 0 else "false");
        } elif jacpy_is_unicode(value) != 0 {
            self.string(value);
        } elif jacpy_is_long(value) != 0 {
            text = required(jacpy_long_repr(value));
            try {
                checked(jacpy_writer_text(self.writer, text));
            } finally {
                jacpy_release(text);
            }
        } elif jacpy_is_float(value) != 0 {
            text = self.float_text(value);
            try {
                checked(jacpy_writer_text(self.writer, text));
            } finally {
                jacpy_release(text);
            }
        } elif jacpy_is_list(value) != 0 or jacpy_is_tuple(value) != 0 {
            checked(jacpy_recursion_enter(" while encoding a JSON object"));
            try {
                self.sequence(value, level);
            } finally {
                jacpy_recursion_leave();
            }
        } elif jacpy_is_dict(value) != 0 {
            checked(jacpy_recursion_enter(" while encoding a JSON object"));
            try {
                self.dictionary(value, level);
            } finally {
                jacpy_recursion_leave();
            }
        } else {
            identity = self.mark(value);
            try {
                replacement = required(jacpy_call_one(self.default_fn, value));
                try {
                    checked(jacpy_recursion_enter(" while encoding a JSON object"));
                    try {
                        self.encode(replacement, level);
                    } except boundary_failure {
                        serialization_note(value, u64(0), 0, 0);
                        raise;
                    } finally {
                        jacpy_recursion_leave();
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

    def sequence(value: u64, level: int) {
        sequence = required(
            jacpy_sequence_fast(value, "_iterencode_list needs a sequence")
        );
        identity: u64 = 0;
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
                        checked(jacpy_writer_text(self.writer, separator));
                    }
                    try {
                        self.encode(item, level);
                    } except boundary_failure {
                        serialization_note(value, u64(0), i, 1);
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

    def key_value(
        dictionary: u64, key: u64, value: u64, level: int, separator: u64, first: bool
    ) -> bool {
        text: u64 = 0;
        if jacpy_is_unicode(key) != 0 {
            text = jacpy_retain(key);
        } elif jacpy_is_float(key) != 0 {
            text = self.float_text(key);
        } elif jacpy_is_none(key) != 0 {
            text = text_object("null");
        } elif jacpy_is_bool(key) != 0 {
            text = text_object("true" if jacpy_truth(key) != 0 else "false");
        } elif jacpy_is_long(key) != 0 {
            text = required(jacpy_long_repr(key));
        } elif self.skipkeys {
            return first;
        } else {
            encoding_error(
                "TypeError",
                "keys must be str, int, float, bool or None, not "
                    + type_name(key)[:100]
            );
        }
        try {
            if first {
                if len(self.indent_cache) != 0 {
                    self.newline(level);
                }
            } else {
                checked(jacpy_writer_text(self.writer, separator));
            }
            self.string(text);
        } finally {
            jacpy_release(text);
        }
        checked(jacpy_writer_text(self.writer, self.key_separator));
        try {
            self.encode(value, level);
        } except boundary_failure {
            serialization_note(dictionary, key, 0, 2);
            raise;
        }
        return False;
    }

    def dictionary(value: u64, level: int) {
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
                items = required(jacpy_mapping_items(value));
                try {
                    if self.sort_keys {
                        checked(jacpy_list_sort(items));
                    }
                    i = 0;
                    while i < int(jacpy_list_size(items)) {
                        item = required(jacpy_list_item(items, i64(i)));
                        try {
                            if jacpy_is_tuple(item) == 0
                                or jacpy_tuple_size(item) != 2 {
                                encoding_error(
                                    "ValueError", "items must return 2-tuples"
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
                while True {
                    record = jacpy_dict_entry(value, position);
                    if record == 0 {
                        if jacpy_error_pending() != 0 {
                            raise boundary_failure();
                        }
                        break;
                    }
                    try {
                        index = required(jacpy_tuple_item(record, 0));
                        try {
                            position = jacpy_integer_value(index);
                        } finally {
                            jacpy_release(index);
                        }
                        key = required(jacpy_tuple_item(record, 1));
                        try {
                            child = required(jacpy_tuple_item(record, 2));
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
                        jacpy_release(record);
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
}

def:pub jacpy_json_encode(value: u64, level: i64, settings: u64, flags: i64) -> u64 {
    options: list[u64] = [];
    writer: u64 = 0;
    try {
        for i in range(6) {
            options.append(required(jacpy_tuple_item(settings, i64(i))));
        }
        writer = required(jacpy_writer_new());
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
        text = jacpy_writer_finish(writer);
        writer = 0;
        text = required(text);
        try {
            return object_tuple([text]);
        } finally {
            jacpy_release(text);
        }
    } except boundary_failure {
        return 0;
    } finally {
        if writer != 0 {
            jacpy_writer_discard(writer);
        }
        for option in options {
            jacpy_release(option);
        }
    }
}
