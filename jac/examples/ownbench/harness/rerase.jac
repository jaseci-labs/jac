"""Region eraser: produce the managed baseline of a region kernel.

Usage: jac run harness/rerase.jac kernels/rgraph.na.jac > bare.na.jac

Deletes region annotations so the same workload runs entirely on the
managed heap -- the mechanical open/close-lines-only diff the regions
evaluation calls for:
  <name>: own Region = Region();   ->  (line removed)
  in <name> { BODY }               ->  BODY (dedented one level)
  in Region() { BODY }             ->  BODY (dedented one level)

Kernel style constraints (load-bearing): the handle declaration sits on
its own line; `in ... {` opens sit on their own line with the block's
closing `}` alone on a line at the same indent; open bodies are indented
exactly four spaces. The transform is exact for kernels written in this
style; it is not a general Jac rewriter.

Note the semantics of the erased program on the native backend: managed
nodes and edges are pinned immortal by the runtime (reachability
liveness for graphs is future work), so the bare variant reports zero
node drops and monotonically growing RSS. That asymmetry is a measured
finding, not an erasure bug; output identity is checked on the digest
lines only.
"""

import re;
import sys;
import from pathlib { Path }

"""Delete region annotations from kernel source text."""
def rerase(text: str) -> str {
    out: list[str] = [];
    stack: list[int] = [];
    for line in text.splitlines() {
        stripped = line.strip();
        if re.fullmatch(r"\w+\s*:\s*own\s+Region\s*=\s*Region\(\)\s*;", stripped) {
            continue;
        }
        if re.fullmatch(r"in\s+(\w+|Region\(\))\s*\{", stripped) {
            stack.append(len(line) - len(line.lstrip()));
            continue;
        }
        if stack
        and stripped == "}"
        and (len(line) - len(line.lstrip())) == stack[-1] {
            stack.pop();
            continue;
        }
        if stack and line.startswith("    " * len(stack)) {
            out.append(line[4 * len(stack):]);
        } else {
            out.append(line);
        }
    }
    return "\n".join(out) + "\n";
}

with entry {
    if len(sys.argv) != 2 {
        sys.stderr.write("usage: jac run rerase.jac <kernel.na.jac>\n");
        sys.exit(2);
    }
    sys.stdout.write(rerase(Path(sys.argv[1]).read_text()));
}
