def:priv _suggestions__generate_suggestions_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _suggestions__generate_suggestions_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

glob module_methods: list[MethodDefinition] = [
         MethodDefinition(
             "_generate_suggestions",
             MethodCallbacks(fast=_suggestions__generate_suggestions_call),
             "_generate_suggestions($module, candidates, item, /)\n--\n\nReturns the candidate in candidates that's closest to item",
             128
         ),

     ];

impl _suggestions__generate_suggestions_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        candidates: ptr[PyObject] = value;
        value = clinic_args[1];
        item: ptr[PyObject] = convert_unicode(
            value, "_generate_suggestions", "argument 2"
        );
        return _suggestions__generate_suggestions_impl(receiver, candidates, item);
    } except boundary_failure {
        return NULL;
    }
}

impl _suggestions__generate_suggestions_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 2)
        and not check_positional("_generate_suggestions", int(nargs), 2, 2) {
        return NULL;
    }
    return _suggestions__generate_suggestions_bound(receiver, args, nargs);
}
