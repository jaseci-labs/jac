import os;
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    AtomTrailer,
    FuncCall,
    FuncSignature,
    HasVar,
    KWPair,
    Module,
    Name,
    UniNode,
    UniScopeNode,
    resolved_decl_of
}
import from jaclang.compiler.frontend.constant { ParamKind, Tokens as Tok }
import from jaclang.compiler.types.types {
    ClassType,
    FunctionType,
    OverloadedType,
    TypeBase
}
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import type from jaclang.compiler.driver.program { JacProgram }

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

impl is_pub(nd: UniNode) -> bool {
    if not isinstance(nd, (Ability, Archetype)) {
        return False;
    }
    access = nd.access;
    return access is not None and access.tag.name == Tok.KW_PUB;
}

def _param_names(decl: Ability) -> tuple[list[str], bool] {
    names: list[str] = [];
    variadic = False;
    sig = decl.signature;
    if not isinstance(sig, FuncSignature) {
        return (names, True);
    }
    for p in sig.get_parameters() {
        if p.unpack is not None {
            variadic = True;
            continue;
        }
        if p.name.value in ("self", "cls") {
            continue;
        }
        names.append(p.name.value);
    }
    return (names, variadic);
}

def _field_names(arch: Archetype) -> set[str] {
    out: set[str] = set();
    for stmt in (ModuleFacts.unwrap_body(arch) or []) {
        for field in stmt.get_all_sub_nodes(HasVar) {
            out.add(field.name.value);
        }
    }
    return out;
}

def _member_names(arch: Archetype) -> set[str] {
    out: set[str] = set();
    body = ModuleFacts.unwrap_body(arch);
    if body is None {
        return out;
    }
    for stmt in body {
        if isinstance(stmt, Ability) and stmt.name_ref is not None {
            out.add(stmt.name_ref.sym_name);
        }
        for field in stmt.get_all_sub_nodes(HasVar) {
            out.add(field.name.value);
        }
    }
    return out;
}

impl native_surface(native_mod: Module, stub_module: str) -> dict[str, NativeBinding] {
    out: dict[str, NativeBinding] = {};
    path = native_mod.loc.mod_path;
    for stmt in ModuleFacts.iter_context_stmts(native_mod) {
        if not is_pub(stmt) {
            continue;
        }
        if isinstance(stmt, Ability) and stmt.name_ref is not None {
            (names, variadic) = _param_names(stmt);
            out[stmt.name_ref.sym_name] = NativeBinding(
                stub_module=stub_module,
                name=stmt.name_ref.sym_name,
                native_path=path,
                decl=stmt,
                params=names,
                variadic=variadic
            );
        } elif isinstance(stmt, Archetype) and stmt.name is not None {
            out[stmt.name.value] = NativeBinding(
                stub_module=stub_module,
                name=stmt.name.value,
                native_path=path,
                decl=stmt,
                members=_member_names(stmt),
                fields=_field_names(stmt)
            );
        }
    }
    return out;
}

impl signature_of(overloads: list[FunctionType]) -> InterfaceSig {
    """The names an interface function can be called with, over every
    overload. A leading run of parameters taken by position only is counted
    and not named: the native declaration may call those anything.""";
    sig = InterfaceSig();
    for fn in overloads {
        leading = 0;
        named = False;
        for p in fn.parameters {
            if p.is_self or p.is_cls or p.name in ("self", "cls") {
                continue;
            }
            if p.param_kind == ParamKind.VARARG or p.param_kind == ParamKind.KWARG {
                sig.variadic = True;
                continue;
            }
            if p.name not in sig.params {
                sig.params.append(p.name);
            }
            if not named
                and (p.param_kind == ParamKind.POSONLY or p.name.startswith("__")) {
                leading += 1;
            } else {
                named = True;
            }
        }
        sig.positional = max(sig.positional, leading);
    }
    return sig;
}

impl callable_sig(ty: (TypeBase | None)) -> (InterfaceSig | None) {
    if isinstance(ty, FunctionType) {
        return signature_of([ty]);
    }
    if isinstance(ty, OverloadedType) {
        return signature_of(list(ty.overloads));
    }
    return None;
}

impl merge_sigs(
    into: (InterfaceSig | None), more: (InterfaceSig | None)
) -> (InterfaceSig | None) {
    if into is None or more is None {
        return into or more;
    }
    for pname in more.params {
        if pname not in into.params {
            into.params.append(pname);
        }
    }
    into.variadic = into.variadic or more.variadic;
    into.positional = max(into.positional, more.positional);
    return into;
}

impl scope_sig(
    scope: UniScopeNode, name: str, prog: JacProgram
) -> (InterfaceSig | None) {
    """How `name` is called in `scope`, over every declaration of it there:
    a scope holds each overload of a function as its own symbol.""";
    found: (InterfaceSig | None) = None;
    for sym in scope.lookup_all(name, deep=False) {
        found = merge_sigs(
            found, callable_sig(prog.get_type_evaluator().get_type_of_symbol(sym))
        );
    }
    return found;
}

impl interface_type(
    stub_mod: Module, name: str, prog: JacProgram
) -> (TypeBase | None) {
    """The type the Python interface gives `name`. An interface is read from
    its symbols and their types, never from syntax: in a build the stubs are
    served from the catalog, which holds no trees.""";
    sym = stub_mod.lookup(name, deep=False);
    if sym is None {
        return None;
    }
    return prog.get_type_evaluator().get_type_of_symbol(sym);
}

impl class_member_type(
    cls: ClassType, member: str, prog: JacProgram
) -> (TypeBase | None) {
    chain: list[ClassType] = list(cls.shared.mro) or [cls];
    for klass in chain {
        scope = klass.shared.symbol_table;
        sym = scope.lookup(member, deep=False) if scope is not None else None;
        if sym is not None {
            return prog.get_type_evaluator().get_type_of_symbol(sym);
        }
    }
    return None;
}

impl constructor_sig(cls: ClassType, prog: JacProgram) -> (InterfaceSig | None) {
    """How the interface constructs `cls`: the `__new__` and `__init__` of the
    nearest class in its chain that declares either. Reaching `object` means
    the interface says nothing, and nothing is held against the native side.""";
    chain: list[ClassType] = list(cls.shared.mro) or [cls];
    for klass in chain {
        if klass.is_builtin("object") {
            return None;
        }
        scope = klass.shared.symbol_table;
        if scope is None {
            continue;
        }
        made: (InterfaceSig | None) = None;
        for maker in ("__new__", "init", "__init__") {
            made = merge_sigs(made, scope_sig(scope, maker, prog));
        }
        if made is not None {
            return made;
        }
    }
    return None;
}

impl parameter_mismatches(
    name: str, params: list[str], want: InterfaceSig
) -> list[str] {
    out: list[str] = [];
    if want.variadic {
        return out;
    }
    for (index, pname) in enumerate(params) {
        if index < want.positional or pname in want.params {
            continue;
        }
        out.append(
            f"parameter {index + 1} of '{name}' is named '{pname}', which the "
            f"Python interface does not declare"
        );
    }
    return out;
}

impl conformance_mismatches(
    stub_mod: Module, native_mod: Module, prog: JacProgram
) -> list[tuple[UniNode, str]] {
    out: list[tuple[UniNode, str]] = [];
    for (name, binding) in native_surface(native_mod, stub_mod.name).items() {
        decl = binding.decl;
        if decl is None {
            continue;
        }
        want = interface_type(stub_mod, name, prog);
        if want is None {
            out.append(
                (
                    decl,
                    f"'{name}' is public here but the Python interface of "
                    f"'{stub_mod.name}' declares no such name"
                )
            );
            continue;
        }
        called = scope_sig(stub_mod, name, prog);
        if isinstance(decl, Ability) {
            against = called;
            if against is None and isinstance(want, ClassType) {
                against = constructor_sig(want, prog);
            }
            if against is None {
                continue;
            }
            for why in parameter_mismatches(name, binding.params, against) {
                out.append((decl, why));
            }
        } elif called is not None {
            out.append(
                (
                    decl,
                    f"'{name}' is a class here but a function in the Python "
                    f"interface of '{stub_mod.name}'"
                )
            );
        } elif isinstance(want, ClassType) {
            made = constructor_sig(want, prog);
            for member in sorted(binding.members) {
                if member.startswith("_")
                    or member in LIFECYCLE_MEMBERS
                    or class_member_type(want, member, prog) is not None {
                    continue;
                }
                if member in binding.fields
                    and made is not None
                    and (made.variadic or member in made.params) {
                    continue;
                }
                out.append(
                    (
                        decl,
                        f"'{name}.{member}' is not a member of the Python "
                        f"interface; make it private or add it to the interface"
                    )
                );
            }
        }
    }
    return out;
}

impl NativeBindings.surface(
    prog: JacProgram, stub_module: str, base_dir: str
) -> (dict[str, NativeBinding] | None) {
    import from jaclang.compiler.frontend.codeinfo {
        is_bundled_native_module,
        resolve_native_module
    }
    if stub_module in self.modules {
        return self.modules[stub_module];
    }
    found: (dict[str, NativeBinding] | None) = None;
    if is_bundled_native_module(stub_module) {
        (_src, full_path) = resolve_native_module(
            stub_module, base_dir, allow_inferred=False
        );
        if full_path is not None and os.path.isfile(full_path) {
            native_mod = prog.load_dependency_module(full_path, need_tree=True);
            found = native_surface(native_mod, stub_module);
        }
    }
    self.modules[stub_module] = found;
    return found;
}

impl NativeBindings.lookup(
    prog: JacProgram, stub_module: str, name: str, base_dir: str
) -> (NativeBinding | None) {
    table = self.surface(prog, stub_module, base_dir);
    return table.get(name) if table is not None else None;
}

impl native_bindings_of(prog: JacProgram) -> NativeBindings {
    found = prog.analysis.native_bindings;
    if found is None {
        found = NativeBindings();
        prog.analysis.native_bindings = found;
    }
    return found;
}

impl call_gaps(call: FuncCall, binding: NativeBinding) -> list[str] {
    out: list[str] = [];
    if binding.variadic {
        return out;
    }
    positional = 0;
    for arg in (call.params or []) {
        if isinstance(arg, KWPair) {
            key = arg.key;
            if isinstance(key, Name) and key.value not in binding.params {
                out.append(
                    f"the native '{binding.stub_module}.{binding.name}' takes no "
                    f"'{key.value}' argument"
                );
            }
        } else {
            positional += 1;
        }
    }
    if positional > len(binding.params) {
        out.append(
            f"the native '{binding.stub_module}.{binding.name}' takes "
            f"{len(binding.params)} positional argument(s), not {positional}"
        );
    }
    return out;
}

impl interface_module_name(home: Module) -> str {
    """The dotted name a stub module is imported by, read off its path under
    the typeshed standard library when it has one.""";
    path = home.loc.mod_path.replace(os.sep, "/") if home.loc is not None else "";
    marker = "/typeshed/stdlib/";
    at = path.rfind(marker);
    if at < 0 {
        return home.name;
    }
    rel = path[at + len(marker):];
    if rel.endswith(".pyi") {
        rel = rel[:-len(".pyi")];
    }
    if rel.endswith("/__init__") {
        rel = rel[:-len("/__init__")];
    }
    return rel.replace("/", ".");
}

impl binding_gaps(prog: JacProgram, nm: Name, base_dir: str) -> list[str] {
    """What the native library lacks for a name the checker typed from a
    Python interface: its module-level function or class, a member of its
    class, or an argument the call passes. A name that did not resolve into
    an interface, or whose interface has no native module, has no gap.""";
    sym = nm.sym;
    if sym is None {
        return [];
    }
    target = resolved_decl_of(sym);
    declared = target.sym if target is not None and target.sym is not None else sym;
    if not declared.in_stub_scope() {
        return [];
    }
    owner: (UniScopeNode | None) = None;
    home: (UniScopeNode | None) = declared.parent_tab;
    while home is not None and not isinstance(home, Module) {
        if owner is None {
            owner = home;
        }
        home = home.parent_scope;
    }
    if not isinstance(home, Module) {
        return [];
    }
    if owner is not None and owner.scope_name in NATIVE_FILE_CLASSES {
        if nm.value in NATIVE_FILE_MEMBERS {
            return [];
        }
        return [f"the native file object has no member '{nm.value}'"];
    }
    lib = interface_module_name(home);
    table = native_bindings_of(prog).surface(prog, lib, base_dir);
    if table is None {
        return [];
    }
    if owner is not None {
        bound = table.get(owner.scope_name);
        if bound is None {
            return [f"'{lib}.{owner.scope_name}' has no native implementation"];
        }
        if nm.value not in bound.members {
            return [
                f"the native '{lib}.{owner.scope_name}' has no member '{nm.value}'"
            ];
        }
        return [];
    }
    bound = table.get(declared.sym_name);
    if bound is None {
        want = prog.get_type_evaluator().get_type_of_symbol(declared);
        if callable_sig(want) is not None
            or (isinstance(want, ClassType) and want.is_instantiable_class()) {
            return [f"'{lib}.{declared.sym_name}' has no native implementation"];
        }
        return [];
    }
    call = nm.parent;
    if isinstance(call, AtomTrailer) {
        call = call.parent;
    }
    if isinstance(call, FuncCall) and isinstance(bound.decl, Ability) {
        return call_gaps(call, bound);
    }
    return [];
}

impl native_library_module_name(path: str) -> (str | None) {
    posix = os.path.realpath(path).replace(os.sep, "/");
    at = posix.rfind(NATIVE_LIBRARY_REL);
    if at < 0 or not posix.endswith(".jac") {
        return None;
    }
    rel = posix[at + len(NATIVE_LIBRARY_REL):-len(".jac")];
    parts = rel.split("/");
    (stem, _dot, suffix) = parts[-1].partition(".");
    if suffix and suffix not in PLATFORM_SUFFIXES {
        return None;
    }
    parts[-1] = stem;
    for part in parts {
        if part.startswith("_") {
            return None;
        }
    }
    return ".".join(parts);
}

impl typeshed_stub_path(name: str) -> (str | None) {
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    stubs_dir = os.path.join(jaclang_pkg_root(), "vendor", "typeshed", "stdlib");
    rel = name.replace(".", os.sep);
    for candidate in (
        os.path.join(stubs_dir, rel + ".pyi"),
        os.path.join(stubs_dir, rel, "__init__.pyi")
    ) {
        if os.path.isfile(candidate) {
            return candidate;
        }
    }
    return None;
}

impl variant_base(path: str) -> (str | None) {
    if not path.endswith(".jac") {
        return None;
    }
    stem = path[:-len(".jac")];
    (head, dot, suffix) = stem.rpartition(".");
    if dot and suffix in PLATFORM_SUFFIXES and os.sep not in suffix {
        return head;
    }
    return None;
}

impl variant_siblings(path: str) -> list[str] {
    base = variant_base(path);
    if base is None {
        return [];
    }
    out: list[str] = [];
    for suffix in PLATFORM_SUFFIXES {
        candidate = f"{base}.{suffix}.jac";
        if candidate != path and os.path.isfile(candidate) {
            out.append(candidate);
        }
    }
    if os.path.isfile(base + ".jac") {
        out.append(base + ".jac");
    }
    return out;
}

impl variant_mismatches(mod: Module, prog: JacProgram) -> list[tuple[UniNode, str]] {
    out: list[tuple[UniNode, str]] = [];
    path = os.path.realpath(mod.loc.mod_path) if mod.loc is not None else "";
    siblings = variant_siblings(path) if path else [];
    if not siblings {
        return out;
    }
    mine = native_surface(mod, "");
    for sibling in siblings {
        other_mod = prog.load_dependency_module(sibling, need_tree=True);
        other = native_surface(other_mod, "");
        shown = os.path.basename(sibling);
        for (name, binding) in mine.items() {
            decl = binding.decl;
            if decl is None {
                continue;
            }
            theirs = other.get(name);
            if theirs is None {
                out.append(
                    (
                        decl,
                        f"'{name}' is public in this platform variant but not in "
                        f"{shown}; every variant of a module exposes the same names"
                    )
                );
            } elif binding.params != theirs.params
                or binding.variadic != theirs.variadic {
                out.append(
                    (
                        decl,
                        f"'{name}' takes ({', '.join(binding.params)}) here but "
                        f"({', '.join(theirs.params)}) in {shown}"
                    )
                );
            } elif binding.members != theirs.members {
                extra = sorted(binding.members - theirs.members);
                if extra {
                    out.append(
                        (decl, f"'{name}' has members {extra} here that {shown} lacks")
                    );
                }
            }
        }
    }
    return out;
}
