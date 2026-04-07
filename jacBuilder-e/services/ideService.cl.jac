
"""Extract latest report from Jac response envelope."""
def _extractReport(data: Any) -> Any {
    if Array.isArray(data) and data.length > 0 {
        return data[data.length - 1];
    }
    if data and data.data and data.data.reports and data.data.reports.length > 0 {
        return data.data.reports[data.data.reports.length - 1];
    }
    if data and data.reports and data.reports.length > 0 {
        return data.reports[data.reports.length - 1];
    }
    return data;
}

"""Force logout: clear all auth state and redirect to /auth."""
def _forceLogout() -> None {
    localStorage.removeItem("jac_token");
    localStorage.removeItem("jac_guest_creds");
    localStorage.removeItem("jac_display_name");
    window.location.href = "/auth";
}

"""POST to walker endpoint with auth token."""
async def _walkerPost(path: str, params: Any) -> Any {
    try {
        token = localStorage.getItem("jac_token");
        server_path = (globalThis.__JAC_API_BASE_URL__ or "") + path;
        response = await fetch(
            server_path,
            {
                "method": "POST",
                "headers": {
                    "Content-Type": "application/json",
                    "Authorization": ("Bearer " + token if token else "")
                },
                "body": JSON.stringify(params)
            }
        );
        if response.status == 401 {
            _forceLogout();
            return {"success": False, "error": "Session expired"};
        }
        data = await response.json();
        return _extractReport(data);
    } except Exception as e {
        console.error("walkerPost error:", e);
        return {"success": False, "error": String(e)};
    }
}

"""Get current authenticated user's profile (creates on first call).
Also captures the ws_token for authenticated WebSocket communication."""
async def:pub ideGetMe() -> Any {
    hint = localStorage.getItem("jac_display_name") or "";
    result = await _walkerPost("/walker/me", {"display_name_hint": hint});
    if result and result.success and result.ws_token {
        _wsAuth["token"] = result.ws_token;
    }
    return result;
}

"""File workspace setup for a project."""
async def:pub ideSetup(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {"project_id": projectId, "action": "setup"}
    );
}

"""List files in a project preview workspace."""
async def:pub ideListFiles(projectId: str, path: str = ".") -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {"project_id": projectId, "action": "list", "path": path}
    );
}

"""Read file from active project workspace."""
async def:pub ideReadFile(projectId: str, path: str) -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {"project_id": projectId, "action": "read", "path": path}
    );
}

"""Write file to active project workspace (autosave/versioning on backend)."""
async def:pub ideWriteFile(projectId: str, path: str, content: str) -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {
            "project_id": projectId,
            "action": "write",
            "path": path,
            "content": content
        }
    );
}

"""Batch-write multiple files to workspace (single commit)."""
async def:pub ideBatchWrite(projectId: str, files: list) -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {
            "project_id": projectId,
            "action": "batch_write",
            "files": files
        }
    );
}

"""Copy file to a new path in workspace."""
async def:pub ideCopyFile(projectId: str, srcPath: str, destPath: str) -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {
            "project_id": projectId,
            "action": "copy",
            "path": srcPath,
            "new_path": destPath
        }
    );
}

"""Delete file/directory from workspace."""
async def:pub ideDeleteFile(projectId: str, path: str) -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {"project_id": projectId, "action": "delete", "path": path}
    );
}

"""Rename or move file/directory in workspace."""
async def:pub ideRenameFile(projectId: str, oldPath: str, newPath: str) -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {
            "project_id": projectId,
            "action": "rename",
            "path": oldPath,
            "new_path": newPath
        }
    );
}

"""Create a directory in workspace."""
async def:pub ideMkdir(projectId: str, path: str) -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {"project_id": projectId, "action": "mkdir", "path": path}
    );
}

"""Search file contents across project workspace."""
async def:pub ideSearchFiles(projectId: str, query: str, caseSensitive: bool = False) -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {
            "project_id": projectId,
            "action": "search",
            "query": query,
            "case_sensitive": caseSensitive
        }
    );
}

async def:pub ideReplaceInFiles(projectId: str, query: str, replaceText: str, caseSensitive: bool = False, fileFilter: str = "") -> Any {
    return await _walkerPost(
        "/walker/ide_file_ops",
        {
            "project_id": projectId,
            "action": "replace",
            "query": query,
            "replace_text": replaceText,
            "case_sensitive": caseSensitive,
            "file_filter": fileFilter
        }
    );
}

"""List curated jacpack templates."""
async def:pub ideListTemplates() -> Any {
    return await _walkerPost("/walker/template_ops", {"action": "list"});
}

"""List projects for current authenticated user."""
async def:pub ideListProjects() -> Any {
    return await _walkerPost("/walker/project_ops", {"action": "list"});
}

"""Create a project from selected template."""
async def:pub ideCreateProject(name: str, templateId: str) -> Any {
    return await _walkerPost(
        "/walker/project_ops",
        {
            "action": "create",
            "name": name,
            "template_id": templateId
        }
    );
}

"""Import project from uploaded jacpack file (base64) or URL."""
async def:pub ideImportProject(name: str, jacpackUrl: str, jacpackContentBase64: str) -> Any {
    return await _walkerPost(
        "/walker/project_ops",
        {
            "action": "import",
            "name": name,
            "jacpack_url": jacpackUrl,
            "jacpack_content_base64": jacpackContentBase64
        }
    );
}

"""Open project status."""
async def:pub ideOpenProject(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/project_ops",
        {"action": "open", "project_id": projectId}
    );
}

"""Rename project display name."""
async def:pub ideRenameProject(projectId: str, name: str) -> Any {
    return await _walkerPost(
        "/walker/project_ops",
        {"action": "rename", "project_id": projectId, "name": name}
    );
}

"""Delete project and its workspace."""
async def:pub ideDeleteProject(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/project_ops",
        {"action": "delete", "project_id": projectId}
    );
}

"""Get version list for active project."""
async def:pub ideListVersions(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/version_ops",
        {"project_id": projectId, "action": "list"}
    );
}

"""Capture a new version from current project working tree."""
async def:pub ideCaptureVersion(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/version_ops",
        {"project_id": projectId, "action": "capture"}
    );
}

"""Checkout version by version id or commit."""
async def:pub ideCheckoutVersion(projectId: str, versionId: str = "", commitSha: str = "") -> Any {
    return await _walkerPost(
        "/walker/version_ops",
        {
            "project_id": projectId,
            "action": "checkout",
            "version_id": versionId,
            "commit_sha": commitSha
        }
    );
}

"""Export version jacpack file."""
async def:pub ideExportVersion(projectId: str, versionId: str = "", outputPath: str = "") -> Any {
    return await _walkerPost(
        "/walker/version_ops",
        {
            "project_id": projectId,
            "action": "export_jacpack",
            "version_id": versionId,
            "output_path": outputPath
        }
    );
}

"""Export version as downloadable jacpack payload."""
async def:pub ideExportVersionDownload(projectId: str, versionId: str = "") -> Any {
    return await _walkerPost(
        "/walker/version_ops",
        {
            "project_id": projectId,
            "action": "export_jacpack_download",
            "version_id": versionId,
            "output_path": ""
        }
    );
}

"""Export project as downloadable zip."""
async def:pub ideExportZipDownload(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/version_ops",
        {
            "project_id": projectId,
            "action": "export_zip_download",
            "version_id": "",
            "output_path": ""
        }
    );
}

"""Start AI chat processing (non-blocking). Returns immediately.
Frontend then polls for events via WebSocket ai_events."""
async def:pub ideChatStart(
    projectId: str,
    message: str,
    currentFilePath: str = "",
    images: list = []
) -> Any {
    payload: Any = {
        "project_id": projectId,
        "message": message,
        "current_file_path": currentFilePath,
        "action": "start"
    };
    if images and images.length > 0 {
        payload.images = images;
    }
    return await _walkerPost("/walker/ai_chat", payload);
}

"""Stop the running JacCoder agent for a project."""
async def:pub ideChatStop(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/ai_chat",
        {
            "project_id": projectId,
            "action": "stop"
        }
    );
}

"""Load persisted JacCoder chat history for a project."""
async def:pub ideChatLoadHistory(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/ai_chat",
        {
            "project_id": projectId,
            "action": "load_history"
        }
    );
}

"""Clear all JacCoder chat history for a project."""
async def:pub ideChatClearHistory(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/ai_chat",
        {
            "project_id": projectId,
            "action": "clear_history"
        }
    );
}

"""Persist assistant/error response and create git version after WS polling completes."""
async def:pub ideChatPersistResult(
    projectId: str,
    responseText: str,
    promotedFiles: list,
    isError: bool = False,
    checkpointRef: str = "",
    activitiesLog: list = []
) -> Any {
    return await _walkerPost(
        "/walker/ai_chat",
        {
            "project_id": projectId,
            "action": "persist_done",
            "response_text": responseText,
            "promoted_files": promotedFiles,
            "is_error": isError,
            "checkpoint_ref": checkpointRef,
            "activities_log": activitiesLog
        }
    );
}

"""Revert to a previous AI turn's checkpoint (non-destructive, stays on branch)."""
async def:pub ideChatRevertToMessage(projectId: str, checkpointRef: str) -> Any {
    return await _walkerPost(
        "/walker/ai_chat",
        {
            "project_id": projectId,
            "action": "revert_to_message",
            "checkpoint_ref": checkpointRef
        }
    );
}

# --- Shared persistent preview WebSocket ---

glob _previewWs: Any = None;
glob _previewWsState: str = "closed";
glob _previewWsOutbox: list = [];
glob _previewWsPending: list = [];
glob _wsAuth: dict = {"token": ""};
glob _TAB_ID: str = crypto.randomUUID();
glob _previewWsPendingMap: Any = Reflect.construct(Map, []);

def _previewWsUrl() -> str {
    base = globalThis.__JAC_API_BASE_URL__;
    if base {
        url = Reflect.construct(URL, [String(base)]);
        protocol = "wss:";
        if url.protocol == "http:" {
            protocol = "ws:";
        }
        return protocol + "//" + url.host + "/ws/ide_preview_stream";
    }
    protocol = "ws:";
    if window.location.protocol == "https:" {
        protocol = "wss:";
    }
    return protocol + "//" + window.location.host + "/ws/ide_preview_stream";
}

def _notifyWsHandler(handler: Any, msg: Any) -> None {
    if not handler { return; }
    try {
        handler.call(None, msg);
    } except Exception as e {
        console.error("WS handler error:", e);
    }
}

def _failWsEntries(entries: list, errorMsg: str) -> None {
    err = {
        "ok": False,
        "error": {"code": "WS_DISCONNECTED", "message": errorMsg}
    };
    if entries and entries.length > 0 {
        while entries.length > 0 {
            entry = entries.shift();
            if entry and entry.handler {
                _notifyWsHandler(entry.handler, err);
            }
        }
    }
    _previewWsPendingMap.forEach(lambda(handler: Any, _rid: Any) {
        _notifyWsHandler(handler, err);
    });
    _previewWsPendingMap.clear();
}

def _flushWsOutbox() -> None {
    if _previewWsState != "open" or not _previewWs { return; }
    while _previewWsOutbox.length > 0 and _previewWsState == "open" and _previewWs {
        entry = _previewWsOutbox.shift();
        try {
            _previewWs.send(entry.payload);
            if entry.requestId {
                _previewWsPendingMap.set(entry.requestId, entry.handler);
            } else {
                _previewWsPending.push(entry);
            }
        } except Exception as e {
            _previewWsOutbox.unshift(entry);
            console.warn("WS send failed, will reconnect:", e);
            try {
                _previewWs.close();
            } except Exception {
            }
            break;
        }
    }
}

def _extractWsReport(data: Any) -> Any {
    if data and data.ok and data.data and data.data.reports and data.data.reports.length > 0 {
        return data.data.reports[data.data.reports.length - 1];
    }
    if data and data.data and data.data.reports and data.data.reports.length > 0 {
        return data.data.reports[data.data.reports.length - 1];
    }
    return data;
}

def _ensurePreviewWs() -> None {
    if _previewWsState == "open" or _previewWsState == "connecting" {
        return;
    }
    wsUrl = _previewWsUrl();
    _previewWsState = "connecting";
    _previewWs = Reflect.construct(WebSocket, [wsUrl]);

    _previewWs.onopen = lambda {
        _previewWsState = "open";
        _flushWsOutbox();
    };
    _previewWs.onmessage = lambda(event: Any) {
        data = JSON.parse(event.data);
        msg = _extractWsReport(data);
        rid = "";
        if msg and msg.request_id { rid = msg.request_id; }
        if rid and _previewWsPendingMap.has(rid) {
            handler = _previewWsPendingMap.get(rid);
            _previewWsPendingMap.delete(rid);
            _notifyWsHandler(handler, msg);
        } elif _previewWsPending.length > 0 {
            entry = _previewWsPending.shift();
            if entry and entry.handler {
                _notifyWsHandler(entry.handler, msg);
            }
        }
    };
    _previewWs.onerror = lambda(e: Any) {
        console.warn("WS error:", e);
    };
    _previewWs.onclose = lambda(_: Any) {
        _previewWs = None;
        _previewWsState = "closed";
        _failWsEntries(_previewWsPending, "WebSocket closed before response");
        _failWsEntries(_previewWsOutbox, "WebSocket closed before send");
    };
}

"""Queue a WS request for preview stream walker.
Includes ws_token for authentication against the pub WS walker.
Each request gets a unique request_id for response correlation."""
def:pub sendWsRequest(action: str, userId: str, projectId: str, logOffset: int, onResponse: Any) -> None {
    reqId = crypto.randomUUID();
    entry = {
        "payload": JSON.stringify(
            {
                "user_id": userId,
                "project_id": projectId,
                "action": action,
                "log_offset": logOffset,
                "ws_token": _wsAuth["token"],
                "connection_id": _TAB_ID,
                "request_id": reqId
            }
        ),
        "requestId": reqId,
        "handler": onResponse
    };
    _previewWsOutbox.push(entry);
    _ensurePreviewWs();
    _flushWsOutbox();
}

"""List public community gallery items."""
async def:pub communityList(search: str = "", tag: str = "") -> Any {
    return await _walkerPost(
        "/walker/community_ops",
        {"action": "list", "search": search, "tag": tag}
    );
}

"""Submit a project to community gallery."""
async def:pub communitySubmit(name: str, description: str, tags: list, jacpackBase64: str) -> Any {
    return await _walkerPost(
        "/walker/community_submit",
        {
            "action": "submit",
            "name": name,
            "description": description,
            "tags": tags,
            "jacpack_content_base64": jacpackBase64
        }
    );
}

"""Clone a community item into user's own projects."""
async def:pub communityClone(commId: str, projectName: str) -> Any {
    return await _walkerPost(
        "/walker/community_submit",
        {"action": "clone", "comm_id": commId, "project_name": projectName}
    );
}

"""Remove own community submission."""
async def:pub communityRemove(commId: str) -> Any {
    return await _walkerPost(
        "/walker/community_submit",
        {"action": "remove", "comm_id": commId}
    );
}

"""Environment variable operations: list/save project env file."""
async def:pub ideEnvOps(projectId: str, action: str, envList: list) -> Any {
    return await _walkerPost(
        "/walker/env_ops",
        {
            "project_id": projectId,
            "action": action,
            "env_list": envList
        }
    );
}

"""User-level global env operations (no project required)."""
async def:pub ideUserEnvOps(action: str, envList: list) -> Any {
    return await _walkerPost(
        "/walker/env_ops",
        {
            "action": action,
            "env_list": envList
        }
    );
}

"""Deploy the current project to K8s."""
async def:pub ideDeployProject(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/deploy_ops",
        {"project_id": projectId, "action": "deploy"}
    );
}

"""Get deployment status for a project."""
async def:pub ideDeployStatus(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/deploy_ops",
        {"project_id": projectId, "action": "status"}
    );
}

"""Destroy a project's deployment."""
async def:pub ideDestroyDeployment(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/deploy_ops",
        {"project_id": projectId, "action": "destroy"}
    );
}

"""Deploy project as a sandbox (1-week TTL)."""
async def:pub ideSandboxDeploy(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/deploy_ops",
        {"project_id": projectId, "action": "deploy", "deploy_mode": "sandbox"}
    );
}

"""Get sandbox deployment status."""
async def:pub ideSandboxStatus(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/deploy_ops",
        {"project_id": projectId, "action": "status", "deploy_mode": "sandbox"}
    );
}

"""Destroy a project's sandbox deployment."""
async def:pub ideSandboxDestroy(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/deploy_ops",
        {"project_id": projectId, "action": "destroy", "deploy_mode": "sandbox"}
    );
}

"""Capture a screenshot of a project's running preview or a direct URL."""
async def:pub idePreviewScreenshot(
    projectId: str = "",
    url: str = "",
    viewport: str = "desktop",
    format: str = "jpeg",
    fullPage: bool = False,
    delay: int = 3000
) -> Any {
    return await _walkerPost(
        "/walker/preview_screenshot",
        {
            "project_id": projectId,
            "url": url,
            "viewport": viewport,
            "format": format,
            "full_page": fullPage,
            "delay": delay
        }
    );
}

"""Fetch a project's thumbnail image (base64)."""
async def:pub ideGetProjectThumbnail(projectId: str) -> Any {
    return await _walkerPost(
        "/walker/project_ops",
        {"action": "get_thumbnail", "project_id": projectId}
    );
}

# --- Shared persistent LSP WebSocket ---

glob _lspWs: Any = None;
glob _lspWsState: str = "closed";
glob _lspWsOutbox: list = [];
glob _lspWsPending: list = [];

def _lspWsUrl() -> str {
    base = globalThis.__JAC_API_BASE_URL__;
    if base {
        url = Reflect.construct(URL, [String(base)]);
        protocol = "wss:";
        if url.protocol == "http:" {
            protocol = "ws:";
        }
        return protocol + "//" + url.host + "/ws/lsp_stream";
    }
    protocol = "ws:";
    if window.location.protocol == "https:" {
        protocol = "wss:";
    }
    return protocol + "//" + window.location.host + "/ws/lsp_stream";
}

def _flushLspOutbox() -> None {
    if _lspWsState != "open" or not _lspWs { return; }
    while _lspWsOutbox.length > 0 and _lspWsState == "open" and _lspWs {
        entry = _lspWsOutbox.shift();
        try {
            _lspWs.send(entry.payload);
            _lspWsPending.push(entry);
        } except Exception as e {
            _lspWsOutbox.unshift(entry);
            console.warn("LSP WS send failed:", e);
            try { _lspWs.close(); } except Exception { }
            break;
        }
    }
}

def _ensureLspWs() -> None {
    if _lspWsState == "open" or _lspWsState == "connecting" {
        return;
    }
    wsUrl = _lspWsUrl();
    _lspWsState = "connecting";
    _lspWs = Reflect.construct(WebSocket, [wsUrl]);

    _lspWs.onopen = lambda {
        _lspWsState = "open";
        _flushLspOutbox();
    };
    _lspWs.onmessage = lambda(event: Any) {
        data = JSON.parse(event.data);
        msg = _extractWsReport(data);
        if _lspWsPending.length == 0 { return; }
        entry = _lspWsPending.shift();
        if entry and entry.handler {
            _notifyWsHandler(entry.handler, msg);
        }
    };
    _lspWs.onerror = lambda(e: Any) {
        console.warn("LSP WS error:", e);
    };
    _lspWs.onclose = lambda(_: Any) {
        _lspWs = None;
        _lspWsState = "closed";
        _failWsEntries(_lspWsPending, "LSP WebSocket closed before response");
        _failWsEntries(_lspWsOutbox, "LSP WebSocket closed before send");
    };
}

"""Queue a WS request for LSP stream walker.
Includes ws_token for authentication against the pub WS walker."""
def:pub sendLspRequest(action: str, userId: str, projectId: str, data: Any, onResponse: Any) -> None {
    entry = {
        "payload": JSON.stringify(
            {
                "user_id": userId,
                "project_id": projectId,
                "action": action,
                "data": (data if data else {}),
                "ws_token": _wsAuth["token"]
            }
        ),
        "handler": onResponse
    };
    _lspWsOutbox.push(entry);
    _ensureLspWs();
    _flushLspOutbox();
}

"""Close shared LSP WebSocket and clear pending queue."""
def:pub closeLspWs() -> None {
    _failWsEntries(_lspWsPending, "LSP WebSocket closed");
    _failWsEntries(_lspWsOutbox, "LSP WebSocket closed");
    if _lspWs {
        try { _lspWs.close(); } except Exception { }
    }
    _lspWs = None;
    _lspWsState = "closed";
}

# ===========================================================================
# Terminal WebSocket (Interactive Terminal)
# ===========================================================================

glob _termWs: Any = None;
glob _termWsState: str = "closed";
glob _termWsOutbox: list = [];
glob _termWsPending: list = [];

def _termWsUrl() -> str {
    base = globalThis.__JAC_API_BASE_URL__;
    if base {
        url = Reflect.construct(URL, [String(base)]);
        protocol = "wss:";
        if url.protocol == "http:" {
            protocol = "ws:";
        }
        return protocol + "//" + url.host + "/ws/terminal_stream";
    }
    protocol = "ws:";
    if window.location.protocol == "https:" {
        protocol = "wss:";
    }
    return protocol + "//" + window.location.host + "/ws/terminal_stream";
}

def _flushTermOutbox() -> None {
    if _termWsState != "open" or not _termWs { return; }
    while _termWsOutbox.length > 0 and _termWsState == "open" and _termWs {
        entry = _termWsOutbox.shift();
        try {
            _termWs.send(entry.payload);
            _termWsPending.push(entry);
        } except Exception as e {
            _termWsOutbox.unshift(entry);
            console.warn("Terminal WS send failed:", e);
            try { _termWs.close(); } except Exception { }
            break;
        }
    }
}

def _ensureTermWs() -> None {
    if _termWsState == "open" or _termWsState == "connecting" {
        return;
    }
    wsUrl = _termWsUrl();
    _termWsState = "connecting";
    _termWs = Reflect.construct(WebSocket, [wsUrl]);

    _termWs.onopen = lambda {
        _termWsState = "open";
        _flushTermOutbox();
    };
    _termWs.onmessage = lambda(event: Any) {
        data = JSON.parse(event.data);
        msg = _extractWsReport(data);
        if _termWsPending.length == 0 { return; }
        entry = _termWsPending.shift();
        if entry and entry.handler {
            _notifyWsHandler(entry.handler, msg);
        }
    };
    _termWs.onerror = lambda(e: Any) {
        console.warn("Terminal WS error:", e);
    };
    _termWs.onclose = lambda(_: Any) {
        _termWs = None;
        _termWsState = "closed";
        _failWsEntries(_termWsPending, "Terminal WebSocket closed before response");
        _failWsEntries(_termWsOutbox, "Terminal WebSocket closed before send");
    };
}

"""Queue a WS request for terminal_stream walker."""
def:pub sendTermRequest(action: str, userId: str, projectId: str, data: str, cols: int, rows: int, onResponse: Any) -> None {
    entry = {
        "payload": JSON.stringify(
            {
                "user_id": userId,
                "project_id": projectId,
                "action": action,
                "data": data,
                "cols": cols,
                "rows": rows,
                "ws_token": _wsAuth["token"]
            }
        ),
        "handler": onResponse
    };
    _termWsOutbox.push(entry);
    _ensureTermWs();
    _flushTermOutbox();
}

"""Send a command string to the interactive terminal (types it + presses Enter).
Ensures the terminal is started first if not already running."""
def:pub runInTerminal(userId: str, projectId: str, command: str) -> None {
    newline = String.fromCharCode(10);
    sendTermRequest("start", userId, projectId, "", 80, 24, lambda(_: Any) -> None {
        setTimeout(lambda {
            sendTermRequest("input", userId, projectId, command + newline, 80, 24, lambda(_r: Any) -> None { ; });
        }, 300);
    });
}

"""Close shared terminal WebSocket and clear pending queue."""
def:pub closeTermWs() -> None {
    _failWsEntries(_termWsPending, "Terminal WebSocket closed");
    _failWsEntries(_termWsOutbox, "Terminal WebSocket closed");
    if _termWs {
        try { _termWs.close(); } except Exception { }
    }
    _termWs = None;
    _termWsState = "closed";
}

"""Close shared preview WebSocket and clear pending queues."""
def:pub closePreviewWs() -> None {
    _failWsEntries(_previewWsPending, "WebSocket closed");
    _failWsEntries(_previewWsOutbox, "WebSocket closed");
    if _previewWs {
        try {
            _previewWs.close();
        } except Exception {
        }
    }
    _previewWs = None;
    _previewWsState = "closed";
}


# ===========================================================================
# Claude Code CLI
# ===========================================================================

"""Check if Claude CLI is available on the server."""
async def:pub claudeCheck() -> Any {
    return await _walkerPost("/walker/claude_chat", {"project_id": "", "action": "check"});
}

"""Start a Claude Code turn (non-blocking)."""
async def:pub claudeChatStart(
    projectId: str,
    message: str,
    model: str = "",
    allowedTools: str = "Read,Edit,Bash,Glob,Grep,Write",
    threadId: str = "",
    envMode: str = "local",
    branch: str = "",
    images: list = []
) -> Any {
    payload: Any = {
        "project_id": projectId,
        "thread_id": threadId,
        "message": message,
        "action": "start",
        "model": model,
        "allowed_tools": allowedTools,
        "env_mode": envMode,
        "branch": branch
    };
    if images and images.length > 0 {
        payload.images = images;
    }
    return await _walkerPost("/walker/claude_chat", payload);
}

"""Interrupt a running Claude turn."""
async def:pub claudeChatInterrupt(projectId: str) -> Any {
    return await _walkerPost("/walker/claude_chat", {
        "project_id": projectId,
        "action": "interrupt"
    });
}

"""Stop Claude session entirely."""
async def:pub claudeChatStop(projectId: str, threadId: str = "") -> Any {
    return await _walkerPost("/walker/claude_chat", {
        "project_id": projectId,
        "thread_id": threadId,
        "action": "stop"
    });
}

"""Get Claude session info."""
async def:pub claudeChatInfo(projectId: str, threadId: str = "") -> Any {
    return await _walkerPost("/walker/claude_chat", {
        "project_id": projectId,
        "thread_id": threadId,
        "action": "info"
    });
}

"""Persist assistant message and activities to thread after WS-based turn completes."""
async def:pub claudePersistTurn(projectId: str, threadId: str, content: str, activities: list = []) -> Any {
    return await _walkerPost("/walker/claude_chat", {
        "project_id": projectId,
        "thread_id": threadId,
        "message": content,
        "action": "persist",
        "activities": activities
    });
}


# ===========================================================================
# Claude History
# ===========================================================================

"""List all Claude threads for a project."""
async def:pub claudeListThreads(projectId: str) -> Any {
    return await _walkerPost("/walker/claude_history", {
        "project_id": projectId,
        "action": "list_threads"
    });
}

"""Get a specific thread with all messages and activities."""
async def:pub claudeGetThread(projectId: str, threadId: str) -> Any {
    return await _walkerPost("/walker/claude_history", {
        "project_id": projectId,
        "thread_id": threadId,
        "action": "get_thread"
    });
}

"""Delete a Claude thread."""
async def:pub claudeDeleteThread(projectId: str, threadId: str) -> Any {
    return await _walkerPost("/walker/claude_history", {
        "project_id": projectId,
        "thread_id": threadId,
        "action": "delete_thread"
    });
}

"""Rename a Claude thread."""
async def:pub claudeRenameThread(projectId: str, threadId: str, title: str) -> Any {
    return await _walkerPost("/walker/claude_history", {
        "project_id": projectId,
        "thread_id": threadId,
        "message": title,
        "action": "rename_thread"
    });
}

"""Merge a worktree thread's branch into the project's active branch."""
async def:pub claudeMergeThread(projectId: str, threadId: str) -> Any {
    return await _walkerPost("/walker/claude_history", {
        "project_id": projectId,
        "thread_id": threadId,
        "action": "merge_thread"
    });
}

"""Clear all messages and activities from a thread (keeps the thread node)."""
async def:pub claudeClearThread(projectId: str, threadId: str) -> Any {
    return await _walkerPost("/walker/claude_history", {
        "project_id": projectId,
        "thread_id": threadId,
        "action": "clear_thread"
    });
}

"""Clean up orphaned worktrees (not linked to any thread)."""
async def:pub claudeCleanupWorktrees(projectId: str) -> Any {
    return await _walkerPost("/walker/claude_history", {
        "project_id": projectId,
        "action": "cleanup_worktrees"
    });
}


# ===========================================================================
# Git Operations
# ===========================================================================

"""Create a git worktree."""
async def:pub gitWorktreeCreate(projectId: str, baseBranch: str, newBranch: str = "") -> Any {
    return await _walkerPost("/walker/git_ops", {
        "project_id": projectId,
        "action": "worktree_create",
        "branch": baseBranch,
        "new_branch": newBranch
    });
}

"""Remove a git worktree."""
async def:pub gitWorktreeRemove(projectId: str, worktreePath: str) -> Any {
    return await _walkerPost("/walker/git_ops", {
        "project_id": projectId,
        "action": "worktree_remove",
        "worktree_path": worktreePath
    });
}

"""List git worktrees."""
async def:pub gitWorktreeList(projectId: str) -> Any {
    return await _walkerPost("/walker/git_ops", {
        "project_id": projectId,
        "action": "worktree_list"
    });
}

async def:pub githubOps(action: str, params: Any = {}) -> Any {
    payload: dict = {"action": action};
    keys = Object.keys(params);
    i = 0;
    while i < keys.length {
        k = keys[i];
        payload[k] = params[k];
        i = i + 1;
    }
    return await _walkerPost("/walker/github_ops", payload);
}

"""Get git status for a project."""
async def:pub gitStatus(projectId: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "status"};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""List git branches."""
async def:pub gitBranches(projectId: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "branches"};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Checkout a branch."""
async def:pub gitCheckout(projectId: str, branch: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "checkout", "branch": branch};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Create a new branch."""
async def:pub gitCreateBranch(projectId: str, branch: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "create_branch", "branch": branch};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Get git diff."""
async def:pub gitDiff(projectId: str, fromRef: str = "", toRef: str = "", worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "diff", "from_ref": fromRef, "to_ref": toRef};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Get working tree diff."""
async def:pub gitDiffWorking(projectId: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "diff_working"};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Get staged diff."""
async def:pub gitDiffStaged(projectId: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "diff_staged"};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Get last commit diff (HEAD~1..HEAD)."""
async def:pub gitDiffLastCommit(projectId: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "diff_last_commit"};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Get file content at a specific git ref."""
async def:pub gitShowFile(projectId: str, ref: str, filePath: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "show_file", "from_ref": ref, "file_path": filePath};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Read file content from working tree on disk."""
async def:pub gitReadWorkingFile(projectId: str, filePath: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "read_working_file", "file_path": filePath};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Commit all changes."""
async def:pub gitCommit(projectId: str, message: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "commit", "message": message};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Stage a single file."""
async def:pub gitStageFile(projectId: str, filePath: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "stage_file", "file_path": filePath};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Unstage a single file."""
async def:pub gitUnstageFile(projectId: str, filePath: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "unstage_file", "file_path": filePath};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Commit only staged files."""
async def:pub gitCommitStaged(projectId: str, message: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "commit_staged", "message": message};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Delete a branch."""
async def:pub gitDeleteBranch(projectId: str, branch: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "delete_branch", "branch": branch};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Push to remote."""
async def:pub gitPush(projectId: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "push"};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Pull from remote."""
async def:pub gitPull(projectId: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "pull"};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Get commit log."""
async def:pub gitLog(projectId: str, limit: int = 20, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "log", "limit": limit};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Add remote origin."""
async def:pub gitRemoteAdd(projectId: str, remoteUrl: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "remote_add", "remote_url": remoteUrl};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""List remotes."""
async def:pub gitRemotes(projectId: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "remotes"};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Remove a remote by name."""
async def:pub gitRemoteRemove(projectId: str, remoteName: str = "origin", worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "remote_remove", "remote_name": remoteName};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Merge a branch into the current branch (on main repo)."""
async def:pub gitMerge(projectId: str, branch: str) -> Any {
    return await _walkerPost("/walker/git_ops", {
        "project_id": projectId,
        "action": "merge",
        "branch": branch
    });
}

"""Create a checkpoint."""
async def:pub gitCheckpointCreate(projectId: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "checkpoint_create"};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Restore a checkpoint."""
async def:pub gitCheckpointRestore(projectId: str, checkpointRef: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "checkpoint_restore", "from_ref": checkpointRef};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Get diff from checkpoint."""
async def:pub gitCheckpointDiff(projectId: str, checkpointRef: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "checkpoint_diff", "from_ref": checkpointRef};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/git_ops", params);
}

"""Stop preview via HTTP (awaitable, unlike the fire-and-forget WS stop)."""
async def:pub idePreviewStop(projectId: str) -> Any {
    return await _walkerPost("/walker/preview_control", {
        "project_id": projectId,
        "action": "stop"
    });
}

async def:pub idePreviewStartWithWorktree(projectId: str, worktreePath: str = "") -> Any {
    params: dict = {"project_id": projectId, "action": "start"};
    if worktreePath { params["worktree_path"] = worktreePath; }
    return await _walkerPost("/walker/preview_control", params);
}
