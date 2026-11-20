---
description: The builtin exception classes, their hierarchy and fields, and where they differ from Python's.
keywords: builtin exceptions, BaseException, Exception, ArithmeticError, OverflowError, ZeroDivisionError, FloatingPointError, AssertionError, AttributeError, BufferError, EOFError, ImportError, ModuleNotFoundError, LookupError, IndexError, KeyError, MemoryError, NameError, UnboundLocalError, OSError, BlockingIOError, ChildProcessError, ConnectionError, BrokenPipeError, ConnectionAbortedError, ConnectionRefusedError, ConnectionResetError, FileExistsError, FileNotFoundError, InterruptedError, IsADirectoryError, NotADirectoryError, PermissionError, ProcessLookupError, TimeoutError, ReferenceError, RuntimeError, NotImplementedError, RecursionError, StopIteration, StopAsyncIteration, SyntaxError, IndentationError, TabError, SystemError, TypeError, ValueError, UnicodeError, UnicodeDecodeError, UnicodeEncodeError, UnicodeTranslateError, ExceptionGroup, SystemExit, KeyboardInterrupt, GeneratorExit, Warning, UserWarning, DeprecationWarning
---
# Builtin exceptions

The exception classes of Python's `builtins` exist in every module without an import, with
Python's names and Python's hierarchy. The runtime and the standard library raise them with
CPython's messages: `int("x")` raises `ValueError: invalid literal for int() with base 10: 'x'`.

## The hierarchy

```text
BaseException
├── SystemExit
├── KeyboardInterrupt
├── GeneratorExit
└── Exception
    ├── ArithmeticError
    │   ├── OverflowError
    │   ├── ZeroDivisionError
    │   └── FloatingPointError
    ├── AssertionError
    ├── AttributeError
    ├── BufferError
    ├── EOFError
    ├── ExceptionGroup
    ├── ImportError
    │   └── ModuleNotFoundError
    ├── LookupError
    │   ├── IndexError
    │   └── KeyError
    ├── MemoryError
    ├── NameError
    │   └── UnboundLocalError
    ├── OSError
    │   ├── BlockingIOError
    │   ├── ChildProcessError
    │   ├── ConnectionError
    │   │   ├── BrokenPipeError
    │   │   ├── ConnectionAbortedError
    │   │   ├── ConnectionRefusedError
    │   │   └── ConnectionResetError
    │   ├── FileExistsError
    │   ├── FileNotFoundError
    │   ├── InterruptedError
    │   ├── IsADirectoryError
    │   ├── NotADirectoryError
    │   ├── PermissionError
    │   ├── ProcessLookupError
    │   └── TimeoutError
    ├── ReferenceError
    ├── RuntimeError
    │   ├── NotImplementedError
    │   └── RecursionError
    ├── StopIteration
    ├── StopAsyncIteration
    ├── SyntaxError
    │   └── IndentationError
    │       └── TabError
    ├── SystemError
    ├── TypeError
    ├── ValueError
    │   └── UnicodeError
    │       ├── UnicodeDecodeError
    │       ├── UnicodeEncodeError
    │       └── UnicodeTranslateError
    └── Warning
        ├── BytesWarning, DeprecationWarning, EncodingWarning, FutureWarning
        ├── ImportWarning, PendingDeprecationWarning, ResourceWarning
        └── RuntimeWarning, SyntaxWarning, UnicodeWarning, UserWarning
```

## What an exception holds

| Member | What it is |
|---|---|
| `str(e)` | Its message: the one argument it was made with, or the tuple of them for several. A `KeyError` shows its key's `repr` |
| `e.args` | The arguments it was made with, as a tuple |
| `repr(e)` | `ValueError('bad input')` |
| `e.__cause__` | The exception named by `raise ... from`, else `None` |
| `e.__traceback__` | The calls it has passed through, outermost first, as CPython's traceback objects: each has its line (`tb_lineno`), its function's name and file (`tb_frame.f_code.co_name`, `co_filename`), and in `tb_next` the call it made, `None` for the one that raised. `None` before it is raised |
| `OSError`: `errno`, `strerror`, `filename`, `filename2` | Set when it is made with two to five arguments, as in CPython. Its message is then `[Errno 2] No such file or directory: 'f.txt'` |
| `StopIteration.value` | Its one argument |
| `SystemExit.code` | Its one argument: the exit status |
| `ExceptionGroup`: `message`, `exceptions` | Made as `ExceptionGroup(message, [e1, e2])` |

An exception that nothing catches ends the program with status 1, after its traceback is
written to standard error in CPython's form:

```text
Traceback (most recent call last):
  File "main.jac", line 3, in <module>
    raise ValueError("uncaught");
ValueError: uncaught
```

## Defining and catching

An exception class is an `obj` that derives from `Exception`. How it is made depends on what
it declares:

- **No fields and no `init`**: it is made as `Exception` is, `AppError("message")`, and `args`
  holds what it was made with.
- **Fields and no `init`**: the positional arguments bind to the fields in order, as for any
  `obj`, and `args` is the tuple of them. For `obj Coded(Exception) { has code: int = 0; }`,
  `Coded(5).code` is `5`, `args` is `(5,)` and `str()` is `5`. (In Python the field would keep
  its default.)
- **An `init`**: `args` is what it passes to `super.init(...)`; an `init` that does not call it
  gets every argument it was made with as `args`.

```jac
obj AppError(Exception) {}

obj LimitError(AppError) {
    has limit: int = 0;

    def init(message: str, limit: int) {
        super.init(message);
        self.limit = limit;
    }
}

def load(name: str) -> str {
    if name == "" {
        raise AppError("no name given");
    }
    try {
        return open(name).read();
    } except OSError as e {
        raise LimitError(f"cannot load {name}", 3) from e;
    }
}

with entry {
    try {
        load("");
    } except AppError as e {
        print(type(e).__name__, e, e.args, repr(e));
        tb = e.__traceback__.tb_next;
        print("raised at line", tb.tb_lineno, "of", tb.tb_frame.f_code.co_name);
    }
    try {
        load("nowhere.txt");
    } except LimitError as e {
        print(e, e.limit, isinstance(e, AppError), type(e.__cause__).__name__);
    }
    try {
        open("nowhere.txt");
    } except OSError as e {
        print(type(e).__name__, e.errno, e.strerror, e.filename);
    }
    try {
        print([1, 2][5]);
    } except (KeyError, IndexError) as e {
        print("lookup failed:", e);
    } finally {
        print("done");
    }
}
```

```output
AppError no name given ('no name given',) AppError('no name given')
raised at line 14 of load
cannot load nowhere.txt 3 True FileNotFoundError
FileNotFoundError 2 No such file or directory nowhere.txt
lookup failed: list index out of range
done
```

## Where they differ from Python

- **`OSError(errno, text)` made by a program is an `OSError`**, not the subclass for that
  error number. In Python `OSError(2, "x")` is a `FileNotFoundError`. The runtime and the
  library raise the right subclass themselves; raise the subclass by name when you need it.
- **`IOError`, `EnvironmentError` and `WindowsError` do not exist** (W2001). They are aliases of
  `OSError` in Python: write `OSError`.
- **`BaseExceptionGroup` and `PythonFinalizationError` do not exist.**
- **`SyntaxError`, `IndentationError` and `TabError` are raised by libraries only**, for
  malformed input of their own (`xml.etree.ElementTree.ParseError` is a `SyntaxError`), with
  CPython's attributes (`msg`, `filename`, `lineno`, `offset`, `text`, `end_lineno`,
  `end_offset`) and message. A Jac program is compiled before it runs, so the language has no
  syntax errors left to raise.
- **`add_note`, `__notes__`, `__context__` and `with_traceback` are not members** (E1030).
  `__cause__` and `__traceback__` are. A traceback holds what the table above lists, and a frame
  only its code's name and file: there is no `tb_lasti`, and no `f_locals` or `f_back`.
- **The `Warning` classes are plain exception classes.** Nothing issues warnings: there is no
  native `warnings` module, so a library call that warns under CPython is silent here.
- **Errors Python reports as the program runs are often compile errors here.** A call with an
  argument of the wrong static type, or a name that does not exist, does not compile; the
  `TypeError` or `NameError` is raised only where the type is not known until the program runs
  (a value typed `any`).

## Where to go next

- Raising and handling: `jac docs try` and `jac docs raise`.
- Ending the program: `sys.exit`, in [sys](sys.md).
- The functions that raise these: [Builtin functions](builtins.md).
