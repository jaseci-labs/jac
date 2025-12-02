#-------------------------------------------------------------------------------
# Message Implementations
#-------------------------------------------------------------------------------
impl Message.to_dict() {
    if isinstance(self.content, str) {
        return {"role": self.role.value, "content": self.content,};
    }
    media_contents = [];
    for media in self.content {
        media_contents.extend(media.to_dict());
        return {"role": self.role.value, "content": media_contents,};
    }
}

#-------------------------------------------------------------------------------
# ToolCallResult Implementations
#-------------------------------------------------------------------------------
impl ToolCallResult.postinit() {
    self.role = MessageRole.TOOL;  # Maybe this should be an assertion?
}

impl ToolCallResult.to_dict() {
    return {
        "role": self.role.value,
        "content": self.content,
        "tool_call_id": self.tool_call_id,
        "name": self.name,

    };
}

#-------------------------------------------------------------------------------
# Tool Implementations
#-------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------
# ToolCall Implementations
#-------------------------------------------------------------------------------
impl ToolCall.__call__() {
    if self.args is not None {
        result = self.tool(**self.args);
    } else {
        raise ValueError("args is None, Expected a dictionary") ;
    }
    return ToolCallResultMsg(
        role=MessageRole.TOOL,
        content=str(result),
        tool_call_id=self.call_id,
        name=self.tool.get_name(),
    );
}

impl ToolCall.__str__() {
    params = ", ".join(f"{k}={v}" for (k, v) in self.args.items());
    return f"{self.tool.get_name()}({params})";
}

impl ToolCall.is_finish_call() {
    return self.tool.is_finish_tool();
}

impl ToolCall.get_output() {
    assert (self.is_finish_call()) , "This method should only be called for finish tools.";
    return self.tool(**self.args);
}

#-------------------------------------------------------------------------------
# MockToolCall Implementations
#-------------------------------------------------------------------------------
impl MockToolCall.to_tool_call() {
    args_parsed = Tool(self.tool).parse_arguments(self.args);
    return ToolCall(
        call_id="",  # Call ID is not used in mock calls.
        tool=Tool(self.tool),
        args=args_parsed,
    );
}

#-------------------------------------------------------------------------------
# Media Implementations
#-------------------------------------------------------------------------------
impl Media.to_dict() {
    raise NotImplementedError("Subclasses must implement this method.") ;
}

#-------------------------------------------------------------------------------
# Text Implementations
#-------------------------------------------------------------------------------
impl Text.to_dict() {
    return [{"type": "text", "text": self.text}];
}

#-------------------------------------------------------------------------------
# Image Implementations
#-------------------------------------------------------------------------------
impl Image.postinit() {
    value = self.url;
    # Handle path-like inputs by converting to string
    if isinstance(value, os.PathLike) {
        value = os.fspath(value);
    }
    # Remote or data URLs: keep as-is (trim whitespace)
    if isinstance(value, str) {
        s = value.strip();
        if s.startswith(("http://", "https://", "gs://", "data:")) {
            self.url = s;
            return;
        }
        # Treat as local file path
        if not os.path.exists(s) {
            raise ValueError(f"Image file does not exist: {s}") ;
        }
        image = open_image(s);
        fmt = image.format or "PNG";
        # Determine MIME type with WEBP special-case for py<3.13
        self.mime_type = self._format_to_mime(fmt);
        with BytesIO() as buffer {
            image.save(buffer, format=fmt);
            data = buffer.getvalue();
            self.url = self._data_url_from_bytes(data, fmt);
            return;
        }
    }
    # PIL Image instance
    if isinstance(value, PILImageCls) {
        fmt = value.format or "PNG";
        with BytesIO() as buffer {
            value.save(buffer, format=fmt);
            data = buffer.getvalue();
            self.url = self._data_url_from_bytes(data, fmt);
            return;
        }
    }
    # Bytes-like object
    if isinstance(value, (bytes, bytearray, memoryview)) {
        raw = bytes(value);
        # Probe format via PIL to set correct MIME
        img = open_image(BytesIO(raw));
        fmt = img.format or "PNG";
        # Use bytes as-is (avoid re-encode) if PIL detects same format as content
        # Otherwise, re-encode to the detected format to be safe.
        try {
            self.url = self._data_url_from_bytes(raw, fmt);
        } except Exception {
            with BytesIO() as buffer {
                img.save(buffer, format=fmt);
                self.url = self._data_url_from_bytes(buffer.getvalue(), fmt);
            }
        }
        return;
    }
    # File-like object (e.g., BytesIO, IO[bytes])
    if hasattr(value, "read") and callable(value.read) {
        # Safely read without permanently moving the cursor
        stream: IO[bytes] = value;  # type: ignore[assignment]
        pos = None;
        try {
            pos = stream.tell();  # type: ignore[attr-defined]
        } except Exception {
            pos = None;
        }
        try {
            # Prefer getvalue if available (e.g., BytesIO)
            if hasattr(stream, "getvalue") and callable(stream.getvalue) {
                raw = stream.getvalue();  # type: ignore[call-arg]
            } else {
                if hasattr(stream, "seek") {
                    with suppress(Exception) {
                        stream.seek(0);
                    }
                }
                raw = stream.read();
            }
            img = open_image(BytesIO(raw));
            fmt = img.format or "PNG";
            self.url = self._data_url_from_bytes(raw, fmt);
        } finally {
            if pos is not None and hasattr(stream, "seek") {
                with suppress(Exception) {
                    stream.seek(pos);
                }
            }
        }
        return;
    }
    # If we reach here, the input type isn't supported
    raise TypeError(
        "Unsupported Image input type. Provide a URL/path string, data URL, bytes, ""BytesIO, file-like object, os.PathLike, or PIL.Image.Image."
    ) ;
}

impl Image._format_to_mime(fmt: str | None) {
    fmt = (fmt or "PNG").upper();
    if fmt == "WEBP" {
        return "image/webp";
    }
    if fmt == "JPEG" or fmt == "JPG" {
        return "image/jpeg";
    }
    if fmt == "PNG" {
        return "image/png";
    }
    # Try mimetypes (uses extension mapping)
    mime = mimetypes.types_map.get("." + fmt.lower());
    return mime or "image/png";
}

impl Image._data_url_from_bytes(data: bytes, fmt: str | None) {
    mime = self.mime_type or self._format_to_mime(fmt);
    # Ensure mime_type is set on the instance for downstream usage
    self.mime_type = mime;
    b64 = base64.b64encode(data).decode("utf-8");
    return f"data:{mime};base64,{b64}";
}

impl Image.to_dict() {
    image_url = {"url": self.url};
    if self.mime_type {
        image_url["format"] = self.mime_type;
    }
    return [{"type": "image_url", "image_url": image_url,}];
}

#-------------------------------------------------------------------------------
# Video Implementations
#-------------------------------------------------------------------------------
impl Video.postinit() {
    if not os.path.exists(self.path) {
        raise ValueError(f"Video file does not exist: {self.path}") ;
    }
}

impl Video.load_frames() {
    try {
        import cv2;
    } except ImportError {
        raise ImportError(
            "OpenCV is required to process video files.""Install `pip install byllm[video]` for video capabilities."
        ) ;
    }
    self._base64frames = [];
    video = cv2.VideoCapture(self.path);
    total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT));
    target_fps = self.fps;
    source_fps = video.get(cv2.CAP_PROP_FPS);
    frames_to_skip = (
        int(source_fps / target_fps) - 1 if target_fps < source_fps else 1
    );
    curr_frame = 0;
    while curr_frame < total_frames - 1 {
        video.set(cv2.CAP_PROP_POS_FRAMES, curr_frame);
        (success, frame) = video.read();
        if not success {
            raise ValueError("Failed to read video frame.") ;
        }
        (_, buffer) = cv2.imencode(".jpg", frame);
        self._base64frames.append(base64.b64encode(buffer).decode("utf-8"));
        curr_frame += frames_to_skip;
    }
}

impl Video.to_dict() {
    if self._base64frames is None {
        self.load_frames();
    }
    assert (self._base64frames is not None) , "Frames must be loaded before conversion.";
    return [
        {"type": "image_url", "image_url": f"data:image/jpeg;base64,{frame}",}
        for frame in self._base64frames
    ];
}
