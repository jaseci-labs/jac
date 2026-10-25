obj BoundArguments {
    has values: list[ptr[PyObject]],
        context: ptr[PyObject] = NULL,
        keywords: ptr[PyObject] = NULL,
        failure: str = "",
        failure_at: int = -1,
        nargs: int = 0;

    def fail_at(index: int, message: str);
    def reach(index: int);
    def drop;
}

def invalid(message: str) -> bool;

def index_value(value: ptr[PyObject]) -> (i64 | None);

glob PARSE_AUTO: int = 0,
     PARSE_POSITIONAL: int = 1,
     PARSE_KEYWORDS: int = 2,
     PARSE_FORMAT: int = 3,
     PARSE_NOTHING: int = 4,
     PARSE_NO_ARGUMENTS: int = 5,
     PARSE_GIVEN: int = 6,
     PARSE_FORMAT_KEYWORDS: int = 7;

obj KeywordArguments {
    has keys: list[ptr[PyObject]] = [],
        names: list[str] = [],
        values: list[ptr[PyObject]] = [];

    def add(key: ptr[PyObject], value: ptr[PyObject]);
    def find(name: str) -> ptr[PyObject];
}

def keywords_of_dict(kwargs: ptr[PyObject]) -> KeywordArguments;

def keywords_of_vector(
    args: ptr[ptr[PyObject]], nargs: int, kwnames: ptr[PyObject]
) -> KeywordArguments;

def plural(count: int) -> str;

obj CallSignature {
    has name: str,
        names: list[str],
        required_count: int,
        positional_count: int,
        positional_only: int = 0,
        keyword_required: int = 0,
        parser: int = PARSE_AUTO,
        interned: list[ptr[PyObject]] = [],
        positional_warning: str = "",
        positional_warn_range: tuple[int, int] = (0, 0),
        keyword_warning: str = "",
        keyword_warn_required: int = -1,
        keyword_warn_optional: list[int] = [];

    def warn(message: str) -> bool;
    def bind_values(
        result: BoundArguments,
        positional: list[ptr[PyObject]],
        keywords: KeywordArguments
    ) -> bool;

    def caller -> str;
    def bind(
        result: BoundArguments, args: ptr[PyObject], kwargs: ptr[PyObject]
    ) -> bool;

    def bind_vector(
        result: BoundArguments,
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwnames: ptr[PyObject]
    ) -> bool;

    def bind_arguments(
        result: BoundArguments,
        positional: list[ptr[PyObject]],
        keywords: KeywordArguments
    ) -> bool;

    def keys -> list[ptr[PyObject]];
    def keyword_slot(key: ptr[PyObject], start: int) -> int;
    def unpack_array(
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwnames: ptr[ptr[PyObject]],
        kwvalues: ptr[ptr[PyObject]],
        nkw: i64
    ) -> ptr[ptr[PyObject]];

    def unpack_keywords(
        result: BoundArguments,
        positional: list[ptr[PyObject]],
        keywords: KeywordArguments
    ) -> bool;

    def format_keywords(
        result: BoundArguments,
        positional: list[ptr[PyObject]],
        keywords: KeywordArguments
    ) -> bool;
}

def check_positional(name: str, nargs: int, low: int, high: int) -> bool;

def unexpected_keyword(
    name: str, accepted: list[str], keywords: KeywordArguments
) -> str;

def call_bound(
    bound: BoundArguments, implementation: Callable[[BoundArguments], ptr[PyObject]]
) -> ptr[PyObject];

def invoke(
    signature: CallSignature,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    implementation: Callable[[BoundArguments], ptr[PyObject]],
    context: ptr[PyObject] = 0,
    forward_keywords: bool = False,
    checked: bool = True
) -> ptr[PyObject];

def invoke_vector(
    signature: CallSignature,
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject],
    implementation: Callable[[BoundArguments], ptr[PyObject]],
    context: ptr[PyObject] = 0
) -> ptr[PyObject];

def call_values(
    bound: BoundArguments,
    implementation: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]]
) -> ptr[PyObject];

def unpack_stack(
    signature: CallSignature,
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[ptr[PyObject]];

def unpack_mapping(
    signature: CallSignature, args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[ptr[PyObject]];

def kwnames_items(kwnames: ptr[PyObject]) -> ptr[ptr[PyObject]];

def invoke_stack(
    signature: CallSignature,
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject],
    implementation: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]],
    context: ptr[PyObject]
) -> ptr[PyObject];

def invoke_tuple(
    signature: CallSignature,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    implementation: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]],
    context: ptr[PyObject],
    checked: bool = True
) -> ptr[PyObject];

def invoke_given(
    value: ptr[PyObject],
    implementation: Callable[[BoundArguments], ptr[PyObject]],
    context: ptr[PyObject] = 0
) -> ptr[PyObject];

def vector_tuple(args: ptr[ptr[PyObject]], nargs: i64) -> ptr[PyObject];

def invoke_one(
    value: ptr[PyObject], implementation: Callable[[ptr[PyObject]], ptr[PyObject]]
) -> ptr[PyObject];

def character_value(value: ptr[PyObject], context: str) -> (i64 | None);


obj ArgumentValue {
    has given: bool = False,
        object: ptr[PyObject] = NULL,
        signed: i64 = 0,
        unsigned: u64 = 0,
        flag: bool = False,
        text: str = "";
}

obj FormatPlan {
    has kinds: list[str],
        minimum: int,
        maximum: int,
        optional: bool;
}

glob FORMAT_PLANS: dict[str, FormatPlan] = {},
     ABSENT = ArgumentValue();

def format_plan(units: str) -> FormatPlan;

obj ArgumentFormat {
    has name: str = "",
        message: str = "",
        types: list[ptr[PyObject]] = [];

    def caller -> str;
    def mismatch(position: int, expected: str, value: ptr[PyObject]);
    def reject(position: int, detail: str);
    def units_of(format: str) -> list[str];
    def expected_types(kinds: list[str]) -> list[ptr[PyObject]];
    def failed -> bool;
    def signed_range(value: i64, low: i64, high: i64, kind: str) -> i64;
    def convert(
        unit: str, value: ptr[PyObject], position: int, type: ptr[PyObject] = NULL
    ) -> ArgumentValue;

    def unpack(args: ptr[PyObject], minimum: int, maximum: int) -> list[ptr[PyObject]];
    def parse(args: ptr[PyObject], units: str) -> list[ArgumentValue];
    def parse_keywords(
        args: ptr[PyObject], kwargs: ptr[PyObject], units: str, keywords: list[str]
    ) -> list[ArgumentValue];

    def extraneous_keyword(
        args: ptr[PyObject], kwargs: ptr[PyObject], keywords: list[str]
    );

    def unexpected_keyword(key: ptr[PyObject], keywords: list[str]);
}

impl BoundArguments.fail_at(index: int, message: str) {
    self.failure = message;
    self.failure_at = index;
}

impl BoundArguments.reach(index: int) {
    if self.failure_at >= 0 and index >= self.failure_at {
        object_error(PyExc_TypeError, self.failure);
        raise boundary_failure();
    }
}

impl BoundArguments.drop {
    for value in self.values {
        jacpy_release(value);
    }
    jacpy_release(self.keywords);
}

impl invalid(message: str) -> bool {
    object_error(PyExc_TypeError, message);
    return False;
}

impl index_value(value: ptr[PyObject]) -> (i64 | None) {
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

impl KeywordArguments.add(key: ptr[PyObject], value: ptr[PyObject]) {
    self.keys.append(key);
    self.names.append(text_value(key) if jacpy_is_unicode(key) != 0 else "");
    self.values.append(value);
}

impl KeywordArguments.find(name: str) -> ptr[PyObject] {
    for i in range(len(self.keys)) {
        if self.names[i] == name and jacpy_is_unicode(self.keys[i]) != 0 {
            return self.values[i];
        }
    }
    return NULL;
}

impl keywords_of_dict(kwargs: ptr[PyObject]) -> KeywordArguments {
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

impl keywords_of_vector(
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

impl plural(count: int) -> str {
    return "" if count == 1 else "s";
}

impl CallSignature.warn(message: str) -> bool {
    text = jacpy_unicode_from_text(message);
    if not text {
        return False;
    }
    status = PyErr_WarnEx(PyExc_DeprecationWarning, PyUnicode_AsUTF8(text), 1);
    jacpy_release(text);
    return status == 0;
}

impl CallSignature.bind_values(
    result: BoundArguments, positional: list[ptr[PyObject]], keywords: KeywordArguments
) -> bool {
    count = len(positional);
    result.nargs = count;
    if self.positional_warning
        and self.positional_warn_range[0] < count
        and count <= self.positional_warn_range[1]
        and not self.warn(self.positional_warning) {
        return False;
    }
    if not self.bind_arguments(result, positional, keywords) {
        return False;
    }
    if self.keyword_warning {
        passed = self.keyword_warn_required >= 0
            and count < self.keyword_warn_required + 1;
        for index in self.keyword_warn_optional {
            if count < index + 1 and result.values[index] != NULL {
                passed = True;
            }
        }
        if passed and not self.warn(self.keyword_warning) {
            return False;
        }
    }
    return True;
}

impl CallSignature.caller -> str {
    return f"{self.name}()" if self.name else "function";
}

impl CallSignature.bind(
    result: BoundArguments, args: ptr[PyObject], kwargs: ptr[PyObject]
) -> bool {
    count = int(PyTuple_Size(args));
    if count < 0 {
        return False;
    }
    positional = [PyTuple_GetItem(args, i64(i)) for i in range(count)];
    return self.bind_values(result, positional, keywords_of_dict(kwargs));
}

impl CallSignature.bind_vector(
    result: BoundArguments, args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
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

impl CallSignature.bind_arguments(
    result: BoundArguments, positional: list[ptr[PyObject]], keywords: KeywordArguments
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
        and parser in (PARSE_POSITIONAL, PARSE_FORMAT, PARSE_NOTHING, PARSE_GIVEN) {
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

impl CallSignature.keys -> list[ptr[PyObject]] {
    if len(self.interned) != len(self.names) {
        made: list[ptr[PyObject]] = [];
        for name in self.names {
            made.append(jacpy_unicode_intern_text(name));
        }
        self.interned = made;
    }
    return self.interned;
}

impl CallSignature.keyword_slot(key: ptr[PyObject], start: int) -> int {
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

impl CallSignature.unpack_array(
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
            slot = self.keyword_slot(key, start) if jacpy_is_unicode(key) != 0 else -1;
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

impl CallSignature.unpack_keywords(
    result: BoundArguments, positional: list[ptr[PyObject]], keywords: KeywordArguments
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
    if nkwargs == 0 and minkw == 0 and minpos <= nargs and nargs <= maxpos {
        for i in range(nargs) {
            result.values[i] = Py_NewRef(positional[i]);
        }
        return True;
    }
    caller = self.caller();
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
                f"{caller} missing required argument '{self.names[i]}' (pos {i + 1})"
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
        return invalid(unexpected_keyword(self.name, self.names[posonly:], keywords));
    }
    return True;
}

impl CallSignature.format_keywords(
    result: BoundArguments, positional: list[ptr[PyObject]], keywords: KeywordArguments
) -> bool {
    nargs = len(positional);
    remaining = len(keywords.keys);
    total = len(self.names);
    pos = self.positional_only;
    caller = self.caller();
    if nargs + remaining > total {
        return invalid(
            f"{caller} takes at most {total} {'keyword ' if nargs == 0 else ''}argument{plural(
                total
            )} ({nargs + remaining} given)"
        );
    }

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
                        f"{caller} takes {'at most' if low != unbounded else 'exactly'} {high} positional argument{plural(
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

impl check_positional(name: str, nargs: int, low: int, high: int) -> bool {
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

impl unexpected_keyword(
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
                    candidates, i64(j), required(jacpy_unicode_from_text(accepted[j]))
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

impl call_bound(
    bound: BoundArguments, implementation: Callable[[BoundArguments], ptr[PyObject]]
) -> ptr[PyObject] {
    try {
        return implementation(bound);
    } except boundary_failure {
        return NULL;
    }
}

impl invoke(
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

impl invoke_vector(
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

impl call_values(
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

impl unpack_stack(
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

impl unpack_mapping(
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

impl kwnames_items(kwnames: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return jacpy_tuple_items(kwnames) if kwnames else ptr[ptr[PyObject]](0);
}

impl invoke_stack(
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

impl invoke_tuple(
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

impl invoke_given(
    value: ptr[PyObject],
    implementation: Callable[[BoundArguments], ptr[PyObject]],
    context: ptr[PyObject] = 0
) -> ptr[PyObject] {
    bound = BoundArguments([Py_NewRef(value)] if value else [], context);
    return call_bound(bound, implementation);
}

impl vector_tuple(args: ptr[ptr[PyObject]], nargs: i64) -> ptr[PyObject] {
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

impl invoke_one(
    value: ptr[PyObject], implementation: Callable[[ptr[PyObject]], ptr[PyObject]]
) -> ptr[PyObject] {
    try {
        return implementation(value);
    } except boundary_failure {
        return NULL;
    }
}

impl character_value(value: ptr[PyObject], context: str) -> (i64 | None) {
    if jacpy_is_unicode(value) == 0 or jacpy_unicode_size(value) != 1 {
        object_error(
            PyExc_TypeError, f"{context}() argument must be a unicode character"
        );
        return None;
    }
    return PyUnicode_ReadChar(value, 0);
}


impl format_plan(units: str) -> FormatPlan {
    if units in FORMAT_PLANS {
        return FORMAT_PLANS[units];
    }

    format: list[str] = [];
    for character in units {
        if character == "!" and format and format[-1] == "O" {
            format[-1] = "O!";
        } else {
            format.append(character);
        }
    }
    kinds = [
        unit
        for unit in format
        if unit != "|" and unit != "$"
    ];
    optional = [
        unit
        for unit in format
        if unit != "$"
    ];
    positional = [
        unit
        for unit in format
        if unit != "|"
    ];
    plan = FormatPlan(
        kinds=kinds,
        minimum=optional.index("|") if "|" in optional else len(kinds),
        maximum=positional.index("$") if "$" in positional else len(kinds),
        optional="|" in format
    );
    FORMAT_PLANS[units] = plan;
    return plan;
}

impl ArgumentFormat.caller -> str {
    return f"{self.name}()" if self.name else "function";
}

impl ArgumentFormat.mismatch(position: int, expected: str, value: ptr[PyObject]) {
    shown = "None" if value == Py_None else type_name(value);
    self.reject(position, f"must be {expected}, not {shown}");
}

impl ArgumentFormat.reject(position: int, detail: str) {
    if self.message {
        object_error(PyExc_TypeError, self.message);
        raise boundary_failure();
    }
    caller = f"{self.name}() " if self.name else "";
    object_error(PyExc_TypeError, f"{caller}argument {position} {detail}");
    raise boundary_failure();
}

impl ArgumentFormat.units_of(format: str) -> list[str] {
    units: list[str] = [];
    for character in format {
        if character == "!" and units and units[-1] == "O" {
            units[-1] = "O!";
        } else {
            units.append(character);
        }
    }
    return units;
}

impl ArgumentFormat.expected_types(kinds: list[str]) -> list[ptr[PyObject]] {
    expected: list[ptr[PyObject]] = [];
    next_type = 0;
    for unit in kinds {
        if unit == "O!" {
            expected.append(self.types[next_type]);
            next_type += 1;
        } else {
            expected.append(NULL);
        }
    }
    return expected;
}

impl ArgumentFormat.failed -> bool {
    return bool(PyErr_Occurred());
}

impl ArgumentFormat.signed_range(value: i64, low: i64, high: i64, kind: str) -> i64 {
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

impl ArgumentFormat.convert(
    unit: str, value: ptr[PyObject], position: int, type: ptr[PyObject] = NULL
) -> ArgumentValue {
    result = ArgumentValue(given=True, object=value);
    if unit == "O" {
        return result;
    }
    if unit == "S" {
        if jacpy_is_bytes(value) == 0 {
            self.mismatch(position, "bytes", value);
        }
        return result;
    }
    if unit == "O!" {
        if PyType_IsSubtype(Py_TYPE(value), type) == 0 {
            expected = required(
                c_string_text(ptr[PyTypeObject](type).view(1)[0].tp_name)
            );
            try {
                self.mismatch(position, text_value(expected), value);
            } finally {
                jacpy_release(expected);
            }
        }
        return result;
    }
    if unit == "C" {
        if jacpy_is_unicode(value) == 0 {
            self.mismatch(position, "a unicode character", value);
        }
        length = jacpy_unicode_size(value);
        if length != 1 {
            self.reject(
                position,
                f"must be a unicode character, not a string of length {length}"
            );
        }
        result.signed = PyUnicode_ReadChar(value, 0);
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
        result.signed = self.signed_range(wide, -32768, 32767, "signed short integer");
    } else {
        result.signed = wide;
    }
    return result;
}

impl ArgumentFormat.unpack(
    args: ptr[PyObject], minimum: int, maximum: int
) -> list[ptr[PyObject]] {
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

impl ArgumentFormat.parse(args: ptr[PyObject], units: str) -> list[ArgumentValue] {
    plan = format_plan(units);
    kinds = plan.kinds;
    expected = self.expected_types(kinds);
    items = self.unpack(args, plan.minimum, len(kinds));
    values: list[ArgumentValue] = [];
    for i in range(len(kinds)) {
        values.append(
            self.convert(kinds[i], items[i], i + 1, expected[i])
                if i < len(items)
                else ABSENT
        );
    }
    return values;
}

impl ArgumentFormat.parse_keywords(
    args: ptr[PyObject], kwargs: ptr[PyObject], units: str, keywords: list[str]
) -> list[ArgumentValue] {
    plan = format_plan(units);
    kinds = plan.kinds;
    expected = self.expected_types(kinds);
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
                else ''}argument{'' if count == 1 else 's'} ({nargs + nkwargs} given)"
        );
        raise boundary_failure();
    }
    values = [ABSENT for _ in range(count)];
    remaining = nkwargs;
    for i in range(count) {
        if i == maximum and maximum < nargs {
            if maximum == 0 {
                object_error(
                    PyExc_TypeError, f"{shown}{called} takes no positional arguments"
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
            (status, found) = dict_get_text(kwargs, keywords[i]);
            if status < 0 {
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
                values[i] = self.convert(kinds[i], current, i + 1, expected[i]);
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

impl ArgumentFormat.extraneous_keyword(
    args: ptr[PyObject], kwargs: ptr[PyObject], keywords: list[str]
) {
    shown = self.name or "function";
    called = "()" if self.name else "";
    for i in range(int(PyTuple_Size(args))) {
        (status, found) = dict_get_text(kwargs, keywords[i]);
        if status < 0 {
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

impl ArgumentFormat.unexpected_keyword(key: ptr[PyObject], keywords: list[str]) {
    shown = self.name or "this function";
    called = "()" if self.name else "";
    candidates = required(PyList_New(i64(len(keywords))));
    suggestion = NULL;
    try {
        for i in range(len(keywords)) {
            if PyList_SetItem(
                candidates, i64(i), required(jacpy_unicode_from_text(keywords[i]))
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
