---
description: Every standard-library module a native program imports, with what each is and how complete it is next to CPython's, and the modules that stay CPython's.
keywords: standard-library modules, stdlib, module list, array.array, array.typecodes, calendar, colorsys, gettext, graphlib, graphlib.TopologicalSorter, ipaddress, keyword.iskeyword, keyword.issoftkeyword, locale, mimetypes, operator.itemgetter, operator.attrgetter, operator.methodcaller, platform.system, platform.machine, platform.python_version, secrets, tomllib, uuid
---
# Standard-library modules

These are the modules a native program imports by Python's names and gets natively: jac's own
modules, written in Jac, compiled into the program. Each has the interface and the behavior of
CPython 3.15's module of the same name, as far as it goes ([The library](index.md),
`jac docs library`, says what they are held to and how an import finds them). Any other module
of Python's standard library is CPython's, reached through the embedded CPython: see
[Modules that are CPython's](#modules-that-are-cpythons) below.

```jac
import base64;
import heapq;
import ipaddress;
import statistics;
import textwrap;
import tomllib;
import glob;
import from string { Template }

with entry {
    print(base64.b64encode(b"jac"), base64.b64decode("amFj"));
    tasks = [(3, "write"), (1, "plan"), (2, "build")];
    heapq.heapify(tasks);
    print(heapq.heappop(tasks), heapq.nsmallest(2, [5, 1, 4, 2]));
    print(statistics.mean([1, 2, 3, 4]), statistics.median([4, 1, 3, 2]));
    print(statistics.mean([1, 2, 3]), statistics.variance([1, 3]), statistics.mean([1.0, 3.0]));
    print(statistics.median_low([4, 1, 3, 2]), statistics.median_high([4, 1, 3, 2]));
    try {
        ipaddress.ip_network("10.0.0.1/24");
    } except ValueError as e {
        print(e, ipaddress.ip_network("10.0.0.1/24", strict=False));
    }
    print(textwrap.fill("the quick brown fox jumps over the lazy dog", width=16));
    conf = tomllib.loads("[app]\nname = \"demo\"\nport = 8080\n");
    print(conf["app"]["port"]);
    print(Template("$who likes $what").substitute({"who": "Ada", "what": "graphs"}));
    print(`glob.escape("data[1].csv"));
}
```

```output
b'amFj' b'jac'
(1, 'plan') [1, 2]
2.5 2.5
2 2 2.0
2 3
10.0.0.1/24 has host bits set 10.0.0.0/24
the quick brown
fox jumps over
the lazy dog
8080
Ada likes graphs
data[[]1].csv
```

`glob` is also a Jac keyword: `import glob;` needs no backtick, but a use of the module does
(`` `glob.glob("*.txt") ``).

In the tables, **complete** means every name of CPython's module is there (names left out on
purpose aside, which are refused with E5142); **partial** lists what is there. A name that is not
there is refused when the program compiles (E1145), never narrowed silently. CPython's whole
module is still there for such a name: see [Modules that are CPython's](#modules-that-are-cpythons).

## Text

| Module | What it is | State |
|---|---|---|
| [`re`](re.md) | Regular expressions | Complete; `\N{...}` raises `NotImplementedError`, `re.DEBUG` left out |
| [`string`, `textwrap`, `difflib`, `shlex`, `fnmatch`, `pprint`, `reprlib`](text.md) | Constants, templates and formatters; wrapping; comparing sequences; shell words; name patterns; pretty printing; limited reprs | Complete (`textwrap` leaves out three names of Python 2's) |
| [`html`, `html.parser`, `html.entities`](text.md) | Escaping, an HTML parser, the entity tables | Complete |
| [`codecs`, `unicodedata`](codecs.md) | Text encodings and the Unicode 17 database | Every encoding but the CJK multibyte ones; `unicodedata` complete |
| `keyword` | `iskeyword`, `issoftkeyword` | Partial: no `kwlist`, `softkwlist`; they answer for Python's keywords, not Jac's |
| `locale` | Locale settings, `localeconv`, `format_string`, `currency`, `strxfrm`, `nl_langinfo`, ... | Complete |
| `gettext` | Message catalogues (GNU `.mo` files) | Complete but `install` (left out) |

`locale` starts in the `"C"` locale, where `format_string` groups no digits and `currency` raises
`ValueError: Currency formatting is not possible using the 'C' locale.`; `setlocale` changes it
to one the system has. `gettext.translation` reads a GNU `.mo` file, plural forms and `pgettext`
contexts included; with no file it raises `FileNotFoundError`, or with `fallback=True` returns a
`NullTranslations`. `gettext.install` and `NullTranslations.install` are left out (E5142): they
bind `_` among the builtins as the program runs. Bind it in the module that uses it:
`_ = gettext.translation(domain, localedir, fallback=True).gettext`.

## Data formats and encodings

| Module | What it is | State |
|---|---|---|
| [`json`](json.md) | JSON | Complete; UTF-16 and UTF-32 bytes are not decoded |
| [`csv`](csv.md) | Comma-separated values | Complete; the reader's converting quoting modes raise `NotImplementedError` |
| `tomllib` | TOML 1.1, as Python 3.15's | Complete |
| [`base64`, `binascii`](base64.md) | Base16, 32, 64 and 85, Ascii85 and Z85; binary and ASCII conversions, `crc32`, `crc_hqx` | Complete, with Python 3.15's options |
| [`struct`](struct.md) | Values packed into bytes | Complete; 64-bit ints |
| `array` | Packed arrays of one C type | Complete, with Python 3.15's type codes; no `DeprecationWarning` for `'u'` |
| [`hashlib`](hashlib.md), `hmac` | Message digests and keyed digests | Complete; no OpenSSL-only algorithms |
| `secrets` | Secure random tokens: `token_bytes`, `token_hex`, `token_urlsafe`, `randbelow`, `randbits`, `choice`, `compare_digest`, `SystemRandom` | Complete |
| `uuid` | `UUID`, `uuid1`, `uuid3` to `uuid8`, `getnode`, the namespaces | Nearly complete: no `SafeUUID`, `UUID.is_safe`; `UUID.int` left out |
| `mimetypes` | File types from names: `guess_type`, `guess_file_type`, `guess_extension`, `MimeTypes` | Nearly complete |
| [`sqlite3`](sqlite3.md), `sqlite3.dbapi2` | SQLite databases: connections, cursors, rows, functions and callbacks in Jac, adapters and converters, blobs, backups, dumps | Nearly complete: no `Connection.Error` and its siblings as properties |
| [`xml.etree.ElementTree`, `xml.etree.ElementPath`, `xml.etree.ElementInclude`](xml.md) | XML trees: parsing, pull parsing, the find paths, serializing as XML, HTML and text, C14N 2.0, XInclude | Complete |
| [`xml.sax`](xml.md) and its `handler`, `xmlreader`, `expatreader`, `saxutils` | XML as events given to a handler | Complete |
| [`xml.dom`, `xml.dom.minidom`, `xml.dom.expatbuilder`, `xml.dom.pulldom`, `xml.dom.xmlbuilder`, `xml.dom.domreg`, `xml.dom.minicompat`, `xml.dom.NodeFilter`](xml.md#xmldom) | The DOM: minidom's nodes, attributes and namespaces, parsing with expat or a SAX parser, `toxml` and `toprettyxml`, clones and imports, the builder's options and filters, fragments, the pull event stream | Nearly complete: a `NodeList` is a sequence of its own, not a `list` (no slices), and what a program reads out of one is untyped; a read-only property has no setter; no `minicompat.defproperty` (left out) or `minicompat.StringTypes` |
| [`xml.parsers.expat` (`pyexpat`), `xml`](xml.md) | expat itself, compiled into the program, with every handler; `xml.is_valid_name`, `is_valid_text` | Complete but `expat_CAPI` (left out) and `GetInputContext` |
| [`plistlib`](xml.md) | Apple property lists, XML and binary | Complete; 64-bit ints |
| [`email`](email.md) and its submodules, [`quopri`](email.md) | Email messages: headers, MIME parts, parsers, generators, policies, addresses and dates; quoted-printable | Complete; a header is read as an `any` |

An `array.array` holds items of one C type: the type codes are `array.typecodes`,
`('b', 'B', 'u', 'w', 'h', 'H', 'i', 'I', 'l', 'L', 'q', 'Q', 'e', 'f', 'd', 'Zf', 'Zd')`. `l`
and `L` have the size of the target's C `long` (8 bytes on Linux and macOS, 4 on Windows and
WASI), and `Zf` and `Zd` are complex numbers of 8 and 16 bytes. An item out of a code's range
raises `OverflowError` worded by its C type (`signed char is greater than maximum`), and one of
the wrong kind `TypeError`. Arrays of different codes compare by their items; an array is not
hashable. `memoryview` and `struct` read and write an array in place.

`tomllib.loads` gives TOML's dates and times as `datetime.date`, `time` and `datetime` (with a
`timezone` for an offset); a `TOMLDecodeError` has `msg`, `doc`, `pos`, `lineno` and `colno`
(`Cannot overwrite a value (at line 2, column 6)`), and `tomllib.load` of a file opened as text
raises `TypeError`, as in CPython. `uuid.UUID` reads the forms CPython reads, braces and
hyphens included, and orders by the 128-bit value. `secrets.token_bytes()` is 32 bytes and
`token_urlsafe(16)` 22 characters; `randbelow(0)` raises `ValueError`.

```jac
import calendar;
import graphlib;
import ipaddress;
import uuid;

with entry {
    ts = graphlib.TopologicalSorter({
        "build": {"compile"},
        "compile": {"fetch"},
        "test": {"build"},
    });
    print(list(ts.static_order()));
    net = ipaddress.ip_network("192.168.1.0/30");
    print(list(net.hosts()), ipaddress.ip_address("::1").is_loopback, net.supernet());
    u = uuid.uuid5(uuid.NAMESPACE_DNS, "example.org");
    print(u, u.version, uuid.UUID(bytes=u.bytes) == u);
    print(calendar.monthrange(2024, 2)[1], calendar.isleap(2100), calendar.weekday(2026, 11, 13));
}
```

```output
['fetch', 'compile', 'build', 'test']
[IPv4Address('192.168.1.1'), IPv4Address('192.168.1.2')] True 192.168.1.0/29
aad03681-8b63-5304-89e0-8ca8f49461b5 5 True
29 False 4
```

## Numbers

| Module | What it is | State |
|---|---|---|
| [`math`, `cmath`](math.md) | Mathematical functions | Complete |
| [`random`](random.md) | Pseudo-random numbers, CPython's sequence for a seed | Complete |
| [`decimal`, `fractions`, `statistics`, `numbers`](decimal.md) | Decimal arithmetic, rational numbers, statistics, the numeric tower | Complete; the builtin types are not registered with `numbers` |
| `colorsys` | Color-system conversions | Complete |
| `ipaddress` | IPv4 and IPv6 addresses, networks and interfaces | Complete; `int(IPv6Address)` left out |

`ipaddress.ip_network` of an address with host bits set (`"10.0.0.1/24"`) raises `ValueError`
unless `strict=False`, and a network's `hosts()` leaves out its network and broadcast
addresses, as in CPython. An IPv6 address is 128 bits, past a 64-bit `int`: `int(addr)` is left
out (E5142), and an `IPv6Address` is made from a str, its 16 `bytes`, or an int of at most 63
bits. `uuid.UUID.int` is left out for the same reason: use `UUID.bytes` or `UUID.hex`.

## Containers and functions

| Module | What it is | State |
|---|---|---|
| [`collections`](collections.md) | `deque`, `defaultdict`, `OrderedDict`, `Counter`, `ChainMap`, `UserDict`, `UserList`, `UserString` | Complete but `namedtuple` (left out) |
| [`itertools`](itertools.md) | Iterator building blocks | Complete but `chain.from_iterable` (left out) |
| [`functools`](functools.md) | `reduce`, `partial`, `lru_cache`, `cache`, `cmp_to_key` | Partial: its run-time decorators are left out |
| `operator` | The operators as functions, `itemgetter`, `attrgetter`, `methodcaller`, `call`, `countOf`, `indexOf`, `length_hint`, Python 3.14's `is_none` | Complete |
| [`heapq`, `bisect`](heapq.md) | Heaps in lists, with Python 3.14's max-heap functions; binary search and sorted insertion | Complete |
| [`copy`](copy.md) | `copy`, `deepcopy` | Nearly complete: no `replace` |
| `graphlib` | `TopologicalSorter`, `CycleError` | Complete |
| [`contextvars`](threading.md) | `ContextVar`, `Token`, `Context`, `copy_context` | Complete |

The functions of `heapq` and `bisect`, and `copy.copy` and `copy.deepcopy`, are compiled for the
types they are called with, so they cannot be used as values (`f = heapq.heappush` is E5090);
call them.

`operator`'s functions apply the language's operators, to builtin values and to an object's
special methods (`__add__`, `__iadd__`, `__abs__`, `__index__`, `__getitem__`, ...), and raise
what the operator raises: `operator.abs("x")` raises
`TypeError: bad operand type for abs(): 'str'`.

## Time

| Module | What it is | State |
|---|---|---|
| [`datetime`, `zoneinfo`](datetime.md) | Dates, times and time zones | Complete; Windows has no system time-zone database |
| [`time`](time.md) | Clocks, `sleep`, `struct_time`, `strftime`, `strptime`, the local zone | Complete |
| `calendar` | Calendars, `monthrange`, `isleap`, `timegm`, `TextCalendar`, `HTMLCalendar`, `Month`, `Day` | Complete |
| [`sched`](threading.md) | An event scheduler: events run in the order of their time, then priority; a cancelled one never runs; `run(blocking=False)` runs what is due and returns the delay until the next | Complete |

## Files and the operating system

| Module | What it is | State |
|---|---|---|
| [`os`, `os.path`, `posixpath`, `ntpath`, `genericpath`](os.md) | The operating system's interface and path names | Nearly complete: no `fdopen`, `popen`, `wait3`, `wait4` |
| [`sys`](sys.md), `atexit` | The command line, the standard streams, `exit`; what runs as the program ends | `sys` partial; `atexit` complete |
| [`io`](io.md) | `open`, the file classes, in-memory streams | Complete; `Reader` and `Writer` left out |
| [`pathlib`](pathlib.md) | `Path`, `PurePath` and the flavoured classes | Nearly complete: no `Path.cwd`, `Path.home`, `Path.from_uri`, `PurePath.parser` |
| [`shutil`, `tempfile`, `glob`, `filecmp`, `fileinput`, `stat`, `mmap`](files.md) | Copying and removing trees, temporary files, wildcards, comparing, many files as one stream, mode bits, mapped files | Complete but `filecmp.dircmp.methodmap` and `shutil.rmtree.avoids_symlink_attacks` (left out) |
| [`subprocess`](subprocess.md) | Child processes | Complete |
| [`signal`, `errno`, `pwd`, `grp`, `resource`, `fcntl`, `termios`, `tty`, `pty`, `syslog`](posix.md) | Signals, error numbers, users and groups, limits, descriptors, the terminal, the system log | Complete but enum aliases and 64-bit-wide values (left out); POSIX only but `signal` and `errno` |
| [`argparse`, `getopt`, `configparser`, `getpass`](argparse.md) | Command lines, INI files, passwords | Complete |
| [`logging`, `logging.handlers`](logging.md) | Loggers, handlers, formatters | `logging` complete; `logging.handlers` has the file, memory, syslog, SMTP, HTTP and queue handlers, and leaves out the two that pickle records and the Windows event log's |
| `platform` | `system`, `machine`, `release`, `uname`, `python_version`, `freedesktop_os_release`, ... | Complete but the `python_*` names that describe an interpreter (left out) |
| [`msvcrt`, `winreg`](windows.md) | The C runtime's console, the registry | Windows only; `winreg`'s predefined keys left out |

`errno` has the target's numbers, with `ENOENT`, `EEXIST`, `EINVAL`, `EACCES`, `EPIPE`, `EDOM`
and `ERANGE` the same everywhere (2, 17, 22, 13, 32, 33, 34). `platform.system()` is `Linux`,
`Darwin` or `Windows`, and `platform.python_version()` is the version of the Python whose
library this is, in a native program too; `python_implementation`, `python_build` and the other
names that describe a running interpreter are left out (E5142).

## Threads

All on [threading, queue and concurrent.futures](threading.md) (`jac docs threading`):

| Module | What it is | State |
|---|---|---|
| `threading`, `_thread` | Threads of the program's own, locks, conditions, semaphores, events, barriers, timers, per-thread attributes | Complete but `settrace`, `setprofile` and their `_all_threads` forms (left out) |
| `queue` | `Queue`, `LifoQueue`, `PriorityQueue`, `SimpleQueue` | Complete |
| `concurrent.futures` | `ThreadPoolExecutor`, `Future`, `wait`, `as_completed` | Complete but `ProcessPoolExecutor` and `InterpreterPoolExecutor` (left out) |

Threads run Jac code one at a time, as CPython's run Python under its GIL, and give way while
they wait. `flow for` runs a loop on several processors at once.

## Event loop

| Module | What it is | State |
|---|---|---|
| [`asyncio`](asyncio.md) and its modules (`asyncio.streams`, `asyncio.subprocess`, `asyncio.protocols`, `asyncio.transports`, ...) | The event loop that runs coroutines: `run` and `Runner`, tasks and futures, `gather`, `wait`, timeouts, task groups, `to_thread`, the locks and queues tasks share, streams, transports and protocols, servers, TLS, subprocesses and signal handlers | Nearly complete: no names that read frames (left out), `iscoroutine`, `iscoroutinefunction` or policy classes; `async with` of a `Server` and a protocol's class as its factory do not compile yet; Ctrl-C does not cancel the main task. On Windows the loop is the selector loop: no proactor loop, subprocesses, pipes, signal handlers or Unix sockets |

A coroutine is an `async def` function's call ([Async](../language/async.md),
`jac docs async`). The loop runs in one thread and its tasks take turns at each `await`.

## Network

| Module | What it is | State |
|---|---|---|
| [`socket`](socket.md) | The `socket` class, `socketpair`, `create_connection`, `create_server`, the name lookups, the address conversions, each system's constants; on Linux the addresses of netlink, vsock, `AF_ALG`, packet, CAN, TIPC and RDS sockets too | Complete but `CAPI` and two `AddressFamily` members (left out); the flag constants are ints |
| [`select`, `selectors`](socket.md) | `select`, `poll`, Linux's `epoll`, macOS's `kqueue`; `DefaultSelector` and the selectors it is one of | Complete, each system's own |
| [`socketserver`](socket.md) | `TCPServer`, `UDPServer`, the Unix, forking and threading servers, the request handlers | Complete |
| [`ssl`](socket.md) | TLS over OpenSSL 3: `SSLContext` (certificates and keys, verification, ciphers, ALPN, SNI and PSK callbacks, sessions), `wrap_socket` and `SSLSocket`, `wrap_bio`, `SSLObject` and `MemoryBIO`, the exceptions, `create_default_context` | Complete but `Options` and `VerifyFlags`, which are flag enums (`OP_*` and `VERIFY_*` are ints), and `SSLContext.sslsocket_class` and `sslobject_class` |
| [`http`, `http.client`, `http.server`, `http.cookies`, `http.cookiejar`](http.md) | `HTTPStatus`; HTTP/1.1 connections and responses, over TLS too; servers and request handlers; cookies and cookie jars | Nearly complete: no `HTTPMethod`, and `HTTPStatus`'s members have no `phrase` |
| [`urllib.parse`, `urllib.request`, `urllib.error`, `urllib.response`, `urllib.robotparser`](urllib.md) | URLs; `urlopen`, requests, openers and handlers for `http`, `https`, `ftp`, `file` and `data` URLs; `robots.txt` | Complete; macOS's system proxy settings are not read |
| [`smtplib`, `poplib`, `imaplib`, `ftplib`](mailclients.md) | Clients of SMTP and LMTP, POP3, IMAP4 and FTP, each with its TLS form | Complete but `ftplib.all_errors`, and `imaplib`'s exceptions as members of `IMAP4` (they are the module's); `IMAP4_stream` on Linux and macOS only |

A socket call that waits, and a name lookup, lets other threads run meanwhile. On WASI a program
makes no sockets: it is given them by its host ([socket](socket.md#platforms)).

## Compression and archives

All on [Compression and archives](compression.md) (`jac docs compression`):

| Module | What it is | State |
|---|---|---|
| `zlib` | `compress`, `decompress`, `compressobj`, `decompressobj`, `crc32`, `adler32` and their `_combine` forms | Complete but `ZLIBNG_VERSION` (left out) |
| `gzip` | `compress`, `decompress`, `open`, `GzipFile` | Complete |
| `bz2` | `compress`, `decompress`, `open`, `BZ2File`, `BZ2Compressor`, `BZ2Decompressor` | Complete |
| `lzma` | `compress`, `decompress`, `open`, `LZMAFile`, `LZMACompressor`, `LZMADecompressor`, the filter chains | Complete |
| `compression.zstd` | Python 3.14's Zstandard: `compress`, `decompress`, `open`, `ZstdFile`, `ZstdCompressor`, `ZstdDecompressor`, `ZstdDict`, `train_dict` | Complete |
| `compression.zlib`, `compression.gzip`, `compression.bz2`, `compression.lzma` | The same modules under Python 3.14's package | Complete |
| `zipfile` | `ZipFile` (reading and writing; stored, deflated, bzip2, LZMA and Zstandard members; ZIP64; decryption), `ZipInfo`, `Path` | Complete but `PyZipFile` (left out) |
| `tarfile` | `open`, `TarFile` (reading and writing; ustar, GNU and pax; gzip, bzip2, xz and Zstandard; streams), `TarInfo`, the extraction filters | Nearly complete: no `TarFile.tarinfo`, `TarFile.fileobject` |

## Platform limits

Some modules call a library of the operating system. The program links it where it is built and
loads it as it starts, so the machine it runs on needs it:

| Library | Modules | macOS | Linux | Windows | WASI |
|---|---|---|---|---|---|
| zlib | `zlib`, `gzip`, `zipfile`, `tarfile` | the system's | `libz.so.1` | linked into the program | not available |
| bzip2 | `bz2`, `zipfile`, `tarfile` | the system's | `libbz2.so.1.0` | linked into the program | not available |
| liblzma | `lzma`, `zipfile`, `tarfile` | the system's | `liblzma.so.5` | linked into the program | not available |
| Zstandard | `compression.zstd`, `zipfile`, `tarfile` | linked into the program | `libzstd.so.1` | linked into the program | not available |
| SQLite | `sqlite3` | the system's | `libsqlite3.so.0` | `winsqlite3.dll` | not available |
| TLS | `ssl`, and what is written over it: `http.client`, `http.server`, `urllib.request`, `smtplib`, `poplib`, `imaplib`, `ftplib`, `asyncio` | OpenSSL 3, linked into the program | OpenSSL 3 (`libssl.so.3`, `libcrypto.so.3`) | OpenSSL 3, linked into the program | not available |

Where a system ships no such library, the program links the copy jac's toolchain ships
("linked into the program"). A module whose library a target lacks does not build there (W5021):
a wasm32-wasi program links only the WASI C library, so none of these is there;
`base64` and `binascii` build everywhere, since the program carries its own CRC-32, and so do
the XML modules, whose parser, expat, is compiled into the program.
`fcntl`, `termios`, `tty`, `pty`, `pwd`, `grp`, `resource` and `syslog`, and the POSIX-only
parts of `select` (a wait on no descriptors), `signal` (`SIGKILL`, `SIGPIPE`, ...), `errno`
(`EWOULDBLOCK` being `EAGAIN`) and `subprocess` (finding a program on `PATH` the POSIX way), are
for Linux and macOS; `msvcrt` and `winreg` for Windows. `errno`, `signal`, `select` and the other
modules with constants have each platform's own values. `fcntl`, `termios` and `tty` are modules
for Windows and WASI as well, which have no such control: every call of theirs raises
`RuntimeError` (`fcntl is unavailable on this platform`), and their constants are 0. CPython has
none of the three on Windows.

## Modules that are CPython's

A module of Python's standard library that is not in the tables above is CPython's, imported
through the CPython jac embeds in the program (`typing`, `enum`, `dataclasses`,
`contextlib`, `pickle`, ...). Its values are Python objects. Some will be written natively; those tied to the Python interpreter (`ast`,
`importlib`, `inspect`, `pickle`, `ctypes`, `unittest`, `tkinter`, ...) will not. See
[The library](index.md#which-modules-stay-cpythons) for the list, and
[Python](../interop/python.md) (`jac docs interop/python`) for how such a module is used.

```jac
import pickle;

with entry {
    print(pickle.loads(pickle.dumps(("Ada", "ada@example.org"))));
}
```

```output
('Ada', 'ada@example.org')
```

A submodule of a native package is native or missing, never CPython's: `import json.tool` and
`import collections.abc` are E5143. Reach CPython's explicitly with
`importlib.import_module("json.tool")`.

The same reaches CPython's module where a partial native one lacks a name. `import http;` is
the native module, which has no `HTTPMethod` (E1145); `importlib.import_module("http")` is
CPython's, with all of it. What it returns are Python values, converted where a Jac type is wanted
([Python values](../interop/python-values.md), `jac docs PyObject`).

```jac
import importlib;

with entry {
    pyhttp = importlib.import_module("http");
    method: str = pyhttp.HTTPMethod("GET").value;
    print(method, pyhttp.HTTPStatus.NOT_FOUND.phrase);
}
```

```output
GET Not Found
```
