"""
Bytecode Opcodes & Instruction Set for js_engine.

Defines the complete instruction set for the js_engine virtual machine plus the
data structures used by both the compiler  and VM .
Keeping everything in one file avoids circular dependencies.

Bun reference: JavaScriptCore bytecode (100+ opcodes); we define a compact set
ECMAScript spec: N/A — implementation-defined bytecode format
"""

import from engine.src.runtime.jsvalue { JSValue }

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Opcode enum
# ══════════════════════════════════════════════════════════════════════════════

"""All VM instruction variants for the js_engine bytecode interpreter."""
enum Opcode {
    # ── Stack ────────────────────────────────────────────────────────── 0-7 ──
    LOAD_CONST = 0,  # push constants[arg]
    LOAD_UNDEFINED = 1,  # push undefined
    LOAD_NULL = 2,  # push null
    LOAD_TRUE = 3,  # push true
    LOAD_FALSE = 4,  # push false
    POP = 5,  # discard top of stack
    DUP = 6,  # duplicate top of stack
    SWAP = 7,  # swap top two stack items
    # ── Variables ───────────────────────────────────────────────────── 8-13 ──
    LOAD_LOCAL = 8,  # push locals[arg]
    STORE_LOCAL = 9,  # locals[arg] = pop()
    LOAD_GLOBAL = 10,  # push globals[constants[arg].as_str()]
    STORE_GLOBAL = 11,  # globals[constants[arg].as_str()] = pop()
    LOAD_FREE = 12,  # push free_vars[arg]
    STORE_FREE = 13,  # free_vars[arg] = pop()
    # ── Objects ────────────────────────────────────────────────────── 14-23 ──
    NEW_OBJECT = 14,  # push {} — create empty object
    NEW_ARRAY = 15,  # push [] with arg items popped from stack
    GET_PROP = 16,  # obj = pop(); key = constants[arg]; push obj[key]
    SET_PROP = 17,  # val = pop(); obj = pop(); obj[constants[arg]] = val
    DEL_PROP = 18,  # obj = pop(); delete obj[constants[arg]]
    GET_INDEX = 19,  # idx = pop(); obj = pop(); push obj[idx]
    SET_INDEX = 20,  # val = pop(); idx = pop(); obj = pop(); obj[idx] = val
    HAS_PROP = 21,  # key = pop(); obj = pop(); push (key in obj)
    GET_ITER = 22,  # push iterator for top of stack
    ITER_NEXT = 23,  # advance iterator; push {value, done}
    # ── Arithmetic ─────────────────────────────────────────────────── 24-30 ──
    ADD = 24,  # b = pop(); a = pop(); push a + b
    SUB = 25,  # b = pop(); a = pop(); push a - b
    MUL = 26,  # b = pop(); a = pop(); push a * b
    DIV = 27,  # b = pop(); a = pop(); push a / b
    MOD = 28,  # b = pop(); a = pop(); push a % b
    POW = 29,  # b = pop(); a = pop(); push a ** b
    NEG = 30,  # a = pop(); push -a
    # ── Bitwise ────────────────────────────────────────────────────── 31-37 ──
    BAND = 31,  # b = pop(); a = pop(); push a & b
    BOR = 32,  # b = pop(); a = pop(); push a | b
    BXOR = 33,  # b = pop(); a = pop(); push a ^ b
    BNOT = 34,  # a = pop(); push ~a
    SHL = 35,  # b = pop(); a = pop(); push a << b
    SHR = 36,  # b = pop(); a = pop(); push a >> b  (signed)
    USHR = 37,  # b = pop(); a = pop(); push a >>> b (unsigned)
    # ── Comparison ─────────────────────────────────────────────────── 38-47 ──
    EQ = 38,  # b = pop(); a = pop(); push a == b  (abstract)
    NEQ = 39,  # b = pop(); a = pop(); push a != b  (abstract)
    LT = 40,  # b = pop(); a = pop(); push a < b
    LTE = 41,  # b = pop(); a = pop(); push a <= b
    GT = 42,  # b = pop(); a = pop(); push a > b
    GTE = 43,  # b = pop(); a = pop(); push a >= b
    STRICT_EQ = 44,  # b = pop(); a = pop(); push a === b
    STRICT_NEQ = 45,  # b = pop(); a = pop(); push a !== b
    INSTANCEOF = 46,  # b = pop(); a = pop(); push a instanceof b
    IN = 47,  # b = pop(); a = pop(); push a in b
    # ── Logic ──────────────────────────────────────────────────────── 48-51 ──
    NOT = 48,  # a = pop(); push !a
    TYPEOF = 49,  # a = pop(); push typeof a (as string JSValue)
    VOID = 50,  # a = pop(); push undefined
    DELETE = 51,  # key = pop(); obj = pop(); delete obj[key] (computed delete)
    # ── Control ────────────────────────────────────────────────────── 52-56 ──
    JUMP = 52,  # pc = arg (unconditional)
    JUMP_IF_TRUE = 53,  # cond = pop(); if ToBoolean(cond): pc = arg
    JUMP_IF_FALSE = 54,  # cond = pop(); if !ToBoolean(cond): pc = arg
    JUMP_IF_NULL = 55,  # a = peek(); if a is null: pc = arg
    JUMP_IF_UNDEFINED = 56,  # a = peek(); if a is undefined: pc = arg
    # ── Functions ──────────────────────────────────────────────────── 57-64 ──
    CALL = 57,  # arg = nargs; fn = stack[-arg-1]; call fn
    CALL_METHOD = 58,  # arg = nargs; arg2 = name constant index
    NEW = 59,  # arg = nargs; ctor = stack[-arg-1]; new ctor(...)
    RETURN = 60,  # return pop()
    RETURN_UNDEFINED = 61,  # return undefined
    MAKE_FUNCTION = 62,  # arg = CompiledFunction index; push closure
    MAKE_ARROW = 63,  # like MAKE_FUNCTION but captures lexical this
    MAKE_CLASS = 64,  # arg = class descriptor index
    # ── Async / Generator ──────────────────────────────────────────── 65-67 ──
    AWAIT = 65,  # val = pop(); suspend coroutine; resume with result
    YIELD = 66,  # val = pop(); yield val; resume with next value
    YIELD_STAR = 67,  # delegate to inner iterator
    # ── Exceptions ─────────────────────────────────────────────────── 68-72 ──
    THROW = 68,  # val = pop(); throw val
    PUSH_CATCH = 69,  # arg = handler pc; push exception handler frame
    POP_CATCH = 70,  # pop exception handler frame (normal exit of try)
    PUSH_FINALLY = 71,  # arg = finally pc; push finally frame
    POP_FINALLY = 72,  # pop finally frame; resume normal or re-throw
    # ── Spread / Rest ──────────────────────────────────────────────── 73-76 ──
    SPREAD = 73,  # expand iterable on stack for call/array spread
    REST_ARGS = 74,  # collect remaining call args into array local
    UNPACK_ARRAY = 75,  # arg = nslots; destructure array from top-of-stack
    UNPACK_OBJECT = 76,  # arg = nkeys; destructure object from top-of-stack
    # ── Misc ───────────────────────────────────────────────────────── 77-81 ──
    NOP = 77,  # no operation (placeholder / alignment)
    DEBUGGER = 78,  # breakpoint hint
    IMPORT = 79,  # arg = module name constant; push module namespace
    EXPORT = 80,  # arg = export name constant; bind to module exports
    LOAD_SELF = 81,  # push current closure's own JSValue (named-fn self-recursion)
    LOAD_THIS = 82,
    OBJECT_SPREAD = 83,
    ITER_NEXT_VAL = 84,
    # ── Class ──────────────────────────────────────────────────────── 85-88 ──
    DEFINE_METHOD = 85,  # arg = name_intern, arg2 = 0(instance)|1(static); pop fn; class stays TOS
    SUPER_CALL = 86,  # arg = nargs; call super constructor with current this
    LOAD_SUPER_PROTO = 87,  # push current closure's super class .prototype (for super.method())
    DEFINE_FIELD = 88,  # arg = name_intern, arg2 = 0(instance)|1(static); pop init_fn; class stays TOS
    # ── Closure Cells ──────────────────────────────────────────────── 89-91 ──
    MAKE_CELL = 89,  # wrap locals[arg] in a shared cell object
    LOAD_DEREF = 90,  # push cell_get(locals[arg])  — read through local cell
    STORE_DEREF = 91,  # cell_set(locals[arg], pop()) — write through local cell
    TO_NUMBER = 93,  # a = pop(); push ToNumber(a) as Float64
    # ── Module System ──────────────────────────────────────────────── 92 ──
    DYNAMIC_IMPORT = 92,  # specifier = pop(); push Promise.resolve(require(specifier))
    # ── Accessor Properties (getters/setters) ──────────────────────── 94-95 ──
    DEFINE_GETTER = 94,  # arg = name_intern, arg2 = 0(instance)|1(static)|2(object literal); pop fn; target stays TOS
    DEFINE_SETTER = 95,  # arg = name_intern, arg2 = 0(instance)|1(static)|2(object literal); pop fn; target stays TOS
    # ── Async Iteration ────────────────────────────────────────────── 96-97 ──
    GET_ASYNC_ITER = 96,  # pop obj; call obj[Symbol.asyncIterator](); push async-iterator wrapper
    ASYNC_ITER_NEXT = 97,  # peek async-iterator; call .next(); await result; push value + done_flag
    # ── TDZ / let-const ────────────────────────────────────────────── 98 ──
    TDZ_CLASS = 98,  # push TDZ sentinel; used with STORE_GLOBAL to mark class TDZ binding
    # ── RegExp literal ──────────────────────────────────────────────── 99 ──
    MAKE_REGEXP = 99,  # arg = index of "/pattern/flags" constant; push RegExp object
    # ── Coercions ──────────────────────────────────────────────────── 100 ──
    TO_STRING = 100,  # a = pop(); push ToString(a) with ToPrimitive("string") for objects
    # ── ESM import.meta ────────────────────────────────────────────── 101 ──
    IMPORT_META = 101,  # push frozen {url, env, resolve} for import.meta
    # ── ESM re-export ──────────────────────────────────────────────── 102 ──
    REEXPORT_STAR = 102,  # pop namespace; live getters for named exports onto exports (skip default)
    REEXPORT_LIVE = 103,  # pop namespace; arg = "imported:exported" constant; install live getter
    LOAD_HOLE = 104,  # push array-hole sentinel (elision in array literal)
    LOAD_LOCAL_CHECKED = 105,  # TDZ-checked local load; throws ReferenceError if TDZ sentinel
    STORE_NEW_CELL = 106,  # pop value; locals[arg] = make_cell(value) — fresh cell per iteration
    STORE_MODULE_GLOBAL = 107,  # module-scoped globals[name] = pop() (CJS top-level; not globalThis)
    ITER_CLOSE = 108,  # pop iterator; call IteratorClose (iterator.return())
    # ── with statement ─────────────────────────────────────────────── 109 ──
    WITH_PUSH = 109,  # obj = pop(); ToObject(obj); push onto vm.with_stack (scope chain)
    WITH_POP = 110,  # pop vm.with_stack
    LOAD_NAME = 111,  # name = constants[arg]; resolve via with_stack→locals→globals; push value
    STORE_NAME = 112,  # val = pop(); name = constants[arg]; resolve via with_stack→locals→globals
    USING_DECLARE = 113,  # pop resource; register on current dispose scope (arg=1 → async dispose). null/undefined skipped; non-disposable → TypeError
    DISPOSE_MARK = 114,  # push current dispose-stack depth as a scope marker (block/for/fn entry with `using`)
    DISPOSE_RUN = 115,  # pop marker; dispose resources above it in reverse order ([Symbol.dispose]()), then restore depth
    # ── destructuring guard ────────────────────────────────────────── 116 ──
    REQUIRE_COERCIBLE = 116,  # RequireObjectCoercible(TOS): throw TypeError if null/undefined; value left on stack
    # ── array-destructuring IteratorClose (spec §7.4.11, done-aware) ── 117 ──
    ITER_CLOSE_NRML = 117,  # normal completion: pop iterator record; if not [[done]], call return(); throw if return() throws or yields non-object
    ITER_CLOSE_THRW = 118,  # abrupt completion: stack [exc, iter]; pop iter; if not [[done]], call return() (swallow its errors); THROW exc
    # ── private brand check (class private members, ES §13.15) ──────── 119 ──
    CHECK_PRIVATE = 119,  # peek TOS (object); if it lacks private member arg (mangled key), throw TypeError; else leave object on stack. arg2=1 → membership test (push bool instead of throw, for `#x in obj`)
    # ── property-key coercion (ES §7.1.19 ToPropertyKey) ───────────────  120 ──
    TO_PROPERTY_KEY = 120,  # k = pop(); push ToPropertyKey(k) as a primitive (Symbol or interned String). Runs Symbol.toPrimitive/toString/valueOf once; used to evaluate a computed member key exactly once for compound assignment / update (base[prop] op= v). Downstream GET_INDEX/SET_INDEX re-coerce is then a no-op.
    # ── delete of a bare global name (ES §13.5.1.2) ────────────────────  121 ──
    DEL_NAME = 121,  # push delete result for the global name constants[arg]: false if it is a non-configurable global property (built-ins like NaN/Math, or a var-declared binding), true if configurable-and-deleted or unresolvable. arg2=1 → strict (parser already rejects `delete name` in strict, so unused).
    # ── super property reads (ES §13.3.7 SuperProperty) ────────────  122/123 ──
    SUPER_GET_PROP = 122,  # stack: [superBase, receiver]; read constants[arg] off superBase but invoke any getter with this=receiver (the current method's `this`). Pushes the value.
    SUPER_GET_INDEX = 123,  # stack: [superBase, key, receiver]; computed form of SUPER_GET_PROP (key is a value on the stack).
    # ── super property writes (ES §13.3.7.1) ───────────────────────  124/125 ──
    SUPER_SET_PROP = 124,  # stack: [val, superBase, receiver]; [[Set]](constants[arg], val) on superBase with this=receiver — a setter runs with this=receiver, else the property is created/updated on receiver. Pushes val.
    SUPER_SET_INDEX = 125,  # stack: [val, superBase, key, receiver]; computed form of SUPER_SET_PROP.
    # ── computed-key function name inference (ES §12.2.6.9 / §14) ───────  126 ──
    INFER_NAME_FROM_KEY = 126,  # stack: [..., key, fn] (fn on top, key below); if fn is an anonymous function/arrow/class set its .name to the property-key name of `key` (string key → the string; Symbol key → "[desc]" or ""; ToPropertyKey applied). arg2: 1 → prefix name with "get " , 2 → "set ". Leaves the stack unchanged.
    # ── new.target (ES §9.4.3 GetNewTarget) ────────────────────────────  127 ──
    LOAD_NEW_TARGET = 127,  # push the current frame's [[NewTarget]] (the constructor when invoked via new/Reflect.construct, else undefined; arrows inherit lexically).
    # ── tagged-template call-site cache (ES §13.2.8.4 GetTemplateObject) ─  128 ──
    TEMPLATE_OBJECT = 128,  # pop the freshly-built cooked strings array (with own `.raw` array). arg = unique template-site id. First evaluation of a site: freeze the array + its `.raw`, cache under (module,site) in realm.template_cache, push it. Later evaluations: discard the fresh array, push the cached one (SameValue identity, ES §13.2.8.4).
    # ── resolve-once name reference for read-modify-write inside `with` ─  129-130 ──
    LOAD_NAME_REF = 129,  # name=constants[arg]; resolve the reference ONCE (§13.15.2). Push [base, value]: base is the resolved with-object cell when the name binds to a with-object, else a lexical/global sentinel. Paired with STORE_NAME_REF so a getter that mutates the scope mid-assignment cannot re-target the write.
    STORE_NAME_REF = 130,  # val=pop(); base=pop(); name=constants[arg]; if base is a with-object write to it directly (PutValue on the initially-created Reference, even if the property was since deleted), else store via the normal name chain (arg2=1 → strict). Consumes the [base, value] pair LOAD_NAME_REF pushed.
    LOAD_CLASS_BRAND = 131,  # push the per-EVALUATION private brand of the class the current method/field-init belongs to (frame.self_fn's closure `class_brand`; 0 if none). Used by the synthetic private-brand-install field to stamp `this.__brand@<sid>` with THIS evaluation's brand (ES §6.2.12 / §15.7).
    # MODULE_NS (was 131) and EXPORT_VAR_LIVE (was 132) removed in the adel merge —
    # adel's ESM model supersedes both: the IMPORT opcode returns an already-marked
    # Module Namespace Exotic Object (no wrapping opcode), and live `export {x}` /
    # `export default fn` bindings use the _esm_alias_add store-hook system (no
    # live-getter opcode). Freed 131 reused by CREATE_GLOBAL_FN_BINDING.
    # ── Annex B / GlobalDeclarationInstantiation ───────────────────────────  131 ──
    CREATE_GLOBAL_FN_BINDING = 132,  # name=constants[arg]; val=pop(); CreateGlobalFunctionBinding(name, val, configurable=(arg2!=0)). Updates self.globals + globalThis descriptor.
    # ES §15.7.14 ClassDefinitionEvaluation: static elements (static field initializers
    # AND static blocks) run in a SEPARATE pass AFTER every class element's property KEY
    # has been evaluated (so a later element's computed key is observed before an earlier
    # static initializer runs). DEFINE_FIELD(static) therefore only records each static
    # element into the class's __STATIC_FIELDS__ list (with its already-evaluated key);
    # this opcode runs them in source order with this=class. Class stays on TOS.
    RUN_STATIC_ELEMENTS = 133,
    # ES §15.10.3 EvaluateCall step 7 (tail position): a call `f(args)` that is the whole
    # ReturnValue of an enclosing strict function is a proper tail call — the enclosing
    # frame must be DISCARDED before entering the callee (PrepareForTailCall) so unbounded
    # tail recursion uses O(1) stack. Same operand layout as CALL (arg = argc, arg2 = callee
    # name idx + 1, arg3 = direct-eval bits). For a plain JS-function callee the VM's run()
    # trampoline reuses the current native frame; any other callee falls back to a normal call.
    TAIL_CALL = 134,
    # ES §7.3.28 PrivateMethodOrAccessorAdd / §7.3.27 PrivateFieldAdd: installing a class's
    # per-evaluation private brand on `this`. Pops [obj, val]; if obj already has an OWN brand
    # marker for this class (arg = brand_key intern id) it is a DOUBLE install → TypeError
    # (`class Base{constructor(o){return o}} class C extends Base{#m(){}}; new C(o); new C(o)`
    # throws). Otherwise stamps obj[brand_key] = val. Replaces the plain SET_PROP the synthetic
    # brand-install field used, which silently re-stamped.
    INSTALL_BRAND = 135,
    # try/finally exception-path bookkeeping (ES §14.15.3). A `try … finally` with no
    # user catch routes an escaping exception (or a generator forced-return via
    # .return() suspended in the try body) to the finalizer, runs it, then re-raises.
    # FINALLY_ENTER: at the finalizer's exception entry — if a generator forced-return
    # is in flight (_gen_ret_pending) there is NO exception value on the stack, so do
    # nothing; otherwise pop the exception value and stash it in local[arg] so the
    # finalizer (which may itself yield/await) runs with a clean operand stack.
    FINALLY_ENTER = 136,
    # FINALLY_RETHROW: at the finalizer's exception exit — if a forced-return is in
    # flight, hand control back so the generator completes with its return value
    # (state.ret_mode); otherwise reload the stashed exception from local[arg] and
    # THROW it (re-raise, unless the finalizer already completed abruptly).
    FINALLY_RETHROW = 137,
    # FILLER: a TRUE no-op pad (bytecode_optimizer_impl_plan). Length-preserving
    # rewrites replace eliminated instructions with FILLER; the optimizer then
    # retargets jumps past filler runs so they normally never execute. Executing
    # one is LEGAL and does nothing — unlike NOP, which pushes the class-TDZ
    # sentinel (do NOT confuse them; NOP-as-pad was a live stack leak, see the
    # cell-elision site in compiler._pop_fn). Must stay side-effect-free so
    # bytecode with JS_BCOPT=0 (jumps still aimed at pads) runs correctly.
    FILLER = 138,
    # ── Compile-time megaops (bytecode_optimizer_impl_plan Phase 2) ──────
    # QUICKENING-style: the optimizer replaces only the HEAD instruction of a
    # matched window; the original interior instructions stay in place. The
    # megaop's fast path performs the whole window's effect and jumps past
    # it; its slow path replicates just the head op (a local load) and FALLS
    # THROUGH into the untouched originals — so jumps into the window, non-
    # fast-path types, and every observable coercion behave exactly as the
    # unoptimized sequence.
    #
    # LOCAL_INC: head of the 8-op postfix `i++`/`i--` STATEMENT shape
    #   LL s; LC "n:0"; SUB; DUP; LC "n:∓1"; SUB; ST s; POP
    #   arg=slot, arg2=delta (+1 for ++, −1 for --). Fast path: int32 slot.
    LOCAL_INC = 139,
    # BR_CMP_LL: head of the 4-op loop condition
    #   LL(_CHECKED) a; LL(_CHECKED) b; LT|LTE|GT|GTE|STRICT_EQ; JUMP_IF_FALSE|TRUE t
    #   arg=slot_a; arg2 = slot_b | cmpop<<16 (0=LT 1=LTE 2=GT 3=GTE 4=SEQ)
    #     | checked_a<<20 | checked_b<<21 | jump_if_true<<22; arg3=branch ip.
    #   Fast path: both operands numeric (TDZ sentinel is non-numeric, so
    #   checked slots in TDZ fall to the slow path and throw exactly there).
    BR_CMP_LL = 140,
    # GET_LL_INDEX: head of  LL(_CHECKED) obj; LL key; GET_INDEX
    #   arg=slot_obj; arg2 = slot_key | checked_obj<<20. Pushes obj+key then
    #   DELEGATES to the ORIGINAL GET_INDEX instruction (still at head+2).
    GET_LL_INDEX = 141,
    # SET_LL_INDEX: head of  LL(_CHECKED) obj; REQUIRE_COERCIBLE; LL key;
    #   TO_PROPERTY_KEY; LL val; SET_INDEX
    #   arg=slot_obj; arg2 = slot_key | checked_obj<<20; arg3=slot_val.
    #   Pushes operands in original order, delegating each coercion/store to
    #   the ORIGINAL instructions in the window (observable order identical).
    SET_LL_INDEX = 142,
    # GET_LLC_PROP: head of  LL(_CHECKED) s; GET_PROP k   (quickening —
    #   pushes the local (TDZ-checked per flag) then DELEGATES to the
    #   ORIGINAL GET_PROP instruction at head+1, so its self-patching
    #   kid-cache (arg2) and shape-IC slots keep working in place.
    #   arg=slot; arg2 = checked<<20.
    GET_LLC_PROP = 143,
    # SET_THIS_PROP: head of  LOAD_THIS; SWAP; SET_PROP k; POP  (the ctor
    #   `this.x = v;` statement). Replicates LOAD_THIS (this-TDZ throw
    #   included) + SWAP, delegates to the ORIGINAL SET_PROP at head+2
    #   (IC preserved), replicates the POP. No operands of its own.
    SET_THIS_PROP = 144,
    # SET_LL_PROP: head of  LL val; LL(_CHECKED) obj; SWAP; SET_PROP k; POP
    #   (the statement `localObj.key = localVal;`). arg=val slot,
    #   arg2 = obj slot | checked_obj<<20. Pushes obj then val (the SWAP's
    #   net effect), delegates to the ORIGINAL SET_PROP at head+3 (IC and
    #   key-cache self-patching preserved via the ip convention), pops.
    SET_LL_PROP = 145,
    # PROP_INC: head of the postfix member update `this.k++` / `local.k++`
    #   LOAD_THIS | LL(_CHECKED) s; GET_PROP k; LC "n:0"; SUB; DUP;
    #   LC "n:∓1"; SUB; LOAD_THIS | LL(_CHECKED) s; SWAP; SET_PROP k; POP
    #   [; POP when the value is unused]. arg=slot (local receiver), arg2=delta
    #   (+1 / −1), arg3 = statement<<0 | local<<1 | checked<<2 | add<<3. The
    #   add form (bit 3) is the statement `x.k += c;` with an int32 constant c:
    #   LOAD_THIS | LL(_CHECKED) s; GET_PROP k; LC c; ADD;
    #   LOAD_THIS | LL(_CHECKED) s; SWAP; SET_PROP k; POP  (arg2 = c). Fast path: the
    #   receiver is a plain object with an own writable int32 data property k
    #   (no getter/setter/proxy can run) — bump it in place and skip the window.
    #   Slow path: replicate the head load and fall through to the originals.
    PROP_INC = 146
}

# ══════════════════════════════════════════════════════════════════════════════
# 2.  Instruction
# ══════════════════════════════════════════════════════════════════════════════

"""Single bytecode instruction.

Fields:
  opcode  primary operation
  arg     primary operand (constant index, local slot, jump target, …)
  arg2    secondary operand (CALL_METHOD name index, etc.)
  line    source line number for stack traces (0 = unknown)
"""
# ⚠️  Serialized field-for-field by bytecode/jsbc.na.jac. If you add/remove/reorder
#     a field here, bump JSBC_FORMAT_VER and update _encode_fn/_decode_fn in jsbc.na.jac.
obj Instruction {
    has opcode: Opcode,
        arg: int = 0,
        arg2: int = 0,
        line: int = 0,
        arg3: int = 0,
        ic_obj: int = 0,
        ic_ver: int = 0,
        ic_holder: int = 0,
        ic_epoch: int = 0;
}

# Auxiliary flag channel (default 0). Currently: on a bare-identifier CALL of
# `eval`, arg3==1 marks a *direct eval whose call site is inside a parameter
# expression* (B7) — the eval'd code must reject `arguments`/`eval` bindings.

# Monomorphic property IC (GET_PROP/SET_PROP). Used only when VM_IC_ENABLED.
# Appended at struct END — Instruction field order is offset-sensitive.
# last receiver object-table id (1-based)
# JSPropertyMap.version at cache fill
# holder object-table id (0 = miss / undefined)
# holder==4 ([[Set]]-add transition IC): realm proto-epoch at fill time.
# RUNTIME-ONLY (not serialized), like the other ic_* fields.
"""Create an Instruction with the given fields."""
def make_instruction(
    op: Opcode,
    arg: int,
    arg2: int,
    line: int,
    arg3: int = 0,
    ic_obj: int = 0,
    ic_ver: int = 0,
    ic_holder: int = 0
) -> Instruction {
    return Instruction(
        opcode=op,
        arg=arg,
        arg2=arg2,
        line=line,
        arg3=arg3,
        ic_obj=ic_obj,
        ic_ver=ic_ver,
        ic_holder=ic_holder
    );
}

"""Shorthand — create a no-argument instruction (arg=0, arg2=0, line=0)."""
def:pub make_op(op: Opcode) -> Instruction {
    return Instruction(opcode=op, arg=0, arg2=0, line=0);
}

# ══════════════════════════════════════════════════════════════════════════════
# 3.  ConstantPool
# ══════════════════════════════════════════════════════════════════════════════

"""Pool of per-function literal constants indexed by integer slot.

Each `LOAD_CONST arg` instruction refers to slot `arg` in the owning
CompiledFunction's ConstantPool.  Constants are appended during compilation
and never mutated afterwards.
"""
obj ConstantPool {
    has values: list[str];

    """Append `v` and return its slot index."""
    def add(v: str) -> int {
        n: int = len(self.values);
        self.values.append(v);
        return n;
    }

    """Return the constant at slot `i`."""
    def get(i: int) -> str {
        return self.values[i];
    }

    """Return the number of constants in the pool."""
    def size -> int {
        return len(self.values);
    }
}

"""Create an empty ConstantPool."""
def make_constant_pool -> ConstantPool {
    # Non-empty literal forces a fresh list.  Jac may reuse one shared `[]`
    # singleton for every empty list literal; mutating that singleton (e.g. via
    # alias registration) would alias ConstantPool.values and corrupt interning.
    vals: list[str] = [""];
    del vals[0];
    return ConstantPool(values=vals);
}

# ══════════════════════════════════════════════════════════════════════════════
# 4.  CompiledFunction
# ══════════════════════════════════════════════════════════════════════════════

"""A compiled JavaScript function — the unit of execution for the VM.

Produced by the bytecode compiler  and consumed by the VM
interpreter .  Nested functions (closures, methods, arrow
functions) each get their own CompiledFunction; the top-level script is
also a CompiledFunction with name="" and params=[].

Layout mirrors JSC's UnlinkedFunctionExecutable:
  code         flat array of Instructions (no nesting — inner functions are
               referenced by index in the parent module's function table)
  constants    literal values used by LOAD_CONST (numbers, strings, booleans)
  locals       names for local variable slots (debug / decompilation)
  params       parameter names in declaration order
  free_vars    captured outer-scope names (closure variables)
  num_locals   total local slot count (params + let/var/const + temporaries)

⚠️  Serialized field-for-field by bytecode/jsbc.na.jac (.jsbc bytecode cache).
    If you add/remove/reorder ANY field below, bump JSBC_FORMAT_VER and update
    _encode_fn/_decode_fn in jsbc.na.jac. Append-only + bump is the safe path
    (see [[js_engine-vm-struct-field-order]]).
"""
obj CompiledFunction {
    has name: str,
        file: str,
        code: list[Instruction],
        constants: ConstantPool,
        locals: list[str],
        params: list[str],
        free_vars: list[str],
        free_var_slots: list[int],
        num_locals: int = 0,
        is_strict: bool = False,
        is_async: bool = False,
        is_generator: bool = False,
        is_method: bool = False,
        param_base: int = 0,
        has_rest: bool = False,
        arguments_slot: int = -1,
        expected_arg_count: int = 0,
        is_bound: bool = False,
        gen_prologue_end_ip: int = -1,
        lexical_names: list[str] = [],
        is_field_init: bool = False,
        ctx_global: JSValue = 0,
        simple_catch_params: list[str] = [],
        source: str = "",
        priv_env_keys: list[str] = [],
        priv_env_mangles: list[str] = [],
        priv_env_next_sid: int = 0,
        self_name: str = "",
        const_cache: list[JSValue] = [],
        optimized: int = 0,
        has_tail_call: bool = False,
        risa: int = 0,
        reg_tmp_base: int = 0,
        rcode: list[int] = [],
        rorig: list[int] = [],
        rhandler: list[int] = [],
        reg_gen_start: int = -1;
}

# parent-local slot index per free_var; -1 = transitive capture

# True for concise methods / accessors (object & class) — these have no own
# `prototype` property (ES §10.2.3: only ordinary function/constructor objects
# define `prototype`). Used so MAKE_FUNCTION creates the closure prototype-less.

# For generators / async generators: bytecode offset just past the
# parameter-binding prologue (default-value + destructuring evaluation).
# The VM runs [0, gen_prologue_end_ip) eagerly at generator creation so an
# abrupt completion in a default/destructured parameter propagates at call
# time (synchronously for generators; as a rejected promise for async
# generators), per FunctionDeclarationInstantiation. -1 = no eager prologue.

# ES §19.2.1.3 EvalDeclarationInstantiation static check: names bound
# *lexically* in this function (let/const/class + parameters). A direct
# `eval` whose top-level `var` re-declares one of these must throw a
# SyntaxError. Populated by the compiler's `_declare` for lexical kinds and
# by parameter binding. Appended LAST — CompiledFunction field order is
# offset-sensitive (see js_engine-vm-struct-field-order). Default `= []`.

# True for a synthetic CLASS FIELD INITIALIZER function (ES §15.7.1): a direct
# `eval` inside it must reject `arguments` (field inits have no arguments) and
# `new.target`. The VM reads this off the caller frame's func in the eval path.
# Appended LAST — CompiledFunction field order is offset-sensitive.

# The contextified sandbox that is the *global object* for this function's
# bare-name resolution (vm.runInContext, Wave 8). 0 (undefined) for ordinary
# code, which resolves against the host globals map + globalThis. Every
# function compiled from one vm.runInContext source shares the same value, so
# a closure returned out of the sandbox keeps resolving against it and a host
# closure invoked *from* sandbox code keeps resolving against the host.
# Appended LAST — CompiledFunction field order is offset-sensitive.

# Simple CatchParameter BindingIdentifier names in this function (B.3.5).
# Direct eval may introduce `var`/function of the same name without SyntaxError.
# Pattern catch params are NOT listed here. Appended at struct END.

# Original source slice for Function.prototype.toString (empty → native form).
# Appended at struct END.

# Snapshot of the enclosing PrivateEnvironment at function compile time
# (ES §8.2 / PerformEval): direct eval must mangle `#name` to the same
# `__priv_#name@<sid>` keys the caller method/field-init uses. Parallel
# lists: `#name` → mangled storage key. `priv_env_next_sid` is the
# compiler's priv_scope_seq after this function's class scopes, so eval
# nested classes allocate fresh sids. Appended at struct END.

# Named-function-expression self-reference name (ES §15.2.5): the IMMUTABLE
# binding a named function expression `function f(){…}` makes for its own
# name.  Compile-time assignment is enforced in `_store_lvalue` (fnself kind),
# but a *direct eval* inside the body compiles a separate program that can only
# resolve `f` as a runtime free-var — STORE_NAME consults this to make that
# write a silent no-op (sloppy) / TypeError (strict).  Empty for declarations,
# arrows, and anonymous expressions.  Appended at struct END (offset-sensitive).

# Decoded-constant cache (dispatch_impl_plan Phase 3): lazily filled,
# parallel to `constants` (hole sentinel = not yet decoded). RUNTIME-ONLY —
# never serialized, so no JSBC_FORMAT_VER impact (the header rule about
# editing CompiledFunction concerns serialized layout). Values are
# immutable by construction (numbers + interned strings), so entries
# never invalidate. Appended at struct END.

# Bytecode-optimizer guard (bytecode_optimizer_impl_plan §1.1): 1 once
# optimize_fn has run, so eval/Function reuse and the jsbc decode path
# (which ships pre-optimized code and sets this to 1) never double-run
# the pass. RUNTIME-ONLY — not serialized. int, not bool (memory rule:
# appended struct fields keep scalar defaults). Appended at struct END.

# True when the compiled body contains TAIL_CALL (set by the compiler's
# _pop_fn scan and by jsbc decode) — such functions must always run via
# the native path whose trampoline implements proper tail calls
# (call_path Phase 3 excludes them from inlining). Appended at END.

# Register ISA (docs/VM_REARCH_PLAN.md V2, bytecode/regisa.jac). RUNTIME-
# ONLY, never serialized (jsbc writes reg_tmp_base as num_locals).
#   risa          0 = not translated yet, 1 = rcode runs (VM._exec_reg),
#                 2 = stack-only (generator / async / tail call / shape
#                 the translator does not model) — VM._exec as before.
#   reg_tmp_base  the function's own local count; registers
#                 [reg_tmp_base, num_locals) are the translator's
#                 temporaries (+1 scratch). num_locals is bumped so every
#                 locals-list allocation site sizes the register file.
#   rcode         packed 64-bit words (op | A<<8 | B<<24 | C<<40)
#   rorig         the stack instruction each word came from (lines,
#                 constants, IC state, bridged handlers)
# Appended at struct END.

# Register ISA handler table: per stack instruction, the register pc of
# the innermost enclosing catch / finally handler, -1 for none; empty
# when the function keeps PUSHCATCH / POPCATCH (it uses `with` / `using`).

# Register pc of gen_prologue_end_ip: where a generator body whose
# parameter prologue already ran (eagerly, on the stack handlers) starts.
"""Create an empty CompiledFunction with the given name and source file."""
def make_compiled_fn(name: str, file: str) -> CompiledFunction {
    pool: ConstantPool = make_constant_pool();
    return CompiledFunction(
        name=name,
        file=file,
        code=[],
        constants=pool,
        locals=[],
        params=[],
        free_vars=[],
        free_var_slots=[],
        num_locals=0,
        is_strict=False,
        is_async=False,
        is_generator=False,
        has_rest=False,
        arguments_slot=-1,
        self_name=""
    );
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  Disassembler
# ══════════════════════════════════════════════════════════════════════════════

"""Return the mnemonic name for `op`."""
def _opname(op: Opcode) -> str {
    if op == Opcode.LOAD_CONST {
        return "LOAD_CONST";
    } elif op == Opcode.LOAD_UNDEFINED {
        return "LOAD_UNDEFINED";
    } elif op == Opcode.LOAD_NULL {
        return "LOAD_NULL";
    } elif op == Opcode.LOAD_TRUE {
        return "LOAD_TRUE";
    } elif op == Opcode.LOAD_FALSE {
        return "LOAD_FALSE";
    } elif op == Opcode.POP {
        return "POP";
    } elif op == Opcode.DUP {
        return "DUP";
    } elif op == Opcode.SWAP {
        return "SWAP";
    } elif op == Opcode.LOAD_LOCAL {
        return "LOAD_LOCAL";
    } elif op == Opcode.STORE_LOCAL {
        return "STORE_LOCAL";
    } elif op == Opcode.LOAD_GLOBAL {
        return "LOAD_GLOBAL";
    } elif op == Opcode.STORE_GLOBAL {
        return "STORE_GLOBAL";
    } elif op == Opcode.LOAD_FREE {
        return "LOAD_FREE";
    } elif op == Opcode.STORE_FREE {
        return "STORE_FREE";
    } elif op == Opcode.NEW_OBJECT {
        return "NEW_OBJECT";
    } elif op == Opcode.NEW_ARRAY {
        return "NEW_ARRAY";
    } elif op == Opcode.GET_PROP {
        return "GET_PROP";
    } elif op == Opcode.SET_PROP {
        return "SET_PROP";
    } elif op == Opcode.DEL_PROP {
        return "DEL_PROP";
    } elif op == Opcode.GET_INDEX {
        return "GET_INDEX";
    } elif op == Opcode.SET_INDEX {
        return "SET_INDEX";
    } elif op == Opcode.HAS_PROP {
        return "HAS_PROP";
    } elif op == Opcode.GET_ITER {
        return "GET_ITER";
    } elif op == Opcode.ITER_NEXT {
        return "ITER_NEXT";
    } elif op == Opcode.ADD {
        return "ADD";
    } elif op == Opcode.SUB {
        return "SUB";
    } elif op == Opcode.MUL {
        return "MUL";
    } elif op == Opcode.DIV {
        return "DIV";
    } elif op == Opcode.MOD {
        return "MOD";
    } elif op == Opcode.POW {
        return "POW";
    } elif op == Opcode.NEG {
        return "NEG";
    } elif op == Opcode.BAND {
        return "BAND";
    } elif op == Opcode.BOR {
        return "BOR";
    } elif op == Opcode.BXOR {
        return "BXOR";
    } elif op == Opcode.BNOT {
        return "BNOT";
    } elif op == Opcode.SHL {
        return "SHL";
    } elif op == Opcode.SHR {
        return "SHR";
    } elif op == Opcode.USHR {
        return "USHR";
    } elif op == Opcode.EQ {
        return "EQ";
    } elif op == Opcode.NEQ {
        return "NEQ";
    } elif op == Opcode.LT {
        return "LT";
    } elif op == Opcode.LTE {
        return "LTE";
    } elif op == Opcode.GT {
        return "GT";
    } elif op == Opcode.GTE {
        return "GTE";
    } elif op == Opcode.STRICT_EQ {
        return "STRICT_EQ";
    } elif op == Opcode.STRICT_NEQ {
        return "STRICT_NEQ";
    } elif op == Opcode.INSTANCEOF {
        return "INSTANCEOF";
    } elif op == Opcode.IN {
        return "IN";
    } elif op == Opcode.NOT {
        return "NOT";
    } elif op == Opcode.TYPEOF {
        return "TYPEOF";
    } elif op == Opcode.VOID {
        return "VOID";
    } elif op == Opcode.DELETE {
        return "DELETE";
    } elif op == Opcode.JUMP {
        return "JUMP";
    } elif op == Opcode.JUMP_IF_TRUE {
        return "JUMP_IF_TRUE";
    } elif op == Opcode.JUMP_IF_FALSE {
        return "JUMP_IF_FALSE";
    } elif op == Opcode.JUMP_IF_NULL {
        return "JUMP_IF_NULL";
    } elif op == Opcode.JUMP_IF_UNDEFINED {
        return "JUMP_IF_UNDEFINED";
    } elif op == Opcode.CALL {
        return "CALL";
    } elif op == Opcode.CALL_METHOD {
        return "CALL_METHOD";
    } elif op == Opcode.NEW {
        return "NEW";
    } elif op == Opcode.RETURN {
        return "RETURN";
    } elif op == Opcode.RETURN_UNDEFINED {
        return "RETURN_UNDEFINED";
    } elif op == Opcode.MAKE_FUNCTION {
        return "MAKE_FUNCTION";
    } elif op == Opcode.MAKE_ARROW {
        return "MAKE_ARROW";
    } elif op == Opcode.MAKE_CLASS {
        return "MAKE_CLASS";
    } elif op == Opcode.AWAIT {
        return "AWAIT";
    } elif op == Opcode.YIELD {
        return "YIELD";
    } elif op == Opcode.YIELD_STAR {
        return "YIELD_STAR";
    } elif op == Opcode.THROW {
        return "THROW";
    } elif op == Opcode.PUSH_CATCH {
        return "PUSH_CATCH";
    } elif op == Opcode.POP_CATCH {
        return "POP_CATCH";
    } elif op == Opcode.PUSH_FINALLY {
        return "PUSH_FINALLY";
    } elif op == Opcode.POP_FINALLY {
        return "POP_FINALLY";
    } elif op == Opcode.SPREAD {
        return "SPREAD";
    } elif op == Opcode.REST_ARGS {
        return "REST_ARGS";
    } elif op == Opcode.UNPACK_ARRAY {
        return "UNPACK_ARRAY";
    } elif op == Opcode.UNPACK_OBJECT {
        return "UNPACK_OBJECT";
    } elif op == Opcode.NOP {
        return "NOP";
    } elif op == Opcode.DEBUGGER {
        return "DEBUGGER";
    } elif op == Opcode.IMPORT {
        return "IMPORT";
    } elif op == Opcode.EXPORT {
        return "EXPORT";
    } elif op == Opcode.LOAD_SELF {
        return "LOAD_SELF";
    } elif op == Opcode.LOAD_THIS {
        return "LOAD_THIS";
    } elif op == Opcode.OBJECT_SPREAD {
        return "OBJECT_SPREAD";
    } elif op == Opcode.ITER_NEXT_VAL {
        return "ITER_NEXT_VAL";
    } elif op == Opcode.DEFINE_METHOD {
        return "DEFINE_METHOD";
    } elif op == Opcode.SUPER_CALL {
        return "SUPER_CALL";
    } elif op == Opcode.LOAD_SUPER_PROTO {
        return "LOAD_SUPER_PROTO";
    } elif op == Opcode.DEFINE_FIELD {
        return "DEFINE_FIELD";
    } elif op == Opcode.MAKE_CELL {
        return "MAKE_CELL";
    } elif op == Opcode.LOAD_DEREF {
        return "LOAD_DEREF";
    } elif op == Opcode.STORE_DEREF {
        return "STORE_DEREF";
    } elif op == Opcode.TO_NUMBER {
        return "TO_NUMBER";
    } elif op == Opcode.DYNAMIC_IMPORT {
        return "DYNAMIC_IMPORT";
    } elif op == Opcode.DEFINE_GETTER {
        return "DEFINE_GETTER";
    } elif op == Opcode.DEFINE_SETTER {
        return "DEFINE_SETTER";
    } elif op == Opcode.GET_ASYNC_ITER {
        return "GET_ASYNC_ITER";
    } elif op == Opcode.ASYNC_ITER_NEXT {
        return "ASYNC_ITER_NEXT";
    } elif op == Opcode.TDZ_CLASS {
        return "TDZ_CLASS";
    } elif op == Opcode.MAKE_REGEXP {
        return "MAKE_REGEXP";
    } elif op == Opcode.TO_STRING {
        return "TO_STRING";
    } elif op == Opcode.IMPORT_META {
        return "IMPORT_META";
    } elif op == Opcode.REEXPORT_STAR {
        return "REEXPORT_STAR";
    } elif op == Opcode.REEXPORT_LIVE {
        return "REEXPORT_LIVE";
    } elif op == Opcode.LOAD_HOLE {
        return "LOAD_HOLE";
    } elif op == Opcode.LOAD_LOCAL_CHECKED {
        return "LOAD_LOCAL_CHECKED";
    } elif op == Opcode.STORE_NEW_CELL {
        return "STORE_NEW_CELL";
    } elif op == Opcode.STORE_MODULE_GLOBAL {
        return "STORE_MODULE_GLOBAL";
    } elif op == Opcode.ITER_CLOSE {
        return "ITER_CLOSE";
    } elif op == Opcode.ITER_CLOSE_NRML {
        return "ITER_CLOSE_NRML";
    } elif op == Opcode.ITER_CLOSE_THRW {
        return "ITER_CLOSE_THRW";
    } elif op == Opcode.CHECK_PRIVATE {
        return "CHECK_PRIVATE";
    } elif op == Opcode.TO_PROPERTY_KEY {
        return "TO_PROPERTY_KEY";
    } elif op == Opcode.DEL_NAME {
        return "DEL_NAME";
    } elif op == Opcode.SUPER_GET_PROP {
        return "SUPER_GET_PROP";
    } elif op == Opcode.SUPER_GET_INDEX {
        return "SUPER_GET_INDEX";
    } elif op == Opcode.SUPER_SET_PROP {
        return "SUPER_SET_PROP";
    } elif op == Opcode.SUPER_SET_INDEX {
        return "SUPER_SET_INDEX";
    } elif op == Opcode.INFER_NAME_FROM_KEY {
        return "INFER_NAME_FROM_KEY";
    } elif op == Opcode.LOAD_NEW_TARGET {
        return "LOAD_NEW_TARGET";
    } elif op == Opcode.TEMPLATE_OBJECT {
        return "TEMPLATE_OBJECT";
    } elif op == Opcode.CREATE_GLOBAL_FN_BINDING {
        return "CREATE_GLOBAL_FN_BINDING";
    } elif op == Opcode.RUN_STATIC_ELEMENTS {
        return "RUN_STATIC_ELEMENTS";
    } elif op == Opcode.TAIL_CALL {
        return "TAIL_CALL";
    } elif op == Opcode.INSTALL_BRAND {
        return "INSTALL_BRAND";
    } elif op == Opcode.FINALLY_ENTER {
        return "FINALLY_ENTER";
    } elif op == Opcode.FINALLY_RETHROW {
        return "FINALLY_RETHROW";
    } elif op == Opcode.FILLER {
        return "FILLER";
    } elif op == Opcode.LOCAL_INC {
        return "LOCAL_INC";
    } elif op == Opcode.BR_CMP_LL {
        return "BR_CMP_LL";
    } elif op == Opcode.GET_LL_INDEX {
        return "GET_LL_INDEX";
    } elif op == Opcode.SET_LL_INDEX {
        return "SET_LL_INDEX";
    } elif op == Opcode.GET_LLC_PROP {
        return "GET_LLC_PROP";
    } elif op == Opcode.SET_THIS_PROP {
        return "SET_THIS_PROP";
    } elif op == Opcode.SET_LL_PROP {
        return "SET_LL_PROP";
    } elif op == Opcode.PROP_INC {
        return "PROP_INC";
    } elif op == Opcode.WITH_PUSH {
        return "WITH_PUSH";
    } elif op == Opcode.WITH_POP {
        return "WITH_POP";
    } elif op == Opcode.LOAD_NAME {
        return "LOAD_NAME";
    } elif op == Opcode.STORE_NAME {
        return "STORE_NAME";
    } elif op == Opcode.LOAD_NAME_REF {
        return "LOAD_NAME_REF";
    } elif op == Opcode.STORE_NAME_REF {
        return "STORE_NAME_REF";
    } elif op == Opcode.LOAD_CLASS_BRAND {
        return "LOAD_CLASS_BRAND";
    } elif op == Opcode.USING_DECLARE {
        return "USING_DECLARE";
    } elif op == Opcode.DISPOSE_MARK {
        return "DISPOSE_MARK";
    } elif op == Opcode.DISPOSE_RUN {
        return "DISPOSE_RUN";
    } elif op == Opcode.REQUIRE_COERCIBLE {
        return "REQUIRE_COERCIBLE";
    } elif op == Opcode.LOAD_NEW_TARGET {
        return "LOAD_NEW_TARGET";
    } else {
        return "UNKNOWN";
    }
}

"""Return true if the opcode takes an `arg` operand that should be printed."""
def _has_arg(op: Opcode) -> bool {
    if op == Opcode.LOAD_CONST {
        return True;
    } elif op == Opcode.LOAD_LOCAL {
        return True;
    } elif op == Opcode.LOAD_LOCAL_CHECKED {
        return True;
    } elif op == Opcode.STORE_LOCAL {
        return True;
    } elif op == Opcode.STORE_NEW_CELL {
        return True;
    } elif op == Opcode.LOAD_GLOBAL {
        return True;
    } elif op == Opcode.STORE_GLOBAL {
        return True;
    } elif op == Opcode.STORE_MODULE_GLOBAL {
        return True;
    } elif op == Opcode.CREATE_GLOBAL_FN_BINDING {
        return True;
    } elif op == Opcode.ITER_CLOSE {
        return True;
    } elif op == Opcode.LOAD_NAME {
        return True;
    } elif op == Opcode.STORE_NAME {
        return True;
    } elif op == Opcode.LOAD_NAME_REF {
        return True;
    } elif op == Opcode.STORE_NAME_REF {
        return True;
    } elif op == Opcode.LOAD_FREE {
        return True;
    } elif op == Opcode.STORE_FREE {
        return True;
    } elif op == Opcode.NEW_ARRAY {
        return True;
    } elif op == Opcode.GET_PROP {
        return True;
    } elif op == Opcode.SET_PROP {
        return True;
    } elif op == Opcode.DEL_PROP {
        return True;
    } elif op == Opcode.JUMP {
        return True;
    } elif op == Opcode.JUMP_IF_TRUE {
        return True;
    } elif op == Opcode.JUMP_IF_FALSE {
        return True;
    } elif op == Opcode.JUMP_IF_NULL {
        return True;
    } elif op == Opcode.JUMP_IF_UNDEFINED {
        return True;
    } elif op == Opcode.CALL {
        return True;
    } elif op == Opcode.CALL_METHOD {
        return True;
    } elif op == Opcode.NEW {
        return True;
    } elif op == Opcode.MAKE_FUNCTION {
        return True;
    } elif op == Opcode.MAKE_ARROW {
        return True;
    } elif op == Opcode.MAKE_CLASS {
        return True;
    } elif op == Opcode.PUSH_CATCH {
        return True;
    } elif op == Opcode.PUSH_FINALLY {
        return True;
    } elif op == Opcode.UNPACK_ARRAY {
        return True;
    } elif op == Opcode.UNPACK_OBJECT {
        return True;
    } elif op == Opcode.IMPORT {
        return True;
    } elif op == Opcode.EXPORT {
        return True;
    } elif op == Opcode.REEXPORT_LIVE {
        return True;
    } elif op == Opcode.DEFINE_METHOD {
        return True;
    } elif op == Opcode.SUPER_CALL {
        return True;
    } elif op == Opcode.DEFINE_FIELD {
        return True;
    } elif op == Opcode.MAKE_CELL {
        return True;
    } elif op == Opcode.LOAD_DEREF {
        return True;
    } elif op == Opcode.STORE_DEREF {
        return True;
    } elif op == Opcode.DEFINE_GETTER {
        return True;
    } elif op == Opcode.DEFINE_SETTER {
        return True;
    } elif op == Opcode.MAKE_REGEXP {
        return True;
    }
    # DYNAMIC_IMPORT has no arg — specifier is on stack
    else {
        return False;
    }
}

"""Public alias for `_opname` — returns the mnemonic string for an opcode.
Used by debug-trace helpers in vm.na.jac and compiler.na.jac."""
def:pub opcode_name(op: Opcode) -> str {
    return _opname(op);
}

"""Map an Opcode to its stable integer id (== its enum value). -1 = unknown.
The `.jsbc` bytecode serializer (jsbc.na.jac) uses this to persist opcodes as
ints. Do NOT replace with `int(op)` — the native backend does not lower
`int(<tagged enum>)` to the enum value (verified). Keep exhaustive + in sync with
`enum Opcode`."""
def:pub opcode_to_int(op: Opcode) -> int {
    if op == Opcode.LOAD_CONST {
        return 0;
    } elif op == Opcode.LOAD_UNDEFINED {
        return 1;
    } elif op == Opcode.LOAD_NULL {
        return 2;
    } elif op == Opcode.LOAD_TRUE {
        return 3;
    } elif op == Opcode.LOAD_FALSE {
        return 4;
    } elif op == Opcode.POP {
        return 5;
    } elif op == Opcode.DUP {
        return 6;
    } elif op == Opcode.SWAP {
        return 7;
    } elif op == Opcode.LOAD_LOCAL {
        return 8;
    } elif op == Opcode.STORE_LOCAL {
        return 9;
    } elif op == Opcode.LOAD_GLOBAL {
        return 10;
    } elif op == Opcode.STORE_GLOBAL {
        return 11;
    } elif op == Opcode.LOAD_FREE {
        return 12;
    } elif op == Opcode.STORE_FREE {
        return 13;
    } elif op == Opcode.NEW_OBJECT {
        return 14;
    } elif op == Opcode.NEW_ARRAY {
        return 15;
    } elif op == Opcode.GET_PROP {
        return 16;
    } elif op == Opcode.SET_PROP {
        return 17;
    } elif op == Opcode.DEL_PROP {
        return 18;
    } elif op == Opcode.GET_INDEX {
        return 19;
    } elif op == Opcode.SET_INDEX {
        return 20;
    } elif op == Opcode.HAS_PROP {
        return 21;
    } elif op == Opcode.GET_ITER {
        return 22;
    } elif op == Opcode.ITER_NEXT {
        return 23;
    } elif op == Opcode.ADD {
        return 24;
    } elif op == Opcode.SUB {
        return 25;
    } elif op == Opcode.MUL {
        return 26;
    } elif op == Opcode.DIV {
        return 27;
    } elif op == Opcode.MOD {
        return 28;
    } elif op == Opcode.POW {
        return 29;
    } elif op == Opcode.NEG {
        return 30;
    } elif op == Opcode.BAND {
        return 31;
    } elif op == Opcode.BOR {
        return 32;
    } elif op == Opcode.BXOR {
        return 33;
    } elif op == Opcode.BNOT {
        return 34;
    } elif op == Opcode.SHL {
        return 35;
    } elif op == Opcode.SHR {
        return 36;
    } elif op == Opcode.USHR {
        return 37;
    } elif op == Opcode.EQ {
        return 38;
    } elif op == Opcode.NEQ {
        return 39;
    } elif op == Opcode.LT {
        return 40;
    } elif op == Opcode.LTE {
        return 41;
    } elif op == Opcode.GT {
        return 42;
    } elif op == Opcode.GTE {
        return 43;
    } elif op == Opcode.STRICT_EQ {
        return 44;
    } elif op == Opcode.STRICT_NEQ {
        return 45;
    } elif op == Opcode.INSTANCEOF {
        return 46;
    } elif op == Opcode.IN {
        return 47;
    } elif op == Opcode.NOT {
        return 48;
    } elif op == Opcode.TYPEOF {
        return 49;
    } elif op == Opcode.VOID {
        return 50;
    } elif op == Opcode.DELETE {
        return 51;
    } elif op == Opcode.JUMP {
        return 52;
    } elif op == Opcode.JUMP_IF_TRUE {
        return 53;
    } elif op == Opcode.JUMP_IF_FALSE {
        return 54;
    } elif op == Opcode.JUMP_IF_NULL {
        return 55;
    } elif op == Opcode.JUMP_IF_UNDEFINED {
        return 56;
    } elif op == Opcode.CALL {
        return 57;
    } elif op == Opcode.CALL_METHOD {
        return 58;
    } elif op == Opcode.NEW {
        return 59;
    } elif op == Opcode.RETURN {
        return 60;
    } elif op == Opcode.RETURN_UNDEFINED {
        return 61;
    } elif op == Opcode.MAKE_FUNCTION {
        return 62;
    } elif op == Opcode.MAKE_ARROW {
        return 63;
    } elif op == Opcode.MAKE_CLASS {
        return 64;
    } elif op == Opcode.AWAIT {
        return 65;
    } elif op == Opcode.YIELD {
        return 66;
    } elif op == Opcode.YIELD_STAR {
        return 67;
    } elif op == Opcode.THROW {
        return 68;
    } elif op == Opcode.PUSH_CATCH {
        return 69;
    } elif op == Opcode.POP_CATCH {
        return 70;
    } elif op == Opcode.PUSH_FINALLY {
        return 71;
    } elif op == Opcode.POP_FINALLY {
        return 72;
    } elif op == Opcode.SPREAD {
        return 73;
    } elif op == Opcode.REST_ARGS {
        return 74;
    } elif op == Opcode.UNPACK_ARRAY {
        return 75;
    } elif op == Opcode.UNPACK_OBJECT {
        return 76;
    } elif op == Opcode.NOP {
        return 77;
    } elif op == Opcode.DEBUGGER {
        return 78;
    } elif op == Opcode.IMPORT {
        return 79;
    } elif op == Opcode.EXPORT {
        return 80;
    } elif op == Opcode.LOAD_SELF {
        return 81;
    } elif op == Opcode.LOAD_THIS {
        return 82;
    } elif op == Opcode.OBJECT_SPREAD {
        return 83;
    } elif op == Opcode.ITER_NEXT_VAL {
        return 84;
    } elif op == Opcode.DEFINE_METHOD {
        return 85;
    } elif op == Opcode.SUPER_CALL {
        return 86;
    } elif op == Opcode.LOAD_SUPER_PROTO {
        return 87;
    } elif op == Opcode.DEFINE_FIELD {
        return 88;
    } elif op == Opcode.MAKE_CELL {
        return 89;
    } elif op == Opcode.LOAD_DEREF {
        return 90;
    } elif op == Opcode.STORE_DEREF {
        return 91;
    } elif op == Opcode.DYNAMIC_IMPORT {
        return 92;
    } elif op == Opcode.TO_NUMBER {
        return 93;
    } elif op == Opcode.DEFINE_GETTER {
        return 94;
    } elif op == Opcode.DEFINE_SETTER {
        return 95;
    } elif op == Opcode.GET_ASYNC_ITER {
        return 96;
    } elif op == Opcode.ASYNC_ITER_NEXT {
        return 97;
    } elif op == Opcode.TDZ_CLASS {
        return 98;
    } elif op == Opcode.MAKE_REGEXP {
        return 99;
    } elif op == Opcode.TO_STRING {
        return 100;
    } elif op == Opcode.IMPORT_META {
        return 101;
    } elif op == Opcode.REEXPORT_STAR {
        return 102;
    } elif op == Opcode.REEXPORT_LIVE {
        return 103;
    } elif op == Opcode.LOAD_HOLE {
        return 104;
    } elif op == Opcode.LOAD_LOCAL_CHECKED {
        return 105;
    } elif op == Opcode.STORE_NEW_CELL {
        return 106;
    } elif op == Opcode.STORE_MODULE_GLOBAL {
        return 107;
    } elif op == Opcode.ITER_CLOSE {
        return 108;
    } elif op == Opcode.WITH_PUSH {
        return 109;
    } elif op == Opcode.WITH_POP {
        return 110;
    } elif op == Opcode.LOAD_NAME {
        return 111;
    } elif op == Opcode.STORE_NAME {
        return 112;
    } elif op == Opcode.USING_DECLARE {
        return 113;
    } elif op == Opcode.DISPOSE_MARK {
        return 114;
    } elif op == Opcode.DISPOSE_RUN {
        return 115;
    } elif op == Opcode.REQUIRE_COERCIBLE {
        return 116;
    } elif op == Opcode.ITER_CLOSE_NRML {
        return 117;
    } elif op == Opcode.ITER_CLOSE_THRW {
        return 118;
    } elif op == Opcode.CHECK_PRIVATE {
        return 119;
    } elif op == Opcode.TO_PROPERTY_KEY {
        return 120;
    } elif op == Opcode.DEL_NAME {
        return 121;
    } elif op == Opcode.SUPER_GET_PROP {
        return 122;
    } elif op == Opcode.SUPER_GET_INDEX {
        return 123;
    } elif op == Opcode.SUPER_SET_PROP {
        return 124;
    } elif op == Opcode.SUPER_SET_INDEX {
        return 125;
    } elif op == Opcode.INFER_NAME_FROM_KEY {
        return 126;
    } elif op == Opcode.LOAD_NEW_TARGET {
        return 127;
    } elif op == Opcode.TEMPLATE_OBJECT {
        return 128;
    } elif op == Opcode.LOAD_NAME_REF {
        return 129;
    } elif op == Opcode.STORE_NAME_REF {
        return 130;
    } elif op == Opcode.LOAD_CLASS_BRAND {
        return 131;
    } elif op == Opcode.CREATE_GLOBAL_FN_BINDING {
        return 132;
    } elif op == Opcode.RUN_STATIC_ELEMENTS {
        return 133;
    } elif op == Opcode.TAIL_CALL {
        return 134;
    } elif op == Opcode.INSTALL_BRAND {
        return 135;
    } elif op == Opcode.FINALLY_ENTER {
        return 136;
    } elif op == Opcode.FINALLY_RETHROW {
        return 137;
    } elif op == Opcode.FILLER {
        return 138;
    } elif op == Opcode.LOCAL_INC {
        return 139;
    } elif op == Opcode.BR_CMP_LL {
        return 140;
    } elif op == Opcode.GET_LL_INDEX {
        return 141;
    } elif op == Opcode.SET_LL_INDEX {
        return 142;
    } elif op == Opcode.GET_LLC_PROP {
        return 143;
    } elif op == Opcode.SET_THIS_PROP {
        return 144;
    } elif op == Opcode.SET_LL_PROP {
        return 145;
    } elif op == Opcode.PROP_INC {
        return 146;
    }
    return -1;
}

"""Inverse of `opcode_to_int`: map an integer id back to its Opcode. Returns NOP
for an out-of-range id (should not occur on a valid, version-matched .jsbc)."""
def:pub opcode_from_int(n: int) -> Opcode {
    if n == 0 {
        return Opcode.LOAD_CONST;
    } elif n == 1 {
        return Opcode.LOAD_UNDEFINED;
    } elif n == 2 {
        return Opcode.LOAD_NULL;
    } elif n == 3 {
        return Opcode.LOAD_TRUE;
    } elif n == 4 {
        return Opcode.LOAD_FALSE;
    } elif n == 5 {
        return Opcode.POP;
    } elif n == 6 {
        return Opcode.DUP;
    } elif n == 7 {
        return Opcode.SWAP;
    } elif n == 8 {
        return Opcode.LOAD_LOCAL;
    } elif n == 9 {
        return Opcode.STORE_LOCAL;
    } elif n == 10 {
        return Opcode.LOAD_GLOBAL;
    } elif n == 11 {
        return Opcode.STORE_GLOBAL;
    } elif n == 12 {
        return Opcode.LOAD_FREE;
    } elif n == 13 {
        return Opcode.STORE_FREE;
    } elif n == 14 {
        return Opcode.NEW_OBJECT;
    } elif n == 15 {
        return Opcode.NEW_ARRAY;
    } elif n == 16 {
        return Opcode.GET_PROP;
    } elif n == 17 {
        return Opcode.SET_PROP;
    } elif n == 18 {
        return Opcode.DEL_PROP;
    } elif n == 19 {
        return Opcode.GET_INDEX;
    } elif n == 20 {
        return Opcode.SET_INDEX;
    } elif n == 21 {
        return Opcode.HAS_PROP;
    } elif n == 22 {
        return Opcode.GET_ITER;
    } elif n == 23 {
        return Opcode.ITER_NEXT;
    } elif n == 24 {
        return Opcode.ADD;
    } elif n == 25 {
        return Opcode.SUB;
    } elif n == 26 {
        return Opcode.MUL;
    } elif n == 27 {
        return Opcode.DIV;
    } elif n == 28 {
        return Opcode.MOD;
    } elif n == 29 {
        return Opcode.POW;
    } elif n == 30 {
        return Opcode.NEG;
    } elif n == 31 {
        return Opcode.BAND;
    } elif n == 32 {
        return Opcode.BOR;
    } elif n == 33 {
        return Opcode.BXOR;
    } elif n == 34 {
        return Opcode.BNOT;
    } elif n == 35 {
        return Opcode.SHL;
    } elif n == 36 {
        return Opcode.SHR;
    } elif n == 37 {
        return Opcode.USHR;
    } elif n == 38 {
        return Opcode.EQ;
    } elif n == 39 {
        return Opcode.NEQ;
    } elif n == 40 {
        return Opcode.LT;
    } elif n == 41 {
        return Opcode.LTE;
    } elif n == 42 {
        return Opcode.GT;
    } elif n == 43 {
        return Opcode.GTE;
    } elif n == 44 {
        return Opcode.STRICT_EQ;
    } elif n == 45 {
        return Opcode.STRICT_NEQ;
    } elif n == 46 {
        return Opcode.INSTANCEOF;
    } elif n == 47 {
        return Opcode.IN;
    } elif n == 48 {
        return Opcode.NOT;
    } elif n == 49 {
        return Opcode.TYPEOF;
    } elif n == 50 {
        return Opcode.VOID;
    } elif n == 51 {
        return Opcode.DELETE;
    } elif n == 52 {
        return Opcode.JUMP;
    } elif n == 53 {
        return Opcode.JUMP_IF_TRUE;
    } elif n == 54 {
        return Opcode.JUMP_IF_FALSE;
    } elif n == 55 {
        return Opcode.JUMP_IF_NULL;
    } elif n == 56 {
        return Opcode.JUMP_IF_UNDEFINED;
    } elif n == 57 {
        return Opcode.CALL;
    } elif n == 58 {
        return Opcode.CALL_METHOD;
    } elif n == 59 {
        return Opcode.NEW;
    } elif n == 60 {
        return Opcode.RETURN;
    } elif n == 61 {
        return Opcode.RETURN_UNDEFINED;
    } elif n == 62 {
        return Opcode.MAKE_FUNCTION;
    } elif n == 63 {
        return Opcode.MAKE_ARROW;
    } elif n == 64 {
        return Opcode.MAKE_CLASS;
    } elif n == 65 {
        return Opcode.AWAIT;
    } elif n == 66 {
        return Opcode.YIELD;
    } elif n == 67 {
        return Opcode.YIELD_STAR;
    } elif n == 68 {
        return Opcode.THROW;
    } elif n == 69 {
        return Opcode.PUSH_CATCH;
    } elif n == 70 {
        return Opcode.POP_CATCH;
    } elif n == 71 {
        return Opcode.PUSH_FINALLY;
    } elif n == 72 {
        return Opcode.POP_FINALLY;
    } elif n == 73 {
        return Opcode.SPREAD;
    } elif n == 74 {
        return Opcode.REST_ARGS;
    } elif n == 75 {
        return Opcode.UNPACK_ARRAY;
    } elif n == 76 {
        return Opcode.UNPACK_OBJECT;
    } elif n == 77 {
        return Opcode.NOP;
    } elif n == 78 {
        return Opcode.DEBUGGER;
    } elif n == 79 {
        return Opcode.IMPORT;
    } elif n == 80 {
        return Opcode.EXPORT;
    } elif n == 81 {
        return Opcode.LOAD_SELF;
    } elif n == 82 {
        return Opcode.LOAD_THIS;
    } elif n == 83 {
        return Opcode.OBJECT_SPREAD;
    } elif n == 84 {
        return Opcode.ITER_NEXT_VAL;
    } elif n == 85 {
        return Opcode.DEFINE_METHOD;
    } elif n == 86 {
        return Opcode.SUPER_CALL;
    } elif n == 87 {
        return Opcode.LOAD_SUPER_PROTO;
    } elif n == 88 {
        return Opcode.DEFINE_FIELD;
    } elif n == 89 {
        return Opcode.MAKE_CELL;
    } elif n == 90 {
        return Opcode.LOAD_DEREF;
    } elif n == 91 {
        return Opcode.STORE_DEREF;
    } elif n == 92 {
        return Opcode.DYNAMIC_IMPORT;
    } elif n == 93 {
        return Opcode.TO_NUMBER;
    } elif n == 94 {
        return Opcode.DEFINE_GETTER;
    } elif n == 95 {
        return Opcode.DEFINE_SETTER;
    } elif n == 96 {
        return Opcode.GET_ASYNC_ITER;
    } elif n == 97 {
        return Opcode.ASYNC_ITER_NEXT;
    } elif n == 98 {
        return Opcode.TDZ_CLASS;
    } elif n == 99 {
        return Opcode.MAKE_REGEXP;
    } elif n == 100 {
        return Opcode.TO_STRING;
    } elif n == 101 {
        return Opcode.IMPORT_META;
    } elif n == 102 {
        return Opcode.REEXPORT_STAR;
    } elif n == 103 {
        return Opcode.REEXPORT_LIVE;
    } elif n == 104 {
        return Opcode.LOAD_HOLE;
    } elif n == 105 {
        return Opcode.LOAD_LOCAL_CHECKED;
    } elif n == 106 {
        return Opcode.STORE_NEW_CELL;
    } elif n == 107 {
        return Opcode.STORE_MODULE_GLOBAL;
    } elif n == 108 {
        return Opcode.ITER_CLOSE;
    } elif n == 109 {
        return Opcode.WITH_PUSH;
    } elif n == 110 {
        return Opcode.WITH_POP;
    } elif n == 111 {
        return Opcode.LOAD_NAME;
    } elif n == 112 {
        return Opcode.STORE_NAME;
    } elif n == 113 {
        return Opcode.USING_DECLARE;
    } elif n == 114 {
        return Opcode.DISPOSE_MARK;
    } elif n == 115 {
        return Opcode.DISPOSE_RUN;
    } elif n == 116 {
        return Opcode.REQUIRE_COERCIBLE;
    } elif n == 117 {
        return Opcode.ITER_CLOSE_NRML;
    } elif n == 118 {
        return Opcode.ITER_CLOSE_THRW;
    } elif n == 119 {
        return Opcode.CHECK_PRIVATE;
    } elif n == 120 {
        return Opcode.TO_PROPERTY_KEY;
    } elif n == 121 {
        return Opcode.DEL_NAME;
    } elif n == 122 {
        return Opcode.SUPER_GET_PROP;
    } elif n == 123 {
        return Opcode.SUPER_GET_INDEX;
    } elif n == 124 {
        return Opcode.SUPER_SET_PROP;
    } elif n == 125 {
        return Opcode.SUPER_SET_INDEX;
    } elif n == 126 {
        return Opcode.INFER_NAME_FROM_KEY;
    } elif n == 127 {
        return Opcode.LOAD_NEW_TARGET;
    } elif n == 128 {
        return Opcode.TEMPLATE_OBJECT;
    } elif n == 129 {
        return Opcode.LOAD_NAME_REF;
    } elif n == 130 {
        return Opcode.STORE_NAME_REF;
    } elif n == 131 {
        return Opcode.LOAD_CLASS_BRAND;
    } elif n == 132 {
        return Opcode.CREATE_GLOBAL_FN_BINDING;
    } elif n == 133 {
        return Opcode.RUN_STATIC_ELEMENTS;
    } elif n == 134 {
        return Opcode.TAIL_CALL;
    } elif n == 135 {
        return Opcode.INSTALL_BRAND;
    } elif n == 136 {
        return Opcode.FINALLY_ENTER;
    } elif n == 137 {
        return Opcode.FINALLY_RETHROW;
    } elif n == 138 {
        return Opcode.FILLER;
    } elif n == 139 {
        return Opcode.LOCAL_INC;
    } elif n == 140 {
        return Opcode.BR_CMP_LL;
    } elif n == 141 {
        return Opcode.GET_LL_INDEX;
    } elif n == 142 {
        return Opcode.SET_LL_INDEX;
    } elif n == 143 {
        return Opcode.GET_LLC_PROP;
    } elif n == 144 {
        return Opcode.SET_THIS_PROP;
    } elif n == 145 {
        return Opcode.SET_LL_PROP;
    } elif n == 146 {
        return Opcode.PROP_INC;
    }
    return Opcode.NOP;
}


"""Return a human-readable disassembly of a CompiledFunction.

Format:
  function <name> (<nparams> params, <nlocals> locals):
    <offset>  <OPCODE>  [arg [arg2]]
    ...
"""
def:pub disassemble(fn: CompiledFunction) -> str {
    result: str = "function " + fn.name + " (";
    result = result + str(len(fn.params)) + " params, ";
    result = result + str(fn.num_locals) + " locals):\n";
    i: int = 0;
    n: int = len(fn.code);
    while i < n {
        ins: Instruction = fn.code[i];
        # Offset (4 chars wide)
        off: str = str(i);
        if i < 10 {
            off = "   " + off;
        } elif i < 100 {
            off = "  " + off;
        } elif i < 1000 {
            off = " " + off;
        }
        line: str = off + "  " + _opname(ins.opcode);
        if _has_arg(ins.opcode) {
            line = line + "  " + str(ins.arg);
            if ins.arg2 != 0 {
                line = line + "  " + str(ins.arg2);
            }
        }
        if ins.line != 0 {
            line = line + "                    ; line " + str(ins.line);
        }
        result = result + line + "\n";
        i = i + 1;
    }
    return result;
}
