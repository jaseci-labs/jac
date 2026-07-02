import from .libc_tty { tty_open, tty_close }
import from .state { TuiState }
import from .select_list { SelectList, SelectItem }
import from .ipc { ipc_clear_cmd_queue, ipc_next_command }
import from .diff { DiffEngine }
import from .terminal_image { term_hyperlink, image_rows }
import from .transport { TtyFdTransport }
import from .tui_loop { tui_loop_once }
import from .tui_core { tui_populate_state, tui_enter_screen, tui_leave_screen }

import os;

import from jacpyembed {
    def jac_engine_boot -> i32;  def jpy_Py_Finalize -> None;  def jpy_PyRun_SimpleString(
        cmd: str
    ) -> i32;  def jpy_PyImport_AddModule(name: str) -> int;  def jpy_PyModule_GetDict(
        module: int
    ) -> int;  def jpy_PyRun_String(s: str, start: i32, g: int, l: int) -> int;  def jpy_PyEval_SaveThread -> int;  def jpy_PyEval_RestoreThread(
        s: int
    ) -> None;  def jpy_PyGILState_Ensure -> int;  def jpy_PyGILState_Release(
        state: int
    ) -> None;  def jpy_PyObject_CallOneArg(fn: int, arg: int) -> int;  def jpy_PyUnicode_FromString(
        s: str
    ) -> int;  def jpy_PyUnicode_AsUTF8(pyobj: int) -> str;  def jpy_Py_DecRef(
        pyobj: int
    ) -> None;
}

glob PY_EVAL: i32 = 258,
     proj = os.getenv("JAC_AI_UI_PROJECT"),
     files_env = os.getenv("JAC_AI_UI_FILES"),
     presets_env = os.getenv("JAC_AI_UI_MODEL_PRESETS");


def _byllm_runtime_hook_py -> str {
    return (
        "_byllm = os.environ.get('JAC_AI_TUI_BYLLM_SRC')\n" + "if _byllm and _byllm not in sys.path:\n" + "    sys.path.insert(0, _byllm)\n" + "_deps = os.environ.get('JAC_AI_TUI_DEPS', '')\n" + "if _deps:\n" + "    for _d in _deps.split(os.pathsep):\n" + "        if _d and _d not in sys.path:\n" + "            sys.path.append(_d)\n"
    );
}


def _agent_py_real -> str {
    return (
        "import os, sys, threading, queue\n" + _byllm_runtime_hook_py() + "try:\n" + "    from jaclang.cli.ai_agent import ui_configure, ui_stream, ui_stop\n" + "    from jaclang.cli.ai_tui.tui_shared import _frame_blob, _dispatch_cmd\n" + "except Exception as _e:\n" + "    sys.stderr.write('jac-ai-tui: embedded agent backend unavailable: ' + repr(_e) + '\\n')\n" + "    sys.stderr.write('  point the embedded interpreter at byllm: set JAC_AI_TUI_BYLLM_SRC=<jac-byllm checkout> and JAC_AI_TUI_DEPS=<dep dirs (litellm, openai, ...)>.\\n')\n" + "    raise\n" + "_q = queue.Queue()\n" + "_stop = threading.Event()\n" + "def _agent_setup():\n" + "    ui_configure()\n" + "    def _feed():\n" + "        try:\n" + "            for frame in ui_stream():\n" + "                if _stop.is_set():\n" + "                    break\n" + "                if frame.get('heartbeat'):\n" + "                    continue\n" + "                _q.put(_frame_blob(frame))\n" + "        except Exception:\n" + "            pass\n" + "    threading.Thread(target=_feed, daemon=True).start()\n" + "def _agent_poll():\n" + "    try:\n" + "        return _q.get_nowait()\n" + "    except queue.Empty:\n" + "        return ''\n" + "def _agent_send(line):\n" + "    _dispatch_cmd(line, _stop, None)\n" + "def _agent_stop():\n" + "    _stop.set()\n" + "    try:\n" + "        ui_stop()\n" + "    except Exception:\n" + "        pass\n"
    );
}


def _agent_py_stub -> str {
    return (
        "import threading, time, queue\n" + "_q = queue.Queue()\n" + "_stop = threading.Event()\n" + "def _agent_setup():\n" + "    def _feed():\n" + "        _q.put('TYPE:full\\nSTATUS:idle\\nACTIVE:\\nMODEL:stub\\nNEEDS_KEY:0\\nKEY_ENV:\\nEV:1:system:stub:embed host booted (stub agent)\\n---')\n" + "        n = 0\n" + "        while not _stop.is_set():\n" + "            n += 1\n" + "            _q.put('TYPE:delta\\nEV:1:system:stub:tick ' + str(n) + '\\n---')\n" + "            time.sleep(1.0)\n" + "    threading.Thread(target=_feed, daemon=True).start()\n" + "def _agent_poll():\n" + "    try:\n" + "        return _q.get_nowait()\n" + "    except queue.Empty:\n" + "        return ''\n" + "def _agent_send(line):\n" + "    _q.put('TYPE:delta\\nEV:2:user:stub:sent ' + line + '\\n---')\n" + "def _agent_stop():\n" + "    _stop.set()\n"
    );
}


def _agent_poll(d: int) -> str {
    gstate = jpy_PyGILState_Ensure();
    pyobj: int = jpy_PyRun_String("_agent_poll()", PY_EVAL, d, d);
    out: str = "";
    if pyobj != 0 {
        out = jpy_PyUnicode_AsUTF8(pyobj);
        jpy_Py_DecRef(pyobj);
    }
    jpy_PyGILState_Release(gstate);
    return out;
}


def _agent_send(d: int, line: str) {
    gstate = jpy_PyGILState_Ensure();
    fn: int = jpy_PyRun_String("_agent_send", PY_EVAL, d, d);
    if fn != 0 {
        arg: int = jpy_PyUnicode_FromString(line);
        if arg != 0 {
            res: int = jpy_PyObject_CallOneArg(fn, arg);
            if res != 0 {
                jpy_Py_DecRef(res);
            }
            jpy_Py_DecRef(arg);
        }
        jpy_Py_DecRef(fn);
    }
    jpy_PyGILState_Release(gstate);
}


obj EmbedPyTransport(TtyFdTransport) {
    has py_dict: int = 0;

    def recv_blob -> str {
        return _agent_poll(self.py_dict);
    }

    def flush_outbound_cmds {
        cmd: str = ipc_next_command();
        while len(cmd) > 0 {
            _agent_send(self.py_dict, cmd);
            cmd = ipc_next_command();
        }
    }
}

glob host_state: TuiState = TuiState(),
     host_diff: DiffEngine = DiffEngine(),
     embed_transport: EmbedPyTransport = EmbedPyTransport();


def _run_embed -> None {
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

    engine_rc: i32 = jac_engine_boot();
    if engine_rc != 0 {
        return;
    }

    agent_src: str = _agent_py_real();
    use_real = os.getenv("JAC_AI_TUI_EMBED_REAL");
    if use_real is None {
        agent_src = _agent_py_stub();
    }

    def_rc: i32 = jpy_PyRun_SimpleString(agent_src);
    main_mod: int = jpy_PyImport_AddModule("__main__");
    d: int = jpy_PyModule_GetDict(main_mod);
    setup_rc: i32 = 0;
    if def_rc == 0 {
        setup_rc = jpy_PyRun_SimpleString("_agent_setup()");
    }
    if def_rc != 0 or setup_rc != 0 {
        jpy_Py_Finalize();
        return;
    }

    ipc_clear_cmd_queue();
    host_state.ipc_fd = -1;
    fd: int = tty_open();
    if fd < 0 {
        jpy_PyRun_SimpleString("_agent_stop()");
        return;
    }
    host_state.render_fd = fd;
    tui_populate_state(host_state, proj_s, files_s, presets_s);
    tui_enter_screen(host_state);
    embed_transport.py_dict = d;
    embed_transport.stdin_eof = False;

    ts: int = jpy_PyEval_SaveThread();

    while tui_loop_once(host_state, host_diff, embed_transport) { }

    jpy_PyEval_RestoreThread(ts);
    jpy_PyRun_SimpleString("_agent_stop()");
    tui_leave_screen(host_state);
    tty_close();
    jpy_Py_Finalize();
}


with entry {
    _run_embed();
}
