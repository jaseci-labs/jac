#!/usr/bin/env python3
"""Phase 6 VM opcode fixture registry and coverage gate (INTEGRATION_PLAN.md).

Defines minimal Python sources that exercise each opcode in the band-2 compiler
emission set. The gate verifies:
  1. Every CPython-emittable opcode has a fixture whose disassembly contains it
     under the pinned CPython 3.14.6 interpreter (same bytecode oracle as proof B).
  2. layer_vm_conformance.jac tags every required opcode and its test sources
     match the FIXTURES registry and still disassemble with the claimed opcode.
  3. Compiler-only opcodes have native-codegen fixtures whose compile_source
     output actually contains the claimed opcode.

Run from repo root:
    python3 jac-py/tools/vm_opcode_fixtures.py --check
"""

from __future__ import annotations

import argparse
import codecs
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

# Policy pin: CURRENT.md / fetch_cpython_reference.py
CPYTHON_PIN = "3.14.6"
CPYTHON_MINOR = "3.14"


@dataclass(frozen=True)
class VmFixture:
    opcode: str
    source: str
    setup: str = ""
    mode: str = "exec"
    result_key: str = "result"


# Opcodes the native compiler may emit today (band 2).
EMISSION_OPCODES: tuple[str, ...] = (
    "RESUME",
    "RETURN_VALUE",
    "LOAD_CONST",
    "LOAD_SMALL_INT",
    "LOAD_NAME",
    "LOAD_LOCALS",
    "LOAD_GLOBAL",
    "BINARY_OP",
    "UNARY_NEGATIVE",
    "UNARY_INVERT",
    "UNARY_NOT",
    "PUSH_NULL",
    "CALL",
    "CALL_KW",
    "MAKE_FUNCTION",
    "LOAD_BUILD_CLASS",
    "MAKE_CELL",
    "COPY_FREE_VARS",
    "LOAD_DEREF",
    "STORE_DEREF",
    "BUILD_TUPLE",
    "SET_FUNCTION_ATTRIBUTE",
    "COMPARE_OP",
    "POP_TOP",
    "STORE_NAME",
    "STORE_ATTR",
    "STORE_SUBSCR",
    "LOAD_ATTR",
    "DELETE_NAME",
    "DELETE_FAST",
    "DELETE_ATTR",
    "DELETE_SUBSCR",
    "POP_JUMP_IF_FALSE",
    "NOT_TAKEN",
    "POP_JUMP_IF_TRUE",
    "POP_JUMP_IF_NOT_NONE",
    "IS_OP",
    "JUMP_FORWARD",
    "COPY",
    "SWAP",
    "TO_BOOL",
    "NOP",
    "POP_ITER",
    "BUILD_LIST",
    "BUILD_SET",
    "LIST_APPEND",
    "SET_ADD",
    "BUILD_MAP",
    "MAP_ADD",
    "DICT_UPDATE",
    "LOAD_FAST",
    "LOAD_FAST_CHECK",
    "LOAD_FAST_BORROW",
    "LOAD_FAST_BORROW_LOAD_FAST_BORROW",
    "STORE_FAST_STORE_FAST",
    "UNPACK_SEQUENCE",
    "LOAD_FAST_AND_CLEAR",
    "STORE_FAST",
    "STORE_FAST_LOAD_FAST",
    "RERAISE",
    "PUSH_EXC_INFO",
    "CHECK_EXC_MATCH",
    "POP_EXCEPT",
    "RAISE_VARARGS",
    "LOAD_SPECIAL",
    "WITH_EXCEPT_START",
    "LOAD_COMMON_CONSTANT",
    "IMPORT_NAME",
    "IMPORT_FROM",
    # Band 4 closures: cell/free var emission.
    "MAKE_CELL",
    "COPY_FREE_VARS",
    "LOAD_DEREF",
    "STORE_DEREF",
    "BUILD_TUPLE",
    "SET_FUNCTION_ATTRIBUTE",
    # Band 3: VM fixtures land before native codegen emits these opcodes.
    "GET_ITER",
    "FOR_ITER",
    "END_FOR",
    "JUMP_BACKWARD",
    "RETURN_GENERATOR",
    "YIELD_VALUE",
    "CALL_INTRINSIC_1",
    "GET_YIELD_FROM_ITER",
    "SEND",
    "END_SEND",
    "CLEANUP_THROW",
    "JUMP_BACKWARD_NO_INTERRUPT",
    "GET_AWAITABLE",
    "GET_AITER",
    "GET_ANEXT",
    "END_ASYNC_FOR",
    # Band 8: structural pattern matching opcodes.
    "GET_LEN",
    "MATCH_SEQUENCE",
    "MATCH_MAPPING",
    "MATCH_KEYS",
    "MATCH_CLASS",
    # Band 10 / star-call + f-string emissions (registry ahead of layer markers).
    "CALL_FUNCTION_EX",
    "UNPACK_EX",
    "LIST_EXTEND",
    "BUILD_STRING",
    "FORMAT_SIMPLE",
    "FORMAT_WITH_SPEC",
    "CONVERT_VALUE",
    # Already emitted by native codegen; keep registry in sync.
    "CONTAINS_OP",
    "SET_UPDATE",
    "STORE_GLOBAL",
    "DELETE_GLOBAL",
    "BINARY_SLICE",
    "STORE_SLICE",
    "BUILD_SLICE",
    "POP_JUMP_IF_NONE",
)

# CPython 3.14 may not emit JUMP_FORWARD in normal compilation; jacpython's
# codegen still emits it. VM coverage for that opcode uses native PyCode.
# LOAD_LOCALS is emitted for closure class bodies; Jac VM class-body execution
# is not yet host-parity for that bytecode shape.
# Slice / None-jump opcodes: CPython 3.14 folds many forms away; jacpython
# still emits the fused opcodes for non-constant bounds / `is not None` tests.
COMPILER_ONLY_OPCODES: frozenset[str] = frozenset(
    {
        "JUMP_FORWARD",
        "LOAD_LOCALS",
        "BINARY_SLICE",
        "STORE_SLICE",
        "BUILD_SLICE",
        "POP_JUMP_IF_NONE",
    }
)

# Minimal sources; disassembly (module + nested code) must contain the tagged opcode.
FIXTURES: tuple[VmFixture, ...] = (
    VmFixture("RESUME", "pass\nresult = 0\n"),
    VmFixture("RETURN_VALUE", "result = 1\n"),
    VmFixture("LOAD_CONST", "result = 1000\n"),
    VmFixture("LOAD_SMALL_INT", "result = 3\n"),
    VmFixture("LOAD_NAME", "result = x\n", setup="x = 9\n"),
    VmFixture(
        "LOAD_GLOBAL",
        "def f():\n    global x\n    return x\nresult = f()\n",
        setup="x = 9\n",
    ),
    VmFixture("BINARY_OP", "result = x + y\n", setup="x = 2\ny = 3\n"),
    VmFixture("UNARY_NEGATIVE", "result = -x\n", setup="x = 5\n"),
    VmFixture("UNARY_INVERT", "result = ~x\n", setup="x = 5\n"),
    VmFixture("UNARY_NOT", "result = not x\n", setup="x = 0\n"),
    VmFixture("PUSH_NULL", "result = len([1])\n"),
    VmFixture("CALL", "result = len([1, 2, 3])\n"),
    VmFixture(
        "CALL_KW",
        "result = f(1, b=2)\n",
        setup="def f(a, b=0):\n    return a + b\n",
    ),
    VmFixture("MAKE_FUNCTION", "def f():\n    return 1\nresult = f()\n"),
    VmFixture("LOAD_BUILD_CLASS", "class C:\n    pass\nresult = C.__name__\n"),
    VmFixture(
        "MAKE_CELL",
        "def outer(x):\n    def inner():\n        return x\n    return inner()\nresult = outer(42)\n",
    ),
    VmFixture(
        "COPY_FREE_VARS",
        "def outer(x):\n    def inner():\n        return x\n    return inner()\nresult = outer(42)\n",
    ),
    VmFixture(
        "LOAD_DEREF",
        "def outer(x):\n    def inner():\n        return x\n    return inner()\nresult = outer(42)\n",
    ),
    VmFixture(
        "STORE_DEREF",
        "def outer():\n    x = 1\n    def inner():\n        nonlocal x\n        x = 2\n    inner()\n    return x\nresult = outer()\n",
    ),
    VmFixture(
        "BUILD_TUPLE",
        "def outer(x):\n    def inner():\n        return x\n    return inner()\nresult = outer(42)\n",
    ),
    VmFixture(
        "SET_FUNCTION_ATTRIBUTE",
        "def outer(x):\n    def inner():\n        return x\n    return inner()\nresult = outer(42)\n",
    ),
    VmFixture("COMPARE_OP", "result = 1 < 2\n"),
    VmFixture("POP_TOP", "x\nresult = 0\n", setup="x = 1\n"),
    VmFixture("STORE_NAME", "x = 7\nresult = x\n"),
    VmFixture(
        "STORE_ATTR",
        "box.x = 11\nresult = box.x\n",
        setup="class Box:\n    pass\nbox = Box()\n",
    ),
    VmFixture(
        "STORE_SUBSCR",
        "seq[1] = 99\nresult = seq[1]\n",
        setup="seq = [10, 20, 30]\n",
    ),
    VmFixture(
        "LOAD_ATTR",
        "result = box.x\n",
        setup="class Box:\n    pass\nbox = Box()\nbox.x = 4\n",
    ),
    VmFixture("DELETE_NAME", "x = 1\ndel x\nresult = 0\n", setup="x = 0\n"),
    VmFixture(
        "DELETE_FAST",
        "def f():\n"
        "    try:\n"
        "        1 // 0\n"
        "    except ZeroDivisionError as e:\n"
        "        return str(e)\n"
        "result = f()\n",
    ),
    VmFixture(
        "DELETE_ATTR",
        "del box.x\nresult = 0\n",
        setup="class Box:\n    pass\nbox = Box()\nbox.x = 1\n",
    ),
    VmFixture(
        "DELETE_SUBSCR",
        "del seq[0]\nresult = len(seq)\n",
        setup="seq = [1, 2, 3]\n",
    ),
    VmFixture(
        "POP_JUMP_IF_FALSE",
        "if x:\n    result = 1\nelse:\n    result = 2\n",
        setup="x = 0\n",
    ),
    VmFixture(
        "NOT_TAKEN",
        "if x:\n    result = 1\nelse:\n    result = 2\n",
        setup="x = 0\n",
    ),
    VmFixture("POP_JUMP_IF_TRUE", "result = x or y\n", setup="x = 0\ny = 2\n"),
    VmFixture("COPY", "x = y = 42\nresult = x + y\n"),
    VmFixture(
        "SWAP",
        "result = (a < b < c)\n",
        setup="a = 1\nb = 2\nc = 3\n",
    ),
    VmFixture(
        "TO_BOOL",
        "if x:\n    result = 1\nelse:\n    result = 0\n",
        setup="x = 1\n",
    ),
    VmFixture(
        "GET_ITER",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
    ),
    VmFixture(
        "FOR_ITER",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
    ),
    VmFixture(
        "END_FOR",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
    ),
    VmFixture(
        "JUMP_BACKWARD",
        "i = 0\nwhile i < 3:\n    i += 1\nresult = i\n",
    ),
    VmFixture("NOP", "while x: break\nresult = 0\n", setup="x = 1\n"),
    VmFixture(
        "POP_ITER",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
    ),
    VmFixture(
        "BUILD_LIST",
        "result = [x for x in y]\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "BUILD_SET",
        "result = {x for x in y}\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "LIST_APPEND",
        "result = [x for x in y]\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "SET_ADD",
        "result = {x for x in y}\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "BUILD_MAP",
        "result = {x: x for x in y}\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "MAP_ADD",
        "result = {x: x for x in y}\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "DICT_UPDATE",
        "result = {**y, 'z': 9}\n",
        setup="y = {'a': 1}\n",
    ),
    VmFixture(
        "LOAD_FAST",
        "class AI:\n"
        "    def __aiter__(self):\n"
        "        return self\n"
        "    async def __anext__(self):\n"
        "        if getattr(self, 'done', False):\n"
        "            raise StopAsyncIteration\n"
        "        self.done = True\n"
        "        return 42\n"
        "async def f():\n"
        "    total = 0\n"
        "    async for x in AI():\n"
        "        total = total + x\n"
        "    return total\n"
        "c = f()\n"
        "result = 0\n"
        "try:\n"
        "    c.send(None)\n"
        "except StopIteration as e:\n"
        "    result = e.value\n",
    ),
    VmFixture(
        "LOAD_FAST_CHECK",
        "def f(x):\n"
        "    if x:\n"
        "        y = 1\n"
        "    return y\n"
        "result = f(1)\n",
    ),
    VmFixture(
        "LOAD_FAST_BORROW",
        "result = [x for x in y if x > 0]\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "LOAD_FAST_BORROW_LOAD_FAST_BORROW",
        "result = {k: v for k, v in pairs}\n",
        setup="pairs = [(1, 2), (3, 4)]\n",
    ),
    VmFixture(
        "STORE_FAST_STORE_FAST",
        "result = {k: v for k, v in pairs}\n",
        setup="pairs = [(1, 2), (3, 4)]\n",
    ),
    VmFixture(
        "UNPACK_SEQUENCE",
        "result = {k: v for k, v in pairs}\n",
        setup="pairs = [(1, 2), (3, 4)]\n",
    ),
    VmFixture(
        "LOAD_FAST_AND_CLEAR",
        "result = [x for x in y]\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "STORE_FAST",
        "result = [x for x in y]\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "STORE_FAST_LOAD_FAST",
        "result = [x for x in y]\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "RERAISE",
        "result = [x for x in y]\n",
        setup="y = [1, 2, 3]\n",
    ),
    VmFixture(
        "PUSH_EXC_INFO",
        "try:\n    1 // 0\nexcept ZeroDivisionError:\n    result = 99\n",
    ),
    VmFixture(
        "CHECK_EXC_MATCH",
        "try:\n    1 // 0\nexcept ZeroDivisionError:\n    result = 99\n",
    ),
    VmFixture(
        "POP_EXCEPT",
        "try:\n    1 // 0\nexcept ZeroDivisionError:\n    result = 99\n",
    ),
    VmFixture("RAISE_VARARGS", "raise ValueError('bad')\n"),
    VmFixture(
        "LOAD_SPECIAL",
        "class CM:\n"
        "    def __enter__(self):\n"
        "        return 42\n"
        "    def __exit__(self, *a):\n"
        "        pass\n"
        "with CM() as x:\n"
        "    result = x\n",
    ),
    VmFixture(
        "WITH_EXCEPT_START",
        "class CM:\n"
        "    def __enter__(self):\n"
        "        return 42\n"
        "    def __exit__(self, *a):\n"
        "        pass\n"
        "with CM() as x:\n"
        "    result = x\n",
    ),
    VmFixture("LOAD_COMMON_CONSTANT", "x = 0\nassert x == 1, 'fail'\nresult = x\n"),
    VmFixture("IMPORT_NAME", "import os\nresult = os.name\n"),
    VmFixture("IMPORT_FROM", "from os import path\nresult = path.sep\n"),
    VmFixture(
        "RETURN_GENERATOR",
        "def gen():\n"
        "    yield 1\n"
        "    yield 2\n"
        "g = gen()\n"
        "result = next(g) + next(g)\n",
    ),
    VmFixture(
        "YIELD_VALUE",
        "def gen():\n"
        "    yield 1\n"
        "    yield 2\n"
        "g = gen()\n"
        "result = next(g) + next(g)\n",
    ),
    VmFixture(
        "CALL_INTRINSIC_1",
        "def gen():\n"
        "    yield 1\n"
        "    yield 2\n"
        "g = gen()\n"
        "result = next(g) + next(g)\n",
    ),
    VmFixture(
        "GET_YIELD_FROM_ITER",
        "def outer():\n"
        "    yield from inner()\n"
        "def inner():\n"
        "    yield 1\n"
        "    yield 2\n"
        "result = list(outer())\n",
    ),
    VmFixture(
        "SEND",
        "def outer():\n"
        "    yield from inner()\n"
        "def inner():\n"
        "    yield 1\n"
        "    yield 2\n"
        "result = list(outer())\n",
    ),
    VmFixture(
        "END_SEND",
        "def outer():\n"
        "    yield from inner()\n"
        "def inner():\n"
        "    yield 1\n"
        "    yield 2\n"
        "result = list(outer())\n",
    ),
    VmFixture(
        "CLEANUP_THROW",
        "def outer():\n"
        "    yield from inner()\n"
        "def inner():\n"
        "    yield 1\n"
        "    yield 2\n"
        "result = list(outer())\n",
    ),
    VmFixture(
        "JUMP_BACKWARD_NO_INTERRUPT",
        "def outer():\n"
        "    yield from inner()\n"
        "def inner():\n"
        "    yield 1\n"
        "    yield 2\n"
        "result = list(outer())\n",
    ),
    VmFixture(
        "GET_AWAITABLE",
        "async def f():\n"
        "    return await g()\n"
        "async def g():\n"
        "    return 1\n"
        "c = f()\n"
        "result = 0\n"
        "try:\n"
        "    c.send(None)\n"
        "except StopIteration as e:\n"
        "    result = e.value\n",
    ),
    VmFixture(
        "GET_AITER",
        "class AI:\n"
        "    def __aiter__(self):\n"
        "        return self\n"
        "    async def __anext__(self):\n"
        "        if getattr(self, 'done', False):\n"
        "            raise StopAsyncIteration\n"
        "        self.done = True\n"
        "        return 42\n"
        "async def f():\n"
        "    total = 0\n"
        "    async for x in AI():\n"
        "        total = total + x\n"
        "    return total\n"
        "c = f()\n"
        "result = 0\n"
        "try:\n"
        "    c.send(None)\n"
        "except StopIteration as e:\n"
        "    result = e.value\n",
    ),
    VmFixture(
        "GET_ANEXT",
        "class AI:\n"
        "    def __aiter__(self):\n"
        "        return self\n"
        "    async def __anext__(self):\n"
        "        if getattr(self, 'done', False):\n"
        "            raise StopAsyncIteration\n"
        "        self.done = True\n"
        "        return 42\n"
        "async def f():\n"
        "    total = 0\n"
        "    async for x in AI():\n"
        "        total = total + x\n"
        "    return total\n"
        "c = f()\n"
        "result = 0\n"
        "try:\n"
        "    c.send(None)\n"
        "except StopIteration as e:\n"
        "    result = e.value\n",
    ),
    VmFixture(
        "END_ASYNC_FOR",
        "class AI:\n"
        "    def __aiter__(self):\n"
        "        return self\n"
        "    async def __anext__(self):\n"
        "        if getattr(self, 'done', False):\n"
        "            raise StopAsyncIteration\n"
        "        self.done = True\n"
        "        return 42\n"
        "async def f():\n"
        "    total = 0\n"
        "    async for x in AI():\n"
        "        total = total + x\n"
        "    return total\n"
        "c = f()\n"
        "result = 0\n"
        "try:\n"
        "    c.send(None)\n"
        "except StopIteration as e:\n"
        "    result = e.value\n",
    ),
    VmFixture(
        "MATCH_SEQUENCE",
        "x = [1, 2]\nmatch x:\n    case [a, b]:\n        result = a + b\n    case _:\n        result = 0\n",
    ),
    VmFixture(
        "GET_LEN",
        "x = [1, 2]\nmatch x:\n    case [a, b]:\n        result = a + b\n    case _:\n        result = 0\n",
    ),
    VmFixture(
        "MATCH_MAPPING",
        "x = {'a': 1, 'b': 2}\nmatch x:\n    case {'a': av, 'b': bv}:\n        result = av + bv\n    case _:\n        result = 0\n",
    ),
    VmFixture(
        "MATCH_KEYS",
        "x = {'a': 1, 'b': 2}\nmatch x:\n    case {'a': av, 'b': bv}:\n        result = av + bv\n    case _:\n        result = 0\n",
    ),
    VmFixture(
        "MATCH_CLASS",
        "class Point:\n    __match_args__ = ('x', 'y')\n    def __init__(self, x, y):\n        self.x = x\n        self.y = y\np = Point(1, 2)\nmatch p:\n    case Point(x, y):\n        result = x + y\n    case _:\n        result = 0\n",
    ),
    VmFixture(
        "POP_JUMP_IF_NOT_NONE",
        "def f(x):\n    match x:\n        case None:\n            return 0\n        case _:\n            return 1\nresult = f(1)\n",
    ),
    VmFixture(
        "IS_OP",
        "def f(x):\n    match x:\n        case True:\n            return 1\n        case _:\n            return 0\nresult = f(True)\n",
    ),
    VmFixture(
        "CALL_FUNCTION_EX",
        "def f(*a, **k):\n"
        "    return (a, k)\n"
        "def g(t, d):\n"
        "    return f(*t, **d)\n"
        "result = g((1,), {'x': 2})\n",
    ),
    VmFixture(
        "UNPACK_EX",
        "a, *b, c = [1, 2, 3, 4]\nresult = a + c + len(b)\n",
    ),
    VmFixture(
        "LIST_EXTEND",
        "a, *b, c = [1, 2, 3, 4]\nresult = a + c + len(b)\n",
    ),
    VmFixture(
        "BUILD_STRING",
        "x = 1\ny = 2\nresult = f'{x}-{y}'\n",
    ),
    VmFixture(
        "FORMAT_SIMPLE",
        "x = 1\nresult = f'x={x}'\n",
    ),
    VmFixture(
        "FORMAT_WITH_SPEC",
        "x = 1.5\nresult = f'{x:.2f}'\n",
    ),
    VmFixture(
        "CONVERT_VALUE",
        "x = 'a'\nresult = f'{x!r}'\n",
    ),
    VmFixture(
        "CONTAINS_OP",
        "result = 2 in seq\n",
        setup="seq = [1, 2, 3]\n",
    ),
    VmFixture(
        "SET_UPDATE",
        "result = {1, 2, *s}\n",
        setup="s = {3, 4}\n",
    ),
    VmFixture(
        "STORE_GLOBAL",
        "def f():\n    global x\n    x = 7\n    return x\nresult = f()\n",
        setup="x = 0\n",
    ),
    VmFixture(
        "DELETE_GLOBAL",
        "def f():\n    global x\n    x = 1\n    del x\n    return 0\nresult = f()\n",
        setup="x = 0\n",
    ),
)

# Native-codegen fixtures (not expected in CPython disassembly).
COMPILER_FIXTURES: tuple[VmFixture, ...] = (
    # JUMP_FORWARD is emitted only when a chained comparison assign is followed
    # by more module code (visit_stmt more_code_follows).
    VmFixture("JUMP_FORWARD", "a = x < y < z\nresult = 0\n"),
    VmFixture(
        "LOAD_LOCALS",
        "class C:\n    def m(self):\n        return 1\n\nresult = C().m()\n",
    ),
    VmFixture(
        "BINARY_SLICE",
        "a = 1\nb = 3\nseq = [1, 2, 3, 4]\nresult = seq[a:b]\n",
    ),
    VmFixture(
        "STORE_SLICE",
        "a = 1\nb = 3\nseq = [1, 2, 3, 4]\nseq[a:b] = [8, 9]\nresult = seq\n",
    ),
    VmFixture(
        "BUILD_SLICE",
        "a = 1\nb = 3\nc = 1\nseq = [1, 2, 3, 4]\nresult = seq[a:b:c]\n",
    ),
    VmFixture(
        "POP_JUMP_IF_NONE",
        "def f(x):\n"
        "    if x is not None:\n"
        "        return 1\n"
        "    return 0\n"
        "result = f(1)\n",
    ),
)

FIXTURE_BY_OPCODE = {fixture.opcode: fixture for fixture in FIXTURES}
COMPILER_FIXTURE_BY_OPCODE = {
    fixture.opcode: fixture for fixture in COMPILER_FIXTURES
}

MARKER_RE = re.compile(r"^\s*#\s*vm-opcode:\s*(OP_[A-Z0-9_]+)\s*$", re.MULTILINE)
COMPILER_MARKER_RE = re.compile(
    r"^\s*#\s*vm-opcode-compiler:\s*(OP_[A-Z0-9_]+)\s*$", re.MULTILINE
)
TAGGED_TEST_RE = re.compile(
    r"^\s*#\s*vm-opcode(-compiler)?:\s*(OP_[A-Z0-9_]+)\s*$", re.MULTILINE
)
EMIT_RE = re.compile(r"\b(OP_[A-Z][A-Z0-9_]*)\b")
ASSIGN_RE = re.compile(
    r'^\s*(setup|body)\s*=\s*"((?:[^"\\]|\\.)*)"\s*;?\s*$', re.MULTILINE
)

_DIS_HELPER = r"""
import dis
import json
import sys
import types

payload = json.loads(sys.stdin.read())
source = payload["source"]
mode = payload["mode"]
setup = payload.get("setup", "")
ns = {"__builtins__": __builtins__}
if setup:
    exec(compile(setup, "<vm-fixture-setup>", "exec"), ns)
co = compile(source, "<vm-fixture>", mode)


def opcode_names(code: types.CodeType) -> set[str]:
    names = {instr.opname for instr in dis.get_instructions(code)}
    for const in code.co_consts:
        if isinstance(const, types.CodeType):
            names |= opcode_names(const)
    return names


print(json.dumps(sorted(opcode_names(co))))
"""


def _repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    return Path(out.stdout.strip())


def _python_version(python: Path) -> str:
    proc = subprocess.run(
        [
            str(python),
            "-c",
            "import sys; print('%d.%d.%d' % sys.version_info[:3])",
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout.strip()


def resolve_pinned_cpython(root: Path) -> Path:
    """Return the CPython 3.14.6 interpreter used by proof leg B."""
    env_override = os.environ.get("JACPYTHON_CPYTHON")
    if env_override:
        candidate = Path(env_override)
        if candidate.is_file() and _python_version(candidate) == CPYTHON_PIN:
            return candidate
        raise RuntimeError(
            f"JACPYTHON_CPYTHON={env_override!r} is not CPython {CPYTHON_PIN}"
        )
    candidates: list[Path] = [
        root / "jac" / ".pbs-build" / "install" / "bin" / f"python{CPYTHON_MINOR}",
        root / ".venv" / "bin" / f"python{CPYTHON_MINOR}",
    ]
    which = shutil.which(f"python{CPYTHON_MINOR}")
    if which:
        candidates.append(Path(which))
    which_py3 = shutil.which("python3")
    if which_py3:
        candidates.append(Path(which_py3))
    seen: set[Path] = set()
    for candidate in candidates:
        if candidate in seen or not candidate.is_file():
            continue
        seen.add(candidate)
        if _python_version(candidate) == CPYTHON_PIN:
            return candidate
    raise RuntimeError(
        f"pinned CPython {CPYTHON_PIN} not found "
        f"(need python{CPYTHON_MINOR} on PATH or jac/.pbs-build install tree)"
    )


def resolve_jac(root: Path) -> Path | None:
    candidates: list[Path] = []
    which = shutil.which("jac")
    if which:
        candidates.append(Path(which))
    candidates.extend(
        [
            root / ".venv" / "bin" / "jac",
            root / "jac" / "zig-out" / "bin" / "jac",
        ]
    )
    seen: set[Path] = set()
    for candidate in candidates:
        if candidate in seen:
            continue
        seen.add(candidate)
        if candidate.is_file():
            return candidate
    return None


def _unescape_jac_string(raw: str) -> str:
    return codecs.decode(raw, "unicode_escape")


def _jac_string_literals(segment: str) -> list[str]:
    literals: list[str] = []
    idx = 0
    while idx < len(segment):
        if segment[idx] != '"':
            idx += 1
            continue
        idx += 1
        chars: list[str] = []
        while idx < len(segment):
            ch = segment[idx]
            if ch == "\\":
                if idx + 1 < len(segment):
                    chars.append(ch)
                    chars.append(segment[idx + 1])
                    idx += 2
                    continue
            if ch == '"':
                idx += 1
                break
            chars.append(ch)
            idx += 1
        literals.append(_unescape_jac_string("".join(chars)))
    return literals


def _assert_call_args(block: str) -> str | None:
    match = re.search(r"assert_vm_value_matches_host\s*\(", block)
    if not match:
        return None
    start = match.end()
    depth = 1
    idx = start
    while idx < len(block) and depth > 0:
        ch = block[idx]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        idx += 1
    if depth != 0:
        return None
    return block[start : idx - 1]


def _dis_opcode_names(
    python: Path, source: str, mode: str, setup: str = ""
) -> set[str]:
    payload = json.dumps({"source": source, "mode": mode, "setup": setup})
    proc = subprocess.run(
        [str(python), "-c", _DIS_HELPER],
        input=payload,
        capture_output=True,
        text=True,
        check=True,
    )
    return set(json.loads(proc.stdout))


def _parse_codegen_emission_opcodes(path: Path) -> set[str]:
    text = path.read_text()
    emitted: set[str] = set()
    for match in re.finditer(r"emit_(?:op|jump)\(\s*(OP_[A-Z0-9_]+)", text):
        emitted.add(match.group(1).removeprefix("OP_"))
    return emitted


def _iter_tagged_test_blocks(text: str):
    for match in TAGGED_TEST_RE.finditer(text):
        compiler_only = match.group(1) is not None
        opcode = match.group(2).removeprefix("OP_")
        start = match.end()
        brace = text.find("{", start)
        if brace < 0:
            yield opcode, compiler_only, ""
            continue
        depth = 0
        end = brace
        for idx in range(brace, len(text)):
            ch = text[idx]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = idx + 1
                    break
        yield opcode, compiler_only, text[brace:end]


def _extract_layer_sources(block: str) -> tuple[str, str, str]:
    assigns = {
        key: _unescape_jac_string(raw)
        for key, raw in ASSIGN_RE.findall(block)
    }
    args = _assert_call_args(block)
    if args is not None:
        compact_args = re.sub(r"\s+", " ", args)
        if re.match(r"setup\s*,\s*body\s*,", compact_args):
            mode_match = re.search(
                r'setup\s*,\s*body\s*,\s*"((?:[^"\\]|\\.)*)"',
                compact_args,
            )
            mode = (
                _unescape_jac_string(mode_match.group(1))
                if mode_match
                else "exec"
            )
            return assigns.get("setup", ""), assigns.get("body", ""), mode
        literals = _jac_string_literals(args)
        if len(literals) >= 3:
            setup = assigns.get("setup", literals[0])
            body = assigns.get("body", literals[1])
            mode = literals[2]
            return setup, body, mode
    if "body" in assigns:
        return assigns.get("setup", ""), assigns["body"], "exec"
    raise ValueError("could not extract setup/body from tagged test block")


def _render_compiler_probe(opcode: str, body: str) -> str:
    body_json = json.dumps(body)
    return f"""\
import from product_compile {{ compile_source }}
import from opcode_meta {{ OP_{opcode} }}
import from objects {{ PyCode, is_error }}

def code_has_opcode(co: PyCode, target: int) -> bool {{
    code = co.co_code;
    i = 0;
    while i < len(code) {{
        if code[i] == target {{
            return True;
        }}
        i = i + 1;
    }}
    for const in co.consts {{
        if isinstance(const, PyCode) {{
            if code_has_opcode(const as PyCode, target) {{
                return True;
            }}
        }}
    }}
    return False;
}}

with entry {{
    co = compile_source({body_json}, "<vm-compiler-fixture>", "exec", 0);
    assert not is_error(co);
    assert code_has_opcode(co as PyCode, OP_{opcode});
}}
"""


def _native_codegen_has_opcode(
    jac: Path, root: Path, opcode: str, body: str
) -> str | None:
    probe_dir = root / "jac-py" / "jacpython"
    script = _render_compiler_probe(opcode, body)
    probe_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".jac",
            dir=probe_dir,
            delete=False,
        ) as handle:
            handle.write(script)
            probe_path = Path(handle.name)
        proc = subprocess.run(
            [str(jac), "run", str(probe_path)],
            cwd=root,
            capture_output=True,
            text=True,
        )
    finally:
        if probe_path is not None:
            probe_path.unlink(missing_ok=True)
    if proc.returncode == 0:
        return None
    detail = proc.stderr.strip() or proc.stdout.strip() or "jac run failed"
    return detail


def check_fixtures(python: Path) -> list[str]:
    errors: list[str] = []
    cpython_ops = set(EMISSION_OPCODES) - COMPILER_ONLY_OPCODES
    tagged = {fixture.opcode for fixture in FIXTURES}
    missing_fixtures = cpython_ops - tagged
    if missing_fixtures:
        errors.append(
            "fixture table missing CPython opcodes: "
            + ", ".join(sorted(missing_fixtures))
        )
    extra_fixtures = tagged - set(EMISSION_OPCODES)
    if extra_fixtures:
        errors.append(
            "fixture table has untracked opcodes: "
            + ", ".join(sorted(extra_fixtures))
        )
    for fixture in FIXTURES:
        names = _dis_opcode_names(
            python, fixture.source, fixture.mode, fixture.setup
        )
        if fixture.opcode not in names:
            errors.append(
                f"{fixture.opcode}: CPython {CPYTHON_PIN} disassembly lacks opcode "
                f"(got {sorted(names)!r}) for {fixture.source!r}"
            )
    return errors


def check_layer_markers(
    layer_path: Path, python: Path, jac: Path | None, root: Path
) -> list[str]:
    errors: list[str] = []
    text = layer_path.read_text()
    marked = {match.removeprefix("OP_") for match in MARKER_RE.findall(text)}
    compiler_marked = {
        match.removeprefix("OP_") for match in COMPILER_MARKER_RE.findall(text)
    }
    cpython_ops = set(EMISSION_OPCODES) - COMPILER_ONLY_OPCODES
    missing = cpython_ops - marked
    if missing:
        errors.append(
            f"{layer_path.name} missing vm-opcode markers: "
            + ", ".join(f"OP_{op}" for op in sorted(missing))
        )
    missing_compiler = COMPILER_ONLY_OPCODES - compiler_marked
    if missing_compiler:
        errors.append(
            f"{layer_path.name} missing vm-opcode-compiler markers: "
            + ", ".join(f"OP_{op}" for op in sorted(missing_compiler))
        )

    seen_cpython: set[str] = set()
    seen_compiler: set[str] = set()
    for opcode, compiler_only, block in _iter_tagged_test_blocks(text):
        if not block:
            errors.append(f"{layer_path.name} OP_{opcode}: missing test block body")
            continue
        try:
            setup, body, mode = _extract_layer_sources(block)
        except ValueError:
            errors.append(
                f"{layer_path.name} OP_{opcode}: could not parse setup/body sources"
            )
            continue

        if compiler_only:
            seen_compiler.add(opcode)
            expected = COMPILER_FIXTURE_BY_OPCODE.get(opcode)
            if expected is None:
                errors.append(
                    f"{layer_path.name} OP_{opcode}: untracked compiler-only opcode"
                )
                continue
            if setup != expected.setup or body != expected.source:
                errors.append(
                    f"{layer_path.name} OP_{opcode}: layer sources drifted from "
                    f"COMPILER_FIXTURES (setup/body mismatch)"
                )
            if jac is None:
                errors.append(
                    f"{layer_path.name} OP_{opcode}: jac binary required to verify "
                    "native codegen opcode emission"
                )
                continue
            detail = _native_codegen_has_opcode(jac, root, opcode, body)
            if detail is not None:
                errors.append(
                    f"{layer_path.name} OP_{opcode}: native compile_source lacks "
                    f"{opcode} ({detail})"
                )
            continue

        seen_cpython.add(opcode)
        expected = FIXTURE_BY_OPCODE.get(opcode)
        if expected is None:
            errors.append(f"{layer_path.name} OP_{opcode}: untracked CPython opcode")
            continue
        if (
            setup != expected.setup
            or body != expected.source
            or mode != expected.mode
        ):
            errors.append(
                f"{layer_path.name} OP_{opcode}: layer sources drifted from FIXTURES "
                "(setup/body/mode mismatch)"
            )
        names = _dis_opcode_names(python, body, mode, setup)
        if opcode not in names:
            errors.append(
                f"{layer_path.name} OP_{opcode}: CPython {CPYTHON_PIN} disassembly "
                f"lacks opcode (got {sorted(names)!r})"
            )

    extra_marked = marked - seen_cpython
    if extra_marked:
        errors.append(
            f"{layer_path.name} vm-opcode markers without parsed tests: "
            + ", ".join(f"OP_{op}" for op in sorted(extra_marked))
        )
    extra_compiler = compiler_marked - seen_compiler
    if extra_compiler:
        errors.append(
            f"{layer_path.name} vm-opcode-compiler markers without parsed tests: "
            + ", ".join(f"OP_{op}" for op in sorted(extra_compiler))
        )
    return errors


def check_codegen_sync(codegen_path: Path) -> list[str]:
    errors: list[str] = []
    emitted = _parse_codegen_emission_opcodes(codegen_path)
    missing = emitted - set(EMISSION_OPCODES)
    if missing:
        errors.append(
            "EMISSION_OPCODES missing codegen opcodes: "
            + ", ".join(sorted(missing))
        )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify fixture registry, layer sync, and opcode coverage",
    )
    parser.parse_args()

    root = _repo_root()
    layer = root / "jac-py" / "jacpython" / "layer_vm_conformance.jac"
    codegen = root / "jac-py" / "jacpython" / "compiler_codegen.jac"
    errors: list[str] = []
    try:
        python = resolve_pinned_cpython(root)
    except RuntimeError as exc:
        errors.append(str(exc))
        python = None
    jac = resolve_jac(root)
    if python is not None:
        errors.extend(check_fixtures(python))
    if layer.is_file():
        if python is not None:
            errors.extend(check_layer_markers(layer, python, jac, root))
        else:
            errors.append(
                f"cannot verify {layer.name} without pinned CPython {CPYTHON_PIN}"
            )
    else:
        errors.append(f"missing layer file: {layer}")
    if codegen.is_file():
        errors.extend(check_codegen_sync(codegen))
    if errors:
        for err in errors:
            print(f"FAIL: {err}")
        return 1
    print(
        f"PASS: VM opcode fixtures cover {len(EMISSION_OPCODES)} emission opcodes "
        f"({len(FIXTURES)} CPython fixtures, "
        f"{len(COMPILER_ONLY_OPCODES)} compiler-only) "
        f"via CPython {CPYTHON_PIN}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
