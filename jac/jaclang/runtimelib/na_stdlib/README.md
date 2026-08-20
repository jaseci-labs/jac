# Bundled native standard library (`na_stdlib`)

Pure-Jac `.jac` modules shipped with jaclang that implement a
Python-congruent **standard library for the native (na) compiler pathway**
(issues [#6404] / [#6940]). This is **Mechanism B**: ordinary Jac compiled and
linked like user code, with zero per-module backend work.

## How resolution works

`jaclang.jac0core.codeinfo.resolve_native_module` is the single shared resolver
used by `BoundaryAnalysisPass`, `NaIRGenPass`, and `NativeCompilePass`. It
searches **nearest-wins**:

1. the importing project's own tree (a flat sibling, then the dotted hierarchy
   walked up to the filesystem root), then
2. this bundled root (`native_stdlib_root()`), which is native **by
   location** -- its modules are plain `.jac` files. At either step a per-OS
   variant `<name>.<os>.jac` (e.g. `_dirent_native.darwin.jac`) is probed
   before the plain `<name>.jac`.

So `import from os.path { normpath }` binds CPython's `posixpath` on the sv
(Python) pathway and `na_stdlib/os/path.jac` on the na (native) pathway (the
*same source* on both), while a user module of the same name always shadows the
bundled one. A bundled module links through the existing cross-module machinery
(binding population, then extern forward-decl, then `link_in`), on both the AOT
(`jac nacompile`) and JIT execution paths.

## Shipped modules

- **`os/path.jac`** (#6940 Phase 0, extended #8201) -- pure-string POSIX path
  helpers (`normpath`, `dirname`, `basename`, `split`, `splitext`, `isabs`,
  `join`, `abspath`, plus `relpath` and `normcase`). `relpath` is CPython's
  algorithm verbatim: absolutize both sides, drop empty components, walk off
  the shared prefix with `..` for each remaining `start` component, and answer
  `.` when nothing is left. `normcase` is the identity, which is what it is on
  POSIX.
- **`json.jac`** (#6940 Phase 1) -- a recursive-descent `loads` over boxed
  `any` (dict/list/str/int/float/bool/None) plus a `dumps` serializer matching
  CPython's default `(', ', ': ')` separators and insertion-ordered keys.
  One documented divergence: only the control set + JSON metacharacters are
  escaped, so congruence holds for ASCII payloads (`ensure_ascii` of
  non-ASCII is a follow-up). (`dumps` of floats now matches CPython: native
  `str(float)` produces the shortest-round-trip repr -- #6940 Phase 0.3,
  pinned byte-for-byte against CPython in the native suite.)
- **`datetime.jac`** (#6940 Phase 1 / #6951) -- a UTC `datetime` and
  `timezone` pair. `timezone.utc` is a class attribute and `datetime.now` /
  `datetime.fromtimestamp` are class-level constructors, riding the native
  static-method and class-attribute capability added for #6951. The civil date
  is computed from the POSIX epoch (Hinnant's days->civil) over the `time`
  intercept, so it is exact for a fixed timestamp; `year`/`month`/`day`/`hour`/
  `minute`/`second`, `weekday()`, and `isoformat()` match CPython. SCOPE: UTC /
  fixed-offset only (no tz database, DST, leap seconds, or microseconds).
- **`gzip.jac`** (#6978 Phase 2) -- a Mechanism-B gzip framing over the
  bundled `zlib` floor (no new FFI): `compress(data, compresslevel=9, mtime=0)`
  and `decompress(data)`. gzip is zlib's DEFLATE engine plus an RFC 1952 header,
  CRC-32, and ISIZE trailer, so the surface reuses the `zlib` floor's one-shot
  `compress2` / `uncompress2`. `compress` takes the raw DEFLATE body (the zlib
  stream with its 2-byte header + 4-byte adler32 stripped -- the DEFLATE bytes
  are identical under either frame) and wraps it; the result is byte-identical
  to CPython's `gzip.compress` at the same level/`mtime` (XFL 2 for level 9,
  4 for level < 2, 0 otherwise -- zlib's gzip-header rule, which CPython
  reuses -- and OS byte 255; CPython 3.14 also defaults `mtime` to 0, so the
  defaults agree byte-for-byte). `decompress` walks the members of the stream
  exactly as CPython does: per member it parses the header (honoring the
  FEXTRA / FNAME / FCOMMENT skips; the 2 FHCRC bytes are skipped unverified,
  which is also CPython's behavior), re-frames the remaining input as a zlib
  stream so the member's own trailer bytes stand in for the adler32, inflates
  through `uncompress2` -- whose consumed-source count locates the member
  boundary; the near-certain final adler mismatch (`Z_DATA_ERROR`) and the
  2^-32 coincidence where the trailer bytes equal the output's adler32
  (`Z_OK`) are both accepted -- then enforces gzip's own CRC-32 and ISIZE
  (compared mod 2^32, per RFC 1952, so members over 4 GiB verify the same way
  CPython does) before concatenating the member outputs. The output buffer
  starts at the final-ISIZE hint and grows geometrically on `Z_BUF_ERROR` up
  to DEFLATE's ~1032x expansion ceiling. A member with no end-of-stream
  marker (including a bare header glued onto a trailer) raises, as does
  trailing garbage after the last member -- matching CPython. Error-type
  mapping: the native surface raises `ValueError` with static messages where
  CPython raises `gzip.BadGzipFile` (an `OSError` subclass: bad magic /
  unknown method / CRC / length), `EOFError` (truncation), or `zlib.error`
  (corrupt DEFLATE data). The `GzipFile` class and streaming file API are out
  of scope.
- **`base64.jac`** (#6978 Phase 3) -- self-contained RFC 4648
  base16/base32/base64 (`b16`/`b32`/`b64` encode+decode, `altchars`,
  `standard_`/`urlsafe_` variants) plus RFC 1924 base85 (`b85encode`/`b85decode`,
  the alphabet CPython's `base64.b85encode` uses). A big-endian bit-accumulator
  over `bytes` primitives -- no FFI floor, no big-int -- growing the result in a
  `list[int]` and converting once with `bytes(...)`. Encoding is byte-identical
  to CPython for all 256 byte values; decoding matches the embedded CPython
  3.14 semantics, probed case by case: `b64decode(validate=False)` (the
  default) discards non-alphabet bytes and applies 3.14's end-of-input padding
  rules (so newline-wrapped MIME/PEM input decodes, unpadded input raises
  `Incorrect padding`); `validate=True` implements strict mode with CPython's
  leading/excess/discontinuous-padding errors; `urlsafe_b64decode` accepts
  both the `+/` and `-_` alphabets (CPython translates then decodes); `b16`
  enforces digit-before-odd-length checks; `b32decode` takes `casefold` and
  `map01` and enforces `len % 8` plus CPython's valid pad-count set
  {0,1,3,4,6}; `b85decode` reports CPython's absolute error positions and the
  32-bit overflow check. Error messages match CPython text, raised as
  `ValueError` (CPython raises `binascii.Error`, itself a `ValueError`
  subclass, so `except ValueError` is congruent; the message text is
  identical). SCOPE: the CPython `None` sentinels for `altchars`/`map01` are
  `b""` here (na has no None-able `bytes` parameter), and bad `altchars`/
  `map01` lengths raise `ValueError` where CPython asserts; the Ascii85
  (`a85`) variant is a follow-up.
- **`textwrap.jac`** (#6978 Phase 3) -- the greedy line wrapper (`wrap`,
  `fill`) plus `dedent` and `indent`, a faithful port of CPython's
  `TextWrapper._wrap_chunks`/`_handle_long_word` over primitives (following
  CPython **>= 3.14** long-word semantics -- 3.14 stopped breaking a long word
  when `space_left == 0`, so 3.13-and-earlier output differs exactly there; the
  bundled sv runtime is 3.14 -- plus the `width <= 0` ->
  `ValueError("invalid width ... (must be > 0)")` error path). **WARNING -- default-call divergence:** this module implements
  `break_on_hyphens=False` semantics (words split on whitespace only), but
  CPython's default is `break_on_hyphens=True`; the *same* `wrap(text, width)`
  call therefore returns different lines on sv vs na whenever the text contains
  hyphenated words (e.g. `wrap("well-known", 6)` -> `['well-', 'known']` on sv,
  `['well-k', 'nown']` on na). Keep hyphenated text away from `wrap`/`fill`, or
  pass `break_on_hyphens=False` explicitly on the sv side. All other
  TextWrapper defaults matched (`expand_tabs`, `replace_whitespace`,
  `drop_whitespace`, `break_long_words`, empty indents, no `max_lines`);
  `indent` splits on `"\n"`; `shorten`/`TextWrapper` not provided.
- **`csv.jac`** (#6978 Phase 3) -- `reader` for the default **excel** dialect
  (delimiter `,`, quotechar `"`, `doublequote=True`, `skipinitialspace=False`,
  QUOTE_MINIMAL). Field parsing matches CPython exactly (quoted fields, doubled
  quotes, a quote opening a field only at its start, literal mid-field quotes,
  unterminated quotes, a `\n` inside a quoted region of a single input string,
  empty line -> `[]`). A NUL character parses as an ordinary character,
  matching CPython **>= 3.14** (3.13 and earlier raised
  `csv.Error("line contains NUL")`; the bundled sv runtime is 3.14) -- but the
  native string type drops an embedded NUL byte on concatenation, so while
  field *splitting* around a NUL is congruent, NUL-bearing field *content* is
  not (`"a\x00b"` comes back as `"ab"` on na). Note the native pathway has no
  `csv.Error` type anyway -- if a future error path is added it will surface as
  `ValueError`.
  SCOPE: eager `list[list[str]]` (congruent with `list(csv.reader(...))`), one
  record per input string -- a *record* cannot span two input strings, so
  feeding a file's raw split lines with multi-line quoted fields diverges from
  CPython's file-object mode; `writer`/`DictReader`/`DictWriter`/custom
  dialects not provided.
- **`pprint.jac`** (#6978 Phase 3) -- `pformat` rendering a single-line repr
  with dict keys sorted (CPython `sort_dicts=True`) and Python `repr`
  conventions for str/int/bool/None/list/dict, including full string escaping:
  backslash/quotes, `\n`/`\t`/`\r` short forms, and `\xNN` for the remaining
  C0 controls (0x00-0x1f) and DEL (0x7f). SCOPE: **single-line output only** --
  CPython wraps representations longer than `width=80` across lines, so any
  object whose repr exceeds one line diverges (width-driven wrapping not
  implemented); string dict keys; floats print with CPython's
  shortest-round-trip repr (#6940 Phase 0.3, so the old `%g` divergence is
  gone); bytes > 0x7f pass through unescaped, so *unicode* non-printables
  (e.g. U+00A0, U+200B) are NOT `\uXXXX`-escaped as CPython would -- congruent
  for ASCII and printable-unicode payloads. Out-of-scope value types: `set`
  raises `ValueError("pprint: unsupported value type on native")` instead of
  silently misrendering; other non-JSON values (e.g. object instances) cannot
  be type-discriminated from `None` by the native runtime today (JacVal tags 6
  vs 8 are both invisible to `isinstance`, and `any` truthiness/`is None` are
  not native-compilable), so they render as `"None"` -- a documented
  divergence.
- **`difflib.jac`** (#6978 Phase 3) -- `SequenceMatcher`
  (`ratio`/`get_matching_blocks`/`set_seq1`/`set_seq2`, full 4-arg constructor
  including `autojunk`) and `get_close_matches`, a port of CPython's
  longest-match DP, matching-block recursion, and `__chain_b` popular-element
  pruning (`autojunk=True` and `len(b) >= 200`: elements occurring more than
  `len(b) // 100 + 1` times cannot seed a match, exactly as their exclusion from
  CPython's `b2j`; they still participate in match extension since `bjunk` is
  empty). `get_close_matches` raises CPython's `ValueError`s for `n <= 0` and
  `cutoff` outside `[0.0, 1.0]`. SCOPE: string sequences; `isjunk` accepted but
  ignored (a non-None `isjunk` silently behaves as None -- the remaining
  error-path/behavior divergence); `ratio` is the same IEEE-double value (only
  its `str` rendering would differ);
  `get_opcodes`/`unified_diff`/`ndiff`/`Differ`/`HtmlDiff` not provided.

- **`statistics.jac`** (#7593 item 18) -- double-precision
  `fmean`/`mean`/`median`/`median_low`/`median_high`/`variance`/`pvariance`/
  `stdev`/`pstdev` over generic `[T]` defs, so int and float sequences both
  monomorphize without boxing. SCOPE/divergences: results always compute in
  float (CPython runs exact Fraction arithmetic internally and `median` of an
  odd-count sequence returns the element itself, preserving int), and errors
  raise `ValueError` directly (CPython's `StatisticsError` subclasses
  `ValueError`, so `except ValueError` behaves identically on both backends).

- **`shutil.jac`** (#7593 item 18) -- `which`/`copyfile`/`copy`/`copy2`/
  `move`/`rmtree` over the native os intrinsics (getenv, path.join,
  path.isdir, path.isfile, path.basename) plus direct libc (access, unlink,
  rmdir, rename, opendir/readdir/closedir). The dirent d_name offset follows
  the glibc x86-64/aarch64 layout (d_ino 8 + d_off 8 + d_reclen 2 + d_type 1
  = 19), matching the platform scope of the other libc-backed modules.
  SCOPE/divergences: copy/copy2 duplicate bytes but do not yet preserve
  mode/mtime metadata; rmtree follows the isdir predicate, so directory
  symlinks are recursed into rather than unlinked; errors raise `ValueError`
  rather than CPython's `OSError` subclasses.

- **`keyword.jac`** (#7593 item 18) -- `kwlist`/`softkwlist`/`iskeyword`/
  `issoftkeyword` mirroring CPython's lists verbatim, ordering included
  (stable since 3.10's soft-keyword additions).

- **`fractions.jac`** (#6978 Phase 2) -- a pure-Jac (Mechanism B) `Fraction`
  over native `int`, normalized on construction via Euclid's GCD with the sign
  carried by the numerator and the denominator kept positive (CPython's value
  model). Construction/reduction (`Fraction(n, d)`), `numerator` /
  `denominator`, and `str()` match CPython exactly. Arithmetic and ordering are
  the CPython dunder methods (`__add__` / `__sub__` / `__mul__` / `__truediv__`
  / `__eq__` / `__lt__`). The na fixture calls them directly (`a.__add__(b)`)
  where the sv fixture uses `+` / `<`, and the resulting *values* are
  congruent; the operator spellings lower too, since the backend now routes a
  binary operator over an archetype through `_emit_arch_dunder_binop`
  (forward magic, then the reflected one) against
  `type_system.operations.BINARY_OPERATOR_MAP`.
  Float/Decimal/string construction is out of scope. SCOPE: native `int` is a
  fixed-width i64, so the cross-multiplications in `__add__` / `__lt__` (and
  friends) silently overflow once intermediate products exceed 2^63, where
  CPython's bignum `Fraction` stays exact; keep components comfortably below
  ~3x10^9 (sqrt of i64 max).

- **`pathlib.jac`** (#8201) -- a `Path` that carries one normalized POSIX
  string and derives every member from it, which is CPython's `PurePosixPath`
  value model: construction splits on `/`, drops empty and `.` components,
  keeps `..` (collapsing one lexically is not symlink-safe), and preserves the
  POSIX root -- `/`, or the special `//` a leading double slash denotes, which
  `///` does not. An all-empty result renders as `.`, so `str(Path(""))` is
  `"."`. Provided surface: `Path(str)`, `Path(Path)`, `str()` / f-string
  interpolation, truthiness, `.name`, `.stem`, `.parent`, `/`, `.resolve()`,
  `.exists()`, `.is_dir()`. Anything outside it does not exist on the type, so
  a native compile that reaches for one fails with "Type `Path` has no
  attribute ..." rather than silently answering wrong.
  `.stem` follows `os.path.splitext`, which is what CPython's own `stem`
  reduces to: the last `.` splits the name only when some non-`.` character
  precedes it, so `.bashrc` and `..` are entirely stem, while a trailing dot
  does split (`b.` has stem `b`) -- that last case is CPython **>= 3.14**
  behavior (3.13 and earlier answered `b.`) and the bundled sv runtime is 3.14.
  SCOPE: POSIX only (no Windows flavour, no drive letter, no
  `PureWindowsPath`). `.resolve()` absolutizes against `os.getcwd()`, resolves
  symlinks through the `realpath(3)` intercept, then collapses `.`/`..`
  lexically -- byte-identical to CPython for a path that exists, but for a path
  whose components do not all exist `realpath(3)` reports failure and the
  answer falls back to the lexical collapse, so a symlink sitting on an
  existing *prefix* of a missing path is not resolved the way CPython's
  component walk resolves it. Comparison, hashing, iteration, `.parts`,
  `.suffix`, `.glob`, `.open`, `.cwd()`, `.home()`, and the whole I/O surface
  are not provided.

- **`fnmatch.jac`** (#8201) -- `fnmatch` and `fnmatchcase` as a direct
  backtracking glob matcher (`*`, `?`, `[seq]`, `[!seq]`, ranges), since the
  native pathway has no regex engine to translate into. The bracket scanner
  reproduces CPython's `translate` rules exactly: a `]` immediately after `[`
  or `[!` is a literal member, an unterminated `[` degrades to a literal `[`,
  and a `-` first or last in a class is a literal `-`. Pinned against CPython
  over a 29-pattern by 14-name grid. `normcase` is the identity, which is what
  it is on POSIX, so `fnmatch` and `fnmatchcase` agree here; on Windows
  CPython's `fnmatch` would case-fold first. `filter` and `translate` are not
  provided.

- **`logging.jac`** (#8201) -- `basicConfig`, `getLogger(name)`, the level
  constants, and `.debug`/`.info`/`.warning`/`.error`/`.critical` on both the
  logger and the module. Records go to stderr, which is where CPython's
  last-resort/`basicConfig` handler puts them, rendered through the
  `%(levelname)s` / `%(name)s` / `%(message)s` fields of the active format
  (default `BASIC_FORMAT`, i.e. `LEVEL:name:message`). The WARNING default
  threshold is honored, so `.debug`/`.info` are dropped until `basicConfig`
  lowers it, matching CPython. SCOPE: no handlers, formatters, filters, or
  logger hierarchy -- there is one process-wide level and one format, so
  `Logger.setLevel` sets *the* level rather than that logger's, and
  `basicConfig` is not the once-only call it is on CPython (a second call
  reconfigures). `%(asctime)s` and the other `%`-fields are left in the output
  verbatim rather than substituted; `filename`/`filemode`/`stream`/`handlers`
  are accepted and ignored, so file logging silently stays on stderr.
  Lazy `%`-args (`log.info("x %s", y)`) and `exc_info` are not provided.

- **`contextvars.jac`** (#8201, held back by #8220 until #8229 and #8230
  landed) -- `ContextVar[T]` as a single process-wide cell: `ContextVar(name)`
  and `` ContextVar(name, `default=...) ``, `.name`, `.get()`, `.get(default)`
  and `.set(value)`. `get` walks CPython's precedence -- the value last `set`,
  else the default the call passed, else the default the constructor took,
  else `LookupError(name)`.
  SCOPE: `None` is the sentinel for *both* "no value" and "no default", where
  CPython keys the second step on whether the argument was **passed**, so an
  explicit `get(None)` reads as an omitted argument: on an unset variable it
  answers the constructor default, or raises, where CPython answers `None`.
  (A variadic `get(*fallback: T)` would carry the presence bit exactly, but a
  variadic parameter of the erased type segfaults the native binary, so this
  waits on that gap.) `None` is likewise the unset marker in the value slot,
  so `set(None)` on a `ContextVar[X | None]` reads back as unset.
  There is also one cell per variable rather than one per context, because
  the native pathway has neither asyncio tasks nor threads to separate them,
  so `copy_context`, `Context.run`, and the `Token` that `set` returns
  (with `reset`) are not provided -- `set` answers `None`. A reference type
  argument (an archetype, `list`, `dict`) lowers; a **scalar** one
  (`int`, `float`, `bool`, and `str`, which is a by-value descriptor
  natively) is refused at the construction site with `E5092` naming the
  instantiation, because a generic archetype is laid out once for every
  instantiation and its `T` slot is a raw pointer (#8229).

The syscall-backed `os` / `os.path` entry points (`makedirs`, `realpath`,
`mkdir`, `exists`, `getmtime`, `normcase`, ...) are Mechanism-A/H compiler
intercepts, reached via the flat `import os`, not bundled here (see
`compiler/passes/native/na_ir_gen/os.impl.jac`). `os.sep` and its
sibling module attributes (`extsep`, `pardir`, `curdir`, `pathsep`, `linesep`,
`devnull`) resolve the same way; `os.altsep` is `None` on POSIX and is not
provided. Note that `getmtime` / `getsize` answer `-1` for a path that cannot
be stat'd, where CPython raises `OSError` -- the established native behavior
for this family.

The **pure-string** members are the bundled `os/path.jac` above and are
reached by importing them (`import from os.path { normpath, relpath }`).
`abspath`, `splitext`, `relpath` and `normpath` are *only* reachable that way:
they are not compiler intercepts, because each needs `normpath`'s component
stack (or, for `splitext`, a tuple return), which is the sort of work
Mechanism B exists to avoid writing twice. Reaching for one through the flat
`import os` fails loudly naming the member rather than answering wrong.

## Adding a module

1. Drop `<name>.jac` (or `<pkg>/<name>.jac` for a dotted import) here,
   exporting its API with `def:pub`. If a module needs platform-specific
   code, add a `<name>.<os>.jac` variant (e.g. `_dirent_native.darwin.jac`);
   it wins over the plain file on that OS.
2. Use only the native-supported subset; prefer typed containers
   (`list[str]`, `dict[str, any]`). A bare `list = []` defaults to `i64`
   elements. An empty `list[any] = []` then grown with `.append(x)` lowers and
   boxes correctly, but a `list[any]` *literal* with scalar elements
   (`[1, 2, 3]`) does not yet box them -- build `any`-lists via `.append` (or
   `json.loads`). `dict[str, any]` literals box their values fine. Unbox a
   boxed scalar before operating on it (`i: int = some_any; str(i)`), and check
   container/None branches with `isinstance` -- `x is None` does not lower to a
   branch condition on the native pathway.
3. Add a tri-backend equivalence fixture
   (`jac/jaclang/compiler/tests/fixtures/prim_<name>.jac`) and register it in
   `test_prim_equivalence.jac` with `require=["na"]` so sv/na congruence is
   enforced, not assumed. Keep the `na { }` block self-contained (a
   module-level helper called from native code lowers to an unregistered
   interop stub) and split a large case body across several small na helpers
   mutating one result dict -- one giant function is beyond what the na
   backend JITs reliably today.

## Mechanism / portability

- **B (here)**: pure-Jac on primitives; portable to every native target
  (ELF/Mach-O/PE/WASM). Preferred. Example: `os/path.jac`.
- **A**: compiler intrinsics over libm/libc/syscalls (`math`, `time`, `os`,
  `random`, `struct`); native-host only.
- **F**: thin FFI wrappers over a system C library; native-host only. Examples:
  `_ssl_native.jac` -- the floor the verifying TLS client `ssl` is built on,
  over OpenSSL `libssl`/`libcrypto` (issue #6978 Phase 1); `_socket_native.jac`
  over libc BSD sockets; `_hashlib_native.jac` over the bundled `libcrypto`.
  An F module declares its C entry points with `import from <lib> { def ...; }`.
  `urllib/request.jac` (`urlopen`) is a pure-Jac surface over the `socket` +
  `ssl` floors -- it links no foreign C beyond libc/libssl/libcrypto (no
  libcurl) -- pinned sv<->na congruent by `test_urllib_equivalence.jac` against a
  loopback HTTP server.

Functions that need a syscall (`os.path.realpath`, `exists`, ...) stay as
Mechanism-A intercepts, not here.

## Mechanism F: FFI floor + pure-Jac surface (`zlib`)

`zlib` is the first Mechanism-F module (#6940 Phase 2): the DEFLATE engine is
never reimplemented; it is the system `libz`, reached through a thin FFI floor,
exactly as CPython's `zlib` wraps the same library. The split is deliberate:

- `_zlib_native.jac`: the **FFI floor**. An `import from z { def ... }` block
  binds `libz` by logical name (`z` → `libz.so` / `libz.dylib` / `z.dll`) and
  re-exports each entry behind a `z_`-prefixed wrapper.
- `zlib.jac`: the **pure-Jac surface**: the Python-shaped API
  (`compress` / `decompress` / `crc32` / `adler32`, CPython argument orders and
  defaults), layered on the floor.

Two conventions make foreign byte I/O work:

- A **`bytes` parameter on a foreign signature** lowers to a raw `i8*` to the
  element data (the C buffer-protocol convention), not the internal jacbytes
  `{ i64 len, [n x i8] }` struct pointer; the element count travels through a
  separate explicit length parameter.
- A clib extern is declared into the **shared native symbol table under its C
  symbol name**, so a libz symbol that collides with a public surface name (e.g.
  `crc32`) would shadow it. Bind the non-colliding variant instead; the floor
  uses `crc32_z` / `adler32_z`.

`bz2` (#6978 Phase 2) follows the same two-file split: `_bz2_native.jac`
wraps the one-shot `BZ2_bzBuffToBuffCompress` / `BZ2_bzBuffToBuffDecompress`
buffer API (logical name `bz2` -> `libbz2`; the in-process JIT dlopens the
system library, while AOT `nacompile` consumes the bundled `libbz2.a`), and
`bz2.jac` is the Python-shaped `compress(data, compresslevel=9)` /
`decompress(data)` surface. `compress` produces a single bzip2 stream
byte-identical to CPython's (same default `workFactor`); note `libbz2`'s
one-shot API is 32-bit throughout -- `sourceLen` is a by-value C `unsigned int`
(lowered as `u32`, unlike zlib's LP64 8-byte `uLong`) and the in/out `destLen`
is an `unsigned int*` (a 4-byte cell) -- so both directions reject inputs
larger than 4 GiB with a `ValueError` (CPython, which streams internally, has
no such limit). SCOPE and divergences from CPython (3.14):

- One-shot buffer API only: incremental `BZ2Compressor` / `BZ2Decompressor`
  and the file API are out of scope.
- Multi-stream inputs return only the first stream's data (silent partial
  output); CPython concatenates every stream.
- Corrupt input raises `ValueError` (carrying the libbz2 error code) where
  CPython raises `OSError("Invalid data stream")`; truncated streams raise
  `ValueError` on both. Out-of-range compresslevels raise `ValueError` on both
  (the native surface reports libbz2's `BZ_PARAM_ERROR` rather than CPython's
  bounds message).
- `decompress` grows its output buffer on `BZ_OUTBUFF_FULL` up to a ceiling of
  `sourceLen * 1024 + 64 MiB` (clamped to 4 GiB); a valid stream that expands
  past that ceiling raises a distinct `ValueError` ("decompressed output
  exceeds the one-shot API limit") where CPython, which streams, would succeed.

Mechanism-F modules are native-host only: a wasm target gets a clean link error
rather than silent breakage.

[#6404]: https://github.com/jaseci-labs/jaseci/issues/6404
[#6940]: https://github.com/jaseci-labs/jaseci/issues/6940
