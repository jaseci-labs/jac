"""Native pickle serialization, memoization and reduction policy.

Python values are retained at the object boundary; protocol selection,
traversal, framing and callback orchestration execute in Jac machine code.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.modules.pickle_opcodes { opcode }
import from jaclang.runtime.python.modules.pickle_stream {
    pickle_writer,
    stream_error,
    builtin_stream_error
}
import from jaclang.runtime.python.modules.pickle_objects { global_names, mapped_names }
import from jaclang.runtime.python.capi {
    jacpy_is_iterator,
    type_name,
    serialization_note,
    repr_value,
    jacpy_is_dict,
    jacpy_add,
    jacpy_none,
    jacpy_not_implemented,
    jacpy_ellipsis,
    jacpy_error_is,
    builtin_kind,
    required,
    checked,
    boundary_failure,
    object_tuple,
    text_object,
    text_value,
    jacpy_builtin_kind,
    jacpy_retain,
    jacpy_release,
    jacpy_is_none,
    jacpy_is_tuple,
    jacpy_is_unicode,
    jacpy_is_type,
    jacpy_is_not_implemented,
    jacpy_mapping_optional_item,
    jacpy_dict_get,
    jacpy_dict_set,
    jacpy_dict_size,
    jacpy_tuple_item,
    jacpy_tuple_size,
    jacpy_tuple_slice,
    jacpy_list_size,
    jacpy_list_item,
    jacpy_bytearray_resize,
    jacpy_iter,
    jacpy_iter_next,
    jacpy_mapping_items,
    jacpy_sequence_list,
    jacpy_truth,
    jacpy_error_pending,
    jacpy_long_fits_i64,
    jacpy_integer_value,
    jacpy_long_bits,
    jacpy_long_sign,
    jacpy_long_signed_bytes,
    jacpy_long_repr,
    jacpy_uint,
    jacpy_int,
    jacpy_float_bits,
    jacpy_float_value,
    jacpy_float_repr,
    jacpy_bytes_length,
    jacpy_bytes_address,
    jacpy_memory_byte,
    jacpy_bytes_from_memory,
    jacpy_unicode_encode,
    jacpy_bytes_decode,
    jacpy_unicode_size,
    jacpy_unicode_char,
    jacpy_object_str,
    jacpy_call,
    jacpy_call_one,
    jacpy_callable,
    jacpy_getattr_string,
    jacpy_optional_attr,
    jacpy_object_type,
    jacpy_import_attr,
    jacpy_recursion_enter,
    jacpy_recursion_leave
}

obj pickle_state {
    has stream: pickle_writer = pickle_writer(),
        memo: u64 = 0,
        persistent_id: u64 = 0,
        reducer_override: u64 = 0,
        dispatch: u64 = 0,
        buffer_callback: u64 = 0,
        error: u64 = 0,
        protocol: int = 5,
        fix_imports: bool = True,
        fast: bool = False,
        active: set[u64] = set();

    def clear {
        self.stream.clear();
        self.active.clear();
        memo = self.memo;
        persistent = self.persistent_id;
        reducer = self.reducer_override;
        dispatch = self.dispatch;
        callback = self.buffer_callback;
        error = self.error;
        self.memo = 0;
        self.persistent_id = 0;
        self.reducer_override = 0;
        self.dispatch = 0;
        self.buffer_callback = 0;
        self.error = 0;
        jacpy_release(memo);
        jacpy_release(persistent);
        jacpy_release(reducer);
        jacpy_release(dispatch);
        jacpy_release(callback);
        jacpy_release(error);
    }

    def fail(message: str) {
        stream_error(self.error, message);
    }

    def emit(op: opcode) {
        self.stream.byte(op.value);
    }

    def ascii(text: str) {
        for ch in text {
            self.stream.byte(ord(ch));
        }
    }

    def encoded(value: u64, encoding: str, errors: str) {
        raw = required(jacpy_unicode_encode(value, encoding, errors));
        try {
            self.stream.data(raw);
        } finally {
            jacpy_release(raw);
        }
    }

    def recalled(value: u64) -> u64 {
        if self.fast {
            return 0;
        }
        key = required(jacpy_uint(value));
        try {
            saved = jacpy_dict_get(self.memo, key);
            if saved == 0 and jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            return saved;
        } finally {
            jacpy_release(key);
        }
    }

    def get(saved: u64) {
        index = required(jacpy_tuple_item(saved, 0));
        try {
            number = jacpy_integer_value(index);
            if jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            if self.protocol == 0 {
                self.emit(opcode.GET);
                self.ascii(str(number));
                self.stream.byte(10);
            } else {
                self.emit(opcode.BINGET if number < 256 else opcode.LONG_BINGET);
                self.stream.integer(u64(number), 1 if number < 256 else 4);
            }
        } finally {
            jacpy_release(index);
        }
    }

    def remember(value: u64) {
        if self.fast {
            return;
        }
        count = jacpy_dict_size(self.memo);
        key: u64 = 0;
        index: u64 = 0;
        pair: u64 = 0;
        try {
            key = required(jacpy_uint(value));
            index = required(jacpy_int(count));
            pair = object_tuple([index, value]);
            checked(jacpy_dict_set(self.memo, key, pair));
            if self.protocol >= 4 {
                self.emit(opcode.MEMOIZE);
            } elif self.protocol > 0 {
                self.emit(opcode.BINPUT if count < 256 else opcode.LONG_BINPUT);
                self.stream.integer(u64(count), 1 if count < 256 else 4);
            } else {
                self.emit(opcode.PUT);
                self.ascii(str(count));
                self.stream.byte(10);
            }
        } finally {
            jacpy_release(key);
            jacpy_release(index);
            jacpy_release(pair);
        }
    }

    def integer(value: u64) {
        small = jacpy_long_fits_i64(value) != 0;
        number: i64 = 0;
        if small {
            number = jacpy_integer_value(value);
            small = -2147483648 <= number <= 2147483647;
        }
        if small {
            if self.protocol == 0 {
                self.emit(opcode.INT);
                self.ascii(str(number));
                self.stream.byte(10);
            } else {
                width = 1 if 0 <= number <= 255 else 2 if 0 <= number <= 65535 else 4;
                self.emit(
                    opcode.BININT1
                        if width == 1
                        else opcode.BININT2 if width == 2 else opcode.BININT
                );
                self.stream.integer(u64.wrap(number), width);
            }
        } elif self.protocol < 2 {
            self.emit(opcode.LONG);
            text = required(jacpy_long_repr(value));
            try {
                self.encoded(text, "ascii", "strict");
            } finally {
                jacpy_release(text);
            }
            self.ascii("L\n");
        } else {
            size = jacpy_long_bits(value) // 8 + 1;
            if size > 2147483647 {
                builtin_stream_error("OverflowError", "int too large to pickle");
            }
            raw = required(jacpy_long_signed_bytes(value, size));
            try {
                address = jacpy_bytes_address(raw);
                if jacpy_long_sign(value) < 0
                    and size > 1
                    and jacpy_memory_byte(address, size - 1) == 255
                    and jacpy_memory_byte(address, size - 2) & 128 != 0 {
                    size -= 1;
                }
                self.emit(opcode.LONG1 if size < 256 else opcode.LONG4);
                self.stream.integer(u64(size), 1 if size < 256 else 4);
                self.stream.append(address, size);
            } finally {
                jacpy_release(raw);
            }
        }
    }

    def unicode(value: u64) {
        if self.protocol == 0 {
            self.emit(opcode.UNICODE);
            for i in range(int(jacpy_unicode_size(value))) {
                point = int(jacpy_unicode_char(value, i64(i)));
                if point < 256 and point not in [0, 10, 13, 26, 92] {
                    self.stream.byte(point);
                } else {
                    self.ascii("\\u" if point <= 65535 else "\\U");
                    for shift in range(12 if point <= 65535 else 28, -1, -4) {
                        self.stream.byte(
                            ord("0123456789abcdef"[(point >> shift) & 15])
                        );
                    }
                }
            }
            self.stream.byte(10);
        } else {
            raw = required(jacpy_unicode_encode(value, "utf-8", "surrogatepass"));
            try {
                self.blob(raw, builtin_kind.STR);
            } finally {
                jacpy_release(raw);
            }
        }
        self.remember(value);
    }

    def blob(raw: u64, kind: builtin_kind) {
        size = jacpy_bytes_length(raw);
        bypass = size >= 65536;
        framing = self.stream.framed;
        if bypass {
            self.stream.flush(True);
            self.stream.framed = False;
        }
        try {
            if kind == builtin_kind.BYTEARRAY {
                self.emit(opcode.BYTEARRAY8);
                self.stream.integer(u64(size), 8);
            } elif kind == builtin_kind.STR {
                width = 1
                    if self.protocol >= 4 and size <= 255
                    else 4 if size <= 4294967295 else 8;
                self.emit(
                    opcode.SHORT_BINUNICODE
                        if width == 1
                        else opcode.BINUNICODE if width == 4 else opcode.BINUNICODE8
                );
                self.stream.integer(u64(size), width);
            } else {
                width = 1 if size <= 255 else 4 if size <= 4294967295 else 8;
                self.emit(
                    opcode.SHORT_BINBYTES
                        if width == 1
                        else opcode.BINBYTES if width == 4 else opcode.BINBYTES8
                );
                self.stream.integer(u64(size), width);
            }
            if bypass {
                self.stream.flush(True);
                self.stream.send(raw);
            } else {
                self.stream.data(raw);
            }
        } finally {
            self.stream.framed = framing;
        }
    }

    def bytes(value: u64, mutable: bool) {
        if (mutable and self.protocol >= 5) or (not mutable and self.protocol >= 3) {
            raw = required(
                jacpy_bytes_from_memory(
                    jacpy_bytes_address(value), jacpy_bytes_length(value)
                )
            );
            try {
                self.blob(
                    raw, builtin_kind.BYTEARRAY if mutable else builtin_kind.BYTES
                );
            } finally {
                jacpy_release(raw);
            }
            self.remember(value);
            return;
        }
        callable: u64 = 0;
        args: u64 = 0;
        content: u64 = 0;
        encoding: u64 = 0;
        try {
            if mutable {
                callable = required(jacpy_object_type(value));
                if jacpy_bytes_length(value) == 0 {
                    args = object_tuple([]);
                } else {
                    content = required(
                        jacpy_bytes_from_memory(
                            jacpy_bytes_address(value), jacpy_bytes_length(value)
                        )
                    );
                    args = object_tuple([content]);
                }
            } elif jacpy_bytes_length(value) == 0 {
                callable = required(jacpy_object_type(value));
                args = object_tuple([]);
            } else {
                callable = required(jacpy_import_attr("_codecs", "encode"));
                content = required(jacpy_bytes_decode(value, "latin1", "strict"));
                encoding = text_object("latin1");
                args = object_tuple([content, encoding]);
            }
            self.reduce_call(callable, args, value);
        } finally {
            jacpy_release(callable);
            jacpy_release(args);
            jacpy_release(content);
            jacpy_release(encoding);
        }
    }

    def tuple(value: u64) {
        count = int(jacpy_tuple_size(value));
        if count == 0 {
            if self.protocol == 0 {
                self.emit(opcode.MARK);
                self.emit(opcode.TUPLE);
            } else {
                self.emit(opcode.EMPTY_TUPLE);
            }
            return;
        }
        compact = self.protocol >= 2 and count <= 3;
        if not compact {
            self.emit(opcode.MARK);
        }
        for i in range(count) {
            item = required(jacpy_tuple_item(value, i64(i)));
            try {
                self.save(item, True);
            } except boundary_failure {
                serialization_note(value, 0, i, 1);
                raise boundary_failure();
            } finally {
                jacpy_release(item);
            }
        }
        previous = self.recalled(value);
        if previous != 0 {
            try {
                if compact {
                    for _ in range(count) {
                        self.emit(opcode.POP);
                    }
                } elif self.protocol == 0 {
                    # POP_MARK belongs to protocol 1. Pop each item and the
                    # leading mark explicitly for a recursive protocol-0 tuple.
                    for _ in range(count + 1) {
                        self.emit(opcode.POP);
                    }
                } else {
                    self.emit(opcode.POP_MARK);
                }
                self.get(previous);
                return;
            } finally {
                jacpy_release(previous);
            }
        }
        if compact {
            self.stream.byte(opcode.TUPLE1.value + count - 1);
        } else {
            self.emit(opcode.TUPLE);
        }
        self.remember(value);
    }

    def batch(iterator: u64, mapping: bool, owner: u64) {
        if jacpy_is_iterator(iterator) == 0 {
            self.fail(
                ("fifth" if mapping else "fourth")
                    + " item of the tuple returned by __reduce__ must be an iterator, not "
                    + type_name(iterator)
            );
        }
        offset = 0;
        while True {
            items: list[u64] = [];
            try {
                for _ in range(1 if self.protocol == 0 else 1000) {
                    item = jacpy_iter_next(iterator);
                    if item == 0 {
                        if jacpy_error_pending() != 0 {
                            raise boundary_failure();
                        }
                        break;
                    }
                    items.append(item);
                }
                if not items {
                    return;
                }
                if len(items) > 1 {
                    self.emit(opcode.MARK);
                }
                for item in items {
                    if mapping {
                        if jacpy_is_tuple(item) == 0 or jacpy_tuple_size(item) != 2 {
                            builtin_stream_error(
                                "TypeError", "dict items iterator must return 2-tuples"
                            );
                        }
                        key = required(jacpy_tuple_item(item, 0));
                        val: u64 = 0;
                        try {
                            val = required(jacpy_tuple_item(item, 1));
                            try {
                                self.save(key, True);
                                self.save(val, True);
                            } except boundary_failure {
                                serialization_note(owner, key, 0, 2);
                                raise boundary_failure();
                            }
                        } finally {
                            jacpy_release(key);
                            jacpy_release(val);
                        }
                    } else {
                        try {
                            self.save(item, True);
                        } except boundary_failure {
                            serialization_note(owner, 0, offset, 1);
                            raise boundary_failure();
                        }
                    }
                    offset += 1;
                }
                self.emit(
                    (opcode.SETITEM if len(items) == 1 else opcode.SETITEMS)
                        if mapping
                        else (opcode.APPEND if len(items) == 1 else opcode.APPENDS)
                );
            } finally {
                for item in items {
                    jacpy_release(item);
                }
            }
        }
    }

    def global_identifier(value: u64, module: bool) {
        try {
            self.encoded(value, "utf-8" if self.protocol >= 3 else "ascii", "strict");
        } except boundary_failure {
            if jacpy_error_is("UnicodeEncodeError") != 0 {
                self.fail(
                    "can't pickle "
                        + ("module" if module else "global")
                        + " identifier "
                        + repr_value(value)
                        + " using pickle protocol "
                        + str(self.protocol)
                );
            }
            raise boundary_failure();
        }
    }

    def global(value: u64, preferred: u64) {
        names = global_names(value, preferred, self.error);
        module: u64 = 0;
        name: u64 = 0;
        try {
            module = required(jacpy_tuple_item(names, 0));
            name = required(jacpy_tuple_item(names, 1));
            if self.protocol >= 2 {
                registry = required(
                    jacpy_import_attr("copyreg", "_extension_registry")
                );
                code: u64 = 0;
                try {
                    code = jacpy_dict_get(registry, names);
                    if code == 0 and jacpy_error_pending() != 0 {
                        raise boundary_failure();
                    }
                    if code != 0 {
                        number = jacpy_integer_value(code);
                        if jacpy_error_pending() != 0 {
                            raise boundary_failure();
                        }
                        if number <= 0 or number > 2147483647 {
                            builtin_stream_error(
                                "RuntimeError", "extension code is out of range"
                            );
                        }
                        width = 1 if number <= 255 else 2 if number <= 65535 else 4;
                        self.emit(
                            opcode.EXT1
                                if width == 1
                                else opcode.EXT2 if width == 2 else opcode.EXT4
                        );
                        self.stream.integer(u64(number), width);
                        return;
                    }
                } finally {
                    jacpy_release(registry);
                    jacpy_release(code);
                }
            }
            if self.protocol >= 4 {
                self.save(module, True);
                self.save(name, True);
                self.emit(opcode.STACK_GLOBAL);
            } else {
                # Emit a getattr chain around the root GLOBAL. Serializing an
                # intermediate attribute object can recurse back to this global
                # or attempt to pickle a module instead of its qualified name.
                parts = text_value(name).split(".");
                root_name = text_object(parts[0]);
                try {
                    if len(parts) > 1 {
                        attribute_get = required(
                            jacpy_import_attr("builtins", "getattr")
                        );
                        try {
                            for _ in range(1, len(parts)) {
                                self.save(attribute_get, False);
                                if self.protocol < 2 {
                                    self.emit(opcode.MARK);
                                }
                            }
                        } finally {
                            jacpy_release(attribute_get);
                        }
                    }
                    mapped = mapped_names(module, root_name, True)
                        if self.protocol < 3 and self.fix_imports
                        else object_tuple([module, root_name]);
                    mapped_module: u64 = 0;
                    mapped_name: u64 = 0;
                    try {
                        mapped_module = required(jacpy_tuple_item(mapped, 0));
                        mapped_name = required(jacpy_tuple_item(mapped, 1));
                        self.emit(opcode.GLOBAL);
                        self.global_identifier(mapped_module, True);
                        self.stream.byte(10);
                        self.global_identifier(mapped_name, False);
                        self.stream.byte(10);
                    } finally {
                        jacpy_release(mapped);
                        jacpy_release(mapped_module);
                        jacpy_release(mapped_name);
                    }
                    for i in range(1, len(parts)) {
                        leaf = text_object(parts[i]);
                        try {
                            self.save(leaf, False);
                        } finally {
                            jacpy_release(leaf);
                        }
                        self.emit(opcode.TUPLE if self.protocol < 2 else opcode.TUPLE2);
                        self.emit(opcode.REDUCE);
                    }
                } finally {
                    jacpy_release(root_name);
                }
            }
            self.remember(value);
        } finally {
            jacpy_release(names);
            jacpy_release(module);
            jacpy_release(name);
        }
    }

    def reduce_call(callable: u64, args: u64, value: u64) {
        self.save_context(callable, value, "reconstructor");
        self.save_context(args, value, "reconstructor arguments");
        self.emit(opcode.REDUCE);
        if value != 0 {
            previous = self.recalled(value);
            if previous != 0 {
                try {
                    self.emit(opcode.POP);
                    self.get(previous);
                } finally {
                    jacpy_release(previous);
                }
            } else {
                self.remember(value);
            }
        }
    }

    def reduction(value: u64, reduced: u64) {
        if jacpy_is_unicode(reduced) != 0 {
            self.global(value, reduced);
            return;
        }
        try {
            self.reduce_value(value, reduced);
        } except boundary_failure {
            serialization_note(value, 0, 0, 0);
            raise boundary_failure();
        }
    }

    def save_context(value: u64, owner: u64, detail: str) {
        try {
            self.save(value, True);
        } except boundary_failure {
            serialization_note(owner, 0, 0, 0, detail);
            raise boundary_failure();
        }
    }

    def remember_constructed(value: u64) {
        previous = self.recalled(value);
        if previous != 0 {
            try {
                self.emit(opcode.POP);
                self.get(previous);
            } finally {
                jacpy_release(previous);
            }
        } else {
            self.remember(value);
        }
    }

    def reduce_value(value: u64, reduced: u64) {
        if jacpy_is_unicode(reduced) != 0 {
            self.global(value, reduced);
            return;
        }
        if jacpy_is_tuple(reduced) == 0 {
            self.fail(
                "__reduce__ must return a string or tuple, not "
                    + type_name(reduced, True)
            );
        }
        count = int(jacpy_tuple_size(reduced));
        if count < 2 or count > 6 {
            self.fail("tuple returned by __reduce__ must contain 2 through 6 elements");
        }
        callable = required(jacpy_tuple_item(reduced, 0));
        args: u64 = 0;
        try {
            args = required(jacpy_tuple_item(reduced, 1));
            if jacpy_callable(callable) == 0 {
                self.fail(
                    "first item of the tuple returned by __reduce__ must be callable, not "
                        + type_name(callable, True)
                );
            }
            if jacpy_is_tuple(args) == 0 {
                self.fail(
                    "second item of the tuple returned by __reduce__ must be a tuple, not "
                        + type_name(args, True)
                );
            }
            name = jacpy_optional_attr(callable, "__name__");
            if jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            special = "";
            if name != 0 {
                try {
                    if jacpy_is_unicode(name) != 0 {
                        special = text_value(name);
                    }
                } finally {
                    jacpy_release(name);
                }
            }
            if self.protocol >= 2 and special == "__newobj__" {
                if jacpy_tuple_size(args) < 1 {
                    self.fail("__newobj__ expected at least 1 argument, got 0");
                }
                cls = required(jacpy_tuple_item(args, 0));
                rest: u64 = 0;
                actual: u64 = 0;
                try {
                    if jacpy_is_type(cls) == 0 {
                        self.fail(
                            "first argument to "
                                + special
                                + "() must be a class, not "
                                + type_name(cls, True)
                        );
                    }
                    actual = required(jacpy_getattr_string(value, "__class__"));
                    if cls != actual {
                        self.fail(
                            "first argument to __newobj__() must be "
                                + repr_value(actual)
                                + ", not "
                                + repr_value(cls)
                        );
                    }
                    rest = required(jacpy_tuple_slice(args, 1, jacpy_tuple_size(args)));
                    self.save_context(cls, value, "class");
                    self.save_context(rest, value, "__new__ arguments");
                    self.emit(opcode.NEWOBJ);
                } finally {
                    jacpy_release(cls);
                    jacpy_release(rest);
                    jacpy_release(actual);
                }
                self.remember_constructed(value);
            } elif self.protocol >= 2 and special == "__newobj_ex__" {
                if jacpy_tuple_size(args) != 3 {
                    self.fail(
                        "__newobj_ex__ expected 3 arguments, got "
                            + str(jacpy_tuple_size(args))
                    );
                }
                cls = required(jacpy_tuple_item(args, 0));
                positional: u64 = 0;
                keywords: u64 = 0;
                actual: u64 = 0;
                try {
                    if jacpy_is_type(cls) == 0 {
                        self.fail(
                            "first argument to "
                                + special
                                + "() must be a class, not "
                                + type_name(cls, True)
                        );
                    }
                    actual = required(jacpy_getattr_string(value, "__class__"));
                    if cls != actual {
                        self.fail(
                            "first argument to __newobj_ex__() must be "
                                + repr_value(actual)
                                + ", not "
                                + repr_value(cls)
                        );
                    }
                    positional = required(jacpy_tuple_item(args, 1));
                    keywords = required(jacpy_tuple_item(args, 2));
                    if jacpy_is_tuple(positional) == 0 {
                        self.fail(
                            "second argument to __newobj_ex__() must be a tuple, not "
                                + type_name(positional, True)
                        );
                    }
                    if jacpy_is_dict(keywords) == 0 {
                        self.fail(
                            "third argument to __newobj_ex__() must be a dict, not "
                                + type_name(keywords, True)
                        );
                    }
                    if self.protocol >= 4 {
                        self.save_context(cls, value, "class");
                        self.save_context(positional, value, "__new__ arguments");
                        self.save_context(keywords, value, "__new__ arguments");
                        self.emit(opcode.NEWOBJ_EX);
                    } else {
                        partial_type = required(
                            jacpy_import_attr("functools", "partial")
                        );
                        new_method: u64 = 0;
                        prefix: u64 = 0;
                        combined: u64 = 0;
                        partial: u64 = 0;
                        empty: u64 = 0;
                        try {
                            new_method = required(jacpy_getattr_string(cls, "__new__"));
                            prefix = object_tuple([new_method, cls]);
                            combined = required(jacpy_add(prefix, positional));
                            partial = required(
                                jacpy_call(partial_type, combined, keywords)
                            );
                            self.save_context(partial, value, "reconstructor");
                            empty = object_tuple([]);
                            self.save(empty, True);
                            self.emit(opcode.REDUCE);
                        } finally {
                            jacpy_release(partial_type);
                            jacpy_release(new_method);
                            jacpy_release(prefix);
                            jacpy_release(combined);
                            jacpy_release(partial);
                            jacpy_release(empty);
                        }
                    }
                } finally {
                    jacpy_release(cls);
                    jacpy_release(positional);
                    jacpy_release(keywords);
                    jacpy_release(actual);
                }
                self.remember_constructed(value);
            } else {
                self.reduce_call(callable, args, value);
            }
            for position in range(3, 5) {
                if count <= position {
                    break;
                }
                iterator = required(jacpy_tuple_item(reduced, i64(position)));
                try {
                    if jacpy_is_none(iterator) == 0 {
                        self.batch(iterator, position == 4, value);
                    }
                } finally {
                    jacpy_release(iterator);
                }
            }
            if count >= 3 {
                state = required(jacpy_tuple_item(reduced, 2));
                state_set: u64 = 0;
                try {
                    if jacpy_is_none(state) != 0 {
                        return;
                    }
                    if count == 6 {
                        state_set = required(jacpy_tuple_item(reduced, 5));
                    }
                    if state_set == 0 or jacpy_is_none(state_set) != 0 {
                        self.save_context(state, value, "state");
                        self.emit(opcode.BUILD);
                    } else {
                        if jacpy_callable(state_set) == 0 {
                            self.fail(
                                "sixth item of the tuple returned by __reduce__ must be callable, not "
                                    + type_name(state_set, True)
                            );
                        }
                        self.save_context(state_set, value, "state setter");
                        if self.protocol < 2 {
                            self.emit(opcode.MARK);
                        }
                        self.save(value, True);
                        self.save_context(state, value, "state");
                        self.emit(opcode.TUPLE if self.protocol < 2 else opcode.TUPLE2);
                        self.emit(opcode.REDUCE);
                        self.emit(opcode.POP);
                    }
                } finally {
                    jacpy_release(state);
                    jacpy_release(state_set);
                }
            }
        } finally {
            jacpy_release(callable);
            jacpy_release(args);
        }
    }

    def save_type(value: u64) {
        singletons = [jacpy_none(), jacpy_not_implemented(), jacpy_ellipsis()];
        try {
            for singleton in singletons {
                cls = required(jacpy_object_type(singleton));
                try {
                    if cls == value {
                        type_type = required(jacpy_object_type(cls));
                        args: u64 = 0;
                        try {
                            args = object_tuple([singleton]);
                            self.reduce_call(type_type, args, value);
                            return;
                        } finally {
                            jacpy_release(type_type);
                            jacpy_release(args);
                        }
                    }
                } finally {
                    jacpy_release(cls);
                }
            }
        } finally {
            for singleton in singletons {
                jacpy_release(singleton);
            }
        }
        self.global(value, 0);
    }

    def other(value: u64, kind: int) {
        reduced: u64 = 0;
        reducer: u64 = 0;
        cls: u64 = 0;
        try {
            if self.reducer_override != 0 {
                reduced = required(jacpy_call_one(self.reducer_override, value));
                if jacpy_is_not_implemented(reduced) == 0 {
                    self.reduction(value, reduced);
                    return;
                }
                jacpy_release(reduced);
                reduced = 0;
            }
            if kind == builtin_kind.TYPE.value {
                self.save_type(value);
                return;
            }
            if kind == builtin_kind.FUNCTION.value {
                self.global(value, 0);
                return;
            }
            cls = required(jacpy_object_type(value));
            reducer = jacpy_mapping_optional_item(self.dispatch, cls);
            if reducer == 0 and jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            if reducer != 0 {
                reduced = required(jacpy_call_one(reducer, value));
            } elif jacpy_is_type(value) != 0 {
                self.global(value, 0);
                return;
            } else {
                reducer = jacpy_optional_attr(value, "__reduce_ex__");
                if jacpy_error_pending() != 0 {
                    raise boundary_failure();
                }
                if reducer != 0 {
                    protocol = required(jacpy_int(i64(self.protocol)));
                    try {
                        reduced = required(jacpy_call_one(reducer, protocol));
                    } finally {
                        jacpy_release(protocol);
                    }
                } else {
                    reducer = required(jacpy_getattr_string(value, "__reduce__"));
                    args = object_tuple([]);
                    try {
                        reduced = required(jacpy_call(reducer, args, 0));
                    } finally {
                        jacpy_release(args);
                    }
                }
            }
            self.reduction(value, reduced);
        } finally {
            jacpy_release(reduced);
            jacpy_release(reducer);
            jacpy_release(cls);
        }
    }

    def pickle_buffer(value: u64) {
        if self.protocol < 5 {
            self.fail("PickleBuffer can only be pickled with protocol >= 5");
        }
        method = required(jacpy_getattr_string(value, "raw"));
        arguments: u64 = 0;
        view: u64 = 0;
        readonly: u64 = 0;
        bytes_method: u64 = 0;
        raw: u64 = 0;
        try {
            arguments = object_tuple([]);
            view = required(jacpy_call(method, arguments, 0));
            readonly = required(jacpy_getattr_string(view, "readonly"));
            truth = jacpy_truth(readonly);
            checked(truth);
            in_band: i64 = 1;
            if self.buffer_callback != 0 {
                result = required(jacpy_call_one(self.buffer_callback, value));
                try {
                    in_band = jacpy_truth(result);
                    checked(in_band);
                } finally {
                    jacpy_release(result);
                }
            }
            if in_band == 0 {
                self.emit(opcode.NEXT_BUFFER);
                if truth != 0 {
                    self.emit(opcode.READONLY_BUFFER);
                }
            } else {
                bytes_method = required(jacpy_getattr_string(view, "tobytes"));
                raw = required(jacpy_call(bytes_method, arguments, 0));
                self.blob(
                    raw, builtin_kind.BYTES if truth != 0 else builtin_kind.BYTEARRAY
                );
                self.remember(value);
            }
        } finally {
            jacpy_release(method);
            jacpy_release(arguments);
            jacpy_release(view);
            jacpy_release(readonly);
            jacpy_release(bytes_method);
            jacpy_release(raw);
        }
    }

    def dump(value: u64) {
        checked(jacpy_bytearray_resize(self.stream.buffer, 0));
        self.stream.framed = False;
        if self.protocol >= 2 {
            self.emit(opcode.PROTO);
            self.stream.byte(self.protocol);
            self.stream.flush(True);
        }
        self.stream.framed = self.protocol >= 4;
        self.save(value, True);
        self.emit(opcode.STOP);
        self.stream.flush(True);
    }

    def save(value: u64, persistent: bool) {
        self.stream.flush(False);
        if persistent and self.persistent_id != 0 {
            pid = required(jacpy_call_one(self.persistent_id, value));
            try {
                if jacpy_is_none(pid) == 0 {
                    if self.protocol > 0 {
                        self.save(pid, False);
                        self.emit(opcode.BINPERSID);
                    } else {
                        text = required(jacpy_object_str(pid));
                        try {
                            self.emit(opcode.PERSID);
                            try {
                                self.encoded(text, "ascii", "strict");
                            } except boundary_failure {
                                if jacpy_error_is("UnicodeEncodeError") != 0 {
                                    self.fail(
                                        "persistent IDs in protocol 0 must be ASCII strings"
                                    );
                                }
                                raise boundary_failure();
                            }
                            self.stream.byte(10);
                        } finally {
                            jacpy_release(text);
                        }
                    }
                    return;
                }
            } finally {
                jacpy_release(pid);
            }
        }
        kind = int(jacpy_builtin_kind(value));
        if kind == builtin_kind.NONE.value {
            self.emit(opcode.NONE);
            return;
        }
        if kind == builtin_kind.BOOL.value {
            truth = jacpy_truth(value);
            if self.protocol >= 2 {
                self.emit(opcode.NEWTRUE if truth != 0 else opcode.NEWFALSE);
            } else {
                self.ascii("I01\n" if truth != 0 else "I00\n");
            }
            return;
        }
        if kind == builtin_kind.INT.value {
            self.integer(value);
            return;
        }
        if kind == builtin_kind.FLOAT.value {
            if self.protocol > 0 {
                self.emit(opcode.BINFLOAT);
                bits = jacpy_float_bits(jacpy_float_value(value));
                for i in range(7, -1, -1) {
                    self.stream.byte(int((bits >> (i * 8)) & 255));
                }
            } else {
                self.emit(opcode.FLOAT);
                text = required(jacpy_float_repr(value));
                try {
                    self.encoded(text, "ascii", "strict");
                    self.stream.byte(10);
                } finally {
                    jacpy_release(text);
                }
            }
            return;
        }
        previous = self.recalled(value);
        if previous != 0 {
            try {
                self.get(previous);
                return;
            } finally {
                jacpy_release(previous);
            }
        }
        if kind == builtin_kind.BYTES.value {
            self.bytes(value, False);
            return;
        }
        if kind == builtin_kind.STR.value {
            self.unicode(value);
            return;
        }
        checked(jacpy_recursion_enter(" while pickling an object"));
        try {
            if self.fast {
                if value in self.active {
                    builtin_stream_error(
                        "ValueError", "fast mode: can't pickle cyclic objects"
                    );
                }
                self.active.add(value);
            }
            if kind == builtin_kind.TUPLE.value {
                self.tuple(value);
            } elif kind == builtin_kind.LIST.value or kind == builtin_kind.DICT.value {
                if self.protocol == 0 {
                    self.emit(opcode.MARK);
                    self.emit(
                        opcode.LIST if kind == builtin_kind.LIST.value else opcode.DICT
                    );
                } else {
                    self.emit(
                        opcode.EMPTY_LIST
                            if kind == builtin_kind.LIST.value
                            else opcode.EMPTY_DICT
                    );
                }
                self.remember(value);
                iterable: u64 = 0;
                iterator: u64 = 0;
                try {
                    iterable = jacpy_mapping_items(value)
                        if kind == builtin_kind.DICT.value
                        else jacpy_retain(value);
                    iterator = required(jacpy_iter(required(iterable)));
                    self.batch(iterator, kind == builtin_kind.DICT.value, value);
                } finally {
                    jacpy_release(iterable);
                    jacpy_release(iterator);
                }
            } elif kind == builtin_kind.BYTEARRAY.value {
                self.bytes(value, True);
            } elif kind == builtin_kind.SET.value
                or kind == builtin_kind.FROZENSET.value {
                values = required(jacpy_sequence_list(value));
                try {
                    if self.protocol < 4 {
                        cls = required(jacpy_object_type(value));
                        args: u64 = 0;
                        try {
                            args = object_tuple([values]);
                            self.reduce_call(cls, args, value);
                        } finally {
                            jacpy_release(cls);
                            jacpy_release(args);
                        }
                    } else {
                        if kind == builtin_kind.SET.value {
                            self.emit(opcode.EMPTY_SET);
                            self.remember(value);
                        }
                        frozen = kind == builtin_kind.FROZENSET.value;
                        count = int(jacpy_list_size(values));
                        if frozen {
                            self.emit(opcode.MARK);
                        }
                        for i in range(count) {
                            if not frozen and i % 1000 == 0 {
                                self.emit(opcode.MARK);
                            }
                            item = required(jacpy_list_item(values, i64(i)));
                            try {
                                self.save(item, True);
                            } except boundary_failure {
                                serialization_note(value, 0, 0, 0, "element");
                                raise boundary_failure();
                            } finally {
                                jacpy_release(item);
                            }
                            if not frozen and (i % 1000 == 999 or i == count - 1) {
                                self.emit(opcode.ADDITEMS);
                            }
                        }
                        if frozen {
                            saved = self.recalled(value);
                            if saved != 0 {
                                try {
                                    self.emit(opcode.POP_MARK);
                                    self.get(saved);
                                } finally {
                                    jacpy_release(saved);
                                }
                            } else {
                                self.emit(opcode.FROZENSET);
                                self.remember(value);
                            }
                        }
                    }
                } finally {
                    jacpy_release(values);
                }
            } elif kind == builtin_kind.PICKLE_BUFFER.value {
                self.pickle_buffer(value);
            } else {
                self.other(value, kind);
            }
        } finally {
            if self.fast {
                self.active.discard(value);
            }
            jacpy_recursion_leave();
        }
    }
}
