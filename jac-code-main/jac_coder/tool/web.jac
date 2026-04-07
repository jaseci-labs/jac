import re;

import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }


"""Fetch a URL as readable text."""
def web_fetch(url: str, format: str = "text") -> str;

"""Search the web."""
def web_search(query: str, num_results: int = 5) -> str;
