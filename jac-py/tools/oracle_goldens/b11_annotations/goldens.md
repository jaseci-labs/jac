# Band 11 annotated assignment / type alias CPython oracle goldens

Interpreter: `CPython 3.14.7` (3.14.7 (main, Aug 10 2026, 07:46:56) [GCC 16.1.1 20260728])

All byte strings below are from host `compile(source, '<b11-annotations>', 'exec')`; the root module code object is listed first, then nested code objects are walked recursively through `co_consts`. Unlike the Band 6/7 streams, the root module scope is included because PEP 649 puts the annotation bytes there.

## Flag constants

| Name | Decimal | Hex |
|---|---:|---:|
| `CO_GENERATOR` | 32 | `0x20` |
| `CO_COROUTINE` | 128 | `0x80` |
| `CO_ITERABLE_COROUTINE` | 256 | `0x100` |
| `CO_ASYNC_GENERATOR` | 512 | `0x200` |
| `CO_OPTIMIZED` | 1 | `0x1` |
| `CO_NEWLOCALS` | 2 | `0x2` |
| `CO_VARARGS` | 4 | `0x4` |
| `CO_VARKEYWORDS` | 8 | `0x8` |
| `CO_NESTED` | 16 | `0x10` |
| `CO_NOFREE` | 64 | `0x40` |
| `CO_HAS_DOCSTRING` | 67108864 | `0x4000000` |

## Fixtures

## module_annotated_with_value

### Source

```python
x: int = 5
```

### `module` (`<module>`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `2`
- `co_code.hex()`: `61008000520117007402300074005e0574015d005e006b011f0052022300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `['__conditional_annotations__']`
- `co_freevars`: `[]`
- `co_consts`: `['5', '<code object __annotate__>', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  MAKE_CELL                       0  __conditional_annotations__ [argval='__conditional_annotations__']
     2  RESUME                          0   [argval=0]
     4  LOAD_CONST                      1  <code object __annotate__ at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object __annotate__>]
     6  MAKE_FUNCTION                 None   [argval=None]
     8  STORE_NAME                      2  __annotate__ [argval='__annotate__']
    10  BUILD_SET                       0   [argval=0]
    12  STORE_NAME                      0  __conditional_annotations__ [argval='__conditional_annotations__']
    14  LOAD_SMALL_INT                  5   [argval=5]
    16  STORE_NAME                      1  x [argval='x']
    18  LOAD_NAME                       0  __conditional_annotations__ [argval='__conditional_annotations__']
    20  LOAD_SMALL_INT                  0   [argval=0]
    22  SET_ADD                         1   [argval=1]
    24  POP_TOP                       None   [argval=None]
    26  LOAD_CONST                      2  None [argval=None]
    28  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[1]<__annotate__>` (`__annotate__`)

- `co_flags`: `0x3` (3)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: (none)
- `co_stacksize`: `4`
- `co_code.hex()`: `800056005e0238840000640300001c00510168012f005e005c00000000000000000039000000640a00001c005c0200000000000000003b025201260000002300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `['format']`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['2', "'x'"]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_FAST_BORROW                0  format [argval='format']
     4  LOAD_SMALL_INT                  2   [argval=2]
     6  COMPARE_OP                    132  > [argval='>']
    10  POP_JUMP_IF_FALSE               3  to L1 [argval=20]
    14  NOT_TAKEN                     None   [argval=None]
    16  LOAD_COMMON_CONSTANT            1  NotImplementedError [argval=1]
    18  RAISE_VARARGS                   1   [argval=1]
    20  BUILD_MAP                       0   [argval=0]
    22  LOAD_SMALL_INT                  0   [argval=0]
    24  LOAD_GLOBAL                     0  __conditional_annotations__ [argval='__conditional_annotations__']
    34  CONTAINS_OP                     0  in [argval=0]
    38  POP_JUMP_IF_FALSE              10  to L2 [argval=62]
    42  NOT_TAKEN                     None   [argval=None]
    44  LOAD_GLOBAL                     2  int [argval='int']
    54  COPY                            2   [argval=2]
    56  LOAD_CONST                      1  'x' [argval='x']
    58  STORE_SUBSCR                  None   [argval=None]
    62  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

## module_bare_annotation

### Source

```python
x: list
```

### `module` (`<module>`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `2`
- `co_code.hex()`: `61008000520117007401300074005d005e006b011f0052022300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `['__conditional_annotations__']`
- `co_freevars`: `[]`
- `co_consts`: `['0', '<code object __annotate__>', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  MAKE_CELL                       0  __conditional_annotations__ [argval='__conditional_annotations__']
     2  RESUME                          0   [argval=0]
     4  LOAD_CONST                      1  <code object __annotate__ at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object __annotate__>]
     6  MAKE_FUNCTION                 None   [argval=None]
     8  STORE_NAME                      1  __annotate__ [argval='__annotate__']
    10  BUILD_SET                       0   [argval=0]
    12  STORE_NAME                      0  __conditional_annotations__ [argval='__conditional_annotations__']
    14  LOAD_NAME                       0  __conditional_annotations__ [argval='__conditional_annotations__']
    16  LOAD_SMALL_INT                  0   [argval=0]
    18  SET_ADD                         1   [argval=1]
    20  POP_TOP                       None   [argval=None]
    22  LOAD_CONST                      2  None [argval=None]
    24  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[1]<__annotate__>` (`__annotate__`)

- `co_flags`: `0x3` (3)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: (none)
- `co_stacksize`: `4`
- `co_code.hex()`: `800056005e0238840000640300001c00510168012f005e005c00000000000000000039000000640a00001c005c0200000000000000003b025201260000002300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `['format']`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['2', "'x'"]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_FAST_BORROW                0  format [argval='format']
     4  LOAD_SMALL_INT                  2   [argval=2]
     6  COMPARE_OP                    132  > [argval='>']
    10  POP_JUMP_IF_FALSE               3  to L1 [argval=20]
    14  NOT_TAKEN                     None   [argval=None]
    16  LOAD_COMMON_CONSTANT            1  NotImplementedError [argval=1]
    18  RAISE_VARARGS                   1   [argval=1]
    20  BUILD_MAP                       0   [argval=0]
    22  LOAD_SMALL_INT                  0   [argval=0]
    24  LOAD_GLOBAL                     0  __conditional_annotations__ [argval='__conditional_annotations__']
    34  CONTAINS_OP                     0  in [argval=0]
    38  POP_JUMP_IF_FALSE              10  to L2 [argval=62]
    42  NOT_TAKEN                     None   [argval=None]
    44  LOAD_GLOBAL                     2  list [argval='list']
    54  COPY                            2   [argval=2]
    56  LOAD_CONST                      1  'x' [argval='x']
    58  STORE_SUBSCR                  None   [argval=None]
    62  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

## class_body_annotations

### Source

```python
class C:
    y: str = 'a'
    z: dict
```

### `module` (`<module>`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `4`
- `co_code.hex()`: `8000150021005200170052013402000000000000740052022300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['<code object C>', "'C'", 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_BUILD_CLASS              None   [argval=None]
     4  PUSH_NULL                     None   [argval=None]
     6  LOAD_CONST                      0  <code object C at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object C>]
     8  MAKE_FUNCTION                 None   [argval=None]
    10  LOAD_CONST                      1  'C' [argval='C']
    12  CALL                            2   [argval=2]
    20  STORE_NAME                      0  C [argval='C']
    22  LOAD_CONST                      2  None [argval=None]
    24  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[0]<C>` (`C`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `2`
- `co_code.hex()`: `610080005d007401520074025e01740316006f005201740456003301520217006c087405520374065600740752042300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `['__classdict__']`
- `co_freevars`: `[]`
- `co_consts`: `["'C'", "'a'", '<code object __annotate__>', '()', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  MAKE_CELL                       0  __classdict__ [argval='__classdict__']
     2  RESUME                          0   [argval=0]
     4  LOAD_NAME                       0  __name__ [argval='__name__']
     6  STORE_NAME                      1  __module__ [argval='__module__']
     8  LOAD_CONST                      0  'C' [argval='C']
    10  STORE_NAME                      2  __qualname__ [argval='__qualname__']
    12  LOAD_SMALL_INT                  1   [argval=1]
    14  STORE_NAME                      3  __firstlineno__ [argval='__firstlineno__']
    16  LOAD_LOCALS                   None   [argval=None]
    18  STORE_DEREF                     0  __classdict__ [argval='__classdict__']
    20  LOAD_CONST                      1  'a' [argval='a']
    22  STORE_NAME                      4  y [argval='y']
    24  LOAD_FAST_BORROW                0  __classdict__ [argval='__classdict__']
    26  BUILD_TUPLE                     1   [argval=1]
    28  LOAD_CONST                      2  <code object __annotate__ at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object __annotate__>]
    30  MAKE_FUNCTION                 None   [argval=None]
    32  SET_FUNCTION_ATTRIBUTE          8  closure [argval=8]
    34  STORE_NAME                      5  __annotate_func__ [argval='__annotate_func__']
    36  LOAD_CONST                      3  () [argval=()]
    38  STORE_NAME                      6  __static_attributes__ [argval='__static_attributes__']
    40  LOAD_FAST_BORROW                0  __classdict__ [argval='__classdict__']
    42  STORE_NAME                      7  __classdictcell__ [argval='__classdictcell__']
    44  LOAD_CONST                      4  None [argval=None]
    46  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[0]<C>.co_consts[2]<__annotate__>` (`__annotate__`)

- `co_flags`: `0x3` (3)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: (none)
- `co_stacksize`: `4`
- `co_code.hex()`: `3c01800056005e0238840000640300001c00510168012f0053015b003b0252012600000053015b013b025202260000002300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `['format']`
- `co_cellvars`: `[]`
- `co_freevars`: `['__classdict__']`
- `co_consts`: `['2', "'y'", "'z'"]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  COPY_FREE_VARS                  1   [argval=1]
     2  RESUME                          0   [argval=0]
     4  LOAD_FAST_BORROW                0  format [argval='format']
     6  LOAD_SMALL_INT                  2   [argval=2]
     8  COMPARE_OP                    132  > [argval='>']
    12  POP_JUMP_IF_FALSE               3  to L1 [argval=22]
    16  NOT_TAKEN                     None   [argval=None]
    18  LOAD_COMMON_CONSTANT            1  NotImplementedError [argval=1]
    20  RAISE_VARARGS                   1   [argval=1]
    22  BUILD_MAP                       0   [argval=0]
    24  LOAD_DEREF                      1  __classdict__ [argval='__classdict__']
    26  LOAD_FROM_DICT_OR_GLOBALS       0  str [argval='str']
    28  COPY                            2   [argval=2]
    30  LOAD_CONST                      1  'y' [argval='y']
    32  STORE_SUBSCR                  None   [argval=None]
    36  LOAD_DEREF                      1  __classdict__ [argval='__classdict__']
    38  LOAD_FROM_DICT_OR_GLOBALS       1  dict [argval='dict']
    40  COPY                            2   [argval=2]
    42  LOAD_CONST                      2  'z' [argval='z']
    44  STORE_SUBSCR                  None   [argval=None]
    48  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

## function_local_annotated

### Source

```python
def f():
    q: int = 3
```

### `module` (`<module>`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `1`
- `co_code.hex()`: `800052001700740052012300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['<code object f>', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_CONST                      0  <code object f at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object f>]
     4  MAKE_FUNCTION                 None   [argval=None]
     6  STORE_NAME                      0  f [argval='f']
     8  LOAD_CONST                      1  None [argval=None]
    10  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[0]<f>` (`f`)

- `co_flags`: `0x3` (3)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: (none)
- `co_stacksize`: `1`
- `co_code.hex()`: `80005e03700052012300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `['q']`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['3', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_SMALL_INT                  3   [argval=3]
     4  STORE_FAST                      0  q [argval='q']
     6  LOAD_CONST                      1  None [argval=None]
     8  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

## function_local_bare_annotation

### Source

```python
def f():
    q: list
```

### `module` (`<module>`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `1`
- `co_code.hex()`: `800052001700740052012300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['<code object f>', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_CONST                      0  <code object f at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object f>]
     4  MAKE_FUNCTION                 None   [argval=None]
     6  STORE_NAME                      0  f [argval='f']
     8  LOAD_CONST                      1  None [argval=None]
    10  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[0]<f>` (`f`)

- `co_flags`: `0x3` (3)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: (none)
- `co_stacksize`: `1`
- `co_code.hex()`: `800052002300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_CONST                      0  None [argval=None]
     4  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

## annotated_attribute_target

### Source

```python
def f(o):
    o.k: int = 1
```

### `module` (`<module>`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `1`
- `co_code.hex()`: `800052001700740052012300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['<code object f>', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_CONST                      0  <code object f at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object f>]
     4  MAKE_FUNCTION                 None   [argval=None]
     6  STORE_NAME                      0  f [argval='f']
     8  LOAD_CONST                      1  None [argval=None]
    10  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[0]<f>` (`f`)

- `co_flags`: `0x3` (3)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: (none)
- `co_stacksize`: `2`
- `co_code.hex()`: `80005e0156006e00000000000000000052012300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `['o']`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['1', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_SMALL_INT                  1   [argval=1]
     4  LOAD_FAST_BORROW                0  o [argval='o']
     6  STORE_ATTR                      0  k [argval='k']
    16  LOAD_CONST                      1  None [argval=None]
    18  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

## annotated_subscript_target

### Source

```python
def f(d):
    d["k"]: int = 1
```

### `module` (`<module>`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `1`
- `co_code.hex()`: `800052001700740052012300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['<code object f>', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_CONST                      0  <code object f at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object f>]
     4  MAKE_FUNCTION                 None   [argval=None]
     6  STORE_NAME                      0  f [argval='f']
     8  LOAD_CONST                      1  None [argval=None]
    10  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[0]<f>` (`f`)

- `co_flags`: `0x3` (3)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: (none)
- `co_stacksize`: `3`
- `co_code.hex()`: `80005e01560052012600000052022300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `['d']`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['1', "'k'", 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_SMALL_INT                  1   [argval=1]
     4  LOAD_FAST_BORROW                0  d [argval='d']
     6  LOAD_CONST                      1  'k' [argval='k']
     8  STORE_SUBSCR                  None   [argval=None]
    12  LOAD_CONST                      2  None [argval=None]
    14  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

## type_alias_simple

### Source

```python
type Pair = tuple[int, int]
```

### `module` (`<module>`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `4`
- `co_code.hex()`: `8000520052015202520317006c013303350b740052012300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `["'Pair'", 'None', '(1,)', '<code object Pair>']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_CONST                      0  'Pair' [argval='Pair']
     4  LOAD_CONST                      1  None [argval=None]
     6  LOAD_CONST                      2  (1,) [argval=(1,)]
     8  LOAD_CONST                      3  <code object Pair at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object Pair>]
    10  MAKE_FUNCTION                 None   [argval=None]
    12  SET_FUNCTION_ATTRIBUTE          1  defaults [argval=1]
    14  BUILD_TUPLE                     3   [argval=3]
    16  CALL_INTRINSIC_1               11  INTRINSIC_TYPEALIAS [argval=11]
    18  STORE_NAME                      0  Pair [argval='Pair']
    20  LOAD_CONST                      1  None [argval=None]
    22  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[3]<Pair>` (`Pair`)

- `co_flags`: `0x3` (3)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: (none)
- `co_stacksize`: `3`
- `co_code.hex()`: `800056005e0238840000640300001c00510168015c0000000000000000005c0200000000000000005c02000000000000000033022c1a000000000000000000002300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `['.format']`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['2']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_FAST_BORROW                0  .format [argval='.format']
     4  LOAD_SMALL_INT                  2   [argval=2]
     6  COMPARE_OP                    132  > [argval='>']
    10  POP_JUMP_IF_FALSE               3  to L1 [argval=20]
    14  NOT_TAKEN                     None   [argval=None]
    16  LOAD_COMMON_CONSTANT            1  NotImplementedError [argval=1]
    18  RAISE_VARARGS                   1   [argval=1]
    20  LOAD_GLOBAL                     0  tuple [argval='tuple']
    30  LOAD_GLOBAL                     2  int [argval='int']
    40  LOAD_GLOBAL                     2  int [argval='int']
    50  BUILD_TUPLE                     2   [argval=2]
    52  BINARY_OP                      26  [] [argval=26]
    64  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

## type_alias_parametrized

### Source

```python
type Box[T] = list[T]
```

### `module` (`<module>`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `2`
- `co_code.hex()`: `80005200170021003400000000000000740052012300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['<code object <generic parameters of Box>>', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_CONST                      0  <code object <generic parameters of Box> at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object <generic parameters of Box>>]
     4  MAKE_FUNCTION                 None   [argval=None]
     6  PUSH_NULL                     None   [argval=None]
     8  CALL                            0   [argval=0]
    16  STORE_NAME                      0  Box [argval='Box']
    18  LOAD_CONST                      1  None [argval=None]
    20  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[0]<<generic parameters of Box>>` (`<generic parameters of Box>`)

- `co_flags`: `0x3` (3)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: (none)
- `co_stacksize`: `5`
- `co_code.hex()`: `610080005200520135073b016f003301520256003301520317006c086c013303350b2300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `['T']`
- `co_freevars`: `[]`
- `co_consts`: `["'Box'", "'T'", '(1,)', '<code object Box>']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  MAKE_CELL                       0  T [argval='T']
     2  RESUME                          0   [argval=0]
     4  LOAD_CONST                      0  'Box' [argval='Box']
     6  LOAD_CONST                      1  'T' [argval='T']
     8  CALL_INTRINSIC_1                7  INTRINSIC_TYPEVAR [argval=7]
    10  COPY                            1   [argval=1]
    12  STORE_DEREF                     0  T [argval='T']
    14  BUILD_TUPLE                     1   [argval=1]
    16  LOAD_CONST                      2  (1,) [argval=(1,)]
    18  LOAD_FAST_BORROW                0  T [argval='T']
    20  BUILD_TUPLE                     1   [argval=1]
    22  LOAD_CONST                      3  <code object Box at 0xADDR, file "<b11-annotations>", line 1> [argval=<code object Box>]
    24  MAKE_FUNCTION                 None   [argval=None]
    26  SET_FUNCTION_ATTRIBUTE          8  closure [argval=8]
    28  SET_FUNCTION_ATTRIBUTE          1  defaults [argval=1]
    30  BUILD_TUPLE                     3   [argval=3]
    32  CALL_INTRINSIC_1               11  INTRINSIC_TYPEALIAS [argval=11]
    34  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

### `module.co_consts[0]<<generic parameters of Box>>.co_consts[3]<Box>` (`Box`)

- `co_flags`: `0x13` (19)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS, CO_NESTED
- coroutine-family: (none)
- `co_stacksize`: `2`
- `co_code.hex()`: `3c01800056005e0238840000640300001c00510168015c00000000000000000053012c1a000000000000000000002300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `['.format']`
- `co_cellvars`: `[]`
- `co_freevars`: `['T']`
- `co_consts`: `['2']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  COPY_FREE_VARS                  1   [argval=1]
     2  RESUME                          0   [argval=0]
     4  LOAD_FAST_BORROW                0  .format [argval='.format']
     6  LOAD_SMALL_INT                  2   [argval=2]
     8  COMPARE_OP                    132  > [argval='>']
    12  POP_JUMP_IF_FALSE               3  to L1 [argval=22]
    16  NOT_TAKEN                     None   [argval=None]
    18  LOAD_COMMON_CONSTANT            1  NotImplementedError [argval=1]
    20  RAISE_VARARGS                   1   [argval=1]
    22  LOAD_GLOBAL                     0  list [argval='list']
    32  LOAD_DEREF                      1  T [argval='T']
    34  BINARY_OP                      26  [] [argval=26]
    46  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```

## plain_assign_control

### Source

```python
x = 5
```

### `module` (`<module>`)

- `co_flags`: `0x0` (0)
- named flags:
- coroutine-family: (none)
- `co_stacksize`: `1`
- `co_code.hex()`: `80005e05740052012300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`
- `co_consts`: `['5', 'None']`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_SMALL_INT                  5   [argval=5]
     4  STORE_NAME                      0  x [argval='x']
     6  LOAD_CONST                      1  None [argval=None]
     8  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```
