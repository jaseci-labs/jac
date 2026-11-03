"""Generate the interpreter's instruction handlers from the instruction table.

instructions.jac lists the instructions, the ops each is made of and their
stack effects; jac/jaclang/runtime/python/interpreter/ops*.jac hold the op
bodies. Every instruction becomes a handler in the shape of CPython's
tail-call interpreter: a `@__preserve_none` C definition named
`_TAIL_CALL_<NAME>` that runs the ops, keeps the value stack and the frame's
published stack pointer exact at every point the garbage collector can run,
and tail-calls the next instruction's handler through the dispatch table. A
`raw` instruction's handler is written by hand in an op module.

The interpreter's C handlers for the same instructions are left out of the
build (bootstrap/python/build.sh reads the handler names from both files), so
instructions move to Jac one table entry at a time.

    jac run scripts/jacpython/gen_eval.jac            # rewrite the handlers
    jac run scripts/jacpython/gen_eval.jac --check    # fail on drift

- jac/jaclang/runtime/python/interpreter/eval.jac
- jac/jaclang/runtime/python/interpreter/dispatch.jac (the dispatch table)
- the `ops* ++> eval` wires of jac/jaclang/archwire.jac's interpreter graph
"""
import argparse;
import re;
import shutil;
import subprocess;
import sys;
import from pathlib { Path }
import from common {
    JAC,
    REPO,
    RUNTIME,
    Signature,
    format_jac,
    op_sources,
    read_signatures,
    write_or_check
}
import from instructions { FAMILIES, MACROS, OPS, Family, Macro, Op }

glob COMMAND: str = "scripts/jacpython/gen_eval.jac",
     TARGET: Path = RUNTIME / "interpreter/eval.jac",
     DISPATCH: Path = RUNTIME / "interpreter/dispatch.jac",
     OPCODE_META: Path = RUNTIME / "opcode_meta.jac",
     ARCHWIRE: Path = JAC / "jaclang/archwire.jac",
     WIRE_BLOCK: str = "graph import runtime.python.interpreter {\n",
     CONTEXT: list[str] = ["frame", "tstate", "oparg", "this_instr", "next_instr"],
     HANDLER_PARAMS: str = "frame: ptr[u8], stack_pointer: ptr[u64], tstate: ptr, next_instr: ptr[u16], oparg: i32",
     # Statuses an op returning i32 reports besides 0 (continue); their
     # meaning is documented in instructions.jac.
     STATUS_ERROR: int = 1,
     STATUS_DEOPT: int = 2,
     STATUS_REDISPATCH: int = 3,
     STATUS_UNWIND: int = 4,
     STATUS_INLINED: int = 5,
     STATUS_ERROR_TAKEN: int = 6,
     STATUS_EXHAUSTED: int = 7,
     STATUS_RESUME_AT: int = 8;

# One item of a stack effect. `count` is the C expression of an array item's
# length (in terms of oparg); a plain item has none.
obj Item {
    has name: str,
        owned: bool = False,
        size: int = 0,
        count: str = "";
}

# A parsed `caches inputs -- outputs` stack effect.
obj Effect {
    has caches: list[Item],
        inputs: list[Item],
        outputs: list[Item];
}

# A value stack slot the handler knows about, relative to the current
# stack_pointer local. `var` holds the value in a local when set; `mem` says
# the slot in memory already holds it.
obj Slot {
    has var: str,
        mem: bool;
}

def parse_item(raw: str) -> Item {
    owned = raw.endswith("!");
    if owned {
        raw = raw[:-1].strip();
    }
    m = re.fullmatch(r"(\w+)\[(.+)\]", raw);
    if m {
        return Item(name=m.group(1), owned=owned, count=m.group(2).strip());
    }
    return Item(name=raw, owned=owned);
}

def parse_effect(text: str) -> Effect {
    (left, right) = text.split("--");
    caches: list[Item] = [];
    inputs: list[Item] = [];
    outputs: list[Item] = [];
    for raw in [
        part.strip()
        for part in left.split(",")
        if part.strip()
    ] {
        if "/" in raw and "[" not in raw {
            (name, size) = raw.split("/");
            caches.append(Item(name=name.strip(), size=int(size)));
        } else {
            inputs.append(parse_item(raw));
        }
    }
    for raw in [
        part.strip()
        for part in right.split(",")
        if part.strip()
    ] {
        outputs.append(parse_item(raw));
    }
    return Effect(caches=caches, inputs=inputs, outputs=outputs);
}

# Names of the handlers the op modules write by hand.
def raw_handlers -> set[str] {
    out: set[str] = set();
    for source in op_sources() {
        out = out | set(re.findall(r"def _TAIL_CALL_(\w+)\(", source.read_text()));
    }
    return out;
}

# Top-level names each op module defines.
def module_names(source: Path) -> set[str] {
    text = source.read_text();
    names = set(re.findall(r"^def (\w+)", text, re.M));
    for m in re.finditer(r"^glob (.*?);", text, re.M | re.S) {
        names = names | set(re.findall(r"(?:^|,)\s*(\w+)\s*:", m.group(1)));
    }
    return names;
}

# The `<ops module> ++> eval { ... }` wires (in archwire's interpreter graph)
# the handlers need, one statement per module.
def eval_wires(text: str) -> list[str] {
    used = set(re.findall(r"\b\w+\b", text));
    out: list[str] = [];
    for source in op_sources() {
        names = sorted(used & module_names(source));
        if names {
            body = ",\n".join("        " + name for name in names);
            out.append(f"    {source.stem} ++> eval {{\n{body}\n    }}\n");
        }
    }
    return out;
}

# An eval wire either stands alone (`ops ++> eval { ... }`) or, once the
# module wires something else too, sits in its list (`ops ++> [ eval { ... },
# ... ]`, how `jac fmt` folds statements from one source).
def wire_pattern -> re.Pattern {
    return re.compile(r"^    ops\w* \+\+> eval \{[^}]*\}\n", re.M);
}

def list_pattern -> re.Pattern {
    return re.compile(r"^    (ops\w*) \+\+> \[\n(.*?)\n    \]\n", re.M | re.S);
}

def entry_pattern -> re.Pattern {
    return re.compile(r"^        eval \{([^}]*)\},?\n", re.M);
}

def wire_key(source: str, names: str) -> str {
    return source + ":" + ",".join(
        sorted(name.strip() for name in names.split(",") if name.strip())
    );
}

def present_wires(text: str) -> list[str] {
    keys: list[str] = [];
    for m in wire_pattern().finditer(text) {
        head = re.match(r"\s*(\w+) \+\+> eval \{([^}]*)\}", m.group(0));
        if head is not None {
            keys.append(wire_key(head.group(1), head.group(2)));
        }
    }
    for m in list_pattern().finditer(text) {
        for e in entry_pattern().finditer(m.group(2) + "\n") {
            keys.append(wire_key(m.group(1), e.group(1)));
        }
    }
    return keys;
}

def wires_current(wires: list[str]) -> bool {
    want: list[str] = [];
    for w in wires {
        head = re.match(r"\s*(\w+) \+\+> eval \{([^}]*)\}", w);
        if head is not None {
            want.append(wire_key(head.group(1), head.group(2)));
        }
    }
    return sorted(present_wires(ARCHWIRE.read_text())) == sorted(want);
}

def strip_list_entry(m: re.Match) -> str {
    body = entry_pattern().sub("", m.group(2) + "\n").rstrip("\n");
    return f"    {m.group(1)} ++> [\n{body}\n    ]\n";
}

def write_wires(wires: list[str]) {
    text = wire_pattern().sub("", ARCHWIRE.read_text());
    text = list_pattern().sub(strip_list_entry, text);
    if WIRE_BLOCK not in text {
        text = text.rstrip("\n") + "\n\n" + WIRE_BLOCK + "}\n";
    }
    at = text.index(WIRE_BLOCK) + len(WIRE_BLOCK);
    ARCHWIRE.write_text(text[:at] + "".join(wires) + text[at:]);
    jac = shutil.which("jac");
    if jac is None {
        sys.exit("jac is not on PATH; archwire.jac is rendered with `jac fmt`");
    }
    result = subprocess.run(
        [jac, "fmt", str(ARCHWIRE)], capture_output=True, text=True
    );
    if result.returncode != 0 {
        sys.exit(f"jac fmt failed on archwire.jac:\n{result.stdout}{result.stderr}");
    }
    print(f"wired the handlers in {ARCHWIRE.relative_to(REPO)}");
}

def family_heads -> dict[str, str] {
    heads: dict[str, str] = {};
    for fam in FAMILIES {
        for member in fam.members {
            heads[member] = fam.head;
        }
    }
    return heads;
}

def handler_call(name: str, sp: str, instr: str) -> str {
    return f"return tail _TAIL_CALL_{name}(frame, {sp}, tstate, {instr}, oparg);";
}

# A stack offset: an integer plus signed symbolic terms, as Jac source.
obj Offset {
    has const: int,
        terms: list[str];

    def plus(n: int, term: str) -> Offset {
        return Offset(const=self.const + n, terms=add_term(self.terms, "+ ", term));
    }

    def minus(n: int, term: str) -> Offset {
        return Offset(const=self.const - n, terms=add_term(self.terms, "- ", term));
    }

    def text -> str {
        if not self.terms {
            return str(self.const);
        }
        head = "" if self.const == 0 else str(self.const) + " ";
        body = " ".join(self.terms);
        if not head and body.startswith("+ ") {
            body = body[2:];
        } elif not head {
            body = "-" + body[2:];
        }
        return (head + body).strip();
    }

    def at -> str {
        if not self.terms {
            if self.const == 0 {
                return "stack_pointer";
            }
            if self.const < 0 {
                return f"(stack_pointer - {-self.const})";
            }
            return f"(stack_pointer + {self.const})";
        }
        return f"(stack_pointer + ({self.text()}))";
    }
}

# Add a signed symbolic term, cancelling it against an opposite one.
def add_term(terms: list[str], sign: str, term: str) -> list[str] {
    out = list(terms);
    if not term {
        return out;
    }
    opposite = ("- " if sign == "+ " else "+ ") + term;
    if opposite in out {
        out.remove(opposite);
    } else {
        out.append(sign + term);
    }
    return out;
}

def zero -> Offset {
    return Offset(const=0, terms=[]);
}

def count_term(item: Item) -> str {
    return f"i64({item.count})";
}

def cache_read(offset: int, size: int) -> str {
    at = f"(this_instr + {offset + 1})";
    if size == 1 {
        return f"{at}.view(1)[0]";
    }
    if size == 2 {
        return f"ptr[u32]({at}).view(1)[0]";
    }
    if size == 4 {
        return f"ptr[u64]({at}).view(1)[0]";
    }
    sys.exit(f"unsupported cache entry size {size}");
}

# Emits one handler. The value stack is modelled symbolically: `slots` maps
# offsets from the stack_pointer local to what the handler knows they hold,
# `depth` is the current top, and stores reach memory only when a later point
# needs them (a sync, an error exit or the final dispatch). An op with an
# array item first commits the model and moves stack_pointer to the top, then
# addresses its items with symbolic offsets.
obj HandlerWriter {
    has name: str,
        parts: list[str],
        sigs: dict[str, Signature],
        ops: dict[str, Op],
        head: str,
        lines: list[str],
        slots: dict[int, Slot],
        refs: set[str],
        depth: int = 0,
        temps: int = 0,
        pristine: bool = True,
        cache_offset: int = 0;

    def fresh -> str {
        self.temps += 1;
        return f"v{self.temps}";
    }

    def emit(line: str) {
        self.lines.append("    " + line);
    }

    def load(offset: int) -> str {
        if offset in self.slots and self.slots[offset].var {
            return self.slots[offset].var;
        }
        var = self.fresh();
        self.emit(f"{var} = {Offset(const=offset, terms=[]).at()}.view(1)[0];");
        self.slots[offset] = Slot(var=var, mem=True);
        return var;
    }

    def stores(limit: int, commit: bool) -> list[str] {
        out: list[str] = [];
        for offset in sorted(self.slots) {
            slot = self.slots[offset];
            if offset < limit and not slot.mem {
                out.append(
                    f"{Offset(const=offset, terms=[]).at()}.view(1)[0] = {slot.var};"
                );
                if commit {
                    slot.mem = True;
                }
            }
        }
        return out;
    }

    def sync(limit: int) {
        for line in self.stores(limit, True) {
            self.emit(line);
        }
        self.emit(
            f"frame_set_stackpointer(frame, {Offset(const=limit, terms=[]).at()});"
        );
    }

    def rebase {
        for line in self.stores(self.depth, True) {
            self.emit(line);
        }
        if self.depth != 0 {
            self.emit(f"stack_pointer = {Offset(const=self.depth, terms=[]).at()};");
        }
        self.slots = {};
        self.depth = 0;
    }

    # Leave the handler with the stack ending at `top`: pending stores below
    # it reach memory first, then `tail` (a `return tail ...` line) runs.
    def exit_at(top: Offset, tail: list[str]) -> list[str] {
        lines: list[str] = [];
        if not top.terms {
            lines = self.stores(top.const, False);
        }
        return lines + tail;
    }

    def label_exit(label: str, top: Offset) -> list[str] {
        self.refs.add(label);
        return self.exit_at(top, [handler_call(label, top.at(), "next_instr")]);
    }

    def error_exit(top: Offset) -> list[str] {
        return self.label_exit("error", top);
    }

    def deopt_exit -> list[str] {
        if not self.head {
            sys.exit(
                f"{self.name}: a guard deoptimizes but the instruction has no family"
            );
        }
        if not self.pristine {
            sys.exit(f"{self.name}: a guard runs after the stack changed");
        }
        self.refs.add(self.head);
        return [handler_call(self.head, "stack_pointer", "this_instr")];
    }

    def redispatch_exit -> list[str] {
        if not self.pristine {
            sys.exit(f"{self.name}: a re-dispatch follows a stack change");
        }
        return [
            "slot = next_handler(this_instr);",
            "return tail slot.view(1)[0].handler(frame, stack_pointer, tstate, this_instr, oparg);"
        ];
    }

    def dispatch_lines(top: Offset, instr: str) -> list[str] {
        return self.exit_at(
            top,
            [
                f"next_instr = {instr};",
                f"stack_pointer = {top.at()};",
                "slot = next_handler(next_instr);",
                "return tail slot.view(1)[0].handler(frame, stack_pointer, tstate, next_instr, next_oparg(next_instr));"
            ]
        );
    }

    def inlined_exit(base: Offset) -> list[str] {
        self.refs.add("start_frame");
        return self.exit_at(
            base,
            [
                f"frame_set_stackpointer(frame, {base.at()});",
                "return tail _TAIL_CALL_start_frame(tstate_current_frame(tstate), stack_pointer, tstate, next_instr, oparg);"
            ]
        );
    }

    # Emit the call of a status-reporting op (i32) and the exits its
    # statuses take. `base` is where the op's inputs start, `before` the top
    # before it ran and `error_top` the top an error leaves.
    def status_call(
        op: Op,
        sig: Signature,
        call: str,
        base: Offset,
        before: Offset,
        error_top: Offset
    ) {
        used = set(re.findall(r"\bST_[A-Z_]+\b", sig.body));
        status = self.fresh();
        self.emit(f"{status} = {call};");
        exits: list[tuple[int, list[str]]] = [];
        if "ST_DEOPT" in used {
            exits.append((STATUS_DEOPT, self.deopt_exit()));
        }
        if "ST_REDISPATCH" in used {
            exits.append((STATUS_REDISPATCH, self.redispatch_exit()));
        }
        if "ST_UNWIND" in used {
            exits.append(
                (STATUS_UNWIND, self.label_exit("exception_unwind", error_top))
            );
        }
        if "ST_INLINED" in used {
            exits.append((STATUS_INLINED, self.inlined_exit(base)));
        }
        if "ST_ERROR_TAKEN" in used {
            exits.append((STATUS_ERROR_TAKEN, self.error_exit(base)));
        }
        if "ST_EXHAUSTED" in used {
            exits.append(
                (
                    STATUS_EXHAUSTED,
                    self.dispatch_lines(before, "next_instr + (i64(oparg) + 1)")
                )
            );
        }
        if "ST_RESUME_AT" in used {
            exits.append(
                (
                    STATUS_RESUME_AT,
                    self.dispatch_lines(before, "frame_instr_ptr(frame)")
                )
            );
        }
        for name in used {
            if name
                not in (
                    "ST_OK",
                    "ST_ERROR",
                    "ST_DEOPT",
                    "ST_REDISPATCH",
                    "ST_UNWIND",
                    "ST_INLINED",
                    "ST_ERROR_TAKEN",
                    "ST_EXHAUSTED",
                    "ST_RESUME_AT"
                ) {
                sys.exit(f"{op.name}: unknown status {name}");
            }
        }
        failure: list[str] = [];
        for (code, lines) in exits {
            failure += [f"if {status} == {code} {{"]
                + ["    " + line for line in lines]
                + ["}"];
        }
        self.branch(f"{status} != 0", failure + self.error_exit(error_top));
    }

    # After an op returning the frame to continue in: the op has linked it
    # and pushed any result onto its stack, so the handler only reloads.
    def switch_frame(op: Op, call: str) {
        self.emit(f"frame = ptr[u8]({call});");
        self.emit("stack_pointer = frame_stackpointer(frame);");
        if op.resume == "start" {
            self.emit("next_instr = frame_instr_ptr(frame);");
        } elif op.resume == "return" {
            self.emit(
                "next_instr = frame_instr_ptr(frame) + frame_return_offset(frame);"
            );
        } else {
            self.emit(f"next_instr = frame_instr_ptr(frame) + {op.resume};");
        }
        self.slots = {};
        self.depth = 0;
        self.pristine = False;
    }

    def branch(cond: str, body: list[str]) {
        self.emit(f"if {cond} {{");
        for line in body {
            self.emit("    " + line);
        }
        self.emit("}");
    }

    def bind_args(
        op: Op,
        sig: Signature,
        values: dict[str, str],
        caches: dict[str, str],
        outputs: list[Item],
        out_at: list[str]
    ) -> tuple[list[str], dict[int, str]] {
        out_params: dict[int, str] = {};
        args: list[str] = [];
        for (pname, _) in sig.params {
            if pname in values {
                args.append(values[pname]);
            } elif pname in caches {
                args.append(caches[pname]);
            } elif pname in CONTEXT {
                args.append(pname);
            } else {
                index = -1;
                for j in range(len(outputs)) {
                    if outputs[j].name == pname {
                        index = j;
                    }
                }
                if index < 0 {
                    sys.exit(f"{op.name}: parameter {pname} binds to nothing");
                }
                args.append(out_at[index]);
                out_params[index] = pname;
            }
        }
        return (args, out_params);
    }

    def run_op(op: Op) {
        effect = parse_effect(op.stack);
        has_array = False;
        for item in effect.inputs + effect.outputs {
            if item.count {
                has_array = True;
            }
        }
        if has_array {
            self.run_array_op(op, effect);
        } else {
            self.run_scalar_op(op, effect);
        }
    }

    def read_caches(effect: Effect) -> dict[str, str] {
        caches: dict[str, str] = {};
        for item in effect.caches {
            if item.name != "unused" {
                caches[item.name] = cache_read(self.cache_offset, item.size);
            }
            self.cache_offset += item.size;
        }
        return caches;
    }

    def check_shape(
        op: Op,
        sig: (Signature | None),
        inputs: list[Item],
        outputs: list[Item],
        kept: list[bool]
    ) {
        owned = [
            i
            for i in range(len(inputs))
            if inputs[i].owned
        ];
        for i in range(len(inputs)) {
            if not inputs[i].owned and owned and i > min(owned) {
                sys.exit(f"{op.name}: owned inputs must be the topmost");
            }
            if not kept[i] and not inputs[i].owned and inputs[i].name == "unused" {
                sys.exit(f"{op.name}: an unused input cannot be consumed");
            }
        }
        if sig is None {
            for j in range(len(outputs)) {
                if j >= len(inputs) or not kept[j] {
                    sys.exit(f"{op.name}: no definition in ops.jac");
                }
            }
            if owned {
                sys.exit(f"{op.name}: no definition in ops.jac");
            }
        }
    }

    def run_scalar_op(op: Op, effect: Effect) {
        sig = self.sigs.get(op.name);
        inputs = effect.inputs;
        outputs = effect.outputs;
        n_in = len(inputs);
        base = self.depth - n_in;
        kept = [
            i < len(outputs) and outputs[i].name == inputs[i].name for i in range(n_in)
        ];
        self.check_shape(op, sig, inputs, outputs, kept);
        owned = [
            i
            for i in range(n_in)
            if inputs[i].owned
        ];
        consumed = [
            i
            for i in range(n_in)
            if not kept[i] and not inputs[i].owned
        ];
        values: dict[str, str] = {};
        for i in range(n_in) {
            if inputs[i].name != "unused" and (sig is not None or i in consumed) {
                values[inputs[i].name] = self.load(base + i);
            }
        }
        caches = self.read_caches(effect);
        error_top = Offset(const=base + n_in - len(owned), terms=[]);
        out_vars: dict[int, str] = {};
        if sig is not None {
            if op.escapes and sig.returns != "bool" {
                self.sync(error_top.const);
            }
            out_at = [
                Offset(const=base + j, terms=[]).at() for j in range(len(outputs))
            ];
            (args, out_params) = self.bind_args(
                op, sig, values, caches, outputs, out_at
            );
            call = f"{op.name}({', '.join(args)})";
            returned = [
                j
                for j in range(len(outputs))
                if j not in out_params and not (j < n_in and kept[j])
            ];
            if returned and sig.returns != "u64" {
                sys.exit(f"{op.name}: outputs need a u64 return or out-parameters");
            }
            if sig.returns == "u64" {
                if len(returned) != 1 {
                    sys.exit(
                        f"{op.name}: returns u64 but has {len(
                            returned
                        )} returned outputs"
                    );
                }
                var = self.fresh();
                self.emit(f"{var} = {call};");
                out_vars[returned[0]] = var;
                if op.error {
                    self.branch(f"{var} == u64(0)", self.error_exit(error_top));
                }
            } elif sig.returns == "bool" {
                self.branch(f"not {call}", self.deopt_exit());
            } elif sig.returns == "i64" {
                self.emit(f"next_instr = next_instr + {call};");
            } elif sig.returns == "i32" {
                self.status_call(
                    op,
                    sig,
                    call,
                    Offset(const=base, terms=[]),
                    Offset(const=base + n_in, terms=[]),
                    error_top
                );
            } elif sig.returns == "None" {
                self.emit(f"{call};");
            } elif sig.returns == "ptr[u8]" and op.resume {
                if outputs or consumed {
                    sys.exit(
                        f"{op.name}: a frame switch takes its inputs and pushes onto the new frame itself"
                    );
                }
                self.switch_frame(op, call);
                return;
            } else {
                sys.exit(f"{op.name}: unsupported return type {sig.returns}");
            }
            if sig.returns != "bool" {
                self.pristine = False;
            }
            for index in out_params {
                self.slots[base + index] = Slot(var="", mem=True);
            }
        }
        for i in range(n_in) {
            if not kept[i] {
                self.slots.pop(base + i, None);
            }
        }
        for j in range(len(outputs)) {
            if j in out_vars {
                self.slots[base + j] = Slot(var=out_vars[j], mem=False);
            }
        }
        if n_in != len(outputs) or consumed or owned {
            self.pristine = False;
        }
        self.depth = base + len(outputs);
        if consumed {
            self.sync(base + min(consumed));
            for i in reversed(consumed) {
                self.emit(f"sr_close({values[inputs[i].name]});");
            }
        }
    }

    def run_array_op(op: Op, effect: Effect) {
        sig = self.sigs.get(op.name);
        inputs = effect.inputs;
        outputs = effect.outputs;
        n_in = len(inputs);
        self.rebase();
        in_at: list[Offset] = [zero()] * n_in;
        cur = zero();
        for i in reversed(range(n_in)) {
            cur = cur.minus(1, "")
                if not inputs[i].count
                else cur.minus(0, count_term(inputs[i]));
            in_at[i] = cur;
        }
        base = cur;
        kept: list[bool] = [];
        same = True;
        for i in range(n_in) {
            same = same
                and i < len(outputs)
                and outputs[i].name == inputs[i].name
                and outputs[i].count == inputs[i].count;
            kept.append(same);
        }
        self.check_shape(op, sig, inputs, outputs, kept);
        out_at: list[Offset] = [];
        cur = base;
        for item in outputs {
            out_at.append(cur);
            cur = cur.plus(1, "") if not item.count else cur.plus(0, count_term(item));
        }
        top_after = cur;
        owned = [
            i
            for i in range(n_in)
            if inputs[i].owned
        ];
        consumed = [
            i
            for i in range(n_in)
            if not kept[i] and not inputs[i].owned
        ];
        error_top = in_at[min(owned)] if owned else zero();
        values: dict[str, str] = {};
        for i in range(n_in) {
            if inputs[i].name == "unused" or (sig is None and i not in consumed) {
                continue;
            }
            var = self.fresh();
            if inputs[i].count {
                self.emit(f"{var} = {in_at[i].at()};");
            } else {
                self.emit(f"{var} = {in_at[i].at()}.view(1)[0];");
            }
            values[inputs[i].name] = var;
        }
        caches = self.read_caches(effect);
        returned_store: list[str] = [];
        if sig is not None {
            if op.escapes and sig.returns != "bool" {
                self.emit(f"frame_set_stackpointer(frame, {error_top.at()});");
            }
            (args, out_params) = self.bind_args(
                op, sig, values, caches, outputs, [o.at() for o in out_at]
            );
            call = f"{op.name}({', '.join(args)})";
            returned = [
                j
                for j in range(len(outputs))
                if j not in out_params and not (j < n_in and kept[j])
            ];
            if returned and sig.returns != "u64" {
                sys.exit(f"{op.name}: outputs need a u64 return or out-parameters");
            }
            if sig.returns == "u64" {
                if len(returned) != 1 or outputs[returned[0]].count {
                    sys.exit(f"{op.name}: a u64 return makes exactly one plain output");
                }
                var = self.fresh();
                self.emit(f"{var} = {call};");
                if op.error {
                    self.branch(f"{var} == u64(0)", self.error_exit(error_top));
                }
                returned_store.append(
                    f"{out_at[returned[0]].at()}.view(1)[0] = {var};"
                );
            } elif sig.returns == "bool" {
                self.branch(f"not {call}", self.deopt_exit());
            } elif sig.returns == "i64" {
                self.emit(f"next_instr = next_instr + {call};");
            } elif sig.returns == "i32" {
                self.status_call(op, sig, call, base, zero(), error_top);
            } elif sig.returns == "None" {
                self.emit(f"{call};");
            } elif sig.returns == "ptr[u8]" and op.resume {
                if outputs or consumed {
                    sys.exit(
                        f"{op.name}: a frame switch takes its inputs and pushes onto the new frame itself"
                    );
                }
                self.switch_frame(op, call);
                return;
            } else {
                sys.exit(f"{op.name}: unsupported return type {sig.returns}");
            }
            if sig.returns != "bool" {
                self.pristine = False;
            }
        }
        if consumed {
            self.pristine = False;
            self.emit(f"frame_set_stackpointer(frame, {in_at[min(consumed)].at()});");
            for i in reversed(consumed) {
                name = values[inputs[i].name];
                if inputs[i].count {
                    index = self.fresh();
                    self.emit(f"for {index} in range({count_term(inputs[i])}) {{");
                    self.emit(f"    sr_close(({name} + {index}).view(1)[0]);");
                    self.emit("}");
                } else {
                    self.emit(f"sr_close({name});");
                }
            }
        }
        for line in returned_store {
            self.emit(line);
        }
        if top_after.const != 0 or top_after.terms {
            self.emit(f"stack_pointer = {top_after.at()};");
        }
        if owned or consumed or n_in != len(outputs) or (n_in and not kept[-1]) {
            self.pristine = False;
        }
    }

    def write -> str {
        self.emit("this_instr = next_instr;");
        self.emit("frame_set_instr_ptr(frame, next_instr);");
        advance_at = len(self.lines);
        self.emit("");
        for part in self.parts {
            if part.startswith("unused/") {
                self.cache_offset += int(part.split("/")[1]);
                continue;
            }
            self.run_op(self.ops[part]);
        }
        self.lines[advance_at] = f"    next_instr = next_instr + {1
            + self.cache_offset};";
        self.rebase();
        self.emit("slot = next_handler(next_instr);");
        self.emit(
            "return tail slot.view(1)[0].handler(frame, stack_pointer, tstate, next_instr, next_oparg(next_instr));"
        );
        return "\n".join(
            [
                "    @__preserve_none",
                f"    def _TAIL_CALL_{self.name}({HANDLER_PARAMS}) -> ptr[PyObject] {{"
            ]
                + ["    " + line for line in self.lines]
                + ["    }"]
        );
    }
}

# Instructions in table order: (name, parts). A raw instruction has no parts.
def instructions -> list[tuple[str, list[str]]] {
    out: list[tuple[str, list[str]]] = [];
    for op in OPS {
        if op.inst {
            out.append((op.name, [] if op.raw else [op.name]));
        }
    }
    for mac in MACROS {
        out.append((mac.name, [part.strip() for part in mac.parts.split("+")]));
    }
    return out;
}

def eval_module -> tuple[str, list[str]] {
    sigs = read_signatures();
    ops = {op.name: op for op in OPS};
    heads = family_heads();
    raws = raw_handlers();
    handlers: list[str] = [];
    names: list[str] = [];
    refs: set[str] = set();
    for (name, parts) in instructions() {
        names.append(name);
        if not parts {
            if name not in raws {
                sys.exit(
                    f"{name}: a raw instruction needs _TAIL_CALL_{name} in ops.jac"
                );
            }
            continue;
        }
        for part in parts {
            if not part.startswith("unused/") and part not in ops {
                sys.exit(f"{name}: unknown op {part}");
            }
        }
        writer = HandlerWriter(
            name=name,
            parts=parts,
            sigs=sigs,
            ops=ops,
            head=heads.get(name, ""),
            lines=[],
            slots={},
            refs=set()
        );
        handlers.append(writer.write());
        refs = refs | writer.refs;
    }
    externs = [
        f"    @__preserve_none\n    def _TAIL_CALL_{name}({HANDLER_PARAMS}) -> ptr[PyObject];"
        for name in sorted(refs - set(names))
    ];
    text = "import from c {\n" + "\n".join(externs + handlers) + "\n}\n";
    return (text, names);
}

# The interpreter's dispatch table, `INSTRUCTION_TABLE`, as Jac C data: every
# opcode below 256 maps to its handler, written in the op modules or generated
# into eval.jac, and opcodes without an instruction to the unknown-opcode
# handler. Opcode numbers come from opcode_meta.jac.
def dispatch_module(names: list[str]) -> str {
    numbers: dict[int, str] = {};
    for m in re.finditer(r"\bOP_(\w+): int = (\d+)", OPCODE_META.read_text()) {
        if int(m.group(2)) < 256 {
            numbers[int(m.group(2))] = m.group(1);
        }
    }
    have = set(names) | raw_handlers();
    table: list[str] = [];
    for code in range(256) {
        name = numbers.get(code, "");
        table.append(name if name in have else "UNKNOWN_OPCODE");
    }
    externs = [
        f"    @__preserve_none\n    def _TAIL_CALL_{name}({HANDLER_PARAMS}) -> ptr[PyObject];"
        for name in sorted(set(table))
    ];
    slots = ",\n".join(
        f"        HandlerSlot(handler=_TAIL_CALL_{name})" for name in table
    );
    return "import from c {\n" + "\n".join(externs)
        + f"\n    glob INSTRUCTION_TABLE: list[HandlerSlot] = [\n{slots}\n    ];\n}}\n";
}

with entry {
    parser = argparse.ArgumentParser(
        description="Generate the instruction handlers from the instruction table."
    );
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    (text, names) = eval_module();
    formatted = format_jac(text, TARGET);
    ok = write_or_check(TARGET, formatted, args.check, COMMAND);
    ok = write_or_check(
        DISPATCH, format_jac(dispatch_module(names), DISPATCH), args.check, COMMAND
    )
        and ok;
    wires = eval_wires(formatted);
    if not wires_current(wires) {
        if args.check {
            print(
                f"{ARCHWIRE.relative_to(REPO)} does not wire the handlers' ops; rerun {COMMAND}",
                file=sys.stderr
            );
            ok = False;
        } else {
            write_wires(wires);
        }
    }
    if not ok {
        sys.exit(1);
    }
    print(f"{len(names)} instructions have Jac handlers");
}
