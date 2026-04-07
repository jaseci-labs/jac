cl import from "@jac/runtime" { Link }

cl {
    def:pub page -> JsxElement {
        # Mock blog posts
        posts = [
            {
                "slug": "getting-started-with-jac",
                "title": "Getting Started with Jac",
                "excerpt": "Learn the basics of building client-side applications with Jac."
            },
            {
                "slug": "file-based-routing-guide",
                "title": "File-Based Routing Guide",
                "excerpt": "Create pages by simply adding files to your pages/ directory."
            },
            {
                "slug": "dynamic-routes-explained",
                "title": "Dynamic Routes Explained",
                "excerpt": "Use [param].jac for single parameters or [...slug].jac for catch-all routes."
            }
        ];

        return
            <div style={{"padding": "2rem"}}>
                <h1>
                    Blog Posts
                </h1>
                <p style={{"color": "#6b7280", "marginBottom": "1.5rem"}}>
                    Click on a post to read it (demonstrates slug-based [slug] routing)
                </p>
                <div
                    style={{
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": "1rem"
                    }}
                >
                    {[
                        <Link
                            key={post["slug"]}
                            to={"/posts/" + post["slug"]}
                            style={{
                                "display": "block",
                                "padding": "1.25rem",
                                "background": "#ffffff",
                                "borderRadius": "8px",
                                "textDecoration": "none",
                                "color": "#111827",
                                "border": "1px solid #e5e7eb",
                                "boxShadow": "0 1px 2px rgba(0,0,0,0.05)"
                            }}
                        >
                            <h3 style={{"margin": "0 0 0.5rem 0", "color": "#3b82f6"}}>
                                {post["title"]}
                            </h3>
                            <p
                                style={{
                                    "margin": "0",
                                    "color": "#6b7280",
                                    "fontSize": "0.875rem"
                                }}
                            >
                                {post["excerpt"]}
                            </p>
                        </Link> for post in posts
                    ]}
                </div>
            </div>;
    }
}
