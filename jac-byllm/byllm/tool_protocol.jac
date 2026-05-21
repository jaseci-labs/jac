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


"""Request-side tool-protocol injection.

Called from `BaseLLM.make_model_params` for backends that lack native tool
calling. Renders the tool schemas into the system prompt and removes the
structured `tools` / `tool_choice` params so the local backend's own (and
unreliable) tool template is not triggered. No-op when there are no tools.

When `tool_choice == "none"` the caller explicitly wants a pure-text reply
(byLLM's final-answer pass works this way): tools are dropped but the
protocol is NOT advertised, so the model is not tempted to emit another
tool call instead of the answer.
"""
def inject_tool_hint(params: dict) -> dict {
    tools = params.get("tools");
    msgs = params.get("messages");
    if not tools or not isinstance(tools, list) or not isinstance(msgs, list) {
        return params;
    }
    if params.get("tool_choice") == "none" {
        bare: dict = dict(params);
        bare.pop("tools", None);
        bare.pop("tool_choice", None);
        return bare;
    }
    block = format_tools_for_prompt(tools);
    if not block {
        return params;
    }
    out: dict = dict(params);
    out["messages"] = attach_tool_hint(msgs, block);
    out.pop("tools", None);
    out.pop("tool_choice", None);
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


"""Find the first JSON object in `content` that looks like a tool call.

Works whether the model wrapped the call in `<tool_call>` tags, a ```json
fence, or emitted bare JSON. When `tool_names` is non-empty, objects whose
name is not a real tool are skipped. Returns {name, arguments, raw, pos}.
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
                name = (
                    parsed.get("name") or parsed.get("tool") or parsed.get("function")
                );
                if (
                    isinstance(name, str)
                    and name
                    and (not tool_names or name in tool_names)
                ) {
                    args = (
                        parsed.get("arguments")
                        or parsed.get("parameters")
                        or parsed.get("args")
                        or {}
                    );
                    return {"name": name, "arguments": args, "raw": blob, "pos": i};
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


"""Response-side tool-call recovery.

Two jobs on an OpenAI-shaped reply dict: strip model-specific control tokens
(e.g. gemma's `<|channel>` reasoning markers) from the content, and -- when
the reply carries no structured `tool_calls` -- lift a tool call out of the
text into `message["tool_calls"]` in the same `SimpleNamespace` shape the
local connector's `wrap_tool_call` produces, so `BaseLLM.dispatch_*` consumes
it identically to a native tool call. Mutates `message` in place.
"""
def recover_tool_calls(message: object, tool_names: list[str] | None = None) -> None {
    if not isinstance(message, dict) {
        return;
    }
    names: list[str] = tool_names if tool_names is not None else [];
    content = message.get("content");
    if not isinstance(content, str) or not content {
        return;
    }
    # Normalise / strip control tokens some local models emit:
    #  - gemma renders quote characters inside tool calls as `<|"|>` tokens;
    #  - `<|channel>thought` reasoning headers and `<token|>` closers.
    stripped = content.replace("<|\"|>", "\"").replace("<|'|>", "'");
    stripped = re.sub("<\\|[a-z_]+>[a-z]*", "", stripped);
    stripped = re.sub("<[a-z_]+\\|>", "", stripped);
    if stripped != content {
        content = stripped;
        message["content"] = content;
    }
    if message.get("tool_calls") {
        return;  # already structured -- nothing more to do
    }
    call = _extract_first_tool_call(content, names);
    if call is None {
        return;
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
    message["tool_calls"] = [tool_call];
    # Strip the consumed tool-call JSON (and its envelope tags) from the
    # content so it does not resurface as a stray "thought" in the stream.
    raw = call.get("raw");
    if isinstance(raw, str) and raw {
        cleaned = str(content).replace(raw, "");
        for tag in ["<tool_call>", "</tool_call>", "<|tool_call|>", "```json", "```"] {
            cleaned = cleaned.replace(tag, "");
        }
        message["content"] = cleaned.strip();
    }
}
