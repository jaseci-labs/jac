"""Ink TUI entrypoint for `jac ai --tui` (compiled via jac_super.ink_compile).

Uses SSE streaming via `agent_stream` (same transport as `jac ai --ui`)
instead of periodic `agent_poll` HTTP requests.  The stream delivers a full
snapshot on connect, then incremental event deltas; the TUI upserts them
into `displayEvents` by id and renders them in a single transcript panel
with tool rows highlighted via background color.  One-shot RPC endpoints
(send/reset/stop/settings) remain request/response over `agent_fetch`.
If the stream disconnects, the loop backs off 800 ms and reconnects."""
import from os { environ }

cl import from react { useEffect }
cl import from "ink" { Box, Text, useApp, useInput }
cl import from "ink-text-input" { default as TextInput }

glob TUI_CWD: str = str(environ.get("JAC_TUI_CWD") or ""),
     BASE: str = str(environ.get("JAC_TUI_API_URL") or ""),
     _streamCtrl: any = None,
     _unmounted: bool = False,
     feedSinceId: int = 0,
     toolSeq: int = 1,
     toolLabelByEvent: dict = {},
     resultLabelByEvent: dict = {},
     displayEvents: list[any] = [],
     activeToolLabel: str = "",
     TUI_COMMANDS: list[str] = [
         "/help",
         "/model",
         "/mode",
         "/context-max",
         "/verbose",
         "/feedback",
         "/stats",
         "/usage",
         "/guides",
         "/mcp",
         "/stop",
         "/reset",
         "/clear",
         "/exit"
     ];

cl {
    def fetchTimeoutMs -> int {
        # One-shot RPC timeout (seconds). Override with JAC_TUI_FETCH_TIMEOUT.
        timeout_s = 120.0;
        raw = str(environ.get("JAC_TUI_FETCH_TIMEOUT") or "").strip();
        if raw {
            try {
                timeout_s = float(raw);
            } except Exception { }
        }
        if timeout_s < 1.0 {
            timeout_s = 1.0;
        }
        return int(timeout_s * 1000.0);
    }

    async def agent_fetch(endpoint: str, body: any = None) -> any {
        if body is None {
            body = {};
        }
        try {
            response: any = await fetch(
                BASE + "/function/" + endpoint,
                {
                    "method": "POST",
                    "headers": {"Content-Type": "application/json"},
                    "body": JSON.stringify(body),
                    "signal": AbortSignal.timeout(fetchTimeoutMs())
                }
            );
            text: str = str(await response.text());
            payload: any = JSON.parse(text);
            # Jac function routes return a transport envelope like
            # `{ok, type, data: {result, reports}, error, meta}`. Unwrap that
            # here so the rest of the TUI can read the actual endpoint result
            # directly.
            data = payload.get("data", None) if payload else None;
            if data is not None {
                result = data.get("result", None);
                if result is not None {
                    return result;
                }
            }
            return payload;
        } except Exception {
            # compile.py patches this catch to also tolerate native fetch errors.
            return {"ok": False, "error": "agent server unreachable"};
        }
    }

    async def send(prompt: str) -> bool {
        # Use `is True` — error envelopes are truthy objects in JS.
        return (await agent_fetch("agent_send", {"prompt": prompt})) is True;
    }

    async def reset -> bool {
        return (await agent_fetch("agent_reset")) is True;
    }

    async def stop -> bool {
        return (await agent_fetch("agent_stop")) is True;
    }

    async def settings -> any {
        return await agent_fetch("agent_settings");
    }

    async def applySettings(
        model: str,
        apiKey: str = "",
        baseUrl: str = "",
        temperature: str = "",
        nCtx: str = ""
    ) -> any {
        return await agent_fetch(
            "agent_apply_settings",
            {
                "model": model,
                "api_key": apiKey,
                "base_url": baseUrl,
                "temperature": temperature,
                "n_ctx": nCtx
            }
        );
    }

    async def runtimeConfig -> any {
        return await agent_fetch("agent_runtime_config");
    }

    async def applyMode(mode: str) -> any {
        return await agent_fetch("agent_apply_mode", {"mode": mode});
    }

    async def toggleVerboseServer -> any {
        return await agent_fetch("agent_toggle_verbose");
    }

    async def toggleFeedbackServer -> any {
        return await agent_fetch("agent_toggle_feedback");
    }

    async def toggleStatsServer -> any {
        return await agent_fetch("agent_toggle_stats");
    }

    async def fetchGuides -> any {
        return await agent_fetch("agent_guides");
    }

    async def mcpStatus -> any {
        return await agent_fetch("agent_mcp_status");
    }

    def actionResultMessage(result: any, fallback: str) -> str {
        return str(result.get("message", "") or result.get("error", "") or fallback);
    }

    def resetFeedState {
        global feedSinceId,toolSeq,toolLabelByEvent,resultLabelByEvent;
        global displayEvents,activeToolLabel;
        feedSinceId = 0;
        toolSeq = 1;
        toolLabelByEvent = {};
        resultLabelByEvent = {};
        displayEvents = [];
        activeToolLabel = "";
    }

    def toolLabelFor(eventId: int) -> str {
        global toolSeq,toolLabelByEvent;
        if eventId in toolLabelByEvent {
            return str(toolLabelByEvent[eventId]);
        }
        lab = "#" + str(toolSeq);
        toolSeq += 1;
        toolLabelByEvent[eventId] = lab;
        return lab;
    }

    def eventToDisplayRow(ev: any, eid: int, creating: bool) -> any {
        kind = str(ev.get("kind", "") or "");
        text = str(ev.get("text", "") or "");
        if kind == "status" {
            return None;
        }
        row: any = {
            "id": eid,
            "kind": kind,
            "text": text,
            "node": str(ev.get("node", "") or "")
        };
        if kind == "call" {
            node_name = str(ev.get("node", "") or "phase");
            tin = int(ev.get("tokens_in", 0) or 0);
            tout = int(ev.get("tokens_out", 0) or 0);
            model_name = str(ev.get("model", "") or "");
            msg = "Call > " + node_name + "  in/out=" + str(tin) + "/" + str(tout);
            if model_name {
                msg += "  model=" + model_name;
            }
            row["kind"] = "system";
            row["text"] = msg;
        } elif kind == "phase" {
            phase_node = str(ev.get("node", "") or "");
            if not phase_node {
                return None;
            }
            row["kind"] = "system";
            row["text"] = "Phase > " + phase_node;
        } elif kind == "tool" {
            tlab = toolLabelFor(eid);
            global activeToolLabel;
            activeToolLabel = tlab;
            row["text"] = "Tool " + tlab + " > " + text;
        } elif kind == "tool_result" {
            global resultLabelByEvent;
            rlab = str(resultLabelByEvent.get(eid, "") or "");
            if not rlab {
                rlab = activeToolLabel;
                if not rlab {
                    rlab = "#" + str(max(1, toolSeq - 1));
                }
                resultLabelByEvent[eid] = rlab;
            }
            row["text"] = "Result " + rlab + " > " + text;
        } elif kind == "answer" and not text and creating {
            return None;
        } elif not text and creating {
            return None;
        }
        return row;
    }

    def processPollEvents(rawEvents: list[any]) -> list[any] {
        global feedSinceId,displayEvents;
        byId: dict = {};
        for row in displayEvents {
            rid = int(row.get("id", 0) or 0);
            if rid > 0 {
                byId[rid] = row;
            }
        }
        for ev in rawEvents {
            eid = int(ev.get("id", 0) or 0);
            if eid <= 0 {
                continue;
            }
            if eid > feedSinceId {
                feedSinceId = eid;
            }
            if eid in byId {
                # Streaming reasoning/answer events grow in place on the server;
                # upsert the latest text (same pattern as the web UI SSE handler).
                fresh = eventToDisplayRow(ev, eid, False);
                if fresh is not None and fresh["text"] {
                    byId[eid]["text"] = fresh["text"];
                }
                continue;
            }
            row = eventToDisplayRow(ev, eid, True);
            if row is None {
                continue;
            }
            byId[eid] = row;
            displayEvents.append(row);
        }
        return list(displayEvents);
    }

    def tui_parse_command(line: str) -> tuple[str, str] {
        text = str(line or "").strip();
        if not text.startswith("/") {
            return ("", "");
        }
        if " " not in text {
            return (text, "");
        }
        i = text.find(" ");
        return (text[:i], text[i + 1:].strip());
    }

    def commandListLine -> str {
        return ", ".join(list(TUI_COMMANDS));
    }

    def eventColor(kind: str) -> str {
        if kind == "answer" {
            return "green";
        }
        if kind == "tool" or kind == "tool_result" {
            return "yellow";
        }
        if kind == "reasoning" {
            return "blue";
        }
        if kind == "error" {
            return "red";
        }
        if kind == "user" {
            return "cyan";
        }
        return "dim";
    }

    def eventLabel(kind: str) -> str {
        if kind == "tool_result" {
            return "result";
        }
        if kind {
            return kind;
        }
        return "info";
    }

    def eventText(ev: any) -> str {
        kind = str(ev.get("kind", "") or "");
        text = str(ev.get("text", "") or "");
        if text {
            return text;
        }
        if kind == "call" {
            node_name: str = str(ev.get("node", "") or "phase");
            tokens_in: int = int(ev.get("tokens_in", 0) or 0);
            tokens_out: int = int(ev.get("tokens_out", 0) or 0);
            return node_name + " in/out=" + str(tokens_in) + "/" + str(tokens_out);
        }
        if kind == "phase" {
            return str(ev.get("node", "") or "phase");
        }
        return "";
    }

    def takeTail(items: list[any], limit: int) -> list[any] {
        if limit <= 0 {
            return [];
        }
        if len(items) <= limit {
            return items;
        }
        return items[len(items) - limit:];
    }

    def Banner(cwd: str, model: str) -> JsxElement {
        return (
            <Box marginBottom={1} flexDirection="column">
                <Box>
                    <Text bold color="magenta">jac</Text>
                    <Text bold color="cyan">.ai</Text>
                    <Text> </Text>
                    <Text dimColor>{cwd}</Text>
                    <Text> </Text>
                    <Text color="yellow">{model or "model: unknown"}</Text>
                </Box>
            </Box>
        );
    }

    def StatusBar(
        status: str, active: str, phase: str, model: str, path: list[str]
    ) -> JsxElement {
        spinner: str = "o";
        if status == "running" {
            spinner = "*";
        }
        color: str = "dim";
        if status == "done" {
            color = "green";
        } elif status == "running" {
            color = "cyan";
        } elif status == "stopping" {
            color = "yellow";
        } elif status == "error" {
            color = "red";
        }
        pathText = "";
        if path {
            pathText = " | " + " -> ".join(path);
        }
        return (
            <Box marginBottom={1} flexDirection="column">
                <Box>
                    <Text color={color}>{spinner} {status}</Text>
                    <Text>  </Text>
                    <Text dimColor>{active or phase or "ready"}</Text>
                    <Text>  </Text>
                    <Text color="yellow">{model or "unknown model"}</Text>
                </Box>
                {pathText and <Text dimColor>{pathText}</Text>}
            </Box>
        );
    }

    def StatsLine(stats: any, settingsData: any, showDetails: bool) -> JsxElement {
        tokens_in = int(stats.get("tokens_in", 0) or 0);
        tokens_out = int(stats.get("tokens_out", 0) or 0);
        tools = int(stats.get("tools", 0) or 0);
        errors = int(stats.get("errors", 0) or 0);
        warnings = int(stats.get("warnings", 0) or 0);
        if not showDetails {
            return (
                <Box marginBottom={1}>
                    <Text dimColor>
                        tokens {tokens_in}/{tokens_out} | tools {tools} | health {errors}e/{warnings}w
                    </Text>
                </Box>
            );
        }
        ctx = int(settingsData.get("n_ctx", 0) or 0);
        temp = float(settingsData.get("temperature", -1.0) or -1.0);
        elapsed = float(stats.get("elapsed", 0.0) or 0.0);
        tokPerS = float(stats.get("tok_per_s", 0.0) or 0.0);
        contextText = "default";
        if ctx > 0 {
            contextText = str(ctx);
        }
        tempText = "default";
        if temp >= 0.0 {
            tempText = str(temp);
        }
        return (
            <Box marginBottom={1} flexDirection="column">
                <Text dimColor>
                    tokens {tokens_in}/{tokens_out} | tools {tools} | health {errors}e/{warnings}w
                </Text>
                <Text dimColor>
                    elapsed {elapsed}s | tok/s {tokPerS} | context {contextText} | temp {tempText}
                </Text>
            </Box>
        );
    }

    def Transcript(events: list[any]) -> JsxElement {
        transcript = takeTail(events, 12);
        if not transcript {
            return (
                <Box flexDirection="column" marginBottom={1}>
                    <Text dimColor>No events yet.</Text>
                </Box>
            );
        }
        return (
            <Box flexDirection="column" marginBottom={1}>
                {transcript.map(
                    lambda (ev: any) -> any {
                        kind = str(ev.get("kind", "") or "");
                        text = eventText(ev);
                        if not text {
                            return None;
                        }
                        color = eventColor(kind);
                        label = eventLabel(kind);
                        isToolBg = kind == "tool" or kind == "tool_result";
                        if isToolBg {
                            return (
                                <Box backgroundColor="gray">
                                    <Text color={color}>{label}: {text}</Text>
                                </Box>
                            );
                        }
                        return <Text color={color}>{label}: {text}</Text>;
                    }
                )}
            </Box>
        );
    }

    def UsagePanel(visible: bool, stats: any, settingsData: any) -> JsxElement {
        if not visible {
            return <Box/>;
        }
        hasRun = bool(stats.get("has_run", False));
        if not hasRun {
            return (
                <Box flexDirection="column" marginTop={1}>
                    <Text bold color="cyan">Usage</Text>
                    <Text dimColor>No completed turn yet.</Text>
                </Box>
            );
        }
        return (
            <Box flexDirection="column" marginTop={1}>
                <Text bold color="cyan">Usage</Text>
                <Text dimColor>
                    tokens in/out: {int(stats.get("tokens_in", 0) or 0)}/{int(
                        stats.get("tokens_out", 0) or 0
                    )}
                </Text>
                <Text dimColor>
                    throughput: {float(stats.get("tok_per_s", 0.0) or 0.0)} tok/s
                </Text>
                <Text dimColor>cost: {float(stats.get("cost", 0.0) or 0.0)}</Text>
                <Text dimColor>
                    reads/writes/runs/files: {int(stats.get("reads", 0) or 0)}/{int(
                        stats.get("writes", 0) or 0
                    )}/{int(stats.get("runs", 0) or 0)}/{int(
                        stats.get("files", 0) or 0
                    )}
                </Text>
                <Text dimColor>ctx max: {int(settingsData.get("n_ctx", 0) or 0)}</Text>
            </Box>
        );
    }

    def InfoPanel(title: str, lines: list[str]) -> JsxElement {
        if not title and not lines {
            return <Box/>;
        }
        return (
            <Box flexDirection="column" marginTop={1}>
                <Text bold color="cyan">{title or "Info"}</Text>
                {[<Text dimColor>{line}</Text> for line in takeTail(lines, 8)]}
            </Box>
        );
    }

    def InputBar(draft: str, onChange: any, onSubmit: any) -> JsxElement {
        return (
            <Box borderStyle="single" borderColor="gray" paddingLeft={1}>
                <Text color="cyan">&gt; </Text>
                <TextInput value={draft} onChange={onChange} onSubmit={onSubmit}/>
            </Box>
        );
    }

    def HelpOverlay(visible: bool) -> JsxElement {
        if not visible {
            return <Box/>;
        }
        return (
            <Box marginTop={1} flexDirection="column">
                <Text bold color="cyan">Commands</Text>
                <Text dimColor>{commandListLine()}</Text>
                <Text dimColor>/model [name|#] to inspect or switch models</Text>
                <Text dimColor>/mode [safe|yolo] to inspect or change approvals</Text>
                <Text dimColor>
                    /context-max [n] to inspect or update the context cap
                </Text>
                <Text dimColor>/verbose and /feedback toggle agent display flags</Text>
                <Text dimColor>
                    /stats toggles per-turn stats; /usage shows usage panel
                </Text>
                <Text dimColor>
                    /guides lists bundled reference guides; /mcp shows MCP status
                </Text>
            </Box>
        );
    }

    def applyMsg(msg: any, setters: any) -> None {
        if msg.get("heartbeat", False) {
            return;
        }
        if msg.get("full", False) {
            global displayEvents,feedSinceId;
            displayEvents = [];
            feedSinceId = 0;
            raw_events = list(msg.get("events", []) or []);
            setters["setEvents"](processPollEvents(raw_events));
        } elif msg.get("ev", None) is not None {
            ev = msg.get("ev", None);
            setters["setEvents"](processPollEvents([ev]));
        }
        setters["setStatus"](str(msg.get("status", "idle") or "idle"));
        setters["setActive"](str(msg.get("active", "") or ""));
        setters["setModel"](str(msg.get("model_name", "") or ""));
        path_val = list(msg.get("path", []) or []);
        phase_val = str(msg.get("active", "") or "");
        if not phase_val and path_val {
            phase_val = str(path_val[-1] or "");
        }
        setters["setPhase"](phase_val);
        setters["setNeedsKey"](bool(msg.get("needs_key", False) or False));
        setters["setKeyEnv"](str(msg.get("key_env", "") or ""));
        setters["setStats"](msg.get("stats", {}) or {"has_run": False});
        setters["setPath"](path_val);
    }

    async def streamLoop(setters: any) {
        global _streamCtrl,_unmounted;
        _unmounted = False;
        while not _unmounted {
            _streamCtrl = new(AbortController);
            try {
                resp = await fetch(
                    BASE + "/function/agent_stream",
                    {
                        "method": "POST",
                        "headers": {"Content-Type": "application/json"},
                        "body": "{}",
                        "signal": _streamCtrl.signal
                    }
                );
                if resp.body is not None {
                    reader = resp.body.getReader();
                    dec = new(TextDecoder);
                    nl = String.fromCharCode(10);
                    sep = nl + nl;
                    buf = "";
                    while True {
                        chunk = await reader.read();
                        if chunk.done {
                            break;
                        }
                        buf = buf + dec.decode(chunk.value, {"stream": True});
                        parts = buf.split(sep);
                        buf = parts[len(parts) - 1];
                        i = 0;
                        while i < len(parts) - 1 {
                            data = "";
                            for line in parts[i].split(nl) {
                                if len(line) >= 5 and line[:5] == "data:" {
                                    data = data + line[5:].strip();
                                }
                            }
                            if data {
                                try {
                                    applyMsg(JSON.parse(data), setters);
                                } except Exception { }
                            }
                            i += 1;
                        }
                    }
                }
            } except Exception {
            # compile.py patches this catch to also tolerate SSE disconnects.
            }
            if _unmounted {
                break;
            }
            await new(Promise, lambda resolve: any { setTimeout(resolve, 800); });
        }
    }

    def stopStream {
        global _streamCtrl,_unmounted;
        _unmounted = True;
        if _streamCtrl is not None {
            _streamCtrl.abort();
        }
    }

    def setInfo(actions: any, title: str, lines: list[str]) {
        actions["setInfoTitle"](title);
        actions["setInfoLines"](lines);
    }

    async def refreshSettings(actions: any) -> any {
        try {
            current = await settings();
            actions["setSettings"](current or {});
            return current or {};
        } except Exception {
            return {};
        }
    }

    async def handleSubmit(line: str, actions: any) -> None {
        text = str(line or "").strip();
        if not text {
            return;
        }
        (cmd, arg) = tui_parse_command(text);
        if cmd == "/help" {
            actions["toggleHelp"]();
            return;
        }
        if cmd == "/usage" {
            actions["toggleUsage"]();
            return;
        }
        if cmd == "/mode" and not arg {
            cfg = await runtimeConfig();
            mode = str(cfg.get("mode", "") or "unknown");
            yolo = bool(cfg.get("yolo_mode", False));
            lines: list[str] = ["mode: " + mode, "yolo: " + ("on" if yolo else "off")];
            setInfo(actions, "Mode", lines);
            return;
        }
        if cmd == "/mode" and arg {
            result = await applyMode(arg);
            setInfo(
                actions,
                "Mode" if bool(result.get("ok", False)) else "Error",
                [actionResultMessage(result, "mode update failed")]
            );
            return;
        }
        if cmd == "/verbose" {
            result = await toggleVerboseServer();
            setInfo(
                actions, "Verbose", [actionResultMessage(result, "verbose toggled")]
            );
            return;
        }
        if cmd == "/feedback" {
            result = await toggleFeedbackServer();
            setInfo(
                actions, "Feedback", [actionResultMessage(result, "feedback toggled")]
            );
            return;
        }
        if cmd == "/stats" {
            result = await toggleStatsServer();
            setInfo(actions, "Stats", [actionResultMessage(result, "stats toggled")]);
            return;
        }
        if cmd == "/guides" {
            guides = list(await fetchGuides() or []);
            lines: list[str] = [];
            for g in guides {
                name = str(g.get("name", "") or "");
                desc = str(g.get("description", "") or "");
                if name {
                    if desc {
                        lines.append(name + " — " + desc);
                    } else {
                        lines.append(name);
                    }
                }
            }
            if not lines {
                lines = ["No guides found."];
            }
            setInfo(actions, "Guides", lines);
            return;
        }
        if cmd == "/mcp" {
            status = await mcpStatus();
            title = "MCP";
            if bool(status.get("available", False)) {
                title = "MCP (available)";
            }
            setInfo(
                actions,
                title,
                [str(status.get("message", "") or "jac-mcp status unknown")]
            );
            return;
        }
        if cmd == "/clear" {
            resetFeedState();
            actions["clear"]();
            actions["clearDraft"]();
            setInfo(actions, "", []);
            return;
        }
        if cmd == "/stop" {
            await stop();
            actions["setStatus"]("stopping");
            setInfo(actions, "Info", ["Stop requested."]);
            return;
        }
        if cmd == "/reset" {
            await reset();
            actions["clear"]();
            actions["clearDraft"]();
            setInfo(actions, "Info", ["Session reset."]);
            return;
        }
        if cmd == "/model" and not arg {
            currentSettings = await refreshSettings(actions);
            lines: list[str] = [
                "current: " + str(currentSettings.get("model", "") or "")
            ];
            presets = list(currentSettings.get("presets", []) or []);
            if presets {
                idx = 1;
                for preset in presets {
                    lines.append(str(idx) + ". " + str(preset));
                    idx += 1;
                }
            }
            setInfo(actions, "Models", lines);
            return;
        }
        if cmd == "/model" and arg {
            currentSettings = await refreshSettings(actions);
            nextModel = str(arg or "").strip();
            if nextModel.isdigit() {
                presets2 = list(currentSettings.get("presets", []) or []);
                idx2 = int(nextModel);
                if idx2 <= 0 or idx2 > len(presets2) {
                    setInfo(actions, "Error", ["invalid preset index"]);
                    return;
                }
                nextModel = str(presets2[idx2 - 1]);
            }
            applied = await applySettings(
                nextModel, "", "", "", str(int(currentSettings.get("n_ctx", 0) or 0))
            );
            if bool(applied.get("ok", False)) {
                actions["setModel"](str(applied.get("model", nextModel) or nextModel));
                await refreshSettings(actions);
                setInfo(
                    actions,
                    "Models",
                    ["switched to " + str(applied.get("model", nextModel) or nextModel)]
                );
            } else {
                setInfo(
                    actions, "Error", [str(applied.get("error", "model update failed"))]
                );
            }
            return;
        }
        if cmd == "/context-max" and not arg {
            currentSettings = await refreshSettings(actions);
            setInfo(
                actions,
                "Context",
                ["current: " + str(int(currentSettings.get("n_ctx", 0) or 0))]
            );
            return;
        }
        if cmd == "/context-max" and arg {
            rawN = str(arg or "").strip();
            if not rawN or not rawN.isdigit() {
                setInfo(actions, "Error", ["usage: /context-max <int>"]);
                return;
            }
            currentSettings = await refreshSettings(actions);
            appliedCtx = await applySettings(
                str(currentSettings.get("model", "") or ""), "", "", "", rawN
            );
            if bool(appliedCtx.get("ok", False)) {
                await refreshSettings(actions);
                setInfo(actions, "Context", ["set to " + rawN]);
            } else {
                setInfo(
                    actions,
                    "Error",
                    [str(appliedCtx.get("error", "context update failed"))]
                );
            }
            return;
        }
        if cmd == "/exit" or cmd == "/quit" {
            actions["exit"]();
            return;
        }
        if cmd {
            setInfo(actions, "Error", ["unknown command: " + text]);
            return;
        }
        sent = False;
        try {
            sent = await send(text);
        } except Exception {
            setInfo(actions, "Error", ["failed to send — server may be restarting"]);
            return;
        }
        if sent {
            actions["clearDraft"]();
            setInfo(actions, "", []);
        } else {
            setInfo(actions, "Busy", ["wait for the active turn or stop it first"]);
        }
    }

    def:pub app -> JsxElement {
        has status: str = "idle",
            active: str = "",
            phase: str = "",
            model: str = "",
            events: list[any] = [],
            stats: any = {"has_run": False},
            settingsData: any = {},
            path: list[str] = [],
            draft: str = "",
            showHelp: bool = False,
            showUsage: bool = False,
            showStats: bool = False,
            needsKey: bool = False,
            keyEnv: str = "",
            infoTitle: str = "",
            infoLines: list[str] = [];

        appCtl: any = useApp();

        def clearView {
            events = [];
        }

        def clearDraft {
            draft = "";
        }

        def toggleHelp {
            showHelp = not showHelp;
        }

        def toggleUsage {
            showUsage = not showUsage;
        }

        def toggleStats {
            showStats = not showStats;
        }

        def exitApp {
            appCtl.exit();
        }

        actions = {
            "toggleHelp": toggleHelp,
            "toggleUsage": toggleUsage,
            "toggleStats": toggleStats,
            "clear": clearView,
            "setStatus": lambda (value: str) { status = value; },
            "setModel": lambda (value: str) { model = value; },
            "setSettings": lambda (value: any) { settingsData = value or {}; },
            "setInfoTitle": lambda (value: str) { infoTitle = value; },
            "setInfoLines": lambda (value: any) { infoLines = list(value or []); },
            "exit": exitApp,
            "clearDraft": clearDraft
        };

        useEffect(
            lambda {
                stream_setters = {
                    "setStatus": lambda (value: str) { status = value; },
                    "setActive": lambda (value: str) { active = value; },
                    "setModel": lambda (value: str) { model = value; },
                    "setPhase": lambda (value: str) { phase = value; },
                    "setEvents": lambda (value: any) { events = list(value or []); },
                    "setNeedsKey": lambda (value: bool) { needsKey = value; },
                    "setKeyEnv": lambda (value: str) { keyEnv = value; },
                    "setStats": lambda (value: any) { stats = value
                    or {"has_run": False}; },
                    "setPath": lambda (value: any) { path = list(value or []); }
                };
                streamLoop(stream_setters);
                async def boot {
                    await refreshSettings(actions);
                    initial_prompt = str(
                        environ.get("JAC_TUI_INITIAL_PROMPT") or ""
                    ).strip();
                    if initial_prompt {
                        try {
                            await send(initial_prompt);
                        } except Exception { }
                    }
                }
                boot();
                return lambda { stopStream(); };
            },
            []
        );

        useInput(
            lambda (input: str, key: any) {
                if key.escape {
                    exitApp();
                    return;
                }
                if key.ctrl and input == "l" {
                    toggleHelp();
                    return;
                }
            }
        );

        async def submit(line: str) {
            await handleSubmit(line, actions);
        }

        return (
            <Box flexDirection="column" padding={1}>
                {Banner(TUI_CWD, model)}
                {StatusBar(status, active, phase, model, path)}
                {StatsLine(stats, settingsData, showStats)}
                <Box flexDirection="column" flexGrow={1}>
                    <Text bold color="cyan">Transcript</Text>
                    {Transcript(events)}
                </Box>
                {(<Text color="yellow">Missing API key: {keyEnv}</Text>)
                    if needsKey
                    else None}
                {InputBar(draft, lambda (value: str) { draft = value; }, submit)}
                {HelpOverlay(showHelp)}
                {UsagePanel(showUsage, stats, settingsData)}
                {InfoPanel(infoTitle, infoLines)}
            </Box>
        );
    }
}
