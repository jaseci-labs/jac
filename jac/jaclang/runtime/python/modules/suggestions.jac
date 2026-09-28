"""Name suggestions for error messages; derived from CPython 3.14.6 Modules/_suggestions.c.

The Levenshtein search itself is Python/suggestions.c, which tracebacks share.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Occurred,
    PyList_GetItem,
    PyList_Size,
    PyObject,
    Py_NewRef,
    _Py_CalculateSuggestions,
    jacpy_is_exact_list,
    jacpy_is_unicode
}
import from jaclang.runtime.python.bindings.converters { borrowed_none }
import from jaclang.runtime.python.capi { object_error }

def _suggestions__generate_suggestions_impl(
    module: ptr[PyObject], candidates: ptr[PyObject], item: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_exact_list(candidates) == 0 {
        object_error("TypeError", "candidates must be a list");
        return NULL;
    }
    for index in range(PyList_Size(candidates)) {
        if jacpy_is_unicode(PyList_GetItem(candidates, index)) == 0 {
            object_error("TypeError", "all elements in 'candidates' must be strings");
            return NULL;
        }
    }
    result = _Py_CalculateSuggestions(candidates, item);
    if not result and not PyErr_Occurred() {
        return Py_NewRef(borrowed_none());
    }
    return result;
}
