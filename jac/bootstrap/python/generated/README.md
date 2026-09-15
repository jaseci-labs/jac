# Generated evaluator source

`generate_evaluator.py` is the maintained source translator. It uses the pinned
CPython analyzer and tier-one/tier-two stack generators, then moves their
branches, loops, dispatch, and error transitions into native Jac. C files here
contain ABI expressions over typed storage. Their LLVM IR is linked with the
native module before optimization; the build rejects surviving adapter calls.

Regenerate from an unmodified extraction of the pinned source archive:

```sh
python3 jac/bootstrap/python/generate_evaluator.py /path/to/Python-3.14.6 /tmp/jac-evaluator-generated
cp /tmp/jac-evaluator-generated/evaluator_handlers.jac /tmp/jac-evaluator-generated/evaluator_jit.jac jac/jaclang/runtime/python/
cp /tmp/jac-evaluator-generated/evaluator_scratch.h /tmp/jac-evaluator-generated/evaluator_tier1_abi.c /tmp/jac-evaluator-generated/evaluator_tier2_abi.c /tmp/jac-evaluator-generated/evaluator_jit_abi.c /tmp/jac-evaluator-generated/evaluator-generation.json jac/bootstrap/python/generated/
```

The manifest records input and output hashes and each adapted source operation.
The build compares the instruction definitions and upstream generator files in
the pristine allowlisted extraction with those inputs before compiling native
source or applying the bridge patch.
Native source comments show the corresponding operation beside its ABI call.
The activation owns the frame chain and in-flight references as a trusted
aggregate; this is not a claim that Jac checks each internal C slot separately.
Scratch retains the original reference representations and addresses across
native tail transfers. Do not clear or decref its fields indiscriminately.

`ceval.c`, `generated_cases.c.h`, `opcode_targets.h`, `executor_cases.c.h`,
and `ceval_macros.h` are retired candidate runtime inputs. `bytecodes.c` remains
the instruction definition. The optional JIT inlines native Jac uop bodies
into a small C trampoline that preserves its patch points and `preserve_none`
ABI. The existing CPython relocation and patch machinery consumes those native
stencils. Their per-object provenance accompanies JIT-enabled builds and records
the native body, optimized IR, object, calling convention, relocation model,
and code model. The linker carries through the original target settings,
including the x86-64 ELF medium code model and absolute data references.

Generation only writes source. It does not build or validate the evaluator.
Use the existing execution runner and benchmark with `--require-native-evaluator`
when validation is authorized. Artifact inspection, upstream coverage, ownership
and reentry checks, matched benchmarks, and platform CI remain separate gates.
