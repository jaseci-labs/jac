"""Utility functions and classes for Jac compilation toolchain."""

import dis
import inspect
import marshal
import os
import pdb
import re
from collections.abc import Callable, Sequence
from dataclasses import fields, is_dataclass
from functools import lru_cache
from traceback import TracebackException
from typing import TYPE_CHECKING, get_args, get_origin

if TYPE_CHECKING:
    import pluggy


@lru_cache(maxsize=256)
def pascal_to_snake(pascal_string: str) -> str:
    """Convert pascal case to snake case."""
    snake_string = re.sub(r"(?<!^)(?=[A-Z])", "_", pascal_string).lower()
    return snake_string


def heading_to_snake(heading: str) -> str:
    """Convert string to snakecase including replacing(/ ,- )."""
    return heading.strip().replace("-", "_").replace("/", "_").replace(" ", "_").lower()


def add_line_numbers(s: str) -> str:
    """Add line numbers to a string."""
    lines = s.split("\n")
    return "\n".join(f"{i + 1}: \t{line}" for i, line in enumerate(lines))


def get_uni_nodes_as_snake_case() -> list[str]:
    """Get all AST nodes as snake case."""
    import inspect
    import sys

    import jaclang.pycore.unitree as uni

    module_name = uni.__name__
    module = sys.modules[module_name]

    # Retrieve the source code of the module
    source_code = inspect.getsource(module)

    classes = inspect.getmembers(module, inspect.isclass)
    uni_node_classes = [cls for _, cls in classes if issubclass(cls, uni.UniNode)]

    ordered_classes = sorted(
        uni_node_classes, key=lambda cls: source_code.find(f"class {cls.__name__}")
    )
    snake_names = []
    for cls in ordered_classes:
        class_name = cls.__name__
        snake_names.append(pascal_to_snake(class_name))
    return snake_names


def dump_traceback(e: Exception) -> str:
    """Dump the stack frames of the exception."""
    trace_dump = ""

    # Utility function to get the error line char offset.
    def byte_offset_to_char_offset(string: str, offset: int) -> int:
        return len(string.encode("utf-8")[:offset].decode("utf-8", errors="replace"))

    # Utility function to check if a file is a compiled Jac file and get the original .jac source
    def get_jac_source_info(py_filename: str) -> tuple[str | None, str | None]:
        """Return (jac_filename, jac_source) if available, else (None, None)."""
        # Currently no mapping from Python to Jac source files is available
        return None, None

    tb = TracebackException(type(e), e, e.__traceback__, limit=None, compact=True)
    trace_dump += f"Error: {str(e)}\n"

    # The first frame is the call the to the above `exec` function, not usefull to the enduser,
    # and Make the most recent call first.
    tb.stack.pop(0)
    tb.stack.reverse()

    # FIXME: should be some settings, we should replace to ensure the anchors length match.
    dump_tab_width = 2

    # Helper function to check if a frame is part of the internal runtime
    def is_internal_runtime_frame(filename: str) -> bool:
        """Check if a frame is part of the Jac internal runtime."""
        normalized: str = filename.replace("\\", "/")
        return (
            "/jaclang/runtimelib/" in normalized
            or "/jaclang/pycore/" in normalized
            or "/jaclang/vendor/" in normalized
            or "/site-packages/pluggy/" in normalized
            or normalized.endswith("/jaclang/meta_importer.py")
        )

    # Process and print frames, collapsing consecutive internal runtime calls
    seen_runtime_marker: bool = False
    collapse_internal: bool = True

    for idx, frame in enumerate(tb.stack):
        is_internal: bool = is_internal_runtime_frame(frame.filename)

        # Collapse consecutive internal runtime frames into a single marker (if enabled)
        if is_internal and collapse_internal:
            if not seen_runtime_marker:
                trace_dump += f"\n{' ' * dump_tab_width}... [internal runtime calls]"
                seen_runtime_marker = True
            continue

        # Reset the marker flag when we hit a user frame
        seen_runtime_marker = False

        func_signature: str = frame.name + ("()" if frame.name.isidentifier() else "")

        # Check if we can map this to a .jac file
        jac_filename, jac_source = get_jac_source_info(frame.filename)
        display_filename: str = jac_filename if jac_filename else frame.filename
        display_source: str | None = jac_source if jac_source else None

        # Pretty print the most recent call's location.
        if idx == 0 and (
            (frame.lineno is not None) and frame.line and frame.line.strip() != ""
        ):
            # Note: This is CPython internals we're trying to get since python doesn't provide
            # the frames original line but the stripped version so we had to do this.
            line_o = frame.line  # Fallback line.
            if hasattr(frame, "_original_line"):
                line_o = frame._original_line.rstrip()  # type: ignore [attr-defined]
            elif hasattr(frame, "_original_lines"):
                # https://github.com/python/cpython/issues/106922
                line_o = frame._original_lines.split("\n")[0].rstrip()  # type: ignore [attr-defined]

            if frame.colno is not None and frame.end_colno is not None:
                off_start = byte_offset_to_char_offset(line_o, frame.colno) - 1
                off_end = byte_offset_to_char_offset(line_o, frame.end_colno) - 1

                # Get the source - prefer .jac source if available, otherwise use .py
                file_source = display_source
                if file_source is None:
                    try:
                        with open(frame.filename) as file:
                            file_source = file.read()
                    except Exception:
                        file_source = ""

                if file_source:
                    # Get the source offset.
                    lines = file_source.split("\n")
                    for i in range(frame.lineno - 1):
                        off_start += len(lines[i]) + 1
                        off_end += len(lines[i]) + 1

                    trace_dump += pretty_print_source_location(
                        display_filename, file_source, frame.lineno, off_start, off_end
                    )

        trace_dump += f"\n{' ' * dump_tab_width}at {func_signature} {display_filename}:{frame.lineno}"

    return trace_dump


# FIXME: Use a proper color library and/or move this somewhere common to jac stack and use it everywhere.
# Reference: https://gist.github.com/rene-d/9e584a7dd2935d0f461904b9f2950007
class ANSIColors:
    """ANSI color codes."""

    BLACK = "\033[0;30m"
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    BROWN = "\033[0;33m"
    BLUE = "\033[0;34m"
    PURPLE = "\033[0;35m"
    CYAN = "\033[0;36m"
    LIGHT_GRAY = "\033[0;37m"
    DARK_GRAY = "\033[1;30m"
    LIGHT_RED = "\033[1;31m"
    LIGHT_GREEN = "\033[1;32m"
    YELLOW = "\033[1;33m"
    LIGHT_BLUE = "\033[1;34m"
    LIGHT_PURPLE = "\033[1;35m"
    LIGHT_CYAN = "\033[1;36m"
    LIGHT_WHITE = "\033[1;37m"
    BOLD = "\033[1m"
    FAINT = "\033[2m"
    ITALIC = "\033[3m"
    UNDERLINE = "\033[4m"
    BLINK = "\033[5m"
    NEGATIVE = "\033[7m"
    CROSSED = "\033[9m"
    END = "\033[0m"


# TODO: After implementing the TextRange (or simillar named) class to mark a text range
# refactor the parameter to accept an instace of that text range object.
def pretty_print_source_location(
    file_path: str,
    file_source: str,
    error_line: int,
    pos_start: int,
    pos_end: int,
    *,
    colors: bool = False,
) -> str:
    """Pretty print internal method for the pretty_print method."""
    # NOTE: The Line numbers and the column numbers are starts with 1.
    # We print totally 5 lines (error line and above 2 and bellow 2).

    # The width of the line number we'll be printing (more of a settings).
    line_num_width: int = 5

    idx: int = pos_start  # Pointer for the current character.

    if file_source == "" or file_path == "":
        return ""

    start_line: int = error_line - 2
    if start_line < 1:
        start_line = 1
    end_line: int = start_line + 5  # Index is exclusive.

    # Get the first character of the [start_line].
    file_source.splitlines(True)[start_line - 1]
    curr_line: int = error_line
    while idx >= 0 and curr_line >= start_line:
        idx -= 1
        if idx < 0:
            break
        if file_source[idx] == "\n":
            curr_line -= 1

    idx += 1  # Enter the line.
    assert idx == 0 or file_source[idx - 1] == "\n"

    pretty_dump = ""

    # Print each lines.
    curr_line = start_line
    while curr_line < end_line:
        pretty_dump += f"%{line_num_width}d | " % curr_line

        idx_line_start = idx
        while idx < len(file_source) and file_source[idx] != "\n":
            idx += 1  # Run to the line end.

        if colors and (curr_line == error_line):
            pretty_dump += (
                file_source[idx_line_start:pos_start]
                + f"{ANSIColors.RED}{file_source[pos_start:pos_end]}{ANSIColors.END}"
                + file_source[pos_end:idx]
            )
        else:
            pretty_dump += file_source[idx_line_start:idx]

        pretty_dump += "\n"

        if curr_line == error_line:  # Print the current line with indicator.
            pretty_dump += f"%{line_num_width}s | " % " "

            spaces = ""
            for idx_pre in range(idx_line_start, pos_start):
                spaces += "\t" if file_source[idx_pre] == "\t" else " "

            err_token_len = pos_end - pos_start
            underline = "^" * err_token_len
            if colors:
                underline = f"{ANSIColors.RED}{underline}{ANSIColors.END}"
            pretty_dump += spaces + underline + "\n"

        if idx == len(file_source):
            break
        curr_line += 1
        idx += 1

    return pretty_dump[:-1]  # Get rid of the last newline (of the last line).


class Jdb(pdb.Pdb):
    """Jac debugger."""

    def __init__(self, *args, **kwargs) -> None:  # noqa
        """Initialize the Jac debugger."""
        super().__init__(*args, **kwargs)
        self.prompt = "Jdb > "

    def has_breakpoint(self, bytecode: bytes) -> bool:
        """Check for breakpoint."""
        code = marshal.loads(bytecode)
        instructions = dis.get_instructions(code)
        return any(
            instruction.opname in ("LOAD_GLOBAL", "LOAD_NAME", "LOAD_FAST")
            and instruction.argval == "breakpoint"
            for instruction in instructions
        )


debugger = Jdb()


def read_file_with_encoding(file_path: str) -> str:
    """Read file with proper encoding detection.

    Tries multiple encodings to handle files with different encodings.
    """
    encodings_to_try = [
        "utf-8-sig",
        "utf-8",
        "utf-16",
        "utf-16le",
        "utf-16be",
    ]

    for encoding in encodings_to_try:
        try:
            with open(file_path, encoding=encoding) as f:
                return f.read()
        except UnicodeError:
            continue
        except Exception as e:
            raise OSError(
                f"Could not read file {file_path}: {e}. "
                f"Report this issue: https://github.com/jaseci-labs/jaseci/issues"
            ) from e

    raise OSError(
        f"Could not read file {file_path} with any encoding. "
        f"Report this issue: https://github.com/jaseci-labs/jaseci/issues"
    )


def _short_type_name(t: object) -> str:
    """Return a short, readable type name for annotations."""
    if t is inspect._empty:
        return "Any"

    origin = get_origin(t)
    if origin is not None:
        name = getattr(origin, "__name__", str(origin).replace("typing.", ""))
        args = get_args(t)
        if not args:
            return name
        return f"{name}[{','.join(_short_type_name(a) for a in args)}]"

    return getattr(t, "__name__", str(t).replace("typing.", ""))


def _signature_summary(func: Callable) -> str:
    """Summarize function signature as (T1,T2)->R (drop param names/self)."""
    try:
        sig = inspect.signature(func)
    except (TypeError, ValueError):
        return ""

    params: list[str] = []
    for p in sig.parameters.values():
        if p.name == "self":
            continue
        params.append(_short_type_name(p.annotation))

    ret = _short_type_name(sig.return_annotation)
    return f"({','.join(params)})->{ret}"


def _safe_repr(v: object, limit: int = 120) -> str:
    """Keep repr readable; avoids huge dumps while staying generic."""
    s = repr(v)
    return s if len(s) <= limit else s[: limit - 1] + "…"


def _describe_node(obj: object) -> str:
    """Single-line description used for LLM routing."""
    cls = obj.__class__

    # Attributes
    attrs: list[str] = []
    if is_dataclass(obj):
        for f in fields(obj):
            attrs.append(f"{f.name}={_safe_repr(getattr(obj, f.name))}")
    else:
        for k, v in vars(obj).items():
            if k.startswith("_"):
                continue
            attrs.append(f"{k}={_safe_repr(v)}")

    # Methods
    methods: list[str] = []
    for m_name, func in inspect.getmembers(cls, predicate=inspect.isfunction):
        if m_name.startswith("__"):
            continue
        sig = _signature_summary(func)
        methods.append(f"{m_name}{sig}" if sig else m_name)

    parts = [cls.__name__]
    if attrs:
        parts.append("attrs:" + ",".join(attrs))
    if methods:
        parts.append("methods:" + ",".join(methods))
    return " — ".join(parts)


def _describe_nodes_list(objects: Sequence[object]) -> str:
    """One object per line, index-friendly for returning list[int]."""
    return "\n".join(f"{i}) {_describe_node(obj)}" for i, obj in enumerate(objects))


# =============================================================================
# Plugin Loading Helpers
# =============================================================================


class DistFacade:
    """Minimal distribution facade for tracking plugin origins.

    Used when manually loading entry points to maintain compatibility
    with pluggy's list_plugin_distinfo() interface.
    """

    def __init__(self, dist: "object | None") -> None:
        self._dist = dist

    @property
    def project_name(self) -> str:
        """Get the distribution/package name."""
        return (
            self._dist.name if self._dist and hasattr(self._dist, "name") else "unknown"
        )

    @property
    def version(self) -> str:
        """Get the distribution version."""
        return (
            self._dist.version
            if self._dist and hasattr(self._dist, "version")
            else "0.0.0"
        )


def get_disabled_plugins() -> list[str]:
    """Get list of disabled plugins from JAC_DISABLED_PLUGINS env var or jac.toml.

    Priority: JAC_DISABLED_PLUGINS env var > jac.toml
    Supports qualified names (package:plugin), short names, and "*" wildcard.

    Returns:
        List of disabled plugin identifiers.
    """
    from pathlib import Path

    # First check environment variable (takes precedence)
    env_disabled = os.environ.get("JAC_DISABLED_PLUGINS", "").strip()
    if env_disabled:
        # Support comma-separated list or single value
        return [d.strip() for d in env_disabled.split(",") if d.strip()]

    # Fall back to jac.toml
    try:
        import tomllib
    except ImportError:
        # Python < 3.11 fallback
        try:
            import tomli as tomllib  # type: ignore
        except ImportError:
            return []

    # Search for jac.toml starting from current directory
    current = Path.cwd().resolve()
    while current != current.parent:
        toml_path = current / "jac.toml"
        if toml_path.exists():
            try:
                with open(toml_path, "rb") as f:
                    data = tomllib.load(f)
                return data.get("plugins", {}).get("disabled", [])
            except Exception:
                return []
        current = current.parent
    # Check root
    toml_path = current / "jac.toml"
    if toml_path.exists():
        try:
            with open(toml_path, "rb") as f:
                data = tomllib.load(f)
            return data.get("plugins", {}).get("disabled", [])
        except Exception:
            pass
    return []


def load_plugins_with_disabling(
    plugin_manager: "pluggy.PluginManager", disabled_list: list[str]
) -> None:
    """Load setuptools entry points while respecting disabled plugin list.

    Supports:
    - "*" wildcard to disable all external plugins
    - Qualified names (package:plugin) for specific plugin disabling
    - Package wildcards (package:*) to disable all plugins from a package
    - Short names for backwards compatibility (affects all packages with that name)

    This manually loads entry points to allow fine-grained control over which
    plugins are loaded when multiple packages have plugins with the same name.

    Args:
        plugin_manager: The pluggy PluginManager instance.
        disabled_list: List of plugin identifiers to disable.
    """
    from importlib.metadata import entry_points

    # Check for wildcard - disable all external plugins
    disable_all = "*" in disabled_list

    # Parse disabled list into qualified and short name sets
    disabled_qualified: set[str] = set()  # package:plugin format
    disabled_packages: set[str] = set()  # package:* format (all plugins from package)
    disabled_short: set[str] = set()  # legacy short names

    for name in disabled_list:
        if name == "*":
            continue  # Already handled above
        elif name.endswith(":*"):
            # Package wildcard: disable all plugins from this package
            disabled_packages.add(name[:-2])  # Remove ":*"
        elif ":" in name:
            disabled_qualified.add(name)
        else:
            disabled_short.add(name)

    # If disable_all, don't load any external plugins
    if disable_all:
        return

    # Get entry points for the "jac" group
    try:
        # Python 3.10+
        eps = entry_points(group="jac")
    except TypeError:
        # Python 3.9 fallback - entry_points() returns dict-like SelectableGroups
        all_eps = entry_points()
        eps = all_eps.get("jac", [])  # type: ignore[attr-defined]

    # Manually load each entry point, skipping disabled ones
    for ep in eps:
        # Get the distribution (package) this entry point comes from
        try:
            dist = ep.dist
            dist_name = dist.name if dist else "unknown"
        except Exception:
            dist = None
            dist_name = "unknown"

        qualified_name = f"{dist_name}:{ep.name}"

        # Check if this specific plugin should be disabled
        should_disable = False
        if dist_name in disabled_packages:
            # Package wildcard match
            should_disable = True
        elif qualified_name in disabled_qualified:
            should_disable = True
        elif ep.name in disabled_short:
            # Legacy: short name matches (affects all packages with this name)
            should_disable = True

        if should_disable:
            # Skip this plugin entirely
            continue

        # Load and register the plugin
        try:
            plugin = ep.load()
            # Check if already registered (another package with same name)
            if plugin_manager.is_registered(plugin):
                continue
            plugin_manager.register(plugin, name=ep.name)
            # Track distribution info for list_plugin_distinfo() to work
            plugin_manager._plugin_distinfo.append((plugin, DistFacade(dist)))
        except Exception:
            # Skip plugins that fail to load
            pass
