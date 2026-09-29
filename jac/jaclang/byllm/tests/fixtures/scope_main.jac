"""Imports the same-named `process_data` from module_alpha and from module_beta."""

import from scope_dir.module_alpha { process_data as alpha_process }
import from scope_dir.module_beta { process_data as beta_process }
