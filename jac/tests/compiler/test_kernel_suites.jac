"""The kernel's own test suites, one host test per case.

Compiler internals tests (the tree, symbol tables, pass outputs, the MIR
decision step) are compiled into the kernel (`compiler/kernel_tests/`, listed
by `compiler/kernel_testing.jac`) and run there natively, against the
compiler's own objects. This file asks the loaded kernel for its cases and
runs each one through `jac_kernel.run_tests`; a failure carries the message
the case raised inside the kernel. Editing a suite makes the development
kernel stale, so `jac native build kernel` comes first, as for any compiler
source."""
import from jaclang.testing.test { parametrize }
import from tests.support { kernel_cases, run_kernel_case }

with entry {
    parametrize(
        "kernel",
        kernel_cases(),
        run_kernel_case,
        id_fn=lambda (case: any) { f"{case.suite}: {case.name}"; }
    );
}
