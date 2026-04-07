import os;
import re;
import time;
import subprocess;
import mimetypes;

import from pathlib { Path }
import from jac_coder.events { emit_event }
import from jac_coder.util.sandbox { sandbox_path }
import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }


"""Read a file with line numbers."""
def read_file(file_path: str, offset: int = 0, limit: int = 2000) -> str;

"""Write content to a file."""
def write_file(file_path: str, content: str) -> str;

"""Find-and-replace in a file."""
def edit_file(
    file_path: str, old_string: str, new_string: str, replace_all: bool = False
) -> str;

"""List files matching a glob pattern."""
def list_files(directory: str = ".", pattern: str = "**/*") -> str;
