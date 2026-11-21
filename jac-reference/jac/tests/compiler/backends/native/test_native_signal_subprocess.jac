"""The bundled `signal` / `subprocess` modules must answer what CPython answers.

`import signal` and `import subprocess` bind CPython's modules on the sv
pathway and `na_stdlib/signal.linux.jac` / `na_stdlib/subprocess.linux.jac` on
the na pathway, so running one fixture through both and demanding identical
output *is* the congruence contract -- CPython is the oracle, not a
hand-copied expectation table.

`signal_probe.jac` exercises handler install/dispatch through the C-ABI
trampoline (which delivers `(signum, None)` where CPython delivers
`(signum, frame)` -- only the signum is printed), the `SIG_IGN` / `SIG_DFL`
sentinel handlers, `getsignal` shadow lookup, `strsignal`, `alarm`,
`valid_signals`, and `pthread_sigmask` blocking with pending delivery on
unblock.

`subprocess_probe.jac` exercises `run` over list and str args, `shell=True`,
stdout/stderr capture, `stderr=STDOUT` merge, `env` replacement, `cwd`,
`DEVNULL`, `call` / `check_call` / `check_output`, `CalledProcessError`,
`CompletedProcess.check_returncode`, `TimeoutExpired`, and a `Popen`
terminated with SIGTERM (returncode -15 on both lanes). The na
implementation spawns the child through `posix_spawnp` with file actions.
"""

import from tests.support { na_run, same_lines, sv_run }

import os;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "native signal answers what CPython's signal answers" {
    (sv_out, _sv_err) = sv_run(os.path.join(FIXTURES, "signal_probe.jac"));
    (na_out, _na_err) = na_run(os.path.join(FIXTURES, "signal_probe.jac"));
    same_lines(sv_out, na_out, "signal");
}

test "native subprocess answers what CPython's subprocess answers" {
    (sv_out, _sv_err) = sv_run(os.path.join(FIXTURES, "subprocess_probe.jac"));
    (na_out, _na_err) = na_run(os.path.join(FIXTURES, "subprocess_probe.jac"));
    same_lines(sv_out, na_out, "subprocess");
}
