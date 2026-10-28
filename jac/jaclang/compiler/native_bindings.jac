import os;

glob NATIVE_FILE_CLASSES: dict[str, str] = {
         "TextIOWrapper": "File",
         "TextIOBase": "File",
         "TextIO": "File",
         "IO": "File",
         "IOBase": "File",
         "BufferedReader": "BinaryFile",
         "BufferedWriter": "BinaryFile",
         "BufferedRandom": "BinaryFile",
         "BufferedIOBase": "BinaryFile",
         "RawIOBase": "BinaryFile",
         "FileIO": "BinaryFile",
         "BinaryIO": "BinaryFile"
     },
     NATIVE_FILE_MEMBERS: set[str] = {
         "read",
         "readline",
         "write",
         "close",
         "flush",
         "__enter__",
         "__exit__"
     },
     NATIVE_LIBRARY_REL: str = "/runtime/na_stdlib/",
     LIFECYCLE_MEMBERS: tuple[str, ...] = ("init", "postinit", "drop"),
     PLATFORM_SUFFIXES: tuple[str, ...] = (
         "linux",
         "darwin",
         "windows",
         "aarch64",
         "x86_64",
         "wasm32"
     );

obj NativeBinding {
    has stub_module: str,
        name: str,
        native_path: str,
        decl: (UniNode | None) = None,
        params: list[str] = [],
        variadic: bool = False,
        members: set[str] = set(),
        fields: set[str] = set(),
        mismatches: list[str] = [];
}

obj InterfaceSig {
    has params: list[str] = [],
        positional: int = 0,
        variadic: bool = False;
}

obj NativeBindings {
    has modules: dict[str, (dict[str, NativeBinding] | None)] = {};

    def surface(
        prog: JacProgram, stub_module: str, base_dir: str
    ) -> (dict[str, NativeBinding] | None);

    def lookup(
        prog: JacProgram, stub_module: str, name: str, base_dir: str
    ) -> (NativeBinding | None);
}

def is_pub(nd: UniNode) -> bool;
def interface_module_name(home: Module) -> str;
def native_surface(native_mod: Module, stub_module: str) -> dict[str, NativeBinding];
def signature_of(overloads: list[FunctionType]) -> InterfaceSig;
def callable_sig(ty: (TypeBase | None)) -> (InterfaceSig | None);
def merge_sigs(
    into: (InterfaceSig | None), more: (InterfaceSig | None)
) -> (InterfaceSig | None);

def declared_symbols(scope: UniScopeNode, name: str) -> list[Symbol];
def overload_symbols(sym: Symbol) -> list[Symbol];
def scope_sig(
    scope: UniScopeNode, name: str, prog: JacProgram
) -> (InterfaceSig | None);

def interface_type(stub_mod: Module, name: str, prog: JacProgram) -> (TypeBase | None);
def class_member_type(
    cls: ClassType, member: str, prog: JacProgram
) -> (TypeBase | None);

def constructor_sig(cls: ClassType, prog: JacProgram) -> (InterfaceSig | None);
def parameter_mismatches(
    name: str, params: list[str], want: InterfaceSig
) -> list[str];

def conformance_mismatches(
    stub_mod: Module, native_mod: Module, prog: JacProgram
) -> list[tuple[UniNode, str]];

def call_gaps(call: FuncCall, binding: NativeBinding) -> list[str];
def native_bindings_of(prog: JacProgram) -> NativeBindings;
def native_library_module_name(path: str) -> (str | None);
def typeshed_stub_path(name: str) -> (str | None);
def variant_base(path: str) -> (str | None);
def variant_siblings(path: str) -> list[str];
def variant_mismatches(mod: Module, prog: JacProgram) -> list[tuple[UniNode, str]];
def binding_gaps(prog: JacProgram, nm: Name, base_dir: str) -> list[str];
def import_gaps(prog: JacProgram, imp: Import, base_dir: str) -> list[str];

def _param_names(decl: Ability) -> tuple[list[str], bool];

def _constructor_params(arch: Archetype) -> tuple[list[str], bool];

def _field_names(arch: Archetype) -> set[str];

def _member_names(arch: Archetype) -> set[str];

def is_owning_scope(scope: UniScopeNode) -> bool;

def is_public_glob(stmt: GlobalVars) -> bool;
