import json;
import os;
import re;
import time;
import from pathlib { Path }
import from collections { namedtuple }

glob SourceLocation = namedtuple("SourceLocation", ["file", "line", "column"]);

glob _B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
     _B64_DECODE = {c: i for (i, c) in enumerate(_B64)};

def _encode_vlq(value: int) -> str {
    if value < 0 {
        value = ((-value) << 1) | 1;
    } else {
        value = value << 1;
    }
    result: list[str] = [];
    while True {
        digit = value & 0x1F;
        value >>= 5;
        if value > 0 {
            digit |= 0x20;
        }
        result.append(_B64[digit]);
        if value == 0 {
            break;
        }
    }
    return "".join(result);
}

def _decode_vlq(segment: str) -> list[int] {
    values: list[int] = [];
    shift = 0;
    value = 0;
    for ch in segment {
        digit: int = int(_B64_DECODE.get(ch, 0));
        value += (digit & 0x1F) << shift;
        if digit & 0x20 {
            shift += 5;
        } else {
            values.append(-(value >> 1) if (value & 1) else (value >> 1));
            value = 0;
            shift = 0;
        }
    }
    return values;
}

def generate_source_map_json(
    source_file: str, output_file: str, line_map: list[tuple[int, int, int]]
) -> str {
    if not line_map {
        return json.dumps(
            {"version": 3, "file": output_file, "sources": [], "mappings": ""}
        );
    }
    mappings_lines: list[str] = [];
    prev_src_line = 0;
    prev_src_col = 0;
    max_out_line = max(entry[0] for entry in line_map);

    line_to_src: dict[int, tuple[int, int]] = {};
    for (out_line, src_line, src_col) in line_map {
        if out_line not in line_to_src {
            line_to_src[out_line] = (src_line, src_col);
        }
    }
    for out_line in range(1, max_out_line + 1) {
        if out_line in line_to_src {
            (src_line, src_col) = line_to_src[out_line];
            segment = (
                _encode_vlq(0) + _encode_vlq(0) + _encode_vlq(
                    src_line - 1 - prev_src_line
                ) + _encode_vlq(src_col - prev_src_col)
            );
            prev_src_line = src_line - 1;
            prev_src_col = src_col;
            mappings_lines.append(segment);
        } else {
            mappings_lines.append("");
        }
    }
    return json.dumps(
        {
            "version": 3,
            "file": output_file,
            "sources": [source_file],
            "names": [],
            "mappings": ";".join(mappings_lines)
        }
    );
}

def read_source_snippet(file_path: str, line: int, context_lines: int = 2) -> str {
    try {
        path = Path(file_path);
        if not path.exists() {
            return "";
        }
        lines = path.read_text(encoding="utf-8").splitlines();
        start = max(0, line - context_lines - 1);
        end = min(len(lines), line + context_lines);
        snippet_lines: list[str] = [];
        for i in range(start, end) {
            line_num = i + 1;
            prefix = " -> " if line_num == line else "    ";
            snippet_lines.append(f"{prefix}{line_num:4} | {lines[i]}");
        }
        return "\n".join(snippet_lines);
    } except Exception {
        return "";
    }
}

def _parse_mappings(mappings_str: str) -> list[list[tuple[int, int, int, int]]] {
    lines: list[list[tuple[int, int, int, int]]] = [];
    src_idx = 0;
    src_line = 0;
    src_col = 0;
    for group in mappings_str.split(";") {
        gen_col = 0;
        segments: list[tuple[int, int, int, int]] = [];
        if group {
            for segment_str in group.split(",") {
                if not segment_str {
                    continue;
                }
                fields = _decode_vlq(segment_str);
                if len(fields) >= 4 {
                    gen_col += fields[0];
                    src_idx += fields[1];
                    src_line += fields[2];
                    src_col += fields[3];
                    segments.append((gen_col, src_idx, src_line, src_col));
                }
            }
        }
        lines.append(segments);
    }
    return lines;
}

def _scan_source_comments(compiled_dir: Path) -> dict[str, str] {
    comments: dict[str, str] = {};
    if not compiled_dir.is_dir() {
        return comments;
    }
    for js_file in compiled_dir.rglob("*.js") {
        try {
            with open(js_file, encoding="utf-8") as f {
                first_line = f.readline().strip();
            }
            m = re.match(r"/\* Source: (.+?) \*/", first_line);
            if m {
                jac_path = m.group(1);
                rel = str(js_file.relative_to(compiled_dir));
                comments[rel] = jac_path;
                comments[str(js_file)] = jac_path;
                comments[f"../compiled/{rel}"] = jac_path;
            }
        } except (OSError, UnicodeDecodeError) {
            continue;
        }
    }
    return comments;
}

glob _STACK_PATTERN = re.compile(r"at\s+(\S+)\s+\((.+?):(\d+):(\d+)\)"),
     _STACK_PATTERN_ANON = re.compile(r"at\s+(.+?):(\d+):(\d+)");

obj SourceMap {
    has sources: list[str],
        source_comments: dict[str, str],
        _index: list[list[tuple[int, int, int, int]]];

    def _resolve_raw(line: int, column: int) -> tuple[str, int, int] | None {
        if line < 1 or line > len(self._index) {
            return None;
        }
        segments = self._index[line - 1];
        if not segments {
            return None;
        }
        best = segments[0];
        for seg in segments {
            if seg[0] <= column {
                best = seg;
            } else {
                break;
            }
        }
        (src_idx, src_line, src_col) = (best[1], best[2], best[3]);
        if src_idx < 0 or src_idx >= len(self.sources) {
            return None;
        }
        return (self.sources[src_idx], src_line + 1, src_col);
    }

    def resolve(line: int, column: int) -> SourceLocation | None {
        if line < 1 or line > len(self._index) {
            return None;
        }
        segments = self._index[line - 1];
        if not segments {
            return None;
        }
        best = segments[0];
        for seg in segments {
            if seg[0] <= column {
                best = seg;
            } else {
                break;
            }
        }
        (src_idx, src_line, src_col) = (best[1], best[2], best[3]);
        if src_idx < 0 or src_idx >= len(self.sources) {
            return None;
        }
        compiled_path = self.sources[src_idx];
        jac_path = self._resolve_to_jac(compiled_path);
        return SourceLocation(file=jac_path, line=src_line + 1, column=src_col);
    }

    def _resolve_to_jac(compiled_path: str) -> str {
        if compiled_path in self.source_comments {
            return self.source_comments[compiled_path];
        }
        basename = os.path.basename(compiled_path);
        for (key, jac_path) in self.source_comments.items() {
            if os.path.basename(key) == basename {
                return jac_path;
            }
        }
        for (key, jac_path) in self.source_comments.items() {
            if compiled_path.endswith(key) or key.endswith(compiled_path) {
                return jac_path;
            }
        }
        return compiled_path;
    }
}

def _is_node_modules(path: str) -> bool {
    return "node_modules" in path;
}

def _short_node_modules(path: str) -> str {
    idx = path.find("node_modules/");
    return path[idx:] if idx >= 0 else path;
}

def _get_map_signature(base_path: str) -> str {
    client_dir = Path(base_path) / ".jac" / "client";
    parts: list[str] = [];
    for sub in ["compiled", "dist"] {
        d = client_dir / sub;
        if d.is_dir() {
            for f in sorted(d.rglob("*.js.map")) {
                try {
                    parts.append(f"{f}:{os.path.getmtime(f)}");
                } except OSError {
                    continue;
                }
            }
        }
    }
    return "|".join(parts);
}

glob _mapper_cache: dict[str, tuple[str, any]] = {};

obj ErrorRateLimiter {
    has _seen: dict[str, float] = {},
        _count: int = 0,
        _window_start: float = 0.0,
        max_per_window: int = 20,
        window_seconds: float = 60.0,
        dedup_seconds: float = 10.0;

    def should_log(message: str) -> bool {
        now: float = time.time();

        if now - self._window_start > self.window_seconds {
            self._window_start = now;
            self._count = 0;
        }

        if self._count >= self.max_per_window {
            return False;
        }

        last_seen = self._seen.get(message, 0.0);
        if now - last_seen < self.dedup_seconds {
            return False;
        }

        self._seen[message] = now;
        self._count += 1;

        if len(self._seen) > 100 {
            cutoff = now - self.dedup_seconds;
            self._seen = {
                k: v
                for (k, v) in self._seen.items()
                if v > cutoff
            };
        }
        return True;
    }
}

glob _error_rate_limiter = ErrorRateLimiter();

obj SourceMapper {
    has _source_map: SourceMap | None = None,
        _per_file_maps: dict[str, SourceMap] = {},
        _base_path: str = "",
        _abs_base_path: str = "";

    static def from_bundle(base_path: str) -> SourceMapper {
        sig: str = _get_map_signature(base_path);
        cached: tuple[str, any] | None = _mapper_cache.get(base_path);
        if cached is not None and cached[0] == sig {
            return SourceMapper(
                _source_map=cached[1]._source_map,
                _per_file_maps=cached[1]._per_file_maps,
                _base_path=cached[1]._base_path
            );
        }
        client_dir = Path(base_path) / ".jac" / "client";
        compiled_dir = client_dir / "compiled";
        dist_dir = client_dir / "dist";

        source_comments = _scan_source_comments(compiled_dir);

        per_file_maps: dict[str, SourceMap] = {};
        if compiled_dir.is_dir() {
            for map_file in compiled_dir.rglob("*.js.map") {
                try {
                    with open(map_file, encoding="utf-8") as f {
                        raw: dict = dict(json.load(f));
                    }
                    sources: list[str] = list(raw.get("sources", []));
                    mappings: str = str(raw.get("mappings", ""));
                    index = _parse_mappings(mappings);
                    js_name: str = str(map_file.name)[:-(len(".map"))];
                    rel_path: str = str(map_file.relative_to(compiled_dir))[:-(
                        len(".map")
                    )];
                    sm = SourceMap(sources=sources, source_comments={}, _index=index);
                    per_file_maps[js_name] = sm;
                    per_file_maps[rel_path] = sm;
                    per_file_maps[f"../compiled/{rel_path}"] = sm;
                } except (OSError, json.JSONDecodeError, KeyError) {
                    continue;
                }
            }
        }

        source_map: SourceMap | None = None;
        if dist_dir.is_dir() {
            for map_file in dist_dir.glob("*.js.map") {
                try {
                    with open(map_file, encoding="utf-8") as f {
                        raw: dict = dict(json.load(f));
                    }
                    sources: list[str] = list(raw.get("sources", []));
                    mappings: str = str(raw.get("mappings", ""));
                    index = _parse_mappings(mappings);
                    source_map = SourceMap(
                        sources=sources, source_comments=source_comments, _index=index
                    );
                    break;
                } except (OSError, json.JSONDecodeError, KeyError) {
                    continue;
                }
            }
        }

        mapper = SourceMapper(
            _source_map=source_map, _per_file_maps=per_file_maps, _base_path=base_path
        );

        _mapper_cache[base_path] = (sig, mapper);
        return mapper;
    }

    def resolve(line: int, column: int) -> SourceLocation | None {
        if self._source_map is None {
            return None;
        }
        raw_loc = self._source_map._resolve_raw(line, column);
        if raw_loc is None {
            return None;
        }
        (compiled_path, compiled_line, compiled_col) = raw_loc;

        compiled_basename = os.path.basename(compiled_path);
        for (key, per_file_map) in self._per_file_maps.items() {
            if key == compiled_basename or key.endswith(f"/{compiled_basename}") {
                second = per_file_map.resolve(compiled_line, compiled_col);
                if second is not None {
                    return second;
                }
                break;
            }
        }

        jac_path = self._source_map._resolve_to_jac(compiled_path);
        return SourceLocation(file=jac_path, line=compiled_line, column=compiled_col);
    }

    def resolve_stack_trace(stack: str, verbose: bool = False) -> str {
        if self._source_map is None {
            return stack;
        }
        resolved_lines: list[str] = [];
        for line in stack.split("\n") {
            result = self._resolve_stack_line(line, verbose);
            if result is not None {
                resolved_lines.append(result);
            }
        }
        return "\n".join(resolved_lines);
    }

    def _resolve_stack_line(line: str, verbose: bool = False) -> str | None {
        if self._source_map is None {
            return line;
        }
        m = _STACK_PATTERN.search(line);
        if m {
            func_name = m.group(1);
            loc = self.resolve(int(m.group(3)), int(m.group(4)));
            if loc {
                display = self._format_resolved_path(loc.file, verbose);
                if display is None {
                    return None;
                }
                return f"    at {func_name} ({display}:{loc.line}:{loc.column})";
            }
            return line;
        }
        m = _STACK_PATTERN_ANON.search(line);
        if m {
            loc = self.resolve(int(m.group(2)), int(m.group(3)));
            if loc {
                display = self._format_resolved_path(loc.file, verbose);
                if display is None {
                    return None;
                }
                return f"    at {display}:{loc.line}:{loc.column}";
            }
            return line;
        }
        return line;
    }

    def _format_resolved_path(path: str, verbose: bool) -> str | None {
        if not path.endswith(".jac") {
            if not verbose {
                return None;
            }
            if _is_node_modules(path) {
                return _short_node_modules(path);
            }
        }
        return self._make_relative(path);
    }

    def _make_relative(path: str) -> str {
        if not self._base_path {
            return path;
        }
        if not self._abs_base_path {
            self._abs_base_path = os.path.abspath(self._base_path);
        }
        try {
            return str(Path(os.path.abspath(path)).relative_to(self._abs_base_path));
        } except ValueError {
            return path;
        }
    }
}

def resolve_client_error_stacks(
    base_path: (str | None),
    stack: str = "",
    component_stack: str = "",
    verbose: bool = False
) -> tuple[str, str] {
    if base_path and (stack or component_stack) {
        try {
            mapper = SourceMapper.from_bundle(base_path);
            if stack {
                stack = mapper.resolve_stack_trace(stack, verbose);
            }
            if component_stack {
                component_stack = mapper.resolve_stack_trace(component_stack, verbose);
            }
        } except Exception { }
    }
    return (stack, component_stack);
}

def format_client_error_log(
    message: str,
    stack: str = "",
    component_stack: str = "",
    url: str = "",
    source: str = ""
) -> list[str] {
    log_parts: list[str] = [f"[Client] {message}"];
    if stack {
        log_parts.append(f"  Stack: {stack}");
    }
    if component_stack {
        log_parts.append(f"  Component stack: {component_stack}");
    }
    if url {
        log_parts.append(f"  URL: {url}");
    }
    if source {
        log_parts.append(f"  Source: {source}");
    }
    return log_parts;
}
