"""Argument ownership and signature binding shared by native Python adapters."""

import from jaclang.runtime.python.cpython_api {
    jacpy_error_pending,
    jacpy_is_unicode,
    jacpy_list_size,
    jacpy_release,
    jacpy_tuple_item,
    jacpy_unicode_size,
    NULL,
    _Py_CalculateSuggestions,
    Py_NewRef,
    Py_None,
    PyDict_GetItemStringRef,
    PyDict_Items,
    PyDict_Size,
    PyErr_Occurred,
    PyExc_OverflowError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyIndex_Check,
    PyList_GetItemRef,
    PyList_New,
    PyList_SetItem,
    PyLong_AsLong,
    PyLong_AsLongLong,
    PyLong_AsSsize_t,
    PyLong_AsUnsignedLongLongMask,
    PyLong_AsUnsignedLongMask,
    PyNumber_Index,
    PyObject,
    PyObject_IsTrue,
    PyTuple_GetItem,
    PyTuple_Size,
    PyUnicode_AsUTF8AndSize,
    PyUnicode_FromString,
    PyUnicode_ReadChar
}
import from jaclang.runtime.python.capi {
    boundary_failure,
    required,
    object_error,
    text_value,
    type_name
}

obj BoundArguments {
    has values: list[ptr[PyObject]],
        context: ptr[PyObject] = NULL,
        keywords: ptr[PyObject] = NULL;

    def drop {
        for value in self.values {
            jacpy_release(value);
        }
        jacpy_release(self.keywords);
    }
}

def invalid(message: str) -> bool {
    object_error(PyExc_TypeError, message);
    return False;
}

def index_value(value: ptr[PyObject]) -> (i64 | None) {
    index = PyNumber_Index(value);
    if index == 0 {
        return None;
    }
    try {
        result = PyLong_AsSsize_t(index);
        if result == -1 and jacpy_error_pending() != 0 {
            return None;
        }
        return result;
    } finally {
        jacpy_release(index);
    }
}

obj CallSignature {
    has name: str,
        names: list[str],
        required_count: int,
        positional_count: int,
        positional_only: int = 0;

    def bind(
        result: BoundArguments, args: ptr[PyObject], kwargs: ptr[PyObject]
    ) -> bool {
        count = int(PyTuple_Size(args));
        if count < 0 {
            return False;
        }
        if count > self.positional_count {
            return invalid(
                f"{self.name}() takes at most {self.positional_count} positional arguments ({count} given)"
            );
        }
        for i in range(count) {
            result.values[i] = required(jacpy_tuple_item(args, i64(i)));
        }
        if kwargs != 0 {
            items = required(PyDict_Items(kwargs));
            try {
                for i in range(int(jacpy_list_size(items))) {
                    item = required(PyList_GetItemRef(items, i64(i)));
                    key: ptr[PyObject] = NULL;
                    try {
                        key = required(jacpy_tuple_item(item, 0));
                        if jacpy_is_unicode(key) == 0 {
                            return invalid("keywords must be strings");
                        }
                        name = text_value(key);
                        index = -1;
                        for j in range(self.positional_only, len(self.names)) {
                            if self.names[j] == name {
                                index = j;
                                break;
                            }
                        }
                        if index < 0 {
                            return invalid(
                                f"{self.name}() got an unexpected keyword argument '{name}'"
                            );
                        }
                        if result.values[index] != 0 {
                            return invalid(
                                f"argument for {self.name}() given by name ('{name}') and position ({index
                                    + 1})"
                            );
                        }
                        result.values[index] = required(jacpy_tuple_item(item, 1));
                    } finally {
                        jacpy_release(key);
                        jacpy_release(item);
                    }
                }
            } finally {
                jacpy_release(items);
            }
        }
        for i in range(self.required_count) {
            if result.values[i] == 0 {
                return invalid(
                    f"{self.name}() missing required argument '{self.names[i]}' (pos {i
                        + 1})"
                );
            }
        }
        return True;
    }
}

def invoke(
    signature: CallSignature,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    implementation: Callable[[BoundArguments], ptr[PyObject]],
    context: ptr[PyObject] = 0,
    forward_keywords: bool = False
) -> ptr[PyObject] {
    # The call frame lives outside the exception region: every exit releases
    # all converted arguments, including a failure in a nested conversion.
    bound = BoundArguments([NULL for _ in signature.names], context);
    if forward_keywords and kwargs != 0 {
        bound.keywords = Py_NewRef(kwargs);
    }
    try {
        if not signature.bind(bound, args, NULL if forward_keywords else kwargs) {
            return NULL;
        }
        return implementation(bound);
    } except boundary_failure {
        return NULL;
    }
}

def invoke_one(
    value: ptr[PyObject], implementation: Callable[[ptr[PyObject]], ptr[PyObject]]
) -> ptr[PyObject] {
    try {
        return implementation(value);
    } except boundary_failure {
        return NULL;
    }
}

def character_value(value: ptr[PyObject], context: str) -> (i64 | None) {
    if jacpy_is_unicode(value) == 0 or jacpy_unicode_size(value) != 1 {
        object_error(
            PyExc_TypeError, f"{context}() argument must be a unicode character"
        );
        return None;
    }
    return PyUnicode_ReadChar(value, 0);
}


# One converted argument of an ArgumentFormat: `given` is False for an
# omitted optional one. Object units fill `object` (borrowed), signed and
# unsigned integer units `signed` / `unsigned`, "p" `flag` and "s" `text`.
obj ArgumentValue {
    has given: bool = False,
        object: ptr[PyObject] = NULL,
        signed: i64 = 0,
        unsigned: u64 = 0,
        flag: bool = False,
        text: str = "";
}

# PyArg_ParseTuple() and PyArg_ParseTupleAndKeywords() over formats of
# single units, with Python/getargs.c's conversions and messages. Units:
# "O" object, "U" str, "s" str without NUL, "i" int, "h" short, "l" long,
# "L" long long, "n" Py_ssize_t, "p" predicate, and the bitfields "B",
# "H", "I", "k", "K"; "|" starts the optional arguments and "$" the
# keyword-only ones. `name` is the text after a format's ':' ("" for none),
# `message` the text after its ';', which replaces the arity and "must be"
# messages. A failure sets the exception and raises boundary_failure.
obj ArgumentFormat {
    has name: str = "",
        message: str = "";

    def caller -> str {
        return f"{self.name}()" if self.name else "function";
    }

    # seterror(): "<name>() argument <position> must be <expected>, not <type>".
    def mismatch(position: int, expected: str, value: ptr[PyObject]) {
        if self.message {
            object_error(PyExc_TypeError, self.message);
            raise boundary_failure();
        }
        shown = "None" if value == Py_None else type_name(value);
        caller = f"{self.name}() " if self.name else "";
        object_error(
            PyExc_TypeError, f"{caller}argument {position} must be {expected}, not {shown}"
        );
        raise boundary_failure();
    }

    def failed -> bool {
        return bool(PyErr_Occurred());
    }

    def signed_range(value: i64, low: i64, high: i64, kind: str) -> i64 {
        if value > high {
            object_error(PyExc_OverflowError, f"{kind} is greater than maximum");
            raise boundary_failure();
        }
        if value < low {
            object_error(PyExc_OverflowError, f"{kind} is less than minimum");
            raise boundary_failure();
        }
        return value;
    }

    # convertsimple(): one unit of the format applied to `value`.
    def convert(unit: str, value: ptr[PyObject], position: int) -> ArgumentValue {
        result = ArgumentValue(given=True, object=value);
        if unit == "O" {
            return result;
        }
        if unit == "U" or unit == "s" {
            if jacpy_is_unicode(value) == 0 {
                self.mismatch(position, "str", value);
            }
            if unit == "s" {
                size: i64 = 0;
                if PyUnicode_AsUTF8AndSize(value, &mut size).is_null() {
                    raise boundary_failure();
                }
                result.text = text_value(value);
                if "\x00" in result.text {
                    object_error(PyExc_ValueError, "embedded null character");
                    raise boundary_failure();
                }
            }
            return result;
        }
        if unit == "p" {
            truth = PyObject_IsTrue(value);
            if truth < 0 {
                raise boundary_failure();
            }
            result.flag = truth != 0;
            return result;
        }
        if unit == "n" {
            index = PyNumber_Index(value);
            if not index {
                raise boundary_failure();
            }
            result.signed = PyLong_AsSsize_t(index);
            jacpy_release(index);
            if result.signed == -1 and self.failed() {
                raise boundary_failure();
            }
            return result;
        }
        if unit == "L" {
            result.signed = PyLong_AsLongLong(value);
            if result.signed == -1 and self.failed() {
                raise boundary_failure();
            }
            return result;
        }
        if unit == "B" or unit == "H" or unit == "I" or unit == "k" or unit == "K" {
            if (unit == "k" or unit == "K") and PyIndex_Check(value) == 0 {
                self.mismatch(position, "int", value);
            }
            result.unsigned = PyLong_AsUnsignedLongLongMask(value)
                if unit == "K"
                else PyLong_AsUnsignedLongMask(value);
            if result.unsigned == u64(0xFFFFFFFFFFFFFFFF) and self.failed() {
                raise boundary_failure();
            }
            mask = {"B": 0xFF, "H": 0xFFFF, "I": 0xFFFFFFFF}.get(unit, -1);
            if mask >= 0 {
                result.unsigned = result.unsigned & u64(mask);
            }
            return result;
        }
        wide = PyLong_AsLong(value);
        if wide == -1 and self.failed() {
            raise boundary_failure();
        }
        if unit == "i" {
            result.signed = self.signed_range(
                wide, -2147483648, 2147483647, "signed integer"
            );
        } elif unit == "h" {
            result.signed = self.signed_range(
                wide, -32768, 32767, "signed short integer"
            );
        } else {
            result.signed = wide;
        }
        return result;
    }

    # The arity check of PyArg_ParseTuple().
    def unpack(args: ptr[PyObject], minimum: int, maximum: int) -> list[ptr[PyObject]] {
        count = int(PyTuple_Size(args));
        if count < 0 {
            raise boundary_failure();
        }
        if count < minimum or count > maximum {
            if self.message {
                object_error(PyExc_TypeError, self.message);
            } else {
                bound = minimum if count < minimum else maximum;
                quantity = "exactly"
                    if minimum == maximum
                    else ("at least" if count < minimum else "at most");
                plural = "" if bound == 1 else "s";
                object_error(
                    PyExc_TypeError,
                    f"{self.caller()} takes {quantity} {bound} argument{plural} ({count} given)"
                );
            }
            raise boundary_failure();
        }
        return [PyTuple_GetItem(args, i64(i)) for i in range(count)];
    }

    # PyArg_ParseTuple(args, units).
    def parse(args: ptr[PyObject], units: str) -> list[ArgumentValue] {
        kinds = units.replace("|", "");
        minimum = units.index("|") if "|" in units else len(units);
        items = self.unpack(args, minimum, len(kinds));
        values: list[ArgumentValue] = [];
        for i in range(len(kinds)) {
            values.append(
                self.convert(kinds[i], items[i], i + 1)
                    if i < len(items)
                    else ArgumentValue()
            );
        }
        return values;
    }

    # PyArg_ParseTupleAndKeywords(args, kwargs, units, keywords):
    # vgetargskeywords(), arguments converted in parameter order.
    def parse_keywords(
        args: ptr[PyObject], kwargs: ptr[PyObject], units: str, keywords: list[str]
    ) -> list[ArgumentValue] {
        kinds = units.replace("|", "").replace("$", "");
        count = len(keywords);
        minimum = units.replace("$", "").find("|");
        minimum = count if minimum < 0 else minimum;
        maximum = units.replace("|", "").find("$");
        maximum = count if maximum < 0 else maximum;
        nargs = int(PyTuple_Size(args));
        nkwargs = int(PyDict_Size(kwargs)) if kwargs else 0;
        shown = self.name or "function";
        called = "()" if self.name else "";
        if nargs + nkwargs > count {
            object_error(
                PyExc_TypeError,
                f"{shown}{called} takes at most {count} {'keyword '
                    if nargs == 0
                    else ''}argument{'' if count == 1 else 's'} ({nargs
                    + nkwargs} given)"
            );
            raise boundary_failure();
        }
        values = [ArgumentValue() for _ in range(count)];
        remaining = nkwargs;
        for i in range(count) {
            # Reaching "$" with more positional arguments than it allows.
            if i == maximum and maximum < nargs {
                if maximum == 0 {
                    object_error(
                        PyExc_TypeError, f"{shown}{called} takes no positional arguments"
                    );
                } else {
                    quantity = "at most" if "|" in units else "exactly";
                    object_error(
                        PyExc_TypeError,
                        f"{shown}{called} takes {quantity} {maximum} positional argument{''
                            if maximum == 1
                            else 's'} ({nargs} given)"
                    );
                }
                raise boundary_failure();
            }
            current = NULL;
            owned = False;
            if i < nargs {
                current = PyTuple_GetItem(args, i64(i));
            } elif remaining > 0 {
                found = NULL;
                if PyDict_GetItemStringRef(kwargs, keywords[i], &mut found) < 0 {
                    raise boundary_failure();
                }
                if found {
                    current = found;
                    owned = True;
                    remaining -= 1;
                }
            }
            if current {
                try {
                    values[i] = self.convert(kinds[i], current, i + 1);
                } finally {
                    if owned {
                        jacpy_release(current);
                    }
                }
                continue;
            }
            if i < minimum {
                object_error(
                    PyExc_TypeError,
                    f"{shown}{called} missing required argument '{keywords[i]}' (pos {i
                        + 1})"
                );
                raise boundary_failure();
            }
            if remaining == 0 {
                return values;
            }
        }
        if remaining > 0 {
            self.extraneous_keyword(args, kwargs, keywords);
        }
        return values;
    }

    # vgetargskeywords()'s report for keywords that name no parameter or
    # repeat a positional one.
    def extraneous_keyword(
        args: ptr[PyObject], kwargs: ptr[PyObject], keywords: list[str]
    ) {
        shown = self.name or "function";
        called = "()" if self.name else "";
        for i in range(int(PyTuple_Size(args))) {
            found = NULL;
            if PyDict_GetItemStringRef(kwargs, keywords[i], &mut found) < 0 {
                raise boundary_failure();
            }
            if found {
                jacpy_release(found);
                object_error(
                    PyExc_TypeError,
                    f"argument for {shown}{called} given by name ('{keywords[
                        i
                    ]}') and position ({i + 1})"
                );
                raise boundary_failure();
            }
        }
        items = required(PyDict_Items(kwargs));
        try {
            for j in range(int(jacpy_list_size(items))) {
                item = required(PyList_GetItemRef(items, i64(j)));
                key = NULL;
                try {
                    key = required(jacpy_tuple_item(item, 0));
                    if jacpy_is_unicode(key) == 0 {
                        object_error(PyExc_TypeError, "keywords must be strings");
                        raise boundary_failure();
                    }
                    if text_value(key) in keywords {
                        continue;
                    }
                    self.unexpected_keyword(key, keywords);
                } finally {
                    jacpy_release(key);
                    jacpy_release(item);
                }
            }
        } finally {
            jacpy_release(items);
        }
        object_error(
            PyExc_TypeError,
            f"invalid keyword argument for {self.name or 'this function'}{called}"
        );
        raise boundary_failure();
    }

    def unexpected_keyword(key: ptr[PyObject], keywords: list[str]) {
        shown = self.name or "this function";
        called = "()" if self.name else "";
        candidates = required(PyList_New(i64(len(keywords))));
        suggestion = NULL;
        try {
            for i in range(len(keywords)) {
                if PyList_SetItem(
                    candidates, i64(i), required(PyUnicode_FromString(keywords[i]))
                )
                    < 0 {
                    raise boundary_failure();
                }
            }
            suggestion = _Py_CalculateSuggestions(candidates, key);
            if suggestion {
                object_error(
                    PyExc_TypeError,
                    f"{shown}{called} got an unexpected keyword argument '{text_value(
                        key
                    )}'. Did you mean '{text_value(suggestion)}'?"
                );
            } else {
                object_error(
                    PyExc_TypeError,
                    f"{shown}{called} got an unexpected keyword argument '{text_value(
                        key
                    )}'"
                );
            }
        } finally {
            jacpy_release(suggestion);
            jacpy_release(candidates);
        }
        raise boundary_failure();
    }
}
