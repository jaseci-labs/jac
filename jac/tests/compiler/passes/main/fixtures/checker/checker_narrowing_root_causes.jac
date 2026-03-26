"""Tests for key type checker root causes found in runtime.impl.jac.

Each section documents a specific type checker limitation with minimal reproduction
cases. All functions prefixed with fail_ currently produce false positive errors
(these are type checker bugs). All ok_ functions are baselines that must not regress.

Root Cause 1: No narrowing after `raise` — raising on None doesn't narrow attr type
Root Cause 2: Unknown propagation — one Unknown cascades into N errors
Root Cause 3: Callable resolves to _SpecialForm — Callable type annotation loses info
Root Cause 4: Assignment into narrowed-None variable rejected
Root Cause 5: String slicing loses type — str[1:] resolves to Unknown instead of str
Root Cause 6: Stdlib return types resolve to Unknown (importlib.util)
Root Cause 7: Nullable attr access on user_root without raise guard
Root Cause 8: Dynamic / runtime class attributes not recognized
Root Cause 9: Union with Any blocks attribute access
Root Cause 10: TypeVar in impl blocks — E1065 in impl but not in def
"""

import from typing { Callable, TypeVar }
import importlib.util;
import from concurrent.futures { ThreadPoolExecutor, Future }

# ============================================================================
# Shared types
# ============================================================================

obj Program {
    has mtir_map: dict[str, str] = {};
}

obj Runtime {
    has program: Program | None = None;
}

obj NodeAnchor {
    has id: int = 0,
        edges: list[int] = [],
        root: int | None = None;
}

obj Context {
    has user_root: NodeAnchor | None = None;
}

obj Memory {
    has data: dict[str, str] = {};
}

obj TieredMemory(Memory) {
    has l3: str | None = None;
    def get_mem() -> dict[str, str] {
        return self.data;
    }
}

obj Destination {
    has nd: (Callable[[str], bool] | None) = None;
}

obj EdgeAnchor {
    has id: int = 0,
        __jac__: str = "edge_anchor";
}

obj GenericEdge {
    has id: int = 0,
        __jac__: str = "generic_edge";
}

obj Archetype {
    has name: str = "arch";
}

obj WalkerArchetype(Archetype) {}

obj ServiceClass {
    has pool: ThreadPoolExecutor = ThreadPoolExecutor();
}

def use_program(p: Program) -> dict[str, str] {
    return p.mtir_map;
}

# ============================================================================
# Root Cause 1: No narrowing after `raise`
#
# After `if x is None { raise ValueError(...); }`, the type checker should
# narrow x from T|None to T on subsequent lines. Currently it doesn't,
# causing false positive E1099 errors on attribute access.
#
# Mirrors: runtime.impl.jac lines 1964-1978 (JacRuntime.program.mtir_map)
# ============================================================================

# --- ok_ functions: baseline patterns that work ---

def ok_raise_narrowing_simple(val: int | None) -> int {
    if val is None {
        raise ValueError("missing");
    }
    return val + 1;
}

# --- fail_ functions: patterns that fail due to root cause 1 ---

def fail_raise_narrows_attr_access(rt: Runtime) -> dict[str, str] {
    # After raise, rt.program should be narrowed from Program|None to Program
    if rt.program is None {
        raise ValueError("no program");
    }
    return rt.program.mtir_map;  # E1099: attribute missing from NoneType
}

def fail_raise_narrows_method_call(rt: Runtime) -> dict[str, str] {
    if rt.program is None {
        raise RuntimeError("not loaded");
    }
    return use_program(rt.program);  # E1053: cannot assign Program|None to Program
}

def fail_raise_narrows_multiple_access(rt: Runtime) -> str {
    if rt.program is None {
        raise ValueError("no program");
    }
    m = rt.program.mtir_map;  # E1099
    return str(len(m));
}

def fail_raise_narrows_elif_chain(rt: Runtime, key: str) -> str {
    if rt.program is None {
        raise ValueError("no program");
    } elif key == "" {
        raise ValueError("no key");
    }
    return rt.program.mtir_map.get(key, "");  # E1099
}

# ============================================================================
# Root Cause 2: Unknown propagation
#
# When a type resolves to Unknown (e.g., from a missing subclass attribute),
# every subsequent attribute access or method call on that Unknown value
# chains into more Unknown errors (E1032).
# One root Unknown produces N cascading errors.
#
# Mirrors: runtime.impl.jac lines 933-952 (Memory.l3 -> Unknown -> .values())
# ============================================================================

def fail_unknown_cascade_from_subclass_attr(mem: Memory) -> str | None {
    # mem is typed as Memory, but at runtime is TieredMemory.
    # Accessing .l3 (defined only on TieredMemory) gives Unknown,
    # which then cascades to all subsequent uses.
    persistence = mem.l3;                # E1030: Memory has no attribute l3
    result = persistence.some_attr       # E1032: Unknown (cascade from above)
        if persistence
        else None;
    return result;
}

def fail_unknown_cascade_from_method(mem: Memory) -> list {
    # get_mem() is only on TieredMemory, not on base Memory
    data = mem.get_mem();                # E1030: Memory has no attribute get_mem
    return `list(data.values());         # E1032: Unknown (cascade from above)
}

# ============================================================================
# Root Cause 3: Callable type annotation resolves to _SpecialForm
#
# When a parameter is annotated as `Callable`, the type checker resolves
# the type to `_SpecialForm` (the typing internal) instead of the actual
# callable type. This means accessing standard callable attributes like
# `__name__` fails, and passing a Callable to a Callable parameter fails.
#
# Mirrors: runtime.impl.jac lines 1204-1212 (test_fun: Callable -> __name__)
# Also mirrors: line 1837 (caller: Callable -> _SpecialForm)
# ============================================================================

def fail_callable_has_name(func: Callable) -> str {
    # Callable-typed parameter should support __name__ attribute access
    return func.__name__;  # E1030: _SpecialForm has no __name__
}

def fail_callable_set_name(func: Callable) -> None {
    # Should be able to set __name__ on a callable
    func.__name__ = "renamed";  # E1030: _SpecialForm has no __name__
}

def use_callable(caller: Callable[..., object]) -> None {
    _ = caller;
}

def fail_callable_passed_as_callable(func: Callable) -> None {
    # Callable should be assignable to Callable[..., object]
    use_callable(func);  # E1053: _SpecialForm cannot assign to Callable
}

# ============================================================================
# Root Cause 4: Assignment into narrowed-None variable rejected
#
# Inside `if x.attr is None { x.attr = new_value; }`, the type checker
# narrows x.attr to NoneType in the true branch. But then assigning a
# non-None value should update the type, not reject the assignment as
# "Cannot assign T to NoneType".
#
# Mirrors: runtime.impl.jac line 1353 (last.nd = post_filter after is None check)
# ============================================================================

def fail_assign_to_narrowed_none_field(dest: Destination) -> None {
    # dest.nd is Callable|None. After `is None` check, narrowed to NoneType.
    # Assigning a Callable should be valid (updating the field).
    filter_fn: Callable[[str], bool] = lambda s: str : s.startswith(".");
    if dest.nd is None {
        dest.nd = filter_fn;  # E1001: Cannot assign Callable to NoneType
    }
}

def fail_assign_to_narrowed_none_local(x: int | None) -> int {
    # Local variable narrowed to None, then reassigned
    if x is None {
        x = 42;  # Should be fine — reassignment updates type
    }
    return x;
}

# ============================================================================
# Root Cause 5: String slicing loses type information
#
# When a string variable is sliced (e.g., s = s[1:]), the resulting type
# should still be str, but the type checker resolves it to Unknown.
# Subsequent string method calls (e.g., .startswith(), .endswith()) then
# fail with E1032.
#
# Mirrors: runtime.impl.jac line 1096 (chomp_target = chomp_target[1:])
# then chomp_target.startswith('.') fails
# ============================================================================

def fail_string_slice_loses_type(target: str) -> str {
    chomp = target;
    while chomp.startswith('.') {
        chomp = chomp[1:];          # slice should preserve str type
        if chomp.startswith('.') {  # E1032: Unknown has no .startswith
            continue;
        }
    }
    return chomp;
}

def fail_string_slice_endswith(path: str) -> bool {
    base = path[:-3];               # slice should be str
    return base.endswith(".jac");    # E1032 if slice type is Unknown
}

def fail_string_index_method(s: str) -> str {
    c = s[0];                       # indexing str should give str
    return c.upper();               # E1032 if index type is Unknown
}

# ============================================================================
# Root Cause 6: Stdlib return types resolve to Unknown
#
# When calling stdlib functions like `importlib.util.spec_from_file_location`,
# the return type resolves to Unknown instead of `ModuleSpec | None`.
# All subsequent attribute access (.origin, .loader, .submodule_search_locations)
# cascades into Unknown errors. This is the single largest source of errors
# in runtime.impl.jac (~20 errors from one root cause).
#
# Mirrors: runtime.impl.jac lines 1118-1165 (spec_from_file_location chain)
# ============================================================================

def fail_stdlib_spec_from_file_location(name: str, path: str) -> str {
    # importlib.util.spec_from_file_location should return ModuleSpec | None
    spec = importlib.util.spec_from_file_location(name, path);
    if (not spec or not spec.origin) {          # E1032: Unknown has no .origin
        raise ImportError("cannot find module");
    }
    return spec.origin;                          # E1032/E1099: Unknown.origin
}

def fail_stdlib_spec_loader(name: str, path: str) -> None {
    spec = importlib.util.spec_from_file_location(name, path);
    if (not spec or not spec.origin) {
        raise ImportError("missing");
    }
    if spec.loader {                            # E1099: Unknown.loader
        spec.loader.exec_module(None);          # E1032: Unknown.exec_module
    }
}

def fail_stdlib_spec_submodule(name: str, path: str) -> list[str] | None {
    spec = importlib.util.spec_from_file_location(name, path);
    if spec {
        return spec.submodule_search_locations;  # E1099: Unknown.submodule_search_locations
    }
    return None;
}

def fail_stdlib_spec_endswith(name: str, path: str) -> bool {
    spec = importlib.util.spec_from_file_location(name, path);
    if spec and spec.origin {
        return spec.origin.endswith('.jac');      # E1032: Unknown.endswith (cascade)
    }
    return False;
}

# ============================================================================
# Root Cause 7: Nullable attribute access without raise guard
#
# When a field is typed as T|None (like user_root: NodeAnchor|None) and code
# accesses attributes on it without an explicit None check or raise guard,
# the checker correctly flags it. But even WITH truthiness guards or
# isinstance checks, the checker sometimes fails to narrow through
# attribute chains.
#
# Mirrors: runtime.impl.jac lines 930-952 (ranchor = ... ctx.user_root),
# line 961 (user_root.archetype), line 1576 (user_root.id)
# ============================================================================

def fail_nullable_attr_no_guard(ctx: Context) -> int {
    # Direct access without null check — this IS a real bug pattern,
    # but included to document the error cascade behavior
    return ctx.user_root.id;        # E1099: NodeAnchor|None missing .id from NoneType
}

def fail_nullable_attr_archetype(ctx: Context) -> int {
    # Accessing .id through nullable chain
    anchor = ctx.user_root;
    return anchor.id;               # E1099: NodeAnchor|None
}

def fail_nullable_ternary_then_access(
    root: NodeAnchor | None,
    ctx: Context
) -> int {
    # Ternary where one branch is T|None — result is T|None
    # Subsequent access without guard fails
    ranchor = root if root else ctx.user_root;
    # ranchor is NodeAnchor|None — accessing without guard
    return ranchor.id;              # E1099: NodeAnchor|None
}

def fail_nullable_ternary_edges(
    root: NodeAnchor | None,
    ctx: Context
) -> list[int] {
    ranchor = root if root else ctx.user_root;
    return ranchor.edges;           # E1099: NodeAnchor|None
}

# ============================================================================
# Root Cause 8: Dynamic / runtime class attributes not recognized
#
# When code accesses attributes that are set dynamically at runtime
# (e.g., via setattr, type(), or metaclass magic), the checker doesn't
# know about them. Also, accessing attributes on `object`-typed params
# fails because `object` has a minimal interface.
#
# Mirrors: runtime.impl.jac line 1001 (type[Archetype].reports),
# line 1947 (JacByLLM._default_llm_instance),
# line 1888 (object.call_params),
# line 2221 (ThreadPoolExecutor.submit — stdlib method not found)
# ============================================================================

def fail_dynamic_class_attr(cls: type[Archetype]) -> None {
    # Setting a class-level attribute dynamically — checker doesn't know it exists
    cls.reports = [];               # E1030: type[Archetype] has no attribute reports
}

def fail_dynamic_instance_cache() -> object {
    # Using getattr to check for cached instance, then setting it
    _cache = getattr(WalkerArchetype, '_instance', None);
    if _cache is not None {
        return _cache;
    }
    instance = WalkerArchetype();
    WalkerArchetype._instance = instance;  # E1030: WalkerArchetype has no _instance
    return instance;
}

def fail_object_typed_attr(model: object) -> dict {
    # Parameter typed as `object` — accessing .call_params fails
    params = model.call_params;     # E1030: object has no attribute call_params
    return params if isinstance(params, `dict) else {};
}

def fail_stdlib_method_on_assigned(svc: ServiceClass) -> Future {
    # ThreadPoolExecutor.submit should be recognized from stdlib
    executor = svc.pool;
    return executor.submit(lambda : None);  # E1032 if executor type is Unknown
}

# ============================================================================
# Root Cause 9: Union with Any blocks attribute access
#
# When a type is a union containing `Any` (e.g., Any | EdgeArchetype),
# the checker reports that `Any` doesn't have the attribute, even though
# `Any` should be compatible with all attribute access by definition.
#
# Mirrors: runtime.impl.jac line ~1400 (__jac__ on Any | EdgeArchetype | GenericEdge)
# ============================================================================

def fail_any_in_union_blocks_attr(
    `edge: (Any | EdgeAnchor | GenericEdge)
) -> str {
    # Any should allow any attribute access, so union with Any should too
    return `edge.__jac__;            # E1099: missing from Any
}

def fail_any_in_union_method(
    val: (Any | str)
) -> int {
    # Any | str — should allow .upper() (from str) or any attr (from Any)
    return len(val.upper());
}

# ============================================================================
# Root Cause 10: TypeVar in impl blocks
#
# A TypeVar defined at module level works fine in standalone `def` functions,
# but when used in an `impl` block, the checker reports E1065:
# "Type variable T has no meaning in this context."
#
# Mirrors: runtime.impl.jac line 1506 (impl JacBasics.assign_all(target: list[T]))
# where T is defined at module level in runtime.jac line 76.
#
# NOTE: This requires a .jac + .impl.jac file pair to reproduce.
# See checker_narrowing_root_causes_impl.jac for the obj declaration
# and checker_narrowing_root_causes_impl.impl.jac for the impl block.
# The test for this root cause compiles the _impl.jac file instead.
# ============================================================================

# TypeVar in standalone def works fine (baseline — should have 0 errors):
glob T = TypeVar("T");

def ok_typevar_in_def(target: list[T]) -> list[T] {
    return target;
}
