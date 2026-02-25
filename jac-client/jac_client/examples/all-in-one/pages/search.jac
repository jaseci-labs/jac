cl import from "@jac/runtime" { Link, useLocation, useNavigate }

cl {
    def:pub page -> JsxElement {
        location = useLocation();
        navigate = useNavigate();

        # Parse query parameters using URLSearchParams
        searchParams = Reflect.construct(URLSearchParams, [location.search]);
        query = searchParams.get("q") or "";
        page = parseInt(searchParams.get("page") or "1");

        has inputValue: str = query;

        # Mock search results
        allResults = [
            {"title": "Getting Started with Jac", "type": "post"},
            {"title": "File-Based Routing Guide", "type": "post"},
            {"title": "Alice Johnson", "type": "user"},
            {"title": "Dynamic Routes Explained", "type": "post"},
            {"title": "Bob Smith", "type": "user"}
        ];

        # Filter results based on query
        results = [
            item
            for item in allResults
            if (
                True
                if not query
                else item["title"].toLowerCase().includes(query.toLowerCase())
            )
        ];

        def handleSearch(e: any) -> None {
            e.preventDefault();
            if inputValue.trim() {
                navigate(f"/search?q={encodeURIComponent(inputValue.trim())}&page=1");
            } else {
                navigate("/search");
            }
        }

        def goToPage(newPage: int) -> None {
            if query {
                navigate(f"/search?q={encodeURIComponent(query)}&page={newPage}");
            } else {
                navigate(f"/search?page={newPage}");
            }
        }

        return
            <div style={{"padding": "2rem", "maxWidth": "600px"}}>
                <h1>
                    Search
                </h1>
                <p style={{"color": "#6b7280", "marginBottom": "1.5rem"}}>
                    Demonstrates query parameter handling with URLSearchParams
                </p>
                <form onSubmit={handleSearch} style={{"marginBottom": "2rem"}}>
                    <div style={{"display": "flex", "gap": "0.5rem"}}>
                        <input
                            type="text"
                            value={inputValue}
                            onChange={lambda e: any  -> None { inputValue = e.target.value;}}
                            placeholder="Search users and posts..."
                            style={{
                                "flex": "1",
                                "padding": "0.75rem",
                                "border": "1px solid #d1d5db",
                                "borderRadius": "6px"
                            }}
                        />
                        <button
                            type="submit"
                            style={{
                                "padding": "0.75rem 1.5rem",
                                "background": "#3b82f6",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "6px",
                                "cursor": "pointer"
                            }}
                        >
                            Search
                        </button>
                    </div>
                </form>
                <div
                    style={{
                        "background": "#f3f4f6",
                        "padding": "1rem",
                        "borderRadius": "6px",
                        "marginBottom": "1.5rem",
                        "fontSize": "0.875rem"
                    }}
                >
                    <strong>
                        Current URL params:
                    </strong>
                    <br/>
                    q = "
                    {query}
                    "
                    <br/>
                    page =
                    {page}
                </div>
                {query
                and (
                    <p style={{"marginBottom": "1rem"}}>
                        Found{results.length} results for "{query}"
                    </p>
                )}
                <ul style={{"listStyle": "none", "padding": "0"}}>
                    {[
                        <li
                            key={item["title"]}
                            style={{
                                "padding": "1rem",
                                "borderBottom": "1px solid #e5e7eb",
                                "display": "flex",
                                "justifyContent": "space-between"
                            }}
                        >
                            <span>
                                {item["title"]}
                            </span>
                            <span
                                style={{
                                    "background": (
                                        item["type"] == "user"
                                        and "#dbeafe"
                                        or "#dcfce7"
                                    ),
                                    "color": (
                                        item["type"] == "user"
                                        and "#1e40af"
                                        or "#166534"
                                    ),
                                    "padding": "0.25rem 0.5rem",
                                    "borderRadius": "4px",
                                    "fontSize": "0.75rem"
                                }}
                            >
                                {item["type"]}
                            </span>
                        </li> for item in results
                    ]}
                </ul>
                <div
                    style={{"marginTop": "1.5rem", "display": "flex", "gap": "0.5rem"}}
                >
                    <button
                        onClick={lambda -> None { goToPage(page - 1);}}
                        disabled={page <= 1}
                        style={{
                            "padding": "0.5rem 1rem",
                            "border": "1px solid #d1d5db",
                            "borderRadius": "4px",
                            "cursor": (page <= 1 and "not-allowed" or "pointer"),
                            "opacity": (page <= 1 and "0.5" or "1")
                        }}
                    >
                        Previous
                    </button>
                    <span style={{"padding": "0.5rem 1rem"}}>
                        Page{page}
                    </span>
                    <button
                        onClick={lambda -> None { goToPage(page + 1);}}
                        style={{
                            "padding": "0.5rem 1rem",
                            "border": "1px solid #d1d5db",
                            "borderRadius": "4px",
                            "cursor": "pointer"
                        }}
                    >
                        Next
                    </button>
                </div>
                <div style={{"marginTop": "2rem"}}>
                    <Link to="/" style={{"color": "#3b82f6"}}>
                        ← Back to Home
                    </Link>
                </div>
            </div>;
    }
}
