#!/usr/bin/env python3
"""Dump exact PyCode fields for the P0.10/P4 expression fixtures.

Test/shim only (PLAN.md P0.2/P0.10, P4a contract freeze). Prints co_code
units, consts, names, flags, stacksize, linetable bytes, exceptiontable
bytes (plus the DECODED exception-table entries), the per-instruction
cache-padding map, and the merged localsplus layout for each fixture so
the Jac compiler has byte-exact ground truth for every clause of the
frozen PyCode front<->back contract (jac-py/jacpython/codeobject.jac,
clauses C1-C5; enforced by pycode_diff.jac pycode_contract_check).
"""
import dis
import marshal

FIXTURES = [
    ("add", "1+1", "eval"),
    ("neg", "-x", "eval"),
    ("add_mul", "a*b+c", "eval"),
    ("call", "f(x,1)", "eval"),
    ("chain_cmp", "x<y<z", "eval"),
    ("add_exec", "1+1\n", "exec"),
    ("assign_exec", "a = 1 + 2\n", "exec"),
]

# Contract-relevant extras: closures exercise C4 (merged localsplus /
# cell-kind slots via LOAD_FAST_BORROW), try/except exercises C3.
EXTRA_FIXTURES = [
    ("closure", "def outer(a):\n    x = a + 1\n    def inner():\n        return x\n"
                "    return inner\n", "exec"),
    ("try_except", "try:\n    g(0)\nexcept Exception as e:\n    err = e\n", "exec"),
]


def read_varint7(data, pos):
    """CPython assemble.c varint7: 6 payload bits/byte, bit 6 = continuation."""
    val = 0
    shift = 0
    while True:
        b = data[pos]
        pos += 1
        val |= (b & 0x3F) << shift
        shift += 6
        if not (b & 0x40):
            return val, pos


def decode_exception_table(et):
    """Decode co_exceptiontable into its logical 5-tuples (contract C3).

    Returns [(start, size, target, depth, lasti)] with offsets in code
    units -- exactly what verify_exception_table in pycode_diff.jac must
    accept and nothing else.
    """
    entries = []
    pos = 0
    while pos < len(et):
        assert et[pos] & 0x80, f"missing start-marker bit at byte {pos}"
        start, pos = read_varint7(et, pos)
        size, pos = read_varint7(et, pos)
        target, pos = read_varint7(et, pos)
        depth_lasti, pos = read_varint7(et, pos)
        entries.append(
            (start, size, target, depth_lasti >> 1, bool(depth_lasti & 1))
        )
    return entries


def cache_map(co):
    """Per-instruction (offset, opname, ncaches) walk with the frozen C1.3
    byte width 2*(1+opcode_cache_count) -- mirrors instruction_byte_width
    in pycode_diff.jac."""
    code = co.co_code
    rows = []
    ip = 0
    ext = 0
    while ip < len(code):
        op = code[ip]
        arg = code[ip + 1] | (ext << 8)
        ext = 0
        if op == dis.opmap["EXTENDED_ARG"]:
            ext = arg
            rows.append((ip, "EXTENDED_ARG", 0, arg))
            ip += 2
            continue
        caches = dis._inline_cache_entries.get(dis.opname[op], 0)
        name = dis.opname[op]
        rows.append((ip, name, caches, arg))
        ip += 2 * (1 + caches)
    return rows


def dump(name, src, mode):
    print("=" * 70)
    print(f"FIXTURE {name}  mode={mode}  src={src!r}")
    print("=" * 70)
    co = compile(src, "<f>", mode)
    code = co.co_code
    # co_code is bytes; each instruction is 2 bytes (op, arg). Print as units.
    print(f"co_code len (bytes) = {len(code)}  (= {len(code)//2} code units)")
    print("co_code units (op,arg) pairs:")
    i = 0
    while i < len(code):
        op = code[i]
        arg = code[i + 1]
        print(f"  [{i//2:3d}] byte_off={i:4d} op={op:3d} arg={arg:3d}")
        i += 2
    print(f"argcount={co.co_argcount} posonly={co.co_posonlyargcount} "
          f"kwonly={co.co_kwonlyargcount}")
    print(f"stacksize={co.co_stacksize} flags={co.co_flags} "
          f"firstlineno={co.co_firstlineno}")
    print(f"filename={co.co_filename!r} name={co.co_name!r} "
          f"qualname={co.co_qualname!r}")
    print(f"consts={list(co.co_consts)!r}")
    print(f"names={list(co.co_names)!r}")
    print(f"varnames={list(co.co_varnames)!r}")
    print(f"cellvars={list(co.co_cellvars)!r}")
    print(f"freevars={list(co.co_freevars)!r}")
    print(f"linetable bytes = {list(co.co_linetable)!r}")
    print(f"exceptiontable bytes = {list(co.co_exceptiontable)!r}")
    # --- frozen-contract ground truth (codeobject.jac C1-C5) ---
    print("exceptiontable decoded (start,size,target,depth,lasti) code units:")
    for e in decode_exception_table(list(co.co_exceptiontable)):
        print(f"  {e}")
    print("instruction map (byte_off, op, ncaches, effective_arg):")
    for off, nm, caches, arg in cache_map(co):
        print(f"  [{off:4d}] {nm:<20s} +{caches} caches  arg={arg}")
    merged = list(co.co_varnames) + list(co.co_cellvars) + list(co.co_freevars)
    print("merged localsplus [varnames|cellvars|freevars]:")
    for idx, nm in enumerate(merged):
        kind = (
            "local"
            if idx < len(co.co_varnames)
            else (
                "cell"
                if idx < len(co.co_varnames) + len(co.co_cellvars)
                else "free"
            )
        )
        print(f"  [{idx}] {nm} ({kind})")
    print("--- dis ---")
    dis.dis(co)
    print()


def main():
    for name, src, mode in FIXTURES + EXTRA_FIXTURES:
        dump(name, src, mode)


if __name__ == "__main__":
    main()
