"""Issue #6669 fixture (entry half): a thin entry that uses NO Object-Spatial
construct itself -- it only delegates to an imported module whose `run_it` does
the `spawn`. Compiled via `jac nacompile`, the binary must link the OSP kernel
(pulled in transitively through the import) and print `7`."""

import from osp_kernel_transitive_lib { run_it }

with entry {
    print(run_it());
}
