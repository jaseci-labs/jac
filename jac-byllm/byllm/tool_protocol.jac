"""Tool-call normalisation for backends without native tool calling.

Frontier cloud providers (OpenAI, Anthropic, Gemini) accept a `tools=` list
and do two things server-side: render the tools into the prompt, and parse the
model's reply back into a structured `tool_calls` field. byllm's local route
(in-process llama.cpp) gets neither -- the GGUF's own chat template renders
tools inconsistently and llama-cpp's generic handler leaves the model's
tool-call text sitting in `content`, so the ReAct loop sees zero tool calls.

This module is the tool-call counterpart of `schema.inject_schema_hint`: byllm
owns the protocol on both ends instead of reverse-engineering each model's
native format.

  - `inject_tool_hint`  -- request side: render the tool schemas and a strict,
                           byllm-defined call protocol into the system message,
                           and drop the structured `tools` field so the local
                           backend's unreliable native template is not engaged.
  - `recover_tool_calls` -- response side: when a reply carries no structured
                           `tool_calls`, lift a tool call back out of the
                           message content into the OpenAI-shaped field the
                           ReAct loop already consumes.

Both are gated by `BaseLLM.supports_native_tools`, so the cloud/litellm path is
left completely untouched.
"""

import json;
import re;
import uuid;
import from types { SimpleNamespace }

# Marker used to keep `inject_tool_hint` idempotent within a single request.
glob _TOOL_PROTOCOL_HEADER = "# Calling tools";

#===============================================================================
# REQUEST SIDE -- render tools + protocol into the prompt
#===============================================================================
"""Render one OpenAI tool-schema dict into a compact prompt description."""
def _render_tool(tool: object) -> str {
    if not isinstance(tool, dict) {
        return "";
    }
    fn = tool.get("function", {});
    if not isinstance(fn, dict) {
        return "";
    }
    name = str(fn.get("name", "") or "");
    if not name {
        return "";
    }
    desc = str(fn.get("description", "") or "");
    params = fn.get("parameters", {}) or {};
    props = params.get("properties", {}) if isinstance(params, dict) else {};
    required = params.get("required", []) if isinstance(params, dict) else [];
    if not isinstance(props, dict) {
        props = {};
    }
    if not isinstance(required, list) {
        required = [];
    }
    lines: list[str] = [f"- {name}: {desc}"];
    for (pname, pinfo) in props.items() {
        ptype = "any";
        pdesc = "";
        if isinstance(pinfo, dict) {
            ptype = str(pinfo.get("type", "any") or "any");
            pdesc = str(pinfo.get("description", "") or "");
        }
        flag = " (required)" if pname in required else "";
        lines.append(f"    - {pname} [{ptype}]{flag}: {pdesc}");
    }
    return "\n".join(lines);
}


"""Build the full tool-use protocol block from a list of tool schemas."""
def format_tools_for_prompt(tools: list) -> str {
    rendered: list[str] = [];
    for tool in tools {
        block = _render_tool(tool);
        if block {
            rendered.append(block);
        }
    }
    if not rendered {
        return "";
    }
    return (
        _TOOL_PROTOCOL_HEADER + "\n\nYou can call tools. The tools available to you are:\n\n" + "\n".join(
            rendered
        ) + "\n\nTo call a tool, reply with ONLY a tool call in exactly this " + "form and nothing else:\n\n" + "<tool_call>{\"name\": \"<tool_name>\", \"arguments\": {<args>}}</tool_call>" + "\n\nRules:\n" + "- Call exactly one tool per reply.\n" + "- \"arguments\" must be a JSON object whose keys match the tool's " + "parameters.\n" + "- Emit nothing outside the <tool_call> tags when calling a tool.\n" + "- After a tool result is returned, call the next tool, or call " + "finish_tool with your final answer to end."
    );
}


"""Append `block` to the first system message; prepend one when none exists.

Returns a new list -- the caller's input is not mutated. Idempotent: a second
call within the same request detects the protocol header and is a no-op.
"""
def attach_tool_hint(messages: list, block: str) -> list {
    out: list = list(messages);
    sys_idx = -1;
    idx = 0;
    for raw in out {
        if isinstance(raw, dict) and raw.get("role") == "system" {
            sys_idx = idx;
            break;
        }
        idx += 1;
    }
    if sys_idx < 0 {
        result: list = [{"role": "system", "content": block}];
        result.extend(out);
        return result;
    }
    target_raw = out[sys_idx];
    if not isinstance(target_raw, dict) {
        return messages;
    }
    # byllm always builds system messages with plain string content; skip
    # injection for any other shape rather than risk corrupting it.
    body = target_raw.get("content", "");
    if not isinstance(body, str) {
        return messages;
    }
    body_text = str(body);
    if _TOOL_PROTOCOL_HEADER in body_text {
        return messages;  # already injected -- idempotent
    }
    target: dict = dict(target_raw);
    target["content"] = body_text.rstrip() + "\n\n" + block;
    out[sys_idx] = target;
    return out;
}


"""Read an attribute off a value that may be a dict or an object."""
def _field(val: object, key: str) -> object {
    if isinstance(val, dict) {
        return val.get(key);
    }
    return getattr(val, key, None);
}


"""Pull (name, arguments-dict) out of one tool-call, dict or object shaped.

Handles the OpenAI native shape (`function.name`/`function.arguments`), the
`SimpleNamespace` shape `recover_tool_calls` produces, and a flat
`{name, arguments}` dict. Arguments arrive as a JSON string or a dict; both
normalise to a dict.
"""
def _tool_call_name_args(tc: object) -> tuple[str, dict] {
    fn = _field(tc, "function");
    name = _field(tc, "name") or _field(fn, "name");
    raw_args = _field(tc, "arguments") or _field(fn, "arguments");
    args: dict = {};
    if isinstance(raw_args, dict) {
        args = raw_args;
    } elif isinstance(raw_args, str) and raw_args {
        try {
            decoded = json.loads(raw_args);
            args = decoded if isinstance(decoded, dict) else {};
        } except Exception {
            args = {};
        }
    }
    return (str(name or ""), args);
}


"""Linearise tool-call and tool-result messages into plain user/assistant text.

Models without a tool-aware chat template (the in-process GGUFs, and ollama
families such as gemma whose template has no `tool` role) silently drop
`role:"tool"` result messages and mis-render assistant `tool_calls` -- so a
ReAct loop feeds them an answer they never see and they re-issue the same call
forever. This rewrites the transcript into the exact text shape the protocol
advertises: an assistant `tool_calls` message becomes the `<tool_call>{...}</tool_call>`
text the model itself would emit, and a tool result becomes a `<tool_response>`
the model reads as ordinary user input. The structured history is untouched;
only the about-to-be-sent copy is linearised.
"""
def linearize_tool_messages(messages: list) -> list {
    out: list = [];
    for m in messages {
        # A tool result: identified by tool_call_id (set only on ToolCallResultMsg).
        if _field(m, "tool_call_id") is not None {
            name = str(_field(m, "name") or "tool");
            content = _field(m, "content");
            out.append(
                {
                    "role": "user",
                    "content": f"<tool_response>{name} -> {content}</tool_response>"
                }
            );
            continue;
        }
        tool_calls = _field(m, "tool_calls");
        if tool_calls {
            text = str(_field(m, "content") or "").strip();
            parts: list = [text] if text else [];
            for tc in tool_calls {
                (name, args) = _tool_call_name_args(tc);
                if not name {
                    continue;
                }
                call_json = json.dumps({"name": name, "arguments": args});
                parts.append(f"<tool_call>{call_json}</tool_call>");
            }
            out.append({"role": "assistant", "content": "\n".join(parts)});
            continue;
        }
        out.append(m);
    }
    return out;
}


"""Request-side tool-protocol injection.

Called from `BaseLLM.make_model_params` for backends that lack native tool
calling. Renders the tool schemas into the system prompt, linearises any prior
tool-call/result messages into text the model can read, and removes the
structured `tools` / `tool_choice` params so the backend's own (and unreliable)
tool template is not triggered. No-op when there are no tools.

When `tool_choice == "none"` the caller explicitly wants a pure-text reply
(byLLM's final-answer pass works this way): tools are dropped but the
protocol is NOT advertised, so the model is not tempted to emit another
tool call instead of the answer. The transcript is still linearised so any
tool results already in history remain readable.
"""
def inject_tool_hint(params: dict) -> dict {
    tools = params.get("tools");
    msgs = params.get("messages");
    if not isinstance(msgs, list) {
        return params;
    }
    if params.get("tool_choice") == "none" {
        bare: dict = dict(params);
        bare["messages"] = linearize_tool_messages(msgs);
        bare.pop("tools", None);
        bare.pop("tool_choice", None);
        return bare;
    }
    if not tools or not isinstance(tools, list) {
        return params;
    }
    block = format_tools_for_prompt(tools);
    if not block {
        return params;
    }
    out: dict = dict(params);
    out["messages"] = attach_tool_hint(linearize_tool_messages(msgs), block);
    out.pop("tools", None);
    out.pop("tool_choice", None);
    # Halt generation at the end of the first tool call. Without it, weaker
    # open-weight models run past `</tool_call>` and hallucinate an entire
    # multi-turn transcript -- fabricated tool results and follow-up calls --
    # in a single reply, which derails the ReAct loop. A hard stop forces one
    # call per turn so the loop feeds back real results.
    out["stop"] = _merge_stop(out.get("stop"), ["</tool_call>"]);
    return out;
}


"""Merge protocol stop strings with any the caller already set, de-duped."""
def _merge_stop(existing: object, extra: list[str]) -> list[str] {
    out: list[str] = [];
    if isinstance(existing, str) and existing {
        out.append(existing);
    } elif isinstance(existing, list) {
        for s in existing {
            if isinstance(s, str) and s {
                out.append(s);
            }
        }
    }
    for s in extra {
        if s not in out {
            out.append(s);
        }
    }
    return out;
}

#===============================================================================
# RESPONSE SIDE -- recover tool calls from message content
#===============================================================================
"""Return the balanced `open_ch..close_ch` substring starting at `start`.

Tracks nesting depth while respecting `"`/`'` string literals so brackets
inside strings do not throw off the count. Returns None when unbalanced.
"""
def _balanced(text: str, start: int, open_ch: str, close_ch: str) -> str | None {
    depth = 0;
    in_str = False;
    quote = "";
    escaped = False;
    i = start;
    while i < len(text) {
        ch = text[i];
        if in_str {
            if escaped {
                escaped = False;
            } elif ch == "\\" {
                escaped = True;
            } elif ch == quote {
                in_str = False;
            }
        } else {
            if ch == "\"" or ch == "'" {
                in_str = True;
                quote = ch;
            } elif ch == open_ch {
                depth += 1;
            } elif ch == close_ch {
                depth -= 1;
                if depth == 0 {
                    return text[start:i + 1];
                }
            }
        }
        i += 1;
    }
    return None;
}


"""Pull a {name, arguments} pair out of one call-shaped object, or None.

Small models are wildly inconsistent in how they key a tool call, so accept
the common spellings: name via `name`/`tool`/`tool_name`/`function` (the last
either a plain name string or a nested `{"name", "arguments"}` object), and
arguments via `arguments`/`parameters`/`args`/`tool_args`/`input`.
"""
def _call_fields(cobj: object) -> dict | None {
    if not isinstance(cobj, dict) {
        return None;
    }
    func = cobj.get("function");
    name: object = cobj.get("name") or cobj.get("tool") or cobj.get("tool_name");
    args: object = (
        cobj.get("arguments")
        or cobj.get("parameters")
        or cobj.get("args")
        or cobj.get("tool_args")
        or cobj.get("input")
    );
    # `function` is a plain name string in some shapes, a nested
    # `{"name", "arguments"}` object (OpenAI native) in others.
    if isinstance(func, dict) {
        name = name or func.get("name");
        args = (
            args or func.get("arguments") or func.get("args") or func.get("parameters")
        );
    } elif isinstance(func, str) {
        name = name or func;
    }
    if isinstance(name, str) and name {
        return {"name": name, "arguments": args or {}};
    }
    return None;
}


"""Find the first JSON object in `content` that looks like a tool call.

Works whether the model wrapped the call in `<tool_call>` tags, a ```json
fence, or emitted bare JSON, and whether the call is a flat
`{"name", "arguments"}` object or sits inside a `{"tool_calls": [...]}` /
`{"tool_call": {...}}` envelope (the shape ollama-served models stream as
text). When `tool_names` is non-empty, objects whose name is not a real tool
are skipped. Returns {name, arguments, raw, pos}.
"""
def _extract_json_call(content: str, tool_names: list) -> dict | None {
    i = 0;
    while i < len(content) {
        if content[i] == "{" {
            blob = _balanced(content, i, "{", "}");
            if blob is None {
                return None;
            }
            parsed: object = None;
            try {
                parsed = json.loads(blob);
            } except Exception {
                parsed = None;
            }
            if isinstance(parsed, dict) {
                # Unwrap a `tool_calls`/`tool_call` envelope; otherwise treat the
                # object itself as the candidate call.
                wrapped = parsed.get("tool_calls") or parsed.get("tool_call");
                candidates: list = [];
                if isinstance(wrapped, list) {
                    candidates = wrapped;
                } elif isinstance(wrapped, dict) {
                    candidates = [wrapped];
                } else {
                    candidates = [parsed];
                }
                for cand in candidates {
                    if not isinstance(cand, dict) {
                        continue;
                    }
                    fields = _call_fields(cand);
                    if fields is None {
                        continue;
                    }
                    name = str(fields.get("name"));
                    if not tool_names or name in tool_names {
                        return {
                            "name": name,
                            "arguments": fields.get("arguments"),
                            "raw": blob,
                            "pos": i
                        };
                    }
                }
            }
            i += len(blob);
            continue;
        }
        i += 1;
    }
    return None;
}


"""Split a function-argument string on its top-level commas.

Commas inside quotes or nested brackets are not treated as separators.
"""
def _split_top_level(text: str) -> list[str] {
    parts: list[str] = [];
    buf = "";
    depth = 0;
    in_str = False;
    quote = "";
    escaped = False;
    for ch in text {
        if in_str {
            buf += ch;
            if escaped {
                escaped = False;
            } elif ch == "\\" {
                escaped = True;
            } elif ch == quote {
                in_str = False;
            }
        } elif ch == "\"" or ch == "'" {
            in_str = True;
            quote = ch;
            buf += ch;
        } elif ch in "([{" {
            depth += 1;
            buf += ch;
        } elif ch in ")]}" {
            depth -= 1;
            buf += ch;
        } elif ch == "," and depth == 0 {
            parts.append(buf);
            buf = "";
        } else {
            buf += ch;
        }
    }
    if buf.strip() {
        parts.append(buf);
    }
    return parts;
}


"""Parse one argument value token: JSON literal, quoted string, or bare word."""
def _parse_value(token: str) -> object {
    t = token.strip();
    if not t {
        return "";
    }
    try {
        return json.loads(t);
    } except Exception { }
    if len(t) >= 2 and t[0] == "'" and t[-1] == "'" {
        return t[1:-1];
    }
    return t;
}


"""Parse a `key=value`/`key: value`, ... argument string into a dict.

Accepts both `=` and `:` separators -- small models use either depending on
whether they think they are writing a call or an object literal.
"""
def _parse_kwargs(argstr: str) -> dict {
    out: dict = {};
    for part in _split_top_level(argstr) {
        m = re.match("\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*[:=]\\s*", part);
        if m is None {
            continue;
        }
        out[m.group(1)] = _parse_value(part[m.end():]);
    }
    return out;
}


"""Find the first `tool_name(...)` or `tool_name{...}` call in `content`.

Only call expressions whose name is in `tool_names` are accepted, so prose
or code snippets that merely mention a function are not misread as a call.
Small models emit both paren and brace forms, so both are scanned.
Returns {name, arguments, raw, pos} or None.
"""
def _extract_paren_call(content: str, tool_names: list) -> dict | None {
    for m in re.finditer("([A-Za-z_][A-Za-z0-9_]*)\\s*([\\(\\{])", content) {
        name = m.group(1);
        if name not in tool_names {
            continue;
        }
        open_ch = m.group(2);
        close_ch = ")" if open_ch == "(" else "}";
        open_idx = m.end() - 1;
        argblob = _balanced(content, open_idx, open_ch, close_ch);
        if argblob is None {
            continue;
        }
        return {
            "name": name,
            "arguments": _parse_kwargs(argblob[1:-1]),
            "raw": content[m.start():open_idx + len(argblob)],
            "pos": m.start()
        };
    }
    return None;
}


"""Find the first tool call in `content`, in JSON or paren-call form.

Small open-weight models are inconsistent -- the same turn may use a JSON
`<tool_call>` envelope for one tool and `finish_tool(arg=...)` paren syntax
for another -- so both forms are scanned and the earliest one wins.
"""
def _extract_first_tool_call(content: str, tool_names: list) -> dict | None {
    json_call = _extract_json_call(content, tool_names);
    paren_call = _extract_paren_call(content, tool_names);
    if json_call is None {
        return paren_call;
    }
    if paren_call is None {
        return json_call;
    }
    json_pos = int(json_call.get("pos") or 0);
    paren_pos = int(paren_call.get("pos") or 0);
    return json_call if json_pos <= paren_pos else paren_call;
}


"""Coerce a reply message (litellm `Message` object or dict) to a plain dict.

The cloud/litellm non-streaming path hands back a `Message` *object*, while the
in-process and streaming paths build plain dicts. Normalising to a dict here
lets the whole text tool protocol operate on one shape and -- crucially -- lets
`recover_tool_calls` write `tool_calls` back in a form the ReAct loop reads.
"""
def coerce_message_dict(message: object) -> dict {
    if isinstance(message, dict) {
        return message;
    }
    out: dict = {"role": _field(message, "role") or "assistant"};
    out["content"] = _field(message, "content");
    tc = _field(message, "tool_calls");
    if tc {
        out["tool_calls"] = tc;
    }
    return out;
}


"""Response-side tool-call recovery.

Two jobs on an OpenAI-shaped reply: strip model-specific control tokens (e.g.
gemma's `<|channel>` reasoning markers) from the content, and -- when the reply
carries no structured `tool_calls` -- lift a tool call out of the text into
`tool_calls` in the same `SimpleNamespace` shape the local connector's
`wrap_tool_call` produces, so `BaseLLM.dispatch_*` consumes it identically to a
native tool call.

Accepts either a dict or a litellm `Message` object, normalises to a dict, and
returns it -- callers must use the return value, since an object input cannot be
mutated into the dict the ReAct loop expects.
"""
def recover_tool_calls(message: object, tool_names: list[str] | None = None) -> dict {
    msg: dict = coerce_message_dict(message);
    names: list[str] = tool_names if tool_names is not None else [];
    content = msg.get("content");
    if not isinstance(content, str) or not content {
        return msg;
    }
    # Normalise / strip control tokens some local models emit:
    #  - gemma renders quote characters inside tool calls as `<|"|>` tokens;
    #  - `<|channel>thought` reasoning headers and `<token|>` closers.
    stripped = content.replace("<|\"|>", "\"").replace("<|'|>", "'");
    stripped = re.sub("<\\|[a-z_]+>[a-z]*", "", stripped);
    stripped = re.sub("<[a-z_]+\\|>", "", stripped);
    if stripped != content {
        content = stripped;
        msg["content"] = content;
    }
    if msg.get("tool_calls") {
        return msg;  # already structured -- nothing more to do
    }
    call = _extract_first_tool_call(content, names);
    if call is None {
        return msg;
    }
    args_raw = call.get("arguments");
    args: dict = {};
    if isinstance(args_raw, dict) {
        args = args_raw;
    } elif isinstance(args_raw, str) {
        try {
            decoded = json.loads(args_raw);
            if isinstance(decoded, dict) {
                args = decoded;
            }
        } except Exception {
            args = {};
        }
    }
    tool_call = SimpleNamespace(
        id="call_" + uuid.uuid4().hex[:12],
        type="function",
        function=SimpleNamespace(name=str(call["name"]), arguments=json.dumps(args))
    );
    msg["tool_calls"] = [tool_call];
    # Strip the consumed tool-call JSON (and its envelope tags) from the
    # content so it does not resurface as a stray "thought" in the stream.
    raw = call.get("raw");
    if isinstance(raw, str) and raw {
        cleaned = str(content).replace(raw, "");
        for tag in ["<tool_call>", "</tool_call>", "<|tool_call|>", "```json", "```"] {
            cleaned = cleaned.replace(tag, "");
        }
        msg["content"] = cleaned.strip();
    }
    return msg;
}
