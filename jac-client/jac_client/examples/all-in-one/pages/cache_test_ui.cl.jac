# Cache Test Page

import from "@jac/runtime" {
    Link,
    jacInvalidate,
    jacClearCache,
    jacGetCacheMetrics,
    jacCacheStats,
    jacIsCacheEnabled,
    jacSetCacheEnabled
}
import from react { useState, useEffect }

sv import from ..main {
    read_test_data,
    create_test_data,
    update_test_data
}

glob MAX_LOG_ENTRIES: int = 20;

def:pub CacheButton(
    text: str, onClick: any, color: str
) -> JsxElement {
    return
        <button
            onClick={onClick}
            style={{
                "padding": "10px 20px",
                "backgroundColor": color,
                "color": "white",
                "border": "none",
                "borderRadius": "6px",
                "cursor": "pointer",
                "fontSize": "14px",
                "fontWeight": "600",
                "marginRight": "10px",
                "marginBottom": "10px"
            }}
        >
            {text}
        </button>;
}

def:pub MetricCard(
    label: str, value: any, color: str
) -> JsxElement {
    return
        <div
            style={{
                "backgroundColor": color,
                "padding": "15px",
                "borderRadius": "8px",
                "textAlign": "center",
                "minWidth": "120px"
            }}
        >
            <div style={{"fontSize": "24px", "fontWeight": "bold", "color": "#1f2937"}}>
                {value}
            </div>
            <div style={{"fontSize": "12px", "color": "#6b7280", "marginTop": "5px"}}>
                {label}
            </div>
        </div>;
}

def:pub InputField(
    value: str, onChange: any, placeholder: str, width: str = "180px", monospace: bool = False
) -> JsxElement {
    fontFamily = "monospace" if monospace else "inherit";
    return
        <input
            type="text"
            value={value}
            onChange={onChange}
            placeholder={placeholder}
            style={{
                "padding": "8px 12px",
                "borderRadius": "4px",
                "border": "1px solid #cbd5e1",
                "fontSize": "14px",
                "width": width,
                "fontFamily": fontFamily
            }}
        />;
}

def:pub CacheTest() -> JsxElement {
    has metrics: dict = {"hits": 0, "misses": 0, "hitRate": 0, "evictions": 0, "cacheSize": 0};
    has stats: dict = {"entries": 0, "keys": [], "config": {}};
    has enabled: bool = True;
    has loading: bool = False;
    has logMessages: list = [];
    has nodeIdInput: str = "";
    has messageInput: str = "Updated!";
    has allNodes: list = [];

    refreshMetrics = lambda -> None {
        metrics = jacGetCacheMetrics();
        stats = jacCacheStats();
        enabled = jacIsCacheEnabled();
    };

    addLog = lambda msg: str -> None {
        d = Reflect.construct(Date, []);
        timestamp = d.toLocaleTimeString();
        newLog = [f"[{timestamp}] {msg}"];
        for item in logMessages.slice(0, MAX_LOG_ENTRIES - 1) {
            newLog.push(item);
        }
        logMessages = newLog;
    };

    can with entry {
        refreshMetrics();
    }

    async def doFetch -> None {
        loading = True;
        addLog("Fetching read_test_data...");
        try {
            result = root spawn read_test_data();
            addLog(f"Got result: {JSON.stringify(result)}");
            refreshMetrics();
        } except Exception as e {
            addLog(f"Error: {e}");
        }
        loading = False;
    }

    async def doFetchMultiple -> None {
        await doFetch();
        await doFetch();
        await doFetch();
    }

    doInvalidate = lambda -> None {
        jacInvalidate("read_test_data");
        addLog("Invalidated read_test_data cache");
        refreshMetrics();
    };

    doClear = lambda -> None {
        jacClearCache();
        addLog("Cleared all cache");
        refreshMetrics();
    };

    toggleEnabled = lambda -> None {
        newState = not enabled;
        jacSetCacheEnabled(newState);
        enabled = newState;
        addLog(f"Cache {'ENABLED' if newState else 'DISABLED'}");
        refreshMetrics();
    };

    # ========================================================================
    # EVENT HANDLERS - Node Operations
    # ========================================================================

    async def doCreateNode -> None {
        loading = True;
        addLog("Creating new TestData node...");
        try {
            result = root spawn create_test_data(message=f"Test {Date.now()}");
            addLog(f"Created node: {JSON.stringify(result)}");
            refreshMetrics();
            # Refresh node list
            await doFetchAllNodes();
        } except Exception as e {
            addLog(f"Error creating node: {e}");
        }
        loading = False;
    }

    async def doFetchAllNodes -> None {
        loading = True;
        addLog("Fetching all TestData nodes...");
        try {
            result = root spawn read_test_data();
            nodeCount = result.length if result.length else 0;
            addLog(f"Got {nodeCount} nodes");
            # Store nodes with their IDs
            nodes = [];
            if Array.isArray(result) {
                for item in result {
                    if item and item["__jac__"] and item["__jac__"]["id"] {
                        nodes.push({
                            "id": item["__jac__"]["id"],
                            "message": item["message"],
                            "count": item["count"]
                        });
                    }
                }
            }
            allNodes = nodes;
            refreshMetrics();
        } except Exception as e {
            addLog(f"Error: {e}");
        }
        loading = False;
    }

    selectNode = lambda nId: str -> None {
        nodeIdInput = nId;
        addLog(f"Selected node: {nId}");
    };

    # ========================================================================
    # EVENT HANDLERS - Node-Specific Cache Operations
    # ========================================================================

    async def doUpdateNode -> None {
        nId = nodeIdInput;
        if not nId {
            addLog("Error: No node selected. Click a node above first.");
            return;
        }
        loading = True;
        addLog(f"Spawning update_test_data on node '{nId}'");
        try {
            result = nId spawn update_test_data(new_message=messageInput);
            addLog(f"Got result: {JSON.stringify(result)}");
            refreshMetrics();
        } except Exception as e {
            addLog(f"Error: {e}");
        }
        loading = False;
    }

    doInvalidateWithNode = lambda -> None {
        nId = nodeIdInput or "";
        jacInvalidate("update_test_data", nId);
        addLog(f"Invalidated update_test_data cache for node '{nId}'");
        refreshMetrics();
    };

    # ========================================================================
    # INPUT HANDLERS
    # ========================================================================

    handleNodeIdChange = lambda e: any -> None {
        nodeIdInput = e.target.value;
    };

    handleMessageChange = lambda e: any -> None {
        messageInput = e.target.value;
    };

    # ========================================================================
    # COMPUTED VALUES
    # ========================================================================

    enabledText = "Disable Cache" if enabled else "Enable Cache";
    enabledColor = "#10b981" if enabled else "#6b7280";
    enabledStatus = "Yes" if enabled else "No";
    hitRateText = f"{(metrics['hitRate'] * 100).toFixed(1)}%";

    # ========================================================================
    # RENDER
    # ========================================================================

    return
        <div style={{"padding": "20px", "maxWidth": "1000px", "margin": "0 auto", "fontFamily": "system-ui"}}>
            {loading and <div style={{
                "position": "fixed",
                "top": "20px",
                "right": "20px",
                "backgroundColor": "#3b82f6",
                "color": "white",
                "padding": "10px 20px",
                "borderRadius": "6px",
                "boxShadow": "0 4px 6px rgba(0,0,0,0.2)",
                "zIndex": "1000"
            }}>Loading...</div>}

            <div style={{"marginBottom": "20px"}}>
                <Link to="/" style={{"color": "#3b82f6", "textDecoration": "none"}}>
                    {"<- Back to Home"}
                </Link>
            </div>

            <h1 style={{"marginBottom": "30px"}}>Cache Testing</h1>

            <div style={{"display": "flex", "gap": "15px", "marginBottom": "30px", "flexWrap": "wrap"}}>
                <MetricCard label="Hits" value={metrics["hits"]} color="#d1fae5"/>
                <MetricCard label="Misses" value={metrics["misses"]} color="#fee2e2"/>
                <MetricCard label="Hit Rate" value={hitRateText} color="#dbeafe"/>
                <MetricCard label="Cache Size" value={metrics["cacheSize"]} color="#fef3c7"/>
                <MetricCard label="Evictions" value={metrics["evictions"]} color="#f3e8ff"/>
            </div>

            <div style={{"marginBottom": "30px", "padding": "20px", "backgroundColor": "#f9fafb", "borderRadius": "8px"}}>
                <h3 style={{"marginTop": "0"}}>Basic Controls (Root Node)</h3>
                <CacheButton text="Fetch Data" onClick={doFetch} color="#3b82f6"/>
                <CacheButton text="Fetch x3" onClick={doFetchMultiple} color="#8b5cf6"/>
                <CacheButton text="Invalidate" onClick={doInvalidate} color="#f59e0b"/>
                <CacheButton text="Clear All" onClick={doClear} color="#ef4444"/>
                <CacheButton text={enabledText} onClick={toggleEnabled} color={enabledColor}/>
                <CacheButton text="Refresh Metrics" onClick={refreshMetrics} color="#6366f1"/>
            </div>

            <div style={{"marginBottom": "30px", "padding": "20px", "backgroundColor": "#fef3c7", "borderRadius": "8px"}}>
                <h3 style={{"marginTop": "0"}}>Test Data Nodes</h3>
                <div style={{"marginBottom": "15px"}}>
                    <CacheButton text="Create Node" onClick={doCreateNode} color="#059669"/>
                    <CacheButton text="Fetch All Nodes" onClick={doFetchAllNodes} color="#7c3aed"/>
                </div>
                {allNodes.length > 0 and (
                    <div style={{"marginTop": "10px"}}>
                        <p style={{"fontWeight": "600", "marginBottom": "8px"}}>Available Nodes (click to select):</p>
                        <div style={{"display": "flex", "flexDirection": "column", "gap": "6px"}}>
                            {allNodes.map(lambda n: dict, i: int -> JsxElement {
                                return <div
                                    key={i}
                                    onClick={lambda -> None { selectNode(n["id"]); }}
                                    style={{
                                        "padding": "8px 12px",
                                        "backgroundColor": "#fff",
                                        "border": "1px solid #d1d5db",
                                        "borderRadius": "4px",
                                        "cursor": "pointer",
                                        "fontFamily": "monospace",
                                        "fontSize": "13px"
                                    }}
                                >
                                    <strong>{n["id"]}</strong>
                                    <span style={{"color": "#6b7280", "marginLeft": "10px"}}>
                                        {n["message"]} (count: {n["count"]})
                                    </span>
                                </div>;
                            })}
                        </div>
                    </div>
                )}
                {allNodes.length == 0 and (
                    <p style={{"color": "#92400e", "fontSize": "13px"}}>
                        No nodes yet. Click "Create Node" or "Fetch All Nodes" to populate.
                    </p>
                )}
            </div>

            <div style={{"marginBottom": "30px", "padding": "20px", "backgroundColor": "#e0f2fe", "borderRadius": "8px"}}>
                <h3 style={{"marginTop": "0"}}>Node-Specific Cache Operations</h3>
                <div style={{"display": "flex", "gap": "10px", "marginBottom": "10px", "flexWrap": "wrap", "alignItems": "center"}}>
                    <label style={{"fontWeight": "600"}}>Node ID:</label>
                    <InputField value={nodeIdInput} onChange={handleNodeIdChange} placeholder="Click a node above" width="320px" monospace={True}/>
                </div>
                <div style={{"display": "flex", "gap": "10px", "marginBottom": "15px", "flexWrap": "wrap", "alignItems": "center"}}>
                    <label style={{"fontWeight": "600"}}>Message:</label>
                    <InputField value={messageInput} onChange={handleMessageChange} placeholder="New message" width="200px"/>
                </div>
                <CacheButton text="Update Node" onClick={doUpdateNode} color="#0284c7"/>
                <CacheButton text="Invalidate Node Cache" onClick={doInvalidateWithNode} color="#ea580c"/>
                <p style={{"fontSize": "12px", "color": "#64748b", "marginTop": "10px", "marginBottom": "0"}}>
                    Uses: nodeId spawn update_test_data(new_message=...). Cache key: walker:nodeId:fields
                </p>
            </div>

            <div style={{"marginBottom": "30px", "padding": "20px", "backgroundColor": "#f9fafb", "borderRadius": "8px"}}>
                <h3 style={{"marginTop": "0"}}>Cache Status</h3>
                <p><strong>Enabled:</strong> {enabledStatus}</p>
                <p><strong>Cached Keys:</strong></p>
                <pre style={{
                    "backgroundColor": "#1f2937",
                    "color": "#10b981",
                    "padding": "10px",
                    "borderRadius": "4px",
                    "overflow": "auto",
                    "maxHeight": "100px"
                }}>
                    {JSON.stringify(stats["keys"], None, 2)}
                </pre>
                <p><strong>Config:</strong></p>
                <pre style={{
                    "backgroundColor": "#1f2937",
                    "color": "#60a5fa",
                    "padding": "10px",
                    "borderRadius": "4px"
                }}>
                    {JSON.stringify(stats["config"], None, 2)}
                </pre>
            </div>

            <div style={{"padding": "20px", "backgroundColor": "#f9fafb", "borderRadius": "8px"}}>
                <h3 style={{"marginTop": "0"}}>Activity Log</h3>
                <div style={{
                    "backgroundColor": "#1f2937",
                    "color": "#e5e7eb",
                    "padding": "10px",
                    "borderRadius": "4px",
                    "fontFamily": "monospace",
                    "fontSize": "12px",
                    "maxHeight": "200px",
                    "overflow": "auto"
                }}>
                    {logMessages.map(lambda entry: str, i: int -> JsxElement {
                        return <div key={i}>{entry}</div>;
                    })}
                    {logMessages.length == 0 and <div style={{"color": "#6b7280"}}>No activity yet. Click Fetch Data to start.</div>}
                </div>
            </div>
        </div>;
}
