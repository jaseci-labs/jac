"""Executable counterpart of the ownership paper's erasure function.

Usage: jac run harness/erase.jac kernels/binarytrees.jac > bare.jac

Deletes every ownership annotation from a kernel source:
  x: own T = ...   ->  x: T = ...
  p: &T / p: &mut T (params and locals)  ->  p: T
  f(&x, &mut y)    ->  f(x, y)

The kernels are authored in a constrained style (annotations only in the
shapes above, no bitwise &) so the transform is exact for them; it is NOT a
general-purpose Jac rewriter. Validation: the erased source must compile
without enforcement under --gc rc/cycles and produce a digest identical to
the annotated build (checked by ci_identity.sh and the ownbench
differential test suite).

Partial erasure (the annotation-lattice sweep) is intentionally not
implemented yet: ownership sites are not independent the way
gradual-typing sites are. A borrow at a call site is only well-formed if
the callee parameter keeps its annotation, so lattice points must be
closed under the borrow-coupling relation between callers and callees.
"""

import re;
import sys;
import from pathlib { Path }

"""Delete every ownership annotation from kernel source text."""
def erase(text: str) -> str {
    text = re.sub(r":\s*own\s+", ": ", text);
    text = re.sub(r":\s*&mut\s+", ": ", text);
    text = re.sub(r":\s*&", ": ", text);
    text = re.sub(r"([(,]\s*)&mut\s+", r"\1", text);
    text = re.sub(r"([(,]\s*)&(?=[A-Za-z_])", r"\1", text);
    return text;
}

with entry {
    if len(sys.argv) != 2 {
        sys.stderr.write("usage: jac run erase.jac <kernel.jac>\n");
        sys.exit(2);
    }
    sys.stdout.write(erase(Path(sys.argv[1]).read_text()));
}
