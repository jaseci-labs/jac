import subprocess;

import from jac_coder.util.sandbox { sandbox_path }
import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }


"""Type-check a .jac file."""
def jac_check(file: str) -> str;

"""Run a Jac file."""
def jac_run(file: str, args: str = "") -> str;
