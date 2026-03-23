"""LLM Traces page - Detailed trace view for LLM calls."""

cl {
    import from react { useEffect }
    import from ....components.common.Button { Button }
    import from ....context.AuthContext { useAuth }
    import from ....services.llmService { getLLMTraces, getLLMTraceDetail }

    def:pub LLMTracesPage -> JsxElement {
        has isLoading: bool = True,
            traces: list = [],
            selectedTrace: dict = {},
            showDetail: bool = False,
            detailLoading: bool = False,
            autoRefresh: bool = True,
            errorMsg: str = "";

        auth = useAuth();

        async def loadTraces -> None {
            try {
                result = await getLLMTraces(auth["authToken"]);
                if result["ok"] and result["data"] {
                    traces = result["data"]["traces"] or [];
                    errorMsg = "";
                } elif result["error"] {
                    errorMsg = result["error"]["message"] or "Failed to load traces";
                }
            } except Exception as e {
                console.error("loadTraces error:", e);
                errorMsg = "Error loading traces: " + String(e);
            }
            isLoading = False;
        }

        async def loadTraceDetail(traceId: str) -> None {
            detailLoading = True;
            showDetail = True;
            result = await getLLMTraceDetail(auth["authToken"], traceId);
            if result["ok"] and result["data"] {
                selectedTrace = result["data"];
            }
            detailLoading = False;
        }

        useEffect(lambda -> None { loadTraces();}, []);

        useEffect(
            lambda -> any { if not autoRefresh {
                return undefined;
            }interval = setInterval(lambda -> None { loadTraces();}, 15000);return lambda -> None { clearInterval(
                interval
            );}; },
            [autoRefresh]
        );

        def formatLatency(ms: float) -> str {
            if ms >= 1000 {
                return str(Math.round(ms / 100) / 10) + "s";
            }
            return str(Math.round(ms)) + "ms";
        }

        def formatTokens(tokens: int) -> str {
            if tokens >= 1000 {
                return str(Math.round(tokens / 100) / 10) + "K";
            }
            return str(tokens);
        }

        def formatTimestamp(ts: str) -> str {
            if not ts {
                return "N/A";
            }
            d = Reflect.construct(Date, [Number(ts) * 1000]);
            hours = String(d.getHours()).padStart(2, "0");
            mins = String(d.getMinutes()).padStart(2, "0");
            secs = String(d.getSeconds()).padStart(2, "0");
            return hours + ":" + mins + ":" + secs;
        }

        def getStatusBadge(status: str) -> str {
            if status == "success" {
                return "px-2 py-0.5 rounded text-xs font-bold bg-teal-500/30 text-teal-300 border border-teal-500/50";
            }
            return "px-2 py-0.5 rounded text-xs font-bold bg-red-500/30 text-red-300 border border-red-500/50";
        }

        if isLoading {
            return
                <div className="flex items-center justify-center h-64">
                    <div className="text-teal-400 text-lg">
                        Loading traces...
                    </div>
                </div>;
        }

        if errorMsg {
            return
                <div className="flex items-center justify-center h-64">
                    <div className="text-red-400 text-lg">
                        {errorMsg}
                    </div>
                </div>;
        }

        if showDetail {
            return
                <div className="space-y-4">
                    <div className="flex items-center gap-3">
                        <Button
                            onClick={lambda -> None { showDetail = False;selectedTrace = {};}}
                            variant="secondary"
                        >
                            Back to Traces
                        </Button>
                        <h2 className="text-xl font-bold text-white">
                            Trace Detail
                        </h2>
                    </div>
                    {detailLoading
                    and <div className="flex items-center justify-center h-32">
                        <div className="text-teal-400">
                            Loading trace detail...
                        </div>
                    </div>}
                    {not detailLoading
                    and selectedTrace["invocation_id"]
                    and <div className="space-y-4">
                        <div
                            className="bg-slate-900 border border-slate-800 rounded-lg p-5"
                        >
                            <h3 className="text-lg font-semibold text-white mb-3">
                                Agent Invocation
                            </h3>
                            <div className="grid grid-cols-2 gap-4 text-sm">
                                <div>
                                    <div className="text-slate-500 mb-1">
                                        Invocation ID
                                    </div>
                                    <div className="text-white font-mono text-xs">
                                        {selectedTrace["invocation_id"]}
                                    </div>
                                </div>
                                <div>
                                    <div className="text-slate-500 mb-1">
                                        Caller
                                    </div>
                                    <div className="text-purple-300 font-mono">
                                        {selectedTrace["caller_name"] or "N/A"}
                                    </div>
                                </div>
                                <div>
                                    <div className="text-slate-500 mb-1">
                                        Status
                                    </div>
                                    <span
                                        className={getStatusBadge(
                                            selectedTrace["status"] or "unknown"
                                        )}
                                    >
                                        {selectedTrace["status"] or "unknown"}
                                    </span>
                                </div>
                                <div>
                                    <div className="text-slate-500 mb-1">
                                        Latency
                                    </div>
                                    <div className="text-white">
                                        {formatLatency(
                                            selectedTrace["total_latency_ms"] or 0
                                        )}
                                    </div>
                                </div>
                            </div>
                        </div>
                        {selectedTrace["user_prompt"]
                        and <div
                            className="bg-slate-900 border border-slate-800 rounded-lg p-5"
                        >
                            <h3 className="text-sm font-semibold text-slate-400 mb-2">
                                User Prompt
                            </h3>
                            <pre
                                className="text-white text-sm whitespace-pre-wrap font-mono bg-slate-800 p-3 rounded max-h-48 overflow-y-auto"
                            >
                                {selectedTrace["user_prompt"]}
                            </pre>
                        </div>}
                        {selectedTrace["agent_response"]
                        and <div
                            className="bg-slate-900 border border-slate-800 rounded-lg p-5"
                        >
                            <h3 className="text-sm font-semibold text-slate-400 mb-2">
                                Agent Response
                            </h3>
                            <pre
                                className="text-white text-sm whitespace-pre-wrap font-mono bg-slate-800 p-3 rounded max-h-48 overflow-y-auto"
                            >
                                {selectedTrace["agent_response"]}
                            </pre>
                        </div>}
                        <div
                            className="bg-slate-900 border border-slate-800 rounded-lg p-5"
                        >
                            <h3 className="text-lg font-semibold text-white mb-3">
                                LLM Calls ({str(len(selectedTrace["llm_calls"] or []))})
                            </h3>
                            {len(selectedTrace["llm_calls"] or []) == 0
                            and <div className="text-slate-500 text-sm">
                                No LLM calls recorded for this trace
                            </div>}
                            {len(selectedTrace["llm_calls"] or []) > 0
                            and <div className="space-y-3">
                                {[
                                    <div
                                        key={str(call["timestamp"]) + str(
                                            call["model"]
                                        )}
                                        className="bg-slate-800 border border-slate-700 rounded-lg p-4"
                                    >
                                        <div
                                            className="flex items-center justify-between mb-2"
                                        >
                                            <div className="flex items-center gap-2">
                                                <span
                                                    className="text-teal-300 font-mono text-sm"
                                                >
                                                    {call["model"] or "unknown"}
                                                </span>
                                                <span
                                                    className={getStatusBadge(
                                                        call["status"] or "unknown"
                                                    )}
                                                >
                                                    {call["status"] or "unknown"}
                                                </span>
                                            </div>
                                            <span
                                                className="text-slate-400 text-xs font-mono"
                                            >
                                                {formatTimestamp(
                                                    call["timestamp"] or ""
                                                )}
                                            </span>
                                        </div>
                                        <div className="grid grid-cols-4 gap-3 text-xs">
                                            <div>
                                                <div className="text-slate-500">
                                                    Tokens
                                                </div>
                                                <div className="text-white">
                                                    {formatTokens(
                                                        call["total_tokens"] or 0
                                                    )}
                                                </div>
                                            </div>
                                            <div>
                                                <div className="text-slate-500">
                                                    Prompt
                                                </div>
                                                <div className="text-white">
                                                    {formatTokens(
                                                        call["prompt_tokens"] or 0
                                                    )}
                                                </div>
                                            </div>
                                            <div>
                                                <div className="text-slate-500">
                                                    Completion
                                                </div>
                                                <div className="text-white">
                                                    {formatTokens(
                                                        call["completion_tokens"] or 0
                                                    )}
                                                </div>
                                            </div>
                                            <div>
                                                <div className="text-slate-500">
                                                    Latency
                                                </div>
                                                <div className="text-white">
                                                    {formatLatency(
                                                        call["latency_ms"] or 0
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                        {call["error"]
                                        and <div
                                            className="mt-2 p-2 bg-red-500/10 border border-red-500/30 rounded text-xs text-red-300 font-mono"
                                        >
                                            {call["error"]}
                                        </div>}
                                    </div>
                                    for call in (selectedTrace["llm_calls"] or [])
                                ]}
                            </div>}
                        </div>
                    </div>}
                </div>;
        }

        return
            <div className="space-y-6">
                <div className="flex items-center justify-between">
                    <h2 className="text-xl font-bold text-white">
                        LLM Traces
                    </h2>
                    <div className="flex items-center gap-3">
                        <label
                            className="flex items-center gap-2 text-sm text-slate-400 cursor-pointer"
                        >
                            <input
                                type="checkbox"
                                checked={autoRefresh}
                                onChange={lambda e: any  -> None { autoRefresh = e.target.checked;}}
                                className="rounded border-slate-600 bg-slate-800 text-teal-500 focus:ring-teal-500"
                            />
                            Auto-refresh
                        </label>
                        <Button
                            onClick={lambda -> None { isLoading = True;loadTraces();}}
                            variant="secondary"
                        >
                            Refresh
                        </Button>
                    </div>
                </div>
                {len(traces) == 0
                and <div
                    className="bg-slate-900 border border-slate-800 rounded-lg p-8 text-center"
                >
                    <div className="text-slate-500 text-lg mb-2">
                        No traces yet
                    </div>
                    <div className="text-slate-600 text-sm">
                        Make some LLM calls to see traces here
                    </div>
                </div>}
                {len(traces) > 0
                and <div className="space-y-2">
                    {[
                        <div
                            key={trace["invocation_id"]}
                            className="bg-slate-900 border border-slate-800 rounded-lg p-4 cursor-pointer hover:border-teal-500/50 transition-colors"
                            onClick={lambda -> None { loadTraceDetail(
                                trace["invocation_id"]
                            );}}
                        >
                            <div className="flex items-center justify-between">
                                <div className="flex items-center gap-3">
                                    <span
                                        className={getStatusBadge(
                                            trace["status"] or "unknown"
                                        )}
                                    >
                                        {trace["status"] or "unknown"}
                                    </span>
                                    <span className="text-purple-300 font-mono text-sm">
                                        {trace["caller_name"] or "unknown"}
                                    </span>
                                    <span className="text-slate-600 font-mono text-xs">
                                        {trace["invocation_id"]}
                                    </span>
                                </div>
                                <div
                                    className="flex items-center gap-4 text-xs text-slate-400"
                                >
                                    <span>
                                        {str(trace["llm_call_count"] or 0) + " calls"}
                                    </span>
                                    <span>
                                        {formatTokens(trace["total_tokens"] or 0) + " tokens"}
                                    </span>
                                    <span>
                                        {formatLatency(trace["total_latency_ms"] or 0)}
                                    </span>
                                    <span className="text-slate-500">
                                        {formatTimestamp(trace["timestamp"] or "")}
                                    </span>
                                </div>
                            </div>
                            {trace["user_prompt"]
                            and <div className="mt-2 text-xs text-slate-500 truncate">
                                {trace["user_prompt"]}
                            </div>}
                        </div> for trace in traces
                    ]}
                </div>}
            </div>;
    }
}
