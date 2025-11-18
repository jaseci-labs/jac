import io
import tempfile
import os
import contextlib

# If these variables are not set by the pyodide this will raise an exception.
CONVERSION_TYPE = globals()["CONVERSION_TYPE"]  # "jac2py" or "py2jac"
INPUT_CODE = globals()["INPUT_CODE"]
CB_STDOUT = globals()["CB_STDOUT"]
CB_STDERR = globals()["CB_STDERR"]
CB_RESULT = globals()["CB_RESULT"]


# Redirect stdout and stderr to javascript callback.
class JsIO(io.StringIO):
    def __init__(self, callback, *args, **kwargs):
        self.callback = callback
        super().__init__(*args, **kwargs)

    def write(self, s: str, /) -> int:
        self.callback(s)
        super().write(s)
        return 0

    def writelines(self, lines, /) -> None:
        for line in lines:
            self.callback(line)
        super().writelines(lines)


with contextlib.redirect_stdout(
    stdout_buf := JsIO(CB_STDOUT)
), contextlib.redirect_stderr(JsIO(CB_STDERR)):

    try:
        if CONVERSION_TYPE == "jac2py":
            # Create temporary file for Jac code
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".jac", delete=False
            ) as temp_jac:
                temp_jac.write(INPUT_CODE)
                temp_jac_path = temp_jac.name

            try:
                # Call jac2py with just the input file path (like run function)
                code = (
                    "from jaclang.cli.cli import jac2py\n"
                    f"jac2py('{temp_jac_path}')\n"
                )

                exec(code)
                result = stdout_buf.getvalue()
                CB_RESULT(result if result else "# No output from jac2py conversion")

            finally:
                try:
                    os.unlink(temp_jac_path)
                except Exception:
                    pass

        elif CONVERSION_TYPE == "py2jac":
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".py", delete=False
            ) as temp_py:
                temp_py.write(INPUT_CODE)
                temp_py_path = temp_py.name

            try:
                # Call py2jac with just the input file path (like run function)
                code = (
                    "from jaclang.cli.cli import py2jac\n" f"py2jac('{temp_py_path}')\n"
                )

                exec(code)
                result = stdout_buf.getvalue()
                CB_RESULT(result if result else "# No output from py2jac conversion")

            finally:
                try:
                    os.unlink(temp_py_path)
                except Exception:
                    pass
        else:
            CB_RESULT(f"# Unknown conversion type: {CONVERSION_TYPE}")

    except Exception as e:
        error_msg = f"Conversion Error: {str(e)}"
        print(error_msg)
        CB_RESULT(f"# Error during conversion:\n# {error_msg}")
        import traceback

        traceback.print_exc()
