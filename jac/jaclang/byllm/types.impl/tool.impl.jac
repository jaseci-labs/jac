impl Tool.postinit -> None {
    try {
        annotations = get_type_hints(self.func);
    } except Exception {
        annotations = getattr(self.func, '__annotations__', {}) or {};
    }
    with suppress(Exception) {
        self.func.__annotations__ = annotations;
    }
    self.description = Tool.get_func_description(self.func);
    if self.func?._jac_semstr_inner {
        self.params_desc = self.func._jac_semstr_inner;
    } else {
        self.params_desc = {name: str(type) for (name, type) in annotations.items()};
    }

    if self.func?._serialize is not None {
        self.serialize = self.func._serialize;
    }
    if self.func?._timeout_sec is not None {
        self.timeout_sec = self.func._timeout_sec;
    }
}

impl Tool.__call__(*args: list, **kwargs: dict) -> object {
    if self.is_finish_tool() {
        try {
            return self.func(*args, **kwargs);
        } except FinishToolError {
            raise;
        } except Exception as e {
            raise FinishToolError(f"finish_tool failed: {e}");
        }
    }
    try {
        return self.func(*args, **kwargs);
    } except Exception as e {
        logger.warning("Tool %s failed: %s", self.get_name(), e);
        return f"Tool error: {e}";
    }
}

impl Tool.get_name -> str {
    return getattr(self.func, "__name__", type(self.func).__name__);
}

impl Tool.get_func_description(func: Callable) -> str {
    if func?._jac_semstr {
        return func._jac_semstr;
    }
    return func.__doc__ or func.__name__;
}

impl Tool.make_finish_tool(resp_type: type) -> Tool {
    def finish_tool(final_output: object) -> object {
        try {
            return TypeAdapter(resp_type).validate_python(final_output);
        } except Exception as e {
            raise FinishToolError(
                f"finish_tool output does not match expected type '{resp_type.__name__}': {e}"
            );
        }
    }
    finish_tool.__annotations__["return"] = resp_type;
    finish_tool.__annotations__["final_output"] = resp_type;
    return Tool(
        func=finish_tool,
        description="This tool is used to finish the tool calls and return the final output.",
        params_desc={"final_output": "The final output of the tool calls.",},
    );
}

impl Tool.is_finish_tool -> bool {
    return (
        self.get_name() == "finish_tool"
        and not getattr(self.func, "_is_error_tool", False)
    );
}

impl Tool.get_json_schema -> dict[str, object] {
    return tool_to_schema(self.func, self.description, self.params_desc, self.info);
}

impl Tool.parse_arguments(args_json: dict) -> dict {
    annotations: dict = {};
    try {
        annotations = self.func.__annotations__;
    } except AttributeError {
        annotations = get_type_hints(self.func);
    }
    params = {
        name: ty
        for (name, ty) in annotations.items()
        if name != "return"
    };
    if self.is_finish_tool() {
        if not isinstance(args_json, dict) {
            args_json = {"final_output": args_json};
        }
        return self._parse_finish_arguments(args_json, params);
    }
    if not isinstance(args_json, dict) {
        raise ValueError(
            f"tool '{self.get_name()}' arguments must be a JSON object; "
            f"got {type(args_json).__name__}"
        );
    }
    args = {};
    for (arg_name, arg_json) in args_json.items() {
        if arg_type := params.get(arg_name) {
            args[arg_name] = TypeAdapter(arg_type).validate_python(arg_json);
        }
    }
    missing = [
        name
        for name in self._required_params(params)
        if name not in args
    ];
    if missing {
        raise ValueError(
            f"missing required argument(s) {missing} for tool "
            f"'{self.get_name()}'; received argument name(s) "
            f"{list(args_json.keys())}"
        );
    }
    return args;
}

impl Tool._parse_finish_arguments(args_json: dict, params: dict) -> dict {
    resp_type = params.get("final_output", object);

    candidates: list = [];
    if "final_output" in args_json {
        candidates.append(args_json["final_output"]);
    } elif len(args_json) == 1 {
        candidates.append(list(args_json.values())[0]);
    }
    if args_json {
        candidates.append(args_json);
    }
    for candidate in candidates {
        try {
            return {"final_output": TypeAdapter(resp_type).validate_python(candidate)};
        } except Exception {
            continue;
        }
    }
    raise ValueError(
        "finish_tool requires a 'final_output' argument matching the declared "
        f"output schema; received argument name(s) {list(args_json.keys())}"
    );
}

impl Tool._required_params(params: dict) -> list {
    try {
        sig = inspect.signature(self.func);
    } except (TypeError, ValueError) {
        return list(params.keys());
    }
    required: list = [];
    for (name, param) in sig.parameters.items() {
        if (
            name in params
            and param.`default is inspect.Parameter.empty
            and param.kind
                in (
                    inspect.Parameter.POSITIONAL_OR_KEYWORD,
                    inspect.Parameter.KEYWORD_ONLY
                )
        ) {
            required.append(name);
        }
    }
    return required;
}
