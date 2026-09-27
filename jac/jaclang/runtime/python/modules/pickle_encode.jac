"""Native pickle serialization, memoization and reduction policy.

Python values are retained at the object boundary; protocol selection,
traversal, framing and callback orchestration execute in Jac machine code.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyByteArray_Resize,
    PyCallable_Check,
    PyDict_SetItem,
    PyImport_ImportModuleAttrString,
    PyIter_Check,
    PyIter_Next,
    PyList_GetItemRef,
    PyLong_AsLongLong,
    PyLong_FromLongLong,
    PyLong_FromUnsignedLongLong,
    PyLong_FromVoidPtr,
    PyMapping_Items,
    PyNumber_Add,
    PyObject,
    PyObject_Call,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PyObject_GetIter,
    PyObject_IsTrue,
    PyObject_Str,
    PySequence_List,
    PyTuple_GetSlice,
    PyTuple_Size,
    PyUnicode_AsEncodedString,
    PyUnicode_ReadChar,
    Py_LeaveRecursiveCall,
    Py_NewRef,
    _PyLong_NumBits,
    jacpy_builtin_kind,
    jacpy_bytes_address,
    jacpy_bytes_decode,
    jacpy_bytes_from_memory,
    jacpy_bytes_length,
    jacpy_dict_get,
    jacpy_dict_size,
    jacpy_ellipsis,
    jacpy_error_is,
    jacpy_error_pending,
    jacpy_float_bits,
    jacpy_float_repr,
    jacpy_float_value,
    jacpy_is_dict,
    jacpy_is_none,
    jacpy_is_not_implemented,
    jacpy_is_tuple,
    jacpy_is_type,
    jacpy_is_unicode,
    jacpy_list_size,
    jacpy_long_fits_i64,
    jacpy_long_repr,
    jacpy_long_sign,
    jacpy_long_signed_bytes,
    jacpy_mapping_optional_item,
    jacpy_memory_byte,
    jacpy_none,
    jacpy_not_implemented,
    jacpy_object_type,
    jacpy_optional_attr,
    jacpy_recursion_enter,
    jacpy_release,
    jacpy_tuple_item,
    jacpy_unicode_size
}
import from jaclang.runtime.python.modules.pickle_opcodes { opcode }
import from jaclang.runtime.python.modules.pickle_stream {
    pickle_writer,
    stream_error,
    builtin_stream_error
}
import from jaclang.runtime.python.modules.pickle_objects { global_names, mapped_names }
import from jaclang.runtime.python.capi {
    type_name,
    serialization_note,
    repr_value,
    builtin_kind,
    required,
    checked,
    boundary_failure,
    object_tuple,
    text_object,
    text_value
}

obj pickle_state {
    has stream: pickle_writer = pickle_writer(),
        memo: ptr[PyObject] = NULL,
        persistent_id: ptr[PyObject] = NULL,
        reducer_override: ptr[PyObject] = NULL,
        dispatch: ptr[PyObject] = NULL,
        buffer_callback: ptr[PyObject] = NULL,
        error: ptr[PyObject] = NULL,
        protocol: int = 5,
        fix_imports: bool = True,
        fast: bool = False,
        active: set[ptr[PyObject]] = set();

    def clear {
        self.stream.clear();
        self.active.clear();
        memo = self.memo;
        persistent = self.persistent_id;
        reducer = self.reducer_override;
        dispatch = self.dispatch;
        callback = self.buffer_callback;
        error = self.error;
        self.memo = NULL;
        self.persistent_id = NULL;
        self.reducer_override = NULL;
        self.dispatch = NULL;
        self.buffer_callback = NULL;
        self.error = NULL;
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

    def encoded(value: ptr[PyObject], encoding: str, errors: str) {
        raw = required(PyUnicode_AsEncodedString(value, encoding, errors));
        try {
            self.stream.data(raw);
        } finally {
            jacpy_release(raw);
        }
    }

    def recalled(value: ptr[PyObject]) -> ptr[PyObject] {
        if self.fast {
            return NULL;
        }
        key = required(PyLong_FromVoidPtr(value));
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

    def get(saved: ptr[PyObject]) {
        index = required(jacpy_tuple_item(saved, 0));
        try {
            number = PyLong_AsLongLong(index);
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

    def remember(value: ptr[PyObject]) {
        if self.fast {
            return;
        }
        count = jacpy_dict_size(self.memo);
        key: ptr[PyObject] = NULL;
        index: ptr[PyObject] = NULL;
        pair: ptr[PyObject] = NULL;
        try {
            key = required(PyLong_FromVoidPtr(value));
            index = required(PyLong_FromLongLong(count));
            pair = object_tuple([index, value]);
            checked(PyDict_SetItem(self.memo, key, pair));
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

    def integer(value: ptr[PyObject]) {
        small = jacpy_long_fits_i64(value) != 0;
        number: i64 = 0;
        if small {
            number = PyLong_AsLongLong(value);
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
            size = _PyLong_NumBits(value) // 8 + 1;
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

    def unicode(value: ptr[PyObject]) {
        if self.protocol == 0 {
            self.emit(opcode.UNICODE);
            for i in range(int(jacpy_unicode_size(value))) {
                point = int(PyUnicode_ReadChar(value, i64(i)));
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
            raw = required(PyUnicode_AsEncodedString(value, "utf-8", "surrogatepass"));
            try {
                self.blob(raw, builtin_kind.STR);
            } finally {
                jacpy_release(raw);
            }
        }
        self.remember(value);
    }

    def blob(raw: ptr[PyObject], kind: builtin_kind) {
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

    def bytes(value: ptr[PyObject], mutable: bool) {
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
        callable: ptr[PyObject] = NULL;
        args: ptr[PyObject] = NULL;
        content: ptr[PyObject] = NULL;
        encoding: ptr[PyObject] = NULL;
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
                callable = required(
                    PyImport_ImportModuleAttrString("_codecs", "encode")
                );
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

    def tuple(value: ptr[PyObject]) {
        count = int(PyTuple_Size(value));
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
                serialization_note(value, NULL, i, 1);
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

    def batch(iterator: ptr[PyObject], mapping: bool, owner: ptr[PyObject]) {
        if PyIter_Check(iterator) == 0 {
            self.fail(
                ("fifth" if mapping else "fourth")
                    + " item of the tuple returned by __reduce__ must be an iterator, not "
                    + type_name(iterator)
            );
        }
        offset = 0;
        while True {
            items: list[ptr[PyObject]] = [];
            try {
                for _ in range(1 if self.protocol == 0 else 1000) {
                    item = PyIter_Next(iterator);
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
                        if jacpy_is_tuple(item) == 0 or PyTuple_Size(item) != 2 {
                            builtin_stream_error(
                                "TypeError", "dict items iterator must return 2-tuples"
                            );
                        }
                        key = required(jacpy_tuple_item(item, 0));
                        val: ptr[PyObject] = NULL;
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
                            serialization_note(owner, NULL, offset, 1);
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

    def global_identifier(value: ptr[PyObject], module: bool) {
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

    def global(value: ptr[PyObject], preferred: ptr[PyObject]) {
        names = global_names(value, preferred, self.error);
        module: ptr[PyObject] = NULL;
        name: ptr[PyObject] = NULL;
        try {
            module = required(jacpy_tuple_item(names, 0));
            name = required(jacpy_tuple_item(names, 1));
            if self.protocol >= 2 {
                registry = required(
                    PyImport_ImportModuleAttrString("copyreg", "_extension_registry")
                );
                code: ptr[PyObject] = NULL;
                try {
                    code = jacpy_dict_get(registry, names);
                    if not code and jacpy_error_pending() != 0 {
                        raise boundary_failure();
                    }
                    if code {
                        number = PyLong_AsLongLong(code);
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
                            PyImport_ImportModuleAttrString("builtins", "getattr")
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
                    mapped_module: ptr[PyObject] = NULL;
                    mapped_name: ptr[PyObject] = NULL;
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

    def reduce_call(
        callable: ptr[PyObject], args: ptr[PyObject], value: ptr[PyObject]
    ) {
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

    def reduction(value: ptr[PyObject], reduced: ptr[PyObject]) {
        if jacpy_is_unicode(reduced) != 0 {
            self.global(value, reduced);
            return;
        }
        try {
            self.reduce_value(value, reduced);
        } except boundary_failure {
            serialization_note(value, NULL, 0, 0);
            raise boundary_failure();
        }
    }

    def save_context(value: ptr[PyObject], owner: ptr[PyObject], detail: str) {
        try {
            self.save(value, True);
        } except boundary_failure {
            serialization_note(owner, NULL, 0, 0, detail);
            raise boundary_failure();
        }
    }

    def remember_constructed(value: ptr[PyObject]) {
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

    def reduce_value(value: ptr[PyObject], reduced: ptr[PyObject]) {
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
        count = int(PyTuple_Size(reduced));
        if count < 2 or count > 6 {
            self.fail("tuple returned by __reduce__ must contain 2 through 6 elements");
        }
        callable = required(jacpy_tuple_item(reduced, 0));
        args: ptr[PyObject] = NULL;
        try {
            args = required(jacpy_tuple_item(reduced, 1));
            if PyCallable_Check(callable) == 0 {
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
                if PyTuple_Size(args) < 1 {
                    self.fail("__newobj__ expected at least 1 argument, got 0");
                }
                cls = required(jacpy_tuple_item(args, 0));
                rest: ptr[PyObject] = NULL;
                actual: ptr[PyObject] = NULL;
                try {
                    if jacpy_is_type(cls) == 0 {
                        self.fail(
                            "first argument to "
                                + special
                                + "() must be a class, not "
                                + type_name(cls, True)
                        );
                    }
                    actual = required(PyObject_GetAttrString(value, "__class__"));
                    if cls != actual {
                        self.fail(
                            "first argument to __newobj__() must be "
                                + repr_value(actual)
                                + ", not "
                                + repr_value(cls)
                        );
                    }
                    rest = required(PyTuple_GetSlice(args, 1, PyTuple_Size(args)));
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
                if PyTuple_Size(args) != 3 {
                    self.fail(
                        "__newobj_ex__ expected 3 arguments, got "
                            + str(PyTuple_Size(args))
                    );
                }
                cls = required(jacpy_tuple_item(args, 0));
                positional: ptr[PyObject] = NULL;
                keywords: ptr[PyObject] = NULL;
                actual: ptr[PyObject] = NULL;
                try {
                    if jacpy_is_type(cls) == 0 {
                        self.fail(
                            "first argument to "
                                + special
                                + "() must be a class, not "
                                + type_name(cls, True)
                        );
                    }
                    actual = required(PyObject_GetAttrString(value, "__class__"));
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
                            PyImport_ImportModuleAttrString("functools", "partial")
                        );
                        new_method: ptr[PyObject] = NULL;
                        prefix: ptr[PyObject] = NULL;
                        combined: ptr[PyObject] = NULL;
                        partial: ptr[PyObject] = NULL;
                        empty: ptr[PyObject] = NULL;
                        try {
                            new_method = required(
                                PyObject_GetAttrString(cls, "__new__")
                            );
                            prefix = object_tuple([new_method, cls]);
                            combined = required(PyNumber_Add(prefix, positional));
                            partial = required(
                                PyObject_Call(partial_type, combined, keywords)
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
                state_set: ptr[PyObject] = NULL;
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
                        if PyCallable_Check(state_set) == 0 {
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

    def save_type(value: ptr[PyObject]) {
        singletons = [jacpy_none(), jacpy_not_implemented(), jacpy_ellipsis()];
        try {
            for singleton in singletons {
                cls = required(jacpy_object_type(singleton));
                try {
                    if cls == value {
                        type_type = required(jacpy_object_type(cls));
                        args: ptr[PyObject] = NULL;
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
        self.global(value, NULL);
    }

    def other(value: ptr[PyObject], kind: int) {
        reduced: ptr[PyObject] = NULL;
        reducer: ptr[PyObject] = NULL;
        cls: ptr[PyObject] = NULL;
        try {
            if self.reducer_override != 0 {
                reduced = required(PyObject_CallOneArg(self.reducer_override, value));
                if jacpy_is_not_implemented(reduced) == 0 {
                    self.reduction(value, reduced);
                    return;
                }
                jacpy_release(reduced);
                reduced = NULL;
            }
            if kind == builtin_kind.TYPE.value {
                self.save_type(value);
                return;
            }
            if kind == builtin_kind.FUNCTION.value {
                self.global(value, NULL);
                return;
            }
            cls = required(jacpy_object_type(value));
            reducer = jacpy_mapping_optional_item(self.dispatch, cls);
            if reducer == 0 and jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            if reducer != 0 {
                reduced = required(PyObject_CallOneArg(reducer, value));
            } elif jacpy_is_type(value) != 0 {
                self.global(value, NULL);
                return;
            } else {
                reducer = jacpy_optional_attr(value, "__reduce_ex__");
                if jacpy_error_pending() != 0 {
                    raise boundary_failure();
                }
                if reducer != 0 {
                    protocol = required(PyLong_FromLongLong(i64(self.protocol)));
                    try {
                        reduced = required(PyObject_CallOneArg(reducer, protocol));
                    } finally {
                        jacpy_release(protocol);
                    }
                } else {
                    reducer = required(PyObject_GetAttrString(value, "__reduce__"));
                    args = object_tuple([]);
                    try {
                        reduced = required(PyObject_Call(reducer, args, NULL));
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

    def pickle_buffer(value: ptr[PyObject]) {
        if self.protocol < 5 {
            self.fail("PickleBuffer can only be pickled with protocol >= 5");
        }
        method = required(PyObject_GetAttrString(value, "raw"));
        arguments: ptr[PyObject] = NULL;
        view: ptr[PyObject] = NULL;
        readonly: ptr[PyObject] = NULL;
        bytes_method: ptr[PyObject] = NULL;
        raw: ptr[PyObject] = NULL;
        try {
            arguments = object_tuple([]);
            view = required(PyObject_Call(method, arguments, NULL));
            readonly = required(PyObject_GetAttrString(view, "readonly"));
            truth = PyObject_IsTrue(readonly);
            checked(truth);
            in_band: i64 = 1;
            if self.buffer_callback != 0 {
                result = required(PyObject_CallOneArg(self.buffer_callback, value));
                try {
                    in_band = PyObject_IsTrue(result);
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
                bytes_method = required(PyObject_GetAttrString(view, "tobytes"));
                raw = required(PyObject_Call(bytes_method, arguments, NULL));
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

    def dump(value: ptr[PyObject]) {
        checked(PyByteArray_Resize(self.stream.buffer, 0));
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

    def save(value: ptr[PyObject], persistent: bool) {
        self.stream.flush(False);
        if persistent and self.persistent_id != 0 {
            pid = required(PyObject_CallOneArg(self.persistent_id, value));
            try {
                if jacpy_is_none(pid) == 0 {
                    if self.protocol > 0 {
                        self.save(pid, False);
                        self.emit(opcode.BINPERSID);
                    } else {
                        text = required(PyObject_Str(pid));
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
            truth = PyObject_IsTrue(value);
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
                iterable: ptr[PyObject] = NULL;
                iterator: ptr[PyObject] = NULL;
                try {
                    iterable = PyMapping_Items(value)
                        if kind == builtin_kind.DICT.value
                        else Py_NewRef(value);
                    iterator = required(PyObject_GetIter(required(iterable)));
                    self.batch(iterator, kind == builtin_kind.DICT.value, value);
                } finally {
                    jacpy_release(iterable);
                    jacpy_release(iterator);
                }
            } elif kind == builtin_kind.BYTEARRAY.value {
                self.bytes(value, True);
            } elif kind == builtin_kind.SET.value
                or kind == builtin_kind.FROZENSET.value {
                values = required(PySequence_List(value));
                try {
                    if self.protocol < 4 {
                        cls = required(jacpy_object_type(value));
                        args: ptr[PyObject] = NULL;
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
                            item = required(PyList_GetItemRef(values, i64(i)));
                            try {
                                self.save(item, True);
                            } except boundary_failure {
                                serialization_note(value, NULL, 0, 0, "element");
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
            Py_LeaveRecursiveCall();
        }
    }
}
