import os;
import json;
import shlex;
import signal;
import subprocess;
import threading;
import time;

glob ACP_PROTOCOL_VERSION: int = 1,
     CLIENT_NAME: str = "jac-hack",
     HANDSHAKE_SECS: float = 120.0,
     CANCEL_GRACE_SECS: float = 10.0,
     TERMINAL_DEFAULT_LIMIT: int = 262144,
     ERR_METHOD_NOT_FOUND: int = -32601,
     ERR_INVALID_PARAMS: int = -32602,
     ERR_INTERNAL: int = -32603,
     ERR_RESOURCE_NOT_FOUND: int = -32002,
     SIGKILL: int = 9,
     LOG_MAX_BYTES: int = 4000000,
     TOOL_UPDATE_FIELDS: list[tuple[str, str]] = [
         ("title", "title"),
         ("kind", "kind"),
         ("status", "status"),
         ("content", "content"),
         ("locations", "locations"),
         ("rawInput", "raw_input"),
         ("rawOutput", "raw_output")
     ];

obj AcpError(Exception) {
    has method: str = "",
        code: int = 0,
        message: str = "",
        data: any = None;

    def postinit -> None;
}

obj PendingCall {
    has done: any = None,
        result: any = None,
        error: (dict[str, any] | None) = None;

    def postinit -> None;
}

obj AcpTerminal {
    has terminal_id: str,
        command: str = "",
        proc: any = None,
        output: str = "",
        limit: int = TERMINAL_DEFAULT_LIMIT,
        truncated: bool = False,
        exit_code: (int | None) = None,
        signal_name: (str | None) = None,
        done: any = None,
        lock: any = None;

    def postinit -> None;
    def append(chunk: str) -> None;
    def status -> (dict[str, any] | None);
}

obj AcpSession(AgentSession) {
    has command: list[str] = [],
        env: dict[str, str] = {},
        load_session_id: str = "",
        client_version: str = "",
        proc: any = None,
        agent_info: dict[str, any] = {},
        agent_caps: dict[str, any] = {},
        auth_methods: list[any] = [],
        models: dict[str, any] = {},
        modes: dict[str, any] = {},
        commands: list[dict[str, any]] = [],
        stop_reason: str = "",
        _pending: dict[int, PendingCall] = {},
        _next_id: int = 0,
        _wlock: any = None,
        _reader: any = None,
        _alive: bool = False,
        _terminals: dict[str, AcpTerminal] = {},
        _turn: any = None,
        _cancel_at: float = 0.0,
        _stderr: any = None,
        _replaying: bool = False;

    override def emit(kind: str, data: (dict[str, any] | None) = None) -> AgentEvent;
    override def start(cwd: str, mcp_servers: list[dict[str, any]]) -> None;
    override def prompt(blocks: list[dict[str, any]]) -> None;
    override def cancel -> None;
    override def stop -> None;
    def alive -> bool;
    def request(method: str, params: dict[str, any], timeout: float = 0.0) -> any;
    def notify(method: str, params: dict[str, any]) -> None;
    def _spawn -> None;
    def _send(msg: dict[str, any]) -> None;
    def _reply(rid: any, result: any) -> None;
    def _reply_error(rid: any, code: int, message: str) -> None;
    def _read_loop -> None;
    def _on_response(msg: dict[str, any]) -> None;
    def _on_exit -> None;
    def _on_notification(method: str, params: dict[str, any]) -> None;
    def _on_update(upd: dict[str, any]) -> None;
    def _serve_request(msg: dict[str, any]) -> None;
    def _handle(method: str, params: dict[str, any], rid: any) -> any;
    def _run_turn(blocks: list[dict[str, any]]) -> None;
    def _adapt_blocks(blocks: list[dict[str, any]]) -> list[dict[str, any]];
    def _permission(params: dict[str, any], rid: any) -> dict[str, any];
    def _fs_read(params: dict[str, any]) -> dict[str, any];
    def _fs_write(params: dict[str, any]) -> dict[str, any];
    def _terminal_create(params: dict[str, any]) -> dict[str, any];
    def _terminal_pump(term: AcpTerminal) -> None;
    def _terminal_event(term: AcpTerminal) -> None;
    def _terminal(params: dict[str, any]) -> AcpTerminal;
    def _kill_terminal(term: AcpTerminal) -> None;
    def _trace(direction: str, text: str) -> None;
}

def chunk_text(content: any) -> str;

def jac_version -> str;

impl AcpError.postinit -> None {
    Exception.__init__(self, f"{self.method}: {self.message} (code {self.code})");
}

impl PendingCall.postinit -> None {
    self.done = threading.Event();
}

impl AcpTerminal.postinit -> None {
    self.done = threading.Event();
    self.lock = threading.Lock();
}

impl AcpTerminal.append(chunk: str) -> None {
    with self.lock {
        self.output += chunk;
        if self.limit > 0 and len(self.output.encode("utf-8")) > self.limit {
            data = self.output.encode("utf-8")[-self.limit:];
            self.output = data.decode("utf-8", errors="ignore");
            self.truncated = True;
        }
    }
}

impl AcpTerminal.status -> (dict[str, any] | None) {
    if not self.done.is_set() {
        return None;
    }
    return {"exitCode": self.exit_code, "signal": self.signal_name};
}

impl AcpSession.emit(kind: str, data: (dict[str, any] | None) = None) -> AgentEvent {
    payload = data if data is not None else {};
    if self._replaying and kind != "ready" {
        payload["replay"] = True;
    }
    return super.emit(kind, payload);
}

impl AcpSession.start(cwd: str, mcp_servers: list[dict[str, any]]) -> None {
    self.cwd = os.path.realpath(cwd or self.root_dir or os.getcwd());
    if not self.root_dir {
        self.root_dir = self.cwd;
    }
    self._wlock = threading.Lock();
    self._pending = {};
    self._terminals = {};
    self._spawn();
    init = self.request(
        "initialize",
        {
            "protocolVersion": ACP_PROTOCOL_VERSION,
            "clientCapabilities": {
                "fs": {"readTextFile": True, "writeTextFile": True},
                "terminal": True
            },
            "clientInfo": {
                "name": CLIENT_NAME,
                "title": "jac hack",
                "version": self.client_version or jac_version()
            }
        },
        timeout=HANDSHAKE_SECS
    );
    init = init or {};
    self.agent_info = init.get("agentInfo") or {};
    self.agent_caps = init.get("agentCapabilities") or {};
    self.auth_methods = init.get("authMethods") or [];
    if init.get("protocolVersion", ACP_PROTOCOL_VERSION) != ACP_PROTOCOL_VERSION {
        self.log(f"agent speaks protocol version {init.get('protocolVersion')}");
    }
    base: dict[str, any] = {"cwd": self.cwd, "mcpServers": mcp_servers};
    sess: any = None;
    resumed = False;
    if self.load_session_id and self.agent_caps.get("loadSession") {
        params = dict(base);
        params["sessionId"] = self.load_session_id;
        try {
            self._replaying = True;
            sess = self.request("session/load", params, timeout=HANDSHAKE_SECS) or {};
            self.agent_session_id = self.load_session_id;
            self._replaying = False;
            resumed = True;
        } except AcpError as e {
            self._replaying = False;
            self.emit("log", {"text": f"could not resume the agent session: {e}"});
            sess = None;
        }
    }
    if sess is None {
        sess = self.request("session/new", base, timeout=HANDSHAKE_SECS) or {};
        self.agent_session_id = str(sess.get("sessionId", ""));
        if not self.agent_session_id {
            raise RuntimeError(f"agent '{self.name}' returned no session id");
        }
    }
    self.models = sess.get("models") or {};
    self.modes = sess.get("modes") or {};
    ready: dict[str, any] = {
        "agent": self.name,
        "title": self.agent_info.get("title")
            or self.agent_info.get("name")
            or self.name,
        "version": self.agent_info.get("version", ""),
        "session_id": self.agent_session_id,
        "load_session": bool(self.agent_caps.get("loadSession")),
        "resumed": resumed,
        "prompt_capabilities": self.agent_caps.get("promptCapabilities") or {}
    };
    if self.models {
        ready["models"] = self.models;
    }
    if self.modes {
        ready["modes"] = self.modes;
    }
    if self.commands {
        ready["commands"] = self.commands;
    }
    self.emit("ready", ready);
}

impl AcpSession._spawn -> None {
    if not self.command {
        raise RuntimeError(f"agent '{self.name}' has no command");
    }
    env = dict(os.environ);
    for (k, v) in self.env.items() {
        env[str(k)] = str(v);
    }
    err_path = (
        self.log_path[:-4] + ".stderr.log"
            if self.log_path.endswith(".log")
            else self.log_path + ".stderr"
    );
    if self.log_path {
        os.makedirs(os.path.dirname(self.log_path), exist_ok=True);
        for p in [self.log_path, err_path] {
            try {
                if os.path.getsize(p) > LOG_MAX_BYTES {
                    os.replace(p, p + ".1");
                }
            } except OSError {}
        }
        self._stderr = open(err_path, "ab");
    } else {
        self._stderr = open(os.devnull, "wb");
    }
    self.log(f"spawn {shlex.join(self.command)} (cwd {self.cwd})");
    try {
        self.proc = subprocess.Popen(
            self.command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self._stderr,
            cwd=self.cwd,
            env=env,
            bufsize=0,
            start_new_session=True
        );
    } except OSError as e {
        self._stderr.close();
        raise RuntimeError(
            f"could not start agent '{self.name}' ({self.command[0]}): {e}"
        );
    }
    self._alive = True;
    self._stopped = False;
    self._reader = threading.Thread(
        target=self._read_loop, name=f"acp-{self.name}", daemon=True
    );
    self._reader.start();
}

impl AcpSession.alive -> bool {
    return self._alive and self.proc is not None and self.proc.poll() is None;
}

impl AcpSession.request(
    method: str, params: dict[str, any], timeout: float = 0.0
) -> any {
    if not self._alive {
        raise AcpError(
            method=method, code=ERR_INTERNAL, message="the agent is not running"
        );
    }
    pc = PendingCall();
    with self._lock {
        self._next_id += 1;
        rid = self._next_id;
        self._pending[rid] = pc;
    }
    try {
        self._send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params});
        deadline = time.time() + timeout if timeout > 0 else 0.0;
        while not pc.done.wait(0.2) {
            now = time.time();
            if deadline and now > deadline {
                raise AcpError(
                    method=method,
                    code=ERR_INTERNAL,
                    message=f"no answer after {int(timeout)}s"
                );
            }
            if method == "session/prompt"
                and self._cancel_at
                and now > self._cancel_at + CANCEL_GRACE_SECS {
                return {"stopReason": "cancelled"};
            }
        }
    } finally {
        with self._lock {
            self._pending.pop(rid, None);
        }
    }
    if pc.error is not None {
        raise AcpError(
            method=method,
            code=int(pc.error.get("code", ERR_INTERNAL) or 0),
            message=str(pc.error.get("message", "error")),
            data=pc.error.get("data")
        );
    }
    return pc.result;
}

impl AcpSession.notify(method: str, params: dict[str, any]) -> None {
    self._send({"jsonrpc": "2.0", "method": method, "params": params});
}

impl AcpSession._send(msg: dict[str, any]) -> None {
    line = json.dumps(msg, ensure_ascii=False);
    self._trace("->", line);
    data = (line + "\n").encode("utf-8");
    try {
        with self._wlock {
            self.proc.stdin.write(data);
            self.proc.stdin.flush();
        }
    } except (OSError, ValueError, AttributeError) as e {
        raise AcpError(
            method=str(msg.get("method", "reply")),
            code=ERR_INTERNAL,
            message=f"the agent's stdin is closed ({e})"
        );
    }
}

impl AcpSession._reply(rid: any, result: any) -> None {
    try {
        self._send({"jsonrpc": "2.0", "id": rid, "result": result});
    } except AcpError {}
}

impl AcpSession._reply_error(rid: any, code: int, message: str) -> None {
    try {
        self._send(
            {"jsonrpc": "2.0", "id": rid, "error": {"code": code, "message": message}}
        );
    } except AcpError {}
}

impl AcpSession._read_loop -> None {
    out = self.proc.stdout;
    while True {
        try {
            line = out.readline();
        } except (OSError, ValueError) {
            break;
        }
        if not line {
            break;
        }
        text = line.decode("utf-8", errors="replace").strip();
        if not text {
            continue;
        }
        self._trace("<-", text);
        try {
            msg = json.loads(text);
        } except ValueError {
            self.emit("log", {"text": f"agent wrote a non-JSON line: {text[:200]}"});
            continue;
        }
        if not isinstance(msg, dict) {
            continue;
        }
        method = msg.get("method");
        if method is None {
            self._on_response(msg);
        } elif "id" in msg {
            threading.Thread(
                target=self._serve_request, args=(msg, ), daemon=True
            ).start();
        } else {
            try {
                self._on_notification(str(method), msg.get("params") or {});
            } except Exception as e {
                self.log(f"notification {method} failed: {e!r}");
            }
        }
    }
    self._on_exit();
}

impl AcpSession._on_response(msg: dict[str, any]) -> None {
    rid = msg.get("id");
    if not isinstance(rid, int) {
        return;
    }
    with self._lock {
        pc = self._pending.get(rid);
    }
    if pc is None {
        return;
    }
    if "error" in msg {
        err = msg.get("error");
        pc.error = err if isinstance(err, dict) else {"message": str(err)};
    } else {
        pc.result = msg.get("result");
    }
    pc.done.set();
}

impl AcpSession._on_exit -> None {
    self._alive = False;
    code: any = None;
    if self.proc is not None {
        try {
            code = self.proc.wait(timeout=2);
        } except Exception {
            code = self.proc.poll();
        }
    }
    self.log(f"agent exited with code {code}");
    with self._lock {
        pend = list(self._pending.values());
    }
    for pc in pend {
        pc.error = {
            "code": ERR_INTERNAL,
            "message": f"the agent process exited (code {code}); see {self.log_path}"
        };
        pc.done.set();
    }
    self.cancel_waits();
    for term in list(self._terminals.values()) {
        self._kill_terminal(term);
    }
    if not self._stopped and not self._busy {
        self.emit(
            "error",
            {
                "message": f"agent '{self.name}' exited (code {code}); see {self.log_path}"
            }
        );
    }
}

impl AcpSession._on_notification(method: str, params: dict[str, any]) -> None {
    if method == "session/update" {
        upd = params.get("update") or {};
        if isinstance(upd, dict) {
            self._on_update(upd);
        }
        return;
    }
    self.emit("log", {"text": f"{method}: {json.dumps(params)[:300]}"});
}

impl AcpSession._on_update(upd: dict[str, any]) -> None {
    kind = str(upd.get("sessionUpdate", ""));
    if kind == "agent_message_chunk" {
        text = chunk_text(upd.get("content"));
        if text {
            data: dict[str, any] = {"text": text};
            if upd.get("messageId") {
                data["message_id"] = upd.get("messageId");
            }
            self.emit("message_chunk", data);
        }
    } elif kind == "agent_thought_chunk" {
        text = chunk_text(upd.get("content"));
        if text {
            self.emit("thought_chunk", {"text": text});
        }
    } elif kind == "user_message_chunk" {
        self.emit(
            "log",
            {"text": chunk_text(upd.get("content")), "role": "user", "replay": True}
        );
    } elif kind == "tool_call" {
        data = {
            "id": upd.get("toolCallId", ""),
            "title": upd.get("title", ""),
            "kind": upd.get("kind", "other"),
            "status": upd.get("status", "pending"),
            "content": upd.get("content") or [],
            "locations": upd.get("locations") or []
        };
        if "rawInput" in upd {
            data["raw_input"] = upd.get("rawInput");
        }
        self.emit("tool_call", data);
    } elif kind == "tool_call_update" {
        data = {"id": upd.get("toolCallId", "")};
        for (src, dst) in TOOL_UPDATE_FIELDS {
            if upd.get(src) is not None {
                data[dst] = upd.get(src);
            }
        }
        self.emit("tool_call_update", data);
    } elif kind == "plan" {
        self.emit("plan", {"entries": upd.get("entries") or []});
    } elif kind == "available_commands_update" {
        cmds = [
            {"name": c.get("name", ""), "description": c.get("description", "")}
            for c in (upd.get("availableCommands") or [])
            if isinstance(c, dict)
        ];
        self.commands = cmds;
        self.emit("commands", {"commands": cmds});
    } else {
        self.emit("log", {"text": f"{kind}: {json.dumps(upd)[:300]}", "update": kind});
    }
}

impl AcpSession._serve_request(msg: dict[str, any]) -> None {
    rid = msg.get("id");
    method = str(msg.get("method", ""));
    params = msg.get("params") or {};
    try {
        result = self._handle(method, params, rid);
    } except AcpError as e {
        self._reply_error(rid, e.code or ERR_INTERNAL, e.message);
        return;
    } except FileNotFoundError as e {
        self._reply_error(rid, ERR_RESOURCE_NOT_FOUND, f"not found: {e.filename or e}");
        return;
    } except Exception as e {
        self.log(f"{method} failed: {e!r}");
        self._reply_error(rid, ERR_INTERNAL, f"{type(e).__name__}: {e}");
        return;
    }
    self._reply(rid, result);
}

impl AcpSession._handle(method: str, params: dict[str, any], rid: any) -> any {
    if method == "session/request_permission" {
        return self._permission(params, rid);
    }
    if method == "fs/read_text_file" {
        return self._fs_read(params);
    }
    if method == "fs/write_text_file" {
        return self._fs_write(params);
    }
    if method == "terminal/create" {
        return self._terminal_create(params);
    }
    if method == "terminal/output" {
        term = self._terminal(params);
        with term.lock {
            res: dict[str, any] = {"output": term.output, "truncated": term.truncated};
        }
        st = term.status();
        if st is not None {
            res["exitStatus"] = st;
        }
        return res;
    }
    if method == "terminal/wait_for_exit" {
        term = self._terminal(params);
        while not term.done.wait(0.25) {
            if self._stopped {
                break;
            }
        }
        return {"exitCode": term.exit_code, "signal": term.signal_name};
    }
    if method == "terminal/kill" {
        self._kill_terminal(self._terminal(params));
        return {};
    }
    if method == "terminal/release" {
        term = self._terminal(params);
        self._kill_terminal(term);
        self._terminals.pop(term.terminal_id, None);
        return {};
    }
    raise AcpError(
        method=method, code=ERR_METHOD_NOT_FOUND, message=f"method not found: {method}"
    );
}

impl AcpSession._permission(params: dict[str, any], rid: any) -> dict[str, any] {
    options = [
        {
            "optionId": o.get("optionId", ""),
            "name": o.get("name", ""),
            "kind": o.get("kind", "")
        }
        for o in (params.get("options") or [])
        if isinstance(o, dict)
    ];
    self.expect(rid, "permission");
    if self._cancel_at {
        self.answer(rid, None);
    }
    self.emit(
        "permission",
        {
            "request_id": rid,
            "tool_call": params.get("toolCall") or {},
            "options": options
        }
    );
    choice = self.wait_answer(rid);
    if choice is None or choice not in [o["optionId"] for o in options] {
        return {"outcome": {"outcome": "cancelled"}};
    }
    return {"outcome": {"outcome": "selected", "optionId": choice}};
}

impl AcpSession._fs_read(params: dict[str, any]) -> dict[str, any] {
    path = str(params.get("path", ""));
    if not path {
        raise AcpError(
            method="fs/read_text_file",
            code=ERR_INVALID_PARAMS,
            message="path is required"
        );
    }
    text = self.read_text(path);
    line = params.get("line");
    limit = params.get("limit");
    if line or limit {
        lines = text.splitlines(keepends=True);
        start = max(int(line or 1) - 1, 0);
        end = start + int(limit) if limit else len(lines);
        text = "".join(lines[start:end]);
    }
    return {"content": text};
}

impl AcpSession._fs_write(params: dict[str, any]) -> dict[str, any] {
    path = str(params.get("path", ""));
    if not path {
        raise AcpError(
            method="fs/write_text_file",
            code=ERR_INVALID_PARAMS,
            message="path is required"
        );
    }
    failure = self.gate_write(path, str(params.get("content", "")));
    if failure is not None {
        raise AcpError(method="fs/write_text_file", code=ERR_INTERNAL, message=failure);
    }
    return {};
}

impl AcpSession._terminal_create(params: dict[str, any]) -> dict[str, any] {
    command = str(params.get("command", ""));
    args = [str(a) for a in (params.get("args") or [])];
    env = dict(os.environ);
    for e in (params.get("env") or []) {
        if isinstance(e, dict) and e.get("name") {
            env[str(e["name"])] = str(e.get("value", ""));
        }
    }
    cwd = self.resolve_path(str(params.get("cwd") or self.cwd));
    limit = params.get("outputByteLimit");
    tid = self.next_request_id("term");
    shown = shlex.join([command, *args]) if args else command;
    term = AcpTerminal(
        terminal_id=tid,
        command=shown,
        limit=int(limit) if limit is not None else TERMINAL_DEFAULT_LIMIT
    );
    try {
        if args {
            proc = subprocess.Popen(
                [command, *args],
                cwd=cwd,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                start_new_session=True
            );
        } else {
            proc = subprocess.Popen(
                command,
                shell=True,
                cwd=cwd,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                start_new_session=True
            );
        }
    } except OSError as e {
        raise AcpError(
            method="terminal/create",
            code=ERR_INTERNAL,
            message=f"could not run {shown}: {e}"
        );
    }
    term.proc = proc;
    self._terminals[tid] = term;
    self._terminal_event(term);
    threading.Thread(target=self._terminal_pump, args=(term, ), daemon=True).start();
    return {"terminalId": tid};
}

impl AcpSession._terminal_pump(term: AcpTerminal) -> None {
    out = term.proc.stdout;
    last = 0.0;
    while True {
        try {
            data = out.read1(8192) if out?.read1 else out.read(8192);
        } except (OSError, ValueError) {
            break;
        }
        if not data {
            break;
        }
        term.append(data.decode("utf-8", errors="replace"));
        now = time.time();
        if now - last > 0.2 {
            last = now;
            self._terminal_event(term);
        }
    }
    code = term.proc.wait();
    if code < 0 {
        try {
            term.signal_name = signal.Signals(-code).name;
        } except ValueError {
            term.signal_name = str(-code);
        }
    } else {
        term.exit_code = code;
    }
    term.done.set();
    self._terminal_event(term);
}

impl AcpSession._terminal_event(term: AcpTerminal) -> None {
    with term.lock {
        data: dict[str, any] = {
            "terminal_id": term.terminal_id,
            "command": term.command,
            "output": term.output
        };
    }
    if term.done.is_set() {
        data["exit_code"] = term.exit_code;
        if term.signal_name {
            data["signal"] = term.signal_name;
        }
    }
    self.emit("terminal", data);
}

impl AcpSession._terminal(params: dict[str, any]) -> AcpTerminal {
    tid = str(params.get("terminalId", ""));
    term = self._terminals.get(tid);
    if term is None {
        raise AcpError(
            method="terminal",
            code=ERR_INVALID_PARAMS,
            message=f"unknown terminal {tid}"
        );
    }
    return term;
}

impl AcpSession._kill_terminal(term: AcpTerminal) -> None {
    if term.proc is None or term.proc.poll() is not None {
        return;
    }
    try {
        os.killpg(term.proc.pid, signal.SIGTERM);
    } except OSError {
        try {
            term.proc.kill();
        } except OSError {}
    }
    try {
        term.proc.wait(timeout=3);
    } except subprocess.TimeoutExpired {
        try {
            os.killpg(term.proc.pid, SIGKILL);
        } except OSError {}
    }
}

impl AcpSession.prompt(blocks: list[dict[str, any]]) -> None {
    with self._lock {
        if self._busy {
            raise RuntimeError("the agent is still working on the previous prompt");
        }
        if not self.alive() {
            raise RuntimeError(f"agent '{self.name}' is not running");
        }
        self._busy = True;
        self._cancel_at = 0.0;
    }
    self._turn = threading.Thread(
        target=self._run_turn, args=(blocks, ), name="acp-turn", daemon=True
    );
    self._turn.start();
}

impl AcpSession._run_turn(blocks: list[dict[str, any]]) -> None {
    reason = "error";
    try {
        res = self.request(
            "session/prompt",
            {"sessionId": self.agent_session_id, "prompt": self._adapt_blocks(blocks)}
        )
            or {};
        reason = str(res.get("stopReason", "end_turn"));
    } except AcpError as e {
        reason = "cancelled" if self._cancel_at else "error";
        if reason == "error" {
            self.emit("error", {"message": e.message});
        }
    } except Exception as e {
        self.emit("error", {"message": f"{type(e).__name__}: {e}"});
    }
    self.stop_reason = reason;
    with self._lock {
        self._busy = False;
        self._cancel_at = 0.0;
    }
    self.emit("turn_end", {"stop_reason": reason});
}

impl AcpSession._adapt_blocks(blocks: list[dict[str, any]]) -> list[dict[str, any]] {
    caps = self.agent_caps.get("promptCapabilities") or {};
    if caps.get("embeddedContext") {
        return blocks;
    }
    out: list[dict[str, any]] = [];
    for b in blocks {
        if b.get("type") == "resource" {
            out.append({"type": "text", "text": blocks_text([b])});
        } else {
            out.append(b);
        }
    }
    return out;
}

impl AcpSession.cancel -> None {
    if self._busy and not self._cancel_at {
        self._cancel_at = time.time();
        try {
            self.notify("session/cancel", {"sessionId": self.agent_session_id});
        } except AcpError {}
    }
    self.cancel_waits();
}

impl AcpSession.stop -> None {
    if self._busy {
        self.cancel();
    }
    self._stopped = True;
    self.cancel_waits();
    for term in list(self._terminals.values()) {
        self._kill_terminal(term);
    }
    self._terminals = {};
    proc = self.proc;
    if proc is not None {
        try {
            proc.stdin.close();
        } except (OSError, ValueError) {}
        try {
            proc.wait(timeout=2);
        } except subprocess.TimeoutExpired {
            try {
                os.killpg(proc.pid, signal.SIGTERM);
            } except OSError {
                proc.terminate();
            }
            try {
                proc.wait(timeout=3);
            } except subprocess.TimeoutExpired {
                try {
                    os.killpg(proc.pid, SIGKILL);
                } except OSError {
                    proc.kill();
                }
            }
        }
    }
    if self._reader is not None {
        self._reader.join(timeout=3);
    }
    if self._turn is not None {
        self._turn.join(timeout=CANCEL_GRACE_SECS + 1);
    }
    if self._stderr is not None {
        try {
            self._stderr.close();
        } except OSError {}
    }
}

impl AcpSession._trace(direction: str, text: str) -> None {
    if os.environ.get("JAC_STUDIO_ACP_TRACE") {
        self.log(f"{direction} {text[:4000]}");
    }
}

impl chunk_text(content: any) -> str {
    if isinstance(content, list) {
        return "".join([chunk_text(c) for c in content]);
    }
    if not isinstance(content, dict) {
        return "";
    }
    kind = content.get("type", "");
    if kind == "text" {
        return str(content.get("text", ""));
    }
    if kind == "resource_link" {
        return f"[{content.get('name', '')}]({content.get('uri', '')})";
    }
    if kind == "resource" {
        res = content.get("resource") or {};
        return str(res.get("text", "")) if isinstance(res, dict) else "";
    }
    return "";
}

impl jac_version -> str {
    try {
        import from importlib.metadata { version }
        return version("jaclang");
    } except Exception {
        return "dev";
    }
}
