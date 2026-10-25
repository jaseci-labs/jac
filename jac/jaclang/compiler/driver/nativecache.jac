import gc;
import os;
import sys;
import time;

glob SLOW_STEP_SECONDS: float = 2.0,
     DEMOTED_SYMBOL_SUFFIX: str = ".__jac_demoted",
     _HEAP_HELD: list[bool] = [False];

class NativeBuildStopped(BaseException) {}

obj NativeUnitEntry {
    has path: str,
        digest: str,
        iface: NativeIface,
        stamp: NativeStamp,
        source: str = "",
        source_key: (str | None) = None,
        object_bytes: (bytes | None) = None,
        bitcode: (bytes | None) = None,
        compile_deps: bytes = b"",
        compile_deps_base: str = "",
        dep_digests: dict[str, str] = {},
        deps_checked: bool = True;
}

obj NativeUnitRegistry {
    has prog: JacProgram,
        session: (NativeBuildSession | None) = None,
        entries: dict[str, NativeUnitEntry] = {},
        building: set[str] postinit,
        not_native: dict[str, str] = {},
        failures: dict[str, str] = {},
        compiled_paths: list[str] = [],
        progress: (Callable[[str], None] | None) = None,
        progress_steps: int = 0,
        cold: bool = False,
        stop_after: int = 0,
        lowered_units: int = 0,
        unit_lower_seconds: dict[str, float] = {},
        unit_functions: dict[str, tuple[int, int]] = {};

    def postinit;
    def begin_parse(path: str);
    def note_step(verb: str, path: str = "", detail: str = "") -> float;
    def note_slow_step(verb: str, path: str, started: float);
    def clear;
    def release_products;
    def forget(path: str);
    def adopt_dep_digests(path: str, digests: dict[str, str]) -> bool;
    static def _source_key(path: str) -> (str | None);
    def _miss(path: str, why: str);
    def _event(name: str);
    def _add_time(name: str, seconds: float);
    def _timed(name: str, started: float);
    def _timed_unit(name: str, path: str, started: float);
    def phase_summary -> str;
    def note_codegen(path: str, object_emitted: bool = True);
    def note_link(reused: bool);
    def _options -> CompileOptions;
    def stamp_for(
        options: (CompileOptions | None) = None, path: str = ""
    ) -> NativeStamp;

    def _carry(resolved: str, stamp: NativeStamp) -> bool;
    def _module_jir(
        resolved: str, stamp: (NativeStamp | None) = None
    ) -> (tuple[bytes, str] | None);

    def _entry_fresh(ent: NativeUnitEntry) -> bool;
    def _register(
        resolved: str, iface: NativeIface, stamp: NativeStamp, source: str
    ) -> NativeUnitEntry;

    def record(
        path: str,
        iface: NativeIface,
        options: (CompileOptions | None) = None,
        dep_digests: (dict[str, str] | None) = None,
        compile_deps: bytes = b""
    ) -> NativeUnitEntry;

    def record_module(
        module: Module, options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None);

    def _explain_iface_change(
        path: str, iface: NativeIface, options: (CompileOptions | None)
    );

    def recorded_native_deps(
        path: str, options: (CompileOptions | None) = None
    ) -> list[tuple[str, str]];

    def _deps_match(
        dep_digests: list[tuple[str, str]], options: (CompileOptions | None) = None
    ) -> bool;

    def dep_digests(paths: list[str]) -> dict[str, str];
    def _dep_miss(resolved: str);
    def _read_from_disk(
        resolved: str,
        stamp: NativeStamp,
        check_deps: bool,
        options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None);

    def ensure(
        path: str,
        compile_on_miss: bool = True,
        options: (CompileOptions | None) = None,
        check_deps: bool = True,
        products: bool = True
    ) -> (NativeUnitEntry | None);

    def dep_iface(
        path: str, options: CompileOptions, products: bool = True
    ) -> (NativeIface | None);

    def dep_discovery_open -> bool;
    def close_dep_deferral -> bool;
    def known_native_deps(path: str, options: CompileOptions) -> list[str];
    def product_sections(path: str) -> dict[int, bytes];
    def compile_unit(
        path: str,
        options: (CompileOptions | None) = None,
        use_str: (str | None) = None,
        products: bool = True
    ) -> (NativeUnitEntry | None);

    def adopt_lowered(
        path: str,
        ir_text: str,
        iface_text: str,
        layout_json: str,
        deps: list[str],
        compile_deps: bytes,
        options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None);

    def _stash_products(resolved: str, gen: CodeGenTarget);
    def known_digest(path: str) -> str;
    def _with_products(
        path: str, options: (CompileOptions | None) = None
    ) -> (NativeUnitEntry | None);

    def emit_objects(paths: list[str], options: (CompileOptions | None) = None);
    def object_for(
        path: str, options: (CompileOptions | None) = None
    ) -> (bytes | None);

    def bitcode_for(
        path: str, options: (CompileOptions | None) = None
    ) -> (bytes | None);

    def _live_gen(resolved: str) -> (CodeGenTarget | None);
}

obj SessionHeap {
    has held: bool = False,
        declined: bool = False,
        thresholds: tuple[int, int, int] = (0, 0, 0);

    def take -> bool;
    def settle -> float;
    def release;
}

obj NativeBuildSession {
    has registry: NativeUnitRegistry,
        options: CompileOptions,
        prog: JacProgram postinit,
        lowered: dict[str, Module] = {},
        source_keys: dict[str, str | None] = {},
        deferred: list[set[str]] = [],
        discovery_open: list[bool] = [],
        unlowerable: set[str] = set(),
        heap: SessionHeap = SessionHeap();

    def discovering -> bool;
    def defer(path: str);
    def close_discovery -> bool;
    def postinit;
    def settle_heap;
    def lower(path: str, use_str: (str | None) = None) -> (NativeUnitEntry | None);
    def unbound_symbols(path: str, deps: list[str]) -> (list[str] | None);
    def finish(paths: list[str]);
    def _optimize_in_parallel(paths: list[str]) -> set[str];
    def _finish(paths: list[str]);
    def close;
}

glob VERDICT_CLOSURE_LIMIT: int = 4096;

def _ir_symbols(unit_ir: any) -> (tuple[set[str], set[str]] | None);

def _ir_referenced_symbols(unit_ir: any) -> set[str];

def _interface_changes(before: any, after: any, path: str, out: list[str]);
