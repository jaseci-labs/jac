# Layer 0/1 replay regression tests. Harness lives in layer0_replay_harness.jac
# (importing it here must NOT pull in this file's tests -- see p3_gate sibling).
import from layer0_replay_harness {
    ReplayResult,
    replay_expr,
    layer0_replay_source,
    layer1_replay_source,
}

# ---------------- tests ----------------
test "layer0: self-contained integer asserts replay against the host" {
    src = "class TestInt(unittest.TestCase):\n"
    "    def test_arithmetic(self):\n"
    "        self.assertEqual(1 + 1, 2)\n"
    "        self.assertEqual(17 % 5, 2)\n"
    "        self.assertEqual(2 ** 10, 1024)\n"
    "        self.assertEqual(100 // 7, 14)\n"
    "        self.assertEqual((3 < 5), True)\n"
    "        self.assertEqual(self.value, 5)\n";
    result = layer0_replay_source(src);
    assert result.passed == 5;
    assert result.skipped == 1;  # self.value is fixture-dependent
    assert result.failed == 0;
}

test "layer0: container and string asserts replay" {
    src = "class TestSeq(unittest.TestCase):\n"
    "    def test_seq(self):\n"
    "        self.assertEqual([1, 2, 3][1], 2)\n"
    "        self.assertEqual((1, 2) + (3, 4), (1, 2, 3, 4))\n"
    "        self.assertEqual('ab' + 'cd', 'abcd')\n"
    "        self.assertEqual({'k': 7}['k'], 7)\n"
    "        self.assertEqual('hello'[1], 'e')\n";
    result = layer0_replay_source(src);
    assert result.passed == 5;
    assert result.skipped == 0;
    assert result.failed == 0;
}

test "layer0: a genuine divergence is reported, not hidden" {
    # replay_expr on an expression the ceval computes must match the host.
    assert replay_expr("6 * 7") == True;
    assert replay_expr("2 + 3 * 4") == True;
    assert replay_expr("[0, 1, 2][2]") == True;
}

test "layer0: non-ASCII str constants survive marshal UTF-8 decode" {
    # Regression guard for the read_utf8 Latin-1 bug: multi-byte codepoints in a
    # marshaled str constant must round-trip so int() sees the real digits.
    # Devanagari, Arabic-Indic, unicode whitespace, and a Latin-1 supplement char.
    assert replay_expr("int('१२३४५६७८९०1234567890')") == True;
    assert replay_expr("int('١٢٣٤٥٦٧٨٩٠')") == True;
    assert replay_expr("int('\\N{EM SPACE}-3\\N{EN SPACE}')") == True;
    assert replay_expr("'café' + 'x'") == True;
}

test "layer0: str %-format (Gap #2) replays against the host" {
    # Conversions, flags, width, precision, tuple/single/mapping args.
    assert replay_expr("'%d' % 42") == True;
    assert replay_expr("'%d' % -7") == True;
    assert replay_expr("'%x' % 255") == True;
    assert replay_expr("'%X' % 255") == True;
    assert replay_expr("'%o' % 8") == True;
    assert replay_expr("'%#x' % 255") == True;
    assert replay_expr("'%05d' % 42") == True;
    assert replay_expr("'%-5d|' % 42") == True;
    assert replay_expr("'%+d' % 42") == True;
    assert replay_expr("'%.3d' % 7") == True;
    assert replay_expr("'%c' % 65") == True;
    assert replay_expr("'%s=%d' % ('x', 5)") == True;
    assert replay_expr("'%r' % 'hi'") == True;
    assert replay_expr("'%(a)s-%(b)d' % {'a': 'p', 'b': 3}") == True;
    assert replay_expr("'%d' % True") == True;
    assert replay_expr("'%x' % False") == True;
}

test "layer0: LOAD_SMALL_INT decodes 128..255 as non-negative" {
    # Regression guard: the ceval LOAD_SMALL_INT handler sign-extended its
    # unsigned oparg, mis-decoding 128..255 (e.g. 255 -> -1).
    assert replay_expr("255") == True;
    assert replay_expr("128") == True;
    assert replay_expr("200 + 55") == True;
    assert replay_expr("255 % 16") == True;
}

test "layer0: int/bool .real/.imag (Gap #3) replay against the host" {
    assert replay_expr("(5).real") == True;
    assert replay_expr("(5).imag") == True;
    assert replay_expr("(7).numerator") == True;
    assert replay_expr("(7).denominator") == True;
    assert replay_expr("True.real") == True;
    assert replay_expr("True.imag") == True;
    assert replay_expr("False.real") == True;
    assert replay_expr("False.imag") == True;
}

test "layer0: non-str-keyed host dicts stay opaque and round-trip" {
    # The native PyDict keys on str; a host dict with non-str keys (maketrans
    # returns {ordinal: repl}) is kept opaque as a PyHostProxy so it round-trips
    # through to_host unchanged instead of being corrupted by str(key).
    assert replay_expr("'abc'.translate(str.maketrans('a', 'X'))") == True;
    assert replay_expr("'abc'.translate(str.maketrans({'a': 'X'}))") == True;
    assert replay_expr("'abc'.translate(str.maketrans({'a': None}))") == True;
    assert replay_expr("'axb'.translate(str.maketrans({'a': None, 'b': '12'}))")
        == True;
    assert replay_expr("len(str.maketrans('ab', 'XY'))") == True;
    # A dict literal with non-str keys (BUILD_MAP) is likewise built on the host
    # and kept opaque, so subscript / len / equality all replay.
    assert replay_expr("{1: 2}") == True;
    assert replay_expr("{1: 2, 3: 4}[3]") == True;
    assert replay_expr("len({10: 20, 30: 40})") == True;
    assert replay_expr("{1: 'a', 2: 'b'}") == True;
}

test "layer0: native sets (BUILD_SET / SET_UPDATE / const) via hash-key protocol" {
    # Native PySet (H3): set literals + set algebra (&, -, ^, |) run natively
    # through PySet.nb_binop, and TYPE_SET/TYPE_FROZENSET marshal constants
    # (>=3 members => LOAD_CONST frozenset + SET_UPDATE) decode to native sets.
    # Mixed native-set / host-view ops (dict.keys() | {2}) fall back to the host.
    assert replay_expr("{1, 2}") == True;
    assert replay_expr("{1, 2, 3}") == True;
    assert replay_expr("{1, 2, 3} & {2, 3, 4}") == True;
    assert replay_expr("{1, 2, 3} - {2}") == True;
    assert replay_expr("{1, 2, 3} ^ {2, 3, 4}") == True;
    assert replay_expr("{1, 2} | {2, 3}") == True;
    assert replay_expr("len({1, 2, 3, 4})") == True;
    assert replay_expr("frozenset({1, 2}) | {3}") == True;
    # dict-view set operations (the test_dict cases that drove this).
    assert replay_expr("{1: 1}.keys() | {2}") == True;
    assert replay_expr("{2} | {1: 1}.items()") == True;
}

test "layer0: dict-view repr round-trips as dict_keys/values/items(...)" {
    # A native PyDictView reaching repr() must present as `dict_keys([...])`, not a
    # bare list -- to_host rebuilds a real host view (keys/values/items) so both
    # iteration AND repr conform. Order follows the dict's insertion order.
    assert replay_expr("repr({'a': 1, 'b': 2}.keys())") == True;
    assert replay_expr("repr({'a': 1, 'b': 2}.values())") == True;
    assert replay_expr("repr({'a': 1, 'b': 2}.items())") == True;
    assert replay_expr("repr({}.keys())") == True;
    # And the materializing consumers still work off the rebuilt view.
    assert replay_expr("list({'a': 1, 'b': 2}.keys())") == True;
    assert replay_expr("sorted({'b': 2, 'a': 1}.values())") == True;
    assert replay_expr("set({'a': 1, 'b': 2}.items())") == True;
}

test "layer0: unported binops fall back to the host" {
    # Native nb_binop covers the ported fast paths; combos it doesn't (str %
    # with %f/%i or multiple args, str * int, list * int) fall back to host
    # CPython. Only a native error triggers the fallback, so ported paths win.
    assert replay_expr("'%s, %s, %i, %f, %5.2f' % ('a', 'b', 1, 2, 3)") == True;
    assert replay_expr("'%.2f' % 3.14159") == True;
    assert replay_expr("'%i-%f' % (5, 2.5)") == True;
    assert replay_expr("'ab' * 3") == True;
    assert replay_expr("3 * 'ab'") == True;
    assert replay_expr("[1, 2] * 2") == True;
    assert replay_expr("(1, 2) * 3") == True;
}

test "layer0: f-string / format opcodes replay against the host" {
    # CONVERT_VALUE (!s/!r/!a), FORMAT_SIMPLE, FORMAT_WITH_SPEC, BUILD_STRING.
    # CPython also folds "%s" % x into these, so plain %s-format lands here too.
    assert replay_expr("f'{5}-{3.14:.1f}'") == True;
    assert replay_expr("f'{\"hi\"!r}'") == True;
    assert replay_expr("f'{255:05d}'") == True;
    assert replay_expr("f'{42:x}'") == True;
    assert replay_expr("f'{\"ab\"!a}'") == True;
    assert replay_expr("'%s, %s' % ('abc', 'abc')") == True;
    assert replay_expr("'{0:^12}'.format(3 + 2.0j)") == True;
    assert replay_expr("'{0:.2f}'.format(3.14159)") == True;
    assert replay_expr("format(255, 'x')") == True;
    assert replay_expr("f'{1}{2}{3}'") == True;
}

test "layer0: native-container methods route to host during bootstrap" {
    # py_attr falls back to host_getattr for host-backed tags (str/list/dict/...)
    # when the native tp_getattro has no method yet. The bound method comes back
    # as a callable PyHostProxy, so the CALL executes it on the host and marshals
    # the result home. This is the bootstrap seam; objects.jac stays na-clean.
    assert replay_expr("'hello'.upper()") == True;
    assert replay_expr("'HELLO'.lower()") == True;
    assert replay_expr("'a,b,c'.split(',')") == True;
    assert replay_expr("'  hi  '.strip()") == True;
    assert replay_expr("'abcabc'.replace('a', 'X')") == True;
    assert replay_expr("'abc'.startswith('ab')") == True;
    assert replay_expr("'x'.join(['a', 'b', 'c'])") == True;
    assert replay_expr("[3, 1, 2].count(1)") == True;
    assert replay_expr("[1, 2, 3].index(2)") == True;
    assert replay_expr("{'a': 1, 'b': 2}.get('a')") == True;
    assert replay_expr("list({'a': 1}.keys())") == True;
    assert replay_expr("list({'a': 1, 'b': 2}.values())") == True;
    assert replay_expr("{'a': 1}.copy()") == True;
    assert replay_expr("(5).bit_length()") == True;
}

test "layer0: LIST_EXTEND addresses the list under a callable+NULL" {
    # Regression guard: a >=3-const list literal compiles to BUILD_LIST 0 +
    # LOAD_CONST tuple + LIST_EXTEND. When a callable and its PUSH_NULL sit
    # below it (len([...]), tuple([...])), the extend must target the list, not
    # the NULL. The prior off-by-one only survived on bare list literals.
    assert replay_expr("len([0, 1, 2])") == True;
    assert replay_expr("len([0, 1, 2, 3, 4])") == True;
    assert replay_expr("tuple([0, 1, 2, 3])") == True;
    assert replay_expr("sum([1, 2, 3, 4])") == True;
    assert replay_expr("[1, 2, 3]") == True;
    assert replay_expr("[1, 2, 3][1]") == True;
    assert replay_expr("max([3, 1, 4, 1, 5])") == True;
}

test "layer0: generator expressions replay through real frame suspend/resume" {
    # P5 generators-as-state-machines: a genexpr-flagged code object returns a
    # PyGenerator on call; YIELD_VALUE suspends the frame and gen_resume drives
    # it forward one value at a time. Consumers reach it either natively
    # (FOR_ITER over the generator) or across the host boundary (list()/tuple()/
    # sum() drain it via gen_drain). Covers the tuple()/frozenset() fast path
    # (LOAD_COMMON_CONSTANT + CALL_INTRINSIC_1 LIST_TO_TUPLE), the SWAP-heavy
    # inlined list comprehension (LOAD_FAST_AND_CLEAR), host-iterable sources
    # (range), and the `if` filter.
    assert replay_expr("list(x * 2 for x in [1, 2, 3])") == True;
    assert replay_expr("tuple(x for x in range(4))") == True;
    assert replay_expr("sum(x for x in [1, 2, 3, 4])") == True;
    assert replay_expr("list(x for x in [1, 2, 3, 4] if x > 2)") == True;
    assert replay_expr("[x * x for x in range(5)]") == True;
    assert replay_expr("tuple(y for y in (x * 2 for x in range(3)))") == True;
    assert replay_expr("max(x for x in [3, 1, 4, 1, 5])") == True;
    assert replay_expr("sorted(x for x in [3, 1, 2])") == True;
    assert replay_expr("list(c for c in 'abc')") == True;
    assert replay_expr("frozenset(x % 2 for x in range(5))") == True;
}

test "layer0: memoryview + slicing (Gap #4) replay against the host" {
    # memoryview host proxy + constant-slice subscript (BINARY_OP []) + int().
    assert replay_expr("int(memoryview(b'123')[1:3])") == True;
    assert replay_expr("int(memoryview(b'1234')[1:3])") == True;
    assert replay_expr("bytes(memoryview(b'abcdef')[2:4])") == True;
    # native-container slicing across the three slice opcodes (LOAD_CONST slice,
    # BINARY_SLICE, BUILD_SLICE) and negative index/step.
    assert replay_expr("'abcdef'[1:4]") == True;
    assert replay_expr("'abcdef'[::-1]") == True;
    assert replay_expr("'abcdef'[-2:]") == True;
    assert replay_expr("[1, 2, 3, 4, 5][1:3]") == True;
    assert replay_expr("[1, 2, 3, 4, 5][::-1]") == True;
    assert replay_expr("(1, 2, 3, 4, 5)[1:4]") == True;
    assert replay_expr("b'abcdef'[2:4]") == True;
    assert replay_expr("list(range(10))[2:5]") == True;
}

test "layer0: marshal decodes inf/nan float constants (no 0.0/0.0 trap)" {
    # CPython constant-folds these to inf/nan float consts; the marshal reader's
    # bytes_to_double must materialize them without `0.0 / 0.0` (a Jac
    # ZeroDivisionError). NaN compares equal to NaN as a conformance match.
    assert replay_expr("1e300 * 1e300") == True;
    assert replay_expr("-1e300 * 1e300") == True;
    assert replay_expr("1e300 * 1e300 * 0") == True;
    assert replay_expr("repr(1e300 * 1e300 * 0)") == True;
    assert replay_expr("str(1e300 * 1e300)") == True;
    assert replay_expr("float('inf')") == True;
    assert replay_expr("repr(float('nan'))") == True;
}

test "layer1: generator functions replay through the exec-mode method harness" {
    # Layer 1 lifts conformance from single expressions to whole test methods:
    # each method's setup (a generator def + binds) runs in both host and
    # jacpython, then every `self.assert*` argument is evaluated against that
    # shared, stateful namespace and diffed. This is the only leg that exercises
    # full generator FUNCTIONS -- def+yield, next()/state threading, .send(),
    # and `yield from` -- against a real test-file shape.
    src = "import unittest\n"
    "class TestGen(unittest.TestCase):\n"
    "    def test_drain(self):\n"
    "        def g():\n"
    "            yield 1\n"
    "            yield 2\n"
    "            yield 3\n"
    "        self.assertEqual(list(g()), [1, 2, 3])\n"
    "        self.assertEqual(sum(g()), 6)\n"
    "    def test_next_threads_state(self):\n"
    "        def g():\n"
    "            yield 10\n"
    "            yield 20\n"
    "        it = g()\n"
    "        self.assertEqual(next(it), 10)\n"
    "        self.assertEqual(next(it), 20)\n"
    "        self.assertEqual(next(it, -1), -1)\n"
    "    def test_send(self):\n"
    "        def acc():\n"
    "            total = 0\n"
    "            while True:\n"
    "                v = yield total\n"
    "                total += v\n"
    "        g = acc()\n"
    "        self.assertEqual(g.send(None), 0)\n"
    "        self.assertEqual(g.send(5), 5)\n"
    "        self.assertEqual(g.send(3), 8)\n"
    "    def test_yield_from(self):\n"
    "        def inner():\n"
    "            yield 1\n"
    "            yield 2\n"
    "            return 3\n"
    "        def outer():\n"
    "            r = yield from inner()\n"
    "            yield r\n"
    "        self.assertEqual(list(outer()), [1, 2, 3])\n"
    "    def test_exhaustion_raises(self):\n"
    "        def g():\n"
    "            yield 1\n"
    "        it = g()\n"
    "        self.assertEqual(next(it), 1)\n"
    "        with self.assertRaises(StopIteration):\n"
    "            next(it)\n"
    "    def test_send_non_none_to_new_gen(self):\n"
    "        def g():\n"
    "            yield 1\n"
    "        it = g()\n"
    "        with self.assertRaises(TypeError):\n"
    "            it.send(0)\n"
    "    def test_copy(self):\n"
    "        def f():\n"
    "            yield 1\n"
    "        g = f()\n"
    "        with self.assertRaises(TypeError):\n"
    "            copy.copy(g)\n"
    "    def test_close_clears_frame(self):\n"
    "        class DetectDelete:\n"
    "            def __init__(self):\n"
    "                DetectDelete.deleted = False\n"
    "            def __del__(self):\n"
    "                DetectDelete.deleted = True\n"
    "        def generator(arg):\n"
    "            yield\n"
    "        g = generator(DetectDelete())\n"
    "        g.close()\n"
    "        self.assertTrue(DetectDelete.deleted)\n"
    "        g = generator(DetectDelete())\n"
    "        next(g)\n"
    "        g.close()\n"
    "        self.assertTrue(DetectDelete.deleted)\n"
    "        g = generator(DetectDelete())\n"
    "        g.gi_frame.clear()\n"
    "        self.assertTrue(DetectDelete.deleted)\n"
    "    def test_uses_fixture(self):\n"
    "        self.assertEqual(self.value, 5)\n";
    result = layer1_replay_source(src);
    # Eight self-contained generator methods replay clean: four value-diff, three
    # assertRaises (send-to-new-gen, uncopyable generator), and the frame-clearing
    # __del__ test (close()/gi_frame.clear() finalize the frame's held arg). The
    # fixture-dependent method (self.value) fails the host probe and is skipped.
    assert result.passed == 8;
    assert result.skipped == 1;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: set hash richcompare and iter protocol (P3.1e)" {
    src = "class TestSetProtocol(unittest.TestCase):\n"
    "    def test_set_eq(self):\n"
    "        self.assertEqual({1, 2, 3}, {3, 2, 1})\n"
    "        self.assertTrue({1} == {1})\n"
    "        self.assertFalse({1} == {2})\n"
    "    def test_hash_collapse(self):\n"
    "        self.assertEqual(hash(1), hash(1.0))\n"
    "        self.assertEqual(hash(1), hash(True))\n"
    "    def test_getiter(self):\n"
    "        it = iter([10, 20])\n"
    "        self.assertEqual(next(it), 10)\n"
    "        self.assertEqual(next(it), 20)\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: tuple hash richcompare and repr (P3.2a)" {
    src = "class TestTupleCore(unittest.TestCase):\n"
    "    def test_tuple_hash(self):\n"
    "        self.assertEqual(hash((1, 2)), hash((1, 2)))\n"
    "        self.assertNotEqual(hash((1,)), hash((1, 2)))\n"
    "    def test_tuple_richcompare(self):\n"
    "        self.assertEqual((1, 2), (1, 2))\n"
    "        self.assertLess((1,), (1, 2))\n"
    "        self.assertNotEqual((1, 2), (2, 1))\n"
    "    def test_tuple_repr(self):\n"
    "        self.assertEqual(repr((1,)), '(1,)')\n"
    "        self.assertEqual(repr(()), '()')\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: int hash and digit add (P3.2a)" {
    src = "class TestIntCore(unittest.TestCase):\n"
    "    def test_int_hash(self):\n"
    "        self.assertEqual(hash(1), hash(1.0))\n"
    "        self.assertEqual(hash(1), hash(True))\n"
    "        big = 10 ** 100\n"
    "        self.assertEqual(hash(big), hash(big))\n"
    "    def test_bigint_add(self):\n"
    "        a = 10 ** 50\n"
    "        self.assertEqual(a + a, 2 * a)\n"
    "    def test_bigint_compare(self):\n"
    "        self.assertLess(10 ** 50, 10 ** 50 + 1)\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: set and frozenset hash and equality (P3.2a)" {
    src = "class TestSetCore(unittest.TestCase):\n"
    "    def test_set_eq(self):\n"
    "        self.assertEqual({1, 2, 3}, {3, 2, 1})\n"
    "        self.assertNotEqual({1, 2}, {1, 3})\n"
    "    def test_frozenset_hash(self):\n"
    "        self.assertEqual(hash(frozenset({1, 2})), hash(frozenset({2, 1})))\n"
    "        self.assertEqual(hash(frozenset()), hash(frozenset()))\n"
    "    def test_set_unhashable(self):\n"
    "        with self.assertRaises(TypeError):\n"
    "            hash({1})\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: exception isinstance str and repr (P3.2a)" {
    src = "class TestExcCore(unittest.TestCase):\n"
    "    def test_isinstance_exc(self):\n"
    "        e = ValueError('x')\n"
    "        self.assertTrue(isinstance(e, ValueError))\n"
    "        self.assertTrue(isinstance(e, Exception))\n"
    "        self.assertFalse(isinstance(e, TypeError))\n"
    "    def test_str_exc(self):\n"
    "        self.assertEqual(str(ValueError('hello')), 'hello')\n"
    "        self.assertEqual(str(ValueError()), '')\n"
    "    def test_repr_exc(self):\n"
    "        self.assertEqual(repr(ValueError('x')), \"ValueError('x')\")\n"
    "        self.assertEqual(repr(ValueError()), 'ValueError()')\n"
    "        self.assertEqual(repr(ValueError(\"it's\")), 'ValueError(\"it\\'s\")')\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: dict equality repr and key collision (P3.2a)" {
    src = "class TestDictCore(unittest.TestCase):\n"
    "    def test_dict_unhashable(self):\n"
    "        with self.assertRaises(TypeError):\n"
    "            hash({})\n"
    "    def test_dict_equal(self):\n"
    "        self.assertEqual({1: 2}, {1: 2})\n"
    "        self.assertNotEqual({1: 2}, {2: 1})\n"
    "    def test_key_collision(self):\n"
    "        d = {}\n"
    "        d[1] = 'a'\n"
    "        d[1.0] = 'b'\n"
    "        self.assertEqual(len(d), 1)\n"
    "        self.assertEqual(d[True], 'b')\n"
    "    def test_dict_repr(self):\n"
    "        self.assertEqual(repr({}), '{}')\n"
    "        self.assertEqual(repr({1: 2}), '{1: 2}')\n";
    result = layer1_replay_source(src);
    assert result.passed == 4;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: bytes hash richcompare and repr (P3.2a)" {
    src = "class TestBytesCore(unittest.TestCase):\n"
    "    def test_bytes_hash(self):\n"
    "        self.assertEqual(hash(b'abc') == hash(b'abc'), True)\n"
    "        self.assertNotEqual(hash(b'a'), hash(b'b'))\n"
    "    def test_bytes_richcompare(self):\n"
    "        self.assertEqual(b'abc', b'abc')\n"
    "        self.assertLess(b'a', b'b')\n"
    "        self.assertNotEqual(b'abc', b'abd')\n"
    "    def test_bytes_repr(self):\n"
    "        self.assertEqual(repr(b'abc'), \"b'abc'\")\n"
    "        self.assertEqual(repr(b'\\t'), \"b'\\\\t'\")\n"
    "        self.assertEqual(repr(b\"it's\"), 'b\"it\\'s\"')\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: list richcompare and repr (P3.2a)" {
    src = "class TestListCore(unittest.TestCase):\n"
    "    def test_list_richcompare(self):\n"
    "        self.assertEqual([1, 2], [1, 2])\n"
    "        self.assertLess([1], [1, 2])\n"
    "        self.assertNotEqual([1, 2], [2, 1])\n"
    "    def test_list_repr(self):\n"
    "        self.assertEqual(repr([]), '[]')\n"
    "        self.assertEqual(repr([1, 2]), '[1, 2]')\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: type repr identity and isinstance (P3.2a)" {
    src = "class TestTypeCore(unittest.TestCase):\n"
    "    def test_type_repr(self):\n"
    "        class C:\n"
    "            pass\n"
    "        self.assertEqual(repr(C), \"<class '__main__.C'>\")\n"
    "        self.assertEqual(repr(int), \"<class 'int'>\")\n"
    "    def test_type_identity(self):\n"
    "        self.assertTrue(int is int)\n"
    "        self.assertTrue(int == int)\n"
    "        self.assertFalse(int == float)\n"
    "    def test_isinstance_basics(self):\n"
    "        self.assertTrue(isinstance(1, int))\n"
    "        class C:\n"
    "            pass\n"
    "        c = C()\n"
    "        self.assertTrue(isinstance(c, C))\n"
    "        self.assertFalse(isinstance(c, int))\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: list repr and richcompare survive operand mutation" {
    src = "class TestListMutate(unittest.TestCase):\n"
    "    def test_repr_mutate(self):\n"
    "        class Obj:\n"
    "            @staticmethod\n"
    "            def __repr__():\n"
    "                try:\n"
    "                    mylist.pop()\n"
    "                except IndexError:\n"
    "                    pass\n"
    "                return 'obj'\n"
    "        mylist = [Obj() for _ in range(5)]\n"
    "        self.assertEqual(repr(mylist), '[obj, obj, obj]')\n"
    "    def test_equal_operator_modifying_operand(self):\n"
    "        class X:\n"
    "            def __eq__(self, other):\n"
    "                list2.clear()\n"
    "                return NotImplemented\n"
    "        class Y:\n"
    "            def __eq__(self, other):\n"
    "                list1.clear()\n"
    "                return NotImplemented\n"
    "        class Z:\n"
    "            def __eq__(self, other):\n"
    "                list3.clear()\n"
    "                return NotImplemented\n"
    "        list1 = [X()]\n"
    "        list2 = [Y()]\n"
    "        self.assertTrue(list1 == list2)\n"
    "        list3 = [Z()]\n"
    "        list4 = [1]\n"
    "        self.assertFalse(list3 == list4)\n"
    "    def test_lt_operator_modifying_operand(self):\n"
    "        class evil:\n"
    "            def __lt__(self, other):\n"
    "                other.clear()\n"
    "                return NotImplemented\n"
    "        a = [[evil()]]\n"
    "        with self.assertRaises(TypeError):\n"
    "            a[0] < a\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: hash routing and compare protocol probes (P3.1e/M10)" {
    src = "class TestProtocolCore(unittest.TestCase):\n"
    "    def test_hash_neg1_sentinel(self):\n"
    "        self.assertEqual(hash(-1), -2)\n"
    "        self.assertNotEqual(hash((-1,)), -1)\n"
    "    def test_hash_str_float_stable(self):\n"
    "        self.assertEqual(hash('a') == hash('a'), True)\n"
    "        self.assertEqual(hash(1.5), hash(1.5))\n"
    "        self.assertEqual(hash(1.0), hash(1))\n"
    "        self.assertEqual(hash(1.5), 1152921504606846977)\n"
    "    def test_bool_int_equality(self):\n"
    "        self.assertTrue(True == 1)\n"
    "        self.assertTrue(1 == True)\n"
    "        self.assertEqual(hash(1), hash(True))\n"
    "    def test_cross_type_ordering(self):\n"
    "        with self.assertRaises(TypeError):\n"
    "            1 < 'a'\n"
    "        with self.assertRaises(TypeError):\n"
    "            (1, 2) < 'a'\n";
    result = layer1_replay_source(src);
    assert result.passed == 4;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer1: user subclass construction after type_ready (P5 heap types)" {
    src = "class TestHeapType(unittest.TestCase):\n"
    "    def test_subclass_attrs(self):\n"
    "        class A:\n"
    "            x = 1\n"
    "        class B(A):\n"
    "            y = 2\n"
    "        self.assertEqual(B.x, 1)\n"
    "        self.assertEqual(B().y, 2)\n"
    "    def test_mro_lookup(self):\n"
    "        class Base:\n"
    "            def f(self):\n"
    "                return 1\n"
    "        class Sub(Base):\n"
    "            pass\n"
    "        self.assertEqual(Sub().f(), 1)\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# P3 corpus ratchet tests live in ``layer0_replay_p3_gate.jac`` so they run in
# isolation (this file's 56 replay regression tests mutate ceval state).
