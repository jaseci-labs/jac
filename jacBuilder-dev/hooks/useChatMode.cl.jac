"""Chat Mode state management hook with streaming AI events."""

import from react { useState, useRef, useEffect, useCallback }
import from ..services.ideService { ideChatStart, ideChatStop, ideChatLoadHistory, ideChatClearHistory, ideChatPersistResult, ideChatRevertToMessage, sendWsRequest }

"""Hook for managing Chat Mode: messages, sending, streaming events, and mode toggle."""
def:pub useChatMode(ide: Any) -> Any {
    has messages: list = [];
    has isLoading: bool = False;
    has chatError: str = "";
    has isChatMode: bool = False;
    has activities: list = [];

    scrollRef = useRef(None);
    pollTimerRef = useRef(None);
    activitiesRef = useRef([]);
    promotedFilesRef = useRef([]);
    sendingRef = useRef(False);
    checkpointRefRef = useRef("");
    userScrolledUpRef = useRef(False);
    has showJumpToLatest: bool = False;

    # Smart auto-scroll: combined listener + scroll-to-bottom + jump indicator.
    # Runs on every messages/activities change so the listener always re-attaches
    # to the correct DOM node even when ChatPanel is conditionally unmounted/remounted.
    # Cleanup removes the old listener before the next run, preventing accumulation.
    useEffect(lambda -> Any {
        el = scrollRef.current;
        if not el { return; }
        def onScroll() -> None {
            threshold = 50;
            atBottom = el.scrollTop + el.clientHeight >= el.scrollHeight - threshold;
            if atBottom {
                userScrolledUpRef.current = False;
                showJumpToLatest = False;
            } else {
                userScrolledUpRef.current = True;
                showJumpToLatest = True;
            }
        }
        el.addEventListener("scroll", onScroll);
        if not userScrolledUpRef.current {
            el.scrollTop = el.scrollHeight;
        } else {
            showJumpToLatest = True;
        }
        return lambda -> None { el.removeEventListener("scroll", onScroll); };
    }, [messages, activities]);

    has historyLoaded: bool = False;

    # Load persisted chat history when project changes
    useEffect(lambda -> None {
        if not ide.projectId { return; }
        historyLoaded = False;
        loadHistoryFn = ideChatLoadHistory;
        loadHistoryFn.call(None, ide.projectId).then(lambda(result: Any) -> None {
            if result and result.success and result.messages and result.messages.length > 0 {
                # Reconstruct build blocks from persisted activities_log
                restoredMsgs: list = [];
                for m in result.messages {
                    if m.role == "assistant" and m.activities_log and m.activities_log.length > 0 {
                        # Insert a build block before the assistant message with all activities
                        restoredMsgs.push({
                            "role": "assistant",
                            "isBuildBlock": True,
                            "activities": m.activities_log,
                            "timestamp": m.timestamp or ""
                        });
                    }
                    restoredMsgs.push(m);
                }
                messages = restoredMsgs;
            } else {
                messages = [];
            }
            historyLoaded = True;
        }).catch(lambda(err: Any) -> None {
            console.error("[useChatMode] Failed to load history:", err);
            historyLoaded = True;
        });
    }, [ide.projectId]);

    # Cleanup poll timer on unmount
    useEffect(lambda -> Any {
        return lambda -> None {
            if pollTimerRef.current {
                clearTimeout(pollTimerRef.current);
                pollTimerRef.current = None;
            }
        };
    }, []);

    def _stopPolling() -> None {
        if pollTimerRef.current {
            clearTimeout(pollTimerRef.current);
            pollTimerRef.current = None;
        }
    }

    def toggleChatMode() -> None {
        isChatMode = not isChatMode;
    }

    async def stopAgent() -> None {
        if not isLoading or not ide.projectId { return; }
        # Finalize the UI immediately — convert streaming message to done state
        _handleDone([{"type": "agent_done", "response": "Interrupted by user."}]);
        # Then tell the server to abort
        try {
            await ideChatStop(ide.projectId);
        } except Exception as err {
            console.error("[useChatMode] Stop failed:", err);
        }
    }

    async def sendMessage(text: str, images: list = []) -> None {
        trimmedText = text.trim();
        if not trimmedText or isLoading or sendingRef.current { return; }
        if not ide.projectId { return; }
        sendingRef.current = True;

        # Reset scroll lock — user just sent a message, auto-scroll to follow the response
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
        promotedFilesRef.current = [];
        checkpointRefRef.current = "";

        # Start AI processing (non-blocking — returns immediately)
        result = await ideChatStart(
            ide.projectId,
            trimmedText,
            ide.activeTab or "",
            images
        );

        # Save checkpoint ref for per-message undo
        if result and result.checkpoint_ref {
            checkpointRefRef.current = result.checkpoint_ref;
        }

        if not result or not result.success {
            errMsg = "AI request failed";
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
            sendingRef.current = False;
            return;
        }

        # Add streaming placeholder message
        streamingMsg = {
            "role": "assistant",
            "content": "",
            "isStreaming": True,
            "activities": [],
            "timestamp": Date.now()
        };
        messages = lambda prev: Any -> Any { return prev.concat([streamingMsg]); };

        # Start polling for events via existing preview WebSocket
        _startEventPolling();
    }

    def _startEventPolling() -> None {
        # Track consecutive polls where processing=False and no events
        idleCountRef = {"current": 0};
        errorCountRef = {"current": 0};

        def pollOnce() -> None {
            if not ide.projectId or not ide.userId { return; }

            sendWsRequest("ai_events", ide.userId, ide.projectId, 0, lambda(msg: Any) -> None {
                try {
                    data = msg.data if msg and msg.data else msg;
                    if not data or not data.success {
                        errorCountRef.current = (errorCountRef.current or 0) + 1;
                        if errorCountRef.current >= 10 {
                            console.warn("[useChatMode] Stopping poll: 10 consecutive WS failures");
                            _handleDone([{"type": "agent_error", "error": "Connection lost. Please try again."}]);
                            return;
                        }
                        pollTimerRef.current = setTimeout(pollOnce, 500);
                        return;
                    }
                    errorCountRef.current = 0;

                    events = data.events or [];
                    stillProcessing = data.processing;
                    isDone = False;

                    # Process each event
                    for evt in events {
                        evtType = evt.type or "";

                        if evtType == "file_promoted" or evtType == "file_promoted_with_warning" {
                            filePath = evt.path or "";
                            activitiesRef.current = activitiesRef.current.concat([{
                                "type": evtType,
                                "path": filePath,
                                "warning": evt.error or "",
                                "timestamp": Date.now()
                            }]);
                            promotedFilesRef.current = promotedFilesRef.current.concat([filePath]);

                            # Refresh file tree as files are promoted
                            ide.refreshFiles();

                        } elif evtType == "file_failed" {
                            activitiesRef.current = activitiesRef.current.concat([{
                                "type": "file_failed",
                                "path": evt.path or "",
                                "error": evt.error or "",
                                "timestamp": Date.now()
                            }]);

                        } elif evtType == "agent_activity" {
                            activitiesRef.current = activitiesRef.current.concat([{
                                "type": "activity",
                                "tool": evt.tool or "",
                                "detail": evt.detail or "",
                                "message": evt.message or "",
                                "step": evt.step or 0,
                                "timestamp": Date.now()
                            }]);

                        } elif evtType == "agent_tool_done" {
                            # Update matching activity with done status and duration
                            doneStep = evt.step or 0;
                            activitiesRef.current = activitiesRef.current.map(lambda a: Any -> Any {
                                if a.step and a.step == doneStep {
                                    return Object.assign({}, a, {
                                        "status": evt.status or "done",
                                        "duration_ms": evt.duration_ms or 0
                                    });
                                }
                                return a;
                            });

                        } elif evtType == "llm_thought" {
                            thoughtContent = evt.content or "";
                            if thoughtContent {
                                # Check if this is agent narration (starts with user-facing text)
                                # vs internal reasoning
                                trimmedThought = thoughtContent.trim();
                                isNarration = False;
                                narrationPrefixes = ["I'll ", "I will ", "Let me ", "I need to ",
                                    "I should ", "I'm going to ", "Now I'll ", "First, ",
                                    "Next, ", "Now, ", "The ", "This ", "Here "];
                                for np in narrationPrefixes {
                                    if trimmedThought.startsWith(np) {
                                        isNarration = True;
                                        break;
                                    }
                                }

                                if isNarration {
                                    # Show as inline narration text (Claude Code style)
                                    activitiesRef.current = activitiesRef.current.concat([{
                                        "type": "agent_text",
                                        "message": trimmedThought,
                                        "iteration": evt.iteration or 0,
                                        "timestamp": Date.now()
                                    }]);
                                } else {
                                    # Aggregate into thinking block — merge with last thought if consecutive
                                    lastAct = activitiesRef.current.length > 0 and activitiesRef.current[activitiesRef.current.length - 1] or None;
                                    if lastAct and lastAct.type == "llm_thought" and not lastAct.closed {
                                        # Merge into existing thought block
                                        mergedThought = Object.assign({}, lastAct, {
                                            "message": (lastAct.fullContent or lastAct.message or "") + "\n" + trimmedThought,
                                            "fullContent": (lastAct.fullContent or lastAct.message or "") + "\n" + trimmedThought,
                                            "duration_ms": Date.now() - lastAct.timestamp
                                        });
                                        activitiesRef.current = activitiesRef.current.slice(0, -1).concat([mergedThought]);
                                    } else {
                                        # Close previous thought block if any
                                        activitiesRef.current = activitiesRef.current.map(lambda th: Any -> Any {
                                            if th.type == "llm_thought" and not th.closed {
                                                return Object.assign({}, th, {"closed": True, "duration_ms": Date.now() - th.timestamp});
                                            }
                                            return th;
                                        });
                                        # Start new thought block
                                        activitiesRef.current = activitiesRef.current.concat([{
                                            "type": "llm_thought",
                                            "message": trimmedThought,
                                            "fullContent": trimmedThought,
                                            "iteration": evt.iteration or 0,
                                            "closed": False,
                                            "timestamp": Date.now()
                                        }]);
                                    }
                                }
                            }

                        } elif evtType == "llm_tool_call" {
                            # Close any open thought blocks
                            activitiesRef.current = activitiesRef.current.map(lambda tc: Any -> Any {
                                if tc.type == "llm_thought" and not tc.closed {
                                    return Object.assign({}, tc, {"closed": True, "duration_ms": Date.now() - tc.timestamp});
                                }
                                return tc;
                            });

                            callCategory = evt.category or "";
                            callLabel = evt.label or "";
                            callTool = evt.tool or "";
                            callId = evt.call_id or "";
                            callArgs = evt.args or {};

                            # Render think() tool calls as inline narration instead of a tool card
                            if callTool == "think" {
                                thinkText = "";
                                if callArgs and callArgs.THOUGHT {
                                    thinkText = String(callArgs.THOUGHT);
                                }
                                if not thinkText and callLabel {
                                    thinkText = callLabel;
                                }
                                if thinkText {
                                    activitiesRef.current = activitiesRef.current.concat([{
                                        "type": "agent_text",
                                        "message": thinkText,
                                        "callId": callId,
                                        "iteration": evt.iteration or 0,
                                        "timestamp": Date.now()
                                    }]);
                                }
                                # Update activities state + streaming message, then skip tool card creation
                                activities = [].concat(activitiesRef.current);
                                messages = lambda prev: Any -> Any {
                                    return prev.map(lambda m: Any -> Any {
                                        if m.isStreaming {
                                            return Object.assign({}, m, {"activities": activitiesRef.current});
                                        }
                                        return m;
                                    });
                                };
                                continue;
                            }

                            # Build display: "Category  label"
                            callDisplay = callCategory;
                            if callLabel and callLabel.length > 0 {
                                callDisplay = callCategory + "  " + callLabel;
                            }

                            activitiesRef.current = activitiesRef.current.concat([{
                                "type": "llm_tool_call",
                                "category": callCategory,
                                "label": callLabel,
                                "tool": callTool,
                                "callId": callId,
                                "args": callArgs,
                                "summary": evt.summary or "",
                                "message": callDisplay,
                                "detail": callLabel,
                                "iteration": evt.iteration or 0,
                                "status": "running",
                                "timestamp": Date.now()
                            }]);

                        } elif evtType == "llm_tool_result" {
                            # Suppress results for think() — the narration is already shown
                            resultToolName = evt.tool or "";
                            if resultToolName == "think" {
                                continue;
                            }

                            # Pair with the matching tool_call by call_id — update in place
                            resultCallId = evt.call_id or "";
                            resultTool = evt.tool or "";
                            resultPreview = evt.result_preview or "";
                            resultMatched = False;

                            if resultCallId {
                                activitiesRef.current = activitiesRef.current.map(lambda rc: Any -> Any {
                                    if rc.type == "llm_tool_call" and rc.callId and rc.callId == resultCallId {
                                        return Object.assign({}, rc, {
                                            "status": "done",
                                            "result": resultPreview,
                                            "duration_ms": Date.now() - rc.timestamp
                                        });
                                    }
                                    return rc;
                                });
                            } else {
                                # Fallback: match by tool name (last unfinished call of same tool)
                                foundIdx = -1;
                                idxCounter = activitiesRef.current.length - 1;
                                while idxCounter >= 0 {
                                    rcItem = activitiesRef.current[idxCounter];
                                    if rcItem.type == "llm_tool_call" and rcItem.tool == resultTool and rcItem.status == "running" {
                                        foundIdx = idxCounter;
                                        break;
                                    }
                                    idxCounter = idxCounter - 1;
                                }
                                if foundIdx >= 0 {
                                    matchedItem = activitiesRef.current[foundIdx];
                                    updatedItem = Object.assign({}, matchedItem, {
                                        "status": "done",
                                        "result": resultPreview,
                                        "duration_ms": Date.now() - matchedItem.timestamp
                                    });
                                    activitiesRef.current = activitiesRef.current.slice(0, foundIdx).concat([updatedItem]).concat(activitiesRef.current.slice(foundIdx + 1));
                                }
                            }

                        } elif evtType == "llm_steps_done" {
                            # Close any open thought blocks
                            activitiesRef.current = activitiesRef.current.map(lambda sd: Any -> Any {
                                if sd.type == "llm_thought" and not sd.closed {
                                    return Object.assign({}, sd, {"closed": True, "duration_ms": Date.now() - sd.timestamp});
                                }
                                return sd;
                            });
                            stepsIters = evt.iterations or 0;
                            activitiesRef.current = activitiesRef.current.concat([{
                                "type": "llm_steps_done",
                                "message": String(stepsIters) + " iteration" + ("s" if stepsIters != 1 else ""),
                                "timestamp": Date.now()
                            }]);

                        } elif evtType == "agent_done" {
                            isDone = True;
                        } elif evtType == "agent_error" {
                            isDone = True;
                        }
                    }

                    # Update activities state to trigger re-render
                    activities = [].concat(activitiesRef.current);

                    # Update the streaming message with current activities
                    messages = lambda prev: Any -> Any {
                        return prev.map(lambda m: Any -> Any {
                            if m.isStreaming {
                                return Object.assign({}, m, {"activities": activitiesRef.current});
                            }
                            return m;
                        });
                    };

                    if isDone {
                        _handleDone(events);
                        return;
                    }

                    # Track idle polls (not processing + no events)
                    if not stillProcessing and events.length == 0 {
                        idleCountRef.current = (idleCountRef.current or 0) + 1;
                    } else {
                        idleCountRef.current = 0;
                    }

                    # Stop polling after 20 consecutive idle polls (10 seconds)
                    # This prevents infinite polling if the agent silently failed.
                    # Before giving up, reload history from backend — the response
                    # may have been persisted even though the WS event was lost.
                    if idleCountRef.current >= 20 {
                        console.warn("[useChatMode] Idle timeout — checking backend for missed response");
                        _tryRecoverOrFail();
                        return;
                    }

                    # Continue polling if still processing or waiting for agent to start
                    pollTimerRef.current = setTimeout(pollOnce, 500);

                } except Exception as e {
                    console.error("[useChatMode] WS poll error:", e);
                    errorCountRef.current = (errorCountRef.current or 0) + 1;
                    if errorCountRef.current >= 10 {
                        console.warn("[useChatMode] Stopping poll: 10 consecutive WS exceptions");
                        _handleDone([{"type": "agent_error", "error": "Connection lost. Please try again."}]);
                        return;
                    }
                    pollTimerRef.current = setTimeout(pollOnce, 1000);
                }
            });
        }

        # Start first poll after a short delay
        pollTimerRef.current = setTimeout(pollOnce, 300);
    }

    def _tryRecoverOrFail() -> None {
        _stopPolling();
        if not ide.projectId {
            _handleDone([{"type": "agent_error", "error": "Agent did not respond. Please try again."}]);
            return;
        }
        # Reload history from backend — persist_done may have saved the response
        # even though the WS event was lost in transit.
        loadFn = ideChatLoadHistory;
        loadFn.call(None, ide.projectId).then(lambda(result: Any) -> None {
            if result and result.success and result.messages and result.messages.length > 0 {
                # Count non-streaming local messages to compare
                localCount = 0;
                for m in messages {
                    if not m.isStreaming { localCount = localCount + 1; }
                }
                if result.messages.length > localCount {
                    # Backend has more messages — recover them (reconstruct build blocks)
                    recoveredMsgs: list = [];
                    for rm in result.messages {
                        if rm.role == "assistant" and rm.activities_log and rm.activities_log.length > 0 {
                            recoveredMsgs.push({
                                "role": "assistant",
                                "isBuildBlock": True,
                                "activities": rm.activities_log,
                                "timestamp": rm.timestamp or ""
                            });
                        }
                        recoveredMsgs.push(rm);
                    }
                    messages = recoveredMsgs;
                    isLoading = False;
                    sendingRef.current = False;
                    activities = [];
                    activitiesRef.current = [];
                    promotedFilesRef.current = [];
                    ide.refreshFiles();
                    return;
                }
            }
            # No new messages on backend — genuinely failed
            _handleDone([{"type": "agent_error", "error": "Agent did not respond. Please try again."}]);
        }).catch(lambda(err: Any) -> None {
            console.error("[useChatMode] Recovery reload failed:", err);
            _handleDone([{"type": "agent_error", "error": "Agent did not respond. Please try again."}]);
        });
    }

    def _handleDone(events: list) -> None {
        _stopPolling();

        # Find the agent_done event for the final response text
        doneResponse = "Done.";
        isErrorResult = False;
        for evt in events {
            evtType = evt.type or "";
            if evtType == "agent_done" {
                doneResponse = evt.response or "Done.";
            } elif evtType == "agent_error" {
                doneResponse = "Error: " + (evt.error or "Unknown error");
                isErrorResult = True;
            }
        }

        allPromoted = [].concat(promotedFilesRef.current);
        turnCheckpointRef = checkpointRefRef.current or "";

        # Persist all activities (thinking, tool calls, file writes, etc.)
        allActivities = [].concat(activitiesRef.current);

        # Persist assistant response + git version to backend (with checkpoint_ref + activities_log)
        if ide.projectId {
            persistFn = ideChatPersistResult;
            persistFn.call(None, ide.projectId, doneResponse, allPromoted, isErrorResult, turnCheckpointRef, allActivities).catch(lambda(err: Any) -> None {
                console.error("[useChatMode] Failed to persist result:", err);
            });
        }

        # Convert streaming message into a completed build block + final response
        finalActivities = [].concat(activitiesRef.current);
        messages = lambda prev: Any -> Any {
            newMsgs: list = [];
            for m in prev {
                if m.isStreaming {
                    # Keep the build block as a completed entry
                    newMsgs.push({
                        "role": "assistant",
                        "isBuildBlock": True,
                        "activities": finalActivities,
                        "timestamp": Date.now()
                    });
                    # Append the final response as a separate message
                    newMsgs.push({
                        "role": "assistant",
                        "content": doneResponse,
                        "updatedFiles": allPromoted,
                        "checkpoint_ref": turnCheckpointRef if not isErrorResult else "",
                        "timestamp": Date.now()
                    });
                } else {
                    newMsgs.push(m);
                }
            }
            return newMsgs;
        };

        # Final file tree refresh
        ide.refreshFiles();

        # Reload active tab if it was updated
        if ide.activeTab {
            for filePath in allPromoted {
                if filePath == ide.activeTab {
                    ide.closeTab(ide.activeTab);
                    ide.openFile(filePath);
                    break;
                }
            }
        }

        isLoading = False;
        sendingRef.current = False;
        activities = [];
        activitiesRef.current = [];
        promotedFilesRef.current = [];
    }

    async def clearChat() -> None {
        _stopPolling();
        sendingRef.current = False;
        messages = [];
        chatError = "";
        activities = [];
        isLoading = False;
        # Clear persisted history on backend — await to ensure consistency
        if ide.projectId {
            try {
                result = await ideChatClearHistory(ide.projectId);
                if not result or not result.success {
                    chatError = "Failed to clear chat history on server";
                }
            } except Exception as err {
                console.error("[useChatMode] Failed to clear history:", err);
                chatError = "Failed to clear chat history";
            }
        }
    }

    async def revertToMessage(checkpointRef: str) -> Any {
        if not checkpointRef or not ide.projectId {
            return {"success": False, "error": "No checkpoint available"};
        }
        result = await ideChatRevertToMessage(ide.projectId, checkpointRef);
        if result and result.success {
            await ide.refreshFiles();
            # Reload active tab to show reverted content
            if ide.activeTab {
                activeTabPath = ide.activeTab;
                ide.closeTab(activeTabPath);
                ide.openFile(activeTabPath);
            }
            # Restart preview with reverted files
            ide.startPreview();
        }
        return result;
    }

    return {
        "messages": messages,
        "isLoading": isLoading,
        "chatError": chatError,
        "isChatMode": isChatMode,
        "activities": activities,
        "scrollRef": scrollRef,
        "historyLoaded": historyLoaded,
        "showJumpToLatest": showJumpToLatest,
        "scrollToLatest": lambda -> None {
            el = scrollRef.current;
            if el {
                el.scrollTo({"top": el.scrollHeight, "behavior": "smooth"});
                userScrolledUpRef.current = False;
                showJumpToLatest = False;
            }
        },
        "toggleChatMode": toggleChatMode,
        "sendMessage": sendMessage,
        "stopAgent": stopAgent,
        "resendMessage": lambda (msgIdx: int, newText: str) -> None {
            if isLoading or sendingRef.current { return; }
            # Truncate messages after the edited user message and resend
            messages = lambda prev: Any -> Any {
                truncated = prev.slice(0, msgIdx);
                return truncated;
            };
            # Small delay so state flushes before sendMessage adds new user msg
            setTimeout(lambda { sendMessage(newText); }, 50);
        },
        "clearChat": clearChat,
        "revertToMessage": revertToMessage
    };
}
