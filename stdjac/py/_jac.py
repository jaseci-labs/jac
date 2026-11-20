"""What Jac's values mean on CPython: the helpers the Python backend's
modules import as `_jac`, the runtime's entry points stdjac calls, the graph,
and the loader for a space's code objects. (stdjac itself, the server and
the crossings' stubs among it, is Jac compiled for CPython.)

A Jac `obj` is a class over JacObj, whose `__jac_fields__` list each field,
its default (made per instance) and whether it has one, a base's first: it is
made by its class's `init`, its own or the one its fields give it. A field
its `postinit` sets (`has x: T postinit;`) is named in `__jac_late__`: no
constructor takes it.
"""

import contextvars
import itertools
import json
import marshal
import os
import sys
import threading
import types
import weakref


def _fields(cls):
    out = []
    for c in reversed(cls.__mro__):
        out.extend(c.__dict__.get("__jac_fields__", []))
    return out


def _late(cls):
    out = set()
    for c in cls.__mro__:
        out.update(c.__dict__.get("__jac_late__", ()))
    return out


class JacType(type):
    """A Jac class: dir() of it lists its fields with defaults, as native
    code's does."""

    def __dir__(cls):
        names = set(super().__dir__()) | {n for n, _, has in _fields(cls) if has}
        if getattr(cls.init, "_jac_fields", False):
            # The init its fields give it, which native code's has no name.
            names.discard("init")
        return sorted(names)


def _field_init(cls):
    """The `init` a class without one of its own has: its fields (a base's
    first) by position or keyword, those with defaults already set, then
    `postinit`, which sets the fields that are its own to set."""
    late = _late(cls)
    fields = [f for f in _fields(cls) if f[0] not in late]

    def init(self, *args, **kw):
        if isinstance(self, BaseException):
            # Its positional arguments are the exception's; its fields are
            # given by keyword.
            BaseException.__init__(self, *args)
            args = ()
        if len(args) > len(fields):
            raise TypeError(f"{cls.__name__}() takes {len(fields)} arguments, got {len(args)}")
        missing = []
        for i, (name, _, has_dflt) in enumerate(fields):
            if i < len(args):
                if name in kw:
                    raise TypeError(f"{cls.__name__}() got multiple values for argument '{name}'")
                object.__setattr__(self, name, args[i])
            elif name in kw:
                object.__setattr__(self, name, kw.pop(name))
            elif not has_dflt:
                missing.append(name)
        if kw:
            raise TypeError(f"{cls.__name__}() got an unexpected keyword argument '{next(iter(kw))}'")
        if missing:
            # As native code's constructor and CPython word it.
            quoted = [f"'{n}'" for n in missing]
            text = quoted[0] if len(quoted) == 1 else " and ".join(quoted) if len(quoted) == 2 else ", ".join(quoted[:-1]) + ", and " + quoted[-1]
            raise TypeError(
                f"{cls.__name__}() missing {len(missing)} required positional argument{'s' if len(missing) > 1 else ''}: {text}"
            )
        # (Looked up on the class: an instance's __getattr__ isn't asked.)
        post = getattr(type(self), "postinit", None)
        if callable(post):
            post(self)

    init.__qualname__ = cls.__qualname__ + ".init"
    init._jac_fields = True
    return init


def _plain_repr(self):
    return f"<{type(self).__name__} object>"


class JacObj(metaclass=JacType):
    """A Jac object: made by its class's `init`, its own or the one its fields
    give it."""

    # (A class over it holds its fields in its instance's dict, but a
    # struct's, which are its slots: Struct.)
    __slots__ = ()

    def __init_subclass__(cls, **kw):
        super().__init_subclass__(**kw)
        if "init" not in cls.__dict__:
            cls.init = _field_init(cls)
        plain = cls.__dict__.get("__jac_plain__", False)
        below_plain = any(k.__dict__.get("__jac_plain__", False) for k in cls.__mro__[1:])
        if plain and not below_plain and not issubclass(cls, BaseException):
            # A Jac `class`, Python's plain class: nothing is generated for
            # it. With no repr, equality or hash written, it prints as
            # `<Name object>`, equals only itself and hashes by identity; a
            # class below it inherits what it has, as Python's does.
            if "__repr__" not in cls.__dict__:
                cls.__repr__ = _plain_repr
            if "__eq__" not in cls.__dict__:
                cls.__eq__ = object.__eq__
                if "__hash__" not in cls.__dict__:
                    cls.__hash__ = object.__hash__
        elif not plain and not issubclass(cls, BaseException):
            if "__repr__" not in cls.__dict__:
                # As a dataclass's: an obj without its own repr has the one
                # its fields give it.
                cls.__repr__ = JacObj.__dict__["__repr__"]
            if below_plain and "__eq__" not in cls.__dict__:
                # An obj below a `class` is a value again.
                cls.__eq__ = JacObj.__dict__["__eq__"]
                if "__hash__" not in cls.__dict__:
                    cls.__hash__ = None
        hook = cls.__dict__.get("__setattr__")
        if hook is not None:
            # A field is the object's own slot: setting it never reaches the
            # class's __setattr__, which sees only what the class lacks.
            def __setattr__(self, name, value, _hook=hook):
                if any(name == n for n, _, _ in _fields(type(self))):
                    object.__setattr__(self, name, value)
                else:
                    _hook(self, name, value)

            cls.__setattr__ = __setattr__
        if issubclass(cls, BaseException):
            # An exception's text, equality and hash stay the exception's.
            for name in ("__repr__", "__eq__", "__hash__"):
                if name not in cls.__dict__:
                    setattr(cls, name, getattr(BaseException, name))

    def __dir__(self):
        names = object.__dir__(self)
        if getattr(type(self).init, "_jac_fields", False):
            names = [n for n in names if n != "init"]
        return names

    def __init__(self, *args, **kw):
        # Every field with a default has it before any `init` runs.
        for name, dflt, has_dflt in _fields(type(self)):
            if has_dflt:
                object.__setattr__(self, name, dflt())
        self.init(*args, **kw)

    def __repr__(self):
        inner = ", ".join(f"{n}={getattr(self, n)!r}" for n, _, _ in _fields(type(self)))
        return f"{type(self).__name__}({inner})"

    # An obj is a value: with no __eq__ of its own, == compares its
    # fields, each as a tuple's item (itself, or ==), as a dataclass's does;
    # an instance of another class is unequal. It isn't hashable unless a
    # class along its MRO gives it a __hash__; one whose own __eq__ comes
    # without a __hash__ isn't either (CPython takes it away).
    def __eq__(self, other):
        if type(other) is not type(self):
            return NotImplemented
        for n, _, _ in _fields(type(self)):
            a = getattr(self, n)
            b = getattr(other, n)
            if a is not b and not a == b:
                return False
        return True

    __hash__ = None


JacObj.init = _field_init(JacObj)


class _Absent:
    """A struct's method that changes it, on a copy an any holds: not found
    there, as native code's box has none of them."""

    __slots__ = ("name",)

    def __init__(self, name):
        self.name = name

    def __get__(self, obj, owner=None):
        raise AttributeError(f"'{(owner or type(obj)).__name__}' object has no attribute '{self.name}'")


def _boxed_setattr(self, name, value):
    raise AttributeError(f"'{type(self).__name__}' object has no attribute '{name}'")


class Struct(JacObj):
    """A Jac struct: a value held in place. Each variable and field
    holding one holds an instance of its own, so the compiler copies it
    (`copy`) where the language copies a value; what changes one changes
    that instance, the place itself. A struct an any holds is a copy of its
    class's box (`box`): its fields not set and its methods that change it
    (`__jac_mut__`) not found, as native code's. `==` compares fields, each
    as `==` does (a NaN equal to nothing, itself among them), and hash()
    hashes them as a tuple of them is hashed (a struct with an `__eq__` of
    its own and no `__hash__` is unhashable, as any class is)."""

    __slots__ = ()

    def __init_subclass__(cls, _box_of=None, **kw):
        if _box_of is not None:
            return
        super().__init_subclass__(**kw)
        cls.__jac_struct__ = cls
        cls.__jac_names__ = tuple(n for n, _, _ in _fields(cls))
        ns = {"__slots__": (), "__setattr__": _boxed_setattr, "__delattr__": _boxed_setattr}
        for m in cls.__dict__.get("__jac_mut__", ()):
            ns[m] = _Absent(m)
        boxed = JacType(cls.__name__, (cls,), ns, _box_of=cls)
        boxed.__qualname__ = cls.__qualname__
        boxed.__module__ = cls.__module__
        cls.__jac_box__ = boxed

    def __eq__(self, other):
        if not isinstance(other, Struct) or other.__jac_struct__ is not self.__jac_struct__:
            return NotImplemented
        for n in self.__jac_names__:
            if not getattr(self, n) == getattr(other, n):
                return False
        return True

    def __hash__(self):
        return hash(tuple(getattr(self, n) for n in self.__jac_names__))


class Array(list):
    """A Jac array: a value held in place, of a fixed length,
    as a list of its elements. Each variable, field and element holding one
    holds an instance of its own, so the compiler copies it (`copy`) where
    the language copies a value. An element is read and written at an index
    of the array's, from 0 (IndexError for any other, a negative one among
    them, as native code's); `==` compares elements, each as `==` does (a
    NaN equal to nothing, itself among them), and hash() hashes them as a
    tuple of them is hashed. An any holds a copy as a list (`box`), as native
    code boxes one."""

    __slots__ = ()

    def __getitem__(self, i):
        if i < 0 or i >= len(self):
            raise IndexError("array index out of range")
        return list.__getitem__(self, i)

    def __setitem__(self, i, v):
        if i < 0 or i >= len(self):
            raise IndexError("array index out of range")
        list.__setitem__(self, i, v)

    def __eq__(self, other):
        if not isinstance(other, list):
            return NotImplemented
        return len(self) == len(other) and all(a == b for a, b in zip(self, other))

    def __ne__(self, other):
        eq = self.__eq__(other)
        return eq if eq is NotImplemented else not eq

    def __hash__(self):
        return hash(tuple(self))


class Sized:
    """An array's element type that is a sized int (i8 ... u64): the
    descriptor `convert` fits an element arriving from an any to."""

    __slots__ = ("w", "uns")

    def __init__(self, w, uns):
        self.w = w
        self.uns = uns


def array(n, zero, *vals):
    """`array[T, n](...)`: no value, each element `zero()`; one value, each
    element a copy of it; or n values, in order."""
    if not vals:
        return Array(zero() for _ in range(n))
    if len(vals) == 1:
        v = vals[0]
        return Array(copy(v) if isinstance(v, (Struct, Array)) else v for _ in range(n))
    return Array(vals)


def copy(v):
    """Struct or array `v`'s copy: an instance of its class (not its box's),
    each struct or array it holds copied in turn."""
    if isinstance(v, Array):
        return Array(copy(x) if isinstance(x, (Struct, Array)) else x for x in v)
    cls = v.__jac_struct__
    c = object.__new__(cls)
    for n in cls.__jac_names__:
        x = getattr(v, n)
        if isinstance(x, (Struct, Array)):
            x = copy(x)
        object.__setattr__(c, n, x)
    return c


def vcopy(v):
    """A generic class's value going where it is held (the compiler's
    CV_TCOPY): a struct's record copied, anything else itself."""
    return copy(v) if isinstance(v, Struct) else v


def box(v):
    """Struct `v` as an any holds it: a copy of its class's box, each struct
    it holds boxed in turn; an array a list of its elements, each boxed."""
    if isinstance(v, Array):
        return [box(x) if isinstance(x, (Struct, Array)) else x for x in v]
    cls = v.__jac_struct__
    c = object.__new__(cls.__jac_box__)
    for n in cls.__jac_names__:
        x = getattr(v, n)
        if isinstance(x, (Struct, Array)):
            x = box(x)
        object.__setattr__(c, n, x)
    return c


def items(xs):
    """A new list of structs `xs` made of another's elements (a slice, a
    concatenation, a copy), or a new dict of struct values made of another's
    (a copy, a merge): each a copy of its own."""
    if isinstance(xs, dict):
        return {k: copy(v) for k, v in xs.items()}
    return [copy(x) for x in xs]


def _dict_of(src):
    """dict(src) of a source the checker knows for no dict and for no
    iterable of pairs, an any or a mapping that is an object (the native
    runtime's _dict_of, rt/methods): Python's dict reads it."""
    return dict(src)


def each_copy(it):
    """What a loop over structs binds its target to: a copy of each."""
    return map(copy, it)


def _copy_parts(v, spec):
    return tuple(
        copy(x) if s is True else _copy_parts(x, s) if isinstance(s, tuple) else x
        for x, s in zip(v, spec)
    )


def each_copy_parts(it, spec):
    """What a loop unpacking each element into targets binds them to: each
    struct the `spec` marks (a tuple of bools, nested as the targets are) a
    copy."""
    return (_copy_parts(v, spec) for v in it)


def repeat_in(xs, n):
    """List of structs `xs` repeated `n` times in place (`xs *= n`), each
    repetition a copy."""
    xs[:] = [copy(x) for _ in range(n) for x in xs]
    return xs


def own_args(f):
    """Function `f`, given structs as the runtime's words (a key function's
    elements): each struct argument a copy of its own."""
    return lambda *a: f(*[copy(x) if isinstance(x, (Struct, Array)) else x for x in a])


def held(v):
    """`v`, read through an any: a struct or an array, a copy as an any
    holds it."""
    return box(v) if isinstance(v, (Struct, Array)) else v


def own(v, want=None):
    """`v`, a struct parameter's argument: a copy of its own when it came
    as an any holds one (a call through an any, Python's code); an array
    parameter's (of type `want`), the array that list is made of."""
    if isinstance(v, Struct):
        return copy(v) if type(v) is not v.__jac_struct__ else v
    if want is not None and type(v) is not Array:
        return convert(v, want)
    return v


def type_of(v):
    """type(v): a struct's class, though an any holds it as its box's."""
    t = type(v)
    return t.__jac_struct__ if isinstance(v, Struct) else t


def overwrite(place, v):
    """Struct `v`, a copy of its own, written over struct `place`, the caller's
    a `&mut` parameter is: field by field, so the caller's is changed."""
    for n in place.__jac_names__:
        object.__setattr__(place, n, getattr(v, n))


def restore(cls):
    """An instance of Jac class `cls` restored for decoding: no `init`
    or `postinit` runs, and the checker's code sets its fields."""
    return cls.__new__(cls)


def field_default(cls, name):
    """The default of `cls`'s field `name`, made as its constructor makes it:
    for a restored instance's field left unset."""
    for n, dflt, _ in _fields(cls):
        if n == name:
            return dflt()
    raise AttributeError(name)

def nsafe_attr(x, name):
    return None if x is None else getattr(x, name)


def nsafe_index(x, i):
    return None if x is None else x[i]


def nsafe_call(x, name, *args, **kw):
    return None if x is None else getattr(x, name)(*args, **kw)


class Cell:
    """A variable a closure captures that a loop binds: each iteration's its
    own, which the closures made in it share with the code around them, as
    native code's are (Gen.fresh_cells)."""

    __slots__ = ("v",)

    def __init__(self, *value):
        if value:
            self.v = value[0]


class Attrs:
    """An object's attributes by their own names, which CPython would mangle
    as an attribute in a class's code (two leading underscores)."""

    __slots__ = ("of",)

    def __init__(self, of):
        self.of = of

    def __getitem__(self, name):
        return getattr(self.of, name)

    def __setitem__(self, name, value):
        setattr(self.of, name, value)

    def __delitem__(self, name):
        delattr(self.of, name)


def unmangle(cls, names):
    """What class `cls`'s body bound by `names`, which CPython mangled, bound
    by them again."""
    prefix = "_" + cls.__name__.lstrip("_")
    for name in names:
        value = cls.__dict__[prefix + name]
        delattr(cls, prefix + name)
        if hasattr(value, "__name__"):
            value.__name__ = name
            value.__qualname__ = cls.__qualname__ + "." + name
        setattr(cls, name, value)


class Default:
    """A parameter's default, which each call that needs it evaluates:
    `make` computes it, in the scope the function was made in."""

    __slots__ = ("make",)

    def __init__(self, make):
        self.make = make


# -- conversions ----------------------------------------------------------------
#
# Where check typed a place and the value comes from an `any` (or a dynamic
# class's instance), it is converted as native code's rt_convert does: numbers
# widen, a value of another type raises TypeError, and an instance of a class
# with __jac_value__ becomes the value it stands for. `want` is a type, a
# class, (container, element types...), ("|", members...), or None: anything.

_CONVERSIONS = {int: "__jac_int__", float: "__jac_float__", str: "__jac_str__", bool: "__jac_bool__"}


def _name_list(names):
    quoted = [f"'{n}'" for n in names]
    if len(quoted) == 1:
        return quoted[0]
    return ", ".join(quoted[:-1]) + ("," if len(quoted) > 2 else "") + " and " + quoted[-1]


def rt_check_args(n, fixed, npos, ndflt, names, required, cap, fname):
    """A `*` spread's count checked against the callee's parameters, where check
    bound the call (a specialization's): `n` given, after `fixed` written ones,
    of `npos` positional parameters (`ndflt` defaulted) named `names`, the
    first `required` needing one; `cap` how many it may fill, -1 when *args
    takes the rest."""
    given = fixed + n
    if cap >= 0 and n > cap:
        takes = f"from {npos - ndflt} to {npos}" if ndflt else str(npos)
        plural = "" if npos == 1 and not ndflt else "s"
        verb = "was" if given == 1 else "were"
        raise TypeError(f"{fname}() takes {takes} positional argument{plural} but {given} {verb} given")
    missing = names[given:required]
    if missing:
        plural = "" if len(missing) == 1 else "s"
        raise TypeError(
            f"{fname}() missing {len(missing)} required positional argument{plural}: {_name_list(missing)}"
        )


def rt_check_kwargs(keys, accepted, taken, need_pos, need_kw, open_, fname):
    """A `**` spread's keys checked against the callee's parameters, as
    rt_check_args checks a `*` spread's count."""
    for k in keys:
        if k in taken:
            raise TypeError(f"{fname}() got multiple values for argument '{k}'")
        if not open_ and k not in accepted:
            raise TypeError(f"{fname}() got an unexpected keyword argument '{k}'")
    for need, kind in ((need_pos, "positional"), (need_kw, "keyword-only")):
        missing = [n for n in need if n not in keys]
        if missing:
            plural = "" if len(missing) == 1 else "s"
            raise TypeError(
                f"{fname}() missing {len(missing)} required {kind} argument{plural}: {_name_list(missing)}"
            )


def _type_name(want):
    if isinstance(want, tuple):
        if want[0] == "|":
            return " | ".join(_type_name(w) for w in want[1:])
        # (An array's is a list: what native code names it.)
        return "list" if want[0] is Array else want[0].__name__
    if isinstance(want, Sized):
        return "int"
    return "None" if want is type(None) else want.__name__


def _fits(v, want):
    """`v` as a `want` without a conversion of its own, or _MISS."""
    if want is None:
        return v
    if isinstance(want, tuple):
        head = want[0]
        if head == "|":
            for w in want[1:]:
                got = _fits(v, w)
                if got is not _MISS:
                    return got
            return _MISS
        if head is Array:
            # An array arriving from an any: a list of as many elements,
            # each converted to its element type, a copy of its own.
            if not isinstance(v, list):
                return _MISS
            if len(v) != want[1]:
                raise ValueError(f"expected {want[1]} items, found {len(v)}")
            return Array(_element(convert(x, want[2]), want[2]) for x in v)
        if not isinstance(v, head):
            return _MISS
        if head is dict:
            items = [(convert(k, want[1]), convert(x, want[2])) for k, x in v.items()]
            if all(a is k and b is x for (a, b), (k, x) in zip(items, v.items())):
                return v
            return dict(items)
        elems = want[1:]
        if head is tuple and not (len(elems) == 2 and elems[1] is ...):
            if len(v) != len(elems):
                return _MISS
            got = tuple(convert(x, w) for x, w in zip(v, elems))
        else:
            got = [convert(x, elems[0]) for x in v]
        if all(a is b for a, b in zip(got, v)):
            return v
        return head(got)
    if v is None:
        return v if want not in (int, float, bool) else _MISS
    if want is float:
        if isinstance(v, (int, float)):
            return float(v) if type(v) is not float else v
        return float(v) if hasattr(type(v), "__float__") and not isinstance(v, (str, bytes)) else _MISS
    if isinstance(want, Sized):
        want = int
    if want is int:
        if isinstance(v, int):
            return int(v) if type(v) is bool else v
        return v.__index__() if hasattr(type(v), "__index__") else _MISS
    if want is complex and type(v) is not complex and isinstance(v, (int, float)):
        # A real number where a complex is declared: itself, with no
        # imaginary part, as native code's rt_convert makes it.
        return complex(v)
    if want is bytes and type(v) is bytearray:
        # A bytearray where a builtin method takes bytes: its bytes, as
        # native code's rt_convert gives them.
        return bytes(v)
    return v if isinstance(v, want) else _MISS


_MISS = object()


def _element(x, want):
    """`x`, converted to an array's element type `want`: its own copy of a
    struct, a sized int in its type's range."""
    if isinstance(x, Struct):
        return copy(x)
    if isinstance(want, Sized):
        return fit(x, want.w, want.uns)
    return x


def convert(v, want):
    """`v` as a value of `want`, as native code converts it."""
    got = _fits(v, want)
    if got is not _MISS:
        return got
    cls = type(v)
    if hasattr(cls, "__jac_value__"):
        conv = _CONVERSIONS.get(want)
        if conv is not None and hasattr(cls, conv):
            return convert(getattr(v, conv)(), want)
        jv = v.__jac_value__()
        if jv is not v:
            return convert(jv, want)
    raise TypeError(f"expected {_type_name(want)}, found {cls.__name__ if v is not None else 'None'}")


# -- flow and wait --------------------------------------------------------------
#
# `flow e` computes e then and there, as native code does, keeping its value or
# what it raised; `wait t` gives the value, or raises what it raised.


# -- tasks -----------------------------------------------------------------------
#
# `flow e` makes a task and `wait t` gives its value, or raises what it raised.
# A task of a call (`flow f(a, b)`: flow_call) is given its callee and its
# arguments as they are where the flow is written, and the call runs on one of a
# pool of threads, as it does in native code (rt/_tasks.jac): at most MAX_TASKS
# of them, each ending after TASK_IDLE seconds with nothing to do; a task no
# thread has taken runs on the thread that waits for it; a task sees the context
# variables as they were at its flow, the caller among them; and the program
# ends once its tasks are done. Any other expression is evaluated where it is
# written (flow).

MAX_TASKS = 32
TASK_IDLE = 30.0

_TASK_QUEUED, _TASK_RUNNING, _TASK_DONE = 0, 1, 2


class Task:
    __slots__ = ("value", "error", "work", "state")

    def __init__(self, value, error, work=None):
        self.value = value
        self.error = error
        self.work = work
        self.state = _TASK_DONE if work is None else _TASK_QUEUED


_tasks_turn = threading.Lock()
_tasks_ready = threading.Condition(_tasks_turn)
_tasks_done = threading.Condition(_tasks_turn)
_tasks_queued = []
_tasks_threads = 0
_tasks_running = 0
_tasks_ending = False


def flow(compute):
    try:
        return Task(compute(), None)
    except BaseException as e:
        return Task(None, e)


def flow_call(fn, /, *args, **kwargs):
    global _tasks_threads, _tasks_ending
    context = contextvars.copy_context()
    task = Task(None, None, lambda: context.run(fn, *args, **kwargs))
    started = True
    with _tasks_turn:
        if not _tasks_ending:
            _tasks_ending = True
            threading._register_atexit(_tasks_finish)
        _tasks_queued.append(task)
        if len(_tasks_queued) + _tasks_running > _tasks_threads and _tasks_threads < MAX_TASKS:
            _tasks_threads += 1
            try:
                threading.Thread(target=_tasks_work, daemon=True).start()
            except RuntimeError:
                _tasks_threads -= 1
                started = _tasks_threads > 0
        else:
            _tasks_ready.notify()
    if not started:
        _task_settle(task)
    return task


def _task_run(task):
    work, task.work = task.work, None
    try:
        task.value = work()
    except BaseException as e:
        task.error = e
    with _tasks_turn:
        task.state = _TASK_DONE
        _tasks_done.notify_all()


def _task_settle(task):
    """Return when `task` is done: run here if no thread has taken it."""
    with _tasks_turn:
        mine = task.state == _TASK_QUEUED
        if mine:
            _tasks_queued.remove(task)
            task.state = _TASK_RUNNING
        else:
            while task.state != _TASK_DONE:
                _tasks_done.wait()
    if mine:
        _task_run(task)


def _tasks_work():
    global _tasks_threads, _tasks_running
    while True:
        with _tasks_turn:
            while not _tasks_queued:
                # (Woken for a task another thread took first, it waits on:
                # only one that waited the whole time ends.)
                if not _tasks_ready.wait(TASK_IDLE) and not _tasks_queued:
                    _tasks_threads -= 1
                    return
            task = _tasks_queued.pop(0)
            task.state = _TASK_RUNNING
            _tasks_running += 1
        _task_run(task)
        with _tasks_turn:
            _tasks_running -= 1
            _tasks_done.notify_all()


def _tasks_finish():
    """The program is ending: run the tasks no thread has taken, and wait for
    those that run."""
    while True:
        with _tasks_turn:
            while not _tasks_queued and _tasks_running > 0:
                _tasks_done.wait()
            if not _tasks_queued:
                return
            task = _tasks_queued.pop(0)
            task.state = _TASK_RUNNING
        _task_run(task)


def wait(task):
    if task.state != _TASK_DONE:
        _task_settle(task)
    if task.error is not None:
        raise task.error
    return task.value


# -- sized ints -----------------------------------------------------------------
#
# An int is Python's; a sized type (i8 ... u64) keeps its range as native code
# does: arithmetic leaving it raises OverflowError, `T.wrap(x)` wraps into it.


def fit(v, w, uns):
    """`v`, which a `w`-bit type (unsigned with `uns`) must hold."""
    if (v < 0 or v >> w) if uns else (v >> (w - 1)) not in (0, -1):
        raise OverflowError("integer overflow")
    return v


def wrap(v, w, uns):
    """`v` modulo the `w`-bit type's range."""
    v &= (1 << w) - 1
    return v - (1 << w) if not uns and v >> (w - 1) else v


def sat(v, w, uns):
    """`v` stopped at the `w`-bit type's least and greatest values."""
    lo, hi = (0, (1 << w) - 1) if uns else (-(1 << (w - 1)), (1 << (w - 1)) - 1)
    return lo if v < lo else hi if v > hi else v


def count(r, w):
    """A shift count for a `w`-bit type."""
    if r < 0 or r >= w:
        raise OverflowError("integer overflow")
    return r


# -- memory regions -------------------------------------------------------------
#
# A region is erased off native and wasm, after the checks have run: an
# open's block runs, and CPython's own memory management frees what it made, so
# nothing is ever made in a region.


class Ordered:
    """rt/core.jac's interface of what is ordered (`<`): what a class
    conforming to it lists among its bases. Checking conformance is the
    compiler's; nothing of it is left to run."""

    __slots__ = ()


class Number(Ordered):
    """rt/core.jac's interface of numbers, which are ordered."""

    __slots__ = ()


class Int(Number):
    """rt/core.jac's interface of int numbers."""

    __slots__ = ()


class Float(Number):
    """rt/core.jac's interface of float numbers."""

    __slots__ = ()


class Region:
    """A region handle (rt/core.jac's Region), which holds nothing here."""

    __slots__ = ()

    def partition(self, k=None):
        """A child region of this one, or with `k`, `k` of them as a tuple."""
        if k is None:
            return Region()
        return tuple(Region() for _ in range(k))


def region_of(item):
    """The region `item` was made in: none, as no region holds anything here."""
    return None


# -- the graph ------------------------------------------------------------------
#
# Nodes, edges and walkers as native code runs them (rt/impl/core.impl.jac's
# rt_spawn): a walk is a queue of what's visited and a stack of where it is, a
# node's exit abilities running after what it visited. Which abilities run where
# is what compiler/analysis/dispatch planned, as data py_gen gives each class: a walker's
# `__jac_plan__`, for entry and exit, is whether the node's abilities run first,
# its own abilities by the class id of the node (or edge) they run at, and its
# untyped ones, which run once as the walk starts and ends; a node's or an
# edge's `__jac_visits__`, for entry and exit, its abilities by the class id of
# the walker they run for. `__jac_id__` is a class's id. After each ability, a
# `skip` ends the node's (its flag cleared), a `disengage` the walk.


# A node's and an edge's id (jid), as native code's runtime makes it
# (rt_jid_new): this process's generation, 64 bits from the system's random
# source, and the id's number among those this process made, from 1, as 32
# hex digits. Allocated as the object is made, kept with it (its `_jac_jid`),
# and given back by a store to what it loads (rt_jid_restore).
_jid_generation = int.from_bytes(os.urandom(8), "little")
_jid_numbers = itertools.count(1)


def _made_with_jid(cls, *args, **kw):
    self = object.__new__(cls)
    self.__dict__["_jac_jid"] = f"{_jid_generation:016x}{next(_jid_numbers):016x}"
    return self


def _state_without_graph(self):
    """What copying a node or an edge takes of it: not its id, which the copy
    has its own of, nor a node's edges, which a copy starts without."""
    return {k: v for k, v in self.__dict__.items() if k not in ("_jac_jid", "_jac_out", "_jac_in")}


class Node(JacObj):
    # One thing in a graph: equal to itself alone, hashed by its identity.
    __eq__ = object.__eq__
    __hash__ = object.__hash__
    __jac_visits__ = ({}, {})
    __new__ = _made_with_jid
    __getstate__ = _state_without_graph


class Edge(JacObj):
    __eq__ = object.__eq__
    __hash__ = object.__hash__
    __jac_visits__ = ({}, {})
    __new__ = _made_with_jid
    __getstate__ = _state_without_graph
    # Its ends, which an edge that is not connected does not have.
    __src__ = None
    __dst__ = None


class GenericEdge(Edge):
    pass


class Walker(JacObj):
    __eq__ = object.__eq__
    __hash__ = object.__hash__
    __jac_plan__ = ((False, {}, ()), (True, {}, ()))

    @property
    def reports(self):
        """What its walks reported, every one of them. A walker that declares
        its reports (`has reports: list[T]`) holds them as a field of its
        own."""
        own = self.__dict__
        if "reports" in own:
            return own["reports"]
        state = _walk_state(self)
        return state.reports

    @reports.setter
    def reports(self, value):
        self.__dict__["reports"] = value


class Root(Node):
    @property
    def shared(self):
        """The one graph the space shares across callers (`root.shared`)."""
        return _shared[0]


class _Walk:
    """A walker's state, which native code keeps in its object's header: its
    flag (1 disengaged, 2 skipping the rest of a node), what's queued to visit
    and how far it got, and what it reported."""

    __slots__ = ("flag", "queue", "head", "reports")

    def __init__(self):
        self.flag = 0
        self.queue = []
        self.head = 0
        self.reports = []


def _walk_state(w):
    # (The walker's own, never through a __setattr__ or __getattr__ of its class.)
    state = w.__dict__.get("_jac_walk")
    if state is None:
        state = w.__dict__["_jac_walk"] = _Walk()
    return state


# Who a server's call is for (stdjac.graph): the root `root` means there,
# whether it is no one's (a call for no caller, which has the shared root and
# every caller's), and the caller's name, "" for no one.
class RtCaller:
    __slots__ = ("home", "rootless", "name")

    def __init__(self, home, rootless, name):
        self.home = home
        self.rootless = rootless
        self.name = name


# The program's root and the shared one; and the caller of the call being
# answered, None where none is: `root` is the program's own there. It is the
# call's context's, so calls a server answers at once each have their
# caller's, and a thread takes that of the thread that started it
# (_start_for_caller).
_current = [Root()]
_shared = [Root()]
_caller = contextvars.ContextVar("jac_caller", default=None)


def rt_caller_enter(home, rootless, name):
    _caller.set(RtCaller(home, rootless, name))


# A thread a call starts works for the call's caller, as natively (rt/core's
# rt_caller): it begins with the caller of the thread that started it. Only
# that is carried over: the thread's context is otherwise CPython's own, a
# new one.
_thread_start = threading.Thread.start


def _start_for_caller(self):
    who = _caller.get()
    if who is not None:
        run = self.run

        def run_for_caller():
            _caller.set(who)
            run()

        self.run = run_for_caller
    _thread_start(self)


threading.Thread.start = _start_for_caller


def rt_caller_name():
    who = _caller.get()
    return "" if who is None else who.name


# What `root` gives where it is read: an error where there is no caller.
def root():
    who = _caller.get()
    if who is None:
        return _current[0]
    if who.rootless:
        raise RuntimeError(
            "`root` is no one's here: this runs for no caller, which has `root.shared` and `allroots()`"
        )
    return who.home


# The root a walker starts at (`root spawn W()`), and `root.shared`'s: the
# shared one for no caller.
def start_root():
    who = _caller.get()
    return _current[0] if who is None else who.home


def rt_set_shared_root(r):
    _shared[0] = r


# The nodes in the graph by their identity, which stdjac names them by.
_live = weakref.WeakValueDictionary()


def _graph(n):
    if "_jac_out" not in n.__dict__:
        n.__dict__["_jac_out"] = []
        n.__dict__["_jac_in"] = []
        _live[id(n)] = n
    return n.__dict__["_jac_out"], n.__dict__["_jac_in"]


# What keeps the graph somewhere else (stdjac.graph) brings a node's edges
# from there before they are read or changed, as native code's runtime asks
# it to (rt_reach): the nodes whose edges are still where they are kept, by
# their identity, and what brings them.
_awaiting = {}
_keeper = [None]


def rt_reach_with(reach):
    _keeper[0] = reach


def rt_await_edges(n):
    _graph(n)
    _awaiting[id(n)] = n


def rt_edges_here(n):
    _awaiting.pop(id(n), None)


def rt_awaits_edges(n):
    return id(n) in _awaiting


def _reach(n):
    if _awaiting and id(n) in _awaiting and _keeper[0] is not None:
        _keeper[0](n)


def rt_edges_held(n, into):
    """Node `n`'s edges as they are here, out of it or into it: nothing is
    brought for them."""
    outs, ins = _graph(n)
    return list(ins if into else outs)


def rt_edges_order(n, into, edges):
    """Node `n`'s edges put in the order `edges` has them: the same edges."""
    held = _graph(n)[1 if into else 0]
    if len(held) == len(edges):
        held[:] = edges


def rt_drop_held_edge(e):
    """Edge `e` out of the graph as it is here, nothing brought for it."""
    _edges_out([e])


def rt_detach_node(ident):
    """Takes the node `ident` names out of the graph, with its edges."""
    n = _live.get(ident)
    if n is not None:
        _reach(n)
        outs, ins = _graph(n)
        remove_edges(list(outs) + list(ins))


def _nodes(x):
    return list(x) if isinstance(x, (list, tuple)) else [x]


def connect(left, right, make, op):
    """`left ++> right` (op "out"), `<++` ("in") or `<++>` ("any"): an edge
    each way it points, made by `make` (a GenericEdge without one)."""
    for a in _nodes(left):
        for b in _nodes(right):
            pairs = [(a, b)] if op == "out" else [(b, a)] if op == "in" else [(a, b), (b, a)]
            for src, dst in pairs:
                e = make() if make is not None else GenericEdge()
                if e.__src__ is not None:
                    # An edge the program holds, given to a second connect.
                    raise ValueError("an edge connects one pair of nodes, and this one is already connected")
                e.__dict__["__src__"] = src
                e.__dict__["__dst__"] = dst
                _graph(src)[0].append(e)
                _graph(dst)[1].append(e)
    return right


# An edge reference's direction, as check records it (EdgeOp.aux).
_OUT, _IN, _BOTH = 0, 1, 2


def refs(src, direction, kind, edges_only):
    """`[src -->]`: the nodes (or with `edges_only`, the edges) one step away
    in `direction`, along edges of class `kind` (any edge without one)."""
    out = []
    for n in _nodes(src):
        _reach(n)
        outs, ins = _graph(n)
        ahead = [e for e in outs if kind is None or isinstance(e, kind)] if direction != _IN else []
        back = [e for e in ins if kind is None or isinstance(e, kind)] if direction != _OUT else []
        if edges_only:
            # Each edge once: one from `n` to itself is among `ahead`.
            out += ahead + [e for e in back if direction == _IN or e.__src__ is not n]
            continue
        # Each node once, however many edges reach it.
        seen = {}
        for e in ahead:
            seen.setdefault(id(e.__dst__), e.__dst__)
        for e in back:
            seen.setdefault(id(e.__src__), e.__src__)
        out += list(seen.values())
    return out


def _without(edges, e):
    """`edges` without edge `e` itself (never another equal to it)."""
    return [x for x in edges if x is not e]


def remove_edges(edges):
    """Takes each of `edges` out of the graph. It has no ends again, as
    before it was connected (one that is not connected is in no node's
    lists)."""
    for e in edges:
        if e.__src__ is not None and id(e.__src__) in _awaiting and id(e.__dst__) in _awaiting:
            # Neither end has all its edges here: one brings its own, so that
            # what keeps the graph sees this one gone from where it was.
            _reach(e.__src__)
    _edges_out(edges)


def _edges_out(edges):
    for e in edges:
        if e.__src__ is None:
            continue
        outs = _graph(e.__src__)[0]
        outs[:] = _without(outs, e)
        ins = _graph(e.__dst__)[1]
        ins[:] = _without(ins, e)
        del e.__dict__["__src__"]
        del e.__dict__["__dst__"]


def _between(a, b, kind):
    """The edges from node `a` to node `b` itself of class `kind` (any
    without one)."""
    return [e for e in _graph(a)[0] if (kind is None or isinstance(e, kind)) and e.__dst__ is b]


def disconnect(left, right, direction, kind):
    """`left del --> right`: the edges between them of class `kind`, as the
    arrow points (`direction`), as rt_disconnect does."""
    for a in _nodes(left):
        for b in _nodes(right):
            if direction == _OUT or direction == _BOTH:
                _reach(a)
                remove_edges(_between(a, b, kind))
            if direction == _IN or direction == _BOTH:
                _reach(b)
                remove_edges(_between(b, a, kind))


def rt_jid_restore(x, text):
    """Node or edge `x`, made from a store's row, takes back the id `text`:
    False, and `x` as it was, when `text` is not one (as rt_jid writes it)."""
    if len(text) != 32 or any(c not in "0123456789abcdef" for c in text):
        return False
    x.__dict__["_jac_jid"] = text
    return True


def rt_edge_dst(e):
    """The node edge `e` leads to, as its arrow points."""
    return e.__dict__["__dst__"]


def jid(x):
    """A node's or an edge's id: only what a graph keeps has one (as native
    code's rt_jid_any refuses anything else)."""
    if isinstance(x, (Node, Edge)):
        return x.__dict__["_jac_jid"]
    raise TypeError(f"jid() takes a node or an edge, not '{type(x).__name__}'")


def _ran(w, state):
    """After an ability: whether the rest at this node is skipped (a `skip`,
    whose flag is cleared, so the walk goes on) or the walk disengaged."""
    if state.flag:
        if state.flag == 2:
            state.flag = 0
        return True
    return False


def _at(w, state, cur, phase):
    """Walker `w`'s and `cur`'s abilities, as `w` enters (phase 0) or leaves (1)
    `cur`, in the order planned."""
    nodes_first, mine, _ = type(w).__jac_plan__[phase]
    own = mine.get(type(cur).__jac_id__, ())
    theirs = type(cur).__jac_visits__[phase].get(type(w).__jac_id__, ())
    if nodes_first:
        for f in theirs:
            f(cur, w, cur)
            if _ran(w, state):
                return
    for f in own:
        f(w, cur)
        if _ran(w, state):
            return
    if not nodes_first:
        for f in theirs:
            f(cur, w, cur)
            if _ran(w, state):
                return


def _has_exit(w, cur):
    return bool(type(w).__jac_plan__[1][1].get(type(cur).__jac_id__)) or bool(
        type(cur).__jac_visits__[1].get(type(w).__jac_id__)
    )


def _whole(w, state, start, phase):
    for f in type(w).__jac_plan__[phase][2]:
        f(w, start)
        if _ran(w, state):
            return


def _dequeue(state):
    if state.head >= len(state.queue):
        return None
    n = state.queue[state.head]
    state.head += 1
    return n


def spawn(w, start):
    """Walker `w`'s walk from `start` (check put the walker first)."""
    state = _walk_state(w)
    state.flag = 0
    state.queue = [start]
    state.head = 0
    _whole(w, state, start, 0)
    stack = []
    while state.flag == 0:
        if not stack:
            nxt = _dequeue(state)
            if nxt is None:
                _whole(w, state, start, 1)
                break
            stack.append([nxt, 0])
            continue
        cur, phase = stack[-1]
        if phase == 0:
            _at(w, state, cur, 0)
            stack[-1][1] = 1
        elif phase == 1:
            nxt = _dequeue(state)
            if nxt is None:
                stack[-1][1] = 2
            elif _has_exit(w, cur):
                stack.append([nxt, 0])
            else:
                stack[-1] = [nxt, 0]
        else:
            _at(w, state, cur, 1)
            stack.pop()
    state.queue = []
    state.head = 0
    return w


def visit(w, items, at):
    """`visit` of the list `items`, at position `at` of what's left to visit
    (counted from its end when negative, -1 its back), as rt_visit_at does:
    whether there was anything to visit."""
    if len(items) == 0:
        return False
    state = _walk_state(w)
    left = len(state.queue) - state.head
    pos = at
    if pos < -left:
        pos = 0
    elif pos < 0:
        pos = pos + left + 1
    if pos > left:
        pos = left
    at = state.head + pos
    state.queue[at:at] = items
    return True


def visit_one(w, target, at):
    """`visit` of one node or edge, which may be None (nothing to visit)."""
    return visit(w, [target] if target is not None else [], at)


def report(w, value):
    _walk_state(w).reports.append(value)


def skip(w):
    _walk_state(w).flag = 2


def disengage(w):
    _walk_state(w).flag = 1


# -- a space's code objects -----------------------------------------------------
#
# Each Jac module of a space is a .jacpyc file (rt/cpython/jac_pyc.py's): the
# marshalled code object of its imports, its functions and its `__jac_init__`,
# which binds names and runs nothing, and one of each of its classes. The loader
# makes every module first, so a module's import of another binds it and runs
# nothing; then runs each module's code object; then makes the classes, each
# after its bases (native code has every class before any module's code runs);
# then runs each module's `__jac_init__` in the program's order.


def install(root, as_main):
    """Load and run the space at `root`, which @jac/space.json describes: its
    main module run as `__main__` with `as_main` (a program's), else by its
    name (a native app's, which serves it). Its main module."""
    with open(os.path.join(root, "@jac", "space.json"), encoding="utf-8") as f:
        info = json.load(f)
    for name, ident in info["ids"].items():
        globals()[name].__jac_id__ = ident
    modules = {}
    units = {}
    for name in info["modules"]:
        with open(os.path.join(root, name + ".jacpyc"), "rb") as f:
            units[name] = marshal.load(f)
        main = as_main and name == info["main"]
        mod = types.ModuleType("__main__" if main else name)
        mod.__file__ = units[name]["file"]
        modules[name] = sys.modules[name] = mod
        if main:
            sys.modules["__main__"] = mod
    for name in info["modules"]:
        # Its packages, each holding what's below it, as an import finds them.
        parts = name.split(".")
        for k in range(len(parts) - 1, 0, -1):
            pkg = ".".join(parts[:k])
            if pkg not in sys.modules:
                sys.modules[pkg] = types.ModuleType(pkg)
            if not hasattr(sys.modules[pkg], "__path__"):
                sys.modules[pkg].__path__ = []
            setattr(sys.modules[pkg], parts[k], sys.modules[".".join(parts[: k + 1])])
    for name in info["modules"]:
        exec(units[name]["module"], modules[name].__dict__)
    for name, cls in info["classes"]:
        exec(units[name]["classes"][cls], modules[name].__dict__)
    for name in info["init"]:
        init = modules[name].__dict__.pop("__jac_init__")
        init()
    return modules[info["main"]]
