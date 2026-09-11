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
    source_file: str, output_file: str, segments: list[tuple[int, int, int, int, str]]
) -> str {
    if not segments {
        return json.dumps(
            {
                "version": 3,
                "file": output_file,
                "sources": [source_file],
                "names": [],
                "mappings": ""
            }
        );
    }

    segments = [
        s
        for s in segments
        if s[2] >= 1 and s[3] >= 1
    ];
    if not segments {
        return json.dumps(
            {
                "version": 3,
                "file": output_file,
                "sources": [source_file],
                "names": [],
                "mappings": ""
            }
        );
    }
    by_line: dict[int, list[tuple[int, int, int, int, str]]] = {};
    for seg in segments {
        by_line.setdefault(seg[0], []).append(seg);
    }
    names: list[str] = [];
    name_index: dict[str, int] = {};
    prev_src_line = 0;
    prev_src_col = 0;
    prev_name = 0;
    mappings_lines: list[str] = [];
    max_line = 0;
    for seg in segments {
        if seg[0] > max_line {
            max_line = seg[0];
        }
    }
    for out_line in range(1, max_line + 1) {
        prev_gen_col = 0;
        parts: list[str] = [];
        for (gen_line, gen_col, src_line, src_col, name) in sorted(
            by_line.get(out_line, [])
        ) {
            field = (
                _encode_vlq(gen_col - prev_gen_col)
                + _encode_vlq(0)
                + _encode_vlq(src_line - 1 - prev_src_line)
                + _encode_vlq(src_col - 1 - prev_src_col)
            );
            prev_gen_col = gen_col;
            prev_src_line = src_line - 1;
            prev_src_col = src_col - 1;
            if name {
                if name not in name_index {
                    name_index[name] = len(names);
                    names.append(name);
                }
                idx = name_index[name];
                field += _encode_vlq(idx - prev_name);
                prev_name = idx;
            }
            parts.append(field);
        }
        mappings_lines.append(",".join(parts));
    }
    return json.dumps(
        {
            "version": 3,
            "file": output_file,
            "sources": [source_file],
            "names": names,
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

def _parse_mappings(mappings_str: str) -> list[list[tuple[int, int, int, int, int]]] {
    lines: list[list[tuple[int, int, int, int, int]]] = [];
    src_idx = 0;
    src_line = 0;
    src_col = 0;
    name_idx = 0;
    for group in mappings_str.split(";") {
        gen_col = 0;
        segments: list[tuple[int, int, int, int, int]] = [];
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
                    seg_name = -1;
                    if len(fields) >= 5 {
                        name_idx += fields[4];
                        seg_name = name_idx;
                    }
                    segments.append((gen_col, src_idx, src_line, src_col, seg_name));
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
            m = re.`match(r"/\* Source: (.+?) \*/", first_line);
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
        _index: list[list[tuple[int, int, int, int, int]]],
        names: list[str] = [];

    def _segment_at(line: int, column: int) -> (tuple[int, int, int, int, int] | None) {
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
        return best;
    }

    def _resolve_raw(line: int, column: int) -> (tuple[str, int, int] | None) {
        best = self._segment_at(line, column);
        if best is None {
            return None;
        }
        (src_idx, src_line, src_col) = (best[1], best[2], best[3]);
        if src_idx < 0 or src_idx >= len(self.sources) {
            return None;
        }
        return (self.sources[src_idx], src_line + 1, src_col);
    }

    def name_at(line: int, column: int) -> str {
        best = self._segment_at(line, column);
        if best is None or best[4] < 0 or best[4] >= len(self.names) {
            return '';
        }
        return self.names[best[4]];
    }

    def resolve(line: int, column: int) -> (SourceLocation | None) {
        raw = self._resolve_raw(line, column);
        if raw is None {
            return None;
        }
        (compiled_path, src_line, src_col) = raw;
        return SourceLocation(
            file=self._resolve_to_jac(compiled_path), line=src_line, column=src_col + 1
        );
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
                        raw: dict[str, any] = dict(json.load(f));
                    }
                    sources: list[str] = list(raw.get("sources", []));
                    mappings: str = str(raw.get("mappings", ""));
                    index = _parse_mappings(mappings);
                    js_name: str = str(map_file.name)[:-(len(".map"))];
                    rel_path: str = str(map_file.relative_to(compiled_dir))[:-(
                        len(".map")
                    )];
                    sm = SourceMap(
                        sources=sources,
                        source_comments={},
                        _index=index,
                        names=[str(n) for n in raw.get("names", [])]
                    );
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
            for map_file in dist_dir.`glob("*.js.map") {
                try {
                    with open(map_file, encoding="utf-8") as f {
                        raw: dict[str, any] = dict(json.load(f));
                    }
                    sources: list[str] = list(raw.get("sources", []));
                    mappings: str = str(raw.get("mappings", ""));
                    index = _parse_mappings(mappings);
                    source_map = SourceMap(
                        sources=sources,
                        source_comments=source_comments,
                        _index=index,
                        names=[str(n) for n in raw.get("names", [])]
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
        return SourceLocation(
            file=jac_path, line=compiled_line, column=compiled_col + 1
        );
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

glob _SOURCE_HEADER_RE = re.compile(r"/\* Source: (.+?) \*/"),
     _JS_IMPORT_RE = re.compile(
         r"import\s+(?P<clause>[^;]*?)\s+from\s+(?P<q>[\"'])(?P<spec>[^\"']+)(?P=q)"
     ),
     _JS_BARE_IMPORT_RE = re.compile(r"import\s+(?P<q>[\"'])(?P<spec>[^\"']+)(?P=q)");

def _module_rel(module_id: str) -> str {
    mid = str(module_id or "");
    if not mid {
        return "";
    }
    for cut in ["?", "#"] {
        idx = mid.find(cut);
        if idx >= 0 {
            mid = mid[:idx];
        }
    }
    scheme = mid.find("://");
    if scheme >= 0 {
        rest = mid[scheme + 3:];
        slash = rest.find("/");
        mid = rest[slash:] if slash >= 0 else "";
    }
    mid = mid.replace("\\", "/");
    marker = "/compiled/";
    at = mid.rfind(marker);
    if at >= 0 {
        mid = mid[at + len(marker):];
    } elif mid.startswith("compiled/") {
        mid = mid[len("compiled/"):];
    } else {
        mid = mid.lstrip("/");
    }
    if mid.startswith("/") or ".." in mid.split("/") {
        return "";
    }
    return mid;
}

def _npm_specifier(raw: str) -> str {
    value = str(raw or "").strip();
    if not value {
        return "";
    }
    cut = value.find("?");
    if cut >= 0 {
        value = value[:cut];
    }
    value = value.replace("\\", "/");
    marker = ".vite/deps/";
    at = value.rfind(marker);
    if at >= 0 {
        value = value[at + len(marker):];
        if value.endswith(".js") {
            value = value[:-3];
        }
        if value.startswith("@") {
            value = value.replace("_", "/", 1);
        }
        return value;
    }
    return value;
}

def _specifier_matches(spec: str, wanted: str) -> bool {
    normalized = _npm_specifier(spec);
    if normalized == wanted {
        return True;
    }
    if wanted and normalized.startswith(wanted + "/") {
        return True;
    }
    if normalized and wanted.startswith(normalized + "/") {
        return True;
    }
    return False;
}

def _text_pos(text: str, offset: int) -> tuple[int, int] {
    head = text[:offset];
    line = head.count("\n") + 1;
    start = head.rfind("\n") + 1;
    return (line, offset - start);
}

def _basename(rel: str) -> str {
    return rel.rsplit("/", 1)[-1];
}

def _discover_jac_toml(base: str) -> (Path | None) {
    current = Path(base).resolve();
    for candidate in [current] + list(current.parents) {
        toml = candidate / "jac.toml";
        if toml.is_file() {
            return toml;
        }
    }
    return None;
}

def _locator_signature(compiled_dir: Path, base_path: str) -> str {
    parts: list[str] = [];
    if compiled_dir.is_dir() {
        for f in sorted(compiled_dir.rglob("*.js.map")) {
            try {
                parts.append(f"{f}:{os.path.getmtime(f)}");
            } except OSError {
                continue;
            }
        }
    }
    toml = os.path.join(base_path, "jac.toml");
    try {
        parts.append(f"{toml}:{os.path.getmtime(toml)}");
    } except OSError {
        parts.append(f"{toml}:-");
    }
    return "|".join(parts);
}

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
    ) -> JacLocator {
        base = os.path.abspath(base_path or ".");
        cdir: Path = Path(compiled_dir)
            if compiled_dir
            else Path(os.path.join(base, ".jac", "client", "compiled"));
        key = f"{base}|{cdir}";
        signature = _locator_signature(cdir, base);
        cached: tuple[str, any] | None = _locator_cache.get(key);
        if cached is not None and cached[0] == signature {
            return cached[1];
        }
        locator = JacLocator(base_path=base, compiled_dir=cdir);
        _locator_cache[key] = (signature, locator);
        return locator;
    }

    def sources -> dict[str, str] {
        if self._sources_loaded {
            return self._sources;
        }
        self._sources_loaded = True;
        if not self.compiled_dir.is_dir() {
            return self._sources;
        }
        for js_file in self.compiled_dir.rglob("*.js") {
            rel = js_file.relative_to(self.compiled_dir).as_posix();
            try {
                with open(js_file, encoding="utf-8") as f {
                    first_line = f.readline().strip();
                }
            } except (OSError, UnicodeDecodeError) {
                continue;
            }
            found = _SOURCE_HEADER_RE.`match(first_line);
            if found {
                self._sources[rel] = found.group(1);
            }
        }
        return self._sources;
    }

    def toml_path -> (Path | None) {
        if not self._toml_scanned {
            self._toml_scanned = True;
            self._toml_path = _discover_jac_toml(self.base_path);
        }
        return self._toml_path;
    }

    def relative(path: str) -> str {
        if not path {
            return path;
        }
        try {
            return Path(os.path.abspath(path)).relative_to(self.base_path).as_posix();
        } except ValueError {
            return path;
        }
    }

    def _load_map(rel: str) -> (SourceMap | None) {
        try {
            raw: dict[str, any] = dict(
                json.loads(
                    (self.compiled_dir / (rel + ".map")).read_text(encoding="utf-8")
                )
            );
        } except (OSError, ValueError) {
            return None;
        }
        return SourceMap(
            sources=list(raw.get("sources", [])),
            source_comments={},
            _index=_parse_mappings(str(raw.get("mappings", ""))),
            names=[str(n) for n in raw.get("names", [])]
        );
    }

    def _map_for(rel: str) -> (SourceMap | None) {
        if not rel {
            return None;
        }
        if rel in self._maps {
            return self._maps[rel];
        }
        if rel in self._maps_missing {
            return None;
        }
        direct = self._load_map(rel);
        if direct is not None {
            self._maps[rel] = direct;
            return direct;
        }
        name = _basename(rel);
        for key in sorted(self.sources().keys()) {
            if _basename(key) == name and key != rel {
                alt = self._load_map(key);
                if alt is not None {
                    self._maps[key] = alt;
                    self._maps[rel] = alt;
                    return alt;
                }
                break;
            }
        }
        self._maps_missing.add(rel);
        return None;
    }

    def _bundle -> (SourceMapper | None) {
        if not self._bundle_scanned {
            self._bundle_scanned = True;
            try {
                self._bundle_mapper = SourceMapper.from_bundle(self.base_path);
            } except Exception {
                self._bundle_mapper = None;
            }
        }
        return self._bundle_mapper;
    }

    def _js_text(rel: str) -> str {
        if rel in self._text_cache {
            return self._text_cache[rel];
        }
        try {
            text = (self.compiled_dir / rel).read_text(encoding="utf-8");
        } except (OSError, UnicodeDecodeError) {
            text = "";
        }
        self._text_cache[rel] = text;
        return text;
    }

    def owner_for(raw_location: str) -> str {
        rel = _module_rel(raw_location);
        if not rel {
            return "";
        }
        known = self.sources();
        if rel in known {
            return known[rel];
        }
        name = _basename(rel);
        for key in sorted(known.keys()) {
            if _basename(key) == name {
                return known[key];
            }
        }
        return "";
    }

    def fallback_owner -> str {
        known = self.sources();
        for key in sorted(known.keys()) {
            if _basename(key) in ("_entry.js", "main.js", "index.js") {
                return known[key];
            }
        }
        toml = self.toml_path();
        if toml is not None {
            return str(toml);
        }
        return self.base_path;
    }

    def locate_compiled(
        module_id: str, line: int, column: int
    ) -> (SourceLocation | None) {
        rel = _module_rel(module_id);
        source_map = self._map_for(rel);
        if source_map is not None {
            loc = source_map.resolve(line, column);
            if loc is not None and loc.file.endswith(".jac") {
                return loc;
            }
            return None;
        }
        bundle = self._bundle();
        if bundle is not None {
            loc = bundle.resolve(line, column);
            if loc is not None and loc.file.endswith(".jac") {
                return loc;
            }
        }
        return None;
    }

    def _frame_target(line: str) -> (tuple[str, int, int] | None) {
        found = _STACK_PATTERN.search(line);
        if found {
            return (found.group(2), int(found.group(3)), int(found.group(4)));
        }
        found = _STACK_PATTERN_ANON.search(line);
        if found {
            return (found.group(1), int(found.group(2)), int(found.group(3)));
        }
        return None;
    }

    def locate_stack(stack: str) -> (SourceLocation | None) {
        for line in str(stack or "").split("\n") {
            target = self._frame_target(line);
            if target is None {
                continue;
            }
            loc = self.locate_compiled(target[0], target[1], target[2]);
            if loc is not None {
                return loc;
            }
        }
        return None;
    }

    def resolve_stack_trace(stack: str, verbose: bool = False) -> str {
        rendered: list[str] = [];
        mapped_any = False;
        for line in str(stack or "").split("\n") {
            target = self._frame_target(line);
            if target is None {
                rendered.append(line);
                continue;
            }
            loc = self.locate_compiled(target[0], target[1], target[2]);
            if loc is not None {
                mapped_any = True;
                found = _STACK_PATTERN.search(line);
                where = f"{self.relative(loc.file)}:{loc.line}:{loc.column}";
                if found {
                    rendered.append(f"    at {found.group(1)} ({where})");
                } else {
                    rendered.append(f"    at {where}");
                }
            } elif verbose {
                rendered.append(line);
            }
        }
        if not mapped_any and not verbose {
            return stack;
        }
        return "\n".join(rendered);
    }

    def locate_import(specifier: str, name: str = "") -> (SourceLocation | None) {
        wanted = _npm_specifier(specifier);
        if not wanted {
            return None;
        }
        owner_only: (SourceLocation | None) = None;
        known = self.sources();
        for rel in sorted(known.keys()) {
            text = self._js_text(rel);
            if not text {
                continue;
            }
            for found in _JS_IMPORT_RE.finditer(text) {
                if not _specifier_matches(found.group("spec"), wanted) {
                    continue;
                }
                offset = found.start();
                if name {
                    hit = re.search(
                        r"\b" + re.escape(name) + r"\b", found.group("clause")
                    );
                    if hit is None {
                        continue;
                    }
                    offset = found.start("clause") + hit.start();
                }
                (js_line, js_col) = _text_pos(text, offset);
                loc = self.locate_compiled(rel, js_line, js_col);
                if loc is not None {
                    return loc;
                }
                if owner_only is None {
                    owner_only = SourceLocation(file=known[rel], line=0, column=0);
                }
            }
        }
        return owner_only;
    }

    def importer_of(module_id: str, specifier: str) -> (SourceLocation | None) {
        rel = _module_rel(module_id);
        known = self.sources();
        if not rel or rel not in known {
            return self.locate_import(specifier);
        }
        wanted = _npm_specifier(specifier);
        text = self._js_text(rel);
        for pattern in (_JS_IMPORT_RE, _JS_BARE_IMPORT_RE) {
            for found in pattern.finditer(text) {
                if not _specifier_matches(found.group("spec"), wanted) {
                    continue;
                }
                (js_line, js_col) = _text_pos(text, found.start());
                loc = self.locate_compiled(rel, js_line, js_col);
                if loc is not None {
                    return loc;
                }
            }
        }
        return SourceLocation(file=known[rel], line=0, column=0);
    }

    def locate_npm_declaration(package: str) -> (tuple[SourceLocation, str] | None) {
        toml = self.toml_path();
        if toml is None or not toml.is_file() {
            return None;
        }
        try {
            lines = toml.read_text(encoding="utf-8").splitlines();
        } except (OSError, UnicodeDecodeError) {
            return None;
        }
        path = str(toml);
        header = -1;
        for (idx, raw) in enumerate(lines) {
            if raw.strip().replace(" ", "") == "[dependencies.npm]" {
                header = idx;
                break;
            }
        }
        if header < 0 {
            return (
                SourceLocation(file=path, line=0, column=0),
                f"jac.toml declares no [dependencies.npm] table, so '{package}' is not declared anywhere"
            );
        }
        cursor = header + 1;
        while cursor < len(lines) {
            stripped = lines[cursor].strip();
            if stripped.startswith("[") {
                break;
            }
            eq = stripped.find("=");
            if eq > 0 {
                raw_key = stripped[:eq].strip();
                if raw_key.strip("\"'") == package {
                    col = lines[cursor].find(raw_key) + 1;
                    return (SourceLocation(file=path, line=cursor + 1, column=col), "");
                }
            }
            cursor += 1;
        }
        return (
            SourceLocation(
                file=path, line=header + 1, column=lines[header].find("[") + 1
            ),
            f"'{package}' is not declared under [dependencies.npm]"
        );
    }
}
