import os;
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    AtomTrailer,
    ElseStmt,
    Enum,
    FuncCall,
    FuncSignature,
    HasVar,
    IfStmt,
    Import,
    KWPair,
    Module,
    ModuleItem,
    ModulePath,
    Name,
    UniNode
}
import from jaclang.compiler.frontend.constant { Tokens as Tok }
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
     CLOSED_BASES: tuple[str, ...] = (
         "object",
         "Generic",
         "Protocol",
         "NamedTuple",
         "BaseException",
         "Exception",
         "OSError",
         "ValueError",
         "TypeError",
         "KeyError",
         "LookupError",
         "RuntimeError",
         "ArithmeticError"
     ),
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

obj StubDecl {
    has name: str,
        kind: str,
        params: list[str] = [],
        variadic: bool = False,
        positional: int = 0,
        members: set[str] = set(),
        extensible: bool = False,
        bases: list[str] = [],
        maker: (StubDecl | None) = None;
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
def stub_home(decl: UniNode) -> (Module | None);
def native_surface(native_mod: Module, stub_module: str) -> dict[str, NativeBinding];
def stub_signature(decl: Ability) -> StubDecl;
def merge_signatures(prev: (StubDecl | None), cur: StubDecl) -> StubDecl;
def stub_surface(
    stub_mod: Module,
    prog: (JacProgram | None) = None,
    visiting: (set[str] | None) = None
) -> dict[str, StubDecl];

def parameter_mismatches(name: str, params: list[str], want: StubDecl) -> list[str];
def conformance_mismatches(
    stub_mod: Module, native_mod: Module, prog: (JacProgram | None) = None
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

impl stub_home(decl: UniNode) -> (Module | None) {
    home = decl if isinstance(decl, Module) else decl.find_parent_of_type(Module);
    if home is None or home.loc is None {
        return None;
    }
    if home.stub_only or home.is_raised_from_py or home.loc.mod_path.endswith(".pyi") {
        return home;
    }
    return None;
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

impl stub_signature(decl: Ability) -> StubDecl {
    name = decl.name_ref.sym_name if decl.name_ref is not None else "";
    out = StubDecl(name=name, kind="function");
    sig = decl.signature;
    if not isinstance(sig, FuncSignature) {
        out.variadic = True;
        return out;
    }
    out.variadic = sig.varargs is not None or sig.kwargs is not None;
    for p in sig.posonly_params {
        if p.name.value not in ("self", "cls") {
            out.params.append(p.name.value);
            out.positional += 1;
        }
    }
    for p in (sig.params or []) {
        pname = p.name.value;
        if pname in ("self", "cls") {
            continue;
        }
        out.params.append(pname);
        if pname.startswith("__") and out.positional == len(out.params) - 1 {
            out.positional += 1;
        }
    }
    for p in sig.kwonlyargs {
        out.params.append(p.name.value);
    }
    return out;
}

impl merge_signatures(prev: (StubDecl | None), cur: StubDecl) -> StubDecl {
    if prev is None or prev.kind != "function" {
        return cur;
    }
    for pname in cur.params {
        if pname not in prev.params {
            prev.params.append(pname);
        }
    }
    prev.variadic = prev.variadic or cur.variadic;
    prev.positional = max(prev.positional, cur.positional);
    return prev;
}

def _base_name(base: UniNode) -> str {
    target: UniNode = base;
    while isinstance(target, AtomTrailer) {
        target = target.right if target.is_attr else target.target;
    }
    return target.value if isinstance(target, Name) else "";
}

def _declare_class(out: dict[str, StubDecl], arch: Archetype) -> None {
    if arch.name is None {
        return;
    }
    found = out.get(arch.name.value);
    if found is None or found.kind != "class" {
        found = StubDecl(name=arch.name.value, kind="class");
        out[arch.name.value] = found;
    }
    found.members |= _member_names(arch);
    for base in arch.base_classes {
        found.bases.append(_base_name(base));
    }
    body = ModuleFacts.unwrap_body(arch);
    for stmt in (body or []) {
        if isinstance(stmt, Ability)
            and stmt.name_ref is not None
            and stmt.name_ref.sym_name in ("init", "__init__", "__new__") {
            found.maker = merge_signatures(found.maker, stub_signature(stmt));
        }
    }
}

def _reexported(
    stmt: Import, prog: JacProgram, visiting: set[str]
) -> list[tuple[str, StubDecl]] {
    out: list[tuple[str, StubDecl]] = [];
    source = stmt.items[0] if stmt.is_absorb and stmt.items else stmt.from_loc;
    if not isinstance(source, ModulePath) {
        return out;
    }
    path = source.resolve_relative_path();
    if not path.endswith(".pyi") or not os.path.isfile(path) or path in visiting {
        return out;
    }
    other = stub_surface(
        prog.load_dependency_module(path, need_tree=True), prog, visiting
    );
    if stmt.is_absorb {
        for (name, decl) in other.items() {
            if not name.startswith("_") {
                out.append((name, decl));
            }
        }
        return out;
    }
    for item in stmt.items {
        if isinstance(item, ModuleItem) and item.name.value in other {
            shown = item.alias.value if item.alias is not None else item.name.value;
            out.append((shown, other[item.name.value]));
        }
    }
    return out;
}

def _inherit(out: dict[str, StubDecl], name: str, chain: set[str]) {
    decl = out[name];
    for base in decl.bases {
        if base in CLOSED_BASES or base == name {
            continue;
        }
        parent = out.get(base);
        if parent is None or parent.kind != "class" or base in chain {
            decl.extensible = True;
            continue;
        }
        _inherit(out, base, chain | {name});
        decl.members |= parent.members;
        decl.extensible = decl.extensible or parent.extensible;
        if decl.maker is None {
            decl.maker = parent.maker;
        }
    }
    decl.bases = [];
}

impl stub_surface(
    stub_mod: Module,
    prog: (JacProgram | None) = None,
    visiting: (set[str] | None) = None
) -> dict[str, StubDecl] {
    out: dict[str, StubDecl] = {};
    active: set[str] = visiting if visiting is not None else set();
    if stub_mod.loc is not None {
        active.add(stub_mod.loc.mod_path);
    }
    pending: list[UniNode] = list(stub_mod.body);
    while pending {
        stmt = pending.pop(0);
        if isinstance(stmt, IfStmt) {
            branch: (IfStmt | ElseStmt | None) = stmt;
            while isinstance(branch, IfStmt) {
                pending.extend(branch.body);
                branch = branch.else_body;
            }
            if isinstance(branch, ElseStmt) {
                pending.extend(branch.body);
            }
        } elif isinstance(stmt, Ability) and stmt.name_ref is not None {
            name = stmt.name_ref.sym_name;
            out[name] = merge_signatures(out.get(name), stub_signature(stmt));
        } elif isinstance(stmt, Archetype) {
            _declare_class(out, stmt);
        } elif isinstance(stmt, Enum) and stmt.name is not None {
            out[stmt.name.value] = StubDecl(
                name=stmt.name.value, kind="class", extensible=True
            );
        } elif isinstance(stmt, Import) and prog is not None {
            for (name, decl) in _reexported(stmt, prog, active) {
                out.setdefault(name, decl);
            }
        }
    }
    for name in list(out.keys()) {
        if out[name].kind == "class" {
            _inherit(out, name, set());
        }
    }
    return out;
}

impl parameter_mismatches(name: str, params: list[str], want: StubDecl) -> list[str] {
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
    stub_mod: Module, native_mod: Module, prog: (JacProgram | None) = None
) -> list[tuple[UniNode, str]] {
    out: list[tuple[UniNode, str]] = [];
    declared = stub_surface(stub_mod, prog);
    for (name, binding) in native_surface(native_mod, stub_mod.name).items() {
        decl = binding.decl;
        if decl is None {
            continue;
        }
        want = declared.get(name);
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
        if isinstance(decl, Ability) {
            against = want if want.kind == "function" else want.maker;
            if against is None {
                continue;
            }
            for why in parameter_mismatches(name, binding.params, against) {
                out.append((decl, why));
            }
        } elif want.kind == "function" {
            out.append(
                (
                    decl,
                    f"'{name}' is a class here but a function in the Python "
                    f"interface of '{stub_mod.name}'"
                )
            );
        } elif not want.extensible {
            made = want.maker;
            for member in sorted(binding.members) {
                if member.startswith("_")
                    or member in LIFECYCLE_MEMBERS
                    or member in want.members {
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

impl binding_gaps(prog: JacProgram, nm: Name, base_dir: str) -> list[str] {
    sym = nm.sym;
    if sym is None or sym.decl is None {
        return [];
    }
    declared = sym.decl.name_of;
    home = stub_home(declared);
    if home is None {
        return [];
    }
    bindings = native_bindings_of(prog);
    owner = declared.find_parent_of_type(Archetype)
        if isinstance(declared, (Ability, HasVar))
        else None;
    if owner is not None
        and owner.name is not None
        and owner.name.value in NATIVE_FILE_CLASSES {
        if nm.value in NATIVE_FILE_MEMBERS {
            return [];
        }
        return [f"the native file object has no member '{nm.value}'"];
    }
    if owner is not None and owner.name is not None {
        bound = bindings.lookup(prog, home.name, owner.name.value, base_dir);
        if bound is None {
            if bindings.surface(prog, home.name, base_dir) is None {
                return [];
            }
            return [f"'{home.name}.{owner.name.value}' has no native implementation"];
        }
        if nm.value not in bound.members {
            return [
                f"the native '{home.name}.{owner.name.value}' has no member "
                f"'{nm.value}'"
            ];
        }
        return [];
    }
    if not isinstance(declared, (Ability, Archetype)) {
        return [];
    }
    table = bindings.surface(prog, home.name, base_dir);
    if table is None {
        return [];
    }
    bound = table.get(nm.value);
    if bound is None {
        return [f"'{home.name}.{nm.value}' has no native implementation"];
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
