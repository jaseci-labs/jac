import sys;
import os;

import from .ipc { ipc_send_cmd }
import from .diff { DiffEngine }
import from .state { TuiState }
import from .transport { TtyFdTransport }
import from .tui_loop { tui_loop_once }
import from .tui_core { tui_setup, tui_teardown }

glob args = sys.argv;

glob state: TuiState = TuiState(),
     diff_engine: DiffEngine = DiffEngine(),
     tty_transport: TtyFdTransport = TtyFdTransport();

glob proj = os.getenv("JAC_AI_UI_PROJECT");

glob files_env = os.getenv("JAC_AI_UI_FILES");

glob presets_env = os.getenv("JAC_AI_UI_MODEL_PRESETS");

def _run {
    proj_s: str = "";
    if proj is not None {
        proj_s = proj;
    }
    files_s: str = "";
    if files_env is not None {
        files_s = files_env;
    }
    presets_s: str = "";
    if presets_env is not None {
        presets_s = presets_env;
    }

    if tui_setup(state, proj_s, files_s, presets_s) < 0 {
        sys.exit(1);
    }

    if len(args) > 1 {
        initial = args[1].strip();
        if len(initial) > 0 {
            ipc_send_cmd(state.ipc_fd, f"SEND:{initial}");
        }
    }

    while tui_loop_once(state, diff_engine, tty_transport, 1) { }

    tui_teardown(state);
}

with entry {
    _run();
}
