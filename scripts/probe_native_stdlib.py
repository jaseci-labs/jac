"""Build and exercise a native Jac library calling the hosted CPython stdlib.

Run from the checkout with its Jac binary:
    jac -c 'import runpy; runpy.run_path("scripts/probe_native_stdlib.py", run_name="__main__")'

Add --runtime PATH to verify the same native artifact in another Python/Jac
runtime, and --report PATH to save the evidence. This is a feasibility probe,
not automatic lowering of ordinary native Jac imports. It uses PyDLL so every
native entry holds the GIL and CPython errors propagate to the Python driver.
No module-specific C adapter or Python callback dispatcher is built.
"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def verify(library: Path) -> dict:
    import ctypes
    import importlib
    import json
    import sys
    from concurrent.futures import ThreadPoolExecutor

    lib = ctypes.PyDLL(str(library))
    lib.import_call.argtypes = [ctypes.py_object] * 4
    lib.import_call.restype = ctypes.c_void_p
    lib.method_call.argtypes = [ctypes.py_object] * 4
    lib.method_call.restype = ctypes.c_void_p
    dec = ctypes.pythonapi.Py_DecRef
    dec.argtypes = [ctypes.c_void_p]
    dec.restype = None

    def take(ptr):
        assert ptr, 'NULL result without a Python exception'
        value = ctypes.cast(ptr, ctypes.py_object).value
        dec(ptr)
        return value

    def call(module, name, *args, **kwargs):
        return take(lib.import_call(module, name, args, kwargs))

    def method(obj, name, *args, **kwargs):
        return take(lib.method_call(obj, name, args, kwargs))

    passed = []
    def check(name, fn):
        fn()
        passed.append(name)
        print('PASS', name, flush=True)

    def json_check():
        data = {'text': 'a\x00á中😀', 'big': 1 << 200}
        encoded = call('json', 'dumps', data, sort_keys=True)
        assert encoded == json.dumps(data, sort_keys=True)
        assert call('json', 'loads', encoded) == data
        import decimal
        assert call('json', 'loads', '1.25', parse_float=decimal.Decimal) == decimal.Decimal('1.25')
        try:
            call('json', 'loads', '1 trailing')
        except json.JSONDecodeError as e:
            assert e.pos == 2 and e.doc == '1 trailing'
        else:
            raise AssertionError('JSON error missing')

    check('json: Unicode, NUL, bigint, kwargs, callback, exact error', json_check)

    def sqlite_check():
        import sqlite3
        conn = call('sqlite3', 'connect', ':memory:')
        try:
            method(conn, 'execute', 'create table t (x, y)')
            method(conn, 'executemany', 'insert into t values (?, ?)', [(1, b'a\x00b'), (2, None)])
            rows = method(method(conn, 'execute', 'select * from t order by x'), 'fetchall')
            assert rows == [(1, b'a\x00b'), (2, None)]
            method(conn, 'create_function', 'double', 1, lambda x: x * 2)
            assert method(method(conn, 'execute', 'select double(21)'), 'fetchone') == (42,)
            try:
                method(conn, 'execute', 'select * from missing')
            except sqlite3.OperationalError:
                pass
            else:
                raise AssertionError('SQLite error missing')
        finally:
            method(conn, 'close')

    check('sqlite3: objects, rows, bytes, callback, error, close', sqlite_check)

    def compression_check():
        data = bytes(range(256)) * 100
        for name in ['zlib', 'gzip', 'bz2', 'lzma', 'compression.zstd']:
            packed = call(name, 'compress', data)
            assert call(name, 'decompress', packed) == data
        packed = call('lzma', 'compress', data)
        stream = call('lzma', 'LZMADecompressor')
        assert method(stream, 'decompress', packed[:12]) + method(stream, 'decompress', packed[12:]) == data
        assert stream.eof
        a = call('bz2', 'compress', b'a')
        b = call('bz2', 'compress', b'b')
        assert call('bz2', 'decompress', a + b) == b'ab'

    check('compression: five engines, incremental lzma, concatenated bz2', compression_check)

    def decimal_check():
        import decimal
        x = call('decimal', 'Decimal', '0.1')
        assert method(x, '__add__', call('decimal', 'Decimal', '0.2')) == decimal.Decimal('0.3')
        assert call('decimal', 'getcontext') is decimal.getcontext()

    check('decimal: exact values, methods, shared context', decimal_check)

    def xml_check():
        import xml.parsers.expat
        parser = call('xml.parsers.expat', 'ParserCreate')
        seen = []
        parser.StartElementHandler = lambda name, attrs: seen.append((name, attrs))
        method(parser, 'Parse', '<root a="中"/>', True)
        assert seen == [('root', {'a': '中'})]
        parser = call('xml.parsers.expat', 'ParserCreate')
        try:
            method(parser, 'Parse', '<root>', True)
        except xml.parsers.expat.ExpatError:
            pass
        else:
            raise AssertionError('Expat error missing')

    check('expat: callback, Unicode, parse error', xml_check)

    def semantics_check():
        import struct
        assert call('math', 'factorial', 100) == __import__('math').factorial(100)
        fmt = '@' + 'bl'
        assert call('struct', 'calcsize', fmt) == struct.calcsize(fmt)
        assert call('struct', 'unpack', fmt, call('struct', 'pack', fmt, 1, 42)) == (1, 42)
        assert call('textwrap', 'wrap', 'well-known', 6) == ['well-', 'known']
        s = call('io', 'StringIO', 'a\x00中')
        assert method(s, 'read') == 'a\x00中'
        method(s, 'close')
        cv = call('contextvars', 'ContextVar', 'probe', default=7)
        assert method(cv, 'get', None) is None
        token = method(cv, 'set', 42)
        assert method(cv, 'get') == 42
        method(cv, 'reset', token)
        assert method(cv, 'get') == 7
        match = call('re', 'search', r'\d+', 'x42')
        assert method(match, 'group') == '42'

    check('math, struct, textwrap, io, contextvars, re', semantics_check)

    def ownership_check():
        class Box:
            pass
        box = Box()
        d = {'value': box}
        before = sys.getrefcount(box)
        for _ in range(10000):
            result = method(d, 'get', 'value')
            assert result is box
            del result
        assert sys.getrefcount(box) == before
        sentinel = RuntimeError('identity')
        def key(x):
            raise sentinel
        try:
            call('builtins', 'sorted', [2, 1], key=key)
        except RuntimeError as e:
            assert e is sentinel
        else:
            raise AssertionError('callback exception missing')
        try:
            call('_jac_nonexistent_stdlib_probe', 'x')
        except ModuleNotFoundError:
            pass
        else:
            raise AssertionError('import error missing')
        try:
            call('math', '_jac_nonexistent_attribute')
        except AttributeError:
            pass
        else:
            raise AssertionError('attribute error missing')

    check('ownership: 10,000 returns; callback exception and identity', ownership_check)

    def threads_check():
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda n: call('math', 'factorial', n), range(20)))
        assert results == [__import__('math').factorial(n) for n in range(20)]

    check('calls from four Python-managed threads', threads_check)

    lib.native_sqlite_answer.argtypes = [ctypes.c_int64]
    lib.native_sqlite_answer.restype = ctypes.c_int64
    assert lib.native_sqlite_answer(41) == 42
    passed.append('native-created SQLite connection, query, result and close')
    print('PASS', passed[-1], flush=True)

    bridge_version = getattr(ctypes.pythonapi, '_PyJac_CompilerBridgeVersion', None)
    return {
        'passed': passed,
        'python': sys.version,
        'executable': sys.executable,
        'jacpython_bridge': bridge_version() if bridge_version else None,
        'module_origins': {
            name: getattr(importlib.import_module(name), '__file__', 'built-in')
            for name in ('math', '_json', '_sqlite3', '_lzma', 'pyexpat')
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jac", default=shutil.which("jac"))
    parser.add_argument("--runtime", action="append", default=[], type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--library", type=Path, help="verify an already built library")
    args = parser.parse_args()
    if args.library:
        result = verify(args.library.resolve())
    else:
        if not args.jac:
            parser.error("jac is not on PATH; provide --jac")
        script = Path(__file__).resolve()
        repo = script.parent.parent
        fixture = script.parent / "fixtures/native_stdlib_bridge.jac"
        suffix = ".dylib" if sys.platform == "darwin" else ".so"
        with tempfile.TemporaryDirectory(prefix="jac-stdlib-probe-") as directory:
            stage = Path(directory)
            library = stage / ("bridge" + suffix)
            command = [args.jac, "build", "--native", "--lib", str(fixture), "-o", str(library)]
            build = subprocess.run(command, cwd=repo, capture_output=True, text=True, timeout=900)
            if build.returncode or not library.is_file() or "demoting " in build.stdout + build.stderr:
                raise RuntimeError("Native bridge build failed or demoted:\n" + build.stdout + build.stderr)
            print("Built native Jac bridge using the checkout compiler", flush=True)
            results = []
            for index, runtime in enumerate([Path(sys.executable), *args.runtime]):
                report = stage / f"runtime-{index}.json"
                # -c works with both CPython and Jac's interpreter mode.
                child = subprocess.run(
                    [str(runtime.resolve()), "-X", "faulthandler", "-c",
                     "import runpy, sys; p = sys.argv.pop(1); runpy.run_path(p, run_name='__main__')",
                     str(script), "--library", str(library), "--report", str(report)],
                    cwd=repo, capture_output=True, text=True, timeout=120,
                )
                if child.returncode:
                    raise RuntimeError(f"Probe failed in {runtime}:\n{child.stdout}{child.stderr}")
                results.append(json.loads(report.read_text()))
                print(f"PASS {runtime}: {len(results[-1]['passed'])} groups", flush=True)
            result = {"fixture": str(fixture.relative_to(repo)), "runtimes": results}
    rendered = json.dumps(result, indent=2) + "\n"
    if args.report:
        args.report.write_text(rendered)
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
