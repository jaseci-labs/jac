"""Frontend LSP protocol layer — wraps WebSocket into high-level LSP client."""

import from ..services.ideService { sendLspRequest, closeLspWs }

glob _nextReqId: int = 1;
glob _pendingCallbacks: Any = {};
glob _notificationHandler: Any = None;
glob _pollTimer: Any = None;
glob _lspReady: bool = False;
glob _lspUserId: str = "";
glob _lspProjectId: str = "";

"""Get next request ID and increment counter."""
def _getNextId() -> int {
    currentId = _nextReqId;
    _nextReqId = currentId + 1;
    return currentId;
}

"""Handle response from WebSocket — route to pending callbacks or notification handler."""
def _handleLspWsResponse(msg: Any) -> None {
    if not msg or not msg.data { return; }
    data = msg.data;
    if not data.success { return; }
    resp = data.response;
    if resp and resp.id != undefined and _pendingCallbacks[String(resp.id)] {
        cb = _pendingCallbacks[String(resp.id)];
        _pendingCallbacks[String(resp.id)] = undefined;
        cb.call(None, resp);
    }
    notifications = data.notifications;
    if notifications and notifications.length > 0 and _notificationHandler {
        handler = _notificationHandler;
        for n in notifications {
            handler.call(None, n);
        }
    }
}

"""Handle poll response — route notifications."""
def _handlePollResponse(msg: Any) -> None {
    if not msg or not msg.data { return; }
    data = msg.data;
    if not data.success { return; }
    notifications = data.notifications;
    if notifications and notifications.length > 0 and _notificationHandler {
        handler = _notificationHandler;
        for n in notifications {
            handler.call(None, n);
        }
    }
}

"""Schedule a single poll after a delay (debounced). Called after sending notifications."""
def _schedulePoll() -> None {
    if not _lspReady { return; }
    if _pollTimer {
        clearTimeout(_pollTimer);
    }
    _pollTimer = setTimeout(lambda {
        _pollTimer = None;
        if not _lspReady { return; }
        sendLspRequest("poll", _lspUserId, _lspProjectId, {}, lambda(msg: Any) {
            _handlePollResponse(msg);
        });
    }, 500);
}

"""Stop any pending poll timer."""
def _stopPolling() -> None {
    if _pollTimer {
        clearTimeout(_pollTimer);
        _pollTimer = None;
    }
}

"""Initialize LSP connection: start subprocess, send initialize, then initialized."""
def:pub lspInit(userId: str, projectId: str, workspaceDir: str, onReady: Any) -> None {
    _lspReady = False;
    _nextReqId = 1;
    _pendingCallbacks = {};
    _lspUserId = userId;
    _lspProjectId = projectId;
    sendLspRequest("init", userId, projectId, {"workspace_dir": workspaceDir}, lambda(msg: Any) {
        if not msg or not msg.data or not msg.data.success {
            console.error("LSP init failed:", msg);
            return;
        }
        initId = _getNextId();
        initMsg = {
            "jsonrpc": "2.0",
            "id": initId,
            "method": "initialize",
            "params": {
                "processId": None,
                "rootUri": "file://" + workspaceDir,
                "capabilities": {
                    "workspace": {
                        "symbol": {
                            "dynamicRegistration": False,
                            "symbolKind": {
                                "valueSet": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
                            }
                        }
                    },
                    "textDocument": {
                        "completion": {
                            "completionItem": {
                                "snippetSupport": False
                            }
                        },
                        "hover": {"contentFormat": ["markdown", "plaintext"]},
                        "publishDiagnostics": {"relatedInformation": True},
                        "definition": {},
                        "references": {},
                        "documentSymbol": {}
                    }
                }
            }
        };
        sendLspRequest("message", userId, projectId, initMsg, lambda(resp: Any) {
            if resp and resp.data and resp.data.response {
                initializedMsg = {"jsonrpc": "2.0", "method": "initialized", "params": {}};
                sendLspRequest("message", userId, projectId, initializedMsg, lambda(_: Any) {
                    _lspReady = True;
                    if onReady {
                        readyCb = onReady;
                        readyCb.call(None);
                    }
                });
            } else {
                console.error("LSP initialize failed:", resp);
            }
        });
    });
}

"""Send an LSP request (expects a response) via WebSocket."""
def:pub lspRequest(userId: str, projectId: str, method: str, params: Any, callback: Any) -> None {
    if not _lspReady { return; }
    reqId = _getNextId();
    msg = {
        "jsonrpc": "2.0",
        "id": reqId,
        "method": method,
        "params": params
    };
    _pendingCallbacks[String(reqId)] = callback;
    sendLspRequest("message", userId, projectId, msg, lambda(resp: Any) {
        _handleLspWsResponse(resp);
    });
}

"""Send an LSP notification (no response expected) via WebSocket. Schedules a poll for diagnostics."""
def:pub lspNotify(userId: str, projectId: str, method: str, params: Any) -> None {
    if not _lspReady { return; }
    msg = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params
    };
    sendLspRequest("message", userId, projectId, msg, lambda(resp: Any) {
        _handleLspWsResponse(resp);
    });
    _schedulePoll();
}

"""Set the handler for server-initiated notifications (e.g. diagnostics)."""
def:pub lspSetNotificationHandler(handler: Any) -> None {
    _notificationHandler = handler;
}

"""Shutdown LSP: stop polling, send shutdown+exit, close WS."""
def:pub lspShutdown(userId: str, projectId: str) -> None {
    _lspReady = False;
    _stopPolling();
    _pendingCallbacks = {};
    sendLspRequest("close", userId, projectId, {}, lambda(_: Any) { });
}
