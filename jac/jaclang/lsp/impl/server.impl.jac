"""Implementations for LSP server infrastructure."""

import dataclasses;
import from enum { Enum }
import from typing { get_type_hints, get_origin, get_args, Union }

# ===========================================================================
# Serialization helpers
# ===========================================================================
impl _to_camel_case(name: str) -> str {
    parts = name.split("_");
    tail = "".join([p.capitalize() for p in parts[1:]]);
    return str(parts[0]) + tail;
}

impl _to_snake_case(name: str) -> str {
    result: list[str] = [];
    for (i, ch) in enumerate(name) {
        if ch.isupper() and i > 0 {
            result.append("_");
        }
        result.append(ch.lower());
    }
    return "".join(result);
}

"""Recursively convert an LSP object to a JSON-compatible dict."""
impl to_dict(obj: Any) -> Any {
    if obj is None {
        return None;
    }
    if isinstance(obj, (str, int, float, bool)) {
        return obj;
    }
    if isinstance(obj, Enum) {
        return obj.value;
    }
    if isinstance(obj, list) {
        return [to_dict(item) for item in obj];
    }
    if isinstance(obj, dict) {
        return {k: to_dict(v) for (k, v) in obj.items()};
    }
    # Object with __dict__ (Jac objs, dataclasses, etc.)
    if hasattr(obj, "__dict__") {
        result: dict = {};
        for (key, value) in vars(obj).items() {
            if key.startswith("_") {
                continue;
            }
            camel_key = _to_camel_case(key);
            converted = to_dict(value);
            if converted is not None {
                result[camel_key] = converted;
            }
        }
        return result;
    }
    return obj;
}

"""Recursively construct an LSP object from a JSON dict."""
impl from_dict(data: Any, cls: Any) -> Any {
    if data is None {
        return None;
    }
    if cls in (str, int, float, bool, type(None)) {
        return data;
    }
    if isinstance(cls, type) and issubclass(cls, Enum) {
        return cls(data);
    }
    # Handle typing.Optional / Union
    origin = get_origin(cls);
    if origin is Union {
        args = get_args(cls);
        # Optional[X] = Union[X, None]
        non_none = [
            a
            for a in args
            if a is not type(None)
        ];
        if data is None {
            return None;
        }
        # For content change events: if dict has "range" key, it's Type1
        if (
            TextDocumentContentChangeEvent_Type1 in args
            and TextDocumentContentChangeEvent in args
        ) {
            if isinstance(data, dict) and "range" in data {
                return from_dict(data, TextDocumentContentChangeEvent_Type1);
            }
            return from_dict(data, TextDocumentContentChangeEvent);
        }
        if len(non_none) == 1 {
            return from_dict(data, non_none[0]);
        }
        return data;
    }
    if origin is list or origin is List {
        (item_cls, ) = get_args(cls) if get_args(cls) else (Any, );
        return [from_dict(item, item_cls) for item in data];
    }
    if not isinstance(data, dict) {
        return data;
    }
    # Convert camelCase dict → snake_case and construct the obj
    snake_data: dict = {};
    for (key, value) in data.items() {
        snake_data[_to_snake_case(key)] = value;
    }
    # Get constructor hints
    try {
        hints = get_type_hints(cls);
    } except Exception {
        hints = {};
    }
    kwargs: dict = {};
    for (field_name, field_type) in hints.items() {
        if field_name.startswith("_") {
            continue;
        }
        if field_name in snake_data {
            kwargs[field_name] = from_dict(snake_data[field_name], field_type);
        }
    }
    try {
        return cls(**kwargs);
    } except TypeError {
        return data;
    }
}

# ===========================================================================
# PositionCodec
# ===========================================================================
impl PositionCodec.utf16_unit_offset(chars: str) -> int {
    return sum(
        1
        for ch in chars
        if ord(ch) > 0xFFFF
    );
}

impl PositionCodec.client_num_units(chars: str) -> int {
    utf32_units = len(chars);
    if self.encoding == PositionEncodingKind.Utf32 {
        return utf32_units;
    }
    if self.encoding == PositionEncodingKind.Utf8 {
        return utf32_units + (self.utf16_unit_offset(chars) * 2);
    }
    return utf32_units + self.utf16_unit_offset(chars);
}

impl PositionCodec.position_from_client_units(
    lines: list[str], position: Position
) -> Position {
    if len(lines) == 0 {
        return Position(0, 0);
    }
    if position.line >= len(lines) {
        return Position(len(lines) - 1, self.client_num_units(lines[-1]));
    }
    _line = lines[position.line].replace("\r\n", "\n");
    _utf32_len = len(_line);
    if self.client_num_units(_line) == 0 {
        return Position(position.line, 0);
    }
    _client_end = self.client_num_units(_line);
    char = position.character;
    if char > _client_end {
        char = _client_end - 1;
    }
    _client_index = 0;
    utf32_index = 0;
    while _client_index < char and utf32_index < _utf32_len {
        _current_char = _line[utf32_index];
        if ord(_current_char) > 0xFFFF {
            if self.encoding == PositionEncodingKind.Utf32 {
                _client_index += 1;
            }
            if self.encoding == PositionEncodingKind.Utf8 {
                _client_index += 4;
            }
            _client_index += 2;
        } else {
            _client_index += 1;
        }
        utf32_index += 1;
    }
    return Position(line=position.line, character=utf32_index);
}

impl PositionCodec.position_to_client_units(
    lines: list[str], position: Position
) -> Position {
    try {
        character = self.client_num_units(lines[position.line][:position.character]);
        return Position(line=position.line, character=character);
    } except IndexError {
        return Position(line=len(lines), character=0);
    }
}

impl PositionCodec.range_from_client_units(lines: list[str], range: Range) -> Range {
    return Range(
        start=self.position_from_client_units(lines, range.start),
        end=self.position_from_client_units(lines, range.end)
    );
}

impl PositionCodec.range_to_client_units(lines: list[str], range: Range) -> Range {
    return Range(
        start=self.position_to_client_units(lines, range.start),
        end=self.position_to_client_units(lines, range.end)
    );
}

# ===========================================================================
# TextDocument
# ===========================================================================
impl TextDocument.postinit -> None {
    self.path = uris.to_fs_path(self.uri) or self.uri;
    self._position_codec = PositionCodec();
}

impl TextDocument.source -> str {
    if self._source is None {
        with io.open(self.path, "r", encoding="utf-8") as f {
            return f.read();
        }
    }
    return self._source;
}

impl TextDocument.lines -> list[str] {
    return self.source.splitlines(True);
}

impl TextDocument.apply_change(change: Any) -> None {
    if isinstance(change, TextDocumentContentChangeEvent_Type1) {
        self._apply_incremental_change(change);
    } elif isinstance(change, dict) and "range" in change {
        # Dict form — convert to Type1
        range_data = change["range"];
        range_obj = Range(
            start=Position(
                line=range_data["start"]["line"],
                character=range_data["start"]["character"]
            ),
            end=Position(
                line=range_data["end"]["line"],
                character=range_data["end"]["character"]
            )
        );
        typed_change = TextDocumentContentChangeEvent_Type1(
            range=range_obj, text=change["text"]
        );
        self._apply_incremental_change(typed_change);
    } else {
        self._apply_full_change(change);
    }
}

impl TextDocument._apply_incremental_change(
    change: TextDocumentContentChangeEvent_Type1
) -> None {
    lines = self.lines;
    text = change.text;
    change_range = self._position_codec.range_from_client_units(lines, change.range);
    start_line = change_range.start.line;
    start_col = change_range.start.character;
    end_line = change_range.end.line;
    end_col = change_range.end.character;

    if start_line == len(lines) {
        self._source = self.source + text;
        return;
    }
    new = io.StringIO();
    for (i, line) in enumerate(lines) {
        if i < start_line {
            new.write(line);
            continue;
        }
        if i > end_line {
            new.write(line);
            continue;
        }
        if i == start_line {
            new.write(line[:start_col]);
            new.write(text);
        }
        if i == end_line {
            new.write(line[end_col:]);
        }
    }
    self._source = new.getvalue();
}

impl TextDocument._apply_full_change(change: Any) -> None {
    if isinstance(change, dict) {
        self._source = change.get("text", "");
    } else {
        self._source = change.text;
    }
}

# ===========================================================================
# Workspace
# ===========================================================================
impl Workspace.postinit -> None {
    self._position_codec = PositionCodec();
    if self.root_uri is not None {
        self._root_path = uris.to_fs_path(self.root_uri);
    } else {
        self._root_path = None;
    }
}

impl Workspace.get_text_document(doc_uri: str) -> TextDocument {
    if doc_uri in self._text_documents {
        return self._text_documents[doc_uri];
    }
    return TextDocument(uri=doc_uri);
}

impl Workspace.put_text_document(text_document: TextDocumentItem) -> None {
    doc_uri = text_document.uri;
    self._text_documents[doc_uri] = TextDocument(
        uri=doc_uri, _source=text_document.text, version=text_document.version
    );
}

impl Workspace.update_text_document(
    text_doc: VersionedTextDocumentIdentifier, change: Any
) -> None {
    doc_uri = text_doc.uri;
    if doc_uri in self._text_documents {
        self._text_documents[doc_uri].apply_change(change);
        self._text_documents[doc_uri].version = text_doc.version;
    }
}

impl Workspace.remove_text_document(doc_uri: str) -> None {
    self._text_documents.pop(doc_uri, None);
}

# ===========================================================================
# LanguageServer
# ===========================================================================
impl LanguageServer.postinit -> None {
    self._write_lock = threading.Lock();
}

impl LanguageServer.workspace -> Workspace {
    if self._workspace is None {
        self._workspace = Workspace();
    }
    return self._workspace;
}

impl LanguageServer.lsp -> LanguageServer {
    return self;
}

"""Register an LSP feature handler. Returns a decorator."""
impl LanguageServer.feature(method: str, options: Any = None) -> Callable {
    def decorator(func: Callable) -> Callable {
        self._features[method] = func;
        if options is not None {
            self._feature_options[method] = options;
        }
        return func;
    }
    return decorator;
}

"""Start the language server reading from stdin and writing to stdout."""
impl LanguageServer.start_io -> None {
    stdin = sys.stdin.buffer;
    self._transport_writer = sys.stdout.buffer;
    loop = asyncio.new_event_loop();
    asyncio.set_event_loop(loop);
    try {
        while not self._shutdown_flag {
            msg = self._read_message(stdin);
            if msg is None {
                break;
            }
            method = msg.get("method");
            msg_id = msg.get("id");
            params = msg.get("params", {});

            # Built-in lifecycle handlers
            if method == INITIALIZE {
                result = self._handle_initialize(params);
                self._send_response(msg_id, result);
                continue;
            }
            if method == INITIALIZED {
                continue;
            }
            if method == SHUTDOWN {
                self._shutdown_flag = True;
                self.shutdown();
                self._send_response(msg_id, None);
                continue;
            }
            if method == EXIT {
                break;
            }

            # Built-in text document sync
            if method == TEXT_DOCUMENT_DID_OPEN {
                typed_params = from_dict(params, DidOpenTextDocumentParams);
                self.workspace.put_text_document(typed_params.text_document);
            } elif method == TEXT_DOCUMENT_DID_CHANGE {
                typed_params = from_dict(params, DidChangeTextDocumentParams);
                for change in typed_params.content_changes {
                    self.workspace.update_text_document(
                        typed_params.text_document, change
                    );
                }
            } elif method == TEXT_DOCUMENT_DID_CLOSE {
                typed_params = from_dict(params, DidCloseTextDocumentParams);
                self.workspace.remove_text_document(typed_params.text_document.uri);
            }

            # User-registered feature handler
            handler = self._features.get(method);
            if handler is None {
                if msg_id is not None {
                    # Unknown request — send empty response
                    self._send_response(msg_id, None);
                }
                continue;
            }

            # Deserialize params to typed object
            param_cls = METHOD_TO_PARAMS.get(method);
            if param_cls is not None {
                typed_params = from_dict(params, param_cls);
            } else {
                typed_params = params;
            }

            # Call handler (sync or async)
            try {
                if asyncio.iscoroutinefunction(handler) {
                    result = loop.run_until_complete(handler(self, typed_params));
                } else {
                    result = handler(self, typed_params);
                }
            } except Exception as e {
                logger.exception(f"Handler error for {method}: {e}");
                if msg_id is not None {
                    self._send_response(msg_id, None);
                }
                continue;
            }

            # Send response for requests (not notifications)
            if msg_id is not None {
                self._send_response(msg_id, result);
            }
        }
    } finally {
        loop.close();
    }
}

"""Publish diagnostics to the client."""
impl LanguageServer.publish_diagnostics(uri: str, diagnostics: list) -> None {
    self._send_notification(
        TEXT_DOCUMENT_PUBLISH_DIAGNOSTICS,
        {"uri": uri, "diagnostics": [to_dict(d) for d in diagnostics]}
    );
}

"""Show a message popup to the user."""
impl LanguageServer.show_message(message: str, msg_type: Any = None) -> None {
    self._send_notification(
        WINDOW_SHOW_MESSAGE,
        {"type": int(msg_type) if msg_type else 3, "message": message}
    );
}

"""Log a message to the output channel."""
impl LanguageServer.show_message_log(message: str, msg_type: Any = None) -> None {
    self._send_notification(
        WINDOW_LOG_MESSAGE,
        {"type": int(msg_type) if msg_type else 3, "message": message}
    );
}

"""Send a request to the client (fire-and-forget)."""
impl LanguageServer.send_request(method: str, params: Any = None) -> None {
    if self._transport_writer is None {
        return;
    }
    self._next_request_id += 1;
    body: dict = {"jsonrpc": "2.0", "id": self._next_request_id, "method": method};
    if params is not None {
        body["params"] = to_dict(params);
    }
    self._write_message(body);
}

"""Graceful shutdown — override in subclass for cleanup."""
impl LanguageServer.shutdown -> None {
    self._shutdown_flag = True;
}

# ---------------------------------------------------------------------------
# Internal transport
# ---------------------------------------------------------------------------
impl LanguageServer._send_notification(method: str, params: Any) -> None {
    body: dict = {"jsonrpc": "2.0", "method": method, "params": params};
    self._write_message(body);
}

impl LanguageServer._send_response(msg_id: Any, result: Any) -> None {
    body: dict = {"jsonrpc": "2.0", "id": msg_id, "result": to_dict(result)};
    self._write_message(body);
}

impl LanguageServer._write_message(body: dict) -> None {
    if self._transport_writer is None {
        return;
    }
    content = json.dumps(body, ensure_ascii=False).encode("utf-8");
    header = f"Content-Length: {len(content)}\r\n\r\n".encode("ascii");
    with self._write_lock {
        try {
            self._transport_writer.write(header);
            self._transport_writer.write(content);
            self._transport_writer.flush();
        } except (BrokenPipeError, OSError) {
            ;  # Client disconnected
        }
    }
}

impl LanguageServer._read_message(stream: Any) -> Optional[dict] {
    # Read headers
    content_length = -1;
    while True {
        line = stream.readline();
        if not line {
            return None;  # EOF

        }
        line_str = line.decode("ascii").strip();
        if not line_str {
            break;  # Empty line = end of headers
        }
        m = RE_CONTENT_LENGTH.match(line_str);
        if m {
            content_length = int(m.group(1));
        }
    }
    if content_length < 0 {
        return None;
    }
    # Read body
    body = stream.read(content_length);
    if not body {
        return None;
    }
    return json.loads(body.decode("utf-8"));
}

impl LanguageServer._dispatch(msg: dict) -> None {
    ;  # Dispatch handled inline in start_io for simplicity
}

"""Handle the initialize request and return capabilities."""
impl LanguageServer._handle_initialize(params: dict) -> dict {
    # Set up workspace from client-provided root URI
    root_uri = params.get("rootUri") or params.get("rootPath");
    self._workspace = Workspace(root_uri=root_uri);
    return {"capabilities": self._build_capabilities()};
}

"""Build ServerCapabilities from registered features."""
impl LanguageServer._build_capabilities -> dict {
    caps: dict = {
        "textDocumentSync": {
            "openClose": True,
            "change": int(TextDocumentSyncKind.Incremental),
            "save": {"includeText": False}
        }
    };
    _cap_map: dict = {
        "textDocument/completion": "completionProvider",
        "textDocument/hover": "hoverProvider",
        "textDocument/documentSymbol": "documentSymbolProvider",
        "textDocument/definition": "definitionProvider",
        "textDocument/references": "referencesProvider",
        "textDocument/rename": "renameProvider",
        "textDocument/formatting": "documentFormattingProvider",
        "textDocument/semanticTokens/full": "semanticTokensProvider"
    };
    for (method, cap_key) in _cap_map.items() {
        if method in self._features {
            options = self._feature_options.get(method);
            if options is not None {
                caps[cap_key] = to_dict(options);
                # semanticTokensProvider needs special structure
                if cap_key == "semanticTokensProvider" {
                    opts = to_dict(options);
                    caps[cap_key] = {"legend": opts, "full": True};
                }
            } else {
                caps[cap_key] = True;
            }
        }
    }
    # Workspace file operations
    file_ops: dict = {};
    file_op_map: dict = {
        "workspace/didCreateFiles": "didCreate",
        "workspace/didRenameFiles": "didRename",
        "workspace/didDeleteFiles": "didDelete"
    };
    for (method, op_key) in file_op_map.items() {
        if method in self._features {
            options = self._feature_options.get(method);
            if options is not None {
                file_ops[op_key] = to_dict(options);
            }
        }
    }
    if file_ops {
        caps.setdefault("workspace", {});
        caps["workspace"]["fileOperations"] = file_ops;
    }
    return caps;
}
