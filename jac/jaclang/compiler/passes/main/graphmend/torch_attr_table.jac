import jaclang.jac0core.unitree as uni;

glob DYNAMIC_TORCH_ATTRS: set[str] = {
         'item',
         'tolist',
         'sum',
         'max',
         'min',
         'mean',
         'prod',
         'argmax',
         'argmin',
         'nonzero',
         'count_nonzero',
         'all',
         'any',
         'equal',
         'allclose',
         'unique'
     };

def is_dynamic_torch_attr(attr: str) -> bool {
    return attr in DYNAMIC_TORCH_ATTRS;
}

def is_torch_attr_target(target: (uni.Expr | None), attr: str) -> bool {
    return (
        isinstance(target, uni.AtomTrailer)
        and isinstance(target.right, uni.Name)
        and (target.right.value == attr)
        and isinstance(target.target, uni.Name)
        and (target.target.value == 'torch')
    );
}

def has_torch_compile_decorator(nd: uni.UniNode) -> bool {
    for dec in (nd?.decorators or []) {
        target = dec.target if isinstance(dec, uni.FuncCall) else dec;
        if is_torch_attr_target(target, 'compile') {
            return True;
        }
    }
    return False;
}
