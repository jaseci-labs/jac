import os;
import signal;
import subprocess;

import from jac_coder.util.sandbox { sandbox_path, get_sandbox_root }
import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }


"""Execute a shell command."""
def bash_exec(
    command: str, workdir: str = ".", timeout: int = 120, background: bool = False
) -> str;
