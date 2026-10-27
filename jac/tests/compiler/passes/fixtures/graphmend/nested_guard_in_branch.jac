"""Compound graph break: a data-dependent branch (predicated to torch.where)
that ALSO contains a tensor-bool validation guard (`if not ...: raise`).

This requires two transformations to compose. TrapLoweringPass must run before
PredicateCtrlFlowPass so the guard is first lowered to a graph-native
a direct `torch._assert_async` (removing the `raise`); predication can then hoist the
branch setups and merge the shared trailing call. The hoisted assert is re-gated
onto the branch predicate (`torch.logical_or(torch.logical_not(cond), check)`),
legal because the lowered check is a proven tensor,
so it still only fires when the branch is taken -- preserving semantics."""
import torch;

@torch.compile()
def f(x: torch.Tensor, y: torch.Tensor) -> any {
    out = torch.zeros_like(x);
    if (x.sum() > 0) {
        if not (x == y).all() {  # jac:ignore[E1030]
            raise ValueError("x and y must match");
        }
        a = x * 2;
        out.copy_(a);
    } else {
        b = x * 3;
        out.copy_(b);
    }
    return out;
}
