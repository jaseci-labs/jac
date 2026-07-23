glob SYSTEM_PERSONA = """\
    This is a task you must complete by returning only the output.
    Do not include explanations, code, or extra text—only the result.
    """,
     INSTRUCTION_TOOL = """
    Use the tools provided to reach the goal. Call one tool at a time with \
    proper args—no explanations, no narration. Think step by step, invoking tools \
    as needed. When done, always call finish_tool(output) to return the final
    output. Only use tools.
    """;

"""Render a human-readable definition of an enum/obj input *value*.

Mirrors the semantic detail the OUTPUT schema carries -- the type-level
semstring plus each member/field semstring -- pulled from the runtime
`_jac_semstr` / `_jac_semstr_inner` attributes. Returns "" for primitives;
recurses one level into nested enum/obj fields (bounded by `_depth`).
"""
def _describe_input_type(value: object, _depth: int = 0) -> str {
    import from enum { Enum }
    import from dataclasses { is_dataclass, fields as _dc_fields }
    if _depth > 2 {
        return "";
    }
    pad = "    " * (_depth + 1);
    if isinstance(value, Enum) {
        ty = type(value);
        tsem = getattr(ty, "_jac_semstr", "") or "";
        msem = getattr(ty, "_jac_semstr_inner", {}) or {};
        rows = [f"{pad}{ty.__name__} (enum)" + (f" -- {tsem}" if tsem else "")];
        for m in ty {
            d = msem.get(m.name, "");
            rows.append(f"{pad}  - {m.name} = {m.value!r}" + (f": {d}" if d else ""));
        }
        return "\n".join(rows);
    }
    if is_dataclass(value) and not isinstance(value, type) {
        ty = type(value);
        tsem = getattr(ty, "_jac_semstr", "") or "";
        fsem = getattr(ty, "_jac_semstr_inner", {}) or {};
        rows = [f"{pad}{ty.__name__} (obj)" + (f" -- {tsem}" if tsem else "")];
        for f in _dc_fields(ty) {
            if f.name.startswith("_") {
                continue;
            }
            d = fsem.get(f.name, "");
            tyname = f.type?.__name__ or str(f.type);
            rows.append(f"{pad}  - {f.name} ({tyname})" + (f": {d}" if d else ""));
            fval = getattr(value, f.name, None);
            if isinstance(fval, Enum)
            or (is_dataclass(fval) and not isinstance(fval, type)) {
                nested = _describe_input_type(fval, _depth + 2);
                if nested {
                    rows.append(nested);
                }
            }
        }
        return "\n".join(rows);
    }
    return "";
}

"""Create an MTRuntime instance from a callable and its arguments.

Builds the message history with system persona, user input, and any media.
Prepares tools including the finish_tool for ReAct-style interactions.
"""
impl MTRuntime.factory(mtir: MTIR) -> MTRuntime {
    # Prepare the tools for the LLM call.
    caller = mtir.caller;
    args = mtir.args;
    call_params = mtir.call_params;
    ir_info = mtir.ir_info;
    # Warn and remove deprecated 'method' parameter.
    if "method" in call_params {
        import warnings;
        warnings.warn(
            "'method' parameter is deprecated and has no effect. "
            "For tool usage, just pass tools=[...] directly to by llm().",
            DeprecationWarning,
            stacklevel=2
        );
        del call_params["method"];
    }
    # Check if we have MTIR info (Jac mode) or need runtime introspection (Python lib mode)
    has_mtir = ir_info is not None;
    # Prepare tools with or without MTIR info
    raw_tools = call_params.get("tools", []);
    tools = [];
    local_idx = 0;
    for func in raw_tools {
        # Already tool-like (e.g., McpTool) — pass through unchanged.
        if func?.get_json_schema and func?.get_name and func?.is_finish_tool {
            tools.append(func);
            continue;
        }
        if has_mtir {
            info = ir_info.tools[local_idx] if local_idx < len(ir_info.tools) else None;
            tools.append(Tool(func, info=info));  # type: ignore
        } else {
            tools.append(Tool(func));  # type: ignore
        }
        local_idx += 1;
    }
    # Construct the input information from the arguments.
    inputs_detail: list[str] = [];
    media_inputs: list = [];  # Can be list[Media] or list[tuple[Media, str]] depending on mode
    if has_mtir {
        # MTIR mode: use compile-time extracted param info with semantic strings
        params = [param for param in ir_info.params];
        arg_keys = list(args.keys());
        # The parameter's own `sem fn.arg` lives on the callable at runtime,
        # keyed by name. Prefer it over the MTIR param semstr, which is
        # shadowed by the type-level sem for enum/obj params.
        caller_psems = getattr(caller, "_jac_semstr_inner", {}) or {};
        for (key, value) in args.items() {
            idx = arg_keys.index(key);
            # Resolve the parameter name for this argument.
            if isinstance(key, str) {
                pname = key;
            } elif key < len(params) {
                # TODO: Handle *args, **kwargs properly.
                pname = params[key].name;
            } else {
                pname = "arg";
            }
            mtir_sem = params[idx].semstr if idx < len(params) else "";
            psem = caller_psems.get(pname) or mtir_sem or "";
            if isinstance(value, Media) {
                media_inputs.append((value, psem));
                continue;
            }
            inputs_detail.append(f"{pname} = {(value, psem)}");
            # For enum/obj inputs, append the full type definition (type-level
            # sem + per-member/field sems) so the model gets the same semantic
            # detail the OUTPUT schema carries. Primitives yield "".
            desc = _describe_input_type(value);
            if desc {
                inputs_detail.append(desc);
            }
        }
    } else {
        # Python library mode: use runtime introspection (old behavior)
        param_names = list(inspect.signature(caller).parameters.keys());
        for (key, value) in args.items() {
            if isinstance(value, Media) {
                # Use tuple format for consistency, but without semantic strings
                media_inputs.append((value, ""));
                continue;
            }

            if isinstance(key, str) {
                inputs_detail.append(f"{key} = {value}");
            } else {
                # TODO: Handle *args, **kwargs properly.
                if key < len(param_names) {
                    inputs_detail.append(f"{param_names[key]} = {value}");
                } else {
                    inputs_detail.append(f"arg = {value}");
                }
            }
        }
    }
    incl_info = call_params.get("incl_info");
    if incl_info and isinstance(incl_info, dict) {
        for (key, value) in incl_info.items() {
            if isinstance(value, Media) {
                # Always use tuple format for consistency
                media_inputs.append((value, ""));
            } else {
                if has_mtir {
                    inputs_detail.append(f"{key} = {(value, "")}");
                } else {
                    inputs_detail.append(f"{key} = {value}");
                }
            }
        }
    }
    if isinstance(caller, MethodType) {
        if has_mtir {
            inputs_detail.insert(
                0,
                f"self = {(
                    caller.__self__,
                    ir_info.parent_class.semstr if ir_info.parent_class else ''
                )}"
            );
        } else {
            inputs_detail.insert(0, f"self = {caller.__self__}");
        }
    }
    # System prompt: Config from jac.toml or default SYSTEM_PERSONA
    system_content = SYSTEM_PERSONA;
    try {
        import from jaclang.project.config { find_project_root }
        import from pathlib { Path }

        # Get the file path of the caller's module
        caller_file = inspect.getfile(caller);
        project_root_result = find_project_root(Path(caller_file).parent);
        project_dir = project_root_result[0] if project_root_result else None;

        config_system_prompt = get_byllm_config(project_dir).get_system_prompt();
        if config_system_prompt {
            system_content = config_system_prompt;
        }
    } except Exception { }

    # `by llm(system_prompt=...)` extends base. Accepts str or zero-arg callable.
    call_system_prompt = call_params.get("system_prompt");
    if callable(call_system_prompt) {
        try {
            call_system_prompt = call_system_prompt();
        } except Exception {
            call_system_prompt = None;
        }
    }
    if call_system_prompt {
        system_content += "\n\n" + str(call_system_prompt);
    }

    # Conversational mode: `by llm(conversation=<list>)` splices the
    # caller's prior conversation between SYSTEM and USER. Entries on input
    # may be Messages or dicts; write-back always emits dicts.
    conv_arg = call_params.get("conversation");
    conv_msgs: list[MessageType] = [];
    conv_list_ref: object = None;
    if isinstance(conv_arg, list) {
        conv_list_ref = conv_arg;
        for item in conv_arg {
            m: any = item;
            if isinstance(m, Message) {
                conv_msgs.append(m);
            } elif isinstance(m, dict) {
                reconstructed: any = Message.from_dict(m);
                conv_msgs.append(reconstructed);
            } else {
                conv_msgs.append(m);
            }
        }
    }

    # Prepare the messages for the LLM call.
    sys_msg = Message(
        role=MessageRole.SYSTEM,
        content=system_content + (INSTRUCTION_TOOL if tools else ""),
    );
    user_msg = Message(
        role=MessageRole.USER,
        content=[
            Text(Tool.get_func_description(caller) + "\n\n" + "\n".join(inputs_detail)),
            *media_inputs,

        ],
    );
    messages: list[MessageType] = [sys_msg, *conv_msgs, user_msg];

    # Prepare return type.
    return_type = get_type_hints(caller).get("return");
    is_streaming = bool(call_params.get("stream", False));
    if is_streaming
    and return_type is not str
    and call_params.get("stream_handler") is None {
        raise ConfigurationError(
            "Streaming responses are only supported for str return types. "
            "Pass a stream_handler to receive stream events for a structured "
            "return type (e.g. `visit [-->] by model(stream=True, "
            "stream_handler=fn)`)."
        );
    }
    if len(tools) > 0 {
        finish_tool = Tool.make_finish_tool(return_type or str);
        tools.append(finish_tool);
    }
    mt_run = MTRuntime(
        messages=messages,
        tools=tools,
        resp_type=return_type,
        stream=is_streaming,
        call_params=call_params,
        mtir=mtir
    );

    # In conversational mode, the auto-SYSTEM is regenerated from sem each
    # turn — exclude it from persistence and bind the caller's list for
    # write-back.
    if conv_list_ref is not None {
        mt_run._scaffolding_ids.append(id(sys_msg));
        mt_run._conversation_list = conv_list_ref;
    }

    return mt_run;
}

"""Add a message to the conversation history."""
impl MTRuntime.add_message(message: MessageType) -> None {
    self.messages.append(message);
}


impl MTRuntime.add_scaffolding_message(message: MessageType) -> None {
    self.messages.append(message);
    self._scaffolding_ids.append(id(message));
}

"""Return the messages in a format suitable for LLM API."""
impl MTRuntime.get_msg_list -> list[dict[str, object] | LiteLLMMessage] {
    return [
        msg.to_dict() if isinstance(msg, Message) else msg for msg in self.messages
    ];
}


impl MTRuntime.write_back_conversation -> None {
    if self._conversation_list is None {
        return;
    }
    out: list = [];
    for msg in self.get_history_for_persist() {
        m: any = msg;
        if hasattr(m, "to_dict") {
            out.append(m.to_dict());
        } elif isinstance(m, dict) {
            out.append(dict(m));
        } elif hasattr(m, "model_dump") {
            try {
                out.append(m.model_dump());
            } except Exception {
                out.append({"raw": str(m)});
            }
        }
    }
    self._conversation_list[:] = out;
}


# Test against finish_tool both at object level and dict level.
def _is_finish_tool_call(tc: any) -> bool {
    if tc?.function and hasattr(tc.function, "name") {
        return tc.function.name == "finish_tool";
    }
    if isinstance(tc, dict) {
        return (tc.get("function") or {}).get("name", "") == "finish_tool";
    }
    return False;
}


impl MTRuntime.get_history_for_persist -> list[MessageType] {
    scaff_ids = set(self._scaffolding_ids);
    out: list = [];
    for msg in self.messages {
        if id(msg) in scaff_ids {
            continue;
        }
        # Skip non-Message artifacts (e.g. MockLLM raw strings).
        if not (
            isinstance(msg, Message)
            or isinstance(msg, dict)
            or hasattr(msg, "to_dict")
            or hasattr(msg, "model_dump")
        ) {
            continue;
        }
        if isinstance(msg, ToolCallResultMsg) and msg.name == "finish_tool" {
            continue;
        }
        tool_calls = msg?.tool_calls;
        if tool_calls is None and isinstance(msg, dict) {
            tool_calls = msg.get("tool_calls");
        }
        if tool_calls and all(_is_finish_tool_call(tc) for tc in tool_calls) {
            continue;
        }
        out.append(msg);
    }
    return out;
}

"""Parse the LLM response string into the expected return type."""
impl MTRuntime.parse_response(response: str) -> object {
    # To use validate_json the string should contains quotes.
    #     example: '"The weather at New York is sunny."'
    # but the response from LLM will not have quotes, so
    # we need to check if it's string and return early.
    if self.resp_type is None or self.resp_type is str or response.strip() == "" {
        return response;
    }
    if self.resp_type {
        try {
            json_dict = json.loads(response);
            return json_to_instance(json_dict, self.resp_type);
        } except OutputConversionError {
            raise;
        } except Exception as e {
            err = OutputConversionError(
                f"Failed to convert LLM output to '{self.resp_type.__name__}': {e}"
            );
            err.raw_output = response;
            raise err;
        }
    }
    return response;
}

"""Get a tool by name. Works for both Tool and McpTool."""
impl MTRuntime.get_tool(tool_name: str) -> Tool | McpTool | None {
    for tool in self.tools {
        if tool.get_name() == tool_name {
            return tool;
        }
    }
    return None;
}

"""Return the tools as JSON schemas for the LLM API."""
impl MTRuntime.get_tool_list -> list[dict] {
    return [tool.get_json_schema() for tool in self.tools];
}

"""Return the JSON schema for the response type, if applicable."""
impl MTRuntime.get_output_schema -> dict | None {
    assert (
        len(self.tools) == 0 or self.get_tool("finish_tool") is not None
    );  #Finish tool should be present in the tools list.
    if len(self.tools) == 0 {
        return self.get_typed_output_schema();
    }
    # If the are tools, the final output will be sent to the finish_tool
    # thus there is no output schema.
    return None;
}

"""Return the JSON schema for the structured return type, even with tools present.

Unlike get_output_schema, not suppressed when tools exist (used for retry feedback).
"""
impl MTRuntime.get_typed_output_schema -> dict | None {
    if self.resp_type is None or self.resp_type is str {
        # No structured schema: str is the default and not schema-driven.
        return None;
    }
    # Use MTIR info if available, otherwise None (Python library mode)
    return_type_info = self.mtir.ir_info.return_type
        if (self.mtir and self.mtir.ir_info)
        else None;
    return type_to_schema(resp_type=self.resp_type, info=return_type_info);
}

impl MTIR.runtime.getter -> MTRuntime {
    return MTRuntime.factory(self);
}
