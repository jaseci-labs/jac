import io
import contextlib
import os

# If these variables are not set by the pyodide this will raise an exception.
PYTHON_CODE = globals()["PYTHON_CODE"]
CB_STDOUT = globals()["CB_STDOUT"]
CB_STDERR = globals()["CB_STDERR"]


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


temp_py_path = "/tmp/temp_python_code.py"

with open(temp_py_path, "w") as f:
    f.write(PYTHON_CODE)

with contextlib.redirect_stdout(
    stdout_buf := JsIO(CB_STDOUT)
), contextlib.redirect_stderr(JsIO(CB_STDERR)):

    try:
        exec(PYTHON_CODE, globals())

    except SystemExit:
        print("Python execution stopped.")
    except Exception:
        import traceback

        traceback.print_exc()
    finally:
        # Clean up temporary file
        try:
            if os.path.exists(temp_py_path):
                os.unlink(temp_py_path)
        except Exception:
            pass
