"""Post-process Jac client bundles for Ink terminal output.

Vendored from jac-ink (jac_ink.plugin.bundle_patch) for jac-super's internal
compile path — no jac-ink pip dependency required for ``jac ai --tui``.
"""

from __future__ import annotations

import re
from pathlib import Path

_JAC_RUNTIME_START = re.compile(r"^\s*const _jac = \{\s*$", re.MULTILINE)

_IMPORT_LINE_RE = re.compile(r'^import\s+\{([^}]+)\}\s+from\s+(["\'])([^"\']+)\2;\s*$')
_MODULE_MARKER_RE = re.compile(r"^//\s*(?:Imported \.jac module:|Client module:)\s*")
_THEME_IMPORT_RE = re.compile(r"^\./(?:.*/)?theme\.js$")

_IMPORT_ORDER = (
    "./runtime_shim.mjs",
    "./jac_runtime_shim.mjs",
    "./jac_builtin_runtime.mjs",
    "ink",
    "@inkjs/ui",
    "./jac_pi_runtime_shim.mjs",
)

_TUPLE_FOR_IN = re.compile(
    r"for \(const _item of (_jac\.builtin\.(?:enumerate|zip)\([^)]*\))\) \{"
)
_SOURCE_TUPLE_FOR = re.compile(
    r"for\s*\(\s*([^)]+?)\s*\)\s+in\s+(enumerate|zip)\s*\(",
)


_MODULE_MARKER = re.compile(
    r"^//\s*(?:Imported \.jac module:|Client module:)\s*(.+?)\s*$",
    re.MULTILINE,
)


def _resolve_jac_module(base: Path, entry_file: Path, mod: str) -> Path | None:
    if mod.startswith("."):
        mod = mod[1:]
    candidates = [mod, entry_file.stem if mod == entry_file.stem else ""]
    seen: set[str] = set()
    for stem in candidates:
        if not stem or stem in seen:
            continue
        seen.add(stem)
        for suffix in (".cl.jac", ".jac"):
            path = base / f"{stem}{suffix}"
            if path.is_file():
                return path
    if mod == entry_file.stem.rsplit(".", 1)[0]:
        return entry_file
    return None


def _bundle_jac_modules_in_order(code: str, entry_file: Path) -> list[Path]:
    base = entry_file.parent
    modules: list[Path] = []
    seen: set[Path] = set()
    for match in _MODULE_MARKER.finditer(code):
        path = _resolve_jac_module(base, entry_file, match.group(1))
        if path is not None and path not in seen:
            seen.add(path)
            modules.append(path)
    if entry_file not in seen:
        modules.append(entry_file)
    return modules


def _names_from_jac_source(text: str) -> list[list[str]]:
    names_queue: list[list[str]] = []
    for match in _SOURCE_TUPLE_FOR.finditer(text):
        parts = [part.strip() for part in match.group(1).split(",")]
        if len(parts) >= 2 and all(parts):
            names_queue.append(parts)
    return names_queue


def collect_tuple_unpack_names(code: str, entry_file: Path | None) -> list[list[str]]:
    if entry_file is None or not entry_file.is_file():
        return []
    names_queue: list[list[str]] = []
    for path in _bundle_jac_modules_in_order(code, entry_file):
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        names_queue.extend(_names_from_jac_source(text))
    return names_queue


def hoist_jac_runtime(code: str) -> tuple[str, str | None]:
    matches = list(_JAC_RUNTIME_START.finditer(code))
    if not matches:
        return code, None

    remove_ranges: list[tuple[int, int]] = []
    runtime_body: str | None = None
    for idx, match in enumerate(matches):
        start = match.start()
        end = _end_of_jac_runtime_block(code, match.end())
        if idx == 0:
            runtime_body = code[start:end].strip()
        remove_ranges.append((start, end))

    out: list[str] = []
    pos = 0
    for start, end in remove_ranges:
        out.append(code[pos:start])
        pos = end
    out.append(code[pos:])
    stripped = "".join(out)

    runtime_module = f"{runtime_body}\nexport {{ _jac }};\n"
    return stripped, runtime_module


def _end_of_jac_runtime_block(code: str, open_brace_end: int) -> int:
    _, end = _extract_brace_block(code, open_brace_end)
    while end < len(code) and code[end] in " \t":
        end += 1
    if end < len(code) and code[end] == ";":
        end += 1
    while end < len(code) and code[end] in " \t":
        end += 1
    if end < len(code) and code[end] == "\r":
        end += 1
    if end < len(code) and code[end] == "\n":
        end += 1
    return end


def _is_theme_module_marker(line: str) -> bool:
    stripped = line.strip()
    if not stripped.startswith("// Imported .jac module:"):
        return False
    path = stripped.split(":", 1)[1].strip()
    return path == ".theme" or path.endswith(".theme") or path.endswith("theme.cl.jac")


def consolidate_bundle_imports(code: str) -> str:
    lines = code.split("\n")
    merged: dict[str, set[str]] = {}
    body: list[str] = []
    theme_block: list[str] | None = None

    i = 0
    while i < len(lines):
        line = lines[i]

        if _is_theme_module_marker(line):
            i += 1
            block: list[str] = []
            while i < len(lines):
                tl = lines[i]
                if _MODULE_MARKER_RE.match(tl):
                    i -= 1
                    break
                if tl.strip() == "" and block:
                    break
                block.append(tl)
                i += 1
            if theme_block is None:
                theme_block = block
            i += 1
            continue

        match = _IMPORT_LINE_RE.match(line)
        if match:
            spec = match.group(3)
            if not _THEME_IMPORT_RE.match(spec):
                merged.setdefault(spec, set()).update(
                    name.strip() for name in match.group(1).split(",") if name.strip()
                )
            i += 1
            continue

        body.append(line)
        i += 1

    full_code = "\n".join(body)

    if re.search(r"\bStatic\b", full_code):
        merged.setdefault("ink", set()).add("Static")
    if re.search(r"\bSpinner\b", full_code):
        merged.setdefault("@inkjs/ui", set()).add("Spinner")
    for sym in ("Box", "Text", "useInput"):
        if re.search(rf"\b{sym}\b", full_code):
            merged.setdefault("ink", set()).add(sym)

    import_lines: list[str] = []
    seen: set[str] = set()
    for spec in _IMPORT_ORDER:
        names = merged.get(spec)
        if not names:
            continue
        import_lines.append(f'import {{ {", ".join(sorted(names))} }} from "{spec}";')
        seen.add(spec)

    for spec in sorted(merged):
        if spec in seen or not merged[spec]:
            continue
        import_lines.append(
            f'import {{ {", ".join(sorted(merged[spec]))} }} from "{spec}";'
        )

    theme_lines = theme_block or []
    parts = [*import_lines, *theme_lines]
    if body:
        if parts:
            parts.append("")
        parts.extend(body)
    return "\n".join(parts)


def fix_tuple_unpack_loops(code: str, entry_file: Path | None = None) -> str:
    names_queue = collect_tuple_unpack_names(code, entry_file)
    out: list[str] = []
    pos = 0
    for match in _TUPLE_FOR_IN.finditer(code):
        out.append(code[pos : match.start()])
        iter_expr = match.group(1)
        body, close = _extract_brace_block(code, match.end())
        names = (
            names_queue.pop(0) if names_queue else _infer_unpack_names(body, iter_expr)
        )
        if names:
            if "enumerate" in iter_expr:
                body, names = _normalize_enumerate_loop(body, names)
            destructure = "const [" + ", ".join(names) + "] = _item;\n    "
            body = destructure + body
        out.append(f"for (const _item of {iter_expr}) {{\n    {body}\n  }}")
        pos = close
    out.append(code[pos:])
    return "".join(out)


def _extract_brace_block(code: str, start: int) -> tuple[str, int]:
    depth = 0
    i = start - 1
    if i < 0 or code[i] != "{":
        return "", start
    depth = 1
    i = start
    while i < len(code) and depth:
        ch = code[i]
        if ch in "'\"":
            i = _skip_string(code, i)
            continue
        if ch == "/" and i + 1 < len(code) and code[i + 1] == "/":
            # Skip // comment to end of line
            i = code.find("\n", i)
            if i == -1:
                i = len(code)
            continue
        if ch == "/" and i + 1 < len(code) and code[i + 1] == "*":
            # Skip /* ... */ block comment
            end = code.find("*/", i + 2)
            i = end + 2 if end != -1 else len(code)
            continue
        if ch == "`":
            # Skip template literal (simplified — no ${} tracking)
            i += 1
            while i < len(code):
                if code[i] == "\\":
                    i += 2
                    continue
                if code[i] == "`":
                    i += 1
                    break
                i += 1
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return code[start:i], i + 1
        i += 1
    return code[start:], len(code)


def _skip_string(code: str, i: int) -> int:
    quote = code[i]
    i += 1
    while i < len(code):
        ch = code[i]
        if ch == "\\":
            i += 2
            continue
        if ch == quote:
            return i + 1
        i += 1
    return len(code)


_JS_KEYWORDS = frozenset(
    {
        "break",
        "case",
        "catch",
        "class",
        "const",
        "continue",
        "debugger",
        "default",
        "delete",
        "do",
        "else",
        "export",
        "extends",
        "false",
        "finally",
        "for",
        "function",
        "if",
        "import",
        "in",
        "instanceof",
        "let",
        "new",
        "null",
        "return",
        "super",
        "switch",
        "this",
        "throw",
        "true",
        "try",
        "typeof",
        "undefined",
        "var",
        "void",
        "while",
        "with",
        "yield",
        "of",
    }
)

_DECL_RE = re.compile(r"\b(?:let|const|var)\s+([a-zA-Z_$][\w$]*)")
_IDENT_RE = re.compile(r"\b([a-zA-Z_$][\w$]*)\b")

_ENUMERATE_VALUE = "f"


def _rename_ident(body: str, old: str, new: str) -> str:
    if old == new:
        return body
    return re.sub(rf"\b{re.escape(old)}\b", new, body)


def _normalize_enumerate_loop(body: str, names: list[str]) -> tuple[str, list[str]]:
    if len(names) < 2:
        names = [names[0] if names else "i", _ENUMERATE_VALUE]
    return body, names


def _loop_bound_idents(body: str) -> list[str]:
    declared = set(_DECL_RE.findall(body))
    declared.add("_item")
    prop_key_idents: set[str] = set()
    for m in re.finditer(r'"(\w+)"\s*:', body):
        prop_key_idents.add(m.group(1))
    str_literal_idents: set[str] = set()
    for m in re.finditer(r'"([^"]*?)"', body):
        for inner in _IDENT_RE.finditer(m.group(1)):
            str_literal_idents.add(inner.group(1))
    used: list[str] = []
    seen: set[str] = set()
    for match in _IDENT_RE.finditer(body):
        ident = match.group(1)
        start, end = match.start(), match.end()
        if ident in _JS_KEYWORDS or ident in declared or ident in seen:
            continue
        if ident.startswith("_jac") or ident.startswith("__jac"):
            continue
        if ident[0].isupper():
            continue
        if start > 0 and body[start - 1] == ".":
            continue
        if end < len(body) and body[end] == ".":
            continue
        rest = body[end:].lstrip()
        if rest.startswith("("):
            continue
        if ident in prop_key_idents:
            continue
        if ident in str_literal_idents:
            continue
        seen.add(ident)
        used.append(ident)
    return used


def _infer_unpack_names(body: str, iter_expr: str) -> list[str]:
    used = _loop_bound_idents(body)
    if "enumerate" in iter_expr:
        return used[:2]
    if "zip" in iter_expr:
        arity = iter_expr.count(",") + 1
        return used[:arity]
    return used


def fix_missing_loop_close(code: str) -> str:
    lines = code.split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if re.match(r"for\s*\(", stripped) and stripped.endswith("{"):
            base_indent = len(line) - len(line.lstrip())
            loop_lines: list[str] = [line]
            i += 1
            depth = 1
            found_return_before_close = False
            while i < len(lines):
                cur = lines[i]
                cur_stripped = cur.strip()
                cur_indent = (
                    len(cur) - len(cur.lstrip()) if cur.strip() else base_indent + 2
                )
                brace_delta = _count_braces(cur)
                old_depth = depth
                depth += brace_delta
                loop_lines.append(cur)
                if depth <= 0:
                    break
                if (
                    old_depth == 1
                    and cur_stripped.startswith("return")
                    and cur_indent <= base_indent + 4
                ):
                    found_return_before_close = True
                i += 1

            if found_return_before_close:
                for j, loop_line in enumerate(loop_lines):
                    if loop_line.strip().startswith("return"):
                        close_indent = " " * base_indent
                        loop_lines.insert(j, close_indent + "}")
                        break
                out.extend(loop_lines)
            else:
                out.extend(loop_lines)
        else:
            out.append(line)
        i += 1
    return "\n".join(out)


def _count_braces(line: str) -> int:
    depth = 0
    in_single = False
    in_double = False
    k = 0
    while k < len(line):
        ch = line[k]
        if ch == "\\" and (in_single or in_double):
            k += 2
            continue
        if ch == '"' and not in_single:
            in_double = not in_double
        elif ch == "'" and not in_double:
            in_single = not in_single
        elif not in_single and not in_double:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
        k += 1
    return depth


_DOUBLE_ESCAPED_UNICODE = re.compile(r"\\\\u([0-9a-fA-F]{4})")

# Pattern: `(X ?? "" || "")` — Jac compiler emits this for `X.get(key, "") or ""`
# The `??` and `||` precedence is wrong; this becomes `(X ?? ("" || ""))` which is
# a syntax error in some engines and semantically wrong. Simplify to `(X ?? "") || ""`
# which is equivalent to just `X ?? ""` for our purposes.
_BROKEN_NULLISH_OR = re.compile(r'(\w+(?:\[\w+\])?\s*\?\?\s*""\s*)\|\|\s*""')


def fix_broken_nullish_or(code: str) -> str:
    """Fix `X ?? "" || ""` -> `X ?? ""` emitted by the Jac compiler."""
    return _BROKEN_NULLISH_OR.sub(r"\1", code)


def fix_double_escaped_unicode(code: str) -> str:
    def _fix_inside_string(m: re.Match[str]) -> str:
        s = m.group(0)
        quote = s[0]
        inner = s[1:-1]
        fixed = _DOUBLE_ESCAPED_UNICODE.sub(r"\\u\1", inner)
        return quote + fixed + quote

    return re.sub(
        r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'',
        _fix_inside_string,
        code,
    )
