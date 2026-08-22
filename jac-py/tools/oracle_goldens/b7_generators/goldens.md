# Band 7 generator CPython oracle goldens

Interpreter: `CPython 3.14.7` (3.14.7 (main, Aug 10 2026, 07:46:56) [GCC 16.1.1 20260728])

All byte strings below are from host `compile(source, '<b7-generators>', 'exec')`; nested code objects are walked recursively through `co_consts`.

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

## simplest_generator

### Source

```python
def g():
    yield 1
```

### `module.co_consts[0]<g>` (`g`)

- `co_flags`: `0x23` (35)
- named flags: CO_GENERATOR, CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: CO_GENERATOR
- `co_stacksize`: `2`
- `co_code.hex()`: `22001f0080005e01780080051f005201230035036901`
- `co_exceptiontable.hex()`: `82070901`
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RETURN_GENERATOR              None   [argval=None]
     2  POP_TOP                       None   [argval=None]
     4  RESUME                          0   [argval=0]
     6  LOAD_SMALL_INT                  1   [argval=1]
     8  YIELD_VALUE                     0   [argval=0]
    10  RESUME                          5   [argval=5]
    12  POP_TOP                       None   [argval=None]
    14  LOAD_CONST                      1  None [argval=None]
    16  RETURN_VALUE                  None   [argval=None]
    18  CALL_INTRINSIC_1                3  INTRINSIC_STOPITERATION_ERROR [argval=3]
    20  RERAISE                         1   [argval=1]
```

Exception entries:

```text
   4..18   ->   18 depth=0 lasti=True
```

## yield_value_then_return

### Source

```python
def g():
    yield 1
    return
```

### `module.co_consts[0]<g>` (`g`)

- `co_flags`: `0x23` (35)
- named flags: CO_GENERATOR, CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: CO_GENERATOR
- `co_stacksize`: `2`
- `co_code.hex()`: `22001f0080005e01780080051f005201230035036901`
- `co_exceptiontable.hex()`: `82070901`
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RETURN_GENERATOR              None   [argval=None]
     2  POP_TOP                       None   [argval=None]
     4  RESUME                          0   [argval=0]
     6  LOAD_SMALL_INT                  1   [argval=1]
     8  YIELD_VALUE                     0   [argval=0]
    10  RESUME                          5   [argval=5]
    12  POP_TOP                       None   [argval=None]
    14  LOAD_CONST                      1  None [argval=None]
    16  RETURN_VALUE                  None   [argval=None]
    18  CALL_INTRINSIC_1                3  INTRINSIC_STOPITERATION_ERROR [argval=3]
    20  RERAISE                         1   [argval=1]
```

Exception entries:

```text
   4..18   ->   18 depth=0 lasti=True
```

## bare_yield

### Source

```python
def g():
    yield
```

### `module.co_consts[0]<g>` (`g`)

- `co_flags`: `0x23` (35)
- named flags: CO_GENERATOR, CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: CO_GENERATOR
- `co_stacksize`: `2`
- `co_code.hex()`: `22001f0080005200780080051f005200230035036901`
- `co_exceptiontable.hex()`: `82070901`
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RETURN_GENERATOR              None   [argval=None]
     2  POP_TOP                       None   [argval=None]
     4  RESUME                          0   [argval=0]
     6  LOAD_CONST                      0  None [argval=None]
     8  YIELD_VALUE                     0   [argval=0]
    10  RESUME                          5   [argval=5]
    12  POP_TOP                       None   [argval=None]
    14  LOAD_CONST                      0  None [argval=None]
    16  RETURN_VALUE                  None   [argval=None]
    18  CALL_INTRINSIC_1                3  INTRINSIC_STOPITERATION_ERROR [argval=3]
    20  RERAISE                         1   [argval=1]
```

Exception entries:

```text
   4..18   ->   18 depth=0 lasti=True
```

## yield_from_iterable

### Source

```python
def g():
    yield from [1, 2, 3]
```

### `module.co_consts[0]<g>` (`g`)

- `co_flags`: `0x23` (35)
- named flags: CO_GENERATOR, CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: CO_GENERATOR
- `co_stacksize`: `3`
- `co_code.hex()`: `22001f0080002e0052024f01130052016a030000780180024c050a001f005201230007004c0635036901`
- `co_exceptiontable.hex()`: `820813018a0111048b071301`
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RETURN_GENERATOR              None   [argval=None]
     2  POP_TOP                       None   [argval=None]
     4  RESUME                          0   [argval=0]
     6  BUILD_LIST                      0   [argval=0]
     8  LOAD_CONST                      2  (1, 2, 3) [argval=(1, 2, 3)]
    10  LIST_EXTEND                     1   [argval=1]
    12  GET_YIELD_FROM_ITER           None   [argval=None]
    14  LOAD_CONST                      1  None [argval=None]
    16  SEND                            3  to L2 [argval=26]
    20  YIELD_VALUE                     1   [argval=1]
    22  RESUME                          2   [argval=2]
    24  JUMP_BACKWARD_NO_INTERRUPT      5  to L1 [argval=16]
    26  END_SEND                      None   [argval=None]
    28  POP_TOP                       None   [argval=None]
    30  LOAD_CONST                      1  None [argval=None]
    32  RETURN_VALUE                  None   [argval=None]
    34  CLEANUP_THROW                 None   [argval=None]
    36  JUMP_BACKWARD_NO_INTERRUPT      6  to L2 [argval=26]
    38  CALL_INTRINSIC_1                3  INTRINSIC_STOPITERATION_ERROR [argval=3]
    40  RERAISE                         1   [argval=1]
```

Exception entries:

```text
   4..20   ->   38 depth=0 lasti=True
  20..22   ->   34 depth=2 lasti=False
  22..36   ->   38 depth=0 lasti=True
```

## yield_from_return_value

### Source

```python
def inner():
    return 7
    yield

def g():
    x = yield from inner()
    yield x
```

### `module.co_consts[0]<inner>` (`inner`)

- `co_flags`: `0x23` (35)
- named flags: CO_GENERATOR, CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: CO_GENERATOR
- `co_stacksize`: `2`
- `co_code.hex()`: `22001f0080005e07230035036901`
- `co_exceptiontable.hex()`: `82030501`
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RETURN_GENERATOR              None   [argval=None]
     2  POP_TOP                       None   [argval=None]
     4  RESUME                          0   [argval=0]
     6  LOAD_SMALL_INT                  7   [argval=7]
     8  RETURN_VALUE                  None   [argval=None]
    10  CALL_INTRINSIC_1                3  INTRINSIC_STOPITERATION_ERROR [argval=3]
    12  RERAISE                         1   [argval=1]
```

Exception entries:

```text
   4..10   ->   10 depth=0 lasti=True
```

### `module.co_consts[1]<g>` (`g`)

- `co_flags`: `0x23` (35)
- named flags: CO_GENERATOR, CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: CO_GENERATOR
- `co_stacksize`: `3`
- `co_code.hex()`: `22001f0080005c0100000000000000003400000000000000130052006a030000780180024c050a0070005600780080051f005200230007004c0a35036901`
- `co_exceptiontable.hex()`: `820e1d0190011b04910b1d01`
- `co_varnames`: `['x']`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RETURN_GENERATOR              None   [argval=None]
     2  POP_TOP                       None   [argval=None]
     4  RESUME                          0   [argval=0]
     6  LOAD_GLOBAL                     1  inner + NULL [argval='inner']
    16  CALL                            0   [argval=0]
    24  GET_YIELD_FROM_ITER           None   [argval=None]
    26  LOAD_CONST                      0  None [argval=None]
    28  SEND                            3  to L2 [argval=38]
    32  YIELD_VALUE                     1   [argval=1]
    34  RESUME                          2   [argval=2]
    36  JUMP_BACKWARD_NO_INTERRUPT      5  to L1 [argval=28]
    38  END_SEND                      None   [argval=None]
    40  STORE_FAST                      0  x [argval='x']
    42  LOAD_FAST_BORROW                0  x [argval='x']
    44  YIELD_VALUE                     0   [argval=0]
    46  RESUME                          5   [argval=5]
    48  POP_TOP                       None   [argval=None]
    50  LOAD_CONST                      0  None [argval=None]
    52  RETURN_VALUE                  None   [argval=None]
    54  CLEANUP_THROW                 None   [argval=None]
    56  JUMP_BACKWARD_NO_INTERRUPT     10  to L2 [argval=38]
    58  CALL_INTRINSIC_1                3  INTRINSIC_STOPITERATION_ERROR [argval=3]
    60  RERAISE                         1   [argval=1]
```

Exception entries:

```text
   4..32   ->   58 depth=0 lasti=True
  32..34   ->   54 depth=2 lasti=False
  34..56   ->   58 depth=0 lasti=True
```

## generator_return_value

### Source

```python
def g():
    yield 1
    return 42
```

### `module.co_consts[0]<g>` (`g`)

- `co_flags`: `0x23` (35)
- named flags: CO_GENERATOR, CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: CO_GENERATOR
- `co_stacksize`: `2`
- `co_code.hex()`: `22001f0080005e01780080051f005e2a230035036901`
- `co_exceptiontable.hex()`: `82070901`
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RETURN_GENERATOR              None   [argval=None]
     2  POP_TOP                       None   [argval=None]
     4  RESUME                          0   [argval=0]
     6  LOAD_SMALL_INT                  1   [argval=1]
     8  YIELD_VALUE                     0   [argval=0]
    10  RESUME                          5   [argval=5]
    12  POP_TOP                       None   [argval=None]
    14  LOAD_SMALL_INT                 42   [argval=42]
    16  RETURN_VALUE                  None   [argval=None]
    18  CALL_INTRINSIC_1                3  INTRINSIC_STOPITERATION_ERROR [argval=3]
    20  RERAISE                         1   [argval=1]
```

Exception entries:

```text
   4..18   ->   18 depth=0 lasti=True
```

## yield_inside_try_finally

### Source

```python
def g():
    try:
        yield 1
    finally:
        cleanup = 2
```

### `module.co_consts[0]<g>` (`g`)

- `co_flags`: `0x23` (35)
- named flags: CO_GENERATOR, CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: CO_GENERATOR
- `co_stacksize`: `4`
- `co_code.hex()`: `22001f0080001b005e01780080011f005e0270005201230020005e02700069003b031d00690135036901`
- `co_exceptiontable.hex()`: `8201130184040c00880413018c04100390031301`
- `co_varnames`: `['cleanup']`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RETURN_GENERATOR              None   [argval=None]
     2  POP_TOP                       None   [argval=None]
     4  RESUME                          0   [argval=0]
     6  NOP                           None   [argval=None]
     8  LOAD_SMALL_INT                  1   [argval=1]
    10  YIELD_VALUE                     0   [argval=0]
    12  RESUME                          1   [argval=1]
    14  POP_TOP                       None   [argval=None]
    16  LOAD_SMALL_INT                  2   [argval=2]
    18  STORE_FAST                      0  cleanup [argval='cleanup']
    20  LOAD_CONST                      1  None [argval=None]
    22  RETURN_VALUE                  None   [argval=None]
    24  PUSH_EXC_INFO                 None   [argval=None]
    26  LOAD_SMALL_INT                  2   [argval=2]
    28  STORE_FAST                      0  cleanup [argval='cleanup']
    30  RERAISE                         0   [argval=0]
    32  COPY                            3   [argval=3]
    34  POP_EXCEPT                    None   [argval=None]
    36  RERAISE                         1   [argval=1]
    38  CALL_INTRINSIC_1                3  INTRINSIC_STOPITERATION_ERROR [argval=3]
    40  RERAISE                         1   [argval=1]
```

Exception entries:

```text
   4..6    ->   38 depth=0 lasti=True
   8..16   ->   24 depth=0 lasti=False
  16..24   ->   38 depth=0 lasti=True
  24..32   ->   32 depth=1 lasti=True
  32..38   ->   38 depth=0 lasti=True
```

## yield_inside_try_except

### Source

```python
def g():
    try:
        yield 1
    except ValueError:
        yield 2
```

### `module.co_consts[0]<g>` (`g`)

- `co_flags`: `0x23` (35)
- named flags: CO_GENERATOR, CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: CO_GENERATOR
- `co_stacksize`: `4`
- `co_code.hex()`: `22001f0080001b005e01780080011f005201230020005c0000000000000000000600640900001c001f005e02780080011f001d005201230069003b031d00690135036901`
- `co_exceptiontable.hex()`: `8201200184040a00880220018a0f1d03990320019c011d039d032001`
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RETURN_GENERATOR              None   [argval=None]
     2  POP_TOP                       None   [argval=None]
     4  RESUME                          0   [argval=0]
     6  NOP                           None   [argval=None]
     8  LOAD_SMALL_INT                  1   [argval=1]
    10  YIELD_VALUE                     0   [argval=0]
    12  RESUME                          1   [argval=1]
    14  POP_TOP                       None   [argval=None]
    16  LOAD_CONST                      1  None [argval=None]
    18  RETURN_VALUE                  None   [argval=None]
    20  PUSH_EXC_INFO                 None   [argval=None]
    22  LOAD_GLOBAL                     0  ValueError [argval='ValueError']
    32  CHECK_EXC_MATCH               None   [argval=None]
    34  POP_JUMP_IF_FALSE               9  to L1 [argval=56]
    38  NOT_TAKEN                     None   [argval=None]
    40  POP_TOP                       None   [argval=None]
    42  LOAD_SMALL_INT                  2   [argval=2]
    44  YIELD_VALUE                     0   [argval=0]
    46  RESUME                          1   [argval=1]
    48  POP_TOP                       None   [argval=None]
    50  POP_EXCEPT                    None   [argval=None]
    52  LOAD_CONST                      1  None [argval=None]
    54  RETURN_VALUE                  None   [argval=None]
    56  RERAISE                         0   [argval=0]
    58  COPY                            3   [argval=3]
    60  POP_EXCEPT                    None   [argval=None]
    62  RERAISE                         1   [argval=1]
    64  CALL_INTRINSIC_1                3  INTRINSIC_STOPITERATION_ERROR [argval=3]
    66  RERAISE                         1   [argval=1]
```

Exception entries:

```text
   4..6    ->   64 depth=0 lasti=True
   8..16   ->   20 depth=0 lasti=False
  16..20   ->   64 depth=0 lasti=True
  20..50   ->   58 depth=1 lasti=True
  50..56   ->   64 depth=0 lasti=True
  56..58   ->   58 depth=1 lasti=True
  58..64   ->   64 depth=0 lasti=True
```

## generator_expression

### Source

```python
gen = (x * 2 for x in range(3))
```

### `module.co_consts[0]<<genexpr>>` (`<genexpr>`)

- `co_flags`: `0x23` (35)
- named flags: CO_GENERATOR, CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: CO_GENERATOR
- `co_stacksize`: `3`
- `co_code.hex()`: `22001f0080005400460d000071115e022c0500000000000000000000780080051f004b0f000009001e005201230035036901`
- `co_exceptiontable.hex()`: `82151701`
- `co_varnames`: `['.0', 'x']`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RETURN_GENERATOR              None   [argval=None]
     2  POP_TOP                       None   [argval=None]
     4  RESUME                          0   [argval=0]
     6  LOAD_FAST                       0  .0 [argval='.0']
     8  FOR_ITER                       13  to L2 [argval=38]
    12  STORE_FAST_LOAD_FAST           17  x, x [argval=('x', 'x')]
    14  LOAD_SMALL_INT                  2   [argval=2]
    16  BINARY_OP                       5  * [argval=5]
    28  YIELD_VALUE                     0   [argval=0]
    30  RESUME                          5   [argval=5]
    32  POP_TOP                       None   [argval=None]
    34  JUMP_BACKWARD                  15  to L1 [argval=8]
    38  END_FOR                       None   [argval=None]
    40  POP_ITER                      None   [argval=None]
    42  LOAD_CONST                      1  None [argval=None]
    44  RETURN_VALUE                  None   [argval=None]
    46  CALL_INTRINSIC_1                3  INTRINSIC_STOPITERATION_ERROR [argval=3]
    48  RERAISE                         1   [argval=1]
```

Exception entries:

```text
   4..46   ->   46 depth=0 lasti=True
```

## non_generator_control

### Source

```python
def g():
    return 1
```

### `module.co_consts[0]<g>` (`g`)

- `co_flags`: `0x3` (3)
- named flags: CO_OPTIMIZED, CO_NEWLOCALS
- coroutine-family: (none)
- `co_stacksize`: `1`
- `co_code.hex()`: `80005e012300`
- `co_exceptiontable.hex()`: ``
- `co_varnames`: `[]`
- `co_cellvars`: `[]`
- `co_freevars`: `[]`

Instructions:

```text
offset  opcode                         arg  argrepr
     0  RESUME                          0   [argval=0]
     2  LOAD_SMALL_INT                  1   [argval=1]
     4  RETURN_VALUE                  None   [argval=None]
```

Exception entries:

```text
(none)
```
