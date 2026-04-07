import from jac_coder.tool.guarded { write_file_guarded, edit_file_guarded }
import from jac_coder.events { check_tool_loop }


"""Write a file with auto-validation."""
def write_code(file_path: str, content: str) -> str;

"""Find-and-replace with auto-validation."""
def edit_code(
    file_path: str, old_string: str, new_string: str, replace_all: bool = False
) -> str;
