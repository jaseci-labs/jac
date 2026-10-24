import hashlib;
import importlib;
import os;
import from pathlib { Path }

glob FORMAT_CACHE_SCHEMA_VERSION: str = "v1",
     _ENTRY_MARKER: bytes = b"JFMTCLEAN\n",
     PRUNE_SENTINEL: str = SWEEP_SENTINEL,
     PRUNE_INTERVAL_SECONDS: float = SWEEP_INTERVAL_SECONDS,
     ENTRY_TTL_SECONDS: float = 2592000.0,
     MAX_ENTRIES: int = 20000,
     _FORMATTER_PIPELINE_MODULES: tuple[str, ...] = (
         "jaclang.compiler.tools.jac_formatter_pass",
         "jaclang.compiler.tools.jac_auto_lint_pass",
         "jaclang.compiler.tools.doc_ir_gen_pass",
         "jaclang.compiler.tools.comment_injection_pass",
         "jaclang.compiler.tools.normalize_pass",
         "jaclang.compiler.tools.unparse_pass",
         "jaclang.compiler.frontend.unparse",
         "jaclang.compiler.tools.doc_ir",
         "jaclang.compiler.passes.context",
         "jaclang.compiler.passes.execution",

     );

def _stable_dump(value: any) -> str;

def config_fingerprint(config: any, lintfix: bool) -> str;

def canonical_logical_path(path: str, project_root: (str | None) = None) -> str;

def default_format_cache_dir(anchor: (Path | str)) -> Path;

def _module_source_bytes(modname: str) -> bytes;

def formatter_pipeline_revision -> str;

def frame_unit(parts: list[bytes]) -> bytes;

def _frame(label: str, payload: bytes) -> bytes;

obj FormatCache {
    has cache_dir: (Path | str | None),
        enabled: bool = True,
        formatter_stamp: str = "",
        cache_root: (Path | None) = None,
        entry_ttl: float = ENTRY_TTL_SECONDS,
        prune_interval: float = PRUNE_INTERVAL_SECONDS,
        max_entries: int = MAX_ENTRIES;

    def postinit;
    def make_key(
        content: bytes, lintfix: bool, config_fingerprint: str, logical_path: str = ""
    ) -> str;

    def entry_path(key: str) -> Path;
    def is_clean(key: str) -> bool;
    def mark_clean(key: str);
    def _maybe_prune;
}
