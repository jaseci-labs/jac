# Native evaluator migration

Status: design and investigation. The shipped evaluator is still CPython C.
No evaluator source may be excluded on the strength of this document or of
compiler-bridge tests alone.

## Implementation contract

Port the pinned CPython evaluator's behavior into native Jac, using existing
compiler ownership, layout, error-lowering, and LLVM infrastructure. The
evaluator must introduce no Jac reference counting or garbage collection in
dispatch. Preserve CPython reference counting, cycle collection, reference
stealing, finalizer timing, and stack-reference representation. Those are Python
semantics, not overhead that Jac borrowing can simply eliminate.

Ownership must describe the Python object behind a handle. Annotating an integer
address does not establish that object's lifetime. A small trusted ABI boundary
must connect typed owners and borrows to CPython operations. Its contracts must
cover calls and decrefs that can execute Python, frame clearing, exception
unwinding, and suspension. Borrowed frame references cannot silently become
heap-safe references when a generator suspends.

Use the pinned build's actual stack-reference representation. In particular,
the ordinary GIL build's null stack reference is not integer zero, and a tagged
reference is not necessarily immortal. Debug and free-threaded representations
need explicit support or explicit build-time rejection; treating all variants
as an untagged object pointer is invalid.

## Dispatch prerequisite

The release baseline uses CPython's tail-call interpreter. Jac dispatch needs a
checked guarantee of bounded native stack usage, including indirect transitions
between opcode handlers. Successful optimization of one recursive function is
insufficient.

Ordinary native Jac calls currently insert a slot-based exception check after
the call. Return lowering also runs finalizers and ownership cleanup. Neither
may be discarded simply to put an LLVM `musttail` immediately before `ret`.

An ARM64 investigation of two scalar functions returning calls to each other
confirmed stack-growing calls and post-call exception-context checks even after
compiling the emitted IR with Clang `-O3`. This is evidence of the current
lowering constraint, not a comparison against a completed Jac evaluator.

The existing `Ability.raises` facts are insufficient to prove a function cannot
raise: `_local_raises` currently gathers explicit raises and resolved callees'
effects. Native checked arithmetic can also raise. Do not use an empty effects
list as permission to suppress exception checks.

Before adopting a tail-transfer contract, specify and test:

- Matching calling conventions, return types, argument layouts, and ABI
  attributes, including indirect calls and cross-module declarations.
- Exception-slot propagation and the returned value's meaning when an error is
  pending. Active handlers and finalizers must retain their behavior.
- Pending local, temporary, region, closure, and owned-parameter cleanup.
- Frame-local addresses and borrows that cannot survive destruction of the
  caller's native frame.
- Compile-time rejection when a requested guarantee cannot be met.
- Verified LLVM IR, emitted ARM64 and x86-64 code, and execution under a small
  stack limit across many handler transitions.

## Porting and generation

Use CPython's instruction definitions and generation structure as the source of
opcode families and metadata. Preserve specialization, instrumentation, cache
layout, monitoring, and error paths as part of each handler's contract. Account
for tier-two configuration explicitly rather than silently disabling it to make
a tier-one port compile.

Historical c2jac code is available before commit `8cc1a5e980`. Assess recovery in
an isolated checkout. Useful pieces include diagnostics, translation provenance,
unsupported-function quarantine, and differential tests. Its historical switch
lowering constructs conditional branches, some goto transformations introduce
exceptions, and its lift oracle runs interpreted Jac. Consequently, its output
is neither a native performance guarantee nor an ownership proof.

Reuse faithful translations of suitable helpers after the native ownership and
dispatch contracts exist. Any retained generator must be deterministic, reject
unsupported input, preserve source attribution and licensing, and have one
maintained location. Do not restore vendored parsers and compiler passes merely
to obtain a one-time translation.

## Source retirement gates

Paths below refer to the pinned CPython archive. Commenting an allowlist entry
does not itself replace symbols, eliminate make prerequisites, or prove that an
old object is absent from a cached archive.

| Source | Condition for retirement |
| --- | --- |
| `Python/ceval.c` | Replace the evaluator and every retained caller's required entry point and helper, including frame setup, argument binding, recursion handling, and evaluation APIs. |
| `Python/generated_cases.c.h` | Replace all enabled tier-one handlers and their specialization, instrumentation, error, and cache behavior. |
| `Python/ceval_macros.h` | Eliminate its use by every retained translation unit and generator output. |
| `Python/opcode_targets.h` | Replace the dispatch table and its build dependencies. |
| `Python/bytecodes.c` | Retire only if no retained metadata or executor generation needs its instruction definitions. Keeping it as generation input may be the correct design. |
| `Python/executor_cases.c.h` | Replace the enabled tier-two executor, or make any configuration change an explicit, measured design decision. |

Keep CPython object, frame, thread, GIL, and collector infrastructure required by
the Python ABI. Do not broaden this migration into replacing the object runtime
merely to increase the number of commented entries.

For each actual exclusion, update source prerequisites, includes, archive
membership, and cache inputs together. Validate a clean build as well as cache
reuse. Preserve the separate full CPython bootstrap host where required.

## Completion evidence

Use `scripts/run_cpython_compiler_tests.jac --execution-tests` and
`scripts/python_evaluator_bench.py` rather than introducing duplicate runners.
Expand their coverage where necessary. The small benchmark corpus is a screen,
not sufficient evidence of performance parity across the Python workload space.

The completed candidate must demonstrate native evaluator provenance independently
of the compiler bridge, with no fallback to the retired evaluator. Verify the
source/object exclusions in the produced runtime, execute upstream evaluator
coverage and targeted ownership/reentrancy tests, and measure identical bytecode
against the pinned tail-call baseline with matching build flags and hardware.

Validate all supported build configurations and release targets, including
startup, imports, embedding entry points, exceptions, generators, coroutines,
tracing/monitoring, specialization, and extension callbacks. Run the applicable
CI jobs explicitly; a target deferred to nightly CI is not covered merely by
green pull-request checks. Keep the migration draft until these gates pass.
