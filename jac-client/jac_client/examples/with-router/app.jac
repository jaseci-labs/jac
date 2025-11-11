
# Pages
cl import from react {useState, useEffect}
cl import from "@jac-client/utils" {Router, Routes, Route, Link}
cl {
    # Home Page Component
    def Home() -> any {
        return <div>
            <h1>Home Page</h1>
            <p>Welcome to the home page!</p>
            <p>This is a simple routing example using React-style routing.</p>
        </div>;
    }

    # About Page Component
    def About() -> any {
        return <div>
            <h1>About Page</h1>
            <p>This is the about page.</p>
            <p>Learn more about our application here.</p>
        </div>;
    }

    # Contact Page Component
    def Contact() -> any {
        return <div>
            <h1>Contact Page</h1>
            <p>Get in touch with us!</p>
            <p>Email: contact@example.com</p>
        </div>;
    }

    # Navigation Component
    def Navigation() -> any {
        return <nav style={{"padding": "1rem", "backgroundColor": "#f0f0f0", "marginBottom": "1rem"}}>
            <Link to="/">Home</Link>
            {" | "}
            <Link to="/about">About</Link>
            {" | "}
            <Link to="/contact">Contact</Link>
        </nav>;
    }
    # Main App Component with Routing
    def app() -> any {
        return <Router defaultRoute="/">
            <div>
                <Navigation />
                <Routes>
                    <Route path="/" component={Home} />
                    <Route path="/about" component={About} />
                    <Route path="/contact" component={Contact} />
                </Routes>
            </div>
        </Router>;
    }
}
