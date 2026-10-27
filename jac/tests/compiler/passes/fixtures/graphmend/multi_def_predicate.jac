"""A predicate name with more than one definition: the use-def trace cannot
prove which one reaches the branch, so both queries answer with their safe
exhaustion value and nothing is tagged or rewritten."""
import torch;

@torch.compile()
def f(x: any) -> any {
    flag = x.item() > 5;
    flag = x.sum() > 0;
    if flag {
        y = x * 2;
    } else {
        y = x * 3;
    }
    return y;
}
