"""The Python distribution must support Jac's bootstrap and native runtime."""
import bz2
import ctypes
import decimal
import hashlib
import lzma
import multiprocessing
import platform
from pathlib import Path
import sqlite3
import shlex
import ssl
import sys
import sysconfig
import subprocess
import tempfile
import venv
import xml.parsers.expat
import zlib
from compression import zstd

assert sys.version_info[:3] == (3, 14, 6), sys.version
# Jac executes its compiler on this interpreter. Keep the release runtime's
# optimization contract explicit so a source-build change cannot silently
# ship the slower development interpreter.
assert sysconfig.get_config_var("Py_TAIL_CALL_INTERP") == 1, "Tail-call interpreter is required"
if sys.platform != "darwin":  # The pinned Zig Mach-O linker does not support LTO.
    assert "-flto" in sysconfig.get_config_var("PY_CFLAGS_NODIST"), "Release Python requires LTO"
# The last optimization option wins; CPython's default -O3 can be followed by
# dependency CFLAGS that silently downgrade it to -O2.
optimization_flags = [
    flag for flag in shlex.split(sysconfig.get_config_var("PY_CFLAGS"))
    if flag.startswith("-O")
]
assert optimization_flags[-1:] == ["-O3"], optimization_flags
if sys.platform == "darwin":
    import _scproxy
sample = b"Jac source-built runtime" * 100
for codec in (bz2, lzma, zlib, zstd):
    assert codec.decompress(codec.compress(sample)) == sample
assert sqlite3.connect(":memory:").execute("select 6 * 7").fetchone() == (42,)
assert str(decimal.Decimal("0.1") + decimal.Decimal("0.2")) == "0.3"
assert hashlib.sha256(sample).digest()
assert ctypes.pythonapi.PyInitConfig_Create
mode = sys.argv[1] if len(sys.argv) > 1 else "jacpython"
assert mode in ("jacpython", "host"), mode
if mode == "jacpython":
    assert ctypes.pythonapi._PyJac_CompilerBridgeVersion() == 4
try:
    required_compiler = ctypes.pythonapi._PyJac_CompilerRequired
except AttributeError:
    required_compiler = None  # Only the build host retains the C compiler.
if mode == "jacpython":
    assert required_compiler is not None, "JacPython was requested but is missing"
elif mode == "host":
    assert required_compiler is None, "Unexpected JacPython runtime"
    assert getattr(sys, "_jacpython_compile", None) is None
    assert not hasattr(sys, "_jacpython_image"), "Unexpected embedded seed"
    assert not hasattr(ctypes.pythonapi, "_PyJac_CompilerBridgeVersion")
if required_compiler is not None:
    import _bisect
    import _heapq
    import _random
    import binascii
    import _operator
    import _queue
    import _json
    import _csv
    import _struct
    import cmath
    import math
    import _collections
    import _functools
    import functools
    import itertools
    import array
    import _pickle
    for replacement in (_bisect, _heapq, _random, binascii, _operator, _queue, _json, _csv, _struct, cmath, math, _collections, _functools, itertools, array, _pickle):
        assert replacement.__name__ in sys.builtin_module_names
        assert replacement.__spec__.origin == "built-in"
    # Startup imports itertools and functools; each native module must also
    # support an isolated interpreter with its own interpreter lock.
    from concurrent import interpreters
    isolated = interpreters.create()
    try:
        isolated.exec("""
import array, _functools, itertools, _pickle, _bisect, _heapq
assert array.__spec__.origin == _functools.__spec__.origin == itertools.__spec__.origin == 'built-in'
assert _functools.partial(pow, 2)(5) == 32
assert list(itertools.islice(itertools.count(3), 3)) == [3, 4, 5]
assert array.array('i', [1, 2]).tolist() == [1, 2]
assert _pickle.__spec__.origin == 'built-in'
assert _pickle.loads(_pickle.dumps({'a': [1, 2]})) == {'a': [1, 2]}
assert _bisect.bisect_right(a=[1, 2, 2], x=2) == 3
assert _heapq.heappop([1, 2, 3]) == 1
""")
    finally:
        isolated.close()
    import gc
    import io
    import pickle
    import pickletools
    import weakref
    recursive_list = []
    recursive_tuple = (recursive_list,)
    recursive_list.append(recursive_tuple)
    protocol_zero = pickle.dumps(recursive_tuple, protocol=0)
    assert all(opcode.proto == 0 for opcode, _, _ in pickletools.genops(protocol_zero))
    restored_tuple = pickle.loads(protocol_zero)
    assert restored_tuple[0][0] is restored_tuple
    assert ctypes.pythonapi.jacpy_pickler_dump
    assert ctypes.pythonapi.jacpy_unpickler_load
    class PickleOwner:
        def callback(self, *args):
            return None
    for codec_kind in ('pickler', 'unpickler', 'memo', 'buffers'):
        owner = PickleOwner()
        if codec_kind == 'unpickler':
            owner.codec = pickle.Unpickler(io.BytesIO(pickle.dumps([1])))
            owner.codec.persistent_load = owner.callback
        elif codec_kind == 'buffers':
            owner.codec = pickle.Pickler(io.BytesIO(), protocol=5, buffer_callback=owner.callback)
        elif codec_kind == 'memo':
            class MemoPickler(pickle.Pickler):
                pass
            owner.codec = MemoPickler(io.BytesIO())
            owner.codec.memo_cycle = owner.codec.memo
            owner.codec.owner = owner
        else:
            owner.codec = pickle.Pickler(io.BytesIO())
            owner.codec.persistent_id = owner.callback
        owner_ref = weakref.ref(owner)
        del owner
        gc.collect()
        assert owner_ref() is None, "Native pickle hid a Python reference cycle"

    stream = io.BytesIO()
    writer = pickle.Pickler(stream)
    empty = writer.__sizeof__()
    values = [[i] for i in range(10000)]
    writer.dump(values)
    grown = writer.__sizeof__()
    assert grown > empty + 100000, (empty, grown)
    writer.clear_memo()
    assert writer.__sizeof__() < grown - 100000
    reader = pickle.Unpickler(io.BytesIO(stream.getvalue()))
    empty = reader.__sizeof__()
    assert reader.load() == values
    grown = reader.__sizeof__()
    assert grown > empty + 100000, (empty, grown)
    reader.memo.clear()
    assert reader.__sizeof__() < grown - 100000

    # Cyclic callbacks must be visible to CPython's collector.
    class Sink:
        def write(self, data):
            pass

    sink = Sink()
    sink.writer = pickle.Pickler(sink)
    reference = weakref.ref(sink)
    del sink
    gc.collect()
    assert reference() is None

    class Source:
        def read(self, count):
            return b""

        def readline(self):
            return b""

    source = Source()
    source.reader = pickle.Unpickler(source)
    reference = weakref.ref(source)
    del source
    gc.collect()
    assert reference() is None
    assert ctypes.pythonapi.jacpy_array_insert
    numeric_array = array.array('q')
    array_empty_size = numeric_array.__sizeof__()
    numeric_array.extend(range(10000))
    assert numeric_array.__sizeof__() > array_empty_size + 80000
    with memoryview(numeric_array) as view:
        numeric_array[0] = 99
        assert view[0] == 99 and view.itemsize == 8
        try:
            numeric_array.clear()
        except BufferError:
            pass
        else:
            raise AssertionError("array resized while exporting a view")
    # A view owns storage and exposes a writable, correctly typed buffer.
    class ArrayOwner(array.array):
        pass
    owner = ArrayOwner('i', [1, 2])
    view = memoryview(owner)
    assert view.format == 'i' and view.shape == (2,) and not view.readonly
    view[1] = 42
    assert owner.tolist() == [1, 42]
    owner_ref = weakref.ref(owner)
    del owner
    gc.collect()
    assert owner_ref() is not None
    view.release()
    gc.collect()
    assert owner_ref() is None
    for cycle_kind in ('iterator', 'view'):
        owner = ArrayOwner('i', [1, 2])
        owner.cycle = iter(owner) if cycle_kind == 'iterator' else memoryview(owner)
        owner_ref = weakref.ref(owner)
        del owner
        gc.collect()
        assert owner_ref() is None, "Native array hid a Python reference cycle"
    numeric_array.clear()
    assert numeric_array.__sizeof__() <= array_empty_size + 1
    numeric_array.append(1)
    class ArrayMutation:
        def __index__(self):
            numeric_array.clear()
            numeric_array.append(4)
            return 7
    numeric_array[0] = ArrayMutation()
    assert numeric_array.tolist() == [7]
    numeric_array.append(ArrayMutation())
    assert numeric_array.tolist() == [4, 7]
    assert array.array('w', 'aΩ😀').tounicode() == 'aΩ😀'
    class IteratorOwner:
        def key(self, value):
            return True
    for iterator_kind in ('cycle', 'groupby', 'grouper', 'tee'):
        owner = IteratorOwner()
        if iterator_kind == 'cycle':
            owner.iterator = itertools.cycle([owner])
        elif iterator_kind == 'groupby':
            owner.iterator = itertools.groupby([owner], owner.key)
        elif iterator_kind == 'grouper':
            owner.iterator = next(itertools.groupby([owner]))[1]
        else:
            owner.iterator = itertools.tee([owner])[0]
        owner_ref = weakref.ref(owner)
        del owner
        gc.collect()
        assert owner_ref() is None, "Native itertools hid a Python reference cycle"
    first, lagging = itertools.tee(range(200000))
    sum(first)
    del first, lagging
    gc.collect()  # Releasing a long replay chain must use the destruction budget.

    assert ctypes.pythonapi.jacpy_tee_next
    assert list(itertools.batched(range(5), 2)) == [(0, 1), (2, 3), (4,)]
    assert list(itertools.permutations("ab")) == [("a", "b"), ("b", "a")]
    assert [(key, list(group)) for key, group in itertools.groupby("aabb")] == [
        ("a", ["a", "a"]), ("b", ["b", "b"])]
    leading, trailing = itertools.tee(range(1000))
    assert list(leading) == list(range(1000))
    assert list(trailing) == list(range(1000))
    del leading, trailing
    for factory in (itertools.product, itertools.combinations,
                    itertools.combinations_with_replacement, itertools.permutations):
        small = factory("ab", repeat=1) if factory is itertools.product else factory(range(300), 1)
        large = factory("ab", repeat=300) if factory is itertools.product else factory(range(300), 300)
        assert large.__sizeof__() > small.__sizeof__()
    del small, large
    assert ctypes.pythonapi.jacpy_lru_call
    assert _functools.reduce(lambda a, b: a + b, range(10)) == 45
    hole = _functools.Placeholder
    bound = _functools.partial(lambda *args, **kw: (args, kw), hole, 2, flag=True)
    assert bound(1, 3) == ((1, 2, 3), {"flag": True})
    assert sorted([4, 1, 3], key=_functools.cmp_to_key(lambda a, b: a - b)) == [1, 3, 4]
    @functools.lru_cache(2)
    def cached(value):
        return value * 2
    for value in (1, 2, 1, 3, 1):
        assert cached(value) == value * 2
    assert cached.cache_info() == (2, 3, 2, 2)
    cached.cache_clear()
    assert cached.cache_info() == (0, 0, 2, 0)
    # Callable state and instance dictionaries must expose callback cycles to GC.
    import gc
    import weakref
    class CallableOwner:
        def call(self, value):
            return value

    for factory in (lambda fn: _functools.partial(fn),
                    lambda fn: _functools._lru_cache_wrapper(fn, 2, False, tuple)):
        owner = CallableOwner()
        owner.binding = factory(owner.call)
        owner.binding.owner = owner
        assert owner.binding(42) == 42
        owner_ref = weakref.ref(owner)
        binding_ref = weakref.ref(owner.binding)
        del owner
        gc.collect()
        assert owner_ref() is None and binding_ref() is None, "Native callable retained a cycle"
    key = _functools.cmp_to_key(lambda a, b: a - b)
    assert type(key).__hash__ is None
    assert ctypes.pythonapi.jacpy_math_fsum
    assert math.factorial(100) // math.factorial(99) == 100
    assert math.isqrt(10 ** 200 - 1) == 10 ** 100 - 1
    assert math.comb(2 ** 100, 2) == 2 ** 99 * (2 ** 100 - 1)
    assert math.fsum([1e100, 1, -1e100]) == 1
    assert math.sumprod([1e100, 1, -1e100], [1., 1., 1.]) == 1
    assert math.hypot(3, 4) == math.dist((0, 0), (3, 4)) == 5
    assert math.copysign(1, math.nextafter(-5e-324, 0.)) == -1
    class CustomCeil:
        def __ceil__(self):
            return "custom ceiling"
    assert math.ceil(CustomCeil()) == "custom ceiling"
    assert ctypes.pythonapi.jacpy_deque_append
    deque = _collections.deque
    sequence = deque(range(1024))
    full_size = sequence.__sizeof__()
    sequence.rotate(17)
    assert sequence.popleft() == 1007
    sequence.clear()
    assert full_size > sequence.__sizeof__() + 8000
    assert list(deque(range(10), maxlen=3)) == [7, 8, 9]
    match deque([1, 2]):
        case [1, 2]:
            pass
        case _:
            raise AssertionError("Deque is missing the sequence-pattern protocol")
    iterator = iter(sequence)
    sequence.append(1)
    try:
        next(iterator)
    except RuntimeError:
        pass
    else:
        raise AssertionError("Deque iterator missed a mutation")
    class ReentrantFactory:
        def __call__(self):
            defaults["key"] = "inserted during callback"
            return "factory result"
    defaults = _collections.defaultdict(ReentrantFactory())
    assert defaults["key"] == "inserted during callback"
    class CustomDeque(deque):
        def __iter__(self):
            return iter(("custom",))
    assert repr(CustomDeque([1])) == "CustomDeque(['custom'])"
    assert ctypes.pythonapi.jacpy_struct_pack
    assert ctypes.pythonapi.jacpy_cmath_unary
    layout = _struct.Struct(">QifD")
    values = (2 ** 64 - 1, -(2 ** 31), 1.25, complex(-2, 3))
    assert layout.unpack(layout.pack(*values)) == values
    assert _struct.pack("f", 2) == _struct.pack("f", 2.0)
    for kind in ("deque", "iterator", "defaultdict"):
        owner = CallableOwner()
        if kind == "defaultdict":
            owner.binding = _collections.defaultdict(owner.call)
            owner.binding["owner"] = owner
        else:
            sequence = _collections.deque([owner])
            owner.binding = sequence if kind == "deque" else iter(sequence)
            del sequence
        owner_ref = weakref.ref(owner)
        del owner
        gc.collect()
        assert owner_ref() is None, "Native collections hid a Python reference cycle"
    callback_layout = _struct.Struct(">I")
    class ReplaceLayout:
        def __index__(self):
            callback_layout.__init__("128s")
            return 42
    assert callback_layout.pack(ReplaceLayout()) == b"\0\0\0*"
    callback_layout.__init__(">I")
    callback_buffer = bytearray(4)
    class RetainedOffset:
        def __index__(self):
            try:
                callback_buffer.extend(b"x")
            except BufferError:
                pass
            else:
                raise AssertionError("Native struct released its exported buffer during a callback")
            callback_layout.__init__("128s")
            return 0
    callback_layout.pack_into(callback_buffer, RetainedOffset(), 42)
    assert callback_buffer == b"\0\0\0*"
    assert _struct.Struct("I" * 1000).__sizeof__() > _struct.Struct("I").__sizeof__()
    iterator_buffer = bytearray(b"abcd")
    unpack_iterator = _struct.iter_unpack("B", iterator_buffer)
    assert next(unpack_iterator) == (97,)
    try:
        iterator_buffer.append(1)
    except BufferError:
        pass
    else:
        raise AssertionError("Native unpack iterator released its buffer too soon")
    assert list(unpack_iterator) == [(98,), (99,), (100,)]
    iterator_buffer.append(1)
    assert cmath.sqrt(-4) == 2j
    assert cmath.rect(2, 0) == 2
    assert cmath.isclose(a=1j, b=1j)
    assert not cmath.isclose(1j, 2j)
    assert cmath.log(1j, complex(float("inf"), float("nan"))) == 0j
    for base, expected_error in ((0, ValueError), (None, TypeError)):
        try:
            cmath.log(1j, base)
        except expected_error:
            pass
        else:
            raise AssertionError("Native complex logarithm accepted an invalid base")
    try:
        cmath.isclose(1, 1, rel_tol=-1)
    except ValueError:
        pass
    else:
        raise AssertionError("Native complex comparison accepted a negative tolerance")
    assert ctypes.pythonapi.jacpy_csv_read
    assert ctypes.pythonapi.jacpy_csv_write
    from io import StringIO
    csv_output = StringIO(newline="")
    csv_writer = _csv.writer(csv_output, quoting=_csv.QUOTE_STRINGS)
    csv_writer.writerow([None, "", 1.25, "comma,quote\"\nnext"])
    csv_reader = _csv.reader(StringIO(csv_output.getvalue(), newline=""), quoting=_csv.QUOTE_STRINGS)
    assert next(csv_reader) == [None, "", 1.25, "comma,quote\"\nnext"]
    assert csv_reader.line_num == 2
    previous_limit = _csv.field_size_limit(2)
    try:
        next(_csv.reader(["abc"]))
    except _csv.Error as error:
        assert "field limit (2)" in str(error)
    else:
        raise AssertionError("Native CSV ignored its field limit")
    finally:
        _csv.field_size_limit(previous_limit)
    # Callback owners and native CSV parsing state participate in cyclic GC.
    import gc
    import weakref
    class CsvInput:
        def __iter__(self):
            return self

        def __next__(self):
            raise StopIteration

    class CsvOutput:
        def write(self, data):
            return len(data)

    for owner_type, factory in ((CsvInput, _csv.reader), (CsvOutput, _csv.writer)):
        owner = owner_type()
        owner.binding = factory(owner)
        owner_ref = weakref.ref(owner)
        del owner
        gc.collect()
        assert owner_ref() is None, "Native CSV bindings hid a callback cycle"
    assert ctypes.pythonapi.jacpy_json_encode
    assert ctypes.pythonapi.jacpy_json_scan
    import json
    document = {"unicode": "\U0001f642\ud800", "nested": [None, True, 2 ** 100, 1.25]}
    assert json.loads(json.dumps(document, indent=2, sort_keys=True)) == document
    assert json.loads('{"a":1,"a":2}', object_pairs_hook=tuple) == (("a", 1), ("a", 2))
    # Native binding state must keep Python callbacks visible to cyclic GC.
    import gc
    import weakref
    class JsonBindingOwner:
        strict = True
        object_pairs_hook = None
        parse_float = float
        parse_int = int
        parse_constant = str

        def object_hook(self, value):
            return value

    owner = JsonBindingOwner()
    owner.scanner = _json.make_scanner(owner)
    owner.encoder = _json.make_encoder(
        None, owner.object_hook, _json.encode_basestring, None,
        ":", ",", False, False, True,
    )
    assert owner.scanner.object_hook == owner.object_hook
    assert owner.encoder.default == owner.object_hook
    assert owner.scanner('{"x": 1}', 0) == ({"x": 1}, 8)
    assert "".join(owner.encoder({"x": 1}, 0)) == '{"x":1}'
    owner_ref = weakref.ref(owner)
    del owner
    gc.collect()
    assert owner_ref() is None, "Native JSON bindings hid a Python reference cycle"
    try:
        json.loads("[" * 100_000 + "0" + "]" * 100_000)
    except RecursionError:
        pass
    else:
        raise AssertionError("Native JSON did not guard recursive parsing")
    assert ctypes.pythonapi.jacpy_queue_get
    import threading
    fifo = _queue.SimpleQueue()
    consumed = []
    def consume_native_queue():
        while True:
            item = fifo.get(timeout=5)
            if item is None:
                return
            consumed.append(item)
    consumers = [threading.Thread(target=consume_native_queue, daemon=True) for _ in range(8)]
    for consumer in consumers:
        consumer.start()
    for item in range(1000):
        fifo.put(item)
    for consumer in consumers:
        fifo.put(None)
    for consumer in consumers:
        consumer.join(10)
        assert not consumer.is_alive(), "Native queue lost a notification"
    assert sorted(consumed) == list(range(1000))
    assert fifo.empty()
    assert ctypes.pythonapi.jacpy_operator_apply
    assert _operator.itemgetter(2, 0)(["a", "b", "c"]) == ("c", "a")
    assert _operator.methodcaller("replace", "a", "b")("native") == "nbtive"
    assert _operator._compare_digest(b"native", b"native") is True
    assert _operator._compare_digest(b"native", b"Native") is False
    vectorcall_function = ctypes.pythonapi.PyVectorcall_Function
    vectorcall_function.argtypes = [ctypes.py_object]
    vectorcall_function.restype = ctypes.c_void_p
    for accessor in (_operator.itemgetter(0), _operator.attrgetter("name"), _operator.methodcaller("upper")):
        assert vectorcall_function(accessor), "Native operator accessor lost vectorcall"
    repr_events = []
    class MethodName(str):
        def __repr__(self):
            repr_events.append("name")
            return super().__repr__()
    class Argument:
        def __repr__(self):
            repr_events.append("argument")
            return "argument"
    repr(_operator.methodcaller(MethodName("method"), Argument(), key=Argument()))
    assert repr_events == ["argument", "argument", "name"]
    recursive_items = []
    recursive_getter = _operator.itemgetter(recursive_items)
    recursive_items.append(recursive_getter)
    assert repr(recursive_getter) == "operator.itemgetter([operator.itemgetter(...)])"
    assert ctypes.pythonapi.jacpy_binascii_convert
    assert binascii.a2b_base64(binascii.b2a_base64(b"native codec")) == b"native codec"
    assert binascii.crc32(b"123456789") == 0xcbf43926
    # Private Jac helpers must not interpose on zlib's distinct C ABI.
    assert zlib.crc32(sample) == binascii.crc32(sample)
    buffer = bytearray(b"data")
    class ResizeDuringArgumentConversion:
        def __bool__(self):
            buffer.clear()
            return False
    resize_flag = ResizeDuringArgumentConversion()
    codec_refs = sys.getrefcount(buffer), sys.getrefcount(resize_flag)
    for _ in range(100):
        try:
            binascii.b2a_base64(buffer, newline=resize_flag)
        except BufferError:
            pass
        else:
            raise AssertionError("Native codecs must preserve exported buffers")
    assert (sys.getrefcount(buffer), sys.getrefcount(resize_flag)) == codec_refs
    buffer.clear()  # Failed argument conversion must release its export.
    assert ctypes.pythonapi.jacpy_bisect
    assert ctypes.pythonapi.jacpy_random_bits
    generator = _random.Random(42)
    assert generator.random() == 0.6394267984578837
    state = generator.getstate()
    bits = generator.getrandbits(130)
    generator.setstate(state)
    assert generator.getrandbits(130) == bits
    assert ctypes.pythonapi.jacpy_heapify
    assert _bisect.bisect_right([1, 2, 2, 4], 2) == 3
    # The native binding frame must release conversions on every error path,
    # including duplicate keywords, unknown names, and failing __index__.
    binding_values, binding_needle = [], object()
    binding_refs = sys.getrefcount(binding_values), sys.getrefcount(binding_needle)
    for _ in range(100):
        for kwargs in ({"x": binding_needle}, {"bad": binding_needle}, {"lo": None}):
            try:
                _bisect.bisect_left(binding_values, binding_needle, **kwargs)
            except TypeError:
                pass
            else:
                raise AssertionError("Invalid native argument binding was accepted")
    del kwargs
    assert (sys.getrefcount(binding_values), sys.getrefcount(binding_needle)) == binding_refs
    import builtins
    original_value_error = builtins.ValueError
    try:
        builtins.ValueError = RuntimeError
        try:
            _bisect.bisect_left([], 0, lo=-1)
        except original_value_error:
            pass
        else:
            raise AssertionError("Native exceptions must ignore rebound builtins")
    finally:
        builtins.ValueError = original_value_error
    heap = [4, 1, 3, 2]
    _heapq.heapify(heap)
    assert [_heapq.heappop(heap) for _ in range(4)] == [1, 2, 3, 4]
    heap = [1, 4, 2, 3]
    _heapq.heapify_max(heap)
    assert [_heapq.heappop_max(heap) for _ in range(4)] == [4, 3, 2, 1]
    assert required_compiler() == 1
    assert ctypes.pythonapi._PyJac_CompilerBridgeVersion() == 4
    for retired in ("_jacpython_compile", "_jacpython_symtable", "_jacpython_tokenize", "_jacpython_image", "_jacpython_code"):
        assert not hasattr(sys, retired), retired
    assert not any(name.startswith("_jacpython_seed") for name in sys.modules)
    import io
    import symtable
    import tokenize
    import ast
    # A false comparison argument still evaluates later arguments and calls
    # the function. Exercise eval, assignment, and statement contexts.
    for comparison_value, expected in ((0, False), (2, True), (4, False)):
        for expression in ("capture(1 < value < 3, later())",
                           "capture(later(), 1 < value < 3, flag=later())",
                           "capture(1 < value < 3, 0 < value < 5)"):
            for template in ("{}", "result = {}", "{}\nresult = seen[-1]"):
                events = []
                seen = []
                def later():
                    events.append("later")
                    return 42
                def capture(*args, **kwargs):
                    seen.append((args, kwargs))
                    return seen[-1]
                scope = dict(value=comparison_value, capture=capture, later=later, seen=seen)
                source = template.format(expression)
                if template == "{}":
                    actual = eval(compile(source, "<compare-arguments>", "eval"), scope)
                else:
                    exec(compile(source, "<compare-arguments>", "exec"), scope)
                    actual = scope["result"]
                expected_args = ((expected, 42), {})
                if "flag=" in expression:
                    expected_args = ((42, expected), {"flag": 42})
                elif "0 < value" in expression:
                    expected_args = ((expected, 0 < comparison_value < 5), {})
                assert actual == expected_args and len(seen) == 1
                assert len(events) == expression.count("later()")
        assert eval("(1 < value < 3) == expected", dict(value=comparison_value, expected=expected))
    match_source = "def match_alias(value):\n match value:\n  case str() as text: return text\n  case _: return None\n"
    match_tree = ast.parse(match_source)
    assert isinstance(match_tree.body[0].body[0].cases[0].pattern.pattern, ast.MatchClass)
    for match_input in (match_source, match_tree):
        match_scope = {}
        exec(compile(match_input, "<match-alias>", "exec"), match_scope)
        assert match_scope["match_alias"]("retained") == "retained"
        assert match_scope["match_alias"](42) is None
    try:
        compile("def invalid_match(value):\n match value:\n  case captured: return captured\n  case _: return None\n", "<nested-diagnostic>", "exec")
    except SyntaxError:
        pass
    else:
        raise AssertionError("Nested codegen diagnostic was discarded")
    assert symtable.symtable("x=1", "<smoke>", "exec").lookup("x").is_global()
    assert list(tokenize.generate_tokens(io.StringIO("x=1\n").readline))
    for source in ('f"{value:{width}}"', 't"{value:{width}}"'):
        tokens = [item[:2] for item in tokenize.generate_tokens(io.StringIO(source).readline)]
        rebuilt = tokenize.untokenize(tokens)
        assert [item[:2] for item in tokenize.generate_tokens(io.StringIO(rebuilt).readline)] == tokens
    for prefix in ("r", "R", "rb", "br", "rB", "Rb", "bR", "Br", "RB", "BR"):
        for quote in ("'", '"'):
            for count in (1, 2):
                body = ("\\" + quote) * count
                source = prefix + quote * 3 + body + quote * 3
                expected = body.encode() if "b" in prefix.lower() else body
                assert eval(source) == expected, source
    namespace = {}
    exec(compile("""
def checked(ok, values):
    assert ok, f"{[item * 2 for item in values]}"
    return 42
scalar = lambda: "not a name"
sequence = lambda: ("not a name",)
member = lambda value: value in {("not a name",)}
def set_global():
    global declared, declared
    declared = 42
def outer():
    value = 0
    def inner():
        nonlocal value, value
        value = 42
    inner()
    return value
""", "<compiler-regressions>", "exec", optimize=0), namespace)
    assert namespace["checked"](True, None) == 42
    try:
        namespace["checked"](False, [1, 2])
    except AssertionError as error:
        assert str(error) == "[2, 4]", error
    else:
        raise AssertionError("Assertion message control flow was bypassed")
    assert namespace["member"](("not a name",))
    assert not namespace["member"]("not a name")
    frozen = next(c for c in namespace["member"].__code__.co_consts if isinstance(c, frozenset))
    sequence = next(c for c in namespace["sequence"].__code__.co_consts if isinstance(c, tuple))
    assert next(iter(frozen)) is sequence
    assert sequence[0] is namespace["scalar"]()
    namespace["set_global"]()
    assert namespace["declared"] == namespace["outer"]() == 42
    constants = {}
    # Inserting deferred module annotations must reindex pooled constants,
    # including a folded list which shares the call's keyword-name tuple.
    calls = []
    annotation_scope = {"record": lambda *args, **kwargs: calls.append((args, kwargs)), "flag": False}
    exec(compile("""
items: list[str] = ['first', 'second', 'third']
record(None)
record(first=None, second=None, third=None)
if flag:
    record('unreachable')
""", "<annotation-constant-pool>", "exec"), annotation_scope)
    assert annotation_scope["items"] == ["first", "second", "third"]
    assert calls == [((None,), {}), ((), {"first": None, "second": None, "third": None})]
    exec(compile("nul = '\\x00tail'\nempty = ''\nprefix = '\\x00'\n", "<nul-constants>", "exec"), constants)
    assert (constants["nul"], constants["empty"], constants["prefix"]) == (chr(0) + "tail", "", chr(0))
    for optimize in (0, 1, 2):
        constants = {}
        exec(compile("""
if True:
    truth = 1
else:
    truth = 2
if False:
    falsehood = 1
else:
    falsehood = 2
if __debug__:
    debug = True
else:
    debug = False
""", "<constant-conditions>", "exec", optimize=optimize), constants)
        assert (constants["truth"], constants["falsehood"], constants["debug"]) == (1, 2, optimize == 0)
    import ast
    tree = ast.parse("class Located:\n    value = 42\n")
    tree.body[0].lineno = 10
    tree.body[0].end_lineno = 11
    located_code = compile(tree, "<separate-class-body>", "exec")
    exec(located_code, namespace)
    assert namespace["Located"].value == 42
    assert all(end is None or end >= start for start, end, _, _ in located_code.co_positions())

    # Runtime callbacks cannot redirect the shipped native compiler.
    def unavailable(*args, **kwargs):
        raise AssertionError("Native JacPython called a retired Python adapter")

    for retired in ("_jacpython_compile", "_jacpython_symtable", "_jacpython_tokenize"):
        setattr(sys, retired, unavailable)
    try:
        assert eval("6 * 7") == 42
        assert symtable.symtable("x=1", "<native>", "exec").lookup("x").is_global()
        assert list(tokenize.generate_tokens(io.StringIO("x=1\n").readline))
    finally:
        for retired in ("_jacpython_compile", "_jacpython_symtable", "_jacpython_tokenize"):
            delattr(sys, retired)
    with tempfile.TemporaryDirectory(prefix="jac-python-cold-") as cache:
        for optimization in ([], ["-O"], ["-OO"]):
            subprocess.run(
                [sys.executable, "-I", "-S", "-B", "-X", "faulthandler", "-X", "pycache_prefix=" + cache]
                + optimization + ["-c", "import ast, ctypes, encodings, sys; "
                                  "ok = eval('6 * 7') == 42 and isinstance(ast.parse('x=1'), ast.Module); "
                                  "ok = ok and encodings.search_function.__code__.co_filename == encodings.__file__; "
                                  "ok = ok and not hasattr(sys, '_jacpython_compile'); "
                                  "sys.exit(0 if ok and ctypes.pythonapi._PyJac_CompilerBridgeVersion() == 4 else 1)"],
                check=True,
            )
    # Global definitions need stable module-level identities for pickle.
    definitions = {}
    exec("""
def define():
    global GlobalClass, GlobalFunction, GenericClass, GenericFunction, AsyncFunction
    class GlobalClass:
        class Nested:
            pass
    def GlobalFunction():
        pass
    class GenericClass[T]:
        pass
    def GenericFunction[T](value: T):
        return value
    async def AsyncFunction():
        pass
    class Local:
        pass
    return Local
Local = define()
class Enclosing:
    global GlobalFromClass, __hidden
    class GlobalFromClass:
        pass
    def __hidden():
        pass
""", definitions)
    for name in ("GlobalClass", "GlobalFunction", "GenericClass", "GenericFunction",
                 "AsyncFunction", "GlobalFromClass"):
        assert definitions[name].__qualname__ == name
    assert definitions["GlobalClass"].Nested.__qualname__ == "GlobalClass.Nested"
    assert definitions["Local"].__qualname__ == "define.<locals>.Local"
    assert definitions["_Enclosing__hidden"].__qualname__ == "__hidden"
    assert definitions["GlobalFunction"].__code__.co_qualname == "GlobalFunction"
    assert definitions["GenericFunction"].__code__.co_qualname == "GenericFunction"
    interactive = subprocess.run(
        [sys.executable, "-I", "-q", "-i"],
        input="def twice(value):\n    return value * 2\n\nprint('INTERACTIVE', twice(21))\n"
              "from __future__ import annotations\ndef typed(x: Missing):\n    return x\n\n"
              "print(typed.__annotations__)\n",
        text=True, capture_output=True, check=True,
    )
    assert "INTERACTIVE 42" in interactive.stdout, interactive
    assert "{'x': 'Missing'}" in interactive.stdout, interactive
    assert "Traceback" not in interactive.stderr, interactive.stderr
callback = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_int)(lambda value: value + 1)
assert callback(41) == 42
assert sysconfig.get_config_var("Py_ENABLE_SHARED") == 1
assert sysconfig.get_config_var("CC") == "cc"
# configure needs Misc/platform_triplet.c to produce wheel-compatible names.
# An empty platform silently builds a runtime that cannot import tagged wheels.
abi_platform = "darwin" if sys.platform == "darwin" else f"{platform.machine()}-linux-gnu"
assert sysconfig.get_config_var("SOABI") == f"cpython-314-{abi_platform}"
ca = Path(sys.executable).resolve().parents[2] / "build" / "cacert.pem"
assert ssl.create_default_context(cafile=str(ca)).cert_store_stats()["x509_ca"] > 0
for library in ("ssl", "crypto", "sqlite3", "mpdec", "lzma", "bz2", "expat", "z", "zstd", "ffi"):
    archive = ca.parent / "lib" / f"lib{library}.a"
    assert archive.is_file() and archive.stat().st_size > 8, archive
xml.parsers.expat.ParserCreate().Parse(b"<jac/>", True)
with tempfile.TemporaryDirectory(prefix="jac-python-venv-") as directory:
    try:
        venv.EnvBuilder(with_pip=True).create(directory)
    except subprocess.CalledProcessError as error:
        print(error.output.decode(errors="replace") if error.output else str(error), file=sys.stderr)
        raise
    subprocess.run(
        [str(Path(directory) / "bin/python"), "-I", "-c", "import ssl, sqlite3, pip; assert 6 * 7 == 42"],
        check=True,
    )
print(f"CPython {sys.version.split()[0]}: runtime module checks passed ({ssl.OPENSSL_VERSION})")
