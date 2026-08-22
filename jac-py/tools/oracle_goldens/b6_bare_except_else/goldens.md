# Band 6 bare-except and try/else CPython 3.14 goldens

Interpreter: `CPython 3.14.7`

## `bare_except_body`

### Source

```python
def f():
    try:
        raise ValueError("x")
    except:
        return "caught"

```

### Function code object

- path: `module.co_consts[0]`
- co_flags: `0x1000003`
- co_stacksize: `4`
- co_code: `80001b005c01000000000000000052003401000000000000680120001f001d00520123003b031d006901`
- co_exceptiontable: `820b0d008d021203`

### Disassembly

```text
0000 RESUME                   arg=0 argrepr=''
0002 NOP                      arg=None argrepr=''
0004 LOAD_GLOBAL              arg=1 argrepr='ValueError + NULL'
0014 LOAD_CONST               arg=0 argrepr="'x'"
0016 CALL                     arg=1 argrepr=''
0024 RAISE_VARARGS            arg=1 argrepr=''
0026 PUSH_EXC_INFO            arg=None argrepr=''
0028 POP_TOP                  arg=None argrepr=''
0030 POP_EXCEPT               arg=None argrepr=''
0032 LOAD_CONST               arg=1 argrepr="'caught'"
0034 RETURN_VALUE             arg=None argrepr=''
0036 COPY                     arg=3 argrepr=''
0038 POP_EXCEPT               arg=None argrepr=''
0040 RERAISE                  arg=1 argrepr=''
```

### Exception entries

```text
0004..0026 -> 0026 depth=0 lasti=False
0026..0030 -> 0036 depth=1 lasti=True
```

## `typed_then_bare_except`

### Source

```python
def f():
    try:
        raise RuntimeError("x")
    except ValueError:
        return "value"
    except:
        return "bare"

```

### Function code object

- path: `module.co_consts[0]`
- co_flags: `0x1000003`
- co_stacksize: `4`
- co_code: `80001b005c01000000000000000052003401000000000000680120005c0200000000000000000600640500001c001f001d00520123001f001d00520223003b031d006901`
- co_exceptiontable: `820b0d008d0b1f039b011f03`

### Disassembly

```text
0000 RESUME                   arg=0 argrepr=''
0002 NOP                      arg=None argrepr=''
0004 LOAD_GLOBAL              arg=1 argrepr='RuntimeError + NULL'
0014 LOAD_CONST               arg=0 argrepr="'x'"
0016 CALL                     arg=1 argrepr=''
0024 RAISE_VARARGS            arg=1 argrepr=''
0026 PUSH_EXC_INFO            arg=None argrepr=''
0028 LOAD_GLOBAL              arg=2 argrepr='ValueError'
0038 CHECK_EXC_MATCH          arg=None argrepr=''
0040 POP_JUMP_IF_FALSE        arg=5 argrepr='to L1'
0044 NOT_TAKEN                arg=None argrepr=''
0046 POP_TOP                  arg=None argrepr=''
0048 POP_EXCEPT               arg=None argrepr=''
0050 LOAD_CONST               arg=1 argrepr="'value'"
0052 RETURN_VALUE             arg=None argrepr=''
0054 POP_TOP                  arg=None argrepr=''
0056 POP_EXCEPT               arg=None argrepr=''
0058 LOAD_CONST               arg=2 argrepr="'bare'"
0060 RETURN_VALUE             arg=None argrepr=''
0062 COPY                     arg=3 argrepr=''
0064 POP_EXCEPT               arg=None argrepr=''
0066 RERAISE                  arg=1 argrepr=''
```

### Exception entries

```text
0004..0026 -> 0026 depth=0 lasti=False
0026..0048 -> 0062 depth=1 lasti=True
0054..0056 -> 0062 depth=1 lasti=True
```

## `bare_except_reraise`

### Source

```python
def f():
    try:
        raise ValueError("x")
    except:
        raise

```

### Function code object

- path: `module.co_consts[0]`
- co_flags: `0x1000003`
- co_stacksize: `4`
- co_code: `80001b005c01000000000000000052003401000000000000680120001f0068003b031d006901`
- co_exceptiontable: `820b0d008d031003`

### Disassembly

```text
0000 RESUME                   arg=0 argrepr=''
0002 NOP                      arg=None argrepr=''
0004 LOAD_GLOBAL              arg=1 argrepr='ValueError + NULL'
0014 LOAD_CONST               arg=0 argrepr="'x'"
0016 CALL                     arg=1 argrepr=''
0024 RAISE_VARARGS            arg=1 argrepr=''
0026 PUSH_EXC_INFO            arg=None argrepr=''
0028 POP_TOP                  arg=None argrepr=''
0030 RAISE_VARARGS            arg=0 argrepr=''
0032 COPY                     arg=3 argrepr=''
0034 POP_EXCEPT               arg=None argrepr=''
0036 RERAISE                  arg=1 argrepr=''
```

### Exception entries

```text
0004..0026 -> 0026 depth=0 lasti=False
0026..0032 -> 0032 depth=1 lasti=True
```

## `try_else_normal`

### Source

```python
def f():
    try:
        value = 1
    except ValueError:
        value = 2
    else:
        value = 3
    return value

```

### Function code object

- path: `module.co_consts[0]`
- co_flags: `0x1000003`
- co_stacksize: `4`
- co_code: `80001b005e0170005e0370005600230020005c0000000000000000000600640700001c001f005e0270001d005400230069003b031d006901`
- co_exceptiontable: `82020800880d190398011903`

### Disassembly

```text
0000 RESUME                   arg=0 argrepr=''
0002 NOP                      arg=None argrepr=''
0004 LOAD_SMALL_INT           arg=1 argrepr=''
0006 STORE_FAST               arg=0 argrepr='value'
0008 LOAD_SMALL_INT           arg=3 argrepr=''
0010 STORE_FAST               arg=0 argrepr='value'
0012 LOAD_FAST_BORROW         arg=0 argrepr='value'
0014 RETURN_VALUE             arg=None argrepr=''
0016 PUSH_EXC_INFO            arg=None argrepr=''
0018 LOAD_GLOBAL              arg=0 argrepr='ValueError'
0028 CHECK_EXC_MATCH          arg=None argrepr=''
0030 POP_JUMP_IF_FALSE        arg=7 argrepr='to L1'
0034 NOT_TAKEN                arg=None argrepr=''
0036 POP_TOP                  arg=None argrepr=''
0038 LOAD_SMALL_INT           arg=2 argrepr=''
0040 STORE_FAST               arg=0 argrepr='value'
0042 POP_EXCEPT               arg=None argrepr=''
0044 LOAD_FAST                arg=0 argrepr='value'
0046 RETURN_VALUE             arg=None argrepr=''
0048 RERAISE                  arg=0 argrepr=''
0050 COPY                     arg=3 argrepr=''
0052 POP_EXCEPT               arg=None argrepr=''
0054 RERAISE                  arg=1 argrepr=''
```

### Exception entries

```text
0004..0008 -> 0016 depth=0 lasti=False
0016..0042 -> 0050 depth=1 lasti=True
0048..0050 -> 0050 depth=1 lasti=True
```

## `try_except_else_exception`

### Source

```python
def f():
    try:
        raise ValueError("x")
    except ValueError:
        value = 2
    else:
        value = 3
    return value

```

### Function code object

- path: `module.co_consts[0]`
- co_flags: `0x1000003`
- co_stacksize: `4`
- co_code: `80001b005c01000000000000000052003401000000000000680120005c0000000000000000000600640700001c001f005e0270001d005400230069003b031d006901`
- co_exceptiontable: `820b0d008d0d1e039d011e03`

### Disassembly

```text
0000 RESUME                   arg=0 argrepr=''
0002 NOP                      arg=None argrepr=''
0004 LOAD_GLOBAL              arg=1 argrepr='ValueError + NULL'
0014 LOAD_CONST               arg=0 argrepr="'x'"
0016 CALL                     arg=1 argrepr=''
0024 RAISE_VARARGS            arg=1 argrepr=''
0026 PUSH_EXC_INFO            arg=None argrepr=''
0028 LOAD_GLOBAL              arg=0 argrepr='ValueError'
0038 CHECK_EXC_MATCH          arg=None argrepr=''
0040 POP_JUMP_IF_FALSE        arg=7 argrepr='to L1'
0044 NOT_TAKEN                arg=None argrepr=''
0046 POP_TOP                  arg=None argrepr=''
0048 LOAD_SMALL_INT           arg=2 argrepr=''
0050 STORE_FAST               arg=0 argrepr='value'
0052 POP_EXCEPT               arg=None argrepr=''
0054 LOAD_FAST                arg=0 argrepr='value'
0056 RETURN_VALUE             arg=None argrepr=''
0058 RERAISE                  arg=0 argrepr=''
0060 COPY                     arg=3 argrepr=''
0062 POP_EXCEPT               arg=None argrepr=''
0064 RERAISE                  arg=1 argrepr=''
```

### Exception entries

```text
0004..0026 -> 0026 depth=0 lasti=False
0026..0052 -> 0060 depth=1 lasti=True
0058..0060 -> 0060 depth=1 lasti=True
```

## `try_except_else_finally`

### Source

```python
def f():
    try:
        value = 1
    except ValueError:
        value = 2
    else:
        value = 3
    finally:
        value = 4
    return value

```

### Function code object

- path: `module.co_consts[0]`
- co_flags: `0x1000003`
- co_stacksize: `4`
- co_code: `80001b005e0170005e0370005e0470005600230020005c0000000000000000000600640600001c001f005e0270001d004c1369003b031d00690120005e04700069003b031d006901`
- co_exceptiontable: `82020a0084021d008a0d1a0397021d0099011a039a031d009d042103`

### Disassembly

```text
0000 RESUME                   arg=0 argrepr=''
0002 NOP                      arg=None argrepr=''
0004 LOAD_SMALL_INT           arg=1 argrepr=''
0006 STORE_FAST               arg=0 argrepr='value'
0008 LOAD_SMALL_INT           arg=3 argrepr=''
0010 STORE_FAST               arg=0 argrepr='value'
0012 LOAD_SMALL_INT           arg=4 argrepr=''
0014 STORE_FAST               arg=0 argrepr='value'
0016 LOAD_FAST_BORROW         arg=0 argrepr='value'
0018 RETURN_VALUE             arg=None argrepr=''
0020 PUSH_EXC_INFO            arg=None argrepr=''
0022 LOAD_GLOBAL              arg=0 argrepr='ValueError'
0032 CHECK_EXC_MATCH          arg=None argrepr=''
0034 POP_JUMP_IF_FALSE        arg=6 argrepr='to L2'
0038 NOT_TAKEN                arg=None argrepr=''
0040 POP_TOP                  arg=None argrepr=''
0042 LOAD_SMALL_INT           arg=2 argrepr=''
0044 STORE_FAST               arg=0 argrepr='value'
0046 POP_EXCEPT               arg=None argrepr=''
0048 JUMP_BACKWARD_NO_INTERRUPT arg=19 argrepr='to L1'
0050 RERAISE                  arg=0 argrepr=''
0052 COPY                     arg=3 argrepr=''
0054 POP_EXCEPT               arg=None argrepr=''
0056 RERAISE                  arg=1 argrepr=''
0058 PUSH_EXC_INFO            arg=None argrepr=''
0060 LOAD_SMALL_INT           arg=4 argrepr=''
0062 STORE_FAST               arg=0 argrepr='value'
0064 RERAISE                  arg=0 argrepr=''
0066 COPY                     arg=3 argrepr=''
0068 POP_EXCEPT               arg=None argrepr=''
0070 RERAISE                  arg=1 argrepr=''
```

### Exception entries

```text
0004..0008 -> 0020 depth=0 lasti=False
0008..0012 -> 0058 depth=0 lasti=False
0020..0046 -> 0052 depth=1 lasti=True
0046..0050 -> 0058 depth=0 lasti=False
0050..0052 -> 0052 depth=1 lasti=True
0052..0058 -> 0058 depth=0 lasti=False
0058..0066 -> 0066 depth=1 lasti=True
```

## `try_without_except_or_finally`

### Source

```python
def f():
    try:
        pass

```

### Compile result

- status: `syntax_error`
- message: `expected 'except' or 'finally' block (<try_without_except_or_finally>, line 3)`

## `tuple_except_as`

### Source

```python
def f():
    try:
        raise KeyError("x")
    except (ValueError, KeyError) as error:
        return error

```

### Function code object

- path: `module.co_consts[0]`
- co_flags: `0x1000003`
- co_stacksize: `4`
- co_code: `80001b005c01000000000000000052003401000000000000680120005c0200000000000000005c00000000000000000033020600640d00001c007000540075021d00520170003f002300520170003f00690169003b031d006901`
- co_exceptiontable: `820b0d008d112a039e0125039f012a03a5052a03`

### Disassembly

```text
0000 RESUME                   arg=0 argrepr=''
0002 NOP                      arg=None argrepr=''
0004 LOAD_GLOBAL              arg=1 argrepr='KeyError + NULL'
0014 LOAD_CONST               arg=0 argrepr="'x'"
0016 CALL                     arg=1 argrepr=''
0024 RAISE_VARARGS            arg=1 argrepr=''
0026 PUSH_EXC_INFO            arg=None argrepr=''
0028 LOAD_GLOBAL              arg=2 argrepr='ValueError'
0038 LOAD_GLOBAL              arg=0 argrepr='KeyError'
0048 BUILD_TUPLE              arg=2 argrepr=''
0050 CHECK_EXC_MATCH          arg=None argrepr=''
0052 POP_JUMP_IF_FALSE        arg=13 argrepr='to L1'
0056 NOT_TAKEN                arg=None argrepr=''
0058 STORE_FAST               arg=0 argrepr='error'
0060 LOAD_FAST                arg=0 argrepr='error'
0062 SWAP                     arg=2 argrepr=''
0064 POP_EXCEPT               arg=None argrepr=''
0066 LOAD_CONST               arg=1 argrepr='None'
0068 STORE_FAST               arg=0 argrepr='error'
0070 DELETE_FAST              arg=0 argrepr='error'
0072 RETURN_VALUE             arg=None argrepr=''
0074 LOAD_CONST               arg=1 argrepr='None'
0076 STORE_FAST               arg=0 argrepr='error'
0078 DELETE_FAST              arg=0 argrepr='error'
0080 RERAISE                  arg=1 argrepr=''
0082 RERAISE                  arg=0 argrepr=''
0084 COPY                     arg=3 argrepr=''
0086 POP_EXCEPT               arg=None argrepr=''
0088 RERAISE                  arg=1 argrepr=''
```

### Exception entries

```text
0004..0026 -> 0026 depth=0 lasti=False
0026..0060 -> 0084 depth=1 lasti=True
0060..0062 -> 0074 depth=1 lasti=True
0062..0064 -> 0084 depth=1 lasti=True
0074..0084 -> 0084 depth=1 lasti=True
```
