import os;
import re;
import fnmatch;
import logging;
import signal;
import subprocess;
import threading;
import time;
import importlib.util;

glob TOOL_KINDS: dict[str, str] = {
         "read_file": "read",
         "list_dir": "read",
         "search": "search",
         "write_file": "edit",
         "run_command": "execute",
         "find_symbol": "search",
         "symbol_context": "read",
         "symbol_uses": "search",
         "archwire": "search",
         "architecture": "search",
         "insight": "search"
     },
     NOISY_LOGGERS: list[str] = ["LiteLLM", "litellm", "byllm", "httpx", "openai"],
     MAX_TOOL_OUTPUT: int = 20000,
     SIGKILL: int = 9,
     DEFAULT_MODEL: str = "gpt-4o-mini",
     TURN_DOC: str = "Carry out the user's request on this Jac project, then answer in concise markdown.",
     SYSTEM_PROMPT: str = """You are the built-in coding agent of jac hack, working inside a Jac project.
Read code with the tools before you answer; do not guess. Paths are relative to the project root.
Prefer the compiler-aware tools: find_symbol to locate a symbol, symbol_context for its declaration,
impl body and wiring, symbol_uses for its uses, archwire for a module's providers, consumers and rules,
architecture for a package's sub-packages, the wires between them and the cycles among them,
insight for roles, interfaces, rule use, slices, blast radius, clusters, a tour, or the diff since main.
In Jac, imports between project modules are wires in archwire.jac, not import lines in the file.
To change a file, call write_file with the complete new content; the user approves every write and may
reject it with a reason. Keep answers short and concrete.""";

obj NativeAgentSession(AgentSession) {
    has model_name: str = "",
        llm: any = None,
        project_model: any = None,
        history: list[any] = [],
        max_iterations: int = 30,
        command_timeout: float = 120.0,
        auto_approve_commands: bool = False,
        code_intel: any = None,
        _thought: str = "",
        _cancel: bool = False,
        _gen: int = 0,
        _turn: any = None,
        _procs: list[any] = [],
        _calls: dict[str, str] = {};

    override def start(cwd: str, mcp_servers: list[dict[str, any]]) -> None;
    override def prompt(blocks: list[dict[str, any]]) -> None;
    override def cancel -> None;
    override def stop -> None;
    def resolve_llm -> any;
    def quiet_logging -> None;
    def _run_turn(blocks: list[dict[str, any]], gen: int) -> None;
    def _forward(ev: any, gen: int) -> None;
    def _emit_if(gen: int, kind: str, data: dict[str, any]) -> None;
    def _finish(gen: int, reason: str) -> None;
    def make_tools -> list[any];
    def model -> any;
    def intel -> any;
    def rel(path: str) -> str;
    def inside(path: str) -> bool;
    def t_read_file(path: str, start_line: int, max_lines: int) -> str;
    def t_list_dir(path: str) -> str;
    def t_search(pattern: str, path: str, file_glob: str, max_results: int) -> str;
    def t_write_file(path: str, content: str) -> str;
    def t_run_command(command: str, timeout_sec: int) -> str;
    def t_find_symbol(query: str, kind: str) -> str;
    def t_symbol_context(key: str) -> str;
    def t_symbol_uses(name: str) -> str;
    def t_archwire(module: str) -> str;
    def t_architecture(scope: str) -> str;
    def t_insight(view: str, key: str) -> str;
}

def friendly_error(e: Exception, model_name: str) -> str;

def tool_title(tool: str, args: any) -> str;

def tool_locations(args: any, root_dir: str) -> list[dict[str, any]];

impl NativeAgentSession.start(cwd: str, mcp_servers: list[dict[str, any]]) -> None {
    self.cwd = os.path.realpath(cwd or self.root_dir or os.getcwd());
    if not self.root_dir {
        self.root_dir = self.cwd;
    }
    self._procs = [];
    self._calls = {};
    if importlib.util.find_spec("litellm") is None {
        raise RuntimeError(
            "the built-in agent needs byllm's model client (litellm), which this jac "
                + "environment does not have; add it with `jac install litellm`"
        );
    }
    self.quiet_logging();
    self.llm = self.resolve_llm();
    name = str(getattr(self.llm, "model_name", "") or self.model_name);
    self.model_name = name;
    if mcp_servers {
        self.log(
            "the built-in agent uses its own compiler tools; ignoring "
                + ", ".join([str(m.get("name", "?")) for m in mcp_servers])
        );
    }
    self.emit(
        "ready",
        {
            "agent": self.name or "jac",
            "title": "Jac (byllm)",
            "version": "",
            "models": {"currentModelId": name, "availableModels": [{"modelId": name}]},
            "commands": []
        }
    );
}

impl NativeAgentSession.resolve_llm -> any {
    if self.llm is not None {
        return self.llm;
    }
    import from jaclang.byllm.llm { Model }
    name = self.model_name or os.environ.get("BYLLM_DEFAULT_MODEL", "");
    if not name {
        try {
            import from jaclang.byllm.config_loader { get_byllm_config }
            name = str(
                get_byllm_config().get_model_config().get("default_model", "") or ""
            );
        } except Exception {
            name = "";
        }
    }
    return Model(model_name=name or DEFAULT_MODEL);
}

impl NativeAgentSession.quiet_logging -> None {
    handler: any = None;
    if self.log_path {
        try {
            os.makedirs(os.path.dirname(self.log_path), exist_ok=True);
            handler = logging.FileHandler(self.log_path, encoding="utf-8");
        } except OSError {
            handler = None;
        }
    }
    for name in NOISY_LOGGERS {
        lg = logging.getLogger(name);
        lg.propagate = False;
        lg.handlers = [handler] if handler is not None else [logging.NullHandler()];
    }
    try {
        import litellm;
        litellm.suppress_debug_info = True;
        litellm.set_verbose = False;
    } except Exception {}
}

impl NativeAgentSession.prompt(blocks: list[dict[str, any]]) -> None {
    with self._lock {
        if self._busy {
            raise RuntimeError("the agent is still working on the previous prompt");
        }
        if self.llm is None {
            raise RuntimeError("the agent is not started");
        }
        self._busy = True;
        self._cancel = False;
        self._gen += 1;
        gen = self._gen;
    }
    self._turn = threading.Thread(
        target=self._run_turn, args=(blocks, gen), name="jac-agent-turn", daemon=True
    );
    self._turn.start();
}

impl NativeAgentSession._run_turn(blocks: list[dict[str, any]], gen: int) -> None {
    llm = self.llm;
    tools = self.make_tools();
    conv = list(self.history);
    self._thought = "";
    request = blocks_text(blocks);
    def studio_turn(request: str) -> str by llm(
        tools=tools,
        conversation=conv,
        stream=True,
        logging=True,
        system_prompt=SYSTEM_PROMPT + f"\nProject root: {self.root_dir}",
        max_react_iterations=self.max_iterations
    );
    studio_turn.__doc__ = TURN_DOC;
    reason = "end_turn";
    stream: any = None;
    try {
        stream = studio_turn(request);
        for ev in stream {
            if self._cancel or gen != self._gen {
                reason = "cancelled";
                break;
            }
            self._forward(ev, gen);
        }
    } except Exception as e {
        if self._cancel {
            reason = "cancelled";
        } else {
            reason = "error";
            self.log(f"turn failed: {e!r}");
            self._emit_if(
                gen, "error", {"message": friendly_error(e, self.model_name)}
            );
        }
    } finally {
        if stream is not None and hasattr(stream, "close") {
            try {
                stream.close();
            } except Exception {}
        }
    }
    if reason == "end_turn" and gen == self._gen {
        self.history = conv;
    }
    self._finish(gen, reason);
}

impl NativeAgentSession._forward(ev: any, gen: int) -> None {
    kind = str(getattr(ev, "event_type", ""));
    data = getattr(ev, "data", {}) or {};
    if kind == "chunk" {
        self._thought = "";
        text = str(data.get("content", ""));
        if text {
            self._emit_if(gen, "message_chunk", {"text": text});
        }
    } elif kind == "thought" {
        self._thought += str(data.get("content", ""));
    } elif kind == "reasoning" {
        text = str(data.get("content", ""));
        if text {
            self._emit_if(gen, "thought_chunk", {"text": text});
        }
    } elif kind in ["steps_done", "stream_reset"] {
        self._thought = "";
        if kind == "stream_reset" {
            self._emit_if(gen, "log", {"text": "the model restarted its reply"});
        }
    } elif kind == "tool_call" {
        if self._thought.strip() {
            self._emit_if(gen, "thought_chunk", {"text": self._thought});
        }
        self._thought = "";
        tool = str(data.get("tool", ""));
        args = data.get("args") or {};
        cid = str(data.get("call_id", "")) or self.next_request_id("call");
        self._calls[tool] = cid;
        self._emit_if(
            gen,
            "tool_call",
            {
                "id": cid,
                "title": tool_title(tool, args),
                "kind": TOOL_KINDS.get(tool, "other"),
                "status": "in_progress",
                "content": [],
                "locations": tool_locations(args, self.root_dir),
                "raw_input": args
            }
        );
    } elif kind == "tool_result" {
        tool = str(data.get("tool", ""));
        cid = str(data.get("call_id", "")) or self._calls.get(tool, "");
        result = str(data.get("result", ""));
        failed = result.startswith("error:") or result.startswith("rejected:");
        self._emit_if(
            gen,
            "tool_call_update",
            {
                "id": cid,
                "status": "failed" if failed else "completed",
                "content": [
                    {"type": "content", "content": {"type": "text", "text": result}}
                ]
            }
        );
    } elif kind == "compaction" {
        self._emit_if(gen, "log", {"text": "the conversation was compacted"});
    }
}

impl NativeAgentSession._emit_if(gen: int, kind: str, data: dict[str, any]) -> None {
    if gen == self._gen and not (self._cancel and kind != "turn_end") {
        self.emit(kind, data);
    }
}

impl NativeAgentSession._finish(gen: int, reason: str) -> None {
    with self._lock {
        if gen != self._gen or not self._busy {
            return;
        }
        self._busy = False;
    }
    self.emit("turn_end", {"stop_reason": reason});
}

impl NativeAgentSession.cancel -> None {
    self._cancel = True;
    self.cancel_waits();
    for p in list(self._procs) {
        try {
            os.killpg(p.pid, signal.SIGTERM);
        } except OSError {}
    }
    with self._lock {
        was_busy = self._busy;
        self._busy = False;
    }
    if was_busy {
        self.emit("turn_end", {"stop_reason": "cancelled"});
    }
}

impl NativeAgentSession.stop -> None {
    self.cancel();
    self._stopped = True;
    if self._turn is not None {
        self._turn.join(timeout=1.0);
    }
}

impl NativeAgentSession.make_tools -> list[any] {
    def read_file(path: str, start_line: int = 1, max_lines: int = 400) -> str {
        return self.t_read_file(path, start_line, max_lines);
    }
    read_file.__doc__ = "Read a text file of the project. Returns numbered lines starting at start_line (1-based), at most max_lines of them.";
    def list_dir(path: str = ".") -> str {
        return self.t_list_dir(path);
    }
    list_dir.__doc__ = "List a directory of the project; directories end with '/'.";
    def search(
        pattern: str, path: str = ".", file_glob: str = "*.jac", max_results: int = 80
    ) -> str {
        return self.t_search(pattern, path, file_glob, max_results);
    }
    search.__doc__ = "Search file contents with a regular expression under path (a directory or file), in files whose name matches file_glob (use '*' for every text file). Returns path:line: text.";
    def write_file(path: str, content: str) -> str {
        return self.t_write_file(path, content);
    }
    write_file.__doc__ = "Write the complete new content of a project file. The user reviews every write; a rejection comes back with the reason.";
    def run_command(command: str, timeout_sec: int = 120) -> str {
        return self.t_run_command(command, timeout_sec);
    }
    run_command.__doc__ = "Run a shell command in the project root (the user approves it first). Returns the exit code and the output.";
    def find_symbol(query: str, kind: str = "") -> str {
        return self.t_find_symbol(query, kind);
    }
    find_symbol.__doc__ = "Find modules and symbols (archetypes, abilities, fields) in the project model by name or dotted key. kind narrows it: module, obj, node, edge, walker, def, can, method, has, enum.";
    def symbol_context(key: str) -> str {
        return self.t_symbol_context(key);
    }
    symbol_context.__doc__ = "Show a symbol or module by key (e.g. pkg.mod.Name.method): location, signature, the wires that carry it, rules, its declaration and its .impl.jac body.";
    def symbol_uses(name: str) -> str {
        return self.t_symbol_uses(name);
    }
    symbol_uses.__doc__ = "List where a symbol is defined and used across the project, from the compiler's symbol tables. Takes a plain name or a dotted key.";
    def archwire(module: str) -> str {
        return self.t_archwire(module);
    }
    archwire.__doc__ = "Show a module's architecture neighbourhood: the wires that feed it and that it feeds (with payload names) and the archwire rules governing it.";
    def architecture(scope: str = "") -> str {
        return self.t_architecture(scope);
    }
    architecture.__doc__ = "Show the architecture one package level at a time: the groups under scope (a package such as pkg.sub, a module shown among its siblings, or empty for the whole project) in provider-first layers, a matrix of wire counts between them, the backward wires that break the layering, and cycles.";
    def insight(view: str, key: str = "") -> str {
        return self.t_insight(view, key);
    }
    insight.__doc__ = "Higher-level views of the wiring. view: roles (foundations, hubs, entry points under key), interface (names crossing the boundary of key), rules (rule use, unused permissions, violations), slice (what module key rests on), blast (what depends on a module or name key), clusters (natural clusters vs packages under key), tour (an onboarding tour of key), diff (architecture changes since git revision key).";
    return [
        read_file,
        list_dir,
        search,
        write_file,
        run_command,
        find_symbol,
        symbol_context,
        symbol_uses,
        archwire,
        architecture,
        insight
    ];
}

impl NativeAgentSession.model -> any {
    if self.project_model is None {
        pm = ProjectModel(root_dir=self.root_dir);
        pm.build();
        self.project_model = pm;
    }
    return self.project_model;
}

impl NativeAgentSession.intel -> any {
    if self.code_intel is None {
        self.emit(
            "log",
            {
                "text": "loading the compiler's symbol tables (the first use takes a while)"
            }
        );
        ci = CodeIntelligence(proj_dir=self.root_dir);
        ci.load();
        self.code_intel = ci;
    }
    return self.code_intel;
}

impl NativeAgentSession.rel(path: str) -> str {
    try {
        r = os.path.relpath(path, self.root_dir);
    } except ValueError {
        return path;
    }
    return path if r.startswith("..") else r;
}

impl NativeAgentSession.inside(path: str) -> bool {
    full = os.path.realpath(self.resolve_path(path));
    top = os.path.realpath(self.root_dir);
    return full == top or full.startswith(top + os.sep);
}

impl NativeAgentSession.t_read_file(path: str, start_line: int, max_lines: int) -> str {
    if self._cancel {
        return "error: cancelled";
    }
    try {
        text = self.read_text(path);
    } except FileNotFoundError {
        return f"error: no such file: {path}";
    } except OSError as e {
        return f"error: {e}";
    }
    lines = text.splitlines();
    start = max(int(start_line or 1), 1);
    count = max(int(max_lines or 400), 1);
    chunk = lines[start - 1:start - 1 + count];
    out = [f"{start + i:>5}  {ln}" for (i, ln) in enumerate(chunk)];
    rest = len(lines) - (start - 1 + len(chunk));
    if rest > 0 {
        out.append(
            f"... ({rest} more lines; call again with start_line={start + len(chunk)})"
        );
    }
    if not out {
        return f"(empty: {path} has {len(lines)} lines)";
    }
    return "\n".join(out);
}

impl NativeAgentSession.t_list_dir(path: str) -> str {
    full = self.resolve_path(path or ".");
    if not os.path.isdir(full) {
        return f"error: not a directory: {path}";
    }
    try {
        names = sorted(os.listdir(full));
    } except OSError as e {
        return f"error: {e}";
    }
    out: list[str] = [];
    for n in names {
        if n in [".git", "__pycache__", "node_modules"] {
            continue;
        }
        out.append(n + "/" if os.path.isdir(os.path.join(full, n)) else n);
    }
    if len(out) > 300 {
        out = out[:300] + [f"... ({len(out) - 300} more)"];
    }
    return "\n".join(out) or "(empty)";
}

impl NativeAgentSession.t_search(
    pattern: str, path: str, file_glob: str, max_results: int
) -> str {
    try {
        rx = re.compile(pattern);
    } except re.error {
        rx = re.compile(re.escape(pattern));
    }
    base = self.resolve_path(path or ".");
    files: list[str] = [];
    if os.path.isfile(base) {
        files = [base];
    } else {
        for (d, ds, fs) in os.walk(base) {
            ds[:] = sorted(
                [
                    x
                    for x in ds
                    if not x.startswith(".") and x not in SKIP_DIRS
                ]
            );
            for f in sorted(fs) {
                if fnmatch.fnmatch(f, file_glob or "*") {
                    files.append(os.path.join(d, f));
                }
            }
        }
    }
    limit = max(int(max_results or 80), 1);
    hits: list[str] = [];
    for f in files {
        if self._cancel {
            return "error: cancelled";
        }
        try {
            with open(f, encoding="utf-8") as fh {
                for (i, ln) in enumerate(fh) {
                    if rx.search(ln) {
                        hits.append(f"{self.rel(f)}:{i + 1}: {ln.rstrip()[:200]}");
                        if len(hits) >= limit {
                            break;
                        }
                    }
                }
            }
        } except (OSError, UnicodeDecodeError) {
            continue;
        }
        if len(hits) >= limit {
            hits.append(f"... (stopped at {limit} results)");
            break;
        }
    }
    return "\n".join(hits) or "no matches";
}

impl NativeAgentSession.t_write_file(path: str, content: str) -> str {
    if self._cancel {
        return "error: cancelled";
    }
    if not self.inside(path) {
        return f"error: {path} is outside the project root";
    }
    failure = self.gate_write(path, content);
    if failure is not None {
        return f"rejected: {failure}";
    }
    full = self.resolve_path(path);
    if self.project_model is not None and full.endswith(".jac") {
        try {
            self.project_model.refresh(full);
        } except Exception {}
    }
    return f"ok: wrote {self.rel(full)} ({len(content.splitlines())} lines)";
}

impl NativeAgentSession.t_run_command(command: str, timeout_sec: int) -> str {
    if self._cancel {
        return "error: cancelled";
    }
    if not self.auto_approve_commands {
        rid = self.next_request_id("perm");
        self.expect(rid, "permission");
        self.emit(
            "permission",
            {
                "request_id": rid,
                "tool_call": {
                    "toolCallId": self._calls.get("run_command", ""),
                    "title": f"Run `{command}`",
                    "kind": "execute",
                    "rawInput": {"command": command}
                },
                "options": [
                    {"optionId": "allow", "name": "Run it", "kind": "allow_once"},
                    {
                        "optionId": "reject",
                        "name": "Don't run it",
                        "kind": "reject_once"
                    }
                ]
            }
        );
        choice = self.wait_answer(rid);
        if choice != "allow" {
            return "rejected: the user did not allow this command";
        }
    }
    tid = self.next_request_id("term");
    self.emit("terminal", {"terminal_id": tid, "command": command, "output": ""});
    try {
        proc = subprocess.Popen(
            command,
            shell=True,
            cwd=self.root_dir,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True
        );
    } except OSError as e {
        self.emit(
            "terminal",
            {"terminal_id": tid, "command": command, "output": str(e), "exit_code": 127}
        );
        return f"error: could not run the command: {e}";
    }
    self._procs.append(proc);
    buf: list[str] = [];
    stream: any = proc.stdout;
    def pump {
        while True {
            raw: bytes = stream.read1(4096);
            if not raw {
                break;
            }
            buf.append(raw.decode("utf-8", errors="replace"));
        }
    }
    reader = threading.Thread(target=pump, daemon=True);
    reader.start();
    limit = float(timeout_sec or self.command_timeout);
    deadline = time.time() + limit;
    timed_out = False;
    last_len = 0;
    while proc.poll() is None {
        if self._cancel or time.time() > deadline {
            timed_out = not self._cancel;
            try {
                os.killpg(proc.pid, SIGKILL);
            } except OSError {}
            break;
        }
        time.sleep(0.2);
        text = "".join(buf);
        if len(text) != last_len {
            last_len = len(text);
            self.emit(
                "terminal",
                {
                    "terminal_id": tid,
                    "command": command,
                    "output": text[-MAX_TOOL_OUTPUT:]
                }
            );
        }
    }
    code = proc.wait();
    reader.join(timeout=2);
    if proc in self._procs {
        self._procs.remove(proc);
    }
    output = "".join(buf);
    self.emit(
        "terminal",
        {
            "terminal_id": tid,
            "command": command,
            "output": output[-MAX_TOOL_OUTPUT:],
            "exit_code": code
        }
    );
    note = f" (killed after {int(limit)}s)" if timed_out else "";
    if len(output) > MAX_TOOL_OUTPUT {
        output = "... (output truncated)\n" + output[-MAX_TOOL_OUTPUT:];
    }
    return f"exit code {code}{note}\n{output}";
}

impl NativeAgentSession.t_find_symbol(query: str, kind: str) -> str {
    pm = self.model();
    kinds = [kind] if kind else None;
    hits = [
        h
        for h in pm.search(query, limit=25, kinds=kinds)
        if h.kind not in ["impl", "package"]
    ];
    if not hits {
        return f"no symbol matches {query!r}";
    }
    out: list[str] = [];
    for h in hits[:20] {
        sig = tidy_sig(getattr(h, "signature", "") or getattr(h, "type_str", ""));
        loc = f"{self.rel(h.file)}:{h.line}" if h.file else "external";
        out.append(f"{h.kind} {h.key}{sig_suffix(sig)}  [{loc}]");
    }
    return "\n".join(out);
}

impl NativeAgentSession.t_symbol_context(key: str) -> str {
    pm = self.model();
    resolved = resolve_key(pm, key);
    if not resolved {
        return f"error: no symbol or module matches {key!r}; try find_symbol";
    }
    if resolved.startswith(WIRE_PREFIX) {
        blk = context_block(pm, resolved);
        return blk["resource"]["text"] if blk else f"error: no wire {key!r}";
    }
    text = symbol_context(pm, resolved);
    if resolved != key {
        text = f"(closest match for {key!r})\n" + text;
    }
    return text;
}

impl NativeAgentSession.t_symbol_uses(name: str) -> str {
    short = name.split(".")[-1] if "." in name else name;
    try {
        refs = self.intel().references(short);
    } except Exception as e {
        return f"error: the compiler could not answer: {e}";
    }
    if not refs {
        return f"no definitions or uses of {short!r} found";
    }
    out: list[str] = [];
    for r in refs[:80] {
        out.append(f"{r.role} {self.rel(r.file)}:{r.line}");
    }
    if len(refs) > 80 {
        out.append(f"... ({len(refs) - 80} more)");
    }
    return "\n".join(out);
}

impl NativeAgentSession.t_insight(view: str, key: str) -> str {
    try {
        return insight_run(self.model(), view, key, True);
    } except ValueError as e {
        return f"error: {e}";
    }
}

impl NativeAgentSession.t_architecture(scope: str) -> str {
    pm = self.model();
    level = graph_level(pm, scope_for(pm, scope));
    return level_text(level, pm);
}

impl NativeAgentSession.t_archwire(module: str) -> str {
    pm = self.model();
    key = module if module in pm.modules else module_of(pm, module);
    if not key {
        hits = pm.search(module, limit=1, kinds=["module"]);
        key = hits[0].key if hits else "";
    }
    if not key {
        return f"error: no module matches {module!r}";
    }
    lines = [f"module {key}"];
    provs = pm.providers(key);
    cons = pm.consumers(key);
    lines.append(f"fed by ({len(provs)}):");
    lines.extend([wire_line(w, "from") for w in provs]);
    lines.append(f"feeds ({len(cons)}):");
    lines.extend([wire_line(w, "to") for w in cons]);
    rules = rule_lines(pm, key);
    if rules {
        lines.append("governed by:");
        lines.extend(rules);
    }
    return "\n".join(lines);
}

impl friendly_error(e: Exception, model_name: str) -> str {
    name = type(e).__name__;
    text = str(e);
    low = text.lower();
    if "Authentication" in name
        or "api key" in low
        or "api_key" in low
        or "no model configured" in low {
        return (
            f"The built-in agent cannot reach model '{model_name}': no usable API key. "
            "Set the provider's key (OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, ...), "
            "or choose another model with `[hack] model = \"...\"` in jac.toml or "
            "BYLLM_DEFAULT_MODEL."
        );
    }
    if isinstance(e, ImportError) {
        return (
            f"The built-in agent needs byllm's model client, which is not installed: {text}. "
            "Add [byllm] to jac.toml and run `jac install` to install it."
        );
    }
    if name in ["ModelNotFoundError", "NotFoundError"] or "model not found" in low {
        return f"Model '{model_name}' was not found by its provider: {text[:300]}";
    }
    if "RateLimit" in name {
        return f"Model '{model_name}' is rate limited: {text[:300]}";
    }
    first = text.strip().splitlines()[0] if text.strip() else "";
    return f"{name}: {first[:400]}";
}

impl tool_title(tool: str, args: any) -> str {
    if not isinstance(args, dict) {
        return tool;
    }
    for k in [
        "path",
        "command",
        "query",
        "key",
        "name",
        "module",
        "scope",
        "pattern"
    ] {
        if args.get(k) {
            val = " ".join(str(args[k]).split());
            return f"{tool} {val[:80]}";
        }
    }
    return tool;
}

impl tool_locations(args: any, root_dir: str) -> list[dict[str, any]] {
    if not isinstance(args, dict) or not args.get("path") {
        return [];
    }
    p = str(args["path"]);
    full = p if os.path.isabs(p) else os.path.join(root_dir, p);
    loc: dict[str, any] = {"path": os.path.normpath(full)};
    if args.get("start_line") {
        loc["line"] = args["start_line"];
    }
    return [loc];
}
