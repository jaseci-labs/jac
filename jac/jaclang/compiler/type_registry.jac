enum NumericKind {
    NotNumeric = "not_numeric",
    IntKind = "int_kind",
    FloatKind = "float_kind"
}

obj JacTypeEntry {
    has name: str,
        emitter_suffix: str,
        numeric_kind: NumericKind = NumericKind.NotNumeric,
        width: int = 0,
        signed: bool = False,
        is_float: bool = False,
        sized: bool = False;

    def size_bytes -> int;
    def align -> int;
    def is_int_kind -> bool;
    def is_float_kind -> bool;
}

def _numeric_entry(shape: ScalarShape, emitter_suffix: str) -> JacTypeEntry;

def _registry_entries -> dict[str, JacTypeEntry];

obj JacTypeRegistry {
    has _entries: dict[str, JacTypeEntry],
        _builtin_names: frozenset[str],
        _non_retaining_builtins: frozenset[str],
        _exception_parents: dict[str, str | None],
        _shapes: dict[str, ScalarShape];

    def is_non_retaining_builtin(name: str) -> bool;
    def shape_of(name: str) -> ScalarShape | None;
    def get(name: str) -> JacTypeEntry | None;
    def primitive_names -> set[str];
    def is_primitive(name: str) -> bool;
    def emitter_items -> list[tuple[str, str]];
    def scalar_entries -> list[JacTypeEntry];
    def builtin_names -> set[str];
    def is_builtin(name: str) -> bool;
    def numeric_kind_of(name: str) -> NumericKind;
    def is_numeric(name: str) -> bool;
    def is_sized(name: str) -> bool;
    def sized_int_names -> list[str];
    def sized_float_names -> list[str];
    def sized_scalar_names -> list[str];
    def range_of(name: str) -> tuple[int, int];
    def literal_fits(name: str, value: int | float) -> bool;
    def widens_to(src: str, dst: str) -> bool;
    def unify(a: str, b: str) -> str | None;
    def is_exception(name: str) -> bool;
    def exception_entries -> list[tuple[str, str | None]];
    def exception_type_id(name: str) -> int;
    def exception_descendants(type_name: str) -> list[str];
}

def _non_retaining_builtin_set -> frozenset[str];

def _builtin_name_set -> frozenset[str];

def _shape_table -> dict[str, ScalarShape];

glob JAC_TYPE_REGISTRY = JacTypeRegistry(
         _entries=_registry_entries(),
         _shapes=_shape_table(),
         _builtin_names=_builtin_name_set(),
         _non_retaining_builtins=_non_retaining_builtin_set(),
         _exception_parents={
             "BaseException": None,
             "Exception": "BaseException",
             "ArithmeticError": "Exception",
             "ZeroDivisionError": "ArithmeticError",
             "OverflowError": "ArithmeticError",
             "FloatingPointError": "ArithmeticError",
             "LookupError": "Exception",
             "IndexError": "LookupError",
             "KeyError": "LookupError",
             "ValueError": "Exception",
             "TypeError": "Exception",
             "AttributeError": "Exception",
             "RuntimeError": "Exception",
             "NotImplementedError": "RuntimeError",
             "RecursionError": "RuntimeError",
             "OSError": "Exception",
             "FileNotFoundError": "OSError",
             "FileExistsError": "OSError",
             "PermissionError": "OSError",
             "TimeoutError": "OSError",
             "IsADirectoryError": "OSError",
             "NotADirectoryError": "OSError",
             "AssertionError": "Exception",
             "ImportError": "Exception",
             "ModuleNotFoundError": "ImportError",
             "NameError": "Exception",
             "UnboundLocalError": "NameError",
             "StopIteration": "Exception",
             "StopAsyncIteration": "Exception",
             "EOFError": "Exception",
             "MemoryError": "Exception",
             "ReferenceError": "Exception",
             "KeyboardInterrupt": "BaseException",
             "SystemExit": "BaseException",
             "GeneratorExit": "BaseException",
             "UnicodeError": "ValueError",
             "UnicodeDecodeError": "UnicodeError",
             "UnicodeEncodeError": "UnicodeError",
             "UnicodeTranslateError": "UnicodeError"
         }
     );
