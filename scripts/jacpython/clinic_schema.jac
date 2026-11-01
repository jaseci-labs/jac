"""The Argument Clinic signatures gen_clinic.jac generates the Jac glue from.

scripts/jacpython/clinic/<name>.jac holds one module's signatures as a Clinic
record: every function and method its clinic input declares, in clinic's
order, with each parameter's converter as Tools/clinic resolves it, the
docstrings, and the parse each call takes. scripts/jacpython/gen_clinic_data.jac
wrote them from the C sources once; they are edited here now.
"""

# One parameter of a clinic function. The first parameter of every function is
# its receiver (converter "self"); a method that needs the class defining it
# takes it next (converter "defining_class").
obj Parameter {
    # kind: inspect's parameter kind (POSITIONAL_ONLY, POSITIONAL_OR_KEYWORD,
    # KEYWORD_ONLY, VAR_POSITIONAL). converter: the clinic converter's name
    # (object, int, Py_buffer, str, a module's own like path_t), and type its
    # C type. format_unit: the getargs unit the converter selects (y*, s#,
    # z...), which keeps accepted types clinic does not otherwise record.
    # default_kind: "" when the parameter is required, "value" when
    # py_default holds its Python default, "NULL" or "unknown" (a default
    # only C can spell) otherwise; c_default is the C expression of the
    # default.
    has name: str,
        kind: str = "POSITIONAL_OR_KEYWORD",
        converter: str = "object",
        type: str = "PyObject *",
        format_unit: str = "",
        default_kind: str = "",
        py_default: any = None,
        c_default: str = "",
        # The optional-group number (in brackets), 0 outside any group.
        group: int = 0,
        # accept={...}: the Python types the converter takes, by name.
        accept: list[str] = [],
        # converter=...: the C function an object or a module's converter
        # calls to convert; subclass_of=...: the type an object must be.
        convert_with: str = "",
        subclass_of: str = "",
        encoding: str = "",
        # The impl takes the converted value by address (Py_buffer, path_t).
        by_reference: bool = False,
        # A module converter's own keyword options, in order: a name of one
        # of the module's C objects, or a string literal its parse spells as
        # a C string.
        options: list[str] = [],
        # The converter's parse hands it the module object first.
        takes_module: bool = False,
        # The converter's cleanup releases the reference it produced.
        releases: bool = False,
        # `[from X.Y]`: the version from which passing the parameter
        # positionally, or by keyword, is an error (a warning before it).
        deprecated_positional: str = "",
        deprecated_keyword: str = "";

    def is_optional -> bool {
        return self.kind != "VAR_POSITIONAL" and self.default_kind != "";
    }
}

# One function or method of a module's clinic input.
obj Function {
    # kind: CALLABLE, STATIC_METHOD, CLASS_METHOD, METHOD_NEW, METHOD_INIT,
    # GETTER or SETTER. cls: the class it belongs to ("" for a module
    # function). docstring: as clinic writes it into PyDoc_STRVAR, text
    # signature first. condition: the C preprocessor condition the function
    # is compiled under ("" when none). returns: the return converter (""
    # for PyObject *).
    has name: str,
        full_name: str,
        c_basename: str,
        kind: str = "CALLABLE",
        cls: str = "",
        docstring: str = "",
        condition: str = "",
        returns: str = "",
        params: list[Parameter] = [],
        # The parse clinic generates: the PyMethodDef flags, the
        # bindings/arguments.jac parser that does what its C does (or why
        # none can), the positional counts and whether it is the limited
        # C API's.
        flags: str = "",
        parser: str = "",
        min_pos: int = 0,
        max_pos: int = 0,
        pos_only: int = 0,
        min_kw_only: int = 0,
        limited_capi: bool = False,
        # The DeprecationWarning texts of the parameters' `[from X.Y]`.
        positional_warning: str = "",
        keyword_warning: str = "",
        # The parse checks that the receiver's type is the class (or a
        # subclass keeping the other of tp_new and tp_init) before refusing
        # arguments.
        self_type_check: bool = False,
        # C defines no `_impl` for it: a clone kept for its docstring, the
        # module binding it by hand.
        bound_by_hand: bool = False;
}

# A module's clinic input and the C docstrings its binding names.
obj Clinic {
    # version and sources: the Python release and the C files the
    # signatures were taken from. classes: each clinic class's C typedef, by
    # name. docs: the module's other PyDoc_STRVAR docstrings and the docs its
    # PyMethodDef, PyMemberDef and PyGetSetDef tables write inline, by C name.
    has module: str,
        version: str,
        sources: list[str],
        classes: dict[str, str] = {},
        functions: list[Function] = [],
        docs: dict[str, str] = {};
}
