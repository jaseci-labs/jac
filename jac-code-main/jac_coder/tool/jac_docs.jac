import os;
import re;

import from jac_coder.config { get_data_dir }
import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }


"""Search Jac documentation by keyword."""
def jac_docs(query: str, max_results: int = 3) -> str;
