"""Utility functions and classes for Jac compilation toolchain."""
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
import from typing { TYPE_CHECKING, get_args, get_origin }

with entry {
    if TYPE_CHECKING {
        import pluggy;
    }
}

"""Convert pascal case to snake case."""
@lru_cache(maxsize=256)
def pascal_to_snake(pascal_string: str) -> str {
    snake_string = re.sub('(?<!^)(?=[A-Z])', '_', pascal_string).lower();
    return snake_string;
}

"""Convert string to snakecase including replacing(/ ,- )."""
def heading_to_snake(heading: str) -> str {
    return heading.strip().replace('-', '_').replace('/', '_').replace(' ', '_').lower();
}

"""Add line numbers to a string."""
def add_line_numbers(s: str) -> str {
    lines = s.split('\n');
    return '\n'.join(f"{(i + 1)}:       {line}" for (i, line) in enumerate(lines));
}

"""Get all AST nodes as snake case."""
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
        key=lambda cls: Any : source_code.find(f"class {cls.__name__}")
    );
    snake_names = [];
    for cls in ordered_classes {
        class_name = cls.__name__;
        snake_names.append(pascal_to_snake(class_name));
    }
    return snake_names;
}

"""Dump the stack frames of the exception."""
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
            or ('/site-packages/pluggy/' in normalized)
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
                (frame.lineno is not None)
                and frame.line
                and (frame.line.strip() != '')
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
                        with open(frame.filename) as file {
                            file_source = file.read();
                        }
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

"""ANSI color codes."""
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

"""Pretty print internal method for the pretty_print method."""
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
    idx: int = pos_start;
    if ((file_source == '') or (file_path == '')) {
        return '';
    }
    start_line: int = error_line - 2;
    if (start_line < 1) {
        start_line = 1;
    }
    end_line: int = start_line + 5;
    file_source.splitlines(True)[(start_line - 1)];
    curr_line: int = error_line;
    while ((idx >= 0) and (curr_line >= start_line)) {
        idx -= 1;
        if (idx < 0) {
            break;
        }
        if (file_source[idx] == '\n') {
            curr_line -= 1;
        }
    }
    idx += 1;
    assert ((idx == 0) or (file_source[(idx - 1)] == '\n'));
    pretty_dump = '';
    curr_line = start_line;
    while (curr_line < end_line) {
        pretty_dump += f"%{line_num_width}d | " % curr_line;
        idx_line_start = idx;
        while ((idx < len(file_source)) and (file_source[idx] != '\n')) {
            idx += 1;
        }
        if (colors and (curr_line == error_line)) {
            pretty_dump += file_source[idx_line_start:pos_start] + f"{ANSIColors.RED}{file_source[pos_start:pos_end]}{ANSIColors.END}" + file_source[pos_end:idx];
        } else {
            pretty_dump += file_source[idx_line_start:idx];
        }
        pretty_dump += '\n';
        if (curr_line == error_line) {
            pretty_dump += f"%{line_num_width}s | " % ' ';
            spaces = '';
            for idx_pre in range(idx_line_start, pos_start) {
                spaces += '\t' if (file_source[idx_pre] == '\t') else ' ';
            }
            err_token_len = pos_end - pos_start;
            underline = '^' * err_token_len;
            if colors {
                underline = f"{ANSIColors.RED}{underline}{ANSIColors.END}";
            }
            pretty_dump += spaces + underline + '\n';
        }
        if (idx == len(file_source)) {
            break;
        }
        curr_line += 1;
        idx += 1;
    }
    return pretty_dump[:-1];
}

"""Jac debugger."""
class Jdb(pdb.Pdb) {
    """Initialize the Jac debugger."""
    def init(self: Jdb, *args: Any, **kwargs: Any) -> None {
        super.init(*args, **kwargs);
        self.prompt = 'Jdb > ';
    }

    """Check for breakpoint."""
    def has_breakpoint(self: Jdb, bytecode: bytes) -> bool {
        code = marshal.loads(bytecode);
        instructions = dis.get_instructions(code);
        return `any(
            (
                (instruction.opname in ('LOAD_GLOBAL', 'LOAD_NAME', 'LOAD_FAST'))
                and (instruction.argval == 'breakpoint')
            ) for instruction in instructions
        );
    }
}

glob debugger = Jdb();
"""Read file with proper encoding detection.

    Tries multiple encodings to handle files with different encodings.
    """
def read_file_with_encoding(file_path: str) -> str {
    encodings_to_try = ['utf-8-sig', 'utf-8', 'utf-16', 'utf-16le', 'utf-16be'];
    for encoding in encodings_to_try {
        try {
            with open(file_path, encoding=encoding) as f {
                return f.read();
            }
        } except UnicodeError {
            continue;
        } except Exception as e {
            raise OSError(
                f"Could not read file {file_path}: {e}. Report this issue: https://github.com/jaseci-labs/jaseci/issues"
            ) ;
        }
    }
    raise OSError(
        f"Could not read file {file_path} with any encoding. Report this issue:https://github.com/jaseci-labs/jaseci/issues"
    ) ;
}

"""Return a short, readable type name for annotations."""
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

"""Summarize function signature as (T1,T2)->R (drop param names/self)."""
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

"""Keep repr readable; avoids huge dumps while staying generic."""
def _safe_repr(v: object, limit: int = 120) -> str {
    s = repr(v);
    return s if (len(s) <= limit) else (s[:(limit - 1)] + '…');
}

"""Single-line description used for LLM routing."""
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

"""One object per line, index-friendly for returning list."""
def _describe_nodes_list(objects: Sequence) -> str {
    return '\n'.join(f"{i}) {_describe_node(obj)}" for (i, `obj) in enumerate(objects));
}

"""Minimal distribution facade for tracking plugin origins.

    Used when manually loading entry points to maintain compatibility
    with pluggy's list_plugin_distinfo() interface.
    """
class DistFacade {
    def init(self: DistFacade, dist: 'object | None') -> None {
        self._dist = dist;
    }

    """Get the distribution/package name."""
    @property
    def project_name(self: DistFacade) -> str {
        return self._dist.name if (self._dist and self._dist?.name) else 'unknown';
    }

    """Get the distribution version."""
    @property
    def version(self: DistFacade) -> str {
        return self._dist.version if (self._dist and self._dist?.version) else '0.0.0';
    }
}

"""Get list of disabled plugins from JAC_DISABLED_PLUGINS env var or jac.toml.

    Priority: JAC_DISABLED_PLUGINS env var > jac.toml
    Supports qualified names (package:plugin), short names, and "*" wildcard.

    Returns:
        List of disabled plugin identifiers.
    """
def get_disabled_plugins -> list {
    import from pathlib { Path }
    env_disabled = os.environ.get('JAC_DISABLED_PLUGINS', '').strip();
    if env_disabled {
        return [
            d.strip()
            for d in env_disabled.split(',')
            if d.strip()
        ];
    }
    try {
        import tomllib;
    } except ImportError {
        try {
            import tomli as tomllib;
        } except ImportError {
            return [];
        }
    }
    current = Path.cwd().resolve();
    while (current != current.parent) {
        toml_path = current / 'jac.toml';
        if toml_path.exists() {
            try {
                with open(toml_path, 'rb') as f {
                    data = tomllib.load(f);
                }
                return data.get('plugins', {}).get('disabled', []);
            } except Exception {
                return [];
            }
        }
        current = current.parent;
    }
    toml_path = current / 'jac.toml';
    if toml_path.exists() {
        try {
            with open(toml_path, 'rb') as f {
                data = tomllib.load(f);
            }
            return data.get('plugins', {}).get('disabled', []);
        } except Exception {
            ;
        }
    }
    return [];
}

"""Load setuptools entry points while respecting disabled plugin list.

    Supports:
    - "*" wildcard to disable all external plugins
    - Qualified names (package:plugin) for specific plugin disabling
    - Package wildcards (package:*) to disable all plugins from a package
    - Short names for backwards compatibility (affects all packages with that
name)

    This manually loads entry points to allow fine-grained control over which
    plugins are loaded when multiple packages have plugins with the same name.

    Args:
        plugin_manager: The pluggy PluginManager instance.
        disabled_list: List of plugin identifiers to disable.
    """
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
        } except Exception {
            ;
        }
    }
}
