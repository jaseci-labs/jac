import from enum { Enum }
import from typing { get_type_hints, get_origin, get_args, Union }

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

impl to_dict(`obj: any) -> any {
    if `obj is None {
        return None;
    }
    if isinstance(`obj, (str, int, float, bool)) {
        return `obj;
    }
    if isinstance(`obj, Enum) {
        return `obj.value;
    }
    if isinstance(`obj, list) {
        return [to_dict(item) for item in `obj];
    }
    if isinstance(`obj, dict) {
        return {k: to_dict(v) for (k, v) in `obj.items()};
    }

    if hasattr(`obj, "__dict__") {
        result: dict[str, any] = {};
        for (key, value) in vars(`obj).items() {
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
    return `obj;
}

impl from_dict(data: any, cls: any) -> any {
    if data is None {
        return None;
    }
    if cls in (str, int, float, bool, type(None)) {
        return data;
    }
    if isinstance(cls, type) and issubclass(cls, Enum) {
        return cls(data);
    }

    origin = get_origin(cls);
    if origin is Union {
        args = get_args(cls);

        non_none = [
            a
            for a in args
            if a is not type(None)
        ];
        if data is None {
            return None;
        }

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
    if origin is list {
        (item_cls, ) = get_args(cls) if get_args(cls) else (any, );
        return [from_dict(item, item_cls) for item in data];
    }
    if not isinstance(data, dict) {
        return data;
    }

    snake_data: dict[str, any] = {};
    for (key, value) in data.items() {
        snake_data[_to_snake_case(key)] = value;
    }

    try {
        hints = get_type_hints(cls);
    } except Exception {
        hints = {};
    }
    kwargs: dict[str, any] = {};
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

impl PositionCodec.utf16_unit_offset(chars: str) -> int {
    return sum(
        1
        for ch in chars
        if ord(ch) > 0xFFFF
    );
}

impl PositionCodec.client_num_units(chars: str) -> int {
    if self.encoding == PositionEncodingKind.Utf8 {
        return len(chars.encode('utf-8'));
    }
    return len(chars)
        if self.encoding == PositionEncodingKind.Utf32
        else len(chars) + self.utf16_unit_offset(chars);
}

impl PositionCodec.position_from_client_units(
    lines: list[str], position: Position
) -> Position {
    if not lines {
        return Position(0, 0);
    }
    line = max(0, min(position.line, len(lines) - 1));
    text = lines[line].rstrip('\r\n');
    consumed = 0;
    index = 0;
    while index < len(text) {
        width = self.client_num_units(text[index]);
        if consumed + width > position.character {
            break;
        }
        consumed += width;
        index += 1;
    }
    return Position(line, index);
}

impl PositionCodec.position_to_client_units(
    lines: list[str], position: Position
) -> Position {
    if not lines {
        return Position(0, 0);
    }
    line = max(0, min(position.line, len(lines) - 1));
    return Position(
        line, self.client_num_units(lines[line][:max(0, position.character)])
    );
}

impl PositionCodec.range_from_client_units(lines: list[str], range: Range) -> Range {
    return Range(
        start=self.position_from_client_units(lines, range.start),
        end=self.position_from_client_units(lines, range.end)
    );
}

impl TextDocument.postinit -> None {
    self.path = uris.to_fs_path(self.uri) or self.uri;
    self._position_codec = PositionCodec();
}

impl TextDocument.source.getter -> str {
    if self._source is None {
        with open(self.path, "r", encoding="utf-8") as f {
            return f.read();
        }
    }
    return self._source;
}

impl TextDocument.lines.getter -> list[str] {
    return self.source.splitlines(True);
}

impl TextDocument.apply_change(change: any) -> None {
    if isinstance(change, TextDocumentContentChangeEvent_Type1) {
        self._apply_incremental_change(change);
    } elif isinstance(change, dict) and "range" in change {
        range_data = change["range"];
        range_obj = Range(
            start=Position(
                line=range_data["start"]["line"],
                character=range_data["start"]["character"]
            ),
            end=Position(
                line=range_data["end"]["line"], character=range_data["end"]["character"]
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

impl TextDocument._apply_full_change(change: any) -> None {
    if isinstance(change, dict) {
        self._source = change.get("text", "");
    } else {
        self._source = change.text;
    }
}

impl Workspace.postinit -> None {
    self.lock = threading.RLock();
    self._position_codec = PositionCodec();
    if self.root_uri is not None {
        self._root_path = uris.to_fs_path(self.root_uri);
    } else {
        self._root_path = None;
    }
}

impl Workspace.get_text_document(doc_uri: str) -> TextDocument {
    with self.lock {
        if doc_uri in self._text_documents {
            return self._text_documents[doc_uri];
        }
    }
    return TextDocument(uri=doc_uri);
}

impl Workspace.put_text_document(text_document: TextDocumentItem) -> None {
    with self.lock {
        doc_uri = text_document.uri;
        self._text_documents[doc_uri] = TextDocument(
            uri=doc_uri, _source=text_document.text, version=text_document.version
        );
        self.revision += 1;
    }
}

impl Workspace.update_text_document(
    text_doc: VersionedTextDocumentIdentifier, change: any
) -> None {
    with self.lock {
        doc_uri = text_doc.uri;
        if doc_uri in self._text_documents {
            self._text_documents[doc_uri].apply_change(change);
            self._text_documents[doc_uri].version = text_doc.version;
            self.revision += 1;
        }
    }
}

impl Workspace.change_text_document(params: DidChangeTextDocumentParams) -> None {
    with self.lock {
        identifier = params.text_document;
        document = self._text_documents.get(identifier.uri);
        if document is None
            or (
                document.version is not None and identifier.version <= document.version
            ) {
            return;
        }
        for change in params.content_changes {
            document.apply_change(change);
        }
        document.version = identifier.version;
        self.revision += 1;
    }
}

impl Workspace.snapshot -> WorkspaceSnapshot {
    with self.lock {
        return WorkspaceSnapshot(
            self.revision,
            {
                uri: TextDocument(
                    uri=uri, _source=document.source, version=document.version
                ) for (uri, document) in self._text_documents.items()
            }
        );
    }
}

impl Workspace.remove_text_document(doc_uri: str) -> None {
    with self.lock {
        self._text_documents.pop(doc_uri, None);
        self.revision += 1;
    }
}

impl LanguageServer.postinit -> None {
    self._write_lock = threading.Lock();
    self._request_lock = threading.RLock();
}

impl LanguageServer.workspace.getter -> Workspace {
    if self._workspace is None {
        self._workspace = Workspace();
    }
    return self._workspace;
}

impl LanguageServer.lsp.getter -> LanguageServer {
    return self;
}

impl LanguageServer.feature(method: str, options: any = None) -> Callable {
    def decorator(func: Callable[[any, any], any]) -> Callable {
        self._features[method] = func;
        if options is not None {
            self._feature_options[method] = options;
        }
        return func;
    }
    return decorator;
}

impl LanguageServer.start_io -> None {
    stdin = sys.stdin.buffer;
    self._transport_writer = sys.stdout.buffer;
    try {
        while True {
            msg = self._read_message(stdin);
            if msg is None {
                break;
            }
            method = msg.get("method");
            msg_id = msg.get("id");
            params = msg.get("params", {});
            if method is None {
                continue;
            }
            if method == EXIT {
                break;
            }
            if method == '$/cancelRequest' {
                self._cancel_request(params.get('id'));
                continue;
            }
            if method == INITIALIZE {
                self._send_response(msg_id, self._handle_initialize(params));
                continue;
            }
            if method == INITIALIZED {
                continue;
            }
            if method == SHUTDOWN {
                self.shutdown();
                self._send_response(msg_id, None);
                continue;
            }
            if self._shutdown_flag {
                if msg_id is not None {
                    self._write_message(
                        {
                            'jsonrpc': '2.0',
                            'id': msg_id,
                            'error': {
                                'code': ResponseErrorCode.InvalidRequest.value,
                                'message': 'Server has shut down'
                            }
                        }
                    );
                }
                continue;
            }
            if method == TEXT_DOCUMENT_DID_OPEN {
                opened = from_dict(params, DidOpenTextDocumentParams);
                self.workspace.put_text_document(opened.text_document);
            } elif method == TEXT_DOCUMENT_DID_CHANGE {
                self.workspace.change_text_document(
                    from_dict(params, DidChangeTextDocumentParams)
                );
            } elif method == TEXT_DOCUMENT_DID_CLOSE {
                closed = from_dict(params, DidCloseTextDocumentParams);
                self.workspace.remove_text_document(closed.text_document.uri);
            }
            if msg_id is not None {
                request = Request(msg_id, method, params, self.workspace.revision);
                with self._request_lock {
                    self._requests[msg_id] = request;
                }
                if method not in self._features {
                    self._finish_request(
                        request,
                        error=ResponseErrorCode.MethodNotFound,
                        message=f'Unknown method: {method}'
                    );
                } else {
                    self.submit_request(request);
                }
            } elif method in self._features {
                try {
                    self._invoke_handler(method, params);
                } except Exception {
                    logger.exception(f'Notification handler failed: {method}');
                }
            }
        }
    } finally {
        self.shutdown();
        if self._request_executor is not None {
            self._request_executor.shutdown(`wait=True, cancel_futures=True);
        }
    }
}

impl LanguageServer._invoke_handler(method: str, params: any) -> any {
    param_cls = METHOD_TO_PARAMS.get(method);
    typed_params = from_dict(params, param_cls) if param_cls is not None else params;
    handler = self._features[method];
    return handler(self, typed_params);
}

impl LanguageServer.submit_request(request: Request) -> None {
    if self._request_executor is None {
        self._request_executor = ThreadPoolExecutor(
            max_workers=1, thread_name_prefix='lsp-requests'
        );
    }
    self._request_executor.submit(self._run_request, request);
}

impl LanguageServer._run_request(request: Request) -> None {
    if request.responded {
        return;
    }
    if request.cancel_token.is_set() {
        self._finish_request(
            request,
            error=ResponseErrorCode.RequestCancelled,
            message='Request cancelled'
        );
        return;
    }
    if request.revision != self.workspace.revision {
        self._finish_request(
            request,
            error=ResponseErrorCode.ContentModified,
            message='Workspace changed'
        );
        return;
    }
    try {
        result = self._invoke_handler(request.method, request.params);
        if request.cancel_token.is_set() {
            self._finish_request(
                request,
                error=ResponseErrorCode.RequestCancelled,
                message='Request cancelled'
            );
        } elif request.revision != self.workspace.revision {
            self._finish_request(
                request,
                error=ResponseErrorCode.ContentModified,
                message='Workspace changed'
            );
        } else {
            self._finish_request(request, result=result);
        }
    } except Exception {
        logger.exception(f'Request handler failed: {request.method}');
        self._finish_request(
            request, error=ResponseErrorCode.InternalError, message='Request failed'
        );
    }
}

impl LanguageServer._finish_request(
    request: Request,
    result: any = None,
    error: ResponseErrorCode | None = None,
    message: str = ''
) -> None {
    with self._request_lock {
        if request.responded {
            return;
        }
        request.responded = True;
        self._requests.pop(request.message_id, None);
        if error is not None {
            self._write_message(
                {
                    'jsonrpc': '2.0',
                    'id': request.message_id,
                    'error': {'code': error.value, 'message': message}
                }
            );
        } else {
            self._send_response(request.message_id, result);
        }
    }
}

impl LanguageServer._cancel_request(message_id: int | str) -> None {
    with self._request_lock {
        request = self._requests.get(message_id);
        if request is not None {
            request.cancel_token.set();
            self._finish_request(
                request,
                error=ResponseErrorCode.RequestCancelled,
                message='Request cancelled'
            );
        }
    }
}

impl LanguageServer.publish_diagnostics(
    uri: str, diagnostics: list[Diagnostic], version: int | None = None
) -> None {
    params: dict[str, any] = {
        'uri': uri,
        'diagnostics': [to_dict(d) for d in diagnostics]
    };
    if version is not None {
        params['version'] = version;
    }
    self._send_notification(TEXT_DOCUMENT_PUBLISH_DIAGNOSTICS, params);
}

impl LanguageServer.show_message(message: str, msg_type: any = None) -> None {
    self._send_notification(
        WINDOW_SHOW_MESSAGE,
        {"type": int(msg_type) if msg_type else 3, "message": message}
    );
}

impl LanguageServer.show_message_log(message: str, msg_type: any = None) -> None {
    self._send_notification(
        WINDOW_LOG_MESSAGE,
        {"type": int(msg_type) if msg_type else 3, "message": message}
    );
}

impl LanguageServer.send_request(method: str, params: any = None) -> None {
    if self._transport_writer is None {
        return;
    }
    self._next_request_id += 1;
    body: dict[str, any] = {
        "jsonrpc": "2.0",
        "id": self._next_request_id,
        "method": method
    };
    if params is not None {
        body["params"] = to_dict(params);
    }
    self._write_message(body);
}

impl LanguageServer.shutdown -> None {
    self._shutdown_flag = True;
}

impl LanguageServer._send_notification(method: str, params: any) -> None {
    body: dict[str, any] = {"jsonrpc": "2.0", "method": method, "params": params};
    self._write_message(body);
}

impl LanguageServer._send_response(msg_id: any, result: any) -> None {
    body: dict[str, any] = {"jsonrpc": "2.0", "id": msg_id, "result": to_dict(result)};
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
        } except (BrokenPipeError, OSError) {}
    }
}

impl LanguageServer._read_message(stream: any) -> Optional[dict] {
    content_length = -1;
    while True {
        line = stream.readline();
        if not line {
            return None;
        }
        line_str = line.decode("ascii").strip();
        if not line_str {
            break;
        }
        m = RE_CONTENT_LENGTH.`match(line_str);
        if m {
            content_length = int(m.group(1));
        }
    }
    if content_length < 0 {
        return None;
    }

    body = stream.read(content_length);
    if not body {
        return None;
    }
    return json.loads(body.decode("utf-8"));
}

impl LanguageServer._handle_initialize(params: dict) -> dict {
    root_uri = params.get("rootUri") or params.get("rootPath");
    self._workspace = Workspace(root_uri=root_uri);
    return {"capabilities": self._build_capabilities()};
}

impl LanguageServer._build_capabilities -> dict {
    caps: dict[str, any] = {
        "textDocumentSync": {
            "openClose": True,
            "change": int(TextDocumentSyncKind.Incremental),
            "save": {"includeText": False}
        }
    };
    _cap_map: dict[str, str] = {
        "textDocument/completion": "completionProvider",
        "textDocument/hover": "hoverProvider",
        "textDocument/documentSymbol": "documentSymbolProvider",
        "textDocument/definition": "definitionProvider",
        "textDocument/references": "referencesProvider",
        "textDocument/rename": "renameProvider",
        "textDocument/formatting": "documentFormattingProvider",
        "textDocument/semanticTokens/full": "semanticTokensProvider",
        "textDocument/inlayHint": "inlayHintProvider"
    };
    for (method, cap_key) in _cap_map.items() {
        if method in self._features {
            options = self._feature_options.get(method);
            if options is not None {
                caps[cap_key] = to_dict(options);

                if cap_key == "semanticTokensProvider" {
                    opts = to_dict(options);
                    caps[cap_key] = {"legend": opts, "full": True};
                }
            } else {
                caps[cap_key] = True;
            }
        }
    }

    file_ops: dict[str, any] = {};
    file_op_map: dict[str, str] = {
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
