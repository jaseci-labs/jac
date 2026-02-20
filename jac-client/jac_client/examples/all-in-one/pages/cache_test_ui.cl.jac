# Cache Test Page - Test caching functionality
import from "@jac/runtime" {
    Link,
    jacInvalidate,
    jacClearCache,
    jacGetCacheMetrics,
    jacCacheStats,
    jacIsCacheEnabled,
    jacSetCacheEnabled,
    jacSpawn
}
import from react { useState, useEffect }

# Import walkers to test caching
sv import from ..main {
    read_test_data,
    create_test_data,
    update_test_data
}

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

def:pub CacheTest() -> JsxElement {
    has metrics: dict = {"hits": 0, "misses": 0, "hitRate": 0, "evictions": 0, "cacheSize": 0};
    has stats: dict = {"entries": 0, "keys": [], "config": {}};
    has enabled: bool = True;
    has fetchCount: int = 0;
    has logMessages: list = [];
    has nodeIdInput: str = "";
    has walkerInput: str = "update_test_data";
    has messageInput: str = "Updated!";
    has createdNodes: list = [];
    has allNodes: list = [];

    refreshMetrics = lambda -> None {
        m = jacGetCacheMetrics();
        metrics = m;
        s = jacCacheStats();
        stats = s;
        enabled = jacIsCacheEnabled();
    };

    addLog = lambda msg: str -> None {
        d = Reflect.construct(Date, []);
        timestamp = d.toLocaleTimeString();
        newLog = [f"[{timestamp}] {msg}"];
        for item in logMessages.slice(0, 19) {
            newLog.push(item);
        }
        logMessages = newLog;
    };

    can with entry {
        refreshMetrics();
    }

    async def doFetch -> None {
        addLog("Fetching read_test_data...");
        try {
            result = root spawn read_test_data();
            fetchCount = fetchCount + 1;
            addLog(f"Got result: {JSON.stringify(result)}");
            refreshMetrics();
        } except Exception as e {
            addLog(f"Error: {e}");
        }
    }

    async def doFetchMultiple -> None {
        await doFetch();
        await doFetch();
        await doFetch();
    }

    # Create a new TestData node
    async def doCreateNode -> None {
        addLog("Creating new TestData node...");
        try {
            result = root spawn create_test_data(message=f"Test {Date.now()}");
            addLog(f"Created node: {JSON.stringify(result)}");
            # Extract node ID from result
            if result and result["__jac__"] and result["__jac__"]["id"] {
                nodeInfo = {"id": result["__jac__"]["id"], "message": result["message"]};
                newNodes = [nodeInfo];
                for n in createdNodes {
                    newNodes.push(n);
                }
                createdNodes = newNodes;
            }
            refreshMetrics();
        } except Error as e {
            addLog(f"Error creating node: {e.message}");
        }
    }

    # Fetch all TestData nodes
    async def doFetchAllNodes -> None {
        addLog("Fetching all TestData nodes...");
        try {
            result = root spawn read_test_data();
            addLog(f"Got {result.length if result.length else 0} nodes");
            # Store nodes with their IDs
            nodes = [];
            if Array.isArray(result) {
                for item in result {
                    if item and item["__jac__"] and item["__jac__"]["id"] {
                        nodes.push({"id": item["__jac__"]["id"], "message": item["message"], "count": item["count"]});
                    }
                }
            }
            allNodes = nodes;
            refreshMetrics();
        } except Error as e {
            addLog(f"Error: {e.message}");
        }
    }

    # Select a node ID for testing
    selectNode = lambda nId: str -> None {
        nodeIdInput = nId;
        addLog(f"Selected node: {nId}");
    };

    doInvalidate = lambda -> None {
        jacInvalidate("read_test_data");
        addLog("Invalidated read_test_data cache");
        refreshMetrics();
    };

    # Node-specific operations
    async def doFetchWithNode -> None {
        wName = walkerInput or "update_test_data";
        nId = nodeIdInput or "";
        fields = {};
        if wName == "update_test_data" {
            fields = {"new_message": messageInput};
        }
        addLog(f"Spawning {wName} on node '{nId}' with fields: {JSON.stringify(fields)}");
        try {
            result = await jacSpawn(wName, nId, fields);
            fetchCount = fetchCount + 1;
            addLog(f"Got result: {JSON.stringify(result)}");
            refreshMetrics();
        } except Error as e {
            addLog(f"Error: {e.message}");
        }
    }

    handleMessageChange = lambda e: any -> None {
        messageInput = e.target.value;
    };

    doInvalidateWithNode = lambda -> None {
        wName = walkerInput or "read_test_data";
        nId = nodeIdInput or "";
        jacInvalidate(wName, nId);
        addLog(f"Invalidated {wName} cache for node '{nId}'");
        refreshMetrics();
    };

    handleNodeIdChange = lambda e: any -> None {
        nodeIdInput = e.target.value;
    };

    handleWalkerChange = lambda e: any -> None {
        walkerInput = e.target.value;
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
        if newState {
            addLog("Cache ENABLED");
        } else {
            addLog("Cache DISABLED");
        }
        refreshMetrics();
    };

    enabledText = "Disable Cache";
    enabledColor = "#10b981";
    enabledStatus = "Yes";
    if not enabled {
        enabledText = "Enable Cache";
        enabledColor = "#6b7280";
        enabledStatus = "No";
    }
    hitRateText = f"{(metrics['hitRate'] * 100).toFixed(1)}%";

    return
        <div style={{"padding": "20px", "maxWidth": "1000px", "margin": "0 auto", "fontFamily": "system-ui"}}>
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
                    <label style={{"fontWeight": "600"}}>Walker:</label>
                    <input
                        type="text"
                        value={walkerInput}
                        onChange={handleWalkerChange}
                        placeholder="update_test_data"
                        style={{
                            "padding": "8px 12px",
                            "borderRadius": "4px",
                            "border": "1px solid #cbd5e1",
                            "fontSize": "14px",
                            "width": "180px"
                        }}
                    />
                    <label style={{"fontWeight": "600"}}>Node ID:</label>
                    <input
                        type="text"
                        value={nodeIdInput}
                        onChange={handleNodeIdChange}
                        placeholder="Click a node above"
                        style={{
                            "padding": "8px 12px",
                            "borderRadius": "4px",
                            "border": "1px solid #cbd5e1",
                            "fontSize": "14px",
                            "width": "280px",
                            "fontFamily": "monospace"
                        }}
                    />
                </div>
                <div style={{"display": "flex", "gap": "10px", "marginBottom": "15px", "flexWrap": "wrap", "alignItems": "center"}}>
                    <label style={{"fontWeight": "600"}}>Message (for update_test_data):</label>
                    <input
                        type="text"
                        value={messageInput}
                        onChange={handleMessageChange}
                        placeholder="New message"
                        style={{
                            "padding": "8px 12px",
                            "borderRadius": "4px",
                            "border": "1px solid #cbd5e1",
                            "fontSize": "14px",
                            "width": "200px"
                        }}
                    />
                </div>
                <CacheButton text="Spawn on Node" onClick={doFetchWithNode} color="#0284c7"/>
                <CacheButton text="Invalidate Node Cache" onClick={doInvalidateWithNode} color="#ea580c"/>
                <p style={{"fontSize": "12px", "color": "#64748b", "marginTop": "10px", "marginBottom": "0"}}>
                    Cache key format: walker:nodeId:fields. Different fields = different cache entries.
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
