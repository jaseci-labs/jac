cl import from "@jac/runtime" { Link, useParams }

cl {
    def:pub page -> JsxElement {
        params = useParams();
        slug = params.slug;

        # Mock blog posts data
        posts = {
            "getting-started-with-jac": {
                "title": "Getting Started with Jac",
                "author": "Alice",
                "date": "2024-01-15",
                "content": "Jac is a powerful language that combines the best of Python and modern web development. In this guide, we'll explore the basics of building client-side applications with Jac."
            },
            "file-based-routing-guide": {
                "title": "File-Based Routing Guide",
                "author": "Bob",
                "date": "2024-01-20",
                "content": "Learn how to use file-based routing in Jac applications. Create pages by simply adding files to your pages/ directory, and Jac will automatically generate routes."
            },
            "dynamic-routes-explained": {
                "title": "Dynamic Routes Explained",
                "author": "Charlie",
                "date": "2024-01-25",
                "content": "Dynamic routes allow you to create pages that respond to URL parameters. Use [param].jac for single parameters or [...slug].jac for catch-all routes."
            }
        };

        post = posts[slug];

        if not post {
            return
                <div style={{"padding": "2rem", "textAlign": "center"}}>
                    <h1>
                        Post Not Found
                    </h1>
                    <p>
                        No post exists with slug: "{slug}"
                    </p>
                    <Link to="/posts">
                        Browse All Posts
                    </Link>
                </div>;
        }

        return
            <article style={{"padding": "2rem", "maxWidth": "700px"}}>
                <Link
                    to="/posts"
                    style={{"color": "#3b82f6", "textDecoration": "none"}}
                >
                    ← Back to Posts
                </Link>
                <h1 style={{"marginTop": "1rem", "fontSize": "2rem"}}>
                    {post["title"]}
                </h1>
                <div style={{"color": "#6b7280", "marginBottom": "1.5rem"}}>
                    By{post["author"]} ·{post["date"]}
                </div>
                <p style={{"lineHeight": "1.7", "color": "#374151"}}>
                    {post["content"]}
                </p>
                <div
                    style={{
                        "marginTop": "2rem",
                        "padding": "1rem",
                        "background": "#eff6ff",
                        "borderRadius": "8px",
                        "fontSize": "0.875rem"
                    }}
                >
                    <strong>
                        URL Slug:
                    </strong>
                    {slug}
                </div>
            </article>;
    }
}
