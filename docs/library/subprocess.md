---
description: The native subprocess module: running child processes with run, Popen and the check functions, and where it differs from CPython's.
keywords: subprocess, subprocess.getoutput, subprocess.getstatusoutput, Popen.send_signal, subprocess.run, subprocess.Popen, subprocess.call, subprocess.check_call, subprocess.check_output, subprocess.CompletedProcess, subprocess.CalledProcessError, subprocess.TimeoutExpired, subprocess.SubprocessError, subprocess.PIPE, subprocess.STDOUT, subprocess.DEVNULL, subprocess.list2cmdline, Popen.communicate, Popen.wait, Popen.poll, Popen.kill, Popen.terminate
---
# subprocess

`import subprocess` in a native program loads jac's own `subprocess`, written in Jac over the
operating system's process interface (`posix_spawn` on POSIX systems, `CreateProcess` on
Windows): `run`, `Popen`, `call`, `check_call`, `check_output`, `getoutput` and
`getstatusoutput`, with CPython's parameters and results. It is not CPython's module: see
[The library](index.md) (`jac docs library`).

```jac
import subprocess;

with entry {
    cp = subprocess.run(["echo", "hello"], capture_output=True, text=True);
    out: str = cp.stdout;
    print(cp.args, cp.returncode, repr(out));
    raw: bytes = subprocess.run(["printf", "%s-%s", "a", "b"], capture_output=True).stdout;
    print(raw);
    fed = subprocess.run(["cat"], input="one\ntwo\n", capture_output=True, text=True);
    lines: str = fed.stdout;
    print(lines.splitlines());
    print(subprocess.run(["sh", "-c", "exit 3"]).returncode);
}
```

```output
['echo', 'hello'] 0 'hello\n'
b'a-b'
['one', 'two']
3
```

## What is there

| Name | What it is |
|---|---|
| `run(args, capture_output, text, check, input, timeout, cwd, env, shell, stdin, stdout, stderr, encoding, errors, ...)` | Runs a command, waits for it, returns a `CompletedProcess`; it takes every parameter of `Popen` |
| `call(args, timeout, cwd, env, shell)` | Runs a command and returns its exit status |
| `check_call(...)` | As `call`, raising `CalledProcessError` for a nonzero status |
| `check_output(args, input, stderr, text, timeout, ...)` | Runs a command and returns its standard output; `CalledProcessError` for a nonzero status |
| `getoutput(cmd)`, `getstatusoutput(cmd)` | Runs a shell command and returns its output and error, without the last newline; with its exit status |
| `Popen(args, bufsize, executable, stdin, stdout, stderr, preexec_fn, close_fds, shell, cwd, env, text, encoding, errors, pass_fds, start_new_session, user, group, umask, ...)` | A child process started and left running: `pid`, `returncode`, `stdin`, `stdout`, `stderr` (file objects for a `PIPE`), `poll()`, `wait(timeout)`, `communicate(input, timeout)`, `send_signal()`, `kill()`, `terminate()`, and `with` |
| `CompletedProcess` | `args`, `returncode`, `stdout`, `stderr`, `check_returncode()` |
| `PIPE`, `STDOUT`, `DEVNULL` | What a stream argument may be, besides an open file descriptor |
| `SubprocessError`, `CalledProcessError`, `TimeoutExpired` | The module's exceptions; the last two carry `cmd`, `output`, `stdout`, `stderr`, and `returncode` or `timeout` |
| `list2cmdline(seq)` | The Windows command line that runs `seq`, quoted as CPython quotes it |

What the arguments mean is CPython's:

- `args` is a list of strs, or one str with `shell=True` (run by `/bin/sh -c`, or `cmd.exe` on
  Windows).
- Standard output and error are `None` in the result unless captured: `capture_output=True`,
  or `stdout=PIPE` and `stderr=PIPE`. `stderr=STDOUT` merges the error stream into the output;
  `DEVNULL` discards it.
- `stdin`, `stdout` and `stderr` may also be an open file or its descriptor (`f.fileno()`); a
  descriptor that is not open raises `OSError` (errno 9).
- Captured output is `bytes`, or with `text=True` (or an `encoding` or `errors`) a str decoded
  with universal newlines (`"\r\n"` read as `"\n"`). `input` is given to the child's standard input: bytes, or a
  str with `text=True`.
- `env` replaces the child's environment; without it the child inherits the program's,
  including changes made through [`os.environ`](os.md). On POSIX the program is looked up on
  the `PATH` of `env` when it is given, and a relative program path is taken in `cwd`.
- `check=True` raises `CalledProcessError` for a nonzero exit status, and `timeout` (seconds)
  raises `TimeoutExpired` after killing the child.
- A child killed by a signal has the negative signal number as its `returncode` (`-15` for
  `SIGTERM`, `-9` for `SIGKILL`).

## Popen

`Popen` starts the child and returns at once. Talk to it with `communicate`, which writes
`input` to its standard input, reads its output and error to the end, waits, and returns the
pair (each `None` unless it was a `PIPE`), or through its `stdin` and `stdout`, which are file
objects for a `PIPE`. A `Popen` is a context manager that closes them and waits.

```jac
import subprocess;

with entry {
    p = subprocess.Popen(["cat"], stdin=subprocess.PIPE, stdout=subprocess.PIPE);
    (out, err) = p.communicate(b"piped bytes");
    print(out, err, p.returncode);
    q = subprocess.Popen(["sleep", "10"]);
    print(q.poll());
    q.terminate();
    print(q.wait());
}
```

```output
b'piped bytes' None 0
None
-15
```

```jac
import subprocess;

with entry {
    r = subprocess.run(["echo", "héllo"], capture_output=True, encoding="utf-8");
    print(repr(r.stdout), r.returncode);
    print(subprocess.getoutput("echo out; echo err 1>&2"), subprocess.getstatusoutput("exit 3"));
    p = subprocess.Popen(["cat"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True);
    (out, err) = p.communicate("to cat\n");
    print(repr(out), err, p.returncode);
    p2 = subprocess.Popen(
        ["sh", "-c", "read x; echo got $x"], stdin=subprocess.PIPE, stdout=subprocess.PIPE
    );
    p2.stdin.write(b"line\n");
    p2.stdin.close();
    print(p2.stdout.read(), p2.wait());
    with subprocess.Popen(["echo", "in a with"], stdout=subprocess.PIPE) as p3 {
        print(p3.stdout.read(), p3.wait());
    }
}
```

```output
'héllo\n' 0
out
err (3, '')
'to cat\n' None 0
b'got line\n' 0
b'in a with\n' 0
```

## Errors

```jac
import subprocess;

with entry {
    try {
        subprocess.run(["sh", "-c", "echo oops >&2; exit 2"], check=True, capture_output=True);
    } except subprocess.CalledProcessError as e {
        print(e.returncode, e.cmd, e.stderr);
        print(e);
    }
    try {
        subprocess.run(["sleep", "5"], timeout=0.2);
    } except subprocess.TimeoutExpired as e {
        print(e.timeout, e);
    }
    try {
        subprocess.run(["no-such-command-here"]);
    } except FileNotFoundError as e {
        print(e.errno, e.filename, e);
    }
}
```

```output
2 ['sh', '-c', 'echo oops >&2; exit 2'] b'oops\n'
Command ['sh', '-c', 'echo oops >&2; exit 2'] returned non-zero exit status 2.
0.2 Command '['sleep', '5']' timed out after 0.2 seconds
2 no-such-command-here [Errno 2] No such file or directory: 'no-such-command-here'
```

A `CalledProcessError` and a `TimeoutExpired` print as CPython's do, and a `CalledProcessError`
for a child a signal killed names the signal: `Command '['sleep', '10']' died with
<Signals.SIGTERM: 15>.`

A program that is not found raises `FileNotFoundError`; on POSIX a file found that cannot be run
raises `PermissionError`. On POSIX each has its `errno` (2, 13) and, as `filename`, the program
as it was given.

## Differences from CPython

- **The results' output fields are typed `any`**: `stdout` and `stderr` are `bytes`, `str` or
  `None` depending on the arguments. Narrow them by assigning to a typed variable before using
  them as one (`out: str = cp.stdout;`), as the examples do.
- **`args` is a str or a `list[str]`**; a tuple is refused (E1053).
- **`env` is a `dict[str, str]`**: pass `os.environ.copy()` rather than `os.environ` (E1053).
- **On Windows** the names only CPython's Windows build has (the `STARTUPINFO` class, the
  `STARTF_*` and `SW_*` constants and the priority classes) are not written yet.

## Platforms

On Windows `Popen` creates the child with `CreateProcess`, building its command line from a
list with `list2cmdline`, and `shell=True` runs the command with `%COMSPEC%` (`cmd.exe`). A
negative `returncode` for a child killed by a signal is POSIX's; see [signal](stdlib.md) for
the signals each platform has.

## Related

- [os](os.md) for the environment, [sys](sys.md) for the program's own command line and exit
  status.
- Child processes whose streams coroutines read and write, `asyncio.create_subprocess_exec`:
  [asyncio](asyncio.md#subprocesses-and-signals).
- Every native module: [Standard-library modules](stdlib.md).
