"""LLM Metrics page - Aggregate LLM usage statistics dashboard."""

cl {
    import from react { useEffect }
    import from ....components.common.Button { Button }
    import from ....context.AuthContext { useAuth }
    import from ....services.llmService { getLLMSummary }

    def:pub LLMMetricsPage -> JsxElement {
        has isLoading: bool = True,
            summary: dict = {},
            autoRefresh: bool = True,
            errorMsg: str = "";

        auth = useAuth();

        async def loadSummary -> None {
            result = await getLLMSummary(auth["authToken"]);
            if result["ok"] and result["data"] {
                summary = result["data"];
                errorMsg = "";
            } elif result["error"] {
                errorMsg = result["error"]["message"]
                or "Failed to load telemetry data";
            }
            isLoading = False;
        }

        useEffect(lambda -> None { loadSummary();}, []);

        useEffect(
            lambda -> any { if not autoRefresh {
                return undefined;
            }interval = setInterval(lambda -> None { loadSummary();}, 15000);return lambda -> None { clearInterval(
                interval
            );}; },
            [autoRefresh]
        );

        def formatCost(cost: float) -> str {
            if cost < 0.01 {
                return "$" + str(Math.round(cost * 1000000) / 1000000);
            }
            return "$" + str(Math.round(cost * 100) / 100);
        }

        def formatLatency(ms: float) -> str {
            if ms >= 1000 {
                return str(Math.round(ms / 100) / 10) + "s";
            }
            return str(Math.round(ms)) + "ms";
        }

        def formatTokens(tokens: int) -> str {
            if tokens >= 1000000 {
                return str(Math.round(tokens / 100000) / 10) + "M";
            }
            if tokens >= 1000 {
                return str(Math.round(tokens / 100) / 10) + "K";
            }
            return str(tokens);
        }

        if isLoading {
            return
                <div className="flex items-center justify-center h-64">
                    <div className="text-teal-400 text-lg">
                        Loading telemetry data...
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

        perModel = summary["per_model"] or {};
        perCaller = summary["per_caller"] or {};
        modelKeys = Object.keys(perModel);
        callerKeys = Object.keys(perCaller);

        return
            <div className="space-y-6">
                <div className="flex items-center justify-between">
                    <h2 className="text-xl font-bold text-white">
                        LLM Telemetry
                    </h2>
                    <div className="flex items-center gap-3">
                        <label
                            className="flex items-center gap-2 text-sm text-slate-400 cursor-pointer"
                        >
                            <input
                                type="checkbox"
                                checked={autoRefresh}
                                onChange={lambda e: any -> None { autoRefresh = e.target.checked;}}
                                className="rounded border-slate-600 bg-slate-800 text-teal-500 focus:ring-teal-500"
                            />
                            Auto-refresh
                        </label>
                        <Button
                            onClick={lambda -> None { isLoading = True;loadSummary();}}
                            variant="secondary"
                        >
                            Refresh
                        </Button>
                    </div>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    <div className="bg-slate-900 border border-slate-800 rounded-lg p-5">
                        <div className="text-sm text-slate-500 mb-1">
                            Total Invocations
                        </div>
                        <div className="text-3xl font-bold text-white">
                            {summary["total_invocations"] or 0}
                        </div>
                        <div className="text-xs text-slate-500 mt-1">
                            {str(summary["total_llm_calls"] or 0) + " LLM calls"}
                        </div>
                    </div>
                    <div className="bg-slate-900 border border-slate-800 rounded-lg p-5">
                        <div className="text-sm text-slate-500 mb-1">
                            Total Tokens
                        </div>
                        <div className="text-3xl font-bold text-teal-400">
                            {formatTokens(summary["total_tokens"] or 0)}
                        </div>
                    </div>
                    <div className="bg-slate-900 border border-slate-800 rounded-lg p-5">
                        <div className="text-sm text-slate-500 mb-1">
                            Total Cost
                        </div>
                        <div className="text-3xl font-bold text-amber-400">
                            {formatCost(summary["total_cost"] or 0)}
                        </div>
                    </div>
                    <div
                        className="bg-slate-900 border border-slate-800 rounded-lg p-5"
                    >
                        <div className="text-sm text-slate-500 mb-1">
                            Avg Latency
                        </div>
                        <div className="text-3xl font-bold text-purple-400">
                            {formatLatency(summary["avg_latency_ms"] or 0)}
                        </div>
                        <div className="text-xs text-slate-500 mt-1">
                            {str(summary["error_count"] or 0) + " errors"}
                        </div>
                    </div>
                </div>
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div className="bg-slate-900 border border-slate-800 rounded-lg p-5">
                        <h3 className="text-lg font-semibold text-white mb-4">
                            Per Model
                        </h3>
                        {modelKeys.length == 0
                        and <div className="text-slate-500 text-sm">
                            No model data yet
                        </div>}
                        {modelKeys.length > 0
                        and <div className="overflow-x-auto">
                            <table className="w-full text-sm">
                                <thead>
                                    <tr
                                        className="text-slate-400 border-b border-slate-700"
                                    >
                                        <th className="text-left py-2 pr-4">
                                            Model
                                        </th>
                                        <th className="text-right py-2 px-2">
                                            Calls
                                        </th>
                                        <th className="text-right py-2 px-2">
                                            Tokens
                                        </th>
                                        <th className="text-right py-2 px-2">
                                            Cost
                                        </th>
                                        <th className="text-right py-2 pl-2">
                                            Errors
                                        </th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {[
                                        <tr
                                            key={m}
                                            className="border-b border-slate-800 text-slate-300"
                                        >
                                            <td
                                                className="py-2 pr-4 font-mono text-teal-300"
                                            >
                                                {m}
                                            </td>
                                            <td className="text-right py-2 px-2">
                                                {perModel[m]["calls"]}
                                            </td>
                                            <td className="text-right py-2 px-2">
                                                {formatTokens(perModel[m]["tokens"])}
                                            </td>
                                            <td
                                                className="text-right py-2 px-2 text-amber-400"
                                            >
                                                {formatCost(perModel[m]["cost"])}
                                            </td>
                                            <td className="text-right py-2 pl-2">
                                                {str(perModel[m]["errors"])}
                                            </td>
                                        </tr> for m in modelKeys
                                    ]}
                                </tbody>
                            </table>
                        </div>}
                    </div>
                    <div
                        className="bg-slate-900 border border-slate-800 rounded-lg p-5"
                    >
                        <h3 className="text-lg font-semibold text-white mb-4">
                            Per Caller
                        </h3>
                        {callerKeys.length == 0
                        and <div className="text-slate-500 text-sm">
                            No caller data yet
                        </div>}
                        {callerKeys.length > 0
                        and <div className="overflow-x-auto">
                            <table className="w-full text-sm">
                                <thead>
                                    <tr
                                        className="text-slate-400 border-b border-slate-700"
                                    >
                                        <th className="text-left py-2 pr-4">
                                            Caller
                                        </th>
                                        <th className="text-right py-2 px-2">
                                            Calls
                                        </th>
                                        <th className="text-right py-2 px-2">
                                            Tokens
                                        </th>
                                        <th className="text-right py-2 px-2">
                                            Cost
                                        </th>
                                        <th className="text-right py-2 pl-2">
                                            Errors
                                        </th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {[
                                        <tr
                                            key={c}
                                            className="border-b border-slate-800 text-slate-300"
                                        >
                                            <td
                                                className="py-2 pr-4 font-mono text-purple-300"
                                            >
                                                {c}
                                            </td>
                                            <td className="text-right py-2 px-2">
                                                {perCaller[c]["calls"]}
                                            </td>
                                            <td className="text-right py-2 px-2">
                                                {formatTokens(perCaller[c]["tokens"])}
                                            </td>
                                            <td
                                                className="text-right py-2 px-2 text-amber-400"
                                            >
                                                {formatCost(perCaller[c]["cost"])}
                                            </td>
                                            <td className="text-right py-2 pl-2">
                                                {str(perCaller[c]["errors"])}
                                            </td>
                                        </tr> for c in callerKeys
                                    ]}
                                </tbody>
                            </table>
                        </div>}
                    </div>
                </div>
            </div>;
    }
}
