import subprocess;

import from pathlib { Path }
import from jac_coder.util.sandbox { sandbox_path }
import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }


"""Regex search across files."""
def grep_search(
    pattern: str, path: str = ".", file_pattern: str = "", max_results: int = 50
) -> str;

"""Find files by glob pattern."""
def find_files(pattern: str, directory: str = ".") -> str;
