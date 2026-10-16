"""The entry module for the relative stdlib-named import region test.

The decorated entry calls a helper imported from the SIBLING module json.jac
through a relative import. The sibling shares its name with a stdlib module, so
a deny list that ignores the import's relative level drops the call edge and
the helper never joins the compiled region."""
import torch;
import from .json { near_helper }

@torch.compile()
def `entry(x: any) -> any {
    return torch.sin(near_helper(x));
}
