# Compiler walkers

Constructing a compiler walker allocates its state. Execution starts with
`module spawn walk`. There is no constructor-triggered pass lifecycle.

- Plain walkers use typed entry abilities for operations on a module.
- Walkers inheriting `TreeWalker` receive the structural child traversal supplied
  by `UniNode.walk_kids`. Their node entry and exit guards delegate to the context
  so cancellation and compile-time pruning suppress subsequent handlers.
- Generic `can prepare with entry` and `can finish with exit` abilities surround
  a traversal. Constructors initialize fields; entry abilities activate temporary
  compilation state such as the evaluator’s diagnostic binding.
- `CompileContext` owns diagnostics, diagnostic policy, cancellation, temporary
  resource cleanup, and the current source node used by lowering helpers.
  Algorithm state belongs to the walker. The `module` field identifies the root;
  the Python AST loader replaces it with the converted Jac module. Generated
  backend products remain on `module.gen`.

The driver calls `run_walker` to construct and spawn a walker within a timed
resource scope. It separately owns schedule validation, analysis facts, cached
results, completion tracking, and delivery of diagnostics. Standalone callers
can use `run_walker` without a program or construct and spawn a walker directly.
Callers using temporary resources supply `resources=ExitStack()` when creating
the context and enclose direct spawning in `with ctx.resources` so cleanup also
runs on exceptions. The execution helper supplies this Python resource scope;
native compiler walkers leave it unset.

Type checking and Python code generation sometimes synchronously traverse an
attached implementation with the same walker. They use `ctx.walk_subtree` to
preserve algorithm state and suppress whole-walk lifecycle abilities during
that nested spawn. Lifecycle abilities check `ctx.nested_depth` for this reason.
