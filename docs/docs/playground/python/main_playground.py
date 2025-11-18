import io
import os
import re
import json
import contextlib
import tempfile

# If these variables are not set by the pyodide this will raise an exception.
SAFE_CODE = globals()["SAFE_CODE"]
CB_STDOUT = globals()["CB_STDOUT"]
CB_STDERR = globals()["CB_STDERR"]
debugger = globals()["debugger"]


def fix_duplicate_graph_json(graph_json_str):
    graph_json_str = graph_json_str.strip()
    if not graph_json_str:
        graph_json_str = '{"nodes": [], "edges": []}'

    try:
        graph = json.loads(graph_json_str)
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}")
        print(f"Problematic JSON string: {repr(graph_json_str)}")
        graph = {"nodes": [], "edges": []}

    # Deduplicate nodes by 'id'
    seen_node_ids = set()
    unique_nodes = []
    for node in graph.get("nodes", []):
        if node["id"] not in seen_node_ids:
            seen_node_ids.add(node["id"])
            unique_nodes.append(node)
    graph["nodes"] = unique_nodes

    # Deduplicate edges by (from, to) tuple
    seen_edges = set()
    unique_edges = []
    for edge in graph.get("edges", []):
        edge_key = (edge["from"], edge["to"])
        if edge_key not in seen_edges:
            seen_edges.add(edge_key)
            unique_edges.append(edge)
    graph["edges"] = unique_edges
    return json.dumps(graph)


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


# Import our custom exception for better error handling
try:
    exec("from debugger import DebuggerTerminated", globals())
except Exception:

    class DebuggerTerminated(Exception):
        pass


with contextlib.redirect_stdout(
    stdout_buf := JsIO(CB_STDOUT)
), contextlib.redirect_stderr(JsIO(CB_STDERR)):

    try:
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".jac", delete=False
        ) as temp_jac:
            temp_jac.write(SAFE_CODE)
            temp_jac_path = temp_jac.name

        code = "from jaclang.cli.cli import run\n" f"run('{temp_jac_path}')\n"
        debugger.set_code(code=code, filepath=temp_jac_path)
        debugger.do_run()
        # Grab the graph output from the debugger
        full_output = stdout_buf.getvalue()
        matches = re.findall(
            r"<==START PRINT GRAPH==>(.*?)<==END PRINT GRAPH==>",
            full_output,
            re.DOTALL,
        )
        if matches:
            graph_json = matches[-1].strip()
            if not graph_json:
                graph_json = '{"nodes": [], "edges": []}'
        else:
            graph_json = '{"nodes": [], "edges": []}'
        debugger.cb_graph(graph_json)

    except DebuggerTerminated:
        print("Debug session ended by user.")
    except SystemExit:
        print("Execution stopped by user.")
    except Exception as e:
        if "terminated" in str(e).lower():
            print("Execution terminated by user.")
        elif "not a directory" in str(e).lower() or "no such file" in str(e).lower():
            print("Debug session ended.")
        else:
            import traceback

            traceback.print_exc()
    finally:
        try:
            os.unlink(temp_jac_path)
        except Exception:
            pass
