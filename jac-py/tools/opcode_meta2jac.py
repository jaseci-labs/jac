"""opcode_meta2jac - emit Jac opcode metadata from pinned CPython headers.

Phase 3 generator (INTEGRATION_PLAN.md): vendored reference/cpython input,
checked-in jacpython/opcode_meta.jac output, --check drift guard.

Reads:
  Include/opcode_ids.h
  Include/opcode.h
  Include/cpython/code.h
  Include/internal/pycore_code.h
  Include/internal/pycore_opcode_metadata.h
  Include/internal/pycore_opcode_utils.h

Usage:
    python jac-py/tools/opcode_meta2jac.py
    python jac-py/tools/opcode_meta2jac.py --check
    python jac-py/tools/opcode_meta2jac.py --stdout
"""

from __future__ import annotations

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(os.path.dirname(_HERE))
_CPY = os.path.join(_REPO, "reference", "cpython")
OUT_PATH = os.path.join(_REPO, "jac-py", "jacpython", "opcode_meta.jac")

PROVENANCE = [
    "reference/cpython/Include/opcode_ids.h",
    "reference/cpython/Include/opcode.h",
    "reference/cpython/Include/cpython/code.h",
    "reference/cpython/Include/internal/pycore_code.h",
    "reference/cpython/Include/internal/pycore_opcode_metadata.h",
    "reference/cpython/Include/internal/pycore_opcode_utils.h",
]

MAX_REAL_OPCODE = 254
HAS_JUMP_FLAG = 8

_DEFINE_RE = re.compile(r"^#define\s+([A-Z_][A-Z0-9_]*)\s+(-?0[xX][0-9a-fA-F]+|-?\d+)\s*$")
_COMPARISON_DEFINE_RE = re.compile(
    r"^#define\s+(COMPARISON_[A-Z_]+)\s+(.+?)\s*$"
)
_CASE_RE = re.compile(r"^\s*case\s+([A-Z_][A-Z0-9_]*)\s*:\s*$")
_RETURN_RE = re.compile(r"^\s*return\s+(.+?);\s*$")
_ARRAY_ENTRY_RE = re.compile(r"^\s*\[([A-Za-z_][A-Za-z0-9_]*|\d+)\]\s*=\s*([^,]+),\s*$")
_METADATA_ENTRY_RE = re.compile(
    r"^\s*\[([A-Z_][A-Z0-9_]*)\]\s*=\s*\{\s*true,\s*[^,]+,\s*([^}]+)\}\s*,\s*$"
)
# Full metadata row: [NAME] = { valid_entry, instr_format?, flag | ... },
_METADATA_ROW_RE = re.compile(
    r"^\s*\[([A-Z_][A-Z0-9_]*)\]\s*=\s*\{\s*(true|false)\s*,"
    r"(?:\s*(?:[A-Z][A-Z0-9_]*|-1),)?\s*([A-Z0-9_ |]*)\}\s*,\s*$"
)

# OPCODE_HAS_* predicates emitted from _PyOpcode_opcode_metadata flags.
_METADATA_FLAG_CLASSIFIERS = [
    ("opcode_has_arg", "HAS_ARG_FLAG"),
    ("opcode_has_const", "HAS_CONST_FLAG"),
    ("opcode_has_name", "HAS_NAME_FLAG"),
    ("opcode_has_jump", "HAS_JUMP_FLAG"),
    ("opcode_has_free", "HAS_FREE_FLAG"),
    ("opcode_has_local", "HAS_LOCAL_FLAG"),
]

# Hand-maintained Jac constants not present as CO_/NB_ defines in the pinned headers.
CMP_CONSTANTS = [
    ("CMP_LT", 0),
    ("CMP_LE", 1),
    ("CMP_EQ", 2),
    ("CMP_NE", 3),
    ("CMP_GT", 4),
    ("CMP_GE", 5),
]
LP_CONSTANTS = [
    ("LP_LOCAL", 32),
    ("LP_CELL", 64),
    ("LP_FREE", 128),
]

# pycore_opcode_utils.h macro bodies (opcode names, not numeric literals).
UNCONDITIONAL_JUMP_OPS = [
    "JUMP",
    "JUMP_NO_INTERRUPT",
    "JUMP_FORWARD",
    "JUMP_BACKWARD",
    "JUMP_BACKWARD_NO_INTERRUPT",
]
SCOPE_EXIT_OPS = ["RETURN_VALUE", "RAISE_VARARGS", "RERAISE"]
BLOCK_PUSH_OPS = ["SETUP_FINALLY", "SETUP_WITH", "SETUP_CLEANUP"]
ASSEMBLER_OPS = ["JUMP_FORWARD", "JUMP_BACKWARD", "JUMP_BACKWARD_NO_INTERRUPT"]

# codegen.c compare_masks[] keyed by Py_LT..Py_GE (cmp_op tuple order).
COMPARE_MASK_EXPRS: list[tuple[str, str]] = [
    ("CMP_LT", "COMPARISON_LESS_THAN"),
    ("CMP_LE", "COMPARISON_LESS_THAN | COMPARISON_EQUALS"),
    ("CMP_EQ", "COMPARISON_EQUALS"),
    ("CMP_NE", "COMPARISON_NOT_EQUALS"),
    ("CMP_GT", "COMPARISON_GREATER_THAN"),
    ("CMP_GE", "COMPARISON_GREATER_THAN | COMPARISON_EQUALS"),
]


def _read(path: str) -> str:
    with open(path) as fh:
        return fh.read()


def parse_defines(text: str) -> dict[str, int]:
    out: dict[str, int] = {}
    for line in text.splitlines():
        m = _DEFINE_RE.match(line.strip())
        if m:
            out[m.group(1)] = int(m.group(2), 0)
    return out


def parse_comparison_defines(text: str) -> dict[str, int]:
    raw: dict[str, str] = {}
    for line in text.splitlines():
        m = _COMPARISON_DEFINE_RE.match(line.strip())
        if m:
            raw[m.group(1)] = m.group(2)
    resolved: dict[str, int] = {}
    pending = dict(raw)
    while pending:
        progressed = False
        for name, expr in list(pending.items()):
            substituted = expr
            unresolved = False
            for other in pending:
                if other != name and re.search(rf"\b{re.escape(other)}\b", substituted):
                    unresolved = True
                    break
            if unresolved:
                continue
            for rname, rval in resolved.items():
                substituted = re.sub(
                    rf"\b{re.escape(rname)}\b", str(rval), substituted
                )
            substituted = substituted.strip()
            if not re.fullmatch(r"[\d\s|()+]+", substituted):
                raise ValueError(f"unsupported comparison define: {name} = {expr}")
            resolved[name] = eval(substituted, {"__builtins__": {}})  # noqa: S307
            del pending[name]
            progressed = True
        if not progressed:
            raise ValueError(f"unresolved comparison defines: {sorted(pending)}")
    return resolved


def eval_comparison_expr(expr: str, comparison_defs: dict[str, int]) -> int:
    substituted = expr.strip()
    for name, val in sorted(comparison_defs.items(), key=lambda kv: len(kv[0]), reverse=True):
        substituted = re.sub(rf"\b{re.escape(name)}\b", str(val), substituted)
    if not re.fullmatch(r"[\d\s|()+]+", substituted):
        raise ValueError(f"unsupported comparison mask expression: {expr}")
    return eval(substituted, {"__builtins__": {}})  # noqa: S307


def parse_switch_function(text: str, func_name: str) -> list[tuple[str, str]]:
    marker = f"int {func_name}(int opcode, int oparg)"
    start = text.find(marker)
    if start < 0:
        raise ValueError(f"{func_name} not found in opcode metadata header")
    chunk = text[start:]
    brace = chunk.find("{")
    if brace < 0:
        raise ValueError(f"{func_name} body not found")
    depth = 0
    end = None
    for i, ch in enumerate(chunk[brace:], start=brace):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise ValueError(f"{func_name} body not terminated")
    body = chunk[brace:end]
    cases: list[tuple[str, str]] = []
    cur_case: str | None = None
    for line in body.splitlines():
        cm = _CASE_RE.match(line)
        if cm:
            cur_case = cm.group(1)
            continue
        rm = _RETURN_RE.match(line)
        if rm and cur_case is not None:
            cases.append((cur_case, rm.group(1)))
            cur_case = None
    return cases


def parse_sparse_array(
    text: str,
    array_name: str,
    opmap: dict[str, int],
    *,
    default_identity: bool = False,
) -> list[int]:
    marker = f"const uint8_t {array_name}[256]"
    start = text.find(marker)
    if start < 0:
        raise ValueError(f"{array_name} not found")
    chunk = text[start:]
    open_brace = chunk.find("{")
    close = chunk.find("};", open_brace)
    body = chunk[open_brace + 1 : close]
    if default_identity:
        values = list(range(256))
    else:
        values = [0] * 256
    for line in body.splitlines():
        m = _ARRAY_ENTRY_RE.match(line)
        if not m:
            continue
        key, raw = m.group(1), m.group(2).strip()
        idx = int(key) if key.isdigit() else opmap[key]
        if raw.isdigit():
            val = int(raw)
        else:
            val = opmap[raw]
        values[idx] = val
    return values


def parse_opcode_metadata(text: str) -> dict[str, tuple[bool, set[str]]]:
    # Rows of `const struct opcode_metadata _PyOpcode_opcode_metadata[267] = {...}`.
    marker = "_PyOpcode_opcode_metadata[267] = {"
    start = text.find(marker)
    if start < 0:
        raise ValueError("_PyOpcode_opcode_metadata table not found")
    chunk = text[start:]
    open_brace = chunk.find("{")
    close = chunk.find("};", open_brace)
    body = chunk[open_brace + 1 : close]
    entries: dict[str, tuple[bool, set[str]]] = {}
    for line in body.splitlines():
        m = _METADATA_ROW_RE.match(line)
        if not m:
            continue
        name, valid_raw, flags_raw = m.group(1), m.group(2), m.group(3)
        flags = {f.strip() for f in flags_raw.split("|") if f.strip()}
        entries[name] = (valid_raw == "true", flags)
    if not entries:
        raise ValueError("no metadata rows parsed")
    return entries


def emit_flag_classifier(
    fn_name: str,
    flag: str | None,
    meta: dict[str, tuple[bool, set[str]]],
    opmap: dict[str, int],
    out: list[str],
) -> None:
    out.append(f"def {fn_name}(op: int) -> bool {{")
    for name in sorted(opmap, key=lambda n: opmap[n]):
        entry = meta.get(name)
        if entry is None:
            continue
        valid, flags = entry
        ok = valid if flag is None else (valid and flag in flags)
        if ok:
            out.append(f"    if op == OP_{name} {{")
            out.append("        return True;")
            out.append("    }")
    out.append("    return False;")
    out.append("}")
    out.append("")


def parse_jump_opcodes(text: str) -> set[str]:
    jump_ops: set[str] = set()
    for line in text.splitlines():
        m = _METADATA_ENTRY_RE.match(line)
        if not m:
            continue
        name, flags = m.group(1), m.group(2)
        if "HAS_JUMP_FLAG" in flags:
            jump_ops.add(name)
    return jump_ops


def c_expr_to_jac(expr: str, opmap: dict[str, int]) -> str:
    result = expr.strip()
    for name in sorted(opmap.keys(), key=len, reverse=True):
        result = re.sub(rf"\b{re.escape(name)}\b", f"OP_{name}", result)
    result = result.replace("*", " * ")
    result = re.sub(r"\s+", " ", result).strip()
    return result


def val_to_op_name(opmap: dict[str, int], val: int) -> str:
    for name, number in opmap.items():
        if number == val:
            return name
    return str(val)


def emit_glob_constants(name: str, items: list[tuple[str, int]], out: list[str]) -> None:
    if not items:
        return
    out.append(f"glob {items[0][0]}: int = {items[0][1]},")
    for key, val in items[1:-1]:
        out.append(f"     {key}: int = {val},")
    last_key, last_val = items[-1]
    out.append(f"     {last_key}: int = {last_val};")
    out.append("")


def emit_switch_fn(
    fn_name: str,
    cases: list[tuple[str, str]],
    opmap: dict[str, int],
    out: list[str],
) -> None:
    op_names = set(opmap)
    out.append(f"def {fn_name}(op: int, oparg: int) -> int {{")
    for case_name, ret in cases:
        jac_ret = c_expr_to_jac(ret, opmap)
        out.append(f"    if op == OP_{case_name} {{")
        out.append(f"        return {jac_ret};")
        out.append("    }")
    out.append("    return -1;")
    out.append("}")
    out.append("")


def emit_compare_helpers(comparison_defs: dict[str, int], out: list[str]) -> None:
    items = sorted(comparison_defs.items(), key=lambda kv: kv[0])
    emit_glob_constants("COMPARISON", items, out)
    out.append("# COMPARE_OP oparg low bits (codegen.c compare_masks[]).")
    out.append("def compare_mask(cmp_kind: int) -> int {")
    for cmp_name, mask_expr in COMPARE_MASK_EXPRS:
        mask_val = eval_comparison_expr(mask_expr, comparison_defs)
        out.append(f"    if cmp_kind == {cmp_name} {{")
        out.append(f"        return {mask_val};")
        out.append("    }")
    out.append("    return 0;")
    out.append("}")
    out.append("")
    out.append("# cmp_kind in top three bits, compare mask in low four (codegen.c).")
    out.append("def compare_oparg(cmp_kind: int) -> int {")
    out.append("    return (cmp_kind << 5) | compare_mask(cmp_kind);")
    out.append("}")
    out.append("")
    out.append("# Bool-context filters set the fifth-lowest bit (codegen.c).")
    out.append("def compare_filter_oparg(cmp_kind: int) -> int {")
    out.append("    return compare_oparg(cmp_kind) | 16;")
    out.append("}")
    out.append("")


def emit_classifier(name: str, op_names: list[str], out: list[str]) -> None:
    out.append(f"def {name}(op: int) -> bool {{")
    if len(op_names) == 1:
        out.append(f"    return op == OP_{op_names[0]};")
    else:
        parts = [f"op == OP_{name}" for name in op_names]
        out.append("    if " + "\n        or ".join(parts) + " {")
        out.append("        return True;")
        out.append("    }")
        out.append("    return False;")
    out.append("}")
    out.append("")


def emit_has_target(jump_ops: set[str], out: list[str]) -> None:
    names = sorted(jump_ops | set(BLOCK_PUSH_OPS))
    out.append("def has_target(op: int) -> bool {")
    parts = [f"op == OP_{name}" for name in names]
    out.append("    if " + "\n        or ".join(parts) + " {")
    out.append("        return True;")
    out.append("    }")
    out.append("    return False;")
    out.append("}")
    out.append("")


def generate() -> str:
    opcode_ids = parse_defines(_read(os.path.join(_CPY, "Include", "opcode_ids.h")))
    nb_defs = parse_defines(_read(os.path.join(_CPY, "Include", "opcode.h")))
    code_defs = parse_defines(_read(os.path.join(_CPY, "Include", "cpython", "code.h")))
    comparison_defs = parse_comparison_defines(
        _read(os.path.join(_CPY, "Include", "internal", "pycore_code.h"))
    )
    meta_text = _read(
        os.path.join(_CPY, "Include", "internal", "pycore_opcode_metadata.h")
    )

    meta_names = {
        "HAVE_ARGUMENT",
        "MIN_SPECIALIZED_OPCODE",
        "MIN_INSTRUMENTED_OPCODE",
    }
    op_items = [
        (name, val)
        for name, val in sorted(opcode_ids.items(), key=lambda kv: kv[1])
        if name not in meta_names and val >= 0
    ]
    opmap = dict(op_items)

    nb_items = [(name, val) for name, val in sorted(nb_defs.items(), key=lambda kv: kv[1])]
    co_items = [
        (name, val)
        for name, val in sorted(code_defs.items(), key=lambda kv: kv[1])
        if name.startswith("CO_") and not name.endswith("MAXBLOCKS")
    ]

    popped = parse_switch_function(meta_text, "_PyOpcode_num_popped")
    pushed = parse_switch_function(meta_text, "_PyOpcode_num_pushed")
    caches = parse_sparse_array(meta_text, "_PyOpcode_Caches", opmap)
    deopt = parse_sparse_array(meta_text, "_PyOpcode_Deopt", opmap, default_identity=True)
    jump_ops = parse_jump_opcodes(meta_text)
    meta_entries = parse_opcode_metadata(meta_text)

    out: list[str] = []
    out.append("# GENERATED by jac-py/tools/opcode_meta2jac.py")
    out.append("#")
    out.append("# CPython opcode / code-object metadata (INTEGRATION_PLAN Phase 3).")
    out.append("# Single version-pinned source for opcode numbers, inline-cache counts,")
    out.append("# stack effects, jump/terminator classifiers, operator ids, and flags.")
    out.append("#")
    for path in PROVENANCE:
        out.append(f"#   {path}")
    out.append("#")
    out.append("# na-clean leaf: no imports, no host calls.")
    out.append("")

    out.append(f"glob MAX_REAL_OPCODE: int = {MAX_REAL_OPCODE};")
    out.append("")

    out.append("# ---------------- instruction opcodes (opcode_ids.h) ----------------")
    emit_glob_constants(
        "OP",
        [(f"OP_{name}", val) for name, val in op_items],
        out,
    )

    out.append("# ---------------- binary-operator ids (opcode.h NB_*) ----------------")
    emit_glob_constants("NB", nb_items, out)

    out.append("# ---------------- rich-compare kinds (cmp_op tuple order) ----------------")
    emit_glob_constants("CMP", CMP_CONSTANTS, out)

    out.append("# ---------------- compare masks (pycore_code.h COMPARISON_*) ----------------")
    emit_compare_helpers(comparison_defs, out)

    out.append("# ---------------- code-object flags (code.h CO_*) ----------------")
    emit_glob_constants("CO", co_items, out)

    out.append("# CPython locals-plus kind bit flags (marshal reader / symtable contract).")
    emit_glob_constants("LP", LP_CONSTANTS, out)

    out.append("# Inline-cache unit counts (_PyOpcode_Caches).")
    out.append("def opcode_cache_count(op: int) -> int {")
    for op, val in sorted(opmap.items(), key=lambda kv: kv[1]):
        if val < len(caches) and caches[val] != 0:
            out.append(f"    if op == OP_{op} {{")
            out.append(f"        return {caches[val]};")
            out.append("    }")
    out.append("    return 0;")
    out.append("}")
    out.append("")

    out.append("# Deoptimization target opcode (_PyOpcode_Deopt).")
    out.append("def opcode_deopt_target(op: int) -> int {")
    out.append(f"    if op < 0 or op > {MAX_REAL_OPCODE} {{")
    out.append("        return op;")
    out.append("    }")
    for idx in range(MAX_REAL_OPCODE + 1):
        val = deopt[idx]
        if val != idx:
            out.append(f"    if op == OP_{val_to_op_name(opmap, idx)} {{")
            out.append(f"        return {val};")
            out.append("    }")
    out.append("    return op;")
    out.append("}")
    out.append("")

    emit_switch_fn("_opcode_num_popped", popped, opmap, out)
    emit_switch_fn("_opcode_num_pushed", pushed, opmap, out)

    out.append(
        "# Net stack effect (flowgraph.c get_stack_effects). jump: 0=fallthrough,"
    )
    out.append("# 1=taken target, -1=maximal (unused on the CFG path).")
    out.append("def stack_effect(op: int, oparg: int, jump: int) -> int | None {")
    out.append("    if op < 0 {")
    out.append("        return None;")
    out.append("    }")
    out.append("    if op <= MAX_REAL_OPCODE {")
    out.append("        deopt = opcode_deopt_target(op);")
    out.append("        if deopt != op {")
    out.append("            return None;")
    out.append("        }")
    out.append("    }")
    out.append("    popped = _opcode_num_popped(op, oparg);")
    out.append("    pushed = _opcode_num_pushed(op, oparg);")
    out.append("    if popped < 0 or pushed < 0 {")
    out.append("        return None;")
    out.append("    }")
    out.append("    if is_block_push_opcode(op) and jump == 0 {")
    out.append("        return 0;")
    out.append("    }")
    out.append("    return pushed - popped;")
    out.append("}")
    out.append("")

    emit_classifier("is_block_push_opcode", BLOCK_PUSH_OPS, out)
    emit_has_target(jump_ops, out)
    emit_classifier("is_unconditional_jump_opcode", UNCONDITIONAL_JUMP_OPS, out)
    emit_classifier("is_scope_exit_opcode", SCOPE_EXIT_OPS, out)
    emit_classifier("is_assembler_opcode", ASSEMBLER_OPS, out)

    # Per-opcode metadata predicates (pycore_opcode_metadata.h OPCODE_HAS_*).
    emit_flag_classifier("opcode_is_valid", None, meta_entries, opmap, out)
    for fn_name, flag in _METADATA_FLAG_CLASSIFIERS:
        emit_flag_classifier(fn_name, flag, meta_entries, opmap, out)

    out.append("# Instruction width in code units: opcode+arg (2) plus cache padding.")
    out.append("def instruction_width(op: int) -> int {")
    out.append("    return 2 + opcode_cache_count(op);")
    out.append("}")
    out.append("")

    out.append("# Advance ip past one instruction (including EXTENDED_ARG prefix chain).")
    out.append("def next_instruction_ip(code: list[int], ip: int) -> int {")
    out.append("    ext = 0;")
    out.append("    while ip < len(code) {")
    out.append("        op = code[ip];")
    out.append("        arg = code[ip + 1];")
    out.append("        arg = arg | (ext << 8);")
    out.append("        ext = 0;")
    out.append("        if op == OP_EXTENDED_ARG {")
    out.append("            ext = arg;")
    out.append("            ip = ip + 2;")
    out.append("            continue;")
    out.append("        }")
    out.append("        return ip + instruction_width(op);")
    out.append("    }")
    out.append("    return ip;")
    out.append("}")
    out.append("")

    return "\n".join(out).rstrip() + "\n"


def main(argv: list[str]) -> int:
    text = generate()
    if "--stdout" in argv:
        sys.stdout.write(text)
        return 0
    if "--check" in argv:
        try:
            with open(OUT_PATH) as fh:
                on_disk = fh.read()
        except FileNotFoundError:
            print(f"{OUT_PATH} missing; run opcode_meta2jac.py to generate it", file=sys.stderr)
            return 1
        if on_disk != text:
            print(f"{OUT_PATH} is stale; regenerate with opcode_meta2jac.py", file=sys.stderr)
            return 1
        print(f"{OUT_PATH} up to date")
        return 0
    with open(OUT_PATH, "w") as fh:
        fh.write(text)
    print(f"wrote {OUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
