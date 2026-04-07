import os;

import from pathlib { Path }
import from jac_coder.events { emit_event }
import from jac_coder.util.sandbox { sandbox_path }
import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }
import from jac_coder.tool.guarded { _check_permission }


"""Scaffold a new Jac project."""
def scaffold_project(project_type: str, name: str, directory: str) -> str;
