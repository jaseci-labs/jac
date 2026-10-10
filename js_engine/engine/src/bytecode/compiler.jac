"""
Bytecode Compiler (AST → Instruction stream) for js_engine.

Walks the AST produced by  and emits Instruction sequences into
CompiledFunction objects.

Design:
  - fn_stack    : stack of CompiledFunctions currently being built
  - scope_stack : flat lexical scope list shared across all nesting levels
  - fn_scope_base: scope_stack index where each fn's scope chain starts
  - Loop backpatching via LoopContext (break/continue patches)
  - Jump backpatching: emit placeholder arg=-1, then patch_jump()
  - Cross-function name refs → global (closure TBD )

Bun reference: Bun uses JSC BytecodeGenerator (C++); we build our own.
ECMAScript spec: §14 Executable Code and Execution Contexts
"""

import from engine.src.bytecode.compiler_ops { compiler_op_for_binary }
import from engine.src.bytecode.optimizer { optimize_fn }
import from engine.src.bytecode.op {
    Opcode,
    Instruction,
    CompiledFunction,
    make_compiled_fn,
    make_instruction,
    make_op,
    opcode_name  # for compiler emit trace
}

import from engine.src.parser.ast { ASTNode, ASTNodeType }
import from engine.src.runtime.jsstring { str_substr, utf8_encode_scalar }
import from engine.src.runtime.mem { byte_chr }

# ══════════════════════════════════════════════════════════════════════════════
# Debug tracing
# ══════════════════════════════════════════════════════════════════════════════

"""Set to True to enable compiler emit-trace debug output."""
glob COMPILER_DEBUG_MODE: bool = False;

# Process-wide monotonic base for tagged-template site ids.  Each compilation
# (main script, every `eval`, every `new Function`) seeds its local template-site
# counter from here and advances it, so a template site is globally unique across
# compilations — two separate `eval` calls of identical source are DIFFERENT sites
# and get DIFFERENT cached arrays (ES §13.2.8.4), while a loop within one eval
# reuses its single site.
glob _TEMPLATE_SITE_BASE: int = 0;

"""Print msg when COMPILER_DEBUG_MODE is True."""
def compiler_debug(msg: str) {
    print("[COMPILER]", msg);
}

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Scope
# ══════════════════════════════════════════════════════════════════════════════

"""One level of lexical scope — tracks variable declarations."""
obj Scope {
    has vars: dict[str, int],
        var_kinds: dict[str, str],
        parent_idx: int,
        is_function: bool,
        slot_count: int;  # name → local slot index
}

# name → "var" | "let" | "const"
# index in Compiler.scope_stack (-1 = none)
# True iff this scope is a function boundary
# next free local slot (within this scope)
"""Create a new scope."""
def make_scope(parent_idx: int, is_function: bool) -> Scope {
    return Scope(
        vars={},
        var_kinds={},
        parent_idx=parent_idx,
        is_function=is_function,
        slot_count=0
    );
}

# ══════════════════════════════════════════════════════════════════════════════
# 2.  LoopContext
# ══════════════════════════════════════════════════════════════════════════════

"""Tracks pending break and continue jump addresses for one loop / switch."""
obj LoopContext {
    has label: str,
        break_addrs: list[int],
        cont_addrs: list[int],
        is_switch: bool,
        is_iteration: bool,
        is_for_of: bool,
        for_of_close_ip: int = -1;
}

# instruction indices needing break target
# instruction indices needing continue target
# switch: break only, continue skips to enclosing loop
# True for for/while/do/for-in/for-of; False for labeled blocks
# True for for-of / for await-of loops (IteratorClose on abrupt exit)
# IP of IteratorClose epilogue for for-of loops
def make_loop_ctx(label: str) -> LoopContext {
    return LoopContext(
        label=label,
        break_addrs=[],
        cont_addrs=[],
        is_switch=False,
        is_iteration=False,
        is_for_of=False
    );
}

"""One enclosing `try` finalizer, tracked so an abrupt exit (break/continue/return)
re-emits it before jumping out (ES §14.15.3). Stored in a dedicated obj (not a raw
`list[ASTNode]` field, which the native backend cannot lower on the Compiler
archetype) — mirrors how LoopContext is field-stored."""
obj FinalizerEntry {
    has fin_node: ASTNode,
        loop_depth: int,
        fn_base: int,
        live_regions: int = 0;  # the finalizer BlockStatement
}


# len(loop_stack) when this try was entered
# len(fn_scope_base) when this try was entered
# Number of runtime exception-handler regions (PUSH_FINALLY / PUSH_CATCH)
# currently live for THIS try at the point of compilation. An abrupt exit
# (break/continue/return) that jumps out of the try must emit exactly this
# many POP_CATCH ops before the finalizer runs, so the frame's catch_stack is
# not left with stale handlers (ES §14.15.3: finally runs, then control
# leaves the construct). Updated as compilation moves body → catch → done.
# ══════════════════════════════════════════════════════════════════════════════
# 3.  String literal unescaping
# ══════════════════════════════════════════════════════════════════════════════

"""
Strip ECMAScript numeric separators (`_`) from a numeric/bigint literal's raw
text (e.g. `1_000` → `1000`, `0x1_0` → `0x10`) so the constant-pool number parser
receives clean digits.  The lexer already validated separator placement (between
digits only), so a blind removal is safe here.
"""
def _strip_numeric_separators(raw: str) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(raw);
    while i < n {
        ch: str = raw[i];
        if ch != "_" {
            out = out + ch;
        }
        i = i + 1;
    }
    return out;
}

"""
Process JavaScript string escape sequences from a raw lexer token value.
The lexer stores escapes verbatim (e.g. backslash-n, backslash-quote);
this function converts them to the actual characters.
Handles: backslash-escapes for quote, n, r, t, b, f, v, 0, xXX, uXXXX
"""
def _unescape_string(raw: str) -> str {
    # append+join, not per-char `result + c` concat: that is O(n²) bytes per
    # literal and dominated the vite-bundle compile's allocation profile.
    result: list[str] = [];
    i: int = 0;
    n: int = len(raw);
    while i < n {
        c: str = raw[i];
        if c == "\\" and i + 1 < n {
            esc: str = raw[i + 1];
            i = i + 2;
            if esc == "\"" {
                result.append("\"");
            } elif esc == "'" {
                result.append("'");
            } elif esc == "\\" {
                result.append("\\");
            } elif esc == "n" {
                result.append("\n");
            } elif esc == "r" {
                result.append(chr(13));
            } elif esc == "t" {
                result.append(chr(9));
            } elif esc == "b" {
                result.append(chr(8));
            } elif esc == "f" {
                result.append(chr(12));
            } elif esc == "v" {
                result.append(chr(11));
            } elif esc == "u" {
                # \u{...} — braced code point (1+ hex digits up to 0x10FFFF)
                if i < n and raw[i] == "{" {
                    j: int = i + 1;
                    cpb: int = 0;
                    okb: bool = True;
                    nhex: int = 0;
                    while j < n and raw[j] != "}" {
                        chb: str = raw[j];
                        if chb >= "0" and chb <= "9" {
                            cpb = cpb * 16 + (ord(chb) - 48);
                        } elif chb >= "a" and chb <= "f" {
                            cpb = cpb * 16 + 10 + (ord(chb) - 97);
                        } elif chb >= "A" and chb <= "F" {
                            cpb = cpb * 16 + 10 + (ord(chb) - 65);
                        } else {
                            okb = False;
                        }
                        nhex = nhex + 1;
                        j = j + 1;
                    }
                    if okb and nhex > 0 and j < n and raw[j] == "}" {
                        i = j + 1;
                        if cpb == 0 {
                            result.append(utf8_encode_scalar(0));  # NUL sentinel
                        } else {
                            result.append(utf8_encode_scalar(cpb));
                        }
                    } else {
                        result.append("\\");
                        result.append(esc);
                    }
                }
                # \uXXXX — consume 4 hex digits
                elif i + 4 <= n {
                    hex4: str = "";
                    h: int = 0;
                    cp: int = 0;
                    ok: bool = True;
                    while h < 4 {
                        ch: str = raw[i + h];
                        if ch >= "0" and ch <= "9" {
                            cp = cp * 16 + (ord(ch) - 48);
                        } elif ch >= "a" and ch <= "f" {
                            cp = cp * 16 + 10 + (ord(ch) - 97);
                        } elif ch >= "A" and ch <= "F" {
                            cp = cp * 16 + 10 + (ord(ch) - 65);
                        } else {
                            ok = False;
                        }
                        h = h + 1;
                    }
                    if ok {
                        i = i + 4;
                        if cp == 0 {
                            result.append(utf8_encode_scalar(0));  # NUL sentinel
                        } else {
                            result.append(utf8_encode_scalar(cp));
                        }
                    } else {
                        result.append("\\");
                        result.append(esc);
                    }
                } else {
                    result.append("\\");
                    result.append(esc);
                }
            } elif esc == "x" {
                # \xXX — consume 2 hex digits
                if i + 2 <= n {
                    cp2: int = 0;
                    ok2: bool = True;
                    x: int = 0;
                    while x < 2 {
                        cx: str = raw[i + x];
                        if cx >= "0" and cx <= "9" {
                            cp2 = cp2 * 16 + (ord(cx) - 48);
                        } elif cx >= "a" and cx <= "f" {
                            cp2 = cp2 * 16 + 10 + (ord(cx) - 97);
                        } elif cx >= "A" and cx <= "F" {
                            cp2 = cp2 * 16 + 10 + (ord(cx) - 65);
                        } else {
                            ok2 = False;
                        }
                        x = x + 1;
                    }
                    if ok2 {
                        i = i + 2;
                        # Must UTF-8-encode like \\uXXXX / fromCharCode — raw chr(0xFE)
                        # is a lone Latin-1 byte and fails SameValue vs fromCharCode(254)
                        # (Annex B unescape("%fe") === "\\xfe").
                        if cp2 == 0 {
                            result.append(utf8_encode_scalar(0));  # NUL sentinel
                        } else {
                            result.append(utf8_encode_scalar(cp2));
                        }
                    } else {
                        result.append("\\");
                        result.append(esc);
                    }
                } else {
                    result.append("\\");
                    result.append(esc);
                }
            } elif esc == "\n" or esc == chr(13) {
                # LineContinuation (ES §12.9.4): `\` followed by a LineTerminator is
                # removed entirely (produces nothing).  `\<CR><LF>` is a single line
                # continuation — swallow the trailing LF too.
                if esc == chr(13) and i < n and raw[i] == "\n" {
                    i = i + 1;
                }
            } elif esc == byte_chr(226)
                and i + 1 < n
                and raw[i] == byte_chr(128)
                and (raw[i + 1] == byte_chr(168) or raw[i + 1] == byte_chr(169)) {
                # LineContinuation with a multi-byte LineTerminator: U+2028 LINE
                # SEPARATOR (0xE2 0x80 0xA8) or U+2029 PARAGRAPH SEPARATOR
                # (0xE2 0x80 0xA9). Jac strings are byte-indexed, so `esc` above only
                # captured the lead byte (0xE2); swallow the remaining two bytes so the
                # whole terminator is removed (produces nothing).
                i = i + 2;
            } elif esc >= "0" and esc <= "7" {
                # Legacy octal escape (Annex B.1.2): `\` + 1-3 octal digits (first digit
                # 0-3 allows 3 digits; 4-7 allows 2) → the character with that code.
                # `\0` NOT followed by an octal digit yields NUL (oct_v == 0 below).
                oct_v: int = ord(esc) - 48;
                oct_max: int = 3;
                if esc >= "4" {
                    oct_max = 2;
                }
                oct_cnt: int = 1;
                while oct_cnt < oct_max and i < n and raw[i] >= "0" and raw[i] <= "7" {
                    oct_v = oct_v * 8 + (ord(raw[i]) - 48);
                    i = i + 1;
                    oct_cnt = oct_cnt + 1;
                }
                if oct_v == 0 {
                    result.append(utf8_encode_scalar(0));  # NUL sentinel
                } else {
                    result.append(utf8_encode_scalar(oct_v));
                }
            } else {
                # Unknown escape — pass through the escaped char itself
                result.append(esc);
            }
        } else {
            result.append(c);
            i = i + 1;
        }
    }
    return "".join(result);
}

# ══════════════════════════════════════════════════════════════════════════════
# 3.  Compiler
# ══════════════════════════════════════════════════════════════════════════════

"""
Compiles an AST tree to a CompiledFunction (bytecode + constants + metadata).

Usage:
    c: Compiler = make_compiler();
    top: CompiledFunction = c.compile_program(nd);
"""
obj Compiler {
    has fn_stack: list[CompiledFunction],
        scope_stack: list[Scope],
        fn_scope_base: list[int],
        loop_stack: list[LoopContext],
        finalizer_stack: list[FinalizerEntry],
        all_fns: list[CompiledFunction],
        cell_slots: list[list[int]],
        esm_live_names: dict[str, bool] = {},
        esm_export_aliases: dict[str, str] = {},
        esm_import_bindings: dict[str, str] = {},
        esm_import_ns_globals: dict[str, str] = {},
        esm_exports_global: str = "__jac_esm_exports",
        source_file: str = "",
        in_default_params: bool = False,
        default_params_in_arrow: bool = False,
        in_block_fn_decl: bool = False,
        loop_body_depth: int = 0,
        loop_body_depth_stack: list[int] = [],
        had_error: bool = False,
        last_error_msg: str = "",
        default_param_body_vars: dict[str, bool] = {},
        param_names: dict[str, bool] = {},
        param_names_stack: list[dict[str, bool]] = [],
        default_param_body_vars_stack: list[dict[str, bool]] = [],
        dead_lexical_names: dict[str, bool] = {},
        dead_lexical_names_stack: list[dict[str, bool]] = [],
        lexical_names_seen: dict[str, bool] = {},
        lexical_names_seen_stack: list[dict[str, bool]] = [],
        global_var_names: dict[str, bool] = {},
        in_direct_eval: bool = False,
        eval_force_strict: bool = False,
        eval_in_param_expr: int = 0,
        super_prop_allowed: bool = False,
        super_call_allowed: bool = False,
        pending_super_prop: bool = False,
        pending_super_call: bool = False,
        super_is_static: bool = False,
        pending_super_static: bool = False,
        in_typeof_operand: bool = False,
        _using_block_seen: bool = False,
        with_depth: int = 0,
        _emit_tail_call: bool = False,
        _in_try_body: int = 0,
        _in_try_body_stack: list[int] = [],
        _dstr_iter_seq: int = 0,
        _template_site_seq: int = 0,
        cv_slot: int = -1,
        cv_slot_stack: list[int] = [],
        in_class_body: int = 0,
        _pending_infer_class_name: str = "",
        priv_scope_seq: int = 0,
        priv_scope_ids: list[int] = [],
        priv_scope_names: list[dict[str, bool]] = [],
        hoist_predeclared: dict[str, bool] = {},
        param_body_var_slots: dict[str, int] = {},
        param_body_var_slots_stack: list[dict[str, int]] = [],
        param_body_split: bool = False,
        param_body_split_stack: list[bool] = [],
        catch_param_names: dict[str, bool] = {},
        catch_param_names_stack: list[dict[str, bool]] = [],
        fn_self_name: str = "",
        fn_self_name_stack: list[str] = [],
        param_tdz: dict[str, bool] = {},
        lexical_global_names: dict[str, bool] = {},
        annexb_block_fn_names: dict[str, bool] = {},
        annexb_block_fn_names_stack: list[dict[str, bool]] = [],
        reuse_predeclared_lexical: bool = False,
        eval_field_forbid: bool = False,
        eval_forbid_newtarget: bool = False,
        catch_pattern_param_names: dict[str, bool] = {},
        catch_pattern_param_names_stack: list[dict[str, bool]] = [],
        block_fn_decl_names: dict[str, bool] = {},
        block_fn_decl_names_stack: list[dict[str, bool]] = [],
        _last_key_id: int = 0,
        program_annexb_fn_names: list[str] = [],
        source_text: str = "",
        _aa_src_len: int = -1,
        _aa_start: list[int] = [],
        _aa_end: list[int] = [],
        compiling_module: bool = False,
        eval_priv_keys: list[str] = [],
        eval_priv_mangles: list[str] = [];  # functions being built; last = current

    # ── low-level helpers ────────────────────────────────────────────────────

    """Return the CompiledFunction currently being built."""
    def _fn -> CompiledFunction {
        return self.fn_stack[len(self.fn_stack) - 1];
    }

    """Append a raw Instruction."""
    def _emit(instr: Instruction) {
        fn: CompiledFunction = self._fn();
        if COMPILER_DEBUG_MODE {
            compiler_debug(
                "  emit ["
                    + fn.name
                    + " ip="
                    + str(len(fn.code))
                    + "] "
                    + opcode_name(instr.opcode)
                    + " arg="
                    + str(instr.arg)
            );
        }
        fn.code.append(instr);
    }

    """Emit a no-arg opcode."""
    def _op(op: Opcode) {
        fn: CompiledFunction = self._fn();
        if COMPILER_DEBUG_MODE {
            compiler_debug(
                "  emit ["
                    + fn.name
                    + " ip="
                    + str(len(fn.code))
                    + "] "
                    + opcode_name(op)
            );
        }
        fn.code.append(make_op(op));
    }

    """Intern a string constant and emit LOAD_CONST idx."""
    def _const(val: str) {
        fn: CompiledFunction = self._fn();
        idx: int = fn.constants.add(val);
        fn.code.append(make_instruction(Opcode.LOAD_CONST, idx, 0, 0));
    }

    """True when name is an export let/const stored on __jac_esm_exports."""
    def _is_esm_live(name: str) -> bool {
        return name in self.esm_live_names;
    }

    """Load an export let/const binding from __jac_esm_exports."""
    def _emit_esm_live_load(name: str) {
        self._emit(
            make_instruction(
                Opcode.LOAD_GLOBAL, self._intern(self.esm_exports_global), 0, 0
            )
        );
        self._emit_get_prop(name);
    }

    """Load a live imported binding (re-read from cached module namespace)."""
    def _emit_esm_import_load(name: str) {
        bind: str = self.esm_import_bindings[name];
        bind_colon: int = -1;
        bi: int = 0;
        while bi < len(bind) {
            if bind[bi] == ":" {
                bind_colon = bi;
            }
            bi = bi + 1;
        }
        ns_g: str = bind;
        imp_k: str = bind;
        if bind_colon >= 0 {
            ns_g = bind[0:bind_colon];
            imp_k = bind[bind_colon + 1:];
        }
        self._emit(make_instruction(Opcode.LOAD_GLOBAL, self._intern(ns_g), 0, 0));
        self._emit_get_prop(imp_k);
    }

    """Emit a compile-time TypeError for assignment to an ESM import binding.
    ECMAScript §10.4.6: import bindings are read-only; any assignment is a
    TypeError regardless of strict mode.
    Stack contract: pops one value (the RHS or its DUP) then throws."""
    def _emit_import_assign_error(name: str) {
        self._op(Opcode.POP);  # discard the to-be-assigned value
        self._emit(
            make_instruction(Opcode.LOAD_GLOBAL, self._intern("TypeError"), 0, 0)
        );
        self._const("s:Assignment to import binding '" + name + "' is not allowed");
        self._emit(make_instruction(Opcode.CALL, 1, 0, 0));
        self._op(Opcode.THROW);
    }

    """Store TOS into an export let/const/var on __jac_esm_exports."""
    def _emit_esm_live_store(name: str) {
        self._emit(
            make_instruction(
                Opcode.LOAD_GLOBAL, self._intern(self.esm_exports_global), 0, 0
            )
        );
        self._op(Opcode.SWAP);
        # define_own=1 → privileged namespace export write (exotic [[Set]] is always false).
        self._emit_set_prop(name, 0, 0, 1);
        self._op(Opcode.POP);
        # Also refresh any `export { name as alias }` live bindings.
        self._emit_esm_alias_stores(name);
    }

    """Register `exported` as a live alias of local binding `local`."""
    def _esm_alias_add(local: str, exported: str) -> None {
        if local not in self.esm_export_aliases {
            self.esm_export_aliases[local] = exported;
            return;
        }
        cur: str = self.esm_export_aliases[local];
        # Dedup: scan comma-separated entries.
        start: int = 0;
        ci: int = 0;
        n: int = len(cur);
        while ci <= n {
            if ci == n or cur[ci] == "," {
                if ci > start and cur[start:ci] == exported {
                    return;
                }
                start = ci + 1;
            }
            ci = ci + 1;
        }
        self.esm_export_aliases[local] = cur + "," + exported;
    }

    """
    After storing `local`, copy the current value onto each export alias installed
    by `export { local as exported }` so namespace observers see live updates.
    Aliases are comma-separated strings (not lists) to avoid Jac empty-list
    singleton aliasing with ConstantPool.values.
    """
    def _emit_esm_alias_stores(name: str) -> None {
        if name not in self.esm_export_aliases {
            return;
        }
        cur: str = self.esm_export_aliases[name];
        start: int = 0;
        ci: int = 0;
        n: int = len(cur);
        while ci <= n {
            if ci == n or cur[ci] == "," {
                if ci > start {
                    alias: str = cur[start:ci];
                    # Same-name `export { x }` after a live namespace store is already
                    # up to date; other aliases still need a copy.
                    if not (alias == name and self._is_esm_live(name)) {
                        # Stack layout for SET_PROP: [exports_obj, value].
                        self._emit(
                            make_instruction(
                                Opcode.LOAD_GLOBAL,
                                self._intern(self.esm_exports_global),
                                0,
                                0
                            )
                        );
                        if self._is_esm_live(name) {
                            self._emit(
                                make_instruction(
                                    Opcode.LOAD_GLOBAL,
                                    self._intern(self.esm_exports_global),
                                    0,
                                    0
                                )
                            );
                            self._emit_get_prop(name);
                        } else {
                            # Module-level `let`/`const` are locals of <main>, not
                            # globals. From a nested function (after STORE_FREE)
                            # resolve via free-var capture — LOAD_GLOBAL would
                            # throw ReferenceError (imported-self-update).
                            a_slot: int = self._resolve(name);
                            if a_slot >= 0 {
                                self._emit(
                                    make_instruction(Opcode.LOAD_LOCAL, a_slot, 0, 0)
                                );
                            } else {
                                a_free: int = self._capture(name);
                                if a_free >= 0 {
                                    self._emit(
                                        make_instruction(Opcode.LOAD_FREE, a_free, 0, 0)
                                    );
                                } else {
                                    self._emit(
                                        make_instruction(
                                            Opcode.LOAD_GLOBAL, self._intern(name), 0, 0
                                        )
                                    );
                                }
                            }
                        }
                        self._emit_set_prop(alias, 0, 0, 1);
                        self._op(Opcode.POP);
                    }
                }
                start = ci + 1;
            }
            ci = ci + 1;
        }
    }

    """Emit bytecode that throws SyntaxError at runtime (early error / invariant break)."""
    def _syntax_error(msg: str) {
        self.had_error = True;
        self.last_error_msg = msg;
        # Prefer a clean SyntaxError message; strip a redundant "SyntaxError: " prefix
        # so runtime Error.name + message don't double-prefix.
        throw_msg: str = msg;
        if throw_msg.startswith("SyntaxError: ") {
            throw_msg = throw_msg[13:];
        }
        self._const("s:" + throw_msg);
        self._op(Opcode.THROW);
    }

    """
    B7: True if the eval'd program `nd` introduces a binding named `arguments` or
    `eval` — `var`/`let`/`const`/`function` declarations (and bound patterns).
    Walks blocks / if / loops / try / switch / labels iteratively but NOT into
    nested function bodies (those are separate scopes). A nested FunctionDeclaration
    *named* `arguments`/`eval` at this level is itself a forbidden binding.
    """
    def _param_eval_has_forbidden_binding(nd: ASTNode, forbid_args: bool) -> bool {
        work: list[ASTNode] = [];
        for ch in nd.children {
            work.append(ch);
        }
        wi: int = 0;
        while wi < len(work) {
            s: ASTNode = work[wi];
            wi = wi + 1;
            t: ASTNodeType = s.ntype;
            if t == ASTNodeType.VariableDeclaration {
                for d in s.declarations {
                    if d.id is not None
                        and self._pattern_binds_forbidden(d.id, forbid_args) {
                        return True;
                    }
                }
            } elif t == ASTNodeType.FunctionDeclaration {
                # The function's own name is a binding in this scope; its params/body
                # are a nested scope and are NOT descended into.
                if s.id is not None and self._name_forbidden(s.id.name, forbid_args) {
                    return True;
                }
            } elif t == ASTNodeType.ClassDeclaration {
                if s.id is not None and self._name_forbidden(s.id.name, forbid_args) {
                    return True;
                }
            } else {
                # Descend into nested statement containers (not function bodies).
                for c in s.children {
                    work.append(c);
                }
                if s.body is not None and s.ntype != ASTNodeType.FunctionDeclaration {
                    work.append(s.body);
                }
                if s.consequent is not None {
                    work.append(s.consequent);
                }
                if s.alternate is not None {
                    work.append(s.alternate);
                }
            }
        }
        return False;
    }

    """True if `name` is a forbidden param-eval binding name: `eval` always, and
    `arguments` only when forbid_args (ordinary, non-arrow function)."""
    def _name_forbidden(name: str, forbid_args: bool) -> bool {
        if name == "eval" {
            return True;
        }
        if forbid_args and name == "arguments" {
            return True;
        }
        return False;
    }

    """True if a binding pattern (Identifier / Array / Object / Assignment / Rest)
    binds a forbidden name (`eval`, and `arguments` when forbid_args) anywhere."""
    def _pattern_binds_forbidden(p: ASTNode, forbid_args: bool) -> bool {
        pwork: list[ASTNode] = [p];
        pi: int = 0;
        while pi < len(pwork) {
            n: ASTNode = pwork[pi];
            pi = pi + 1;
            if n.ntype == ASTNodeType.Identifier {
                if self._name_forbidden(n.name, forbid_args) {
                    return True;
                }
            } elif n.ntype == ASTNodeType.ArrayPattern
                or n.ntype == ASTNodeType.ArrayExpression {
                for e in n.children {
                    pwork.append(e);
                }
            } elif n.ntype == ASTNodeType.ObjectPattern
                or n.ntype == ASTNodeType.ObjectExpression {
                for pr in n.properties {
                    if pr.ntype == ASTNodeType.RestElement {
                        if pr.argument is not None {
                            pwork.append(pr.argument);
                        }
                    } elif pr.shorthand {
                        # `{ arguments }` / `{ arguments = d }` — bound name is the key.
                        if pr.key is not None {
                            pwork.append(pr.key);
                        }
                    } elif pr.expression is not None {
                        pwork.append(pr.expression);
                    }
                }
            } elif n.ntype == ASTNodeType.AssignmentPattern {
                if n.left is not None {
                    pwork.append(n.left);
                }
            } elif n.ntype == ASTNodeType.RestElement {
                if n.argument is not None {
                    pwork.append(n.argument);
                }
            }
        }
        return False;
    }

    """Strict mode: assign to global only if the binding already exists."""
    def _emit_strict_store_global(name: str) {
        # Strict store: STORE_GLOBAL with arg2=1 makes the VM throw ReferenceError
        # when the name has no binding anywhere (an unresolvable reference), while a
        # binding that merely holds `undefined` stores normally.  (The old value-probe
        # wrongly threw for any `var x;`-declared global still holding undefined.)
        self._emit(make_instruction(Opcode.STORE_GLOBAL, self._intern(name), 1, 0));
    }

    """Emit bytecode that throws ReferenceError at runtime."""
    def _emit_reference_error(msg: str) {
        self._emit(
            make_instruction(Opcode.LOAD_GLOBAL, self._intern("ReferenceError"), 0, 0)
        );
        self._const("s:" + msg);
        self._emit(make_instruction(Opcode.CALL, 1, 0, 0));
        self._op(Opcode.THROW);
    }

    """Emit TypeError for assignment to a const binding."""
    def _emit_const_assign_error(name: str) {
        self._op(Opcode.POP);
        self._emit(
            make_instruction(Opcode.LOAD_GLOBAL, self._intern("TypeError"), 0, 0)
        );
        self._const("s:Assignment to constant variable.");
        self._emit(make_instruction(Opcode.CALL, 1, 0, 0));
        self._op(Opcode.THROW);
    }

    """Intern a name into the constant pool WITHOUT emitting LOAD_CONST.
    Used for LOAD_GLOBAL/STORE_GLOBAL where the name is encoded in arg."""
    def _intern(name: str) -> int {
        fn: CompiledFunction = self._fn();
        return fn.constants.add(name);
    }

    """Constant-pool index for a property/global name.

    `_last_key_id` is left at 0 (the "uncached" encoding for arg2/arg3), so the
    VM interns the key ONCE on first execution and self-patches the instruction
    (see _ins_cached_key_arg2 / _ins_cached_set_prop_key in vm.jac). We do NOT
    pre-intern here (adel added a compile-time str_intern that:
      (1) crashes js_compiler, which by design has no realm/str-intern table, and
      (2) bakes realm-specific, insertion-order-dependent intern ids into the
          portable .jsbc — a correctness hazard, since the runtime realm assigns
          different ids). The VM's lazy runtime interning gives the same hot-path
          caching without either problem. Returns the constant-pool index."""
    def _intern_key(name: str) -> int {
        self._last_key_id = 0;
        return self._intern(name);
    }

    """Emit GET_PROP with compile-time-cached intern id in arg2."""
    def _emit_get_prop(name: str, line: int = 0) {
        idx: int = self._intern_key(name);
        self._emit(make_instruction(Opcode.GET_PROP, idx, self._last_key_id, line));
    }

    """Emit SET_PROP with intern id encoded in arg3 as `(kid<<1)|define_own`."""
    def _emit_set_prop(name: str, strict: int = 0, line: int = 0, define_own: int = 0) {
        idx: int = self._intern_key(name);
        encoded: int = (self._last_key_id << 1) | (1 if define_own != 0 else 0);
        self._emit(make_instruction(Opcode.SET_PROP, idx, strict, line, encoded));
    }

    """
    Store a top-level declared binding into the module globals map only.
    CJS top-level var/function/class must not become own properties of globalThis.
    """
    def _emit_store_global_decl(name: str) {
        idx: int = self._intern(name);
        if len(self.fn_scope_base) == 1 {
            # Top-level binding. Classic scripts and modules both keep the binding in the
            # VM-wide globals map (visible to `new Function`, forward refs, etc.), so we
            # stay on STORE_MODULE_GLOBAL. But a CLASSIC SCRIPT's top-level var/function/
            # class is ALSO an own property of the global object (§16.1.7
            # GlobalDeclarationInstantiation → CreateGlobalVarBinding), so `globalThis.x`
            # must see it. arg2=1 tells the VM to mirror the value onto global_this; a
            # MODULE (arg2=0) keeps its top-level bindings OFF globalThis. EVAL code is
            # also excluded: EvalDeclarationInstantiation routes var bindings to the
            # caller's varEnv (direct eval) or a fresh/own env (strict eval) — a strict
            # or direct eval must NOT create a globalThis property (test262 eval-code
            # indirect/var-env-var-strict, direct arrow `var arguments`). in_direct_eval
            # is set for both direct and indirect eval compilation.
            _sgd_mirror: int = 0
                if (self.compiling_module or self.in_direct_eval)
                else 1;
            self._emit(
                make_instruction(Opcode.STORE_MODULE_GLOBAL, idx, _sgd_mirror, 0)
            );
        } else {
            self._emit(make_instruction(Opcode.STORE_GLOBAL, idx, 0, 0));
        }
    }

    """Map a property name to its internal storage key.
    Private names (starting with #) are mangled to `__priv_#name@<scope>` so that
    bracket-notation access via c["#count"] cannot reach them AND same-named private
    members in different classes (e.g. `#m` in both a super and a subclass) stay
    distinct.  <scope> is the id of the nearest enclosing class body that declares
    `#name` (ES PrivateEnvironment lexical resolution)."""
    def _prop_key(name: str) -> str {
        if len(name) > 0 and name[0] == "#" {
            # Nearest PrivateEnvironment first (class bodies opened in this unit).
            si: int = len(self.priv_scope_ids) - 1;
            while si >= 0 {
                if name in self.priv_scope_names[si] {
                    return "__priv_" + name + "@" + str(self.priv_scope_ids[si]);
                }
                si = si - 1;
            }
            # Direct-eval inheritance: caller's PrivateEnvironment (outer scopes).
            ep_i: int = 0;
            ep_n: int = len(self.eval_priv_keys);
            while ep_i < ep_n {
                if self.eval_priv_keys[ep_i] == name {
                    return self.eval_priv_mangles[ep_i];
                }
                ep_i = ep_i + 1;
            }
            # ES AllPrivateNamesValid: a private name not in the running
            # PrivateEnvironment is an early SyntaxError in direct eval (the
            # eval inherits the caller's private names via eval_priv_*). Outside
            # eval, keep the legacy bare-key fallback (runtime TypeError).
            if self.in_direct_eval {
                self._syntax_error(
                    "SyntaxError: Private name '" + name + "' is not defined"
                );
            }
            # No declaring scope found (e.g. a stray reference in invalid code, or a
            # name only used via `#x in obj` outside a class): fall back to the bare
            # mangled key so behaviour matches the pre-per-scope implementation.
            return "__priv_" + name;
        }
        return name;
    }

    """True if `name` is a private class member name (starts with `#`)."""
    def _is_private_name(name: str) -> bool {
        return len(name) > 0 and name[0] == "#";
    }

    """Enter a new class body's private scope: allocate a fresh scope id and record
    the private names it declares (fields, methods, accessors — instance and static).
    Returns the scope id (callers must pair with `_leave_priv_scope`)."""
    def _enter_priv_scope(nd: ASTNode) -> int {
        pnames: dict[str, bool] = {};
        for m in nd.children {
            if m.key is not None and not m.computed {
                mk: str = m.key.name;
                if len(mk) > 0 and mk[0] == "#" {
                    pnames[mk] = True;
                }
            }
        }
        sid: int = self.priv_scope_seq;
        self.priv_scope_seq = self.priv_scope_seq + 1;
        self.priv_scope_ids.append(sid);
        self.priv_scope_names.append(pnames);
        return sid;
    }

    def _leave_priv_scope {
        n: int = len(self.priv_scope_ids);
        if n > 0 {
            del self.priv_scope_ids[n - 1];
            del self.priv_scope_names[n - 1];
        }
    }

    """The per-instance private-method/accessor brand key for a class scope.
    Private *methods* and *accessors* live on the prototype, so prototype
    reachability alone can't tell whether a given instance has been branded (ES:
    PrivateMethodOrAccessorAdd runs during InitializeInstanceElements, i.e. AFTER
    super() returns for a derived class).  We install this marker on the instance at
    field-init time; the VM's brand check consults it for methods/accessors."""
    def _priv_brand_key(sid: int) -> str {
        return "__brand@" + str(sid);
    }

    """True if the class body declares at least one INSTANCE private member (field, method,
    or accessor). Such a class installs a per-instance brand marker (`__brand@<sid>` = this
    evaluation's brand) so a private access can enforce the per-evaluation identity
    (ES §6.2.12 / §15.7)."""
    def _class_needs_instance_brand(nd: ASTNode) -> bool {
        for m in nd.children {
            if not m.is_static
                and not m.computed
                and m.key is not None
                and self._is_private_name(m.key.name) {
                return True;
            }
        }
        return False;
    }

    """True if the class body declares at least one STATIC private member. The class object
    itself is stamped with the per-evaluation brand (static private access has `this` = the
    class object), so a static private read across evaluations is rejected (ES §15.7)."""
    def _class_needs_static_brand(nd: ASTNode) -> bool {
        for m in nd.children {
            if m.is_static
                and not m.computed
                and m.key is not None
                and self._is_private_name(m.key.name) {
                return True;
            }
        }
        return False;
    }

    """Emit a synthetic field that stamps `this` with this class's per-EVALUATION brand
    (`this.__brand@<sid> = <class brand>`, the value pushed by LOAD_CLASS_BRAND — the
    field-init closure captured `class_brand` at DEFINE_FIELD time). Registered like any
    field via DEFINE_FIELD (arg2 = is_static): an INSTANCE brand runs per-construct after
    super() for a derived class (exactly when private methods become accessible, ES §13.15.5);
    a STATIC brand runs once at class-def time with `this` = the class object. Class TOS."""
    def _emit_private_brand_install(sid: int, is_static: int) {
        brand_key: str = self._priv_brand_key(sid);
        self._push_fn("");
        self._op(Opcode.LOAD_THIS);  # [obj]
        self._op(Opcode.LOAD_CLASS_BRAND);  # [obj, val] (this eval's brand)
        # INSTALL_BRAND(brand_key): PrivateMethodOrAccessorAdd — a double install on the same
        # object (already has the OWN brand marker) is a TypeError; otherwise stamp it.
        self._emit(
            make_instruction(Opcode.INSTALL_BRAND, self._intern(brand_key), 0, 0)
        );
        self._op(Opcode.RETURN_UNDEFINED);
        bf: CompiledFunction = self._pop_fn();
        bf_idx: int = len(self.all_fns);
        self.all_fns.append(bf);
        self._emit(make_instruction(Opcode.MAKE_FUNCTION, bf_idx, 0, 0));
        self._emit(
            make_instruction(Opcode.DEFINE_FIELD, self._intern(brand_key), is_static, 0)
        );
    }

    """LOAD_SUPER_PROTO arg2: 1 when the enclosing method/accessor is static (super
    resolves against the super class itself), else 0 (super.prototype)."""
    def _super_static_arg -> int {
        if self.super_is_static {
            return 1;
        }
        return 0;
    }

    """Pre-hook for ES §15.7.14 NamedEvaluation of an anonymous class expression.
    Call IMMEDIATELY BEFORE compile_expr(expr): if `expr` is an anonymous class, stash
    the inferred name so compile_class_expr applies it inside class evaluation (before
    static elements), matching the spec order. No-op for anything else. Pair with
    _maybe_infer_fn_name after compile_expr (which then skips the class case)."""
    def _pre_infer_class_name(expr: ASTNode, inferred: str) -> bool {
        if expr is None {
            return False;
        }
        if expr.ntype == ASTNodeType.ClassExpression and expr.id is None {
            self._pending_infer_class_name = inferred;
            return True;  # compile_class_expr will apply the name; caller must NOT also
            # call _maybe_infer_fn_name for this class (would double-store).
        }
        return False;
    }

    """True if `expr` can hold a proper tail call in tail position (ES §15.10.3): a direct
    CallExpression, or an operator whose tail sub-expression can (&&/||/??/?:/comma). Used to
    decide whether to set _emit_tail_call for `return <expr>`; the operator compile_* fns then
    route the flag to the genuinely-tail sub-expressions only. `new`/optional-call are NOT
    tail calls, so those callee forms fall out at compile_call (they don't emit TAIL_CALL)."""
    def _is_tail_position_expr(expr: ASTNode | None) -> bool {
        if expr is None {
            return False;
        }
        if expr.ntype == ASTNodeType.CallExpression {
            return True;
        }
        if expr.ntype == ASTNodeType.LogicalExpression {
            return self._is_tail_position_expr(expr.right);
        }
        if expr.ntype == ASTNodeType.ConditionalExpression {
            return self._is_tail_position_expr(expr.consequent)
                or self._is_tail_position_expr(expr.alternate);
        }
        if expr.ntype == ASTNodeType.SequenceExpression {
            ns: int = len(expr.expressions);
            if ns > 0 {
                return self._is_tail_position_expr(expr.expressions[ns - 1]);
            }
            return False;
        }
        return False;
    }

    """ECMAScript name inference (NamedEvaluation): if expr is an anonymous
    function/arrow/class expression, set its inferred name. Call immediately AFTER
    compile_expr(expr) while the last entry in all_fns is the function just compiled.
    For an anonymous class the name is applied via a late __CLASS_NAME__ store here.
    NOTE: call sites that instead want the name applied INSIDE class evaluation — so a
    static field initializer observes it (ES §15.7.14 step 18) — use _pre_infer_class_name
    BEFORE compile_expr and must NOT call this for the class (compile_class_expr handles it)."""
    def _maybe_infer_fn_name(expr: ASTNode, inferred: str) {
        if expr.ntype == ASTNodeType.FunctionExpression
            or expr.ntype == ASTNodeType.ArrowFunctionExpr {
            if expr.id is None and len(self.all_fns) > 0 {
                self.all_fns[len(self.all_fns) - 1].name = inferred;
            }
        } elif expr.ntype == ASTNodeType.ClassExpression {
            # Anonymous class: set __CLASS_NAME__ on the runtime object via bytecode.
            if expr.id is None {
                self._op(Opcode.DUP);
                self._const("s:" + inferred);
                cls_name_key_infer: int = self._intern("__CLASS_NAME__");
                self._emit(make_instruction(Opcode.SET_PROP, cls_name_key_infer, 0, 0));
                self._op(Opcode.POP);
            }
        }
    }

    """True when `expr` is an anonymous function/arrow whose `.name` should be
    inferred from a computed property key at runtime (INFER_NAME_FROM_KEY).  Named
    function expressions keep their own name; classes use the __CLASS_NAME__ path."""
    def _expr_is_anonymous_named(expr: ASTNode) -> bool {
        if expr is None {
            return False;
        }
        if expr.ntype == ASTNodeType.FunctionExpression
            or expr.ntype == ASTNodeType.ArrowFunctionExpr {
            return expr.id is None;
        }
        # An anonymous class expression also takes its name from the property key
        # (ES §15.7.4 NamedEvaluation) — `{ [sym]: class {} }` names the class.
        if expr.ntype == ASTNodeType.ClassExpression {
            return expr.id is None;
        }
        return False;
    }

    """Return the index of the next instruction to be emitted."""
    def _ip -> int {
        fn: CompiledFunction = self._fn();
        return len(fn.code);
    }

    """Emit a jump with placeholder target (0); return the instruction index."""
    def _jump(op: Opcode) -> int {
        fn: CompiledFunction = self._fn();
        addr: int = len(fn.code);
        fn.code.append(make_instruction(op, 0, 0, 0));
        return addr;
    }

    """Backpatch the jump at addr to the current instruction pointer.
    Uses full instruction replacement (not field mutation) to avoid Jac
    native list-subscript field-mutation bugs."""
    def _patch(addr: int) {
        fn: CompiledFunction = self._fn();
        old: Instruction = fn.code[addr];
        fn.code[addr] = make_instruction(old.opcode, len(fn.code), old.arg2, old.line);
    }

    """Backpatch the jump at addr to an explicit target.
    Uses full instruction replacement for the same reason as _patch."""
    def _patch_to(addr: int, target: int) {
        fn: CompiledFunction = self._fn();
        old: Instruction = fn.code[addr];
        fn.code[addr] = make_instruction(old.opcode, target, old.arg2, old.line);
    }

    # ── scope management ──────────────────────────────────────────────────

    """
    Push a new scope.
    For block scopes the slot counter is inherited from the parent so that
    nested blocks do not reuse the same slot indices as their siblings.
    """
    def _push_scope(is_function: bool) {
        parent: int = len(self.scope_stack) - 1;
        sc: Scope = make_scope(parent, is_function);
        if not is_function and parent >= 0 {
            sc.slot_count = self.scope_stack[parent].slot_count;
        }
        self.scope_stack.append(sc);
        # Per-block FunctionDeclaration name set (Annex B.3.3.4 redeclaration).
        self.block_fn_decl_names_stack.append(self.block_fn_decl_names);
        self.block_fn_decl_names = {};
    }

    """Pop innermost scope; propagate the high-water slot count to the parent."""
    def _pop_scope -> None {
        n: int = len(self.scope_stack);
        if n == 0 {
            return;
        }
        popped: Scope = self.scope_stack[n - 1];
        if not popped.is_function and popped.parent_idx >= 0 {
            par: Scope = self.scope_stack[popped.parent_idx];
            if par.slot_count < popped.slot_count {
                par.slot_count = popped.slot_count;
            }
        }
        del self.scope_stack[n - 1];
        n_bfd: int = len(self.block_fn_decl_names_stack);
        if n_bfd > 0 {
            self.block_fn_decl_names = self.block_fn_decl_names_stack[n_bfd - 1];
            del self.block_fn_decl_names_stack[n_bfd - 1];
        }
        # Record let/const bindings that are no longer reachable in the scope chain.
        for dname in popped.vars {
            if dname in popped.var_kinds {
                dkind: str = popped.var_kinds[dname];
                if dkind == "let" or dkind == "const" {
                    # Annex B block-fn names keep a varEnv binding after the block
                    # exits — do not mark them dead-lexical (B.3.3.2 / B.3.3.3).
                    if self._resolve(dname) < 0
                        and dname not in self.global_var_names
                        and dname not in self.lexical_global_names
                        and dname not in self.annexb_block_fn_names {
                        self.dead_lexical_names[dname] = True;
                    }
                }
            }
        }
    }

    """Return the scope-stack index where the current function's scope starts."""
    def _fn_base -> int {
        return self.fn_scope_base[len(self.fn_scope_base) - 1];
    }

    """Scope-qualified key for hoist_predeclared — avoids inner-fn var clobbering outer let pre-decl."""
    def _hoist_predecl_key(name: str) -> str {
        return str(self._fn_base()) + ":" + name;
    }

    # ── variable declaration / resolution ─────────────────────────────────

    """Declare a lexical (let/const) binding for a destructuring-pattern target.

    A block pre-scan (_compile_block) may have already pre-declared this name and
    installed its TDZ sentinel, recording a `hoist_predeclared` flag.  When that
    flag is present, reuse the existing slot instead of calling `_declare` again
    (which would raise a false "already been declared" SyntaxError).  Mirrors the
    predeclare-consume path used for plain Identifier declarators in
    compile_var_decl."""
    def _declare_lex_binding(name: str, kind: str) -> int {
        if kind == "let" or kind == "const" {
            hp_key: str = self._hoist_predecl_key(name);
            if hp_key in self.hoist_predeclared {
                del self.hoist_predeclared[hp_key];
                return self._resolve(name);
            }
        }
        return self._declare(name, kind);
    }

    """Allocate an anonymous local slot in the innermost scope (no name binding,
    no lexical/var bookkeeping). Used for engine-internal scratch storage such as
    the pending exception value saved across an exception-path finalizer. Keeps
    num_locals in sync so the VM reserves the slot."""
    def _alloc_scratch_slot -> int {
        sc: Scope = self.scope_stack[len(self.scope_stack) - 1];
        slot: int = sc.slot_count;
        sc.slot_count = sc.slot_count + 1;
        fn: CompiledFunction = self._fn();
        if fn.num_locals < sc.slot_count {
            fn.num_locals = sc.slot_count;
        }
        while len(fn.locals) <= slot {
            fn.locals.append("");
        }
        return slot;
    }

    """
    Declare name with the given kind ("var" | "let" | "const").
    "var" is hoisted to the function-boundary scope; let/const stay in
    the current block scope.  Returns the allocated local slot, or -1
    when the variable should live in the globals map.

    Top-level "var" declarations (those at the outermost script scope,
    i.e. len(fn_scope_base) == 1) are treated as true globals so that
    inner functions read and write the same binding via LOAD_GLOBAL /
    STORE_GLOBAL rather than capturing a by-value copy via LOAD_FREE /
    STORE_FREE.
    """
    def _declare(name: str, kind: str) -> int {
        target: int = len(self.scope_stack) - 1;
        fn_base: int = self._fn_base();
        # "fnhoist" — a top-level/module function declaration name.  Like "var"
        # it is function-scoped and freely redeclarable (with other functions or
        # with `var`), but unlike top-level "var" it must occupy a real local
        # slot of the <main> wrapper so each module keeps its own lexical scope.
        # It still produces a lexical conflict against a same-named let/const.
        if kind == "fnhoist" {
            # Module goal: top-level FunctionDeclarations are lexical.  Vars are
            # pre-recorded in global_var_names before the fnhoist pass, so a
            # same-named `var`/`function` pair must fail here (eval-script-code-target).
            if self.compiling_module and name in self.global_var_names {
                self._syntax_error(
                    "SyntaxError: Identifier '" + name + "' has already been declared"
                );
                return -1;
            }
            target = fn_base;
        } elif kind == "var" {
            # At top-level script scope (fn_scope_base has exactly one entry)
            # "var" becomes a true global — caller emits STORE_GLOBAL instead
            # of STORE_LOCAL, and ordinary name resolution falls through to
            # LOAD_GLOBAL / STORE_GLOBAL in every function that uses it.
            if len(self.fn_scope_base) == 1 {
                # Module goal: LexicallyDeclaredNames ∩ VarDeclaredNames — a
                # top-level `function` already bound as fnhoist conflicts with var.
                if self.compiling_module {
                    fn_sc_m: Scope = self.scope_stack[fn_base];
                    if name in fn_sc_m.vars {
                        fk_m: str = "var";
                        if name in fn_sc_m.var_kinds {
                            fk_m = fn_sc_m.var_kinds[name];
                        }
                        if fk_m == "fnhoist" {
                            self._syntax_error(
                                "SyntaxError: Identifier '"
                                    + name
                                    + "' has already been declared"
                            );
                            return -1;
                        }
                    }
                }
                self.global_var_names[name] = True;
                # Module goal: a top-level `var` is bound in the module environment
                # (ES §16.2.1.6.4 InitializeEnvironment), so it takes a local slot of
                # this module's <main> wrapper like a top-level function — not the
                # one VM-wide globals map, where every module's `var V` was the same
                # binding (minified bundles reuse short names; a later module's `V`
                # replaced an earlier module's). Exported vars keep their binding on
                # __jac_esm_exports.
                if not self.compiling_module
                    or self.in_direct_eval
                    or name in self.esm_live_names {
                    return -1;
                }
            }
            target = fn_base;
            # var hoisted to function scope must not conflict with let/const anywhere in function.
            # Annex B: a `var` may shadow an enclosing catch parameter of the same
            # name (`catch (e) { var e; }`), so catch-param bindings are exempt.
            chk_i: int = len(self.scope_stack) - 1;
            while chk_i >= fn_base {
                chk_sc: Scope = self.scope_stack[chk_i];
                if name in chk_sc.vars and name not in self.catch_param_names {
                    chk_k: str = "var";
                    if name in chk_sc.var_kinds {
                        chk_k = chk_sc.var_kinds[name];
                    }
                    if chk_k == "let" or chk_k == "const" {
                        self._syntax_error(
                            "SyntaxError: Identifier '"
                                + name
                                + "' has already been declared"
                        );
                        return -1;
                    }
                }
                chk_i = chk_i - 1;
            }
        } elif kind == "let" or kind == "const" {
            # let/const must not conflict with hoisted var at function scope (VARP-C-002):
            # `function f(){ var c; let c; }` is an early error.  This only applies when
            # the let/const is declared in the SAME scope as the var (the function base).
            # A let/const/catch-param in a deeper block legitimately shadows a
            # function-scoped var, so skip the check when target is a nested block.
            # Exclude parameters so for-head let may shadow param var (SCP-L-006).
            if target == fn_base {
                fn_sc: Scope = self.scope_stack[fn_base];
                if name in fn_sc.vars and name not in self.param_names {
                    fn_k: str = "var";
                    if name in fn_sc.var_kinds {
                        fn_k = fn_sc.var_kinds[name];
                    }
                    if fn_k == "var" or fn_k == "fnhoist" {
                        self._syntax_error(
                            "SyntaxError: Identifier '"
                                + name
                                + "' has already been declared"
                        );
                        return -1;
                    }
                }
            }
        }
        if target < 0 {
            return -1;
        }
        sc: Scope = self.scope_stack[target];
        # When a `var`/`fnhoist` is hoisted to an ANCESTOR scope (fn_base) while nested
        # block scopes are open — e.g. an Annex B.3.3 sloppy block-level function
        # declaration whose function-scoped `var f` is bound lazily *during* block
        # compilation — the ancestor's slot_count is stale: the open child block already
        # allocated slots past it. Allocating at the stale count would ALIAS a live
        # block binding (symptom: a function-scope `let` read back as the block fn).
        # Bump the ancestor's slot_count past every currently-open descendant scope.
        if (target < len(self.scope_stack) - 1) and (name not in sc.vars) {
            desc_i: int = target + 1;
            while desc_i < len(self.scope_stack) {
                if self.scope_stack[desc_i].slot_count > sc.slot_count {
                    sc.slot_count = self.scope_stack[desc_i].slot_count;
                }
                desc_i = desc_i + 1;
            }
        }
        if name in sc.vars {
            old_k: str = "var";
            if name in sc.var_kinds {
                old_k = sc.var_kinds[name];
            }
            # Function declarations and `var` of the same name freely redeclare
            # one another in scripts (function-scoped, last-wins).  Module goal:
            # top-level FunctionDeclarations are lexical, so `var x; function x`
            # is an early SyntaxError (LexicallyDeclaredNames ∩ VarDeclaredNames).
            new_var_like: bool = kind == "var" or kind == "fnhoist";
            old_var_like: bool = old_k == "var" or old_k == "fnhoist";
            if new_var_like and old_var_like {
                if self.compiling_module
                    and (
                        (kind == "var" and old_k == "fnhoist")
                        or (kind == "fnhoist" and old_k == "var")
                    ) {
                    self._syntax_error(
                        "SyntaxError: Identifier '"
                            + name
                            + "' has already been declared"
                    );
                    return sc.vars[name];
                }
                return sc.vars[name];
            }
            # A named-function-expression self-name (`fnself`) lives in a separate outer
            # environment and is legally shadowed by ANY body declaration of the same
            # name (ES §15.2.5 / §10.2.11): `var func = function n(){ var n; }`. Rebind
            # the slot to the body declaration (it wins) instead of erroring. The shadowing
            # binding must NOT observe the function value — the prologue self-name init is
            # suppressed for a shadowed name (see _compile_function), so the reused slot
            # starts undefined for a bare `var n;` (scope-var-open).
            if old_k == "fnself" {
                sc.var_kinds[name] = kind;
                if name == self.fn_self_name {
                    self.fn_self_name = "";
                    # A body declaration shadows the self-name → it is now mutable, so
                    # the runtime eval-store guard must not treat it as immutable.
                    if self._fn().self_name == name {
                        self._fn().self_name = "";
                    }
                }
                return sc.vars[name];
            }
            # for-in/of ForDeclaration pattern: the head lexicals were TDZ-predeclared
            # before the iterable; the per-iteration destructure re-visits them and must
            # bind (not redeclare) the SAME slot (ES §14.7.5.6). See compile_for_in/of.
            if self.reuse_predeclared_lexical
                and (kind == "let" or kind == "const")
                and (old_k == "let" or old_k == "const") {
                return sc.vars[name];
            }
            self._syntax_error(
                "SyntaxError: Identifier '" + name + "' has already been declared"
            );
            return sc.vars[name];
        }
        slot: int = sc.slot_count;
        sc.vars[name] = slot;
        sc.var_kinds[name] = kind;
        sc.slot_count = sc.slot_count + 1;
        # A `var`/`fnhoist` hoisted to an ANCESTOR (fn_base) just consumed `slot` at
        # that ancestor while descendant block scopes are open. Those descendants
        # inherited the ancestor's OLD slot_count at push time, so a child block
        # opened *later* under them would inherit that stale count and hand out
        # `slot` again — aliasing the hoisted var (symptom: `for (var i…) { let x }`
        # where a reference to `i` reads `x`'s TDZ slot). Propagate the new
        # slot_count DOWN to every currently-open descendant so their future child
        # blocks start past the hoisted var. (The upward guard above only covers the
        # opposite order — block opened before the var was hoisted.)
        if target < len(self.scope_stack) - 1 {
            prop_i: int = target + 1;
            while prop_i < len(self.scope_stack) {
                if self.scope_stack[prop_i].slot_count < sc.slot_count {
                    self.scope_stack[prop_i].slot_count = sc.slot_count;
                }
                prop_i = prop_i + 1;
            }
        }
        # Keep num_locals in sync
        fn: CompiledFunction = self._fn();
        if fn.num_locals < sc.slot_count {
            fn.num_locals = sc.slot_count;
        }
        # Populate debug name table so the VM can resolve free-var names
        while len(fn.locals) <= slot {
            fn.locals.append("");
        }
        fn.locals[slot] = name;
        # ES §19.2.1.3: record lexically-scoped names (let/const/class) so a
        # nested direct `eval` introducing a `var` of the same name is a
        # SyntaxError. `param` names are recorded separately at binding time.
        if kind == "let" or kind == "const" or kind == "class" {
            # O(1) dedup via lexical_names_seen — a linear `not in fn.lexical_names`
            # scan here was O(n²) across a function's n lexical bindings.
            if name not in self.lexical_names_seen {
                self.lexical_names_seen[name] = True;
                fn.lexical_names.append(name);
            }
        }
        return slot;
    }

    """Allocate a fresh slot in the current block scope and rebind `name` to it,
    overriding any existing binding of the same name in that scope.  Used when a
    body let/const legitimately shadows a function-expression self-name that was
    pre-declared into the same scope for recursion."""
    def _declare_shadow(name: str, kind: str) -> int {
        sc: Scope = self.scope_stack[len(self.scope_stack) - 1];
        slot: int = sc.slot_count;
        sc.vars[name] = slot;
        sc.var_kinds[name] = kind;
        sc.slot_count = sc.slot_count + 1;
        fn: CompiledFunction = self._fn();
        if fn.num_locals < sc.slot_count {
            fn.num_locals = sc.slot_count;
        }
        while len(fn.locals) <= slot {
            fn.locals.append("");
        }
        fn.locals[slot] = name;
        return slot;
    }

    """Slot of a body `var` whose name is a formal parameter (ES §10.2.11).

    Simple parameter list: the var IS the parameter binding — reuse its slot
    (a sloppy `arguments` object stays aliased to it). Otherwise the body gets
    its own variable environment (parameter expressions must not see body
    vars — SCP-P-003), and that binding STARTS WITH the parameter's value:
    `function f(a = 1) { var a; return a; }` returns the argument. The copy is
    emitted here, so this must first run at hoist time, after the parameters
    (defaults, destructuring) are bound. It used to always allocate a fresh,
    never-initialized slot, so `function f(a) { var r = a; …; var a = x; }`
    read undefined — convert-source-map's readFromFileMap(sm, read) does
    exactly that (`var sm = read(filename)`), breaking Vite's source maps."""
    def _param_body_var_slot(name: str) -> int {
        if not self.param_body_split {
            return self._resolve(name);
        }
        if name in self.param_body_var_slots {
            return self.param_body_var_slots[name];
        }
        pb_src: int = self._resolve(name);
        pb_slot: int = self._declare_param_body_var(name);
        if pb_src >= 0 and pb_slot >= 0 and pb_src != pb_slot {
            self._emit(make_instruction(Opcode.LOAD_LOCAL, pb_src, 0, 0));
            self._emit(make_instruction(Opcode.STORE_LOCAL, pb_slot, 0, 0));
        }
        return pb_slot;
    }

    def _declare_param_body_var(name: str) -> int {
        if name in self.param_body_var_slots {
            return self.param_body_var_slots[name];
        }
        fn: CompiledFunction = self._fn();
        fn_base: int = self.fn_scope_base[len(self.fn_scope_base) - 1];
        sc: Scope = self.scope_stack[fn_base];
        slot: int = sc.slot_count;
        sc.slot_count = sc.slot_count + 1;
        if fn.num_locals < sc.slot_count {
            fn.num_locals = sc.slot_count;
        }
        while len(fn.locals) <= slot {
            fn.locals.append("");
        }
        fn.locals[slot] = name;
        self.param_body_var_slots[name] = slot;
        return slot;
    }

    """
    Walk scope chain from innermost outward within the current function
    boundary looking for name.  Returns the slot index or -1 (global).
    """
    def _resolve(name: str) -> int {
        if not self.in_default_params and name in self.param_body_var_slots {
            return self.param_body_var_slots[name];
        }
        fn_base: int = self.fn_scope_base[len(self.fn_scope_base) - 1];
        i: int = len(self.scope_stack) - 1;
        while i >= fn_base {
            sc: Scope = self.scope_stack[i];
            if name in sc.vars {
                return sc.vars[name];
            }
            i = i - 1;
        }
        return -1;
    }

    """Resolve `name` in the CURRENT FUNCTION's base scope only (fn_scope_base),
    skipping inner block scopes — used for the Annex B.3.3 function-scoped `var`
    that a block-level function declaration must also write to.  Returns the slot
    or -1."""
    def _resolve_at_fn_base(name: str) -> int {
        fn_base: int = self.fn_scope_base[len(self.fn_scope_base) - 1];
        if fn_base < 0 or fn_base >= len(self.scope_stack) {
            return -1;
        }
        base_sc: Scope = self.scope_stack[fn_base];
        if name in base_sc.vars {
            return base_sc.vars[name];
        }
        return -1;
    }

    """True iff an ESM import / live-export reference to `name` is shadowed by a
    real user binding and must resolve through the scope chain instead of the
    module namespace (ES §8.2.1: the module environment is the OUTERMOST scope,
    so any function param/local/block binding of the same name shadows it —
    `new Promise((resolve, reject) => …)` under `import { resolve } from 'path'`
    binds the parameter, not path.resolve).

    Scans the enclosing-function scopes exactly like _capture but PURELY (no
    free-var registration). A binding owned by fn level >= 1 always shadows. A
    module-top-level (level 0) binding shadows a pure import (imports never
    scope-register, so any level-0 hit is a genuine top-level block shadow) but
    NOT a live export: `export let x` slots are dead — declaration stores go
    only to the namespace object — so namespace reads must keep winning there."""
    def _esm_shadowed_in_enclosing_fn(name: str) -> bool {
        n_bases: int = len(self.fn_scope_base);
        if n_bases < 2 {
            return False;
        }
        outer_top: int = self.fn_scope_base[n_bases - 1] - 1;
        found_at: int = -1;
        i: int = outer_top;
        while i >= 0 {
            sc: Scope = self.scope_stack[i];
            if name in sc.vars {
                found_at = i;
                i = -1;
            }
            i = i - 1;
        }
        if found_at < 0 {
            return False;
        }
        found_fn_level: int = 0;
        lv: int = 0;
        while lv < n_bases {
            if self.fn_scope_base[lv] <= found_at {
                found_fn_level = lv;
            }
            lv = lv + 1;
        }
        if found_fn_level >= 1 {
            return True;
        }
        if name in self.esm_import_bindings and not self._is_esm_live(name) {
            return True;
        }
        return False;
    }

    """Shared shadow test for identifier LOAD/STORE sites: True iff `name` —
    known to be in esm_import_bindings or esm_live_names — is shadowed by a
    binding in the CURRENT function (param/local) or an enclosing function.
    Module-top-level slots of live exports are dead (see
    _esm_shadowed_in_enclosing_fn) and do not shadow."""
    def _esm_name_is_shadowed(name: str) -> bool {
        slot: int = self._resolve(name);
        if slot >= 0 {
            # In a nested function any hit is a real param/local. At module top
            # level (fn level 0) only a pure import can be shadowed — a live
            # export's slot is the dead declaration binding.
            if len(self.fn_scope_base) > 1 {
                return True;
            }
            if name in self.esm_import_bindings and not self._is_esm_live(name) {
                return True;
            }
            return False;
        }
        return self._esm_shadowed_in_enclosing_fn(name);
    }

    """Annex B.3.3 step 1.b: True if creating a function-scoped `var` for `name`
    would collide with a lexical (`let`/`const`/`class`) binding between the
    current block and the function/var environment — in which case the Annex B
    extension must be suppressed entirely.

    Also suppress when `name` is a formal parameter (BoundNames of argumentsList),
    when a destructuring catch parameter would make `var name` an early error
    (B.3.5), and for classic-script / eval global code when `lexical_global_names`
    contains the name.  A *simple* `catch (name)` BindingIdentifier does NOT block
    (B.3.5 allows the corresponding VariableStatement)."""
    def _annexb_blocked_by_lexical(name: str) -> bool {
        # Formal parameters: Annex B must not observe the extension (skip-param).
        if name in self.param_names {
            return True;
        }
        # Spec: when argumentsObjectNeeded, "arguments" is appended to parameterNames
        # — so a block-level `function arguments(){}` must NOT clobber the arguments
        # object (skip-arguments).  We never annex-B-hoist "arguments" in that case,
        # so a pre-existing fn-base binding means the implicit arguments object.
        if name == "arguments" and name not in self.annexb_block_fn_names {
            if self._resolve_at_fn_base("arguments") >= 0 {
                return True;
            }
        }
        # Destructuring catch parameters block; simple BindingIdentifier does not.
        if name in self.catch_pattern_param_names {
            return True;
        }
        fn_base: int = self.fn_scope_base[len(self.fn_scope_base) - 1];
        # Scan from the current block down to (but not including) the function
        # base — a lexical there blocks the outer var hoist.
        i: int = len(self.scope_stack) - 1;
        while i > fn_base {
            sc: Scope = self.scope_stack[i];
            if name in sc.vars {
                k: str = "var";
                if name in sc.var_kinds {
                    k = sc.var_kinds[name];
                }
                if k == "let" or k == "const" or k == "class" {
                    # Simple catch BindingIdentifier is recorded as `let` but does
                    # not make a replacing `var` an early error (B.3.5).
                    if name in self.catch_param_names
                        and name not in self.catch_pattern_param_names {
                        i = i - 1;
                        continue;
                    }
                    return True;
                }
            }
            i = i - 1;
        }
        # Top-level script/eval: a lexical global of the same name would make a
        # hoisted `var` an early error (GlobalDeclarationInstantiation).
        if len(self.fn_scope_base) == 1 and name in self.lexical_global_names {
            return True;
        }
        return False;
    }

    """True when the current scope is an Annex-B-eligible nested block.

    - Inside a function: the body lives in a block scope at `fn_base+1`.
      Top-level `function f(){}` there must stay function-scoped `var`s.
      Annex B only applies deeper than that (Block / if / switch / try / …).
    - At script/eval top level (`fn_scope_base` length 1): any scope deeper
      than `fn_base` is a real nested block (no separate body scope)."""
    def _in_nested_block -> bool {
        fn_base: int = self.fn_scope_base[len(self.fn_scope_base) - 1];
        cur: int = len(self.scope_stack) - 1;
        if len(self.fn_scope_base) == 1 {
            return cur > fn_base;
        }
        return cur > fn_base + 1;
    }

    """True if `name` is already bound in the innermost (current) block scope.
    Lexical redeclaration (let/const) is only an early error within the same
    block — shadowing a binding from an enclosing block scope is allowed."""
    def _in_current_scope(name: str) -> bool {
        n: int = len(self.scope_stack);
        if n == 0 {
            return False;
        }
        return name in self.scope_stack[n - 1].vars;
    }

    """Return the declaration kind for name in the current function scope."""
    def _get_kind(name: str) -> str {
        fn_base: int = self.fn_scope_base[len(self.fn_scope_base) - 1];
        i: int = len(self.scope_stack) - 1;
        while i >= fn_base {
            sc: Scope = self.scope_stack[i];
            if name in sc.vars {
                if name in sc.var_kinds {
                    return sc.var_kinds[name];
                }
                return "var";
            }
            i = i - 1;
        }
        return "var";
    }

    """Return the kind of an outer-scope binding captured by name (for const checks)."""
    def _get_outer_binding_kind(name: str) -> str {
        n_bases: int = len(self.fn_scope_base);
        if n_bases < 2 {
            return "var";
        }
        outer_top: int = self.fn_scope_base[n_bases - 1] - 1;
        i: int = outer_top;
        while i >= 0 {
            sc: Scope = self.scope_stack[i];
            if name in sc.vars {
                if name in sc.var_kinds {
                    return sc.var_kinds[name];
                }
                return "var";
            }
            i = i - 1;
        }
        return "var";
    }

    """Emit TDZ_CLASS + STORE_LOCAL for a let/const slot."""
    def _emit_tdz_store(slot: int) {
        self._op(Opcode.TDZ_CLASS);
        if self.loop_body_depth > 0 {
            self._emit(make_instruction(Opcode.STORE_NEW_CELL, slot, 0, 0));
        } else {
            self._emit(make_instruction(Opcode.STORE_LOCAL, slot, 0, 0));
        }
    }

    # ── function stack ─────────────────────────────────────────────────────

    def _push_fn(name: str) {
        self.param_names_stack.append(self.param_names);
        self.param_names = {};
        self.param_body_var_slots_stack.append(self.param_body_var_slots);
        self.param_body_var_slots = {};
        self.param_body_split_stack.append(self.param_body_split);
        self.param_body_split = False;
        self.default_param_body_vars_stack.append(self.default_param_body_vars);
        self.default_param_body_vars = {};
        self.dead_lexical_names_stack.append(self.dead_lexical_names);
        self.dead_lexical_names = {};
        self.lexical_names_seen_stack.append(self.lexical_names_seen);
        self.lexical_names_seen = {};
        self.fn_self_name_stack.append(self.fn_self_name);
        self.fn_self_name = "";
        # Completion-value tracking is a property of the <main> script/eval body
        # only.  Nested function bodies must not write the <main> accumulator, so
        # stash and disable it for the duration of the inner function.
        self.cv_slot_stack.append(self.cv_slot);
        self.cv_slot = -1;
        self.annexb_block_fn_names_stack.append(self.annexb_block_fn_names);
        self.annexb_block_fn_names = {};
        # A nested function starts a fresh tail-position context: its own `return f()`
        # is tail-eligible even if the function literal appears inside an enclosing
        # try body. Save + reset the try-body depth across the nested function.
        self._in_try_body_stack.append(self._in_try_body);
        self._in_try_body = 0;
        # A body-declared lexical's per-iteration fresh-cell rule is scoped to the
        # loop's own function; a nested function body starts fresh (its loops manage
        # their own bodies). Save + reset so an outer loop doesn't mark inner lexicals.
        self.loop_body_depth_stack.append(self.loop_body_depth);
        self.loop_body_depth = 0;
        fn: CompiledFunction = make_compiled_fn(name, self.source_file);
        self.fn_stack.append(fn);
        self.fn_scope_base.append(len(self.scope_stack));
        self.cell_slots.append([]);
        self._push_scope(True);
    }

    def _pop_fn -> CompiledFunction {
        n_pns: int = len(self.param_names_stack);
        if n_pns > 0 {
            self.param_names = self.param_names_stack[n_pns - 1];
            del self.param_names_stack[n_pns - 1];
        }
        n_pbvs: int = len(self.param_body_var_slots_stack);
        if n_pbvs > 0 {
            self.param_body_var_slots = self.param_body_var_slots_stack[n_pbvs - 1];
            del self.param_body_var_slots_stack[n_pbvs - 1];
        }
        n_pbs: int = len(self.param_body_split_stack);
        if n_pbs > 0 {
            self.param_body_split = self.param_body_split_stack[n_pbs - 1];
            del self.param_body_split_stack[n_pbs - 1];
        }
        n_dpb: int = len(self.default_param_body_vars_stack);
        if n_dpb > 0 {
            self.default_param_body_vars = self.default_param_body_vars_stack[
                n_dpb - 1
            ];
            del self.default_param_body_vars_stack[n_dpb - 1];
        }
        n_dln: int = len(self.dead_lexical_names_stack);
        if n_dln > 0 {
            self.dead_lexical_names = self.dead_lexical_names_stack[n_dln - 1];
            del self.dead_lexical_names_stack[n_dln - 1];
        }
        n_lns: int = len(self.lexical_names_seen_stack);
        if n_lns > 0 {
            self.lexical_names_seen = self.lexical_names_seen_stack[n_lns - 1];
            del self.lexical_names_seen_stack[n_lns - 1];
        }
        n_fsn: int = len(self.fn_self_name_stack);
        if n_fsn > 0 {
            self.fn_self_name = self.fn_self_name_stack[n_fsn - 1];
            del self.fn_self_name_stack[n_fsn - 1];
        }
        n_cv: int = len(self.cv_slot_stack);
        if n_cv > 0 {
            self.cv_slot = self.cv_slot_stack[n_cv - 1];
            del self.cv_slot_stack[n_cv - 1];
        }
        n_abf: int = len(self.annexb_block_fn_names_stack);
        if n_abf > 0 {
            self.annexb_block_fn_names = self.annexb_block_fn_names_stack[n_abf - 1];
            del self.annexb_block_fn_names_stack[n_abf - 1];
        }
        n_itb: int = len(self._in_try_body_stack);
        if n_itb > 0 {
            self._in_try_body = self._in_try_body_stack[n_itb - 1];
            del self._in_try_body_stack[n_itb - 1];
        }
        n_lbd: int = len(self.loop_body_depth_stack);
        if n_lbd > 0 {
            self.loop_body_depth = self.loop_body_depth_stack[n_lbd - 1];
            del self.loop_body_depth_stack[n_lbd - 1];
        }
        self._pop_scope();
        n_base: int = len(self.fn_scope_base);
        del self.fn_scope_base[n_base - 1];
        n_fn: int = len(self.fn_stack);
        fn: CompiledFunction = self.fn_stack[n_fn - 1];
        del self.fn_stack[n_fn - 1];
        # ── cell post-processing ──────────────────────────────────────────
        # Replace LOAD_LOCAL/STORE_LOCAL for cellified slots with
        # LOAD_DEREF/STORE_DEREF and prepend MAKE_CELL instructions.
        n_cell: int = len(self.cell_slots);
        cells: list[int] = self.cell_slots[n_cell - 1];
        del self.cell_slots[n_cell - 1];
        if len(cells) > 0 {
            # : rewrite opcodes in-place
            ci: int = 0;
            while ci < len(fn.code) {
                ins: Instruction = fn.code[ci];
                if ins.opcode == Opcode.LOAD_LOCAL and ins.arg in cells {
                    fn.code[ci] = make_instruction(
                        Opcode.LOAD_DEREF, ins.arg, ins.arg2, ins.line
                    );
                } elif ins.opcode == Opcode.LOAD_LOCAL_CHECKED and ins.arg in cells {
                    fn.code[ci] = make_instruction(
                        Opcode.LOAD_DEREF, ins.arg, ins.arg2, ins.line
                    );
                } elif ins.opcode == Opcode.STORE_LOCAL and ins.arg in cells {
                    fn.code[ci] = make_instruction(
                        Opcode.STORE_DEREF, ins.arg, ins.arg2, ins.line
                    );
                } elif ins.opcode == Opcode.STORE_NEW_CELL and ins.arg not in cells {
                    # Loop iter slot not captured by any closure — no cell needed.
                    fn.code[ci] = make_instruction(
                        Opcode.STORE_LOCAL, ins.arg, ins.arg2, ins.line
                    );
                }
                ci = ci + 1;
            }
            # : dedup + sort cell slot indices
            cell_list: list[int] = [];
            for k in cells {
                if k not in cell_list {
                    cell_list.append(k);
                }
            }
            si: int = 0;
            while si < len(cell_list) - 1 {
                sj: int = si + 1;
                while sj < len(cell_list) {
                    if cell_list[sj] < cell_list[si] {
                        tmp: int = cell_list[si];
                        cell_list[si] = cell_list[sj];
                        cell_list[sj] = tmp;
                    }
                    sj = sj + 1;
                }
                si = si + 1;
            }
            # : prepend MAKE_CELL instructions and fix jump targets
            prefix: list[Instruction] = [];
            for cs in cell_list {
                prefix.append(make_instruction(Opcode.MAKE_CELL, cs, 0, 0));
            }
            n_prefix: int = len(prefix);
            fi: int = 0;
            while fi < len(fn.code) {
                old_fi: Instruction = fn.code[fi];
                fop: Opcode = old_fi.opcode;
                if fop == Opcode.JUMP
                    or fop == Opcode.JUMP_IF_TRUE
                    or fop == Opcode.JUMP_IF_FALSE
                    or fop == Opcode.JUMP_IF_NULL
                    or fop == Opcode.JUMP_IF_UNDEFINED
                    or fop == Opcode.PUSH_CATCH
                    or fop == Opcode.PUSH_FINALLY {
                    # Replace entire instruction to avoid list-subscript field-mutation bugs.
                    fn.code[fi] = make_instruction(
                        old_fi.opcode, old_fi.arg + n_prefix, old_fi.arg2, old_fi.line
                    );
                }
                fi = fi + 1;
            }
            new_code: list[Instruction] = [];
            for p in prefix {
                new_code.append(p);
            }
            for c in fn.code {
                new_code.append(c);
            }
            fn.code = new_code;
            # The generator parameter-prologue boundary was recorded as a code offset
            # BEFORE this MAKE_CELL prefix was prepended, so shift it by n_prefix too.
            # Otherwise the VM runs the eager prologue [0, end_ip) too short — cutting
            # off the tail of the param prologue (e.g. the LOAD_SELF+STORE_LOCAL that
            # initialises a named-generator self-ref slot) and resuming the body at the
            # wrong IP, so a closure capturing the self-name sees `undefined`.
            if fn.gen_prologue_end_ip >= 0 {
                fn.gen_prologue_end_ip = fn.gen_prologue_end_ip + n_prefix;
            }
        }
        # Any STORE_NEW_CELL whose slot is not in cells means no closure captured
        # the loop variable — downgrade to STORE_LOCAL so the VM never allocates
        # a cell object for non-escaping loop counters.
        # When arg2 != 0 (set by compile_for as outer_slot+1), this is a per-iteration
        # copy that can be fully eliminated: NOP the preceding LOAD_LOCAL and this
        # STORE_NEW_CELL, then redirect all reads/writes of iter_slot → outer_slot.
        snc_i: int = 0;
        while snc_i < len(fn.code) {
            snc_ins: Instruction = fn.code[snc_i];
            if snc_ins.opcode == Opcode.TAIL_CALL {
                fn.has_tail_call = True;
            }
            if snc_ins.opcode == Opcode.STORE_NEW_CELL and snc_ins.arg not in cells {
                iter_slot: int = snc_ins.arg;
                if snc_ins.arg2 != 0 {
                    # for-loop iter copy: arg2 encodes (outer_slot + 1)
                    outer_slot: int = snc_ins.arg2 - 1;
                    # FILLER the preceding LOAD_LOCAL outer_slot. NOT NOP: NOP
                    # pushes the class-TDZ sentinel, so the old NOP;NOP pad here
                    # dispatched 2 ops AND leaked 2 stack slots per loop
                    # iteration (bytecode_optimizer_impl_plan §0.2). FILLER is a
                    # true no-op and the optimizer retargets jumps past it.
                    if snc_i > 0 {
                        prev: Instruction = fn.code[snc_i - 1];
                        if prev.opcode == Opcode.LOAD_LOCAL
                            and prev.arg == outer_slot {
                            fn.code[snc_i - 1] = make_instruction(
                                Opcode.FILLER, 0, 0, prev.line
                            );
                        }
                    }
                    # FILLER this STORE_NEW_CELL (same reasoning as above)
                    fn.code[snc_i] = make_instruction(
                        Opcode.FILLER, 0, 0, snc_ins.line
                    );
                    # Redirect reads of iter_slot → outer_slot throughout the function
                    rd_i: int = 0;
                    while rd_i < len(fn.code) {
                        rd_ins: Instruction = fn.code[rd_i];
                        if rd_ins.opcode == Opcode.LOAD_LOCAL
                            and rd_ins.arg == iter_slot {
                            fn.code[rd_i] = make_instruction(
                                Opcode.LOAD_LOCAL, outer_slot, rd_ins.arg2, rd_ins.line
                            );
                        } elif rd_ins.opcode == Opcode.LOAD_LOCAL_CHECKED
                            and rd_ins.arg == iter_slot {
                            fn.code[rd_i] = make_instruction(
                                Opcode.LOAD_LOCAL, outer_slot, rd_ins.arg2, rd_ins.line
                            );
                        } elif rd_ins.opcode == Opcode.STORE_LOCAL
                            and rd_ins.arg == iter_slot {
                            fn.code[rd_i] = make_instruction(
                                Opcode.STORE_LOCAL, outer_slot, rd_ins.arg2, rd_ins.line
                            );
                        }
                        rd_i = rd_i + 1;
                    }
                } else {
                    # for-of/for-in iter store or pattern store: plain downgrade
                    fn.code[snc_i] = make_instruction(
                        Opcode.STORE_LOCAL, iter_slot, 0, snc_ins.line
                    );
                }
            }
            snc_i = snc_i + 1;
        }
        # Snapshot the active PrivateEnvironment so direct eval in this function
        # (methods, field inits, nested arrows) mangles `#name` to the same keys.
        if len(self.priv_scope_ids) > 0 {
            pe_map: dict[str, str] = {};
            pe_si: int = 0;
            while pe_si < len(self.priv_scope_ids) {
                for pe_nm in self.priv_scope_names[pe_si] {
                    pe_map[pe_nm] = "__priv_"
                        + pe_nm
                        + "@"
                        + str(self.priv_scope_ids[pe_si]);
                }
                pe_si = pe_si + 1;
            }
            for pe_k in pe_map {
                fn.priv_env_keys.append(pe_k);
                fn.priv_env_mangles.append(pe_map[pe_k]);
            }
            fn.priv_env_next_sid = self.priv_scope_seq;
        }
        # Also inherit a caller-eval private map when this function is itself
        # compiled inside direct eval (nested functions/arrows in eval'd code).
        if len(fn.priv_env_keys) == 0 and len(self.eval_priv_keys) > 0 {
            pe_ei: int = 0;
            while pe_ei < len(self.eval_priv_keys) {
                fn.priv_env_keys.append(self.eval_priv_keys[pe_ei]);
                fn.priv_env_mangles.append(self.eval_priv_mangles[pe_ei]);
                pe_ei = pe_ei + 1;
            }
            fn.priv_env_next_sid = self.priv_scope_seq;
        }
        # Bytecode optimizer (bytecode_optimizer_impl_plan): every function —
        # top-level, inner, eval, Function, jsbc precompile — is popped here
        # exactly once, with its code final (cell prefixes prepended, snc
        # elision done above), so this is the single chokepoint.
        optimize_fn(fn);
        # Register ISA (docs/VM_REARCH_PLAN.md V2): derived from this final
        # code lazily, the first time the function runs (VM._reg_ready).
        return fn;
    }

    # ── closure capture ────────────────────────────────────────────────────

    """
    Walk scope chains of outer functions (above the current fn_scope_base)
    looking for `name`.  If found, register the name in the CURRENT
    function's `free_vars` list and return the free-var slot index.
    Returns -1 when not found in any outer scope, or when called at top
    level (no enclosing function to capture from).

    Call AFTER _resolve() returns -1 (not a local).  The same name is
    de-duplicated: calling _capture() twice for the same name returns the
    same slot.
    """
    def _capture(name: str) -> int {
        # Only meaningful when there is at least one enclosing function.
        n_bases: int = len(self.fn_scope_base);
        if n_bases < 2 {
            return -1;
        }

        fn: CompiledFunction = self._fn();

        # Fast path: already captured?
        fv_idx: int = 0;
        while fv_idx < len(fn.free_vars) {
            if fn.free_vars[fv_idx] == name {
                return fv_idx;
            }
            fv_idx = fv_idx + 1;
        }

        # Slow path: scan outward through every outer-function scope layer,
        # find where `name` is declared, record which scope index.
        outer_top: int = self.fn_scope_base[n_bases - 1] - 1;
        found_at: int = -1;
        i: int = outer_top;
        while i >= 0 {
            sc: Scope = self.scope_stack[i];
            if name in sc.vars {
                found_at = i;
                i = -1;  # break
            }
            i = i - 1;
        }
        if found_at < 0 {
            return -1;
        }

        # Determine which function level owns the scope where `name` was found.
        # fn_scope_base[j] = scope_stack start of function j in fn_stack.
        found_fn_level: int = 0;
        lv: int = 0;
        while lv < n_bases {
            if self.fn_scope_base[lv] <= found_at {
                found_fn_level = lv;
            }
            lv = lv + 1;
        }

        # Mark the local slot as needing a cell in the defining function.
        found_sc: Scope = self.scope_stack[found_at];
        direct_slot: int = -1;
        if name in found_sc.vars {
            cell_slot: int = found_sc.vars[name];
            direct_slot = cell_slot;
            if cell_slot not in self.cell_slots[found_fn_level] {
                self.cell_slots[found_fn_level].append(cell_slot);
            }
        }

        # Propagate `name` upward through every intermediate function between
        # found_fn_level+1 and n_bases-2, so that each intermediate function
        # captures the variable from its own enclosing frame.
        # This is the "transitive free-variable" rule required for closures
        # nested more than one level deep (e.g. outer(a) → middle(b) → inner(c)
        # where inner uses `a`; middle must capture `a` so it can pass it on).
        mid: int = found_fn_level + 1;
        while mid < n_bases - 1 {
            mid_fn: CompiledFunction = self.fn_stack[mid];
            already: bool = False;
            mi: int = 0;
            while mi < len(mid_fn.free_vars) {
                if mid_fn.free_vars[mi] == name {
                    already = True;
                }
                mi = mi + 1;
            }
            if not already {
                mid_fn.free_vars.append(name);
                if mid == found_fn_level + 1 {
                    # The first intermediate function is created in the defining
                    # function's frame, so it captures from that frame directly:
                    # record the exact slot, as for a direct capture. The VM's name
                    # scan would otherwise take the first local of that name — a
                    # sibling block's let/const of the same name, not this one.
                    mid_fn.free_var_slots.append(direct_slot);
                } else {
                    mid_fn.free_var_slots.append(-1);  # transitive — VM uses free_vals path
                }
            }
            mid = mid + 1;
        }

        slot: int = len(fn.free_vars);
        fn.free_vars.append(name);
        # Record the exact parent-local slot for direct captures so the VM can
        # bypass the ambiguous name scan when two siblings both declare the same name.
        # Direct = defining function is the immediate parent (level n_bases-2).
        if found_fn_level == n_bases - 2 {
            fn.free_var_slots.append(direct_slot);
        } else {
            fn.free_var_slots.append(-1);  # transitive — VM falls back to free_vals
        }
        return slot;
    }

    # ── loop / switch context ──────────────────────────────────────────────

    def _push_loop(label: str) -> LoopContext {
        lc: LoopContext = make_loop_ctx(label);
        self.loop_stack.append(lc);
        return lc;
    }

    def _pop_loop -> LoopContext {
        n: int = len(self.loop_stack);
        lc: LoopContext = self.loop_stack[n - 1];
        del self.loop_stack[n - 1];
        return lc;
    }

    """Patch all accumulated break jumps of ctx to the current ip."""
    def _patch_breaks(ctx: LoopContext) {
        close_ip: int = ctx.for_of_close_ip;
        for addr in ctx.break_addrs {
            if close_ip >= 0 {
                self._patch_to(addr, close_ip);
            } else {
                self._patch(addr);
            }
        }
    }

    """
    Emit POP_CATCH + ITER_CLOSE for each for-of loop being exited when jumping
    to an outer label (break/continue).  Closes innermost for-of first.
    """
    def _emit_close_enclosing_for_of(until_idx: int) {
        j: int = len(self.loop_stack) - 1;
        while j > until_idx {
            lc: LoopContext = self.loop_stack[j];
            if lc.is_for_of {
                self._op(Opcode.POP_CATCH);
                self._op(Opcode.ITER_CLOSE);
            }
            j = j - 1;
        }
    }

    """Patch all accumulated continue jumps of ctx to an explicit target."""
    def _patch_conts(ctx: LoopContext, target: int) {
        for addr in ctx.cont_addrs {
            self._patch_to(addr, target);
        }
    }

    """
    Patch cont_addrs for labeled LoopContexts that directly wrap the
    current top-of-stack loop.  Called after _patch_conts so that
    `continue outerLabel` (whose addrs land in the labeled wrapper ctx,
    not the for/while ctx) are also resolved to the correct target.
    Stops at the first unlabeled context below the current loop.
    """
    def _patch_label_conts(target: int) {
        si: int = len(self.loop_stack) - 2;
        while si >= 0 {
            lc: LoopContext = self.loop_stack[si];
            if lc.label != "" {
                self._patch_conts(lc, target);
                si = si - 1;
            } else {
                si = -1;
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════
    # Statements
    # ══════════════════════════════════════════════════════════════════════

    """Seed the running completion value to `undefined` (ES §14 UpdateEmpty).
    `if`/`switch`/loops/`try` produce `undefined` when their body is skipped or
    yields no value, so we reset the accumulator before compiling them; inner
    expression statements then overwrite it.  No-op outside completion mode."""
    def _cv_reset {
        if self.cv_slot >= 0 {
            self._op(Opcode.LOAD_UNDEFINED);
            self._emit(make_instruction(Opcode.STORE_LOCAL, self.cv_slot, 0, 0));
        }
    }

    def compile_stmt(nd: ASTNode) {
        if nd.ntype == ASTNodeType.ExpressionStatement {
            if nd.expression is not None {
                expr_s: ASTNode = nd.expression;
                # ECMAScript completion value: an ExpressionStatement's value is the
                # statement-list's running value (ES §14.5.1).  In completion mode
                # (script/eval <main>) capture it into the accumulator instead of
                # discarding it.
                if self.cv_slot >= 0 {
                    self.compile_expr(expr_s);
                    self._emit(
                        make_instruction(Opcode.STORE_LOCAL, self.cv_slot, 0, 0)
                    );
                    # Optimization: assignment-as-statement with a simple Identifier LHS
                    # skips the DUP+POP pair.  compile_assign normally DUPs the result
                    # so callers can use the value; when the assignment is a statement
                    # the result is immediately discarded, making DUP+POP pure waste.
                } elif expr_s.ntype == ASTNodeType.AssignmentExpression
                    and expr_s.left is not None
                    and expr_s.left.ntype == ASTNodeType.Identifier {
                    self.compile_assign_stmt(expr_s);
                } else {
                    self.compile_expr(expr_s);
                    self._op(Opcode.POP);
                }
            }
        } elif nd.ntype == ASTNodeType.VariableDeclaration {
            self.compile_var_decl(nd);
        } elif nd.ntype == ASTNodeType.FunctionDeclaration {
            self.compile_function_decl(nd);
        } elif nd.ntype == ASTNodeType.ClassDeclaration {
            self.compile_class_decl(nd);
        } elif nd.ntype == ASTNodeType.ReturnStatement {
            # ES §14.15.3: a `return` inside try/finally runs every enclosing finalizer
            # in this function first. Finalizers are stack-neutral, so the evaluated
            # return value stays on TOS across them.
            ret_has_fin: bool = self._has_in_fn_finalizer();
            if nd.argument is not None {
                # ES §15.10.3: `return <expr>;` in a STRICT function puts <expr> in tail
                # position. A call there is a proper tail call; the tail position also
                # propagates THROUGH &&/||/??/?:/comma to their tail sub-expression(s), so a
                # call reached that way is a tail call too (coalesce/comma/conditional/logical
                # tco tests). Excluded when a finalizer must run after (not tail position) or
                # in a non-strict function. The operator compile_* fns route _emit_tail_call
                # to only their genuinely-tail sub-expressions; compile_call consumes it.
                if not ret_has_fin
                    and self._in_try_body == 0
                    and self._fn().is_strict
                    and self._is_tail_position_expr(nd.argument) {
                    self._emit_tail_call = True;
                }
                self.compile_expr(nd.argument);
                self._emit_tail_call = False;
                if ret_has_fin {
                    self._emit_finalizers_for_exit(0);
                }
                self._op(Opcode.RETURN);
            } else {
                if ret_has_fin {
                    self._emit_finalizers_for_exit(0);
                }
                self._op(Opcode.RETURN_UNDEFINED);
            }
        } elif nd.ntype == ASTNodeType.IfStatement {
            self._cv_reset();
            self.compile_if(nd);
        } elif nd.ntype == ASTNodeType.WhileStatement {
            self._cv_reset();
            self.compile_while(nd);
        } elif nd.ntype == ASTNodeType.WithStatement {
            self._cv_reset();
            self.compile_with(nd);
        } elif nd.ntype == ASTNodeType.DoWhileStatement {
            self._cv_reset();
            self.compile_do_while(nd);
        } elif nd.ntype == ASTNodeType.ForStatement {
            self._cv_reset();
            self.compile_for(nd);
        } elif nd.ntype == ASTNodeType.ForInStatement {
            self._cv_reset();
            self.compile_for_in(nd);
        } elif nd.ntype == ASTNodeType.ForOfStatement {
            self._cv_reset();
            self.compile_for_of(nd);
        } elif nd.ntype == ASTNodeType.BlockStatement {
            self._compile_block(nd);
        } elif nd.ntype == ASTNodeType.BreakStatement {
            self.compile_break(nd);
        } elif nd.ntype == ASTNodeType.ContinueStatement {
            self.compile_continue(nd);
        } elif nd.ntype == ASTNodeType.ThrowStatement {
            if nd.argument is not None {
                self.compile_expr(nd.argument);
            } else {
                self._op(Opcode.LOAD_UNDEFINED);
            }
            self._emit(make_instruction(Opcode.THROW, 0, 0, nd.loc.line));
        } elif nd.ntype == ASTNodeType.TryStatement {
            self._cv_reset();
            self.compile_try(nd);
        } elif nd.ntype == ASTNodeType.SwitchStatement {
            self._cv_reset();
            self.compile_switch(nd);
        } elif nd.ntype == ASTNodeType.LabeledStatement {
            self.compile_labeled(nd);
        } elif nd.ntype == ASTNodeType.DebuggerStatement {
            self._op(Opcode.DEBUGGER);
        } elif nd.ntype == ASTNodeType.ImportDeclaration {
            # Emit IMPORT opcode — VM resolves module and pushes namespace.
            src: str = "";
            if nd.source is not None {
                src = nd.source.value;
            }
            ns_gname: str = "";
            if src in self.esm_import_ns_globals {
                ns_gname = self.esm_import_ns_globals[src];
            } else {
                ns_gname = self.esm_exports_global
                    + "_imp_"
                    + str(len(self.esm_import_ns_globals));
                self.esm_import_ns_globals[src] = ns_gname;
            }
            # arg2=1 → source-phase import (returns WebAssembly.Module for .wasm)
            # arg2=2 → deferred evaluation (`import defer * as ns from`)
            imp_phase: int = 0;
            if nd.kind == "source" {
                imp_phase = 1;
            } elif nd.kind == "defer" {
                imp_phase = 2;
            }
            self._emit(
                make_instruction(
                    Opcode.IMPORT, self._intern(src), imp_phase, nd.loc.line
                )
            );
            self._emit(
                make_instruction(Opcode.STORE_GLOBAL, self._intern(ns_gname), 0, 0)
            );
            # Bind specifiers from the module namespace (now on top of stack).
            n_specs: int = len(nd.specifiers);
            if n_specs > 0 {
                spec_i: int = 0;
                while spec_i < n_specs {
                    sp: ASTNode = nd.specifiers[spec_i];
                    if sp.left is None or sp.right is None {
                        spec_i = spec_i + 1;
                        continue;
                    }
                    imported_name: str = sp.left.name;
                    local_name: str = sp.right.name;
                    if imp_phase == 1 {
                        # Source phase: the IMPORT result IS the module source object
                        # (bound as the local name — typically a default-style binding).
                        self._emit(
                            make_instruction(
                                Opcode.LOAD_GLOBAL, self._intern(ns_gname), 0, 0
                            )
                        );
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL, self._intern(local_name), 0, 0
                            )
                        );
                    } elif imported_name == "*" {
                        # Namespace import (including `import defer * as`): bind the
                        # namespace object eagerly. The IMPORT opcode already returns
                        # the Module Namespace Exotic Object marked in place (adel
                        # model), so `ns` is === the object dynamic `import()` of the
                        # same module resolves to (ES §10.4.6) — no wrapping opcode.
                        # Identity is stable once instantiated; deferred evaluation
                        # runs on first access.
                        self._emit(
                            make_instruction(
                                Opcode.LOAD_GLOBAL, self._intern(ns_gname), 0, 0
                            )
                        );
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL, self._intern(local_name), 0, 0
                            )
                        );
                    } else {
                        # Named and default imports are LIVE bindings (ES §16.2.1.5.2):
                        # each use re-reads the export from the module namespace so
                        # that circular imports (where the export is initialized
                        # *after* the importing statement is hoisted and run) observe
                        # the final value rather than an `undefined` snapshot.
                        self.esm_import_bindings[local_name] = ns_gname
                            + ":"
                            + imported_name;
                    }
                    spec_i = spec_i + 1;
                }
            }
        } elif nd.ntype == ASTNodeType.ExportDefaultDecl {
            if nd.expression is not None {
                edd: ASTNode = nd.expression;
                # ES §16.2.3.7: `export default function f(){}` / `class C{}` binds
                # `f`/`C` in the module scope and exports it under `default` as a LIVE
                # binding — reassigning `f` inside the module updates `imported.default`.
                # The compile pre-pass already registered `_esm_alias_add(name,
                # "default")` for a named default decl, so subsequent stores to the
                # binding update the `default` export via the alias-store hooks
                # (adel model). Here we just bind the name + EXPORT the initial value.
                # `export default function/class …` parses the declaration as a
                # *statement* node (Function/ClassDeclaration), but its value must
                # be produced on the stack for the default export.  compile_expr
                # does not handle declaration node types, so route them through the
                # matching expression compiler (the node shape is identical).  A
                # named `export default function f(){}` / `class C{}` also binds
                # the name `f`/`C` in the module scope per ES §16.2.3.7.
                if edd.ntype == ASTNodeType.ClassDeclaration {
                    # Anonymous default class: name is "default" (ES §16.2.3.7), applied
                    # INSIDE class evaluation (before static elements) via the pre-hook —
                    # so a static field initializer observes `this.name === "default"`.
                    if edd.id is None {
                        self._pending_infer_class_name = "default";
                    }
                    self.compile_class_expr(edd);
                    if edd.id is not None {
                        self._op(Opcode.DUP);
                        edd_cslot: int = self._declare(edd.id.name, "let");
                        if edd_cslot >= 0 {
                            self._emit(
                                make_instruction(Opcode.STORE_LOCAL, edd_cslot, 0, 0)
                            );
                        } else {
                            self._emit(
                                make_instruction(
                                    Opcode.STORE_GLOBAL, self._intern(edd.id.name), 0, 0
                                )
                            );
                        }
                    }
                } elif edd.ntype == ASTNodeType.FunctionDeclaration {
                    # `export default function f(){}` is a HoistableDeclaration:
                    # compile without the immutable fnself self-name so a `f = …` in
                    # the body reassigns the module binding (live default export).
                    self.compile_fn_expr(edd, True);
                    if edd.id is not None {
                        self._op(Opcode.DUP);
                        edd_fslot: int = self._declare(edd.id.name, "var");
                        if edd_fslot >= 0 {
                            self._emit(
                                make_instruction(Opcode.STORE_LOCAL, edd_fslot, 0, 0)
                            );
                        } else {
                            self._emit(
                                make_instruction(
                                    Opcode.STORE_GLOBAL, self._intern(edd.id.name), 0, 0
                                )
                            );
                        }
                        # Seed live export + `default` alias (pre-scan registered both).
                        if self._is_esm_live(edd.id.name) {
                            self._op(Opcode.DUP);
                            self._emit_esm_live_store(edd.id.name);
                        }
                    } else {
                        # Anonymous default function: name is "default" (ES §16.2.3.7).
                        # Set the compiled function's name directly (name is a
                        # non-writable own property, so a runtime SET_PROP no-ops).
                        if len(self.all_fns) > 0 {
                            self.all_fns[len(self.all_fns) - 1].name = "default";
                        }
                    }
                } else {
                    # `export default <AssignmentExpression>` — SetFunctionName
                    # when IsAnonymousFunctionDefinition (ES §16.2.3.7 step 3).
                    # Parentheses unwrap in the parser, so `(function(){})` /
                    # `(class{})` / `(function*(){})` arrive as the inner expr.
                    self.compile_expr(edd);
                    self._maybe_infer_fn_name(edd, "default");
                }
                # EXPORT the initial `default` value. If the default decl is a named
                # module-global binding, the pre-pass's `_esm_alias_add(name,
                # "default")` keeps `default` live on subsequent stores (adel model).
                self._op(Opcode.EXPORT);
            }
        } elif nd.ntype == ASTNodeType.ExportAllDecl {
            ex_src: str = "";
            if nd.source is not None {
                ex_src = nd.source.value;
            }
            self._emit(
                make_instruction(Opcode.IMPORT, self._intern(ex_src), 0, nd.loc.line)
            );
            # `export * as ns from "mod"` → install the module namespace as export `ns`.
            # Plain `export * from "mod"` → REEXPORT_STAR (skip default).
            # The IMPORT result already IS the Module Namespace Exotic Object marked
            # in place (adel model), so it is stored directly as the named export —
            # no MODULE_NS wrapping opcode (ES §16.2.3.7 / §10.4.6).
            if nd.expression is not None and nd.expression.name != "" {
                ex_as_name: str = nd.expression.name;
                self._emit(
                    make_instruction(
                        Opcode.LOAD_GLOBAL, self._intern(self.esm_exports_global), 0, 0
                    )
                );
                self._op(Opcode.SWAP);
                self._emit_set_prop(ex_as_name, 0, 0, 1);
                self._op(Opcode.POP);
            } else {
                self._op(Opcode.REEXPORT_STAR);
            }
        } elif nd.ntype == ASTNodeType.ExportNamedDecl {
            if nd.source is not None and len(nd.specifiers) > 0 {
                ex_from_src: str = nd.source.value;
                self._emit(
                    make_instruction(
                        Opcode.IMPORT, self._intern(ex_from_src), 0, nd.loc.line
                    )
                );
                exf_n: int = len(nd.specifiers);
                exf_i: int = 0;
                while exf_i < exf_n {
                    if exf_i < exf_n - 1 {
                        self._op(Opcode.DUP);
                    }
                    exf_spec: ASTNode = nd.specifiers[exf_i];
                    exf_left: ASTNode | None = exf_spec.left;
                    exf_right: ASTNode | None = exf_spec.right;
                    if exf_left is not None and exf_right is not None {
                        exf_pair: str = exf_left.name + ":" + exf_right.name;
                        self._emit(
                            make_instruction(
                                Opcode.REEXPORT_LIVE, self._intern(exf_pair), 0, 0
                            )
                        );
                    }
                    exf_i = exf_i + 1;
                }
            } elif nd.expression is not None {
                exp_decl0: ASTNode = nd.expression;
                if exp_decl0.ntype == ASTNodeType.VariableDeclaration {
                    for exp_d0 in exp_decl0.declarations {
                        if exp_d0.id is not None
                            and exp_d0.id.ntype == ASTNodeType.Identifier {
                            self.esm_live_names[exp_d0.id.name] = True;
                        }
                    }
                } elif (
                    exp_decl0.ntype == ASTNodeType.FunctionDeclaration
                    or exp_decl0.ntype == ASTNodeType.ClassDeclaration
                ) {
                    if exp_decl0.id is not None {
                        self.esm_live_names[exp_decl0.id.name] = True;
                    }
                }
                self.compile_stmt(nd.expression);
                # Live export names are written during the declaration's store path
                # (`_emit_esm_live_store`). Function/class still need an explicit
                # install when the declaration itself did not go through that path.
                exp_decl: ASTNode = nd.expression;
                if exp_decl.ntype == ASTNodeType.FunctionDeclaration
                    or exp_decl.ntype == ASTNodeType.ClassDeclaration {
                    if exp_decl.id is not None {
                        exp_fn_name: str = exp_decl.id.name;
                        # Ensure the namespace sees the binding (fn/class stored in local/global).
                        self._emit(
                            make_instruction(
                                Opcode.LOAD_GLOBAL,
                                self._intern(self.esm_exports_global),
                                0,
                                0
                            )
                        );
                        exp_fn_slot: int = self._resolve(exp_fn_name);
                        if exp_fn_slot >= 0 {
                            self._emit(
                                make_instruction(Opcode.LOAD_LOCAL, exp_fn_slot, 0, 0)
                            );
                        } else {
                            self._emit(
                                make_instruction(
                                    Opcode.LOAD_GLOBAL, self._intern(exp_fn_name), 0, 0
                                )
                            );
                        }
                        self._emit_set_prop(exp_fn_name, 0, 0, 1);
                        self._op(Opcode.POP);
                    }
                }
            }
            # export { a, b } — specifiers without declaration (no "from" source).
            # Guard: nd.source is not None means re-export; already handled above
            # via REEXPORT_LIVE. Running this block again would overwrite the live
            # getter with a stale LOAD_GLOBAL of a non-existent local name.
            if len(nd.specifiers) > 0 and nd.source is None {
                for exp_sp in nd.specifiers {
                    if exp_sp.left is None or exp_sp.right is None {
                        continue;
                    }
                    exp_local: str = exp_sp.left.name;
                    exp_exported: str = exp_sp.right.name;
                    # Register live alias so subsequent stores to `exp_local` update
                    # the namespace export (and seed the current value now). Replaces
                    # HEAD's EXPORT_VAR_LIVE getter with adel's store-hook model.
                    self._esm_alias_add(exp_local, exp_exported);
                    self._emit(
                        make_instruction(
                            Opcode.LOAD_GLOBAL,
                            self._intern(self.esm_exports_global),
                            0,
                            0
                        )
                    );
                    if exp_local in self.esm_import_bindings {
                        # `export { importAlias as name }` — local came from an import alias.
                        # esm_import_bindings stores "ns_global:imported_name"; emit a live read.
                        self._emit_esm_import_load(exp_local);
                    } elif self._is_esm_live(exp_local) {
                        self._emit_esm_live_load(exp_local);
                    } else {
                        exp_sp_slot: int = self._resolve(exp_local);
                        if exp_sp_slot >= 0 {
                            self._emit(
                                make_instruction(Opcode.LOAD_LOCAL, exp_sp_slot, 0, 0)
                            );
                        } else {
                            self._emit(
                                make_instruction(
                                    Opcode.LOAD_GLOBAL, self._intern(exp_local), 0, 0
                                )
                            );
                        }
                    }
                    self._emit_set_prop(exp_exported, 0, 0, 1);
                    self._op(Opcode.POP);
                }
            }
        }
        # EmptyStatement / unknown: no-op
    }

    # ── block statement ───────────────────────────────────────────────────

    """
    Recursively pre-declare every Identifier bound by a destructuring pattern
    (ArrayPattern or ObjectPattern) with the TDZ sentinel.  Handles nesting,
    rest elements, and default-value (AssignmentPattern) sub-patterns.
    """
    def _predeclare_pattern_tdz(pat: ASTNode, kind: str) {
        if pat.ntype == ASTNodeType.Identifier {
            if pat.name != "undefined" {
                s: int = self._declare(pat.name, kind);
                if s >= 0 {
                    self._emit_tdz_store(s);
                }
                # Record a predeclare flag so the later per-property _declare in
                # compile_obj_pattern/compile_arr_pattern (via _declare_lex_binding)
                # reuses this slot instead of raising a false redeclaration error.
                if (kind == "let" or kind == "const") {
                    self.hoist_predeclared[self._hoist_predecl_key(pat.name)] = True;
                }
            }
        } elif pat.ntype == ASTNodeType.ArrayPattern {
            for elem in pat.elements {
                if elem is not None {
                    if elem.ntype == ASTNodeType.RestElement {
                        if elem.argument is not None {
                            self._predeclare_pattern_tdz(elem.argument, kind);
                        }
                    } elif elem.ntype == ASTNodeType.AssignmentPattern {
                        if elem.left is not None {
                            self._predeclare_pattern_tdz(elem.left, kind);
                        }
                    } else {
                        self._predeclare_pattern_tdz(elem, kind);
                    }
                }
            }
        } elif pat.ntype == ASTNodeType.ObjectPattern {
            for prop in pat.properties {
                if prop.ntype == ASTNodeType.RestElement {
                    if prop.argument is not None {
                        self._predeclare_pattern_tdz(prop.argument, kind);
                    }
                } else {
                    # value/expression is the binding target; key is the source property
                    if prop.expression is not None {
                        if prop.expression.ntype == ASTNodeType.AssignmentPattern {
                            if prop.expression.left is not None {
                                self._predeclare_pattern_tdz(
                                    prop.expression.left, kind
                                );
                            }
                        } else {
                            self._predeclare_pattern_tdz(prop.expression, kind);
                        }
                    } elif prop.shorthand and prop.key is not None {
                        self._predeclare_pattern_tdz(prop.key, kind);
                    }
                }
            }
        }
    }

    """Compile a BlockStatement with TDZ pre-init and strict block-fn hoisting."""
    def _compile_block(nd: ASTNode) {
        self._push_scope(False);
        # Detect a direct `using`/`await using` declaration in this block — if present,
        # bracket the block body with DISPOSE_MARK/DISPOSE_RUN so resources declared
        # here are disposed (reverse order) at block exit.
        blk_has_using: bool = False;
        for ustmt in nd.children {
            if ustmt.ntype == ASTNodeType.VariableDeclaration {
                if ustmt.value == "using" or ustmt.value == "await using" {
                    blk_has_using = True;
                }
            }
        }
        if blk_has_using {
            self._op(Opcode.DISPOSE_MARK);
        }
        # Pre-declare let/const/using at block entry and install TDZ sentinels.
        # `hoist_predeclared` is keyed only by name, so a block-local `let x` would
        # otherwise clobber (and later consume) an outer/top-level `let x`'s predeclare
        # flag — making the outer declaration look like a redeclaration (false
        # SyntaxError, e.g. `{ let x } let x`).  Record which names this block adds and
        # restore the prior flag state at block exit so scopes stay independent.
        blk_predeclared: list[str] = [];
        blk_prior_flag: dict[str, bool] = {};
        for stmt in nd.children {
            if stmt.ntype == ASTNodeType.VariableDeclaration {
                vd_kind: str = stmt.value;
                if vd_kind == "using" or vd_kind == "await using" {
                    vd_kind = "const";
                }
                if vd_kind == "let" or vd_kind == "const" {
                    for vd_decl in stmt.declarations {
                        if vd_decl.id is not None {
                            if vd_decl.id.ntype == ASTNodeType.Identifier {
                                tdz_name: str = vd_decl.id.name;
                                tdz_slot: int = self._declare(tdz_name, vd_kind);
                                if tdz_slot >= 0 {
                                    self._emit_tdz_store(tdz_slot);
                                    # hoist_predeclared is keyed per function-base
                                    # (_hoist_predecl_key), which doesn't distinguish
                                    # sibling blocks in the same function — so still
                                    # save/restore the prior flag at block exit to keep
                                    # sibling block scopes independent.
                                    tdz_key: str = self._hoist_predecl_key(tdz_name);
                                    if tdz_key not in blk_prior_flag {
                                        blk_prior_flag[tdz_key] = tdz_key
                                            in self.hoist_predeclared;
                                        blk_predeclared.append(tdz_key);
                                    }
                                    self.hoist_predeclared[tdz_key] = True;
                                }
                            } elif vd_decl.id.ntype == ASTNodeType.ArrayPattern
                                or vd_decl.id.ntype == ASTNodeType.ObjectPattern {
                                # Predeclare each pattern-bound name with a TDZ sentinel
                                # and a hoist_predeclared flag; track those flags for
                                # save/restore so sibling blocks stay independent (see
                                # the Identifier branch above).  Snapshot the prior flag
                                # state BEFORE predeclaring, since _predeclare_pattern_tdz
                                # sets the flags itself.
                                pat_names: list[str] = [];
                                self._collect_pattern_names(vd_decl.id, pat_names);
                                for pn in pat_names {
                                    pn_key: str = self._hoist_predecl_key(pn);
                                    if pn_key not in blk_prior_flag {
                                        blk_prior_flag[pn_key] = pn_key
                                            in self.hoist_predeclared;
                                        blk_predeclared.append(pn_key);
                                    }
                                }
                                self._predeclare_pattern_tdz(vd_decl.id, vd_kind);
                            }
                        }
                    }
                }
            }
        }
        # Strict mode: hoist block-scoped function declarations.
        if self._fn().is_strict {
            block_fn_names: dict[str, bool] = {};
            self.in_block_fn_decl = True;
            for stmt in nd.children {
                if stmt.ntype == ASTNodeType.FunctionDeclaration {
                    if stmt.id is not None {
                        bf_name: str = stmt.id.name;
                        if bf_name in block_fn_names {
                            self._syntax_error(
                                "SyntaxError: Identifier '"
                                    + bf_name
                                    + "' has already been declared"
                            );
                        } else {
                            block_fn_names[bf_name] = True;
                            self.compile_function_decl(stmt);
                        }
                    }
                }
            }
            self.in_block_fn_decl = False;
            for stmt in nd.children {
                if stmt.ntype != ASTNodeType.FunctionDeclaration {
                    self.compile_stmt(stmt);
                }
            }
        } else {
            # Sloppy mode: BlockDeclarationInstantiation still initializes
            # block-level FunctionDeclarations at block entry (ES §14.2.14 /
            # B.3.3), so references before the textual declaration see the
            # function (e.g. skip-arguments).  Outer var dual-write is handled
            # inside compile_function_decl (suppressed for params/arguments).
            for stmt in nd.children {
                if stmt.ntype == ASTNodeType.FunctionDeclaration {
                    self.compile_function_decl(stmt);
                }
            }
            for stmt in nd.children {
                if stmt.ntype != ASTNodeType.FunctionDeclaration {
                    self.compile_stmt(stmt);
                }
            }
        }
        # Dispose `using` resources declared in this block (reverse order) on normal
        # block exit.  (Abrupt completions — break/return/throw — are handled by the
        # VM's frame dispose-scope unwinding in _unwind_in_frame.)
        if blk_has_using {
            self._op(Opcode.DISPOSE_RUN);
        }
        # Restore the outer `hoist_predeclared` state for names this block shadowed, so
        # a later same-named declaration in an enclosing scope isn't misread as a
        # redeclaration (its own predeclare flag is preserved).
        for bpn in blk_predeclared {
            if blk_prior_flag[bpn] {
                self.hoist_predeclared[bpn] = True;
            } elif bpn in self.hoist_predeclared {
                del self.hoist_predeclared[bpn];
            }
        }
        self._pop_scope();
    }

    # ── var / let / const ─────────────────────────────────────────────────

    def compile_var_decl(nd: ASTNode) {
        decl_kw: str = nd.value;  # "var" | "let" | "const" | "using" | "await using"
        # `using` / `await using` bind exactly like `const` (block-scoped, immutable)
        # and additionally register the resource for disposal at scope exit.
        is_using: bool = decl_kw == "using" or decl_kw == "await using";
        is_async_using: bool = decl_kw == "await using";
        kind: str = decl_kw;
        if is_using {
            kind = "const";
        }
        if is_using {
            # Each declarator's bound value is registered (in source order) onto the
            # current block's disposable-resource stack; the block runs them in
            # reverse at exit.  Mark this block as having `using` so compile_block
            # brackets it with the dispose mark/run opcodes.
            self._using_block_seen = True;
        }
        for decl in nd.declarations {
            if decl.id is None {
                self._syntax_error(
                    "SyntaxError: variable declarator missing binding identifier"
                );
                continue;
            }
            if decl.id.ntype == ASTNodeType.Identifier {
                vname: str = decl.id.name;
                # ES §12.1.1 / §14.3.1.1: in strict mode a `var`/`let`/`const` binding may
                # not be named `eval` or `arguments` (BindingIdentifier early error).
                if self._fn().is_strict and (vname == "eval" or vname == "arguments") {
                    self._syntax_error(
                        "SyntaxError: Unexpected eval or arguments in strict mode"
                    );
                }
                # ES §12.1.1: strict-mode future reserved words are not valid
                # BindingIdentifiers (`public`, `private`, `protected`, `interface`,
                # `package`, `implements`, `let`, `static`, `yield`).
                if self._fn().is_strict
                    and (
                        vname == "public"
                        or vname == "private"
                        or vname == "protected"
                        or vname == "interface"
                        or vname == "package"
                        or vname == "implements"
                        or vname == "let"
                        or vname == "static"
                        or vname == "yield"
                    ) {
                    self._syntax_error(
                        "SyntaxError: Unexpected strict mode reserved word"
                    );
                }
                if kind == "const" and decl.init is None {
                    self._syntax_error(
                        "SyntaxError: Missing initializer in const declaration"
                    );
                }
                decl_kind: str = kind;
                slot: int = -1;
                if kind == "var" and vname in self.param_names {
                    slot = self._param_body_var_slot(vname);
                } elif self._hoist_predecl_key(vname) in self.hoist_predeclared {
                    slot = self._resolve(vname);
                    del self.hoist_predeclared[self._hoist_predecl_key(vname)];
                } else {
                    existing_slot: int = self._resolve(vname);
                    if existing_slot >= 0 {
                        if kind == "var" {
                            ex_k: str = self._get_kind(vname);
                            if (ex_k == "let" or ex_k == "const")
                                and vname not in self.catch_param_names {
                                self._syntax_error(
                                    "SyntaxError: Identifier '"
                                        + vname
                                        + "' has already been declared"
                                );
                            }
                            slot = existing_slot;
                        } elif self._in_current_scope(vname)
                            and vname != self.fn_self_name {
                            # let/const re-bound in the SAME block scope — early error.
                            self._syntax_error(
                                "SyntaxError: Identifier '"
                                    + vname
                                    + "' has already been declared"
                            );
                            slot = existing_slot;
                        } elif vname == self.fn_self_name
                            and self._in_current_scope(vname) {
                            # Body let/const shadowing the function-expression's own
                            # name: allocate a fresh slot in the body scope, overriding
                            # the self-reference binding (which lives in an outer env).
                            # Clear fn_self_name so a SECOND same-name let/const in this
                            # scope is correctly reported as a redeclaration error.
                            slot = self._declare_shadow(vname, decl_kind);
                            self.fn_self_name = "";
                        } else {
                            # let/const shadowing a binding from an enclosing block
                            # scope is allowed — allocate a fresh slot here.
                            slot = self._declare(vname, decl_kind);
                        }
                    } else {
                        slot = self._declare(vname, decl_kind);
                    }
                }
                if kind == "let" or kind == "const" {
                    if slot >= 0 {
                        self._emit_tdz_store(slot);
                    }
                }
                if decl.init is not None {
                    vd_pre_class: bool = self._pre_infer_class_name(decl.init, vname);
                    self.compile_expr(decl.init);
                    # Skip the post-call for a class handled inline by the pre-hook (else it
                    # would emit a SECOND __CLASS_NAME__ store).
                    if not vd_pre_class {
                        self._maybe_infer_fn_name(decl.init, vname);
                    }
                    if is_using {
                        # Register the resource for disposal (DUPs off the value on
                        # the stack), then store into the binding slot.
                        au01: int = 0;
                        if is_async_using {
                            au01 = 1;
                        }
                        self._op(Opcode.DUP);
                        self._emit(
                            make_instruction(Opcode.USING_DECLARE, au01, 0, nd.loc.line)
                        );
                    }
                    if self._is_esm_live(vname) {
                        self._emit_esm_live_store(vname);
                    } elif kind == "var" and self.with_depth > 0 {
                        # `var x = init` inside a `with` body: the *declaration* hoists to
                        # the function/global scope, but the *initializer assignment* is an
                        # ordinary assignment that must resolve through the scope chain —
                        # so a with-object binding of `x` receives the value, not the
                        # hoisted var (ES §14.3.2.1 → PutValue via the running env).
                        self._emit(
                            make_instruction(
                                Opcode.STORE_NAME, self._intern(vname), 0, 0
                            )
                        );
                        self._emit_esm_alias_stores(vname);
                    } elif slot >= 0 {
                        self._emit(make_instruction(Opcode.STORE_LOCAL, slot, 0, 0));
                        self._emit_esm_alias_stores(vname);
                    } else {
                        self._emit_store_global_decl(vname);
                        self._emit_esm_alias_stores(vname);
                    }
                } elif kind != "var" {
                    # `let/const x;` (no initializer) → InitializeBinding(x, undefined).
                    # Live exports must push that value before `_emit_esm_live_store`
                    # (stack: [exports, value]); calling store with an empty stack
                    # corrupted the VM (abort/OOM on `export let x;`).
                    self._op(Opcode.LOAD_UNDEFINED);
                    if self._is_esm_live(vname) {
                        self._emit_esm_live_store(vname);
                    } elif slot < 0 {
                        self._emit_store_global_decl(vname);
                        self._emit_esm_alias_stores(vname);
                    } else {
                        self._emit(make_instruction(Opcode.STORE_LOCAL, slot, 0, 0));
                        self._emit_esm_alias_stores(vname);
                    }
                }
            } elif decl.id.ntype == ASTNodeType.ObjectPattern {
                if decl.init is not None {
                    self.compile_expr(decl.init);
                } else {
                    self._op(Opcode.LOAD_UNDEFINED);
                }
                # Block TDZ pre-scan may have already declared pattern names; reuse
                # those slots (same as for-in/of ForDeclaration) to avoid false
                # "already been declared" errors from compile_obj_pattern.
                prev_reuse_op: bool = self.reuse_predeclared_lexical;
                if kind == "let" or kind == "const" {
                    self.reuse_predeclared_lexical = True;
                }
                self.compile_obj_pattern(decl.id, kind);
                self.reuse_predeclared_lexical = prev_reuse_op;
            } elif decl.id.ntype == ASTNodeType.ArrayPattern {
                if decl.init is not None {
                    self.compile_expr(decl.init);
                } else {
                    self._op(Opcode.LOAD_UNDEFINED);
                }
                prev_reuse_ap: bool = self.reuse_predeclared_lexical;
                if kind == "let" or kind == "const" {
                    self.reuse_predeclared_lexical = True;
                }
                self.compile_arr_pattern(decl.id, kind);
                self.reuse_predeclared_lexical = prev_reuse_ap;
            }
        }
    }

    """Destructure an object pattern from TOS into locals."""
    def compile_obj_pattern(pat: ASTNode, kind: str, iter_cell: bool = False) {
        extracted_keys: list[str] = [];
        do_cell: bool = iter_cell and (kind == "let" or kind == "const");
        # ES §13.15.5.2 / §8.6.2: RequireObjectCoercible on the source — destructuring
        # `null`/`undefined` with an object pattern (`{a} = null`, `function f({}){} f()`)
        # must throw TypeError before any property is read.
        self._op(Opcode.REQUIRE_COERCIBLE);
        for prop in pat.properties {
            if prop.ntype == ASTNodeType.RestElement {
                self._op(Opcode.DUP);
                self._op(Opcode.NEW_OBJECT);
                self._op(Opcode.SWAP);
                # ES §14.3.3.1 CopyDataProperties(excludedItems): excluded keys are
                # FILTERED from the key walk, never read — a getter for an already-
                # destructured key must not fire a second time during the rest copy.
                # arg2 = 1 + constant index of "\x1f"-joined excluded names (0 = none).
                # (Computed keys are not in extracted_keys — same limitation as before.)
                _re_excl_arg: int = 0;
                if len(extracted_keys) > 0 {
                    _re_joined: str = "";
                    _re_i: int = 0;
                    while _re_i < len(extracted_keys) {
                        if _re_i > 0 {
                            _re_joined = _re_joined + "\x1f";
                        }
                        _re_joined = _re_joined + extracted_keys[_re_i];
                        _re_i = _re_i + 1;
                    }
                    _re_excl_arg = self._intern(_re_joined) + 1;
                }
                self._emit(make_instruction(Opcode.OBJECT_SPREAD, 0, _re_excl_arg, 0));
                if prop.argument is not None
                    and prop.argument.ntype == ASTNodeType.Identifier {
                    slot: int = self._declare_lex_binding(prop.argument.name, kind);
                    if slot >= 0 {
                        if do_cell {
                            self._emit(
                                make_instruction(Opcode.STORE_NEW_CELL, slot, 0, 0)
                            );
                        } else {
                            self._emit(
                                make_instruction(Opcode.STORE_LOCAL, slot, 0, 0)
                            );
                        }
                    } else {
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL,
                                self._intern(prop.argument.name),
                                0,
                                0
                            )
                        );
                    }
                } else {
                    self._op(Opcode.POP);
                }
            } else {
                if prop.computed and prop.key is not None {
                    # Computed key: { [expr]: binding } — evaluate key expression at runtime
                    self._op(Opcode.DUP);
                    self.compile_expr(prop.key);
                    self._op(Opcode.GET_INDEX);
                    # Computed keys can't be tracked statically; rest spread exclusion skipped.
                } else {
                    # Non-computed key: Identifier keys use .name, but Literal keys
                    # (numeric `{0: v}` / string `{"a": v}`) carry the key in .value.
                    # Mirror compile_object's key extraction, else numeric/string keys
                    # intern as "" and every GET returns undefined (ES §13.3.5).
                    key_name: str = "";
                    if prop.key is not None {
                        if prop.key.ntype == ASTNodeType.Literal {
                            key_name = prop.key.value;
                        } else {
                            key_name = prop.key.name;
                        }
                    }
                    extracted_keys.append(key_name);
                    self._op(Opcode.DUP);
                    _op_idx: int = self._intern(key_name);
                    self._emit(make_instruction(Opcode.GET_PROP, _op_idx, 0, 0));
                }
                if prop.expression is not None
                    and prop.expression.ntype == ASTNodeType.Identifier {
                    slot: int = self._declare_lex_binding(prop.expression.name, kind);
                    if slot >= 0 {
                        if do_cell {
                            self._emit(
                                make_instruction(Opcode.STORE_NEW_CELL, slot, 0, 0)
                            );
                        } else {
                            self._emit(
                                make_instruction(Opcode.STORE_LOCAL, slot, 0, 0)
                            );
                        }
                    } else {
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL,
                                self._intern(prop.expression.name),
                                0,
                                0
                            )
                        );
                    }
                } elif prop.expression is not None
                    and prop.expression.ntype == ASTNodeType.AssignmentPattern {
                    ap_j: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
                    ap_je: int = self._jump(Opcode.JUMP);
                    self._patch(ap_j);
                    self._op(Opcode.POP);
                    if prop.expression.right is not None {
                        self.compile_expr(prop.expression.right);
                        # ECMAScript §13.3.3.6: infer name from the binding identifier when
                        # the initializer is an anonymous function/arrow (SingleNameBinding rule).
                        if prop.expression.left is not None
                            and prop.expression.left.ntype == ASTNodeType.Identifier {
                            self._maybe_infer_fn_name(
                                prop.expression.right, prop.expression.left.name
                            );
                        }
                    } else {
                        self._op(Opcode.LOAD_UNDEFINED);
                    }
                    self._patch(ap_je);
                    if prop.expression.left is not None
                        and prop.expression.left.ntype == ASTNodeType.Identifier {
                        slot: int = self._declare_lex_binding(
                            prop.expression.left.name, kind
                        );
                        if slot >= 0 {
                            if do_cell {
                                self._emit(
                                    make_instruction(Opcode.STORE_NEW_CELL, slot, 0, 0)
                                );
                            } else {
                                self._emit(
                                    make_instruction(Opcode.STORE_LOCAL, slot, 0, 0)
                                );
                            }
                        } else {
                            self._emit(
                                make_instruction(
                                    Opcode.STORE_GLOBAL,
                                    self._intern(prop.expression.left.name),
                                    0,
                                    0
                                )
                            );
                        }
                    } elif prop.expression.left is not None
                        and prop.expression.left.ntype == ASTNodeType.ArrayPattern {
                        self.compile_arr_pattern(prop.expression.left, kind);
                    } elif prop.expression.left is not None
                        and prop.expression.left.ntype == ASTNodeType.ObjectPattern {
                        self.compile_obj_pattern(prop.expression.left, kind);
                    } else {
                        self._op(Opcode.POP);
                    }
                } elif prop.expression is not None {
                    if prop.expression.ntype == ASTNodeType.ObjectPattern {
                        self.compile_obj_pattern(prop.expression, kind);
                    } elif prop.expression.ntype == ASTNodeType.ArrayPattern {
                        self.compile_arr_pattern(prop.expression, kind);
                    } else {
                        self._op(Opcode.POP);
                    }
                } elif prop.shorthand and prop.key is not None {
                    slot: int = self._declare_lex_binding(prop.key.name, kind);
                    if slot >= 0 {
                        if do_cell {
                            self._emit(
                                make_instruction(Opcode.STORE_NEW_CELL, slot, 0, 0)
                            );
                        } else {
                            self._emit(
                                make_instruction(Opcode.STORE_LOCAL, slot, 0, 0)
                            );
                        }
                    } else {
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL, self._intern(prop.key.name), 0, 0
                            )
                        );
                    }
                } else {
                    self._op(Opcode.POP);
                }
            }
        }
        self._op(Opcode.POP);
    }

    """Destructure an array pattern from TOS into locals."""
    def compile_arr_pattern(pat: ASTNode, kind: str, iter_cell: bool = False) {
        self._op(Opcode.GET_ITER);
        # ES §13.15.5.2 / §8.5.2: array destructuring uses the iterator protocol
        # and must call IteratorClose (§7.4.11) when it finishes with the iterator
        # not yet exhausted, on both normal AND abrupt completion.  We stash the
        # iterator record in a synthetic local so the abrupt-completion handler can
        # reach it regardless of what transient values sit on the stack when an
        # element-target evaluation throws.  If no local slot is available (bare
        # global scope), fall back to the plain path (no close-on-throw).
        ap_iter_name: str = "__dstriter_" + str(self._dstr_iter_seq);
        self._dstr_iter_seq = self._dstr_iter_seq + 1;
        # Declare in the CURRENT (innermost) scope so the synthetic slot shares the
        # same per-scope slot numbering as the pattern's binding targets — using
        # fn_base ("fnhoist"/"var") would hand out a slot that aliases a block-scoped
        # binding (e.g. `for (const [name] of …)` where name is block slot 0).
        # "const" is a fresh unique-named lexical → real local slot everywhere
        # (module top level included); we emit plain STORE_LOCAL/LOAD_LOCAL for it.
        ap_iter_slot: int = self._declare(ap_iter_name, "const");
        ap_use_close: bool = ap_iter_slot >= 0;
        ap_catch_jmp: int = -1;
        if ap_use_close {
            self._op(Opcode.DUP);  # [iter, iter]
            self._emit(make_instruction(Opcode.STORE_LOCAL, ap_iter_slot, 0, 0));  # [iter]
            ap_catch_jmp = self._jump(Opcode.PUSH_CATCH);
        }
        do_cell: bool = iter_cell and (kind == "let" or kind == "const");
        for elem in pat.elements {
            if elem.ntype == ASTNodeType.Identifier {
                self._op(Opcode.ITER_NEXT_VAL);
                if elem.name == "undefined" {
                    self._op(Opcode.POP);
                } else {
                    slot: int = self._declare_lex_binding(elem.name, kind);
                    if slot >= 0 {
                        if do_cell {
                            self._emit(
                                make_instruction(Opcode.STORE_NEW_CELL, slot, 0, 0)
                            );
                        } else {
                            self._emit(
                                make_instruction(Opcode.STORE_LOCAL, slot, 0, 0)
                            );
                        }
                    } else {
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL, self._intern(elem.name), 0, 0
                            )
                        );
                    }
                }
            } elif elem.ntype == ASTNodeType.RestElement {
                self._op(Opcode.REST_ARGS);
                if elem.argument is not None {
                    # ES §13.15.5.5 BindingRestElement: the rest target may itself
                    # be a binding pattern (`[...[a, b]]`, `[...{ length }]`), in
                    # which case the collected array is destructured recursively
                    # rather than bound to a single identifier.
                    if elem.argument.ntype == ASTNodeType.ArrayPattern {
                        self.compile_arr_pattern(elem.argument, kind);
                    } elif elem.argument.ntype == ASTNodeType.ObjectPattern {
                        self.compile_obj_pattern(elem.argument, kind);
                    } else {
                        slot: int = self._declare_lex_binding(elem.argument.name, kind);
                        if slot >= 0 {
                            if do_cell {
                                self._emit(
                                    make_instruction(Opcode.STORE_NEW_CELL, slot, 0, 0)
                                );
                            } else {
                                self._emit(
                                    make_instruction(Opcode.STORE_LOCAL, slot, 0, 0)
                                );
                            }
                        } else {
                            self._emit(
                                make_instruction(
                                    Opcode.STORE_GLOBAL,
                                    self._intern(elem.argument.name),
                                    0,
                                    0
                                )
                            );
                        }
                    }
                } else {
                    self._op(Opcode.POP);
                }
            } elif elem.ntype == ASTNodeType.AssignmentPattern {
                self._op(Opcode.ITER_NEXT_VAL);
                ap2_j: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
                ap2_je: int = self._jump(Opcode.JUMP);
                self._patch(ap2_j);
                self._op(Opcode.POP);
                if elem.right is not None {
                    self.compile_expr(elem.right);
                    # ECMAScript §13.3.3.6: infer name from the binding identifier when
                    # the initializer is an anonymous function/arrow (SingleNameBinding rule).
                    if elem.left is not None
                        and elem.left.ntype == ASTNodeType.Identifier {
                        self._maybe_infer_fn_name(elem.right, elem.left.name);
                    }
                } else {
                    self._op(Opcode.LOAD_UNDEFINED);
                }
                self._patch(ap2_je);
                if elem.left is not None
                    and elem.left.ntype == ASTNodeType.Identifier {
                    slot: int = self._declare_lex_binding(elem.left.name, kind);
                    if slot >= 0 {
                        if do_cell {
                            self._emit(
                                make_instruction(Opcode.STORE_NEW_CELL, slot, 0, 0)
                            );
                        } else {
                            self._emit(
                                make_instruction(Opcode.STORE_LOCAL, slot, 0, 0)
                            );
                        }
                    } else {
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL, self._intern(elem.left.name), 0, 0
                            )
                        );
                    }
                } elif elem.left is not None
                    and elem.left.ntype == ASTNodeType.ArrayPattern {
                    self.compile_arr_pattern(elem.left, kind);
                } elif elem.left is not None
                    and elem.left.ntype == ASTNodeType.ObjectPattern {
                    self.compile_obj_pattern(elem.left, kind);
                } else {
                    self._op(Opcode.POP);
                }
            } elif elem.ntype == ASTNodeType.ArrayPattern {
                self._op(Opcode.ITER_NEXT_VAL);
                self.compile_arr_pattern(elem, kind);
            } elif elem.ntype == ASTNodeType.ObjectPattern {
                self._op(Opcode.ITER_NEXT_VAL);
                self.compile_obj_pattern(elem, kind);
            } else {
                self._op(Opcode.ITER_NEXT_VAL);
                self._op(Opcode.POP);
            }
        }
        if ap_use_close {
            # Normal completion: leave the catch region, then IteratorClose the
            # (still-on-stack) iterator record if it is not already exhausted.
            self._op(Opcode.POP_CATCH);
            self._op(Opcode.ITER_CLOSE_NRML);  # pops the iterator record
            ap_skip_thrw: int = self._jump(Opcode.JUMP);
            # Abrupt-completion handler: an element target threw.  The exception is
            # on TOS; the iterator record is in ap_iter_slot.  ITER_CLOSE_THRW reads
            # the iterator from the slot, closes it (swallowing return()'s own
            # error), then re-throws the original exception.
            self._patch(ap_catch_jmp);
            self._emit(make_instruction(Opcode.LOAD_LOCAL, ap_iter_slot, 0, 0));  # [exc, iter]
            self._op(Opcode.ITER_CLOSE_THRW);
            self._patch(ap_skip_thrw);
        } else {
            self._op(Opcode.POP);
        }
    }

    # ── function declaration ──────────────────────────────────────────────

    def compile_function_decl(nd: ASTNode, module_local: bool = False) {
        # (see _compile_function(is_declaration=True) call below — a declaration's
        # name is a mutable outer binding, not an immutable fnself self-name)
        # ES §12.1.1 (BindingIdentifier early errors): in strict mode a function
        # declaration named `eval` or `arguments` is a SyntaxError.
        if nd.id is not None
            and self._fn().is_strict
            and (nd.id.name == "eval" or nd.id.name == "arguments") {
            self._syntax_error(
                "SyntaxError: Unexpected eval or arguments in strict mode"
            );
        }
        # ECMAScript hoisting: pre-declare the name in the current scope BEFORE
        # compiling the body.  This ensures recursive references inside the body
        # (e.g. fib calling fib) can find the name via _resolve() / _capture()
        # rather than falling back to LOAD_GLOBAL (which would be undefined).
        #
        # `module_local`: when True the declaration is bound as a local of the
        # enclosing <main> (module) wrapper instead of being stored in the
        # single VM-wide globals map.  This gives each module its own lexical
        # scope for top-level `function` declarations so that two modules that
        # each declare `function t(){}` do not collide in the shared globals.
        # Exported closures that reference such a function capture it as a
        # free-variable cell, so the binding persists with the closure even
        # after the module body finishes executing.
        pre_slot: int = -1;
        pre_name: str = "";
        is_local: bool = False;
        # Annex B.3.3 dual-write: outer function-scoped var slot to also update
        # when a sloppy block-level function is evaluated (or -1 if suppressed).
        annexb_var_slot: int = -1;
        annexb_var_is_global: bool = False;
        if nd.id is not None and len(self.fn_stack) > 1 {
            pre_name = nd.id.name;
            pre_kind: str = "var";
            if self.in_block_fn_decl {
                pre_kind = "let";
            }
            # Sloppy nested-block function: Annex B.3.3 — bind as block `let`,
            # and (unless a colliding lexical would make a var early-error)
            # also mirror into the function-scoped var environment.
            elif (not self._fn().is_strict) and self._in_nested_block() {
                pre_kind = "let";
                if not self._annexb_blocked_by_lexical(pre_name) {
                    # Prefer the slot pre-declared at FunctionDeclarationInstantiation
                    # (annexb_block_fn_names); otherwise create one now.
                    if len(self.fn_scope_base) == 1 {
                        annexb_var_is_global = True;
                    } else {
                        annexb_var_slot = self._resolve_at_fn_base(pre_name);
                        if annexb_var_slot < 0 {
                            annexb_var_slot = self._declare(pre_name, "var");
                        }
                        if annexb_var_slot >= 0 {
                            self.annexb_block_fn_names[pre_name] = True;
                        }
                    }
                }
            }
            # For Annex B / block `let` bindings, ALWAYS allocate a fresh slot in
            # the current block — `_resolve` would otherwise reuse the outer
            # function-scoped `var` slot and the two bindings would alias
            # (block assignment would clobber the outer var).
            # B.3.3.4: duplicate FunctionDeclarations in the same sloppy block
            # redeclare the same block binding (last wins) — reuse that slot.
            if pre_kind == "let" {
                ab_redecl: bool = pre_name in self.block_fn_decl_names
                    and self._in_current_scope(pre_name);
                if ab_redecl {
                    n_sc: int = len(self.scope_stack);
                    pre_slot = self.scope_stack[n_sc - 1].vars[pre_name];
                } else {
                    pre_slot = self._declare(pre_name, "let");
                    if pre_slot >= 0 {
                        self.block_fn_decl_names[pre_name] = True;
                        self._emit_tdz_store(pre_slot);
                    }
                }
            } else {
                pre_slot = self._resolve(pre_name);
                if pre_slot < 0 {
                    pre_slot = self._declare(pre_name, pre_kind);
                }
            }
            is_local = True;
        } elif nd.id is not None and self.in_block_fn_decl {
            # Strict block-level function declaration at TOP-LEVEL (`{ function f(){} }`
            # in global/eval script): ES §14.6 / §11.2.2 — this is block-scoped, NOT
            # var-hoisted to the global object.  Bind it as a block-local `let` slot
            # (block scopes at <main> hold real local slots) so `f` outside the block is
            # a dead lexical → ReferenceError, instead of leaking to globalThis.
            pre_name = nd.id.name;
            pre_slot = self._declare(pre_name, "let");
            if pre_slot >= 0 {
                self._emit_tdz_store(pre_slot);
            }
            is_local = True;
        } elif nd.id is not None
            and (not self._fn().is_strict)
            and self._in_nested_block() {
            # Sloppy top-level (or eval) nested-block function — Annex B.3.3 /
            # B.3.3.2 Changes to GlobalDeclarationInstantiation.  Bind as block
            # `let`; mirror to varEnv only when no colliding lexical exists.
            # Check blocked BEFORE declaring the block `let` — otherwise the
            # freshly-declared binding would self-suppress the dual-write.
            pre_name = nd.id.name;
            if not self._annexb_blocked_by_lexical(pre_name) {
                annexb_var_is_global = True;
            }
            ab_redecl_g: bool = pre_name in self.block_fn_decl_names
                and self._in_current_scope(pre_name);
            if ab_redecl_g {
                n_sc_g: int = len(self.scope_stack);
                pre_slot = self.scope_stack[n_sc_g - 1].vars[pre_name];
            } else {
                pre_slot = self._declare(pre_name, "let");
                if pre_slot >= 0 {
                    self.block_fn_decl_names[pre_name] = True;
                    self._emit_tdz_store(pre_slot);
                }
            }
            is_local = True;
        } elif nd.id is not None and module_local and not self.in_direct_eval {
            # Top-level module scope: force a real local slot in <main> even
            # though _declare("var") would otherwise treat it as a global.
            # "fnhoist" allocates a concrete slot but stays freely redeclarable
            # (function-scoped, last-wins) — matching ECMAScript semantics for
            # `function f(){} var f;` and duplicate function declarations.
            # compile_program's hoist pre-pass may have already declared this name.
            pre_name = nd.id.name;
            pre_slot = self._resolve(pre_name);
            if pre_slot < 0 {
                pre_slot = self._declare(pre_name, "fnhoist");
            }
            is_local = True;
        }

        fn_val: CompiledFunction = self._compile_function(nd, True);
        fn_idx: int = len(self.all_fns);
        self.all_fns.append(fn_val);
        self._emit(make_instruction(Opcode.MAKE_FUNCTION, fn_idx, 0, 0));
        if nd.id is not None {
            name: str = nd.id.name;
            if is_local {
                if pre_slot >= 0 {
                    # Annex B.3.3: also write the function object to the outer
                    # function-scoped var / global binding (keep a copy on stack).
                    if annexb_var_slot >= 0 or annexb_var_is_global {
                        self._op(Opcode.DUP);
                    }
                    self._emit(make_instruction(Opcode.STORE_LOCAL, pre_slot, 0, 0));
                    if annexb_var_slot >= 0 {
                        self._emit(
                            make_instruction(Opcode.STORE_LOCAL, annexb_var_slot, 0, 0)
                        );
                    } elif annexb_var_is_global {
                        # Annex B dual-write into varEnv: prefer STORE_GLOBAL so
                        # (a) globalThis data properties stay in sync and
                        # (b) direct-eval can redirect into the caller's dyn vars.
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL, self._intern(name), 0, 0
                            )
                        );
                    }
                } else {
                    self._emit(
                        make_instruction(Opcode.STORE_GLOBAL, self._intern(name), 0, 0)
                    );
                }
            } else {
                # top-level: store globally so LOAD_GLOBAL can find it.
                # ES §9.1.1.4.16 CreateGlobalFunctionBinding: a SCRIPT-level function
                # declaration creates a NON-configurable own property of the global
                # object (so `delete f` returns false — S13_A12_T1). A direct-eval
                # top-level function is configurable:true instead. Modules take the
                # is_local branch above (module-local binding, never a global prop).
                if len(self.fn_scope_base) == 1 and not self.compiling_module {
                    fn_cfg: int = 1 if self.in_direct_eval else 0;
                    self._emit(
                        make_instruction(
                            Opcode.CREATE_GLOBAL_FN_BINDING,
                            self._intern(name),
                            fn_cfg,
                            0
                        )
                    );
                } else {
                    self._emit_store_global_decl(name);
                }
            }
        } else {
            self._op(Opcode.POP);
        }
    }

    # ── class declaration ─────────────────────────────────────────────────

    """Emit a computed-key class field (ES §15.7.10).

    The key expression is evaluated **once at class-definition time** (in source
    order, interleaved with methods) and left on the stack; a synthetic 1-param
    init function `function(__k){ this[__k] = <init|undefined>; }` is built and
    pushed above it. `DEFINE_FIELD` (arg3=1) then captures both: for a static
    field it runs the init fn immediately with the key; for an instance field it
    stores a `{__f, __k}` entry on the class so the constructor's field-init loop
    binds `this[__k]` per instance.

    `m_has_init` selects between the initializer expression and `undefined`."""
    def _emit_computed_field(m: ASTNode, m_is_static_f: int, m_has_init: bool) {
        # 1. Evaluate the computed key once, now — leave it on the stack.
        #    ClassFieldDefinitionEvaluation (ES §15.7.10) evaluates ClassElementName
        #    → ComputedPropertyName → ToPropertyKey at DEFINITION time, so a throwing
        #    toString/valueOf/@@toPrimitive (or a non-key return) aborts the class
        #    definition here — NOT deferred to the (possibly much later) instance
        #    field init. Coerce now; SET_INDEX inside the init fn then re-uses the key.
        if m.key is not None {
            self.compile_expr(m.key);
        } else {
            self._op(Opcode.LOAD_UNDEFINED);
        }
        self._op(Opcode.TO_PROPERTY_KEY);
        # 2. Build the synthetic init fn:  function(__k){ this[__k] = value; }
        fi_sp: bool = self.super_prop_allowed;
        fi_sc: bool = self.super_call_allowed;
        self.super_prop_allowed = True;
        self.super_call_allowed = False;
        self._push_fn("");
        self._fn().is_field_init = True;  # ES §15.7.1 eval-in-field early errors
        ck_slot: int = self._declare("__ck", "let");  # param slot 0
        # SET_INDEX pops (val, idx, obj) → push obj, idx, val in that order.
        self._op(Opcode.LOAD_THIS);  # obj
        self._emit(make_instruction(Opcode.LOAD_LOCAL, ck_slot, 0, 0));  # idx (the key)
        if m_has_init and m.expression is not None {
            self.compile_expr(m.expression);  # val
        } else {
            self._op(Opcode.LOAD_UNDEFINED);
        }
        # Class fields are CreateDataProperty (arg3=1), never [[Set]] — a computed
        # key colliding with an inherited/own read-only or non-enumerable slot
        # (e.g. `static ['constructor']`) must still define an own {w:T,e:T,c:T}
        # data property (ES §15.7.10 DefineField).
        self._emit(make_instruction(Opcode.SET_INDEX, 0, 0, 0, 1));  # this[key] = val (pushes val)
        self._op(Opcode.POP);
        self._op(Opcode.RETURN_UNDEFINED);
        f_cf: CompiledFunction = self._pop_fn();
        f_cf.params.append("__ck");
        f_cf.param_base = 0;
        self.super_prop_allowed = fi_sp;
        self.super_call_allowed = fi_sc;
        f_cf_idx: int = len(self.all_fns);
        self.all_fns.append(f_cf);
        self._emit(make_instruction(Opcode.MAKE_FUNCTION, f_cf_idx, 0, 0));
        # 3. DEFINE_FIELD with arg3=1 → computed: key sits below the fn on the stack.
        self._emit(
            make_instruction(Opcode.DEFINE_FIELD, self._intern(""), m_is_static_f, 0, 1)
        );
    }

    def compile_class_decl(nd: ASTNode) {
        # ES §15.7: all class code is strict; force it for every function compiled
        # while inside this body (methods, constructor, field inits, static blocks).
        self.in_class_body = self.in_class_body + 1;
        # Open this class body's private-name scope (per-class brands).
        self._enter_priv_scope(nd);
        # Pre-declare the class name in the current scope BEFORE compiling the
        # body.  This ensures references to the class inside its own methods
        # (e.g. EventEmitter.defaultMaxListeners in getMaxListeners) can be
        # captured as free variables when the class is inside a function scope.
        pre_slot: int = -1;
        pre_is_local: bool = False;
        if nd.id is not None and len(self.fn_stack) > 1 {
            pre_slot = self._resolve(nd.id.name);
            if pre_slot < 0 {
                pre_slot = self._declare(nd.id.name, "let");
                if pre_slot >= 0 {
                    self._emit_tdz_store(pre_slot);
                }
            }
            pre_is_local = True;
        } elif nd.id is not None
            and (len(self.scope_stack) - 1) == self._fn_base()
            and self.compiling_module
            and not self.in_direct_eval {
            # MODULE goal: a top-level class is bound as a LOCAL of this module's
            # <main> wrapper (module-local), exactly like top-level function
            # declarations (see compile_program's module_local hoist). Storing it as
            # a VM-wide global lexical name instead makes two modules that each
            # declare `class Scope {}` collide on the single shared globals map —
            # the second overwrites the first, so the first module's `new Scope()`
            # constructs the wrong class. Force a real local slot (in TDZ) so the
            # class-store below writes STORE_LOCAL and each module keeps its own.
            pre_slot = self._resolve(nd.id.name);
            if pre_slot < 0 {
                pre_slot = self._declare(nd.id.name, "let");
                if pre_slot >= 0 {
                    self._emit_tdz_store(pre_slot);
                }
            }
            pre_is_local = True;
        } elif nd.id is not None and (len(self.scope_stack) - 1) == self._fn_base() {
            # Classic SCRIPT goal: a class declared directly at the top level of the
            # script scope becomes a global lexical name (visible to
            # `new Function(...)` which closes over the realm global env). A class
            # nested in a block/switch/if at global scope stays block-scoped, so its
            # name must NOT leak to globals (test262 switch/scope-lex-class:
            # `switch(0){default: class x{}} x;` must throw ReferenceError).
            self.lexical_global_names[nd.id.name] = True;
        }
        # Inner immutable class-name binding (ES §15.7.4) — see the detailed note at
        # the member-loop entry below. Declared (in TDZ) BEFORE the heritage clause so
        # a closure in `extends (...)` captures it and observes the class once
        # initialised (scope-name-lex-open-heritage). Pushed after the OUTER pre-decl
        # above so the outer stores still target the outer binding.
        cd_name_scope: bool = False;
        cd_name_slot: int = -1;
        if nd.id is not None {
            self._push_scope(False);
            cd_name_scope = True;
            cd_name_slot = self._declare(nd.id.name, "const");
            if cd_name_slot >= 0 {
                self._emit_tdz_store(cd_name_slot);
            }
        }
        has_super: int = 0;
        if nd.superclass is not None {
            self.compile_expr(nd.superclass);
            has_super = 1;
        }
        # arg2 = this class's private-scope id (sid), so the VM can stamp `__brandsid@cur`
        # on the class object → captured onto member closures for the sid-aware brand check.
        _mc_sid: int = self.priv_scope_ids[len(self.priv_scope_ids) - 1]
            if len(self.priv_scope_ids) > 0
            else 0;
        self._emit(make_instruction(Opcode.MAKE_CLASS, has_super, _mc_sid, 0));
        # Initialise the inner immutable self-binding from the class value (on TOS).
        if cd_name_slot >= 0 {
            self._op(Opcode.DUP);
            self._emit(make_instruction(Opcode.STORE_LOCAL, cd_name_slot, 0, 0));
        }
        # Set class.name (ECMAScript §15.7.3.8): stored as __CLASS_NAME__ so the VM's
        # GET_PROP "name" handler can serve it without triggering setter-chain traversal.
        if nd.id is not None {
            self._op(Opcode.DUP);
            self._const("s:" + nd.id.name);
            cls_name_key_cd: int = self._intern("__CLASS_NAME__");
            self._emit(make_instruction(Opcode.SET_PROP, cls_name_key_cd, 0, 0));
            self._op(Opcode.POP);
            # A10/ES §15.7: inside the class body (static blocks, field initializers,
            # computed member keys) the class binding is already initialized — bind
            # the name to its slot/global NOW (DUP keeps the class on TOS for the
            # member loop) so `C.x` in a `static { … }` resolves instead of throwing
            # TDZ. The post-loop store below is then a redundant no-op refresh.
            if nd.id is not None {
                self._op(Opcode.DUP);
                cls_early_name: str = nd.id.name;
                if pre_is_local {
                    if pre_slot >= 0 {
                        self._emit(
                            make_instruction(Opcode.STORE_LOCAL, pre_slot, 0, 0)
                        );
                    } else {
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL, self._intern(cls_early_name), 0, 0
                            )
                        );
                    }
                } else {
                    self._emit_store_global_decl(cls_early_name);
                }
            }
        }
        # (The inner immutable class-name binding — the INNER of the two bindings a
        # class DECLARATION creates: OUTER mutable in the enclosing scope, INNER const
        # scoped to the class body that methods/statics capture, so
        # `cls.prototype.method()` still returns the class after outer `C = null`
        # (scope-name-lex-close) — was declared above, before the heritage clause.)
        # ES §13.15.5 / §10.2.1.3: PrivateMethodOrAccessorAdd runs BEFORE field
        # initializers in InitializeInstanceElements, so an instance field initializer
        # can call a private method (`a = this.#m()`). The per-instance brand marker is
        # what makes a private method reachable, so register its install as the FIRST
        # instance field (index 0 in __FIELDS__) — before any user field.
        if len(self.priv_scope_ids) > 0 and self._class_needs_instance_brand(nd) {
            self._emit_private_brand_install(
                self.priv_scope_ids[len(self.priv_scope_ids) - 1], 0
            );
        }
        # The STATIC private brand is likewise the FIRST static element (so a static block
        # can access a static private): its DEFINE_FIELD(static) must precede any user static
        # field/block, which now all defer into __STATIC_FIELDS__ (run by RUN_STATIC_ELEMENTS).
        if len(self.priv_scope_ids) > 0 and self._class_needs_static_brand(nd) {
            self._emit_private_brand_install(
                self.priv_scope_ids[len(self.priv_scope_ids) - 1], 1
            );
        }
        # Compile each method/field in the body; class stays on TOS after each DEFINE_METHOD
        for m in nd.children {
            if m.ntype == ASTNodeType.MethodDefinition {
                m_key: str = "";
                m_computed: bool = m.computed;
                # m_lit_key: a non-computed *literal* key (string/number). String
                # literals carry their cooked key in m_key (compile-time); numeric
                # literals are emitted through the runtime computed path so the VM
                # canonicalizes them (0x10 → "16", 1e2 → "100", etc.).
                m_lit_key: bool = False;
                m_lit_num: bool = False;
                if m.key is not None
                    and m.key.ntype == ASTNodeType.Identifier
                    and not m_computed {
                    m_key = m.key.name;
                } elif m.key is not None
                    and m.key.ntype == ASTNodeType.Literal
                    and not m_computed {
                    m_lit_key = True;
                    if m.key.kind == "string" {
                        m_key = _unescape_string(m.key.value);
                    } elif m.key.kind == "number" {
                        m_lit_num = True;
                    } else {
                        # bool/null/etc. literal key — use its source text verbatim.
                        m_key = m.key.value;
                    }
                }
                if m.kind == "static-block" {
                    # Static initialization block (ES2022 §15.7): compile the body as
                    # a synthetic zero-arg function and run it once at class-definition
                    # time with this=class via the static DEFINE_FIELD path (which
                    # calls the fn and discards its return). Empty key — not a property.
                    if m.expression is not None {
                        # B9: static blocks have a home object — `super.x` is allowed.
                        # Static block `super.x` resolves against the super class (static).
                        self.pending_super_prop = True;
                        self.pending_super_call = False;
                        self.pending_super_static = True;
                        self.compile_expr(m.expression);  # MAKE_FUNCTION → fn on TOS
                        self._emit(
                            make_instruction(
                                Opcode.DEFINE_FIELD, self._intern(""), 1, 0
                            )
                        );
                    }
                    continue;
                }
                if m.kind == "field" {
                    # Instance/static field initializer
                    m_is_static_f: int = 0;
                    if m.is_static {
                        m_is_static_f = 1;
                    }
                    # Check if field has a real initializer (not the empty Identifier placeholder)
                    m_has_init: bool = True;
                    if m.expression is not None
                        and m.expression.ntype == ASTNodeType.Identifier
                        and m.expression.name == "" {
                        m_has_init = False;
                    }
                    if m.expression is None {
                        m_has_init = False;
                    }
                    if m_computed or m_lit_num {
                        # Computed-key field (`[expr]` / `[expr] = v`) OR a NUMERIC-literal
                        # key field (`0 = 'bar'`, `1.5;`): evaluate the key once now and
                        # capture it into a 1-param init fn (ES §15.7.10). Numeric literals
                        # ride the same path so the VM canonicalizes the key via
                        # ToPropertyKey (`0`→"0", `0x10`→"16") — the non-computed literal
                        # path below leaves m_key "" and would install a bogus "" property.
                        self._emit_computed_field(m, m_is_static_f, m_has_init);
                        continue;
                    }
                    if m_has_init and m.expression is not None {
                        # ES §15.7.1 Early Error: a class field initializer must not
                        # contain `arguments` (it is not a function body). `new.target`
                        # IS allowed directly; it is only rejected inside `eval` that
                        # inherits the field context (handled via eval_field_init below).
                        # ES §15.7.1 Early Error: a class field initializer must not
                        # contain `arguments` (it is not a function body). `new.target`
                        # IS allowed directly. Walk the initializer, not descending into
                        # nested ordinary functions (they have their own `arguments`);
                        # arrows inherit it, so we DO descend into them. Inlined (the
                        # compiler.na.jac archetype is at its parser function-count cap).
                        fi_work: list[ASTNode] = [m.expression];
                        fi_wi: int = 0;
                        while fi_wi < len(fi_work) {
                            fi_s: ASTNode = fi_work[fi_wi];
                            fi_wi = fi_wi + 1;
                            if fi_s is None {
                                continue;
                            }
                            fi_t: ASTNodeType = fi_s.ntype;
                            if fi_t == ASTNodeType.Identifier
                                and fi_s.name == "arguments" {
                                self._syntax_error(
                                    "SyntaxError: 'arguments' is not allowed in class field initializer"
                                );
                                fi_wi = len(fi_work);
                                continue;
                            }
                            if fi_t == ASTNodeType.FunctionExpression
                                or fi_t == ASTNodeType.FunctionDeclaration {
                                continue;
                            }
                            if fi_s.left is not None {
                                fi_work.append(fi_s.left);
                            }
                            if fi_s.right is not None {
                                fi_work.append(fi_s.right);
                            }
                            if fi_s.argument is not None {
                                fi_work.append(fi_s.argument);
                            }
                            if fi_s.callee is not None {
                                fi_work.append(fi_s.callee);
                            }
                            if fi_s.object is not None {
                                fi_work.append(fi_s.object);
                            }
                            if fi_s.property is not None
                                and fi_t != ASTNodeType.MetaProperty {
                                fi_work.append(fi_s.property);
                            }
                            if fi_s.cond_expr is not None {
                                fi_work.append(fi_s.cond_expr);
                            }
                            if fi_s.consequent is not None {
                                fi_work.append(fi_s.consequent);
                            }
                            if fi_s.alternate is not None {
                                fi_work.append(fi_s.alternate);
                            }
                            if fi_s.expression is not None {
                                fi_work.append(fi_s.expression);
                            }
                            if fi_s.body is not None {
                                fi_work.append(fi_s.body);
                            }
                            if fi_s.superclass is not None {
                                fi_work.append(fi_s.superclass);
                            }
                            for fi_a in fi_s.arguments {
                                fi_work.append(fi_a);
                            }
                            for fi_e in fi_s.elements {
                                if fi_e is not None {
                                    fi_work.append(fi_e);
                                }
                            }
                            for fi_p in fi_s.properties {
                                fi_work.append(fi_p);
                            }
                            for fi_ex in fi_s.expressions {
                                fi_work.append(fi_ex);
                            }
                            for fi_pr in fi_s.params {
                                fi_work.append(fi_pr);
                            }
                            for fi_c in fi_s.children {
                                fi_work.append(fi_c);
                            }
                        }
                        # Has an initializer — wrap in a synthetic function:
                        #   function() { this.<key> = <init_expr>; }
                        # B9: field initializers have a home object — `super.x` is
                        # allowed (but not `super()`).
                        fi_sp: bool = self.super_prop_allowed;
                        fi_sc: bool = self.super_call_allowed;
                        self.super_prop_allowed = True;
                        self.super_call_allowed = False;
                        self._push_fn("");
                        self._fn().is_field_init = True;  # ES §15.7.1 eval-in-field early errors
                        self.compile_expr(m.expression);
                        # ES §15.7.10 NamedEvaluation: an anonymous fn/arrow/class initializer of
                        # a field named `x`/`#field` infers that name (`.name === "x"`).
                        self._maybe_infer_fn_name(m.expression, m_key);
                        self._op(Opcode.LOAD_THIS);
                        self._op(Opcode.SWAP);
                        # Class field → CreateDataProperty (arg3=1), never [[Set]]
                        # (ES §15.7.10 DefineField): defines an own {w:T,e:T,c:T} slot.
                        self._emit(
                            make_instruction(
                                Opcode.SET_PROP,
                                self._intern(self._prop_key(m_key)),
                                0,
                                0,
                                1
                            )
                        );
                        self._op(Opcode.POP);
                        self._op(Opcode.RETURN_UNDEFINED);
                        f_init: CompiledFunction = self._pop_fn();
                        self.super_prop_allowed = fi_sp;
                        self.super_call_allowed = fi_sc;
                        f_init_idx: int = len(self.all_fns);
                        self.all_fns.append(f_init);
                        self._emit(
                            make_instruction(Opcode.MAKE_FUNCTION, f_init_idx, 0, 0)
                        );
                        self._emit(
                            make_instruction(
                                Opcode.DEFINE_FIELD,
                                self._intern(self._prop_key(m_key)),
                                m_is_static_f,
                                0
                            )
                        );
                    }
                    # No initializer (ES §15.7.10): the field is still defined as an
                    # own data property with value undefined at construction time
                    # (before the constructor body runs, so there is no risk of
                    # overwriting a later assignment). Emit a synthetic init fn
                    # `function(){ this.<key> = undefined; }`. Computed no-init keys
                    # are handled above via _emit_computed_field.
                    if not m_has_init and m_key != "" {
                        # No-initializer field (ES §15.7.10): the slot is defined as
                        # own {value: undefined, w:T,e:T,c:T} at construction.  Rather
                        # than compile a whole synthetic `function(){ this.k = undefined }`
                        # per field — which for a class with thousands of bare fields
                        # (e.g. the Unicode ID_Start conformance tests: 6k–8k private
                        # names) costs a CompiledFunction + closure each and blows past
                        # the test-runner memory cap — emit a lightweight bare-field
                        # marker (DEFINE_FIELD arg3=2).  The key string is the value on
                        # the stack; DEFINE_FIELD records it so DefineField installs the
                        # undefined slot directly (static: now; instance: per-construct).
                        nf_key: str = self._prop_key(m_key);
                        self._const("s:" + nf_key);
                        self._emit(
                            make_instruction(
                                Opcode.DEFINE_FIELD,
                                self._intern(nf_key),
                                m_is_static_f,
                                0,
                                2
                            )
                        );
                    }
                    continue;
                }
                if m.expression is None {
                    continue;
                }
                # For computed method names ([expr]()), push the key expr first,
                # then the function.  VM pops both when arg==-1.  Numeric literal
                # keys (m_lit_num) also go through the runtime key path so the VM
                # canonicalizes them; string/identifier keys use a static arg.
                m_runtime_key: bool = m_computed or m_lit_num;
                if m_computed and m.key is not None {
                    self.compile_expr(m.key);
                } elif m_lit_num and m.key is not None {
                    self.compile_literal(m.key);  # pushes the number constant
                }
                # B9: all class methods/accessors may use `super.x`; only a derived
                # class's constructor may use `super()`.
                self.pending_super_prop = True;
                self.pending_super_call = has_super == 1 and m_key == "constructor";
                self.pending_super_static = m.is_static;
                self.compile_expr(m.expression);  # emits MAKE_FUNCTION → fn on TOS
                # ECMAScript §10.2.9: infer method name at compile time when the key
                # is known statically (identifier or string literal). Getters/setters
                # get "get <key>"/"set <key>"; regular methods get "<key>".
                if not m_runtime_key and m_key != "" and m_key != "constructor" {
                    m_inferred_name: str = m_key;
                    if m.kind == "get" {
                        m_inferred_name = "get " + m_key;
                    } elif m.kind == "set" {
                        m_inferred_name = "set " + m_key;
                    }
                    self._maybe_infer_fn_name(m.expression, m_inferred_name);
                    # Computed / numeric-literal method key: name is inferred at runtime
                    # from the key on the stack (ES §12.2.6.9).  Stack is [class, key, fn].
                } elif m_runtime_key and m.kind != "constructor" {
                    m_infer_pfx: int = 0;
                    if m.kind == "get" {
                        m_infer_pfx = 1;
                    } elif m.kind == "set" {
                        m_infer_pfx = 2;
                    }
                    self._emit(
                        make_instruction(Opcode.INFER_NAME_FROM_KEY, 0, m_infer_pfx, 0)
                    );
                }
                m_is_static: int = 0;
                if m.is_static {
                    m_is_static = 1;
                }
                m_key_arg: int = -1;
                if not m_runtime_key {
                    m_key_arg = self._intern(self._prop_key(m_key));
                }
                if m.kind == "get" {
                    self._emit(
                        make_instruction(
                            Opcode.DEFINE_GETTER, m_key_arg, m_is_static, 0
                        )
                    );
                } elif m.kind == "set" {
                    self._emit(
                        make_instruction(
                            Opcode.DEFINE_SETTER, m_key_arg, m_is_static, 0
                        )
                    );
                } else {
                    self._emit(
                        make_instruction(
                            Opcode.DEFINE_METHOD, m_key_arg, m_is_static, 0
                        )
                    );
                }
            }
        }
        # ES §15.7.14 step 33: after every element's KEY is evaluated (all DEFINE_* done),
        # run the deferred static elements (static field initializers + static blocks + the
        # static private brand) in source order with this=class. Class stays on TOS.
        self._op(Opcode.RUN_STATIC_ELEMENTS);
        # Pop the inner class-name binding scope before the OUTER-binding store below,
        # so that store resolves to the outer (mutable) binding, not the inner const.
        if cd_name_scope {
            self._pop_scope();
        }
        if nd.id is not None {
            name: str = nd.id.name;
            if pre_is_local {
                if pre_slot >= 0 {
                    self._emit(make_instruction(Opcode.STORE_LOCAL, pre_slot, 0, 0));
                } else {
                    self._emit(
                        make_instruction(Opcode.STORE_GLOBAL, self._intern(name), 0, 0)
                    );
                }
            } else {
                # top-level: store globally so LOAD_GLOBAL can find it
                self._emit_store_global_decl(name);
            }
        } else {
            self._op(Opcode.POP);
        }
        self._leave_priv_scope();
        self.in_class_body = self.in_class_body - 1;
    }

    # ── if ─────────────────────────────────────────────────────────────────

    """Compile a Statement that may be a bare (unbraced) FunctionDeclaration in
    an Annex B if/switch clause.  Wrap it in a synthetic block scope so the
    declaration gets a mutable block-scoped binding (plus the outer var mirror
    via compile_function_decl's Annex B path)."""
    def _compile_annexb_stmt(stmt: ASTNode) {
        if stmt.ntype == ASTNodeType.FunctionDeclaration
            and (not self._fn().is_strict) {
            self._push_scope(False);
            self.compile_function_decl(stmt);
            self._pop_scope();
        } else {
            self.compile_stmt(stmt);
        }
    }

    def compile_if(nd: ASTNode) -> None {
        if nd.cond_expr is None {
            self._syntax_error("SyntaxError: if statement missing test expression");
            return;
        }
        self.compile_expr(nd.cond_expr);
        jf: int = self._jump(Opcode.JUMP_IF_FALSE);
        if nd.consequent is not None {
            self._compile_annexb_stmt(nd.consequent);
        }
        if nd.alternate is not None {
            je: int = self._jump(Opcode.JUMP);
            self._patch(jf);
            self._compile_annexb_stmt(nd.alternate);
            self._patch(je);
        } else {
            self._patch(jf);
        }
    }

    # ── while ──────────────────────────────────────────────────────────────

    def compile_while(nd: ASTNode) -> None {
        if nd.cond_expr is None {
            self._syntax_error("SyntaxError: while statement missing test expression");
            return;
        }
        ctx: LoopContext = self._push_loop("");
        ctx.is_iteration = True;
        loop_start: int = self._ip();
        self.compile_expr(nd.cond_expr);
        jf: int = self._jump(Opcode.JUMP_IF_FALSE);
        if nd.body is not None {
            self.loop_body_depth = self.loop_body_depth + 1;
            self.compile_stmt(nd.body);
            self.loop_body_depth = self.loop_body_depth - 1;
        }
        self._emit(make_instruction(Opcode.JUMP, loop_start, 0, 0));
        self._patch(jf);
        self._patch_conts(ctx, loop_start);
        self._patch_label_conts(loop_start);
        self._patch_breaks(ctx);
        self._pop_loop();
    }

    # ── with ─────────────────────────────────────────────────────────────────

    """
    Compile `with (object) body` (A4).  Evaluates the object, pushes it onto the
    runtime with-scope chain (WITH_PUSH), compiles the body with `with_depth`
    incremented so bare identifier load/store route through LOAD_NAME/STORE_NAME
    (which consult the with-object before the lexical scope chain), then pops the
    with-object (WITH_POP).  The POP is emitted on both the normal exit and is
    naturally unwound on exception by the VM's frame-unwind logic.
    """
    def compile_with(nd: ASTNode) -> None {
        # `with` is a SyntaxError in strict mode (ECMAScript §13.11.1).
        if self._fn().is_strict {
            self._syntax_error(
                "SyntaxError: Strict mode code may not include a with statement"
            );
            return;
        }
        if nd.expression is None {
            self._syntax_error("SyntaxError: with statement missing object expression");
            return;
        }
        # A `let`/`const`/`class`/lexically-scoped declaration may not be the
        # direct (unbraced) body of a `with` (ECMAScript §13.11.1 — the body is a
        # Statement, not a Declaration).
        if nd.body is not None {
            wb: ASTNodeType = nd.body.ntype;
            if wb == ASTNodeType.ClassDeclaration {
                self._syntax_error(
                    "SyntaxError: Lexical declaration cannot appear in a single-statement context"
                );
                return;
            }
            if wb == ASTNodeType.VariableDeclaration
                and (nd.body.value == "let" or nd.body.value == "const") {
                self._syntax_error(
                    "SyntaxError: Lexical declaration cannot appear in a single-statement context"
                );
                return;
            }
            if wb == ASTNodeType.FunctionDeclaration {
                self._syntax_error(
                    "SyntaxError: Function declaration cannot appear in a single-statement context"
                );
                return;
            }
        }
        self.compile_expr(nd.expression);
        self._op(Opcode.WITH_PUSH);
        self.with_depth = self.with_depth + 1;
        if nd.body is not None {
            self.compile_stmt(nd.body);
        }
        self.with_depth = self.with_depth - 1;
        self._op(Opcode.WITH_POP);
    }

    # ── do-while ───────────────────────────────────────────────────────────

    def compile_do_while(nd: ASTNode) -> None {
        if nd.cond_expr is None {
            self._syntax_error(
                "SyntaxError: do-while statement missing test expression"
            );
            return;
        }
        ctx: LoopContext = self._push_loop("");
        ctx.is_iteration = True;
        loop_start: int = self._ip();
        if nd.body is not None {
            self.loop_body_depth = self.loop_body_depth + 1;
            self.compile_stmt(nd.body);
            self.loop_body_depth = self.loop_body_depth - 1;
        }
        cont_target: int = self._ip();
        self._patch_conts(ctx, cont_target);
        self._patch_label_conts(cont_target);
        self.compile_expr(nd.cond_expr);
        self._emit(make_instruction(Opcode.JUMP_IF_TRUE, loop_start, 0, 0));
        self._patch_breaks(ctx);
        self._pop_loop();
    }

    # ── for ────────────────────────────────────────────────────────────────

    def _compile_for_update(
        nd: ASTNode,
        ctx: LoopContext,
        let_outer_slot: int,
        let_iter_slot: int,
        let_loop_name: str
    ) {
        cont_target: int = self._ip();
        self._patch_conts(ctx, cont_target);
        self._patch_label_conts(cont_target);
        if nd.update is not None {
            update_start: int = self._ip();
            if nd.update.ntype == ASTNodeType.AssignmentExpression
                and nd.update.left is not None
                and nd.update.left.ntype == ASTNodeType.Identifier {
                self.compile_assign_stmt(nd.update);
            } else {
                self.compile_expr(nd.update);
                self._op(Opcode.POP);
            }
            # Per-iteration let/const: rewrite any STORE_LOCAL/STORE_DEREF targeting
            # let_iter_slot in the update expression → STORE_LOCAL let_outer_slot.
            # This routes the incremented value into the carry slot directly, so the
            # iteration cell already captured by closures is never mutated.
            if let_iter_slot >= 0 {
                fn: CompiledFunction = self._fn();
                upd_i: int = update_start;
                while upd_i < len(fn.code) {
                    upd_ins: Instruction = fn.code[upd_i];
                    if (
                        upd_ins.opcode == Opcode.STORE_LOCAL
                        or upd_ins.opcode == Opcode.STORE_DEREF
                    )
                        and upd_ins.arg == let_iter_slot {
                        fn.code[upd_i] = make_instruction(
                            Opcode.STORE_LOCAL,
                            let_outer_slot,
                            upd_ins.arg2,
                            upd_ins.line
                        );
                    }
                    upd_i = upd_i + 1;
                }
            }
        } elif let_iter_slot >= 0 {
            # No `update` clause (e.g. `for (let x = 0; x < N;) { x++; }`): the body
            # mutates the per-iteration binding (let_iter_slot) directly.  When a
            # closure in scope forces the cell machinery to survive (STORE_NEW_CELL
            # is kept, not eliminated by _pop_fn), the next iteration re-seeds the
            # fresh cell from let_outer_slot — which was never updated, so the loop
            # test never advances and spins forever.  Carry the current iteration
            # value back into let_outer_slot here so the seed sees the mutation.
            # (_pop_fn strips this copy together with STORE_NEW_CELL when there is no
            # capturing closure, so the no-closure fast path is unaffected.)
            self._emit(make_instruction(Opcode.LOAD_LOCAL, let_iter_slot, 0, 0));
            self._emit(make_instruction(Opcode.STORE_LOCAL, let_outer_slot, 0, 0));
        }
    }

    def compile_for(nd: ASTNode) {
        let_outer_slot: int = -1;
        let_iter_slot: int = -1;
        let_loop_name: str = "";
        has_let_iter: bool = False;

        self._push_scope(False);
        ctx: LoopContext = self._push_loop("");
        ctx.is_iteration = True;

        # A for-head `let`/`const` is a fresh binding scoped to the loop, but it shares
        # the fn_base `hoist_predeclared` key with a statement-level pre-declaration of
        # the same name (pd_i top-level pass / block pre-scan). Left in place, the head's
        # compile_var_decl would CONSUME that entry and bind the outer slot — the loop
        # then aliases the sibling's binding, and the sibling `let` later reports a false
        # "Identifier has already been declared". Stash such entries around the init
        # compile so the head declares fresh in the loop scope; entries the init itself
        # creates (pattern TDZ predeclare→bind pairs) are untouched — they are created
        # after this point and consumed before the restore.
        fh_stashed: list[str] = [];
        if nd.init is not None and nd.init.ntype == ASTNodeType.VariableDeclaration {
            fh_kind: str = nd.init.value;
            if fh_kind == "let" or fh_kind == "const" {
                for fh_decl in nd.init.declarations {
                    if fh_decl.id is None {
                        continue;
                    }
                    fh_names: list[str] = [];
                    if fh_decl.id.ntype == ASTNodeType.Identifier {
                        fh_names.append(fh_decl.id.name);
                    } elif fh_decl.id.ntype == ASTNodeType.ObjectPattern
                        or fh_decl.id.ntype == ASTNodeType.ArrayPattern {
                        self._collect_pattern_names(fh_decl.id, fh_names);
                    }
                    for fh_name in fh_names {
                        fh_key: str = self._hoist_predecl_key(fh_name);
                        if fh_key in self.hoist_predeclared {
                            fh_stashed.append(fh_key);
                            del self.hoist_predeclared[fh_key];
                        }
                    }
                }
            }
        }

        if nd.init is not None and nd.init.ntype == ASTNodeType.VariableDeclaration {
            init_kind: str = nd.init.value;
            if init_kind == "let" or init_kind == "const" {
                if len(nd.init.declarations) > 0 {
                    decl0: ASTNode = nd.init.declarations[0];
                    if decl0.id is not None
                        and decl0.id.ntype == ASTNodeType.Identifier {
                        let_loop_name = decl0.id.name;
                        self.compile_var_decl(nd.init);
                        let_outer_slot = self._resolve(decl0.id.name);
                        # Declare the per-iteration shadow slot as "let" in the current
                        # block scope (NOT as "var") so it gets the slot AFTER let_outer_slot
                        # and doesn't collide with it.  "var" hoists to the function base
                        # where slot_count hasn't seen the block's slots yet, causing collision.
                        let_iter_slot = self._declare("__iter_" + decl0.id.name, "let");
                        if let_iter_slot >= 0 {
                            has_let_iter = True;
                            self._push_scope(False);
                            isi: int = len(self.scope_stack) - 1;
                            self.scope_stack[isi].vars[decl0.id.name] = let_iter_slot;
                            self.scope_stack[isi].var_kinds[decl0.id.name] = init_kind;
                        }
                    }
                }
            }
        }
        if not has_let_iter and nd.init is not None {
            if nd.init.ntype == ASTNodeType.VariableDeclaration {
                self.compile_var_decl(nd.init);
            } else {
                self.compile_expr(nd.init);
                self._op(Opcode.POP);
            }
        }
        # Restore stashed outer pre-declarations so the sibling statement-level
        # declaration still finds (and consumes) its own entry.
        for fh_rk in fh_stashed {
            self.hoist_predeclared[fh_rk] = True;
        }

        loop_start: int = self._ip();
        if has_let_iter {
            self._emit(make_instruction(Opcode.LOAD_LOCAL, let_outer_slot, 0, 0));
            # arg2 encodes (outer_slot + 1) so _pop_fn can eliminate this pair when
            # no closure captures the iteration variable (0 means "not a for-loop copy").
            self._emit(
                make_instruction(
                    Opcode.STORE_NEW_CELL, let_iter_slot, let_outer_slot + 1, 0
                )
            );
        }
        if nd.cond_expr is not None {
            self.compile_expr(nd.cond_expr);
            jf: int = self._jump(Opcode.JUMP_IF_FALSE);
            if nd.body is not None {
                self.loop_body_depth = self.loop_body_depth + 1;
                self.compile_stmt(nd.body);
                self.loop_body_depth = self.loop_body_depth - 1;
            }
            self._compile_for_update(
                nd, ctx, let_outer_slot, let_iter_slot, let_loop_name
            );
            self._emit(make_instruction(Opcode.JUMP, loop_start, 0, 0));
            self._patch(jf);
        } else {
            if nd.body is not None {
                self.loop_body_depth = self.loop_body_depth + 1;
                self.compile_stmt(nd.body);
                self.loop_body_depth = self.loop_body_depth - 1;
            }
            self._compile_for_update(
                nd, ctx, let_outer_slot, let_iter_slot, let_loop_name
            );
            self._emit(make_instruction(Opcode.JUMP, loop_start, 0, 0));
        }
        self._patch_breaks(ctx);
        self._pop_loop();
        if has_let_iter {
            self._pop_scope();
        }
        self._pop_scope();
    }

    # ── for-in ─────────────────────────────────────────────────────────────

    def compile_for_in(nd: ASTNode) -> None {
        if nd.right is None or nd.left is None {
            self._syntax_error("SyntaxError: for-in statement missing left or right");
            return;
        }
        self._push_scope(False);
        ctx: LoopContext = self._push_loop("");
        ctx.is_iteration = True;
        fi_predecl: bool = False;
        fi_cell_slot: int = -1;
        if nd.left.ntype == ASTNodeType.VariableDeclaration {
            fi_kind: str = nd.left.value;
            if fi_kind == "let" or fi_kind == "const" {
                if len(nd.left.declarations) > 0 {
                    fi_decl: ASTNode = nd.left.declarations[0];
                    if fi_decl.id is not None
                        and fi_decl.id.ntype == ASTNodeType.Identifier {
                        fi_slot: int = self._declare(fi_decl.id.name, fi_kind);
                        if fi_slot >= 0 {
                            self._emit_tdz_store(fi_slot);
                        }
                        fi_predecl = True;
                        fi_cell_slot = fi_slot;
                    } elif fi_decl.id is not None
                        and (
                            fi_decl.id.ntype == ASTNodeType.ArrayPattern
                            or fi_decl.id.ntype == ASTNodeType.ObjectPattern
                        ) {
                        # ES §14.7.5.6: a destructured ForDeclaration (`for (let [x] in …)`)
                        # instantiates its lexical bindings (in TDZ) into a new environment
                        # BEFORE the iterable expression is evaluated — so a closure in the
                        # iterable that reads a head name observes the TDZ binding
                        # (ReferenceError), not any outer binding (scope-head-lex-close).
                        self._predeclare_pattern_tdz(fi_decl.id, fi_kind);
                        fi_predecl = True;
                    }
                }
            }
        }
        self.compile_expr(nd.right);
        # arg=1 flags key-iteration mode (for...in) vs arg=0 value-iteration (for...of)
        self._emit(make_instruction(Opcode.GET_ITER, 1, 0, 0));
        loop_start: int = self._ip();
        self._emit(make_instruction(Opcode.ITER_NEXT, 0, 0, 0));  # pushes value + done flag
        jf: int = self._jump(Opcode.JUMP_IF_FALSE);
        self._store_for_var(nd.left, fi_predecl);
        fi_store_addr: int = self._ip() - 1;
        if nd.body is not None {
            self.loop_body_depth = self.loop_body_depth + 1;
            self.compile_stmt(nd.body);
            self.loop_body_depth = self.loop_body_depth - 1;
        }
        if fi_cell_slot >= 0 and len(self.cell_slots) > 0 {
            fi_cells: list[int] = self.cell_slots[len(self.cell_slots) - 1];
            if fi_cell_slot in fi_cells and fi_store_addr >= 0 {
                fi_fn: CompiledFunction = self._fn();
                fi_old: Instruction = fi_fn.code[fi_store_addr];
                if fi_old.opcode == Opcode.STORE_LOCAL and fi_old.arg == fi_cell_slot {
                    fi_fn.code[fi_store_addr] = make_instruction(
                        Opcode.STORE_NEW_CELL, fi_cell_slot, 0, fi_old.line
                    );
                }
            }
        }
        self._emit(make_instruction(Opcode.JUMP, loop_start, 0, 0));
        self._patch(jf);
        self._op(Opcode.POP);  # pop iterator
        self._patch_conts(ctx, loop_start);
        self._patch_label_conts(loop_start);
        self._patch_breaks(ctx);
        self._pop_loop();
        self._pop_scope();
    }

    # ── for-of ─────────────────────────────────────────────────────────────

    def compile_for_of(nd: ASTNode) -> None {
        if nd.right is None or nd.left is None {
            self._syntax_error("SyntaxError: for-of statement missing left or right");
            return;
        }
        self._push_scope(False);
        ctx: LoopContext = self._push_loop("");
        ctx.is_iteration = True;
        ctx.is_for_of = True;
        for_of_predecl: bool = False;
        fo_use_new_cell: bool = False;
        fo_cell_slot: int = -1;
        # A10: `for (using x of …)` / `for await (await using x of …)` — the loop
        # variable is a disposable; each iteration disposes it (ES Explicit Resource
        # Management). Declared like `const`, plus per-iteration USING_DECLARE +
        # DISPOSE_MARK/DISPOSE_RUN bracketing.
        fo_is_using: bool = False;
        fo_is_async_using: bool = False;
        if nd.left.ntype == ASTNodeType.VariableDeclaration {
            fo_kind: str = nd.left.value;
            if fo_kind == "using" or fo_kind == "await using" {
                fo_is_using = True;
                if fo_kind == "await using" {
                    fo_is_async_using = True;
                }
                fo_kind = "const";  # binding semantics: const-like, block-scoped
            }
            if fo_kind == "let" or fo_kind == "const" {
                if len(nd.left.declarations) > 0 {
                    fo_decl: ASTNode = nd.left.declarations[0];
                    if fo_decl.id is not None
                        and fo_decl.id.ntype == ASTNodeType.Identifier {
                        fo_slot: int = self._declare(fo_decl.id.name, fo_kind);
                        if fo_slot >= 0 {
                            self._emit_tdz_store(fo_slot);
                        }
                        for_of_predecl = True;
                        fo_cell_slot = fo_slot;
                    } elif fo_decl.id is not None
                        and (
                            fo_decl.id.ntype == ASTNodeType.ArrayPattern
                            or fo_decl.id.ntype == ASTNodeType.ObjectPattern
                        ) {
                        # ES §14.7.5.6: destructured ForDeclaration — instantiate the head
                        # lexicals (in TDZ) BEFORE the iterable is evaluated, so a closure
                        # in the iterable reading a head name throws (scope-body-lex-open).
                        self._predeclare_pattern_tdz(fo_decl.id, fo_kind);
                        for_of_predecl = True;
                    }
                }
            }
        }
        self.compile_expr(nd.right);
        if nd.is_async {
            self._op(Opcode.GET_ASYNC_ITER);
            loop_start: int = self._ip();
            self._emit(make_instruction(Opcode.ASYNC_ITER_NEXT, 0, 0, 0));
        } else {
            self._op(Opcode.GET_ITER);
            loop_start: int = self._ip();
            self._emit(make_instruction(Opcode.ITER_NEXT, 0, 0, 0));
        }
        jf: int = self._jump(Opcode.JUMP_IF_FALSE);
        # A10 `using` loop var: open a fresh disposable scope for this iteration.
        # DISPOSE_MARK pushes a depth marker onto the operand stack, so it must be
        # emitted while the iteration value is NOT the only thing on the stack —
        # register the value (still on top) BEFORE marking. Order: DUP value →
        # USING_DECLARE (registers + pops dup) won't work because the marker must
        # record the depth *before* registration. So: store the loop var first, then
        # mark, then re-load it and register.
        self._store_for_var(nd.left, for_of_predecl, fo_use_new_cell, fo_cell_slot);
        fo_store_addr: int = self._ip() - 1;
        if fo_is_using {
            self._op(Opcode.DISPOSE_MARK);
            fo_au01: int = 0;
            if fo_is_async_using {
                fo_au01 = 1;
            }
            if fo_cell_slot >= 0 {
                self._emit(make_instruction(Opcode.LOAD_LOCAL, fo_cell_slot, 0, 0));
            } else {
                self._op(Opcode.LOAD_UNDEFINED);
            }
            self._emit(make_instruction(Opcode.USING_DECLARE, fo_au01, 0, nd.loc.line));
        }
        fo_catch_jmp: int = self._jump(Opcode.PUSH_CATCH);
        if nd.body is not None {
            self.loop_body_depth = self.loop_body_depth + 1;
            self.compile_stmt(nd.body);
            self.loop_body_depth = self.loop_body_depth - 1;
        }
        # Dispose this iteration's resource(s) on normal completion (the catch path
        # below disposes on abrupt completion via the iterator-close THROW handler).
        if fo_is_using {
            self._op(Opcode.DISPOSE_RUN);
        }
        if fo_cell_slot >= 0 and len(self.cell_slots) > 0 {
            fo_cells: list[int] = self.cell_slots[len(self.cell_slots) - 1];
            if fo_cell_slot in fo_cells and fo_store_addr >= 0 {
                fo_fn: CompiledFunction = self._fn();
                fo_old: Instruction = fo_fn.code[fo_store_addr];
                if fo_old.opcode == Opcode.STORE_LOCAL and fo_old.arg == fo_cell_slot {
                    fo_fn.code[fo_store_addr] = make_instruction(
                        Opcode.STORE_NEW_CELL, fo_cell_slot, 0, fo_old.line
                    );
                }
            }
        }
        self._op(Opcode.POP_CATCH);
        self._emit(make_instruction(Opcode.JUMP, loop_start, 0, 0));
        self._patch(jf);
        self._op(Opcode.POP);
        skip_close_jmp: int = self._jump(Opcode.JUMP);
        close_ip: int = self._ip();
        ctx.for_of_close_ip = close_ip;
        self._op(Opcode.POP_CATCH);
        self._op(Opcode.ITER_CLOSE);
        exit_close_jmp: int = self._jump(Opcode.JUMP);
        self._patch(fo_catch_jmp);
        self._op(Opcode.SWAP);
        # ABRUPT completion (exception in the body): IteratorClose (arg=1) SWALLOWS any error
        # from return(); the following THROW re-raises the original exception (§7.4.11).
        self._emit(make_instruction(Opcode.ITER_CLOSE, 1, 0, 0));
        self._op(Opcode.THROW);
        after_ip: int = self._ip();
        self._patch(skip_close_jmp);
        self._patch(exit_close_jmp);
        self._patch_conts(ctx, loop_start);
        self._patch_label_conts(loop_start);
        self._patch_breaks(ctx);
        self._pop_loop();
        self._pop_scope();
    }

    def _store_for_var(
        lhs: ASTNode,
        already_declared: bool,
        use_new_cell: bool = False,
        cell_slot: int = -1
    ) -> None {
        if lhs.ntype == ASTNodeType.VariableDeclaration {
            if len(lhs.declarations) > 0 {
                decl: ASTNode = lhs.declarations[0];
                if decl.id is None {
                    self._op(Opcode.POP);
                    self._syntax_error("SyntaxError: for-loop binding missing pattern");
                    return;
                }
                iter_kind: str = lhs.value;
                iter_cell: bool = iter_kind == "let" or iter_kind == "const";
                if decl.id.ntype == ASTNodeType.Identifier {
                    slot: int = -1;
                    if already_declared {
                        slot = self._resolve(decl.id.name);
                    } else {
                        slot = self._declare(decl.id.name, lhs.value);
                    }
                    if slot >= 0 {
                        if use_new_cell and cell_slot >= 0 and slot == cell_slot {
                            self._emit(
                                make_instruction(Opcode.STORE_NEW_CELL, slot, 0, 0)
                            );
                        } else {
                            self._emit(
                                make_instruction(Opcode.STORE_LOCAL, slot, 0, 0)
                            );
                        }
                    } else {
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL, self._intern(decl.id.name), 0, 0
                            )
                        );
                    }
                } elif decl.id.ntype == ASTNodeType.ArrayPattern {
                    # If the head pattern was TDZ-predeclared before the iterable
                    # (for-in/of), reuse those bindings instead of redeclaring.
                    prev_reuse_ap: bool = self.reuse_predeclared_lexical;
                    if already_declared {
                        self.reuse_predeclared_lexical = True;
                    }
                    self.compile_arr_pattern(decl.id, iter_kind, iter_cell);
                    self.reuse_predeclared_lexical = prev_reuse_ap;
                } elif decl.id.ntype == ASTNodeType.ObjectPattern {
                    prev_reuse_op: bool = self.reuse_predeclared_lexical;
                    if already_declared {
                        self.reuse_predeclared_lexical = True;
                    }
                    self.compile_obj_pattern(decl.id, iter_kind, iter_cell);
                    self.reuse_predeclared_lexical = prev_reuse_op;
                } else {
                    self._op(Opcode.POP);
                }
            }
        } elif lhs.ntype == ASTNodeType.Identifier {
            if lhs.name in self.esm_import_bindings
                and not self._esm_name_is_shadowed(lhs.name) {
                # ECMAScript §10.4.6: import bindings are read-only (shadowing
                # params/locals are ordinary bindings — see _store_lvalue).
                self._emit_import_assign_error(lhs.name);
            } elif self._is_esm_live(lhs.name)
                and not self._esm_name_is_shadowed(lhs.name) {
                self._emit_esm_live_store(lhs.name);
            } else {
                slot: int = self._resolve(lhs.name);
                if slot >= 0 {
                    self._emit(make_instruction(Opcode.STORE_LOCAL, slot, 0, 0));
                } else {
                    # Not a local of THIS function: a bare-identifier for-of/for-await LHS
                    # (`for (x of …)`) that targets a CAPTURED outer binding must write it via
                    # STORE_FREE, not the global object (test262 for-await-of/head-lhs-async:
                    # `let async; …; for await (async of [7])` writes the enclosing `let`). Only
                    # fall to STORE_GLOBAL when the name is truly unresolved (a real global).
                    _sfv_free: int = self._capture(lhs.name);
                    if _sfv_free >= 0 {
                        self._emit(
                            make_instruction(Opcode.STORE_FREE, _sfv_free, 0, 0)
                        );
                    } else {
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL, self._intern(lhs.name), 0, 0
                            )
                        );
                    }
                }
                self._emit_esm_alias_stores(lhs.name);
            }
        } elif lhs.ntype == ASTNodeType.ObjectExpression
            or lhs.ntype == ASTNodeType.ArrayExpression {
            # for ([x] of …) / for ({k} of …) — LHS is a destructuring-assignment
            # target (no declaration keyword). _store_lvalue destructures a DUPed
            # copy and leaves the original on the stack, which we then POP.
            self._op(Opcode.DUP);
            self._store_lvalue(lhs);
            self._op(Opcode.POP);
        } elif lhs.ntype == ASTNodeType.MemberExpression {
            # for (obj.prop of …) / for (arr[i] of …) — assign to a member target.
            # _store_lvalue(MemberExpression) leaves the stored value on the stack.
            self._store_lvalue(lhs);
            self._op(Opcode.POP);
        } else {
            self._op(Opcode.POP);
        }
    }

    # ── break / continue ───────────────────────────────────────────────────

    def compile_break(nd: ASTNode) -> None {
        label: str = nd.name;
        if len(self.loop_stack) == 0 {
            self._syntax_error("SyntaxError: Illegal break statement");
            return;
        }
        if label == "" {
            self._emit_finalizers_for_exit(len(self.loop_stack));
            addr: int = self._jump(Opcode.JUMP);
            ctx: LoopContext = self.loop_stack[len(self.loop_stack) - 1];
            ctx.break_addrs.append(addr);
            return;
        }
        i: int = len(self.loop_stack) - 1;
        while i >= 0 {
            lc: LoopContext = self.loop_stack[i];
            if lc.label == label {
                self._emit_finalizers_for_exit(i + 1);
                self._emit_close_enclosing_for_of(i);
                addr2: int = self._jump(Opcode.JUMP);
                lc.break_addrs.append(addr2);
                return;
            }
            i = i - 1;
        }
        self._syntax_error("SyntaxError: Undefined label '" + label + "' in break");
    }

    def compile_continue(nd: ASTNode) -> None {
        label: str = nd.name;
        if label == "" {
            i: int = len(self.loop_stack) - 1;
            while i >= 0 {
                lc: LoopContext = self.loop_stack[i];
                if not lc.is_switch and (lc.label == "" or lc.is_iteration) {
                    self._emit_finalizers_for_exit(i + 1);
                    if lc.is_for_of {
                        self._op(Opcode.POP_CATCH);
                    }
                    addr: int = self._jump(Opcode.JUMP);
                    lc.cont_addrs.append(addr);
                    return;
                }
                i = i - 1;
            }
            self._syntax_error("SyntaxError: Illegal continue statement");
            return;
        }
        i = len(self.loop_stack) - 1;
        while i >= 0 {
            lc2: LoopContext = self.loop_stack[i];
            if lc2.label == label {
                if lc2.is_switch or not lc2.is_iteration {
                    self._syntax_error("SyntaxError: Illegal continue statement");
                    return;
                }
                self._emit_finalizers_for_exit(i + 1);
                self._emit_close_enclosing_for_of(i);
                addr2: int = self._jump(Opcode.JUMP);
                lc2.cont_addrs.append(addr2);
                return;
            }
            i = i - 1;
        }
        self._syntax_error("SyntaxError: Undefined label '" + label + "' in continue");
    }

    # ── try / catch / finally ─────────────────────────────────────────────

    def compile_try(nd: ASTNode) -> None {
        # Track this try's finalizer for the duration of body+catch compilation, so a
        # break/continue/return out of them re-emits it before jumping (ES §14.15.3).
        # Popped before compiling the finalizer itself.
        fin_entry: FinalizerEntry = FinalizerEntry(
            fin_node=nd, loop_depth=0, fn_base=0, live_regions=0
        );
        if nd.finalizer is not None {
            fin_ct: ASTNode = nd.finalizer;
            fin_entry = FinalizerEntry(
                fin_node=fin_ct,
                loop_depth=len(self.loop_stack),
                fn_base=len(self.fn_scope_base),
                live_regions=0
            );
            self.finalizer_stack.append(fin_entry);
        }
        # When a finalizer is present, wrap the whole try/catch in a runtime
        # exception-handler region (PUSH_FINALLY → fe_jmp). An exception escaping
        # the body (with no catch, or after the catch re-throws) unwinds to this
        # region, runs the finalizer, then re-throws — ES §14.15.3: the abrupt
        # completion of the try/catch is only replaced by the finalizer's if the
        # finalizer itself completes abruptly, otherwise the original is rethrown.
        fe_jmp: int = -1;
        if nd.finalizer is not None {
            fe_jmp = self._jump(Opcode.PUSH_FINALLY);
            fin_entry.live_regions = 1;
        }
        # The body catch region is only needed when there IS a user catch handler.
        # With a finalizer but no catch, a body exception must unwind straight to the
        # finally region (fe_jmp) — emitting a body PUSH_CATCH here would instead route
        # it to the normal-completion path and swallow it (S12.14_A12).
        catch_jmp: int = -1;
        if nd.handler is not None {
            catch_jmp = self._jump(Opcode.PUSH_CATCH);
            if nd.finalizer is not None {
                fin_entry.live_regions = 2;
            }
        }
        self._in_try_body = self._in_try_body + 1;
        if nd.body is not None {
            self.compile_stmt(nd.body);
        }
        self._in_try_body = self._in_try_body - 1;
        if nd.handler is not None {
            self._op(Opcode.POP_CATCH);
            # Body catch region gone on the normal path; only the finally region remains.
            if nd.finalizer is not None {
                fin_entry.live_regions = 1;
            }
        }
        end_jmp: int = self._jump(Opcode.JUMP);
        if catch_jmp >= 0 {
            self._patch(catch_jmp);
        }
        if nd.handler is not None {
            handler: ASTNode = nd.handler;
            self._push_scope(False);
            self.catch_param_names_stack.append(self.catch_param_names);
            self.catch_param_names = {};
            self.catch_pattern_param_names_stack.append(self.catch_pattern_param_names);
            self.catch_pattern_param_names = {};
            if handler.param is not None
                and handler.param.ntype == ASTNodeType.Identifier {
                cp_name: str = handler.param.name;
                # ES §13.15.1: in strict mode a CatchParameter may not be named `eval`
                # or `arguments` (BoundNames restriction).
                if self._fn().is_strict
                    and (cp_name == "eval" or cp_name == "arguments") {
                    self._syntax_error(
                        "SyntaxError: Unexpected eval or arguments in strict mode"
                    );
                }
                self.catch_param_names[cp_name] = True;
                # B.3.5: record simple catch params so EDI allows var/function redeclaration.
                self._fn().simple_catch_params.append(cp_name);
                slot: int = self._declare(cp_name, "let");
                if slot >= 0 {
                    self._emit(make_instruction(Opcode.STORE_LOCAL, slot, 0, 0));
                } else {
                    self._emit_store_global_decl(cp_name);
                }
            } elif handler.param is not None
                and handler.param.ntype == ASTNodeType.ArrayPattern {
                # Destructuring catch binding: `catch ([a, b]) {}` — the exception
                # value is on TOS; destructure it into the pattern (block-scoped like
                # a catch identifier, i.e. kind "let").  Record the bound names for
                # the Annex-B var-in-catch shadow rule AND as pattern names so
                # Annex B.3.3 suppresses the extension (B.3.5 early error).
                cp_arr_names: list[str] = [];
                self._collect_pattern_names(handler.param, cp_arr_names);
                for cpn in cp_arr_names {
                    self.catch_param_names[cpn] = True;
                    self.catch_pattern_param_names[cpn] = True;
                }
                self.compile_arr_pattern(handler.param, "let");
            } elif handler.param is not None
                and handler.param.ntype == ASTNodeType.ObjectPattern {
                # `catch ({x, y}) {}` — same as above with an object pattern.
                cp_obj_names: list[str] = [];
                self._collect_pattern_names(handler.param, cp_obj_names);
                for cpn2 in cp_obj_names {
                    self.catch_param_names[cpn2] = True;
                    self.catch_pattern_param_names[cpn2] = True;
                }
                self.compile_obj_pattern(handler.param, "let");
            } else {
                self._op(Opcode.POP);
            }
            if handler.body is not None {
                self.compile_stmt(handler.body);
            }
            n_cpn: int = len(self.catch_param_names_stack);
            self.catch_param_names = self.catch_param_names_stack[n_cpn - 1];
            del self.catch_param_names_stack[n_cpn - 1];
            n_cpp: int = len(self.catch_pattern_param_names_stack);
            self.catch_pattern_param_names = self.catch_pattern_param_names_stack[
                n_cpp - 1
            ];
            del self.catch_pattern_param_names_stack[n_cpp - 1];
            self._pop_scope();
        }
        # ── Try WITHOUT finalizer: original path (body-catch region only) ──
        if nd.finalizer is None {
            self._patch(end_jmp);
            return;
        }

        # ── Try WITH finalizer ──
        # Both the normal-completion path (end_jmp) and the catch handler's normal
        # fall-through arrive here. Pop the runtime finally region, then run the
        # finalizer as a *normal* completion.
        self._patch(end_jmp);
        # Body+catch compiled: this finalizer no longer applies to inner abrupt exits.
        del self.finalizer_stack[len(self.finalizer_stack) - 1];
        self._op(Opcode.POP_FINALLY);
        # The *normal* completion value of a `finally` block is discarded
        # (ES §14.15.3 UpdateEmpty is applied to the try/catch value, not the
        # finally value).  Suppress completion-value writes while compiling the
        # finalizer so `try{2}finally{3}` yields 2, not 3.
        cv_saved: int = self.cv_slot;
        self.cv_slot = -1;
        self.compile_stmt(nd.finalizer);
        self.cv_slot = cv_saved;
        end_normal_jmp: int = self._jump(Opcode.JUMP);

        # Exception path: an exception escaping the body (no catch, or thrown by the
        # catch handler) unwinds here with the exception value on TOS (the runtime
        # already popped this finally region in _unwind_in_frame). A generator
        # forced-return (.return()) suspended in the try body ALSO lands here, but
        # with NO value on the stack (`_gen_ret_pending`). FINALLY_ENTER stashes the
        # exception (or nothing, for a forced-return) into a scratch local so the
        # finalizer — which may itself yield/await — runs with a clean operand stack;
        # stashing also matters when the finalizer completes ABRUPTLY (continue /
        # break / return): the abrupt jump abandons the exception, and a value left on
        # the operand stack would corrupt the loop/return target's stack height
        # (S12.14_A12: `try{throw}finally{continue}`). FINALLY_RETHROW then re-raises
        # the exception, or — for a forced-return — hands control back so the
        # generator completes with its return value (async-generator return-try-finally).
        self._patch(fe_jmp);
        fe_exc_slot: int = self._alloc_scratch_slot();
        self._emit(make_instruction(Opcode.FINALLY_ENTER, fe_exc_slot, 0, 0));
        cv_saved_fe: int = self.cv_slot;
        self.cv_slot = -1;
        self.compile_stmt(nd.finalizer);
        self.cv_slot = cv_saved_fe;
        self._emit(make_instruction(Opcode.FINALLY_RETHROW, fe_exc_slot, 0, 0));

        self._patch(end_normal_jmp);
    }

    """True if the current function has any enclosing try-finalizer on the stack."""
    def _has_in_fn_finalizer -> bool {
        n: int = len(self.finalizer_stack);
        if n == 0 {
            return False;
        }
        return self.finalizer_stack[n - 1].fn_base == len(self.fn_scope_base);
    }

    """Re-emit the `finally` blocks an abrupt exit jumps out of, innermost first
    (ES §14.15.3). `min_loop_depth` = loop_stack length at the target loop; a
    finalizer entered while loop_stack was at least that deep lies inside the
    jumped-over region and runs. For `return`, pass 0 (all finalizers in the current
    function run). Finalizers of an enclosing function (different fn_base) never run.
    A finalizer is stack-neutral, so a pending return value on TOS survives it.
    Completion-value writes are suppressed (a finally's normal value is discarded)."""
    def _emit_finalizers_for_exit(min_loop_depth: int) {
        cur_fn_base: int = len(self.fn_scope_base);
        # Snapshot the stack; we re-emit from a copy while temporarily truncating the
        # live stack so an abrupt statement INSIDE a re-emitted finalizer sees only the
        # finalizers OUTSIDE it (never itself — otherwise `finally{return}` recurses
        # forever: test262 S12.14_A5 CHECK#2).
        saved_stack: list[FinalizerEntry] = [];
        for se in self.finalizer_stack {
            saved_stack.append(se);
        }
        i: int = len(saved_stack) - 1;
        while i >= 0 {
            fe: FinalizerEntry = saved_stack[i];
            if fe.fn_base != cur_fn_base {
                break;
            }
            if fe.loop_depth < min_loop_depth {
                break;
            }
            # Pop this try's live runtime exception-handler regions (the finally
            # region and, if the abrupt exit is inside the try body, the body catch
            # region) before running its finalizer, so the frame's catch_stack is not
            # left with stale handlers after control leaves the construct.
            rp: int = 0;
            while rp < fe.live_regions {
                self._op(Opcode.POP_CATCH);
                rp = rp + 1;
            }
            # Expose only the finalizers strictly outside this one while compiling it.
            trunc: list[FinalizerEntry] = [];
            j: int = 0;
            while j < i {
                trunc.append(saved_stack[j]);
                j = j + 1;
            }
            self.finalizer_stack = trunc;
            cv_saved_f: int = self.cv_slot;
            self.cv_slot = -1;
            self.compile_stmt(fe.fin_node);
            self.cv_slot = cv_saved_f;
            i = i - 1;
        }
        self.finalizer_stack = saved_stack;
    }

    # ── switch ─────────────────────────────────────────────────────────────

    def compile_switch(nd: ASTNode) -> None {
        if nd.discriminant is None {
            self._syntax_error("SyntaxError: switch statement missing discriminant");
            return;
        }
        # Switch cases share one block scope; duplicate let/const without nested blocks is a SyntaxError.
        switch_lexicals: dict[str, bool] = {};
        switch_lexical_kinds: dict[str, str] = {};
        sw_ci: int = 0;
        while sw_ci < len(nd.cases) {
            sw_case: ASTNode = nd.cases[sw_ci];
            sw_si: int = 0;
            while sw_si < len(sw_case.children) {
                sw_stmt: ASTNode = sw_case.children[sw_si];
                if sw_stmt.ntype == ASTNodeType.VariableDeclaration {
                    sw_kind: str = sw_stmt.value;
                    if sw_kind == "let" or sw_kind == "const" {
                        sw_di: int = 0;
                        while sw_di < len(sw_stmt.declarations) {
                            sw_decl: ASTNode = sw_stmt.declarations[sw_di];
                            if sw_decl.id is not None
                                and sw_decl.id.ntype == ASTNodeType.Identifier {
                                sw_name: str = sw_decl.id.name;
                                if sw_name in switch_lexicals {
                                    self._syntax_error(
                                        "SyntaxError: Identifier '"
                                            + sw_name
                                            + "' has already been declared"
                                    );
                                } else {
                                    switch_lexicals[sw_name] = True;
                                    switch_lexical_kinds[sw_name] = sw_kind;
                                }
                            }
                            sw_di = sw_di + 1;
                        }
                    }
                } elif sw_stmt.ntype == ASTNodeType.FunctionDeclaration
                    and (sw_stmt.is_generator or sw_stmt.is_async) {
                    # ES §14.12.4: a generator / async / async-generator function
                    # declaration in a switch CaseBlock is ALWAYS block-scoped (unlike a
                    # plain sloppy FunctionDeclaration, it has no Annex B.3.3 var leak).
                    # Collect its name as a CaseBlock lexical so it does not leak to the
                    # enclosing scope (scope-lex-{generator,async-function,async-generator}).
                    if sw_stmt.id is not None
                        and sw_stmt.id.ntype == ASTNodeType.Identifier {
                        sw_fname: str = sw_stmt.id.name;
                        if sw_fname not in switch_lexicals {
                            switch_lexicals[sw_fname] = True;
                            switch_lexical_kinds[sw_fname] = "let";
                        }
                    }
                }
                sw_si = sw_si + 1;
            }
            sw_ci = sw_ci + 1;
        }
        ctx: LoopContext = self._push_loop("");
        ctx.is_switch = True;
        # ES §14.12.4: the switch DISCRIMINANT is evaluated in the ENCLOSING lexical
        # environment, BEFORE the CaseBlock environment is entered — so a closure in
        # the discriminant that reads a name shadowed by a case-clause `let` sees the
        # OUTER binding, not the CaseBlock one (scope-lex-open-case). Compile it now,
        # before pushing the CaseBlock scope; its value stays on the operand stack and
        # is consumed by the case-test comparisons emitted inside the scope below.
        self.compile_expr(nd.discriminant);
        # A switch CaseBlock is its own lexical environment (ES §14.12.4): case-clause
        # `let`/`const` bindings live in a scope distinct from the enclosing one, so
        # `switch(x){ case 1: let y; } let y;` is NOT a redeclaration.  Push a block
        # scope and TDZ-predeclare the case lexicals into it (they are hoisted across
        # the whole CaseBlock).  Save/restore the outer `hoist_predeclared` flags for
        # these names (keyed by name) so consuming them here doesn't misflag an
        # enclosing same-named declaration (see _compile_block for the same guard).
        self._push_scope(False);
        sw_predeclared: list[str] = [];
        sw_prior_flag: dict[str, bool] = {};
        for sw_lex_name in switch_lexicals {
            sw_lex_kind: str = "let";
            if sw_lex_name in switch_lexical_kinds {
                sw_lex_kind = switch_lexical_kinds[sw_lex_name];
            }
            sw_lex_slot: int = self._declare(sw_lex_name, sw_lex_kind);
            if sw_lex_slot >= 0 {
                self._emit_tdz_store(sw_lex_slot);
                sw_lex_key: str = self._hoist_predecl_key(sw_lex_name);
                if sw_lex_key not in sw_prior_flag {
                    sw_prior_flag[sw_lex_key] = sw_lex_key in self.hoist_predeclared;
                    sw_predeclared.append(sw_lex_key);
                }
                self.hoist_predeclared[sw_lex_key] = True;
            }
        }
        n: int = len(nd.cases);

        # body_target[i] = case index whose statement list runs when case i matches
        body_target: list[int] = [];
        bt_fill: int = 0;
        while bt_fill < n {
            body_target.append(-1);
            bt_fill = bt_fill + 1;
        }
        next_tgt: int = -1;
        bt_i: int = n - 1;
        while bt_i >= 0 {
            cas_bt: ASTNode = nd.cases[bt_i];
            if len(cas_bt.children) > 0 {
                body_target[bt_i] = bt_i;
                next_tgt = bt_i;
            } else {
                body_target[bt_i] = next_tgt;
            }
            bt_i = bt_i - 1;
        }

        default_idx: int = -1;
        d_i: int = 0;
        while d_i < n {
            if nd.cases[d_i].cond_expr is None {
                default_idx = d_i;
            }
            d_i = d_i + 1;
        }

        body_entry: list[int] = [];
        be_fill: int = 0;
        while be_fill < n {
            body_entry.append(-1);
            be_fill = be_fill + 1;
        }

        body_jump_addrs: list[int] = [];
        body_jump_targets: list[int] = [];

        # (Discriminant already compiled above, before the CaseBlock scope was entered.)

        # Phase 1: emit tests for labeled cases
        c_i: int = 0;
        while c_i < n {
            cas_t: ASTNode = nd.cases[c_i];
            if cas_t.cond_expr is not None {
                self._op(Opcode.DUP);
                self.compile_expr(cas_t.cond_expr);
                self._op(Opcode.STRICT_EQ);
                j_nomatch: int = self._jump(Opcode.JUMP_IF_FALSE);
                self._op(Opcode.POP);
                j_body: int = self._jump(Opcode.JUMP);
                body_jump_addrs.append(j_body);
                body_jump_targets.append(body_target[c_i]);
                self._patch(j_nomatch);
            }
            c_i = c_i + 1;
        }

        # No test matched: pop the discriminant, THEN jump to the default body (or
        # switch end). Order matters — the POP must precede the unconditional JUMP,
        # or it is dead code after the jump and the discriminant is never popped.
        # A leaked discriminant desyncs the operand stack: a matched `case` pops it
        # (see the case path above) but the default/no-match path did not, so the
        # switch was not stack-neutral. Inside a for-of/for-in body — whose iterator
        # lives on the operand stack across the body — the stray value sits atop the
        # iterator and the next ITER_NEXT reads the wrong slot, aborting the loop
        # after one iteration. (A classic `for` uses a local counter, so it was
        # immune, which is why this hid until a switch-with-default ran inside
        # `for (… of …)` — e.g. vite's injectEnvironmentAndFilterToHooks.)
        self._op(Opcode.POP);
        j_default: int = self._jump(Opcode.JUMP);

        default_jump_target: int = -1;
        if default_idx >= 0 {
            default_jump_target = body_target[default_idx];
        }

        # Phase 2: emit bodies in source order (fall-through between consecutive bodies)
        c_i = 0;
        while c_i < n {
            if body_target[c_i] == c_i {
                body_entry[c_i] = self._ip();
                cas_b: ASTNode = nd.cases[c_i];
                for stmt in cas_b.children {
                    # A generator/async function declaration in a case is block-scoped
                    # (its name was pre-declared as a CaseBlock `let` above): compile it
                    # under in_block_fn_decl so it binds that block slot instead of
                    # var-hoisting to the enclosing function/global scope.
                    if stmt.ntype == ASTNodeType.FunctionDeclaration
                        and (stmt.is_generator or stmt.is_async) {
                        sw_prev_bfd: bool = self.in_block_fn_decl;
                        self.in_block_fn_decl = True;
                        self.compile_stmt(stmt);
                        self.in_block_fn_decl = sw_prev_bfd;
                    } else {
                        self.compile_stmt(stmt);
                    }
                }
            }
            c_i = c_i + 1;
        }

        switch_end: int = self._ip();

        bj: int = 0;
        while bj < len(body_jump_addrs) {
            tgt2: int = body_jump_targets[bj];
            if tgt2 >= 0 and body_entry[tgt2] >= 0 {
                self._patch_to(body_jump_addrs[bj], body_entry[tgt2]);
            } else {
                self._patch_to(body_jump_addrs[bj], switch_end);
            }
            bj = bj + 1;
        }

        if default_jump_target >= 0 and body_entry[default_jump_target] >= 0 {
            self._patch_to(j_default, body_entry[default_jump_target]);
        } else {
            self._patch_to(j_default, switch_end);
        }

        self._patch_breaks(ctx);
        # Restore outer hoist_predeclared flags for the case lexicals, then pop the
        # CaseBlock scope.
        for sw_bpn in sw_predeclared {
            if sw_prior_flag[sw_bpn] {
                self.hoist_predeclared[sw_bpn] = True;
            } elif sw_bpn in self.hoist_predeclared {
                del self.hoist_predeclared[sw_bpn];
            }
        }
        self._pop_scope();
        self._pop_loop();
    }

    # ── labeled statement ──────────────────────────────────────────────────

    def _is_iteration_stmt(stmt: ASTNode) -> bool {
        if stmt is None {
            return False;
        }
        st: ASTNodeType = stmt.ntype;
        return st == ASTNodeType.ForStatement
            or st == ASTNodeType.WhileStatement
            or st == ASTNodeType.DoWhileStatement
            or st == ASTNodeType.ForInStatement
            or st == ASTNodeType.ForOfStatement;
    }

    def compile_labeled(nd: ASTNode) -> None {
        if nd.body is None {
            self._syntax_error("SyntaxError: labeled statement missing body");
            return;
        }
        li: int = len(self.loop_stack) - 1;
        while li >= 0 {
            if self.loop_stack[li].label == nd.name {
                self._syntax_error(
                    "SyntaxError: Label '" + nd.name + "' has already been declared"
                );
                return;
            }
            li = li - 1;
        }
        ctx: LoopContext = self._push_loop(nd.name);
        if self._is_iteration_stmt(nd.body) {
            ctx.is_iteration = True;
        }
        self.compile_stmt(nd.body);
        self._patch_breaks(ctx);
        self._pop_loop();
    }

    # ══════════════════════════════════════════════════════════════════════
    # Expressions
    # ══════════════════════════════════════════════════════════════════════

    def compile_expr(nd: ASTNode) {
        if nd.ntype == ASTNodeType.Literal {
            self.compile_literal(nd);
        } elif nd.ntype == ASTNodeType.Identifier {
            self.compile_identifier(nd);
        } elif nd.ntype == ASTNodeType.BinaryExpression {
            self.compile_binary(nd);
        } elif nd.ntype == ASTNodeType.UnaryExpression {
            self.compile_unary(nd);
        } elif nd.ntype == ASTNodeType.LogicalExpression {
            self.compile_logical(nd);
        } elif nd.ntype == ASTNodeType.ConditionalExpression {
            self.compile_conditional(nd);
        } elif nd.ntype == ASTNodeType.AssignmentExpression {
            self.compile_assign(nd);
        } elif nd.ntype == ASTNodeType.UpdateExpression {
            self.compile_update(nd);
        } elif nd.ntype == ASTNodeType.CallExpression {
            self.compile_call(nd);
        } elif nd.ntype == ASTNodeType.NewExpression {
            self.compile_new(nd);
        } elif nd.ntype == ASTNodeType.MemberExpression {
            self.compile_member(nd);
        } elif nd.ntype == ASTNodeType.OptionalChainExpr {
            self.compile_optional_chain(nd);
        } elif nd.ntype == ASTNodeType.ArrayExpression {
            self.compile_array(nd);
        } elif nd.ntype == ASTNodeType.ObjectExpression {
            self.compile_object(nd);
        } elif nd.ntype == ASTNodeType.TemplateLiteral {
            self.compile_template(nd);
        } elif nd.ntype == ASTNodeType.SequenceExpression {
            self.compile_sequence(nd);
        } elif nd.ntype == ASTNodeType.ArrowFunctionExpr {
            self.compile_arrow(nd);
        } elif nd.ntype == ASTNodeType.FunctionExpression {
            self.compile_fn_expr(nd);
        } elif nd.ntype == ASTNodeType.ClassExpression {
            self.compile_class_expr(nd);
        } elif nd.ntype == ASTNodeType.AwaitExpression {
            if nd.argument is not None {
                self.compile_expr(nd.argument);
            } else {
                self._op(Opcode.LOAD_UNDEFINED);
            }
            # arg=1 marks a MODULE TOP-LEVEL await (directly in the module body, not a
            # nested function). The VM keeps its plain-value awaits synchronous — TLA drives
            # the module-graph evaluation whose ordering depends on that (module-code/
            # top-level-await/module-import-unwrapped), unlike a script async function where
            # `await <plain value>` must suspend one microtask for correct interleaving.
            aw_tla: int = 1
                if (self.compiling_module and len(self.fn_scope_base) == 1)
                else 0;
            self._emit(make_instruction(Opcode.AWAIT, aw_tla, 0, nd.loc.line));
        } elif nd.ntype == ASTNodeType.YieldExpression {
            if nd.argument is not None {
                self.compile_expr(nd.argument);
            } else {
                self._op(Opcode.LOAD_UNDEFINED);
            }
            if nd.prefix {
                self._op(Opcode.YIELD_STAR);
            } else {
                # AsyncGeneratorYield (ES §27.6.3.8 step 3): a plain `yield x` in an ASYNC
                # generator awaits the operand BEFORE yielding, so a yielded thenable or
                # promise is assimilated — the consumer sees its resolved value (and a
                # rejection surfaces as a throw at the yield site). Sync generators yield
                # the operand as-is; `yield*` (YIELD_STAR) runs its own await protocol.
                # arg2=1 marks this as a YIELD-OPERAND await so the VM drives it inline.
                if self._fn().is_async and self._fn().is_generator {
                    self._emit(make_instruction(Opcode.AWAIT, 0, 1, nd.loc.line));
                }
                self._op(Opcode.YIELD);
            }
        } elif nd.ntype == ASTNodeType.SpreadElement {
            if nd.argument is not None {
                self.compile_expr(nd.argument);
            }
            self._op(Opcode.SPREAD);
        } elif nd.ntype == ASTNodeType.MetaProperty {
            # `import.meta` → push frozen {url, env, resolve} object
            # `new.target` → the current frame's [[NewTarget]] (ES §13.3.12).
            if nd.name == "import.meta" {
                # ES §13.3.12.1: `import.meta` is a SyntaxError unless the syntactic goal is
                # Module. `Function("import.meta")` / `Function("a=import.meta","")` compile
                # under the FunctionBody/FormalParameters goal, and direct eval inherits the
                # (Script) caller's goal — neither is Module (test262 import.meta/syntax/* and
                # not-accessible-from-direct-eval).
                if not self.compiling_module {
                    self._syntax_error(
                        "SyntaxError: Cannot use 'import.meta' outside a module"
                    );
                } else {
                    self._op(Opcode.IMPORT_META);
                }
            } elif nd.name == "new.target" {
                self._op(Opcode.LOAD_NEW_TARGET);
            } else {
                self._op(Opcode.LOAD_NEW_TARGET);
            }
        } elif nd.ntype == ASTNodeType.TaggedTemplateExpr {
            if nd.tag is not None {
                self.compile_expr(nd.tag);
            }
            if nd.quasi is not None {
                # Tagged template: call tag(strings, expr1, expr2, ...)
                # where strings is an Array of cooked quasi strings with a
                # .raw property containing the unprocessed (raw) quasi strings.
                nq_tt: int = len(nd.quasi.quasis);
                ne_tt: int = len(nd.quasi.expressions);
                # Push cooked quasis onto stack, then build Array
                qi_tt: int = 0;
                while qi_tt < nq_tt {
                    self._const("s:" + _unescape_string(nd.quasi.quasis[qi_tt]));
                    qi_tt = qi_tt + 1;
                }
                self._emit(make_instruction(Opcode.NEW_ARRAY, nq_tt, 0, 0));
                # Attach .raw = Array of raw (unescaped) quasis
                self._op(Opcode.DUP);
                qi_tt = 0;
                while qi_tt < nq_tt {
                    self._const("s:" + nd.quasi.quasis[qi_tt]);
                    qi_tt = qi_tt + 1;
                }
                self._emit(make_instruction(Opcode.NEW_ARRAY, nq_tt, 0, 0));
                raw_key: int = self._intern("raw");
                self._emit(make_instruction(Opcode.SET_PROP, raw_key, 0, 0));
                self._op(Opcode.POP);  # discard returned raw_array from SET_PROP
                # ES §13.2.8.4 GetTemplateObject: freeze + cache the cooked-strings
                # object per source site so every evaluation of THIS tagged template
                # yields the SAME (frozen) object.  TEMPLATE_OBJECT replaces the fresh
                # array on the stack with the cached one on a cache hit.
                # Globally-unique site id (across all compilations) so that two
                # separate `eval`/`new Function` compilations of identical source get
                # DIFFERENT ids — a loop within one compilation keeps its single id.
                tt_site: int = _TEMPLATE_SITE_BASE;
                _TEMPLATE_SITE_BASE = _TEMPLATE_SITE_BASE + 1;
                self._emit(make_instruction(Opcode.TEMPLATE_OBJECT, tt_site, 0, 0));
                # Push each interpolated expression
                ei_tt: int = 0;
                while ei_tt < ne_tt {
                    self.compile_expr(nd.quasi.expressions[ei_tt]);
                    ei_tt = ei_tt + 1;
                }
                self._emit(make_instruction(Opcode.CALL, 1 + ne_tt, 0, 0));
            } else {
                self._emit(make_instruction(Opcode.CALL, 0, 0, 0));
            }
        } else {
            self._op(Opcode.LOAD_UNDEFINED);
        }
    }

    # ── literal ────────────────────────────────────────────────────────────

    def compile_literal(nd: ASTNode) {
        val: str = nd.value;
        # Check kind FIRST so that string literals like 'true', 'false', 'null'
        # are compiled as strings rather than boolean/null primitives.
        if nd.kind == "string" {
            self._const("s:" + _unescape_string(val));
        } elif nd.kind == "number" {
            self._const("n:" + _strip_numeric_separators(val));
        } elif nd.kind == "bigint" {
            self._const("b:" + _strip_numeric_separators(val));
        } elif nd.kind == "regexp" {
            # val is "/pattern/flags" — store as "r:pattern|flags"
            # Find the last '/' to split pattern from flags
            last_slash: int = len(val) - 1;
            while last_slash > 0 and val[last_slash] != "/" {
                last_slash = last_slash - 1;
            }
            re_pat: str = str_substr(val, 1, last_slash);
            re_flg: str = str_substr(val, last_slash + 1, len(val));
            # Store the raw "/pattern/flags" literal as-is — the VM decodes
            # by finding the last "/" (same logic as above). Avoids any
            # function-call-in-string-concat codegen issue.
            fn2: CompiledFunction = self._fn();
            idx2: int = fn2.constants.add(val);
            fn2.code.append(make_instruction(Opcode.MAKE_REGEXP, idx2, 0, 0));
        } elif val == "true" {
            self._op(Opcode.LOAD_TRUE);
        } elif val == "false" {
            self._op(Opcode.LOAD_FALSE);
        } elif val == "null" {
            self._op(Opcode.LOAD_NULL);
        } elif val == "undefined" {
            self._op(Opcode.LOAD_UNDEFINED);
        } else {
            self._const(val);
        }  # backward-compat fallback
    }

    # ── identifier ─────────────────────────────────────────────────────────

    def compile_identifier(nd: ASTNode) {
        name: str = nd.name;
        if name == "undefined" {
            self._op(Opcode.LOAD_UNDEFINED);
        } elif name == "null" {
            self._op(Opcode.LOAD_NULL);
        } elif name == "true" {
            self._op(Opcode.LOAD_TRUE);
        } elif name == "false" {
            self._op(Opcode.LOAD_FALSE);
        } elif name == "this" {
            self._emit(make_instruction(Opcode.LOAD_THIS, 0, 0, 0));
        } else {  # `this` binding
            # Import/live-export bindings are name-keyed and scope-blind; a
            # same-named function param/local (or captured outer local) shadows
            # them (ES §8.2.1 — module env is outermost). Without this check,
            # `new Promise((resolve, reject) => resolve(v))` under
            # `import { resolve } from 'path'` called path.resolve.
            if name in self.esm_import_bindings
                and not self._esm_name_is_shadowed(name) {
                self._emit_esm_import_load(name);
            } elif self._is_esm_live(name) and not self._esm_name_is_shadowed(name) {
                self._emit_esm_live_load(name);
            } elif self.with_depth > 0 {
                # Inside a `with` body, name resolution is dynamic: the with-object(s)
                # may shadow lexical/global bindings, so defer the entire lookup to
                # the VM via LOAD_NAME (with_stack → locals → free → globals). (A4)
                # Still register any enclosing-scope binding as a free var so a
                # function *nested* in the `with` can resolve it (LOAD_NAME step 3)
                # when no with-object shadows it — e.g. a global helper referenced
                # inside `with(o){ (function(){ helper() })() }`.
                _ = self._capture(name);
                self._emit(
                    make_instruction(
                        Opcode.LOAD_NAME, self._intern(name), 0, nd.loc.line
                    )
                );
            } else {
                slot: int = self._resolve(name);
                if self.in_default_params
                    and len(self.param_tdz) > 0
                    and name in self.param_tdz {
                    # ES §10.2.11: a default expression referencing a parameter that is
                    # not yet initialized (its own name, or a later param) is a TDZ
                    # access → ReferenceError (e.g. `(x = x)`, `(a = b, b)`).
                    self._emit_reference_error(
                        "Cannot access '" + name + "' before initialization"
                    );
                } elif slot >= 0 {
                    kind: str = self._get_kind(name);
                    if kind == "let" or kind == "const" {
                        self._emit(
                            make_instruction(Opcode.LOAD_LOCAL_CHECKED, slot, 0, 0)
                        );
                    } else {
                        self._emit(make_instruction(Opcode.LOAD_LOCAL, slot, 0, 0));
                    }
                } else {
                    free_slot: int = self._capture(name);
                    if free_slot >= 0 {
                        self._emit(make_instruction(Opcode.LOAD_FREE, free_slot, 0, 0));
                    } elif self.in_default_params
                        and name in self.default_param_body_vars {
                        self._emit_reference_error(name + " is not defined");
                    } elif name in self.dead_lexical_names {
                        # A let/const of this name went out of scope with its block and
                        # nothing else of that name is visible here (resolution above
                        # found no live local or captured binding — a sibling block may
                        # have re-declared it): a read is a ReferenceError, `typeof` is
                        # "undefined".
                        if self.in_typeof_operand {
                            self._op(Opcode.LOAD_UNDEFINED);
                        } else {
                            self._emit_reference_error(name + " is not defined");
                        }
                    } else {
                        # arg2 = 1 → tolerant load (typeof operand): VM yields undefined
                        # instead of throwing ReferenceError on an unresolvable name (A9).
                        lg_tol: int = 0;
                        if self.in_typeof_operand {
                            lg_tol = 1;
                        }
                        self._emit(
                            make_instruction(
                                Opcode.LOAD_GLOBAL,
                                self._intern(name),
                                lg_tol,
                                nd.loc.line
                            )
                        );
                    }
                }
            }
        }
    }

    # ── binary expression ──────────────────────────────────────────────────

    def compile_binary(nd: ASTNode) -> None {
        op: str = nd.operator;
        # Private-in: `#member in obj` (ES §13.10) — brand-membership test.  The LHS
        # is a private name (parsed as an Identifier starting with `#`); do NOT load
        # it as a variable.  Compile the object and emit CHECK_PRIVATE in membership
        # mode (arg2=1), which pushes a boolean.
        if op == "in"
            and nd.left is not None
            and nd.left.ntype == ASTNodeType.Identifier
            and self._is_private_name(nd.left.name) {
            if nd.right is not None {
                self.compile_expr(nd.right);
            }
            pin_key: int = self._intern(self._prop_key(nd.left.name));
            self._emit(make_instruction(Opcode.CHECK_PRIVATE, pin_key, 1, nd.loc.line));
            return;
        }
        if nd.left is not None {
            self.compile_expr(nd.left);
        }
        if nd.right is not None {
            self.compile_expr(nd.right);
        }
        mapped: Opcode = compiler_op_for_binary(op);
        if mapped != Opcode.NOP {
            self._op(mapped);
        } else {
            self._syntax_error("SyntaxError: Unknown operator '" + op + "'");
        }
    }

    # ── unary expression ───────────────────────────────────────────────────

    def compile_unary(nd: ASTNode) {
        op: str = nd.operator;
        if op == "typeof" {
            if nd.argument is not None {
                # `typeof <ident>` on an unresolvable name must yield "undefined",
                # not throw — mark the operand load tolerant (A9). The identifier
                # resolves like any other read: a let/const whose block has ended is
                # only "undefined" when no binding of that name is still in scope.
                saved_tof: bool = self.in_typeof_operand;
                if nd.argument.ntype == ASTNodeType.Identifier {
                    self.in_typeof_operand = True;
                }
                self.compile_expr(nd.argument);
                self.in_typeof_operand = saved_tof;
                self._op(Opcode.TYPEOF);
            } else {
                self._op(Opcode.TYPEOF);
            }
        } elif op == "void" {
            if nd.argument is not None {
                self.compile_expr(nd.argument);
            }
            self._op(Opcode.VOID);
        } elif op == "delete" {
            strict01: int = 0;
            if self._fn().is_strict {
                strict01 = 1;
            }
            if nd.argument is not None {
                arg: ASTNode = nd.argument;
                if arg.ntype == ASTNodeType.MemberExpression {
                    if arg.object is not None {
                        self.compile_expr(arg.object);
                    }
                    if arg.computed {
                        if arg.property is not None {
                            self.compile_expr(arg.property);
                        }
                        self._emit(make_instruction(Opcode.DELETE, 0, strict01, 0));  # stack: obj, key → DELETE pops both
                    } else {
                        if arg.property is not None {
                            # arg2 = cached key id (like GET_PROP); arg3 = strict flag.
                            # Putting strict in arg2 collided with key caching and made
                            # `delete ns.local` resolve key=1 ("__proto__") in modules.
                            _dp_idx: int = self._intern_key(arg.property.name);
                            self._emit(
                                make_instruction(
                                    Opcode.DEL_PROP,
                                    _dp_idx,
                                    self._last_key_id,
                                    0,
                                    strict01
                                )
                            );
                        }
                    }
                } elif arg.ntype == ASTNodeType.Identifier {
                    # `delete <Identifier>` (ES §13.5.1.2): a resolvable binding that
                    # is non-configurable → false; unresolvable → true.  A local slot
                    # or a top-level `var` binding is non-configurable, so it is false
                    # and the operand is NOT evaluated.  Any other bare name (a global
                    # property such as a built-in `NaN`, or a plain assigned global)
                    # is resolved at runtime by DEL_NAME, which respects the property's
                    # [[Configurable]] attribute.  (Strict mode makes `delete name` an
                    # early SyntaxError, handled in the parser.)
                    del_slot: int = self._resolve(arg.name);
                    if del_slot >= 0
                        or arg.name in self.global_var_names
                        or arg.name in self.lexical_global_names {
                        # Local slot, top-level `var`, or a top-level lexical binding
                        # (let/const/class) — all non-configurable → delete is false.
                        self._op(Opcode.LOAD_FALSE);
                    } else {
                        self._emit(
                            make_instruction(
                                Opcode.DEL_NAME, self._intern(arg.name), strict01, 0
                            )
                        );
                    }
                } else {
                    # `delete <other expression>` (a call result, literal, …): the
                    # operand is not a Reference, so the result is always true — but
                    # the operand MUST still be evaluated for its side effects
                    # (`delete foo()` calls foo), then discarded.
                    self.compile_expr(arg);
                    self._op(Opcode.POP);
                    self._op(Opcode.LOAD_TRUE);
                }
            } else {
                self._op(Opcode.LOAD_TRUE);
            }
        } elif op == "!" {
            if nd.argument is not None {
                self.compile_expr(nd.argument);
            }
            self._op(Opcode.NOT);
        } elif op == "-" {
            if nd.argument is not None {
                self.compile_expr(nd.argument);
            }
            self._op(Opcode.NEG);
        } elif op == "+" {
            if nd.argument is not None {
                self.compile_expr(nd.argument);
            }
            self._op(Opcode.TO_NUMBER);
        } elif op == "~" {
            if nd.argument is not None {
                self.compile_expr(nd.argument);
            }
            self._op(Opcode.BNOT);
        } else {
            if nd.argument is not None {
                self.compile_expr(nd.argument);
            }
        }
    }

    # ── logical (short-circuit) ────────────────────────────────────────────

    def compile_logical(nd: ASTNode) {
        op: str = nd.operator;
        # ES §15.10.3: tail position propagates to the RIGHT operand of &&/||/?? — the LHS is
        # the condition (not a tail call). Capture and clear the incoming tail flag, restore
        # it only for the RHS so `return a && f(x)` tail-calls `f`.
        lg_tail: bool = self._emit_tail_call;
        self._emit_tail_call = False;
        if nd.left is not None {
            self.compile_expr(nd.left);
        }
        if op == "&&" {
            # JUMP_IF_FALSE pops the condition.  DUP first so the original
            # LHS stays on the stack as the result when the condition is false.
            self._op(Opcode.DUP);
            j: int = self._jump(Opcode.JUMP_IF_FALSE);
            self._op(Opcode.POP);  # true path: discard the DUP'd LHS
            self._emit_tail_call = lg_tail;
            if nd.right is not None {
                self.compile_expr(nd.right);
            }
            self._emit_tail_call = False;
            self._patch(j);  # false path: original LHS already on stack
        } elif op == "||" {
            # Symmetric: DUP so original LHS stays when condition is truthy.
            self._op(Opcode.DUP);
            j: int = self._jump(Opcode.JUMP_IF_TRUE);
            self._op(Opcode.POP);  # false path: discard the DUP'd LHS
            self._emit_tail_call = lg_tail;
            if nd.right is not None {
                self.compile_expr(nd.right);
            }
            self._emit_tail_call = False;
            self._patch(j);  # true path: original LHS already on stack
        } elif op == "??" {
            # ECMAScript: ?? triggers on null OR undefined.
            # Both JUMP_IF_NULL and JUMP_IF_UNDEFINED peek (do not pop).
            j_null: int = self._jump(Opcode.JUMP_IF_NULL);
            j_undef: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
            j_end: int = self._jump(Opcode.JUMP);  # LHS is not nullish — keep it
            self._patch(j_null);  # null path
            self._patch(j_undef);  # undefined path
            self._op(Opcode.POP);  # discard null/undefined
            self._emit_tail_call = lg_tail;
            if nd.right is not None {
                self.compile_expr(nd.right);
            }
            self._emit_tail_call = False;
            self._patch(j_end);
        } else {
            self._op(Opcode.POP);
            self._emit_tail_call = lg_tail;
            if nd.right is not None {
                self.compile_expr(nd.right);
            }
            self._emit_tail_call = False;
        }
    }

    # ── conditional (ternary) ──────────────────────────────────────────────

    def compile_conditional(nd: ASTNode) {
        # ES §15.10.3: tail position propagates to BOTH branches of `?:` (the test is not a
        # tail call). Capture/clear for the test, restore for each branch.
        cnd_tail: bool = self._emit_tail_call;
        self._emit_tail_call = False;
        if nd.cond_expr is not None {
            self.compile_expr(nd.cond_expr);
        }
        jf: int = self._jump(Opcode.JUMP_IF_FALSE);
        self._emit_tail_call = cnd_tail;
        if nd.consequent is not None {
            self.compile_expr(nd.consequent);
        }
        self._emit_tail_call = False;
        je: int = self._jump(Opcode.JUMP);
        self._patch(jf);
        self._emit_tail_call = cnd_tail;
        if nd.alternate is not None {
            self.compile_expr(nd.alternate);
        }
        self._emit_tail_call = False;
        self._patch(je);
    }

    # ── assignment ─────────────────────────────────────────────────────────

    """Assignment optimized for statement context (Identifier LHS only).
    Skips the DUP that compile_assign emits for expression-context callers,
    saving a DUP+POP pair per assignment statement."""
    def compile_assign_stmt(nd: ASTNode) -> None {
        if nd.left is None {
            return;
        }
        op: str = nd.operator;
        lhs: ASTNode = nd.left;
        if op == "||=" {
            # layout: lhs; DUP; JUMP_IF_FALSE→assign; JUMP→skip;
            #   [assign]: POP; rhs; store; JUMP→done;
            #   [skip]: POP;  [done]:
            self.compile_expr(lhs);
            self._op(Opcode.DUP);
            j_assign_or: int = self._jump(Opcode.JUMP_IF_FALSE);
            j_skip_or: int = self._jump(Opcode.JUMP);
            self._patch(j_assign_or);
            self._op(Opcode.POP);
            if nd.right is not None {
                self.compile_expr(nd.right);
                if lhs.ntype == ASTNodeType.Identifier {
                    self._maybe_infer_fn_name(nd.right, lhs.name);
                }
            }
            self._store_lvalue(lhs);
            j_done_or: int = self._jump(Opcode.JUMP);
            self._patch(j_skip_or);
            self._op(Opcode.POP);
            self._patch(j_done_or);
            return;
        }
        if op == "&&=" {
            # layout: lhs; DUP; JUMP_IF_TRUE→assign; JUMP→skip;
            #   [assign]: POP; rhs; store; JUMP→done;
            #   [skip]: POP;  [done]:
            self.compile_expr(lhs);
            self._op(Opcode.DUP);
            j_assign_and: int = self._jump(Opcode.JUMP_IF_TRUE);
            j_skip_and: int = self._jump(Opcode.JUMP);
            self._patch(j_assign_and);
            self._op(Opcode.POP);
            if nd.right is not None {
                self.compile_expr(nd.right);
                if lhs.ntype == ASTNodeType.Identifier {
                    self._maybe_infer_fn_name(nd.right, lhs.name);
                }
            }
            self._store_lvalue(lhs);
            j_done_and: int = self._jump(Opcode.JUMP);
            self._patch(j_skip_and);
            self._op(Opcode.POP);
            self._patch(j_done_and);
            return;
        }
        if op == "??=" {
            # layout: lhs; JUMP_IF_NULL→assign; JUMP_IF_UNDEFINED→assign; JUMP→skip;
            #   [assign]: POP; rhs; store; JUMP→done;
            #   [skip]: POP;  [done]:
            self.compile_expr(lhs);
            j_null_s: int = self._jump(Opcode.JUMP_IF_NULL);
            j_undef_s: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
            j_skip_nul: int = self._jump(Opcode.JUMP);
            self._patch(j_null_s);
            self._patch(j_undef_s);
            self._op(Opcode.POP);
            if nd.right is not None {
                self.compile_expr(nd.right);
                if lhs.ntype == ASTNodeType.Identifier {
                    self._maybe_infer_fn_name(nd.right, lhs.name);
                }
            }
            self._store_lvalue(lhs);
            j_done_nul: int = self._jump(Opcode.JUMP);
            self._patch(j_skip_nul);
            self._op(Opcode.POP);
            self._patch(j_done_nul);
            return;
        }
        if op == "="
            and lhs.ntype == ASTNodeType.Identifier
            and self.with_depth > 0
            and lhs.name not in self.esm_import_bindings
            and not self._is_esm_live(lhs.name) {
            # Plain `x = rhs` STATEMENT to a bare identifier inside `with` (ES §13.15.2):
            # the reference to `x` is resolved to its base ONCE, BEFORE the RHS, so a
            # side effect during RHS evaluation (e.g. `delete scope.x`) cannot re-target
            # the write to an outer binding (test262 S11.13.1_A5_T1 — the expression-form
            # of this lives in compile_assign). LOAD_NAME_REF arg2=1 captures ONLY the base
            # (a plain store reads no value — reading a write-only/unbound name like a sloppy
            # implicit global would spuriously throw). The trailing POP drops the
            # STORE_NAME_REF result — statement context needs no value.
            pws_name_arg: int = self._intern(lhs.name);
            pws_strict: int = 1 if self._fn().is_strict else 0;
            self._emit(make_instruction(Opcode.LOAD_NAME_REF, pws_name_arg, 1, 0));  # arg2=1: base only
            if nd.right is not None {
                self.compile_expr(nd.right);
                self._maybe_infer_fn_name(nd.right, lhs.name);
            }
            self._emit(
                make_instruction(Opcode.STORE_NAME_REF, pws_name_arg, pws_strict, 0)
            );
            self._op(Opcode.POP);  # statement context: discard result
        } elif op == "=" {
            if nd.right is not None {
                self.compile_expr(nd.right);
                self._maybe_infer_fn_name(nd.right, lhs.name);
            }
            # No DUP — result is not needed in statement context.
            self._store_lvalue(lhs);
        } elif lhs.ntype == ASTNodeType.Identifier and self.with_depth > 0 {
            # Compound assignment to a bare identifier inside `with` (statement form):
            # resolve the reference ONCE via LOAD_NAME_REF/STORE_NAME_REF (ES §13.15.2),
            # so a getter that deletes the with-binding mid-read cannot re-target the
            # write (test262 compound-assignment S11.13.2_A5/A6). Result discarded (POP).
            sca_name_arg: int = self._intern(lhs.name);
            sca_strict: int = 1 if self._fn().is_strict else 0;
            self._emit(make_instruction(Opcode.LOAD_NAME_REF, sca_name_arg, 0, 0));
            if nd.right is not None {
                self.compile_expr(nd.right);
            }
            self._emit_binop(op[0:len(op) - 1]);
            self._emit(
                make_instruction(Opcode.STORE_NAME_REF, sca_name_arg, sca_strict, 0)
            );
            self._op(Opcode.POP);
        } else {
            # Compound: load current value, compile rhs, apply op, store.
            self.compile_expr(lhs);
            if nd.right is not None {
                self.compile_expr(nd.right);
            }
            self._emit_binop(op[0:len(op) - 1]);
            # No DUP — result is not needed in statement context.
            self._store_lvalue(lhs);
        }
    }

    def compile_assign(nd: ASTNode) -> None {
        if nd.left is None {
            return;
        }
        op: str = nd.operator;
        lhs: ASTNode = nd.left;
        if op == "||=" {
            # Computed-member target: evaluate the reference (base + key) ONCE via the helper
            # (test262 logical-assignment lgcl-*-operator-lhs-before-rhs). Falls through to the
            # generic path for identifier / literal-key / super targets, or if no slot is free.
            if lhs.ntype == ASTNodeType.MemberExpression
                and lhs.computed
                and self._computed_key_needs_once(lhs)
                and not self._lhs_is_super_member(lhs)
                and self._compile_logical_computed_member(nd, lhs, 0) {
                return;
            }
            self.compile_expr(lhs);
            self._op(Opcode.DUP);
            j_skip_or: int = self._jump(Opcode.JUMP_IF_FALSE);
            j_end_or: int = self._jump(Opcode.JUMP);
            self._patch(j_skip_or);
            self._op(Opcode.POP);
            if nd.right is not None {
                self.compile_expr(nd.right);
                # ES §13.15.2 NamedEvaluation: `x ||= function(){}` names the anonymous
                # fn/class after the identifier target (test262 logical-assignment
                # -namedevaluation-*).
                if lhs.ntype == ASTNodeType.Identifier {
                    self._maybe_infer_fn_name(nd.right, lhs.name);
                }
            }
            if lhs.ntype == ASTNodeType.Identifier {
                self._op(Opcode.DUP);
            }
            self._store_lvalue(lhs);
            self._patch(j_end_or);
            return;
        }
        if op == "&&=" {
            if lhs.ntype == ASTNodeType.MemberExpression
                and lhs.computed
                and self._computed_key_needs_once(lhs)
                and not self._lhs_is_super_member(lhs)
                and self._compile_logical_computed_member(nd, lhs, 1) {
                return;
            }
            self.compile_expr(lhs);
            self._op(Opcode.DUP);
            # &&= assigns only when the LHS is truthy; a falsy LHS short-circuits
            # and keeps the original value (no store).  This is the mirror of ||=.
            j_end_and: int = self._jump(Opcode.JUMP_IF_FALSE);
            self._op(Opcode.POP);
            if nd.right is not None {
                self.compile_expr(nd.right);
                if lhs.ntype == ASTNodeType.Identifier {
                    self._maybe_infer_fn_name(nd.right, lhs.name);
                }
            }
            if lhs.ntype == ASTNodeType.Identifier {
                self._op(Opcode.DUP);
            }
            self._store_lvalue(lhs);
            self._patch(j_end_and);
            return;
        }
        if op == "??=" {
            if lhs.ntype == ASTNodeType.MemberExpression
                and lhs.computed
                and self._computed_key_needs_once(lhs)
                and not self._lhs_is_super_member(lhs)
                and self._compile_logical_computed_member(nd, lhs, 2) {
                return;
            }
            self.compile_expr(lhs);
            j_null_s: int = self._jump(Opcode.JUMP_IF_NULL);
            j_undef_s: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
            j_end_nul: int = self._jump(Opcode.JUMP);
            self._patch(j_null_s);
            self._patch(j_undef_s);
            self._op(Opcode.POP);
            if nd.right is not None {
                self.compile_expr(nd.right);
                if lhs.ntype == ASTNodeType.Identifier {
                    self._maybe_infer_fn_name(nd.right, lhs.name);
                }
            }
            if lhs.ntype == ASTNodeType.Identifier {
                self._op(Opcode.DUP);
            }
            self._store_lvalue(lhs);
            self._patch(j_end_nul);
            return;
        }
        if op == "=" {
            _pa_is_super_member: bool = lhs.ntype == ASTNodeType.MemberExpression
                and lhs.object is not None
                and lhs.object.ntype == ASTNodeType.Identifier
                and lhs.object.name == "super";
            if lhs.ntype == ASTNodeType.MemberExpression
                and lhs.computed
                and self._computed_key_needs_once(lhs)
                and not _pa_is_super_member
                and self._compile_plain_computed_member_assign(nd, lhs) {
                # Handled by the ordered computed-member helper (evaluates base + key
                # expression before the RHS, ToPropertyKey deferred until after).
            } elif _pa_is_super_member
                and lhs.computed
                and self._computed_key_needs_once(lhs)
                and self._compile_plain_computed_super_assign(nd, lhs) {
                # Handled by the ordered computed-super helper.
            } elif lhs.ntype == ASTNodeType.Identifier
                and self.with_depth > 0
                and lhs.name not in self.esm_import_bindings
                and not self._is_esm_live(lhs.name) {
                # Plain `x = rhs` to a bare identifier inside `with` (ES §13.15.2): the
                # reference to `x` is created and resolved to its base ONCE, BEFORE the
                # RHS. PutValue then writes through that captured base even if the
                # binding was deleted/re-shadowed during RHS evaluation (test262
                # S11.13.1_A5). LOAD_NAME_REF arg2=1 pushes ONLY the base (no GetValue is
                # spec'd for a plain assignment target — reading it would spuriously throw
                # for a write-only/unbound name like a sloppy implicit global).
                pw_name_arg: int = self._intern(lhs.name);
                pw_strict: int = 1 if self._fn().is_strict else 0;
                # Capture the enclosing binding as a free var so the runtime name-chain
                # store can reach it (mirrors _store_lvalue's with-path) — needed for a
                # direct-eval-forced dynamic body assigning an outer binding.
                _ = self._capture(lhs.name);
                self._emit(make_instruction(Opcode.LOAD_NAME_REF, pw_name_arg, 1, 0));  # arg2=1: base only (plain `=` reads no value)
                if nd.right is not None {
                    self.compile_expr(nd.right);
                    self._maybe_infer_fn_name(nd.right, lhs.name);
                }
                self._emit(
                    make_instruction(Opcode.STORE_NAME_REF, pw_name_arg, pw_strict, 0)
                );
            } else {
                if nd.right is not None {
                    self.compile_expr(nd.right);
                    # NamedEvaluation only fires when the LHS IsIdentifierRef — a bare
                    # identifier, NOT a parenthesized `(x)` (test262 fn-name-lhs-cover).
                    if lhs.ntype == ASTNodeType.Identifier and not lhs.parenthesized {
                        self._maybe_infer_fn_name(nd.right, lhs.name);
                    }
                }
                # DUP so assignment expression leaves its value on the stack.
                # ExpressionStatement will POP it; other callers use it.
                # (MemberExpression _store_lvalue manages its own stack layout.)
                # Object/Array destructuring assignment also needs a DUP: _store_lvalue
                # consumes one copy while the other stays as the expression result.
                if lhs.ntype == ASTNodeType.Identifier {
                    self._op(Opcode.DUP);
                } elif lhs.ntype == ASTNodeType.ObjectExpression
                    or lhs.ntype == ASTNodeType.ArrayExpression {
                    self._op(Opcode.DUP);
                }
                self._store_lvalue(lhs);
            }
        } elif lhs.ntype == ASTNodeType.MemberExpression
            and lhs.computed
            and self._lhs_is_super_member(lhs)
            and self._compile_super_computed_compound(nd, lhs, op[0:len(op) - 1]) {
            # `super[key] op= rhs` — routed through the SUPER opcodes (else `super` compiles
            # as a bare identifier). Key evaluated once. Handled by the helper.
        } elif lhs.ntype == ASTNodeType.MemberExpression
            and lhs.computed
            and self._computed_key_needs_once(lhs) {
            # Compound assignment to a computed member: `base[prop] op= rhs`.
            # ECMAScript §13.15.2: the reference (base and ToPropertyKey(prop)) is
            # evaluated ONCE, before the RHS.  Evaluate obj+key up front, coerce the
            # key a single time with TO_PROPERTY_KEY, stash it in a synthetic local,
            # and DUP the object so `base` and `prop` each evaluate exactly once.
            _ca_bin: str = op[0:len(op) - 1];
            _ca_seq: int = self._dstr_iter_seq;
            self._dstr_iter_seq = self._dstr_iter_seq + 1;
            _ca_oslot: int = self._declare("__caobj_" + str(_ca_seq), "const");
            _ca_kslot: int = self._declare("__cakey_" + str(_ca_seq), "const");
            _ca_vslot: int = self._declare("__caval_" + str(_ca_seq), "const");
            if _ca_oslot < 0 or _ca_kslot < 0 or _ca_vslot < 0 {
                # Bare-global fallback: no local slot available.  Re-evaluate via the
                # generic path (double-eval, but correct value) rather than fail.
                self.compile_expr(lhs);
                if nd.right is not None {
                    self.compile_expr(nd.right);
                }
                self._emit_binop(_ca_bin);
                self._store_lvalue(lhs);
            } else {
                # Spec order (§13.3.3 EvaluatePropertyAccessWithExpressionKey, driving
                # §13.15.2): base, then the key EXPRESSION, then RequireObjectCoercible
                # on base, then ToPropertyKey — so `prop()` runs even when base is
                # nullish, but `prop.toString` runs only after the null check.
                if lhs.object is not None {
                    self.compile_expr(lhs.object);
                }  # [obj]
                self._emit(make_instruction(Opcode.STORE_LOCAL, _ca_oslot, 0, 0));  # []
                if lhs.property is not None {
                    self.compile_expr(lhs.property);
                }  # [rawkey]
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _ca_oslot, 0, 0));  # [rawkey, obj]
                self._op(Opcode.REQUIRE_COERCIBLE);  # throws if obj nullish
                self._op(Opcode.POP);  # [rawkey]
                self._op(Opcode.TO_PROPERTY_KEY);  # [key]
                self._emit(make_instruction(Opcode.STORE_LOCAL, _ca_kslot, 0, 0));  # []
                # read: cur = obj[key]
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _ca_oslot, 0, 0));
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _ca_kslot, 0, 0));
                self._op(Opcode.GET_INDEX);  # [cur]
                if nd.right is not None {
                    self.compile_expr(nd.right);
                }  # [cur, rhs]
                self._emit_binop(_ca_bin);  # [newval]
                # write: obj[key] = newval.  Stash newval, then lay out [obj, key, newval]
                # so SET_INDEX pops (val, key, obj) in order.
                self._emit(make_instruction(Opcode.STORE_LOCAL, _ca_vslot, 0, 0));  # []
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _ca_oslot, 0, 0));  # [obj]
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _ca_kslot, 0, 0));  # [obj, key]
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _ca_vslot, 0, 0));  # [obj, key, newval]
                self._op(Opcode.SET_INDEX);  # [newval]
            }
        } elif lhs.ntype == ASTNodeType.Identifier and self.with_depth > 0 {
            # Compound assignment to a bare identifier inside `with`: the reference must
            # be resolved ONCE (ES §13.15.2). LOAD_NAME_REF pushes [base, value];
            # STORE_NAME_REF writes back through that same base and leaves the value as
            # the expression result — so a getter that deletes the with-binding mid-read
            # cannot re-target the write to an outer binding (test262 compound-assignment
            # S11.13.2_A5/A6). The name may still resolve to a lexical/global binding, in
            # which case LOAD_NAME_REF pushes a null base sentinel and STORE_NAME_REF
            # falls back to the ordinary name-chain store.
            wc_name_arg: int = self._intern(lhs.name);
            wc_strict: int = 1 if self._fn().is_strict else 0;
            # Capture the enclosing-scope binding as a free var so LOAD_NAME_REF/
            # STORE_NAME_REF can resolve it at runtime (mirrors compile_identifier's
            # with-path) — needed for a direct-eval-forced dynamic body compound-assigning
            # an outer binding (test262 compound-assignment/S11.13.2_A6.*_T1).
            _ = self._capture(lhs.name);
            self._emit(make_instruction(Opcode.LOAD_NAME_REF, wc_name_arg, 0, 0));
            if nd.right is not None {
                self.compile_expr(nd.right);
            }
            self._emit_binop(op[0:len(op) - 1]);
            self._emit(
                make_instruction(Opcode.STORE_NAME_REF, wc_name_arg, wc_strict, 0)
            );
        } else {
            self.compile_expr(lhs);
            if nd.right is not None {
                self.compile_expr(nd.right);
            }
            self._emit_binop(op[0:len(op) - 1]);
            if lhs.ntype == ASTNodeType.Identifier {
                self._op(Opcode.DUP);
            }
            self._store_lvalue(lhs);
        }
    }

    """Plain `base[prop] = rhs` with a non-literal computed key (ES §13.15.2).
    Evaluation order: the LHS reference is evaluated first — base, then the key
    EXPRESSION — and only THEN the RHS; ToPropertyKey(prop) and ToObject(base) are
    deferred to PutValue, i.e. after the RHS (test262 target-member-computed-reference
    and its -null/-undefined variants). Returns False when no local slots are
    available (bare-global scope), so the caller falls back to the generic path."""
    def _compile_plain_computed_member_assign(nd: ASTNode, lhs: ASTNode) -> bool {
        _pm_seq: int = self._dstr_iter_seq;
        self._dstr_iter_seq = self._dstr_iter_seq + 1;
        _pm_oslot: int = self._declare("__pmobj_" + str(_pm_seq), "const");
        _pm_kslot: int = self._declare("__pmkey_" + str(_pm_seq), "const");
        _pm_vslot: int = self._declare("__pmval_" + str(_pm_seq), "const");
        if _pm_oslot < 0 or _pm_kslot < 0 or _pm_vslot < 0 {
            return False;
        }
        _pm_strict: int = 1 if self._fn().is_strict else 0;
        if lhs.object is not None {
            self.compile_expr(lhs.object);
        }  # [obj]
        self._emit(make_instruction(Opcode.STORE_LOCAL, _pm_oslot, 0, 0));  # []
        if lhs.property is not None {
            self.compile_expr(lhs.property);
        }  # [rawkey] (key EXPRESSION, uncoerced)
        self._emit(make_instruction(Opcode.STORE_LOCAL, _pm_kslot, 0, 0));  # []
        if nd.right is not None {
            self.compile_expr(nd.right);
        }  # [rhs]  (RHS runs before ToPropertyKey/ToObject)
        self._emit(make_instruction(Opcode.STORE_LOCAL, _pm_vslot, 0, 0));  # []
        # PutValue: ToObject(base) (RequireObjectCoercible → TypeError if nullish),
        # then ToPropertyKey(key), then [[Set]].
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _pm_oslot, 0, 0));  # [obj]
        self._op(Opcode.REQUIRE_COERCIBLE);  # [obj] (throws if obj nullish)
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _pm_kslot, 0, 0));  # [obj, rawkey]
        self._op(Opcode.TO_PROPERTY_KEY);  # [obj, key]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _pm_vslot, 0, 0));  # [obj, key, val]
        self._emit(make_instruction(Opcode.SET_INDEX, 0, _pm_strict, 0));  # [val]
        return True;
    }

    """`base[prop] ||= rhs` / `&&=` / `??=` with a non-literal computed key.
    ES §13.15.2 (ApplyStringOrNumericBinaryOperator is not used for logical assignment,
    but the LHS Reference is still evaluated ONCE, before the short-circuit): evaluate base
    then the key EXPRESSION, coerce the key a single time, READ `cur = obj[key]`, then
    short-circuit — the RHS and the store run only on the taken branch, reusing the SAME
    obj/key (so `obj[incr()] ||= incr()` calls the key `incr()` exactly once). `mode`: 0=||=,
    1=&&=, 2=??=. Returns False when no local slots are available (caller falls back)."""
    def _compile_logical_computed_member(nd: ASTNode, lhs: ASTNode, mode: int) -> bool {
        _lm_seq: int = self._dstr_iter_seq;
        self._dstr_iter_seq = self._dstr_iter_seq + 1;
        _lm_oslot: int = self._declare("__lmobj_" + str(_lm_seq), "const");
        _lm_kslot: int = self._declare("__lmkey_" + str(_lm_seq), "const");
        if _lm_oslot < 0 or _lm_kslot < 0 {
            return False;
        }
        _lm_strict: int = 1 if self._fn().is_strict else 0;
        # Evaluate the reference ONCE: base, then key EXPRESSION, RequireObjectCoercible(base)
        # (so a nullish base throws AFTER the key expr runs — matching §13.3.3 order), then
        # ToPropertyKey once. Stash obj + coerced key in locals.
        if lhs.object is not None {
            self.compile_expr(lhs.object);
        }  # [obj]
        self._emit(make_instruction(Opcode.STORE_LOCAL, _lm_oslot, 0, 0));  # []
        if lhs.property is not None {
            self.compile_expr(lhs.property);
        }  # [rawkey]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _lm_oslot, 0, 0));  # [rawkey, obj]
        self._op(Opcode.REQUIRE_COERCIBLE);  # throws if obj nullish
        self._op(Opcode.POP);  # [rawkey]
        self._op(Opcode.TO_PROPERTY_KEY);  # [key]
        self._emit(make_instruction(Opcode.STORE_LOCAL, _lm_kslot, 0, 0));  # []
        # read: cur = obj[key]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _lm_oslot, 0, 0));
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _lm_kslot, 0, 0));
        self._op(Opcode.GET_INDEX);  # [cur]
        # Short-circuit: keep `cur` as the result on the no-store branch; else store rhs.
        _lm_jstore: int = 0;
        _lm_jskip: int = 0;
        if mode == 0 {  # ||=  : store only when cur is FALSY
            self._op(Opcode.DUP);
            _lm_jstore = self._jump(Opcode.JUMP_IF_FALSE);  # falsy → store
            _lm_jskip = self._jump(Opcode.JUMP);  # truthy → keep cur
            self._patch(_lm_jstore);
            self._op(Opcode.POP);  # discard cur
        } elif mode == 1 {  # &&=  : store only when cur is TRUTHY
            self._op(Opcode.DUP);
            _lm_jstore = self._jump(Opcode.JUMP_IF_TRUE);  # truthy → store
            _lm_jskip = self._jump(Opcode.JUMP);  # falsy → keep cur
            self._patch(_lm_jstore);
            self._op(Opcode.POP);  # discard cur
        } else {  # ??=  : store only when cur is null/undefined
            _lm_jn: int = self._jump(Opcode.JUMP_IF_NULL);
            _lm_ju: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
            _lm_jskip = self._jump(Opcode.JUMP);  # non-nullish → keep cur
            self._patch(_lm_jn);
            self._patch(_lm_ju);
            self._op(Opcode.POP);  # discard cur (nullish)
        }
        # store branch (stack is [] here — cur was discarded above): eval RHS, then
        # obj[key] = rhs. Lay out [obj, key, rhs] for SET_INDEX (pops val,key,obj), which
        # leaves rhs on the stack as the assignment-expression result.
        _lm_vslot: int = self._declare("__lmval_" + str(_lm_seq), "const");
        if _lm_vslot < 0 {
            return False;
        }
        if nd.right is not None {
            self.compile_expr(nd.right);  # [rhs]
        } else {
            self._op(Opcode.LOAD_UNDEFINED);  # [rhs]
        }
        self._emit(make_instruction(Opcode.STORE_LOCAL, _lm_vslot, 0, 0));  # []
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _lm_oslot, 0, 0));  # [obj]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _lm_kslot, 0, 0));  # [obj, key]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _lm_vslot, 0, 0));  # [obj, key, rhs]
        self._emit(make_instruction(Opcode.SET_INDEX, 0, _lm_strict, 0));  # [rhs]
        self._patch(_lm_jskip);  # both branches converge with result on TOS
        return True;
    }

    """`++super[key]` / `super[key]--` etc. — a prefix/postfix update on a COMPUTED super
    property. ToPropertyKey(key) runs ONCE (ES §13.4); the read uses SUPER_GET_INDEX and the
    write SUPER_SET_INDEX (so `super` resolves to the home object's prototype with receiver =
    `this`, not a bare `super` identifier). `up_unit` is the ±1 SUB operand. Returns False if
    no local slot is free (caller falls back)."""
    def _compile_super_computed_update(
        nd: ASTNode, arg: ASTNode, up_unit: str
    ) -> bool {
        _su_seq: int = self._dstr_iter_seq;
        self._dstr_iter_seq = self._dstr_iter_seq + 1;
        _su_kslot: int = self._declare("__sukey_" + str(_su_seq), "const");
        _su_vslot: int = self._declare("__suold_" + str(_su_seq), "const");
        _su_bslot: int = self._declare("__subase_" + str(_su_seq), "const");
        if _su_kslot < 0 or _su_vslot < 0 or _su_bslot < 0 {
            return False;
        }
        if not self.super_prop_allowed {
            self._syntax_error("SyntaxError: 'super' keyword unexpected here");
        }
        # ES §13.3.7.1 MakeSuperPropertyReference: GetThisBinding (this-TDZ) then
        # GetSuperBase are captured BEFORE evaluating the key expression — a key `toString`
        # that mutates the receiver's [[Prototype]] must NOT change the super base already
        # captured (test262 prop-expr-getsuperbase-before-topropertykey-putvalue-*). Stash
        # the super base once, then evaluate + ToPropertyKey the key.
        self._op(Opcode.LOAD_THIS);  # [this]
        self._op(Opcode.POP);  # []
        self._emit(
            make_instruction(Opcode.LOAD_SUPER_PROTO, 0, self._super_static_arg(), 0)
        );  # [base]
        self._emit(make_instruction(Opcode.STORE_LOCAL, _su_bslot, 0, 0));  # []
        if arg.property is not None {
            self.compile_expr(arg.property);
        }  # [rawkey]
        self._op(Opcode.TO_PROPERTY_KEY);  # [key]
        self._emit(make_instruction(Opcode.STORE_LOCAL, _su_kslot, 0, 0));  # []
        # cur = super[key]  →  SUPER_GET_INDEX wants [base, key, recv]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _su_bslot, 0, 0));  # [base]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _su_kslot, 0, 0));  # [base, key]
        self._op(Opcode.LOAD_THIS);  # [base, key, recv]
        self._op(Opcode.SUPER_GET_INDEX);  # [cur]
        self._const("n:0");
        self._emit(make_instruction(Opcode.SUB, 0, 1, 0));  # [numcur]  ToNumeric
        if not nd.prefix {
            self._op(Opcode.DUP);  # [numcur, numcur]
            self._emit(make_instruction(Opcode.STORE_LOCAL, _su_vslot, 0, 0));  # [numcur]
        }
        self._const(up_unit);
        self._emit(make_instruction(Opcode.SUB, 0, 1, 0));  # [new]
        # super[key] = new  →  SUPER_SET_INDEX wants [val, base, key, recv]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _su_bslot, 0, 0));  # [new, base]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _su_kslot, 0, 0));  # [new, base, key]
        self._op(Opcode.LOAD_THIS);  # [new, base, key, recv]
        self._op(Opcode.SUPER_SET_INDEX);  # [new]
        if not nd.prefix {
            self._op(Opcode.POP);  # drop new
            self._emit(make_instruction(Opcode.LOAD_LOCAL, _su_vslot, 0, 0));  # [old]
        }
        return True;
    }

    """`super[key] op= rhs` — a compound assignment to a COMPUTED super property. The
    reference (ToPropertyKey(key)) is evaluated ONCE; the read uses SUPER_GET_INDEX and the
    write SUPER_SET_INDEX. `bin` is the binary op ("+", "*", …). Returns False if no local
    slot is free (caller falls back)."""
    def _compile_super_computed_compound(nd: ASTNode, lhs: ASTNode, bin: str) -> bool {
        _sc_seq: int = self._dstr_iter_seq;
        self._dstr_iter_seq = self._dstr_iter_seq + 1;
        _sc_kslot: int = self._declare("__sckey_" + str(_sc_seq), "const");
        _sc_vslot: int = self._declare("__scval_" + str(_sc_seq), "const");
        _sc_bslot: int = self._declare("__scbase_" + str(_sc_seq), "const");
        if _sc_kslot < 0 or _sc_vslot < 0 or _sc_bslot < 0 {
            return False;
        }
        if not self.super_prop_allowed {
            self._syntax_error("SyntaxError: 'super' keyword unexpected here");
        }
        # ES §13.3.7.1: GetThisBinding then GetSuperBase captured BEFORE the key expression —
        # a key `toString` that swaps the receiver's prototype must not change the captured
        # super base (test262 prop-expr-getsuperbase-before-topropertykey-putvalue-*).
        self._op(Opcode.LOAD_THIS);  # [this]
        self._op(Opcode.POP);  # []
        self._emit(
            make_instruction(Opcode.LOAD_SUPER_PROTO, 0, self._super_static_arg(), 0)
        );  # [base]
        self._emit(make_instruction(Opcode.STORE_LOCAL, _sc_bslot, 0, 0));  # []
        if lhs.property is not None {
            self.compile_expr(lhs.property);
        }  # [rawkey]
        self._op(Opcode.TO_PROPERTY_KEY);  # [key]
        self._emit(make_instruction(Opcode.STORE_LOCAL, _sc_kslot, 0, 0));  # []
        # cur = super[key]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _sc_bslot, 0, 0));  # [base]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _sc_kslot, 0, 0));  # [base, key]
        self._op(Opcode.LOAD_THIS);  # [base, key, recv]
        self._op(Opcode.SUPER_GET_INDEX);  # [cur]
        if nd.right is not None {
            self.compile_expr(nd.right);
        }  # [cur, rhs]
        self._emit_binop(bin);  # [new]
        # super[key] = new  →  SUPER_SET_INDEX wants [val, base, key, recv]
        self._emit(make_instruction(Opcode.STORE_LOCAL, _sc_vslot, 0, 0));  # []
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _sc_vslot, 0, 0));  # [new]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _sc_bslot, 0, 0));  # [new, base]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _sc_kslot, 0, 0));  # [new, base, key]
        self._op(Opcode.LOAD_THIS);  # [new, base, key, recv]
        self._op(Opcode.SUPER_SET_INDEX);  # [new]
        return True;
    }

    """Plain `super[prop] = rhs` with a non-literal computed key (ES §13.15.2).
    The key EXPRESSION is evaluated before the RHS; ToPropertyKey(prop) is deferred
    until after the RHS (test262 target-super-computed-reference). Returns False when
    no local slots are available, so the caller falls back to the generic path."""
    def _compile_plain_computed_super_assign(nd: ASTNode, lhs: ASTNode) -> bool {
        _ps_seq: int = self._dstr_iter_seq;
        self._dstr_iter_seq = self._dstr_iter_seq + 1;
        _ps_kslot: int = self._declare("__pskey_" + str(_ps_seq), "const");
        _ps_vslot: int = self._declare("__psval_" + str(_ps_seq), "const");
        if _ps_kslot < 0 or _ps_vslot < 0 {
            return False;
        }
        if not self.super_prop_allowed {
            self._syntax_error("SyntaxError: 'super' keyword unexpected here");
        }
        # ES §13.3.7.1 SuperProperty[Expression]: step 2 GetThisBinding runs BEFORE
        # step 3 (evaluating the key Expression). In a derived constructor with an
        # uninitialized `this` (before super() returns), GetThisBinding throws a
        # ReferenceError that must precede any side effect of the key expression —
        # e.g. `super[super()] = 0` throws ReferenceError, not the base-ctor error
        # (test262 super/prop-expr-uninitialized-this-putvalue). LOAD_THIS enforces
        # this-TDZ; POP discards the value (re-read below for the actual receiver).
        self._op(Opcode.LOAD_THIS);  # [this]
        self._op(Opcode.POP);  # []
        if lhs.property is not None {
            self.compile_expr(lhs.property);
        }  # [rawkey] (key EXPRESSION, uncoerced)
        self._emit(make_instruction(Opcode.STORE_LOCAL, _ps_kslot, 0, 0));  # []
        if nd.right is not None {
            self.compile_expr(nd.right);
        }  # [rhs]  (RHS before ToPropertyKey)
        self._emit(make_instruction(Opcode.STORE_LOCAL, _ps_vslot, 0, 0));  # []
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _ps_vslot, 0, 0));  # [val]
        self._emit(
            make_instruction(Opcode.LOAD_SUPER_PROTO, 0, self._super_static_arg(), 0)
        );  # [val, base]
        self._op(Opcode.LOAD_THIS);  # [val, base, recv]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _ps_kslot, 0, 0));  # [val, base, recv, rawkey]
        self._op(Opcode.TO_PROPERTY_KEY);  # [val, base, recv, key]
        self._op(Opcode.SWAP);  # [val, base, key, recv]
        self._op(Opcode.SUPER_SET_INDEX);  # [val]
        return True;
    }

    """One object-destructuring-assignment property whose target is a plain (non-super,
    non-private) MemberExpression, e.g. `({[srcKey]: tgt[tgtKey] = dflt} = src)`.
    ES §13.15.5.6 KeyedDestructuringAssignmentEvaluation orders the operations:
      1. Evaluate the source PropertyName (incl. ToPropertyKey).
      2. Evaluate the target Reference — object then key EXPRESSION (raw); ToPropertyKey
         of the target key is DEFERRED to PutValue (after the default).
      3. GetV(source, propertyName)  — the source "get".
      4. If the value is undefined and an Initializer is present, evaluate the default.
      5. PutValue: ToPropertyKey(targetKey) then [[Set]].
    The generic `_store_lvalue` path evaluates the target reference LAST (after the get
    and default), which is observably wrong when the target's object/key have side
    effects (test262 keyed-destructuring-property-reference-target-evaluation-order and
    its -with-bindings variant). Stack: [src] on entry and exit. `extracted`/`comp_slots`
    are updated for a trailing `...rest` exclusion, mirroring the inline path. Returns
    False (before emitting anything) when no temp slots are available — caller falls back
    to the generic path."""
    def _compile_dstr_member_prop(
        oad_prop: ASTNode,
        memtgt: ASTNode,
        defnode: ASTNode | None,
        extracted: list[str],
        comp_slots: list[int]
    ) -> bool {
        _dm_seq: int = self._dstr_iter_seq;
        self._dstr_iter_seq = self._dstr_iter_seq + 1;
        _dm_obj_slot: int = self._declare("__dstrmobj_" + str(_dm_seq), "const");
        _dm_val_slot: int = self._declare("__dstrmval_" + str(_dm_seq), "const");
        if _dm_obj_slot < 0 or _dm_val_slot < 0 {
            return False;
        }
        _dm_src_computed: bool = oad_prop.computed and oad_prop.key is not None;
        _dm_skey_slot: int = -1;
        if _dm_src_computed {
            _dm_skey_slot = self._declare("__dstrmskey_" + str(_dm_seq), "const");
            if _dm_skey_slot < 0 {
                return False;
            }
        }
        _dm_tgt_computed: bool = memtgt.computed;
        _dm_rkey_slot: int = -1;
        if _dm_tgt_computed {
            _dm_rkey_slot = self._declare("__dstrmrkey_" + str(_dm_seq), "const");
            if _dm_rkey_slot < 0 {
                return False;
            }
        }
        _dm_strict: int = 1 if self._fn().is_strict else 0;

        # ── 1. source PropertyName (evaluated FIRST) ─────────────────────────────
        _dm_src_static: str = "";
        if _dm_src_computed and oad_prop.key is not None {
            self._op(Opcode.DUP);  # [src, src]
            self.compile_expr(oad_prop.key);  # [src, src, rawsk]
            self._op(Opcode.TO_PROPERTY_KEY);  # [src, src, sk]
            self._emit(make_instruction(Opcode.STORE_LOCAL, _dm_skey_slot, 0, 0));  # [src, src]
            self._op(Opcode.POP);  # [src]
            comp_slots.append(_dm_skey_slot);
        } else {
            if oad_prop.key is not None {
                if oad_prop.key.ntype == ASTNodeType.Literal {
                    _dm_src_static = oad_prop.key.value;
                } else {
                    _dm_src_static = oad_prop.key.name;
                }
            }
            extracted.append(_dm_src_static);
        }

        # ── 2. target Reference: object + raw key (BEFORE the get) ───────────────
        if memtgt.object is not None {
            self.compile_expr(memtgt.object);
        } else {  # [src, obj]
            self._op(Opcode.LOAD_UNDEFINED);
        }
        self._emit(make_instruction(Opcode.STORE_LOCAL, _dm_obj_slot, 0, 0));  # [src]
        _dm_tgt_static: str = "";
        if _dm_tgt_computed {
            if memtgt.property is not None {
                self.compile_expr(memtgt.property);
            } else {  # [src, rawtk]
                self._op(Opcode.LOAD_UNDEFINED);
            }
            self._emit(make_instruction(Opcode.STORE_LOCAL, _dm_rkey_slot, 0, 0));  # [src]
        } else {
            if memtgt.property is not None {
                _dm_tgt_static = self._prop_key(memtgt.property.name);
            }
        }

        # ── 3. get: v = source[propertyName] ─────────────────────────────────────
        self._op(Opcode.DUP);  # [src, src]
        if _dm_src_computed {
            self._emit(make_instruction(Opcode.LOAD_LOCAL, _dm_skey_slot, 0, 0));  # [src, src, sk]
            self._op(Opcode.GET_INDEX);  # [src, v]
        } elif _dm_src_static == "__proto__" {
            self._const("__proto__");  # [src, src, "__proto__"]
            self._op(Opcode.GET_INDEX);  # [src, v]
        } else {
            self._emit(
                make_instruction(Opcode.GET_PROP, self._intern(_dm_src_static), 0, 0)
            );  # [src, v]
        }

        # ── 4. default (only when v === undefined) ───────────────────────────────
        if defnode is not None {
            _dm_dj: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
            _dm_dje: int = self._jump(Opcode.JUMP);
            self._patch(_dm_dj);
            self._op(Opcode.POP);  # [src]  (drop undefined)
            self.compile_expr(defnode);  # [src, defval]
            self._patch(_dm_dje);
        }
        # stack: [src, v]

        # ── 5. PutValue: obj[ToPropertyKey(targetKey)] = v ───────────────────────
        self._emit(make_instruction(Opcode.STORE_LOCAL, _dm_val_slot, 0, 0));  # [src]
        self._emit(make_instruction(Opcode.LOAD_LOCAL, _dm_obj_slot, 0, 0));  # [src, obj]
        if _dm_tgt_computed {
            self._emit(make_instruction(Opcode.LOAD_LOCAL, _dm_rkey_slot, 0, 0));  # [src, obj, rawtk]
            self._op(Opcode.TO_PROPERTY_KEY);  # [src, obj, tk]
            self._emit(make_instruction(Opcode.LOAD_LOCAL, _dm_val_slot, 0, 0));  # [src, obj, tk, v]
            self._emit(make_instruction(Opcode.SET_INDEX, 0, _dm_strict, 0));  # [src, v]
            self._op(Opcode.POP);  # [src]
        } else {
            # Private target `obj.#x` (ES §13.15.5): brand-check the object BEFORE the
            # write (throws TypeError if the class did not declare #x). Object is on top
            # (loaded above), matching _store_lvalue. The `this` read that would throw a
            # this-TDZ ReferenceError already happened in STEP 2 (compile of memtgt.object),
            # so an uninitialized `this` throws ReferenceError before this brand check.
            if memtgt.property is not None
                and self._is_private_name(memtgt.property.name) {
                self._emit(
                    make_instruction(
                        Opcode.CHECK_PRIVATE, self._intern(_dm_tgt_static), 2, 0
                    )
                );
            }
            self._emit(make_instruction(Opcode.LOAD_LOCAL, _dm_val_slot, 0, 0));  # [src, obj, v]
            _dm_sp_idx: int = self._intern_key(_dm_tgt_static);
            _dm_sp_enc: int = self._last_key_id << 1;  # define_own=0
            self._emit(
                make_instruction(Opcode.SET_PROP, _dm_sp_idx, _dm_strict, 0, _dm_sp_enc)
            );  # [src, v]
            self._op(Opcode.POP);  # [src]
        }
        return True;
    }

    """Emit the arithmetic/bitwise opcode for a compound-assignment operator core
    (the operator text with its trailing `=` already stripped, e.g. `*` or `>>>`)."""
    def _emit_binop(bin_op: str) {
        if bin_op == "+" {
            self._op(Opcode.ADD);
        } elif bin_op == "-" {
            self._op(Opcode.SUB);
        } elif bin_op == "*" {
            self._op(Opcode.MUL);
        } elif bin_op == "/" {
            self._op(Opcode.DIV);
        } elif bin_op == "%" {
            self._op(Opcode.MOD);
        } elif bin_op == "**" {
            self._op(Opcode.POW);
        } elif bin_op == "&" {
            self._op(Opcode.BAND);
        } elif bin_op == "|" {
            self._op(Opcode.BOR);
        } elif bin_op == "^" {
            self._op(Opcode.BXOR);
        } elif bin_op == "<<" {
            self._op(Opcode.SHL);
        } elif bin_op == ">>" {
            self._op(Opcode.SHR);
        } elif bin_op == ">>>" {
            self._op(Opcode.USHR);
        } else {
            self._op(Opcode.ADD);
        }
    }

    """True when a computed member key must be evaluated exactly once for a
    read-modify-write (ES §13.15.2 / §13.4).  Only a *literal* key is safe to
    re-materialize twice: its ToPropertyKey is a pure, side-effect-free constant.
    Any other key expression — including a bare identifier, whose *value* may be an
    object with a side-effecting `toString`/`valueOf`/`Symbol.toPrimitive` — must be
    coerced once, so we take the stash-in-local path."""
    def _computed_key_needs_once(lhs: ASTNode) -> bool {
        if lhs.property is None {
            return False;
        }
        if lhs.property.ntype == ASTNodeType.Literal {
            return False;
        }
        return True;
    }

    """True if `lhs` is a `super[expr]` / `super.x` member expression (needs the super
    assignment path, not the ordinary member path)."""
    def _lhs_is_super_member(lhs: ASTNode) -> bool {
        return lhs.ntype == ASTNodeType.MemberExpression
            and lhs.object is not None
            and lhs.object.ntype == ASTNodeType.Identifier
            and lhs.object.name == "super";
    }

    def _store_lvalue(lhs: ASTNode) {
        if lhs.ntype == ASTNodeType.Identifier {
            # ES §13.15.1 / §15.1.1: in strict mode, `eval` and `arguments` are not
            # valid assignment targets — an early SyntaxError.
            if self._fn().is_strict
                and (lhs.name == "eval" or lhs.name == "arguments") {
                self._syntax_error(
                    "SyntaxError: Unexpected eval or arguments in strict mode"
                );
            }
            if lhs.name in self.esm_import_bindings
                and not self._esm_name_is_shadowed(lhs.name) {
                # ECMAScript §10.4.6: import bindings are read-only. A shadowing
                # param/local of the same name is an ordinary mutable binding —
                # only the unshadowed import reference is a TypeError.
                self._emit_import_assign_error(lhs.name);
            } elif self.with_depth > 0 {
                # Inside a `with` body: defer the store to the VM, which checks the
                # with-object(s) before the lexical scope chain / globals. (A4)
                # arg2=1 in strict mode → an unresolvable store throws ReferenceError
                # (e.g. the with-object property was deleted mid-assignment).
                # Register the enclosing binding as a free var so a nested function
                # can write through to it when unshadowed (STORE_NAME step 3).
                _ = self._capture(lhs.name);
                _sn_strict: int = 1 if self._fn().is_strict else 0;
                self._emit(
                    make_instruction(
                        Opcode.STORE_NAME, self._intern(lhs.name), _sn_strict, 0
                    )
                );
            } elif self._is_esm_live(lhs.name)
                and not self._esm_name_is_shadowed(lhs.name) {
                # Inline (not via _emit_esm_live_store): expression context — value
                # must remain on the stack for the caller.  _emit_esm_live_store is
                # for statement context only and adds a trailing POP.
                self._emit(
                    make_instruction(
                        Opcode.LOAD_GLOBAL, self._intern(self.esm_exports_global), 0, 0
                    )
                );
                self._op(Opcode.SWAP);
                # define_own=1: privileged namespace export write (exotic [[Set]] → false).
                self._emit_set_prop(lhs.name, 0, 0, 1);
                # Refresh `export { name as alias }` bindings (reloads; keeps TOS value).
                self._emit_esm_alias_stores(lhs.name);
            } else {
                slot: int = self._resolve(lhs.name);
                if slot >= 0 {
                    sl_kind: str = self._get_kind(lhs.name);
                    if sl_kind == "const" {
                        self._emit_const_assign_error(lhs.name);
                    } elif sl_kind == "fnself" {
                        # Named function-expression self-name: immutable binding.
                        # Strict → TypeError; sloppy → silent no-op (discard the value;
                        # the DUP'd assignment result stays on the stack for the caller).
                        if self._fn().is_strict {
                            self._emit_const_assign_error(lhs.name);
                        } else {
                            self._op(Opcode.POP);
                        }
                    } else {
                        self._emit(make_instruction(Opcode.STORE_LOCAL, slot, 0, 0));
                        self._emit_esm_alias_stores(lhs.name);
                    }
                } else {
                    free_slot: int = self._capture(lhs.name);
                    if free_slot >= 0 {
                        fo_kind: str = self._get_outer_binding_kind(lhs.name);
                        if fo_kind == "const" {
                            self._emit_const_assign_error(lhs.name);
                        } elif fo_kind == "fnself" {
                            if self._fn().is_strict {
                                self._emit_const_assign_error(lhs.name);
                            } else {
                                self._op(Opcode.POP);
                            }
                        } else {
                            self._emit(
                                make_instruction(Opcode.STORE_FREE, free_slot, 0, 0)
                            );
                            self._emit_esm_alias_stores(lhs.name);
                        }
                    } elif self._fn().is_strict {
                        self._emit_strict_store_global(lhs.name);
                        self._emit_esm_alias_stores(lhs.name);
                    } else {
                        self._emit(
                            make_instruction(
                                Opcode.STORE_GLOBAL, self._intern(lhs.name), 0, 0
                            )
                        );
                        self._emit_esm_alias_stores(lhs.name);
                    }
                }
            }
        } elif lhs.ntype == ASTNodeType.MemberExpression
            and lhs.object is not None
            and lhs.object.ntype == ASTNodeType.Identifier
            and lhs.object.name == "super" {
            # `super.x = v` / `super[k] = v` (ES §13.3.7.1): [[Set]] on the super base
            # with receiver = the current `this`.  Stack on entry: [val].
            #   - GetSuperBase (LOAD_SUPER_PROTO) precedes ToPropertyKey of a computed
            #     key (observable side-effect order).
            #   - GetThisBinding (LOAD_THIS, which enforces this-TDZ in a derived ctor)
            #     also precedes the key — emit it before the key expression.
            if not self.super_prop_allowed {
                self._syntax_error("SyntaxError: 'super' keyword unexpected here");
            }
            self._emit(
                make_instruction(
                    Opcode.LOAD_SUPER_PROTO, 0, self._super_static_arg(), 0
                )
            );  # [val, base]
            if lhs.computed {
                self._op(Opcode.LOAD_THIS);  # [val, base, recv]
                if lhs.property is not None {
                    self.compile_expr(lhs.property);
                }  # [val, base, recv, key]
                self._op(Opcode.SWAP);  # [val, base, key, recv]
                self._op(Opcode.SUPER_SET_INDEX);  # [val]
            } elif lhs.property is not None {
                _ssp_idx: int = self._intern(self._prop_key(lhs.property.name));
                self._op(Opcode.LOAD_THIS);  # [val, base, recv]
                self._emit(make_instruction(Opcode.SUPER_SET_PROP, _ssp_idx, 0, 0));  # [val]
            }
        } elif lhs.ntype == ASTNodeType.MemberExpression {
            # Stack on entry: [val]  (RHS already compiled)
            # SET_PROP / SET_INDEX both push their result value, so no DUP needed.
            if lhs.object is not None {
                self.compile_expr(lhs.object);
            }
            # Stack: [val, obj]
            # Private write (`obj.#x = v`) — brand-check the object (which is on
            # top here, before the SWAP) so writing a private field/accessor on an
            # object whose class did not declare it throws TypeError (ES §13.15.5).
            if not lhs.computed
                and lhs.property is not None
                and self._is_private_name(lhs.property.name) {
                _sp_priv: int = self._intern(self._prop_key(lhs.property.name));
                self._emit(make_instruction(Opcode.CHECK_PRIVATE, _sp_priv, 2, 0));
            }
            self._op(Opcode.SWAP);
            # Stack: [obj, val]
            # arg2 = strict flag: in strict mode a failed [[Set]] (non-writable data
            # property own or inherited, accessor without a setter) is a TypeError
            # (ES §6.2.5.6 PutValue); sloppy mode is a silent no-op.
            _sp_strict: int = 1 if self._fn().is_strict else 0;
            if lhs.computed {
                if lhs.property is not None {
                    self.compile_expr(lhs.property);
                }
                # Stack: [obj, val, key]
                self._op(Opcode.SWAP);
                # Stack: [obj, key, val]
                self._emit(make_instruction(Opcode.SET_INDEX, 0, _sp_strict, 0));
                # Stack: [val]  (SET_INDEX pops val/key/obj, pushes val)
            } else {
                if lhs.property is not None {
                    _sp_idx: int = self._intern_key(self._prop_key(lhs.property.name));
                    _sp_enc: int = self._last_key_id << 1;  # define_own=0
                    self._emit(
                        make_instruction(
                            Opcode.SET_PROP, _sp_idx, _sp_strict, 0, _sp_enc
                        )
                    );
                }
                # Stack: [val]  (SET_PROP pops val/obj, pushes val)
            }
        } elif lhs.ntype == ASTNodeType.ObjectExpression {
            # Assignment destructuring: ({ key: target, ... } = rhs)
            # Stack on entry: [src_obj]  (caller DUPed the original RHS)
            # RequireObjectCoercible: `({a} = null)` must throw TypeError before reads.
            self._op(Opcode.REQUIRE_COERCIBLE);
            # Track statically-known keys already destructured so an `...rest` target
            # can copy the source minus them (mirrors compile_obj_pattern).
            oad_extracted: list[str] = [];
            # Computed keys (`{[a]: t, ...rest}`) are runtime values: the key
            # expression is evaluated once (spec order) and stashed in a temp local
            # so the `...rest` copy can exclude it via a computed DELETE.
            oad_comp_slots: list[int] = [];
            for oad_prop in lhs.properties {
                if oad_prop.ntype == ASTNodeType.RestElement
                    or oad_prop.ntype == ASTNodeType.SpreadElement {
                    # `({a, ...rest} = obj)` — build rest = OwnPropertyKeys(src) minus the
                    # already-extracted keys, as a fresh object (ES §14.3.3.1 /
                    # CopyDataProperties).  Stack has [src_obj]; leave it for the final POP.
                    self._op(Opcode.DUP);  # [src, src]
                    self._op(Opcode.NEW_OBJECT);  # [src, src, {}]
                    self._op(Opcode.SWAP);  # [src, {}, src]
                    # CopyDataProperties(excludedItems): statically-known extracted
                    # keys are FILTERED from the copy (their getters must not fire
                    # again) via arg2 = 1 + constant index of "\x1f"-joined names.
                    _oad_excl_arg: int = 0;
                    if len(oad_extracted) > 0 {
                        _oad_joined: str = "";
                        _oad_i: int = 0;
                        while _oad_i < len(oad_extracted) {
                            if _oad_i > 0 {
                                _oad_joined = _oad_joined + "\x1f";
                            }
                            _oad_joined = _oad_joined + oad_extracted[_oad_i];
                            _oad_i = _oad_i + 1;
                        }
                        _oad_excl_arg = self._intern(_oad_joined) + 1;
                    }
                    self._emit(
                        make_instruction(Opcode.OBJECT_SPREAD, 0, _oad_excl_arg, 0)
                    );  # [src, rest]
                    # Exclude previously-listed computed keys via computed DELETE.
                    for oad_cs in oad_comp_slots {
                        self._op(Opcode.DUP);  # [.., rest, rest]
                        self._emit(make_instruction(Opcode.LOAD_LOCAL, oad_cs, 0, 0));  # [.., rest, rest, key]
                        self._op(Opcode.DELETE);  # [.., rest, delres]
                        self._op(Opcode.POP);  # [.., rest]
                    }
                    # Store the rest object into the target (identifier or member expr).
                    # _store_lvalue pops for identifiers but leaves the value on the
                    # stack for a MemberExpression (SET_PROP/SET_INDEX push their result).
                    oad_rtgt: ASTNode | None = oad_prop.argument;
                    if oad_rtgt is not None {
                        self._store_lvalue(oad_rtgt);
                        if oad_rtgt.ntype == ASTNodeType.MemberExpression {
                            self._op(Opcode.POP);
                        }
                    } else {
                        self._op(Opcode.POP);
                    }
                } else {
                    # A plain (non-super, non-private) MemberExpression target requires the
                    # target reference to be evaluated BEFORE the source get (ES §13.15.5.6 —
                    # test262 keyed-destructuring-property-reference-target-evaluation-order).
                    # Route those through the ordered helper; everything else keeps the
                    # simpler get-then-store path below.
                    oad_pre: ASTNode | None = oad_prop.expression;
                    oad_pre_inner: ASTNode | None = oad_pre;
                    oad_pre_def: ASTNode | None = None;
                    if oad_pre is not None
                        and (
                            oad_pre.ntype == ASTNodeType.AssignmentPattern
                            or (
                                oad_pre.ntype == ASTNodeType.AssignmentExpression
                                and oad_pre.operator == "="
                            )
                        ) {
                        oad_pre_inner = oad_pre.left;
                        oad_pre_def = oad_pre.right;
                    }
                    oad_is_mem: bool = False;
                    if oad_pre_inner is not None
                        and oad_pre_inner.ntype == ASTNodeType.MemberExpression
                        and oad_pre_inner.object is not None
                        and not oad_prop.shorthand {
                        oad_is_mem = True;
                        if oad_pre_inner.object.ntype == ASTNodeType.Identifier
                            and oad_pre_inner.object.name == "super" {
                            oad_is_mem = False;
                        }
                    }
                    oad_mem_done: bool = False;
                    if oad_is_mem and oad_pre_inner is not None {
                        oad_mem_done = self._compile_dstr_member_prop(
                            oad_prop,
                            oad_pre_inner,
                            oad_pre_def,
                            oad_extracted,
                            oad_comp_slots
                        );
                    }
                    if not oad_mem_done {
                        if oad_prop.computed and oad_prop.key is not None {
                            self._op(Opcode.DUP);  # [src, src]
                            self.compile_expr(oad_prop.key);  # [src, src, key]
                            # Stash the key in a temp so a later `...rest` can DELETE it
                            # (and so the key expression is evaluated exactly once).
                            oad_ckey_name: str = "__dstrckey_"
                                + str(self._dstr_iter_seq);
                            self._dstr_iter_seq = self._dstr_iter_seq + 1;
                            oad_ckey_slot: int = self._declare(oad_ckey_name, "const");
                            if oad_ckey_slot >= 0 {
                                self._op(Opcode.DUP);  # [src, src, key, key]
                                self._emit(
                                    make_instruction(
                                        Opcode.STORE_LOCAL, oad_ckey_slot, 0, 0
                                    )
                                );  # [src, src, key]
                                oad_comp_slots.append(oad_ckey_slot);
                            }
                            self._op(Opcode.GET_INDEX);  # [src, val]
                        } else {
                            # Identifier keys use .name; Literal (numeric/string) keys .value.
                            oad_key: str = "";
                            if oad_prop.key is not None {
                                if oad_prop.key.ntype == ASTNodeType.Literal {
                                    oad_key = oad_prop.key.value;
                                } else {
                                    oad_key = oad_prop.key.name;
                                }
                            }
                            oad_extracted.append(oad_key);
                            self._op(Opcode.DUP);
                            if oad_key == "__proto__" {
                                # A destructuring pattern `{ __proto__: t }` reads the ORDINARY
                                # property named "__proto__" — it is NOT the object-literal
                                # prototype special form (Annex B), so duplicates are allowed
                                # (test262 obj-prop-__proto__dup). Use GET_INDEX (plain [[Get]]),
                                # which honours an own "__proto__" data property, rather than
                                # GET_PROP whose static-key path resolves the __proto__ accessor.
                                self._const("__proto__");  # [src, src, "__proto__"]
                                self._op(Opcode.GET_INDEX);  # [src, val]
                            } else {
                                oad_kidx: int = self._intern(oad_key);
                                self._emit(
                                    make_instruction(Opcode.GET_PROP, oad_kidx, 0, 0)
                                );
                            }
                        }
                        oad_tgt: ASTNode | None = None;
                        if not oad_prop.shorthand {
                            oad_tgt = oad_prop.expression;
                        } elif oad_prop.expression is not None
                            and oad_prop.expression.ntype
                                == ASTNodeType.AssignmentPattern {
                            # Shorthand with default: `{ x = default }` — the value node
                            # carries the AssignmentPattern; the key alone loses the default.
                            oad_tgt = oad_prop.expression;
                        } else {
                            oad_tgt = oad_prop.key;
                        }
                        if oad_tgt is not None
                            and (
                                oad_tgt.ntype == ASTNodeType.AssignmentPattern
                                or (
                                    oad_tgt.ntype == ASTNodeType.AssignmentExpression
                                    and oad_tgt.operator == "="
                                )
                            ) {
                            # Default value: ({k: x = default} = …) or shorthand ({x = default} = …).
                            # Stack: [extracted_val]. Substitute default when undefined.
                            oad_dj: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
                            oad_dje: int = self._jump(Opcode.JUMP);
                            self._patch(oad_dj);
                            self._op(Opcode.POP);
                            if oad_tgt.right is not None {
                                self.compile_expr(oad_tgt.right);
                                # NamedEvaluation: `({x = function(){}} = …)` names the default.
                                if oad_tgt.left is not None
                                    and oad_tgt.left.ntype == ASTNodeType.Identifier {
                                    self._maybe_infer_fn_name(
                                        oad_tgt.right, oad_tgt.left.name
                                    );
                                }
                            } else {
                                self._op(Opcode.LOAD_UNDEFINED);
                            }
                            self._patch(oad_dje);
                            if oad_tgt.left is not None {
                                self._store_lvalue(oad_tgt.left);
                                if oad_tgt.left.ntype == ASTNodeType.MemberExpression {
                                    self._op(Opcode.POP);
                                }
                            } else {
                                self._op(Opcode.POP);
                            }
                        } elif oad_tgt is not None {
                            self._store_lvalue(oad_tgt);
                            if oad_tgt.ntype == ASTNodeType.MemberExpression {
                                self._op(Opcode.POP);
                            }
                        } else {
                            self._op(Opcode.POP);
                        }
                    }  # end: if not oad_mem_done
                }
            }
            self._op(Opcode.POP);  # pop src_obj; original RHS stays on stack from caller's DUP
        } elif lhs.ntype == ASTNodeType.ArrayExpression {
            # Assignment destructuring: [a, b] = rhs  (no declaration keyword)
            # Stack on entry: [src_arr]  (caller DUPed the original RHS)
            self._op(Opcode.GET_ITER);
            # IteratorClose (§7.4.11) on normal/abrupt completion — see the mirror
            # logic in compile_arr_pattern. Stash the iterator record in a local so
            # the abrupt handler can reach it past any transient stack values.
            aad_iter_name: str = "__dstriter_" + str(self._dstr_iter_seq);
            self._dstr_iter_seq = self._dstr_iter_seq + 1;
            # Current-scope lexical slot (see the rationale in compile_arr_pattern).
            aad_iter_slot: int = self._declare(aad_iter_name, "const");
            aad_use_close: bool = aad_iter_slot >= 0;
            aad_catch_jmp: int = -1;
            if aad_use_close {
                self._op(Opcode.DUP);
                self._emit(make_instruction(Opcode.STORE_LOCAL, aad_iter_slot, 0, 0));
                aad_catch_jmp = self._jump(Opcode.PUSH_CATCH);
            }
            for aad_elem in lhs.elements {
                if aad_elem is None or aad_elem.ntype == ASTNodeType.Elision {
                    # Elision: advance the iterator one step and discard the value.
                    # In an assignment LHS (ArrayExpression) a hole is an Elision node,
                    # not a Python None (unlike the binding ArrayPattern), so both
                    # forms must be recognised — otherwise the hole falls through to
                    # the generic element path, which tries to _store_lvalue an
                    # Elision and skips the trailing IteratorClose.
                    self._op(Opcode.ITER_NEXT_VAL);
                    self._op(Opcode.POP);
                } elif aad_elem.ntype == ASTNodeType.RestElement
                    or aad_elem.ntype == ASTNodeType.SpreadElement {
                    # ...rest element — collect remaining into array.  In a plain
                    # assignment statement the LHS parses as an ArrayExpression, so
                    # the spread arrives as SpreadElement (not RestElement); handle
                    # both.  Per ES §13.15.5.5 the rest target may itself be a
                    # destructuring assignment pattern (`[...[x, y]] = a`).
                    if aad_elem.argument is not None
                        and aad_elem.argument.ntype == ASTNodeType.MemberExpression {
                        # AssignmentRestElement with a MemberExpression target
                        # (ES §13.15.5.4): the target *reference* is evaluated BEFORE
                        # IteratorStep, so `[...{}[thrower()]] = it` throws before
                        # `next()` runs and triggers IteratorClose.  REST_ARGS needs
                        # the iterator record at TOS, so stash obj/key in temp locals.
                        aad_rm: ASTNode = aad_elem.argument;
                        _aad_robj_slot: int = self._declare(
                            "__dstrrobj_" + str(self._dstr_iter_seq), "const"
                        );
                        self._dstr_iter_seq = self._dstr_iter_seq + 1;
                        if aad_rm.object is not None {
                            self.compile_expr(aad_rm.object);
                        }  # [.., obj]
                        # Private write `[...this.#x] = it` — brand-check before stepping.
                        if not aad_rm.computed
                            and aad_rm.property is not None
                            and self._is_private_name(aad_rm.property.name) {
                            _aad_rpriv: int = self._intern(
                                self._prop_key(aad_rm.property.name)
                            );
                            self._emit(
                                make_instruction(Opcode.CHECK_PRIVATE, _aad_rpriv, 2, 0)
                            );
                        }
                        self._emit(
                            make_instruction(Opcode.STORE_LOCAL, _aad_robj_slot, 0, 0)
                        );  # []
                        _aad_rkey_slot: int = -1;
                        if aad_rm.computed {
                            _aad_rkey_slot = self._declare(
                                "__dstrrkey_" + str(self._dstr_iter_seq), "const"
                            );
                            self._dstr_iter_seq = self._dstr_iter_seq + 1;
                            if aad_rm.property is not None {
                                self.compile_expr(aad_rm.property);
                            }  # [.., key]
                            self._emit(
                                make_instruction(
                                    Opcode.STORE_LOCAL, _aad_rkey_slot, 0, 0
                                )
                            );  # []
                        }
                        self._op(Opcode.REST_ARGS);  # [iter, rest]
                        if aad_rm.computed {
                            self._emit(
                                make_instruction(
                                    Opcode.LOAD_LOCAL, _aad_robj_slot, 0, 0
                                )
                            );  # [iter, rest, obj]
                            self._op(Opcode.SWAP);  # [iter, obj, rest]
                            self._emit(
                                make_instruction(
                                    Opcode.LOAD_LOCAL, _aad_rkey_slot, 0, 0
                                )
                            );  # [iter, obj, rest, key]
                            self._op(Opcode.SWAP);  # [iter, obj, key, rest]
                            self._op(Opcode.SET_INDEX);  # [iter, rest]
                            self._op(Opcode.POP);  # [iter]
                        } else {
                            self._emit(
                                make_instruction(
                                    Opcode.LOAD_LOCAL, _aad_robj_slot, 0, 0
                                )
                            );  # [iter, rest, obj]
                            self._op(Opcode.SWAP);  # [iter, obj, rest]
                            if aad_rm.property is not None {
                                _aad_rpidx: int = self._intern(
                                    self._prop_key(aad_rm.property.name)
                                );
                                self._emit(
                                    make_instruction(Opcode.SET_PROP, _aad_rpidx, 0, 0)
                                );  # [iter, rest]
                            }
                            self._op(Opcode.POP);  # [iter]
                        }
                    } else {
                        self._op(Opcode.REST_ARGS);
                        if aad_elem.argument is not None {
                            if aad_elem.argument.ntype == ASTNodeType.ArrayExpression
                                or aad_elem.argument.ntype
                                    == ASTNodeType.ObjectExpression {
                                # Nested destructuring assignment target: _store_lvalue
                                # consumes a DUPed copy and leaves the original for us to POP.
                                self._op(Opcode.DUP);
                                self._store_lvalue(aad_elem.argument);
                                self._op(Opcode.POP);
                            } else {
                                self._store_lvalue(aad_elem.argument);
                            }
                        } else {
                            self._op(Opcode.POP);
                        }
                    }
                } elif aad_elem.ntype == ASTNodeType.AssignmentPattern
                    or (
                        aad_elem.ntype == ASTNodeType.AssignmentExpression
                        and aad_elem.operator == "="
                    ) {
                    # Default value: [a = default] = ...   In expression context the
                    # element parses as an AssignmentExpression("="), not an
                    # AssignmentPattern; both share .left/.right and mean the same here.
                    self._op(Opcode.ITER_NEXT_VAL);
                    aad_j: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
                    aad_je: int = self._jump(Opcode.JUMP);
                    self._patch(aad_j);
                    self._op(Opcode.POP);
                    if aad_elem.right is not None {
                        self.compile_expr(aad_elem.right);
                        # NamedEvaluation (ES §13.15.5.4): `[fn = function(){}] = …`
                        # names the anonymous default after the identifier target.
                        if aad_elem.left is not None
                            and aad_elem.left.ntype == ASTNodeType.Identifier {
                            self._maybe_infer_fn_name(
                                aad_elem.right, aad_elem.left.name
                            );
                        }
                    } else {
                        self._op(Opcode.LOAD_UNDEFINED);
                    }
                    self._patch(aad_je);
                    if aad_elem.left is not None {
                        self._store_lvalue(aad_elem.left);
                        # MemberExpression leaves value on stack; clean it up in destructuring context.
                        if aad_elem.left.ntype == ASTNodeType.MemberExpression {
                            self._op(Opcode.POP);
                        }
                    } else {
                        self._op(Opcode.POP);
                    }
                } elif aad_elem.ntype == ASTNodeType.ArrayExpression {
                    # Nested array destructuring assignment
                    self._op(Opcode.ITER_NEXT_VAL);
                    self._op(Opcode.DUP);
                    self._store_lvalue(aad_elem);
                    self._op(Opcode.POP);
                } elif aad_elem.ntype == ASTNodeType.ObjectExpression {
                    # Nested object destructuring assignment
                    self._op(Opcode.ITER_NEXT_VAL);
                    self._op(Opcode.DUP);
                    self._store_lvalue(aad_elem);
                    self._op(Opcode.POP);
                } elif aad_elem.ntype == ASTNodeType.MemberExpression {
                    # AssignmentElement with a MemberExpression target (ES §13.15.5.3):
                    # the *target reference* must be evaluated BEFORE IteratorStep, so a
                    # throwing base/key (`[ {}[thrower()] ] = it`) aborts before `next()`
                    # runs and triggers IteratorClose.  ITER_NEXT_VAL requires the
                    # iterator record at TOS, so we can't leave obj/key stacked above
                    # it — stash the evaluated reference in temp locals, step the
                    # iterator, then reload obj/key to SET.
                    _aad_obj_slot: int = self._declare(
                        "__dstrmobj_" + str(self._dstr_iter_seq), "const"
                    );
                    self._dstr_iter_seq = self._dstr_iter_seq + 1;
                    if aad_elem.object is not None {
                        self.compile_expr(aad_elem.object);
                    }  # [.., obj]
                    # Private write `[this.#x] = it` — brand-check the object (still on
                    # TOS) so a missing private field throws TypeError *before* the
                    # iterator is stepped (ES §13.15.5.3 / §13.15.5).
                    if not aad_elem.computed
                        and aad_elem.property is not None
                        and self._is_private_name(aad_elem.property.name) {
                        _aad_priv: int = self._intern(
                            self._prop_key(aad_elem.property.name)
                        );
                        self._emit(
                            make_instruction(Opcode.CHECK_PRIVATE, _aad_priv, 2, 0)
                        );
                    }
                    self._emit(
                        make_instruction(Opcode.STORE_LOCAL, _aad_obj_slot, 0, 0)
                    );  # []
                    _aad_key_slot: int = -1;
                    if aad_elem.computed {
                        _aad_key_slot = self._declare(
                            "__dstrmkey_" + str(self._dstr_iter_seq), "const"
                        );
                        self._dstr_iter_seq = self._dstr_iter_seq + 1;
                        if aad_elem.property is not None {
                            self.compile_expr(aad_elem.property);
                        }  # [.., key]
                        self._emit(
                            make_instruction(Opcode.STORE_LOCAL, _aad_key_slot, 0, 0)
                        );  # []
                    }
                    # Iterator record is at TOS again (nothing pushed above it).
                    self._op(Opcode.ITER_NEXT_VAL);  # [iter, val]
                    if aad_elem.computed {
                        # Want [iter, obj, key, val] for SET_INDEX (val=pop, key=pop, obj=pop).
                        self._emit(
                            make_instruction(Opcode.LOAD_LOCAL, _aad_obj_slot, 0, 0)
                        );  # [iter, val, obj]
                        self._op(Opcode.SWAP);  # [iter, obj, val]
                        self._emit(
                            make_instruction(Opcode.LOAD_LOCAL, _aad_key_slot, 0, 0)
                        );  # [iter, obj, val, key]
                        self._op(Opcode.SWAP);  # [iter, obj, key, val]
                        self._op(Opcode.SET_INDEX);  # [iter, val]
                        self._op(Opcode.POP);  # [iter]
                    } else {
                        self._emit(
                            make_instruction(Opcode.LOAD_LOCAL, _aad_obj_slot, 0, 0)
                        );  # [iter, val, obj]
                        self._op(Opcode.SWAP);  # [iter, obj, val]
                        if aad_elem.property is not None {
                            _aad_pidx: int = self._intern(
                                self._prop_key(aad_elem.property.name)
                            );
                            self._emit(
                                make_instruction(Opcode.SET_PROP, _aad_pidx, 0, 0)
                            );  # [iter, val]
                        }
                        self._op(Opcode.POP);  # [iter]
                    }
                } else {
                    self._op(Opcode.ITER_NEXT_VAL);
                    self._store_lvalue(aad_elem);
                }
            }
            if aad_use_close {
                # Normal completion: exit the catch region, close the iterator if
                # not exhausted (ITER_CLOSE_NRML pops the on-stack iterator record).
                self._op(Opcode.POP_CATCH);
                self._op(Opcode.ITER_CLOSE_NRML);
                aad_skip_thrw: int = self._jump(Opcode.JUMP);
                self._patch(aad_catch_jmp);
                self._emit(make_instruction(Opcode.LOAD_LOCAL, aad_iter_slot, 0, 0));  # [exc, iter]
                self._op(Opcode.ITER_CLOSE_THRW);
                self._patch(aad_skip_thrw);
            } else {
                self._op(Opcode.POP);  # pop the iterator
            }
            # original RHS stays on stack from caller's DUP
        }
    }

    # ── update (++ / --) ───────────────────────────────────────────────────

    def compile_update(nd: ASTNode) -> None {
        if nd.argument is None {
            return;
        }
        arg: ASTNode = nd.argument;
        op: str = nd.operator;
        # ES §13.4: `x++`/`x--` are NUMERIC: oldValue = ToNumeric(x); newValue =
        # oldValue ±1; the postfix result is oldValue (already coerced). Implement the
        # step with SUB (which does ToNumeric and never string-concatenates like ADD, and
        # keeps BigInt operands BigInt via the arg2=1 unit): `++` subtracts -1, `--`
        # subtracts 1. `SUB 0` (arg2=1) is a BigInt-safe ToNumeric used to coerce the old
        # value for the postfix result and the stored operand.
        up_unit: str = "n:-1" if op == "++" else "n:1";
        # For MemberExpression targets, _store_lvalue leaves the stored value on
        # the stack (SET_PROP/SET_INDEX push their result).  For Identifier targets,
        # STORE_LOCAL/STORE_GLOBAL pop the value.  The DUP strategy must account
        # for this difference.
        is_member: bool = arg.ntype == ASTNodeType.MemberExpression;
        # `++super[key]` / `super[key]++` (computed super property update): the ordinary
        # computed-member path below would compile `super` as a bare identifier ("super is
        # not defined"). Route through the SUPER opcodes instead, evaluating the key once.
        if is_member
            and arg.computed
            and self._lhs_is_super_member(arg)
            and self._compile_super_computed_update(nd, arg, up_unit) {
            return;
        }
        # Computed member update (`base[prop]++`): ToPropertyKey(prop) must run once
        # (ES §13.4.4/5).  Evaluate base+key once, stash both in synthetic locals, and
        # reuse them for the read and write — mirrors the compound-assignment path.
        # Only for keys whose coercion may be observable (see _computed_key_needs_once).
        if is_member and arg.computed and self._computed_key_needs_once(arg) {
            _up_seq: int = self._dstr_iter_seq;
            self._dstr_iter_seq = self._dstr_iter_seq + 1;
            _up_oslot: int = self._declare("__upobj_" + str(_up_seq), "const");
            _up_kslot: int = self._declare("__upkey_" + str(_up_seq), "const");
            _up_vslot: int = self._declare("__upold_" + str(_up_seq), "const");
            if _up_oslot >= 0 and _up_kslot >= 0 and _up_vslot >= 0 {
                # Evaluate base and ToPropertyKey(prop) once, stash both in locals.
                # Spec order: base, key EXPRESSION, RequireObjectCoercible(base),
                # ToPropertyKey — so `prop()` runs even for a nullish base but
                # `prop.toString` runs only after the null check throws.
                if arg.object is not None {
                    self.compile_expr(arg.object);
                }  # [obj]
                self._emit(make_instruction(Opcode.STORE_LOCAL, _up_oslot, 0, 0));  # []
                if arg.property is not None {
                    self.compile_expr(arg.property);
                }  # [rawkey]
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _up_oslot, 0, 0));  # [rawkey, obj]
                self._op(Opcode.REQUIRE_COERCIBLE);  # throws if obj nullish
                self._op(Opcode.POP);  # [rawkey]
                self._op(Opcode.TO_PROPERTY_KEY);  # [key]
                self._emit(make_instruction(Opcode.STORE_LOCAL, _up_kslot, 0, 0));  # []
                # Lay out the write operands (obj, key) first so `new` ends up on top
                # as SET_INDEX wants [obj, key, val].
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _up_oslot, 0, 0));  # [obj]
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _up_kslot, 0, 0));  # [obj, key]
                # cur = obj[key]  — re-load obj/key for the read.
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _up_oslot, 0, 0));
                self._emit(make_instruction(Opcode.LOAD_LOCAL, _up_kslot, 0, 0));  # [obj, key, obj, key]
                self._op(Opcode.GET_INDEX);  # [obj, key, cur]
                self._const("n:0");
                self._emit(make_instruction(Opcode.SUB, 0, 1, 0));  # [obj, key, numcur]  ToNumeric
                if not nd.prefix {
                    # Postfix result is the ToNumeric-coerced OLD value; stash it.
                    self._op(Opcode.DUP);  # [obj, key, numcur, numcur]
                    self._emit(make_instruction(Opcode.STORE_LOCAL, _up_vslot, 0, 0));  # [obj, key, numcur]
                }
                self._const(up_unit);
                self._emit(make_instruction(Opcode.SUB, 0, 1, 0));  # [obj, key, new]
                self._op(Opcode.SET_INDEX);  # [new]
                if not nd.prefix {
                    self._op(Opcode.POP);  # drop new
                    self._emit(make_instruction(Opcode.LOAD_LOCAL, _up_vslot, 0, 0));  # [old]
                }
                return;
            }
        }
        # Update to a bare identifier inside `with`: resolve the reference ONCE (ES
        # §13.15.2) via LOAD_NAME_REF / STORE_NAME_REF so a getter that deletes the
        # with-binding mid-read cannot re-target the write (test262 postfix/prefix
        # -increment/-decrement S11.3.1_A5 / S11.4.x).
        if arg.ntype == ASTNodeType.Identifier and self.with_depth > 0 {
            up_name_arg: int = self._intern(arg.name);
            up_strict: int = 1 if self._fn().is_strict else 0;
            # Register the enclosing-scope binding as a free var so LOAD_NAME/STORE_NAME
            # (via LOAD_NAME_REF) can resolve it at runtime when no with-object shadows it
            # — mirrors compile_identifier's with-path.  Needed for a direct-eval-forced
            # dynamic body reading/writing an outer binding, e.g. `outer++` in a fn that
            # also contains a direct eval (test262 …reassign-fn-name-in-body-in-eval reads
            # an outer `let callCount`).
            _ = self._capture(arg.name);
            if nd.prefix {
                # [base, val] → [base, new] → store → [new]  (result = new value)
                self._emit(make_instruction(Opcode.LOAD_NAME_REF, up_name_arg, 0, 0));
                self._const(up_unit);
                self._emit(make_instruction(Opcode.SUB, 0, 1, 0));
                self._emit(
                    make_instruction(Opcode.STORE_NAME_REF, up_name_arg, up_strict, 0)
                );
            } else {
                # Postfix: result is the numeric OLD value. Stash it in a temp local so
                # only [base, new] reaches STORE_NAME_REF, then reload the old value.
                up_seq2: int = self._dstr_iter_seq;
                self._dstr_iter_seq = self._dstr_iter_seq + 1;
                up_old_slot: int = self._declare("__upwith_" + str(up_seq2), "const");
                self._emit(make_instruction(Opcode.LOAD_NAME_REF, up_name_arg, 0, 0));  # [base, val]
                # ToNumeric(old) via `val - 0` (arg2=1 keeps a BigInt a BigInt), then stash.
                self._const("n:0");
                self._emit(make_instruction(Opcode.SUB, 0, 1, 0));  # [base, oldNum]
                if up_old_slot >= 0 {
                    self._op(Opcode.DUP);  # [base, oldNum, oldNum]
                    self._emit(make_instruction(Opcode.STORE_LOCAL, up_old_slot, 0, 0));  # [base, oldNum]
                }
                self._const(up_unit);
                self._emit(make_instruction(Opcode.SUB, 0, 1, 0));  # [base, new]
                self._emit(
                    make_instruction(Opcode.STORE_NAME_REF, up_name_arg, up_strict, 0)
                );  # [new]
                self._op(Opcode.POP);  # []
                if up_old_slot >= 0 {
                    self._emit(make_instruction(Opcode.LOAD_LOCAL, up_old_slot, 0, 0));  # [oldNum]
                } else {
                    self._op(Opcode.LOAD_UNDEFINED);
                }
            }
            return;
        }
        if nd.prefix {
            # Prefix: result is the NEW value = ToNumeric(x) ± 1 (SUB coerces the operand).
            self.compile_expr(arg);
            self._const(up_unit);
            self._emit(make_instruction(Opcode.SUB, 0, 1, 0));
            if not is_member {
                # STORE_LOCAL pops — DUP first so new value stays on stack as result.
                self._op(Opcode.DUP);
            }
            self._store_lvalue(arg);
            # For MemberExpression: _store_lvalue leaves [new_val] on stack — correct.
            # For Identifier: DUP + STORE_LOCAL → [new_val] on stack — correct.
        } else {
            # Postfix: result is the OLD value, ToNumeric-coerced (§13.4.2 step 3).
            self.compile_expr(arg);  # [rawold]
            self._const("n:0");
            self._emit(make_instruction(Opcode.SUB, 0, 1, 0));  # [numold]  ToNumeric(old)
            self._op(Opcode.DUP);  # [numold, numold]
            self._const(up_unit);
            self._emit(make_instruction(Opcode.SUB, 0, 1, 0));  # [numold, new]
            self._store_lvalue(arg);
            if is_member {
                # _store_lvalue left [new_val] on stack; pop it so only [old_val] remains.
                self._op(Opcode.POP);
            }
            # For Identifier: STORE_LOCAL popped new_val — [old_val] is correct already.
        }
    }

    # ── call ───────────────────────────────────────────────────────────────

    def compile_call(nd: ASTNode) -> None {
        if nd.callee is None {
            return;
        }
        callee: ASTNode = nd.callee;
        argc: int = len(nd.arguments);
        # Spread flag (call_path_impl_plan Phase 1): arg3 bit 3 on every
        # call-family opcode. When clear the VM skips _expand_spreads —
        # the unconditional scan cost a has_own probe per object argument
        # per call. Bits 0-2 of CALL/TAIL_CALL arg3 stay the direct-eval
        # params; the flag composes with them.
        _sp_fl: int = 0;
        for _sp_a in nd.arguments {
            if _sp_a.ntype == ASTNodeType.SpreadElement {
                _sp_fl = 8;
            }
        }
        # Capture-and-clear the tail-call request for THIS call (so nested calls in the
        # callee/arguments don't inherit it). Only a plain `f(...)` CALL or `obj.f(...)`/
        # `expr()(...)` CALL_METHOD path honors it; super()/import()/optional-chain do not.
        _is_tail: bool = self._emit_tail_call;
        self._emit_tail_call = False;
        # ── dynamic import() → IMPORT opcode (returns namespace wrapped in Promise)
        if callee.ntype == ASTNodeType.Identifier and callee.name == "import" {
            # import("specifier", options?) — compile the argument, emit DYNAMIC_IMPORT.
            # The merged PARSER represents `import.source(...)` / `import.defer(...)`
            # as a Call node with callee=Identifier("import") and `nd.kind` set to
            # "source"/"defer" (NOT a MetaProperty), so the phase is read from
            # nd.kind here: "" = normal, "source" = source-phase, "defer" = defer.
            # Phase is passed in arg1 (0/1/2); arg2 signals an options object is on
            # the stack above the specifier (import attributes / options, §13.3.10.1).
            if argc > 0 {
                self.compile_expr(nd.arguments[0]);
            } else {
                self._op(Opcode.LOAD_UNDEFINED);
            }
            # Optional 2nd argument (import attributes / options object). Compile it so
            # its evaluation + side-effects run in source order (after the specifier);
            # a throw during its evaluation propagates synchronously. The VM validates
            # (non-object → reject) and reads options.with.
            _di_has_opts: int = 0;
            if argc > 1 {
                self.compile_expr(nd.arguments[1]);
                _di_has_opts = 1;
            }
            _di_phase: int = 0;
            if nd.kind == "source" {
                _di_phase = 1;
            } elif nd.kind == "defer" {
                _di_phase = 2;
            }
            self._emit(
                make_instruction(
                    Opcode.DYNAMIC_IMPORT, _di_phase, _di_has_opts, nd.loc.line
                )
            );
            return;
        }
        # ── super() ── call super constructor
        if callee.ntype == ASTNodeType.Identifier and callee.name == "super" {
            # B9: `super()` is only valid inside a derived class constructor.
            if not self.super_call_allowed {
                self._syntax_error("SyntaxError: 'super' keyword unexpected here");
            }
            for arg in nd.arguments {
                self.compile_expr(arg);
            }
            self._emit(make_instruction(Opcode.SUPER_CALL, argc, 0, 0, _sp_fl));
        } elif callee.ntype == ASTNodeType.MemberExpression {
            # Check for super.method(args)
            is_super_method: bool = False;
            if callee.object is not None and callee.property is not None {
                if callee.object.ntype == ASTNodeType.Identifier {
                    if callee.object.name == "super" {
                        is_super_method = True;
                    }
                }
            }
            if is_super_method and callee.property is not None {
                # B9: `super.method()` / `super[expr]()` needs a method/accessor home
                # object.  The method is looked up on the super base but invoked with
                # this = the current method's `this` (via SUPER_GET_* which pushes the
                # receiver), so a getter/method sees the right receiver.
                if not self.super_prop_allowed {
                    self._syntax_error("SyntaxError: 'super' keyword unexpected here");
                }
                # LOAD_SUPER_PROTO; [key]; LOAD_THIS; SUPER_GET_*; LOAD_THIS; args; CALL_METHOD
                # arg2=1 in a static method → super resolves against the super class itself.
                self._emit(
                    make_instruction(
                        Opcode.LOAD_SUPER_PROTO,
                        0,
                        self._super_static_arg(),
                        nd.loc.line
                    )
                );
                if callee.computed {
                    self.compile_expr(callee.property);
                    self._op(Opcode.LOAD_THIS);
                    self._op(Opcode.SUPER_GET_INDEX);
                } else {
                    _sm_key: int = self._intern(self._prop_key(callee.property.name));
                    self._op(Opcode.LOAD_THIS);
                    self._emit(
                        make_instruction(Opcode.SUPER_GET_PROP, _sm_key, 0, nd.loc.line)
                    );
                }
                self._op(Opcode.LOAD_THIS);
                for arg in nd.arguments {
                    self.compile_expr(arg);
                }
                self._emit(
                    make_instruction(Opcode.CALL_METHOD, argc, 0, nd.loc.line, _sp_fl)
                );
            } else {
                # `a?.b.m(args)` / `a?.b[k](args)` — the callee's receiver chain is
                # rooted at an OptionalChainExpr, so the CALL is part of the chain:
                # a nullish root short-circuits the WHOLE call (no property read,
                # no argument evaluation), yielding undefined (ES §13.3 Optional
                # Chains).  Emit the receiver chain with the short-circuit region
                # left open, then extend it over the method load + call.
                _cc_root: ASTNode | None = self._opt_chain_root(callee);
                if _cc_root is not None and callee.object is not None {
                    _cc_ocv: list[int] = self._emit_opt_chain_value(
                        callee.object, _cc_root, nd.loc.line
                    );
                    self._op(Opcode.DUP);  # [recv, recv]
                    _cc_name_idx: int = 0;
                    if callee.computed {
                        if callee.property is not None {
                            self.compile_expr(callee.property);
                        }
                        self._op(Opcode.GET_INDEX);  # [recv, fn]
                    } else {
                        if callee.property is not None {
                            _cc_name_idx = self._intern(
                                self._prop_key(callee.property.name)
                            );
                            if self._is_private_name(callee.property.name) {
                                self._emit(
                                    make_instruction(
                                        Opcode.CHECK_PRIVATE,
                                        _cc_name_idx,
                                        0,
                                        nd.loc.line
                                    )
                                );
                            }
                            self._emit(
                                make_instruction(
                                    Opcode.GET_PROP, _cc_name_idx, 0, nd.loc.line
                                )
                            );  # [recv, fn]
                        }
                    }
                    self._op(Opcode.SWAP);  # [fn, recv]
                    for _cc_arg in nd.arguments {
                        self.compile_expr(_cc_arg);
                    }
                    self._emit(
                        make_instruction(
                            Opcode.CALL_METHOD, argc, _cc_name_idx, nd.loc.line, _sp_fl
                        )
                    );
                    _cc_jend: int = self._jump(Opcode.JUMP);
                    self._patch(_cc_ocv[0]);
                    self._patch(_cc_ocv[1]);
                    self._op(Opcode.POP);  # discard the nullish value tested by the guards
                    if _cc_ocv[2] == 1 {
                        self._op(Opcode.POP);
                    }
                    self._op(Opcode.LOAD_UNDEFINED);
                    self._patch(_cc_jend);
                    return;
                }
                if callee.object is not None {
                    self.compile_expr(callee.object);
                }
                self._op(Opcode.DUP);
                if callee.computed {
                    if callee.property is not None {
                        self.compile_expr(callee.property);
                    }
                    self._op(Opcode.GET_INDEX);
                } else {
                    if callee.property is not None {
                        _cp_idx: int = self._intern(
                            self._prop_key(callee.property.name)
                        );
                        # Private method call (`this.#m()`) — brand-check the receiver
                        # first (ES §13.15.5); a private method on an object whose class
                        # did not declare it (or before super() installed the brand) is
                        # a TypeError, not a missing method.
                        if self._is_private_name(callee.property.name) {
                            self._emit(
                                make_instruction(
                                    Opcode.CHECK_PRIVATE, _cp_idx, 0, nd.loc.line
                                )
                            );
                        }
                        self._emit(
                            make_instruction(Opcode.GET_PROP, _cp_idx, 0, nd.loc.line)
                        );
                    }
                }
                self._op(Opcode.SWAP);
                for arg in nd.arguments {
                    self.compile_expr(arg);
                }
                # arg2 = property name constant index (0 for computed calls)
                _cm_name_idx: int = 0;
                if not callee.computed and callee.property is not None {
                    _cm_name_idx = self._intern(self._prop_key(callee.property.name));
                }
                self._emit(
                    make_instruction(
                        Opcode.CALL_METHOD, argc, _cm_name_idx, nd.loc.line, _sp_fl
                    )
                );
            }
        } elif callee.ntype == ASTNodeType.OptionalChainExpr {
            # x?.method(args)  or  x?.[key](args)
            # Evaluate the object; short-circuit to undefined on null/undefined.
            if callee.object is not None {
                self.compile_expr(callee.object);
            } else {
                self._op(Opcode.LOAD_UNDEFINED);
            }
            j_null_oc: int = self._jump(Opcode.JUMP_IF_NULL);
            j_undef_oc: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
            # ── non-nullish: emit as regular method call ──────────────────
            self._op(Opcode.DUP);
            _oc_cm_name_idx: int = 0;
            if callee.computed {
                if callee.property is not None {
                    self.compile_expr(callee.property);
                }
                self._op(Opcode.GET_INDEX);
            } else {
                if callee.property is not None {
                    _oc_cm_name_idx = self._intern(
                        self._prop_key(callee.property.name)
                    );
                    self._emit(
                        make_instruction(
                            Opcode.GET_PROP, _oc_cm_name_idx, 0, nd.loc.line
                        )
                    );
                }
            }
            self._op(Opcode.SWAP);
            for arg in nd.arguments {
                self.compile_expr(arg);
            }
            self._emit(
                make_instruction(
                    Opcode.CALL_METHOD, argc, _oc_cm_name_idx, nd.loc.line, _sp_fl
                )
            );
            j_end_oc: int = self._jump(Opcode.JUMP);
            # ── nullish path: pop object, push undefined ──────────────────
            self._patch(j_null_oc);
            self._patch(j_undef_oc);
            self._op(Opcode.POP);
            self._op(Opcode.LOAD_UNDEFINED);
            self._patch(j_end_oc);
        } else {
            self.compile_expr(callee);
            for arg in nd.arguments {
                self.compile_expr(arg);
            }
            # arg2 = callee name constant index + 1 (0 means no name; shift avoids collision at index 0)
            _call_name_idx: int = 0;
            if callee.ntype == ASTNodeType.Identifier {
                _call_name_idx = self._intern(callee.name) + 1;
            }
            # B7: a direct `eval(...)` call compiled inside a parameter-default
            # expression — mark it so the runtime forbids forbidden bindings in the
            # eval'd code (ES §15.1.1 parameter-scope rule). arg3: 1 = forbid both
            # `arguments` and `eval` (ordinary function — it has its own
            # `arguments`); 2 = forbid only `eval` (arrow — no own `arguments`, so
            # `var arguments` in the param eval is allowed).
            # arg3 bits: 1/2 = param-eval mode (B7); 4 = this is a *direct* eval call
            # (bare-identifier `eval(...)`), so the runtime inherits the caller's
            # scope/strict/super. A non-bare-identifier call form — `(0,eval)(...)`,
            # `x.eval(...)`, an aliased eval — is *indirect* and inherits nothing.
            _call_eval_param: int = 0;
            if callee.ntype == ASTNodeType.Identifier and callee.name == "eval" {
                _call_eval_param = 4;  # direct eval
                if self.in_default_params {
                    if self.default_params_in_arrow {
                        _call_eval_param = _call_eval_param | 2;
                    } else {
                        _call_eval_param = _call_eval_param | 1;
                    }
                }
            }
            # TAIL_CALL carries the same operands as CALL (incl. the direct-eval bit): the VM
            # only performs a proper tail call when the callee is a plain JS function; a real
            # %eval% still runs as a direct eval (tco-non-eval-* shadow `eval` with a function).
            _call_op: Opcode = Opcode.TAIL_CALL if _is_tail else Opcode.CALL;
            self._emit(
                make_instruction(
                    _call_op,
                    argc,
                    _call_name_idx,
                    nd.loc.line,
                    _call_eval_param + _sp_fl
                )
            );
        }
    }

    # ── new ────────────────────────────────────────────────────────────────

    def compile_new(nd: ASTNode) {
        if nd.callee is not None {
            self.compile_expr(nd.callee);
        }
        argc: int = len(nd.arguments);
        _nw_spfl: int = 0;
        for _nw_spa in nd.arguments {
            if _nw_spa.ntype == ASTNodeType.SpreadElement {
                _nw_spfl = 8;
            }
        }
        for arg in nd.arguments {
            self.compile_expr(arg);
        }
        self._emit(make_instruction(Opcode.NEW, argc, 0, 0, _nw_spfl));
    }

    # ── member ─────────────────────────────────────────────────────────────

    def compile_member(nd: ASTNode) -> None {
        # If the object chain is rooted at an OptionalChainExpr, wrap the entire chain
        # (root step + all tail steps) in a single short-circuit scope so that a nullish
        # root short-circuits ALL property accesses, not just the optional one.
        # e.g. `a?.b.c` — when a is null the whole chain evaluates to undefined.
        opt_root: ASTNode | None = self._opt_chain_root(nd);
        if opt_root is not None {
            ocv: list[int] = self._emit_opt_chain_value(nd, opt_root, nd.loc.line);
            ocv_jend: int = self._jump(Opcode.JUMP);
            self._patch(ocv[0]);
            self._patch(ocv[1]);
            self._op(Opcode.POP);  # discard the nullish value tested by the guards
            # For a receiver-preserving optional call the stack was [recv, fn] at the
            # guard, so the receiver is still underneath — discard it too.
            if ocv[2] == 1 {
                self._op(Opcode.POP);
            }
            self._op(Opcode.LOAD_UNDEFINED);
            self._patch(ocv_jend);
            return;
        }
        self._compile_member_rest(nd);
    }

    # Emits an optional-rooted member chain (root optional step + all member
    # tail steps), leaving its value on the stack.  `chain_leaf` is the
    # outermost MemberExpression to include (or `opt_root` itself).  The
    # nullish short-circuit jumps are returned UNPATCHED as [j_null, j_undef,
    # extra_pop] so the caller can extend the short-circuit region (e.g. a
    # method call over the chain value, `a?.b.m()`) before patching.  The
    # caller must emit the nullish landing: POP (twice when extra_pop == 1),
    # then LOAD_UNDEFINED.
    def _emit_opt_chain_value(
        chain_leaf: ASTNode, opt_root: ASTNode, line: int
    ) -> list[int] {
        # Collect all steps from chain_leaf down to (exclusive of) opt_root, leaf-to-root order.
        steps_rev: list[ASTNode] = [];
        step_cur: ASTNode = chain_leaf;
        while step_cur is not None {
            if step_cur.ntype == ASTNodeType.OptionalChainExpr {
                break;
            }
            steps_rev.append(step_cur);
            if step_cur.ntype == ASTNodeType.MemberExpression
                and step_cur.object is not None {
                step_cur = step_cur.object;
            } else {
                break;
            }
        }
        opt_root_is_call: bool = (
            opt_root.property is not None and opt_root.property.name == "()"
        );
        orc_has_recv: bool = False;
        if opt_root_is_call {
            # The optional root is a CALL (`a.b?.().c`): evaluate the callee,
            # short-circuit if it is nullish, else call it (preserving `this` when
            # the callee is itself a member expression), then continue with the
            # tail property steps on the result.
            orc_callee: ASTNode | None = opt_root.object;
            orc_has_recv = orc_callee is not None
                and orc_callee.ntype == ASTNodeType.MemberExpression
                and orc_callee.object is not None;
            if orc_callee is not None
                and orc_callee.ntype == ASTNodeType.MemberExpression
                and orc_callee.object is not None {
                self.compile_expr(orc_callee.object);  # [recv]
                self._op(Opcode.DUP);  # [recv, recv]
                if orc_callee.computed {
                    if orc_callee.property is not None {
                        self.compile_expr(orc_callee.property);
                    }
                    self._op(Opcode.GET_INDEX);  # [recv, fn]
                } else {
                    if orc_callee.property is not None {
                        orc_idx: int = self._intern(
                            self._prop_key(orc_callee.property.name)
                        );
                        self._emit(make_instruction(Opcode.GET_PROP, orc_idx, 0, line));  # [recv, fn]
                    }
                }
            } else {
                if orc_callee is not None {
                    self.compile_expr(orc_callee);
                }  # [fn]
            }
        } else {
            if opt_root.object is not None {
                self.compile_expr(opt_root.object);
            }
        }
        j_null: int = self._jump(Opcode.JUMP_IF_NULL);
        j_undef: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
        # Emit root optional step (e.g. `.b`, `?.()`).
        if opt_root_is_call {
            orc_argc: int = len(opt_root.arguments);
            if orc_has_recv {
                self._op(Opcode.SWAP);  # [fn, recv]
                orc_spfl: int = 0;
                for orc_spa in opt_root.arguments {
                    if orc_spa.ntype == ASTNodeType.SpreadElement {
                        orc_spfl = 8;
                    }
                }
                for orc_a in opt_root.arguments {
                    self.compile_expr(orc_a);
                }
                self._emit(
                    make_instruction(Opcode.CALL_METHOD, orc_argc, 0, line, orc_spfl)
                );
            } else {
                orc_spfl2: int = 0;
                for orc_spa2 in opt_root.arguments {
                    if orc_spa2.ntype == ASTNodeType.SpreadElement {
                        orc_spfl2 = 8;
                    }
                }
                for orc_a2 in opt_root.arguments {
                    self.compile_expr(orc_a2);
                }
                self._emit(make_instruction(Opcode.CALL, orc_argc, 0, line, orc_spfl2));
            }
        } elif not opt_root.computed and opt_root.property is not None {
            r_idx: int = self._intern(self._prop_key(opt_root.property.name));
            self._emit(make_instruction(Opcode.GET_PROP, r_idx, 0, line));
        } elif opt_root.computed and opt_root.property is not None {
            self.compile_expr(opt_root.property);
            self._op(Opcode.GET_INDEX);
        }
        # Emit tail steps root-to-leaf (reverse of steps_rev).
        ri: int = len(steps_rev) - 1;
        while ri >= 0 {
            ts: ASTNode = steps_rev[ri];
            if not ts.computed and ts.property is not None {
                ts_idx: int = self._intern(self._prop_key(ts.property.name));
                # A private tail step (`o?.c.#f`) is still a brand check: a present but
                # non-declaring base throws TypeError (ES §13.15.5), not `undefined`.
                if self._is_private_name(ts.property.name) {
                    self._emit(make_instruction(Opcode.CHECK_PRIVATE, ts_idx, 0, line));
                }
                self._emit(make_instruction(Opcode.GET_PROP, ts_idx, 0, line));
            } elif ts.computed and ts.property is not None {
                self.compile_expr(ts.property);
                self._op(Opcode.GET_INDEX);
            }
            ri = ri - 1;
        }
        extra_pop: int = 0;
        if orc_has_recv {
            extra_pop = 1;
        }
        return [j_null, j_undef, extra_pop];
    }

    def _compile_member_rest(nd: ASTNode) -> None {
        # `super.x` / `super[expr]` property access (not a call — that is handled in
        # compile_call).  The base is the super class's prototype (LOAD_SUPER_PROTO);
        # for `class C extends null` that prototype is null/undefined, so the GET
        # then throws TypeError, matching the spec (GetPrototypeOf([[HomeObject]])).
        if nd.object is not None
            and nd.object.ntype == ASTNodeType.Identifier
            and nd.object.name == "super" {
            # B9: `super.x` needs a method/accessor home object.
            if not self.super_prop_allowed {
                self._syntax_error("SyntaxError: 'super' keyword unexpected here");
            }
            # ES §13.3.7.1: a `super.x` reference looks the property up on the super
            # base (HomeObject's [[Prototype]]) but any getter runs with `this` =
            # the current method's `this` (the receiver), NOT the super base.  Push
            # the receiver and use the SUPER_GET_* opcodes so the getter sees it.
            self._emit(
                make_instruction(
                    Opcode.LOAD_SUPER_PROTO, 0, self._super_static_arg(), 0
                )
            );
            if nd.computed {
                # GetThisBinding (the receiver / this-TDZ check) precedes ToPropertyKey
                # of the key (ES §13.3.7.1): emit LOAD_THIS BEFORE the key expression so
                # an uninitialized `this` (derived ctor before super()) throws first.
                self._op(Opcode.LOAD_THIS);  # [base, recv]
                if nd.property is not None {
                    self.compile_expr(nd.property);
                }  # [base, recv, key]
                self._op(Opcode.SWAP);  # [base, key, recv]
                self._op(Opcode.SUPER_GET_INDEX);
            } else {
                if nd.property is not None {
                    _sm_idx: int = self._intern_key(self._prop_key(nd.property.name));
                    self._op(Opcode.LOAD_THIS);
                    self._emit(
                        make_instruction(
                            Opcode.SUPER_GET_PROP,
                            _sm_idx,
                            self._last_key_id,
                            nd.loc.line
                        )
                    );
                }
            }
            return;
        }

        # Normal (non-optional-rooted) member access.
        if nd.object is not None {
            self.compile_expr(nd.object);
        }
        if nd.computed {
            if nd.property is not None {
                self.compile_expr(nd.property);
            }
            self._op(Opcode.GET_INDEX);
        } else {
            if nd.property is not None {
                _m_idx: int = self._intern_key(self._prop_key(nd.property.name));
                # Private member read (`obj.#x`) — verify the object carries the
                # private brand first (ES §13.15.5); accessing a private field or
                # accessor on an object whose class did not declare it is a
                # TypeError, not `undefined`.  CHECK_PRIVATE peeks the object and
                # throws if the brand is absent, leaving it for the GET_PROP.
                if self._is_private_name(nd.property.name) {
                    self._emit(
                        make_instruction(
                            Opcode.CHECK_PRIVATE,
                            _m_idx,
                            0,
                            nd.loc.line,
                            self._last_key_id
                        )
                    );
                }
                self._emit(
                    make_instruction(
                        Opcode.GET_PROP, _m_idx, self._last_key_id, nd.loc.line
                    )
                );
            }
        }
    }

    # ── optional chain ─────────────────────────────────────────────────────
    # Handles:
    #   x?.prop      → OptionalChainExpr(object=x, property="prop", computed=false)
    #   x?.[key]     → OptionalChainExpr(object=x, property=key, computed=true)
    #   x?.()        → OptionalChainExpr(object=x, property="()", arguments=[...])
    #
    # If object is null or undefined → push undefined.
    # Otherwise behave like the corresponding non-optional access/call.

    def compile_optional_chain(nd: ASTNode) -> None {
        if nd.object is None {
            self._op(Opcode.LOAD_UNDEFINED);
            return;
        }
        is_call: bool = nd.property is not None and nd.property.name == "()";
        # `obj.m?.()` / `obj[k]?.()` — an optional CALL whose callee is a member
        # expression must preserve the receiver (`this` = obj), like a normal method
        # call.  Compile the member manually to leave [receiver, fn] on the stack,
        # null-check the fn, then CALL_METHOD.  (A plain `f?.()` has no receiver.)
        if is_call
            and nd.object is not None
            and nd.object.ntype == ASTNodeType.MemberExpression
            and nd.object.object is not None {
            oc_mem: ASTNode = nd.object;
            if oc_mem.object is not None {
                self.compile_expr(oc_mem.object);
            }  # [receiver]
            self._op(Opcode.DUP);  # [receiver, receiver]
            if oc_mem.computed {
                if oc_mem.property is not None {
                    self.compile_expr(oc_mem.property);
                }
                self._op(Opcode.GET_INDEX);  # [receiver, fn]
            } else {
                if oc_mem.property is not None {
                    ocm_idx: int = self._intern(self._prop_key(oc_mem.property.name));
                    self._emit(
                        make_instruction(Opcode.GET_PROP, ocm_idx, 0, nd.loc.line)
                    );  # [receiver, fn]
                }
            }
            # Null-check the FN (top of stack); short-circuit to undefined if nullish.
            ocm_jn: int = self._jump(Opcode.JUMP_IF_NULL);
            ocm_ju: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
            self._op(Opcode.SWAP);  # [fn, receiver]
            oc_margc: int = len(nd.arguments);
            ocm_spfl: int = 0;
            for ocm_spa in nd.arguments {
                if ocm_spa.ntype == ASTNodeType.SpreadElement {
                    ocm_spfl = 8;
                }
            }
            for oc_marg in nd.arguments {
                self.compile_expr(oc_marg);
            }
            self._emit(
                make_instruction(Opcode.CALL_METHOD, oc_margc, 0, nd.loc.line, ocm_spfl)
            );
            ocm_jend: int = self._jump(Opcode.JUMP);
            self._patch(ocm_jn);
            self._patch(ocm_ju);
            self._op(Opcode.POP);  # discard nullish fn
            self._op(Opcode.POP);  # discard receiver
            self._op(Opcode.LOAD_UNDEFINED);
            self._patch(ocm_jend);
            return;
        }
        if nd.object is not None {
            self.compile_expr(nd.object);
        }
        # Peek at the top of stack; jump to nullish path if null or undefined.
        j_null: int = self._jump(Opcode.JUMP_IF_NULL);
        j_undef: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
        # ── non-nullish path ──────────────────────────────────────────────
        if is_call {
            # x?.() — call the object itself as a function with optional args
            _oc_argc: int = len(nd.arguments);
            _oc_spfl: int = 0;
            for _oc_spa in nd.arguments {
                if _oc_spa.ntype == ASTNodeType.SpreadElement {
                    _oc_spfl = 8;
                }
            }
            for _oc_arg in nd.arguments {
                self.compile_expr(_oc_arg);
            }
            self._emit(
                make_instruction(Opcode.CALL, _oc_argc, 0, nd.loc.line, _oc_spfl)
            );
        } elif nd.computed {
            if nd.property is not None {
                self.compile_expr(nd.property);
            }
            self._op(Opcode.GET_INDEX);
        } else {
            if nd.property is not None {
                _oc_idx: int = self._intern_key(self._prop_key(nd.property.name));
                # Private member in an optional chain (`obj?.#x`): still a brand check —
                # accessing a private on an object whose class did not declare it is a
                # TypeError, not `undefined` (ES §13.15.5). The `?.` only short-circuits on a
                # nullish base (handled above); a present non-declaring base must throw.
                if self._is_private_name(nd.property.name) {
                    self._emit(
                        make_instruction(
                            Opcode.CHECK_PRIVATE,
                            _oc_idx,
                            0,
                            nd.loc.line,
                            self._last_key_id
                        )
                    );
                }
                self._emit(
                    make_instruction(
                        Opcode.GET_PROP, _oc_idx, self._last_key_id, nd.loc.line
                    )
                );
            }
        }
        j_end: int = self._jump(Opcode.JUMP);
        # ── nullish path ──────────────────────────────────────────────────
        self._patch(j_null);
        self._patch(j_undef);
        self._op(Opcode.POP);  # discard null/undefined object
        self._op(Opcode.LOAD_UNDEFINED);
        self._patch(j_end);
    }

    # Walk nd.object downward through MemberExpression nodes looking for the
    # OptionalChainExpr that roots the chain.  Returns it if found, else None.
    def _opt_chain_root(nd: ASTNode) -> ASTNode | None {
        cur: ASTNode | None = nd.object;
        while cur is not None {
            if cur.ntype == ASTNodeType.OptionalChainExpr {
                return cur;
            }
            if cur.ntype != ASTNodeType.MemberExpression {
                return None;
            }
            cur = cur.object;
        }
        return None;
    }

    # ── array ──────────────────────────────────────────────────────────────

    def compile_array(nd: ASTNode) {
        # arg3 bit 16 = "proven spread-free": NEW_ARRAY then skips its per-element
        # spread-marker scan (a has_own probe per object element). A positive
        # "no spread" bit keeps bytecode cached before it (bit clear) on the scan.
        ca_flags: int = 16;
        for elem in nd.elements {
            if elem.ntype == ASTNodeType.Elision {
                self._op(Opcode.LOAD_HOLE);
            } else {
                if elem.ntype == ASTNodeType.SpreadElement {
                    ca_flags = 0;
                }
                self.compile_expr(elem);
            }
        }
        self._emit(
            make_instruction(Opcode.NEW_ARRAY, len(nd.elements), 0, 0, ca_flags)
        );
    }

    # ── object ─────────────────────────────────────────────────────────────

    def compile_object(nd: ASTNode) {
        self._op(Opcode.NEW_OBJECT);
        for prop in nd.properties {
            if prop.ntype == ASTNodeType.SpreadElement {
                if prop.argument is not None {
                    self.compile_expr(prop.argument);
                } else {
                    self._op(Opcode.LOAD_UNDEFINED);
                }
                self._op(Opcode.OBJECT_SPREAD);
                continue;
            }
            self._op(Opcode.DUP);
            _co_idx: int = -1;
            if prop.computed {
                if prop.key is not None {
                    self.compile_expr(prop.key);
                    # ES §13.2.5.5: ComputedPropertyName's ToPropertyKey (which runs the
                    # key object's toString/@@toPrimitive) is evaluated BEFORE the value
                    # AssignmentExpression. Coerce the key now so a side-effecting key
                    # toString observes state before the value is read (test262
                    # computed-property-name-topropertykey-before-value-evaluation).
                    # ToPropertyKey is idempotent, so the later SET_INDEX/DEFINE_* re-coerce
                    # is a no-op.
                    self._op(Opcode.TO_PROPERTY_KEY);
                }
            } else {
                if prop.key is not None {
                    # Identifier keys use .name; string Literal keys must be
                    # unescaped (so `"\\"` / `"\x00"` match value-literal cooking).
                    if prop.key.ntype == ASTNodeType.Literal {
                        if prop.key.kind == "string" {
                            _co_idx = self._intern(_unescape_string(prop.key.value));
                        } else {
                            _co_idx = self._intern(prop.key.value);
                        }
                    } else {
                        _co_idx = self._intern(prop.key.name);
                    }
                }
            }
            if prop.expression is not None {
                # B9: object-literal methods/accessors have the object as their home
                # object, so `super.x` is permitted in their bodies. (Set for any
                # property value — over-permissive for `key: function(){}`, but that
                # avoids false-positive SyntaxErrors on valid concise methods, which
                # are indistinguishable here; `super()` stays disallowed.)
                self.pending_super_prop = True;
                self.pending_super_call = False;
                self.compile_expr(prop.expression);
                # ES §12.2.6.9 / §10.2.9 SetFunctionName for an object-literal ACCESSOR:
                # its name is "get <key>" / "set <key>". For a non-computed key, set it on
                # the compiled fn now; a computed accessor infers it at runtime from the key
                # (INFER_NAME_FROM_KEY, prefix arg2 = 1 for get / 2 for set), emitted below
                # after the key is pushed (mirrors class computed accessors).
                if (prop.kind == "get" or prop.kind == "set") and not prop.computed {
                    if prop.key is not None and len(self.all_fns) > 0 {
                        co_acc_key: str = "";
                        if prop.key.ntype == ASTNodeType.Literal {
                            if prop.key.kind == "string" {
                                co_acc_key = _unescape_string(prop.key.value);
                            } else {
                                co_acc_key = prop.key.value;
                            }
                        } else {
                            co_acc_key = prop.key.name;
                        }
                        co_acc_pfx: str = "get " if prop.kind == "get" else "set ";
                        self.all_fns[len(self.all_fns) - 1].name = co_acc_pfx
                            + co_acc_key;
                    }
                }
                # ECMAScript §12.2.6.9 (PropertyDefinition): for non-computed, non-shorthand
                # properties whose value is an anonymous function/arrow/class, infer the
                # name from the property key.
                if not prop.computed
                    and not prop.shorthand
                    and prop.kind != "get"
                    and prop.kind != "set" {
                    if prop.key is not None {
                        co_inf_name: str = "";
                        if prop.key.ntype == ASTNodeType.Literal {
                            if prop.key.kind == "string" {
                                co_inf_name = _unescape_string(prop.key.value);
                            } else {
                                co_inf_name = prop.key.value;
                            }
                        } else {
                            co_inf_name = prop.key.name;
                        }
                        if co_inf_name != "" and co_inf_name != "__proto__" {
                            self._maybe_infer_fn_name(prop.expression, co_inf_name);
                        }
                    }
                    # Computed data property `{[expr]: anonFn}`: name is inferred at runtime
                    # from the key (ES §12.2.6.9 SetFunctionName).  Stack is [obj, key, fn].
                } elif prop.computed
                    and prop.kind != "get"
                    and prop.kind != "set"
                    and self._expr_is_anonymous_named(prop.expression) {
                    self._op(Opcode.INFER_NAME_FROM_KEY);
                }
            } elif prop.shorthand {
                if prop.key is not None {
                    self.compile_identifier(prop.key);
                }
            } else {
                self._op(Opcode.LOAD_UNDEFINED);
            }
            # Kind must be checked before computed: `get [Symbol.species]()` is both
            # computed and kind=="get". Emitting SET_INDEX would store the getter as a
            # data property; DEFINE_GETTER with arg=-1 installs a real accessor
            # (key already on the stack), matching class computed accessors.
            if prop.kind == "get" {
                # Object literal getter: arg2=2 means install on the object directly.
                # Computed key (`{ get [expr](){} }`): arg=-1 → key is on the stack
                # (below the fn), coerced via ToPropertyKey in the handler.  A computed
                # getter's name is "get <key>", inferred at runtime (ES §12.2.6.9).
                if prop.computed {
                    self._emit(make_instruction(Opcode.INFER_NAME_FROM_KEY, 0, 1, 0));
                }
                self._emit(make_instruction(Opcode.DEFINE_GETTER, _co_idx, 2, 0));
            } elif prop.kind == "set" {
                # Object literal setter: arg2=2 means install on the object directly.
                if prop.computed {
                    self._emit(make_instruction(Opcode.INFER_NAME_FROM_KEY, 0, 2, 0));
                }
                self._emit(make_instruction(Opcode.DEFINE_SETTER, _co_idx, 2, 0));
            } elif prop.computed {
                # Object-literal computed data property `{[k]: v}` — CreateDataProperty
                # (arg3=1), an OWN definition that ignores inherited read-only props
                # (ES §13.2.5.5 PropertyDefinitionEvaluation).
                self._emit(make_instruction(Opcode.SET_INDEX, 0, 0, 0, 1));
            } else {
                co_proto_init: int = 0;
                if prop.key is not None {
                    co_key_name: str = "";
                    if prop.key.ntype == ASTNodeType.Literal {
                        if prop.key.kind == "string" {
                            co_key_name = _unescape_string(prop.key.value);
                        } else {
                            co_key_name = prop.key.value;
                        }
                    } else {
                        co_key_name = prop.key.name;
                    }
                    # Annex B.3.1: ONLY the plain `__proto__: value` form (a colon
                    # PropertyDefinition with a non-computed literal `__proto__` key) is the
                    # special [[Prototype]] setter. A SHORTHAND `{__proto__}` and a method
                    # `{__proto__(){}}` create an ORDINARY own "__proto__" property instead
                    # (computed `['__proto__']` is already handled by the SET_INDEX branch).
                    co_is_method: bool = prop.expression is not None
                        and prop.expression.ntype == ASTNodeType.FunctionExpression
                        and prop.expression.is_method;
                    if co_key_name == "__proto__"
                        and not prop.shorthand
                        and prop.kind == "init"
                        and not co_is_method {
                        co_proto_init = 1;
                    }
                }
                # Named data property: CreateDataProperty (arg3=1) — an OWN definition.
                # `__proto__:` (co_proto_init=1) keeps its special [[Prototype]] setter
                # path instead, so only flag the ordinary-key case.
                co_define_own: int = 0;
                if co_proto_init == 0 {
                    co_define_own = 1;
                }
                self._emit(
                    make_instruction(
                        Opcode.SET_PROP, _co_idx, co_proto_init, 0, co_define_own
                    )
                );
            }
            self._op(Opcode.POP);
        }
    }

    # ── template literal ───────────────────────────────────────────────────

    def compile_template(nd: ASTNode) {
        nq: int = len(nd.quasis);
        ne: int = len(nd.expressions);
        started: bool = False;
        i: int = 0;
        while i < nq {
            self._const("s:" + _unescape_string(nd.quasis[i]));
            if started {
                self._op(Opcode.ADD);
            }
            started = True;
            if i < ne {
                self.compile_expr(nd.expressions[i]);
                # Template interpolation uses ToString semantics (hint "string"),
                # unlike '+' which uses ToPrimitive("default").
                self._op(Opcode.TO_STRING);
                self._op(Opcode.ADD);
            }
            i = i + 1;
        }
        if not started {
            self._const("");
        }
    }

    # ── sequence ───────────────────────────────────────────────────────────

    def compile_sequence(nd: ASTNode) {
        # ES §15.10.3: tail position propagates only to the LAST expression of a comma
        # sequence (`return a, b, f(x)` tail-calls `f`); the earlier ones are discarded.
        seq_tail: bool = self._emit_tail_call;
        self._emit_tail_call = False;
        n: int = len(nd.expressions);
        i: int = 0;
        while i < n {
            if i == n - 1 {
                self._emit_tail_call = seq_tail;
            }
            self.compile_expr(nd.expressions[i]);
            if i < n - 1 {
                self._op(Opcode.POP);
            }
            i = i + 1;
        }
        self._emit_tail_call = False;
    }

    # ── arrow / fn-expr / class-expr ──────────────────────────────────────

    def compile_arrow(nd: ASTNode) {
        fn_val: CompiledFunction = self._compile_function(nd);
        fn_idx: int = len(self.all_fns);
        self.all_fns.append(fn_val);
        self._emit(make_instruction(Opcode.MAKE_ARROW, fn_idx, 0, 0));
    }

    def compile_fn_expr(nd: ASTNode, is_declaration: bool = False) {
        # `is_declaration` is set for `export default function f(){}`: it is a
        # HoistableDeclaration whose `f` is a mutable outer binding, so the body must
        # not get the immutable fnself self-name (lets `f = …` reassign it).
        fn_val: CompiledFunction = self._compile_function(nd, is_declaration);
        fn_idx: int = len(self.all_fns);
        self.all_fns.append(fn_val);
        self._emit(make_instruction(Opcode.MAKE_FUNCTION, fn_idx, 0, 0));
    }

    def compile_class_expr(nd: ASTNode) {
        # ES §15.7: all class code is strict (see compile_class_decl).
        # Capture any pending INFERRED name (ES §15.7.14 step 18) for THIS class up front,
        # before the heritage clause is compiled — a `class extends (class {})` heritage
        # would otherwise let the inner anonymous class steal this class's inferred name.
        ce_infer_name: str = self._pending_infer_class_name;
        self._pending_infer_class_name = "";
        self.in_class_body = self.in_class_body + 1;
        self._enter_priv_scope(nd);
        # Named class EXPRESSION self-binding (ES §15.7.4 ClassDefinitionEvaluation):
        # the class name is an IMMUTABLE lexical binding in a scope enclosing only the
        # class body, so methods/statics AND the heritage (`extends`) clause can
        # reference the class by name while any outer binding of the same name is
        # untouched.  The binding is created (in TDZ) BEFORE the heritage is evaluated
        # — a closure in the heritage clause captures it and observes the class value
        # once initialised (post-MAKE_CLASS); the binding is `const`, so a reassignment
        # is a TypeError (scope-name-lex-open-heritage).
        ce_name_scope: bool = False;
        ce_name_slot: int = -1;
        if nd.id is not None {
            self._push_scope(False);
            ce_name_scope = True;
            ce_name_slot = self._declare(nd.id.name, "const");
            if ce_name_slot >= 0 {
                self._emit_tdz_store(ce_name_slot);
            }
        }
        has_super: int = 0;
        if nd.superclass is not None {
            self.compile_expr(nd.superclass);
            has_super = 1;
        }
        # arg2 = this class's private-scope id (sid), so the VM can stamp `__brandsid@cur`
        # on the class object → captured onto member closures for the sid-aware brand check.
        _mc_sid: int = self.priv_scope_ids[len(self.priv_scope_ids) - 1]
            if len(self.priv_scope_ids) > 0
            else 0;
        self._emit(make_instruction(Opcode.MAKE_CLASS, has_super, _mc_sid, 0));
        # Apply the INFERRED name (captured up front) NOW — before static elements run —
        # so their initializers observe the correct `this.name`. Named classes carry their
        # own name below; a real `static name` element still wins (SET_PROP __CLASS_NAME__
        # only overwrites the "" placeholder).
        if nd.id is None and ce_infer_name != "" {
            self._op(Opcode.DUP);
            self._const("s:" + ce_infer_name);
            name_key_ce_inf: int = self._intern("__CLASS_NAME__");
            self._emit(make_instruction(Opcode.SET_PROP, name_key_ce_inf, 0, 0));
            self._op(Opcode.POP);
        }
        # Set class.name (ECMAScript §15.7.3.8) — stored as __CLASS_NAME__ — and
        # initialise the immutable self-binding from the class value (kept on TOS).
        if nd.id is not None {
            self._op(Opcode.DUP);
            self._const("s:" + nd.id.name);
            name_key_ce: int = self._intern("__CLASS_NAME__");
            self._emit(make_instruction(Opcode.SET_PROP, name_key_ce, 0, 0));
            self._op(Opcode.POP);
            if ce_name_slot >= 0 {
                self._op(Opcode.DUP);
                self._emit(make_instruction(Opcode.STORE_LOCAL, ce_name_slot, 0, 0));
            }
        }
        # ES §13.15.5: register the INSTANCE private brand install as the FIRST instance
        # field (before user fields) so an instance field initializer can call a private
        # method (mirrors compile_class_decl).
        if len(self.priv_scope_ids) > 0 and self._class_needs_instance_brand(nd) {
            self._emit_private_brand_install(
                self.priv_scope_ids[len(self.priv_scope_ids) - 1], 0
            );
        }
        # STATIC brand as the FIRST static element (mirrors compile_class_decl).
        if len(self.priv_scope_ids) > 0 and self._class_needs_static_brand(nd) {
            self._emit_private_brand_install(
                self.priv_scope_ids[len(self.priv_scope_ids) - 1], 1
            );
        }
        for m in nd.children {
            if m.ntype == ASTNodeType.MethodDefinition {
                ce_key: str = "";
                ce_computed: bool = m.computed;
                # See compile_class_decl: handle non-computed literal keys (string
                # cooked at compile time; numeric routed through the runtime key path).
                ce_lit_num: bool = False;
                if m.key is not None
                    and m.key.ntype == ASTNodeType.Identifier
                    and not ce_computed {
                    ce_key = m.key.name;
                } elif m.key is not None
                    and m.key.ntype == ASTNodeType.Literal
                    and not ce_computed {
                    if m.key.kind == "string" {
                        ce_key = _unescape_string(m.key.value);
                    } elif m.key.kind == "number" {
                        ce_lit_num = True;
                    } else {
                        ce_key = m.key.value;
                    }
                }
                if m.kind == "static-block" {
                    # Static initialization block (ES2022) — see the class-statement path.
                    if m.expression is not None {
                        self.compile_expr(m.expression);
                        self._emit(
                            make_instruction(
                                Opcode.DEFINE_FIELD, self._intern(""), 1, 0
                            )
                        );
                    }
                    continue;
                }
                if m.kind == "field" {
                    ce_is_static_f: int = 0;
                    if m.is_static {
                        ce_is_static_f = 1;
                    }
                    ce_has_init: bool = True;
                    if m.expression is not None
                        and m.expression.ntype == ASTNodeType.Identifier
                        and m.expression.name == "" {
                        ce_has_init = False;
                    }
                    if m.expression is None {
                        ce_has_init = False;
                    }
                    if ce_computed or ce_lit_num {
                        # Computed-key field OR a NUMERIC-literal key field (`0 = 'bar'`) —
                        # route through _emit_computed_field so the VM canonicalizes the key
                        # via ToPropertyKey. The non-computed literal path below leaves
                        # ce_key "" and would install a bogus "" property. See
                        # compile_class_decl for the mirror fix on the statement path.
                        self._emit_computed_field(m, ce_is_static_f, ce_has_init);
                        continue;
                    }
                    if ce_has_init and m.expression is not None {
                        # B9: field initializers permit `super.x` (not `super()`).
                        ce_fi_sp: bool = self.super_prop_allowed;
                        ce_fi_sc: bool = self.super_call_allowed;
                        self.super_prop_allowed = True;
                        self.super_call_allowed = False;
                        self._push_fn("");
                        self._fn().is_field_init = True;  # ES §15.7.1 eval-in-field early errors
                        self.compile_expr(m.expression);
                        # ES §15.7.10 NamedEvaluation: an anonymous fn/arrow/class initializer of
                        # a field named `x`/`#field` infers that name (`.name === "x"`).
                        self._maybe_infer_fn_name(m.expression, ce_key);
                        self._op(Opcode.LOAD_THIS);
                        self._op(Opcode.SWAP);
                        self._emit(
                            make_instruction(
                                Opcode.SET_PROP,
                                self._intern(self._prop_key(ce_key)),
                                0,
                                0
                            )
                        );
                        self._op(Opcode.POP);
                        self._op(Opcode.RETURN_UNDEFINED);
                        ce_f_init: CompiledFunction = self._pop_fn();
                        self.super_prop_allowed = ce_fi_sp;
                        self.super_call_allowed = ce_fi_sc;
                        ce_f_idx: int = len(self.all_fns);
                        self.all_fns.append(ce_f_init);
                        self._emit(
                            make_instruction(Opcode.MAKE_FUNCTION, ce_f_idx, 0, 0)
                        );
                        self._emit(
                            make_instruction(
                                Opcode.DEFINE_FIELD,
                                self._intern(self._prop_key(ce_key)),
                                ce_is_static_f,
                                0
                            )
                        );
                    }
                    # No initializer (ES §15.7.10): still an own data property = undefined.
                    if not ce_has_init
                        and not ce_computed
                        and not ce_lit_num
                        and ce_key != "" {
                        self._push_fn("");
                        self._op(Opcode.LOAD_UNDEFINED);
                        self._op(Opcode.LOAD_THIS);
                        self._op(Opcode.SWAP);
                        self._emit(
                            make_instruction(
                                Opcode.SET_PROP,
                                self._intern(self._prop_key(ce_key)),
                                0,
                                0
                            )
                        );
                        self._op(Opcode.POP);
                        self._op(Opcode.RETURN_UNDEFINED);
                        ce_f_noinit: CompiledFunction = self._pop_fn();
                        ce_fn_idx: int = len(self.all_fns);
                        self.all_fns.append(ce_f_noinit);
                        self._emit(
                            make_instruction(Opcode.MAKE_FUNCTION, ce_fn_idx, 0, 0)
                        );
                        self._emit(
                            make_instruction(
                                Opcode.DEFINE_FIELD,
                                self._intern(self._prop_key(ce_key)),
                                ce_is_static_f,
                                0
                            )
                        );
                    }
                    continue;
                }
                if m.expression is None {
                    continue;
                }
                ce_runtime_key: bool = ce_computed or ce_lit_num;
                if ce_computed and m.key is not None {
                    self.compile_expr(m.key);
                } elif ce_lit_num and m.key is not None {
                    self.compile_literal(m.key);
                }
                # B9: super context (see compile_class_decl).
                self.pending_super_prop = True;
                self.pending_super_call = has_super == 1 and ce_key == "constructor";
                self.pending_super_static = m.is_static;
                self.compile_expr(m.expression);
                # ECMAScript §10.2.9: infer method name at compile time for static keys.
                if not ce_runtime_key and ce_key != "" and ce_key != "constructor" {
                    ce_inferred_name: str = ce_key;
                    if m.kind == "get" {
                        ce_inferred_name = "get " + ce_key;
                    } elif m.kind == "set" {
                        ce_inferred_name = "set " + ce_key;
                    }
                    self._maybe_infer_fn_name(m.expression, ce_inferred_name);
                }
                ce_is_static: int = 0;
                if m.is_static {
                    ce_is_static = 1;
                }
                ce_key_arg: int = -1;
                if not ce_runtime_key {
                    ce_key_arg = self._intern(self._prop_key(ce_key));
                }
                if m.kind == "get" {
                    self._emit(
                        make_instruction(
                            Opcode.DEFINE_GETTER, ce_key_arg, ce_is_static, 0
                        )
                    );
                } elif m.kind == "set" {
                    self._emit(
                        make_instruction(
                            Opcode.DEFINE_SETTER, ce_key_arg, ce_is_static, 0
                        )
                    );
                } else {
                    self._emit(
                        make_instruction(
                            Opcode.DEFINE_METHOD, ce_key_arg, ce_is_static, 0
                        )
                    );
                }
            }
        }
        # ES §15.7.14 step 33: run deferred static elements after all keys are evaluated.
        self._op(Opcode.RUN_STATIC_ELEMENTS);
        # Pop the named-class-expression self-binding scope (class value stays on TOS).
        if ce_name_scope {
            self._pop_scope();
        }
        self._leave_priv_scope();
        self.in_class_body = self.in_class_body - 1;
    }

    # ══════════════════════════════════════════════════════════════════════
    # Shared function-compilation helper
    # ══════════════════════════════════════════════════════════════════════

    """Append to _aa_start/_aa_end every occurrence of `word` in source_text that is
    not inside a longer ASCII identifier. Only ASCII identifier bytes on either side
    disqualify a hit, so anything unusual next to it (a non-ASCII byte, an escape)
    still counts — over-reporting is safe, under-reporting is not."""
    def _aa_collect(word: str) {
        st: str = self.source_text;
        n: int = len(st);
        wl: int = len(word);
        at: int = st.find(word, 0);
        while at >= 0 {
            bounded: bool = True;
            if at > 0 {
                pc: int = ord(st[at - 1]);
                if (pc >= 97 and pc <= 122)
                    or (pc >= 65 and pc <= 90)
                    or (pc >= 48 and pc <= 57)
                    or pc == 95
                    or pc == 36 {
                    bounded = False;
                }
            }
            if bounded and at + wl < n {
                nc: int = ord(st[at + wl]);
                if (nc >= 97 and nc <= 122)
                    or (nc >= 65 and nc <= 90)
                    or (nc >= 48 and nc <= 57)
                    or nc == 95
                    or nc == 36 {
                    bounded = False;
                }
            }
            if bounded and wl == 4 and word == "eval" {
                # Only a call whose callee is the bare identifier can be a
                # direct eval (ES §13.3.6.1): a member name (`x.eval(...)`) or
                # a non-call reference (`const e = eval`) never reaches this
                # function's `arguments` or locals.
                pj: int = at - 1;
                while pj >= 0
                    and (
                        st[pj] == " "
                        or st[pj] == "\t"
                        or st[pj] == "\n"
                        or st[pj] == "\r"
                    ) {
                    pj = pj - 1;
                }
                if pj >= 0 and st[pj] == "." {
                    bounded = False;
                }
                nj: int = at + wl;
                while nj < n
                    and (
                        st[nj] == " "
                        or st[nj] == "\t"
                        or st[nj] == "\n"
                        or st[nj] == "\r"
                    ) {
                    nj = nj + 1;
                }
                if nj >= n or (st[nj] != "(" and st[nj] != "/") {
                    bounded = False;
                }
            }
            if bounded {
                self._aa_start.append(at);
                self._aa_end.append(at + wl);
            }
            at = st.find(word, at + wl);
        }
    }

    """True if source_text[start:end] contains an `arguments` or `eval` identifier.
    The occurrence table is built once per source text; the per-function substring
    scan it replaces was O(source × nesting depth), and its false hits (`eval` in
    `evaluate`) made functions materialize an unused `arguments` object per call."""
    def _src_range_has_args_ref(start: int, end: int) -> bool {
        if self._aa_src_len != len(self.source_text) {
            self._aa_start = [];
            self._aa_end = [];
            self._aa_collect("arguments");
            na: int = len(self._aa_start);
            self._aa_collect("eval");
            # Two ascending runs → one ascending list (the search below needs order).
            m_start: list[int] = [];
            m_end: list[int] = [];
            ia: int = 0;
            ie: int = na;
            while ia < na or ie < len(self._aa_start) {
                if ie >= len(self._aa_start)
                    or (ia < na and self._aa_start[ia] < self._aa_start[ie]) {
                    m_start.append(self._aa_start[ia]);
                    m_end.append(self._aa_end[ia]);
                    ia = ia + 1;
                } else {
                    m_start.append(self._aa_start[ie]);
                    m_end.append(self._aa_end[ie]);
                    ie = ie + 1;
                }
            }
            self._aa_start = m_start;
            self._aa_end = m_end;
            self._aa_src_len = len(self.source_text);
        }
        lo: int = 0;
        hi: int = len(self._aa_start);
        while lo < hi {
            mid: int = (lo + hi) // 2;
            if self._aa_start[mid] < start {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        while lo < len(self._aa_start) and self._aa_start[lo] < end {
            if self._aa_end[lo] <= end
                and not (
                    self._aa_end[lo] - self._aa_start[lo] == 4
                    and _src_eval_own_name(self.source_text, start, self._aa_start[lo])
                ) {
                return True;
            }
            lo = lo + 1;
        }
        return False;
    }

    def _compile_function(
        nd: ASTNode, is_declaration: bool = False
    ) -> CompiledFunction {
        name: str = "";
        if nd.id is not None {
            name = nd.id.name;
        }
        # A function lexically nested inside a `with` body inherits that object env
        # record on its scope chain (ES §9.1): the closure captures the active
        # with-objects at MAKE_FUNCTION/MAKE_ARROW time and its frame is seeded with
        # them.  So identifier resolution in the body MUST route through
        # LOAD_NAME/STORE_NAME to consult those with-objects at runtime.  Preserve a
        # nonzero with_depth into the body when one is active (its value is only a
        # boolean gate here; the VM checks the real frame.with_objs length).  Outside
        # a `with`, reset to 0 for direct local/global resolution.
        saved_with_depth: int = self.with_depth;
        if self.with_depth == 0 {
            self.with_depth = 0;
        } else {
            self.with_depth = 1;
        }
        # A nested function's lexical pre-declarations (Phase-B `hoist_predeclared`,
        # keyed only by name) are entirely independent of the enclosing scope's.  Save
        # and reset the map so the body's `let`/`const` don't consume an enclosing
        # same-named binding's predeclare flag — e.g. `const a; function f(){ const a }`
        # must not misread the outer `a` as a redeclaration.  Restored at return.
        # Swapped, not copied: nothing else holds the enclosing map, and a per-function
        # copy is O(functions × top-level lexical names) on a large module.
        saved_hoist_predeclared: dict[str, bool] = self.hoist_predeclared;
        self.hoist_predeclared = {};
        # B9: establish super-context for this function body, restoring the enclosing
        # context at the single return. Arrows inherit the enclosing function's
        # active super flags (super is lexical). Non-arrows take the *pending* flags
        # set by the class-element / object-method loop just before this call (a
        # method/constructor body), else no super.
        saved_super_prop: bool = self.super_prop_allowed;
        saved_super_call: bool = self.super_call_allowed;
        saved_super_static: bool = self.super_is_static;
        if nd.ntype != ASTNodeType.ArrowFunctionExpr {
            self.super_prop_allowed = self.pending_super_prop;
            self.super_call_allowed = self.pending_super_call;
            self.super_is_static = self.pending_super_static;
        }
        # Consume pending so nested functions compiled within this body start clean.
        self.pending_super_prop = False;
        self.pending_super_call = False;
        self.pending_super_static = False;
        self._push_fn(name);
        # Set is_generator/is_async on the pushed fn NOW (they are also copied onto the
        # returned CompiledFunction at the end) so the BODY compilation can consult them —
        # e.g. AsyncGeneratorYield emits an AWAIT before YIELD only in an async generator.
        if nd.is_generator {
            self._fn().is_generator = True;
        }
        if nd.is_async {
            self._fn().is_async = True;
        }
        # Arrows created inside a class field initializer inherit the field-init
        # eval early-error rules (ES §15.7.1): a later direct eval in the arrow
        # must reject `arguments` the same way an eval during field init does.
        # Ordinary nested functions do NOT inherit (they have their own `arguments`).
        if nd.ntype == ASTNodeType.ArrowFunctionExpr {
            fi_oi: int = len(self.fn_stack) - 2;
            while fi_oi >= 0 {
                if self.fn_stack[fi_oi].is_field_init {
                    self._fn().is_field_init = True;
                    fi_oi = -1;
                } else {
                    fi_oi = fi_oi - 1;
                }
            }
        }
        # ── Early strict-mode detection (for parameter early errors) ──────────
        # The function's own strict mode is finalized later (§ Strict mode detection),
        # but the strict PARAMETER early errors (ES §15.1.1 / §15.2.1) must be checked
        # here — before params are declared.  A function is strict if the enclosing
        # code is strict, it is class-body code, an inherited eval-strict, or its body
        # opens with a "use strict" directive prologue.
        fn_early_strict: bool = False;
        os_idx: int = len(self.fn_stack) - 2;
        if os_idx >= 0 and self.fn_stack[os_idx].is_strict {
            fn_early_strict = True;
        }
        if self.in_class_body > 0 {
            fn_early_strict = True;
        }
        if self.eval_force_strict {
            fn_early_strict = True;
        }
        if nd.body is not None and len(nd.body.children) > 0 {
            fes0: ASTNode = nd.body.children[0];
            if fes0.ntype == ASTNodeType.ExpressionStatement
                and fes0.expression is not None
                and fes0.expression.ntype == ASTNodeType.Literal
                and fes0.expression.value == "use strict" {
                fn_early_strict = True;
            }
        }
        # ES §12.1.1: the BindingIdentifier of a strict FunctionExpression may not be
        # `eval` or `arguments` (function *declarations* are checked in
        # compile_function_decl before the body is compiled).
        if nd.ntype == ASTNodeType.FunctionExpression
            and nd.id is not None
            and fn_early_strict
            and (nd.id.name == "eval" or nd.id.name == "arguments") {
            self._syntax_error(
                "SyntaxError: Unexpected eval or arguments in strict mode"
            );
        }
        # Strict parameter early errors: no param may be named `eval`/`arguments`, and
        # no two params may share a name (ES §15.1.1 UniqueFormalParameters + the
        # BindingIdentifier `eval`/`arguments` restriction).  Collected across simple,
        # rest, and defaulted-identifier params.
        if fn_early_strict {
            fes_seen: dict[str, bool] = {};
            for fes_p in nd.params {
                fes_pname: str = "";
                if fes_p.ntype == ASTNodeType.Identifier {
                    fes_pname = fes_p.name;
                } elif fes_p.ntype == ASTNodeType.RestElement
                    and fes_p.argument is not None
                    and fes_p.argument.ntype == ASTNodeType.Identifier {
                    fes_pname = fes_p.argument.name;
                } elif fes_p.ntype == ASTNodeType.AssignmentPattern
                    and fes_p.left is not None
                    and fes_p.left.ntype == ASTNodeType.Identifier {
                    fes_pname = fes_p.left.name;
                }
                if fes_pname == "eval" or fes_pname == "arguments" {
                    self._syntax_error(
                        "SyntaxError: Unexpected eval or arguments in strict mode"
                    );
                }
                if fes_pname != "" {
                    if fes_pname in fes_seen {
                        self._syntax_error(
                            "SyntaxError: Duplicate parameter name not allowed in this context"
                        );
                    }
                    fes_seen[fes_pname] = True;
                }
            }
        }
        # For named functions, pre-declare the name as a local in the function's
        # own scope so recursive calls resolve via LOAD_LOCAL (not LOAD_GLOBAL).
        # A LOAD_SELF + STORE_LOCAL pair at the top of the body initialises this
        # slot to the function's own closure JSValue at runtime — no free-var
        # capture needed.
        self_slot: int = -1;
        # Check if any parameter (including rest) shadows the function name.
        # If so, skip the self-ref slot — the param wins, and param_base stays 0.
        param_shadows_name: bool = False;
        if name != "" {
            for chk_param in nd.params {
                if chk_param.ntype == ASTNodeType.Identifier
                    and chk_param.name == name {
                    param_shadows_name = True;
                } elif chk_param.ntype == ASTNodeType.RestElement
                    and chk_param.argument is not None
                    and chk_param.argument.name == name {
                    param_shadows_name = True;
                }
            }
        }
        # A body-level `var name` (or function declaration of the same name) fully
        # SHADOWS the self-name inside the body (ES §15.2.5): the var owns the name and
        # starts undefined, so the self-binding is not visible there. Skip the fnself
        # slot entirely — otherwise the prologue self-init would seed the shared slot with
        # the function value and a bare `var name;` would read it back (scope-var-open).
        body_shadows_name: bool = False;
        if name != ""
            and not param_shadows_name
            and nd.ntype == ASTNodeType.FunctionExpression
            and nd.body is not None {
            for bsn in self.collect_toplevel_var_names(nd.body.children) {
                if bsn == name {
                    body_shadows_name = True;
                }
            }
        }
        if name != ""
            and not param_shadows_name
            and not body_shadows_name
            and nd.ntype == ASTNodeType.FunctionExpression {
            # Named FunctionExpression only (ES §15.2.5 / §10.2.11): the self-binding
            # is IMMUTABLE — assignment throws TypeError in strict mode and is a
            # silent no-op in sloppy mode.  Declare it with the distinct "fnself"
            # kind so _store_lvalue can enforce that.  (Node type covers plain,
            # generator, and async named function expressions + concise methods;
            # arrows are ArrowFunctionExpr and correctly excluded.)
            #
            # FunctionDeclaration must NOT get a fnself slot: its name binding lives
            # in the enclosing (block/var) environment, and body references capture
            # that outer binding as a free var.  That is required for Annex B.3.3
            # block-scoping — `function f(){ f = 123; }` must mutate the block
            # binding, not an immutable local self-name.
            self_slot = self._declare(name, "fnself");
            self.fn_self_name = name;
            # Persist the immutable self-name onto the CompiledFunction so a direct
            # eval inside the body (which resolves `name` only as a runtime free-var)
            # can enforce fnself immutability in STORE_NAME (ES §15.2.5).
            self._fn().self_name = name;
        }
        # ── Strict mode detection (must precede parameter compilation) ─────────
        # ES §10.2.11: a function's strictness governs its WHOLE definition,
        # including parameter default expressions.  Determine it before compiling
        # defaults so a closure created in a param default (e.g. one that assigns
        # the immutable named-fn-expr self-name) is itself compiled as strict —
        # otherwise `fnself`/const immutability in `_store_lvalue` would silently
        # no-op instead of emitting a TypeError (scope-name-var-open-strict).
        cur_fn_strict: CompiledFunction = self._fn();
        outer_strict_idx: int = len(self.fn_stack) - 2;
        if outer_strict_idx >= 0 {
            if self.fn_stack[outer_strict_idx].is_strict {
                cur_fn_strict.is_strict = True;
            }
        }
        # ES §15.7: all code inside a class definition (constructor, methods,
        # accessors, field initializers, static blocks) is strict mode code.
        if self.in_class_body > 0 {
            cur_fn_strict.is_strict = True;
        }
        # ES §11.2.1 Directive Prologue: scan ALL leading string-literal
        # ExpressionStatements (not just the first), so `"use strict"` still
        # activates strict mode when preceded by other (non-standard) directives
        # like `"bogus directive"; "use strict";` (directive-prologue/14.1-*).
        if nd.body is not None {
            dpi: int = 0;
            while dpi < len(nd.body.children) {
                dp_nd: ASTNode = nd.body.children[dpi];
                if dp_nd.ntype != ASTNodeType.ExpressionStatement
                    or dp_nd.expression is None
                    or dp_nd.expression.ntype != ASTNodeType.Literal
                    or dp_nd.expression.kind != "string" {
                    dpi = len(nd.body.children);  # end of prologue → stop
                    continue;
                }
                if dp_nd.expression.value == "use strict" {
                    cur_fn_strict.is_strict = True;
                }
                dpi = dpi + 1;
            }
        }
        dp_slots: list[int] = [];
        dp_idx: int = 0;
        # Collect default-parameter (AssignmentPattern) info for post-decl emit.
        default_params: list[int] = [];  # slot indices
        default_exprs: list[ASTNode] = [];  # right-hand default expressions
        default_param_names: list[str] = [];  # binding name for each default (for name inference)
        default_src_idx: list[int] = [];  # source-order param index for each default (param TDZ)
        # Ordered list of every simple-parameter binding name (source order).  Used
        # to compute which params are still uninitialized (TDZ) while a given
        # default expression is evaluated.  Only Identifier params can be observed
        # by name in a default; destructured params bind synthetic names.
        param_order: list[str] = [];
        param_src_pos: int = 0;
        for param in nd.params {
            if param.ntype == ASTNodeType.Identifier {
                fn: CompiledFunction = self._fn();
                fn.params.append(param.name);
                self._declare(param.name, "var");
                param_order.append(param.name);
            } elif param.ntype == ASTNodeType.RestElement {
                if param.argument is not None {
                    fn: CompiledFunction = self._fn();
                    if param.argument.ntype == ASTNodeType.ArrayPattern
                        or param.argument.ntype == ASTNodeType.ObjectPattern {
                        # Destructured rest parameter: `function f(...[a, b]) {}` /
                        # `function f(...{length}) {}` (ES §15.1.5 FunctionRestParameter
                        # : BindingRestElement → BindingPattern). The VM materializes the
                        # collected rest array into the LAST param slot, so reserve a
                        # synthetic slot there and destructure it in the emit loop below.
                        synth_rest: str = "__dp_" + str(dp_idx);
                        dp_idx = dp_idx + 1;
                        fn.params.append(synth_rest);
                        fn.has_rest = True;
                        dp_slot: int = self._declare(synth_rest, "var");
                        dp_slots.append(dp_slot);
                        param_order.append(synth_rest);
                    } else {
                        fn.params.append(param.argument.name);
                        fn.has_rest = True;
                        self._declare(param.argument.name, "var");
                        param_order.append(param.argument.name);
                    }
                }
            } elif param.ntype == ASTNodeType.AssignmentPattern {
                if param.left is not None
                    and param.left.ntype == ASTNodeType.Identifier {
                    fn: CompiledFunction = self._fn();
                    fn.params.append(param.left.name);
                    dfp_slot: int = self._declare(param.left.name, "var");
                    if param.right is not None {
                        default_params.append(dfp_slot);
                        default_exprs.append(param.right);
                        default_param_names.append(param.left.name);
                        default_src_idx.append(param_src_pos);
                    }
                    param_order.append(param.left.name);
                } elif param.left is not None
                    and (
                        param.left.ntype == ASTNodeType.ObjectPattern
                        or param.left.ntype == ASTNodeType.ArrayPattern
                    ) {
                    # Destructured parameter WITH a default initializer, e.g.
                    # `function f([a, b] = [1, 2]) {}`.  The argument lands in a
                    # synthetic slot; the default expression substitutes when the
                    # argument is `undefined`, and the resulting value is then
                    # destructured (handled in the destructure-emit loop below).
                    synth_name: str = "__dp_" + str(dp_idx);
                    dp_idx = dp_idx + 1;
                    fn: CompiledFunction = self._fn();
                    fn.params.append(synth_name);
                    dp_slot: int = self._declare(synth_name, "var");
                    dp_slots.append(dp_slot);
                    if param.right is not None {
                        default_params.append(dp_slot);
                        default_exprs.append(param.right);
                        default_param_names.append("");
                        default_src_idx.append(param_src_pos);
                    }
                    param_order.append(synth_name);
                }
            } elif param.ntype == ASTNodeType.ObjectPattern
                or param.ntype == ASTNodeType.ArrayPattern {
                synth_name: str = "__dp_" + str(dp_idx);
                dp_idx = dp_idx + 1;
                fn: CompiledFunction = self._fn();
                fn.params.append(synth_name);
                dp_slot: int = self._declare(synth_name, "var");
                dp_slots.append(dp_slot);
                param_order.append(synth_name);
            }
            param_src_pos = param_src_pos + 1;
        }
        # For non-arrow functions, declare the implicit `arguments` local.
        # ECMAScript: every non-arrow function has an `arguments` array-like
        # object that contains all passed arguments.  Arrow functions inherit
        # `arguments` from their enclosing scope (handled by free-var capture).
        #
        # PERF/LEAK: materializing `arguments` builds a per-call JSObject + property
        # map (mapped to the frame locals) that accumulates in the object table and
        # is never reclaimed by default (the table GC is off) → unbounded per-call
        # memory growth (found via massif: every `add(a,b){return a+b}` call leaked).
        # A function whose SOURCE never mentions `arguments` (nor `eval`, which could
        # reference it via a dynamically-built string) provably cannot observe the
        # arguments object, so we skip allocating its slot entirely — the dominant
        # case. The source-slice covers nested functions/computed keys too, so this
        # never drops a slot that is actually needed (a nested `arguments` merely
        # keeps the outer slot — safe, just a missed optimization). When the source
        # text is unavailable (e.g. the standalone js_compiler builds .jsbc without
        # it) we conservatively keep the old always-declare behavior.
        args_slot: int = -1;
        if nd.ntype != ASTNodeType.ArrowFunctionExpr {
            aa_needs: bool = True;
            aa_sa: int = nd.loc.start;
            aa_sb: int = nd.loc.end;
            if len(self.source_text) > 0
                and aa_sa >= 0
                and aa_sb > aa_sa
                and aa_sb <= len(self.source_text) {
                aa_needs = self._src_range_has_args_ref(aa_sa, aa_sb);
            }
            if aa_needs {
                args_slot = self._declare("arguments", "var");
            }
        }
        # For named functions: emit LOAD_SELF + STORE_LOCAL(self_slot) so the
        # function can refer to itself recursively via its declared name.
        if self_slot >= 0 {
            self._emit(make_instruction(Opcode.LOAD_SELF, 0, 0, 0));
            self._emit(make_instruction(Opcode.STORE_LOCAL, self_slot, 0, 0));
        }
        param_names: dict[str, bool] = {};
        for pname_nd in nd.params {
            if pname_nd.ntype == ASTNodeType.Identifier {
                param_names[pname_nd.name] = True;
            } elif pname_nd.ntype == ASTNodeType.AssignmentPattern {
                if pname_nd.left is not None
                    and pname_nd.left.ntype == ASTNodeType.Identifier {
                    param_names[pname_nd.left.name] = True;
                }
            } elif pname_nd.ntype == ASTNodeType.RestElement {
                if pname_nd.argument is not None {
                    param_names[pname_nd.argument.name] = True;
                }
            }
        }
        self.param_names = param_names;
        # Simple parameter list = plain identifiers only (no default, pattern
        # or rest): then body vars share the parameter bindings.
        pbs_split: bool = False;
        for pbs_p in nd.params {
            if pbs_p.ntype != ASTNodeType.Identifier {
                pbs_split = True;
            }
        }
        self.param_body_split = pbs_split;
        self.default_param_body_vars = {};
        if nd.body is not None {
            for dp_stmt in nd.body.children {
                if dp_stmt.ntype == ASTNodeType.VariableDeclaration
                    and dp_stmt.value == "var" {
                    for dp_decl in dp_stmt.declarations {
                        if dp_decl.id is not None
                            and dp_decl.id.ntype == ASTNodeType.Identifier {
                            self.default_param_body_vars[dp_decl.id.name] = True;
                        }
                    }
                } elif dp_stmt.ntype == ASTNodeType.FunctionDeclaration {
                    if dp_stmt.id is not None {
                        self.default_param_body_vars[dp_stmt.id.name] = True;
                    }
                }
            }
        }
        # ── Parameter binding, left to right (ES §10.2.11) ───────────────
        # Each parameter is fully bound — its default substituted when the
        # argument is undefined, then, for a pattern, destructured — before the
        # next parameter's initializer runs, so a default may read names that an
        # EARLIER destructured parameter bound: `function f({x}, y = x)`,
        # `function f([a], b = a * 2)`. Evaluating every default first and
        # destructuring afterwards left those names unresolved (ReferenceError).
        # Defaults compile with in_default_params set (param TDZ, eval rules), as
        # before; destructuring keeps compiling with it off.
        self.default_params_in_arrow = nd.ntype == ASTNodeType.ArrowFunctionExpr;
        # Param TDZ (ES §10.2.11): every parameter binding is uninitialized until its
        # own value is assigned, processed left-to-right.  Seed the set with all
        # param names; as each parameter at source position `pb_pos` is bound, the
        # params BEFORE it are already bound (cleared), while the current param and
        # all later params remain in TDZ — a reference to one throws ReferenceError.
        self.param_tdz = {};
        for pt_name in param_order {
            if pt_name != "" {
                self.param_tdz[pt_name] = True;
            }
        }
        pt_cleared_upto: int = 0;
        dfp_i: int = 0;
        dp_pi: int = 0;
        pb_pos: int = 0;
        for param in nd.params {
            # Clear TDZ for every param strictly before this one — they are bound.
            while pt_cleared_upto < pb_pos {
                if pt_cleared_upto < len(param_order) {
                    clr_nm: str = param_order[pt_cleared_upto];
                    if clr_nm in self.param_tdz {
                        del self.param_tdz[clr_nm];
                    }
                }
                pt_cleared_upto = pt_cleared_upto + 1;
            }
            # Default initializer of this parameter (default_src_idx is source order).
            if dfp_i < len(default_params)
                and dfp_i < len(default_src_idx)
                and default_src_idx[dfp_i] == pb_pos {
                dfp_s: int = default_params[dfp_i];
                self.in_default_params = True;
                self._emit(make_instruction(Opcode.LOAD_LOCAL, dfp_s, 0, 0));
                dfp_j: int = self._jump(Opcode.JUMP_IF_UNDEFINED);
                dfp_je: int = self._jump(Opcode.JUMP);
                self._patch(dfp_j);
                self._op(Opcode.POP);
                self.compile_expr(default_exprs[dfp_i]);
                # ECMAScript §13.3.3.6: if the initializer is an anonymous function/arrow,
                # infer the name from the binding identifier (SingleNameBinding rule).
                if dfp_i < len(default_param_names) {
                    self._maybe_infer_fn_name(
                        default_exprs[dfp_i], default_param_names[dfp_i]
                    );
                }
                self._patch(dfp_je);
                self._emit(make_instruction(Opcode.STORE_LOCAL, dfp_s, 0, 0));
                self.in_default_params = False;
                dfp_i = dfp_i + 1;
            }
            # Bare destructured parameter: `function f([a, b]) {}` / `function f({x}) {}`.
            if param.ntype == ASTNodeType.ObjectPattern
                or param.ntype == ASTNodeType.ArrayPattern {
                slot_v: int = dp_slots[dp_pi];
                self._emit(make_instruction(Opcode.LOAD_LOCAL, slot_v, 0, 0));
                if param.ntype == ASTNodeType.ArrayPattern {
                    self.compile_arr_pattern(param, "var");
                } else {
                    self.compile_obj_pattern(param, "var");
                }
                dp_pi = dp_pi + 1;
                # Destructured parameter WITH a default: `function f([a, b] = [1, 2]) {}`.
                # The default was just substituted into the synthetic slot above; load
                # that value and destructure it.
            } elif param.ntype == ASTNodeType.AssignmentPattern
                and param.left is not None
                and (
                    param.left.ntype == ASTNodeType.ObjectPattern
                    or param.left.ntype == ASTNodeType.ArrayPattern
                ) {
                slot_v2: int = dp_slots[dp_pi];
                self._emit(make_instruction(Opcode.LOAD_LOCAL, slot_v2, 0, 0));
                if param.left.ntype == ASTNodeType.ArrayPattern {
                    self.compile_arr_pattern(param.left, "var");
                } else {
                    self.compile_obj_pattern(param.left, "var");
                }
                dp_pi = dp_pi + 1;
                # Destructured rest parameter: `function f(...[a, b]) {}`. The VM has
                # collected the rest array into the synthetic slot; load it and destructure.
            } elif param.ntype == ASTNodeType.RestElement
                and param.argument is not None
                and (
                    param.argument.ntype == ASTNodeType.ObjectPattern
                    or param.argument.ntype == ASTNodeType.ArrayPattern
                ) {
                slot_vr: int = dp_slots[dp_pi];
                self._emit(make_instruction(Opcode.LOAD_LOCAL, slot_vr, 0, 0));
                if param.argument.ntype == ASTNodeType.ArrayPattern {
                    self.compile_arr_pattern(param.argument, "var");
                } else {
                    self.compile_obj_pattern(param.argument, "var");
                }
                dp_pi = dp_pi + 1;
            }
            pb_pos = pb_pos + 1;
        }
        self.in_default_params = False;
        self.param_tdz = {};
        # For generators / async generators, mark the end of the parameter-binding
        # prologue. The VM runs [0, gen_prologue_end_ip) eagerly at generator
        # creation so an abrupt completion in a default/destructured parameter is
        # raised at call time (B5). Recorded as the current code offset.
        if nd.is_generator {
            self._fn().gen_prologue_end_ip = len(self._fn().code);
        }
        # (Strict-mode detection moved above, before parameter compilation.)
        # ── Direct-eval → dynamic name resolution (ES §19.2.1.3) ─────────────
        # A SLOPPY-mode function body that contains a direct `eval(...)` call may have
        # `var` bindings created at runtime by that eval.  Such a binding lives in THIS
        # function's variable environment and must SHADOW a captured outer binding of
        # the same name.  A statically-resolved LOAD_FREE/LOAD_LOCAL cannot see it, so
        # force the body's bare-identifier load/store through LOAD_NAME/STORE_NAME —
        # which consult the frame's runtime dyn_var bindings first (VM _eval_scope_*).
        # Reuse the `with_depth` gate (its VM path already does local→dyn_var→free→
        # global name resolution and resolve-once compound assignment); with_objs is
        # empty here so no with-object is consulted.  Strict eval cannot leak `var`
        # bindings into the caller, so it needs no dynamic scope.
        # (test262 compound-assignment/S11.13.2_A6.*_T1.)
        if self.with_depth == 0
            and not self._fn().is_strict
            and nd.body is not None
            and self._fn_body_has_direct_eval(nd.body.children, nd.params) {
            self.with_depth = 1;
        }
        # ── Body hoist Phase A: reserve fn-scope slots for hoisted names ─────
        # FunctionDeclaration and ClassDeclaration names must be declared in the
        # function scope BEFORE pushing the body block scope, so body let/const
        # slots do not alias the same local indices as hoisted var bindings.
        if nd.body is not None
            and not (
                nd.ntype == ASTNodeType.ArrowFunctionExpr and nd.expression_body
            ) {
            # ES VarDeclaredNames is RECURSIVE (blocks / if / try / catch /
            # loops — not nested functions): every var name must get its
            # fn-scope slot at FunctionDeclarationInstantiation, BEFORE any
            # statement compiles.  Collecting only top-level declarations made
            # a reference emitted earlier in the body bind a global instead of
            # the local (`e = 3; try {…} catch (e) { var e = 4; }` threw
            # "e is not defined" in strict mode — rollup catch-deconflict output).
            hv_names_a: list[str] = self.collect_toplevel_var_names(nd.body.children);
            hv_seen_a: dict[str, bool] = {};
            for hv_name_a in hv_names_a {
                if hv_name_a in hv_seen_a {
                    continue;
                }
                hv_seen_a[hv_name_a] = True;
                if hv_name_a in self.param_names {
                    self._param_body_var_slot(hv_name_a);
                } else {
                    self._declare(hv_name_a, "var");
                }
            }
            for hoist_stmt in nd.body.children {
                if hoist_stmt.ntype == ASTNodeType.FunctionDeclaration {
                    if hoist_stmt.id is not None {
                        self._declare(hoist_stmt.id.name, "var");
                    }
                } elif hoist_stmt.ntype == ASTNodeType.ClassDeclaration {
                    if hoist_stmt.id is not None {
                        cls_tdz_slot: int = self._declare(hoist_stmt.id.name, "let");
                        if cls_tdz_slot >= 0 {
                            self._emit_tdz_store(cls_tdz_slot);
                        } else {
                            self._emit(make_instruction(Opcode.TDZ_CLASS, 0, 0, 0));
                            self._emit_store_global_decl(hoist_stmt.id.name);
                        }
                    }
                }
            }
            # Annex B.3.3: in sloppy mode, block/if/switch/labelled function
            # declarations also create a function-scoped `var` binding, initialized
            # to `undefined` at FunctionDeclarationInstantiation — before any
            # statement runs.  Skip names that would collide with a parameter or
            # a lexical that would make a replacing `var` an early error.
            if not self._fn().is_strict and nd.body is not None {
                ab_names: list[str] = [];
                self._collect_block_fn_names(nd.body, ab_names, True);
                ab_lex: dict[str, bool] = {};
                self._collect_annexb_blocking_lexicals(nd.body, ab_lex);
                ab_seen: dict[str, bool] = {};
                for ab_name in ab_names {
                    if ab_name in ab_seen {
                        continue;
                    }
                    ab_seen[ab_name] = True;
                    if ab_name in self.param_names {
                        continue;
                    }
                    if ab_name in ab_lex {
                        continue;
                    }
                    # argumentsObjectNeeded → "arguments" ∈ parameterNames (skip-arguments).
                    if ab_name == "arguments" and args_slot >= 0 {
                        continue;
                    }
                    # A binding already present at fn_base as let/const/class blocks.
                    ab_kind: str = self._get_kind(ab_name);
                    if ab_kind == "let" or ab_kind == "const" or ab_kind == "class" {
                        continue;
                    }
                    ab_slot: int = self._resolve_at_fn_base(ab_name);
                    if ab_slot < 0 {
                        ab_slot = self._declare(ab_name, "var");
                    }
                    if ab_slot >= 0 {
                        self.annexb_block_fn_names[ab_name] = True;
                        # Initialize to undefined (binding exists before evaluation).
                        self._op(Opcode.LOAD_UNDEFINED);
                        self._emit(make_instruction(Opcode.STORE_LOCAL, ab_slot, 0, 0));
                    }
                }
            }
        }
        self._push_scope(False);
        # ── Body hoist Phase B: pre-declare let/const with TDZ in body scope ─
        # Includes destructuring pattern names so nested function declarations
        # compiled during the hoist pass can `_capture` them (otherwise they
        # fall through to LOAD_GLOBAL and see `undefined` — e.g. common's
        # `const { inspect } = require('util'); function mustCall(){ inspect() }`).
        if nd.body is not None
            and not (
                nd.ntype == ASTNodeType.ArrowFunctionExpr and nd.expression_body
            ) {
            for hoist_stmt in nd.body.children {
                if hoist_stmt.ntype == ASTNodeType.VariableDeclaration {
                    vd_kind_pre: str = hoist_stmt.value;
                    if vd_kind_pre == "let" or vd_kind_pre == "const" {
                        for vd_decl_pre in hoist_stmt.declarations {
                            if vd_decl_pre.id is None {
                                continue;
                            }
                            hp_names: list[str] = [];
                            if vd_decl_pre.id.ntype == ASTNodeType.Identifier {
                                hp_names.append(vd_decl_pre.id.name);
                            } elif vd_decl_pre.id.ntype == ASTNodeType.ObjectPattern
                                or vd_decl_pre.id.ntype == ASTNodeType.ArrayPattern {
                                self._collect_pattern_names(vd_decl_pre.id, hp_names);
                            }
                            for hp_name in hp_names {
                                # VARP-C-002 / VARP-C-003: a body-level let/const sharing a
                                # name with a function-scope var or hoisted function
                                # declaration (both declared at fn_base in Phase A) is an
                                # early error — they occupy the same lexical environment.
                                fnb: int = self._fn_base();
                                fnb_sc: Scope = self.scope_stack[fnb];
                                fnb_k: str = "var";
                                if hp_name in fnb_sc.var_kinds {
                                    fnb_k = fnb_sc.var_kinds[hp_name];
                                }
                                # Only a genuine `var`/function binding at fn_base conflicts.
                                # Exempt parameters, the implicit `arguments` binding, and the
                                # function-expression self-name (all shadowable).
                                fnb_conflict: bool = hp_name in fnb_sc.vars
                                    and (fnb_k == "var" or fnb_k == "fnhoist");
                                fnb_exempt: bool = hp_name in self.param_names
                                    or hp_name == "arguments"
                                    or hp_name == self.fn_self_name;
                                if fnb_conflict and not fnb_exempt {
                                    self._syntax_error(
                                        "SyntaxError: Identifier '"
                                            + hp_name
                                            + "' has already been declared"
                                    );
                                }
                                hslot: int = self._declare(hp_name, vd_kind_pre);
                                if hslot >= 0 {
                                    self._emit_tdz_store(hslot);
                                    self.hoist_predeclared[
                                        self._hoist_predecl_key(hp_name)
                                    ] = True;
                                }
                            }
                        }
                    }
                }
            }
        }
        # ── Hoist function declarations (ES spec §10.2.11) ─────────────────────
        # Function declarations are initialized at scope entry per ECMAScript spec.
        # Emit MAKE_FUNCTION + STORE_LOCAL for every direct FunctionDeclaration
        # at the top of the function body before any other statement executes.
        # This is safe because MAKE_CELL instructions are prepended by _pop_fn()
        # before ALL other code, so captured variables are already Cells when
        # MAKE_FUNCTION runs. Closures capture the Cell (a mutable reference),
        # so later assignments in the outer scope are visible inside the closure.
        # The body compilation loop below skips FunctionDeclarations to avoid
        # double-compilation.
        if nd.body is not None
            and not (
                nd.ntype == ASTNodeType.ArrowFunctionExpr and nd.expression_body
            ) {
            for hoist_fn_nd in nd.body.children {
                if hoist_fn_nd.ntype == ASTNodeType.FunctionDeclaration {
                    self.compile_function_decl(hoist_fn_nd);
                }
            }
        }
        # Compile body
        if nd.ntype == ASTNodeType.ArrowFunctionExpr and nd.expression_body {
            if nd.body is not None {
                self.compile_expr(nd.body);
            } else {
                self._op(Opcode.LOAD_UNDEFINED);
            }
            self._op(Opcode.RETURN);
        } else {
            if nd.body is not None {
                for stmt in nd.body.children {
                    # Skip FunctionDeclarations — already compiled in the hoist pass above.
                    if stmt.ntype == ASTNodeType.FunctionDeclaration {
                        continue;
                    }
                    self.compile_stmt(stmt);
                }
            }
            if COMPILER_DEBUG_MODE {
                compiler_debug(
                    "  _compile_function: about to emit RETURN_UNDEFINED for fn="
                        + self._fn().name
                );
            }
            self._op(Opcode.RETURN_UNDEFINED);
            if COMPILER_DEBUG_MODE {
                compiler_debug("  _compile_function: RETURN_UNDEFINED emitted OK");
            }
        }
        self._pop_scope();
        compiled: CompiledFunction = self._pop_fn();
        # Preserve source slice for Function.prototype.toString.
        if len(self.source_text) > 0 {
            src_a: int = nd.loc.start;
            src_b: int = nd.loc.end;
            if src_a >= 0 and src_b > src_a and src_b <= len(self.source_text) {
                compiled.source = self.source_text[src_a:src_b];
            }
        }
        # param_base = slot offset where params live.
        # For named functions: slot 0 is reserved for self-ref, params start at 1.
        # Use a typed local for the field assignment to avoid cross-module GEP crash.
        pb: int = 0;
        if self_slot >= 0 {
            pb = 1;
        }
        compiled.param_base = pb;
        # Store arguments slot for the VM to populate at call time.
        compiled.arguments_slot = args_slot;
        # ExpectedArgumentCount: params before first default or rest (ECMAScript §17.2.5).
        eac: int = 0;
        for ep in nd.params {
            if ep.ntype == ASTNodeType.AssignmentPattern
                or ep.ntype == ASTNodeType.RestElement {
                break;
            }
            eac = eac + 1;
        }
        compiled.expected_arg_count = eac;
        # Propagate is_generator flag from AST node.
        if nd.is_generator {
            compiled.is_generator = True;
        }
        # Propagate is_async flag from AST node.
        if nd.is_async {
            compiled.is_async = True;
        }
        # Propagate is_method (concise method/accessor → no own `prototype`).
        if nd.is_method {
            compiled.is_method = True;
        }
        self.with_depth = saved_with_depth;  # A4: restore enclosing with-depth
        self.hoist_predeclared = saved_hoist_predeclared;  # restore enclosing lexical predeclare state
        self.super_prop_allowed = saved_super_prop;  # B9: restore enclosing super-context
        self.super_is_static = saved_super_static;
        self.super_call_allowed = saved_super_call;
        return compiled;
    }

    # ══════════════════════════════════════════════════════════════════════
    # Top-level entry point
    # ══════════════════════════════════════════════════════════════════════

    """Annex B.3.3: collect the names of `function` declarations nested inside
    blocks / if / switch / loops / try of `body`, WITHOUT descending into nested
    function bodies (they have their own scope).  When `top` is True the direct
    children of `body` are skipped (those are ordinary FunctionDeclarationInstantiation
    hoists, not the Annex-B block case).  Iterative worklist to avoid deep recursion.

    Catch clauses: only a *destructuring* CatchParameter suppresses collecting
    the name (B.3.5 early error for `var`).  A simple `catch (f)` does NOT
    suppress — Annex B still creates the function-scoped binding (no-skip-try)."""
    def _collect_block_fn_names(body: ASTNode, out: list[str], top: bool) -> None {
        if body is None {
            return;
        }
        # Seed the worklist with the containers directly under `body`.  At the top
        # level, a direct-child FunctionDeclaration is NOT an Annex-B case; but its
        # block/if/etc. siblings ARE candidates to descend into.
        # Each work item is accompanied by the set of *pattern* catch-parameter
        # names in enclosing catch clauses.
        cbf_work: list[ASTNode] = [];
        cbf_catch: list[dict[str, bool]] = [];
        empty_cp: dict[str, bool] = {};
        for cbf_s in body.children {
            if cbf_s.ntype == ASTNodeType.FunctionDeclaration {
                if not top and cbf_s.id is not None {
                    out.append(cbf_s.id.name);
                }
            } else {
                cbf_work.append(cbf_s);
                cbf_catch.append(empty_cp);
            }
        }
        while len(cbf_work) > 0 {
            cbf_n: ASTNode = cbf_work[len(cbf_work) - 1];
            del cbf_work[len(cbf_work) - 1];
            cp_env: dict[str, bool] = cbf_catch[len(cbf_catch) - 1];
            del cbf_catch[len(cbf_catch) - 1];
            if cbf_n is None {
                continue;
            }
            cbt: ASTNodeType = cbf_n.ntype;
            # Do NOT descend into function/class bodies — they open a new scope.
            if cbt == ASTNodeType.FunctionDeclaration {
                if cbf_n.id is not None and cbf_n.id.name not in cp_env {
                    out.append(cbf_n.id.name);
                }
            } elif cbt == ASTNodeType.BlockStatement {
                for cbf_c in cbf_n.children {
                    cbf_work.append(cbf_c);
                    cbf_catch.append(cp_env);
                }
            } elif cbt == ASTNodeType.IfStatement {
                if cbf_n.consequent is not None {
                    cbf_work.append(cbf_n.consequent);
                    cbf_catch.append(cp_env);
                }
                if cbf_n.alternate is not None {
                    cbf_work.append(cbf_n.alternate);
                    cbf_catch.append(cp_env);
                }
            } elif cbt == ASTNodeType.SwitchStatement {
                for cbf_case in cbf_n.cases {
                    for cbf_cs in cbf_case.children {
                        cbf_work.append(cbf_cs);
                        cbf_catch.append(cp_env);
                    }
                }
            } elif cbt == ASTNodeType.ForStatement
                or cbt == ASTNodeType.ForInStatement
                or cbt == ASTNodeType.ForOfStatement
                or cbt == ASTNodeType.WhileStatement
                or cbt == ASTNodeType.DoWhileStatement {
                if cbf_n.body is not None {
                    cbf_work.append(cbf_n.body);
                    cbf_catch.append(cp_env);
                }
            } elif cbt == ASTNodeType.LabeledStatement {
                if cbf_n.body is not None {
                    cbf_work.append(cbf_n.body);
                    cbf_catch.append(cp_env);
                }
            } elif cbt == ASTNodeType.TryStatement {
                if cbf_n.body is not None {
                    cbf_work.append(cbf_n.body);
                    cbf_catch.append(cp_env);
                }
                if cbf_n.handler is not None {
                    # Only destructuring CatchParameter names suppress Annex B.
                    new_cp: dict[str, bool] = {};
                    for ck in cp_env {
                        new_cp[ck] = True;
                    }
                    if cbf_n.handler.param is not None {
                        hp: ASTNode = cbf_n.handler.param;
                        if hp.ntype == ASTNodeType.ArrayPattern
                            or hp.ntype == ASTNodeType.ObjectPattern {
                            cp_ns: list[str] = [];
                            self._collect_pattern_names(hp, cp_ns);
                            for cpn in cp_ns {
                                new_cp[cpn] = True;
                            }
                        }
                    }
                    if cbf_n.handler.body is not None {
                        cbf_work.append(cbf_n.handler.body);
                        cbf_catch.append(new_cp);
                    }
                }
                if cbf_n.finalizer is not None {
                    cbf_work.append(cbf_n.finalizer);
                    cbf_catch.append(cp_env);
                }
            }
        }
    }

    """Collect lexical binding names in `body` that would make a function-scoped
    `var` of the same name an early error (LexicallyDeclaredNames ∩ VarDeclaredNames).
    Includes let/const/class and for-head lexicals, plus destructuring catch
    parameters.  Excludes simple `catch (id)` BindingIdentifiers (B.3.5) and does
    not descend into nested function/class bodies."""
    def _collect_annexb_blocking_lexicals(body: ASTNode, out: dict[str, bool]) -> None {
        if body is None {
            return;
        }
        abx_work: list[ASTNode] = [];
        for abx_s0 in body.children {
            abx_work.append(abx_s0);
        }
        while len(abx_work) > 0 {
            abx_n: ASTNode = abx_work[len(abx_work) - 1];
            del abx_work[len(abx_work) - 1];
            if abx_n is None {
                continue;
            }
            abx_t: ASTNodeType = abx_n.ntype;
            if abx_t == ASTNodeType.FunctionDeclaration
                or abx_t == ASTNodeType.FunctionExpression
                or abx_t == ASTNodeType.ArrowFunctionExpr
                or abx_t == ASTNodeType.ClassExpression {
                continue;
            } elif abx_t == ASTNodeType.ClassDeclaration {
                if abx_n.id is not None {
                    out[abx_n.id.name] = True;
                }
                continue;
            } elif abx_t == ASTNodeType.VariableDeclaration {
                if abx_n.value == "let"
                    or abx_n.value == "const"
                    or abx_n.value == "using"
                    or abx_n.value == "await using" {
                    for abx_d in abx_n.declarations {
                        if abx_d.id is not None {
                            abx_ns: list[str] = [];
                            self._collect_pattern_names(abx_d.id, abx_ns);
                            for abx_nm in abx_ns {
                                out[abx_nm] = True;
                            }
                        }
                    }
                }
            } elif abx_t == ASTNodeType.BlockStatement {
                for abx_c in abx_n.children {
                    abx_work.append(abx_c);
                }
            } elif abx_t == ASTNodeType.IfStatement {
                if abx_n.consequent is not None {
                    abx_work.append(abx_n.consequent);
                }
                if abx_n.alternate is not None {
                    abx_work.append(abx_n.alternate);
                }
            } elif abx_t == ASTNodeType.SwitchStatement {
                for abx_case in abx_n.cases {
                    for abx_cs in abx_case.children {
                        abx_work.append(abx_cs);
                    }
                }
            } elif abx_t == ASTNodeType.ForStatement {
                if abx_n.init is not None {
                    abx_work.append(abx_n.init);
                }
                if abx_n.body is not None {
                    abx_work.append(abx_n.body);
                }
            } elif abx_t == ASTNodeType.ForInStatement
                or abx_t == ASTNodeType.ForOfStatement {
                if abx_n.left is not None {
                    abx_work.append(abx_n.left);
                }
                if abx_n.body is not None {
                    abx_work.append(abx_n.body);
                }
            } elif abx_t == ASTNodeType.WhileStatement
                or abx_t == ASTNodeType.DoWhileStatement {
                if abx_n.body is not None {
                    abx_work.append(abx_n.body);
                }
            } elif abx_t == ASTNodeType.LabeledStatement
                or abx_t == ASTNodeType.WithStatement {
                if abx_n.body is not None {
                    abx_work.append(abx_n.body);
                }
            } elif abx_t == ASTNodeType.TryStatement {
                if abx_n.body is not None {
                    abx_work.append(abx_n.body);
                }
                if abx_n.handler is not None {
                    if abx_n.handler.param is not None {
                        hp2: ASTNode = abx_n.handler.param;
                        # Only pattern catch params block a replacing `var`.
                        if hp2.ntype == ASTNodeType.ArrayPattern
                            or hp2.ntype == ASTNodeType.ObjectPattern {
                            abx_cp: list[str] = [];
                            self._collect_pattern_names(hp2, abx_cp);
                            for abx_cn in abx_cp {
                                out[abx_cn] = True;
                            }
                        }
                    }
                    if abx_n.handler.body is not None {
                        abx_work.append(abx_n.handler.body);
                    }
                }
                if abx_n.finalizer is not None {
                    abx_work.append(abx_n.finalizer);
                }
            }
        }
    }

    """
    Collect the binding identifier names introduced by a binding target
    (Identifier or destructuring pattern), appending them to `out`.  Used by the
    var-hoist pre-pass so `var [a, b]` / `var {x}` hoist all of their bound names.
    """
    def _collect_pattern_names(pat: ASTNode | None, out: list[str]) -> None {
        if pat is None {
            return;
        }
        pt: ASTNodeType = pat.ntype;
        if pt == ASTNodeType.Identifier {
            # An array-pattern elision hole is represented as an Identifier named
            # "undefined" (see _parse_array_pattern). It is NOT a binding, so it must
            # not be collected — otherwise `[, , ...x]` collects "undefined" twice and
            # the let/const block pre-scan reports a false "already declared". Matches
            # the same guard in _predeclare_pattern_tdz.
            if pat.name != "" and pat.name != "undefined" {
                out.append(pat.name);
            }
        } elif pt == ASTNodeType.ArrayPattern {
            for el in pat.elements {
                self._collect_pattern_names(el, out);
            }
        } elif pt == ASTNodeType.ObjectPattern {
            for pp in pat.properties {
                if pp.ntype == ASTNodeType.Property {
                    # Property binding target lives in `.expression` (see make_property);
                    # `.value` is the string kind field ("init"), not an AST child.
                    if pp.expression is not None {
                        self._collect_pattern_names(pp.expression, out);
                    } elif pp.shorthand and pp.key is not None {
                        self._collect_pattern_names(pp.key, out);
                    }
                } elif pp.ntype == ASTNodeType.RestElement {
                    self._collect_pattern_names(pp.argument, out);
                } else {
                    self._collect_pattern_names(pp, out);
                }
            }
        } elif pt == ASTNodeType.AssignmentPattern {
            self._collect_pattern_names(pat.left, out);
        } elif pt == ASTNodeType.RestElement {
            self._collect_pattern_names(pat.argument, out);
        }
    }

    """True if `nd` (a statement/expression subtree) contains a DIRECT eval call —
    a CallExpression whose callee is the bare Identifier `eval` — reachable WITHOUT
    crossing into a nested function/class body (those open their own var scope, and
    their direct eval affects only their own bindings, ES §19.2.1.1). Used to force
    dynamic (LOAD_NAME/STORE_NAME) name resolution in the enclosing function body so
    an eval-introduced `var` shadows a captured outer binding (test262 compound-
    assignment/S11.13.2_A6.*_T1). Mirrors _ast_contains_await's field walk."""
    def _subtree_has_direct_eval(nd: ASTNode | None) -> bool {
        if nd is None {
            return False;
        }
        nt: ASTNodeType = nd.ntype;
        # Do NOT descend into a nested function/class body — new var scope.
        if nt == ASTNodeType.FunctionDeclaration
            or nt == ASTNodeType.FunctionExpression
            or nt == ASTNodeType.ArrowFunctionExpr
            or nt == ASTNodeType.ClassDeclaration
            or nt == ASTNodeType.ClassExpression {
            return False;
        }
        if nt == ASTNodeType.CallExpression
            and nd.callee is not None
            and nd.callee.ntype == ASTNodeType.Identifier
            and nd.callee.name == "eval" {
            return True;
        }
        if self._subtree_has_direct_eval(nd.expression) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.argument) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.init) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.body) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.left) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.right) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.consequent) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.alternate) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.cond_expr) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.callee) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.property) {
            return True;
        }
        if self._subtree_has_direct_eval(nd.object) {
            return True;
        }
        # Property / MethodDefinition computed key: `{[eval("var x=…")]: …}` in a
        # destructuring PARAMETER introduces a var into the function scope (test262
        # function-code/eval-param-env-with-computed-key). The property's VALUE node is
        # stored in `.expression` (walked above); `.value` is an unrelated string field.
        if self._subtree_has_direct_eval(nd.key) {
            return True;
        }
        for ch in nd.children {
            if self._subtree_has_direct_eval(ch) {
                return True;
            }
        }
        for d in nd.declarations {
            if self._subtree_has_direct_eval(d) {
                return True;
            }
        }
        for el in nd.elements {
            if self._subtree_has_direct_eval(el) {
                return True;
            }
        }
        for a in nd.arguments {
            if self._subtree_has_direct_eval(a) {
                return True;
            }
        }
        for p in nd.properties {
            if self._subtree_has_direct_eval(p) {
                return True;
            }
        }
        # SequenceExpression `(a, eval(...), b)` and TemplateLiteral interpolations keep
        # their parts here — the compound-assign RHS `x *= (eval("var x=2"), 4)` hides
        # its eval in `.expressions` (test262 compound-assignment/S11.13.2_A6.*_T1).
        for ex in nd.expressions {
            if self._subtree_has_direct_eval(ex) {
                return True;
            }
        }
        return False;
    }

    """True if the function whose body statements are `stmts` (and parameter default
    expressions `params`) contains a direct eval call in its OWN scope."""
    def _fn_body_has_direct_eval(stmts: list[ASTNode], params: list[ASTNode]) -> bool {
        for s in stmts {
            if self._subtree_has_direct_eval(s) {
                return True;
            }
        }
        for p in params {
            if self._subtree_has_direct_eval(p) {
                return True;
            }
        }
        return False;
    }

    """ES VarDeclaredNames: collect every function-scoped `var` name reachable
    from `stmts` — descending into blocks / if / loops / try / switch / with /
    labels but NOT into nested functions or classes (those open new var scopes).
    Shared by top-level var hoisting and the direct-eval EvalDeclarationInstantiation
    SyntaxError check (ES §19.2.1.3)."""
    def collect_toplevel_var_names(stmts: list[ASTNode]) -> list[str] {
        hv_names: list[str] = [];
        hv_work: list[ASTNode] = [];
        hv_wi: int = 0;
        while hv_wi < len(stmts) {
            hv_work.append(stmts[hv_wi]);
            hv_wi = hv_wi + 1;
        }
        while len(hv_work) > 0 {
            hv_st: ASTNode = hv_work[len(hv_work) - 1];
            del hv_work[len(hv_work) - 1];
            if hv_st is None {
                continue;
            }
            hv_nt: ASTNodeType = hv_st.ntype;
            if hv_nt == ASTNodeType.FunctionDeclaration
                or hv_nt == ASTNodeType.FunctionExpression
                or hv_nt == ASTNodeType.ArrowFunctionExpr
                or hv_nt == ASTNodeType.ClassDeclaration
                or hv_nt == ASTNodeType.ClassExpression {
                continue;
            } elif hv_nt == ASTNodeType.VariableDeclaration {
                if hv_st.value == "var" {
                    for hv_d in hv_st.declarations {
                        if hv_d.id is not None {
                            self._collect_pattern_names(hv_d.id, hv_names);
                        }
                    }
                }
            } elif hv_nt == ASTNodeType.BlockStatement {
                for hv_c in hv_st.children {
                    hv_work.append(hv_c);
                }
            } elif hv_nt == ASTNodeType.IfStatement {
                if hv_st.consequent is not None {
                    hv_work.append(hv_st.consequent);
                }
                if hv_st.alternate is not None {
                    hv_work.append(hv_st.alternate);
                }
            } elif hv_nt == ASTNodeType.ForStatement {
                if hv_st.init is not None {
                    hv_work.append(hv_st.init);
                }
                if hv_st.body is not None {
                    hv_work.append(hv_st.body);
                }
            } elif hv_nt == ASTNodeType.ForInStatement {
                if hv_st.left is not None {
                    hv_work.append(hv_st.left);
                }
                if hv_st.body is not None {
                    hv_work.append(hv_st.body);
                }
            } elif hv_nt == ASTNodeType.ForOfStatement {
                if hv_st.left is not None {
                    hv_work.append(hv_st.left);
                }
                if hv_st.body is not None {
                    hv_work.append(hv_st.body);
                }
            } elif hv_nt == ASTNodeType.WhileStatement {
                if hv_st.body is not None {
                    hv_work.append(hv_st.body);
                }
            } elif hv_nt == ASTNodeType.DoWhileStatement {
                if hv_st.body is not None {
                    hv_work.append(hv_st.body);
                }
            } elif hv_nt == ASTNodeType.WithStatement {
                if hv_st.body is not None {
                    hv_work.append(hv_st.body);
                }
            } elif hv_nt == ASTNodeType.LabeledStatement {
                if hv_st.body is not None {
                    hv_work.append(hv_st.body);
                }
            } elif hv_nt == ASTNodeType.TryStatement {
                if hv_st.body is not None {
                    hv_work.append(hv_st.body);
                }
                if hv_st.handler is not None {
                    hv_work.append(hv_st.handler);
                }
                if hv_st.finalizer is not None {
                    hv_work.append(hv_st.finalizer);
                }
            } elif hv_nt == ASTNodeType.CatchClause {
                if hv_st.body is not None {
                    hv_work.append(hv_st.body);
                }
            } elif hv_nt == ASTNodeType.SwitchStatement {
                for hv_cs in hv_st.cases {
                    for hv_cc in hv_cs.children {
                        hv_work.append(hv_cc);
                    }
                }
            } elif hv_nt == ASTNodeType.ExportNamedDecl {
                # `export var x;` — descend into the wrapped declaration so the
                # exported var is hoisted like any top-level var.
                if hv_st.expression is not None {
                    hv_work.append(hv_st.expression);
                }
            }
        }
        return hv_names;
    }

    """
    Compile a Program nd and return the top-level CompiledFunction.
    Inner functions accumulate in self.all_fns.
    """
    def:pub compile_program(nd: ASTNode) -> CompiledFunction {
        if COMPILER_DEBUG_MODE {
            compiler_debug("→ compile_program  n_stmts=" + str(len(nd.children)));
        }
        self._push_fn("<main>");
        n_stmts: int = len(nd.children);
        # B7: direct eval inside a parameter expression may not introduce a binding
        # named `eval` (always) or `arguments` (only when the enclosing function has
        # its own `arguments`, i.e. non-arrow) — ES §15.1.1. Emit an early SyntaxError.
        if self.eval_in_param_expr > 0 {
            pe_forbid_args: bool = self.eval_in_param_expr == 1;
            if self._param_eval_has_forbidden_binding(nd, pe_forbid_args) {
                self._syntax_error(
                    "SyntaxError: Binding 'arguments' or 'eval' is not allowed in eval inside a parameter expression"
                );
            }
        }
        # ES §15.7.1: direct eval inside a class field initializer — top-level
        # `arguments` / `new.target` in the eval'd code are early SyntaxErrors.
        # Walk the whole program (statements + expressions) but do NOT descend into
        # nested ordinary functions (they have their own arguments/new.target);
        # arrows inherit both, so descend into them. Inlined (parser fn-count cap).
        if self.eval_field_forbid or self.eval_forbid_newtarget {
            # Two early-error scans over the eval'd program sharing the same boundary
            # (an ordinary FunctionExpression/Declaration has its own arguments AND
            # new.target — do NOT descend; arrows inherit both, so DO descend):
            #   • eval_field_forbid  (ES §15.7.1): DIRECT eval in a class field init
            #     must not reference `arguments` (the field init has none). `new.target`
            #     IS valid there, so it is not checked here.
            #   • eval_forbid_newtarget (ES §13.3.12): INDIRECT eval is global code —
            #     `new.target` (top level, or inside an inheriting arrow) is an error.
            ff_work: list[ASTNode] = [];
            for ff_c0 in nd.children {
                ff_work.append(ff_c0);
            }
            ff_wi: int = 0;
            while ff_wi < len(ff_work) {
                ff_s: ASTNode = ff_work[ff_wi];
                ff_wi = ff_wi + 1;
                if ff_s is None {
                    continue;
                }
                ff_t: ASTNodeType = ff_s.ntype;
                if self.eval_field_forbid
                    and ff_t == ASTNodeType.Identifier
                    and ff_s.name == "arguments" {
                    self._syntax_error(
                        "SyntaxError: 'arguments' is not allowed in eval within a class field initializer"
                    );
                    ff_wi = len(ff_work);
                    continue;
                }
                if self.eval_forbid_newtarget
                    and ff_t == ASTNodeType.MetaProperty
                    and ff_s.name == "new.target" {
                    self._syntax_error(
                        "SyntaxError: 'new.target' is only valid inside functions"
                    );
                    ff_wi = len(ff_work);
                    continue;
                }
                if ff_t == ASTNodeType.FunctionExpression
                    or ff_t == ASTNodeType.FunctionDeclaration {
                    continue;
                }
                if ff_s.left is not None {
                    ff_work.append(ff_s.left);
                }
                if ff_s.right is not None {
                    ff_work.append(ff_s.right);
                }
                if ff_s.argument is not None {
                    ff_work.append(ff_s.argument);
                }
                if ff_s.callee is not None {
                    ff_work.append(ff_s.callee);
                }
                if ff_s.object is not None {
                    ff_work.append(ff_s.object);
                }
                if ff_s.property is not None and ff_t != ASTNodeType.MetaProperty {
                    ff_work.append(ff_s.property);
                }
                if ff_s.cond_expr is not None {
                    ff_work.append(ff_s.cond_expr);
                }
                if ff_s.consequent is not None {
                    ff_work.append(ff_s.consequent);
                }
                if ff_s.alternate is not None {
                    ff_work.append(ff_s.alternate);
                }
                if ff_s.expression is not None {
                    ff_work.append(ff_s.expression);
                }
                if ff_s.body is not None {
                    ff_work.append(ff_s.body);
                }
                if ff_s.superclass is not None {
                    ff_work.append(ff_s.superclass);
                }
                if ff_s.init is not None {
                    ff_work.append(ff_s.init);
                }
                if ff_s.update is not None {
                    ff_work.append(ff_s.update);
                }
                for ff_a in ff_s.arguments {
                    ff_work.append(ff_a);
                }
                for ff_e in ff_s.elements {
                    if ff_e is not None {
                        ff_work.append(ff_e);
                    }
                }
                for ff_p in ff_s.properties {
                    ff_work.append(ff_p);
                }
                for ff_ex in ff_s.expressions {
                    ff_work.append(ff_ex);
                }
                for ff_pr in ff_s.params {
                    ff_work.append(ff_pr);
                }
                for ff_d in ff_s.declarations {
                    ff_work.append(ff_d);
                }
                for ff_c in ff_s.children {
                    ff_work.append(ff_c);
                }
            }
        }
        # Direct eval inherits the caller's strict mode (ES §19.2.1.1).
        if self.eval_force_strict {
            self._fn().is_strict = True;
        }
        # Top-level "use strict" prologue (SCP-FN-006 / LET-004 strict block functions)
        if n_stmts > 0 {
            first_stmt: ASTNode = nd.children[0];
            if first_stmt.ntype == ASTNodeType.ExpressionStatement
                and first_stmt.expression is not None {
                if first_stmt.expression.ntype == ASTNodeType.Literal {
                    if first_stmt.expression.value == "use strict" {
                        self._fn().is_strict = True;
                    }
                }
            }
        }
        # ── Module goal detection (import/export → allow TLA; else reject top-level await)
        # The parser records the goal on the Program node (`nd.is_async`, set when it
        # parsed under force_module/module detection) so an import-less module still
        # allows top-level `await`; also treat any import/export as module goal.
        is_module_goal: bool = nd.is_async;
        mg_i: int = 0;
        while mg_i < n_stmts {
            mg_s: ASTNode = nd.children[mg_i];
            if mg_s.ntype == ASTNodeType.ImportDeclaration
                or mg_s.ntype == ASTNodeType.ExportNamedDecl
                or mg_s.ntype == ASTNodeType.ExportDefaultDecl
                or mg_s.ntype == ASTNodeType.ExportAllDecl {
                is_module_goal = True;
            }
            mg_i = mg_i + 1;
        }
        self.compiling_module = is_module_goal;
        # Module code is always strict (ES §16.2.2).
        if is_module_goal {
            self._fn().is_strict = True;
        }
        # ── ECMAScript statement completion value (ES §14) ──────────────────
        # Script / eval evaluation returns the completion value of the last
        # statement that produced a non-empty value (not merely a trailing
        # ExpressionStatement).  Reserve a synthetic <main> local as the running
        # accumulator: ExpressionStatements write it, if/switch/loops/try seed it
        # to `undefined`, blocks/declarations are transparent (see compile_stmt).
        # Only script/eval bodies observe this value — module bodies do not, so we
        # leave cv_slot == -1 there.  The name is not a valid identifier, so it can
        # never collide with a user binding.  Declared first in the outermost
        # <main> scope so its slot is stable and reachable from every nested block.
        if not is_module_goal {
            cv_decl_slot: int = self._declare("*cv", "const");
            if cv_decl_slot >= 0 {
                self.cv_slot = cv_decl_slot;
                self._op(Opcode.LOAD_UNDEFINED);
                self._emit(make_instruction(Opcode.STORE_LOCAL, cv_decl_slot, 0, 0));
            }
        }
        # ── Duplicate export name detection (ESM-X-005) ─────────────────────
        top_export_names: dict[str, bool] = {};
        dup_i: int = 0;
        while dup_i < n_stmts {
            dup_s: ASTNode = nd.children[dup_i];
            if dup_s.ntype == ASTNodeType.ExportNamedDecl
                and dup_s.expression is not None {
                dup_d: ASTNode = dup_s.expression;
                if dup_d.ntype == ASTNodeType.VariableDeclaration {
                    for dup_decl in dup_d.declarations {
                        if dup_decl.id is not None
                            and dup_decl.id.ntype == ASTNodeType.Identifier {
                            dn: str = dup_decl.id.name;
                            if dn in top_export_names {
                                self.had_error = True;
                                self._syntax_error(
                                    "SyntaxError: Duplicate export of '" + dn + "'"
                                );
                                return self._pop_fn();
                            }
                            top_export_names[dn] = True;
                        }
                    }
                }
            }
            dup_i = dup_i + 1;
        }
        if not is_module_goal {
            tla_i: int = 0;
            while tla_i < n_stmts {
                tla_s: ASTNode = nd.children[tla_i];
                if tla_s.ntype == ASTNodeType.ExpressionStatement
                    and tla_s.expression is not None
                    and tla_s.expression.ntype == ASTNodeType.AwaitExpression {
                    self._emit(
                        make_instruction(
                            Opcode.LOAD_GLOBAL, self._intern("SyntaxError"), 0, 0
                        )
                    );
                    self._const(
                        "s:await is only valid in async functions and the top level bodies of modules"
                    );
                    self._emit(make_instruction(Opcode.CALL, 1, 0, 0));
                    self._op(Opcode.THROW);
                    return self._pop_fn();
                }
                tla_i = tla_i + 1;
            }
        }
        # ── ECMAScript class TDZ (top-level) ─────────────────────────────────
        # Pre-scan: install TDZ sentinels for all top-level ClassDeclarations
        # before any statement is compiled, so references before the declaration
        # throw ReferenceError at runtime.
        tdz_i: int = 0;
        while tdz_i < n_stmts {
            tdz_stmt: ASTNode = nd.children[tdz_i];
            if tdz_stmt.ntype == ASTNodeType.ClassDeclaration {
                if tdz_stmt.id is not None {
                    self._emit(make_instruction(Opcode.TDZ_CLASS, 0, 0, 0));
                    self._emit_store_global_decl(tdz_stmt.id.name);
                }
            }
            tdz_i = tdz_i + 1;
        }
        # ── Pre-scan export live bindings + aliases (before function hoist) ──
        # `export var/let/const/function/class` → store on the module namespace.
        # `export { local as exp }` → dual-write aliases so later mutations are live.
        el_pre_i: int = 0;
        while el_pre_i < n_stmts {
            el_pre_s: ASTNode = nd.children[el_pre_i];
            if el_pre_s.ntype == ASTNodeType.ExportNamedDecl {
                if el_pre_s.expression is not None {
                    el_pre_d: ASTNode = el_pre_s.expression;
                    if el_pre_d.ntype == ASTNodeType.VariableDeclaration {
                        for el_pre_dd in el_pre_d.declarations {
                            if el_pre_dd.id is not None
                                and el_pre_dd.id.ntype == ASTNodeType.Identifier {
                                self.esm_live_names[el_pre_dd.id.name] = True;
                            }
                        }
                    } elif (
                        el_pre_d.ntype == ASTNodeType.FunctionDeclaration
                        or el_pre_d.ntype == ASTNodeType.ClassDeclaration
                    ) {
                        if el_pre_d.id is not None {
                            self.esm_live_names[el_pre_d.id.name] = True;
                        }
                    }
                }
                if len(el_pre_s.specifiers) > 0 and el_pre_s.source is None {
                    for el_pre_sp in el_pre_s.specifiers {
                        if el_pre_sp.left is None or el_pre_sp.right is None {
                            continue;
                        }
                        el_loc: str = el_pre_sp.left.name;
                        el_exp: str = el_pre_sp.right.name;
                        self._esm_alias_add(el_loc, el_exp);
                    }
                }
            } elif el_pre_s.ntype == ASTNodeType.ExportDefaultDecl {
                # `export default function fn(){}` / `class C{}`: the local name is
                # a mutable binding and `default` is a live alias of it (test262
                # eval-gtbndng-indirect-update-dflt — `fn = 2` updates .default).
                if el_pre_s.expression is not None {
                    el_edd: ASTNode = el_pre_s.expression;
                    if (
                        (
                            el_edd.ntype == ASTNodeType.FunctionDeclaration
                            or el_edd.ntype == ASTNodeType.ClassDeclaration
                        )
                        and el_edd.id is not None
                    ) {
                        self.esm_live_names[el_edd.id.name] = True;
                        self._esm_alias_add(el_edd.id.name, "default");
                    }
                }
            }
            el_pre_i = el_pre_i + 1;
        }
        # ── ESM import hoisting (SCP-M-002) ──────────────────────────────────
        # Per ESM spec, all ImportDeclarations are linked/resolved before any
        # module body code runs. Hoist all imports to the top of the program so
        # that imported bindings are available even for code that textually
        # precedes the import statement.
        # Also collect imported binding names for duplicate-binding detection.
        # Use dict[str,bool] (not list[str]) — dict `in` is reliable in Jac native.
        imported_names: dict[str, bool] = {};
        imp_i: int = 0;
        while imp_i < n_stmts {
            imp_stmt: ASTNode = nd.children[imp_i];
            if imp_stmt.ntype == ASTNodeType.ImportDeclaration {
                self.compile_stmt(imp_stmt);
                # Record all local binding names introduced by this import
                imp_spec_i: int = 0;
                imp_n_specs: int = len(imp_stmt.specifiers);
                while imp_spec_i < imp_n_specs {
                    sp_nd: ASTNode = imp_stmt.specifiers[imp_spec_i];
                    if sp_nd.right is not None {
                        imported_names[sp_nd.right.name] = True;
                    }
                    imp_spec_i = imp_spec_i + 1;
                }
            }
            imp_i = imp_i + 1;
        }
        # ── Pre-declare top-level let/const before function hoisting ─────────
        # ECMAScript: function declarations are hoisted before any variable
        # initializers run, but let/const variable *slots* must already exist
        # in the scope so that _capture() can find them and create Cell
        # references rather than falling back to LOAD_GLOBAL (which returns
        # undefined because let/const never go on globalThis).
        # var declarations at top level return -1 from _declare() (they ARE
        # globals), so they already work without this pre-scan.
        pd_i: int = 0;
        while pd_i < n_stmts {
            pd_s: ASTNode = nd.children[pd_i];
            pd_vd: ASTNode | None = None;
            if pd_s.ntype == ASTNodeType.VariableDeclaration {
                pd_vd = pd_s;
            } elif pd_s.ntype == ASTNodeType.ExportNamedDecl
                and pd_s.expression is not None {
                if pd_s.expression.ntype == ASTNodeType.VariableDeclaration {
                    pd_vd = pd_s.expression;
                }
            }
            if pd_vd is not None {
                pd_kind: str = pd_vd.value;
                if pd_kind == "let" or pd_kind == "const" {
                    for pd_decl in pd_vd.declarations {
                        if pd_decl.id is None {
                            continue;
                        }
                        pd_names: list[str] = [];
                        if pd_decl.id.ntype == ASTNodeType.Identifier {
                            pd_names.append(pd_decl.id.name);
                        } elif pd_decl.id.ntype == ASTNodeType.ObjectPattern
                            or pd_decl.id.ntype == ASTNodeType.ArrayPattern {
                            self._collect_pattern_names(pd_decl.id, pd_names);
                        }
                        for pd_name in pd_names {
                            pd_slot: int = self._declare(pd_name, pd_kind);
                            # ES §14: a top-level `let`/`const` is in its TDZ until its
                            # declaration executes.  When it gets a real local slot (eval
                            # code and nested <main> wrappers), seed the slot with the TDZ
                            # sentinel so an access before the declaration throws a
                            # ReferenceError (lex-env-no-init-{let,const}); LOAD_LOCAL_CHECKED
                            # on an unset (undefined) slot would silently yield undefined.
                            if pd_slot >= 0 {
                                self._emit_tdz_store(pd_slot);
                            }
                            self.hoist_predeclared[self._hoist_predecl_key(pd_name)] = True;
                            self.lexical_global_names[pd_name] = True;
                        }
                    }
                }
            }
            # Top-level class declarations are lexical bindings too (non-deletable),
            # but are stored as module-globals rather than pre-declared slots — record
            # their names so `delete <ClassName>` compiles to false.
            pd_cls: ASTNode | None = None;
            if pd_s.ntype == ASTNodeType.ClassDeclaration {
                pd_cls = pd_s;
            } elif pd_s.ntype == ASTNodeType.ExportNamedDecl
                and pd_s.expression is not None
                and pd_s.expression.ntype == ASTNodeType.ClassDeclaration {
                pd_cls = pd_s.expression;
            }
            if pd_cls is not None
                and pd_cls.id is not None
                and pd_cls.id.ntype == ASTNodeType.Identifier {
                self.lexical_global_names[pd_cls.id.name] = True;
            }
            pd_i = pd_i + 1;
        }
        # ── Recursive top-level `var` hoisting (ES VarDeclaredNames) ─────────
        # Pre-bind every function-scoped `var` reachable from the program body —
        # including vars nested in blocks / if / loops / try / switch / with — to
        # `undefined` as a real global, so a LOAD_GLOBAL miss reliably means "truly
        # undeclared" (A9 unresolvable-reference ReferenceError).  Runs before
        # function-declaration hoisting so a same-named function overwrites the
        # placeholder (GlobalDeclarationInstantiation order).  Iterative worklist
        # (a recursive helper miscompiles enum-equality branches in Jac native).
        if len(self.fn_scope_base) == 1 and not self.in_direct_eval {
            hv_names: list[str] = self.collect_toplevel_var_names(nd.children);
            hv_seen: dict[str, bool] = {};
            for hv_name in hv_names {
                if hv_name in hv_seen {
                    continue;
                }
                hv_seen[hv_name] = True;
                if self._hoist_predecl_key(hv_name) in self.hoist_predeclared {
                    continue;
                }
                if self.compiling_module and hv_name not in self.esm_live_names {
                    # Module-scoped var (see _declare): bind it as a <main> local
                    # now, before function hoisting, so hoisted functions capture
                    # the slot instead of resolving the name as a global.
                    hv_slot: int = self._declare(hv_name, "var");
                    if hv_slot >= 0 {
                        self._op(Opcode.LOAD_UNDEFINED);
                        self._emit(make_instruction(Opcode.STORE_LOCAL, hv_slot, 0, 0));
                    }
                    continue;
                }
                self.global_var_names[hv_name] = True;
                self._op(Opcode.LOAD_UNDEFINED);
                self._emit(
                    make_instruction(
                        Opcode.STORE_MODULE_GLOBAL, self._intern(hv_name), 0, 0
                    )
                );
            }
        }
        # ── Annex B.3.3.2 / B.3.3.3: block-level function → varEnv binding ──
        # Mirror FunctionDeclarationInstantiation's annexB pre-pass for script
        # and eval <main>.  Eligible names get a varEnv binding initialized to
        # `undefined` before any statement runs (CreateGlobalFunctionBinding for
        # script; eval EDI is finished in the VM for function varEnvs).
        self.program_annexb_fn_names = [];
        if len(self.fn_scope_base) == 1 and not self._fn().is_strict {
            ab_g_names: list[str] = [];
            self._collect_block_fn_names(nd, ab_g_names, True);
            ab_g_lex: dict[str, bool] = {};
            self._collect_annexb_blocking_lexicals(nd, ab_g_lex);
            ab_g_seen: dict[str, bool] = {};
            for ab_g_name in ab_g_names {
                if ab_g_name in ab_g_seen {
                    continue;
                }
                ab_g_seen[ab_g_name] = True;
                if ab_g_name in ab_g_lex {
                    continue;
                }
                if ab_g_name in self.lexical_global_names {
                    continue;
                }
                self.annexb_block_fn_names[ab_g_name] = True;
                self.global_var_names[ab_g_name] = True;
                self.program_annexb_fn_names.append(ab_g_name);
                # Direct eval: VM run_in_this_context_ex2 creates the binding on
                # the caller's varEnv (function) or global (configurable:true).
                # Script GDI: CreateGlobalFunctionBinding(F, undefined, false).
                if not self.in_direct_eval {
                    self._op(Opcode.LOAD_UNDEFINED);
                    self._emit(
                        make_instruction(
                            Opcode.CREATE_GLOBAL_FN_BINDING,
                            self._intern(ab_g_name),
                            0,
                            0
                        )
                    );
                }
            }
        }
        # ── ECMAScript function declaration hoisting (top-level) ──────────
        # Per ES spec §15.2.11, function declarations are initialized before
        # any statement executes.
        #
        # MODULE goal: each module is compiled as its own <main> wrapper, so
        # top-level `function` declarations are bound as LOCALS of that wrapper
        # (module_local=True) rather than written into the single VM-wide
        # globals map — two modules that each declare `function t(){}` must not
        # collide.  Forward references still work via the two-pass hoist below.
        #
        # CLASSIC SCRIPT goal: GlobalDeclarationInstantiation creates bindings
        # on the realm global environment.  They must be visible to
        # `new Function("return f()")` (CreateDynamicFunction closes over the
        # realm global env, NOT the caller's lexical scope / <main> locals).
        # So classic scripts use module_local=False → STORE_MODULE_GLOBAL.
        # (CJS files are wrapped in a function by `_cjs_run_in_module`, so their
        # user decls never take this <main> path.)
        #
        # TWO-PASS HOIST (modules): pass 1 pre-declares all top-level function
        # names as <main> locals; pass 2 compiles each body so mutual refs
        # capture as upvalues rather than falling back to LOAD_GLOBAL.
        hoist_pre_i: int = 0;
        while hoist_pre_i < n_stmts {
            hoist_pre_stmt: ASTNode = nd.children[hoist_pre_i];
            if hoist_pre_stmt.ntype == ASTNodeType.FunctionDeclaration
                and not self.in_direct_eval {
                if is_module_goal and hoist_pre_stmt.id is not None {
                    self._declare(hoist_pre_stmt.id.name, "fnhoist");
                }
            } elif hoist_pre_stmt.ntype == ASTNodeType.ClassDeclaration
                and not self.in_direct_eval {
                # MODULE goal: pre-declare top-level CLASS names as module-local
                # slots too (as `let` — classes are TDZ until their statement runs,
                # unlike hoisted functions). This must happen BEFORE any top-level
                # function body is compiled, so a closure referencing the class
                # (e.g. `new Foo()` inside a function defined earlier) captures the
                # SAME module-local slot the class statement later stores into —
                # otherwise the reference falls back to a stale/global binding and
                # reads TDZ forever ("Cannot access 'X' before initialization").
                # compile_class_decl resolves this pre-declared slot instead of
                # re-declaring, so no double-declaration.
                if is_module_goal and hoist_pre_stmt.id is not None {
                    self._declare(hoist_pre_stmt.id.name, "let");
                }
            }
            hoist_pre_i = hoist_pre_i + 1;
        }
        hoist_i: int = 0;
        while hoist_i < n_stmts {
            hoist_stmt: ASTNode = nd.children[hoist_i];
            if hoist_stmt.ntype == ASTNodeType.FunctionDeclaration {
                self.compile_function_decl(
                    hoist_stmt, is_module_goal and not self.in_direct_eval
                );
            }
            hoist_i = hoist_i + 1;
        }
        si: int = 0;
        while si < n_stmts {
            stmt: ASTNode = nd.children[si];
            # Skip FunctionDeclarations — already compiled in the hoist pass.
            if stmt.ntype == ASTNodeType.FunctionDeclaration {
                si = si + 1;
                continue;
            }
            # Skip ImportDeclarations — already compiled in the import hoist pass.
            if stmt.ntype == ASTNodeType.ImportDeclaration {
                si = si + 1;
                continue;
            }
            # SCP-M-003: duplicate binding — const/let at module top level must
            # not re-declare an imported name (ECMAScript early error / SyntaxError).
            if stmt.ntype == ASTNodeType.VariableDeclaration {
                stmt_kind: str = stmt.value;
                if stmt_kind == "const" or stmt_kind == "let" {
                    dup_found: bool = False;
                    for dup_decl in stmt.declarations {
                        if not dup_found
                            and dup_decl.id is not None
                            and dup_decl.id.ntype == ASTNodeType.Identifier {
                            if dup_decl.id.name in imported_names {
                                dup_msg: str = "SyntaxError: Identifier '"
                                    + dup_decl.id.name
                                    + "' has already been declared";
                                self._const("s:" + dup_msg);
                                self._op(Opcode.THROW);
                                dup_found = True;
                            }
                        }
                    }
                    if dup_found {
                        si = si + 1;
                        continue;
                    }
                }
            }
            is_last: bool = si == n_stmts - 1;
            # ECMAScript completion value.  In completion mode (script/eval), every
            # statement is compiled normally — ExpressionStatements and the
            # if/switch/loops/try seeds thread the running value into cv_slot — and
            # the accumulated value is returned at the tail (below).  Outside
            # completion mode (module bodies), fall back to the legacy behaviour of
            # returning a trailing ExpressionStatement's value directly.
            if self.cv_slot < 0
                and is_last
                and stmt.ntype == ASTNodeType.ExpressionStatement {
                if stmt.expression is not None {
                    self.compile_expr(stmt.expression);
                    self._op(Opcode.RETURN);
                } else {
                    self._op(Opcode.RETURN_UNDEFINED);
                }
            } else {
                self.compile_stmt(stmt);
            }
            si = si + 1;
        }
        # Return the accumulated completion value (script/eval); RETURN_UNDEFINED
        # is only reached for module bodies / empty programs.
        if self.cv_slot >= 0 {
            self._emit(make_instruction(Opcode.LOAD_LOCAL, self.cv_slot, 0, 0));
            self._op(Opcode.RETURN);
        } else {
            self._op(Opcode.RETURN_UNDEFINED);
        }
        compiled: CompiledFunction = self._pop_fn();
        return compiled;
    }
}

# flat scope chain
# scope_stack idx where each fn starts
# innermost loop first
# Enclosing try-finalizers (innermost last). break/continue/return re-emit the
# finalizers they jump out of (ES §14.15.3). See _emit_finalizers_for_exit.

# completed inner functions
# per fn-level: local slots needing cells
# export let/const/var/fn → store on __jac_esm_exports
# local → comma-separated exported names for `export { local as x }`.
# Stored as a string (not list): Jac may share one empty-list singleton for
# every `[]` literal, so a list aliased with ConstantPool.values made
# `_emit_esm_alias_stores` emit unbounded bytecode when interning.

# local name → "ns_global:imported"
# module src → ns global name
# per-module exports global name
# source file path (set by caller before compile_program)
# True while compiling default-parameter expressions
# B7: True when the enclosing function of the default params is an arrow (arrows have no own `arguments`)
# True while hoisting block-scoped function decls
# Depth of enclosing iteration-loop BODIES currently being compiled (for/while/
# do/for-in/for-of bodies; NOT the loop head). When > 0, a `let`/`const`
# declared in the loop body is stored via STORE_NEW_CELL instead of STORE_LOCAL
# so each iteration gets a FRESH binding cell — ES §13.7.4.7 CreatePerIteration-
# Environment covers the head binding, but a body-declared lexical is its own
# per-iteration declarative record too, so a closure made in iteration N must
# capture iteration N's cell, not the last one. The _pop_fn post-pass downgrades
# any STORE_NEW_CELL whose slot no closure captured back to STORE_LOCAL, so this
# is free for non-escaping body locals. Saved/restored across nested function
# compilation so an outer loop never marks an inner function's body lexicals.

# saved across nested fn compilation
# True if _syntax_error was emitted
# Most recent early-error message (for host reporting)
# body var names blocked in default exprs
# parameter identifiers for shadow detection

# let/const names no longer in scope

# O(1) membership mirror of the CURRENT function's CompiledFunction.lexical_names
# (which is an ordered list, kept for serialization + VM iteration). Deduping the
# list via `name not in fn.lexical_names` was O(n) per declaration → O(n²) for a
# module/function with n lexical bindings (froze on large bundles). Per-function
# (push/pop with the fn stack) so nested functions don't cross-contaminate.

# top-level var names (true globals)
# True when compiling eval() / runInThisContext source
# True when a direct-eval caller is strict (inherit strict mode)
# B7: 0=no; 1=ordinary-fn param eval (reject `arguments`+`eval`); 2=arrow param eval (reject `eval` only)
# B9: super-context tracking. *_allowed = active in the function currently being
# compiled; pending_* = to be handed to the next non-arrow _compile_function (a
# method/constructor body). `super()` needs a derived-class constructor;
# `super.x` needs any method/accessor with a home object. Arrows inherit the
# enclosing function's active flags (super is lexical in arrows).

# True while compiling a *static* method/accessor body: `super.x` resolves
# against the super *class* itself (B.x), not B.prototype.x.

# True while compiling a `typeof <ident>` operand — LOAD_GLOBAL must tolerate undeclared (A9)
# set by compile_var_decl when a `using` decl appears; compile_block reads+clears it to bracket the block with dispose mark/run
# >0 while compiling inside a `with` body (A4)
# One-shot: set by compile_return right before compiling a CallExpression that is the
# whole `return` argument of a STRICT function — compile_call then emits TAIL_CALL instead
# of CALL (ES §15.10.3 proper tail calls). Cleared after each compile_call. Only honored
# when the enclosing function is strict and the call is not wrapped in a try-finalizer.

# Depth of enclosing try BODIES (not catch/finally) in the current function. A
# call in the body of a try is NOT in tail position (ES §15.10.3): the try's
# catch/finally is a pending abrupt-completion handler, so `return f()` must be
# an ordinary CALL — a TAIL_CALL would replace the frame and let f's exception
# bypass the catch (Promise combinators' `try { return performCombinator() }`).
# Reset per function in compile_function; incremented only around the try body.

# saved _in_try_body per nested function
# monotonic counter for synthetic array-dstr iterator-close temp locals
# monotonic unique id per tagged-template source site (ES §13.2.8.4 cache key)
# ECMAScript statement completion value (ES §14 Runtime Semantics: Evaluation).
# Only observable for script/eval bodies (Script/eval evaluation returns the
# completion value of the last statement that produced a non-empty value).  We
# thread it through a synthetic <main> local: expression statements write it,
# if/switch/loops/try seed it to `undefined` (per their empty-body completion),
# blocks/declarations are transparent.  -1 = not in completion mode (inside a
# nested function, or a module body where the value is unobservable).
# <main> local slot holding the running completion value; -1 disables tracking
# saved cv_slot across nested-function compilation
# >0 while compiling a class body: all class code is implicitly strict (ES §15.7)
# ES §15.7.14 ClassDefinitionEvaluation step 18: SetFunctionName(F, className)
# runs BEFORE static elements (step 33+), so an anonymous class's INFERRED name
# (from `var C = class {}` / `export default class {}` / `{[k]: class{}}`) must be
# applied inside class evaluation, not at the assignment site — otherwise a static
# field initializer reads `this.name === ""`. The caller sets this one-shot field
# before compile_expr; compile_class_expr consumes it right after MAKE_CLASS and
# clears it. Empty = no pending inferred name.

# Per-class private-name brands (ES §8.2.x PrivateEnvironment). Each class body
# gets a fresh scope id; a `#name` is mangled to `__priv_#name@<id>` where <id> is
# the NEAREST enclosing class scope declaring that name — so same-named `#m` in a
# super and a subclass are distinct keys (no prototype-chain collision).
# monotonic class-scope id allocator
# active class-scope ids, innermost last
# parallel: private-name SET per scope (dict for O(1) lookup — a class with thousands of #fields would be O(n^2) with a list)
# let/const names pre-declared in hoist Phase B / block pre-scan
# body `var` slots that shadow formal parameters (SCP-P-003)

# True when the current function's parameter list is not simple (defaults,
# destructuring, rest): only then does a body `var` named like a parameter
# get its own binding (ES §10.2.11 step 28) — see _param_body_var_slot.

# catch binding names (Annex B var-in-catch)

# named-function-expression self-reference name (shadowable by body decls)

# ES §10.2.11: parameter names still in TDZ (uninitialized) while a default
# expression is compiled — a reference to one throws ReferenceError, e.g.
# `(x = x)`, `(a = b, b)`.  Cleared per-param left-to-right.  Declared LAST in
# the Compiler field block: inserting a `has` field mid-struct shifts field
# offsets and corrupts program init (NULL call from jac_entry) — the same
# C-struct-compat hazard as VM fields.

# Top-level lexical binding names (module/script let/const/class).  These are
# stored as module-globals but are LEXICAL bindings, not configurable globalThis
# properties, so `delete <name>` must yield false (ES §13.5.1.2).  Populated in
# the compile_program pre-scan.  (Appended last — Compiler struct field order is
# offset-sensitive; see the VM-struct-field-order note.)

# Annex B.3.3 block-level function names that were var-hoisted to the current
# function scope (sloppy mode).  When such a `function f(){}` block declaration
# executes, it must ALSO copy the function object to the function-scoped `var f`
# binding (not only the block-local lexical binding).  Reset per function.

# When True, `_declare` REUSES an existing same-scope let/const binding (returns
# its slot) instead of raising a redeclaration SyntaxError. Set transiently while
# emitting the per-iteration destructuring of a for-in/of ForDeclaration pattern
# whose names were already TDZ-predeclared before the iterable (ES §14.7.5.6).
# Appended at struct END — mid-struct insertion corrupts init (see
# js_engine-vm-struct-field-order).

# ES §15.7.1: when compiling direct-eval source that inherits a CLASS FIELD
# INITIALIZER context, top-level `arguments` / `new.target` are early errors.
# Set by the VM eval path from the caller frame's `is_field_init`. Appended at
# struct END (mid-struct insertion corrupts init — js_engine-vm-struct-field-order).

# ES §15.1.1 / §13.3.12: INDIRECT eval evaluates as global code, where
# `new.target` is a SyntaxError unless nested inside an ordinary function
# (arrows inherit the global's — absent — new.target, so are NOT a boundary).
# Set by the VM eval path when inherit_caller_scope is False. Appended struct END.

# Catch-parameter names bound by a destructuring pattern (`catch ({f})` /
# `catch ([f])`).  Unlike a simple `catch (f)` BindingIdentifier (B.3.5), a
# pattern catch makes `var f` in that catch an early error, so Annex B.3.3
# must suppress the extension for those names. Appended struct END.

# Sloppy-mode block-level FunctionDeclaration names in the CURRENT block
# (B.3.3.4 allows duplicate FunctionDeclarations in the same block). Appended
# struct END; pushed/popped with _push_scope / _pop_scope.

# Always 0: the "uncached" encoding for GET_PROP arg2 / SET_PROP arg3, so the
# VM interns each property key once at runtime and self-patches the bytecode
# (see _intern_key). Kept as a field because the emit helpers read it; do NOT
# pre-fill it via str_intern (breaks realm-less js_compiler + .jsbc portability).
# Appended struct END (Compiler field order is offset-sensitive).

# Annex B block-fn names collected for the most recent compile_program.
# Survives `_pop_fn` (unlike annexb_block_fn_names, which is stacked per-fn).
# Consumed by VM EvalDeclarationInstantiation (B.3.3.3).

# Full source text of the unit being compiled (for Function.prototype.toString).
# Set by the VM / run_script before compile_program / _compile_function.

# `arguments` / `eval` identifier occurrences in source_text (start/end offsets,
# ascending), built lazily by _src_range_has_args_ref; _aa_src_len = len of the
# source_text they were computed for (-1 = not yet).

# True while compile_program is compiling under the Module goal.  In modules,
# LexicallyDeclaredNames (incl. top-level FunctionDeclarations) ∩ VarDeclaredNames
# is an early SyntaxError — unlike scripts where `var`/`function` freely redeclare.
# Appended at struct END (Compiler field order is offset-sensitive).

# Direct-eval inheritance of the caller's PrivateEnvironment (W7): `#name` in
# eval'd code resolves to the caller's mangled private keys. Populated by the
# VM eval path from the caller CompiledFunction's priv_env_* snapshot.
# Appended at struct END.
# ══════════════════════════════════════════════════════════════════════════════
# 4.  Factory
# ══════════════════════════════════════════════════════════════════════════════

"""Create a fresh Compiler instance."""
def:pub make_compiler -> Compiler {
    return Compiler(
        fn_stack=[],
        scope_stack=[],
        fn_scope_base=[],
        loop_stack=[],
        finalizer_stack=[],
        all_fns=[],
        cell_slots=[]
    );
}

"""True when the `eval` token at `at` in `src` is a definition's own name:
walking back to `start`, only spaces, `*` and the keywords function / async
/ static / get / set come before it (`eval() {`, `get eval()`,
`function* eval(`) — a definition, never a call."""
def _src_eval_own_name(src: str, start: int, at: int) -> bool {
    i: int = at - 1;
    while i >= start {
        ch: str = src[i];
        if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" or ch == "*" {
            i = i - 1;
        } else {
            we: int = i;
            while i >= start
                and (
                    (src[i] >= "a" and src[i] <= "z")
                    or (src[i] >= "A" and src[i] <= "Z")
                ) {
                i = i - 1;
            }
            wl: int = we - i;
            if wl == 0 {
                return False;
            }
            if not (
                _src_word_at(src, i + 1, wl, "function")
                or _src_word_at(src, i + 1, wl, "async")
                or _src_word_at(src, i + 1, wl, "static")
                or _src_word_at(src, i + 1, wl, "get")
                or _src_word_at(src, i + 1, wl, "set")
            ) {
                return False;
            }
        }
    }
    return True;
}

def _src_word_at(src: str, pos: int, wl: int, word: str) -> bool {
    if wl != len(word) {
        return False;
    }
    j: int = 0;
    while j < wl {
        if src[pos + j] != word[j] {
            return False;
        }
        j = j + 1;
    }
    return True;
}
