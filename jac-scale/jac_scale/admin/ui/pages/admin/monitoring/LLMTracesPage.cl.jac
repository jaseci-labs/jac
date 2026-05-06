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
            errorMsg: str = "",
            expandedIds: list = [],
            childrenMap: dict = {};

        auth = useAuth();

        async def loadTraces {
            try {
                result = await getLLMTraces(auth["authToken"], 50, 0, "", "", "", True);
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

        async def loadTraceDetail(traceId: str) {
            detailLoading = True;
            showDetail = True;
            result = await getLLMTraceDetail(auth["authToken"], traceId);
            if result["ok"] and result["data"] {
                selectedTrace = result["data"];
            }
            detailLoading = False;
        }

        async def toggleExpand(traceId: str) {
            idx = expandedIds.indexOf(traceId);
            if idx >= 0 {
                expandedIds = expandedIds.slice(0, idx).concat(
                    expandedIds.slice(idx + 1)
                );
            } else {
                expandedIds = expandedIds.concat([traceId]);
                if not childrenMap[traceId] {
                    tResult = await getLLMTraceDetail(auth["authToken"], traceId);
                    if tResult["ok"] and tResult["data"] {
                        newMap = Object.assign({}, childrenMap);
                        newMap[traceId] = tResult["data"]["child_traces"] or [];
                        childrenMap = newMap;
                    }
                }
            }
        }

        useEffect(lambda { loadTraces(); }, []);

        useEffect(
            lambda -> any {
                if not autoRefresh {
                    return undefined;
                }
                interval = setInterval(lambda { loadTraces(); }, 15000);
                return lambda { clearInterval(interval); };
            },
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

        def formatCost(cost: float) -> str {
            if not cost or cost == 0 {
                return "$0.00";
            }
            if cost >= 0.01 {
                return "$" + Number(cost).toFixed(2);
            }
            return "$" + Number(cost).toFixed(4);
        }

        if isLoading {
            return
                <div className="flex items-center justify-center h-64">
                    <div className="text-teal-400 text-lg">Loading traces...</div>
                </div>;
        }

        if errorMsg {
            return
                <div className="flex items-center justify-center h-64">
                    <div className="text-red-400 text-lg">{errorMsg}</div>
                </div>;
        }

        if showDetail {
            return
                <div className="space-y-4">
                    <div className="flex items-center gap-3">
                        <Button
                            onClick={lambda {
                                showDetail = False;
                                selectedTrace = {};
                            }}
                            variant="secondary"
                        >
                            Back to Traces
                        </Button>
                        <h2 className="text-xl font-bold text-white">Trace Detail</h2>
                    </div>
                    {detailLoading
                    and <div className="flex items-center justify-center h-32">
                        <div className="text-teal-400">Loading trace detail...</div>
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
                            <div className="grid grid-cols-3 gap-4 text-sm">
                                <div>
                                    <div className="text-slate-500 mb-1">Caller</div>
                                    <div className="text-purple-300 font-mono">
                                        {selectedTrace["caller_name"] or "N/A"}
                                    </div>
                                </div>
                                <div>
                                    <div className="text-slate-500 mb-1">Model</div>
                                    <div className="text-teal-300 font-mono text-sm">
                                        {selectedTrace["model"] or "N/A"}
                                    </div>
                                </div>
                                <div>
                                    <div className="text-slate-500 mb-1">Status</div>
                                    <span
                                        className={getStatusBadge(
                                            selectedTrace["status"] or "unknown"
                                        )}
                                    >
                                        {selectedTrace["status"] or "unknown"}
                                    </span>
                                </div>
                                <div>
                                    <div className="text-slate-500 mb-1">Tokens</div>
                                    <div className="text-white">
                                        {formatTokens(
                                            selectedTrace["total_tokens"] or 0
                                        )}{(
                                            selectedTrace["aggregated_total_tokens"]
                                            or 0
                                        ) > (selectedTrace["total_tokens"] or 0)
                                        and <span
                                            className="text-slate-500 text-xs ml-1"
                                        >
                                            {"(tree: " + formatTokens(
                                                selectedTrace["aggregated_total_tokens"]
                                                or 0
                                            ) + ")"}
                                        </span>}
                                    </div>
                                </div>
                                <div>
                                    <div className="text-slate-500 mb-1">Cost</div>
                                    <div className="text-yellow-400">
                                        {formatCost(selectedTrace["total_cost"] or 0)}{(
                                            selectedTrace["aggregated_total_cost"] or 0
                                        ) > (selectedTrace["total_cost"] or 0)
                                        and <span
                                            className="text-slate-500 text-xs ml-1"
                                        >
                                            {"(tree: " + formatCost(
                                                selectedTrace["aggregated_total_cost"]
                                                or 0
                                            ) + ")"}
                                        </span>}
                                    </div>
                                </div>
                                <div>
                                    <div className="text-slate-500 mb-1">Latency</div>
                                    <div className="text-white">
                                        {formatLatency(
                                            selectedTrace["total_latency_ms"] or 0
                                        )}
                                    </div>
                                </div>
                                {selectedTrace["parent_invocation_id"]
                                and <div className="col-span-2">
                                    <div className="text-slate-500 mb-1">
                                        Parent Trace
                                    </div>
                                    <div
                                        className="text-teal-400 font-mono text-xs cursor-pointer hover:underline"
                                        onClick={lambda { loadTraceDetail(
                                            selectedTrace["parent_invocation_id"]
                                        ); }}
                                    >
                                        {selectedTrace["parent_invocation_id"]}
                                    </div>
                                </div>}
                                <div className="col-span-3">
                                    <div className="text-slate-500 mb-1">
                                        Invocation ID
                                    </div>
                                    <div className="text-white font-mono text-xs">
                                        {selectedTrace["invocation_id"]}
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
                        {len(selectedTrace["child_traces"] or []) > 0
                        and <div
                            className="bg-slate-900 border border-slate-800 rounded-lg p-5"
                        >
                            <h3 className="text-lg font-semibold text-white mb-3">
                                Nested Traces ({str(
                                    len(selectedTrace["child_traces"] or [])
                                )})
                            </h3>
                            <div className="space-y-2">
                                {[
                                    <div
                                        key={child["invocation_id"]}
                                        className="bg-slate-800 border border-slate-700 rounded-lg p-4 cursor-pointer hover:border-teal-500/50 transition-colors"
                                        onClick={lambda { loadTraceDetail(
                                            child["invocation_id"]
                                        ); }}
                                    >
                                        <div
                                            className="flex items-center justify-between"
                                        >
                                            <div className="flex items-center gap-3">
                                                <span
                                                    className={getStatusBadge(
                                                        child["status"] or "unknown"
                                                    )}
                                                >
                                                    {child["status"] or "unknown"}
                                                </span>
                                                <span
                                                    className="text-purple-300 font-mono text-sm"
                                                >
                                                    {child["caller_name"] or "unknown"}
                                                </span>
                                                <span
                                                    className="text-teal-300 font-mono text-xs"
                                                >
                                                    {child["model"] or ""}
                                                </span>
                                                {(child["child_count"] or 0) > 0
                                                and <span
                                                    className="px-1.5 py-0.5 rounded bg-teal-500/20 text-teal-400 text-xs border border-teal-500/40"
                                                >
                                                    {"+" + String(
                                                        child["child_count"]
                                                    ) + " nested"}
                                                </span>}
                                            </div>
                                            <div
                                                className="flex items-center gap-4 text-xs text-slate-400"
                                            >
                                                <span>
                                                    {String(
                                                        child["llm_call_count"] or 0
                                                    ) + " calls"}
                                                </span>
                                                <span>
                                                    {formatTokens(
                                                        child["total_tokens"] or 0
                                                    ) + " tokens"}
                                                </span>
                                                <span className="text-yellow-400">
                                                    {formatCost(
                                                        child["total_cost"] or 0
                                                    )}
                                                </span>
                                                <span>
                                                    {formatLatency(
                                                        child["total_latency_ms"] or 0
                                                    )}
                                                </span>
                                            </div>
                                        </div>
                                    </div>
                                    for child in (selectedTrace["child_traces"] or [])
                                ]}
                            </div>
                        </div>}
                    </div>}
                </div>;
        }

        def appendChildren(parentId: str, depth: int, items: list, visited: list) {
            if visited.indexOf(parentId) >= 0 {
                return;
            }
            nextVisited = visited.concat([parentId]);
            ch = childrenMap[parentId] or [];
            for child in ch {
                items.push({"trace": child, "depth": depth});
                childId = child["invocation_id"] or "";
                if childId and expandedIds.indexOf(childId) >= 0 {
                    appendChildren(childId, depth + 1, items, nextVisited);
                }
            }
        }

        def getDisplayItems -> list {
            items: list = [];
            for i in traces {
                items.push({"trace": i, "depth": 0});
                traceId = i["invocation_id"] or "";
                if traceId and expandedIds.indexOf(traceId) >= 0 {
                    appendChildren(traceId, 1, items, []);
                }
            }
            return items;
        }

        return
            <div className="space-y-6">
                <div className="flex items-center justify-between">
                    <h2 className="text-xl font-bold text-white">LLM Traces</h2>
                    <div className="flex items-center gap-3">
                        <label
                            className="flex items-center gap-2 text-sm text-slate-400 cursor-pointer"
                        >
                            <input
                                type="checkbox"
                                checked={autoRefresh}
                                onChange={lambda e: any { autoRefresh = e.target.checked; }}
                                className="rounded border-slate-600 bg-slate-800 text-teal-500 focus:ring-teal-500"
                            />
                            Auto-refresh
                        </label>
                        <Button
                            onClick={lambda {
                                isLoading = True;
                                loadTraces();
                            }}
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
                    <div className="text-slate-500 text-lg mb-2">No traces yet</div>
                    <div className="text-slate-600 text-sm">
                        Make some LLM calls to see traces here
                    </div>
                </div>}
                {len(traces) > 0
                and <div
                    className="bg-slate-900 border border-slate-800 rounded-lg overflow-hidden"
                >
                    <div
                        className="flex items-center px-4 py-2.5 border-b border-slate-700 text-xs text-slate-500 font-semibold uppercase tracking-wider"
                    >
                        <div className="flex-1">Trace</div>
                        <div className="w-14 text-right">Calls</div>
                        <div className="w-20 text-right">Tokens</div>
                        <div className="w-24 text-right">Cost</div>
                        <div className="w-16 text-right">Latency</div>
                        <div className="w-16 text-right">Time</div>
                    </div>
                    {[
                        <div
                            key={item["trace"]["invocation_id"]}
                            className="flex items-center px-4 py-3 border-b border-slate-800/50 hover:bg-slate-800/40 transition-colors cursor-pointer"
                        >
                            <div
                                className="flex-1 flex items-center gap-2 min-w-0"
                                style={{
                                    "paddingLeft": String(item["depth"] * 28) + "px"
                                }}
                                onClick={lambda { loadTraceDetail(
                                    item["trace"]["invocation_id"]
                                ); }}
                            >
                                {(item["trace"]["child_count"] or 0) > 0
                                and <button
                                    className="flex-shrink-0 w-5 h-5 flex items-center justify-center text-slate-400 hover:text-teal-400 rounded hover:bg-slate-700/50"
                                    onClick={lambda e: any {
                                        e.stopPropagation();
                                        toggleExpand(item["trace"]["invocation_id"]);
                                    }}
                                >
                                    {expandedIds.indexOf(
                                        item["trace"]["invocation_id"]
                                    ) >= 0
                                    and <span className="text-xs">▼</span>}{expandedIds.indexOf(
                                        item["trace"]["invocation_id"]
                                    ) < 0
                                    and <span className="text-xs">▶</span>}
                                </button>}
                                {(item["trace"]["child_count"] or 0) == 0
                                and <span className="flex-shrink-0 w-5"/>}
                                {item["depth"] > 0
                                and <span className="text-slate-600 text-xs mr-1">
                                    └
                                </span>}
                                <span
                                    className={getStatusBadge(
                                        item["trace"]["status"] or "unknown"
                                    )}
                                >
                                    {item["trace"]["status"] or "unknown"}
                                </span>
                                <span
                                    className="text-purple-300 font-mono text-sm truncate hover:text-purple-200"
                                >
                                    {item["trace"]["caller_name"] or "unknown"}
                                </span>
                                {expandedIds.indexOf(
                                    item["trace"]["invocation_id"]
                                ) >= 0
                                and not childrenMap[item["trace"]["invocation_id"]]
                                and <span
                                    className="text-teal-400 text-xs animate-pulse"
                                >
                                    loading...
                                </span>}
                            </div>
                            <div className="w-14 text-right text-sm text-slate-300">
                                {String(
                                    item["trace"]["aggregated_llm_call_count"]
                                    or item["trace"]["llm_call_count"]
                                    or 0
                                )}
                            </div>
                            <div className="w-20 text-right text-sm text-slate-300">
                                {formatTokens(
                                    item["trace"]["aggregated_total_tokens"]
                                    or item["trace"]["total_tokens"]
                                    or 0
                                )}
                            </div>
                            <div className="w-24 text-right text-sm text-yellow-400">
                                {formatCost(
                                    item["trace"]["aggregated_total_cost"]
                                    or item["trace"]["total_cost"]
                                    or 0
                                )}
                            </div>
                            <div className="w-16 text-right text-sm text-slate-300">
                                {formatLatency(item["trace"]["total_latency_ms"] or 0)}
                            </div>
                            <div className="w-16 text-right text-sm text-slate-500">
                                {formatTimestamp(item["trace"]["timestamp"] or "")}
                            </div>
                        </div> for item in getDisplayItems()
                    ]}
                </div>}
            </div>;
    }
}
