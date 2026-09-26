"""Native pickle opcode evaluation and reference ownership.

The stack, marks, memo policy and opcode dispatch execute in Jac. CPython
supplies retained values and the object protocol at callback boundaries.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyDict_Items,
    PyDict_New,
    PyDict_SetItem,
    PyFloat_FromDouble,
    PyFloat_FromString,
    PyImport_ImportModuleAttrString,
    PyIter_Next,
    PyList_Append,
    PyList_GetItemRef,
    PyLong_AsLongLong,
    PyLong_FromLongLong,
    PyMemoryView_FromObject,
    PyNumber_Long,
    PyObject,
    PyObject_Call,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PyObject_IsTrue,
    PyObject_SetAttr,
    PyObject_SetItem,
    PyTuple_New,
    PyTuple_Size,
    Py_NewRef,
    jacpy_bytearray_new,
    jacpy_bytes_address,
    jacpy_bytes_decode,
    jacpy_bytes_from_memory,
    jacpy_bytes_length,
    jacpy_bytes_unescape,
    jacpy_dict_get,
    jacpy_dict_size,
    jacpy_error_is,
    jacpy_error_pending,
    jacpy_float_unpack,
    jacpy_is_dict,
    jacpy_is_exact_unicode,
    jacpy_is_list,
    jacpy_is_none,
    jacpy_is_tuple,
    jacpy_is_type,
    jacpy_is_unicode,
    jacpy_list_new,
    jacpy_list_size,
    jacpy_long_from_signed_bytes,
    jacpy_memory_byte,
    jacpy_memory_copy,
    jacpy_none,
    jacpy_offset,
    jacpy_optional_attr,
    jacpy_release,
    jacpy_set_new,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    jacpy_type_new,
    jacpy_unicode_intern
}
import from jaclang.runtime.python.modules.pickle_opcodes { opcode }
import from jaclang.runtime.python.modules.pickle_stream {
    pickle_reader,
    stream_error,
    builtin_stream_error
}
import from jaclang.runtime.python.modules.binary_scalars { integer_from_bits }
import from jaclang.runtime.python.capi {
    text_value,
    required,
    checked,
    boundary_failure,
    object_tuple
}

obj unpickle_state {
    has stream: pickle_reader = pickle_reader(),
        stack: list[ptr[PyObject]] = [],
        marks: list[int] = [],
        memo: ptr[PyObject] = NULL,
        find_class: ptr[PyObject] = NULL,
        persistent_load: ptr[PyObject] = NULL,
        buffers: ptr[PyObject] = NULL,
        error: ptr[PyObject] = NULL,
        encoding: str = "ASCII",
        errors: str = "strict",
        protocol: int = 0;

    def reset_stack {
        while self.stack {
            jacpy_release(self.stack.pop());
        }
        self.marks.clear();
    }

    def clear {
        self.reset_stack();
        self.stream.clear();
        memo = self.memo;
        find = self.find_class;
        persistent = self.persistent_load;
        buffers = self.buffers;
        error = self.error;
        self.memo = NULL;
        self.find_class = NULL;
        self.persistent_load = NULL;
        self.buffers = NULL;
        self.error = NULL;
        jacpy_release(memo);
        jacpy_release(find);
        jacpy_release(persistent);
        jacpy_release(buffers);
        jacpy_release(error);
    }

    def fail(message: str) {
        stream_error(self.error, message);
    }

    def floor -> int {
        return self.marks[-1] if self.marks else 0;
    }

    def require_items(count: int) {
        if len(self.stack) - self.floor() < count {
            self.fail("unpickling stack underflow");
        }
    }

    def top -> ptr[PyObject] {
        self.require_items(1);
        return self.stack[-1];
    }

    def pop -> ptr[PyObject] {
        self.require_items(1);
        return self.stack.pop();
    }

    def push(value: ptr[PyObject]) {
        self.stack.append(required(value));
    }

    def mark_count -> int {
        if not self.marks {
            self.fail("could not find MARK");
        }
        return len(self.stack) - self.marks.pop();
    }

    def tuple(count: int) -> ptr[PyObject] {
        self.require_items(count);
        value = required(PyTuple_New(i64(count)));
        for i in range(count) {
            jacpy_tuple_set_owned(value, i64(count - 1 - i), self.stack.pop());
        }
        return value;
    }

    def remember(index: i64) {
        if index < 0 {
            builtin_stream_error("ValueError", "negative PUT argument");
        }
        value = self.top();
        key = required(PyLong_FromLongLong(index));
        try {
            checked(PyDict_SetItem(self.memo, key, value));
        } finally {
            jacpy_release(key);
        }
    }

    def recall(index: i64) {
        key = required(PyLong_FromLongLong(index));
        value: ptr[PyObject] = NULL;
        try {
            value = jacpy_dict_get(self.memo, key);
        } finally {
            jacpy_release(key);
        }
        if value == 0 {
            if jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            self.fail("Memo value not found at index " + str(index));
        }
        self.push(value);
    }

    def line_without_newline -> ptr[PyObject] {
        raw = self.stream.line();
        try {
            return required(
                jacpy_bytes_from_memory(
                    jacpy_bytes_address(raw), jacpy_bytes_length(raw) - 1
                )
            );
        } finally {
            jacpy_release(raw);
        }
    }

    def line_integer -> i64 {
        raw = self.line_without_newline();
        number: ptr[PyObject] = NULL;
        try {
            number = required(PyNumber_Long(raw));
            value = PyLong_AsLongLong(number);
            if jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            return value;
        } finally {
            jacpy_release(raw);
            jacpy_release(number);
        }
    }

    def decode_text(raw: ptr[PyObject], encoding: str, errors: str) -> ptr[PyObject] {
        try {
            return required(jacpy_bytes_decode(raw, encoding, errors));
        } finally {
            jacpy_release(raw);
        }
    }

    def find(module: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
        arguments = object_tuple([module, name]);
        try {
            return required(PyObject_Call(self.find_class, arguments, NULL));
        } finally {
            jacpy_release(arguments);
        }
    }

    def global_value -> ptr[PyObject] {
        raw = self.line_without_newline();
        module: ptr[PyObject] = NULL;
        name: ptr[PyObject] = NULL;
        try {
            if jacpy_bytes_length(raw) == 0 {
                self.fail("pickle data was truncated");
            }
            module = required(jacpy_bytes_decode(raw, "utf-8", "strict"));
            name = self.decode_text(self.line_without_newline(), "utf-8", "strict");
            if text_value(name) == "" {
                self.fail("pickle data was truncated");
            }
            return self.find(module, name);
        } finally {
            jacpy_release(raw);
            jacpy_release(module);
            jacpy_release(name);
        }
    }

    def append_items(count: int) {
        items = self.tuple(count);
        try {
            target = self.top();
            if jacpy_is_list(target) != 0 {
                for i in range(count) {
                    item = required(jacpy_tuple_item(items, i64(i)));
                    try {
                        checked(PyList_Append(target, item));
                    } finally {
                        jacpy_release(item);
                    }
                }
            } else {
                extend = jacpy_optional_attr(target, "extend");
                if jacpy_error_pending() != 0 {
                    raise boundary_failure();
                }
                if extend != 0 {
                    try {
                        jacpy_release(required(PyObject_CallOneArg(extend, items)));
                    } finally {
                        jacpy_release(extend);
                    }
                } else {
                    append = required(PyObject_GetAttrString(target, "append"));
                    try {
                        for i in range(count) {
                            item = required(jacpy_tuple_item(items, i64(i)));
                            try {
                                jacpy_release(
                                    required(PyObject_CallOneArg(append, item))
                                );
                            } finally {
                                jacpy_release(item);
                            }
                        }
                    } finally {
                        jacpy_release(append);
                    }
                }
            }
        } finally {
            jacpy_release(items);
        }
    }

    def set_items(count: int) {
        if count % 2 {
            self.fail("odd number of items for SETITEMS");
        }
        items = self.tuple(count);
        try {
            target = self.top();
            for i in range(0, count, 2) {
                key = required(jacpy_tuple_item(items, i64(i)));
                value: ptr[PyObject] = NULL;
                try {
                    value = required(jacpy_tuple_item(items, i64(i + 1)));
                    checked(PyObject_SetItem(target, key, value));
                } finally {
                    jacpy_release(key);
                    jacpy_release(value);
                }
            }
        } finally {
            jacpy_release(items);
        }
    }

    def restore_mapping(
        target: ptr[PyObject], mapping: ptr[PyObject], attributes: bool
    ) {
        items = required(PyDict_Items(mapping));
        try {
            for i in range(int(jacpy_list_size(items))) {
                pair = required(PyList_GetItemRef(items, i64(i)));
                name: ptr[PyObject] = NULL;
                value: ptr[PyObject] = NULL;
                try {
                    name = required(jacpy_tuple_item(pair, 0));
                    value = required(jacpy_tuple_item(pair, 1));
                    if attributes {
                        checked(PyObject_SetAttr(target, name, value));
                    } else {
                        if jacpy_is_exact_unicode(name) != 0 {
                            interned = required(jacpy_unicode_intern(name));
                            jacpy_release(name);
                            name = interned;
                        }
                        checked(PyObject_SetItem(target, name, value));
                    }
                } finally {
                    jacpy_release(pair);
                    jacpy_release(name);
                    jacpy_release(value);
                }
            }
        } finally {
            jacpy_release(items);
        }
    }

    def build {
        state = self.pop();
        try {
            target = self.top();
            method = jacpy_optional_attr(target, "__setstate__");
            if jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            if method != 0 {
                try {
                    jacpy_release(required(PyObject_CallOneArg(method, state)));
                } finally {
                    jacpy_release(method);
                }
                return;
            }
            dictionary = Py_NewRef(state);
            slots: ptr[PyObject] = NULL;
            try {
                if jacpy_is_tuple(state) != 0 and PyTuple_Size(state) == 2 {
                    jacpy_release(dictionary);
                    dictionary = NULL;
                    dictionary = required(jacpy_tuple_item(state, 0));
                    slots = required(jacpy_tuple_item(state, 1));
                }
                if jacpy_is_none(dictionary) == 0 {
                    if jacpy_is_dict(dictionary) == 0 {
                        self.fail("state is not a dictionary");
                    }
                    destination = required(PyObject_GetAttrString(target, "__dict__"));
                    try {
                        self.restore_mapping(destination, dictionary, False);
                    } finally {
                        jacpy_release(destination);
                    }
                }
                if slots != 0 and jacpy_is_none(slots) == 0 {
                    if jacpy_is_dict(slots) == 0 {
                        self.fail("slot state is not a dictionary");
                    }
                    self.restore_mapping(target, slots, True);
                }
            } finally {
                jacpy_release(dictionary);
                jacpy_release(slots);
            }
        } finally {
            jacpy_release(state);
        }
    }

    def extension(code: i64) {
        if code <= 0 or code > 2147483647 {
            self.fail("EXT specifies code <= 0");
        }
        key = required(PyLong_FromLongLong(code));
        cache: ptr[PyObject] = NULL;
        registry: ptr[PyObject] = NULL;
        registered: ptr[PyObject] = NULL;
        try {
            cache = required(
                PyImport_ImportModuleAttrString("copyreg", "_extension_cache")
            );
            value = jacpy_dict_get(cache, key);
            if value != 0 {
                self.push(value);
                return;
            }
            if jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            registry = required(
                PyImport_ImportModuleAttrString("copyreg", "_inverted_registry")
            );
            registered = jacpy_dict_get(registry, key);
            if registered == 0 {
                if jacpy_error_pending() != 0 {
                    raise boundary_failure();
                }
                builtin_stream_error(
                    "ValueError", "unregistered extension code " + str(code)
                );
            }
            if jacpy_is_tuple(registered) == 0 or PyTuple_Size(registered) != 2 {
                builtin_stream_error("ValueError", "invalid extension registry entry");
            }
            module = required(jacpy_tuple_item(registered, 0));
            name: ptr[PyObject] = NULL;
            result: ptr[PyObject] = NULL;
            try {
                name = required(jacpy_tuple_item(registered, 1));
                result = self.find(module, name);
                checked(PyDict_SetItem(cache, key, result));
                self.push(Py_NewRef(result));
            } finally {
                jacpy_release(module);
                jacpy_release(name);
                jacpy_release(result);
            }
        } finally {
            jacpy_release(key);
            jacpy_release(cache);
            jacpy_release(registry);
            jacpy_release(registered);
        }
    }

    def instantiate(cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
        if PyTuple_Size(args) == 0 and jacpy_is_type(cls) != 0 {
            initializer = jacpy_optional_attr(cls, "__getinitargs__");
            if jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
            if initializer == 0 {
                return required(jacpy_type_new(cls, args, NULL));
            }
            jacpy_release(initializer);
        }
        return required(PyObject_Call(cls, args, NULL));
    }

    def load -> ptr[PyObject] {
        self.reset_stack();
        self.protocol = 0;
        while True {
            op = self.stream.opcode();
            if op == opcode.STOP.value {
                return self.pop();
            } elif op == opcode.PROTO.value {
                self.protocol = int(self.stream.integer(1));
                if self.protocol > 5 {
                    builtin_stream_error(
                        "ValueError",
                        "unsupported pickle protocol: " + str(self.protocol)
                    );
                }
            } elif op == opcode.FRAME.value {
                self.stream.begin_frame(self.stream.integer(8));
            } elif op == opcode.MARK.value {
                self.marks.append(len(self.stack));
            } elif op == opcode.POP.value {
                if len(self.stack) == self.floor() and self.marks {
                    self.marks.pop();
                } else {
                    jacpy_release(self.pop());
                }
            } elif op == opcode.POP_MARK.value {
                count = self.mark_count();
                for _ in range(count) {
                    jacpy_release(self.stack.pop());
                }
            } elif op == opcode.DUP.value {
                self.push(Py_NewRef(self.top()));
            } elif op == opcode.NONE.value {
                self.push(jacpy_none());
            } elif op == opcode.NEWTRUE.value or op == opcode.NEWFALSE.value {
                self.push(PyBool_FromLong(1 if op == opcode.NEWTRUE.value else 0));
            } elif op == opcode.BININT.value {
                self.push(integer_from_bits(self.stream.integer(4), 4, True));
            } elif op == opcode.BININT1.value or op == opcode.BININT2.value {
                self.push(
                    PyLong_FromLongLong(
                        i64(self.stream.integer(1 if op == opcode.BININT1.value else 2))
                    )
                );
            } elif op == opcode.INT.value or op == opcode.LONG.value {
                raw = self.line_without_newline();
                try {
                    size = jacpy_bytes_length(raw);
                    address = jacpy_bytes_address(raw);
                    if op == opcode.INT.value
                        and size == 2
                        and jacpy_memory_byte(address, 0) == 48
                        and jacpy_memory_byte(address, 1) in [48, 49] {
                        self.push(PyBool_FromLong(jacpy_memory_byte(address, 1) - 48));
                    } elif op == opcode.LONG.value
                        and size > 0
                        and jacpy_memory_byte(address, size - 1) == 76 {
                        trimmed = required(jacpy_bytes_from_memory(address, size - 1));
                        try {
                            self.push(PyNumber_Long(trimmed));
                        } finally {
                            jacpy_release(trimmed);
                        }
                    } else {
                        self.push(PyNumber_Long(raw));
                    }
                } finally {
                    jacpy_release(raw);
                }
            } elif op == opcode.LONG1.value or op == opcode.LONG4.value {
                byte_count = self.stream.integer(1 if op == opcode.LONG1.value else 4);
                if byte_count > 2147483647 {
                    self.fail("LONG pickle has negative byte byte_count");
                }
                raw = self.stream.exact(i64(byte_count));
                try {
                    self.push(jacpy_long_from_signed_bytes(raw));
                } finally {
                    jacpy_release(raw);
                }
            } elif op == opcode.FLOAT.value {
                raw = self.line_without_newline();
                try {
                    self.push(PyFloat_FromString(raw));
                } finally {
                    jacpy_release(raw);
                }
            } elif op == opcode.BINFLOAT.value {
                raw = self.stream.exact(8);
                try {
                    self.push(
                        PyFloat_FromDouble(
                            jacpy_float_unpack(jacpy_bytes_address(raw), 8, 0)
                        )
                    );
                } finally {
                    jacpy_release(raw);
                }
            } elif op
                in [
                    opcode.BINBYTES.value,
                    opcode.SHORT_BINBYTES.value,
                    opcode.BINBYTES8.value,
                    opcode.BYTEARRAY8.value,
                    opcode.BINUNICODE.value,
                    opcode.SHORT_BINUNICODE.value,
                    opcode.BINUNICODE8.value,
                    opcode.BINSTRING.value,
                    opcode.SHORT_BINSTRING.value
                ] {
                width = 4;
                if op
                    in [
                        opcode.SHORT_BINBYTES.value,
                        opcode.SHORT_BINUNICODE.value,
                        opcode.SHORT_BINSTRING.value
                    ] {
                    width = 1;
                } elif op
                    in [
                        opcode.BINBYTES8.value,
                        opcode.BINUNICODE8.value,
                        opcode.BYTEARRAY8.value
                    ] {
                    width = 8;
                }
                byte_count = self.stream.integer(width);
                if op == opcode.BINSTRING.value and byte_count > 2147483647 {
                    self.fail("BINSTRING pickle has negative byte count");
                }
                if byte_count > 9223372036854775807
                    or (op == opcode.BINSTRING.value and byte_count > 2147483647) {
                    builtin_stream_error(
                        "OverflowError", "pickle byte count exceeds system's maximum"
                    );
                }
                raw = self.stream.exact(i64(byte_count));
                if op
                    in [
                        opcode.BINUNICODE.value,
                        opcode.SHORT_BINUNICODE.value,
                        opcode.BINUNICODE8.value
                    ] {
                    self.push(self.decode_text(raw, "utf-8", "surrogatepass"));
                } elif op in [opcode.BINSTRING.value, opcode.SHORT_BINSTRING.value]
                    and self.encoding != "bytes" {
                    self.push(self.decode_text(raw, self.encoding, self.errors));
                } elif op == opcode.BYTEARRAY8.value {
                    try {
                        value = required(jacpy_bytearray_new(i64(byte_count)));
                        jacpy_memory_copy(
                            jacpy_bytes_address(value),
                            jacpy_bytes_address(raw),
                            i64(byte_count)
                        );
                        self.push(value);
                    } finally {
                        jacpy_release(raw);
                    }
                } else {
                    self.push(raw);
                }
            } elif op == opcode.UNICODE.value {
                self.push(
                    self.decode_text(
                        self.line_without_newline(), "raw-unicode-escape", "strict"
                    )
                );
            } elif op == opcode.EMPTY_LIST.value {
                self.push(jacpy_list_new());
            } elif op == opcode.EMPTY_DICT.value {
                self.push(PyDict_New());
            } elif op == opcode.EMPTY_TUPLE.value {
                self.push(PyTuple_New(0));
            } elif op == opcode.TUPLE.value {
                self.push(self.tuple(self.mark_count()));
            } elif op
                in [opcode.TUPLE1.value, opcode.TUPLE2.value, opcode.TUPLE3.value] {
                self.push(self.tuple(op - opcode.TUPLE1.value + 1));
            } elif op == opcode.LIST.value or op == opcode.DICT.value {
                count = self.mark_count();
                items = self.tuple(count);
                try {
                    if op == opcode.DICT.value and count % 2 {
                        self.fail("odd number of items for DICT");
                    }
                    self.push(
                        jacpy_list_new() if op == opcode.LIST.value else PyDict_New()
                    );
                    for i in range(count) {
                        self.push(jacpy_tuple_item(items, i64(i)));
                    }
                    if op == opcode.LIST.value {
                        self.append_items(count);
                    } else {
                        self.set_items(count);
                    }
                } finally {
                    jacpy_release(items);
                }
            } elif op == opcode.APPEND.value {
                self.append_items(1);
            } elif op == opcode.APPENDS.value {
                self.append_items(self.mark_count());
            } elif op == opcode.SETITEM.value {
                self.set_items(2);
            } elif op == opcode.SETITEMS.value {
                self.set_items(self.mark_count());
            } elif op == opcode.PUT.value {
                self.remember(self.line_integer());
            } elif op == opcode.BINPUT.value or op == opcode.LONG_BINPUT.value {
                self.remember(
                    i64(self.stream.integer(1 if op == opcode.BINPUT.value else 4))
                );
            } elif op == opcode.MEMOIZE.value {
                self.remember(jacpy_dict_size(self.memo));
            } elif op == opcode.GET.value {
                self.recall(self.line_integer());
            } elif op == opcode.BINGET.value or op == opcode.LONG_BINGET.value {
                self.recall(
                    i64(self.stream.integer(1 if op == opcode.BINGET.value else 4))
                );
            } elif op == opcode.GLOBAL.value {
                self.push(self.global_value());
            } elif op == opcode.STACK_GLOBAL.value {
                name = self.pop();
                module: ptr[PyObject] = NULL;
                try {
                    module = self.pop();
                    if jacpy_is_unicode(name) == 0 or jacpy_is_unicode(module) == 0 {
                        self.fail("STACK_GLOBAL requires str");
                    }
                    self.push(self.find(module, name));
                } finally {
                    jacpy_release(name);
                    jacpy_release(module);
                }
            } elif op
                in [opcode.REDUCE.value, opcode.NEWOBJ.value, opcode.NEWOBJ_EX.value] {
                kwargs: ptr[PyObject] = NULL;
                args: ptr[PyObject] = NULL;
                callable: ptr[PyObject] = NULL;
                try {
                    if op == opcode.NEWOBJ_EX.value {
                        kwargs = self.pop();
                    }
                    args = self.pop();
                    callable = self.pop();
                    if op == opcode.REDUCE.value {
                        if jacpy_is_tuple(args) == 0 {
                            builtin_stream_error(
                                "TypeError", "REDUCE argument must be a tuple"
                            );
                        }
                        self.push(PyObject_Call(callable, args, NULL));
                    } else {
                        self.push(jacpy_type_new(callable, args, kwargs));
                    }
                } finally {
                    jacpy_release(kwargs);
                    jacpy_release(args);
                    jacpy_release(callable);
                }
            } elif op == opcode.BUILD.value {
                self.build();
            } elif op == opcode.PERSID.value or op == opcode.BINPERSID.value {
                pid: ptr[PyObject] = NULL;
                try {
                    pid = self.pop()
                        if op == opcode.BINPERSID.value
                        else self.decode_text(
                            self.line_without_newline(), "ASCII", "strict"
                        );
                } except boundary_failure {
                    if jacpy_error_is("UnicodeDecodeError") != 0 {
                        self.fail("persistent IDs in protocol 0 must be ASCII strings");
                    }
                    raise boundary_failure();
                }
                try {
                    if self.persistent_load == 0 {
                        self.fail("unsupported persistent id encountered");
                    }
                    self.push(PyObject_CallOneArg(self.persistent_load, pid));
                } finally {
                    jacpy_release(pid);
                }
            } elif op == opcode.STRING.value {
                raw = self.line_without_newline();
                try {
                    size = jacpy_bytes_length(raw);
                    address = jacpy_bytes_address(raw);
                    if size < 2
                        or jacpy_memory_byte(address, 0) not in [34, 39]
                        or jacpy_memory_byte(address, size - 1)
                            != jacpy_memory_byte(address, 0) {
                        self.fail("the STRING opcode argument must be quoted");
                    }
                    inner = required(
                        jacpy_bytes_from_memory(jacpy_offset(address, 1), size - 2)
                    );
                    decoded: ptr[PyObject] = NULL;
                    try {
                        decoded = required(jacpy_bytes_unescape(inner));
                    } finally {
                        jacpy_release(inner);
                    }
                    self.push(
                        decoded
                            if self.encoding == "bytes"
                            else self.decode_text(decoded, self.encoding, self.errors)
                    );
                } finally {
                    jacpy_release(raw);
                }
            } elif op == opcode.EMPTY_SET.value {
                self.push(jacpy_set_new(NULL, 0));
            } elif op == opcode.FROZENSET.value {
                items = self.tuple(self.mark_count());
                try {
                    self.push(jacpy_set_new(items, 1));
                } finally {
                    jacpy_release(items);
                }
            } elif op == opcode.ADDITEMS.value {
                count = self.mark_count();
                items = self.tuple(count);
                add: ptr[PyObject] = NULL;
                try {
                    add = required(PyObject_GetAttrString(self.top(), "add"));
                    for i in range(count) {
                        item = required(jacpy_tuple_item(items, i64(i)));
                        try {
                            jacpy_release(required(PyObject_CallOneArg(add, item)));
                        } finally {
                            jacpy_release(item);
                        }
                    }
                } finally {
                    jacpy_release(items);
                    jacpy_release(add);
                }
            } elif op == opcode.EXT1.value
                or op == opcode.EXT2.value
                or op == opcode.EXT4.value {
                self.extension(
                    i64(
                        self.stream.integer(
                            1
                                if op == opcode.EXT1.value
                                else 2 if op == opcode.EXT2.value else 4
                        )
                    )
                );
            } elif op == opcode.NEXT_BUFFER.value {
                if self.buffers == 0 {
                    self.fail(
                        "pickle stream refers to out-of-band data but no *buffers* argument was given"
                    );
                }
                value = PyIter_Next(self.buffers);
                if value == 0 {
                    if jacpy_error_pending() != 0 {
                        raise boundary_failure();
                    }
                    self.fail("not enough out-of-band buffers");
                }
                self.push(value);
            } elif op == opcode.READONLY_BUFFER.value {
                view = required(PyMemoryView_FromObject(self.top()));
                readonly: ptr[PyObject] = NULL;
                method: ptr[PyObject] = NULL;
                args: ptr[PyObject] = NULL;
                try {
                    readonly = required(PyObject_GetAttrString(view, "readonly"));
                    truth = PyObject_IsTrue(readonly);
                    checked(truth);
                    if truth == 0 {
                        method = required(PyObject_GetAttrString(view, "toreadonly"));
                        args = object_tuple([]);
                        result = required(PyObject_Call(method, args, NULL));
                        jacpy_release(self.pop());
                        self.push(result);
                    }
                } finally {
                    jacpy_release(view);
                    jacpy_release(readonly);
                    jacpy_release(method);
                    jacpy_release(args);
                }
            } elif op == opcode.INST.value or op == opcode.OBJ.value {
                count = self.mark_count();
                cls: ptr[PyObject] = NULL;
                args: ptr[PyObject] = NULL;
                try {
                    if op == opcode.INST.value {
                        cls = self.global_value();
                        args = self.tuple(count);
                    } else {
                        if count < 1 {
                            self.fail("unpickling stack underflow");
                        }
                        args = self.tuple(count - 1);
                        cls = self.pop();
                    }
                    self.push(self.instantiate(cls, args));
                } finally {
                    jacpy_release(cls);
                    jacpy_release(args);
                }
            } else {
                self.fail("invalid load key, " + str(op));
            }
        }
        return NULL;
    }
}
