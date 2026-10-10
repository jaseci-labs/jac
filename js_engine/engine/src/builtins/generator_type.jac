"""
JSGeneratorState type definition — shared by builtins/generators.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _GENERATOR_TABLE — that stays in generators.na.jac.
"""

import from engine.src.runtime.jsvalue { JSValue, js_undefined }
import from engine.src.bytecode.op { CompiledFunction }


# ═══════════════════════════════════════════════════════════════════════════════
# JSGeneratorState
# ═══════════════════════════════════════════════════════════════════════════════

"""
Per-generator execution state.

  func       — the compiled generator function
  locals     — snapshot of the local variables at yield point
  free_vals  — captured free variables
  this_val   — lexical `this` at the time the generator was created
  catch_stack — active try/catch block nesting (IP of catch handlers)
  send_val   — value injected by .next(val) / .return(val) / .throw(err)
  throw_mode — True if the injected value is an exception to throw
  ret_mode   — True if .return(val) was called (force-close)
"""
obj:pub JSGeneratorState {
    has func: CompiledFunction,
        locals: list[JSValue],
        free_vals: list[JSValue],
        this_val: JSValue,
        catch_stack: list[int],
        send_val: JSValue,
        saved_stack: list[JSValue],
        delegate_gen: JSValue,
        async_promise: JSValue,
        module_fns: list[CompiledFunction],
        super_fn: JSValue = js_undefined(),
        saved_ip: int = 0,
        saved_rpc: int = 0,
        done: bool = False,
        throw_mode: bool = False,
        ret_mode: bool = False,
        stack_base: int = 0,
        executing: bool = False,
        cell_kind: int = 8,
        cell_flags: int = 0,
        structure_id: int = 0;
}
# Saved operand stack slice (items pushed before yield that belong to this frame)

# Active yield* delegate generator (js_undefined() if none)

# outer async Promise to settle when done (ASYNC frames only)
# compilation-unit snapshot — restored on async resume (Fix 1)
# B13: the originating method/ctor closure (carries [[HomeObject]] / super_class)
# so `super.x` inside a generator method resolves. js_undefined if none.

# Register-ISA frames: the register pc to resume at (saved_ip stays the
# stack-instruction index the handlers and stack traces use).

# True while this generator's body is on the VM stack (being resumed). A
# re-entrant .next()/.throw()/.return() while executing must throw TypeError
# (ES §27.5.3.3 GeneratorResume / step "If state is executing"). Placed BEFORE
# the cell header so the GC-inspected header stays at the struct tail.

# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_GENERATOR
