cl import from "@jac/runtime" { Link }

cl {
    def:pub page -> JsxElement {
        # Mock list of users
        users = [
            {"id": "1", "name": "Alice Johnson", "role": "Admin"},
            {"id": "2", "name": "Bob Smith", "role": "Developer"},
            {"id": "3", "name": "Charlie Brown", "role": "Designer"}
        ];

        return
            <div style={{"padding": "2rem"}}>
                <h1>
                    Users Directory
                </h1>
                <p style={{"color": "#6b7280", "marginBottom": "1.5rem"}}>
                    Click on a user to view their profile (demonstrates dynamic [id] routing)
                </p>
                <div
                    style={{
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": "0.75rem"
                    }}
                >
                    {users.map(
                        lambda user: any  -> any { return
                            <Link
                                key={user["id"]}
                                to={"/users/" + user["id"]}
                                style={{
                                    "display": "block",
                                    "padding": "1rem",
                                    "background": "#f9fafb",
                                    "borderRadius": "8px",
                                    "textDecoration": "none",
                                    "color": "#111827",
                                    "border": "1px solid #e5e7eb"
                                }}
                            >
                                <strong>
                                    {user["name"]}
                                </strong>
                                <span
                                    style={{"color": "#6b7280", "marginLeft": "0.5rem"}}
                                >
                                    —{user["role"]}
                                </span>
                            </Link>; }
                    )}
                </div>
            </div>;
    }
}
