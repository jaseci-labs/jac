import from datetime { datetime, timedelta }
import from fastapi { UploadFile }
import from uuid { uuid4 }

glob storage = get_storage({'base_path': './uploads'});

#
# Basic backend walkers
#
node Todo {
    has text: str,
        done: bool = False;
}

walker:pub create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo;
    }
}

walker:pub ping_server {
    can ping with `root entry {
        report "pong from backend!";
    }
}

walker:pub get_server_message {
    can info with `root entry {
        report "hello from a basic walker!";
    }
}

# Walker: File upload demonstration
walker:pub upload_file {
    has file: UploadFile;
    has folder: str = "documents";

    can process with `root entry {
        # Generate unique filename
        ext = self.file.filename.rsplit('.', 1)[-1] if '.' in self.file.filename else '';
        unique_name = f"{uuid4()}.{ext}" if ext else str(uuid4());
        path = f"{self.folder}/{unique_name}";

        # Upload file to storage
        storage.upload(self.file.file, path);

        # Get metadata
        metadata = storage.get_metadata(path);

        report {
            "success": True,
            "original_filename": self.file.filename,
            "storage_path": path,
            "size": metadata['size'],
            "content_type": self.file.content_type
        };
    }
}

# Walker: List uploaded files
walker:pub list_uploaded_files {
    has folder: str = "";
    has recursive: bool = False;

    can process with `root entry {
        files = [];
        for path in storage.list_files(self.folder, self.recursive) {
            metadata = storage.get_metadata(path);
            files.append({
                "path": path,
                "size": metadata['size'],
                "modified": str(metadata['modified'])
            });
        }
        report {"files": files, "count": len(files)};
    }
}

# Walker: Delete uploaded file
walker:pub delete_uploaded_file {
    has path: str;

    can process with `root entry {
        if not storage.exists(self.path) {
            report {"success": False, "error": "File not found"};
            return;
        }
        deleted = storage.delete(self.path);
        report {"success": deleted, "path": self.path};
    }
}

#
# Combined example: auth + routing + CSS styling + asset serving + nested folder imports
#
cl import from react { useEffect, useRef }
cl import from "@jac/runtime" {
    Router,
    Routes,
    Route,
    Link,
    useNavigate,
    Navigate,
    jacIsLoggedIn
}

# Pure CSS + asset-in-CSS example
cl import ".styles/styles.css";

# Login Page
cl import from .pages.loginPage { LoginPage }

# Signup Page
cl import from .pages.signupPage { SignupPage }

# Simple 404 page
cl import from .pages.notFound { NotFound }

# Navigation component with active link styling and auth
cl import from .components.navigation {
    Navigation
}

# Page showing nested imports from different folders
cl import from .pages.nestedDemo {
    NestedImportsDemo
}

cl import from .pages.FeaturesTest { FeaturesTest }

cl import from .pages.LandingPage { LandingPage }

cl import from .pages.BudgetPlanner { BudgetPlanner }

# Context provider
cl import from .context.BudgetContext { BudgetProvider }

# TypeScript component import
cl import from ".components/Card.tsx" { Card }

# Main app wrapped in Router (same API as with-router/ example)
cl {
    def:pub HomePage -> any {
        # Check if user is logged in, redirect if not
        if not jacIsLoggedIn() {
            return
                <Navigate to="/login" />;
        }
        has count: int = 0,
            pingResult: str = "",
            serverMessage: str = "",
            lastTodoMessage: str = "";

        can with count entry {
            console.log("Home count changed: ", count);
        }

        # Call simple backend walkers
        async def handlePing -> None {
            result = root spawn ping_server();
            if result.reports and result.reports.length > 0 {
                pingResult = result.reports[0][0];
            }
        }

        async def loadServerMessage -> None {
            result = root spawn get_server_message();
            if result.reports and result.reports.length > 0 {
                serverMessage = result.reports[0][0];
            }
        }

        # Create a sample Todo node in the graph with a hardcoded payload
        async def handleCreateSampleTodo -> None {
            result = root spawn create_todo(text="Sample todo from all-in-one app");
            if result.reports and result.reports.length > 0 {
                todo = result.reports[0][0];
                lastTodoMessage = "Created Todo: " + todo.text;
                console.log("Created Todo node:", todo);
            }
        }

        async can with entry {
            await loadServerMessage();
        }

        # Initialize a Web Worker and handle message-based communication
        workerRef = useRef(None);
        has message: str = "";

        useEffect(
            lambda -> None { workerRef.current = Reflect.construct(
                Worker, ["/workers/worker.js"]
            );workerRef.current.onmessage = lambda event: any  -> None { console.log(
                "Message received from worker:", event.data
            );message = event.data;};return (
                lambda -> None { workerRef.current.terminate();}
            ); },
            []
        );
        handleClick = lambda -> None { workerRef.current.postMessage("");};

        return
            <div
                style={{
                    "padding": "2rem",
                    "fontFamily": "system-ui, -apple-system, sans-serif"
                }}
            >
                <h1>
                    🍔 Router + Styling + Assets Demo
                </h1>
                <p>
                    This home page combines
                    {" "}
                    <strong>
                        React Router,
                    </strong>
                    {" "}
                    <strong>
                        pure CSS styling,
                    </strong>
                    {" "}
                    <strong>
                        staticassets
                    </strong>
                    {" "}
                    and
                    {" "}
                    <strong>
                        nested folder imports
                    </strong>
                </p>
                <div className="container">
                    <h2
                        style={{
                            "color": "white",
                            "textShadow": "2px 2px 4px rgba(0,0,0,0.6)"
                        }}
                    >
                        CSS Background Image
                    </h2>
                    <p
                        style={{
                            "color": "white",
                            "maxWidth": "480px",
                            "textShadow": "1px 1px 3px rgba(0,0,0,0.7)"
                        }}
                    >
                        This section uses the burger image as a background via CSS, just like the
                        {" "}
                        <code>
                            asset-serving/css-with-image
                        </code>
                        {" "}
                        example.
                    </p>
                </div>
                <Card
                    title="TypeScript Card Component"
                    description="This card is built with TypeScript and demonstrates type-safe component usage in Jac"
                    variant="highlighted"
                >
                    <p style={{"margin": "0.5rem 0", "color": "#374151"}}>
                        This is a TypeScript component imported and used in Jac code!
                    </p>
                </Card>
                <div className="card">
                    <h3>
                        Direct &lt;img&gt; asset
                    </h3>
                    <img
                        src="/static/assets/burger.png"
                        alt="Burger asset served by Jac"
                        className="burgerImage"
                    />
                    <p style={{"marginTop": "0.75rem", "color": "#555"}}>
                        This image is served from the project
                        {" "}
                        <code>
                            assets/
                        </code>
                        {" "}
                        folder using the
                        {" "}
                        <code>
                            /static/assets/
                        </code>
                        {" "}
                        path.
                    </p>
                </div>
                <div style={{"marginTop": "2rem"}}>
                    <h3>
                        Counter with pure CSS classes
                    </h3>
                    <p>
                        You've clicked the burger
                        {" "}
                        <strong>
                            {count}
                        </strong>
                        {" "}
                        times.
                    </p>
                    <button
                        onClick={lambda e: any  -> None { count = count + 1;}}
                        style={{
                            "padding": "0.6rem 1.4rem",
                            "fontSize": "1rem",
                            "backgroundColor": "#ff6b35",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "6px",
                            "cursor": "pointer",
                            "boxShadow": "0 2px 4px rgba(0,0,0,0.2)"
                        }}
                    >
                        Click the Burger! 🍔
                    </button>
                </div>
                <div style={{"marginTop": "2rem"}}>
                    <h3>
                        Backend Walkers
                    </h3>
                    <p>
                        Basic example walkers:
                        {" "}
                        <code>
                            ping_server
                        </code>
                        {" "}
                        and
                        {" "}
                        <code>
                            get_server_message
                        </code>
                    </p>
                    <button
                        onClick={lambda e: any  -> None { handlePing();}}
                        style={{
                            "padding": "0.5rem 1.2rem",
                            "marginRight": "0.75rem",
                            "backgroundColor": "#3b82f6",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "6px",
                            "cursor": "pointer"
                        }}
                    >
                        Ping Backend
                    </button>
                    <button
                        onClick={lambda e: any  -> None { handleCreateSampleTodo();}}
                        style={{
                            "padding": "0.5rem 1.2rem",
                            "backgroundColor": "#10b981",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "6px",
                            "cursor": "pointer"
                        }}
                    >
                        Create Sample Todo
                    </button>
                    {pingResult
                    and (
                        <span style={{"marginLeft": "0.5rem", "color": "#374151"}}>
                            Result:
                            {" "}
                            <code>
                                {pingResult}
                            </code>
                        </span>
                    )}
                    {serverMessage
                    and (
                        <p style={{"marginTop": "0.75rem", "color": "#374151"}}>
                            Message:
                            {" "}
                            <code>
                                {serverMessage}
                            </code>
                        </p>
                    )}
                    {lastTodoMessage
                    and (
                        <p style={{"marginTop": "0.5rem", "color": "#111827"}}>
                            {lastTodoMessage}
                        </p>
                    )}
                </div>
                <div style={{"marginTop": "2rem"}}>
                    <h3>
                        Web Worker
                    </h3>
                    <p>
                        This demonstrates how to communicate with a
                        {" "}
                        <strong>
                            Python backend worker
                        </strong>
                        {" "}
                        using Web Workers for asynchronous processing.
                    </p>
                    <p
                        style={{
                            "fontSize": "0.9rem",
                            "color": "#666",
                            "marginTop": "0.5rem"
                        }}
                    >
                        File:
                        {" "}
                        <code>
                            worker.py
                        </code>
                        {" "}
                        — Runs in a separate thread to avoid blocking the UI.
                    </p>
                    <button
                        onClick={lambda -> None { handleClick();}}
                        style={{
                            "padding": "0.5rem 1.2rem",
                            "marginRight": "0.75rem",
                            "backgroundColor": "#d73bf6ff",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "6px",
                            "cursor": "pointer"
                        }}
                    >
                        Call Python Worker
                    </button>
                    {message
                    && (
                        <p style={{marginTop: "1rem", fontWeight: "bold"}}>
                            {message}
                        </p>
                    )}
                </div>
            </div>;
    }

    def:pub app -> any {
        return
            <Router>
                <div style={{"fontFamily": "system-ui, -apple-system, sans-serif"}}>
                    <Navigation />
                    <div
                        style={{
                            "maxWidth": "960px",
                            "margin": "0 auto",
                            "padding": "0 1rem 3rem 1rem"
                        }}
                    >
                        <Routes>
                            <Route path="/" element={<HomePage />} />
                            <Route path="/login" element={<LoginPage />} />
                            <Route path="/signup" element={<SignupPage />} />
                            <Route path="/nested" element={<NestedImportsDemo />} />
                            <Route path="/features-test" element={<FeaturesTest />} />
                            <Route path="/landing" element={<LandingPage />} />
                            <Route
                                path="/budget-planner"
                                element={<BudgetProvider>
                                    <BudgetPlanner />
                                </BudgetProvider>}
                            />
                            <Route path="*" element={<NotFound />} />
                        </Routes>
                    </div>
                </div>
            </Router>;
    }
}
