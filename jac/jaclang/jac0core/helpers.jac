import dis;
import inspect;
import marshal;
import os;
import pdb;
import re;
import from collections.abc { Callable, Sequence }
import from dataclasses { fields, is_dataclass }
import from functools { lru_cache }
import from traceback { TracebackException }
import from typing { get_args, get_origin }
import type from jaclang { plugin as pluggy }

@lru_cache(maxsize=256)
def pascal_to_snake(pascal_string: str) -> str {
    snake_string = re.sub('(?<!^)(?=[A-Z])', '_', pascal_string).lower();
    return snake_string;
}

def heading_to_snake(heading: str) -> str {
    return heading.strip().replace('-', '_').replace('/', '_').replace(
        ' ', '_'
    ).lower();
}

def add_line_numbers(s: str) -> str {
    lines = s.split('\n');
    return '\n'.join(f"{(i + 1)}:       {line}" for (i, line) in enumerate(lines));
}

def get_uni_nodes_as_snake_case -> list {
    import inspect;
    import sys;
    import jaclang.jac0core.unitree as uni;
    module_name = uni.__name__;
    module = sys.modules[module_name];
    source_code = inspect.getsource(module);
    classes = inspect.getmembers(module, inspect.isclass);
    uni_node_classes = [
        cls
        for (_, cls) in classes
        if issubclass(cls, uni.UniNode)
    ];
    ordered_classes = sorted(
        uni_node_classes,
        key=lambda cls: any : source_code.find(f"class {cls.__name__}")
    );
    snake_names = [];
    for cls in ordered_classes {
        class_name = cls.__name__;
        snake_names.append(pascal_to_snake(class_name));
    }
    return snake_names;
}

def dump_traceback(e: Exception) -> str {
    trace_dump = '';
    def byte_offset_to_char_offset(string: str, offset: int) -> int {
        return len(string.encode('utf-8')[:offset].decode('utf-8', errors='replace'));
    }
    """Return (jac_filename, jac_source) if available, else (None, None).""";
    def get_jac_source_info(py_filename: str) -> tuple[((str | None), (str | None))] {
        return (None, None);
    }
    tb = TracebackException(`type(e), e, e.__traceback__, limit=None, compact=True);
    trace_dump += f"Error: {str(e)}\n";
    tb.stack.pop(0);
    tb.stack.reverse();
    dump_tab_width = 2;
    """Check if a frame is part of the Jac internal runtime.""";
    def is_internal_runtime_frame(filename: str) -> bool {
        normalized: str = filename.replace('\\', '/');
        return (
            ('/jaclang/runtimelib/' in normalized)
            or ('/jaclang/jac0core/' in normalized)
            or ('/jaclang/vendor/' in normalized)
            or ('/jaclang/plugin.py' in normalized)
            or normalized.endswith('/jaclang/meta_importer.py')
        );
    }
    seen_runtime_marker: bool = False;
    collapse_internal: bool = True;
    for (idx, frame) in enumerate(tb.stack) {
        is_internal: bool = is_internal_runtime_frame(frame.filename);
        if (is_internal and collapse_internal) {
            if not seen_runtime_marker {
                trace_dump += f"\n{(' ' * dump_tab_width)}... [internal runtime calls]";
                seen_runtime_marker = True;
            }
            continue;
        }
        seen_runtime_marker = False;
        func_signature: str = frame.name + ('()' if frame.name.isidentifier() else '');
        (jac_filename, jac_source) = get_jac_source_info(frame.filename);
        display_filename: str = jac_filename or frame.filename;
        display_source: (str | None) = jac_source;
        if (
            (idx == 0)
            and (
                (frame.lineno is not None) and frame.line and (frame.line.strip() != '')
            )
        ) {
            line_o = frame.line;
            if frame?._original_line {
                line_o = frame._original_line.rstrip();
            } elif frame?._original_lines {
                line_o = frame._original_lines.split('\n')[0].rstrip();
            }
            if ((frame.colno is not None) and (frame.end_colno is not None)) {
                off_start = byte_offset_to_char_offset(line_o, frame.colno) - 1;
                off_end = byte_offset_to_char_offset(line_o, frame.end_colno) - 1;
                file_source = display_source;
                if (file_source is None) {
                    try {
                        file_source = read_file_with_encoding(frame.filename);
                    } except Exception {
                        file_source = '';
                    }
                }
                if file_source {
                    lines = file_source.split('\n');
                    for i in range((frame.lineno - 1)) {
                        off_start += len(lines[i]) + 1;
                        off_end += len(lines[i]) + 1;
                    }
                    trace_dump += pretty_print_source_location(
                        display_filename, file_source, frame.lineno, off_start, off_end
                    );
                }
            }
        }
        trace_dump += f"\n{(' ' * dump_tab_width)}at {func_signature} {display_filename}:{frame.lineno}";
    }
    return trace_dump;
}

class ANSIColors {
    with entry {
        BLACK = '\x1b[0;30m';
        RED = '\x1b[0;31m';
        GREEN = '\x1b[0;32m';
        BROWN = '\x1b[0;33m';
        BLUE = '\x1b[0;34m';
        PURPLE = '\x1b[0;35m';
        CYAN = '\x1b[0;36m';
        LIGHT_GRAY = '\x1b[0;37m';
        DARK_GRAY = '\x1b[1;30m';
        LIGHT_RED = '\x1b[1;31m';
        LIGHT_GREEN = '\x1b[1;32m';
        YELLOW = '\x1b[1;33m';
        LIGHT_BLUE = '\x1b[1;34m';
        LIGHT_PURPLE = '\x1b[1;35m';
        LIGHT_CYAN = '\x1b[1;36m';
        LIGHT_WHITE = '\x1b[1;37m';
        BOLD = '\x1b[1m';
        FAINT = '\x1b[2m';
        ITALIC = '\x1b[3m';
        UNDERLINE = '\x1b[4m';
        BLINK = '\x1b[5m';
        NEGATIVE = '\x1b[7m';
        CROSSED = '\x1b[9m';
        END = '\x1b[0m';
    }
}

def pretty_print_source_location(
    file_path: str,
    file_source: str,
    error_line: int,
    pos_start: int,
    pos_end: int,
    *,
    colors: bool = False
) -> str {
    line_num_width: int = 5;
    if ((file_source == '') or (file_path == '')) {
        return '';
    }

    fb = file_source.encode("utf-8");
    flen: int = len(fb);
    NL: int = 10;
    idx: int = pos_start;
    if (idx > flen) {
        idx = flen;
    }
    start_line: int = error_line - 2;
    if (start_line < 1) {
        start_line = 1;
    }
    end_line: int = start_line + 5;
    curr_line: int = error_line;
    while ((idx >= 0) and (curr_line >= start_line)) {
        idx -= 1;
        if (idx < 0) {
            break;
        }
        if (fb[idx] == NL) {
            curr_line -= 1;
        }
    }
    idx += 1;
    pretty_dump = '';
    curr_line = start_line;
    while (curr_line < end_line) {
        pretty_dump += f"%{line_num_width}d | " % curr_line;
        idx_line_start = idx;
        while ((idx < flen) and (fb[idx] != NL)) {
            idx += 1;
        }
        if (colors and (curr_line == error_line)) {
            pre = fb[idx_line_start:pos_start].decode("utf-8", errors="replace");
            mid = fb[pos_start:pos_end].decode("utf-8", errors="replace");
            post = fb[pos_end:idx].decode("utf-8", errors="replace");
            pretty_dump += pre + f"{ANSIColors.RED}{mid}{ANSIColors.END}" + post;
        } else {
            pretty_dump += fb[idx_line_start:idx].decode("utf-8", errors="replace");
        }
        pretty_dump += '\n';
        if (curr_line == error_line) {
            pretty_dump += f"%{line_num_width}s | " % ' ';

            prefix = fb[idx_line_start:pos_start].decode("utf-8", errors="replace");
            spaces = '';
            for ch in prefix {
                spaces += '\t' if (ch == '\t') else ' ';
            }
            err_token_len = len(
                fb[pos_start:pos_end].decode("utf-8", errors="replace")
            );
            line_remaining = len(fb[pos_start:idx].decode("utf-8", errors="replace"));
            if (line_remaining > 0 and err_token_len > line_remaining) {
                err_token_len = line_remaining;
            }
            if (err_token_len < 1) {
                err_token_len = 1;
            }
            underline = '^' * err_token_len;
            if colors {
                underline = f"{ANSIColors.RED}{underline}{ANSIColors.END}";
            }
            pretty_dump += spaces + underline + '\n';
        }
        if (idx == flen) {
            break;
        }
        curr_line += 1;
        idx += 1;
    }
    return pretty_dump[:-1];
}

def format_related_spans(
    related: list[tuple[str, object]], *, colors: bool = False
) -> str {
    result = '';
    for (label, loc) in related {
        mod_path = loc.mod_path;
        first_line = loc.first_line;
        col_start = loc.col_start;
        if colors {
            result += f"\n{ANSIColors.CYAN}note{ANSIColors.END}: {label}";
        } else {
            result += f"\nnote: {label}";
        }
        if (mod_path != '') {
            result += f"\n  --> {mod_path}:{first_line}:{col_start}";
            try {
                source = loc.orig_src.code;
                span_dump = pretty_print_source_location(
                    mod_path,
                    source,
                    first_line,
                    loc.pos_start,
                    loc.pos_end,
                    colors=colors
                );
                if (span_dump != '') {
                    result += '\n' + span_dump;
                }
            } except Exception {
                ;
            }
        }
    }
    return result;
}

class Jdb(pdb.Pdb) {
    def init(self: Jdb, *args: any, **kwargs: any) -> None;
    def has_breakpoint(self: Jdb, bytecode: bytes) -> bool;
}

glob debugger = Jdb(),
     _JAC_TEXT_ENCODINGS = ['utf-8-sig', 'utf-8', 'utf-16', 'utf-16le', 'utf-16be'];

def read_file_with_encoding(file_path: str) -> str {
    for encoding in _JAC_TEXT_ENCODINGS {
        try {
            with open(file_path, encoding=encoding) as f {
                return f.read();
            }
        } except UnicodeError {
            continue;
        } except Exception as e {
            raise OSError(
                f"Could not read file {file_path}: {e}. Report this issue: https://github.com/jaseci-labs/jaseci/issues"
            );
        }
    }
    raise OSError(
        f"Could not read file {file_path} with any encoding. Report this issue:https://github.com/jaseci-labs/jaseci/issues"
    );
}

import tomllib;

class MalformedJacTomlError(tomllib.TOMLDecodeError) {
    has file_path: str,
        original: tomllib.TOMLDecodeError;

    def init(
        self: MalformedJacTomlError, file_path: str, original: tomllib.TOMLDecodeError
    ) {
        msg = f"jac.toml is malformed at {file_path}: {original}";
        if hasattr(original, "doc") and hasattr(original, "pos") {
            tomllib.TOMLDecodeError.__init__(
                self, msg, getattr(original, "doc"), getattr(original, "pos")
            );
        } else {
            tomllib.TOMLDecodeError.__init__(self, msg);
        }
        self.file_path = file_path;
        self.original = original;
    }
}


def read_toml_with_encoding(file_path: str) -> dict {
    try {
        return tomllib.loads(read_file_with_encoding(file_path));
    } except tomllib.TOMLDecodeError as exc {
        raise MalformedJacTomlError(file_path, exc);
    }
}

def _short_type_name(t: object) -> str {
    if (t is inspect._empty) {
        return 'Any';
    }
    origin = get_origin(t);
    if (origin is not None) {
        name = getattr(origin, '__name__', str(origin).replace('typing.', ''));
        args = get_args(t);
        if not args {
            return name;
        }
        return f"{name}[{','.join(_short_type_name(a) for a in args)}]";
    }
    return getattr(t, '__name__', str(t).replace('typing.', ''));
}

def _signature_summary(func: Callable) -> str {
    try {
        sig = inspect.signature(func);
    } except (TypeError, ValueError) {
        return '';
    }
    params: list = [];
    for p in sig.parameters.values() {
        if (p.name == 'self') {
            continue;
        }
        params.append(_short_type_name(p.annotation));
    }
    ret = _short_type_name(sig.return_annotation);
    return f"({','.join(params)})->{ret}";
}

def _safe_repr(v: object, limit: int = 120) -> str {
    s = repr(v);
    return s if (len(s) <= limit) else (s[:(limit - 1)] + '…');
}

def _describe_node(`obj: object) -> str {
    cls = `obj.__class__;
    attrs: list = [];
    if is_dataclass(`obj) {
        for f in fields(`obj) {
            attrs.append(f"{f.name}={_safe_repr(getattr(obj, f.name))}");
        }
    } else {
        for (k, v) in vars(`obj).items() {
            if k.startswith('_') {
                continue;
            }
            attrs.append(f"{k}={_safe_repr(v)}");
        }
    }
    methods: list = [];
    for (m_name, func) in inspect.getmembers(cls, predicate=inspect.isfunction) {
        if m_name.startswith('__') {
            continue;
        }
        sig = _signature_summary(func);
        methods.append(f"{m_name}{sig}" if sig else m_name);
    }
    parts = [cls.__name__];
    if attrs {
        parts.append(('attrs:' + ','.join(attrs)));
    }
    if methods {
        parts.append(('methods:' + ','.join(methods)));
    }
    return ' — '.join(parts);
}

def _describe_nodes_list(objects: Sequence) -> str {
    return '\n'.join(f"{i}) {_describe_node(obj)}" for (i, `obj) in enumerate(objects));
}

obj DistFacade {
    has _dist: (object | None);
    has project_name: str { getter; }
    has version: str { getter; }
}

def _warn_malformed_jac_toml(exc: MalformedJacTomlError) {
    import sys;
    sys.stderr.write(
        f"warning: jac.toml is malformed ({exc.file_path}): {exc.original}; "
        "ignoring [plugins].disabled. "
        "Run a `jac` CLI command for the actionable error.\n"
    );
}


def path_matches_exclude(
    file_path: str, patterns: list, project_root: str = ""
) -> bool {
    import from fnmatch { fnmatch }
    if not patterns {
        return False;
    }
    norm = file_path.replace(os.sep, '/');
    if project_root {
        root_prefix = project_root.replace(os.sep, '/').rstrip('/') + '/';
        if norm.startswith(root_prefix) {
            norm = norm[len(root_prefix):];
        }
    }
    parts = [
        p
        for p in norm.split('/')
        if p
    ];
    for pattern in patterns {
        if '/' in pattern {
            if fnmatch(norm, pattern)
            or fnmatch(norm, '*/' + pattern)
            or fnmatch('_/' + norm, pattern) {
                return True;
            }
        } else {
            for part in parts {
                if fnmatch(part, pattern) {
                    return True;
                }
            }
        }
    }
    return False;
}


def get_disabled_plugins -> list {
    env_disabled = os.environ.get('JAC_DISABLED_PLUGINS', '').strip();
    if env_disabled {
        return [
            d.strip()
            for d in env_disabled.split(',')
            if d.strip()
        ];
    }

    import from jaclang.jac0core.modresolver { find_project_root }
    result = find_project_root();
    if result is None {
        return [];
    }
    (_, toml_path) = result;
    try {
        data = read_toml_with_encoding(str(toml_path));
        return data.get('plugins', {}).get('disabled', []);
    } except MalformedJacTomlError as exc {
        _warn_malformed_jac_toml(exc);
        return [];
    } except Exception {
        return [];
    }
}

def load_plugins_with_disabling(
    plugin_manager: 'pluggy.PluginManager', disabled_list: list
) -> None {
    import from importlib.metadata { entry_points }
    disable_all = '*' in disabled_list;
    disabled_qualified: set = `set();
    disabled_packages: set = `set();
    disabled_short: set = `set();
    for name in disabled_list {
        if (name == '*') {
            continue;
        } elif name.endswith(':*') {
            disabled_packages.add(name[:-2]);
        } elif (':' in name) {
            disabled_qualified.add(name);
        } else {
            disabled_short.add(name);
        }
    }
    if disable_all {
        return;
    }
    try {
        eps = entry_points(group='jac');
    } except TypeError {
        all_eps = entry_points();
        eps = all_eps.get('jac', []);
    }
    for ep in eps {
        try {
            dist = ep.dist;
            dist_name = dist.name if dist else 'unknown';
        } except Exception {
            dist = None;
            dist_name = 'unknown';
        }
        qualified_name = f"{dist_name}:{ep.name}";
        should_disable = False;
        if (dist_name in disabled_packages) {
            should_disable = True;
        } elif (qualified_name in disabled_qualified) {
            should_disable = True;
        } elif (ep.name in disabled_short) {
            should_disable = True;
        }
        if should_disable {
            continue;
        }
        try {
            plugin = ep.load();
            if plugin_manager.is_registered(plugin) {
                continue;
            }
            plugin_manager.register(plugin, name=ep.name);
            plugin_manager._plugin_distinfo.append((plugin, DistFacade(dist)));
        } except Exception as exc {
            import sys;
            if isinstance(exc, MalformedJacTomlError) {
                sys.stderr.write(
                    f"warning: plugin '{qualified_name}' failed to load -- "
                    "jac.toml parse failure (see warning above).\n"
                );
            } elif isinstance(exc, ModuleNotFoundError) and exc?.name {
                detail = f"missing dependency '{exc.name}'";
                sys.stderr.write(
                    f"warning: plugin '{qualified_name}' failed to load -- "
                    f"{detail}. Install the missing package, or disable this "
                    "plugin via JAC_DISABLED_PLUGINS / [plugins].disabled in "
                    "jac.toml.\n"
                );
            } else {
                cause = type(exc).__name__;
                detail = f"{cause}: {exc}";
                sys.stderr.write(
                    f"warning: plugin '{qualified_name}' failed to load -- "
                    f"{detail}. Install the missing package, or disable this "
                    "plugin via JAC_DISABLED_PLUGINS / [plugins].disabled in "
                    "jac.toml.\n"
                );
            }
        }
    }
}

def _is_version_info_access(expr: 'uni.Expr') -> bool {
    import jaclang.jac0core.unitree as uni;

    if not isinstance(expr, uni.AtomTrailer) {
        return False;
    }
    if not expr.is_attr {
        return False;
    }
    return (
        isinstance(expr.target, uni.Name)
        and expr.target.value == "sys"
        and isinstance(expr.right, uni.Name)
        and expr.right.value == "version_info"
    );
}

def _is_type_checking_ref(expr: 'uni.Expr') -> bool {
    import jaclang.jac0core.unitree as uni;

    if isinstance(expr, uni.AtomUnit) {
        expr = expr.value;
    }
    if isinstance(expr, uni.Name) {
        return expr.value == "TYPE_CHECKING";
    }
    if isinstance(expr, uni.AtomTrailer) and expr.is_attr {
        return (
            isinstance(expr.right, uni.Name) and expr.right.value == "TYPE_CHECKING"
        );
    }
    return False;
}

def _extract_version_tuple(expr: 'uni.Expr') -> tuple[int, int] | None {
    import jaclang.jac0core.unitree as uni;

    if not isinstance(expr, uni.TupleVal) {
        return None;
    }
    if len(expr.values) < 2 {
        return None;
    }
    (major, minor) = (expr.values[0], expr.values[1]);
    if not isinstance(major, uni.Int) or not isinstance(minor, uni.Int) {
        return None;
    }
    return (major.lit_value, minor.lit_value);
}

def evaluate_version_condition(condition: 'uni.Expr') -> bool | None {
    import sys;
    import operator;
    import jaclang.jac0core.unitree as uni;
    import from jaclang.jac0core.constant { Tokens as Tok }

    cond = condition;
    if isinstance(cond, uni.AtomUnit) {
        cond = cond.value;
    }

    if _is_type_checking_ref(cond) {
        return True;
    }
    if isinstance(cond, uni.UnaryExpr)
    and cond.op.name == Tok.NOT
    and _is_type_checking_ref(cond.operand) {
        return False;
    }
    if not isinstance(cond, uni.CompareExpr) {
        return None;
    }
    if not _is_version_info_access(cond.left) {
        return None;
    }
    if len(cond.ops) != 1 or len(cond.rights) != 1 {
        return None;
    }

    target = _extract_version_tuple(cond.rights[0]);
    if target is None {
        return None;
    }

    current = (sys.version_info.major, sys.version_info.minor);
    op_map: dict = {
        ">=": operator.ge,
        "GtE": operator.ge,
        ">": operator.gt,
        "Gt": operator.gt,
        "<=": operator.le,
        "LtE": operator.le,
        "<": operator.lt,
        "Lt": operator.lt,
        "==": operator.eq,
        "Eq": operator.eq,
        "!=": operator.ne,
        "NotEq": operator.ne
    };

    op_str = cond.ops[0].value;
    return op_map[op_str](current, target) if op_str in op_map else None;
}
