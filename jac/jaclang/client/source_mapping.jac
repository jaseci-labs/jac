import json;
import os;
import re;
import time;
import from pathlib { Path }
import from typing { NamedTuple }

class SourceLocation(NamedTuple) {
    has file: str,
        line: int,
        column: int;
}

glob _B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
     _B64_DECODE = {c: i for (i, c) in enumerate(_B64)};

def _encode_vlq(value: int) -> str;

def _decode_vlq(segment: str) -> list[int];

def generate_source_map_json(
    source_file: str, output_file: str, segments: list[tuple[int, int, int, int, str]]
) -> str;

def read_source_snippet(file_path: str, line: int, context_lines: int = 2) -> str;

def _parse_mappings(mappings_str: str) -> list[list[tuple[int, int, int, int, int]]];

def _scan_source_comments(compiled_dir: Path) -> dict[str, str];

glob _STACK_PATTERN = re.compile(r"at\s+(\S+)\s+\((.+?):(\d+):(\d+)\)"),
     _STACK_PATTERN_ANON = re.compile(r"at\s+(.+?):(\d+):(\d+)");

obj SourceMap {
    has sources: list[str],
        source_comments: dict[str, str],
        _index: list[list[tuple[int, int, int, int, int]]],
        names: list[str] = [];

    def _segment_at(line: int, column: int) -> (tuple[int, int, int, int, int] | None);
    def _resolve_raw(line: int, column: int) -> (tuple[str, int, int] | None);
    def name_at(line: int, column: int) -> str;
    def resolve(line: int, column: int) -> (SourceLocation | None);
    def _resolve_to_jac(compiled_path: str) -> str;
}

def _is_node_modules(path: str) -> bool;

def _short_node_modules(path: str) -> str;

def _get_map_signature(base_path: str) -> str;

glob _mapper_cache: dict[str, tuple[str, any]] = {};

obj ErrorRateLimiter {
    has _seen: dict[str, float] = {},
        _count: int = 0,
        _window_start: float = 0.0,
        max_per_window: int = 20,
        window_seconds: float = 60.0,
        dedup_seconds: float = 10.0;

    def should_log(message: str) -> bool;
}

glob _error_rate_limiter = ErrorRateLimiter();

obj SourceMapper {
    has _source_map: SourceMap | None = None,
        _per_file_maps: dict[str, SourceMap] = {},
        _base_path: str = "",
        _abs_base_path: str = "";

    static def from_bundle(base_path: str) -> SourceMapper;
    def resolve(line: int, column: int) -> SourceLocation | None;
    def resolve_stack_trace(stack: str, verbose: bool = False) -> str;
    def _resolve_stack_line(line: str, verbose: bool = False) -> str | None;
    def _format_resolved_path(path: str, verbose: bool) -> str | None;
    def _make_relative(path: str) -> str;
}

glob _SOURCE_HEADER_RE = re.compile(r"/\* Source: (.+?) \*/"),
     _JS_IMPORT_RE = re.compile(
         r"import\s+(?P<clause>[^;]*?)\s+from\s+(?P<q>[\"'])(?P<spec>[^\"']+)(?P=q)"
     ),
     _JS_BARE_IMPORT_RE = re.compile(r"import\s+(?P<q>[\"'])(?P<spec>[^\"']+)(?P=q)");

def _module_rel(module_id: str) -> str;

def _npm_specifier(raw: str) -> str;

def _specifier_matches(spec: str, wanted: str) -> bool;

def _text_pos(text: str, offset: int) -> tuple[int, int];

def _basename(rel: str) -> str;

def _discover_jac_toml(base: str) -> (Path | None);

def _locator_signature(compiled_dir: Path, base_path: str) -> str;

glob _locator_cache: dict[str, tuple[str, any]] = {};

obj JacLocator {
    has base_path: str,
        compiled_dir: Path,
        _sources: dict[str, str] = {},
        _sources_loaded: bool = False,
        _maps: dict[str, SourceMap] = {},
        _maps_missing: set[str] = set(),
        _toml_path: (Path | None) = None,
        _toml_scanned: bool = False,
        _bundle_mapper: (SourceMapper | None) = None,
        _bundle_scanned: bool = False,
        _text_cache: dict[str, str] = {};

    static def for_base(
        base_path: str, compiled_dir: (str | None) = None
    ) -> JacLocator;

    def sources -> dict[str, str];
    def toml_path -> (Path | None);
    def relative(path: str) -> str;
    def _load_map(rel: str) -> (SourceMap | None);
    def _map_for(rel: str) -> (SourceMap | None);
    def _bundle -> (SourceMapper | None);
    def _js_text(rel: str) -> str;
    def owner_for(raw_location: str) -> str;
    def fallback_owner -> str;
    def locate_compiled(
        module_id: str, line: int, column: int
    ) -> (SourceLocation | None);

    def _frame_target(line: str) -> (tuple[str, int, int] | None);
    def locate_stack(stack: str) -> (SourceLocation | None);
    def resolve_stack_trace(stack: str, verbose: bool = False) -> str;
    def locate_import(specifier: str, name: str = "") -> (SourceLocation | None);
    def importer_of(module_id: str, specifier: str) -> (SourceLocation | None);
    def locate_npm_declaration(package: str) -> (tuple[SourceLocation, str] | None);
}
