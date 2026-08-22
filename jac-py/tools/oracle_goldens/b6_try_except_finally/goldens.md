# Band 6 try/except/finally combined CPython goldens

Generated with CPython 3.14.7 using `compile(source, '<f>', 'exec')`.
Instruction listings use `dis.get_instructions(..., show_caches=True, adaptive=False)`.

## `try_except_finally_normal`

### Source

```python
def f():
    try:
        value = 1
    except ValueError:
        value = 2
    finally:
        finished = 3
```

### Code object

- `qualname`: `f`
- `co_flags`: `0x1000003`
- `co_stacksize`: `4`
- `co_code`: `80001b005e0170005e0370015201230020005c0000000000000000000600640600001c001f005e0270001d004c1369003b031d00690120005e03700169003b031d006901`
- `co_exceptiontable`: `82020800880d180395021b009701180398031b009b041f03`

### Instructions

```text
offset  cache  opname                       oparg  argrepr
     0      2  RESUME                           0  
     2      4  NOP                           None  
     4      6  LOAD_SMALL_INT                   1  
     6      8  STORE_FAST                       0  value
     8     10  LOAD_SMALL_INT                   3  
    10     12  STORE_FAST                       1  finished
    12     14  LOAD_CONST                       1  None
    14     16  RETURN_VALUE                  None  
    16     18  PUSH_EXC_INFO                 None  
    18     20  LOAD_GLOBAL                      0  ValueError
    28     30  CHECK_EXC_MATCH               None  
    30     32  POP_JUMP_IF_FALSE                6  to L2
    34     36  NOT_TAKEN                     None  
    36     38  POP_TOP                       None  
    38     40  LOAD_SMALL_INT                   2  
    40     42  STORE_FAST                       0  value
    42     44  POP_EXCEPT                    None  
    44     46  JUMP_BACKWARD_NO_INTERRUPT      19  to L1
    46     48  RERAISE                          0  
    48     50  COPY                             3  
    50     52  POP_EXCEPT                    None  
    52     54  RERAISE                          1  
    54     56  PUSH_EXC_INFO                 None  
    56     58  LOAD_SMALL_INT                   3  
    58     60  STORE_FAST                       1  finished
    60     62  RERAISE                          0  
    62     64  COPY                             3  
    64     66  POP_EXCEPT                    None  
    66     68  RERAISE                          1  
```

### Exception entries

```text
start  end  target  depth  lasti
    4    8      16      0 False
   16   42      48      1 True
   42   46      54      0 False
   46   48      48      1 True
   48   54      54      0 False
   54   62      62      1 True
```

## `try_except_finally_raised_caught`

### Source

```python
def f():
    try:
        raise ValueError("body")
    except ValueError:
        handled = 1
    finally:
        finished = 2
```

### Code object

- `qualname`: `f`
- `co_flags`: `0x1000003`
- `co_stacksize`: `4`
- `co_code`: `80001b005c01000000000000000052003401000000000000680120005c0000000000000000000600640600001c001f005e0170001d004d0469003b031d0069011b005e0270015201230020005e02700169003b031d006901`
- `co_exceptiontable`: `820b0d008d0d1d039a0225009c011d039d032500a5042903`

### Instructions

```text
offset  cache  opname                       oparg  argrepr
     0      2  RESUME                           0  
     2      4  NOP                           None  
     4      6  LOAD_GLOBAL                      1  ValueError + NULL
    14     16  LOAD_CONST                       0  'body'
    16     18  CALL                             1  
    24     26  RAISE_VARARGS                    1  
    26     28  PUSH_EXC_INFO                 None  
    28     30  LOAD_GLOBAL                      0  ValueError
    38     40  CHECK_EXC_MATCH               None  
    40     42  POP_JUMP_IF_FALSE                6  to L1
    44     46  NOT_TAKEN                     None  
    46     48  POP_TOP                       None  
    48     50  LOAD_SMALL_INT                   1  
    50     52  STORE_FAST                       0  handled
    52     54  POP_EXCEPT                    None  
    54     56  JUMP_FORWARD                     4  to L2
    56     58  RERAISE                          0  
    58     60  COPY                             3  
    60     62  POP_EXCEPT                    None  
    62     64  RERAISE                          1  
    64     66  NOP                           None  
    66     68  LOAD_SMALL_INT                   2  
    68     70  STORE_FAST                       1  finished
    70     72  LOAD_CONST                       1  None
    72     74  RETURN_VALUE                  None  
    74     76  PUSH_EXC_INFO                 None  
    76     78  LOAD_SMALL_INT                   2  
    78     80  STORE_FAST                       1  finished
    80     82  RERAISE                          0  
    82     84  COPY                             3  
    84     86  POP_EXCEPT                    None  
    86     88  RERAISE                          1  
```

### Exception entries

```text
start  end  target  depth  lasti
    4   26      26      0 False
   26   52      58      1 True
   52   56      74      0 False
   56   58      58      1 True
   58   64      74      0 False
   74   82      82      1 True
```

## `try_except_finally_raised_unmatched`

### Source

```python
def f():
    try:
        raise KeyError("body")
    except ValueError:
        handled = 1
    finally:
        finished = 2
```

### Code object

- `qualname`: `f`
- `co_flags`: `0x1000003`
- `co_stacksize`: `4`
- `co_code`: `80001b005c01000000000000000052003401000000000000680120005c0200000000000000000600640600001c001f005e0170001d004d0469003b031d0069011b005e0270015201230020005e02700169003b031d006901`
- `co_exceptiontable`: `820b0d008d0d1d039a0225009c011d039d032500a5042903`

### Instructions

```text
offset  cache  opname                       oparg  argrepr
     0      2  RESUME                           0  
     2      4  NOP                           None  
     4      6  LOAD_GLOBAL                      1  KeyError + NULL
    14     16  LOAD_CONST                       0  'body'
    16     18  CALL                             1  
    24     26  RAISE_VARARGS                    1  
    26     28  PUSH_EXC_INFO                 None  
    28     30  LOAD_GLOBAL                      2  ValueError
    38     40  CHECK_EXC_MATCH               None  
    40     42  POP_JUMP_IF_FALSE                6  to L1
    44     46  NOT_TAKEN                     None  
    46     48  POP_TOP                       None  
    48     50  LOAD_SMALL_INT                   1  
    50     52  STORE_FAST                       0  handled
    52     54  POP_EXCEPT                    None  
    54     56  JUMP_FORWARD                     4  to L2
    56     58  RERAISE                          0  
    58     60  COPY                             3  
    60     62  POP_EXCEPT                    None  
    62     64  RERAISE                          1  
    64     66  NOP                           None  
    66     68  LOAD_SMALL_INT                   2  
    68     70  STORE_FAST                       1  finished
    70     72  LOAD_CONST                       1  None
    72     74  RETURN_VALUE                  None  
    74     76  PUSH_EXC_INFO                 None  
    76     78  LOAD_SMALL_INT                   2  
    78     80  STORE_FAST                       1  finished
    80     82  RERAISE                          0  
    82     84  COPY                             3  
    84     86  POP_EXCEPT                    None  
    86     88  RERAISE                          1  
```

### Exception entries

```text
start  end  target  depth  lasti
    4   26      26      0 False
   26   52      58      1 True
   52   56      74      0 False
   56   58      58      1 True
   58   64      74      0 False
   74   82      82      1 True
```

## `try_except_as_finally`

### Source

```python
def f():
    try:
        raise ValueError("body")
    except ValueError as error:
        handled = 1
    finally:
        finished = 2
```

### Code object

- `qualname`: `f`
- `co_flags`: `0x1000003`
- `co_stacksize`: `4`
- `co_code`: `80001b005c01000000000000000052003401000000000000680120005c0000000000000000000600640d00001c0070005e0170011d00520170003f004d08520170003f00690169003b031d0069011b005e0270025201230020005e02700269003b031d006901`
- `co_exceptiontable`: `820b0d008d0b240398021f039a052c009f052403a4032c00ac043003`

### Instructions

```text
offset  cache  opname                       oparg  argrepr
     0      2  RESUME                           0  
     2      4  NOP                           None  
     4      6  LOAD_GLOBAL                      1  ValueError + NULL
    14     16  LOAD_CONST                       0  'body'
    16     18  CALL                             1  
    24     26  RAISE_VARARGS                    1  
    26     28  PUSH_EXC_INFO                 None  
    28     30  LOAD_GLOBAL                      0  ValueError
    38     40  CHECK_EXC_MATCH               None  
    40     42  POP_JUMP_IF_FALSE               13  to L1
    44     46  NOT_TAKEN                     None  
    46     48  STORE_FAST                       0  error
    48     50  LOAD_SMALL_INT                   1  
    50     52  STORE_FAST                       1  handled
    52     54  POP_EXCEPT                    None  
    54     56  LOAD_CONST                       1  None
    56     58  STORE_FAST                       0  error
    58     60  DELETE_FAST                      0  error
    60     62  JUMP_FORWARD                     8  to L2
    62     64  LOAD_CONST                       1  None
    64     66  STORE_FAST                       0  error
    66     68  DELETE_FAST                      0  error
    68     70  RERAISE                          1  
    70     72  RERAISE                          0  
    72     74  COPY                             3  
    74     76  POP_EXCEPT                    None  
    76     78  RERAISE                          1  
    78     80  NOP                           None  
    80     82  LOAD_SMALL_INT                   2  
    82     84  STORE_FAST                       2  finished
    84     86  LOAD_CONST                       1  None
    86     88  RETURN_VALUE                  None  
    88     90  PUSH_EXC_INFO                 None  
    90     92  LOAD_SMALL_INT                   2  
    92     94  STORE_FAST                       2  finished
    94     96  RERAISE                          0  
    96     98  COPY                             3  
    98    100  POP_EXCEPT                    None  
   100    102  RERAISE                          1  
```

### Exception entries

```text
start  end  target  depth  lasti
    4   26      26      0 False
   26   48      72      1 True
   48   52      62      1 True
   52   62      88      0 False
   62   72      72      1 True
   72   78      88      0 False
   88   96      96      1 True
```

## `return_inside_try_finally`

### Source

```python
def f():
    try:
        return 7
    finally:
        finished = 1
```

### Code object

- `qualname`: `f`
- `co_flags`: `0x1000003`
- `co_stacksize`: `4`
- `co_code`: `80001b001b005e0170005e07230020005e01700069003b031d006901`
- `co_exceptiontable`: `87040b03`

### Instructions

```text
offset  cache  opname                       oparg  argrepr
     0      2  RESUME                           0  
     2      4  NOP                           None  
     4      6  NOP                           None  
     6      8  LOAD_SMALL_INT                   1  
     8     10  STORE_FAST                       0  finished
    10     12  LOAD_SMALL_INT                   7  
    12     14  RETURN_VALUE                  None  
    14     16  PUSH_EXC_INFO                 None  
    16     18  LOAD_SMALL_INT                   1  
    18     20  STORE_FAST                       0  finished
    20     22  RERAISE                          0  
    22     24  COPY                             3  
    24     26  POP_EXCEPT                    None  
    26     28  RERAISE                          1  
```

### Exception entries

```text
start  end  target  depth  lasti
   14   22      22      1 True
```

## `exception_inside_handler_finally`

### Source

```python
def f():
    try:
        raise ValueError("body")
    except ValueError:
        raise RuntimeError("handler")
    finally:
        finished = 1
```

### Code object

- `qualname`: `f`
- `co_flags`: `0x1000003`
- `co_stacksize`: `4`
- `co_code`: `80001b005c01000000000000000052003401000000000000680120005c0000000000000000000600640d00001c001f005c03000000000000000052013401000000000000680169003b031d00690120005e01700069003b031d006901`
- `co_exceptiontable`: `820b0d008d172403a4032700a7042b03`

### Instructions

```text
offset  cache  opname                       oparg  argrepr
     0      2  RESUME                           0  
     2      4  NOP                           None  
     4      6  LOAD_GLOBAL                      1  ValueError + NULL
    14     16  LOAD_CONST                       0  'body'
    16     18  CALL                             1  
    24     26  RAISE_VARARGS                    1  
    26     28  PUSH_EXC_INFO                 None  
    28     30  LOAD_GLOBAL                      0  ValueError
    38     40  CHECK_EXC_MATCH               None  
    40     42  POP_JUMP_IF_FALSE               13  to L1
    44     46  NOT_TAKEN                     None  
    46     48  POP_TOP                       None  
    48     50  LOAD_GLOBAL                      3  RuntimeError + NULL
    58     60  LOAD_CONST                       1  'handler'
    60     62  CALL                             1  
    68     70  RAISE_VARARGS                    1  
    70     72  RERAISE                          0  
    72     74  COPY                             3  
    74     76  POP_EXCEPT                    None  
    76     78  RERAISE                          1  
    78     80  PUSH_EXC_INFO                 None  
    80     82  LOAD_SMALL_INT                   1  
    82     84  STORE_FAST                       0  finished
    84     86  RERAISE                          0  
    86     88  COPY                             3  
    88     90  POP_EXCEPT                    None  
    90     92  RERAISE                          1  
```

### Exception entries

```text
start  end  target  depth  lasti
    4   26      26      0 False
   26   72      72      1 True
   72   78      78      0 False
   78   86      86      1 True
```

## `nested_try_except_finally`

### Source

```python
def f():
    try:
        try:
            value = 1
        except ValueError:
            value = 2
        finally:
            inner_finished = 3
    except KeyError:
        outer_handled = 4
    finally:
        outer_finished = 5
```

### Code object

- `qualname`: `f`
- `co_flags`: `0x1000003`
- `co_stacksize`: `4`
- `co_code`: `80001b001b005e0170005e0370015e0570035201230020005c0000000000000000000600640600001c001f005e0270001d004c1569003b031d00690120005e03700169003b031d00690120005c0200000000000000000600640600001c001f005e0470021d004c2d69003b031d00690120005e05700369003b031d006901`
- `co_exceptiontable`: `83020b00850225008b0d1b0398021e009a011b039b031e009e042203a2032500a50d3503b2023800b4013503b5033800b8043c03`

### Instructions

```text
offset  cache  opname                       oparg  argrepr
     0      2  RESUME                           0  
     2      4  NOP                           None  
     4      6  NOP                           None  
     6      8  LOAD_SMALL_INT                   1  
     8     10  STORE_FAST                       0  value
    10     12  LOAD_SMALL_INT                   3  
    12     14  STORE_FAST                       1  inner_finished
    14     16  LOAD_SMALL_INT                   5  
    16     18  STORE_FAST                       3  outer_finished
    18     20  LOAD_CONST                       1  None
    20     22  RETURN_VALUE                  None  
    22     24  PUSH_EXC_INFO                 None  
    24     26  LOAD_GLOBAL                      0  ValueError
    34     36  CHECK_EXC_MATCH               None  
    36     38  POP_JUMP_IF_FALSE                6  to L3
    40     42  NOT_TAKEN                     None  
    42     44  POP_TOP                       None  
    44     46  LOAD_SMALL_INT                   2  
    46     48  STORE_FAST                       0  value
    48     50  POP_EXCEPT                    None  
    50     52  JUMP_BACKWARD_NO_INTERRUPT      21  to L1
    52     54  RERAISE                          0  
    54     56  COPY                             3  
    56     58  POP_EXCEPT                    None  
    58     60  RERAISE                          1  
    60     62  PUSH_EXC_INFO                 None  
    62     64  LOAD_SMALL_INT                   3  
    64     66  STORE_FAST                       1  inner_finished
    66     68  RERAISE                          0  
    68     70  COPY                             3  
    70     72  POP_EXCEPT                    None  
    72     74  RERAISE                          1  
    74     76  PUSH_EXC_INFO                 None  
    76     78  LOAD_GLOBAL                      2  KeyError
    86     88  CHECK_EXC_MATCH               None  
    88     90  POP_JUMP_IF_FALSE                6  to L4
    92     94  NOT_TAKEN                     None  
    94     96  POP_TOP                       None  
    96     98  LOAD_SMALL_INT                   4  
    98    100  STORE_FAST                       2  outer_handled
   100    102  POP_EXCEPT                    None  
   102    104  JUMP_BACKWARD_NO_INTERRUPT      45  to L2
   104    106  RERAISE                          0  
   106    108  COPY                             3  
   108    110  POP_EXCEPT                    None  
   110    112  RERAISE                          1  
   112    114  PUSH_EXC_INFO                 None  
   114    116  LOAD_SMALL_INT                   5  
   116    118  STORE_FAST                       3  outer_finished
   118    120  RERAISE                          0  
   120    122  COPY                             3  
   122    124  POP_EXCEPT                    None  
   124    126  RERAISE                          1  
```

### Exception entries

```text
start  end  target  depth  lasti
    6   10      22      0 False
   10   14      74      0 False
   22   48      54      1 True
   48   52      60      0 False
   52   54      54      1 True
   54   60      60      0 False
   60   68      68      1 True
   68   74      74      0 False
   74  100     106      1 True
  100  104     112      0 False
  104  106     106      1 True
  106  112     112      0 False
  112  120     120      1 True
```

## `try_finally_loop_break_continue`

### Source

```python
def f(items):
    total = 0
    for item in items:
        try:
            if item == 0:
                break
            if item < 0:
                continue
            total += item
        finally:
            cleaned = item
    return total
```

### Code object

- `qualname`: `f`
- `co_flags`: `0x1000003`
- `co_stacksize`: `5`
- `co_code`: `80005e007001560010004627000070021b0056025e0038580000640700001c001b00540270031f005601230056025e0038120000640600001c001b00540270034b1d000057122c0d000000000000000000007001540270034b29000009001e005601230020005402700369003b031d006901`
- `co_exceptiontable`: `8907320296073202a2083202b2043605`

### Instructions

```text
offset  cache  opname                       oparg  argrepr
     0      2  RESUME                           0  
     2      4  LOAD_SMALL_INT                   0  
     4      6  STORE_FAST                       1  total
     6      8  LOAD_FAST_BORROW                 0  items
     8     10  GET_ITER                      None  
    10     12  FOR_ITER                        39  to L4
    14     16  STORE_FAST                       2  item
    16     18  NOP                           None  
    18     20  LOAD_FAST_BORROW                 2  item
    20     22  LOAD_SMALL_INT                   0  
    22     24  COMPARE_OP                      88  bool(==)
    26     28  POP_JUMP_IF_FALSE                7  to L2
    30     32  NOT_TAKEN                     None  
    32     34  NOP                           None  
    34     36  LOAD_FAST                        2  item
    36     38  STORE_FAST                       3  cleaned
    38     40  POP_TOP                       None  
    40     42  LOAD_FAST_BORROW                 1  total
    42     44  RETURN_VALUE                  None  
    44     46  LOAD_FAST_BORROW                 2  item
    46     48  LOAD_SMALL_INT                   0  
    48     50  COMPARE_OP                      18  bool(<)
    52     54  POP_JUMP_IF_FALSE                6  to L3
    56     58  NOT_TAKEN                     None  
    58     60  NOP                           None  
    60     62  LOAD_FAST                        2  item
    62     64  STORE_FAST                       3  cleaned
    64     66  JUMP_BACKWARD                   29  to L1
    68     70  LOAD_FAST_BORROW_LOAD_FAST_BORROW    18  total, item
    70     72  BINARY_OP                       13  +=
    82     84  STORE_FAST                       1  total
    84     86  LOAD_FAST                        2  item
    86     88  STORE_FAST                       3  cleaned
    88     90  JUMP_BACKWARD                   41  to L1
    92     94  END_FOR                       None  
    94     96  POP_ITER                      None  
    96     98  LOAD_FAST_BORROW                 1  total
    98    100  RETURN_VALUE                  None  
   100    102  PUSH_EXC_INFO                 None  
   102    104  LOAD_FAST                        2  item
   104    106  STORE_FAST                       3  cleaned
   106    108  RERAISE                          0  
   108    110  COPY                             3  
   110    112  POP_EXCEPT                    None  
   112    114  RERAISE                          1  
```

### Exception entries

```text
start  end  target  depth  lasti
   18   32     100      1 False
   44   58     100      1 False
   68   84     100      1 False
  100  108     108      2 True
```
