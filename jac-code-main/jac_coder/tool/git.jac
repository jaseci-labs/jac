import os;
import subprocess;

import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }
import from jac_coder.util.sandbox { sandbox_path }


"""Show working tree status."""
def git_status() -> str;

"""Show diff of changes."""
def git_diff(ref: str = "HEAD") -> str;

"""Stage files and create a commit."""
def git_commit(message: str, files: list[str] = []) -> str;

"""Show recent commit history."""
def git_log(count: int = 10) -> str;
