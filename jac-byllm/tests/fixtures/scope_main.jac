"""Main entry point that imports process_data from both module_alpha and module_beta.

This tests that same-named functions in different modules resolve correctly
when imported into a single entry point.
"""

import from scope_dir.module_alpha { process_data as alpha_process }
import from scope_dir.module_beta { process_data as beta_process }

with entry {
    alpha_result = alpha_process();
    beta_result = beta_process();

    print(f"Alpha result: {alpha_result}");
    print(f"Beta result: {beta_result}");
}
