"""Benchmark JacPython against the stock CPython the same recipe builds.

A JacPython build also produces a build-only stock CPython from the same
configure flags (`<platform>.host`), so the two interpreters differ only in
the C that JacPython replaces. Each benchmark runs on both at once, each
pinned to its own physical core, so both see the same machine conditions.

    jac run scripts/jacpython/bench.jac run --deps DEPS --out OUT
    jac run scripts/jacpython/bench.jac compare OUT

`DEPS` holds pyperf and pyperformance, which the interpreters import (they
ship no pip): `uv pip install --target DEPS pyperf pyperformance`.

Suites:
- `modules`: the compiler frontend, the object types and the extension
  modules JacPython replaces, one `pyperf timeit` case each, plus cold and
  warm import commands.
- `pyperformance`: every pyperformance benchmark that needs no third-party
  package (2to3 is skipped: it installs a vendored package with pip).
"""
import argparse;
import json;
import math;
import os;
import queue;
import subprocess;
import sys;
import tomllib;
import from concurrent.futures { ThreadPoolExecutor }
import from pathlib { Path }
import from common { JAC }

glob PLATFORM: str = {"x86_64": "linux-x86_64", "aarch64": "linux-aarch64"}.get(
         os.uname().machine, "linux-x86_64"
     ),
     BUILD: Path = JAC / ".python-build/jacpython",
     IMPORTS: str = "argparse, json, typing, dataclasses, asyncio, email.message, http.client, decimal, pathlib",
     # Benchmarks that bind a fixed port run one interpreter at a time.
     SERIAL: set[str] = {"asyncio_tcp", "asyncio_tcp_ssl"},
     SKIPPED: set[str] = {"2to3"},
     STDLIB_SOURCE: str = "import sysconfig; src = open(sysconfig.get_path('stdlib') + '/{name}').read()",
     # (name, statement, setup) for `pyperf timeit`.
     CASES: list[tuple[str, str, str]] = [
         ("compile_typing_py", "compile(src, 'typing.py', 'exec')", "|typing.py"),
         ("compile_argparse_py", "compile(src, 'argparse.py', 'exec')", "|argparse.py"),
         ("ast_parse_typing_py", "ast.parse(src)", "import ast\n|typing.py"),
         (
             "compile_ast_to_code",
             "compile(tree, 'typing.py', 'exec')",
             "import ast\n|typing.py\ntree = ast.parse(src)"
         ),
         ("eval_small_expr", "eval('a * 2 + b', g)", "g = {'a': 3, 'b': 4}"),
         ("exec_small_stmt", "exec('x = [i * i for i in range(10)]', {})", ""),
         (
             "tokenize_typing_py",
             "list(tokenize.generate_tokens(io.StringIO(src).readline))",
             "import io, tokenize\n|typing.py"
         ),
         ("obj_range_loop", "for i in range(10000): pass", ""),
         (
             "obj_range_len_index",
             "len(r); r[500]; 77 in r; r[10:20]",
             "r = range(0, 100000, 3)"
         ),
         (
             "obj_enumerate",
             "for i, x in enumerate(lst): pass",
             "lst = list(range(10000))"
         ),
         ("obj_reversed", "for x in reversed(lst): pass", "lst = list(range(10000))"),
         (
             "obj_slice_list",
             "lst[1:-1]; lst[::2]; lst[10:20]",
             "lst = list(range(1000))"
         ),
         ("obj_slice_object", "slice(1, 10, 2).indices(100)", ""),
         (
             "obj_bound_method_create",
             "m = o.f; m(); m = o.f; m()",
             "class C:\n  def f(self): return 1\no = C()"
         ),
         (
             "obj_closure_cells",
             "make()()",
             "def make():\n  x = 1; y = 2\n  def g(): return x + y\n  return g"
         ),
         (
             "obj_complex_arith",
             "z = a * b + c; z = z / b; abs(z); z.conjugate()",
             "a = 1+2j; b = 3-1j; c = 0.5+0.5j"
         ),
         (
             "obj_bool_ops",
             "bool(0); bool(lst); True & False; True + 1; int(True)",
             "lst = [1]"
         ),
         ("obj_structseq_stat", "os.stat('.')", "import os"),
         ("obj_structseq_localtime", "time.localtime(0).tm_year", "import time"),
         (
             "obj_iter_callable",
             "list(iter(it.__next__, 999))",
             "it = iter(range(1000))"
         ),
         (
             "obj_seq_iter",
             "for x in s: pass",
             "class S:\n  def __getitem__(self, i):\n    if i >= 1000: raise IndexError\n    return i\ns = S()"
         ),
         ("obj_generic_alias", "list[int]; dict[str, list[int]]", ""),
         (
             "obj_union_isinstance",
             "isinstance(3, U); isinstance('a', U); int | str",
             "U = int | str | None"
         ),
         (
             "obj_simple_namespace",
             "ns = types.SimpleNamespace(a=1, b=2); ns.a + ns.b",
             "import types"
         ),
         ("obj_fstring_template", "f'{a}-{b!r}-{c:>5}'", "a = 1; b = 'x'; c = 3.5"),
         (
             "mod_json_dumps",
             "json.dumps(doc)",
             "import json; doc = {'k%d' % i: [i, str(i), {'x': i * 1.5, 'y': None, 'z': True}] for i in range(200)}"
         ),
         (
             "mod_json_loads",
             "json.loads(s)",
             "import json; s = json.dumps({'k%d' % i: [i, str(i), {'x': i * 1.5, 'y': None}] for i in range(200)})"
         ),
         (
             "mod_re_search",
             "pat.search(text)",
             "import re; pat = re.compile(r'(\\w+)@(\\w+)\\.com'); text = 'x ' * 2000 + 'joe@example.com'"
         ),
         (
             "mod_re_findall",
             "pat.findall(text)",
             "import re; pat = re.compile(r'[A-Z][a-z]+'); text = 'Hello World Foo bar Baz ' * 200"
         ),
         (
             "mod_re_sub",
             "pat.sub(r'\\2 \\1', text)",
             "import re; pat = re.compile(r'(\\w+) (\\w+)'); text = 'alpha beta gamma delta ' * 200"
         ),
         (
             "mod_pickle_dumps",
             "pickle.dumps(data, 5)",
             "import pickle; data = [{'a': i, 'b': str(i), 'c': (i, i * 2.0)} for i in range(500)]"
         ),
         (
             "mod_pickle_loads",
             "pickle.loads(blob)",
             "import pickle; blob = pickle.dumps([{'a': i, 'b': str(i), 'c': (i, i * 2.0)} for i in range(500)], 5)"
         ),
         (
             "mod_struct_pack_unpack",
             "st.unpack(st.pack(1, 2, 3.0, b'abcd'))",
             "import struct; st = struct.Struct('<iqd4s')"
         ),
         (
             "mod_math",
             "for x in xs: math.sqrt(x); math.sin(x); math.log(x); math.floor(x)",
             "import math; xs = [i + 0.5 for i in range(100)]"
         ),
         (
             "mod_math_int",
             "math.gcd(a, b); math.comb(60, 30); math.isqrt(a)",
             "import math; a = 2**200 + 7; b = 3**120"
         ),
         (
             "mod_math_fsum",
             "math.fsum(xs)",
             "import math; xs = [i * 0.1 for i in range(1000)]"
         ),
         (
             "mod_cmath",
             "cmath.sqrt(z); cmath.exp(z); cmath.phase(z)",
             "import cmath; z = 1.5+2.5j"
         ),
         (
             "mod_itertools",
             "list(itertools.islice(itertools.product(range(10), repeat=3), 500)); list(itertools.accumulate(range(500))); list(itertools.chain(a, a))",
             "import itertools; a = list(range(200))"
         ),
         (
             "mod_itertools_groupby",
             "for k, g in itertools.groupby(data): list(g)",
             "import itertools; data = sorted([i % 37 for i in range(2000)])"
         ),
         (
             "mod_deque",
             "d = collections.deque()\nfor i in range(1000): d.append(i)\nwhile d: d.popleft()",
             "import collections"
         ),
         (
             "mod_defaultdict_counter",
             "dd = collections.defaultdict(int)\nfor w in words: dd[w] += 1\ncollections.Counter(words)",
             "import collections; words = ['w%d' % (i % 50) for i in range(1000)]"
         ),
         (
             "mod_functools_lru",
             "f(5); f(6); f(5)",
             "import functools\n@functools.lru_cache(maxsize=128)\ndef f(x): return x"
         ),
         (
             "mod_functools_partial_reduce",
             "p(3); functools.reduce(operator.add, xs)",
             "import functools, operator; p = functools.partial(pow, 2); xs = list(range(500))"
         ),
         (
             "mod_heapq",
             "h = []\nfor x in xs: heapq.heappush(h, x)\nwhile h: heapq.heappop(h)",
             "import heapq, random; random.seed(1); xs = [random.random() for _ in range(500)]"
         ),
         (
             "mod_bisect",
             "for x in qs: bisect.bisect_left(a, x)\nb = []\nfor x in qs: bisect.insort(b, x)",
             "import bisect, random; random.seed(1); a = sorted(random.random() for _ in range(1000)); qs = [random.random() for _ in range(300)]"
         ),
         (
             "mod_random",
             "for _ in range(100): r.random()\nr.randrange(1000); r.getrandbits(64)",
             "import random; r = random.Random(1)"
         ),
         (
             "mod_operator_sort_key",
             "sorted(rows, key=operator.itemgetter(1, 0))",
             "import operator, random; random.seed(1); rows = [(random.random(), i % 17) for i in range(1000)]"
         ),
         (
             "mod_datetime",
             "d = datetime.datetime(2026, 10, 22, 12, 30) + datetime.timedelta(days=3, seconds=17)\nd.isoformat(); datetime.datetime.fromisoformat('2026-10-22T12:30:00'); d.strftime('%Y-%m-%d %H:%M')",
             "import datetime"
         ),
         (
             "mod_decimal",
             "x = a * b + c; x.quantize(q); x.sqrt()",
             "from decimal import Decimal as D; a = D('1.2345'); b = D('6.789'); c = D('0.001'); q = D('0.0001')"
         ),
         (
             "mod_hashlib_sha256_small",
             "hashlib.sha256(b'hello world').hexdigest()",
             "import hashlib"
         ),
         (
             "mod_hashlib_sha256_1mb",
             "hashlib.sha256(buf).digest()",
             "import hashlib; buf = bytes(range(256)) * 4096"
         ),
         (
             "mod_hashlib_md5_blake2",
             "hashlib.md5(buf).digest(); hashlib.blake2b(buf).digest()",
             "import hashlib; buf = b'x' * 4096"
         ),
         (
             "mod_zlib_roundtrip",
             "zlib.decompress(zlib.compress(buf, 6))",
             "import zlib; buf = b'the quick brown fox ' * 5000"
         ),
         (
             "mod_binascii",
             "binascii.hexlify(buf); base64.b64encode(buf); binascii.crc32(buf)",
             "import binascii, base64; buf = bytes(range(256)) * 16"
         ),
         (
             "mod_csv_read",
             "list(csv.reader(lines))",
             "import csv; lines = ['a,b,\"c d\",%d,%f' % (i, i / 3) for i in range(1000)]"
         ),
         (
             "mod_array",
             "a = array.array('d', xs); a.tobytes(); a[100]; a.append(1.0); sum(a)",
             "import array; xs = [i * 0.5 for i in range(1000)]"
         ),
         (
             "mod_unicodedata",
             "for c in s: unicodedata.category(c)\nunicodedata.normalize('NFKD', s)",
             "import unicodedata; s = 'H\\u00e9llo W\\u00f6rld \\ufb01 \\u00bd \\u65e5\\u672c\\u8a9e ' * 20"
         ),
         (
             "mod_codecs_cjk",
             "s.encode('shift_jis').decode('shift_jis')",
             "s = '\\u65e5\\u672c\\u8a9e\\u306e\\u30c6\\u30ad\\u30b9\\u30c8' * 100"
         ),
         (
             "mod_elementtree",
             "ET.fromstring(xml)",
             "import xml.etree.ElementTree as ET; xml = '<r>' + ''.join('<i a=\"%d\">t%d</i>' % (i, i) for i in range(500)) + '</r>'"
         ),
         (
             "mod_sqlite",
             "cur.execute('SELECT a, b FROM t WHERE a < 200').fetchall()",
             "import sqlite3; con = sqlite3.connect(':memory:'); con.execute('CREATE TABLE t(a, b)'); con.executemany('INSERT INTO t VALUES(?, ?)', [(i, str(i)) for i in range(1000)]); cur = con.cursor()"
         ),
         (
             "mod_abc_isinstance",
             "isinstance(d, Mapping); isinstance(l, Mapping); issubclass(dict, Iterable)",
             "from collections.abc import Mapping, Iterable; d = {}; l = []"
         ),
         (
             "mod_weakref",
             "r = weakref.ref(o); r(); wd[1] = o; wd[1]",
             "import weakref\nclass O: pass\no = O(); wd = weakref.WeakValueDictionary()"
         ),
         (
             "mod_time_calls",
             "time.perf_counter(); time.monotonic(); time.time()",
             "import time"
         ),
         (
             "mod_posix_calls",
             "os.getpid(); os.fspath('x'); os.path.exists('.'); os.listdir('.')",
             "import os"
         ),
         (
             "mod_socketpair",
             "a.send(b'x' * 100); b.recv(100)",
             "import socket; a, b = socket.socketpair()"
         ),
         (
             "mod_asyncio_gather",
             "asyncio.run(main())",
             "import asyncio\nasync def w(i): return i\nasync def main(): return await asyncio.gather(*[w(i) for i in range(200)])"
         ),
         (
             "mod_zoneinfo",
             "dt.astimezone(ny)",
             "import datetime, zoneinfo\ntry:\n  ny = zoneinfo.ZoneInfo('America/New_York')\nexcept Exception:\n  ny = datetime.timezone.utc\ndt = datetime.datetime(2026, 10, 22, tzinfo=datetime.timezone.utc)"
         ),
         (
             "mod_statistics",
             "statistics.NormalDist(0, 1).inv_cdf(0.3); statistics.mean(xs)",
             "import statistics; xs = list(range(100))"
         )
     ];

# pyperf's own options go between `command` and `rest`.
obj Job {
    has name: str,
        interpreter: str,
        command: list[str],
        rest: list[str],
        cwd: Path,
        output: Path;
}

def interpreter_path(variant: str) -> str {
    return str(BUILD / variant / "python/install/bin/python3.14");
}

# A setup line `|file.py` reads that stdlib file's source into `src`.
def expand_setup(setup: str) -> str {
    lines: list[str] = [];
    for line in setup.split("\n") {
        if line.startswith("|") {
            lines.append(STDLIB_SOURCE.replace("{name}", line[1:]));
        } else {
            lines.append(line);
        }
    }
    return "\n".join(lines);
}

def module_jobs(out: Path, interpreters: dict[str, str], empty: Path) -> list[Job] {
    jobs: list[Job] = [];
    for (label, python) in interpreters.items() {
        for (name, statement, setup) in CASES {
            rest = ["--name", name];
            if setup {
                rest += ["-s", expand_setup(setup)];
            }
            rest.append(statement);
            jobs.append(
                Job(
                    name=name,
                    interpreter=label,
                    command=[python, "-m", "pyperf", "timeit"],
                    rest=rest,
                    cwd=out,
                    output=out / label / f"{name}.json"
                )
            );
        }
        cold = [
            python,
            "-B",
            "-X",
            f"pycache_prefix={empty}",
            "-c",
            f"import {IMPORTS}"
        ];
        warm = [python, "-c", f"import {IMPORTS}"];
        for (name, measured) in [
            ("cold_import_no_pyc", cold),
            ("warm_import_pyc", warm)
        ] {
            jobs.append(
                Job(
                    name=name,
                    interpreter=label,
                    command=[python, "-m", "pyperf", "command"],
                    rest=["--name", name, "--", *measured],
                    cwd=out,
                    output=out / label / f"{name}.json"
                )
            );
        }
    }
    return jobs;
}

def pyperformance_root(deps: Path) -> Path {
    return deps / "pyperformance/data-files/benchmarks";
}

# Every dependency-free benchmark: (name, script, extra arguments).
def pyperformance_benchmarks(deps: Path) -> list[tuple[str, Path, list[str]]] {
    found: list[tuple[str, Path, list[str]]] = [];
    for directory in sorted(pyperformance_root(deps).glob("bm_*")) {
        if (directory / "requirements.txt").exists() {
            continue;
        }
        for meta in sorted(directory.glob("*.toml")) {
            data = tomllib.loads(meta.read_text());
            tool = data.get("tool", {}).get("pyperformance", {});
            if meta.name == "pyproject.toml" {
                fallback = data["project"]["name"].removeprefix("pyperformance_bm_");
            } else {
                fallback = meta.stem.removeprefix("bm_");
            }
            name = tool.get("name") or fallback;
            if name not in SKIPPED {
                script = directory / tool.get("runscript", "run_benchmark.py");
                found.append((name, script, list(tool.get("extra_opts", []))));
            }
        }
    }
    return found;
}

def pyperformance_jobs(
    out: Path, interpreters: dict[str, str], deps: Path
) -> list[Job] {
    jobs: list[Job] = [];
    for (name, script, extra) in pyperformance_benchmarks(deps) {
        for (label, python) in interpreters.items() {
            jobs.append(
                Job(
                    name=name,
                    interpreter=label,
                    command=[python, str(script)],
                    rest=extra,
                    cwd=script.parent,
                    output=out / label / f"{name}.json"
                )
            );
        }
    }
    return jobs;
}

obj Runner {
    has deps: Path,
        fast: bool,
        cores: queue.Queue;

    def run_one(job: Job) -> str {
        if job.output.exists() {
            return f"cached  {job.interpreter:10} {job.name}";
        }
        job.output.parent.mkdir(parents=True, exist_ok=True);
        cpu = self.cores.get();
        try {
            options = [
                "--inherit-environ",
                "PYTHONPATH",
                "--affinity",
                str(cpu),
                "-o",
                str(job.output)
            ];
            if self.fast {
                options.append("--fast");
            }
            env = dict(os.environ, PYTHONPATH=str(self.deps));
            with open(job.output.with_suffix(".log"), "w") as handle {
                result = subprocess.run(
                    [*job.command, *options, *job.rest],
                    env=env,
                    cwd=job.cwd,
                    stdout=handle,
                    stderr=subprocess.STDOUT
                );
            }
            status = "ok" if result.returncode == 0 else f"FAIL({result.returncode})";
            return f"{status:7} {job.interpreter:10} {job.name}";
        } finally {
            self.cores.put(cpu);
        }
    }
}

def run_jobs(jobs: list[Job], deps: Path, workers: int, fast: bool) -> list[str] {
    cores: queue.Queue = queue.Queue();
    # Logical CPUs 2k and 2k+1 are one physical core's two threads.
    for index in range(workers) {
        cores.put(2 * index);
    }
    runner = Runner(deps=deps, fast=fast, cores=cores);
    lines: list[str] = [];
    with ThreadPoolExecutor(max_workers=workers) as pool {
        for line in pool.map(runner.run_one, jobs) {
            print(line, flush=True);
            lines.append(line);
        }
    }
    return lines;
}

# Every value of every run of a pyperf result file, keyed by benchmark name.
def load_values(directory: Path) -> dict[str, list[float]] {
    values: dict[str, list[float]] = {};
    for path in sorted(directory.glob("*.json")) {
        data = json.loads(path.read_text());
        for bench in data.get("benchmarks", []) {
            name = bench.get("metadata", {}).get("name")
                or data.get("metadata", {}).get("name", path.stem);
            collected = [
                float(value) for run in bench.get("runs", [])
                for value in run.get("values", [])
            ];
            if collected {
                values[name] = collected;
            }
        }
    }
    return values;
}

def mean(values: list[float]) -> float {
    return sum(values) / len(values);
}

def variance(values: list[float]) -> float {
    center = mean(values);
    return sum((value - center) ** 2 for value in values) / (len(values) - 1);
}

# Welch's t statistic; two samples differ when |t| is at least 2.
def significant(first: list[float], second: list[float]) -> bool {
    if len(first) < 2 or len(second) < 2 {
        return False;
    }
    spread = math.sqrt(variance(first) / len(first) + variance(second) / len(second));
    return spread == 0 or abs(mean(first) - mean(second)) / spread >= 2.0;
}

def human(seconds: float) -> str {
    for (unit, scale) in [("s", 1.0), ("ms", 1e-3), ("us", 1e-6), ("ns", 1e-9)] {
        if seconds >= scale {
            return f"{seconds / scale:.3g} {unit}";
        }
    }
    return f"{seconds:.3g} s";
}

def compare(out: Path, base: str, new: str) {
    for suite in ["modules", "pyperformance"] {
        before = load_values(out / suite / base);
        after = load_values(out / suite / new);
        names = sorted(set(before) & set(after));
        if not names {
            continue;
        }
        rows = [
            (
                mean(after[name]) / mean(before[name]),
                name,
                mean(before[name]),
                mean(after[name]),
                significant(before[name], after[name])
            ) for name in names
        ];
        rows.sort(reverse=True);
        print(f"\n## {suite}: {new} / {base} (above 1 is slower)\n");
        for (ratio, name, first, second, differs) in rows {
            note = "" if differs else "  (not significant)";
            print(
                f"{name:36} {human(first):>10} {human(second):>10}  x{ratio:.2f}{note}"
            );
        }
        geomean = math.exp(sum(math.log(row[0]) for row in rows) / len(rows));
        print(f"\n{len(rows)} benchmarks, geometric mean x{geomean:.3f}");
        missing = sorted(set(before) ^ set(after));
        if missing {
            print("only on one side: " + ", ".join(missing));
        }
    }
}

with entry {
    parser = argparse.ArgumentParser(
        description="Benchmark JacPython against the stock CPython of the same recipe."
    );
    parser.add_argument("action", choices=["run", "compare"]);
    parser.add_argument("out", nargs="?", `default="");
    parser.add_argument("--out", dest="out_option", `default="");
    parser.add_argument("--deps", `default="");
    parser.add_argument(
        "--suite", choices=["modules", "pyperformance", "all"], `default="all"
    );
    parser.add_argument("--jobs", type=int, `default=8);
    parser.add_argument("--fast", action="store_true");
    parser.add_argument("--only", `default="");
    parser.add_argument("--base", `default=interpreter_path(f"{PLATFORM}.host"));
    parser.add_argument("--new", `default=interpreter_path(PLATFORM));
    args = parser.parse_args();
    out = Path(args.out_option or args.out or "jacpython-bench").resolve();
    if args.action == "compare" {
        compare(out, "cpython", "jacpython");
        sys.exit(0);
    }
    if not args.deps {
        sys.exit("run needs --deps: uv pip install --target DEPS pyperf pyperformance");
    }
    deps = Path(args.deps).resolve();
    interpreters = {"cpython": args.base, "jacpython": args.new};
    only = set(
        name
        for name in args.only.split(",")
        if name
    );
    empty = out / "empty_pycache";
    empty.mkdir(parents=True, exist_ok=True);
    failures: list[str] = [];
    if args.suite in ("modules", "all") {
        jobs = [
            job
            for job in module_jobs(out / "modules", interpreters, empty)
            if not only or job.name in only
        ];
        failures += [
            line
            for line in run_jobs(jobs, deps, args.jobs * 2, args.fast)
            if line.startswith("FAIL")
        ];
    }
    if args.suite in ("pyperformance", "all") {
        jobs = [
            job
            for job in pyperformance_jobs(out / "pyperformance", interpreters, deps)
            if not only or job.name in only
        ];
        parallel = [
            job
            for job in jobs
            if job.name not in SERIAL
        ];
        serial = [
            job
            for job in jobs
            if job.name in SERIAL
        ];
        failures += [
            line
            for line in run_jobs(parallel, deps, args.jobs * 2, args.fast)
            if line.startswith("FAIL")
        ];
        failures += [
            line
            for line in run_jobs(serial, deps, 1, args.fast)
            if line.startswith("FAIL")
        ];
    }
    compare(out, "cpython", "jacpython");
    if failures {
        print("\nfailed:\n" + "\n".join(failures));
        sys.exit(1);
    }
}
