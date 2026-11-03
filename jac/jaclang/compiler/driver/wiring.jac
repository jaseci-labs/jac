import hashlib;
import os;
import from collections.abc { Iterator }
import from contextlib { contextmanager }
import from contextvars { ContextVar }

glob ARCH_FILE_NAME: str = "archwire.jac",
     SKIPPED_PROJECT_DIRS: tuple[str, ...] = ("node_modules", "__pycache__"),
     RECORDS_FORMAT: int = 4,
     STDLIB_MODULES: frozenset[str] = frozenset(
         {
             "__future__",
             "_abc",
             "_aix_support",
             "_android_support",
             "_apple_support",
             "_ast",
             "_ast_unparse",
             "_asyncio",
             "_bisect",
             "_blake2",
             "_bz2",
             "_codecs",
             "_codecs_cn",
             "_codecs_hk",
             "_codecs_iso2022",
             "_codecs_jp",
             "_codecs_kr",
             "_codecs_tw",
             "_collections",
             "_collections_abc",
             "_colorize",
             "_compat_pickle",
             "_contextvars",
             "_csv",
             "_ctypes",
             "_curses",
             "_curses_panel",
             "_datetime",
             "_dbm",
             "_decimal",
             "_elementtree",
             "_frozen_importlib",
             "_frozen_importlib_external",
             "_functools",
             "_gdbm",
             "_hashlib",
             "_heapq",
             "_hmac",
             "_imp",
             "_interpchannels",
             "_interpqueues",
             "_interpreters",
             "_io",
             "_ios_support",
             "_json",
             "_locale",
             "_lsprof",
             "_lzma",
             "_markupbase",
             "_md5",
             "_multibytecodec",
             "_multiprocessing",
             "_opcode",
             "_opcode_metadata",
             "_operator",
             "_osx_support",
             "_overlapped",
             "_pickle",
             "_posixshmem",
             "_posixsubprocess",
             "_py_abc",
             "_py_warnings",
             "_pydatetime",
             "_pydecimal",
             "_pyio",
             "_pylong",
             "_pyrepl",
             "_queue",
             "_random",
             "_remote_debugging",
             "_scproxy",
             "_sha1",
             "_sha2",
             "_sha3",
             "_signal",
             "_sitebuiltins",
             "_socket",
             "_sqlite3",
             "_sre",
             "_ssl",
             "_stat",
             "_statistics",
             "_string",
             "_strptime",
             "_struct",
             "_suggestions",
             "_symtable",
             "_sysconfig",
             "_thread",
             "_threading_local",
             "_tkinter",
             "_tokenize",
             "_tracemalloc",
             "_types",
             "_typing",
             "_uuid",
             "_warnings",
             "_weakref",
             "_weakrefset",
             "_winapi",
             "_wmi",
             "_zoneinfo",
             "_zstd",
             "abc",
             "annotationlib",
             "antigravity",
             "argparse",
             "array",
             "ast",
             "asyncio",
             "atexit",
             "base64",
             "bdb",
             "binascii",
             "bisect",
             "builtins",
             "bz2",
             "cProfile",
             "calendar",
             "cmath",
             "cmd",
             "code",
             "codecs",
             "codeop",
             "collections",
             "colorsys",
             "compileall",
             "compression",
             "concurrent",
             "configparser",
             "contextlib",
             "contextvars",
             "copy",
             "copyreg",
             "csv",
             "ctypes",
             "curses",
             "dataclasses",
             "datetime",
             "dbm",
             "decimal",
             "difflib",
             "dis",
             "doctest",
             "email",
             "encodings",
             "ensurepip",
             "enum",
             "errno",
             "faulthandler",
             "fcntl",
             "filecmp",
             "fileinput",
             "fnmatch",
             "fractions",
             "ftplib",
             "functools",
             "gc",
             "genericpath",
             "getopt",
             "getpass",
             "gettext",
             "glob",
             "graphlib",
             "grp",
             "gzip",
             "hashlib",
             "heapq",
             "hmac",
             "html",
             "http",
             "idlelib",
             "imaplib",
             "importlib",
             "inspect",
             "io",
             "ipaddress",
             "itertools",
             "json",
             "keyword",
             "linecache",
             "locale",
             "logging",
             "lzma",
             "mailbox",
             "marshal",
             "math",
             "mimetypes",
             "mmap",
             "modulefinder",
             "msvcrt",
             "multiprocessing",
             "netrc",
             "nt",
             "ntpath",
             "nturl2path",
             "numbers",
             "opcode",
             "operator",
             "optparse",
             "os",
             "pathlib",
             "pdb",
             "pickle",
             "pickletools",
             "pkgutil",
             "platform",
             "plistlib",
             "poplib",
             "posix",
             "posixpath",
             "pprint",
             "profile",
             "pstats",
             "pty",
             "pwd",
             "py_compile",
             "pyclbr",
             "pydoc",
             "pydoc_data",
             "pyexpat",
             "queue",
             "quopri",
             "random",
             "re",
             "readline",
             "reprlib",
             "resource",
             "rlcompleter",
             "runpy",
             "sched",
             "secrets",
             "select",
             "selectors",
             "shelve",
             "shlex",
             "shutil",
             "signal",
             "site",
             "smtplib",
             "socket",
             "socketserver",
             "sqlite3",
             "sre_compile",
             "sre_constants",
             "sre_parse",
             "ssl",
             "stat",
             "statistics",
             "string",
             "stringprep",
             "struct",
             "subprocess",
             "symtable",
             "sys",
             "sysconfig",
             "syslog",
             "tabnanny",
             "tarfile",
             "tempfile",
             "termios",
             "textwrap",
             "this",
             "threading",
             "time",
             "timeit",
             "tkinter",
             "token",
             "tokenize",
             "tomllib",
             "trace",
             "traceback",
             "tracemalloc",
             "tty",
             "turtle",
             "turtledemo",
             "types",
             "typing",
             "unicodedata",
             "unittest",
             "urllib",
             "uuid",
             "venv",
             "warnings",
             "wave",
             "weakref",
             "webbrowser",
             "winreg",
             "winsound",
             "wsgiref",
             "xml",
             "xmlrpc",
             "zipapp",
             "zipfile",
             "zipimport",
             "zlib",
             "zoneinfo",
             "_precompiled",
             "MANIFEST.json",
             "utf_8",
             "latin_1",
             "ascii",
             "node_modules",
             "__pycache__"
         }
     );

obj WireBinding {
    has provider: str,
        form: str,
        name: str = "",
        alias: str = "",
        injected: bool = True;

    def key -> tuple[str, str, str, str];
    def is_module_form -> bool;
    def bound_name -> str;
}

obj PatternRec {
    has dotted: str,
        is_glob: bool = False,
        is_string: bool = False,
        text: str = "";

    def matches(module: str) -> bool;
}

obj RuleRec {
    has name: str,
        sources: list[PatternRec] = [],
        targets: list[PatternRec] = [],
        item_names: set[str] = set(),
        is_open: bool = False;
}

obj WireRec {
    has provider: str,
        consumers: list[str] = [],
        is_module_form: bool = False,
        is_absorb: bool = False,
        is_typed: bool = False,
        is_comptime: bool = False,
        is_injected: bool = True,
        alias: str = "",
        items: list[tuple[str, str]] = [],
        line: int = 0,
        col: int = 0,
        lb_line: int = 0,
        lb_col: int = 0,
        payload: str = "",
        index: int = 0;

    def bindings -> list[WireBinding];
}

obj WiringSpec {
    has root_dir: str,
        path: str,
        parse_failed: bool = False,
        wires: list[WireRec] = [],
        rules: list[RuleRec] = [],
        _raw: dict[str, list[WireRec]] = {},
        _raw_by_prefix: dict[str, list[str]] = {},
        _by_consumer: dict[str, list[WireRec]] = {},
        _splits: dict[str, (tuple[str, list[str]] | None)] = {},
        _annex_cache: dict[str, str] = {},
        _policy_digest: str = "",
        _project_modules: (list[str] | None) = None,
        _unnamed_modules: (list[str] | None) = None,
        _prefix: (str | None) = None,
        _owned_dirs: dict[str, bool] = {},
        _scopes: dict[tuple[str, int], list[list[str]]] = {},
        _wire_lines: dict[int, list[WireRec]] = {},
        package_prefix: str = "";

    def postinit -> None;
    def module_name(path: str) -> (str | None);
    def _local_name(name: str) -> (str | None);
    def import_prefix -> str;
    def import_name(name: str) -> str;
    def module_file(name: str) -> (str | None);
    def _variant_file(local: str, parts: list[str]) -> (str | None);
    def owns(path: str) -> bool;
    def split_consumer(path: str) -> (tuple[str, list[str]] | None);
    def consumer_scope(consumer: str, wire: WireRec) -> list[str];
    def consumer_scopes(consumer: str, wire: WireRec) -> list[list[str]];
    def wire_for_import(
        stmt: Import, consumer: str, taken: set[int]
    ) -> (WireRec | None);

    def wire_import(wire: WireRec) -> (Import | None);
    def is_package_dir(name: str) -> bool;
    def project_modules -> list[str];
    def ruled_modules -> list[str];
    def ruled_as(consumer: str) -> list[str];
    def _scan_modules(directory: str, found: list[str], seen: set[str]) -> None;
    def consumer_wires(consumer: str) -> list[WireRec];
    def is_covered(consumer: str) -> bool;
    def _wire_pieces(wire: WireRec) -> list[tuple[int, int, str]];
    def annex_source(consumer: str) -> (str | None);
    def digest_for(consumer: str) -> str;
    def consumer_bindings(
        consumer: str, scope: (list[str] | None) = None
    ) -> dict[tuple[str, str, str, str], WireRec];

    def import_provider(path_node: ModulePath) -> (str | None);
    def import_bindings(imp: Import) -> list[tuple[WireBinding, UniNode]];
    def wire_suggestion(binding: WireBinding, consumer: str) -> str;
    def rules_governing(provider: str, consumer: str, local: bool) -> list[RuleRec];
    def rules_admitting(provider: str, consumer: str, local: bool) -> list[RuleRec];
    def top_package(module: str) -> str;
    def top_pattern(top: str) -> PatternRec;
    def needs_rule(provider: str, consumer: str, local: bool) -> bool;
    def edge_rule(source: str, targets: list[str]) -> RuleRec;
    static def admitted_names(rules: list[RuleRec]) -> (set[str] | None);
}

glob _spec_cache: dict[str, tuple[str, WiringSpec]] = {},
     _resolution: ContextVar[dict[str, WiringSpec | None] | None] = ContextVar(
         'jac_wiring_resolution', `default=None
     ),
     _building: set[str] = set();

@contextmanager
def wiring_scope -> Iterator[None];

def is_arch_file(path: str) -> bool;
def arch_file_for(path: str) -> (str | None);
def wiring_for_path(path: str) -> (WiringSpec | None);
def wiring_annex_for(file_path: str) -> (WovenAnnex | None);
def wiring_digest_for(file_path: str) -> str;
def place_wired_imports(mod: Module) -> None;
def pattern_record(pattern: ModulePattern, scope: str = "") -> PatternRec;
def rule_record(rule: ImportRule) -> RuleRec;
def wire_records(wire: ImportWire, source: str = "") -> list[WireRec];
def module_records(mod: Module, source: str) -> tuple[list[WireRec], list[RuleRec]];
def parse_records(source: str, path: str) -> tuple[bool, list[WireRec], list[RuleRec]];
def wire_block(provider: str, consumer: str) -> str;
def block_relative(block: str, name: str) -> str;
def wire_text(
    block: str,
    binding: WireBinding,
    consumers: list[str],
    items: (list[tuple[str, str]] | None) = None
) -> str;

def render_wiring(
    spec: WiringSpec, facts: list[tuple[str, WireBinding]], rules: list[RuleRec]
) -> str;

def wiring_facts(wires: list[WireRec]) -> list[tuple[str, WireBinding]];
def rule_text(rule: RuleRec) -> str;
def rule_name_for(top: str) -> str;
def propose_rules(
    spec: WiringSpec, facts: list[tuple[str, WireBinding]], rules: list[RuleRec]
) -> list[RuleRec];

def _wire_name(name: str) -> str;
def _target_text(consumers: list[str], items: (list[tuple[str, str]] | None)) -> str;
def _entry_order(
    pair: tuple[list[str], (list[tuple[str, str]] | None)]
) -> tuple[list[str], list[tuple[str, str]]];

def _block_text(block: str, body: list[str]) -> str;
def canonical_wiring_source(source: str, path: str) -> str;
def prune_wiring_source(source: str, path: str, dropped: Callable[[str], bool]) -> str;

def encode_records(
    parse_failed: bool, wires: list[WireRec], rules: list[RuleRec]
) -> str;

def decode_records(text: str) -> (tuple[bool, list[WireRec], list[RuleRec]] | None);
def _split_list(text: str) -> list[str];
def _encode_patterns(patterns: list[PatternRec]) -> str;
def _decode_patterns(text: str) -> (list[PatternRec] | None);
def import_prefix_for(root_dir: str) -> str;
def is_stdlib_module(name: str) -> bool;

def _load_spec(root_dir: str, arch_path: str) -> WiringSpec;
def scope_path_of(nd: UniNode) -> (list[str] | None);
def is_positional_import(imp: Import) -> bool;
def scope_owners(mod: Module) -> dict[str, list[(Ability | ImplDef)]];
def inject_into_scope(owner: (Ability | ImplDef), stmt: UniNode) -> None;
def local_module_name(root_dir: str, path: str) -> (str | None);
def variant_base_file(path: str) -> (str | None);
def unnamed_module_label(root_dir: str, path: str) -> (str | None);
