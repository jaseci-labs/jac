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
     },
     SCALAR_TORCH_ATTRS: set[str] = {'item', 'tolist', 'equal', 'allclose'},
     LOGGING_PATTERNS: list[str] = ['logger', 'logging', 'warn', 'critical'],
     SIDE_EFFECT_CALLS: set[str] = {'print'},
     AUTOGRAD_SIGNAL_ATTRS: set[str] = {
         'autograd',
         'backward',
         'enable_grad',
         'grad',
         'requires_grad',
         'requires_grad_',
         'set_grad_enabled',
         'train',
         'training',
         'zero_grad'
     },
     AUTOGRAD_MODULE_PATHS: list[str] = ['torch.autograd', 'torch.optim'],
     AUTOGRAD_ITEM_NAMES: set[str] = {'autograd', 'optim'},
     OPTIM_RECEIVER_PATTERNS: list[str] = ['optim', 'sched'],
     GRAD_OFF_CTX_ATTRS: set[str] = {'no_grad', 'inference_mode'};

def symbol_is_builtin(sym: uni.Symbol) -> bool;

def cond_is_data_dependent(cond: uni.Expr) -> bool;

def cond_materializes_scalar(cond: uni.Expr) -> bool;

def cond_traces_attr(cond: uni.Expr, attrs: set[str], on_exhaust: bool) -> bool;

def expr_uses_attr(expr: uni.UniNode, attrs: set[str]) -> bool;

def trace_symbol_attr(
    sym: uni.Symbol, attrs: set[str], visited: set[str], depth: int, on_exhaust: bool
) -> bool;

def defining_assignment(sym: uni.Symbol) -> (uni.Assignment | None);

def is_side_effect_name(name: str) -> bool;

def is_torch_attr_target(target: (uni.Expr | None), attr: str) -> bool;

def decorator_base(dec: uni.Expr) -> uni.Expr;

def has_torch_compile_decorator(nd: uni.UniNode) -> bool;
