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
        for (key, value) in args.items() {
            idx = list(args.keys()).index(key);
            if isinstance(value, Media) {
                media_inputs.append((value, params[idx].semstr or ""));
                continue;
            }

            if isinstance(key, str) {
                inputs_detail.append(f"{key} = {(value, params[idx].semstr or "")}");
            } else {
                # TODO: Handle *args, **kwargs properly.
                if key < len(params) {
                    inputs_detail.append(
                        f"{params[key].name} = {(value, params[idx].semstr or "")}"
                    );
                } else {
                    inputs_detail.append(f"arg = {(value, params[idx].semstr or "")}");
                }
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

    # Conversational mode: `by llm(conversation=<list>)` splices the
    # caller's prior conversation between SYSTEM and USER. Entries on input
    # may be Messages or dicts; write-back always emits dicts.
    conv_arg = call_params.get("conversation");
    conv_msgs: list[MessageType] = [];
    conv_list_ref: object = None;
    if isinstance(conv_arg, list) {
        conv_list_ref = conv_arg;
        for item in conv_arg {
            m: Any = item;
            if isinstance(m, Message) {
                conv_msgs.append(m);
            } elif isinstance(m, dict) {
                reconstructed: Any = Message.from_dict(m);
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
    if is_streaming and return_type is not str {
        raise ConfigurationError(
            "Streaming responses are only supported for str return types."
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

"""Build the parameter dict for the LLM API call."""
impl MTRuntime.dispatch_params -> dict[str, object] {
    params = {
        "messages": self.get_msg_list(),
        "tools": self.get_tool_list() or None,
        "response_format": self.get_output_schema(),
        "temperature": self.call_params.get("temperature", 0.7),
        # "max_tokens": self.call_params.get("max_tokens", 100),
        # "top_k": self.call_params.get("top_k", 50),
        # "top_p": self.call_params.get("top_p", 0.9),
    };
    return params;
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
        m: Any = msg;
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
def _is_finish_tool_call(tc: Any) -> bool {
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
    if len(self.tools) == 0 and self.resp_type {
        if self.resp_type is str {
            return None;  # Strings are default and not using a schema.

        }
        # Use MTIR info if available, otherwise None (Python library mode)
        return_type_info = self.mtir.ir_info.return_type
            if (self.mtir and self.mtir.ir_info)
            else None;
        return type_to_schema(resp_type=self.resp_type, info=return_type_info);
    }
    # If the are tools, the final output will be sent to the finish_tool
    # thus there is no output schema.
    return None;
}
