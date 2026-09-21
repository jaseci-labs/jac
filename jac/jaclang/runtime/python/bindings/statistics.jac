"""Python statistics accelerator signature and initialization."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition
}
import from jaclang.runtime.python.bindings.arguments {
    CallSignature,
    BoundArguments,
    invoke
}
import from jaclang.runtime.python.modules.statistics { jacpy_statistics_inv_cdf }

# Upstream declares the three parameters positional-only, so the whole name
# list is positional-only and a keyword is rejected rather than matched.
glob:priv inv_cdf_signature = CallSignature(
         "_normal_dist_inv_cdf", ["p", "mu", "sigma"], 3, 3, 3
     );

def:priv inv_cdf_bound(args: BoundArguments) -> u64 {
    return jacpy_statistics_inv_cdf(args.values[0], args.values[1], args.values[2]);
}

def:priv inv_cdf_call(module: u64, args: u64) -> u64 {
    return invoke(inv_cdf_signature, args, 0, inv_cdf_bound);
}

glob:priv definition = ModuleDefinition(
         "_statistics",
         "Accelerators for the statistics module.\n",
         [
             MethodDefinition(
                 "_normal_dist_inv_cdf",
                 MethodCallbacks(positional=inv_cdf_call),
                 "_normal_dist_inv_cdf($module, p, mu, sigma, /)\n--\n\n",
                 1
             )
         ]
     );

def:pub PyInit__statistics -> u64 {
    return definition.initialize();
}
