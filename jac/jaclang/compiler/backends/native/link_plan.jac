import ctypes;
import hashlib;
import json;
import os;
import sys;
import time;

glob PLAN_DIGEST_FORMAT: int = 3,
     PARTITION_FUNCTIONS: int = 4096;

enum ArtifactKind {
    EXECUTABLE = "executable",
    SHARED = "shared",
    WASM = "wasm",
    JIT = "jit"
}

glob LIBC_SHARED_NAMES: tuple[str, ...] = ("libc.so.6", "libm.so.6"),
     EXECUTABLE_ENTRY_SYMBOLS: list[str] = ["main", "_start", "_jac_win_start"];

class LinkPlanError(RuntimeError) {}

class SymbolCollision(LinkPlanError) {
    def init(self: SymbolCollision, symbol: str, first: str, second: str);
}

def check_pub_collisions(units: list[LinkUnit]);

def check_prefix_collisions(units: list[LinkUnit]);

obj LinkUnit {
    has path: str,
        prefix: str,
        iface: NativeIface,
        digest: str,
        modkey: str = "",
        is_root: bool = False;
}

obj LinkInputs {
    has objects: list[bytes] = [],
        archives: list[str] = [],
        crt_objects: list[str] = [],
        needed_libs: list[str] = [],
        symbol_lib_map: dict[str, str] = {},
        export_symbols: list[str] = [],
        static_musl: bool = False;

    def digest(plan_digest: str, kind: str, soname: str) -> str;
}

def _file_digest(path: str) -> str;

obj LinkResult {
    has output_path: str,
        plan_digest: str,
        layout_digest: str,
        sha256: str,
        classes: dict[str, any] = {},
        units: list[str] = [],
        reused: bool = False;
}

obj LinkPlan {
    has prog: JacProgram,
        options: CompileOptions,
        roots: list[str],
        units: list[LinkUnit],
        mode: str,
        triple: str,
        callback_bindings: list[InteropBinding] = [],
        library_api: bool = False;

    def unit(path: str) -> (LinkUnit | None);
    def root_unit -> LinkUnit;
    def root_index -> int;
    def init_units -> list[LinkUnit];
    def init_symbols -> list[str];
    def plan_digest -> str;
    def merged_layout -> dict[str, any];
    def layout_digest -> str;
    def demoted_symbols -> list[str];
    def clib_paths -> list[str];
    def clib_symbol_lib -> dict[str, str];
    def pub_exports -> list[str];
    def has_unit(rel: str) -> bool;
    def glue_spec(kind: ArtifactKind, platform: str, static_musl: bool) -> GlueSpec;
}

def initialization_order(units: list[LinkUnit], roots: list[str]) -> list[LinkUnit];

def _init_cycle_message(
    start: str, reads: dict[str, list[tuple[str, str]]], placed: set[str]
) -> str;

def _platform_of(triple: str) -> str;

def build_link_plan(
    prog: JacProgram,
    roots: list[str],
    options: (CompileOptions | None) = None,
    mode: str = "",
    native_unit: bool = False
) -> LinkPlan;

def _build_link_plan(
    prog: JacProgram,
    roots: list[str],
    options: (CompileOptions | None) = None,
    mode: str = "",
    native_unit: bool = False
) -> LinkPlan;

def _target_machine(plan: LinkPlan, kind: ArtifactKind) -> TargetMachine;

obj UnitGlueSymbols {
    has declared: dict[str, str] = {},
        defined: list[str] = [];
}

glob HEAP_GLUE_SYMBOLS: list[str] = ["jac_heap_size", "jac_list_heap_size"],
     _glue_symbol_memo: dict[str, UnitGlueSymbols] = {};

def unit_glue_symbols(
    bitcode: bytes, wanted: list[str], options: CompileOptions
) -> UnitGlueSymbols;

def _glue_symbols_store(key: str, options: CompileOptions) -> str;

def _read_glue_symbols(store: str) -> (UnitGlueSymbols | None);

def _write_glue_symbols(store: str, symbols: UnitGlueSymbols);

def glue_symbol_memo_clear;

def callback_glue_ir(plan: LinkPlan) -> str;

def heap_glue_ir(plan: LinkPlan) -> tuple[str, list[str]];

def _glue_module(
    plan: LinkPlan, spec: GlueSpec, tm: (TargetMachine | None) = None
) -> tuple[ModuleRef, list[str]];

def whole_program_module(
    plan: LinkPlan, spec: GlueSpec
) -> tuple[ModuleRef, list[str]];

def unit_objects(
    plan: LinkPlan, spec: GlueSpec, tm: TargetMachine
) -> tuple[list[bytes], list[str]];

def name_private_functions(merged: ModuleRef);

def optimize_whole_program(
    plan: LinkPlan, merged: ModuleRef, kind: ArtifactKind, tm: TargetMachine
) -> None;

def optimize_merged_program(plan: LinkPlan, merged: ModuleRef, kind: ArtifactKind);

def _log_phase(
    log: (Callable[[str], None] | None), phase: str, started: float
) -> float;

def plan_objects(
    plan: LinkPlan,
    spec: GlueSpec,
    kind: ArtifactKind,
    tm: TargetMachine,
    log: (Callable[[str], None] | None) = None
) -> tuple[list[bytes], list[str]];

def _write_sidecar(
    plan: LinkPlan,
    output_path: str,
    plan_digest: str,
    action_digest: str = "",
    artifact_sha256: str = ""
) -> tuple[dict[str, any], str];

def _sha256_of(path: str) -> str;

def _reuse_artifact(
    plan: LinkPlan, output_path: str, action_digest: str
) -> (LinkResult | None);

def _links_for_host(triple: str) -> bool;

def link_artifact(
    plan: LinkPlan,
    output_path: str,
    kind: ArtifactKind,
    log: any = None,
    app_imports: (set | None) = None
) -> LinkResult;

def _unmangled(symbol: str, mangled: bool) -> str;

def unresolved_unit_symbols(plan: LinkPlan, objects: list[bytes]) -> list[str];

def expose_root_exports(plan: LinkPlan, merged: ModuleRef) -> list[str];

def wasm_program_ir(plan: LinkPlan) -> str;

def link_wasm(
    plan: LinkPlan, output_path: str, app_imports: (set | None) = None
) -> LinkResult;

def undefined_functions(mod: ModuleRef) -> list[str];

def load_jit_library(lib_path: str) -> ctypes.CDLL;

def _jit_image_path(plan: LinkPlan) -> (str | None);

def _has_global(module: ModuleRef, name: str) -> bool;

def _mark_host_rc_threaded(engine: ExecutionEngine);

def jit_engine(plan: LinkPlan) -> ExecutionEngine;

def jit_engine_for_module(
    prog: JacProgram, module: any, options: CompileOptions
) -> (ExecutionEngine | None);

def jit_engine_for_cached(
    prog: JacProgram, path: str, options: CompileOptions
) -> (ExecutionEngine | None);

def internalize_native_implementation(module: ModuleRef, exports: list[str]);
