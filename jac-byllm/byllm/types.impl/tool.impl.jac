impl Tool.postinit() {
    annotations = get_type_hints(self.func);
    with suppress(Exception) {
        self.func.__annotations__ = annotations;
    }
    self.description = Tool.get_func_description(self.func);
    if hasattr(self.func, "_jac_semstr_inner") {
        self.params_desc = self.func._jac_semstr_inner;  # type: ignore
    } else {
        self.params_desc = {name: str(type) for (name, type) in annotations.items()};
    }
}

impl Tool.__call__( *args: list , **kwargs: dict) {
    # If there is an error with the finish tool, we throw the exception.
    # Since it's the user's responsibility to handle it.
    if self.is_finish_tool() {
        return self.func(*args, **kwargs);
    }
    try {
        # TODO: Shoud I json serialize or this is fine?
        return self.func(*args, **kwargs);
    } except Exception as e {
        # For the LLM if the tool failed, it'll see the error message
        # and make decision based on that.
        return str(e);
    }
}

impl Tool.get_name() {
    return self.func.__name__;
}

impl Tool.get_func_description(func: Callable) {
    if hasattr(func, "_jac_semstr") {
        return func._jac_semstr;  # type: ignore

    }
    return func.__doc__ or func.__name__;
}

impl Tool.make_finish_tool(resp_type: type) {
    def finish_tool(final_output: object) -> object {
        return TypeAdapter(resp_type).validate_python(final_output);
    }
    finish_tool.__annotations__["return"] = resp_type;
    finish_tool.__annotations__["final_output"] = resp_type;
    return Tool(
        func=finish_tool,
        description="This tool is used to finish the tool calls and return the final output.",
        params_desc={"final_output": "The final output of the tool calls.",},
    );
}

impl Tool.is_finish_tool() {
    return self.get_name() == "finish_tool";
}

impl Tool.get_json_schema() {
    return tool_to_schema(self.func, self.description, self.params_desc);
}

impl Tool.parse_arguments(args_json: dict) {
    args = {};
    annotations: dict = {};
    try {
        annotations = self.func.__annotations__;
    } except AttributeError {
        annotations = get_type_hints(self.func);
    }
    for (arg_name, arg_json) in args_json.items() {
        if arg_type := annotations.get(arg_name) {
            args[arg_name] = TypeAdapter(arg_type).validate_python(arg_json);
        }
    }
    return args;
}
