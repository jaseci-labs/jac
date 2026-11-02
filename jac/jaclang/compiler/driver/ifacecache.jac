import from contextlib { contextmanager }
import from pathlib { Path }
import from collections.abc { Callable, Iterator }
import os;
import time;

glob DIAG_SCHEMA: int = 1,
     SOURCE_DEP_PREFIX: str = "src:",
     IFACE_RETAIN_CAP: int = 1024,
     _CODEC_MODULES: tuple[str, ...] = (
         "jaclang.compiler.types.type_evaluator",
         "jaclang.compiler.types.stubcat.reader",
         "jaclang.compiler.types.stubcat.writer",
         "jaclang.compiler.types.stubcat.modiface"
     ),
     _CODEC_MEMO: list[IfaceCodec] = [];

obj IfaceCodec {
    has build_module_iface: any,
        open_module_iface: any,
        read_iface_hash: any,
        iface_module: any;
}

def iface_codec -> (IfaceCodec | None);

def prime_iface_codec -> (IfaceCodec | None);

def iface_verify_enabled -> bool;

def _interface_source_path(path: str) -> bool;

def native_lowering_reads(path: str) -> bool;


def _span_record(span: any) -> list[str | int | None];

def _span_from_record(rec: list[any]) -> any;

def _alert_record(alert: any) -> dict[str, any];

def _alert_from_record(rec: dict[str, any]) -> any;

obj IfaceEntry {
    has path: str,
        digest: str,
        section: (bytes | None) = None,
        placement: (bytes | None) = None,
        diags: (bytes | None) = None,
        paths: JirPaths | None = None,
        catalog: any = None,
        module: any = None,
        stamp: float = 0.0,
        replayed_token: int = -1;
}

obj EncodedInterface {
    has module_key: str,
        section: bytes,
        digest: str,
        paths: JirPaths | None = None;
}

obj IfaceRegistry(CatalogResolver) {
    has prog: any,
        entries: dict[str, IfaceEntry] = {},
        building: set[str] postinit,
        checking: set[str] postinit,
        frames: list[str] postinit,
        direct_deps: dict[str, dict[str, str]] = {},
        _iface_bytes: dict[str, EncodedInterface] = {},
        _incoherent: set[str] = set(),
        verifying: bool = False,
        cold: bool = False,
        closure_token: int = 0,
        _pkg_dir_memo: str = "";

    def postinit;
    def on_closure_release;
    def _event(name: str);
    def _pkg_dir -> str;
    def forget(resolved_path: str);
    def clear;
    def frame_push(resolved_path: str);
    def frame_pop;
    def note_dep(dep_path: str);
    def _client_edges(mod: any) -> set[str];
    def dep_rows(resolved_path: str, mod: any) -> list[DepRow];
    def _entry_fresh(ent: IfaceEntry) -> bool;
    def _register(
        resolved: str,
        digest: str,
        section: (bytes | None),
        placement: (bytes | None),
        diags: (bytes | None) = None,
        remember: bool = True,
        paths: JirPaths | None = None
    ) -> IfaceEntry;

    @contextmanager
    def _compilation_scope -> Iterator[None];

    def _module_jir(resolved: str) -> tuple[bytes, str] | None;
    def ensure(path: str, compile_on_miss: bool = True) -> IfaceEntry | None;
    def serve(compiler: any, resolved: str, options: any) -> any;
    def prepare_interface(resolved: str, mod: any) -> bool;
    def persist_after_compile(
        resolved: str, mod: any, options: any, err_start: int, warn_start: int
    );

    def _module_jir_in_context(resolved: str) -> (tuple[bytes, str] | None);
    def _register_from_disk(resolved: str, check_deps: bool) -> (IfaceEntry | None);
    def _deps_match(data: bytes, base_dir: str = "") -> bool;
    def _ensure_in_context(
        path: str, compile_on_miss: bool = True
    ) -> (IfaceEntry | None);

    def _materialize(ent: IfaceEntry) -> any;
    def _restore_placement(ent: IfaceEntry);
    def _prepare(ent: IfaceEntry, mod: any);
    static def _profiles_of(
        diag_bytes: (bytes | None), path_mapper: Callable[[str], str] | None = None
    ) -> (dict[str, any] | None);

    def _replay_records(prof: dict[str, any], err0: int, warn0: int);
    def eligible(compiler: any, resolved: str, options: any) -> bool;
    def ready -> bool;
    def _serve_in_context(compiler: any, resolved: str, options: any) -> any;
    def _serve_symtab(resolved: str, profile_key: (str | None)) -> any;
    def _serve_analysis(compiler: any, resolved: str, options: any) -> any;
    def analysis_profile(options: any) -> str;
    def _ensure_flow_graph(mod: any) -> None;
    def _encode_iface(codec: IfaceCodec, mod: any, paths: JirPaths) -> (bytes | None);
    def _prepare_interface_in_context(resolved: str, mod: any) -> bool;
    def _persist_in_context(
        resolved: str, mod: any, options: any, err_start: int, warn_start: int
    ) -> None;

    def _disk_iface_digest(resolved: str) -> str;
    def _existing_profiles(resolved: str) -> dict[str, any];
    def client_boundary_facts(dep_path: str) -> (list[str] | None);
    def resolve_module(path: str) -> (Module | None);
    def resolve_shared(
        module_path: str, dotted: str, class_name: str
    ) -> (ClassDetailsShared | None);

    def _fresh_verify_program -> JacProgram;
    def _verify_iface(resolved: str, ent: IfaceEntry) -> None;
    def _verify_analysis(resolved: str, options: any, prof: dict[str, any]);
}

def artifact_cache_path(path: str, program: JacProgram) -> Path;

def seed_dep_edges(prog: any, root_dir: str, limit: int = 5000) -> int;
