"""Run the NA TUI in-process for `jac ai --tui` (no sidecar subprocess).

The in-process backend loads `libtui.so` via ctypes (see `tui_host`) and drives
it from two plain threads -- a feeder (ui_stream frames -> tui_apply_frame) and a
ticker (poll the tty, dispatch keys, drain the command pull-queue, render). The
wire grammar is shared with the subprocess backend through `tui_shared`. See
PLAN-tui-in-process §5/§8/§9.
"""

import from jaclang.cli.agent_api { AgentRequest }

def run_tui_in_process(req: AgentRequest) -> int;
