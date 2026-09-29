"""Argument ownership and signature binding shared by native Python adapters."""

import from jaclang.runtime.python.cpython_api {
    jacpy_dict_size,
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
    PyDict_Next,
    PyDict_Size,
    PyErr_NoMemory,
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
    PyMem_Free,
    PyMem_Malloc,
    PyNumber_Index,
    PyObject,
    jacpy_tuple_items,
    PyUnicode_InternFromString,
    PyUnicode_Equal,
    PyObject_IsTrue,
    PyTuple_GetItem,
    PyTuple_New,
    PyTuple_SetItem,
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

# A call's arguments bound to parameters, as new references (NULL for an
# omitted one). A parser that converts while it binds (PARSE_FORMAT_KEYWORDS)
# leaves its TypeError in `failure`, raised by reach() when conversion gets
# to parameter `failure_at`.
obj BoundArguments {
    has values: list[ptr[PyObject]],
        context: ptr[PyObject] = NULL,
        keywords: ptr[PyObject] = NULL,
        failure: str = "",
        failure_at: int = -1;

    def fail_at(index: int, message: str) {
        self.failure = message;
        self.failure_at = index;
    }

    # Called before converting parameter `index` (len(values) before the
    # implementation runs).
    def reach(index: int) {
        if self.failure_at >= 0 and index >= self.failure_at {
            object_error(PyExc_TypeError, self.failure);
            raise boundary_failure();
        }
    }

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

# The Python/getargs.c routine a CallSignature applies, as Argument Clinic
# chooses it for the function (Tools/clinic/libclinic/parse_args.py):
#   PARSE_AUTO         hand-written signatures: PARSE_POSITIONAL, rejecting
#                      keywords, when every parameter is positional-only,
#                      otherwise PARSE_KEYWORDS
#   PARSE_POSITIONAL   _PyArg_CheckPositional()
#   PARSE_KEYWORDS     _PyArg_UnpackKeywords()
#   PARSE_FORMAT       the arity check of PyArg_ParseTuple() / _PyArg_ParseStack()
#   PARSE_FORMAT_KEYWORDS
#                      PyArg_ParseTupleAndKeywords() (vgetargskeywords()), which
#                      converts each argument as it binds it
#   PARSE_NOTHING      _PyArg_NoPositional() and _PyArg_NoKeywords() (a
#                      parameterless tp_new or tp_init)
#   PARSE_NO_ARGUMENTS a parameterless defining-class method's
#                      "takes no arguments"
#   PARSE_GIVEN        METH_NOARGS and METH_O: CPython's call already checked
glob PARSE_AUTO: int = 0,
     PARSE_POSITIONAL: int = 1,
     PARSE_KEYWORDS: int = 2,
     PARSE_FORMAT: int = 3,
     PARSE_NOTHING: int = 4,
     PARSE_NO_ARGUMENTS: int = 5,
     PARSE_GIVEN: int = 6,
     PARSE_FORMAT_KEYWORDS: int = 7;

# The keyword arguments of one call, borrowed: from a kwargs dict in its
# iteration order, or from a vectorcall's kwnames and the values after the
# positional ones. `names` holds each key's text ("" for a non-str key).
obj KeywordArguments {
    has keys: list[ptr[PyObject]] = [],
        names: list[str] = [],
        values: list[ptr[PyObject]] = [];

    def add(key: ptr[PyObject], value: ptr[PyObject]) {
        self.keys.append(key);
        self.names.append(text_value(key) if jacpy_is_unicode(key) != 0 else "");
        self.values.append(value);
    }

    # find_keyword(): the value passed under `name`, or NULL.
    def find(name: str) -> ptr[PyObject] {
        for i in range(len(self.keys)) {
            if self.names[i] == name and jacpy_is_unicode(self.keys[i]) != 0 {
                return self.values[i];
            }
        }
        return NULL;
    }
}

def keywords_of_dict(kwargs: ptr[PyObject]) -> KeywordArguments {
    found = KeywordArguments();
    if kwargs == 0 {
        return found;
    }
    position: i64 = 0;
    key: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    while PyDict_Next(kwargs, &mut position, &mut key, &mut value) != 0 {
        found.add(key, value);
    }
    return found;
}

def keywords_of_vector(
    args: ptr[ptr[PyObject]], nargs: int, kwnames: ptr[PyObject]
) -> KeywordArguments {
    found = KeywordArguments();
    if kwnames == 0 {
        return found;
    }
    count = int(PyTuple_Size(kwnames));
    stack = args.view(nargs + count);
    for i in range(count) {
        found.add(PyTuple_GetItem(kwnames, i64(i)), stack[nargs + i]);
    }
    return found;
}

def plural(count: int) -> str {
    return "" if count == 1 else "s";
}

# A native function's parameters and the getargs routine that binds them.
# `name` is the name clinic's messages use (the class name for tp_new and
# tp_init); `required_count` is clinic's min_pos, `positional_count` its
# max_pos, `positional_only` its pos_only and `keyword_required` its
# min_kw_only. The positional parsers refuse keywords first, as
# _PyArg_NoKeywords() does for tp_new and tp_init (a METH_FASTCALL call
# never passes any).
obj CallSignature {
    has name: str,
        names: list[str],
        required_count: int,
        positional_count: int,
        positional_only: int = 0,
        keyword_required: int = 0,
        parser: int = PARSE_AUTO,
        interned: list[ptr[PyObject]] = [];

    # getargs' "%.200s%s" of fname: an empty name (a format without ':name')
    # reads "function".
    def caller -> str {
        return f"{self.name}()" if self.name else "function";
    }

    def bind(
        result: BoundArguments, args: ptr[PyObject], kwargs: ptr[PyObject]
    ) -> bool {
        count = int(PyTuple_Size(args));
        if count < 0 {
            return False;
        }
        positional = [PyTuple_GetItem(args, i64(i)) for i in range(count)];
        return self.bind_values(result, positional, keywords_of_dict(kwargs));
    }

    def bind_vector(
        result: BoundArguments,
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwnames: ptr[PyObject]
    ) -> bool {
        count = int(nargs);
        positional: list[ptr[PyObject]] = [];
        if count > 0 {
            stack = args.view(count);
            positional = [stack[i] for i in range(count)];
        }
        return self.bind_values(
            result, positional, keywords_of_vector(args, count, kwnames)
        );
    }

    # Bind borrowed positional and keyword arguments to result.values as
    # new references; False with the TypeError set on a mismatch.
    def bind_values(
        result: BoundArguments,
        positional: list[ptr[PyObject]],
        keywords: KeywordArguments
    ) -> bool {
        parser = self.parser;
        if parser == PARSE_AUTO {
            parser = PARSE_POSITIONAL
                if self.positional_only == len(self.names)
                else PARSE_KEYWORDS;
        }
        count = len(positional);
        if parser == PARSE_NOTHING and count > 0 {
            return invalid(f"{self.name}() takes no positional arguments");
        }
        if parser == PARSE_NO_ARGUMENTS and (count > 0 or keywords.keys) {
            return invalid(f"{self.name}() takes no arguments");
        }
        if keywords.keys
            and parser
                in (PARSE_POSITIONAL, PARSE_FORMAT, PARSE_NOTHING, PARSE_GIVEN) {
            return invalid(f"{self.name}() takes no keyword arguments");
        }
        if parser == PARSE_KEYWORDS {
            return self.unpack_keywords(result, positional, keywords);
        }
        if parser == PARSE_FORMAT_KEYWORDS {
            return self.format_keywords(result, positional, keywords);
        }
        if parser == PARSE_POSITIONAL {
            if self.parser == PARSE_AUTO and not self.names and count > 0 {
                return invalid(f"{self.name}() takes no arguments ({count} given)");
            }
            if not check_positional(
                self.name, count, self.required_count, self.positional_count
            ) {
                return False;
            }
        } elif parser == PARSE_FORMAT {
            low = self.required_count;
            high = self.positional_count;
            if count < low or count > high {
                bound = low if count < low else high;
                quantity = "exactly"
                    if low == high
                    else ("at least" if count < low else "at most");
                return invalid(
                    f"{self.caller()} takes {quantity} {bound} argument{plural(bound)} ({count} given)"
                );
            }
        }
        for i in range(min(count, len(result.values))) {
            result.values[i] = Py_NewRef(positional[i]);
        }
        return True;
    }

    # The parameter names as interned str, made on first use: a keyword is
    # found by identity first and by value second, as find_keyword() does.
    def keys -> list[ptr[PyObject]] {
        if len(self.interned) != len(self.names) {
            made: list[ptr[PyObject]] = [];
            for name in self.names {
                made.append(PyUnicode_InternFromString(name));
            }
            self.interned = made;
        }
        return self.interned;
    }

    # The index of the parameter that keyword `key` names at or after
    # `start`, or -1.
    def keyword_slot(key: ptr[PyObject], start: int) -> int {
        known = self.keys();
        for i in range(start, len(known)) {
            if known[i] == key {
                return i;
            }
        }
        for i in range(start, len(known)) {
            if known[i] != NULL and PyUnicode_Equal(known[i], key) == 1 {
                return i;
            }
        }
        return -1;
    }

    # unpack_stack()'s and unpack_mapping()'s bind: positional values, then
    # `nkw` keyword names and their values; NULL for anything the parser
    # must report.
    def unpack_array(
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwnames: ptr[ptr[PyObject]],
        kwvalues: ptr[ptr[PyObject]],
        nkw: i64
    ) -> ptr[ptr[PyObject]] {
        none = ptr[ptr[PyObject]](0);
        total = len(self.names);
        posonly = self.positional_only;
        maxpos = self.positional_count;
        minpos = self.required_count;
        count = int(nargs);
        if count > maxpos or count < min(posonly, minpos) or count + int(nkw) > total {
            return none;
        }
        array = ptr[ptr[PyObject]](PyMem_Malloc(u64(max(total, 1) * 8)));
        if array == 0 {
            return none;
        }
        slots = array.view(total);
        for i in range(total) {
            slots[i] = NULL;
        }
        if count > 0 {
            given = args.view(count);
            for i in range(count) {
                slots[i] = given[i];
            }
        }
        if nkw > 0 {
            keys = kwnames.view(int(nkw));
            values = kwvalues.view(int(nkw));
            start = max(count, posonly);
            for j in range(int(nkw)) {
                key = keys[j];
                slot = self.keyword_slot(key, start)
                    if jacpy_is_unicode(key) != 0
                    else -1;
                if slot < 0 or slots[slot] != NULL {
                    PyMem_Free(array);
                    return none;
                }
                slots[slot] = values[j];
            }
        }
        required = maxpos + self.keyword_required if self.keyword_required else minpos;
        for i in range(total) {
            if slots[i] == NULL and (i < minpos or (maxpos <= i and i < required)) {
                PyMem_Free(array);
                return none;
            }
        }
        return array;
    }

    # _PyArg_UnpackKeywords() without var-positional parameters.
    def unpack_keywords(
        result: BoundArguments,
        positional: list[ptr[PyObject]],
        keywords: KeywordArguments
    ) -> bool {
        nargs = len(positional);
        nkwargs = len(keywords.keys);
        posonly = self.positional_only;
        minpos = self.required_count;
        maxpos = self.positional_count;
        minkw = self.keyword_required;
        maxargs = len(self.names);
        reqlimit = maxpos + minkw if minkw else minpos;
        minposonly = min(posonly, minpos);
        caller = self.caller();
        if nkwargs == 0 and minkw == 0 and minpos <= nargs and nargs <= maxpos {
            for i in range(nargs) {
                result.values[i] = Py_NewRef(positional[i]);
            }
            return True;
        }
        if nargs + nkwargs > maxargs {
            return invalid(
                f"{caller} takes at most {maxargs} {'keyword '
                    if nargs == 0
                    else ''}argument{plural(maxargs)} ({nargs + nkwargs} given)"
            );
        }
        if nargs > maxpos {
            if maxpos == 0 {
                return invalid(f"{caller} takes no positional arguments");
            }
            return invalid(
                f"{caller} takes {'at most' if minpos < maxpos else 'exactly'} {maxpos} positional argument{plural(
                    maxpos
                )} ({nargs} given)"
            );
        }
        if nargs < minposonly {
            return invalid(
                f"{caller} takes {'at least' if minposonly < maxpos else 'exactly'} {minposonly} positional argument{plural(
                    minposonly
                )} ({nargs} given)"
            );
        }
        for i in range(nargs) {
            result.values[i] = Py_NewRef(positional[i]);
        }
        remaining = nkwargs;
        for i in range(max(nargs, posonly), maxargs) {
            current: ptr[PyObject] = NULL;
            if remaining {
                current = keywords.find(self.names[i]);
            } elif i >= reqlimit {
                break;
            }
            if current {
                result.values[i] = Py_NewRef(current);
                remaining -= 1;
            } elif i < minpos or (maxpos <= i and i < reqlimit) {
                return invalid(
                    f"{caller} missing required argument '{self.names[i]}' (pos {i
                        + 1})"
                );
            }
        }
        if remaining > 0 {
            for i in range(posonly, nargs) {
                if keywords.find(self.names[i]) {
                    return invalid(
                        f"argument for {caller} given by name ('{self.names[
                            i
                        ]}') and position ({i + 1})"
                    );
                }
            }
            return invalid(
                unexpected_keyword(self.name, self.names[posonly:], keywords)
            );
        }
        return True;
    }

    # vgetargskeywords() for a clinic format: '|' before the first optional
    # parameter, '$' before the first keyword-only one. An error found after
    # some arguments were bound is deferred to result.reach(), so conversion
    # errors of the arguments before it come first, as in getargs.
    def format_keywords(
        result: BoundArguments,
        positional: list[ptr[PyObject]],
        keywords: KeywordArguments
    ) -> bool {
        nargs = len(positional);
        remaining = len(keywords.keys);
        total = len(self.names);
        pos = self.positional_only;
        caller = self.caller();
        if nargs + remaining > total {
            return invalid(
                f"{caller} takes at most {total} {'keyword '
                    if nargs == 0
                    else ''}argument{plural(total)} ({nargs + remaining} given)"
            );
        }
        # INT_MAX stands for a format without '|' or '$'.
        unbounded = 0x7FFFFFFF;
        optional = self.keyword_required == 0 and self.required_count < total;
        low = self.required_count if optional else unbounded;
        high = self.positional_count if self.positional_count < total else unbounded;
        skipping = False;
        i = 0;
        while i < total {
            if i == high {
                if skipping {
                    break;
                }
                if high < nargs {
                    if high == 0 {
                        result.fail_at(i, f"{caller} takes no positional arguments");
                    } else {
                        result.fail_at(
                            i,
                            f"{caller} takes {'at most'
                                if low != unbounded
                                else 'exactly'} {high} positional argument{plural(
                                high
                            )} ({nargs} given)"
                        );
                    }
                    return True;
                }
            }
            if not skipping {
                current: ptr[PyObject] = NULL;
                if i < nargs {
                    current = positional[i];
                } elif remaining and i >= pos {
                    current = keywords.find(self.names[i]);
                    if current {
                        remaining -= 1;
                    }
                }
                if current {
                    result.values[i] = Py_NewRef(current);
                    i += 1;
                    continue;
                }
                if i < low {
                    if i < pos {
                        skipping = True;
                    } else {
                        result.fail_at(
                            i,
                            f"{caller} missing required argument '{self.names[i]}' (pos {i
                                + 1})"
                        );
                        return True;
                    }
                }
                if not remaining and not skipping {
                    return True;
                }
            }
            i += 1;
        }
        if skipping {
            least = min(pos, low);
            result.fail_at(
                i,
                f"{caller} takes {'at least' if least < i else 'exactly'} {least} positional argument{plural(
                    least
                )} ({nargs} given)"
            );
            return True;
        }
        if remaining > 0 {
            for j in range(pos, nargs) {
                if keywords.find(self.names[j]) {
                    result.fail_at(
                        total,
                        f"argument for {caller} given by name ('{self.names[
                            j
                        ]}') and position ({j + 1})"
                    );
                    return True;
                }
            }
            result.fail_at(
                total, unexpected_keyword(self.name, self.names[pos:], keywords)
            );
        }
        return True;
    }
}

# _PyArg_CheckPositional() with a function name.
def check_positional(name: str, nargs: int, low: int, high: int) -> bool {
    if nargs < low {
        qualifier = "" if low == high else "at least ";
        return invalid(
            f"{name} expected {qualifier}{low} argument{plural(low)}, got {nargs}"
        );
    }
    if nargs > high {
        qualifier = "" if low == high else "at most ";
        return invalid(
            f"{name} expected {qualifier}{high} argument{plural(high)}, got {nargs}"
        );
    }
    return True;
}

# error_unexpected_keyword_arg()'s message: the first keyword that names
# no keyword parameter, with _Py_CalculateSuggestions()'s near match.
def unexpected_keyword(
    name: str, accepted: list[str], keywords: KeywordArguments
) -> str {
    shown = f"{name}()" if name else "this function";
    for i in range(len(keywords.keys)) {
        key = keywords.keys[i];
        if jacpy_is_unicode(key) == 0 {
            return "keywords must be strings";
        }
        if keywords.names[i] in accepted {
            continue;
        }
        candidates = required(PyList_New(i64(len(accepted))));
        suggestion: ptr[PyObject] = NULL;
        try {
            for j in range(len(accepted)) {
                if PyList_SetItem(
                    candidates, i64(j), required(PyUnicode_FromString(accepted[j]))
                )
                    < 0 {
                    raise boundary_failure();
                }
            }
            suggestion = _Py_CalculateSuggestions(candidates, key);
            if suggestion {
                return f"{shown} got an unexpected keyword argument '{keywords.names[
                    i
                ]}'. Did you mean '{text_value(suggestion)}'?";
            }
            return f"{shown} got an unexpected keyword argument '{keywords.names[i]}'";
        } finally {
            jacpy_release(suggestion);
            jacpy_release(candidates);
        }
    }
    return f"invalid keyword argument for {shown}";
}

# Run `implementation` over bound arguments. The call frame lives outside the
# exception region: every exit releases all converted arguments, including a
# failure in a nested conversion.
def call_bound(
    bound: BoundArguments, implementation: Callable[[BoundArguments], ptr[PyObject]]
) -> ptr[PyObject] {
    try {
        return implementation(bound);
    } except boundary_failure {
        return NULL;
    }
}

# A METH_VARARGS or METH_VARARGS|METH_KEYWORDS call (and tp_new / tp_init).
# `checked` False is clinic's failed self_type_check for tp_new/tp_init: a
# subclass that replaced the other slot, where _PyArg_NoKeywords() and
# _PyArg_NoPositional() are skipped.
def invoke(
    signature: CallSignature,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    implementation: Callable[[BoundArguments], ptr[PyObject]],
    context: ptr[PyObject] = 0,
    forward_keywords: bool = False,
    checked: bool = True
) -> ptr[PyObject] {
    if not checked {
        if signature.parser == PARSE_NOTHING {
            return call_bound(BoundArguments([], context), implementation);
        }
        kwargs = NULL;
    }
    bound = BoundArguments([NULL for _ in signature.names], context);
    if forward_keywords and kwargs != 0 {
        bound.keywords = Py_NewRef(kwargs);
    }
    try {
        if not signature.bind(bound, args, NULL if forward_keywords else kwargs) {
            return NULL;
        }
    } except boundary_failure {
        return NULL;
    }
    return call_bound(bound, implementation);
}

# A METH_FASTCALL or METH_FASTCALL|METH_KEYWORDS call.
def invoke_vector(
    signature: CallSignature,
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject],
    implementation: Callable[[BoundArguments], ptr[PyObject]],
    context: ptr[PyObject] = 0
) -> ptr[PyObject] {
    bound = BoundArguments([NULL for _ in signature.names], context);
    try {
        if not signature.bind_vector(bound, args, nargs, kwnames) {
            return NULL;
        }
    } except boundary_failure {
        return NULL;
    }
    return call_bound(bound, implementation);
}

# The generated glue's slow path. Its bound function takes the receiver and a
# borrowed array of parameter values (NULL for an omitted one) with its length;
# the glue passes the vectorcall stack or a tuple's items directly when
# clinic's own fast path applies (no keywords, an accepted positional count),
# and these bind everything else through the signature's parser, with its
# messages, into an array as long as the parameter list.
def call_values(
    bound: BoundArguments,
    implementation: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]]
) -> ptr[PyObject] {
    count = len(bound.values);
    if count == 0 {
        return implementation(bound.context, ptr[ptr[PyObject]](0), i64(0));
    }
    array = ptr[ptr[PyObject]](PyMem_Malloc(u64(count * 8)));
    if array == 0 {
        return PyErr_NoMemory();
    }
    slots = array.view(count);
    for i in range(count) {
        slots[i] = bound.values[i];
    }
    result = implementation(bound.context, array, i64(count));
    PyMem_Free(array);
    return result;
}

# _PyArg_UnpackKeywords()'s successful binds, without its messages: a new
# array of len(signature.names) borrowed values (NULL for an omitted one),
# freed by the caller with PyMem_Free. NULL when the call needs the parser's
# checks (a bad count, a missing, unexpected or repeated argument, a non-str
# keyword); invoke_stack() then reports it as CPython does.
def unpack_stack(
    signature: CallSignature,
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[ptr[PyObject]] {
    nkw = PyTuple_Size(kwnames) if kwnames else i64(0);
    return signature.unpack_array(
        args, nargs, kwnames_items(kwnames), args + nargs, nkw
    );
}

# The same over a call's tuple and keyword dict.
def unpack_mapping(
    signature: CallSignature, args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[ptr[PyObject]] {
    nargs = PyTuple_Size(args);
    count = jacpy_dict_size(kwargs) if kwargs else i64(0);
    none = ptr[ptr[PyObject]](0);
    if count == 0 {
        return signature.unpack_array(jacpy_tuple_items(args), nargs, none, none, 0);
    }
    pairs = ptr[ptr[PyObject]](PyMem_Malloc(u64(count * 16)));
    if pairs == 0 {
        return none;
    }
    slots = pairs.view(int(count * 2));
    position: i64 = 0;
    key: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    index = 0;
    while index < int(count)
        and PyDict_Next(kwargs, &mut position, &mut key, &mut value) != 0 {
        slots[index] = key;
        slots[int(count) + index] = value;
        index += 1;
    }
    result = signature.unpack_array(
        jacpy_tuple_items(args), nargs, pairs, pairs + count, count
    );
    PyMem_Free(pairs);
    return result;
}

def kwnames_items(kwnames: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return jacpy_tuple_items(kwnames) if kwnames else ptr[ptr[PyObject]](0);
}

# A METH_FASTCALL or METH_FASTCALL|METH_KEYWORDS call off its fast path.
def invoke_stack(
    signature: CallSignature,
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject],
    implementation: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]],
    context: ptr[PyObject]
) -> ptr[PyObject] {
    bound = BoundArguments([NULL for _ in signature.names], context);
    try {
        if not signature.bind_vector(bound, args, nargs, kwnames) {
            return NULL;
        }
    } except boundary_failure {
        return NULL;
    }
    return call_values(bound, implementation);
}

# A METH_VARARGS|METH_KEYWORDS call, tp_new or tp_init off its fast path;
# `checked` as for invoke().
def invoke_tuple(
    signature: CallSignature,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    implementation: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]],
    context: ptr[PyObject],
    checked: bool = True
) -> ptr[PyObject] {
    if not checked {
        if signature.parser == PARSE_NOTHING {
            return implementation(context, ptr[ptr[PyObject]](0), i64(0));
        }
        kwargs = NULL;
    }
    bound = BoundArguments([NULL for _ in signature.names], context);
    try {
        if not signature.bind(bound, args, kwargs) {
            return NULL;
        }
    } except boundary_failure {
        return NULL;
    }
    return call_values(bound, implementation);
}

# A METH_NOARGS or METH_O call: CPython's call checked the arity, so the
# argument (NULL for none) is the one value.
def invoke_given(
    value: ptr[PyObject],
    implementation: Callable[[BoundArguments], ptr[PyObject]],
    context: ptr[PyObject] = 0
) -> ptr[PyObject] {
    bound = BoundArguments([Py_NewRef(value)] if value else [], context);
    return call_bound(bound, implementation);
}

# A METH_FASTCALL call's positional arguments as a new tuple, for an
# implementation that takes them the METH_VARARGS way; NULL on failure.
def vector_tuple(args: ptr[ptr[PyObject]], nargs: i64) -> ptr[PyObject] {
    result = PyTuple_New(nargs);
    if not result or nargs == 0 {
        return result;
    }
    stack = args.view(int(nargs));
    for i in range(int(nargs)) {
        if PyTuple_SetItem(result, i64(i), Py_NewRef(stack[i])) < 0 {
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
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

# A format's units analysed once: the conversion units without '|' and '$',
# the index of the first optional one and of the first keyword-only one
# (the unit count when absent), and whether it has a '|'.
obj FormatPlan {
    has kinds: str,
        minimum: int,
        maximum: int,
        optional: bool;
}

glob FORMAT_PLANS: dict[str, FormatPlan] = {},
     # The value of every omitted argument; callers only read it.
     ABSENT = ArgumentValue();

def format_plan(units: str) -> FormatPlan {
    if units in FORMAT_PLANS {
        return FORMAT_PLANS[units];
    }
    kinds = units.replace("|", "").replace("$", "");
    minimum = units.replace("$", "").find("|");
    maximum = units.replace("|", "").find("$");
    plan = FormatPlan(
        kinds=kinds,
        minimum=len(kinds) if minimum < 0 else minimum,
        maximum=len(kinds) if maximum < 0 else maximum,
        optional="|" in units
    );
    FORMAT_PLANS[units] = plan;
    return plan;
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
            PyExc_TypeError,
            f"{caller}argument {position} must be {expected}, not {shown}"
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
        plan = format_plan(units);
        kinds = plan.kinds;
        items = self.unpack(args, plan.minimum, len(kinds));
        values: list[ArgumentValue] = [];
        for i in range(len(kinds)) {
            values.append(
                self.convert(kinds[i], items[i], i + 1) if i < len(items) else ABSENT
            );
        }
        return values;
    }

    # PyArg_ParseTupleAndKeywords(args, kwargs, units, keywords):
    # vgetargskeywords(), arguments converted in parameter order.
    def parse_keywords(
        args: ptr[PyObject], kwargs: ptr[PyObject], units: str, keywords: list[str]
    ) -> list[ArgumentValue] {
        plan = format_plan(units);
        kinds = plan.kinds;
        count = len(keywords);
        minimum = plan.minimum;
        maximum = plan.maximum;
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
        values = [ABSENT for _ in range(count)];
        remaining = nkwargs;
        for i in range(count) {
            # Reaching "$" with more positional arguments than it allows.
            if i == maximum and maximum < nargs {
                if maximum == 0 {
                    object_error(
                        PyExc_TypeError,
                        f"{shown}{called} takes no positional arguments"
                    );
                } else {
                    quantity = "at most" if plan.optional else "exactly";
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
