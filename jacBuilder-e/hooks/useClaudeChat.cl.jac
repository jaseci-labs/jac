"""Claude Code chat hook — manages Claude CLI streaming, tool activity, provider toggle, and thread persistence."""

import from react { useState, useRef, useEffect, useCallback }
import from ..services.ideService {
    claudeChatStart, claudeChatInterrupt, claudeChatStop, claudeCheck, sendWsRequest,
    claudeListThreads, claudeGetThread, claudeDeleteThread, claudeRenameThread,
    claudeCleanupWorktrees, claudePersistTurn, claudeClearThread, claudeMergeThread,
    idePreviewStop
}

"""Hook for Claude Code chat: streaming text, tool timeline, provider toggle.
Uses WebSocket polling via sendWsRequest (same pattern as useChatMode)."""
def:pub useClaudeChat(ide: Any) -> Any {
    has messages: list = [];
    has isLoading: bool = False;
    has chatError: str = "";
    has activities: list = [];
    has streamingText: str = "";
    has claudeAvailable: bool | None = None;
    has aiProvider: str = "jaccoder";
    has activeThreadId: str = "";
    has threads: list = [];
    has threadsLoading: bool = False;
    has envMode: str = "local";
    has threadBranch: str = "";
    has threadWorktreePath: str = "";

    scrollRef = useRef(None);
    pollTimerRef = useRef(None);
    activitiesRef = useRef([]);
    streamingTextRef = useRef("");
    syncedFilesRef = useRef([]);
    thinkingTextRef = useRef("");
    activeThreadIdRef = useRef("");
    userScrolledUpRef = useRef(False);
    has showJumpToLatest: bool = False;

    # Smart auto-scroll: combined listener + scroll-to-bottom + jump indicator.
    # Handles both ScrollArea (finds [data-viewport] child) and plain div containers.
    # Re-runs on every content change so the listener always re-attaches to the
    # correct DOM node after conditional renders. Cleanup prevents accumulation.
    useEffect(lambda -> Any {
        if not scrollRef.current { return; }
        # Support both Radix ScrollArea (viewport child) and plain div
        viewport = scrollRef.current.querySelector("[data-viewport]") or scrollRef.current;
        def onScroll() -> None {
            threshold = 50;
            atBottom = viewport.scrollTop + viewport.clientHeight >= viewport.scrollHeight - threshold;
            if atBottom {
                userScrolledUpRef.current = False;
                showJumpToLatest = False;
            } else {
                userScrolledUpRef.current = True;
                showJumpToLatest = True;
            }
        }
        viewport.addEventListener("scroll", onScroll);
        if not userScrolledUpRef.current {
            viewport.scrollTop = viewport.scrollHeight;
        } else {
            showJumpToLatest = True;
        }
        return lambda -> Any { viewport.removeEventListener("scroll", onScroll); };
    }, [messages, activities, streamingText]);

    # Cleanup on unmount
    useEffect(lambda -> Any {
        return lambda -> None {
            if pollTimerRef.current {
                clearTimeout(pollTimerRef.current);
                pollTimerRef.current = None;
            }
        };
    }, []);

    # Check Claude availability on mount
    useEffect(lambda -> None {
        async def checkAvail() -> None {
            result = await claudeCheck();
            if result and result.available {
                claudeAvailable = True;
            } else {
                claudeAvailable = False;
            }
        }
        checkAvail();
    }, []);

    # Load thread list when project changes; clear old state
    useEffect(lambda -> None {
        if not ide.projectId { return; }
        # Clear state from previous project
        activeThreadId = "";
        activeThreadIdRef.current = "";
        messages = [];
        activities = [];
        streamingText = "";
        chatError = "";
        threadBranch = "";
        threadWorktreePath = "";
        loadThreads();
    }, [ide.projectId]);

    async def loadThreads() -> None {
        if not ide.projectId { return; }
        threadsLoading = True;
        try {
            result = await claudeListThreads(ide.projectId);
            if result and result.success {
                threads = result.threads or [];
            }
        } except Exception as e {
            console.error("[useClaudeChat] loadThreads error:", e);
        }
        threadsLoading = False;
    }

    async def loadThread(threadId: str) -> None {
        if not ide.projectId or not threadId { return; }
        # Stop any active Claude turn before switching threads
        if isLoading {
            _stopPolling();
            await claudeChatInterrupt(ide.projectId);
            isLoading = False;
        }
        try {
            result = await claudeGetThread(ide.projectId, threadId);
            if result and result.success {
                activeThreadId = threadId;
                activeThreadIdRef.current = threadId;
                loadedMsgs: list = [];
                rawMsgs = result.messages or [];
                for m in rawMsgs {
                    loadedMsgs.push({
                        "role": m.role,
                        "content": m.content,
                        "turn_number": m.turn_number,
                        "timestamp": m.created_at
                    });
                }
                messages = loadedMsgs;

                # Restore persisted activities (thinking logs, tool calls)
                loadedActs: list = [];
                rawActs = result.activities or [];
                for a in rawActs {
                    loadedActs.push({
                        "type": a.activity_type or "tool",
                        "tool": a.tool_name or "",
                        "message": a.message or "",
                        "status": a.status or "",
                        "timestamp": a.created_at or "",
                        "turn_number": a.turn_number or 0
                    });
                }
                activities = loadedActs;
                activitiesRef.current = loadedActs;

                streamingText = "";
                chatError = "";

                # Restore worktree state from thread
                threadInfo = result.thread;
                prevWorktreePath = threadWorktreePath;
                if threadInfo {
                    threadBranch = threadInfo.branch or "";
                    threadWorktreePath = threadInfo.worktree_path or "";
                    envMode = "worktree" if threadInfo.worktree_path else "local";
                }

                # Auto-restart preview if worktree changed
                newWt = threadInfo.worktree_path or "" if threadInfo else "";
                if newWt != prevWorktreePath {
                    _restartPreview(newWt);
                }
            }
        } except Exception as e {
            console.error("[useClaudeChat] loadThread error:", e);
        }
    }

    async def deleteThread(threadId: str) -> None {
        if not ide.projectId or not threadId { return; }
        try {
            # Check if this is the local thread (no worktree_path) — clear instead of delete
            isLocalThread = False;
            for t in threads {
                if t.id == threadId and not t.worktree_path {
                    isLocalThread = True;
                    break;
                }
            }
            if isLocalThread {
                # Local thread: clear messages but keep the thread node
                result = await claudeClearThread(ide.projectId, threadId);
                if result and result.success {
                    if activeThreadId == threadId {
                        messages = [];
                        activities = [];
                        streamingText = "";
                    }
                    await loadThreads();
                }
                return;
            }
            result = await claudeDeleteThread(ide.projectId, threadId);
            if result and result.success {
                if activeThreadId == threadId {
                    activeThreadId = "";
                    activeThreadIdRef.current = "";
                    messages = [];
                    activities = [];
                    streamingText = "";
                }
                await loadThreads();
            }
        } except Exception as e {
            console.error("[useClaudeChat] deleteThread error:", e);
        }
    }

    async def renameThread(threadId: str, title: str) -> None {
        if not ide.projectId or not threadId { return; }
        try {
            await claudeRenameThread(ide.projectId, threadId, title);
            await loadThreads();
        } except Exception as e {
            console.error("[useClaudeChat] renameThread error:", e);
        }
    }

    def startNewThread() -> None {
        prevWorktreePath = threadWorktreePath;

        # Find the existing local thread (no worktree_path) from thread list
        localThread = None;
        for t in threads {
            if not t.worktree_path {
                localThread = t;
                break;
            }
        }

        if localThread {
            # Reuse existing local thread — load its messages
            loadThreadFn = loadThread;
            loadThreadFn.call(None, localThread.id);
        } else {
            # No local thread yet — reset to blank (will be created on first message)
            activeThreadId = "";
            activeThreadIdRef.current = "";
            messages = [];
            activities = [];
            streamingText = "";
            chatError = "";
            isLoading = False;
            envMode = "local";
            threadBranch = "";
            threadWorktreePath = "";
        }

        # Auto-restart preview from default dir if was running from worktree
        if prevWorktreePath {
            _restartPreview("");
        }
    }

    async def mergeThread(threadId: str) -> Any {
        if not ide.projectId or not threadId { return None; }
        try {
            result = await claudeMergeThread(ide.projectId, threadId);
            if result and result.success {
                # Thread is now merged — switch to local thread
                activeThreadId = "";
                activeThreadIdRef.current = "";
                messages = [];
                activities = [];
                streamingText = "";
                envMode = "local";
                threadBranch = "";
                threadWorktreePath = "";
                await loadThreads();

                # Restart preview from main repo
                await _restartPreview("");
            }
            return result;
        } except Exception as e {
            console.error("[useClaudeChat] mergeThread error:", e);
            return None;
        }
    }

    async def cleanupWorktrees() -> None {
        if not ide.projectId { return; }
        try {
            await claudeCleanupWorktrees(ide.projectId);
        } except Exception as e {
            console.error("[useClaudeChat] cleanupWorktrees error:", e);
        }
    }

    async def _restartPreview(worktreePath: str = "") -> None {
        if not ide.projectId { return; }
        await idePreviewStop(ide.projectId);
        if ide.startPreview {
            startFn = ide.startPreview;
            startFn.call(None, worktreePath);
        }
    }

    def _stopPolling() -> None {
        if pollTimerRef.current {
            clearTimeout(pollTimerRef.current);
            pollTimerRef.current = None;
        }
    }

    def toggleProvider() -> None {
        if aiProvider == "jaccoder" {
            aiProvider = "claude";
        } else {
            aiProvider = "jaccoder";
        }
    }

    async def sendMessage(text: str, images: list = []) -> None {
        trimmedText = text.trim();
        if not trimmedText or isLoading { return; }
        if not ide.projectId { return; }

        # Reset scroll lock so the response is followed automatically
        userScrolledUpRef.current = False;

        # Add user message
        userMsg: Any = {
            "role": "user",
            "content": trimmedText,
            "timestamp": Date.now()
        };
        if images and images.length > 0 {
            userMsg.images = images;
        }
        messages = lambda prev: Any -> Any { return prev.concat([userMsg]); };

        isLoading = True;
        chatError = "";
        activities = [];
        activitiesRef.current = [];
        streamingTextRef.current = "";
        streamingText = "";
        syncedFilesRef.current = [];
        thinkingTextRef.current = "";

        # Start Claude turn (HTTP — just the initial kick, returns immediately)
        result = await claudeChatStart(
            ide.projectId, trimmedText, "", "Read,Edit,Bash,Glob,Grep,Write",
            activeThreadId, envMode, threadBranch, images
        );

        if not result or not result.success {
            errMsg = "Claude request failed";
            if result and result.error {
                errMsg = result.error;
            }
            chatError = errMsg;
            errorMsg = {
                "role": "error",
                "content": errMsg,
                "timestamp": Date.now()
            };
            messages = lambda prev: Any -> Any { return prev.concat([errorMsg]); };
            isLoading = False;
            return;
        }

        # Capture thread_id and worktree info from response
        if result.thread_id {
            activeThreadId = result.thread_id;
            activeThreadIdRef.current = result.thread_id;
        }
        newWtPath = "";
        if result.worktree_path {
            newWtPath = result.worktree_path;
            threadWorktreePath = result.worktree_path;
        }
        if result.branch {
            threadBranch = result.branch;
        }
        if result.env_mode {
            envMode = result.env_mode;
        }

        # If worktree was just created and preview is running from wrong dir, restart it
        previewWt = ide.previewWorktreePath or "";
        if newWtPath and newWtPath != previewWt {
            _restartPreview(newWtPath);
        }

        # Add streaming placeholder
        streamingMsg = {
            "role": "assistant",
            "content": "",
            "isStreaming": True,
            "activities": [],
            "timestamp": Date.now()
        };
        messages = lambda prev: Any -> Any { return prev.concat([streamingMsg]); };

        # Start WebSocket polling (same pattern as useChatMode)
        _startEventPolling();
    }

    def _startEventPolling() -> None {
        idleCountRef = {"current": 0};

        def pollOnce() -> None {
            if not ide.projectId or not ide.userId { return; }

            sendWsRequest("claude_events", ide.userId, ide.projectId, 0, lambda(msg: Any) -> None {
                try {
                    data = msg.data if msg and msg.data else msg;
                    if not data or not data.success {
                        pollTimerRef.current = setTimeout(pollOnce, 500);
                        return;
                    }

                    events = data.events or [];
                    stillProcessing = data.processing;
                    isDone = False;
                    doneContent = "";

                    for evt in events {
                        evtType = evt.type or "";

                        if evtType == "claude_text_delta" {
                            chunk = evt.text or "";
                            streamingTextRef.current = streamingTextRef.current + chunk;
                            streamingText = streamingTextRef.current;

                        } elif evtType == "claude_tool_start" {
                            thinkingTextRef.current = "";
                            activitiesRef.current = activitiesRef.current.concat([{
                                "type": "activity",
                                "tool": evt.tool_name or "",
                                "tool_id": evt.tool_id or "",
                                "message": evt.tool_name or "",
                                "timestamp": Date.now()
                            }]);

                        } elif evtType == "claude_tool_end" {
                            activitiesRef.current = activitiesRef.current.map(lambda (a: Any, i: int) -> Any {
                                if i == activitiesRef.current.length - 1 and not a.status {
                                    return Object.assign({}, a, {"status": "done"});
                                }
                                return a;
                            });

                        } elif evtType == "claude_message_complete" {
                            content = evt.content or "";
                            if content {
                                doneContent = content;
                            }

                        } elif evtType == "claude_done" {
                            isDone = True;
                            if evt.is_error {
                                doneContent = "Error during Claude turn.";
                            }

                        } elif evtType == "claude_error" {
                            isDone = True;
                            doneContent = "Error: " + (evt.error or "Unknown error");

                        } elif evtType == "claude_file_synced" {
                            syncedPath = evt.path or "";
                            syncedFilesRef.current = syncedFilesRef.current.concat([syncedPath]);
                            ide.refreshFiles();
                            # Immediately reload this tab if it's open so editor
                            # shows Claude's changes (prevents stale-content overwrite on save)
                            if syncedPath {
                                ide.closeTab(syncedPath);
                                ide.openFile(syncedPath);
                            }

                        } elif evtType == "claude_version_saved" {
                            ide.refreshFiles();
                            ide.refreshVersions();

                        } elif evtType == "claude_thinking_delta" {
                            thinkText = evt.text or "";
                            if thinkText {
                                thinkingTextRef.current = thinkingTextRef.current + thinkText;
                                truncated = thinkingTextRef.current.slice(-200);
                                lastAct = activitiesRef.current[activitiesRef.current.length - 1];
                                if lastAct and lastAct.type == "thinking" {
                                    activitiesRef.current = activitiesRef.current.slice(0, -1).concat([{
                                        "type": "thinking",
                                        "message": truncated,
                                        "timestamp": lastAct.timestamp
                                    }]);
                                } else {
                                    activitiesRef.current = activitiesRef.current.concat([{
                                        "type": "thinking",
                                        "message": truncated,
                                        "timestamp": Date.now()
                                    }]);
                                }
                            }

                        } elif evtType == "claude_check_retry" {
                            activitiesRef.current = activitiesRef.current.concat([{
                                "type": "activity",
                                "tool": "jac_check",
                                "message": "jac check found errors — auto-fixing (attempt " + String(evt.attempt or 1) + ")",
                                "timestamp": Date.now()
                            }]);

                        } elif evtType == "claude_check_failed" {
                            activitiesRef.current = activitiesRef.current.concat([{
                                "type": "activity",
                                "tool": "jac_check",
                                "message": "jac check still has errors after retries",
                                "status": "error",
                                "timestamp": Date.now()
                            }]);

                        } elif evtType == "claude_check_passed" {
                            activitiesRef.current = activitiesRef.current.concat([{
                                "type": "activity",
                                "tool": "jac_check",
                                "message": "jac check passed after " + String(evt.attempts or 1) + " attempts",
                                "status": "done",
                                "timestamp": Date.now()
                            }]);
                        }
                    }

                    # Update activities state
                    activities = [].concat(activitiesRef.current);

                    # Update streaming message
                    currentText = streamingTextRef.current;
                    currentActs = activitiesRef.current;
                    messages = lambda prev: Any -> Any {
                        return prev.map(lambda m: Any -> Any {
                            if m.isStreaming {
                                return Object.assign({}, m, {
                                    "content": currentText,
                                    "activities": currentActs
                                });
                            }
                            return m;
                        });
                    };

                    if isDone {
                        _handleDone(doneContent);
                        return;
                    }

                    # Idle tracking
                    if not stillProcessing and events.length == 0 {
                        idleCountRef.current = (idleCountRef.current or 0) + 1;
                    } else {
                        idleCountRef.current = 0;
                    }

                    if idleCountRef.current >= 30 {
                        console.warn("[useClaudeChat] Stopping poll: 30 consecutive idle cycles");
                        _handleDone("Claude did not respond. Please try again.");
                        return;
                    }

                    pollTimerRef.current = setTimeout(pollOnce, 500);

                } except Exception as e {
                    console.error("[useClaudeChat] WS poll error:", e);
                    pollTimerRef.current = setTimeout(pollOnce, 1000);
                }
            });
        }

        # Start first poll after a short delay
        pollTimerRef.current = setTimeout(pollOnce, 300);
    }

    def _handleDone(finalContent: str) -> None {
        _stopPolling();

        # Use streaming text if no explicit final content
        content = finalContent;
        if not content or not content.trim() {
            content = streamingTextRef.current or "Done.";
        }

        finalActs = [].concat(activitiesRef.current);

        # Replace streaming message with final
        messages = lambda prev: Any -> Any {
            return prev.map(lambda m: Any -> Any {
                if m.isStreaming {
                    return {
                        "role": "assistant",
                        "content": content,
                        "activities": finalActs,
                        "timestamp": Date.now()
                    };
                }
                return m;
            });
        };

        # Persist assistant message + activities to backend thread (WS polling doesn't persist).
        # Use activeThreadIdRef (not activeThreadId state) to avoid stale closure
        # on the first turn — useState updates are async and the closure from
        # _startEventPolling captures the old value before re-render.
        persistContent = content;
        persistThreadId = activeThreadIdRef.current;
        persistProjectId = ide.projectId;
        if persistThreadId and persistProjectId {
            claudePersistTurn(persistProjectId, persistThreadId, persistContent, finalActs);
        }

        # Refresh file tree and versions (Claude edited files + created git commit)
        ide.refreshFiles();
        ide.refreshVersions();

        # Reload ALL open tabs that Claude modified (not just active tab)
        syncedSet = syncedFilesRef.current;
        if syncedSet.length > 0 {
            currentActive = ide.activeTab;
            for syncedPath in syncedSet {
                ide.closeTab(syncedPath);
            }
            for syncedPath in syncedSet {
                ide.openFile(syncedPath);
            }
            # Restore focus to the previously active tab if it was open
            if currentActive {
                ide.openFile(currentActive);
            }
            # Check if preview needs restart: either not running, or running
            # from wrong directory (e.g. /tmp while thread is in worktree)
            wtPath = threadWorktreePath or "";
            previewWt = ide.previewWorktreePath or "";
            needsRestart = False;
            if ide.previewStatus == "stopped" {
                needsRestart = True;
            } elif wtPath and wtPath != previewWt {
                needsRestart = True;
            }

            if needsRestart {
                _restartPreview(wtPath);
            } else {
                # Preview is running from correct dir — just refresh iframe
                setTimeout(lambda -> None {
                    ide.refreshPreview();
                }, 3000);
            }
        }

        isLoading = False;
        activities = [];
        activitiesRef.current = [];
        streamingTextRef.current = "";
        streamingText = "";
        syncedFilesRef.current = [];

        # Refresh thread list (new thread may have been created)
        loadThreads();
    }

    async def interruptClaude() -> None {
        if ide.projectId {
            await claudeChatInterrupt(ide.projectId);
        }
    }

    async def stopSession() -> None {
        _stopPolling();
        if ide.projectId {
            await claudeChatStop(ide.projectId);
        }
        isLoading = False;
    }

    async def clearChat() -> None {
        _stopPolling();
        messages = [];
        chatError = "";
        activities = [];
        streamingText = "";
        isLoading = False;
        # Clear messages on backend for the active thread (especially local thread)
        clearThreadId = activeThreadId;
        clearProjectId = ide.projectId;
        if clearThreadId and clearProjectId {
            await claudeClearThread(clearProjectId, clearThreadId);
        }
    }

    return {
        "messages": messages,
        "isLoading": isLoading,
        "chatError": chatError,
        "activities": activities,
        "streamingText": streamingText,
        "claudeAvailable": claudeAvailable,
        "aiProvider": aiProvider,
        "scrollRef": scrollRef,
        "activeThreadId": activeThreadId,
        "threads": threads,
        "threadsLoading": threadsLoading,
        "envMode": envMode,
        "threadBranch": threadBranch,
        "threadWorktreePath": threadWorktreePath,
        "showJumpToLatest": showJumpToLatest,
        "scrollToLatest": lambda -> None {
            if scrollRef.current {
                viewport = scrollRef.current.querySelector("[data-viewport]") or scrollRef.current;
                viewport.scrollTo({"top": viewport.scrollHeight, "behavior": "smooth"});
                userScrolledUpRef.current = False;
                showJumpToLatest = False;
            }
        },
        "toggleProvider": toggleProvider,
        "sendMessage": sendMessage,
        "interruptClaude": interruptClaude,
        "stopSession": stopSession,
        "clearChat": clearChat,
        "loadThread": loadThread,
        "loadThreads": loadThreads,
        "deleteThread": deleteThread,
        "renameThread": renameThread,
        "startNewThread": startNewThread,
        "setEnvMode": setEnvMode,
        "setThreadBranch": setThreadBranch,
        "mergeThread": mergeThread,
        "cleanupWorktrees": cleanupWorktrees
    };
}
