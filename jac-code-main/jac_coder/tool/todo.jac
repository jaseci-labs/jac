import json;

import from jac_coder.util.tool_output { tool_status, tool_end }

glob _todos: dict = {};


"""Create or update a todo list."""
def update_todos(todos_json: str) -> str;

"""Get current todos."""
def get_todos(session_id: str = "default") -> list;
