import bdb
import json
from types import FrameType
from typing import Callable


class DebuggerTerminated(Exception):
    """Custom exception for clean debugger termination"""


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


class Debugger(bdb.Bdb):

    def __init__(self) -> None:
        super().__init__()
        self.filepath: str = ""
        self.code: str = ""
        self.curframe: FrameType | None = None
        self.breakpoint_buff: list[int] = []
        self._terminated = False  # Add termination flag
        self.total_lines = 0

        self.cb_break: Callable[[Debugger, int], None] = lambda dbg, lineno: None
        self.cb_graph: Callable[[str], None] = lambda graph: None

    def set_code(self, code: str, filepath: str) -> None:
        self.filepath = filepath

        with open(filepath, "r") as f:
            source = f.read()
            self.total_lines = len(source.splitlines())
        self.code = code
        self.curframe = None
        self.clear_breakpoints()

    def user_line(self, frame):
        """Called when we stop or break at a line."""
        # Check if terminated
        if self._terminated:
            # Raise exception to break out of execution cleanly
            raise DebuggerTerminated("Execution terminated by user")

        if self.curframe is None:
            self.curframe = frame
            self.set_continue()
        elif frame.f_code.co_filename == self.filepath:
            lineno = frame.f_lineno
            if lineno >= (self.total_lines - 5):
                self.set_continue()
                return
            self._send_graph()
            self.curframe = frame
            self.cb_break(self, lineno)
        else:
            self.do_step_into()  # Just step till we reach the file again.

    def user_call(self, frame, args):
        """Called when entering a function."""
        if self._terminated:
            raise DebuggerTerminated("Execution terminated by user")
        super().user_call(frame, args)

    def user_return(self, frame, retval):
        """Called when returning from a function."""
        if self._terminated:
            raise DebuggerTerminated("Execution terminated by user")
        super().user_return(frame, retval)

    def user_exception(self, frame, exc_stuff):
        """Called when an exception occurs."""
        if self._terminated:
            raise DebuggerTerminated("Execution terminated by user")
        super().user_exception(frame, exc_stuff)

    def _send_graph(self) -> None:
        try:
            graph_str = self.runeval("printgraph(format='json')")  # type: ignore[func-returns-value]  # typeshed#15049
            self.cb_graph(graph_str)
        except Exception as e:
            print(f"[Debugger] Error sending graph: {e}")
        self.set_trace()

    # -------------------------------------------------------------------------
    # Public API.
    # -------------------------------------------------------------------------

    def set_breakpoint(self, lineno: int) -> None:
        if not self.filepath:
            self.breakpoint_buff.append(lineno)
        else:
            self.set_break(self.filepath, lineno)

    def clear_breakpoints(self) -> None:
        self.clear_all_breaks()

    def do_run(self) -> None:
        for lineno in self.breakpoint_buff:
            self.set_break(self.filepath, lineno)
        self.breakpoint_buff.clear()
        self.run(self.code)

    def do_continue(self) -> None:
        self.set_continue()

    def do_step_over(self) -> None:
        assert self.curframe is not None
        self.set_next(self.curframe)

    def do_step_into(self) -> None:
        self.set_step()

    def do_step_out(self) -> None:
        assert self.curframe is not None
        self.set_return(self.curframe)

    def do_terminate(self) -> None:
        # Set termination flag first
        self._terminated = True

        # Instead of calling set_quit() which fails in Pyodide,
        # we'll use a more direct approach to stop execution
        try:
            # Clear all breakpoints first
            self.clear_all_breaks()
            # Force the debugger to stop by clearing the frame
            self.curframe = None
            # Use set_step() with immediate return to exit cleanly
            self.set_step()
        except Exception as e:
            # If even basic operations fail, just set the flag and return
            print(f"Debug termination handled: {e}")

        # Always raise our custom exception to signal clean termination
        raise DebuggerTerminated("Debugger terminated by user")
