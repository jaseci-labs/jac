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
    UniNode
}
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import type from jaclang.compiler.driver.program { JacProgram }

obj NativeBinding {
    has stub_module: str,
        name: str,
        native_path: str,
        decl: (UniNode | None) = None,
        params: list[str] = [],
        variadic: bool = False,
        members: set[str] = set(),
        mismatches: list[str] = [];
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
def stub_surface(stub_mod: Module) -> dict[str, UniNode];
def conformance_mismatches(
    stub_mod: Module, native_mod: Module
) -> list[tuple[UniNode, str]];

def call_gaps(call: FuncCall, binding: NativeBinding) -> list[str];
def native_bindings_of(prog: JacProgram) -> NativeBindings;
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
                members=_member_names(stmt)
            );
        }
    }
    return out;
}

impl stub_surface(stub_mod: Module) -> dict[str, UniNode] {
    out: dict[str, UniNode] = {};
    for stmt in stub_mod.body {
        if isinstance(stmt, Ability) and stmt.name_ref is not None {
            out[stmt.name_ref.sym_name] = stmt;
        } elif isinstance(stmt, Archetype) and stmt.name is not None {
            out[stmt.name.value] = stmt;
        }
    }
    return out;
}

impl conformance_mismatches(
    stub_mod: Module, native_mod: Module
) -> list[tuple[UniNode, str]] {
    out: list[tuple[UniNode, str]] = [];
    declared = stub_surface(stub_mod);
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
        if isinstance(decl, Ability) != isinstance(want, Ability) {
            out.append(
                (
                    decl,
                    f"'{name}' is not the same kind of declaration as in the "
                    f"Python interface of '{stub_mod.name}'"
                )
            );
            continue;
        }
        if isinstance(decl, Ability) and isinstance(want, Ability) {
            (want_names, want_variadic) = _param_names(want);
            for (index, pname) in enumerate(binding.params) {
                if want_variadic or pname in want_names {
                    continue;
                }
                out.append(
                    (
                        decl,
                        f"parameter {index + 1} of '{name}' is named '{pname}', "
                        f"which the Python interface does not declare"
                    )
                );
            }
        } elif isinstance(decl, Archetype) and isinstance(want, Archetype) {
            want_members = _member_names(want);
            for member in sorted(binding.members) {
                if member.startswith("_") or member in want_members {
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
