"""Isolated reference-boundary checks, run under the pinned CPython with the GIL."""

import ctypes
import gc
import sys
import weakref
import warnings
import types


def python_function(name, result, *arguments):
    """Bind independently: the compiler also uses ctypes.pythonapi functions."""
    address = ctypes.cast(getattr(ctypes.pythonapi, name), ctypes.c_void_p).value
    assert address is not None
    return ctypes.PYFUNCTYPE(result, *arguments)(address)


def check_raise_helper(candidate_address):
    """Compare the port to Python raise, including stealing and bare reraise."""
    native = ctypes.PYFUNCTYPE(
        ctypes.c_int32, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p
    )(candidate_address)
    tstate = python_function("PyThreadState_Get", ctypes.c_void_p)()
    retain = python_function("Py_IncRef", None, ctypes.c_void_p)
    missing = object()

    def candidate(value, cause=missing):
        # do_raise consumes both references. The fixture retains its own
        # Python bindings so the transfer must use separate references.
        retain(id(value))
        if cause is not missing:
            retain(id(cause))
        return native(tstate, id(value), None if cause is missing else id(cause))

    def baseline(value, cause=missing):
        if cause is missing:
            raise value
        raise value from cause

    def outcome(function, value, cause):
        try:
            function(value, cause)
        except BaseException as error:
            result = (
                type(error).__name__, str(error),
                None if error.__cause__ is None else (
                    type(error.__cause__).__name__, str(error.__cause__)
                ),
                error.__suppress_context__,
            )
            # Comparing traceback frame layouts would compare the Python
            # fixture to its ctypes wrapper. Clear those frames before the
            # separate ownership checks below.
            error.__traceback__ = None
            return result
        raise AssertionError("raise returned without a Python exception")

    class ConstructorError(Exception):
        def __new__(cls):
            raise LookupError("exception construction failed")

    class BadConstructor(Exception):
        def __new__(cls):
            return 42

    values = [
        lambda: ValueError,
        lambda: ValueError("raised"),
        lambda: ConstructorError,
        lambda: BadConstructor,
        lambda: 42,
        lambda: None,
    ]
    causes = [
        lambda: missing,
        lambda: None,
        lambda: KeyError,
        lambda: KeyError("cause"),
        lambda: ConstructorError,
        lambda: BadConstructor,
        lambda: 42,
    ]
    for make_value in values:
        for make_cause in causes:
            expected = outcome(baseline, make_value(), make_cause())
            actual = outcome(candidate, make_value(), make_cause())
            assert actual == expected, (expected, actual)

    value = ValueError("owned operand")
    count = sys.getrefcount(value)
    outcome(candidate, value, missing)
    assert sys.getrefcount(value) == count
    invalid = []
    count = sys.getrefcount(invalid)
    outcome(candidate, invalid, missing)
    assert sys.getrefcount(invalid) == count

    try:
        native(tstate, None, None)
    except RuntimeError as error:
        assert str(error) == "No active exception to reraise"
    else:
        raise AssertionError("bare raise accepted without an active exception")

    active = ValueError("active handled exception")
    try:
        raise active
    except ValueError:
        try:
            native(tstate, None, None)
        except ValueError as reraised:
            assert reraised is active
        else:
            raise AssertionError("bare raise did not restore the handled exception")
    active.__traceback__ = None


def check_except_type_helper(candidate_address: int, name: str):
    """Validate error precedence, exception classes, and tuple subclasses."""
    prototype = ctypes.PYFUNCTYPE(ctypes.c_int32, ctypes.c_void_p, ctypes.c_void_p)
    native = prototype(candidate_address)
    baseline = python_function(name, ctypes.c_int32, ctypes.c_void_p, ctypes.c_void_p)
    assert candidate_address != ctypes.cast(baseline, ctypes.c_void_p).value
    tstate = python_function("PyThreadState_Get", ctypes.c_void_p)()

    class Group(ExceptionGroup):
        pass

    class TupleSubclass(tuple):
        def __iter__(self):
            raise AssertionError("the evaluator must read tuple slots directly")

        def __getitem__(self, key):
            raise AssertionError("the evaluator must read tuple slots directly")

    def observe(function, value):
        count = sys.getrefcount(value)
        try:
            status = function(tstate, id(value))
        except Exception as error:
            outcome = (type(error), str(error))
        else:
            outcome = (status,)
        assert sys.getrefcount(value) == count
        return outcome

    for value in (
        Exception, BaseException, ValueError, ExceptionGroup, BaseExceptionGroup,
        Group, (), (ValueError, TypeError), (ExceptionGroup, int), (int, Group),
        (ValueError, ExceptionGroup), ((ValueError,),), None, 42, int, "bad",
        ValueError("instance"), TupleSubclass((ValueError, TypeError)),
        TupleSubclass((ExceptionGroup,)),
    ):
        assert observe(native, value) == observe(baseline, value), (name, value)


def check_slice_helper(candidate_address: int, name: str):
    """Compare native support entry points to the pinned C evaluator helper."""
    prototype = ctypes.PYFUNCTYPE(
        ctypes.c_int32, ctypes.c_void_p, ctypes.POINTER(ctypes.c_ssize_t)
    )
    native = prototype(candidate_address)
    baseline = python_function(name, ctypes.c_int32, ctypes.c_void_p, ctypes.POINTER(ctypes.c_ssize_t))
    assert candidate_address != ctypes.cast(baseline, ctypes.c_void_p).value

    class Index:
        def __init__(self, result):
            self.result = result
            self.calls = 0

        def __index__(self):
            self.calls += 1
            return self.result

    class Raises:
        calls = 0

        def __index__(self):
            self.calls += 1
            raise ValueError("index callback failed")

    class Reenters:
        def __init__(self, function):
            self.function = function
            self.calls = 0

        def __index__(self):
            self.calls += 1
            output = ctypes.c_ssize_t(111)
            assert self.function(id(42), ctypes.byref(output)) == 1
            return output.value

    def observe(function, value):
        output = ctypes.c_ssize_t(314159)
        count = sys.getrefcount(value)
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            try:
                status = function(id(value), ctypes.byref(output))
            except Exception as error:
                outcome = ("error", type(error).__name__, str(error), output.value)
            else:
                outcome = ("ok", status, output.value)
        assert sys.getrefcount(value) == count
        return outcome, [(w.category.__name__, str(w.message)) for w in caught]

    for value in (None, False, True, 0, -1, 1, 1 << 400, -(1 << 400), 1.5, "bad", object()):
        expected = observe(baseline, value)
        actual = observe(native, value)
        assert actual == expected, (name, value, expected, actual)
    for result in (42, -1, 1 << 400, -(1 << 400), True, "bad", 1.5):
        value = Index(result)
        expected = observe(baseline, value)
        assert value.calls == 1
        actual = observe(native, value)
        assert value.calls == 2
        assert actual == expected, (name, result, expected, actual)
    value = Raises()
    assert observe(native, value) == observe(baseline, value)
    assert value.calls == 2
    left, right = Reenters(native), Reenters(baseline)
    assert observe(native, left) == observe(baseline, right)
    assert left.calls == right.calls == 1


def check_await_helper(candidate_address):
    native = ctypes.PYFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int32)(candidate_address)
    baseline = python_function("_PyEval_GetAwaitable", ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int32)
    assert candidate_address != ctypes.cast(baseline, ctypes.c_void_p).value
    release = python_function("Py_DecRef", None, ctypes.c_void_p)

    def observe(function, value, oparg):
        count = sys.getrefcount(value)
        try:
            pointer = function(id(value), oparg)
        except BaseException as error:
            result = (type(error).__name__, str(error))
        else:
            assert pointer
            # Reading through py_object adds a temporary Python reference;
            # remove it before checking the explicit returned ownership.
            obj = ctypes.cast(pointer, ctypes.py_object).value
            result = ('ok', type(obj).__name__, obj is value)
            del obj
            if pointer == id(value):
                assert sys.getrefcount(value) == count + 1
            release(pointer)
        assert sys.getrefcount(value) == count
        return result

    events = []

    class Iterator:
        def __iter__(self):
            return self
        def __next__(self):
            raise StopIteration
        def __del__(self):
            events.append('iterator deleted')

    class Await:
        def __await__(self):
            events.append('await')
            return Iterator()

    class BadAwait:
        def __await__(self):
            events.append('bad await')
            return 17

    class Raises:
        def __await__(self):
            events.append('raise')
            raise ValueError('await callback failed')

    for value in (None, 1, [], object(), Await(), BadAwait(), Raises()):
        for oparg in (0, 1, 2, -1, 50):
            events.clear()
            expected = observe(baseline, value, oparg), events.copy()
            events.clear()
            actual = observe(native, value, oparg), events.copy()
            assert actual == expected, (type(value), oparg, expected, actual)

    class Wait:
        def __await__(self):
            yield 'paused'

    async def coroutine():
        await Wait()

    @types.coroutine
    def generator():
        yield 'paused'

    for factory in (coroutine, generator):
        value = factory()
        try:
            assert observe(native, value, 0) == observe(baseline, value, 0)
            assert value.send(None) == 'paused'
            assert observe(native, value, 0) == observe(baseline, value, 0)
        finally:
            value.close()

    class Reenter:
        def __init__(self, function):
            self.function = function
        def __await__(self):
            events.append(observe(self.function, Await(), 0))
            return Iterator()

    events.clear()
    expected = observe(baseline, Reenter(baseline), 0), events.copy()
    events.clear()
    actual = observe(native, Reenter(native), 0), events.copy()
    assert actual == expected, (expected, actual)
    print('Await helper: errors, owners, finalizers, suspension and reentry passed')


def check_anext_helper(candidate_address):
    native = ctypes.PYFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p)(candidate_address)
    baseline = python_function("_PyEval_GetANext", ctypes.c_void_p, ctypes.c_void_p)
    assert candidate_address != ctypes.cast(baseline, ctypes.c_void_p).value
    release = python_function("Py_DecRef", None, ctypes.c_void_p)
    events = []

    def observe(function, value):
        count = sys.getrefcount(value)
        try:
            pointer = function(id(value))
        except BaseException as error:
            cause = error.__cause__
            result = ('error', type(error).__name__, str(error),
                      (type(cause).__name__, str(cause)) if cause else None,
                      error.__suppress_context__)
        else:
            assert pointer
            obj = ctypes.cast(pointer, ctypes.py_object).value
            result = ('ok', type(obj).__name__)
            if type(obj).__name__ == 'async_generator_asend':
                obj.close()
            del obj
            release(pointer)
        assert sys.getrefcount(value) == count
        return result

    class Iterator:
        def __iter__(self):
            return self
        def __next__(self):
            raise StopIteration
        def __del__(self):
            events.append('iterator deleted')

    class Awaitable:
        def __await__(self):
            events.append('await')
            return Iterator()
        def __del__(self):
            events.append('awaitable deleted')

    class Good:
        def __anext__(self):
            events.append('anext')
            return Awaitable()

    class Bad:
        def __anext__(self):
            events.append('bad anext')
            return 27

    class BadAwait:
        def __anext__(self):
            return self
        def __await__(self):
            events.append('bad await')
            return None

    class Raises:
        def __anext__(self):
            events.append('raise')
            raise LookupError('anext failed')

    class Stops:
        def __anext__(self):
            events.append('stop')
            raise StopAsyncIteration

    async def generator():
        yield 1

    for value in (None, 1, [], object(), Good(), Bad(), BadAwait(), Raises(), Stops(), generator()):
        events.clear()
        expected = observe(baseline, value), events.copy()
        events.clear()
        actual = observe(native, value), events.copy()
        assert actual == expected, (type(value), expected, actual)

    class Reenter:
        def __init__(self, function):
            self.function = function
        def __anext__(self):
            events.append(observe(self.function, Good()))
            return Awaitable()

    events.clear()
    expected = observe(baseline, Reenter(baseline)), events.copy()
    events.clear()
    actual = observe(native, Reenter(native)), events.copy()
    assert actual == expected, (expected, actual)
    print('ANext helper: errors, owners, finalizers, async generators and reentry passed')


def check_boundary(library):
    lib = ctypes.PyDLL(library)
    ptr = ctypes.c_void_p
    integer = ctypes.c_int64
    signatures = {
        "jacpy_ref_null": (ptr, []),
        "jacpy_ref_new": (ptr, [ptr]),
        "jacpy_ref_is_null": (integer, [ptr]),
        "jacpy_ref_close": (None, [ptr]),
        "jacpy_ref_clear": (None, [ctypes.POINTER(ptr)]),
        "jacpy_stack_null": (ptr, []),
        "jacpy_stack_is_null": (integer, [ptr]),
        "jacpy_stack_is_heap_safe": (integer, [ptr]),
        "jacpy_stack_is_int": (integer, [ptr]),
        "jacpy_stack_new": (ptr, [ptr]),
        "jacpy_stack_steal": (ptr, [ptr]),
        "jacpy_stack_dup": (ptr, [ptr]),
        "jacpy_stack_promote": (ptr, [ptr]),
        "jacpy_stack_object_new": (ptr, [ptr]),
        "jacpy_stack_object_borrow": (ptr, [ptr]),
        "jacpy_stack_object_steal": (ptr, [ptr]),
        "jacpy_stack_close": (None, [ptr]),
        "jacpy_stack_clear": (None, [ctypes.POINTER(ptr)]),
    }
    for name, (result, args) in signatures.items():
        function = getattr(lib, name)
        function.restype = result
        function.argtypes = args

    # This verifies the installed boundary, not an assumed pointer-null value.
    null = lib.jacpy_stack_null()
    assert lib.jacpy_ref_null() is None
    assert lib.jacpy_ref_is_null(None)
    assert not lib.jacpy_ref_is_null(id(None))
    assert null == 1
    assert lib.jacpy_stack_is_null(null)
    assert lib.jacpy_stack_is_heap_safe(null)
    assert lib.jacpy_stack_promote(null) == null
    assert lib.jacpy_stack_dup(null) == null
    assert lib.jacpy_stack_new(None) == null
    assert lib.jacpy_stack_steal(None) == null
    assert lib.jacpy_stack_object_new(null) is None
    assert lib.jacpy_stack_object_borrow(null) is None
    assert lib.jacpy_stack_object_steal(null) is None
    lib.jacpy_stack_close(null)
    lib.jacpy_ref_close(None)

    value = []
    count = sys.getrefcount(value)
    owner = lib.jacpy_ref_new(id(value))
    assert sys.getrefcount(value) == count + 1
    stack = lib.jacpy_stack_steal(owner)
    assert stack == id(value)
    assert sys.getrefcount(value) == count + 1
    assert lib.jacpy_stack_object_borrow(stack) == id(value)
    assert sys.getrefcount(value) == count + 1
    duplicate = lib.jacpy_stack_dup(stack)
    assert duplicate == stack
    assert sys.getrefcount(value) == count + 2
    lib.jacpy_stack_close(duplicate)
    owner = lib.jacpy_stack_object_steal(stack)
    assert owner == id(value)
    assert sys.getrefcount(value) == count + 1
    lib.jacpy_ref_close(owner)
    assert sys.getrefcount(value) == count

    # The tagged mortal borrow owns nothing. Promotion retains its object;
    # closing the borrow alone must not decref the original owner.
    borrowed = id(value) | 1
    assert not lib.jacpy_stack_is_heap_safe(borrowed)
    promoted = lib.jacpy_stack_promote(borrowed)
    assert lib.jacpy_stack_is_heap_safe(promoted)
    assert promoted == id(value)
    assert sys.getrefcount(value) == count + 1
    lib.jacpy_stack_close(borrowed)
    assert sys.getrefcount(value) == count + 1
    lib.jacpy_stack_close(promoted)
    assert sys.getrefcount(value) == count
    object_owner = lib.jacpy_stack_object_steal(borrowed)
    assert sys.getrefcount(value) == count + 1
    lib.jacpy_ref_close(object_owner)
    assert sys.getrefcount(value) == count

    for immortal in (None, True, False, 1):
        stack = lib.jacpy_stack_new(id(immortal))
        assert stack == id(immortal) | 1
        assert lib.jacpy_stack_is_heap_safe(stack)
        assert not lib.jacpy_stack_is_int(stack)
        lib.jacpy_stack_close(lib.jacpy_stack_dup(stack))
        lib.jacpy_stack_close(stack)

    for number in (0, 37, -31, (1 << 60) - 1, -(1 << 60)):
        tagged = ((number << 2) | 3) & ((1 << 64) - 1)
        assert lib.jacpy_stack_is_int(tagged)
        assert lib.jacpy_stack_is_heap_safe(tagged)
        assert lib.jacpy_stack_promote(tagged) == tagged
        assert lib.jacpy_stack_dup(tagged) == tagged
        try:
            lib.jacpy_stack_object_borrow(tagged)
        except TypeError as error:
            assert "tagged integer" in str(error)
        else:
            raise AssertionError("tagged integers cannot produce an object borrow")
        for convert in (lib.jacpy_stack_object_new, lib.jacpy_stack_object_steal):
            owner = convert(tagged)
            assert ctypes.cast(owner, ctypes.py_object).value == number
            lib.jacpy_ref_close(owner)
        lib.jacpy_stack_close(tagged)

    # CPython finalizers reenter this boundary and inspect the visible owner.
    # A stale slot would cause a second release here.
    events = []
    saved = []
    slot = ptr(null)

    class Resurrect:
        def __del__(self):
            events.append(slot.value)
            lib.jacpy_stack_clear(ctypes.byref(slot))
            saved.append(self)

    value = Resurrect()
    weak = weakref.ref(value)
    slot.value = lib.jacpy_stack_new(id(value))
    del value
    lib.jacpy_stack_clear(ctypes.byref(slot))
    assert events == [null]
    assert len(saved) == 1 and weak() is saved[0]
    saved.clear()
    gc.collect()
    assert weak() is None and events == [null]

    # An independently promoted frame borrow survives suspension/owner clear.
    class Payload:
        pass

    value = Payload()
    weak = weakref.ref(value)
    promoted = ptr(lib.jacpy_stack_promote(id(value) | 1))
    del value
    gc.collect()
    assert weak() is not None
    lib.jacpy_stack_clear(ctypes.byref(promoted))
    assert weak() is None and promoted.value == null

    object_slot = ptr()

    class ReenterObject:
        def __del__(self):
            events.append(object_slot.value)
            lib.jacpy_ref_clear(ctypes.byref(object_slot))

    value = ReenterObject()
    object_slot.value = lib.jacpy_ref_new(id(value))
    del value
    lib.jacpy_ref_clear(ctypes.byref(object_slot))
    assert events == [null, None]
    print("CPython reference boundary: null, ownership, tags, promotion, reentrancy passed")


if __name__ == "__main__":
    check_boundary(sys.argv[1])
