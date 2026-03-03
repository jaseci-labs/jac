# Jac Console System — Deep Dive Documentation

This document explains every part of the Jac CLI console system: how `jacpretty.jac`
works internally, how `console.impl.jac` builds on top of it, and how the two files
integrate together to produce colored, structured terminal output.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [jacpretty.jac — Line by Line](#2-jacprettyjac--line-by-line)
   - [2.1 Imports](#21-imports)
   - [2.2 Color and Style Constants](#22-color-and-style-constants)
   - [2.3 `_parse_color` — Color Code Resolver](#23-_parse_color--color-code-resolver)
   - [2.4 `Style` Class](#24-style-class)
   - [2.5 `render_markup` — Markup Parser](#25-render_markup--markup-parser)
   - [2.6 `Console` Class](#26-console-class)
   - [2.7 Global Instance and Public API](#27-global-instance-and-public-api)
3. [console.impl.jac — Line by Line](#3-consoleimpljac--line-by-line)
   - [3.1 Imports and Stream Factories](#31-imports-and-stream-factories)
   - [3.2 Environment Detection](#32-environment-detection)
   - [3.3 Core Print Method](#33-core-print-method)
   - [3.4 Status and Spinner](#34-status-and-spinner)
   - [3.5 Semantic Message Methods](#35-semantic-message-methods)
   - [3.6 Structured Output Methods](#36-structured-output-methods)
   - [3.7 `_get_console` — The Lazy Singleton](#37-_get_console--the-lazy-singleton)
4. [Integration: How the Two Files Connect](#4-integration-how-the-two-files-connect)
5. [The Full Call Chain](#5-the-full-call-chain)
6. [Environment Variables Reference](#6-environment-variables-reference)
7. [ANSI Escape Code Primer](#7-ansi-escape-code-primer)
8. [Markup Tag Reference](#8-markup-tag-reference)

---

## 1. Architecture Overview

The console system has two layers:

```
┌─────────────────────────────────────────────────┐
│              Application Code                   │
│   console.success(...)  console.error(...)  ... │
└──────────────────────┬──────────────────────────┘
                       │  uses
┌──────────────────────▼──────────────────────────┐
│              console.impl.jac                   │
│  JacConsole — high-level semantic API           │
│  (success, error, warning, info, tables, etc.)  │
│  Understands: emojis, color flags, stderr/stdout│
└──────────────────────┬──────────────────────────┘
                       │  delegates to
┌──────────────────────▼──────────────────────────┐
│              jacpretty.jac                      │
│  Console — low-level rendering engine           │
│  Understands: ANSI codes, markup tags, TTY      │
└─────────────────────────────────────────────────┘
```

`jacpretty.jac` is a **zero-dependency** color rendering library — it knows nothing about
the Jac CLI domain. It only knows how to turn `[bold red]text[/]` into actual colored
terminal output via ANSI escape codes.

`console.impl.jac` is the **semantic layer** — it translates domain concepts
("this is a compilation error", "this is a file watcher event") into the correct
colors, symbols, and streams using jacpretty underneath.

A global `console` proxy object (defined in `console.jac`) exposes everything to
application code via a single import.

---

## 2. `jacpretty.jac` — Line by Line

### 2.1 Imports

```jac
import os, re, sys;
import from typing { Dict, Optional, Tuple, Any }
```

- `os` — reads environment variables (`NO_COLOR`) and terminal width
  (`os.get_terminal_size`)
- `re` — compiles the markup regex used to find `[tag]...[/]` patterns
- `sys` — provides `sys.stdout` as the default output stream
- `typing` — type hints only; no runtime impact

---

### 2.2 Color and Style Constants

```jac
glob COLORS: Dict[(str, int)] = {
    'black': 0, 'red': 1, 'green': 2, 'yellow': 3,
    'blue': 4, 'magenta': 5, 'cyan': 6, 'white': 7,
    'bright_black': 8, 'bright_red': 9, ...  'bright_white': 15
}
```

Maps every color name to its position in the ANSI 16-color palette. The number here
is **not** the ANSI code directly — it is an index. The actual ANSI code is computed
in `_parse_color` by adding this index to a base offset (30 for foreground, 40 for
background).

```jac
glob STYLES: Dict[(str, str)] = {
    'bold': '1', 'dim': '2', 'italic': '3', 'underline': '4',
    'blink': '5', 'reverse': '7', 'conceal': '8', 'strike': '9'
}
```

Maps style names to their SGR (Select Graphic Rendition) parameter strings. These
numbers are part of the ANSI standard — `1` is bold, `2` is dim, `4` is underline,
etc. Note there is no `6` — that is a rapid blink variant not commonly supported.

```jac
glob STYLE_ALIASES: Dict[(str, str)] = {
    'b': 'bold', 'd': 'dim', 'i': 'italic', 'u': 'underline',
    'r': 'reverse', 's': 'strike', 'c': 'conceal'
}
```

Single-character shortcuts. When `Style._parse` sees the word `b`, it looks it up
here first and resolves it to `bold` before checking `STYLES`.

---

### 2.3 `_parse_color` — Color Code Resolver

```jac
def _parse_color(color: str, bg: bool = False) -> Optional[Tuple[(str, ...)]]
```

This is the engine that converts any color expression into a tuple of ANSI code
strings. It returns a tuple because some color modes require multiple numbers in the
escape sequence. Returns `None` if the expression is not a recognized color.

**Parameter `bg`:** When `True`, generates background color codes instead of
foreground. This flips `base` from 30→40 and `mode` from `'38'`→`'48'`.

#### Named colors

```jac
if (color in COLORS) {
    n = COLORS[color];
    return (str((base + n)) if (n < 8) else str(base + 52 + n), );
}
```

For the standard 8 colors (index 0–7), the ANSI foreground codes are 30–37 and
background are 40–47. So `base + n` gives the right code directly.

For the bright 8 colors (index 8–15), ANSI defines codes 90–97 (fg) and 100–107 (bg).
The formula `base + 52 + n` bridges the gap: for fg (base=30) and bright_black
(n=8): `30 + 52 + 8 = 90` ✓. For bright_white (n=15): `30 + 52 + 15 = 97` ✓.

The trailing comma makes it a **one-element tuple**, matching the return type of the
other branches which return multi-element tuples.

#### Hex colors

```jac
if (color.startswith('#') and (len(color) == 7)) {
    return (mode, '2', str(int(color[1:3], 16)), str(int(color[3:5], 16)), str(int(color[5:7], 16)));
}
```

Hex colors use ANSI's 24-bit "true color" format: `\x1b[38;2;R;G;Bm`. The tuple
produced is `('38', '2', 'R', 'G', 'B')` where R/G/B are parsed from the hex string
by slicing two characters at a time and converting from base-16.

#### RGB colors

```jac
if (color.startswith('rgb(') and color.endswith(')')) {
    p = color[4:-1].split(',');
    return (mode, '2', p[0].strip(), p[1].strip(), p[2].strip()) if (len(p) == 3) else None;
}
```

`rgb(255, 0, 128)` → strips the `rgb(` prefix and `)` suffix, splits on commas,
strips whitespace. Produces the same 5-element tuple as hex, but takes the numbers
directly from the input string. Returns `None` if the string doesn't parse to
exactly 3 components.

#### 256-palette colors

```jac
if (color.startswith('color(') and color.endswith(')')) {
    return (mode, '5', color[6:-1]);
}
```

Uses ANSI's 256-color format: `\x1b[38;5;Nm`. The tuple is `('38', '5', 'N')`.
The index string `N` is taken verbatim from between the parentheses — no validation
is done, which means `color(999)` would generate an invalid but non-crashing code.

---

### 2.4 `Style` Class

The `Style` class represents a parsed combination of colors and text attributes. It
is lazy — it does not compute the ANSI code string until the first time `.codes` is
accessed.

#### `__slots__`

```jac
with entry {
    __slots__ = ['_def', '_codes'];
}
```

Restricts the instance to exactly two attributes: `_def` (the raw style definition
string, e.g., `'bold red on blue'`) and `_codes` (the computed ANSI code string,
e.g., `'1;31;44'`). This reduces memory usage and prevents accidental attribute
creation.

#### `init`

```jac
def init(self: Style, definition: str = '') -> object {
    (self._def, self._codes) = (definition, None);
}
```

Stores the definition string and sets `_codes` to `None` (not yet computed).

#### `__bool__`

```jac
def __bool__(self: Style) -> object {
    return bool(self._def);
}
```

A `Style` with an empty definition string is falsy. Used in `__add__` to handle
combining an empty style with a non-empty one cleanly.

#### `__add__`

```jac
def __add__(self: Style, other: 'Style') -> 'Style' {
    return Style(f"{self._def} {other._def}") if (self and other) else (self or other);
}
```

Combines two styles by concatenating their definition strings with a space.
`Style('bold') + Style('red')` → `Style('bold red')`. If either side is empty/falsy,
returns the non-empty one unchanged (avoids a leading/trailing space in the
definition).

#### `codes` property

```jac
@property
def codes(self: Style) -> str {
    if (self._codes is None) {
        self._codes = self._parse();
    }
    return self._codes;
}
```

Lazy computation: `_parse()` is called at most once per instance. The result is
cached in `_codes`. Subsequent accesses return the cached string immediately.

#### `_parse`

```jac
def _parse(self: Style) -> str {
    if not self._def { return ''; }
    (codes, words, i) = ([], self._def.lower().split(), 0);
    while (i < len(words)) {
        w = words[i];
        # 1. Background color: "on <color>"
        if (w == 'on' and (i + 1) < len(words) and (bg := _parse_color(words[i+1], True))) {
            codes.extend(bg); i += 2; continue;
        }
        # 2. Style or alias
        if ((attr := STYLE_ALIASES.get(w, w)) in STYLES) {
            codes.append(STYLES[attr]); i += 1; continue;
        }
        # 3. Foreground color
        if (fg := _parse_color(w)) {
            codes.extend(fg);
        }
        i += 1;
    }
    return ';'.join(codes);
}
```

Walks the words of the definition string left to right with a manual index `i`
(not a for-loop) so it can consume two words at once for `on <color>` pairs.

**Priority order per word:**

1. If the word is `on` and the next word is a valid color → background, advance by 2
2. If the word (after alias resolution) is a style name → append style code, advance by 1
3. Otherwise try it as a foreground color → extend with color codes, advance by 1

All codes are collected into a list and joined with `;` at the end, forming the
middle part of an ANSI escape sequence like `1;31;44` (bold red on blue).

#### `render`

```jac
def render(self: Style, text: str) -> str {
    return f"\x1b[{self.codes}m{text}\x1b[0m" if self.codes else text;
}
```

Wraps `text` in the ANSI escape sequence. `\x1b` is the ESC character (byte `0x1B`,
decimal 27). The sequence `\x1b[<codes>m` opens the style and `\x1b[0m` resets all
attributes back to default. If there are no codes (empty style), the text is returned
unchanged.

#### `Style.parse` classmethod

```jac
@classmethod
def parse(cls: Any, definition: str) -> 'Style' {
    return cls(definition);
}
```

Alternative constructor — identical to `Style(definition)`. Provided for API
compatibility in case callers prefer the `Style.parse('bold red')` form.

---

### 2.5 `render_markup` — Markup Parser

```jac
glob RE_MARKUP = re.compile('\\[(/)?([^\\[\\]]*)\\]');
```

The compiled regex. It matches any `[...]` bracketed expression. The two capture
groups are:

- Group 1 `(/)?` — present (as `/`) only for closing tags `[/]`, `[/bold]`, etc.
- Group 2 `([^\[\]]*)` — the tag content: everything inside the brackets except
  nested brackets

```jac
def render_markup(markup: str, base_style: str = '') -> str
```

Converts a markup string like `"[bold red]Error:[/] message"` into an ANSI-rendered
string. The optional `base_style` is applied to any text that falls outside all tags.

#### Bracket escaping

```jac
markup = markup.replace('\\[', '\x00').replace('\\]', '\x01');
```

Before scanning for tags, literal `\[` and `\]` in the source string are replaced
with placeholder bytes (`\x00` and `\x01`). This prevents the regex from treating
them as tag boundaries. They are restored to `[` and `]` when each text segment is
extracted.

#### Main loop

```jac
(result, stack, pos) = ([], [base_style] if base_style else [], 0);

for m in RE_MARKUP.finditer(markup) {
    # Text before this tag
    if (m.start() > pos) {
        txt = markup[pos:m.start()].replace('\x00', '[').replace('\x01', ']');
        result.append(Style(' '.join(stack)).render(txt) if stack else txt);
    }
    # Closing tag [/] or [/tagname] — pop top style
    if (m.group(1) and stack) { stack.pop(); }
    # Opening tag [tagname] — push style
    elif m.group(2).strip() { stack.append(m.group(2).strip()); }

    pos = m.end();
}
```

`stack` holds the currently active style names (innermost last). Before processing
each tag, the text between the previous tag's end and this tag's start is rendered
using `Style(' '.join(stack))`. This means nested tags combine: inside
`[bold][red]text[/][/]`, the text renders with `Style('bold red')`.

Closing tags always pop — the tag name in `[/bold]` is ignored. This means mismatched
tags like `[red]text[/bold]` still work (the `/bold` closes whatever is on top of the
stack).

#### Tail text

```jac
if (pos < len(markup)) {
    txt = markup[pos:].replace('\x00', '[').replace('\x01', ']');
    result.append(Style(' '.join(stack)).render(txt) if stack else txt);
}
```

After all tags are processed, any remaining text (after the last tag) is rendered
with whatever styles are still on the stack (handles unclosed tags gracefully).

---

### 2.6 `Console` Class

The `Console` class is the low-level output engine. It owns a file handle and knows
whether it is writing to a real terminal.

#### `init`

```jac
def init(self: Console, *, file: Any = None, width: Optional[int] = None,
         force_terminal: Optional[bool] = None, no_color: bool = False) -> object {
    (self._file, self._width, self._force_terminal) = (file or sys.stdout, width, force_terminal);
    self._no_color = no_color or bool(os.environ.get('NO_COLOR'));
}
```

- `file` — the output stream. Defaults to `sys.stdout`. Pass `sys.stderr` to create
  an error console.
- `width` — override terminal width. If `None`, queried live from the OS each time.
- `force_terminal` — override TTY detection. `True` forces color on, `False` forces
  color off, `None` uses `isatty()`.
- `no_color` — can be set directly or picked up from the `NO_COLOR` environment
  variable (the standard cross-tool convention).

#### `width` property

```jac
@property
def width(self: Console) -> int {
    if self._width { return self._width; }
    try { return os.get_terminal_size().columns; }
    except (OSError, ValueError) { return 80; }
}
```

Queries the OS for the current terminal width. Falls back to 80 columns if the query
fails (e.g., when running in a non-interactive environment or piped output).
`OSError` covers non-TTY file handles; `ValueError` covers some edge cases on
certain platforms.

#### `is_terminal` property

```jac
@property
def is_terminal(self: Console) -> bool {
    if (self._force_terminal is not None) { return self._force_terminal; }
    try { return self._file.isatty(); }
    except Exception as e { return False; }
}
```

`isatty()` returns `True` only when the file handle is connected to an interactive
terminal (not a pipe, file, or StringIO). The broad `except Exception` catches the
case where `_file` is a mock or StringIO that does not implement `isatty()`.

#### `print`

```jac
def print(self: Console, *objects: Any, sep: str = ' ', end: str = '\n',
          style: str = '', markup: bool = True) -> None {
    parts = [];
    for `obj in objects {
        text = str(`obj);
        if (self.is_terminal and not self._no_color) {
            text = render_markup(text, style) if markup else Style(style).render(text) if style else text;
        } elif markup {
            text = RE_MARKUP.sub('', text);
        }
        parts.append(text);
    }
    self._file.write((sep.join(parts) + end));
    if self.is_terminal { self._file.flush(); }
}
```

The three rendering paths:

| Condition | Result |
|---|---|
| TTY + color enabled + `markup=True` | Full markup rendering via `render_markup` |
| TTY + color enabled + `markup=False` + `style` set | Apply `style` to entire text via `Style.render` |
| TTY + color enabled + `markup=False` + no style | Plain text, no change |
| Non-TTY (any markup setting) | Text written as-is, no ANSI codes emitted |

**Why markup tags are not stripped on non-TTY:** `RE_MARKUP` matches any `[content]`
pattern. Stripping it would clobber legitimate square-bracket content in tool output
(e.g. graphviz DOT `[label="..."]`, code snippets containing `[index]`, etc.).
Callers that write raw non-markup text to a shared stream should pass `markup=False`
to avoid ambiguity, though this does not strip — it simply skips rendering.

After all objects are converted to strings, they are joined with `sep` and `end` is
appended — matching Python's built-in `print()` signature. Flushing only happens on
a real terminal; for files/pipes the OS buffers are more efficient.

#### `rule`

```jac
def rule(self: Console, title: str = '', char: str = '─', style: str = 'dim') -> None {
    w = self.width;
    line = (char * ((w - len(title) - 2) // 2)) + f" {title} " + (char * ((w - len(title) - 1) // 2))
        if title
        else (char * w);
    self.print(f"[{style}]{line}[/]" if style else line);
}
```

Draws a horizontal rule across the full terminal width. Without a title, it simply
repeats `char` for `width` columns. With a title, it centers the title between two
runs of `char`. The asymmetric `-2` / `-1` in the two halves handles odd-width
remainders so the total always equals the terminal width exactly.

#### `log`

```jac
def log(self: Console, *objects: Any, **kwargs: Any) -> None {
    import from datetime { datetime }
    self.print(f"[dim][{datetime.now().strftime('%H:%M:%S')}][/]", *objects, **kwargs);
}
```

Prepends a dim `[HH:MM:SS]` timestamp to the output. The timestamp is generated
fresh on each call. All args are passed through to `print`, so `log` inherits all
of `print`'s behavior including markup rendering.

---

### 2.7 Global Instance and Public API

```jac
glob _console: Optional[Console] = None;

def get_console -> Console {
    global _console;
    if (_console is None) { _console = Console(); }
    return _console;
}

def print(*objects: Any, **kwargs: Any) -> None {
    get_console().print(*objects, **kwargs);
}

glob __all__ = ['Console', 'Style', 'print', 'render_markup', 'get_console'];
```

`get_console()` returns a module-level singleton `Console` instance writing to
`sys.stdout`. This is the default console for anyone who does
`import from jaclang.cli.jacpretty { get_console }` directly (used in the demo).

The module-level `print()` is a convenience wrapper that lets callers do
`jacpretty.print(...)` without explicitly obtaining the console first.

`__all__` defines the public API surface — only these names are exported when a
caller does a wildcard import.

---

## 3. `console.impl.jac` — Line by Line

### 3.1 Imports and Stream Factories

```jac
import os, sys;
import from contextlib { contextmanager }
import from typing { Any }
import from jaclang.cli.jacpretty { Console as _PrettyConsole }
```

`_PrettyConsole` is jacpretty's `Console` class, imported under a private alias to
signal it is an internal detail of this module.

```jac
def _get_pretty_stdout -> _PrettyConsole {
    return _PrettyConsole();
}

def _get_pretty_stderr -> _PrettyConsole {
    return _PrettyConsole(file=sys.stderr);
}
```

These two factory functions create **fresh** `_PrettyConsole` instances on every
call. This is intentional and critical for testing correctness.

**Why not a singleton?** When tests redirect `sys.stdout = io.StringIO()`, a
singleton would still hold a reference to the *original* `sys.stdout` captured at
creation time. Output would flow to the original stream, making
`captured_output.getvalue()` return `''`. By creating a new instance per call,
`_PrettyConsole.__init__` evaluates `file or sys.stdout` at the moment of the call,
picking up whatever `sys.stdout` is *right now* — exactly like Python's built-in
`print()`.

`_get_pretty_stderr` passes `sys.stderr` explicitly for methods that must write to
the error stream (`error()`).

---

### 3.2 Environment Detection

```jac
impl JacConsole.init -> None {
    self.use_emoji = JacConsole._should_use_emoji();
    self.use_color = JacConsole._should_use_color();
}
```

Called once when the `JacConsole` instance is first created. Sets two boolean flags
that all subsequent methods read.

```jac
impl JacConsole._should_use_emoji -> bool {
    if os.environ.get('NO_EMOJI') or os.environ.get('TERM') == 'dumb' { return False; }
    if sys.platform == 'win32' and not os.environ.get('WT_SESSION') { return False; }
    return True;
}
```

Emoji is disabled when:

- `NO_EMOJI` env var is set (any value)
- `TERM=dumb` (a terminal that supports no capabilities)
- Running on Windows **without** Windows Terminal (`WT_SESSION` is set by Windows
  Terminal when it launches a process)

The Windows check exists because the default `cmd.exe` and PowerShell consoles do not
render emoji reliably.

```jac
impl JacConsole._should_use_color -> bool {
    if os.environ.get('NO_COLOR') { return False; }
    if os.environ.get('TERM') == 'dumb' { return False; }
    return True;
}
```

Color is disabled when:

- `NO_COLOR` env var is set — this is the [no-color.org](https://no-color.org)
  standard honored by most modern CLI tools
- `TERM=dumb` — a terminal with no SGR support

Note: jacpretty's `Console` also reads `NO_COLOR` independently for its own TTY
check. The two checks are complementary: jacpretty gates on `is_terminal`, while
`JacConsole` uses `use_color` to decide whether to even call emoji/color paths.

---

### 3.3 Core Print Method

```jac
impl JacConsole.print(*args: Any, **kwargs: Any) -> None {
    markup = kwargs.pop('markup', True);
    style = kwargs.pop('style', '');
    kwargs.pop('highlight', None);
    _get_pretty_stdout().print(
        *args,
        sep=kwargs.pop('sep', ' '),
        end=kwargs.pop('end', '\n'),
        style=style,
        markup=markup
    );
}
```

This is the bridge from the JacConsole API to jacpretty. It:

1. Extracts `markup` (default `True`) — whether to parse `[tag]` syntax
2. Extracts `style` (default `''`) — a base style applied to all text
3. Silently discards `highlight` — a Rich-specific kwarg that has no meaning here
4. Extracts `sep` and `end` before forwarding to avoid passing unknown kwargs
5. Creates a fresh stdout Console and calls its `print()`

jacpretty's `Console.print` already handles the TTY check and markup rendering, so
this method does not duplicate that logic.

---

### 3.4 Status and Spinner

#### `status` (basic stub)

```jac
impl JacConsole.status(*args: Any, **kwargs: Any) -> object {
    if args {
        _get_pretty_stdout().print(f"[dim]{args[0] if isinstance(args[0], str) else str(args[0])}[/]");
    }
    @contextmanager
    def _noop_status -> object { yield None; }
    return _noop_status();
}
```

`status` is meant to be used as a context manager:

```jac
with console.status("Loading modules...") { ... }
```

The base implementation prints the status text in dim style and then returns a no-op
context manager that simply yields `None`. There is no live spinner — the text
appears once at entry and the block executes silently. This is a deliberate minimal
implementation; richer plugins can override this to provide a real animated spinner.

#### `spinner` (inline animation)

```jac
@ contextmanager
impl JacConsole.spinner(text: str) -> object {
    _get_pretty_stdout().print(f"[dim]{text}...[/]", end='');
    sys.stdout.flush();
    try {
        yield None;
    } finally {
        _get_pretty_stdout().print(f" [bold green]done[/]");
    }
}
```

Simulates a spinner with a simple before/after pattern:

1. Prints `text...` in dim style with `end=''` so **no newline** is emitted yet —
   the cursor stays on the same line
2. `sys.stdout.flush()` forces the partial line to appear immediately
3. The `yield` hands control to the `with` block body
4. When the body completes (or raises), `finally` prints `done` in bold green on
   the **same line**, then adds the default newline

Both `print` calls create separate `_PrettyConsole` instances, but both write to
`sys.stdout`, so the output is contiguous. The result in the terminal is:

```
Resolving types... done
```

---

### 3.5 Semantic Message Methods

All four methods follow the same pattern: choose a prefix symbol (emoji or text
fallback), then print with the appropriate color.

#### `success`

```jac
impl JacConsole.success(message: str, emoji: bool = True) -> None {
    prefix = '✔' if emoji and self.use_emoji else '[OK]';
    _get_pretty_stdout().print(f"[bold green]{prefix}[/] {message}");
}
```

- Emoji on: `✔ Build completed in 1.3s`  (green ✔, plain message)
- Emoji off: `[OK] Build completed in 1.3s`  (green [OK], plain message)

The message itself is intentionally not styled — this matches the UX convention of
tools like cargo and npm where the status indicator is colored but the description is
readable plain text.

#### `error`

```jac
impl JacConsole.error(message: str, hint: str | None = None, emoji: bool = True) -> None {
    prefix = '✖' if emoji and self.use_emoji else '[ERROR]';
    _get_pretty_stderr().print(f"[bold red]{prefix} Error:[/] {message}");
    if hint {
        hint_prefix = '💡' if self.use_emoji else 'HINT:';
        _get_pretty_stderr().print(f"[dim]{hint_prefix} {hint}[/]");
    }
}
```

Unlike all other methods, `error` writes to **`sys.stderr`** via `_get_pretty_stderr()`.
This is the Unix convention: errors go to stderr so they can be separated from
normal stdout output by shell piping.

The optional `hint` provides a secondary line for suggestions, printed in dim style
to visually subordinate it to the main error.

Output example:

```
✖ Error: Compilation failed: unexpected token ';'
💡 Did you mean 'main.jac'?
```

#### `warning`

```jac
impl JacConsole.warning(message: str, emoji: bool = True) -> None {
    prefix = '⚠' if emoji and self.use_emoji else '[WARNING]';
    _get_pretty_stdout().print(f"[bold yellow]{prefix}[/] {message}");
}
```

Warnings go to **stdout** (not stderr). They are informational — not errors — so they
belong in the main output stream.

#### `info`

```jac
impl JacConsole.info(message: str, emoji: bool = True) -> None {
    prefix = 'ℹ' if emoji and self.use_emoji else '[INFO]';
    _get_pretty_stdout().print(f"[bold cyan]{prefix}[/] {message}");
}
```

Same pattern as warning, with cyan instead of yellow.

---

### 3.6 Structured Output Methods

#### `print_header`

```jac
impl JacConsole.print_header(title: str, version: str | None = None) -> None {
    pc = _get_pretty_stdout();
    pc.rule();
    if version {
        pc.print(f"[bold bright_white]{title}[/]  [dim]v{version}[/]");
    } else {
        pc.print(f"[bold bright_white]{title}[/]");
    }
    pc.rule();
}
```

`pc.rule()` (no args) draws a full-width dim horizontal line using the default `─`
character. The title is bold bright white for maximum visibility. The version string
is dim to not compete with the title. Output:

```
────────────────────────────────────────────────────────────────────────────────
JacPretty Demo  v1.0.0
────────────────────────────────────────────────────────────────────────────────
```

#### `print_urls`

```jac
impl JacConsole.print_urls(urls: Any, symbol: str = '➜') -> None {
    pc = _get_pretty_stdout();
    items = urls.items() if isinstance(urls, dict) else urls;
    for (label, url) in items {
        padded_label = f"{label}:".ljust(10);
        pc.print(f"  [bold cyan]{symbol}[/]  [dim]{padded_label}[/] [bright_blue underline]{url}[/]");
    }
}
```

Accepts either a `dict` (converted to `.items()`) or any iterable of `(label, url)`
pairs. The label is right-padded to 10 characters with `.ljust(10)` for column
alignment. Colors: cyan arrow, dim label, bright_blue underlined URL.

#### `print_next_steps`

```jac
impl JacConsole.print_next_steps(steps: list[str], title: str = 'Next Steps') -> None {
    pc = _get_pretty_stdout();
    pc.print(f"\n[bold bright_white]{title}:[/]");
    for (i, step) in enumerate(steps, 1) {
        pc.print(f"  [bold cyan]{i}.[/] {step}");
    }
    pc.print();
}
```

Steps can contain markup themselves — `jac run [bold cyan]main.jac[/]` works because
jacpretty's markup parser handles nested tags. The leading `\n` and trailing
`pc.print()` (empty newline) add breathing room around the block.

#### `print_list`

```jac
impl JacConsole.print_list(items: list[str], style: str = 'success', symbol: str = '✔') -> None {
    pc = _get_pretty_stdout();
    color_map = {
        'success': 'bold green', 'warning': 'bold yellow',
        'error': 'bold red', 'info': 'bold cyan'
    };
    color = color_map.get(style, 'bold green');
    for item in items {
        pc.print(f"  [{color}]{symbol}[/] {item}");
    }
}
```

The `style` parameter is a semantic key (`'success'`, `'warning'`, etc.) not a raw
color. The `color_map` translates it. Unrecognized styles fall back to `'bold green'`.
The caller can pass any symbol, enabling use of `⚠`, `✖`, `ℹ`, or any custom prefix.

#### `print_table`

```jac
impl JacConsole.print_table(headers: list[str], rows: list[list[str]], title: str | None = None) -> None {
    # Calculate column widths
    col_widths: list[int] = [len(h) for h in headers];
    for row in rows {
        for (i, cell) in enumerate(row) {
            if i < len(col_widths) {
                col_widths[i] = max(col_widths[i], len(str(cell)));
            }
        }
    }
    # Print header row
    header_parts = [f"[bold bright_white]{h.ljust(w)}[/]" for (h, w) in zip(headers, col_widths)];
    pc.print(' [dim]|[/] '.join(header_parts));
    separator = '-' * (sum(col_widths) + (len(col_widths) - 1) * 3);
    pc.print(f"[dim]{separator}[/]");
    # Print data rows
    for row in rows {
        row_parts = [str(cell).ljust(col_widths[i]) if i < len(col_widths) else str(cell)
                     for (i, cell) in enumerate(row)];
        pc.print(' [dim]|[/] '.join(row_parts));
    }
    pc.print();
}
```

A pure-Python ASCII table renderer:

1. **Column widths:** initialized to each header's length, then expanded to fit the
   widest cell in each column
2. **Header row:** each header is left-padded to its column width and wrapped in
   `[bold bright_white]`; columns are joined with dim ` | ` separators
3. **Separator:** a single `---...---` line spanning the full table width (computed as
   total content width plus separator widths)
4. **Data rows:** cells padded to column width, joined with the same dim ` | `

The separator width formula: `sum(col_widths) + (len(col_widths) - 1) * 3`
→ 3 characters per separator (` | `), one fewer separator than columns.

#### `print_elapsed_time`

```jac
impl JacConsole.print_elapsed_time(seconds: float) -> None {
    pc = _get_pretty_stdout();
    if seconds < 1 {
        ms = seconds * 1000;
        pc.print(f"  [dim]Done in[/] [bold green]{ms:.0f}ms[/]");
    } else {
        pc.print(f"  [dim]Done in[/] [bold green]{seconds:.1f}s[/]");
    }
}
```

Sub-second times are shown in milliseconds (no decimal), longer times in seconds
with one decimal. The label "Done in" is dim, the value is bold green. This matches
the visual convention of tools like Vite and esbuild.

#### `print_file_change`

```jac
impl JacConsole.print_file_change(filepath: str, action: str = 'changed') -> None {
    import from datetime { datetime }
    timestamp = datetime.now().strftime('%H:%M:%S');
    emoji_map = {'changed': '⚡', 'created': '✨', 'deleted': '🗑️'};
    color_map = {'changed': 'yellow', 'created': 'green', 'deleted': 'red'};
    emoji = emoji_map.get(action, '📝') if self.use_emoji else action.upper();
    color = color_map.get(action, 'cyan');
    pc.print(f"[dim][{timestamp}][/] [{color}]{emoji} {action.capitalize()}:[/] {filepath}");
}
```

Each action has its own semantic color:

- `changed` → yellow (caution, something shifted)
- `created` → green (positive, new file)
- `deleted` → red (destructive action)

Unknown actions fall back to cyan emoji `📝` and cyan color. The timestamp is always
dim to stay visually subordinate. When emoji is off, `action.upper()` (e.g.,
`CHANGED:`) replaces the emoji, ensuring no information is lost.

#### `print_watching`

```jac
impl JacConsole.print_watching(pattern: str, count: int) -> None {
    pc = _get_pretty_stdout();
    watch_emoji = '👀 ' if self.use_emoji else '';
    pc.print(f"[bold cyan]{watch_emoji}Watching for changes...[/]");
    pc.print(f"   [dim]Monitoring:[/] [bright_white]{pattern}[/] [dim]({count} files)[/]");
}
```

Two lines: a bold cyan status line and an indented dim detail line. When emoji is
enabled, `'👀 '` (with trailing space) is prepended — the trailing space is part of
the string so no extra space logic is needed in the f-string. When emoji is off, the
empty string produces no prefix.

---

### 3.7 `_get_console` — The Lazy Singleton

```jac
impl _get_console -> JacConsole {
    global _console_instance;
    if _console_instance is None {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        _console_instance = Jac.get_console();
        _console_instance.init();
    }
    return _console_instance;
}
```

This is called by `_ConsoleProxy.__getattr__` (in `console.jac`) every time the
global `console` object is accessed. It is a **singleton for the `JacConsole`
object** — meaning configuration (`use_emoji`, `use_color`) is stable across the
lifetime of the process. This is intentional: you do not want the color/emoji mode
to flip between method calls.

`Jac.get_console()` goes through the runtime hook system. If a plugin (like jac-super)
has registered a replacement, it gets returned here instead of the default
`JacConsole`. This is the extension point for the entire console system.

The `import` statement is inside the function body to avoid circular imports — the
runtime module imports CLI modules, so a top-level import would create a cycle.

---

## 4. Integration: How the Two Files Connect

```
console.impl.jac          jacpretty.jac
─────────────────         ──────────────────────────────────────────
JacConsole.success()
  └─ _get_pretty_stdout() → _PrettyConsole()          (fresh Console on sys.stdout)
       └─ Console.print(f"[bold green]✔[/] {msg}")
            └─ is_terminal? ──yes──→ render_markup("[bold green]✔[/] msg")
            │                             └─ Style('bold green')._parse()
            │                                  └─ STYLES['bold'] = '1'
            │                                     _parse_color('green') = ('32',)
            │                                     codes = '1;32'
            │                             └─ Style.render("✔")
            │                                  └─ "\x1b[1;32m✔\x1b[0m msg"
            └─ no ──→ RE_MARKUP.sub('', text)  → "✔ msg"  (clean, no tags)
```

The key coupling point is this import in `console.impl.jac`:

```jac
import from jaclang.cli.jacpretty { Console as _PrettyConsole }
```

Everything `console.impl.jac` does with colors goes through jacpretty. The impl
never writes ANSI codes directly — it writes markup strings and trusts jacpretty to
render them.

---

## 5. The Full Call Chain

From the perspective of application code calling `console.error("Disk full")`:

```
1. console.error("Disk full")
   │
   │  console is a _ConsoleProxy (from console.jac)
   │  _ConsoleProxy.__getattr__('error') calls _get_console()
   │
2. _get_console()
   │  first call: Jac.get_console() → creates JacConsole, calls .init()
   │  subsequent calls: returns cached _console_instance
   │
3. JacConsole.init()
   │  self.use_emoji = _should_use_emoji()   # reads NO_EMOJI, TERM, platform
   │  self.use_color = _should_use_color()   # reads NO_COLOR, TERM
   │
4. JacConsole.error("Disk full", hint=None, emoji=True)
   │  prefix = '✖'  (emoji=True and use_emoji=True)
   │  _get_pretty_stderr()  → Console(file=sys.stderr)  [fresh instance]
   │  .print("[bold red]✖ Error:[/] Disk full")
   │
5. Console.print("[bold red]✖ Error:[/] Disk full")
   │  is_terminal = sys.stderr.isatty()  → True (interactive session)
   │  _no_color = False  (NO_COLOR not set)
   │  → render_markup("[bold red]✖ Error:[/] Disk full", base_style='')
   │
6. render_markup(...)
   │  Finds [bold red] at pos 0 → pushes 'bold red' onto stack
   │  Text "✖ Error:" → Style('bold red').render("✖ Error:")
   │     _parse(): STYLES['bold']='1', _parse_color('red')=('31',) → codes='1;31'
   │     render(): "\x1b[1;32m✖ Error:\x1b[0m"  (bright red bold)
   │  Finds [/] → pops stack
   │  Remaining text " Disk full" → no stack → plain text
   │  Returns "\x1b[1;31m✖ Error:\x1b[0m Disk full"
   │
7. Console.print writes to sys.stderr:
   "\x1b[1;31m✖ Error:\x1b[0m Disk full\n"
   │
8. Terminal renders:   ✖ Error: Disk full
                       ^^^^^^^^^^^^^ bold red   ^^^^^^^^^ plain
```

---

## 6. Environment Variables Reference

| Variable | Effect | Checked by |
|---|---|---|
| `NO_COLOR` | Disables all ANSI color output | jacpretty `Console.__init__`, `JacConsole._should_use_color` |
| `NO_EMOJI` | Disables emoji characters | `JacConsole._should_use_emoji` |
| `TERM=dumb` | Disables both color and emoji | `_should_use_emoji`, `_should_use_color` |
| `WT_SESSION` | Enables emoji on Windows (set by Windows Terminal) | `_should_use_emoji` |

When color is disabled by `NO_COLOR`:

- On TTY: `Console.print` skips markup rendering and strips tags
- On non-TTY: tags are already stripped by the `elif markup` branch

When emoji is disabled:

- `success()` shows `[OK]` instead of `✔`
- `error()` shows `[ERROR]` instead of `✖`
- `warning()` shows `[WARNING]` instead of `⚠`
- `info()` shows `[INFO]` instead of `ℹ`
- `print_file_change()` shows `CHANGED:` / `CREATED:` / `DELETED:` instead of emoji
- `print_watching()` shows no prefix instead of `👀`

---

## 7. ANSI Escape Code Primer

ANSI SGR (Select Graphic Rendition) sequences have the form:

```
ESC [ <codes> m
```

Where `ESC` is byte `0x1B` (`\x1b`, `\033`), `[` is a literal bracket, `<codes>` is
one or more semicolon-separated numbers, and `m` terminates the sequence.

`\x1b[0m` — reset all attributes to default.

Common codes used by jacpretty:

| Code | Meaning |
|---|---|
| `1` | Bold |
| `2` | Dim |
| `3` | Italic |
| `4` | Underline |
| `5` | Blink |
| `7` | Reverse |
| `8` | Conceal |
| `9` | Strikethrough |
| `30`–`37` | Foreground: black–white |
| `40`–`47` | Background: black–white |
| `90`–`97` | Foreground: bright black–bright white |
| `100`–`107` | Background: bright black–bright white |
| `38;2;R;G;B` | Foreground: 24-bit RGB true color |
| `48;2;R;G;B` | Background: 24-bit RGB true color |
| `38;5;N` | Foreground: 256-palette color N |
| `48;5;N` | Background: 256-palette color N |

Combined styles use `;` between codes in a single sequence:
`\x1b[1;31m` — bold red. `\x1b[1;31;44m` — bold red on blue background.

---

## 8. Markup Tag Reference

All markup is in the form `[style definition]text[/]`. The style definition is the
same syntax as `Style(definition)`.

### Named colors (foreground)

`[black]` `[red]` `[green]` `[yellow]` `[blue]` `[magenta]` `[cyan]` `[white]`
`[bright_black]` `[bright_red]` `[bright_green]` `[bright_yellow]`
`[bright_blue]` `[bright_magenta]` `[bright_cyan]` `[bright_white]`

### Background colors

`[on red]` `[on bright_blue]` etc. — same names, prefixed with `on`

### Styles

`[bold]` `[dim]` `[italic]` `[underline]` `[blink]` `[reverse]` `[conceal]` `[strike]`

### Aliases

`[b]` `[d]` `[i]` `[u]` `[r]` `[s]` `[c]`

### Combined

`[bold red]` `[bold red on blue]` `[italic bright_yellow on bright_black]`

### Extended colors

`[#ff6b6b]` — hex RGB foreground
`[rgb(255,0,128)]` — RGB foreground
`[color(196)]` — 256-palette foreground
`[white on #6c5ce7]` — combining name foreground with hex background

### Closing

`[/]` — closes the innermost open tag (tag name in closing tags is ignored)

### Nesting

```
[bold]outer [red]inner[/] back to bold[/]
```

Inside `[red]`: active stack is `['bold', 'red']`, rendered as `Style('bold red')`.
After `[/]`: stack is `['bold']`, rendered as `Style('bold')`.
