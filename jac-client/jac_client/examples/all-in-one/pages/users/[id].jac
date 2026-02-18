cl import from "@jac/runtime" { Link, useParams }

cl {
    def:pub page -> JsxElement {
        params = useParams();
        userId = params.id;

        # Mock user data based on ID
        users = {
            "1": {
                "name": "Alice Johnson",
                "email": "alice@example.com",
                "role": "Admin"
            },
            "2": {"name": "Bob Smith", "email": "bob@example.com", "role": "Developer"},
            "3": {
                "name": "Charlie Brown",
                "email": "charlie@example.com",
                "role": "Designer"
            }
        };

        user = users[userId];

        if not user {
            return
                <div style={{"padding": "2rem", "textAlign": "center"}}>
                    <h1>
                        User Not Found
                    </h1>
                    <p>
                        No user exists with ID:{userId}
                    </p>
                    <Link to="/users">
                        Back to Users
                    </Link>
                </div>;
        }

        return
            <div style={{"padding": "2rem"}}>
                <Link
                    to="/users"
                    style={{"color": "#3b82f6", "textDecoration": "none"}}
                >
                    ← Back to Users
                </Link>
                <h1 style={{"marginTop": "1rem"}}>
                    User Profile
                </h1>
                <div
                    style={{
                        "background": "#f9fafb",
                        "padding": "1.5rem",
                        "borderRadius": "8px",
                        "marginTop": "1rem"
                    }}
                >
                    <p>
                        <strong>
                            ID:
                        </strong>
                        {userId}
                    </p>
                    <p>
                        <strong>
                            Name:
                        </strong>
                        {user["name"]}
                    </p>
                    <p>
                        <strong>
                            Email:
                        </strong>
                        {user["email"]}
                    </p>
                    <p>
                        <strong>
                            Role:
                        </strong>
                        {user["role"]}
                    </p>
                </div>
            </div>;
    }
}
