import os;
import tempfile;
import subprocess;

import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }


"""Spawn a sub-agent for a task."""
def spawn_task(description: str, prompt: str, agent_type: str = "explore") -> str;
