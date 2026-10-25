"""Generate CPython's published opcode metadata from the instruction table.

instructions.jac declares CPython's instruction set (FORMAT, PSEUDOS,
FAMILIES and OPCODE_PINS), and the op definitions in
jac/jaclang/runtime/python/interpreter/ops*.jac show most of its flags (its
docstring says which). From them this writes, byte for byte, the files
CPython's Tools/cases_generator writes from Python/bytecodes.c, and the same
tables as Jac for the bytecode compiler and the runtime:

    jac run scripts/jacpython/gen_opcode_meta.jac            # rewrite them
    jac run scripts/jacpython/gen_opcode_meta.jac --check    # fail on drift

- jac/bootstrap/python/generated/Include/opcode_ids.h.in
- jac/bootstrap/python/generated/Include/internal/pycore_opcode_metadata.h.in
- jac/bootstrap/python/generated/Include/internal/pycore_uop_ids.h.in
- jac/bootstrap/python/generated/Include/internal/pycore_uop_metadata.h.in
- jac/bootstrap/python/generated/Lib/_opcode_metadata.py.in
- jac/jaclang/runtime/python/opcode_meta.jac

jac/bootstrap/python/cpython-sources.txt marks the first five paths
`generated`: the build stages these copies (named without `.in`) where the
archive's were. They keep the header CPython's generators write, naming the
generator and Python/bytecodes.c, because they are CPython's published text.
The analysis follows Tools/cases_generator/analyzer.py and stack.py, and each
writer the generator its header names.
"""
import argparse;
import re;
import sys;
import from pathlib { Path }
import from common {
    BOOTSTRAP,
    RUNTIME,
    Signature,
    format_jac,
    read_signatures,
    write_or_check
}
import from instructions {
    FAMILIES,
    FORMAT,
    OPCODE_PINS,
    OPS,
    PSEUDOS,
    Family,
    Inst,
    Macro,
    Op,
    Pseudo,
    Uop
}

glob COMMAND: str = "scripts/jacpython/gen_opcode_meta.jac",
     GENERATED: Path = BOOTSTRAP / "generated",
     OPCODE_META: Path = RUNTIME / "opcode_meta.jac",
     SOURCE: str = "Python/bytecodes.c",
     # The opcode flags in bit order (HAS_<NAME>_FLAG).
     FLAGS: list[str] = [
         "ARG",
         "CONST",
         "NAME",
         "JUMP",
         "FREE",
         "LOCAL",
         "EVAL_BREAK",
         "DEOPT",
         "ERROR",
         "ESCAPES",
         "EXIT",
         "PURE",
         "PASSTHROUGH",
         "OPARG_AND_1",
         "ERROR_NO_POP",
         "NO_SAVE_IP"
     ],
     # The order a uop's flags are written in.
     FLAG_ORDER: list[str] = [
         "ARG",
         "CONST",
         "NAME",
         "JUMP",
         "FREE",
         "LOCAL",
         "EVAL_BREAK",
         "DEOPT",
         "EXIT",
         "ERROR",
         "ERROR_NO_POP",
         "ESCAPES",
         "PURE",
         "NO_SAVE_IP"
     ],
     # Macro expansion size codes besides the cache sizes 1, 2 and 4.
     OPARG_KINDS: list[tuple[str, int]] = [
         ("OPARG_SIMPLE", 0),
         ("OPARG_CACHE_1", 1),
         ("OPARG_CACHE_2", 2),
         ("OPARG_CACHE_4", 4),
         ("OPARG_TOP", 5),
         ("OPARG_BOTTOM", 6),
         ("OPARG_SAVE_RETURN_OFFSET", 7),
         ("OPARG_REPLACED", 9),
         ("OPERAND1_1", 10),
         ("OPERAND1_2", 11),
         ("OPERAND1_4", 12)
     ],
     # Words a FORMAT entry's `facts` may hold.
     RECORDED: list[str] = [
         "ARG",
         "CONST",
         "NAME",
         "JUMP",
         "DEOPT",
         "EXIT",
         "ERROR",
         "ERROR_NO_POP",
         "LOCAL",
         "FREE",
         "ESCAPES",
         "THIS_INSTR"
     ],
     ANNOTATIONS: list[str] = [
         "pure",
         "no_save_ip",
         "specializing",
         "replaced",
         "tier1",
         "tier2"
     ],
     # The published files, by path in the CPython tree.
     OPCODE_IDS: str = "Include/opcode_ids.h",
     OPCODE_METADATA: str = "Include/internal/pycore_opcode_metadata.h",
     UOP_IDS: str = "Include/internal/pycore_uop_ids.h",
     UOP_METADATA: str = "Include/internal/pycore_uop_metadata.h",
     PY_METADATA: str = "Lib/_opcode_metadata.py";

# A stack item. `size` is the C expression of an array item's length.
obj Item {
    has name: str,
        size: str = "",
        peek: bool = False;
}

obj Cache {
    has name: str,
        size: int;
}

# A uop and the facts its flags are made of.
obj UopDef {
    has name: str,
        inputs: list[Item],
        outputs: list[Item],
        caches: list[Cache],
        annotations: list[str],
        facts: set[str],
        tier: int = 0,
        replicated: int = 0,
        implicit: bool = False;

    def size -> int {
        return sum([cache.size for cache in self.caches]);
    }

    # Why the uop cannot run in a uop trace, or "" when it can.
    def why_not_viable -> str {
        if self.name == "_SAVE_RETURN_OFFSET" {
            return "";
        }
        if "INSTRUMENTED" in self.name {
            return "is instrumented";
        }
        if "replaced" in self.annotations {
            return "is replaced";
        }
        if self.name in ("INTERPRETER_EXIT", "JUMP_BACKWARD") {
            return "has tier 1 control flow";
        }
        if "THIS_INSTR" in self.facts {
            return "uses the 'this_instr' variable";
        }
        if len(
            [
                cache
                for cache in self.caches
                if cache.name != "unused"
            ]
        )
            > 2 {
            return "has too many cache entries";
        }
        if "ERROR" in self.facts and "ERROR_NO_POP" in self.facts {
            return "has both popping and not-popping errors";
        }
        return "";
    }

    def is_viable -> bool {
        return self.why_not_viable() == "";
    }
}

# A part of an instruction: a uop, `size` units of unused cache, or a flush.
obj Part {
    has uop: UopDef | None,
        size: int,
        flush: bool = False;
}

obj InstrDef {
    has name: str,
        parts: list[Part],
        family: str = "";

    def size -> int {
        return 1 + sum([part.size for part in self.parts]);
    }
}

obj PseudoDef {
    has name: str,
        inputs: list[Item],
        outputs: list[Item],
        targets: list[str],
        sequence: bool,
        flags: list[str];
}

obj Analysis {
    has uops: dict[str, UopDef],
        instructions: dict[str, InstrDef],
        pseudos: dict[str, PseudoDef],
        opmap: dict[str, int],
        have_arg: int,
        min_instrumented: int;
}

# A stack offset: a number plus symbolic terms added and subtracted.
obj Offset {
    has numeric: int,
        positive: list[str],
        negative: list[str];
}

# The symbolic stack CPython's analysis runs an instruction's uops on.
obj Stack {
    has base: Offset,
        logical: Offset,
        variables: list[Item];

    def pop(item: Item) {
        if self.variables and self.variables[-1].size != item.size {
            self.variables = [];
            self.base = self.logical;
        }
        self.logical = offset_sub(self.logical, offset_of(item));
        if self.variables {
            self.variables.pop();
            return;
        }
        self.base = self.logical;
    }

    def push(item: Item) {
        self.variables.append(item);
        self.logical = offset_add(self.logical, offset_of(item));
    }
}

# Writes C as CPython's generators do: indentation follows the braces and
# parentheses each emitted string opens or closes.
obj CWriter {
    has chunks: list[str],
        indents: list[int],
        newline: bool = True;

    def raw(text: str) {
        self.chunks.append(text);
    }

    def emit(text: str) {
        parens = text.count("(") - text.count(")");
        braces = text.count("{") - text.count("}");
        if parens < 0 {
            self.indents.pop();
        }
        if braces < 0 or is_label(text) {
            self.indents.pop();
        }
        if self.newline and text {
            if text[0] != "\n" {
                self.chunks.append(" " * self.indents[-1]);
            }
            self.newline = False;
        }
        self.chunks.append(text);
        if text.endswith("\n") {
            self.newline = True;
        }
        if parens > 0 {
            self.indents.append(self.indents[-1] + 4);
        }
        if is_label(text) {
            self.indents.append(self.indents[-1] + 4);
        } elif braces > 0 {
            self.indents.append(self.indents[-1] + (0 if 'extern "C"' in text else 4));
        }
    }

    def text -> str {
        return "".join(self.chunks);
    }
}

def is_label(text: str) -> bool {
    return not text.startswith("//") and text.endswith(":");
}

def writer -> CWriter {
    return CWriter(chunks=[], indents=[0]);
}

def fail(message: str) {
    sys.exit(f"{COMMAND}: {message}");
}

# ---------------------------------------------------------------- offsets

def zero -> Offset {
    return Offset(numeric=0, positive=[], negative=[]);
}

def offset_of(item: Item) -> Offset {
    if not item.size {
        return Offset(numeric=1, positive=[], negative=[]);
    }
    text = item.size.strip();
    if re.fullmatch(r"[+-]?\d+", text) {
        return Offset(numeric=int(text), positive=[], negative=[]);
    }
    if text[0] == "+" {
        text = text[1:];
    }
    if text[0] == "-" {
        return Offset(numeric=0, positive=[], negative=[text[1:]]);
    }
    return Offset(numeric=0, positive=[text], negative=[]);
}

# Cancel terms that are both added and subtracted.
def offset_create(numeric: int, positive: list[str], negative: list[str]) -> Offset {
    plus = sorted(positive);
    minus = sorted(negative);
    plus_kept: list[str] = [];
    minus_kept: list[str] = [];
    while plus and minus {
        p_item = plus.pop();
        n_item = minus.pop();
        if p_item > n_item {
            plus_kept.append(p_item);
            minus.append(n_item);
        } elif p_item < n_item {
            minus_kept.append(n_item);
            plus.append(p_item);
        }
    }
    return Offset(
        numeric=numeric, positive=plus + plus_kept, negative=minus + minus_kept
    );
}

def offset_add(left: Offset, right: Offset) -> Offset {
    return offset_create(
        left.numeric + right.numeric,
        left.positive + right.positive,
        left.negative + right.negative
    );
}

def offset_sub(left: Offset, right: Offset) -> Offset {
    return offset_create(
        left.numeric - right.numeric,
        left.positive + right.negative,
        left.negative + right.positive
    );
}

def offset_neg(offset: Offset) -> Offset {
    return Offset(
        numeric=-offset.numeric,
        positive=list(offset.negative),
        negative=list(offset.positive)
    );
}

# Parenthesize a symbolic term that holds an operator other than `*`.
def parenthesize(term: str) -> str {
    if term.startswith("(") and term.endswith(")") {
        return term;
    }
    if re.match(r"^[\s\w*]+$", term) {
        return term;
    }
    return f"({term})";
}

def offset_c(offset: Offset) -> str {
    symbolic = "";
    for term in offset.negative {
        symbolic += f" - {parenthesize(term)}";
    }
    for term in offset.positive {
        symbolic += f" + {parenthesize(term)}";
    }
    res = symbolic
        if symbolic and offset.numeric == 0
        else f"{offset.numeric}{symbolic}";
    if res.startswith(" + ") {
        res = res[3:];
    }
    if res.startswith(" - ") {
        res = "-" + res[3:];
    }
    return res;
}

# What a sequence of stack effects pops and then pushes, as C expressions.
def stack_effect(effects: list[tuple[list[Item], list[Item]]]) -> tuple[str, str] {
    stack = Stack(base=zero(), logical=zero(), variables=[]);
    for (inputs, outputs) in effects {
        for item in reversed(inputs) {
            stack.pop(item);
        }
        for item in outputs {
            stack.push(item);
        }
    }
    return (
        offset_c(offset_neg(stack.base)),
        offset_c(offset_sub(stack.logical, stack.base))
    );
}

# ---------------------------------------------------------------- the table

# Split at the commas outside brackets.
def split_items(text: str) -> list[str] {
    out: list[str] = [];
    depth = 0;
    current = "";
    for ch in text {
        if ch in "[(" {
            depth += 1;
        } elif ch in "])" {
            depth -= 1;
        }
        if ch == "," and depth == 0 {
            out.append(current.strip());
            current = "";
        } else {
            current += ch;
        }
    }
    if current.strip() {
        out.append(current.strip());
    }
    return out;
}

def parse_item(text: str) -> Item {
    m = re.fullmatch(r"(\w+)\[(.+)\]", text);
    if m {
        return Item(name=m.group(1), size=m.group(2));
    }
    return Item(name=text);
}

# A declaration `caches and inputs -- outputs`: the inputs in order (cache
# entries and stack items) and the outputs.
def parse_effect(text: str) -> tuple[list[Cache | Item], list[Item]] {
    (left, right) = text.split("--");
    inputs: list[Cache | Item] = [];
    for raw in split_items(left) {
        m = re.fullmatch(r"(\w+)/(-?\d+)", raw);
        if m {
            inputs.append(Cache(name=m.group(1), size=int(m.group(2))));
        } else {
            inputs.append(parse_item(raw));
        }
    }
    return (inputs, [parse_item(raw) for raw in split_items(right)]);
}

# The bodies an op definition reaches: its own and its helpers', through
# calls to lowercase definitions of the op modules.
def reached_text(name: str, sigs: dict[str, Signature]) -> str {
    seen: set[str] = set();
    pending: list[str] = [name];
    text = "";
    while pending {
        current = pending.pop();
        if current in seen or current not in sigs {
            continue;
        }
        seen.add(current);
        body = sigs[current].body;
        text += body;
        for called in re.findall(r"\b(\w+)\(", body) {
            if called in sigs and not called.isupper() {
                pending.append(called);
            }
        }
    }
    return text;
}

# The facts of the uop declared as `name` (with the Jac op of that name) from
# its declaration, the op definition and the recorded words.
def uop_facts(
    name: str,
    stack: str,
    words: list[str],
    ops: dict[str, Op],
    sigs: dict[str, Signature]
) -> set[str] {
    recorded: set[str] = set();
    for word in words {
        if word.isupper() {
            if word not in RECORDED {
                fail(f"{name}: unknown fact {word}");
            }
            recorded.add(word);
        } elif word not in ANNOTATIONS
            and not re.fullmatch(r"replicate\(\d+\)", word) {
            fail(f"{name}: unknown annotation {word}");
        }
    }
    shown: set[str] = set();
    if re.search(r"\boparg\b", stack) {
        shown.add("ARG");
    }
    op = ops.get(name);
    if op is not None and not op.raw and name in sigs {
        sig = sigs[name];
        reached = reached_text(name, sigs);
        if "oparg" in [param for (param, _) in sig.params]
            or "ST_EXHAUSTED" in sig.body {
            shown.add("ARG");
        }
        if "frame_const(" in reached {
            shown.add("CONST");
        }
        if re.search(r"\b(names_code_name|attr_name)\(", reached) {
            shown.add("NAME");
        }
        if sig.returns == "i64" or "ST_EXHAUSTED" in sig.body {
            shown.add("JUMP");
        }
        if sig.returns == "bool" or "ST_DEOPT" in sig.body {
            shown.add("GUARD");
        }
        if op.error or re.search(r"\bST_(ERROR|ERROR_TAKEN|UNWIND)\b", sig.body) {
            shown.add("FAILS");
        }
    }
    for flag in ("ARG", "CONST", "NAME", "JUMP") {
        if flag in recorded and flag in shown {
            fail(f"{name}: {flag} is recorded but the op definition shows it");
        }
    }
    if "DEOPT" in recorded and "GUARD" in shown {
        fail(f"{name}: DEOPT is recorded but the op definition is a guard");
    }
    if "ERROR" in recorded and "FAILS" in shown and "ERROR_NO_POP" not in recorded {
        fail(f"{name}: ERROR is recorded but the op definition reports errors");
    }
    facts = (recorded | shown) - {"GUARD", "FAILS"};
    if "GUARD" in shown and "EXIT" not in recorded {
        facts.add("DEOPT");
    }
    if "FAILS" in shown and "ERROR_NO_POP" not in recorded {
        facts.add("ERROR");
    }
    if "CHECK_PERIODIC" in name {
        facts.add("EVAL_BREAK");
    }
    if "pure" in words {
        facts.add("PURE");
    }
    if "no_save_ip" in words {
        facts.add("NO_SAVE_IP");
    }
    return facts;
}

def make_uop(
    name: str,
    inputs: list[Cache | Item],
    outputs: list[Item],
    words: list[str],
    facts: set[str]
) -> UopDef {
    items = [
        item
        for item in inputs
        if isinstance(item, Item)
    ];
    # Items that stay at the same depth, from the bottom up to the first
    # change, are only peeked at.
    for index in range(min(len(items), len(outputs))) {
        if items[index].name != outputs[index].name {
            break;
        }
        items[index].peek = True;
        outputs[index].peek = True;
    }
    tier = 0;
    replicated = 0;
    for word in words {
        if tier == 0 and word == "specializing" {
            tier = 1;
        } elif tier == 0 and re.fullmatch(r"tier\d", word) {
            tier = int(word[-1]);
        }
        m = re.fullmatch(r"replicate\((\d+)\)", word);
        if m and replicated == 0 {
            replicated = int(m.group(1));
        }
    }
    return UopDef(
        name=name,
        inputs=items,
        outputs=outputs,
        caches=[
            item
            for item in inputs
            if isinstance(item, Cache)
        ],
        annotations=[
            word
            for word in words
            if not word.isupper()
        ],
        facts=facts,
        tier=tier,
        replicated=replicated
    );
}

# Enter `uop` under `key`, after the copies it is replicated into (one per
# constant oparg).
def add_uop(uops: dict[str, UopDef], key: str, uop: UopDef) {
    for index in range(uop.replicated) {
        copy = UopDef(
            name=f"{uop.name}_{index}",
            inputs=uop.inputs,
            outputs=uop.outputs,
            caches=uop.caches,
            annotations=uop.annotations,
            facts=uop.facts - {"ARG"},
            tier=uop.tier
        );
        uops[copy.name] = copy;
    }
    uops[key] = uop;
}

# An instruction's facts: any part's, except that it is pure (or keeps no
# instruction pointer) only when every part is.
def combine(each: list[set[str]]) -> set[str] {
    out: set[str] = set();
    for facts in each {
        out = out | (facts - {"PURE", "NO_SAVE_IP"});
    }
    for flag in ("PURE", "NO_SAVE_IP") {
        if all(flag in facts for facts in each) {
            out.add(flag);
        }
    }
    return out;
}

def part_facts(part: Part) -> set[str] {
    if part.uop is not None {
        return part.uop.facts;
    }
    return {"PURE"};
}

def instr_facts(inst: InstrDef) -> set[str] {
    return combine([part_facts(part) for part in inst.parts]);
}

def pseudo_facts(pseudo: PseudoDef, a: Analysis) -> set[str] {
    return combine([instr_facts(a.instructions[name]) for name in pseudo.targets]);
}

def analyze -> Analysis {
    sigs = read_signatures();
    ops = {op.name: op for op in OPS};
    uops: dict[str, UopDef] = {};
    instructions: dict[str, InstrDef] = {};
    for decl in FORMAT {
        if isinstance(decl, Inst) {
            (inputs, outputs) = parse_effect(decl.stack);
            words = decl.facts.split();
            facts = uop_facts(decl.name, decl.stack, words, ops, sigs);
            # Unused cache entries become the instruction's padding around
            # its single uop.
            parts: list[Part] = [];
            uop_inputs: list[Cache | Item] = [];
            at = -1;
            for item in inputs {
                if isinstance(item, Cache) and item.name == "unused" {
                    parts.append(Part(uop=None, size=item.size));
                } else {
                    uop_inputs.append(item);
                    if at < 0 {
                        at = len(parts);
                        parts.append(Part(uop=None, size=0));
                    }
                }
            }
            uop = make_uop("_" + decl.name, uop_inputs, outputs, words, facts);
            uop.implicit = True;
            add_uop(uops, decl.name, uop);
            part = Part(uop=uop, size=uop.size());
            if at < 0 {
                parts.append(part);
            } else {
                parts[at] = part;
            }
            instructions[decl.name] = InstrDef(name=decl.name, parts=parts);
        } elif isinstance(decl, Uop) {
            (inputs, outputs) = parse_effect(decl.stack);
            words = decl.facts.split();
            facts = uop_facts(decl.name, decl.stack, words, ops, sigs);
            add_uop(
                uops, decl.name, make_uop(decl.name, inputs, outputs, words, facts)
            );
        }
    }
    for decl in FORMAT {
        if isinstance(decl, Macro) {
            parts: list[Part] = [];
            for raw in decl.parts.split("+") {
                word = raw.strip();
                m = re.fullmatch(r"(\w+)/(-?\d+)", word);
                if word == "flush" {
                    parts.append(Part(uop=None, size=0, flush=True));
                } elif m {
                    parts.append(Part(uop=None, size=int(m.group(2))));
                } elif word in uops {
                    parts.append(Part(uop=uops[word], size=uops[word].size()));
                } else {
                    fail(f"{decl.name}: no uop {word}");
                }
            }
            instructions[decl.name] = InstrDef(name=decl.name, parts=parts);
        }
    }
    for family in FAMILIES {
        for member in family.members {
            instructions[member].family = family.head;
        }
    }
    pseudos: dict[str, PseudoDef] = {};
    for decl in PSEUDOS {
        (inputs, outputs) = parse_effect(decl.stack);
        targets = decl.targets.strip();
        pseudos[decl.name] = PseudoDef(
            name=decl.name,
            inputs=[
                item
                for item in inputs
                if isinstance(item, Item)
            ],
            outputs=outputs,
            targets=[target.strip() for target in targets[1:-1].split(",")],
            sequence=targets.startswith("["),
            flags=decl.flags.split()
        );
    }
    a = Analysis(
        uops=uops,
        instructions=instructions,
        pseudos=pseudos,
        opmap={},
        have_arg=0,
        min_instrumented=0
    );
    assign_opcodes(a);
    return a;
}

# Give `name` the first free opcode from `start`; returns the next start.
def place(opmap: dict[str, int], name: str, start: int) -> int {
    if name in opmap {
        return start;
    }
    taken = set(opmap.values());
    while start in taken {
        start += 1;
    }
    opmap[name] = start;
    return start + 1;
}

def assign_opcodes(a: Analysis) {
    opmap: dict[str, int] = {};
    for (name, code) in OPCODE_PINS {
        opmap[name] = code;
    }
    instrumented = [
        name
        for name in a.instructions
        if name.startswith("INSTRUMENTED")
    ];
    specialized: set[str] = set();
    for family in FAMILIES {
        specialized.update(family.members);
    }
    no_arg: list[str] = [];
    has_arg: list[str] = [];
    for (name, inst) in a.instructions.items() {
        if name in specialized or name in instrumented {
            continue;
        }
        if "ARG" in instr_facts(inst) {
            has_arg.append(name);
        } else {
            no_arg.append(name);
        }
    }
    a.min_instrumented = 254 - (len(instrumented) - 1);
    start = 1;
    for name in sorted(no_arg) {
        start = place(opmap, name, start);
    }
    for name in sorted(has_arg) {
        start = place(opmap, name, start);
    }
    start = opmap["RESUME"] + 1;
    for name in sorted(specialized) {
        start = place(opmap, name, start);
    }
    start = a.min_instrumented;
    for name in instrumented {
        start = place(opmap, name, start);
    }
    for (index, name) in enumerate(sorted(a.pseudos)) {
        opmap[name] = 256 + index;
    }
    a.opmap = opmap;
    a.have_arg = len(no_arg);
}

# ---------------------------------------------------------------- shared views

def cflags(facts: set[str]) -> str {
    out: list[str] = [];
    for flag in FLAG_ORDER {
        if flag == "ERROR" {
            if "ERROR" in facts or "ERROR_NO_POP" in facts {
                out.append("HAS_ERROR_FLAG");
            }
        } elif flag in facts {
            out.append(f"HAS_{flag}_FLAG");
        }
    }
    return " | ".join(out) or "0";
}

def instr_effect(inst: InstrDef) -> tuple[str, str] {
    return stack_effect(
        [
            (part.uop.inputs, part.uop.outputs)
            for part in inst.parts
            if part.uop is not None
        ]
    );
}

# Every instruction's and pseudo instruction's (popped, pushed), by name.
def stack_effects(a: Analysis) -> dict[str, tuple[str, str]] {
    out: dict[str, tuple[str, str]] = {};
    for (name, inst) in a.instructions.items() {
        out[name] = instr_effect(inst);
    }
    for (name, pseudo) in a.pseudos.items() {
        out[name] = stack_effect([(pseudo.inputs, pseudo.outputs)]);
    }
    return out;
}

def instr_format(inst: InstrDef) -> str {
    text = "INSTR_FMT_IB" if "ARG" in instr_facts(inst) else "INSTR_FMT_IX";
    if inst.size() > 1 {
        text += "C";
    }
    return text + "0" * (inst.size() - 2);
}

# Whether `inst` is a superinstruction: a single uop named after the two
# single-uop instructions it joins.
def is_super(inst: InstrDef, a: Analysis) -> bool {
    if len(inst.parts) != 1 or inst.parts[0].uop is None {
        return False;
    }
    pieces = inst.name.split("_");
    if len(pieces) % 2 {
        return False;
    }
    half = len(pieces) // 2;
    first = "_".join(pieces[:half]);
    second = "_".join(pieces[half:]);
    return first in a.instructions
        and second in a.instructions
        and len(a.instructions[first].parts) == 1
        and len(a.instructions[second].parts) == 1;
}

# The cache entries each family head (and each instruction outside a family)
# carries, in declaration order.
def cache_counts(a: Analysis) -> list[tuple[str, int]] {
    out: list[tuple[str, int]] = [];
    for (name, inst) in a.instructions.items() {
        if inst.family and inst.family != name {
            continue;
        }
        if name.startswith("INSTRUMENTED") {
            continue;
        }
        if inst.size() > 1 {
            out.append((name, inst.size() - 1));
        }
    }
    return out;
}

def deopt_of(inst: InstrDef) -> str {
    return inst.family or inst.name;
}

# ---------------------------------------------------------------- C headers

def header(generator: str, comment: str) -> str {
    return f"{comment} This file is generated by Tools/cases_generator/{generator}\n"
        + f"{comment} from:\n{comment}   {SOURCE}\n{comment} Do not edit!\n";
}

def guard_open(name: str) -> str {
    return f'\n#ifndef {name}\n#define {name}\n#ifdef __cplusplus\nextern "C" {{\n#endif\n\n';
}

def guard_close(name: str) -> str {
    return f"\n#ifdef __cplusplus\n}}\n#endif\n#endif /* !{name} */\n";
}

def define(name: str, value: int) -> str {
    return f"#define {name:<38} {value:>3}\n";
}

def opcode_ids_h(a: Analysis) -> str {
    out = writer();
    out.raw(header("opcode_id_generator.py", "//"));
    out.raw(guard_open("Py_OPCODE_IDS_H"));
    out.emit("/* Instruction opcodes for compiled code */\n");
    for (code, name) in sorted([(code, name) for (name, code) in a.opmap.items()]) {
        out.emit(define(name, code));
    }
    out.emit("\n");
    out.emit(define("HAVE_ARGUMENT", a.have_arg));
    out.emit(define("MIN_SPECIALIZED_OPCODE", a.opmap["RESUME"] + 1));
    out.emit(define("MIN_INSTRUMENTED_OPCODE", a.min_instrumented));
    out.raw(guard_close("Py_OPCODE_IDS_H"));
    return out.text();
}

def emit_effect_function(out: CWriter, direction: str, data: list[tuple[str, str]]) {
    out.emit(f"extern int _PyOpcode_num_{direction}(int opcode, int oparg);\n");
    out.emit("#ifdef NEED_OPCODE_METADATA\n");
    out.emit(f"int _PyOpcode_num_{direction}(int opcode, int oparg)  {{\n");
    out.emit("switch(opcode) {\n");
    for (name, effect) in data {
        out.emit(f"case {name}:\n");
        out.emit(f"    return {effect};\n");
    }
    out.emit("default:\n");
    out.emit("    return -1;\n");
    out.emit("}\n");
    out.emit("}\n\n");
    out.emit("#endif\n\n");
}

def emit_metadata_table(out: CWriter, a: Analysis) {
    size = 256 + len(a.pseudos);
    out.emit("struct opcode_metadata {\n");
    out.emit("uint8_t valid_entry;\n");
    out.emit("uint8_t instr_format;\n");
    out.emit("uint16_t flags;\n");
    out.emit("};\n\n");
    out.emit(
        f"extern const struct opcode_metadata _PyOpcode_opcode_metadata[{size}];\n"
    );
    out.emit("#ifdef NEED_OPCODE_METADATA\n");
    out.emit(f"const struct opcode_metadata _PyOpcode_opcode_metadata[{size}] = {{\n");
    for name in sorted(a.instructions) {
        inst = a.instructions[name];
        out.emit(
            f"[{name}] = {{ true, {instr_format(inst)}, {cflags(
                instr_facts(inst)
            )} }},\n"
        );
    }
    for name in sorted(a.pseudos) {
        pseudo = a.pseudos[name];
        flags = cflags(pseudo_facts(pseudo, a));
        for flag in pseudo.flags {
            flags = f"{flag}_FLAG" if flags == "0" else f"{flags} | {flag}_FLAG";
        }
        out.emit(f"[{name}] = {{ true, -1, {flags} }},\n");
    }
    out.emit("};\n");
    out.emit("#endif\n\n");
}

# Whether every part of `inst` can run in a uop trace (specializing and
# replaced uops aside).
def viable_expansion(inst: InstrDef) -> bool {
    for part in inst.parts {
        uop = part.uop;
        if uop is None {
            continue;
        }
        if "specializing" in uop.annotations or "replaced" in uop.annotations {
            continue;
        }
        if uop.tier == 1 or not uop.is_viable() {
            return False;
        }
    }
    return True;
}

def expansion(inst: InstrDef, a: Analysis) -> list[tuple[str, str, int]] {
    out: list[tuple[str, str, int]] = [];
    if is_super(inst, a) {
        pieces = inst.name.split("_");
        half = len(pieces) // 2;
        first = a.instructions["_".join(pieces[:half])].parts[0].uop;
        second = a.instructions["_".join(pieces[half:])].parts[0].uop;
        if first is not None and second is not None {
            out.append((first.name, "OPARG_TOP", 0));
            out.append((second.name, "OPARG_BOTTOM", 0));
        }
        return out;
    }
    offset = 0;
    for part in inst.parts {
        uop = part.uop;
        if uop is not None {
            if "specializing" in uop.annotations {
                continue;
            }
            kind = "OPARG_SIMPLE";
            if uop.name == "_SAVE_RETURN_OFFSET" {
                kind = "OPARG_SAVE_RETURN_OFFSET";
            } elif uop.caches {
                kind = str(uop.caches[0].size);
            }
            if "replaced" in uop.annotations {
                kind = "OPARG_REPLACED";
            }
            out.append((uop.name, kind, offset));
            if len(uop.caches) > 1 {
                inner = sum([cache.size for cache in uop.caches[:-1]]);
                out.append(
                    (uop.name, f"OPERAND1_{uop.caches[-1].size}", offset + inner)
                );
            }
        }
        offset += part.size;
    }
    return out;
}

def emit_expansion_table(out: CWriter, a: Analysis) {
    table: list[tuple[str, list[tuple[str, str, int]]]] = [];
    for name in sorted(a.instructions) {
        inst = a.instructions[name];
        if not is_super(inst, a) and not viable_expansion(inst) {
            continue;
        }
        table.append((name, expansion(inst, a)));
    }
    widest = max([len(uops) for (_, uops) in table]);
    out.emit(f"#define MAX_UOP_PER_EXPANSION {widest}\n");
    out.emit("struct opcode_macro_expansion {\n");
    out.emit("int nuops;\n");
    out.emit(
        "struct { int16_t uop; int8_t size; int8_t offset; } uops[MAX_UOP_PER_EXPANSION];\n"
    );
    out.emit("};\n");
    out.emit(
        "extern const struct opcode_macro_expansion _PyOpcode_macro_expansion[256];\n\n"
    );
    out.emit("#ifdef NEED_OPCODE_METADATA\n");
    out.emit("const struct opcode_macro_expansion\n");
    out.emit("_PyOpcode_macro_expansion[256] = {\n");
    for (name, uops) in table {
        entries = ", ".join(
            [f"{{ {uop}, {kind}, {offset} }}" for (uop, kind, offset) in uops]
        );
        out.emit(f"[{name}] = {{ .nuops = {len(uops)}, .uops = {{ {entries} }} }},\n");
    }
    out.emit("};\n");
    out.emit("#endif // NEED_OPCODE_METADATA\n\n");
}

def emit_pseudo_targets(out: CWriter, a: Analysis) {
    size = len(a.pseudos);
    widest = max([len(pseudo.targets) for pseudo in a.pseudos.values()]);
    out.emit("struct pseudo_targets {\n");
    out.emit("uint8_t as_sequence;\n");
    out.emit(f"uint8_t targets[{widest + 1}];\n");
    out.emit("};\n");
    out.emit(f"extern const struct pseudo_targets _PyOpcode_PseudoTargets[{size}];\n");
    out.emit("#ifdef NEED_OPCODE_METADATA\n");
    out.emit(f"const struct pseudo_targets _PyOpcode_PseudoTargets[{size}] = {{\n");
    for pseudo in a.pseudos.values() {
        targets = pseudo.targets + ["0"] * (widest + 1 - len(pseudo.targets));
        sequence = "1" if pseudo.sequence else "0";
        listed = ", ".join(targets);
        out.emit(f"[{pseudo.name}-256] = {{ {sequence}, {{ {listed} }} }},\n");
    }
    out.emit("};\n\n");
    out.emit("#endif // NEED_OPCODE_METADATA\n");
    out.emit("static inline bool\n");
    out.emit("is_pseudo_target(int pseudo, int target) {\n");
    out.emit(f"if (pseudo < 256 || pseudo >= {256 + size}) {{\n");
    out.emit("return false;\n");
    out.emit("}\n");
    out.emit(
        "for (int i = 0; _PyOpcode_PseudoTargets[pseudo-256].targets[i]; i++) {\n"
    );
    out.emit(
        "if (_PyOpcode_PseudoTargets[pseudo-256].targets[i] == target) return true;\n"
    );
    out.emit("}\n");
    out.emit("return false;\n");
    out.emit("}\n\n");
}

def opcode_metadata_h(a: Analysis) -> str {
    out = writer();
    out.raw(header("opcode_metadata_generator.py", "//"));
    out.raw(guard_open("Py_CORE_OPCODE_METADATA_H"));
    out.emit("#ifndef Py_BUILD_CORE\n");
    out.emit('#  error "this header requires Py_BUILD_CORE define"\n');
    out.emit("#endif\n\n");
    out.emit("#include <stdbool.h>              // bool\n");
    out.emit('#include "opcode_ids.h"\n');
    out.emit("\n\n#define IS_PSEUDO_INSTR(OP)  ( \\\n");
    for name in a.pseudos {
        out.emit(f"((OP) == {name}) || \\\n");
    }
    out.emit("0");
    out.emit(")\n\n");
    out.emit('#include "pycore_uop_ids.h"\n');
    effects = stack_effects(a);
    names = sorted(effects);
    emit_effect_function(out, "popped", [(name, effects[name][0]) for name in names]);
    emit_effect_function(out, "pushed", [(name, effects[name][1]) for name in names]);
    out.emit("enum InstructionFormat {\n");
    formats = sorted(set([instr_format(inst) for inst in a.instructions.values()]));
    for (index, text) in enumerate(formats) {
        out.emit(f"{text} = {index + 1},\n");
    }
    out.emit("};\n\n");
    size = 256 + len(a.pseudos);
    out.emit("#define IS_VALID_OPCODE(OP) \\\n");
    out.emit(f"    (((OP) >= 0) && ((OP) < {size}) && \\\n");
    out.emit("     (_PyOpcode_opcode_metadata[(OP)].valid_entry))\n\n");
    for (bit, flag) in enumerate(FLAGS) {
        out.emit(f"#define HAS_{flag}_FLAG ({1 << bit})\n");
    }
    for flag in FLAGS {
        out.emit(
            f"#define OPCODE_HAS_{flag}(OP) (_PyOpcode_opcode_metadata[OP].flags & (HAS_{flag}_FLAG))\n"
        );
    }
    out.emit("\n");
    for (name, value) in OPARG_KINDS {
        out.emit(f"#define {name} {value}\n");
    }
    out.emit("\n");
    emit_metadata_table(out, a);
    emit_expansion_table(out, a);
    out.emit(f"extern const char *_PyOpcode_OpName[{size}];\n");
    out.emit("#ifdef NEED_OPCODE_METADATA\n");
    out.emit(f"const char *_PyOpcode_OpName[{size}] = {{\n");
    for name in sorted(list(a.instructions) + list(a.pseudos)) {
        out.emit(f'[{name}] = "{name}",\n');
    }
    out.emit("};\n");
    out.emit("#endif\n\n");
    out.emit("extern const uint8_t _PyOpcode_Caches[256];\n");
    out.emit("#ifdef NEED_OPCODE_METADATA\n");
    out.emit("const uint8_t _PyOpcode_Caches[256] = {\n");
    for (name, count) in cache_counts(a) {
        out.emit(f"[{name}] = {count},\n");
    }
    out.emit("};\n");
    out.emit("#endif\n\n");
    out.emit("extern const uint8_t _PyOpcode_Deopt[256];\n");
    out.emit("#ifdef NEED_OPCODE_METADATA\n");
    out.emit("const uint8_t _PyOpcode_Deopt[256] = {\n");
    deopts = [(name, deopt_of(inst)) for (name, inst) in a.instructions.items()];
    defined = set(a.opmap.values());
    for code in range(256) {
        if code not in defined {
            deopts.append((str(code), str(code)));
        }
    }
    for (name, deopt) in sorted(deopts) {
        out.emit(f"[{name}] = {deopt},\n");
    }
    out.emit("};\n\n");
    out.emit("#endif // NEED_OPCODE_METADATA\n\n");
    out.emit("#define EXTRA_CASES \\\n");
    for code in range(256) {
        if code not in defined {
            out.emit(f"    case {code}: \\\n");
        }
    }
    out.emit("        ;\n");
    emit_pseudo_targets(out, a);
    out.raw(guard_close("Py_CORE_OPCODE_METADATA_H"));
    return out.text();
}

# Uops a trace can hold, in declaration order.
def trace_uops(a: Analysis) -> list[UopDef] {
    return [
        uop
        for uop in a.uops.values()
        if uop.is_viable() and uop.tier != 1
    ];
}

def uop_ids_h(a: Analysis) -> str {
    out = writer();
    out.raw(header("uop_id_generator.py", "//"));
    out.raw(guard_open("Py_CORE_UOP_IDS_H"));
    out.emit("#define _EXIT_TRACE 300\n");
    out.emit("#define _SET_IP 301\n");
    next_id = 302;
    named = {uop.name: uop for uop in a.uops.values()};
    for name in sorted(named) {
        uop = named[name];
        if name in ("_EXIT_TRACE", "_SET_IP") or uop.tier == 1 {
            continue;
        }
        if uop.implicit and not uop.replicated {
            out.emit(f"#define {name} {name[1:]}\n");
        } else {
            out.emit(f"#define {name} {next_id}\n");
            next_id += 1;
        }
    }
    out.emit(f"#define MAX_UOP_ID {next_id - 1}\n");
    out.raw(guard_close("Py_CORE_UOP_IDS_H"));
    return out.text();
}

def uop_metadata_h(a: Analysis) -> str {
    out = writer();
    out.raw(header("uop_metadata_generator.py", "//"));
    out.raw(guard_open("Py_CORE_UOP_METADATA_H"));
    out.emit("#include <stdint.h>\n");
    out.emit('#include "pycore_uop_ids.h"\n');
    out.emit("extern const uint16_t _PyUop_Flags[MAX_UOP_ID+1];\n");
    out.emit("extern const uint8_t _PyUop_Replication[MAX_UOP_ID+1];\n");
    out.emit("extern const char * const _PyOpcode_uop_name[MAX_UOP_ID+1];\n\n");
    out.emit("extern int _PyUop_num_popped(int opcode, int oparg);\n\n");
    out.emit("#ifdef NEED_OPCODE_METADATA\n");
    out.emit("const uint16_t _PyUop_Flags[MAX_UOP_ID+1] = {\n");
    for uop in trace_uops(a) {
        out.emit(f"[{uop.name}] = {cflags(uop.facts)},\n");
    }
    out.emit("};\n\n");
    out.emit("const uint8_t _PyUop_Replication[MAX_UOP_ID+1] = {\n");
    for uop in a.uops.values() {
        if uop.replicated {
            out.emit(f"[{uop.name}] = {uop.replicated},\n");
        }
    }
    out.emit("};\n\n");
    out.emit("const char *const _PyOpcode_uop_name[MAX_UOP_ID+1] = {\n");
    for name in sorted([uop.name for uop in trace_uops(a)]) {
        out.emit(f'[{name}] = "{name}",\n');
    }
    out.emit("};\n");
    out.emit("int _PyUop_num_popped(int opcode, int oparg)\n{\n");
    out.emit("switch(opcode) {\n");
    for uop in trace_uops(a) {
        stack = Stack(base=zero(), logical=zero(), variables=[]);
        for item in reversed(uop.inputs) {
            if item.peek {
                break;
            }
            stack.pop(item);
        }
        out.emit(f"case {uop.name}:\n");
        out.emit(f"    return {offset_c(offset_neg(stack.base))};\n");
    }
    out.emit("default:\n");
    out.emit("    return -1;\n");
    out.emit("}\n");
    out.emit("}\n\n");
    out.emit("#endif // NEED_OPCODE_METADATA\n\n");
    out.raw(guard_close("Py_CORE_UOP_METADATA_H"));
    return out.text();
}

def py_metadata(a: Analysis) -> str {
    out = writer();
    out.raw(header("py_metadata_generator.py", "#"));
    specialized: list[str] = [];
    out.emit("_specializations = {\n");
    for family in FAMILIES {
        out.emit(f'"{family.head}": [\n');
        for member in family.members {
            out.emit(f'    "{member}",\n');
            specialized.append(member);
        }
        out.emit("],\n");
    }
    out.emit("}\n\n");
    out.emit("_specialized_opmap = {\n");
    for name in sorted(specialized) {
        out.emit(f"'{name}': {a.opmap[name]},\n");
    }
    out.emit("}\n\n");
    out.emit("opmap = {\n");
    for (name, code) in a.opmap.items() {
        if name not in specialized {
            out.emit(f"'{name}': {code},\n");
        }
    }
    out.emit("}\n\n");
    out.emit(f"HAVE_ARGUMENT = {a.have_arg}\n");
    out.emit(f"MIN_INSTRUMENTED_OPCODE = {a.min_instrumented}\n");
    return out.text();
}

# ---------------------------------------------------------------- opcode_meta.jac

glob META_CONSTANTS: str = """
# ---------------- binary-operator ids (opcode.h NB_*) ----------------
glob NB_ADD: int = 0,
     NB_AND: int = 1,
     NB_FLOOR_DIVIDE: int = 2,
     NB_LSHIFT: int = 3,
     NB_MATRIX_MULTIPLY: int = 4,
     NB_MULTIPLY: int = 5,
     NB_REMAINDER: int = 6,
     NB_OR: int = 7,
     NB_POWER: int = 8,
     NB_RSHIFT: int = 9,
     NB_SUBTRACT: int = 10,
     NB_TRUE_DIVIDE: int = 11,
     NB_XOR: int = 12,
     NB_INPLACE_ADD: int = 13,
     NB_INPLACE_AND: int = 14,
     NB_INPLACE_FLOOR_DIVIDE: int = 15,
     NB_INPLACE_LSHIFT: int = 16,
     NB_INPLACE_MATRIX_MULTIPLY: int = 17,
     NB_INPLACE_MULTIPLY: int = 18,
     NB_INPLACE_REMAINDER: int = 19,
     NB_INPLACE_OR: int = 20,
     NB_INPLACE_POWER: int = 21,
     NB_INPLACE_RSHIFT: int = 22,
     NB_INPLACE_SUBTRACT: int = 23,
     NB_INPLACE_TRUE_DIVIDE: int = 24,
     NB_INPLACE_XOR: int = 25,
     NB_SUBSCR: int = 26,
     NB_OPARG_LAST: int = 26;

# ---------------- rich-compare kinds (cmp_op tuple order) ----------------
glob CMP_LT: int = 0,
     CMP_LE: int = 1,
     CMP_EQ: int = 2,
     CMP_NE: int = 3,
     CMP_GT: int = 4,
     CMP_GE: int = 5;

# ---------------- compare masks (pycore_code.h COMPARISON_*) ----------------
glob COMPARISON_EQUALS: int = 8,
     COMPARISON_GREATER_THAN: int = 4,
     COMPARISON_LESS_THAN: int = 2,
     COMPARISON_NOT_EQUALS: int = 7,
     COMPARISON_UNORDERED: int = 1;

# COMPARE_OP oparg low bits (codegen.c compare_masks[]).
def compare_mask(cmp_kind: int) -> int {
    if cmp_kind == CMP_LT {
        return 2;
    }
    if cmp_kind == CMP_LE {
        return 10;
    }
    if cmp_kind == CMP_EQ {
        return 8;
    }
    if cmp_kind == CMP_NE {
        return 7;
    }
    if cmp_kind == CMP_GT {
        return 4;
    }
    if cmp_kind == CMP_GE {
        return 12;
    }
    return 0;
}

# cmp_kind in top three bits, compare mask in low four (codegen.c).
def compare_oparg(cmp_kind: int) -> int {
    return (cmp_kind << 5) | compare_mask(cmp_kind);
}

# Bool-context filters set the fifth-lowest bit (codegen.c).
def compare_filter_oparg(cmp_kind: int) -> int {
    return compare_oparg(cmp_kind) | 16;
}

# ---------------- code-object flags (code.h CO_*) ----------------
glob CO_OPTIMIZED: int = 1,
     CO_NEWLOCALS: int = 2,
     CO_VARARGS: int = 4,
     CO_VARKEYWORDS: int = 8,
     CO_NESTED: int = 16,
     CO_GENERATOR: int = 32,
     CO_COROUTINE: int = 128,
     CO_ITERABLE_COROUTINE: int = 256,
     CO_ASYNC_GENERATOR: int = 512,
     CO_FUTURE_DIVISION: int = 131072,
     CO_FUTURE_WITH_STATEMENT: int = 524288,
     CO_FUTURE_PRINT_FUNCTION: int = 1048576,
     CO_FUTURE_UNICODE_LITERALS: int = 2097152,
     CO_FUTURE_BARRY_AS_BDFL: int = 4194304,
     CO_FUTURE_GENERATOR_STOP: int = 8388608,
     CO_FUTURE_ANNOTATIONS: int = 16777216,
     CO_NO_MONITORING_EVENTS: int = 33554432,
     CO_HAS_DOCSTRING: int = 67108864,
     CO_METHOD: int = 134217728;

# co_localspluskinds bits (Include/internal/pycore_code.h).
glob CO_FAST_HIDDEN: int = 16,
     CO_FAST_LOCAL: int = 32,
     CO_FAST_CELL: int = 64,
     CO_FAST_FREE: int = 128;

# CPython locals-plus kind bit flags (marshal reader / symtable contract).
glob LP_LOCAL: int = 32,
     LP_CELL: int = 64,
     LP_FREE: int = 128;
""",
     META_STACK_EFFECT: str = """
# Net stack effect (flowgraph.c get_stack_effects). jump: 0=fallthrough,
# 1=taken target, -1=maximal (unused on the CFG path).
def stack_effect(op: int, oparg: int, jump: int) -> int | None {
    if op < 0 {
        return None;
    }
    if op <= MAX_REAL_OPCODE {
        deopt = opcode_deopt_target(op);
        if deopt != op {
            return None;
        }
    }
    popped = _opcode_num_popped(op, oparg);
    pushed = _opcode_num_pushed(op, oparg);
    if popped < 0 or pushed < 0 {
        return None;
    }
    if is_block_push_opcode(op) and jump == 0 {
        return 0;
    }
    return pushed - popped;
}

def is_block_push_opcode(op: int) -> bool {
    if op == OP_SETUP_FINALLY or op == OP_SETUP_WITH or op == OP_SETUP_CLEANUP {
        return True;
    }
    return False;
}
""",
     META_CLASSIFIERS: str = """
def is_unconditional_jump_opcode(op: int) -> bool {
    if op == OP_JUMP
        or op == OP_JUMP_NO_INTERRUPT
        or op == OP_JUMP_FORWARD
        or op == OP_JUMP_BACKWARD
        or op == OP_JUMP_BACKWARD_NO_INTERRUPT {
        return True;
    }
    return False;
}

def is_scope_exit_opcode(op: int) -> bool {
    if op == OP_RETURN_VALUE or op == OP_RAISE_VARARGS or op == OP_RERAISE {
        return True;
    }
    return False;
}

def is_assembler_opcode(op: int) -> bool {
    if op == OP_JUMP_FORWARD
        or op == OP_JUMP_BACKWARD
        or op == OP_JUMP_BACKWARD_NO_INTERRUPT {
        return True;
    }
    return False;
}
""",
     META_ACCESSORS: str = """
def opcode_has_arg(op: int) -> bool {
    return _OPCODE_FLAGS.get(op, 0) & OC_ARG != 0;
}

def opcode_has_const(op: int) -> bool {
    return _OPCODE_FLAGS.get(op, 0) & OC_CONST != 0;
}

def opcode_has_name(op: int) -> bool {
    return _OPCODE_FLAGS.get(op, 0) & OC_NAME != 0;
}

def opcode_has_local(op: int) -> bool {
    return _OPCODE_FLAGS.get(op, 0) & OC_LOCAL != 0;
}

def opcode_has_jump(op: int) -> bool {
    return _OPCODE_FLAGS.get(op, 0) & OC_JUMP != 0;
}

def opcode_has_free(op: int) -> bool {
    return _OPCODE_FLAGS.get(op, 0) & OC_FREE != 0;
}

def instruction_width(op: int) -> int {
    return 2 + opcode_cache_count(op);
}

# Advance ip past one instruction (including EXTENDED_ARG prefix chain).
def next_instruction_ip(code: list[int], ip: int) -> int {
    ext = 0;
    while ip < len(code) {
        op = code[ip];
        arg = code[ip + 1];
        arg = arg | (ext << 8);
        ext = 0;
        if op == OP_EXTENDED_ARG {
            ext = arg;
            ip = ip + 2;
            continue;
        }
        return ip + instruction_width(op);
    }
    return ip;
}
""",
     # The classification bits opcode_meta.jac keeps, by flag.
     META_CLASSES: list[tuple[str, str, int]] = [
         ("ARG", "OC_ARG", 1),
         ("CONST", "OC_CONST", 2),
         ("NAME", "OC_NAME", 4),
         ("LOCAL", "OC_LOCAL", 8),
         ("JUMP", "OC_JUMP", 16),
         ("FREE", "OC_FREE", 32)
     ];

def glob_block(entries: list[str]) -> str {
    return "glob " + ",\n     ".join(entries) + ";\n";
}

def dict_block(name: str, kind: str, entries: list[str]) -> str {
    return f"glob {name}: {kind} = {{\n"
        + ",\n".join([f"         {row}" for row in entries])
        + "\n     };\n";
}

def effect_function(name: str, data: list[tuple[str, str]]) -> str {
    lines = [f"def {name}(op: int, oparg: int) -> int {{"];
    for (opname, effect) in data {
        lines += [f"    if op == OP_{opname} {{", f"        return {effect};", "    }"];
    }
    lines += ["    return -1;", "}"];
    return "\n".join(lines) + "\n";
}

def or_chain(names: list[str]) -> str {
    return "\n        or ".join([f"op == OP_{name}" for name in names]);
}

def opcode_meta_module(a: Analysis) -> str {
    by_code = sorted([(code, name) for (name, code) in a.opmap.items()]);
    facts: dict[str, set[str]] = {};
    for (name, inst) in a.instructions.items() {
        facts[name] = instr_facts(inst);
    }
    for (name, pseudo) in a.pseudos.items() {
        facts[name] = pseudo_facts(pseudo, a)
            | set([flag[4:] for flag in pseudo.flags]);
    }
    effects = stack_effects(a);
    names = sorted(effects);
    deopts = [
        f"OP_{name}: {a.opmap[deopt_of(a.instructions[name])]}"
        for (_, name) in by_code
        if name in a.instructions and deopt_of(a.instructions[name]) != name
    ];
    caches = dict(cache_counts(a));
    classes: list[str] = [];
    for (_, name) in by_code {
        bits = [
            label
            for (flag, label, _) in META_CLASSES
            if flag in facts[name]
        ];
        if bits {
            joined = " | ".join(bits);
            classes.append(f"OP_{name}: {joined}");
        }
    }
    targets = sorted(
        [
            name
            for name in a.opmap
            if "JUMP" in facts[name]
                or name in ("SETUP_FINALLY", "SETUP_WITH", "SETUP_CLEANUP")
        ]
    );
    parts = [
        '"""CPython\'s opcode and code-object metadata: opcode numbers, inline cache\n'
            + "counts, deopt targets, stack effects, opcode classes and the operator and\n"
            + "code-object constants the bytecode compiler and the runtime read.\n\n"
            + f"Generated by {COMMAND} from\n"
            + "scripts/jacpython/instructions.jac; do not edit. See LICENSE.cpython.\n"
            + '"""\n',
        "glob MAX_REAL_OPCODE: int = 254;\n",
        "# ---------------- instruction opcodes (opcode_ids.h) ----------------\n"
            + glob_block([f"OP_{name}: int = {code}" for (code, name) in by_code]),
        META_CONSTANTS,
        "# Inline-cache unit counts (_PyOpcode_Caches).\n"
            + dict_block(
                "_OPCODE_CACHE_COUNT",
                "dict[int, int]",
                [
                    f"OP_{name}: {caches[name]}"
                    for (_, name) in by_code
                    if name in caches
                ]
            ),
        "def opcode_cache_count(op: int) -> int {\n"
            + "    return _OPCODE_CACHE_COUNT.get(op, 0);\n}\n",
        dict_block("_OPCODE_DEOPT_MAP", "dict[int, int]", deopts),
        "def opcode_deopt_target(op: int) -> int {\n"
            + "    if op < 0 or op > 254 {\n        return op;\n    }\n"
            + "    return _OPCODE_DEOPT_MAP.get(op, op);\n}\n",
        effect_function(
            "_opcode_num_popped", [(name, effects[name][0]) for name in names]
        ),
        effect_function(
            "_opcode_num_pushed", [(name, effects[name][1]) for name in names]
        ),
        META_STACK_EFFECT,
        "def has_target(op: int) -> bool {\n    if "
            + or_chain(targets)
            + " {\n        return True;\n    }\n    return False;\n}\n",
        META_CLASSIFIERS,
        dict_block(
            "_OPCODE_IS_VALID_SET", "set[int]", [f"OP_{name}" for (_, name) in by_code]
        ),
        "def opcode_is_valid(op: int) -> bool {\n"
            + "    return op in _OPCODE_IS_VALID_SET;\n}\n",
        "# Opcode classification families (CPython opcode metadata has_* sets).\n"
            + glob_block([f"{label}: int = {bit}" for (_, label, bit) in META_CLASSES]),
        "# opcode -> classification membership; opcodes absent from the table carry none.\n"
            + dict_block("_OPCODE_FLAGS", "dict[int, int]", classes),
        META_ACCESSORS
    ];
    return "\n".join([part.strip("\n") + "\n" for part in parts]);
}

with entry {
    parser = argparse.ArgumentParser(
        description="Generate CPython's opcode metadata from the instruction table."
    );
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    a = analyze();
    published = [
        (OPCODE_IDS, opcode_ids_h(a)),
        (OPCODE_METADATA, opcode_metadata_h(a)),
        (UOP_IDS, uop_ids_h(a)),
        (UOP_METADATA, uop_metadata_h(a)),
        (PY_METADATA, py_metadata(a))
    ];
    ok = True;
    for (path, text) in published {
        ok = write_or_check(GENERATED / f"{path}.in", text, args.check, COMMAND) and ok;
    }
    ok = write_or_check(
        OPCODE_META, format_jac(opcode_meta_module(a), OPCODE_META), args.check, COMMAND
    )
        and ok;
    if not ok {
        sys.exit(1);
    }
}
