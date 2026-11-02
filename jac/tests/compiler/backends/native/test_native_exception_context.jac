"""The exception-context lookup touches its single-thread global only while single-threaded.

`__jac_exception_context` keeps the one thread's context in a process-wide
global until the program starts a thread (`__jac_rc_threaded`), and reads the
thread-local slot after that. The global is a plain load and store, so a path
that reaches it with the flag set races between threads; and while the flag
is clear, the lookup has to publish a context the thread-local slot already
holds (a library's initializers create it with the flag set, before
`jac_main` clears it), or the global stays empty and every lookup takes the
slow path. These tests walk the blocks of the lookup and of its out-of-line
slow path with the flag and the slot's state fixed.
"""

import re;
import from tests.support { compile_native_ir }

glob FIXTURE: str = "na_exception_context.jac",
     MAIN_CTX: str = '@"__jac_exception_main_ctx"',
     FUNCS: dict[str, str] = {
         "context": "__jac_exception_context",
         "slow": "__jac_exception_context_slow"
     };

"""The blocks of the lookup and its slow path in the fixture's IR:
"fn:label" -> lines."""
def lookup_blocks -> dict[str, list[str]] {
    text = str(compile_native_ir(FIXTURE).gen.llvm_ir);
    blocks: dict[str, list[str]] = {};
    for (fn, name) in FUNCS.items() {
        found = re.search(
            r'define [^\n]*@"' + name + r'"\(\)[^\n]*\n\{\n(.*?)\n}\n', text, re.S
        );
        if found is None {
            continue;
        }
        label = "";
        for line in found.group(1).splitlines() {
            head = re.`match(r'^"?([\w.]+)"?:$', line);
            if head is not None {
                label = f"{fn}:{head.group(1)}";
                blocks[label] = [];
            } elif label {
                blocks[label].append(line);
            }
        }
    }
    assert "context:entry" in blocks , "__jac_exception_context not found in the IR";
    return blocks;
}

"""The value of each branch condition that tests the thread flag or the
thread-local slot, when the flag is `threaded` and the slot is `slot_empty`."""
def conditions(
    blocks: dict[str, list[str]], threaded: bool, slot_empty: bool
) -> dict[str, bool] {
    known: dict[str, bool] = {};
    for fn in FUNCS {
        body = "\n".join(
            line
            for (label, lines) in blocks.items()
            if label.startswith(fn + ":") for line in lines
        );
        flags = re.findall(
            r'%"?([\w.]+)"? = load atomic i8, i8\* @"__jac_rc_threaded"', body
        );
        slots = re.findall(
            r'%"?([\w.]+)"? = call i64 @"__jac_exception_tls_get"\(\)', body
        );
        for (dst, op, src) in re.findall(
            r'%"?([\w.]+)"? = icmp (eq|ne) i(?:8|64) %"?([\w.]+)"?, 0', body
        ) {
            if src in flags {
                known[f"{fn}:{dst}"] = threaded if op == "ne" else not threaded;
            } elif src in slots {
                known[f"{fn}:{dst}"] = slot_empty if op == "eq" else not slot_empty;
            }
        }
    }
    assert known , "the lookup tests neither the thread flag nor the slot";
    return known;
}

"""The blocks reachable from the lookup's entry, a branch on a known condition
taking its one side and a call of the slow path entering it."""
def reachable(blocks: dict[str, list[str]], known: dict[str, bool]) -> list[str] {
    seen: list[str] = [];
    todo = ["context:entry"];
    while todo {
        at = todo.pop();
        if at in seen {
            continue;
        }
        seen.append(at);
        fn = at.split(":")[0];
        if any(f'@"{FUNCS["slow"]}"(' in line for line in blocks[at]) {
            todo.append("slow:entry");
        }
        last = blocks[at][-1];
        cond = re.`match(
            r'\s*br i1 %"?([\w.]+)"?, label %"?([\w.]+)"?, label %"?([\w.]+)"?', last
        );
        jump = re.`match(r'\s*br label %"?([\w.]+)"?', last);
        if cond is not None {
            (c, yes, no) = cond.groups();
            key = f"{fn}:{c}";
            if key in known {
                todo.append(f"{fn}:{yes if known[key] else no}");
            } else {
                todo.extend([f"{fn}:{yes}", f"{fn}:{no}"]);
            }
        } elif jump is not None {
            todo.append(f"{fn}:{jump.group(1)}");
        }
    }
    return seen;
}

"""The reachable lines that mention the single-thread global."""
def main_ctx_uses(blocks: dict[str, list[str]], labels: list[str]) -> list[str] {
    return [
        line for label in labels
        for line in blocks[label]
        if MAIN_CTX in line
    ];
}

test "with a thread started, the lookup reads the thread-local slot and never the global" {
    blocks = lookup_blocks();
    for slot_empty in [True, False] {
        labels = reachable(blocks, conditions(blocks, True, slot_empty));
        uses = main_ctx_uses(blocks, labels);
        assert not uses , f"threaded path (slot empty: {slot_empty}) touches the global:\n"
            + "\n".join(uses);
        assert any(
            "__jac_exception_tls_get" in line for label in labels
            for line in blocks[label]
        ) , "threaded path does not read the thread-local slot";
    }
}

test "while single-threaded, the context the thread-local slot holds or gets is published" {
    blocks = lookup_blocks();
    # the slot already holding a context is `jac_main`'s case: a library's
    # initializers ran with the flag set and created it
    for slot_empty in [True, False] {
        labels = reachable(blocks, conditions(blocks, False, slot_empty));
        assert any(
            re.`match(r'\s*store .*' + re.escape(MAIN_CTX) + r'\s*$', line)
            for line in main_ctx_uses(blocks, labels)
        ) , f"single-threaded lookup (slot empty: {slot_empty}) never publishes its context";
    }
}
