# Debug page to diagnose sidecar/API connectivity in desktop builds
cl {
    import from react { useState, useEffect }
    import from "@jac/runtime" { Link }

    # Import a walker to test actual API calls
    sv import from ..main { ping_server }

    def:pub page -> JsxElement {
        has apiUrl: str = "",
            tauriAvailable: bool = False,
            tauriApiUrl: str = "",
            pingResult: str = "",
            pingError: str = "",
            fetchResult: str = "",
            fetchError: str = "",
            windowInfo: str = "",
            loading: bool = False;

        # Gather debug info on mount
        async can with entry {
            # Check globalThis.__JAC_API_BASE_URL__
            apiUrl = str(globalThis.__JAC_API_BASE_URL__)
                if globalThis.__JAC_API_BASE_URL__
                else "(not set)";

            # Check if Tauri is available
            tauriAvailable = bool(globalThis.__TAURI__);

            # Try to get API URL from Tauri invoke
            if globalThis.__TAURI__ {
                try {
                    invoke = globalThis.__TAURI__.core.invoke;
                    result = await invoke("get_api_url");
                    tauriApiUrl = str(result) if result else "(returned empty)";
                } except Exception as e {
                    tauriApiUrl = f"Error: {e}";
                }
            } else {
                tauriApiUrl = "(Tauri not available)";
            }

            # Collect window info
            info_parts = [];
            info_parts.append(f"Location: {window.location.href}");
            info_parts.append(f"Protocol: {window.location.protocol}");
            info_parts.append(f"Host: {window.location.host}");
            info_parts.append(f"User Agent: {navigator.userAgent[:100]}...");
            windowInfo = "\n".join(info_parts);
        }

        # Test ping via walker spawn
        async def testWalkerPing {
            loading = True;
            pingResult = "";
            pingError = "";
            try {
                response = root spawn ping_server();
                pingResult = JSON.stringify(response, None, 2);
            } except Exception as e {
                pingError = str(e);
            }
            loading = False;
        }

        # Test direct fetch to API
        async def testDirectFetch {
            loading = True;
            fetchResult = "";
            fetchError = "";

            base_url = globalThis.__JAC_API_BASE_URL__ or "";
            endpoint = f"{base_url}/functions" if base_url else "/functions";

            try {
                response = await fetch(
                    endpoint,
                    {"method": "GET", "headers": {"Content-Type": "application/json"}}
                );
                text = await response.text();
                fetchResult = f"Status: {response.status}\nURL: {endpoint}\nBody: {text[:500]}";
            } except Exception as e {
                fetchError = f"URL: {endpoint}\nError: {e}";
            }
            loading = False;
        }

        # Test fetch to root
        async def testRootFetch {
            loading = True;
            fetchResult = "";
            fetchError = "";

            base_url = globalThis.__JAC_API_BASE_URL__ or "";
            endpoint = f"{base_url}/" if base_url else "/";

            try {
                response = await fetch(endpoint, {"method": "GET"});
                text = await response.text();
                fetchResult = f"Status: {response.status}\nURL: {endpoint}\nBody (first 500 chars): {text[:500]}";
            } except Exception as e {
                fetchError = f"URL: {endpoint}\nError: {e}";
            }
            loading = False;
        }

        return
            <div
                style={{
                    "maxWidth": "900px",
                    "margin": "0 auto",
                    "padding": "20px",
                    "fontFamily": "monospace",
                    "backgroundColor": "#1a1a2e",
                    "minHeight": "100vh",
                    "color": "#eee"
                }}
            >
                <div
                    style={{
                        "display": "flex",
                        "justifyContent": "space-between",
                        "alignItems": "center",
                        "marginBottom": "20px"
                    }}
                >
                    <h1 style={{"color": "#00d9ff", "margin": "0"}}>
                        Sidecar Debug Panel
                    </h1>
                    <Link to="/">
                        <button
                            style={{
                                "padding": "8px 16px",
                                "backgroundColor": "#333",
                                "color": "#fff",
                                "border": "1px solid #555",
                                "borderRadius": "4px",
                                "cursor": "pointer"
                            }}
                        >
                            Back Home
                        </button>
                    </Link>
                </div>
                {loading
                and <div
                    style={{
                        "position": "fixed",
                        "top": "10px",
                        "right": "10px",
                        "backgroundColor": "#ff6b6b",
                        "color": "white",
                        "padding": "10px 20px",
                        "borderRadius": "4px"
                    }}
                >
                    Loading...
                </div>}
                # Section 1: Environment Info
                <div
                    style={{
                        "backgroundColor": "#16213e",
                        "padding": "20px",
                        "borderRadius": "8px",
                        "marginBottom": "20px"
                    }}
                >
                    <h2 style={{"color": "#00d9ff", "marginTop": "0"}}>
                        1. Environment Detection
                    </h2>
                    <div style={{"marginBottom": "15px"}}>
                        <div style={{"color": "#888", "fontSize": "12px"}}>
                            globalThis.__JAC_API_BASE_URL__
                        </div>
                        <div
                            style={{
                                "backgroundColor": "#0f3460",
                                "padding": "10px",
                                "borderRadius": "4px",
                                "color": "#4ade80"
                                    if apiUrl != "(not set)"
                                    else "#f87171",
                                "wordBreak": "break-all"
                            }}
                        >
                            {apiUrl}
                        </div>
                    </div>
                    <div style={{"marginBottom": "15px"}}>
                        <div style={{"color": "#888", "fontSize": "12px"}}>
                            Tauri Available (__TAURI__)
                        </div>
                        <div
                            style={{
                                "backgroundColor": "#0f3460",
                                "padding": "10px",
                                "borderRadius": "4px",
                                "color": "#4ade80" if tauriAvailable else "#f87171"
                            }}
                        >
                            {"Yes - Desktop Build"
                                if tauriAvailable
                                else "No - Web Build"}
                        </div>
                    </div>
                    <div style={{"marginBottom": "15px"}}>
                        <div style={{"color": "#888", "fontSize": "12px"}}>
                            Tauri invoke('get_api_url') Result
                        </div>
                        <div
                            style={{
                                "backgroundColor": "#0f3460",
                                "padding": "10px",
                                "borderRadius": "4px",
                                "color": "#fbbf24"
                                    if "Error" in tauriApiUrl
                                    else "#4ade80",
                                "wordBreak": "break-all"
                            }}
                        >
                            {tauriApiUrl}
                        </div>
                    </div>
                    <div>
                        <div style={{"color": "#888", "fontSize": "12px"}}>
                            Window Info
                        </div>
                        <pre
                            style={{
                                "backgroundColor": "#0f3460",
                                "padding": "10px",
                                "borderRadius": "4px",
                                "color": "#94a3b8",
                                "whiteSpace": "pre-wrap",
                                "margin": "0",
                                "fontSize": "11px"
                            }}
                        >
                            {windowInfo}
                        </pre>
                    </div>
                </div>
                # Section 2: Walker Test
                <div
                    style={{
                        "backgroundColor": "#16213e",
                        "padding": "20px",
                        "borderRadius": "8px",
                        "marginBottom": "20px"
                    }}
                >
                    <h2 style={{"color": "#00d9ff", "marginTop": "0"}}>
                        2. Walker Spawn Test
                    </h2>
                    <p style={{"color": "#888", "fontSize": "13px"}}>
                        Tests `root spawn ping_server()` - this is how your app calls the backend.
                    </p>
                    <button
                        onClick={lambda { testWalkerPing();}}
                        style={{
                            "padding": "10px 20px",
                            "backgroundColor": "#3b82f6",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "4px",
                            "cursor": "pointer",
                            "marginBottom": "15px"
                        }}
                    >
                        Test Walker Ping
                    </button>
                    {pingResult
                    and <div>
                        <div style={{"color": "#4ade80", "fontWeight": "bold"}}>
                            SUCCESS:
                        </div>
                        <pre
                            style={{
                                "backgroundColor": "#064e3b",
                                "padding": "10px",
                                "borderRadius": "4px",
                                "color": "#4ade80",
                                "whiteSpace": "pre-wrap",
                                "overflow": "auto"
                            }}
                        >
                            {pingResult}
                        </pre>
                    </div>}
                    {pingError
                    and <div>
                        <div style={{"color": "#f87171", "fontWeight": "bold"}}>
                            ERROR:
                        </div>
                        <pre
                            style={{
                                "backgroundColor": "#450a0a",
                                "padding": "10px",
                                "borderRadius": "4px",
                                "color": "#fca5a5",
                                "whiteSpace": "pre-wrap"
                            }}
                        >
                            {pingError}
                        </pre>
                    </div>}
                </div>
                # Section 3: Direct Fetch Test
                <div
                    style={{
                        "backgroundColor": "#16213e",
                        "padding": "20px",
                        "borderRadius": "8px",
                        "marginBottom": "20px"
                    }}
                >
                    <h2 style={{"color": "#00d9ff", "marginTop": "0"}}>
                        3. Direct Fetch Tests
                    </h2>
                    <p style={{"color": "#888", "fontSize": "13px"}}>
                        Tests raw HTTP fetch to the API endpoint.
                    </p>
                    <div
                        style={{
                            "display": "flex",
                            "gap": "10px",
                            "marginBottom": "15px"
                        }}
                    >
                        <button
                            onClick={lambda { testDirectFetch();}}
                            style={{
                                "padding": "10px 20px",
                                "backgroundColor": "#8b5cf6",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "4px",
                                "cursor": "pointer"
                            }}
                        >
                            Fetch /functions
                        </button>
                        <button
                            onClick={lambda { testRootFetch();}}
                            style={{
                                "padding": "10px 20px",
                                "backgroundColor": "#6366f1",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "4px",
                                "cursor": "pointer"
                            }}
                        >
                            Fetch / (root)
                        </button>
                    </div>
                    {fetchResult
                    and <div>
                        <div style={{"color": "#4ade80", "fontWeight": "bold"}}>
                            RESPONSE:
                        </div>
                        <pre
                            style={{
                                "backgroundColor": "#064e3b",
                                "padding": "10px",
                                "borderRadius": "4px",
                                "color": "#4ade80",
                                "whiteSpace": "pre-wrap",
                                "overflow": "auto",
                                "maxHeight": "300px"
                            }}
                        >
                            {fetchResult}
                        </pre>
                    </div>}
                    {fetchError
                    and <div>
                        <div style={{"color": "#f87171", "fontWeight": "bold"}}>
                            ERROR:
                        </div>
                        <pre
                            style={{
                                "backgroundColor": "#450a0a",
                                "padding": "10px",
                                "borderRadius": "4px",
                                "color": "#fca5a5",
                                "whiteSpace": "pre-wrap"
                            }}
                        >
                            {fetchError}
                        </pre>
                    </div>}
                </div>
                # Section 4: Diagnostic Summary
                <div
                    style={{
                        "backgroundColor": "#16213e",
                        "padding": "20px",
                        "borderRadius": "8px"
                    }}
                >
                    <h2 style={{"color": "#00d9ff", "marginTop": "0"}}>
                        4. What To Check
                    </h2>
                    <ul style={{"color": "#94a3b8", "lineHeight": "1.8"}}>
                        <li>
                            <strong style={{"color": "#fbbf24"}}>
                                __JAC_API_BASE_URL__ is "(not set)":
                            </strong>
                            Sidecar didn't start or Tauri didn't inject the URL
                        </li>
                        <li>
                            <strong style={{"color": "#fbbf24"}}>
                                __TAURI__ is not available:
                            </strong>
                            Running as web, not desktop
                        </li>
                        <li>
                            <strong style={{"color": "#fbbf24"}}>
                                Walker ping fails:
                            </strong>
                            API endpoint not reachable or sidecar crashed
                        </li>
                        <li>
                            <strong style={{"color": "#fbbf24"}}>
                                Fetch fails with network error:
                            </strong>
                            CORS or sidecar not running
                        </li>
                        <li>
                            <strong style={{"color": "#4ade80"}}>All green:</strong>
                            Sidecar is working correctly!
                        </li>
                    </ul>
                </div>
            </div>;
    }
}
